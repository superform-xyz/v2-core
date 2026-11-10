#!/usr/bin/env bash
#
# migrate_sponsorship_paymaster_budgets.sh
#
# Moves every SuperVault strategy's sponsorship budget from the SUPERSEDED
# SuperSponsorshipPaymaster to the CURRENT one, retaining 15% at the signer.
#
#   FROM  0x185f6f03abBe881A9f2018836202c8F6F0BCAFE2  (superseded)
#   TO    0xBdf571ce14e228B370Bf6B4e5fd4cD19013e7Ef9  (current prod SuperSponsorshipPaymaster)
#
# Both addresses are CREATE2-identical on every prod chain, as is the aggregator and EntryPoint
# v0.7, so the only per-chain differences are the chain id, which RPC to read, and the gas
# token's name. ONE script rather than one per chain on purpose: this moves money, and two
# copies means fixing every bug twice.
#
# FLARE IS WHY THE ARITHMETIC IS THE WAY IT IS. Two bugs were found and fixed on the Base run,
# where they were nearly harmless; on Flare both are severe, because FLR budgets run ~3300x
# larger in raw units:
#   - summing with awk accumulates in a double. On Base that lost 6 wei; on Flare it loses
#     26,924 wei (382828837063701561344 against a true 382828837063701588268).
#   - bash `(( ))` is 64-bit signed. Flare's largest single balance is 236933284428906167566,
#     about 25x over 2^63, so every `(( ))` comparison on it would be meaningless.
# Every wei value here is therefore handled as an arbitrary-precision integer via Python, and
# compared with wei_gt_zero / wei_pct. Do not "simplify" either back into shell arithmetic.
#
# Status: Base (8453) was migrated on 2026-11-06 — 14 strategies, 0.116189 ETH withdrawn,
# 0.098761 ETH forwarded, 0.017428 ETH retained. Re-running against Base is harmless: every
# balance is zero there now, so the script reports "nothing to migrate" and exits.
#
# Per strategy, in one sequential pass:
#   1. withdrawStrategyFunds(strategy, SIGNER, balance)   -> the full balance lands on SIGNER
#   2. fundStrategy(strategy) with 85% of that balance    -> forwarded to the new paymaster
# leaving 15% of each withdrawal on SIGNER, as requested. Change with RETAIN_PCT.
#
# Usage:
#   NETWORK=ethereum ./script/run/config/migrate_sponsorship_paymaster_budgets.sh              # DRY RUN
#   NETWORK=ethereum CONFIRM=yes ./script/run/config/migrate_sponsorship_paymaster_budgets.sh  # broadcast
#
# Env:
#   NETWORK        ethereum | base | flare | robinhood — REQUIRED, no default. Deliberate: a money script should
#                  never pick a chain for you, and the preflight cross-checks the RPC's own
#                  chain id against it before anything is read, let alone sent.
#                  CHAIN=... is accepted as an alias and scrubbed (Foundry reads CHAIN itself).
#   ACCOUNT        keystore account name          (default: v2-deployer)
#   CONFIRM        "yes" to broadcast             (default: unset = dry run)
#   RETAIN_PCT     percent retained at the signer (default: 15)
#   <CHAIN>_RPC_URL  read from .env when unset (ETHEREUM_RPC_URL / BASE_RPC_URL)
#
# ---------------------------------------------------------------------------
# WHO SIGNS. `withdrawStrategyFunds` is `onlyRole(FUNDING_ROLE)`. Verified on Base AND Ethereum
# 2026-11-06, the FUNDING_ROLE holder on BOTH paymasters is
#   0x22BC97cFac64D6d9BCaDF5dC36e4D01Db9e929c5
# which is the `v2-deployer` keystore and matches PAYMASTER_ADMIN in
# DeploySuperSponsorshipPaymaster.s.sol. So the default ACCOUNT=v2-deployer is correct.
#
# Do NOT confuse it with `v2-supervaults` = 0x6E3dadcAf328ebB58753e89a3e589F5C5e988dF8, the
# address `ConfigBase.DEPLOYER` calls "the deployer". That one holds NEITHER role here, and
# running this with ACCOUNT=v2-supervaults would revert on the first withdraw. The preflight
# below checks the role on the resolved signer and aborts before sending anything either way,
# so a wrong ACCOUNT costs nothing but a prompt.
#
# `fundStrategy` is permissionless, so step 2 works from any funded signer.
# ---------------------------------------------------------------------------
#
# Side effect worth knowing: `fundStrategy` on a strategy the NEW paymaster has never seen
# calls `_applyDefaultSenderIfNeverConfigured`, which sets `allowedSender[strategy]` to
# DEFAULT_ALLOWED_SENDER and emits AllowedSenderSet. That is the intended post-#1034
# behaviour, not a side effect of this script, but it means funding is not purely a balance
# change. A strategy whose sender was deliberately set to address(0) as a block is NOT touched.
#
# Safe to re-run: a strategy already at zero on the old paymaster is skipped, so an
# interrupted run resumes where it stopped.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$PROJECT_ROOT"

