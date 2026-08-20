#!/usr/bin/env bash
###################################################################################
# Register the HyperCore hook family in SuperGovernor on HyperEVM (chain 999)
#
# Distinct from register_hooks_hyperevm.sh, which is a one-off for PR #943's
# FetchNativeFeeHook and hardcodes its address.
#
# Unlike the per-chain scripts that hardcode addresses, this one reads them out of
# the deployment output, so it can be run immediately after DeployV2OtherHooks
# without transcribing five addresses by hand.
#
# Usage: ./script/run/others/register_hypercore_hooks.sh [simulate|execute] [account]
#   mode:    simulate (default) — dry-run only
#            execute            — send real transactions
#   account: foundry account name (default: v2-supervaults)
###################################################################################

set -euo pipefail

PASS_FILE=""
cleanup() { rm -f "${PASS_FILE:-}"; }
trap cleanup EXIT

SUPER_GOVERNOR="0xB5396ef2bF8CA360cEB4166b77AFb2bed20e74d4"
CHAIN_ID=999
NETWORK_KEY="HyperEVM"
DEPLOYMENT_JSON="script/output/prod/latest.json"

MODE="${1:-simulate}"
ACCOUNT="${2:-v2-supervaults}"

HOOK_NAMES=(
    "HyperCoreAddApiWalletHook"
    "HyperCoreUsdClassTransferHook"
    "HyperCoreSendAssetHook"
    "HyperCoreApproveBuilderFeeHook"
    "ApproveAndHyperCoreDepositUsdcPerpHook"
)

# ── Validate mode ──────────────────────────────────────────────────────────────
if [[ "$MODE" != "simulate" && "$MODE" != "execute" ]]; then
    echo "Usage: $0 [simulate|execute] [account]"
    exit 1
fi

# ── Resolve hook addresses from the deployment output ──────────────────────────
if [ ! -f "$DEPLOYMENT_JSON" ]; then
    echo "❌ $DEPLOYMENT_JSON not found. Deploy first."
    exit 1
fi

declare -A HOOKS
missing=0
for name in "${HOOK_NAMES[@]}"; do
    addr=$(python3 -c "
import json,sys
d=json.load(open('$DEPLOYMENT_JSON'))
print(d.get('networks',{}).get('$NETWORK_KEY',{}).get('contracts',{}).get('$name',''))
" 2>/dev/null || echo "")
    if [ -z "$addr" ]; then
        echo "❌ $name not found in $DEPLOYMENT_JSON under networks.$NETWORK_KEY"
        missing=1
    else
        HOOKS[$name]="$addr"
    fi
done
if [ "$missing" -ne 0 ]; then
    echo ""
    echo "Deploy the HyperCore hooks on chain $CHAIN_ID before registering them."
    exit 1
fi

# ── Load RPC ───────────────────────────────────────────────────────────────────
if [ -z "${HYPEREVM_MAINNET:-}" ]; then
    echo "Loading HyperEVM RPC from 1Password..."
    export HYPEREVM_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/HYPEREVM_RPC_URL/credential 2>/dev/null | tr -d '\n')
fi

if [ -z "${HYPEREVM_MAINNET:-}" ]; then
    echo "❌ HYPEREVM_MAINNET not set. Export it or ensure 1Password CLI is available."
    exit 1
fi

RPC_URL="$HYPEREVM_MAINNET"

echo "============================================================"
echo "  Register HyperCore Hooks in SuperGovernor — chain $CHAIN_ID"
echo "  SuperGovernor: $SUPER_GOVERNOR"
echo "  Account:       $ACCOUNT"
echo "  Mode:          $MODE"
echo "  Hooks:         ${#HOOK_NAMES[@]}"
echo "============================================================"
echo ""

# ── Sanity: the chain we are pointed at must actually be 999 ──────────────────
ACTUAL_CHAIN=$(cast chain-id --rpc-url "$RPC_URL" 2>/dev/null || echo "")
if [ "$ACTUAL_CHAIN" != "$CHAIN_ID" ]; then
    echo "❌ RPC reports chain $ACTUAL_CHAIN, expected $CHAIN_ID. Refusing to continue."
    exit 1
fi

# ── Fetch already-registered hooks ────────────────────────────────────────────
echo "Fetching already-registered hooks from SuperGovernor..."
REGISTERED_RAW=$(cast call "$SUPER_GOVERNOR" "getRegisteredHooks()(address[])" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
echo ""

# ── Prompt for keystore password once (execute mode only) ─────────────────────
if [[ "$MODE" == "execute" ]]; then
    echo "⚠️  EXECUTE MODE: This will send real transactions on HyperEVM."
    read -rp "Proceed? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""

    read -rsp "Keystore password for '$ACCOUNT': " KEYSTORE_PASSWORD
    echo ""
    if ! cast wallet address --account "$ACCOUNT" --password "$KEYSTORE_PASSWORD" &>/dev/null; then
        echo "❌ Invalid password for account '$ACCOUNT'"
        exit 1
    fi
    PASS_FILE=$(mktemp)
    chmod 600 "$PASS_FILE"
    printf '%s' "$KEYSTORE_PASSWORD" > "$PASS_FILE"
    unset KEYSTORE_PASSWORD
    echo "✅ Password verified"
    echo ""
fi

# ── Register hooks ─────────────────────────────────────────────────────────────
success=0
skipped=0
failed=0

for name in "${HOOK_NAMES[@]}"; do
    addr="${HOOKS[$name]}"

    if echo "$REGISTERED_RAW" | grep -qi "$addr"; then
        echo "⏭  SKIP  $name ($addr) — already registered"
        ((skipped++)) || true
        continue
    fi

    if [[ "$MODE" == "simulate" ]]; then
        echo "🔍 SIMULATE  registerHook($addr)  [$name]"
        if cast call "$SUPER_GOVERNOR" "registerHook(address)" "$addr" \
            --rpc-url "$RPC_URL" \
            --from "$(cast wallet address --account "$ACCOUNT" 2>/dev/null || echo '0x0000000000000000000000000000000000000000')" \
            2>/dev/null; then
            echo "   ✅ Simulation OK"
        else
            echo "   ⚠️  Simulation call reverted (may be auth-gated — expected in dry-run)"
        fi
        ((success++)) || true
    else
        echo "📤 SEND  registerHook($addr)  [$name]"
        if cast send \
            --account "$ACCOUNT" \
            --password-file "$PASS_FILE" \
            --rpc-url "$RPC_URL" \
            "$SUPER_GOVERNOR" \
            "registerHook(address)" "$addr"; then
            echo "   ✅ OK"
            ((success++)) || true
        else
            echo "   ❌ FAILED"
            ((failed++)) || true
        fi
    fi
done

echo ""
echo "============================================================"
echo "  Summary (HyperEVM — $MODE)"
echo "  Registered/simulated: $success"
echo "  Skipped (existing):   $skipped"
echo "  Failed:               $failed"
echo "============================================================"

[ "$failed" -eq 0 ]
