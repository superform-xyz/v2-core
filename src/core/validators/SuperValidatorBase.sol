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
    /// @notice Structure holding proof data for destination chain operations
    /// @dev Contains merkle proof and destination chain ID
    struct DstProof {
        bytes32[] proof;
        uint64 dstChainId;
        DstInfo info;
    }

    /// @notice Structure holding destination chain operation details
    /// @dev Used to validate destination `proof` on source validator
    struct DstInfo {
        address account;
        address executor;
        address[] dstTokens;
        uint256[] intentAmounts;
        address validator;
        bytes data;
    }

    /// @notice Structure representing data specific to a destination chain operation
    /// @dev Contains all necessary data to validate and execute a cross-chain operation
    struct DestinationData {
        /// @notice The encoded call data to be executed
        bytes callData;
        /// @notice The destination chain ID where execution should occur
        uint64 chainId;
        /// @notice The account that should execute the operation
        address sender;
        /// @notice The executor contract address that handles the operation
        address executor;
        /// @notice The tokens required in the target account to proceed with the execution
        address[] dstTokens;
        /// @notice The minimum token amounts required for execution
        uint256[] intentAmounts;
    }


    /// @notice Structure holding signature data used across validator implementations
    /// @dev Contains all components needed for merkle proof verification and signature validation
    struct SignatureData {
        /// @notice Whether to validate destination proof
        bool validateDstProof;
        /// @notice Timestamp after which the signature is no longer valid
        uint48 validUntil;
        /// @notice Root of the merkle tree containing operation leaves
        bytes32 merkleRoot;
        /// @notice Merkle proof for the source chain operation
        bytes32[] proofSrc;
        /// @notice Merkle proof for the destination chains operation
        DstProof[] proofDst;
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

    function _createLeaf(bytes memory data, uint48 validUntil, bool checkCrossChainExecution) internal view virtual returns (bytes32);

    function _createDestinationLeaf(DestinationData memory destinationData, uint48 validUntil, address validator) internal view virtual returns (bytes32) {
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
