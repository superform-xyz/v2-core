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
    uint256 public constant MANAGER_KEY = 0x3;
    uint256 public constant SUPER_ACTIONS_CONFIGURATOR_KEY = 0x777;
    // registry
    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");

    // ids
    bytes32 public constant ROLES_ID = keccak256("ROLES");


    // yieldSourceIds
    bytes32 public constant RANDOM_YIELD_SOURCE_ID = keccak256("RANDOM_YIELD_SOURCE_ID");
}
