// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperExecutor
/// @author Superform Labs
/// @notice Interface for the SuperExecutor contract that executes hooks
interface ISuperExecutor {
    struct ExecutorEntry {
        address[] hooksAddresses;
        bytes[] hooksData;
        bytes[] stateProofs;       // Optional proofs for state transitions
        bytes[] expectedResults;   // Optional expected results
        bool[] skipOnChainExecution; // Whether to skip actual execution
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NO_HOOKS();
    error INVALID_FEE();
    error NOT_AUTHORIZED();
    error LENGTH_MISMATCH();
    error NOT_INITIALIZED();
    error MANAGER_NOT_SET();
    error ADDRESS_NOT_VALID();
    error ALREADY_INITIALIZED();
    error INSUFFICIENT_BALANCE_FOR_FEE();
    error FEE_NOT_TRANSFERRED();
    error PROOF_REQUIRED();
    error PROOF_VERIFICATION_FAILED();
    error EXPECTED_RESULTS_REQUIRED();
    error VERIFIER_NOT_CONFIGURED();
    error EXECUTION_SKIP_NOT_ALLOWED();
    error PROVER_NOT_CONFIGURED();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event SuperPositionLocked(address indexed account, address indexed spToken, uint256 amount);
    event HookExecutionSkipped(address indexed account, address indexed hook, bool verified);
    event ProofVerified(address indexed account, address indexed hook, bool success);
    event ResultsVerified(address indexed account, address indexed hook, bool success);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Execute a batch of calls
    /// @param data The data to execute
    function execute(bytes memory data) external;
}
