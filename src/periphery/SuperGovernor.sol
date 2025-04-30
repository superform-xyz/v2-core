// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// Superform
import { ISuperGovernor, FeeType } from "./interfaces/ISuperGovernor.sol";
import { ISuperVaultAggregator } from "./interfaces/ISuperVaultAggregator.sol";

/// @title SuperGovernor
/// @author Superform Labs
/// @notice Central registry for all deployed contracts in the Superform periphery
contract SuperGovernor is ISuperGovernor, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    /// @inheritdoc ISuperGovernor

    function SUPER_GOVERNOR_ROLE() external pure returns (bytes32) {
        return _SUPER_GOVERNOR_ROLE;
    }

    /// @inheritdoc ISuperGovernor
    function GOVERNOR_ROLE() external pure returns (bytes32) {
        return _GOVERNOR_ROLE;
    }

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

    // Global freeze for strategist takeovers
    bool private _strategistTakeoversFrozen;

    // Validator registry
    mapping(address validator => bool isValidator) private _isValidator;
    address[] private _validatorsList;

    // Fee management
    // Current fee values
    mapping(FeeType => uint256) private _feeValues;
    // Proposed fee values
    mapping(FeeType => uint256) private _proposedFeeValues;
    // Effective times for proposed fee updates
    mapping(FeeType => uint256) private _feeEffectiveTimes;

    // Timelock configuration
    uint256 private constant TIMELOCK = 7 days;
    uint256 private constant BPS_MAX = 10_000; // 100% in basis points

    // Role definitions
    bytes32 private constant _SUPER_GOVERNOR_ROLE = keccak256("SUPER_GOVERNOR_ROLE");
    bytes32 private constant _GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    // Common contract keys
    bytes32 public constant TREASURY = keccak256("TREASURY");
    bytes32 public constant SUPER_ORACLE = keccak256("SUPER_ORACLE");
    bytes32 public constant BLSPPSORACLE = keccak256("BLSPPSORACLE");
    bytes32 public constant ECDSAPPSORACLE = keccak256("ECDSAPPSORACLE");
    bytes32 public constant SUPER_VAULT_AGGREGATOR = keccak256("SUPER_VAULT_AGGREGATOR");
    bytes32 public constant UP = keccak256("UP");
    bytes32 public constant SUP = keccak256("SUP");
    bytes32 public constant SUPER_BANK = keccak256("SUPER_BANK");

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the SuperGovernor contract
    /// @param admin Address of the default admin (will have SUPER_GOVERNOR_ROLE)
    /// @param governor Address that will have the GOVERNOR_ROLE for daily operations
    /// @param treasury_ Address of the treasury
    constructor(address admin, address governor, address treasury_) {
        if (admin == address(0) || treasury_ == address(0) || governor == address(0)) revert INVALID_ADDRESS();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(_SUPER_GOVERNOR_ROLE, admin);
        _grantRole(_GOVERNOR_ROLE, governor);

        // Set role admins
        _setRoleAdmin(_GOVERNOR_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(_SUPER_GOVERNOR_ROLE, DEFAULT_ADMIN_ROLE);

        // Initialize with default fees
        _feeValues[FeeType.REVENUE_SHARE] = 2000; // 20% revenue share
        _feeValues[FeeType.SUPER_VAULT_PERFORMANCE_FEE] = 2000; // 20% performance fee
        _feeValues[FeeType.SUPER_ASSET_SWAP_FEE] = 4000; // 40% swap fee

        // Set treasury in address registry
        _addressRegistry[TREASURY] = treasury_;
        emit AddressSet(TREASURY, treasury_);
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
                        SUPER VAULT AGGREGATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/

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
        } else {
            if (_registeredHooks.contains(hook_)) {
                revert HOOK_ALREADY_APPROVED();
            }
            _registeredHooks.add(hook_);
            emit HookApproved(hook_);
        }
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
        if (_activePPSOracle == address(0)) revert NO_ACTIVE_PPS_ORACLE();
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
        if (effectiveTime == 0 || block.timestamp < effectiveTime) {
            revert TIMELOCK_NOT_EXPIRED();
        }

        // Update the fee value
        _feeValues[feeType] = _proposedFeeValues[feeType];

        // Reset proposal data
        _proposedFeeValues[feeType] = 0;
        _feeEffectiveTimes[feeType] = 0;

        emit FeeUpdated(feeType, _feeValues[feeType]);
    }

    /*//////////////////////////////////////////////////////////////
                           SUPERBANK HOOKS MGMT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGovernor
    function proposeSuperBankHookMerkleRoot(
        address hook,
        bytes32 proposedRoot,
        uint256 delay
    )
        external
        onlyRole(_GOVERNOR_ROLE)
    {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();
        if (delay == 0) revert INVALID_TIMESTAMP();

        uint256 effectiveTime = block.timestamp + delay;
        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];
        data.proposedRoot = proposedRoot;
        data.effectiveTime = effectiveTime;

        emit SuperBankHookMerkleRootProposed(hook, proposedRoot, effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function executeSuperBankHookMerkleRootUpdate(address hook) external returns (bool) {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();

        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];

        // Check if there's a proposed update
        bytes32 proposedRoot = data.proposedRoot;
        if (proposedRoot == bytes32(0)) return false;

        // Check if the effective time has passed
        if (block.timestamp < data.effectiveTime) return false;

        // Update the Merkle root
        data.currentRoot = proposedRoot;

        // Reset the proposal
        data.proposedRoot = bytes32(0);
        data.effectiveTime = 0;

        emit SuperBankHookMerkleRootUpdated(hook, proposedRoot);
        return true;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
    function getSuperBankHookMerkleRoot(address hook) external view returns (bytes32) {
        if (!_registeredHooks.contains(hook)) revert HOOK_NOT_APPROVED();
        return superBankHooksMerkleRoots[hook].currentRoot;
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
