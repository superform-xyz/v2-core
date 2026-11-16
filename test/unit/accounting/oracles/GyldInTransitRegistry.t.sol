// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { GyldInTransitRegistry } from "../../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";

/// @title GyldInTransitRegistryTest
/// @notice Roles, timelocked destinations, the account-side record rules (cap, staleness, approved pair) and
///         the reconciler-side settle rules (per lot, decrease only, loud loss) of the in-transit registry.
contract GyldInTransitRegistryTest is Test {
    using stdStorage for StdStorage;

    GyldInTransitRegistry internal reg;
    GyldBondRegistry internal bonds;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockERC20 internal otherCash;
    MockAggregator internal navFeed;

    address internal admin = address(0xA11CE);
    address internal account = address(0xACC0);
    address internal other = address(0x07E7);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);

    uint256 internal constant AGE = 14 days;
    uint256 internal constant CAP = 1000e6;

    function setUp() public {
        vm.warp(1_800_000_000);
        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        otherCash = new MockERC20("Other", "OTH", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1e8);

        bonds = new GyldBondRegistry(admin);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        bonds.registerInstrument(cfg);

        reg = new GyldInTransitRegistry(admin, address(bonds));
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _configure() internal {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), CAP);
        vm.stopPrank();
    }

    function _record(uint256 amount) internal returns (uint256 lotId) {
        vm.prank(account);
        lotId = reg.recordCashOut(address(bond), address(cash), amount);
    }

    function _recordBonds(uint256 shares) internal returns (uint256 lotId) {
        vm.prank(account);
        lotId = reg.recordBondsOut(address(bond), address(cash), shares);
    }

    function _mint(uint256 lotId, uint256 cashConsumed) internal {
        vm.prank(admin);
        reg.settleMint(lotId, cashConsumed, 1, bytes32("m"));
    }

    function _expectRole(address who, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, who, role));
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR / ROLES
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(reg.BOND_REGISTRY()), address(bonds));
        assertTrue(reg.hasRole(reg.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(reg.hasRole(reg.MANAGER_ROLE(), admin));
        assertTrue(reg.hasRole(reg.RECONCILER_ROLE(), admin));
        assertEq(reg.DESTINATION_DELAY(), 2 days);
        assertEq(reg.MAX_TRANSIT_AGE_CEILING(), 365 days);
        assertEq(reg.depositAddress(), address(0));
        assertEq(reg.maxTransitAge(), 0);
        assertEq(reg.lotCount(), 0);
    }

    function test_Constructor_RevertZero() public {
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        new GyldInTransitRegistry(address(0), address(bonds));
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        new GyldInTransitRegistry(admin, address(0));
    }

    function test_Roles_NonHoldersRevert() public {
        bytes32 manager = reg.MANAGER_ROLE();
        bytes32 reconciler = reg.RECONCILER_ROLE();
        _expectRole(other, manager);
        vm.prank(other);
        reg.setDestinations(deposit, holding);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxTransitAge(AGE);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxCashInTransit(address(bond), CAP);
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleMint(1, 1, 1, bytes32("x"));
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleLoss(1, 1, bytes32("x"));
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleCashReturn(1, 1, bytes32("x"));
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleRedemption(1, 1, 1, bytes32("x"));
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleReturn(1, 1, bytes32("x"));
    }

    /*//////////////////////////////////////////////////////////////
                               DESTINATIONS
    //////////////////////////////////////////////////////////////*/

    function test_Destinations_FirstSetImmediate_ChangeTimelocked() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        assertEq(reg.depositAddress(), deposit);
        assertEq(reg.redeemHoldingWallet(), holding);

        vm.expectRevert(GyldInTransitRegistry.DESTINATIONS_ALREADY_SET.selector);
        reg.setDestinations(address(1), address(2));

        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.executeDestinations();

        reg.proposeDestinations(address(1), address(2));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        reg.executeDestinations();
        assertEq(reg.depositAddress(), deposit, "unchanged while pending");

        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations();
        assertEq(reg.depositAddress(), address(1));
        assertEq(reg.redeemHoldingWallet(), address(2));
        (,, uint64 executeAt) = reg.pendingDestinations();
        assertEq(executeAt, 0, "pending cleared");

        reg.proposeDestinations(address(3), address(4));
        reg.cancelDestinations();
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.cancelDestinations();
        assertEq(reg.depositAddress(), address(1), "cancel keeps the live value");
        vm.stopPrank();
    }

    function test_Destinations_RevertZero() public {
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.setDestinations(address(0), holding);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.proposeDestinations(deposit, address(0));
        vm.stopPrank();
    }

    function test_MaxTransitAge_Bounds() public {
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.INVALID_AGE.selector);
        reg.setMaxTransitAge(0);
        vm.expectRevert(GyldInTransitRegistry.INVALID_AGE.selector);
        reg.setMaxTransitAge(366 days);
        reg.setMaxTransitAge(365 days);
        assertEq(reg.maxTransitAge(), 365 days);
        vm.stopPrank();
    }

    function test_MaxCashInTransit_RequiresRegisteredInstrument() public {
        vm.prank(admin);
        vm.expectRevert(GyldInTransitRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        reg.setMaxCashInTransit(address(otherCash), CAP);
    }

    /// @dev The fee haircut is per instrument, manager-only, bounded, and refused for an unregistered token.
    function test_TransitFeeBps_Bounds_And_Registered() public {
        vm.prank(account);
        vm.expectRevert();
        reg.setTransitFeeBps(address(bond), 10);
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        reg.setTransitFeeBps(address(0xBAD), 10);
        uint256 maxFee = reg.MAX_TRANSIT_FEE_BPS();
        vm.expectRevert(GyldInTransitRegistry.INVALID_FEE.selector);
        reg.setTransitFeeBps(address(bond), maxFee + 1);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.TransitFeeUpdated(address(bond), 25);
        reg.setTransitFeeBps(address(bond), 25);
        assertEq(reg.transitFeeBps(address(bond)), 25);
        reg.setTransitFeeBps(address(bond), maxFee);
        reg.setTransitFeeBps(address(bond), 0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              recordCashOut
    //////////////////////////////////////////////////////////////*/

    function test_RecordCashOut_HappyPath_OpensOneLotPerRecord() public {
        _configure();
        uint256 t0 = block.timestamp;
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.CashOutRecorded(account, address(bond), 1, address(cash), 400e6, 400e6);
        assertEq(_record(400e6), 1, "ids start at 1");
        vm.warp(t0 + 1 days);
        assertEq(_record(100e6), 2);

        GyldInTransitRegistry.Transit memory t = reg.transit(account, address(bond));
        assertEq(t.cashOut, 500e6);
        assertEq(t.oldestOpenAt, t0, "the oldest OPEN lot sets the age");
        assertEq(reg.totalCashInTransit(address(bond)), 500e6);
        assertEq(reg.cashOut(account, address(bond)), 500e6);
        assertFalse(reg.isStale(account, address(bond)));
        assertEq(reg.lotCount(), 2);

        uint256[] memory ids = reg.lotsOf(account, address(bond));
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
        (uint256 oldestId, uint64 openedAt) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, 1);
        assertEq(openedAt, t0);

        GyldInTransitRegistry.Lot memory l = reg.getLot(2);
        assertEq(l.account, account);
        assertEq(l.bondToken, address(bond));
        assertEq(uint256(l.kind), uint256(GyldInTransitRegistry.LotKind.CASH_OUT));
        assertEq(l.openedAt, t0 + 1 days);
        assertEq(l.recorded, 100e6);
        assertEq(l.open, 100e6);
        assertEq(reg.getLot(3).recorded, 0, "unissued id reads empty");
    }

    function test_RecordCashOut_CapBoundary() public {
        _configure();
        uint256 lot1 = _record(CAP);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        _record(1);
        // cap is on OUTSTANDING, not per tx: settlement frees room
        _mint(lot1, 1);
        _record(1);
    }

    function test_RecordCashOut_ZeroCapDisables() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, 1, 0));
        _record(1);
    }

    function test_RecordCashOut_Preconditions() public {
        // nothing configured: destination first
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.recordCashOut(address(bond), address(cash), 1);
        vm.prank(admin);
        reg.setDestinations(deposit, holding);
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_AGE_NOT_CONFIGURED.selector);
        reg.recordCashOut(address(bond), address(cash), 1);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        // wrong pair
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.PAIR_NOT_APPROVED.selector);
        reg.recordCashOut(address(bond), address(otherCash), 1);
        // zero amount
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.recordCashOut(address(bond), address(cash), 0);
    }

    function test_RecordCashOut_StaleRefuses_UntilTheStaleLotSettles() public {
        _configure();
        uint256 lot1 = _record(100e6);
        vm.warp(block.timestamp + AGE + 1);
        assertTrue(reg.isStale(account, address(bond)));
        assertTrue(reg.isLotStale(lot1));
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        _record(1);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 204);
        // other accounts are unaffected
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), 1);
        // settling THE stale lot re-opens the account
        vm.prank(admin);
        reg.settleMint(lot1, 100e6, 95e18, bytes32("m"));
        assertFalse(reg.isStale(account, address(bond)));
        assertFalse(reg.isLotStale(lot1), "a closed lot is never stale");
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, 0);
        _record(1);
    }

    function test_PreviewCashOut_MirrorsStrictPath() public {
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 0), 206);
        assertEq(reg.previewCashOut(account, address(bond), address(otherCash), 1), 201);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 202);
        vm.prank(admin);
        reg.setDestinations(deposit, holding);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 203);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 205, "zero cap");
        vm.prank(admin);
        reg.setMaxCashInTransit(address(bond), CAP);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), CAP), 0);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), CAP + 1), 205);
        // checkCashOut is the reverting twin
        reg.checkCashOut(account, address(bond), address(cash), CAP);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        reg.checkCashOut(account, address(bond), address(cash), CAP + 1);
    }

    /*//////////////////////////////////////////////////////////////
                              recordBondsOut
    //////////////////////////////////////////////////////////////*/

    function test_RecordBondsOut_IgnoresCapAndStaleness() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        vm.stopPrank(); // no cap set: bonds out must still work
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.BondsOutRecorded(account, address(bond), 1, address(cash), 100e18, 100e18);
        assertEq(_recordBonds(100e18), 1);
        vm.warp(block.timestamp + AGE + 1); // stale on the cash side would refuse; bonds must not
        assertTrue(reg.isStale(account, address(bond)), "a bond lot ages too");
        assertEq(_recordBonds(300e18), 2);
        GyldInTransitRegistry.Transit memory t = reg.transit(account, address(bond));
        assertEq(t.bondsOut, 400e18);
        assertEq(uint256(reg.getLot(2).kind), uint256(GyldInTransitRegistry.LotKind.BONDS_OUT));
    }

    function test_RecordBondsOut_Preconditions() public {
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.recordBondsOut(address(bond), address(cash), 1);
        assertEq(reg.previewBondsOut(address(bond), address(cash)), 302);
        assertEq(reg.previewBondsOut(address(bond), address(otherCash)), 301);
        vm.prank(admin);
        reg.setDestinations(deposit, holding);
        assertEq(reg.previewBondsOut(address(bond), address(cash)), 303);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        assertEq(reg.previewBondsOut(address(bond), address(cash)), 0);
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.PAIR_NOT_APPROVED.selector);
        reg.recordBondsOut(address(bond), address(otherCash), 1);
        vm.prank(account);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.recordBondsOut(address(bond), address(cash), 0);
    }

    /*//////////////////////////////////////////////////////////////
                           STALENESS, PER LOT
    //////////////////////////////////////////////////////////////*/

    /// @dev THE bug the aggregate clock had: a strategy with a rolling book (a new deposit every week, each one
    ///      minted within a day) never drained its entry, so it read stale `maxTransitAge` after its FIRST record
    ///      although no single order was ever late. With one lot per order it never goes stale.
    function test_Staleness_RollingBook_NeverStale() public {
        _configure();
        uint256 start = block.timestamp;
        for (uint256 week; week < 10; ++week) {
            uint256 lotId = _record(100e6);
            assertFalse(reg.isStale(account, address(bond)), "a healthy book is never stale");
            vm.warp(block.timestamp + 1 days);
            _mint(lotId, 100e6);
            // keep something open across the boundary so the aggregate NEVER drains
            uint256 overlap = _record(10e6);
            vm.warp(block.timestamp + 6 days);
            assertFalse(reg.isStale(account, address(bond)));
            _mint(overlap, 10e6);
        }
        assertGt(block.timestamp - start, AGE * 4, "well past the age, many times over");
        assertEq(reg.cashOut(account, address(bond)), 0);
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, 0);
    }

    /// @dev One stalled order ages alone: settling it un-stales the account even while younger lots stay open,
    ///      and the younger lots then age on their own clock.
    function test_Staleness_OneStalledLotAgesAlone() public {
        _configure();
        uint256 t0 = block.timestamp;
        uint256 slow = _record(100e6);
        vm.warp(t0 + 10 days);
        uint256 young = _record(200e6);
        vm.warp(t0 + AGE + 1);
        assertTrue(reg.isStale(account, address(bond)), "the 14-day-old lot is stale");
        assertTrue(reg.isLotStale(slow));
        assertFalse(reg.isLotStale(young), "the 4-day-old lot is not");

        // reconcile the slow one (cancelled at Gyld, cash came back on chain)
        vm.prank(admin);
        reg.settleCashReturn(slow, 100e6, bytes32("cancel"));
        assertFalse(reg.isStale(account, address(bond)), "only the young lot is open now");
        (uint256 oldestId, uint64 openedAt) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, young);
        assertEq(openedAt, t0 + 10 days);
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, t0 + 10 days, "the clock moved to the next lot");
        _record(1); // deposits are open again

        // the young lot ages on its own clock
        vm.warp(t0 + 10 days + AGE + 1);
        assertTrue(reg.isStale(account, address(bond)));
        assertTrue(reg.isLotStale(young));
    }

    /// @dev Settles out of order leave the head on the oldest OPEN lot; closing it skips the whole closed run.
    function test_Settle_OutOfOrder_HeadSkipsClosedRun() public {
        _configure();
        uint256 t0 = block.timestamp;
        uint256 a = _record(1e6);
        vm.warp(t0 + 1 days);
        uint256 b = _record(2e6);
        vm.warp(t0 + 2 days);
        uint256 c = _record(3e6);
        _mint(c, 3e6);
        _mint(b, 2e6);
        (uint256 oldestId,) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, a, "head stays on the oldest open lot");
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, t0);
        _mint(a, 1e6);
        (oldestId,) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, 0, "queue drained");
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, 0);
        assertEq(reg.cashOut(account, address(bond)), 0);
        // the next record starts a fresh clock
        vm.warp(t0 + 30 days);
        uint256 d = _record(5e6);
        assertFalse(reg.isStale(account, address(bond)));
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, t0 + 30 days);
        (oldestId,) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, d);
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @dev A settle is bounded by ITS lot, not by the aggregate: a partial fill cannot borrow room from another
    ///      order, and the aggregates follow the lots down.
    function test_Settle_PartialFills_BoundedByTheLot() public {
        _configure();
        uint256 lot1 = _record(600e6);
        uint256 lot2 = _record(400e6);

        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.MintSettled(account, lot1, bytes32("m"), address(bond), 500e6, 480e18, 100e6, 500e6);
        reg.settleMint(lot1, 500e6, 480e18, bytes32("m"));
        assertEq(reg.getLot(lot1).open, 100e6);
        assertEq(reg.cashOut(account, address(bond)), 500e6);
        assertEq(reg.totalCashInTransit(address(bond)), 500e6);

        // 500e6 is open in aggregate, but lot 1 only has 100e6 left
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 100e6, 101e6));
        reg.settleMint(lot1, 101e6, 1, bytes32("m"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_BONDS_RECEIVED.selector);
        reg.settleMint(lot1, 1, 0, bytes32("m"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.settleLoss(lot1, 0, bytes32("l"));

        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.TransitLoss(account, lot1, bytes32("l"), address(bond), 100e6, 0, 400e6);
        reg.settleLoss(lot1, 100e6, bytes32("l"));
        assertEq(reg.getLot(lot1).open, 0, "closed");
        (uint256 oldestId,) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, lot2, "head moved to the next lot");

        // a closed lot takes nothing more
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 0, 1));
        reg.settleMint(lot1, 1, 1, bytes32("m"));

        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.CashReturnSettled(account, lot2, bytes32("c"), address(bond), 400e6, 0, 0);
        reg.settleCashReturn(lot2, 400e6, bytes32("c"));
        vm.stopPrank();
        assertEq(reg.totalCashInTransit(address(bond)), 0);
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, 0, "drained");
    }

    function test_Settle_BondLots_RedemptionAndReturn() public {
        _configure();
        uint256 lot1 = _recordBonds(50e18);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 50e18, 51e18));
        reg.settleRedemption(lot1, 51e18, 1, bytes32("r"));
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ReturnSettled(account, lot1, bytes32("c"), address(bond), 20e18, 30e18, 30e18);
        reg.settleReturn(lot1, 20e18, bytes32("c"));
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.RedemptionSettled(account, lot1, bytes32("r"), address(bond), 30e18, 29e6, 0, 0);
        reg.settleRedemption(lot1, 30e18, 29e6, bytes32("r"));
        vm.stopPrank();
        GyldInTransitRegistry.Transit memory t = reg.transit(account, address(bond));
        assertEq(t.bondsOut, 0);
        assertEq(t.oldestOpenAt, 0, "closed");
    }

    /// @dev A settle must name a lot that exists and is of the right kind.
    function test_Settle_UnknownLot_And_KindMismatch() public {
        _configure();
        uint256 cashLot = _record(100e6);
        uint256 bondLot = _recordBonds(10e18);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_NOT_FOUND.selector, 99));
        reg.settleMint(99, 1, 1, bytes32("m"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_NOT_FOUND.selector, 0));
        reg.settleReturn(0, 1, bytes32("c"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_KIND_MISMATCH.selector, bondLot));
        reg.settleMint(bondLot, 1, 1, bytes32("m"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_KIND_MISMATCH.selector, bondLot));
        reg.settleLoss(bondLot, 1, bytes32("l"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_KIND_MISMATCH.selector, bondLot));
        reg.settleCashReturn(bondLot, 1, bytes32("c"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_KIND_MISMATCH.selector, cashLot));
        reg.settleRedemption(cashLot, 1, 1, bytes32("r"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_KIND_MISMATCH.selector, cashLot));
        reg.settleReturn(cashLot, 1, bytes32("c"));
        vm.stopPrank();
        assertEq(reg.cashOut(account, address(bond)), 100e6, "nothing moved");
        assertEq(reg.bondsOut(account, address(bond)), 10e18);
    }

    /// @dev A lot belongs to its account: settling it moves that account's aggregates and nobody else's.
    function test_Settle_LotIsBoundToItsAccount() public {
        _configure();
        uint256 mine = _record(100e6);
        vm.prank(other);
        uint256 theirs = reg.recordCashOut(address(bond), address(cash), 50e6);
        _mint(theirs, 50e6);
        assertEq(reg.cashOut(account, address(bond)), 100e6, "untouched");
        assertEq(reg.cashOut(other, address(bond)), 0);
        assertEq(reg.getLot(mine).open, 100e6);
        assertEq(reg.totalCashInTransit(address(bond)), 100e6);
    }

    /// @dev Settlements can never clear more than their lot recorded, in any interleaving.
    function testFuzz_SettleNeverExceedsLot(uint64 a, uint64 b, uint64 s1, uint64 s2) public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), type(uint256).max);
        vm.stopPrank();
        uint256 ra = bound(uint256(a), 1, 1e18);
        uint256 rb = bound(uint256(b), 1, 1e18);
        uint256 la = _record(ra);
        uint256 lb = _record(rb);
        uint256 c1 = bound(uint256(s1), 1, ra);
        _mint(la, c1);
        uint256 openA = ra - c1;
        uint256 c2 = bound(uint256(s2), 1, 1e18 * 2);
        vm.prank(admin);
        if (c2 > openA) {
            vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, openA, c2));
            reg.settleLoss(la, c2, bytes32(0));
            assertEq(reg.cashOut(account, address(bond)), openA + rb, "lot b's room is not lot a's");
        } else {
            reg.settleLoss(la, c2, bytes32(0));
            assertEq(reg.getLot(la).open, openA - c2);
            assertEq(reg.cashOut(account, address(bond)), openA - c2 + rb);
            assertEq(reg.totalCashInTransit(address(bond)), openA - c2 + rb);
        }
        assertEq(reg.getLot(lb).open, rb, "lot b untouched throughout");
    }

    function test_IsStale_UnconfiguredAgeReadsStale() public {
        vm.startPrank(admin);
        reg.setDestinations(deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), CAP);
        vm.stopPrank();
        uint256 lotId = _record(1);
        // an age cannot be set back to zero through the setter, so emulate the unconfigured state by storage
        stdstore.target(address(reg)).sig("maxTransitAge()").checked_write(uint256(0));
        assertEq(reg.maxTransitAge(), 0);
        assertTrue(reg.isStale(account, address(bond)), "an unbounded lot is never counted");
        assertTrue(reg.isLotStale(lotId));
    }
}
