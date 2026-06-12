// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform imports
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { SwapUniswapV2Hook } from "../../../src/hooks/swappers/uniswap-v2/SwapUniswapV2Hook.sol";
import { ApproveAndSwapUniswapV2Hook } from "../../../src/hooks/swappers/uniswap-v2/ApproveAndSwapUniswapV2Hook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";

import "forge-std/console2.sol";

/// @title UniswapV2HookIntegrationTest
/// @author Superform Labs
/// @notice Integration tests for Uniswap V2 swap hooks using real mainnet forks
/// @dev Tests swap functionality via SuperExecutor with real Uniswap V2 router
contract UniswapV2HookIntegrationTest is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to avoid stack too deep in swap tests
    struct SwapTestParams {
        uint256 sellAmount;
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
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

    SwapUniswapV2Hook public swapHook;
    ApproveAndSwapUniswapV2Hook public approveAndSwapHook;

    /// @notice Sentinel address for native token detection
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        console2.log("Deploying UniswapV2 hooks with real router");

        // Deploy hooks with real Uniswap V2 Router
        swapHook = new SwapUniswapV2Hook(MAINNET_V2_SWAP_ROUTER, NATIVE);
        approveAndSwapHook = new ApproveAndSwapUniswapV2Hook(MAINNET_V2_SWAP_ROUTER, NATIVE);

        console2.log("SwapUniswapV2Hook deployed at:", address(swapHook));
        console2.log("ApproveAndSwapUniswapV2Hook deployed at:", address(approveAndSwapHook));
        console2.log("User account:", address(instanceOnEth.account));
    }

    // CRITICAL: Integration test contracts MUST include receive() for EntryPoint fee refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook data for Uniswap V2 swap
    /// @param tokenIn Input token address (or NATIVE sentinel)
    /// @param tokenOut Output token address (or NATIVE sentinel)
    /// @param deadline Transaction deadline
    /// @param amountIn Amount of input tokens
    /// @param amountOutMin Minimum output amount
    /// @param usePrevHookAmount Whether to use previous hook's output
    /// @param path Array of token addresses for the swap route (always real addresses, never NATIVE sentinel)
    function _buildHookData(
        address tokenIn,
        address tokenOut,
        uint256 deadline,
        uint256 amountIn,
        uint256 amountOutMin,
        bool usePrevHookAmount,
        address[] memory path
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(
            tokenIn, // 20 bytes
            tokenOut, // 20 bytes
            deadline, // 32 bytes
            amountIn, // 32 bytes
            amountOutMin, // 32 bytes
            usePrevHookAmount, // 1 byte
            uint256(path.length) // 32 bytes
        );
        for (uint256 i = 0; i < path.length; i++) {
            data = bytes.concat(data, bytes20(path[i]));
        }
        return data;
    }

    /// @notice Build a simple 2-element path
    function _buildPath(address token0, address token1) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = token0;
        path[1] = token1;
    }

    /// @notice Build a 3-element multi-hop path
    function _buildPath(address token0, address token1, address token2) internal pure returns (address[] memory path) {
        path = new address[](3);
        path[0] = token0;
        path[1] = token1;
        path[2] = token2;
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

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test hook data decoding
    function test_UniswapV2Hook_HookDataDecoding() external view {
        console2.log("=== UniswapV2Hook Data Decoding Test ===");

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.3 ether,
            false,
            path
        );

        // Test hook can decode usePrevHookAmount correctly
        bool usePrevHookAmount = swapHook.decodeUsePrevHookAmount(hookData);
        assertFalse(usePrevHookAmount, "Should not use prev hook amount");

        // Test with usePrevHookAmount = true
        bytes memory hookDataWithPrev = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.3 ether,
            true,
            path
        );

        bool usePrevHookAmountTrue = swapHook.decodeUsePrevHookAmount(hookDataWithPrev);
        assertTrue(usePrevHookAmountTrue, "Should use prev hook amount");

        console2.log("Hook data decoding test passed");
    }

    /// @notice Test inspect function returns tokenOut
    function test_UniswapV2Hook_InspectFunction() external view {
        console2.log("=== UniswapV2Hook Inspect Function Test ===");

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.3 ether,
            false,
            path
        );

        // Test inspect function returns tokenOut
        bytes memory inspectResult = swapHook.inspect(hookData);
        assertEq(inspectResult.length, 20, "Should return 20 bytes (1 address)");

        // Extract tokenOut address
        address extractedTokenOut;
        assembly {
            extractedTokenOut := mload(add(inspectResult, 20))
        }
        assertEq(extractedTokenOut, CHAIN_1_WETH, "Should extract correct tokenOut");

        console2.log("Inspect function test passed");
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test successful USDC -> WETH swap using ApproveAndSwapUniswapV2Hook (single-hop)
    function test_UniswapV2_ApproveAndSwap_USDC_to_WETH() public {
        console2.log("=== UniswapV2 ApproveAndSwap USDC -> WETH Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1000e6; // 1000 USDC
        params.tokenIn = CHAIN_1_USDC;
        params.tokenOut = CHAIN_1_WETH;
        params.recipient = accountEth;
        params.deadline = block.timestamp + 1 hours;
        params.expectedMinOut = 0.2 ether; // Conservative minimum
        params.account = instanceOnEth.account;

        // Fund account with USDC
        deal(CHAIN_1_USDC, params.account, params.sellAmount);

        // Get initial balances
        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Initial USDC balance:", params.initialTokenInBalance);
        console2.log("Initial WETH balance:", params.initialTokenOutBalance);

        // Build hook data with path [USDC, WETH]
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            params.tokenIn,
            params.tokenOut,
            params.deadline,
            params.sellAmount,
            params.expectedMinOut,
            false,
            path
        );

        // Execute the swap with approval handling
        _executeSwap(address(approveAndSwapHook), hookData);

        // Verify swap results
        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Final USDC balance:", params.finalTokenInBalance);
        console2.log("Final WETH balance:", params.finalTokenOutBalance);

        uint256 usdcSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 wethReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        console2.log("USDC spent:", usdcSpent);
        console2.log("WETH received:", wethReceived);

        assertEq(usdcSpent, params.sellAmount, "Should spend exact USDC amount");
        assertGt(wethReceived, 0, "Should receive some WETH");
        assertGe(wethReceived, params.expectedMinOut, "Should receive at least minimum WETH");

        console2.log("ApproveAndSwap USDC -> WETH test passed");
    }

    /// @notice Test successful WETH -> USDC swap using ApproveAndSwapUniswapV2Hook
    function test_UniswapV2_ApproveAndSwap_WETH_to_USDC() public {
        console2.log("=== UniswapV2 ApproveAndSwap WETH -> USDC Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1 ether; // 1 WETH
        params.tokenIn = CHAIN_1_WETH;
        params.tokenOut = CHAIN_1_USDC;
        params.recipient = accountEth;
        params.deadline = block.timestamp + 1 hours;
        params.expectedMinOut = 1000e6; // Conservative minimum
        params.account = instanceOnEth.account;

        // Fund account with WETH
        deal(CHAIN_1_WETH, params.account, params.sellAmount);

        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Initial WETH balance:", params.initialTokenInBalance);
        console2.log("Initial USDC balance:", params.initialTokenOutBalance);

        address[] memory path = _buildPath(CHAIN_1_WETH, CHAIN_1_USDC);
        bytes memory hookData = _buildHookData(
            params.tokenIn,
            params.tokenOut,
            params.deadline,
            params.sellAmount,
            params.expectedMinOut,
            false,
            path
        );

        _executeSwap(address(approveAndSwapHook), hookData);

        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        console2.log("Final WETH balance:", params.finalTokenInBalance);
        console2.log("Final USDC balance:", params.finalTokenOutBalance);

        uint256 wethSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 usdcReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        console2.log("WETH spent:", wethSpent);
        console2.log("USDC received:", usdcReceived);

        assertEq(wethSpent, params.sellAmount, "Should spend exact WETH amount");
        assertGt(usdcReceived, 0, "Should receive some USDC");
        assertGe(usdcReceived, params.expectedMinOut, "Should receive at least minimum USDC");

        console2.log("ApproveAndSwap WETH -> USDC test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-HOP SWAP TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test multi-hop swap via ApproveAndSwapUniswapV2Hook (USDC -> WETH -> DAI)
    function test_UniswapV2_ApproveAndSwap_MultiHop() public {
        console2.log("=== UniswapV2 Multi-Hop Swap Test (USDC -> WETH -> DAI) ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6; // 1000 USDC

        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 initialUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 initialDAI = IERC20(CHAIN_1_DAI).balanceOf(account);

        // Multi-hop path: USDC -> WETH -> DAI
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH, CHAIN_1_DAI);

        // tokenIn = USDC, tokenOut = DAI (final output)
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_DAI,
            block.timestamp + 1 hours,
            sellAmount,
            500e18, // Minimum 500 DAI (conservative for multi-hop)
            false,
            path
        );

        _executeSwap(address(approveAndSwapHook), hookData);

        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 finalDAI = IERC20(CHAIN_1_DAI).balanceOf(account);

        uint256 usdcSpent = initialUSDC - finalUSDC;
        uint256 daiReceived = finalDAI - initialDAI;

        console2.log("USDC spent:", usdcSpent);
        console2.log("DAI received:", daiReceived);

        assertEq(usdcSpent, sellAmount, "Should spend exact USDC");
        assertGt(daiReceived, 500e18, "Should receive at least 500 DAI");

        console2.log("Multi-hop swap test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        NATIVE TOKEN SWAP TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test native ETH input swap (ETH -> USDC) using ApproveAndSwapUniswapV2Hook
    function test_UniswapV2_ApproveAndSwap_NativeInput() public {
        console2.log("=== UniswapV2 Native Input (ETH -> USDC) Test ===");

        address account = instanceOnEth.account;
        uint256 ethAmount = 1 ether;

        // Fund account with ETH
        vm.deal(account, ethAmount + 1 ether); // Extra for gas

        uint256 initialETH = account.balance;
        uint256 initialUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);

        // Path: WETH -> USDC (path always uses real addresses, not NATIVE sentinel)
        address[] memory path = _buildPath(CHAIN_1_WETH, CHAIN_1_USDC);

        // tokenIn = NATIVE sentinel, tokenOut = USDC
        bytes memory hookData = _buildHookData(
            NATIVE,
            CHAIN_1_USDC,
            block.timestamp + 1 hours,
            ethAmount,
            1000e6, // Minimum 1000 USDC
            false,
            path
        );

        _executeSwap(address(approveAndSwapHook), hookData);

        uint256 finalETH = account.balance;
        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);

        uint256 usdcReceived = finalUSDC - initialUSDC;

        console2.log("ETH spent (approx):", initialETH - finalETH);
        console2.log("USDC received:", usdcReceived);

        // ETH spent should be at least ethAmount (plus some gas)
        assertLt(finalETH, initialETH, "Should spend ETH");
        assertGt(usdcReceived, 1000e6, "Should receive at least 1000 USDC");

        console2.log("Native input swap test passed");
    }

    /// @notice Test native ETH output swap (USDC -> ETH) using ApproveAndSwapUniswapV2Hook
    function test_UniswapV2_ApproveAndSwap_NativeOutput() public {
        console2.log("=== UniswapV2 Native Output (USDC -> ETH) Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 2000e6; // 2000 USDC

        deal(CHAIN_1_USDC, account, sellAmount);
        // Give some initial ETH for gas
        vm.deal(account, 0.1 ether);

        uint256 initialUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 initialETH = account.balance;

        // Path: USDC -> WETH (path always uses real addresses)
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);

        // tokenIn = USDC, tokenOut = NATIVE sentinel
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            NATIVE,
            block.timestamp + 1 hours,
            sellAmount,
            0.5 ether, // Minimum 0.5 ETH
            false,
            path
        );

        _executeSwap(address(approveAndSwapHook), hookData);

        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 finalETH = account.balance;

        uint256 usdcSpent = initialUSDC - finalUSDC;

        console2.log("USDC spent:", usdcSpent);
        console2.log("ETH balance change:", finalETH > initialETH ? finalETH - initialETH : 0);

        assertEq(usdcSpent, sellAmount, "Should spend exact USDC");
        assertGt(finalETH, initialETH, "Should receive ETH");

        console2.log("Native output swap test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK CHAINING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with usePrevHookAmount flag
    function test_UniswapV2_UsePrevHookAmount() public {
        console2.log("=== UniswapV2 UsePrevHookAmount Test ===");

        address account = instanceOnEth.account;
        uint256 mockPrevAmount = 500e6; // 500 USDC from previous hook

        // Fund account with USDC
        deal(CHAIN_1_USDC, account, mockPrevAmount);

        // Create mock previous hook
        MockPrevHookV2 mockPrevHook = new MockPrevHookV2(mockPrevAmount);

        // Build hook data with usePrevHookAmount = true
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory swapHookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6, // originalAmountIn (different from actual prev hook amount)
            0.1 ether, // originalMinAmountOut
            true, // usePrevHookAmount = true
            path
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

        // Should receive WETH based on mockPrevAmount (500 USDC), not originalAmountIn (1000 USDC)
        assertGt(finalWETH, initialWETH, "Should receive WETH");

        console2.log("WETH received:", finalWETH - initialWETH);
        console2.log("UsePrevHookAmount test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        OUT AMOUNT TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that outAmount is correctly tracked for chaining
    function test_UniswapV2_OutAmountTracking() public {
        console2.log("=== UniswapV2 OutAmount Tracking Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6; // 1000 USDC

        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            sellAmount,
            0.2 ether,
            false,
            path
        );

        _executeSwap(address(approveAndSwapHook), hookData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 wethReceived = finalWETH - initialWETH;

        assertGt(wethReceived, 0, "Should track WETH received");

        console2.log("WETH received and tracked:", wethReceived);
        console2.log("OutAmount tracking test passed");
    }
}

/// @notice Mock contract to simulate previous hook returning specific amounts
contract MockPrevHookV2 is BaseHook {
    uint256 private _outAmount;

    constructor(uint256 outAmount_) BaseHook(ISuperHook.HookType.NONACCOUNTING, 0) {
        _outAmount = outAmount_;
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
        _setOutAmount(_outAmount, msg.sender);
    }

    function _postExecute(address, address, bytes calldata) internal pure override { }
}

/*//////////////////////////////////////////////////////////////
                    EXTENDED INTEGRATION TESTS
//////////////////////////////////////////////////////////////*/

/// @title UniswapV2HookEdgeCaseTests
/// @notice Additional edge case and error scenario tests
contract UniswapV2HookEdgeCaseTests is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    SwapUniswapV2Hook public swapHook;
    ApproveAndSwapUniswapV2Hook public approveAndSwapHook;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        swapHook = new SwapUniswapV2Hook(MAINNET_V2_SWAP_ROUTER, NATIVE);
        approveAndSwapHook = new ApproveAndSwapUniswapV2Hook(MAINNET_V2_SWAP_ROUTER, NATIVE);
    }

    receive() external payable { }

    function _buildHookData(
        address tokenIn,
        address tokenOut,
        uint256 deadline,
        uint256 amountIn,
        uint256 amountOutMin,
        bool usePrevHookAmount,
        address[] memory path
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = abi.encodePacked(
            tokenIn,
            tokenOut,
            deadline,
            amountIn,
            amountOutMin,
            usePrevHookAmount,
            uint256(path.length)
        );
        for (uint256 i = 0; i < path.length; i++) {
            data = bytes.concat(data, bytes20(path[i]));
        }
        return data;
    }

    function _buildPath(address token0, address token1) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = token0;
        path[1] = token1;
    }

    /*//////////////////////////////////////////////////////////////
                        SLIPPAGE REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that swap reverts when slippage is too high
    /// @dev Uses try/catch pattern since vm.expectRevert doesn't work with ERC-4337 UserOps
    function test_UniswapV2_RevertIf_SlippageTooHigh() public {
        console2.log("=== UniswapV2 Slippage Revert Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6; // 1000 USDC

        deal(CHAIN_1_USDC, account, sellAmount);

        // Set unrealistic minimum output (way too high)
        uint256 unrealisticMinOut = 100 ether; // Expect 100 ETH for 1000 USDC (impossible)

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            sellAmount,
            unrealisticMinOut,
            false,
            path
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        // Execute - will fail at UserOp level due to slippage
        try this.executeOpExternal(opData) {
            revert("Expected swap to fail due to slippage");
        } catch {
            uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
            assertEq(usdcAfter, usdcBefore, "USDC should not be spent on failed swap");
        }

        console2.log("Slippage revert test passed");
    }

    /// @notice Test swap with expired deadline
    function test_UniswapV2_RevertIf_DeadlineExpired() public {
        console2.log("=== UniswapV2 Deadline Expired Test ===");

        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;

        deal(CHAIN_1_USDC, account, sellAmount);

        // Set deadline in the past
        uint256 expiredDeadline = block.timestamp - 1;

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            expiredDeadline,
            sellAmount,
            0.1 ether,
            false,
            path
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

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
    function test_UniswapV2_ZeroAmountSwap() public {
        console2.log("=== UniswapV2 Zero Amount Test ===");

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            0, // Zero amount
            0,
            false,
            path
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Execute - should fail due to zero amount
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
    function test_UniswapV2_MultipleSequentialSwaps() public {
        console2.log("=== UniswapV2 Multiple Sequential Swaps Test ===");

        address account = instanceOnEth.account;
        uint256 initialUSDC = 2000e6;

        deal(CHAIN_1_USDC, account, initialUSDC);

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);

        // First swap: 1000 USDC -> WETH
        bytes memory hookData1 = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.2 ether,
            false,
            path
        );

        // Second swap: 1000 USDC -> WETH
        bytes memory hookData2 = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.2 ether,
            false,
            path
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
    function test_UniswapV2_LargeAmountSwap() public {
        console2.log("=== UniswapV2 Large Amount Swap Test ===");

        address account = instanceOnEth.account;
        uint256 largeAmount = 1_000_000e6; // 1M USDC

        deal(CHAIN_1_USDC, account, largeAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            largeAmount,
            100 ether, // Expect at least 100 WETH
            false,
            path
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
    function test_UniswapV2_SmallAmountSwap() public {
        console2.log("=== UniswapV2 Small Amount Swap Test ===");

        address account = instanceOnEth.account;
        uint256 smallAmount = 1e6; // 1 USDC

        deal(CHAIN_1_USDC, account, smallAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            smallAmount,
            0, // No minimum (small amount)
            false,
            path
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
                    PATH VALIDATION TESTS (P1-1)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test revert when path[0] does not match tokenIn (non-native)
    function test_UniswapV2_RevertIf_PathStartMismatch() public {
        address account = instanceOnEth.account;

        // tokenIn = USDC but path starts with WETH
        address[] memory path = _buildPath(CHAIN_1_WETH, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC, // tokenIn
            CHAIN_1_WETH, // tokenOut
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );

        vm.expectRevert(SwapUniswapV2Hook.INVALID_PATH.selector);
        swapHook.build(address(0), account, hookData);
    }

    /// @notice Test revert when path[last] does not match tokenOut (non-native)
    function test_UniswapV2_RevertIf_PathEndMismatch() public {
        address account = instanceOnEth.account;

        // tokenOut = WETH but path ends with DAI
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_DAI);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC, // tokenIn
            CHAIN_1_WETH, // tokenOut — does NOT match path[1]
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );

        vm.expectRevert(SwapUniswapV2Hook.INVALID_PATH.selector);
        swapHook.build(address(0), account, hookData);
    }

    /// @notice Test that path validation is skipped for NATIVE tokenIn (router handles WETH)
    function test_UniswapV2_PathValidation_NativeInputSkipped() public view {
        address account = instanceOnEth.account;

        // tokenIn = NATIVE, path[0] = WETH — should NOT revert
        address[] memory path = _buildPath(CHAIN_1_WETH, CHAIN_1_USDC);
        bytes memory hookData = _buildHookData(
            NATIVE,        // tokenIn = NATIVE sentinel
            CHAIN_1_USDC,  // tokenOut
            block.timestamp + 1 hours,
            1 ether,
            1000e6,
            false,
            path
        );

        // Should not revert — path[0] != NATIVE is expected for native swaps
        swapHook.build(address(0), account, hookData);
    }

    /// @notice Test that path validation is skipped for NATIVE tokenOut (router handles WETH)
    function test_UniswapV2_PathValidation_NativeOutputSkipped() public view {
        address account = instanceOnEth.account;

        // tokenOut = NATIVE, path[last] = WETH — should NOT revert
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,  // tokenIn
            NATIVE,        // tokenOut = NATIVE sentinel
            block.timestamp + 1 hours,
            1000e6,
            0.5 ether,
            false,
            path
        );

        // Should not revert — path[last] != NATIVE is expected for native output swaps
        swapHook.build(address(0), account, hookData);
    }

    /// @notice Test path validation on ApproveAndSwap variant
    function test_UniswapV2_ApproveAndSwap_RevertIf_PathMismatch() public {
        address account = instanceOnEth.account;

        // tokenIn = USDC but path starts with DAI
        address[] memory path = _buildPath(CHAIN_1_DAI, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC, // tokenIn — does NOT match path[0]
            CHAIN_1_WETH, // tokenOut
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );

        vm.expectRevert(ApproveAndSwapUniswapV2Hook.INVALID_PATH.selector);
        approveAndSwapHook.build(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                    PATH LENGTH VALIDATION TESTS (P2-4)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test revert when path has only 1 element (too short)
    /// @dev pathLength=1 with 1 address = 189 bytes total, which is < 209 minimum,
    ///      so INVALID_HOOK_DATA fires before _decodeSwapParams can check pathLength.
    ///      We manually craft 209+ bytes with pathLength=1 to hit the path length check.
    function test_UniswapV2_RevertIf_PathTooShort() public {
        address account = instanceOnEth.account;

        // Build data with pathLength=1 but pad to pass the 209-byte minimum check.
        // Normal _buildHookData with 1-element path yields 189 bytes (under 209).
        // Instead, encode pathLength=1 with extra padding so data.length >= 209.
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );
        // Overwrite pathLength at offset 137 (32 bytes) to 1 instead of 2.
        // The data still has 2 addresses appended (209 bytes total), so it passes the
        // minimum length check, but _decodeSwapParams sees pathLength < 2 and reverts.
        assembly {
            // hookData is a bytes variable: first 32 bytes = length, data starts at +32
            // pathLength is at byte offset 137 in the data, stored as uint256 (32 bytes)
            // So it occupies bytes [137..168], which is at memory offset 32 + 137 = 169
            mstore(add(hookData, 169), 1)
        }

        vm.expectRevert(SwapUniswapV2Hook.INVALID_PATH_LENGTH.selector);
        swapHook.build(address(0), account, hookData);
    }

    /// @notice Test revert when path exceeds MAX_PATH_LENGTH (10)
    function test_UniswapV2_RevertIf_PathTooLong() public {
        address account = instanceOnEth.account;

        // Build path with 11 elements (exceeds MAX_PATH_LENGTH = 10)
        address[] memory path = new address[](11);
        path[0] = CHAIN_1_USDC;
        for (uint256 i = 1; i < 10; i++) {
            path[i] = CHAIN_1_WETH;
        }
        path[10] = CHAIN_1_WETH;

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );

        vm.expectRevert(SwapUniswapV2Hook.INVALID_PATH_LENGTH.selector);
        swapHook.build(address(0), account, hookData);
    }

    /// @notice Test that path with exactly MAX_PATH_LENGTH (10) is accepted
    function test_UniswapV2_PathAtMaxLength() public view {
        address account = instanceOnEth.account;

        // Build path with exactly 10 elements (should pass validation)
        address[] memory path = new address[](10);
        path[0] = CHAIN_1_USDC;
        for (uint256 i = 1; i < 9; i++) {
            path[i] = CHAIN_1_WETH;
        }
        path[9] = CHAIN_1_WETH;

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );

        // Should not revert — 10 is within MAX_PATH_LENGTH
        swapHook.build(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                    ZERO AMOUNT CHAINING TESTS (P2-2)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test revert when usePrevHookAmount=true and previous hook returns 0
    function test_UniswapV2_RevertIf_PrevHookAmountZero() public {
        address account = instanceOnEth.account;

        // Mock previous hook that returns 0
        MockPrevHookV2 zeroPrevHook = new MockPrevHookV2(0);

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,  // originalAmountIn
            0.1 ether, // originalMinAmountOut
            true,    // usePrevHookAmount = true
            path
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.build(address(zeroPrevHook), account, hookData);
    }

    /// @notice Test revert on ApproveAndSwap when usePrevHookAmount=true and previous hook returns 0
    function test_UniswapV2_ApproveAndSwap_RevertIf_PrevHookAmountZero() public {
        address account = instanceOnEth.account;

        MockPrevHookV2 zeroPrevHook = new MockPrevHookV2(0);

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            true,
            path
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndSwapHook.build(address(zeroPrevHook), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                    HOOK DATA VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test revert when hook data is too short (< 209 bytes)
    function test_UniswapV2_RevertIf_HookDataTooShort() public {
        address account = instanceOnEth.account;

        // 100 bytes of garbage data — well under the 209 byte minimum
        bytes memory shortData = new bytes(100);

        vm.expectRevert(SwapUniswapV2Hook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, shortData);
    }

    /// @notice Test revert when data length doesn't match claimed pathLength
    function test_UniswapV2_RevertIf_DataLengthMismatch() public {
        address account = instanceOnEth.account;

        // Build valid hook data for 2-element path, then truncate one address
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp + 1 hours,
            1000e6,
            0.1 ether,
            false,
            path
        );

        // Truncate 10 bytes from the end — pathLength says 2 but data is too short
        bytes memory truncated = new bytes(hookData.length - 10);
        for (uint256 i = 0; i < truncated.length; i++) {
            truncated[i] = hookData[i];
        }

        vm.expectRevert(SwapUniswapV2Hook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(0), account, truncated);
    }

    /// @notice Test revert when deadline is in the past
    function test_UniswapV2_RevertIf_DeadlineExpired_Direct() public {
        address account = instanceOnEth.account;

        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            block.timestamp - 1, // expired
            1000e6,
            0.1 ether,
            false,
            path
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                SwapUniswapV2Hook.EXPIRED_DEADLINE.selector, block.timestamp - 1, block.timestamp
            )
        );
        swapHook.build(address(0), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test revert when router address is zero
    function test_UniswapV2_RevertIf_RouterZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapUniswapV2Hook(address(0), NATIVE);
    }

    /// @notice Test revert when router is zero on ApproveAndSwap variant
    function test_UniswapV2_ApproveAndSwap_RevertIf_RouterZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapUniswapV2Hook(address(0), NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for UniswapV2 hooks
    function test_UniswapV2_DecodeAmounts_ReplaceCalldataAmounts() external view {
        address account = instanceOnEth.account;
        uint256 originalAmount = 1000e6;
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);

        bytes memory hookData =
            _buildHookData(CHAIN_1_USDC, CHAIN_1_WETH, block.timestamp + 1 hours, originalAmount, 0.2 ether, false, path);

        // Verify decodeAmount
        assertEq(swapHook.decodeAmounts(hookData)[0], originalAmount, "SwapHook decodeAmount mismatch");
        assertEq(approveAndSwapHook.decodeAmounts(hookData)[0], originalAmount, "ApproveAndSwapHook decodeAmount mismatch");

        // Replace and verify roundtrip
        uint256 newAmount = 500e6;
        bytes memory replacedSwap = swapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        bytes memory replacedApproveAndSwap = approveAndSwapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));

        assertEq(swapHook.decodeAmounts(replacedSwap)[0], newAmount, "SwapHook replaced amount mismatch");
        assertEq(approveAndSwapHook.decodeAmounts(replacedApproveAndSwap)[0], newAmount, "ApproveAndSwapHook replaced amount mismatch");
        assertFalse(swapHook.decodeUsePrevHookAmount(replacedSwap), "usePrevHookAmount should be preserved");
    }

    /// @notice ApproveAndSwap: build with 1000 USDC, replace to 500 USDC, execute, verify only 500 spent
    function test_UniswapV2_ApproveAndSwap_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        address account = instanceOnEth.account;
        uint256 originalAmount = 1000e6;
        uint256 newAmount = 500e6;
        address[] memory path = _buildPath(CHAIN_1_USDC, CHAIN_1_WETH);

        deal(CHAIN_1_USDC, account, originalAmount);

        bytes memory hookData =
            _buildHookData(CHAIN_1_USDC, CHAIN_1_WETH, block.timestamp + 1 hours, originalAmount, 0, false, path);

        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount, "Amount not replaced correctly");

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        // Execute via SuperExecutor
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
