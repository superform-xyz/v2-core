// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title ISuperBank
/// @author SuperForm Labs
/// @notice Interface for SuperBank, which compounds protocol revenue into sUP by executing registered hooks.
interface ISuperBank {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_LENGTH_ARRAY();
    error INVALID_ARRAY_LENGTH();
    error INVALID_ADDRESS();
    error INVALID_MERKLE_PROOF();
    error HOOK_EXECUTION_FAILED();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when hooks are executed.
    /// @param hooks The addresses of the hooks that were executed.
    /// @param data The data passed to each hook.
    event HooksExecuted(address[] hooks, bytes[] data);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Data required for executing hooks with Merkle proof verification.
    /// @param hooks Array of addresses of hooks to execute.
    /// @param data Array of arbitrary data to pass to each hook.
    /// @param merkleProofs Double array of Merkle proofs verifying each hook's allowed targets.
    struct HookExecutionData {
        address[] hooks;
        bytes[] data;
        bytes32[][] merkleProofs;
    }

    /*//////////////////////////////////////////////////////////////
                              FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Executes a batch of hooks, verifying each with a Merkle proof.
    /// @dev Each hook is verified against a Merkle root from SuperGovernor.
    /// @dev Hooks must implement the ISuperHook interface (preExecute, build, postExecute).
    /// @param executionData HookExecutionData struct containing arrays of hooks, data, and Merkle proofs.
    function executeHooks(HookExecutionData calldata executionData) external;
}
