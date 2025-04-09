// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook, ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";

/// @title ApproveERC20Hook
/// @author Superform Labs
/// @notice This hook does not support tokens reverting on 0 approval
/// @dev data has the following structure
/// @notice         address token = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address spender = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
/// @notice         uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 72);
contract ApproveERC20Hook is BaseHook, ISuperHook, ISuperHookContextAware {
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 72;

    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(
        address prevHook,
        address,
        bytes memory data
    )
        external
        view
        override
        returns (Execution[] memory executions)
    {
        address token = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address spender = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        uint256 amount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amount = ISuperHookResult(prevHook).outAmount();
        }

        if (amount == 0) revert AMOUNT_NOT_VALID();
        if (token == address(0) || spender == address(0)) revert ADDRESS_NOT_VALID();

        // @dev no-revert-on-failure tokens are not supported
        executions = new Execution[](2);
        executions[0] = Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, 0)) });
        executions[1] =
            Execution({ target: token, value: 0, callData: abi.encodeCall(IERC20.approve, (spender, amount)) });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory data) external {
        outAmount = BytesLib.toUint256(BytesLib.slice(data, 40, 32), 0);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address prevHook, address account, bytes memory data) external {
        address token = BytesLib.toAddress(data, 0);
        address spender = BytesLib.toAddress(data, 20);
        outAmount = IERC20(token).allowance(account, spender);
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }
}
