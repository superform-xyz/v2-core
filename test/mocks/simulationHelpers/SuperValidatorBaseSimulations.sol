// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { ERC7579ValidatorBase } from "modulekit/Modules.sol";

// Superform
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";

/// @title SuperValidatorBaseSimulations
/// @author Superform Labs
/// @notice A base contract for all Superform validators used for simulations. This contract is not to be deployed
abstract contract SuperValidatorBaseSimulations is ERC7579ValidatorBase, ISuperValidator {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice Tracks which accounts have initialized this validator
    /// @dev Used to prevent unauthorized use of the validator
    mapping(address account => bool initialized) internal _initialized;

    /// @notice Maps accounts to their owners
    /// @dev Used to verify signatures against the correct owner address
    mapping(address account => address owner) internal _accountOwners;

    /// @notice Prefix for 7702 authority -> https://eip7702.io/
    bytes3 internal constant EIP7702_PREFIX = bytes3(0xef0100);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZERO_ADDRESS();
    error INVALID_PROOF();
    error ALREADY_INITIALIZED();
    error INVALID_DESTINATION_PROOF(); // thrown on source
    error EMPTY_DESTINATION_PROOF();
    error PROOF_COUNT_MISMATCH();
    error INVALID_MERKLE_PROOF();
    error UNEXPECTED_CHAIN_PROOF();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function isInitialized(address account) external view returns (bool) {
        return _initialized[account];
    }

    function namespace() public pure returns (string memory) {
        return _namespace();
    }

    function isModuleType(uint256 typeId) external pure override returns (bool) {
        return typeId == TYPE_VALIDATOR;
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
        emit AccountOwnerSet(msg.sender, owner);
    }

    function onUninstall(bytes calldata) external {
        if (!_initialized[msg.sender]) revert NOT_INITIALIZED();
        _initialized[msg.sender] = false;

        delete _accountOwners[msg.sender];
        emit AccountUnset(msg.sender);
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
            uint64[] memory chainsWithDestinationExecution,
            uint48 validUntil,
            uint48 validAfter,
            bytes32 merkleRoot,
            bytes32[] memory proofSrc,
            DstProof[] memory proofDst,
            bytes memory signature
        ) = abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], DstProof[], bytes));
        return SignatureData(
            chainsWithDestinationExecution, validUntil, validAfter, merkleRoot, proofSrc, proofDst, signature
        );
    }

    /// @dev `_processSignatureForAccountType` deliberately does NOT exist here.
    ///      It used to be a hand-copied duplicate of `SuperValidatorBase`'s, with ZERO callers — the only
    ///      subclass, `SuperDestinationValidatorSimulations`, goes through `_createLeafAndProcessProof` and
    ///      returns the magic value on a root match without validating the placeholder simulation signature.
    ///      A duplicate with no callers is pure drift risk: it silently fell behind the real base (it still
    ///      had the pre-SUP-17924 "codeless owner == EOA" branch) while looking authoritative. If a
    ///      simulation ever needs real account-type dispatch, inherit the production base rather than copying
    ///      it.

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
    /// @param validAfter Timestamp before which the signature is not yet valid
    /// @return True if the signature is valid, false otherwise
    function _isSignatureValid(
        address signer,
        address sender,
        uint48 validUntil,
        uint48 validAfter
    )
        internal
        view
        virtual
        returns (bool)
    {
        /// @dev block.timestamp could vary between chains
        // validUntil == 0 means infinite validity
        // validAfter must be <= block.timestamp (signature only valid after this time)
        // validAfter must be <= validUntil (if validUntil != 0)
        bool isValid = block.timestamp >= validAfter
            && (validUntil == 0 || (validUntil >= block.timestamp && validAfter <= validUntil));

        if (_is7702Account(sender.code)) {
            // in case of 7702 owner is the account itself (the EOA)
            return signer == sender && isValid;
        }
        return signer == _accountOwners[sender] && isValid;
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
        return _isSignatureValid(signer, sender, validUntil, 0);
    }

    /// @notice Checks if an address is a 7702 signer
    /// @param code The code of the address to check
    /// @return True if the address is a 7702 signer, false otherwise
    function _is7702Account(bytes memory code) internal pure returns (bool) {
        return bytes3(code) == EIP7702_PREFIX;
    }
}
