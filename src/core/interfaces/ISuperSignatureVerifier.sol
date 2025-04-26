// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title ISuperSignatureVerifier
/// @author Superform Labs
/// @notice Interface for signature verification systems
interface ISuperSignatureVerifier {
    /// @notice Verifies a signature against a message and signer
    /// @param signer The expected signer address
    /// @param message The message that was signed
    /// @param signature The signature to verify
    /// @return isValid True if the signature is valid
    function verifySignature(
        address signer,
        bytes32 message,
        bytes calldata signature
    ) external view returns (bool isValid);
    
    /// @notice Recovers the signer from a signature
    /// @param message The message that was signed
    /// @param signature The signature to recover from
    /// @return signer The recovered signer address
    function recoverSigner(
        bytes32 message,
        bytes calldata signature
    ) external view returns (address signer);
    
    /// @notice Returns the unique identifier for this signature scheme
    /// @return signatureTypeId The signature scheme identifier
    function signatureTypeId() external pure returns (bytes32);
}