// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title IPPSOracle
/// @author Superform Labs
/// @notice Interface for PPS oracles that provide price-per-share updates
/// @dev All PPS oracle implementations must conform to this interface
interface IPPSOracle {
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

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a PPS update is validated and forwarded
    /// @param strategy Address of the strategy
    /// @param pps The validated price-per-share value
    /// @param timestamp Timestamp when the value was generated
    /// @param sender Address that submitted the update
    event PPSValidated(address indexed strategy, uint256 pps, uint256 timestamp, address indexed sender);

    /// @notice Emitted when the validator quorum requirement is updated
    /// @param newQuorum The new quorum value
    event QuorumUpdated(uint256 newQuorum);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the PPS for a single strategy
    /// @param strategy Address of the strategy
    /// @param proofs Array of cryptographic proofs of the PPS value from different validators
    /// @param pps Price-per-share value
    /// @param timestamp Timestamp when the value was generated
    function updatePPS(address strategy, bytes[] calldata proofs, uint256 pps, uint256 timestamp) external;

    /// @notice Updates the PPS for multiple strategies in a batch
    /// @param strategies Array of strategy addresses
    /// @param proofsArray Array of arrays of cryptographic proofs (one array of proofs per strategy)
    /// @param ppss Array of price-per-share values
    /// @param timestamps Array of timestamps when values were generated
    function batchUpdatePPS(
        address[] calldata strategies,
        bytes[][] calldata proofsArray,
        uint256[] calldata ppss,
        uint256[] calldata timestamps
    )
        external;

    /// @notice Gets the current validator quorum requirement
    /// @return The number of validators required for a valid proof
    function getQuorumRequirement() external view returns (uint256);
}
