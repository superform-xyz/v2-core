// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ISuperValidator
/// @author Superform Labs
interface ISuperValidator {
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
        /// @notice List of chain IDs that require destination proof validation
        uint64[] chainsWithDestinationExecution;
        /// @notice Timestamp after which the signature is no longer valid
        uint48 validUntil;
        /// @notice Timestamp before which the signature is not yet valid
        uint48 validAfter;
        /// @notice Root of the merkle tree containing operation leaves
        bytes32 merkleRoot;
        /// @notice Merkle proof for the source chain operation
        bytes32[] proofSrc;
        /// @notice Merkle proof for the destination chains operation
        DstProof[] proofDst;
        /// @notice Raw ECDSA signature bytes
        bytes signature;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event AccountOwnerSet(address indexed account, address indexed owner);
    event AccountUnset(address indexed account);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the sender account has not been initialized
    error INVALID_SENDER();
    error NOT_INITIALIZED();
    error NOT_IMPLEMENTED();
    error PROOF_NOT_FOUND();
    error INVALID_CHAIN_ID();

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function namespace() external pure returns (string memory);
}
