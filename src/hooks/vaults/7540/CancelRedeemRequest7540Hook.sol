// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC7540CancelRedeem } from "../../../vendor/standards/ERC7540/IERC7540Vault.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title CancelRedeemRequest7540Hook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
contract CancelRedeemRequest7540Hook is BaseHook, ISuperHookInflowOutflow {
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.CANCEL_REDEEM_REQUEST) { }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Cancel Redeem Request ERC-7540";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Cancels a pending redeem request on an ERC-7540 vault";
    }


    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address account,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = data.extractYieldSource();

        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: yieldSource,
            value: 0,
            callData: abi.encodeCall(IERC7540CancelRedeem.cancelRedeemRequest, (0, account))
        });
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
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
