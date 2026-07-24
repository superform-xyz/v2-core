#!/bin/bash

# add_to_super_ledger_staging_prod.sh
# Purpose: Add new oracles to SuperLedgerConfiguration for staging/production deployments
# Usage: sh script/run/config/add_to_super_ledger_staging_prod.sh <environment> [simulate]

set -e

# ===== CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/script/output"

# Default Fireblocks sender address — overridden per-chain via get_fireblocks_sender()
FIREBLOCKS_SENDER_DEFAULT="0x28b7599f461D104f07D78215Fa6F9B959851f93d"

# ===== LOAD SHARED UTILITIES =====
source "$SCRIPT_DIR/../utils/oracle-utils.sh"

# ===== HELPER FUNCTIONS =====
log() {
    local level=$1
    shift
    echo "[$level] $*" >&2
}

# ===== USAGE =====
usage() {
    cat << EOF
Usage: $0 <environment> [simulate] [--chains <chain_ids>]

Add new oracles to SuperLedgerConfiguration for staging/production deployments.
Automatically loops through all chains and checks if oracles are configured.
Uses Fireblocks MPC wallet for transaction signing.

Arguments:
    environment     "staging" or "prod"
    simulate        Optional: Run in simulation mode without broadcasting
    --chains        Optional: Comma-separated chain IDs to target (default: all chains)

Prerequisites:
    1. Run extract_configurable_oracles.sh first to create the oracle list
    2. Ensure 1Password CLI is authenticated (op signin)
    3. Fireblocks credentials configured in 1Password

Examples:
    $0 staging                          # Add oracles for staging (all chains)
    $0 staging simulate                 # Simulate adding oracles (no broadcast)
    $0 prod                             # Add oracles for production (all chains)
    $0 prod --chains 56,42161           # Add oracles only on BSC and Arbitrum
    $0 prod simulate --chains 56,42161  # Simulate on BSC and Arbitrum only

EOF
    exit 1
}

# ===== MAIN SCRIPT =====

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

ENVIRONMENT=$1
SIMULATE_MODE=""

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    log "ERROR" "Invalid environment: $ENVIRONMENT"
    log "ERROR" "Environment must be 'staging' or 'prod'"
    exit 1
fi

# Parse optional flags
CHAIN_FILTER=""
for arg in "${@:2}"; do
    if [ "$arg" = "simulate" ]; then
        SIMULATE_MODE="simulate"
        log "INFO" "Running in SIMULATE mode (no broadcast)"
    elif [[ "$arg" == --chains ]]; then
        # Next arg will be the chain list — handled below
        :
    elif [[ "$prev_arg" == --chains ]]; then
        CHAIN_FILTER="$arg"
    fi
    prev_arg="$arg"
done

# Also handle --chains=56,42161 form
for arg in "${@:2}"; do
    if [[ "$arg" == --chains=* ]]; then
        CHAIN_FILTER="${arg#--chains=}"
    fi
done

if [ -n "$CHAIN_FILTER" ]; then
    log "INFO" "Filtering to chains: $CHAIN_FILTER"
fi

log "INFO" "Adding oracles to SuperLedgerConfiguration for environment: $ENVIRONMENT"
log "INFO" "Using Fireblocks MPC wallet for transaction signing"
log "INFO" "Default sender address: $FIREBLOCKS_SENDER_DEFAULT (per-chain override for Flare)"

# Set forge environment
if [ "$ENVIRONMENT" = "staging" ]; then
    FORGE_ENV=2
    ENV_DIR="staging"
elif [ "$ENVIRONMENT" = "prod" ]; then
    FORGE_ENV=0
    ENV_DIR="prod"
fi

# ===== LOAD NETWORK CONFIGURATION =====
# Map environment to network file name
if [ "$ENVIRONMENT" = "prod" ]; then
    NETWORKS_FILE="$SCRIPT_DIR/../utils/networks-production.sh"
else
    NETWORKS_FILE="$SCRIPT_DIR/../utils/networks-$ENVIRONMENT.sh"
fi

if [ ! -f "$NETWORKS_FILE" ]; then
    log "ERROR" "Network configuration file not found: $NETWORKS_FILE"
    exit 1