OLD_PAYMASTER=0x185f6f03abBe881A9f2018836202c8F6F0BCAFE2
NEW_PAYMASTER=0xBdf571ce14e228B370Bf6B4e5fd4cD19013e7Ef9
AGGREGATOR=0x10AC0b33e1C4501CF3ec1cB1AE51ebfdbd2d4698
ENTRYPOINT=0x0000000071727De22E5E9d8BAf0edAc6f37da032
FUNDING_ROLE=0x39b2bc593170a470d7d1acf171dc293a49be46c39f27a26e75cbfe9e17828cca
ACCOUNT="${ACCOUNT:-v2-deployer}"
RETAIN_PCT="${RETAIN_PCT:-15}"
CONFIRM="${CONFIRM:-}"

RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YEL=$'\033[1;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
info()  { echo "${BLU}ℹ️  $*${NC}"; }
ok()    { echo "${GRN}✅ $*${NC}"; }
warn()  { echo "${YEL}⚠️  $*${NC}"; }
die()   { echo "${RED}❌ $*${NC}" >&2; exit 1; }

# Wei comparisons go through Python, never bash `(( ))`. Bash arithmetic is 64-bit signed, so
# it silently mis-evaluates any amount at or above 2^63 wei (~9.22 ETH): `(( 9300000000000000000 > 0 ))`
# is FALSE. Today's budgets are ~0.02 ETH each, but a script that moves money must not carry a
# landmine that only arms itself once the balances grow.
wei_gt_zero() { python3 -c "import sys; sys.exit(0 if int('$1') > 0 else 1)"; }
wei_pct()     { python3 -c "print(int('$1') * (100 - int('$2')) // 100)"; }

# ===== chain =====
# NETWORK, not CHAIN. Foundry reads CHAIN from the environment as `--chain` and validates it
# against its own chain-name enum, so an exported CHAIN=ethereum makes every `cast call` fail
# with "invalid value 'ethereum' for '--chain <CHAIN>'" (it wants "mainnet"). CHAIN is still
# accepted here for convenience and then SCRUBBED from the environment below, so it can never
# reach cast — including a CHAIN that was already exported in the calling shell for some other
# reason. Do not reintroduce a bare CHAIN variable in this script.
NETWORK="${NETWORK:-${CHAIN:-}}"
unset CHAIN

# NATIVE is only a display label. Flare's gas token is FLR, not ETH, and budgets there run
# ~3300x larger in raw units, so printing "ETH" would misread by three orders of magnitude at a
# glance — on a screen whose numbers decide whether you type CONFIRM=yes.
case "$NETWORK" in
    ethereum|mainnet) EXPECTED_CHAIN_ID=1;    RPC_VAR=ETHEREUM_RPC_URL; CHAIN_LABEL=Ethereum; NATIVE=ETH ;;
    base)             EXPECTED_CHAIN_ID=8453; RPC_VAR=BASE_RPC_URL;     CHAIN_LABEL=Base;     NATIVE=ETH ;;
    flare)            EXPECTED_CHAIN_ID=14;   RPC_VAR=FLARE_RPC_URL;    CHAIN_LABEL=Flare;    NATIVE=FLR ;;
    # Robinhood Chain (Arbitrum Orbit L2). RH_RPC_URL is NOT in .env like the other three — the
    # networks scripts pull it from 1Password (op://5ylebqljbh3x6zomdxi3qd7tsa/RH_RPC_URL), so
    # export it yourself before running:  export RH_RPC_URL="$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/RH_RPC_URL/credential)"
    robinhood|rh)     EXPECTED_CHAIN_ID=4663; RPC_VAR=RH_RPC_URL;       CHAIN_LABEL=Robinhood; NATIVE=ETH ;;
    "")               die "NETWORK is required. One of: ethereum, base, flare, robinhood." ;;
    *)                die "unknown network '$NETWORK'. Supported: ethereum, base, flare, robinhood." ;;
