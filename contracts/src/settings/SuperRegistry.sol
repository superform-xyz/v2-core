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
    // -- executors
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_EXECUTOR_ID = keccak256("SUPER_EXECUTOR_ID");
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_GATEWAY_EXECUTOR_ID = keccak256("SUPER_GATEWAY_EXECUTOR_ID");

    // -- RBAC
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_RBAC_ID = keccak256("SUPER_RBAC_ID");
    // -- SuperPositions
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_POSITIONS_ID = keccak256("SUPER_POSITIONS_ID");

    // -- registries
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_LEDGER_ID = keccak256("SUPER_LEDGER_ID");

    // -- sentinels
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SUPER_POSITION_SENTINEL_ID = keccak256("SUPER_POSITION_SENTINEL_ID");
    // -- bridges
    /// @inheritdoc ISuperRegistry
    bytes32 public constant ACROSS_GATEWAY_ID = keccak256("ACROSS_GATEWAY_ID");

    // -- storage
    /// @inheritdoc ISuperRegistry
    bytes32 public constant SHARED_STATE_ID = keccak256("SHARED_STATE_ID");

    // -- paymaster
    /// @inheritdoc ISuperRegistry
    bytes32 public constant PAYMASTER_ID = keccak256("PAYMASTER_ID");

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
