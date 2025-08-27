#!/bin/bash

# Centralized Network Configuration for V2 Core Deployment
# This file contains all network definitions used across deployment scripts

# Define all supported networks with their configuration
# Format: "CHAIN_ID:NetworkName:RPC_VAR:VERIFIER_VAR"
NETWORKS=(
    "1:Ethereum:ETH_MAINNET:ETH_VERIFIER_URL"
    "8453:Base:BASE_MAINNET:BASE_VERIFIER_URL"
    "56:BNB:BSC_MAINNET:BSC_VERIFIER_URL"
    "42161:Arbitrum:ARBITRUM_MAINNET:ARBITRUM_VERIFIER_URL"
)

# Network name mapping function
get_network_name() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "Ethereum"
            ;;
        8453)
            echo "Base"
            ;;
        56)
            echo "BNB"
            ;;
        42161)
            echo "Arbitrum"
            ;;
        *)
            echo "ERROR: Unknown network ID: $network_id" >&2
            return 1
            ;;
    esac
}

# Get RPC URL variable name for network
get_rpc_var() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "ETH_MAINNET"
            ;;
        8453)
            echo "BASE_MAINNET"
            ;;
        56)
            echo "BSC_MAINNET"
            ;;
        42161)
            echo "ARBITRUM_MAINNET"
            ;;
        *)
            echo "ERROR: Unknown network ID for RPC: $network_id" >&2
            return 1
            ;;
    esac
}

# Get RPC URL value for network
get_rpc_url() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "$ETH_MAINNET"
            ;;
        8453)
            echo "$BASE_MAINNET"
            ;;
        56)
            echo "$BSC_MAINNET"
            ;;
        42161)
            echo "$ARBITRUM_MAINNET"
            ;;
        *)
            echo "ERROR: Unknown network ID for RPC: $network_id" >&2
            return 1
            ;;
    esac
}

# Get verifier URL variable name for network
get_verifier_var() {
    local network_id=$1
    case "$network_id" in
        1)
            echo "ETH_VERIFIER_URL"
            ;;
        8453)
            echo "BASE_VERIFIER_URL"
            ;;
        56)
            echo "BSC_VERIFIER_URL"
            ;;
        42161)
            echo "ARBITRUM_VERIFIER_URL"
            ;;
        *)
            echo "ERROR: Unknown network ID for verifier: $network_id" >&2
            return 1
            ;;
    esac
}

# Validate that a network ID is supported
is_network_supported() {
    local network_id=$1
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r id _ _ _ <<< "$network_def"
        if [ "$id" = "$network_id" ]; then
            return 0
        fi
    done
    return 1
}

# Get all supported network IDs
get_supported_networks() {
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id _ _ _ <<< "$network_def"
        echo "$network_id"
    done
}

# Load RPC URLs from credential manager for all networks
load_rpc_urls() {
    echo "Loading RPC URLs from credential manager..."
    export ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential)
    export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential)
    export BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential)
    export ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential)
    echo "✅ RPC URLs loaded successfully"
}

# Load Tenderly verification URLs for all networks
load_tenderly_urls() {
    if [ -z "$TENDERLY_ACCOUNT" ] || [ -z "$TENDERLY_PROJECT" ]; then
        echo "⚠️  Warning: TENDERLY_ACCOUNT and TENDERLY_PROJECT must be set before calling load_tenderly_urls"
        return 1
    fi
    
    echo "Setting up Tenderly verification URLs..."
    export ETH_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/1/public"
    export BASE_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/8453/public"
    export BSC_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/56/public"
    export ARBITRUM_VERIFIER_URL="https://api.tenderly.co/api/v1/account/$TENDERLY_ACCOUNT/project/$TENDERLY_PROJECT/etherscan/verify/network/42161/public"
    echo "✅ Tenderly verification URLs configured"
}

# Print network information
print_network_info() {
    echo "Supported Networks:"
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var verifier_var <<< "$network_def"
        echo "  - $network_name (Chain ID: $network_id)"
    done
}