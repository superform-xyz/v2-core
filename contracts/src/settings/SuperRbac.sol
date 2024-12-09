// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISuperRbac } from "src/interfaces/ISuperRbac.sol";

contract SuperRbac is Ownable, ISuperRbac {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => mapping(bytes32 => bool)) private _roles;

    // roles
    /**
     *     BRIDGE_GATEWAY - can execute calls on SuperGatewayExecutor
     *     SUPER_ADMIN_ROLE - generic admin role; should have access for everything
     *     EXECUTOR_CONFIGURATOR - can configure super executors
     *     HOOK_REGISTRY_CONFIGURATOR - can configure hooks registry
     *     STRATEGIES_REGISTRY_CONFIGURATOR - can configure strategies registry
     *     SENTINEL_CONFIGURATOR - can configure super sentinel
     */
    /// @inheritdoc ISuperRbac
    bytes32 public constant BRIDGE_GATEWAY = keccak256("BRIDGE_GATEWAY");
    /// @inheritdoc ISuperRbac
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    /// @inheritdoc ISuperRbac
    bytes32 public constant EXECUTOR_CONFIGURATOR = keccak256("EXECUTOR_CONFIGURATOR");
    /// @inheritdoc ISuperRbac
    bytes32 public constant HOOK_REGISTRY_CONFIGURATOR = keccak256("HOOK_REGISTRY_CONFIGURATOR");
    /// @inheritdoc ISuperRbac
    bytes32 public constant STRATEGIES_REGISTRY_CONFIGURATOR = keccak256("STRATEGIES_REGISTRY_CONFIGURATOR");
    /// @inheritdoc ISuperRbac
    bytes32 public constant SENTINEL_CONFIGURATOR = keccak256("SENTINEL_CONFIGURATOR");

    constructor(address owner) Ownable(owner) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
    function setRole(address account_, bytes32 role_, bool allowed_) external override onlyOwner {
        if (account_ == address(0)) revert INVALID_ACCOUNT();
        if (role_ == bytes32(0)) revert INVALID_ROLE();
        _roles[account_][role_] = allowed_;
        emit RoleUpdated(account_, role_, allowed_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
    function hasRole(address account_, bytes32 role_) external view override returns (bool) {
        return _roles[account_][role_];
    }
}
