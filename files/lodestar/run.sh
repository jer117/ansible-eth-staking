#!/bin/bash

set -e

# Configuration
DATA_DIR="/opt/data"
KEYSTORES_DIR="${DATA_DIR}/keystores"
SECRETS_DIR="${DATA_DIR}/secrets"
NETWORK="${NETWORK:-mainnet}"
BEACON_NODE_ADDRESS="${BEACON_NODE_ADDRESS:-http://charon:3600}"
BUILDER_API_ENABLED="${BUILDER_API_ENABLED:-false}"
BUILDER_SELECTION="${BUILDER_SELECTION:-builderalways}"

# Create directories
mkdir -p "${DATA_DIR}" "${KEYSTORES_DIR}" "${SECRETS_DIR}"

echo "Starting Lodestar validator client setup..."
echo "Network: ${NETWORK}"
echo "Beacon node: ${BEACON_NODE_ADDRESS}"
echo "Builder API: ${BUILDER_API_ENABLED}"
echo "Builder selection: ${BUILDER_SELECTION}"

# Initialize counters
IMPORTED_COUNT=0
EXISTING_COUNT=0

# Import keystores from Charon directory
for f in /home/charon/validator_keys/keystore-*.json; do
    if [ -f "$f" ]; then
        echo "Importing key ${f}"

        # Extract pubkey from keystore file
        PUBKEY="0x$(grep '"pubkey"' "$f" | awk -F'"' '{print $4}')"

        PUBKEY_DIR="${KEYSTORES_DIR}/${PUBKEY}"

        # Skip import if keystore already exists
        if [ -d "${PUBKEY_DIR}" ]; then
            EXISTING_COUNT=$((EXISTING_COUNT + 1))
            echo "Keystore for ${PUBKEY} already exists, skipping..."
            continue
        fi

        mkdir -p "${PUBKEY_DIR}"

        # Copy the keystore file to persisted keys backend
        install -m 600 "$f" "${PUBKEY_DIR}/voting-keystore.json"

        # Copy the corresponding password file
        PASSWORD_FILE="${f%.json}.txt"
        if [ -f "${PASSWORD_FILE}" ]; then
            install -m 600 "${PASSWORD_FILE}" "${SECRETS_DIR}/${PUBKEY}"
        else
            echo "Warning: Password file ${PASSWORD_FILE} not found"
        fi

        IMPORTED_COUNT=$((IMPORTED_COUNT + 1))
        echo "Imported keystore for ${PUBKEY}"
    fi
done

echo "Processed all keys imported=${IMPORTED_COUNT}, existing=${EXISTING_COUNT}, total=$(ls /home/charon/validator_keys/keystore-*.json 2>/dev/null | wc -l || echo 0)"

# Start Lodestar validator
echo "Starting Lodestar validator client..."

exec node /usr/app/packages/cli/bin/lodestar validator \
    --dataDir="$DATA_DIR" \
    --keystoresDir="$KEYSTORES_DIR" \
    --secretsDir="$SECRETS_DIR" \
    --network="$NETWORK" \
    --metrics=true \
    --metrics.address="0.0.0.0" \
    --metrics.port=5064 \
    --beaconNodes="$BEACON_NODE_ADDRESS" \
    --builder="$BUILDER_API_ENABLED" \
    --builder.selection="$BUILDER_SELECTION" \
    --distributed 