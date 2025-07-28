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

# Function to read latest file from S3
read_latest_from_s3() {
    local environment=$1
    local latest_file_path="/tmp/latest.json"

    if aws s3 cp "s3://$S3_BUCKET_NAME/$environment/latest.json" "$latest_file_path" --quiet 2>/dev/null; then
        log "INFO" "Successfully downloaded latest.json from S3 for $environment"
        
        # Read the file and validate JSON
        local content=$(cat "$latest_file_path")
        
        # Validate the content from file
        if ! echo "$content" | jq '.' >/dev/null 2>&1; then
            log "ERROR" "Invalid JSON in latest file, resetting to default"
            content="{\"networks\":{},\"updated_at\":null}"
        else
            log "INFO" "Successfully validated latest.json from S3"
        fi
    else
        log "WARN" "latest.json not found in S3 for $environment, initializing empty file"
        content="{\"networks\":{},\"updated_at\":null}"
    fi
   
    echo "$content"
}

# Function to check counter and prompt for confirmation
check_and_confirm_counter() {
    local environment=$1
    local network_name=$2
    local network_id=$3
    
    log "INFO" "Checking counter for $network_name in $environment"
    
    local content=$(read_latest_from_s3 "$environment")
    local existing_counter=$(echo "$content" | jq -r ".networks[\"$network_name\"].counter // empty")
    
    if [ -n "$existing_counter" ]; then
        local new_counter=$((existing_counter + 1))
        echo -e "${YELLOW}⚠️  Found existing counter for $network_name: $existing_counter${NC}"
        echo -e "${CYAN}   New counter will be: $new_counter${NC}"
        echo -e "${WHITE}   Do you want to proceed with this new counter? (y/n)${NC}"
        
        read -r confirmation
        if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
            log "INFO" "Deployment cancelled by user"
            exit 1
        fi
        
        echo "$new_counter"
    else
        # Generate new counter starting from 0
        local new_counter=0
        log "INFO" "No existing counter found for $network_name, using new counter: $new_counter"
        echo "$new_counter"
    fi
}

# Function to upload contract addresses to S3
upload_to_s3() {
    local environment=$1
    local network_name=$2
    local network_id=$3
    local counter=$4
    
    log "INFO" "Uploading contract addresses to S3 for $network_name"
    
    # Read existing content from S3
    local content=$(read_latest_from_s3 "$environment")
    
    # Read deployed contracts from output file
    local contracts_file="script/output/$environment/$network_id/$network_name-latest.json"
    
    if [ ! -f "$contracts_file" ]; then
        log "ERROR" "Contract file not found: $contracts_file"
        return 1
    fi
    
    # Read and validate contracts file
    local contracts=$(tr -d '\r' < "$contracts_file")
    if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
        log "ERROR" "Failed to parse JSON from contract file for $network_name"
        return 1
    fi
    
    # Update content with new deployment info
    content=$(echo "$content" | jq \
        --arg network "$network_name" \
        --arg counter "$counter" \
        --argjson contracts "$contracts" \
        '.networks[$network] = {
            "counter": ($counter|tonumber),
            "vnet_id": "",
            "contracts": $contracts
        }')
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time')
    
    # Upload to S3
    local latest_file_path="/tmp/latest.json"
    echo "$content" | jq '.' > "$latest_file_path"
    
    if aws s3 cp "$latest_file_path" "s3://$S3_BUCKET_NAME/$environment/latest.json" --quiet; then
        log "SUCCESS" "Successfully uploaded latest.json to S3 for $environment"
    else
        log "ERROR" "Failed to upload latest.json to S3"
        return 1
    fi
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

# Production RPC URLs
echo -e "${CYAN}   • Loading RPC URLs...${NC}"
export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
export BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
export ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)

# Tenderly configuration for verification
echo -e "${CYAN}   • Loading Tenderly credentials...${NC}"
export TENDERLY_ACCESS_TOKEN=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY_V2/credential)
export TENDERLY_ACCOUNT="superform"
export TENDERLY_PROJECT="v2"

# S3 configuration
echo -e "${CYAN}   • Loading S3 configuration...${NC}"
export S3_BUCKET_NAME="superform-deployment-state"

# Tenderly verification URLs for each network
echo -e "${CYAN}   • Setting up Tenderly verification URLs...${NC}"
export BASE_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/8453"
export BSC_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/56"
export ARBITRUM_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/42161"

# Create output directories
mkdir -p "script/output/$ENVIRONMENT/8453"
mkdir -p "script/output/$ENVIRONMENT/56"
mkdir -p "script/output/$ENVIRONMENT/42161"

