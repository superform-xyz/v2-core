// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import {ISuperGovernor, FeeType} from "./interfaces/ISuperGovernor.sol";
import {ISuperVaultAggregator} from "./interfaces/ISuperVaultAggregator.sol";

/// @title SuperGovernor
/// @author Superform Labs
/// @notice Central registry for all deployed contracts in the Superform periphery
contract SuperGovernor is ISuperGovernor, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Address registry
    mapping(bytes32 id => address address_) private _addressRegistry;

    // PPS Oracle management
    // Active PPS Oracle quorum requirement
    uint256 private _activePPSOracleQuorum;
    // Current active PPS Oracle
    address private _activePPSOracle;
    // Proposed new active PPS Oracle
    address private _proposedActivePPSOracle;
    // Effective time for proposed active PPS Oracle change
    uint256 private _activePPSOracleEffectiveTime;

    // Hook registry
    EnumerableSet.AddressSet private _registeredHooks;
    EnumerableSet.AddressSet private _registeredFulfillRequestsHooks;

    // SuperBank Hook Target validation
    mapping(address hook => ISuperGovernor.HookMerkleRootData merkleData) private superBankHooksMerkleRoots;

    // VaultBank Hook Target validation
    mapping(address hook => ISuperGovernor.HookMerkleRootData merkleData) private vaultBankHooksMerkleRoots;

    // Global freeze for strategist takeovers
    bool private _strategistTakeoversFrozen;

    // Validator registry
    mapping(address validator => bool isValidator) private _isValidator;
    address[] private _validatorsList;

    // Relayer registry
    mapping(address relayer => bool isRelayer) private _isRelayer;
    address[] private _relayersList;

    // Executor registry
    mapping(address executor => bool isExecutor) private _isExecutor;
    address[] private _executorsList;

    // Polymer prover
    address private _prover;

    // Fee management
    // Current fee values
    mapping(FeeType => uint256) private _feeValues;
    // Proposed fee values
    mapping(FeeType => uint256) private _proposedFeeValues;
    // Effective times for proposed fee updates
    mapping(FeeType => uint256) private _feeEffectiveTimes;

    // Upkeep cost per update for PPS updates
    uint256 private _upkeepCostPerUpdate;
    // Proposed new upkeep cost
    uint256 private _proposedUpkeepCostPerUpdate;
    // Effective time for proposed upkeep cost change
    uint256 private _upkeepCostEffectiveTime;

    // Upkeep control
    bool private _upkeepPaymentsEnabled;
    bool private _proposedUpkeepPaymentsEnabled;
    uint256 private _upkeepPaymentsChangeEffectiveTime;

    // Superform strategists (exempt from upkeep costs)
    EnumerableSet.AddressSet private _superformStrategists;

    // Timelock configuration
    uint256 private constant TIMELOCK = 7 days;
    uint256 private constant BPS_MAX = 10_000; // 100% in basis points

    // Role definitions
    bytes32 private constant _SUPER_GOVERNOR_ROLE = keccak256("SUPER_GOVERNOR_ROLE");
    bytes32 private constant _GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 private constant _BANK_MANAGER_ROLE = keccak256("BANK_MANAGER_ROLE");
    bytes32 private constant _GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant _SUPER_ASSET_FACTORY = keccak256("SUPER_ASSET_FACTORY");


    // Common contract keys
    bytes32 public constant TREASURY = keccak256("TREASURY");
    bytes32 public constant SUPER_ORACLE = keccak256("SUPER_ORACLE");
    bytes32 public constant BLSPPSORACLE = keccak256("BLSPPSORACLE");
    bytes32 public constant ECDSAPPSORACLE = keccak256("ECDSAPPSORACLE");
    bytes32 public constant SUPER_VAULT_AGGREGATOR = keccak256("SUPER_VAULT_AGGREGATOR");
    bytes32 public constant UP = keccak256("UP");
    bytes32 public constant SUP = keccak256("SUP");
    bytes32 public constant SUPER_BANK = keccak256("SUPER_BANK");
    bytes32 public constant BANK_MANAGER = keccak256("BANK_MANAGER");



    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    // todo add aggregator here?
    /// @notice Initializes the SuperGovernor contract
    /// @param superGovernor Address of the default admin (will have SUPER_GOVERNOR_ROLE)
    /// @param governor Address that will have the GOVERNOR_ROLE for daily operations
    /// @param bankManager Address that will have the BANK_MANAGER_ROLE for daily operations
    /// @param treasury_ Address of the treasury
    /// @param prover_ Address of the prover
    constructor(address superGovernor, address governor, address bankManager, address treasury_, address prover_) {
        if (
            superGovernor == address(0) || treasury_ == address(0) || governor == address(0)
                || bankManager == address(0)
        ) revert INVALID_ADDRESS();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, superGovernor);
        _grantRole(_SUPER_GOVERNOR_ROLE, superGovernor);
        _grantRole(_GOVERNOR_ROLE, governor);
        _grantRole(_BANK_MANAGER_ROLE, bankManager);
        // Setup GUARDIAN_ROLE without assigning any address
        _setRoleAdmin(_GUARDIAN_ROLE, DEFAULT_ADMIN_ROLE);

        // Set role admins
        _setRoleAdmin(_GOVERNOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(_SUPER_GOVERNOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(_BANK_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);

        // Initialize with default fees
        _feeValues[FeeType.REVENUE_SHARE] = 2000; // 20% revenue share
        _feeValues[FeeType.SUPER_VAULT_PERFORMANCE_FEE] = 2000; // 20% performance fee
        _feeValues[FeeType.SUPER_ASSET_SWAP_FEE] = 4000; // 40% swap fee
        emit FeeUpdated(FeeType.REVENUE_SHARE, _feeValues[FeeType.REVENUE_SHARE]);
        emit FeeUpdated(FeeType.SUPER_VAULT_PERFORMANCE_FEE, _feeValues[FeeType.SUPER_VAULT_PERFORMANCE_FEE]);
        emit FeeUpdated(FeeType.SUPER_ASSET_SWAP_FEE, _feeValues[FeeType.SUPER_ASSET_SWAP_FEE]);

        // Set treasury in address registry
        _addressRegistry[TREASURY] = treasury_;
        emit AddressSet(TREASURY, treasury_);

        // Initialize upkeep cost
        _upkeepCostPerUpdate = 1e18; // 1 UP token

        emit UpkeepCostPerUpdateChanged(_upkeepCostPerUpdate);

        // Initialize prover
        _prover = prover_;
        emit ProverSet(prover_);
    }
    /*//////////////////////////////////////////////////////////////
                       CONTRACT REGISTRY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGovernor
    function setAddress(bytes32 key, address value) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (value == address(0)) revert INVALID_ADDRESS();

        _addressRegistry[key] = value;
        emit AddressSet(key, value);
    }

    /*//////////////////////////////////////////////////////////////
                        PROVER
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function setProver(address prover_) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (prover_ == address(0)) revert INVALID_ADDRESS();

        _prover = prover_;
        emit ProverSet(prover_);
    }

    /*//////////////////////////////////////////////////////////////
                        SUPER VAULT AGGREGATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGovernor
    function changePrimaryStrategist(address strategy_, address newStrategist_)
        external
        onlyRole(_SUPER_GOVERNOR_ROLE)
    {
        // Check if takeovers are globally frozen
        if (_strategistTakeoversFrozen) revert STRATEGIST_TAKEOVERS_FROZEN();

        if (strategy_ == address(0) || newStrategist_ == address(0)) revert INVALID_ADDRESS();

        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        // Call the interface method to change the strategist
        // This function can only be called by the SuperGovernor and bypasses the timelock
        ISuperVaultAggregator(aggregator).changePrimaryStrategist(strategy_, newStrategist_);
    }

    /// @notice Proposes a new global hooks Merkle root in the SuperVaultAggregator
    /// @dev Only callable by GOVERNOR_ROLE
    /// @param newRoot New Merkle root for global hooks validation
    function proposeGlobalHooksRoot(bytes32 newRoot) external onlyRole(_GOVERNOR_ROLE) {
        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperVaultAggregator(aggregator).proposeGlobalHooksRoot(newRoot);
    }

    /// @notice Sets veto status for the global hooks Merkle root
    /// @dev Only callable by GUARDIAN_ROLE
    /// @param vetoed_ Whether to veto (true) or unveto (false) the global hooks root
    function setGlobalHooksRootVetoStatus(bool vetoed_) external onlyRole(_GUARDIAN_ROLE) {
        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperVaultAggregator(aggregator).setGlobalHooksRootVetoStatus(vetoed_);
    }

    /// @notice Sets veto status for a strategy-specific hooks Merkle root
    /// @dev Only callable by GUARDIAN_ROLE
    /// @param strategy_ Address of the strategy to affect
    /// @param vetoed_ Whether to veto (true) or unveto (false) the strategy hooks root
    function setStrategyHooksRootVetoStatus(address strategy_, bool vetoed_) external onlyRole(_GUARDIAN_ROLE) {
        if (strategy_ == address(0)) revert INVALID_ADDRESS();

        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperVaultAggregator(aggregator).setStrategyHooksRootVetoStatus(strategy_, vetoed_);
    }

    /// @inheritdoc ISuperGovernor
    function freezeStrategistTakeover() external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (_strategistTakeoversFrozen) revert STRATEGIST_TAKEOVERS_FROZEN();

        // Set frozen status to true (permanent, cannot be undone)
        _strategistTakeoversFrozen = true;

        // Emit event for the frozen status
        emit StrategistTakeoversFrozen();
    }

    /*//////////////////////////////////////////////////////////////
                         HOOK MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function registerHook(address hook_, bool isFulfillRequestsHook_) external onlyRole(_GOVERNOR_ROLE) {
        if (hook_ == address(0)) revert INVALID_ADDRESS();

        if (isFulfillRequestsHook_) {
            if (_registeredFulfillRequestsHooks.contains(hook_)) {
                revert FULFILL_REQUESTS_HOOK_ALREADY_REGISTERED();
            }

            _registeredFulfillRequestsHooks.add(hook_);
            emit FulfillRequestsHookRegistered(hook_);
        }
        if (_registeredHooks.contains(hook_)) {
            revert HOOK_ALREADY_APPROVED();
        }
        _registeredHooks.add(hook_);
        emit HookApproved(hook_);
    }

    /// @inheritdoc ISuperGovernor
    function unregisterHook(address hook_, bool isFulfillRequestsHook_) external onlyRole(_GOVERNOR_ROLE) {
        if (isFulfillRequestsHook_) {
            _unregisterFulfillRequestsHook(hook_);
        } else {
            _unregisterRegularHook(hook_);
        }
    }

    /*//////////////////////////////////////////////////////////////
                      EXECUTORS MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addExecutor(address executor_) external onlyRole(_GOVERNOR_ROLE) {
        if (executor_ == address(0)) revert INVALID_ADDRESS();
        if (_isExecutor[executor_]) revert EXECUTOR_ALREADY_REGISTERED();

        _isExecutor[executor_] = true;
        _executorsList.push(executor_);
        emit ExecutorAdded(executor_);
    }

    /// @inheritdoc ISuperGovernor
    function removeExecutor(address executor_) external onlyRole(_GOVERNOR_ROLE) {
        if (!_isExecutor[executor_]) revert EXECUTOR_NOT_REGISTERED();

        _isExecutor[executor_] = false;

        // Remove from executors array
        uint256 length = _executorsList.length;
        for (uint256 i; i < length; i++) {
            if (_executorsList[i] == executor_) {
                _executorsList[i] = _executorsList[_executorsList.length - 1];
                _executorsList.pop();
                break;
            }
        }

        emit ExecutorRemoved(executor_);
    }

    /*//////////////////////////////////////////////////////////////
                      RELAYER MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addRelayer(address relayer_) external onlyRole(_GOVERNOR_ROLE) {
        if (relayer_ == address(0)) revert INVALID_ADDRESS();
        if (_isRelayer[relayer_]) revert RELAYER_ALREADY_REGISTERED();

        _isRelayer[relayer_] = true;
        _relayersList.push(relayer_);
        emit RelayerAdded(relayer_);
    }

    /// @inheritdoc ISuperGovernor
    function removeRelayer(address relayer_) external onlyRole(_GOVERNOR_ROLE) {
        if (!_isRelayer[relayer_]) revert RELAYER_NOT_REGISTERED();

        _isRelayer[relayer_] = false;

        // Remove from relayers array
        uint256 length = _relayersList.length;
        for (uint256 i; i < length; i++) {
            if (_relayersList[i] == relayer_) {
                _relayersList[i] = _relayersList[_relayersList.length - 1];
                _relayersList.pop();
                break;
            }
        }

        emit RelayerRemoved(relayer_);
    }

    /*//////////////////////////////////////////////////////////////
                      VALIDATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addValidator(address validator) external onlyRole(_GOVERNOR_ROLE) {
        if (validator == address(0)) revert INVALID_ADDRESS();
        if (_isValidator[validator]) revert VALIDATOR_ALREADY_REGISTERED();

        _isValidator[validator] = true;
        _validatorsList.push(validator);
        emit ValidatorAdded(validator);
    }

    /// @inheritdoc ISuperGovernor
    function removeValidator(address validator) external onlyRole(_GOVERNOR_ROLE) {
        if (!_isValidator[validator]) revert VALIDATOR_NOT_REGISTERED();

        _isValidator[validator] = false;

        // Remove from validators array
        uint256 length = _validatorsList.length;
        for (uint256 i; i < length; i++) {
            if (_validatorsList[i] == validator) {
                _validatorsList[i] = _validatorsList[_validatorsList.length - 1];
                _validatorsList.pop();
                break;
            }
        }

        emit ValidatorRemoved(validator);
    }

    /*//////////////////////////////////////////////////////////////
                       PPS ORACLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function setActivePPSOracle(address oracle) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (oracle == address(0)) revert INVALID_ADDRESS();

        // If this is the first oracle or replacing a zero oracle, set it immediately
        if (_activePPSOracle == address(0)) {
            _activePPSOracle = oracle;
            emit ActivePPSOracleSet(oracle);
        } else {
            // Otherwise require the timelock process
            revert MUST_USE_TIMELOCK_FOR_CHANGE();
        }
    }

    /// @inheritdoc ISuperGovernor
    function proposeActivePPSOracle(address oracle) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (oracle == address(0)) revert INVALID_ADDRESS();

        _proposedActivePPSOracle = oracle;
        _activePPSOracleEffectiveTime = block.timestamp + TIMELOCK;

        emit ActivePPSOracleProposed(oracle, _activePPSOracleEffectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function executeActivePPSOracleChange() external {
        if (_proposedActivePPSOracle == address(0)) revert NO_PROPOSED_PPS_ORACLE();

        if (block.timestamp < _activePPSOracleEffectiveTime) {
            revert TIMELOCK_NOT_EXPIRED();
        }

        address oldOracle = _activePPSOracle;
        _activePPSOracle = _proposedActivePPSOracle;

        // Reset proposal data
        _proposedActivePPSOracle = address(0);
        _activePPSOracleEffectiveTime = 0;

        emit ActivePPSOracleChanged(oldOracle, _activePPSOracle);
    }

    /// @inheritdoc ISuperGovernor
    function setPPSOracleQuorum(uint256 quorum) external onlyRole(_GOVERNOR_ROLE) {
        if (quorum == 0) revert INVALID_QUORUM();

        _activePPSOracleQuorum = quorum;
        emit PPSOracleQuorumUpdated(quorum);
    }

    /*//////////////////////////////////////////////////////////////
                      REVENUE SHARE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function proposeFee(FeeType feeType, uint256 value) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (value > BPS_MAX) revert INVALID_FEE_VALUE();

        _proposedFeeValues[feeType] = value;
        _feeEffectiveTimes[feeType] = block.timestamp + TIMELOCK;

        emit FeeProposed(feeType, value, _feeEffectiveTimes[feeType]);
    }

    /// @inheritdoc ISuperGovernor
    function executeFeeUpdate(FeeType feeType) external {
        uint256 effectiveTime = _feeEffectiveTimes[feeType];
        if (effectiveTime == 0) revert NO_PROPOSED_FEE(feeType);
        if (block.timestamp < effectiveTime) {
            revert TIMELOCK_NOT_EXPIRED();
        }

        // Update the fee value
        _feeValues[feeType] = _proposedFeeValues[feeType];

        // Reset proposal data
        delete _proposedFeeValues[feeType];
        delete _feeEffectiveTimes[feeType];

        emit FeeUpdated(feeType, _feeValues[feeType]);
    }

    /*//////////////////////////////////////////////////////////////
                      UPKEEP COST MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function proposeUpkeepCostPerUpdate(uint256 newCost_) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        _proposedUpkeepCostPerUpdate = newCost_;
        _upkeepCostEffectiveTime = block.timestamp + TIMELOCK;

        emit UpkeepCostPerUpdateProposed(newCost_, _upkeepCostEffectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function executeUpkeepCostPerUpdateChange() external {
        uint256 upkeepCostEffectiveTime = _upkeepCostEffectiveTime;
        if (upkeepCostEffectiveTime == 0) revert NO_PROPOSED_UPKEEP_COST();
        if (block.timestamp < upkeepCostEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        _upkeepCostPerUpdate = _proposedUpkeepCostPerUpdate;

        // Reset proposal data
        _proposedUpkeepCostPerUpdate = 0;
        _upkeepCostEffectiveTime = 0;

        emit UpkeepCostPerUpdateChanged(_upkeepCostPerUpdate);
    }

    /*//////////////////////////////////////////////////////////////
                        UPKEEP PAYMENTS CONTROL
    //////////////////////////////////////////////////////////////*/
    /// @notice Proposes a change to the upkeep payments enabled status
    /// @param enabled The proposed new status for upkeep payments
    function proposeUpkeepPaymentsChange(bool enabled) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        _proposedUpkeepPaymentsEnabled = enabled;
        _upkeepPaymentsChangeEffectiveTime = block.timestamp + TIMELOCK;

        emit UpkeepPaymentsChangeProposed(enabled, _upkeepPaymentsChangeEffectiveTime);
    }

    /// @notice Executes a previously proposed change to upkeep payments status after timelock expires
    function executeUpkeepPaymentsChange() external {
        if (_upkeepPaymentsChangeEffectiveTime == 0) revert NO_PENDING_CHANGE();
        if (block.timestamp < _upkeepPaymentsChangeEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        _upkeepPaymentsEnabled = _proposedUpkeepPaymentsEnabled;
        _upkeepPaymentsChangeEffectiveTime = 0;

        emit UpkeepPaymentsChanged(_upkeepPaymentsEnabled);
    }

    /// @notice Checks if upkeep payments are currently enabled
    /// @return enabled True if upkeep payments are enabled
    function isUpkeepPaymentsEnabled() external view returns (bool enabled) {
        return _upkeepPaymentsEnabled;
    }

    /// @notice Gets the proposed upkeep payments status and effective time
    /// @return enabled The proposed status
    /// @return effectiveTime The timestamp when the change becomes effective
    function getProposedUpkeepPaymentsStatus() external view returns (bool enabled, uint256 effectiveTime) {
        return (_proposedUpkeepPaymentsEnabled, _upkeepPaymentsChangeEffectiveTime);
    }

    /*//////////////////////////////////////////////////////////////
                        SUPERFORM STRATEGIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @notice Adds a strategist to the superform strategists list (exempt from upkeep costs)
    /// @param strategist The address to add to the list
    function addSuperformStrategist(address strategist) external onlyRole(_GOVERNOR_ROLE) {
        if (strategist == address(0)) revert INVALID_ADDRESS();
        if (!_superformStrategists.add(strategist)) revert STRATEGIST_ALREADY_REGISTERED();

        emit SuperformStrategistAdded(strategist);
    }

    /// @notice Removes a strategist from the superform strategists list
    /// @param strategist The address to remove from the list
    function removeSuperformStrategist(address strategist) external onlyRole(_GOVERNOR_ROLE) {
        if (!_superformStrategists.remove(strategist)) revert STRATEGIST_NOT_REGISTERED();

        emit SuperformStrategistRemoved(strategist);
    }

    /// @notice Checks if an address is a registered superform strategist
    /// @param strategist The address to check
    /// @return isSuperform True if the address is a superform strategist
    function isSuperformStrategist(address strategist) external view returns (bool isSuperform) {
        return _superformStrategists.contains(strategist);
    }

    /// @notice Gets the list of all superform strategists
    /// @return strategists The list of all superform strategist addresses
    function getAllSuperformStrategists() external view returns (address[] memory strategists) {
        return _superformStrategists.values();
    }

    /*//////////////////////////////////////////////////////////////
                           SUPERBANK HOOKS MGMT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGovernor
    function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot) external onlyRole(_GOVERNOR_ROLE) {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();

        uint256 effectiveTime = block.timestamp + TIMELOCK;
        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];
        data.proposedRoot = proposedRoot;
        data.effectiveTime = effectiveTime;

        emit SuperBankHookMerkleRootProposed(hook, proposedRoot, effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function proposeVaultBankHookMerkleRoot(address hook, bytes32 proposedRoot) external onlyRole(_GOVERNOR_ROLE) {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();

        uint256 effectiveTime = block.timestamp + TIMELOCK;
        ISuperGovernor.HookMerkleRootData storage data = vaultBankHooksMerkleRoots[hook];
        data.proposedRoot = proposedRoot;
        data.effectiveTime = effectiveTime;

        emit VaultBankHookMerkleRootProposed(hook, proposedRoot, effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function executeSuperBankHookMerkleRootUpdate(address hook) external {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();

        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];

        // Check if there's a proposed update
        bytes32 proposedRoot = data.proposedRoot;
        if (proposedRoot == bytes32(0)) revert NO_PROPOSED_MERKLE_ROOT();

        // Check if the effective time has passed
        if (block.timestamp < data.effectiveTime) revert TIMELOCK_NOT_EXPIRED();

        // Update the Merkle root
        data.currentRoot = proposedRoot;

        // Reset the proposal
        data.proposedRoot = bytes32(0);
        data.effectiveTime = 0;

        emit SuperBankHookMerkleRootUpdated(hook, proposedRoot);
    }

    /// @inheritdoc ISuperGovernor
    function executeVaultBankHookMerkleRootUpdate(address hook) external {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();

        ISuperGovernor.HookMerkleRootData storage data = vaultBankHooksMerkleRoots[hook];

        // Check if there's a proposed update
        bytes32 proposedRoot = data.proposedRoot;
        if (proposedRoot == bytes32(0)) revert NO_PROPOSED_MERKLE_ROOT();

        // Check if the effective time has passed
        if (block.timestamp < data.effectiveTime) revert TIMELOCK_NOT_EXPIRED();

        // Update the Merkle root
        data.currentRoot = proposedRoot;

        // Reset the proposal
        data.proposedRoot = bytes32(0);
        data.effectiveTime = 0;

        emit VaultBankHookMerkleRootUpdated(hook, proposedRoot);
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function SUPER_GOVERNOR_ROLE() external pure returns (bytes32) {
        return _SUPER_GOVERNOR_ROLE;
    }

    /// @inheritdoc ISuperGovernor
    function GOVERNOR_ROLE() external pure returns (bytes32) {
        return _GOVERNOR_ROLE;
    }

    /// @inheritdoc ISuperGovernor
    function BANK_MANAGER_ROLE() external pure returns (bytes32) {
        return _BANK_MANAGER_ROLE;
    }

    /// @inheritdoc ISuperGovernor
    function GUARDIAN_ROLE() external pure returns (bytes32) {
        return _GUARDIAN_ROLE;
    }

    /// @inheritdoc ISuperGovernor
    function SUPER_ASSET_FACTORY() external pure returns (bytes32) {
        return _SUPER_ASSET_FACTORY;
    }

    /// @inheritdoc ISuperGovernor
    function getAddress(bytes32 key) external view returns (address) {
        address value = _addressRegistry[key];
        if (value == address(0)) revert CONTRACT_NOT_FOUND();
        return value;
    }

    /// @inheritdoc ISuperGovernor
    function isStrategistTakeoverFrozen() external view returns (bool) {
        return _strategistTakeoversFrozen;
    }

    /// @inheritdoc ISuperGovernor
    function isHookRegistered(address hook) external view returns (bool) {
        return _registeredHooks.contains(hook);
    }

    /// @inheritdoc ISuperGovernor
    function isFulfillRequestsHookRegistered(address hook) external view returns (bool) {
        return _registeredFulfillRequestsHooks.contains(hook);
    }

    /// @inheritdoc ISuperGovernor
    function getRegisteredHooks() external view returns (address[] memory) {
        return _registeredHooks.values();
    }

    /// @inheritdoc ISuperGovernor
    function getRegisteredFulfillRequestsHooks() external view returns (address[] memory) {
        return _registeredFulfillRequestsHooks.values();
    }

    /// @inheritdoc ISuperGovernor
    function isValidator(address validator) external view returns (bool) {
        return _isValidator[validator];
    }

    /// @inheritdoc ISuperGovernor
    function isGuardian(address guardian) external view returns (bool) {
        return hasRole(_GUARDIAN_ROLE, guardian);
    }

    /// @inheritdoc ISuperGovernor
    function isRelayer(address relayer) external view returns (bool) {
        return _isRelayer[relayer];
    }

    /// @inheritdoc ISuperGovernor
    function isExecutor(address executor) external view returns (bool) {
        return _isExecutor[executor];
    }

    /// @inheritdoc ISuperGovernor
    function getValidators() external view returns (address[] memory) {
        return _validatorsList;
    }

    /// @inheritdoc ISuperGovernor
    function getProposedActivePPSOracle() external view returns (address proposedOracle, uint256 effectiveTime) {
        return (_proposedActivePPSOracle, _activePPSOracleEffectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function getPPSOracleQuorum() external view returns (uint256) {
        return _activePPSOracleQuorum;
    }

    /// @inheritdoc ISuperGovernor
    function getActivePPSOracle() external view returns (address) {
        if (_activePPSOracle == address(0)) revert NO_ACTIVE_PPS_ORACLE();
        return _activePPSOracle;
    }

    /// @inheritdoc ISuperGovernor
    function isActivePPSOracle(address oracle) external view returns (bool) {
        return oracle == _activePPSOracle;
    }

    /// @inheritdoc ISuperGovernor
    function getFee(FeeType feeType) external view returns (uint256) {
        return _feeValues[feeType];
    }

    /// @inheritdoc ISuperGovernor
    function getUpkeepCostPerUpdate() external view returns (uint256) {
        return _upkeepCostPerUpdate;
    }

    /// @inheritdoc ISuperGovernor
    function getProposedUpkeepCostPerUpdate() external view returns (uint256 proposedCost, uint256 effectiveTime) {
        return (_proposedUpkeepCostPerUpdate, _upkeepCostEffectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function getSuperBankHookMerkleRoot(address hook) external view returns (bytes32) {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();
        return superBankHooksMerkleRoots[hook].currentRoot;
    }

    /// @inheritdoc ISuperGovernor
    function getVaultBankHookMerkleRoot(address hook) external view returns (bytes32) {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();
        return vaultBankHooksMerkleRoots[hook].currentRoot;
    }

    /// @inheritdoc ISuperGovernor
    function getProposedSuperBankHookMerkleRoot(address hook)
        external
        view
        returns (bytes32 proposedRoot, uint256 effectiveTime)
    {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();
        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];
        return (data.proposedRoot, data.effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function getProposedVaultBankHookMerkleRoot(address hook)
        external
        view
        returns (bytes32 proposedRoot, uint256 effectiveTime)
    {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();
        ISuperGovernor.HookMerkleRootData storage data = vaultBankHooksMerkleRoots[hook];
        return (data.proposedRoot, data.effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function getProver() external view returns (address) {
        return _prover;
    }
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Internal function to unregister a fulfill requests hook
    function _unregisterFulfillRequestsHook(address hook_) internal {
        if (!_registeredFulfillRequestsHooks.contains(hook_)) {
            revert FULFILL_REQUESTS_HOOK_NOT_REGISTERED();
        }
        _registeredFulfillRequestsHooks.remove(hook_);
        emit FulfillRequestsHookUnregistered(hook_);
        _unregisterRegularHook(hook_);
    }

    /// @dev Internal function to unregister a regular hook
    function _unregisterRegularHook(address hook_) internal {
        if (!_registeredHooks.contains(hook_)) {
            revert HOOK_NOT_APPROVED();
        }
        _registeredHooks.remove(hook_);
        emit HookRemoved(hook_);
    }
}
