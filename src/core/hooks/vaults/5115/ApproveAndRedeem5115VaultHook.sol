// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { IERC4626 } from "openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IStandardizedYield } from "../../../../vendor/pendle/IStandardizedYield.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title ApproveAndRedeem5115VaultHook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         bytes4 yieldSourceOracleId = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         address tokenIn = BytesLib.toAddress(data, 24);
/// @notice         address tokenOut = BytesLib.toAddress(data, 44);
/// @notice         uint256 shares = BytesLib.toUint256(data, 64);
/// @notice         uint256 minTokenOut = BytesLib.toUint256(data, 96);
/// @notice         bool burnFromInternalBalance = _decodeBool(data, 128);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 129);
contract ApproveAndRedeem5115VaultHook is
    BaseHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
{
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 64;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 129;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.ERC5115) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
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
        address yieldSource = data.extractYieldSource();
        address tokenIn = BytesLib.toAddress(data, 24);
        address tokenOut = BytesLib.toAddress(data, 44);
        uint256 shares = BytesLib.toUint256(data, 64);
        uint256 minTokenOut = BytesLib.toUint256(data, 96);
        bool burnFromInternalBalance = _decodeBool(data, 128);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            shares = ISuperHookResult(prevHook).outAmount();
        }

        if (shares == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || tokenIn == address(0) || tokenOut == address(0)) {
            revert ADDRESS_NOT_VALID();
        }

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, shares)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(
                IStandardizedYield.redeem, (account, shares, tokenOut, minTokenOut, burnFromInternalBalance)
            )
        });
        executions[3] =
            Execution({ target: tokenIn, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return _decodeAmount(data);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
        return _replaceCalldataAmount(data, amount, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view returns(address target, address[] memory args) {
        target = data.extractYieldSource();
        args = new address[](2);
        args[0] = tempAcc;
        args[1] = BytesLib.toAddress(data, 24); // tokenOut
    }

    /// @inheritdoc ISuperHookInspector
    function beneficiaryArgs(bytes calldata) external pure returns (uint8[] memory idxs) {
        idxs = new uint8[](1);
        idxs[0] = 0;
    }


    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        asset = BytesLib.toAddress(BytesLib.slice(data, 24, 20), 0);
        outAmount = _getBalance(account, data);
        usedShares = _getSharesBalance(account, data);
        spToken = data.extractYieldSource();
        tempAcc = account;
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data) - outAmount;
        usedShares = usedShares - _getSharesBalance(account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory) private view returns (uint256) {
        return IERC20(asset).balanceOf(account);
    }

    function _getSharesBalance(address account, bytes memory data) private view returns (uint256) {
        address yieldSource = data.extractYieldSource();
        return IStandardizedYield(yieldSource).balanceOf(account);
    }
}
