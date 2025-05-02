// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Withdraw7540VaultHook } from "../../../../../src/core/hooks/vaults/7540/Withdraw7540VaultHook.sol";
import { ISuperHook } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract Withdraw7540VaultHookTest is Helpers {
    Withdraw7540VaultHook public hook;

    bytes4 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;

    function setUp() public {
        yieldSourceOracleId = bytes4(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        token = address(new MockERC20("Token", "TKN", 18));
        amount = 1000;

        hook = new Withdraw7540VaultHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 1);
        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, yieldSource);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        address _yieldSource = yieldSource;

        // yieldSource is address(0)
        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));

        // account is address(0)
        yieldSource = _yieldSource;
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), _encodeData(false, false));
    }

    function test_Build_RevertIf_AmountZero() public {
        amount = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_PreAndPostExecuteX() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);
        bytes memory data = _encodeData(false, false);
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount);

        bool lockForSp = hook.lockForSP();
        assertEq(lockForSp, false);

        address spToken = hook.spToken();
        assertEq(spToken, yieldSource);

        address asset = hook.asset();
        assertEq(asset, token);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);
    }

    function test_ReplaceCalldata() public view {
        bytes memory data = _encodeData(false, false);

        bytes memory replacedData = hook.replaceCalldataAmount(data, 1);
        assertEq(replacedData.length, data.length);

        uint256 replacedAmount = hook.decodeAmount(replacedData);
        assertEq(replacedAmount, 1);
    }

    function _encodeData(bool usePrevHook, bool lockForSp) internal view returns (bytes memory) {
        return abi.encodePacked(yieldSourceOracleId, yieldSource, amount, usePrevHook, lockForSp);
    }
}