fi

log "INFO" "Loading network configuration from: $NETWORKS_FILE"
source "$NETWORKS_FILE"

log "INFO" "Network configuration loaded successfully"

# ===== LOAD RPC URLs FROM 1PASSWORD =====
log "INFO" "Loading RPC URLs from 1Password..."
if ! load_rpc_urls; then
    log "ERROR" "Failed to load RPC URLs from 1Password"
    exit 1
fi
log "INFO" "RPC URLs loaded successfully"

# ===== LOAD FIREBLOCKS CREDENTIALS =====
log "INFO" "Loading Fireblocks credentials from 1Password..."
export FIREBLOCKS_API_KEY=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_ACTION/credential)
export FIREBLOCKS_API_PRIVATE_KEY_PATH=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_SECRET/notesPlain)
export FIREBLOCKS_VAULT_ACCOUNT_IDS=29  # SuperLedger Config Vault Account

if [ -z "$FIREBLOCKS_API_KEY" ]; then
    log "ERROR" "Failed to load Fireblocks API key from 1Password"
    exit 1
fi

log "INFO" "Fireblocks credentials loaded successfully"

# ===== LOAD ORACLE LIST =====
ORACLE_LIST_FILE="$OUTPUT_DIR/$ENV_DIR/new_oracles_to_add"

if [ ! -f "$ORACLE_LIST_FILE" ]; then
    log "ERROR" "Oracle list file not found: $ORACLE_LIST_FILE"
    log "ERROR" "Please run extract_configurable_oracles.sh first:"
    log "ERROR" "  sh script/run/tooling/extract_configurable_oracles.sh $ENVIRONMENT v2-deployer"
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

# ===== LOOP THROUGH CHAINS =====
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r CHAIN_ID CHAIN_NAME RPC_VAR <<< "$network_def"

    # Apply chain filter if specified
    if [ -n "$CHAIN_FILTER" ]; then
        if ! echo ",$CHAIN_FILTER," | grep -q ",$CHAIN_ID,"; then
            continue
        fi
    fi

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

    # Set Fireblocks RPC environment variables for this chain
    export FIREBLOCKS_RPC_URL="$RPC_URL"
    export FIREBLOCKS_CHAIN_ID="$CHAIN_ID"

    # Set Fireblocks asset ID for chains not auto-detected
    case $CHAIN_ID in
        988) export FIREBLOCKS_ASSET_ID="GUSDT_STABLE" ;;
        *)   unset FIREBLOCKS_ASSET_ID ;;
    esac

    # Resolve per-chain sender (Flare uses a different Fireblocks vault derivation)
    CHAIN_SENDER=$(get_fireblocks_sender "$CHAIN_ID")
    TX_TYPE_FLAG=""
    if [ "$CHAIN_ID" = "14" ]; then
        TX_TYPE_FLAG="--legacy"
    fi
    log "INFO" "Sender: $CHAIN_SENDER"

    # Load deployment output for this chain
    OUTPUT_FILE="$OUTPUT_DIR/$ENV_DIR/$CHAIN_ID/${CHAIN_NAME}-latest.json"
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

        # Compute oracle ID using per-chain Fireblocks sender address
        oracle_id=$(compute_oracle_id "$oracle_salt" "$CHAIN_SENDER")
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

    log "INFO" "Executing forge script via Fireblocks..."
    log "INFO" "  Salts: $SALTS_ARG"
    log "INFO" "  Addresses: $ADDRESSES_ARG"

    # Execute forge script with Fireblocks
    # Note: Empty strings for salt namespace and branch name for staging/prod
    fireblocks-json-rpc --http -- forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
        --sig 'run(uint256,uint64,string,string,string[],address[])' \
        $FORGE_ENV \
        $CHAIN_ID \
        "" \
        "" \
        "$SALTS_ARG" \
        "$ADDRESSES_ARG" \
        --rpc-url {} \
        --sender "$CHAIN_SENDER" \
        $BROADCAST_FLAG \
        $TX_TYPE_FLAG \
        --unlocked \
        --slow \
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
