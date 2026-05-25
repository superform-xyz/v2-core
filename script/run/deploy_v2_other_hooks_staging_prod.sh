#!/usr/bin/env bash

###################################################################################
# Deploy Morpho Hooks Script
###################################################################################
# Description:
#   Deploys Morpho hooks (supply, borrow, repay, withdraw, lend, combined)
#   via DeployV2OtherHooks.s.sol across configured networks.
#
# Usage:
#   ./script/run/deploy_morpho_hooks.sh <environment> <mode> <account> [--slow] [--resume] [--legacy]
#
# Arguments:
#   environment: staging or prod
#   mode: simulate or deploy
#   account: foundry account name (e.g., v2, deployer, main)
#   --slow: (optional) send transactions one at a time
#   --resume: (optional) resume from previous broadcast
#   --legacy: (optional) use legacy transactions with 1 gwei gas price
#
# Author: Superform Team
###################################################################################

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Logging function
log() {
    local level=$1
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}                    🪝 Morpho Hooks Deployment Script 🪝                             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_header

# Script directory and project root setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check arguments
if [ $# -lt 3 ]; then
    echo -e "${RED}❌ Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode> <account> [--slow] [--resume] [--legacy]${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode: simulate or deploy${NC}"
    echo -e "${CYAN}  account: foundry account name${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging simulate v2${NC}"
    echo -e "${CYAN}  $0 prod deploy deployer${NC}"
    echo -e "${CYAN}  $0 prod deploy deployer --slow${NC}"
    exit 1
fi

ENVIRONMENT=$1
MODE=$2
ACCOUNT=$3

# Parse optional flags
SLOW_FLAG=""
BATCH_SIZE_FLAG=""
RESUME_FLAG=""
LEGACY_FLAG=""
GAS_PRICE_FLAG=""
for arg in "${@:4}"; do
    case "$arg" in
        --slow)
            SLOW_FLAG="--slow"
            BATCH_SIZE_FLAG="--batch-size 1"
            echo -e "${YELLOW}🐢 Slow mode enabled${NC}"
            ;;
        --resume)
            RESUME_FLAG="--resume"
            echo -e "${YELLOW}🔄 Resume mode enabled${NC}"
            ;;
        --legacy)
            LEGACY_FLAG="--legacy"
            GAS_PRICE_FLAG="--with-gas-price 1gwei"
            echo -e "${YELLOW}📜 Legacy mode enabled${NC}"
            ;;
    esac
done

# Validate environment and set bytecode paths
if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}🌐 Loading staging network configuration...${NC}"
    LOCKED_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode-dev"
    source "$SCRIPT_DIR/networks-staging.sh"
    FORGE_ENV=2
    export CI=true
    export GITHUB_REF_NAME="staging"
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}🌐 Loading production network configuration...${NC}"
    LOCKED_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode"
    source "$SCRIPT_DIR/networks-production.sh"
    FORGE_ENV=0
    export CI=true
    export GITHUB_REF_NAME="prod"
else
    echo -e "${RED}❌ Invalid environment: $ENVIRONMENT${NC}"
    exit 1
fi

echo -e "${CYAN}✅ Network configuration loaded for $ENVIRONMENT${NC}"
print_network_info

# Validate account
if ! cast wallet list 2>/dev/null | sed 's/ (Local)//' | grep -q "^$ACCOUNT$"; then
    echo -e "${RED}❌ Account '$ACCOUNT' not found in foundry wallet list${NC}"
    cast wallet list 2>/dev/null | sed 's/ (Local)//' | sed 's/^/  • /' || echo -e "${RED}  No accounts found.${NC}"
    exit 1
fi

# Set flags based on mode
if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}🔍 Running in simulation mode...${NC}"
    BROADCAST_FLAG=""
    VERIFY_FLAG=""
elif [ "$MODE" = "deploy" ]; then
    echo -e "${GREEN}🚀 Running in deployment mode...${NC}"
    BROADCAST_FLAG="--broadcast"
    VERIFY_FLAG="--verify"
