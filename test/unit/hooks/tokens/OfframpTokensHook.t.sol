// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { OfframpTokensHook } from "../../../../src/hooks/tokens/OfframpTokensHook.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";

contract OfframpTokensHookTest is Helpers {
    OfframpTokensHook public hook;

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
        hook = new OfframpTokensHook();
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Build() public view {
        // Prepare test data
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        bytes memory data = _encodeData(tokens);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(this), data);

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

        bytes memory data = _encodeData(tokens);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(this), data);
        uint256 balance = address(this).balance;

        // Verify results - should be 3 executions: 1 for the native transfer and 2 for the hook callbacks
        assertEq(executions.length, 3);
        // The actual native transfer is the second execution
        assertEq(executions[1].target, to); // For native token, target should be the recipient
        assertEq(executions[1].value, balance);
        assertEq(executions[1].callData.length, 0); // No call data for native transfers
    }

    function test_Build_MixedTransfersA() public view {
        // Prepare test data with mixed ERC20 and native tokens
        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = NATIVE_TOKEN;
        tokens[2] = token2;

        bytes memory data = _encodeData(tokens);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(this), data);
        uint256 balance = address(this).balance;

        // Verify results - should be 5 executions: 3 for the transfers and 2 for the hook callbacks
        assertEq(executions.length, 5);

        // Check first ERC20 transfer (index 1 because of hook callback)
        assertEq(executions[1].target, token1, "A");
        assertEq(executions[1].value, 0, "B");
        assertGt(executions[1].callData.length, 0, "C");

        // Check native token transfer (index 2)
        assertEq(executions[2].target, to, "D");
        assertEq(executions[2].value, balance, "E");
        assertEq(executions[2].callData.length, 0, "F");

        // Check second ERC20 transfer (index 3)
        assertEq(executions[3].target, token2, "G");
        assertEq(executions[3].value, 0, "H");
        assertGt(executions[3].callData.length, 0, "I");
    }

    function test_Inspector() public view {
        // Prepare test data
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        // Encode the data in the format expected by inspect:
        // First 20 bytes: to address
        // Then abi encoded (address[] tokens)
        bytes memory tokensData = abi.encode(tokens);
        bytes memory data = abi.encodePacked(
            abi.encodePacked(to), // First 20 bytes: to address
            tokensData // Then the encoded tokens
        );

        bytes memory result = hook.inspect(data);

        assertGt(result.length, 0);

        address recipient;
        assembly {
            recipient := mload(add(result, 20))
        }
        assertEq(recipient, to);
    }

    function _encodeData(address[] memory tokens) internal view returns (bytes memory) {
        bytes memory tokensData = abi.encode(tokens);
        return abi.encodePacked(to, tokensData);
    }
}
