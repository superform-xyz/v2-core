// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {ERC7579ValidatorBase} from "modulekit/Modules.sol";
import {ISuperSignatureStorage} from "../interfaces/ISuperSignatureStorage.sol";

/// @title SuperValidatorBase
/// @author Superform Labs
/// @notice A base contract for all Superform validators
abstract contract SuperValidatorBase is ERC7579ValidatorBase {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Structure holding signature data used across validator implementations
    /// @dev Contains all components needed for merkle proof verification and signature validation
    struct SignatureData {
        /// @notice Timestamp after which the signature is no longer valid
        uint48 validUntil;
        /// @notice Root of the merkle tree containing operation leaves
        bytes32 merkleRoot;
        /// @notice Merkle proof for the source chain operation
        bytes32[] proofSrc;
        /// @notice Merkle proof for the destination chain operation
        bytes32[] proofDst;
        /// @notice Raw ECDSA signature bytes
        bytes signature;
    }

    /// @notice Tracks which accounts have initialized this validator
    /// @dev Used to prevent unauthorized use of the validator
    mapping(address account => bool initialized) internal _initialized;

    /// @notice Maps accounts to their owners
    /// @dev Used to verify signatures against the correct owner address
    mapping(address account => address owner) internal _accountOwners;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_PROOF();
    error ALREADY_INITIALIZED();

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
        if (!_initialized[msg.sender]) revert ISuperSignatureStorage.NOT_INITIALIZED();
        _initialized[msg.sender] = false;
        delete _accountOwners[msg.sender];
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Returns the namespace identifier for this validator
    /// @dev Used for module compatibility and identification in the ERC-7579 framework
    /// @return The string identifier for this validator class
    function _namespace() internal pure virtual returns (string memory) {
        return "SuperValidator";
    }

    function _createLeaf(bytes memory data, uint48 validUntil) internal view virtual returns (bytes32);

    /// @notice Decodes raw signature data into a structured SignatureData object
    /// @dev Handles ABI decoding of all signature components
    /// @param sigDataRaw ABI-encoded signature data bytes
    /// @return Structured SignatureData for further processing
    function _decodeSignatureData(bytes memory sigDataRaw) internal pure virtual returns (SignatureData memory) {
        (
            uint48 validUntil,
            bytes32 merkleRoot,
            bytes32[] memory proofSrc,
            bytes32[] memory proofDst,
            bytes memory signature
        ) = abi.decode(sigDataRaw, (uint48, bytes32, bytes32[], bytes32[], bytes));
        return SignatureData(validUntil, merkleRoot, proofSrc, proofDst, signature);
    }

    /// @notice Creates a message hash from a merkle root for signature verification
    /// @dev In the base implementation, the message hash is simply the merkle root itself
    ///      Derived contracts might implement more complex hashing if needed
    /// @param merkleRoot The merkle root to use for message hash creation
    /// @return The hash that was signed by the account owner
    function _createMessageHash(bytes32 merkleRoot) internal pure returns (bytes32) {
        return keccak256(abi.encode(namespace(), merkleRoot));
    }

    /// @notice Validates if a signature is valid based on signer and expiration time
    /// @dev Checks that the signer matches the registered account owner and signature hasn't expired
    /// @param signer The address recovered from the signature
    /// @param sender The account address being operated on
    /// @param validUntil Timestamp after which the signature is no longer valid
    /// @return True if the signature is valid, false otherwise
    function _isSignatureValid(address signer, address sender, uint48 validUntil)
        internal
        view
        virtual
        returns (bool)
    {
        /// @dev block.timestamp could vary between chains
        /// @dev validUntil = 0 means infinite validity
        return signer == _accountOwners[sender] && (validUntil == 0 || validUntil >= block.timestamp);
    }
}
