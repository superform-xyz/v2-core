// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

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
    /// @notice Structure representing data specific to a destination chain operation
    /// @dev Contains all necessary data to validate and execute a cross-chain operation
    struct DestinationData {
        /// @notice The encoded call data to be executed
        bytes callData;
        /// @notice The destination chain ID where execution should occur
        uint64 chainId;
        /// @notice The account that should execute the operation
        address sender;
        /// @notice The executor contract address that handles the operation
        address executor;
        /// @notice The minimum token amount required for execution
        uint256 intentAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_SENDER();
    error NOT_IMPLEMENTED();
    error INVALID_CHAIN_ID();

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
    /// @dev EIP1271 compatible
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
        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, destinationData);

        // Validate
        bool isValid = _isSignatureValid(signer, sender, sigData.validUntil);
        return isValid ? bytes4(0x1626ba7e) : bytes4("");
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
    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        DestinationData memory destinationData = abi.decode(data, (DestinationData));
        // Note: destinationData.initData is not included because it is not needed for the leaf.
        // If precomputed account is != than the executing account, the entire execution reverts
        // before this method is called. Check SuperDestinationExecutor for more details.
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        destinationData.callData,
                        destinationData.chainId,
                        destinationData.sender,
                        destinationData.executor,
                        destinationData.intentAmount,
                        validUntil
                    )
                )
            )
        );
    }

    /// @notice Validates a signature based on signer identity and expiration time
    /// @dev Overrides the base implementation to check both ownership and expiration
    /// @param signer The address that signed the message (recovered from signature)
    /// @param sender The smart account address that should execute the operation
    /// @param validUntil Timestamp after which the signature becomes invalid
    /// @return True if the signer is the account owner and signature hasn't expired
    function _isSignatureValid(
        address signer,
        address sender,
        uint48 validUntil
    )
        internal
        view
        override
        returns (bool)
    {
        return signer == _accountOwners[sender] && validUntil >= block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Processes a signature and verifies it against a merkle proof
    /// @dev Verifies that the leaf is part of the merkle tree specified by the root
    ///      and recovers the signer's address from the signature
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @param destinationData The destination execution data to create the leaf hash from
    /// @return signer The address that signed the message
    /// @return leaf The computed leaf hash used in merkle verification
    function _processSignatureAndVerifyLeaf(
        SignatureData memory sigData,
        DestinationData memory destinationData
    )
        private
        pure
        returns (address signer, bytes32 leaf)
    {
        // Create leaf from destination data and verify against merkle root using the proof
        leaf = _createLeaf(abi.encode(destinationData), sigData.validUntil);
        if (!MerkleProof.verify(sigData.proofDst, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Recover signer from signature using standard Ethereum signature recovery
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
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
            uint256 intentAmount
        ) = abi.decode(destinationDataRaw, (bytes, uint64, address, address, uint256));
        if (sender_ != decodedSender) revert INVALID_SENDER();
        if (chainId != uint64(block.chainid)) revert INVALID_CHAIN_ID();

        return DestinationData({
            callData: callData,
            chainId: chainId,
            sender: decodedSender,
            executor: executor,
            intentAmount: intentAmount
        });
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
