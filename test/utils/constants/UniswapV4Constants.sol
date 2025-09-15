// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Constants } from "../Constants.sol";

/// @title UniswapV4Constants
/// @author Superform Labs
/// @notice Constants for Uniswap V4 testing infrastructure
/// @dev Provides addresses, configurations, and test parameters for V4 integration
abstract contract UniswapV4Constants is Constants {
    /*//////////////////////////////////////////////////////////////
                        UNISWAP V4 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Mainnet UniswapV4 addresses (TBD - update when V4 launches)
    /// @dev These will be updated once V4 is deployed on mainnet
    address public constant MAINNET_V4_POOL_MANAGER = address(0); // TBD
    address public constant MAINNET_V4_POSITION_MANAGER = address(0); // TBD
    address public constant MAINNET_V4_HOOK_REGISTRY = address(0); // TBD

    /// @notice Block number for V4 launch (estimated - update when known)
    uint256 public constant MAINNET_V4_LAUNCH_BLOCK = 22_000_000; // Estimated

    /*//////////////////////////////////////////////////////////////
                            FEE TIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Common V4 fee tiers for testing
    uint24 public constant FEE_LOW = 500;    // 0.05%
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%  
    uint24 public constant FEE_HIGH = 10000;  // 1%

    /// @notice Corresponding tick spacings for fee tiers
    int24 public constant TICK_SPACING_LOW = 10;      // For 0.05% fee
    int24 public constant TICK_SPACING_MEDIUM = 60;   // For 0.3% fee
    int24 public constant TICK_SPACING_HIGH = 200;    // For 1% fee

    /*//////////////////////////////////////////////////////////////
                            TEST TOKENS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test tokens for V4 pools (reuse existing constants)
    address public constant V4_WETH = CHAIN_1_WETH;
    address public constant V4_USDC = CHAIN_1_USDC;
    address public constant V4_WBTC = CHAIN_1_WBTC;

    /*//////////////////////////////////////////////////////////////
                            HOOK KEYS
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook identification constants
    string public constant SWAP_UNISWAP_V4_HOOK_KEY = "SwapUniswapV4Hook";
    string public constant SWAP_UNISWAP_V4_MULTI_HOP_HOOK_KEY = "SwapUniswapV4MultiHopHook";

    /*//////////////////////////////////////////////////////////////
                            TEST PARAMETERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standard test amounts for V4 swaps
    uint256 public constant V4_SMALL_SWAP = 1_000_000; // 1 USDC or 0.001 WETH
    uint256 public constant V4_MEDIUM_SWAP = 10_000_000; // 10 USDC or 0.01 WETH
    uint256 public constant V4_LARGE_SWAP = 100_000_000; // 100 USDC or 0.1 WETH

    /// @notice Default slippage parameters for testing
    uint256 public constant DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS = 100; // 1%
    uint256 public constant STRICT_MAX_SLIPPAGE_DEVIATION_BPS = 50;   // 0.5%
    uint256 public constant LOOSE_MAX_SLIPPAGE_DEVIATION_BPS = 500;   // 5%

    /// @notice Quote validation parameters
    uint256 public constant QUOTE_DEVIATION_TOLERANCE_BPS = 500; // 5% max deviation from on-chain quote

    /*//////////////////////////////////////////////////////////////
                            POOL IDS
    //////////////////////////////////////////////////////////////*/

    /// @notice Common pool identifiers for testing (will be calculated from pool keys)
    /// @dev These are placeholders - actual pool IDs will be calculated from PoolKey structs
    bytes32 public constant WETH_USDC_POOL_ID_MEDIUM = bytes32(0); // Will be keccak256(abi.encode(poolKey))
    bytes32 public constant WETH_WBTC_POOL_ID_MEDIUM = bytes32(0);
    bytes32 public constant USDC_WBTC_POOL_ID_MEDIUM = bytes32(0);

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get tick spacing for a given fee tier
    /// @param fee The fee tier
    /// @return tickSpacing The corresponding tick spacing
    function getTickSpacing(uint24 fee) internal pure returns (int24 tickSpacing) {
        if (fee == FEE_LOW) return TICK_SPACING_LOW;
        if (fee == FEE_MEDIUM) return TICK_SPACING_MEDIUM;
        if (fee == FEE_HIGH) return TICK_SPACING_HIGH;
        return TICK_SPACING_MEDIUM; // Default to medium
    }

    /// @notice Check if two tokens need to be swapped for proper pool ordering
    /// @dev V4 pools require token0 < token1
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return token0 The lower address token
    /// @return token1 The higher address token
    /// @return swapped Whether the tokens were swapped from input order
    function sortTokens(
        address tokenA,
        address tokenB
    ) 
        internal 
        pure 
        returns (address token0, address token1, bool swapped) 
    {
        require(tokenA != tokenB, "Identical tokens");
        
        if (tokenA < tokenB) {
            (token0, token1, swapped) = (tokenA, tokenB, false);
        } else {
            (token0, token1, swapped) = (tokenB, tokenA, true);
        }
    }

    /// @notice Calculate expected minimum output for a given input and slippage
    /// @param amountIn Input amount
    /// @param expectedPrice Expected price ratio (output per input)
    /// @param slippageBps Slippage tolerance in basis points
    /// @return minAmountOut Minimum expected output
    function calculateMinAmountOut(
        uint256 amountIn,
        uint256 expectedPrice,
        uint256 slippageBps
    )
        internal
        pure
        returns (uint256 minAmountOut)
    {
        uint256 expectedOut = (amountIn * expectedPrice) / 1e18;
        minAmountOut = (expectedOut * (10000 - slippageBps)) / 10000;
    }

    /*//////////////////////////////////////////////////////////////
                            MOCK DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Mock price ratios for testing (in 1e18 precision)
    /// @dev These are approximate ratios - real tests should use on-chain prices
    uint256 public constant MOCK_USDC_PER_WETH = 3000e18; // 1 WETH = 3000 USDC
    uint256 public constant MOCK_USDC_PER_WBTC = 60000e18; // 1 WBTC = 60000 USDC  
    uint256 public constant MOCK_WETH_PER_WBTC = 20e18; // 1 WBTC = 20 WETH

    /// @notice Common multi-hop paths for testing
    /// @dev These represent typical multi-hop routes through V4 pools

    /// @notice Path: USDC -> WETH -> WBTC
    /// @return Path array for USDC to WBTC via WETH
    function getUSDCtoWBTCPath() internal pure returns (address[] memory) {
        address[] memory path = new address[](3);
        path[0] = V4_USDC;
        path[1] = V4_WETH;
        path[2] = V4_WBTC;
        return path;
    }

    /// @notice Fees for USDC -> WETH -> WBTC path
    /// @return Fee array for the multi-hop path
    function getUSDCtoWBTCFees() internal pure returns (uint24[] memory) {
        uint24[] memory fees = new uint24[](2);
        fees[0] = FEE_MEDIUM; // USDC -> WETH
        fees[1] = FEE_MEDIUM; // WETH -> WBTC
        return fees;
    }

    /*//////////////////////////////////////////////////////////////
                        TESTING SCENARIOS
    //////////////////////////////////////////////////////////////*/

    /// @notice Different test scenarios with varying parameters
    enum TestScenario {
        BASIC_SWAP,           // Simple A->B swap
        RATIO_PROTECTION,     // Test dynamic minAmount recalculation
        HOOK_CHAINING,        // Test with previous hook output
        MULTI_HOP,            // Multi-hop swap through multiple pools
        HIGH_SLIPPAGE,        // Test with high price impact
        EDGE_CASE_AMOUNTS     // Test with very small/large amounts
    }

    /// @notice Get test parameters for a specific scenario
    /// @param scenario The test scenario
    /// @return amountIn Input amount for the test
    /// @return minAmountOut Minimum output for the test
    /// @return maxSlippageDeviationBps Maximum slippage deviation
    function getTestParams(TestScenario scenario) 
        internal 
        pure 
        returns (
            uint256 amountIn,
            uint256 minAmountOut,
            uint256 maxSlippageDeviationBps
        ) 
    {
        if (scenario == TestScenario.BASIC_SWAP) {
            amountIn = V4_MEDIUM_SWAP;
            minAmountOut = calculateMinAmountOut(amountIn, MOCK_USDC_PER_WETH, 300); // 3% slippage
            maxSlippageDeviationBps = DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS;
        } else if (scenario == TestScenario.RATIO_PROTECTION) {
            amountIn = V4_SMALL_SWAP;
            minAmountOut = calculateMinAmountOut(amountIn, MOCK_USDC_PER_WETH, 100); // 1% slippage
            maxSlippageDeviationBps = STRICT_MAX_SLIPPAGE_DEVIATION_BPS;
        } else if (scenario == TestScenario.HOOK_CHAINING) {
            amountIn = 0; // Will be overridden by previous hook
            minAmountOut = V4_SMALL_SWAP / 2; // Conservative estimate
            maxSlippageDeviationBps = DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS;
        } else if (scenario == TestScenario.MULTI_HOP) {
            amountIn = V4_LARGE_SWAP;
            minAmountOut = calculateMinAmountOut(amountIn, MOCK_USDC_PER_WBTC, 500); // 5% slippage for multi-hop
            maxSlippageDeviationBps = LOOSE_MAX_SLIPPAGE_DEVIATION_BPS;
        } else {
            // Default to basic swap
            amountIn = V4_MEDIUM_SWAP;
            minAmountOut = calculateMinAmountOut(amountIn, MOCK_USDC_PER_WETH, 300);
            maxSlippageDeviationBps = DEFAULT_MAX_SLIPPAGE_DEVIATION_BPS;
        }
    }
}