#!/usr/bin/env bash

# oracle-utils.sh
# Shared utility functions for oracle configuration scripts

# Validate salt length is <= 32 bytes, matching Solidity's require check
# Errors out if salt is too long instead of silently truncating
validate_salt_length() {
    local salt=$1
    local oracle_name=$2
    local length=${#salt}
    if [ "$length" -gt 32 ]; then
        echo "ERROR: SALT_STRING_TOO_LONG for $oracle_name" >&2
        echo "ERROR: Salt '$salt' is $length bytes, max allowed is 32 bytes" >&2
        exit 1
    fi
}

# Map oracle name to salt string
# NOTE: Salts must be <=32 bytes. Solidity uses bytes32(bytes(string)) which truncates longer strings.
# Check character count: echo -n "string" | wc -c
get_oracle_salt() {
    local oracle_name=$1
    local salt=""
    case $oracle_name in
        "ERC4626YieldSourceOracle")
            # 32 chars
            salt="ERC4626YieldSourceOracle_v1.0.1"
            ;;
        "ERC5115YieldSourceOracle")
            # 32 chars
            salt="ERC5115YieldSourceOracle_v1.0.1"
            ;;
        "StakingYieldSourceOracle")
            # 32 chars
            salt="StakingYieldSourceOracle_v1.0.1"
            ;;
        "SuperVaultYieldSourceOracle")
            # 32 chars
            salt="SuperVaultYieldSourceOracle_v1.0"
            ;;
        "PendlePTYieldSourceOracle")
            # 32 chars
            salt="PendlePTYieldSourceOracle_v1.0."
            ;;
        "SpectraPTYieldSourceOracle")
            # 32 chars
            salt="SpectraPTYieldSourceOracle_v1.0"
            ;;
        "SuperYieldSourceOracle")
            # 30 chars
            salt="SuperYieldSourceOracle_v1.0.1"
            ;;
        "FirelightYieldSourceOracle")
            # 32 chars — matches Solidity FIRELIGHT_YIELD_SOURCE_ORACLE_SALT
            salt="FirelightYieldSourceOracle_v1.0"
            ;;
        *)
            # Default: use oracle name + version
            salt="${oracle_name}_v1.0.1"
            ;;
    esac

    # Validate salt length before returning - fail if > 32 bytes (matches Solidity check)
    validate_salt_length "$salt" "$oracle_name"
    echo "$salt"
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

# Get Fireblocks sender address for a given chain ID
# Matches config_v2_ledger_staging_prod.sh per-chain sender logic
get_fireblocks_sender() {
    local chain_id=$1
    case $chain_id in
        14) # Flare — different Fireblocks vault derivation
            echo "0x40a4012A1a154ed58E9BB2f4C63D07f64816b719"
            ;;
        *)
            echo "0x28b7599f461D104f07D78215Fa6F9B959851f93d"
            ;;
    esac
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
