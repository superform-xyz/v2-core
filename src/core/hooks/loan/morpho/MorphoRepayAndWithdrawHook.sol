// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { IIrm } from "../../../../vendor/morpho/IIrm.sol";
import { BytesLib } from "../../../../vendor/BytesLib.sol";
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
import { BaseLoanHook } from "../BaseLoanHook.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
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
/// @notice         bool isPositiveFeed = _decodeBool(data, 146);
contract MorphoRepayAndWithdrawHook is BaseHook, BaseLoanHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;
    using SharesMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               STORAGE
    //////////////////////////////////////////////////////////////*/
    address public morpho;
    IMorphoBase public morphoBase;
    IMorpho public morphoInterface;
    IMorphoStaticTyping public morphoStaticTyping;

    uint256 private constant AMOUNT_POSITION = 80;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 144;

    struct BuildHookLocalVars {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 amount;
        uint256 lltv;
        bool usePrevHookAmount;
        bool isFullRepayment;
        bool isPositiveFeed;
        Id id;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address registry_, address morpho_) BaseLoanHook(registry_, "LoanRepay") {
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

        uint256 fee = _deriveFeeAmount(marketParams);
        uint256 collateralForWithdraw;
        executions = new Execution[](5);
        if (vars.isFullRepayment) {
            uint128 borrowBalance = _deriveShareBalance(vars.id, account);
            uint256 shareBalance = uint256(borrowBalance);
            uint256 assetsToPay = _deriveInterest(marketParams) + fee + _sharesToAssets(marketParams, account);
            collateralForWithdraw = _deriveCollateralForFullRepayment(vars.id, account);

            executions[0] =
                Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, assetsToPay))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(IMorphoBase.repay, (marketParams, 0, shareBalance, account, "")) // 0 assets as
                    // we are repaying in full
             });
            executions[3] =
                Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
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
            uint256 fullCollateral = _deriveCollateralForFullRepayment(vars.id, account);
            collateralForWithdraw = _deriveCollateralForPartialRepayment(
                vars.id,
                vars.oracle,
                vars.loanToken,
                vars.collateralToken,
                account,
                vars.amount,
                fullCollateral,
                vars.isPositiveFeed
            );
            executions[0] =
                Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
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
            executions[3] =
                Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
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
        address loanToken = BytesLib.toAddress(data, 0);
        address oracle = BytesLib.toAddress(data, 40);
        address collateralToken = BytesLib.toAddress(data, 20);
        bool isPositiveFeed = _decodeBool(data, 146);
        uint256 loanAmount = _decodeAmount(data);
        return _deriveCollateralAmountFromLoanAmount(loanToken, oracle, collateralToken, isPositiveFeed, outAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        // store current balance
        outAmount = getCollateralTokenBalance(account, data);
    }

    function _postExecute(address prevHook, address account, bytes calldata data) internal override {
        outAmount = getCollateralTokenBalance(account, data) - outAmount;
    }

    function _decodeHookData(bytes memory data) internal pure returns (BuildHookLocalVars memory vars) {
        address loanToken = BytesLib.toAddress(data, 0);
        address collateralToken = BytesLib.toAddress(data, 20);
        address oracle = BytesLib.toAddress(data, 40);
        address irm = BytesLib.toAddress(data, 60);
        uint256 amount = _decodeAmount(data);
        uint256 lltv = BytesLib.toUint256(data, 112);
        bool usePrevHookAmount = _decodeBool(data, 144);
        bool isFullRepayment = _decodeBool(data, 145);
        bool isPositiveFeed = _decodeBool(data, 146);

        MarketParams memory marketParams = _generateMarketParams(loanToken, collateralToken, oracle, irm, lltv);
        Id id = marketParams.id();

        vars = BuildHookLocalVars({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            amount: amount,
            lltv: lltv,
            usePrevHookAmount: usePrevHookAmount,
            isFullRepayment: isFullRepayment,
            isPositiveFeed: isPositiveFeed,
            id: id
        });
    }

    function _generateMarketParams(
        address loanToken,
        address collateralToken,
        address oracle,
        address irm,
        uint256 lltv
    )
        internal
        pure
        returns (MarketParams memory)
    {
        return MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }

    function _deriveInterest(MarketParams memory marketParams) internal view returns (uint256 interest) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
        uint256 elapsed = block.timestamp - market.lastUpdate;
        interest = MathLib.wMulDown(market.totalBorrowAssets, MathLib.wTaylorCompounded(borrowRate, elapsed));
    }

    function _deriveShareBalance(Id id, address account) internal view returns (uint128 borrowShares) {
        (, borrowShares,) = morphoStaticTyping.position(id, account);
    }

    function _deriveCollateralForFullRepayment(
        Id id,
        address account
    )
        internal
        view
        returns (uint256 collateralAmount)
    {
        (,, uint128 collateral) = morphoStaticTyping.position(id, account);
        collateralAmount = uint256(collateral);
    }

    function _deriveCollateralAmountFromLoanAmount(
        address loanToken,
        address oracle,
        address collateralToken,
        bool isPositiveFeed,
        uint256 loanAmount
    )
        internal
        view
        returns (uint256 collateralAmount)
    {
        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();
        uint256 loanDecimals = ERC20(loanToken).decimals();
        uint256 collateralDecimals = ERC20(collateralToken).decimals();

        // Correct scaling factor as per the oracle's specification:
        // 10^(36 + loanDecimals - collateralDecimals)
        uint256 scalingFactor = 10 ** (36 + loanDecimals - collateralDecimals);

        if (isPositiveFeed) {
            // Inverting the original calculation when isPositiveFeed is true:
            // loanAmount = collateralAmount * price / scalingFactor
            collateralAmount = Math.mulDiv(loanAmount, scalingFactor, price);
        } else {
            // Inverting the original calculation when isPositiveFeed is false:
            // loanAmount = collateralAmount * scalingFactor / price
            collateralAmount = Math.mulDiv(loanAmount, price, scalingFactor);
        }
    }

    function _deriveCollateralForPartialRepayment(
        Id id,
        address oracle,
        address loanToken,
        address collateralToken,
        address account,
        uint256 amount,
        uint256 fullCollateral,
        bool isPositiveFeed
    )
        internal
        view
        returns (uint256 withdrawableCollateral)
    {
        uint256 fullLoanAmount = _deriveLoanAmount(id, account);
        // uint256 fullLoanAmountInCollateral = _deriveCollateralAmountFromLoanAmount(loanToken, oracle,
        // collateralToken, isPositiveFeed, fullLoanAmount);
        // uint256 remainingLoan;
        // if (fullLoanAmountInCollateral >= amount) {
        //     remainingLoan = fullLoanAmountInCollateral - amount;
        // } else {
        //     return 0;
        // }
        uint256 remainingLoanAmount = fullLoanAmount - amount;
        uint256 loanDecimals = ERC20(loanToken).decimals();
        uint256 collateralDecimals = ERC20(collateralToken).decimals();
        uint256 scalingFactor = 10 ** (36 + loanDecimals - collateralDecimals);

        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();

        // Compute the collateral still required to back the remaining debt.
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

        withdrawableCollateral = fullCollateral - requiredCollateralForRemaining;
    }

    function _deriveLoanAmount(Id id, address account) internal view returns (uint256 loanAmount) {
        (, uint128 fullShares,) = morphoStaticTyping.position(id, account);
        uint256 castShares = uint256(fullShares);

        Market memory market = morphoInterface.market(id);
        loanAmount = castShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    function _deriveFeeAmount(MarketParams memory marketParams) internal view returns (uint256 feeAmount) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
        uint256 elapsed = block.timestamp - market.lastUpdate;
        uint256 interest = MathLib.wMulDown(market.totalBorrowAssets, MathLib.wTaylorCompounded(borrowRate, elapsed));

        feeAmount = MathLib.wMulDown(interest, market.fee);
    }

    function _sharesToAssets(
        MarketParams memory marketParams,
        address account
    )
        internal
        view
        returns (uint256 assets)
    {
        Id id = marketParams.id();
        uint256 shareBalance = _deriveShareBalance(id, account);
        Market memory market = morphoInterface.market(id);
        assets = shareBalance.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    function _assetsToShares(MarketParams memory marketParams, uint256 assets) internal view returns (uint256 shares) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        shares = assets.toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
    }
}
