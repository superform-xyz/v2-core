#!/usr/bin/env bash

###################################################################################
# Deploy Other Hooks Script
###################################################################################
# Description:
#   Deploys all other-hook families (Morpho, Aave V3/V4, HyperCore, Firelight, Algebra
#   Integral, DETH, Sponsorship, rFLR, WrappedNative, Euler, Spectra, Odos V3,
#   FeeSplitting, Gyld, ...) via DeployV2OtherHooks.s.sol across configured networks.
#
#   SINGLE-DISPATCH: one forge invocation per network, calling the generic run() entrypoint.
#   Per-family chain gating lives in Solidity (_deployAllHooks) — the single source of truth.
#   Each family therefore deploys exactly once per network; already-deployed contracts skip
#   idempotently. On failure, the family being deployed is attributed from the run log.
#
#   Sources lib_deploy.sh for shared deployment utilities.
#
# Usage:
#   ./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh <environment> <mode> <account> [--slow] [--resume] [--legacy]
#
#   Targeted single-family redeploy (uses the explicit run<Family>() entrypoints kept in
#   DeployV2OtherHooks.s.sol, e.g. runHyperCore/runFirelight/runSponsorship/runFeeSplitting/runGyld):
#     TARGET_FAMILY=HyperCore ./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh staging deploy v2
#
#   Gyld tokenized bonds are ONLY deployable this way, because both config tables in
#   ConfigOtherHooks are deliberately empty and the generic `run` path therefore skips the family
#   on every chain:
#     TARGET_FAMILY=Gyld ./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh staging deploy v2
#   That ships the registry, oracle and guard, which are inert until an instrument is registered.
#   The two trade instances additionally need gyldSettlements[chainId] set to Gyld's venue address,
#   which does not exist yet.
#
#   REQUIRED POST-DEPLOY, IN THIS ORDER. GyldTradePolicy fails closed by design, so skipping a step
#   does not degrade gracefully: it makes every affected trade revert. Signatures below are exact —
#   an earlier version of this block omitted the registry address from both and produced
#   unresolvable selectors.
#
#     1. register the oracle in SuperLedgerConfiguration, feePercent = 0, never FlatFeeLedger. TWO
#        commands, not one — the wrapper does NOT build its own work list, it reads a file:
#          sh script/run/tooling/extract_configurable_oracles.sh <env> v2-deployer
#          ./script/run/config/add_to_super_ledger_staging_prod.sh <env> <mode> <account>
#        Run the extract step even if `script/output/<env>/new_oracles_to_add` already exists. A file
#        left over from an earlier family's deploy makes the wrapper succeed loudly while registering
#        that OTHER family's oracles and never mentioning GyldBondYieldSourceOracle — the one failure
#        here that produces no error at all. Confirm the oracle is named in the file before signing.
#
#     2. set the registry-wide PPS tolerance, AS DEPLOYER (still holds INSTRUMENT_MANAGER_ROLE):
#          forge script script/ConfigureGyldBondRegistry.s.sol:ConfigureGyldBondRegistry \
#            --sig 'runPolicyDefaults(uint256,uint64,address)' <env> <chainId> <registry>
#        Skipped and an aggregator is wired -> every trade reverts PPS_AGE_NOT_CONFIGURED.
#
#     3. hand the roles to governance:
#          forge script script/TransferGyldBondRegistryRoles.s.sol:TransferGyldBondRegistryRoles \
#            --sig 'run(uint256,uint64,address)' <env> <chainId> <registry>
#        Its own NatSpec explains why this precedes instrument registration.
#
#     4. register each instrument, AS GOVERNOR. There is no script for this yet. Set
#        maxEntryPremiumBps / maxExitDiscountBps IN THE InstrumentConfig here — registration accepts
#        zero for both, and zero is what the policy reports as unconfigured.
#
#     5. only if step 4 left either tolerance at zero, or to recalibrate later, AS GOVERNOR:
#          forge script script/ConfigureGyldBondRegistry.s.sol:ConfigureGyldBondRegistry \
#            --sig 'runTradeFloors(uint256,uint64,address,address,uint16,uint16)' \
#            <env> <chainId> <registry> <bondToken> <entryBps> <exitBps>
#        Requires the instrument to be registered already, which is why it follows step 4.
#        Left at zero -> every fill in that direction reverts TRADE_FLOORS_NOT_SET.
#
#     5b. OPTIONAL, and only as a deliberate incident decision, AS GOVERNOR (R4-3):
#          registry.setEmergencyExit(bondToken, maxPublicationAge, discountBps)
#        Opens the bounded exit grace so a SELL can still price against a recently stale NAV
#        publication instead of waiting out a 2-day recovery mark. Both arguments together or
#        neither; (0, 0) closes it. The discount must be >= maxExitDiscountBps and <=
#        MAX_TOLERANCE_BPS, the window <= MAX_AGE_CEILING. NOT set at registration by design, and
#        NOT a default: leave it closed until an incident calls for it, and close it afterwards.
#        Never widened for a BUY — the policy ignores it on that leg.
#
#     6. verify before believing any of it. Read-only, safe against prod at any time:
#          forge script script/ConfigureGyldBondRegistry.s.sol:ConfigureGyldBondRegistry \
#            --sig 'runCheck(uint64,address,address,address[])' <chainId> <registry> <policy> '[]'
#        It prints UNSET for maxPpsAge and for each direction's floor. A registry that looks healthy
#        and trades nothing is the failure mode this exists to surface.
#
#     7. register the guard and both trade instances in the periphery SuperGovernor, then add the
#        leaves to the strategy's Merkle root. Both are periphery-side and outside this repo.
#   Note: a targeted family run executes on every configured network; families with chain
#   requirements revert (and are reported) on unsupported chains.
#
# Arguments:
#   environment: staging or prod
#   mode: simulate or deploy
#   account: foundry account name (e.g., v2, deployer, main)
#   --slow: (optional) send transactions one at a time
#   --resume: (optional) resume from previous broadcast
#   --legacy: (optional) use legacy transactions with 1 gwei gas price
###################################################################################

