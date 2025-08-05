#!/bin/bash

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
    echo -e "${CYAN}║${WHITE}                    🚀 V2 Core Production/Staging Deployment Script 🚀                ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Function to print section separator
print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to print network deployment header
print_network_header() {
    local network=$1
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                           🌐 Deploying to ${network} Network 🌐                          ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Network name mapping
get_network_name() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "Ethereum"
            ;;
        8453)
            echo "Base"
            ;;
        56)
            echo "BNB"
            ;;
        42161)
            echo "Arbitrum"
            ;;
        *)
            log "ERROR" "Unknown network ID: $network_id"
            return 1
            ;;
    esac
}

# Function to validate locked bytecode files
validate_locked_bytecode() {
    log "INFO" "Validating locked bytecode artifacts..."
    
    # Define required contracts (same as in update_locked_bytecode.sh)
    local CORE_CONTRACTS=(
        "SuperExecutor"
        "SuperDestinationExecutor" 
        "SuperSenderCreator"
        "AcrossV3Adapter"
        "DebridgeAdapter"
        "SuperLedger"
        "FlatFeeLedger"
        "SuperLedgerConfiguration"
        "SuperValidator"
        "SuperDestinationValidator"
        "SuperNativePaymaster"
    )
    
    local HOOK_CONTRACTS=(
        "ApproveERC20Hook"
        "TransferERC20Hook"
        "BatchTransferHook"
        "BatchTransferFromHook"
        "Deposit4626VaultHook"
        "ApproveAndDeposit4626VaultHook"
        "Redeem4626VaultHook"
        "Deposit5115VaultHook"
        "ApproveAndDeposit5115VaultHook"
        "Redeem5115VaultHook"
        "RequestDeposit7540VaultHook"
        "ApproveAndRequestDeposit7540VaultHook"
        "ApproveAndRequestRedeem7540VaultHook"
        "Redeem7540VaultHook"
        "RequestRedeem7540VaultHook"
        "Deposit7540VaultHook"
        "CancelDepositRequest7540Hook"
        "CancelRedeemRequest7540Hook"
        "ClaimCancelDepositRequest7540Hook"
        "ClaimCancelRedeemRequest7540Hook"
        "Swap1InchHook"
        "SwapOdosV2Hook"
        "ApproveAndSwapOdosV2Hook"
        "AcrossSendFundsAndExecuteOnDstHook"
        "DeBridgeSendOrderAndExecuteOnDstHook"
        "DeBridgeCancelOrderHook"
        "EthenaCooldownSharesHook"
        "EthenaUnstakeHook"
        "OfframpTokensHook"
        "MarkRootAsUsedHook"
        "MerklClaimRewardHook"
    )
    
    local ORACLE_CONTRACTS=(
        "ERC4626YieldSourceOracle"
        "ERC5115YieldSourceOracle"
        "ERC7540YieldSourceOracle"
        "PendlePTYieldSourceOracle"
        "SpectraPTYieldSourceOracle"
        "StakingYieldSourceOracle"
        "SuperYieldSourceOracle"
    )
    
    local missing_files=()
    
    # Check core contracts
    for contract in "${CORE_CONTRACTS[@]}"; do
        local file_path="script/locked-bytecode/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_files+=("$file_path")
        fi
    done
    
    # Check hook contracts
    for contract in "${HOOK_CONTRACTS[@]}"; do
        local file_path="script/locked-bytecode/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_files+=("$file_path")
        fi
    done
    
    # Check oracle contracts
    for contract in "${ORACLE_CONTRACTS[@]}"; do
        local file_path="script/locked-bytecode/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_files+=("$file_path")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing locked bytecode files:${NC}"
        for file in "${missing_files[@]}"; do
            echo -e "${RED}   - $file${NC}"
        done
        return 1
    fi
    
    echo -e "${GREEN}✅ All required locked bytecode files are present${NC}"
    return 0
}


# Function to check V2 Core addresses on a network
check_v2_addresses() {
    local network_id=$1
    local network_name=$2
    local rpc_url_var=$3
    local verifier_url_var=$4
    
    echo -e "${CYAN}Checking V2 Core addresses for $network_name (Chain ID: $network_id)...${NC}"
    
    forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64)' true $FORGE_ENV $network_id \
        --rpc-url ${!rpc_url_var} \
        --chain $network_id \
        -vv | grep -e "Addr" -e "already deployed" -e "Code Size" -e "====" -e "====>"
}

