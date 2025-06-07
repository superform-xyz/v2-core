// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import { ISuperGovernor, FeeType } from "./interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "./interfaces/SuperVault/ISuperVaultAggregator.sol";
import { ISuperAssetFactory } from "./interfaces/SuperAsset/ISuperAssetFactory.sol";
import { ISuperOracle } from "./interfaces/oracles/ISuperOracle.sol";
import { ISuperOracleL2 } from "./interfaces/oracles/ISuperOracleL2.sol";

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

    // Whitelisted incentive tokens
    mapping(address token => bool isWhitelisted) private _isWhitelistedIncentiveToken;
    EnumerableSet.AddressSet private _proposedWhitelistedIncentiveTokens;
    EnumerableSet.AddressSet private _proposedRemoveWhitelistedIncentiveTokens;
    uint256 private _proposedWhitelistedIncentiveTokensEffectiveTime;

    // Fee management
    // Current fee values
    mapping(FeeType type_ => uint256 value) private _feeValues;
    // Proposed fee values
    mapping(FeeType type_ => uint256 proposedValue) private _proposedFeeValues;
    // Effective times for proposed fee updates
    mapping(FeeType type_ => uint256 effectiveTime) private _feeEffectiveTimes;

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
    bytes32 public constant UP = keccak256("UP");
    bytes32 public constant SUP = keccak256("SUP");
    bytes32 public constant TREASURY = keccak256("TREASURY");
    bytes32 public constant SUPER_BANK = keccak256("SUPER_BANK");
    bytes32 public constant SUPER_ORACLE = keccak256("SUPER_ORACLE");
    bytes32 public constant BANK_MANAGER = keccak256("BANK_MANAGER");
    bytes32 public constant ECDSAPPSORACLE = keccak256("ECDSAPPSORACLE");
    bytes32 public constant SUPER_VAULT_AGGREGATOR = keccak256("SUPER_VAULT_AGGREGATOR");

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
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
                    PERIPHERY CONFIGURATIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function setProver(address prover_) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (prover_ == address(0)) revert INVALID_ADDRESS();

        _prover = prover_;
        emit ProverSet(prover_);
    }

    /// @inheritdoc ISuperGovernor
    function changePrimaryStrategist(
        address strategy_,
        address newStrategist_
    )
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

    /// @inheritdoc ISuperGovernor
    function freezeStrategistTakeover() external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (_strategistTakeoversFrozen) revert STRATEGIST_TAKEOVERS_FROZEN();

        // Set frozen status to true (permanent, cannot be undone)
        _strategistTakeoversFrozen = true;

        // Emit event for the frozen status
        emit StrategistTakeoversFrozen();
    }

    /// @inheritdoc ISuperGovernor
    function changeHooksRootUpdateTimelock(uint256 newTimelock_) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        // Call the SuperVaultAggregator to change the hooks root update timelock
        ISuperVaultAggregator(aggregator).setHooksRootUpdateTimelock(newTimelock_);
    }

    /// @inheritdoc ISuperGovernor
    function proposeGlobalHooksRoot(bytes32 newRoot) external onlyRole(_GOVERNOR_ROLE) {
        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperVaultAggregator(aggregator).proposeGlobalHooksRoot(newRoot);
    }

    /// @inheritdoc ISuperGovernor
    function setGlobalHooksRootVetoStatus(bool vetoed_) external onlyRole(_GUARDIAN_ROLE) {
        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperVaultAggregator(aggregator).setGlobalHooksRootVetoStatus(vetoed_);
    }

    /// @inheritdoc ISuperGovernor
    function setStrategyHooksRootVetoStatus(address strategy_, bool vetoed_) external onlyRole(_GUARDIAN_ROLE) {
        if (strategy_ == address(0)) revert INVALID_ADDRESS();

        address aggregator = _addressRegistry[SUPER_VAULT_AGGREGATOR];
        if (aggregator == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperVaultAggregator(aggregator).setStrategyHooksRootVetoStatus(strategy_, vetoed_);
    }

    /// @inheritdoc ISuperGovernor
    function setSuperAssetManager(address superAsset, address _superAssetManager) external onlyRole(_GOVERNOR_ROLE) {
        if (_superAssetManager == address(0)) revert INVALID_ADDRESS();
        address value = _addressRegistry[_SUPER_ASSET_FACTORY];
        if (value == address(0)) revert CONTRACT_NOT_FOUND();
        ISuperAssetFactory factory = ISuperAssetFactory(value);
        factory.setSuperAssetManager(superAsset, _superAssetManager);
    }

    /// @inheritdoc ISuperGovernor
    function addICCToWhitelist(address icc) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (icc == address(0)) revert INVALID_ADDRESS();
        address value = _addressRegistry[_SUPER_ASSET_FACTORY];
        if (value == address(0)) revert CONTRACT_NOT_FOUND();
        ISuperAssetFactory factory = ISuperAssetFactory(value);
        factory.addICCToWhitelist(icc);
    }

    /// @inheritdoc ISuperGovernor
    function removeICCFromWhitelist(address icc) external onlyRole(_SUPER_GOVERNOR_ROLE) {
        if (icc == address(0)) revert INVALID_ADDRESS();
        address value = _addressRegistry[_SUPER_ASSET_FACTORY];
        if (value == address(0)) revert CONTRACT_NOT_FOUND();
        ISuperAssetFactory factory = ISuperAssetFactory(value);
        factory.removeICCFromWhitelist(icc);
    }

    /// @inheritdoc ISuperGovernor
    function setOracleMaxStaleness(uint256 newMaxStaleness_) external onlyRole(_GOVERNOR_ROLE) {
        address oracle = _addressRegistry[SUPER_ORACLE];
        if (oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).setMaxStaleness(newMaxStaleness_);
    }

    /// @inheritdoc ISuperGovernor
    function setOracleFeedMaxStaleness(address feed_, uint256 newMaxStaleness_) external onlyRole(_GOVERNOR_ROLE) {
        if (feed_ == address(0)) revert INVALID_ADDRESS();
        address oracle = _addressRegistry[SUPER_ORACLE];
        if (oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).setFeedMaxStaleness(feed_, newMaxStaleness_);
    }

    /// @inheritdoc ISuperGovernor
    function setOracleFeedMaxStalenessBatch(
        address[] calldata feeds_,
        uint256[] calldata newMaxStalenessList_
    )
        external
        onlyRole(_GOVERNOR_ROLE)
    {
        address oracle = _addressRegistry[SUPER_ORACLE];
        if (oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).setFeedMaxStalenessBatch(feeds_, newMaxStalenessList_);
    }

    /// @inheritdoc ISuperGovernor
    function queueOracleUpdate(
        address[] calldata bases_,
        address[] calldata quotes_,
        bytes32[] calldata providers_,
        address[] calldata feeds_
    )
        external
        onlyRole(_GOVERNOR_ROLE)
    {
        address oracle = _addressRegistry[SUPER_ORACLE];
        if (oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).queueOracleUpdate(bases_, quotes_, providers_, feeds_);
    }

    /// @inheritdoc ISuperGovernor
    function queueOracleProviderRemoval(bytes32[] calldata providers_) external onlyRole(_GOVERNOR_ROLE) {
        address oracle = _addressRegistry[SUPER_ORACLE];
        if (oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).queueProviderRemoval(providers_);
    }

    /// @inheritdoc ISuperGovernor
    function batchSetOracleUptimeFeed(
        address[] calldata dataOracles_,
        address[] calldata uptimeOracles_,
        uint256[] calldata gracePeriods_
    )
        external
        onlyRole(_GOVERNOR_ROLE)
    {
        address oracleL2 = _addressRegistry[SUPER_ORACLE];
        if (oracleL2 == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracleL2(oracleL2).batchSetUptimeFeed(dataOracles_, uptimeOracles_, gracePeriods_);
    }

    /// @inheritdoc ISuperGovernor
    function setEmergencyPrice(address token_, uint256 price_) external onlyRole(_GOVERNOR_ROLE) {
        address oracle = _addressRegistry[SUPER_ORACLE];
        if (oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).setEmergencyPrice(token_, price_);
    }

    /// @inheritdoc ISuperGovernor
    function batchSetEmergencyPrices(
        address[] calldata tokens_,
        uint256[] calldata prices_
    )
        external
        onlyRole(_GOVERNOR_ROLE)
    {
        address oracle = _addressRegistry[SUPER_ORACLE];
        if(oracle == address(0)) revert CONTRACT_NOT_FOUND();

        ISuperOracle(oracle).batchSetEmergencyPrice(tokens_, prices_);
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
    /// @inheritdoc ISuperGovernor
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

    /*//////////////////////////////////////////////////////////////
                        SUPERFORM STRATEGIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addSuperformStrategist(address strategist) external onlyRole(_GOVERNOR_ROLE) {
        if (strategist == address(0)) revert INVALID_ADDRESS();
        if (!_superformStrategists.add(strategist)) revert STRATEGIST_ALREADY_REGISTERED();

        emit SuperformStrategistAdded(strategist);
    }

    /// @inheritdoc ISuperGovernor
    function removeSuperformStrategist(address strategist) external onlyRole(_GOVERNOR_ROLE) {
        if (!_superformStrategists.remove(strategist)) revert STRATEGIST_NOT_REGISTERED();

        emit SuperformStrategistRemoved(strategist);
    }

    /*//////////////////////////////////////////////////////////////
                           VAULT HOOKS MGMT
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                      INCENTIVE TOKEN MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function proposeAddIncentiveTokens(address[] memory tokens) external onlyRole(_GOVERNOR_ROLE) {
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert INVALID_ADDRESS();
            _proposedWhitelistedIncentiveTokens.add(tokens[i]);
        }

        _proposedWhitelistedIncentiveTokensEffectiveTime = block.timestamp + TIMELOCK;

        emit WhitelistedIncentiveTokensProposed(
            _proposedWhitelistedIncentiveTokens.values(), _proposedWhitelistedIncentiveTokensEffectiveTime
        );
    }

    /// @inheritdoc ISuperGovernor
    function executeAddIncentiveTokens() external {
        if (block.timestamp < _proposedWhitelistedIncentiveTokensEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        for (uint256 i; i < _proposedWhitelistedIncentiveTokens.length(); i++) {
            address token = _proposedWhitelistedIncentiveTokens.at(i);

            _isWhitelistedIncentiveToken[token] = true;
            emit WhitelistedIncentiveTokensAdded(_proposedWhitelistedIncentiveTokens.values());

            // Remove from proposed whitelisted tokens
            _proposedWhitelistedIncentiveTokens.remove(token);
        }

        // Reset proposal timestamp
        _proposedWhitelistedIncentiveTokensEffectiveTime = 0;
    }

    /// @inheritdoc ISuperGovernor
    function proposeRemoveIncentiveTokens(address[] memory tokens) external onlyRole(_GOVERNOR_ROLE) {
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert INVALID_ADDRESS();
            if (!_isWhitelistedIncentiveToken[tokens[i]]) revert NOT_WHITELISTED_INCENTIVE_TOKEN();

            _proposedRemoveWhitelistedIncentiveTokens.add(tokens[i]);
        }

        _proposedWhitelistedIncentiveTokensEffectiveTime = block.timestamp + TIMELOCK;

        emit WhitelistedIncentiveTokensProposed(
            _proposedRemoveWhitelistedIncentiveTokens.values(), _proposedWhitelistedIncentiveTokensEffectiveTime
        );
    }

    /// @inheritdoc ISuperGovernor
    function executeRemoveIncentiveTokens() external {
        if (block.timestamp < _proposedWhitelistedIncentiveTokensEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        for (uint256 i; i < _proposedRemoveWhitelistedIncentiveTokens.length(); i++) {
            address token = _proposedRemoveWhitelistedIncentiveTokens.at(i);
            if (_isWhitelistedIncentiveToken[token]) {
                _isWhitelistedIncentiveToken[token] = false;

                emit WhitelistedIncentiveTokensRemoved(_proposedWhitelistedIncentiveTokens.values());

                // Remove from proposed whitelisted tokens to be removed
                _proposedRemoveWhitelistedIncentiveTokens.remove(token);
            }
        }

        // Reset proposal timestamp
        _proposedWhitelistedIncentiveTokensEffectiveTime = 0;
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

    /// @inheritdoc ISuperGovernor
    function isUpkeepPaymentsEnabled() external view returns (bool enabled) {
        return _upkeepPaymentsEnabled;
    }

    /// @inheritdoc ISuperGovernor
    function getProposedUpkeepPaymentsStatus() external view returns (bool enabled, uint256 effectiveTime) {
        return (_proposedUpkeepPaymentsEnabled, _upkeepPaymentsChangeEffectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function isSuperformStrategist(address strategist) external view returns (bool isSuperform) {
        return _superformStrategists.contains(strategist);
    }

    /// @inheritdoc ISuperGovernor
    function getAllSuperformStrategists() external view returns (address[] memory strategists) {
        return _superformStrategists.values();
    }

    /// @inheritdoc ISuperGovernor
    function isWhitelistedIncentiveToken(address token) external view returns (bool) {
        return _isWhitelistedIncentiveToken[token];
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
