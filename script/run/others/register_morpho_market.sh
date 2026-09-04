#!/usr/bin/env bash

###################################################################################
# Morpho Blue Market Registration Script
###################################################################################
# Description:
#   Registers a Morpho Blue market in the MorphoBlueMarketRegistry:
#     1. Pre-flight checks (registry code, role, market existence, idempotency)
#     2. setIrmApproval (skipped if already approved)
#     3. registerMarket
#     4. Post-registration verification (isRegistered + oracle PPS resolution)
#   Every state-changing call is simulated (cast call --from) before sending.
#
# Usage:
#   ./script/run/others/register_morpho_market.sh [account]
#
# Arguments:
#   account: foundry keystore account name (default: v2-deployer)
#
# Defaults are set for the cbBTC/USDC market on Base PROD.
# Edit the CONFIG block below for other markets/chains/environments.
###################################################################################

set -euo pipefail

# ── CONFIG ─────────────────────────────────────────────────────────────────────
# Base PROD deployment (script/output/prod/8453/Base-latest.json)
REGISTRY="0x058F8B818D1AB68d4ed915E9a7f414A7960d8292"
SUPPLY_ORACLE="0x1267b7C237Be2c5CCdF79B72e200F358b84D1601"
DEBT_ORACLE="0x24412F6Cd813925A94190459Df2AB8549dCE3141"

# Morpho Blue cbBTC/USDC market on Base (id 0x9103c3...191836)
MORPHO="0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb"
LOAN_TOKEN="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"   # USDC
COLLATERAL_TOKEN="0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf" # cbBTC
ORACLE="0x663BECd10daE6C4A3Dcd89F1d76c1174199639B9"
IRM="0x46415998764C29aB2a25CbeA6254146D50D22687"          # Adaptive Curve IRM
LLTV="860000000000000000"                                  # 86%

EXPECTED_MANAGER="0x6E3dadcAf328ebB58753e89a3e589F5C5e988dF8" # DEPLOYER
RPC_VAR="BASE_RPC_URL"
# ───────────────────────────────────────────────────────────────────────────────

ACCOUNT="${1:-v2-deployer}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

fail() { echo -e "${RED}ERROR: $1${NC}"; exit 1; }
info() { echo -e "${CYAN}$1${NC}"; }
ok()   { echo -e "${GREEN}$1${NC}"; }

# ── Environment ────────────────────────────────────────────────────────────────
[ -f .env ] && source .env
RPC="${!RPC_VAR:-}"
[ -n "$RPC" ] || fail "$RPC_VAR is not set (source .env or export it)"
command -v cast >/dev/null || fail "cast (foundry) not found"

echo "=================================================================="
echo " Morpho Blue Market Registration"
echo "=================================================================="
info "Registry:   $REGISTRY"
info "Market:     loan=$LOAN_TOKEN"
info "            collateral=$COLLATERAL_TOKEN"
info "            oracle=$ORACLE"
info "            irm=$IRM lltv=$LLTV"
info "Account:    $ACCOUNT (expected manager: $EXPECTED_MANAGER)"
echo ""

# ── Pre-flight checks ──────────────────────────────────────────────────────────
info "Pre-flight checks..."

CODE_LEN=$(cast code "$REGISTRY" --rpc-url "$RPC" | wc -c | tr -d ' ')
[ "$CODE_LEN" -gt 10 ] || fail "no code at registry address $REGISTRY"

ROLE=$(cast keccak "MARKET_MANAGER_ROLE")
info "  resolving account '$ACCOUNT' address (keystore password prompt)..."
SENDER=$(cast wallet address --account "$ACCOUNT") || fail "could not unlock account '$ACCOUNT'"
info "  sender: $SENDER"
HAS_ROLE=$(cast call "$REGISTRY" "hasRole(bytes32,address)(bool)" "$ROLE" "$SENDER" --rpc-url "$RPC")
if [ "$HAS_ROLE" != "true" ]; then
    echo -e "${RED}Account '$ACCOUNT' ($SENDER) does NOT hold MARKET_MANAGER_ROLE on this registry.${NC}"
    echo -e "${YELLOW}Roles were granted at deployment to: $EXPECTED_MANAGER${NC}"
    echo -e "${YELLOW}Either run this script with the account controlling that address, or have it grant the role:${NC}"
    echo -e "${YELLOW}  cast send $REGISTRY \"grantRole(bytes32,address)\" $ROLE $SENDER \\\\\n      --account <admin-account> --rpc-url \$$RPC_VAR${NC}"
    exit 1
fi
ok "  registry code present, sender role confirmed"
EXPECTED_MANAGER="$SENDER"

