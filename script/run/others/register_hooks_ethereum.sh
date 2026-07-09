#!/usr/bin/env bash
###################################################################################
# Register new hooks in SuperGovernor on Ethereum (chain 1)
# Hooks to register are the new deployments from feat/hook-sizing-manifest branch.
#
# Usage: ./script/run/register_hooks_ethereum.sh [simulate|execute] [account]
#   mode:    simulate (default) — dry-run only
#            execute            — send real transactions
#   account: foundry account name (default: v2-supervaults)
###################################################################################

set -euo pipefail

PASS_FILE=""
cleanup() { rm -f "${PASS_FILE:-}"; }
trap cleanup EXIT

SUPER_GOVERNOR="0xB5396ef2bF8CA360cEB4166b77AFb2bed20e74d4"
CHAIN_ID=1

MODE="${1:-simulate}"
ACCOUNT="${2:-v2-supervaults}"

# New hooks deployed on Ethereum in PR #943
declare -A HOOKS
HOOKS["FetchNativeFeeHook"]="0xF294E9215B23824bd6D0CBa219f00Cc63427787c"
HOOKS["ForceDeallocateMorphoHook"]="0xc75D87Cb2A69B0bb5ebA40Fc60cFE6DC7eD02379"
HOOKS["MetaMorphoReallocateHook"]="0x71D621914fc19a81C9196A4538dB0fb43846691c"
HOOKS["MorphoBorrowHook"]="0x4CB2712b7f27D05660397aF7E262e0a7fF6c8E78"
HOOKS["MorphoLendHook"]="0xf312c7010924769AcE2a2948196656e43634DA7b"
HOOKS["MorphoRepayAndWithdrawHook"]="0xE8a70d597CCe82875A78Eb53cDf1A761061a84E9"
HOOKS["MorphoRepayHook"]="0x5e5F648A3d47B4D032Bc5AE8d78b3c39d549d619"
HOOKS["MorphoSupplyAndBorrowHook"]="0x3159751c40C58c0408421e82e36299b4Bc461472"
HOOKS["MorphoSupplyHook"]="0x37fd99fDca734EcD9bEa8a8B4709346991f3412f"
HOOKS["MorphoWithdrawHook"]="0xC6988018b78E2E54A1E0f97Bb513Ad92e30FDaD5"

HOOK_NAMES=(
    "FetchNativeFeeHook"
    "ForceDeallocateMorphoHook"
    "MetaMorphoReallocateHook"
    "MorphoBorrowHook"
    "MorphoLendHook"
    "MorphoRepayAndWithdrawHook"
    "MorphoRepayHook"
    "MorphoSupplyAndBorrowHook"
    "MorphoSupplyHook"
    "MorphoWithdrawHook"
)

# ── Validate mode ──────────────────────────────────────────────────────────────
if [[ "$MODE" != "simulate" && "$MODE" != "execute" ]]; then
    echo "Usage: $0 [simulate|execute] [account]"
    exit 1
fi

# ── Load RPC ───────────────────────────────────────────────────────────────────
if [ -z "${ETH_MAINNET:-}" ]; then
    echo "Loading Ethereum RPC from 1Password..."
    export ETH_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/ETHEREUM_RPC_URL/credential 2>/dev/null | tr -d '\n')
fi

if [ -z "${ETH_MAINNET:-}" ]; then
    echo "❌ ETH_MAINNET not set. Export it or ensure 1Password CLI is available."
    exit 1
fi

RPC_URL="$ETH_MAINNET"

echo "============================================================"
echo "  Register Hooks in SuperGovernor — Ethereum (chain $CHAIN_ID)"
echo "  SuperGovernor: $SUPER_GOVERNOR"
echo "  Account:       $ACCOUNT"
echo "  Mode:          $MODE"
echo "  Hooks:         ${#HOOK_NAMES[@]}"
echo "============================================================"
echo ""

# ── Fetch already-registered hooks ────────────────────────────────────────────
echo "Fetching already-registered hooks from SuperGovernor..."
REGISTERED_RAW=$(cast call "$SUPER_GOVERNOR" "getRegisteredHooks()(address[])" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
echo ""

# ── Prompt for keystore password once (execute mode only) ─────────────────────
if [[ "$MODE" == "execute" ]]; then
    echo "⚠️  EXECUTE MODE: This will send real transactions on Ethereum."
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
    echo ""
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo "============================================================"
echo "  Summary (Ethereum — $MODE)"
echo "  Registered: $success"
echo "  Skipped:    $skipped  (already registered)"
echo "  Failed:     $failed"
echo "============================================================"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