else
    echo -e "${RED}❌ Invalid mode: $MODE${NC}"
    exit 1
fi

print_separator

# Load credentials
echo -e "${BLUE}🔧 Loading Configuration...${NC}"

echo -e "${CYAN}   • Loading RPC URLs...${NC}"
if ! load_rpc_urls; then
    echo -e "${RED}❌ Failed to load some RPC URLs${NC}"
fi

echo -e "${CYAN}   • Loading Etherscan V2 API credentials...${NC}"
if ! load_etherscan_api_key; then
    echo -e "${RED}❌ Failed to load Etherscan V2 API key${NC}"
    exit 1
fi

# Create output directories
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id _ _ <<< "$network_def"
    mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id"
done

cd "$PROJECT_ROOT"
export SUPERFORM_PROJECT_ROOT="$PROJECT_ROOT"

echo -e "${GREEN}✅ Configuration loaded${NC}"
print_separator

# Morpho is only deployed on these chains - skip others
MORPHO_SUPPORTED_CHAINS=("1" "8453" "56" "42161")

# Aave V4 is only deployed on Ethereum mainnet
AAVE_V4_SUPPORTED_CHAINS=("1")

is_morpho_supported() {
    local chain_id=$1
    for supported in "${MORPHO_SUPPORTED_CHAINS[@]}"; do
        if [ "$supported" = "$chain_id" ]; then
            return 0
        fi
    done
    return 1
}

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

# Other hooks use locked-bytecode-other/ for production
OTHER_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode-other"
if [ "$ENVIRONMENT" = "staging" ]; then
    if [ -d "$PROJECT_ROOT/script/generated-bytecode-other" ]; then
        OTHER_BYTECODE_PATH="$PROJECT_ROOT/script/generated-bytecode-other"
    fi
fi

# Check bytecode availability for Morpho hooks
echo -e "${BLUE}🔍 Checking Morpho hook bytecode availability...${NC}"

MORPHO_HOOKS=(
    "MorphoSupplyAndBorrowHook"
    "MorphoBorrowHook"
    "MorphoRepayHook"
    "MorphoRepayAndWithdrawHook"
    "MorphoSupplyHook"
    "MorphoWithdrawHook"
    "MorphoLendHook"
    "MetaMorphoReallocateHook"
)

missing_morpho=0
for hook in "${MORPHO_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ✅ ${hook}${NC}"
    else
        echo -e "${YELLOW}   ⚠️  ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_morpho=$((missing_morpho + 1))
    fi
done

