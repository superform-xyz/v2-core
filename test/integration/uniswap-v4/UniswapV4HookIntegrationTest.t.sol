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

/// @title UniswapV4HookIntegrationTest
/// @author Superform Labs
/// @notice Comprehensive integration tests for Uniswap V4 hook using real mainnet forks when available
/// @dev Tests dynamic minAmount recalculation, hook chaining, and integration patterns
contract UniswapV4HookIntegrationTest is MinimalBaseIntegrationTest {
    using CurrencyLibrary for Currency;

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
                            CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_UniswapV4Hook_HookDataDecoding() external {
        console2.log("=== UniswapV4Hook Data Decoding Test ===");

        uint256 swapAmountIn = 1000e6; // 1000 USDC
        uint256 expectedMinOut = 300_000_000_000_000_000; // ~0.3 WETH minimum

        // Generate swap calldata using the parser
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: accountEth,
                sqrtPriceLimitX96: 0,
                originalAmountIn: swapAmountIn,
                originalMinAmountOut: expectedMinOut,
                maxSlippageDeviationBps: 500, // 5% max deviation
                zeroForOne: true, // USDC -> WETH
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
            token0 := mload(add(add(inspectResult, 0x20), 0))
            token1 := mload(add(add(inspectResult, 0x20), 20))
        }

        // Verify correct token addresses returned
        assertEq(token0, V4_USDC, "Token0 should be USDC");
        assertEq(token1, V4_WETH, "Token1 should be WETH");

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
        params.zeroForOne = V4_USDC < V4_WETH; // Derive zeroForOne based on addresses

        // Get realistic minimum using HOOK'S ON-CHAIN QUOTE (best V4 "oracle")
        SwapUniswapV4Hook.QuoteResult memory quote = uniswapV4Hook.getQuote(
            SwapUniswapV4Hook.QuoteParams({
                poolKey: testPoolKey,
                zeroForOne: params.zeroForOne,
                amountIn: params.sellAmount,
                sqrtPriceLimitX96: 0 // No limit
             })
        );
        params.expectedMinOut = quote.amountOut * 995 / 1000; // Apply 0.5% slippage buffer on quote

        // Get account address and setup
        params.account = instanceOnEth.account;
        deal(V4_USDC, params.account, params.sellAmount);

        // Get initial balances
        params.initialUSDCBalance = IERC20(V4_USDC).balanceOf(params.account);
        params.initialWETHBalance = IERC20(V4_WETH).balanceOf(params.account);

        console2.log("Initial USDC balance:", params.initialUSDCBalance);
        console2.log("Initial WETH balance:", params.initialWETHBalance);
        console2.log("Expected minimum WETH out (from pool quote):", params.expectedMinOut);
        console2.log("Quoted amountOut:", quote.amountOut);

        // Generate swap calldata using the parser
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: params.account,
                sqrtPriceLimitX96: 0,
                originalAmountIn: params.sellAmount,
                originalMinAmountOut: params.expectedMinOut,
                maxSlippageDeviationBps: 500, // Keep for amount ratio protection
                zeroForOne: params.zeroForOne,
                additionalData: ""
            }),
            false // Don't use prev hook amount
        );

        // Set up hook execution
        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = approveHook;
        hookAddresses[1] = address(uniswapV4Hook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = _createApproveHookData(V4_USDC, address(uniswapV4Hook), params.sellAmount, false);
        hookDataArray[1] = swapCalldata;

        // Execute via SuperExecutor
        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        // Execute the swap
        executeOp(opData);

        // Verify swap was successful
        params.finalUSDCBalance = IERC20(V4_USDC).balanceOf(params.account);
        params.finalWETHBalance = IERC20(V4_WETH).balanceOf(params.account);

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
