#!/bin/bash

# Focused diagnostic script for Charon-Lighthouse validator issues
# Based on the specific error: "No validators present" and connection refused

set -e

echo "============================================================================"
echo "CHARON-LIGHTHOUSE VALIDATOR DIAGNOSTIC"
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

echo ""
echo "1. CONTAINER STATUS CHECK"
echo "--------------------------------"

# Check if containers are running
if docker ps | grep -q "charon"; then
    charon_status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "charon" | awk '{print $2}')
    print_status "OK" "Charon container: $charon_status"
else
    print_status "ERROR" "Charon container not running"
fi

if docker ps | grep -q "eth-ansible-validator-1"; then
    validator_status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "eth-ansible-validator-1" | awk '{print $2}')
    print_status "OK" "Lighthouse validator: $validator_status"
else
    print_status "ERROR" "Lighthouse validator container not running"
fi

echo ""
echo "2. CHARON API ACCESSIBILITY"
echo "--------------------------------"

# Check if Charon port 3600 is exposed
if docker port charon 2>/dev/null | grep -q "3600"; then
    print_status "OK" "Charon port 3600 is exposed"
    docker port charon | grep "3600"
else
    print_status "ERROR" "Charon port 3600 is NOT exposed"
fi

# Test direct connection to Charon API
echo ""
echo "Testing Charon API connectivity:"
if curl -s --connect-timeout 5 http://charon:3600/health >/dev/null 2>&1; then
    print_status "OK" "Charon API health endpoint accessible from host"
else
    print_status "ERROR" "Charon API health endpoint NOT accessible from host"
fi

# Test from within the validator container
echo ""
echo "Testing from within Lighthouse validator container:"
if docker exec eth-ansible-validator-1 curl -s --connect-timeout 5 http://charon:3600/health >/dev/null 2>&1; then
    print_status "OK" "Charon API accessible from Lighthouse validator container"
else
    print_status "ERROR" "Charon API NOT accessible from Lighthouse validator container"
fi

echo ""
echo "3. VALIDATOR DEFINITIONS CHECK"
echo "--------------------------------"

# Check for validator_definitions.yml in both locations
validator_def_locations=(
    "/root/.charon/validator_keys/validator_definitions.yml"
    "/root/.lighthouse/hoodi/validators/validator_definitions.yml"
)

found_def_file=""
for file in "${validator_def_locations[@]}"; do
    if [ -f "$file" ]; then
        print_status "OK" "Found validator_definitions.yml at: $file"
        found_def_file="$file"
        break
    fi
done

if [ -z "$found_def_file" ]; then
    print_status "ERROR" "validator_definitions.yml not found in any expected location"
    echo "Expected locations:"
    for file in "${validator_def_locations[@]}"; do
        echo "  - $file"
    done
fi

# Check the content of validator_definitions.yml
if [ -n "$found_def_file" ]; then
    echo ""
    echo "Validator definitions content:"
    cat "$found_def_file"
fi

echo ""
echo "4. PUBLIC KEY COMPARISON"
echo "--------------------------------"

# Extract public key from cluster-lock.json
if [ -f "/root/.charon/cluster-lock.json" ]; then
    cluster_pubkey=$(jq -r '.validators[0].public_key' /root/.charon/cluster-lock.json 2>/dev/null)
    if [ "$cluster_pubkey" != "null" ] && [ -n "$cluster_pubkey" ]; then
        print_status "OK" "Cluster-lock public key: $cluster_pubkey"
    else
        print_status "ERROR" "Could not extract public key from cluster-lock.json"
    fi
else
    print_status "ERROR" "cluster-lock.json not found"
fi

# Extract public key from validator_definitions.yml
if [ -n "$found_def_file" ]; then
    validator_pubkey=$(grep "voting_public_key" "$found_def_file" | head -1 | sed 's/.*"\(.*\)".*/\1/' 2>/dev/null)
    if [ -n "$validator_pubkey" ]; then
        print_status "OK" "Validator-definitions public key: $validator_pubkey"
    else
        print_status "ERROR" "Could not extract public key from validator_definitions.yml"
    fi
else
    print_status "ERROR" "Cannot check validator_definitions.yml (file not found)"
fi

# Compare public keys
if [ -n "$cluster_pubkey" ] && [ -n "$validator_pubkey" ]; then
    if [ "$cluster_pubkey" = "$validator_pubkey" ]; then
        print_status "OK" "Public keys MATCH ✓"
    else
        print_status "ERROR" "Public keys MISMATCH ✗"
        echo "  Expected: $cluster_pubkey"
        echo "  Found:    $validator_pubkey"
    fi
fi

echo ""
echo "5. CONTAINER NETWORK CHECK"
echo "--------------------------------"

# Check if containers are on the same network
if docker network inspect eth-staking-network-net >/dev/null 2>&1; then
    print_status "OK" "eth-staking-network-net exists"
    
    echo "Containers on the network:"
    docker network inspect eth-staking-network-net --format='{{range .Containers}}{{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}' 2>/dev/null || echo "No containers found"
else
    print_status "ERROR" "eth-staking-network-net does not exist"
fi

echo ""
echo "6. RECENT CONTAINER LOGS"
echo "--------------------------------"

echo "Recent Charon logs (last 10 lines):"
docker logs --tail 10 charon 2>&1 | grep -E "(ERRO|WARN|INFO.*validator|INFO.*api)" || echo "No relevant logs found"

echo ""
echo "Recent Lighthouse validator logs (last 10 lines):"
docker logs --tail 10 eth-ansible-validator-1 2>&1 | grep -E "(ERRO|WARN|INFO.*validator|INFO.*No validators)" || echo "No relevant logs found"

echo ""
echo "7. VOLUME MOUNTS CHECK"
echo "--------------------------------"

# Check volume mounts for validator container
echo "Lighthouse validator volume mounts:"
docker inspect eth-ansible-validator-1 --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{.RW}}{{"\n"}}{{end}}' 2>/dev/null || echo "Cannot inspect container"

echo ""
echo "8. TROUBLESHOOTING RECOMMENDATIONS"
echo "--------------------------------"

echo "Based on the diagnostics above, here are the likely issues and solutions:"
echo ""
echo "1. If Charon API is not accessible:"
echo "   - Check if Charon container is running: docker ps | grep charon"
echo "   - Check Charon logs: docker logs charon"
echo "   - Verify port 3600 is exposed: docker port charon"
echo ""
echo "2. If validator_definitions.yml is missing:"
echo "   - Run the Ansible playbook again: ansible-playbook -i inventory main.yml --tags validator"
echo "   - Check if the file was created in the correct location"
echo ""
echo "3. If public keys don't match:"
echo "   - Update validator_definitions.yml to use the correct public key from cluster-lock.json"
echo "   - The expected public key is: 0xb17e1dddca92e0e31e66dea3a037679179879fe2d0b7e95cf931d6fdc4a472d5de7cda4bdaa4811fc8332e99538a0505"
echo ""
echo "4. If containers can't communicate:"
echo "   - Ensure both containers are on eth-staking-network-net"
echo "   - Restart containers: docker restart charon eth-ansible-validator-1"
echo ""
echo "5. Quick fix commands:"
echo "   - Restart Charon: docker restart charon"
echo "   - Restart Lighthouse validator: docker restart eth-ansible-validator-1"
echo "   - Check real-time logs: docker logs -f charon & docker logs -f eth-ansible-validator-1" 