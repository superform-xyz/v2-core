// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

import { OfframpTokensHook } from "../../../../src/hooks/tokens/OfframpTokensHook.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../utils/Helpers.sol";
import { LibSort } from "solady/utils/LibSort.sol";

contract OfframpTokensHookTest is Helpers {
    using LibSort for address[];
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
        assertEq(executions.length, 2);
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

    function test_Build_MixedTransfers() public {
        // Prepare test data with mixed ERC20 and native tokens
        address[] memory tokens = new address[](3);
        tokens[0] = token1;
        tokens[1] = NATIVE_TOKEN;
        tokens[2] = token2;

        // make sure tokens are sorted and unique
        tokens.insertionSort();
        tokens.uniquifySorted();

        MockERC20(token1).mint(address(this), 1000);
        MockERC20(token2).mint(address(this), 2000);

        bytes memory data = _encodeData(tokens);

        // Test build function
        Execution[] memory executions = hook.build(address(0), address(this), data);
        uint256 balance = address(this).balance;

        // Verify results - should be 5 executions: 3 for the transfers and 2 for the hook callbacks
        assertEq(executions.length, 5);

        // Check first ERC20 transfer (index 1 because of hook callback)
        assertEq(executions[1].target, token2, "A");
        assertEq(executions[1].value, 0, "B");
        assertGt(executions[1].callData.length, 0, "C");

        // Check second ERC20 transfer (index 3)
        assertEq(executions[2].target, token1, "G");
        assertEq(executions[2].value, 0, "H");
        assertGt(executions[2].callData.length, 0, "I");

        // Check native token transfer (index 2)
        assertEq(executions[3].target, to, "D");
        assertEq(executions[3].value, balance, "E");
        assertEq(executions[3].callData.length, 0, "F");

 
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
            to, // First 20 bytes: to address
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

    function test_Build_WithZeroBalances() public {
        // Test the optimized logic: tokens with zero balances should be skipped
        // This verifies that the balance caching works correctly
        
        address mockAccount = address(0x123);
        
        // Mint tokens only to mockAccount
        MockERC20(token1).mint(mockAccount, amount1);
        // token2 has zero balance for mockAccount
        
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;
        
        bytes memory data = _encodeData(tokens);
        
        // Test build function with mockAccount
        Execution[] memory executions = hook.build(address(0), mockAccount, data);
        
        // Should be 3 executions: 1 for token1 transfer and 2 for hook callbacks
        // token2 should be skipped due to zero balance
        assertEq(executions.length, 3, "Should only have 1 transfer + 2 callbacks");
        
        // Check that only token1 transfer is included
        assertEq(executions[1].target, token1, "Should be token1");
        assertEq(executions[1].value, 0, "ERC20 transfer has no value");
        
        // Decode and verify the transfer amount matches the balance
        (address recipient, uint256 transferAmount) = abi.decode(
            BytesLib.slice(executions[1].callData, 4, executions[1].callData.length - 4), // Skip function selector
            (address, uint256)
        );
        assertEq(recipient, to, "Recipient should match");
        assertEq(transferAmount, amount1, "Transfer amount should match balance");
    }
    
    function test_Build_MixedZeroAndNonZeroBalances() public {
        // Test with multiple tokens where some have zero balances
        // This ensures the balance cache correctly filters out zero balances
        
        address mockAccount = address(0x456);
        
        // Create 4 tokens, but only mint to 2 of them
        MockERC20 token3 = new MockERC20("Mock Token 3", "MTK3", 18);
        MockERC20 token4 = new MockERC20("Mock Token 4", "MTK4", 18);
        
        uint256 amount3 = 3000;
        uint256 amount4 = 4000;
        
        // Mint to token1 and token3 only
        MockERC20(token1).mint(mockAccount, amount1);
        token3.mint(mockAccount, amount3);
        // token2 and token4 have zero balances
        
        address[] memory tokens = new address[](4);
        tokens[0] = token1;
        tokens[1] = token2; // zero balance
        tokens[2] = address(token3);
        tokens[3] = address(token4); // zero balance
        
        bytes memory data = _encodeData(tokens);
        
        Execution[] memory executions = hook.build(address(0), mockAccount, data);
        
        // Should be 4 executions: 2 for transfers (token1, token3) and 2 for hook callbacks
        assertEq(executions.length, 4, "Should only have 2 transfers + 2 callbacks");
        
        // Verify first transfer is token1
        assertEq(executions[1].target, token1, "First transfer should be token1");
        (address recipient1, uint256 transferAmount1) = abi.decode(
            BytesLib.slice(executions[1].callData, 4, executions[1].callData.length - 4),
            (address, uint256)
        );
        assertEq(transferAmount1, amount1, "Token1 amount should match");
        
        // Verify second transfer is token3
        assertEq(executions[2].target, address(token3), "Second transfer should be token3");
        (address recipient3, uint256 transferAmount3) = abi.decode(
            BytesLib.slice(executions[2].callData, 4, executions[2].callData.length - 4),
            (address, uint256)
        );
        assertEq(transferAmount3, amount3, "Token3 amount should match");
    }
    
    function test_Build_AllZeroBalances() public {
        // Edge case: all tokens have zero balances
        // Should only return hook callbacks, no transfers
        
        address mockAccount = address(0x789);
        
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;
        
        bytes memory data = _encodeData(tokens);
        
        Execution[] memory executions = hook.build(address(0), mockAccount, data);
        
        // Should be 2 executions: only the hook callbacks, no transfers
        assertEq(executions.length, 2, "Should only have hook callbacks");
    }
    
    function test_Build_NativeAndERC20WithZeroBalances() public {
        // Test mixed native and ERC20 tokens with some zero balances
        // Verifies balance caching works for both native and ERC20 tokens
        
        address payable mockAccount = payable(address(0xABC));
        
        // Give mockAccount some native tokens
        vm.deal(mockAccount, nativeAmount);
        
        // Mint only token1, not token2
        MockERC20(token1).mint(mockAccount, amount1);
        
        address[] memory tokens = new address[](3);
        tokens[0] = NATIVE_TOKEN;
        tokens[1] = token1;
        tokens[2] = token2; // zero balance

        // make sure tokens are sorted and unique
        tokens.insertionSort();
        tokens.uniquifySorted();
        
        bytes memory data = _encodeData(tokens);
        
        Execution[] memory executions = hook.build(address(0), mockAccount, data);
        
        // Should be 4 executions: 2 transfers (native + token1) and 2 hook callbacks
        assertEq(executions.length, 4, "Should have 2 transfers + 2 callbacks");
        
        // Verify native token transfer
        assertEq(executions[2].target, to, "Native transfer target should be recipient");
        assertEq(executions[2].value, nativeAmount, "Native transfer value should match");
        assertEq(executions[2].callData.length, 0, "Native transfer has no callData");
        
        // Verify token1 transfer
        assertEq(executions[1].target, token1, "Second transfer should be token1");
        (address recipient, uint256 transferAmount) = abi.decode(
            BytesLib.slice(executions[1].callData, 4, executions[1].callData.length - 4),
            (address, uint256)
        );
        assertEq(transferAmount, amount1, "Token1 amount should match cached balance");
    }
    
    function test_Build_BalanceCacheAccuracy() public {
        // Specifically test that cached balances are accurate
        // and match what would be queried in the second loop
        
        address mockAccount = address(0xDEF);
        
        uint256 preciseAmount1 = 123_456_789;
        uint256 preciseAmount2 = 987_654_321;
        
        MockERC20(token1).mint(mockAccount, preciseAmount1);
        MockERC20(token2).mint(mockAccount, preciseAmount2);
        
        address[] memory tokens = new address[](2);
        tokens[0] = token1;
        tokens[1] = token2;

        // make sure tokens are sorted and unique
        tokens.insertionSort();
        tokens.uniquifySorted();

        bytes memory data = _encodeData(tokens);
        
        Execution[] memory executions = hook.build(address(0), mockAccount, data);
        
        // Decode and verify exact amounts
        bytes memory callData1 = BytesLib.slice(
            executions[1].callData, 4, executions[1].callData.length - 4
        );
        bytes memory callData2 = BytesLib.slice(
            executions[2].callData, 4, executions[2].callData.length - 4
        );
        
        (, uint256 transferAmount1) = abi.decode(callData1, (address, uint256));
        (, uint256 transferAmount2) = abi.decode(callData2, (address, uint256));
        
        assertEq(transferAmount1, preciseAmount2, "Cached balance for token1 must be exact");
        assertEq(transferAmount2, preciseAmount1, "Cached balance for token2 must be exact");
        
        // Verify these match the actual balances
        assertEq(transferAmount1, MockERC20(tokens[0]).balanceOf(mockAccount), "Must match actual balance");
        assertEq(transferAmount2, MockERC20(tokens[1]).balanceOf(mockAccount), "Must match actual balance");
    }

    function _encodeData(address[] memory tokens) internal view returns (bytes memory) {
        bytes memory tokensData = abi.encode(tokens);
        return abi.encodePacked(to, tokensData);
    }
}
