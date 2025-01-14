#!/bin/bash

# Add PR number as first argument
PR_NUMBER=$1

if [ -z "$PR_NUMBER" ]; then
    echo "Error: PR number is required"
    exit 1
fi


API_BASE_URL="https://api.tenderly.co/api/v1"
# Load environment variables
TENDERLY_ACCESS_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/TENDERLY_ACCESS_KEY/credential)
TENDERLY_ACCOUNT="superform"
TENDERLY_PROJECT="v2"

generate_slug() {
    local testnet_name=$1
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    local base_slug=$(echo "$testnet_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "${base_slug}-pr${PR_NUMBER}"
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
    echo "Making API request to create virtual testnet..." >&2  # Add status message

    # Make API request
    local response=$(curl -s -X POST \
        "${API_BASE_URL}/account/${account_name}/project/${project_name}/vnets" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "X-Access-Key: ${access_key}" \
        -d "$json_data")

    # Extract RPC URLs using jq
    local admin_rpc=$(echo "$response" | jq -r '.rpcs[] | select(.name=="Admin RPC") | .url')
    local public_rpc=$(echo "$response" | jq -r '.rpcs[] | select(.name=="Public RPC") | .url')
    local vnet_id=$(echo "$response" | jq -r '.id')

    if [ -z "$admin_rpc" ] || [ -z "$public_rpc" ]; then
        echo "Error creating TestNet: $response" >&2
        return 1
    fi
    
    echo "------------SUCCESS------------" >&2
    # Return results as JSON
    echo $admin_rpc
}


# Create Ethereum Mainnet fork VNet
echo "Creating Ethereum Mainnet Virtual Network for PR #${PR_NUMBER}..."
ETH_MAINNET=$(create_virtual_testnet \
    "eth-mainnet-fork" \
    "1" \
    "1" \
    "$TENDERLY_ACCOUNT" \
    "$TENDERLY_PROJECT" \
    "$TENDERLY_ACCESS_KEY")

ETH_MAINNET_VERIFIER_URL="$ETH_MAINNET/verify/etherscan"

if [ -n "$ETH_MAINNET" ]; then
    curl $ETH_MAINNET \
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

    echo Deploy SuperDeployer on network 1: ...
    forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
        --sig 'run(uint256)' 1 \
        --verify \
        --verifier-url $ETH_MAINNET_VERIFIER_URL \
        --rpc-url $ETH_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --slow

    echo Deploy V2 on network 1: ...
    forge script script/DeployV2.s.sol:DeployV2 \
        --sig 'run(uint256,uint64)' 1 1 \
        --verify \
        --verifier-url $ETH_MAINNET_VERIFIER_URL \
        --rpc-url $ETH_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --slow
    wait
else
    echo "ETH_MAINNET RPC URL not found. Exiting."
    exit 0
fi

# Create Base Mainnet fork VNet
echo "Creating Base Mainnet Virtual Network for PR #${PR_NUMBER}..."
BASE_MAINNET=$(create_virtual_testnet \
    "base-mainnet-fork" \
    "8453" \
    "8453" \
    "$TENDERLY_ACCOUNT" \
    "$TENDERLY_PROJECT" \
    "$TENDERLY_ACCESS_KEY")

BASE_MAINNET_VERIFIER_URL="$BASE_MAINNET/verify/etherscan"

if [ -n "$BASE_MAINNET" ]; then
    curl $BASE_MAINNET \
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

    wait

    echo Deploy SuperDeployer on network 2: ...
    forge script script/DeploySuperDeployer.s.sol:DeploySuperDeployer \
        --sig 'run(uint256)' 1 \
        --verify \
        --verifier-url $BASE_MAINNET_VERIFIER_URL \
        --rpc-url $BASE_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --slow

    wait

    echo Deploy V2 on network 2: ...
    forge script script/DeployV2.s.sol:DeployV2 \
        --sig 'run(uint256,uint64)' 1 8453 \
        --verify \
        --verifier-url $BASE_MAINNET_VERIFIER_URL \
        --rpc-url $BASE_MAINNET \
        --etherscan-api-key $TENDERLY_ACCESS_KEY \
        --broadcast \
        --slow
    wait
else
    echo "BASE_MAINNET RPC URL not found. Exiting."
    exit 0
fi