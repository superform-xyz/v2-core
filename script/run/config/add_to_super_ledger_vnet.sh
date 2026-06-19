#!/bin/bash

# add_to_super_ledger_vnet.sh
# Purpose: Add new oracles to SuperLedgerConfiguration for vnet deployments
# Usage: sh script/run/config/add_to_super_ledger_vnet.sh <branch_name> [simulate]

set -e

# ===== CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/script/output"

FORGE_ENV=1  # vnet environment

# ===== LOAD SHARED UTILITIES =====
source "$SCRIPT_DIR/../utils/oracle-utils.sh"
source "$SCRIPT_DIR/../utils/networks-staging.sh"
source "$SCRIPT_DIR/../utils/networks-production.sh"

# ===== HELPER FUNCTIONS =====
log() {
    local level=$1
    shift
    echo "[$level] $*" >&2
}

# Get vnet RPC URL by querying S3 latest.json and then Tenderly API
get_vnet_rpc_url() {
    local branch_name=$1
    local chain_id=$2
    local access_key=$3

    # Get network name using shared function from networks files
    local network_name=$(get_network_name "$chain_id" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$network_name" ]; then
        log "ERROR" "Unknown chain ID: $chain_id"
        return 1
    fi

    log "INFO" "Fetching vnet RPC for $network_name (Chain ID: $chain_id)"

    # Read VNET ID from S3 latest.json
    local vnet_latest_path="/tmp/vnet_latest_${branch_name}_$$.json"
    if ! aws s3 cp "s3://vnet-state/$branch_name/latest.json" "$vnet_latest_path" --quiet 2>/dev/null; then
        log "ERROR" "Failed to download latest.json from S3 for branch: $branch_name"
        return 1
    fi

    local vnet_id=$(jq -r ".networks[\"$network_name\"].vnet_id" "$vnet_latest_path")

    if [ -z "$vnet_id" ] || [ "$vnet_id" = "null" ]; then
        log "ERROR" "Could not find VNET ID for $network_name in S3 latest.json"
        return 1
    fi

    log "INFO" "Found VNET ID: $vnet_id"

    # Get RPC URL from Tenderly API using VNET ID
    local vnet_details=$(curl -s -X GET \
        "https://api.tenderly.co/api/v1/account/superform/project/v2/vnets/$vnet_id" \
        -H "X-Access-Key: $access_key")

    if echo "$vnet_details" | grep -q "error"; then
        log "ERROR" "Failed to fetch vnet details for VNET ID: $vnet_id"
        log "ERROR" "Response: $vnet_details"
        return 1
    fi

    local rpc_url=$(echo "$vnet_details" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')

    if [ -z "$rpc_url" ] || [ "$rpc_url" = "null" ]; then
        log "ERROR" "Could not extract RPC URL from VNET details for $vnet_id"
        return 1
    fi

    echo "$rpc_url"
}

# Alias get_chain_name to get_network_name for compatibility
get_chain_name() {
    get_network_name "$1"
}

# ===== USAGE =====
usage() {
    cat << EOF
Usage: $0 <branch_name> [simulate]

Add new oracles to SuperLedgerConfiguration for vnet deployments.
Automatically loops through all chains and checks if oracles are configured.

Arguments:
    branch_name     Branch name for vnet (e.g., "demo")
    simulate        Optional: Run in simulation mode without broadcasting

Prerequisites:
    1. Run extract_configurable_oracles.sh first to create the oracle list
    2. Ensure 1Password CLI is authenticated (op signin)

Examples:
    $0 demo                    # Add oracles for demo vnet
    $0 demo simulate           # Simulate adding oracles (no broadcast)

EOF
    exit 1
}

# ===== MAIN SCRIPT =====

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

BRANCH_NAME=$1
SIMULATE_MODE=""

# Check for simulate flag
if [ $# -ge 2 ] && [ "$2" = "simulate" ]; then
    SIMULATE_MODE="simulate"
    log "INFO" "Running in SIMULATE mode (no broadcast)"
fi

log "INFO" "Adding oracles to SuperLedgerConfiguration for branch: $BRANCH_NAME"

# ===== LOAD CREDENTIALS FROM 1PASSWORD =====
log "INFO" "Loading credentials from 1Password..."

# Try to read from environment variable first, then from 1Password
if [ -n "$TENDERLY_ACCESS_KEY" ]; then
    log "INFO" "Using TENDERLY_ACCESS_KEY from environment variable"
else
    TENDERLY_ACCESS_KEY=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential" 2>/dev/null) || {
        log "ERROR" "Failed to read TENDERLY_ACCESS_KEY from 1Password"
        log "ERROR" "Please ensure 1Password CLI is authenticated: op signin"
        log "ERROR" "Or set TENDERLY_ACCESS_KEY environment variable"
        exit 1
    }
    log "INFO" "Successfully loaded Tenderly access key from 1Password"
fi

# ===== LOAD ORACLE LIST =====
ORACLE_LIST_FILE="$OUTPUT_DIR/$BRANCH_NAME/new_oracles_to_add"

if [ ! -f "$ORACLE_LIST_FILE" ]; then
    log "ERROR" "Oracle list file not found: $ORACLE_LIST_FILE"
    log "ERROR" "Please run extract_configurable_oracles.sh first:"
    log "ERROR" "  sh script/run/tooling/extract_configurable_oracles.sh $BRANCH_NAME"
    exit 1
fi

log "INFO" "Loading oracle list from: $ORACLE_LIST_FILE"

# Read oracles from file (skip comments and empty lines)
ORACLES_TO_ADD=()
while IFS= read -r line; do
    # Skip comments and empty lines
    if [[ "$line" =~ ^#.*$ ]] || [ -z "$line" ]; then
        continue
    fi
    # Trim whitespace and carriage returns
    line=$(echo "$line" | tr -d '\r' | xargs)
    ORACLES_TO_ADD+=("$line")
done < "$ORACLE_LIST_FILE"

if [ ${#ORACLES_TO_ADD[@]} -eq 0 ]; then
    log "INFO" "No oracles to add (file is empty or contains only comments)"
    exit 0
fi

log "INFO" "Found ${#ORACLES_TO_ADD[@]} oracle(s) to add:"
for oracle in "${ORACLES_TO_ADD[@]}"; do
    log "INFO" "  - $oracle"
done

# ===== DEFINE VNET CHAINS =====
# All chains for vnet deployments
VNET_CHAINS=(
    "1"       # Ethereum
    "8453"    # Base
    "10"      # Optimism
)

# ===== DETERMINE SALT NAMESPACE =====
SALT_NAMESPACE="$BRANCH_NAME"
log "INFO" "Using salt namespace: $SALT_NAMESPACE"
log "INFO" ""

# ===== PHASE 1: COLLECT ALL CHANGES =====
log "INFO" "Analyzing changes across all chains..."
log "INFO" ""

# Data structure to store changes per chain
declare -A CHAIN_CHANGES  # chain_id -> oracle count
declare -A CHAIN_ORACLES  # chain_id -> oracle names (comma separated)
declare -A CHAIN_SALTS    # chain_id -> salts (comma separated)
declare -A CHAIN_ADDRESSES # chain_id -> addresses (comma separated)
declare -A CHAIN_RPC      # chain_id -> RPC URL
declare -A CHAIN_CONFIG   # chain_id -> config address

TOTAL_CHANGES=0

for CHAIN_ID in "${VNET_CHAINS[@]}"; do
    CHAIN_NAME=$(get_chain_name "$CHAIN_ID")

    # Get RPC URL for this chain (silently)
    RPC_URL=$(get_vnet_rpc_url "$BRANCH_NAME" "$CHAIN_ID" "$TENDERLY_ACCESS_KEY" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$RPC_URL" ]; then
        continue
    fi

    # Load deployment output for this chain
    OUTPUT_FILE="$OUTPUT_DIR/$BRANCH_NAME/$CHAIN_ID/${CHAIN_NAME}-latest.json"
    if [ ! -f "$OUTPUT_FILE" ]; then
        continue
    fi

    # Read SuperLedgerConfiguration address
    CONFIG_ADDRESS=$(jq -r '.SuperLedgerConfiguration' "$OUTPUT_FILE" 2>/dev/null)
    if [ -z "$CONFIG_ADDRESS" ] || [ "$CONFIG_ADDRESS" = "null" ]; then
        continue
    fi

    # Get sender address
    SENDER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

    # Build arrays for oracles to add on this chain
    SALTS_TO_ADD=()
    ADDRESSES_TO_ADD=()
    ORACLES_ADDED=()

    for oracle_name in "${ORACLES_TO_ADD[@]}"; do
        # Get oracle address from output file
        oracle_address=$(jq -r ".[\"$oracle_name\"]" "$OUTPUT_FILE" 2>/dev/null)
        if [ -z "$oracle_address" ] || [ "$oracle_address" = "null" ]; then
            continue
        fi

        # Get oracle salt
        oracle_salt=$(get_oracle_salt "$oracle_name")

        # Compute oracle ID
        oracle_id=$(compute_oracle_id "$oracle_salt" "$SENDER_ADDRESS")

        # Check if already configured (silently)
        if check_oracle_configured "$RPC_URL" "$CONFIG_ADDRESS" "$oracle_id" 2>/dev/null; then
            continue
        fi

        # Add to arrays
        SALTS_TO_ADD+=("$oracle_salt")
        ADDRESSES_TO_ADD+=("$oracle_address")
        ORACLES_ADDED+=("$oracle_name")
    done

    # Store chain data if there are oracles to add
    if [ ${#ORACLES_ADDED[@]} -gt 0 ]; then
        CHAIN_CHANGES[$CHAIN_ID]=${#ORACLES_ADDED[@]}
        CHAIN_ORACLES[$CHAIN_ID]=$(IFS=,; echo "${ORACLES_ADDED[*]}")
        CHAIN_SALTS[$CHAIN_ID]=$(IFS=,; echo "${SALTS_TO_ADD[*]}")
        CHAIN_ADDRESSES[$CHAIN_ID]=$(IFS=,; echo "${ADDRESSES_TO_ADD[*]}")
        CHAIN_RPC[$CHAIN_ID]="$RPC_URL"
        CHAIN_CONFIG[$CHAIN_ID]="$CONFIG_ADDRESS"
        TOTAL_CHANGES=$((TOTAL_CHANGES + ${#ORACLES_ADDED[@]}))
    fi
done

# ===== PHASE 2: DISPLAY SUMMARY =====
log "INFO" ""
log "INFO" "=========================================="
log "INFO" "SUMMARY OF CHANGES"
log "INFO" "=========================================="
log "INFO" ""

if [ $TOTAL_CHANGES -eq 0 ]; then
    log "INFO" "No changes needed - all oracles are already configured on all chains."
    exit 0
fi

log "INFO" "Total oracle configurations to add: $TOTAL_CHANGES"
log "INFO" ""

for CHAIN_ID in "${VNET_CHAINS[@]}"; do
    if [ -n "${CHAIN_CHANGES[$CHAIN_ID]}" ]; then
        CHAIN_NAME=$(get_chain_name "$CHAIN_ID")
        count=${CHAIN_CHANGES[$CHAIN_ID]}
        oracles=${CHAIN_ORACLES[$CHAIN_ID]}

        log "INFO" "$CHAIN_NAME (Chain ID: $CHAIN_ID)"
        log "INFO" "  Oracle configurations to add: $count"
        IFS=',' read -ra oracle_array <<< "$oracles"
        for oracle in "${oracle_array[@]}"; do
            log "INFO" "    - $oracle"
        done
        log "INFO" ""
    fi
done

# ===== PHASE 3: ASK FOR CONFIRMATION =====
if [ -z "$SIMULATE_MODE" ]; then
    log "INFO" "=========================================="
    log "INFO" "WARNING: You are about to BROADCAST these transactions to the blockchain!"
    log "INFO" "=========================================="
    log "INFO" ""
    read -p "Do you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log "INFO" "Operation cancelled by user"
        exit 0
    fi
    log "INFO" "Proceeding with broadcast..."
else
    log "INFO" "Running in SIMULATE mode - no transactions will be broadcast"
    log "INFO" ""
    read -p "Press Enter to continue with simulation..."
    echo
fi

log "INFO" ""

# ===== PHASE 4: EXECUTE =====
log "INFO" "=========================================="
log "INFO" "EXECUTING TRANSACTIONS"
log "INFO" "=========================================="
log "INFO" ""

for CHAIN_ID in "${VNET_CHAINS[@]}"; do
    if [ -z "${CHAIN_CHANGES[$CHAIN_ID]}" ]; then
        continue
    fi

    CHAIN_NAME=$(get_chain_name "$CHAIN_ID")
    log "INFO" "Processing $CHAIN_NAME (Chain ID: $CHAIN_ID)..."

    # Rebuild arrays from stored data
    IFS=',' read -ra ORACLES_ADDED <<< "${CHAIN_ORACLES[$CHAIN_ID]}"
    IFS=',' read -ra SALTS_TO_ADD <<< "${CHAIN_SALTS[$CHAIN_ID]}"
    IFS=',' read -ra ADDRESSES_TO_ADD <<< "${CHAIN_ADDRESSES[$CHAIN_ID]}"
    RPC_URL="${CHAIN_RPC[$CHAIN_ID]}"

    # Build forge script arguments
    SALTS_ARG="["
    for i in "${!SALTS_TO_ADD[@]}"; do
        if [ $i -gt 0 ]; then
            SALTS_ARG+=","
        fi
        SALTS_ARG+="\"${SALTS_TO_ADD[$i]}\""
    done
    SALTS_ARG+="]"

    ADDRESSES_ARG="["
    for i in "${!ADDRESSES_TO_ADD[@]}"; do
        if [ $i -gt 0 ]; then
            ADDRESSES_ARG+=","
        fi
        ADDRESSES_ARG+="${ADDRESSES_TO_ADD[$i]}"
    done
    ADDRESSES_ARG+="]"

    # Determine broadcast flag
    BROADCAST_FLAG=""
    if [ -z "$SIMULATE_MODE" ]; then
        BROADCAST_FLAG="--broadcast"
    fi

    # Execute forge script
    forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
        --sig 'run(uint256,uint64,string,string,string[],address[])' \
        $FORGE_ENV \
        $CHAIN_ID \
        "$SALT_NAMESPACE" \
        "$BRANCH_NAME" \
        "$SALTS_ARG" \
        "$ADDRESSES_ARG" \
        --rpc-url "$RPC_URL" \
        $BROADCAST_FLAG \
        -vv

    if [ $? -eq 0 ]; then
        log "INFO" "✓ Successfully processed $CHAIN_NAME"
    else
        log "ERROR" "✗ Failed to process $CHAIN_NAME"
    fi
    log "INFO" ""
done

log "INFO" "=========================================="
log "INFO" "COMPLETED"
log "INFO" "=========================================="
