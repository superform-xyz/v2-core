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
# Usage:
#   ./deploy_v2_vnet.sh <branch_name> [local]
#   
#   Parameters:
#     branch_name: Name of the branch (required)
#     local: Optional parameter. If set to any value, script runs in local mode
#
# Requirements:
#   - jq: For JSON processing
#   - curl: For API calls
#   - forge: For contract deployment
#   - GitHub environment (for CI) or environment file (for local)
#
# Environment Variables:
#   Required:
#   - TENDERLY_ACCESS_KEY: Access key for Tenderly API
#   
#   Required for CI:
#   - GITHUB_TOKEN: GitHub API token
#   - GITHUB_REPOSITORY: Repository name (owner/repo)
#   - GITHUB_REF_NAME: Branch name
#
# Author: Superform Team
# Version: 1.0.0
###################################################################################

set -euo pipefail  # Exit on error, undefined var, pipe failure

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
IS_LOCAL=${2:-""}  # Optional second parameter for local mode

# Validation
if [ -z "$BRANCH_NAME" ]; then
    echo "Error: Branch name is required"
    exit 1
fi

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
    [ -n "$IS_LOCAL" ]
    return $?
}

# Network name mapping
get_network_slug() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "eth"
            ;;
        8453)
            echo "base"
            ;;
        10)
            echo "op"
            ;;
        *)
            log "ERROR" "Unknown network ID: $network_id"
            return 1
            ;;
    esac
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

###################################################################################
# Counter Management Functions
###################################################################################

update_counter() {
    local slug=$1
    local vnet_id=$2
    
    log "INFO" "Updating counter for slug: $slug"
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/contracts/script/output/vnet_counters.json")
    
    if [ "$(echo "$response" | jq -r '.message')" == "Not Found" ]; then
        content="{\"slugs\":{}}"
        sha=""
    else
        content=$(echo "$response" | jq -r '.content' | base64 --decode)
        sha=$(echo "$response" | jq -r '.sha')
    fi

    current_counter=$(echo "$content" | jq -r ".slugs[\"$slug\"].counter // 0")
    new_counter=$((current_counter + 1))
    
    new_content=$(echo "$content" | jq \
        --arg slug "$slug" \
        --arg vnet "$vnet_id" \
        --arg counter "$new_counter" \
        '.slugs[$slug] = {"counter": ($counter|tonumber), "vnet_id": $vnet}')

    update_response=$(curl -s -X PUT \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/contracts/script/output/vnet_counters.json" \
        -d @- << EOF
{
    "message": "Update VNET counter for $slug",
    "content": "$(echo "$new_content" | base64)",
    "sha": "$sha",
    "branch": "$GITHUB_REF_NAME"
}
EOF
    )

    if [ "$(echo "$update_response" | jq -r '.message // empty')" != "" ]; then
        log "ERROR" "Failed to update counter"
        return 1
    fi

    echo "$new_counter"
    return 0
}

get_salt() {
    local slug=$1
    local vnet_id=$2

    # If running locally, always return 1
    if is_local_run; then
        echo "1"
        return 0
    fi

    # CI environment - handle counter logic
    MAX_RETRIES=3
    retry_count=0
    while [ $retry_count -lt $MAX_RETRIES ]; do
        if counter=$(update_counter "$slug" "$vnet_id"); then
            echo "$counter"
            return 0
        fi
        retry_count=$((retry_count + 1))
        sleep 1
    done
    
    return 1
}

###################################################################################
# VNET Creation and Management
###################################################################################

