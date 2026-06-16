#!/usr/bin/env python3
"""Enrich hooks.json manifest with missing fields: compatibleProtocols, requiresApproval,
approveVariant, asyncLifecycle, amountMeta, sized, erc165."""

import json
import sys
from collections import OrderedDict

MANIFEST_PATH = "manifests/hooks.json"

# ── amountMeta mappings (from Phase 5 session context) ──────────────────────

# ASSETS denomination (IN)
ASSETS_IN = [
    "Deposit4626VaultHook", "ApproveAndDeposit4626VaultHook",
    "Deposit5115VaultHook", "ApproveAndDeposit5115VaultHook",
    "Deposit7540VaultHook",
    "RequestDeposit7540VaultHook", "ApproveAndRequestDeposit7540VaultHook",
    "Withdraw7540VaultHook", "WithdrawWithId7540VaultHook",
]

# SHARES denomination (IN)
SHARES_IN = [
    "Redeem4626VaultHook", "Redeem5115VaultHook",
    "Redeem7540VaultHook", "RedeemWithId7540VaultHook",
    "RequestRedeem7540VaultHook",
    "RequestRedeemDETHHook", "ApproveAndRequestRedeemDETHHook",
    "EthenaCooldownSharesHook",
    "RedeemFirelightVaultHook",
    "MintSuperPositionsHook", "BurnSuperPositionsHook",
]

# Sizeless hooks (empty amountMeta)
SIZELESS = [
    "FluidClaimRewardHook", "GearboxClaimRewardHook", "YearnClaimOneRewardHook",
    "MerklClaimRewardHook", "BatchTransferFromHook",
    "ClaimAssetsDETHHook", "ClaimWithdrawFirelightVaultHook",
]

# Special: MorphoWithdrawHook has dual-slot with XOR invariant
MORPHO_WITHDRAW = "MorphoWithdrawHook"

# Compound hooks: dual amount
COMPOUND_HOOKS = {
    "MorphoSupplyAndBorrowHook":   [{"direction": "IN", "denomination": "TOKEN"}, {"direction": "OUT", "denomination": "TOKEN"}],
    "AaveV4SupplyAndBorrowHook":   [{"direction": "IN", "denomination": "TOKEN"}, {"direction": "OUT", "denomination": "TOKEN"}],
    "MorphoRepayAndWithdrawHook":  [{"direction": "IN", "denomination": "TOKEN"}, {"direction": "OUT", "denomination": "TOKEN"}],
    "AaveV4RepayAndWithdrawHook":  [{"direction": "IN", "denomination": "TOKEN"}, {"direction": "OUT", "denomination": "TOKEN"}],
}

def get_amount_meta(name):
    if name in SIZELESS:
        return []
    if name in COMPOUND_HOOKS:
        return COMPOUND_HOOKS[name]
    if name == MORPHO_WITHDRAW:
        return [{"direction": "IN", "denomination": "ASSETS"}, {"direction": "IN", "denomination": "SHARES"}]
    if name in ASSETS_IN:
        return [{"direction": "IN", "denomination": "ASSETS"}]
    if name in SHARES_IN:
        return [{"direction": "IN", "denomination": "SHARES"}]
    # Default: TOKEN (swappers, bridges, token hooks, stake, loan single, etc.)
    return [{"direction": "IN", "denomination": "TOKEN"}]


# ── compatibleProtocols mapping ─────────────────────────────────────────────

