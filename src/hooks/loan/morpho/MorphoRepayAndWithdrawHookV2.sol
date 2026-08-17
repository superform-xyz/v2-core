// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesMathLib } from "../../../vendor/morpho/SharesMathLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";
import { IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams, Id, Market } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title MorphoRepayAndWithdrawHookV2
/// @author Superform Labs
/// @notice Repays borrowed assets and withdraws collateral from a Morpho market with independent exact amounts
/// @dev V2 correction: Both repay and withdraw amounts are independently sized by the OMS,
///      NOT proportionally derived from debt ratio like V1.
///      Full repayment uses share-based repay with post-accrual debt.
///      Partial repay caps to current debt under interest drift.
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 primaryAmount = BytesLib.toUint256(data, 132);     // repay amount
/// @notice         uint256 secondaryAmount = BytesLib.toUint256(data, 164);   // withdraw amount (0 = repay-only)
/// @notice         bool usePrevHookAmount = _decodeBool(data, 196);           // applies to primaryAmount only
/// @notice         bool isFullRepayment = _decodeBool(data, 197);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 198);
/// @dev KNOWN LIMITATION (P1-2): An attacker can front-run full repayment by repaying 1 wei of shares
///      on behalf of the borrower, causing the victim's transaction to revert.
/// @dev KNOWN LIMITATION (P1-3): Interest accrues between build() and execute(). _preExecute calls
///      accrueInterest() before the actual repay, but the approval was set during build().
/// @dev outAmount tracks collateral tokens received (post-balance - pre-balance).
///      When secondaryAmount = 0, this is a repay-only execution (no withdraw).
contract MorphoRepayAndWithdrawHookV2 is BaseMorphoLoanHook {
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 internal constant SECONDARY_AMOUNT_OFFSET = 164;
    uint256 internal constant V2_IS_FULL_REPAYMENT_OFFSET = 197;
    uint256 internal constant V2_LLTV_OFFSET = 198;
    uint256 internal constant V2_MIN_DATA_LENGTH = 230;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/

    IMorphoStaticTyping public immutable morphoStaticTyping;

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct RepayWithdrawVars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 primaryAmount;
        uint256 secondaryAmount;
        bool usePrevHookAmount;
        bool isFullRepayment;
        uint256 lltv;
    }

    struct BuildContext {
        MarketParams marketParams;
        Id id;
        uint256 repayAmount;
        uint256 approvalAmount;
        uint256 shareBalance;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue protocol
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) {
        morphoStaticTyping = IMorphoStaticTyping(morpho_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Repay and Withdraw V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Repays debt and withdraws collateral from a Morpho market with independent exact amounts";
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        RepayWithdrawVars memory vars = _decodeV2Data(data);

        BuildContext memory ctx;
        ctx.marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        ctx.id = ctx.marketParams.id();

        if (vars.isFullRepayment) {
            // Full repay: share-based repay with post-accrual debt
            (, uint128 borrowShares,) = morphoStaticTyping.position(ctx.id, account);
            ctx.shareBalance = uint256(borrowShares);
            if (ctx.shareBalance == 0) revert AMOUNT_NOT_VALID();

            // Derive loan amount for approval (rounds up to cover accrued interest)
            Market memory market = IMorpho(morpho).market(ctx.id);
            ctx.approvalAmount = ctx.shareBalance.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
        } else {
            // Partial repay: use specified or prev-hook amount
            if (vars.usePrevHookAmount) {
                vars.primaryAmount = ISuperHookResult(prevHook).getOutAmount(account);
            }
            ctx.repayAmount = vars.primaryAmount;
            if (ctx.repayAmount == 0) revert AMOUNT_NOT_VALID();

            // Cap repay to current debt under interest drift
            Market memory market = IMorpho(morpho).market(ctx.id);
            (, uint128 borrowShares,) = morphoStaticTyping.position(ctx.id, account);
            uint256 currentDebt = uint256(borrowShares).toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
            if (ctx.repayAmount > currentDebt) {
                ctx.repayAmount = currentDebt;
            }

            ctx.approvalAmount = ctx.repayAmount;
        }

        if (vars.secondaryAmount == 0) {
            // REPAY-ONLY path: no collateral withdrawal
            if (vars.isFullRepayment) {
                // Full repay-only: share-based
                executions = new Execution[](4);
                executions[0] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
                executions[1] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, ctx.approvalAmount))
                });
                executions[2] = Execution({
                    target: morpho,
                    value: 0,
                    callData: abi.encodeCall(
                        IMorphoBase.repay, (ctx.marketParams, 0, ctx.shareBalance, account, "")
                    )
                });
                executions[3] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
            } else {
                // Partial repay-only: asset-based
                executions = new Execution[](4);
                executions[0] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
                executions[1] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, ctx.approvalAmount))
                });
                executions[2] = Execution({
                    target: morpho,
                    value: 0,
                    callData: abi.encodeCall(
                        IMorphoBase.repay, (ctx.marketParams, ctx.repayAmount, 0, account, "")
                    )
                });
                executions[3] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
            }
        } else {
            // REPAY + WITHDRAW path
            if (vars.isFullRepayment) {
                // Full repay + independent withdraw: share-based repay
                executions = new Execution[](5);
                executions[0] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
                executions[1] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, ctx.approvalAmount))
                });
                executions[2] = Execution({
                    target: morpho,
                    value: 0,
                    callData: abi.encodeCall(
                        IMorphoBase.repay, (ctx.marketParams, 0, ctx.shareBalance, account, "")
                    )
                });
                executions[3] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
                executions[4] = Execution({
                    target: morpho,
                    value: 0,
                    callData: abi.encodeCall(
                        IMorphoBase.withdrawCollateral,
                        (ctx.marketParams, vars.secondaryAmount, account, account)
                    )
                });
            } else {
                // Partial repay + independent withdraw: asset-based repay
                executions = new Execution[](5);
                executions[0] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
                executions[1] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, ctx.approvalAmount))
                });
                executions[2] = Execution({
                    target: morpho,
                    value: 0,
                    callData: abi.encodeCall(
                        IMorphoBase.repay, (ctx.marketParams, ctx.repayAmount, 0, account, "")
                    )
                });
                executions[3] = Execution({
                    target: vars.loanToken,
                    value: 0,
                    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
                });
                executions[4] = Execution({
                    target: morpho,
                    value: 0,
                    callData: abi.encodeCall(
                        IMorphoBase.withdrawCollateral,
                        (ctx.marketParams, vars.secondaryAmount, account, account)
                    )
                });
            }
        }
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
        amounts[1] = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 2) revert INVALID_AMOUNTS_LENGTH();
        data = _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
        return _replaceCalldataAmount(data, amounts[1], SECONDARY_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN
        );
        meta[1] = ISuperHookInflowOutflow.AmountMeta(
            ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN
        );
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        RepayWithdrawVars memory vars = _decodeV2Data(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        return abi.encodePacked(
            marketParams.loanToken, marketParams.collateralToken, marketParams.oracle, marketParams.irm
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    function _decodeV2Data(bytes memory data) internal pure returns (RepayWithdrawVars memory vars) {
        if (data.length < V2_MIN_DATA_LENGTH) revert INVALID_DATA_LENGTH();

        vars.loanToken = BytesLib.toAddress(data, LOAN_TOKEN_OFFSET);
        vars.collateralToken = BytesLib.toAddress(data, COLLATERAL_TOKEN_OFFSET);
        vars.oracle = BytesLib.toAddress(data, ORACLE_OFFSET);
        vars.irm = BytesLib.toAddress(data, IRM_OFFSET);
        vars.primaryAmount = BytesLib.toUint256(data, AMOUNT_POSITION);
        vars.secondaryAmount = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
        vars.usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
        vars.isFullRepayment = _decodeBool(data, V2_IS_FULL_REPAYMENT_OFFSET);
        vars.lltv = BytesLib.toUint256(data, V2_LLTV_OFFSET);

        if (
            vars.loanToken == address(0) || vars.collateralToken == address(0) || vars.oracle == address(0)
                || vars.irm == address(0)
        ) {
            revert ADDRESS_NOT_VALID();
        }
    }

    /// @inheritdoc BaseHook
    /// @dev Calls accrueInterest before storing collateral balance for delta tracking
    function _preExecute(address, address account, bytes calldata data) internal override {
        RepayWithdrawVars memory vars = _decodeV2Data(data);
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        IMorpho(morpho).accrueInterest(marketParams);

        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data) - getOutAmount(account), account);
        _setOutToken(getCollateralTokenAddress(data), account);
    }
}
