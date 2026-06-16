#!/usr/bin/env bash
###################################################################################
# Deploy hooks individually via cast send to the Deterministic Deployer
# Usage: ./script/run/deploy_hooks_cast.sh <chain> <account>
#   chain: eth, bnb, base, arb
#   account: foundry account name (e.g., v2-deployer)
###################################################################################

set -euo pipefail

DEPLOYER="0x4e59b44847b379578588920cA78FbF26c0B4956C"

# Morpho addresses per chain
MORPHO_ETH="0x000000000000000000000000BBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
MORPHO_BNB="0x00000000000000000000000001b0Bd309AA75547f7a37Ad7B1219A898E67a83a"
MORPHO_BASE="0x000000000000000000000000BBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
MORPHO_ARB="0x0000000000000000000000006c247b1F6182318877311737BaC0844bAa518F5e"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <chain: eth|bnb|base|arb> <account>"
    exit 1
fi

CHAIN=$1
ACCOUNT=$2

case "$CHAIN" in
    eth)
        RPC_VAR="ETH_MAINNET"
        MORPHO_ADDR="$MORPHO_ETH"
        CHAIN_ID=1
        ;;
    bnb)
        RPC_VAR="BSC_MAINNET"
        MORPHO_ADDR="$MORPHO_BNB"
        CHAIN_ID=56
        ;;
    base)
        RPC_VAR="BASE_MAINNET"
        MORPHO_ADDR="$MORPHO_BASE"
        CHAIN_ID=8453
        ;;
    arb)
        RPC_VAR="ARBITRUM_MAINNET"
        MORPHO_ADDR="$MORPHO_ARB"
        CHAIN_ID=42161
        ;;
    *)
        echo "Unknown chain: $CHAIN"
        exit 1
        ;;
esac

RPC_URL="${!RPC_VAR:-}"
if [ -z "$RPC_URL" ]; then
    echo "RPC URL not set for $RPC_VAR. Source your .env or load from 1Password first."
    exit 1
fi

BYTECODE_DIR="script/locked-bytecode-other"

compute_salt() {
    local name=$1
    # keccak256(abi.encodePacked("SuperformV2", "", name, "v2.0"))
    cast keccak "$(cast --from-utf8 "SuperformV2${name}v2.0")"
}

get_bytecode() {
    local name=$1
    python3 -c "import json; d=json.load(open('${BYTECODE_DIR}/${name}.json')); bc=d['bytecode']['object']; print(bc if bc.startswith('0x') else '0x'+bc)"
}

