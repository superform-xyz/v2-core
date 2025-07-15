// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { ApproveERC20Hook } from "../../../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";

contract ApproveERC20HookTest is Helpers {
    using BytesLib for bytes;

    ApproveERC20Hook public hook;

    address token;
    address spender;
    uint256 amount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        token = address(_mockToken);

        spender = address(this);
        amount = 1000;

        hook = new ApproveERC20Hook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Build() public view {
        bytes memory data = _encodeData(false);
        Execution[] memory executions = hook.build(address(0), address(0), data);
        assertEq(executions.length, 4);
        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, token);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);
    }

    function test_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 4);
        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        assertEq(executions[2].target, token);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        address _token = token;

        token = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), abi.encodePacked(address(0), spender, amount, false));

        token = _token;
        spender = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(false));
    }

    function test_PostExecute() public {
        hook.postExecute(address(0), address(this), _encodeData(false));
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_PreAndPostExecute_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        hook.postExecute(mockPrevHook, address(this), _encodeData(true));
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_Inspector() public view {
        bytes memory data = _encodeData(false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        assertEq(BytesLib.toAddress(argsEncoded, 0), token);
        assertEq(BytesLib.toAddress(argsEncoded, 20), spender);
    }

    function _encodeData(bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(token, spender, amount, usePrev);
    }
}
