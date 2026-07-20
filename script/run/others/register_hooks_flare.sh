#!/usr/bin/env bash
###################################################################################
# Register new hooks in SuperGovernor on Flare (chain 14)
# Hooks to register are the new deployments from feat/hook-sizing-manifest branch.
#
# Usage: ./script/run/register_hooks_flare.sh [simulate|execute] [account]
#   mode:    simulate (default) — dry-run only
#            execute            — send real transactions
#   account: foundry account name (default: v2-supervaults)
###################################################################################

set -euo pipefail

PASS_FILE=""
cleanup() { rm -f "${PASS_FILE:-}"; }
trap cleanup EXIT

SUPER_GOVERNOR="0xB5396ef2bF8CA360cEB4166b77AFb2bed20e74d4"
CHAIN_ID=14

MODE="${1:-simulate}"
ACCOUNT="${2:-v2-supervaults}"

# New hooks deployed on Flare in PR #943
declare -A HOOKS
HOOKS["ApproveAndSwapAlgebraIntegralHook"]="0x87E8958d0a2Bd030060fa63852770d5bdA303153"
HOOKS["ClaimRFLRV3Hook"]="0x2FAa029F0959D53A4E3B73c41fE2AC524432816d"
HOOKS["FetchNativeFeeHook"]="0xF294E9215B23824bd6D0CBa219f00Cc63427787c"
HOOKS["SwapAlgebraIntegralHook"]="0xF7291FD5Ef4c59bc81314BCf2A1546008edF8F41"
HOOKS["WithdrawRFLRHookV2"]="0x4667a6F5E0285dc1aCA46C6A4f4Bb5DACe7bb880"

# Preserve insertion order for display
HOOK_NAMES=(
    "ApproveAndSwapAlgebraIntegralHook"
    "ClaimRFLRV3Hook"
    "FetchNativeFeeHook"
    "SwapAlgebraIntegralHook"
    "WithdrawRFLRHookV2"
)

# ── Validate mode ──────────────────────────────────────────────────────────────
if [[ "$MODE" != "simulate" && "$MODE" != "execute" ]]; then
    echo "Usage: $0 [simulate|execute] [account]"
    exit 1
fi

# ── Load RPC ───────────────────────────────────────────────────────────────────
if [ -z "${FLARE_MAINNET:-}" ]; then
    echo "Loading Flare RPC from 1Password..."
    export FLARE_MAINNET=$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/FLARE_RPC_URL/credential 2>/dev/null | tr -d '\n')
fi

if [ -z "${FLARE_MAINNET:-}" ]; then
    echo "❌ FLARE_MAINNET not set. Export it or ensure 1Password CLI is available."
    exit 1
fi

RPC_URL="$FLARE_MAINNET"

echo "============================================================"
echo "  Register Hooks in SuperGovernor — Flare (chain $CHAIN_ID)"
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

is_registered() {
    local addr="${1,,}"  # lowercase
    echo "$REGISTERED_RAW" | tr ',' '\n' | tr -d '[] ' | while read -r entry; do
        if [ "${entry,,}" = "$addr" ]; then
            echo "yes"
            return
        fi
    done
}

# ── Prompt for keystore password once (execute mode only) ─────────────────────
if [[ "$MODE" == "execute" ]]; then
    echo "⚠️  EXECUTE MODE: This will send real transactions on Flare."
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

    # Check if already registered
    if echo "$REGISTERED_RAW" | grep -qi "$addr"; then
        echo "⏭  SKIP  $name ($addr) — already registered"
        ((skipped++)) || true
        continue
    fi

    if [[ "$MODE" == "simulate" ]]; then
        echo "🔍 SIMULATE  registerHook($addr)  [$name]"
        # Dry-run via cast call (no state change)
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
echo "  Summary (Flare — $MODE)"
echo "  Registered: $success"
echo "  Skipped:    $skipped  (already registered)"
echo "  Failed:     $failed"
echo "============================================================"

if [[ $failed -gt 0 ]]; then
    exit 1
fi
