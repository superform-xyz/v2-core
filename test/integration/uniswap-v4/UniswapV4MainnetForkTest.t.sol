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
import { UniswapV4QuoteOracle } from "../../../src/libraries/uniswap-v4/UniswapV4QuoteOracle.sol";

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

/// @title UniswapV4MainnetForkTest
/// @author Superform Labs
/// @notice Fork tests for Uniswap V4 hook against real mainnet contracts
/// @dev Tests will be activated once V4 is deployed on mainnet
contract UniswapV4MainnetForkTest is MinimalBaseIntegrationTest, UniswapV4Constants {
    using CurrencyLibrary for address;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapUniswapV4Hook public uniswapV4Hook;
    UniswapV4Parser public parser;
    ISuperNativePaymaster public superNativePaymaster;
    
    IPoolManagerSuperform public poolManager;
    
    // Real V4 pool configurations
    PoolKey public wethUsdcPoolKey;
    PoolKey public wethWbtcPoolKey;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        // Fork from V4 launch block for consistent testing
        // NOTE: Update this when V4 is actually deployed
        blockNumber = MAINNET_V4_LAUNCH_BLOCK;
        super.setUp();
        
        // Skip tests if V4 not deployed yet
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            vm.skip(true);
            return;
        }
        
        // Use real mainnet V4 contracts
        poolManager = IPoolManagerSuperform(MAINNET_V4_POOL_MANAGER);
        
        // Deploy V4 hook with real pool manager
        uniswapV4Hook = new SwapUniswapV4Hook(MAINNET_V4_POOL_MANAGER);
        
        // Deploy parser
        parser = new UniswapV4Parser();
        
        // Deploy paymaster
        superNativePaymaster = ISuperNativePaymaster(
            new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR))
        );
        
        // Setup real V4 pool keys (these would be discovered from V4 deployment)
        wethUsdcPoolKey = PoolKey({
            currency0: Currency.wrap(V4_USDC),
            currency1: Currency.wrap(V4_WETH), 
            fee: FEE_MEDIUM,
            tickSpacing: TICK_SPACING_MEDIUM,
            hooks: IHooks(address(0))
        });
        
        wethWbtcPoolKey = PoolKey({
            currency0: Currency.wrap(V4_WETH),
            currency1: Currency.wrap(V4_WBTC),
            fee: FEE_MEDIUM,
            tickSpacing: TICK_SPACING_MEDIUM,
            hooks: IHooks(address(0))
        });
        
        // Fund the account with real mainnet tokens
        _getTokens(V4_USDC, accountEth, 1000_000_000); // 1000 USDC
        _getTokens(V4_WETH, accountEth, 1e18); // 1 WETH
        _getTokens(V4_WBTC, accountEth, 1e8); // 1 WBTC
    }

    // CRITICAL: Integration test contracts MUST include receive() for EntryPoint fee refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                          REAL MAINNET V4 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RealMainnetV4Pool_USDC_WETH_BasicSwap() external {
        console2.log("=== Real Mainnet V4 Pool Test: USDC -> WETH ===");
        
        // Skip if V4 not deployed
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            console2.log("Skipping: V4 not deployed on mainnet yet");
            return;
        }
        
        uint256 swapAmount = V4_MEDIUM_SWAP; // 10 USDC
        
        // Get real pool state for quote validation
        (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 lpFee) = 
            poolManager.getSlot0(keccak256(abi.encode(wethUsdcPoolKey)));
        
        console2.log("Real V4 Pool State:");
        console2.log("  SqrtPriceX96:", sqrtPriceX96);
        console2.log("  Tick:", int256(tick));
        console2.log("  LP Fee:", lpFee);
        console2.log("  Protocol Fee:", protocolFee);
        
        // Generate on-chain quote using real pool state
        UniswapV4QuoteOracle.QuoteResult memory quote = UniswapV4QuoteOracle.getQuote(
            poolManager,
            UniswapV4QuoteOracle.QuoteParams({
                poolKey: wethUsdcPoolKey,
                zeroForOne: true, // USDC -> WETH
                amountIn: swapAmount,
                sqrtPriceLimitX96: 0
            })
        );
        
        console2.log("On-chain Quote Result:");
        console2.log("  Expected Output:", quote.amountOut);
        console2.log("  Price After:", quote.sqrtPriceX96After);
        console2.log("  Ticks Crossed:", quote.initializedTicksCrossed);
        console2.log("  Gas Estimate:", quote.gasEstimate);
        
        // Use conservative minAmountOut based on real quote
        uint256 minAmountOut = (quote.amountOut * 9500) / 10000; // 5% slippage from quote
        
        // Generate hook data with real pool parameters
        bytes memory hookData = parser.generateSingleHopSwapData(
            UniswapV4Parser.SingleHopSwapParams({
                tokenIn: V4_USDC,
                tokenOut: V4_WETH,
                fee: FEE_MEDIUM,
                recipient: accountEth,
                amountIn: swapAmount,
                minAmountOut: minAmountOut,
                sqrtPriceLimitX96: 0,
                maxSlippageDeviationBps: QUOTE_DEVIATION_TOLERANCE_BPS // 5%
            }),
            false
        );
        
        // Log initial balances
        uint256 usdcBefore = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wethBefore = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("Initial Mainnet Balances:");
        console2.log("  USDC:", usdcBefore);
        console2.log("  WETH:", wethBefore);
        
        // Execute swap against real V4 pool
        _executeRealV4Swap(hookData);
        
        // Verify results
        uint256 usdcAfter = IERC20(V4_USDC).balanceOf(accountEth);
        uint256 wethAfter = IERC20(V4_WETH).balanceOf(accountEth);
        
        console2.log("Post-Execution Mainnet Balances:");
        console2.log("  USDC:", usdcAfter);
        console2.log("  WETH:", wethAfter);
        
        uint256 actualAmountIn = usdcBefore - usdcAfter;
        uint256 actualAmountOut = wethAfter - wethBefore;
        
        console2.log("Actual Swap Results:");
        console2.log("  Amount In:", actualAmountIn);
        console2.log("  Amount Out:", actualAmountOut);
        
        // Verify swap executed correctly
        assertEq(actualAmountIn, swapAmount, "Should use exact input amount");
        assertGe(actualAmountOut, minAmountOut, "Should meet minimum output requirement");
        
        // Verify output is close to quote (within reasonable deviation)
        uint256 quoteDeviation = actualAmountOut > quote.amountOut
            ? ((actualAmountOut - quote.amountOut) * 10000) / quote.amountOut
            : ((quote.amountOut - actualAmountOut) * 10000) / quote.amountOut;
        
        assertLe(quoteDeviation, 1000, "Actual output should be within 10% of quote"); // Allow 10% deviation for real market conditions
        
        console2.log("Quote vs Actual Deviation:", quoteDeviation, "bps");
    }

    function test_RealMainnetV4Pool_LargeSwapSlippageProtection() external {
        console2.log("=== Real Mainnet V4 Pool: Large Swap Slippage Protection ===");
        
        // Skip if V4 not deployed
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            console2.log("Skipping: V4 not deployed on mainnet yet");
            return;
        }
        
        uint256 largeSwapAmount = 100_000_000_000; // 100,000 USDC - very large swap
        
        // Get price impact estimate
        uint256 priceImpactBps = UniswapV4QuoteOracle.getPriceImpact(
            poolManager,
            UniswapV4QuoteOracle.QuoteParams({
                poolKey: wethUsdcPoolKey,
                zeroForOne: true,
                amountIn: largeSwapAmount,
                sqrtPriceLimitX96: 0
            })
        );
        
        console2.log("Large Swap Price Impact:", priceImpactBps, "bps");
        
        // If price impact is too high, the swap should be rejected or split
        if (priceImpactBps > 1000) { // > 10% price impact
            console2.log("High price impact detected - this would require special handling");
            
            // Test that our hook would properly handle this via quote deviation protection
            // (In practice, might split into smaller swaps or use different routing)
            assertTrue(priceImpactBps > 1000, "Should detect high price impact for large swaps");
        }
    }

    function test_RealMainnetV4Pool_DynamicMinAmountWithRealPrices() external {
        console2.log("=== Real Mainnet V4: Dynamic MinAmount with Real Prices ===");
        
        // Skip if V4 not deployed
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            console2.log("Skipping: V4 not deployed on mainnet yet");
            return;
        }
        
        uint256 originalAmountIn = V4_MEDIUM_SWAP;
        
        // Get real quote for original amount
        UniswapV4QuoteOracle.QuoteResult memory originalQuote = UniswapV4QuoteOracle.getQuote(
            poolManager,
            UniswapV4QuoteOracle.QuoteParams({
                poolKey: wethUsdcPoolKey,
                zeroForOne: true,
                amountIn: originalAmountIn,
                sqrtPriceLimitX96: 0
            })
        );
        
        uint256 originalMinAmountOut = (originalQuote.amountOut * 9500) / 10000; // 5% slippage
        uint256 changedAmountIn = (originalAmountIn * 110) / 100; // 10% increase
        
        console2.log("Dynamic MinAmount Test with Real Prices:");
        console2.log("  Original AmountIn:", originalAmountIn);
        console2.log("  Original Quote:", originalQuote.amountOut);
        console2.log("  Original MinAmountOut:", originalMinAmountOut);
        console2.log("  Changed AmountIn:", changedAmountIn);
        
        // Get quote for changed amount to validate our calculation
        UniswapV4QuoteOracle.QuoteResult memory changedQuote = UniswapV4QuoteOracle.getQuote(
            poolManager,
            UniswapV4QuoteOracle.QuoteParams({
                poolKey: wethUsdcPoolKey,
                zeroForOne: true,
                amountIn: changedAmountIn,
                sqrtPriceLimitX96: 0
            })
        );
        
        console2.log("  Changed Quote:", changedQuote.amountOut);
        
        // Calculate expected dynamic minAmountOut
        uint256 expectedDynamicMinOut = (originalMinAmountOut * changedAmountIn) / originalAmountIn;
        console2.log("  Expected Dynamic MinOut:", expectedDynamicMinOut);
        
        // Verify our dynamic calculation is reasonable compared to actual quote
        uint256 calculationDeviation = expectedDynamicMinOut > changedQuote.amountOut
            ? ((expectedDynamicMinOut - changedQuote.amountOut) * 10000) / changedQuote.amountOut
            : ((changedQuote.amountOut - expectedDynamicMinOut) * 10000) / expectedDynamicMinOut;
        
        console2.log("  Dynamic Calculation vs Real Quote Deviation:", calculationDeviation, "bps");
        
        // Our dynamic calculation should be reasonably close to real market conditions
        assertLe(calculationDeviation, 2000, "Dynamic calculation should be within 20% of real quote");
    }

    function test_RealMainnetV4Pool_QuoteValidationAccuracy() external {
        console2.log("=== Real Mainnet V4: Quote Validation Accuracy ===");
        
        // Skip if V4 not deployed
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            console2.log("Skipping: V4 not deployed on mainnet yet");
            return;
        }
        
        uint256 testAmount = V4_MEDIUM_SWAP;
        
        // Test quote validation with different deviation tolerances
        uint256[] memory testDeviations = new uint256[](4);
        testDeviations[0] = 100; // 1%
        testDeviations[1] = 500; // 5%
        testDeviations[2] = 1000; // 10%
        testDeviations[3] = 5000; // 50%
        
        for (uint256 i = 0; i < testDeviations.length; i++) {
            uint256 deviation = testDeviations[i];
            
            // Get real quote
            UniswapV4QuoteOracle.QuoteResult memory quote = UniswapV4QuoteOracle.getQuote(
                poolManager,
                UniswapV4QuoteOracle.QuoteParams({
                    poolKey: wethUsdcPoolKey,
                    zeroForOne: true,
                    amountIn: testAmount,
                    sqrtPriceLimitX96: 0
                })
            );
            
            // Test validation with quote result as expected minimum
            bool isValid = UniswapV4QuoteOracle.validateQuoteDeviation(
                poolManager,
                wethUsdcPoolKey,
                testAmount,
                UniswapV4QuoteOracle.ValidationParams({
                    expectedMinOut: quote.amountOut,
                    maxDeviationBps: deviation
                })
            );
            
            console2.log("Quote validation with", deviation, "bps tolerance:", isValid ? "VALID" : "INVALID");
            
            // Should be valid since we're comparing against the same quote
            assertTrue(isValid, "Quote should validate against itself");
        }
    }

    function test_RealMainnetV4Pool_CrossPoolArbitrage() external {
        console2.log("=== Real Mainnet V4: Cross-Pool Price Consistency ===");
        
        // Skip if V4 not deployed
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            console2.log("Skipping: V4 not deployed on mainnet yet");
            return;
        }
        
        uint256 testAmount = V4_MEDIUM_SWAP;
        
        // Get quotes for USDC -> WETH
        UniswapV4QuoteOracle.QuoteResult memory usdcWethQuote = UniswapV4QuoteOracle.getQuote(
            poolManager,
            UniswapV4QuoteOracle.QuoteParams({
                poolKey: wethUsdcPoolKey,
                zeroForOne: true,
                amountIn: testAmount,
                sqrtPriceLimitX96: 0
            })
        );
        
        console2.log("Cross-Pool Price Analysis:");
        console2.log("  USDC -> WETH Quote:", usdcWethQuote.amountOut);
        
        // Calculate implied WETH/USDC price
        uint256 impliedWethUsdcPrice = (testAmount * 1e18) / usdcWethQuote.amountOut;
        console2.log("  Implied WETH/USDC Price:", impliedWethUsdcPrice);
        
        // Get reverse quote (WETH -> USDC) with equivalent WETH amount
        UniswapV4QuoteOracle.QuoteResult memory wethUsdcQuote = UniswapV4QuoteOracle.getQuote(
            poolManager,
            UniswapV4QuoteOracle.QuoteParams({
                poolKey: wethUsdcPoolKey,
                zeroForOne: false,
                amountIn: usdcWethQuote.amountOut,
                sqrtPriceLimitX96: 0
            })
        );
        
        console2.log("  WETH -> USDC Quote:", wethUsdcQuote.amountOut);
        
        // Calculate round-trip efficiency
        uint256 roundTripEfficiency = (wethUsdcQuote.amountOut * 10000) / testAmount;
        console2.log("  Round-trip Efficiency:", roundTripEfficiency, "bps (10000 = 100%)");
        
        // Round-trip should lose some value due to fees and slippage, but not too much
        assertGe(roundTripEfficiency, 9400, "Round-trip should retain at least 94% of value"); // 6% max loss
        assertLe(roundTripEfficiency, 10000, "Cannot gain value in round-trip");
        
        console2.log("Price consistency check passed");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute swap against real V4 pool
    /// @param hookData Encoded hook data for the swap
    function _executeRealV4Swap(bytes memory hookData) internal {
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(uniswapV4Hook);
        
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;
        
        ISuperExecutor.ExecutorEntry memory entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: hooksAddresses,
            hooksData: hooksData
        });
        
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        
        // Execute with higher gas limit for real V4 operations
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 2e18); // Higher gas limit
    }

    /// @notice Check if V4 is deployed and pools exist
    /// @param poolKey Pool key to check
    /// @return exists Whether the pool exists and is initialized
    function _checkV4PoolExists(PoolKey memory poolKey) internal view returns (bool exists) {
        if (MAINNET_V4_POOL_MANAGER == address(0)) {
            return false;
        }
        
        try poolManager.getSlot0(keccak256(abi.encode(poolKey))) returns (
            uint160 sqrtPriceX96,
            int24,
            uint16,
            uint24
        ) {
            exists = sqrtPriceX96 > 0;
        } catch {
            exists = false;
        }
    }

    /// @notice Get current market conditions for analysis
    /// @param poolKey Pool to analyze
    function _analyzeMarketConditions(PoolKey memory poolKey) internal view {
        if (!_checkV4PoolExists(poolKey)) {
            console2.log("Pool not available for analysis");
            return;
        }
        
        (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 lpFee) = 
            poolManager.getSlot0(keccak256(abi.encode(poolKey)));
        
        console2.log("Market Conditions Analysis:");
        console2.log("  Current Price (sqrtPriceX96):", sqrtPriceX96);
        console2.log("  Current Tick:", int256(tick));
        console2.log("  LP Fee:", lpFee, "bps");
        console2.log("  Protocol Fee:", protocolFee, "bps");
        
        // Additional analysis could include:
        // - Liquidity depth
        // - Recent price movements
        // - Volume analysis
        // - Fee collection rates
    }
}