print_header

# Source centralized network configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/networks.sh"

# Check if arguments are provided
if [ $# -lt 2 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode>${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode: simulate or deploy${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging simulate${NC}"
    echo -e "${CYAN}  $0 prod deploy${NC}"
    exit 1
fi

ENVIRONMENT=$1
MODE=$2

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - No broadcasting to network${NC}"
    echo -e "${CYAN}   - No contract verification${NC}"
    BROADCAST_FLAG=""
    VERIFY_FLAG=""
elif [ "$MODE" = "deploy" ]; then
    echo -e "${GREEN}🚀 Running in deployment mode for $ENVIRONMENT...${NC}"
    echo -e "${CYAN}   - Broadcasting to network${NC}"
    echo -e "${CYAN}   - Tenderly private verification enabled${NC}"
    BROADCAST_FLAG="--broadcast"
    VERIFY_FLAG="--verify"
else
    echo -e "${RED}❌ Invalid mode: $MODE${NC}"
    echo -e "${YELLOW}Mode must be either 'simulate' or 'deploy'${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

# Load RPC URLs using centralized function
echo -e "${CYAN}   • Loading RPC URLs...${NC}"
load_rpc_urls

# Tenderly configuration for verification
echo -e "${CYAN}   • Loading Tenderly credentials...${NC}"
export TENDERLY_ACCESS_TOKEN=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential)
export TENDERLY_ACCOUNT="superform"
export TENDERLY_PROJECT="v2"

# Load Tenderly verification URLs using centralized function
echo -e "${CYAN}   • Setting up Tenderly verification URLs...${NC}"
load_tenderly_urls

# Create output directories
mkdir -p "script/output/$ENVIRONMENT/1"
mkdir -p "script/output/$ENVIRONMENT/8453"
mkdir -p "script/output/$ENVIRONMENT/56"
mkdir -p "script/output/$ENVIRONMENT/42161"

# Deployment parameters
if [ "$ENVIRONMENT" = "staging" ]; then
    FORGE_ENV=2
    export CI=true
    export GITHUB_REF_NAME="staging"
elif [ "$ENVIRONMENT" = "prod" ]; then
    FORGE_ENV=0
    export CI=true
    export GITHUB_REF_NAME="prod"
fi 

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Using Tenderly private verification mode${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
print_separator

# ===== LOCKED BYTECODE VALIDATION =====
echo -e "${BLUE}🔍 Validating locked bytecode artifacts...${NC}"
if ! validate_locked_bytecode; then
    echo -e "${RED}❌ Locked bytecode validation failed${NC}"
    echo -e "${YELLOW}Please ensure all required contract artifacts are present before deployment.${NC}"
    exit 1
fi
print_separator

# ===== ADDRESS CHECKING PHASE =====
echo -e "${BLUE}🔍 Checking V2 Core contract addresses...${NC}"
echo -e "${CYAN}This will show you which contracts are already deployed and which need to be deployed.${NC}"
echo ""

# Check addresses on all networks using centralized configuration
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
    check_v2_addresses "$network_id" "$network_name" "$rpc_var" "$verifier_var"
    echo ""
done

# Prompt user for confirmation
echo -e "${WHITE}Do you want to proceed with the addresses above? (y/n): ${NC}"
read -r proceed

if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
    echo -e "${YELLOW}Deployment cancelled by user${NC}"
    exit 1
fi



print_separator

# Deploy to each network (using centralized NETWORKS configuration)
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
    
    print_network_header "${network_name^^} MAINNET"
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    echo -e "${CYAN}   Verification: ${WHITE}Tenderly Private${NC}"
    echo -e "${YELLOW}   Executing forge script...${NC}"
    
    forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64)' false $FORGE_ENV $network_id \
        --account v2 \
        --rpc-url ${!rpc_var} \
        --chain $network_id \
        --etherscan-api-key $TENDERLY_ACCESS_TOKEN \
        --verifier-url ${!verifier_var} \
        $BROADCAST_FLAG \
        $VERIFY_FLAG \
        --slow \
        -vv
    
    echo -e "${GREEN}✅ $network_name Mainnet deployment completed successfully!${NC}"
done

# Note: Legacy individual network deployments have been replaced by the centralized 
# network loop above for better maintainability and consistency.

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}                🎉 All V2 Core $ENVIRONMENT $MODE Operations Completed! 🎉                ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"



print_separator 