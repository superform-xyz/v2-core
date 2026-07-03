#!/bin/bash

# extract_configurable_oracles.sh
# Purpose: Extract oracle names from deployment outputs and create a file of oracles to add to SuperLedgerConfiguration
# This script identifies which oracles are deployed but not yet configured in SuperLedgerConfiguration

set -e

# ===== CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/script/output"

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
Usage: $0 <environment> [account]

Extract oracles from deployment outputs that need to be added to SuperLedgerConfiguration.
Dynamically discovers deployed oracles and checks on-chain which are already configured.

Arguments:
    environment     Environment: branch name for vnet (e.g., "demo"), "staging", or "prod"
    account         Wallet account name (required for vnet only)
                    For staging/prod, Fireblocks sender address is used automatically

Output:
    Creates script/output/<environment>/new_oracles_to_add with list of oracle names
    that are deployed but not yet configured in SuperLedgerConfiguration.

Ban List:
    The following oracles are excluded from configuration:
    - PendlePTYieldSourceOracle
    - SpectraPTYieldSourceOracle
    - SuperYieldSourceOracle

Prerequisites:
    - For vnet: 1Password CLI authenticated (op signin) for Tenderly access
    - For staging/prod: 1Password CLI authenticated for RPC URLs

Examples:
    $0 staging                      # Extract oracles for staging (uses Fireblocks sender)
    $0 prod                         # Extract oracles for production (uses Fireblocks sender)
    $0 demo v2-deployer             # Extract oracles for demo vnet

EOF
    exit 1
}

# ===== MAIN SCRIPT =====

