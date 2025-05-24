#!/bin/bash

# Quick fix script for Charon-Lighthouse validator issues
# Based on the specific error: "No validators present" and connection refused

set -e

echo "============================================================================"
echo "CHARON-LIGHTHOUSE VALIDATOR QUICK FIX"
echo "============================================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

# Expected public key from cluster-lock.json
EXPECTED_PUBKEY="0xb17e1dddca92e0e31e66dea3a037679179879fe2d0b7e95cf931d6fdc4a472d5de7cda4bdaa4811fc8332e99538a0505"

echo ""
echo "1. CHECKING CURRENT STATUS"
echo "--------------------------------"

# Check if containers are running
charon_running=false
validator_running=false

if docker ps | grep -q "charon"; then
    charon_running=true
    print_status "OK" "Charon container is running"
else
    print_status "ERROR" "Charon container is not running"
fi

if docker ps | grep -q "eth-ansible-validator-1"; then
    validator_running=true
    print_status "OK" "Lighthouse validator container is running"
else
    print_status "ERROR" "Lighthouse validator container is not running"
fi

echo ""
echo "2. FIXING VALIDATOR DEFINITIONS"
echo "--------------------------------"

# Create the correct validator_definitions.yml with the expected public key
VALIDATOR_DEF_DIR="/root/.charon/validator_keys"
VALIDATOR_DEF_FILE="$VALIDATOR_DEF_DIR/validator_definitions.yml"

# Create directory if it doesn't exist
if [ ! -d "$VALIDATOR_DEF_DIR" ]; then
    print_status "INFO" "Creating directory: $VALIDATOR_DEF_DIR"
    mkdir -p "$VALIDATOR_DEF_DIR"
fi

# Create the correct validator_definitions.yml
print_status "INFO" "Creating validator_definitions.yml with correct public key"
cat > "$VALIDATOR_DEF_FILE" << EOF
---
- enabled: true
  voting_public_key: "$EXPECTED_PUBKEY"
  type: "web3signer"
  url: "http://charon:3600"
  fee_recipient: "0xBC1eF09B6A48aAEEC6059Cf7E7936F4DD1eFE8cF"
  gas_limit: 30000000
  builder_proposals: true
  builder_boost_factor: 100
EOF

print_status "OK" "Created validator_definitions.yml with public key: $EXPECTED_PUBKEY"

# Set correct permissions
chmod 600 "$VALIDATOR_DEF_FILE"
chown root:root "$VALIDATOR_DEF_FILE"

echo ""
echo "3. RESTARTING CONTAINERS"
echo "--------------------------------"

# Restart Charon if it's running
if [ "$charon_running" = true ]; then
    print_status "INFO" "Restarting Charon container..."
    docker restart charon
    sleep 5
    print_status "OK" "Charon container restarted"
else
    print_status "WARN" "Charon container not running - you may need to start it manually"
fi

# Restart Lighthouse validator if it's running
if [ "$validator_running" = true ]; then
    print_status "INFO" "Restarting Lighthouse validator container..."
    docker restart eth-ansible-validator-1
    sleep 5
    print_status "OK" "Lighthouse validator container restarted"
else
    print_status "WARN" "Lighthouse validator container not running - you may need to start it manually"
fi

echo ""
echo "4. VERIFYING THE FIX"
echo "--------------------------------"

# Wait a moment for containers to fully start
sleep 10

# Check if Charon API is accessible
if curl -s --connect-timeout 5 http://charon:3600/health >/dev/null 2>&1; then
    print_status "OK" "Charon API is now accessible"
else
    print_status "ERROR" "Charon API is still not accessible"
fi

# Check if validator container can see validators
echo ""
echo "Checking Lighthouse validator logs for validator detection..."
if docker logs eth-ansible-validator-1 --tail 20 2>&1 | grep -q "No validators present"; then
    print_status "WARN" "Lighthouse still reports 'No validators present'"
    echo "This might take a few more minutes to resolve..."
else
    print_status "OK" "Lighthouse validator appears to be working"
fi

echo ""
echo "5. FINAL STATUS CHECK"
echo "--------------------------------"

# Show current container status
echo "Current container status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(charon|eth-ansible-validator-1)" || echo "Containers not found"

# Show recent logs
echo ""
echo "Recent Charon logs (last 5 lines):"
docker logs --tail 5 charon 2>&1 | grep -E "(ERRO|WARN|INFO.*validator|INFO.*api)" || echo "No relevant logs found"

echo ""
echo "Recent Lighthouse validator logs (last 5 lines):"
docker logs --tail 5 eth-ansible-validator-1 2>&1 | grep -E "(ERRO|WARN|INFO.*validator|INFO.*No validators)" || echo "No relevant logs found"

echo ""
echo "============================================================================"
echo "QUICK FIX COMPLETE"
echo "============================================================================"

echo ""
echo "SUMMARY:"
echo "1. Created validator_definitions.yml with the correct public key"
echo "2. Restarted both Charon and Lighthouse validator containers"
echo "3. Verified basic connectivity"
echo ""
echo "NEXT STEPS:"
echo "1. Monitor the logs: docker logs -f charon & docker logs -f eth-ansible-validator-1"
echo "2. Wait 2-3 minutes for Lighthouse to detect the validator"
echo "3. If issues persist, run the diagnostic script: ./scripts/diagnose-charon-validator.sh"
echo ""
echo "The expected public key is now configured: $EXPECTED_PUBKEY" 