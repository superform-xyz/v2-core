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
    echo -e "${CYAN}║${WHITE}     🔧 Add To SuperLedger Configuration Script (Staging/Production) 🔧           ${CYAN}║${NC}"
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
    local environment=$1
    local network_name=$2
    local network_id=$3

    local contracts_file="script/output/$environment/$network_id/$network_name-latest.json"

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

# Check if first argument is "simulate"
if [ "$1" = "simulate" ]; then
    MODE="simulate"
    shift # Remove "simulate" from arguments
else
    MODE="add"
fi

# Check if arguments are provided
if [ $# -lt 5 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 [simulate] <environment> <chain_id> <network_name> <account> <salts> <oracle_addresses>${NC}"
    echo -e "${CYAN}  simulate: Optional flag to run in simulation mode (no broadcast)${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  chain_id: Network chain ID (e.g., 1 for Ethereum, 8453 for Base)${NC}"
    echo -e "${CYAN}  network_name: Network name (e.g., Ethereum, Base, Optimism)${NC}"
    echo -e "${CYAN}  account: foundry account name (e.g., v2-deployer, deployer, main)${NC}"
    echo -e "${CYAN}  salts: Comma-separated list of salts (e.g., \"SUPER_VAULT_ORACLE,ANOTHER_ORACLE\")${NC}"
    echo -e "${CYAN}  oracle_addresses: Comma-separated list of oracle addresses${NC}"
    echo -e "${CYAN}Available accounts: $(cast wallet list 2>/dev/null | sed 's/ (Local)//' | tr '\n' ' ' || echo 'Run \"cast wallet list\" to see available accounts')${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  # Staging - Simulate first${NC}"
    echo -e "${CYAN}  $0 simulate staging 1 Ethereum v2-deployer \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # Staging - Actually execute${NC}"
    echo -e "${CYAN}  $0 staging 1 Ethereum v2-deployer \"SUPER_VAULT_ORACLE\" \"0x1234...\"${NC}"
    echo -e "${CYAN}  # Production - Multiple oracles${NC}"
    echo -e "${CYAN}  $0 prod 8453 Base v2-deployer \"SUPER_VAULT_ORACLE,PENDLE_ORACLE\" \"0x1234...,0x5678...\"${NC}"
    exit 1
fi

ENVIRONMENT=$1
CHAIN_ID=$2
NETWORK_NAME=$3
ACCOUNT=$4
SALTS_INPUT=$5
ORACLE_ADDRESSES_INPUT=$6

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be 'staging' or 'prod'${NC}"
    exit 1
fi

# Set environment variable for forge script
if [ "$ENVIRONMENT" = "staging" ]; then
    FORGE_ENV=2
else
    FORGE_ENV=0
fi

###################################################################################
# Load Network Configuration
###################################################################################

# Source the appropriate network configuration file
if [ "$ENVIRONMENT" = "staging" ]; then
    NETWORKS_FILE="$SCRIPT_DIR/networks-staging.sh"
else
    NETWORKS_FILE="$SCRIPT_DIR/networks-production.sh"
fi

if [ ! -f "$NETWORKS_FILE" ]; then
    log "ERROR" "Network configuration file not found: $NETWORKS_FILE"
    exit 1
fi

log "INFO" "Sourcing network configuration from: $NETWORKS_FILE"
source "$NETWORKS_FILE"

# Validate network is supported
if ! is_network_supported "$CHAIN_ID"; then
    echo -e "${RED}❌ Network with chain ID $CHAIN_ID is not supported in $ENVIRONMENT environment${NC}"
    echo -e "${YELLOW}Supported networks:${NC}"
    print_network_info
    exit 1
fi

# Validate account exists in foundry wallet list
if ! cast wallet list 2>/dev/null | sed 's/ (Local)//' | grep -q "^$ACCOUNT$"; then
    echo -e "${RED}❌ Account '$ACCOUNT' not found in foundry wallet list${NC}"
    echo -e "${YELLOW}Available accounts:${NC}"
    cast wallet list 2>/dev/null | sed 's/ (Local)//' | sed 's/^/  • /' || echo -e "${RED}  No accounts found. Run 'cast wallet import' to add accounts.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Account '$ACCOUNT' validated${NC}"

###################################################################################
# Authentication Setup
###################################################################################

# Load RPC URLs from 1Password
log "INFO" "Loading RPC URLs from 1Password..."
if ! load_rpc_urls; then
    log "ERROR" "Failed to load RPC URLs from 1Password"
    log "ERROR" "Please ensure 1Password CLI is installed and authenticated"
    exit 1
fi
log "INFO" "Successfully loaded RPC URLs"

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - Configuration will be simulated only${NC}"
    BROADCAST_FLAG=""
else
    echo -e "${GREEN}🚀 Running in add mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - Oracle will be added to SuperLedger${NC}"
    BROADCAST_FLAG="--broadcast"
fi

print_separator
echo -e "${BLUE}🔧 Configuration Details...${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}   • Chain ID: $CHAIN_ID${NC}"
echo -e "${CYAN}   • Network: $NETWORK_NAME${NC}"
echo -e "${CYAN}   • Mode: $MODE${NC}"
echo -e "${CYAN}   • Account: $ACCOUNT${NC}"
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
check_deployment_files "$ENVIRONMENT" "$NETWORK_NAME" "$CHAIN_ID"
if [ $? -ne 0 ]; then
    exit 1
fi
echo -e "${GREEN}✅ Deployment files validated${NC}"
print_separator

# Get RPC URL from network configuration
RPC_URL=$(get_rpc_url "$CHAIN_ID")

# Validate RPC URL is set
if [ -z "$RPC_URL" ]; then
    echo -e "${RED}❌ Error: RPC_URL not set for chain ID $CHAIN_ID${NC}"
    echo -e "${YELLOW}Please set the RPC_URL environment variable or ensure 1Password CLI is configured.${NC}"
    echo -e "${CYAN}Options:${NC}"
    echo -e "${CYAN}  1. Use 1Password CLI: op signin${NC}"
    echo -e "${CYAN}  2. Set specific RPC URL: export RPC_URL=\"your-rpc-url\"${NC}"
    echo -e "${CYAN}  3. Set network-specific variable:${NC}"
    RPC_VAR=$(get_rpc_var "$CHAIN_ID")
    echo -e "${CYAN}     - export $RPC_VAR=\"your-rpc\"${NC}"
    exit 1
fi

# Load Etherscan API key for verification
echo -e "${CYAN}   • Loading Etherscan API key for verification...${NC}"
if ! load_etherscan_api_key; then
    log "WARN" "Could not load Etherscan API key - contract verification may not work"
else
    echo -e "${GREEN}✅ Etherscan API key loaded${NC}"
fi

print_network_header "${NETWORK_NAME^^}"
echo -e "${CYAN}   Chain ID: ${WHITE}$CHAIN_ID${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

# Always use the unified signature with all parameters (empty strings for optional ones)
SALT_NS="${SALT_NAMESPACE:-}"
BRANCH="${BRANCH_NAME:-}"

forge script script/AddToSuperLedgerConfiguration.s.sol:AddToSuperLedgerConfiguration \
    --sig 'run(uint256,uint64,string,string,string[],address[])' $FORGE_ENV $CHAIN_ID "$SALT_NS" "$BRANCH" "$SALTS_ARG" "$ADDRESSES_ARG" \
    --account $ACCOUNT \
    --rpc-url "$RPC_URL" \
    --chain $CHAIN_ID \
    --etherscan-api-key $ETHERSCANV2_API_KEY \
    --verifier etherscan \
    $BROADCAST_FLAG \
    --slow \
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
echo -e "${CYAN}🔑 Transaction signed with account: $ACCOUNT${NC}"
print_separator
