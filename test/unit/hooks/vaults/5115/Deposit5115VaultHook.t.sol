// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {Deposit5115VaultHook} from "../../../../../src/core/hooks/vaults/5115/Deposit5115VaultHook.sol";
import {ISuperHook} from "../../../../../src/core/interfaces/ISuperHook.sol";
import {MockERC20} from "../../../../mocks/MockERC20.sol";
import {MockHook} from "../../../../mocks/MockHook.sol";
import {BaseHook} from "../../../../../src/core/hooks/BaseHook.sol";
import {Helpers} from "../../../../utils/Helpers.sol";

contract Deposit5115VaultHookTest is Helpers {
    Deposit5115VaultHook public hook;

    bytes32 yieldSourceOracleId;
    address yieldSource;
    address token;
    uint256 amount;

    function setUp() public {
        yieldSourceOracleId = bytes32(keccak256("YIELD_SOURCE_ORACLE_ID"));
        yieldSource = address(this);
        token = address(new MockERC20("Token", "TKN", 18));
        amount = 1000;

        hook = new Deposit5115VaultHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.INFLOW));
    }

    function test_NativePOC() public {
        token = address(0);

        bytes memory data = _encodeData(false);
        // this shouldn't revert anymore after the fix
        //vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), data);
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }


    function test_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_Native() public view {
        bytes memory data = abi.encodePacked(
            yieldSourceOracleId, yieldSource, address(0), amount, amount, false, address(0), uint256(0)
        );
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, amount);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        address _yieldSource = yieldSource;

        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));

        yieldSource = _yieldSource;
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), _encodeData(false));
    }

    function test_Build_RevertIf_AmountZero() public {
        amount = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_DecodeAmount() public view {
        bytes memory data = _encodeData(false);
        uint256 decodedAmount = hook.decodeAmount(data);
        assertEq(decodedAmount, amount);
    }

    function test_PreAndPostExecute() public {
        yieldSource = token; // for the .balanceOf call
        _getTokens(token, address(this), amount);
        bytes memory data = _encodeData(false);
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), amount);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function _encodeData(bool usePrevHook) internal view returns (bytes memory) {
        return abi.encodePacked(
            yieldSourceOracleId, yieldSource, token, amount, amount, usePrevHook, address(0), uint256(0)
        );
    }
}