set -eo pipefail

# Source shared deployment library
source "$(dirname "${BASH_SOURCE[0]}")/../utils/lib_deploy.sh"

FORGE_SCRIPT="script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks"

# ── Setup ──────────────────────────────────────────────────────────────────────
print_header "Other Hooks Deployment Script"

parse_args "$@"
validate_environment "$ENVIRONMENT"
validate_account "$ACCOUNT"
setup_mode_flags "$MODE"
load_credentials
create_output_directories

# ── Hook support check functions ───────────────────────────────────────────────

# ── Other hooks bytecode path ──────────────────────────────────────────────────

# All environments deploy from locked-bytecode/
# (use regenerate_bytecode.sh to build, then manually copy to locked-bytecode/)
OTHER_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode"

# ── Bytecode availability checks ──────────────────────────────────────────────

echo -e "${BLUE}Checking Morpho hook bytecode availability...${NC}"

MORPHO_HOOKS=(
    "MorphoSupplyAndBorrowHook"
    "MorphoBorrowHook"
    "MorphoRepayHook"
    "MorphoRepayAndWithdrawHook"
    "MorphoSupplyHook"
    "MorphoWithdrawHook"
    "MorphoLendHook"
    "MetaMorphoReallocateHook"
    "ForceDeallocateMorphoHook"
    "MorphoSupplyAndBorrowHookV2"
    "MorphoRepayHookV2"
    "MorphoRepayAndWithdrawHookV2"
    "MorphoHealthCheckHook"
)

missing_morpho=0
for hook in "${MORPHO_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_morpho=$((missing_morpho + 1))
    fi
done

