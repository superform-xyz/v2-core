// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../../vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import {BaseHook} from "../../BaseHook.sol";
import {HookSubTypes} from "../../../libraries/HookSubTypes.sol";
import {ISuperHookResult, ISuperHookContextAware, ISuperHookInspector} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveERC20Hook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         address token = BytesLib.toAddress(data, 0);
/// @notice         address spender = BytesLib.toAddress(data, 20);
/// @notice         uint256 amount = BytesLib.toUint256(data, 40);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);
contract ApproveERC20Hook is BaseHook, ISuperHookContextAware, ISuperHookInspector {
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 72;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) {}

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(address prevHook, address, bytes calldata data)
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        address token = BytesLib.toAddress(data, 0);
        address spender = BytesLib.toAddress(data, 20);
        uint256 amount = BytesLib.toUint256(data, 40);

        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (token == address(0) || spender == address(0)) revert ADDRESS_NOT_VALID();

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](2);
        executions[0] = Execution({target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, 0))});
        executions[1] =
            Execution({target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, amount))});
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure returns (bytes memory) {
        return abi.encodePacked(
            BytesLib.toAddress(data, 0), //token
            BytesLib.toAddress(data, 20) //spender
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        outAmount = BytesLib.toUint256(data, 40);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        address token = BytesLib.toAddress(data, 0);
        address spender = BytesLib.toAddress(data, 20);
        outAmount = IERC20(token).allowance(account, spender);
    }
}