# Check arguments
if [ $# -lt 1 ]; then
    usage
fi

ENV_INPUT=$1
ACCOUNT=${2:-}  # Optional for staging/prod, required for vnet

# Determine if this is vnet, staging, or prod
if [ "$ENV_INPUT" = "prod" ]; then
    ENVIRONMENT="prod"
    BASE_OUTPUT_DIR="$OUTPUT_DIR/prod"
    FORGE_ENV=0

    # For production, use Fireblocks sender address
    SENDER_ADDRESS="0x28b7599f461D104f07D78215Fa6F9B959851f93d"
    log "INFO" "Using Fireblocks sender address for production: $SENDER_ADDRESS"

elif [ "$ENV_INPUT" = "staging" ]; then
    ENVIRONMENT="staging"
    BASE_OUTPUT_DIR="$OUTPUT_DIR/staging"
    FORGE_ENV=2

    # For staging, use Fireblocks sender address
    SENDER_ADDRESS="0x28b7599f461D104f07D78215Fa6F9B959851f93d"
    log "INFO" "Using Fireblocks sender address for staging: $SENDER_ADDRESS"

else
    # vnet - ENV_INPUT is the branch name
    ENVIRONMENT="vnet"
    BRANCH_NAME="$ENV_INPUT"
    BASE_OUTPUT_DIR="$OUTPUT_DIR/$BRANCH_NAME"
    FORGE_ENV=1

    # For vnet, account parameter is required
    if [ -z "$ACCOUNT" ]; then
        log "ERROR" "Account parameter is required for vnet environments"
        usage
    fi

    # For vnet, use Foundry test mnemonic derivation (index 0)
    # This matches the Solidity script's deriveRememberKey(MNEMONIC, 0)
    SENDER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    log "INFO" "Using Foundry test address for vnet branch '$BRANCH_NAME': $SENDER_ADDRESS"
fi

log "INFO" "Extracting configurable oracles for environment: $ENVIRONMENT"

if [ ! -d "$BASE_OUTPUT_DIR" ]; then
    log "ERROR" "Output directory not found: $BASE_OUTPUT_DIR"
    log "ERROR" "Please ensure contracts are deployed first"
    exit 1
fi

log "INFO" "Searching for deployment outputs in: $BASE_OUTPUT_DIR"

# Find one sample output file to extract oracle names
SAMPLE_FILE=$(find "$BASE_OUTPUT_DIR" -name "*-latest.json" | head -n 1)

if [ -z "$SAMPLE_FILE" ]; then
    log "ERROR" "No deployment output files found in $BASE_OUTPUT_DIR"
    exit 1
fi

log "INFO" "Using sample file: $SAMPLE_FILE"

# ===== STEP 1: DYNAMICALLY EXTRACT ALL DEPLOYED ORACLES =====
log "INFO" "Extracting deployed oracles from output files..."

# Extract all keys from JSON that end with "YieldSourceOracle"
DEPLOYED_ORACLES=()
while IFS= read -r oracle_name; do
    # Filter out empty lines and trim whitespace
    oracle_name=$(echo "$oracle_name" | xargs)
    if [ -n "$oracle_name" ]; then
        DEPLOYED_ORACLES+=("$oracle_name")
        log "INFO" "Found deployed oracle: $oracle_name"
    fi
done < <(jq -r 'keys[] | select(endswith("YieldSourceOracle"))' "$SAMPLE_FILE")

if [ ${#DEPLOYED_ORACLES[@]} -eq 0 ]; then
    log "WARN" "No oracles found in deployment outputs"
    exit 0
fi

log "INFO" "Total deployed oracles found: ${#DEPLOYED_ORACLES[@]}"

# ===== APPLY BAN LIST =====
# Oracles that should not be configured (excluded from processing)
BANNED_ORACLES=(
    "PendlePTYieldSourceOracle"
    "SpectraPTYieldSourceOracle"
    "SuperYieldSourceOracle"
)

log "INFO" "Applying ban list to exclude certain oracles..."

# Filter out banned oracles
FILTERED_ORACLES=()
for oracle in "${DEPLOYED_ORACLES[@]}"; do
    is_banned=false
    for banned in "${BANNED_ORACLES[@]}"; do
        if [ "$oracle" = "$banned" ]; then
            is_banned=true
            log "INFO" "Excluding banned oracle: $oracle"
            break
        fi
    done
    if [ "$is_banned" = false ]; then
        FILTERED_ORACLES+=("$oracle")
    else
        log "INFO" "Filtered out banned oracle: $oracle"
    fi
done

# Replace DEPLOYED_ORACLES with filtered list
DEPLOYED_ORACLES=("${FILTERED_ORACLES[@]}")

if [ ${#DEPLOYED_ORACLES[@]} -eq 0 ]; then
    log "WARN" "No oracles remaining after applying ban list"
    exit 0
fi

log "INFO" "Oracles remaining after ban list: ${#DEPLOYED_ORACLES[@]}"

# ===== STEP 2: LOAD CREDENTIALS =====
log "INFO" "Loading credentials from 1Password..."

if [ "$ENVIRONMENT" = "vnet" ]; then
    # Load Tenderly access key for vnet
    TENDERLY_ACCESS_KEY=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential" 2>/dev/null) || {
        log "ERROR" "Failed to read TENDERLY_ACCESS_KEY from 1Password"
        log "ERROR" "Please ensure 1Password CLI is authenticated: op signin"
        exit 1
    }
    log "INFO" "Successfully loaded Tenderly access key"
else
    # Load network configuration for staging/production
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

    # Load RPC URLs using networks file function
    if ! load_rpc_urls; then
        log "ERROR" "Failed to load RPC URLs from 1Password"
        exit 1
    fi
    log "INFO" "Successfully loaded RPC URLs from 1Password"
fi

# ===== STEP 3: CHECK ON-CHAIN WHICH ORACLES ARE CONFIGURED =====
log "INFO" "Checking on-chain configuration status..."

# Get a sample chain to check configuration
# Extract chain name from sample file path
SAMPLE_CHAIN_FILE=$(basename "$SAMPLE_FILE")
SAMPLE_CHAIN_NAME="${SAMPLE_CHAIN_FILE%-latest.json}"

log "INFO" "Using chain $SAMPLE_CHAIN_NAME to check oracle configuration"

# Get chain ID from chain name
case "$SAMPLE_CHAIN_NAME" in
    "Ethereum") SAMPLE_CHAIN_ID=1 ;;
    "Base") SAMPLE_CHAIN_ID=8453 ;;
    "BNB") SAMPLE_CHAIN_ID=56 ;;
    "Arbitrum") SAMPLE_CHAIN_ID=42161 ;;
    "Optimism") SAMPLE_CHAIN_ID=10 ;;
    "Polygon") SAMPLE_CHAIN_ID=137 ;;
    "Unichain") SAMPLE_CHAIN_ID=130 ;;
    "Avalanche") SAMPLE_CHAIN_ID=43114 ;;
    "Sonic") SAMPLE_CHAIN_ID=146 ;;
    "Gnosis") SAMPLE_CHAIN_ID=100 ;;
    "Worldchain") SAMPLE_CHAIN_ID=480 ;;
    *)
        log "ERROR" "Unknown chain name: $SAMPLE_CHAIN_NAME"
        exit 1
        ;;