deploy_hook() {
    local name=$1
    local constructor_args=${2:-""}  # empty = no constructor args

    echo "──────────────────────────────────────────"
    echo "Deploying: $name"

    local salt
    salt=$(compute_salt "$name")
    echo "  Salt: $salt"

    local bytecode
    bytecode=$(get_bytecode "$name")

    # Build calldata: salt (32 bytes) + bytecode + constructor_args
    local calldata
    if [ -n "$constructor_args" ]; then
        # Strip 0x prefixes for concatenation, then re-add
        local salt_hex="${salt#0x}"
        local bc_hex="${bytecode#0x}"
        local args_hex="${constructor_args#0x}"
        calldata="0x${salt_hex}${bc_hex}${args_hex}"
    else
        local salt_hex="${salt#0x}"
        local bc_hex="${bytecode#0x}"
        calldata="0x${salt_hex}${bc_hex}"
    fi

    # Check if already deployed by computing CREATE2 address
    # CREATE2: keccak256(0xff ++ deployer ++ salt ++ keccak256(initcode))[12:]
    local init_code
    if [ -n "$constructor_args" ]; then
        init_code="0x${bc_hex}${args_hex}"
    else
        init_code="0x${bc_hex}"
    fi
    local init_code_hash
    init_code_hash=$(cast keccak "$init_code" 2>/dev/null || echo "")

    if [ -n "$init_code_hash" ]; then
        # Manually compute CREATE2: keccak256(0xff ++ deployer ++ salt ++ initCodeHash)[12:]
        local deployer_hex="${DEPLOYER#0x}"
        local salt_hex_raw="${salt#0x}"
        local hash_hex="${init_code_hash#0x}"
        local predicted
        predicted=$(cast keccak "0xff${deployer_hex}${salt_hex_raw}${hash_hex}" 2>/dev/null || echo "")
        if [ -n "$predicted" ]; then
            # Take last 20 bytes (40 hex chars)
            predicted="0x${predicted: -40}"
            predicted=$(cast to-check-sum-address "$predicted" 2>/dev/null || echo "$predicted")

            local code_size
            code_size=$(cast codesize "$predicted" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
            if [ "$code_size" != "0" ]; then
                echo "  Already deployed at: $predicted (code size: $code_size)"
                echo "  SKIPPING"
                return 0
            fi
            echo "  Predicted address: $predicted"
        fi
    fi

    echo "  Sending transaction..."
    if cast send --account "$ACCOUNT" --password-file "$PASS_FILE" --rpc-url "$RPC_URL" --chain "$CHAIN_ID" "$DEPLOYER" "$calldata"; then
        echo "  SUCCESS"
    else
        echo "  FAILED"
        return 1
    fi
}

echo "============================================================"
echo "  Hook Deployment via Cast"
echo "  Chain: $CHAIN (ID: $CHAIN_ID)"
echo "  Account: $ACCOUNT"
echo "  RPC: $RPC_VAR"
echo "============================================================"
echo ""

# Ask for confirmation
read -rp "Deploy hooks to $CHAIN? (y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

# Ask for keystore password once
echo -ne "Enter keystore password for account '$ACCOUNT': "
read -rs KEYSTORE_PASSWORD
echo ""
PASS_FILE=$(mktemp)
chmod 600 "$PASS_FILE"
echo "$KEYSTORE_PASSWORD" > "$PASS_FILE"
unset KEYSTORE_PASSWORD
trap 'rm -f "$PASS_FILE"' EXIT

MORPHO_ARG_HEX="${MORPHO_ADDR#0x}"

echo ""
echo "=== MORPHO HOOKS (constructor: address morpho) ==="
echo ""

for hook in MorphoSupplyAndBorrowHook MorphoBorrowHook MorphoRepayHook MorphoRepayAndWithdrawHook MorphoSupplyHook MorphoWithdrawHook MorphoLendHook; do
    deploy_hook "$hook" "$MORPHO_ADDR" || true
    echo ""
done

echo ""
echo "=== MORPHO HOOKS (no constructor args) ==="
echo ""

for hook in MetaMorphoReallocateHook ForceDeallocateMorphoHook; do
    deploy_hook "$hook" || true
    echo ""
done

echo ""
echo "=== AAVE V4 HOOKS (no constructor args, Ethereum only) ==="
echo ""

if [ "$CHAIN" = "eth" ]; then
    for hook in AaveV4SupplyHook AaveV4WithdrawHook AaveV4BorrowHook AaveV4RepayHook AaveV4SupplyAndBorrowHook AaveV4RepayAndWithdrawHook; do
        deploy_hook "$hook" || true
        echo ""
    done
else
    echo "  Skipping AaveV4 hooks (Ethereum only)"
fi

# Odos V3 Router (same on all chains where deployed)
ODOS_V3_ROUTER="0x0000000000000000000000000D05a7D3448512B78fa8A9e46c4872C88C4a0D05"

echo ""
echo "=== ODOS V3 HOOKS (constructor: address routerV3) ==="
echo ""

for hook in SwapOdosV3Hook ApproveAndSwapOdosV3Hook; do
    deploy_hook "$hook" "$ODOS_V3_ROUTER" || true
    echo ""
done

echo ""
echo "============================================================"
echo "  Deployment Complete"
echo "============================================================"
