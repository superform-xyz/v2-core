#!/usr/bin/env bash

###################################################################################
# Transfer SuperSponsorshipPaymaster Roles
###################################################################################
# Description:
#   Transfers SuperSponsorshipPaymaster roles from DEPLOYER to governance addresses
#   across all chains in the target environment. Reads the paymaster address from
#   script/output/<env>/<chainId>/<ChainName>-latest.json per chain.
#
#   Role mapping:
#     - FUNDING_ROLE       -> GOVERNOR        (0x9e01...48eC)
#     - DEFAULT_ADMIN_ROLE -> SUPER_GOVERNOR  (0x8922...ad2e)
#     - MANAGER_ROLE       -> SUPER_GOVERNOR  (0x8922...ad2e)
#   Then revokes all roles from DEPLOYER.
#
# Usage:
#   ./script/run/config/transfer_sponsorship_paymaster_roles.sh <environment> <mode> <account> [--slow] [--legacy] [--check-only]
#
# Arguments:
#   environment - staging or prod
#   mode        - simulate or execute
#   account     - Foundry keystore account name (e.g. v2, deployer)
#
# Optional Flags:
#   --slow       - Send transactions one at a time, waiting for confirmation
#   --legacy     - Use legacy transactions with 1 gwei gas price
#   --check-only - Only check role status, no transfers
#
# Examples:
#   # Simulate role transfer across all prod chains
#   ./script/run/config/transfer_sponsorship_paymaster_roles.sh prod simulate v2
#
#   # Execute role transfer on all prod chains
#   ./script/run/config/transfer_sponsorship_paymaster_roles.sh prod execute deployer
#
#   # Check current role status only
#   ./script/run/config/transfer_sponsorship_paymaster_roles.sh prod simulate v2 --check-only
#
# Requirements:
#   - forge: Foundry CLI
#   - op: 1Password CLI (authenticated)
#   - cast: For wallet management
#   - python3: For JSON parsing
#   - Paymaster must be deployed and address present in script/output/<env>/<chainId>/
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

print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${WHITE}      SuperSponsorshipPaymaster Role Transfer Script                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_separator() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_network_header() {
    local network=$1
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────────────────╮${NC}"
    echo -e "${CYAN}│${WHITE}  Transferring roles on ${network}${CYAN}│${NC}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────────────────╯${NC}"
}

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

print_header

# ===== ARGUMENT PARSING =====

if [ $# -lt 3 ]; then
    echo -e "${RED}Error: Missing required arguments${NC}"
    echo -e "${YELLOW}Usage: $0 <environment> <mode> <account> [--slow] [--legacy] [--check-only]${NC}"
    echo -e "${CYAN}  environment: staging or prod${NC}"
    echo -e "${CYAN}  mode:        simulate or execute${NC}"
    echo -e "${CYAN}  account:     foundry account name (e.g., v2, deployer)${NC}"
    echo -e "${CYAN}  --slow:       (optional) send transactions one at a time${NC}"
    echo -e "${CYAN}  --legacy:     (optional) use legacy transactions with 1 gwei gas price${NC}"
    echo -e "${CYAN}  --check-only: (optional) only check role status, no transfers${NC}"
    echo -e "${CYAN}Examples:${NC}"
    echo -e "${CYAN}  $0 prod simulate v2${NC}"
    echo -e "${CYAN}  $0 prod execute deployer${NC}"
    echo -e "${CYAN}  $0 prod simulate v2 --check-only${NC}"
    exit 1
fi

ENVIRONMENT=$1
MODE=$2
ACCOUNT=$3

# Parse optional flags
SLOW_FLAG=""
BATCH_SIZE_FLAG=""
LEGACY_FLAG=""
GAS_PRICE_FLAG=""
CHECK_ONLY=false
for arg in "${@:4}"; do
    case "$arg" in
        --slow)
            SLOW_FLAG="--slow"
            BATCH_SIZE_FLAG="--batch-size 1"
            echo -e "${YELLOW}Slow mode enabled: transactions sent one at a time${NC}"
            ;;
        --legacy)
            LEGACY_FLAG="--legacy"
            GAS_PRICE_FLAG="--with-gas-price 1gwei"
            echo -e "${YELLOW}Legacy mode enabled: using legacy transactions with 1 gwei gas price${NC}"
            ;;
        --check-only)
            CHECK_ONLY=true
            echo -e "${YELLOW}Check-only mode: will only display current role status${NC}"
            ;;
    esac
done

# ===== VALIDATE ENVIRONMENT =====

FORGE_ENV=""
OUTPUT_DIR=""

if [ "$ENVIRONMENT" = "staging" ]; then
    echo -e "${CYAN}Loading staging network configuration...${NC}"
    FORGE_ENV=2
    OUTPUT_DIR="$PROJECT_ROOT/script/output/staging"
    source "$SCRIPT_DIR/../utils/networks-staging.sh"