# Deployment parameters
FORGE_ENV=0

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Using Tenderly private verification mode${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
print_separator

# ===== ADDRESS CHECKING PHASE =====
echo -e "${BLUE}🔍 Checking V2 Core contract addresses...${NC}"
echo -e "${CYAN}This will show you which contracts are already deployed and which need to be deployed.${NC}"
echo ""

# Check addresses on all networks
check_v2_addresses 8453 "Base" "BASE_MAINNET" "BASE_VERIFIER_URL"
echo ""
check_v2_addresses 56 "BNB" "BSC_MAINNET" "BSC_VERIFIER_URL"
echo ""
check_v2_addresses 42161 "Arbitrum" "ARBITRUM_MAINNET" "ARBITRUM_VERIFIER_URL"
echo ""

# Prompt user for confirmation
echo -e "${WHITE}Do you want to proceed with the addresses above? (y/n): ${NC}"
read -r proceed

if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
    echo -e "${YELLOW}Deployment cancelled by user${NC}"
    exit 1
fi

# Check counters and get confirmation for each network (only for deploy mode)
if [ "$MODE" = "deploy" ]; then
    BASE_COUNTER=$(check_and_confirm_counter "$ENVIRONMENT" "Base" 8453)
    BNB_COUNTER=$(check_and_confirm_counter "$ENVIRONMENT" "BNB" 56)
    ARBITRUM_COUNTER=$(check_and_confirm_counter "$ENVIRONMENT" "Arbitrum" 42161)
fi

print_separator

# Deploy to Base Mainnet
print_network_header "BASE MAINNET"
echo -e "${CYAN}   Chain ID: ${WHITE}8453${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
if [ "$MODE" = "deploy" ]; then
    echo -e "${CYAN}   Counter: ${WHITE}$BASE_COUNTER${NC}"
fi
echo -e "${CYAN}   Verification: ${WHITE}Tenderly Private${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(bool,uint256,uint64)' false $FORGE_ENV 8453 \
    --account v2 \
    --rpc-url $BASE_MAINNET \
    --chain 8453 \
    --etherscan-api-key $TENDERLY_ACCESS_TOKEN \
    --verifier-url $BASE_VERIFIER_URL \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    --slow \
    -vv

echo -e "${GREEN}✅ Base Mainnet deployment completed successfully!${NC}"

# Upload to S3 only if in deploy mode
if [ "$MODE" = "deploy" ]; then
    upload_to_s3 "$ENVIRONMENT" "Base" 8453 "$BASE_COUNTER"
fi
wait

# Deploy to BSC Mainnet
print_network_header "BSC MAINNET"
echo -e "${CYAN}   Chain ID: ${WHITE}56${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
if [ "$MODE" = "deploy" ]; then
    echo -e "${CYAN}   Counter: ${WHITE}$BNB_COUNTER${NC}"
fi
echo -e "${CYAN}   Verification: ${WHITE}Tenderly Private${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(bool,uint256,uint64)' false $FORGE_ENV 56 \
    --account v2 \
    --rpc-url $BSC_MAINNET \
    --chain 56 \
    --etherscan-api-key $TENDERLY_ACCESS_TOKEN \
    --verifier-url $BSC_VERIFIER_URL \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    --slow \
    -vv

echo -e "${GREEN}✅ BSC Mainnet deployment completed successfully!${NC}"

# Upload to S3 only if in deploy mode
if [ "$MODE" = "deploy" ]; then
    upload_to_s3 "$ENVIRONMENT" "BNB" 56 "$BNB_COUNTER"
fi

wait

# Deploy to Arbitrum Mainnet
print_network_header "ARBITRUM MAINNET"
echo -e "${CYAN}   Chain ID: ${WHITE}42161${NC}"
echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
if [ "$MODE" = "deploy" ]; then
    echo -e "${CYAN}   Counter: ${WHITE}$ARBITRUM_COUNTER${NC}"
fi
echo -e "${CYAN}   Verification: ${WHITE}Tenderly Private${NC}"
echo -e "${YELLOW}   Executing forge script...${NC}"

forge script script/DeployV2Core.s.sol:DeployV2Core \
    --sig 'run(bool,uint256,uint64)' false $FORGE_ENV 42161 \
    --account v2 \
    --rpc-url $ARBITRUM_MAINNET \
    --chain 42161 \
    --etherscan-api-key $TENDERLY_ACCESS_TOKEN \
    --verifier-url $ARBITRUM_VERIFIER_URL \
    $BROADCAST_FLAG \
    $VERIFY_FLAG \
    --slow \
    -vv

echo -e "${GREEN}✅ Arbitrum Mainnet deployment completed successfully!${NC}"

# Upload to S3 only if in deploy mode
if [ "$MODE" = "deploy" ]; then
    upload_to_s3 "$ENVIRONMENT" "Arbitrum" 42161 "$ARBITRUM_COUNTER"
fi


print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}║${WHITE}                🎉 All V2 Core $ENVIRONMENT $MODE Operations Completed! 🎉                ${GREEN}║${NC}"
echo -e "${GREEN}║                                                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"

if [ "$MODE" = "deploy" ]; then
    echo -e "${CYAN}🔗 Contract addresses have been uploaded to S3 bucket: $S3_BUCKET_NAME/$ENVIRONMENT/latest.json${NC}"
fi

print_separator 