PROTOCOL_MAP = {
    # ERC-4626
    "Deposit4626VaultHook": ["erc4626"], "ApproveAndDeposit4626VaultHook": ["erc4626"],
    "Redeem4626VaultHook": ["erc4626"],
    # ERC-5115
    "Deposit5115VaultHook": ["erc5115"], "ApproveAndDeposit5115VaultHook": ["erc5115"],
    "Redeem5115VaultHook": ["erc5115"],
    # ERC-7540
    "Deposit7540VaultHook": ["erc7540"], "RequestDeposit7540VaultHook": ["erc7540"],
    "ApproveAndRequestDeposit7540VaultHook": ["erc7540"],
    "Redeem7540VaultHook": ["erc7540"], "RedeemWithId7540VaultHook": ["erc7540"],
    "RequestRedeem7540VaultHook": ["erc7540"],
    "Withdraw7540VaultHook": ["erc7540"], "WithdrawWithId7540VaultHook": ["erc7540"],
    "CancelDepositRequest7540Hook": ["erc7540"], "CancelDepositRequestWithId7540Hook": ["erc7540"],
    "CancelRedeemRequest7540Hook": ["erc7540"], "CancelRedeemRequestWithId7540Hook": ["erc7540"],
    "ClaimCancelDepositRequest7540Hook": ["erc7540"], "ClaimCancelDepositRequestWithId7540Hook": ["erc7540"],
    "ClaimCancelRedeemRequest7540Hook": ["erc7540"], "ClaimCancelRedeemRequestWithId7540Hook": ["erc7540"],
    "SetOperator7540Hook": ["erc7540"], "SetSlippageHook": ["erc7540"],
    # Morpho
    "MorphoSupplyHook": ["morpho"], "MorphoLendHook": ["morpho"],
    "MorphoBorrowHook": ["morpho"], "MorphoRepayHook": ["morpho"],
    "MorphoSupplyAndBorrowHook": ["morpho"], "MorphoRepayAndWithdrawHook": ["morpho"],
    "MorphoWithdrawHook": ["morpho"],
    "MetaMorphoReallocateHook": ["morpho-metamorpho"], "ForceDeallocateMorphoHook": ["morpho-metamorpho"],
    # Aave V4
    "AaveV4SupplyHook": ["aave-v4"], "AaveV4WithdrawHook": ["aave-v4"],
    "AaveV4BorrowHook": ["aave-v4"], "AaveV4RepayHook": ["aave-v4"],
    "AaveV4SupplyAndBorrowHook": ["aave-v4"], "AaveV4RepayAndWithdrawHook": ["aave-v4"],
    # Uniswap
    "SwapUniswapV3Hook": ["uniswap-v3"], "ApproveAndSwapUniswapV3Hook": ["uniswap-v3"],
    "SwapUniswapV3Router02Hook": ["uniswap-v3"], "ApproveAndSwapUniswapV3Router02Hook": ["uniswap-v3"],
    "SwapUniswapV2Hook": ["uniswap-v2"], "ApproveAndSwapUniswapV2Hook": ["uniswap-v2"],
    "SwapUniswapV4Hook": ["uniswap-v4"],
    # Odos
    "SwapOdosV2Hook": ["odos-v2"], "ApproveAndSwapOdosV2Hook": ["odos-v2"],
    "SwapOdosV3Hook": ["odos-v3"], "ApproveAndSwapOdosV3Hook": ["odos-v3"],
    # KyberSwap
    "SwapKyberSwapHook": ["kyberswap"], "ApproveAndSwapKyberSwapHook": ["kyberswap"],
    # Spark PSM
    "SwapSparkPSMExactInHook": ["spark-psm"], "ApproveAndSwapSparkPSMExactInHook": ["spark-psm"],
    "SwapSparkPSMExactOutHook": ["spark-psm"], "ApproveAndSwapSparkPSMExactOutHook": ["spark-psm"],
    # Algebra Integral
    "SwapAlgebraIntegralHook": ["algebra-integral"], "ApproveAndSwapAlgebraIntegralHook": ["algebra-integral"],
    # OpenOcean
    "SwapOpenOceanSparkDexHook": ["openocean"], "ApproveAndSwapOpenOceanSparkDexHook": ["openocean"],
    # 1inch
    "Swap1InchHook": ["1inch"],
    # Pendle
    "PendleRouterRedeemHook": ["pendle"], "PendleRouterSwapHook": ["pendle"], "PendleUnifiedHook": ["pendle"],
    "RecordPurchasePendlePTAmortizedOracleHook": ["pendle"],
    "RecordPurchasePendlePTAmortizedOracleHookV2": ["pendle"],
    "RecordRedemptionPendlePTAmortizedOracleHook": ["pendle"],
    "RecordRedemptionPendlePTAmortizedOracleHookV2": ["pendle"],
    # Spectra
    "SpectraExchangeDepositHook": ["spectra"], "SpectraExchangeRedeemHook": ["spectra"],
    # Across
    "AcrossSendFundsAndExecuteOnDstHook": ["across"], "ApproveAndAcrossSendFundsAndExecuteOnDstHook": ["across"],
    "AcrossSendFundsAndExecuteOnDstHookV2": ["across-v2"], "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2": ["across-v2"],
    # Stargate
    "StargateSendHook": ["stargate"], "ApproveAndStargateSendHook": ["stargate"],
    "StargateSendHookV2": ["stargate-v2"], "ApproveAndStargateSendHookV2": ["stargate-v2"],
    # deBridge
    "DeBridgeSendOrderAndExecuteOnDstHook": ["debridge"], "DeBridgeCancelOrderHook": ["debridge"],
    # CCTP / Circle
    "CCTPSendHook": ["circle-cctp"], "ApproveAndCCTPSendHook": ["circle-cctp"],
    "CircleGatewayWalletHook": ["circle-gateway"], "CircleGatewayMinterHook": ["circle-gateway"],
    "CircleGatewayAddDelegateHook": ["circle-gateway"], "CircleGatewayRemoveDelegateHook": ["circle-gateway"],
    # Ethena
    "EthenaCooldownSharesHook": ["ethena"], "EthenaUnstakeHook": ["ethena"],
    # DETH
    "RequestRedeemDETHHook": ["deth"], "ApproveAndRequestRedeemDETHHook": ["deth"],
    "ClaimAssetsDETHHook": ["deth"],
    # Firelight
    "RedeemFirelightVaultHook": ["firelight"], "ClaimWithdrawFirelightVaultHook": ["firelight"],
    # Fluid
    "FluidStakeHook": ["fluid"], "ApproveAndFluidStakeHook": ["fluid"],
    "FluidUnstakeHook": ["fluid"], "FluidClaimRewardHook": ["fluid"],
    # Gearbox
    "GearboxStakeHook": ["gearbox"], "ApproveAndGearboxStakeHook": ["gearbox"],
    "GearboxUnstakeHook": ["gearbox"], "GearboxClaimRewardHook": ["gearbox"],
    # Yearn
    "YearnClaimOneRewardHook": ["yearn"],
    # Merkl
    "MerklClaimRewardHook": ["merkl"],
    # Stargate claim
    "ClaimFailedTransferHook": ["stargate"],
    # Flare rFLR
    "ClaimRFLRHook": ["flare-rflr"], "WithdrawRFLRHook": ["flare-rflr"], "WithdrawVestedRFLRHook": ["flare-rflr"],
    # WETH
    "DepositWETHHook": ["weth"], "WithdrawWETHHook": ["weth"],
    # Token ops - generic ERC-20
    "TransferERC20Hook": ["erc20"], "ApproveERC20Hook": ["erc20"],
    "TransferHook": ["erc20"], "NativeTransferHook": ["native"],
    "BatchTransferHook": ["erc20"], "BatchTransferFromHook": ["permit2"],
    "OfframpTokensHook": ["offramp"],
    # Sponsorship
    "FetchNativeFeeHook": ["superform-sponsorship"],
    # Superform
    "MarkRootAsUsedHook": ["superform"],
    "MintSuperPositionsHook": ["superform"], "BurnSuperPositionsHook": ["superform"],
}