if [ $missing_morpho -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ${missing_morpho} Morpho hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

# Check bytecode availability for Aave V4 hooks
echo -e "${BLUE}🔍 Checking Aave V4 hook bytecode availability...${NC}"

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
        echo -e "${GREEN}   ✅ ${hook}${NC}"
    else
        echo -e "${YELLOW}   ⚠️  ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_aavev4=$((missing_aavev4 + 1))
    fi
done

if [ $missing_aavev4 -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ${missing_aavev4} Aave V4 hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

# Check bytecode availability for Firelight hooks
echo -e "${BLUE}🔍 Checking Firelight hook bytecode availability...${NC}"

FIRELIGHT_HOOKS=(
    "RedeemFirelightVaultHook"
    "ClaimWithdrawFirelightVaultHook"
)

missing_firelight=0
for hook in "${FIRELIGHT_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ✅ ${hook}${NC}"
    else
        echo -e "${YELLOW}   ⚠️  ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_firelight=$((missing_firelight + 1))
    fi
done

if [ $missing_firelight -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ${missing_firelight} Firelight hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

# Check bytecode availability for Algebra Integral hooks
echo -e "${BLUE}🔍 Checking Algebra Integral hook bytecode availability...${NC}"

ALGEBRA_INTEGRAL_HOOKS=(
    "SwapAlgebraIntegralHook"
    "ApproveAndSwapAlgebraIntegralHook"
)

missing_algebra=0
for hook in "${ALGEBRA_INTEGRAL_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ✅ ${hook}${NC}"
    else
        echo -e "${YELLOW}   ⚠️  ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_algebra=$((missing_algebra + 1))
    fi
done

if [ $missing_algebra -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ${missing_algebra} Algebra Integral hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

# Check bytecode availability for DETH hooks
echo -e "${BLUE}🔍 Checking DETH hook bytecode availability...${NC}"

DETH_HOOKS=(
    "RequestRedeemDETHHook"
    "ApproveAndRequestRedeemDETHHook"
    "ClaimAssetsDETHHook"
)

missing_deth=0
for hook in "${DETH_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ✅ ${hook}${NC}"
    else
        echo -e "${YELLOW}   ⚠️  ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_deth=$((missing_deth + 1))
    fi
done

if [ $missing_deth -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ${missing_deth} DETH hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""

# Check bytecode availability for rFLR hooks
echo -e "${BLUE}🔍 Checking rFLR hook bytecode availability...${NC}"

RFLR_HOOKS=(
    "ClaimRFLRHook"
    "WithdrawRFLRHook"
)

missing_rflr=0
for hook in "${RFLR_HOOKS[@]}"; do
    if [ -f "$OTHER_BYTECODE_PATH/${hook}.json" ]; then
        echo -e "${GREEN}   ✅ ${hook}${NC}"
    else
        echo -e "${YELLOW}   ⚠️  ${hook} - missing from $OTHER_BYTECODE_PATH${NC}"
        missing_rflr=$((missing_rflr + 1))
    fi
done

if [ $missing_rflr -gt 0 ]; then
    echo -e "${YELLOW}⚠️  ${missing_rflr} rFLR hook(s) missing bytecode. They will be skipped during deployment.${NC}"
    echo -e "${YELLOW}   Run ./script/run/regenerate_bytecode.sh to generate missing bytecode.${NC}"
fi

echo ""
print_separator

# Confirmation before deployment
echo -e "${WHITE}🤔 Deploy hooks (Morpho + Aave V4 + Firelight + Algebra Integral + DETH + rFLR) to all networks in $ENVIRONMENT mode '$MODE'? (y/n): ${NC}"
read -r proceed

if [ "$proceed" != "y" ] && [ "$proceed" != "Y" ]; then
    echo -e "${YELLOW}Deployment cancelled by user${NC}"
    exit 1
fi

# Ask for keystore password once upfront (avoids repeated prompts per chain)
echo -ne "${WHITE}🔑 Enter keystore password for account '$ACCOUNT': ${NC}"
read -rs KEYSTORE_PASSWORD
echo ""
# Write to a temp file (secure: only user-readable, auto-cleaned on exit)
PASS_FILE=$(mktemp)
chmod 600 "$PASS_FILE"
echo "$KEYSTORE_PASSWORD" > "$PASS_FILE"
unset KEYSTORE_PASSWORD
trap 'rm -f "$PASS_FILE"' EXIT
KEYSTORE_PASSWORD_FLAG="--password-file $PASS_FILE"

print_separator

# Deploy to each network
deployed_networks=0

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var <<< "$network_def"

    echo -e "${PURPLE}╭─────────────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${PURPLE}│${WHITE}                  🪝 Deploying Other Hooks to ${network_name} (${network_id}) 🪝                      ${PURPLE}│${NC}"
    echo -e "${PURPLE}╰─────────────────────────────────────────────────────────────────────────────────────╯${NC}"


    # Check RPC URL is set
    if [[ -z "${!rpc_var:-}" ]]; then
        echo -e "${RED}  ❌ RPC URL $rpc_var not set, skipping $network_name${NC}"
        continue
    fi

    has_hooks=false

    # Deploy Morpho hooks if supported on this chain
    if is_morpho_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Morpho hooks...${NC}"

        if forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
            --sig 'run(uint256,uint64)' $FORGE_ENV $network_id \
            --account $ACCOUNT \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url ${!rpc_var} \
            --chain $network_id \
            --etherscan-api-key $ETHERSCANV2_API_KEY \
            --verifier etherscan \
            $BROADCAST_FLAG \
            $VERIFY_FLAG \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv; then
            echo -e "${GREEN}   ✅ Morpho hooks deployment completed!${NC}"
        else
            echo -e "${RED}   ❌ Morpho hooks deployment failed on $network_name, continuing...${NC}"
        fi
    fi

    # Deploy Firelight hooks if supported on this chain
    if is_firelight_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Firelight hooks...${NC}"

        if forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
            --sig 'runFirelight(uint256,uint64)' $FORGE_ENV $network_id \
            --account $ACCOUNT \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url ${!rpc_var} \
            --chain $network_id \
            --etherscan-api-key $ETHERSCANV2_API_KEY \
            --verifier etherscan \
            $BROADCAST_FLAG \
            $VERIFY_FLAG \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv; then
            echo -e "${GREEN}   ✅ Firelight hooks deployment completed!${NC}"
        else
            echo -e "${RED}   ❌ Firelight hooks deployment failed on $network_name, continuing...${NC}"
        fi
    fi

    # Deploy Algebra Integral hooks if supported on this chain
    if is_algebra_integral_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying Algebra Integral hooks (SparkDEX V4)...${NC}"

        if forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
            --sig 'runAlgebraIntegral(uint256,uint64)' $FORGE_ENV $network_id \
            --account $ACCOUNT \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url ${!rpc_var} \
            --chain $network_id \
            --etherscan-api-key $ETHERSCANV2_API_KEY \
            --verifier etherscan \
            $BROADCAST_FLAG \
            $VERIFY_FLAG \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv; then
            echo -e "${GREEN}   ✅ Algebra Integral hooks deployment completed!${NC}"
        else
            echo -e "${RED}   ❌ Algebra Integral hooks deployment failed on $network_name, continuing...${NC}"
        fi
    fi

    # Deploy DETH hooks if supported on this chain
    if is_deth_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying DETH hooks...${NC}"

        if forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
            --sig 'runDETH(uint256,uint64)' $FORGE_ENV $network_id \
            --account $ACCOUNT \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url ${!rpc_var} \
            --chain $network_id \
            --etherscan-api-key $ETHERSCANV2_API_KEY \
            --verifier etherscan \
            $BROADCAST_FLAG \
            $VERIFY_FLAG \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv; then
            echo -e "${GREEN}   ✅ DETH hooks deployment completed!${NC}"
        else
            echo -e "${RED}   ❌ DETH hooks deployment failed on $network_name, continuing...${NC}"
        fi
    fi

    # Deploy rFLR hooks if supported on this chain
    if is_rflr_supported "$network_id"; then
        has_hooks=true
        echo -e "${CYAN}   Chain ID: ${WHITE}$network_id${NC}"
        echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
        echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"
        echo -e "${YELLOW}   Deploying rFLR hooks...${NC}"

        if forge script script/DeployV2OtherHooks.s.sol:DeployV2OtherHooks \
            --sig 'runRFLR(uint256,uint64)' $FORGE_ENV $network_id \
            --account $ACCOUNT \
            $KEYSTORE_PASSWORD_FLAG \
            --rpc-url ${!rpc_var} \
            --chain $network_id \
            --etherscan-api-key $ETHERSCANV2_API_KEY \
            --verifier etherscan \
            $BROADCAST_FLAG \
            $VERIFY_FLAG \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $RESUME_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG \
            --timeout 300 \
            -vv; then
            echo -e "${GREEN}   ✅ rFLR hooks deployment completed!${NC}"
        else
            echo -e "${RED}   ❌ rFLR hooks deployment failed on $network_name, continuing...${NC}"
        fi
    fi

    if [ "$has_hooks" = false ]; then
        echo -e "${YELLOW}  ⏭️  No supported hooks for $network_name ($network_id), skipping${NC}"
        continue
    fi

    deployed_networks=$((deployed_networks + 1))
    echo ""
done

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}     🎉 Other Hooks $ENVIRONMENT $MODE Completed ($deployed_networks networks) 🎉                  ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
