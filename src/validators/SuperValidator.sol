// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import {PackedUserOperation} from "modulekit/external/ERC4337.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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
    /// @notice Magic value returned when a signature is valid according to EIP-1271
    /// @dev The value 0x1626ba7e is specified by the EIP-1271 standard
    bytes4 public constant VALID_SIGNATURE = bytes4(0x1626ba7e);

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
        if (!_initialized[_userOp.sender]) revert NOT_INITIALIZED();

        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);

        // Verify source data
        (address signer,) = _processSignatureAndVerifyLeaf(_userOp.sender, sigData, _userOpHash);

        // Validate
        bool isValid = _isSignatureValid(signer, _userOp.sender, sigData.validUntil);

        // Verify destination data
        if (isValid && sigData.validateDstProof) {
            uint256 dstLen = sigData.proofDst.length;
            if (dstLen == 0) revert INVALID_DESTINATION_PROOF();

            for (uint256 i; i < dstLen; ++i) {
                DstProof memory dstProof = sigData.proofDst[i];
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
                    revert INVALID_DESTINATION_PROOF();
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
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();

        // Decode data
        bytes memory sigDataRaw = abi.decode(data, (bytes));
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);

        // Process signature
        (address signer,) = _processSignatureAndVerifyLeaf(msg.sender, sigData, dataHash);

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
    /// @param checkCrossChainExecution Whether to validate destination proof
    /// @return The calculated leaf hash used in merkle tree verification
    function _createLeaf(
        bytes memory data,
        uint48 validUntil,
        bool checkCrossChainExecution
    )
        internal
        view
        override
        returns (bytes32)
    {
        bytes32 userOpHash = abi.decode(data, (bytes32));
        return keccak256(
            bytes.concat(keccak256(abi.encode(userOpHash, validUntil, checkCrossChainExecution, address(this))))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Processes a signature and verifies it against a merkle proof
    /// @dev Verifies the user operation hash is part of the merkle tree and recovers the signer
    ///      Uses the source proof (proofSrc) for verification
    /// @param sender The sender address to validate the signature against
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @param userOpHash The hash of the user operation being verified
    /// @return signer The address that signed the message
    /// @return leaf The computed leaf hash used in merkle verification
    function _processSignatureAndVerifyLeaf(
        address sender,
        SignatureData memory sigData,
        bytes32 userOpHash
    )
        private
        view
        returns (address signer, bytes32 leaf)
    {
        // Create leaf from user operation hash and verify it's part of the merkle tree
        leaf = _createLeaf(abi.encode(userOpHash), sigData.validUntil, sigData.validateDstProof);
        if (!MerkleProof.verify(sigData.proofSrc, sigData.merkleRoot, leaf)) revert INVALID_PROOF();

        address owner = _accountOwners[sender];

        if (_isSafeSigner(owner)) {
           signer = _processEIP1271Signature(owner, sigData);
        } else {
           signer = _processECDSASignature(sigData);
        }
    }


}
