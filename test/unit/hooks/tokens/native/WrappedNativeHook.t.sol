// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { WrappedNativeHook } from "../../../../../src/hooks/tokens/native/WrappedNativeHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";

contract WrappedNativeHookTest is Helpers {
    using BytesLib for bytes;

    WrappedNativeHook public hook;

    address wrappedNative;
    uint256 amount;

    function setUp() public {
        wrappedNative = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        amount = 1 ether;
        hook = new WrappedNativeHook(wrappedNative);
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.WRAPPED_NATIVE(), wrappedNative);
    }

    /*//////////////////////////////////////////////////////////////
                            WRAP (native → wrapped)
    //////////////////////////////////////////////////////////////*/

    function test_Wrap_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(true, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(true, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Wrap_Build() public view {
        bytes memory data = _encodeData(true, false);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);

        // Check preExecute
        assertEq(executions[0].target, address(hook));
        assertEq(executions[0].value, 0);

        // Check main execution (deposit native → wrapped)
        assertEq(executions[1].target, wrappedNative);
        assertEq(executions[1].value, amount);
        assertEq(executions[1].callData, abi.encodeWithSignature("deposit()"));

        // Check postExecute
        assertEq(executions[2].target, address(hook));
        assertEq(executions[2].value, 0);
    }

    function test_Wrap_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2 ether;
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, wrappedNative));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(true, true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, wrappedNative);
        assertEq(executions[1].value, prevHookAmount);
        assertEq(executions[1].callData, abi.encodeWithSignature("deposit()"));
    }

    function test_Wrap_Build_RevertIf_ZeroAmount() public {
        amount = 0;
        vm.expectRevert(WrappedNativeHook.ZERO_AMOUNT.selector);
        hook.build(address(0), address(this), _encodeData(true, false));
    }

    function test_Wrap_Build_RevertIf_ZeroAmountFromPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, wrappedNative));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        vm.expectRevert(WrappedNativeHook.ZERO_AMOUNT.selector);
        hook.build(mockPrevHook, address(this), _encodeData(true, true));
    }

    function test_Wrap_PreAndPostExecute() public {
        vm.deal(address(this), 10 ether);

        uint256 initialBalance = address(this).balance;

        hook.setExecutionContext(address(this));
        hook.preExecute(address(0), address(this), _encodeData(true, false));
        assertEq(hook.getOutAmount(address(this)), initialBalance);

        // Simulate native balance decrease (deposited to wrapped native)
        vm.deal(address(this), initialBalance - amount);

        hook.postExecute(address(0), address(this), _encodeData(true, false));
        assertEq(hook.getOutAmount(address(this)), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            UNWRAP (wrapped → native)
    //////////////////////////////////////////////////////////////*/

    function test_Unwrap_UsePrevHookAmount() public view {
        bytes memory data = _encodeData(false, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _encodeData(false, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Unwrap_Build() public {
        // Mock wrapped native balance check
        vm.mockCall(
            wrappedNative,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(amount)
        );

        bytes memory data = _encodeData(false, false);
        Execution[] memory executions = hook.build(address(0), address(this), data);

        assertEq(executions.length, 3);

        // Check preExecute
        assertEq(executions[0].target, address(hook));
        assertEq(executions[0].value, 0);

        // Check main execution (withdraw wrapped → native)
        assertEq(executions[1].target, wrappedNative);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeWithSignature("withdraw(uint256)", amount));

        // Check postExecute
        assertEq(executions[2].target, address(hook));
        assertEq(executions[2].value, 0);
    }

    function test_Unwrap_Build_WithPrevHook() public {
        uint256 prevHookAmount = 2 ether;

        vm.mockCall(
            wrappedNative,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(prevHookAmount)
        );

        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, wrappedNative));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        bytes memory data = _encodeData(false, true);
        Execution[] memory executions = hook.build(mockPrevHook, address(this), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, wrappedNative);
        assertEq(executions[1].value, 0);
        assertEq(executions[1].callData, abi.encodeWithSignature("withdraw(uint256)", prevHookAmount));
    }

    function test_Unwrap_Build_RevertIf_ZeroAmount() public {
        amount = 0;
        vm.expectRevert(WrappedNativeHook.ZERO_AMOUNT.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_Unwrap_Build_RevertIf_ZeroAmountFromPrevHook() public {
        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, wrappedNative));
        MockHook(mockPrevHook).setOutAmount(0, address(this));

        vm.expectRevert(WrappedNativeHook.ZERO_AMOUNT.selector);
        hook.build(mockPrevHook, address(this), _encodeData(false, true));
    }

    function test_Unwrap_Build_RevertIf_InsufficientBalance() public {
        vm.mockCall(
            wrappedNative,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(amount - 1)
        );

        vm.expectRevert(WrappedNativeHook.INSUFFICIENT_BALANCE.selector);
        hook.build(address(0), address(this), _encodeData(false, false));
    }

    function test_Unwrap_Build_RevertIf_InsufficientBalanceFromPrevHook() public {
        uint256 prevHookAmount = 2 ether;

        vm.mockCall(
            wrappedNative,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(amount) // less than prevHookAmount
        );

        address mockPrevHook = address(new MockHook(ISuperHook.HookType.INFLOW, wrappedNative));
        MockHook(mockPrevHook).setOutAmount(prevHookAmount, address(this));

        vm.expectRevert(WrappedNativeHook.INSUFFICIENT_BALANCE.selector);
        hook.build(mockPrevHook, address(this), _encodeData(false, true));
    }

    function test_Unwrap_PreAndPostExecute() public {
        uint256 initialWrappedBalance = 5 ether;

        vm.mockCall(
            wrappedNative,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(initialWrappedBalance)
        );

        hook.setExecutionContext(address(this));
        hook.preExecute(address(0), address(this), _encodeData(false, false));
        assertEq(hook.getOutAmount(address(this)), initialWrappedBalance);

        // Mock reduced wrapped native balance after withdrawal
        vm.mockCall(
            wrappedNative,
            abi.encodeWithSignature("balanceOf(address)", address(this)),
            abi.encode(initialWrappedBalance - amount)
        );

        hook.postExecute(address(0), address(this), _encodeData(false, false));
        assertEq(hook.getOutAmount(address(this)), amount);
    }

    /*//////////////////////////////////////////////////////////////
                            SHARED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspector() public view {
        bytes memory argsEncoded = hook.inspect("");
        assertEq(argsEncoded.length, 20); // Only one address (20 bytes)
        assertEq(BytesLib.toAddress(argsEncoded, 0), wrappedNative);
    }

    function test_DecodeAmounts_Wrap() public view {
        bytes memory data = _encodeData(true, false);
        assertEq(hook.decodeAmounts(data)[0], amount);
    }

    function test_DecodeAmounts_Unwrap() public view {
        bytes memory data = _encodeData(false, false);
        assertEq(hook.decodeAmounts(data)[0], amount);
    }

    function test_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeData(true, false);
        uint256 newAmount = 2e18;
        bytes memory result = hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(hook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeData(true, false);
        bytes memory result = hook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(hook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ReplaceCalldataAmounts_ThenBuild_Wrap() public view {
        bytes memory data = _encodeData(true, false);
        uint256 newAmount = 500;
        bytes memory replaced = hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = hook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(hook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _encodeData(true, false);
        bytes memory replaced = hook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION=52, amount ends at 84, check bytes after (wrap + usePrevHookAmount)
        for (uint256 i = 84; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @param wrap true = wrap (native -> wrapped), false = unwrap (wrapped -> native)
    /// @param usePrev true = use previous hook's outAmount
    function _encodeData(bool wrap, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), address(0), amount, wrap, usePrev);
    }

    receive() external payable { }
}