esac

# Get RPC URL for this chain
if [ "$ENVIRONMENT" = "vnet" ]; then
    # For vnet, read VNET ID from S3 latest.json and query Tenderly API
    vnet_latest_path="/tmp/vnet_latest_$$.json"
    if aws s3 cp "s3://vnet-state/$BRANCH_NAME/latest.json" "$vnet_latest_path" --quiet 2>/dev/null; then
        VNET_ID=$(jq -r ".networks[\"$SAMPLE_CHAIN_NAME\"].vnet_id" "$vnet_latest_path")

        if [ -n "$VNET_ID" ] && [ "$VNET_ID" != "null" ]; then
            log "INFO" "Found VNET ID from S3: $VNET_ID"

            # Get RPC URL from Tenderly API using VNET ID
            vnet_details=$(curl -s -X GET \
                "https://api.tenderly.co/api/v1/account/superform/project/v2/vnets/$VNET_ID" \
                -H "X-Access-Key: $TENDERLY_ACCESS_KEY")

            RPC_URL=$(echo "$vnet_details" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')

            if [ -z "$RPC_URL" ] || [ "$RPC_URL" = "null" ]; then
                log "ERROR" "Failed to get RPC URL from VNET $VNET_ID"
                log "ERROR" "Cannot check on-chain configuration, falling back to empty list"
                NEW_ORACLES=("${DEPLOYED_ORACLES[@]}")
            else
                log "INFO" "RPC URL obtained successfully"

                # Get SuperLedgerConfiguration address
                CONFIG_ADDRESS=$(jq -r '.SuperLedgerConfiguration' "$SAMPLE_FILE")
                if [ -z "$CONFIG_ADDRESS" ] || [ "$CONFIG_ADDRESS" = "null" ]; then
                    log "ERROR" "SuperLedgerConfiguration address not found in output"
                    log "ERROR" "Cannot check on-chain configuration, falling back to empty list"
                    NEW_ORACLES=("${DEPLOYED_ORACLES[@]}")
                else
                    log "INFO" "SuperLedgerConfiguration: $CONFIG_ADDRESS"

                    # Check each oracle on-chain
                    NEW_ORACLES=()
                    for oracle_name in "${DEPLOYED_ORACLES[@]}"; do
                        oracle_salt=$(get_oracle_salt "$oracle_name")
                        oracle_id=$(compute_oracle_id "$oracle_salt" "$SENDER_ADDRESS")

                        log "INFO" "Checking $oracle_name (ID: $oracle_id)..."

                        if check_oracle_configured "$RPC_URL" "$CONFIG_ADDRESS" "$oracle_id"; then
                            log "INFO" "  ✓ Already configured (skipping)"
                        else
                            log "INFO" "  ✗ Not configured (will add)"
                            NEW_ORACLES+=("$oracle_name")
                        fi
                    done
                fi
            fi
        else
            log "ERROR" "Failed to extract VNET ID from S3 latest.json"
            log "ERROR" "Cannot check on-chain configuration, falling back to empty list"
            NEW_ORACLES=("${DEPLOYED_ORACLES[@]}")
        fi
    else
        log "ERROR" "Failed to download latest.json from S3"
        log "ERROR" "Cannot check on-chain configuration, falling back to empty list"
        NEW_ORACLES=("${DEPLOYED_ORACLES[@]}")
    fi
else
    # For staging/production, use RPC from networks file
    # Get RPC URL for the sample chain using the networks file function
    SAMPLE_RPC_URL=$(get_rpc_url "$SAMPLE_CHAIN_ID")
    if [ $? -ne 0 ] || [ -z "$SAMPLE_RPC_URL" ]; then
        log "ERROR" "Failed to get RPC URL for chain $SAMPLE_CHAIN_ID"
        log "ERROR" "Cannot check on-chain configuration, falling back to empty list"
        NEW_ORACLES=("${DEPLOYED_ORACLES[@]}")
    else
        CONFIG_ADDRESS=$(jq -r '.SuperLedgerConfiguration' "$SAMPLE_FILE")
        if [ -z "$CONFIG_ADDRESS" ] || [ "$CONFIG_ADDRESS" = "null" ]; then
            log "ERROR" "SuperLedgerConfiguration address not found in output"
            log "ERROR" "Cannot check on-chain configuration, falling back to empty list"
            NEW_ORACLES=("${DEPLOYED_ORACLES[@]}")
        else
            log "INFO" "SuperLedgerConfiguration: $CONFIG_ADDRESS"

            # Check each oracle on-chain
            NEW_ORACLES=()
            for oracle_name in "${DEPLOYED_ORACLES[@]}"; do
                oracle_salt=$(get_oracle_salt "$oracle_name")
                oracle_id=$(compute_oracle_id "$oracle_salt" "$SENDER_ADDRESS")

                log "INFO" "Checking $oracle_name (ID: $oracle_id)..."

                if check_oracle_configured "$SAMPLE_RPC_URL" "$CONFIG_ADDRESS" "$oracle_id"; then
                    log "INFO" "  ✓ Already configured (skipping)"
                else
                    log "INFO" "  ✗ Not configured (will add)"
                    NEW_ORACLES+=("$oracle_name")
                fi
            done
        fi
    fi
fi

# ===== STEP 4: CREATE OUTPUT FILE =====
# Determine output file path based on environment
if [ "$ENVIRONMENT" = "prod" ]; then
    OUTPUT_FILE="$OUTPUT_DIR/prod/new_oracles_to_add"
    ENV_DISPLAY="prod"
elif [ "$ENVIRONMENT" = "staging" ]; then
    OUTPUT_FILE="$OUTPUT_DIR/staging/new_oracles_to_add"
    ENV_DISPLAY="staging"
else
    OUTPUT_FILE="$OUTPUT_DIR/$BRANCH_NAME/new_oracles_to_add"
    ENV_DISPLAY="$BRANCH_NAME (vnet)"
fi

if [ ${#NEW_ORACLES[@]} -eq 0 ]; then
    log "INFO" "All deployed oracles are already configured"
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    echo "# No new oracles to add - all deployed oracles are already configured" > "$OUTPUT_FILE"
    log "INFO" "Created empty marker file: $OUTPUT_FILE"
    exit 0
fi

log "INFO" "Writing ${#NEW_ORACLES[@]} oracle(s) to: $OUTPUT_FILE"

# Create parent directory if needed
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Write header
cat > "$OUTPUT_FILE" << EOF
# Oracles to add to SuperLedgerConfiguration
# Generated by extract_configurable_oracles.sh
# Environment: $ENV_DISPLAY
# Generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
#
# This list was generated by:
# 1. Scanning deployment outputs for all *YieldSourceOracle contracts
# 2. Checking on-chain which oracles are already configured
# 3. Including only oracles that are deployed but not yet configured

EOF

# Write oracle names (one per line)
for oracle in "${NEW_ORACLES[@]}"; do
    echo "$oracle" >> "$OUTPUT_FILE"
done

log "INFO" "Successfully wrote ${#NEW_ORACLES[@]} oracle(s) to $OUTPUT_FILE"
log "INFO" "Oracle names:"
for oracle in "${NEW_ORACLES[@]}"; do
    log "INFO" "  - $oracle"
done

log "INFO" ""
log "INFO" "Summary:"
log "INFO" "  Total deployed oracles: ${#DEPLOYED_ORACLES[@]}"
log "INFO" "  Oracles to add: ${#NEW_ORACLES[@]}"
log "INFO" "  Already configured: $((${#DEPLOYED_ORACLES[@]} - ${#NEW_ORACLES[@]}))"
log "INFO" ""
log "INFO" "Extraction complete"
