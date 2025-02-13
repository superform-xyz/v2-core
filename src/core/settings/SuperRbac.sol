// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol"; 

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";

contract SuperRbac is AccessControl, ISuperRbac {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/
    // roles
    /**
     *     BRIDGE_GATEWAY - can execute calls on SuperGatewayExecutor
     */
    /// @inheritdoc ISuperRbac
    bytes32 public constant BRIDGE_GATEWAY = keccak256("BRIDGE_GATEWAY");

    constructor(address owner) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
     }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
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

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
    function hasRole(address account_, bytes32 role_) external view override returns (bool) {
        return super.hasRole(role_, account_);
    }
}
