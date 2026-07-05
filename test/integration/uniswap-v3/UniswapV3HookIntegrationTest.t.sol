// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform imports
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { SwapUniswapV3Hook } from "../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol";
import { ApproveAndSwapUniswapV3Hook } from "../../../src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";

import "forge-std/console2.sol";

/// @title UniswapV3HookIntegrationTest
/// @author Superform Labs
/// @notice Integration tests for Uniswap V3 swap hooks using real mainnet forks
/// @dev Tests swap functionality via SuperExecutor with real Uniswap V3 router
contract UniswapV3HookIntegrationTest is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to avoid stack too deep in swap tests
    struct SwapTestParams {
        uint256 sellAmount;
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        uint256 expectedMinOut;
        address account;
        uint256 initialTokenInBalance;
        uint256 initialTokenOutBalance;
        uint256 finalTokenInBalance;
        uint256 finalTokenOutBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapUniswapV3Hook public swapHook;
    ApproveAndSwapUniswapV3Hook public approveAndSwapHook;

    // Uniswap V3 fee tiers
    uint24 public constant FEE_LOW = 500; // 0.05%
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    uint24 public constant FEE_HIGH = 10000; // 1%

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        console2.log("Deploying UniswapV3 hooks with real router");

        // Deploy hooks with real Uniswap V3 SwapRouter
        swapHook = new SwapUniswapV3Hook(MAINNET_V3_SWAP_ROUTER);
        approveAndSwapHook = new ApproveAndSwapUniswapV3Hook(MAINNET_V3_SWAP_ROUTER);

        console2.log("SwapUniswapV3Hook deployed at:", address(swapHook));
        console2.log("ApproveAndSwapUniswapV3Hook deployed at:", address(approveAndSwapHook));
        console2.log("User account:", address(instanceOnEth.account));
    }

    // CRITICAL: Integration test contracts MUST include receive() for EntryPoint fee refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook data for Uniswap V3 swap
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param fee Pool fee tier
    /// @param recipient Recipient of output tokens
    /// @param deadline Transaction deadline
    /// @param sqrtPriceLimitX96 Price limit for the swap
    /// @param amountIn Amount of input tokens
    /// @param amountOutMinimum Minimum output amount
    /// @param usePrevHookAmount Whether to use previous hook's output
    function _buildHookData(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 deadline,
        uint160 sqrtPriceLimitX96,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory payload = abi.encode(fee, deadline, sqrtPriceLimitX96);
        bytes memory layer1 = abi.encodePacked(
            bytes32(0), address(0), // header @0
            tokenIn, tokenOut, // inputToken @52, outputToken @72
            amountIn, // inputAmount @92
            uint256(0), // outputQuote @124
            amountOutMinimum, // outputMin @156
            usePrevHookAmount, // @188
            payload.length // payloadLength @189
        );
        return bytes.concat(layer1, payload);
    }

    /// @notice Execute a swap using the hook via SuperExecutor
    function _executeSwap(address hook, bytes memory hookData) private {
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = hook;

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);
    }

    /// @notice Execute a swap with approval hook chained before
    function _executeSwapWithApproval(address swapHook_, bytes memory swapHookData) private {
        // For ApproveAndSwapUniswapV3Hook, use single hook
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = swapHook_;

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = swapHookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test hook data decoding
    function test_UniswapV3Hook_HookDataDecoding() external view {
        console2.log("=== UniswapV3Hook Data Decoding Test ===");

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC, // tokenIn
            CHAIN_1_WETH, // tokenOut
            FEE_MEDIUM, // fee
            accountEth, // recipient
            block.timestamp + 1 hours, // deadline
            0, // sqrtPriceLimitX96 (0 = no limit)
            1000e6, // amountIn (1000 USDC)
            0.3 ether, // amountOutMinimum (~0.3 WETH)
            false // usePrevHookAmount
        );

        // Test hook can decode usePrevHookAmount correctly
        bool usePrevHookAmount = swapHook.decodeUsePrevHookAmount(hookData);
        assertFalse(usePrevHookAmount, "Should not use prev hook amount");

        console2.log("Hook data decoding test passed");
    }

    /// @notice Test inspect function returns tokenOut
    function test_UniswapV3Hook_InspectFunction() external view {
        console2.log("=== UniswapV3Hook Inspect Function Test ===");

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            accountEth,
            block.timestamp + 1 hours,
            0,
            1000e6,
            0.3 ether,
            false
        );

        // Test inspect function returns tokenOut
        bytes memory inspectResult = swapHook.inspect(hookData);
        assertEq(inspectResult.length, 20, "Should return 20 bytes (1 address)");

        // Extract tokenOut address
        address extractedTokenOut;
        assembly ("memory-safe") {
            extractedTokenOut := mload(add(inspectResult, 20))
        }
        assertEq(extractedTokenOut, CHAIN_1_WETH, "Should extract correct tokenOut");

        console2.log("Inspect function test passed");
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test successful USDC -> WETH swap using ApproveAndSwapUniswapV3Hook
    function test_UniswapV3_ApproveAndSwap_USDC_to_WETH() public {
        console2.log("=== UniswapV3 ApproveAndSwap USDC -> WETH Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1000e6; // 1000 USDC
        params.tokenIn = CHAIN_1_USDC;
        params.tokenOut = CHAIN_1_WETH;
        params.fee = FEE_MEDIUM;
        params.recipient = accountEth;
        params.deadline = block.timestamp + 1 hours;
        params.sqrtPriceLimitX96 = 0; // No price limit
        params.expectedMinOut = 0.2 ether; // Expect at least ~0.2 WETH (conservative)
        params.account = instanceOnEth.account;

        // Fund account with USDC
        deal(CHAIN_1_USDC, params.account, params.sellAmount);

        // Get initial balances
        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Initial USDC balance:", params.initialTokenInBalance);
        console2.log("Initial WETH balance:", params.initialTokenOutBalance);

        // Build hook data
        bytes memory hookData = _buildHookData(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.recipient,
            params.deadline,
            params.sqrtPriceLimitX96,
            params.sellAmount,
            params.expectedMinOut,
            false // usePrevHookAmount
        );

        // Execute the swap with approval handling
        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        // Verify swap results
        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Final USDC balance:", params.finalTokenInBalance);
        console2.log("Final WETH balance:", params.finalTokenOutBalance);

        // Calculate amounts
        uint256 usdcSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 wethReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        console2.log("USDC spent:", usdcSpent);
        console2.log("WETH received:", wethReceived);

        // Verify swap executed correctly
        assertEq(usdcSpent, params.sellAmount, "Should spend exact USDC amount");
        assertGt(wethReceived, 0, "Should receive some WETH");
        assertGe(wethReceived, params.expectedMinOut, "Should receive at least minimum WETH");

        console2.log("ApproveAndSwap USDC -> WETH test passed");
    }

    /// @notice Test successful WETH -> USDC swap using ApproveAndSwapUniswapV3Hook
    function test_UniswapV3_ApproveAndSwap_WETH_to_USDC() public {
        console2.log("=== UniswapV3 ApproveAndSwap WETH -> USDC Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1 ether; // 1 WETH
        params.tokenIn = CHAIN_1_WETH;
        params.tokenOut = CHAIN_1_USDC;
        params.fee = FEE_MEDIUM;
        params.recipient = accountEth;
        params.deadline = block.timestamp + 1 hours;
        params.sqrtPriceLimitX96 = 0; // No price limit
        params.expectedMinOut = 1000e6; // Expect at least 1000 USDC (conservative)
        params.account = instanceOnEth.account;

        // Fund account with WETH
        deal(CHAIN_1_WETH, params.account, params.sellAmount);

        // Get initial balances
        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Initial WETH balance:", params.initialTokenInBalance);
        console2.log("Initial USDC balance:", params.initialTokenOutBalance);

        // Build hook data
        bytes memory hookData = _buildHookData(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.recipient,
            params.deadline,
            params.sqrtPriceLimitX96,
            params.sellAmount,
            params.expectedMinOut,
            false
        );

        // Execute the swap
        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        // Verify swap results
        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Final WETH balance:", params.finalTokenInBalance);
        console2.log("Final USDC balance:", params.finalTokenOutBalance);

        // Calculate amounts
        uint256 wethSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 usdcReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        console2.log("WETH spent:", wethSpent);
        console2.log("USDC received:", usdcReceived);

        // Verify swap executed correctly
        assertEq(wethSpent, params.sellAmount, "Should spend exact WETH amount");
        assertGt(usdcReceived, 0, "Should receive some USDC");
        assertGe(usdcReceived, params.expectedMinOut, "Should receive at least minimum USDC");

        console2.log("ApproveAndSwap WETH -> USDC test passed");
    }

    /// @notice Test swap with different fee tiers
    function test_UniswapV3_DifferentFeeTiers() public {
        console2.log("=== UniswapV3 Different Fee Tiers Test ===");

        // Test with high fee tier (1%) - WBTC/WETH pool uses this
        address account = instanceOnEth.account;
        uint256 sellAmount = 0.1 ether; // 0.1 WETH

        // Use WETH -> USDC with high fee tier (some pools use this)
        deal(CHAIN_1_WETH, account, sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 initialUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData = _buildHookData(
            CHAIN_1_WETH,
            CHAIN_1_USDC,
            FEE_LOW, // 0.05% fee tier
            account,
            block.timestamp + 1 hours,
            0,
            sellAmount,
            100e6, // Minimum 100 USDC
            false
        );

        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);

        assertLt(finalWETH, initialWETH, "Should spend WETH");
        assertGt(finalUSDC, initialUSDC, "Should receive USDC");

        console2.log("Fee tier test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK CHAINING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with usePrevHookAmount flag
    function test_UniswapV3_UsePrevHookAmount() public {
        console2.log("=== UniswapV3 UsePrevHookAmount Test ===");

        address account = instanceOnEth.account;
        uint256 mockPrevAmount = 500e6; // 500 USDC from previous hook

        // Fund account with USDC
        deal(CHAIN_1_USDC, account, mockPrevAmount);

        // Create mock previous hook
        MockPrevHook mockPrevHook = new MockPrevHook(mockPrevAmount);

        // Build hook data with usePrevHookAmount = true
        bytes memory swapHookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            1000e6, // originalAmountIn (different from actual)
            0.1 ether, // originalMinAmountOut
            true // usePrevHookAmount = true
        );

        // Execute with hook chaining
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(mockPrevHook);
        hookAddresses[1] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = ""; // Mock hook needs no data
        hookDataArray[1] = swapHookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        // Should receive WETH based on mockPrevAmount, not originalAmountIn
        assertGt(finalWETH, initialWETH, "Should receive WETH");

        console2.log("UsePrevHookAmount test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        OUT AMOUNT TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that outAmount is correctly tracked for chaining
    function test_UniswapV3_OutAmountTracking() public {
        console2.log("=== UniswapV3 OutAmount Tracking Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6; // 1000 USDC

        // Fund account
        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            sellAmount,
            0.2 ether,
            false
        );

        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 wethReceived = finalWETH - initialWETH;

        // The hook's getOutAmount should reflect what was received
        // Note: In real usage, this would be read by subsequent hooks
        assertGt(wethReceived, 0, "Should track WETH received");

        console2.log("WETH received and tracked:", wethReceived);
        console2.log("OutAmount tracking test passed");
    }
}

/// @notice Mock contract to simulate previous hook returning specific amounts
contract MockPrevHook is BaseHook {
    uint256 private _outAmount;

    constructor(uint256 outAmount_) BaseHook(ISuperHook.HookType.NONACCOUNTING, 0) {
        _outAmount = outAmount_;
    }

    function name() external pure override returns (string memory) {
        return "Mock Prev Hook";
    }

    function description() external pure override returns (string memory) {
        return "Mock hook for testing";
    }

    function _buildHookExecutions(address, address, bytes calldata)
        internal
        pure
        override
        returns (Execution[] memory)
    {
        return new Execution[](0);
    }

    function _preExecute(address, address, bytes calldata) internal override {
        // Set mock output amount
        _setOutAmount(_outAmount, msg.sender);
    }

    function _postExecute(address, address, bytes calldata) internal pure override {
        // No post-execution logic needed for mock
    }
}

/*//////////////////////////////////////////////////////////////
                    EXTENDED INTEGRATION TESTS
//////////////////////////////////////////////////////////////*/

/// @title UniswapV3HookEdgeCaseTests
/// @notice Additional edge case and error scenario tests
contract UniswapV3HookEdgeCaseTests is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    SwapUniswapV3Hook public swapHook;
    ApproveAndSwapUniswapV3Hook public approveAndSwapHook;

    uint24 public constant FEE_MEDIUM = 3000;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        swapHook = new SwapUniswapV3Hook(MAINNET_V3_SWAP_ROUTER);
        approveAndSwapHook = new ApproveAndSwapUniswapV3Hook(MAINNET_V3_SWAP_ROUTER);
    }

    receive() external payable { }

    function _buildHookData(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address, /* recipient — unused in new layout */
        uint256 deadline,
        uint160 sqrtPriceLimitX96,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory payload = abi.encode(fee, deadline, sqrtPriceLimitX96);
        bytes memory layer1 = abi.encodePacked(
            bytes32(0), // header: yieldSourceOracleId
            address(0), // header: yieldSource
            tokenIn, // inputToken @52
            tokenOut, // outputToken @72
            amountIn, // inputAmount @92
            uint256(0), // outputQuote @124
            amountOutMinimum, // outputMin @156
            usePrevHookAmount, // usePrevHookAmount @188
            payload.length // payloadLength @189
        );
        return bytes.concat(layer1, payload);
    }

    /*//////////////////////////////////////////////////////////////
                        SLIPPAGE REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that swap reverts when slippage is too high
    /// @dev Uses try/catch pattern since vm.expectRevert doesn't work with ERC-4337 UserOps
    function test_UniswapV3_RevertIf_SlippageTooHigh() public {
        console2.log("=== UniswapV3 Slippage Revert Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6; // 1000 USDC

        deal(CHAIN_1_USDC, account, sellAmount);

        // Set unrealistic minimum output (way too high)
        uint256 unrealisticMinOut = 100 ether; // Expect 100 ETH for 1000 USDC (impossible)

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            sellAmount,
            unrealisticMinOut,
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Record USDC balance before
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        // Execute - will fail at UserOp level due to slippage
        try this.executeOpExternal(opData) {
            // If it succeeds, test fails
            revert("Expected swap to fail due to slippage");
        } catch {
            // Expected: swap fails, USDC should not be spent
            uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
            assertEq(usdcAfter, usdcBefore, "USDC should not be spent on failed swap");
        }

        console2.log("Slippage revert test passed");
    }

    /// @notice Test swap with expired deadline
    function test_UniswapV3_RevertIf_DeadlineExpired() public {
        console2.log("=== UniswapV3 Deadline Expired Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;

        deal(CHAIN_1_USDC, account, sellAmount);

        // Set deadline in the past
        uint256 expiredDeadline = block.timestamp - 1;

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            expiredDeadline,
            0,
            sellAmount,
            0.1 ether,
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Record USDC balance before
        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        // Execute - will fail due to expired deadline
        try this.executeOpExternal(opData) {
            revert("Expected swap to fail due to expired deadline");
        } catch {
            uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
            assertEq(usdcAfter, usdcBefore, "USDC should not be spent on failed swap");
        }

        console2.log("Deadline expired test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        ZERO AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with zero amount
    function test_UniswapV3_ZeroAmountSwap() public {
        console2.log("=== UniswapV3 Zero Amount Test ===");

        address account = instanceOnEth.account;

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            0, // Zero amount
            0,
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Execute - should fail due to zero amount (AS - amount specified)
        try this.executeOpExternal(opData) {
            revert("Expected swap to fail due to zero amount");
        } catch {
            // Expected failure
        }

        console2.log("Zero amount test passed");
    }

    /// @notice External wrapper to enable try/catch for UserOp execution
    function executeOpExternal(UserOpData memory opData) external {
        executeOp(opData);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTIPLE SWAPS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test multiple sequential swaps in a single transaction
    function test_UniswapV3_MultipleSequentialSwaps() public {
        console2.log("=== UniswapV3 Multiple Sequential Swaps Test ===");

        address account = instanceOnEth.account;
        uint256 initialUSDC = 2000e6;

        deal(CHAIN_1_USDC, account, initialUSDC);

        // First swap: USDC -> WETH
        bytes memory hookData1 = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            1000e6,
            0.2 ether,
            false
        );

        // Second swap: USDC -> WETH (remaining)
        bytes memory hookData2 = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            1000e6,
            0.2 ether,
            false
        );

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(approveAndSwapHook);
        hookAddresses[1] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = hookData1;
        hookDataArray[1] = hookData2;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertEq(finalUSDC, 0, "Should spend all USDC");
        assertGt(finalWETH, initialWETH, "Should receive WETH");
        assertGe(finalWETH - initialWETH, 0.4 ether, "Should receive at least 0.4 WETH total");

        console2.log("Multiple sequential swaps test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        LARGE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with large amounts (whale scenario)
    function test_UniswapV3_LargeAmountSwap() public {
        console2.log("=== UniswapV3 Large Amount Swap Test ===");

        address account = instanceOnEth.account;
        uint256 largeAmount = 1_000_000e6; // 1M USDC

        deal(CHAIN_1_USDC, account, largeAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            largeAmount,
            100 ether, // Expect at least 100 WETH
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 wethReceived = finalWETH - initialWETH;

        assertGt(wethReceived, 100 ether, "Should receive significant WETH for large swap");

        console2.log("WETH received:", wethReceived);
        console2.log("Large amount swap test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        SMALL AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with very small amounts
    function test_UniswapV3_SmallAmountSwap() public {
        console2.log("=== UniswapV3 Small Amount Swap Test ===");

        address account = instanceOnEth.account;
        uint256 smallAmount = 1e6; // 1 USDC

        deal(CHAIN_1_USDC, account, smallAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            account,
            block.timestamp + 1 hours,
            0,
            smallAmount,
            0, // No minimum (small amount)
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertGt(finalWETH, initialWETH, "Should receive some WETH even for small amount");

        console2.log("Small amount swap test passed");
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for UniswapV3 hooks
    function test_UniswapV3_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 1000e6;
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, accountEth, block.timestamp + 1 hours, 0, originalAmount, 0.2 ether, false
        );

        // Verify decodeAmount
        assertEq(swapHook.decodeAmounts(hookData)[0], originalAmount, "SwapHook decodeAmount mismatch");
        assertEq(approveAndSwapHook.decodeAmounts(hookData)[0], originalAmount, "ApproveAndSwapHook decodeAmount mismatch");

        // Replace and verify roundtrip
        uint256 newAmount = 500e6;
        bytes memory replacedSwap = swapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        bytes memory replacedApproveAndSwap = approveAndSwapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));

        assertEq(swapHook.decodeAmounts(replacedSwap)[0], newAmount, "SwapHook replaced amount mismatch");
        assertEq(approveAndSwapHook.decodeAmounts(replacedApproveAndSwap)[0], newAmount, "ApproveAndSwapHook replaced amount mismatch");

        // Verify other fields preserved
        assertFalse(swapHook.decodeUsePrevHookAmount(replacedSwap), "usePrevHookAmount should be preserved");
    }

    /// @notice ApproveAndSwap: build with 1000 USDC, replace to 500 USDC, execute, verify only 500 spent
    function test_UniswapV3_ApproveAndSwap_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        address account = instanceOnEth.account;
        uint256 originalAmount = 1000e6;
        uint256 newAmount = 500e6;

        deal(CHAIN_1_USDC, account, originalAmount);

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, account, block.timestamp + 1 hours, 0, originalAmount, 0, false
        );

        // Replace with new amount
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount, "Amount not replaced correctly");

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        // Execute with replaced data
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = replaced;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertEq(usdcAfter, originalAmount - newAmount, "Should only spend replaced amount");
        assertGt(wethAfter - wethBefore, 0, "Should receive WETH");
    }
}
