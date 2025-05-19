// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {PackedUserOperation} from "modulekit/external/ERC4337.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Superform
import {SuperValidatorBase} from "./SuperValidatorBase.sol";
import {ISuperSignatureStorage} from "../interfaces/ISuperSignatureStorage.sol";

/// @title SuperMerkleValidator
/// @author Superform Labs
/// @notice Validates user operations using merkle proofs for smart account signatures
/// @dev Implements EIP-1271 and ERC-4337 signature validation mechanisms
///      Uses transient storage for signature data management
contract SuperMerkleValidator is SuperValidatorBase, ISuperSignatureStorage {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Magic value returned when a signature is valid according to EIP-1271
    /// @dev The value 0x1626ba7e is specified by the EIP-1271 standard
    bytes4 constant VALID_SIGNATURE = bytes4(0x1626ba7e);

    /// @notice Storage key for transient signature data
    /// @dev Uses the transient storage pattern to store signature data temporarily
    ///      This is more gas efficient than regular storage for temporary data
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
    function validateUserOp(PackedUserOperation calldata _userOp, bytes32 _userOpHash)
        external
        override
        returns (ValidationData)
    {
        if (!_initialized[_userOp.sender]) revert NOT_INITIALIZED();

        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(sigData, _userOpHash);

        // Validate
        bool isValid = _isSignatureValid(signer, _userOp.sender, sigData.validUntil);

        // store only if destination proof exists and sig is valid
        if (isValid && sigData.proofDst.length > 0) {
            // we check only the signature validity here
            //    merkle tree was checked already in `_processSignatureAndVerifyLeaf` and reverts if invalid
            _storeSignature(uint256(uint160(_userOp.sender)), _userOp.signature);
        }

        return _packValidationData(!isValid, sigData.validUntil, 0);
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(address, bytes32 dataHash, bytes calldata data)
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
    /// @notice Creates a unique leaf hash for merkle tree verification
    /// @dev Overrides the base implementation to handle user operation hash data
    ///      Double-hashing is used for added security
    /// @param data Encoded data containing the user operation hash
    /// @param validUntil Timestamp after which the signature becomes invalid
    /// @return The calculated leaf hash used in merkle tree verification
    function _createLeaf(bytes memory data, uint48 validUntil) internal pure override returns (bytes32) {
        bytes32 userOpHash = abi.decode(data, (bytes32));
        return keccak256(bytes.concat(keccak256(abi.encode(userOpHash, validUntil))));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Processes a signature and verifies it against a merkle proof
    /// @dev Verifies the user operation hash is part of the merkle tree and recovers the signer
    ///      Uses the source proof (proofSrc) for verification
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @param userOpHash The hash of the user operation being verified
    /// @return signer The address that signed the message
    /// @return leaf The computed leaf hash used in merkle verification
    function _processSignatureAndVerifyLeaf(SignatureData memory sigData, bytes32 userOpHash)
        private
        pure
        returns (address signer, bytes32 leaf)
    {
        // Create leaf from user operation hash and verify it's part of the merkle tree
        leaf = _createLeaf(abi.encode(userOpHash), sigData.validUntil);
        if (!MerkleProof.verify(sigData.proofSrc, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        // Recover signer from signature using standard Ethereum signature recovery
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

    /// @notice Generates a storage key for transient storage
    /// @dev Combines the base storage key with an identifier (usually account address)
    ///      to create a unique storage location
    /// @param identifier The unique identifier (typically derived from account address)
    /// @return A unique storage key for the transient storage system
    function _makeKey(uint256 identifier) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(SIGNATURE_KEY_STORAGE, identifier));
    }

    /// @notice Stores signature data in transient storage
    /// @dev Uses EVM assembly for efficient transient storage operations
    ///      First stores the length, then each 32-byte chunk of the signature data
    ///      Transient storage (tstore) is used for gas efficiency and temporary data
    /// @param identifier The unique identifier for this signature (derived from account address)
    /// @param data The signature data to store
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
