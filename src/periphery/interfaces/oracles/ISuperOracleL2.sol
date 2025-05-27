// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title ISuperOracleL2
/// @author Superform Labs
/// @notice Interface for Layer 2 Oracle for Superform
interface ISuperOracleL2 {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Error when no uptime feed is configured for the data oracle
    error NO_UPTIME_FEED();

    /// @notice Error when the L2 sequencer is down
    error SEQUENCER_DOWN();

    /// @notice Error when the grace period after sequencer restart is not over
    error GRACE_PERIOD_NOT_OVER();

    /*//////////////////////////////////////////////////////////////
                            EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when an uptime feed is set for a data oracle
    /// @param dataOracle The data oracle address
    /// @param uptimeOracle The uptime feed address
    event UptimeFeedSet(address dataOracle, address uptimeOracle);

    /// @notice Emitted when a grace period is set for an uptime oracle
    /// @param uptimeOracle The uptime oracle address
    /// @param gracePeriod The grace period in seconds
    event GracePeriodSet(address uptimeOracle, uint256 gracePeriod);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Set uptime feeds for multiple data oracles in batch
    /// @param dataOracles Array of data oracle addresses to set uptime feeds for
    /// @param uptimeOracles Array of uptime feed addresses to set
    /// @param gracePeriods Array of grace periods in seconds after sequencer restart
    function batchSetUptimeFeed(
        address[] calldata dataOracles,
        address[] calldata uptimeOracles,
        uint256[] calldata gracePeriods
    ) external;
}
