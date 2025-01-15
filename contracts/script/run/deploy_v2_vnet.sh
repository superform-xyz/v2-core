#!/bin/bash

# Environment and Chain IDs
ENVIRONMENT=1  # Environment 1 for tenderly vnet execution
ETH_CHAIN_ID=1
BASE_CHAIN_ID=8453
OPTIMISM_CHAIN_ID=10

# Add PR number as first argument and commit hash as second argument
PR_NUMBER=$1
COMMIT_HASH=$2

if [ -z "$PR_NUMBER" ]; then
    echo "Error: PR number is required"
    exit 1
fi

if [ -z "$COMMIT_HASH" ]; then
    echo "Error: Commit hash is required"
    exit 1
fi

# Check if running locally by testing for op command
if command -v op >/dev/null 2>&1; then
    # Running locally, use op to get access key
    TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
else
    source .env
    # Not running locally, use environment variable
    if [ -z "$TENDERLY_ACCESS_KEY" ]; then
        echo "Error: TENDERLY_ACCESS_KEY environment variable is required"
        exit 1
    fi
fi

API_BASE_URL="https://api.tenderly.co/api/v1"
# Load environment variables
TENDERLY_ACCOUNT="superform"
TENDERLY_PROJECT="v2"

# Array to store VNET IDs for cleanup
declare -a VNET_IDS

delete_vnet() {
    local vnet_id=$1
    echo "Deleting VNET: $vnet_id"
    curl -s -X DELETE \
        "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
        -H "X-Access-Key: ${TENDERLY_ACCESS_KEY}"
}

cleanup_vnets() {
    echo "Cleaning up VNETs..."
    for vnet_id in "${VNET_IDS[@]}"; do
        delete_vnet "$vnet_id"
    done
}

# Set up trap to cleanup VNETs on script exit due to error
trap 'cleanup_vnets' ERR

