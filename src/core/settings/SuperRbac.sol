// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol"; 

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";

contract SuperRbac is AccessControlEnumerable, ISuperRbac {
    /*//////////////////////////////////////////////////////////////
                                 ROLES
    //////////////////////////////////////////////////////////////*/
    // roles
    /**
     *     BRIDGE_GATEWAY - can execute calls on SuperGatewayExecutor
     */

    constructor(address owner) {
        if (owner == address(0)) revert INVALID_ACCOUNT();
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
}
