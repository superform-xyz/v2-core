// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { HyperCorePerpPositionOracle } from "../../../../src/accounting/oracles/HyperCorePerpPositionOracle.sol";
import { IHyperCorePerpSnapshot } from "../../../../src/interfaces/accounting/IHyperCorePerpSnapshot.sol";
import { HyperCoreReadLib } from "../../../../src/vendor/hyperliquid/HyperCoreReadLib.sol";

/// @dev Stand-in for a failing precompile that burns all forwarded gas on every call.
contract GasBurnerAll {
    fallback() external {
        assembly {
            invalid()
        }
    }
}

/// @notice Unit tests for the HyperCore perp position oracle.
/// @dev The read precompiles are mocked at their fixed addresses with `vm.mockCall`, encoding EXACTLY the wire
///      shapes observed live on chain 999 (struct-wrapped `perpAssetInfo`, static tuples elsewhere, no selector).
///      Fixtures: BTC = perp 0, szDecimals 5, markPx 803870 (= $80,387.0 at 1 dp); ETH_PERP = perp 1, szDecimals 4,
///      markPx 291_234 (= $2,912.34 at 2 dp).
contract HyperCorePerpPositionOracleTest is Test {
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

    uint32 internal constant BTC = 0;
    uint8 internal constant BTC_SZ_DECIMALS = 5;
    uint64 internal constant BTC_MARK = 803_870; // $80,387.0
    uint64 internal constant BTC_ORACLE = 803_241;

    uint32 internal constant ETH_PERP = 1;
    uint8 internal constant ETH_SZ_DECIMALS = 4;
    uint64 internal constant ETH_MARK = 291_234; // $2,912.34
    uint64 internal constant ETH_ORACLE = 291_100;

    uint32 internal constant INVALID_PERP = 110_000;

    HyperCorePerpPositionOracle internal oracle;
    address internal user = makeAddr("user");

    function setUp() public {
        oracle = new HyperCorePerpPositionOracle();
        _mockAssetInfo(BTC, "BTC", BTC_SZ_DECIMALS, 40);
        _mockAssetInfo(ETH_PERP, "ETH", ETH_SZ_DECIMALS, 25);
        _mockPx(BTC, BTC_MARK, BTC_ORACLE);
        _mockPx(ETH_PERP, ETH_MARK, ETH_ORACLE);
        _mockAccount(user, true, 1000e6, 1500e6, 200e6, 80e6, 1400e6);
    }

    /*//////////////////////////////////////////////////////////////
                              MOCK HELPERS
    //////////////////////////////////////////////////////////////*/

    function _mockAssetInfo(uint32 perp, string memory coin, uint8 szDecimals, uint8 maxLeverage) internal {
        vm.mockCall(
            PERP_ASSET_INFO,
            abi.encode(perp),
            abi.encode(HyperCoreReadLib.PerpAssetInfo(coin, 56, szDecimals, maxLeverage, false))
        );
    }

    function _mockPosition(
        address account,
        uint32 perp,
        int64 szi,
        uint64 entryNtl,
        int64 isolatedRawUsd,
        uint32 leverage,
        bool isIsolated
    )
        internal
    {
        vm.mockCall(
            POSITION2,
            abi.encode(account, perp),
            abi.encode(HyperCoreReadLib.Position(szi, entryNtl, isolatedRawUsd, leverage, isIsolated))
        );
    }

    function _mockPx(uint32 perp, uint64 mark, uint64 oraclePx_) internal {
        vm.mockCall(MARK_PX, abi.encode(perp), abi.encode(mark));
        vm.mockCall(ORACLE_PX, abi.encode(perp), abi.encode(oraclePx_));
    }

    function _mockAccount(
        address account,
        bool exists,
        uint64 withdrawable,
        int64 accountValue,
        uint64 marginUsed,
        uint64 ntlPos,
        int64 rawUsd
    )
        internal
    {
        vm.mockCall(CORE_USER_EXISTS, abi.encode(account), abi.encode(exists));
        vm.mockCall(WITHDRAWABLE, abi.encode(account), abi.encode(withdrawable));
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(uint32(0), account),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(accountValue, marginUsed, ntlPos, rawUsd))
        );
    }

    /// @dev Duplicated on purpose (see the note on the address literals): the test must not lean on the oracle's
    ///      own helper to check the oracle's arithmetic.
    function _abs(int64 x) internal pure returns (uint256) {
        return x < 0 ? uint256(-int256(x)) : uint256(int256(x));
    }

    /*//////////////////////////////////////////////////////////////
                            GET PERP POSITION
    //////////////////////////////////////////////////////////////*/

    /// @dev 0.00100 BTC long at $80,387.0: notional must be $80.387 = 80_387_000 in 6-dp USD.
    function test_PerpPosition_LongBTC_DecimalsProof() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.perp, BTC);
        assertEq(p.coin, "BTC");
        assertEq(p.szDecimals, BTC_SZ_DECIMALS);
        assertEq(p.szi, int64(100));
        assertEq(p.entryNtl, 80_000_000);
        assertEq(p.isolatedRawUsd, int64(0));
        assertEq(p.leverage, 20);
        assertFalse(p.isIsolated);
        assertEq(p.markPx, BTC_MARK);
        assertEq(p.oraclePx, BTC_ORACLE);
        assertEq(p.notionalUsd, 80_387_000);
    }

    /// @dev 1.5 BTC short: notional is unsigned ($120,580.5), side stays in szi.
    function test_PerpPosition_Short_NotionalUnsignedSziSigned() public {
        _mockPosition(user, BTC, -150_000, 120_000_000_000, 0, 10, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.szi, int64(-150_000));
        assertEq(p.notionalUsd, 120_580_500_000);
    }

    /// @dev Live shape: an empty row still carries a configured leverage. No revert, zero notional.
    function test_PerpPosition_ZeroSize_LeverageStillPopulated() public {
        _mockPosition(user, BTC, 0, 0, 0, 20, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.szi, int64(0));
        assertEq(p.notionalUsd, 0);
        assertEq(p.leverage, 20);
        assertEq(p.markPx, BTC_MARK);
    }

    function test_PerpPosition_Isolated_NegativeIsolatedRawUsd() public {
        _mockPosition(user, BTC, 100, 80_000_000, -5e6, 5, true);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertTrue(p.isIsolated);
        assertEq(p.isolatedRawUsd, int64(-5e6));
        assertEq(p.leverage, 5);
    }

    function test_PerpPosition_Int64Min_NoOverflow() public {
        _mockPosition(user, BTC, type(int64).min, 0, 0, 1, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.szi, type(int64).min);
        assertEq(p.notionalUsd, uint256(2 ** 63) * uint256(BTC_MARK));
    }

    /// @dev 2.5000 ETH_PERP at $2,912.34: 25_000 * 291_234 = 7_280_850_000 = $7,280.85. No szDecimals scaling.
    function test_PerpPosition_SecondSzDecimals_ETH() public {
        _mockPosition(user, ETH_PERP, 25_000, 7_000_000_000, 0, 10, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, ETH_PERP);

        assertEq(p.coin, "ETH");
        assertEq(p.szDecimals, ETH_SZ_DECIMALS);
        assertEq(p.markPx, ETH_MARK);
        assertEq(p.notionalUsd, 7_280_850_000);
    }

    /// @dev Unknown index: perpAssetInfo reverts first, so no account read is ever attempted.
    function test_PerpPosition_Revert_InvalidIndex() public {
        vm.mockCallRevert(PERP_ASSET_INFO, abi.encode(INVALID_PERP), "");
        vm.expectCall(POSITION2, abi.encode(user, INVALID_PERP), 0);

        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getPerpPosition(user, INVALID_PERP);
    }

    function test_PerpPosition_Revert_ZeroAccount() public {
        vm.expectRevert(HyperCorePerpPositionOracle.ZERO_ADDRESS.selector);
        oracle.getPerpPosition(address(0), BTC);
    }

    /// @dev Empty returndata is the wrong-chain signature. Here the addresses carry the one-byte stub `mockCall`
    ///      etched in setUp and no mock matches, which also yields ok + empty; the truly code-less case is pinned
    ///      in HyperCoreReadLib.t.sol. Either way the oracle fails closed by name with length 0.
    function test_PerpPosition_Revert_EmptyReturndata_WrongChain() public {
        HyperCorePerpPositionOracle fresh = new HyperCorePerpPositionOracle();
        vm.clearMockedCalls();

        vm.expectRevert(
            abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, PERP_ASSET_INFO, uint256(0))
        );
        fresh.getPerpPosition(user, BTC);
    }

    /// @dev Pins the selector-less calldata and the argument order of every precompile the oracle touches.
    ///      `accountMarginSummary` is DEX FIRST, `position2` is USER FIRST.
    function test_Encodings_NoSelector_ArgOrder() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);

        vm.expectCall(CORE_USER_EXISTS, abi.encode(user));
        vm.expectCall(WITHDRAWABLE, abi.encode(user));
        vm.expectCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user));
        vm.expectCall(PERP_ASSET_INFO, abi.encode(BTC));
        vm.expectCall(POSITION2, abi.encode(user, BTC));
        vm.expectCall(MARK_PX, abi.encode(BTC));
        vm.expectCall(ORACLE_PX, abi.encode(BTC));

        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;
        oracle.getAccountSnapshot(user, perps);
    }

    /*//////////////////////////////////////////////////////////////
                           GET ACCOUNT SNAPSHOT
    //////////////////////////////////////////////////////////////*/

    function test_AccountSnapshot_Shape_TwoPerps() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, -25_000, 7_000_000_000, 0, 10, false);

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = ETH_PERP;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertTrue(s.coreUserExists);
        assertEq(s.perpDex, 0);
        assertEq(s.perpDex, oracle.PERP_DEX());
        assertEq(s.withdrawableUsd, 1000e6);
        assertEq(s.accountValue, int64(1500e6));
        assertEq(s.marginUsed, 200e6);
        assertEq(s.ntlPos, 80e6);
        assertEq(s.rawUsd, int64(1400e6));

        assertEq(s.positions.length, 2);
        assertEq(s.positions[0].perp, BTC);
        assertEq(s.positions[0].szi, int64(100));
        assertEq(s.positions[0].notionalUsd, 80_387_000);
        assertEq(s.positions[1].perp, ETH_PERP);
        assertEq(s.positions[1].szi, int64(-25_000));
        assertEq(s.positions[1].notionalUsd, 7_280_850_000);
    }

    /// @dev ONE ROW PER INPUT: duplicates are neither collapsed nor reordered; `positions[i]` is `perps[i]`.
    function test_AccountSnapshot_OneToOne_DuplicatesPreserved() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, 25_000, 7_000_000_000, 0, 10, false);

        uint32[] memory perps = new uint32[](4);
        perps[0] = BTC;
        perps[1] = BTC;
        perps[2] = ETH_PERP;
        perps[3] = BTC;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.positions.length, 4);
        for (uint256 i; i < 4; ++i) {
            assertEq(s.positions[i].perp, perps[i]);
        }
        assertEq(s.positions[0].notionalUsd, 80_387_000);
        assertEq(s.positions[1].notionalUsd, 80_387_000);
        assertEq(s.positions[2].notionalUsd, 7_280_850_000);
        assertEq(s.positions[3].notionalUsd, 80_387_000);
        // Repeated rows are byte-identical.
        assertEq(abi.encode(s.positions[0]), abi.encode(s.positions[1]));
        assertEq(abi.encode(s.positions[0]), abi.encode(s.positions[3]));
    }

    function test_AccountSnapshot_EmptyPerps_AccountFieldsOnly() public view {
        uint32[] memory perps = new uint32[](0);
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.positions.length, 0);
        assertTrue(s.coreUserExists);
        assertEq(s.withdrawableUsd, 1000e6);
        assertEq(s.accountValue, int64(1500e6));
    }

    /// @dev Live shape: a user HyperCore has never seen returns zero rows without reverting.
    function test_AccountSnapshot_NonExistentUser_ZerosAndFlagFalse() public {
        address ghost = makeAddr("ghost");
        _mockAccount(ghost, false, 0, 0, 0, 0, 0);
        _mockPosition(ghost, BTC, 0, 0, 0, 0, false);

        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(ghost, perps);

        assertFalse(s.coreUserExists);
        assertEq(s.withdrawableUsd, 0);
        assertEq(s.accountValue, int64(0));
        assertEq(s.positions.length, 1);
        assertEq(s.positions[0].szi, int64(0));
        assertEq(s.positions[0].notionalUsd, 0);
        assertEq(s.positions[0].markPx, BTC_MARK);
    }

    function test_AccountSnapshot_NegativeAccountValue_Preserved() public {
        _mockAccount(user, true, 0, -5e6, 50e6, 100e6, -7e6);

        uint32[] memory perps = new uint32[](0);
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.accountValue, int64(-5e6));
        assertEq(s.rawUsd, int64(-7e6));
        assertEq(s.marginUsed, 50e6);
    }

    /// @dev One invalid index fails the whole snapshot — no partial result.
    function test_AccountSnapshot_Revert_InvalidIndexFailsWholeCall() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        vm.mockCallRevert(PERP_ASSET_INFO, abi.encode(INVALID_PERP), "");

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = INVALID_PERP;

        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getAccountSnapshot(user, perps);
    }

    function test_AccountSnapshot_Revert_ZeroAccount() public {
        uint32[] memory perps = new uint32[](0);
        vm.expectRevert(HyperCorePerpPositionOracle.ZERO_ADDRESS.selector);
        oracle.getAccountSnapshot(address(0), perps);
    }

    /*//////////////////////////////////////////////////////////////
                         MORE EDGE CASES / INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev A delisted or halted market can report a zero mark price: the leg is returned with zero notional, no
    ///      revert, and the raw size is still visible to the consumer.
    function test_PerpPosition_ZeroMarkPrice_ZeroNotional_NoRevert() public {
        _mockPx(BTC, 0, 0);
        _mockPosition(user, BTC, -12_345, 9_000_000, 0, 20, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.markPx, 0);
        assertEq(p.notionalUsd, 0);
        assertEq(p.szi, int64(-12_345));
        assertEq(p.entryNtl, 9_000_000);
    }

    /// @dev The largest index the ABI allows is encoded verbatim to every perp-indexed precompile.
    function test_PerpPosition_MaxIndex_EncodedVerbatim() public {
        uint32 maxPerp = type(uint32).max;
        _mockAssetInfo(maxPerp, "MAX", 1, 2);
        _mockPx(maxPerp, 5, 6);
        _mockPosition(user, maxPerp, 7, 8, 9, 10, true);

        vm.expectCall(PERP_ASSET_INFO, abi.encode(maxPerp));
        vm.expectCall(POSITION2, abi.encode(user, maxPerp));
        vm.expectCall(MARK_PX, abi.encode(maxPerp));
        vm.expectCall(ORACLE_PX, abi.encode(maxPerp));

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, maxPerp);
        assertEq(p.perp, maxPerp);
        assertEq(p.coin, "MAX");
        assertEq(p.notionalUsd, 35);
    }

    /// @dev The oracle is a pure reader: no storage slot of its own is ever written, on either entrypoint.
    function test_Oracle_NeverWritesStorage() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, 25_000, 7_000_000_000, 0, 10, false);
        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = ETH_PERP;

        vm.record();
        oracle.getPerpPosition(user, BTC);
        oracle.getAccountSnapshot(user, perps);
        (bytes32[] memory reads, bytes32[] memory writes) = vm.accesses(address(oracle));

        assertEq(writes.length, 0);
        assertEq(reads.length, 0); // zero storage: not even a read
    }

    /// @dev Both entrypoints are callable through STATICCALL (true `view` semantics for on-chain consumers).
    function test_Oracle_CallableViaStaticcall() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;

        (bool ok1,) = address(oracle).staticcall(abi.encodeCall(oracle.getPerpPosition, (user, BTC)));
        (bool ok2, bytes memory ret) =
            address(oracle).staticcall(abi.encodeCall(oracle.getAccountSnapshot, (user, perps)));
        assertTrue(ok1);
        assertTrue(ok2);

        IHyperCorePerpSnapshot.AccountSnapshot memory s = abi.decode(ret, (IHyperCorePerpSnapshot.AccountSnapshot));
        assertEq(s.positions.length, 1);
        assertEq(s.positions[0].notionalUsd, 80_387_000);
    }

    /// @dev Golden function and error selectors, as bindings and consumers will match them.
    function test_Abi_FunctionAndErrorSelectors() public pure {
        assertEq(IHyperCorePerpSnapshot.getPerpPosition.selector, bytes4(keccak256("getPerpPosition(address,uint32)")));
        assertEq(
            IHyperCorePerpSnapshot.getAccountSnapshot.selector,
            bytes4(keccak256("getAccountSnapshot(address,uint32[])"))
        );
        assertEq(
            IHyperCorePerpSnapshot.getAccountSnapshotOnDex.selector,
            bytes4(keccak256("getAccountSnapshotOnDex(address,uint32,uint32[])"))
        );
        assertEq(HyperCoreReadLib.INSUFFICIENT_GAS.selector, bytes4(keccak256("INSUFFICIENT_GAS(uint256,uint256)")));
        assertEq(HyperCorePerpPositionOracle.ZERO_ADDRESS.selector, bytes4(keccak256("ZERO_ADDRESS()")));
        bytes4 callFailed = bytes4(keccak256("PRECOMPILE_CALL_FAILED(address)"));
        assertEq(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, callFailed);
        assertEq(
            HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, bytes4(keccak256("PRECOMPILE_BAD_RETURN(address,uint256)"))
        );
    }

    /// @dev A failing account-level read never reaches the per-perp reads, and a failing per-perp read never
    ///      produces a partial array: the call reverts as a whole on the FIRST bad row.
    function test_AccountSnapshot_FailsAtFirstBadRow_NoLaterReads() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, 25_000, 7_000_000_000, 0, 10, false);
        vm.mockCallRevert(PERP_ASSET_INFO, abi.encode(INVALID_PERP), "");

        uint32[] memory perps = new uint32[](3);
        perps[0] = BTC;
        perps[1] = INVALID_PERP;
        perps[2] = ETH_PERP;

        vm.expectCall(PERP_ASSET_INFO, abi.encode(ETH_PERP), 0);
        vm.expectCall(POSITION2, abi.encode(user, ETH_PERP), 0);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getAccountSnapshot(user, perps);
    }

    /// @dev Wrong-chain signature through the snapshot path too: account-level read answers empty first.
    function test_AccountSnapshot_Revert_EmptyReturndata_WrongChain() public {
        vm.clearMockedCalls();
        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;

        vm.expectRevert(
            abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_BAD_RETURN.selector, CORE_USER_EXISTS, uint256(0))
        );
        oracle.getAccountSnapshot(user, perps);
    }

    /// @dev Isolated and cross legs in one snapshot keep their own margin mode and isolated margin.
    function test_AccountSnapshot_MixedMarginModes() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, -25_000, 7_000_000_000, -3e6, 5, true);

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = ETH_PERP;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertFalse(s.positions[0].isIsolated);
        assertEq(s.positions[0].isolatedRawUsd, int64(0));
        assertTrue(s.positions[1].isIsolated);
        assertEq(s.positions[1].isolatedRawUsd, int64(-3e6));
        assertEq(s.positions[1].leverage, 5);
    }

    /*//////////////////////////////////////////////////////////////
                              GAS BEHAVIOUR
    //////////////////////////////////////////////////////////////*/

    /// @dev A gas-burning precompile hit on the SECOND perp fails the whole snapshot by name and costs at most the
    ///      successful reads plus ONE cap — pins "a reverting snapshot costs at most one cap on top".
    function test_AccountSnapshot_BurnOnSecondPerp_BoundedByOneCap() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockAssetInfo(777, "BURN", 3, 10);
        _mockPosition(user, 777, 1, 1, 0, 1, false);
        vm.etch(MARK_PX, type(GasBurnerAll).runtimeCode); // burns on ANY markPx read
        vm.clearMockedCalls();
        // re-mock everything except markPx (the burner now owns that address)
        _mockAssetInfo(BTC, "BTC", BTC_SZ_DECIMALS, 40);
        _mockAssetInfo(777, "BURN", 3, 10);
        vm.mockCall(ORACLE_PX, abi.encode(BTC), abi.encode(BTC_ORACLE));
        vm.mockCall(ORACLE_PX, abi.encode(uint32(777)), abi.encode(uint64(1)));
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, 777, 1, 1, 0, 1, false);
        _mockAccount(user, true, 1000e6, 1500e6, 200e6, 80e6, 1400e6);

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = 777;

        uint256 before = gasleft();
        (bool ok, bytes memory ret) =
            address(oracle).call{ gas: 5_000_000 }(abi.encodeCall(oracle.getAccountSnapshot, (user, perps)));
        uint256 used = before - gasleft();

        assertFalse(ok);
        assertEq(ret, abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, MARK_PX));
        // First perp's markPx read already burns: the whole call is one cap plus the account-level reads.
        assertLt(used, 700_000);
        assertGt(used, 500_000);
    }

    /// @dev The oracle's OWN per-perp overhead (mocked precompiles are near-free) stays small; the real cost is the
    ///      precompiles themselves. Loose bound so the number is documented without being brittle.
    function test_AccountSnapshot_OracleOverheadPerPerp_Bounded() public {
        uint256 n = 16;
        uint32[] memory one = new uint32[](1);
        uint32[] memory many = new uint32[](n);
        for (uint256 i; i < n; ++i) {
            uint32 perp = uint32(500 + i);
            many[i] = perp;
            _mockAssetInfo(perp, "G", 2, 10);
            _mockPx(perp, 1000, 1000);
            _mockPosition(user, perp, 10, 10_000, 0, 1, false);
        }
        one[0] = many[0];

        uint256 g1 = gasleft();
        oracle.getAccountSnapshot(user, one);
        g1 -= gasleft();
        uint256 gn = gasleft();
        oracle.getAccountSnapshot(user, many);
        gn -= gasleft();

        uint256 marginal = (gn - g1) / (n - 1);
        assertLt(marginal, 60_000, "per-perp overhead (mocked precompiles) should stay well under 60k");
    }

    /// @dev The caller-gas floor applies to the oracle's entry points too: too little gas is refused by name, not
    ///      reported as a bad market.
    function test_AccountSnapshot_InsufficientCallerGas_Named() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;

        (bool ok, bytes memory ret) =
            address(oracle).call{ gas: 300_000 }(abi.encodeCall(oracle.getAccountSnapshot, (user, perps)));

        assertFalse(ok);
        assertEq(bytes4(ret), HyperCoreReadLib.INSUFFICIENT_GAS.selector);
    }

    /// @dev One-to-one holds on the dex-aware entry point as well, duplicates included.
    function test_AccountSnapshotOnDex_OneToOne() public {
        uint32 dex = 1;
        uint32 a = 10_000;
        uint32 b = 10_001;
        _mockAssetInfo(a, "xyz:XYZ100", 4, 30);
        _mockAssetInfo(b, "xyz:TSLA", 2, 20);
        _mockPx(a, 1_234_500, 1_234_000);
        _mockPx(b, 3_955_000, 3_950_000);
        _mockPosition(user, a, 50_000, 6_172_500_000, 0, 10, false);
        _mockPosition(user, b, -100, 395_500_000, 0, 5, false);
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(dex, user),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(1e9, 1e8, 62_120_500_000, 9e8))
        );

        uint32[] memory perps = new uint32[](3);
        perps[0] = a;
        perps[1] = b;
        perps[2] = a;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshotOnDex(user, dex, perps);

        assertEq(s.positions.length, 3);
        assertEq(s.positions[0].coin, "xyz:XYZ100");
        assertEq(s.positions[1].coin, "xyz:TSLA");
        assertEq(abi.encode(s.positions[2]), abi.encode(s.positions[0]));
        assertEq(s.positions[0].notionalUsd + s.positions[1].notionalUsd, s.ntlPos); // reconciles on dex 1
    }

    /*//////////////////////////////////////////////////////////////
                        ABI SHAPE / DEX SEMANTICS
    //////////////////////////////////////////////////////////////*/

    /// @dev The dex-aware entry point reads THAT dex's margin summary (dex-first encoding) and echoes it, while
    ///      `withdrawable` stays the dex-0 figure because precompile 0x803 is dex-0 scoped.
    function test_AccountSnapshotOnDex_ReadsRequestedDexMargin() public {
        uint32 dex = 2;
        uint32 hip3 = 20_000; // flx:TSLA-style index: dex 2, market 0
        _mockAssetInfo(hip3, "flx:TSLA", 2, 10);
        _mockPx(hip3, 3_955_000, 3_950_000);
        _mockPosition(user, hip3, 1000, 39_000_000, 0, 5, false);
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(dex, user),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(77e6, 11e6, 3_955_000_000, 70e6))
        );
        vm.expectCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(dex, user));
        vm.expectCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user), 0);

        uint32[] memory perps = new uint32[](1);
        perps[0] = hip3;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshotOnDex(user, dex, perps);

        assertEq(s.perpDex, dex);
        assertEq(s.accountValue, int64(77e6));
        assertEq(s.marginUsed, 11e6);
        assertEq(s.ntlPos, 3_955_000_000);
        assertEq(s.rawUsd, int64(70e6));
        assertEq(s.withdrawableUsd, 1000e6); // dex-0 figure from setUp, unchanged by `dex`
        assertTrue(s.coreUserExists);
        assertEq(s.positions.length, 1);
        assertEq(s.positions[0].coin, "flx:TSLA");
        assertEq(s.positions[0].notionalUsd, 3_955_000_000);
        assertEq(s.positions[0].notionalUsd, s.ntlPos); // reconciles on the RIGHT dex
    }

    /// @dev The two-argument entry point is exactly the dex-0 case of the three-argument one.
    function test_AccountSnapshot_EqualsOnDexZero() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, -25_000, 7_000_000_000, 0, 10, false);
        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = ETH_PERP;

        IHyperCorePerpSnapshot.AccountSnapshot memory a = oracle.getAccountSnapshot(user, perps);
        IHyperCorePerpSnapshot.AccountSnapshot memory b = oracle.getAccountSnapshotOnDex(user, 0, perps);

        assertEq(abi.encode(a), abi.encode(b));
        assertEq(a.perpDex, oracle.PERP_DEX());
    }

    /// @dev An unknown dex fails the whole call from the margin-summary precompile, by name.
    function test_AccountSnapshotOnDex_Revert_UnknownDex() public {
        vm.mockCallRevert(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(99), user), "");
        uint32[] memory perps = new uint32[](0);

        vm.expectRevert(
            abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, ACCOUNT_MARGIN_SUMMARY)
        );
        oracle.getAccountSnapshotOnDex(user, 99, perps);
    }

    function test_AccountSnapshotOnDex_Revert_ZeroAccount() public {
        uint32[] memory perps = new uint32[](0);
        vm.expectRevert(HyperCorePerpPositionOracle.ZERO_ADDRESS.selector);
        oracle.getAccountSnapshotOnDex(address(0), 1, perps);
    }

    /// @dev Fuzz: the dex argument is passed through verbatim to the margin-summary read and echoed.
    function testFuzz_AccountSnapshotOnDex_DexPassthrough(
        uint32 dex,
        int64 av,
        uint64 mu,
        uint64 ntl,
        int64 raw
    )
        public
    {
        vm.mockCall(
            ACCOUNT_MARGIN_SUMMARY,
            abi.encode(dex, user),
            abi.encode(HyperCoreReadLib.AccountMarginSummary(av, mu, ntl, raw))
        );
        uint32[] memory perps = new uint32[](0);
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshotOnDex(user, dex, perps);
        assertEq(s.perpDex, dex);
        assertEq(s.accountValue, av);
        assertEq(s.marginUsed, mu);
        assertEq(s.ntlPos, ntl);
        assertEq(s.rawUsd, raw);
    }

    /// @dev Golden field order of the public structs, as bindings and the OMS will decode them. A reordered
    ///      field changes these bytes.
    function test_Abi_StructFieldOrder() public pure {
        IHyperCorePerpSnapshot.PerpPosition memory p = IHyperCorePerpSnapshot.PerpPosition({
            perp: 7,
            coin: "BTC",
            szDecimals: 5,
            szi: -100,
            entryNtl: 80_000_000,
            isolatedRawUsd: -5e6,
            leverage: 20,
            isIsolated: true,
            markPx: 803_870,
            oraclePx: 803_241,
            notionalUsd: 80_387_000
        });
        bytes memory expectedPosition = abi.encode(
            uint32(7),
            "BTC",
            uint8(5),
            int64(-100),
            uint64(80_000_000),
            int64(-5e6),
            uint32(20),
            true,
            uint64(803_870),
            uint64(803_241),
            uint256(80_387_000)
        );
        // A struct with a dynamic member encodes as a one-element tuple: offset word, then the tuple body.
        assertEq(abi.encode(p), abi.encodePacked(bytes32(uint256(0x20)), expectedPosition));

        IHyperCorePerpSnapshot.PerpPosition[] memory rows = new IHyperCorePerpSnapshot.PerpPosition[](1);
        rows[0] = p;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = IHyperCorePerpSnapshot.AccountSnapshot({
            coreUserExists: true,
            perpDex: 0,
            withdrawableUsd: 1000e6,
            accountValue: -1,
            marginUsed: 2,
            ntlPos: 3,
            rawUsd: -4,
            positions: rows
        });
        bytes memory expectedSnapshot =
            abi.encode(true, uint32(0), uint64(1000e6), int64(-1), uint64(2), uint64(3), int64(-4), rows);
        assertEq(abi.encode(s), abi.encodePacked(bytes32(uint256(0x20)), expectedSnapshot));
    }

    /// @dev A builder-dex (HIP-3) leg is returned with its `dex:COIN` symbol but is NOT part of the dex-0 margin
    ///      figures. Pins the documented limitation: the consumer must not reconcile such legs against `ntlPos`.
    function test_AccountSnapshot_Hip3Leg_ReturnedButNotInDexZeroMargin() public {
        uint32 hip3 = 123_456;
        _mockAssetInfo(hip3, "xyz:ABC", 2, 5);
        _mockPx(hip3, 1_000_000, 1_000_000);
        _mockPosition(user, hip3, 500, 5_000_000_000, 0, 3, false);
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        // Dex-0 margin summary says total open notional is exactly the BTC leg.
        _mockAccount(user, true, 1000e6, 1500e6, 200e6, 80_387_000, 1400e6);

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = hip3;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.perpDex, 0);
        assertEq(s.positions.length, 2);
        assertEq(s.positions[1].coin, "xyz:ABC");
        assertEq(s.positions[1].notionalUsd, 500_000_000);
        // The HIP-3 leg's notional exceeds what dex 0 reports: by design, not reconciled here.
        assertGt(s.positions[0].notionalUsd + s.positions[1].notionalUsd, s.ntlPos);
        assertEq(s.positions[0].notionalUsd, s.ntlPos);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev notional == |szi| * markPx for ANY szDecimals: the decimals cancel, so no scaling is ever applied.
    function testFuzz_Notional(int64 szi, uint64 markPx, uint8 szDecimals) public {
        uint32 perp = 7;
        _mockAssetInfo(perp, "FUZZ", szDecimals, 3);
        _mockPx(perp, markPx, markPx);
        _mockPosition(user, perp, szi, 0, 0, 1, false);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, perp);

        assertEq(p.szi, szi);
        assertEq(p.markPx, markPx);
        assertEq(p.szDecimals, szDecimals);
        assertEq(p.notionalUsd, _abs(szi) * uint256(markPx));
    }

    /*//////////////////////////////////////////////////////////////
                         ADDITIONAL EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_PerpDexConstant_IsNativeDex() public view {
        assertEq(oracle.PERP_DEX(), 0);
    }

    /// @dev (2^63 - 1) * (2^64 - 1) fits comfortably in uint256; checked arithmetic must not trip.
    function test_PerpPosition_MaxValues_NoOverflow() public {
        _mockPx(BTC, type(uint64).max, type(uint64).max);
        _mockPosition(user, BTC, type(int64).max, type(uint64).max, type(int64).max, type(uint32).max, true);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.notionalUsd, uint256(uint64(type(int64).max)) * uint256(type(uint64).max));
        assertEq(p.entryNtl, type(uint64).max);
        assertEq(p.leverage, type(uint32).max);
    }

    /// @dev A single-leg read must not touch the account-level precompiles.
    function test_PerpPosition_DoesNotReadAccountLevelPrecompiles() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);

        vm.expectCall(CORE_USER_EXISTS, abi.encode(user), 0);
        vm.expectCall(WITHDRAWABLE, abi.encode(user), 0);
        vm.expectCall(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user), 0);

        oracle.getPerpPosition(user, BTC);
    }

    /// @dev Reads are per account: two accounts on the same perp are independent rows.
    function test_PerpPosition_TwoAccounts_Isolated() public {
        address other = makeAddr("other");
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(other, BTC, -200, 160_000_000, -1e6, 3, true);

        IHyperCorePerpSnapshot.PerpPosition memory a = oracle.getPerpPosition(user, BTC);
        IHyperCorePerpSnapshot.PerpPosition memory b = oracle.getPerpPosition(other, BTC);

        assertEq(a.szi, int64(100));
        assertEq(b.szi, int64(-200));
        assertTrue(b.isIsolated);
        assertEq(b.isolatedRawUsd, int64(-1e6));
        // Same market data for both.
        assertEq(a.markPx, b.markPx);
        assertEq(a.szDecimals, b.szDecimals);
    }

    /// @dev Each precompile in the per-perp sequence fails closed with ITS address, after assetInfo passed.
    function test_PerpPosition_Revert_EachDownstreamPrecompile() public {
        // position2
        vm.mockCallRevert(POSITION2, abi.encode(user, BTC), "");
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, POSITION2));
        oracle.getPerpPosition(user, BTC);

        // markPx
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        vm.mockCallRevert(MARK_PX, abi.encode(BTC), "");
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, MARK_PX));
        oracle.getPerpPosition(user, BTC);

        // oraclePx
        vm.mockCall(MARK_PX, abi.encode(BTC), abi.encode(BTC_MARK));
        vm.mockCallRevert(ORACLE_PX, abi.encode(BTC), "");
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, ORACLE_PX));
        oracle.getPerpPosition(user, BTC);
    }

    function test_AccountSnapshot_AllDuplicates_ThreeRows() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);

        uint32[] memory perps = new uint32[](3);
        perps[0] = BTC;
        perps[1] = BTC;
        perps[2] = BTC;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.positions.length, 3);
        for (uint256 i; i < 3; ++i) {
            assertEq(s.positions[i].perp, BTC);
            assertEq(s.positions[i].notionalUsd, 80_387_000);
        }
    }

    /// @dev Every input row is read: a repeated index costs a full set of reads each time (the caller pays).
    function test_AccountSnapshot_Duplicates_ReadEveryOccurrence() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);

        vm.expectCall(PERP_ASSET_INFO, abi.encode(BTC), 3);
        vm.expectCall(POSITION2, abi.encode(user, BTC), 3);
        vm.expectCall(MARK_PX, abi.encode(BTC), 3);
        vm.expectCall(ORACLE_PX, abi.encode(BTC), 3);

        uint32[] memory perps = new uint32[](3);
        perps[0] = BTC;
        perps[1] = BTC;
        perps[2] = BTC;
        oracle.getAccountSnapshot(user, perps);
    }

    /// @dev Zero-size and open rows coexist; the zero row is never dropped.
    function test_AccountSnapshot_MixedZeroAndOpen_ZeroRowKept() public {
        _mockPosition(user, BTC, 0, 0, 0, 20, false);
        _mockPosition(user, ETH_PERP, 25_000, 7_000_000_000, 0, 10, false);

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = ETH_PERP;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.positions.length, 2);
        assertEq(s.positions[0].szi, int64(0));
        assertEq(s.positions[0].notionalUsd, 0);
        assertEq(s.positions[1].notionalUsd, 7_280_850_000);
    }

    /// @dev Account-level precompile failures surface with their own address, before any perp is read.
    function test_AccountSnapshot_Revert_AccountLevelPrecompiles() public {
        uint32[] memory perps = new uint32[](1);
        perps[0] = BTC;
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);

        vm.mockCallRevert(CORE_USER_EXISTS, abi.encode(user), "");
        vm.expectCall(PERP_ASSET_INFO, abi.encode(BTC), 0);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, CORE_USER_EXISTS));
        oracle.getAccountSnapshot(user, perps);

        vm.mockCall(CORE_USER_EXISTS, abi.encode(user), abi.encode(true));
        vm.mockCallRevert(WITHDRAWABLE, abi.encode(user), "");
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, WITHDRAWABLE));
        oracle.getAccountSnapshot(user, perps);

        vm.mockCall(WITHDRAWABLE, abi.encode(user), abi.encode(uint64(1)));
        vm.mockCallRevert(ACCOUNT_MARGIN_SUMMARY, abi.encode(uint32(0), user), "");
        vm.expectRevert(
            abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, ACCOUNT_MARGIN_SUMMARY)
        );
        oracle.getAccountSnapshot(user, perps);
    }

    /// @dev Invalid index FIRST in the list: nothing of the valid perp is read either.
    function test_AccountSnapshot_Revert_InvalidIndexFirst() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        vm.mockCallRevert(PERP_ASSET_INFO, abi.encode(INVALID_PERP), "");

        uint32[] memory perps = new uint32[](2);
        perps[0] = INVALID_PERP;
        perps[1] = BTC;

        vm.expectCall(POSITION2, abi.encode(user, BTC), 0);
        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, PERP_ASSET_INFO));
        oracle.getAccountSnapshot(user, perps);
    }

    /// @dev A price read failing on the SECOND perp fails the whole snapshot — no partial result.
    function test_AccountSnapshot_Revert_PriceFailsOnSecondPerp() public {
        _mockPosition(user, BTC, 100, 80_000_000, 0, 20, false);
        _mockPosition(user, ETH_PERP, 25_000, 7_000_000_000, 0, 10, false);
        vm.mockCallRevert(ORACLE_PX, abi.encode(ETH_PERP), "");

        uint32[] memory perps = new uint32[](2);
        perps[0] = BTC;
        perps[1] = ETH_PERP;

        vm.expectRevert(abi.encodeWithSelector(HyperCoreReadLib.PRECOMPILE_CALL_FAILED.selector, ORACLE_PX));
        oracle.getAccountSnapshot(user, perps);
    }

    /// @dev 32 distinct perps: order preserved, every row carries its own index and decimals.
    function test_AccountSnapshot_ManyPerps_OrderAndShape() public {
        uint256 n = 32;
        uint32[] memory perps = new uint32[](n);
        for (uint256 i; i < n; ++i) {
            uint32 perp = uint32(1000 + i);
            perps[i] = perp;
            _mockAssetInfo(perp, "X", uint8(i % 6), 10);
            _mockPx(perp, uint64(1000 + i), uint64(1000 + i));
            _mockPosition(user, perp, int64(int256(i)) - 16, 0, 0, 1, false);
        }

        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.positions.length, n);
        for (uint256 i; i < n; ++i) {
            assertEq(s.positions[i].perp, uint32(1000 + i));
            assertEq(s.positions[i].szDecimals, uint8(i % 6));
            assertEq(s.positions[i].markPx, uint64(1000 + i));
            assertEq(s.positions[i].notionalUsd, _abs(int64(int256(i)) - 16) * (1000 + i));
        }
    }

    /// @dev One-to-one over an arbitrary list (duplicates likely): same length, `positions[i].perp == perps[i]`,
    ///      and each row carries that perp's own data.
    function testFuzz_AccountSnapshot_OneToOne(uint32[8] memory raw, uint8 lenSeed) public {
        uint256 len = uint256(lenSeed) % 9; // 0..8
        uint32[] memory perps = new uint32[](len);
        for (uint256 i; i < len; ++i) {
            uint32 perp = raw[i];
            perps[i] = perp;
            _mockAssetInfo(perp, "F", uint8(perp % 7), 10);
            _mockPx(perp, uint64(perp) + 1, uint64(perp) + 2);
            _mockPosition(user, perp, int64(int32(perp)), 0, 0, 1, false);
        }

        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.positions.length, len);
        for (uint256 i; i < len; ++i) {
            assertEq(s.positions[i].perp, perps[i]);
            assertEq(s.positions[i].szDecimals, uint8(perps[i] % 7));
            assertEq(s.positions[i].markPx, uint64(perps[i]) + 1);
            assertEq(s.positions[i].oraclePx, uint64(perps[i]) + 2);
            assertEq(s.positions[i].szi, int64(int32(perps[i])));
        }
    }

    /// @dev A snapshot row is exactly what the single-leg read returns for the same perp.
    function testFuzz_SnapshotRow_EqualsSinglePositionRead(
        uint32 perp,
        int64 szi,
        uint64 entryNtl,
        int64 iso,
        uint32 lev,
        bool isIso,
        uint64 mark
    )
        public
    {
        _mockAssetInfo(perp, "X", 3, 10);
        _mockPx(perp, mark, mark);
        _mockPosition(user, perp, szi, entryNtl, iso, lev, isIso);

        uint32[] memory perps = new uint32[](2);
        perps[0] = perp;
        perps[1] = perp;
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);
        IHyperCorePerpSnapshot.PerpPosition memory single = oracle.getPerpPosition(user, perp);

        assertEq(abi.encode(s.positions[0]), abi.encode(single));
        assertEq(abi.encode(s.positions[1]), abi.encode(single));
    }

    /// @dev Account-level fields are passed through verbatim, sign included.
    function testFuzz_AccountSnapshot_AccountFieldsPassthrough(
        bool exists,
        uint64 withdrawable,
        int64 accountValue,
        uint64 marginUsed,
        uint64 ntlPos,
        int64 rawUsd
    )
        public
    {
        _mockAccount(user, exists, withdrawable, accountValue, marginUsed, ntlPos, rawUsd);

        uint32[] memory perps = new uint32[](0);
        IHyperCorePerpSnapshot.AccountSnapshot memory s = oracle.getAccountSnapshot(user, perps);

        assertEq(s.coreUserExists, exists);
        assertEq(s.withdrawableUsd, withdrawable);
        assertEq(s.accountValue, accountValue);
        assertEq(s.marginUsed, marginUsed);
        assertEq(s.ntlPos, ntlPos);
        assertEq(s.rawUsd, rawUsd);
    }

    /// @dev Every raw position field is echoed unchanged alongside the derived notional.
    function testFuzz_PerpPosition_RawFieldsPassthrough(
        int64 szi,
        uint64 entryNtl,
        int64 iso,
        uint32 lev,
        bool isIso,
        uint64 mark,
        uint64 oraclePx_
    )
        public
    {
        _mockPx(BTC, mark, oraclePx_);
        _mockPosition(user, BTC, szi, entryNtl, iso, lev, isIso);

        IHyperCorePerpSnapshot.PerpPosition memory p = oracle.getPerpPosition(user, BTC);

        assertEq(p.szi, szi);
        assertEq(p.entryNtl, entryNtl);
        assertEq(p.isolatedRawUsd, iso);
        assertEq(p.leverage, lev);
        assertEq(p.isIsolated, isIso);
        assertEq(p.markPx, mark);
        assertEq(p.oraclePx, oraclePx_);
        assertEq(p.notionalUsd, _abs(szi) * uint256(mark));
    }
}
