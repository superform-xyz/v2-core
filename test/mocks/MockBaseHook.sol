// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract MockBaseHook {
    function getExecutionCaller() public pure returns (address) {
        return address(0);
    }
}
