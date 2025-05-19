// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.30;

// External
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import { EnumerableSet } from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { SuperVault } from "./SuperVault.sol";
import { SuperVaultStrategy } from "./SuperVaultStrategy.sol";
import { SuperVaultEscrow } from "./SuperVaultEscrow.sol";
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "../interfaces/ISuperVaultAggregator.sol";
// Libraries
import { AssetMetadataLib } from "../libraries/AssetMetadataLib.sol";

/// @title SuperVaultAggregator
/// @author Superform Labs
/// @notice Registry and PPS oracle for all SuperVaults
/// @dev Creates new SuperVault trios and manages PPS updates
contract SuperVaultAggregator is ISuperVaultAggregator {
    using AssetMetadataLib for address;
    using Clones for address;
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

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
    EnumerableSet.AddressSet private _superVaults;
    EnumerableSet.AddressSet private _superVaultStrategies;
    EnumerableSet.AddressSet private _superVaultEscrows;

    // Constant for PPS decimals
    uint256 public constant PPS_DECIMALS = 18;

    // Timelock for strategist changes and Merkle root updates
    uint256 private constant _STRATEGIST_CHANGE_TIMELOCK = 7 days;
    uint256 private constant _HOOKS_ROOT_UPDATE_TIMELOCK = 15 minutes;

    // Global hooks Merkle root data
    bytes32 private _globalHooksRoot;
    bytes32 private _proposedGlobalHooksRoot;
    uint256 private _globalHooksRootEffectiveTime;
    bool private _globalHooksRootVetoed;

    // No need for separate mappings since we now store this data in the StrategyData struct

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that msg.sender is the active PPS Oracle
    modifier onlyPPSOracle() {
        if (!SUPER_GOVERNOR.isActivePPSOracle(msg.sender)) {
            revert UNAUTHORIZED_PPS_ORACLE();
        }
        _;
    }

    /// @notice Validates that a strategy exists (has been created by this aggregator)
    modifier validStrategy(address strategy) {
        if (!_superVaultStrategies.contains(strategy)) revert UNKNOWN_STRATEGY();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperVaultAggregator
    /// @param superGovernor_ Address of the SuperGovernor contract
    constructor(address superGovernor_) {
        if (superGovernor_ == address(0)) revert ZERO_ADDRESS();

        // Deploy implementation contracts
        VAULT_IMPLEMENTATION = address(new SuperVault());
        STRATEGY_IMPLEMENTATION = address(new SuperVaultStrategy());
        ESCROW_IMPLEMENTATION = address(new SuperVaultEscrow());

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
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
            params.asset == address(0) || params.mainStrategist == address(0)
                || params.feeConfig.recipient == address(0)
        ) {
            revert ZERO_ADDRESS();
        }

        // Strategist is now handled directly within the vault creation flow
        // No need for external registration

        // Create minimal proxies
        // todo add asset as part of this @Vik
        // @dev cloneDeterministic disallows a clone to have the same name and symbol pair
        superVault = VAULT_IMPLEMENTATION.cloneDeterministic(keccak256(abi.encodePacked(params.name, params.symbol)));
        escrow = ESCROW_IMPLEMENTATION.cloneDeterministic(keccak256(abi.encodePacked(params.name, params.symbol)));
        strategy = STRATEGY_IMPLEMENTATION.cloneDeterministic(keccak256(abi.encodePacked(params.name, params.symbol)));

        // Initialize superVault
        SuperVault(superVault).initialize(params.asset, params.name, params.symbol, strategy, escrow);

        // Initialize escrow
        SuperVaultEscrow(escrow).initialize(superVault, strategy);

        // Initialize strategy
        SuperVaultStrategy(strategy).initialize(superVault, address(SUPER_GOVERNOR), params.feeConfig);

        // Store vault trio in registry
        _superVaults.add(superVault);
        _superVaultStrategies.add(strategy);
        _superVaultEscrows.add(escrow);

        (bool success, uint8 assetDecimals) = params.asset.tryGetAssetDecimals();
        uint8 underlyingDecimals = success ? assetDecimals : 18;

        // Initialize StrategyData individually to avoid mapping assignment issues
        _strategyData[strategy].pps = 10 ** underlyingDecimals; // 1.0 as initial PPS
        _strategyData[strategy].lastUpdateTimestamp = block.timestamp;
        _strategyData[strategy].minUpdateInterval = params.minUpdateInterval;
        _strategyData[strategy].maxStaleness = params.maxStaleness;
        _strategyData[strategy].isPaused = false;
        _strategyData[strategy].mainStrategist = params.mainStrategist;
        _strategyData[strategy].authorizedCallers = new address[](0);
        // Secondary strategists is handled through the AddressSet methods, not assignment

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
        // Check if the update is exempt from paying upkeep
        bool isExempt = _isExemptFromUpkeep(strategy, updateAuthority, timestamp);

        // Forward the PPS update with upkeep cost if not exempt
        _forwardPPS(strategy, isExempt, pps, timestamp, SUPER_GOVERNOR.getUpkeepCostPerUpdate());
    }

    /// @inheritdoc ISuperVaultAggregator
    function batchForwardPPS(
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

        // Calculate upkeep cost per strategy
        uint256 upkeepPerStrategy = SUPER_GOVERNOR.getUpkeepCostPerUpdate() / strategiesLength;

        // Process all valid strategies
        for (uint256 i; i < strategiesLength; i++) {
            _forwardPPS(strategies[i], false, ppss[i], timestamps[i], upkeepPerStrategy);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperVaultAggregator
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

    /// @inheritdoc ISuperVaultAggregator
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
    /// @inheritdoc ISuperVaultAggregator
    function addAuthorizedCaller(address strategy, address caller) external validStrategy(strategy) {
        // Either primary or secondary strategist can add authorized callers
        if (!isAnyStrategist(msg.sender, strategy)) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        if (caller == address(0)) revert ZERO_ADDRESS();

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
        // Either primary or secondary strategist can remove authorized callers
        if (!isAnyStrategist(msg.sender, strategy)) revert UNAUTHORIZED_UPDATE_AUTHORITY();

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
                       STRATEGIST MANAGEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultAggregator
    function addSecondaryStrategist(address strategy, address strategist) external validStrategy(strategy) {
        // Only the primary strategist can add secondary strategists
        if (msg.sender != _strategyData[strategy].mainStrategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        if (strategist == address(0)) revert ZERO_ADDRESS();

        // Check if strategist is already the primary strategist
        if (_strategyData[strategy].mainStrategist == strategist) revert STRATEGIST_ALREADY_EXISTS();

        // Add as secondary strategist using EnumerableSet
        if (!_strategyData[strategy].secondaryStrategists.add(strategist)) revert STRATEGIST_ALREADY_EXISTS();

        emit SecondaryStrategistAdded(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function removeSecondaryStrategist(address strategy, address strategist) external validStrategy(strategy) {
        // Only the primary strategist can remove secondary strategists
        if (msg.sender != _strategyData[strategy].mainStrategist) revert UNAUTHORIZED_UPDATE_AUTHORITY();

        // Remove the strategist using EnumerableSet
        if (!_strategyData[strategy].secondaryStrategists.remove(strategist)) revert STRATEGIST_NOT_FOUND();

        emit SecondaryStrategistRemoved(strategy, strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function changePrimaryStrategist(address strategy, address newStrategist) external validStrategy(strategy) {
        // Only SuperGovernor can call this
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        if (newStrategist == address(0)) revert ZERO_ADDRESS();

        address oldStrategist = _strategyData[strategy].mainStrategist;

        // If new strategist is already a secondary strategist, remove them
        if (_strategyData[strategy].secondaryStrategists.contains(newStrategist)) {
            _strategyData[strategy].secondaryStrategists.remove(newStrategist);
        }

        // Make the old primary strategist a secondary strategist
        _strategyData[strategy].secondaryStrategists.add(oldStrategist);

        // Set the new primary strategist
        _strategyData[strategy].mainStrategist = newStrategist;

        emit PrimaryStrategistChanged(strategy, oldStrategist, newStrategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeChangePrimaryStrategist(address strategy, address newStrategist) external validStrategy(strategy) {
        // Only secondary strategists can propose changes to the primary strategist
        if (!_strategyData[strategy].secondaryStrategists.contains(msg.sender)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        if (newStrategist == address(0)) revert ZERO_ADDRESS();

        // Set up the proposal with 7-day timelock
        uint256 effectiveTime = block.timestamp + _STRATEGIST_CHANGE_TIMELOCK;

        // Store proposal in the strategy data
        _strategyData[strategy].proposedStrategist = newStrategist;
        _strategyData[strategy].strategistChangeEffectiveTime = effectiveTime;
        _strategyData[strategy].strategistChangeProposer = msg.sender;

        emit PrimaryStrategistChangeProposed(strategy, msg.sender, newStrategist, effectiveTime);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeChangePrimaryStrategist(address strategy) external validStrategy(strategy) {
        // Check if there is a pending proposal
        if (_strategyData[strategy].proposedStrategist == address(0)) revert NO_PENDING_STRATEGIST_CHANGE();

        // Check if the timelock period has passed
        if (block.timestamp < _strategyData[strategy].strategistChangeEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        address newStrategist = _strategyData[strategy].proposedStrategist;
        address oldStrategist = _strategyData[strategy].mainStrategist;

        // If new strategist is already a secondary strategist, remove them
        if (_strategyData[strategy].secondaryStrategists.contains(newStrategist)) {
            _strategyData[strategy].secondaryStrategists.remove(newStrategist);
        }

        // Make the old primary strategist a secondary strategist
        _strategyData[strategy].secondaryStrategists.add(oldStrategist);

        // Set the new primary strategist
        _strategyData[strategy].mainStrategist = newStrategist;

        // Clear the proposal
        _strategyData[strategy].proposedStrategist = address(0);
        _strategyData[strategy].strategistChangeEffectiveTime = 0;
        _strategyData[strategy].strategistChangeProposer = address(0);

        emit PrimaryStrategistChanged(strategy, oldStrategist, newStrategist);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperVaultAggregator
    function proposeGlobalHooksRoot(bytes32 newRoot) external {
        // Only SUPER_GOVERNOR can update the global hooks root
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Set new root with timelock
        _proposedGlobalHooksRoot = newRoot;
        _globalHooksRootEffectiveTime = block.timestamp + _HOOKS_ROOT_UPDATE_TIMELOCK;

        emit GlobalHooksRootUpdateProposed(newRoot, _globalHooksRootEffectiveTime);
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeGlobalHooksRootUpdate() external {
        // Ensure there is a pending proposal
        if (_proposedGlobalHooksRoot == bytes32(0)) {
            revert NO_PENDING_GLOBAL_ROOT_CHANGE();
        }

        // Check if timelock period has elapsed
        if (block.timestamp < _globalHooksRootEffectiveTime) {
            revert ROOT_UPDATE_NOT_READY();
        }

        // Update the global hooks root
        bytes32 oldRoot = _globalHooksRoot;
        _globalHooksRoot = _proposedGlobalHooksRoot;
        _globalHooksRootEffectiveTime = 0;
        _proposedGlobalHooksRoot = bytes32(0);

        emit GlobalHooksRootUpdated(oldRoot, _globalHooksRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function setGlobalHooksRootVetoStatus(bool vetoed) external {
        // Only SuperGovernor can call this
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Don't emit event if status doesn't change
        if (_globalHooksRootVetoed == vetoed) {
            return;
        }

        // Update veto status
        _globalHooksRootVetoed = vetoed;

        emit GlobalHooksRootVetoStatusChanged(vetoed, _globalHooksRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) external validStrategy(strategy) {
        // Only the main strategist can propose strategy-specific hooks root
        if (_strategyData[strategy].mainStrategist != msg.sender) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Set proposed root with timelock
        _strategyData[strategy].proposedHooksRoot = newRoot;
        _strategyData[strategy].hooksRootEffectiveTime = block.timestamp + _HOOKS_ROOT_UPDATE_TIMELOCK;

        emit StrategyHooksRootUpdateProposed(
            strategy, msg.sender, newRoot, _strategyData[strategy].hooksRootEffectiveTime
        );
    }

    /// @inheritdoc ISuperVaultAggregator
    function executeStrategyHooksRootUpdate(address strategy) external validStrategy(strategy) {
        // Ensure there is a pending proposal
        if (_strategyData[strategy].proposedHooksRoot == bytes32(0)) {
            revert NO_PENDING_STRATEGIST_CHANGE(); // Reusing error for simplicity
        }

        // Check if timelock period has elapsed
        if (block.timestamp < _strategyData[strategy].hooksRootEffectiveTime) {
            revert ROOT_UPDATE_NOT_READY();
        }

        // Update the strategy's hooks root
        bytes32 oldRoot = _strategyData[strategy].strategistHooksRoot;
        _strategyData[strategy].strategistHooksRoot = _strategyData[strategy].proposedHooksRoot;

        // Reset proposal state
        _strategyData[strategy].proposedHooksRoot = bytes32(0);
        _strategyData[strategy].hooksRootEffectiveTime = 0;

        emit StrategyHooksRootUpdated(strategy, oldRoot, _strategyData[strategy].strategistHooksRoot);
    }

    /// @inheritdoc ISuperVaultAggregator
    function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) external validStrategy(strategy) {
        // Only SuperGovernor can call this
        if (msg.sender != address(SUPER_GOVERNOR)) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Don't emit event if status doesn't change
        if (_strategyData[strategy].hooksRootVetoed == vetoed) {
            return;
        }

        // Update veto status
        _strategyData[strategy].hooksRootVetoed = vetoed;

        emit StrategyHooksRootVetoStatusChanged(strategy, vetoed, _strategyData[strategy].strategistHooksRoot);
    }
    /// @inheritdoc ISuperVaultAggregator

    function isGlobalHooksRootVetoed() external view returns (bool vetoed) {
        return _globalHooksRootVetoed;
    }

    /// @inheritdoc ISuperVaultAggregator
    function isStrategyHooksRootVetoed(address strategy) external view returns (bool vetoed) {
        return _strategyData[strategy].hooksRootVetoed;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    function getUpkeepBalance(address strategist) external view returns (uint256 balance) {
        return _strategistUpkeepBalance[strategist];
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAuthorizedCallers(address strategy) external view returns (address[] memory callers) {
        return _strategyData[strategy].authorizedCallers;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getMainStrategist(address strategy) external view returns (address strategist) {
        strategist = _strategyData[strategy].mainStrategist;
        if (strategist == address(0)) revert ZERO_ADDRESS();

        return strategist;
    }

    /// @inheritdoc ISuperVaultAggregator
    function isMainStrategist(address strategist, address strategy) external view returns (bool) {
        return _strategyData[strategy].mainStrategist == strategist;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getSecondaryStrategists(address strategy) external view returns (address[] memory) {
        return _strategyData[strategy].secondaryStrategists.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function isSecondaryStrategist(address strategist, address strategy) external view returns (bool) {
        return _strategyData[strategy].secondaryStrategists.contains(strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function isAnyStrategist(address strategist, address strategy) public view returns (bool) {
        // Check if primary strategist
        if (_strategyData[strategy].mainStrategist == strategist) {
            return true;
        }

        // Check if secondary strategist using EnumerableSet
        return _strategyData[strategy].secondaryStrategists.contains(strategist);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaults() external view returns (address[] memory) {
        return _superVaults.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaults(uint256 index) external view returns (address) {
        if (index >= _superVaults.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaults.at(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaultStrategies() external view returns (address[] memory) {
        return _superVaultStrategies.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaultStrategies(uint256 index) external view returns (address) {
        if (index >= _superVaultStrategies.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaultStrategies.at(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getAllSuperVaultEscrows() external view returns (address[] memory) {
        return _superVaultEscrows.values();
    }

    /// @inheritdoc ISuperVaultAggregator
    function superVaultEscrows(uint256 index) external view returns (address) {
        if (index >= _superVaultEscrows.length()) revert INDEX_OUT_OF_BOUNDS();
        return _superVaultEscrows.at(index);
    }

    /// @inheritdoc ISuperVaultAggregator
    function validateHook(
        address strategy,
        bytes calldata hookArgs,
        bytes32[] calldata globalProof,
        bytes32[] calldata strategyProof
    )
        external
        view
        returns (bool isValid)
    {
        // If both roots are vetoed, all hook validations fail
        bool globalHooksVetoed = _globalHooksRootVetoed;
        bool strategyHooksVetoed = _strategyData[strategy].hooksRootVetoed;
        if (globalHooksVetoed && strategyHooksVetoed) {
            return false;
        }

        return
            _validateSingleHook(strategy, hookArgs, globalProof, strategyProof, globalHooksVetoed, strategyHooksVetoed);
    }

    /// @inheritdoc ISuperVaultAggregator
    function validateHooks(
        address strategy,
        bytes[] calldata hooksArgs,
        bytes32[][] calldata globalProofs,
        bytes32[][] calldata strategyProofs
    )
        external
        view
        returns (bool[] memory validHooks)
    {
        uint256 length = hooksArgs.length;

        // Ensure array lengths match
        if (globalProofs.length != length || strategyProofs.length != length) {
            revert INVALID_ARRAY_LENGTH();
        }

        // Get veto statuses only once
        bool globalHooksVetoed = _globalHooksRootVetoed;
        bool strategyHooksVetoed = _strategyData[strategy].hooksRootVetoed;

        // If both roots are vetoed, all hooks are invalid
        if (globalHooksVetoed && strategyHooksVetoed) {
            validHooks = new bool[](length);
            // All values default to false in Solidity, so no need to set them
            return validHooks;
        }

        // Validate each hook
        validHooks = new bool[](length);
        for (uint256 i; i < length; i++) {
            validHooks[i] = _validateSingleHook(
                strategy, hooksArgs[i], globalProofs[i], strategyProofs[i], globalHooksVetoed, strategyHooksVetoed
            );
        }

        return validHooks;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getGlobalHooksRoot() external view returns (bytes32 root) {
        return _globalHooksRoot;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getProposedGlobalHooksRoot() external view returns (bytes32 root, uint256 effectiveTime) {
        return (_proposedGlobalHooksRoot, _globalHooksRootEffectiveTime);
    }

    /// @notice Checks if the global hooks root is active (timelock period has passed)
    /// @return isActive True if the global hooks root is active
    function isGlobalHooksRootActive() external view returns (bool) {
        return block.timestamp >= _globalHooksRootEffectiveTime && _globalHooksRoot != bytes32(0);
    }

    /// @inheritdoc ISuperVaultAggregator
    function getStrategyHooksRoot(address strategy) external view returns (bytes32 root) {
        return _strategyData[strategy].strategistHooksRoot;
    }

    /// @inheritdoc ISuperVaultAggregator
    function getProposedStrategyHooksRoot(address strategy)
        external
        view
        returns (bytes32 root, uint256 effectiveTime)
    {
        return (_strategyData[strategy].proposedHooksRoot, _strategyData[strategy].hooksRootEffectiveTime);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        address strategist = _strategyData[strategy].mainStrategist;

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
        if (block.timestamp - timestamp > _strategyData[strategy].maxStaleness) {
            emit StaleUpdate(strategy, updateAuthority, timestamp);
            return true;
        }

        // If strategist is a superform strategist, they're exempt from upkeep fees
        address strategist = _strategyData[strategy].mainStrategist;
        if (SUPER_GOVERNOR.isSuperformStrategist(strategist)) {
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

    /// @notice Creates a leaf node for Merkle verification from hook arguments
    /// @param hookArgs The packed-encoded hook arguments (from solidityPack in JS)
    /// @return leaf The leaf node hash
    function _createLeaf(bytes calldata hookArgs) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(hookArgs))));
    }

    /**
     * @dev Internal function to validate a single hook
     * @param strategy Address of the strategy
     * @param hookArgs Hook arguments
     * @param globalProof Merkle proof for global root
     * @param strategyProof Merkle proof for strategy root
     * @param globalVetoed Whether global hooks are vetoed
     * @param strategyVetoed Whether strategy hooks are vetoed
     * @return True if hook is valid, false otherwise
     */
    function _validateSingleHook(
        address strategy,
        bytes calldata hookArgs,
        bytes32[] calldata globalProof,
        bytes32[] calldata strategyProof,
        bool globalVetoed,
        bool strategyVetoed
    )
        internal
        view
        returns (bool)
    {
        uint256 lengthGlobalProof = globalProof.length;
        uint256 lengthStrategyProof = strategyProof.length;

        // If both proofs are empty, the hook is not allowed
        if (lengthGlobalProof == 0 && lengthStrategyProof == 0) {
            return false;
        }

        // Create leaf node from the hook arguments
        bytes32 leaf = _createLeaf(hookArgs);

        // First try to verify against the global root if provided
        if (lengthGlobalProof > 0 && !globalVetoed) {
            // Only validate against global root if it exists
            if (_globalHooksRoot != bytes32(0) && MerkleProof.verify(globalProof, _globalHooksRoot, leaf)) {
                return true;
            }
        }

        // Then try to verify against the strategy-specific root if provided
        if (lengthStrategyProof > 0 && !strategyVetoed) {
            bytes32 strategyRoot = _strategyData[strategy].strategistHooksRoot;
            if (strategyRoot != bytes32(0) && MerkleProof.verify(strategyProof, strategyRoot, leaf)) {
                return true;
            }
        }

        // If we get here, verification failed
        return false;
    }
}
