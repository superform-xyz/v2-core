// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { IHookExecutionData } from "./interfaces/IHookExecutionData.sol";
import { ISuperHook, Execution } from "../core/interfaces/ISuperHook.sol";

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
        address hookAddress;
        bytes memory hookData;
        bytes32[] memory merkleProof;
        ISuperHook hook;
        bytes32 merkleRoot;
        Execution[] memory executions;
        Execution memory executionStep;
        bytes32 targetLeaf;
        bool success;

        for (uint256 i; i < hooksLength; i++) {
            hookAddress = executionData.hooks[i];
            hookData = executionData.data[i];
            merkleProof = executionData.merkleProofs[i];

            hook = ISuperHook(hookAddress);

            // 1. Get the Merkle root specific to this hook
            merkleRoot = _getMerkleRootForHook(hookAddress);

            ISuperHook(hookAddress).setExecutionContext(address(this), "");

            // 2. Build Execution Steps
            executions = hook.build(prevHook, address(this), hookData);

            // 3. Execute Target Calls and verify each target
            for (uint256 j; j < executions.length; ++j) {
                executionStep = executions[j];

                // valid hooks encapsulate execution between a `.preExecute` and ` .postExecute`
                // target for preExecute and postExecute is the hook address
                // keep the original behavior for validating the tree against the actual execution steps
                if (executionStep.target != hookAddress) {
                    // Verify that this target is allowed for this hook using the Merkle proof
                    // The leaf is the hash of the target address
                    targetLeaf = keccak256(bytes.concat(keccak256(abi.encodePacked(executionStep.target))));
                    // Verify this target is allowed using the corresponding Merkle proof
                    if (!MerkleProof.verify(merkleProof, merkleRoot, targetLeaf)) {
                        revert INVALID_MERKLE_PROOF();
                    }
                }

                // Execute the call after verification
                (success,) = executionStep.target.call{ value: executionStep.value }(executionStep.callData);
                if (!success) {
                    revert HOOK_EXECUTION_FAILED();
                }
            }

            // Reset execution state after each hook
            ISuperHook(hookAddress).resetExecutionState(address(this));

            prevHook = hookAddress;
        }

        emit HooksExecuted(executionData.hooks, executionData.data);
    }
}
