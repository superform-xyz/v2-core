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
#   ./deploy_v2_vnet.sh <branch_name>
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
#      - Maintains deployment history in branch-specific directories
#      - Reuses existing VNETs when possible
#      - Updates deployment records in latest.json
#
# Requirements:
#   - jq: For JSON processing
#   - curl: For API calls
#   - forge: For contract deployment
#   - op: For local secret management (local mode only)
#   - GitHub environment variables (CI mode only)
#
# Environment Variables:
#   Required for all modes:
#   - TENDERLY_ACCESS_KEY: Access key for Tenderly API
#   
#   Required for CI mode:
#   - GITHUB_TOKEN: GitHub API token
#   - GITHUB_REPOSITORY: Repository name (owner/repo)
#   - GITHUB_REF_NAME: Branch name
#   - GITHUB_RUN_ID: Unique identifier for the workflow run
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
ENVIRONMENT=1  # Environment 1 for tenderly vnet execution
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


# Base output directory
OUTPUT_BASE_DIR="contracts/script/output"

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
    if [ -z "${GITHUB_TOKEN:-}" ] || [ -z "${GITHUB_REPOSITORY:-}" ] || [ -z "${GITHUB_REF_NAME:-}" ] || [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
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
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log "ERROR" "GITHUB_TOKEN environment variable is required for CI mode"
        exit 1
    fi
    if [ -z "${GITHUB_REPOSITORY:-}" ]; then
        log "ERROR" "GITHUB_REPOSITORY environment variable is required for CI mode"
        exit 1
    fi
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
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$BRANCH_LATEST_FILE?ref=$GITHUB_REF_NAME")
    
    if [ "$(echo "$response" | jq -r '.message')" == "Not Found" ]; then
        echo "{\"networks\":{},\"updated_at\":null}"
    else
        echo "$response" | jq -r '.content' | base64 --decode
    fi
}

# Function to update branch-level latest file with optimistic locking
update_branch_latest() {
    local content=$1
    local initial_sha=$2
    
    update_response=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$BRANCH_LATEST_FILE?ref=$GITHUB_REF_NAME" \
        -d @- << EOF
{
    "message": "Update deployment info for job $GITHUB_RUN_ID",
    "content": "$(echo "$content" | base64)",
    "sha": "$initial_sha",
    "branch": "$GITHUB_REF_NAME"
}
EOF
    )
    
    if [ "$(echo "$update_response" | jq -r '.message // empty')" != "" ]; then
        return 1
    fi
    return 0
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

delete_vnet() {
    local vnet_id=$1
    log "INFO" "Deleting VNET: $vnet_id"
    curl -s -X DELETE \
        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
        -H "X-Access-Key: ${TENDERLY_ACCESS_KEY}"
}

cleanup_vnets() {
    log "INFO" "Cleaning up VNETs..."
    for vnet_id in "${VNET_IDS[@]}"; do
        delete_vnet "$vnet_id"
    done
}

# Set up trap to cleanup VNETs on script exit due to error
trap 'cleanup_vnets' ERR

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
    vnet_id=$(echo "$content" | jq -r ".networks[\"$network_slug\"].vnet_id // empty")
    
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
            "chain_id": $network_id
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

    # Extract RPC URLs and VNET ID using jq
    local admin_rpc=$(echo "$response" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')
    local vnet_id=$(echo "$response" | jq -r '.id')

    if [ -z "$admin_rpc" ] || [ -z "$vnet_id" ]; then
        log "ERROR" "Error creating TestNet: $response"
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
# Initialize Output Directories and Files
###################################################################################

# Initialize output files
initialize_output_files() {
    log "INFO" "Initializing output directories and files..."
    for network in 1 8453 10; do
        network_slug=$(get_network_slug "$network")
        output_dir="$BRANCH_DIR/$network"
        output_file="$output_dir/${network_slug^}-latest.json"
        
        # Create directory if it doesn't exist
        mkdir -p "$output_dir"
        
        # Create initial JSON file if it doesn't exist
        if [ ! -f "$output_file" ]; then
            log "INFO" "Creating initial JSON file for $network_slug"
            echo "{}" > "$output_file"
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
            ETH_MAINNET="$admin_rpc"
            ;;
        8453)
            BASE_VNET_ID="$vnet_id"
            BASE_MAINNET="$admin_rpc"
            ;;
        10)
            OPTIMISM_VNET_ID="$vnet_id"
            OPTIMISM_MAINNET="$admin_rpc"
            ;;
    esac
    VNET_IDS+=("$vnet_id")
    i=$((i + 1))
