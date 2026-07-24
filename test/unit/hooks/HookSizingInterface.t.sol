// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../utils/Helpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    ISuperHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookContextAware
} from "../../../src/interfaces/ISuperHook.sol";

// ═══════════════════════════════════════════════════════
//  VAULT HOOKS
// ═══════════════════════════════════════════════════════
import { Deposit4626VaultHook } from "../../../src/hooks/vaults/4626/Deposit4626VaultHook.sol";
import { ApproveAndDeposit4626VaultHook } from "../../../src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { Redeem4626VaultHook } from "../../../src/hooks/vaults/4626/Redeem4626VaultHook.sol";
import { Deposit5115VaultHook } from "../../../src/hooks/vaults/5115/Deposit5115VaultHook.sol";
import { ApproveAndDeposit5115VaultHook } from "../../../src/hooks/vaults/5115/ApproveAndDeposit5115VaultHook.sol";
import { Redeem5115VaultHook } from "../../../src/hooks/vaults/5115/Redeem5115VaultHook.sol";
import { Deposit7540VaultHook } from "../../../src/hooks/vaults/7540/Deposit7540VaultHook.sol";
import { RequestDeposit7540VaultHook } from "../../../src/hooks/vaults/7540/RequestDeposit7540VaultHook.sol";
import {
    ApproveAndRequestDeposit7540VaultHook
} from "../../../src/hooks/vaults/7540/ApproveAndRequestDeposit7540VaultHook.sol";
import { Redeem7540VaultHook } from "../../../src/hooks/vaults/7540/Redeem7540VaultHook.sol";
import { RedeemWithId7540VaultHook } from "../../../src/hooks/vaults/7540/RedeemWithId7540VaultHook.sol";
import { RequestRedeem7540VaultHook } from "../../../src/hooks/vaults/7540/RequestRedeem7540VaultHook.sol";
import { Withdraw7540VaultHook } from "../../../src/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { WithdrawWithId7540VaultHook } from "../../../src/hooks/vaults/7540/WithdrawWithId7540VaultHook.sol";
import { RequestRedeemDETHHook } from "../../../src/hooks/vaults/deth/RequestRedeemDETHHook.sol";
import { ApproveAndRequestRedeemDETHHook } from "../../../src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol";
import { ClaimAssetsDETHHook } from "../../../src/hooks/vaults/deth/ClaimAssetsDETHHook.sol";
import { EthenaCooldownSharesHook } from "../../../src/hooks/vaults/ethena/EthenaCooldownSharesHook.sol";
import { EthenaUnstakeHook } from "../../../src/hooks/vaults/ethena/EthenaUnstakeHook.sol";
import { ForceDeallocateMorphoHook } from "../../../src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol";
import { MetaMorphoReallocateHook } from "../../../src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol";
import { CancelDepositRequest7540Hook } from "../../../src/hooks/vaults/7540/CancelDepositRequest7540Hook.sol";
import {
    CancelDepositRequestWithId7540Hook
} from "../../../src/hooks/vaults/7540/CancelDepositRequestWithId7540Hook.sol";
import { CancelRedeemRequest7540Hook } from "../../../src/hooks/vaults/7540/CancelRedeemRequest7540Hook.sol";
import {
    CancelRedeemRequestWithId7540Hook
} from "../../../src/hooks/vaults/7540/CancelRedeemRequestWithId7540Hook.sol";
import {
    ClaimCancelDepositRequest7540Hook
} from "../../../src/hooks/vaults/7540/ClaimCancelDepositRequest7540Hook.sol";
import {
    ClaimCancelDepositRequestWithId7540Hook
} from "../../../src/hooks/vaults/7540/ClaimCancelDepositRequestWithId7540Hook.sol";
import {
    ClaimCancelRedeemRequest7540Hook
} from "../../../src/hooks/vaults/7540/ClaimCancelRedeemRequest7540Hook.sol";
import {
    ClaimCancelRedeemRequestWithId7540Hook
} from "../../../src/hooks/vaults/7540/ClaimCancelRedeemRequestWithId7540Hook.sol";
import { SetOperator7540Hook } from "../../../src/hooks/vaults/7540/SetOperator7540Hook.sol";
import { SetSlippageHook } from "../../../src/hooks/vaults/7540/SetSlippageHook.sol";
import { MarkRootAsUsedHook } from "../../../src/hooks/superform/MarkRootAsUsedHook.sol";
import { OfframpTokensHook } from "../../../src/hooks/tokens/OfframpTokensHook.sol";
import {
    RecordPurchasePendlePTAmortizedOracleHook
} from "../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol";
import {
    RecordPurchasePendlePTAmortizedOracleHookV2
} from "../../../src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol";
import {
    RecordRedemptionPendlePTAmortizedOracleHook
} from "../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHook.sol";
import {
    RecordRedemptionPendlePTAmortizedOracleHookV2
} from "../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol";
import { RedeemFirelightVaultHook } from "../../../src/hooks/vaults/firelight/RedeemFirelightVaultHook.sol";
import {
    ClaimWithdrawFirelightVaultHook
} from "../../../src/hooks/vaults/firelight/ClaimWithdrawFirelightVaultHook.sol";
import { MintSuperPositionsHook } from "../../../src/hooks/vaults/vault-bank/MintSuperPositionsHook.sol";
import { BurnSuperPositionsHook } from "../../../src/hooks/vaults/vault-bank/BurnSuperPositionsHook.sol";

// ═══════════════════════════════════════════════════════
//  TOKEN HOOKS
// ═══════════════════════════════════════════════════════
import { TransferERC20Hook } from "../../../src/hooks/tokens/erc20/TransferERC20Hook.sol";
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { TransferHook } from "../../../src/hooks/tokens/TransferHook.sol";
import { NativeTransferHook } from "../../../src/hooks/tokens/NativeTransferHook.sol";
import { WrappedNativeHook } from "../../../src/hooks/tokens/native/WrappedNativeHook.sol";
import { BatchTransferFromHook } from "../../../src/hooks/tokens/permit2/BatchTransferFromHook.sol";

// ═══════════════════════════════════════════════════════
//  SWAPPER HOOKS
// ═══════════════════════════════════════════════════════
import { SwapUniswapV3Hook } from "../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol";
import {
    ApproveAndSwapUniswapV3Hook
} from "../../../src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol";
import {
    SwapUniswapV3Router02Hook
} from "../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol";
import {
    ApproveAndSwapUniswapV3Router02Hook
} from "../../../src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol";
import { SwapUniswapV2Hook } from "../../../src/hooks/swappers/uniswap-v2/SwapUniswapV2Hook.sol";
import { ApproveAndSwapUniswapV2Hook } from "../../../src/hooks/swappers/uniswap-v2/ApproveAndSwapUniswapV2Hook.sol";
import { SwapUniswapV4Hook } from "../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { SwapOdosV2Hook } from "../../../src/hooks/swappers/odos/SwapOdosV2Hook.sol";
import { ApproveAndSwapOdosV2Hook } from "../../../src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol";
import { SwapOdosV3Hook } from "../../../src/hooks/swappers/odos/SwapOdosV3Hook.sol";
import { ApproveAndSwapOdosV3Hook } from "../../../src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol";
import { SwapKyberSwapHook } from "../../../src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol";
import { ApproveAndSwapKyberSwapHook } from "../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { SwapSparkPSMExactInHook } from "../../../src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol";
import {
    ApproveAndSwapSparkPSMExactInHook
} from "../../../src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactInHook.sol";
import { SwapSparkPSMExactOutHook } from "../../../src/hooks/swappers/spark-psm/SwapSparkPSMExactOutHook.sol";
import {
    ApproveAndSwapSparkPSMExactOutHook
} from "../../../src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactOutHook.sol";
import {
    SwapAlgebraIntegralHook
} from "../../../src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol";
import {
    ApproveAndSwapAlgebraIntegralHook
} from "../../../src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol";
import { SwapOpenOceanHook } from "../../../src/hooks/swappers/openocean/SwapOpenOceanHook.sol";
import {
    ApproveAndSwapOpenOceanHook
} from "../../../src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol";
import { SpectraExchangeRedeemHook } from "../../../src/hooks/swappers/spectra/SpectraExchangeRedeemHook.sol";
import { PendleRouterRedeemHook } from "../../../src/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
import { PendleUnifiedHook } from "../../../src/hooks/swappers/pendle/PendleUnifiedHook.sol";
import { PendleRouterSwapHook } from "../../../src/hooks/swappers/pendle/deprecated/PendleRouterSwapHook.sol";
import {
    SpectraExchangeDepositHook
} from "../../../src/hooks/swappers/spectra/SpectraExchangeDepositHook.sol";
import { Swap1InchHook } from "../../../src/hooks/swappers/1inch/Swap1InchHook.sol";
import { BatchTransferHook } from "../../../src/hooks/tokens/BatchTransferHook.sol";

// ═══════════════════════════════════════════════════════
//  BRIDGE HOOKS
// ═══════════════════════════════════════════════════════
import {
    AcrossSendFundsAndExecuteOnDstHook
} from "../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol";
import {
    ApproveAndAcrossSendFundsAndExecuteOnDstHook
} from "../../../src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol";
import {
    AcrossSendFundsAndExecuteOnDstHookV2
} from "../../../src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol";
import {
    ApproveAndAcrossSendFundsAndExecuteOnDstHookV2
} from "../../../src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.sol";
import { StargateSendHook } from "../../../src/hooks/bridges/stargate/StargateSendHook.sol";
import { ApproveAndStargateSendHook } from "../../../src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol";
import { StargateSendHookV2 } from "../../../src/hooks/bridges/stargate/StargateSendHookV2.sol";
import { ApproveAndStargateSendHookV2 } from "../../../src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol";
import {
    DeBridgeSendOrderAndExecuteOnDstHook
} from "../../../src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol";
import { CCTPSendHook } from "../../../src/hooks/bridges/cctp/CCTPSendHook.sol";
import { ApproveAndCCTPSendHook } from "../../../src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol";
import { CircleGatewayWalletHook } from "../../../src/hooks/bridges/circle/CircleGatewayWalletHook.sol";
import { CircleGatewayMinterHook } from "../../../src/hooks/bridges/circle/CircleGatewayMinterHook.sol";
import { CircleGatewayAddDelegateHook } from "../../../src/hooks/bridges/circle/CircleGatewayAddDelegateHook.sol";
import {
    CircleGatewayRemoveDelegateHook
} from "../../../src/hooks/bridges/circle/CircleGatewayRemoveDelegateHook.sol";
import { DeBridgeCancelOrderHook } from "../../../src/hooks/bridges/debridge/DeBridgeCancelOrderHook.sol";

// ═══════════════════════════════════════════════════════
//  STAKE HOOKS
// ═══════════════════════════════════════════════════════
import { FluidStakeHook } from "../../../src/hooks/stake/fluid/FluidStakeHook.sol";
import { ApproveAndFluidStakeHook } from "../../../src/hooks/stake/fluid/ApproveAndFluidStakeHook.sol";
import { FluidUnstakeHook } from "../../../src/hooks/stake/fluid/FluidUnstakeHook.sol";
import { GearboxStakeHook } from "../../../src/hooks/stake/gearbox/GearboxStakeHook.sol";
import { ApproveAndGearboxStakeHook } from "../../../src/hooks/stake/gearbox/ApproveAndGearboxStakeHook.sol";
import { GearboxUnstakeHook } from "../../../src/hooks/stake/gearbox/GearboxUnstakeHook.sol";

// ═══════════════════════════════════════════════════════
//  CLAIM HOOKS
// ═══════════════════════════════════════════════════════
import { FluidClaimRewardHook } from "../../../src/hooks/claim/fluid/FluidClaimRewardHook.sol";
import { GearboxClaimRewardHook } from "../../../src/hooks/claim/gearbox/GearboxClaimRewardHook.sol";
import { YearnClaimOneRewardHook } from "../../../src/hooks/claim/yearn/YearnClaimOneRewardHook.sol";
import { MerklClaimRewardHook } from "../../../src/hooks/claim/merkl/MerklClaimRewardHook.sol";
import { ClaimFailedTransferHook } from "../../../src/hooks/claim/stargate/ClaimFailedTransferHook.sol";
import { ClaimRFLRHook } from "../../../src/hooks/claim/flare/ClaimRFLRHook.sol";
import { WithdrawRFLRHook } from "../../../src/hooks/claim/flare/WithdrawRFLRHook.sol";
import { WithdrawVestedRFLRHook } from "../../../src/hooks/claim/flare/WithdrawVestedRFLRHook.sol";

// ═══════════════════════════════════════════════════════
//  SPONSORSHIP HOOKS
// ═══════════════════════════════════════════════════════
import { FetchNativeFeeHook } from "../../../src/hooks/sponsorship/FetchNativeFeeHook.sol";

