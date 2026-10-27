// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IHyperCorePerpSnapshot
/// @author Superform Labs
/// @notice Raw HyperCore perp positions of an EVM account, read synchronously through the HyperEVM read
///         precompiles.
/// @dev THE INPUT IS MARKET IDENTITY, THE OUTPUT IS A STRUCTURED, NEVER-NETTED SNAPSHOT: the caller names perp
///      indices and gets one signed, mark-to-market leg per index. Nothing is summed into a NAV here. The only
///      netted figures returned are HyperCore's OWN account-level margin summary, surfaced verbatim so the
///      consumer can reconcile the legs against the source of truth instead of re-deriving equity.
///
///      COVERAGE IS THE CALLER'S: HyperCore does not enumerate an account's perps, so a snapshot covers EXACTLY
///      the supplied indices and never claims more. Zero-size rows are still returned so the shape is stable.
///
///      ONE ROW PER INPUT: `positions.length == perps.length` and `positions[i]` describes `perps[i]`, always,
///      duplicates included. Nothing is collapsed or reordered, so an integration never has to match rows back
///      to its request by `perp`. If a caller repeats an index it pays for and receives the row twice.
///
///      ONE PERP DEX FOR THE MARGIN FIGURES: the four margin fields describe `perpDex` only — dex 0 for
///      `getAccountSnapshot`, the caller's choice for `getAccountSnapshotOnDex`. Legs are read for whatever indices
///      the caller supplies, including builder-deployed (HIP-3) markets that live on another dex and keep separate
///      margin — legs on a dex other than `perpDex` are returned but are NOT reflected in `accountValue`,
///      `marginUsed`, `ntlPos` or `rawUsd`. `withdrawableUsd` is ALWAYS dex 0 (precompile 0x803 is dex-0 scoped).
///      `coin` (`"dex:COIN"` for HIP-3 markets) is the on-chain hint of dex membership.
///
///      PERP INDEX SPACE (verified live 2026-10-26): the precompiles address a market as
///      `perpDexIndex * 10000 + indexInMeta` (dex 0 = native: 0 = BTC, 1 = ETH, …; 10000 = `xyz:XYZ100`,
///      20000 = `flx:TSLA`, 70000 = `cash:USA500`). This is NOT the trading API's asset id
///      (`100000 + perpDexIndex * 10000 + indexInMeta`): an API id reverts here (fails closed), and "correcting"
///      it in the wrong direction reads ANOTHER dex's market with no error. Consumers must check `coin` against
///      the symbol they expect before trusting a leg. The oracle does not validate the index space itself.
///
///      ACCOUNT IDENTITY: the EVM address IS the HyperCore account (1:1), consistent with the CoreWriter hooks.
///
///      DECIMALS AND DENOMINATION: every "USD" figure has 6 decimals and is denominated in the perp dex's
///      COLLATERAL TOKEN — USDC on dex 0, but builder dexes choose their own quote asset (verified live: flx,
///      vntl and km settle in USDH, hyna in USDE, cash in USDT0). Figures from different dexes are therefore NOT
///      the same unit and must not be summed as one "USD". Prices carry `6 - szDecimals` decimals and `szi`
///      carries `szDecimals`, so `|szi| * markPx` is already a 6-dp notional in that collateral token with NO
///      further scaling.
///
///      FRESHNESS: values are HyperCore state as of the construction of the current EVM block. CoreWriter
///      actions sent earlier in the same block are NOT yet visible, so a read must never serve as the
///      post-condition of a write issued in the same transaction. Delisted or closed markets (HIP-3 stock and
///      commodity perps outside trading hours) keep answering with their last mark/oracle price and
///      `PerpAssetInfo` carries no liveness flag: gate on `szi != 0`, bound mark against oracle, reject
///      `markPx == 0`.
///
///      WHERE IT MAY BE CALLED: off-chain (`eth_call`) and in the EXECUTION phase of a transaction. It must never
///      be consulted during ERC-4337 validation: the values change every block, and ERC-7562 forbids it twice
///      over (OP-041: calls to code-less addresses; OP-062: only precompiles 0x1..0x11 and P256VERIFY are
///      allowed). On-chain callers that try/catch a read are protected by the per-read gas cap in
///      `HyperCoreReadLib` — an invalid index burns at most that cap per read instead of 63/64 of the caller's
///      frame. A caller with less than `HyperCoreReadLib.MIN_CALLER_GAS` left is refused up front with
///      `INSUFFICIENT_GAS` rather than having a clamped read mis-reported as an unknown index.
interface IHyperCorePerpSnapshot {
    /// @notice One perp leg for an account.
    /// @param perp Perp index as supplied (uint32, the precompile ABI's index type)
    /// @param coin Market symbol from HyperCore (e.g. "BTC"); builder-deployed markets read `"dex:COIN"`
    /// @param szDecimals Size decimals of the perp; `markPx`/`oraclePx` carry `6 - szDecimals` decimals
    /// @param szi Signed size in `szDecimals` (negative = short); zero when there is no open position
    /// @param entryNtl Entry notional, 6-dp, in the perp dex's collateral token (USDC on dex 0)
    /// @param isolatedRawUsd Isolated margin, 6-dp collateral token, SIGNED; zero for cross-margin
    /// @param leverage Configured leverage. NON-ZERO even when `szi == 0` (observed live) — not a position flag
    /// @param isIsolated True when the perp is in isolated margin mode for the account
    /// @param markPx Mark price, `6 - szDecimals` decimals, dex collateral token; frozen on delisted markets
    /// @param oraclePx Oracle price, `6 - szDecimals` decimals, dex collateral token; frozen on delisted markets
    /// @param notionalUsd `|szi| * markPx`, UNSIGNED, 6-dp in the dex's collateral token; the side lives in `szi`.
    ///        Never a positive asset, and never summed across dexes with different collateral.
    struct PerpPosition {
        uint32 perp;
        string coin;
        uint8 szDecimals;
        int64 szi;
        uint64 entryNtl;
        int64 isolatedRawUsd;
        uint32 leverage;
        bool isIsolated;
        uint64 markPx;
        uint64 oraclePx;
        uint256 notionalUsd;
    }

