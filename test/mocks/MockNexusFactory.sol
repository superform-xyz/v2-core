// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract MockNexusFactory {
    address public precomputed;
    constructor (address _acc) {
        precomputed = _acc;
    }

    function createAccount(bytes memory, bytes32) external view returns (address) {
        return precomputed;
    }
}