#!/usr/bin/env bash

# Colors for better visual output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Function to print colored header
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}          🔧 Add To SuperLedger Configuration Script (VNET) 🔧                    ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print network configuration header
print_network_header() {
    local network=$1
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                 🔧 Adding Oracle to SuperLedger on ${network} Network 🔧            ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Function to check if output files exist for configuration
check_deployment_files() {
    local network_name=$1
    local network_id=$2
    local branch_name=$3

    local contracts_file="script/output/$branch_name/$network_id/$network_name-latest.json"

    if [ ! -f "$contracts_file" ]; then
        log "ERROR" "Deployment file not found: $contracts_file"
        log "ERROR" "Please ensure the core contracts have been deployed first"
        return 1
    fi

    # Validate the file contains required contracts
    if ! jq -e '.SuperLedgerConfiguration' "$contracts_file" >/dev/null 2>&1; then
        log "ERROR" "SuperLedgerConfiguration not found in $contracts_file"
        return 1
    fi

    log "INFO" "Deployment file validated: $contracts_file"
    return 0
}

print_header

# Ensure we're running from the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Change to repository root if not already there
if [ "$(pwd)" != "$REPO_ROOT" ]; then
    echo -e "${YELLOW}📁 Changing to repository root: $REPO_ROOT${NC}"
    cd "$REPO_ROOT"
fi

# Tenderly Configuration
API_BASE_URL="https://api.tenderly.co/api/v1"
TENDERLY_ACCOUNT="superform"
TENDERLY_PROJECT="v2"

# Hardcoded VNET networks (based on deploy_v2_vnet_s3.sh)
declare -A VNET_NETWORKS
VNET_NETWORKS["Ethereum"]="1"
VNET_NETWORKS["Base"]="8453"
VNET_NETWORKS["Optimism"]="10"

# Function to generate slug for vnet
generate_slug() {
    local network=$1
    local branch=$2
    local output="${branch//\//-}-${network}"
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    output=$(echo "$output" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "$output"
}

# Function to get network name slug for Tenderly
get_network_slug() {
    local chain_id=$1
    case "$chain_id" in
        1) echo "ethereum" ;;
        8453) echo "base" ;;
        10) echo "optimism" ;;
        *) echo "unknown" ;;
    esac
}

