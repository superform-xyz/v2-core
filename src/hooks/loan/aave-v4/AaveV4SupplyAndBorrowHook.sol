// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IAaveV4Spoke } from "../../../vendor/aave-v4/IAaveV4Spoke.sol";

// Superform
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV4LoanHook } from "./BaseAaveV4LoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title AaveV4SupplyAndBorrowHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address loanToken = BytesLib.toAddress(data, 0);
/// @notice         address collateralToken = BytesLib.toAddress(data, 20);
/// @notice         address spoke = BytesLib.toAddress(data, 40);
/// @notice         uint256 supplyReserveId = BytesLib.toUint256(data, 60);
/// @notice         uint256 borrowReserveId = BytesLib.toUint256(data, 92);
/// @notice         uint256 amount = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 157);
/// @dev outAmount tracks collateral tokens consumed (pre-balance - post-balance).
///      NOTE: This is NOT the borrowed loanToken amount. Downstream hooks using usePrevHookAmount
///      will receive the collateral amount spent, not the loan amount received.
/// @dev Unlike Morpho's MorphoSupplyAndBorrowHook which derives borrow amount on-chain via oracle,
///      the borrow amount is computed off-chain by the bundler and passed in calldata. Aave V4's
///      risk pricing (User Risk Premium, e-Mode) makes on-chain derivation impractical.
contract AaveV4SupplyAndBorrowHook is BaseAaveV4LoanHook {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() BaseAaveV4LoanHook(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V4 Supply and Borrow";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies and borrows assets from an Aave V4 lending pool";
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
        SupplyAndBorrowHookLocalVars memory vars = _decodeSupplyAndBorrowHookData(data);

        if (vars.usePrevHookAmount) {
            vars.amount = ISuperHookResult(prevHook).getOutAmount(account);
        }

        if (vars.amount == 0) revert AMOUNT_NOT_VALID();
        if (vars.borrowAmount == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](6);
        executions[0] = Execution({
            target: vars.collateralToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.spoke, vars.amount))
        });
        executions[2] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.supply, (vars.supplyReserveId, vars.amount, account))
        });
        // Aave V4 does NOT auto-enable collateral on supply — explicit enablement required.
        // NOTE: Calling when already enabled is a no-op (Spoke checks bitmap and returns early),
        // so no conditional check is needed — it would cost the same gas for the SLOAD.
        executions[3] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.setUsingAsCollateral, (vars.supplyReserveId, true, account))
        });
        executions[4] = Execution({
            target: vars.spoke,
            value: 0,
            callData: abi.encodeCall(IAaveV4Spoke.borrow, (vars.borrowReserveId, vars.borrowAmount, account))
        });
        // P1-1: Reset approval after supply to prevent dangling allowance
        executions[5] = Execution({
            target: vars.collateralToken,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (vars.spoke, 0))
        });
    }

    /// @inheritdoc BaseAaveV4LoanHook
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](2);
        amounts[0] = BytesLib.toUint256(data, AAVE_V4_AMOUNT_OFFSET);
        amounts[1] = BytesLib.toUint256(data, BORROW_AMOUNT_OFFSET);
    }

    /// @inheritdoc BaseAaveV4LoanHook
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
        data = _replaceCalldataAmount(data, amounts[0], AAVE_V4_AMOUNT_OFFSET);
        return _replaceCalldataAmount(data, amounts[1], BORROW_AMOUNT_OFFSET);
    }

    /// @inheritdoc BaseAaveV4LoanHook
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        meta = new ISuperHookInflowOutflow.AmountMeta[](2);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
        meta[1] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.OUT, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        SupplyAndBorrowHookLocalVars memory vars = _decodeSupplyAndBorrowHookData(data);
        return abi.encodePacked(vars.spoke);
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
        _setOutToken(getCollateralTokenAddress(data), account);
    }
}
