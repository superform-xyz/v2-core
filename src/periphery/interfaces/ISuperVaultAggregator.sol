// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @title ISuperVaultAggregator
/// @author Superform Labs
/// @notice Interface for the SuperVaultAggregator contract
/// @dev Registry and PPS oracle for all SuperVaults
interface ISuperVaultAggregator {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Strategy configuration and state data
    /// @param pps Current price-per-share value
    /// @param lastUpdateTimestamp Last time PPS was updated
    /// @param minUpdateInterval Minimum time interval between PPS updates
    /// @param maxStaleness Maximum time allowed between PPS updates before staleness
    /// @param isPaused Whether the strategy is paused
    /// @param strategist Address of the strategist controlling the strategy
    /// @param authorizedCallers List of callers authorized to update PPS without paying upkeep
    struct StrategyData {
        uint256 pps;
        uint256 lastUpdateTimestamp;
        uint256 minUpdateInterval;
        uint256 maxStaleness;
        bool isPaused;
        address strategist;
        address[] authorizedCallers;
    }

    /// @notice Parameters for creating a new SuperVault trio
    /// @param asset Address of the underlying asset
    /// @param name Name of the vault token
    /// @param symbol Symbol of the vault token
    /// @param manager Address of the vault manager
    /// @param strategist Address of the vault strategist
    /// @param emergencyAdmin Address of the emergency admin
    /// @param feeRecipient Address that will receive fees
    /// @param superVaultCap Maximum cap for the vault (in underlying asset)
    /// @param minUpdateInterval Minimum time interval between PPS updates
    /// @param maxStaleness Maximum time allowed between PPS updates before staleness
    struct VaultCreationParams {
        address asset;
        string name;
        string symbol;
        address manager;
        address strategist;
        address emergencyAdmin;
        address feeRecipient;
        uint256 superVaultCap;
        uint256 minUpdateInterval;
        uint256 maxStaleness;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when address provided is zero
    error ZERO_ADDRESS();
    /// @notice Thrown when array length is zero
    error ZERO_ARRAY_LENGTH();
    /// @notice Thrown when array length is zero
    error ARRAY_LENGTH_MISMATCH();

    /// @notice Thrown when insufficient upkeep balance for operation
    error INSUFFICIENT_UPKEEP();
    /// @notice Thrown when vault is paused but operation requires active state
    error VAULT_PAUSED();
    /// @notice Thrown when caller is not an approved PPS oracle
    error UNAUTHORIZED_PPS_ORACLE();
    /// @notice Thrown when PPS update is too frequent (before minUpdateInterval)
    error UPDATE_TOO_FREQUENT();
    /// @notice Thrown when PPS update is too stale (after maxStaleness)
    error UPDATE_TOO_STALE();
    /// @notice Thrown when caller is not authorized for update
    error UNAUTHORIZED_UPDATE_AUTHORITY();
    /// @notice Thrown when strategy address is not a known SuperVault strategy
    error UNKNOWN_STRATEGY();
    /// @notice Thrown when withdrawing more upkeep than available
    error INSUFFICIENT_UPKEEP_BALANCE();
    /// @notice Thrown when caller is already authorized
    error CALLER_ALREADY_AUTHORIZED();
    /// @notice Thrown when caller is not authorized
    error CALLER_NOT_AUTHORIZED();
    /// @notice Thrown when array index is out of bounds
    error INDEX_OUT_OF_BOUNDS();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a new vault trio is created
    /// @param vault Address of the created SuperVault
    /// @param strategy Address of the created SuperVaultStrategy
    /// @param escrow Address of the created SuperVaultEscrow
    /// @param asset Address of the underlying asset
    /// @param name Name of the vault token
    /// @param symbol Symbol of the vault token
    event VaultDeployed(
        address indexed vault, address indexed strategy, address escrow, address asset, string name, string symbol
    );

    /// @notice Emitted when a PPS value is updated
    /// @param strategy Address of the strategy
    /// @param pps New price-per-share value
    /// @param timestamp Timestamp of the update
    event PPSUpdated(address indexed strategy, uint256 pps, uint256 timestamp);

    /// @notice Emitted when a strategy is paused due to missed updates
    /// @param strategy Address of the paused strategy
    event StrategyPaused(address indexed strategy);

    /// @notice Emitted when a strategy is unpaused
    /// @param strategy Address of the unpaused strategy
    event StrategyUnpaused(address indexed strategy);

    /// @notice Emitted when upkeep tokens are deposited
    /// @param strategist Address of the strategist
    /// @param amount Amount of UP tokens deposited
    event UpkeepDeposited(address indexed strategist, uint256 amount);

    /// @notice Emitted when upkeep tokens are withdrawn
    /// @param strategist Address of the strategist
    /// @param amount Amount of UP tokens withdrawn
    event UpkeepWithdrawn(address indexed strategist, uint256 amount);

