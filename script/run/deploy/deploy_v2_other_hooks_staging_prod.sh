#!/usr/bin/env bash

###################################################################################
# Deploy Other Hooks Script
###################################################################################
# Description:
#   Deploys all other-hook families (Morpho, Aave V3/V4, HyperCore, Firelight, Algebra
#   Integral, DETH, Sponsorship, rFLR, WrappedNative, Euler, Spectra, Odos V3,
#   FeeSplitting, ...) via DeployV2OtherHooks.s.sol across configured networks.
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
#   DeployV2OtherHooks.s.sol, e.g. runHyperCore/runFirelight/runSponsorship/runFeeSplitting):
#     TARGET_FAMILY=HyperCore ./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh staging deploy v2
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
        14|999|988) # Flare, HyperEVM, Stable - no Etherscan support or rate-limited
            local_verify_flag=""
            echo -e "${CYAN}   Verification: ${WHITE}Skipped (explorer not supported)${NC}"
            ;;
        4663) # Robinhood Chain - Blockscout explorer (not on Etherscan V2)
            if [[ -n "$VERIFY_FLAG" ]]; then
                local_etherscan_flags="--verifier blockscout --verifier-url https://robinhoodchain.blockscout.com/api/"
            fi
            ;;
        *)
            if [[ -n "$VERIFY_FLAG" ]]; then
                local_etherscan_flags="--etherscan-api-key $ETHERSCANV2_API_KEY --verifier etherscan --verifier-url https://api.etherscan.io/v2/api?chainid=$network_id"
            fi
            ;;
    esac
    case $network_id in
        988) # Stable chain not in forge's chain registry
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
    forge script "$FORGE_SCRIPT" \
        --sig "${sig_name}(uint256,uint64)" $FORGE_ENV $network_id \
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
    if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
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
