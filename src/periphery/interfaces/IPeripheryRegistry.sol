// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IPeripheryRegistry {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error INVALID_ACCOUNT();
    error INVALID_FEE_SPLIT();
    error HOOK_NOT_REGISTERED();
    error TIMELOCK_NOT_EXPIRED();
    error HOOK_ALREADY_REGISTERED();
    error INVALID_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event HookRegistered(address indexed hook);
    event HookUnregistered(address indexed hook);
    event FeeSplitUpdated(uint256 superformFeeSplit);
    event FeeSplitProposed(uint256 superformFeeSplit, uint256 effectiveTime);
    event TreasuryUpdated(address indexed treasury);

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the current Superform fee split.
    /// @return The fee split in basis points (0-10000).
    function getSuperformFeeSplit() external view returns (uint256);

    /// @notice Get all registered hooks
    function getRegisteredHooks() external view returns (address[] memory);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if a hook is registered
    /// @param hook_ The hook to check
    /// @return True if the hook is registered, false otherwise
    function isHookRegistered(address hook_) external view returns (bool);

    /// @notice Register a hook
    /// @param hook_ The hook to register
    function registerHook(address hook_) external;

    /// @notice Unregister a hook
    /// @param hook_ The hook to unregister
    function unregisterHook(address hook_) external;

    /// @dev Propose a new fee split for Superform.
    /// @param feeSplit_ The new fee split in basis points (0-10000).
    function proposeFeeSplit(uint256 feeSplit_) external;

    /// @dev Execute the proposed fee split update after timelock.
    function executeFeeSplitUpdate() external;

    /// @dev Get the treasury address.
    /// @return The treasury address.
    function getTreasury() external view returns (address);

    /// @dev Set the treasury address.
    /// @param treasury_ The new treasury address.
    function setTreasury(address treasury_) external;
}
