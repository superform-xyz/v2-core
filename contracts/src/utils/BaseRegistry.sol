// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IRegistry } from "src/interfaces/registries/IRegistry.sol";

abstract contract BaseRegistry is IRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    string public name;

    address[] public items;
    mapping(address => ItemInfo) public pendingItems;
    mapping(address => ItemInfo) public registeredItems;

    mapping(address => bool) private _votedForItem;

    constructor(string memory name_) {
        name = name_;
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IRegistry
    function isActive(address item_) external view returns (bool) {
        return registeredItems[item_].isActive;
    }

    /// @inheritdoc IRegistry
    function votes(address item_) external view returns (uint128) {
        return registeredItems[item_].votes;
    }

    /// @inheritdoc IRegistry
    function getItemCount() external view returns (uint256) {
        return items.length;
    }

    /// @inheritdoc IRegistry
    function getItemAtIndex(uint256 index_) external view returns (address) {
        return items[index_];
    }

    /// @inheritdoc IRegistry
    function getItemInfo(address item_) external view returns (ItemInfo memory) {
        return registeredItems[item_];
    }

    /// @inheritdoc IRegistry
    function generateItemId(address item_, address sender_) public view returns (bytes32) {
        return keccak256(abi.encodePacked(item_, sender_, name));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Vote for an item
    /// @param item_ The address of the item to vote for
    function _vote(address item_) internal {
        if (item_ == address(0)) revert ADDRESS_NOT_VALID();
        if (!registeredItems[item_].isActive) revert ITEM_NOT_ACTIVE();

        _votedForItem[item_] = true;
        registeredItems[item_].votes++;
    }

    /// @notice Register an item
    /// @param item_ The address of the item to register
    function _registerItem(address item_, address sender_) internal {
        if (item_ == address(0)) revert ADDRESS_NOT_VALID();
        if (registeredItems[item_].isActive) revert ALREADY_REGISTERED();
        if (pendingItems[item_].id != bytes32(0)) revert REGISTRATION_PENDING();

        bytes32 id = generateItemId(item_, sender_);
        if (id == bytes32(0)) revert ID_NOT_VALID();

        pendingItems[item_] = ItemInfo({ id: id, isActive: false, index: 0, votes: 0 });
    }

    /// @notice Delist an item
    /// @param item_ The address of the item to delist
    function _delistItem(address item_) internal {
        if (!(registeredItems[item_].isActive || pendingItems[item_].id != bytes32(0))) {
            revert ADDRESS_NOT_VALID();
        }
        delete registeredItems[item_];
        delete pendingItems[item_];
    }

    /// @notice Accept a pending item registration
    /// @param item_ The address of the item to accept the registration for
    function _acceptItemRegistration(address item_) internal {
        if (item_ == address(0)) revert ADDRESS_NOT_VALID();
        if (pendingItems[item_].id == bytes32(0)) revert PENDING_REGISTRATION_NOT_VALID();

        // remove pending
        bytes32 _id = pendingItems[item_].id;
        delete pendingItems[item_];

        // add registered
        items.push(item_);
        uint128 index = uint128(items.length - 1);
        registeredItems[item_] = ItemInfo({ id: _id, isActive: true, index: uint128(index), votes: 0 });
        emit ItemRegistered(item_, _id, uint128(index));
    }
}
