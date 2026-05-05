#!/usr/bin/env bash

###################################################################################
# Deploy SuperSponsorshipPaymaster
###################################################################################
# Description:
#   Deploys SuperSponsorshipPaymaster across all chains in the target environment
#   using deterministic CREATE2 deployment. Loads RPC URLs and API keys from
#   1Password, uses Foundry keystore for signing. Skips chains where the
#   paymaster is already deployed.
#
# Usage:
#   ./script/run/deploy_super_sponsorship_paymaster.sh <environment> <mode> <account> [--slow] [--resume] [--legacy]
#
# Arguments:
#   environment  - staging or prod
#   mode         - simulate or deploy
#   account      - Foundry keystore account name (e.g. v2, deployer, main)
#
# Optional Flags:
#   --slow       - Send transactions one at a time, waiting for confirmation
#   --resume     - Resume from previous broadcast (use after interruption)
#   --legacy     - Use legacy transactions with 1 gwei gas price
#
# Examples:
#   # Simulate deployment across all staging chains
#   ./script/run/deploy_super_sponsorship_paymaster.sh staging simulate v2
#
#   # Deploy to all production chains
#   ./script/run/deploy_super_sponsorship_paymaster.sh prod deploy deployer
#
#   # Deploy with slow mode
#   ./script/run/deploy_super_sponsorship_paymaster.sh prod deploy deployer --slow
#
#   # Resume interrupted deployment
#   ./script/run/deploy_super_sponsorship_paymaster.sh prod deploy deployer --resume
#
# Requirements:
#   - forge: Foundry CLI
#   - op: 1Password CLI (authenticated)
#   - cast: For wallet management
#   - Bytecode must exist in locked-bytecode/ (prod) or locked-bytecode-dev/ (staging)
#   - Run regenerate_bytecode.sh first if bytecode is missing
#
###################################################################################

set -eo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}          SuperSponsorshipPaymaster Deployment Script                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_network_header() {
    local network=$1
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${WHITE}                    Deploying to ${network}                                       ${CYAN}│${NC}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

print_header

# ===== ARGUMENT PARSING =====

if [ $# -lt 3 ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode> <account> [--slow] [--resume] [--legacy]${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode: simulate or deploy${NC}"
    echo -e "${CYAN}  account: foundry account name (e.g., v2, deployer, main)${NC}"
    echo -e "${CYAN}  --slow: (optional) send transactions one at a time${NC}"
    echo -e "${CYAN}  --resume: (optional) resume from previous broadcast${NC}"
    echo -e "${CYAN}  --legacy: (optional) use legacy transactions with 1 gwei gas price${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 staging simulate v2${NC}"
    echo -e "${CYAN}  $0 prod deploy deployer${NC}"
    echo -e "${CYAN}  $0 prod deploy deployer --slow${NC}"
    echo -e "${CYAN}Available accounts: $(cast wallet list 2>/dev/null | sed 's/ (Local)//' | tr '\n' ' ' || echo 'Run "cast wallet list" to see available accounts')${NC}"
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
            echo -e "${YELLOW}Slow mode enabled: transactions sent one at a time${NC}"
            ;;
        --resume)
            RESUME_FLAG="--resume"
            echo -e "${YELLOW}Resume mode enabled: continuing from previous broadcast${NC}"
            ;;
        --legacy)
            LEGACY_FLAG="--legacy"
            GAS_PRICE_FLAG="--with-gas-price 1gwei"
            echo -e "${YELLOW}Legacy mode enabled: using legacy transactions with 1 gwei gas price${NC}"
            ;;
    esac
done

# ===== VALIDATE ENVIRONMENT =====

LOCKED_BYTECODE_PATH=""
FORGE_ENV=""

if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}Loading staging network configuration...${NC}"
    LOCKED_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode-dev"
    FORGE_ENV=2
    source "$SCRIPT_DIR/networks-staging.sh"
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}Loading production network configuration...${NC}"
    LOCKED_BYTECODE_PATH="$PROJECT_ROOT/script/locked-bytecode"
    FORGE_ENV=0
    source "$SCRIPT_DIR/networks-production.sh"
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

# Validate locked bytecode directory
if [[ ! -d "$LOCKED_BYTECODE_PATH" ]]; then
    echo -e "${RED}Error: Locked bytecode directory does not exist: $LOCKED_BYTECODE_PATH${NC}"
    exit 1
fi

echo -e "${CYAN}Network configuration loaded for $ENVIRONMENT${NC}"
print_network_info

# ===== VALIDATE MODE =====

BROADCAST_FLAG=""
VERIFY_FLAG=""

if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}Running in simulation mode (dry run)${NC}"
elif [ "$MODE" = "deploy" ]; then
    echo -e "${GREEN}Running in deployment mode (will broadcast)${NC}"
    BROADCAST_FLAG="--broadcast"
    VERIFY_FLAG="--verify"
