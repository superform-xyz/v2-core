// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { SuperValidatorBase } from "./SuperValidatorBase.sol";

/// @title SuperDestinationValidator
/// @author Superform Labs
/// @notice Validates cross-chain operation signatures for destination chain operations
/// @dev Handles signature verification and merkle proof validation for cross-chain messages
///      Cannot be used for standard ERC-1271 validation (those methods revert with NOT_IMPLEMENTED)
contract SuperDestinationValidator is SuperValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    bytes4 internal constant VALID_SIGNATURE = bytes4(0x5c2ec0f3);

    bytes4 internal constant MAGIC_VALUE_EIP1271 = bytes4(0x1626ba7e);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validate a user operation
    /// @dev Not implemented
    function validateUserOp(PackedUserOperation calldata, bytes32) external pure override returns (ValidationData) {
        // @dev The following validator shouldn't be used for EntryPoint calls
        revert NOT_IMPLEMENTED();
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
    )
        external
        pure
        virtual
        override
        returns (bytes4)
    {
        revert NOT_IMPLEMENTED();
    }

    function isValidDestinationSignature(address sender, bytes calldata data) external view returns (bytes4) {
        if (!_initialized[sender]) revert NOT_INITIALIZED();

        // Decode data
        (SignatureData memory sigData, DestinationData memory destinationData) =
            _decodeSignatureAndDestinationData(data, sender);

        // Verify leaf
        _verifyLeaf(sigData, destinationData);

        address owner = _accountOwners[sender];

        // Process signature
        bool isValid;
        if (owner.code.length == 0) {
            // Recover signer from signature using standard Ethereum signature recovery
            address signer = _processEOASignature(sigData);

            // Verify signer is valid based on signer and expiration time
            isValid = _isSignatureValid(signer, sender, sigData.validUntil);
        } else {
            isValid = _processContractSignature(owner, sigData);
        }

        // Validate
        return isValid ? VALID_SIGNATURE : bytes4("");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a unique leaf hash for merkle tree verification
    /// @dev Overrides the base implementation to handle destination-specific data
    ///      `executor` is included in the leaf to ensure that the leaf is unique for each executor,
    ///      otherwise it would allow the owner's signature to be replayed if the account mistakenly
    ///      installs two of the same executors
    /// @param data Encoded destination data containing execution details
    /// @param validUntil Timestamp after which the signature becomes invalid
    /// @return The calculated leaf hash used in merkle tree verification
    function _createLeaf(bytes memory data, uint48 validUntil, bool) internal view override returns (bytes32) {
        DestinationData memory destinationData = abi.decode(data, (DestinationData));

        return _createDestinationLeaf(destinationData, validUntil, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Processes a signature and verifies it against a merkle proof
    /// @dev Verifies that the leaf is part of the merkle tree specified by the root
    ///      and recovers the signer's address from the signature
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @param destinationData The destination execution data to create the leaf hash from
    function _verifyLeaf(
        SignatureData memory sigData,
        DestinationData memory destinationData
    )
        private
        view
    {
        // Create leaf from destination data
        bytes32 leaf = _createLeaf(abi.encode(destinationData), sigData.validUntil, false);

        // Verify leaf against merkle root using the proof
        if (!MerkleProof.verify(_extractProof(sigData), sigData.merkleRoot, leaf)) revert INVALID_PROOF();
    }
    
    /// @notice Processes an EOA signature and returns the signer
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @return signer The address that signed the message
    function _processEOASignature(
        SignatureData memory sigData
    ) private pure returns (address signer) {
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

    /// @notice Processes a contract signature and verifies it against the owner
    /// @dev This function is used to process contract signatures
    /// @param owner The owner of the contract
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    function _processContractSignature(
        address owner,
        SignatureData memory sigData
    ) private view returns (bool) {
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        bytes memory sig = sigData.signature;

        bytes4 rv = IERC1271(owner).isValidSignature(ethSignedMessageHash, sig);
        return rv == MAGIC_VALUE_EIP1271;
    }

    /// @notice Extracts the proof for the current chain from the signature data
    /// @dev Iterates over the proofDst array to find a match for the current chain ID
    /// @param sigData Signature data containing proofs for different chains
    /// @return The proof array corresponding to the current chain ID
    /// @dev Reverts with PROOF_NOT_FOUND if no matching proof is found
    function _extractProof(SignatureData memory sigData) private view returns (bytes32[] memory) {
        uint256 len = sigData.proofDst.length;
        for (uint256 i; i < len; ++i) {
            if (sigData.proofDst[i].dstChainId == block.chainid) return sigData.proofDst[i].proof;
        }
        revert PROOF_NOT_FOUND();
    }

    /// @notice Decodes and validates raw destination data
    /// @dev Checks that the sender and chain ID match current execution context
    ///      to prevent replay attacks across accounts or chains
    /// @param destinationDataRaw ABI-encoded destination data bytes
    /// @param sender_ Expected sender address to validate against
    /// @return Structured DestinationData for further processing
    function _decodeDestinationData(
        bytes memory destinationDataRaw,
        address sender_
    )
        private
        view
        returns (DestinationData memory)
    {
        (
            bytes memory callData,
            uint64 chainId,
            address decodedSender,
            address executor,
            address[] memory dstTokens,
            uint256[] memory intentAmounts
        ) = abi.decode(destinationDataRaw, (bytes, uint64, address, address, address[], uint256[]));
        if (sender_ != decodedSender) revert INVALID_SENDER();

        if (chainId != block.chainid) revert INVALID_CHAIN_ID();
        return DestinationData(callData, chainId, decodedSender, executor, dstTokens, intentAmounts);
    }

    function _decodeSignatureAndDestinationData(
        bytes memory data,
        address sender
    )
        private
        view
        returns (SignatureData memory, DestinationData memory)
    {
        (bytes memory sigDataRaw, bytes memory destinationDataRaw) = abi.decode(data, (bytes, bytes));
        return (_decodeSignatureData(sigDataRaw), _decodeDestinationData(destinationDataRaw, sender));
    }
}
