#!/bin/bash

###################################################################################
# Superform V2 Deployment Script
###################################################################################
# Description:
#   This script manages the deployment of Superform V2 contracts to multiple networks
#   using Tenderly Virtual Networks (VNETs). It includes functionality for:
#   - Creating and managing VNETs for multiple chains
#   - Maintaining deployment salt counters for deterministic addresses
#   - Supporting both local development and CI environments
#   - Handling cleanup of resources on failure
#
# Directory Structure:
#   script/output/
#   ├── dev/                      # Development branch deployments
#   │   ├── latest.json          # Latest deployment info for dev branch
#   │   ├── 1/                   # Ethereum deployment outputs
#   │   ├── 8453/               # Base deployment outputs
#   │   └── 10/                 # Optimism deployment outputs
#   ├── feat-xyz/                # Feature branch deployments
#   │   └── ...                 # Same structure as dev/
#   └── main/                    # Main branch deployments
#       └── ...                 # Same structure as dev/
#
# File Organization:
#   - latest.json: Contains network-specific deployment info including:
#     - VNET IDs for active deployments
#     - Salt counters for deterministic addresses
#     - Contract addresses and metadata
#     - Timestamps for tracking deployment history
#
# Usage:
#   ./deploy_v2_vnet.sh_s3 <branch_name>
#   
#   Parameters:
#     branch_name: Name of the branch (required)
#
# Execution Modes:
#   1. Local Development:
#      - Detected by presence of 'op' command
#      - Uses 1Password for secrets
#      - Creates new VNETs for each run
#      - Does not maintain deployment history
#
#   2. CI Environment:
#      - Uses GitHub environment variables
#      - Stores latest.json in S3 bucket
#      - Maintains deployment history in branch-specific directories
#      - Reuses existing VNETs when possible
#      - Updates deployment records in latest.json
#
# Requirements:
#   - jq: For JSON processing
#   - curl: For API calls
#   - forge: For contract deployment
#   - op: For local secret management (local mode only)
#   - aws: For S3 operations (CI mode only)
#   - GitHub environment variables (CI mode only)
#
# Environment Variables:
#   Required for all modes:
#   - TENDERLY_ACCESS_KEY: Access key for Tenderly API
#   
#   Required for CI mode:
#   - GITHUB_REF_NAME: Branch name
#   - S3_BUCKET_NAME: S3 bucket name for storing latest.json
#
# Error Handling:
#   - Automatic cleanup of VNETs on failure
#   - Retries for API operations with exponential backoff
#   - Optimistic locking for file updates
#   - Comprehensive logging and error reporting
#
# Author: Superform Team
# Version: 1.0.0
###################################################################################

set -euo pipefail  # Exit on error, undefined var, pipe failure

###################################################################################
# Helper Functions
###################################################################################

# Logging function for consistent output
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Environment detection
is_local_run() {
    command -v op >/dev/null 2>&1
    return $?
}

# Network name mapping
get_network_slug() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "Ethereum"
            ;;
        8453)
            echo "Base"
            ;;
        10)
            echo "Optimism"
            ;;
        *)
            log "ERROR" "Unknown network ID: $network_id"
            return 1
            ;;
    esac
}

###################################################################################
# Configuration
###################################################################################

# Environment and Chain IDs
ETH_CHAIN_ID=1
BASE_CHAIN_ID=8453
OPTIMISM_CHAIN_ID=10

# Tenderly Configuration
API_BASE_URL="https://api.tenderly.co/api/v1"
TENDERLY_ACCOUNT="superform"
TENDERLY_PROJECT="v2"

# Script Arguments
BRANCH_NAME=$1

# Set environment for forge scripts
FORGE_ENV=1  # Default to environment 1 for both local and CI

# Validation
if [ -z "$BRANCH_NAME" ]; then
    echo "Error: Branch name is required"
    exit 1
fi


# Base output directory for local file operations
OUTPUT_BASE_DIR="script/output"


###################################################################################
# Authentication Setup
###################################################################################

if is_local_run; then
    log "INFO" "Running in local environment"
    # For local runs, get TENDERLY_ACCESS_KEY from 1Password
    TENDERLY_ACCESS_KEY=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential")
