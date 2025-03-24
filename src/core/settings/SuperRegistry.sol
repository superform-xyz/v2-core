// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

/// @title SuperRegistry
/// @author Superform Labs
/// @notice A registry for storing addresses of contracts
contract SuperRegistry is Ownable2Step, ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;

    constructor(address owner_) Ownable(owner_) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
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
    function getAddress(bytes32 id_) external view override returns (address address_) {
        address_ = addresses[id_];
        if (address_ == address(0)) revert INVALID_ADDRESS();
    }
}
