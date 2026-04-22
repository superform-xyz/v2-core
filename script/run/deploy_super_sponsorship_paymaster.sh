#!/usr/bin/env bash

###################################################################################
# Deploy SuperSponsorshipPaymaster
###################################################################################
# Description:
#   Deploys SuperSponsorshipPaymaster to one or more chains using deterministic
#   CREATE2 deployment via the Foundry script.
#
# Usage:
#   ./script/run/deploy_super_sponsorship_paymaster.sh <env> <chain_id> [branch_name]
#   ./script/run/deploy_super_sponsorship_paymaster.sh check <env> <chain_id> [branch_name]
#
# Arguments:
#   env          - Environment: 0 (prod), 1 (vnet), 2 (staging)
#   chain_id     - Chain ID to deploy on (e.g. 1, 8453, 42161)
#   branch_name  - Required for vnet (env=1), ignored otherwise
#
# Examples:
#   # Deploy to Base staging
#   ./script/run/deploy_super_sponsorship_paymaster.sh 2 8453
#
#   # Deploy to Ethereum production
#   ./script/run/deploy_super_sponsorship_paymaster.sh 0 1
#
#   # Deploy to vnet
#   ./script/run/deploy_super_sponsorship_paymaster.sh 1 8453 my-branch
#
#   # Check deployment status on Base staging
#   ./script/run/deploy_super_sponsorship_paymaster.sh check 2 8453
#
# Requirements:
#   - forge: Foundry CLI
#   - Bytecode must exist in locked-bytecode/ (prod) or locked-bytecode-dev/ (staging/vnet)
#   - Run regenerate_bytecode.sh first if bytecode is missing
#
###################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

# Ensure we're in the right directory
if [ ! -f "foundry.toml" ]; then
    log "ERROR" "${RED}foundry.toml not found. Please run from the v2-core root directory.${NC}"
    exit 1
fi

# Parse arguments
MODE="deploy"
if [ "${1:-}" = "check" ]; then
    MODE="check"
    shift
fi

ENV="${1:?Usage: $0 [check] <env> <chain_id> [branch_name]}"
CHAIN_ID="${2:?Usage: $0 [check] <env> <chain_id> [branch_name]}"
BRANCH_NAME="${3:-}"

# Validate env
if [[ "$ENV" != "0" && "$ENV" != "1" && "$ENV" != "2" ]]; then
    log "ERROR" "${RED}Invalid env: $ENV. Must be 0 (prod), 1 (vnet), or 2 (staging).${NC}"
    exit 1
fi

# Validate branch_name for vnet
if [[ "$ENV" == "1" && -z "$BRANCH_NAME" ]]; then
    log "ERROR" "${RED}branch_name is required for vnet (env=1).${NC}"
    exit 1
fi

# Set RPC URL based on chain ID
get_rpc_env_var() {
    case $1 in
        1)     echo "ETHEREUM_RPC_URL" ;;
        8453)  echo "BASE_RPC_URL" ;;
        10)    echo "OPTIMISM_RPC_URL" ;;
        42161) echo "ARBITRUM_RPC_URL" ;;
        56)    echo "BNB_RPC_URL" ;;
        137)   echo "POLYGON_RPC_URL" ;;
        43114) echo "AVALANCHE_RPC_URL" ;;
        130)   echo "UNICHAIN_RPC_URL" ;;
        59144) echo "LINEA_RPC_URL" ;;
        80094) echo "BERACHAIN_RPC_URL" ;;
        146)   echo "SONIC_RPC_URL" ;;
        100)   echo "GNOSIS_RPC_URL" ;;
        480)   echo "WORLDCHAIN_RPC_URL" ;;
        *)     echo "" ;;
    esac
}

RPC_ENV_VAR=$(get_rpc_env_var "$CHAIN_ID")
if [ -z "$RPC_ENV_VAR" ]; then
    log "ERROR" "${RED}Unsupported chain ID: $CHAIN_ID${NC}"
    exit 1
fi

RPC_URL="${!RPC_ENV_VAR:-}"
if [ -z "$RPC_URL" ]; then
    log "ERROR" "${RED}RPC URL not set. Please set $RPC_ENV_VAR environment variable.${NC}"
    exit 1
fi

# Check bytecode availability
BYTECODE_DIR="script/locked-bytecode"
if [[ "$ENV" != "0" ]]; then
    BYTECODE_DIR="script/locked-bytecode-dev"
fi

if [ ! -f "${BYTECODE_DIR}/SuperSponsorshipPaymaster.json" ]; then
    log "WARN" "${YELLOW}Bytecode not found at ${BYTECODE_DIR}/SuperSponsorshipPaymaster.json${NC}"
    log "WARN" "${YELLOW}Run: ./script/run/regenerate_bytecode.sh SuperSponsorshipPaymaster${NC}"

    # Try generated-bytecode as fallback
    if [ -f "script/generated-bytecode/SuperSponsorshipPaymaster.json" ]; then
        log "INFO" "${BLUE}Found in generated-bytecode, copying...${NC}"
        cp "script/generated-bytecode/SuperSponsorshipPaymaster.json" "${BYTECODE_DIR}/SuperSponsorshipPaymaster.json"
    else
        log "ERROR" "${RED}Cannot find bytecode. Build and regenerate first.${NC}"
        exit 1
    fi
fi

# Build script name
SCRIPT="script/DeploySuperSponsorshipPaymaster.s.sol:DeploySuperSponsorshipPaymaster"

log "INFO" "${BLUE}====== SuperSponsorshipPaymaster Deployment ======${NC}"
log "INFO" "Mode: $MODE"
log "INFO" "Environment: $ENV"
log "INFO" "Chain ID: $CHAIN_ID"
log "INFO" "RPC: $RPC_ENV_VAR"
if [ -n "$BRANCH_NAME" ]; then
    log "INFO" "Branch: $BRANCH_NAME"
fi
echo ""

if [ "$MODE" = "check" ]; then
    log "INFO" "${BLUE}Running deployment check...${NC}"
    forge script "$SCRIPT" \
        --sig "runCheck(uint256,uint64,string)" \
        "$ENV" "$CHAIN_ID" "$BRANCH_NAME" \
        --rpc-url "$RPC_URL" \
        -vvv
else
    log "INFO" "${BLUE}Running deployment (simulation first)...${NC}"

    # Simulate first
    forge script "$SCRIPT" \
        --sig "run(uint256,uint64,string)" \
        "$ENV" "$CHAIN_ID" "$BRANCH_NAME" \
        --rpc-url "$RPC_URL" \
        -vvv

    echo ""
    log "INFO" "${GREEN}Simulation succeeded.${NC}"
    echo ""
    read -p "Broadcast the transaction? (y/N): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "INFO" "${YELLOW}Broadcasting...${NC}"
        forge script "$SCRIPT" \
            --sig "run(uint256,uint64,string)" \
            "$ENV" "$CHAIN_ID" "$BRANCH_NAME" \
            --rpc-url "$RPC_URL" \
            --broadcast \
            -vvv

        log "INFO" "${GREEN}Deployment broadcast complete!${NC}"
    else
        log "INFO" "${YELLOW}Broadcast cancelled.${NC}"
    fi
fi
