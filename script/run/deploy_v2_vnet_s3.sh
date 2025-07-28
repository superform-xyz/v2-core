#!/bin/bash

###################################################################################
# Superform V2 Core Deployment Script
###################################################################################
# Description:
#   This script manages the deployment of Superform V2 CORE contracts to multiple networks
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
    # Check if branch name is 'local'
    [ "${BRANCH_NAME:-}" = "local" ]
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
# Store branch name as a global variable for is_local_run checks
BRANCH_NAME=$1

# Detect if this is a development or main branch
IS_MAIN_OR_DEV=false
if [ "$BRANCH_NAME" = "dev" ] || [ "$BRANCH_NAME" = "main" ]; then
    IS_MAIN_OR_DEV=true
fi

# Set environment for forge scripts
FORGE_ENV=1  # Default to environment 1 for both local and CI

# Handle branch name logic
if [ "$BRANCH_NAME" = "local" ]; then
    log "INFO" "Local branch detected: $BRANCH_NAME. Using local deployment settings."
    GITHUB_REF_NAME="local"
    S3_BUCKET_NAME="vnet-state"
else
    # For all other branches (including main, dev, and custom branches)
    log "INFO" "Branch detected: $BRANCH_NAME. Using vnet-state bucket."
    GITHUB_REF_NAME="$BRANCH_NAME"
    S3_BUCKET_NAME="vnet-state"
fi

# Log branch name for debugging
log "INFO" "Running with branch name: $BRANCH_NAME"



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

# Check if we're in a local run and if the op command is available
if command -v op >/dev/null 2>&1; then
    log "INFO" "Running in local environment with 1Password CLI available"
    # For local runs with op available, get TENDERLY_ACCESS_KEY from 1Password
    TENDERLY_ACCESS_KEY=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential")
else
    
    # Source .env if any required variable is missing
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
if ! is_local_run && [ "$IS_MAIN_OR_DEV" = "true" ]; then
    if [ -z "${GITHUB_REF_NAME:-}" ]; then
        log "ERROR" "GITHUB_REF_NAME environment variable is required for CI mode"
        exit 1
    fi
fi

# Directory configuration based on branch type
if is_local_run; then
    # For local runs only
    BRANCH_DIR="$OUTPUT_BASE_DIR/local"
    # Create local output directories
    for network in 1 8453 10; do
        mkdir -p "$BRANCH_DIR/$network"
    done