// ═══════════════════════════════════════════════════════
//  LOAN HOOKS
// ═══════════════════════════════════════════════════════
import { MorphoSupplyHook } from "../../../src/hooks/loan/morpho/MorphoSupplyHook.sol";
import { MorphoLendHook } from "../../../src/hooks/loan/morpho/MorphoLendHook.sol";
import { MorphoBorrowHook } from "../../../src/hooks/loan/morpho/MorphoBorrowHook.sol";
import { MorphoRepayHook } from "../../../src/hooks/loan/morpho/MorphoRepayHook.sol";
import { MorphoSupplyAndBorrowHook } from "../../../src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol";
import { MorphoRepayAndWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol";
import { MorphoWithdrawHook } from "../../../src/hooks/loan/morpho/MorphoWithdrawHook.sol";
import { AaveV4SupplyHook } from "../../../src/hooks/loan/aave-v4/AaveV4SupplyHook.sol";
import { AaveV4WithdrawHook } from "../../../src/hooks/loan/aave-v4/AaveV4WithdrawHook.sol";
import { AaveV4BorrowHook } from "../../../src/hooks/loan/aave-v4/AaveV4BorrowHook.sol";
import { AaveV4RepayHook } from "../../../src/hooks/loan/aave-v4/AaveV4RepayHook.sol";
import { AaveV4SupplyAndBorrowHook } from "../../../src/hooks/loan/aave-v4/AaveV4SupplyAndBorrowHook.sol";
import { AaveV4RepayAndWithdrawHook } from "../../../src/hooks/loan/aave-v4/AaveV4RepayAndWithdrawHook.sol";

/// @title HookSizingInterfaceTest
/// @notice Comprehensive tests for amountRoles(), supportsInterface(), decodeAmounts/replaceCalldataAmounts
///         correctness across all hook categories
contract HookSizingInterfaceTest is Helpers {
    using Dir for ISuperHookInflowOutflow.Direction;
    using Den for ISuperHookInflowOutflow.Denomination;

    // ──────── Dummy addresses for constructors ────────
    address constant DUMMY_ROUTER = address(0x1001);
    address constant DUMMY_NATIVE = address(0x1002);
    address constant DUMMY_SPOKE = address(0x1003);
    address constant DUMMY_VALIDATOR = address(0x1004);
    address constant DUMMY_MORPHO = address(0x1005);
    address constant DUMMY_PERMIT2 = address(0x1006);
    address constant DUMMY_DISTRIBUTOR = address(0x1007);
    address constant DUMMY_SPONSORSHIP = address(0x1008);

    // ──────── Token denomination hooks ────────
    TransferERC20Hook transferERC20;
    ApproveERC20Hook approveERC20;
    TransferHook transferHook;
    NativeTransferHook nativeTransfer;
    WrappedNativeHook wrappedNative;
    FetchNativeFeeHook fetchNativeFee;
    ClaimFailedTransferHook claimFailedTransfer;

    // Swappers (TOKEN)
    SwapUniswapV3Hook swapUniV3;
    ApproveAndSwapUniswapV3Hook approveSwapUniV3;
    SwapUniswapV3Router02Hook swapUniV3Router02;
    ApproveAndSwapUniswapV3Router02Hook approveSwapUniV3Router02;
    SwapUniswapV2Hook swapUniV2;
    ApproveAndSwapUniswapV2Hook approveSwapUniV2;
    SwapUniswapV4Hook swapUniV4;
    SwapOdosV2Hook swapOdosV2;
    ApproveAndSwapOdosV2Hook approveSwapOdosV2;
    SwapOdosV3Hook swapOdosV3;
    ApproveAndSwapOdosV3Hook approveSwapOdosV3;
    SwapKyberSwapHook swapKyber;
    ApproveAndSwapKyberSwapHook approveSwapKyber;
    SwapSparkPSMExactInHook swapSparkIn;
    ApproveAndSwapSparkPSMExactInHook approveSwapSparkIn;
    SwapSparkPSMExactOutHook swapSparkOut;
    ApproveAndSwapSparkPSMExactOutHook approveSwapSparkOut;
    SwapAlgebraIntegralHook swapAlgebra;
    ApproveAndSwapAlgebraIntegralHook approveSwapAlgebra;
    SwapOpenOceanHook swapOpenOcean;
    ApproveAndSwapOpenOceanHook approveSwapOpenOcean;
    SpectraExchangeRedeemHook spectraRedeem;
    PendleRouterRedeemHook pendleRedeem;

    // Bridges (TOKEN)
    AcrossSendFundsAndExecuteOnDstHook acrossV1;
    ApproveAndAcrossSendFundsAndExecuteOnDstHook approveAcrossV1;
    AcrossSendFundsAndExecuteOnDstHookV2 acrossV2;
    ApproveAndAcrossSendFundsAndExecuteOnDstHookV2 approveAcrossV2;
    StargateSendHook stargate;
    ApproveAndStargateSendHook approveStargate;
    StargateSendHookV2 stargateV2;
    ApproveAndStargateSendHookV2 approveStargateV2;
    DeBridgeSendOrderAndExecuteOnDstHook debridge;
    CCTPSendHook cctp;
    ApproveAndCCTPSendHook approveCctp;
    CircleGatewayWalletHook circleGateway;

    // Stake (TOKEN)
    FluidStakeHook fluidStake;
    ApproveAndFluidStakeHook approveFluidStake;
    FluidUnstakeHook fluidUnstake;
    GearboxStakeHook gearboxStake;
    ApproveAndGearboxStakeHook approveGearboxStake;
    GearboxUnstakeHook gearboxUnstake;

    // ──────── Assets denomination hooks ────────
    Deposit4626VaultHook deposit4626;
    ApproveAndDeposit4626VaultHook approveDeposit4626;
    Deposit5115VaultHook deposit5115;
    ApproveAndDeposit5115VaultHook approveDeposit5115;
    Deposit7540VaultHook deposit7540;
    RequestDeposit7540VaultHook requestDeposit7540;
    ApproveAndRequestDeposit7540VaultHook approveRequestDeposit7540;
    Withdraw7540VaultHook withdraw7540;
    WithdrawWithId7540VaultHook withdrawWithId7540;

    // ──────── Shares denomination hooks ────────
    Redeem4626VaultHook redeem4626;
    Redeem5115VaultHook redeem5115;
    Redeem7540VaultHook redeem7540;
    RedeemWithId7540VaultHook redeemWithId7540;
    RequestRedeem7540VaultHook requestRedeem7540;
    RequestRedeemDETHHook requestRedeemDETH;
    ApproveAndRequestRedeemDETHHook approveRequestRedeemDETH;
    EthenaCooldownSharesHook ethenaCooldown;
    RedeemFirelightVaultHook redeemFirelight;
    MintSuperPositionsHook mintSP;
    BurnSuperPositionsHook burnSP;

    // ──────── Sizeless hooks ────────
    FluidClaimRewardHook fluidClaim;
    GearboxClaimRewardHook gearboxClaim;
    YearnClaimOneRewardHook yearnClaim;
    MerklClaimRewardHook merklClaim;
    BatchTransferFromHook batchTransfer;
    ClaimAssetsDETHHook claimAssetsDETH;
    ClaimWithdrawFirelightVaultHook claimWithdrawFirelight;

    // ──────── Loan hooks (TOKEN) ────────
    MorphoSupplyHook morphoSupply;
    MorphoLendHook morphoLend;
    MorphoBorrowHook morphoBorrow;
    MorphoRepayHook morphoRepay;
    MorphoSupplyAndBorrowHook morphoSupplyAndBorrow;
    MorphoRepayAndWithdrawHook morphoRepayAndWithdraw;

    // ──────── Special: MorphoWithdraw (ASSETS + SHARES) ────────
    MorphoWithdrawHook morphoWithdraw;

    // ──────── Aave V4 loan hooks (TOKEN) ────────
    AaveV4SupplyHook aaveSupply;
    AaveV4WithdrawHook aaveWithdraw;
    AaveV4BorrowHook aaveBorrow;
    AaveV4RepayHook aaveRepay;
    AaveV4SupplyAndBorrowHook aaveSupplyAndBorrow;
    AaveV4RepayAndWithdrawHook aaveRepayAndWithdraw;

    // ──────── Newly-S1 hooks ────────
    ForceDeallocateMorphoHook forceDeallocateMorpho;

    // ──────── Newly-S2 hooks (opaque-blob + sizeless) ────────
    PendleUnifiedHook pendleUnified;
    PendleRouterSwapHook pendleRouterSwap;
    SpectraExchangeDepositHook spectraExchangeDeposit;
    Swap1InchHook swap1Inch;
    BatchTransferHook batchTransferBasic;
    CircleGatewayMinterHook circleGatewayMinter;
    CircleGatewayAddDelegateHook circleGatewayAddDelegate;
    CircleGatewayRemoveDelegateHook circleGatewayRemoveDelegate;
    DeBridgeCancelOrderHook debridgeCancel;
    RecordPurchasePendlePTAmortizedOracleHook recordPurchaseOracle;
    RecordPurchasePendlePTAmortizedOracleHookV2 recordPurchaseOracleV2;
    RecordRedemptionPendlePTAmortizedOracleHook recordRedemptionOracle;
    RecordRedemptionPendlePTAmortizedOracleHookV2 recordRedemptionOracleV2;
    ClaimRFLRHook claimRFLR;
    WithdrawRFLRHook withdrawRFLR;
    WithdrawVestedRFLRHook withdrawVestedRFLR;
    CancelDepositRequest7540Hook cancelDeposit7540;
    CancelDepositRequestWithId7540Hook cancelDepositWithId7540;
    CancelRedeemRequest7540Hook cancelRedeem7540;
    CancelRedeemRequestWithId7540Hook cancelRedeemWithId7540;
    ClaimCancelDepositRequest7540Hook claimCancelDeposit7540;
    ClaimCancelDepositRequestWithId7540Hook claimCancelDepositWithId7540;
    ClaimCancelRedeemRequest7540Hook claimCancelRedeem7540;
    ClaimCancelRedeemRequestWithId7540Hook claimCancelRedeemWithId7540;
    SetOperator7540Hook setOperator7540;
    SetSlippageHook setSlippage;
    MarkRootAsUsedHook markRootAsUsed;
    OfframpTokensHook offrampTokens;
    EthenaUnstakeHook ethenaUnstake;
    MetaMorphoReallocateHook metaMorphoReallocate;

    function setUp() public {
        // ── Token denomination hooks ──
        transferERC20 = new TransferERC20Hook();
        approveERC20 = new ApproveERC20Hook();
        transferHook = new TransferHook(DUMMY_NATIVE);
        nativeTransfer = new NativeTransferHook();
        wrappedNative = new WrappedNativeHook(DUMMY_NATIVE);
        fetchNativeFee = new FetchNativeFeeHook(DUMMY_SPONSORSHIP);
        claimFailedTransfer = new ClaimFailedTransferHook();

        // Swappers
        swapUniV3 = new SwapUniswapV3Hook(DUMMY_ROUTER);
        approveSwapUniV3 = new ApproveAndSwapUniswapV3Hook(DUMMY_ROUTER);
        swapUniV3Router02 = new SwapUniswapV3Router02Hook(DUMMY_ROUTER);
        approveSwapUniV3Router02 = new ApproveAndSwapUniswapV3Router02Hook(DUMMY_ROUTER);
        swapUniV2 = new SwapUniswapV2Hook(DUMMY_ROUTER, DUMMY_NATIVE);
        approveSwapUniV2 = new ApproveAndSwapUniswapV2Hook(DUMMY_ROUTER, DUMMY_NATIVE);
        swapUniV4 = new SwapUniswapV4Hook(DUMMY_ROUTER);
        swapOdosV2 = new SwapOdosV2Hook(DUMMY_ROUTER);
        approveSwapOdosV2 = new ApproveAndSwapOdosV2Hook(DUMMY_ROUTER);
        swapOdosV3 = new SwapOdosV3Hook(DUMMY_ROUTER);
        approveSwapOdosV3 = new ApproveAndSwapOdosV3Hook(DUMMY_ROUTER);
        swapKyber = new SwapKyberSwapHook(DUMMY_ROUTER, DUMMY_ROUTER, DUMMY_NATIVE);
        approveSwapKyber = new ApproveAndSwapKyberSwapHook(DUMMY_ROUTER, DUMMY_ROUTER, DUMMY_NATIVE);
        swapSparkIn = new SwapSparkPSMExactInHook(DUMMY_ROUTER);
        approveSwapSparkIn = new ApproveAndSwapSparkPSMExactInHook(DUMMY_ROUTER);
        swapSparkOut = new SwapSparkPSMExactOutHook(DUMMY_ROUTER);
        approveSwapSparkOut = new ApproveAndSwapSparkPSMExactOutHook(DUMMY_ROUTER);
        swapAlgebra = new SwapAlgebraIntegralHook(DUMMY_ROUTER);
        approveSwapAlgebra = new ApproveAndSwapAlgebraIntegralHook(DUMMY_ROUTER);
        swapOpenOcean = new SwapOpenOceanHook(DUMMY_ROUTER, DUMMY_ROUTER, DUMMY_NATIVE);
        approveSwapOpenOcean = new ApproveAndSwapOpenOceanHook(DUMMY_ROUTER, DUMMY_ROUTER, DUMMY_NATIVE);
        spectraRedeem = new SpectraExchangeRedeemHook(DUMMY_ROUTER);
        pendleRedeem = new PendleRouterRedeemHook(DUMMY_ROUTER);

        // Bridges
        acrossV1 = new AcrossSendFundsAndExecuteOnDstHook(DUMMY_SPOKE, DUMMY_VALIDATOR);
        approveAcrossV1 = new ApproveAndAcrossSendFundsAndExecuteOnDstHook(DUMMY_SPOKE, DUMMY_VALIDATOR);
        acrossV2 = new AcrossSendFundsAndExecuteOnDstHookV2(DUMMY_SPOKE, DUMMY_VALIDATOR);
        approveAcrossV2 = new ApproveAndAcrossSendFundsAndExecuteOnDstHookV2(DUMMY_SPOKE, DUMMY_VALIDATOR);
        stargate = new StargateSendHook(DUMMY_VALIDATOR);
        approveStargate = new ApproveAndStargateSendHook(DUMMY_VALIDATOR);
        stargateV2 = new StargateSendHookV2(DUMMY_VALIDATOR);
        approveStargateV2 = new ApproveAndStargateSendHookV2(DUMMY_VALIDATOR);
        debridge = new DeBridgeSendOrderAndExecuteOnDstHook(DUMMY_SPOKE, DUMMY_VALIDATOR);
        cctp = new CCTPSendHook(DUMMY_SPOKE, DUMMY_VALIDATOR);
        approveCctp = new ApproveAndCCTPSendHook(DUMMY_SPOKE, DUMMY_VALIDATOR);
        circleGateway = new CircleGatewayWalletHook(DUMMY_SPOKE);

        // Stake
        fluidStake = new FluidStakeHook();
        approveFluidStake = new ApproveAndFluidStakeHook();
        fluidUnstake = new FluidUnstakeHook();
        gearboxStake = new GearboxStakeHook();
        approveGearboxStake = new ApproveAndGearboxStakeHook();
        gearboxUnstake = new GearboxUnstakeHook();

        // ── Assets denomination hooks ──
        deposit4626 = new Deposit4626VaultHook();
        approveDeposit4626 = new ApproveAndDeposit4626VaultHook();
        deposit5115 = new Deposit5115VaultHook();
        approveDeposit5115 = new ApproveAndDeposit5115VaultHook();
        deposit7540 = new Deposit7540VaultHook();
        requestDeposit7540 = new RequestDeposit7540VaultHook();
        approveRequestDeposit7540 = new ApproveAndRequestDeposit7540VaultHook();
        withdraw7540 = new Withdraw7540VaultHook();
        withdrawWithId7540 = new WithdrawWithId7540VaultHook();

        // ── Shares denomination hooks ──
        redeem4626 = new Redeem4626VaultHook();
        redeem5115 = new Redeem5115VaultHook();
        redeem7540 = new Redeem7540VaultHook();
        redeemWithId7540 = new RedeemWithId7540VaultHook();
        requestRedeem7540 = new RequestRedeem7540VaultHook();
        requestRedeemDETH = new RequestRedeemDETHHook();
        approveRequestRedeemDETH = new ApproveAndRequestRedeemDETHHook();
        ethenaCooldown = new EthenaCooldownSharesHook();
        redeemFirelight = new RedeemFirelightVaultHook();
        mintSP = new MintSuperPositionsHook();
        burnSP = new BurnSuperPositionsHook();

        // ── Sizeless hooks ──
        fluidClaim = new FluidClaimRewardHook();
        gearboxClaim = new GearboxClaimRewardHook();
        yearnClaim = new YearnClaimOneRewardHook();
        merklClaim = new MerklClaimRewardHook(DUMMY_DISTRIBUTOR);
        batchTransfer = new BatchTransferFromHook(DUMMY_PERMIT2);
        claimAssetsDETH = new ClaimAssetsDETHHook();
        claimWithdrawFirelight = new ClaimWithdrawFirelightVaultHook();

        // ── Loan hooks ──
        morphoSupply = new MorphoSupplyHook(DUMMY_MORPHO);
        morphoLend = new MorphoLendHook(DUMMY_MORPHO);
        morphoBorrow = new MorphoBorrowHook(DUMMY_MORPHO);
        morphoRepay = new MorphoRepayHook(DUMMY_MORPHO);
        morphoSupplyAndBorrow = new MorphoSupplyAndBorrowHook(DUMMY_MORPHO);
        morphoRepayAndWithdraw = new MorphoRepayAndWithdrawHook(DUMMY_MORPHO);
        morphoWithdraw = new MorphoWithdrawHook(DUMMY_MORPHO);

        // ── Aave V4 loan hooks ──
        aaveSupply = new AaveV4SupplyHook();
        aaveWithdraw = new AaveV4WithdrawHook();
        aaveBorrow = new AaveV4BorrowHook();
        aaveRepay = new AaveV4RepayHook();
        aaveSupplyAndBorrow = new AaveV4SupplyAndBorrowHook();
        aaveRepayAndWithdraw = new AaveV4RepayAndWithdrawHook();

        // ── Newly-S1 hooks ──
        forceDeallocateMorpho = new ForceDeallocateMorphoHook();

        // ── Newly-S2 hooks ──
        pendleUnified = new PendleUnifiedHook(DUMMY_ROUTER);
        pendleRouterSwap = new PendleRouterSwapHook(DUMMY_ROUTER);
        spectraExchangeDeposit = new SpectraExchangeDepositHook(DUMMY_ROUTER);
        swap1Inch = new Swap1InchHook(DUMMY_ROUTER, DUMMY_NATIVE);
        batchTransferBasic = new BatchTransferHook(DUMMY_NATIVE);
        circleGatewayMinter = new CircleGatewayMinterHook(DUMMY_ROUTER);
        circleGatewayAddDelegate = new CircleGatewayAddDelegateHook(DUMMY_ROUTER);
        circleGatewayRemoveDelegate = new CircleGatewayRemoveDelegateHook(DUMMY_ROUTER);
        debridgeCancel = new DeBridgeCancelOrderHook(DUMMY_ROUTER);
        recordPurchaseOracle = new RecordPurchasePendlePTAmortizedOracleHook(DUMMY_ROUTER);
        recordPurchaseOracleV2 = new RecordPurchasePendlePTAmortizedOracleHookV2(DUMMY_ROUTER);
        recordRedemptionOracle = new RecordRedemptionPendlePTAmortizedOracleHook(DUMMY_ROUTER);
        recordRedemptionOracleV2 = new RecordRedemptionPendlePTAmortizedOracleHookV2(DUMMY_ROUTER);
        claimRFLR = new ClaimRFLRHook(DUMMY_ROUTER);
        withdrawRFLR = new WithdrawRFLRHook(DUMMY_ROUTER, DUMMY_NATIVE);
        withdrawVestedRFLR = new WithdrawVestedRFLRHook(DUMMY_ROUTER, DUMMY_NATIVE);
        cancelDeposit7540 = new CancelDepositRequest7540Hook();
        cancelDepositWithId7540 = new CancelDepositRequestWithId7540Hook();
        cancelRedeem7540 = new CancelRedeemRequest7540Hook();
        cancelRedeemWithId7540 = new CancelRedeemRequestWithId7540Hook();
        claimCancelDeposit7540 = new ClaimCancelDepositRequest7540Hook();
        claimCancelDepositWithId7540 = new ClaimCancelDepositRequestWithId7540Hook();
        claimCancelRedeem7540 = new ClaimCancelRedeemRequest7540Hook();
        claimCancelRedeemWithId7540 = new ClaimCancelRedeemRequestWithId7540Hook();
        setOperator7540 = new SetOperator7540Hook();
        setSlippage = new SetSlippageHook();
        markRootAsUsed = new MarkRootAsUsedHook();
        offrampTokens = new OfframpTokensHook();
        ethenaUnstake = new EthenaUnstakeHook();
        metaMorphoReallocate = new MetaMorphoReallocateHook();
    }

    /*//////////////////////////////////////////////////////////////
                    ERC-165: supportsInterface
    //////////////////////////////////////////////////////////////*/

    /// @dev All sized hooks MUST return true for ISuperHookInflowOutflow + ISuperHookOutflow
    function test_SupportsInterface_SizedHooks() public view {
        bytes4 inflowOutflowId = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflowId = type(ISuperHookOutflow).interfaceId;

        // TOKEN hooks
        assertTrue(transferERC20.supportsInterface(inflowOutflowId));
        assertTrue(transferERC20.supportsInterface(outflowId));
        assertTrue(swapUniV3.supportsInterface(inflowOutflowId));
        assertTrue(acrossV1.supportsInterface(inflowOutflowId));
        assertTrue(fluidStake.supportsInterface(inflowOutflowId));
        assertTrue(fetchNativeFee.supportsInterface(inflowOutflowId));

        // ASSETS hooks
        assertTrue(deposit4626.supportsInterface(inflowOutflowId));
        assertTrue(deposit4626.supportsInterface(outflowId));
        assertTrue(approveDeposit4626.supportsInterface(inflowOutflowId));
        assertTrue(withdraw7540.supportsInterface(inflowOutflowId));

        // SHARES hooks
        assertTrue(redeem4626.supportsInterface(inflowOutflowId));
        assertTrue(redeem4626.supportsInterface(outflowId));
        assertTrue(mintSP.supportsInterface(inflowOutflowId));
        assertTrue(ethenaCooldown.supportsInterface(inflowOutflowId));

        // Sizeless hooks (still return true — they implement the interface, just with empty arrays)
        assertTrue(fluidClaim.supportsInterface(inflowOutflowId));
        assertTrue(fluidClaim.supportsInterface(outflowId));
        assertTrue(merklClaim.supportsInterface(inflowOutflowId));
        assertTrue(batchTransfer.supportsInterface(inflowOutflowId));

        // Loan hooks
        assertTrue(morphoSupply.supportsInterface(inflowOutflowId));
        assertTrue(morphoWithdraw.supportsInterface(inflowOutflowId));
        assertTrue(aaveSupply.supportsInterface(inflowOutflowId));
        assertTrue(aaveSupplyAndBorrow.supportsInterface(inflowOutflowId));
    }

    /// @dev All hooks support IERC165, ISuperHook, ISuperHookResult, ISuperHookInspector
    function test_SupportsInterface_BaseInterfaces() public view {
        bytes4 ierc165Id = type(IERC165).interfaceId;
        bytes4 hookId = type(ISuperHook).interfaceId;
        bytes4 resultId = type(ISuperHookResult).interfaceId;
        bytes4 inspectorId = type(ISuperHookInspector).interfaceId;

        // Spot-check across categories
        assertTrue(transferERC20.supportsInterface(ierc165Id));
        assertTrue(transferERC20.supportsInterface(hookId));
        assertTrue(transferERC20.supportsInterface(resultId));
        assertTrue(transferERC20.supportsInterface(inspectorId));

        assertTrue(deposit4626.supportsInterface(ierc165Id));
        assertTrue(redeem4626.supportsInterface(ierc165Id));
        assertTrue(fluidClaim.supportsInterface(ierc165Id));
        assertTrue(morphoSupply.supportsInterface(ierc165Id));
        assertTrue(aaveSupply.supportsInterface(ierc165Id));
    }

    /// @dev Unknown interface IDs return false
    function test_SupportsInterface_UnknownReturnsFalse() public view {
        bytes4 randomId = bytes4(keccak256("random.interface"));
        assertFalse(transferERC20.supportsInterface(randomId));
        assertFalse(deposit4626.supportsInterface(randomId));
        assertFalse(fluidClaim.supportsInterface(randomId));
        assertFalse(morphoSupply.supportsInterface(randomId));
    }

    /*//////////////////////////////////////////////////////////////
                    AMOUNT ROLES: TOKEN denomination
    //////////////////////////////////////////////////////////////*/

    function test_AmountRoles_TOKEN_TokenHooks() public view {
        _assertSingleMeta(transferERC20.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveERC20.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(transferHook.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(nativeTransfer.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(wrappedNative.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(fetchNativeFee.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(claimFailedTransfer.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    function test_AmountRoles_TOKEN_Swappers() public view {
        _assertSingleMeta(swapUniV3.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapUniV3.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapUniV3Router02.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapUniV3Router02.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapUniV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapUniV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapUniV4.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapOdosV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapOdosV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapOdosV3.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapOdosV3.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapKyber.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapKyber.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapSparkIn.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapSparkIn.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapSparkOut.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapSparkOut.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapAlgebra.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapAlgebra.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(swapOpenOcean.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveSwapOpenOcean.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(spectraRedeem.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(pendleRedeem.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    function test_AmountRoles_TOKEN_Bridges() public view {
        _assertSingleMeta(acrossV1.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveAcrossV1.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(acrossV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveAcrossV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(stargate.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveStargate.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(stargateV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveStargateV2.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(debridge.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(cctp.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveCctp.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(circleGateway.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    function test_AmountRoles_TOKEN_Stake() public view {
        _assertSingleMeta(fluidStake.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveFluidStake.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(fluidUnstake.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(gearboxStake.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(approveGearboxStake.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(gearboxUnstake.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    function test_AmountRoles_TOKEN_MorphoLoanHooks() public view {
        _assertSingleMeta(morphoSupply.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(morphoLend.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(morphoBorrow.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(morphoRepay.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(morphoSupplyAndBorrow.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(morphoRepayAndWithdraw.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    function test_AmountRoles_TOKEN_AaveV4SingleAmount() public view {
        _assertSingleMeta(aaveSupply.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(aaveWithdraw.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(aaveBorrow.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        _assertSingleMeta(aaveRepay.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /*//////////////////////////////////////////////////////////////
                    AMOUNT ROLES: ASSETS denomination
    //////////////////////////////////////////////////////////////*/

    function test_AmountRoles_ASSETS_VaultDeposits() public view {
        _assertSingleMeta(deposit4626.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(approveDeposit4626.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(deposit5115.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(approveDeposit5115.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(deposit7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(requestDeposit7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(approveRequestDeposit7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
    }

    function test_AmountRoles_ASSETS_VaultWithdraws() public view {
        _assertSingleMeta(withdraw7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
        _assertSingleMeta(withdrawWithId7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.ASSETS);
    }

    /*//////////////////////////////////////////////////////////////
                    AMOUNT ROLES: SHARES denomination
    //////////////////////////////////////////////////////////////*/

    function test_AmountRoles_SHARES_VaultRedeems() public view {
        _assertSingleMeta(redeem4626.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(redeem5115.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(redeem7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(redeemWithId7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(requestRedeem7540.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(requestRedeemDETH.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(approveRequestRedeemDETH.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(ethenaCooldown.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(redeemFirelight.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(mintSP.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
        _assertSingleMeta(burnSP.amountRoles(""), ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.SHARES);
    }

    /*//////////////////////////////////////////////////////////////
                    AMOUNT ROLES: Sizeless hooks
    //////////////////////////////////////////////////////////////*/

    function test_AmountRoles_Sizeless_ClaimHooks() public view {
        assertEq(fluidClaim.amountRoles("").length, 0);
        assertEq(gearboxClaim.amountRoles("").length, 0);
        assertEq(yearnClaim.amountRoles("").length, 0);
        assertEq(merklClaim.amountRoles("").length, 0);
    }

    function test_AmountRoles_Sizeless_CommitmentBound() public view {
        assertEq(batchTransfer.amountRoles("").length, 0);
        assertEq(claimAssetsDETH.amountRoles("").length, 0);
        assertEq(claimWithdrawFirelight.amountRoles("").length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    AMOUNT ROLES: Dual-amount hooks
    //////////////////////////////////////////////////////////////*/

    function test_AmountRoles_AaveV4SupplyAndBorrow_DualMeta() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = aaveSupplyAndBorrow.amountRoles("");
        assertEq(meta.length, 2);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint8(meta[1].dir), uint8(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint8(meta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_AmountRoles_AaveV4RepayAndWithdraw_DualMeta() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = aaveRepayAndWithdraw.amountRoles("");
        assertEq(meta.length, 2);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint8(meta[1].dir), uint8(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint8(meta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_AmountRoles_MorphoWithdraw_DualMeta_AssetsAndShares() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = morphoWithdraw.amountRoles("");
        assertEq(meta.length, 2);
        // Slot 0: assets
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.ASSETS));
        // Slot 1: shares
        assertEq(uint8(meta[1].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.SHARES));
    }

    /*//////////////////////////////////////////////////////////////
                    AMOUNT ROLES LENGTH == DECODE AMOUNTS LENGTH
    //////////////////////////////////////////////////////////////*/

    /// @dev For single-amount hooks, amountRoles.length must equal decodeAmounts.length (both 1)
    function test_AmountRolesLength_MatchesDecodeAmountsLength_SingleAmount() public view {
        // Build minimal data for a deposit4626 hook: bytes32 + address + uint256 + bool = 85 bytes
        bytes memory depositData = abi.encodePacked(bytes32(0), address(1), uint256(1e18), false);
        assertEq(deposit4626.amountRoles(depositData).length, deposit4626.decodeAmounts(depositData).length);

        // TransferERC20: header(52) + address(20) + address(20) + uint256(32) + bool(1) = 125 bytes
        bytes memory transferData = abi.encodePacked(bytes32(0), address(0), address(1), address(2), uint256(1e18), false);
        assertEq(transferERC20.amountRoles(transferData).length, transferERC20.decodeAmounts(transferData).length);
    }

    /// @dev For sizeless hooks, both must return length 0
    function test_AmountRolesLength_MatchesDecodeAmountsLength_Sizeless() public view {
        bytes memory empty = "";
        assertEq(fluidClaim.amountRoles(empty).length, fluidClaim.decodeAmounts(empty).length);
        assertEq(merklClaim.amountRoles(empty).length, merklClaim.decodeAmounts(empty).length);
        assertEq(batchTransfer.amountRoles(empty).length, batchTransfer.decodeAmounts(empty).length);
    }

    /// @dev For dual-amount hooks, both must return length 2
    function test_AmountRolesLength_MatchesDecodeAmountsLength_DualAmount() public view {
        // AaveV4SupplyAndBorrow: header(52) + loanToken + collateralToken + spoke + supplyReserveId + borrowReserveId + amount + usePrevHookAmount + borrowAmount
        bytes memory aaveData = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), uint256(1), uint256(2), uint256(1e18), false, uint256(5e17)
        );
        assertEq(
            aaveSupplyAndBorrow.amountRoles(aaveData).length, aaveSupplyAndBorrow.decodeAmounts(aaveData).length
        );

        // MorphoWithdraw: header(52) + loanToken + collateralToken + oracle + irm + lltv + assets + shares
        bytes memory morphoData = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        assertEq(morphoWithdraw.amountRoles(morphoData).length, morphoWithdraw.decodeAmounts(morphoData).length);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE + REPLACE: Single-amount roundtrip
    //////////////////////////////////////////////////////////////*/

    function test_DecodeReplace_Roundtrip_Deposit4626() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(1e18), false);
        assertEq(deposit4626.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(2e18));
        assertEq(deposit4626.decodeAmounts(replaced)[0], 2e18);
        assertEq(replaced.length, data.length);
    }

    function test_DecodeReplace_Roundtrip_Redeem4626() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), address(2), uint256(500), false);
        assertEq(redeem4626.decodeAmounts(data)[0], 500);

        bytes memory replaced = redeem4626.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(redeem4626.decodeAmounts(replaced)[0], 999);
    }

    function test_DecodeReplace_Roundtrip_TransferERC20() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(1), address(2), uint256(42), false);
        assertEq(transferERC20.decodeAmounts(data)[0], 42);

        bytes memory replaced = transferERC20.replaceCalldataAmounts(data, _singleAmount(100));
        assertEq(transferERC20.decodeAmounts(replaced)[0], 100);
    }

    function testFuzz_DecodeReplace_Roundtrip_Deposit4626(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(0), false);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(deposit4626.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_Roundtrip_Redeem4626(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), address(2), uint256(0), false);
        bytes memory replaced = redeem4626.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(redeem4626.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_Roundtrip_TransferERC20(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(1), address(2), uint256(0), false);
        bytes memory replaced = transferERC20.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(transferERC20.decodeAmounts(replaced)[0], amt);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE + REPLACE: Dual-amount roundtrip
    //////////////////////////////////////////////////////////////*/

    function test_DecodeReplace_Roundtrip_AaveV4SupplyAndBorrow() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), uint256(1), uint256(2), uint256(1e18), false, uint256(5e17)
        );
        uint256[] memory amounts = aaveSupplyAndBorrow.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1e18);
        assertEq(amounts[1], 5e17);

        bytes memory replaced = aaveSupplyAndBorrow.replaceCalldataAmounts(data, _dualAmounts(2e18, 1e18));
        uint256[] memory newAmounts = aaveSupplyAndBorrow.decodeAmounts(replaced);
        assertEq(newAmounts[0], 2e18);
        assertEq(newAmounts[1], 1e18);
    }

    function test_DecodeReplace_Roundtrip_AaveV4RepayAndWithdraw() public view {
        // header(52) + loanToken + collateralToken + spoke + supplyReserveId + borrowReserveId + amount + usePrevHookAmount + isFullRepayment + withdrawAmount
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), uint256(1), uint256(2), uint256(1e18), false, false, uint256(8e17)
        );
        uint256[] memory amounts = aaveRepayAndWithdraw.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1e18);
        assertEq(amounts[1], 8e17);

        bytes memory replaced = aaveRepayAndWithdraw.replaceCalldataAmounts(data, _dualAmounts(3e18, 2e18));
        uint256[] memory newAmounts = aaveRepayAndWithdraw.decodeAmounts(replaced);
        assertEq(newAmounts[0], 3e18);
        assertEq(newAmounts[1], 2e18);
    }

    function testFuzz_DecodeReplace_Roundtrip_AaveV4SupplyAndBorrow(uint256 a, uint256 b) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), uint256(1), uint256(2), uint256(0), false, uint256(0)
        );
        bytes memory replaced = aaveSupplyAndBorrow.replaceCalldataAmounts(data, _dualAmounts(a, b));
        uint256[] memory amounts = aaveSupplyAndBorrow.decodeAmounts(replaced);
        assertEq(amounts[0], a);
        assertEq(amounts[1], b);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE + REPLACE: MorphoWithdraw (XOR invariant)
    //////////////////////////////////////////////////////////////*/

    function test_MorphoWithdraw_DecodeAmounts_Assets() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        uint256[] memory amounts = morphoWithdraw.decodeAmounts(data);
        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1e18); // assets
        assertEq(amounts[1], 0); // shares
    }

    function test_MorphoWithdraw_DecodeAmounts_Shares() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(0), uint256(5e17)
        );
        uint256[] memory amounts = morphoWithdraw.decodeAmounts(data);
        assertEq(amounts[0], 0); // assets
        assertEq(amounts[1], 5e17); // shares
    }

    function test_MorphoWithdraw_ReplaceCalldataAmounts_AssetsOnly() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        // Replace with assets=2e18, shares=0 → valid
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(2e18, 0));
        uint256[] memory amounts = morphoWithdraw.decodeAmounts(replaced);
        assertEq(amounts[0], 2e18);
        assertEq(amounts[1], 0);
    }

    function test_MorphoWithdraw_ReplaceCalldataAmounts_SharesOnly() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(0), uint256(5e17)
        );
        // Replace with assets=0, shares=1e18 → valid
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(0, 1e18));
        uint256[] memory amounts = morphoWithdraw.decodeAmounts(replaced);
        assertEq(amounts[0], 0);
        assertEq(amounts[1], 1e18);
    }

    function test_MorphoWithdraw_ReplaceCalldataAmounts_RevertsBothNonzero() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(1e18, 1e18));
    }

    function test_MorphoWithdraw_ReplaceCalldataAmounts_RevertsBothZero() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(0, 0));
    }

    function testFuzz_MorphoWithdraw_XOR_Invariant(uint256 a, uint256 b) public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(0), uint256(0)
        );

        bool bothZero = (a == 0 && b == 0);
        bool bothNonzero = (a != 0 && b != 0);

        if (bothZero || bothNonzero) {
            vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
            morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(a, b));
        } else {
            bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(a, b));
            uint256[] memory amounts = morphoWithdraw.decodeAmounts(replaced);
            assertEq(amounts[0], a);
            assertEq(amounts[1], b);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    SIZELESS: decodeAmounts returns []
    //////////////////////////////////////////////////////////////*/

    function test_Sizeless_DecodeAmounts_Empty() public view {
        assertEq(fluidClaim.decodeAmounts("").length, 0);
        assertEq(gearboxClaim.decodeAmounts("").length, 0);
        assertEq(yearnClaim.decodeAmounts("").length, 0);
        assertEq(merklClaim.decodeAmounts("").length, 0);
        assertEq(batchTransfer.decodeAmounts("").length, 0);
    }

    /// @dev ClaimAssetsDETH and ClaimWithdrawFirelight are decode-only:
    ///      both decodeAmounts and amountRoles return [] (requestId is not a sizable amount)
    function test_DecodeOnly_DecodeAmountsEmpty_AndAmountRolesEmpty() public view {
        // ClaimAssetsDETH: both decodeAmounts and amountRoles return empty
        // (requestId is not a sizable amount — it's an NFT receipt ID)
        bytes memory dethData = abi.encodePacked(bytes32(0), address(1), address(2), uint256(42));
        assertEq(claimAssetsDETH.decodeAmounts(dethData).length, 0);
        assertEq(claimAssetsDETH.amountRoles(dethData).length, 0);

        // ClaimWithdrawFirelight: same pattern
        bytes memory firelightData = abi.encodePacked(bytes32(0), address(1), uint256(42), false);
        assertEq(claimWithdrawFirelight.decodeAmounts(firelightData).length, 0);
        assertEq(claimWithdrawFirelight.amountRoles(firelightData).length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    SIZELESS: replaceCalldataAmounts rejects non-empty
    //////////////////////////////////////////////////////////////*/

    function test_Sizeless_ReplaceCalldataAmounts_AcceptsEmpty() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), address(2), address(3));
        bytes memory result = fluidClaim.replaceCalldataAmounts(data, new uint256[](0));
        assertEq(result.length, data.length);
    }

    function test_Sizeless_ReplaceCalldataAmounts_RevertsNonEmpty_FluidClaim() public {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), address(2), address(3));
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        fluidClaim.replaceCalldataAmounts(data, _singleAmount(1));
    }

    function test_Sizeless_ReplaceCalldataAmounts_RevertsNonEmpty_MerklClaim() public {
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        merklClaim.replaceCalldataAmounts("", _singleAmount(1));
    }

    function test_Sizeless_ReplaceCalldataAmounts_RevertsNonEmpty_BatchTransfer() public {
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        batchTransfer.replaceCalldataAmounts("", _singleAmount(1));
    }

    function test_Sizeless_ReplaceCalldataAmounts_RevertsNonEmpty_GearboxClaim() public {
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        gearboxClaim.replaceCalldataAmounts("", _singleAmount(1));
    }

    function test_Sizeless_ReplaceCalldataAmounts_RevertsNonEmpty_YearnClaim() public {
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        yearnClaim.replaceCalldataAmounts("", _singleAmount(1));
    }

    /*//////////////////////////////////////////////////////////////
                    INVALID_AMOUNTS_LENGTH for sized hooks
    //////////////////////////////////////////////////////////////*/

    function test_ReplaceCalldataAmounts_RevertsWrongLength_SingleAmountHook() public {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(1e18), false);

        // Passing 0 amounts to a hook that expects 1
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        deposit4626.replaceCalldataAmounts(data, new uint256[](0));

        // Passing 2 amounts to a hook that expects 1
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        deposit4626.replaceCalldataAmounts(data, _dualAmounts(1, 2));
    }

    function test_ReplaceCalldataAmounts_RevertsWrongLength_DualAmountHook() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), uint256(1), uint256(2), uint256(1e18), false, uint256(5e17)
        );

        // Passing 1 amount to a hook that expects 2
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveSupplyAndBorrow.replaceCalldataAmounts(data, _singleAmount(1));

        // Passing 0 amounts to a hook that expects 2
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveSupplyAndBorrow.replaceCalldataAmounts(data, new uint256[](0));
    }

    function test_ReplaceCalldataAmounts_RevertsWrongLength_MorphoWithdraw() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoWithdraw.replaceCalldataAmounts(data, _singleAmount(1));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoWithdraw.replaceCalldataAmounts(data, new uint256[](0));
    }

    /*//////////////////////////////////////////////////////////////
                    FIELD PRESERVATION after replace
    //////////////////////////////////////////////////////////////*/

    function test_ReplaceCalldataAmounts_PreservesOtherFields_Deposit4626() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(0xABCD)), address(0xDEAD), uint256(1e18), true);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(2e18));

        assertEq(replaced.length, data.length);
        // bytes32 yieldSourceOracleId at [0:32] preserved
        for (uint256 i; i < 32; ++i) {
            assertEq(replaced[i], data[i]);
        }
        // address yieldSource at [32:52] preserved
        for (uint256 i = 32; i < 52; ++i) {
            assertEq(replaced[i], data[i]);
        }
        // bool usePrevHookAmount at [84] preserved
        assertEq(replaced[84], data[84]);
    }

    function test_ReplaceCalldataAmounts_PreservesOtherFields_TransferERC20() public view {
        // header(52) + token(20) + to(20) + amount(32) + usePrevHookAmount(1) = 125 bytes
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xBEEF), address(0xCAFE), uint256(42), true);
        bytes memory replaced = transferERC20.replaceCalldataAmounts(data, _singleAmount(999));

        // 52-byte header at [0:52] preserved
        for (uint256 i; i < 52; ++i) {
            assertEq(replaced[i], data[i]);
        }
        // address token at [52:72] preserved
        for (uint256 i = 52; i < 72; ++i) {
            assertEq(replaced[i], data[i]);
        }
        // address to at [72:92] preserved
        for (uint256 i = 72; i < 92; ++i) {
            assertEq(replaced[i], data[i]);
        }
        // bool usePrevHookAmount at [124] preserved
        assertEq(replaced[124], data[124]);
    }

    /*//////////////////////////////////////////////////////////////
         EXHAUSTIVE ERC-165: ALL hooks support ISuperHookInflowOutflow
    //////////////////////////////////////////////////////////////*/

    /// @dev Every sized hook (77 hooks) must return true for ISuperHookInflowOutflow
    function test_SupportsInterface_ALL_Hooks_InflowOutflow() public view {
        bytes4 iid = type(ISuperHookInflowOutflow).interfaceId;

        // TOKEN: token hooks
        assertTrue(transferERC20.supportsInterface(iid));
        assertTrue(approveERC20.supportsInterface(iid));
        assertTrue(transferHook.supportsInterface(iid));
        assertTrue(nativeTransfer.supportsInterface(iid));
        assertTrue(wrappedNative.supportsInterface(iid));
        assertTrue(fetchNativeFee.supportsInterface(iid));
        assertTrue(claimFailedTransfer.supportsInterface(iid));

        // TOKEN: swappers
        assertTrue(swapUniV3.supportsInterface(iid));
        assertTrue(approveSwapUniV3.supportsInterface(iid));
        assertTrue(swapUniV3Router02.supportsInterface(iid));
        assertTrue(approveSwapUniV3Router02.supportsInterface(iid));
        assertTrue(swapUniV2.supportsInterface(iid));
        assertTrue(approveSwapUniV2.supportsInterface(iid));
        assertTrue(swapUniV4.supportsInterface(iid));
        assertTrue(swapOdosV2.supportsInterface(iid));
        assertTrue(approveSwapOdosV2.supportsInterface(iid));
        assertTrue(swapOdosV3.supportsInterface(iid));
        assertTrue(approveSwapOdosV3.supportsInterface(iid));
        assertTrue(swapKyber.supportsInterface(iid));
        assertTrue(approveSwapKyber.supportsInterface(iid));
        assertTrue(swapSparkIn.supportsInterface(iid));
        assertTrue(approveSwapSparkIn.supportsInterface(iid));
        assertTrue(swapSparkOut.supportsInterface(iid));
        assertTrue(approveSwapSparkOut.supportsInterface(iid));
        assertTrue(swapAlgebra.supportsInterface(iid));
        assertTrue(approveSwapAlgebra.supportsInterface(iid));
        assertTrue(swapOpenOcean.supportsInterface(iid));
        assertTrue(approveSwapOpenOcean.supportsInterface(iid));
        assertTrue(spectraRedeem.supportsInterface(iid));
        assertTrue(pendleRedeem.supportsInterface(iid));

        // TOKEN: bridges
        assertTrue(acrossV1.supportsInterface(iid));
        assertTrue(approveAcrossV1.supportsInterface(iid));
        assertTrue(acrossV2.supportsInterface(iid));
        assertTrue(approveAcrossV2.supportsInterface(iid));
        assertTrue(stargate.supportsInterface(iid));
        assertTrue(approveStargate.supportsInterface(iid));
        assertTrue(stargateV2.supportsInterface(iid));
        assertTrue(approveStargateV2.supportsInterface(iid));
        assertTrue(debridge.supportsInterface(iid));
        assertTrue(cctp.supportsInterface(iid));
        assertTrue(approveCctp.supportsInterface(iid));
        assertTrue(circleGateway.supportsInterface(iid));

        // TOKEN: stake
        assertTrue(fluidStake.supportsInterface(iid));
        assertTrue(approveFluidStake.supportsInterface(iid));
        assertTrue(fluidUnstake.supportsInterface(iid));
        assertTrue(gearboxStake.supportsInterface(iid));
        assertTrue(approveGearboxStake.supportsInterface(iid));
        assertTrue(gearboxUnstake.supportsInterface(iid));

        // ASSETS: vault deposits
        assertTrue(deposit4626.supportsInterface(iid));
        assertTrue(approveDeposit4626.supportsInterface(iid));
        assertTrue(deposit5115.supportsInterface(iid));
        assertTrue(approveDeposit5115.supportsInterface(iid));
        assertTrue(deposit7540.supportsInterface(iid));
        assertTrue(requestDeposit7540.supportsInterface(iid));
        assertTrue(approveRequestDeposit7540.supportsInterface(iid));
        assertTrue(withdraw7540.supportsInterface(iid));
        assertTrue(withdrawWithId7540.supportsInterface(iid));

        // SHARES: vault redeems
        assertTrue(redeem4626.supportsInterface(iid));
        assertTrue(redeem5115.supportsInterface(iid));
        assertTrue(redeem7540.supportsInterface(iid));
        assertTrue(redeemWithId7540.supportsInterface(iid));
        assertTrue(requestRedeem7540.supportsInterface(iid));
        assertTrue(requestRedeemDETH.supportsInterface(iid));
        assertTrue(approveRequestRedeemDETH.supportsInterface(iid));
        assertTrue(ethenaCooldown.supportsInterface(iid));
        assertTrue(redeemFirelight.supportsInterface(iid));
        assertTrue(mintSP.supportsInterface(iid));
        assertTrue(burnSP.supportsInterface(iid));

        // Sizeless hooks (still implement the interface, just empty arrays)
        assertTrue(fluidClaim.supportsInterface(iid));
        assertTrue(gearboxClaim.supportsInterface(iid));
        assertTrue(yearnClaim.supportsInterface(iid));
        assertTrue(merklClaim.supportsInterface(iid));
        assertTrue(batchTransfer.supportsInterface(iid));
        assertTrue(claimAssetsDETH.supportsInterface(iid));
        assertTrue(claimWithdrawFirelight.supportsInterface(iid));

        // Loan hooks
        assertTrue(morphoSupply.supportsInterface(iid));
        assertTrue(morphoLend.supportsInterface(iid));
        assertTrue(morphoBorrow.supportsInterface(iid));
        assertTrue(morphoRepay.supportsInterface(iid));
        assertTrue(morphoSupplyAndBorrow.supportsInterface(iid));
        assertTrue(morphoRepayAndWithdraw.supportsInterface(iid));
        assertTrue(morphoWithdraw.supportsInterface(iid));
        assertTrue(aaveSupply.supportsInterface(iid));
        assertTrue(aaveWithdraw.supportsInterface(iid));
        assertTrue(aaveBorrow.supportsInterface(iid));
        assertTrue(aaveRepay.supportsInterface(iid));
        assertTrue(aaveSupplyAndBorrow.supportsInterface(iid));
        assertTrue(aaveRepayAndWithdraw.supportsInterface(iid));
    }

    /// @dev Every sized hook that has replaceCalldataAmounts must return true for ISuperHookOutflow
    function test_SupportsInterface_ALL_Hooks_Outflow() public view {
        bytes4 oid = type(ISuperHookOutflow).interfaceId;

        // TOKEN hooks
        assertTrue(transferERC20.supportsInterface(oid));
        assertTrue(approveERC20.supportsInterface(oid));
        assertTrue(transferHook.supportsInterface(oid));
        assertTrue(nativeTransfer.supportsInterface(oid));
        assertTrue(wrappedNative.supportsInterface(oid));
        assertTrue(fetchNativeFee.supportsInterface(oid));
        assertTrue(claimFailedTransfer.supportsInterface(oid));

        // Swappers
        assertTrue(swapUniV3.supportsInterface(oid));
        assertTrue(approveSwapUniV3.supportsInterface(oid));
        assertTrue(swapUniV3Router02.supportsInterface(oid));
        assertTrue(approveSwapUniV3Router02.supportsInterface(oid));
        assertTrue(swapUniV2.supportsInterface(oid));
        assertTrue(approveSwapUniV2.supportsInterface(oid));
        assertTrue(swapUniV4.supportsInterface(oid));
        assertTrue(swapOdosV2.supportsInterface(oid));
        assertTrue(approveSwapOdosV2.supportsInterface(oid));
        assertTrue(swapOdosV3.supportsInterface(oid));
        assertTrue(approveSwapOdosV3.supportsInterface(oid));
        assertTrue(swapKyber.supportsInterface(oid));
        assertTrue(approveSwapKyber.supportsInterface(oid));
        assertTrue(swapSparkIn.supportsInterface(oid));
        assertTrue(approveSwapSparkIn.supportsInterface(oid));
        assertTrue(swapSparkOut.supportsInterface(oid));
        assertTrue(approveSwapSparkOut.supportsInterface(oid));
        assertTrue(swapAlgebra.supportsInterface(oid));
        assertTrue(approveSwapAlgebra.supportsInterface(oid));
        assertTrue(swapOpenOcean.supportsInterface(oid));
        assertTrue(approveSwapOpenOcean.supportsInterface(oid));
        assertTrue(spectraRedeem.supportsInterface(oid));
        assertTrue(spectraExchangeDeposit.supportsInterface(oid));
        assertTrue(swap1Inch.supportsInterface(oid));
        assertTrue(pendleRedeem.supportsInterface(oid));

        // Bridges
        assertTrue(acrossV1.supportsInterface(oid));
        assertTrue(approveAcrossV1.supportsInterface(oid));
        assertTrue(acrossV2.supportsInterface(oid));
        assertTrue(approveAcrossV2.supportsInterface(oid));
        assertTrue(stargate.supportsInterface(oid));
        assertTrue(approveStargate.supportsInterface(oid));
        assertTrue(stargateV2.supportsInterface(oid));
        assertTrue(approveStargateV2.supportsInterface(oid));
        assertTrue(debridge.supportsInterface(oid));
        assertTrue(cctp.supportsInterface(oid));
        assertTrue(approveCctp.supportsInterface(oid));
        assertTrue(circleGateway.supportsInterface(oid));

        // Stake
        assertTrue(fluidStake.supportsInterface(oid));
        assertTrue(approveFluidStake.supportsInterface(oid));
        assertTrue(fluidUnstake.supportsInterface(oid));
        assertTrue(gearboxStake.supportsInterface(oid));
        assertTrue(approveGearboxStake.supportsInterface(oid));
        assertTrue(gearboxUnstake.supportsInterface(oid));

        // Vault deposits (ASSETS)
        assertTrue(deposit4626.supportsInterface(oid));
        assertTrue(approveDeposit4626.supportsInterface(oid));
        assertTrue(deposit5115.supportsInterface(oid));
        assertTrue(approveDeposit5115.supportsInterface(oid));
        assertTrue(deposit7540.supportsInterface(oid));
        assertTrue(requestDeposit7540.supportsInterface(oid));
        assertTrue(approveRequestDeposit7540.supportsInterface(oid));
        assertTrue(withdraw7540.supportsInterface(oid));
        assertTrue(withdrawWithId7540.supportsInterface(oid));

        // Vault redeems (SHARES)
        assertTrue(redeem4626.supportsInterface(oid));
        assertTrue(redeem5115.supportsInterface(oid));
        assertTrue(redeem7540.supportsInterface(oid));
        assertTrue(redeemWithId7540.supportsInterface(oid));
        assertTrue(requestRedeem7540.supportsInterface(oid));
        assertTrue(requestRedeemDETH.supportsInterface(oid));
        assertTrue(approveRequestRedeemDETH.supportsInterface(oid));
        assertTrue(ethenaCooldown.supportsInterface(oid));
        assertTrue(redeemFirelight.supportsInterface(oid));
        assertTrue(mintSP.supportsInterface(oid));
        assertTrue(burnSP.supportsInterface(oid));

        // Sizeless hooks
        assertTrue(fluidClaim.supportsInterface(oid));
        assertTrue(gearboxClaim.supportsInterface(oid));
        assertTrue(yearnClaim.supportsInterface(oid));
        assertTrue(merklClaim.supportsInterface(oid));
        assertTrue(batchTransfer.supportsInterface(oid));

        // Loan hooks
        assertTrue(morphoSupply.supportsInterface(oid));
        assertTrue(morphoLend.supportsInterface(oid));
        assertTrue(morphoBorrow.supportsInterface(oid));
        assertTrue(morphoRepay.supportsInterface(oid));
        assertTrue(morphoSupplyAndBorrow.supportsInterface(oid));
        assertTrue(morphoRepayAndWithdraw.supportsInterface(oid));
        assertTrue(morphoWithdraw.supportsInterface(oid));
        assertTrue(aaveSupply.supportsInterface(oid));
        assertTrue(aaveWithdraw.supportsInterface(oid));
        assertTrue(aaveBorrow.supportsInterface(oid));
        assertTrue(aaveRepay.supportsInterface(oid));
        assertTrue(aaveSupplyAndBorrow.supportsInterface(oid));
        assertTrue(aaveRepayAndWithdraw.supportsInterface(oid));
    }

    /// @dev Decode-only hooks (ClaimAssetsDETH, ClaimWithdrawFirelight) support ISuperHookInflowOutflow
    ///      but their amountRoles returns [] (no writable slots), so they are effectively sizeless
    function test_SupportsInterface_DecodeOnly_InflowOutflowYes_OutflowNo() public view {
        bytes4 iid = type(ISuperHookInflowOutflow).interfaceId;
        assertTrue(claimAssetsDETH.supportsInterface(iid));
        assertTrue(claimWithdrawFirelight.supportsInterface(iid));
        // Decode-only hooks do NOT support ISuperHookOutflow (no replaceCalldataAmounts)
        bytes4 oid = type(ISuperHookOutflow).interfaceId;
        assertFalse(claimAssetsDETH.supportsInterface(oid));
        assertFalse(claimWithdrawFirelight.supportsInterface(oid));
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Bridge hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev Across V1 hook: AMOUNT@92 — data = uint256 + addr + addr + addr + uint256(amt) + padding
    function test_DecodeReplace_Roundtrip_AcrossV1() public view {
        bytes memory data = _buildBridgeData_92(7e18);
        assertEq(acrossV1.decodeAmounts(data)[0], 7e18);

        bytes memory replaced = acrossV1.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(acrossV1.decodeAmounts(replaced)[0], 3e18);
        assertEq(replaced.length, data.length);
    }

    function test_DecodeReplace_Roundtrip_AcrossV2() public view {
        bytes memory data = _buildBridgeData_92(5e18);
        assertEq(acrossV2.decodeAmounts(data)[0], 5e18);

        bytes memory replaced = acrossV2.replaceCalldataAmounts(data, _singleAmount(9e18));
        assertEq(acrossV2.decodeAmounts(replaced)[0], 9e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveAcrossV1() public view {
        bytes memory data = _buildBridgeData_92(4e18);
        bytes memory replaced = approveAcrossV1.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(approveAcrossV1.decodeAmounts(replaced)[0], 8e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveAcrossV2() public view {
        bytes memory data = _buildBridgeData_92(4e18);
        bytes memory replaced = approveAcrossV2.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(approveAcrossV2.decodeAmounts(replaced)[0], 6e18);
    }

    /// @dev Stargate hooks: AMOUNT@108
    function test_DecodeReplace_Roundtrip_Stargate() public view {
        bytes memory data = _buildBridgeData_108(2e18);
        assertEq(stargate.decodeAmounts(data)[0], 2e18);

        bytes memory replaced = stargate.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(stargate.decodeAmounts(replaced)[0], 4e18);
    }

    function test_DecodeReplace_Roundtrip_StargateV2() public view {
        bytes memory data = _buildBridgeData_108(1e18);
        bytes memory replaced = stargateV2.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(stargateV2.decodeAmounts(replaced)[0], 6e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveStargate() public view {
        bytes memory data = _buildBridgeData_108(3e18);
        bytes memory replaced = approveStargate.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(approveStargate.decodeAmounts(replaced)[0], 7e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveStargateV2() public view {
        bytes memory data = _buildBridgeData_108(3e18);
        bytes memory replaced = approveStargateV2.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(approveStargateV2.decodeAmounts(replaced)[0], 7e18);
    }

    /// @dev deBridge: header(52) + usePrevHookAmount(1) + value(32) + giveTokenAddress(20) + giveAmount(32) + ...
    function test_DecodeReplace_Roundtrip_DeBridge() public view {
        // header(52) + bool(1) + uint256(32) + address(20) = 105 prefix, then amount
        bytes memory data = abi.encodePacked(bytes32(0), address(0), false, uint256(1), address(0xA), uint256(2e18), bytes32(0));
        assertEq(debridge.decodeAmounts(data)[0], 2e18);

        bytes memory replaced = debridge.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(debridge.decodeAmounts(replaced)[0], 5e18);
    }

    /// @dev CCTP: AMOUNT@72 — 52-byte header + address(burnToken) + uint256(amount) + ...
    function test_DecodeReplace_Roundtrip_CCTP() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), uint256(1e18), bytes32(0));
        assertEq(cctp.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = cctp.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(cctp.decodeAmounts(replaced)[0], 3e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveCCTP() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), uint256(1e18), bytes32(0));
        bytes memory replaced = approveCctp.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(approveCctp.decodeAmounts(replaced)[0], 8e18);
    }

    /// @dev CircleGateway: AMOUNT@72 — 52-byte header + address + uint256 + bool
    function test_DecodeReplace_Roundtrip_CircleGateway() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), uint256(1e6), false);
        assertEq(circleGateway.decodeAmounts(data)[0], 1e6);

        bytes memory replaced = circleGateway.replaceCalldataAmounts(data, _singleAmount(5e6));
        assertEq(circleGateway.decodeAmounts(replaced)[0], 5e6);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Swapper hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev UniswapV3: AMOUNT@92
    function test_DecodeReplace_Roundtrip_SwapUniswapV3() public view {
        bytes memory data = _buildSwapperData_128(1e18);
        assertEq(swapUniV3.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(swapUniV3.decodeAmounts(replaced)[0], 5e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveSwapUniswapV3() public view {
        bytes memory data = _buildSwapperData_128(2e18);
        bytes memory replaced = approveSwapUniV3.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(approveSwapUniV3.decodeAmounts(replaced)[0], 4e18);
    }

    /// @dev UniswapV3Router02: AMOUNT@128 — 52-byte header + bytes32 + addr + addr + uint32 + uint256
    function test_DecodeReplace_Roundtrip_SwapUniswapV3Router02() public view {
        // AMOUNT_POSITION = 92 (52-byte header + addr(20) + addr(20))
        bytes memory data = abi.encodePacked(bytes32(0), bytes20(address(0)), address(0xA), address(0xB), uint256(1e18), uint256(0), false, abi.encode(uint24(3000), uint160(0)));
        assertEq(swapUniV3Router02.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapUniV3Router02.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(swapUniV3Router02.decodeAmounts(replaced)[0], 3e18);
    }

    /// @dev UniswapV2: AMOUNT@124 (52-byte header + addr(20) + addr(20) + uint256(32))
    function test_DecodeReplace_Roundtrip_SwapUniswapV2() public view {
        // AMOUNT_POSITION = 92 (52-byte header + addr(20) + addr(20))
        address[] memory path = new address[](2);
        path[0] = address(0xA);
        path[1] = address(0xB);
        bytes memory data = abi.encodePacked(
            bytes32(0), bytes20(address(0)), // 52-byte header
            address(0xA), address(0xB), uint256(1e18), uint256(0), false, abi.encode(uint256(0), path)
        );
        assertEq(swapUniV2.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapUniV2.replaceCalldataAmounts(data, _singleAmount(9e18));
        assertEq(swapUniV2.decodeAmounts(replaced)[0], 9e18);
    }

    /// @dev UniswapV4: AMOUNT@120
    function test_DecodeReplace_Roundtrip_SwapUniswapV4() public view {
        bytes memory data = _buildSwapperData_120(7e18);
        assertEq(swapUniV4.decodeAmounts(data)[0], 7e18);

        bytes memory replaced = swapUniV4.replaceCalldataAmounts(data, _singleAmount(2e18));
        assertEq(swapUniV4.decodeAmounts(replaced)[0], 2e18);
    }

    /// @dev OdosV2: AMOUNT@92 — 52-byte header + address(inputToken) + address(outputToken) + uint256(inputAmount)
    function test_DecodeReplace_Roundtrip_SwapOdosV2() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0));
        assertEq(swapOdosV2.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapOdosV2.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(swapOdosV2.decodeAmounts(replaced)[0], 6e18);
    }

    /// @dev OdosV3: AMOUNT@92 — 52-byte header + address(inputToken) + address(outputToken) + uint256(inputAmount)
    function test_DecodeReplace_Roundtrip_SwapOdosV3() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0));
        assertEq(swapOdosV3.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapOdosV3.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(swapOdosV3.decodeAmounts(replaced)[0], 4e18);
    }

    /// @dev KyberSwap: AMOUNT@92 — 52-byte header + address(inputToken) + address(outputToken) + uint256(amount)
    function test_DecodeReplace_Roundtrip_SwapKyberSwap() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0), false);
        assertEq(swapKyber.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapKyber.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(swapKyber.decodeAmounts(replaced)[0], 8e18);
    }

    /// @dev ApproveAndSwapKyberSwap: AMOUNT@92 — 52-byte header + addr + addr + uint256(amount)
    function test_DecodeReplace_Roundtrip_ApproveSwapKyberSwap() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0), false);
        assertEq(approveSwapKyber.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = approveSwapKyber.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(approveSwapKyber.decodeAmounts(replaced)[0], 3e18);
    }

    /// @dev SparkPSM ExactIn: AMOUNT@92 — 52-byte header + addr + addr + uint256(amount)
    function test_DecodeReplace_Roundtrip_SwapSparkPSMExactIn() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), address(0xC), uint256(0), false);
        assertEq(swapSparkIn.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapSparkIn.replaceCalldataAmounts(data, _singleAmount(2e18));
        assertEq(swapSparkIn.decodeAmounts(replaced)[0], 2e18);
    }

    /// @dev SparkPSM ExactOut: AMOUNT@92 — 52-byte header + addr + addr + uint256(amount)
    function test_DecodeReplace_Roundtrip_SwapSparkPSMExactOut() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), address(0xC), uint256(0), false);
        assertEq(swapSparkOut.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapSparkOut.replaceCalldataAmounts(data, _singleAmount(2e18));
        assertEq(swapSparkOut.decodeAmounts(replaced)[0], 2e18);
    }

    /// @dev AlgebraIntegral: AMOUNT@92
    function test_DecodeReplace_Roundtrip_SwapAlgebraIntegral() public view {
        bytes memory data = _buildSwapperData_144(1e18);
        assertEq(swapAlgebra.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapAlgebra.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(swapAlgebra.decodeAmounts(replaced)[0], 5e18);
    }

    /// @dev OpenOcean: AMOUNT@92 — 52-byte header + address(inputToken) + address(outputToken) + uint256(amount)
    function test_DecodeReplace_Roundtrip_SwapOpenOcean() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0), false);
        assertEq(swapOpenOcean.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = swapOpenOcean.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(swapOpenOcean.decodeAmounts(replaced)[0], 4e18);
    }

    /// @dev ApproveAndSwapOpenOcean: AMOUNT@92 — 52-byte header + addr + addr + uint256(amount)
    function test_DecodeReplace_Roundtrip_ApproveSwapOpenOcean() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0), false);
        assertEq(approveSwapOpenOcean.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = approveSwapOpenOcean.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(approveSwapOpenOcean.decodeAmounts(replaced)[0], 7e18);
    }

    /// @dev SpectraExchangeRedeem: AMOUNT@92 — 52-byte header + addr(20) inputToken/asset + addr(20) outputToken/pt + uint256(inputAmount/sharesToBurn)
    function test_DecodeReplace_Roundtrip_SpectraExchangeRedeem() public view {
        // AMOUNT_POSITION = 92 (52-byte header + addr(20) asset + addr(20) pt)
        bytes memory redeemPayload = abi.encode(address(0xC), uint256(0), bytes1(0));
        bytes memory data = bytes.concat(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(0xA)),
            bytes20(address(0xB)),
            bytes32(uint256(1e18)),
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            bytes1(0x00),
            bytes32(redeemPayload.length),
            redeemPayload
        );
        assertEq(spectraRedeem.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = spectraRedeem.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(spectraRedeem.decodeAmounts(replaced)[0], 3e18);
    }

    /// @dev PendleRouterRedeem: AMOUNT@92 — 52-byte header + addr(20) inputToken + addr(20) outputToken + uint256(inputAmount)
    function test_DecodeReplace_Roundtrip_PendleRouterRedeem() public view {
        // AMOUNT_POSITION = 92 (52-byte header + addr(20) + addr(20))
        bytes memory data = bytes.concat(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(0)),
            bytes20(address(0)),
            bytes32(uint256(1e18)),
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            bytes1(0x00)
        );
        assertEq(pendleRedeem.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = pendleRedeem.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(pendleRedeem.decodeAmounts(replaced)[0], 8e18);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Token hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev ApproveERC20: AMOUNT@92 — 52-byte header + address(token) + address(spender) + uint256 + bool = 125
    function test_DecodeReplace_Roundtrip_ApproveERC20() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(100), false);
        assertEq(approveERC20.decodeAmounts(data)[0], 100);

        bytes memory replaced = approveERC20.replaceCalldataAmounts(data, _singleAmount(200));
        assertEq(approveERC20.decodeAmounts(replaced)[0], 200);
    }

    /// @dev TransferHook: AMOUNT@92 — 52-byte header + address(token) + address(to) + uint256 + bool = 125
    function test_DecodeReplace_Roundtrip_TransferHook() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(50), true);
        assertEq(transferHook.decodeAmounts(data)[0], 50);

        bytes memory replaced = transferHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(transferHook.decodeAmounts(replaced)[0], 999);
    }

    /// @dev NativeTransferHook: AMOUNT@72 — 52-byte header + address(to) + uint256 = 104
    function test_DecodeReplace_Roundtrip_NativeTransfer() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xDEAD), uint256(1e18));
        assertEq(nativeTransfer.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = nativeTransfer.replaceCalldataAmounts(data, _singleAmount(2e18));
        assertEq(nativeTransfer.decodeAmounts(replaced)[0], 2e18);
    }

    /// @dev WrappedNative wrap: header(52) + uint256(32) + bool(wrap) + bool(usePrevHookAmount) = 86
    function test_DecodeReplace_Roundtrip_WrappedNative_Wrap() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), uint256(5e18), true, false);
        assertEq(wrappedNative.decodeAmounts(data)[0], 5e18);

        bytes memory replaced = wrappedNative.replaceCalldataAmounts(data, _singleAmount(10e18));
        assertEq(wrappedNative.decodeAmounts(replaced)[0], 10e18);
    }

    /// @dev WrappedNative unwrap: header(52) + uint256(32) + bool(wrap) + bool(usePrevHookAmount) = 86
    function test_DecodeReplace_Roundtrip_WrappedNative_Unwrap() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), uint256(3e18), false, true);
        assertEq(wrappedNative.decodeAmounts(data)[0], 3e18);

        bytes memory replaced = wrappedNative.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(wrappedNative.decodeAmounts(replaced)[0], 7e18);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Stake hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev FluidStake: AMOUNT@52 — bytes32 + addr + uint256 + bool = 85
    function test_DecodeReplace_Roundtrip_FluidStake() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(1)), address(0xA), uint256(1e18), false);
        assertEq(fluidStake.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = fluidStake.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(fluidStake.decodeAmounts(replaced)[0], 4e18);
    }

    function test_DecodeReplace_Roundtrip_FluidUnstake() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(2)), address(0xB), uint256(2e18), true);
        assertEq(fluidUnstake.decodeAmounts(data)[0], 2e18);

        bytes memory replaced = fluidUnstake.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(fluidUnstake.decodeAmounts(replaced)[0], 6e18);
    }

    function test_DecodeReplace_Roundtrip_GearboxStake() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(3)), address(0xC), uint256(3e18), false);
        assertEq(gearboxStake.decodeAmounts(data)[0], 3e18);

        bytes memory replaced = gearboxStake.replaceCalldataAmounts(data, _singleAmount(9e18));
        assertEq(gearboxStake.decodeAmounts(replaced)[0], 9e18);
    }

    function test_DecodeReplace_Roundtrip_GearboxUnstake() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(4)), address(0xD), uint256(4e18), true);
        assertEq(gearboxUnstake.decodeAmounts(data)[0], 4e18);

        bytes memory replaced = gearboxUnstake.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(gearboxUnstake.decodeAmounts(replaced)[0], 8e18);
    }

    /// @dev ApproveAndFluidStake: AMOUNT@72 — addr + bytes32 + addr + uint256 + bool = 105
    function test_DecodeReplace_Roundtrip_ApproveFluidStake() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(1)), address(0xA), address(0xB), uint256(1e18), false);
        assertEq(approveFluidStake.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = approveFluidStake.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(approveFluidStake.decodeAmounts(replaced)[0], 5e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveGearboxStake() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(2)), address(0xC), address(0xD), uint256(2e18), false);
        assertEq(approveGearboxStake.decodeAmounts(data)[0], 2e18);

        bytes memory replaced = approveGearboxStake.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(approveGearboxStake.decodeAmounts(replaced)[0], 7e18);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Vault 5115 hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev Deposit5115: AMOUNT@72 — bytes32 + addr + addr + uint256 + uint256 + bool = 137
    function test_DecodeReplace_Roundtrip_Deposit5115() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(1e18), uint256(0), false);
        assertEq(deposit5115.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = deposit5115.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(deposit5115.decodeAmounts(replaced)[0], 4e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveDeposit5115() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(2e18), uint256(0), false);
        bytes memory replaced = approveDeposit5115.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(approveDeposit5115.decodeAmounts(replaced)[0], 5e18);
    }

    /// @dev Redeem5115: AMOUNT@72 — same layout as Deposit5115
    function test_DecodeReplace_Roundtrip_Redeem5115() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(500), uint256(0), false);
        assertEq(redeem5115.decodeAmounts(data)[0], 500);

        bytes memory replaced = redeem5115.replaceCalldataAmounts(data, _singleAmount(1000));
        assertEq(redeem5115.decodeAmounts(replaced)[0], 1000);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Vault 7540 hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev Deposit7540: AMOUNT@52 — bytes32 + addr + uint256 + bool = 85
    function test_DecodeReplace_Roundtrip_Deposit7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(deposit7540.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = deposit7540.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(deposit7540.decodeAmounts(replaced)[0], 3e18);
    }

    function test_DecodeReplace_Roundtrip_RequestDeposit7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(2e18), true);
        bytes memory replaced = requestDeposit7540.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(requestDeposit7540.decodeAmounts(replaced)[0], 5e18);
    }

    function test_DecodeReplace_Roundtrip_Redeem7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(redeem7540.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = redeem7540.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(redeem7540.decodeAmounts(replaced)[0], 4e18);
    }

    function test_DecodeReplace_Roundtrip_RedeemWithId7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), uint256(42), false);
        assertEq(redeemWithId7540.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = redeemWithId7540.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(redeemWithId7540.decodeAmounts(replaced)[0], 6e18);
    }

    function test_DecodeReplace_Roundtrip_RequestRedeem7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(500), false);
        bytes memory replaced = requestRedeem7540.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(requestRedeem7540.decodeAmounts(replaced)[0], 999);
    }

    function test_DecodeReplace_Roundtrip_Withdraw7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        bytes memory replaced = withdraw7540.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(withdraw7540.decodeAmounts(replaced)[0], 7e18);
    }

    function test_DecodeReplace_Roundtrip_WithdrawWithId7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), uint256(99), false);
        bytes memory replaced = withdrawWithId7540.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(withdrawWithId7540.decodeAmounts(replaced)[0], 3e18);
    }

    function test_DecodeReplace_Roundtrip_ApproveRequestDeposit7540() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(1e18), false);
        bytes memory replaced = approveRequestDeposit7540.replaceCalldataAmounts(data, _singleAmount(9e18));
        assertEq(approveRequestDeposit7540.decodeAmounts(replaced)[0], 9e18);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Special vault hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev RequestRedeemDETH: AMOUNT@52
    function test_DecodeReplace_Roundtrip_RequestRedeemDETH() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(requestRedeemDETH.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = requestRedeemDETH.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(requestRedeemDETH.decodeAmounts(replaced)[0], 5e18);
    }

    /// @dev ApproveAndRequestRedeemDETH: AMOUNT@72
    function test_DecodeReplace_Roundtrip_ApproveRequestRedeemDETH() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(2e18), false);
        bytes memory replaced = approveRequestRedeemDETH.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(approveRequestRedeemDETH.decodeAmounts(replaced)[0], 4e18);
    }

    /// @dev EthenaCooldown: AMOUNT@52
    function test_DecodeReplace_Roundtrip_EthenaCooldown() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(ethenaCooldown.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = ethenaCooldown.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(ethenaCooldown.decodeAmounts(replaced)[0], 6e18);
    }

    /// @dev RedeemFirelight: AMOUNT@52
    function test_DecodeReplace_Roundtrip_RedeemFirelight() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(redeemFirelight.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = redeemFirelight.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(redeemFirelight.decodeAmounts(replaced)[0], 3e18);
    }

    /// @dev MintSuperPositions: AMOUNT@52
    function test_DecodeReplace_Roundtrip_MintSuperPositions() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1000), false);
        assertEq(mintSP.decodeAmounts(data)[0], 1000);

        bytes memory replaced = mintSP.replaceCalldataAmounts(data, _singleAmount(5000));
        assertEq(mintSP.decodeAmounts(replaced)[0], 5000);
    }

    /// @dev BurnSuperPositions: AMOUNT@52
    function test_DecodeReplace_Roundtrip_BurnSuperPositions() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(2000), false);
        assertEq(burnSP.decodeAmounts(data)[0], 2000);

        bytes memory replaced = burnSP.replaceCalldataAmounts(data, _singleAmount(4000));
        assertEq(burnSP.decodeAmounts(replaced)[0], 4000);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Morpho loan hooks (single-amount) roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev MorphoSupply: AMOUNT@80 — 4 addrs(80) + uint256(amt) + uint256(lltv) + bool = 145
    function test_DecodeReplace_Roundtrip_MorphoSupply() public view {
        bytes memory data = _buildMorphoSingleData(1e18);
        assertEq(morphoSupply.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(morphoSupply.decodeAmounts(replaced)[0], 5e18);
    }

    function test_DecodeReplace_Roundtrip_MorphoLend() public view {
        bytes memory data = _buildMorphoSingleData(2e18);
        bytes memory replaced = morphoLend.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(morphoLend.decodeAmounts(replaced)[0], 8e18);
    }

    function test_DecodeReplace_Roundtrip_MorphoBorrow() public view {
        bytes memory data = _buildMorphoSingleData(3e18);
        bytes memory replaced = morphoBorrow.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(morphoBorrow.decodeAmounts(replaced)[0], 6e18);
    }

    function test_DecodeReplace_Roundtrip_MorphoRepay() public view {
        bytes memory data = _buildMorphoSingleData(4e18);
        bytes memory replaced = morphoRepay.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(morphoRepay.decodeAmounts(replaced)[0], 7e18);
    }

    function test_DecodeReplace_Roundtrip_MorphoSupplyAndBorrow() public view {
        bytes memory data = _buildMorphoSingleData(5e18);
        bytes memory replaced = morphoSupplyAndBorrow.replaceCalldataAmounts(data, _singleAmount(9e18));
        assertEq(morphoSupplyAndBorrow.decodeAmounts(replaced)[0], 9e18);
    }

    function test_DecodeReplace_Roundtrip_MorphoRepayAndWithdraw() public view {
        bytes memory data = _buildMorphoSingleData(6e18);
        bytes memory replaced = morphoRepayAndWithdraw.replaceCalldataAmounts(data, _singleAmount(1e18));
        assertEq(morphoRepayAndWithdraw.decodeAmounts(replaced)[0], 1e18);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Aave V4 single-amount hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev AaveV4Supply: AMOUNT@124 — 3 addrs(60) + 2 uint256s(64) + uint256(amt) + bool = 157
    function test_DecodeReplace_Roundtrip_AaveV4Supply() public view {
        bytes memory data = _buildAaveV4SingleData(1e18);
        assertEq(aaveSupply.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = aaveSupply.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(aaveSupply.decodeAmounts(replaced)[0], 5e18);
    }

    function test_DecodeReplace_Roundtrip_AaveV4Withdraw() public view {
        bytes memory data = _buildAaveV4SingleData(2e18);
        bytes memory replaced = aaveWithdraw.replaceCalldataAmounts(data, _singleAmount(8e18));
        assertEq(aaveWithdraw.decodeAmounts(replaced)[0], 8e18);
    }

    function test_DecodeReplace_Roundtrip_AaveV4Borrow() public view {
        bytes memory data = _buildAaveV4SingleData(3e18);
        bytes memory replaced = aaveBorrow.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(aaveBorrow.decodeAmounts(replaced)[0], 6e18);
    }

    function test_DecodeReplace_Roundtrip_AaveV4Repay() public view {
        bytes memory data = _buildAaveV4SingleData(4e18);
        bytes memory replaced = aaveRepay.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(aaveRepay.decodeAmounts(replaced)[0], 7e18);
    }

    /*//////////////////////////////////////////////////////////////
         DECODE + REPLACE: Special hooks roundtrip
    //////////////////////////////////////////////////////////////*/

    /// @dev FetchNativeFee: AMOUNT@72 — 52-byte header + address(sponsor) + uint256(amt) = 104
    function test_DecodeReplace_Roundtrip_FetchNativeFee() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xDEAD), uint256(1e16));
        assertEq(fetchNativeFee.decodeAmounts(data)[0], 1e16);

        bytes memory replaced = fetchNativeFee.replaceCalldataAmounts(data, _singleAmount(5e16));
        assertEq(fetchNativeFee.decodeAmounts(replaced)[0], 5e16);
    }

    /// @dev ClaimFailedTransfer: AMOUNT@92 — 52-byte header + addr(adapter)@52 + addr(token)@72 + uint256(amt)@92 = 124
    function test_DecodeReplace_Roundtrip_ClaimFailedTransfer() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18));
        assertEq(claimFailedTransfer.decodeAmounts(data)[0], 1e18);

        bytes memory replaced = claimFailedTransfer.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(claimFailedTransfer.decodeAmounts(replaced)[0], 3e18);
    }

    /*//////////////////////////////////////////////////////////////
         FUZZ: Category-representative roundtrips
    //////////////////////////////////////////////////////////////*/

    function testFuzz_DecodeReplace_MorphoSupply(uint256 amt) public view {
        bytes memory data = _buildMorphoSingleData(0);
        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(morphoSupply.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_SwapUniswapV3(uint256 amt) public view {
        bytes memory data = _buildSwapperData_128(0);
        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(swapUniV3.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_AcrossV1(uint256 amt) public view {
        bytes memory data = _buildBridgeData_92(0);
        bytes memory replaced = acrossV1.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(acrossV1.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_FluidStake(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(0), false);
        bytes memory replaced = fluidStake.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(fluidStake.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_Deposit5115(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), address(2), uint256(0), uint256(0), false);
        bytes memory replaced = deposit5115.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(deposit5115.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_Redeem7540(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(0), false);
        bytes memory replaced = redeem7540.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(redeem7540.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_AaveV4Supply(uint256 amt) public view {
        bytes memory data = _buildAaveV4SingleData(0);
        bytes memory replaced = aaveSupply.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(aaveSupply.decodeAmounts(replaced)[0], amt);
    }

    function testFuzz_DecodeReplace_AaveV4RepayAndWithdraw(uint256 a, uint256 b) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder (bytes32 + address = 32+20)
            address(1), address(2), address(3), uint256(1), uint256(2), uint256(0), false, false, uint256(0)
        );
        bytes memory replaced = aaveRepayAndWithdraw.replaceCalldataAmounts(data, _dualAmounts(a, b));
        uint256[] memory amounts = aaveRepayAndWithdraw.decodeAmounts(replaced);
        assertEq(amounts[0], a);
        assertEq(amounts[1], b);
    }

    function testFuzz_DecodeReplace_MintSuperPositions(uint256 amt) public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(0), false);
        bytes memory replaced = mintSP.replaceCalldataAmounts(data, _singleAmount(amt));
        assertEq(mintSP.decodeAmounts(replaced)[0], amt);
    }

    /*//////////////////////////////////////////////////////////////
         FIELD PRESERVATION: non-amount fields survive replace
    //////////////////////////////////////////////////////////////*/

    function test_FieldPreservation_MorphoWithdraw() public view {
        address loanTk = address(0xAAAA);
        address collTk = address(0xBBBB);
        address oracle = address(0xCCCC);
        address irm = address(0xDDDD);
        uint256 lltv = 86e16;
        // 52-byte header + 4 addrs(80) + lltv(32) + assets(32) + shares(32)
        bytes memory data = abi.encodePacked(bytes32(0), address(0), loanTk, collTk, oracle, irm, lltv, uint256(1e18), uint256(0));
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(5e18, 0));

        // 52-byte header (bytes [0:52]) preserved
        for (uint256 i; i < 52; ++i) {
            assertEq(replaced[i], data[i], "header bytes mismatch");
        }
        // All 4 addresses (bytes [52:132]) preserved
        for (uint256 i = 52; i < 132; ++i) {
            assertEq(replaced[i], data[i], "address bytes mismatch");
        }
        // LLTV (bytes [132:164]) preserved
        for (uint256 i = 132; i < 164; ++i) {
            assertEq(replaced[i], data[i], "lltv bytes mismatch");
        }
    }

    function test_FieldPreservation_AaveV4SupplyAndBorrow() public view {
        address loanTk = address(0x1111);
        address collTk = address(0x2222);
        address spoke = address(0x3333);
        uint256 supplyResId = 10;
        uint256 borrowResId = 20;
        // 52-byte header + 3 addrs(60) + 2 reserveIds(64) + amount(32) + usePrev(1) + borrowAmount(32)
        bytes memory data = abi.encodePacked(bytes32(0), address(0), loanTk, collTk, spoke, supplyResId, borrowResId, uint256(1e18), false, uint256(5e17));
        bytes memory replaced = aaveSupplyAndBorrow.replaceCalldataAmounts(data, _dualAmounts(9e18, 2e18));

        // 52-byte header (bytes [0:52]) preserved
        for (uint256 i; i < 52; ++i) {
            assertEq(replaced[i], data[i], "header bytes mismatch");
        }
        // 3 addresses (bytes [52:112]) preserved
        for (uint256 i = 52; i < 112; ++i) {
            assertEq(replaced[i], data[i], "address bytes mismatch");
        }
        // 2 reserve IDs (bytes [112:176]) preserved
        for (uint256 i = 112; i < 176; ++i) {
            assertEq(replaced[i], data[i], "reserveId bytes mismatch");
        }
        // usePrevHookAmount bool at [208] preserved
        assertEq(replaced[208], data[208], "usePrev mismatch");
    }

    function test_FieldPreservation_MorphoSupply() public view {
        address loanTk = address(0xAA11);
        address collTk = address(0xBB22);
        address oracle = address(0xCC33);
        address irm = address(0xDD44);
        uint256 lltv = 75e16;
        // 52-byte header + 4 addrs(80) + amount(32) + lltv(32) + usePrev(1)
        bytes memory data = abi.encodePacked(bytes32(0), address(0), loanTk, collTk, oracle, irm, uint256(1e18), lltv, false);
        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(8e18));

        // 52-byte header (bytes [0:52]) preserved
        for (uint256 i; i < 52; ++i) {
            assertEq(replaced[i], data[i], "header bytes mismatch");
        }
        // 4 addresses (bytes [52:132]) preserved
        for (uint256 i = 52; i < 132; ++i) {
            assertEq(replaced[i], data[i], "address bytes mismatch");
        }
        // LLTV at bytes [164:196] preserved
        for (uint256 i = 164; i < 196; ++i) {
            assertEq(replaced[i], data[i], "lltv bytes mismatch");
        }
        // usePrev bool at [196] preserved
        assertEq(replaced[196], data[196], "usePrev mismatch");
    }

    function test_FieldPreservation_SwapUniswapV3() public view {
        bytes memory data = _buildSwapperData_128(1e18);
        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(5e18));

        // Everything before amount (bytes [0:92]) preserved (AMOUNT_POSITION=92)
        for (uint256 i; i < 92; ++i) {
            assertEq(replaced[i], data[i], "prefix bytes mismatch");
        }
        // Everything after amount (bytes [124:]) preserved
        for (uint256 i = 124; i < data.length; ++i) {
            assertEq(replaced[i], data[i], "suffix bytes mismatch");
        }
    }

    /*//////////////////////////////////////////////////////////////
         INVALID_AMOUNTS_LENGTH: more categories
    //////////////////////////////////////////////////////////////*/

    function test_ReplaceAmountsLength_Bridges() public {
        bytes memory data = _buildBridgeData_92(1e18);

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        acrossV1.replaceCalldataAmounts(data, new uint256[](0));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        acrossV1.replaceCalldataAmounts(data, _dualAmounts(1, 2));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        stargate.replaceCalldataAmounts(_buildBridgeData_108(1e18), new uint256[](0));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        cctp.replaceCalldataAmounts(abi.encodePacked(address(1), uint256(1e18), bytes32(0)), _dualAmounts(1, 2));
    }

    function test_ReplaceAmountsLength_Swappers() public {
        bytes memory data = _buildSwapperData_128(1e18);

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapUniV3.replaceCalldataAmounts(data, new uint256[](0));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapUniV3.replaceCalldataAmounts(data, _dualAmounts(1, 2));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapOdosV2.replaceCalldataAmounts(
            abi.encodePacked(address(1), uint256(1e18), address(2), address(3), uint256(0)),
            new uint256[](0)
        );
    }

    function test_ReplaceAmountsLength_Stake() public {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(1e18), false);

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        fluidStake.replaceCalldataAmounts(data, new uint256[](0));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        fluidStake.replaceCalldataAmounts(data, _dualAmounts(1, 2));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        gearboxStake.replaceCalldataAmounts(data, new uint256[](0));
    }

    function test_ReplaceAmountsLength_MorphoLoan() public {
        bytes memory data = _buildMorphoSingleData(1e18);

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoSupply.replaceCalldataAmounts(data, new uint256[](0));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoSupply.replaceCalldataAmounts(data, _dualAmounts(1, 2));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoBorrow.replaceCalldataAmounts(data, new uint256[](0));
    }

    function test_ReplaceAmountsLength_AaveV4Single() public {
        bytes memory data = _buildAaveV4SingleData(1e18);

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveSupply.replaceCalldataAmounts(data, new uint256[](0));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveSupply.replaceCalldataAmounts(data, _dualAmounts(1, 2));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveBorrow.replaceCalldataAmounts(data, new uint256[](0));
    }

    function test_ReplaceAmountsLength_AaveV4RepayAndWithdraw() public {
        bytes memory data = abi.encodePacked(
            address(1), address(2), address(3), uint256(1), uint256(2), uint256(1e18), false, false, uint256(5e17)
        );

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveRepayAndWithdraw.replaceCalldataAmounts(data, _singleAmount(1));

        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveRepayAndWithdraw.replaceCalldataAmounts(data, new uint256[](0));

        uint256[] memory three = new uint256[](3);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveRepayAndWithdraw.replaceCalldataAmounts(data, three);
    }

    /*//////////////////////////////////////////////////////////////
         EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Zero amounts decode correctly
    function test_DecodeAmounts_ZeroAmount() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(0), false);
        assertEq(deposit4626.decodeAmounts(data)[0], 0);
        assertEq(fluidStake.decodeAmounts(data)[0], 0);
        assertEq(mintSP.decodeAmounts(data)[0], 0);
    }

    /// @dev type(uint256).max decodes correctly
    function test_DecodeAmounts_MaxUint256() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), type(uint256).max, false);
        assertEq(deposit4626.decodeAmounts(data)[0], type(uint256).max);
        assertEq(fluidStake.decodeAmounts(data)[0], type(uint256).max);
    }

    /// @dev Replace 0 with non-zero
    function test_ReplaceCalldataAmounts_ZeroToNonzero() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(0), false);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(42e18));
        assertEq(deposit4626.decodeAmounts(replaced)[0], 42e18);
    }

    /// @dev Replace non-zero with 0
    function test_ReplaceCalldataAmounts_NonzeroToZero() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(1), uint256(99e18), false);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(0));
        assertEq(deposit4626.decodeAmounts(replaced)[0], 0);
    }

    /// @dev Replace with same value produces byte-for-byte identical data
    function test_ReplaceCalldataAmounts_Idempotent() public view {
        bytes memory data = abi.encodePacked(bytes32(uint256(0xAB)), address(0xBEEF), uint256(1e18), true);
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(1e18));
        assertEq(keccak256(replaced), keccak256(data));
    }

    /// @dev Idempotent for dual-amount hook
    function test_ReplaceCalldataAmounts_Idempotent_DualAmount() public view {
        // MorphoWithdraw: header(52) + 4 addrs(80) + lltv@132(32) + assets@164(32) + shares@196(32)
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),
            address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(1e18, 0));
        assertEq(keccak256(replaced), keccak256(data));
    }

    /// @dev Verify data length is preserved across all categories
    function test_ReplaceCalldataAmounts_PreservesLength() public view {
        // Deposit4626
        bytes memory d1 = abi.encodePacked(bytes32(0), address(1), uint256(1e18), false);
        assertEq(deposit4626.replaceCalldataAmounts(d1, _singleAmount(2e18)).length, d1.length);

        // MorphoWithdraw: header(52) + 4 addrs(80) + lltv@132(32) + assets@164(32) + shares@196(32)
        bytes memory d2 = abi.encodePacked(bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0));
        assertEq(morphoWithdraw.replaceCalldataAmounts(d2, _dualAmounts(5e18, 0)).length, d2.length);

        // AaveV4SupplyAndBorrow: header(52) + 3 addrs(60) + 2 resIds(64) + supply@176(32) + usePrev@208(1) + borrow@209(32)
        bytes memory d3 = abi.encodePacked(bytes32(0), address(0), address(1), address(2), address(3), uint256(1), uint256(2), uint256(1e18), false, uint256(5e17));
        assertEq(aaveSupplyAndBorrow.replaceCalldataAmounts(d3, _dualAmounts(2e18, 1e18)).length, d3.length);

        // Bridge
        bytes memory d4 = _buildBridgeData_92(1e18);
        assertEq(acrossV1.replaceCalldataAmounts(d4, _singleAmount(2e18)).length, d4.length);

        // Swapper
        bytes memory d5 = _buildSwapperData_128(1e18);
        assertEq(swapUniV3.replaceCalldataAmounts(d5, _singleAmount(2e18)).length, d5.length);
    }

    /*//////////////////////////////////////////////////////////////
            MISSING APPROVE-HOOK ROUNDTRIPS
    //////////////////////////////////////////////////////////////*/

    /// @dev ApproveAndSwapOdosV2: AMOUNT@92 — 52-byte header + inputToken@52 + outputToken@72 + inputAmount@92
    function test_DecodeReplace_Roundtrip_ApproveSwapOdosV2() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0));
        assertEq(approveSwapOdosV2.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapOdosV2.replaceCalldataAmounts(data, _singleAmount(5e18));
        assertEq(approveSwapOdosV2.decodeAmounts(replaced)[0], 5e18);
    }

    /// @dev ApproveAndSwapOdosV3: AMOUNT@92 — 52-byte header + inputToken@52 + outputToken@72 + inputAmount@92
    function test_DecodeReplace_Roundtrip_ApproveSwapOdosV3() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0));
        assertEq(approveSwapOdosV3.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapOdosV3.replaceCalldataAmounts(data, _singleAmount(3e18));
        assertEq(approveSwapOdosV3.decodeAmounts(replaced)[0], 3e18);
    }

    /// @dev ApproveAndSwapSparkPSMExactIn: AMOUNT@92 — 52-byte header + addr + addr + uint256(amount)
    function test_DecodeReplace_Roundtrip_ApproveSwapSparkPSMExactIn() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), address(0xC), uint256(0), false);
        assertEq(approveSwapSparkIn.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapSparkIn.replaceCalldataAmounts(data, _singleAmount(7e18));
        assertEq(approveSwapSparkIn.decodeAmounts(replaced)[0], 7e18);
    }

    /// @dev ApproveAndSwapSparkPSMExactOut: AMOUNT@92 — 52-byte header + addr + addr + uint256(amount)
    function test_DecodeReplace_Roundtrip_ApproveSwapSparkPSMExactOut() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), address(0xC), uint256(0), false);
        assertEq(approveSwapSparkOut.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapSparkOut.replaceCalldataAmounts(data, _singleAmount(4e18));
        assertEq(approveSwapSparkOut.decodeAmounts(replaced)[0], 4e18);
    }

    /// @dev ApproveAndSwapAlgebraIntegral: AMOUNT@144
    function test_DecodeReplace_Roundtrip_ApproveSwapAlgebraIntegral() public view {
        bytes memory data = _buildSwapperData_144(1e18);
        assertEq(approveSwapAlgebra.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapAlgebra.replaceCalldataAmounts(data, _singleAmount(9e18));
        assertEq(approveSwapAlgebra.decodeAmounts(replaced)[0], 9e18);
    }

    /// @dev ApproveAndSwapUniswapV2: AMOUNT@124 (52-byte header + addr(20) + addr(20) + uint256(32))
    function test_DecodeReplace_Roundtrip_ApproveSwapUniswapV2() public view {
        // AMOUNT_POSITION = 92 (52-byte header + addr(20) + addr(20))
        address[] memory path = new address[](2);
        path[0] = address(0xA);
        path[1] = address(0xB);
        bytes memory data = abi.encodePacked(
            bytes32(0), bytes20(address(0)), // 52-byte header
            address(0xA), address(0xB), uint256(1e18), uint256(0), false, abi.encode(uint256(0), path)
        );
        assertEq(approveSwapUniV2.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapUniV2.replaceCalldataAmounts(data, _singleAmount(2e18));
        assertEq(approveSwapUniV2.decodeAmounts(replaced)[0], 2e18);
    }

    /// @dev ApproveAndSwapUniswapV3Router02: AMOUNT@128 — 52-byte header + bytes32 + addr + addr + uint32 + uint256
    function test_DecodeReplace_Roundtrip_ApproveSwapUniswapV3Router02() public view {
        // AMOUNT_POSITION = 92 (52-byte header + addr(20) + addr(20))
        bytes memory data = abi.encodePacked(bytes32(0), bytes20(address(0)), address(0xA), address(0xB), uint256(1e18), uint256(0), false, abi.encode(uint24(3000), uint160(0)));
        assertEq(approveSwapUniV3Router02.decodeAmounts(data)[0], 1e18);
        bytes memory replaced = approveSwapUniV3Router02.replaceCalldataAmounts(data, _singleAmount(6e18));
        assertEq(approveSwapUniV3Router02.decodeAmounts(replaced)[0], 6e18);
    }

    /*//////////////////////////////////////////////////////////////
            EXHAUSTIVE amountRoles().length == decodeAmounts().length
    //////////////////////////////////////////////////////////////*/

    /// @dev Verify length consistency for ALL sized hooks in a single pass
    function test_AmountRolesLength_Equals_DecodeAmountsLength_AllHooks() public view {
        _assertAmountRoles_Tokens();
        _assertAmountRoles_Swappers();
        _assertAmountRoles_Bridges();
        _assertAmountRoles_Loans();
        _assertAmountRoles_Misc();
    }

    function _assertAmountRoles_Tokens() internal view {
        // TOKEN hooks — all use 52-byte header + data layout (just needs enough bytes for amount offset)
        bytes memory tokenData = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0), false);

        assertEq(transferERC20.amountRoles(tokenData).length, transferERC20.decodeAmounts(tokenData).length);
        assertEq(approveERC20.amountRoles(tokenData).length, approveERC20.decodeAmounts(tokenData).length);
        assertEq(transferHook.amountRoles(tokenData).length, transferHook.decodeAmounts(tokenData).length);
        assertEq(nativeTransfer.amountRoles(tokenData).length, nativeTransfer.decodeAmounts(tokenData).length);

        bytes memory wrappedNativeData = abi.encodePacked(bytes32(0), address(0), uint256(1e18), true, false);
        assertEq(wrappedNative.amountRoles(wrappedNativeData).length, wrappedNative.decodeAmounts(wrappedNativeData).length);

        // Stake
        bytes memory stakeData = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(fluidStake.amountRoles(stakeData).length, fluidStake.decodeAmounts(stakeData).length);
        assertEq(fluidUnstake.amountRoles(stakeData).length, fluidUnstake.decodeAmounts(stakeData).length);
        assertEq(gearboxStake.amountRoles(stakeData).length, gearboxStake.decodeAmounts(stakeData).length);
        assertEq(gearboxUnstake.amountRoles(stakeData).length, gearboxUnstake.decodeAmounts(stakeData).length);

        // Vault 4626
        bytes memory vaultData = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(1e18), false);
        assertEq(deposit4626.amountRoles(vaultData).length, deposit4626.decodeAmounts(vaultData).length);
        assertEq(redeem4626.amountRoles(vaultData).length, redeem4626.decodeAmounts(vaultData).length);
        assertEq(approveDeposit4626.amountRoles(vaultData).length, approveDeposit4626.decodeAmounts(vaultData).length);
    }

    function _assertAmountRoles_Swappers() internal view {
        // Swappers
        bytes memory swapData128 = _buildSwapperData_128(1e18);
        assertEq(swapUniV3.amountRoles(swapData128).length, swapUniV3.decodeAmounts(swapData128).length);
        assertEq(approveSwapUniV3.amountRoles(swapData128).length, approveSwapUniV3.decodeAmounts(swapData128).length);

        bytes memory odosData = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), uint256(0), uint256(0));
        assertEq(swapOdosV2.amountRoles(odosData).length, swapOdosV2.decodeAmounts(odosData).length);
        assertEq(swapOdosV3.amountRoles(odosData).length, swapOdosV3.decodeAmounts(odosData).length);
        assertEq(approveSwapOdosV2.amountRoles(odosData).length, approveSwapOdosV2.decodeAmounts(odosData).length);
        assertEq(approveSwapOdosV3.amountRoles(odosData).length, approveSwapOdosV3.decodeAmounts(odosData).length);
    }

    function _assertAmountRoles_Bridges() internal view {
        // Bridges
        bytes memory bridgeData92 = _buildBridgeData_92(1e18);
        assertEq(acrossV1.amountRoles(bridgeData92).length, acrossV1.decodeAmounts(bridgeData92).length);
        assertEq(acrossV2.amountRoles(bridgeData92).length, acrossV2.decodeAmounts(bridgeData92).length);
        assertEq(approveAcrossV1.amountRoles(bridgeData92).length, approveAcrossV1.decodeAmounts(bridgeData92).length);
        assertEq(approveAcrossV2.amountRoles(bridgeData92).length, approveAcrossV2.decodeAmounts(bridgeData92).length);

        bytes memory bridgeData108 = _buildBridgeData_108(1e18);
        assertEq(stargate.amountRoles(bridgeData108).length, stargate.decodeAmounts(bridgeData108).length);
        assertEq(stargateV2.amountRoles(bridgeData108).length, stargateV2.decodeAmounts(bridgeData108).length);
        assertEq(approveStargate.amountRoles(bridgeData108).length, approveStargate.decodeAmounts(bridgeData108).length);
        assertEq(approveStargateV2.amountRoles(bridgeData108).length, approveStargateV2.decodeAmounts(bridgeData108).length);
    }

    function _assertAmountRoles_Loans() internal view {
        // Loan: Morpho
        bytes memory morphoData = _buildMorphoSingleData(1e18);
        assertEq(morphoSupply.amountRoles(morphoData).length, morphoSupply.decodeAmounts(morphoData).length);
        assertEq(morphoLend.amountRoles(morphoData).length, morphoLend.decodeAmounts(morphoData).length);
        assertEq(morphoBorrow.amountRoles(morphoData).length, morphoBorrow.decodeAmounts(morphoData).length);
        assertEq(morphoRepay.amountRoles(morphoData).length, morphoRepay.decodeAmounts(morphoData).length);

        // Loan: MorphoWithdraw (dual) — 52-byte header + 4 addrs(80) + lltv(32) + assets(32) + shares(32)
        bytes memory mwData = abi.encodePacked(
            bytes32(0), address(0),
            address(0xA), address(0xB), address(0xC), address(0xD),
            uint256(86e16), uint256(1e18), uint256(0)
        );
        assertEq(morphoWithdraw.amountRoles(mwData).length, morphoWithdraw.decodeAmounts(mwData).length);

        // Loan: Aave V4
        bytes memory aaveData = _buildAaveV4SingleData(1e18);
        assertEq(aaveSupply.amountRoles(aaveData).length, aaveSupply.decodeAmounts(aaveData).length);
        assertEq(aaveWithdraw.amountRoles(aaveData).length, aaveWithdraw.decodeAmounts(aaveData).length);
        assertEq(aaveBorrow.amountRoles(aaveData).length, aaveBorrow.decodeAmounts(aaveData).length);
        assertEq(aaveRepay.amountRoles(aaveData).length, aaveRepay.decodeAmounts(aaveData).length);

        // Aave V4 compound — 52-byte header + 3 addrs(60) + 2 reserveIds(64) + amount(32) + usePrev(1) + borrowAmount(32)
        bytes memory aaveDualData = abi.encodePacked(
            bytes32(0), address(0),
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(1e18), false, uint256(5e17)
        );
        assertEq(aaveSupplyAndBorrow.amountRoles(aaveDualData).length, aaveSupplyAndBorrow.decodeAmounts(aaveDualData).length);

        // Aave V4 repay+withdraw — 52-byte header + 3 addrs(60) + 2 reserveIds(64) + amount(32) + usePrev(1) + isFullRepayment(1) + withdrawAmount(32)
        bytes memory aaveRwData = abi.encodePacked(
            bytes32(0), address(0),
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(1e18), false, false, uint256(5e17)
        );
        assertEq(aaveRepayAndWithdraw.amountRoles(aaveRwData).length, aaveRepayAndWithdraw.decodeAmounts(aaveRwData).length);
    }

    function _assertAmountRoles_Misc() internal view {
        // Sizeless (true sizeless — decodeAmounts returns [] too)
        bytes memory emptyData = "";
        assertEq(fluidClaim.amountRoles(emptyData).length, fluidClaim.decodeAmounts(emptyData).length);
        assertEq(gearboxClaim.amountRoles(emptyData).length, gearboxClaim.decodeAmounts(emptyData).length);
        assertEq(yearnClaim.amountRoles(emptyData).length, yearnClaim.decodeAmounts(emptyData).length);
        assertEq(merklClaim.amountRoles(emptyData).length, merklClaim.decodeAmounts(emptyData).length);
        assertEq(batchTransfer.amountRoles(emptyData).length, batchTransfer.decodeAmounts(emptyData).length);

        // Decode-only hooks: both decodeAmounts and amountRoles return [] (length 0)
        // requestId is not a sizable amount — it's an NFT/withdrawal receipt ID
        bytes memory dethData = abi.encodePacked(bytes32(0), address(0xA), uint256(42), false);
        assertEq(claimAssetsDETH.decodeAmounts(dethData).length, 0, "DETH decode returns 0");
        assertEq(claimAssetsDETH.amountRoles(dethData).length, 0, "DETH roles returns 0");
        assertEq(claimWithdrawFirelight.decodeAmounts(dethData).length, 0, "Firelight decode returns 0");
        assertEq(claimWithdrawFirelight.amountRoles(dethData).length, 0, "Firelight roles returns 0");
    }

    /*//////////////////////////////////////////////////////////////
            SHORT-DATA / OUT-OF-BOUNDS SAFETY
    //////////////////////////////////////////////////////////////*/

    /// @dev decodeAmounts with data shorter than AMOUNT_POSITION + 32 should revert
    function test_DecodeAmounts_RevertsOnShortData_Deposit4626() public {
        // Deposit4626: AMOUNT@52, needs at least 84 bytes. Send only 60.
        bytes memory shortData = abi.encodePacked(bytes32(0), address(0xA), uint64(0));
        vm.expectRevert();
        deposit4626.decodeAmounts(shortData);
    }

    function test_DecodeAmounts_RevertsOnShortData_SwapUniswapV3() public {
        // SwapUniV3: AMOUNT@128, needs at least 160 bytes. Send only 100.
        bytes memory shortData = new bytes(100);
        vm.expectRevert();
        swapUniV3.decodeAmounts(shortData);
    }

    function test_DecodeAmounts_RevertsOnShortData_AaveV4Supply() public {
        // AaveV4: AMOUNT@124, needs at least 156 bytes. Send only 130.
        bytes memory shortData = new bytes(130);
        vm.expectRevert();
        aaveSupply.decodeAmounts(shortData);
    }

    function test_DecodeAmounts_RevertsOnShortData_MorphoWithdraw() public {
        // MorphoWithdraw: SHARES_OFFSET=144, needs 176 bytes. Send only 150.
        bytes memory shortData = new bytes(150);
        vm.expectRevert();
        morphoWithdraw.decodeAmounts(shortData);
    }

    /// @dev replaceCalldataAmounts with data shorter than needed should revert (Panic 0x32)
    function test_ReplaceCalldataAmounts_RevertsOnShortData_Deposit4626() public {
        bytes memory shortData = new bytes(60);
        vm.expectRevert();
        deposit4626.replaceCalldataAmounts(shortData, _singleAmount(1e18));
    }

    function test_ReplaceCalldataAmounts_RevertsOnShortData_MorphoWithdraw() public {
        bytes memory shortData = new bytes(150);
        vm.expectRevert();
        morphoWithdraw.replaceCalldataAmounts(shortData, _dualAmounts(1e18, 0));
    }

    function test_ReplaceCalldataAmounts_RevertsOnShortData_AaveV4SupplyAndBorrow() public {
        // Needs 189 bytes minimum. Send only 160.
        bytes memory shortData = new bytes(160);
        vm.expectRevert();
        aaveSupplyAndBorrow.replaceCalldataAmounts(shortData, _dualAmounts(1e18, 5e17));
    }

    /// @dev replaceCalldataAmounts with empty data should revert
    function test_ReplaceCalldataAmounts_RevertsOnEmptyData_SingleAmount() public {
        bytes memory emptyData = "";
        vm.expectRevert();
        transferERC20.replaceCalldataAmounts(emptyData, _singleAmount(1e18));
    }

    /*//////////////////////////////////////////////////////////////
            MorphoWithdraw XOR ADDITIONAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    /// @dev Replace assets-only → shares-only should work (toggle denominations)
    function test_MorphoWithdraw_ReplaceCalldataAmounts_ToggleDenomination() public view {
        // Start with assets=1e18, shares=0 (with 52-byte header)
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),
            address(0xA), address(0xB), address(0xC), address(0xD),
            uint256(86e16), uint256(1e18), uint256(0)
        );
        uint256[] memory decoded = morphoWithdraw.decodeAmounts(data);
        assertEq(decoded[0], 1e18);
        assertEq(decoded[1], 0);

        // Toggle to assets=0, shares=5e17
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(0, 5e17));
        uint256[] memory decoded2 = morphoWithdraw.decodeAmounts(replaced);
        assertEq(decoded2[0], 0);
        assertEq(decoded2[1], 5e17);
    }

    /// @dev Max uint256 in assets slot should still work (XOR with shares=0)
    function test_MorphoWithdraw_ReplaceCalldataAmounts_MaxAssets() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),
            address(0xA), address(0xB), address(0xC), address(0xD),
            uint256(86e16), uint256(1e18), uint256(0)
        );
        bytes memory replaced = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(type(uint256).max, 0));
        assertEq(morphoWithdraw.decodeAmounts(replaced)[0], type(uint256).max);
        assertEq(morphoWithdraw.decodeAmounts(replaced)[1], 0);
    }

    /*//////////////////////////////////////////////////////////////
            FIELD PRESERVATION — ADDITIONAL HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @dev Across bridge: replacing amount preserves all other fields
    function test_FieldPreservation_AcrossV1() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder header
            uint256(42),        // value (at 52)
            address(0xAA),      // recipient (at 84)
            address(0xBB),      // inputToken (at 104)
            address(0xCC),      // outputToken (at 124)
            uint256(1e18),      // inputAmount at 144
            uint256(999),       // outputAmount
            uint32(137),        // destinationChainId
            address(0xDD),      // exclusiveRelayer
            uint32(100),        // quoteTimestamp
            uint32(200),        // fillDeadline
            uint32(300),        // exclusivityDeadline
            bytes("")           // message
        );
        bytes memory replaced = acrossV1.replaceCalldataAmounts(data, _singleAmount(7e18));
        // Check amount was replaced
        assertEq(acrossV1.decodeAmounts(replaced)[0], 7e18);
        // Check non-amount fields preserved (first 144 bytes untouched)
        for (uint256 i; i < 144; ++i) {
            assertEq(replaced[i], data[i], "prefix byte mismatch");
        }
        // Check bytes after the 32-byte amount field are preserved
        for (uint256 i = 176; i < data.length; ++i) {
            assertEq(replaced[i], data[i], "suffix byte mismatch");
        }
    }

    /// @dev AaveV4RepayAndWithdraw: replacing both amounts preserves isFullRepayment flag at byte 209
    function test_FieldPreservation_AaveV4RepayAndWithdraw_IsFullRepaymentFlag() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder header
            address(0xAA),      // loanToken (at 52)
            address(0xBB),      // collateralToken (at 72)
            address(0xCC),      // spoke (at 92)
            uint256(1),         // supplyReserveId (at 112)
            uint256(2),         // borrowReserveId (at 144)
            uint256(1e18),      // repay amount at 176 (32)
            false,              // usePrevHookAmount at 208 (1)
            true,               // isFullRepayment at 209 (1) ← MUST be preserved
            uint256(5e17)       // withdraw amount at 210 (32)
        );

        bytes memory replaced = aaveRepayAndWithdraw.replaceCalldataAmounts(data, _dualAmounts(2e18, 3e17));
        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[0], 2e18);
        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[1], 3e17);
        // Byte 208 (usePrevHookAmount=false) and byte 209 (isFullRepayment=true) must be preserved
        assertEq(uint8(replaced[208]), 0x00, "usePrevHookAmount corrupted");
        assertEq(uint8(replaced[209]), 0x01, "isFullRepayment corrupted");
    }

    /*//////////////////////////////////////////////////////////////
         SECURITY FIX INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    // ─── MorphoWithdraw: XOR check fires BEFORE data mutation ───

    /// @dev Verify that when XOR revert fires, the original data bytes are NOT mutated
    ///      (check-before-mutate pattern)
    function test_MorphoWithdraw_XOR_DataUnmodifiedOnRevert() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),
            address(1), address(2), address(3), address(4),
            uint256(86e16), uint256(7e18), uint256(0)
        );
        bytes memory snapshot = new bytes(data.length);
        for (uint256 i; i < data.length; ++i) snapshot[i] = data[i];

        // Both-nonzero → revert before mutation
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(1e18, 1e18));

        // data should be bit-identical to snapshot (no partial write occurred)
        assertEq(keccak256(data), keccak256(snapshot), "data mutated despite revert");
    }

    /// @dev Fuzz: XOR revert always fires before mutation for any invalid pair
    function testFuzz_MorphoWithdraw_XOR_NeverPartiallyMutates(uint256 a, uint256 b) public {
        // Only test invalid pairs (both zero or both nonzero)
        vm.assume((a == 0 && b == 0) || (a != 0 && b != 0));

        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),
            address(1), address(2), address(3), address(4),
            uint256(86e16), uint256(42), uint256(0)
        );
        bytes32 before = keccak256(data);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(a, b));

        assertEq(keccak256(data), before, "data mutated on revert path");
    }

    /// @dev Valid XOR pairs (exactly one nonzero) should succeed and roundtrip
    function testFuzz_MorphoWithdraw_XOR_ValidPairsSucceed(uint256 val) public view {
        vm.assume(val != 0);

        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),
            address(1), address(2), address(3), address(4),
            uint256(86e16), uint256(0), uint256(0)
        );

        // assets-only
        bytes memory r1 = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(val, 0));
        assertEq(morphoWithdraw.decodeAmounts(r1)[0], val);
        assertEq(morphoWithdraw.decodeAmounts(r1)[1], 0);

        // shares-only
        bytes memory r2 = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(0, val));
        assertEq(morphoWithdraw.decodeAmounts(r2)[0], 0);
        assertEq(morphoWithdraw.decodeAmounts(r2)[1], val);
    }

    // ─── AaveV4RepayAndWithdraw: isFullRepayment flag interaction ───

    /// @dev When isFullRepayment=true, replaceCalldataAmounts still works (byte-level)
    ///      but the flag itself is preserved and amounts are irrelevant to build()
    function test_AaveV4RepayAndWithdraw_FullRepayment_ReplacePreservesFlag() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder header
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2),
            uint256(1e18),      // repay amount at 176
            false,              // usePrevHookAmount at 208
            true,               // isFullRepayment at 209
            uint256(5e17)       // withdraw amount at 210
        );

        // Replace both amounts
        bytes memory replaced = aaveRepayAndWithdraw.replaceCalldataAmounts(data, _dualAmounts(999, 888));

        // Amounts are replaced at the byte level
        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[0], 999);
        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[1], 888);

        // Flags preserved
        assertEq(uint8(replaced[208]), 0x00, "usePrevHookAmount corrupted");
        assertEq(uint8(replaced[209]), 0x01, "isFullRepayment must survive");
    }

    /// @dev When isFullRepayment=false, amounts and flag are all preserved correctly
    function test_AaveV4RepayAndWithdraw_NotFullRepayment_ReplacePreservesFlag() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder header
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2),
            uint256(1e18),      // repay amount at 176
            false,              // usePrevHookAmount at 208
            false,              // isFullRepayment at 209
            uint256(5e17)       // withdraw amount at 210
        );

        bytes memory replaced = aaveRepayAndWithdraw.replaceCalldataAmounts(data, _dualAmounts(3e18, 2e18));

        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[0], 3e18);
        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[1], 2e18);
        assertEq(uint8(replaced[208]), 0x00);
        assertEq(uint8(replaced[209]), 0x00, "isFullRepayment=false must survive");
    }

    /// @dev Fuzz: isFullRepayment flag is never corrupted regardless of amount values
    function testFuzz_AaveV4RepayAndWithdraw_FlagPreservation(uint256 repay, uint256 withdraw, bool fullRepay) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder header
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2),
            uint256(1e18),
            false,
            fullRepay,
            uint256(5e17)
        );

        bytes memory replaced = aaveRepayAndWithdraw.replaceCalldataAmounts(data, _dualAmounts(repay, withdraw));

        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[0], repay);
        assertEq(aaveRepayAndWithdraw.decodeAmounts(replaced)[1], withdraw);
        // The critical flag must survive any amount replacement
        assertEq(uint8(replaced[209]), fullRepay ? 0x01 : 0x00, "isFullRepayment corrupted by replace");
        assertEq(uint8(replaced[208]), 0x00, "usePrevHookAmount corrupted by replace");
    }

    // ─── ClaimAssetsDETH / ClaimWithdrawFirelight: ERC-165 correctness ───

    /// @dev Decode-only hooks: ISuperHookInflowOutflow=true, ISuperHookOutflow=false
    function test_DecodeOnly_ERC165_FullMatrix() public view {
        bytes4 inflowOutflow = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflow = type(ISuperHookOutflow).interfaceId;
        bytes4 erc165 = type(IERC165).interfaceId;
        bytes4 hook = type(ISuperHook).interfaceId;
        bytes4 result = type(ISuperHookResult).interfaceId;
        bytes4 inspector = type(ISuperHookInspector).interfaceId;

        // ClaimAssetsDETH
        assertTrue(claimAssetsDETH.supportsInterface(inflowOutflow), "DETH: ISuperHookInflowOutflow");
        assertFalse(claimAssetsDETH.supportsInterface(outflow), "DETH: ISuperHookOutflow should be false");
        assertTrue(claimAssetsDETH.supportsInterface(erc165), "DETH: IERC165");
        assertTrue(claimAssetsDETH.supportsInterface(hook), "DETH: ISuperHook");
        assertTrue(claimAssetsDETH.supportsInterface(result), "DETH: ISuperHookResult");
        assertTrue(claimAssetsDETH.supportsInterface(inspector), "DETH: ISuperHookInspector");
        assertFalse(claimAssetsDETH.supportsInterface(bytes4(0xdeadbeef)), "DETH: garbage");

        // ClaimWithdrawFirelight
        assertTrue(claimWithdrawFirelight.supportsInterface(inflowOutflow), "FL: ISuperHookInflowOutflow");
        assertFalse(claimWithdrawFirelight.supportsInterface(outflow), "FL: ISuperHookOutflow should be false");
        assertTrue(claimWithdrawFirelight.supportsInterface(erc165), "FL: IERC165");
        assertTrue(claimWithdrawFirelight.supportsInterface(hook), "FL: ISuperHook");
        assertTrue(claimWithdrawFirelight.supportsInterface(result), "FL: ISuperHookResult");
        assertTrue(claimWithdrawFirelight.supportsInterface(inspector), "FL: ISuperHookInspector");
        assertFalse(claimWithdrawFirelight.supportsInterface(bytes4(0xdeadbeef)), "FL: garbage");
    }

    /// @dev Sized hooks (regular ones) must support BOTH ISuperHookInflowOutflow AND ISuperHookOutflow
    ///      Decode-only hooks must support only ISuperHookInflowOutflow
    ///      This tests the boundary between the two categories
    function test_ERC165_SizedVsDecodeOnly_Boundary() public view {
        bytes4 outflow = type(ISuperHookOutflow).interfaceId;
        bytes4 inflowOutflow = type(ISuperHookInflowOutflow).interfaceId;

        // Representative sized hooks — both interfaces true
        assertTrue(deposit4626.supportsInterface(inflowOutflow));
        assertTrue(deposit4626.supportsInterface(outflow));
        assertTrue(morphoWithdraw.supportsInterface(inflowOutflow));
        assertTrue(morphoWithdraw.supportsInterface(outflow));
        assertTrue(aaveRepayAndWithdraw.supportsInterface(inflowOutflow));
        assertTrue(aaveRepayAndWithdraw.supportsInterface(outflow));

        // Sizeless hooks — both interfaces true (they have replaceCalldataAmounts accepting [])
        assertTrue(fluidClaim.supportsInterface(inflowOutflow));
        assertTrue(fluidClaim.supportsInterface(outflow));

        // Decode-only hooks — ISuperHookInflowOutflow true, ISuperHookOutflow FALSE
        assertTrue(claimAssetsDETH.supportsInterface(inflowOutflow));
        assertFalse(claimAssetsDETH.supportsInterface(outflow));
        assertTrue(claimWithdrawFirelight.supportsInterface(inflowOutflow));
        assertFalse(claimWithdrawFirelight.supportsInterface(outflow));
    }

    /// @dev Decode-only hooks return empty from both decodeAmounts AND amountRoles
    ///      with any data input (including empty)
    function test_DecodeOnly_EmptyArraysWithAnyData() public view {
        bytes[] memory inputs = new bytes[](3);
        inputs[0] = "";
        inputs[1] = abi.encodePacked(bytes32(0));
        inputs[2] = abi.encodePacked(bytes32(0), address(1), uint256(99), false);

        for (uint256 i; i < inputs.length; ++i) {
            assertEq(claimAssetsDETH.decodeAmounts(inputs[i]).length, 0);
            assertEq(claimAssetsDETH.amountRoles(inputs[i]).length, 0);
            assertEq(claimWithdrawFirelight.decodeAmounts(inputs[i]).length, 0);
            assertEq(claimWithdrawFirelight.amountRoles(inputs[i]).length, 0);
        }
    }

    // ─── Cross-category: exhaustive roundtrip on every hook category ───

    /// @dev Verify decode→replace→decode roundtrip for representative hooks from EACH denomination
    function test_Roundtrip_AllDenominations() public view {
        // TOKEN — 52-byte header + addr(token) + addr(to) + uint256(amount) + bool
        bytes memory tokenData = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), false);
        bytes memory tokenReplaced = transferERC20.replaceCalldataAmounts(tokenData, _singleAmount(2e18));
        assertEq(transferERC20.decodeAmounts(tokenReplaced)[0], 2e18, "TOKEN roundtrip");

        // ASSETS — bytes32(oracleId) + addr(vault) + uint256(amount) + bool (first 52 bytes = header)
        bytes memory assetData = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        bytes memory assetReplaced = deposit4626.replaceCalldataAmounts(assetData, _singleAmount(3e18));
        assertEq(deposit4626.decodeAmounts(assetReplaced)[0], 3e18, "ASSETS roundtrip");

        // SHARES — bytes32(oracleId) + addr(vault) + addr(owner) + uint256(shares) + bool
        bytes memory shareData = abi.encodePacked(bytes32(0), address(0xA), address(0xB), uint256(1e18), false);
        bytes memory shareReplaced = redeem4626.replaceCalldataAmounts(shareData, _singleAmount(4e18));
        assertEq(redeem4626.decodeAmounts(shareReplaced)[0], 4e18, "SHARES roundtrip");

        // DUAL (Morpho assets+shares) — 52-byte header + 4 addrs + lltv + assets + shares
        bytes memory dualData = abi.encodePacked(
            bytes32(0), address(0),
            address(1), address(2), address(3), address(4),
            uint256(86e16), uint256(5e18), uint256(0)
        );
        bytes memory dualReplaced = morphoWithdraw.replaceCalldataAmounts(dualData, _dualAmounts(6e18, 0));
        assertEq(morphoWithdraw.decodeAmounts(dualReplaced)[0], 6e18, "DUAL assets roundtrip");
        assertEq(morphoWithdraw.decodeAmounts(dualReplaced)[1], 0, "DUAL shares roundtrip");

        // DUAL (Aave repay+withdraw) — 52-byte header + 3 addrs + 2 reserveIds + amount + usePrev + isFullRepayment + withdrawAmount
        bytes memory aaveData = abi.encodePacked(
            bytes32(0), address(0),
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(1e18), false, false, uint256(5e17)
        );
        bytes memory aaveReplaced = aaveRepayAndWithdraw.replaceCalldataAmounts(aaveData, _dualAmounts(7e18, 8e18));
        assertEq(aaveRepayAndWithdraw.decodeAmounts(aaveReplaced)[0], 7e18, "AAVE repay roundtrip");
        assertEq(aaveRepayAndWithdraw.decodeAmounts(aaveReplaced)[1], 8e18, "AAVE withdraw roundtrip");
    }

    /// @dev Verify length preservation across ALL hook categories after replace
    function test_LengthPreservation_AllCategories() public view {
        // Token: header(52) + token(20) + to(20) + amount@92(32) + usePrev(1)
        bytes memory d1 = abi.encodePacked(bytes32(0), address(0), address(0xA), address(0xB), uint256(1e18), false);
        assertEq(transferERC20.replaceCalldataAmounts(d1, _singleAmount(2e18)).length, d1.length);

        // Swapper
        bytes memory d2 = _buildSwapperData_128(1e18);
        assertEq(swapUniV3.replaceCalldataAmounts(d2, _singleAmount(2e18)).length, d2.length);

        // Bridge
        bytes memory d3 = _buildBridgeData_92(1e18);
        assertEq(acrossV1.replaceCalldataAmounts(d3, _singleAmount(2e18)).length, d3.length);

        // Stake
        bytes memory d4 = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(fluidStake.replaceCalldataAmounts(d4, _singleAmount(2e18)).length, d4.length);

        // Vault 4626
        bytes memory d5 = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        assertEq(deposit4626.replaceCalldataAmounts(d5, _singleAmount(2e18)).length, d5.length);

        // Morpho single
        bytes memory d6 = _buildMorphoSingleData(1e18);
        assertEq(morphoSupply.replaceCalldataAmounts(d6, _singleAmount(2e18)).length, d6.length);

        // MorphoWithdraw dual: header(52) + 4 addrs(80) + lltv@132(32) + assets@164(32) + shares@196(32)
        bytes memory d7 = abi.encodePacked(
            bytes32(0), address(0),
            address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        assertEq(morphoWithdraw.replaceCalldataAmounts(d7, _dualAmounts(2e18, 0)).length, d7.length);

        // Aave V4 single
        bytes memory d8 = _buildAaveV4SingleData(1e18);
        assertEq(aaveSupply.replaceCalldataAmounts(d8, _singleAmount(2e18)).length, d8.length);

        // Aave V4 dual: header(52) + 3 addrs(60) + 2 resIds(64) + repay@176(32) + usePrev@208(1) + isFullRepay@209(1) + withdraw@210(32)
        bytes memory d9 = abi.encodePacked(
            bytes32(0), address(0),
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(1e18), false, false, uint256(5e17)
        );
        assertEq(aaveRepayAndWithdraw.replaceCalldataAmounts(d9, _dualAmounts(2e18, 3e17)).length, d9.length);

        // Sizeless
        bytes memory d10 = abi.encodePacked(bytes32(0), address(1), address(2));
        assertEq(fluidClaim.replaceCalldataAmounts(d10, new uint256[](0)).length, d10.length);
    }

    // ─── amountRoles denomination correctness across all categories ───

    /// @dev Verify every denomination type is correctly reported
    function test_AmountRoles_DenominationCorrectness_AllCategories() public view {
        // TOKEN hooks
        _assertSingleMeta(
            transferERC20.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.TOKEN
        );
        _assertSingleMeta(
            swapUniV3.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.TOKEN
        );
        _assertSingleMeta(
            acrossV1.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.TOKEN
        );
        _assertSingleMeta(
            fluidStake.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.TOKEN
        );

        // ASSETS hooks
        _assertSingleMeta(
            deposit4626.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.ASSETS
        );
        _assertSingleMeta(
            deposit5115.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.ASSETS
        );
        _assertSingleMeta(
            withdraw7540.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.ASSETS
        );

        // SHARES hooks
        _assertSingleMeta(
            redeem4626.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.SHARES
        );
        _assertSingleMeta(
            redeem5115.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.SHARES
        );
        _assertSingleMeta(
            ethenaCooldown.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.SHARES
        );
        _assertSingleMeta(
            mintSP.amountRoles(""),
            ISuperHookInflowOutflow.Direction.IN,
            ISuperHookInflowOutflow.Denomination.SHARES
        );

        // Morpho dual: ASSETS + SHARES
        ISuperHookInflowOutflow.AmountMeta[] memory mwMeta = morphoWithdraw.amountRoles("");
        assertEq(mwMeta.length, 2);
        assertEq(uint8(mwMeta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(mwMeta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.ASSETS));
        assertEq(uint8(mwMeta[1].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(mwMeta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.SHARES));

        // Aave V4 compound: TOKEN(IN) + TOKEN(OUT)
        ISuperHookInflowOutflow.AmountMeta[] memory aaveMeta = aaveSupplyAndBorrow.amountRoles("");
        assertEq(aaveMeta.length, 2);
        assertEq(uint8(aaveMeta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(aaveMeta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
        assertEq(uint8(aaveMeta[1].dir), uint8(ISuperHookInflowOutflow.Direction.OUT));
        assertEq(uint8(aaveMeta[1].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    // ─── INVALID_AMOUNTS_LENGTH across all categories ───

    /// @dev Comprehensive test: every hook category rejects wrong-length amounts arrays
    function test_InvalidAmountsLength_AllCategories() public {
        // Single-amount hooks reject length 0 and length 2
        bytes memory tokenData = abi.encodePacked(address(0xA), address(0xB), uint256(1e18), false);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        transferERC20.replaceCalldataAmounts(tokenData, new uint256[](0));
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        transferERC20.replaceCalldataAmounts(tokenData, _dualAmounts(1, 2));

        // Swapper
        bytes memory swapData = _buildSwapperData_128(1e18);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapUniV3.replaceCalldataAmounts(swapData, new uint256[](0));
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapUniV3.replaceCalldataAmounts(swapData, _dualAmounts(1, 2));

        // Bridge
        bytes memory bridgeData = _buildBridgeData_92(1e18);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        acrossV1.replaceCalldataAmounts(bridgeData, new uint256[](0));

        // Stake
        bytes memory stakeData = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        fluidStake.replaceCalldataAmounts(stakeData, new uint256[](0));

        // Vault
        bytes memory vaultData = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        deposit4626.replaceCalldataAmounts(vaultData, new uint256[](0));

        // Morpho single
        bytes memory morphoData = _buildMorphoSingleData(1e18);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoSupply.replaceCalldataAmounts(morphoData, _dualAmounts(1, 2));

        // MorphoWithdraw (expects 2)
        bytes memory mwData = abi.encodePacked(
            address(1), address(2), address(3), address(4), uint256(86e16), uint256(1e18), uint256(0)
        );
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        morphoWithdraw.replaceCalldataAmounts(mwData, _singleAmount(1e18));

        // Aave single (expects 1)
        bytes memory aaveData = _buildAaveV4SingleData(1e18);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveSupply.replaceCalldataAmounts(aaveData, _dualAmounts(1, 2));

        // Aave dual (expects 2)
        bytes memory aaveDualData = abi.encodePacked(
            address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(1e18), false, false, uint256(5e17)
        );
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        aaveRepayAndWithdraw.replaceCalldataAmounts(aaveDualData, _singleAmount(1));

        // Sizeless (expects 0)
        bytes memory sData = abi.encodePacked(bytes32(0), address(1));
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        fluidClaim.replaceCalldataAmounts(sData, _singleAmount(1));
    }

    // ─── Multiple replace operations: idempotent and composable ───

    /// @dev Replace the same amount twice → second replace is idempotent
    function test_DoubleReplace_Idempotent() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        bytes memory r1 = deposit4626.replaceCalldataAmounts(data, _singleAmount(5e18));
        bytes memory r2 = deposit4626.replaceCalldataAmounts(r1, _singleAmount(5e18));
        assertEq(keccak256(r1), keccak256(r2), "double replace should be idempotent");
    }

    /// @dev Replace → replace with different value → decode shows latest
    function test_DoubleReplace_LatestWins() public view {
        bytes memory data = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        bytes memory r1 = deposit4626.replaceCalldataAmounts(data, _singleAmount(5e18));
        bytes memory r2 = deposit4626.replaceCalldataAmounts(r1, _singleAmount(9e18));
        assertEq(deposit4626.decodeAmounts(r2)[0], 9e18);
    }

    /// @dev Replace dual amounts: morpho XOR remains enforced on second replace
    function test_DoubleReplace_MorphoWithdraw_XORStillEnforced() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4),
            uint256(86e16), uint256(1e18), uint256(0)
        );
        bytes memory r1 = morphoWithdraw.replaceCalldataAmounts(data, _dualAmounts(2e18, 0));
        // Second replace: switch from assets to shares
        bytes memory r2 = morphoWithdraw.replaceCalldataAmounts(r1, _dualAmounts(0, 3e18));
        assertEq(morphoWithdraw.decodeAmounts(r2)[0], 0);
        assertEq(morphoWithdraw.decodeAmounts(r2)[1], 3e18);

        // Second replace with invalid pair still reverts
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        morphoWithdraw.replaceCalldataAmounts(r1, _dualAmounts(1, 1));
    }

    // ─── Edge values: boundary conditions ───

    /// @dev type(uint256).max survives decode→replace→decode roundtrip
    function test_MaxUint256_Roundtrip_AllHookTypes() public view {
        uint256 maxVal = type(uint256).max;

        // Single-amount: deposit4626
        bytes memory d1 = abi.encodePacked(bytes32(0), address(0xA), uint256(0), false);
        bytes memory r1 = deposit4626.replaceCalldataAmounts(d1, _singleAmount(maxVal));
        assertEq(deposit4626.decodeAmounts(r1)[0], maxVal, "4626 max");

        // Dual-amount: MorphoWithdraw (assets slot only)
        bytes memory d2 = abi.encodePacked(
            bytes32(0), address(0), address(1), address(2), address(3), address(4), uint256(86e16), uint256(0), uint256(0)
        );
        bytes memory r2 = morphoWithdraw.replaceCalldataAmounts(d2, _dualAmounts(maxVal, 0));
        assertEq(morphoWithdraw.decodeAmounts(r2)[0], maxVal, "morpho max");

        // Dual-amount: Aave V4 RepayAndWithdraw
        bytes memory d3 = abi.encodePacked(
            bytes32(0), address(0), address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(0), false, false, uint256(0)
        );
        bytes memory r3 = aaveRepayAndWithdraw.replaceCalldataAmounts(d3, _dualAmounts(maxVal, maxVal));
        assertEq(aaveRepayAndWithdraw.decodeAmounts(r3)[0], maxVal, "aave repay max");
        assertEq(aaveRepayAndWithdraw.decodeAmounts(r3)[1], maxVal, "aave withdraw max");
    }

    /// @dev Zero amounts survive decode→replace→decode roundtrip
    function test_ZeroAmount_Roundtrip_AllHookTypes() public view {
        // Single-amount: replace nonzero with zero
        bytes memory d1 = abi.encodePacked(bytes32(0), address(0xA), uint256(1e18), false);
        bytes memory r1 = deposit4626.replaceCalldataAmounts(d1, _singleAmount(0));
        assertEq(deposit4626.decodeAmounts(r1)[0], 0, "4626 zero");

        // Dual-amount: aave (both zero is allowed — no XOR constraint)
        bytes memory d2 = abi.encodePacked(
            bytes32(0), address(0), address(0xAA), address(0xBB), address(0xCC),
            uint256(1), uint256(2), uint256(1e18), false, false, uint256(5e17)
        );
        bytes memory r2 = aaveRepayAndWithdraw.replaceCalldataAmounts(d2, _dualAmounts(0, 0));
        assertEq(aaveRepayAndWithdraw.decodeAmounts(r2)[0], 0, "aave repay zero");
        assertEq(aaveRepayAndWithdraw.decodeAmounts(r2)[1], 0, "aave withdraw zero");
    }

    /*//////////////////////////////////////////////////////////////
                    HELPERS
    //////////////////////////////////////////////////////////////*/

    function _assertSingleMeta(
        ISuperHookInflowOutflow.AmountMeta[] memory meta,
        ISuperHookInflowOutflow.Direction expectedDir,
        ISuperHookInflowOutflow.Denomination expectedDenom
    )
        internal
        pure
    {
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0].dir), uint8(expectedDir));
        assertEq(uint8(meta[0].denom), uint8(expectedDenom));
    }

    /// @dev Build bridge data with AMOUNT@144: placeholder(52) + uint256(32) + addr(20) + addr(20) + addr(20) + uint256(amt) + padding
    function _buildBridgeData_92(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder (bytes32 + address = 32+20)
            uint256(1),         // dstChainId (32)
            address(0xAA),      // recipient (20)
            address(0xBB),      // inputToken (20)
            address(0xCC),      // outputToken (20)
            amt,                // amount at offset 144 (32)
            uint256(0),         // outputAmount (32)
            uint256(0)          // fillDeadline (32)
        );
    }

    /// @dev Build bridge data with AMOUNT@160: placeholder(52) + uint256(32) + addr(20) + addr(20) + uint32(4) + bytes32(32) + uint256(amt) + padding
    function _buildBridgeData_108(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder (bytes32 + address = 32+20)
            uint256(1),         // dstChainId (32)
            address(0xAA),      // pool (20)
            address(0xBB),      // token (20)
            uint32(1),          // dstEid (4)
            bytes32(0),         // to (32)
            amt,                // amount at offset 160 (32)
            uint256(0)          // minAmountLD (32)
        );
    }

    /// @dev Build UniswapV3 swapper data (3-layer format): header(52) + inputToken(20) + outputToken(20) + AMOUNT@92(32) + outputQuote(32) + outputMin(32) + usePrev(1) + payloadLen(32) + fee(4) + deadline(32) + sqrtPrice(32)
    function _buildSwapperData_128(uint256 amt) internal pure returns (bytes memory) {
        bytes memory payload = abi.encode(uint24(3000), uint256(9999999999), uint160(0));
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte header
            address(0xAA),          // inputToken @52
            address(0xBB),          // outputToken @72
            amt,                    // inputAmount @92 (AMOUNT_POSITION)
            uint256(0),             // outputQuote @124
            uint256(0),             // outputMin @156
            false,                  // usePrevHookAmount @188
            payload.length,         // payloadLength @189
            payload
        );
    }

    /// @dev Build swapper data with AMOUNT@172: placeholder(52) + addr + addr + uint32 + uint32 + addr + addr + uint256 + uint256(amt) + uint256 + uint256 + bool + bool
    function _buildSwapperData_120(uint256 amt) internal pure returns (bytes memory) {
        // New layout: placeholder(52) + currency0(20) + currency1(20) + amountIn(32) + amountOutMin(32) + zeroForOne(1) + usePrevHookAmount(1) + abi.encode(payload)
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder
            address(0xAA),          // currency0 (20)
            address(0xBB),          // currency1 (20)
            amt,                    // amountIn at pos 92 (32)
            uint256(0),             // amountOutMin (32)
            false,                  // zeroForOne (1)
            false,                  // usePrevHookAmount (1)
            abi.encode(uint24(3000), int24(60), address(0xCC), address(0xDD), uint160(0), uint256(0), bytes(""))
        );
    }

    /// @dev Build AlgebraIntegral swapper data (3-layer format): header(52) + inputToken(20) + outputToken(20) + AMOUNT@92(32) + outputQuote(32) + outputMin(32) + usePrev(1) + payloadLen(32) + payload = abi.encode(deployer, deadline, limitSqrtPrice)
    function _buildSwapperData_144(uint256 amt) internal pure returns (bytes memory) {
        bytes memory payload = abi.encode(address(0), uint256(9999999999), uint160(0));
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte header
            address(0xAA),          // inputToken @52
            address(0xBB),          // outputToken @72
            amt,                    // inputAmount @92 (AMOUNT_POSITION)
            uint256(0),             // outputQuote @124
            uint256(0),             // outputMin @156
            false,                  // usePrevHookAmount @188
            payload.length,         // payloadLength @189
            payload
        );
    }

    /// @dev Build Morpho single-amount data: placeholder(52) + 4 addrs(80) + uint256(amt@132) + uint256(lltv) + bool
    function _buildMorphoSingleData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder (bytes32 + address = 32+20)
            address(0xAA),      // loanToken (20)
            address(0xBB),      // collateralToken (20)
            address(0xCC),      // oracle (20)
            address(0xDD),      // irm (20)
            amt,                // amount at offset 132 (32)
            uint256(86e16),     // lltv (32)
            false               // usePrev (1)
        );
    }

    /// @dev Build Aave V4 single-amount data: placeholder(52) + 3 addrs(60) + 2 uint256s(64) + uint256(amt@176) + bool
    function _buildAaveV4SingleData(uint256 amt) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), address(0), // 52-byte placeholder (bytes32 + address = 32+20)
            address(0xAA),      // loanToken (20)
            address(0xBB),      // collateralToken (20)
            address(0xCC),      // spoke (20)
            uint256(1),         // supplyReserveId (32)
            uint256(2),         // borrowReserveId (32)
            amt,                // amount at offset 176 (32)
            false               // usePrev (1)
        );
    }

    // ═══════════════════════════════════════════════════════════════════
    //  COMBINED: usePrevHookAmount + decodeAmounts + replaceCalldataAmounts
    // ═══════════════════════════════════════════════════════════════════

    /// @notice Vault 4626: decode amount, replace it, verify usePrevHookAmount flag preserved
    function test_Combined_Deposit4626_DecodeReplaceUsePrev() public view {
        // Build data with usePrevHookAmount = true
        bytes memory data = abi.encodePacked(
            bytes32(uint256(0xDEAD)),   // yieldSourceOracleId (32)
            address(0xBEEF),            // yieldSource (20)
            uint256(1000 ether),        // amount at offset 52 (32)
            true                        // usePrevHookAmount at offset 84 (1)
        );

        // 1. decodeUsePrevHookAmount returns true
        assertTrue(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(data));

        // 2. decodeAmounts reads the original amount
        uint256[] memory decoded = deposit4626.decodeAmounts(data);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 1000 ether);

        // 3. replaceCalldataAmounts replaces the amount
        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(500 ether));

        // 4. After replace, decodeAmounts reads new amount
        uint256[] memory decodedAfter = deposit4626.decodeAmounts(replaced);
        assertEq(decodedAfter[0], 500 ether);

        // 5. usePrevHookAmount flag is still true after replace
        assertTrue(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Vault 4626: same test with usePrevHookAmount = false
    function test_Combined_Deposit4626_DecodeReplaceUsePrevFalse() public view {
        bytes memory data = abi.encodePacked(
            bytes32(uint256(0xDEAD)),
            address(0xBEEF),
            uint256(2000 ether),
            false                       // usePrevHookAmount = false
        );

        assertFalse(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = deposit4626.decodeAmounts(data);
        assertEq(decoded[0], 2000 ether);

        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(999 ether));
        uint256[] memory decodedAfter = deposit4626.decodeAmounts(replaced);
        assertEq(decodedAfter[0], 999 ether);

        assertFalse(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice SwapUniswapV3: decode, replace, verify usePrevHookAmount preserved
    function test_Combined_SwapUniV3_DecodeReplaceUsePrev() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),              // inputToken @52
            address(0xBB),              // outputToken @72
            uint256(5 ether),           // inputAmount @92 (AMOUNT_POSITION)
            uint256(0),                 // outputQuote @124
            uint256(4 ether),           // outputMin @156
            true,                       // usePrevHookAmount @188
            uint256(68),                // payloadLength @189
            uint32(3000),               // fee @221
            uint256(block.timestamp + 100), // deadline @225
            uint256(0)                  // sqrtPriceLimitX96 @257
        );

        assertTrue(ISuperHookContextAware(address(swapUniV3)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = swapUniV3.decodeAmounts(data);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 5 ether);

        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(10 ether));
        uint256[] memory decodedAfter = swapUniV3.decodeAmounts(replaced);
        assertEq(decodedAfter[0], 10 ether);

        // usePrevHookAmount preserved
        assertTrue(ISuperHookContextAware(address(swapUniV3)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Bridge AcrossV2: decode, replace, verify usePrevHookAmount preserved
    function test_Combined_AcrossV2_DecodeReplaceUsePrev() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            uint256(0),                 // value (32)
            address(0xAA),              // recipient (20)
            address(0xBB),              // inputToken (20)
            address(0xCC),              // outputToken (20)
            uint256(100 ether),         // inputAmount at offset 144 (32)
            uint256(99 ether),          // outputAmount (32)
            uint256(42161),             // destinationChainId (32)
            address(0xDD),              // exclusiveRelayer (20)
            uint32(3600),               // fillDeadlineOffset (4)
            uint32(0),                  // exclusivityPeriod (4)
            true,                       // usePrevHookAmount at offset 268 (1)
            abi.encode(bytes("initData")) // destinationMessage (variable)
        );

        assertTrue(ISuperHookContextAware(address(acrossV2)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = acrossV2.decodeAmounts(data);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 100 ether);

        bytes memory replaced = acrossV2.replaceCalldataAmounts(data, _singleAmount(50 ether));
        uint256[] memory decodedAfter = acrossV2.decodeAmounts(replaced);
        assertEq(decodedAfter[0], 50 ether);

        assertTrue(ISuperHookContextAware(address(acrossV2)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Stake FluidStake: decode, replace, verify usePrevHookAmount preserved
    function test_Combined_FluidStake_DecodeReplaceUsePrev() public view {
        bytes memory data = abi.encodePacked(
            bytes32(uint256(0xF00D)),   // yieldSourceOracleId (32)
            address(0xBEEF),            // yieldSource (20)
            uint256(750 ether),         // amount at offset 52 (32)
            true                        // usePrevHookAmount at offset 84 (1)
        );

        assertTrue(ISuperHookContextAware(address(fluidStake)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = fluidStake.decodeAmounts(data);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 750 ether);

        bytes memory replaced = fluidStake.replaceCalldataAmounts(data, _singleAmount(250 ether));
        assertEq(fluidStake.decodeAmounts(replaced)[0], 250 ether);

        assertTrue(ISuperHookContextAware(address(fluidStake)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Aave V4 single (Supply): decode, replace, verify usePrevHookAmount preserved
    function test_Combined_AaveV4Supply_DecodeReplaceUsePrev() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),              // loanToken (20)
            address(0xBB),              // collateralToken (20)
            address(0xCC),              // spoke (20)
            uint256(1),                 // supplyReserveId (32)
            uint256(2),                 // borrowReserveId (32)
            uint256(300 ether),         // amount at offset 176 (32)
            true                        // usePrevHookAmount at offset 208 (1)
        );

        assertTrue(ISuperHookContextAware(address(aaveSupply)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = aaveSupply.decodeAmounts(data);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 300 ether);

        bytes memory replaced = aaveSupply.replaceCalldataAmounts(data, _singleAmount(100 ether));
        assertEq(aaveSupply.decodeAmounts(replaced)[0], 100 ether);

        assertTrue(ISuperHookContextAware(address(aaveSupply)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Aave V4 dual (SupplyAndBorrow): decode, replace both amounts, verify usePrevHookAmount preserved
    function test_Combined_AaveV4SupplyAndBorrow_DecodeReplaceUsePrev() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),              // loanToken (20)
            address(0xBB),              // collateralToken (20)
            address(0xCC),              // spoke (20)
            uint256(1),                 // supplyReserveId (32)
            uint256(2),                 // borrowReserveId (32)
            uint256(1000 ether),        // supply amount at offset 176 (32)
            true,                       // usePrevHookAmount at offset 208 (1)
            uint256(500 ether)          // borrowAmount at offset 209 (32)
        );

        assertTrue(ISuperHookContextAware(address(aaveSupplyAndBorrow)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = aaveSupplyAndBorrow.decodeAmounts(data);
        assertEq(decoded.length, 2);
        assertEq(decoded[0], 1000 ether);
        assertEq(decoded[1], 500 ether);

        bytes memory replaced = aaveSupplyAndBorrow.replaceCalldataAmounts(data, _dualAmounts(800 ether, 400 ether));
        uint256[] memory decodedAfter = aaveSupplyAndBorrow.decodeAmounts(replaced);
        assertEq(decodedAfter[0], 800 ether);
        assertEq(decodedAfter[1], 400 ether);

        // usePrevHookAmount flag at byte 156 preserved through dual replace
        assertTrue(ISuperHookContextAware(address(aaveSupplyAndBorrow)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Morpho single (MorphoSupply): decode, replace, verify usePrevHookAmount preserved
    function test_Combined_MorphoSupply_DecodeReplaceUsePrev() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),              // loanToken (20)
            address(0xBB),              // collateralToken (20)
            address(0xCC),              // oracle (20)
            address(0xDD),              // irm (20)
            uint256(600 ether),         // amount at offset 132 (32)
            uint256(86e16),             // lltv (32)
            true                        // usePrevHookAmount at offset 196 (1)
        );

        assertTrue(ISuperHookContextAware(address(morphoSupply)).decodeUsePrevHookAmount(data));

        uint256[] memory decoded = morphoSupply.decodeAmounts(data);
        assertEq(decoded.length, 1);
        assertEq(decoded[0], 600 ether);

        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(200 ether));
        assertEq(morphoSupply.decodeAmounts(replaced)[0], 200 ether);

        assertTrue(ISuperHookContextAware(address(morphoSupply)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Fuzz: Deposit4626 combined decode/replace/usePrev roundtrip
    function test_Fuzz_Combined_Deposit4626(uint256 origAmt, uint256 newAmt, bool usePrev) public view {
        bytes memory data = abi.encodePacked(
            bytes32(uint256(0xDEAD)),
            address(0xBEEF),
            origAmt,
            usePrev
        );

        assertEq(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(data), usePrev);
        assertEq(deposit4626.decodeAmounts(data)[0], origAmt);

        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(newAmt));
        assertEq(deposit4626.decodeAmounts(replaced)[0], newAmt);
        assertEq(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(replaced), usePrev);
    }

    /// @notice Fuzz: SwapUniswapV3 combined decode/replace/usePrev roundtrip
    function test_Fuzz_Combined_SwapUniV3(uint256 origAmt, uint256 newAmt, bool usePrev) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),              // inputToken @52
            address(0xBB),              // outputToken @72
            origAmt,                    // inputAmount @92
            uint256(0),                 // outputQuote @124
            uint256(0),                 // outputMin @156
            usePrev,                    // usePrevHookAmount @188
            uint256(68),                // payloadLength @189
            uint32(3000),               // fee @221
            uint256(block.timestamp + 100), // deadline @225
            uint256(0)                  // sqrtPriceLimitX96 @257
        );

        assertEq(ISuperHookContextAware(address(swapUniV3)).decodeUsePrevHookAmount(data), usePrev);
        assertEq(swapUniV3.decodeAmounts(data)[0], origAmt);

        bytes memory replaced = swapUniV3.replaceCalldataAmounts(data, _singleAmount(newAmt));
        assertEq(swapUniV3.decodeAmounts(replaced)[0], newAmt);
        assertEq(ISuperHookContextAware(address(swapUniV3)).decodeUsePrevHookAmount(replaced), usePrev);
    }

    /// @notice Fuzz: AaveV4SupplyAndBorrow combined decode/replace/usePrev roundtrip (dual-amount)
    function test_Fuzz_Combined_AaveV4SupplyAndBorrow(
        uint256 origSupply,
        uint256 origBorrow,
        uint256 newSupply,
        uint256 newBorrow,
        bool usePrev
    ) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),
            address(0xBB),
            address(0xCC),
            uint256(1),
            uint256(2),
            origSupply,
            usePrev,
            origBorrow
        );

        assertEq(ISuperHookContextAware(address(aaveSupplyAndBorrow)).decodeUsePrevHookAmount(data), usePrev);
        uint256[] memory decoded = aaveSupplyAndBorrow.decodeAmounts(data);
        assertEq(decoded[0], origSupply);
        assertEq(decoded[1], origBorrow);

        bytes memory replaced = aaveSupplyAndBorrow.replaceCalldataAmounts(data, _dualAmounts(newSupply, newBorrow));
        uint256[] memory decodedAfter = aaveSupplyAndBorrow.decodeAmounts(replaced);
        assertEq(decodedAfter[0], newSupply);
        assertEq(decodedAfter[1], newBorrow);
        assertEq(ISuperHookContextAware(address(aaveSupplyAndBorrow)).decodeUsePrevHookAmount(replaced), usePrev);
    }

    /// @notice Fuzz: AcrossV2 combined decode/replace/usePrev roundtrip
    function test_Fuzz_Combined_AcrossV2(uint256 origAmt, uint256 newAmt, bool usePrev) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            uint256(0),
            address(0xAA),
            address(0xBB),
            address(0xCC),
            origAmt,
            uint256(99 ether),
            uint256(42161),
            address(0xDD),
            uint32(3600),
            uint32(0),
            usePrev,
            abi.encode(bytes("test"))
        );

        assertEq(ISuperHookContextAware(address(acrossV2)).decodeUsePrevHookAmount(data), usePrev);
        assertEq(acrossV2.decodeAmounts(data)[0], origAmt);

        bytes memory replaced = acrossV2.replaceCalldataAmounts(data, _singleAmount(newAmt));
        assertEq(acrossV2.decodeAmounts(replaced)[0], newAmt);
        assertEq(ISuperHookContextAware(address(acrossV2)).decodeUsePrevHookAmount(replaced), usePrev);
    }

    /// @notice Fuzz: MorphoSupply combined decode/replace/usePrev roundtrip
    function test_Fuzz_Combined_MorphoSupply(uint256 origAmt, uint256 newAmt, bool usePrev) public view {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0),     // 52-byte header
            address(0xAA),
            address(0xBB),
            address(0xCC),
            address(0xDD),
            origAmt,
            uint256(86e16),
            usePrev
        );

        assertEq(ISuperHookContextAware(address(morphoSupply)).decodeUsePrevHookAmount(data), usePrev);
        assertEq(morphoSupply.decodeAmounts(data)[0], origAmt);

        bytes memory replaced = morphoSupply.replaceCalldataAmounts(data, _singleAmount(newAmt));
        assertEq(morphoSupply.decodeAmounts(replaced)[0], newAmt);
        assertEq(ISuperHookContextAware(address(morphoSupply)).decodeUsePrevHookAmount(replaced), usePrev);
    }

    /// @notice Multiple replaces: verify last replace wins and usePrevHookAmount stays consistent
    function test_Combined_MultiReplace_UsePrevPreserved() public view {
        bytes memory data = abi.encodePacked(
            bytes32(uint256(0xDEAD)),
            address(0xBEEF),
            uint256(1000 ether),
            true
        );

        // Replace three times in sequence
        bytes memory r1 = deposit4626.replaceCalldataAmounts(data, _singleAmount(500 ether));
        bytes memory r2 = deposit4626.replaceCalldataAmounts(r1, _singleAmount(250 ether));
        bytes memory r3 = deposit4626.replaceCalldataAmounts(r2, _singleAmount(type(uint256).max));

        assertEq(deposit4626.decodeAmounts(r3)[0], type(uint256).max);
        assertTrue(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(r3));
    }

    /// @notice Replace with zero: verify usePrevHookAmount still readable
    function test_Combined_ReplaceWithZero_UsePrevPreserved() public view {
        bytes memory data = abi.encodePacked(
            bytes32(uint256(0xDEAD)),
            address(0xBEEF),
            uint256(1000 ether),
            true
        );

        bytes memory replaced = deposit4626.replaceCalldataAmounts(data, _singleAmount(0));
        assertEq(deposit4626.decodeAmounts(replaced)[0], 0);
        assertTrue(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(replaced));
    }

    /// @notice Cross-category: all hooks with usePrevHookAmount decode correctly after replace
    function test_Combined_AllCategories_UsePrevAfterReplace() public view {
        // Vault 4626
        {
            bytes memory d = abi.encodePacked(bytes32(0), address(0xBEEF), uint256(1e18), true);
            bytes memory r = deposit4626.replaceCalldataAmounts(d, _singleAmount(2e18));
            assertTrue(ISuperHookContextAware(address(deposit4626)).decodeUsePrevHookAmount(r));
            assertEq(deposit4626.decodeAmounts(r)[0], 2e18);
        }

        // Swapper UniV3
        {
            bytes memory d = abi.encodePacked(
                bytes32(0), address(0),
                address(0xAA), address(0xBB), // inputToken@52, outputToken@72
                uint256(1e18), uint256(0), uint256(0), // amount@92, outputQuote@124, outputMin@156
                true, uint256(68), // usePrev@188, payloadLen@189
                uint32(500), uint256(block.timestamp + 100), uint256(0) // fee@221, deadline@225, sqrtPrice@257
            );
            bytes memory r = swapUniV3.replaceCalldataAmounts(d, _singleAmount(3e18));
            assertTrue(ISuperHookContextAware(address(swapUniV3)).decodeUsePrevHookAmount(r));
            assertEq(swapUniV3.decodeAmounts(r)[0], 3e18);
        }

        // Bridge AcrossV2
        {
            bytes memory d = abi.encodePacked(
                bytes32(0), address(0),
                uint256(0), address(0xAA), address(0xBB), address(0xCC),
                uint256(1e18), uint256(9e17), uint256(42161),
                address(0xDD), uint32(3600), uint32(0), true,
                abi.encode(bytes("x"))
            );
            bytes memory r = acrossV2.replaceCalldataAmounts(d, _singleAmount(4e18));
            assertTrue(ISuperHookContextAware(address(acrossV2)).decodeUsePrevHookAmount(r));
            assertEq(acrossV2.decodeAmounts(r)[0], 4e18);
        }

        // Stake Fluid
        {
            bytes memory d = abi.encodePacked(bytes32(0), address(0xBEEF), uint256(1e18), true);
            bytes memory r = fluidStake.replaceCalldataAmounts(d, _singleAmount(5e18));
            assertTrue(ISuperHookContextAware(address(fluidStake)).decodeUsePrevHookAmount(r));
            assertEq(fluidStake.decodeAmounts(r)[0], 5e18);
        }

        // Aave V4 Supply
        {
            bytes memory d = abi.encodePacked(
                bytes32(0), address(0),
                address(0xAA), address(0xBB), address(0xCC),
                uint256(1), uint256(2), uint256(1e18), true
            );
            bytes memory r = aaveSupply.replaceCalldataAmounts(d, _singleAmount(6e18));
            assertTrue(ISuperHookContextAware(address(aaveSupply)).decodeUsePrevHookAmount(r));
            assertEq(aaveSupply.decodeAmounts(r)[0], 6e18);
        }

        // Morpho Supply
        {
            bytes memory d = abi.encodePacked(
                bytes32(0), address(0),
                address(0xAA), address(0xBB), address(0xCC), address(0xDD),
                uint256(1e18), uint256(86e16), true
            );
            bytes memory r = morphoSupply.replaceCalldataAmounts(d, _singleAmount(7e18));
            assertTrue(ISuperHookContextAware(address(morphoSupply)).decodeUsePrevHookAmount(r));
            assertEq(morphoSupply.decodeAmounts(r)[0], 7e18);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    name() — NON-EMPTY + UNIQUENESS
    //////////////////////////////////////////////////////////////*/

    /// @dev Every deployed hook MUST return a non-empty name
    function test_Name_AllHooks_NonEmpty() public view {
        // Token hooks
        assertTrue(bytes(transferERC20.name()).length > 0, "transferERC20");
        assertTrue(bytes(approveERC20.name()).length > 0, "approveERC20");
        assertTrue(bytes(transferHook.name()).length > 0, "transferHook");
        assertTrue(bytes(nativeTransfer.name()).length > 0, "nativeTransfer");
        assertTrue(bytes(wrappedNative.name()).length > 0, "wrappedNative");
        assertTrue(bytes(fetchNativeFee.name()).length > 0, "fetchNativeFee");
        assertTrue(bytes(claimFailedTransfer.name()).length > 0, "claimFailedTransfer");

        // Swappers
        assertTrue(bytes(swapUniV3.name()).length > 0, "swapUniV3");
        assertTrue(bytes(approveSwapUniV3.name()).length > 0, "approveSwapUniV3");
        assertTrue(bytes(swapUniV3Router02.name()).length > 0, "swapUniV3Router02");
        assertTrue(bytes(approveSwapUniV3Router02.name()).length > 0, "approveSwapUniV3Router02");
        assertTrue(bytes(swapUniV2.name()).length > 0, "swapUniV2");
        assertTrue(bytes(approveSwapUniV2.name()).length > 0, "approveSwapUniV2");
        assertTrue(bytes(swapUniV4.name()).length > 0, "swapUniV4");
        assertTrue(bytes(swapOdosV2.name()).length > 0, "swapOdosV2");
        assertTrue(bytes(approveSwapOdosV2.name()).length > 0, "approveSwapOdosV2");
        assertTrue(bytes(swapOdosV3.name()).length > 0, "swapOdosV3");
        assertTrue(bytes(approveSwapOdosV3.name()).length > 0, "approveSwapOdosV3");
        assertTrue(bytes(swapKyber.name()).length > 0, "swapKyber");
        assertTrue(bytes(approveSwapKyber.name()).length > 0, "approveSwapKyber");
        assertTrue(bytes(swapSparkIn.name()).length > 0, "swapSparkIn");
        assertTrue(bytes(approveSwapSparkIn.name()).length > 0, "approveSwapSparkIn");
        assertTrue(bytes(swapSparkOut.name()).length > 0, "swapSparkOut");
        assertTrue(bytes(approveSwapSparkOut.name()).length > 0, "approveSwapSparkOut");
        assertTrue(bytes(swapAlgebra.name()).length > 0, "swapAlgebra");
        assertTrue(bytes(approveSwapAlgebra.name()).length > 0, "approveSwapAlgebra");
        assertTrue(bytes(swapOpenOcean.name()).length > 0, "swapOpenOcean");
        assertTrue(bytes(approveSwapOpenOcean.name()).length > 0, "approveSwapOpenOcean");
        assertTrue(bytes(spectraRedeem.name()).length > 0, "spectraRedeem");
        assertTrue(bytes(pendleRedeem.name()).length > 0, "pendleRedeem");

        // Bridges
        assertTrue(bytes(acrossV1.name()).length > 0, "acrossV1");
        assertTrue(bytes(approveAcrossV1.name()).length > 0, "approveAcrossV1");
        assertTrue(bytes(acrossV2.name()).length > 0, "acrossV2");
        assertTrue(bytes(approveAcrossV2.name()).length > 0, "approveAcrossV2");
        assertTrue(bytes(stargate.name()).length > 0, "stargate");
        assertTrue(bytes(approveStargate.name()).length > 0, "approveStargate");
        assertTrue(bytes(stargateV2.name()).length > 0, "stargateV2");
        assertTrue(bytes(approveStargateV2.name()).length > 0, "approveStargateV2");
        assertTrue(bytes(debridge.name()).length > 0, "debridge");
        assertTrue(bytes(cctp.name()).length > 0, "cctp");
        assertTrue(bytes(approveCctp.name()).length > 0, "approveCctp");
        assertTrue(bytes(circleGateway.name()).length > 0, "circleGateway");

        // Stake
        assertTrue(bytes(fluidStake.name()).length > 0, "fluidStake");
        assertTrue(bytes(approveFluidStake.name()).length > 0, "approveFluidStake");
        assertTrue(bytes(fluidUnstake.name()).length > 0, "fluidUnstake");
        assertTrue(bytes(gearboxStake.name()).length > 0, "gearboxStake");
        assertTrue(bytes(approveGearboxStake.name()).length > 0, "approveGearboxStake");
        assertTrue(bytes(gearboxUnstake.name()).length > 0, "gearboxUnstake");

        // Assets denomination
        assertTrue(bytes(deposit4626.name()).length > 0, "deposit4626");
        assertTrue(bytes(approveDeposit4626.name()).length > 0, "approveDeposit4626");
        assertTrue(bytes(deposit5115.name()).length > 0, "deposit5115");
        assertTrue(bytes(approveDeposit5115.name()).length > 0, "approveDeposit5115");
        assertTrue(bytes(deposit7540.name()).length > 0, "deposit7540");
        assertTrue(bytes(requestDeposit7540.name()).length > 0, "requestDeposit7540");
        assertTrue(bytes(approveRequestDeposit7540.name()).length > 0, "approveRequestDeposit7540");
        assertTrue(bytes(withdraw7540.name()).length > 0, "withdraw7540");
        assertTrue(bytes(withdrawWithId7540.name()).length > 0, "withdrawWithId7540");

        // Shares denomination
        assertTrue(bytes(redeem4626.name()).length > 0, "redeem4626");
        assertTrue(bytes(redeem5115.name()).length > 0, "redeem5115");
        assertTrue(bytes(redeem7540.name()).length > 0, "redeem7540");
        assertTrue(bytes(redeemWithId7540.name()).length > 0, "redeemWithId7540");
        assertTrue(bytes(requestRedeem7540.name()).length > 0, "requestRedeem7540");
        assertTrue(bytes(requestRedeemDETH.name()).length > 0, "requestRedeemDETH");
        assertTrue(bytes(approveRequestRedeemDETH.name()).length > 0, "approveRequestRedeemDETH");
        assertTrue(bytes(ethenaCooldown.name()).length > 0, "ethenaCooldown");
        assertTrue(bytes(redeemFirelight.name()).length > 0, "redeemFirelight");
        assertTrue(bytes(mintSP.name()).length > 0, "mintSP");
        assertTrue(bytes(burnSP.name()).length > 0, "burnSP");

        // Sizeless hooks
        assertTrue(bytes(fluidClaim.name()).length > 0, "fluidClaim");
        assertTrue(bytes(gearboxClaim.name()).length > 0, "gearboxClaim");
        assertTrue(bytes(yearnClaim.name()).length > 0, "yearnClaim");
        assertTrue(bytes(merklClaim.name()).length > 0, "merklClaim");
        assertTrue(bytes(batchTransfer.name()).length > 0, "batchTransfer");
        assertTrue(bytes(claimAssetsDETH.name()).length > 0, "claimAssetsDETH");
        assertTrue(bytes(claimWithdrawFirelight.name()).length > 0, "claimWithdrawFirelight");

        // Loan hooks
        assertTrue(bytes(morphoSupply.name()).length > 0, "morphoSupply");
        assertTrue(bytes(morphoLend.name()).length > 0, "morphoLend");
        assertTrue(bytes(morphoBorrow.name()).length > 0, "morphoBorrow");
        assertTrue(bytes(morphoRepay.name()).length > 0, "morphoRepay");
        assertTrue(bytes(morphoSupplyAndBorrow.name()).length > 0, "morphoSupplyAndBorrow");
        assertTrue(bytes(morphoRepayAndWithdraw.name()).length > 0, "morphoRepayAndWithdraw");
        assertTrue(bytes(morphoWithdraw.name()).length > 0, "morphoWithdraw");

        // Aave V4 loan hooks
        assertTrue(bytes(aaveSupply.name()).length > 0, "aaveSupply");
        assertTrue(bytes(aaveWithdraw.name()).length > 0, "aaveWithdraw");
        assertTrue(bytes(aaveBorrow.name()).length > 0, "aaveBorrow");
        assertTrue(bytes(aaveRepay.name()).length > 0, "aaveRepay");
        assertTrue(bytes(aaveSupplyAndBorrow.name()).length > 0, "aaveSupplyAndBorrow");
        assertTrue(bytes(aaveRepayAndWithdraw.name()).length > 0, "aaveRepayAndWithdraw");
    }

    /// @dev No two deployed hooks may share the same name
    function test_Name_AllHooks_Unique() public view {
        string[] memory names = new string[](88);
        uint256 i = 0;

        // Token hooks
        names[i++] = transferERC20.name();
        names[i++] = approveERC20.name();
        names[i++] = transferHook.name();
        names[i++] = nativeTransfer.name();
        names[i++] = wrappedNative.name();
        names[i++] = fetchNativeFee.name();
        names[i++] = claimFailedTransfer.name();

        // Swappers
        names[i++] = swapUniV3.name();
        names[i++] = approveSwapUniV3.name();
        names[i++] = swapUniV3Router02.name();
        names[i++] = approveSwapUniV3Router02.name();
        names[i++] = swapUniV2.name();
        names[i++] = approveSwapUniV2.name();
        names[i++] = swapUniV4.name();
        names[i++] = swapOdosV2.name();
        names[i++] = approveSwapOdosV2.name();
        names[i++] = swapOdosV3.name();
        names[i++] = approveSwapOdosV3.name();
        names[i++] = swapKyber.name();
        names[i++] = approveSwapKyber.name();
        names[i++] = swapSparkIn.name();
        names[i++] = approveSwapSparkIn.name();
        names[i++] = swapSparkOut.name();
        names[i++] = approveSwapSparkOut.name();
        names[i++] = swapAlgebra.name();
        names[i++] = approveSwapAlgebra.name();
        names[i++] = swapOpenOcean.name();
        names[i++] = approveSwapOpenOcean.name();
        names[i++] = spectraRedeem.name();
        names[i++] = pendleRedeem.name();

        // Bridges
        names[i++] = acrossV1.name();
        names[i++] = approveAcrossV1.name();
        names[i++] = acrossV2.name();
        names[i++] = approveAcrossV2.name();
        names[i++] = stargate.name();
        names[i++] = approveStargate.name();
        names[i++] = stargateV2.name();
        names[i++] = approveStargateV2.name();
        names[i++] = debridge.name();
        names[i++] = cctp.name();
        names[i++] = approveCctp.name();
        names[i++] = circleGateway.name();

        // Stake
        names[i++] = fluidStake.name();
        names[i++] = approveFluidStake.name();
        names[i++] = fluidUnstake.name();
        names[i++] = gearboxStake.name();
        names[i++] = approveGearboxStake.name();
        names[i++] = gearboxUnstake.name();

        // Vaults - Assets
        names[i++] = deposit4626.name();
        names[i++] = approveDeposit4626.name();
        names[i++] = deposit5115.name();
        names[i++] = approveDeposit5115.name();
        names[i++] = deposit7540.name();
        names[i++] = requestDeposit7540.name();
        names[i++] = approveRequestDeposit7540.name();
        names[i++] = withdraw7540.name();
        names[i++] = withdrawWithId7540.name();

        // Vaults - Shares
        names[i++] = redeem4626.name();
        names[i++] = redeem5115.name();
        names[i++] = redeem7540.name();
        names[i++] = redeemWithId7540.name();
        names[i++] = requestRedeem7540.name();
        names[i++] = requestRedeemDETH.name();
        names[i++] = approveRequestRedeemDETH.name();
        names[i++] = ethenaCooldown.name();
        names[i++] = redeemFirelight.name();
        names[i++] = mintSP.name();
        names[i++] = burnSP.name();

        // Sizeless
        names[i++] = fluidClaim.name();
        names[i++] = gearboxClaim.name();
        names[i++] = yearnClaim.name();
        names[i++] = merklClaim.name();
        names[i++] = batchTransfer.name();
        names[i++] = claimAssetsDETH.name();
        names[i++] = claimWithdrawFirelight.name();

        // Loans
        names[i++] = morphoSupply.name();
        names[i++] = morphoLend.name();
        names[i++] = morphoBorrow.name();
        names[i++] = morphoRepay.name();
        names[i++] = morphoSupplyAndBorrow.name();
        names[i++] = morphoRepayAndWithdraw.name();
        names[i++] = morphoWithdraw.name();

        // Aave V4
        names[i++] = aaveSupply.name();
        names[i++] = aaveWithdraw.name();
        names[i++] = aaveBorrow.name();
        names[i++] = aaveRepay.name();
        names[i++] = aaveSupplyAndBorrow.name();
        names[i++] = aaveRepayAndWithdraw.name();

        assertEq(i, 88, "count mismatch");

        // O(n^2) uniqueness check (acceptable for 83 items)
        for (uint256 a = 0; a < i; a++) {
            for (uint256 b = a + 1; b < i; b++) {
                assertFalse(
                    keccak256(bytes(names[a])) == keccak256(bytes(names[b])),
                    string.concat("Duplicate name: ", names[a])
                );
            }
        }
    }

    /// @dev Spot-check: verify specific hooks return their expected names
    function test_Name_SpotCheck() public view {
        assertEq(deposit4626.name(), "Deposit ERC-4626 Vault");
        assertEq(swapUniV3.name(), "Swap Uniswap V3");
        assertEq(acrossV1.name(), "Across Bridge");
        assertEq(morphoSupply.name(), "Morpho Supply");
        assertEq(aaveSupply.name(), "Aave V4 Supply");
        assertEq(fluidClaim.name(), "Fluid Claim Reward");
        assertEq(redeem7540.name(), "Redeem ERC-7540 Vault");
        assertEq(circleGateway.name(), "Circle Gateway Wallet");
    }

    /*//////////////////////////////////////////////////////////////
                         DESCRIPTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Every deployed hook MUST return a non-empty description
    function test_Description_AllHooks_NonEmpty() public view {
        // Token hooks
        assertTrue(bytes(transferERC20.description()).length > 0, "transferERC20");
        assertTrue(bytes(approveERC20.description()).length > 0, "approveERC20");
        assertTrue(bytes(transferHook.description()).length > 0, "transferHook");
        assertTrue(bytes(nativeTransfer.description()).length > 0, "nativeTransfer");
        assertTrue(bytes(wrappedNative.description()).length > 0, "wrappedNative");
        assertTrue(bytes(fetchNativeFee.description()).length > 0, "fetchNativeFee");
        assertTrue(bytes(claimFailedTransfer.description()).length > 0, "claimFailedTransfer");

        // Swappers
        assertTrue(bytes(swapUniV3.description()).length > 0, "swapUniV3");
        assertTrue(bytes(approveSwapUniV3.description()).length > 0, "approveSwapUniV3");
        assertTrue(bytes(swapUniV3Router02.description()).length > 0, "swapUniV3Router02");
        assertTrue(bytes(approveSwapUniV3Router02.description()).length > 0, "approveSwapUniV3Router02");
        assertTrue(bytes(swapUniV2.description()).length > 0, "swapUniV2");
        assertTrue(bytes(approveSwapUniV2.description()).length > 0, "approveSwapUniV2");
        assertTrue(bytes(swapUniV4.description()).length > 0, "swapUniV4");
        assertTrue(bytes(swapOdosV2.description()).length > 0, "swapOdosV2");
        assertTrue(bytes(approveSwapOdosV2.description()).length > 0, "approveSwapOdosV2");
        assertTrue(bytes(swapOdosV3.description()).length > 0, "swapOdosV3");
        assertTrue(bytes(approveSwapOdosV3.description()).length > 0, "approveSwapOdosV3");
        assertTrue(bytes(swapKyber.description()).length > 0, "swapKyber");
        assertTrue(bytes(approveSwapKyber.description()).length > 0, "approveSwapKyber");
        assertTrue(bytes(swapSparkIn.description()).length > 0, "swapSparkIn");
        assertTrue(bytes(approveSwapSparkIn.description()).length > 0, "approveSwapSparkIn");
        assertTrue(bytes(swapSparkOut.description()).length > 0, "swapSparkOut");
        assertTrue(bytes(approveSwapSparkOut.description()).length > 0, "approveSwapSparkOut");
        assertTrue(bytes(swapAlgebra.description()).length > 0, "swapAlgebra");
        assertTrue(bytes(approveSwapAlgebra.description()).length > 0, "approveSwapAlgebra");
        assertTrue(bytes(swapOpenOcean.description()).length > 0, "swapOpenOcean");
        assertTrue(bytes(approveSwapOpenOcean.description()).length > 0, "approveSwapOpenOcean");
        assertTrue(bytes(spectraRedeem.description()).length > 0, "spectraRedeem");
        assertTrue(bytes(pendleRedeem.description()).length > 0, "pendleRedeem");

        // Bridges
        assertTrue(bytes(acrossV1.description()).length > 0, "acrossV1");
        assertTrue(bytes(approveAcrossV1.description()).length > 0, "approveAcrossV1");
        assertTrue(bytes(acrossV2.description()).length > 0, "acrossV2");
        assertTrue(bytes(approveAcrossV2.description()).length > 0, "approveAcrossV2");
        assertTrue(bytes(stargate.description()).length > 0, "stargate");
        assertTrue(bytes(approveStargate.description()).length > 0, "approveStargate");
        assertTrue(bytes(stargateV2.description()).length > 0, "stargateV2");
        assertTrue(bytes(approveStargateV2.description()).length > 0, "approveStargateV2");
        assertTrue(bytes(debridge.description()).length > 0, "debridge");
        assertTrue(bytes(cctp.description()).length > 0, "cctp");
        assertTrue(bytes(approveCctp.description()).length > 0, "approveCctp");
        assertTrue(bytes(circleGateway.description()).length > 0, "circleGateway");

        // Stake
        assertTrue(bytes(fluidStake.description()).length > 0, "fluidStake");
        assertTrue(bytes(approveFluidStake.description()).length > 0, "approveFluidStake");
        assertTrue(bytes(fluidUnstake.description()).length > 0, "fluidUnstake");
        assertTrue(bytes(gearboxStake.description()).length > 0, "gearboxStake");
        assertTrue(bytes(approveGearboxStake.description()).length > 0, "approveGearboxStake");
        assertTrue(bytes(gearboxUnstake.description()).length > 0, "gearboxUnstake");

        // Assets denomination
        assertTrue(bytes(deposit4626.description()).length > 0, "deposit4626");
        assertTrue(bytes(approveDeposit4626.description()).length > 0, "approveDeposit4626");
        assertTrue(bytes(deposit5115.description()).length > 0, "deposit5115");
        assertTrue(bytes(approveDeposit5115.description()).length > 0, "approveDeposit5115");
        assertTrue(bytes(deposit7540.description()).length > 0, "deposit7540");
        assertTrue(bytes(requestDeposit7540.description()).length > 0, "requestDeposit7540");
        assertTrue(bytes(approveRequestDeposit7540.description()).length > 0, "approveRequestDeposit7540");
        assertTrue(bytes(withdraw7540.description()).length > 0, "withdraw7540");
        assertTrue(bytes(withdrawWithId7540.description()).length > 0, "withdrawWithId7540");

        // Shares denomination
        assertTrue(bytes(redeem4626.description()).length > 0, "redeem4626");
        assertTrue(bytes(redeem5115.description()).length > 0, "redeem5115");
        assertTrue(bytes(redeem7540.description()).length > 0, "redeem7540");
        assertTrue(bytes(redeemWithId7540.description()).length > 0, "redeemWithId7540");
        assertTrue(bytes(requestRedeem7540.description()).length > 0, "requestRedeem7540");
        assertTrue(bytes(requestRedeemDETH.description()).length > 0, "requestRedeemDETH");
        assertTrue(bytes(approveRequestRedeemDETH.description()).length > 0, "approveRequestRedeemDETH");
        assertTrue(bytes(ethenaCooldown.description()).length > 0, "ethenaCooldown");
        assertTrue(bytes(redeemFirelight.description()).length > 0, "redeemFirelight");
        assertTrue(bytes(mintSP.description()).length > 0, "mintSP");
        assertTrue(bytes(burnSP.description()).length > 0, "burnSP");

        // Sizeless hooks
        assertTrue(bytes(fluidClaim.description()).length > 0, "fluidClaim");
        assertTrue(bytes(gearboxClaim.description()).length > 0, "gearboxClaim");
        assertTrue(bytes(yearnClaim.description()).length > 0, "yearnClaim");
        assertTrue(bytes(merklClaim.description()).length > 0, "merklClaim");
        assertTrue(bytes(batchTransfer.description()).length > 0, "batchTransfer");
        assertTrue(bytes(claimAssetsDETH.description()).length > 0, "claimAssetsDETH");
        assertTrue(bytes(claimWithdrawFirelight.description()).length > 0, "claimWithdrawFirelight");

        // Loan hooks
        assertTrue(bytes(morphoSupply.description()).length > 0, "morphoSupply");
        assertTrue(bytes(morphoLend.description()).length > 0, "morphoLend");
        assertTrue(bytes(morphoBorrow.description()).length > 0, "morphoBorrow");
        assertTrue(bytes(morphoRepay.description()).length > 0, "morphoRepay");
        assertTrue(bytes(morphoSupplyAndBorrow.description()).length > 0, "morphoSupplyAndBorrow");
        assertTrue(bytes(morphoRepayAndWithdraw.description()).length > 0, "morphoRepayAndWithdraw");
        assertTrue(bytes(morphoWithdraw.description()).length > 0, "morphoWithdraw");

        // Aave V4 loan hooks
        assertTrue(bytes(aaveSupply.description()).length > 0, "aaveSupply");
        assertTrue(bytes(aaveWithdraw.description()).length > 0, "aaveWithdraw");
        assertTrue(bytes(aaveBorrow.description()).length > 0, "aaveBorrow");
        assertTrue(bytes(aaveRepay.description()).length > 0, "aaveRepay");
        assertTrue(bytes(aaveSupplyAndBorrow.description()).length > 0, "aaveSupplyAndBorrow");
        assertTrue(bytes(aaveRepayAndWithdraw.description()).length > 0, "aaveRepayAndWithdraw");
    }

    /// @dev No two deployed hooks may share the same description
    function test_Description_AllHooks_Unique() public view {
        string[] memory descs = new string[](88);
        uint256 i = 0;

        // Token hooks
        descs[i++] = transferERC20.description();
        descs[i++] = approveERC20.description();
        descs[i++] = transferHook.description();
        descs[i++] = nativeTransfer.description();
        descs[i++] = wrappedNative.description();
        descs[i++] = fetchNativeFee.description();
        descs[i++] = claimFailedTransfer.description();

        // Swappers
        descs[i++] = swapUniV3.description();
        descs[i++] = approveSwapUniV3.description();
        descs[i++] = swapUniV3Router02.description();
        descs[i++] = approveSwapUniV3Router02.description();
        descs[i++] = swapUniV2.description();
        descs[i++] = approveSwapUniV2.description();
        descs[i++] = swapUniV4.description();
        descs[i++] = swapOdosV2.description();
        descs[i++] = approveSwapOdosV2.description();
        descs[i++] = swapOdosV3.description();
        descs[i++] = approveSwapOdosV3.description();
        descs[i++] = swapKyber.description();
        descs[i++] = approveSwapKyber.description();
        descs[i++] = swapSparkIn.description();
        descs[i++] = approveSwapSparkIn.description();
        descs[i++] = swapSparkOut.description();
        descs[i++] = approveSwapSparkOut.description();
        descs[i++] = swapAlgebra.description();
        descs[i++] = approveSwapAlgebra.description();
        descs[i++] = swapOpenOcean.description();
        descs[i++] = approveSwapOpenOcean.description();
        descs[i++] = spectraRedeem.description();
        descs[i++] = pendleRedeem.description();

        // Bridges
        descs[i++] = acrossV1.description();
        descs[i++] = approveAcrossV1.description();
        descs[i++] = acrossV2.description();
        descs[i++] = approveAcrossV2.description();
        descs[i++] = stargate.description();
        descs[i++] = approveStargate.description();
        descs[i++] = stargateV2.description();
        descs[i++] = approveStargateV2.description();
        descs[i++] = debridge.description();
        descs[i++] = cctp.description();
        descs[i++] = approveCctp.description();
        descs[i++] = circleGateway.description();

        // Stake
        descs[i++] = fluidStake.description();
        descs[i++] = approveFluidStake.description();
        descs[i++] = fluidUnstake.description();
        descs[i++] = gearboxStake.description();
        descs[i++] = approveGearboxStake.description();
        descs[i++] = gearboxUnstake.description();

        // Vaults - Assets
        descs[i++] = deposit4626.description();
        descs[i++] = approveDeposit4626.description();
        descs[i++] = deposit5115.description();
        descs[i++] = approveDeposit5115.description();
        descs[i++] = deposit7540.description();
        descs[i++] = requestDeposit7540.description();
        descs[i++] = approveRequestDeposit7540.description();
        descs[i++] = withdraw7540.description();
        descs[i++] = withdrawWithId7540.description();

        // Vaults - Shares
        descs[i++] = redeem4626.description();
        descs[i++] = redeem5115.description();
        descs[i++] = redeem7540.description();
        descs[i++] = redeemWithId7540.description();
        descs[i++] = requestRedeem7540.description();
        descs[i++] = requestRedeemDETH.description();
        descs[i++] = approveRequestRedeemDETH.description();
        descs[i++] = ethenaCooldown.description();
        descs[i++] = redeemFirelight.description();
        descs[i++] = mintSP.description();
        descs[i++] = burnSP.description();

        // Sizeless
        descs[i++] = fluidClaim.description();
        descs[i++] = gearboxClaim.description();
        descs[i++] = yearnClaim.description();
        descs[i++] = merklClaim.description();
        descs[i++] = batchTransfer.description();
        descs[i++] = claimAssetsDETH.description();
        descs[i++] = claimWithdrawFirelight.description();

        // Loans
        descs[i++] = morphoSupply.description();
        descs[i++] = morphoLend.description();
        descs[i++] = morphoBorrow.description();
        descs[i++] = morphoRepay.description();
        descs[i++] = morphoSupplyAndBorrow.description();
        descs[i++] = morphoRepayAndWithdraw.description();
        descs[i++] = morphoWithdraw.description();

        // Aave V4
        descs[i++] = aaveSupply.description();
        descs[i++] = aaveWithdraw.description();
        descs[i++] = aaveBorrow.description();
        descs[i++] = aaveRepay.description();
        descs[i++] = aaveSupplyAndBorrow.description();
        descs[i++] = aaveRepayAndWithdraw.description();

        assertEq(i, 88, "count mismatch");

        // O(n^2) uniqueness check
        for (uint256 a = 0; a < i; a++) {
            for (uint256 b = a + 1; b < i; b++) {
                assertFalse(
                    keccak256(bytes(descs[a])) == keccak256(bytes(descs[b])),
                    string.concat("Duplicate description: ", descs[a])
                );
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
         NEWLY-S1: ForceDeallocateMorphoHook sizing tests
    //////////////////////////////////////////////////////////////*/

    /// @dev ForceDeallocateMorphoHook: supportsInterface(ISuperHookInflowOutflow) == true
    function test_ForceDeallocateMorpho_SupportsInterface() public view {
        assertTrue(forceDeallocateMorpho.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertTrue(forceDeallocateMorpho.supportsInterface(type(ISuperHookOutflow).interfaceId));
    }

    /// @dev ForceDeallocateMorphoHook: decodeAmounts reads at offset 72
    function test_ForceDeallocateMorpho_DecodeAmounts() public view {
        // Layout: bytes32(0-32) + address(32-52) + address(52-72) + uint256 assets(72-104) + ...
        bytes memory data = abi.encodePacked(
            bytes32(0),         // placeholder (32)
            address(0xAA),      // morphoVaultV2 (20)
            address(0xBB),      // adapter (20)
            uint256(42e18),     // assets at offset 72 (32)
            uint256(0),         // deadline (32)
            uint256(0),         // maxPenaltyBps (32)
            false,              // usePrevHookAmount (1)
            bytes("")           // adapterData (0)
        );
        uint256[] memory amounts = forceDeallocateMorpho.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], 42e18);
    }

    /// @dev ForceDeallocateMorphoHook: amountRoles returns 1 entry (IN, TOKEN)
    function test_ForceDeallocateMorpho_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = forceDeallocateMorpho.amountRoles("");
        assertEq(meta.length, 1);
        assertEq(uint8(meta[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(meta[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    /// @dev ForceDeallocateMorphoHook: decode/replace roundtrip
    function test_ForceDeallocateMorpho_DecodeReplace_Roundtrip() public view {
        bytes memory data = abi.encodePacked(
            bytes32(0),
            address(0xAA),
            address(0xBB),
            uint256(100e18),
            uint256(1000),
            uint256(500),
            false,
            bytes("")
        );
        assertEq(forceDeallocateMorpho.decodeAmounts(data)[0], 100e18);
        bytes memory replaced = forceDeallocateMorpho.replaceCalldataAmounts(data, _singleAmount(200e18));
        assertEq(forceDeallocateMorpho.decodeAmounts(replaced)[0], 200e18);
        assertEq(replaced.length, data.length);
    }

    /// @dev ForceDeallocateMorphoHook: replaceCalldataAmounts reverts on wrong length
    function test_ForceDeallocateMorpho_ReplaceCalldataAmounts_RevertsWrongLength() public {
        bytes memory data = abi.encodePacked(
            bytes32(0), address(0xAA), address(0xBB), uint256(1e18), uint256(0), uint256(0), false, bytes("")
        );
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        forceDeallocateMorpho.replaceCalldataAmounts(data, new uint256[](0));
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        forceDeallocateMorpho.replaceCalldataAmounts(data, _dualAmounts(1, 2));
    }

    /*//////////////////////////////////////////////////////////////
         NEWLY-S2: All 30 S2 hooks — InflowOutflow=true, Outflow=false, empty arrays
    //////////////////////////////////////////////////////////////*/

    /// @dev All newly-S2 hooks must support ISuperHookInflowOutflow
    function test_NewlyS2_SupportsInterface_InflowOutflow() public view {
        bytes4 iid = type(ISuperHookInflowOutflow).interfaceId;
        // Opaque-blob hooks
        assertTrue(pendleUnified.supportsInterface(iid), "pendleUnified");
        assertTrue(spectraExchangeDeposit.supportsInterface(iid), "spectraExchangeDeposit");
        assertTrue(swap1Inch.supportsInterface(iid), "swap1Inch");
        assertTrue(batchTransferBasic.supportsInterface(iid), "batchTransferBasic");
        assertTrue(circleGatewayMinter.supportsInterface(iid), "circleGatewayMinter");
        // Oracle hooks
        assertTrue(recordPurchaseOracle.supportsInterface(iid), "recordPurchaseOracle");
        assertTrue(recordPurchaseOracleV2.supportsInterface(iid), "recordPurchaseOracleV2");
        assertTrue(recordRedemptionOracle.supportsInterface(iid), "recordRedemptionOracle");
        assertTrue(recordRedemptionOracleV2.supportsInterface(iid), "recordRedemptionOracleV2");
        // Flare claim hooks
        assertTrue(claimRFLR.supportsInterface(iid), "claimRFLR");
        assertTrue(withdrawRFLR.supportsInterface(iid), "withdrawRFLR");
        assertTrue(withdrawVestedRFLR.supportsInterface(iid), "withdrawVestedRFLR");
        // 7540 cancel/claim hooks
        assertTrue(cancelDeposit7540.supportsInterface(iid), "cancelDeposit7540");
        assertTrue(cancelDepositWithId7540.supportsInterface(iid), "cancelDepositWithId7540");
        assertTrue(cancelRedeem7540.supportsInterface(iid), "cancelRedeem7540");
        assertTrue(cancelRedeemWithId7540.supportsInterface(iid), "cancelRedeemWithId7540");
        assertTrue(claimCancelDeposit7540.supportsInterface(iid), "claimCancelDeposit7540");
        assertTrue(claimCancelDepositWithId7540.supportsInterface(iid), "claimCancelDepositWithId7540");
        assertTrue(claimCancelRedeem7540.supportsInterface(iid), "claimCancelRedeem7540");
        assertTrue(claimCancelRedeemWithId7540.supportsInterface(iid), "claimCancelRedeemWithId7540");
        // Admin/config hooks
        assertTrue(setOperator7540.supportsInterface(iid), "setOperator7540");
        assertTrue(setSlippage.supportsInterface(iid), "setSlippage");
        assertTrue(markRootAsUsed.supportsInterface(iid), "markRootAsUsed");
        // Other hooks
        assertTrue(debridgeCancel.supportsInterface(iid), "debridgeCancel");
        assertTrue(circleGatewayAddDelegate.supportsInterface(iid), "circleGatewayAddDelegate");
        assertTrue(circleGatewayRemoveDelegate.supportsInterface(iid), "circleGatewayRemoveDelegate");
        assertTrue(offrampTokens.supportsInterface(iid), "offrampTokens");
        assertTrue(ethenaUnstake.supportsInterface(iid), "ethenaUnstake");
        assertTrue(metaMorphoReallocate.supportsInterface(iid), "metaMorphoReallocate");
        assertTrue(pendleRouterSwap.supportsInterface(iid), "pendleRouterSwap");
    }

    /// @dev All newly-S2 hooks must NOT support ISuperHookOutflow
    function test_NewlyS2_DoesNotSupport_Outflow() public view {
        bytes4 oid = type(ISuperHookOutflow).interfaceId;
        assertFalse(pendleUnified.supportsInterface(oid), "pendleUnified");
        assertFalse(batchTransferBasic.supportsInterface(oid), "batchTransferBasic");
        assertFalse(circleGatewayMinter.supportsInterface(oid), "circleGatewayMinter");
        assertFalse(recordPurchaseOracle.supportsInterface(oid), "recordPurchaseOracle");
        assertFalse(recordPurchaseOracleV2.supportsInterface(oid), "recordPurchaseOracleV2");
        assertFalse(recordRedemptionOracle.supportsInterface(oid), "recordRedemptionOracle");
        assertFalse(recordRedemptionOracleV2.supportsInterface(oid), "recordRedemptionOracleV2");
        assertFalse(claimRFLR.supportsInterface(oid), "claimRFLR");
        assertFalse(withdrawRFLR.supportsInterface(oid), "withdrawRFLR");
        assertFalse(withdrawVestedRFLR.supportsInterface(oid), "withdrawVestedRFLR");
        assertFalse(cancelDeposit7540.supportsInterface(oid), "cancelDeposit7540");
        assertFalse(cancelDepositWithId7540.supportsInterface(oid), "cancelDepositWithId7540");
        assertFalse(cancelRedeem7540.supportsInterface(oid), "cancelRedeem7540");
        assertFalse(cancelRedeemWithId7540.supportsInterface(oid), "cancelRedeemWithId7540");
        assertFalse(claimCancelDeposit7540.supportsInterface(oid), "claimCancelDeposit7540");
        assertFalse(claimCancelDepositWithId7540.supportsInterface(oid), "claimCancelDepositWithId7540");
        assertFalse(claimCancelRedeem7540.supportsInterface(oid), "claimCancelRedeem7540");
        assertFalse(claimCancelRedeemWithId7540.supportsInterface(oid), "claimCancelRedeemWithId7540");
        assertFalse(setOperator7540.supportsInterface(oid), "setOperator7540");
        assertFalse(setSlippage.supportsInterface(oid), "setSlippage");
        assertFalse(markRootAsUsed.supportsInterface(oid), "markRootAsUsed");
        assertFalse(debridgeCancel.supportsInterface(oid), "debridgeCancel");
        assertFalse(circleGatewayAddDelegate.supportsInterface(oid), "circleGatewayAddDelegate");
        assertFalse(circleGatewayRemoveDelegate.supportsInterface(oid), "circleGatewayRemoveDelegate");
        assertFalse(offrampTokens.supportsInterface(oid), "offrampTokens");
        assertFalse(ethenaUnstake.supportsInterface(oid), "ethenaUnstake");
        assertFalse(metaMorphoReallocate.supportsInterface(oid), "metaMorphoReallocate");
        assertFalse(pendleRouterSwap.supportsInterface(oid), "pendleRouterSwap");
    }

    /// @dev All newly-S2 hooks must return empty amountRoles
    function test_NewlyS2_AmountRoles_Empty() public view {
        assertEq(pendleUnified.amountRoles("").length, 0, "pendleUnified");
        assertEq(batchTransferBasic.amountRoles("").length, 0, "batchTransferBasic");
        assertEq(circleGatewayMinter.amountRoles("").length, 0, "circleGatewayMinter");
        assertEq(recordPurchaseOracle.amountRoles("").length, 0, "recordPurchaseOracle");
        assertEq(cancelDeposit7540.amountRoles("").length, 0, "cancelDeposit7540");
        assertEq(claimRFLR.amountRoles("").length, 0, "claimRFLR");
        assertEq(setOperator7540.amountRoles("").length, 0, "setOperator7540");
        assertEq(markRootAsUsed.amountRoles("").length, 0, "markRootAsUsed");
        assertEq(debridgeCancel.amountRoles("").length, 0, "debridgeCancel");
        assertEq(offrampTokens.amountRoles("").length, 0, "offrampTokens");
        assertEq(ethenaUnstake.amountRoles("").length, 0, "ethenaUnstake");
        assertEq(metaMorphoReallocate.amountRoles("").length, 0, "metaMorphoReallocate");
        assertEq(pendleRouterSwap.amountRoles("").length, 0, "pendleRouterSwap");
    }

    /// @dev All newly-S2 hooks must return empty decodeAmounts
    function test_NewlyS2_DecodeAmounts_Empty() public view {
        assertEq(pendleUnified.decodeAmounts("").length, 0, "pendleUnified");
        assertEq(batchTransferBasic.decodeAmounts("").length, 0, "batchTransferBasic");
        assertEq(circleGatewayMinter.decodeAmounts("").length, 0, "circleGatewayMinter");
        assertEq(recordPurchaseOracle.decodeAmounts("").length, 0, "recordPurchaseOracle");
        assertEq(cancelDeposit7540.decodeAmounts("").length, 0, "cancelDeposit7540");
        assertEq(claimRFLR.decodeAmounts("").length, 0, "claimRFLR");
        assertEq(setOperator7540.decodeAmounts("").length, 0, "setOperator7540");
        assertEq(markRootAsUsed.decodeAmounts("").length, 0, "markRootAsUsed");
        assertEq(debridgeCancel.decodeAmounts("").length, 0, "debridgeCancel");
        assertEq(offrampTokens.decodeAmounts("").length, 0, "offrampTokens");
        assertEq(ethenaUnstake.decodeAmounts("").length, 0, "ethenaUnstake");
        assertEq(metaMorphoReallocate.decodeAmounts("").length, 0, "metaMorphoReallocate");
        assertEq(pendleRouterSwap.decodeAmounts("").length, 0, "pendleRouterSwap");
    }

    /// @dev Spot-check: verify specific hooks return their expected descriptions
    function test_Description_SpotCheck() public view {
        assertEq(deposit4626.description(), "Deposits assets into an ERC-4626 vault and receives shares");
        assertEq(swapUniV3.description(), "Swaps tokens via Uniswap V3 exact input single");
        assertEq(acrossV1.description(), "Bridges tokens via Across and executes on destination chain");
        assertEq(morphoSupply.description(), "Supplies collateral to a Morpho market");
        assertEq(aaveSupply.description(), "Supplies assets to an Aave V4 lending pool");
    }

    /*//////////////////////////////////////////////////////////////
                    CI GUARDRAIL: INFLOW/OUTFLOW ⇒ SIZING
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns every hook instantiated in this test contract.
    function _allHooks() internal view returns (ISuperHook[] memory hooks) {
        hooks = new ISuperHook[](119);
        uint256 i;
        // ── Token (7) ──
        hooks[i++] = ISuperHook(address(transferERC20));
        hooks[i++] = ISuperHook(address(approveERC20));
        hooks[i++] = ISuperHook(address(transferHook));
        hooks[i++] = ISuperHook(address(nativeTransfer));
        hooks[i++] = ISuperHook(address(wrappedNative));
        hooks[i++] = ISuperHook(address(fetchNativeFee));
        hooks[i++] = ISuperHook(address(claimFailedTransfer));
        // ── Swappers (23) ──
        hooks[i++] = ISuperHook(address(swapUniV3));
        hooks[i++] = ISuperHook(address(approveSwapUniV3));
        hooks[i++] = ISuperHook(address(swapUniV3Router02));
        hooks[i++] = ISuperHook(address(approveSwapUniV3Router02));
        hooks[i++] = ISuperHook(address(swapUniV2));
        hooks[i++] = ISuperHook(address(approveSwapUniV2));
        hooks[i++] = ISuperHook(address(swapUniV4));
        hooks[i++] = ISuperHook(address(swapOdosV2));
        hooks[i++] = ISuperHook(address(approveSwapOdosV2));
        hooks[i++] = ISuperHook(address(swapOdosV3));
        hooks[i++] = ISuperHook(address(approveSwapOdosV3));
        hooks[i++] = ISuperHook(address(swapKyber));
        hooks[i++] = ISuperHook(address(approveSwapKyber));
        hooks[i++] = ISuperHook(address(swapSparkIn));
        hooks[i++] = ISuperHook(address(approveSwapSparkIn));
        hooks[i++] = ISuperHook(address(swapSparkOut));
        hooks[i++] = ISuperHook(address(approveSwapSparkOut));
        hooks[i++] = ISuperHook(address(swapAlgebra));
        hooks[i++] = ISuperHook(address(approveSwapAlgebra));
        hooks[i++] = ISuperHook(address(swapOpenOcean));
        hooks[i++] = ISuperHook(address(approveSwapOpenOcean));
        hooks[i++] = ISuperHook(address(spectraRedeem));
        hooks[i++] = ISuperHook(address(pendleRedeem));
        // ── Bridges (12) ──
        hooks[i++] = ISuperHook(address(acrossV1));
        hooks[i++] = ISuperHook(address(approveAcrossV1));
        hooks[i++] = ISuperHook(address(acrossV2));
        hooks[i++] = ISuperHook(address(approveAcrossV2));
        hooks[i++] = ISuperHook(address(stargate));
        hooks[i++] = ISuperHook(address(approveStargate));
        hooks[i++] = ISuperHook(address(stargateV2));
        hooks[i++] = ISuperHook(address(approveStargateV2));
        hooks[i++] = ISuperHook(address(debridge));
        hooks[i++] = ISuperHook(address(cctp));
        hooks[i++] = ISuperHook(address(approveCctp));
        hooks[i++] = ISuperHook(address(circleGateway));
        // ── Stake (6) ──
        hooks[i++] = ISuperHook(address(fluidStake));
        hooks[i++] = ISuperHook(address(approveFluidStake));
        hooks[i++] = ISuperHook(address(fluidUnstake));
        hooks[i++] = ISuperHook(address(gearboxStake));
        hooks[i++] = ISuperHook(address(approveGearboxStake));
        hooks[i++] = ISuperHook(address(gearboxUnstake));
        // ── Assets denomination (9) ──
        hooks[i++] = ISuperHook(address(deposit4626));
        hooks[i++] = ISuperHook(address(approveDeposit4626));
        hooks[i++] = ISuperHook(address(deposit5115));
        hooks[i++] = ISuperHook(address(approveDeposit5115));
        hooks[i++] = ISuperHook(address(deposit7540));
        hooks[i++] = ISuperHook(address(requestDeposit7540));
        hooks[i++] = ISuperHook(address(approveRequestDeposit7540));
        hooks[i++] = ISuperHook(address(withdraw7540));
        hooks[i++] = ISuperHook(address(withdrawWithId7540));
        // ── Shares denomination (11) ──
        hooks[i++] = ISuperHook(address(redeem4626));
        hooks[i++] = ISuperHook(address(redeem5115));
        hooks[i++] = ISuperHook(address(redeem7540));
        hooks[i++] = ISuperHook(address(redeemWithId7540));
        hooks[i++] = ISuperHook(address(requestRedeem7540));
        hooks[i++] = ISuperHook(address(requestRedeemDETH));
        hooks[i++] = ISuperHook(address(approveRequestRedeemDETH));
        hooks[i++] = ISuperHook(address(ethenaCooldown));
        hooks[i++] = ISuperHook(address(redeemFirelight));
        hooks[i++] = ISuperHook(address(mintSP));
        hooks[i++] = ISuperHook(address(burnSP));
        // ── Sizeless (7) ──
        hooks[i++] = ISuperHook(address(fluidClaim));
        hooks[i++] = ISuperHook(address(gearboxClaim));
        hooks[i++] = ISuperHook(address(yearnClaim));
        hooks[i++] = ISuperHook(address(merklClaim));
        hooks[i++] = ISuperHook(address(batchTransfer));
        hooks[i++] = ISuperHook(address(claimAssetsDETH));
        hooks[i++] = ISuperHook(address(claimWithdrawFirelight));
        // ── Loans (7) ──
        hooks[i++] = ISuperHook(address(morphoSupply));
        hooks[i++] = ISuperHook(address(morphoLend));
        hooks[i++] = ISuperHook(address(morphoBorrow));
        hooks[i++] = ISuperHook(address(morphoRepay));
        hooks[i++] = ISuperHook(address(morphoSupplyAndBorrow));
        hooks[i++] = ISuperHook(address(morphoRepayAndWithdraw));
        hooks[i++] = ISuperHook(address(morphoWithdraw));
        // ── Aave V4 (6) ──
        hooks[i++] = ISuperHook(address(aaveSupply));
        hooks[i++] = ISuperHook(address(aaveWithdraw));
        hooks[i++] = ISuperHook(address(aaveBorrow));
        hooks[i++] = ISuperHook(address(aaveRepay));
        hooks[i++] = ISuperHook(address(aaveSupplyAndBorrow));
        hooks[i++] = ISuperHook(address(aaveRepayAndWithdraw));
        // ── Newly-S1 (1) ──
        hooks[i++] = ISuperHook(address(forceDeallocateMorpho));
        // ── Newly-S2 (30) ──
        hooks[i++] = ISuperHook(address(pendleUnified));
        hooks[i++] = ISuperHook(address(pendleRouterSwap));
        hooks[i++] = ISuperHook(address(spectraExchangeDeposit));
        hooks[i++] = ISuperHook(address(swap1Inch));
        hooks[i++] = ISuperHook(address(batchTransferBasic));
        hooks[i++] = ISuperHook(address(circleGatewayMinter));
        hooks[i++] = ISuperHook(address(circleGatewayAddDelegate));
        hooks[i++] = ISuperHook(address(circleGatewayRemoveDelegate));
        hooks[i++] = ISuperHook(address(debridgeCancel));
        hooks[i++] = ISuperHook(address(recordPurchaseOracle));
        hooks[i++] = ISuperHook(address(recordPurchaseOracleV2));
        hooks[i++] = ISuperHook(address(recordRedemptionOracle));
        hooks[i++] = ISuperHook(address(recordRedemptionOracleV2));
        hooks[i++] = ISuperHook(address(claimRFLR));
        hooks[i++] = ISuperHook(address(withdrawRFLR));
        hooks[i++] = ISuperHook(address(withdrawVestedRFLR));
        hooks[i++] = ISuperHook(address(cancelDeposit7540));
        hooks[i++] = ISuperHook(address(cancelDepositWithId7540));
        hooks[i++] = ISuperHook(address(cancelRedeem7540));
        hooks[i++] = ISuperHook(address(cancelRedeemWithId7540));
        hooks[i++] = ISuperHook(address(claimCancelDeposit7540));
        hooks[i++] = ISuperHook(address(claimCancelDepositWithId7540));
        hooks[i++] = ISuperHook(address(claimCancelRedeem7540));
        hooks[i++] = ISuperHook(address(claimCancelRedeemWithId7540));
        hooks[i++] = ISuperHook(address(setOperator7540));
        hooks[i++] = ISuperHook(address(setSlippage));
        hooks[i++] = ISuperHook(address(markRootAsUsed));
        hooks[i++] = ISuperHook(address(offrampTokens));
        hooks[i++] = ISuperHook(address(ethenaUnstake));
        hooks[i++] = ISuperHook(address(metaMorphoReallocate));

        assertEq(i, 119, "allHooks count mismatch - add new hooks here");
    }

    /// @dev CI guardrail: every INFLOW or OUTFLOW hook MUST support both sizing interfaces.
    ///      If a hook is INFLOW/OUTFLOW but lacks ISuperHookOutflow it will silently
    ///      bypass OMS amount resizing, breaking M2/M3 accounting.
    function test_Invariant_InflowOutflow_MustSupportSizing() public view {
        ISuperHook[] memory hooks = _allHooks();
        bytes4 inflowOutflowId = type(ISuperHookInflowOutflow).interfaceId;
        bytes4 outflowId = type(ISuperHookOutflow).interfaceId;

        for (uint256 i; i < hooks.length; i++) {
            ISuperHook.HookType ht = ISuperHookResult(address(hooks[i])).hookType();

            if (ht == ISuperHook.HookType.INFLOW || ht == ISuperHook.HookType.OUTFLOW) {
                assertTrue(
                    IERC165(address(hooks[i])).supportsInterface(inflowOutflowId),
                    string.concat(hooks[i].name(), " is INFLOW/OUTFLOW but missing ISuperHookInflowOutflow")
                );
                assertTrue(
                    IERC165(address(hooks[i])).supportsInterface(outflowId),
                    string.concat(hooks[i].name(), " is INFLOW/OUTFLOW but missing ISuperHookOutflow")
                );
            }
        }
    }

    /// @dev CI guardrail: no half-state — if a hook declares ISuperHookInflowOutflow
    ///      with non-empty decodeAmounts, it MUST also support ISuperHookOutflow.
    ///      Hooks that return empty decodeAmounts (S2 decode-only) are exempt.
    function test_Invariant_NonEmptyDecodeAmounts_ImpliesOutflow() public view {
        ISuperHook[] memory hooks = _allHooks();
        bytes4 outflowId = type(ISuperHookOutflow).interfaceId;

        for (uint256 i; i < hooks.length; i++) {
            // Try decodeAmounts with empty data — hooks with actual amounts will return non-empty
            try ISuperHookInflowOutflow(address(hooks[i])).decodeAmounts("") returns (uint256[] memory amounts) {
                if (amounts.length > 0) {
                    assertTrue(
                        IERC165(address(hooks[i])).supportsInterface(outflowId),
                        string.concat(hooks[i].name(), " has non-empty decodeAmounts but missing ISuperHookOutflow")
                    );
                }
            } catch {
                // Hook doesn't implement decodeAmounts or reverts — that's fine
            }
        }
    }
}

/// @dev Dummy libraries to avoid "unused" warnings on enum types
library Dir {
    function isIn(ISuperHookInflowOutflow.Direction d) internal pure returns (bool) {
        return d == ISuperHookInflowOutflow.Direction.IN;
    }
}

library Den {
    function isToken(ISuperHookInflowOutflow.Denomination d) internal pure returns (bool) {
        return d == ISuperHookInflowOutflow.Denomination.TOKEN;
    }
}
