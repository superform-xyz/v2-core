// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { SuperValidatorBaseSimulations } from "./SuperValidatorBaseSimulations.sol";

/// @title SuperDestinationValidatorSimulations
/// @author Superform Labs
/// @notice Simulation helper used for SuperDestinationValidator. This contract is not to be deployed
/// @dev Consumers must reserve gas for live owner-signature validation separately. A pre-signature
///      simulation cannot reproduce arbitrary Safe/EIP-1271 valid-path gas from placeholder bytes.
contract SuperDestinationValidatorSimulations is SuperValidatorBaseSimulations {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @dev bytes4(keccak256("isValidDestinationSignature(address,bytes)")) = 0x5c2ec0f3
    bytes4 constant DESTINATION_SIGNATURE_MAGIC_VALUE = bytes4(0x5c2ec0f3);
    bytes4 constant INVALID_DESTINATION_SIGNATURE = 0x00000000;

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validate a user operation
    /// @dev Not implemented
    function validateUserOp(
        PackedUserOperation calldata,
        bytes32
    )
        external
        pure
        override
        returns (ValidationData)
    {
        // @dev The following validator shouldn't be used for EntryPoint calls
        revert NOT_IMPLEMENTED();
    }

    /// @notice Validate a signature with sender
    function isValidSignatureWithSender(address, bytes32, bytes calldata)
        external
        pure
        virtual
        override
        returns (bytes4)
    {
        revert NOT_IMPLEMENTED();
    }

    function isValidDestinationSignature(address sender, bytes calldata data) external view returns (bytes4) {
        if (!_initialized[sender]) revert NOT_INITIALIZED();

        // Decode data
        (SignatureData memory sigData, DestinationData memory destinationData) =
            _decodeSignatureAndDestinationData(data);

        // Exercise the destination proof hashing path, but do not validate the placeholder
        // simulation signature. The bundler cannot synthesize a valid signature for arbitrary
        // Safe/EIP-1271 owners before the user signs the final intent.
        bytes32 processedRoot = _createLeafAndProcessProof(sigData, destinationData);

        // Keep proof hashing observable so the optimizer cannot remove its gas. The simulation
        // executor intentionally ignores this return value because its proof and signature are
        // placeholders; a valid proof still receives the production magic value.
        return processedRoot == sigData.merkleRoot ? DESTINATION_SIGNATURE_MAGIC_VALUE : INVALID_DESTINATION_SIGNATURE;
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a unique leaf hash for merkle tree verification
    /// @dev Overrides the base implementation to handle destination-specific data
    ///      `executor` is included in the leaf to ensure that the leaf is unique for each executor,
    ///      otherwise it would allow the owner's signature to be replayed if the account mistakenly
    ///      installs two of the same executors
    /// @param data Encoded destination data containing execution details
    /// @param validUntil Timestamp after which the signature becomes invalid
    /// @return The calculated leaf hash used in merkle tree verification
    function _createLeafForDestination(bytes memory data, uint48 validUntil) internal view returns (bytes32) {
        DestinationData memory destinationData = abi.decode(data, (DestinationData));

        return _createDestinationLeaf(destinationData, validUntil, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates the destination leaf and exercises proof processing
    /// @dev Simulation payloads contain placeholder proofs and signatures, so cryptographic
    ///      validity is intentionally not enforced. Structural decoding and proof hashing remain.
    /// @param sigData Signature data including merkle root, proofs, and actual signature
    /// @param destinationData The destination execution data to create the leaf hash from
    /// @return processedRoot The root reconstructed from the destination leaf and proof
    function _createLeafAndProcessProof(
        SignatureData memory sigData,
        DestinationData memory destinationData
    )
        private
        view
        returns (bytes32 processedRoot)
    {
        bytes32 leaf = _createLeafForDestination(abi.encode(destinationData), sigData.validUntil);
        processedRoot = MerkleProof.processProof(_extractProof(sigData), leaf);
    }

    /// @notice Extracts the proof for the current chain from the signature data
    /// @dev Iterates over the proofDst array to find a match for the current chain ID
    /// @param sigData Signature data containing proofs for different chains
    /// @return The proof array corresponding to the current chain ID
    /// @dev Reverts with PROOF_NOT_FOUND if no matching proof is found
    function _extractProof(SignatureData memory sigData) private view returns (bytes32[] memory) {
        uint256 len = sigData.proofDst.length;
        for (uint256 i; i < len; ++i) {
            if (sigData.proofDst[i].dstChainId == block.chainid) {
                return sigData.proofDst[i].proof;
            }
        }
        revert PROOF_NOT_FOUND();
    }

    /// @notice Decodes signature and destination data from raw bytes
    /// @dev Decodes the signature data and destination data from the raw bytes
    /// @param data Raw bytes containing signature and destination data
    /// @return The decoded signature data and destination data
    function _decodeSignatureAndDestinationData(bytes memory data)
        private
        pure
        returns (SignatureData memory, DestinationData memory)
    {
        (bytes memory sigDataRaw, bytes memory destinationDataRaw) = abi.decode(data, (bytes, bytes));
        return (_decodeSignatureData(sigDataRaw), _decodeDestinationData(destinationDataRaw));
    }

    /// @notice Decodes raw destination data
    /// @param destinationDataRaw ABI-encoded destination data bytes
    /// @return Structured DestinationData for further processing
    function _decodeDestinationData(bytes memory destinationDataRaw) private pure returns (DestinationData memory) {
        (
            bytes memory callData,
            uint64 chainId,
            address decodedSender,
            address executor,
            address[] memory dstTokens,
            uint256[] memory intentAmounts
        ) = abi.decode(destinationDataRaw, (bytes, uint64, address, address, address[], uint256[]));

        return DestinationData(callData, chainId, decodedSender, executor, dstTokens, intentAmounts);
    }
}
