// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BatchTransferHook } from "../../../../src/hooks/tokens/BatchTransferHook.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";

contract BatchTransferHookTest is Helpers {
    using BytesLib for bytes;
    
    BatchTransferHook public hook;

    address token1;
    address token2;
    address to;
    uint256 amount1 = 1000;
    uint256 amount2 = 2000;
    uint256 nativeAmount = 1 ether;
    address constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        // Deploy mock ERC20 tokens
        MockERC20 _mockToken1 = new MockERC20("Mock Token 1", "MTK1", 18);
        MockERC20 _mockToken2 = new MockERC20("Mock Token 2", "MTK2", 18);
        token1 = address(_mockToken1);
        token2 = address(_mockToken2);

        // Set up recipient and hook
        to = address(this);
        hook = new BatchTransferHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Build_ERC20Transfers() public view {
        // Prepare test data
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        bytes memory data = _encodeData(tokens, amounts);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify results - should be 4 executions: 2 for the actual transfers and 2 for the hook callbacks
        assertEq(executions.length, 4);

        // Check first token transfer
        assertEq(executions[1].target, token1);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        // Check second token transfer
        assertEq(executions[2].target, token2);
        assertEq(executions[2].value, 0);
        assertGt(executions[2].callData.length, 0);
    }

    function test_Build_NativeTokenTransfer() public view {
        // Prepare test data with native token
        address[] memory tokens = new address[](1);
        tokens[0] = NATIVE_TOKEN;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = nativeAmount;

        bytes memory data = _encodeData(tokens, amounts);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify results - should be 3 executions: 1 for the native transfer and 2 for the hook callbacks
        assertEq(executions.length, 3);
        // The actual native transfer is the second execution
        assertEq(executions[1].target, to); // For native token, target should be the recipient
        assertEq(executions[1].value, nativeAmount);
        assertEq(executions[1].callData.length, 0); // No call data for native transfers
    }

    function test_Build_MixedTransfers() public view {
        // Prepare test data with mixed ERC20 and native tokens
        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = NATIVE_TOKEN;
        tokens[2] = token2;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = amount1;
        amounts[1] = nativeAmount;
        amounts[2] = amount2;

        bytes memory data = _encodeData(tokens, amounts);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(0), data);

        // Verify results - should be 5 executions: 3 for the transfers and 2 for the hook callbacks
        assertEq(executions.length, 5);

        // Check first ERC20 transfer (index 1 because of hook callback)
        assertEq(executions[1].target, token1);
        assertEq(executions[1].value, 0);
        assertGt(executions[1].callData.length, 0);

        // Check native token transfer (index 2)
        assertEq(executions[2].target, to);
        assertEq(executions[2].value, nativeAmount);
        assertEq(executions[2].callData.length, 0);

        // Check second ERC20 transfer (index 3)
        assertEq(executions[3].target, token2);
        assertEq(executions[3].value, 0);
        assertGt(executions[3].callData.length, 0);
    }

    function test_Build_RevertIf_LengthMismatch() public {
        // Prepare invalid data with mismatched array lengths
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](1); // One less than tokens array
        amounts[0] = amount1;

        bytes memory data = _encodeData(tokens, amounts);

        // Test should revert with LENGTH_MISMATCH error
        vm.expectRevert(BatchTransferHook.LENGTH_MISMATCH.selector);
        hook.build(address(0), address(0), data);
    }

    function test_Inspector() public view {
        // Prepare test data
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        // Encode the data in the format expected by inspect:
        // First 20 bytes: to address
        // Then abi encoded (address[] tokens, uint256[] amounts)
        bytes memory tokensData = abi.encode(tokens, amounts);
        bytes memory data = abi.encodePacked(
            abi.encodePacked(to), // First 20 bytes: to address
            tokensData // Then the encoded tokens and amounts
        );

        // Test inspect function
        bytes memory result = hook.inspect(data);

        // Verify the output contains the recipient and token addresses
        assertGt(result.length, 0);

        // Extract the recipient address (first 20 bytes)
        address recipient;
        assembly {
            recipient := mload(add(result, 20))
        }
        assertEq(recipient, to);
    }

    function _encodeData(address[] memory tokens, uint256[] memory amounts) internal view returns (bytes memory) {
        // The hook expects the data to be in the format:
        // 1. First 20 bytes: recipient address
        // 2. Remaining bytes: abi encoded (address[] tokens, uint256[] amounts)
        bytes memory tokensData = abi.encode(tokens, amounts);
        return abi.encodePacked(to, tokensData);
    }
}
