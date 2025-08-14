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
    echo -e "${CYAN}║${WHITE}                    📤 V2 Core S3 Contract Upload Script 📤                      ${CYAN}║${NC}"
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



# Function to read latest file from S3
read_latest_from_s3() {
    local environment=$1
    local latest_file_path="/tmp/latest_s3.json"

    if aws s3 cp "s3://$S3_BUCKET_NAME/$environment/latest.json" "$latest_file_path" --quiet 2>/dev/null; then
        log "INFO" "Successfully downloaded latest.json from S3 for $environment"
        
        # Read the file and validate JSON
        local content=$(cat "$latest_file_path")

        
        # Check if content is empty or just whitespace
        if [ -z "$(echo "$content" | tr -d '[:space:]')" ]; then
            log "WARN" "S3 file is empty or whitespace only, initializing default content"
            content="{\"networks\":{},\"updated_at\":null}"
        elif ! echo "$content" | jq '.' >/dev/null 2>&1; then
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

# Function to get next counter for a network
get_next_counter() {
    local environment=$1
    local network_name=$2
    
    log "INFO" "Getting next counter for $network_name in $environment"
    
    local content=$(read_latest_from_s3 "$environment")
    local existing_counter=$(echo "$content" | jq -r ".networks[\"$network_name\"].counter // empty")
    
    if [ -n "$existing_counter" ] && [ "$existing_counter" != "null" ]; then
        local new_counter=$((existing_counter + 1))
        log "INFO" "Found existing counter: $existing_counter, new counter: $new_counter for $network_name"
        echo "$new_counter"
    else
        # Generate new counter starting from 0
        local new_counter=0
        log "INFO" "No existing counter found for $network_name, using new counter: $new_counter"
        echo "$new_counter"
    fi
}

# Function to batch upload all contract addresses to S3
batch_upload_to_s3() {
    local environment=$1
    shift
    local network_defs=("$@")
    
    log "INFO" "Starting batch upload for all networks"
    
    # Read existing content from S3
    local content=$(read_latest_from_s3 "$environment")
    log "DEBUG" "Initial content from S3 length: ${#content} characters"
    log "DEBUG" "Initial content preview: $(echo "$content" | head -c 100)..."
    
    # Process each network and collect all data
    local updated_networks=()
    for network_def in "${network_defs[@]}"; do
        IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
        
        echo -e "${CYAN}📋 Processing $network_name (Chain ID: $network_id)...${NC}"
        
        # Get counter for this network
        local counter=$(get_next_counter "$environment" "$network_name")
        
        # Use environment name directly
        local env_folder="$environment"
        
        # Read deployed contracts from output file
        local contracts_file="script/output/$env_folder/$network_id/$network_name-latest.json"
        
        if [ ! -f "$contracts_file" ]; then
            log "ERROR" "Contract file not found: $contracts_file"
            return 1
        fi
        
        log "INFO" "Reading contracts from: $contracts_file"
        
        # Read and validate contracts file
        local contracts=$(tr -d '\r' < "$contracts_file")
        
        if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
            log "ERROR" "Failed to parse JSON from contract file for $network_name"
            return 1
        fi
        
        log "INFO" "Successfully parsed contracts JSON for $network_name"
        
        # Update content with new deployment info
        log "DEBUG" "Updating content with network: $network_name, counter: $counter"
        content=$(echo "$content" | jq \
            --arg network "$network_name" \
            --arg counter "$counter" \
            --argjson contracts "$contracts" \
            '.networks[$network] = {
                "counter": ($counter|tonumber),
                "vnet_id": "",
                "contracts": $contracts
            }') || {
            log "ERROR" "Failed to update content with deployment info for $network_name"
            return 1
        }
        
        updated_networks+=("$network_name")
        echo -e "${GREEN}   ✅ $network_name data processed successfully${NC}"
    done
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time') || {
        log "ERROR" "Failed to update timestamp"
        return 1
    }
    
    # Display the updated content for confirmation
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 Final S3 content for $environment that will be uploaded:${NC}"
    echo -e "${CYAN}🔄 Updated networks: ${updated_networks[*]}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Check if content is empty or just whitespace
    if [ -z "$(echo "$content" | tr -d '[:space:]')" ]; then
        echo -e "${RED}ERROR: Content is empty or whitespace only${NC}"
        log "ERROR" "Raw content: '$content'"
        return 1
    fi
    
    echo "$content" | jq '.' 2>&1 || {
        echo -e "${RED}ERROR: Failed to parse JSON content${NC}"
        log "ERROR" "Raw content that failed: '$content'"
        return 1
    }
    
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Ask for user confirmation ONCE for all networks
    printf "${WHITE}🚀 Do you want to upload ALL networks (${updated_networks[*]}) to S3? (y/n): ${NC}"
    read -r confirmation
    echo ""
    
    if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
        log "INFO" "Batch upload cancelled by user"
        return 1
    fi
    
    # Upload to S3
    local latest_file_path="/tmp/latest_upload.json"
    echo "$content" | jq '.' > "$latest_file_path"
    
    if aws s3 cp "$latest_file_path" "s3://$S3_BUCKET_NAME/$environment/latest.json" --quiet; then
        log "SUCCESS" "Successfully uploaded latest.json to S3 for $environment"
        return 0
    else
        log "ERROR" "Failed to upload latest.json to S3"
        return 1
    fi
}