if [ $missing_morpho -gt 0 ]; then
    echo -e "${YELLOW}${missing_morpho} Morpho hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo -e "${BLUE}Checking Aave V4 hook bytecode availability...${NC}"

AAVE_V4_HOOKS=(
    "AaveV4SupplyHook"
    "AaveV4WithdrawHook"
    "AaveV4BorrowHook"
    "AaveV4RepayHook"
    "AaveV4SupplyAndBorrowHook"
    "AaveV4RepayAndWithdrawHook"
    "AaveV4SupplyAndBorrowHookV2"
    "AaveV4RepayHookV2"
    "AaveV4RepayAndWithdrawHookV2"
    "AaveV4LendHook"
    "AaveV4RedeemHook"
    "AaveV4SupplyHookV2"
    "AaveV4BorrowHookV2"
    "AaveV4WithdrawHookV2"
    "AaveV4HealthCheckHook"
)

missing_aavev4=0
for hook in "${AAVE_V4_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_aavev4=$((missing_aavev4 + 1))
    fi
done

if [ $missing_aavev4 -gt 0 ]; then
    echo -e "${YELLOW}${missing_aavev4} Aave V4 hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo -e "${BLUE}Checking Aave V3 hook bytecode availability...${NC}"

AAVE_V3_HOOKS=(
    "AaveV3SupplyHook"
    "AaveV3WithdrawHook"
    "AaveV3BorrowHook"
    "AaveV3RepayHook"
    "AaveV3SupplyAndBorrowHook"
    "AaveV3RepayAndWithdrawHook"
    "AaveV3RepayWithATokensHook"
    "AaveV3SupplyAndBorrowHookV2"
    "AaveV3RepayHookV2"
    "AaveV3RepayAndWithdrawHookV2"
)

missing_aavev3=0
for hook in "${AAVE_V3_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_aavev3=$((missing_aavev3 + 1))
    fi
done

if [ $missing_aavev3 -gt 0 ]; then
    echo -e "${YELLOW}${missing_aavev3} Aave V3 hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking Euler EVK hook bytecode availability...${NC}"

EULER_HOOKS=(
    "EulerDepositCollateralAndBorrowHook"
    "EulerRepayHook"
    "EulerRepayAndWithdrawHook"
)

missing_euler=0
for hook in "${EULER_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_euler=$((missing_euler + 1))
    fi
done

if [ $missing_euler -gt 0 ]; then
    echo -e "${YELLOW}${missing_euler} Euler EVK hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking Firelight hook bytecode availability...${NC}"

FIRELIGHT_HOOKS=(
    "RedeemFirelightVaultHook"
    "ClaimWithdrawFirelightVaultHook"
)

missing_firelight=0
for hook in "${FIRELIGHT_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_firelight=$((missing_firelight + 1))
    fi
done

if [ $missing_firelight -gt 0 ]; then
    echo -e "${YELLOW}${missing_firelight} Firelight hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking HyperCore hook bytecode availability...${NC}"

HYPERCORE_HOOKS=(
    "HyperCoreAddApiWalletHook"
    "HyperCoreUsdClassTransferHook"
    "HyperCoreSendAssetHook"
    "HyperCoreApproveBuilderFeeHook"
    "ApproveAndHyperCoreDepositHook"
    "HyperCorePerpPositionOracle"
)

missing_hypercore=0
for hook in "${HYPERCORE_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_hypercore=$((missing_hypercore + 1))
    fi
done

if [ $missing_hypercore -gt 0 ]; then
    echo -e "${YELLOW}${missing_hypercore} HyperCore hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking Gyld bond contract bytecode availability...${NC}"

# ApproveAndTradeGyldBondHook ships TWICE, once per direction, from this ONE artifact: the two deploy
# keys differ (and therefore the CREATE2 salts and addresses), the bytecode does not. So four artifacts
# back five deploy entries.
GYLD_CONTRACTS=(
    "GyldBondRegistry"
    "GyldBondYieldSourceOracle"
    "GyldTradePolicy"
    "GyldTradeGuardHook"
    "ApproveAndTradeGyldBondHook"
)

