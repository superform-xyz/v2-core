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
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapUniswapV4Hook public uniswapV4Hook;
    UniswapV4Parser public parser;
    ISuperNativePaymaster public superNativePaymaster;

    IPoolManager public poolManager;

    // Test pool configuration
    PoolKey public testPoolKey;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        console2.log("Using real V4 deployment");
        poolManager = IPoolManager(MAINNET_V4_POOL_MANAGER);

        // Deploy UniswapV4 Hook
        uniswapV4Hook = new SwapUniswapV4Hook(address(poolManager));

        // Deploy parser
        parser = new UniswapV4Parser();

        // Deploy paymaster
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        // Setup test pool (USDC/WETH)
        testPoolKey = PoolKey({
            currency0: Currency.wrap(V4_USDC), // USDC
            currency1: Currency.wrap(V4_WETH), // WETH
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
                additionalData: ""
            }),
            false
        );

        // Test inspect function returns token addresses
        bytes memory inspectResult = uniswapV4Hook.inspect(swapCalldata);
        assertEq(inspectResult.length, 40, "Should return 40 bytes (2 addresses)");

        // Extract addresses
        address token0 = address(bytes20(inspectResult[0:20]));
        address token1 = address(bytes20(inspectResult[20:40]));

        // Verify correct token addresses returned
        assertEq(token0, V4_USDC, "Token0 should be USDC");
        assertEq(token1, V4_WETH, "Token1 should be WETH");

        console2.log("Inspect function test passed");
    }

    function test_UniswapV4Hook_HookChaining() external {
        console2.log("=== UniswapV4Hook Hook Chaining Test ===");

        // Test the usePrevHookAmount flag functionality
        bytes memory swapCalldata = parser.generateSingleHopSwapCalldata(
            UniswapV4Parser.SingleHopParams({
                poolKey: testPoolKey,
                dstReceiver: accountEth,
                sqrtPriceLimitX96: 0,
                originalAmountIn: 1000e6,
                originalMinAmountOut: 300_000_000_000_000_000,
                maxSlippageDeviationBps: 500,
                additionalData: ""
            }),
            true // Use prev hook amount
        );

        // Verify hook can decode the chaining flag
        bool usePrevHookAmount = uniswapV4Hook.decodeUsePrevHookAmount(swapCalldata);
        assertTrue(usePrevHookAmount, "Should use prev hook amount");

        console2.log("Hook chaining test passed");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createUserOp(
        address target,
        bytes memory callData,
        address token,
        uint256 amount
    )
        internal
        returns (UserOpData memory)
    {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = target;

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = callData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });

        return _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
    }

    function _executeUserOp(UserOpData memory userOp, address account) internal {
        // Execute with appropriate gas limit
        executeOpsThroughPaymaster(userOp, superNativePaymaster, 1e18);
    }
}
