#!/usr/bin/env bash

# oracle-utils.sh
# Shared utility functions for oracle configuration scripts

# Map oracle name to salt string
# NOTE: Salts must be <=32 bytes. Solidity uses bytes32(bytes(string)) which truncates longer strings.
# Check character count: echo -n "string" | wc -c
get_oracle_salt() {
    local oracle_name=$1
    case $oracle_name in
        "ERC4626YieldSourceOracle")
            # 32 chars
            echo "ERC4626YieldSourceOracle_v1.0.1"
            ;;
        "ERC5115YieldSourceOracle")
            # 32 chars
            echo "ERC5115YieldSourceOracle_v1.0.1"
            ;;
        "StakingYieldSourceOracle")
            # 32 chars
            echo "StakingYieldSourceOracle_v1.0.1"
            ;;
        "SuperVaultYieldSourceOracle")
            # 34 chars -> truncated to 32: SuperVaultYieldSourceOracle_v1.0
            echo "SuperVaultYieldSourceOracle_v1.0"
            ;;
        "PendlePTYieldSourceOracle")
            # 33 chars -> truncated to 32: PendlePTYieldSourceOracle_v1.0.
            echo "PendlePTYieldSourceOracle_v1.0."
            ;;
        "SpectraPTYieldSourceOracle")
            # 34 chars -> truncated to 32: SpectraPTYieldSourceOracle_v1.0
            echo "SpectraPTYieldSourceOracle_v1.0"
            ;;
        "SuperYieldSourceOracle")
            # 30 chars
            echo "SuperYieldSourceOracle_v1.0.1"
            ;;
        *)
            # Default: use oracle name + version, truncate to 32 chars if needed
            local salt="${oracle_name}_v1.0.1"
            echo "${salt:0:32}"
            ;;
    esac
}

# Compute oracle ID using Solidity logic: keccak256(abi.encodePacked(salt, sender))
compute_oracle_id() {
    local salt=$1
    local sender=$2

    # Convert salt string to bytes32
    local salt_bytes32=$(cast --to-bytes32 "$(cast --from-utf8 "$salt")")

    # Compute keccak256(abi.encodePacked(salt, sender))
    # In abi.encodePacked, bytes32 is 32 bytes and address is 20 bytes (no padding)
    local packed="${salt_bytes32}${sender#0x}"
    local oracle_id=$(cast keccak "$packed")

    echo "$oracle_id"
}

# Check if oracle is already configured on-chain
check_oracle_configured() {
    local rpc_url=$1
    local config_address=$2
    local oracle_id=$3

    # Suppress nightly warning by filtering stderr
    local result=$(FOUNDRY_DISABLE_NIGHTLY_WARNING=1 cast call "$config_address" \
        "getYieldSourceOracleConfig(bytes32)(address,uint256,address,address,address)" \
        "$oracle_id" \
        --rpc-url "$rpc_url" 2>/dev/null) || true

    if [ -z "$result" ] || echo "$result" | grep -q "error"; then
        return 1
    fi

    # Parse the result - check if yieldSourceOracle (1st field) is non-zero
    # The result has 5 lines, one per return value
    local oracle_address=$(echo "$result" | sed -n '1p')

    if [ "$oracle_address" != "0x0000000000000000000000000000000000000000" ]; then
        return 0
    fi

    return 1
}

# Get wallet address from account name
get_wallet_address() {
    local account_name=$1

    # Use cast wallet address with empty password for imported wallets
    # This will prompt for password if needed, but imported wallets typically work
    local address=$(echo "" | FOUNDRY_DISABLE_NIGHTLY_WARNING=1 cast wallet address "$account_name" 2>/dev/null || true)

    if [ -n "$address" ] && [[ "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "$address"
        return 0
    fi

    # Fallback: Try to extract from keystore JSON (older format keystores)
    local keystore_dir="$HOME/.foundry/keystores"
    local keystore_file="$keystore_dir/$account_name"

    if [ -f "$keystore_file" ]; then
        local address=$(jq -r '.address' "$keystore_file" 2>/dev/null)
        if [ -n "$address" ] && [ "$address" != "null" ]; then
            # Ensure 0x prefix
            if [[ ! "$address" =~ ^0x ]]; then
                address="0x$address"
            fi
            echo "$address"
            return 0
        fi
    fi

    echo "ERROR: Could not extract address from wallet: $account_name" >&2
    echo "ERROR: Try running: cast wallet address $account_name" >&2
    return 1
}
