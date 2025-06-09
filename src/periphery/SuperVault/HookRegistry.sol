// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Superform
import { ISuperGovernor } from "../interfaces/ISuperGovernor.sol";
import { IHookFactory } from "../interfaces/SuperVault/IHookFactory.sol";
import { ISuperVaultRegistry } from "../interfaces/SuperVault/ISuperVaultRegistry.sol";

/// @title HookFactory
/// @author Superform Labs
/// @notice Factory contract for hook validation and Merkle root management
contract HookFactory is IHookFactory {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    // Governance and registry contracts
    ISuperGovernor public immutable SUPER_GOVERNOR;
    ISuperVaultRegistry public immutable SUPER_VAULT_REGISTRY;

    // Timelock for Merkle root updates
    uint256 private _hooksRootUpdateTimelock = 15 minutes;

    // Global hooks Merkle root data
    bytes32 private _globalHooksRoot;
    bytes32 private _proposedGlobalHooksRoot;
    uint256 private _globalHooksRootEffectiveTime;
    bool private _globalHooksRootVetoed;

    // Strategy-specific hooks data
    mapping(address strategy => bytes32 strategistHooksRoot) private _strategyHooksRoots;
    mapping(address strategy => bytes32 proposedHooksRoot) private _proposedStrategyHooksRoots;
    mapping(address strategy => uint256 hooksRootEffectiveTime) private _strategyHooksRootEffectiveTimes;
    mapping(address strategy => bool hooksRootVetoed) private _strategyHooksRootVetoed;

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Validates that the strategy exists in the asset registry
    modifier validStrategy(address strategy) {
        // Check that strategy has a main strategist (exists in registry)
        if (SUPER_VAULT_REGISTRY.getMainStrategist(strategy) == address(0)) revert ZERO_ADDRESS();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /// @notice Initializes the HookFactory
    /// @param superGovernor_ Address of the SuperGovernor contract
    /// @param superVaultRegistry_ Address of the SuperVaultRegistry contract
    constructor(address superGovernor_, address superVaultRegistry_) {
        if (superGovernor_ == address(0) || superVaultRegistry_ == address(0)) revert ZERO_ADDRESS();

        SUPER_GOVERNOR = ISuperGovernor(superGovernor_);
        SUPER_VAULT_REGISTRY = ISuperVaultRegistry(superVaultRegistry_);
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK VALIDATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IHookFactory
    function setHooksRootUpdateTimelock(uint256 newTimelock) external {
        // Only SUPER_GOVERNOR or the SuperVaultAggregator can update the timelock
        address aggregator = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_VAULT_AGGREGATOR());
        if (msg.sender != address(SUPER_GOVERNOR) && msg.sender != aggregator) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Update the timelock
        _hooksRootUpdateTimelock = newTimelock;

        emit HooksRootUpdateTimelockChanged(newTimelock);
    }

    /// @inheritdoc IHookFactory
    function proposeGlobalHooksRoot(bytes32 newRoot) external {
        // Only SUPER_GOVERNOR or the SuperVaultAggregator can update the global hooks root
        address aggregator = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_VAULT_AGGREGATOR());
        if (msg.sender != address(SUPER_GOVERNOR) && msg.sender != aggregator) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Set new root with timelock
        _proposedGlobalHooksRoot = newRoot;
        _globalHooksRootEffectiveTime = block.timestamp + _hooksRootUpdateTimelock;

        emit GlobalHooksRootUpdateProposed(newRoot, _globalHooksRootEffectiveTime);
    }

    /// @inheritdoc IHookFactory
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

    /// @inheritdoc IHookFactory
    function setGlobalHooksRootVetoStatus(bool vetoed) external {
        // Only SuperGovernor or the SuperVaultAggregator can call this
        address aggregator = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_VAULT_AGGREGATOR());
        if (msg.sender != address(SUPER_GOVERNOR) && msg.sender != aggregator) {
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

    /// @inheritdoc IHookFactory
    function proposeStrategyHooksRoot(address strategy, bytes32 newRoot) external validStrategy(strategy) {
        // Only the main strategist can propose strategy-specific hooks root
        if (SUPER_VAULT_REGISTRY.getMainStrategist(strategy) != msg.sender) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Set proposed root with timelock
        _proposedStrategyHooksRoots[strategy] = newRoot;
        _strategyHooksRootEffectiveTimes[strategy] = block.timestamp + _hooksRootUpdateTimelock;

        emit StrategyHooksRootUpdateProposed(strategy, msg.sender, newRoot, _strategyHooksRootEffectiveTimes[strategy]);
    }

    /// @inheritdoc IHookFactory
    function executeStrategyHooksRootUpdate(address strategy) external validStrategy(strategy) {
        // Ensure there is a pending proposal
        if (_proposedStrategyHooksRoots[strategy] == bytes32(0)) {
            revert NO_PENDING_STRATEGIST_CHANGE(); // Reusing error for simplicity
        }

        // Check if timelock period has elapsed
        if (block.timestamp < _strategyHooksRootEffectiveTimes[strategy]) {
            revert ROOT_UPDATE_NOT_READY();
        }

        // Update the strategy's hooks root
        bytes32 oldRoot = _strategyHooksRoots[strategy];
        _strategyHooksRoots[strategy] = _proposedStrategyHooksRoots[strategy];

        // Reset proposal state
        _proposedStrategyHooksRoots[strategy] = bytes32(0);
        _strategyHooksRootEffectiveTimes[strategy] = 0;

        emit StrategyHooksRootUpdated(strategy, oldRoot, _strategyHooksRoots[strategy]);
    }

    /// @inheritdoc IHookFactory
    function setStrategyHooksRootVetoStatus(address strategy, bool vetoed) external validStrategy(strategy) {
        // Only SuperGovernor or the SuperVaultAggregator can call this
        address aggregator = SUPER_GOVERNOR.getAddress(SUPER_GOVERNOR.SUPER_VAULT_AGGREGATOR());
        if (msg.sender != address(SUPER_GOVERNOR) && msg.sender != aggregator) {
            revert UNAUTHORIZED_UPDATE_AUTHORITY();
        }

        // Don't emit event if status doesn't change
        if (_strategyHooksRootVetoed[strategy] == vetoed) {
            return;
        }

        // Update veto status
        _strategyHooksRootVetoed[strategy] = vetoed;

        emit StrategyHooksRootVetoStatusChanged(strategy, vetoed, _strategyHooksRoots[strategy]);
    }

    /// @inheritdoc IHookFactory
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
        bool strategyHooksVetoed = _strategyHooksRootVetoed[strategy];
        if (globalHooksVetoed && strategyHooksVetoed) {
            return false;
        }

        return
            _validateSingleHook(strategy, hookArgs, globalProof, strategyProof, globalHooksVetoed, strategyHooksVetoed);
    }

    /// @inheritdoc IHookFactory
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
        bool strategyHooksVetoed = _strategyHooksRootVetoed[strategy];

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

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IHookFactory
    function isGlobalHooksRootVetoed() external view returns (bool vetoed) {
        return _globalHooksRootVetoed;
    }

    /// @inheritdoc IHookFactory
    function isStrategyHooksRootVetoed(address strategy) external view returns (bool vetoed) {
        return _strategyHooksRootVetoed[strategy];
    }

    /// @inheritdoc IHookFactory
    function getHooksRootUpdateTimelock() external view returns (uint256) {
        return _hooksRootUpdateTimelock;
    }

    /// @inheritdoc IHookFactory
    function getGlobalHooksRoot() external view returns (bytes32 root) {
        return _globalHooksRoot;
    }

    /// @inheritdoc IHookFactory
    function getProposedGlobalHooksRoot() external view returns (bytes32 root, uint256 effectiveTime) {
        return (_proposedGlobalHooksRoot, _globalHooksRootEffectiveTime);
    }

    /// @inheritdoc IHookFactory
    function isGlobalHooksRootActive() external view returns (bool) {
        return block.timestamp >= _globalHooksRootEffectiveTime && _globalHooksRoot != bytes32(0);
    }

    /// @inheritdoc IHookFactory
    function getStrategyHooksRoot(address strategy) external view returns (bytes32 root) {
        return _strategyHooksRoots[strategy];
    }

    /// @inheritdoc IHookFactory
    function getProposedStrategyHooksRoot(address strategy)
        external
        view
        returns (bytes32 root, uint256 effectiveTime)
    {
        return (_proposedStrategyHooksRoots[strategy], _strategyHooksRootEffectiveTimes[strategy]);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @notice Creates a leaf node for Merkle verification from hook arguments
    /// @param hookArgs The packed-encoded hook arguments (from solidityPack in JS)
    /// @return leaf The leaf node hash
    function _createLeaf(bytes calldata hookArgs) internal pure returns (bytes32) {
        /// @dev note the leaf is just composed by the args, not by the address of the hook
        /// @dev this means hooks with different addresses but with the same type of encodings, will have the
        /// same authorization (same proof is going to be generated). Is this ok?
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
            bytes32 strategyRoot = _strategyHooksRoots[strategy];
            if (strategyRoot != bytes32(0) && MerkleProof.verify(strategyProof, strategyRoot, leaf)) {
                return true;
            }
        }

        // If we get here, verification failed
        return false;
    }
}