print_header

# Source centralized network configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/networks.sh"

# Check if arguments are provided
if [ $# -lt 1 ]; then
    echo -e "${RED}❌ Error: Missing required argument${NC}"
    echo -e "${YELLOW}Usage: $0 <environment>${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging${NC}"
    echo -e "${CYAN}  $0 prod${NC}"
    exit 1
fi

ENVIRONMENT=$1

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

# S3 configuration
echo -e "${CYAN}   • Loading S3 configuration...${NC}"
export S3_BUCKET_NAME="superform-deployment-state"

echo -e "${GREEN}✅ Configuration loaded successfully${NC}"
echo -e "${CYAN}   • Environment: $ENVIRONMENT${NC}"
echo -e "${CYAN}   • S3 Bucket: $S3_BUCKET_NAME${NC}"
print_separator

# Use environment name directly
env_folder="$ENVIRONMENT"

echo -e "${BLUE}🔍 Scanning for deployed contracts in output/$env_folder/...${NC}"

FOUND_DEPLOYMENTS=()

# Check which networks have deployments
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
    
    contracts_file="script/output/$env_folder/$network_id/$network_name-latest.json"
    
    if [ -f "$contracts_file" ]; then
        echo -e "${GREEN}   ✅ Found deployment: $network_name (Chain ID: $network_id)${NC}"
        FOUND_DEPLOYMENTS+=("$network_def")
    else
        echo -e "${YELLOW}   ⚠️  No deployment found: $network_name (Chain ID: $network_id) - $contracts_file${NC}"
    fi
done

if [ ${#FOUND_DEPLOYMENTS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No contract deployments found in output/$env_folder/ directory${NC}"
    echo -e "${YELLOW}Please ensure contracts have been deployed before running this script.${NC}"
    exit 1
fi

print_separator

echo -e "${PURPLE}📤 Processing batch upload of all contracts to S3...${NC}"

TOTAL_COUNT=${#FOUND_DEPLOYMENTS[@]}

echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
echo -e "${PURPLE}│${WHITE}                        📤 Batch Uploading All Network Contracts 📤                 ${PURPLE}│${NC}"
echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"

echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
echo -e "${CYAN}   Total Networks: ${WHITE}$TOTAL_COUNT${NC}"
echo -e "${CYAN}   Networks: ${WHITE}$(for net in "${FOUND_DEPLOYMENTS[@]}"; do IFS=':' read -r id name _ _ <<< "$net"; echo -n "$name "; done)${NC}"
echo ""

if batch_upload_to_s3 "$ENVIRONMENT" "${FOUND_DEPLOYMENTS[@]}"; then
    print_separator
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}║${WHITE}              🎉 All Contract Uploads Completed Successfully! 🎉                    ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}🔗 Contract addresses uploaded to S3 bucket: $S3_BUCKET_NAME/$ENVIRONMENT/latest.json${NC}"
    echo -e "${CYAN}📊 Successfully uploaded: $TOTAL_COUNT/$TOTAL_COUNT networks${NC}"
else
    print_separator
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                                                      ║${NC}"
    echo -e "${RED}║${WHITE}                        ❌ Batch Upload Failed ❌                                   ${RED}║${NC}"
    echo -e "${RED}║                                                                                      ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RED}❌ Failed to upload contracts to S3${NC}"
    exit 1
fi

print_separator