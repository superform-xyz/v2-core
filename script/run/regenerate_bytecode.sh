#!/usr/bin/env bash

###################################################################################
# Regenerate Bytecode Script
###################################################################################
# Description:
#   This script regenerates bytecode artifacts for core V2 contracts, hooks, and 
#   oracles by copying from compiled outputs to generated-bytecode folder for 
#   VNET deployments.
#
# Usage:
#   ./script/run/regenerate_bytecode.sh [CONTRACT_NAME]
#
# Arguments:
#   CONTRACT_NAME (optional): Name of specific contract to regenerate.
#                            If provided, must exist in out/ folder.
#                            If omitted, regenerates all contracts.
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

# Parse command line arguments
CONTRACT_NAME=""
if [ $# -gt 0 ]; then
    CONTRACT_NAME="$1"
    log "INFO" "${BLUE}🔧 Regenerating Bytecode for Contract: ${CONTRACT_NAME}${NC}"
else
    log "INFO" "${BLUE}🔧 Regenerating Bytecode for All V2 Core Contracts${NC}"
fi

# Ensure we're in the right directory
if [ ! -f "foundry.toml" ]; then
    log "ERROR" "${RED}foundry.toml not found. Please run this script from the v2-core root directory.${NC}"
    exit 1
fi

# If specific contract is requested, validate it exists in out folder
if [ -n "$CONTRACT_NAME" ]; then
    CONTRACT_PATH="out/${CONTRACT_NAME}.sol/${CONTRACT_NAME}.json"
    if [ ! -f "$CONTRACT_PATH" ]; then
        log "ERROR" "${RED}Contract '${CONTRACT_NAME}' not found at ${CONTRACT_PATH}${NC}"
        log "ERROR" "${RED}Please ensure the contract exists and has been compiled.${NC}"
        exit 1
    fi
    log "INFO" "${GREEN}✅ Contract '${CONTRACT_NAME}' found in out folder${NC}"
fi

# Build contracts
log "INFO" "${YELLOW}📦 Building contracts...${NC}"
if ! forge build; then
    log "ERROR" "${RED}Failed to build contracts${NC}"
    exit 1
fi

# Create generated-bytecode directory if it doesn't exist
mkdir -p script/generated-bytecode

log "INFO" "${BLUE}📋 Copying core contract artifacts...${NC}"

# Define arrays of contracts to copy
# Core contracts from specified directories
CORE_CONTRACTS=(
    "SuperExecutor"
    "SuperDestinationExecutor" 
    "SuperSenderCreator"
    "AcrossV3Adapter"
    "DebridgeAdapter"
    "StargateAdapter"
    "StargateAdapterV2"
    "AcrossV3AdapterV2"
    "SuperLedger"
    "FlatFeeLedger"
    "SuperLedgerConfiguration"
    "SuperValidator"
    "SuperDestinationValidator"
    "SuperNativePaymaster"
    "SuperSponsorshipPaymaster"
)

# Hook contracts from specified directories
HOOK_CONTRACTS=(
    "ApproveERC20Hook"
    "TransferERC20Hook"
    "TransferHook"
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
    "Redeem7540VaultHook"
    "RequestRedeem7540VaultHook"
    "Deposit7540VaultHook"
    "Withdraw7540VaultHook"
    "SetOperator7540Hook"
    "SetSlippageHook"
    "CancelDepositRequest7540Hook"
    "CancelRedeemRequest7540Hook"
    "ClaimCancelDepositRequest7540Hook"
    "ClaimCancelRedeemRequest7540Hook"
    "CancelDepositRequestWithId7540Hook"
    "CancelRedeemRequestWithId7540Hook"
    "ClaimCancelDepositRequestWithId7540Hook"
    "ClaimCancelRedeemRequestWithId7540Hook"
    "RedeemWithId7540VaultHook"
    "WithdrawWithId7540VaultHook"
    "Swap1InchHook"
    "SwapOdosV2Hook"
    "ApproveAndSwapOdosV2Hook"
    "PendleRouterRedeemHook"
    "PendleRouterSwapHook"
    "PendleUnifiedHook"
    "RecordPurchasePendlePTAmortizedOracleHook"
    "RecordRedemptionPendlePTAmortizedOracleHook"
    "RecordPurchasePendlePTAmortizedOracleHookV2"
    "RecordRedemptionPendlePTAmortizedOracleHookV2"
    "AcrossSendFundsAndExecuteOnDstHook"
    "ApproveAndAcrossSendFundsAndExecuteOnDstHook"
    "DeBridgeSendOrderAndExecuteOnDstHook"
    "DeBridgeCancelOrderHook"
    "StargateSendHook"
    "ApproveAndStargateSendHook"
    "StargateSendHookV2"
    "ApproveAndStargateSendHookV2"
    "EthenaCooldownSharesHook"
    "EthenaUnstakeHook"
    "OfframpTokensHook"
    "MarkRootAsUsedHook"
    "MerklClaimRewardHook"
    "ClaimFailedTransferHook"
    "CircleGatewayWalletHook"
    "CircleGatewayMinterHook"
    "CircleGatewayAddDelegateHook"
    "CircleGatewayRemoveDelegateHook"
    "SwapUniswapV4Hook"
    "SwapUniswapV3Hook"
    "ApproveAndSwapUniswapV3Hook"
    "SwapSparkPSMExactInHook"
    "ApproveAndSwapSparkPSMExactInHook"
    "SwapSparkPSMExactOutHook"
    "ApproveAndSwapSparkPSMExactOutHook"
    "SwapKyberSwapHook"
    "ApproveAndSwapKyberSwapHook"
    "SwapOpenOceanHook"
    "ApproveAndSwapOpenOceanHook"
    "SwapUniswapV2Hook"
    "ApproveAndSwapUniswapV2Hook"
    "RedeemFirelightVaultHook"
    "ClaimWithdrawFirelightVaultHook"
    "SwapAlgebraIntegralHook"
    "ApproveAndSwapAlgebraIntegralHook"
    "SwapOdosV3Hook"
    "ApproveAndSwapOdosV3Hook"
    "CCTPSendHook"
    "ApproveAndCCTPSendHook"
    "SwapUniswapV3Router02Hook"
    "ApproveAndSwapUniswapV3Router02Hook"
    "AcrossSendFundsAndExecuteOnDstHookV2"
    "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2"
)

# Oracle contracts from accounting/oracles
ORACLE_CONTRACTS=(
    "ERC4626YieldSourceOracle"
    "ERC5115YieldSourceOracle"
    "PendlePTYieldSourceOracle"
    "SpectraPTYieldSourceOracle"
    "StakingYieldSourceOracle"
    "SuperYieldSourceOracle"
    "SuperVaultYieldSourceOracle"
    "YoYieldSourceOracle"
    "PendlePTAmortizedOracle"
    "PendlePTAmortizedOracleV2"
    "FirelightYieldSourceOracle"
    "DETHYieldSourceOracle"
    "ERC7540YieldSourceOracle"
    "SpectraMetaVaultOracle"
)

# Morpho hook contracts (deployed via DeployV2OtherHooks, stored in generated-bytecode-other/)
MORPHO_HOOK_CONTRACTS=(
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

# Aave V4 hook contracts (deployed via DeployV2OtherHooks, stored in generated-bytecode-other/)
AAVE_V4_HOOK_CONTRACTS=(
    "AaveV4SupplyHook"
    "AaveV4WithdrawHook"
    "AaveV4BorrowHook"
    "AaveV4RepayHook"
    "AaveV4SupplyAndBorrowHook"
    "AaveV4RepayAndWithdrawHook"
)

# DETH hook contracts (deployed via DeployV2OtherHooks, stored in generated-bytecode-other/)
DETH_HOOK_CONTRACTS=(
    "RequestRedeemDETHHook"
    "ApproveAndRequestRedeemDETHHook"
    "ClaimAssetsDETHHook"
)

# Sponsorship contracts (deployed via DeployV2OtherHooks, stored in generated-bytecode-other/)
SPONSORSHIP_CONTRACTS=(
    "NativeFeeSponsorship"
    "FetchNativeFeeHook"
)

# rFLR hook contracts (deployed via DeployV2OtherHooks, stored in generated-bytecode-other/)
RFLR_HOOK_CONTRACTS=(
    "ClaimRFLRHook"
    "ClaimRFLRV2Hook"
    "WithdrawRFLRHook"
    "WithdrawVestedRFLRHook"
)

# Odos V3 hook contracts - now deployed via DeployV2Core (kept here for reference)
ODOS_V3_HOOK_CONTRACTS=()


# Function to copy contract artifact
copy_contract() {
    local contract_name=$1
    local source_path
    local dest_path="script/generated-bytecode/${contract_name}.json"
    
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

# Process contracts based on argument
if [ -n "$CONTRACT_NAME" ]; then
    # Single contract mode
    log "INFO" "${BLUE}📦 Copying specific contract: ${CONTRACT_NAME}...${NC}"
    if copy_contract "$CONTRACT_NAME"; then
        log "INFO" "${GREEN}🎉 Contract ${CONTRACT_NAME} successfully updated in generated-bytecode!${NC}"
        exit 0
    else
        log "ERROR" "${RED}❌ Failed to copy contract ${CONTRACT_NAME}${NC}"
        exit 1
    fi
else
    # All contracts mode (original behavior)
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

    # Copy Morpho hook contracts to generated-bytecode-other/
    log "INFO" "${BLUE}🪝 Copying Morpho hook contracts to generated-bytecode-other/...${NC}"
    mkdir -p script/generated-bytecode-other
    failed_morpho=0
    for contract in "${MORPHO_HOOK_CONTRACTS[@]}"; do
        local_source="out/${contract}.sol/${contract}.json"
        local_dest="script/generated-bytecode-other/${contract}.json"
        if [ ! -f "$local_source" ]; then
            log "ERROR" "${RED}❌ Artifact not found for contract: ${contract} at ${local_source}${NC}"
            failed_morpho=$((failed_morpho + 1))
        else
            cp "$local_source" "$local_dest"
            log "INFO" "${GREEN}✅ Copied ${contract} → generated-bytecode-other/${NC}"
        fi
    done

    # Copy Aave V4 hook contracts to generated-bytecode-other/
    log "INFO" "${BLUE}🪝 Copying Aave V4 hook contracts to generated-bytecode-other/...${NC}"
    failed_aavev4=0
    for contract in "${AAVE_V4_HOOK_CONTRACTS[@]}"; do
        local_source="out/${contract}.sol/${contract}.json"
        local_dest="script/generated-bytecode-other/${contract}.json"
        if [ ! -f "$local_source" ]; then
            log "ERROR" "${RED}❌ Artifact not found for contract: ${contract} at ${local_source}${NC}"
            failed_aavev4=$((failed_aavev4 + 1))
        else
            cp "$local_source" "$local_dest"
            log "INFO" "${GREEN}✅ Copied ${contract} → generated-bytecode-other/${NC}"
        fi
    done

    # Copy DETH hook contracts to generated-bytecode-other/
    log "INFO" "${BLUE}🪝 Copying DETH hook contracts to generated-bytecode-other/...${NC}"
    failed_deth=0
    for contract in "${DETH_HOOK_CONTRACTS[@]}"; do
        local_source="out/${contract}.sol/${contract}.json"
        local_dest="script/generated-bytecode-other/${contract}.json"
        if [ ! -f "$local_source" ]; then
            log "ERROR" "${RED}❌ Artifact not found for contract: ${contract} at ${local_source}${NC}"
            failed_deth=$((failed_deth + 1))
        else
            cp "$local_source" "$local_dest"
            log "INFO" "${GREEN}✅ Copied ${contract} → generated-bytecode-other/${NC}"
        fi
    done

    # Copy Sponsorship contracts to generated-bytecode-other/
    log "INFO" "${BLUE}🪝 Copying Sponsorship contracts to generated-bytecode-other/...${NC}"
    failed_sponsorship=0
    for contract in "${SPONSORSHIP_CONTRACTS[@]}"; do
        local_source="out/${contract}.sol/${contract}.json"
        local_dest="script/generated-bytecode-other/${contract}.json"
        if [ ! -f "$local_source" ]; then
            log "ERROR" "${RED}❌ Artifact not found for contract: ${contract} at ${local_source}${NC}"
            failed_sponsorship=$((failed_sponsorship + 1))
        else
            cp "$local_source" "$local_dest"
            log "INFO" "${GREEN}✅ Copied ${contract} → generated-bytecode-other/${NC}"
        fi
    done

    # Copy rFLR hook contracts to generated-bytecode-other/
    log "INFO" "${BLUE}🪝 Copying rFLR hook contracts to generated-bytecode-other/...${NC}"
    failed_rflr=0
    for contract in "${RFLR_HOOK_CONTRACTS[@]}"; do
        local_source="out/${contract}.sol/${contract}.json"
        local_dest="script/generated-bytecode-other/${contract}.json"
        if [ ! -f "$local_source" ]; then
            log "ERROR" "${RED}❌ Artifact not found for contract: ${contract} at ${local_source}${NC}"
            failed_rflr=$((failed_rflr + 1))
        else
            cp "$local_source" "$local_dest"
            log "INFO" "${GREEN}✅ Copied ${contract} → generated-bytecode-other/${NC}"
        fi
    done

    # Copy Odos V3 hook contracts to generated-bytecode-other/
    log "INFO" "${BLUE}🪝 Copying Odos V3 hook contracts to generated-bytecode-other/...${NC}"
    failed_odosv3=0
    for contract in "${ODOS_V3_HOOK_CONTRACTS[@]}"; do
        local_source="out/${contract}.sol/${contract}.json"
        local_dest="script/generated-bytecode-other/${contract}.json"
        if [ ! -f "$local_source" ]; then
            log "ERROR" "${RED}❌ Artifact not found for contract: ${contract} at ${local_source}${NC}"
            failed_odosv3=$((failed_odosv3 + 1))
        else
            cp "$local_source" "$local_dest"
            log "INFO" "${GREEN}✅ Copied ${contract} → generated-bytecode-other/${NC}"
        fi
    done

    # Summary for all contracts mode
    total_contracts=$((${#CORE_CONTRACTS[@]} + ${#HOOK_CONTRACTS[@]} + ${#ORACLE_CONTRACTS[@]} + ${#MORPHO_HOOK_CONTRACTS[@]} + ${#AAVE_V4_HOOK_CONTRACTS[@]} + ${#DETH_HOOK_CONTRACTS[@]} + ${#SPONSORSHIP_CONTRACTS[@]} + ${#RFLR_HOOK_CONTRACTS[@]} + ${#ODOS_V3_HOOK_CONTRACTS[@]}))
    total_failed=$((failed_core + failed_hooks + failed_oracles + failed_morpho + failed_aavev4 + failed_deth + failed_sponsorship + failed_rflr + failed_odosv3))
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

    if [ $failed_morpho -gt 0 ]; then
        log "WARN" "${YELLOW}  ⚠️  Failed Morpho hook contracts: ${failed_morpho}/${#MORPHO_HOOK_CONTRACTS[@]}${NC}"
    fi

    if [ $failed_aavev4 -gt 0 ]; then
        log "WARN" "${YELLOW}  ⚠️  Failed Aave V4 hook contracts: ${failed_aavev4}/${#AAVE_V4_HOOK_CONTRACTS[@]}${NC}"
    fi

    if [ $failed_deth -gt 0 ]; then
        log "WARN" "${YELLOW}  ⚠️  Failed DETH hook contracts: ${failed_deth}/${#DETH_HOOK_CONTRACTS[@]}${NC}"
    fi

    if [ $failed_sponsorship -gt 0 ]; then
        log "WARN" "${YELLOW}  ⚠️  Failed Sponsorship contracts: ${failed_sponsorship}/${#SPONSORSHIP_CONTRACTS[@]}${NC}"
    fi

    if [ $failed_rflr -gt 0 ]; then
        log "WARN" "${YELLOW}  ⚠️  Failed rFLR hook contracts: ${failed_rflr}/${#RFLR_HOOK_CONTRACTS[@]}${NC}"
    fi

    if [ $failed_odosv3 -gt 0 ]; then
        log "WARN" "${YELLOW}  ⚠️  Failed Odos V3 hook contracts: ${failed_odosv3}/${#ODOS_V3_HOOK_CONTRACTS[@]}${NC}"
    fi

    if [ $total_failed -eq 0 ]; then
        log "INFO" "${GREEN}🎉 All contracts successfully updated in generated-bytecode and generated-bytecode-other!${NC}"
        exit 0
    else
        log "ERROR" "${RED}❌ ${total_failed} contracts failed to copy. Please check the error messages above.${NC}"
        exit 1
    fi
fi
