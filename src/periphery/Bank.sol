// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import {IHookExecutionData} from "./interfaces/IHookExecutionData.sol";
import {ISuperHook, Execution} from "../core/interfaces/ISuperHook.sol";

abstract contract Bank {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_HOOK();
    error INVALID_MERKLE_PROOF();
    error HOOK_EXECUTION_FAILED();
    error ZERO_LENGTH_ARRAY();
    error INVALID_ARRAY_LENGTH();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when hooks are executed.
    /// @param hooks The addresses of the hooks that were executed.
    /// @param data The data passed to each hook.
    event HooksExecuted(address[] hooks, bytes[] data);

    /*//////////////////////////////////////////////////////////////
                                INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getMerkleRootForHook(address hookAddress) internal view virtual returns (bytes32);

    function _executeHooks(IHookExecutionData.HookExecutionData calldata executionData) internal virtual {
        uint256 hooksLength = executionData.hooks.length;
        if (hooksLength == 0) revert ZERO_LENGTH_ARRAY();

        // Validate arrays have matching lengths
        if (hooksLength != executionData.data.length || hooksLength != executionData.merkleProofs.length) {
            revert INVALID_ARRAY_LENGTH();
        }

        address prevHook;

        for (uint256 i; i < hooksLength; i++) {
            address hookAddress = executionData.hooks[i];
            bytes memory hookData = executionData.data[i];
            bytes32[] memory merkleProof = executionData.merkleProofs[i];

            ISuperHook hook = ISuperHook(hookAddress);

            // 1. Get the Merkle root specific to this hook
            bytes32 merkleRoot = _getMerkleRootForHook(hookAddress);

            // 2. Pre-Execute Hook
            hook.preExecute(prevHook, address(this), hookData);

            // 3. Build Execution Steps
            Execution[] memory executions = hook.build(prevHook, address(this), hookData);

            // 4. Execute Target Calls and verify each target
            for (uint256 j; j < executions.length; ++j) {
                Execution memory executionStep = executions[j];

                // Verify that this target is allowed for this hook using the Merkle proof
                // The leaf is the hash of the target address
                bytes32 targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(executionStep.target))));

                // Verify this target is allowed using the corresponding Merkle proof
                if (!MerkleProof.verify(merkleProof, merkleRoot, targetLeaf)) {
                    revert INVALID_MERKLE_PROOF();
                }

                // Execute the call after verification
                (bool success,) = executionStep.target.call{value: executionStep.value}(executionStep.callData);
                if (!success) {
                    revert HOOK_EXECUTION_FAILED();
                }
            }

            // 5. Post-Execute Hook
            hook.postExecute(prevHook, address(this), hookData);

            prevHook = hookAddress;
        }

        emit HooksExecuted(executionData.hooks, executionData.data);
    }
}
