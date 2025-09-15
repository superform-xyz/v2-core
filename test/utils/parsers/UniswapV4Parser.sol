// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { BaseAPIParser } from "./BaseAPIParser.sol";

// Real Uniswap V4 imports
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";

/// @title UniswapV4Parser
/// @author Superform Labs
/// @notice Parser for generating Uniswap V4 hook calldata without external API dependencies
/// @dev Provides on-chain calldata generation for V4 swaps following Superform patterns
contract UniswapV4Parser is BaseAPIParser {
    using Currency for address;

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

    /*//////////////////////////////////////////////////////////////
                        SINGLE-HOP GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if two tokens need to be swapped for proper pool ordering
    /// @dev V4 pools require token0 < token1
    /// @param tokenA First token
    /// @param tokenB Second token
    /// @return token0 The lower address token
    /// @return token1 The higher address token
    /// @return swapped Whether the tokens were swapped from input order
    function _sortTokens(
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

    /// @notice Generate hook data for single-hop V4 swap
    /// @dev Creates properly encoded data matching SwapUniswapV4Hook expectations
    /// @param params The swap parameters
    /// @param usePrevHookAmount Whether to use previous hook's output
    /// @return hookData Encoded hook data ready for execution
    function generateSingleHopSwapCalldata(
        SingleHopSwapParams memory params,
        bool usePrevHookAmount
    )
        public
        pure
        returns (bytes memory hookData)
    {
        // Validate inputs
        if (params.tokenIn == params.tokenOut) {
            revert IdenticalTokens();
        }

        // Sort tokens for proper pool ordering (V4 requires token0 < token1)
        (address token0, address token1, bool swapped) = _sortTokens(params.tokenIn, params.tokenOut);

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
            abi.encode(poolKey), // 160 bytes: PoolKey
            params.recipient, // 20 bytes: dstReceiver
            params.sqrtPriceLimitX96, // 20 bytes: sqrtPriceLimitX96
            params.amountIn, // 32 bytes: originalAmountIn
            params.minAmountOut, // 32 bytes: originalMinAmountOut
            params.maxSlippageDeviationBps, // 32 bytes: maxSlippageDeviationBps
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // 1 byte: usePrevHookAmount flag
                // Additional data would go here if needed (bytes hookData)
        );
    }
}
