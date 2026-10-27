// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { HyperCoreReadLib } from "../../../../src/vendor/hyperliquid/HyperCoreReadLib.sol";

/// @dev Exposes the internal library readers so each can be exercised and reverted in isolation.
contract HyperCoreReadLibHarness {
    function position(address user, uint32 perp) external view returns (HyperCoreReadLib.Position memory) {
        return HyperCoreReadLib.position(user, perp);
    }

    function withdrawable(address user) external view returns (uint64) {
        return HyperCoreReadLib.withdrawable(user);
    }

    function markPx(uint32 perp) external view returns (uint64) {
        return HyperCoreReadLib.markPx(perp);
    }

    function oraclePx(uint32 perp) external view returns (uint64) {
        return HyperCoreReadLib.oraclePx(perp);
    }

    function perpAssetInfo(uint32 perp) external view returns (HyperCoreReadLib.PerpAssetInfo memory) {
        return HyperCoreReadLib.perpAssetInfo(perp);
    }

    function accountMarginSummary(
        uint32 dex,
        address user
    )
        external
        view
        returns (HyperCoreReadLib.AccountMarginSummary memory)
    {
        return HyperCoreReadLib.accountMarginSummary(dex, user);
    }

    function coreUserExists(address user) external view returns (bool) {
        return HyperCoreReadLib.coreUserExists(user);
    }
}

/// @dev Stand-in for a failing precompile: consumes every unit of gas forwarded to it, like the live one does.
contract GasBurner {
    fallback() external {
        assembly {
            invalid()
        }
    }
}

/// @dev Stand-in for an expensive-but-valid precompile: burns the forwarded gas down to ~60k doing real work
///      (keccak in a loop, so the optimizer cannot elide it), then answers one word.
contract GasHog {
    fallback() external {
        assembly {
            for { } gt(gas(), 60000) { } {
                pop(keccak256(0, 64))
            }
            mstore(0, 123)
            return(0, 32)
        }
    }
}

