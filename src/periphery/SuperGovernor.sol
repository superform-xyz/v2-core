// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// external
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

// Superform
import { ISuperGovernor } from "./interfaces/ISuperGovernor.sol";

/// @title SuperGovernor
/// @author Superform Labs
/// @notice Central registry for all deployed contracts in the Superform periphery
contract SuperGovernor is ISuperGovernor, Ownable2Step {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Address registry
    mapping(bytes32 id => address address_) private _addressRegistry;

    // PPS Oracle registry
    mapping(address ppsOracle => bool isOracle) private _isPPSOracle;
    address[] private _ppsOraclesList;

    // Hook registry
    mapping(address hook => bool isRegistered) private _isHookRegistered;
    mapping(address hook => bool isRegistered) private _isFulfillRequestsHookRegistered;
    address[] private _registeredHooks;
    address[] private _registeredFulfillRequestsHooks;

    // SuperBank Hook Target validation
    mapping(address hook => ISuperGovernor.HookMerkleRootData merkleData) private superBankHooksMerkleRoots;

    // Strategist registry
    mapping(address strategist => bool isStrategist) private _isStrategist;
    address[] private _strategistsList;

    // Validator registry
    mapping(address validator => bool isValidator) private _isValidator;
    address[] private _validatorsList;

    // Revenue share
    uint256 private revenueShare;
    uint256 private proposedRevenueShare;
    uint256 private revenueShareEffectiveTime;

    // Timelock configuration
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant MAX_REVENUE_SHARE = 10_000; // 100% in basis points

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
    /// @param owner_ Address of the owner
    /// @param treasury_ Address of the treasury
    constructor(address owner_, address treasury_) Ownable(owner_) {
        if (owner_ == address(0)) revert INVALID_ADDRESS();
        if (treasury_ == address(0)) revert INVALID_ADDRESS();

        // Initialize with a default revenue share of 20% (2000 basis points)
        revenueShare = 2000;

        // Set treasury in address registry
        _addressRegistry[TREASURY] = treasury_;
        emit AddressSet(TREASURY, treasury_);
    }

    /*//////////////////////////////////////////////////////////////
                       CONTRACT REGISTRY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function setAddress(bytes32 key, address value) external onlyOwner {
        if (value == address(0)) revert INVALID_ADDRESS();
        if (_addressRegistry[key] != address(0)) revert CONTRACT_ALREADY_REGISTERED();

        _addressRegistry[key] = value;
        emit AddressSet(key, value);
    }

    /// @inheritdoc ISuperGovernor
    function removeAddress(bytes32 key) external onlyOwner {
        if (_addressRegistry[key] == address(0)) revert CONTRACT_NOT_FOUND();

        delete _addressRegistry[key];
        emit AddressRemoved(key);
    }

    /// @inheritdoc ISuperGovernor
    function getAddress(bytes32 key) external view returns (address) {
        address value = _addressRegistry[key];
        if (value == address(0)) revert CONTRACT_NOT_FOUND();
        return value;
    }

    /*//////////////////////////////////////////////////////////////
                         HOOK MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function registerHook(address hook_, bool isFulfillRequestsHook_) external onlyOwner {
        if (hook_ == address(0)) revert INVALID_ADDRESS();

        if (isFulfillRequestsHook_) {
            if (_isFulfillRequestsHookRegistered[hook_]) revert FULFILL_REQUESTS_HOOK_ALREADY_REGISTERED();
            _isFulfillRequestsHookRegistered[hook_] = true;
            _registeredFulfillRequestsHooks.push(hook_);
            emit FulfillRequestsHookRegistered(hook_);
        }

        if (!_isHookRegistered[hook_]) {
            _isHookRegistered[hook_] = true;
            _registeredHooks.push(hook_);
            emit HookApproved(hook_);
        } else if (!isFulfillRequestsHook_) {
            revert HOOK_ALREADY_APPROVED();
        }
    }

    /// @inheritdoc ISuperGovernor
    function unregisterHook(address hook_, bool isFulfillRequestsHook_) external onlyOwner {
        if (isFulfillRequestsHook_) {
            if (!_isFulfillRequestsHookRegistered[hook_]) revert FULFILL_REQUESTS_HOOK_NOT_REGISTERED();
            _isFulfillRequestsHookRegistered[hook_] = false;

            // Find the hook in the registered fulfill requests hooks array and remove it
            uint256 length = _registeredFulfillRequestsHooks.length;
            for (uint256 i; i < length; i++) {
                if (_registeredFulfillRequestsHooks[i] == hook_) {
                    _registeredFulfillRequestsHooks[i] =
                        _registeredFulfillRequestsHooks[_registeredFulfillRequestsHooks.length - 1];
                    _registeredFulfillRequestsHooks.pop();
                    break;
                }
            }
            emit FulfillRequestsHookUnregistered(hook_);
        }

        if (_isHookRegistered[hook_]) {
            _isHookRegistered[hook_] = false;

            // Find the hook in the registered hooks array and remove it
            uint256 length = _registeredHooks.length;
            for (uint256 i; i < length; i++) {
                if (_registeredHooks[i] == hook_) {
                    _registeredHooks[i] = _registeredHooks[_registeredHooks.length - 1];
                    _registeredHooks.pop();
                    break;
                }
            }
            emit HookRemoved(hook_);
        } else if (!isFulfillRequestsHook_) {
            revert HOOK_NOT_APPROVED();
        }
    }

    /// @inheritdoc ISuperGovernor
    function isHookRegistered(address hook) external view returns (bool) {
        return _isHookRegistered[hook];
    }

    /// @inheritdoc ISuperGovernor
    function isFulfillRequestsHookRegistered(address hook) external view returns (bool) {
        return _isFulfillRequestsHookRegistered[hook];
    }

    /// @inheritdoc ISuperGovernor
    function getRegisteredHooks() external view returns (address[] memory) {
        return _registeredHooks;
    }

    /// @inheritdoc ISuperGovernor
    function getRegisteredFulfillRequestsHooks() external view returns (address[] memory) {
        return _registeredFulfillRequestsHooks;
    }

    /*//////////////////////////////////////////////////////////////
                      STRATEGIST MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addStrategist(address strategist) external onlyOwner {
        if (strategist == address(0)) revert INVALID_ADDRESS();
        if (_isStrategist[strategist]) revert STRATEGIST_ALREADY_REGISTERED();

        _isStrategist[strategist] = true;
        _strategistsList.push(strategist);
        emit StrategistAdded(strategist);
    }

    /// @inheritdoc ISuperGovernor
    function removeStrategist(address strategist) external onlyOwner {
        if (!_isStrategist[strategist]) revert STRATEGIST_NOT_REGISTERED();

        _isStrategist[strategist] = false;

        // Remove from strategists array
        uint256 length = _strategistsList.length;
        for (uint256 i; i < length; i++) {
            if (_strategistsList[i] == strategist) {
                _strategistsList[i] = _strategistsList[_strategistsList.length - 1];
                _strategistsList.pop();
                break;
            }
        }

        emit StrategistRemoved(strategist);
    }

    /// @inheritdoc ISuperGovernor
    function isStrategist(address strategist) external view returns (bool) {
        return _isStrategist[strategist];
    }

    /// @inheritdoc ISuperGovernor
    function getStrategists() external view returns (address[] memory) {
        return _strategistsList;
    }

    /*//////////////////////////////////////////////////////////////
                      VALIDATOR MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addValidator(address validator) external onlyOwner {
        if (validator == address(0)) revert INVALID_ADDRESS();
        if (_isValidator[validator]) revert VALIDATOR_ALREADY_REGISTERED();

        _isValidator[validator] = true;
        _validatorsList.push(validator);
        emit ValidatorAdded(validator);
    }

    /// @inheritdoc ISuperGovernor
    function removeValidator(address validator) external onlyOwner {
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

    /// @inheritdoc ISuperGovernor
    function isValidator(address validator) external view returns (bool) {
        return _isValidator[validator];
    }

    /// @inheritdoc ISuperGovernor
    function getValidators() external view returns (address[] memory) {
        return _validatorsList;
    }

    /*//////////////////////////////////////////////////////////////
                       PPS ORACLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function addPPSOracle(address oracle) external onlyOwner {
        if (oracle == address(0)) revert INVALID_ADDRESS();
        if (_isPPSOracle[oracle]) revert PPS_ORACLE_ALREADY_REGISTERED();

        _isPPSOracle[oracle] = true;
        _ppsOraclesList.push(oracle);
        emit PPSOracleAdded(oracle);
    }

    /// @inheritdoc ISuperGovernor
    function removePPSOracle(address oracle) external onlyOwner {
        if (!_isPPSOracle[oracle]) revert PPS_ORACLE_NOT_REGISTERED();

        _isPPSOracle[oracle] = false;

        // Remove from oracles array
        uint256 length = _ppsOraclesList.length;
        for (uint256 i; i < length; i++) {
            if (_ppsOraclesList[i] == oracle) {
                _ppsOraclesList[i] = _ppsOraclesList[_ppsOraclesList.length - 1];
                _ppsOraclesList.pop();
                break;
            }
        }

        emit PPSOracleRemoved(oracle);
    }

    /// @inheritdoc ISuperGovernor
    function isPPSOracle(address oracle) external view returns (bool) {
        return _isPPSOracle[oracle];
    }

    /// @inheritdoc ISuperGovernor
    function getPPSOracles() external view returns (address[] memory) {
        return _ppsOraclesList;
    }

    /*//////////////////////////////////////////////////////////////
                      REVENUE SHARE MANAGEMENT
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperGovernor
    function proposeRevenueShare(uint256 share) external onlyOwner {
        if (share > MAX_REVENUE_SHARE) revert INVALID_REVENUE_SHARE();

        proposedRevenueShare = share;
        revenueShareEffectiveTime = block.timestamp + ONE_WEEK;

        emit RevenueShareProposed(share, revenueShareEffectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function executeRevenueShareUpdate() external {
        uint256 effectiveTime = revenueShareEffectiveTime;
        if (effectiveTime == 0 || block.timestamp < effectiveTime) {
            revert TIMELOCK_NOT_EXPIRED();
        }
        revenueShare = proposedRevenueShare;
        proposedRevenueShare = 0;
        revenueShareEffectiveTime = 0;

        emit RevenueShareUpdated(revenueShare);
    }

    /// @inheritdoc ISuperGovernor
    function getRevenueShare() external view returns (uint256) {
        return revenueShare;
    }

    /*//////////////////////////////////////////////////////////////
                           SUPERBANK HOOKS MGMT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperGovernor
    function getSuperBankHookMerkleRoot(address hook) external view returns (bytes32) {
        if (!_isHookRegistered[hook]) revert HOOK_NOT_APPROVED();
        return superBankHooksMerkleRoots[hook].currentRoot;
    }

    /// @inheritdoc ISuperGovernor
    function getProposedSuperBankHookMerkleRoot(address hook)
        external
        view
        returns (bytes32 proposedRoot, uint256 effectiveTime)
    {
        if (!_isHookRegistered[hook]) revert HOOK_NOT_APPROVED();
        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];
        return (data.proposedRoot, data.effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function proposeSuperBankHookMerkleRoot(address hook, bytes32 proposedRoot, uint256 delay) external onlyOwner {
        if (!_isHookRegistered[hook]) revert HOOK_NOT_APPROVED();
        if (delay == 0) revert INVALID_TIMESTAMP();

        uint256 effectiveTime = block.timestamp + delay;
        ISuperGovernor.HookMerkleRootData storage data = superBankHooksMerkleRoots[hook];
        data.proposedRoot = proposedRoot;
        data.effectiveTime = effectiveTime;

        emit SuperBankHookMerkleRootProposed(hook, proposedRoot, effectiveTime);
    }

    /// @inheritdoc ISuperGovernor
    function executeSuperBankHookMerkleRootUpdate(address hook) external returns (bool) {
        if (!_isHookRegistered[hook]) revert HOOK_NOT_APPROVED();

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
}
