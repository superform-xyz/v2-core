// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

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
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");

    // ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");
    bytes32 public constant RELAYER_ID = keccak256("RELAYER");
    bytes32 public constant RELAYER_SENTINEL_ID = keccak256("RELAYER_SENTINEL");

    // smart accounts
    uint256 public constant MODULE_TYPE_VALIDATOR = 1;
    uint256 public constant MODULE_TYPE_EXECUTOR = 2;
    uint256 public constant MODULE_TYPE_HOOK = 3;
}
