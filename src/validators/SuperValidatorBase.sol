// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { ISuperValidator } from "../interfaces/ISuperValidator.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

// Add import for Safe interface
interface ISafeConfig {
    function getOwners() external view returns (address[] memory);
    function getThreshold() external view returns (uint256);
    function isOwner(address owner) external view returns (bool);
}

/// @title SuperValidatorBase
/// @author Superform Labs
/// @notice A base contract for all Superform validators
abstract contract SuperValidatorBase is ERC7579ValidatorBase, ISuperValidator {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Tracks which accounts have initialized this validator
    /// @dev Used to prevent unauthorized use of the validator
    mapping(address account => bool initialized) internal _initialized;

    /// @notice Maps accounts to their owners
    /// @dev Used to verify signatures against the correct owner address
    mapping(address account => address owner) internal _accountOwners;

    bytes4 internal constant MAGIC_VALUE_EIP1271 = bytes4(0x1626ba7e);

    /// @notice Chain-agnostic domain separator type hash
    /// @dev Uses a fixed domain without chainId for cross-chain compatibility
    bytes32 private constant CHAIN_AGNOSTIC_DOMAIN_TYPEHASH =
        0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f; // keccak256("EIP712Domain(string name,string
        // version,uint256 chainId,address verifyingContract)")

    /// @notice Fixed chain ID for cross-chain signature compatibility
    uint256 private constant FIXED_CHAIN_ID = 1;

    /// @notice Domain name and version for cross-chain signatures
    string private constant DOMAIN_NAME = "SuperformSafe";
    string private constant DOMAIN_VERSION = "1.0.0";

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_PROOF();
    error ALREADY_INITIALIZED();
    error INVALID_DESTINATION_PROOF(); // thrown on source

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

    /// @notice Processes a contract signature using chain-agnostic validation
    /// @dev Bypasses Safe's native EIP-712 validation to enable cross-chain compatibility
    /// @param safe The Safe account address
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @return The Safe address if validation succeeds, address(0) if it fails
    function _processEIP1271Signature(address safe, SignatureData memory sigData) internal view returns (address) {
        // Use chain-agnostic validation instead of Safe's native isValidSignature
        if (_validateChainAgnosticMultisig(safe, sigData)) {
            return safe;
        }
        return address(0);
    }

    /// @notice Validates multisig signature using chain-agnostic domain separator
    /// @dev Implements custom multisig validation that works across all chains
    /// @param safe The Safe account address
    /// @param sigData Signature data to validate
    /// @return True if the signature is valid for the Safe's multisig configuration
    function _validateChainAgnosticMultisig(address safe, SignatureData memory sigData) internal view returns (bool) {
        // Check if the account has code (is a contract)
        if (safe.code.length == 0) {
            return false;
        }

        // Get the chain-agnostic message hash
        bytes32 rawHash = _createMessageHash(sigData.merkleRoot);
        bytes32 chainAgnosticHash = _getChainAgnosticTypedDataHash(rawHash, safe);

        // Get Safe configuration
        address[] memory owners = _getSafeOwners(safe);
        uint256 threshold = _getSafeThreshold(safe);

        // Validate signatures against the multisig configuration
        return _verifyMultisigSignatures(chainAgnosticHash, sigData.signature, owners, threshold);
    }

    /// @notice Creates chain-agnostic EIP-712 typed data hash
    /// @dev Uses fixed chainId and consistent domain across all chains
    /// @param structHash The struct hash to wrap in EIP-712 format
    /// @param verifyingContract The Safe contract address
    /// @return The chain-agnostic typed data hash
    function _getChainAgnosticTypedDataHash(
        bytes32 structHash,
        address verifyingContract
    )
        internal
        pure
        returns (bytes32)
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                CHAIN_AGNOSTIC_DOMAIN_TYPEHASH,
                keccak256(bytes(DOMAIN_NAME)),
                keccak256(bytes(DOMAIN_VERSION)),
                FIXED_CHAIN_ID,
                verifyingContract
            )
        );

        return keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                domainSeparator,
                keccak256(abi.encode(keccak256("SafeMessage(bytes message)"), keccak256(abi.encode(structHash))))
            )
        );
    }

    /// @notice Retrieves the list of owners from a Safe contract
    /// @dev Reads the owners array from the Safe's storage
    /// @param safe The Safe contract address
    /// @return owners Array of owner addresses
    function _getSafeOwners(address safe) internal view returns (address[] memory owners) {
        try ISafeConfig(safe).getOwners() returns (address[] memory _owners) {
            return _owners;
        } catch {
            // Fallback: return empty array if call fails
            return new address[](0);
        }
    }

    /// @notice Retrieves the signature threshold from a Safe contract
    /// @dev Reads the threshold value from the Safe's storage
    /// @param safe The Safe contract address
    /// @return threshold Number of signatures required
    function _getSafeThreshold(address safe) internal view returns (uint256 threshold) {
        try ISafeConfig(safe).getThreshold() returns (uint256 _threshold) {
            return _threshold;
        } catch {
            // Fallback: return 0 if call fails
            return 0;
        }
    }

    /// @notice Verifies multisig signatures against owners and threshold
    /// @dev Implements Safe-compatible signature verification with chain-agnostic hash
    /// @param messageHash The chain-agnostic message hash
    /// @param signatures The concatenated signature data
    /// @param owners Array of Safe owner addresses
    /// @param threshold Required number of signatures
    /// @return True if enough valid signatures are provided
    function _verifyMultisigSignatures(
        bytes32 messageHash,
        bytes memory signatures,
        address[] memory owners,
        uint256 threshold
    )
        internal
        view
        returns (bool)
    {
        if (threshold == 0 || owners.length == 0) {
            return false;
        }

        // Account for 20-byte validator address prefix in Safe signature format
        uint256 signatureOffset = 20;
        uint256 actualSignatureLength = signatures.length - signatureOffset;

        if (actualSignatureLength < threshold * 65) {
            return false;
        }

        address lastOwner = address(0);
        uint256 validSignatures = 0;

        for (uint256 i = 0; i < threshold; i++) {
            // Extract signature components (similar to Safe's signatureSplit)
            // Skip the 20-byte validator address prefix
            uint8 v;
            bytes32 r;
            bytes32 s;

            assembly {
                let signaturePos := add(mul(i, 65), signatureOffset)
                r := mload(add(add(signatures, 0x20), signaturePos))
                s := mload(add(add(signatures, 0x40), signaturePos))
                v := byte(0, mload(add(add(signatures, 0x60), signaturePos)))
            }

            // Recover signer address
            address currentOwner = ecrecover(messageHash, v, r, s);

            // Check if recovered address is a valid owner and maintains order
            if (currentOwner > lastOwner && _isOwner(currentOwner, owners)) {
                validSignatures++;
                lastOwner = currentOwner;
            }
        }

        return validSignatures >= threshold;
    }

    /// @notice Checks if an address is in the owners array
    /// @dev Helper function for signature verification
    /// @param addr Address to check
    /// @param owners Array of owner addresses
    /// @return True if the address is an owner
    function _isOwner(address addr, address[] memory owners) internal pure returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == addr) {
                return true;
            }
        }
        return false;
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
}
