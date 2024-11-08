// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISuperRegistry } from "../interfaces/ISuperRegistry.sol";

contract SuperRegistryMock is Ownable, ISuperRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(bytes32 => address) public addresses;

    // roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SENTINELS_MANAGER = keccak256("SENTINELS_MANAGER");
    bytes32 public constant RELAYER_SENTINEL_MANAGER = keccak256("RELAYER_SENTINEL_MANAGER");

    bytes32 public constant HOOK_EXECUTOR_ROLE = keccak256("HOOK_EXECUTOR_ROLE");
    bytes32 public constant HOOK_REGISTRATION_ROLE = keccak256("HOOK_REGISTRATION_ROLE");

    // ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");
    bytes32 public constant RELAYER_ID = keccak256("RELAYER");
    bytes32 public constant RELAYER_SENTINEL_ID = keccak256("RELAYER_SENTINEL");

    constructor(address owner) Ownable(owner) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER
    //////////////////////////////////////////////////////////////*/
    /// @dev Set the address of an ID.
    /// @param id_ The ID.
    /// @param address_ The address.
    function setAddress(bytes32 id_, address address_) external onlyOwner {
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
