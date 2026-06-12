// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { ISuperHookInflowOutflow, ISuperHookOutflow } from "../../interfaces/ISuperHook.sol";

/// @title NativeTransferHook
/// @author Superform Labs
/// @notice Simple hook for transferring native ETH to a specified recipient
/// @dev Data structure: address to (20 bytes) + uint256 amount (32 bytes) = 52 bytes total
///      This hook is NONACCOUNTING and only used for ETH → token swaps where
///      native ETH needs to be transferred to the next hook in the chain
contract NativeTransferHook is BaseHook, ISuperHookInflowOutflow, ISuperHookOutflow {
    uint256 private constant AMOUNT_POSITION = 20;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.TOKEN) { }

    /*//////////////////////////////////////////////////////////////
                                VIEW METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address, // prevHook
        address, // account  
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        // Decode: first 20 bytes = recipient address, next 32 bytes = amount
        address to = BytesLib.toAddress(data, 0);
        uint256 amount = BytesLib.toUint256(data, 20);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: to,
            value: amount,
            callData: ""
        });
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
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
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }
}