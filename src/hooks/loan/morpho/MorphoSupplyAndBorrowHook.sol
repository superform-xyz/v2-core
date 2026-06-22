// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IOracle } from "../../../vendor/morpho/IOracle.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookResult, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoSupplyAndBorrowHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address oracle = BytesLib.toAddress(data, 40);
/// @notice         address irm = BytesLib.toAddress(data, 60);
/// @notice         uint256 amount = BytesLib.toUint256(data, 80);
/// @notice         uint256 ltvRatio = BytesLib.toUint256(data, 112);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 144);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 145);
/// @notice         bool placeholder = _decodeBool(data, 177);
/// @dev outAmount tracks collateral tokens consumed (pre-balance - post-balance).
///      NOTE: This is NOT the borrowed loanToken amount. Downstream hooks using usePrevHookAmount
///      will receive the collateral amount spent, not the loan amount received.
contract MorphoSupplyAndBorrowHook is BaseMorphoLoanHook {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 private constant PRICE_SCALING_FACTOR = 1e36;
    uint256 private constant PERCENTAGE_SCALING_FACTOR = 1e18;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue protocol
    constructor(address morpho_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Supply and Borrow";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies collateral and borrows assets from a Morpho market";
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
        BorrowHookLocalVars memory vars = _decodeBorrowHookData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        uint256 loanAmount = deriveLoanAmount(vars.amount, vars.ltvRatio, vars.lltv, vars.oracle);

        executions = new Execution[](5);
        executions[0] =
            Execution({ target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
        executions[1] = Execution({
            target: vars.collateralToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, vars.amount, account, ""))
        });
        executions[3] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.borrow, (marketParams, loanAmount, 0, account, account))
        });
        // P1-1: Reset approval after supply to prevent dangling allowance
        executions[4] =
            Execution({ target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0)) });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        BorrowHookLocalVars memory vars = _decodeBorrowHookData(data);

        MarketParams memory marketParams =
            _generateMarketParams(vars.loanToken, vars.collateralToken, vars.oracle, vars.irm, vars.lltv);

        return abi.encodePacked(
            marketParams.loanToken, marketParams.collateralToken, marketParams.oracle, marketParams.irm
        );
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice This function returns the loan amount required for a given collateral amount.
    /// @dev It corresponds to the price of 10**(collateral token decimals) assets of collateral token quoted in
    /// 10**(loan token decimals) assets of loan token with `36 + loan token decimals - collateral token decimals`
    /// decimals of precision.
    function deriveLoanAmount(
        uint256 collateralAmount,
        uint256 ltvRatio,
        uint256 lltv,
        address oracle
    )
        public
        view
        returns (uint256 loanAmount)
    {
        IOracle oracleInstance = IOracle(oracle);
        uint256 price = oracleInstance.price();
        if (price == 0) revert ORACLE_PRICE_NOT_VALID();

        if (ltvRatio >= lltv) revert LTV_RATIO_NOT_VALID();

        uint256 fullAmount = Math.mulDiv(collateralAmount, price, PRICE_SCALING_FACTOR);
        loanAmount = Math.mulDiv(fullAmount, ltvRatio, PERCENTAGE_SCALING_FACTOR);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getCollateralTokenBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
        _setOutToken(asset, account);
    }
}
