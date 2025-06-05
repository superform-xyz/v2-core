// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ApproveAndRedeem5115VaultHook} from
    "../../../../../src/core/hooks/vaults/5115/ApproveAndRedeem5115VaultHook.sol";
import {ISuperHook} from "../../../../../src/core/interfaces/ISuperHook.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {BaseHook} from "../../../../../src/core/hooks/BaseHook.sol";
import {MockERC20} from "../../../../mocks/MockERC20.sol";
import {MockHook} from "../../../../mocks/MockHook.sol";
import {Helpers} from "../../../../utils/Helpers.sol";

contract ApproveAndRedeem5115VaultHookTest is Helpers {
    ApproveAndRedeem5115VaultHook public hook;

    bytes4 yieldSourceOracleId;
    address yieldSource;
    address tokenIn;
    address tokenOut;
    uint256 shares;
    uint256 minTokenOut;
    bool burnFromInternalBalance;
    bool usePrevHook;
    bool lockForSp;

    function setUp() public {
        yieldSourceOracleId = bytes4(bytes(ERC5115_YIELD_SOURCE_ORACLE_KEY));
        yieldSource = address(this);
        tokenIn = address(new MockERC20("TokenIn", "TIN", 18));
        tokenOut = address(new MockERC20("TokenOut", "TOUT", 18));
        shares = 1000;
        minTokenOut = 1000;
        burnFromInternalBalance = false;
        usePrevHook = false;
        lockForSp = false;

        hook = new ApproveAndRedeem5115VaultHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.OUTFLOW));
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeData(false);
        bytes memory newCalldata = hook.replaceCalldataAmount(data, 1000);
        assertEq(newCalldata.length, data.length);
    }

    function test_Build_ApproveAndRedeem_5115_Hook() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 2);
        assertEq(executions[0].target, tokenIn);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_ApproveAndRedeem_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, tokenIn));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount);

        bytes memory data = _encodeData(true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 2);

        assertEq(executions[0].target, tokenIn);
        assertEq(executions[0].value, 0);
        assertGt(executions[0].callData.length, 0);

        assertEq(executions[1].target, yieldSource);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

    }

    function test_Build_ApproveAndRedeem_RevertIf_AddressZero() public {
        address _yieldSource = yieldSource;

        yieldSource = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));

        yieldSource = _yieldSource;
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), _encodeData(false));
    }

    function test_Build_ApproveAndRedeem_RevertIf_SharesZero() public {
        shares = 0;
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_ApproveAndRedeem_DecodeAmount() public view {
        bytes memory data = _encodeData(false);
        uint256 decodedAmount = hook.decodeAmount(data);
        assertEq(decodedAmount, shares);
    }

    function test_ApproveAndRedeem_PreAndPostExecute() public {
        yieldSource = tokenIn; // for the .balanceOf call
        _getTokens(tokenIn, address(this), shares);
        bytes memory data = _encodeData(false);
        hook.preExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), shares);

        hook.postExecute(address(0), address(this), data);
        assertEq(hook.outAmount(), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function _encodeData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return abi.encodePacked(
            yieldSourceOracleId,
            yieldSource,
            tokenIn,
            tokenOut,
            shares,
            minTokenOut,
            burnFromInternalBalance,
            usePrevHookAmount,
            address(0),
            uint256(0)
        );
    }
}