esac

# ===== RPC =====
RPC_URL="${!RPC_VAR:-}"
if [[ -z "$RPC_URL" ]]; then
    [[ -f .env ]] || die ".env not found and $RPC_VAR is unset"
    # `|| true` is load-bearing: with `set -o pipefail` a grep that matches nothing fails the
    # whole substitution, and `set -e` then kills the script BEFORE the die below can say why —
    # an exit code 1 with no message. RH is the first chain whose RPC is not in .env, so this
    # path had never been taken.
    RPC_URL="$(grep -E "^${RPC_VAR}=" .env | head -1 | cut -d= -f2- | tr -d '"' || true)"
fi
if [[ -z "$RPC_URL" ]]; then
    die "$RPC_VAR is not set and is not in .env.
       Robinhood's RPC lives in 1Password rather than .env, unlike the other chains:
         export RH_RPC_URL=\"\$(op read op://5ylebqljbh3x6zomdxi3qd7tsa/RH_RPC_URL/credential)\"
       then re-run."
fi
R=(--rpc-url "$RPC_URL")

command -v cast >/dev/null || die "cast not found on PATH"

# The RPC is asked what chain it is actually on, rather than trusting the variable name. A
# mislabelled endpoint would otherwise send mainnet-sized transactions wherever it points.
CHAIN_ID="$(cast chain-id "${R[@]}" 2>/dev/null)" \
    || die "could not reach the $CHAIN_LABEL RPC in $RPC_VAR"
[[ "$CHAIN_ID" == "$EXPECTED_CHAIN_ID" ]] \
    || die "$RPC_VAR points at chain $CHAIN_ID, not $CHAIN_LABEL ($EXPECTED_CHAIN_ID)"
ok "$CHAIN_LABEL RPC reachable (chain $CHAIN_ID, block $(cast block-number "${R[@]}"))"

# ===== keystore =====
# NOTE: ETH_PASSWORD is a password FILE PATH to cast, not the password itself. Pass the
# secret with --password so an exported ETH_PASSWORD cannot be misread as a filename.
read -r -s -p "Keystore password for '$ACCOUNT': " PW; echo
[[ -n "$PW" ]] || die "empty password"
SIGNER="$(cast wallet address --account "$ACCOUNT" --password "$PW" 2>/dev/null)" \
    || die "could not unlock keystore account '$ACCOUNT' (wrong password, or no such account)"
ok "signer: $SIGNER  (keystore '$ACCOUNT')"

# ===== contract preflight =====
for p in "$OLD_PAYMASTER" "$NEW_PAYMASTER" "$AGGREGATOR"; do
    [[ "$(cast code "$p" "${R[@]}")" != "0x" ]] || die "no code at $p on $CHAIN_LABEL"
done

OLD_EP="$(cast call "$OLD_PAYMASTER" 'entryPoint()(address)' "${R[@]}")"
NEW_EP="$(cast call "$NEW_PAYMASTER" 'entryPoint()(address)' "${R[@]}")"
[[ "${OLD_EP,,}" == "${ENTRYPOINT,,}" ]] || die "old paymaster EntryPoint is $OLD_EP, expected $ENTRYPOINT"
[[ "${NEW_EP,,}" == "${ENTRYPOINT,,}" ]] || die "new paymaster EntryPoint is $NEW_EP, expected $ENTRYPOINT"
ok "both paymasters share EntryPoint $ENTRYPOINT"

# A globally paused NEW paymaster would accept funds that no UserOp can then spend, and a
# paused OLD one blocks the manager exit path. Neither is fatal to this script, but both are
# worth refusing to run blind into.
[[ "$(cast call "$NEW_PAYMASTER" 'globalPaused()(bool)' "${R[@]}")" == "false" ]] \
    || die "the NEW paymaster is globalPaused; funding it now would strand the $NATIVE"

