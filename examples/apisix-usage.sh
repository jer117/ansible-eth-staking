#!/bin/bash
# APISIX Usage Examples for Ethereum Staking Infrastructure
# Replace <SERVER_IP> and <YOUR_API_KEY> with actual values

SERVER="<SERVER_IP>"
API_KEY="<YOUR_API_KEY>"
BEARER_TOKEN="<YOUR_BEARER_TOKEN>"

echo "=== APISIX Usage Examples for Ethereum Staking ==="
echo ""

# Health checks (no authentication required)
echo "1. Checking Consensus Client Health (no auth):"
curl -s "http://${SERVER}:9080/health" | jq .
echo ""

echo "2. Checking Execution Client Health (no auth):"
curl -s "http://${SERVER}:9080/execution-health"
echo ""
echo ""

# Authenticated requests using API Key
echo "3. Get Consensus Client Version (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  "http://${SERVER}:9080/consensus/eth/v1/node/version" | jq .
echo ""

echo "4. Get Consensus Client Syncing Status (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  "http://${SERVER}:9080/consensus/eth/v1/node/syncing" | jq .
echo ""

echo "5. Get Consensus Client Peers (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  "http://${SERVER}:9080/consensus/eth/v1/node/peers" | jq .
echo ""

echo "6. Get Current Block Number from Execution Client (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  "http://${SERVER}:9080/execution/" | jq .
echo ""

echo "7. Get Execution Client Syncing Status (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  "http://${SERVER}:9080/execution/" | jq .
echo ""

# Authenticated requests using Bearer Token
echo "8. Get Consensus Node Identity (with Bearer Token):"
curl -s -H "Authorization: Bearer ${BEARER_TOKEN}" \
  "http://${SERVER}:9080/consensus/eth/v1/node/identity" | jq .
echo ""

echo "9. Get Chain Head from Execution Client (with Bearer Token):"
curl -s -H "Authorization: Bearer ${BEARER_TOKEN}" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}' \
  "http://${SERVER}:9080/execution/" | jq .
echo ""

# Advanced Lighthouse API calls
echo "10. Get Validator Performance (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  "http://${SERVER}:9080/consensus/eth/v1/beacon/states/head/validators" | jq .
echo ""

echo "11. Get Current Epoch (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  "http://${SERVER}:9080/consensus/eth/v1/beacon/states/head/finality_checkpoints" | jq .
echo ""

# Nethermind admin API calls
echo "12. Get Peer Count from Execution Client (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' \
  "http://${SERVER}:9080/execution/" | jq .
echo ""

echo "13. Get Gas Price (with API Key):"
curl -s -H "X-API-Key: ${API_KEY}" \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' \
  "http://${SERVER}:9080/execution/" | jq .
echo ""

# Test unauthorized access (should fail)
echo "14. Test Unauthorized Access (should return 401):"
curl -i "http://${SERVER}:9080/consensus/eth/v1/node/version" 2>&1 | grep -E "HTTP|401|Unauthorized"
echo ""

# Metrics (port 9091 is only reachable on the Docker network, not published on the host)
echo "15. View APISIX Prometheus Metrics (run on the server):"
echo "docker run --rm --network eth-staking-network-net curlimages/curl -s http://eth-ansible-apisix:9091/apisix/prometheus/metrics"
echo ""

echo "=== Examples Complete ==="

