// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4OwnerSnapshot
/// @notice Complete raw Aave accounting inputs for an owner on a specified set of spokes.
/// @dev Values stay in underlying token units. Consumers normalize, classify and net them.
interface IAaveV4OwnerSnapshot {
    struct OwnerPosition {
        address sourceKey;
        address spoke;
        uint256 reserveId;
        address underlying;
        uint8 underlyingDecimals;
        uint8 side;
        uint256 assets;
        string symbol; // Optional display metadata; empty when unavailable or malformed.
    }

    struct WalletBalance {
        address token;
        uint8 decimals;
        uint256 balance;
    }

    /// @notice Version of the complete owner snapshot contract; consumers must require version 1.
    function SNAPSHOT_VERSION() external view returns (uint256);

    /// @notice Read registered positions, discover every active debt on covered spokes, and read cash.
    /// @dev Reverts on any incomplete accounting read or unregistered active debt. Source keys and spokes are
    ///      deduplicated. Spokes are the union of registered positions and configuredSpokes. Wallet
    ///      tokens are the union of debt underlyings and cashTokens, excluding vaultAsset. A consumer
    ///      must keep a spoke covered until all its positions are closed, and use cashTokens to retain
    ///      leftover-cash coverage after debt sources disappear. No supply positions are auto-discovered.
    /// @param owner Strategy/account whose positions and wallet balances are read.
    /// @param sourceKeys Registered supply or debt keys for this oracle.
    /// @param configuredSpokes Additional spokes to cover independently of source registration.
    /// @param cashTokens Explicit tokens to keep tracking after full repayment.
    /// @param vaultAsset Token already counted as idle vault cash by the consumer.
    /// @param maxReservesPerSpoke Maximum permitted reserve count; exceeding it reverts, never truncates.
    /// @return version Snapshot contract version.
    /// @return positions Unique registered positions followed by additional active debts.
    /// @return balances Unique non-vault cash balances; all amounts are non-negative raw token units.
    function getOwnerSnapshot(
        address owner,
        address[] calldata sourceKeys,
        address[] calldata configuredSpokes,
        address[] calldata cashTokens,
        address vaultAsset,
        uint256 maxReservesPerSpoke
    )
        external
        view
        returns (uint256 version, OwnerPosition[] memory positions, WalletBalance[] memory balances);
}