elif [ "$ENVIRONMENT" = "prod" ]; then
    echo -e "${CYAN}Loading production network configuration...${NC}"
    FORGE_ENV=0
    OUTPUT_DIR="$PROJECT_ROOT/script/output/prod"
    source "$SCRIPT_DIR/../utils/networks-production.sh"
else
    echo -e "${RED}Invalid environment: $ENVIRONMENT${NC}"
    echo -e "${YELLOW}Environment must be either 'staging' or 'prod'${NC}"
    exit 1
fi

echo -e "${CYAN}Network configuration loaded for $ENVIRONMENT${NC}"
print_network_info

# ===== VALIDATE MODE =====

BROADCAST_FLAG=""

if [ "$MODE" = "simulate" ]; then
    echo -e "${YELLOW}Running in simulation mode (dry run)${NC}"
elif [ "$MODE" = "execute" ]; then
    echo -e "${GREEN}Running in execution mode (will broadcast)${NC}"
    BROADCAST_FLAG="--broadcast"
else
    echo -e "${RED}Invalid mode: $MODE${NC}"
    echo -e "${YELLOW}Mode must be either 'simulate' or 'execute'${NC}"
    exit 1
fi

# ===== VALIDATE ACCOUNT =====

if ! cast wallet list 2>/dev/null | sed 's/ (Local)//' | grep -q "^$ACCOUNT$"; then
    echo -e "${RED}Account '$ACCOUNT' not found in foundry wallet list${NC}"
    echo -e "${YELLOW}Available accounts:${NC}"
    cast wallet list 2>/dev/null | sed 's/ (Local)//' | sed 's/^/  - /' || echo -e "${RED}  No accounts found.${NC}"
    exit 1
fi

# ===== RESOLVE PAYMASTER ADDRESSES PER CHAIN =====

print_separator
echo -e "${BLUE}Resolving paymaster addresses from ${OUTPUT_DIR}...${NC}"

