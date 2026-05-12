// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IDETHAsyncRedeemer
/// @notice Minimal interface for Dialectic's AsyncRedeemer contract
/// @dev The AsyncRedeemer implements a two-phase async redemption flow:
///      1. requestRedeem() transfers DETH shares and mints an ERC-721 NFT receipt
///      2. claimAssets() burns the NFT and transfers WETH after finalization
///      Both functions require the caller to be whitelisted.
interface IDETHAsyncRedeemer {
    /// @notice Requests redemption of DETH shares for WETH
    /// @param shares Amount of DETH shares to redeem
    /// @param receiver Address to receive the ERC-721 NFT receipt
    /// @param minAssets Minimum WETH expected (slippage protection)
    /// @return requestId The minted NFT request ID
    function requestRedeem(uint256 shares, address receiver, uint256 minAssets) external returns (uint256 requestId);

    /// @notice Claims WETH for a finalized redemption request
    /// @param requestId The NFT request ID to claim
    /// @return assets Amount of WETH received
    function claimAssets(uint256 requestId) external returns (uint256 assets);

    /// @notice Returns the Machine vault address
    /// @return The address of the Machine vault contract
    function machine() external view returns (address);
}
