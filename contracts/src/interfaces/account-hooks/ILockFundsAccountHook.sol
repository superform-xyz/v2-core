// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface ILockFundsAccountHook {
    function lock(address account, address asset, uint256 amount) external;
    function unlock(address account, address asset, uint256 amount) external;
    function clean(address account) external;
}

