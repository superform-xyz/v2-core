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

# Function to upload contract addresses to S3
upload_to_s3() {
    local environment=$1
    local network_name=$2
    local network_id=$3
    local counter=$4
    
    log "INFO" "Uploading contract addresses to S3 for $network_name"
    
    # Read existing content from S3
    local content=$(read_latest_from_s3 "$environment")
    log "DEBUG" "Initial content from S3 length: ${#content} characters"
    log "DEBUG" "Initial content preview: $(echo "$content" | head -c 100)..."
    
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
    log "DEBUG" "Raw contracts content length: ${#contracts} characters"
    log "DEBUG" "Raw contracts preview: $(echo "$contracts" | head -c 200)..."
    
    if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
        log "ERROR" "Failed to parse JSON from contract file for $network_name"
        log "ERROR" "Raw contracts content: '$contracts'"
        return 1
    fi
    
    log "INFO" "Successfully parsed contracts JSON for $network_name"
    log "DEBUG" "Parsed contracts length: ${#contracts} characters"
    
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
        log "ERROR" "Failed to update content with deployment info"
        return 1
    }
    
    log "DEBUG" "Content after network update length: ${#content} characters"
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time') || {
        log "ERROR" "Failed to update timestamp"
        return 1
    }
    
    log "DEBUG" "Content after timestamp update length: ${#content} characters"
    
    # Debug: Check content length and first few characters
    log "DEBUG" "Content length: ${#content} characters"
    log "DEBUG" "Content preview: $(echo "$content" | head -c 100)..."
    
    # Display the updated content for confirmation
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Current S3 content for $environment that will be uploaded:${NC}"
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
    
    # Ask for user confirmation
    printf "${WHITE}Do you want to upload this content to S3? (y/n): ${NC}"
    read -r confirmation
    echo ""
    
    if [ "$confirmation" != "y" ] && [ "$confirmation" != "Y" ]; then
        log "INFO" "Upload cancelled by user for $network_name"
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
    IFS=':' read -r network_id network_name <<< "$network_def"
    
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
echo -e "${BLUE}📤 Processing contract uploads to S3...${NC}"

# Process each found deployment
SUCCESS_COUNT=0
TOTAL_COUNT=${#FOUND_DEPLOYMENTS[@]}

for network_def in "${FOUND_DEPLOYMENTS[@]}"; do
    IFS=':' read -r network_id network_name <<< "$network_def"
    
    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                        📤 Uploading $network_name Contracts 📤                        ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"
    
    # Get next counter for this network
    COUNTER=$(get_next_counter "$ENVIRONMENT" "$network_name")
    
    echo -e "${CYAN}   Network: ${WHITE}$network_name${NC}"
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Counter: ${WHITE}$COUNTER${NC}"
    echo -e "${CYAN}   Environment: ${WHITE}$ENVIRONMENT${NC}"
    echo ""
    
    if upload_to_s3 "$ENVIRONMENT" "$network_name" "$network_id" "$COUNTER"; then
        echo -e "${GREEN}✅ Successfully uploaded $network_name contracts to S3${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}❌ Failed to upload $network_name contracts to S3${NC}"
    fi
    
    echo ""
done

print_separator

if [ $SUCCESS_COUNT -eq $TOTAL_COUNT ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}║${WHITE}              🎉 All Contract Uploads Completed Successfully! 🎉                    ${GREEN}║${NC}"
    echo -e "${GREEN}║                                                                                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${CYAN}🔗 Contract addresses uploaded to S3 bucket: $S3_BUCKET_NAME/$ENVIRONMENT/latest.json${NC}"
    echo -e "${CYAN}📊 Successfully uploaded: $SUCCESS_COUNT/$TOTAL_COUNT networks${NC}"
else
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                                                                                      ║${NC}"
    echo -e "${YELLOW}║${WHITE}                ⚠️  Upload Completed with Some Failures ⚠️                       ${YELLOW}║${NC}"
    echo -e "${YELLOW}║                                                                                      ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${YELLOW}📊 Successfully uploaded: $SUCCESS_COUNT/$TOTAL_COUNT networks${NC}"
    echo -e "${RED}❌ Failed uploads: $((TOTAL_COUNT - SUCCESS_COUNT)) networks${NC}"
fi

print_separator