// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform imports
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { SwapUniswapV4Hook } from "../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { DynamicMinAmountCalculator } from "../../../src/libraries/uniswap-v4/DynamicMinAmountCalculator.sol";

// Uniswap V4 imports
import { 
    IPoolManagerSuperform,
    PoolKey, 
    Currency,
    CurrencyLibrary,
    IHooks
} from "../../../src/interfaces/external/uniswap-v4/IPoolManagerSuperform.sol";

// Test imports
import { UniswapV4Constants } from "../../utils/constants/UniswapV4Constants.sol";
import { UniswapV4Parser } from "../../utils/parsers/UniswapV4Parser.sol";
import { MockPoolManager } from "../../mocks/MockPoolManager.sol";

/// @title UniswapV4HookIntegrationTest
/// @author Superform Labs
/// @notice Comprehensive integration tests for Uniswap V4 hook
/// @dev Tests dynamic minAmount recalculation, hook chaining, and real V4 integration patterns
contract UniswapV4HookIntegrationTest is MinimalBaseIntegrationTest, UniswapV4Constants {
    using CurrencyLibrary for address;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapUniswapV4Hook public uniswapV4Hook;
    UniswapV4Parser public parser;
    ISuperNativePaymaster public superNativePaymaster;
    
    IPoolManagerSuperform public poolManager;
    
    // Test pool configuration
    PoolKey public testPoolKey;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        
        // Deploy mock Pool Manager (until V4 is live on mainnet)
        poolManager = IPoolManagerSuperform(address(new MockPoolManager()));
        
        // Deploy UniswapV4 Hook
        uniswapV4Hook = new SwapUniswapV4Hook(address(poolManager));
        
        // Deploy parser
        parser = new UniswapV4Parser();
        
        // Deploy paymaster
        superNativePaymaster = ISuperNativePaymaster(
            new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR))
        );
        
        // Setup test pool (USDC/WETH)
        testPoolKey = PoolKey({
            currency0: Currency.wrap(V4_USDC), // USDC
            currency1: Currency.wrap(V4_WETH), // WETH
            fee: FEE_MEDIUM,
            tickSpacing: TICK_SPACING_MEDIUM,
            hooks: IHooks(address(0))
        });
        
        // Setup mock pool with realistic exchange rate
        MockPoolManager(address(poolManager)).setupMockPool(testPoolKey, MOCK_USDC_PER_WETH);
        
        // Fund the account with test tokens
        _getTokens(V4_USDC, accountEth, 100_000_000); // 100 USDC
        _getTokens(V4_WETH, accountEth, 1e18); // 1 WETH
        _getTokens(V4_WBTC, accountEth, 1e8); // 1 WBTC
        
        // Add liquidity to mock pool
        _addMockLiquidity();
    }

    // CRITICAL: Integration test contracts MUST include receive() for EntryPoint fee refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            BASIC SWAP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_BasicSwap_USDC_to_WETH() external {
        console2.log("=== UniswapV4Hook Basic Swap Test: USDC to WETH ===");
        
        uint256 swapAmount = V4_MEDIUM_SWAP; // 10 USDC
        uint256 expectedMinOut = calculateMinAmountOut(swapAmount, 1e18 / MOCK_USDC_PER_WETH, 300); // 3% slippage
        
        // Log initial balances
        uint256 usdcBefore = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wethBefore = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("Initial Balances:");
        console2.log("  USDC:", usdcBefore);
        console2.log("  WETH:", wethBefore);
        
        // Generate hook data using parser
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: swapAmount,
                minAmountOut: expectedMinOut,
                sqrtPriceLimitX96: 0, // No price limit
                maxSlippageDeviationBps: DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS
            }),
            false // Don't use prev hook amount
        );
        
        // Setup hook execution following existing pattern
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(uniswapV4Hook);
        
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;
        
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData
        });
        
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        
        // Execute through paymaster (following existing pattern)
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
        
        // Verify results
        uint256 usdcAfter = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wethAfter = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("Post-Execution Balances:");
        console2.log("  USDC:", usdcAfter);
        console2.log("  WETH:", wethAfter);
        
        // Verify swap executed correctly
        assertEq(usdcBefore - usdcAfter, swapAmount, "USDC input should match");
        assertGe(wethAfter - wethBefore, expectedMinOut, "WETH output should meet minimum");
    }

    function test_UniswapV4Hook_BasicSwap_WETH_to_USDC() external {
        console2.log("=== UniswapV4Hook Basic Swap Test: WETH to USDC ===");
        
        uint256 swapAmount = 0.01 ether; // 0.01 WETH
        uint256 expectedMinOut = calculateMinAmountOut(swapAmount, MOCK_USDC_PER_WETH, 300); // 3% slippage
        
        // Log initial balances
        uint256 wethBefore = IERC20(V4_WETH).balanceOf(accountEth);
        uint256 usdcBefore = IERC20(V4_USDC).balanceOf(accountEth);
        
        console2.log("Initial Balances:");
        console2.log("  WETH:", wethBefore);
        console2.log("  USDC:", usdcBefore);
        
        // Generate hook data for reverse swap
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_WETH,
                tokenOut: V4_USDC,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: swapAmount,
                minAmountOut: expectedMinOut,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS
            }),
            false
        );
        
        // Execute swap
        _executeSingleHookSwap(hookData);
        
        // Verify results
        uint256 wethAfter = IERC20(V4_WETH).balanceOf(accountEth);
        uint256 usdcAfter = IERC20(V4_USDC).balanceOf(accountEth);
        
        console2.log("Post-Execution Balances:");
        console2.log("  WETH:", wethAfter);
        console2.log("  USDC:", usdcAfter);
        
        assertEq(wethBefore - wethAfter, swapAmount, "WETH input should match");
        assertGe(usdcAfter - usdcBefore, expectedMinOut, "USDC output should meet minimum");
    }

    /*//////////////////////////////////////////////////////////////
                    DYNAMIC MINAMOUNT RECALCULATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_DynamicMinAmountRecalculation() external {
        console2.log("=== Dynamic MinAmount Recalculation Test ===");
        
        // Test the critical requirement: changing amountIn should recalculate minAmount
        uint256 originalAmountIn = V4_MEDIUM_SWAP; // 10 USDC
        uint256 originalMinAmountOut = calculateMinAmountOut(originalAmountIn, 1e18 / MOCK_USDC_PER_WETH, 300);
        uint256 changedAmountIn = (originalAmountIn * 120) / 100; // 20% increase
        
        // Create hook data with original amounts
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: originalAmountIn,
                minAmountOut: originalMinAmountOut,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: STRICT_MAX_SLIPPAGE_DEVIATION_BPS // Only 0.5% deviation allowed
            }),
            true // Use prev hook amount (simulating changed amount)
        );
        
        // Mock previous hook that changes the amount
        MockHookResult mockPrevHook = new MockHookResult(changedAmountIn);
        
        // Since 20% change exceeds 0.5% max deviation, this should fail
        vm.expectRevert(
            abi.encodeWithSelector(
                DynamicMinAmountCalculator.ExcessiveSlippageDeviation.selector,
                2000, // 20% deviation in bps
                STRICT_MAX_SLIPPAGE_DEVIATION_BPS // 0.5% max allowed
            )
        );
        
        // Attempt to execute with excessive deviation
        _executeMockHookChain(address(mockPrevHook), hookData);
    }

    function test_UniswapV4Hook_DynamicMinAmountRecalculation_Success() external {
        console2.log("=== Dynamic MinAmount Recalculation Success Test ===");
        
        uint256 originalAmountIn = V4_MEDIUM_SWAP;
        uint256 originalMinAmountOut = calculateMinAmountOut(originalAmountIn, 1e18 / MOCK_USDC_PER_WETH, 300);
        uint256 changedAmountIn = (originalAmountIn * 101) / 100; // Only 1% increase
        
        // Create hook data allowing 1% deviation
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: originalAmountIn,
                minAmountOut: originalMinAmountOut,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS // 1% deviation allowed
            }),
            true
        );
        
        // Mock previous hook with acceptable change
        MockHookResult mockPrevHook = new MockHookResult(changedAmountIn);
        
        // Log balances before
        uint256 usdcBefore = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wethBefore = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("Before Dynamic Recalculation:");
        console2.log("  Original AmountIn:", originalAmountIn);
        console2.log("  Changed AmountIn:", changedAmountIn);
        console2.log("  Original MinAmountOut:", originalMinAmountOut);
        
        // This should succeed with recalculated minAmountOut
        _executeMockHookChain(address(mockPrevHook), hookData);
        
        uint256 usdcAfter = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wethAfter = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("After Dynamic Recalculation:");
        console2.log("  Actual AmountIn Used:", usdcBefore - usdcAfter);
        console2.log("  WETH Received:", wethAfter - wethBefore);
        
        // Verify the changed amount was used
        assertEq(usdcBefore - usdcAfter, changedAmountIn, "Should use changed amount from previous hook");
        
        // Verify we got proportionally adjusted output
        uint256 expectedNewMinOut = (originalMinAmountOut * changedAmountIn) / originalAmountIn;
        assertGe(wethAfter - wethBefore, expectedNewMinOut, "Should meet recalculated minimum output");
    }

    /*//////////////////////////////////////////////////////////////
                           HOOK CHAINING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_HookChaining() external {
        console2.log("=== Hook Chaining with Previous Amount ===");
        
        // Simulate a bridge hook that provides tokens, followed by V4 swap
        uint256 bridgeOutput = V4_SMALL_SWAP; // 1 USDC from bridge
        uint256 expectedSwapOutput = calculateMinAmountOut(bridgeOutput, 1e18 / MOCK_USDC_PER_WETH, 500); // 5% slippage
        
        MockHookResult mockBridgeHook = new MockHookResult(bridgeOutput);
        
        // V4 hook uses previous hook amount
        bytes memory v4HookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: 0, // Will be overridden by prevHook amount
                minAmountOut: expectedSwapOutput,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: LOOSE_MAX_SLIPPAGE_DEVIATION_BPS // 5% for chained operations
            }),
            true // Use prev hook amount
        );
        
        uint256 wethBefore = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("Hook Chaining Test:");
        console2.log("  Bridge Output:", bridgeOutput);
        console2.log("  Expected Min Swap Output:", expectedSwapOutput);
        
        // Execute chained hooks
        _executeMockHookChain(address(mockBridgeHook), v4HookData);
        
        uint256 wethAfter = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("  Actual WETH Received:", wethAfter - wethBefore);
        
        assertGe(wethAfter - wethBefore, expectedSwapOutput, "Should receive expected output from chained execution");
    }

    /*//////////////////////////////////////////////////////////////
                           MULTI-HOP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_MultiHopSwap() external {
        console2.log("=== Multi-Hop Swap Test: USDC -> WETH -> WBTC ===");
        
        uint256 swapAmount = V4_LARGE_SWAP; // 100 USDC
        
        // Setup additional mock pool for WETH/WBTC
        PoolKey memory wethWbtcPool = PoolKey({
            currency0: Currency.wrap(V4_WETH),
            currency1: Currency.wrap(V4_WBTC),
            fee: FEE_MEDIUM,
            tickSpacing: TICK_SPACING_MEDIUM,
            hooks: IHooks(address(0))
        });
        
        MockPoolManager(address(poolManager)).setupMockPool(wethWbtcPool, MOCK_WETH_PER_WBTC);
        
        // Generate multi-hop swap data
        bytes memory hookData = parser.generateUSDCtoWBTCSwapData(
            accountEth,
            swapAmount,
            false // Don't use prev hook amount
        );
        
        uint256 usdcBefore = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wbtcBefore = IERC20(V4_WBTC).balanceOf(accountEth);
        
        console2.log("Multi-Hop Initial Balances:");
        console2.log("  USDC:", usdcBefore);
        console2.log("  WBTC:", wbtcBefore);
        
        // Note: This test demonstrates the structure but would need a multi-hop hook implementation
        // For now, we validate the hook data generation
        (bool isValid, uint256 dataLength) = parser.validateHookData(hookData);
        assertTrue(isValid, "Multi-hop hook data should be valid");
        assertGt(dataLength, 100, "Multi-hop hook data should have substantial length");
        
        console2.log("Multi-hop hook data generated successfully with length:", dataLength);
    }

    /*//////////////////////////////////////////////////////////////
                           EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_SmallAmountSwap() external {
        console2.log("=== Small Amount Swap Test ===");
        
        uint256 swapAmount = 1000; // Very small amount (0.001 USDC)
        
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: swapAmount,
                minAmountOut: 1, // Minimal output expected
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: LOOSE_MAX_SLIPPAGE_DEVIATION_BPS // 5% for small amounts
            }),
            false
        );
        
        uint256 usdcBefore = IERC20(V4_USDC).balanceOf(accountEth);
        
        // Should handle small amounts gracefully
        _executeSingleHookSwap(hookData);
        
        uint256 usdcAfter = IERC20(V4_USDC).balanceOf(accountEth);
        assertEq(usdcBefore - usdcAfter, swapAmount, "Should handle small amounts correctly");
    }

    function test_UniswapV4Hook_InspectFunction() external {
        console2.log("=== Inspect Function Test ===");
        
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: V4_MEDIUM_SWAP,
                minAmountOut: 1000,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS
            }),
            false
        );
        
        // Test the inspect function
        bytes memory packedResult = uniswapV4Hook.inspect(hookData);
        
        // Decode the result - should contain input and output tokens (40 bytes total)
        assertEq(packedResult.length, 40, "Inspect result should contain two addresses");
        
        address extractedToken0 = address(bytes20(packedResult[0:20]));
        address extractedToken1 = address(bytes20(packedResult[20:40]));
        
        // Should contain both USDC and WETH (in sorted order)
        assertTrue(
            (extractedToken0 == V4_USDC && extractedToken1 == V4_WETH) ||
            (extractedToken0 == V4_WETH && extractedToken1 == V4_USDC),
            "Should extract correct token pair"
        );
    }

    function test_UniswapV4Hook_DecodeUsePrevHookAmount() external {
        console2.log("=== Decode UsePrevHookAmount Test ===");
        
        // Test with usePrevHookAmount = true
        bytes memory hookDataTrue = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: V4_MEDIUM_SWAP,
                minAmountOut: 1000,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS
            }),
            true // usePrevHookAmount = true
        );
        
        assertTrue(uniswapV4Hook.decodeUsePrevHookAmount(hookDataTrue), "Should decode true correctly");
        
        // Test with usePrevHookAmount = false
        bytes memory hookDataFalse = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: V4_MEDIUM_SWAP,
                minAmountOut: 1000,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS
            }),
            false // usePrevHookAmount = false
        );
        
        assertFalse(uniswapV4Hook.decodeUsePrevHookAmount(hookDataFalse), "Should decode false correctly");
    }

    /*//////////////////////////////////////////////////////////////
                           HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute a single hook swap
    /// @param hookData Encoded hook data
    function _executeSingleHookSwap(bytes memory hookData) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(uniswapV4Hook);
        
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;
        
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData
        });
        
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /// @notice Execute hook chain with mock previous hook
    /// @param prevHookAddress Address of mock previous hook
    /// @param v4HookData Hook data for V4 hook
    function _executeMockHookChain(address prevHookAddress, bytes memory v4HookData) internal {
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = prevHookAddress;
        hooksAddresses[1] = address(uniswapV4Hook);
        
        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = ""; // Mock previous hook data
        hooksData[1] = v4HookData;
        
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData
        });
        
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 1e18);
    }

    /// @notice Add mock liquidity to pools for realistic testing
    function _addMockLiquidity() internal {
        bytes32 poolId = keccak256(abi.encode(testPoolKey));
        
        // Approve mock pool manager to spend tokens
        vm.prank(accountEth);
        IERC20(V4_USDC).approve(address(poolManager), type(uint256).max);
        vm.prank(accountEth);
        IERC20(V4_WETH).approve(address(poolManager), type(uint256).max);
        
        // Add substantial liquidity for testing
        MockPoolManager(address(poolManager)).addMockLiquidity(
            poolId,
            V4_USDC,
            V4_WETH,
            50_000_000, // 50 USDC
            20_000_000_000_000_000 // 0.02 WETH
        );
    }
}

/// @notice Mock contract for testing previous hook results
contract MockHookResult {
    uint256 private _outAmount;
    
    constructor(uint256 outAmount) {
        _outAmount = outAmount;
    }
    
    function getOutAmount(address) external view returns (uint256) {
        return _outAmount;
    }
    
    // Mock hook interface functions (minimal implementation)
    function build(address, address, bytes calldata) external pure returns (bytes[] memory) {
        bytes[] memory executions = new bytes[](0);
        return executions;
    }
    
    function preExecute(address, address, bytes calldata) external pure {
        // Mock implementation
    }
    
    function postExecute(address, address, bytes calldata) external pure {
        // Mock implementation  
    }
}