# ── approveVariant pairs ────────────────────────────────────────────────────

APPROVE_PAIRS = {
    "Deposit4626VaultHook": "ApproveAndDeposit4626VaultHook",
    "Deposit5115VaultHook": "ApproveAndDeposit5115VaultHook",
    "RequestDeposit7540VaultHook": "ApproveAndRequestDeposit7540VaultHook",
    "RequestRedeemDETHHook": "ApproveAndRequestRedeemDETHHook",
    "AcrossSendFundsAndExecuteOnDstHook": "ApproveAndAcrossSendFundsAndExecuteOnDstHook",
    "AcrossSendFundsAndExecuteOnDstHookV2": "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2",
    "StargateSendHook": "ApproveAndStargateSendHook",
    "StargateSendHookV2": "ApproveAndStargateSendHookV2",
    "CCTPSendHook": "ApproveAndCCTPSendHook",
    "SwapUniswapV3Hook": "ApproveAndSwapUniswapV3Hook",
    "SwapUniswapV3Router02Hook": "ApproveAndSwapUniswapV3Router02Hook",
    "SwapUniswapV2Hook": "ApproveAndSwapUniswapV2Hook",
    "SwapOdosV2Hook": "ApproveAndSwapOdosV2Hook",
    "SwapOdosV3Hook": "ApproveAndSwapOdosV3Hook",
    "SwapKyberSwapHook": "ApproveAndSwapKyberSwapHook",
    "SwapSparkPSMExactInHook": "ApproveAndSwapSparkPSMExactInHook",
    "SwapSparkPSMExactOutHook": "ApproveAndSwapSparkPSMExactOutHook",
    "SwapAlgebraIntegralHook": "ApproveAndSwapAlgebraIntegralHook",
    "SwapOpenOceanSparkDexHook": "ApproveAndSwapOpenOceanSparkDexHook",
    "FluidStakeHook": "ApproveAndFluidStakeHook",
    "GearboxStakeHook": "ApproveAndGearboxStakeHook",
}
# Reverse: ApproveAnd variants point back to base
APPROVE_REVERSE = {v: k for k, v in APPROVE_PAIRS.items()}

