// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveAndDeposit4626VaultHook } from "../../../../../src/core/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { ISuperHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { console2 } from "forge-std/console2.sol";

contract ApproveAndDeposit4626VaultHookTest is BaseTest {
    ApproveAndDeposit4626VaultHook public hook;

    bytes4 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;

    function setUp() public override { 
        super.setUp();

        yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        token = address(new MockERC20("Token", "TKN", 18));
        amount = 1000;

        hook = new ApproveAndDeposit4626VaultHook(address(this));
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.INFLOW));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 4);
        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0); 

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0); 

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0); 

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0); 
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);
        
        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 4);
        assertEq(executions[0].target, token);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0); 

        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0); 

        assertEq(executions[2].target, yieldSource);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0); 

        assertEq(executions[3].target, token);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0); 
    }

    function test_Build_RevertIf_AddressZero() public {
        address _yieldSource = yieldSource;

        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));

        yieldSource = _yieldSource;
        token = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_Build_RevertIf_AmountZero() public {
        amount = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_DecodeAmount() public view {
        bytes memory data = _encodeData(false, false);
        uint256 decodedAmount = hook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);
        bytes memory data = _encodeData(false, false);
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount);


        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);    
    }

    function _encodeData(bool usePrevHook, bool lockForSp) internal view returns (bytes memory) {
        return abi.encodePacked(
            yieldSourceOracleId,
            yieldSource,
            token,
            amount,
            usePrevHook,
            lockForSp
        );
    }
}