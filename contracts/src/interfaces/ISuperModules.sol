// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

interface ISuperModules {
    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/
    struct ModuleInfo {
        bytes32 id;
        bool isActive;
        uint128 index;
        uint128 votes;
    }
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ModuleRegistered(address indexed module, bytes32 id, uint128 index);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ID_NOT_VALID();
    error NOT_AUTHORIZED();
    error MODULE_NOT_ACTIVE();
    error ADDRESS_NOT_VALID();
    error ALREADY_REGISTERED();
    error REGISTRATION_PENDING();
    error INVALID_SUPER_REGISTRY();
    error PENDING_REGISTRATION_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Check if a module is active.
    /// @param module_ The address of the module.
    /// @return Whether the module is active.
    function isActive(address module_) external view returns (bool);

    /// @dev Get the number of votes for a module.
    /// @param module_ The address of the module.
    /// @return The number of votes for the module.
    function votes(address module_) external view returns (uint128);

    /// @dev Generate a module ID.
    /// @param module_ The address of the module.
    /// @return The module ID.
    function generateModuleId(address module_) external view returns (bytes32);

    /// @notice Get the number of modules.
    /// @return The number of modules.
    function getModuleCount() external view returns (uint256);

    /// @notice Get the module at a given index.
    /// @param index_ The index of the module.
    /// @return The address of the module.
    function getModuleAtIndex(uint256 index_) external view returns (address);

    /// @notice Get the module info.
    /// @param module_ The address of the module.
    /// @return The module info.
    function getModuleInfo(address module_) external view returns (ModuleInfo memory);

    /// @notice Get the super registry.
    /// @return The super registry.
    function superRegistry() external view returns (address);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Register a module.
    /// @param module_ The address of the module.
    function registerModule(address module_) external;

    /// @notice Accept a module registration.
    /// @param module_ The address of the module.
    function acceptModuleRegistration(address module_) external;

    /// @notice Delist(Unregister) a module.
    /// @param module_ The address of the module.
    function delistModule(address module_) external;

    /// @notice Vote for a module.
    /// @param module_ The address of the module.
    function vote(address module_) external;
}
