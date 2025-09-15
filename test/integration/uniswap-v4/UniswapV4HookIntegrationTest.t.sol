// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform imports
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { SwapUniswapV4Hook } from "../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { UniswapV4Parser } from "../../utils/parsers/UniswapV4Parser.sol";

// Real Uniswap V4 imports
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";
import { PoolId, PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";

/// @title UniswapV4HookIntegrationTest
/// @author Superform Labs
/// @notice Comprehensive integration tests for Uniswap V4 hook using real mainnet forks when available
/// @dev Tests dynamic minAmount recalculation, hook chaining, and integration patterns
contract UniswapV4HookIntegrationTest is MinimalBaseIntegrationTest {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to avoid stack too deep in swap test
    struct SwapTestParams {
        uint256 sellAmount;
        bool zeroForOne;
        uint256 expectedMinOut;
        address account;
        uint256 initialUSDCBalance;
        uint256 initialWETHBalance;
        uint256 finalUSDCBalance;
        uint256 finalWETHBalance;
        uint256 wethReceived;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapUniswapV4Hook public uniswapV4Hook;
    UniswapV4Parser public parser;
    ISuperNativePaymaster public superNativePaymaster;

    IPoolManager public poolManager;

    // Test pool configuration
    PoolKey public testPoolKey;

    // V4 pool parameters
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    int24 public constant TICK_SPACING_MEDIUM = 60;
    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        console2.log("Using real V4 deployment");
        poolManager = IPoolManager(MAINNET_V4_POOL_MANAGER);

        // Deploy UniswapV4 Hook
        uniswapV4Hook = new SwapUniswapV4Hook(address(poolManager));

        console2.log("HOOK ADDRESS:", address(uniswapV4Hook));
        console2.log("USER ADDRESS:", address(instanceOnEth.account));

        // Deploy parser
        parser = new UniswapV4Parser();

        // Deploy paymaster
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));
        // Setup test pool (USDC/WETH)
        testPoolKey = PoolKey({
            currency0: Currency.wrap(CHAIN_1_USDC), // USDC
            currency1: Currency.wrap(CHAIN_1_WETH), // WETH
            fee: FEE_MEDIUM,
            tickSpacing: TICK_SPACING_MEDIUM,
            hooks: IHooks(address(0))
        });
    }

    // CRITICAL: Integration test contracts MUST include receive() for EntryPoint fee refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Integer square root using Babylonian method
    /// @param x The number to calculate square root of
    /// @return The square root of x
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    /// @notice Calculate appropriate sqrtPriceLimitX96 based on current pool price and slippage tolerance
    /// @param poolKey The pool to get current price from
    /// @param zeroForOne Direction of the swap
    /// @param slippageToleranceBps Slippage tolerance in basis points (e.g., 50 = 0.5%)
    /// @return sqrtPriceLimitX96 The calculated price limit
    function _calculatePriceLimit(
        PoolKey memory poolKey,
        bool zeroForOne,
        uint256 slippageToleranceBps
    ) internal view returns (uint160 sqrtPriceLimitX96) {
        PoolId poolId = PoolIdLibrary.toId(poolKey);
        
        // Get current pool price using StateLibrary
        (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        
        // Handle uninitialized pools - use a reasonable default
        if (currentSqrtPriceX96 == 0) {
            // For testing, use 1:1 price ratio as fallback
            currentSqrtPriceX96 = 79228162514264337593543950336;
        }
        
        // Calculate slippage factor (10000 = 100%)
        uint256 slippageFactor = zeroForOne 
            ? 10000 - slippageToleranceBps  // Price goes down
            : 10000 + slippageToleranceBps; // Price goes up
        
        // Apply square root to slippage factor (since we're dealing with sqrt prices)
        // Scale up for precision, then scale back down
        uint256 sqrtSlippageFactor = _sqrt(slippageFactor * 1e18 / 10000);
        uint256 adjustedPrice = (uint256(currentSqrtPriceX96) * sqrtSlippageFactor) / 1e9;
        
        // Enforce TickMath boundaries
        if (zeroForOne) {
            // For zeroForOne, price decreases, ensure we don't go below minimum
            sqrtPriceLimitX96 = adjustedPrice < TickMath.MIN_SQRT_PRICE + 1
                ? TickMath.MIN_SQRT_PRICE + 1
                : uint160(adjustedPrice);
        } else {
            // For !zeroForOne, price increases, ensure we don't exceed maximum
            sqrtPriceLimitX96 = adjustedPrice > TickMath.MAX_SQRT_PRICE - 1
                ? TickMath.MAX_SQRT_PRICE - 1
                : uint160(adjustedPrice);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_HookDataDecoding() external {
        console2.log("=== UniswapV4Hook Data Decoding Test ===");

        uint256 swapAmountIn = 1000e6; // 1000 USDC
        uint256 expectedMinOut = 300_000_000_000_000_000; // ~0.3 WETH minimum
        bool zeroForOne = true; // USDC -> WETH

        // Calculate appropriate price limit with 0.5% slippage
        uint160 priceLimit = _calculatePriceLimit(testPoolKey, zeroForOne, 50);

        // Generate swap calldata using the parser
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: accountEth,
                sqrtPriceLimitX96: priceLimit, // Use same price limit as quote
                originalAmountIn: swapAmountIn,
                originalMinAmountOut: expectedMinOut,
                maxSlippageDeviationBps: 500, // 5% max deviation
                zeroForOne: zeroForOne,
                additionalData: ""
            }),
            false // Don't use prev hook amount
        );

        // Test hook can decode the data properly
        bool usePrevHookAmount = uniswapV4Hook.decodeUsePrevHookAmount(swapCalldata);
        assertFalse(usePrevHookAmount, "Should not use prev hook amount");

        console2.log("Hook data decoding test passed");
    }

    function test_UniswapV4Hook_InspectFunction() external {
        console2.log("=== UniswapV4Hook Inspect Function Test ===");

        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: accountEth,
                sqrtPriceLimitX96: 0,
                originalAmountIn: 1000e6,
                originalMinAmountOut: 300_000_000_000_000_000,
                maxSlippageDeviationBps: 500,
                zeroForOne: true, // USDC -> WETH
                additionalData: ""
            }),
            false
        );

        // Test inspect function returns token addresses
        bytes memory inspectResult = uniswapV4Hook.inspect(swapCalldata);
        assertEq(inspectResult.length, 40, "Should return 40 bytes (2 addresses)");

        // Extract addresses using assembly for slice operations
        address token0;
        address token1;
        assembly {
            // Load 32 bytes starting from offset 0x20 (skip length prefix)
            let firstWord := mload(add(inspectResult, 0x20))
            // Extract first address (first 20 bytes) by shifting right 12 bytes (96 bits)
            token0 := shr(96, firstWord)
            
            // Load 32 bytes starting from offset 0x20 + 20 = 0x34
            let secondWord := mload(add(inspectResult, 0x34))
            // Extract second address (first 20 bytes) by shifting right 12 bytes (96 bits)
            token1 := shr(96, secondWord)
        }

        // Verify correct token addresses returned
        assertEq(token0, CHAIN_1_USDC, "Token0 should be USDC");
        assertEq(token1, CHAIN_1_WETH, "Token1 should be WETH");

        console2.log("Inspect function test passed");
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test successful swap with amount tracking
    function test_UniswapV4SwapWithAmountTracking() public {
        console2.log("=== UniswapV4Hook Swap Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1000e6; // 1000 USDC
        params.zeroForOne = CHAIN_1_USDC < CHAIN_1_WETH; // Derive zeroForOne based on addresses

        // Calculate appropriate price limit with 1% slippage tolerance (100 bps)
        uint160 priceLimit = _calculatePriceLimit(testPoolKey, params.zeroForOne, 100); // 100 bps = 1%
        console2.log("Calculated price limit for quote and swap:", priceLimit);

        // Get realistic minimum using HOOK'S ON-CHAIN QUOTE with the same price limit
        SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: params.zeroForOne,
                amountIn: params.sellAmount,
                sqrtPriceLimitX96: priceLimit // Use same price limit for quote
             })
        );
        params.expectedMinOut = quote.amountOut * 995 / 1000; // Apply 0.5% additional slippage buffer on quote

        // Get account address and setup
        params.account = instanceOnEth.account;
        deal(CHAIN_1_USDC, params.account, params.sellAmount);

        // Get initial balances
        params.initialUSDCBalance = IERC20(CHAIN_1_USDC).balanceOf(params.account);
        params.initialWETHBalance = IERC20(CHAIN_1_WETH).balanceOf(params.account);

        console2.log("Initial USDC balance:", params.initialUSDCBalance);
        console2.log("Initial WETH balance:", params.initialWETHBalance);
        console2.log("Expected minimum WETH out (from pool quote):", params.expectedMinOut);
        console2.log("Quoted amountOut:", quote.amountOut);

        // Generate swap calldata using the parser
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: params.account,
                sqrtPriceLimitX96: priceLimit, // Use same price limit as quote
                originalAmountIn: params.sellAmount,
                originalMinAmountOut: params.expectedMinOut,
                maxSlippageDeviationBps: 500, // Keep for amount ratio protection
                zeroForOne: params.zeroForOne,
                additionalData: ""
            }),
            false // Don't use prev hook amount
        );

        // Set up hook execution - single hook for swap
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = swapCalldata;

        // Execute via SuperExecutor
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Execute the swap
        executeOp(opData);

        // Verify swap was successful
        params.finalUSDCBalance = IERC20(CHAIN_1_USDC).balanceOf(params.account);
        params.finalWETHBalance = IERC20(CHAIN_1_WETH).balanceOf(params.account);

        console2.log("Final USDC balance:", params.finalUSDCBalance);
        console2.log("Final WETH balance:", params.finalWETHBalance);

        // Allow for small tolerance due to gas costs
        assertLe(params.finalUSDCBalance, params.initialUSDCBalance - params.sellAmount + 1e6, "USDC should be spent");
        assertGt(params.finalWETHBalance, params.initialWETHBalance, "WETH balance should increase");

        // Verify minimum buy amount was respected
        params.wethReceived = params.finalWETHBalance - params.initialWETHBalance;
        assertGe(params.wethReceived, params.expectedMinOut, "Should receive at least minimum buy amount");

        // Log final results
        console2.log("USDC spent:", params.initialUSDCBalance - params.finalUSDCBalance);
        console2.log("WETH received:", params.wethReceived);
        console2.log("Swap test passed successfully");
    }
}