else
    echo -e "${RED}Invalid mode: $MODE${NC}"
    echo -e "${YELLOW}Mode must be either 'simulate' or 'deploy'${NC}"
    exit 1
fi

# ===== VALIDATE ACCOUNT =====

if ! cast wallet list 2>/dev/null | sed 's/ (Local)//' | grep -q "^$ACCOUNT$"; then
    echo -e "${RED}Account '$ACCOUNT' not found in foundry wallet list${NC}"
    echo -e "${YELLOW}Available accounts:${NC}"
    cast wallet list 2>/dev/null | sed 's/ (Local)//' | sed 's/^/  • /' || echo -e "${RED}  No accounts found. Run 'cast wallet import' to add accounts.${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}Loading Configuration...${NC}"

# ===== LOAD CREDENTIALS FROM 1PASSWORD =====

echo -e "${CYAN}   Loading RPC URLs from 1Password...${NC}"
if ! load_rpc_urls; then
    echo -e "${RED}Failed to load some RPC URLs from 1Password${NC}"
    echo -e "${YELLOW}Ensure credentials are configured in the 1Password vault${NC}"
    # Continue - individual chain checks will catch failures
fi

echo -e "${CYAN}   Loading Etherscan V2 API key...${NC}"
if ! load_etherscan_api_key; then
    echo -e "${RED}Failed to load Etherscan V2 API key${NC}"
    echo -e "${RED}Contract verification will not work without this credential${NC}"
    exit 1
fi

echo -e "${GREEN}Configuration loaded successfully${NC}"

# ===== CHECK BYTECODE =====

print_separator
echo -e "${BLUE}Checking bytecode availability...${NC}"

if [ ! -f "${LOCKED_BYTECODE_PATH}/SuperSponsorshipPaymaster.json" ]; then
    echo -e "${YELLOW}Bytecode not found at ${LOCKED_BYTECODE_PATH}/SuperSponsorshipPaymaster.json${NC}"

    # Try generated-bytecode as fallback
    if [ -f "$PROJECT_ROOT/script/generated-bytecode/SuperSponsorshipPaymaster.json" ]; then
        echo -e "${CYAN}Found in generated-bytecode, copying...${NC}"
        cp "$PROJECT_ROOT/script/generated-bytecode/SuperSponsorshipPaymaster.json" "${LOCKED_BYTECODE_PATH}/SuperSponsorshipPaymaster.json"
    else
        echo -e "${RED}Cannot find bytecode. Run: ./script/run/regenerate_bytecode.sh SuperSponsorshipPaymaster${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Bytecode available${NC}"

# ===== SET ENVIRONMENT VARIABLES =====

export CI=true
export GITHUB_REF_NAME="$ENVIRONMENT"
export SUPERFORM_PROJECT_ROOT="$PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Create output directories
for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id _ _ <<< "$network_def"
    mkdir -p "$PROJECT_ROOT/script/output/$ENVIRONMENT/$network_id"
done

# Forge script path
SCRIPT="script/DeploySuperSponsorshipPaymaster.s.sol:DeploySuperSponsorshipPaymaster"

# ===== CHECK DEPLOYMENT STATUS ACROSS ALL CHAINS =====

print_separator
echo -e "${BLUE}Checking deployment status across all $ENVIRONMENT networks...${NC}"
echo ""

declare -A CHAIN_DEPLOYED
declare -a NEEDS_DEPLOY=()
declare -a ALREADY_DEPLOYED=()
declare -a CHECK_FAILED=()

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var <<< "$network_def"

    echo -e "${CYAN}Checking $network_name (Chain $network_id)...${NC}"

    # Verify RPC is available
    if [[ -z "${!rpc_var:-}" ]]; then
        echo -e "${RED}  RPC URL not set ($rpc_var) - skipping${NC}"
        CHECK_FAILED+=("$network_name ($network_id)")
        continue
    fi

    check_output=$(forge script "$SCRIPT" \
        --sig "runCheck(uint256,uint64,string)" \
        "$FORGE_ENV" "$network_id" "" \
        --rpc-url "${!rpc_var}" \
        --chain "$network_id" \
        -vv 2>&1) || true

    if echo "$check_output" | grep -q "Is deployed: true"; then
        echo -e "${GREEN}  Already deployed${NC}"
        CHAIN_DEPLOYED["$network_id"]=true
        ALREADY_DEPLOYED+=("$network_name ($network_id)")
    else
        echo -e "${YELLOW}  Not yet deployed${NC}"
        CHAIN_DEPLOYED["$network_id"]=false
        NEEDS_DEPLOY+=("$network_name ($network_id)")
    fi
done

echo ""
print_separator

# ===== DEPLOYMENT STATUS SUMMARY =====

echo -e "${BLUE}Deployment Status Summary:${NC}"
echo -e "${GREEN}   Already deployed: ${#ALREADY_DEPLOYED[@]}${NC}"
for item in "${ALREADY_DEPLOYED[@]}"; do
    echo -e "${GREEN}     - $item${NC}"
