// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

/// @title ISuperOracle
/// @author Superform Labs
/// @notice Interface for SuperOracle
interface ISuperOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Error when address is zero
    error ZERO_ADDRESS();

    /// @notice Error when array length is zero
    error ZERO_ARRAY_LENGTH();

    /// @notice Error when oracle provider index is invalid
    error INVALID_ORACLE_PROVIDER();

    /// @notice Error when no oracles are configured for base asset
    error NO_ORACLES_CONFIGURED();

    /// @notice Error when no valid reported prices are found
    error NO_VALID_REPORTED_PRICES();

    /// @notice Error when caller is not admin
    error NOT_ADMIN();

    /// @notice Error when arrays have mismatched lengths
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Error when timelock period has not elapsed
    error TIMELOCK_NOT_ELAPSED();

    /// @notice Error when there is already a pending update
    error PENDING_UPDATE_EXISTS();

    /// @notice Error when oracle data is untrusted
    error ORACLE_UNTRUSTED_DATA();

    /// @notice Error when provider max staleness period is not set
    error NO_PENDING_UPDATE();

    /// @notice Error when quote is not supported (only USD is supported)
    error UNSUPPORTED_QUOTE();

    /// @notice Error when provider max staleness period is exceeded
    error MAX_STALENESS_EXCEEDED();

    /// @notice Error when no prices are reported
    error NO_PRICES();

    /// @notice Error when average provider is not allowed
    error AVERAGE_PROVIDER_NOT_ALLOWED();

    /// @notice Error when provider is zero
    error ZERO_PROVIDER();
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when oracles are configured
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param feeds Array of oracle addresses
    event OraclesConfigured(address[] bases, address[] quotes, bytes32[] providers, address[] feeds);

    /// @notice Emitted when oracle update is queued
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param feeds Array of oracle addresses
    /// @param timestamp Timestamp when update was queued
    event OracleUpdateQueued(
        address[] bases, address[] quotes, bytes32[] providers, address[] feeds, uint256 timestamp
    );

    /// @notice Emitted when oracle update is executed
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param feeds Array of oracle addresses
    event OracleUpdateExecuted(address[] bases, address[] quotes, bytes32[] providers, address[] feeds);

    /// @notice Emitted when provider max staleness period is updated
    /// @param feed Feed address
    /// @param newMaxStaleness New maximum staleness period in seconds
    event FeedMaxStalenessUpdated(address feed, uint256 newMaxStaleness);

    /// @notice Emitted when max staleness period is updated
    /// @param newMaxStaleness New maximum staleness period in seconds
    event MaxStalenessUpdated(uint256 newMaxStaleness);

    /// @notice Emitted when provider removal is queued
    /// @param providers Array of provider ids to remove
    /// @param timestamp Timestamp when removal was queued
    event ProviderRemovalQueued(bytes32[] providers, uint256 timestamp);

    /// @notice Emitted when provider removal is executed
    /// @param providers Array of provider ids that were removed
    event ProviderRemovalExecuted(bytes32[] providers);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct for pending oracle update
    struct PendingUpdate {
        address[] bases;
        address[] quotes;
        bytes32[] providers;
        address[] feeds;
        uint256 timestamp;
    }

    /// @notice Struct for pending provider removal
    struct PendingRemoval {
        bytes32[] providers;
        uint256 timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get oracle address for a base asset and provider
    /// @param base Base asset address
    /// @param quote Quote asset address
    /// @param provider Provider id
    /// @return oracle Oracle address
    function getOracleAddress(address base, address quote, bytes32 provider) external view returns (address oracle);

    /// @notice Get quote from specified oracle provider
    /// @param baseAmount Amount of base asset
    /// @param base Base asset address
    /// @param quote Quote asset address
    /// @param oracleProvider Id of oracle provider to use
    /// @return quoteAmount The quote amount
    function getQuoteFromProvider(uint256 baseAmount, address base, address quote, bytes32 oracleProvider)
        external
        view
        returns (uint256 quoteAmount, uint256 deviation, uint256 totalProviders, uint256 availableProviders);

    /// @notice Queue oracle update for timelock
    /// @param bases Array of base assets
    /// @param providers Array of provider ids
    /// @param quotes Array of quote assets
    /// @param feeds Array of oracle addresses
    function queueOracleUpdate(
        address[] calldata bases,
        address[] calldata quotes,
        bytes32[] calldata providers,
        address[] calldata feeds
    ) external;

    /// @notice Execute queued oracle update after timelock period
    function executeOracleUpdate() external;

    /// @notice Queue provider removal for timelock
    /// @param providers Array of provider ids to remove
    function queueProviderRemoval(bytes32[] calldata providers) external;

    /// @notice Execute queued provider removal after timelock period
    function executeProviderRemoval() external;

    /// @notice Set the maximum staleness period for a specific provider
    /// @param feed Feed address
    /// @param newMaxStaleness New maximum staleness period in seconds
    function setFeedMaxStaleness(address feed, uint256 newMaxStaleness) external;

    /// @notice Set the maximum staleness period for all providers
    /// @param newMaxStaleness New maximum staleness period in seconds
    function setMaxStaleness(uint256 newMaxStaleness) external;

    /// @notice Set the maximum staleness period for multiple providers
    /// @param feeds Array of feed addresses
    /// @param newMaxStalenessList Array of new maximum staleness periods in seconds
    function setFeedMaxStalenessBatch(address[] calldata feeds, uint256[] calldata newMaxStalenessList) external;

    /// @notice Get all active provider ids
    /// @return Array of active provider ids
    function getActiveProviders() external view returns (bytes32[] memory);
}
