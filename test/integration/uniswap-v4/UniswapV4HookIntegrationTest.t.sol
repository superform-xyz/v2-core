// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";
import { PoolId, PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform imports
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { SwapUniswapV4Hook } from "../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { NativeTransferHook } from "../../../src/hooks/tokens/NativeTransferHook.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { UniswapV4Parser } from "../../utils/parsers/UniswapV4Parser.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";

import { BaseHook } from "../../../src/hooks/BaseHook.sol";

import "forge-std/console2.sol";

/// @title UniswapV4HookIntegrationTest
/// @author Superform Labs
/// @notice Comprehensive integration tests for Uniswap V4 hook using real mainnet forks when available
/// @dev Tests dynamic minAmount recalculation, hook chaining, and integration patterns
contract UniswapV4HookIntegrationTest is MinimalBaseIntegrationTest {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using ModuleKitHelpers for *;

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
    NativeTransferHook public nativeTransferHook;
    UniswapV4Parser public parser;
    ISuperNativePaymaster public superNativePaymaster;

    IPoolManager public poolManager;

    // Test pool configuration
    PoolKey public testPoolKey;
    PoolKey public nativePoolKey; // ETH/USDC pool for native token tests

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

        // Deploy hooks
        uniswapV4Hook = new SwapUniswapV4Hook(address(poolManager));
        nativeTransferHook = new NativeTransferHook();

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

        // Setup native pool (ETH/USDC) for native token tests
        nativePoolKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO, // Native ETH
            currency1: Currency.wrap(CHAIN_1_USDC), // USDC
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
    )
        internal
        view
        returns (uint160 sqrtPriceLimitX96)
    {
        PoolId poolId = PoolIdLibrary.toId(poolKey);

        // Get current pool price using StateLibrary
        (uint160 currentSqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        // Handle uninitialized pools - use a reasonable default
        if (currentSqrtPriceX96 == 0) {
            // For testing, use 1:1 price ratio as fallback
            currentSqrtPriceX96 = 79_228_162_514_264_337_593_543_950_336;
        }

        // Calculate slippage factor (10000 = 100%)
        uint256 slippageFactor = zeroForOne
            ? 10_000 - slippageToleranceBps // Price goes down
            : 10_000 + slippageToleranceBps; // Price goes up

        // Apply square root to slippage factor (since we're dealing with sqrt prices)
        // Scale up for precision, then scale back down
        uint256 sqrtSlippageFactor = _sqrt(slippageFactor * 1e18 / 10_000);
        uint256 adjustedPrice = (uint256(currentSqrtPriceX96) * sqrtSlippageFactor) / 1e9;

        // Enforce TickMath boundaries
        if (zeroForOne) {
            // For zeroForOne, price decreases, ensure we don't go below minimum
            sqrtPriceLimitX96 =
                adjustedPrice < TickMath.MIN_SQRT_PRICE + 1 ? TickMath.MIN_SQRT_PRICE + 1 : uint160(adjustedPrice);
        } else {
            // For !zeroForOne, price increases, ensure we don't exceed maximum
            sqrtPriceLimitX96 =
                adjustedPrice > TickMath.MAX_SQRT_PRICE - 1 ? TickMath.MAX_SQRT_PRICE - 1 : uint160(adjustedPrice);
        }
    }

    /// @notice Helper to execute native ETH swaps using hook chaining
    function _executeNativeSwap(uint256 ethAmount, bytes memory swapCalldata) private {
        // Set up hook chaining: NativeTransferHook → SwapUniswapV4Hook
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(nativeTransferHook);
        hookAddresses[1] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](2);
        // NativeTransferHook data: transfer ETH to SwapUniswapV4Hook
        hookDataArray[0] = abi.encodePacked(address(uniswapV4Hook), ethAmount);
        // SwapUniswapV4Hook data: existing swap calldata
        hookDataArray[1] = swapCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);
    }

    /// @notice Helper to execute token to native ETH swaps
    function _executeTokenToNativeSwap(bytes memory swapCalldata) private {
        // For token→ETH swaps, use single hook (no ETH input needed)
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = swapCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);
    }

    /// @notice Helper to execute token-to-token swaps
    function _executeTokenSwap(bytes memory swapCalldata, bytes memory revertReason) private {
        // For token swaps, use single hook
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = swapCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });
        // Expect the revert
        if (revertReason.length == 0) {
            instanceOnEth.expect4337Revert();
        } else if (revertReason.length == 4) {
            instanceOnEth.expect4337Revert(bytes4(revertReason));
        } else {
            instanceOnEth.expect4337Revert(revertReason);
        }

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_HookDataDecoding() external view {
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

    function test_UniswapV4Hook_InspectFunction() external view {
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

    /*//////////////////////////////////////////////////////////////
                         NATIVE TOKEN SWAP TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ETH to USDC swap using native tokens
    function test_UniswapV4Hook_NativeETHToUSDC() external {
        console2.log("=== Native ETH to USDC Swap Test ===");

        address account = accountEth;
        uint256 ethAmount = 0.1 ether; // 0.1 ETH
        bool zeroForOne = true; // ETH (token0) -> USDC (token1) in native pool

        // Fund account with ETH for the swap
        vm.deal(account, ethAmount + 1 ether); // Extra for gas

        // Record initial balances
        uint256 initialETHBalance = account.balance;
        uint256 initialUSDCBalance = IERC20(CHAIN_1_USDC).balanceOf(account);

        console2.log("Initial ETH balance:", initialETHBalance);
        console2.log("Initial USDC balance:", initialUSDCBalance);

        // Calculate appropriate price limit with 1% slippage tolerance (100 bps)
        uint160 priceLimit = _calculatePriceLimit(nativePoolKey, zeroForOne, 100); // 100 bps = 1%
        console2.log("Calculated price limit for quote and swap:", priceLimit);

        // Get realistic minimum using HOOK'S ON-CHAIN QUOTE with the same price limit
        SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: nativePoolKey,
                zeroForOne: zeroForOne,
                amountIn: ethAmount,
                sqrtPriceLimitX96: priceLimit // Use same price limit for quote
             })
        );
        uint256 expectedMinUSDC = quote.amountOut * 995 / 1000; // Apply 0.5% additional slippage buffer on quote

        console2.log("Expected minimum USDC out (from pool quote):", expectedMinUSDC);
        console2.log("Quoted amountOut:", quote.amountOut);

        // Generate swap calldata for native ETH to USDC
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: nativePoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: priceLimit, // Use same price limit as quote
                originalAmountIn: ethAmount,
                originalMinAmountOut: expectedMinUSDC,
                maxSlippageDeviationBps: 500, // Keep for amount ratio protection
                zeroForOne: zeroForOne,
                additionalData: ""
            }),
            false
        );

        // Execute the native swap
        _executeNativeSwap(ethAmount, swapCalldata);

        // Verify swap results
        uint256 finalETHBalance = account.balance;
        uint256 finalUSDCBalance = IERC20(CHAIN_1_USDC).balanceOf(account);

        console2.log("Final ETH balance:", finalETHBalance);
        console2.log("Final USDC balance:", finalUSDCBalance);

        // Verify ETH was spent (allowing for gas costs)
        assertLt(finalETHBalance, initialETHBalance - ethAmount + 0.01 ether, "ETH should be spent");
        assertGt(finalUSDCBalance, initialUSDCBalance, "USDC balance should increase");

        uint256 usdcReceived = finalUSDCBalance - initialUSDCBalance;
        assertGe(usdcReceived, expectedMinUSDC, "Should receive at least minimum USDC");

        console2.log("ETH spent:", initialETHBalance - finalETHBalance);
        console2.log("USDC received:", usdcReceived);
        console2.log("Native ETH to USDC swap test passed");
    }

    /// @notice Test USDC to ETH swap receiving native tokens
    function test_UniswapV4Hook_USDCToNativeETH() external {
        console2.log("=== USDC to Native ETH Swap Test ===");

        address account = accountEth;
        uint256 usdcAmount = 500e6; // 500 USDC
        bool zeroForOne = false; // USDC (token1) -> ETH (token0) in native pool

        // Fund account with USDC
        deal(CHAIN_1_USDC, account, usdcAmount + 1000e6); // Extra for other operations

        // Record initial balances
        uint256 initialETHBalance = account.balance;
        uint256 initialUSDCBalance = IERC20(CHAIN_1_USDC).balanceOf(account);

        console2.log("Initial ETH balance:", initialETHBalance);
        console2.log("Initial USDC balance:", initialUSDCBalance);

        // Calculate appropriate price limit with 1% slippage tolerance (100 bps)
        uint160 priceLimit = _calculatePriceLimit(nativePoolKey, zeroForOne, 100); // 100 bps = 1%
        console2.log("Calculated price limit for quote and swap:", priceLimit);

        // Get realistic minimum using HOOK'S ON-CHAIN QUOTE with the same price limit
        SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: nativePoolKey,
                zeroForOne: zeroForOne,
                amountIn: usdcAmount,
                sqrtPriceLimitX96: priceLimit // Use same price limit for quote
             })
        );
        uint256 expectedMinETH = quote.amountOut * 995 / 1000; // Apply 0.5% additional slippage buffer on quote

        console2.log("Expected minimum ETH out (from pool quote):", expectedMinETH);
        console2.log("Quoted amountOut:", quote.amountOut);

        // Generate swap calldata for USDC to native ETH
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: nativePoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: priceLimit, // Use same price limit as quote
                originalAmountIn: usdcAmount,
                originalMinAmountOut: expectedMinETH,
                maxSlippageDeviationBps: 500, // Keep for amount ratio protection
                zeroForOne: zeroForOne,
                additionalData: ""
            }),
            false
        );

        // Execute the swap to native ETH
        _executeTokenToNativeSwap(swapCalldata);

        // Verify swap results
        uint256 finalETHBalance = account.balance;
        uint256 finalUSDCBalance = IERC20(CHAIN_1_USDC).balanceOf(account);

        console2.log("Final ETH balance:", finalETHBalance);
        console2.log("Final USDC balance:", finalUSDCBalance);

        // Verify USDC was spent and ETH received
        assertLe(finalUSDCBalance, initialUSDCBalance - usdcAmount + 1e6, "USDC should be spent");
        assertGt(finalETHBalance, initialETHBalance, "ETH balance should increase");

        uint256 ethReceived = finalETHBalance - initialETHBalance;
        assertGe(ethReceived, expectedMinETH, "Should receive at least minimum ETH");

        console2.log("USDC spent:", initialUSDCBalance - finalUSDCBalance);
        console2.log("ETH received:", ethReceived);
        console2.log("USDC to native ETH swap test passed");
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR CONDITION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test INSUFFICIENT_OUTPUT_AMOUNT error by manipulating pool state
    function test_RevertQuoteDeviationExceedsSafetyBound() public {
        address account = instanceOnEth.account;
        uint256 swapAmount = 1000e6; // 1000 USDC

        deal(CHAIN_1_USDC, account, swapAmount);

        // Set minimum output higher than what the pool can provide with restrictive price limit
        uint256 unrealisticMinOut = 1000e18; // 1000 WETH for 1000 USDC (impossible)
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 100, // Very restrictive limit
                originalAmountIn: swapAmount,
                originalMinAmountOut: unrealisticMinOut,
                maxSlippageDeviationBps: 0, // No slippage tolerance
                zeroForOne: true,
                additionalData: ""
            }),
            false
        );

        _executeTokenSwap(
            swapCalldata, abi.encodeWithSelector(SwapUniswapV4Hook.INSUFFICIENT_OUTPUT_AMOUNT.selector)
        );
    }

    /// @notice Test UNAUTHORIZED_CALLBACK error by calling unlockCallback directly
    function test_RevertUnauthorizedCallback() public {
        bytes memory callbackData = abi.encode(
            testPoolKey,
            1000e6, // amountIn
            950e6, // minAmountOut
            instanceOnEth.account, // dstReceiver
            uint160(TickMath.MIN_SQRT_PRICE + 1), // sqrtPriceLimitX96
            true, // zeroForOne
            "" // additionalData
        );

        vm.expectRevert(SwapUniswapV4Hook.UNAUTHORIZED_CALLBACK.selector);
        uniswapV4Hook.unlockCallback(callbackData);
    }

    /// @notice Test INVALID_HOOK_DATA error with insufficient data length
    function test_RevertInvalidHookData_ShortLength() public {
        // Create hook data that's too short (less than 218 bytes required)
        bytes memory shortData = new bytes(100); // Less than 218 bytes required

        vm.expectRevert(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector);
        uniswapV4Hook.decodeUsePrevHookAmount(shortData);
    }

    /// @notice Test INVALID_HOOK_DATA error with same currency0 and currency1
    function test_RevertInvalidHookData_SameCurrencies() public {
        address account = instanceOnEth.account;

        // Create pool key with same currencies (invalid)
        PoolKey memory invalidPoolKey = PoolKey({
            currency0: Currency.wrap(CHAIN_1_USDC),
            currency1: Currency.wrap(CHAIN_1_USDC), // Same currency - should revert
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        bytes memory invalidSwapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: invalidPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1,
                originalAmountIn: 1000e6,
                originalMinAmountOut: 950e6,
                maxSlippageDeviationBps: 500,
                zeroForOne: true,
                additionalData: ""
            }),
            false
        );

        deal(CHAIN_1_USDC, account, 1000e6);

        _executeTokenSwap(invalidSwapCalldata, abi.encode(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector));
    }

    /// @notice Test INVALID_HOOK_DATA error with zero fee
    function test_RevertInvalidHookData_ZeroFee() public {
        address account = instanceOnEth.account;

        // Create pool key with zero fee (invalid)
        PoolKey memory invalidPoolKey = PoolKey({
            currency0: Currency.wrap(CHAIN_1_USDC),
            currency1: Currency.wrap(CHAIN_1_WETH),
            fee: 0, // Zero fee - invalid
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        bytes memory invalidSwapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: invalidPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1,
                originalAmountIn: 1000e6,
                originalMinAmountOut: 950e18,
                maxSlippageDeviationBps: 500,
                zeroForOne: true,
                additionalData: ""
            }),
            false
        );

        deal(CHAIN_1_USDC, account, 1000e6);

        _executeTokenSwap(invalidSwapCalldata, abi.encode(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector));
    }

    /// @notice Test EXCESSIVE_SLIPPAGE_DEVIATION error with extreme ratio change
    function test_RevertExcessiveSlippageDeviation() public {
        address account = instanceOnEth.account;
        uint256 originalAmount = 1000e6; // Original amount in calldata
        uint256 actualAmount = 10_000e6; // 900% increase from previous hook

        // Fund with the larger actual amount
        deal(CHAIN_1_USDC, account, actualAmount);

        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1,
                originalAmountIn: originalAmount,
                originalMinAmountOut: 950e6,
                maxSlippageDeviationBps: 500, // 5% max - will be exceeded by 900% change
                zeroForOne: true,
                additionalData: ""
            }),
            true // usePrevHookAmount - will compare actual vs original
        );

        // Create a mock previous hook that returns the large amount
        MockPrevHook mockPrevHook = new MockPrevHook(actualAmount);

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(mockPrevHook);
        hookAddresses[1] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = ""; // Mock hook needs no data
        hookDataArray[1] = swapCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        instanceOnEth.expect4337Revert(
            abi.encodeWithSelector(
                SwapUniswapV4Hook.EXCESSIVE_SLIPPAGE_DEVIATION.selector,
                9000, // 90% deviation (900% increase)
                500 // 5% max allowed
            )
        );

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        executeOp(opData);
    }

    /// @notice Test invalid hook data with insufficient data length
    function test_RevertInvalidNativeTransferUsage() public {
        // Create hook data that's too short (less than 218 bytes required)
        bytes memory shortData = abi.encodePacked(
            CHAIN_1_USDC, // currency0 (20 bytes)
            CHAIN_1_WETH // currency1 (20 bytes) - total only 40 bytes, need 218
        );

        vm.expectRevert(SwapUniswapV4Hook.INVALID_HOOK_DATA.selector);
        uniswapV4Hook.decodeUsePrevHookAmount(shortData);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE AND BOUNDARY TESTS  
    //////////////////////////////////////////////////////////////*/

    /// @notice Test minimal swap amounts (boundary condition)
    function test_MinimalAmountSwap() public {
        address account = instanceOnEth.account;
        uint256 minSwapAmount = 1e6; // 1 USDC

        deal(CHAIN_1_USDC, account, minSwapAmount);

        // Get realistic quote for minimal amount
        SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: true,
                amountIn: minSwapAmount,
                sqrtPriceLimitX96: 0 // No limit
             })
        );
        uint256 expectedMinOut = quote.amountOut * 99 / 100; // 1% slippage

        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1,
                originalAmountIn: minSwapAmount,
                originalMinAmountOut: expectedMinOut,
                maxSlippageDeviationBps: 500,
                zeroForOne: true,
                additionalData: ""
            }),
            false
        );

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        _executeTokenSwap(swapCalldata, "");
        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertGt(finalWETH, initialWETH, "Should receive WETH from minimal swap");
    }

    /// @notice Debug test to understand dynamic min amount calculation
    function test_DebugDynamicMinAmount() public view {
        uint256 actualAmount = 1e18; // input amount (USDC, 18-decimals here in test env)
        uint256 originalAmount = (actualAmount * 1e18) / 105e16; // ~0.952e18, 5% smaller

        // Get quote for the larger amount
        SwapUniswapV4Hook.QuoteResult memory actualQuote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: true,
                amountIn: actualAmount,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            })
        );

        // Scale output proportionally to input amounts
        uint256 scaledOut = (actualQuote.amountOut * originalAmount) / actualAmount;

        // Apply slippage tolerance (1000 = 10%)
        uint256 originalMinAmountOut = (scaledOut * (10_000 - 1000)) / 10_000;

        console2.log("=== Debug Values ===");
        console2.log("actualAmount:", actualAmount);
        console2.log("originalAmount:", originalAmount);
        console2.log("actualQuote.amountOut:", actualQuote.amountOut);
        console2.log("scaledOut:", scaledOut);
        console2.log("originalMinAmountOut:", originalMinAmountOut);
        
        // Calculate what the hook will do
        uint256 amountRatio = (actualAmount * 1e18) / originalAmount;
        uint256 dynamicMinAmountOut = (originalMinAmountOut * amountRatio) / 1e18;
        
        console2.log("amountRatio:", amountRatio);
        console2.log("dynamicMinAmountOut (what hook calculates):", dynamicMinAmountOut);
        
        // Compare with actual quote
        console2.log("actualQuote vs dynamicMin ratio:", (dynamicMinAmountOut * 100) / actualQuote.amountOut);
    }

    function test_MaxDeviationBoundary() public {
        address account = instanceOnEth.account;

        // --- Use correct decimals ---
        // USDC has 6 decimals, so 1e6 = 1 USDC
        uint256 actualAmount = 1e6; // 1 USDC
        uint256 originalAmount = (actualAmount * 1e18) / 105e16; // ≈ 0.952 USDC (still in 6 decimals)

        // --- Get quote for the actualAmount (1 USDC) ---
        SwapUniswapV4Hook.QuoteResult memory actualQuote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: true,
                amountIn: actualAmount,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            })
        );

        // --- Scale the minOut to match originalAmount ---
        uint256 scaledMinOut = (actualQuote.amountOut * originalAmount) / actualAmount;

        // --- Apply maxSlippageDeviationBps (1000 = 10%) ---
        uint256 originalMinAmountOut = (scaledMinOut * (10_000 - 1000)) / 10_000;

        // 🔍 Debug
        console2.log("---- Test Setup Debug ----");
        console2.log("actualAmount (USDC 6d):      ", actualAmount);
        console2.log("originalAmount (USDC 6d):    ", originalAmount);
        console2.log("actualQuote.amountOut (WETH):", actualQuote.amountOut);
        console2.log("scaledMinOut (WETH):         ", scaledMinOut);
        console2.log("originalMinAmountOut (WETH): ", originalMinAmountOut);

        // --- Fund account with USDC ---
        deal(CHAIN_1_USDC, account, actualAmount);

        // --- Build calldata for the hook ---
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1,
                originalAmountIn: originalAmount,
                originalMinAmountOut: originalMinAmountOut,
                maxSlippageDeviationBps: 1000,
                zeroForOne: true,
                additionalData: ""
            }),
            true
        );

        // --- Hook chaining ---
        MockPrevHook mockPrevHook = new MockPrevHook(actualAmount);

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(mockPrevHook);
        hookAddresses[1] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = "";
        hookDataArray[1] = swapCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData =
            _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // --- Execute ---
        executeOp(opData); // ✅ should succeed at boundary
    }





    /// @notice Test decodeUsePrevHookAmount with various data lengths
    function test_DecodeUsePrevHookAmount_EdgeCases() public view {
        // Test minimum valid length (218 bytes)
        bytes memory minValidData = new bytes(218);
        minValidData[217] = 0x01; // Set usePrevHookAmount to true

        bool result = uniswapV4Hook.decodeUsePrevHookAmount(minValidData);
        assertTrue(result, "Should decode true from minimum valid data");

        // Test with additional data
        bytes memory dataWithExtra = new bytes(300);
        dataWithExtra[217] = 0x00; // Set usePrevHookAmount to false

        result = uniswapV4Hook.decodeUsePrevHookAmount(dataWithExtra);
        assertFalse(result, "Should decode false from data with extra bytes");
    }

    /// @notice Test inspect function with different token orderings
    function test_InspectTokenExtraction() public view {
        bytes memory testData = abi.encodePacked(
            CHAIN_1_USDC, // currency0
            CHAIN_1_WETH, // currency1
            uint32(3000), // fee
            uint32(int32(60)), // tickSpacing
            address(0), // hooks
            instanceOnEth.account, // dstReceiver
            uint256(TickMath.MIN_SQRT_PRICE + 1), // sqrtPriceLimitX96
            uint256(1000e6), // originalAmountIn
            uint256(950e6), // originalMinAmountOut
            uint256(500), // maxSlippageDeviationBps
            bytes1(0x01), // zeroForOne
            bytes1(0x00) // usePrevHookAmount
        );

        bytes memory result = uniswapV4Hook.inspect(testData);

        // Should return 40 bytes (2 addresses)
        assertEq(result.length, 40, "Should return 40 bytes");

        // Extract and verify addresses
        address extractedCurrency0;
        address extractedCurrency1;
        assembly {
            extractedCurrency0 := mload(add(result, 0x14))
            extractedCurrency1 := mload(add(result, 0x28))
        }

        assertEq(extractedCurrency0, CHAIN_1_USDC, "Should extract USDC as currency0");
        assertEq(extractedCurrency1, CHAIN_1_WETH, "Should extract WETH as currency1");
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTION COVERAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Test getQuote function with various scenarios
    function test_GetQuote_VariousScenarios() public view {
        // Test normal quote
        SwapUniswapV4Hook.QuoteResult memory quote1 = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: true,
                amountIn: 1000e6,
                sqrtPriceLimitX96: 0 // No limit
             })
        );
        assertGt(quote1.amountOut, 0, "Should return positive amount out");

        // Test opposite direction
        SwapUniswapV4Hook.QuoteResult memory quote2 = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: false,
                amountIn: 1e18,
                sqrtPriceLimitX96: 0
            })
        );
        assertGt(quote2.amountOut, 0, "Should return positive amount out for opposite direction");

        // Test with price limit
        SwapUniswapV4Hook.QuoteResult memory quote3 = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: true,
                amountIn: 1000e6,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            })
        );
        assertGt(quote3.amountOut, 0, "Should return positive amount out with price limit");
    }

    /// @notice Test dynamic ratio calculations
    function test_DynamicRatioCalculations() public {
        address account = instanceOnEth.account;

        // Test 50% decrease scenario
        uint256 originalAmount = 1000e6; // intended original input (USDC)
        uint256 actualAmount   = 500e6;  // only half actually provided

        deal(CHAIN_1_USDC, account, actualAmount);

        // ---- get a quote for the *actual* amount ----
        SwapUniswapV4Hook.QuoteResult memory q = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: true,
                amountIn: actualAmount,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            })
        );

        console2.log("quote.amountOut (actualAmount):", q.amountOut);

        // Scale originalMinAmountOut based on ratio of originalAmount to actualAmount
        uint256 originalMinAmountOut = (q.amountOut * originalAmount) / actualAmount;

        console2.log("originalAmount      :", originalAmount);
        console2.log("actualAmount        :", actualAmount);
        console2.log("scaledMinAmountOut  :", originalMinAmountOut);

        // ---- build calldata ----
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: account,
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1,
                originalAmountIn: originalAmount,
                originalMinAmountOut: originalMinAmountOut, // dynamically scaled
                maxSlippageDeviationBps: 6000,              // allow 60% deviation
                zeroForOne: true,
                additionalData: ""
            }),
            true
        );

        MockPrevHook mockPrevHook = new MockPrevHook(actualAmount); // simulate prev output

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(mockPrevHook);
        hookAddresses[1] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = "";
        hookDataArray[1] = swapCalldata;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        executeOp(opData);
        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertGt(finalWETH, initialWETH, "Should successfully execute with 50% ratio decrease");

        // Expected dynamic minOut ~ (originalMinOut * actualAmount / originalAmount)
    }

}

/// @notice Mock contract to simulate previous hook returning specific amounts
contract MockPrevHook is BaseHook {
    uint256 private _outAmount;

    constructor(uint256 outAmount) BaseHook(ISuperHook.HookType.NONACCOUNTING, 0) {
        _outAmount = outAmount;
    }

    // BaseHook implementation
    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
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