    /// @notice Emitted when upkeep tokens are spent for validation
    /// @param strategist Address of the strategist
    /// @param amount Amount of UP tokens spent
    event UpkeepSpent(address indexed strategist, uint256 amount);

    /// @notice Emitted when an authorized caller is added for a strategy
    /// @param strategy Address of the strategy
    /// @param caller Address of the authorized caller
    event AuthorizedCallerAdded(address indexed strategy, address indexed caller);

    /// @notice Emitted when an authorized caller is removed for a strategy
    /// @param strategy Address of the strategy
    /// @param caller Address of the removed caller
    event AuthorizedCallerRemoved(address indexed strategy, address indexed caller);

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Creates a new SuperVault trio (SuperVault, SuperVaultStrategy, SuperVaultEscrow)
    /// @param params Parameters for the new vault creation
    /// @return superVault Address of the created SuperVault
    /// @return strategy Address of the created SuperVaultStrategy
    /// @return escrow Address of the created SuperVaultEscrow
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow);

    /// @notice Forwards a validated PPS update from a trusted oracle
    /// @param updateAuthority Address that initiated the update (for upkeep tracking)
    /// @param strategy Address of the strategy to update
    /// @param pps New price-per-share value
    /// @param timestamp Timestamp when this value was generated
    function forwardPPS(address updateAuthority, address strategy, uint256 pps, uint256 timestamp) external;

    /// @notice Forwards multiple validated PPS updates from a trusted oracle
    /// @param updateAuthority Address that initiated the updates (for upkeep tracking)
    /// @param strategies Array of strategy addresses to update
    /// @param ppss Array of new price-per-share values
    /// @param timestamps Array of timestamps when values were generated
    function batchForwardPPS(
        address updateAuthority,
        address[] calldata strategies,
        uint256[] calldata ppss,
        uint256[] calldata timestamps
    )
        external;

    /// @notice Deposits UP tokens for strategist upkeep
    /// @param strategist Address of the strategist to deposit for
    /// @param amount Amount of UP tokens to deposit
    function depositUpkeep(address strategist, uint256 amount) external;

    /// @notice Withdraws UP tokens from strategist upkeep balance
    /// @param amount Amount of UP tokens to withdraw
    function withdrawUpkeep(uint256 amount) external;

    /// @notice Gets the full strategy data
    /// @param strategy Address of the strategy
    /// @return data The StrategyData struct containing all strategy information
    function getStrategyData(address strategy) external view returns (StrategyData memory data);

    /// @notice Gets the current PPS (price-per-share) for a strategy
    /// @param strategy Address of the strategy
    /// @return pps Current price-per-share value
    function getPPS(address strategy) external view returns (uint256 pps);

    /// @notice Gets the last update timestamp for a strategy's PPS
    /// @param strategy Address of the strategy
    /// @return timestamp Last update timestamp
    function getLastUpdateTimestamp(address strategy) external view returns (uint256 timestamp);

    /// @notice Gets the minimum update interval for a strategy
    /// @param strategy Address of the strategy
    /// @return interval Minimum time between updates
    function getMinUpdateInterval(address strategy) external view returns (uint256 interval);

    /// @notice Gets the maximum staleness period for a strategy
    /// @param strategy Address of the strategy
    /// @return staleness Maximum time allowed between updates
    function getMaxStaleness(address strategy) external view returns (uint256 staleness);

    /// @notice Checks if a strategy is currently paused
    /// @param strategy Address of the strategy
    /// @return isPaused True if paused, false otherwise
    function isStrategyPaused(address strategy) external view returns (bool isPaused);

    /// @notice Gets all authorized callers for a strategy
    /// @param strategy Address of the strategy
    /// @return callers Array of authorized callers
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers);

    /// @notice Gets the strategist for a strategy
    /// @param strategy Address of the strategy
    /// @return strategist Address of the strategist
    function getStrategist(address strategy) external view returns (address strategist);

    /// @notice Checks if an address is the strategist for a strategy
    /// @param strategist Address of the strategist
    /// @param strategy Address of the strategy
    /// @return isStrategist True if the address is the strategist, false otherwise
    function isStrategist(address strategist, address strategy) external view returns (bool isStrategist);

    /// @notice Gets the current upkeep balance for a strategist
    /// @param strategist Address of the strategist
    /// @return balance Current upkeep balance in UP tokens
    function getUpkeepBalance(address strategist) external view returns (uint256 balance);

    /// @notice Adds an authorized caller for a strategy
    /// @param strategy Address of the strategy
    /// @param caller Address of the caller to authorize
    function addAuthorizedCaller(address strategy, address caller) external;

    /// @notice Removes an authorized caller for a strategy
    /// @param strategy Address of the strategy
    /// @param caller Address of the caller to remove
    function removeAuthorizedCaller(address strategy, address caller) external;
}
