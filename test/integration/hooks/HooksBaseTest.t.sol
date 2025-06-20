// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;


import "forge-std/Test.sol";
import "forge-std/console.sol";

import {MockHook} from "../../mocks/MockHook.sol";
import {ISuperHook, ISuperHookResult, ISuperHookResultOutflow, Execution} from "../../../src/core/interfaces/ISuperHook.sol";

contract HooksBaseTest is Test {
    function fork(string memory chainName, uint256 blockNumber) internal {
        vm.createSelectFork(getRpc(chainName), blockNumber);
    }

    function getRpc(string memory chainName) internal pure returns (string memory) {
        if (keccak256(bytes(chainName)) == keccak256("eth")) {
          return "https://eth-mainnet.public.blastapi.io";
        } else {
          revert(string(abi.encodePacked("BaseTest.getRpc: unsupported chain ", chainName)));
        }
    }

    function setUp() public virtual {
        prevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(0));
    }

    MockHook public prevHook;
    ISuperHook public hook;

    address public user;


    function _processHook(address account, bytes memory hookData) internal {
      console.log("=== hookData ===");
      console.logBytes(hookData);

      console.log("=== BUILDING ===");
      Execution[] memory executions = hook.build(address(prevHook), account, hookData);
      vm.startPrank(account);
      for (uint256 i = 0; i < executions.length; i++) {
        console.log("==== EXECUTION %s ===", i);
        (bool success, bytes memory data) = executions[i].target.call{value: executions[i].value}(executions[i].callData);
        if (!success) {
          console.log("\t=== FAILED ===");
          console.logBytes(data);
          assembly ("memory-safe") {
            revert(add(data, 0x20), mload(data))
          }
        }
      }
      vm.stopPrank();
    }
}