generate_slug() {
    local testnet_name=$1
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    local base_slug=$(echo "$testnet_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    # Take first 8 characters of commit hash
    local short_hash=$(echo "$COMMIT_HASH" | cut -c1-8)
    echo "${base_slug}-pr${PR_NUMBER}-${short_hash}"
}

create_virtual_testnet() {
    local testnet_name=$1
    local network_id=$2
    local chain_id=$3
    local account_name=$4
    local project_name=$5
    local access_key=$6
    
    local slug=$(generate_slug "$testnet_name")
    echo "---------------------------------" >&2
    echo "Creating TestNet with slug: $slug" >&2 
    
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
            "chain_id": $chain_id
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
    echo "Making API request to create virtual testnet..." >&2

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
        echo "Error creating TestNet: $response" >&2
        return 1
    fi
    
    echo "------------SUCCESS------------" >&2
    # Return both admin RPC and VNET ID
    echo "${admin_rpc}|${vnet_id}"
}

set_initial_balance() {
    local rpc_url=$1
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

# Create all VNETs first
echo "Creating Ethereum Mainnet Virtual Network for PR #${PR_NUMBER}..."
ETH_RESPONSE=$(create_virtual_testnet \
    "eth" \
    "$ETH_CHAIN_ID" \
    "$ETH_CHAIN_ID" \
    "$TENDERLY_ACCOUNT" \
    "$TENDERLY_PROJECT" \
    "$TENDERLY_ACCESS_KEY")
ETH_MAINNET=$(echo "$ETH_RESPONSE" | cut -d'|' -f1)
ETH_VNET_ID=$(echo "$ETH_RESPONSE" | cut -d'|' -f2)
VNET_IDS+=("$ETH_VNET_ID")

echo "Creating Base Mainnet Virtual Network for PR #${PR_NUMBER}..."
BASE_RESPONSE=$(create_virtual_testnet \
    "base" \
    "$BASE_CHAIN_ID" \
    "$BASE_CHAIN_ID" \
    "$TENDERLY_ACCOUNT" \
    "$TENDERLY_PROJECT" \
    "$TENDERLY_ACCESS_KEY")
BASE_MAINNET=$(echo "$BASE_RESPONSE" | cut -d'|' -f1)
BASE_VNET_ID=$(echo "$BASE_RESPONSE" | cut -d'|' -f2)
VNET_IDS+=("$BASE_VNET_ID")

echo "Creating Optimism Mainnet Virtual Network for PR #${PR_NUMBER}..."
OPTIMISM_RESPONSE=$(create_virtual_testnet \
    "op" \
    "$OPTIMISM_CHAIN_ID" \
    "$OPTIMISM_CHAIN_ID" \
    "$TENDERLY_ACCOUNT" \
    "$TENDERLY_PROJECT" \
    "$TENDERLY_ACCESS_KEY")
OPTIMISM_MAINNET=$(echo "$OPTIMISM_RESPONSE" | cut -d'|' -f1)
OPTIMISM_VNET_ID=$(echo "$OPTIMISM_RESPONSE" | cut -d'|' -f2)
VNET_IDS+=("$OPTIMISM_VNET_ID")

# Verify all VNETs were created successfully
if [ -z "$ETH_MAINNET" ] || [ -z "$BASE_MAINNET" ] || [ -z "$OPTIMISM_MAINNET" ]; then
    echo "Error: Failed to create one or more VNETs"
    [ -z "$ETH_MAINNET" ] && echo "- Ethereum Mainnet VNET creation failed"
    [ -z "$BASE_MAINNET" ] && echo "- Base Mainnet VNET creation failed"
    [ -z "$OPTIMISM_MAINNET" ] && echo "- Optimism Mainnet VNET creation failed"
    cleanup_vnets
    exit 1
fi

# Set up verifier URLs
ETH_MAINNET_VERIFIER_URL="$ETH_MAINNET/verify/etherscan"
BASE_MAINNET_VERIFIER_URL="$BASE_MAINNET/verify/etherscan"
OPTIMISM_MAINNET_VERIFIER_URL="$OPTIMISM_MAINNET/verify/etherscan"

# Set initial balances for all networks
echo "Setting initial balances..."
set_initial_balance "$ETH_MAINNET"
set_initial_balance "$BASE_MAINNET"
set_initial_balance "$OPTIMISM_MAINNET"

# Deploy on Ethereum Mainnet
echo "Deploying on Ethereum Mainnet..."
echo Deploy SuperDeployer on Ethereum: ...
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $ENVIRONMENT \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    echo "Failed to deploy SuperDeployer on Ethereum"
    cleanup_vnets
    exit 1
fi

echo Deploy V2 on Ethereum: ...
if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $ETH_CHAIN_ID "$COMMIT_HASH" \
    --verify \
    --verifier-url $ETH_MAINNET_VERIFIER_URL \
    --rpc-url $ETH_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    echo "Failed to deploy V2 on Ethereum"
    cleanup_vnets
    exit 1
fi
wait

# Deploy on Base Mainnet
echo "Deploying on Base Mainnet..."
echo Deploy SuperDeployer on Base: ...
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $ENVIRONMENT \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    echo "Failed to deploy SuperDeployer on Base"
    cleanup_vnets
    exit 1
fi

echo Deploy V2 on Base: ...
if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $BASE_CHAIN_ID "$COMMIT_HASH" \
    --verify \
    --verifier-url $BASE_MAINNET_VERIFIER_URL \
    --rpc-url $BASE_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    echo "Failed to deploy V2 on Base"
    cleanup_vnets
    exit 1
fi
wait

# Deploy on Optimism Mainnet
echo "Deploying on Optimism Mainnet..."
echo Deploy SuperDeployer on Optimism: ...
if ! forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
    --sig 'run(uint256)' $ENVIRONMENT \
    --verify \
    --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
    --rpc-url $OPTIMISM_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    echo "Failed to deploy SuperDeployer on Optimism"
    cleanup_vnets
    exit 1
fi

echo Deploy V2 on Optimism: ...
if ! forge script script/DeployV2.s.sol:DeployV2 \
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $OPTIMISM_CHAIN_ID "$COMMIT_HASH" \
    --verify \
    --verifier-url $OPTIMISM_MAINNET_VERIFIER_URL \
    --rpc-url $OPTIMISM_MAINNET \
    --etherscan-api-key $TENDERLY_ACCESS_KEY \
    --broadcast \
    --slow; then
    echo "Failed to deploy V2 on Optimism"
    cleanup_vnets
    exit 1
fi
wait

echo "All deployments completed successfully!"