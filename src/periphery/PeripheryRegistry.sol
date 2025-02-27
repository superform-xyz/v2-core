// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

// Superform
import { IPeripheryRegistry } from "./interfaces/IPeripheryRegistry.sol";

/// @title PeripheryRegistry
/// @author Superform Labs
/// @notice A registry for periphery configurations
contract PeripheryRegistry is AccessControlEnumerable, IPeripheryRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public isHookRegistered;
    address[] public registeredHooks;

    address private treasury;

    uint256 private feeSplit;
    uint256 private proposedFeeSplit;
    uint256 private feeSplitEffectiveTime;

    // Fee split configuration
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant MAX_FEE_SPLIT = 10_000;

    constructor(address owner_, address treasury_) {
        if (owner_ == address(0)) revert INVALID_ACCOUNT();
        if (treasury_ == address(0)) revert INVALID_ADDRESS();
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);

        // Initialize with a default fee split of 20% (2000 basis points)
        feeSplit = 2000;

        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IPeripheryRegistry
    function registerHook(address hook_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isHookRegistered[hook_]) revert HOOK_ALREADY_REGISTERED();
        if (hook_ == address(0)) revert INVALID_ADDRESS();
        isHookRegistered[hook_] = true;
        registeredHooks.push(hook_);
        emit HookRegistered(hook_);
    }

    /// @inheritdoc IPeripheryRegistry
    function unregisterHook(address hook_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!isHookRegistered[hook_]) revert HOOK_NOT_REGISTERED();
        if (hook_ == address(0)) revert INVALID_ADDRESS();
        isHookRegistered[hook_] = false;

        // Remove the hook from the registeredHooks array
        for (uint256 i = 0; i < registeredHooks.length; i++) {
            if (registeredHooks[i] == hook_) {
                // Move the last element to the position of the element to delete
                registeredHooks[i] = registeredHooks[registeredHooks.length - 1];
                // Remove the last element
                registeredHooks.pop();
                break;
            }
        }

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
    function executeFeeSplitUpdate() external {
        if (block.timestamp < feeSplitEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        feeSplit = proposedFeeSplit;
        proposedFeeSplit = 0;
        feeSplitEffectiveTime = 0;

        emit FeeSplitUpdated(feeSplit);
    }

    function setTreasury(address treasury_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (treasury_ == address(0)) revert INVALID_ADDRESS();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
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
    function getTreasury() external view returns (address) {
        return treasury;
    }
}
