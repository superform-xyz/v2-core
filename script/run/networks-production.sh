#!/bin/bash

# Production Network Configuration for V2 Core Deployment
# This file contains all production network definitions (full mainnet deployment)

# Define production networks
# Format: "CHAIN_ID:NetworkName:RPC_VAR"
NETWORKS=(
    "1:Ethereum:ETH_MAINNET"
    "8453:Base:BASE_MAINNET"
    "56:BNB:BSC_MAINNET"
    "42161:Arbitrum:ARBITRUM_MAINNET"
    "10:Optimism:OPTIMISM_MAINNET"
    "137:Polygon:POLYGON_MAINNET"
    "130:Unichain:UNICHAIN_MAINNET"
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
        10)
            echo "Optimism"
            ;;
        137)
            echo "Polygon"
            ;;
        130)
            echo "Unichain"
            ;;
        *)
            echo "ERROR: Unknown production network ID: $network_id" >&2
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
        10)
            echo "OPTIMISM_MAINNET"
            ;;
        137)
            echo "POLYGON_MAINNET"
            ;;
        130)
            echo "UNICHAIN_MAINNET"
            ;;
        *)
            echo "ERROR: Unknown production network ID for RPC: $network_id" >&2
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
        10)
            echo "$OPTIMISM_MAINNET"
            ;;
        137)
            echo "$POLYGON_MAINNET"
            ;;
        130)
            echo "$UNICHAIN_MAINNET"
            ;;
        *)
            echo "ERROR: Unknown production network ID for RPC: $network_id" >&2
            return 1
            ;;
    esac
}

# Validate that a network ID is supported in production
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

# Get all supported production network IDs
get_supported_networks() {
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id _ _ <<< "$network_def"
        echo "$network_id"
    done
}

# Load RPC URLs from credential manager for all production networks
load_rpc_urls() {
    echo "Loading production RPC URLs from credential manager..."
    
    local failed_rpcs=()
    
    # Load core networks (same as staging)
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
    
    # Load production-only networks
    echo "  • Loading Optimism RPC..."
    if ! export OPTIMISM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/OPTIMISM_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("OPTIMISM_RPC_URL")
    fi
    
    echo "  • Loading Polygon RPC..."
    if ! export POLYGON_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/POLYGON_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("POLYGON_RPC_URL")
    fi
    
    echo "  • Loading Unichain RPC..."
    if ! export UNICHAIN_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/UNICHAIN_RPC_URL/credential 2>/dev/null); then
        failed_rpcs+=("UNICHAIN_RPC_URL")
    fi
    
    if [[ ${#failed_rpcs[@]} -gt 0 ]]; then
        echo "❌ Failed to load the following RPC URLs from 1Password:"
        for failed_rpc in "${failed_rpcs[@]}"; do
            echo "   • $failed_rpc"
        done
        echo "⚠️  Some networks may not be accessible during deployment"
        return 1
    fi
    
    echo "✅ Production RPC URLs loaded successfully (all 7 networks)"
}

# Load Etherscan V2 API key for verification
load_etherscan_api_key() {
    echo "Loading Etherscan V2 API key for production verification..."
    if ! export ETHERSCANV2_API_KEY_TEST=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY_TEST/credential 2>/dev/null); then
        echo "❌ Failed to load ETHERSCANV2_API_KEY_TEST from 1Password"
        echo "   Contract verification will not work without this credential"
        return 1
    fi
    echo "✅ Etherscan V2 API key loaded for production"
}

# Print production network information
print_network_info() {
    echo "Production Networks Configuration:"
    for network_def in "${NETWORKS[@]}"; do
        IFS=':' read -r network_id network_name rpc_var <<< "$network_def"
        echo "  - $network_name (Chain ID: $network_id)"
    done
}
