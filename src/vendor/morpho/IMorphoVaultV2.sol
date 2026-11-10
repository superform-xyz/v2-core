// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IMorphoVaultV2
/// @notice Minimal interface for Morpho Vault V2's forceDeallocate function
interface IMorphoVaultV2 {
    /// @notice Permissionlessly deallocates assets from an adapter back to the vault's idle balance.
    /// @dev A penalty (up to 2%) is charged as a share burn on `onBehalf`.
    /// @param adapter The adapter contract to deallocate from (must be registered).
    /// @param data Protocol-specific encoded data for the adapter's deallocate function.
    /// @param assets The amount of underlying assets to deallocate.
    /// @param onBehalf The address whose shares will be burned as penalty.
    /// @return penaltyAssets The asset-denominated penalty withdrawn from onBehalf (shares are burned to
    ///         cover it). Named `penaltyShares` in earlier revisions of this file; Morpho returns assets.
    function forceDeallocate(
        address adapter,
        bytes memory data,
        uint256 assets,
        address onBehalf
    ) external returns (uint256 penaltyAssets);

    /// @notice Returns the penalty rate (in WAD, i.e. 1e18 = 100%) for forceDeallocate on a given adapter.
    /// @dev Maximum is 0.02e18 (2%).
    /// @param adapter The adapter address to query the penalty for.
    /// @return The penalty rate in WAD.
    function forceDeallocatePenalty(address adapter) external view returns (uint256);

    /// @notice Number of adapters currently registered on the vault.
    /// @dev Walked with `adapters(i)` over `[0, adaptersLength())`. Curator-managed under timelock, so the
    ///      length can change between a simulation and execution; callers must tolerate that.
    function adaptersLength() external view returns (uint256);

    /// @notice The adapter registered at `index`.
    /// @dev Adapters are heterogeneous. A Morpho Blue market adapter answers `IMorphoMarketV1Adapter`;
    ///      a `MorphoVaultV1Adapter` wraps another vault and does NOT, so it must be filtered out by probing
    ///      rather than assumed.
    function adapters(uint256 index) external view returns (address);

    /// @notice The vault's underlying asset.
    function asset() external view returns (address);

    /// @notice Vault share balance of `account`.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Shares that would be burned to withdraw exactly `assets`, rounded up.
    /// @dev Pure share math: it does NOT require the vault to hold `assets` as idle, so it is valid to call
    ///      while the vault is still illiquid. That is what makes it usable as a pre-flight penalty bound.
    function previewWithdraw(uint256 assets) external view returns (uint256);
}
