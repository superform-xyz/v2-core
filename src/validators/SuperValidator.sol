// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { SuperValidatorBase } from "./SuperValidatorBase.sol";
import { ISuperSignatureStorage } from "../interfaces/ISuperSignatureStorage.sol";
import { SignatureTransientStorage } from "../libraries/SignatureTransientStorage.sol";

/// @title SuperValidator
/// @author Superform Labs
/// @notice Validates user operations using merkle proofs for smart account signatures
/// @dev Implements EIP-1271 and ERC-4337 signature validation mechanisms
///      Uses transient storage for signature data management
contract SuperValidator is SuperValidatorBase, ISuperSignatureStorage {
    using SignatureTransientStorage for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperSignatureStorage
    function retrieveSignatureData(address account) external view returns (bytes memory) {
        uint256 identifier = uint256(uint160(account));
        return identifier.loadSignature();
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validate a user operation
    /// @param _userOp The user operation to validate
    function validateUserOp(
        PackedUserOperation calldata _userOp,
        bytes32 _userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        if (!_is7702Account(_userOp.sender.code) && !_initialized[_userOp.sender]) {
            revert NOT_INITIALIZED();
        }

        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);

        // Verify source data
        (address signer,) = _createLeafAndVerifyProofAndSignature(_userOp.sender, sigData, _userOpHash);

        // Validate
        bool isValid = _isSignatureValid(signer, _userOp.sender, sigData.validUntil);

        // Verify destination data
        if (isValid && sigData.chainsWithDestinationExecution.length > 0) {
            uint256 dstLen = sigData.proofDst.length;
            uint256 expectedChainsLen = sigData.chainsWithDestinationExecution.length;
            if (dstLen == 0) revert EMPTY_DESTINATION_PROOF();
            // Exact 1:1 mapping required - chainsWithDestinationExecution can contain duplicates
            if (dstLen != expectedChainsLen) revert PROOF_COUNT_MISMATCH();

            // Validate all proofs with 1:1 correspondence to expected chains
            for (uint256 i; i < dstLen; ++i) {
                DstProof memory dstProof = sigData.proofDst[i];

                // Check for duplicate proofs by comparing with previous proofs
                for (uint256 k; k < i; ++k) {
                    if (_areProofsEqual(dstProof, sigData.proofDst[k])) {
                        revert DUPLICATE_CHAIN_PROOF();
                    }
                }

                // Verify proof is for the expected chain at this index
                if (dstProof.dstChainId != sigData.chainsWithDestinationExecution[i]) {
                    revert UNEXPECTED_CHAIN_PROOF();
                }

                DestinationData memory dstData = DestinationData({
                    callData: dstProof.info.data,
                    chainId: dstProof.dstChainId,
                    sender: dstProof.info.account,
                    executor: dstProof.info.executor,
                    dstTokens: dstProof.info.dstTokens,
                    intentAmounts: dstProof.info.intentAmounts
                });

                bytes32 dstLeaf = _createDestinationLeaf(dstData, sigData.validUntil, dstProof.info.validator);

                if (!MerkleProof.verify(dstProof.proof, sigData.merkleRoot, dstLeaf)) {
                    revert INVALID_MERKLE_PROOF();
                }
            }

            // store signature in transient storage to be retrieved during bridge execution
            uint256 identifier = uint256(uint160(_userOp.sender));
            identifier.storeSignature(_userOp.signature);
        }

        return _packValidationData(!isValid, sigData.validUntil, 0);
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(
        address,
        bytes32 dataHash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        if (!_is7702Account(msg.sender.code) && !_initialized[msg.sender]) {
            revert NOT_INITIALIZED();
        }

        // Decode data
        bytes memory sigDataRaw = abi.decode(data, (bytes));
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);

        // Process signature
        (address signer,) = _createLeafAndVerifyProofAndSignature(msg.sender, sigData, dataHash);

        // Validate
        bool isValid = _isSignatureValid(signer, msg.sender, sigData.validUntil);

        return isValid ? EIP1271_MAGIC_VALUE : bytes4("");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a unique leaf hash for merkle tree verification
    /// @dev Overrides the base implementation to handle user operation hash data
    ///      Double-hashing is used for added security
    /// @param data Encoded data containing the user operation hash
    /// @param validUntil Timestamp after which the signature becomes invalid
    /// @param chainsWithDestinationExecution Which chains have destination execution
    /// @return The calculated leaf hash used in merkle tree verification
    function _createLeaf(
        bytes memory data,
        uint48 validUntil,
        uint64[] memory chainsWithDestinationExecution
    )
        internal
        view
        returns (bytes32)
    {
        bytes32 userOpHash = abi.decode(data, (bytes32));
        return keccak256(
            bytes.concat(keccak256(abi.encode(userOpHash, validUntil, chainsWithDestinationExecution, address(this))))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates leaf and verifies source proof and signature
    /// @dev Verifies the user operation hash is part of the merkle tree using source proof
    ///      and processes signature for any account type (EOA, EIP-1271, EIP-7702)
    /// @param sender The sender address to validate the signature against
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @param userOpHash The hash of the user operation being verified
    /// @return signer The address that signed the message
    /// @return leaf The computed leaf hash used in merkle verification
    function _createLeafAndVerifyProofAndSignature(
        address sender,
        SignatureData memory sigData,
        bytes32 userOpHash
    )
        private
        view
        returns (address signer, bytes32 leaf)
    {
        // Create leaf from user operation hash and verify it's part of the merkle tree using source proof
        leaf = _createLeaf(abi.encode(userOpHash), sigData.validUntil, sigData.chainsWithDestinationExecution);
        if (!MerkleProof.verify(sigData.proofSrc, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Process signature using common method
        signer = _processSignatureForAccountType(sender, sigData);
    }

    /// @notice Compares two DstProof structs for equality using hash comparison
    /// @dev Gas-efficient comparison using keccak256 hash of encoded struct data
    /// @param proof1 First proof to compare
    /// @param proof2 Second proof to compare
    /// @return true if proofs are identical, false otherwise
    function _areProofsEqual(DstProof memory proof1, DstProof memory proof2) private pure returns (bool) {
        return _hashDstProof(proof1) == _hashDstProof(proof2);
    }

    /// @notice Computes a hash of a DstProof struct
    /// @dev Uses abi.encode to avoid hash collisions with dynamic arrays
    /// @param proof The proof to hash
    /// @return The keccak256 hash of the encoded proof
    function _hashDstProof(DstProof memory proof) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                proof.dstChainId,
                proof.proof,
                proof.info.account,
                proof.info.executor,
                proof.info.dstTokens,
                proof.info.intentAmounts,
                proof.info.validator,
                proof.info.data
            )
        );
    }
}
