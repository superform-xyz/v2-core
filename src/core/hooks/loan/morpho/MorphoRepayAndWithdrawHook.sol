// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IIrm } from "../../../../vendor/morpho/IIrm.sol";
import { MathLib } from "../../../../vendor/morpho/MathLib.sol";
import { IOracle } from "../../../../vendor/morpho/IOracle.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesMathLib } from "../../../../vendor/morpho/SharesMathLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { MarketParamsLib } from "../../../../vendor/morpho/MarketParamsLib.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams, Id, Market
} from "../../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { ISuperHook, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookLoans } from "../../../interfaces/ISuperHook.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title MorphoRepayAndWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address collateralToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         address oracle = BytesLib.toAddress(BytesLib.slice(data, 40, 20), 0);
/// @notice         address irm = BytesLib.toAddress(BytesLib.slice(data, 60, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 80, 32), 0);
/// @notice         uint256 lltv = BytesLib.toUint256(BytesLib.slice(data, 112, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
/// @notice         bool isFullRepayment = _decodeBool(data, 145);
contract MorphoRepayAndWithdrawHook is BaseMorphoLoanHook, ISuperHookInspector {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoBase;
    IMorphoStaticTyping public morphoStaticTyping;

    struct BuildExecutionContext {
        MarketParams marketParams;
        Id id;
        uint256 fee;
        uint256 collateralForWithdraw;
        uint128 borrowBalance;
        uint256 shareBalance;
        uint256 amountToApprove;
        uint256 fullCollateral;
    }


    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant PRICE_SCALING_FACTOR = 1e36;
    uint256 private constant PERCENTAGE_SCALING_FACTOR = 1e18;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
        morphoInterface = IMorpho(morpho_);
        morphoStaticTyping = IMorphoStaticTyping(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
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
        BuildHookLocalVars memory vars = _decodeHookData(data);
        if (vars.amount == 0) revert AMOUNT_NOT_VALID();
        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        BuildExecutionContext memory ctx;
        ctx.marketParams = _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        ctx.id = ctx.marketParams.id();
        ctx.fee = deriveFeeAmount(ctx.marketParams);

        executions = new Execution[](5);
        executions[0] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });
        executions[3] = Execution({
            target: vars.loanToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });

        if (vars.isFullRepayment) {
            ctx.borrowBalance = deriveShareBalance(ctx.id, account);
            ctx.shareBalance = uint256(ctx.borrowBalance);
            ctx.amountToApprove = deriveLoanAmount(ctx.id, account) + deriveInterest(ctx.marketParams) + ctx.fee;
            ctx.collateralForWithdraw = deriveCollateralForFullRepayment(ctx.id, account);

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, ctx.amountToApprove))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.repay,
                    (ctx.marketParams, 0, ctx.shareBalance, account, "")
                )
            });
            executions[4] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.withdrawCollateral,
                    (ctx.marketParams, ctx.collateralForWithdraw, account, account)
                )
            });
        } else {
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).outAmount();
            }

            ctx.fullCollateral = deriveCollateralForFullRepayment(ctx.id, account);
            ctx.collateralForWithdraw =
                deriveCollateralForPartialRepayment(ctx.id, account, vars.amount, ctx.fullCollateral);

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.repay,
                    (ctx.marketParams, vars.amount, 0, account, "")
                )
            });
            executions[4] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.withdrawCollateral,
                    (ctx.marketParams, ctx.collateralForWithdraw, account, account)
                )
            });
        }
    }


    /// @inheritdoc ISuperHookLoans
    function getUsedAssets(address account, bytes memory data) external view returns (uint256) {
        BuildHookLocalVars memory vars = _decodeHookData(data);
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        Id id = marketParams.id();
        if (vars.isFullRepayment) {
            return outAmount + deriveCollateralForFullRepayment(id, account) + deriveInterest(marketParams);
        } else {
            return outAmount;
        }
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        BuildHookLocalVars memory vars = _decodeHookData(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        return abi.encodePacked(
            marketParams.loanToken, marketParams.collateralToken, marketParams.oracle, marketParams.irm
        );
    }
    /*//////////////////////////////////////////////////////////////
                            PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/

    function deriveInterest(MarketParams memory marketParams) public view returns (uint256 interest) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
        if (block.timestamp < market.lastUpdate) revert INVALID_TIMESTAMP();

        uint256 elapsed = block.timestamp - market.lastUpdate;
        interest = MathLib.wMulDown(market.totalBorrowAssets, MathLib.wTaylorCompounded(borrowRate, elapsed));
    }

    function deriveShareBalance(Id id, address account) public view returns (uint128 borrowShares) {
        (, borrowShares,) = morphoStaticTyping.position(id, account);
    }

    function deriveCollateralForFullRepayment(Id id, address account) public view returns (uint256 collateralAmount) {
        (,, uint128 collateral) = morphoStaticTyping.position(id, account);
        collateralAmount = uint256(collateral);
    }

    function deriveCollateralAmountFromLoanAmount(
        address oracle,
        uint256 loanAmount
    )
        public
        view
        returns (uint256 collateralAmount)
    {
        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();

        collateralAmount = Math.mulDiv(loanAmount, PRICE_SCALING_FACTOR, price);
    }

    function deriveCollateralForPartialRepayment(
        Id id,
        address account,
        uint256 amount,
        uint256 fullCollateral
    )
        public
        view
        returns (uint256 withdrawableCollateral)
    {
        uint256 fullLoanAmount = deriveLoanAmount(id, account);
        if (fullLoanAmount < amount) revert AMOUNT_NOT_VALID();

        withdrawableCollateral = Math.mulDiv(fullCollateral, amount, fullLoanAmount);
    }

    function deriveLoanAmount(Id id, address account) public view returns (uint256 loanAmount) {
        (, uint128 fullShares,) = morphoStaticTyping.position(id, account);
        uint256 castShares = uint256(fullShares);

        Market memory market = morphoInterface.market(id);
        loanAmount = castShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    function sharesToAssets(MarketParams memory marketParams, address account) public view returns (uint256 assets) {
        Id id = marketParams.id();
        uint256 shareBalance = deriveShareBalance(id, account);
        Market memory market = morphoInterface.market(id);
        assets = shareBalance.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    function assetsToShares(MarketParams memory marketParams, uint256 assets) public view returns (uint256 shares) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        shares = assets.toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        // store current balance
        outAmount = getCollateralTokenBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = getCollateralTokenBalance(account, data) - outAmount;
    }
}
