// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperStateVerifier
/// @author Superform Labs
/// @notice Interface for verifying state transitions
interface ISuperStateVerifier {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_PROOF();
    error INVALID_STATE_TRANSITION();

    /// @notice Verifies a state transition proof
    /// @param initialState The initial state before execution
    /// @param finalState The final state after execution
    /// @param executionData The data describing the execution
    /// @param proof The proof of valid state transition
    /// @return isValid True if the state transition is valid
    function verifyStateTransition(
        bytes calldata initialState,
        bytes calldata finalState,
        bytes calldata executionData,
        bytes calldata proof
    ) external view returns (bool isValid);
    
    /// @notice Returns the unique identifier for this prover
    /// @return proverTypeId The prover system identifier
    function proverTypeId() external pure returns (bytes32);
}
