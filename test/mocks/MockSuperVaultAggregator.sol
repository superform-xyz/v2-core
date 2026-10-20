// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ISuperVaultAggregator } from "../../src/interfaces/ISuperVaultAggregator.sol";

/// @notice Minimal mock of the SuperVaultAggregator for paymaster unit tests: lets a test declare which
///         (manager, strategy) pairs are "main manager".
contract MockSuperVaultAggregator is ISuperVaultAggregator {
    mapping(address manager => mapping(address strategy => bool)) public mainManager;

    function setMainManager(address manager, address strategy, bool isMain) external {
        mainManager[manager][strategy] = isMain;
    }

    function isMainManager(address manager, address strategy) external view returns (bool) {
        return mainManager[manager][strategy];
    }
}