# ── asyncLifecycle (7540 hooks) ─────────────────────────────────────────────

ASYNC_DEPOSIT_7540 = {
    "request": "RequestDeposit7540VaultHook",
    "fulfill": "Deposit7540VaultHook",
    "cancel": "CancelDepositRequest7540Hook",
    "claimCancel": "ClaimCancelDepositRequest7540Hook",
}
ASYNC_DEPOSIT_7540_WITH_ID = {
    "request": "RequestDeposit7540VaultHook",
    "fulfill": "Deposit7540VaultHook",
    "cancel": "CancelDepositRequestWithId7540Hook",
    "claimCancel": "ClaimCancelDepositRequestWithId7540Hook",
}
ASYNC_REDEEM_7540 = {
    "request": "RequestRedeem7540VaultHook",
    "fulfill": "Redeem7540VaultHook",
    "cancel": "CancelRedeemRequest7540Hook",
    "claimCancel": "ClaimCancelRedeemRequest7540Hook",
}
ASYNC_REDEEM_7540_WITH_ID = {
    "request": "RequestRedeem7540VaultHook",
    "fulfill": "RedeemWithId7540VaultHook",
    "cancel": "CancelRedeemRequestWithId7540Hook",
    "claimCancel": "ClaimCancelRedeemRequestWithId7540Hook",
}
ASYNC_DETH = {
    "request": "RequestRedeemDETHHook",
    "fulfill": "ClaimAssetsDETHHook",
    "cancel": None,
    "claimCancel": None,
}
ASYNC_ETHENA = {
    "request": "EthenaCooldownSharesHook",
    "fulfill": "EthenaUnstakeHook",
    "cancel": None,
    "claimCancel": None,
}
ASYNC_FIRELIGHT = {
    "request": "RedeemFirelightVaultHook",
    "fulfill": "ClaimWithdrawFirelightVaultHook",
    "cancel": None,
    "claimCancel": None,
}

ASYNC_LIFECYCLE_MAP = {
    # 7540 deposit lifecycle
    "RequestDeposit7540VaultHook": ASYNC_DEPOSIT_7540,
    "ApproveAndRequestDeposit7540VaultHook": ASYNC_DEPOSIT_7540,
    "Deposit7540VaultHook": ASYNC_DEPOSIT_7540,
    "CancelDepositRequest7540Hook": ASYNC_DEPOSIT_7540,
    "ClaimCancelDepositRequest7540Hook": ASYNC_DEPOSIT_7540,
    "CancelDepositRequestWithId7540Hook": ASYNC_DEPOSIT_7540_WITH_ID,
    "ClaimCancelDepositRequestWithId7540Hook": ASYNC_DEPOSIT_7540_WITH_ID,
    # 7540 redeem lifecycle
    "RequestRedeem7540VaultHook": ASYNC_REDEEM_7540,
    "Redeem7540VaultHook": ASYNC_REDEEM_7540,
    "CancelRedeemRequest7540Hook": ASYNC_REDEEM_7540,
    "ClaimCancelRedeemRequest7540Hook": ASYNC_REDEEM_7540,
    "RedeemWithId7540VaultHook": ASYNC_REDEEM_7540_WITH_ID,
    "CancelRedeemRequestWithId7540Hook": ASYNC_REDEEM_7540_WITH_ID,
    "ClaimCancelRedeemRequestWithId7540Hook": ASYNC_REDEEM_7540_WITH_ID,
    # DETH lifecycle
    "RequestRedeemDETHHook": ASYNC_DETH,
    "ApproveAndRequestRedeemDETHHook": ASYNC_DETH,
    "ClaimAssetsDETHHook": ASYNC_DETH,
    # Ethena lifecycle
    "EthenaCooldownSharesHook": ASYNC_ETHENA,
    "EthenaUnstakeHook": ASYNC_ETHENA,
    # Firelight lifecycle
    "RedeemFirelightVaultHook": ASYNC_FIRELIGHT,
    "ClaimWithdrawFirelightVaultHook": ASYNC_FIRELIGHT,
}


