// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title HyperCoreReadLib
/// @author Superform Labs
/// @notice Typed `staticcall` readers for Hyperliquid's HyperCore read precompiles (0x800+) on HyperEVM
/// @dev The read precompiles take RAW `abi.encode(args)` — there is NO 4-byte function selector — and return
///      abi-encoded values that match the latest HyperCore state at the time the EVM block was constructed.
///      That is why this is a library of low-level calls and not a Solidity `interface`: an interface call
///      would prepend a selector and every read would fail. Gas is `2000 + 65 * (inputLen + outputLen)`.
/// @dev INVALID INPUT (e.g. an unknown perp index) makes the precompile fail AND consume all gas forwarded to
///      the call frame. Every read therefore forwards at most `PRECOMPILE_GAS_LIMIT`, which bounds the burn an
///      on-chain caller can suffer while leaving ~24x headroom over the most expensive documented read, and every
///      read first requires the caller to hold `MIN_CALLER_GAS` so the cap is actually forwarded (EIP-150 would
///      otherwise clamp it silently and a VALID read could run out of gas and look like an invalid index). A
///      failure is still terminal for the read (fail closed, no fallback). Addresses are protocol constants on 999/998.
/// @dev DECIMALS: value figures (`entryNtl`, `isolatedRawUsd`, `withdrawable`, every margin-summary field) have 6
///      decimals and are denominated in the perp dex's COLLATERAL TOKEN (USDC on dex 0; builder dexes may use
///      USDH, USDE, USDT0, …). Prices (`markPx`, `oraclePx`) carry `6 - szDecimals` decimals. `szi` is
///      denominated in `szDecimals` of the perp, so `|szi| * markPx` is a 6-decimal notional in that token.
library HyperCoreReadLib {
    /*//////////////////////////////////////////////////////////////
                              PRECOMPILES
    //////////////////////////////////////////////////////////////*/

    /// @notice `withdrawable(address user) -> uint64` withdrawable perp margin, 6-dp USD
    address internal constant WITHDRAWABLE_PRECOMPILE = 0x0000000000000000000000000000000000000803;
    /// @notice `markPx(uint32 perp) -> uint64` mark price, `6 - szDecimals` decimals
    address internal constant MARK_PX_PRECOMPILE = 0x0000000000000000000000000000000000000806;
    /// @notice `oraclePx(uint32 perp) -> uint64` oracle price, `6 - szDecimals` decimals
    address internal constant ORACLE_PX_PRECOMPILE = 0x0000000000000000000000000000000000000807;
    /// @notice `perpAssetInfo(uint32 perp) -> PerpAssetInfo`
    address internal constant PERP_ASSET_INFO_PRECOMPILE = 0x000000000000000000000000000000000000080a;
    /// @notice `accountMarginSummary(uint32 perpDexIndex, address user) -> AccountMarginSummary`
    address internal constant ACCOUNT_MARGIN_SUMMARY_PRECOMPILE = 0x000000000000000000000000000000000000080F;
    /// @notice `coreUserExists(address user) -> bool`
    address internal constant CORE_USER_EXISTS_PRECOMPILE = 0x0000000000000000000000000000000000000810;
    /// @notice `position2(address user, uint32 perp) -> Position`
    /// @dev The uint32-indexed successor of `position` (0x800, uint16). Perp indices are
    ///      `perpDexIndex * 10000 + indexInMeta` (NOT the trading API's `100000 + …` asset id, which reverts), so
    ///      builder dexes from index 7 upward (>= 70000) are unreachable through the uint16 `position`; `position2`
    ///      is required, not stylistic. The precompile decides which indices exist; nothing is validated here.
    address internal constant POSITION2_PRECOMPILE = 0x0000000000000000000000000000000000000813;

    /// @notice Gas forwarded to every precompile read — a ceiling, not a floor
    /// @dev Documented cost of the most expensive read (`perpAssetInfo`, 32-byte input, 256-byte output) is
    ///      2000 + 65 * 288 = 20,720 (~24x headroom; measured live frames are 3.7k–11.1k, so real headroom is
    ///      larger). The cap bounds the worst-case burn on an invalid index to this amount per read instead of
    ///      63/64 of the caller's frame (measured: 500,503 with the cap vs 29.5M of 30M without), so an on-chain
    ///      consumer that still has more than the cap available can safely try/catch the oracle. If Hyperliquid
    ///      ever reprices beyond it the read fails closed by name rather than returning garbage.
    uint256 internal constant PRECOMPILE_GAS_LIMIT = 500_000;

    /// @notice Minimum gas the caller must have left before a read
    /// @dev EIP-150 forwards at most 63/64 of the remaining gas, so the full `PRECOMPILE_GAS_LIMIT` is only
    ///      forwarded when `gasleft() >= cap * 64 / 63` (≈ 507,937); the rest is margin for the check itself and
    ///      for decoding. Below this the read reverts `INSUFFICIENT_GAS` instead of letting a clamped frame fail
    ///      a legitimate read and mis-signal it as `PRECOMPILE_CALL_FAILED` ("unknown index").
    uint256 internal constant MIN_CALLER_GAS = 520_000;

    /// @dev Expected returndata sizes. Static tuples are exact; `PerpAssetInfo` is dynamic (string) so only a
    ///      lower bound applies: offset word + 5 head words + string length word = 224 bytes with an empty coin.
    uint256 private constant WORD = 32;
    uint256 private constant POSITION_LEN = 160;
    uint256 private constant MARGIN_SUMMARY_LEN = 128;
    uint256 private constant PERP_ASSET_INFO_MIN_LEN = 224;

    /*//////////////////////////////////////////////////////////////
                               RETURN TYPES
    //////////////////////////////////////////////////////////////*/

    /// @notice `position2` output. All-static tuple, 160 bytes on the wire.
    /// @param szi Signed size in `szDecimals` (negative = short); zero when there is no open position
    /// @param entryNtl Entry notional, 6-dp USD
    /// @param isolatedRawUsd Isolated margin, 6-dp USD, signed; zero for cross-margin positions
    /// @param leverage Configured leverage. Observed live to be NON-ZERO on zero-size rows — not a position flag.
    /// @param isIsolated True when the perp is in isolated margin mode for the user
    struct Position {
        int64 szi;
        uint64 entryNtl;
        int64 isolatedRawUsd;
        uint32 leverage;
        bool isIsolated;
    }

    /// @notice `perpAssetInfo` output. Contains a `string`, so it is STRUCT-WRAPPED on the wire (a leading
    ///         offset word); decode it as `(PerpAssetInfo)`, never as a flat tuple.
    /// @param coin Market symbol, e.g. "BTC"; builder-deployed (HIP-3) markets are prefixed `"dex:COIN"`
    /// @param marginTableId HyperCore margin table id
    /// @param szDecimals Size decimals of the perp; prices carry `6 - szDecimals` decimals
    /// @param maxLeverage Maximum leverage allowed on the perp
    /// @param onlyIsolated True when the perp only supports isolated margin
    struct PerpAssetInfo {
        string coin;
        uint32 marginTableId;
        uint8 szDecimals;
        uint8 maxLeverage;
        bool onlyIsolated;
    }

    /// @notice `accountMarginSummary` output. All-static tuple, 128 bytes on the wire. All 6-dp USD.
    /// @param accountValue HyperCore-netted account value on the dex, SIGNED
    /// @param marginUsed Margin currently in use on the dex
    /// @param ntlPos Total open notional on the dex
    /// @param rawUsd Raw USD balance on the dex, SIGNED
    struct AccountMarginSummary {
        int64 accountValue;
        uint64 marginUsed;
        uint64 ntlPos;
        int64 rawUsd;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the precompile itself fails (live: an invalid input such as an unknown perp index)
    /// @param precompile The precompile address whose read failed
    error PRECOMPILE_CALL_FAILED(address precompile);

    /// @notice Thrown when the caller has too little gas left for the cap to be forwarded in full
    /// @param available Gas left at the check
    /// @param required `MIN_CALLER_GAS`
    error INSUFFICIENT_GAS(uint256 available, uint256 required);

    /// @notice Thrown when the precompile returned, but with returndata of an unexpected size
    /// @dev Length 0 is the wrong-chain signature: on a chain without HyperCore the fixed addresses are code-less
    ///      and a staticcall to them "succeeds" with nothing. Any other unexpected length means the wire shape
    ///      drifted from what this library decodes. LENGTH drift is named here so a deploy or upgrade mismatch
    ///      fails closed with a diagnosable reason; VALUE-level drift (a dirty `uint32`/`bool` word, a malformed
    ///      string offset) is still rejected by `abi.decode`, but with an empty revert. Both fail closed.
    /// @param precompile The precompile address that answered
    /// @param length The returndata length received
    error PRECOMPILE_BAD_RETURN(address precompile, uint256 length);

    /*//////////////////////////////////////////////////////////////
                                 READERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reads `user`'s position on `perp` via `position2`
    /// @dev A user HyperCore has never seen and a perp the user never traded both return `szi == 0` without
    ///      reverting (other fields such as `leverage` may still be non-zero); only an unknown `perp` reverts.
    function position(address user, uint32 perp) internal view returns (Position memory) {
        return abi.decode(_staticcall(POSITION2_PRECOMPILE, abi.encode(user, perp), POSITION_LEN, true), (Position));
    }

    /// @notice Reads `user`'s withdrawable perp margin, 6-dp USD
    function withdrawable(address user) internal view returns (uint64) {
        return abi.decode(_staticcall(WITHDRAWABLE_PRECOMPILE, abi.encode(user), WORD, true), (uint64));
    }

    /// @notice Reads the mark price of `perp`, `6 - szDecimals` decimals
    function markPx(uint32 perp) internal view returns (uint64) {
        return abi.decode(_staticcall(MARK_PX_PRECOMPILE, abi.encode(perp), WORD, true), (uint64));
    }

    /// @notice Reads the oracle price of `perp`, `6 - szDecimals` decimals
    function oraclePx(uint32 perp) internal view returns (uint64) {
        return abi.decode(_staticcall(ORACLE_PX_PRECOMPILE, abi.encode(perp), WORD, true), (uint64));
    }

    /// @notice Reads the static market info of `perp`
    /// @dev Reverts for an unknown index — as EVERY perp-indexed precompile does (verified live: `position2`,
    ///      `markPx` and `oraclePx` all fail on index 110000). It is read for `coin` and `szDecimals`, not as a
    ///      validation step; no read order buys fail-fast or gas on an invalid index.
    function perpAssetInfo(uint32 perp) internal view returns (PerpAssetInfo memory) {
        return abi.decode(
            _staticcall(PERP_ASSET_INFO_PRECOMPILE, abi.encode(perp), PERP_ASSET_INFO_MIN_LEN, false), (PerpAssetInfo)
        );
    }

    /// @notice Reads HyperCore's own netted margin figures for `user` on `perpDexIndex`
    /// @dev Argument order is DEX FIRST, then user — the reverse of `position`.
    function accountMarginSummary(
        uint32 perpDexIndex,
        address user
    )
        internal
        view
        returns (AccountMarginSummary memory)
    {
        return abi.decode(
            _staticcall(ACCOUNT_MARGIN_SUMMARY_PRECOMPILE, abi.encode(perpDexIndex, user), MARGIN_SUMMARY_LEN, true),
            (AccountMarginSummary)
        );
    }

    /// @notice Whether HyperCore has an account for `user`
    function coreUserExists(address user) internal view returns (bool) {
        return abi.decode(_staticcall(CORE_USER_EXISTS_PRECOMPILE, abi.encode(user), WORD, true), (bool));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL
    //////////////////////////////////////////////////////////////*/

    /// @notice Single choke point for every read
    /// @dev Requires `MIN_CALLER_GAS` (else `INSUFFICIENT_GAS`), forwards `PRECOMPILE_GAS_LIMIT`, reverts
    ///      `PRECOMPILE_CALL_FAILED` when the precompile fails and `PRECOMPILE_BAD_RETURN` when the returndata
    ///      length is not `expectedLen` (`exact`) or is below it.
    /// @param precompile The precompile to call
    /// @param input Raw abi-encoded arguments (no selector)
    /// @param expectedLen Expected returndata length (exact for static tuples, lower bound for dynamic ones)
    /// @param exact Whether `expectedLen` must match exactly
    function _staticcall(
        address precompile,
        bytes memory input,
        uint256 expectedLen,
        bool exact
    )
        private
        view
        returns (bytes memory ret)
    {
        uint256 available = gasleft();
        if (available < MIN_CALLER_GAS) revert INSUFFICIENT_GAS(available, MIN_CALLER_GAS);
        bool ok;
        (ok, ret) = precompile.staticcall{ gas: PRECOMPILE_GAS_LIMIT }(input);
        if (!ok) revert PRECOMPILE_CALL_FAILED(precompile);
        if (exact ? ret.length != expectedLen : ret.length < expectedLen) {
            revert PRECOMPILE_BAD_RETURN(precompile, ret.length);
        }
    }
}
