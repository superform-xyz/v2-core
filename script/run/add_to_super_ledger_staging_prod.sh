#!/bin/bash

# add_to_super_ledger_staging_prod.sh
# Purpose: Add new oracles to SuperLedgerConfiguration for staging/production deployments
# Usage: sh script/run/add_to_super_ledger_staging_prod.sh <environment> [simulate]

set -e

# ===== CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/script/output"

# ===== LOAD SHARED UTILITIES =====
source "$SCRIPT_DIR/oracle-utils.sh"

# ===== HELPER FUNCTIONS =====
log() {
    local level=$1
    shift
    echo "[$level] $*" >&2
}

# ===== USAGE =====
usage() {
    cat << EOF
Usage: $0 <environment> <account> [simulate]

Add new oracles to SuperLedgerConfiguration for staging/production deployments.
Automatically loops through all chains and checks if oracles are configured.

Arguments:
    environment     "staging" or "prod"
    account         Foundry wallet account name (e.g., "v2-deployer")
    simulate        Optional: Run in simulation mode without broadcasting

Prerequisites:
    1. Run extract_configurable_oracles.sh first to create the oracle list
    2. Ensure 1Password CLI is authenticated (op signin)
    3. Ensure wallet account is imported: cast wallet import <name> --private-key <key>

Examples:
    $0 staging v2-deployer                    # Add oracles for staging
    $0 staging v2-deployer simulate           # Simulate adding oracles (no broadcast)
    $0 prod v2-deployer                       # Add oracles for production

EOF
    exit 1
}

# ===== MAIN SCRIPT =====

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

ENVIRONMENT=$1
ACCOUNT=$2
SIMULATE_MODE=""

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    log "ERROR" "Invalid environment: $ENVIRONMENT"
    log "ERROR" "Environment must be 'staging' or 'prod'"
    exit 1
fi