    /// @notice Account-level margin figures plus one leg per requested perp, in request order.
    /// @param coreUserExists Whether HyperCore knows the account. False means every ACCOUNT-LEVEL figure is zero
    ///        and every row has `szi == 0`; rows still carry market data (`szDecimals`, `markPx`, `oraclePx`)
    ///        and a default `leverage`. Gate on `szi != 0`, never on this flag or on `leverage`.
    /// @param perpDex The perp dex the four margin figures below describe (0 = Hyperliquid's native perp dex)
    /// @param withdrawableUsd Withdrawable perp margin on DEX 0, 6-dp USDC, regardless of `perpDex` (precompile 0x803
    ///        is dex-0 scoped; other dexes expose no withdrawable figure on-chain)
    /// @param accountValue HyperCore-netted account value on `perpDex`, 6-dp collateral token, SIGNED
    /// @param marginUsed Margin in use on `perpDex`, 6-dp collateral token
    /// @param ntlPos Total open notional on `perpDex`, 6-dp collateral token (HyperCore's own figure, all of the
    ///        account's legs on that dex — a superset of the covered rows)
    /// @param rawUsd Raw collateral balance on `perpDex`, 6-dp, SIGNED
    /// @param positions `positions[i]` is the leg for `perps[i]`; same length and order as the request, zero-size
    ///        rows and duplicates included
    struct AccountSnapshot {
        bool coreUserExists;
        uint32 perpDex;
        uint64 withdrawableUsd;
        int64 accountValue;
        uint64 marginUsed;
        uint64 ntlPos;
        int64 rawUsd;
        PerpPosition[] positions;
    }

    /// @notice Read one perp leg for `account`.
    /// @dev STRICT, NO FALLBACK: a zero account reverts `ZERO_ADDRESS`; an unknown perp index makes the precompile
    ///      fail and the call reverts `PRECOMPILE_CALL_FAILED`; malformed or empty returndata (wrong chain)
    ///      reverts `PRECOMPILE_BAD_RETURN`. Nothing degrades to a zero-valued leg. A perp the account never
    ///      traded returns a zero-size row, not a revert.
    /// @param account The account whose position is read (its own HyperCore master)
    /// @param perp The perp index to read
    /// @return position The raw leg plus the prices and decimals needed to value it
    function getPerpPosition(address account, uint32 perp) external view returns (PerpPosition memory position);

    /// @notice Read HyperCore's account-level margin figures on the native perp dex (0) and the legs for `perps`.
    /// @dev Equivalent to `getAccountSnapshotOnDex(account, 0, perps)`. Rows map 1:1 onto `perps` (no
    ///      de-duplication, no reordering). An empty `perps` is allowed and returns only the account-level fields.
    ///      Any invalid index fails the WHOLE call — no partial snapshot.
    /// @param account The account whose positions are read
    /// @param perps The perp indices the caller covers (the covered universe)
    /// @return snapshot Account-level figures and one row per requested perp — never netted
    function getAccountSnapshot(
        address account,
        uint32[] calldata perps
    )
        external
        view
        returns (AccountSnapshot memory snapshot);

    /// @notice Read HyperCore's account-level margin figures on `perpDex` and the legs for `perps`.
    /// @dev Builder-deployed (HIP-3) dexes keep separate margin: pass the dex the requested legs live on
    ///      (`perp / 10000`) so `accountValue`, `marginUsed`, `ntlPos` and `rawUsd` describe them. An unknown
    ///      `perpDex` fails the whole call (`PRECOMPILE_CALL_FAILED` from 0x80F). `withdrawableUsd` stays dex 0.
    /// @param account The account whose positions are read
    /// @param perpDex The perp dex whose margin summary is reported (0 = native)
    /// @param perps The perp indices the caller covers
    /// @return snapshot Account-level figures on `perpDex` and one row per requested perp — never netted
    function getAccountSnapshotOnDex(
        address account,
        uint32 perpDex,
        uint32[] calldata perps
    )
        external
        view
        returns (AccountSnapshot memory snapshot);
}
