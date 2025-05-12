// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { ISuperVaultStrategy } from "../interfaces/ISuperVaultStrategy.sol";

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
    /// @param mainStrategist Address of the primary strategist controlling the strategy
    /// @param secondaryStrategists Set of secondary strategists that can manage the strategy
    /// @param authorizedCallers List of callers authorized to update PPS without paying upkeep
    struct StrategyData {
        uint256 pps;
        uint256 lastUpdateTimestamp;
        uint256 minUpdateInterval;
        uint256 maxStaleness;
        bool isPaused;
        address mainStrategist;
        EnumerableSet.AddressSet secondaryStrategists;
        address[] authorizedCallers;
        // Strategist change proposal data
        address proposedStrategist;
        uint256 strategistChangeEffectiveTime;
        address strategistChangeProposer;
    }

    /// @notice Parameters for creating a new SuperVault trio
    /// @param asset Address of the underlying asset
    /// @param name Name of the vault token
    /// @param symbol Symbol of the vault token
    /// @param mainStrategist Address of the vault mainStrategist
    /// @param minUpdateInterval Minimum time interval between PPS updates
    /// @param maxStaleness Maximum time allowed between PPS updates before staleness
    /// @param feeConfig Fee configuration for the vault
    struct VaultCreationParams {
        address asset;
        string name;
        string symbol;
        address mainStrategist;
        uint256 minUpdateInterval;
        uint256 maxStaleness;
        ISuperVaultStrategy.FeeConfig feeConfig;
    }

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

    /// @notice Emitted when a secondary strategist is added to a strategy
    /// @param strategy Address of the strategy
    /// @param strategist Address of the strategist added
    event SecondaryStrategistAdded(address indexed strategy, address indexed strategist);

    /// @notice Emitted when a secondary strategist is removed from a strategy
    /// @param strategy Address of the strategy
    /// @param strategist Address of the strategist removed
    event SecondaryStrategistRemoved(address indexed strategy, address indexed strategist);

    /// @notice Emitted when a primary strategist is changed
    /// @param strategy Address of the strategy
    /// @param oldStrategist Address of the old primary strategist
    /// @param newStrategist Address of the new primary strategist
    event PrimaryStrategistChanged(
        address indexed strategy, address indexed oldStrategist, address indexed newStrategist
    );

    /// @notice Emitted when a primary strategist is changed to a superform strategist
    /// @param strategy Address of the strategy
    /// @param oldStrategist Address of the old primary strategist
    /// @param newStrategist Address of the new primary strategist (superform strategist)
    event PrimaryStrategistChangedToSuperForm(
        address indexed strategy, address indexed oldStrategist, address indexed newStrategist
    );

    /// @notice Emitted when a change to primary strategist is proposed by a secondary strategist
    /// @param strategy Address of the strategy
    /// @param proposer Address of the secondary strategist who made the proposal
    /// @param newStrategist Address of the proposed new primary strategist
    /// @param effectiveTime Timestamp when the proposal can be executed
    event PrimaryStrategistChangeProposed(
        address indexed strategy, address indexed proposer, address indexed newStrategist, uint256 effectiveTime
    );

    /// @notice Emitted when a PPS update is stale (Validators could get slashed for innactivity)
    /// @param strategy Address of the strategy
    /// @param updateAuthority Address of the update authority
    /// @param timestamp Timestamp of the stale update
    event StaleUpdate(address indexed strategy, address indexed updateAuthority, uint256 timestamp);

    /// @notice Emitted when the upkeep cost per update is changed
    /// @param oldCost Previous upkeep cost per update
    /// @param newCost New upkeep cost per update
    event UpkeepCostUpdated(uint256 oldCost, uint256 newCost);

    /*///////////////////////////////////////////////////////////////
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
    /// @notice Thrown when attempting to remove the last strategist
    error CANNOT_REMOVE_LAST_STRATEGIST();
    /// @notice Thrown when attempting to add a strategist that already exists
    error STRATEGIST_ALREADY_EXISTS();
    /// @notice Thrown when strategist is not found
    error STRATEGIST_NOT_FOUND();
    /// @notice Thrown when there is no pending strategist change proposal
    error NO_PENDING_STRATEGIST_CHANGE();
    /// @notice Thrown when caller is not authorized to update settings
    error UNAUTHORIZED_CALLER();
    /// @notice Thrown when the timelock for a proposed change has not expired
    error TIMELOCK_NOT_EXPIRED();

    /*//////////////////////////////////////////////////////////////
                            VAULT CREATION
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a new SuperVault trio (SuperVault, SuperVaultStrategy, SuperVaultEscrow)
    /// @param params Parameters for the new vault creation
    /// @return superVault Address of the created SuperVault
    /// @return strategy Address of the created SuperVaultStrategy
    /// @return escrow Address of the created SuperVaultEscrow
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow);

    /*//////////////////////////////////////////////////////////////
                          PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Forwards a validated PPS update from a trusted oracle
    /// @param updateAuthority Address that initiated the update (for upkeep tracking for single updates)
    /// @param strategy Address of the strategy to update
    /// @param pps New price-per-share value
    /// @param timestamp Timestamp when this value was generated
    function forwardPPS(address updateAuthority, address strategy, uint256 pps, uint256 timestamp) external;

    /// @notice Forwards multiple validated PPS updates from a trusted oracle
    /// @param strategies Array of strategy addresses to update
    /// @param ppss Array of new price-per-share values
    /// @param timestamps Array of timestamps when values were generated
    function batchForwardPPS(
        address[] calldata strategies,
        uint256[] calldata ppss,
        uint256[] calldata timestamps
    )
        external;

    /*//////////////////////////////////////////////////////////////
                        UPKEEP MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposits UP tokens for strategist upkeep
    /// @param strategist Address of the strategist to deposit for
    /// @param amount Amount of UP tokens to deposit
    function depositUpkeep(address strategist, uint256 amount) external;

    /// @notice Withdraws UP tokens from strategist upkeep balance
    /// @param amount Amount of UP tokens to withdraw
    function withdrawUpkeep(uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED CALLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds an authorized caller for a strategy
    /// @param strategy Address of the strategy
    /// @param caller Address of the caller to authorize
    function addAuthorizedCaller(address strategy, address caller) external;

    /// @notice Removes an authorized caller for a strategy
    /// @param strategy Address of the strategy
    /// @param caller Address of the caller to remove
    function removeAuthorizedCaller(address strategy, address caller) external;

    /*//////////////////////////////////////////////////////////////
                       STRATEGIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds a secondary strategist to a strategy
    /// @notice A strategist can either be secondary or primary
    /// @param strategy Address of the strategy
    /// @param strategist Address of the strategist to add
    function addSecondaryStrategist(address strategy, address strategist) external;

    /// @notice Removes a secondary strategist from a strategy
    /// @param strategy Address of the strategy
    /// @param strategist Address of the strategist to remove
    function removeSecondaryStrategist(address strategy, address strategist) external;

    /// @notice Changes the primary strategist of a strategy immediately (only callable by SuperGovernor)
    /// @notice A strategist can either be secondary or primary
    /// @param strategy Address of the strategy
    /// @param newStrategist Address of the new primary strategist
    function changePrimaryStrategist(address strategy, address newStrategist) external;

    /// @notice Proposes a change to the primary strategist (callable by secondary strategists)
    /// @notice A strategist can either be secondary or primary
    /// @param strategy Address of the strategy
    /// @param newStrategist Address of the proposed new primary strategist
    function proposeChangePrimaryStrategist(address strategy, address newStrategist) external;

    /// @notice Executes a previously proposed change to the primary strategist after timelock
    /// @param strategy Address of the strategy
    function executeChangePrimaryStrategist(address strategy) external;

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

    /// @notice Gets the current upkeep balance for a strategist
    /// @param strategist Address of the strategist
    /// @return balance Current upkeep balance in UP tokens
    function getUpkeepBalance(address strategist) external view returns (uint256 balance);

    /// @notice Gets all authorized callers for a strategy
    /// @param strategy Address of the strategy
    /// @return callers Array of authorized callers
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers);

    /// @notice Gets the main strategist for a strategy
    /// @param strategy Address of the strategy
    /// @return strategist Address of the main strategist
    function getMainStrategist(address strategy) external view returns (address strategist);

    /// @notice Checks if an address is the main strategist for a strategy
    /// @param strategist Address of the strategist
    /// @param strategy Address of the strategy
    /// @return isMainStrategist True if the address is the main strategist, false otherwise
    function isMainStrategist(address strategist, address strategy) external view returns (bool isMainStrategist);

    /// @notice Gets all secondary strategists for a strategy
    /// @param strategy Address of the strategy
    /// @return secondaryStrategists Array of secondary strategist addresses
    function getSecondaryStrategists(address strategy) external view returns (address[] memory secondaryStrategists);

    /// @notice Checks if an address is a secondary strategist for a strategy
    /// @param strategist Address of the strategist
    /// @param strategy Address of the strategy
    /// @return isSecondaryStrategist True if the address is a secondary strategist, false otherwise
    function isSecondaryStrategist(
        address strategist,
        address strategy
    )
        external
        view
        returns (bool isSecondaryStrategist);

    /// @dev Internal helper function to check if an address is any kind of strategist (primary or secondary)
    /// @param strategist Address to check
    /// @param strategy The strategy to check against
    /// @return True if the address is either the primary strategist or a secondary strategist
    function isAnyStrategist(address strategist, address strategy) external view returns (bool);

    /// @notice Gets all created SuperVaults
    /// @return Array of SuperVault addresses
    function getAllSuperVaults() external view returns (address[] memory);

    /// @notice Gets a SuperVault by index
    /// @param index The index of the SuperVault
    /// @return The SuperVault address at the given index
    function superVaults(uint256 index) external view returns (address);

    /// @notice Gets all created SuperVaultStrategies
    /// @return Array of SuperVaultStrategy addresses
    function getAllSuperVaultStrategies() external view returns (address[] memory);

    /// @notice Gets a SuperVaultStrategy by index
    /// @param index The index of the SuperVaultStrategy
    /// @return The SuperVaultStrategy address at the given index
    function superVaultStrategies(uint256 index) external view returns (address);

    /// @notice Gets all created SuperVaultEscrows
    /// @return Array of SuperVaultEscrow addresses
    function getAllSuperVaultEscrows() external view returns (address[] memory);

    /// @notice Gets a SuperVaultEscrow by index
    /// @param index The index of the SuperVaultEscrow
    /// @return The SuperVaultEscrow address at the given index
    function superVaultEscrows(uint256 index) external view returns (address);
}
