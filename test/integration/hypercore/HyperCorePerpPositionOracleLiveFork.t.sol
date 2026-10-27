// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { HyperCorePerpPositionOracle } from "../../../src/accounting/oracles/HyperCorePerpPositionOracle.sol";
import { IHyperCorePerpSnapshot } from "../../../src/interfaces/accounting/IHyperCorePerpSnapshot.sol";
import { HyperCoreReadLib } from "../../../src/vendor/hyperliquid/HyperCoreReadLib.sol";
import { HyperCorePrecompileForwarderLib } from "../../utils/HyperCorePrecompileForwarder.sol";
import { Helpers } from "../../utils/Helpers.sol";

/// @title HyperCorePerpPositionOracleLiveFork
/// @notice END-TO-END fork tests: the UNMODIFIED oracle reads REAL open HyperCore positions on a HyperEVM fork.
/// @dev On a plain fork the read precompiles are code-less. Here every precompile address is `vm.etch`ed with a
///      forwarder whose fallback relays the raw calldata to the live node (`vm.rpc("eth_call")`) and returns the
///      live bytes, so the oracle's own `staticcall`s are answered by genuine HyperCore state. No `vm.mockCall`.
///      Live positions move between calls, so assertions are invariants and tolerances, never exact values.
/// @dev Default account: an HLP strategy sub-vault with ~170 open perps across the majors. Override with
///      HYPERCORE_FORK_ACCOUNT. EXCLUDED FROM CI (Makefile FLARE_FORK_TESTS): public RPC + live vault. Set
///      HYPERCORE_FORK_FULL=true to also run the ffi API cross-check and the whole-universe sweep (slow).
contract HyperCorePerpPositionOracleLiveFork is Helpers {
    // NOTE: these address literals (and the small `_abs` helper below, where present) are deliberately duplicated
    // across the HyperCore test files instead of referencing `HyperCoreReadLib.*` / the oracle's helper, so each
    // suite pins the documented wire contract independently of the code under test. `HyperCoreReadLib.t.sol`
    // asserts the literals equal the library constants, which is where a moved precompile would surface.
    address internal constant PERP_ASSET_INFO = 0x000000000000000000000000000000000000080a;
    address internal constant POSITION2 = 0x0000000000000000000000000000000000000813;

    /// @dev HLP strategy sub-vault (holds the actual positions; the top-level HLP vault address holds none)
    address internal constant HLP_STRATEGY = 0x010461C14e146ac35Fe42271BDC1134EE31C703a;
    /// @dev Fee recipient of the `xyz` builder dex (dex index 1): ~$1M of margin on dex 1, none on dex 0, no open
    ///      legs — the cleanest live proof that the dex parameter reads THAT dex's margin.
    address internal constant XYZ_FEE_RECIPIENT = 0x83FfCfB1F2ad843C474B2E28df86c721cb869d3a;
    uint32 internal constant XYZ_DEX = 1;
    uint32 internal constant BTC = 0;
    uint32 internal constant INVALID_PERP = 110_000;
    /// @dev Majors live in the lowest indices; 12 is enough for at least one open leg on any active vault.
    uint32 internal constant COVERED = 12;
    /// @dev Legs below this mark notional (6-dp USD) are treated as dust in the API cross-check.
    uint256 internal constant DUST_USD6 = 1000e6;

    uint256 internal forkId;
    address internal account;
    HyperCorePerpPositionOracle internal oracle;

    struct ApiPosition {
        string coin;
        int256 szi; // scaled to szDecimals once the coin is resolved
        string sziRaw;
        int256 positionValueUsd6; // 6-dp USD
        uint256 leverage;
        bool isolated;
    }

    function setUp() public {
        forkId = vm.createFork(envOr("HYPEREVM_RPC_URL", "https://rpc.hyperliquid.xyz/evm"));
        vm.selectFork(forkId);

        HyperCorePrecompileForwarderLib.install();
        account = vm.envOr("HYPERCORE_FORK_ACCOUNT", HLP_STRATEGY);
        oracle = new HyperCorePerpPositionOracle();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _abs(int256 x) internal pure returns (uint256) {
        return x < 0 ? uint256(-x) : uint256(x);
    }

    function _range(uint32 n) internal pure returns (uint32[] memory perps) {
        perps = new uint32[](n);
        for (uint32 i; i < n; ++i) {
            perps[i] = i;
        }
    }

    /// @dev `a` within `bps` basis points of `b` (relative to `b`).
    function _within(uint256 a, uint256 b, uint256 bps) internal pure returns (bool) {
        uint256 diff = a > b ? a - b : b - a;
        return diff * 10_000 <= b * bps;
    }

    /// @dev External self-call so a library read can be used in try/catch.
    function assetInfoExternal(uint32 perp) external view returns (HyperCoreReadLib.PerpAssetInfo memory) {
        return HyperCoreReadLib.perpAssetInfo(perp);
    }

    /// @dev Parses a decimal string like "-374026.3" into an int256 scaled by 10^decimals (truncating extra digits).
    function _parseDecimal(string memory s, uint8 decimals) internal pure returns (int256) {
        bytes memory b = bytes(s);
        bool neg;
        uint256 i;
        if (b.length > 0 && b[0] == "-") {
            neg = true;
            i = 1;
        }
        uint256 intPart;
        for (; i < b.length && b[i] != "."; ++i) {
            intPart = intPart * 10 + _digit(b[i], s);
        }
        uint256 frac;
        uint256 fracDigits;
        if (i < b.length && b[i] == ".") {
            for (++i; i < b.length && fracDigits < decimals; ++i) {
                frac = frac * 10 + _digit(b[i], s);
                ++fracDigits;
            }
        }
        for (; fracDigits < decimals; ++fracDigits) {
            frac *= 10;
        }
        int256 v = int256(intPart * 10 ** decimals + frac);
        return neg ? -v : v;
    }

    /// @dev Rejects anything that is not a plain decimal digit so an unexpected API format is diagnosable.
    function _digit(bytes1 c, string memory source) internal pure returns (uint256) {
        require(c >= "0" && c <= "9", string.concat("non-digit in API number: ", source));
        return uint8(c) - 48;
    }

    /// @dev Fetches the account's clearinghouse state from Hyperliquid's public info API (independent of the EVM).
    function _fetchApiPositions() internal returns (ApiPosition[] memory out) {
        string[] memory cmd = new string[](9);
        cmd[0] = "curl";
        cmd[1] = "-s";
        cmd[2] = "-X";
        cmd[3] = "POST";
        cmd[4] = "https://api.hyperliquid.xyz/info";
        cmd[5] = "-H";
        cmd[6] = "Content-Type: application/json";
        cmd[7] = "-d";
        cmd[8] = string.concat('{"type":"clearinghouseState","user":"', vm.toString(account), '"}');
        string memory json = string(vm.ffi(cmd));

        uint256 n;
        while (vm.keyExistsJson(json, string.concat(".assetPositions[", vm.toString(n), "]"))) {
            ++n;
        }
        out = new ApiPosition[](n);
        for (uint256 k; k < n; ++k) {
            string memory base = string.concat(".assetPositions[", vm.toString(k), "].position");
            out[k].coin = vm.parseJsonString(json, string.concat(base, ".coin"));
            out[k].sziRaw = vm.parseJsonString(json, string.concat(base, ".szi"));
            string memory pvKey = string.concat(base, ".positionValue");
            out[k].positionValueUsd6 = _parseDecimal(vm.parseJsonString(json, pvKey), 6);
            out[k].leverage = vm.parseJsonUint(json, string.concat(base, ".leverage.value"));
            out[k].isolated = keccak256(bytes(vm.parseJsonString(json, string.concat(base, ".leverage.type"))))
                == keccak256("isolated");
        }
    }

    function _findApi(ApiPosition[] memory ps, string memory coin) internal pure returns (bool found, uint256 idx) {
        bytes32 h = keccak256(bytes(coin));
        for (uint256 k; k < ps.length; ++k) {
            if (keccak256(bytes(ps[k].coin)) == h) return (true, k);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The forwarder is in place and the library's own staticcall path reaches live HyperCore.
    function test_LiveFork_ForwarderServesPrecompiles() public view {
        assertEq(block.chainid, 999);
        assertGt(POSITION2.code.length, 0);
        assertGt(PERP_ASSET_INFO.code.length, 0);

        HyperCoreReadLib.PerpAssetInfo memory info = HyperCoreReadLib.perpAssetInfo(BTC);
        assertEq(info.coin, "BTC");
        assertEq(info.szDecimals, 5);
        assertTrue(HyperCoreReadLib.coreUserExists(account));
    }

    /// @dev The oracle, unmodified and unmocked, reads the account's real BTC leg.
    function test_LiveFork_GetPerpPosition_RealBTC() public view {
        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(account, BTC);

        assertEq(p.perp, BTC);
        assertEq(p.coin, "BTC");
        assertEq(p.szDecimals, 5);
        assertGe(p.markPx, 100_000); // >= $10k at 1 dp
        assertLe(p.markPx, 100_000_000); // <= $10M
        assertTrue(_within(p.markPx, p.oraclePx, 500));
        assertEq(p.notionalUsd, _abs(p.szi) * uint256(p.markPx));
        assertGt(p.leverage, 0);

        if (p.szi != 0) {
            // Open leg: entry notional exists and is the same order of magnitude as mark notional.
            assertGt(p.entryNtl, 0);
            assertGe(p.notionalUsd * 5, p.entryNtl);
            assertLe(p.notionalUsd, uint256(p.entryNtl) * 5);
        }
    }

    /// @dev Snapshot over the majors: at least one real open leg, every row internally consistent, and the
    ///      covered notional never exceeds HyperCore's own total open notional for the account.
    function test_LiveFork_Snapshot_Majors_RealPositions() public view {
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, _range(COVERED));

        assertTrue(s.coreUserExists);
        assertEq(s.perpDex, 0);
        assertGt(s.accountValue, 0);
        assertGt(s.ntlPos, 0);
        assertLe(s.withdrawableUsd, uint64(s.accountValue));
        assertEq(s.positions.length, COVERED);

        uint256 open;
        uint256 sumNotional;
        for (uint256 i; i < COVERED; ++i) {
            IHyperCorePerpSnapshot.PerpPosition memory p = s.positions[i];
            assertEq(p.perp, uint32(i));
            assertGt(bytes(p.coin).length, 0);
            assertLe(p.szDecimals, 6);
            assertEq(p.notionalUsd, _abs(p.szi) * uint256(p.markPx));
            if (p.szi != 0) {
                ++open;
                assertGt(p.markPx, 0);
                assertGt(p.entryNtl, 0);
                assertTrue(_within(p.markPx, p.oraclePx, 1000)); // open market: mark within 10% of oracle
                sumNotional += p.notionalUsd;
            }
        }
        assertGt(open, 0);
        // Subset of the account's legs, priced at mark a few blocks apart from ntlPos: allow 2% drift.
        assertLe(sumNotional, uint256(s.ntlPos) * 102 / 100);
    }

    /// @dev One row per input on live data: five requested, five returned, in order, duplicates included.
    function test_LiveFork_OneToOne_RealData() public view {
        uint32[] memory perps = new uint32[](5);
        perps[0] = 0;
        perps[1] = 1;
        perps[2] = 0;
        perps[3] = 1;
        perps[4] = 5;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, perps);

        assertEq(s.positions.length, 5);
        for (uint256 i; i < 5; ++i) {
            assertEq(s.positions[i].perp, perps[i]);
        }
        assertEq(s.positions[0].coin, "BTC");
        assertEq(s.positions[1].coin, "ETH");
        assertEq(s.positions[1].szDecimals, 4);
        assertEq(s.positions[4].coin, "SOL");
        // Same perp requested twice: static fields identical; live figures may straddle Core states through the
        // forwarder (on-chain they could not), so prices get a 1% band and sizes must agree in side.
        _assertSameLeg(s.positions[0], s.positions[2]);
        _assertSameLeg(s.positions[1], s.positions[3]);
    }

    function _assertSameLeg(
        IHyperCorePerpSnapshot.PerpPosition memory a,
        IHyperCorePerpSnapshot.PerpPosition memory b
    )
        internal
        pure
    {
        assertEq(a.perp, b.perp);
        assertEq(a.coin, b.coin);
        assertEq(a.szDecimals, b.szDecimals);
        assertEq(a.leverage, b.leverage);
        assertEq(a.isIsolated, b.isIsolated);
        if (a.markPx != 0) assertTrue(_within(a.markPx, b.markPx, 100));
        if (a.oraclePx != 0) assertTrue(_within(a.oraclePx, b.oraclePx, 100));
        assertTrue((a.szi < 0) == (b.szi < 0) || a.szi == 0 || b.szi == 0);
        assertEq(a.notionalUsd, _abs(a.szi) * uint256(a.markPx));
        assertEq(b.notionalUsd, _abs(b.szi) * uint256(b.markPx));
    }

    /// @dev A snapshot row agrees with the single-leg read of the same perp (static fields exact; live prices and
    ///      sizes within tolerance because the two reads are seconds apart on an active vault).
    function test_LiveFork_SnapshotRow_AgreesWithSingleRead() public view {
        uint32[] memory perps = _range(4);
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, perps);

        for (uint256 i; i < 4; ++i) {
            IHyperCorePerpSnapshot.PerpPosition memory row = s.positions[i];
            IHyperCorePerpSnapshot.PerpPosition memory single = oracle.getPerpPosition(account, uint32(i));

            assertEq(row.perp, single.perp);
            assertEq(row.coin, single.coin);
            assertEq(row.szDecimals, single.szDecimals);
            assertEq(row.leverage, single.leverage);
            assertEq(row.isIsolated, single.isIsolated);
            if (row.markPx != 0) assertTrue(_within(row.markPx, single.markPx, 100)); // 1%
            assertTrue((row.szi < 0) == (single.szi < 0) || row.szi == 0 || single.szi == 0);
        }
    }

    /// @dev The dex-aware entry point against a REAL builder dex: xyz (dex 1), market 0 = `xyz:XYZ100` at index
    ///      10000. The margin summary is read for dex 1 and echoed; the leg carries the `dex:COIN` symbol.
    function test_LiveFork_SnapshotOnDex_RealHip3Market() public view {
        uint32[] memory perps = new uint32[](1);
        perps[0] = 10_000;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshotOnDex(account, 1, perps);

        assertEq(s.perpDex, 1);
        assertEq(s.positions.length, 1);
        assertEq(s.positions[0].perp, 10_000);
        assertEq(s.positions[0].coin, "xyz:XYZ100");
        assertGt(s.positions[0].markPx, 0);
        assertEq(s.positions[0].notionalUsd, _abs(s.positions[0].szi) * uint256(s.positions[0].markPx));
        // HLP strategy has no xyz margin; the figures are HyperCore's for dex 1, not dex 0's copied over.
        IHyperCorePerpSnapshot.AccountSnapshot memory dex0 = oracle.getAccountSnapshot(account, new uint32[](0));
        assertTrue(s.accountValue != dex0.accountValue || dex0.accountValue == 0);
    }

    /// @dev REAL builder-dex margin: the xyz fee recipient's account value lives on dex 1 and is invisible on
    ///      dex 0, so `getAccountSnapshotOnDex(.., 1, ..)` must report it and `getAccountSnapshot` (dex 0) must not.
    function test_LiveFork_OnDex_ReadsRealBuilderDexMargin() public view {
        uint32[] memory none = new uint32[](0);
        IHyperCorePerpSnapshot.AccountSnapshot memory onXyz =
            oracle.getAccountSnapshotOnDex(XYZ_FEE_RECIPIENT, XYZ_DEX, none);
        IHyperCorePerpSnapshot.AccountSnapshot memory onNative = oracle.getAccountSnapshot(XYZ_FEE_RECIPIENT, none);

        assertTrue(onXyz.coreUserExists);
        assertEq(onXyz.perpDex, XYZ_DEX);
        assertEq(onNative.perpDex, 0);
        assertGt(onXyz.accountValue, 1000e6); // > $1,000 of dex-1 collateral (live: ~$1.08M)
        assertGt(onXyz.accountValue, onNative.accountValue); // dex 0 holds (almost) nothing for this account
        assertEq(onXyz.ntlPos, 0); // fee recipient: no open legs
        // withdrawable is dex-0 scoped: identical on both entry points for the same account.
        assertEq(onXyz.withdrawableUsd, onNative.withdrawableUsd);
    }

    /// @dev The caller-gas floor holds through the forwarder: too little gas is refused by name; enough succeeds.
    function test_LiveFork_GasFloor_RealRead() public {
        (bool okLow, bytes memory retLow) =
            address(oracle).call{ gas: 400_000 }(abi.encodeCall(oracle.getPerpPosition, (account, BTC)));
        assertFalse(okLow);
        assertEq(bytes4(retLow), HyperCoreReadLib.INSUFFICIENT_GAS.selector);

        (bool okHigh, bytes memory retHigh) =
            address(oracle).call{ gas: 3_000_000 }(abi.encodeCall(oracle.getPerpPosition, (account, BTC)));
        assertTrue(okHigh);
        IHyperCorePerpSnapshot.PerpPosition memory p = abi.decode(retHigh, (IHyperCorePerpSnapshot.PerpPosition));
        assertEq(p.coin, "BTC");
    }

    /// @dev An API-style asset id (100000 + dex*10000 + i) is NOT a precompile index: fails closed by name.
    function test_LiveFork_ApiAssetId_IsNotAPrecompileIndex() public {
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getPerpPosition(account, 110_000);
    }

    /// @dev An unknown index fails closed through the real precompile error path (forwarder relays the error).
    function test_LiveFork_InvalidIndex_FailsClosed() public {
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getPerpPosition(account, INVALID_PERP);

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = INVALID_PERP;
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getAccountSnapshot(account, perps);
    }

    /// @dev A fresh address is a legitimate all-zero snapshot, not a revert.
    function test_LiveFork_FreshAddress_ZeroSnapshot() public {
        address fresh = makeAddr("never-on-hypercore");
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(fresh, _range(3));

        assertFalse(s.coreUserExists);
        assertEq(s.withdrawableUsd, 0);
        assertEq(s.accountValue, int64(0));
        assertEq(s.ntlPos, 0);
        assertEq(s.positions.length, 3);
        for (uint256 i; i < 3; ++i) {
            assertEq(s.positions[i].szi, int64(0));
            assertEq(s.positions[i].notionalUsd, 0);
            assertGt(s.positions[i].markPx, 0); // market data is account-independent
        }
    }

    /// @dev Independent source of truth: Hyperliquid's public info API. For each covered perp, the oracle's size,
    ///      side, leverage, margin mode and mark notional must agree with the API's `clearinghouseState`
    ///      (tolerances absorb the seconds between the two reads on a live vault).
    function test_LiveFork_MatchesHyperliquidInfoApi() public {
        if (!envOr("HYPERCORE_FORK_FULL", false)) vm.skip(true);

        ApiPosition[] memory api = _fetchApiPositions();
        assertGt(api.length, 0);

        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, _range(COVERED));

        uint256 matched;
        for (uint256 i; i < COVERED; ++i) {
            IHyperCorePerpSnapshot.PerpPosition memory p = s.positions[i];
            string memory coin = p.coin;
            (bool found, uint256 k) = _findApi(api, coin);

            if (!found) {
                // API lists only open positions: the oracle must agree the leg is flat — unless it is dust that
                // was opened in the seconds between the two reads.
                assertLt(p.notionalUsd, DUST_USD6, string.concat(coin, ": oracle open, API flat"));
                continue;
            }
            // Dust legs on an active vault flip side within seconds (observed live on BNB); skip them.
            if (_abs(api[k].positionValueUsd6) < DUST_USD6) continue;

            int256 apiSzi = _parseDecimal(api[k].sziRaw, p.szDecimals);
            assertTrue((apiSzi < 0) == (p.szi < 0), string.concat(coin, ": side mismatch"));
            assertTrue(_within(_abs(p.szi), _abs(apiSzi), 1500), string.concat(coin, ": size mismatch > 15%"));
            assertTrue(
                _within(p.notionalUsd, uint256(api[k].positionValueUsd6), 1500),
                string.concat(coin, ": notional mismatch > 15%")
            );
            assertEq(p.leverage, api[k].leverage, string.concat(coin, ": leverage"));
            assertEq(p.isIsolated, api[k].isolated, string.concat(coin, ": margin mode"));
            ++matched;
        }
        assertGt(matched, 0);
    }

    /// @dev Opt-in (HYPERCORE_FORK_FULL=true): sweep the ENTIRE perp universe and reconcile the summed mark
    ///      notional against HyperCore's own `ntlPos`. ~1k live RPC reads; too slow for the default run.
    function test_LiveFork_FullUniverse_NotionalReconcilesWithCore() public {
        if (!envOr("HYPERCORE_FORK_FULL", false)) vm.skip(true);

        // Discover the universe size: indices are contiguous and the first unknown one reverts.
        uint32 n;
        for (; n < 2000; ++n) {
            try this.assetInfoExternal(n) { }
            catch {
                break;
            }
        }
        assertGt(n, 100);

        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, _range(n));
        assertEq(s.positions.length, n);

        uint256 sumNotional;
        uint256 open;
        for (uint256 i; i < n; ++i) {
            if (s.positions[i].szi != 0) {
                ++open;
                sumNotional += s.positions[i].notionalUsd;
            }
        }
        assertGt(open, 0);
        // Full coverage: summed mark notional equals HyperCore's ntlPos up to price drift during the sweep.
        assertTrue(_within(sumNotional, uint256(s.ntlPos), 300));
    }
}
