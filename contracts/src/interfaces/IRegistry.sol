// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IRegistryBase {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ItemRegistered(address indexed item, bytes32 indexed id, uint128 indexed index);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error ID_NOT_VALID();
    error ITEM_NOT_ACTIVE();
    error ADDRESS_NOT_VALID();
    error ALREADY_REGISTERED();
    error REGISTRATION_PENDING();
    error PENDING_REGISTRATION_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    struct ItemInfo {
        bytes32 id;
        bool isActive;
        uint128 index;
        uint128 votes;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Check if an item is active
    /// @param item_ The address of the item to check
    function isActive(address item_) external view returns (bool);

    /// @notice Get the number of votes for an item
    /// @param item_ The address of the item to get the votes for
    function votes(address item_) external view returns (uint128);

    /// @notice Get the number of items
    function getItemCount() external view returns (uint256);

    /// @notice Get the item at a given index
    /// @param index_ The index of the item to get
    function getItemAtIndex(uint256 index_) external view returns (address);

    /// @notice Get the information of an item
    /// @param item_ The address of the item to get the information for
    function getItemInfo(address item_) external view returns (ItemInfo memory);

    /// @notice Generate the id of an item
    /// @param item_ The address of the item to generate the id for
    function generateItemId(address item_) external view returns (bytes32);
}

interface IHooksRegistry {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Vote for an item
    /// @param item_ The address of the item to vote for
    function vote(address item_) external;

    /// @notice Register an item
    /// @param item_ The address of the item to register
    function registerHook(address item_) external;

    /// @notice Delist an item
    /// @param item_ The address of the item to delist
    function delistHook(address item_) external;

    /// @notice Accept a pending item registration
    /// @param item_ The address of the item to accept the registration for
    function acceptHookRegistration(address item_) external;
}
