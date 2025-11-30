#!/bin/bash
# APISIX Deployment Verification Script
# Usage: ./verify-apisix.sh <SERVER_IP> <API_KEY>

set -e

SERVER=${1:-localhost}
API_KEY=${2:-""}
PORT=9080
ADMIN_PORT=9180

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
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC} - $2"
    else
        echo -e "${RED}✗ FAIL${NC} - $2"
        return 1
    fi
}

# Test 1: Check if APISIX container is running
echo "Test 1: Checking APISIX container status..."
if command -v ssh &> /dev/null && [ "$SERVER" != "localhost" ]; then
    APISIX_RUNNING=$(ssh root@${SERVER} "docker ps | grep eth-ansible-apisix" 2>/dev/null || echo "")
else
    APISIX_RUNNING=$(docker ps | grep eth-ansible-apisix 2>/dev/null || echo "")
fi

if [ -n "$APISIX_RUNNING" ]; then
    print_result 0 "APISIX container is running"
else
    print_result 1 "APISIX container is not running"
    exit 1
fi
echo ""

# Test 2: Check if etcd container is running
echo "Test 2: Checking etcd container status..."
if command -v ssh &> /dev/null && [ "$SERVER" != "localhost" ]; then
    ETCD_RUNNING=$(ssh root@${SERVER} "docker ps | grep eth-ansible-apisix-etcd" 2>/dev/null || echo "")
else
    ETCD_RUNNING=$(docker ps | grep eth-ansible-apisix-etcd 2>/dev/null || echo "")
fi

if [ -n "$ETCD_RUNNING" ]; then
    print_result 0 "etcd container is running"
else
    print_result 1 "etcd container is not running"
    exit 1
fi
echo ""

# Test 3: Check health endpoint (no auth)
echo "Test 3: Testing health endpoint (no authentication)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER}:${PORT}/health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "Health endpoint accessible"
else
    print_result 1 "Health endpoint returned HTTP ${HTTP_CODE}"
fi
echo ""

# Test 4: Check execution health endpoint (no auth)
echo "Test 4: Testing execution health endpoint (no authentication)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER}:${PORT}/execution-health 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "Execution health endpoint accessible"
else
    print_result 1 "Execution health endpoint returned HTTP ${HTTP_CODE}"
fi
echo ""

# Test 5: Check auth protection (should return 401)
echo "Test 5: Testing authentication protection..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER}:${PORT}/consensus/eth/v1/node/version 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
    print_result 0 "Authentication protection is working (HTTP ${HTTP_CODE})"
else
    print_result 1 "Authentication protection failed (HTTP ${HTTP_CODE}, expected 401 or 403)"
fi
echo ""

# Test 6: Check authenticated access (if API key provided)
if [ -n "$API_KEY" ]; then
    echo "Test 6: Testing authenticated access with API Key..."
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "X-API-Key: ${API_KEY}" http://${SERVER}:${PORT}/consensus/eth/v1/node/version 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        print_result 0 "Authenticated access works"
        
        # Get actual response
        echo ""
        echo "Response:"
        curl -s -H "X-API-Key: ${API_KEY}" http://${SERVER}:${PORT}/consensus/eth/v1/node/version | jq . 2>/dev/null || echo "JSON parsing failed"
    else
        print_result 1 "Authenticated access failed (HTTP ${HTTP_CODE})"
    fi
    echo ""
    
    # Test 7: Test execution client access
    echo "Test 7: Testing execution client access (eth_blockNumber)..."
    RESPONSE=$(curl -s -H "X-API-Key: ${API_KEY}" \
        -X POST \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
        http://${SERVER}:${PORT}/execution/ 2>/dev/null || echo "")
    
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
    echo -e "${YELLOW}Test 6-7: Skipped (no API key provided)${NC}"
    echo "Run with API key to test authenticated endpoints:"
    echo "./verify-apisix.sh ${SERVER} <your-api-key>"
    echo ""
fi

# Test 8: Check Prometheus metrics
echo "Test 8: Testing Prometheus metrics endpoint..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER}:9091/apisix/prometheus/metrics 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "Prometheus metrics endpoint accessible"
    
    # Count metrics
    METRIC_COUNT=$(curl -s http://${SERVER}:9091/apisix/prometheus/metrics 2>/dev/null | grep -c "^apisix_" || echo "0")
    echo "   Found ${METRIC_COUNT} APISIX metrics"
else
    print_result 1 "Prometheus metrics endpoint failed (HTTP ${HTTP_CODE})"
fi
echo ""

# Test 9: Check APISIX admin API
echo "Test 9: Testing APISIX Admin API (requires admin key)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER}:${ADMIN_PORT}/apisix/admin/routes 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "200" ]; then
    print_result 0 "Admin API is accessible (HTTP ${HTTP_CODE})"
else
    echo -e "${YELLOW}⚠ WARNING${NC} - Admin API returned HTTP ${HTTP_CODE}"
fi
echo ""

# Summary
echo "======================================"
echo "  Verification Summary"
echo "======================================"
echo ""
echo -e "${GREEN}Core Components:${NC}"
echo "  • APISIX Gateway: Running on port ${PORT}"
echo "  • etcd: Running"
echo "  • Prometheus Metrics: Available on port 9091"
echo ""
echo -e "${GREEN}Endpoints:${NC}"
echo "  • Health Check: http://${SERVER}:${PORT}/health"
echo "  • Consensus API: http://${SERVER}:${PORT}/consensus/*"
echo "  • Execution API: http://${SERVER}:${PORT}/execution/"
echo ""
echo -e "${GREEN}Security:${NC}"
echo "  • Authentication: Enabled"
echo "  • Supported Methods: API Key, Bearer Token"
echo ""

if [ -z "$API_KEY" ]; then
    echo -e "${YELLOW}Note: Run with API key for full verification:${NC}"
    echo "./verify-apisix.sh ${SERVER} <your-api-key>"
fi

echo ""
echo "======================================"

