// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IIrm } from "../../../vendor/morpho/IIrm.sol";
import { MathLib } from "../../../vendor/morpho/MathLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SharesMathLib } from "../../../vendor/morpho/SharesMathLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";
import { IMorpho, IMorphoBase, IMorphoStaticTyping, MarketParams, Id, Market } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoRepayAndWithdrawHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address oracle = BytesLib.toAddress(data, 40);
/// @notice         address irm = BytesLib.toAddress(data, 60);
/// @notice         uint256 amount = BytesLib.toUint256(data, 80);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 112);
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
        uint256 collateralForWithdraw;
        uint256 fullCollateral;
        uint128 borrowBalance;
        uint256 shareBalance;
    }

    uint256 private constant PRICE_SCALING_FACTOR = 1e36;
    uint256 private constant PERCENTAGE_SCALING_FACTOR = 1e18;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN_REPAY) {
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
        if (vars.loanToken == address(0) || vars.collateralToken == address(0)) revert ADDRESS_NOT_VALID();

        BuildExecutionContext memory ctx;
        ctx.marketParams = _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        ctx.id = ctx.marketParams.id();

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[3] =
            Execution({ target: vars.loanToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });

        if (vars.isFullRepayment) {
            ctx.borrowBalance = deriveShareBalance(ctx.id, account);
            ctx.shareBalance = uint256(ctx.borrowBalance);
            ctx.collateralForWithdraw = deriveCollateralForFullRepayment(ctx.id, account);

            executions[1] = Execution({
                target: vars.loanToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (morpho, deriveLoanAmount(ctx.id, account)))
            });
            executions[2] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(IMorphoBase.repay, (ctx.marketParams, 0, ctx.shareBalance, account, ""))
            });
            executions[4] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.withdrawCollateral, (ctx.marketParams, ctx.collateralForWithdraw, account, account)
                )
            });
        } else {
            if (vars.usePrevHookAmount) {
                vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
            }
            if (vars.amount == 0) revert AMOUNT_NOT_VALID();

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
                callData: abi.encodeCall(IMorphoBase.repay, (ctx.marketParams, vars.amount, 0, account, ""))
            });
            executions[4] = Execution({
                target: morpho,
                value: 0,
                callData: abi.encodeCall(
                    IMorphoBase.withdrawCollateral, (ctx.marketParams, ctx.collateralForWithdraw, account, account)
                )
            });
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
    /// @dev derive the share balance of the account
    /// @param id the id of the market
    /// @param account the account to derive the share balance for
    /// @return borrowShares the share balance of the account

    function deriveShareBalance(Id id, address account) public view returns (uint128 borrowShares) {
        (, borrowShares,) = morphoStaticTyping.position(id, account);
    }

    /// @dev derive the collateral balance of the account
    /// @param id the id of the market
    /// @param account the account to derive the collateral balance for
    /// @return collateralAmount the collateral balance of the account
    function deriveCollateralForFullRepayment(Id id, address account) public view returns (uint256 collateralAmount) {
        (,, uint128 collateral) = morphoStaticTyping.position(id, account);
        collateralAmount = uint256(collateral);
    }

    /// @dev derive the collateral amount for partial repayment
    /// @param id the id of the market
    /// @param account the account to derive the collateral amount for
    /// @param amount the amount to repay
    /// @param fullCollateral the full collateral amount
    /// @return withdrawableCollateral the collateral amount for partial repayment
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

        withdrawableCollateral = Math.mulDiv(fullCollateral, amount, fullLoanAmount);
    }

    /// @dev derive the loan amount of the account
    /// @param id the id of the market
    /// @param account the account to derive the loan amount for
    /// @return loanAmount the loan amount of the account
    function deriveLoanAmount(Id id, address account) public view returns (uint256 loanAmount) {
        (, uint128 fullShares,) = morphoStaticTyping.position(id, account);
        uint256 castShares = uint256(fullShares);

        Market memory market = morphoInterface.market(id);
        loanAmount = castShares.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /// @dev derive the assets for a share balance in a market
    /// @param marketParams the market parameters
    /// @param account the account to derive the assets for
    /// @return assets the assets of the account
    function sharesToAssets(MarketParams memory marketParams, address account) public view returns (uint256 assets) {
        Id id = marketParams.id();
        uint256 shareBalance = deriveShareBalance(id, account);
        Market memory market = morphoInterface.market(id);
        assets = shareBalance.toAssetsUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /// @dev derive the shares for an amount of assets in a market
    /// @param marketParams the market parameters
    /// @param assets the assets to derive the shares for
    /// @return shares the shares of the account
    function assetsToShares(MarketParams memory marketParams, uint256 assets) public view returns (uint256 shares) {
        Id id = marketParams.id();
        Market memory market = morphoInterface.market(id);
        shares = assets.toSharesUp(market.totalBorrowAssets, market.totalBorrowShares);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        BuildHookLocalVars memory vars = _decodeHookData(data);
        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);
        morphoInterface.accrueInterest(marketParams);

        // store current balance
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data) - getOutAmount(account), account);
    }
}