# Check for simulate flag
if [ $# -ge 3 ] && [ "$3" = "simulate" ]; then
    SIMULATE_MODE="simulate"
    log "INFO" "Running in SIMULATE mode (no broadcast)"
fi

log "INFO" "Adding oracles to SuperLedgerConfiguration for environment: $ENVIRONMENT"
log "INFO" "Using wallet account: $ACCOUNT"

# Get sender address from wallet
SENDER_ADDRESS=$(get_wallet_address "$ACCOUNT")
if [ $? -ne 0 ] || [ -z "$SENDER_ADDRESS" ]; then
    log "ERROR" "Failed to get address from wallet account: $ACCOUNT"
    log "ERROR" "Please ensure the wallet is imported: cast wallet import $ACCOUNT --private-key <key>"
    exit 1
fi

log "INFO" "Sender address: $SENDER_ADDRESS"

# Set forge environment
if [ "$ENVIRONMENT" = "staging" ]; then
    FORGE_ENV=2
    ENV_DIR="staging"
    ENV_ID="2"
elif [ "$ENVIRONMENT" = "prod" ]; then
    FORGE_ENV=0
    ENV_DIR="production"
    ENV_ID="0"
fi

# ===== LOAD NETWORK CONFIGURATION =====
# Map environment to network file name
if [ "$ENVIRONMENT" = "prod" ]; then
    NETWORKS_FILE="$SCRIPT_DIR/networks-production.sh"
else
    NETWORKS_FILE="$SCRIPT_DIR/networks-$ENVIRONMENT.sh"
fi

if [ ! -f "$NETWORKS_FILE" ]; then
    log "ERROR" "Network configuration file not found: $NETWORKS_FILE"
    exit 1
fi

log "INFO" "Loading network configuration from: $NETWORKS_FILE"
source "$NETWORKS_FILE"

# The networks file provides:
# - NETWORKS array with network definitions
# - get_network_name() function
# - get_rpc_var() function
# - get_rpc_url() function (uses RPC environment variables)
# - load_rpc_urls() function (loads RPC URLs from 1Password)
# - is_network_supported() function

log "INFO" "Network configuration loaded successfully"

# Load RPC URLs from 1Password using the networks file function
log "INFO" "Loading RPC URLs from 1Password..."
if ! load_rpc_urls; then
    log "ERROR" "Failed to load RPC URLs from 1Password"
    exit 1
fi
log "INFO" "RPC URLs loaded successfully"

# ===== LOAD ORACLE LIST =====
ORACLE_LIST_FILE="$OUTPUT_DIR/$ENV_DIR/new_oracles_to_add"

if [ ! -f "$ORACLE_LIST_FILE" ]; then
    log "ERROR" "Oracle list file not found: $ORACLE_LIST_FILE"
    log "ERROR" "Please run extract_configurable_oracles.sh first:"
    log "ERROR" "  sh script/run/extract_configurable_oracles.sh $ENVIRONMENT $ENVIRONMENT $ACCOUNT"
    exit 1
fi

log "INFO" "Loading oracle list from: $ORACLE_LIST_FILE"

# Read oracles from file (skip comments and empty lines)
ORACLES_TO_ADD=()
while IFS= read -r line; do
    if [[ "$line" =~ ^#.*$ ]] || [ -z "$line" ]; then
        continue
    fi
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

# ===== LOOP THROUGH ALL CHAINS =====
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r CHAIN_ID CHAIN_NAME RPC_VAR <<< "$network_def"

    log "INFO" ""
    log "INFO" "=========================================="
    log "INFO" "Processing chain: $CHAIN_NAME (ID: $CHAIN_ID)"
    log "INFO" "=========================================="

    # Get RPC URL using the function from networks file or direct variable
    RPC_URL=$(get_rpc_url "$CHAIN_ID" 2>/dev/null) || RPC_URL="${!RPC_VAR}"

    if [ -z "$RPC_URL" ]; then
        log "ERROR" "Failed to get RPC URL for chain $CHAIN_ID, skipping..."
        continue
    fi
    log "INFO" "RPC URL configured"

    # Load deployment output for this chain
    OUTPUT_FILE="$OUTPUT_DIR/$ENV_DIR/$ENV_ID/${CHAIN_NAME}-latest.json"
    if [ ! -f "$OUTPUT_FILE" ]; then
        log "WARN" "Output file not found: $OUTPUT_FILE, skipping chain..."
        continue
    fi

    log "INFO" "Loading deployment output: $OUTPUT_FILE"

    # Read SuperLedgerConfiguration address
    CONFIG_ADDRESS=$(jq -r '.SuperLedgerConfiguration' "$OUTPUT_FILE")
    if [ -z "$CONFIG_ADDRESS" ] || [ "$CONFIG_ADDRESS" = "null" ]; then
        log "ERROR" "SuperLedgerConfiguration address not found in output, skipping chain..."
        continue
    fi
    log "INFO" "SuperLedgerConfiguration: $CONFIG_ADDRESS"

    # Build arrays for oracles to add on this chain
    SALTS_TO_ADD=()
    ADDRESSES_TO_ADD=()
    ORACLES_ADDED=()

    for oracle_name in "${ORACLES_TO_ADD[@]}"; do
        log "INFO" "Processing oracle: $oracle_name"

        # Get oracle address from output file
        oracle_address=$(jq -r ".[\"$oracle_name\"]" "$OUTPUT_FILE")
        if [ -z "$oracle_address" ] || [ "$oracle_address" = "null" ]; then
            log "WARN" "Oracle $oracle_name not found in deployment output, skipping..."
            continue
        fi
        log "INFO" "  Address: $oracle_address"

        # Get oracle salt
        oracle_salt=$(get_oracle_salt "$oracle_name")
        log "INFO" "  Salt: $oracle_salt"

        # Compute oracle ID
        oracle_id=$(compute_oracle_id "$oracle_salt" "$SENDER_ADDRESS")
        log "INFO" "  Oracle ID: $oracle_id"

        # Check if already configured
        if check_oracle_configured "$RPC_URL" "$CONFIG_ADDRESS" "$oracle_id"; then
            log "INFO" "  Status: Already configured, skipping"
            continue
        fi

        # Add to arrays
        SALTS_TO_ADD+=("$oracle_salt")
        ADDRESSES_TO_ADD+=("$oracle_address")
        ORACLES_ADDED+=("$oracle_name")
        log "INFO" "  Status: Will add to configuration"
    done

    # Check if there are oracles to add
    if [ ${#SALTS_TO_ADD[@]} -eq 0 ]; then
        log "INFO" "All oracles already configured on chain $CHAIN_NAME, skipping..."
        continue
    fi

    log "INFO" "Will add ${#SALTS_TO_ADD[@]} oracle(s) on chain $CHAIN_NAME:"
    for oracle in "${ORACLES_ADDED[@]}"; do
        log "INFO" "  - $oracle"
    done

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

    log "INFO" "Executing forge script..."
    log "INFO" "  Salts: $SALTS_ARG"
    log "INFO" "  Addresses: $ADDRESSES_ARG"

    # Execute forge script with wallet account authentication
    # Note: Empty strings for salt namespace and branch name for staging/prod
    forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
        --sig 'run(uint256,uint64,string,string,string[],address[])' \
        $FORGE_ENV \
        $CHAIN_ID \
        "" \
        "" \
        "$SALTS_ARG" \
        "$ADDRESSES_ARG" \
        --rpc-url "$RPC_URL" \
        --account "$ACCOUNT" \
        $BROADCAST_FLAG \
        -vv

    if [ $? -eq 0 ]; then
        log "INFO" "Successfully processed chain $CHAIN_NAME"
    else
        log "ERROR" "Failed to process chain $CHAIN_NAME"
    fi
done

log "INFO" ""
log "INFO" "=========================================="
log "INFO" "Completed processing all chains"
log "INFO" "=========================================="
