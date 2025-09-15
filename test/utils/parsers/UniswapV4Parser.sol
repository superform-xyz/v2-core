// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { BaseAPIParser } from "./BaseAPIParser.sol";

// Uniswap V4 imports  
import { 
    PoolKey, 
    Currency, 
    CurrencyLibrary,
    IHooks
} from "../../../src/interfaces/external/uniswap-v4/IPoolManagerSuperform.sol";

// Test imports
import { UniswapV4Constants } from "../constants/UniswapV4Constants.sol";

/// @title UniswapV4Parser
/// @author Superform Labs
/// @notice Parser for generating Uniswap V4 hook calldata without external API dependencies
/// @dev Provides on-chain calldata generation for V4 swaps following Superform patterns
contract UniswapV4Parser is BaseAPIParser, UniswapV4Constants {
    using CurrencyLibrary for address;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when token path is invalid for multi-hop
    error InvalidTokenPath();

    /// @notice Thrown when fees array doesn't match token path
    error InvalidFeesArray();

    /// @notice Thrown when tokens are identical
    error IdenticalTokens();

    /*//////////////////////////////////////////////////////////////
                                 STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parameters for single-hop V4 swap
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param fee Fee tier for the pool
    /// @param recipient Recipient of output tokens
    /// @param amountIn Input amount
    /// @param minAmountOut Minimum output amount
    /// @param sqrtPriceLimitX96 Price limit (0 for no limit)
    /// @param maxSlippageDeviationBps Maximum allowed ratio change in basis points
    struct SingleHopSwapParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 minAmountOut;
        uint160 sqrtPriceLimitX96;
        uint256 maxSlippageDeviationBps;
    }

    /// @notice Parameters for multi-hop V4 swap
    /// @param path Encoded path for multi-hop
    /// @param recipient Recipient of final output tokens
    /// @param amountIn Input amount
    /// @param minAmountOut Final minimum output amount
    /// @param maxSlippageDeviationBps Maximum allowed ratio change in basis points
    struct MultiHopSwapParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 minAmountOut;
        uint256 maxSlippageDeviationBps;
    }

    /*//////////////////////////////////////////////////////////////
                        SINGLE-HOP GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generate hook data for single-hop V4 swap
    /// @dev Creates properly encoded data matching SwapUniswapV4Hook expectations
    /// @param params The swap parameters
    /// @param usePrevHookAmount Whether to use previous hook's output
    /// @return hookData Encoded hook data ready for execution
    function generateSingleHopSwapData(
        SingleHopSwapParams memory params,
        bool usePrevHookAmount
    ) 
        external 
        pure 
        returns (bytes memory hookData) 
    {
        // Validate inputs
        if (params.tokenIn == params.tokenOut) {
            revert IdenticalTokens();
        }

        // Sort tokens for proper pool ordering (V4 requires token0 < token1)
        (address token0, address token1, bool swapped) = sortTokens(params.tokenIn, params.tokenOut);

        // Create PoolKey with sorted tokens
        PoolKey memory poolKey = PoolKey({
            currency0: token0.wrap(),
            currency1: token1.wrap(),
            fee: params.fee,
            tickSpacing: getTickSpacing(params.fee),
            hooks: IHooks(address(0)) // No custom hooks for basic swap
        });

        // Encode according to enhanced data structure (297+ bytes)
        hookData = abi.encodePacked(
            abi.encode(poolKey),                        // 160 bytes: PoolKey
            params.recipient,                           // 20 bytes: dstReceiver  
            params.sqrtPriceLimitX96,                  // 20 bytes: sqrtPriceLimitX96
            params.amountIn,                           // 32 bytes: originalAmountIn
            params.minAmountOut,                       // 32 bytes: originalMinAmountOut
            params.maxSlippageDeviationBps,            // 32 bytes: maxSlippageDeviationBps
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // 1 byte: usePrevHookAmount flag
            // Additional data would go here if needed (bytes hookData)
        );
    }

    /// @notice Generate hook data with recommended slippage for token pair
    /// @dev Automatically determines appropriate slippage based on token pair volatility
    /// @param tokenIn Input token
    /// @param tokenOut Output token  
    /// @param fee Fee tier
    /// @param recipient Recipient address
    /// @param amountIn Input amount
    /// @param usePrevHookAmount Whether to use previous hook output
    /// @return hookData Encoded hook data with recommended parameters
    function generateRecommendedSwapData(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 amountIn,
        bool usePrevHookAmount
    )
        external
        pure
        returns (bytes memory hookData)
    {
        // Determine recommended slippage based on token pair
        uint256 recommendedSlippageBps = _getRecommendedSlippage(tokenIn, tokenOut);
        uint256 maxDeviationBps = recommendedSlippageBps / 2; // Half of slippage for ratio protection

        // Calculate minAmountOut based on mock prices (in real usage, would query oracle)
        uint256 minAmountOut = _calculateMockMinAmountOut(tokenIn, tokenOut, amountIn, recommendedSlippageBps);

        SingleHopSwapParams memory params = SingleHopSwapParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: recipient,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            sqrtPriceLimitX96: 0, // No price limit
            maxSlippageDeviationBps: maxDeviationBps
        });

        return generateSingleHopSwapData(params, usePrevHookAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-HOP GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generate hook data for multi-hop V4 swap
    /// @dev Creates data for swaps through multiple V4 pools
    /// @param params Multi-hop swap parameters
    /// @param usePrevHookAmount Whether to use previous hook output
    /// @return hookData Encoded multi-hop hook data
    function generateMultiHopSwapData(
        MultiHopSwapParams memory params,
        bool usePrevHookAmount
    ) 
        external 
        pure 
        returns (bytes memory hookData) 
    {
        // Validate path
        if (params.path.length == 0) {
            revert InvalidTokenPath();
        }

        // Encode multi-hop data structure (different from single-hop)
        // For multi-hop, we encode the path directly instead of PoolKey
        hookData = abi.encodePacked(
            params.path,                               // Variable: encoded multi-hop path
            params.recipient,                          // 20 bytes: recipient
            params.amountIn,                           // 32 bytes: originalAmountIn  
            params.minAmountOut,                       // 32 bytes: originalMinAmountOut
            params.maxSlippageDeviationBps,            // 32 bytes: maxSlippageDeviationBps
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // 1 byte: usePrevHookAmount flag
        );
    }

    /// @notice Generate common multi-hop swap data (USDC -> WETH -> WBTC)
    /// @dev Convenience function for the most common multi-hop route
    /// @param recipient Recipient address
    /// @param amountIn Input amount in USDC
    /// @param usePrevHookAmount Whether to use previous hook output
    /// @return hookData Encoded multi-hop data for USDC -> WBTC via WETH
    function generateUSDCtoWBTCSwapData(
        address recipient,
        uint256 amountIn,
        bool usePrevHookAmount
    )
        external
        pure
        returns (bytes memory hookData)
    {
        // Create path for USDC -> WETH -> WBTC
        bytes memory path = encodePath(getUSDCtoWBTCPath(), getUSDCtoWBTCFees());
        
        // Calculate expected minimum output (conservative estimate)
        uint256 minAmountOut = calculateMinAmountOut(amountIn, MOCK_USDC_PER_WBTC, 500); // 5% slippage
        
        MultiHopSwapParams memory params = MultiHopSwapParams({
            path: path,
            recipient: recipient,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            maxSlippageDeviationBps: LOOSE_MAX_SLIPPAGE_DEVIATION_BPS // 5% for multi-hop
        });

        return generateMultiHopSwapData(params, usePrevHookAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            PATH ENCODING
    //////////////////////////////////////////////////////////////*/

    /// @notice Encode multi-hop path following V4 conventions
    /// @dev Path format: token0 || fee0 || token1 || fee1 || token2
    /// @param tokens Array of token addresses in swap order
    /// @param fees Array of fee tiers for each pool
    /// @return path Encoded path bytes
    function encodePath(
        address[] memory tokens,
        uint24[] memory fees
    ) 
        public 
        pure 
        returns (bytes memory path) 
    {
        if (tokens.length != fees.length + 1) {
            revert InvalidFeesArray();
        }
        if (tokens.length < 2) {
            revert InvalidTokenPath();
        }
        
        path = abi.encodePacked(tokens[0]);
        for (uint256 i = 0; i < fees.length; i++) {
            path = abi.encodePacked(path, fees[i], tokens[i + 1]);
        }
    }

    /// @notice Decode multi-hop path into tokens and fees
    /// @dev Reverses the encodePath operation
    /// @param path Encoded path bytes
    /// @return tokens Array of token addresses
    /// @return fees Array of fee tiers
    function decodePath(bytes memory path) 
        external 
        pure 
        returns (address[] memory tokens, uint24[] memory fees) 
    {
        uint256 pathLength = path.length;
        
        // Each hop adds 23 bytes (20 for address + 3 for fee)
        // First token is 20 bytes, so: 20 + n * 23 where n is number of hops
        require((pathLength - 20) % 23 == 0, "Invalid path length");
        
        uint256 numHops = (pathLength - 20) / 23;
        tokens = new address[](numHops + 1);
        fees = new uint24[](numHops);
        
        // Extract first token
        tokens[0] = address(bytes20(path[0:20]));
        
        // Extract subsequent tokens and fees
        for (uint256 i = 0; i < numHops; i++) {
            uint256 offset = 20 + i * 23;
            fees[i] = uint24(bytes3(path[offset:offset + 3]));
            tokens[i + 1] = address(bytes20(path[offset + 3:offset + 23]));
        }
    }

    /*//////////////////////////////////////////////////////////////
                            TEST HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create hook data for basic test scenario
    /// @dev Convenient function for standard testing with reasonable defaults
    /// @param scenario Test scenario to generate data for
    /// @param recipient Recipient address
    /// @param usePrevHookAmount Whether to use previous hook output
    /// @return hookData Generated hook data for the scenario
    function generateTestScenarioData(
        TestScenario scenario,
        address recipient,
        bool usePrevHookAmount
    )
        external
        pure
        returns (bytes memory hookData)
    {
        (uint256 amountIn, uint256 minAmountOut, uint256 maxSlippageDeviationBps) = getTestParams(scenario);
        
        SingleHopSwapParams memory params = SingleHopSwapParams({
            tokenIn: V4_USDC,
            tokenOut: V4_WETH,
            fee: FEE_MEDIUM,
            recipient: recipient,
            amountIn: amountIn,
            minAmountOut: minAmountOut,
            sqrtPriceLimitX96: 0,
            maxSlippageDeviationBps: maxSlippageDeviationBps
        });

        return generateSingleHopSwapData(params, usePrevHookAmount);
    }

    /// @notice Validate hook data structure
    /// @dev Ensures the generated hook data has the correct format
    /// @param hookData The hook data to validate
    /// @return isValid Whether the data structure is valid
    /// @return dataLength The actual data length
    function validateHookData(bytes memory hookData) 
        external 
        pure 
        returns (bool isValid, uint256 dataLength) 
    {
        dataLength = hookData.length;
        isValid = dataLength >= 297; // Minimum length for single-hop data
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get recommended slippage for a token pair
    /// @dev Returns appropriate slippage based on token volatility characteristics
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @return slippageBps Recommended slippage in basis points
    function _getRecommendedSlippage(address tokenIn, address tokenOut) 
        private 
        pure 
        returns (uint256 slippageBps) 
    {
        // Simplified logic - in production would consider token volatility
        if (tokenIn == V4_WETH || tokenOut == V4_WETH) {
            slippageBps = 300; // 3% for ETH pairs
        } else if (tokenIn == V4_USDC || tokenOut == V4_USDC) {
            slippageBps = 200; // 2% for stablecoin pairs
        } else {
            slippageBps = 500; // 5% for other pairs
        }
    }

    /// @notice Calculate mock minimum amount out using predefined ratios
    /// @dev Uses mock price ratios for testing - real implementation would query oracles
    /// @param tokenIn Input token
    /// @param tokenOut Output token
    /// @param amountIn Input amount
    /// @param slippageBps Slippage tolerance
    /// @return minAmountOut Calculated minimum output
    function _calculateMockMinAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 slippageBps
    )
        private
        pure
        returns (uint256 minAmountOut)
    {
        uint256 expectedPrice;
        
        // Get mock price ratio
        if (tokenIn == V4_USDC && tokenOut == V4_WETH) {
            expectedPrice = 1e18 / MOCK_USDC_PER_WETH; // WETH per USDC
        } else if (tokenIn == V4_WETH && tokenOut == V4_USDC) {
            expectedPrice = MOCK_USDC_PER_WETH; // USDC per WETH
        } else if (tokenIn == V4_USDC && tokenOut == V4_WBTC) {
            expectedPrice = 1e18 / MOCK_USDC_PER_WBTC; // WBTC per USDC
        } else if (tokenIn == V4_WBTC && tokenOut == V4_USDC) {
            expectedPrice = MOCK_USDC_PER_WBTC; // USDC per WBTC
        } else if (tokenIn == V4_WETH && tokenOut == V4_WBTC) {
            expectedPrice = 1e18 / MOCK_WETH_PER_WBTC; // WBTC per WETH
        } else if (tokenIn == V4_WBTC && tokenOut == V4_WETH) {
            expectedPrice = MOCK_WETH_PER_WBTC; // WETH per WBTC
        } else {
            expectedPrice = 1e18; // 1:1 default
        }

        minAmountOut = calculateMinAmountOut(amountIn, expectedPrice, slippageBps);
    }
}