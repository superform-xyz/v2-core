// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IPSM3
/// @notice Interface for Sky.money's Spark PSM (Peg Stability Module) v3
/// @dev Supports USDC, USDS, and sUSDS swaps with zero-fee deterministic pricing
interface IPSM3 {
    /// @notice Swap an exact amount of input tokens for output tokens
    /// @param assetIn The token to swap from
    /// @param assetOut The token to swap to
    /// @param amountIn The exact amount of input tokens
    /// @param minAmountOut The minimum acceptable output amount
    /// @param receiver The address to receive output tokens
    /// @param referralCode Referral code for tracking
    /// @return amountOut The actual amount of output tokens received
    function swapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        uint256 referralCode
    )
        external
        returns (uint256 amountOut);

    /// @notice Swap tokens to receive an exact amount of output tokens
    /// @param assetIn The token to swap from
    /// @param assetOut The token to swap to
    /// @param amountOut The exact amount of output tokens desired
    /// @param maxAmountIn The maximum acceptable input amount
    /// @param receiver The address to receive output tokens
    /// @param referralCode Referral code for tracking
    /// @return amountIn The actual amount of input tokens consumed
    function swapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver,
        uint256 referralCode
    )
        external
        returns (uint256 amountIn);

    /// @notice Preview the output amount for an exact input swap
    /// @param assetIn The token to swap from
    /// @param assetOut The token to swap to
    /// @param amountIn The exact amount of input tokens
    /// @return amountOut The estimated output amount
    function previewSwapExactIn(
        address assetIn,
        address assetOut,
        uint256 amountIn
    )
        external
        view
        returns (uint256 amountOut);

    /// @notice Preview the input amount for an exact output swap
    /// @param assetIn The token to swap from
    /// @param assetOut The token to swap to
    /// @param amountOut The exact amount of output tokens desired
    /// @return amountIn The estimated input amount required
    function previewSwapExactOut(
        address assetIn,
        address assetOut,
        uint256 amountOut
    )
        external
        view
        returns (uint256 amountIn);
}
