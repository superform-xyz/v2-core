// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IMorphoBase, MarketParams } from "../../../vendor/morpho/IMorpho.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseMorphoLoanHookV2 } from "./BaseMorphoLoanHookV2.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../interfaces/ISuperHook.sol";

/// @title MorphoSupplyAndBorrowHookV2
/// @author Superform Labs
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address loanToken = BytesLib.toAddress(data, 52);
/// @notice         address collateralToken = BytesLib.toAddress(data, 72);
/// @notice         address oracle = BytesLib.toAddress(data, 92);
/// @notice         address irm = BytesLib.toAddress(data, 112);
/// @notice         uint256 collateralAmount = BytesLib.toUint256(data, 132);
/// @notice         uint256 borrowAmount = BytesLib.toUint256(data, 164);
/// @notice         bool usePrevHookAmount = _decodeStrictBool(data, 196);
/// @notice         uint256 lltv = BytesLib.toUint256(data, 197);
/// @notice         byte reserved = data[229]; // must be 0x00
/// @dev Both legs are exact: collateralAmount is supplied and borrowAmount is borrowed with no
///      ratio/oracle derivation inside the hook. usePrevHookAmount applies to the collateral leg
///      only and requires the previous hook's output token to equal the collateral token.
///      outAmount publishes the actual borrowed loan-token wallet delta with outToken = loanToken,
///      so downstream usePrevHookAmount consumers receive the token this hook actually produced.
contract MorphoSupplyAndBorrowHookV2 is BaseMorphoLoanHookV2 {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton
    constructor(address morpho_) BaseMorphoLoanHookV2(morpho_, HookSubTypes.LOAN) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Morpho Supply and Borrow V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Supplies an exact collateral amount and borrows an exact asset amount from a Morpho market";
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
        MorphoV2Vars memory vars = _decodeMorphoV2(data, false);
        vars.amount1 = _resolveOpenAmount1(
            prevHook, account, vars.collateralToken, vars.amount1, vars.amount2, vars.usePrevHookAmount
        );

        MarketParams memory marketParams = _marketParams(vars);

        executions = new Execution[](5);
        executions[0] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });
        executions[1] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, vars.amount1))
        });
        executions[2] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.supplyCollateral, (marketParams, vars.amount1, account, ""))
        });
        executions[3] = Execution({
            target: morpho,
            value: 0,
            callData: abi.encodeCall(IMorphoBase.borrow, (marketParams, vars.amount2, 0, account, account))
        });
        // Reset approval after supply to prevent dangling allowance
        executions[4] = Execution({
            target: vars.collateralToken, value: 0, callData: abi.encodeCall(IERC20.approve, (morpho, 0))
        });
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        return _decodeTwoAmounts(data, AMOUNT_POSITION, AMOUNT2_OFFSET);
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
        return _replaceTwoAmounts(data, amounts, AMOUNT_POSITION, AMOUNT2_OFFSET);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        return _inspectMorphoV2(_decodeMorphoV2(data, false));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        MorphoV2Vars memory vars = _decodeMorphoV2(data, false);
        vars.amount1 = _resolveOpenAmount1(
            prevHook, account, vars.collateralToken, vars.amount1, vars.amount2, vars.usePrevHookAmount
        );

        expectedPrimaryAmount = vars.amount1;
        expectedSecondaryAmount = vars.amount2;
        _snapshotBalances(account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        _settleOpen(account, data);
    }
}
