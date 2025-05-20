// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

/// @title ECDSAPPSOracle
/// @author Superform Labs
/// @notice Interface for PPS oracles that provide price-per-share updates
/// @dev All PPS oracle implementations must conform to this interface
interface IECDSAPPSOracle {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when the proof is invalid or cannot be verified
    error INVALID_PROOF();
    /// @notice Thrown when a validator is not registered or authorized
    error INVALID_VALIDATOR();
    /// @notice Thrown when the quorum of validators is not met
    error QUORUM_NOT_MET();
    /// @notice Thrown when the input arrays have different lengths
    error ARRAY_LENGTH_MISMATCH();
    /// @notice Thrown when the input array is empty
    error ZERO_LENGTH_ARRAY();
    /// @notice Thrown when the timestamp in the proof is invalid
    error INVALID_TIMESTAMP();
    /// @notice Thrown when the strategy address in the proof does not match
    error STRATEGY_MISMATCH();
    /// @notice Thrown when the pps value in the proof does not match
    error PPS_MISMATCH();
    /// @notice Thrown when the oracle is not set as the active PPS Oracle in SuperGovernor
    error NOT_ACTIVE_PPS_ORACLE();
    /// @notice Thrown when the dispersion (standard deviation / mean) is too high
    error HIGH_PPS_DISPERSION();
    /// @notice Thrown when the deviation from previous PPS is too high
    error HIGH_PPS_DEVIATION();
    /// @notice Thrown when too few validators participated in the round
    error INSUFFICIENT_VALIDATOR_PARTICIPATION();
    /// @notice Thrown when the reported validator count doesn't match the actual number of valid signatures
    error VALIDATOR_COUNT_MISMATCH();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a PPS update is validated and forwarded
    /// @param strategy Address of the strategy
    /// @param pps The validated price-per-share value
    /// @param ppsStdev The standard deviation of the price-per-share
    /// @param validatorSet Number of validators who calculated the PPS
    /// @param totalValidators Total number of validators in the network
    /// @param timestamp Timestamp when the value was generated
    /// @param sender Address that submitted the update
    event PPSValidated(
        address indexed strategy, 
        uint256 pps, 
        uint256 ppsStdev,
        uint256 validatorSet,
        uint256 totalValidators,
        uint256 timestamp, 
        address indexed sender
    );

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Arguments for updating PPS for a single strategy
    /// @param strategy Address of the strategy
    /// @param proofs Array of cryptographic proofs of the PPS value from different validators
    /// @param pps Price-per-share value (mean)
    /// @param ppsStdev Standard deviation of the price-per-share
    /// @param validatorSet Number of validators who calculated this PPS
    /// @param totalValidators Total number of validators in the network
    /// @param timestamp Timestamp when the value was generated
    struct UpdatePPSArgs {
        address strategy;
        bytes[] proofs;
        uint256 pps;
        uint256 ppsStdev;
        uint256 validatorSet;
        uint256 totalValidators;
        uint256 timestamp;
    }

    /// @notice Arguments for batch updating PPS for multiple strategies
    /// @param strategies Array of strategy addresses
    /// @param proofsArray Array of arrays of cryptographic proofs (one array of proofs per strategy)
    /// @param ppss Array of price-per-share values (means)
    /// @param ppsStdevs Array of standard deviations of price-per-share values
    /// @param validatorSets Array of numbers of validators who calculated each PPS
    /// @param totalValidators Array of total number of validators in the network for each update
    /// @param timestamps Array of timestamps when values were generated
    struct BatchUpdatePPSArgs {
        address[] strategies;
        bytes[][] proofsArray;
        uint256[] ppss;
        uint256[] ppsStdevs;
        uint256[] validatorSets;
        uint256[] totalValidators;
        uint256[] timestamps;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the PPS for a single strategy
    /// @param args Struct containing all parameters for PPS update
    function updatePPS(UpdatePPSArgs calldata args) external;

    /// @notice Updates the PPS for multiple strategies in a batch
    /// @param args Struct containing all parameters for batch PPS update
    function batchUpdatePPS(BatchUpdatePPSArgs calldata args) external;
}
