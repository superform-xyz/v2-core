// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { ISuperVaultAggregator } from "./ISuperVaultAggregator.sol";

/// @title ISuperAssetRegistry
/// @author Superform Labs
/// @notice Interface for PPS updates, strategist management, and upkeep management
interface ISuperAssetRegistry {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    /// @notice Emitted when a PPS value is updated
    /// @param strategy Address of the strategy
    /// @param pps New price-per-share value
    /// @param ppsStdev Standard deviation of price-per-share value
    /// @param validatorSet Number of validators who calculated this PPS
    /// @param totalValidators Total number of validators in the network
    /// @param timestamp Timestamp of the update
    event PPSUpdated(
        address indexed strategy,
        uint256 pps,
        uint256 ppsStdev,
        uint256 validatorSet,
        uint256 totalValidators,
        uint256 timestamp
    );

    /// @notice Emitted when a strategy is paused due to missed updates
    /// @param strategy Address of the paused strategy
    event StrategyPaused(address indexed strategy);

    /// @notice Emitted when a strategy is unpaused
    /// @param strategy Address of the unpaused strategy
    event StrategyUnpaused(address indexed strategy);

    /// @notice Emitted when a strategy validation check fails but execution continues
    /// @param strategy Address of the strategy that failed the check
    /// @param reason String description of which check failed
    event StrategyCheckFailed(address indexed strategy, string reason);

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

    /// @notice Emitted when a strategy's PPS verification thresholds are updated
    /// @param strategy Address of the strategy
    /// @param dispersionThreshold New dispersion threshold (stddev/mean)
    /// @param deviationThreshold New deviation threshold (abs diff/current)
    /// @param mnThreshold New M/N threshold (validatorSet/totalValidators)
    event PPSVerificationThresholdsUpdated(
        address indexed strategy, uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold
    );

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
    /// @notice Thrown when caller is not an approved PPS oracle
    error UNAUTHORIZED_PPS_ORACLE();
    /// @notice Thrown when PPS update is too frequent (before minUpdateInterval)
    error UPDATE_TOO_FREQUENT();
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
    /// @notice Thrown when attempting to add a strategist that already exists
    error STRATEGIST_ALREADY_EXISTS();
    /// @notice Thrown when strategist is not found
    error STRATEGIST_NOT_FOUND();
    /// @notice Thrown when there is no pending strategist change proposal
    error NO_PENDING_STRATEGIST_CHANGE();
    /// @notice Thrown when the timelock for a proposed change has not expired
    error TIMELOCK_NOT_EXPIRED();

    /*//////////////////////////////////////////////////////////////
                          PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Forwards a validated PPS update from a trusted oracle
    /// @param updateAuthority Address that initiated the update (for upkeep tracking for single updates)
    /// @param args Struct containing all PPS update parameters
    function forwardPPS(address updateAuthority, ISuperVaultAggregator.ForwardPPSArgs calldata args) external;

    /// @notice Batch forwards validated PPS updates to multiple strategies
    /// @param args Struct containing all batch PPS update parameters
    function batchForwardPPS(ISuperVaultAggregator.BatchForwardPPSArgs calldata args) external;

    /// @notice Initialize strategy data for a newly created strategy
    /// @param strategy Address of the strategy
    /// @param mainStrategist Address of the main strategist
    /// @param minUpdateInterval Minimum update interval
    /// @param maxStaleness Maximum staleness allowed
    /// @param assetDecimals Decimals of the underlying asset
    function initializeStrategyData(
        address strategy,
        address mainStrategist,
        uint256 minUpdateInterval,
        uint256 maxStaleness,
        uint8 assetDecimals
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
    /// @param strategy Address of the strategy
    /// @param strategist Address of the strategist to add
    function addSecondaryStrategist(address strategy, address strategist) external;

    /// @notice Removes a secondary strategist from a strategy
    /// @param strategy Address of the strategy
    /// @param strategist Address of the strategist to remove
    function removeSecondaryStrategist(address strategy, address strategist) external;

    /// @notice Changes the primary strategist of a strategy immediately (only callable by SuperGovernor)
    /// @param strategy Address of the strategy
    /// @param newStrategist Address of the new primary strategist
    function changePrimaryStrategist(address strategy, address newStrategist) external;

    /// @notice Proposes a change to the primary strategist (callable by secondary strategists)
    /// @param strategy Address of the strategy
    /// @param newStrategist Address of the proposed new primary strategist
    function proposeChangePrimaryStrategist(address strategy, address newStrategist) external;

    /// @notice Executes a previously proposed change to the primary strategist after timelock
    /// @param strategy Address of the strategy
    function executeChangePrimaryStrategist(address strategy) external;

    /// @notice Updates the PPS verification thresholds for a strategy
    /// @param strategy Address of the strategy
    /// @param dispersionThreshold_ New dispersion threshold (stddev/mean ratio, scaled by 1e18)
    /// @param deviationThreshold_ New deviation threshold (abs diff/current ratio, scaled by 1e18)
    /// @param mnThreshold_ New M/N threshold (validatorSet/totalValidators ratio, scaled by 1e18)
    function updatePPSVerificationThresholds(
        address strategy,
        uint256 dispersionThreshold_,
        uint256 deviationThreshold_,
        uint256 mnThreshold_
    )
        external;

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Gets the current PPS (price-per-share) for a strategy
    /// @param strategy Address of the strategy
    /// @return pps Current price-per-share value
    function getPPS(address strategy) external view returns (uint256 pps);

    /// @notice Gets the current PPS and its standard deviation for a strategy
    /// @param strategy Address of the strategy
    /// @return pps Current price-per-share value
    /// @return ppsStdev Standard deviation of price-per-share value
    function getPPSWithStdDev(address strategy) external view returns (uint256 pps, uint256 ppsStdev);

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

    /// @notice Gets the PPS verification thresholds for a strategy
    /// @param strategy Address of the strategy
    /// @return dispersionThreshold The current dispersion threshold (stddev/mean ratio, scaled by 1e18)
    /// @return deviationThreshold The current deviation threshold (abs diff/current ratio, scaled by 1e18)
    /// @return mnThreshold The current M/N threshold (validatorSet/totalValidators ratio, scaled by 1e18)
    function getPPSVerificationThresholds(address strategy)
        external
        view
        returns (uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold);

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

    /// @notice Check if an address is any kind of strategist (primary or secondary)
    /// @param strategist Address to check
    /// @param strategy The strategy to check against
    /// @return True if the address is either the primary strategist or a secondary strategist
    function isAnyStrategist(address strategist, address strategy) external view returns (bool);
}
