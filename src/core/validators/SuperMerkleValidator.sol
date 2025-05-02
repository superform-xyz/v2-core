// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Superform
import { SuperValidatorBase } from "./SuperValidatorBase.sol";
import { ISuperSignatureStorage } from "../interfaces/ISuperSignatureStorage.sol";

import "forge-std/console2.sol";

/// @title SuperMerkleValidator
/// @author Superform Labs
/// @notice A userOp validator contract
contract SuperMerkleValidator is SuperValidatorBase, ISuperSignatureStorage {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    bytes4 constant VALID_SIGNATURE = bytes4(0x1626ba7e);
    bytes32 internal constant SIGNATURE_KEY_STORAGE = keccak256("transient.signature.bytes.mapping");

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperSignatureStorage
    function retrieveSignatureData(address account) external view returns (bytes memory) {
        return _loadSignature(uint256(uint160(account)));
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
        console2.log("----------------A");
        if (!_initialized[_userOp.sender]) revert NOT_INITIALIZED();

        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, _userOpHash);

        // Validate
        bool isValid = _isSignatureValid(signer, _userOp.sender, sigData.validUntil);
        if (isValid) {
            // we check only the signature validity here
            //    merkle tree was checked already in `_processSignatureAndVerifyLeaf` and reverts if invalid
            _storeSignature(uint256(uint160(_userOp.sender)), _userOp.signature);
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
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();

        // Decode data
        bytes memory sigDataRaw = abi.decode(data, (bytes));
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, dataHash);

        // Validate
        bool isValid = _isSignatureValid(signer, msg.sender, sigData.validUntil);

        return isValid ? VALID_SIGNATURE : bytes4("");
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        bytes32 userOpHash = abi.decode(data, (bytes32));
        return keccak256(bytes.concat(keccak256(abi.encode(userOpHash, validUntil))));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _processSignatureAndVerifyLeaf(
        SignatureData memory sigData,
        bytes32 userOpHash
    )
        private
        pure
        returns (address signer, bytes32 leaf)
    {
        console2.log("----------------_processSignatureAndVerifyLeaf A");

        leaf = _createLeaf(abi.encode(userOpHash), sigData.validUntil);
        console2.log("----------------_processSignatureAndVerifyLeaf B");
        if (!MerkleProof.verify(sigData.proofSrc, sigData.merkleRoot, leaf)) revert INVALID_PROOF();
        console2.log("----------------_processSignatureAndVerifyLeaf C");

        // Get signer
        console2.log("----------------_processSignatureAndVerifyLeaf D");
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        console2.log("----------------_processSignatureAndVerifyLeaf E");
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        console2.log("----------------_processSignatureAndVerifyLeaf F");
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
        console2.log("----------------_processSignatureAndVerifyLeaf G", signer);
    }

    function _makeKey(uint256 identifier) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(SIGNATURE_KEY_STORAGE, identifier));
    }

    function _storeSignature(uint256 identifier, bytes calldata data) private {
        bytes32 storageKey = _makeKey(identifier);
        uint256 len = data.length;

        assembly {
            tstore(storageKey, len)
        }

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := calldataload(add(data.offset, i))
                tstore(add(storageKey, div(add(i, 32), 32)), word)
            }
        }
    }

    function _loadSignature(uint256 identifier) private view returns (bytes memory out) {
        bytes32 storageKey = _makeKey(identifier);
        uint256 len;
        assembly {
            len := tload(storageKey)
        }

        out = new bytes(len);

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := tload(add(storageKey, div(add(i, 32), 32)))
            }

            assembly {
                mstore(add(add(out, 0x20), i), word)
            }
        }
    }
}
