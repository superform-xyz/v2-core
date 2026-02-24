// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IYoVault
/// @notice Interface for Yo Vaults with async redemption support
/// @dev Yo Vaults use address-based accumulator pattern for pending redemptions,
///      unlike standard ERC-7540 which uses request IDs
interface IYoVault {
    /// @notice Returns the share token balance of an account
    /// @param account The address to query
    /// @return The share balance
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the number of decimals of the share token
    /// @return The number of decimals
    function decimals() external view returns (uint8);

    /// @notice Converts shares to assets at current exchange rate
    /// @param shares The amount of shares to convert
    /// @return assets The equivalent amount of assets
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @notice Converts assets to shares at current exchange rate
    /// @param assets The amount of assets to convert
    /// @return shares The equivalent amount of shares
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @notice Returns pending redeem request for an owner
    /// @dev Returns accumulated pending assets and shares across all requests
    ///      This differs from ERC-7540 which uses (requestId, controller) params
    /// @param owner The address to check pending requests for
    /// @return assets The total pending assets to be received
    /// @return shares The total pending shares (burned but not yet fulfilled)
    function pendingRedeemRequest(address owner) external view returns (uint256 assets, uint256 shares);

    /// @notice Returns total assets managed by the vault
    /// @return The total assets under management
    function totalAssets() external view returns (uint256);

    /// @notice Preview deposit assets to shares conversion
    /// @param assets The amount of assets to deposit
    /// @return shares The amount of shares that would be minted
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /// @notice Request async redemption of shares
    /// @dev If vault has sufficient liquidity, redemption is immediate.
    ///      Otherwise, request is stored and fulfilled later by operator.
    /// @param shares The amount of shares to redeem
    /// @param receiver The address to receive the assets
    /// @param owner The owner of the shares
    /// @return assets The amount of assets requested (may be pending)
    function requestRedeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
