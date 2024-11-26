// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

contract SuperRegistry is Ownable, ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;

    // ids
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_RBAC_ID = keccak256("SUPER_RBAC_ID");
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_POSITIONS_ID = keccak256("SUPER_POSITIONS_ID");

    constructor(address owner) Ownable(owner) { }

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
    function getAddress(bytes32 id_) external view override returns (address) {
        return addresses[id_];
    }
}
