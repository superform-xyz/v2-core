// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { NativeTransferHook } from "../../../../src/hooks/tokens/NativeTransferHook.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

contract NativeTransferHookTest is Helpers {
    using BytesLib for bytes;

    NativeTransferHook public hook;
    address public to;
    uint256 public amount;

    function setUp() public {
        hook = new NativeTransferHook();
        to = address(0xBEEF);
        amount = 1 ether;
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Build() public view {
        bytes memory data = _encodeData();
        Execution[] memory executions = hook.build(address(0), address(this), data);
        assertEq(executions.length, 3); // pre + main + post
        assertEq(executions[1].target, to);
        assertEq(executions[1].value, amount);
        assertEq(executions[1].callData.length, 0);
    }

    function test_DecodeAmounts() public view {
        bytes memory data = _encodeData();
        assertEq(hook.decodeAmounts(data)[0], amount);
    }

    function test_ReplaceCalldataAmounts() public view {
        bytes memory data = _encodeData();
        uint256 newAmount = 2 ether;
        bytes memory result = hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(hook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _encodeData();
        bytes memory result = hook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(hook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_NativeTransfer_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _encodeData();
        uint256 newAmount = 500;
        bytes memory replaced = hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = hook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(hook.decodeAmounts(replaced)[0], newAmount);
        assertEq(executions[1].value, newAmount);
    }

    function test_NativeTransfer_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _encodeData();
        bytes memory replaced = hook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION=72, check bytes [0..72) unchanged (placeholder + "to" address)
        for (uint256 i = 0; i < 72; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    function _encodeData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes(new bytes(52)), to, amount);
    }
}
