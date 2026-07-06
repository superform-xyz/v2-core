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
    echo -e "${CYAN}║${WHITE}                   🔧 V2 SuperLedger Configuration Script 🔧                        ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}                        (Production/Staging Environments)                           ${CYAN}║${NC}"
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
    echo -e "${PURPLE}│${WHITE}                     🔧 Configuring SuperLedger on ${network} Network 🔧                ${PURPLE}│${NC}"
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
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Change to repository root if not already there
if [ "$(pwd)" != "$REPO_ROOT" ]; then
    echo -e "${YELLOW}📁 Changing to repository root: $REPO_ROOT${NC}"
    cd "$REPO_ROOT"
fi

# Network configuration will be sourced after environment is determined

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode>${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode: simulate or configure${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging simulate${NC}"
    echo -e "${CYAN}  $0 prod configure${NC}"
    exit 1
fi

ENVIRONMENT=$1
MODE=$2

# Validate environment and source appropriate network configuration
if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}🌐 Loading staging network configuration...${NC}"
    source "$SCRIPT_DIR/../utils/networks-staging.sh"
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}🌐 Loading production network configuration...${NC}"
    source "$SCRIPT_DIR/../utils/networks-production.sh"
else
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

echo -e "${CYAN}✅ Network configuration loaded for $ENVIRONMENT environment${NC}"
print_network_info

# Set environment variable for forge script
if [ "$ENVIRONMENT" = "staging" ]; then
    FORGE_ENV=2
else
    FORGE_ENV=0
fi

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - Configuration will be simulated only${NC}"
    BROADCAST_FLAG=""
elif [ "$MODE" = "configure" ]; then
    echo -e "${GREEN}🚀 Running in configuration mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - SuperLedger will be configured${NC}"
    BROADCAST_FLAG="--broadcast"
else
    echo -e "${RED}❌ Invalid mode: $MODE${NC}"
    echo -e "${YELLOW}Mode must be either 'simulate' or 'configure'${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

# Load RPC URLs using network-specific function
echo -e "${CYAN}   • Loading RPC URLs...${NC}"
load_rpc_urls

# Fireblocks configuration
echo -e "${CYAN}   • Loading Fireblocks credentials...${NC}"
export FIREBLOCKS_API_KEY=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_ACTION/credential)
export FIREBLOCKS_API_PRIVATE_KEY_PATH=$(op read op://zry2qwhqux2w6qtjitg44xb7b4/V2_SUPERLEDGER_SECRET/notesPlain)
export FIREBLOCKS_VAULT_ACCOUNT_IDS=29  # SuperLedger Config Vault Account

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Using Fireblocks MPC for transaction signing${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}   • Mode: $MODE${NC}"
print_separator

# Check deployment files for each network
echo -e "${BLUE}🔍 Validating deployment files...${NC}"
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name _ <<< "$network_def"
    check_deployment_files "$ENVIRONMENT" "$network_name" "$network_id"
done
echo -e "${GREEN}✅ All deployment files validated${NC}"
print_separator

# Configure SuperLedger on each network
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name _ <<< "$network_def"
    
    network_name_upper=$(echo "$network_name" | tr '[:lower:]' '[:upper:]')
    print_network_header "${network_name_upper} MAINNET"
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    echo -e "${CYAN}   MPC Wallet: ${WHITE}Fireblocks${NC}"
    echo -e "${YELLOW}   Executing forge script via Fireblocks...${NC}"
    
    # Get RPC URL for this network
    RPC_URL=$(get_rpc_url "$network_id")
    export FIREBLOCKS_RPC_URL="$RPC_URL"
    export FIREBLOCKS_CHAIN_ID="$network_id"

    # Set Fireblocks asset ID for chains not auto-detected
    case $network_id in
        988) export FIREBLOCKS_ASSET_ID="GUSDT_STABLE" ;;
        *)   unset FIREBLOCKS_ASSET_ID ;;
    esac

    # Per-chain sender address and tx type (Fireblocks derives different addresses per chain)
    local sender_address
    local tx_type_flag=""
    case $network_id in
        14) # Flare - different Fireblocks address, legacy tx required
            sender_address="0x40a4012A1a154ed58E9BB2f4C63D07f64816b719"
            tx_type_flag="--legacy"
            ;;
        *)  sender_address="0x28b7599f461D104f07D78215Fa6F9B959851f93d" ;;
    esac
    echo -e "${CYAN}   Sender: ${WHITE}$sender_address${NC}"

    fireblocks-json-rpc --http -- forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'runLedgerConfigurations(uint256,uint64)' $FORGE_ENV $network_id \
        --rpc-url {} \
        --sender $sender_address \
        $BROADCAST_FLAG \
        $tx_type_flag \
        --unlocked \
        --slow \
        -vv
    
    echo -e "${GREEN}✅ $network_name Mainnet SuperLedger configuration completed!${NC}"
    wait
done



print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}            🎉 All V2 SuperLedger $ENVIRONMENT $MODE Operations Completed! 🎉            ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${CYAN}🔧 SuperLedger configurations have been completed for:${NC}"
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name _ <<< "$network_def"
    echo -e "${CYAN}   • $network_name Mainnet (Chain ID: $network_id)${NC}"
done
echo -e "${CYAN}🏛️ All transactions signed via Fireblocks MPC wallet${NC}"
print_separator 