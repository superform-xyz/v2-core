// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { SuperValidatorBase } from "./SuperValidatorBase.sol";

/// @title SuperDestinationValidator
/// @dev Can't be used for ERC-1271 validation
/// @author Superform Labs
/// @notice A destination validator contract
contract SuperDestinationValidator is SuperValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct DestinationData {
        bytes callData;
        uint64 chainId;
        address sender;
        address executor;
        uint256 intentAmount;
    }

    bytes4 constant VALID_SIGNATURE = bytes4(0x1626ba7e);

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
        return isValid ? VALID_SIGNATURE : bytes4("");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        DestinationData memory destinationData = abi.decode(data, (DestinationData));
        /// @dev `executor` is included in the leaf to ensure that the leaf is unique for each executor
        ///      otherwise it allows the owner's signature to be replayed if the account mistakenly installs two of the
        /// same executors
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
        /// @dev block.timestamp could vary between chains
        return signer == _accountOwners[sender] && validUntil >= block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _processSignatureAndVerifyLeaf(
        SignatureData memory sigData,
        DestinationData memory destinationData
    )
        private
        pure
        returns (address signer, bytes32 leaf)
    {
        // Verify leaf and root are valid
        leaf = _createLeaf(abi.encode(destinationData), sigData.validUntil);
        if (!MerkleProof.verify(sigData.proofDst, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Get signer
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

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
        if (chainId != block.chainid) revert INVALID_CHAIN_ID();
        return DestinationData(callData, chainId, decodedSender, executor, intentAmount);
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