# Market must exist on the Morpho singleton (register-time check would catch this,
# but failing early with a clear message is nicer)
MARKET_KEY=$(cast call "$REGISTRY" \
    "computeMarketKey(address,address,address,address,uint256)(address)" \
    "$LOAN_TOKEN" "$COLLATERAL_TOKEN" "$ORACLE" "$IRM" "$LLTV" --rpc-url "$RPC")
info "  derived market key: $MARKET_KEY"

IS_REGISTERED=$(cast call "$REGISTRY" "isRegistered(address)(bool)" "$MARKET_KEY" --rpc-url "$RPC")
if [ "$IS_REGISTERED" = "true" ]; then
    ok "Market already registered under $MARKET_KEY — nothing to do."
    exit 0
fi

IRM_APPROVED=$(cast call "$REGISTRY" "approvedIrms(address)(bool)" "$IRM" --rpc-url "$RPC")
info "  irm approved: $IRM_APPROVED | market registered: $IS_REGISTERED"
echo ""

# ── Step 1: setIrmApproval (if needed) ────────────────────────────────────────
if [ "$IRM_APPROVED" != "true" ]; then
    info "Simulating setIrmApproval..."
    cast call "$REGISTRY" "setIrmApproval(address,bool)" "$IRM" true \
        --from "$EXPECTED_MANAGER" --rpc-url "$RPC" > /dev/null \
        || fail "setIrmApproval simulation reverted"
    ok "  simulation OK"

    echo -e "${YELLOW}About to SEND setIrmApproval($IRM, true) from account '$ACCOUNT'.${NC}"
    read -r -p "Proceed? (yes/no) " CONFIRM
    [ "$CONFIRM" = "yes" ] || fail "aborted by user"

    cast send "$REGISTRY" "setIrmApproval(address,bool)" "$IRM" true \
        --account "$ACCOUNT" --rpc-url "$RPC"
    ok "  setIrmApproval sent"

    IRM_APPROVED=$(cast call "$REGISTRY" "approvedIrms(address)(bool)" "$IRM" --rpc-url "$RPC")
    [ "$IRM_APPROVED" = "true" ] || fail "IRM approval did not take effect"
else
    ok "IRM already approved — skipping step 1"
fi
echo ""

# ── Step 2: registerMarket ─────────────────────────────────────────────────────
info "Simulating registerMarket..."
cast call "$REGISTRY" \
    "registerMarket(address,address,address,address,address,uint256)(address)" \
    "$MORPHO" "$LOAN_TOKEN" "$COLLATERAL_TOKEN" "$ORACLE" "$IRM" "$LLTV" \
    --from "$EXPECTED_MANAGER" --rpc-url "$RPC" > /dev/null \
    || fail "registerMarket simulation reverted (market missing on Morpho, or params wrong)"
ok "  simulation OK"

echo -e "${YELLOW}About to SEND registerMarket for the market above from account '$ACCOUNT'.${NC}"
echo -e "${YELLOW}Registration is add-only; removal requires the 2-day timelocked deregistration.${NC}"
read -r -p "Proceed? (yes/no) " CONFIRM
[ "$CONFIRM" = "yes" ] || fail "aborted by user"

cast send "$REGISTRY" \
    "registerMarket(address,address,address,address,address,uint256)" \
    "$MORPHO" "$LOAN_TOKEN" "$COLLATERAL_TOKEN" "$ORACLE" "$IRM" "$LLTV" \
    --account "$ACCOUNT" --rpc-url "$RPC"
ok "  registerMarket sent"
echo ""

# ── Step 3: Verification ───────────────────────────────────────────────────────
info "Verifying..."
IS_REGISTERED=$(cast call "$REGISTRY" "isRegistered(address)(bool)" "$MARKET_KEY" --rpc-url "$RPC")
[ "$IS_REGISTERED" = "true" ] || fail "market not registered after send"
ok "  isRegistered($MARKET_KEY) = true"

if [ -n "$SUPPLY_ORACLE" ]; then
    PPS=$(cast call "$SUPPLY_ORACLE" "getPricePerShare(address)(uint256)" "$MARKET_KEY" --rpc-url "$RPC" || echo "REVERTED")
    info "  supply oracle PPS: $PPS"
fi
if [ -n "$DEBT_ORACLE" ]; then
    TVL=$(cast call "$DEBT_ORACLE" "getTVL(address)(uint256)" "$MARKET_KEY" --rpc-url "$RPC" || echo "REVERTED")
    info "  debt oracle TVL:   $TVL"
fi

echo ""
ok "=================================================================="
ok " DONE — market key $MARKET_KEY is live."
ok " Use it as the yieldSourceAddress in SuperLedger config / monitoring."
ok "=================================================================="
