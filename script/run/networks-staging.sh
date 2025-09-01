#!/bin/bash

# Staging Network Configuration for V2 Core Deployment
# This file contains staging network definitions (subset for testing)

# Define staging networks
# Format: "CHAIN_ID:NetworkName:RPC_VAR"
NETWORKS=(
    "1:Ethereum:ETH_MAINNET"
    "8453:Base:BASE_MAINNET"
    "56:BNB:BSC_MAINNET"
    "42161:Arbitrum:ARBITRUM_MAINNET"
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
            echo "ERROR: Unknown staging network ID: $network_id" >&2
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
            echo "ERROR: Unknown staging network ID for RPC: $network_id" >&2
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
            echo "ERROR: Unknown staging network ID for RPC: $network_id" >&2
            return 1
            ;;
    esac
}

# Validate that a network ID is supported in staging
is_network_supported() {
    local network_id=$1
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r id _ _ <<< "$network_def"
        if [ "$id" = "$network_id" ]; then
            return 0
        fi
    done
    return 1
}

# Get all supported staging network IDs
get_supported_networks() {
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id _ _ <<< "$network_def"
        echo "$network_id"
    done
}

# Load RPC URLs from credential manager for staging networks
load_rpc_urls() {
    echo "Loading staging RPC URLs from credential manager..."
    
    local failed_rpcs=()
    
    echo "  • Loading Ethereum RPC..."
    if ! export ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("ETHEREUM_RPC_URL")
    fi
    
    echo "  • Loading Base RPC..."
    if ! export BASE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BASE_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("BASE_RPC_URL")
    fi
    
    echo "  • Loading BSC RPC..."
    if ! export BSC_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/BSC_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("BSC_RPC_URL")
    fi
    
    echo "  • Loading Arbitrum RPC..."
    if ! export ARBITRUM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ARBITRUM_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("ARBITRUM_RPC_URL")
    fi
    
    if [[ ${#failed_rpcs[@]} -gt 0 ]]; then
        echo "❌ Failed to load the following RPC URLs from 1Password:"
        for failed_rpc in "${failed_rpcs[@]}"; do
            echo "   • $failed_rpc"
        done
        echo "⚠️  Some networks may not be accessible during deployment"
        return 1
    fi
    
    echo "✅ Staging RPC URLs loaded successfully (all 4 networks)"
}

# Load Etherscan V2 API key for verification
load_etherscan_api_key() {
    echo "Loading Etherscan V2 API key for staging verification..."
    if ! export ETHERSCANV2_API_KEY_TEST=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY_TEST/credential 2>/dev/null); then
        echo "❌ Failed to load ETHERSCANV2_API_KEY_TEST from 1Password"
        echo "   Contract verification will not work without this credential"
        return 1
    fi
    echo "✅ Etherscan V2 API key loaded for staging"
}

# Print staging network information
print_network_info() {
    echo "Staging Networks Configuration:"
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var <<< "$network_def"
        echo "  - $network_name (Chain ID: $network_id)"
    done
}
