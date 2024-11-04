// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

abstract contract Constants {
    // amounts
    uint256 public constant SMALL = 10 ether;
    uint256 public constant MEDIUM = 100 ether;
    uint256 public constant LARGE = 1000 ether;
    uint256 public constant EXTRA_LARGE = 10000 ether;

    // keys
    uint256 public constant USER1_KEY = 0x1;
    uint256 public constant USER2_KEY = 0x2;
}