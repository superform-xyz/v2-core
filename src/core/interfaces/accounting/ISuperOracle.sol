// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title ISuperOracle
/// @author Superform Labs
/// @notice Interface for SuperOracle
interface ISuperOracle {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

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

    /// @notice Error when ISO 4217 quote is invalid
    error INVALID_ISO4217_QUOTE();

    /// @notice Error when ISO 4217 quote is already supported
    error ISO4217_QUOTE_ALREADY_SUPPORTED();

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when oracles are configured
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param oracleAddresses Array of oracle addresses
    event OraclesConfigured(address[] bases, uint256[] providers, address[] oracleAddresses);

    /// @notice Emitted when oracle update is queued
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param oracleAddresses Array of oracle addresses
    /// @param timestamp Timestamp when update was queued
    event OracleUpdateQueued(address[] bases, uint256[] providers, address[] oracleAddresses, uint256 timestamp);

    /// @notice Emitted when oracle update is executed
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param oracleAddresses Array of oracle addresses
    event OracleUpdateExecuted(address[] bases, uint256[] providers, address[] oracleAddresses);

    /// @notice Emitted when provider max staleness period is updated
    /// @param provider Provider index
    /// @param newMaxStaleness New maximum staleness period in seconds
    event ProviderMaxStalenessUpdated(uint256 provider, uint256 newMaxStaleness);

    /// @notice Emitted when a new ISO 4217 quote is added
    /// @param quote The quote address added
    event ISO4217QuoteAdded(address indexed quote);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct for pending oracle update
    struct PendingUpdate {
        address[] bases;
        uint256[] providers;
        address[] oracleAddresses;
        uint256 timestamp;
    }
    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get oracle address for a base asset and provider
    /// @param base Base asset address
    /// @param provider Provider index
    /// @return oracle Oracle address
    function getOracleAddress(address base, uint256 provider) external view returns (address oracle);

    /// @notice Get quote from specified oracle provider
    /// @param baseAmount Amount of base asset
    /// @param base Base asset address
    /// @param quote Quote asset address
    /// @param oracleProvider Index of oracle provider to use
    /// @return quoteAmount The quote amount
    function getQuoteFromProvider(
        uint256 baseAmount,
        address base,
        address quote,
        uint256 oracleProvider
    )
        external
        view
        returns (uint256 quoteAmount);

    /// @notice Queue oracle update for timelock
    /// @param bases Array of base assets
    /// @param providers Array of provider indexes
    /// @param oracleAddresses Array of oracle addresses
    function queueOracleUpdate(
        address[] calldata bases,
        uint256[] calldata providers,
        address[] calldata oracleAddresses
    )
        external;

    /// @notice Execute queued oracle update after timelock period
    function executeOracleUpdate() external;

    /// @notice Set the maximum staleness period for a specific provider
    /// @param provider Provider index
    /// @param newMaxStaleness New maximum staleness period in seconds
    function setProviderMaxStaleness(uint256 provider, uint256 newMaxStaleness) external;
}
