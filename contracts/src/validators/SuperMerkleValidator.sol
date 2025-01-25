// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// Superform
import { SuperRegistryImplementer } from "../utils/SuperRegistryImplementer.sol";

contract SuperMerkleValidator is SuperRegistryImplementer, ERC7579ValidatorBase 
{
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct SignatureData {
        uint48 validUntil;
        bytes32 merkleRoot;
        bytes32[] proof;
        bytes signature;
    }

    struct UserOpData {
        address sender;
        uint256 nonce;
        bytes callData;
        bytes32 accountGasLimits;
    }

    constructor(address registry_) SuperRegistryImplementer(registry_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function isInitialized(address) external pure returns (bool) {
        return true;
    }

    function namespace() public pure returns (string memory) {
        return "MerkleUserOpValidator-v0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata) external pure { }
    function onUninstall(bytes calldata) external pure { }

    /// @notice Validate a user operation
    /// @param _userOp The user operation to validate
    function validateUserOp(
        PackedUserOperation calldata _userOp,
        bytes32 // _userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        // Decode signature
        SignatureData memory sigData = _decodeSignatureData(_userOp.signature);
        UserOpData memory userOpData = UserOpData({
            sender: _userOp.sender,
            nonce: _userOp.nonce,
            callData: _userOp.callData,
            accountGasLimits: _userOp.accountGasLimits
        });

        // Process signature
        (address signer, bytes32 leaf) = _processSignature(sigData, userOpData);

        // Validate
        bool isValid =
            _isSignatureValid(signer, userOpData.sender, sigData.validUntil, sigData.merkleRoot, leaf, sigData.proof);
        return _packValidationData(!isValid, sigData.validUntil, 0);
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(
        address sender,
        bytes32, // hash
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        // Decode data
        (SignatureData memory sigData, UserOpData memory userOpData) = _decodeSignatureAndUserOpData(data, sender);

        // Process signature
        (address signer, bytes32 leaf) = _processSignature(sigData, userOpData);

        // Validate
        bool isValid = _isSignatureValid(signer, sender, sigData.validUntil, sigData.merkleRoot, leaf, sigData.proof);

        return isValid ? bytes4(0x1626ba7e) : bytes4("");
    }

    /// @notice Validate a signature with data
    function validateSignatureWithData(
        bytes32,
        bytes calldata sigDataRaw,
        bytes calldata userOpDataRaw
    )
        external
        view
        virtual
        returns (bool validSig)
    {
        // Decode signature and user operation data
        SignatureData memory sigData = _decodeSignatureData(sigDataRaw);
        UserOpData memory userOpData = _decodeUserOpData(userOpDataRaw, msg.sender);

        // Process signature
        (address signer, bytes32 leaf) = _processSignature(sigData, userOpData);

        return _isSignatureValid(signer, msg.sender, sigData.validUntil, sigData.merkleRoot, leaf, sigData.proof);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    function _processSignature(
        SignatureData memory sigData,
        UserOpData memory userOpData
    )
        private
        pure
        returns (address signer, bytes32 leaf)
    {
        // Create leaf
        leaf = _createLeaf(userOpData);

        // Create message hash
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot, leaf, userOpData.sender, userOpData.nonce);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

    function _decodeSignatureData(bytes memory sigDataRaw) private pure returns (SignatureData memory) {
        (uint48 validUntil, bytes32 merkleRoot, bytes32[] memory proof, bytes memory signature) =
            abi.decode(sigDataRaw, (uint48, bytes32, bytes32[], bytes));
        return SignatureData(validUntil, merkleRoot, proof, signature);
    }

    function _decodeUserOpData(bytes memory userOpDataRaw, address sender) private pure returns (UserOpData memory) {
        (uint256 nonce, bytes memory callData, bytes32 accountGasLimits) =
            abi.decode(userOpDataRaw, (uint256, bytes, bytes32));
        return UserOpData(sender, nonce, callData, accountGasLimits);
    }

    function _decodeSignatureAndUserOpData(bytes memory data, address sender)
        private
        pure
        returns (SignatureData memory, UserOpData memory)
    {
        (bytes memory sigDataRaw, bytes memory userOpDataRaw) = abi.decode(data, (bytes, bytes));
        return (_decodeSignatureData(sigDataRaw), _decodeUserOpData(userOpDataRaw, sender));
    }

    function _createLeaf(UserOpData memory userOpData) private pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(userOpData.sender, userOpData.nonce, userOpData.callData, userOpData.accountGasLimits)
        );
    }

    function _createMessageHash(
        bytes32 merkleRoot,
        bytes32 leaf,
        address sender,
        uint256 nonce
    )
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(namespace(), merkleRoot, leaf, sender, nonce));
    }

    function _isSignatureValid(
        address signer,
        address sender,
        uint48 validUntil,
        bytes32 merkleRoot,
        bytes32 leaf,
        bytes32[] memory proof
    )
        private
        view
        returns (bool)
    {
        // Verify merkle proof
        bool isValid = MerkleProof.verify(proof, merkleRoot, leaf);
        return isValid && signer == sender && validUntil >= block.timestamp;
    }
}
