// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { MockHook } from "../../../mocks/MockHook.sol";
import { ISuperHook, Execution } from "../../../../src/core/interfaces/ISuperHook.sol";

import { PendleRouterSwapHook } from "../../../../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";

contract CantinaIntegrationPendleRouterSwapHookTest is Test {
    address constant PENDLE_ROUTER = address(0x888888888889758F76e7103c6CbF23ABbF58F946);

    MockHook public prevHook;
    ISuperHook public hook;

    address public user;

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

    function _processHook(address account, bytes memory hookData) internal {
        console.log("=== hookData ===");
        console.logBytes(hookData);

        console.log("=== BUILDING ===");
        Execution[] memory executions = hook.build(address(prevHook), account, hookData);
        vm.startPrank(account);
        for (uint256 i = 0; i < executions.length; i++) {
            console.log("==== EXECUTION %s ===", i);
            (bool success, bytes memory data) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
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

    function test_execute_swapExactPtForToken_decodeTokenOut() public {
        // for https://cantina.xyz/code/ba62fa4e-f933-4eec-b9ac-868325f4a694/findings/310
        // https://cantina.xyz/code/ba62fa4e-f933-4eec-b9ac-868325f4a694/findings/311
        // https://explorer.phalcon.xyz/tx/eth/0x202cfd7e8dae561af172274dcfce04703daeaf63852c0872208d030fa71a457e
        fork("eth", 22_581_741 - 1);
        user = address(0x708Db604264455673e63D82e8a6bbb66Ab856617);
        hook = ISuperHook(address(new PendleRouterSwapHook(PENDLE_ROUTER)));

        bytes memory hookData;
        {
            // copied from inputData of tx
            bytes memory txData =
                hex"594a88cc000000000000000000000000708db604264455673e63d82e8a6bbb66ab85661700000000000000000000000085667e484a32d884010cf16427d90049ccf46e970000000000000000000000000000000000000000000000554a360376a755038500000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000001e000000000000000000000000090d2af7d622ca3141efa4d8f1f24d86e5974cc8f00000000000000000000000000000000000000000000005500d51af39d8b1cf900000000000000000000000090d2af7d622ca3141efa4d8f1f24d86e5974cc8f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

            bytes4 placeholder = bytes4(0x00);
            // market
            address yieldSource = address(0x85667e484a32d884010Cf16427D90049CCf46e97);
            bool usePrevHookAmount = false;
            uint256 value = 0;

            hookData = abi.encodePacked(placeholder, yieldSource, usePrevHookAmount, value, txData);
        }

        // fails in preExecute -> _getBalance-> _decodeTokenOut(data[57:]);
        // 0x00000000000000000000000000000000000000a0::balanceOf(..)
        _processHook(user, hookData);
    }
}
