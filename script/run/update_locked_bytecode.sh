#!/bin/bash

###################################################################################
# Update Locked Bytecode Script
###################################################################################
# Description:
#   This script updates the locked-bytecode folder with the latest compiled
#   artifacts for core V2 contracts, hooks, and oracles that require deterministic
#   deployment addresses.
#
# Usage:
#   ./script/update_locked_bytecode.sh
#
# Requirements:
#   - forge: For contract compilation
#   - jq: For JSON processing (optional, for validation)
#
# Author: Superform Team
###################################################################################

set -euo pipefail  # Exit on error, undefined var, pipe failure

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
}

log "INFO" "${BLUE}🔧 Updating Locked Bytecode for V2 Core Contracts${NC}"

# Ensure we're in the right directory
if [ ! -f "foundry.toml" ]; then
    log "ERROR" "${RED}foundry.toml not found. Please run this script from the v2-core root directory.${NC}"
    exit 1
fi

# Build contracts
log "INFO" "${YELLOW}📦 Building contracts...${NC}"
if ! forge build; then
    log "ERROR" "${RED}Failed to build contracts${NC}"
    exit 1
fi

# Create locked-bytecode directory if it doesn't exist
mkdir -p script/locked-bytecode

log "INFO" "${BLUE}📋 Copying core contract artifacts...${NC}"

# Define arrays of contracts to copy
# Core contracts from specified directories
CORE_CONTRACTS=(
    "SuperExecutor"
    "SuperDestinationExecutor" 
    "SuperSenderCreator"
    "AcrossV3Adapter"
    "DebridgeAdapter"
    "SuperLedger"
    "FlatFeeLedger"
    "SuperLedgerConfiguration"
    "SuperValidator"
    "SuperDestinationValidator"
    "SuperNativePaymaster"
)

# Hook contracts from specified directories
HOOK_CONTRACTS=(
    "ApproveERC20Hook"
    "TransferERC20Hook"
    "BatchTransferHook"
    "BatchTransferFromHook"
    "Deposit4626VaultHook"
    "ApproveAndDeposit4626VaultHook"
    "Redeem4626VaultHook"
    "Deposit5115VaultHook"
    "ApproveAndDeposit5115VaultHook"
    "Redeem5115VaultHook"
    "RequestDeposit7540VaultHook"
    "ApproveAndRequestDeposit7540VaultHook"
    "ApproveAndRequestRedeem7540VaultHook"
    "Redeem7540VaultHook"
    "RequestRedeem7540VaultHook"
    "Deposit7540VaultHook"
    "Withdraw7540VaultHook"
    "CancelDepositRequest7540Hook"
    "CancelRedeemRequest7540Hook"
    "ClaimCancelDepositRequest7540Hook"
    "ClaimCancelRedeemRequest7540Hook"
    "Swap1InchHook"
    "SwapOdosV2Hook"
    "ApproveAndSwapOdosV2Hook"
    "AcrossSendFundsAndExecuteOnDstHook"
    "DeBridgeSendOrderAndExecuteOnDstHook"
    "DeBridgeCancelOrderHook"
    "EthenaCooldownSharesHook"
    "EthenaUnstakeHook"
    "CancelRedeemHook"
    "OfframpTokensHook"
    "MintSuperPositionsHook"
    "MarkRootAsUsedHook"
)

# Oracle contracts from accounting/oracles
ORACLE_CONTRACTS=(
    "ERC4626YieldSourceOracle"
    "ERC5115YieldSourceOracle"
    "ERC7540YieldSourceOracle"
    "PendlePTYieldSourceOracle"
    "SpectraPTYieldSourceOracle"
    "StakingYieldSourceOracle"
    "SuperYieldSourceOracle"
)

# Function to copy contract artifact
copy_contract() {
    local contract_name=$1
    local source_path
    local dest_path="script/locked-bytecode/${contract_name}.json"
    
    # Find the contract artifact - correct pattern for Foundry structure
    source_path="out/${contract_name}.sol/${contract_name}.json"
    
    if [ ! -f "$source_path" ]; then
        log "ERROR" "${RED}❌ Artifact not found for contract: ${contract_name} at ${source_path}${NC}"
        return 1
    fi
    
    # Copy the artifact
    cp "$source_path" "$dest_path"
    log "INFO" "${GREEN}✅ Copied ${contract_name}${NC}"
    
    return 0
}

# Copy all core contracts
log "INFO" "${BLUE}📦 Copying core contracts...${NC}"
failed_core=0
for contract in "${CORE_CONTRACTS[@]}"; do
    if ! copy_contract "$contract"; then
        failed_core=$((failed_core + 1))
    fi
done

# Copy all hook contracts
log "INFO" "${BLUE}🪝 Copying hook contracts...${NC}"
failed_hooks=0
for contract in "${HOOK_CONTRACTS[@]}"; do
    if ! copy_contract "$contract"; then
        failed_hooks=$((failed_hooks + 1))
    fi
done

# Copy all oracle contracts
log "INFO" "${BLUE}🔮 Copying oracle contracts...${NC}"
failed_oracles=0
for contract in "${ORACLE_CONTRACTS[@]}"; do
    if ! copy_contract "$contract"; then
        failed_oracles=$((failed_oracles + 1))
    fi
done

# Summary
total_contracts=$((${#CORE_CONTRACTS[@]} + ${#HOOK_CONTRACTS[@]} + ${#ORACLE_CONTRACTS[@]}))
total_failed=$((failed_core + failed_hooks + failed_oracles))
total_success=$((total_contracts - total_failed))

log "INFO" "${BLUE}📊 Summary:${NC}"
log "INFO" "${GREEN}  ✅ Successfully copied: ${total_success}/${total_contracts} contracts${NC}"

if [ $failed_core -gt 0 ]; then
    log "WARN" "${YELLOW}  ⚠️  Failed core contracts: ${failed_core}/${#CORE_CONTRACTS[@]}${NC}"
fi

if [ $failed_hooks -gt 0 ]; then
    log "WARN" "${YELLOW}  ⚠️  Failed hook contracts: ${failed_hooks}/${#HOOK_CONTRACTS[@]}${NC}"
fi

if [ $failed_oracles -gt 0 ]; then
    log "WARN" "${YELLOW}  ⚠️  Failed oracle contracts: ${failed_oracles}/${#ORACLE_CONTRACTS[@]}${NC}"
fi

if [ $total_failed -eq 0 ]; then
    log "INFO" "${GREEN}🎉 All contracts successfully updated in locked-bytecode!${NC}"
    exit 0
else
    log "ERROR" "${RED}❌ ${total_failed} contracts failed to copy. Please check the error messages above.${NC}"
    exit 1
fi 