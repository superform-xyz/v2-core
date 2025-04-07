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
/// @notice A destination validator contract
contract SuperDestinationValidator is SuperValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct DestinationData {
        uint256 nonce;
        bytes callData;
        uint64 chainId;
        address sender;
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
    function validateUserOp(
        PackedUserOperation calldata,
        bytes32
    )
        external
        pure
        override
        returns (ValidationData)
    {   
        // @dev The following validator shouldn't be used for EntryPoint calls
        revert NOT_IMPLEMENTED();
    }

    /// @notice Validate a signature with sender
    /// @dev EIP1271 compatible
    function isValidSignatureWithSender(
        address sender,
        bytes32,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        // Decode data
        (SignatureData memory sigData, DestinationData memory destinationData) = _decodeSignatureAndDestinationData(data, sender);
        // Process signature
        (address signer, ) = _processSignatureAndVerifyLeaf(sigData, destinationData);

        // Validate
        bool isValid = _isSignatureValid(signer, sender, sigData.validUntil);
        return isValid ? bytes4(0x1626ba7e) : bytes4("");
    }

    /// @notice Validate a signature with data
    function validateSignatureWithData(
        bytes32,
        bytes calldata sigDataRaw,
        bytes calldata destinationDataRaw
    )
        external
        view
        virtual
        returns (bool validSig)
    {
        // Decode signature and user operation data
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);
        DestinationData memory destinationData = _decodeDestinationData(destinationDataRaw, msg.sender);

        // Process signature
        (address signer, ) = _processSignatureAndVerifyLeaf(sigData, destinationData);

        return _isSignatureValid(signer, msg.sender, sigData.validUntil);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure override returns (string memory) {
        return "SuperDestinationValidator-v0.0.1";
    }

    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        DestinationData memory destinationData = abi.decode(data, (DestinationData));

        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        destinationData.callData,
                        destinationData.chainId,
                        destinationData.sender,
                        destinationData.nonce,
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
        if (!MerkleProof.verify(sigData.proof, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Get signer
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

 
    function _decodeDestinationData(bytes memory destinationDataRaw, address sender_) private view returns (DestinationData memory) {
        (uint256 nonce, bytes memory callData, uint64 chainId, address decodedSender) =
            abi.decode(destinationDataRaw, (uint256, bytes, uint64, address));
        if (sender_ != decodedSender) revert INVALID_SENDER();
        if (chainId != block.chainid) revert INVALID_CHAIN_ID();
        return DestinationData(nonce, callData, chainId, decodedSender);
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
