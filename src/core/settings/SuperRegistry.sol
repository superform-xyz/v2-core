// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

contract SuperRegistry is ISuperRegistry, Ownable {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;
    mapping(bytes32 => mapping(address => bool)) private roles;

    constructor(address owner) Ownable(owner) {
        if (owner == address(0)) revert INVALID_ACCOUNT();
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRegistry

    /// @inheritdoc ISuperRegistry
    function setAddress(bytes32 id_, address address_) external override onlyOwner {
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
