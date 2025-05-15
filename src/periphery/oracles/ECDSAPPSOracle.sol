// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// External
import { ECDSA } from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

// Superform
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../interfaces/ISuperVaultAggregator.sol";
import { IECDSAPPSOracle } from "../interfaces/IECDSAPPSOracle.sol";

/// @title ECDSAPPSOracle
/// @author Superform Labs
/// @notice PPS Oracle that validates price updates using ECDSA signatures
/// @dev Implements the IECDSAPPSOracle interface for validating and forwarding PPS updates
contract ECDSAPPSOracle is IECDSAPPSOracle {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    /// @notice The SuperGovernor contract for validator verification
    ISuperGovernor public immutable SUPER_GOVERNOR;
    bytes32 private constant SUPER_VAULT_AGGREGATOR = keccak256("SUPER_VAULT_AGGREGATOR");

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the ECDSAPPSOracle contract
    /// @param superGovernor_ Address of the SuperGovernor contract
    constructor(address superGovernor_) {
        if (superGovernor_ == address(0)) revert INVALID_VALIDATOR();

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                         PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IECDSAPPSOracle
    function updatePPS(address strategy, bytes[] calldata proofs, uint256 pps, uint256 timestamp) external {
        // Validate proofs and check quorum requirement
        _validateProofs(strategy, proofs, pps, timestamp);

        emit PPSValidated(strategy, pps, timestamp, msg.sender);

        // Forward the validated PPS update to the SuperVaultAggregator
        // The msg.sender is passed as updateAuthority for upkeep tracking
        ISuperVaultAggregator(SUPER_GOVERNOR.getAddress(SUPER_VAULT_AGGREGATOR)).forwardPPS(
            msg.sender, strategy, pps, timestamp
        );
    }

    /// @inheritdoc IECDSAPPSOracle
    function batchUpdatePPS(
        address[] calldata strategies,
        bytes[][] calldata proofsArray,
        uint256[] calldata ppss,
        uint256[] calldata timestamps
    )
        external
    {
        uint256 strategiesLength = strategies.length;

        if (strategiesLength == 0) revert ZERO_LENGTH_ARRAY();

        // Validate input array lengths
        if (
            strategiesLength != proofsArray.length || strategiesLength != ppss.length
                || strategiesLength != timestamps.length
        ) revert ARRAY_LENGTH_MISMATCH();

        // Process each strategy update
        for (uint256 i; i < strategiesLength; i++) {
            address strategy = strategies[i];
            bytes[] calldata proofs = proofsArray[i];
            uint256 pps = ppss[i];
            uint256 timestamp = timestamps[i];

            _validateProofs(strategy, proofs, pps, timestamp);
            emit PPSValidated(strategy, pps, timestamp, msg.sender);
        }

        // Forward all validated updates to SuperVaultAggregator as a batch
        ISuperVaultAggregator(SUPER_GOVERNOR.getAddress(SUPER_VAULT_AGGREGATOR)).batchForwardPPS(
            strategies, ppss, timestamps
        );
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates an array of proofs for a strategy's PPS update
    /// @param strategy Address of the strategy
    /// @param proofs Array of cryptographic proofs
    /// @param pps Price-per-share value
    /// @param timestamp Timestamp when the value was generated
    /// @dev Reverts immediately if duplicate signers are found or quorum is not met
    function _validateProofs(address strategy, bytes[] calldata proofs, uint256 pps, uint256 timestamp) internal view {
        // Check if this oracle is the active PPS Oracle
        if (!SUPER_GOVERNOR.isActivePPSOracle(address(this))) revert NOT_ACTIVE_PPS_ORACLE();
        // Create message hash
        bytes32 messageHash = keccak256(abi.encodePacked(strategy, pps, timestamp));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Track valid signers and count
        uint256 validSignatureCount;

        uint256 proofsLength = proofs.length;
        address[] memory seenSigners = new address[](proofsLength);

        if (proofsLength == 0) revert ZERO_LENGTH_ARRAY();

        // Process each proof
        for (uint256 i; i < proofsLength; i++) {
            // Recover the signer from the proof
            address signer = ethSignedMessageHash.recover(proofs[i]);

            // Verify the signer is a registered validator
            if (!SUPER_GOVERNOR.isValidator(signer)) revert INVALID_VALIDATOR();

            // Check for duplicate signers and revert if found
            for (uint256 j; j < validSignatureCount; j++) {
                if (seenSigners[j] == signer) revert INVALID_PROOF();
            }

            // Mark this signer as seen and increment count
            seenSigners[validSignatureCount] = signer;
            validSignatureCount++;
        }

        // Ensure we have enough valid signatures to meet quorum
        uint256 quorumRequirement = SUPER_GOVERNOR.getPPSOracleQuorum();
        if (validSignatureCount < quorumRequirement) revert QUORUM_NOT_MET();
    }
}
