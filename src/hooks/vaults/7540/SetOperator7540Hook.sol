// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540 } from "../../../vendor/vaults/7540/IERC7540.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title SetOperator7540Hook
/// @author Superform Labs
/// @notice Hook for setting operator approval on ERC-7540 vaults
/// @dev Allows users to approve or revoke operators who can act on their behalf for vault operations
/// @dev The following hook does not need a _postExecute or a _preExecute definition
/// @dev data has the following structure
/// @notice         uint256 placeholder0 = BytesLib.toUint256(data, 0);
/// @notice         address vault = BytesLib.toAddress(data, 32);
/// @notice         address operator = BytesLib.toAddress(data, 52);
/// @notice         bool approved = _decodeBool(data, 72);
contract SetOperator7540Hook is BaseHook, ISuperHookInflowOutflow {
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

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Set Operator ERC-7540";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Sets an operator for an ERC-7540 vault";
    }


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

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](0);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](0);
    }

    /// @inheritdoc IERC165
    /// @dev S2: implements ISuperHookInflowOutflow (decode-only) but NOT ISuperHookOutflow
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return false;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    /// @dev Side-effect only hook — forwards previous hook's outAmount + outToken
    function _pipeMode() internal pure override returns (PipeMode) {
        return PipeMode.PASSTHROUGH;
    }
}
