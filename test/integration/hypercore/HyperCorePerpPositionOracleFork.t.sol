// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { HyperCorePerpPositionOracle } from "../../../src/accounting/oracles/HyperCorePerpPositionOracle.sol";
import { IHyperCorePerpSnapshot } from "../../../src/interfaces/accounting/IHyperCorePerpSnapshot.sol";
import { HyperCoreReadLib } from "../../../src/vendor/hyperliquid/HyperCoreReadLib.sol";
import { Helpers } from "../../utils/Helpers.sol";

/// @title HyperCorePerpPositionOracleFork
/// @notice Fork tests for the HyperCore perp position oracle against REAL HyperEVM mainnet (chain 999).
/// @dev What a fork can and cannot verify here:
///      - CANNOT: call the read precompiles locally. They are node logic, not EVM code: on the fork the fixed
///        addresses are code-less and a local staticcall returns empty, so the oracle fails closed. That
///        behaviour is itself asserted below.
///      - CAN: read the live precompile values through `vm.rpc("eth_call")`, assert invariants on them (never
///        exact values), and REPLAY the live wire bytes into `vm.mockCall` so the real oracle is exercised on
///        genuine HyperCore returndata. This proves the decoding and arithmetic match the live shapes.
/// @dev Runs against HYPEREVM_RPC_URL, defaulting to the public https://rpc.hyperliquid.xyz/evm. The default
///      account is an HLP strategy sub-vault with real open positions; override with HYPERCORE_FORK_ACCOUNT.
///      See `HyperCorePerpPositionOracleLiveFork` for the end-to-end variant where the oracle itself reads live
///      state through etched precompile forwarders instead of replayed mocks.
contract HyperCorePerpPositionOracleFork is Helpers {
    // NOTE: these address literals (and the small `_abs` helper below, where present) are deliberately duplicated
    // across the HyperCore test files instead of referencing `HyperCoreReadLib.*` / the oracle's helper, so each
    // suite pins the documented wire contract independently of the code under test. `HyperCoreReadLib.t.sol`
    // asserts the literals equal the library constants, which is where a moved precompile would surface.
    address internal constant WITHDRAWABLE = 0x0000000000000000000000000000000000000803;
    address internal constant MARK_PX = 0x0000000000000000000000000000000000000806;
    address internal constant ORACLE_PX = 0x0000000000000000000000000000000000000807;
    address internal constant PERP_ASSET_INFO = 0x000000000000000000000000000000000000080a;
    address internal constant ACCOUNT_MARGIN_SUMMARY = 0x000000000000000000000000000000000000080F;
    address internal constant CORE_USER_EXISTS = 0x0000000000000000000000000000000000000810;
    address internal constant POSITION2 = 0x0000000000000000000000000000000000000813;

    /// @dev HLP strategy sub-vault: the top-level HLP vault address holds no positions itself, this one holds the
    ///      actual ~170 open perps, so the replayed BTC leg is normally non-zero.
    address internal constant HLP_STRATEGY = 0x010461C14e146ac35Fe42271BDC1134EE31C703a;
    /// @dev Legacy uint16-indexed `position` precompile, kept only to prove `position2` is a faithful successor
    address internal constant POSITION_LEGACY = 0x0000000000000000000000000000000000000800;
    uint32 internal constant BTC = 0;
    uint32 internal constant ETH_PERP = 1;
    uint32 internal constant INVALID_PERP = 110_000;

    uint256 internal forkId;
    address internal account;
    HyperCorePerpPositionOracle internal oracle;

    function setUp() public {
        forkId = vm.createFork(envOr("HYPEREVM_RPC_URL", "https://rpc.hyperliquid.xyz/evm"));
        vm.selectFork(forkId);

        account = vm.envOr("HYPERCORE_FORK_ACCOUNT", HLP_STRATEGY);
        oracle = new HyperCorePerpPositionOracle();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Live read of a precompile through the node, bypassing revm.
    function _liveCall(address precompile, bytes memory input) internal returns (bytes memory) {
        string memory params =
            string.concat('[{"to":"', vm.toString(precompile), '","data":"', vm.toString(input), '"},"latest"]');
        return vm.rpc("eth_call", params);
    }

    /// @dev External self-call wrapper so a failing `vm.rpc` can be caught with `vm.expectRevert`.
    function liveCallExternal(address precompile, bytes memory input) external returns (bytes memory) {
        return _liveCall(precompile, input);
    }

    function _abs(int64 x) internal pure returns (uint256) {
        return x < 0 ? uint256(-int256(x)) : uint256(int256(x));
    }

    /*//////////////////////////////////////////////////////////////
                                  TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_PrecompilesHaveNoEvmCode_OracleFailsClosed() public {
        assertEq(block.chainid, 999);
        assertEq(POSITION2.code.length, 0);
        assertEq(PERP_ASSET_INFO.code.length, 0);

        vm.expectRevert(
            abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, PERP_ASSET_INFO, uint256(0))
        );
        oracle.getPerpPosition(account, BTC);
    }

    function test_Fork_Live_BTC_AssetInfo() public {
        bytes memory ret = _liveCall(PERP_ASSET_INFO, abi.encode(BTC));
        HyperCoreReadLib.PerpAssetInfo memory info = abi.decode(ret, (HyperCoreReadLib.PerpAssetInfo));

        assertEq(info.coin, "BTC");
        assertEq(info.szDecimals, 5);
        assertGt(info.maxLeverage, 0);
    }

    /// @dev BTC prices at 1 dp (6 - 5): sane band $10k..$10M and mark within 5% of oracle.
    function test_Fork_Live_BTC_Prices_Band() public {
        uint64 mark = abi.decode(_liveCall(MARK_PX, abi.encode(BTC)), (uint64));
        uint64 oraclePx = abi.decode(_liveCall(ORACLE_PX, abi.encode(BTC)), (uint64));

        assertGt(mark, 0);
        assertGt(oraclePx, 0);
        assertGe(mark, 100_000);
        assertLe(mark, 100_000_000);
        uint256 diff = mark > oraclePx ? mark - oraclePx : oraclePx - mark;
        assertLe(diff * 10_000 / oraclePx, 500);
    }

    function test_Fork_Live_Account() public {
        assertTrue(abi.decode(_liveCall(CORE_USER_EXISTS, abi.encode(account)), (bool)));
        assertGt(abi.decode(_liveCall(WITHDRAWABLE, abi.encode(account)), (uint64)), 0);

        HyperCoreReadLib.AccountMarginSummary memory m = abi.decode(
            _liveCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), account)), (HyperCoreReadLib.AccountMarginSummary)
        );
        assertGt(m.accountValue, 0);

        bytes memory pos = _liveCall(POSITION2, abi.encode(account, BTC));
        assertEq(pos.length, 160);
    }

    /// @dev Fetch every precompile the oracle touches for (account, BTC), replay the raw bytes into mocks, and
    ///      check the oracle reproduces the live fields and the documented notional.
    function test_Fork_LiveReplay_OracleMatchesLive() public {
        bytes memory infoRet = _liveCall(PERP_ASSET_INFO, abi.encode(BTC));
        bytes memory posRet = _liveCall(POSITION2, abi.encode(account, BTC));
        bytes memory markRet = _liveCall(MARK_PX, abi.encode(BTC));
        bytes memory oracleRet = _liveCall(ORACLE_PX, abi.encode(BTC));
        bytes memory wdRet = _liveCall(WITHDRAWABLE, abi.encode(account));
        bytes memory summaryRet = _liveCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), account));
        bytes memory existsRet = _liveCall(CORE_USER_EXISTS, abi.encode(account));

        vm.mockCall(PERP_ASSET_INFO, abi.encode(BTC), infoRet);
        vm.mockCall(POSITION2, abi.encode(account, BTC), posRet);
        vm.mockCall(MARK_PX, abi.encode(BTC), markRet);
        vm.mockCall(ORACLE_PX, abi.encode(BTC), oracleRet);
        vm.mockCall(WITHDRAWABLE, abi.encode(account), wdRet);
        vm.mockCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), account), summaryRet);
        vm.mockCall(CORE_USER_EXISTS, abi.encode(account), existsRet);

        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, perps);

        HyperCoreReadLib.Position memory live = abi.decode(posRet, (HyperCoreReadLib.Position));
        HyperCoreReadLib.AccountMarginSummary memory m;
        m = abi.decode(summaryRet, (HyperCoreReadLib.AccountMarginSummary));

        assertEq(s.coreUserExists, abi.decode(existsRet, (bool)));
        assertEq(s.perpDex, 0);
        assertEq(s.withdrawableUsd, abi.decode(wdRet, (uint64)));
        assertEq(s.accountValue, m.accountValue);
        assertEq(s.marginUsed, m.marginUsed);
        assertEq(s.ntlPos, m.ntlPos);
        assertEq(s.rawUsd, m.rawUsd);

        assertEq(s.positions.length, 1);
        IHyperCorePerpSnapshot.PerpPosition memory p = s.positions[0];
        assertEq(p.perp, BTC);
        assertEq(p.coin, "BTC");
        assertEq(p.szDecimals, 5);
        assertEq(p.szi, live.szi);
        assertEq(p.entryNtl, live.entryNtl);
        assertEq(p.isolatedRawUsd, live.isolatedRawUsd);
        assertEq(p.leverage, live.leverage);
        assertEq(p.isIsolated, live.isIsolated);
        assertEq(p.markPx, abi.decode(markRet, (uint64)));
        assertEq(p.oraclePx, abi.decode(oracleRet, (uint64)));
        assertEq(p.notionalUsd, _abs(live.szi) * uint256(p.markPx));
    }

    function test_Fork_Live_InvalidIndex_Reverts() public {
        vm.expectRevert();
        this.liveCallExternal(MARK_PX, abi.encode(INVALID_PERP));
    }

    /*//////////////////////////////////////////////////////////////
                            ADDITIONAL LIVE CHECKS
    //////////////////////////////////////////////////////////////*/

    /// @dev `position2` (uint32) returns the same leg as the legacy `position` (uint16) for the same account and
    ///      perp, so switching index width lost nothing. The two are separate `latest` reads on an actively trading
    ///      vault, so static fields are exact and live figures get a tolerance.
    function test_Fork_Live_Position2_MatchesLegacyPosition() public {
        bytes memory legacyRet = _liveCall(POSITION_LEGACY, abi.encode(account, uint16(BTC)));
        bytes memory modernRet = _liveCall(POSITION2, abi.encode(account, BTC));
        assertEq(legacyRet.length, 160);
        assertEq(modernRet.length, 160);

        HyperCoreReadLib.Position memory legacy = abi.decode(legacyRet, (HyperCoreReadLib.Position));
        HyperCoreReadLib.Position memory modern = abi.decode(modernRet, (HyperCoreReadLib.Position));
        assertEq(modern.leverage, legacy.leverage);
        assertEq(modern.isIsolated, legacy.isIsolated);
        assertTrue((modern.szi < 0) == (legacy.szi < 0) || modern.szi == 0 || legacy.szi == 0);
        if (legacy.szi != 0) assertTrue(_within(_abs(modern.szi), _abs(legacy.szi), 500)); // 5%
    }

    function _within(uint256 a, uint256 b, uint256 bps) internal pure returns (bool) {
        uint256 diff = a > b ? a - b : b - a;
        return diff * 10_000 <= b * bps;
    }

    /// @dev The wire shape of `perpAssetInfo` is struct-wrapped and round-trips through the library's struct.
    function test_Fork_Live_PerpAssetInfo_WireShape() public {
        bytes memory ret = _liveCall(PERP_ASSET_INFO, abi.encode(BTC));
        assertEq(ret.length, 256);
        assertEq(uint256(bytes32(ret)), 0x20);

        HyperCoreReadLib.PerpAssetInfo memory info = abi.decode(ret, (HyperCoreReadLib.PerpAssetInfo));
        assertEq(abi.encode(info), ret);
    }

    /// @dev ETH_PERP is perp index 1 with szDecimals 4, so its prices carry 2 decimals.
    function test_Fork_Live_ETH_AssetInfo() public {
        HyperCoreReadLib.PerpAssetInfo memory info =
            abi.decode(_liveCall(PERP_ASSET_INFO, abi.encode(ETH_PERP)), (HyperCoreReadLib.PerpAssetInfo));
        uint64 mark = abi.decode(_liveCall(MARK_PX, abi.encode(ETH_PERP)), (uint64));

        assertEq(info.coin, "ETH");
        assertEq(info.szDecimals, 4);
        // $100..$100k at 2 dp
        assertGe(mark, 10_000);
        assertLe(mark, 10_000_000);
    }

    /// @dev A fresh address HyperCore has never seen: `coreUserExists` false, every read still succeeds with
    ///      zeros, nothing reverts.
    function test_Fork_Live_FreshAddress_ZerosNoRevert() public {
        address fresh = makeAddr("never-on-hypercore");

        assertFalse(abi.decode(_liveCall(CORE_USER_EXISTS, abi.encode(fresh)), (bool)));
        assertEq(abi.decode(_liveCall(WITHDRAWABLE, abi.encode(fresh)), (uint64)), 0);

        bytes memory pos = _liveCall(POSITION2, abi.encode(fresh, BTC));
        assertEq(pos.length, 160);
        assertEq(abi.decode(pos, (HyperCoreReadLib.Position)).szi, int64(0));

        HyperCoreReadLib.AccountMarginSummary memory m = abi.decode(
            _liveCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), fresh)), (HyperCoreReadLib.AccountMarginSummary)
        );
        assertEq(m.accountValue, int64(0));
        assertEq(m.marginUsed, 0);
    }

    /// @dev Withdrawable margin can never exceed HyperCore's own account value for a solvent account. Two separate
    ///      `latest` reads, so a 1% band absorbs a mark move landing between them.
    function test_Fork_Live_Withdrawable_LeqAccountValue() public {
        uint64 withdrawable = abi.decode(_liveCall(WITHDRAWABLE, abi.encode(account)), (uint64));
        HyperCoreReadLib.AccountMarginSummary memory m = abi.decode(
            _liveCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), account)), (HyperCoreReadLib.AccountMarginSummary)
        );

        assertGt(m.accountValue, 0);
        assertLe(withdrawable, uint256(uint64(m.accountValue)) * 101 / 100);
    }

    /// @dev Two perps with a duplicate, replayed from live bytes: THREE rows, request order, per-perp decimals,
    ///      and the repeated row byte-identical to its first occurrence.
    function test_Fork_LiveReplay_TwoPerps_OneToOne() public {
        uint32[2] memory perps2 = [BTC, ETH_PERP];
        for (uint256 i; i < 2; ++i) {
            uint32 perp = perps2[i];
            vm.mockCall(PERP_ASSET_INFO, abi.encode(perp), _liveCall(PERP_ASSET_INFO, abi.encode(perp)));
            vm.mockCall(POSITION2, abi.encode(account, perp), _liveCall(POSITION2, abi.encode(account, perp)));
            vm.mockCall(MARK_PX, abi.encode(perp), _liveCall(MARK_PX, abi.encode(perp)));
            vm.mockCall(ORACLE_PX, abi.encode(perp), _liveCall(ORACLE_PX, abi.encode(perp)));
        }
        vm.mockCall(WITHDRAWABLE, abi.encode(account), _liveCall(WITHDRAWABLE, abi.encode(account)));
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(uint32(0), account),
            _liveCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), account))
        );
        vm.mockCall(CORE_USER_EXISTS, abi.encode(account), _liveCall(CORE_USER_EXISTS, abi.encode(account)));

        uint32[] memory perps = new uint32[](3);
        perps[0] = BTC;
        perps[1] = ETH_PERP;
        perps[2] = BTC;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(account, perps);

        assertTrue(s.coreUserExists);
        assertEq(s.positions.length, 3);
        assertEq(s.positions[0].perp, BTC);
        assertEq(s.positions[0].szDecimals, 5);
        assertEq(s.positions[1].perp, ETH_PERP);
        assertEq(s.positions[1].szDecimals, 4);
        assertEq(s.positions[2].perp, BTC);
        assertEq(abi.encode(s.positions[2]), abi.encode(s.positions[0]));
        for (uint256 i; i < 3; ++i) {
            assertGt(s.positions[i].markPx, 0);
            assertEq(s.positions[i].notionalUsd, _abs(s.positions[i].szi) * uint256(s.positions[i].markPx));
        }
    }

    /// @dev `perpAssetInfo` on an invalid index reverts live as well — it is a valid index gate, not just prices.
    function test_Fork_Live_InvalidIndex_AssetInfoReverts() public {
        vm.expectRevert();
        this.liveCallExternal(PERP_ASSET_INFO, abi.encode(INVALID_PERP));
    }
}
