#!/opt/homebrew/bin/bash

# Colors for better visual output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Associative array to store deployment status for each network
declare -A NETWORK_DEPLOYMENT_STATUS

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

# Function to extract contract names from regenerate_bytecode.sh
extract_contracts_from_regenerate_script() {
    local array_name=$1
    local script_path="$PROJECT_ROOT/script/run/regenerate_bytecode.sh"
    
    if [[ ! -f "$script_path" ]]; then
        return 1
    fi
    
    # Extract contract names from the specified array in regenerate_bytecode.sh
    # Find the array definition and stop at the closing parenthesis
    sed -n "/${array_name}=(/,/^)/p" "$script_path" | grep -o '"[^"]*"' | tr -d '"'
}

# Function to validate locked bytecode files (sourced from regenerate_bytecode.sh)
validate_locked_bytecode() {
    log "INFO" "Validating locked bytecode artifacts..."
    
    local script_path="$PROJECT_ROOT/script/run/regenerate_bytecode.sh"
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}❌ Cannot find regenerate_bytecode.sh at: $script_path${NC}"
        return 1
    fi
    
    local missing_files=()
    
    # Extract and check core contracts
    log "INFO" "Checking core contracts from regenerate_bytecode.sh..."
    local core_contracts
    core_contracts=$(extract_contracts_from_regenerate_script "CORE_CONTRACTS")
    for contract in $core_contracts; do
        [[ -z "$contract" ]] && continue
        local file_path="$PROJECT_ROOT/script/locked-bytecode/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_files+=("$file_path")
        fi
    done
    
    # Extract and check hook contracts
    log "INFO" "Checking hook contracts from regenerate_bytecode.sh..."
    local hook_contracts
    hook_contracts=$(extract_contracts_from_regenerate_script "HOOK_CONTRACTS")
    for contract in $hook_contracts; do
        [[ -z "$contract" ]] && continue
        local file_path="$PROJECT_ROOT/script/locked-bytecode/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_files+=("$file_path")
        fi
    done
    
    # Extract and check oracle contracts
    log "INFO" "Checking oracle contracts from regenerate_bytecode.sh..."
    local oracle_contracts
    oracle_contracts=$(extract_contracts_from_regenerate_script "ORACLE_CONTRACTS")
    for contract in $oracle_contracts; do
        [[ -z "$contract" ]] && continue
        local file_path="$PROJECT_ROOT/script/locked-bytecode/${contract}.json"
        if [ ! -f "$file_path" ]; then
            missing_files+=("$file_path")
        fi
    done
    
    # Show expected total count
    local expected_total
    expected_total=$(get_expected_contract_count)
    log "INFO" "Expected total artifacts: $expected_total (from regenerate_bytecode.sh)"
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        echo -e "${RED}❌ Missing locked bytecode files:${NC}"
        for file in "${missing_files[@]}"; do
            echo -e "${RED}   - $file${NC}"
        done
        echo -e "${RED}   Missing: ${#missing_files[@]} files${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ All required locked bytecode files are present${NC}"
    echo -e "${GREEN}   Validated: $expected_total contract artifacts${NC}"
    return 0
}


# Function to get expected contract count from regenerate_bytecode.sh
get_expected_contract_count() {
    local script_path="$PROJECT_ROOT/script/run/regenerate_bytecode.sh"
    
    if [[ ! -f "$script_path" ]]; then
        echo "0"
        return 1
    fi
    
    # Use the same extraction logic as extract_contracts_from_update_script
    local core_count hook_count oracle_count
    
    # Extract CORE_CONTRACTS array and count elements
    core_count=$(sed -n "/CORE_CONTRACTS=(/,/^)/p" "$script_path" | grep -o '"[^"]*"' | wc -l)
    
    # Extract HOOK_CONTRACTS array and count elements  
    hook_count=$(sed -n "/HOOK_CONTRACTS=(/,/^)/p" "$script_path" | grep -o '"[^"]*"' | wc -l)
    
    # Extract ORACLE_CONTRACTS array and count elements
    oracle_count=$(sed -n "/ORACLE_CONTRACTS=(/,/^)/p" "$script_path" | grep -o '"[^"]*"' | wc -l)
    
    local total_expected=$((core_count + hook_count + oracle_count))
    echo "$total_expected"
}