/// @notice Unit tests for the HyperCore read-precompile library.
/// @dev Pins (a) the documented precompile addresses, (b) the selector-less calldata of every reader, (c) the
///      decode of REAL wire bytes captured from chain 999 on 2026-10-26 (`cast call` against the public RPC),
///      and (d) that every reader fails closed by name on both a reverting and an empty-returning precompile.
contract HyperCoreReadLibTest is Test {
    address internal constant WITHDRAWABLE = 0x0000000000000000000000000000000000000803;
    address internal constant MARK_PX = 0x0000000000000000000000000000000000000806;
    address internal constant ORACLE_PX = 0x0000000000000000000000000000000000000807;
    address internal constant PERP_ASSET_INFO = 0x000000000000000000000000000000000000080a;
    address internal constant ACCOUNT_MARGIN_SUMMARY = 0x000000000000000000000000000000000000080F;
    address internal constant CORE_USER_EXISTS = 0x0000000000000000000000000000000000000810;
    address internal constant POSITION2 = 0x0000000000000000000000000000000000000813;

    /// @dev Live `perpAssetInfo(0)` return: 256 bytes, struct-wrapped (word0 = 0x20 offset), coin "BTC",
    ///      marginTableId 56, szDecimals 5, maxLeverage 40, onlyIsolated false.
    bytes internal constant LIVE_BTC_ASSET_INFO = hex"0000000000000000000000000000000000000000000000000000000000000020"
        hex"00000000000000000000000000000000000000000000000000000000000000a0"
        hex"0000000000000000000000000000000000000000000000000000000000000038"
        hex"0000000000000000000000000000000000000000000000000000000000000005"
        hex"0000000000000000000000000000000000000000000000000000000000000028"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000003"
        hex"4254430000000000000000000000000000000000000000000000000000000000";

    /// @dev Live `position2(0x...01, 0)`: 160 bytes, zero size, leverage 20 on an EMPTY row.
    bytes internal constant LIVE_EMPTY_POSITION = hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000014"
        hex"0000000000000000000000000000000000000000000000000000000000000000";

    /// @dev Live `accountMarginSummary(0, 0x...01)`: 128 bytes, accountValue 100000, marginUsed 0, ntlPos 0,
    ///      rawUsd 100000 (= $0.10 at 6 dp).
    bytes internal constant LIVE_MARGIN_SUMMARY = hex"00000000000000000000000000000000000000000000000000000000000186a0"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"0000000000000000000000000000000000000000000000000000000000000000"
        hex"00000000000000000000000000000000000000000000000000000000000186a0";

    /// @dev Live `markPx(0)` = 0xc441e = 803870 ($80,387.0 at 1 dp) and `oraclePx(0)` = 0xc4519 = 804121.
    bytes internal constant LIVE_BTC_MARK = hex"00000000000000000000000000000000000000000000000000000000000c441e";
    bytes internal constant LIVE_BTC_ORACLE = hex"00000000000000000000000000000000000000000000000000000000000c4519";

    HyperCoreReadLibHarness internal lib;
    address internal user = makeAddr("user");

    function setUp() public {
        lib = new HyperCoreReadLibHarness();
    }

    function _precompiles() internal pure returns (address[7] memory) {
        return [WITHDRAWABLE, MARK_PX, ORACLE_PX, PERP_ASSET_INFO, ACCOUNT_MARGIN_SUMMARY, CORE_USER_EXISTS, POSITION2];
    }

    /// @dev Invokes the reader bound to `precompile` with fixed arguments, through the harness.
    function _callReader(address precompile) internal view {
        if (precompile == WITHDRAWABLE) lib.withdrawable(user);
        else if (precompile == MARK_PX) lib.markPx(0);
        else if (precompile == ORACLE_PX) lib.oraclePx(0);
        else if (precompile == PERP_ASSET_INFO) lib.perpAssetInfo(0);
        else if (precompile == ACCOUNT_MARGIN_SUMMARY) lib.accountMarginSummary(0, user);
        else if (precompile == CORE_USER_EXISTS) lib.coreUserExists(user);
        else lib.position(user, 0);
    }

    /*//////////////////////////////////////////////////////////////
                               ADDRESSES
    //////////////////////////////////////////////////////////////*/

    function test_Constants_MatchDocumentedPrecompileAddresses() public pure {
        assertEq(HyperCoreReadLib.WITHDRAWABLE_PRECOMPILE, WITHDRAWABLE);
        assertEq(HyperCoreReadLib.MARK_PX_PRECOMPILE, MARK_PX);
        assertEq(HyperCoreReadLib.ORACLE_PX_PRECOMPILE, ORACLE_PX);
        assertEq(HyperCoreReadLib.PERP_ASSET_INFO_PRECOMPILE, PERP_ASSET_INFO);
        assertEq(HyperCoreReadLib.ACCOUNT_MARGIN_SUMMARY_PRECOMPILE, ACCOUNT_MARGIN_SUMMARY);
        assertEq(HyperCoreReadLib.CORE_USER_EXISTS_PRECOMPILE, CORE_USER_EXISTS);
        assertEq(HyperCoreReadLib.POSITION2_PRECOMPILE, POSITION2);
    }

    /*//////////////////////////////////////////////////////////////
                          LIVE WIRE-BYTE DECODING
    //////////////////////////////////////////////////////////////*/

    function test_Decode_LivePerpAssetInfo_StructWrapped() public {
        assertEq(LIVE_BTC_ASSET_INFO.length, 256);
        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(0)), LIVE_BTC_ASSET_INFO);

        HyperCoreReadLib.PerpAssetInfo memory info = lib.perpAssetInfo(0);

        assertEq(info.coin, "BTC");
        assertEq(info.marginTableId, 56);
        assertEq(info.szDecimals, 5);
        assertEq(info.maxLeverage, 40);
        assertFalse(info.onlyIsolated);
    }

    /// @dev The mock encoding used across the oracle tests is byte-identical to the live wire shape, so the
    ///      mocked suites cannot pass for the wrong reason.
    function test_MockEncoding_PerpAssetInfo_EqualsLiveBytes() public pure {
        bytes memory encoded = abi.encode(HyperCoreReadLib.PerpAssetInfo("BTC", 56, 5, 40, false));
        assertEq(encoded, LIVE_BTC_ASSET_INFO);
    }

    function test_Decode_LiveEmptyPosition_LeverageNonZero() public {
        assertEq(LIVE_EMPTY_POSITION.length, 160);
        vm.mockCall(POSITION2, abi.encode(user, uint32(0)), LIVE_EMPTY_POSITION);

        HyperCoreReadLib.Position memory p = lib.position(user, 0);

        assertEq(p.szi, int64(0));
        assertEq(p.entryNtl, 0);
        assertEq(p.isolatedRawUsd, int64(0));
        assertEq(p.leverage, 20);
        assertFalse(p.isIsolated);
    }

    function test_MockEncoding_Position_EqualsLiveBytes() public pure {
        assertEq(abi.encode(HyperCoreReadLib.Position(0, 0, 0, 20, false)), LIVE_EMPTY_POSITION);
    }

    function test_Decode_LiveMarginSummary() public {
        assertEq(LIVE_MARGIN_SUMMARY.length, 128);
        vm.mockCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user), LIVE_MARGIN_SUMMARY);

        HyperCoreReadLib.AccountMarginSummary memory m = lib.accountMarginSummary(0, user);

        assertEq(m.accountValue, int64(100_000));
        assertEq(m.marginUsed, 0);
        assertEq(m.ntlPos, 0);
        assertEq(m.rawUsd, int64(100_000));
    }

    function test_MockEncoding_MarginSummary_EqualsLiveBytes() public pure {
        assertEq(abi.encode(HyperCoreReadLib.AccountMarginSummary(100_000, 0, 0, 100_000)), LIVE_MARGIN_SUMMARY);
    }

    function test_Decode_LivePrices_OneDecimalForBTC() public {
        vm.mockCall(MARK_PX, abi.encode(uint32(0)), LIVE_BTC_MARK);
        vm.mockCall(ORACLE_PX, abi.encode(uint32(0)), LIVE_BTC_ORACLE);

        assertEq(lib.markPx(0), 803_870);
        assertEq(lib.oraclePx(0), 804_121);
    }

    function test_Decode_SingleWordReaders() public {
        vm.mockCall(WITHDRAWABLE, abi.encode(user), abi.encode(uint64(100_000)));
        vm.mockCall(CORE_USER_EXISTS, abi.encode(user), abi.encode(true));

        assertEq(lib.withdrawable(user), 100_000);
        assertTrue(lib.coreUserExists(user));
    }

    /// @dev Signed fields round-trip through int64 without sign loss.
    function test_Decode_NegativeSignedFields() public {
        vm.mockCall(
            POSITION2,
            abi.encode(user, uint32(3)),
            abi.encode(HyperCoreReadLib.Position(type(int64).min, 1, type(int64).min, 1, true))
        );
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(uint32(0), user),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(-1, 0, 0, type(int64).min))
        );

        HyperCoreReadLib.Position memory p = lib.position(user, 3);
        HyperCoreReadLib.AccountMarginSummary memory m = lib.accountMarginSummary(0, user);

        assertEq(p.szi, type(int64).min);
        assertEq(p.isolatedRawUsd, type(int64).min);
        assertTrue(p.isIsolated);
        assertEq(m.accountValue, int64(-1));
        assertEq(m.rawUsd, type(int64).min);
    }

    /*//////////////////////////////////////////////////////////////
                              CALLDATA SHAPE
    //////////////////////////////////////////////////////////////*/

    /// @dev Every reader sends RAW abi.encode(args) — 32-byte-aligned, no 4-byte selector — in documented order.
    function test_Calldata_SelectorlessAndOrdered() public {
        vm.mockCall(POSITION2, abi.encode(user, uint32(7)), abi.encode(HyperCoreReadLib.Position(1, 1, 0, 1, false)));
        vm.mockCall(WITHDRAWABLE, abi.encode(user), abi.encode(uint64(1)));
        vm.mockCall(MARK_PX, abi.encode(uint32(7)), abi.encode(uint64(1)));
        vm.mockCall(ORACLE_PX, abi.encode(uint32(7)), abi.encode(uint64(1)));
        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(7)), LIVE_BTC_ASSET_INFO);
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(uint32(9), user),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(0, 0, 0, 0))
        );
        vm.mockCall(CORE_USER_EXISTS, abi.encode(user), abi.encode(false));

        // 64-byte calldata: (address, uint32) — user first.
        vm.expectCall(POSITION2, abi.encode(user, uint32(7)));
        vm.expectCall(WITHDRAWABLE, abi.encode(user));
        vm.expectCall(MARK_PX, abi.encode(uint32(7)));
        vm.expectCall(ORACLE_PX, abi.encode(uint32(7)));
        vm.expectCall(PERP_ASSET_INFO, abi.encode(uint32(7)));
        // 64-byte calldata: (uint32, address) — DEX first.
        vm.expectCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(9), user));
        vm.expectCall(CORE_USER_EXISTS, abi.encode(user));

        lib.position(user, 7);
        lib.withdrawable(user);
        lib.markPx(7);
        lib.oraclePx(7);
        lib.perpAssetInfo(7);
        lib.accountMarginSummary(9, user);
        lib.coreUserExists(user);

        assertEq(abi.encode(user, uint32(7)).length, 64);
        assertEq(abi.encode(uint32(7)).length, 32);
    }

    /*//////////////////////////////////////////////////////////////
                              FAIL CLOSED
    //////////////////////////////////////////////////////////////*/

    /// @dev A reverting precompile (invalid input live) surfaces as PRECOMPILE_CALL_FAILED(thatPrecompile).
    function test_FailClosed_EveryReader_OnPrecompileRevert() public {
        address[7] memory ps = _precompiles();
        for (uint256 i; i < ps.length; ++i) {
            vm.mockCallRevert(ps[i], bytes(""), bytes(""));
            vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, ps[i]));
            _callReader(ps[i]);
        }
    }

    /// @dev No mocks: the fixed addresses are code-less, a staticcall "succeeds" with empty returndata, and
    ///      the library must still revert by name with length 0 — this is the wrong-chain signature.
    function test_FailClosed_EveryReader_OnEmptyReturndata() public {
        address[7] memory ps = _precompiles();
        for (uint256 i; i < ps.length; ++i) {
            assertEq(ps[i].code.length, 0);
            vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, ps[i], 0));
            _callReader(ps[i]);
        }
    }

    /// @dev Static returns are length-checked EXACTLY: one byte short is rejected by name, not by abi.decode.
    function test_FailClosed_ShortReturndata_Named() public {
        bytes memory short31 = new bytes(31);
        vm.mockCall(MARK_PX, abi.encode(uint32(0)), short31);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, MARK_PX, 31));
        lib.markPx(0);

        bytes memory short159 = new bytes(159);
        vm.mockCall(POSITION2, abi.encode(user, uint32(0)), short159);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, POSITION2, 159));
        lib.position(user, 0);

        bytes memory short127 = new bytes(127);
        vm.mockCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user), short127);
        vm.expectRevert(
            abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, ACCOUNT_MARGIN_SUMMARY, 127)
        );
        lib.accountMarginSummary(0, user);
    }

    /// @dev Trailing bytes on a static tuple (a future appended field) are rejected instead of silently ignored.
    function test_FailClosed_TrailingReturndata_Named() public {
        bytes memory position192 = abi.encodePacked(LIVE_EMPTY_POSITION, bytes32(uint256(7)));
        vm.mockCall(POSITION2, abi.encode(user, uint32(0)), position192);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, POSITION2, 192));
        lib.position(user, 0);

        bytes memory two64 = abi.encode(uint64(1), uint64(2));
        vm.mockCall(WITHDRAWABLE, abi.encode(user), two64);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, WITHDRAWABLE, 64));
        lib.withdrawable(user);
    }

    /// @dev `perpAssetInfo` is dynamic: below the 224-byte minimum is rejected by name; a longer coin is fine.
    function test_PerpAssetInfo_LengthLowerBound() public {
        bytes memory tooShort = new bytes(192);
        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(0)), tooShort);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, PERP_ASSET_INFO, 192));
        lib.perpAssetInfo(0);

        // Empty coin: exactly the 224-byte minimum.
        bytes memory emptyCoin = abi.encode(HyperCoreReadLib.PerpAssetInfo("", 1, 2, 3, true));
        assertEq(emptyCoin.length, 224);
        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(1)), emptyCoin);
        assertEq(lib.perpAssetInfo(1).szDecimals, 2);

        // HIP-3 style coin longer than one word.
        bytes memory longCoin =
            abi.encode(HyperCoreReadLib.PerpAssetInfo("somebuilderdex:AVERYLONGCOINNAMEXYZ", 9, 3, 10, false));
        assertGt(longCoin.length, 256);
        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(2)), longCoin);
        assertEq(lib.perpAssetInfo(2).coin, "somebuilderdex:AVERYLONGCOINNAMEXYZ");
    }

    /// @dev Correct length but dirty words (leverage > uint32, bool == 2) still revert — via abi.decode's own
    ///      validation (anonymous). Documented here so the behaviour is pinned.
    function test_FailClosed_DirtyWords_RevertAnonymously() public {
        bytes memory dirtyLeverage = abi.encode(int64(1), uint64(1), int64(0), uint256(type(uint32).max) + 1, false);
        assertEq(dirtyLeverage.length, 160);
        vm.mockCall(POSITION2, abi.encode(user, uint32(0)), dirtyLeverage);
        vm.expectRevert();
        lib.position(user, 0);

        bytes memory dirtyBool = abi.encode(uint256(2));
        vm.mockCall(CORE_USER_EXISTS, abi.encode(user), dirtyBool);
        vm.expectRevert();
        lib.coreUserExists(user);
    }

    /// @dev The per-read gas cap bounds what an all-gas-consuming precompile can burn: the caller keeps the rest
    ///      of its frame and still sees the named error. Pins the on-chain try/catch safety property.
    function test_GasCap_BoundsBurnOnPrecompileFailure() public {
        assertEq(HyperCoreReadLib.PRECOMPILE_GAS_LIMIT, 500_000);
        vm.etch(PERP_ASSET_INFO, type(GasBurner).runtimeCode);

        uint256 before = gasleft();
        (bool ok, bytes memory ret) = address(lib).call{ gas: 5_000_000 }(abi.encodeCall(lib.perpAssetInfo, (0)));
        uint256 used = before - gasleft();

        assertFalse(ok);
        assertEq(ret, abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        // Burned at most the cap plus call overhead — far below the 5M forwarded.
        assertLt(used, 600_000);
        assertGt(used, 400_000);
    }

    /// @dev Revert data from the precompile is NOT bubbled: the caller always sees the library's own error.
    function test_FailClosed_RevertDataNotBubbled() public {
        vm.mockCallRevert(MARK_PX, abi.encode(uint32(0)), abi.encodeWithSignature("Error(string)", "PrecompileError"));
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, MARK_PX));
        lib.markPx(0);
    }

    /// @dev A caller that cannot fund the cap is refused by name BEFORE the call, so a clamped frame can never make
    ///      a valid read look like an unknown index.
    function test_GasFloor_InsufficientCallerGas_Named() public {
        vm.mockCall(MARK_PX, abi.encode(uint32(0)), abi.encode(uint64(1)));

        (bool ok, bytes memory ret) = address(lib).call{ gas: 300_000 }(abi.encodeCall(lib.markPx, (0)));

        assertFalse(ok);
        assertEq(bytes4(ret), HyperCoreReadLib.INSUFFICIENT_GAS.selector);
        (uint256 available, uint256 required) = abi.decode(_slice(ret, 4), (uint256, uint256));
        assertEq(required, HyperCoreReadLib.MIN_CALLER_GAS);
        assertLt(available, required);
        assertGt(available, 200_000);
    }

    /// @dev The floor guarantees the full cap is forwardable under EIP-150 (63/64 of the remaining gas).
    function test_GasFloor_CoversCapUnderEip150() public pure {
        uint256 forwardable = HyperCoreReadLib.MIN_CALLER_GAS - HyperCoreReadLib.MIN_CALLER_GAS / 64;
        assertGe(forwardable, HyperCoreReadLib.PRECOMPILE_GAS_LIMIT);
    }

    function _slice(bytes memory data, uint256 start) internal pure returns (bytes memory out) {
        out = new bytes(data.length - start);
        for (uint256 i; i < out.length; ++i) {
            out[i] = data[start + i];
        }
    }

    /// @dev Property: for a VALID mocked read, any caller gas budget yields exactly one of two outcomes — success,
    ///      or `INSUFFICIENT_GAS` by name. Never `PRECOMPILE_CALL_FAILED`, never an anonymous OOG inside the lib.
    function testFuzz_GasFloor_ValidReadNeverMisreported(uint32 gasSeed) public {
        uint256 gas = 60_000 + (uint256(gasSeed) % 2_000_000);
        vm.mockCall(MARK_PX, abi.encode(uint32(0)), abi.encode(uint64(42)));

        (bool ok, bytes memory ret) = address(lib).call{ gas: gas }(abi.encodeCall(lib.markPx, (0)));

        if (ok) {
            assertEq(abi.decode(ret, (uint64)), 42);
            assertGe(gas, HyperCoreReadLib.MIN_CALLER_GAS); // success implies the floor was met at the call site
        } else {
            assertEq(bytes4(ret), HyperCoreReadLib.INSUFFICIENT_GAS.selector, "only the named floor error is allowed");
        }
    }

    /// @dev `coin` lengths at the 32-byte word boundary decode correctly and pass the dynamic lower bound.
    function test_PerpAssetInfo_CoinWordBoundary() public {
        string memory c32 = "abcdefghijklmnopqrstuvwxyz012345"; // exactly 32 bytes -> 256-byte return
        string memory c33 = "abcdefghijklmnopqrstuvwxyz0123456"; // 33 bytes -> 288-byte return
        bytes memory r32 = abi.encode(HyperCoreReadLib.PerpAssetInfo(c32, 1, 2, 3, false));
        bytes memory r33 = abi.encode(HyperCoreReadLib.PerpAssetInfo(c33, 1, 2, 3, false));
        assertEq(r32.length, 256);
        assertEq(r33.length, 288);

        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(5)), r32);
        vm.mockCall(PERP_ASSET_INFO, abi.encode(uint32(6)), r33);
        assertEq(lib.perpAssetInfo(5).coin, c32);
        assertEq(lib.perpAssetInfo(6).coin, c33);
    }

    /// @dev The cap is a ceiling, not a requirement: a read that legitimately uses most of it still succeeds.
    function test_GasCap_NearCapReadSucceeds() public {
        vm.etch(MARK_PX, type(GasHog).runtimeCode);

        uint256 before = gasleft();
        uint64 px = lib.markPx(0);
        uint256 used = before - gasleft();

        assertEq(px, 123);
        assertGt(used, 400_000); // the hog really consumed most of the forwarded cap
        assertLt(used, 600_000);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SingleWordReaders_RoundTrip(
        address account,
        uint32 perp,
        uint64 a,
        uint64 b,
        uint64 c,
        bool e
    )
        public
    {
        vm.mockCall(WITHDRAWABLE, abi.encode(account), abi.encode(a));
        vm.mockCall(MARK_PX, abi.encode(perp), abi.encode(b));
        vm.mockCall(ORACLE_PX, abi.encode(perp), abi.encode(c));
        vm.mockCall(CORE_USER_EXISTS, abi.encode(account), abi.encode(e));

        assertEq(lib.withdrawable(account), a);
        assertEq(lib.markPx(perp), b);
        assertEq(lib.oraclePx(perp), c);
        assertEq(lib.coreUserExists(account), e);
    }

    function testFuzz_AccountMarginSummary_RoundTrip_DexFirst(
        uint32 dex,
        address account,
        int64 av,
        uint64 mu,
        uint64 ntl,
        int64 raw
    )
        public
    {
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(dex, account),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(av, mu, ntl, raw))
        );
        vm.expectCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(dex, account));

        HyperCoreReadLib.AccountMarginSummary memory m = lib.accountMarginSummary(dex, account);
        assertEq(m.accountValue, av);
        assertEq(m.marginUsed, mu);
        assertEq(m.ntlPos, ntl);
        assertEq(m.rawUsd, raw);
    }

    /// @dev Any returndata length other than the exact static size is rejected by name, for every static reader.
    function testFuzz_StaticReaders_RejectAnyOtherLength(uint16 lenSeed) public {
        uint256 len = uint256(lenSeed) % 512;
        bytes memory blob = new bytes(len);

        if (len != 32) {
            vm.mockCall(MARK_PX, abi.encode(uint32(0)), blob);
            vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, MARK_PX, len));
            lib.markPx(0);
        }
        if (len != 160) {
            vm.mockCall(POSITION2, abi.encode(user, uint32(0)), blob);
            vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, POSITION2, len));
            lib.position(user, 0);
        }
        if (len != 128) {
            vm.mockCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user), blob);
            vm.expectRevert(
                abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, ACCOUNT_MARGIN_SUMMARY, len)
            );
            lib.accountMarginSummary(0, user);
        }
    }

    function testFuzz_Position_RoundTrip(
        address account,
        uint32 perp,
        int64 szi,
        uint64 entryNtl,
        int64 iso,
        uint32 lev,
        bool isIso
    )
        public
    {
        vm.mockCall(
            POSITION2, abi.encode(account, perp), abi.encode(HyperCoreReadLib.Position(szi, entryNtl, iso, lev, isIso))
        );
        HyperCoreReadLib.Position memory p = lib.position(account, perp);
        assertEq(p.szi, szi);
        assertEq(p.entryNtl, entryNtl);
        assertEq(p.isolatedRawUsd, iso);
        assertEq(p.leverage, lev);
        assertEq(p.isIsolated, isIso);
    }

    function testFuzz_PerpAssetInfo_RoundTrip(
        uint32 perp,
        string memory coin,
        uint32 table,
        uint8 szDec,
        uint8 maxLev,
        bool onlyIso
    )
        public
    {
        vm.mockCall(
            PERP_ASSET_INFO,
            abi.encode(perp),
            abi.encode(HyperCoreReadLib.PerpAssetInfo(coin, table, szDec, maxLev, onlyIso))
        );
        HyperCoreReadLib.PerpAssetInfo memory info = lib.perpAssetInfo(perp);
        assertEq(info.coin, coin);
        assertEq(info.marginTableId, table);
        assertEq(info.szDecimals, szDec);
        assertEq(info.maxLeverage, maxLev);
        assertEq(info.onlyIsolated, onlyIso);
    }
}
