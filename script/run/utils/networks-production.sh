#!/usr/bin/env bash

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
    "43114:Avalanche:AVALANCHE_MAINNET"
    "59144:Linea:LINEA_MAINNET"
    "80094:Berachain:BERACHAIN_MAINNET"
    "146:Sonic:SONIC_MAINNET"
    "100:Gnosis:GNOSIS_MAINNET"
    "480:Worldchain:WORLDCHAIN_MAINNET"
    "999:HyperEVM:HYPEREVM_MAINNET"
    "14:Flare:FLARE_MAINNET"
    "988:Stable:STABLE_MAINNET"
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
        10)
            echo "Optimism"
            ;;
        137)
            echo "Polygon"
            ;;
        130)
            echo "Unichain"
            ;;
        43114)
            echo "Avalanche"
            ;;
        59144)
            echo "Linea"
            ;;
        80094)
            echo "Berachain"
            ;;
        146)
            echo "Sonic"
            ;;
        100)
            echo "Gnosis"
            ;;
        480)
            echo "Worldchain"
            ;;
        999)
            echo "HyperEVM"
            ;;
        14)
            echo "Flare"
            ;;
        988)
            echo "Stable"
            ;;
        4663)
            echo "RH"
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
        43114)
            echo "AVALANCHE_MAINNET"
            ;;
        59144)
            echo "LINEA_MAINNET"
            ;;
        80094)
            echo "BERACHAIN_MAINNET"
            ;;
        146)
            echo "SONIC_MAINNET"
            ;;
        100)
            echo "GNOSIS_MAINNET"
            ;;
        480)
            echo "WORLDCHAIN_MAINNET"
            ;;
        999)
            echo "HYPEREVM_MAINNET"
            ;;
        14)
            echo "FLARE_MAINNET"
            ;;
        988)
            echo "STABLE_MAINNET"
            ;;
        4663)
            echo "RH_MAINNET"
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
        43114)
            echo "$AVALANCHE_MAINNET"
            ;;
        59144)
            echo "$LINEA_MAINNET"
            ;;
        80094)
            echo "$BERACHAIN_MAINNET"
            ;;
        146)
            echo "$SONIC_MAINNET"
            ;;
        100)
            echo "$GNOSIS_MAINNET"
            ;;
        480)
            echo "$WORLDCHAIN_MAINNET"
            ;;
        999)
            echo "$HYPEREVM_MAINNET"
            ;;
        14)
            echo "$FLARE_MAINNET"
            ;;
        988)
            echo "$STABLE_MAINNET"
            ;;
        4663)
            echo "$RH_MAINNET"
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

