// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SetSlippageHook } from "../../../../../src/hooks/vaults/7540/SetSlippageHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";

contract SetSlippageHookTest is Helpers {
    using BytesLib for bytes;

    SetSlippageHook public hook;

    uint16 private constant MAX_SLIPPAGE_BPS = 10_000;

    function setUp() public {
        hook = new SetSlippageHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(hook.SUB_TYPE()), uint256(HookSubTypes.ERC7540));
    }

    function test_Build_ValidSlippage() public {
        address vault = makeAddr("vault");
        uint16 slippageBps = 500; // 5%
        bytes memory data = _encodeData(vault, slippageBps);

        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify execution structure (preExecute + hook + postExecute = 3)
        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        // Verify calldata
        bytes memory expectedCalldata = abi.encodeWithSignature("setRedeemSlippage(uint16)", slippageBps);
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_ZeroSlippage() public {
        address vault = makeAddr("vault");
        bytes memory data = _encodeData(vault, 0);

        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Should allow 0% slippage
        assertEq(executions.length, 3);
        bytes memory expectedCalldata = abi.encodeWithSignature("setRedeemSlippage(uint16)", uint16(0));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_MaxSlippage() public {
        address vault = makeAddr("vault");
        bytes memory data = _encodeData(vault, MAX_SLIPPAGE_BPS);

        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Should allow 100% slippage (max tolerance)
        assertEq(executions.length, 3);
        bytes memory expectedCalldata = abi.encodeWithSignature("setRedeemSlippage(uint16)", MAX_SLIPPAGE_BPS);
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_ZeroVault() public {
        bytes memory data = _encodeData(address(0), 500);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_ExcessiveSlippage() public {
        bytes memory data = _encodeData(makeAddr("vault"), MAX_SLIPPAGE_BPS + 1);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Inspector() public {
        address vault = makeAddr("vault");
        bytes memory data = _encodeData(vault, 500);

        bytes memory inspectionResult = hook.inspect(data);

        assertEq(BytesLib.toAddress(inspectionResult, 0), vault);
    }

    function test_DataEncodingDecoding() public {
        address vault = makeAddr("vault");
        uint16 slippageBps = 1250; // 12.5%

        bytes memory data = _encodeData(vault, slippageBps);

        // Verify encoding
        assertEq(data.length, 54); // 32 + 20 + 2
        assertEq(BytesLib.toAddress(data, 32), vault);
        assertEq(BytesLib.toUint16(data, 52), slippageBps);
    }

    function test_Build_WithNonZeroPrevHook() public {
        address vault = makeAddr("vault");
        address prevHook = makeAddr("prevHook");
        bytes memory data = _encodeData(vault, 500);

        // Build with non-zero prevHook - should be ignored
        Execution[] memory executions = hook.build(prevHook, address(0), data);

        // Verify execution is identical regardless of prevHook parameter
        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        // Verify calldata is correct
        bytes memory expectedCalldata = abi.encodeWithSignature("setRedeemSlippage(uint16)", uint16(500));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function testFuzz_Build(address vault, uint16 slippageBps) public {
        vm.assume(vault != address(0));
        vm.assume(slippageBps <= MAX_SLIPPAGE_BPS);

        bytes memory data = _encodeData(vault, slippageBps);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        // Verify calldata
        bytes memory expectedCalldata = abi.encodeWithSignature("setRedeemSlippage(uint16)", slippageBps);
        assertEq(executions[1].callData, expectedCalldata);
    }

    function _encodeData(address vault, uint16 slippageBps) internal pure returns (bytes memory) {
        bytes memory placeholder = new bytes(32);
        return bytes.concat(placeholder, abi.encodePacked(vault), abi.encodePacked(slippageBps));
    }
}
