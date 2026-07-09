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

# New hooks deployed on Flare in this branch (vs dev)
declare -A HOOKS
HOOKS["ApproveAndDeposit4626VaultHook"]="0xba687c9D5113a3B2692fd87b0F389dD5fF402808"
HOOKS["ApproveAndRequestDeposit7540VaultHook"]="0x3D40479c9c9B9f12FC3E08625E13A72AFe27c435"
HOOKS["ApproveAndSwapOpenOceanHook"]="0x88832253c5BFBD07d37A02E6EDFaa28F6e280227"
HOOKS["CancelDepositRequestWithId7540Hook"]="0x05B79c1CCC26019a8d93579818cb6aA586b81AE9"
HOOKS["CancelRedeemRequestWithId7540Hook"]="0x4929d62Dd0c1f418Ff31f4f949571A2820290500"
HOOKS["ClaimCancelDepositRequestWithId7540Hook"]="0x3f96d92Af8b6a8632419DC9a9D7A794FBb3EF38d"
HOOKS["ClaimCancelRedeemRequestWithId7540Hook"]="0x436B54df18a0545D0F09aDcb79d795CD65A5de4f"
HOOKS["ClaimRFLRV3Hook"]="0x04F83BF33a71b44f916B5529828f7C22890F9d00"
HOOKS["Deposit4626VaultHook"]="0x71761d36cF081A3762E5347b4e3635CeCAd5156b"
HOOKS["Deposit7540VaultHook"]="0x70b604978aB85aF6f58Df2F4e7313dFd40525646"
HOOKS["Redeem4626VaultHook"]="0x95C61fE513885E23Bd7DA1f27B1ad9B16AE29f81"
HOOKS["RedeemWithId7540VaultHook"]="0x51580e817988B4b56d839827c78A8F39D38036aA"
HOOKS["RequestDeposit7540VaultHook"]="0x6B0Fa663F1276b04E12C463B3002c58cFbD59CB3"
HOOKS["RequestRedeem7540VaultHook"]="0x343Cd015339Be39d62d220313654600BbC24cd08"
HOOKS["SetOperator7540Hook"]="0x3731e9Ca56837a5Fb38753Ad1204Bc578566De4a"
HOOKS["StargateAdapterV2"]="0x70DA113dF37e4ED9A414af8Cb51b6C559fac775b"
HOOKS["SwapOpenOceanHook"]="0xd4Ca1E1afCD79a932D1933dD161f5211790B42d7"
HOOKS["WithdrawWithId7540VaultHook"]="0xE03A772E17a8383103Ecd743D1167ACA48f50Bd2"

# Preserve insertion order for display
HOOK_NAMES=(
    "ApproveAndDeposit4626VaultHook"
    "ApproveAndRequestDeposit7540VaultHook"
    "ApproveAndSwapOpenOceanHook"
    "CancelDepositRequestWithId7540Hook"
    "CancelRedeemRequestWithId7540Hook"
    "ClaimCancelDepositRequestWithId7540Hook"
    "ClaimCancelRedeemRequestWithId7540Hook"
    "ClaimRFLRV3Hook"
    "Deposit4626VaultHook"
    "Deposit7540VaultHook"
    "Redeem4626VaultHook"
    "RedeemWithId7540VaultHook"
    "RequestDeposit7540VaultHook"
    "RequestRedeem7540VaultHook"
    "SetOperator7540Hook"
    "StargateAdapterV2"
    "SwapOpenOceanHook"
    "WithdrawWithId7540VaultHook"
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