done

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
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $FORGE_ENV \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    $(is_local_run || echo "--silent") \
    --slow; then
    log "ERROR" "Failed to deploy SuperDeployer on Ethereum"
    cleanup_vnets
    exit 1
fi

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
    cleanup_vnets
    exit 1
fi
wait

# Deploy on Base Mainnet
log "INFO" "Deploying on Base Mainnet..."
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $FORGE_ENV \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    $(is_local_run || echo "--silent") \
    --slow; then
    log "ERROR" "Failed to deploy SuperDeployer on Base"
    cleanup_vnets
    exit 1
fi

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
    cleanup_vnets
    exit 1
fi
wait

# Deploy on Optimism Mainnet
log "INFO" "Deploying on Optimism Mainnet..."
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $FORGE_ENV \
    --verify \
    --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
    --rpc-url $OPTIMISM_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    $(is_local_run || echo "--silent") \
    --slow; then
    log "ERROR" "Failed to deploy SuperDeployer on Optimism"
    cleanup_vnets
    exit 1
fi

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
    cleanup_vnets
    exit 1
fi
wait

# Read deployed contracts from output file and validate
read_and_validate_contracts() {
    local file_path=$1
    local network_name=$2
    
    if [ ! -f "$file_path" ]; then
        log "ERROR" "Contract file not found for $network_name: $file_path"
        return 1
    fi
    
    local contracts
    contracts=$(cat "$file_path")
    
    # Validate JSON format
    if ! echo "$contracts" | jq '.' >/dev/null 2>&1; then
        log "ERROR" "Invalid JSON in contract file for $network_name"
        return 1
    fi
    
    echo "$contracts"
    return 0
}

# Update the branch latest file section to use validation
if ! is_local_run; then
    log "INFO" "All deployments successful. Updating branch latest file..."
    
    # Read current latest file and get its SHA
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$BRANCH_LATEST_FILE?ref=$GITHUB_REF_NAME")
    
    initial_sha=""
    if [ "$(echo "$response" | jq -r '.message')" != "Not Found" ]; then
        initial_sha=$(echo "$response" | jq -r '.sha')
        content=$(echo "$response" | jq -r '.content' | base64 --decode)
    else
        content="{\"networks\":{},\"updated_at\":null}"
    fi
    
    # Update content with new deployment info
    i=0
    for network in 1 8453 10; do
        network_slug=$(get_network_slug "$network")
        vnet_id=$(echo "${VNET_RESPONSES[$i]}" | cut -d'|' -f2)
        
        # Read and validate deployed contracts
        contracts_file="$BRANCH_DIR/$network/${network_slug^}-latest.json"
        contracts=$(read_and_validate_contracts "$contracts_file" "$network_slug")
        if [ $? -ne 0 ]; then
            log "ERROR" "Failed to validate contract file for $network_slug"
            cleanup_vnets
            exit 1
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
            
        i=$((i + 1))
    done
    
    # Add metadata
    content=$(echo "$content" | jq \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '. + {
            "updated_at": $timestamp
        }')
    
    # Try to update with optimistic locking
    max_retries=3
    retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if update_branch_latest "$content" "$initial_sha"; then
            log "SUCCESS" "Successfully updated branch latest file"
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -eq $max_retries ]; then
                log "ERROR" "Failed to update branch latest file after $max_retries attempts"
                cleanup_vnets
                exit 1
            fi
            
            # Re-read latest file for next attempt
            response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/$BRANCH_LATEST_FILE?ref=$GITHUB_REF_NAME")
            initial_sha=$(echo "$response" | jq -r '.sha')
            log "WARN" "Retrying update with new SHA: $initial_sha (attempt $retry_count of $max_retries)"
        fi
    done
fi

log "SUCCESS" "All deployments completed successfully!"

