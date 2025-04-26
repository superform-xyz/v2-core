// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/// @title ISuperProofVerifier
/// @author Superform Labs
/// @notice Interface for proof verification systems
interface ISuperProofVerifier {
    /// @notice Verifies a single proof against a commitment
    /// @param commitment The commitment value (e.g., Merkle root, ZK public input)
    /// @param message The message or data being verified
    /// @param proof The verification proof
    /// @return isValid True if the proof is valid
    function verifyProof(
        bytes32 commitment,
        bytes calldata message,
        bytes calldata proof
    ) external view returns (bool isValid);
    
    /// @notice Verifies multiple proofs in a batch
    /// @param commitments Array of commitments
    /// @param messages Array of messages or data being verified
    /// @param proofs Array of verification proofs
    /// @return validProofs Bitmap of valid proofs (1 bit per proof, 1 = valid)
    function batchVerifyProofs(
        bytes32[] calldata commitments,
        bytes[] calldata messages,
        bytes[] calldata proofs
    ) external view returns (uint256 validProofs);
    
    /// @notice Returns the unique identifier for this proof system
    /// @return proofTypeId The proof system identifier
    function proofTypeId() external pure returns (bytes32);
}