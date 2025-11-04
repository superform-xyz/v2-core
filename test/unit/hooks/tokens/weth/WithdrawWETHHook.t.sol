// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { WithdrawWETHHook } from "../../../../../src/hooks/tokens/weth/WithdrawWETHHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";

contract WithdrawWETHHookTest is Helpers {
    using BytesLib for bytes;

    WithdrawWETHHook public hook;

    address weth;
    uint256 amount;

    function setUp() public {
        weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        amount = 1 ether;
        hook = new WithdrawWETHHook(weth);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.WETH(), weth);
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Build() public {
        // Mock WETH balance check
        vm.mockCall(
            weth,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(amount)
        );
        
        bytes memory data = _encodeData(false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        
        assertEq(executions.length, 3);
        
        // Check preExecute
        assertEq(executions[0].target, address(hook));
        assertEq(executions[0].value, 0);
        
        // Check main execution
        assertEq(executions[1].target, weth);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeWithSignature("withdraw(uint256)", amount));
        
        // Check postExecute
        assertEq(executions[2].target, address(hook));
        assertEq(executions[2].value, 0);
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2 ether;
        
        // Mock WETH balance check
        vm.mockCall(
            weth,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(prevHookAmount)
        );
        
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, weth));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);
        
        assertEq(executions.length, 3);
        assertEq(executions[1].target, weth);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeWithSignature("withdraw(uint256)", prevHookAmount));
    }

    function test_Build_RevertIf_ZeroAmount() public {
        amount = 0;
        vm.expectRevert(WithdrawWETHHook.ZERO_WETH_AMOUNT.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_Build_RevertIf_ZeroAmountFromPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, weth));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        bytes memory data = _encodeData(true);
        vm.expectRevert(WithdrawWETHHook.ZERO_WETH_AMOUNT.selector);
        hook.build(mockPrevHook, address(this), data);
    }

    function test_Build_RevertIf_InsufficientBalance() public {
        // Mock insufficient WETH balance
        vm.mockCall(
            weth,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(amount - 1)
        );
        
        vm.expectRevert(WithdrawWETHHook.INSUFFICIENT_WETH_BALANCE.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_Build_RevertIf_InsufficientBalanceFromPrevHook() public {
        uint256 prevHookAmount = 2 ether;
        
        // Mock insufficient WETH balance
        vm.mockCall(
            weth,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(amount)
        );
        
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, weth));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(true);
        vm.expectRevert(WithdrawWETHHook.INSUFFICIENT_WETH_BALANCE.selector);
        hook.build(mockPrevHook, address(this), data);
    }

    function test_PreAndPostExecute() public {
        uint256 initialWethBalance = 5 ether;
        
        // Mock initial WETH balance
        vm.mockCall(
            weth,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(initialWethBalance)
        );
        
        hook.setExecutionContext(address(this));
        hook.preExecute(address(0), address(this), _encodeData(false));
        assertEq(hook.getOutAmount(address(this)), initialWethBalance);

        // Mock reduced WETH balance after withdrawal
        vm.mockCall(
            weth,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(initialWethBalance - amount)
        );
        
        hook.postExecute(address(0), address(this), _encodeData(false));
        assertEq(hook.getOutAmount(address(this)), amount);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = hook.inspect(data);
        assertEq(argsEncoded.length, 20); // Only one address (20 bytes)

        assertEq(BytesLib.toAddress(argsEncoded, 0), weth);
    }

    function _encodeData(bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(amount, usePrev);
    }
}