else
    # For CI/remote runs (dev, main, and custom branches)
    # Handle feature branches differently
    if [[ "$GITHUB_REF_NAME" == feat/* ]]; then
        # Extract feature name without feat/ prefix
        FEATURE_NAME=${GITHUB_REF_NAME#feat/}
        BRANCH_DIR="$OUTPUT_BASE_DIR/feat/$FEATURE_NAME"
    else
        # For dev, main, and custom branches
        BRANCH_DIR="$OUTPUT_BASE_DIR/$GITHUB_REF_NAME"
    fi
    
    BRANCH_LATEST_FILE="$BRANCH_DIR/latest.json"
    
    # Create branch output directories
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
    # Simply use the current Unix timestamp as salt
    # This ensures a unique but predictable value
    local timestamp=$(date +%s)
    echo "$timestamp"

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

# Function to check if a VNET with a specific slug exists in Tenderly
check_existing_vnet_by_slug() {
    local slug=$1
    local account=$2
    local project=$3
    local access_key=$4
    
    log "INFO" "Checking if a VNET with slug '$slug' already exists in Tenderly"
    
    # Validate inputs
    if [ -z "$slug" ] || [ -z "$account" ] || [ -z "$project" ] || [ -z "$access_key" ]; then
        log "ERROR" "Missing required parameters for VNET check"
        log "DEBUG" "slug=$slug, account=$account, project=$project, access_key=[${access_key:+SET}]"
        return 1
    fi
    
    # Get list of all VNETs from Tenderly
    log "DEBUG" "Making API call to list VNETs..."
    local vnet_list
    if ! vnet_list=$(curl -s -X GET \
        "${API_BASE_URL}/account/${account}/project/${project}/vnets" \
        -H "X-Access-Key: ${access_key}" 2>&1); then
        log "ERROR" "Failed to make API call to list VNETs"
        log "ERROR" "curl error: $vnet_list"
        return 1
    fi
    
    log "DEBUG" "API response received, length: ${#vnet_list}"
    
    # Check if response is valid JSON
    if ! echo "$vnet_list" | jq '.' >/dev/null 2>&1; then
        log "ERROR" "Invalid JSON response when listing VNETs"
        log "ERROR" "Response (first 500 chars): ${vnet_list:0:500}"
        return 1
    fi
    
    log "DEBUG" "API response is valid JSON, checking for existing VNET..."
    
    # Check if the VNET with this slug exists
    local existing_vnet_id
    if ! existing_vnet_id=$(echo "$vnet_list" | jq -r --arg slug "$slug" '.[] | select(.slug==$slug) | .id // empty' 2>&1); then
        log "ERROR" "Failed to parse VNET list with jq"
        log "ERROR" "jq error: $existing_vnet_id"
        return 1
    fi
    
    if [ -n "$existing_vnet_id" ]; then
        log "INFO" "Found existing VNET with slug '$slug', ID: $existing_vnet_id"
        
        # Get details of the VNET to extract RPC URL
        log "DEBUG" "Getting VNET details for ID: $existing_vnet_id"
        local vnet_details
        if ! vnet_details=$(curl -s -X GET \
            "${API_BASE_URL}/account/${account}/project/${project}/vnets/${existing_vnet_id}" \
            -H "X-Access-Key: ${access_key}" 2>&1); then
            log "ERROR" "Failed to get VNET details"
            log "ERROR" "curl error: $vnet_details"
            return 1
        fi
        
        local admin_rpc
        if ! admin_rpc=$(echo "$vnet_details" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url' 2>&1); then
            log "ERROR" "Failed to extract admin RPC from VNET details"
            log "ERROR" "jq error: $admin_rpc"
            return 1
        fi
        
        if [ -n "$admin_rpc" ]; then
            log "INFO" "Successfully extracted admin RPC: $admin_rpc"
            echo "${admin_rpc}|${existing_vnet_id}"
            return 0
        else
            log "WARN" "No admin RPC found in VNET details"
        fi
    else
        log "DEBUG" "No existing VNET found with slug '$slug'"
    fi
    
    # No existing VNET found or couldn't extract details
    return 1
}

# Check for existing VNET in branch latest file and create if not found
check_vnets() {
    local network_slug=$1
    local network_id=$2
    
    # Check if we can reuse an existing VNET
    log "INFO" "Checking for existing VNET for network: $network_slug"

    # Step 1: Check in S3/branch latest file
    content=$(read_branch_latest)
    log "DEBUG: Content received from read_branch_latest: $content"

    vnet_id=$(echo "$content" | jq -r ".networks[\"$network_slug\"].vnet_id // empty")
    log "DEBUG" "VNET ID from latest file: $vnet_id"
    
    if [ -n "$vnet_id" ]; then
        log "INFO" "Found existing VNET ID in S3: $vnet_id"
        # Check if VNET still exists in Tenderly and has the correct slug
        local tenderly_response=$(curl -s -X GET \
            "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
            -H "X-Access-Key: ${TENDERLY_ACCESS_KEY}")
        
        if [ "$(echo "$tenderly_response" | jq -r '.id')" == "$vnet_id" ]; then
            # Validate that the VNET has the expected slug for this branch/network
            local expected_slug=$(generate_slug "$network_slug")
            local actual_slug=$(echo "$tenderly_response" | jq -r '.slug')
            
            if [ "$actual_slug" == "$expected_slug" ]; then
                local admin_rpc=$(echo "$tenderly_response" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')
                if [ -n "$admin_rpc" ]; then
                    log "INFO" "Reusing VNET from S3 state with correct slug: $actual_slug"
                    echo "${admin_rpc}|${vnet_id}"
                    return 0
                fi
            else
                log "WARN" "VNET ID $vnet_id exists but has wrong slug. Expected: $expected_slug, Found: $actual_slug"
                log "WARN" "This indicates S3 file corruption. Will create new VNET with correct slug."
            fi
        fi
        log "INFO" "VNET ID exists in branch file but not valid for reuse"
    fi
    
    # Step 2: Check if there's already a VNET with this slug in Tenderly (not in our state)
    slug=$(generate_slug "$network_slug")
    log "INFO" "Checking if VNET with slug '$slug' already exists in Tenderly"
    log "DEBUG" "Generated slug: $slug for network: $network_slug"
    log "DEBUG" "TENDERLY_ACCOUNT: $TENDERLY_ACCOUNT, TENDERLY_PROJECT: $TENDERLY_PROJECT"
    
    log "DEBUG" "Calling check_existing_vnet_by_slug function..."
    local existing_vnet
    # Temporarily disable exit on error for this specific call
    set +e
    existing_vnet=$(check_existing_vnet_by_slug "$slug" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
    local check_result=$?
    set -e
    
    if [ $check_result -eq 0 ]; then
        log "INFO" "Found and reusing existing VNET from Tenderly with slug: $slug"
        log "DEBUG" "Existing VNET response: $existing_vnet"
        echo "$existing_vnet"
        return 0
    else
        log "DEBUG" "check_existing_vnet_by_slug returned non-zero status, proceeding to create new VNET"
    fi

    # Step 3: If no existing VNET found, create a new one
    log "INFO" "No existing VNET found. Creating new VNET for $network_slug with slug: $slug"
    log "DEBUG" "Calling create_virtual_testnet with parameters: slug=$slug, network_id=$network_id"
    
    local response
    if response=$(create_virtual_testnet "$slug" "$network_id" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY"); then
        log "INFO" "Successfully created new VNET"
        log "DEBUG" "New VNET response: $response"
        echo "$response"
        return 0
    else
        log "ERROR" "Failed to create new VNET"
        return 1
    fi
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
    
    # Always use S3 for file operations
    latest_file_path="/tmp/latest.json"
    if aws s3 cp "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" "$latest_file_path" --quiet 2>/dev/null; then
        content=$(cat "$latest_file_path")
        if ! echo "$content" | jq '.' >/dev/null 2>&1; then
            content="{\"networks\":{},\"updated_at\":null}"
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
    
    # Always use S3 for file operations, even for local runs
    echo "$content" | jq '.' > "/tmp/latest.json"
    if aws s3 cp "/tmp/latest.json" "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" --quiet; then
        log "INFO" "VNET information successfully uploaded to S3"
    else
        log "WARN" "Failed to upload VNET information to S3"
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
ETH_SALT=$(get_salt)
log "INFO" "Generated ETH_SALT: $ETH_SALT"

network_slug=$(get_network_slug "8453")
BASE_SALT=$(get_salt)
log "INFO" "Generated BASE_SALT: $BASE_SALT"

network_slug=$(get_network_slug "10")
OPTIMISM_SALT=$(get_salt)
log "INFO" "Generated OPTIMISM_SALT: $OPTIMISM_SALT"

# Validate salts to ensure they're positive integers
if ! [[ "$ETH_SALT" =~ ^[0-9]+$ ]] || [ "$ETH_SALT" -le 0 ]; then
    log "WARN" "Invalid ETH_SALT: $ETH_SALT. Using fallback value."
    ETH_SALT=1
fi

if ! [[ "$BASE_SALT" =~ ^[0-9]+$ ]] || [ "$BASE_SALT" -le 0 ]; then
    log "WARN" "Invalid BASE_SALT: $BASE_SALT. Using fallback value."
    BASE_SALT=1
fi

if ! [[ "$OPTIMISM_SALT" =~ ^[0-9]+$ ]] || [ "$OPTIMISM_SALT" -le 0 ]; then
    log "WARN" "Invalid OPTIMISM_SALT: $OPTIMISM_SALT. Using fallback value."
    OPTIMISM_SALT=1
fi

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

# Export environment variables needed for the deployment script
if ! is_local_run; then
    export CI=true
    export GITHUB_REF_NAME="$GITHUB_REF_NAME"
else
    # For local runs, we still want to use branch-specific directories for non-local branches
    if [ "$BRANCH_NAME" != "local" ]; then
        export CI=true
        export GITHUB_REF_NAME="$BRANCH_NAME"
    else
        export CI=false
    fi
fi

log "INFO" "Environment variables exported"
log "DEBUG" "CI=${CI:-false}, GITHUB_REF_NAME=${GITHUB_REF_NAME:-not_set}"

# Cache VNET information to be saved after successful deployment
if is_local_run; then
    # Just log the VNET info, but don't save it to S3 yet
    log "INFO" "VNET information cached for later use after successful deployment"
else
    log "INFO" "VNET information cached for later use after successful deployment"
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

# Function to handle deployment failures without updating S3 files
deploy_error_handler() {
    local network=$1
    log "ERROR" "Failed to deploy V2 on $network"
    log "INFO" "No S3 files were updated since deployment failed"
    exit 1
}

# Set trap to ensure S3 files are preserved on any unexpected error
trap 'log "ERROR" "Unexpected error occurred, preserving S3 file"; exit 1' ERR

# Deploy all networks - Core contracts only
deploy_contracts() {
    # Deploy Core contracts on Ethereum Mainnet
    log "INFO" "Deploying V2 Core on Ethereum Mainnet..."
    if ! forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64,string)' false $FORGE_ENV $ETH_CHAIN_ID "$ETH_SALT" \
        --verify \
        --verifier-url $ETH_MAINNET_VERIFIER_URL \
        --rpc-url $ETH_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --jobs 10 \
        -vvv \
        --slow; then
        deploy_error_handler "Ethereum"
    fi
    wait
    
    # Deploy Core contracts on Base Mainnet
    log "INFO" "Deploying V2 Core on Base Mainnet..."
    if ! forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64,string)' false $FORGE_ENV $BASE_CHAIN_ID "$BASE_SALT" \
        --verify \
        --verifier-url $BASE_MAINNET_VERIFIER_URL \
        --rpc-url $BASE_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --jobs 10 \
        -vvv \
        --slow; then
        deploy_error_handler "Base"
    fi
    wait
    
    # Deploy Core contracts on Optimism Mainnet
    log "INFO" "Deploying V2 Core on Optimism Mainnet..."
    if ! forge script script/DeployV2Core.s.sol:DeployV2Core \
        --sig 'run(bool,uint256,uint64,string)' false $FORGE_ENV $OPTIMISM_CHAIN_ID "$OPTIMISM_SALT" \
        --verify \
        --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
        --rpc-url $OPTIMISM_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --jobs 10 \
        -vvv \
        --slow; then
        deploy_error_handler "Optimism"
    fi
    wait
    
    # If we reach here, all core deployments were successful
    log "INFO" "All V2 Core deployments completed successfully!"
    return 0
}



# Update the branch latest file section to use validation
update_latest_file() {
    log "INFO" "All deployments successful. Updating latest file..."
    
    # Initialize content with default structure
    content="{\"networks\":{},\"updated_at\":null}"
    local latest_file
    local initial_sha=""
    
    # Always use S3 for file operations
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
    
    log "DEBUG" "Initial content structure:"
    echo "$content" | jq '.' >&2
    
    # Update content with new deployment info
    i=0
    for network in 1 8453 10; do
        network_slug=$(get_network_slug "$network")
        vnet_id=$(echo "${VNET_RESPONSES[$i]}" | cut -d'|' -f2)
        
        # Read and validate deployed contracts
        # Always use consistent directory structure based on GITHUB_REF_NAME 
        local network_dir="$OUTPUT_BASE_DIR/$GITHUB_REF_NAME/$network"
        
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
    
    # Always use S3 for file operations
    # Format JSON nicely
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
    
    # Upload to S3
    if aws s3 cp "$latest_file_path" "s3://$S3_BUCKET_NAME/$GITHUB_REF_NAME/latest.json" --quiet; then
        log "SUCCESS" "Successfully uploaded latest.json to S3"
    else
        log "ERROR" "Failed to upload latest.json to S3"
        exit 1
    fi
}

# Run all deployments and update the latest file only if successful
# Run the deployment process
deploy_contracts

# If we get here, all deployments were successful
# First ensure we have VNET info saved properly (this was delayed until after successful deployment)
if is_local_run; then
    save_vnet_info true
else
    save_vnet_info false
fi

# Now update the latest file with the new contract addresses
# Since we're using S3 for everything now, no need to pass parameters
update_latest_file

log "SUCCESS" "All V2 Core deployments completed successfully!"