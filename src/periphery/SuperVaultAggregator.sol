// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

// Superform
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperGovernor } from "./interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "./interfaces/ISuperVaultAggregator.sol";

/// @title SuperVaultAggregator
/// @author SuperForm Labs
/// @notice Registry and PPS oracle for all SuperVaults
/// @dev Creates new SuperVault trios and manages PPS updates
contract SuperVaultAggregator is ISuperVaultAggregator {
    using Clones for address;
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Vault implementation contracts
    address public immutable VAULT_IMPLEMENTATION;
    address public immutable STRATEGY_IMPLEMENTATION;
    address public immutable ESCROW_IMPLEMENTATION;

    // Governance
    ISuperGovernor public immutable SUPER_GOVERNOR;

    // Strategy data storage
    mapping(address strategy => StrategyData) private _strategyData;

    // Upkeep balances
    mapping(address strategist => uint256 upkeep) private _strategistUpkeepBalance;

    // Registry of created vaults
    address[] public superVaults;
    address[] public superVaultStrategies;
    address[] public superVaultEscrows;

    // Constant for PPS decimals
    uint256 public constant PPS_DECIMALS = 18;

    // Upkeep cost per update
    uint256 public upkeepCostPerUpdate;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperVaultAggregator
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param upkeepCostPerUpdate_ Cost in UP tokens per PPS update
    constructor(address superGovernor_, uint256 upkeepCostPerUpdate_) {
        if (superGovernor_ == address(0)) revert ZERO_ADDRESS();

        // Deploy implementation contracts
        VAULT_IMPLEMENTATION = address(new SuperVault());
        STRATEGY_IMPLEMENTATION = address(new SuperVaultStrategy());
        ESCROW_IMPLEMENTATION = address(new SuperVaultEscrow());

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
        upkeepCostPerUpdate = upkeepCostPerUpdate_;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that msg.sender is a registered PPS Oracle
    modifier onlyPPSOracle() {
        if (!SUPER_GOVERNOR.isPPSOracle(msg.sender)) {
            revert UNAUTHORIZED_PPS_ORACLE();
        }
        _;
    }

    /// @notice Validates that a strategy exists (has been created by this aggregator)
    modifier validStrategy(address strategy) {
        bool found = false;
        uint256 length = superVaultStrategies.length;
        for (uint256 i; i < length; i++) {
            if (superVaultStrategies[i] == strategy) {
                found = true;
                break;
            }
        }
        if (!found) revert UNKNOWN_STRATEGY();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            VAULT CREATION
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function createVault(VaultCreationParams calldata params)
        external
        returns (address superVault, address strategy, address escrow)
    {
        // Input validation
        if (
            params.asset == address(0) || params.manager == address(0) || params.strategist == address(0)
                || params.emergencyAdmin == address(0) || params.feeRecipient == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        // Ensure strategist is registered
        if (!SUPER_GOVERNOR.isStrategist(params.strategist)) {
            revert STRATEGIST_NOT_REGISTERED();
        }

        // Create minimal proxies
        superVault = VAULT_IMPLEMENTATION.clone();
        escrow = ESCROW_IMPLEMENTATION.clone();
        strategy = STRATEGY_IMPLEMENTATION.clone();

        // Initialize superVault
        SuperVault(superVault).initialize(params.asset, params.name, params.symbol, strategy, escrow);

        // Initialize escrow
        SuperVaultEscrow(escrow).initialize(superVault, strategy);

        // Initialize strategy
        SuperVaultStrategy(strategy).initialize(
            superVault,
            params.manager,
            params.strategist,
            params.emergencyAdmin,
            address(SUPER_GOVERNOR),
            params.superVaultCap
        );

        // Store vault trio in registry
        superVaults.push(superVault);
        superVaultStrategies.push(strategy);
        superVaultEscrows.push(escrow);

        // Initialize StrategyData
        _strategyData[strategy] = StrategyData({
            pps: 10 ** PPS_DECIMALS, // 1.0 as initial PPS
            lastUpdateTimestamp: block.timestamp,
            minUpdateInterval: params.minUpdateInterval,
            maxStaleness: params.maxStaleness,
            isPaused: false,
            strategist: params.strategist,
            authorizedCallers: new address[](0)
        });

        emit VaultDeployed(superVault, strategy, escrow, params.asset, params.name, params.symbol);
        emit PPSUpdated(strategy, _strategyData[strategy].pps, _strategyData[strategy].lastUpdateTimestamp);

        return (superVault, strategy, escrow);
    }

    /*//////////////////////////////////////////////////////////////
                          PPS UPDATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function forwardPPS(
        address updateAuthority,
        address strategy,
        uint256 pps,
        uint256 timestamp
    )
        external
        onlyPPSOracle
        validStrategy(strategy)
    {
        // Check if the authority is exempt from paying upkeep
        bool isExempt = _isExemptFromUpkeep(strategy, updateAuthority, timestamp);

        // Pass the full upkeep cost for single updates
        _forwardPPS(strategy, isExempt, pps, timestamp, upkeepCostPerUpdate);
    }

    /// @inheritdoc ISuperVaultAggregator
    function batchForwardPPS(
        address updateAuthority,
        address[] calldata strategies,
        uint256[] calldata ppss,
        uint256[] calldata timestamps
    )
        external
        onlyPPSOracle
    {
        // Check array lengths
        if (strategies.length != ppss.length || strategies.length != timestamps.length) {
            revert ARRAY_LENGTH_MISMATCH();
        }

        uint256 strategiesLength = strategies.length;
        if (strategiesLength == 0) revert ZERO_ARRAY_LENGTH();

        // First, identify valid strategies and check exemption status
        bool[] memory exemptStatus = new bool[](strategiesLength);
        uint256 nonExemptCount = 0;

        for (uint256 i; i < strategiesLength; i++) {
            // Check if exempt from upkeep
            bool isExempt = _isExemptFromUpkeep(strategies[i], updateAuthority, timestamps[i]);
            exemptStatus[i] = isExempt;

            if (!isExempt) {
                nonExemptCount++;
            }
        }

        // Calculate upkeep cost per non-exempt strategy
        uint256 upkeepPerStrategy = nonExemptCount > 0 ? upkeepCostPerUpdate / nonExemptCount : 0;

        // Process all valid strategies
        for (uint256 i; i < strategiesLength; i++) {
            _forwardPPS(strategies[i], exemptStatus[i], ppss[i], timestamps[i], upkeepPerStrategy);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function depositUpkeep(address strategist, uint256 amount) external {
        if (!SUPER_GOVERNOR.isStrategist(strategist)) revert STRATEGIST_NOT_REGISTERED();
        if (amount == 0) revert ZERO_ADDRESS(); // Reusing error code for consistency

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Transfer UP tokens from msg.sender to this contract
        IERC20(upToken).safeTransferFrom(msg.sender, address(this), amount);

        // Update upkeep balance
        _strategistUpkeepBalance[strategist] += amount;

        emit UpkeepDeposited(strategist, amount);
    }

    /// @inheritdoc ISuperVaultAggregator
    function withdrawUpkeep(address strategist, uint256 amount) external {
        // Only the strategist can withdraw their own upkeep
        if (msg.sender != strategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();
        if (amount == 0) revert ZERO_ADDRESS(); // Reusing error code for consistency

        // Check sufficient balance
        if (_strategistUpkeepBalance[strategist] < amount) {
            revert INSUFFICIENT_UPKEEP_BALANCE();
        }

        // Get the UP token address from SUPER_GOVERNOR
        address upToken = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.UP());

        // Update upkeep balance
        _strategistUpkeepBalance[strategist] -= amount;

        // Transfer UP tokens to strategist
        IERC20(upToken).safeTransfer(strategist, amount);

        emit UpkeepWithdrawn(strategist, amount);
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZED CALLER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function addAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        address strategist = _strategyData[strategy].strategist;
        if (msg.sender != strategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Check if caller is already authorized
        address[] memory callers = _strategyData[strategy].authorizedCallers;
        for (uint256 i; i < callers.length; i++) {
            if (callers[i] == caller) {
                revert CALLER_ALREADY_AUTHORIZED();
            }
        }

        _strategyData[strategy].authorizedCallers.push(caller);
        emit AuthorizedCallerAdded(strategy, caller);
    }

    /// @inheritdoc ISuperVaultAggregator
    function removeAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        address strategist = _strategyData[strategy].strategist;
        if (msg.sender != strategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Find and remove the caller
        address[] storage callers = _strategyData[strategy].authorizedCallers;
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
                         INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
        view
        returns (bool)
    {
        // Update is exempt if it is stale
        if (block.timestamp - timestamp > _strategyData[strategy].maxStaleness) {
            return true;
        }

        // Check if the updateAuthority is in the authorized callers list
        uint256 authCallerLength = _strategyData[strategy].authorizedCallers.length;
        for (uint256 i; i < authCallerLength; i++) {
            if (_strategyData[strategy].authorizedCallers[i] == updateAuthority) {
                return true;
            }
        }

        return false;
    }

    /// @notice Internal implementation of forwarding PPS updates
    /// @param strategy Address of the strategy being updated
    /// @param isExempt Whether the update is exempt from paying upkeep
    /// @param pps New PPS value
    /// @param timestamp Timestamp of the PPS measurement
    /// @param upkeepCost The amount of upkeep to charge (if not exempt)
    function _forwardPPS(
        address strategy,
        bool isExempt,
        uint256 pps,
        uint256 timestamp,
        uint256 upkeepCost
    )
        internal
    {
        // Check rate limiting
        uint256 minInterval = _strategyData[strategy].minUpdateInterval;
        uint256 lastUpdate = _strategyData[strategy].lastUpdateTimestamp;
        if (block.timestamp - lastUpdate < minInterval) {
            revert UPDATE_TOO_FREQUENT();
        }

        // Get the strategy's strategist to deduct upkeep cost from
        address strategist = _strategyData[strategy].strategist;

        // If not exempt, deduct upkeep from strategist's balance
        if (!isExempt) {
            if (_strategistUpkeepBalance[strategist] < upkeepCost) {
                revert INSUFFICIENT_UPKEEP();
            }

            _strategistUpkeepBalance[strategist] -= upkeepCost;
            emit UpkeepSpent(strategist, upkeepCost);
        }

        // Update PPS and timestamp in StrategyData
        _strategyData[strategy].pps = pps;
        _strategyData[strategy].lastUpdateTimestamp = timestamp;

        emit PPSUpdated(strategy, pps, timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
    function getStrategyData(address strategy) external view returns (StrategyData memory data) {
        return _strategyData[strategy];
    }

    /// @inheritdoc ISuperVaultAggregator
    function getPPS(address strategy) external view returns (uint256 pps) {
        return _strategyData[strategy].pps;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getLastUpdateTimestamp(address strategy) external view returns (uint256 timestamp) {
        return _strategyData[strategy].lastUpdateTimestamp;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMinUpdateInterval(address strategy) external view returns (uint256 interval) {
        return _strategyData[strategy].minUpdateInterval;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMaxStaleness(address strategy) external view returns (uint256 staleness) {
        return _strategyData[strategy].maxStaleness;
    }

    /// @inheritdoc ISuperVaultAggregator
    function isStrategyPaused(address strategy) external view returns (bool isPaused) {
        return _strategyData[strategy].isPaused;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers) {
        return _strategyData[strategy].authorizedCallers;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getUpkeepBalance(address strategist) external view returns (uint256 balance) {
        return _strategistUpkeepBalance[strategist];
    }

    /// @notice Gets all created SuperVaults
    /// @return Array of SuperVault addresses
    function getAllSuperVaults() external view returns (address[] memory) {
        return superVaults;
    }

    /// @notice Gets all created SuperVaultStrategies
    /// @return Array of SuperVaultStrategy addresses
    function getAllSuperVaultStrategies() external view returns (address[] memory) {
        return superVaultStrategies;
    }

    /// @notice Gets all created SuperVaultEscrows
    /// @return Array of SuperVaultEscrow addresses
    function getAllSuperVaultEscrows() external view returns (address[] memory) {
        return superVaultEscrows;
    }
}
