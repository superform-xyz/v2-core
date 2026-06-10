// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { TransferHook } from "../../../../src/hooks/tokens/TransferHook.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

contract TransferHookTest is Helpers {
    using BytesLib for bytes;

    TransferHook public hook;
    address public NATIVE_TOKEN = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    address token;
    address to;
    uint256 amount;

    function setUp() public {
        MockERC20 _mockToken = new MockERC20("Mock Token", "MTK", 18);
        token = address(_mockToken);

        to = address(this);
        amount = 1000;

        hook = new TransferHook(NATIVE_TOKEN);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.NATIVE_TOKEN(), NATIVE_TOKEN);
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(token, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(token, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Build_ERC20() public view {
        bytes memory data = _encodeData(token, false);
        Execution[] memory executions = hook.build(address(0), address(0), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_NativeToken() public view {
        bytes memory data = _encodeData(NATIVE_TOKEN, false);
        Execution[] memory executions = hook.build(address(0), address(0), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, to);
        assertEq(executions[1].value, amount);
        assertEq(executions[1].callData.length, 0);
    }

    function test_Build_ERC20_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, token));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(token, true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, token);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);
    }

    function test_Build_NativeToken_WithPrevHook() public {
        uint256 prevHookAmount = 2000;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, NATIVE_TOKEN));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(NATIVE_TOKEN, true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, to);
        assertEq(executions[1].value, prevHookAmount);
        assertEq(executions[1].callData.length, 0);
    }

    function test_Build_RevertIf_AddressZero() public {
        address zeroToken = address(0);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(this), _encodeData(zeroToken, false));
    }

    function test_Build_RevertIf_AmountZero() public {
        uint256 zeroAmount = 0;
        bytes memory data = abi.encodePacked(token, to, zeroAmount, false);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(this), data);
    }

    function test_PreAndPostExecute_ERC20() public {
        _getTokens(token, address(to), amount);
        hook.preExecute(address(0), address(this), _encodeData(token, false));
        assertEq(hook.getOutAmount(address(this)), amount);

        hook.postExecute(address(0), address(this), _encodeData(token, false));
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_PreAndPostExecute_NativeToken() public {
        // Deal native token to the 'to' address
        vm.deal(to, amount);

        hook.preExecute(address(0), address(this), _encodeData(NATIVE_TOKEN, false));
        assertEq(hook.getOutAmount(address(this)), amount);

        hook.postExecute(address(0), address(this), _encodeData(NATIVE_TOKEN, false));
        assertEq(hook.getOutAmount(address(this)), 0);
    }

    function test_Inspector_ERC20() public view {
        bytes memory data = _encodeData(token, false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        assertEq(BytesLib.toAddress(argsEncoded, 0), token);
        assertEq(BytesLib.toAddress(argsEncoded, 20), to);
    }

    function test_Inspector_NativeToken() public view {
        bytes memory data = _encodeData(NATIVE_TOKEN, false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);

        assertEq(BytesLib.toAddress(argsEncoded, 0), NATIVE_TOKEN);
        assertEq(BytesLib.toAddress(argsEncoded, 20), to);
    }

    function test_DecodeAmount() public view {
        bytes memory data = _encodeData(token, false);
        assertEq(hook.decodeAmount(data), amount);
    }

    function test_ReplaceCalldataAmount() public view {
        bytes memory data = _encodeData(token, false);
        uint256 newAmount = 2e18;
        bytes memory result = hook.replaceCalldataAmount(data, newAmount);
        assertEq(result.length, data.length);
        assertEq(hook.decodeAmount(result), newAmount);
    }

    function testFuzz_ReplaceCalldataAmount(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeData(token, false);
        bytes memory result = hook.replaceCalldataAmount(data, fuzzAmount);
        assertEq(hook.decodeAmount(result), fuzzAmount);
    }

    function test_TransferHook_ReplaceCalldataAmount_ThenBuild() public view {
        bytes memory data = _encodeData(token, false);
        uint256 newAmount = 500;
        bytes memory replaced = hook.replaceCalldataAmount(data, newAmount);
        Execution[] memory executions = hook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(hook.decodeAmount(replaced), newAmount);
    }

    function test_TransferHook_ReplaceCalldataAmount_PreservesOtherFields() public view {
        bytes memory data = _encodeData(token, false);
        bytes memory replaced = hook.replaceCalldataAmount(data, 999);
        assertEq(replaced.length, data.length);
        for (uint256 i = 0; i < 40; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 72; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    function _encodeData(address tokenAddress, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(tokenAddress, to, amount, usePrev);
    }
}
