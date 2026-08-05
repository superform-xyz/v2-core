#!/usr/bin/env bash

###################################################################################
# Deploy Other Hooks Script
###################################################################################
# Description:
#   Deploys other hooks (Morpho, Aave V4, Firelight, Algebra Integral, DETH,
#   Sponsorship, rFLR, WrappedNative) via DeployV2OtherHooks.s.sol across configured networks.
#   Sources lib_deploy.sh for shared deployment utilities.
#
# Usage:
#   ./script/run/deploy/deploy_v2_other_hooks_staging_prod.sh <environment> <mode> <account> [--slow] [--resume] [--legacy]
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

# Morpho is only deployed on these chains
MORPHO_SUPPORTED_CHAINS=("1" "8453" "56" "42161")

is_morpho_supported() {
    local chain_id=$1
    for supported in "${MORPHO_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

# Aave V4 is only deployed on Ethereum mainnet
AAVE_V4_SUPPORTED_CHAINS=("1")

is_aave_v4_supported() {
    local chain_id=$1
    for supported in "${AAVE_V4_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

# Firelight is only deployed on Flare
FIRELIGHT_SUPPORTED_CHAINS=("14")

is_firelight_supported() {
    local chain_id=$1
    for supported in "${FIRELIGHT_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

# Algebra Integral (SparkDEX V4) is only deployed on Flare
ALGEBRA_INTEGRAL_SUPPORTED_CHAINS=("14")

is_algebra_integral_supported() {
    local chain_id=$1
    for supported in "${ALGEBRA_INTEGRAL_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

# DETH hooks are only deployed on Ethereum mainnet
DETH_SUPPORTED_CHAINS=("1")

is_deth_supported() {
    local chain_id=$1
    for supported in "${DETH_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

# Sponsorship contracts are deployed on all chains
is_sponsorship_supported() {
    return 0
}

# rFLR hooks are only deployed on Flare
RFLR_SUPPORTED_CHAINS=("14")

is_rflr_supported() {
    local chain_id=$1
    for supported in "${RFLR_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

# WrappedNativeHook is deployed on Ethereum (WETH) and Flare (WFLR)
WRAPPED_NATIVE_SUPPORTED_CHAINS=("1" "14")

is_wrapped_native_supported() {
    local chain_id=$1
    for supported in "${WRAPPED_NATIVE_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

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

echo -e "${WHITE}Deploy hooks (Morpho + Aave V4 + Firelight + Algebra Integral + DETH + Sponsorship + rFLR + rFLR V2 + WrappedNative) to all networks in $ENVIRONMENT mode '$MODE'? (y/n): ${NC}"
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
    if is_morpho_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Morpho hooks...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'run(uint256,uint64)' $FORGE_ENV $network_id \
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
            -vv; then
            echo -e "${GREEN}   Morpho hooks deployment completed!${NC}"
        else
            echo -e "${RED}   Morpho hooks deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("Morpho @ $network_name")
        fi
    fi

    # Deploy Firelight hooks if supported on this chain
    if is_firelight_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Firelight hooks...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runFirelight(uint256,uint64)' $FORGE_ENV $network_id \
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
            -vv; then
            echo -e "${GREEN}   Firelight hooks deployment completed!${NC}"
        else
            echo -e "${RED}   Firelight hooks deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("Firelight @ $network_name")
        fi
    fi

    # Deploy Algebra Integral hooks if supported on this chain
    if is_algebra_integral_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Algebra Integral hooks (SparkDEX V4)...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runAlgebraIntegral(uint256,uint64)' $FORGE_ENV $network_id \
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
            -vv; then
            echo -e "${GREEN}   Algebra Integral hooks deployment completed!${NC}"
        else
            echo -e "${RED}   Algebra Integral hooks deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("AlgebraIntegral @ $network_name")
        fi
    fi

    # Deploy DETH hooks if supported on this chain
    if is_deth_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying DETH hooks...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runDETH(uint256,uint64)' $FORGE_ENV $network_id \
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
            -vv; then
            echo -e "${GREEN}   DETH hooks deployment completed!${NC}"
        else
            echo -e "${RED}   DETH hooks deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("DETH @ $network_name")
        fi
    fi

    # Deploy Sponsorship contracts (all chains)
    if is_sponsorship_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Sponsorship contracts...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runSponsorship(uint256,uint64)' $FORGE_ENV $network_id \
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
            -vv; then
            echo -e "${GREEN}   Sponsorship contracts deployment completed!${NC}"
        else
            echo -e "${RED}   Sponsorship contracts deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("Sponsorship @ $network_name")
        fi
    fi

    # Deploy rFLR hooks if supported on this chain
    if is_rflr_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying rFLR hooks...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runRFLR(uint256,uint64)' $FORGE_ENV $network_id \
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
            -vv; then
            echo -e "${GREEN}   rFLR hooks deployment completed!${NC}"
        else
            echo -e "${RED}   rFLR hooks deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("rFLR @ $network_name")
        fi
    fi

    # Deploy rFLR V2 hooks if supported on this chain
    if is_rflr_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying rFLR V2 hooks...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runRFLRV2(uint256,uint64)' $FORGE_ENV $network_id \
            --account "$ACCOUNT" \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url "${!rpc_var}" \
            --chain $network_id \
            $local_etherscan_flags \
            $BROADCAST_FLAG \
            $local_verify_flag \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv; then
            echo -e "${GREEN}   rFLR V2 hooks deployment completed!${NC}"
        else
            echo -e "${RED}   rFLR V2 hooks deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("rFLR V2 @ $network_name")
        fi
    fi

    # Deploy WrappedNativeHook (with WFLR address) if supported on this chain
    if is_wrapped_native_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying WrappedNativeHook...${NC}"

        if forge script "$FORGE_SCRIPT" \
            --sig 'runWrappedNative(uint256,uint64)' $FORGE_ENV $network_id \
            --account "$ACCOUNT" \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url "${!rpc_var}" \
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
            -vv; then
            echo -e "${GREEN}   WrappedNativeHook deployment completed!${NC}"
        else
            echo -e "${RED}   WrappedNativeHook deployment failed on $network_name, continuing...${NC}"
            FAILED_HOOK_DEPLOYS+=("WrappedNative @ $network_name")
        fi
    fi

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
