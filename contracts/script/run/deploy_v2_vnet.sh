#!/bin/bash

# Environment and Chain IDs
ENVIRONMENT=1  # Environment 1 for tenderly vnet execution
ETH_CHAIN_ID=1
BASE_CHAIN_ID=8453
OPTIMISM_CHAIN_ID=10

# Add branch name as first argument and commit hash as second argument
BRANCH_NAME=$1

if [ -z "$BRANCH_NAME" ]; then
    echo "Error: Branch name is required"
    exit 1
fi

# Helper function to check if running locally
is_local_run() {
    command -v op >/dev/null 2>&1
    return $?
}

# Check if running locally
if is_local_run; then
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

update_counter() {
    local slug=$1
    local vnet_id=$2
    
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/script/output/vnet_counters.json")
    
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
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/script/output/vnet_counters.json" \
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
        return 1
    fi

    echo "$new_counter"
    return 0
}

check_existing_vnet() {
    local slug=$1
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        "https://api.github.com/repos/$GITHUB_REPOSITORY/contents/script/output/vnet_counters.json")
    
    if [ "$(echo "$response" | jq -r '.message')" == "Not Found" ]; then
        return 1
    fi

    local content=$(echo "$response" | jq -r '.content' | base64 --decode)
    local vnet_id=$(echo "$content" | jq -r ".slugs[\"$slug\"].vnet_id // empty")
    
    if [ -n "$vnet_id" ]; then
        # Check if VNET still exists in Tenderly
        local tenderly_response=$(curl -s -X GET \
            "${API_BASE_URL}/account/${TENDERLY_ACCOUNT}/project/${TENDERLY_PROJECT}/vnets/${vnet_id}" \
            -H "X-Access-Key: ${TENDERLY_ACCESS_KEY}")
        
        if [ "$(echo "$tenderly_response" | jq -r '.id')" == "$vnet_id" ]; then
            echo "$vnet_id"
            return 0
        fi
    fi
    
    return 1
}

generate_slug() {
    local network=$1
    local output="${BRANCH_NAME//\//-}-${network}"
    # Convert to lowercase, replace spaces with hyphens, remove special chars
    local output=$(echo "$output" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    echo "$output"
}

create_virtual_testnet() {
    local testnet_name=$1
    local slug=$2
    local network_id=$3
    local account_name=$4
    local project_name=$5
    local access_key=$6
    
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

# Create VNETs and get salts for each network
for network in 1 8453 10; do
    slug=$(generate_slug "$network")
    
    if is_local_run; then
        # Local run - create new VNET and use salt=1
        response=$(create_virtual_testnet "$network" "$slug" "$network" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
        vnet_id=$(echo "$response" | cut -d'|' -f2)
        salt="1"
    else
        # CI run - check existing VNET and handle counter
        existing_vnet_id=$(check_existing_vnet "$slug")
        if [ -n "$existing_vnet_id" ]; then
            vnet_id="$existing_vnet_id"
            response=$(create_virtual_testnet "$network" "$slug" "$network" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
            vnet_id=$(echo "$response" | cut -d'|' -f2)
        else
            response=$(create_virtual_testnet "$network" "$slug" "$network" "$TENDERLY_ACCOUNT" "$TENDERLY_PROJECT" "$TENDERLY_ACCESS_KEY")
            vnet_id=$(echo "$response" | cut -d'|' -f2)
        fi
        
        salt=$(get_salt "$slug" "$vnet_id")
        if [ $? -ne 0 ]; then
            echo "Failed to get salt for $slug"
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
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $ETH_CHAIN_ID "$ETH_SALT" \
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
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $BASE_CHAIN_ID "$BASE_SALT" \
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
    --sig 'run(uint256,uint64,string)' $ENVIRONMENT $OPTIMISM_CHAIN_ID "$OPTIMISM_SALT" \
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