// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { BaseAPIParser } from "./BaseAPIParser.sol";

// Real Uniswap V4 imports
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";

/// @title UniswapV4Parser
/// @author Superform Labs
/// @notice Parser for generating Uniswap V4 hook calldata without external API dependencies
/// @dev Provides on-chain calldata generation for V4 swaps following Superform patterns
contract UniswapV4Parser is BaseAPIParser {
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
    /// @param poolKey Pool key for the V4 pool
    /// @param dstReceiver Recipient of output tokens
    /// @param sqrtPriceLimitX96 Price limit (0 for no limit)
    /// @param originalAmountIn Input amount
    /// @param originalMinAmountOut Minimum output amount
    /// @param maxSlippageDeviationBps Maximum allowed ratio change in basis points
    /// @param zeroForOne Whether swapping token0 for token1
    /// @param additionalData Additional data for the swap
    struct SingleHopParams {
        PoolKey poolKey;
        address dstReceiver;
        uint160 sqrtPriceLimitX96;
        uint256 originalAmountIn;
        uint256 originalMinAmountOut;
        uint256 maxSlippageDeviationBps;
        bool zeroForOne;
        bytes additionalData;
    }

    /*//////////////////////////////////////////////////////////////
                        SINGLE-HOP GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Get tick spacing for a given fee tier
    /// @param fee The fee tier
    /// @return tickSpacing The tick spacing for the fee tier
    function getTickSpacing(uint24 fee) public pure returns (int24 tickSpacing) {
        if (fee == 500) {
            tickSpacing = 10;
        } else if (fee == 3000) {
            tickSpacing = 60;
        } else if (fee == 10_000) {
            tickSpacing = 200;
        } else {
            revert("Unsupported fee tier");
        }
    }

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
    /// Layout (standard 10-field Layer 1):
    ///   [0..31]    bytes32 placeholder0
    ///   [32..51]   address placeholder1     (bytes20)
    ///   [52..71]   address inputToken       (bytes20)
    ///   [72..91]   address outputToken      (bytes20)
    ///   [92..123]  uint256 inputAmount      (bytes32)
    ///   [124..155] uint256 outputQuote      (bytes32) — equals outputMin for AMM hooks
    ///   [156..187] uint256 outputMin        (bytes32)
    ///   [188]      bool    usePrevHookAmount (bytes1)
    ///   [189..220] uint256 payloadLength    (bytes32)
    ///   [221..]    bytes   payload          (variable)
    /// @param params The swap parameters
    /// @param usePrevHookAmount Whether to use previous hook's output
    /// @return hookData Encoded hook data ready for execution
    function generateSingleHopSwapCalldata(
        SingleHopParams memory params,
        bool usePrevHookAmount
    )
        public
        pure
        returns (bytes memory hookData)
    {
        // abi-encoded payload (Layer 2)
        // Payload: abi.encode(bool zeroForOne, uint24 fee, int24 tickSpacing, address hooks,
        //          address dstReceiver, uint160 sqrtPriceLimitX96, uint256 maxSlippageDeviationBps, bytes additionalData)
        bytes memory payload = abi.encode(
            params.zeroForOne,
            params.poolKey.fee,
            params.poolKey.tickSpacing,
            address(params.poolKey.hooks),
            params.dstReceiver,
            params.sqrtPriceLimitX96,
            params.maxSlippageDeviationBps,
            params.additionalData
        );

        // Tight-packed Layer 0 + Layer 1 + Layer 2
        hookData = abi.encodePacked(
            bytes32(0),                                         // 32 bytes [0..31]:    placeholder0
            bytes20(address(0)),                                // 20 bytes [32..51]:   placeholder1
            bytes20(Currency.unwrap(params.poolKey.currency0)), // 20 bytes [52..71]:   inputToken
            bytes20(Currency.unwrap(params.poolKey.currency1)), // 20 bytes [72..91]:   outputToken
            params.originalAmountIn,                            // 32 bytes [92..123]:  inputAmount
            params.originalMinAmountOut,                        // 32 bytes [124..155]: outputQuote (== outputMin for AMM)
            params.originalMinAmountOut,                        // 32 bytes [156..187]: outputMin
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00),    // 1  byte  [188]:      usePrevHookAmount
            payload.length,                                     // 32 bytes [189..220]: payloadLength
            payload                                             // var      [221..]:    payload
        );
    }
}