# THE GATE. Without FUNDING_ROLE every withdraw reverts, so check once here rather than
# discovering it one failed transaction at a time.
HAS_ROLE="$(cast call "$OLD_PAYMASTER" 'hasRole(bytes32,address)(bool)' "$FUNDING_ROLE" "$SIGNER" "${R[@]}")"
if [[ "$HAS_ROLE" != "true" ]]; then
    echo
    die "$(cat <<EOF
$SIGNER does NOT hold FUNDING_ROLE on $OLD_PAYMASTER.
       Every withdrawStrategyFunds call would revert.

       FUNDING_ROLE is held by the paymaster admin EOA set at deployment:
         0x22BC97cFac64D6d9BCaDF5dC36e4D01Db9e929c5   = the 'v2-deployer' keystore
       (DeploySuperSponsorshipPaymaster.s.sol: PAYMASTER_ADMIN)

       Most likely you passed the wrong ACCOUNT. Re-run with ACCOUNT=v2-deployer.
       Note 'v2-supervaults' (0x6E3dadcAf328ebB58753e89a3e589F5C5e988dF8) does NOT hold it.
       Otherwise the admin must grantRole(FUNDING_ROLE, $SIGNER) on $OLD_PAYMASTER first.
EOF
)"
fi
ok "signer holds FUNDING_ROLE on the old paymaster"

