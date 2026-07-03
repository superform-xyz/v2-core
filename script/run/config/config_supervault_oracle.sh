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
    echo -e "${CYAN}║${WHITE}              🔧 SuperVault Oracle Configuration Script 🔧                           ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}     Configure SuperVaultYieldSourceOracle on existing deployments                    ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
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

# Check if arguments are provided
if [ $# -lt 3 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode> <chain_id>${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode: simulate or configure${NC}"
    echo -e "${CYAN}  chain_id: target chain ID (e.g., 999 for HyperEVM)${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging simulate 999${NC}"
    echo -e "${CYAN}  $0 staging configure 999${NC}"
    echo -e "${CYAN}  $0 prod configure 1${NC}"
    exit 1
fi

ENVIRONMENT=$1
MODE=$2
CHAIN_ID=$3

# Validate environment and source appropriate network configuration
if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}🌐 Loading staging network configuration...${NC}"
    source "$SCRIPT_DIR/../utils/networks-staging.sh"
    FORGE_ENV=2
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}🌐 Loading production network configuration...${NC}"
    source "$SCRIPT_DIR/../utils/networks-production.sh"
    FORGE_ENV=0
else
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

echo -e "${CYAN}✅ Network configuration loaded for $ENVIRONMENT environment${NC}"

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - Configuration will be simulated only${NC}"
    BROADCAST_FLAG=""
elif [ "$MODE" = "configure" ]; then
    echo -e "${GREEN}🚀 Running in configuration mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - SuperVaultYieldSourceOracle will be configured${NC}"
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
echo -e "${CYAN}   • Chain ID: $CHAIN_ID${NC}"
print_separator

# Get network name for display
NETWORK_NAME=$(get_network_name "$CHAIN_ID")
if [ -z "$NETWORK_NAME" ]; then
    echo -e "${RED}❌ Unknown chain ID: $CHAIN_ID${NC}"
    exit 1
fi

# Check deployment file exists
CONTRACTS_FILE="script/output/$ENVIRONMENT/$CHAIN_ID/$NETWORK_NAME-latest.json"
if [ ! -f "$CONTRACTS_FILE" ]; then
    echo -e "${RED}❌ Deployment file not found: $CONTRACTS_FILE${NC}"
    echo -e "${YELLOW}Please ensure the core contracts have been deployed first${NC}"
    exit 1
fi

# Check if SuperVaultYieldSourceOracle is deployed
if ! jq -e '.SuperVaultYieldSourceOracle' "$CONTRACTS_FILE" >/dev/null 2>&1; then
    echo -e "${RED}❌ SuperVaultYieldSourceOracle not found in $CONTRACTS_FILE${NC}"
    echo -e "${YELLOW}This oracle needs to be deployed before it can be configured${NC}"
    exit 1
fi

SUPERVAULT_ORACLE=$(jq -r '.SuperVaultYieldSourceOracle' "$CONTRACTS_FILE")
echo -e "${CYAN}   • SuperVaultYieldSourceOracle: $SUPERVAULT_ORACLE${NC}"

print_separator
echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${PURPLE}│${WHITE}        🔧 Configuring SuperVaultYieldSourceOracle on $NETWORK_NAME 🔧               ${PURPLE}│${NC}"
echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"

# Get RPC URL for this network
RPC_URL=$(get_rpc_url "$CHAIN_ID")
export FIREBLOCKS_RPC_URL="$RPC_URL"
export FIREBLOCKS_CHAIN_ID="$CHAIN_ID"

echo -e "${YELLOW}   Executing forge script via Fireblocks...${NC}"

fireblocks-json-rpc --http -- forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'runSuperVaultOracleConfiguration(uint256,uint64)' $FORGE_ENV $CHAIN_ID \
    --rpc-url {} \
    --sender 0x28b7599f461D104f07D78215Fa6F9B959851f93d \
    $BROADCAST_FLAG \
    --unlocked \
    --slow \
    -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ $NETWORK_NAME SuperVaultYieldSourceOracle configuration completed!${NC}"
else
    echo -e "${RED}❌ $NETWORK_NAME SuperVaultYieldSourceOracle configuration failed!${NC}"
    exit 1
fi

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}         🎉 SuperVaultYieldSourceOracle Configuration Completed! 🎉                  ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

echo -e "${CYAN}🔧 Configuration completed for:${NC}"
echo -e "${CYAN}   • Network: $NETWORK_NAME (Chain ID: $CHAIN_ID)${NC}"
echo -e "${CYAN}   • Oracle: $SUPERVAULT_ORACLE${NC}"
echo -e "${CYAN}🏛️ Transaction signed via Fireblocks MPC wallet${NC}"
print_separator
