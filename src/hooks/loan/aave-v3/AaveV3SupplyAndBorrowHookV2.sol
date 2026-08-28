// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IPool } from "../../../vendor/aave-v3/IPool.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseAaveV3LoanHookV2 } from "./BaseAaveV3LoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title AaveV3SupplyAndBorrowHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address pool = BytesLib.toAddress(data, 92);
/// @notice         uint8   interestRateMode = BytesLib.toUint8(data, 112); // must == 2
/// @notice         uint256 collateralAmount = BytesLib.toUint256(data, 113);
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 145);
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 177);
/// @dev Both legs are exact. usePrevHookAmount applies to the collateral leg only and requires the
///      previous hook's output token to equal the collateral token. outAmount publishes the actual
///      borrowed loan-token wallet delta with outToken = loanToken, so downstream
///      usePrevHookAmount consumers receive the token this hook actually produced.
contract AaveV3SupplyAndBorrowHookV2 is BaseAaveV3LoanHookV2 {
    constructor() BaseAaveV3LoanHookV2(HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Aave V3 Supply and Borrow V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies an exact collateral amount and borrows an exact asset amount from an Aave V3 pool";
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
        AaveV3V2Vars memory vars = _decodeAaveV3V2(data, false);
        _resolveOpenAmounts(prevHook, account, vars);

        executions = new Execution[](5);
        executions[0] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, vars.amount1))
        });
        executions[2] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.supply, (vars.collateralToken, vars.amount1, account, 0))
        });
        executions[3] = Execution({
            target: vars.pool,
            value: 0,
            callData: abi.encodeCall(IPool.borrow, (vars.loanToken, vars.amount2, VARIABLE_RATE_MODE, 0, account))
        });
        // Reset approval after supply to prevent dangling allowance
        executions[4] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (vars.pool, 0))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory)
        external
        pure
        override
        returns (ISuperHookInflowOutflow.AmountMeta[] memory meta)
    {
        return _twoTokenRoles();
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
        return _replaceTwoAmounts(data, amounts, AMOUNT1_OFFSET, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return _inspectAaveV3V2(_decodeAaveV3V2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Resolves both open legs; reverts before any provider call on zero/sentinel amounts or
    ///      an invalid previous-hook output (wrong token, zero hook, zero amount)
    function _resolveOpenAmounts(address prevHook, address account, AaveV3V2Vars memory vars) internal view {
        if (vars.amount2 == 0 || vars.amount2 == type(uint256).max) revert AMOUNT_NOT_VALID();
        if (vars.usePrevHookAmount) {
            vars.amount1 = _resolvePrevHookOutput(prevHook, account, vars.collateralToken);
        }
        if (vars.amount1 == 0 || vars.amount1 == type(uint256).max) revert AMOUNT_NOT_VALID();
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        AaveV3V2Vars memory vars = _decodeAaveV3V2(data, false);
        _resolveOpenAmounts(prevHook, account, vars);

        expectedPrimaryAmount = vars.amount1;
        expectedSecondaryAmount = vars.amount2;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleOpen(account, data);
    }
}
