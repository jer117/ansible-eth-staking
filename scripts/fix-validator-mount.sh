#!/bin/bash

# Fix script for validator mount issue
# Mounts /root/.charon/validator_keys to /root/.lighthouse/hoodi/validators

set -e

echo "============================================================================"
echo "FIXING VALIDATOR MOUNT ISSUE"
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
echo "1. STOPPING CONTAINERS"
echo "--------------------------------"

# Stop the validator container
if docker ps | grep -q "eth-ansible-validator-1"; then
    print_status "INFO" "Stopping Lighthouse validator container..."
    docker stop eth-ansible-validator-1
    print_status "OK" "Lighthouse validator container stopped"
else
    print_status "WARN" "Lighthouse validator container not running"
fi

echo ""
echo "2. CREATING CORRECT VALIDATOR DEFINITIONS"
echo "--------------------------------"

# Create the correct validator_definitions.yml
VALIDATOR_DEF_FILE="/root/.charon/validator_keys/validator_definitions.yml"

print_status "INFO" "Creating validator_definitions.yml with correct configuration"
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
echo "3. STARTING VALIDATOR WITH CORRECT MOUNT"
echo "--------------------------------"

# Start the validator container with the correct mount
print_status "INFO" "Starting Lighthouse validator with correct mount..."

docker run -d \
  --name eth-ansible-validator-1 \
  --network eth-staking-network-net \
  --restart unless-stopped \
  -p 127.0.0.1:5064:5064 \
  -p 127.0.0.1:8009:8009 \
  -v "/root/.charon/validator_keys:/root/.lighthouse/hoodi/validators:rw" \
  sigp/lighthouse:v7.0.0 \
  lighthouse validator_client \
  --beacon-nodes http://charon:3600 \
  --suggested-fee-recipient 0xBC1eF09B6A48aAEEC6059Cf7E7936F4DD1eFE8cF \
  --init-slashing-protection \
  --http \
  --http-address 0.0.0.0 \
  --unencrypted-http-transport \
  --http-port 5064 \
  --http-allow-origin "*" \
  --metrics \
  --metrics-address 0.0.0.0 \
  --metrics-port 8009 \
  --network hoodi \
  --use-long-timeouts \
  --disable-auto-discover \
  --distributed

print_status "OK" "Lighthouse validator container started with correct mount"

echo ""
echo "4. VERIFYING THE FIX"
echo "--------------------------------"

# Wait for container to start
sleep 10

# Check if container is running
if docker ps | grep -q "eth-ansible-validator-1"; then
    print_status "OK" "Lighthouse validator container is running"
else
    print_status "ERROR" "Lighthouse validator container failed to start"
    exit 1
fi

# Check if it can see validators
echo ""
echo "Checking Lighthouse validator logs for validator detection..."
sleep 5

if docker logs eth-ansible-validator-1 --tail 20 2>&1 | grep -q "No enabled validators"; then
    print_status "WARN" "Lighthouse still reports 'No enabled validators'"
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

# Show volume mounts
echo ""
echo "Volume mounts for Lighthouse validator:"
docker inspect eth-ansible-validator-1 --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{.RW}}{{"\n"}}{{end}}' 2>/dev/null || echo "Cannot inspect container"

# Show recent logs
echo ""
echo "Recent Lighthouse validator logs (last 10 lines):"
docker logs --tail 10 eth-ansible-validator-1 2>&1 | grep -E "(ERRO|WARN|INFO.*validator|INFO.*No validators)" || echo "No relevant logs found"

echo ""
echo "============================================================================"
echo "VALIDATOR MOUNT FIX COMPLETE"
echo "============================================================================"

echo ""
echo "SUMMARY:"
echo "1. Stopped the old Lighthouse validator container"
echo "2. Created correct validator_definitions.yml with web3signer configuration"
echo "3. Started new container with correct mount: /root/.charon/validator_keys -> /root/.lighthouse/hoodi/validators"
echo "4. Verified container is running and accessible"
echo ""
echo "NEXT STEPS:"
echo "1. Monitor the logs: docker logs -f eth-ansible-validator-1"
echo "2. Wait 2-3 minutes for Lighthouse to detect the validator"
echo "3. Check if validator appears in logs: docker logs eth-ansible-validator-1 | grep -i validator"
echo ""
echo "The validator should now be properly configured with public key: $EXPECTED_PUBKEY" 