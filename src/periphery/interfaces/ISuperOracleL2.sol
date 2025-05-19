// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

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
    /// @notice Set the uptime feed for a data oracle
    /// @param dataOracle The data oracle to set the uptime feed for
    /// @param uptimeOracle The uptime feed to set for the data oracle
    /// @param gracePeriod The grace period in seconds after sequencer restart
    function setUptimeFeed(address dataOracle, address uptimeOracle, uint256 gracePeriod) external;
}
