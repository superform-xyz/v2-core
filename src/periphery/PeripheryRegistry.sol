// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

// Superform
import { IPeripheryRegistry } from "./interfaces/IPeripheryRegistry.sol";

contract PeripheryRegistry is AccessControlEnumerable, IPeripheryRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public isHookRegistered;
    address[] public registeredHooks;

    uint256 private feeSplit;
    uint256 private proposedFeeSplit;
    uint256 private feeSplitEffectiveTime;

    // Slippage tolerance configuration
    uint256 private slippageTolerance;
    uint256 private proposedSlippageTolerance;
    uint256 private slippageToleranceEffectiveTime;

    // Fee split configuration
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant MAX_FEE_SPLIT = 10_000;
    uint256 private constant MAX_SLIPPAGE_TOLERANCE = 1000; // 10% max slippage

    constructor(address owner_) {
        if (owner_ == address(0)) revert INVALID_ACCOUNT();
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);

        // Initialize with a default fee split of 20% (2000 basis points)
        feeSplit = 2000;

        // Initialize with a default slippage tolerance of 1% (100 basis points)
        slippageTolerance = 100;
    }

    modifier onlyHooksManager() {
        if (!hasRole(keccak256("HOOKS_MANAGER_ROLE"), msg.sender)) revert NOT_AUTHORIZED();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IPeripheryRegistry
    function registerHook(address hook_) external onlyHooksManager {
        if (isHookRegistered[hook_]) revert HOOK_ALREADY_REGISTERED();
        isHookRegistered[hook_] = true;
        registeredHooks.push(hook_);
        emit HookRegistered(hook_);
    }

    /// @inheritdoc IPeripheryRegistry
    function unregisterHook(address hook_) external onlyHooksManager {
        if (!isHookRegistered[hook_]) revert HOOK_NOT_REGISTERED();
        isHookRegistered[hook_] = false;
        emit HookUnregistered(hook_);
    }

    /// @inheritdoc IPeripheryRegistry
    function proposeFeeSplit(uint256 feeSplit_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (feeSplit_ > MAX_FEE_SPLIT) revert INVALID_FEE_SPLIT();

        proposedFeeSplit = feeSplit_;
        feeSplitEffectiveTime = block.timestamp + ONE_WEEK;

        emit FeeSplitProposed(feeSplit_, feeSplitEffectiveTime);
    }

    /// @inheritdoc IPeripheryRegistry
    function proposeSlippageTolerance(uint256 slippageTolerance_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (slippageTolerance_ > MAX_SLIPPAGE_TOLERANCE) revert INVALID_SLIPPAGE_TOLERANCE();

        proposedSlippageTolerance = slippageTolerance_;
        slippageToleranceEffectiveTime = block.timestamp + ONE_WEEK;

        emit SlippageToleranceProposed(slippageTolerance_, slippageToleranceEffectiveTime);
    }

    /*//////////////////////////////////////////////////////////////
                                 PUBLIC METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IPeripheryRegistry
    function executeFeeSplitUpdate() external {
        if (block.timestamp < feeSplitEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        feeSplit = proposedFeeSplit;
        proposedFeeSplit = 0;
        feeSplitEffectiveTime = 0;

        emit FeeSplitUpdated(feeSplit);
    }

    /// @inheritdoc IPeripheryRegistry
    function executeSlippageToleranceUpdate() external {
        if (block.timestamp < slippageToleranceEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        slippageTolerance = proposedSlippageTolerance;
        proposedSlippageTolerance = 0;
        slippageToleranceEffectiveTime = 0;

        emit SlippageToleranceUpdated(slippageTolerance);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IPeripheryRegistry
    function getRegisteredHooks() external view returns (address[] memory) {
        return registeredHooks;
    }

    /// @inheritdoc IPeripheryRegistry
    function getSuperformFeeSplit() external view returns (uint256) {
        return feeSplit;
    }

    /// @inheritdoc IPeripheryRegistry
    function getSlippageTolerance() external view returns (uint256) {
        return slippageTolerance;
    }
}
