// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";

contract SuperRbac is Ownable, ISuperRbac {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => mapping(bytes32 => bool)) private _roles;

    // roles
    /// @inheritdoc ISuperRbac
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    /// @inheritdoc ISuperRbac
    bytes32 public constant SENTINELS_CONFIGURATOR = keccak256("SENTINELS_CONFIGURATOR");
    /// @inheritdoc ISuperRbac
    bytes32 public constant RELAYER_SENTINEL_CONFIGURATOR = keccak256("RELAYER_SENTINEL_CONFIGURATOR");
    /// @inheritdoc ISuperRbac
    bytes32 public constant SUPER_MODULE_CONFIGURATOR = keccak256("SUPER_MODULE_CONFIGURATOR");
    /// @inheritdoc ISuperRbac
    bytes32 public constant RELAYER_SENTINEL_NOTIFIER = keccak256("RELAYER_SENTINEL_NOTIFIER");

    constructor(address owner) Ownable(owner) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
    function setRole(address account_, bytes32 role_, bool allowed_) external override onlyOwner {
        if (account_ == address(0)) revert INVALID_ACCOUNT();
        if (role_ == bytes32(0)) revert INVALID_ROLE();
        _roles[account_][role_] = allowed_;
        emit RoleAdded(account_, role_, allowed_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
    function hasRole(address account_, bytes32 role_) external view override returns (bool) {
        return _roles[account_][role_];
    }
}
