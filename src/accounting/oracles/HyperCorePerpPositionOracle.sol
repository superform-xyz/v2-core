// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// Superform
import { HyperCoreReadLib } from "../../vendor/hyperliquid/HyperCoreReadLib.sol";
import { IHyperCorePerpSnapshot } from "../../interfaces/accounting/IHyperCorePerpSnapshot.sol";

/// @title HyperCorePerpPositionOracle
/// @author Superform Labs
/// @notice Read-only oracle exposing an account's HyperCore perp positions to HyperEVM contracts
/// @dev HyperCore perps are written through CoreWriter and are otherwise invisible to the EVM. This contract
///      reads them back through the HyperCore read precompiles, synchronously and without an external feed:
///      the values match the latest HyperCore state at the time the EVM block was constructed.
/// @dev Not an `IYieldSourceOracle`: a perp leg is signed, mark-to-market, USD-denominated and per-perp, so
///      there is no scalar price-per-share to report. It is a structured snapshot — raw legs plus HyperCore's
///      own account-level margin summary — for an off-chain or execution-phase consumer (OMS / strategy
///      snapshot / hook) to classify and net. NOT for the ERC-4337 validation phase (see the interface).
/// @dev HYPEREVM ONLY (chain 999, testnet 998). Zero storage, no constructor, no events. On any other chain
///      the precompile addresses are code-less and every read reverts `PRECOMPILE_BAD_RETURN(addr, 0)`: the
///      oracle fails closed rather than reporting zeros.
/// @dev An unknown perp index makes the precompile fail and consume the gas forwarded to it; the library caps
///      that at `PRECOMPILE_GAS_LIMIT` per read, so a reverting snapshot costs at most one cap on top of the
///      reads that succeeded, and refuses (`INSUFFICIENT_GAS`) callers that cannot fund the cap, so a clamped
///      read is never mistaken for an unknown index. There is no try/catch inside the oracle. Gas envelope:
///      roughly 27k for the account level plus ~55k per REQUESTED perp (four reads, cold access, decoding;
///      duplicates are re-read, not cached), so a snapshot of a few dozen perps fits a HyperEVM small block
///      (3M gas); whole-universe sweeps are `eth_call` only.
contract HyperCorePerpPositionOracle is IHyperCorePerpSnapshot {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Default perp dex for `getAccountSnapshot` (echoed as `AccountSnapshot.perpDex`). 0 is Hyperliquid's
    ///         native perp dex; `getAccountSnapshotOnDex` takes the dex explicitly.
    uint32 public constant PERP_DEX = 0;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the queried account is the zero address
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                              EXTERNAL VIEWS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHyperCorePerpSnapshot
    function getPerpPosition(address account, uint32 perp) external view returns (PerpPosition memory position) {
        if (account == address(0)) revert ZERO_ADDRESS();
        position = _perpPosition(account, perp);
    }

    /// @inheritdoc IHyperCorePerpSnapshot
    function getAccountSnapshot(
        address account,
        uint32[] calldata perps
    )
        external
        view
        returns (AccountSnapshot memory snapshot)
    {
        return _snapshot(account, PERP_DEX, perps);
    }

    /// @inheritdoc IHyperCorePerpSnapshot
    function getAccountSnapshotOnDex(
        address account,
        uint32 perpDex,
        uint32[] calldata perps
    )
        external
        view
        returns (AccountSnapshot memory snapshot)
    {
        return _snapshot(account, perpDex, perps);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Account-level figures on `perpDex` plus one row per requested perp
    /// @dev `withdrawable` (0x803) is dex-0 scoped and is reported as such whatever `perpDex` is.
    function _snapshot(
        address account,
        uint32 perpDex,
        uint32[] calldata perps
    )
        private
        view
        returns (AccountSnapshot memory snapshot)
    {
        if (account == address(0)) revert ZERO_ADDRESS();

        // Account level first: a failing account-level read surfaces before any perp is read.
        snapshot.coreUserExists = HyperCoreReadLib.coreUserExists(account);
        snapshot.perpDex = perpDex;
        snapshot.withdrawableUsd = HyperCoreReadLib.withdrawable(account);
        HyperCoreReadLib.AccountMarginSummary memory summary = HyperCoreReadLib.accountMarginSummary(perpDex, account);
        snapshot.accountValue = summary.accountValue;
        snapshot.marginUsed = summary.marginUsed;
        snapshot.ntlPos = summary.ntlPos;
        snapshot.rawUsd = summary.rawUsd;

        // ONE ROW PER INPUT: `positions[i]` is always `perps[i]`, duplicates included. An integration that sends
        // three indices gets three rows back in the same order, so nothing has to be matched up by `perp`.
        uint256 n = perps.length;
        snapshot.positions = new PerpPosition[](n);
        for (uint256 i; i < n; ++i) {
            snapshot.positions[i] = _perpPosition(account, perps[i]);
        }
    }

    /// @notice Assemble one leg from four precompile reads
    /// @dev All four perp-indexed reads revert on an unknown index (verified live), so the read order is NOT a
    ///      validation step; `perpAssetInfo` simply supplies `coin` and `szDecimals`. `notionalUsd = |szi| * markPx`
    ///      is 6-dp in the dex's collateral token by construction (`szDecimals` on the size, `6 - szDecimals` on the
    ///      price); applying any `10^szDecimals` factor here would be the bug. The product is bounded by
    ///      2^63 * 2^64 so it cannot overflow uint256. `coin` is kept because it is the only on-chain hint of which
    ///      dex a perp belongs to. Assumes `account != address(0)`.
    function _perpPosition(address account, uint32 perp) private view returns (PerpPosition memory p) {
        HyperCoreReadLib.PerpAssetInfo memory info = HyperCoreReadLib.perpAssetInfo(perp);
        HyperCoreReadLib.Position memory pos = HyperCoreReadLib.position(account, perp);

        p.perp = perp;
        p.coin = info.coin;
        p.szDecimals = info.szDecimals;
        p.szi = pos.szi;
        p.entryNtl = pos.entryNtl;
        p.isolatedRawUsd = pos.isolatedRawUsd;
        p.leverage = pos.leverage;
        p.isIsolated = pos.isIsolated;
        p.markPx = HyperCoreReadLib.markPx(perp);
        p.oraclePx = HyperCoreReadLib.oraclePx(perp);
        p.notionalUsd = _abs(pos.szi) * uint256(p.markPx);
    }

    /// @notice Absolute value of an int64 as uint256
    /// @dev Widens to int256 BEFORE negating: `-type(int64).min` overflows int64 but not int256. Never use
    ///      `uint256(uint64(x))`, which yields two's-complement garbage for shorts.
    function _abs(int64 x) private pure returns (uint256) {
        return x < 0 ? uint256(-int256(x)) : uint256(int256(x));
    }
}
