// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

/// @title ISuperDestinationValidator
/// @author Superform Labs
/// @notice Interface for validating cross-chain destination signature data
/// @dev Used to verify that cross-chain execution requests are properly authorized
///      Works with EIP-1271 signature verification standard
interface ISuperDestinationValidator {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the sender account has not been initialized
    error NOT_INITIALIZED();
    
    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates a signature for cross-chain destination execution
    /// @dev Verifies the validity of a signature or merkle proof for cross-chain operations
    ///      Returns the EIP-1271 magic value (0x1626ba7e) if the signature is valid
    /// @param sender The sender account that initiated the cross-chain request
    /// @param data Encoded signature and destination data including calldata, chainId, etc.
    /// @return The EIP-1271 magic value if valid, empty bytes4 if invalid
    function isValidDestinationSignature(address sender, bytes calldata data) external view returns (bytes4);
}
