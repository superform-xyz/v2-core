// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SetOperator7540Hook } from "../../../../../src/hooks/vaults/7540/SetOperator7540Hook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { HookSubTypes } from "../../../../../src/libraries/HookSubTypes.sol";
import { IERC7540 } from "../../../../../src/vendor/vaults/7540/IERC7540.sol";

contract SetOperator7540HookTest is Helpers {
    using BytesLib for bytes;

    SetOperator7540Hook public hook;

    function setUp() public {
        hook = new SetOperator7540Hook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(uint256(hook.SUB_TYPE()), uint256(HookSubTypes.ERC7540));
    }

    function test_Build_ApproveOperator() public {
        address vault = makeAddr("vault");
        address operator = makeAddr("operator");
        bytes memory data = _encodeData(vault, operator, true);

        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify execution structure (preExecute + hook + postExecute = 3)
        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        // Verify calldata
        bytes memory expectedCalldata = abi.encodeCall(IERC7540.setOperator, (operator, true));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevokeOperator() public {
        address vault = makeAddr("vault");
        address operator = makeAddr("operator");
        bytes memory data = _encodeData(vault, operator, false);

        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify calldata for revocation
        bytes memory expectedCalldata = abi.encodeCall(IERC7540.setOperator, (operator, false));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function test_Build_RevertIf_ZeroVault() public {
        bytes memory data = _encodeData(address(0), makeAddr("operator"), true);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Build_RevertIf_ZeroOperator() public {
        bytes memory data = _encodeData(makeAddr("vault"), address(0), true);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Inspector() public {
        address vault = makeAddr("vault");
        bytes memory data = _encodeData(vault, makeAddr("operator"), true);

        bytes memory inspectionResult = hook.inspect(data);

        assertEq(BytesLib.toAddress(inspectionResult, 0), vault);
    }

    function test_DataEncodingDecoding() public {
        address vault = makeAddr("vault");
        address operator = makeAddr("operator");
        bool approved = true;

        bytes memory data = _encodeData(vault, operator, approved);

        // Verify encoding
        assertEq(data.length, 73); // 32 + 20 + 20 + 1
        assertEq(BytesLib.toAddress(data, 32), vault);
        assertEq(BytesLib.toAddress(data, 52), operator);
        assertEq(data[72] != 0, approved);
    }

    function test_Build_WithNonZeroPrevHook() public {
        address vault = makeAddr("vault");
        address operator = makeAddr("operator");
        address prevHook = makeAddr("prevHook");
        bytes memory data = _encodeData(vault, operator, true);

        // Build with non-zero prevHook - should be ignored
        Execution[] memory executions = hook.build(prevHook, address(0), data);

        // Verify execution is identical regardless of prevHook parameter
        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        // Verify calldata is correct
        bytes memory expectedCalldata = abi.encodeCall(IERC7540.setOperator, (operator, true));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function testFuzz_Build(address vault, address operator, bool approved) public {
        vm.assume(vault != address(0));
        vm.assume(operator != address(0));

        bytes memory data = _encodeData(vault, operator, approved);
        Execution[] memory executions = hook.build(address(0), address(0), data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, vault);
        assertEq(executions[1].value, 0);

        // Verify calldata
        bytes memory expectedCalldata = abi.encodeCall(IERC7540.setOperator, (operator, approved));
        assertEq(executions[1].callData, expectedCalldata);
    }

    function _encodeData(address vault, address operator, bool approved) internal pure returns (bytes memory) {
        bytes memory placeholder = new bytes(32);
        return bytes.concat(placeholder, abi.encodePacked(vault), abi.encodePacked(operator), abi.encodePacked(approved ? uint8(1) : uint8(0)));
    }
}
