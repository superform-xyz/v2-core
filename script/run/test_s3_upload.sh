#!/bin/bash

# Test script for S3 upload functionality
# This script tests the S3 upload without running the full deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Print test header
print_test_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}║${WHITE}                           🧪 S3 Upload Test Script 🧪                              ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                                                      ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
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
    
    log "INFO" "Found contract file: $contracts_file"
    
    # Read and validate contracts file
    local contracts=$(tr -d '\r' < "$contracts_file")
    if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
        log "ERROR" "Failed to parse JSON from contract file for $network_name"
        return 1
    fi
    
    log "INFO" "Successfully parsed contracts JSON for $network_name"
    
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
    
    echo -e "${YELLOW}📄 Generated S3 content preview:${NC}"
    echo "$content" | jq '.' | head -20
    echo -e "${CYAN}... (truncated for readability)${NC}"
    
    if aws s3 cp "$latest_file_path" "s3://$S3_BUCKET_NAME/$environment/latest.json" --quiet; then
        log "SUCCESS" "Successfully uploaded latest.json to S3 for $environment"
        return 0
    else
        log "ERROR" "Failed to upload latest.json to S3"
        return 1
    fi
}

# Main test function
run_test() {
    local environment=$1
    local dry_run=${2:-false}
    
    print_test_header
    
    echo -e "${BLUE}🧪 Testing S3 upload functionality for environment: ${WHITE}$environment${NC}"
    echo -e "${BLUE}🏗️  Dry run mode: ${WHITE}$dry_run${NC}"
    
    # S3 configuration
    export S3_BUCKET_NAME="superform-deployment-state"
    
    # Test networks with their expected files
    local networks="Base:8453 BNB:56 Arbitrum:42161"
    
    echo -e "${CYAN}📋 Available contract files:${NC}"
    for network_pair in $networks; do
        network_name=${network_pair%:*}
        network_id=${network_pair#*:}
        contracts_file="script/output/$environment/$network_id/$network_name-latest.json"
        
        if [ -f "$contracts_file" ]; then
            echo -e "${GREEN}✅ $network_name: $contracts_file${NC}"
        else
            echo -e "${RED}❌ $network_name: $contracts_file (NOT FOUND)${NC}"
        fi
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Test each network
    for network_pair in $networks; do
        network_name=${network_pair%:*}
        network_id=${network_pair#*:}
        contracts_file="script/output/$environment/$network_id/$network_name-latest.json"
        
        if [ ! -f "$contracts_file" ]; then
            echo -e "${YELLOW}⚠️  Skipping $network_name - no contract file found${NC}"
            continue
        fi
        
        echo -e "${BLUE}🔄 Testing $network_name (Chain ID: $network_id)${NC}"
        
        # Use a test counter
        test_counter=123
        
        if [ "$dry_run" = "true" ]; then
            echo -e "${CYAN}🔍 DRY RUN: Would upload contracts for $network_name with counter $test_counter${NC}"
            
            # Show what would be uploaded
            local content=$(read_latest_from_s3 "$environment")
            local contracts=$(tr -d '\r' < "$contracts_file" | jq -c '.')
            
            content=$(echo "$content" | jq \
                --arg network "$network_name" \
                --arg counter "$test_counter" \
                --argjson contracts "$contracts" \
                '.networks[$network] = {
                    "counter": ($counter|tonumber),
                    "vnet_id": "",
                    "contracts": $contracts
                }')
            
            echo -e "${YELLOW}📄 Would upload this structure:${NC}"
            echo "$content" | jq ".networks[\"$network_name\"]" | head -10
            echo -e "${CYAN}... (truncated for readability)${NC}"
        else
            # Actually upload to S3
            if upload_to_s3 "$environment" "$network_name" "$network_id" "$test_counter"; then
                echo -e "${GREEN}✅ Successfully uploaded $network_name to S3${NC}"
            else
                echo -e "${RED}❌ Failed to upload $network_name to S3${NC}"
            fi
        fi
        
        echo ""
    done
    
    echo -e "${GREEN}🎉 Test completed for environment: $environment${NC}"
    
    if [ "$dry_run" = "false" ]; then
        echo -e "${CYAN}🔗 Check the results at: s3://$S3_BUCKET_NAME/$environment/latest.json${NC}"
    fi
}

# Check arguments
if [ $# -eq 0 ]; then
    echo -e "${RED}❌ Error: Environment argument required${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> [dry-run]${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  dry-run: optional, set to 'true' for dry run mode${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging           # Test actual upload to staging${NC}"
    echo -e "${CYAN}  $0 staging true      # Dry run for staging${NC}"
    exit 1
fi

ENVIRONMENT=$1
DRY_RUN=${2:-false}

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "prod" ]; then
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

# Check if required tools are available
if ! command -v aws >/dev/null 2>&1; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}❌ jq not found. Please install jq first.${NC}"
    exit 1
fi

# Run the test
run_test "$ENVIRONMENT" "$DRY_RUN" 