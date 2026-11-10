// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title IMorphoMarketV1Adapter
/// @notice Minimal read interface for Morpho Vault V2's Morpho Blue market adapters
/// @dev Covers `MorphoMarketV1Adapter` and `MorphoMarketV1AdapterV2`. Only the views a caller needs to
///      enumerate the adapter's listed markets and size a `forceDeallocate` are declared; the mutating
///      `allocate`/`deallocate` entry points are vault-only and deliberately absent.
/// @dev DO NOT ASSUME AN ADAPTER ANSWERS THIS INTERFACE. A Vault V2's adapter list is heterogeneous: a
///      `MorphoVaultV1Adapter` wraps another vault and implements none of `marketIds`, `marketIdsLength` or
///      `expectedSupplyAssets`. Because a `STATICCALL` to an address with no code SUCCEEDS with empty
///      returndata, a `try/catch` against a wrong-shaped or codeless target takes the SUCCESS branch and
///      then has to decode zero bytes. Callers must probe with `code.length` plus a low-level `staticcall`
///      and a returndata-length check, not with `try/catch`.
/// @dev Verified against the live Gauntlet WETH Prime adapter 0xc2B92c498b235516380c04879259Eb2CB1A87a35 on
///      Ethereum: every selector below is present in its deployed bytecode. `allocation(bytes32)` is NOT,
///      so the vault's per-market bookkeeping is not reachable from the adapter.
interface IMorphoMarketV1Adapter {
    /// @notice The Vault V2 this adapter belongs to.
    /// @dev The identity check that makes an adapter trustworthy to enumerate: a caller walking
    ///      `vault.adapters(i)` must assert `parentVault() == vault` before reading anything else, so a
    ///      look-alike contract registered elsewhere cannot be mistaken for this vault's adapter.
    function parentVault() external view returns (address);

    /// @notice The Morpho Blue singleton this adapter supplies into.
    function morpho() external view returns (address);

    /// @notice Number of Morpho Blue market ids this adapter lists.
    function marketIdsLength() external view returns (uint256);

    /// @notice The market id at `index`.
    /// @dev Nothing in the adapter forbids the same id appearing twice, and two adapters of one vault can
    ///      list the same id. Liquidity is a property of the MARKET, so a caller planning several pulls must
    ///      track committed liquidity per id rather than per (adapter, market) pair.
    function marketIds(uint256 index) external view returns (bytes32);

    /// @notice The adapter's own position on `marketId`, in underlying, including interest accrued to
    ///         `block.timestamp`.
    /// @dev This is the ADAPTER'S share accounting converted to assets, NOT the market's withdrawable
    ///      liquidity, and on the V2 adapter it tracks an internal `supplyShares` figure rather than the raw
    ///      Morpho position. A pull must be bounded by `min(this, market liquidity)`; either bound alone
    ///      reverts inside the adapter or inside Morpho.
    function expectedSupplyAssets(bytes32 marketId) external view returns (uint256);

    /// @notice The IRM this adapter pins its markets to, or `address(0)` when it pins none.
    /// @dev PRESENT ONLY ON `MorphoMarketV1AdapterV2`. When it returns non-zero, that adapter reverts
    ///      `IrmMismatch` on any market whose `irm` differs, so a caller must drop such markets in its view
    ///      pass or the whole transaction reverts. Probe it: on the V1 adapter the call fails and the
    ///      correct reading is "pins no IRM".
    function adaptiveCurveIrm() external view returns (address);
}