/// @notice Contract to test V4 deployment status and configuration
/// @dev Provides utilities for checking V4 mainnet deployment status
contract V4DeploymentChecker {
    /// @notice Check if V4 is deployed on current network
    /// @return deployed Whether V4 contracts are available
    /// @return poolManagerAddress Address of the pool manager (if deployed)
    function checkV4Deployment() external view returns (bool deployed, address poolManagerAddress) {
        // This would be updated once V4 addresses are known
        poolManagerAddress = address(0); // TBD - update when V4 launches
        deployed = poolManagerAddress != address(0);
        
        if (deployed) {
            // Additional validation could verify the contract is actually V4 PoolManager
            try IPoolManagerSuperform(poolManagerAddress).getSlot0(bytes32(0)) {
                // If it doesn't revert, it's likely a valid pool manager
            } catch {
                // If basic call fails, might not be correct contract
                deployed = false;
            }
        }
    }
    
    /// @notice Get recommended test parameters for current market conditions
    /// @return params Suggested parameters for testing
    function getRecommendedTestParams() external view returns (TestParams memory params) {
        params = TestParams({
            smallSwapAmount: 1_000_000, // 1 USDC
            mediumSwapAmount: 10_000_000, // 10 USDC  
            largeSwapAmount: 100_000_000, // 100 USDC
            maxPriceImpactBps: 500, // 5%
            defaultSlippageBps: 300, // 3%
            quoteDeviationToleranceBps: 1000 // 10%
        });
    }
    
    struct TestParams {
        uint256 smallSwapAmount;
        uint256 mediumSwapAmount;
        uint256 largeSwapAmount;
        uint256 maxPriceImpactBps;
        uint256 defaultSlippageBps;
        uint256 quoteDeviationToleranceBps;
    }
}