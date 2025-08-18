// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IAccountInitializer {
    function initializeAccount(bytes calldata initData) external payable;
}
