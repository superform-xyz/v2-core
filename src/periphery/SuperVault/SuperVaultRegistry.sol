// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultRegistry } from "../interfaces/SuperVault/ISuperVaultRegistry.sol";
import { ISuperVaultAggregator } from "../interfaces/SuperVault/ISuperVaultAggregator.sol";

/// @title SuperVaultRegistry
/// @author Superform Labs
/// @notice Registry for PPS updates, strategist management, and upkeep management
contract SuperVaultRegistry is ISuperVaultRegistry {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Governance
    ISuperGovernor public immutable SUPER_GOVERNOR;

    // Strategy data storage (extracted from original StrategyData struct)
    mapping(address strategy => uint256 pps) private _strategyPPS;
    mapping(address strategy => uint256 ppsStdev) private _strategyPPSStdev;
    mapping(address strategy => uint256 lastUpdateTimestamp) private _strategyLastUpdateTimestamp;
    mapping(address strategy => uint256 minUpdateInterval) private _strategyMinUpdateInterval;
    mapping(address strategy => uint256 maxStaleness) private _strategyMaxStaleness;
    mapping(address strategy => bool isPaused) private _strategyIsPaused;
    mapping(address strategy => address mainStrategist) private _strategyMainStrategist;
    mapping(address strategy => EnumerableSet.AddressSet secondaryStrategists) private _strategySecondaryStrategists;
    mapping(address strategy => address[] authorizedCallers) private _strategyAuthorizedCallers;

    // Strategist change proposal data
    mapping(address strategy => address proposedStrategist) private _strategyProposedStrategist;
    mapping(address strategy => uint256 strategistChangeEffectiveTime) private _strategyStrategistChangeEffectiveTime;

    // PPS Verification thresholds
    mapping(address strategy => uint256 dispersionThreshold) private _strategyDispersionThreshold;
    mapping(address strategy => uint256 deviationThreshold) private _strategyDeviationThreshold;
    mapping(address strategy => uint256 mnThreshold) private _strategyMnThreshold;

    // Upkeep balances
    mapping(address strategist => uint256 upkeep) private _strategistUpkeepBalance;

    // Timelock for strategist changes
    uint256 private constant _STRATEGIST_CHANGE_TIMELOCK = 7 days;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that msg.sender is the active PPS Oracle
    modifier onlyAggregator() {
        if (msg.sender != SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_VAULT_AGGREGATOR())) {
            revert CALLER_NOT_AUTHORIZED();
        }
        _;
    }

    /// @notice Validates that a strategy exists (has been initialized)
    modifier validStrategy(address strategy) {
        if (_strategyMainStrategist[strategy] == address(0)) revert UNKNOWN_STRATEGY();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperAssetRegistry
    /// @param superGovernor_ Address of the SuperGovernor contract
    constructor(address superGovernor_) {
        if (superGovernor_ == address(0)) revert ZERO_ADDRESS();
        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
    }

    /*//////////////////////////////////////////////////////////////
                          PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultRegistry
    function forwardPPS(
        address updateAuthority,
        ISuperVaultAggregator.ForwardPPSArgs calldata args
    )
        external
        onlyAggregator
        validStrategy(args.strategy)
    {
        // Check if the update is exempt from paying upkeep
        bool isExempt = _isExemptFromUpkeep(args.strategy, updateAuthority, args.timestamp);

        // Create a new ForwardPPSArgs struct with updated isExempt and upkeepCost
        _forwardPPS(
            ISuperVaultAggregator.ForwardPPSArgs({
                strategy: args.strategy,
                isExempt: isExempt,
                pps: args.pps,
                ppsStdev: args.ppsStdev,
                validatorSet: args.validatorSet,
                totalValidators: args.totalValidators,
                timestamp: args.timestamp,
                upkeepCost: SUPER_GOVERNOR.getUpkeepCostPerUpdate()
            })
        );
    }

    /// @inheritdoc ISuperVaultRegistry
    function batchForwardPPS(ISuperVaultAggregator.BatchForwardPPSArgs calldata args) external onlyAggregator {
        // Check array lengths
        if (
            args.strategies.length != args.ppss.length || args.strategies.length != args.ppsStdevs.length
                || args.strategies.length != args.validatorSets.length || args.strategies.length != args.timestamps.length
        ) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        uint256 strategiesLength = args.strategies.length;
        if (strategiesLength == 0) revert ZERO_ARRAY_LENGTH();

        bool upkeepExempt = false;
        uint256 upkeepPerStrategy;

        // Check if upkeep payments are globally disabled in SuperGovernor
        if (SUPER_GOVERNOR.isUpkeepPaymentsEnabled()) {
            // Calculate upkeep cost per strategy
            upkeepPerStrategy = SUPER_GOVERNOR.getUpkeepCostPerUpdate() / strategiesLength;
        } else {
            upkeepExempt = true;
            upkeepPerStrategy = 0;
        }

        // Process all valid strategies
        for (uint256 i; i < strategiesLength; i++) {
            // Skip invalid strategies without reverting
            if (_strategyMainStrategist[args.strategies[i]] == address(0)) continue;

            // Forward update, not exempt from upkeep in batch updates
            _forwardPPS(
                ISuperVaultAggregator.ForwardPPSArgs({
                    strategy: args.strategies[i],
                    isExempt: upkeepExempt,
                    pps: args.ppss[i],
                    ppsStdev: args.ppsStdevs[i],
                    validatorSet: args.validatorSets[i],
                    totalValidators: args.totalValidators[i],
                    timestamp: args.timestamps[i],
                    upkeepCost: upkeepPerStrategy
                })
            );
        }
    }

    /// @inheritdoc ISuperVaultRegistry
    function initializeStrategyData(
        address strategy,
        address mainStrategist,
        uint256 minUpdateInterval,
        uint256 maxStaleness,
        uint8 assetDecimals
    )
        external
    {
        // Only the vault factory should call this
        // We use a simple check - if the strategy doesn't have a strategist, it's new
        if (_strategyMainStrategist[strategy] != address(0)) revert STRATEGIST_ALREADY_EXISTS();

        // Initialize strategy data
        _strategyPPS[strategy] = 10 ** assetDecimals; // 1.0 as initial PPS
        _strategyPPSStdev[strategy] = 0; // Initialize standard deviation to 0
        _strategyLastUpdateTimestamp[strategy] = block.timestamp;
        _strategyMinUpdateInterval[strategy] = minUpdateInterval;
        _strategyMaxStaleness[strategy] = maxStaleness;
        _strategyIsPaused[strategy] = false;
        _strategyMainStrategist[strategy] = mainStrategist;

        // Set default threshold values
        _strategyDispersionThreshold[strategy] = type(uint256).max; // Default: max (disabled)
        _strategyDeviationThreshold[strategy] = type(uint256).max; // Default: max (disabled)
        _strategyMnThreshold[strategy] = 0; // Default: 0 (disabled)

        emit PPSUpdated(strategy, _strategyPPS[strategy], 0, 0, 0, _strategyLastUpdateTimestamp[strategy]);
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultRegistry
    function depositUpkeep(address strategist, uint256 amount) external {
        if (amount == 0) revert ZERO_ADDRESS(); // Reusing error code for consistency

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Transfer UP tokens from msg.sender to this contract
        IERC20(upToken).safeTransferFrom(msg.sender, address(this), amount);

        // Update upkeep balance
        _strategistUpkeepBalance[strategist] += amount;

        emit UpkeepDeposited(strategist, amount);
    }

    /// @inheritdoc ISuperVaultRegistry
    function withdrawUpkeep(uint256 amount) external {
        if (amount == 0) revert ZERO_ADDRESS(); // Reusing error code for consistency

        // Check sufficient balance
        if (_strategistUpkeepBalance[msg.sender] < amount) {
            revert INSUFFICIENT_UPKEEP_BALANCE();
        }

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Update upkeep balance
        _strategistUpkeepBalance[msg.sender] -= amount;

        // Transfer UP tokens to strategist
        IERC20(upToken).safeTransfer(msg.sender, amount);

        emit UpkeepWithdrawn(msg.sender, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED CALLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultRegistry
    function addAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        // Either primary or secondary strategist can add authorized callers
        if (!isAnyStrategist(msg.sender, strategy)) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        if (caller == address(0)) revert ZERO_ADDRESS();

        // Check if caller is already authorized
        address[] memory callers = _strategyAuthorizedCallers[strategy];
        for (uint256 i; i < callers.length; i++) {
            if (callers[i] == caller) {
                revert CALLER_ALREADY_AUTHORIZED();
            }
        }

        _strategyAuthorizedCallers[strategy].push(caller);
        emit AuthorizedCallerAdded(strategy, caller);
    }

    /// @inheritdoc ISuperVaultRegistry
    function removeAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        // Either primary or secondary strategist can remove authorized callers
        if (!isAnyStrategist(msg.sender, strategy)) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Find and remove the caller
        address[] storage callers = _strategyAuthorizedCallers[strategy];
        bool found = false;

        for (uint256 i; i < callers.length; i++) {
            if (callers[i] == caller) {
                // Replace with the last element, then pop
                callers[i] = callers[callers.length - 1];
                callers.pop();
                found = true;
                break;
            }
        }

        if (!found) revert CALLER_NOT_AUTHORIZED();
        emit AuthorizedCallerRemoved(strategy, caller);
    }

    /*//////////////////////////////////////////////////////////////
                       STRATEGIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultRegistry
    function addSecondaryStrategist(address strategy, address strategist) external validStrategy(strategy) {
        // Only the primary strategist can add secondary strategists
        if (msg.sender != _strategyMainStrategist[strategy]) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        if (strategist == address(0)) revert ZERO_ADDRESS();

        // Check if strategist is already the primary strategist
        if (_strategyMainStrategist[strategy] == strategist) revert STRATEGIST_ALREADY_EXISTS();

        // Add as secondary strategist using EnumerableSet
        if (!_strategySecondaryStrategists[strategy].add(strategist)) revert STRATEGIST_ALREADY_EXISTS();

        emit SecondaryStrategistAdded(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultRegistry
    function removeSecondaryStrategist(address strategy, address strategist) external validStrategy(strategy) {
        // Only the primary strategist can remove secondary strategists
        if (msg.sender != _strategyMainStrategist[strategy]) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Remove the strategist using EnumerableSet
        if (!_strategySecondaryStrategists[strategy].remove(strategist)) revert STRATEGIST_NOT_FOUND();

        emit SecondaryStrategistRemoved(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultRegistry
    function updatePPSVerificationThresholds(
        address strategy,
        uint256 dispersionThreshold_,
        uint256 deviationThreshold_,
        uint256 mnThreshold_
    )
        external
        validStrategy(strategy)
    {
        // Check that caller is either the main strategist or a secondary strategist
        if (
            msg.sender != _strategyMainStrategist[strategy]
                && !_strategySecondaryStrategists[strategy].contains(msg.sender)
        ) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Update the thresholds
        _strategyDispersionThreshold[strategy] = dispersionThreshold_;
        _strategyDeviationThreshold[strategy] = deviationThreshold_;
        _strategyMnThreshold[strategy] = mnThreshold_;

        // Emit the event
        emit PPSVerificationThresholdsUpdated(strategy, dispersionThreshold_, deviationThreshold_, mnThreshold_);
    }

    /// @inheritdoc ISuperVaultRegistry
    function changePrimaryStrategist(address strategy, address newStrategist) external validStrategy(strategy) {
        // Only SuperGovernor or the SuperVaultAggregator can call this
        address aggregator = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_VAULT_AGGREGATOR());
        if (msg.sender != address(SUPER_GOVERNOR) && msg.sender != aggregator) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        if (newStrategist == address(0)) revert ZERO_ADDRESS();

        address oldStrategist = _strategyMainStrategist[strategy];

        // If new strategist is already a secondary strategist, remove them
        if (_strategySecondaryStrategists[strategy].contains(newStrategist)) {
            _strategySecondaryStrategists[strategy].remove(newStrategist);
        }

        // Make the old primary strategist a secondary strategist
        _strategySecondaryStrategists[strategy].add(oldStrategist);

        // Set the new primary strategist
        _strategyMainStrategist[strategy] = newStrategist;

        emit PrimaryStrategistChanged(strategy, oldStrategist, newStrategist);
    }

    /// @inheritdoc ISuperVaultRegistry
    function proposeChangePrimaryStrategist(address strategy, address newStrategist) external validStrategy(strategy) {
        // Only secondary strategists can propose changes to the primary strategist
        if (!_strategySecondaryStrategists[strategy].contains(msg.sender)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        if (newStrategist == address(0)) revert ZERO_ADDRESS();

        // Set up the proposal with 7-day timelock
        uint256 effectiveTime = block.timestamp + _STRATEGIST_CHANGE_TIMELOCK;

        // Store proposal in the strategy data
        _strategyProposedStrategist[strategy] = newStrategist;
        _strategyStrategistChangeEffectiveTime[strategy] = effectiveTime;

        emit PrimaryStrategistChangeProposed(strategy, msg.sender, newStrategist, effectiveTime);
    }

    /// @inheritdoc ISuperVaultRegistry
    function executeChangePrimaryStrategist(address strategy) external validStrategy(strategy) {
        // Check if there is a pending proposal
        if (_strategyProposedStrategist[strategy] == address(0)) revert NO_PENDING_STRATEGIST_CHANGE();

        // Check if the timelock period has passed
        if (block.timestamp < _strategyStrategistChangeEffectiveTime[strategy]) revert TIMELOCK_NOT_EXPIRED();

        address newStrategist = _strategyProposedStrategist[strategy];
        address oldStrategist = _strategyMainStrategist[strategy];

        // If new strategist is already a secondary strategist, remove them
        if (_strategySecondaryStrategists[strategy].contains(newStrategist)) {
            _strategySecondaryStrategists[strategy].remove(newStrategist);
        }

        // Make the old primary strategist a secondary strategist
        _strategySecondaryStrategists[strategy].add(oldStrategist);

        // Set the new primary strategist
        _strategyMainStrategist[strategy] = newStrategist;

        // Clear the proposal
        _strategyProposedStrategist[strategy] = address(0);

        emit PrimaryStrategistChanged(strategy, oldStrategist, newStrategist);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultRegistry
    function getPPS(address strategy) external view validStrategy(strategy) returns (uint256 pps) {
        return _strategyPPS[strategy];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getPPSWithStdDev(address strategy)
        external
        view
        validStrategy(strategy)
        returns (uint256 pps, uint256 ppsStdev)
    {
        return (_strategyPPS[strategy], _strategyPPSStdev[strategy]);
    }

    /// @inheritdoc ISuperVaultRegistry
    function getLastUpdateTimestamp(address strategy) external view returns (uint256 timestamp) {
        return _strategyLastUpdateTimestamp[strategy];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getMinUpdateInterval(address strategy) external view returns (uint256 interval) {
        return _strategyMinUpdateInterval[strategy];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getMaxStaleness(address strategy) external view returns (uint256 staleness) {
        return _strategyMaxStaleness[strategy];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getPPSVerificationThresholds(address strategy)
        external
        view
        validStrategy(strategy)
        returns (uint256 dispersionThreshold, uint256 deviationThreshold, uint256 mnThreshold)
    {
        return (
            _strategyDispersionThreshold[strategy],
            _strategyDeviationThreshold[strategy],
            _strategyMnThreshold[strategy]
        );
    }

    /// @inheritdoc ISuperVaultRegistry
    function isStrategyPaused(address strategy) external view returns (bool isPaused) {
        return _strategyIsPaused[strategy];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getUpkeepBalance(address strategist) external view returns (uint256 balance) {
        return _strategistUpkeepBalance[strategist];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers) {
        return _strategyAuthorizedCallers[strategy];
    }

    /// @inheritdoc ISuperVaultRegistry
    function getMainStrategist(address strategy) external view returns (address strategist) {
        strategist = _strategyMainStrategist[strategy];
        if (strategist == address(0)) revert ZERO_ADDRESS();

        return strategist;
    }

    /// @inheritdoc ISuperVaultRegistry
    function isMainStrategist(address strategist, address strategy) external view returns (bool) {
        return _strategyMainStrategist[strategy] == strategist;
    }

    /// @inheritdoc ISuperVaultRegistry
    function getSecondaryStrategists(address strategy) external view returns (address[] memory) {
        return _strategySecondaryStrategists[strategy].values();
    }

    /// @inheritdoc ISuperVaultRegistry
    function isSecondaryStrategist(address strategist, address strategy) external view returns (bool) {
        return _strategySecondaryStrategists[strategy].contains(strategist);
    }

    /// @inheritdoc ISuperVaultRegistry
    function isAnyStrategist(address strategist, address strategy) public view returns (bool) {
        // Check if primary strategist
        if (_strategyMainStrategist[strategy] == strategist) {
            return true;
        }

        // Check if secondary strategist using EnumerableSet
        return _strategySecondaryStrategists[strategy].contains(strategist);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Internal implementation of forwarding PPS updates
    /// @param args Struct containing all parameters for PPS update
    function _forwardPPS(ISuperVaultAggregator.ForwardPPSArgs memory args) internal {
        // Check rate limiting
        uint256 minInterval = _strategyMinUpdateInterval[args.strategy];
        uint256 lastUpdate = _strategyLastUpdateTimestamp[args.strategy];
        if (block.timestamp - lastUpdate < minInterval) {
            revert UPDATE_TOO_FREQUENT();
        }

        // Perform validation checks and pause/unpause strategy
        bool checksFailed = _performValidationChecks(args);
        _updateStrategyPauseStatus(args.strategy, checksFailed);

        // Handle upkeep costs
        _handleUpkeepCosts(args);

        // Update strategy data
        _updateStrategyData(args);
    }

    /// @notice Performs validation checks on PPS update
    /// @param args PPS update arguments
    /// @return checksFailed True if any validation check failed
    function _performValidationChecks(ISuperVaultAggregator.ForwardPPSArgs memory args) internal returns (bool) {
        bool checksFailed = false;

        // C2.1) Dispersion Check
        if (_strategyDispersionThreshold[args.strategy] != type(uint256).max && args.pps > 0) {
            uint256 dispersion = (args.ppsStdev * 1e18) / args.pps;
            if (dispersion > _strategyDispersionThreshold[args.strategy]) {
                checksFailed = true;
                emit StrategyCheckFailed(args.strategy, "HIGH_PPS_DISPERSION");
            }
        }

        // C2.2) Deviation Check
        uint256 currentPPS = _strategyPPS[args.strategy];
        if (_strategyDeviationThreshold[args.strategy] != type(uint256).max && currentPPS > 0) {
            uint256 absDiff = args.pps > currentPPS ? (args.pps - currentPPS) : (currentPPS - args.pps);
            uint256 relativeDeviation = (absDiff * 1e18) / currentPPS;
            if (relativeDeviation > _strategyDeviationThreshold[args.strategy]) {
                checksFailed = true;
                emit StrategyCheckFailed(args.strategy, "HIGH_PPS_DEVIATION");
            }
        }

        // C2.3) M/N Check
        if (args.totalValidators > 0 && _strategyMnThreshold[args.strategy] > 0) {
            uint256 participationRate = (args.validatorSet * 1e18) / args.totalValidators;
            if (participationRate < _strategyMnThreshold[args.strategy]) {
                checksFailed = true;
                emit StrategyCheckFailed(args.strategy, "INSUFFICIENT_VALIDATOR_PARTICIPATION");
            }
        }

        return checksFailed;
    }

    /// @notice Updates strategy pause status based on validation results
    /// @param strategy Address of the strategy
    /// @param checksFailed Whether validation checks failed
    function _updateStrategyPauseStatus(address strategy, bool checksFailed) internal {
        if (checksFailed && !_strategyIsPaused[strategy]) {
            _strategyIsPaused[strategy] = true;
            emit StrategyPaused(strategy);
        } else if (!checksFailed && _strategyIsPaused[strategy]) {
            _strategyIsPaused[strategy] = false;
            emit StrategyUnpaused(strategy);
        }
    }

    /// @notice Handles upkeep cost deduction
    /// @param args PPS update arguments
    function _handleUpkeepCosts(ISuperVaultAggregator.ForwardPPSArgs memory args) internal {
        if (!args.isExempt) {
            address strategist = _strategyMainStrategist[args.strategy];
            if (_strategistUpkeepBalance[strategist] < args.upkeepCost) {
                revert INSUFFICIENT_UPKEEP();
            }
            _strategistUpkeepBalance[strategist] -= args.upkeepCost;
            emit UpkeepSpent(strategist, args.upkeepCost);
        }
    }

    /// @notice Updates strategy data with new PPS values
    /// @param args PPS update arguments
    function _updateStrategyData(ISuperVaultAggregator.ForwardPPSArgs memory args) internal {
        _strategyPPS[args.strategy] = args.pps;
        _strategyPPSStdev[args.strategy] = args.ppsStdev;
        _strategyLastUpdateTimestamp[args.strategy] = args.timestamp;

        emit PPSUpdated(args.strategy, args.pps, args.ppsStdev, args.validatorSet, args.totalValidators, args.timestamp);
    }

    /// @notice Check if an update authority is exempt from paying upkeep costs
    /// @param strategy Address of the strategy being updated
    /// @param updateAuthority Address initiating the update
    /// @param timestamp Timestamp of the PPS measurement
    /// @return isExempt True if the authority is exempt from paying upkeep
    function _isExemptFromUpkeep(
        address strategy,
        address updateAuthority,
        uint256 timestamp
    )
        internal
        returns (bool)
    {
        // Check if upkeep payments are globally disabled in SuperGovernor
        if (!SUPER_GOVERNOR.isUpkeepPaymentsEnabled()) {
            return true;
        }

        // Update is exempt if it is stale
        if (block.timestamp - timestamp > _strategyMaxStaleness[strategy]) {
            emit StaleUpdate(strategy, updateAuthority, timestamp);
            return true;
        }

        // If strategist is a superform strategist, they're exempt from upkeep fees
        address strategist = _strategyMainStrategist[strategy];
        if (SUPER_GOVERNOR.isSuperformStrategist(strategist)) {
            return true;
        }

        // Check if the updateAuthority is in the authorized callers list
        uint256 authCallerLength = _strategyAuthorizedCallers[strategy].length;
        for (uint256 i; i < authCallerLength; i++) {
            if (_strategyAuthorizedCallers[strategy][i] == updateAuthority) {
                return true;
            }
        }

        return false;
    }
}
