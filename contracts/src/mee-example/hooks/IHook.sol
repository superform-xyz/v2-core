// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

interface IHook {
    function build(bytes memory data) external view returns (Execution[] memory executions);
    function totalOps() external view returns (uint256);
}
