// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

/// @title IV3SwapRouter
/// @notice Interface for Uniswap V3 SwapRouter02's exactInputSingle
/// @dev SwapRouter02 removes deadline from the params struct.
///      Deadline is handled via the multicall(uint256 deadline, bytes[] data) wrapper on SwapRouter02.
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
