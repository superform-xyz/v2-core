// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540 } from "../../../../vendor/vaults/7540/IERC7540.sol";

// Superform
import {
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookAsync,
    ISuperHookContextAware,
    ISuperHookAsyncCancelations
} from "../../../interfaces/ISuperHook.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title ApproveAndRequestDeposit7540VaultHook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         bytes4 placeholder = bytes4(BytesLib.slice(data, 0, 4), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 4);
/// @notice         address token = BytesLib.toAddress(data, 24);
/// @notice         uint256 amount = BytesLib.toUint256(data, 44);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 76);
contract ApproveAndRequestDeposit7540VaultHook is
    BaseHook,
    ISuperHookInflowOutflow,
    ISuperHookAsync,
    ISuperHookAsyncCancelations,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    uint256 private constant AMOUNT_POSITION = 44;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 76;

    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING, HookSubTypes.ERC7540) { }

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
        address token = BytesLib.toAddress(data, 24);
        uint256 amount = _decodeAmount(data);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (yieldSource == address(0) || account == address(0) || token == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](4);
        executions[0] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, amount)) });
        executions[2] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540.requestDeposit, (amount, account, account))
        });
        executions[3] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (yieldSource, 0)) });
    }

    /// @inheritdoc ISuperHookAsync
    function getUsedAssetsOrShares() external view returns (uint256, bool isShares) {
        return (outAmount, false);
    }

    /// @inheritdoc ISuperHookAsyncCancelations
    function isAsyncCancelHook() external pure returns (CancelationType) {
        return CancelationType.NONE;
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

    /*//////////////////////////////////////////////////////////////    
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        outAmount = _getBalance(account, data);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        outAmount = outAmount - _getBalance(account, data);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _decodeAmount(bytes memory data) private pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        return IERC20(IERC7540(data.extractYieldSource()).asset()).balanceOf(account);
    }
}
