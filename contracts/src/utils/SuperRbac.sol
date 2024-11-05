// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.28;

// external
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// Superform
import { ISuperRbac } from "../interfaces/ISuperRbac.sol";

contract SuperRbac is Ownable, ISuperRbac {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => mapping(bytes32 => bool)) private _roles;

    constructor(address owner) Ownable(owner) { }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Add a role to an account.
    /// @param account_ The address of the account.
    /// @param role_ The role to add.
    /// @param allowed_ Whether the role is allowed.
    function setRole(address account_, bytes32 role_, bool allowed_) public onlyOwner {
        if (account_ == address(0)) revert INVALID_ACCOUNT();
        if (role_ == bytes32(0)) revert INVALID_ROLE();
        _roles[account_][role_] = allowed_;
        emit RoleAdded(account_, role_, allowed_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperRbac
    function hasRole(address account_, bytes32 role_) public view override returns (bool) {
        return _roles[account_][role_];
    }
}
