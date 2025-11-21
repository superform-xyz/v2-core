// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540 } from "../../../vendor/vaults/7540/IERC7540.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";

/// @title SetOperator7540Hook
/// @author Superform Labs
/// @notice Hook for setting operator approval on ERC-7540 vaults
/// @dev Allows users to approve or revoke operators who can act on their behalf for vault operations
/// @dev The following hook does not need a _postExecute or a _preExecute definition
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32));
/// @notice         address vault = BytesLib.toAddress(data, 32);
/// @notice         address operator = BytesLib.toAddress(data, 52);
/// @notice         bool approved = _decodeBool(data, 72);
contract SetOperator7540Hook is BaseHook {
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant VAULT_POSITION = 32;
    uint256 private constant OPERATOR_POSITION = 52;
    uint256 private constant APPROVED_POSITION = 72;

    /*//////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.ERC7540) { }

    /*//////////////////////////////////////////////////////////////
                                VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    /// @dev Creates a single execution calling vault.setOperator(operator, approved)
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
        address vault = BytesLib.toAddress(data, VAULT_POSITION);
        address operator = BytesLib.toAddress(data, OPERATOR_POSITION);
        bool approved = _decodeBool(data, APPROVED_POSITION);

        if (vault == address(0)) revert ADDRESS_NOT_VALID();
        if (operator == address(0)) revert ADDRESS_NOT_VALID();

        // Build single execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: vault,
            value: 0,
            callData: abi.encodeCall(IERC7540.setOperator, (operator, approved))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookInspector
    /// @dev Returns the vault address being operated on
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(BytesLib.toAddress(data, VAULT_POSITION));
    }
}
