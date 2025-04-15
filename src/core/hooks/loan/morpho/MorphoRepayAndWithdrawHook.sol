// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IIrm } from "../../../../vendor/morpho/IIrm.sol";
import { MathLib } from "../../../../vendor/morpho/MathLib.sol";
import { IOracle } from "../../../../vendor/morpho/IOracle.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesMathLib } from "../../../../vendor/morpho/SharesMathLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { MarketParamsLib } from "../../../../vendor/morpho/MarketParamsLib.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {
    IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams, Id, Market
} from "../../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
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
/// @notice         bool isPositiveFeed = _decodeBool(data, 145);
/// @notice         bool isFullRepayment = _decodeBool(data, 146);
contract MorphoRepayAndWithdrawHook is BaseMorphoLoanHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoBase;
    IMorphoStaticTyping public morphoStaticTyping;

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address morpho_) BaseMorphoLoanHook(registry_, HookSubTypes.LOAN_REPAY) {
        if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
        morpho = morpho_;
        morphoBase = IMorphoBase(morpho_);
        morphoInterface = IMorpho(morpho_);
        morphoStaticTyping = IMorphoStaticTyping(morpho_);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address account,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        BuildHookLocalVars memory vars = _decodeHookData(data);

        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        Id id = marketParams.id();

        uint256 fee = deriveFeeAmount(marketParams);
        uint256 collateralForWithdraw;

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        if (vars.isFullRepayment) {
            uint128 borrowBalance = deriveShareBalance(id, account);
            uint256 shareBalance = uint256(borrowBalance);
            uint256 amountToApprove = deriveLoanAmount(id, account) + deriveInterest(marketParams) + fee;
            collateralForWithdraw = deriveCollateralForFullRepayment(id, account);

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, amountToApprove))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(IMorphoBase.repay, (marketParams, 0, shareBalance, account, "")) // 0 assets as
                    // we are repaying in full
             });
            executions[4] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.withdrawCollateral, (marketParams, collateralForWithdraw, account, account)
                )
            });
        } else {
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).outAmount();
            }
            uint256 fullCollateral = deriveCollateralForFullRepayment(id, account);
            collateralForWithdraw = deriveCollateralForPartialRepayment(
                id,
                vars.oracle,
                vars.loanToken,
                vars.collateralToken,
                account,
                vars.amount,
                fullCollateral,
                vars.isPositiveFeed
            );

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(IMorphoBase.repay, (marketParams, vars.amount, 0, account, "")) // 0 shares as
                    // partial repayment
             });
            executions[4] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.withdrawCollateral, (marketParams, collateralForWithdraw, account, account)
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

    /*//////////////////////////////////////////////////////////////
                            PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    function deriveInterest(MarketParams memory marketParams) public view returns (uint256 interest) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
        if (block.timestamp > market.lastUpdate) {
            uint256 elapsed = block.timestamp - market.lastUpdate;
            interest = MathLib.wMulDown(market.totalBorrowAssets, MathLib.wTaylorCompounded(borrowRate, elapsed));
        } else {
           revert INVALID_TIMESTAMP();
        }
    }

    function deriveShareBalance(Id id, address account) public view returns (uint128 borrowShares) {
        (, borrowShares,) = morphoStaticTyping.position(id, account);
    }

    function deriveCollateralForFullRepayment(Id id, address account) public view returns (uint256 collateralAmount) {
        (,, uint128 collateral) = morphoStaticTyping.position(id, account);
        collateralAmount = uint256(collateral);
    }

    function deriveCollateralAmountFromLoanAmount(
        address loanToken,
        address oracle,
        address collateralToken,
        bool isPositiveFeed,
        uint256 loanAmount
    )
        public
        view
        returns (uint256 collateralAmount)
    {
        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();
        uint256 loanDecimals = ERC20(loanToken).decimals();
        uint256 collateralDecimals = ERC20(collateralToken).decimals();

        if (collateralDecimals > 36 + loanDecimals) revert TOKEN_DECIMALS_NOT_SUPPORTED();

        // Correct scaling factor as per the oracle's specification:
        // 10^(36 + loanDecimals - collateralDecimals)
        uint256 scalingFactor = 10 ** (36 + loanDecimals - collateralDecimals);

        if (isPositiveFeed) {
            // loanAmount = collateralAmount * price / scalingFactor
            collateralAmount = Math.mulDiv(loanAmount, scalingFactor, price);
        } else {
            // loanAmount = collateralAmount * scalingFactor / price
            collateralAmount = Math.mulDiv(loanAmount, price, scalingFactor);
        }
    }

    function deriveCollateralForPartialRepayment(
        Id id,
        address oracle,
        address loanToken,
        address collateralToken,
        address account,
        uint256 amount,
        uint256 fullCollateral,
        bool isPositiveFeed
    )
        public
        view
        returns (uint256 withdrawableCollateral)
    {
        uint256 fullLoanAmount = deriveLoanAmount(id, account);
        if (fullLoanAmount < amount) revert AMOUNT_NOT_VALID();
        uint256 remainingLoanAmount = fullLoanAmount - amount;
        uint256 loanDecimals = ERC20(loanToken).decimals();
        uint256 collateralDecimals = ERC20(collateralToken).decimals();
        uint256 scalingFactor = 10 ** (36 + loanDecimals - collateralDecimals);

        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();

        uint256 requiredCollateralForRemaining;
        if (isPositiveFeed) {
            // For a positive feed, the oracle returns the price in units of loan token per collateral token.
            // The collateral required is:
            //   requiredCollateral = remainingLoan * scalingFactor / price
            requiredCollateralForRemaining = Math.mulDiv(remainingLoanAmount, scalingFactor, price);
        } else {
            // For a negative feed, the oracle returns the price in units of collateral token per loan token.
            // The collateral required is:
            //   requiredCollateral = remainingLoan * price / scalingFactor
            requiredCollateralForRemaining = Math.mulDiv(remainingLoanAmount, price, scalingFactor);
        }
        if (fullCollateral > requiredCollateralForRemaining) {
            withdrawableCollateral = fullCollateral - requiredCollateralForRemaining;
        } else {
            revert AMOUNT_NOT_VALID();
        }
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
