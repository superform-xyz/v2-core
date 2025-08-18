// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../BaseHook.sol";
import { HookSubTypes } from "../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../libraries/HookDataDecoder.sol";
import { ISuperHookInspector } from "../../interfaces/ISuperHook.sol";
import { ISuperDestinationExecutor } from "../../interfaces/ISuperDestinationExecutor.sol";

/// @title MarkRootAsUsedHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address destinationExecutor = BytesLib.toAddress(data, 32);
/// @notice         bytes merkleRootData = BytesLib.slice(data, 52, data.length - 52);
contract MarkRootAsUsedHook is BaseHook {
    using HookDataDecoder for bytes;


    constructor() BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address destinationExecutor = data.extractYieldSource();
        bytes memory merkleRootData = BytesLib.slice(data, 52, data.length - 52);

        bytes32[] memory merkleRoots = abi.decode(merkleRootData, (bytes32[]));
        if (merkleRoots.length == 0) revert AMOUNT_NOT_VALID();

        executions = new Execution[](1);
        executions[0] = Execution({
            target: destinationExecutor,
            value: 0,
            callData: abi.encodeCall(ISuperDestinationExecutor.markRootsAsUsed, (merkleRoots))
        });
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource());
    }
}