# ===== build the plan =====
info "enumerating $CHAIN_LABEL strategies from the aggregator"
mapfile -t STRATEGIES < <(
    cast call "$AGGREGATOR" 'getAllSuperVaultStrategies()(address[])' "${R[@]}" \
        | tr -d '[]' | tr ',' '\n' | tr -d ' ' | grep -E '^0x[0-9a-fA-F]{40}$'
)
(( ${#STRATEGIES[@]} > 0 )) || die "the aggregator returned no strategies"
info "${#STRATEGIES[@]} strategies registered; reading budgets on the old paymaster"

# `getStrategyBudget` returns (balance, totalDebited, maxSingleOpCost, paused); cast prints it
# as a tuple and annotates large numbers as "123[1.23e17]", so strip the annotation.
# A FAILED READ IS NOT A ZERO BALANCE. The caller treats an empty result as "nothing to
# migrate" and skips the strategy, so swallowing a transient RPC error here would quietly leave
# a funded strategy behind and still report success. Fail loudly instead.
strategy_balance() {
    local raw
    raw="$(cast call "$OLD_PAYMASTER" 'getStrategyBudget(address)((uint256,uint256,uint128,bool))' "$1" "${R[@]}" 2>&1)" \
        || die "could not read the budget for $1 on the old paymaster: $raw"
    printf '%s' "$raw" | tr -d '()' | cut -d, -f1 | sed 's/\[.*//' | tr -d ' '
}

PLAN_FILE="$(mktemp)"; trap 'rm -f "$PLAN_FILE"' EXIT
for s in "${STRATEGIES[@]}"; do
    b="$(strategy_balance "$s")"
    [[ -n "$b" && "$b" != "0" ]] && echo "$s $b" >> "$PLAN_FILE"
done
FUNDED_COUNT="$(wc -l < "$PLAN_FILE" | tr -d ' ')"
(( FUNDED_COUNT > 0 )) || { ok "nothing to migrate: no strategy holds a balance on the old paymaster"; exit 0; }

# Summed in Python, NOT awk: awk accumulates in a double, which silently loses precision
# above 2^53. On the live plan that produced a total 6 wei short of the true sum and broke the
# totalAllocated reconciliation below. Every wei figure in this script stays integer.
TOTAL_WITHDRAW="$(python3 -c "
import sys
print(sum(int(l.split()[1]) for l in open('$PLAN_FILE')))")"
TOTAL_FUND="$(wei_pct "$TOTAL_WITHDRAW" "$RETAIN_PCT")"
TOTAL_ALLOCATED="$(cast call "$OLD_PAYMASTER" 'totalAllocated()(uint256)' "${R[@]}" | sed 's/\[.*//' | tr -d ' ')"
EP_DEPOSIT="$(cast call "$ENTRYPOINT" 'balanceOf(address)(uint256)' "$OLD_PAYMASTER" "${R[@]}" | sed 's/\[.*//' | tr -d ' ')"
SIGNER_BAL="$(cast balance "$SIGNER" "${R[@]}")"

echo
echo "====== MIGRATION PLAN ======"
printf '%-44s %22s %22s\n' "STRATEGY" "WITHDRAW (wei)" "FUND (wei)"
while read -r s b; do
    f="$(wei_pct "$b" "$RETAIN_PCT")"
    printf '%-44s %22s %22s\n' "$s" "$b" "$f"
done < "$PLAN_FILE"
echo "----------------------------------------------------------------------------------------------"
printf '%-44s %22s %22s\n' "TOTAL ($FUNDED_COUNT strategies)" "$TOTAL_WITHDRAW" "$TOTAL_FUND"
echo
echo "  retained at signer   : $(python3 -c "print($TOTAL_WITHDRAW - $TOTAL_FUND)") wei (${RETAIN_PCT}%)"
echo "  old totalAllocated   : $TOTAL_ALLOCATED wei"
echo "  old EntryPoint dep.  : $EP_DEPOSIT wei"
echo "  signer $NATIVE balance   : $SIGNER_BAL wei"
echo "============================"
echo

# Per-strategy sums must reconcile against totalAllocated, or a strategy exists that the
# aggregator does not list (e.g. funded before registration, or on a different aggregator)
# and this script would silently leave its budget behind.
if [[ "$TOTAL_WITHDRAW" != "$TOTAL_ALLOCATED" ]]; then
    warn "per-strategy balances ($TOTAL_WITHDRAW) do not equal totalAllocated ($TOTAL_ALLOCATED)."
    warn "difference: $(python3 -c "print($TOTAL_ALLOCATED - $TOTAL_WITHDRAW)") wei is held by strategies this"
    warn "script cannot see. Investigate before relying on this run to drain the old paymaster."
fi

# withdrawStrategyFunds also requires amount <= entryPoint.balanceOf(paymaster).
python3 -c "import sys; sys.exit(0 if $EP_DEPOSIT >= $TOTAL_WITHDRAW else 1)" \
    || die "EntryPoint deposit ($EP_DEPOSIT) is below the total to withdraw ($TOTAL_WITHDRAW); withdrawals would revert"

# ===== can the signer afford the gas? =====
# Matters far more on Ethereum than on Base: this sends 2 transactions per strategy, and a
# run that dies halfway leaves withdrawn ETH sitting on the signer with its matching
# fundStrategy never sent. Estimated from the real first leg rather than a guessed constant.
FIRST_STRAT="$(head -1 "$PLAN_FILE" | cut -d' ' -f1)"
FIRST_AMT="$(head -1 "$PLAN_FILE" | cut -d' ' -f2)"
GAS_W="$(cast estimate "$OLD_PAYMASTER" 'withdrawStrategyFunds(address,address,uint256)' \
            "$FIRST_STRAT" "$SIGNER" "$FIRST_AMT" --from "$SIGNER" "${R[@]}" 2>/dev/null || echo 120000)"
GAS_F="$(cast estimate "$NEW_PAYMASTER" 'fundStrategy(address)' "$FIRST_STRAT" \
            --value "$(wei_pct "$FIRST_AMT" "$RETAIN_PCT")" --from "$SIGNER" "${R[@]}" 2>/dev/null || echo 150000)"
GAS_PRICE="$(cast gas-price "${R[@]}")"
# 30% headroom on the price: a run takes minutes and mainnet gas moves inside that window.
GAS_COST="$(python3 -c "print(($GAS_W + $GAS_F) * $FUNDED_COUNT * $GAS_PRICE * 130 // 100)")"
echo "  gas estimate         : $(( GAS_W + GAS_F )) gas/strategy x $FUNDED_COUNT at $GAS_PRICE wei"
echo "                         ~$GAS_COST wei with 30% price headroom"
if ! python3 -c "import sys; sys.exit(0 if $SIGNER_BAL >= $GAS_COST else 1)"; then
    die "signer holds $SIGNER_BAL wei but needs about $GAS_COST for gas. Top it up before running;
       a run that stops midway leaves withdrawn $NATIVE on the signer with its funding unsent."
fi
ok "signer can cover the gas"
echo

if [[ "$CONFIRM" != "yes" ]]; then
    warn "DRY RUN. Nothing was sent. Re-run with CONFIRM=yes to broadcast."
    exit 0
fi

# ===== execute =====
SEND=(--account "$ACCOUNT" --password "$PW" "${R[@]}")

# A load-balanced RPC can serve a stale view straight after a send, so confirm the state
# actually moved instead of trusting the receipt alone. This bit the SPCX registration run.
await_zero_balance() {
    local s="$1"
    for _ in $(seq 1 30); do
        [[ "$(strategy_balance "$s")" == "0" ]] && return 0
        sleep 2
    done
    return 1
}

# Read the plan on FD 3, not stdin: a `while read` loop fed from stdin loses its remaining
# lines the moment anything inside the body reads stdin, which would silently skip strategies.
i=0
while read -r -u 3 s b; do
    i=$((i+1))
    FUND="$(wei_pct "$b" "$RETAIN_PCT")"
    echo
    echo "---------- [$i/$FUNDED_COUNT] $s ----------"

    # Re-read: a previous interrupted run may already have drained this one.
    CUR="$(strategy_balance "$s")"
    if [[ -z "$CUR" || "$CUR" == "0" ]]; then
        info "already drained on the old paymaster, skipping"
        continue
    fi
    if [[ "$CUR" != "$b" ]]; then
        warn "balance changed since the plan was built ($b -> $CUR); using the live value"
        b="$CUR"
        FUND="$(wei_pct "$b" "$RETAIN_PCT")"
    fi
    wei_gt_zero "$FUND" || warn "${RETAIN_PCT}%-retained share of $b rounds to zero; withdrawing without forwarding"

    # Simulate before spending gas. An abort here means something changed since preflight.
    info "simulating withdraw of $b wei"
    cast call "$OLD_PAYMASTER" 'withdrawStrategyFunds(address,address,uint256)' \
        "$s" "$SIGNER" "$b" --from "$SIGNER" "${R[@]}" >/dev/null \
        || die "withdraw simulation reverted for $s; nothing sent"

    info "sending withdraw"
    cast send "$OLD_PAYMASTER" 'withdrawStrategyFunds(address,address,uint256)' \
        "$s" "$SIGNER" "$b" "${SEND[@]}" >/dev/null
    await_zero_balance "$s" || die "withdraw sent but $s still shows a non-zero balance; stopping"
    ok "withdrew $b wei to the signer"

    if ! wei_gt_zero "$FUND"; then
        warn "nothing to forward for $s"
        continue
    fi

    info "simulating fundStrategy with $FUND wei"
    cast call "$NEW_PAYMASTER" 'fundStrategy(address)' "$s" \
        --value "$FUND" --from "$SIGNER" "${R[@]}" >/dev/null \
        || die "fundStrategy simulation reverted for $s; the withdrawn $NATIVE is on $SIGNER"

    BEFORE="$(cast call "$NEW_PAYMASTER" 'getStrategyBudget(address)((uint256,uint256,uint128,bool))' "$s" "${R[@]}" \
              | tr -d '()' | cut -d, -f1 | sed 's/\[.*//' | tr -d ' ')"
    info "sending fundStrategy"
    cast send "$NEW_PAYMASTER" 'fundStrategy(address)' "$s" --value "$FUND" "${SEND[@]}" >/dev/null

    for _ in $(seq 1 30); do
        AFTER="$(cast call "$NEW_PAYMASTER" 'getStrategyBudget(address)((uint256,uint256,uint128,bool))' "$s" "${R[@]}" \
                 | tr -d '()' | cut -d, -f1 | sed 's/\[.*//' | tr -d ' ')"
        [[ "$AFTER" != "$BEFORE" ]] && break
        sleep 2
    done
    [[ "$AFTER" != "$BEFORE" ]] || die "fundStrategy sent but the new budget for $s did not move; stopping"
    ok "funded $FUND wei on the new paymaster (budget $BEFORE -> $AFTER)"
done 3< "$PLAN_FILE"

# ===== reconcile =====
echo
echo "====== RESULT ======"
echo "  old totalAllocated : $(cast call "$OLD_PAYMASTER" 'totalAllocated()(uint256)' "${R[@]}")"
echo "  new totalAllocated : $(cast call "$NEW_PAYMASTER" 'totalAllocated()(uint256)' "${R[@]}")"
echo "  signer balance     : $(cast balance "$SIGNER" "${R[@]}") wei"
echo "                       (expect roughly the ${RETAIN_PCT}% retention minus gas)"
echo "===================="
ok "migration complete"
