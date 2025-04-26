// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";

// interfaces
import { ISuperProofVerifier } from "../interfaces/ISuperProofVerifier.sol";
import { ISuperSignatureVerifier } from "../interfaces/ISuperSignatureVerifier.sol";

/// @title SuperValidatorBase
/// @author Superform Labs
/// @notice A base contract for all Superform validators with abstracted proof verification
abstract contract SuperValidatorBase is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct ProofData {
        uint48 validUntil;
        bytes32 commitment;
        bytes proof;
        bytes signature;
    }

    mapping(address => bool) internal _initialized;
    mapping(address => address) internal _accountOwners;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_PROOF();
    error NOT_INITIALIZED();
    error ALREADY_INITIALIZED();
    error ARRAY_LENGTH_MISMATCH();
    error VERIFIER_REQUIRED();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function isInitialized(address account) external view returns (bool) {
        return _initialized[account];
    }

    function namespace() public pure returns (string memory) {
        return _namespace();
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }

    function getAccountOwner(address account) external view returns (address) {
        return _accountOwners[account];
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function onInstall(bytes calldata data) external {
        if (_initialized[msg.sender]) revert ALREADY_INITIALIZED();
        _initialized[msg.sender] = true;
        address owner = abi.decode(data, (address));
        if (owner == address(0)) revert ZERO_ADDRESS();
        _accountOwners[msg.sender] = owner;
    }

    function onUninstall(bytes calldata) external {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _initialized[msg.sender] = false;
        delete _accountOwners[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _namespace() internal pure virtual returns (string memory);
    
    function _decodeProofData(bytes memory proofDataRaw) internal pure virtual returns (ProofData memory) {
        (uint48 validUntil, bytes32 commitment, bytes memory proof, bytes memory signature) =
            abi.decode(proofDataRaw, (uint48, bytes32, bytes, bytes));
        return ProofData(validUntil, commitment, proof, signature);
    }
    
    function _createMessageHash(bytes32 commitment) internal pure returns (bytes32) {
        return keccak256(abi.encode(namespace(), commitment));
    }
    
    /// @notice Verifies a proof using a specified verifier
    /// @param verifier The proof verifier contract address
    /// @param commitment The commitment to verify against
    /// @param message The message or data being verified
    /// @param proof The verification proof
    function _verifyProof(
        address verifier,
        bytes32 commitment,
        bytes memory message,
        bytes memory proof
    ) internal view returns (bool) {
        if (verifier == address(0)) revert VERIFIER_REQUIRED();
        return ISuperProofVerifier(verifier).verifyProof(commitment, message, proof);
    }
    
    /// @notice Verifies a batch of proofs using a specified verifier
    /// @param verifier The proof verifier contract address
    /// @param commitments Array of commitments
    /// @param messages Array of messages
    /// @param proofs Array of proofs
    /// @return validProofs Bitmap of valid proofs
    function _batchVerifyProofs(
        address verifier,
        bytes32[] memory commitments,
        bytes[] memory messages,
        bytes[] memory proofs
    ) internal view returns (uint256) {
        if (verifier == address(0)) revert VERIFIER_REQUIRED();
        if (commitments.length != messages.length || commitments.length != proofs.length) 
            revert ARRAY_LENGTH_MISMATCH();
            
        return ISuperProofVerifier(verifier).batchVerifyProofs(commitments, messages, proofs);
    }
    
    /// @notice Verifies a signature using a specified verifier
    /// @param verifier The signature verifier contract address
    /// @param signer The expected signer
    /// @param message The message that was signed
    /// @param signature The signature to verify
    function _verifySignature(
        address verifier,
        address signer,
        bytes32 message,
        bytes memory signature
    ) internal view returns (bool) {
        if (verifier == address(0)) revert VERIFIER_REQUIRED();
        return ISuperSignatureVerifier(verifier).verifySignature(signer, message, signature);
    }
    
    /// @notice Recovers the signer of a signature using a specified verifier
    /// @param verifier The signature verifier contract address
    /// @param message The message that was signed
    /// @param signature The signature to recover from
    /// @return signer The recovered signer address
    function _recoverSigner(
        address verifier,
        bytes32 message,
        bytes memory signature
    ) internal view returns (address) {
        if (verifier == address(0)) revert VERIFIER_REQUIRED();
        return ISuperSignatureVerifier(verifier).recoverSigner(message, signature);
    }
    
    function _isSignatureValid(
        address signer,
        address sender,
        uint48 validUntil
    )
        internal
        view
        virtual
        returns (bool)
    {
        return signer == _accountOwners[sender] && validUntil >= block.timestamp;
    }
}