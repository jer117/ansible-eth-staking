#!/bin/bash

# Ethereum Staking Setup Verification Script
# This script checks all the issues mentioned by Alan

set -e

echo "============================================================================"
echo "ETHEREUM STAKING SETUP VERIFICATION"
echo "============================================================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "OK" ]; then
        echo -e "${GREEN}✓${NC} $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
    fi
}

echo ""
echo "1. DOCKER NETWORK VERIFICATION"
echo "--------------------------------"

# Check if Docker network exists
if docker network ls | grep -q "eth-staking-network-net"; then
    print_status "OK" "Docker network 'eth-staking-network-net' exists"
else
    print_status "ERROR" "Docker network 'eth-staking-network-net' missing"
fi

# List containers on the network
echo ""
echo "Containers on eth-staking-network-net:"
docker network inspect eth-staking-network-net --format='{{range .Containers}}{{.Name}} ({{.IPv4Address}}){{"\n"}}{{end}}' 2>/dev/null || echo "No containers found"

echo ""
echo "2. CONTAINER STATUS VERIFICATION"
echo "--------------------------------"

# Check container statuses
containers=("charon" "eth-ansible-consensus-1" "eth-ansible-execution-1" "eth-ansible-validator-1" "mev-boost")

for container in "${containers[@]}"; do
    if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$container"; then
        status=$(docker ps --format "table {{.Names}}\t{{.Status}}" | grep "$container" | awk '{print $2}')
        print_status "OK" "$container: $status"
    else
        print_status "ERROR" "$container: Not running or not found"
    fi
done

echo ""
echo "3. PORT EXPOSURE VERIFICATION"
echo "--------------------------------"

# Check if Charon port 3600 is exposed
if docker port charon 2>/dev/null | grep -q "3600"; then
    print_status "OK" "Charon port 3600 is exposed"
    docker port charon | grep "3600"
else
    print_status "ERROR" "Charon port 3600 is not exposed"
fi

echo ""
echo "4. KEY FILE VERIFICATION"
echo "--------------------------------"

# Check Charon key files
charon_files=(
    "/root/.charon/cluster-lock.json"
    "/root/.charon/charon-enr-private-key"
    "/root/.charon/cluster-definition.json"
)

for file in "${charon_files[@]}"; do
    if [ -f "$file" ]; then
        print_status "OK" "$file exists"
    else
        print_status "ERROR" "$file missing"
    fi
done

# Check validator key files
validator_files=(
    "/root/.charon/validator_keys"
    "/root/.lighthouse/hoodi/validators"
    "/root/.charon/validator_keys/validator_definitions.yml"
    "/root/.lighthouse/hoodi/validators/validator_definitions.yml"
)

for file in "${validator_files[@]}"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        print_status "OK" "$file exists"
    else
        print_status "ERROR" "$file missing"
    fi
done

echo ""
echo "5. FILE PERMISSIONS VERIFICATION"
echo "--------------------------------"

# Check file permissions
if [ -f "/root/.charon/charon-enr-private-key" ]; then
    perms=$(ls -la /root/.charon/charon-enr-private-key | awk '{print $1}')
    if [[ "$perms" == *"666"* ]] || [[ "$perms" == *"600"* ]]; then
        print_status "OK" "charon-enr-private-key permissions: $perms"
    else
        print_status "WARN" "charon-enr-private-key permissions: $perms (should be 600 or 666)"
    fi
fi

if [ -f "/root/.charon/cluster-lock.json" ]; then
    perms=$(ls -la /root/.charon/cluster-lock.json | awk '{print $1}')
    if [[ "$perms" == *"666"* ]] || [[ "$perms" == *"600"* ]]; then
        print_status "OK" "cluster-lock.json permissions: $perms"
    else
        print_status "WARN" "cluster-lock.json permissions: $perms (should be 600 or 666)"
    fi
fi

echo ""
echo "6. PUBLIC KEY MATCHING VERIFICATION"
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
validator_def_files=(
    "/root/.charon/validator_keys/validator_definitions.yml"
    "/root/.lighthouse/hoodi/validators/validator_definitions.yml"
)

validator_pubkey=""
for file in "${validator_def_files[@]}"; do
    if [ -f "$file" ]; then
        validator_pubkey=$(grep "voting_public_key" "$file" | head -1 | sed 's/.*"\(.*\)".*/\1/' 2>/dev/null)
        if [ -n "$validator_pubkey" ]; then
            print_status "OK" "Validator-definitions public key from $file: $validator_pubkey"
            break
        fi
    fi
done

if [ -z "$validator_pubkey" ]; then
    print_status "ERROR" "Could not extract public key from validator_definitions.yml (checked: ${validator_def_files[*]})"
fi

# Compare public keys
if [ -n "$cluster_pubkey" ] && [ -n "$validator_pubkey" ]; then
    if [ "$cluster_pubkey" = "$validator_pubkey" ]; then
        print_status "OK" "Public keys MATCH ✓"
    else
        print_status "ERROR" "Public keys MISMATCH ✗"
        echo "  Cluster-lock: $cluster_pubkey"
        echo "  Validator-def: $validator_pubkey"
    fi
else
    print_status "WARN" "Cannot compare public keys (one or both missing)"
fi

echo ""
echo "7. CONTAINER LOGS ANALYSIS"
echo "--------------------------------"

# Check Charon logs for errors
echo "Recent Charon errors:"
docker logs --tail 10 charon 2>&1 | grep -E "(ERRO|WARN|unknown public key|Unable to sign)" || echo "No recent errors found"

echo ""
echo "Recent Lighthouse validator errors:"
docker logs --tail 10 eth-ansible-validator-1 2>&1 | grep -E "(pubkey|ERRO|WARN)" || echo "No recent errors found"

echo ""
echo "9. FIREWALL CHECK"
echo "--------------------------------"

# Check if UFW is active and what ports are open
if command -v ufw >/dev/null 2>&1; then
    ufw_status=$(ufw status | head -1)
    if [[ "$ufw_status" == *"active"* ]]; then
        print_status "OK" "UFW is active"
        echo "Open ports:"
        ufw status | grep "ALLOW" || echo "No specific rules found"
    else
        print_status "WARN" "UFW is not active"
    fi
else
    print_status "WARN" "UFW not installed"
fi

echo ""
echo "============================================================================"
echo "VERIFICATION COMPLETE"
echo "============================================================================"

# Summary
echo ""
echo "SUMMARY:"
echo "Run this command to see all container logs:"
echo "  docker logs charon && docker logs eth-ansible-validator-1"
echo ""
echo "To check specific issues:"
echo "1. If public keys don't match: Compare /root/.charon/cluster-lock.json with /root/.charon/validator_keys/validator_definitions.yml"
echo "2. If containers can't communicate: Check Docker network with 'docker network inspect eth-staking-network-net'"
echo "3. If Charon API is not accessible: Check if port 3600 is exposed with 'docker port charon'"
echo "4. If files are missing: Check if the Ansible playbook ran successfully" 