# Function to analyze deployment status across all networks and determine next steps
analyze_deployment_status() {
    echo -e "${BLUE}📊 Analyzing deployment status across all networks...${NC}"
    echo ""
    
    local all_fully_deployed=true
    local needs_deployment=false
    local networks_with_missing=()
    
    # Get expected contract count from regenerate_bytecode.sh
    local total_expected
    total_expected=$(get_expected_contract_count)
    
    if [[ $total_expected -eq 0 ]]; then
        echo -e "${RED}❌ Unable to determine expected contract count from regenerate_bytecode.sh${NC}"
        return 2
    fi
    
    echo -e "${CYAN}Expected total contracts per network (from regenerate_bytecode.sh): ${WHITE}$total_expected${NC}"
    echo -e "${CYAN}  • Core contracts: ${WHITE}$(sed -n "/CORE_CONTRACTS=(/,/^)/p" "$SCRIPT_DIR/regenerate_bytecode.sh" | grep -o '"[^"]*"' | wc -l)${NC}"
    echo -e "${CYAN}  • Hook contracts: ${WHITE}$(sed -n "/HOOK_CONTRACTS=(/,/^)/p" "$SCRIPT_DIR/regenerate_bytecode.sh" | grep -o '"[^"]*"' | wc -l)${NC}"
    echo -e "${CYAN}  • Oracle contracts: ${WHITE}$(sed -n "/ORACLE_CONTRACTS=(/,/^)/p" "$SCRIPT_DIR/regenerate_bytecode.sh" | grep -o '"[^"]*"' | wc -l)${NC}"
    echo ""
    
    # Analyze each network against the expected total from regenerate_bytecode.sh
    for network_id in "${!NETWORK_DEPLOYMENT_STATUS[@]}"; do
        IFS=':' read -r deployed detected_total network_name <<< "${NETWORK_DEPLOYMENT_STATUS[$network_id]}"
        
        # Use the expected total from regenerate_bytecode.sh, not the detected total
        if [[ $deployed -eq $total_expected ]]; then
            echo -e "${GREEN}✅ $network_name (Chain $network_id): All $deployed/$total_expected contracts deployed${NC}"
        elif [[ $deployed -lt $total_expected ]]; then
            local missing=$((total_expected - deployed))
            echo -e "${YELLOW}⚠️  $network_name (Chain $network_id): $deployed/$total_expected contracts deployed (${missing} missing)${NC}"
            all_fully_deployed=false
            needs_deployment=true
            networks_with_missing+=("$network_name")
        elif [[ $deployed -gt $total_expected ]]; then
            echo -e "${CYAN}ℹ️  $network_name (Chain $network_id): $deployed/$total_expected contracts deployed (${deployed} > expected ${total_expected})${NC}"
            echo -e "${CYAN}    Note: More contracts deployed than expected - this may include additional contracts${NC}"
        else
            echo -e "${RED}❌ $network_name (Chain $network_id): Error in deployment status${NC}"
            all_fully_deployed=false
        fi
    done
    
    echo ""
    
    # Determine action based on analysis
    if [[ $all_fully_deployed == true && $total_expected -gt 0 ]]; then
        echo -e "${GREEN}🎉 EXCELLENT! All contracts are already deployed on all networks!${NC}"
        echo -e "${GREEN}   Expected: $total_expected contracts (from regenerate_bytecode.sh)${NC}"
        echo -e "${GREEN}   Status: Fully deployed across all chains${NC}"
        echo -e "${GREEN}   No deployment needed - terminating with success${NC}"
        return 0  # All deployed - skip deployment
    elif [[ $needs_deployment == true ]]; then
        echo -e "${YELLOW}📋 DEPLOYMENT REQUIRED${NC}"
        echo -e "${CYAN}   Expected total per network: $total_expected contracts (from regenerate_bytecode.sh)${NC}"
        echo -e "${CYAN}   The following networks have missing contracts:${NC}"
        for network in "${networks_with_missing[@]}"; do
            echo -e "${CYAN}   • $network${NC}"
        done
        echo ""
        echo -e "${WHITE}   Only missing contracts will be deployed (existing ones will be skipped)${NC}"
        return 1  # Needs deployment - continue with confirmation
    else
        echo -e "${RED}❌ Unable to determine deployment status${NC}"
        echo -e "${RED}   Expected: $total_expected contracts (from regenerate_bytecode.sh)${NC}"
        return 2  # Error state
    fi
}

# Function to check V2 Core addresses on a network and capture deployment status
check_v2_addresses() {
    local network_id=$1
    local network_name=$2
    local rpc_url_var=$3
    local verifier_url_var=$4
    
    echo -e "${CYAN}Checking V2 Core addresses for $network_name (Chain ID: $network_id)...${NC}"
    
    # Capture the full output to parse deployment status
    local check_output
    check_output=$(forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64)' true $FORGE_ENV $network_id \
        --rpc-url ${!rpc_url_var} \
        --chain $network_id \
        -vv 2>&1)
    
    # Display the relevant output lines
    echo "$check_output" | grep -e "Addr" -e "already deployed" -e "Code Size" -e "====" -e "====>"
    
    # Extract deployment counts from the summary line
    local summary_line
    summary_line=$(echo "$check_output" | grep "=====> On this chain we have")
    
    if [[ -n "$summary_line" ]]; then
        # Parse: "=====> On this chain we have X contracts already deployed out of Y"
        local deployed_count=$(echo "$summary_line" | grep -o "have [0-9]\+ contracts" | grep -o "[0-9]\+")
        local total_count=$(echo "$summary_line" | grep -o "out of [0-9]\+" | grep -o "[0-9]\+")
        
        # Store deployment status for this network
        NETWORK_DEPLOYMENT_STATUS["${network_id}"]="${deployed_count}:${total_count}:${network_name}"
        
        echo -e "${YELLOW}  📊 Status: ${deployed_count}/${total_count} contracts deployed${NC}"
    else
        echo -e "${RED}  ❌ Could not parse deployment status${NC}"
        NETWORK_DEPLOYMENT_STATUS["${network_id}"]="0:0:${network_name}"
    fi
}

print_header

# Source centralized network configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Find project root (go up from script/run/ to project root)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$SCRIPT_DIR/networks.sh"

# Check if arguments are provided
if [ $# -lt 3 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode> <account>${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode: simulate or deploy${NC}"
    echo -e "${CYAN}  account: foundry account name (e.g., v2, deployer, main)${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging simulate v2${NC}"
    echo -e "${CYAN}  $0 prod deploy deployer${NC}"
    echo -e "${CYAN}Available accounts: $(cast wallet list 2>/dev/null | sed 's/ (Local)//' | tr '\n' ' ' || echo 'Run "cast wallet list" to see available accounts')${NC}"
    exit 1
fi

ENVIRONMENT=$1
MODE=$2
ACCOUNT=$3

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

# Validate account exists in foundry wallet list
if ! cast wallet list 2>/dev/null | sed 's/ (Local)//' | grep -q "^$ACCOUNT$"; then
    echo -e "${RED}❌ Account '$ACCOUNT' not found in foundry wallet list${NC}"
    echo -e "${YELLOW}Available accounts:${NC}"
    cast wallet list 2>/dev/null | sed 's/ (Local)//' | sed 's/^/  • /' || echo -e "${RED}  No accounts found. Run 'cast wallet import' to add accounts.${NC}"
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
mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/1"
mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/8453"
mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/56"
mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/42161"

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
echo -e "${CYAN}   • Account: $ACCOUNT${NC}"

# Change to project root directory for forge commands
echo -e "${CYAN}   • Changing to project root: $PROJECT_ROOT${NC}"
cd "$PROJECT_ROOT"

# Export PROJECT_ROOT as environment variable for Solidity scripts
export SUPERFORM_PROJECT_ROOT="$PROJECT_ROOT"
echo -e "${CYAN}   • Exported SUPERFORM_PROJECT_ROOT: $SUPERFORM_PROJECT_ROOT${NC}"
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

print_separator

# Analyze deployment status and determine next steps
analyze_deployment_status
analysis_result=$?

case $analysis_result in
    0)
        # All contracts deployed - exit successfully
        print_separator
        echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║                                                                                      ║${NC}"
        echo -e "${GREEN}║${WHITE}                🎉 All V2 Core Contracts Already Deployed! 🎉                    ${GREEN}║${NC}"
        echo -e "${GREEN}║${WHITE}                           No deployment necessary                               ${GREEN}║${NC}"
        echo -e "${GREEN}║                                                                                      ║${NC}"
        echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        exit 0
        ;;
    1)
        # Some contracts need deployment - ask for confirmation
        echo -e "${WHITE}🤔 Do you want to proceed with deploying the missing contracts? (y/n): ${NC}"
        read -r proceed
        
        if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
            echo -e "${YELLOW}Deployment cancelled by user${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ Proceeding with deployment of missing contracts...${NC}"
        ;;
    2)
        # Error in analysis
        echo -e "${RED}❌ Error analyzing deployment status. Please check the output above.${NC}"
        exit 1
        ;;
esac



print_separator

# Deploy only to networks that need deployment (smart deployment logic)
deployed_networks=0
skipped_networks=0

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
    
    # Check deployment status for this network
    if [[ -n "${NETWORK_DEPLOYMENT_STATUS[$network_id]}" ]]; then
        IFS=':' read -r deployed total_expected network_status_name <<< "${NETWORK_DEPLOYMENT_STATUS[$network_id]}"
        
        # Get expected total from regenerate_bytecode.sh
        script_expected=$(get_expected_contract_count)
        
        # Skip if all contracts are already deployed
        if [[ $deployed -eq $script_expected ]]; then
            echo -e "${GREEN}⏭️  Skipping ${network_name^^} MAINNET - All $deployed/$script_expected contracts already deployed${NC}"
            ((skipped_networks++))
            continue
        fi
        
        # Deploy to networks with missing contracts
        echo -e "${YELLOW}🚀 Deploying to ${network_name^^} MAINNET - $deployed/$script_expected contracts deployed ($(($script_expected - $deployed)) missing)${NC}"
    else
        echo -e "${YELLOW}🚀 Deploying to ${network_name^^} MAINNET - No previous deployment status found${NC}"
    fi
    
    print_network_header "${network_name^^} MAINNET"
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
    echo -e "${CYAN}   Verification: ${WHITE}Tenderly Private${NC}"
    echo -e "${YELLOW}   Executing forge script...${NC}"
    
    forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64)' false $FORGE_ENV $network_id \
        --account $ACCOUNT \
        --rpc-url ${!rpc_var} \
        --chain $network_id \
        --etherscan-api-key $TENDERLY_ACCESS_TOKEN \
        --verifier-url ${!verifier_var} \
        $BROADCAST_FLAG \
        $VERIFY_FLAG \
        --slow \
        -vv
    
    echo -e "${GREEN}✅ $network_name Mainnet deployment completed successfully!${NC}"
    ((deployed_networks++))
done

echo ""
echo -e "${BLUE}📊 Deployment Summary:${NC}"
echo -e "${GREEN}   • Networks deployed: $deployed_networks${NC}"
echo -e "${YELLOW}   • Networks skipped: $skipped_networks${NC}"

# Note: Legacy individual network deployments have been replaced by the centralized 
# network loop above for better maintainability and consistency.

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}                🎉 All V2 Core $ENVIRONMENT $MODE Operations Completed! 🎉                ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"



print_separator 