def get_erc165(name, leg_sizing):
    """Determine ERC-165 interface support."""
    if name in SIZELESS or name in ("ClaimAssetsDETHHook", "ClaimWithdrawFirelightVaultHook"):
        # Decode-only: supports InflowOutflow but NOT Outflow
        return ["ISuperHookInflowOutflow"]
    if any(s != "none" for s in leg_sizing) or len(leg_sizing) > 0:
        return ["ISuperHookInflowOutflow", "ISuperHookOutflow"]
    return []


def get_sized(name, leg_sizing):
    """Determine if hook is sized (has any sizable legs)."""
    if name in SIZELESS:
        return False
    return len(leg_sizing) > 0 and any(s == "sized" for s in leg_sizing)


def get_requires_approval(name):
    """Determine if hook requires prior ERC-20 approval."""
    if name.startswith("ApproveAnd"):
        return False  # ApproveAnd variants handle their own approval
    if name in APPROVE_PAIRS:
        return True  # Base variant needs approval
    return False


def get_approve_variant(name):
    """Get the approve variant for this hook."""
    if name in APPROVE_PAIRS:
        return APPROVE_PAIRS[name]
    if name in APPROVE_REVERSE:
        return APPROVE_REVERSE[name]
    return None


def enrich_hook(name, hook):
    """Add missing fields to a hook entry."""
    leg_sizing = hook.get("legSizing", [])

    # Build enriched hook with desired key order
    enriched = OrderedDict()
    enriched["name"] = hook["name"]
    enriched["description"] = hook["description"]
    enriched["hookType"] = hook.get("hookType", "INFLOW_OUTFLOW")
    enriched["subtype"] = hook.get("subtype", "")
    enriched["amountMeta"] = get_amount_meta(name)
    enriched["sized"] = get_sized(name, leg_sizing)
    enriched["erc165"] = get_erc165(name, leg_sizing)
    enriched["actionTypes"] = hook["actionTypes"]
    enriched["legSizing"] = leg_sizing
    enriched["addresses"] = hook["addresses"]
    enriched["availableChains"] = hook["availableChains"]
    enriched["requiresApproval"] = get_requires_approval(name)
    enriched["approveVariant"] = get_approve_variant(name)
    enriched["asyncLifecycle"] = ASYNC_LIFECYCLE_MAP.get(name, None)
    enriched["compatibleProtocols"] = PROTOCOL_MAP.get(name, [])

    return enriched


def main():
    with open(MANIFEST_PATH, "r") as f:
        manifest = json.load(f, object_pairs_hook=OrderedDict)

    hooks = manifest["hooks"]
    enriched_hooks = OrderedDict()

    for name, hook in hooks.items():
        enriched_hooks[name] = enrich_hook(name, hook)

    manifest["hooks"] = enriched_hooks

    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
        f.write("\n")

    print(f"Enriched {len(enriched_hooks)} hooks in {MANIFEST_PATH}")

    # Validation summary
    missing_protocols = [n for n, h in enriched_hooks.items() if not h["compatibleProtocols"]]
    if missing_protocols:
        print(f"WARNING: {len(missing_protocols)} hooks have no compatibleProtocols:")
        for n in missing_protocols:
            print(f"  - {n}")

    approve_count = sum(1 for h in enriched_hooks.values() if h["requiresApproval"])
    async_count = sum(1 for h in enriched_hooks.values() if h["asyncLifecycle"])
    sized_count = sum(1 for h in enriched_hooks.values() if h["sized"])
    print(f"  requiresApproval: {approve_count}")
    print(f"  asyncLifecycle: {async_count}")
    print(f"  sized: {sized_count}")
    print(f"  sizeless: {len(enriched_hooks) - sized_count}")


if __name__ == "__main__":
    main()
