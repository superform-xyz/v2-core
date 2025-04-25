// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { BatchTransferFromHook } from "../../../../../src/core/hooks/tokens/permit2/BatchTransferFromHook.sol";

contract BatchTransferFromHookTest is BaseTest {
    BatchTransferFromHook public hook;

    address usdc;
    address weth;
    address dai;
    function setUp() public override {
        super.setUp();

        hook = new BatchTransferFromHook(PERMIT2);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_ZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new BatchTransferFromHook(address(0));
    }
}