# Function to get vnet RPC URL from Tenderly
get_vnet_rpc_url() {
    local branch_name=$1
    local chain_id=$2
    local access_key=$3

    if [ -z "$access_key" ]; then
        log "ERROR" "Tenderly access key not provided"
        return 1
    fi

    local network_slug=$(get_network_slug "$chain_id")
    local slug=$(generate_slug "$network_slug" "$branch_name")

    log "INFO" "Looking up vnet with slug: $slug"

    # Get list of all VNETs from Tenderly
    local vnet_list
    vnet_list=$(curl -s -X GET \
        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets" \
        -H "X-Access-Key: ${access_key}")

    # Find vnet with matching slug
    local vnet_id
    vnet_id=$(echo "$vnet_list" | jq -r --arg slug "$slug" '.[] | select(.slug==$slug) | .id // empty')

    if [ -z "$vnet_id" ]; then
        log "ERROR" "No vnet found with slug: $slug"
        return 1
    fi

    log "INFO" "Found vnet with ID: $vnet_id"

    # Get vnet details to extract RPC URL
    local vnet_details
    vnet_details=$(curl -s -X GET \
        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
        -H "X-Access-Key: ${access_key}")

    # Extract Admin RPC URL
    local admin_rpc
    admin_rpc=$(echo "$vnet_details" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')

    if [ -n "$admin_rpc" ]; then
        log "INFO" "Successfully extracted admin RPC: $admin_rpc"
        echo "$admin_rpc"
        return 0
    else
        log "ERROR" "Could not extract Admin RPC from vnet details"
        return 1
    fi
}

# Check if first argument is "simulate"
if [ "$1" = "simulate" ]; then
    MODE="simulate"
    shift # Remove "simulate" from arguments
else
    MODE="add"
fi

# Check if arguments are provided
if [ $# -lt 4 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 [simulate] <chain_id> <network_name> <branch_name> <salts> <oracle_addresses>${NC}"
    echo -e "${CYAN}  simulate: Optional flag to run in simulation mode (no broadcast)${NC}"
    echo -e "${CYAN}  chain_id: Network chain ID (e.g., 1 for Ethereum, 8453 for Base)${NC}"
    echo -e "${CYAN}  network_name: Network name (e.g., Ethereum, Base, Optimism)${NC}"
    echo -e "${CYAN}  branch_name: Branch name for vnet deployments (e.g., demo, dev, local)${NC}"
    echo -e "${CYAN}  salts: Comma-separated list of salts (e.g., \"SUPER_VAULT_ORACLE,ANOTHER_ORACLE\")${NC}"
    echo -e "${CYAN}  oracle_addresses: Comma-separated list of oracle addresses${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  # VNET - Simulate first${NC}"
    echo -e "${CYAN}  $0 simulate 1 Ethereum demo \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # VNET - Actually execute${NC}"
    echo -e "${CYAN}  $0 1 Ethereum demo \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # Multiple oracles${NC}"
    echo -e "${CYAN}  $0 8453 Base demo \"SUPER_VAULT_ORACLE,PENDLE_ORACLE\" \"0x1234...,0x5678...\"${NC}"
    exit 1
fi

CHAIN_ID=$1
NETWORK_NAME=$2
BRANCH_NAME=$3
SALTS_INPUT=$4
ORACLE_ADDRESSES_INPUT=$5

# Set environment variable for forge script (always vnet)
FORGE_ENV=1

###################################################################################
# Authentication Setup
###################################################################################

# Load Tenderly credentials from 1Password
log "INFO" "Loading Tenderly credentials from 1Password..."
TENDERLY_ACCESS_KEY=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential")
if [ -z "$TENDERLY_ACCESS_KEY" ]; then
    log "ERROR" "Failed to read Tenderly access key from 1Password"
    log "ERROR" "Please ensure 1Password CLI is installed and authenticated"
    exit 1
fi
log "INFO" "Successfully loaded Tenderly credentials"

# Validate network is supported
if [ -z "${VNET_NETWORKS[$NETWORK_NAME]}" ]; then
    echo -e "${RED}❌ Invalid network: $NETWORK_NAME${NC}"
    echo -e "${YELLOW}Supported VNET networks: ${!VNET_NETWORKS[@]}${NC}"
    exit 1
fi

# Validate chain ID matches network
if [ "${VNET_NETWORKS[$NETWORK_NAME]}" != "$CHAIN_ID" ]; then
    echo -e "${RED}❌ Chain ID mismatch: $NETWORK_NAME should have chain ID ${VNET_NETWORKS[$NETWORK_NAME]}, not $CHAIN_ID${NC}"
    exit 1
fi

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode for vnet...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - Configuration will be simulated only${NC}"
    BROADCAST_FLAG=""
else
    echo -e "${GREEN}🚀 Running in add mode for vnet...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - Oracle will be added to SuperLedger${NC}"
    BROADCAST_FLAG="--broadcast"
fi

print_separator
echo -e "${BLUE}🔧 Configuration Details...${NC}"
echo -e "${CYAN}   • Environment: vnet${NC}"
echo -e "${CYAN}   • Chain ID: $CHAIN_ID${NC}"
echo -e "${CYAN}   • Network: $NETWORK_NAME${NC}"
echo -e "${CYAN}   • Branch Name: $BRANCH_NAME${NC}"
echo -e "${CYAN}   • Mode: $MODE${NC}"
echo -e "${CYAN}   • Salts: $SALTS_INPUT${NC}"
echo -e "${CYAN}   • Oracle Addresses: $ORACLE_ADDRESSES_INPUT${NC}"
print_separator

# Convert comma-separated strings to arrays
IFS=',' read -ra SALTS_ARRAY <<< "$SALTS_INPUT"
IFS=',' read -ra ORACLE_ADDRESSES_ARRAY <<< "$ORACLE_ADDRESSES_INPUT"

# Validate arrays have same length
if [ ${#SALTS_ARRAY[@]} -ne ${#ORACLE_ADDRESSES_ARRAY[@]} ]; then
    echo -e "${RED}❌ Error: Number of salts (${#SALTS_ARRAY[@]}) does not match number of oracle addresses (${#ORACLE_ADDRESSES_ARRAY[@]})${NC}"
    exit 1
fi

echo -e "${CYAN}   • Number of oracles to add: ${#SALTS_ARRAY[@]}${NC}"

# Build the Forge script arguments
# Convert arrays to bytes32[] and address[] format for Solidity
SALTS_ARG="["
ADDRESSES_ARG="["

for i in "${!SALTS_ARRAY[@]}"; do
    # Convert salt string to bytes32 format
    SALT="${SALTS_ARRAY[$i]}"
    # Trim whitespace
    SALT=$(echo "$SALT" | xargs)

    # Convert to bytes32 (will be handled by the script)
    if [ $i -gt 0 ]; then
        SALTS_ARG+=","
    fi
    SALTS_ARG+="\"$SALT\""

    # Add address
    ADDRESS="${ORACLE_ADDRESSES_ARRAY[$i]}"
    # Trim whitespace
    ADDRESS=$(echo "$ADDRESS" | xargs)

    if [ $i -gt 0 ]; then
        ADDRESSES_ARG+=","
    fi
    ADDRESSES_ARG+="$ADDRESS"
done

SALTS_ARG+="]"
ADDRESSES_ARG+="]"

echo -e "${CYAN}   • Salts Array: $SALTS_ARG${NC}"
echo -e "${CYAN}   • Addresses Array: $ADDRESSES_ARG${NC}"
print_separator

# Check deployment files
echo -e "${BLUE}🔍 Validating deployment files...${NC}"
check_deployment_files "$NETWORK_NAME" "$CHAIN_ID" "$BRANCH_NAME"
if [ $? -ne 0 ]; then
    exit 1
fi
echo -e "${GREEN}✅ Deployment files validated${NC}"
print_separator

# Get salt namespace from environment variable or derive from network
if [ -z "${SALT_NAMESPACE:-}" ]; then
    case "$CHAIN_ID" in
        1)
            SALT_NAMESPACE=$(grep -oP 'ETH_SALT="\K[^"]+' script/run/deploy_v2_vnet_s3.sh 2>/dev/null || echo "")
            ;;
        8453)
            SALT_NAMESPACE=$(grep -oP 'BASE_SALT="\K[^"]+' script/run/deploy_v2_vnet_s3.sh 2>/dev/null || echo "")
            ;;
        10)
            SALT_NAMESPACE=$(grep -oP 'OPTIMISM_SALT="\K[^"]+' script/run/deploy_v2_vnet_s3.sh 2>/dev/null || echo "")
            ;;
        *)
            SALT_NAMESPACE=""
            ;;
    esac

    # If still empty and we have a branch name, use the branch name as salt namespace
    if [ -z "$SALT_NAMESPACE" ] && [ -n "$BRANCH_NAME" ]; then
        SALT_NAMESPACE="$BRANCH_NAME"
        log "INFO" "Using branch name as salt namespace: $SALT_NAMESPACE"
    fi
fi

# Get RPC URL from Tenderly vnet
echo -e "${CYAN}🔍 Fetching vnet RPC URL from Tenderly...${NC}"
RPC_URL=$(get_vnet_rpc_url "$BRANCH_NAME" "$CHAIN_ID" "$TENDERLY_ACCESS_KEY")
if [ $? -ne 0 ] || [ -z "$RPC_URL" ]; then
    echo -e "${RED}❌ Error: Failed to get vnet RPC URL from Tenderly${NC}"
    exit 1
fi

print_network_header "${NETWORK_NAME^^}"
echo -e "${CYAN}   Chain ID: ${WHITE}$CHAIN_ID${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${CYAN}   Environment: ${WHITE}vnet${NC}"
echo -e "${CYAN}   Branch Name: ${WHITE}$BRANCH_NAME${NC}"
if [ -n "$SALT_NAMESPACE" ]; then
    echo -e "${CYAN}   Salt Namespace: ${WHITE}$SALT_NAMESPACE${NC}"
fi
echo -e "${YELLOW}   Executing forge script...${NC}"

# Set defaults for optional parameters
SALT_NS="${SALT_NAMESPACE:-}"
BRANCH="${BRANCH_NAME:-}"

forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
    --sig 'run(uint256,uint64,string,string,string[],address[])' $FORGE_ENV $CHAIN_ID "$SALT_NS" "$BRANCH" "$SALTS_ARG" "$ADDRESSES_ARG" \
    --rpc-url "$RPC_URL" \
    $BROADCAST_FLAG \
    -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ $NETWORK_NAME configuration completed successfully!${NC}"
else
    echo -e "${RED}❌ Configuration failed!${NC}"
    exit 1
fi

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}            🎉 Oracle Addition to SuperLedger $MODE Completed! 🎉                  ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${CYAN}🔧 Added ${#SALTS_ARRAY[@]} oracle(s) to SuperLedger configuration on:${NC}"
echo -e "${CYAN}   • $NETWORK_NAME (Chain ID: $CHAIN_ID)${NC}"
print_separator
