#!/bin/bash
# APISIX Deployment Verification Script
# Usage: ./verify-apisix.sh <SERVER_IP> [API_KEY]
#
# API_KEY is apisix_api_key from your vars or, if Ansible generated it, the contents of
# credentials/<inventory_hostname>/apisix/api_key next to your inventory file:
#   ./verify-apisix.sh <SERVER_IP> "$(cat credentials/<inventory_hostname>/apisix/api_key)"

set -e

SERVER=${1:-localhost}
API_KEY=${2:-""}
PORT=9080

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "  APISIX Deployment Verification"
echo "======================================"
echo ""
echo "Server: ${SERVER}"
echo "Port: ${PORT}"
echo ""

# Function to print test results
print_result() {
    if [ "$1" -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC} - $2"
    else
        echo -e "${RED}✗ FAIL${NC} - $2"
        return 1
    fi
}

# Function to run a command on the server (over SSH unless the server is localhost)
on_server() {
    if command -v ssh &> /dev/null && [ "$SERVER" != "localhost" ]; then
        # $1 is the command to run on the server, so it is expanded here on purpose
        # shellcheck disable=SC2029
        ssh "root@${SERVER}" "$1"
    else
        sh -c "$1"
    fi
}

# Test 1: Check if APISIX container is running
echo "Test 1: Checking APISIX container status..."
APISIX_RUNNING=$(on_server "docker ps --format '{{.Names}}' | grep -x eth-ansible-apisix" 2>/dev/null || echo "")

if [ -n "$APISIX_RUNNING" ]; then
    print_result 0 "APISIX container is running"
else
    print_result 1 "APISIX container is not running"
    exit 1
fi
echo ""

# Test 2: Check health endpoint (no auth)
echo "Test 2: Testing health endpoint (no authentication)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER}:${PORT}/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "Health endpoint accessible"
else
    print_result 1 "Health endpoint returned HTTP ${HTTP_CODE}"
fi
echo ""

# Test 3: Check execution health endpoint (no auth)
echo "Test 3: Testing execution health endpoint (no authentication)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER}:${PORT}/execution-health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "Execution health endpoint accessible"
else
    print_result 1 "Execution health endpoint returned HTTP ${HTTP_CODE}"
fi
echo ""

# Test 4: Check auth protection (should return 401)
echo "Test 4: Testing authentication protection..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${SERVER}:${PORT}/consensus/eth/v1/node/version" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "401" ]; then
    print_result 0 "Authentication protection is working (HTTP ${HTTP_CODE})"
else
    print_result 1 "Authentication protection failed (HTTP ${HTTP_CODE}, expected 401)"
fi
echo ""

# Test 5: Check authenticated access (if API key provided)
if [ -n "$API_KEY" ]; then
    echo "Test 5: Testing authenticated access with API Key..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: ${API_KEY}" "http://${SERVER}:${PORT}/consensus/eth/v1/node/version" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_result 0 "Authenticated access works"

        # Get actual response
        echo ""
        echo "Response:"
        curl -s -H "X-API-Key: ${API_KEY}" "http://${SERVER}:${PORT}/consensus/eth/v1/node/version" | jq . 2>/dev/null || echo "JSON parsing failed"
    else
        print_result 1 "Authenticated access failed (HTTP ${HTTP_CODE})"
    fi
    echo ""

    # Test 6: Check that a wrong API key is rejected
    echo "Test 6: Testing that a wrong API key is rejected..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: ${API_KEY}-wrong" "http://${SERVER}:${PORT}/consensus/eth/v1/node/version" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "401" ]; then
        print_result 0 "Wrong API key is rejected (HTTP ${HTTP_CODE})"
    else
        print_result 1 "Wrong API key was not rejected (HTTP ${HTTP_CODE}, expected 401)"
    fi
    echo ""

    # Test 7: Test execution client access
    echo "Test 7: Testing execution client access (eth_blockNumber)..."
    RESPONSE=$(curl -s -H "X-API-Key: ${API_KEY}" \
        -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        "http://${SERVER}:${PORT}/execution/" 2>/dev/null || echo "")

    if echo "$RESPONSE" | grep -q "result"; then
        print_result 0 "Execution client access works"
        echo ""
        echo "Response:"
        echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
    else
        print_result 1 "Execution client access failed"
        echo "Response: $RESPONSE"
    fi
    echo ""
else
    echo -e "${YELLOW}Test 5-7: Skipped (no API key provided)${NC}"
    echo "Run with API key to test authenticated endpoints:"
    echo "./verify-apisix.sh ${SERVER} <your-api-key>"
    echo ""
fi

# Test 8: Check Prometheus metrics
# Port 9091 is not published on the host and the APISIX image has no curl, so fetch the
# metrics from inside the container using bash's /dev/tcp.
echo "Test 8: Testing Prometheus metrics endpoint (inside the APISIX container)..."
METRICS_CMD="docker exec eth-ansible-apisix bash -c 'exec 3<>/dev/tcp/127.0.0.1/9091 && printf \"GET /apisix/prometheus/metrics HTTP/1.0\\r\\n\\r\\n\" >&3 && cat <&3'"
METRICS=$(on_server "$METRICS_CMD" 2>/dev/null || echo "")
if echo "$METRICS" | grep -q "^HTTP/1\.[01] 200"; then
    print_result 0 "Prometheus metrics endpoint accessible"

    # Count metrics
    METRIC_COUNT=$(echo "$METRICS" | grep -c "^apisix_" || true)
    echo "   Found ${METRIC_COUNT} APISIX metrics"
else
    print_result 1 "Prometheus metrics endpoint failed"
fi
echo ""

# Summary
echo "======================================"
echo "  Verification Summary"
echo "======================================"
echo ""
echo -e "${GREEN}Core Components:${NC}"
echo "  • APISIX Gateway: Running on port ${PORT} (standalone mode, no etcd)"
echo "  • Prometheus Metrics: Available on port 9091 inside the Docker network"
echo ""
echo -e "${GREEN}Endpoints:${NC}"
echo "  • Health Check: http://${SERVER}:${PORT}/health"
echo "  • Execution Health Check: http://${SERVER}:${PORT}/execution-health"
echo "  • Consensus API: http://${SERVER}:${PORT}/consensus/*"
echo "  • Execution API: http://${SERVER}:${PORT}/execution/"
echo ""
echo -e "${GREEN}Security:${NC}"
echo "  • Authentication: Enabled (key-auth)"
echo "  • Supported Methods: API Key (X-API-Key), Bearer Token (Authorization: Bearer)"
echo ""

if [ -z "$API_KEY" ]; then
    echo -e "${YELLOW}Note: Run with API key for full verification:${NC}"
    echo "./verify-apisix.sh ${SERVER} <your-api-key>"
fi

echo ""
echo "======================================"