else
    log "INFO" "Running in CI environment"
    # Only source .env if any required variable is missing
    if [ -z "${GITHUB_REF_NAME:-}" ] || [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
        if [ ! -f .env ]; then
            log "ERROR" ".env file is required when environment variables are missing"
            exit 1
        fi
        log "INFO" "Loading missing variables from .env file"
        source .env
    fi
fi

###################################################################################
# Environment Validation
###################################################################################

# Validate Tenderly access key for all modes
if [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
    log "ERROR" "TENDERLY_ACCESS_KEY environment variable is required"
    exit 1
fi

# Validate CI-specific environment variables
if ! is_local_run; then
    if [ -z "${GITHUB_REF_NAME:-}" ]; then
        log "ERROR" "GITHUB_REF_NAME environment variable is required for CI mode"
        exit 1
    fi
fi

# CI-specific directory configuration
if ! is_local_run; then
    # Handle feature branches differently
    if [[ "$GITHUB_REF_NAME" == feat/* ]]; then
        # Extract feature name without feat/ prefix
        FEATURE_NAME=${GITHUB_REF_NAME#feat/}
        BRANCH_DIR="$OUTPUT_BASE_DIR/feat/$FEATURE_NAME"
    else
        # For dev, main branches
        BRANCH_DIR="$OUTPUT_BASE_DIR/$GITHUB_REF_NAME"
    fi
    
    BRANCH_LATEST_FILE="$BRANCH_DIR/latest.json"
    
    # Create branch output directories
    for network in 1 8453 10; do
        mkdir -p "$BRANCH_DIR/$network"
    done
else
    # For local runs
    BRANCH_DIR="$OUTPUT_BASE_DIR/local"
    # Create local output directories
    for network in 1 8453 10; do
        mkdir -p "$BRANCH_DIR/$network"
    done
fi

# Function to read branch-level latest file
read_branch_latest() {
    latest_file_path="/tmp/latest.json"

    if aws s3 cp "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" "$latest_file_path" --quiet; then
        log "INFO" "Successfully downloaded latest.json from S3"

        # Read the file and validate JSON
        content=$(cat "$latest_file_path")

        # Validate the content from file
        if ! echo "$content" | jq '.' >/dev/null 2>&1; then
            log "ERROR" "Invalid JSON in latest file, resetting to default"
            log "ERROR" "Response: $content"
            content="{\"networks\":{},\"updated_at\":null}"
        else
            log "INFO" "Successfully validated latest.json from S3"
        fi
    else
        log "WARN" "latest.json not found in S3, initializing empty file"
        content="{\"networks\":{},\"updated_at\":null}"
    fi
   
    echo "$content"
}

# Generate salt for a network
get_salt() {
    local network_slug=$1
    
    if is_local_run; then
        echo "1"
        return 0
    fi
    
    # Read current latest file
    content=$(read_branch_latest)
    current_counter=$(echo "$content" | jq -r ".networks[\"$network_slug\"].counter // 0")
    echo $((current_counter + 1))
}

###################################################################################
# VNET Management Functions
###################################################################################

# Array to store VNET IDs for cleanup
declare -a VNET_IDS

#delete_vnet() {
#    local vnet_id=$1
#    log "INFO" "Deleting VNET: $vnet_id"
#    curl -s -X DELETE \
#        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
#        -H "X-Access-Key: ${TENDERLY_ACCESS_KEY}"
#}

#cleanup_vnets() {
#    log "INFO" "Cleaning up VNETs..."
#    for vnet_id in "${VNET_IDS[@]}"; do
#        delete_vnet "$vnet_id"
#    done
#}

# Set up trap to cleanup VNETs on script exit due to error
#trap 'cleanup_vnets' ERR

generate_slug() {
    local network=$1
    local output="${BRANCH_NAME//\//-}-${network}"
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    local output=$(echo "$output" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "$output"
}

# Check for existing VNET in branch latest file and create if not found
check_vnets() {
    local network_slug=$1
    local network_id=$2
    
    if is_local_run; then
        # For local runs, always create new VNET
        slug=$(generate_slug "$network_slug")
        response=$(create_virtual_testnet "$slug" "$network_id" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
        echo "$response"
        return 0
    fi
    
    log "INFO" "Checking for existing VNET for network: $network_slug"

    # Read from branch latest file
    content=$(read_branch_latest)
    log "DEBUG: Content received from read_branch_latest: $content"

    vnet_id=$(echo "$content" | jq -r ".networks[\"$network_slug\"].vnet_id // empty")
    log "DEBUG" "VNET ID from latest file: $vnet_id"
    
    if [ -n "$vnet_id" ]; then
        log "INFO" "Found existing VNET ID: $vnet_id"
        # Check if VNET still exists in Tenderly
        local tenderly_response=$(curl -s -X GET \
            "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
            -H "X-Access-Key: ${TENDERLY_ACCESS_KEY}")
        
        if [ "$(echo "$tenderly_response" | jq -r '.id')" == "$vnet_id" ]; then
            local admin_rpc=$(echo "$tenderly_response" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')
            if [ -n "$admin_rpc" ]; then
                echo "${admin_rpc}|${vnet_id}"
                return 0
            fi
        fi
        log "INFO" "VNET ID exists in branch file but not in Tenderly"
    fi
    
    # No valid existing VNET found, create new one
    log "INFO" "Creating new VNET for $network_slug"
    slug=$(generate_slug "$network_slug")
    response=$(create_virtual_testnet "$slug" "$network_id" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
    echo "$response"
    return 0
}

create_virtual_testnet() {
    local slug=$1
    local network_id=$2
    local account_name=$3
    local project_name=$4
    local access_key=$5
    
    log "INFO" "Creating TestNet with slug: $slug"
    
    # Determine custom chain ID based on network_id
    local custom_chain_id
    case "$network_id" in
        1)
            custom_chain_id=1
            ;;
        8453)
            custom_chain_id=8453
            ;;
        10)
            custom_chain_id=10
            ;;
        *)
            custom_chain_id=$network_id
            ;;
    esac

    # Construct JSON payload
    local json_data=$(cat <<EOF
{
    "slug": "$slug",
    "display_name": "$slug",
    "fork_config": {
        "network_id": $network_id,
        "block_number": "latest"
    },
    "virtual_network_config": {
        "chain_config": {
            "chain_id": $custom_chain_id
        }
    },
    "sync_state_config": {
        "enabled": false
    },
    "explorer_page_config": {
        "enabled": false,
        "verification_visibility": "src"
    }
}
EOF
)

    # Make API request
    local response=$(curl -s -X POST \
        "${API_BASE_URL}/account/${account_name}/project/${project_name}/vnets" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "X-Access-Key: ${access_key}" \
        -d "$json_data")
        
    # Debug the raw response
    log "DEBUG" "Raw Tenderly API response: $response"
    
    # Check if response is valid JSON
    if ! echo "$response" | jq '.' >/dev/null 2>&1; then
        log "ERROR" "Invalid JSON response from Tenderly API"
        log "ERROR" "Response: $response"
        return 1
    fi
    
    # Check for API error responses
    if [ "$(echo "$response" | jq -r '.error.message // empty')" != "" ]; then
        log "ERROR" "Tenderly API error: $(echo "$response" | jq -r '.error.message')"
        return 1
    fi
    
    # Check if response has the expected structure
    if ! echo "$response" | jq -e '.rpcs' >/dev/null 2>&1; then
        log "ERROR" "Unexpected response format from Tenderly API (missing rpcs field)"
        log "ERROR" "Full response: $response"
        return 1
    fi

    # Extract RPC URLs and VNET ID using jq with error handling
    local admin_rpc=$(echo "$response" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')
    local vnet_id=$(echo "$response" | jq -r '.id')

    if [ -z "$admin_rpc" ] || [ -z "$vnet_id" ]; then
        log "ERROR" "Failed to extract required fields from Tenderly API response"
        log "ERROR" "Admin RPC: $admin_rpc"
        log "ERROR" "VNET ID: $vnet_id"
        log "ERROR" "Full response: $response"
        return 1
    fi
    
    log "SUCCESS" "VNET created successfully"
    echo "${admin_rpc}|${vnet_id}"
}

set_initial_balance() {
    local rpc_url=$1
    log "INFO" "Setting initial balance for RPC: $rpc_url"
    curl $rpc_url \
        -X POST \
        -H "Content-Type: application/json" \
        -d '{
            "jsonrpc": "2.0",
            "method": "tenderly_setBalance",
            "params": [
            [
            "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
            ],
            "0xDE0B6B3A7640000"
            ],
            "id": "1234"
        }'
}

###################################################################################
# Save VNET Information
###################################################################################

save_vnet_info() {
    local is_local=$1
    log "INFO" "Saving VNET information..."
    
    # Initialize content
    content="{\"networks\":{},\"updated_at\":null}"
    local latest_file
    
    if [ "$is_local" = true ]; then
        latest_file="$OUTPUT_BASE_DIR/latest.json"
        if [ -f "$latest_file" ]; then
            content=$(cat "$latest_file")
            if ! echo "$content" | jq '.' >/dev/null 2>&1; then
                content="{\"networks\":{},\"updated_at\":null}"
            fi
        fi
    else
        latest_file_path="/tmp/latest.json"
        if aws s3 cp "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" "$latest_file_path" --quiet 2>/dev/null; then
            content=$(cat "$latest_file_path")
            if ! echo "$content" | jq '.' >/dev/null 2>&1; then
                content="{\"networks\":{},\"updated_at\":null}"
            fi
        fi
    fi
    
    # Update VNET information only
    i=0
    for network in 1 8453 10; do
        network_slug=$(get_network_slug "$network")
        vnet_id=$(echo "${VNET_RESPONSES[$i]}" | cut -d'|' -f2)
        
        if [ -n "$vnet_id" ]; then
            # Update only VNET information
            content=$(echo "$content" | jq \
                --arg slug "$network_slug" \
                --arg vnet "$vnet_id" \
                '.networks[$slug] = {
                    "vnet_id": $vnet,
                    "contracts": {}
                }')
        fi
        
        i=$((i + 1))
    done
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time')
    
    if [ "$is_local" = true ]; then
        echo "$content" | jq '.' > "$latest_file"
        log "INFO" "VNET information saved locally"
    else
        echo "$content" | jq '.' > "/tmp/latest.json"
        if aws s3 cp "/tmp/latest.json" "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" --quiet; then
            log "INFO" "VNET information successfully uploaded to S3"
        else
            log "WARN" "Failed to upload VNET information to S3"
        fi
    fi
}

###################################################################################
# Initialize Output Directories and Files
###################################################################################

# Initialize output files
initialize_output_files() {
    log "INFO" "Initializing output directories and files..."
    log "INFO" "Branch directory: $BRANCH_DIR"
    
    for network in 1 8453 10; do
        network_slug=$(get_network_slug "$network")
        output_dir="$BRANCH_DIR/$network"
        output_file="$output_dir/$network_slug-latest.json"
        
        # Create directory if it doesn't exist
        mkdir -p "$output_dir"
        log "INFO" "Created directory: $output_dir"
        
        # Create initial JSON file if it doesn't exist
        if [ ! -f "$output_file" ]; then
            log "INFO" "Creating initial JSON file: $output_file"
            echo "{}" > "$output_file"
            # Verify file was created
            if [ -f "$output_file" ]; then
                log "INFO" "Successfully created file: $output_file"
            else
                log "ERROR" "Failed to create file: $output_file"
            fi
        fi
    done
}

# Initialize before deployments
initialize_output_files

###################################################################################
# Main Deployment Logic
###################################################################################

# First phase: Create or get VNETs for all networks
# Store responses in indexed arrays matching the network order
declare -a VNET_RESPONSES

for network in 1 8453 10; do
    network_slug=$(get_network_slug "$network")
    response=$(check_vnets "$network_slug" "$network")
    VNET_RESPONSES+=("$response")
done

# Second phase: Generate salts for each network
network_slug=$(get_network_slug "1")
ETH_SALT=$(get_salt "$network_slug")

network_slug=$(get_network_slug "8453")
BASE_SALT=$(get_salt "$network_slug")

network_slug=$(get_network_slug "10")
OPTIMISM_SALT=$(get_salt "$network_slug")

# Third phase: Store network-specific variables
i=0
for network in 1 8453 10; do
    vnet_response="${VNET_RESPONSES[$i]}"
    vnet_id=$(echo "$vnet_response" | cut -d'|' -f2)
    admin_rpc=$(echo "$vnet_response" | cut -d'|' -f1)
    
    case "$network" in
        1)
            ETH_VNET_ID="$vnet_id"
            export ETH_MAINNET="$admin_rpc"
            ;;
        8453)
            BASE_VNET_ID="$vnet_id"
            export BASE_MAINNET="$admin_rpc"
            ;;
        10)
            OPTIMISM_VNET_ID="$vnet_id"
            export OPTIMISM_MAINNET="$admin_rpc"
            ;;
    esac
    
    VNET_IDS+=("$vnet_id")
    i=$((i + 1))
done

# Export TENDERLY_ACCESS_KEY if it's not already exported
if [ -n "$TENDERLY_ACCESS_KEY" ]; then
    export TENDERLY_ACCESS_KEY
fi

log "INFO" "Environment variables exported"

# Save VNET information before deployment
if is_local_run; then
    save_vnet_info true
else
    save_vnet_info false
fi

###################################################################################
# Contract Deployment
###################################################################################

# Set up verifier URLs
ETH_MAINNET_VERIFIER_URL="$ETH_MAINNET/verify/etherscan"
BASE_MAINNET_VERIFIER_URL="$BASE_MAINNET/verify/etherscan"
OPTIMISM_MAINNET_VERIFIER_URL="$OPTIMISM_MAINNET/verify/etherscan"

# Set initial balances
log "INFO" "Setting initial balances..."
set_initial_balance "$ETH_MAINNET"
set_initial_balance "$BASE_MAINNET"
set_initial_balance "$OPTIMISM_MAINNET"

# Deploy on Ethereum Mainnet
log "INFO" "Deploying on Ethereum Mainnet..."
if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $FORGE_ENV $ETH_CHAIN_ID "$ETH_SALT" \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    $(is_local_run || echo "--silent") \
    --slow; then
    log "ERROR" "Failed to deploy V2 on Ethereum"
    exit 1
fi
wait

# Deploy on Base Mainnet
log "INFO" "Deploying on Base Mainnet..."

if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $FORGE_ENV $BASE_CHAIN_ID "$BASE_SALT" \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    $(is_local_run || echo "--silent") \
    --slow; then
    log "ERROR" "Failed to deploy V2 on Base"
    exit 1
fi
wait

# Deploy on Optimism Mainnet
log "INFO" "Deploying on Optimism Mainnet..."

if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $FORGE_ENV $OPTIMISM_CHAIN_ID "$OPTIMISM_SALT" \
    --verify \
    --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
    --rpc-url $OPTIMISM_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    $(is_local_run || echo "--silent") \
    --slow; then
    log "ERROR" "Failed to deploy V2 on Optimism"
    exit 1
fi
wait



# Update the branch latest file section to use validation
update_latest_file() {
    local is_local=$1
    log "INFO" "All deployments successful. Updating latest file..."
    
    # Initialize content with default structure
    content="{\"networks\":{},\"updated_at\":null}"
    local latest_file
    local initial_sha=""
    
    if [ "$is_local" = true ]; then
        latest_file="$OUTPUT_BASE_DIR/latest.json"
        # Create the file if it doesn't exist
        if [ ! -f "$latest_file" ]; then
            echo "$content" > "$latest_file"
        else
            content=$(cat "$latest_file")
            # Validate the content from file
            if ! echo "$content" | jq '.' >/dev/null 2>&1; then
                log "WARN" "Invalid JSON in latest file, resetting to default"
                content="{\"networks\":{},\"updated_at\":null}"
            fi
        fi
    else
        latest_file_path="/tmp/latest.json"

        # Download latest.json from S3
        if aws s3 cp "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" "$latest_file_path" --quiet; then
            log "INFO" "Successfully downloaded latest.json from S3"

            # Read the file and validate JSON
            content=$(cat "$latest_file_path")

            # Validate the content from file
            if ! echo "$content" | jq '.' >/dev/null 2>&1; then
                log "WARN" "Invalid JSON in latest file, resetting to default"
                content="{\"networks\":{},\"updated_at\":null}"
            fi
        else
            log "WARN" "latest.json not found in S3, initializing empty file"
            content="{\"networks\":{},\"updated_at\":null}"
        fi
    fi
    
    log "DEBUG" "Initial content structure:"
    echo "$content" | jq '.' >&2
    
    # Update content with new deployment info
    i=0
    for network in 1 8453 10; do
        network_slug=$(get_network_slug "$network")
        vnet_id=$(echo "${VNET_RESPONSES[$i]}" | cut -d'|' -f2)
        
        # Read and validate deployed contracts
        local network_dir
        if [ "$is_local" = true ]; then
            network_dir="$OUTPUT_BASE_DIR/local/$network"
        else
            network_dir="$OUTPUT_BASE_DIR/$GITHUB_REF_NAME/$network"
        fi
        
        contracts_file="$network_dir/$network_slug-latest.json"
        log "INFO" "Looking for contracts at: $contracts_file"
        
        # List directory contents for debugging
        log "DEBUG" "Directory contents of $network_dir:"
        ls -la "$network_dir" || true
        
        if [ ! -f "$contracts_file" ]; then
            log "ERROR" "Contract file not found for $network_slug: $contracts_file"
            log "DEBUG" "Current working directory: $(pwd)"
            log "DEBUG" "Listing parent directory:"
            ls -la "$(dirname "$network_dir")" || true
            exit 1
        fi
        
        # Read contracts file and ensure it's valid JSON - handle potential DOS line endings
        contracts=$(tr -d '\r' < "$contracts_file")
        if ! contracts=$(echo "$contracts" | jq -c '.' 2>/dev/null); then
            log "ERROR" "Failed to parse JSON from contract file for $network_slug"
            log "DEBUG" "Raw file contents:"
            cat "$contracts_file" | xxd
            exit 1
        fi
        
        log "INFO" "Successfully parsed contracts for $network_slug"
        
        # Validate JSON format
        if [ -z "$contracts" ]; then
            log "ERROR" "Empty or invalid JSON in contract file for $network_slug"
            exit 1
        fi
        
        # Check if contracts is empty object
        if [ "$contracts" = "{}" ]; then
            log "WARN" "No contracts found in file for $network_slug"
        fi
        
        # Use the salts we generated earlier
        case "$network" in
            1)
                new_counter="$ETH_SALT"
                ;;
            8453)
                new_counter="$BASE_SALT"
                ;;
            10)
                new_counter="$OPTIMISM_SALT"
                ;;
        esac
        
        # Debug output for all parameters
        echo "$contracts" | jq '.' >&2
        echo "$content" | jq '.' >&2
        
        # Validate all inputs before jq operation
        if ! echo "$contracts" | jq '.' >/dev/null 2>&1; then
            log "ERROR" "contracts is not valid JSON"
            exit 1
        fi
        
        if ! echo "$content" | jq '.' >/dev/null 2>&1; then
            log "ERROR" "content is not valid JSON"
            exit 1
        fi
        
        if ! [[ "$new_counter" =~ ^[0-9]+$ ]]; then
            log "ERROR" "new_counter is not a valid number: $new_counter"
            exit 1
        fi
        
        content=$(echo "$content" | jq \
            --arg slug "$network_slug" \
            --arg vnet "$vnet_id" \
            --arg counter "$new_counter" \
            --argjson contracts "$contracts" \
            '.networks[$slug] = {
                "counter": ($counter|tonumber),
                "vnet_id": $vnet,
                "contracts": $contracts
            }')
            
        # Validate the result
        if [ $? -ne 0 ]; then
            log "ERROR" "jq command failed"
            exit 1
        fi
        
        # Debug the output
        log "DEBUG" "Updated content:"
        echo "$content" | jq '.' >&2
            
        i=$((i + 1))
    done
    
    # Update timestamp
    content=$(echo "$content" | jq --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" '.updated_at = $time')
    
    if [ "$is_local" = true ]; then
        echo "$content" | jq '.' > "$latest_file"
        log "SUCCESS" "Successfully updated local latest file"
    else
        # Format JSON nicely before base64 encoding
        content=$(echo "$content" | jq '.')
        
        # Use -w 0 to avoid line wrapping in base64 output
        encoded_content=$(echo -n "$content" | base64 -w 0)
        
        update_data="{\"message\":\"Update branch latest file\",\"content\":\"$encoded_content\""
        
        # Only include SHA if we have one (for existing files)
        if [ -n "$initial_sha" ]; then
            log "INFO" "Including SHA in update request: $initial_sha"
            update_data="$update_data,\"sha\":\"$initial_sha\""
        fi
        
        update_data="$update_data,\"branch\":\"$GITHUB_REF_NAME\"}"
        
        log "INFO" "Sending update request to GitHub API"
        echo "$content" | jq '.' > "$latest_file_path"

        if aws s3 cp "$latest_file_path" "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" --quiet; then
            log "SUCCESS" "Successfully uploaded latest.json to S3"
        else
            log "ERROR" "Failed to upload latest.json to S3"
            exit 1
        fi    
    fi
}

# After all deployments are done, update the latest file
if is_local_run; then
    update_latest_file true
else
    update_latest_file false
fi

log "SUCCESS" "All deployments completed successfully!"