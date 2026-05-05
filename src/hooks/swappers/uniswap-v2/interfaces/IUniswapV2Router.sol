// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V2 Router
interface IUniswapV2Router {
    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
    /// @param amountIn The amount of input tokens to send
    /// @param amountOutMin The minimum amount of output tokens that must be received
    /// @param path An array of token addresses representing the swap route
    /// @param to Recipient of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        returns (uint256[] memory amounts);

    /// @notice Swaps exact ETH for as many output tokens as possible
    /// @dev msg.value is used as the input amount
    /// @param amountOutMin The minimum amount of output tokens that must be received
    /// @param path An array of token addresses (path[0] must be WETH)
    /// @param to Recipient of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256[] memory amounts);

    /// @notice Swaps an exact amount of tokens for ETH
    /// @param amountIn The amount of input tokens to send
    /// @param amountOutMin The minimum amount of ETH that must be received
    /// @param path An array of token addresses (path[last] must be WETH)
    /// @param to Recipient of the ETH
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        returns (uint256[] memory amounts);
}
