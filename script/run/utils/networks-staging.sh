#!/usr/bin/env bash

# Staging Network Configuration for V2 Core Deployment
# This file contains staging network definitions (subset for testing)

# Define staging networks
# Format: "CHAIN_ID:NetworkName:RPC_VAR"
NETWORKS=(
    "1:Ethereum:ETH_MAINNET"
    "8453:Base:BASE_MAINNET"
    "56:BNB:BSC_MAINNET"
    "42161:Arbitrum:ARBITRUM_MAINNET"
    "43114:Avalanche:AVALANCHE_MAINNET"
    "999:HyperEVM:HYPEREVM_MAINNET"
    "14:Flare:FLARE_MAINNET"
    "4663:RH:RH_MAINNET"
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
        43114)
            echo "Avalanche"
            ;;
        999)
            echo "HyperEVM"
            ;;
        14)
            echo "Flare"
            ;;
        4663)
            echo "RH"
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
        43114)
            echo "AVALANCHE_MAINNET"
            ;;
        999)
            echo "HYPEREVM_MAINNET"
            ;;
        14)
            echo "FLARE_MAINNET"
            ;;
        4663)
            echo "RH_MAINNET"
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
        43114)
            echo "$AVALANCHE_MAINNET"
            ;;
        999)
            echo "$HYPEREVM_MAINNET"
            ;;
        14)
            echo "$FLARE_MAINNET"
            ;;
        4663)
            echo "$RH_MAINNET"
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


# Read a 1Password secret with one retry and a same-named environment-variable fallback.
# Burst reads can transiently fail against the desktop-app integration (authorization race),
# and `export VAR=$(op read ...)` masks failures (export always exits 0) — so detect emptiness
# explicitly, retry once, then fall back to an already-exported env var of the same name (.env).
op_read_rpc() {
    local item=$1
    local val
    val=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/${item}/credential" 2>/dev/null | tr -d '\n') || val=""
    if [[ -z "$val" ]]; then
        sleep 2
        val=$(op read "op://5ylebqljbh3x6zomdxi3qd7tsa/${item}/credential" 2>/dev/null | tr -d '\n') || val=""
    fi
    if [[ -z "$val" ]]; then
        val=$(printenv "$item" 2>/dev/null || true)
    fi
    printf '%s' "$val"
}

# Load RPC URLs from credential manager for staging networks
load_rpc_urls() {
    echo "Loading staging RPC URLs from credential manager..."

    local failed_rpcs=()

    echo "  • Loading Ethereum RPC..."
    export ETH_MAINNET="$(op_read_rpc ETHEREUM_RPC_URL)"
        [[ -z "${ETH_MAINNET}" ]] && failed_rpcs+=("ETHEREUM_RPC_URL")

    echo "  • Loading Base RPC..."
    export BASE_MAINNET="$(op_read_rpc BASE_RPC_URL)"
        [[ -z "${BASE_MAINNET}" ]] && failed_rpcs+=("BASE_RPC_URL")

    echo "  • Loading BSC RPC..."
    export BSC_MAINNET="$(op_read_rpc BSC_RPC_URL)"
        [[ -z "${BSC_MAINNET}" ]] && failed_rpcs+=("BSC_RPC_URL")

    echo "  • Loading Arbitrum RPC..."
    export ARBITRUM_MAINNET="$(op_read_rpc ARBITRUM_RPC_URL)"
        [[ -z "${ARBITRUM_MAINNET}" ]] && failed_rpcs+=("ARBITRUM_RPC_URL")

    echo "  • Loading Avalanche RPC..."
    export AVALANCHE_MAINNET="$(op_read_rpc AVALANCHE_RPC_URL)"
        [[ -z "${AVALANCHE_MAINNET}" ]] && failed_rpcs+=("AVALANCHE_RPC_URL")

    echo "  • Loading HyperEVM RPC..."
    export HYPEREVM_MAINNET="$(op_read_rpc HYPEREVM_RPC_URL)"
        [[ -z "${HYPEREVM_MAINNET}" ]] && failed_rpcs+=("HYPEREVM_RPC_URL")

    echo "  • Loading Flare RPC..."
    export FLARE_MAINNET="$(op_read_rpc FLARE_RPC_URL)"
        [[ -z "${FLARE_MAINNET}" ]] && failed_rpcs+=("FLARE_RPC_URL")

    echo "  • Loading RH RPC..."
    export RH_MAINNET="$(op_read_rpc RH_RPC_URL)"
        [[ -z "${RH_MAINNET}" ]] && failed_rpcs+=("RH_RPC_URL")

    if [[ ${#failed_rpcs[@]} -gt 0 ]]; then
        echo "❌ Failed to load the following RPC URLs from 1Password:"
        for failed_rpc in "${failed_rpcs[@]}"; do
            echo "   • $failed_rpc"
        done
        echo "⚠️  Some networks may not be accessible during deployment"
        return 1
    fi

    echo "✅ Staging RPC URLs loaded successfully (all networks)"
}

# Load Etherscan V2 API key for verification
load_etherscan_api_key() {
    echo "Loading Etherscan V2 API key for staging verification..."
    if ! export ETHERSCANV2_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY/credential 2>/dev/null); then
        echo "❌ Failed to load ETHERSCANV2_API_KEY from 1Password"
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