generate_slug() {
    local network=$1
    local output="${BRANCH_NAME//\//-}-${network}"
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    local output=$(echo "$output" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "$output"
}

check_existing_vnet() {
    local slug=$1
    log "INFO" "Checking for existing VNET with slug: $slug"
    
    log "DEBUG" "GitHub API URL: https://api.github.com/repos/$GITHUB_REPOSITORY/contents/contracts/script/output/vnet_counters.json"
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/contracts/script/output/vnet_counters.json")
    
    log "DEBUG" "GitHub API Response: $response"  # Add this line to log the response

    if [ "$(echo "$response" | jq -r '.message')" == "Not Found" ]; then
        log "INFO" "No vnet counter file found"
        return 1
    fi

    local content=$(echo "$response" | jq -r '.content' | base64 --decode)
    local vnet_id=$(echo "$content" | jq -r ".slugs[\"$slug\"].vnet_id // empty")
    
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
    fi
    
    log "INFO" "No existing VNET found"
    return 1
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
# Authentication Setup
###################################################################################

if is_local_run; then
    log "INFO" "Running in local environment"
    # For local runs, always source .env
    if [ ! -f .env ]; then
        log "ERROR" ".env file is required for local runs"
        exit 1
    fi
    source .env
    if [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
        log "ERROR" "TENDERLY_ACCESS_KEY environment variable is required in .env file"
        exit 1
    fi
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

    # Final check for required variables
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        log "ERROR" "GITHUB_TOKEN environment variable is required"
        exit 1
    fi
    if [ -z "${GITHUB_REPOSITORY:-}" ]; then
        log "ERROR" "GITHUB_REPOSITORY environment variable is required"
        exit 1
    fi
    if [ -z "${GITHUB_REF_NAME:-}" ]; then
        log "ERROR" "GITHUB_REF_NAME environment variable is required"
        exit 1
    fi
    if [ -z "${TENDERLY_ACCESS_KEY:-}" ]; then
        log "ERROR" "TENDERLY_ACCESS_KEY environment variable is required"
        exit 1
    fi
fi

###################################################################################
# Main Deployment Logic
###################################################################################

# Create VNETs and get salts for each network
for network in 1 8453 10; do
    network_slug=$(get_network_slug "$network")
    slug=$(generate_slug "$network_slug")
    
    if is_local_run; then
        # Local run - create new VNET and use salt=1
        response=$(create_virtual_testnet "$slug" "$network" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
        vnet_id=$(echo "$response" | cut -d'|' -f2)
        salt="1"
    else
        # CI run - check existing VNET and handle counter
        response=$(check_existing_vnet "$slug")
        if [ $? -eq 0 ]; then
            # VNET exists, use existing one
            vnet_id=$(echo "$response" | cut -d'|' -f2)
        else
            # VNET doesn't exist, create new one
            response=$(create_virtual_testnet "$slug" "$network" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
            vnet_id=$(echo "$response" | cut -d'|' -f2)
        fi
        
        salt=$(get_salt "$slug" "$vnet_id")
        if [ $? -ne 0 ]; then
            log "ERROR" "Failed to get salt for $slug"
            cleanup_vnets
            exit 1
        fi
    fi

    # Store variables based on network
    case "$network" in
        1)
            ETH_VNET_ID="$vnet_id"
            ETH_SALT="$salt"
            ETH_MAINNET=$(echo "$response" | cut -d'|' -f1)
            VNET_IDS+=("$vnet_id")
            ;;
        8453)
            BASE_VNET_ID="$vnet_id"
            BASE_SALT="$salt"
            BASE_MAINNET=$(echo "$response" | cut -d'|' -f1)
            VNET_IDS+=("$vnet_id")
            ;;
        10)
            OPTIMISM_VNET_ID="$vnet_id"
            OPTIMISM_SALT="$salt"
            OPTIMISM_MAINNET=$(echo "$response" | cut -d'|' -f1)
            VNET_IDS+=("$vnet_id")
            ;;
    esac
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
    --sig 'run(uint256)' $ENVIRONMENT \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    log "ERROR" "Failed to deploy SuperDeployer on Ethereum"
    cleanup_vnets
    exit 1
fi

if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $ETH_CHAIN_ID "$ETH_SALT" \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    log "ERROR" "Failed to deploy V2 on Ethereum"
    cleanup_vnets
    exit 1
fi
wait

# Deploy on Base Mainnet
log "INFO" "Deploying on Base Mainnet..."
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $ENVIRONMENT \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    log "ERROR" "Failed to deploy SuperDeployer on Base"
    cleanup_vnets
    exit 1
fi

if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $BASE_CHAIN_ID "$BASE_SALT" \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    log "ERROR" "Failed to deploy V2 on Base"
    cleanup_vnets
    exit 1
fi
wait

# Deploy on Optimism Mainnet
log "INFO" "Deploying on Optimism Mainnet..."
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $ENVIRONMENT \
    --verify \
    --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
    --rpc-url $OPTIMISM_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    log "ERROR" "Failed to deploy SuperDeployer on Optimism"
    cleanup_vnets
    exit 1
fi

if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $OPTIMISM_CHAIN_ID "$OPTIMISM_SALT" \
    --verify \
    --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
    --rpc-url $OPTIMISM_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    log "ERROR" "Failed to deploy V2 on Optimism"
    cleanup_vnets
    exit 1
fi
wait

log "SUCCESS" "All deployments completed successfully!"