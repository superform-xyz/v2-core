// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

// Superform
import { ChainAgnosticSafeSignatureValidation } from "../libraries/ChainAgnosticSafeSignatureValidation.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";

/// @title SuperValidatorBase
/// @author Superform Labs
/// @notice A base contract for all Superform validators
abstract contract SuperValidatorBase is ERC7579ValidatorBase, ISuperValidator {
    using ChainAgnosticSafeSignatureValidation for address;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
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
    error INVALID_DESTINATION_PROOF(); // thrown on source
    error NOT_EIP1271_SIGNER();

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
        address owner = abi.decode(data, (address));
        if (owner == address(0)) revert ZERO_ADDRESS();
        _initialized[msg.sender] = true;
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
    /// @notice Returns the namespace identifier for this validator
    /// @dev Used for module compatibility and identification in the ERC-7579 framework
    /// @return The string identifier for this validator class
    function _namespace() internal pure virtual returns (string memory) {
        return "SuperValidator";
    }

    function _createLeaf(
        bytes memory data,
        uint48 validUntil,
        bool checkCrossChainExecution
    )
        internal
        view
        virtual
        returns (bytes32);

    function _createDestinationLeaf(
        DestinationData memory destinationData,
        uint48 validUntil,
        address validator
    )
        internal
        view
        virtual
        returns (bytes32)
    {
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
                        destinationData.dstTokens,
                        destinationData.intentAmounts,
                        validUntil,
                        validator
                    )
                )
            )
        );
    }

    /// @notice Decodes raw signature data into a structured SignatureData object
    /// @dev Handles ABI decoding of all signature components
    /// @param sigDataRaw ABI-encoded signature data bytes
    /// @return Structured SignatureData for further processing
    function _decodeSignatureData(bytes memory sigDataRaw) internal pure virtual returns (SignatureData memory) {
        (
            bool validateDstProof,
            uint48 validUntil,
            bytes32 merkleRoot,
            bytes32[] memory proofSrc,
            DstProof[] memory proofDst,
            bytes memory signature
        ) = abi.decode(sigDataRaw, (bool, uint48, bytes32, bytes32[], DstProof[], bytes));
        return SignatureData(validateDstProof, validUntil, merkleRoot, proofSrc, proofDst, signature);
    }

    /// @notice Creates a message hash from a merkle root for signature verification
    /// @dev In the base implementation, the message hash is simply the merkle root itself
    ///      Derived contracts might implement more complex hashing if needed
    /// @param merkleRoot The merkle root to use for message hash creation
    /// @return The hash that was signed by the account owner
    function _createMessageHash(bytes32 merkleRoot) internal pure returns (bytes32) {
        return keccak256(abi.encode(namespace(), merkleRoot));
    }

    /// @notice Processes an EOA signature and returns the signer
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @return signer The address that signed the message
    function _processECDSASignature(SignatureData memory sigData) internal pure returns (address signer) {
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(messageHash);

        signer = ECDSA.recover(ethSignedMessageHash, sigData.signature);
    }

    /// @notice Processes an EIP-1271 contract signature with chain-agnostic validation
    /// @dev First tries Safe-specific chain-agnostic validation, then falls back to generic EIP-1271
    /// @param contractSigner The EIP-1271 compatible contract address
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @return The contract address if validation succeeds, address(0) if it fails
    function _processEIP1271Signature(
        address contractSigner,
        SignatureData memory sigData
    )
        internal
        view
        returns (address)
    {
        // For Safe contracts: Try chain-agnostic validation first (cross-chain compatibility)
        if (contractSigner.validateChainAgnosticMultisig(sigData, _createMessageHash(sigData.merkleRoot))) {
            return contractSigner;
        }

        // Generic EIP-1271 validation (works for ALL EIP-1271 contracts including Safe fallback)
        bytes32 messageHash = _createMessageHash(sigData.merkleRoot);
        try IERC1271(contractSigner).isValidSignature(messageHash, sigData.signature) returns (bytes4 result) {
            if (result == IERC1271.isValidSignature.selector) {
                return contractSigner;
            }
        } catch { }

        revert NOT_EIP1271_SIGNER();
    }

    /// @notice Validates if a signature is valid based on signer and expiration time
    /// @dev Checks that the signer matches the registered account owner and signature hasn't expired
    /// @param signer The address recovered from the signature
    /// @param sender The account address being operated on
    /// @param validUntil Timestamp after which the signature is no longer valid
    /// @return True if the signature is valid, false otherwise
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
        /// @dev block.timestamp could vary between chains
        /// @dev validUntil = 0 means infinite validity
        return signer == _accountOwners[sender] && (validUntil == 0 || validUntil >= block.timestamp);
    }

    /// @notice Checks if an address supports EIP-1271 signature validation
    /// @param addr The address to check
    /// @return True if the address supports EIP-1271, false otherwise
    function _isEIP1271Signer(address addr) internal view returns (bool) {
        if (addr.code.length == 0) return false; // EOA

        // Try calling isValidSignature with properly formatted dummy data
        // Safe7579 expects: [20 bytes validator address][signature data]
        // Use address(0) as validator (falls back to Safe's checkSignatures) + 1 byte signature
        bytes memory testSignature = abi.encodePacked(address(0), hex"00");
        bytes memory callData = abi.encodeWithSelector(IERC1271.isValidSignature.selector, bytes32(0), testSignature);
        (bool success, bytes memory returnData) = addr.staticcall{ gas: 50_000 }(callData);

        // Function exists if:
        // 1. Call succeeds (function exists and validation passed)
        // 2. Call fails but returns data (function exists but validation failed)
        // 3. Call fails with no data = function doesn't exist
        return success || returnData.length > 0;
    }
}