missing_gyld=0
for contract in "${GYLD_CONTRACTS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${contract}.json" ]; then
        echo -e "${GREEN}   ${contract}${NC}"
    else
        echo -e "${YELLOW}   ${contract} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_gyld=$((missing_gyld + 1))
    fi
done

if [ $missing_gyld -gt 0 ]; then
    echo -e "${YELLOW}${missing_gyld} Gyld contract(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo -e "${YELLOW}   NOTE: the Gyld family is NOT deployed by a routine run. Both config tables in${NC}"
echo -e "${YELLOW}   ConfigOtherHooks are deliberately empty, so it is skipped on every chain unless you${NC}"
echo -e "${YELLOW}   target it explicitly with TARGET_FAMILY=Gyld.${NC}"

echo ""

echo -e "${BLUE}Checking Algebra Integral hook bytecode availability...${NC}"

ALGEBRA_INTEGRAL_HOOKS=(
    "SwapAlgebraIntegralHook"
    "ApproveAndSwapAlgebraIntegralHook"
)

missing_algebra=0
for hook in "${ALGEBRA_INTEGRAL_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_algebra=$((missing_algebra + 1))
    fi
done

if [ $missing_algebra -gt 0 ]; then
    echo -e "${YELLOW}${missing_algebra} Algebra Integral hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking DETH hook bytecode availability...${NC}"

DETH_HOOKS=(
    "RequestRedeemDETHHook"
    "ApproveAndRequestRedeemDETHHook"
    "ClaimAssetsDETHHook"
)

missing_deth=0
for hook in "${DETH_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_deth=$((missing_deth + 1))
    fi
done

if [ $missing_deth -gt 0 ]; then
    echo -e "${YELLOW}${missing_deth} DETH hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking Sponsorship contract bytecode availability...${NC}"

SPONSORSHIP_CONTRACTS=(
    "NativeFeeSponsorship"
    "FetchNativeFeeHook"
)

missing_sponsorship=0
for hook in "${SPONSORSHIP_CONTRACTS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_sponsorship=$((missing_sponsorship + 1))
    fi
done

if [ $missing_sponsorship -gt 0 ]; then
    echo -e "${YELLOW}${missing_sponsorship} Sponsorship contract(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking rFLR hook bytecode availability...${NC}"

RFLR_HOOKS=(
    "ClaimRFLRHook"
    "ClaimRFLRV2Hook"
    "ClaimRFLRV3Hook"
    "WithdrawRFLRHook"
    "WithdrawVestedRFLRHook"
)

missing_rflr=0
for hook in "${RFLR_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_rflr=$((missing_rflr + 1))
    fi
done

if [ $missing_rflr -gt 0 ]; then
    echo -e "${YELLOW}${missing_rflr} rFLR hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking rFLR V2 hook bytecode availability...${NC}"

RFLR_V2_HOOKS=(
    "WithdrawRFLRHookV2"
    "WithdrawVestedRFLRHookV2"
)

missing_rflr_v2=0
for hook in "${RFLR_V2_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_rflr_v2=$((missing_rflr_v2 + 1))
    fi
done

if [ $missing_rflr_v2 -gt 0 ]; then
    echo -e "${YELLOW}${missing_rflr_v2} rFLR V2 hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

echo -e "${BLUE}Checking WrappedNativeHook bytecode availability...${NC}"

WRAPPED_NATIVE_HOOKS=(
    "WrappedNativeHook"
)

missing_wrapped_native=0
for hook in "${WRAPPED_NATIVE_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ${hook}${NC}"
    else
        echo -e "${YELLOW}   ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_wrapped_native=$((missing_wrapped_native + 1))
    fi
done