# Load RPC URLs from environment variables for CI
load_rpc_urls_ci() {
    echo "Loading production RPC URLs from environment variables..."

    local failed_rpcs=()

    echo "  • Loading Ethereum RPC..."
    if [[ -n "${ETHEREUM_RPC_URL:-}" ]]; then
        export ETH_MAINNET="$ETHEREUM_RPC_URL"
    else
        failed_rpcs+=("ETHEREUM_RPC_URL")
    fi

    echo "  • Loading Base RPC..."
    if [[ -n "${BASE_RPC_URL:-}" ]]; then
        export BASE_MAINNET="$BASE_RPC_URL"
    else
        failed_rpcs+=("BASE_RPC_URL")
    fi

    echo "  • Loading BSC RPC..."
    if [[ -n "${BSC_RPC_URL:-}" ]]; then
        export BSC_MAINNET="$BSC_RPC_URL"
    else
        failed_rpcs+=("BSC_RPC_URL")
    fi

    echo "  • Loading Arbitrum RPC..."
    if [[ -n "${ARBITRUM_RPC_URL:-}" ]]; then
        export ARBITRUM_MAINNET="$ARBITRUM_RPC_URL"
    else
        failed_rpcs+=("ARBITRUM_RPC_URL")
    fi

    echo "  • Loading Optimism RPC..."
    if [[ -n "${OPTIMISM_RPC_URL:-}" ]]; then
        export OPTIMISM_MAINNET="$OPTIMISM_RPC_URL"
    else
        failed_rpcs+=("OPTIMISM_RPC_URL")
    fi

    echo "  • Loading Polygon RPC..."
    if [[ -n "${POLYGON_RPC_URL:-}" ]]; then
        export POLYGON_MAINNET="$POLYGON_RPC_URL"
    else
        failed_rpcs+=("POLYGON_RPC_URL")
    fi

    echo "  • Loading Unichain RPC..."
    if [[ -n "${UNICHAIN_RPC_URL:-}" ]]; then
        export UNICHAIN_MAINNET="$UNICHAIN_RPC_URL"
    else
        failed_rpcs+=("UNICHAIN_RPC_URL")
    fi

    echo "  • Loading Avalanche RPC..."
    if [[ -n "${AVALANCHE_RPC_URL:-}" ]]; then
        export AVALANCHE_MAINNET="$AVALANCHE_RPC_URL"
    else
        failed_rpcs+=("AVALANCHE_RPC_URL")
    fi

    echo "  • Loading Linea RPC..."
    if [[ -n "${LINEA_RPC_URL:-}" ]]; then
        export LINEA_MAINNET="$LINEA_RPC_URL"
    else
        failed_rpcs+=("LINEA_RPC_URL")
    fi

    echo "  • Loading Berachain RPC..."
    if [[ -n "${BERACHAIN_RPC_URL:-}" ]]; then
        export BERACHAIN_MAINNET="$BERACHAIN_RPC_URL"
    else
        failed_rpcs+=("BERACHAIN_RPC_URL")
    fi

    echo "  • Loading Sonic RPC..."
    if [[ -n "${SONIC_RPC_URL:-}" ]]; then
        export SONIC_MAINNET="$SONIC_RPC_URL"
    else
        failed_rpcs+=("SONIC_RPC_URL")
    fi

    echo "  • Loading Gnosis RPC..."
    if [[ -n "${GNOSIS_RPC_URL:-}" ]]; then
        export GNOSIS_MAINNET="$GNOSIS_RPC_URL"
    else
        failed_rpcs+=("GNOSIS_RPC_URL")
    fi

    echo "  • Loading Worldchain RPC..."
    if [[ -n "${WORLDCHAIN_RPC_URL:-}" ]]; then
        export WORLDCHAIN_MAINNET="$WORLDCHAIN_RPC_URL"
    else
        failed_rpcs+=("WORLDCHAIN_RPC_URL")
    fi

    echo "  • Loading HyperEVM RPC..."
    if [[ -n "${HYPEREVM_RPC_URL:-}" ]]; then
        export HYPEREVM_MAINNET="$HYPEREVM_RPC_URL"
    else
        failed_rpcs+=("HYPEREVM_RPC_URL")
    fi

    echo "  • Loading Flare RPC..."
    if [[ -n "${FLARE_RPC_URL:-}" ]]; then
        export FLARE_MAINNET="$FLARE_RPC_URL"
    else
        failed_rpcs+=("FLARE_RPC_URL")
    fi

    echo "  • Loading Stable RPC..."
    if [[ -n "${STABLE_RPC_URL:-}" ]]; then
        export STABLE_MAINNET="$STABLE_RPC_URL"
    else
        failed_rpcs+=("STABLE_RPC_URL")
    fi

    echo "  • Loading RH RPC..."
    if [[ -n "${RH_RPC_URL:-}" ]]; then
        export RH_MAINNET="$RH_RPC_URL"
    else
        failed_rpcs+=("RH_RPC_URL")
    fi

    if [[ ${#failed_rpcs[@]} -gt 0 ]]; then
        echo "❌ Failed to load the following RPC URLs from environment:"
        for failed_rpc in "${failed_rpcs[@]}"; do
            echo "   • $failed_rpc"
        done
        echo "⚠️  Some networks may not be accessible during testing"
        return 1
    fi

    echo "✅ Production RPC URLs loaded successfully from environment"
}

# Load RPC URLs from credential manager for all production networks
load_rpc_urls() {
    echo "Loading production RPC URLs from credential manager..."

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

    echo "  • Loading Optimism RPC..."
    export OPTIMISM_MAINNET="$(op_read_rpc OPTIMISM_RPC_URL)"
        [[ -z "${OPTIMISM_MAINNET}" ]] && failed_rpcs+=("OPTIMISM_RPC_URL")

    echo "  • Loading Polygon RPC..."
    export POLYGON_MAINNET="$(op_read_rpc POLYGON_RPC_URL)"
        [[ -z "${POLYGON_MAINNET}" ]] && failed_rpcs+=("POLYGON_RPC_URL")

    echo "  • Loading Unichain RPC..."
    export UNICHAIN_MAINNET="$(op_read_rpc UNICHAIN_RPC_URL)"
        [[ -z "${UNICHAIN_MAINNET}" ]] && failed_rpcs+=("UNICHAIN_RPC_URL")

    echo "  • Loading Avalanche RPC..."
    export AVALANCHE_MAINNET="$(op_read_rpc AVALANCHE_RPC_URL)"
        [[ -z "${AVALANCHE_MAINNET}" ]] && failed_rpcs+=("AVALANCHE_RPC_URL")

    echo "  • Loading Linea RPC..."
    export LINEA_MAINNET="$(op_read_rpc LINEA_RPC_URL)"
        [[ -z "${LINEA_MAINNET}" ]] && failed_rpcs+=("LINEA_RPC_URL")

    echo "  • Loading Berachain RPC..."
    export BERACHAIN_MAINNET="$(op_read_rpc BERACHAIN_RPC_URL)"
        [[ -z "${BERACHAIN_MAINNET}" ]] && failed_rpcs+=("BERACHAIN_RPC_URL")

    echo "  • Loading Sonic RPC..."
    export SONIC_MAINNET="$(op_read_rpc SONIC_RPC_URL)"
        [[ -z "${SONIC_MAINNET}" ]] && failed_rpcs+=("SONIC_RPC_URL")

    echo "  • Loading Gnosis RPC..."
    export GNOSIS_MAINNET="$(op_read_rpc GNOSIS_RPC_URL)"
        [[ -z "${GNOSIS_MAINNET}" ]] && failed_rpcs+=("GNOSIS_RPC_URL")

    echo "  • Loading Worldchain RPC..."
    export WORLDCHAIN_MAINNET="$(op_read_rpc WORLDCHAIN_RPC_URL)"
        [[ -z "${WORLDCHAIN_MAINNET}" ]] && failed_rpcs+=("WORLDCHAIN_RPC_URL")

    echo "  • Loading HyperEVM RPC..."
    export HYPEREVM_MAINNET="$(op_read_rpc HYPEREVM_RPC_URL)"
        [[ -z "${HYPEREVM_MAINNET}" ]] && failed_rpcs+=("HYPEREVM_RPC_URL")

    echo "  • Loading Flare RPC..."
    export FLARE_MAINNET="$(op_read_rpc FLARE_RPC_URL)"
        [[ -z "${FLARE_MAINNET}" ]] && failed_rpcs+=("FLARE_RPC_URL")

    echo "  • Loading Stable RPC..."
    export STABLE_MAINNET="$(op_read_rpc STABLE_RPC_URL)"
        [[ -z "${STABLE_MAINNET}" ]] && failed_rpcs+=("STABLE_RPC_URL")

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

    echo "✅ Production RPC URLs loaded successfully"
}

# Load Etherscan V2 API key for verification
load_etherscan_api_key() {
    echo "Loading Etherscan V2 API key for production verification..."
    if ! export ETHERSCANV2_API_KEY=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHERSCANV2_API_KEY/credential 2>/dev/null); then
        echo "❌ Failed to load ETHERSCANV2_API_KEY from 1Password"
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
