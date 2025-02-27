// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

contract SuperRegistry is AccessControlEnumerable, ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;

    constructor(address owner) {
        if (owner == address(0)) revert INVALID_ACCOUNT();
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRegistry
    function setRole(address account_, bytes32 role_, bool allowed_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (account_ == address(0)) revert INVALID_ACCOUNT();
        if (role_ == bytes32(0)) revert INVALID_ROLE();
        if (allowed_) {
            _grantRole(role_, account_);
        } else {
            _revokeRole(role_, account_);
        }
        emit RoleUpdated(account_, role_, allowed_);
    }

    /// @inheritdoc ISuperRegistry
    function setAddress(bytes32 id_, address address_) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (address_ == address(0)) revert INVALID_ADDRESS();
        addresses[id_] = address_;
        emit AddressSet(id_, address_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRegistry
    function getAddress(bytes32 id_) public view override returns (address address_) {
        address_ = addresses[id_];
        if (address_ == address(0)) revert INVALID_ADDRESS();
    }


}