if [ $missing_wrapped_native -gt 0 ]; then
    echo -e "${YELLOW}${missing_wrapped_native} WrappedNative hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/tooling/regenerate_bytecode.sh WrappedNativeHook to generate missing bytecode.${NC}"
fi

echo ""
print_separator

# ── Confirmation ───────────────────────────────────────────────────────────────

echo -e "${WHITE}Deploy hooks (Morpho + Aave V4 + HyperCore + Firelight + Algebra Integral + DETH + Sponsorship + rFLR + rFLR V2 + WrappedNative + Loan Hooks V2 + Euler) to all networks in $ENVIRONMENT mode '$MODE'? (y/n): ${NC}"
read -r proceed

if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
    echo -e "${YELLOW}Deployment cancelled by user${NC}"
    exit 1
fi

# ── Keystore password ─────────────────────────────────────────────────────────

prompt_keystore_password "$ACCOUNT"

print_separator

# ── Deploy to each network ─────────────────────────────────────────────────────

# Acquire deploy lock + check stale broadcasts
acquire_deploy_lock
check_stale_broadcasts "DeployV2OtherHooks"

deployed_networks=0
declare -a FAILED_HOOK_DEPLOYS=()

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var <<< "$network_def"

    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                  Deploying Other Hooks to ${network_name} (${network_id})                      ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"

    # Check RPC URL is set
    if [[ -z "${!rpc_var:-}" ]]; then
        echo -e "${RED}  RPC URL $rpc_var not set, skipping $network_name${NC}"
        continue
    fi

    # Pre-flight: nonce + balance checks (warnings only, don't block)
    preflight_network_checks "$network_id" "$network_name" "$rpc_var" || true

    has_hooks=false

    # Per-chain verification flags (some chains don't support Etherscan V2)
    # Per-chain --chain flag (some chains not in forge's registry)
    local_etherscan_flags=""
    local_verify_flag="$VERIFY_FLAG"
    local_chain_flag="--chain $network_id"
    case $network_id in
        14|999|988|5042) # Flare, HyperEVM, Stable, Arc - no Etherscan support or rate-limited
            local_verify_flag=""
            echo -e "${CYAN}   Verification: ${WHITE}Skipped (explorer not supported)${NC}"
            ;;
        4663) # Robinhood Chain - Blockscout explorer (not on Etherscan V2)
            if [[ -n "$VERIFY_FLAG" ]]; then
                local_etherscan_flags="--verifier blockscout --verifier-url https://robinhoodchain.blockscout.com/api/"
            fi
            ;;
        *)
            # An empty key used to collapse this to `--etherscan-api-key --verifier ...`,
            # which forge rejects outright ("a value is required"). Deploy unverified
            # instead: the contracts land, and verify.sh can run against them after.
            if [[ -n "$VERIFY_FLAG" && -z "${ETHERSCANV2_API_KEY:-}" ]]; then
                local_verify_flag=""
                echo -e "${YELLOW}   Verification: Skipped (ETHERSCANV2_API_KEY empty)${NC}"
            elif [[ -n "$VERIFY_FLAG" ]]; then
                local_etherscan_flags="--etherscan-api-key ${ETHERSCANV2_API_KEY} --verifier etherscan --verifier-url https://api.etherscan.io/v2/api?chainid=$network_id"
            fi
            ;;
    esac
    case $network_id in
        988|5042) # Stable, Arc — not in forge's chain registry
            local_chain_flag=""
            ;;
    esac

    # Backup the existing output JSON before forge overwrites it
    output_json="$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id/$network_name-latest.json"
    backup_json="${output_json}.bak"
    if [[ -f "$output_json" ]]; then
        cp "$output_json" "$backup_json"
    fi

    # Deploy Morpho hooks if supported on this chain
    # Deploy ALL hook families via the generic run() entrypoint — single forge invocation.
    # Family gating lives in Solidity (_deployAllHooks): each family deploys exactly once per
    # network, gated by chain configuration (Morpho/Aave/HyperCore/Firelight/Algebra/DETH/
    # Sponsorship/rFLR/Spectra/Odos/Euler/FeeSplitting/...). The explicit run<Family>()
    # entrypoints remain in DeployV2OtherHooks.s.sol for targeted redeploys: set TARGET_FAMILY
    # to use one for this whole run (e.g. TARGET_FAMILY=HyperCore ./script/run/deploy/... ).
    has_hooks=true
    sig_name="run"
    if [[ -n "${TARGET_FAMILY:-}" ]]; then
        sig_name="run${TARGET_FAMILY}"
        echo -e "${YELLOW}   TARGET_FAMILY set: using ${sig_name}() for this run${NC}"
    fi
    echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
    echo -e "${YELLOW}   Deploying hook families via ${sig_name}() (single dispatch)...${NC}"

    deploy_log=$(mktemp)
    # Suspend errexit around the forge pipeline: with `set -eo pipefail` a chain failure
    # (e.g. insufficient native for gas) would abort the whole run before the PIPESTATUS
    # check below — the loop must move on to the remaining chains instead.
    set +e
    forge script "$FORGE_SCRIPT" \
        --sig "${sig_name}(uint256,uint64)" $FORGE_ENV $network_id \
        --gas-limit "$SCRIPT_GAS_LIMIT" \
        --account "$ACCOUNT" \
        $KEYSTORE_PASSWORD_FLAG \
        --rpc-url ${!rpc_var} \
        $local_chain_flag \
        $local_etherscan_flags \
        $BROADCAST_FLAG \
        $local_verify_flag \
        $SLOW_FLAG \
        $BATCH_SIZE_FLAG \
        $RESUME_FLAG \
        $LEGACY_FLAG \
        $GAS_PRICE_FLAG \
        --timeout 300 \
        -vv 2>&1 | tee "$deploy_log"
    forge_status=${PIPESTATUS[0]}
    set -e
    if [[ $forge_status -eq 0 ]]; then
        echo -e "${GREEN}   Hook deployment completed!${NC}"
    else
        # Attribute the failure to the family that was mid-deploy when the run aborted:
        # the Solidity dispatcher logs a "Deploying <Family> ... on chainId" marker per family.
        failed_family=$(grep -oE "Deploying [A-Za-z0-9 ]+ on chainId" "$deploy_log" | tail -1 | sed -E 's/^Deploying //; s/ on chainId$//')
        FAILED_HOOK_DEPLOYS+=("${failed_family:-unknown family} @ $network_name")
        echo -e "${RED}   Hook deployment failed on $network_name (family: ${failed_family:-unknown}), continuing...${NC}"
    fi
    rm -f "$deploy_log"

    # Restore any entries that the forge script dropped (e.g., Nexus contracts)
    preserve_existing_json_entries "$output_json" "$backup_json"
    rm -f "$backup_json"

    if [ "$has_hooks" = false ]; then
        echo -e "${YELLOW}  No supported hooks for $network_name ($network_id), skipping${NC}"
        continue
    fi

    deployed_networks=$((deployed_networks + 1))
    echo ""
done

# ── Post-deployment verification ───────────────────────────────────────────────
verify_deployments

# ── Summary ────────────────────────────────────────────────────────────────────
print_separator

if [[ ${#FAILED_HOOK_DEPLOYS[@]} -gt 0 ]]; then
    echo -e "${RED}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║${WHITE}     Other Hooks $ENVIRONMENT $MODE completed with ERRORS                              ${RED}║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "${RED}   Failed deployments (${#FAILED_HOOK_DEPLOYS[@]}):${NC}"
    for failed in "${FAILED_HOOK_DEPLOYS[@]}"; do
        echo -e "${RED}     - $failed${NC}"
    done
    exit 1
else
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}     Other Hooks $ENVIRONMENT $MODE Completed ($deployed_networks networks)                  ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
fi
