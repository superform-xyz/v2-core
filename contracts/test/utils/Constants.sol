// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

abstract contract Constants {
    // amounts
    uint256 public constant SMALL = 1 ether;
    uint256 public constant MEDIUM = 5 ether;
    uint256 public constant LARGE = 20 ether;
    uint256 public constant EXTRA_LARGE = 100 ether;

    // keys
    uint256 public constant USER1_KEY = 0x1;
    uint256 public constant USER2_KEY = 0x2;

    // registry
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SNAP_REGISTRATION_ROLE = keccak256("HOOK_REGISTRATION_ROLE");

    // ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");

    // smart accounts
    uint256 public constant MODULE_TYPE_VALIDATOR = 1;
    uint256 public constant MODULE_TYPE_EXECUTOR = 2;
    uint256 public constant MODULE_TYPE_HOOK = 3;
}