done
echo -e "${YELLOW}   Needs deployment: ${#NEEDS_DEPLOY[@]}${NC}"
for item in "${NEEDS_DEPLOY[@]}"; do
    echo -e "${YELLOW}     - $item${NC}"
done
if [[ ${#CHECK_FAILED[@]} -gt 0 ]]; then
    echo -e "${RED}   Check failed: ${#CHECK_FAILED[@]}${NC}"
    for item in "${CHECK_FAILED[@]}"; do
        echo -e "${RED}     - $item${NC}"
    done
fi
echo ""

# Exit if everything is deployed
if [[ ${#NEEDS_DEPLOY[@]} -eq 0 ]]; then
    echo -e "${GREEN}All chains already have SuperSponsorshipPaymaster deployed! Nothing to do.${NC}"
    exit 0
fi

# ===== PROMPT FOR KEYSTORE PASSWORD =====

echo -e "${WHITE}Enter keystore password for account '$ACCOUNT' (used for all chains):${NC}"
read -s -p "" KEYSTORE_PASSWORD
echo ""

if [[ -z "$KEYSTORE_PASSWORD" ]]; then
    echo -e "${RED}Error: Empty password provided${NC}"
    exit 1
fi

# Verify the password works
if ! cast wallet address --account "$ACCOUNT" --password "$KEYSTORE_PASSWORD" &>/dev/null; then
    echo -e "${RED}Error: Invalid password for account '$ACCOUNT'${NC}"
    exit 1
fi
echo -e "${GREEN}Keystore password verified${NC}"

# Clean up password on exit
trap 'unset KEYSTORE_PASSWORD' EXIT

# ===== CONFIRM DEPLOYMENT =====

if [ "$MODE" = "deploy" ]; then
    print_separator
    echo -e "${WHITE}Proceed with deploying to ${#NEEDS_DEPLOY[@]} chain(s)? (y/n): ${NC}"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Deployment cancelled by user${NC}"
        exit 0
    fi
fi

# ===== DEPLOY TO ALL CHAINS =====

print_separator
deployed_count=0
skipped_count=0
failed_count=0

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var <<< "$network_def"

    # Skip already deployed
    local_deployed="${CHAIN_DEPLOYED[$network_id]+${CHAIN_DEPLOYED[$network_id]}}"
    if [[ "$local_deployed" == "true" ]]; then
        echo -e "${GREEN}Skipping $network_name ($network_id) - already deployed${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # Skip if RPC not available
    if [[ -z "${!rpc_var:-}" ]]; then
        echo -e "${RED}Skipping $network_name ($network_id) - no RPC URL${NC}"
        failed_count=$((failed_count + 1))
        continue
    fi

    print_network_header "$network_name ($network_id)"
    echo -e "${CYAN}   Mode: ${WHITE}$MODE${NC}"
    echo -e "${CYAN}   Account: ${WHITE}$ACCOUNT${NC}"

    # Per-chain verification flags
    local_verify_flag="$VERIFY_FLAG"
    local_etherscan_flags=""
    case $network_id in
        14|999) # Flare, HyperEVM - aggressive rate limiting
            local_verify_flag=""
            echo -e "${CYAN}   Verification: ${WHITE}Skipped (rate-limited explorer)${NC}"
            ;;
        *)
            if [[ -n "$VERIFY_FLAG" ]]; then
                local_etherscan_flags="--etherscan-api-key $ETHERSCANV2_API_KEY --verifier etherscan"
            fi
            echo -e "${CYAN}   Verification: ${WHITE}Etherscan V2${NC}"
            ;;
    esac

    echo -e "${YELLOW}   Executing forge script...${NC}"

    if forge script "$SCRIPT" \
        --sig "run(uint256,uint64,string)" \
        "$FORGE_ENV" "$network_id" "" \
        --account "$ACCOUNT" \
        --password "$KEYSTORE_PASSWORD" \
        --rpc-url "${!rpc_var}" \
        --chain "$network_id" \
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
        echo -e "${GREEN}$network_name deployment completed successfully${NC}"
        deployed_count=$((deployed_count + 1))
    else
        echo -e "${RED}$network_name deployment FAILED${NC}"
        failed_count=$((failed_count + 1))
    fi
    echo ""
done

# ===== SUMMARY =====

print_separator
echo -e "${BLUE}Deployment Summary:${NC}"
echo -e "${GREEN}   Deployed: $deployed_count${NC}"
echo -e "${YELLOW}   Skipped (already deployed): $skipped_count${NC}"
if [[ $failed_count -gt 0 ]]; then
    echo -e "${RED}   Failed: $failed_count${NC}"
fi

print_separator
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${WHITE}    SuperSponsorshipPaymaster $ENVIRONMENT $MODE Complete!                          ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
