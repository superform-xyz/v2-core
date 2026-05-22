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
    /// @return penaltyShares The number of vault shares burned from onBehalf as penalty.
    function forceDeallocate(
        address adapter,
        bytes memory data,
        uint256 assets,
        address onBehalf
    ) external returns (uint256 penaltyShares);

    /// @notice Returns the penalty rate (in WAD, i.e. 1e18 = 100%) for forceDeallocate on a given adapter.
    /// @dev Maximum is 0.02e18 (2%).
    /// @param adapter The adapter address to query the penalty for.
    /// @return The penalty rate in WAD.
    function forceDeallocatePenalty(address adapter) external view returns (uint256);
}
