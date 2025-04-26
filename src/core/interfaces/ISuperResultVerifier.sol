// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title ISuperResultVerifier
/// @author Superform Labs
/// @notice Interface for verifying execution results
interface ISuperResultVerifier {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RESULTS_MISMATCH();
    error INVALID_RESULT_FORMAT();

    /// @notice Verifies that execution results match expected outcomes
    /// @param account The account that executed the operation
    /// @param hook The hook that was executed
    /// @param expectedResult The expected result data
    /// @param actualResult The actual result data from execution
    /// @return isValid True if the results match within acceptable bounds
    function verifyResults(
        address account,
        address hook,
        bytes calldata expectedResult,
        bytes calldata actualResult
    ) external view returns (bool isValid);
    
    /// @notice Returns the unique identifier for this verifier
    /// @return verifierTypeId The verifier system identifier
    function verifierTypeId() external pure returns (bytes32);
}