# Helper: read SuperSponsorshipPaymaster address from chain's JSON output
get_paymaster_address() {
    local chain_id=$1
    local chain_dir="$OUTPUT_DIR/$chain_id"

    if [[ ! -d "$chain_dir" ]]; then
        return 1
    fi

    local json_file
    json_file=$(ls "$chain_dir"/*-latest.json 2>/dev/null | head -1)
    if [[ -z "$json_file" ]]; then
        return 1
    fi

    local addr
    addr=$(python3 -c "
import json, sys
try:
    d = json.load(open('$json_file'))
    v = d.get('SuperSponsorshipPaymaster', '')
    if v and v.startswith('0x') and len(v) == 42:
        print(v)
    else:
        sys.exit(1)
except:
    sys.exit(1)
" 2>/dev/null) || return 1

    echo "$addr"
}

# Only target chains where SuperSponsorshipPaymaster is deployed
TARGET_CHAINS="1 8453 999 14"  # Ethereum, Base, HyperEVM, Flare

declare -A CHAIN_PAYMASTER
chains_found=0
chains_missing=0

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name _ <<< "$network_def"

    # Skip chains not in our target list
    if ! echo "$TARGET_CHAINS" | grep -qw "$network_id"; then
        continue
    fi

    addr=$(get_paymaster_address "$network_id" 2>/dev/null) || addr=""
    if [[ -n "$addr" ]]; then
        CHAIN_PAYMASTER["$network_id"]="$addr"
        echo -e "${GREEN}  $network_name ($network_id): $addr${NC}"
        chains_found=$((chains_found + 1))
    else
        echo -e "${YELLOW}  $network_name ($network_id): not found - skipping${NC}"
        chains_missing=$((chains_missing + 1))
    fi
done

echo ""
echo -e "${BLUE}Found: $chains_found chains | Missing: $chains_missing chains${NC}"

if [[ $chains_found -eq 0 ]]; then
    echo -e "${RED}No paymaster addresses found. Nothing to do.${NC}"
    exit 1
fi

print_separator
echo -e "${BLUE}Configuration:${NC}"
echo -e "${CYAN}  Environment:  ${WHITE}$ENVIRONMENT${NC}"
echo -e "${CYAN}  Mode:         ${WHITE}$MODE${NC}"
echo -e "${CYAN}  Account:      ${WHITE}$ACCOUNT${NC}"
echo -e "${CYAN}  Check-only:   ${WHITE}$CHECK_ONLY${NC}"
echo -e "${CYAN}  Chains:       ${WHITE}$chains_found${NC}"
echo ""

# ===== LOAD CREDENTIALS FROM 1PASSWORD =====

print_separator
echo -e "${BLUE}Loading Configuration...${NC}"

echo -e "${CYAN}   Loading RPC URLs from 1Password...${NC}"
if ! load_rpc_urls; then
    echo -e "${RED}Failed to load some RPC URLs from 1Password${NC}"
fi

echo -e "${GREEN}Configuration loaded${NC}"

# ===== SET ENVIRONMENT VARIABLES =====

export CI=true
export GITHUB_REF_NAME="$ENVIRONMENT"
export SUPERFORM_PROJECT_ROOT="$PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Forge script path
SCRIPT="script/TransferSuperSponsorshipPaymasterRoles.s.sol:TransferSuperSponsorshipPaymasterRoles"

# Determine which sig to use
if [ "$CHECK_ONLY" = true ]; then
    FORGE_SIG="runCheck(uint256,address)"
else
    FORGE_SIG="run(uint256,address)"
fi

# ===== PROMPT FOR KEYSTORE PASSWORD =====

if [ "$CHECK_ONLY" = false ]; then
    echo -e "${WHITE}Enter keystore password for account '$ACCOUNT' (used for all chains):${NC}"
    read -s -p "" KEYSTORE_PASSWORD
    echo ""

    if [[ -z "$KEYSTORE_PASSWORD" ]]; then
        echo -e "${RED}Error: Empty password provided${NC}"
        exit 1
    fi

    if ! cast wallet address --account "$ACCOUNT" --password "$KEYSTORE_PASSWORD" &>/dev/null; then
        echo -e "${RED}Error: Invalid password for account '$ACCOUNT'${NC}"
        exit 1
    fi
    echo -e "${GREEN}Keystore password verified${NC}"

    trap 'unset KEYSTORE_PASSWORD' EXIT
fi

# ===== CONFIRM EXECUTION =====

if [ "$MODE" = "execute" ] && [ "$CHECK_ONLY" = false ]; then
    print_separator
    echo -e "${WHITE}This will transfer SuperSponsorshipPaymaster roles on $chains_found $ENVIRONMENT chain(s).${NC}"
    echo -e "${WHITE}  FUNDING_ROLE       -> GOVERNOR       (0x9e01f41da2212C1FBc32A041CfAEF72479FA48eC)${NC}"
    echo -e "${WHITE}  DEFAULT_ADMIN_ROLE -> SUPER_GOVERNOR (0x89226a5Fd572f380991Bb17c20c96ba91F98aD2e)${NC}"
    echo -e "${WHITE}  MANAGER_ROLE       -> SUPER_GOVERNOR (0x89226a5Fd572f380991Bb17c20c96ba91F98aD2e)${NC}"
    echo -e "${WHITE}  All roles revoked from DEPLOYER${NC}"
    echo ""
    echo -e "${WHITE}Proceed? (y/n): ${NC}"
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}Transfer cancelled by user${NC}"
        exit 0
    fi
fi

# ===== EXECUTE ON ALL CHAINS =====

print_separator
success_count=0
skipped_count=0
failed_count=0

for network_def in "${NETWORKS[@]}"; do
    IFS=':' read -r network_id network_name rpc_var <<< "$network_def"

    # Skip if no paymaster address found for this chain
    paymaster_addr="${CHAIN_PAYMASTER[$network_id]:-}"
    if [[ -z "$paymaster_addr" ]]; then
        echo -e "${YELLOW}Skipping $network_name ($network_id) - no paymaster address in output${NC}"
        skipped_count=$((skipped_count + 1))
        continue
    fi

    # Skip if RPC not available
    if [[ -z "${!rpc_var:-}" ]]; then
        echo -e "${RED}Skipping $network_name ($network_id) - no RPC URL${NC}"
        failed_count=$((failed_count + 1))
        continue
    fi

    print_network_header "$network_name ($network_id) @ $paymaster_addr"

    # Build forge command
    FORGE_CMD="forge script $SCRIPT \
        --sig \"$FORGE_SIG\" \
        $FORGE_ENV $paymaster_addr \
        --rpc-url ${!rpc_var} \
        --chain $network_id"

    if [ "$CHECK_ONLY" = false ]; then
        FORGE_CMD="$FORGE_CMD \
            --account $ACCOUNT \
            --password $KEYSTORE_PASSWORD \
            $BROADCAST_FLAG \
            $SLOW_FLAG \
            $BATCH_SIZE_FLAG \
            $LEGACY_FLAG \
            $GAS_PRICE_FLAG"
    fi

    FORGE_CMD="$FORGE_CMD --timeout 300 -vv"

    echo -e "${YELLOW}   Executing forge script...${NC}"

    if eval "$FORGE_CMD"; then
        echo -e "${GREEN}$network_name completed successfully${NC}"
        success_count=$((success_count + 1))
    else
        echo -e "${RED}$network_name FAILED${NC}"
        failed_count=$((failed_count + 1))
    fi
    echo ""
done

# ===== SUMMARY =====

print_separator
echo -e "${BLUE}Summary:${NC}"
echo -e "${GREEN}   Succeeded: $success_count${NC}"
if [[ $skipped_count -gt 0 ]]; then
    echo -e "${YELLOW}   Skipped:   $skipped_count${NC}"
fi
if [[ $failed_count -gt 0 ]]; then
    echo -e "${RED}   Failed:    $failed_count${NC}"
fi

print_separator
if [ "$CHECK_ONLY" = true ]; then
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}    SuperSponsorshipPaymaster $ENVIRONMENT Role Check Complete!                   ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${WHITE}    SuperSponsorshipPaymaster $ENVIRONMENT Role Transfer $MODE Complete!           ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
fi
