// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

import { GyldInTransitRegistry } from "../../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldDeliveryReceiver } from "../../../../src/accounting/oracles/GyldDeliveryReceiver.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { ConfigureGyldInTransitRegistry } from "../../../../script/ConfigureGyldInTransitRegistry.s.sol";

/// @title GyldInTransitRegistryTest
/// @notice Roles, timelocked destinations, the account-side record rules (cap, staleness, approved pair) and
///         the reconciler-side settle rules (per lot, decrease only, swept from the strategy's delivery receiver,
///         tied to the live NAV; losses only through the MANAGER's timelocked, provisionally recognised manual
///         settle) of the in-transit registry.
contract GyldInTransitRegistryTest is Test {
    using stdStorage for StdStorage;

    GyldInTransitRegistry internal reg;
    GyldBondRegistry internal bonds;
    GyldBondYieldSourceOracle internal oracle;

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
    uint256 internal constant GLOBAL_CAP = 3 * CAP; // instrument-wide, across strategies

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
        // 5% entry premium / exit discount: the NAV tie on settles tolerates fills within these bounds
        cfg.maxEntryPremiumBps = 500;
        cfg.maxExitDiscountBps = 500;
        vm.prank(admin);
        bonds.registerInstrument(cfg);

        reg = new GyldInTransitRegistry(admin, address(bonds));
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bonds), address(reg));
        vm.prank(admin);
        reg.setValuationOracle(address(oracle));
    }

    /// @dev The strategy's mailbox: everything Gyld "delivers" in these tests is minted here, never to the account.
    function _recv(address acct) internal view returns (address) {
        return address(reg.receiverOf(acct));
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _configure() internal {
        vm.startPrank(admin);
        reg.setDestinations(account, deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), CAP);
        reg.setMaxTotalCashInTransit(address(bond), GLOBAL_CAP);
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

    uint256 internal refNonce;

    function _ref() internal returns (bytes32) {
        return bytes32(++refNonce);
    }

    /// @dev A mint settle sweeps bonds out of the RECEIVER: simulate Gyld minting them there at NAV 1.00 (6-dec
    ///      cash -> 18-dec bonds), then acknowledge.
    function _mint(uint256 lotId, uint256 cashConsumed) internal {
        uint256 bondsOut_ = cashConsumed * 1e12;
        bond.mint(_recv(reg.getLot(lotId).account), bondsOut_);
        _freshNav();
        vm.prank(admin);
        reg.settleMint(lotId, cashConsumed, bondsOut_, _ref());
    }

    /// @dev The NAV tie needs a fresh feed: re-stamp the mock after the time warps these tests do
    function _freshNav() internal {
        navFeed.setUpdatedAt(block.timestamp);
    }

    /// @dev The loss path: MANAGER proposes, waits out the delay, executes.
    function _loss(uint256 lotId, uint256 amount) internal {
        vm.startPrank(admin);
        reg.proposeManualSettle(lotId, amount, _ref());
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lotId);
        vm.stopPrank();
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
        (address dep, address hold) = reg.destinationsOf(account);
        assertEq(dep, address(0));
        assertEq(hold, address(0));
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
        reg.setDestinations(account, deposit, holding);
        _expectRole(other, manager);
        vm.prank(other);
        reg.proposeDestinations(account, deposit, holding);
        _expectRole(other, manager);
        vm.prank(other);
        reg.executeDestinations(account);
        _expectRole(other, manager);
        vm.prank(other);
        reg.cancelDestinations(account);
        _expectRole(other, manager);
        vm.prank(other);
        reg.cancelManualSettle(1);
        _expectRole(other, manager);
        vm.prank(other);
        reg.proposeValuationOracle(address(oracle));
        _expectRole(other, manager);
        vm.prank(other);
        reg.executeValuationOracle();
        _expectRole(other, manager);
        vm.prank(other);
        reg.cancelValuationOracle();
        _expectRole(other, manager);
        vm.prank(other);
        reg.rescueFromReceiver(account, address(bond), 1);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxTransitAge(AGE);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxCashInTransit(address(bond), CAP);
        _expectRole(other, manager);
        vm.prank(other);
        reg.setMaxTotalCashInTransit(address(bond), CAP);
        _expectRole(other, reconciler);
        vm.prank(other);
        reg.settleMint(1, 1, 1, bytes32("x"));
        _expectRole(other, manager);
        vm.prank(other);
        reg.proposeManualSettle(1, 1, bytes32("x"));
        _expectRole(other, manager);
        vm.prank(other);
        reg.executeManualSettle(1);
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
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.DestinationsSet(account, deposit, holding);
        reg.setDestinations(account, deposit, holding);
        assertEq(reg.depositAddressOf(account), deposit);
        assertEq(reg.redeemHoldingWalletOf(account), holding);

        vm.expectRevert(GyldInTransitRegistry.DESTINATIONS_ALREADY_SET.selector);
        reg.setDestinations(account, address(1), address(2));

        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.executeDestinations(account);

        reg.proposeDestinations(account, address(1), address(2));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        reg.executeDestinations(account);
        assertEq(reg.depositAddressOf(account), deposit, "unchanged while pending");

        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(account);
        assertEq(reg.depositAddressOf(account), address(1));
        assertEq(reg.redeemHoldingWalletOf(account), address(2));
        (,, uint64 executeAt) = reg.pendingDestinations(account);
        assertEq(executeAt, 0, "pending cleared");

        reg.proposeDestinations(account, address(3), address(4));
        reg.cancelDestinations(account);
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.cancelDestinations(account);
        assertEq(reg.depositAddressOf(account), address(1), "cancel keeps the live value");
        vm.stopPrank();
    }

    function test_Destinations_RevertZero() public {
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.setDestinations(account, address(0), holding);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.setDestinations(address(0), deposit, holding);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        reg.proposeDestinations(account, deposit, address(0));
        vm.stopPrank();
    }

    /// @dev Destinations are per strategy. A second strategy has none until the manager sets its own pair, so it
    ///      can neither deposit nor redeem, and configuring it never touches the first one. One deposit address per
    ///      strategy or one pooled account a second strategy needs its own Gyld account (a shared deposit address is
    /// refused, see test_Segregation_OneDepositAddressPerStrategy): the second case is simply the same pair on every
    /// strategy.
    function test_Destinations_PerStrategy_UnconfiguredStrategyIsRefused() public {
        _configure();
        _record(1); // the configured strategy works
        assertEq(reg.previewCashOut(other, address(bond), address(cash), 1), 202, "no deposit address for other");
        assertEq(reg.previewBondsOut(other, address(bond), address(cash)), 302, "no holding wallet for other");
        vm.prank(other);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.recordCashOut(address(bond), address(cash), 1);
        vm.prank(other);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.recordBondsOut(address(bond), address(cash), 1);
        vm.expectRevert(GyldInTransitRegistry.DESTINATION_NOT_SET.selector);
        reg.checkBondsOut(other, address(bond), address(cash));

        // its own pair (a sub-account at Gyld), or the same pair (one pooled account): both are just config
        vm.prank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), 1);
        assertEq(reg.getLot(2).destination, address(0xD2), "other's lot went to other's address");
        assertEq(reg.getLot(1).destination, deposit, "the first strategy's lot is untouched");
        assertEq(reg.depositAddressOf(account), deposit);
        // a pending change on one strategy is invisible to the other
        vm.prank(admin);
        reg.proposeDestinations(other, address(0xD3), address(0x43));
        (,, uint64 at) = reg.pendingDestinations(account);
        assertEq(at, 0);
    }

    /// @dev A lot keeps the destination it was sent to. A rotation after the fact changes where NEW lots go and
    ///      never re-labels an open one, so reconciliation of the old lot still points at the old address.
    function test_Lot_SnapshotsDestination_AcrossRotation() public {
        _configure();
        uint256 before = _record(100e6);
        uint256 beforeBonds = _recordBonds(5e18);
        vm.startPrank(admin);
        reg.proposeDestinations(account, address(0xD2), address(0x42));
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(account);
        vm.stopPrank();
        uint256 after_ = _record(50e6);
        uint256 afterBonds = _recordBonds(1e18);
        assertEq(reg.getLot(before).destination, deposit, "old cash lot keeps the old deposit address");
        assertEq(reg.getLot(beforeBonds).destination, holding, "old bond lot keeps the old holding wallet");
        assertEq(reg.getLot(after_).destination, address(0xD2), "new cash lot uses the new address");
        assertEq(reg.getLot(afterBonds).destination, address(0x42));
        // settling the old lot still works and refers to the old lot only
        _mint(before, 100e6);
        assertEq(reg.getLot(before).open, 0);
        assertEq(reg.getLot(after_).open, 50e6);
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
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        reg.setMaxCashInTransit(address(otherCash), CAP);
        vm.expectRevert(GyldInTransitRegistry.INSTRUMENT_NOT_REGISTERED.selector);
        reg.setMaxTotalCashInTransit(address(otherCash), CAP);
        vm.stopPrank();
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
        assertEq(l.destination, deposit, "snapshotted at record time");
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
        reg.setDestinations(account, deposit, holding);
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
        reg.setDestinations(account, deposit, holding);
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
        vm.prank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), 1);
        // settling THE stale lot re-opens the account (the bonds have to be there first)
        bond.mint(_recv(account), 96e18); // floor at 5% premium: 100 / 1.05 = 95.24
        _freshNav();
        vm.prank(admin);
        reg.settleMint(lot1, 100e6, 96e18, bytes32("m"));
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
        reg.setDestinations(account, deposit, holding);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 203);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 205, "zero cap");
        vm.prank(admin);
        reg.setMaxCashInTransit(address(bond), CAP);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 207, "zero instrument-wide cap");
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.GLOBAL_CAP_EXCEEDED.selector, 1, 0));
        reg.checkCashOut(account, address(bond), address(cash), 1);
        vm.prank(admin);
        reg.setMaxTotalCashInTransit(address(bond), GLOBAL_CAP);
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
        reg.setDestinations(account, deposit, holding);
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
        assertEq(reg.previewBondsOut(account, address(bond), address(cash)), 302);
        assertEq(reg.previewBondsOut(account, address(bond), address(otherCash)), 301);
        vm.prank(admin);
        reg.setDestinations(account, deposit, holding);
        assertEq(reg.previewBondsOut(account, address(bond), address(cash)), 303);
        vm.prank(admin);
        reg.setMaxTransitAge(AGE);
        assertEq(reg.previewBondsOut(account, address(bond), address(cash)), 0);
        reg.checkBondsOut(account, address(bond), address(cash));
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
        cash.mint(_recv(account), 100e6);
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

        bond.mint(_recv(account), 480e18); // Gyld minted, to the receiver
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.MintSettled(account, lot1, bytes32("m"), address(bond), 500e6, 480e18, 100e6, 500e6);
        reg.settleMint(lot1, 500e6, 480e18, bytes32("m"));
        assertEq(reg.getLot(lot1).open, 100e6);
        assertEq(bond.balanceOf(account), 480e18, "swept into the strategy by the settle");
        assertEq(bond.balanceOf(_recv(account)), 0, "receiver drained");
        assertEq(reg.cashOut(account, address(bond)), 500e6);
        assertEq(reg.totalCashInTransit(address(bond)), 500e6);

        // 500e6 is open in aggregate, but lot 1 only has 100e6 left
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 100e6, 101e6));
        reg.settleMint(lot1, 101e6, 1, bytes32("m2"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_BONDS_RECEIVED.selector);
        reg.settleMint(lot1, 1, 0, bytes32("m2"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.proposeManualSettle(lot1, 0, bytes32("l"));

        // the rest never minted: a LOSS, which only the manager can book, after the delay
        reg.proposeManualSettle(lot1, 100e6, bytes32("l"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSettled(
            account, lot1, bytes32("l"), address(bond), GyldInTransitRegistry.LotKind.CASH_OUT, 100e6, 0, 400e6
        );
        reg.executeManualSettle(lot1);
        assertEq(reg.getLot(lot1).open, 0, "closed");
        (uint256 oldestId,) = reg.oldestOpenLot(account, address(bond));
        assertEq(oldestId, lot2, "head moved to the next lot");

        // a closed lot takes nothing more
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 0, 1));
        reg.settleMint(lot1, 1, 1, bytes32("m3"));
        vm.stopPrank();

        cash.mint(_recv(account), 400e6); // Gyld sent the cancelled deposit back, to the receiver
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.CashReturnSettled(account, lot2, bytes32("c"), address(bond), 400e6, 0, 0);
        reg.settleCashReturn(lot2, 400e6, bytes32("c"));
        assertEq(reg.totalCashInTransit(address(bond)), 0);
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, 0, "drained");
    }

    function test_Settle_BondLots_RedemptionAndReturn() public {
        _configure();
        uint256 lot1 = _recordBonds(50e18);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 50e18, 51e18));
        reg.settleRedemption(lot1, 51e18, 1, bytes32("r"));
        vm.prank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_CASH_RETURNED.selector);
        reg.settleRedemption(lot1, 1e18, 0, bytes32("r"));
        bond.mint(_recv(account), 20e18); // Gyld returned 20 bonds from the holding wallet, to the receiver
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ReturnSettled(account, lot1, bytes32("c"), address(bond), 20e18, 30e18, 30e18);
        reg.settleReturn(lot1, 20e18, bytes32("c"));
        cash.mint(_recv(account), 29e6); // the payout landed in the receiver
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.RedemptionSettled(account, lot1, bytes32("r"), address(bond), 30e18, 29e6, 0, 0);
        reg.settleRedemption(lot1, 30e18, 29e6, bytes32("r"));
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
        vm.prank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
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
        reg.setDestinations(account, deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), type(uint256).max);
        reg.setMaxTotalCashInTransit(address(bond), type(uint256).max);
        vm.stopPrank();
        uint256 ra = bound(uint256(a), 1, 1e18);
        uint256 rb = bound(uint256(b), 1, 1e18);
        uint256 la = _record(ra);
        uint256 lb = _record(rb);
        uint256 c1 = bound(uint256(s1), 1, ra);
        _mint(la, c1);
        uint256 openA = ra - c1;
        uint256 c2 = bound(uint256(s2), 1, 1e18 * 2);
        if (c2 > openA) {
            vm.prank(admin);
            vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, openA, c2));
            reg.proposeManualSettle(la, c2, bytes32("z"));
            assertEq(reg.cashOut(account, address(bond)), openA + rb, "lot b's room is not lot a's");
        } else {
            _loss(la, c2);
            assertEq(reg.getLot(la).open, openA - c2);
            assertEq(reg.cashOut(account, address(bond)), openA - c2 + rb);
            assertEq(reg.totalCashInTransit(address(bond)), openA - c2 + rb);
        }
        assertEq(reg.getLot(lb).open, rb, "lot b untouched throughout");
    }

    function test_IsStale_UnconfiguredAgeReadsStale() public {
        vm.startPrank(admin);
        reg.setDestinations(account, deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(bond), CAP);
        reg.setMaxTotalCashInTransit(address(bond), GLOBAL_CAP);
        vm.stopPrank();
        uint256 lotId = _record(1);
        // an age cannot be set back to zero through the setter, so emulate the unconfigured state by storage
        stdstore.target(address(reg)).sig("maxTransitAge()").checked_write(uint256(0));
        assertEq(reg.maxTransitAge(), 0);
        assertTrue(reg.isStale(account, address(bond)), "an unbounded lot is never counted");
        assertTrue(reg.isLotStale(lotId));
    }

    /*//////////////////////////////////////////////////////////////
                         MORE: DESTINATIONS AND ROLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A second proposal replaces the first; execute is one-shot; cancel leaves nothing to execute.
    function test_Destinations_ProposeOverrides_ExecuteOnce_CancelClears() public {
        _configure();
        vm.startPrank(admin);
        reg.proposeDestinations(account, address(1), address(2));
        reg.proposeDestinations(account, address(3), address(4));
        (address pd, address ph, uint64 at) = reg.pendingDestinations(account);
        assertEq(pd, address(3));
        assertEq(ph, address(4));
        assertEq(at, block.timestamp + reg.DESTINATION_DELAY(), "clock restarts with the new proposal");
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(account);
        assertEq(reg.depositAddressOf(account), address(3), "the LAST proposal wins");
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.executeDestinations(account);
        reg.proposeDestinations(account, address(5), address(6));
        reg.cancelDestinations(account);
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.executeDestinations(account);
        assertEq(reg.depositAddressOf(account), address(3), "cancel keeps the live pair");
        vm.stopPrank();
    }

    /// @dev A strategy that was never set can still be configured through the timelocked path; afterwards the
    ///      immediate first-set path is closed for it.
    function test_Destinations_TimelockedPathAlsoWorksForAnUnsetStrategy() public {
        vm.startPrank(admin);
        reg.proposeDestinations(other, deposit, holding);
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(other);
        assertEq(reg.depositAddressOf(other), deposit);
        vm.expectRevert(GyldInTransitRegistry.DESTINATIONS_ALREADY_SET.selector);
        reg.setDestinations(other, deposit, holding);
        vm.stopPrank();
    }

    /// @dev The two roles do not overlap: a reconciler cannot configure, a manager cannot settle.
    function test_Roles_ReconcilerCannotConfigure_ManagerCannotSettle() public {
        _configure();
        uint256 lotId = _record(10e6);
        address reconciler = address(0x5E77);
        address manager = address(0x3A4A);
        vm.startPrank(admin);
        reg.grantRole(reg.RECONCILER_ROLE(), reconciler);
        reg.grantRole(reg.MANAGER_ROLE(), manager);
        vm.stopPrank();
        bytes32 managerRole = reg.MANAGER_ROLE();
        bytes32 reconcilerRole = reg.RECONCILER_ROLE();

        _expectRole(reconciler, managerRole);
        vm.prank(reconciler);
        reg.setMaxCashInTransit(address(bond), 1);
        _expectRole(reconciler, managerRole);
        vm.prank(reconciler);
        reg.setTransitFeeBps(address(bond), 1);
        _expectRole(reconciler, managerRole);
        vm.prank(reconciler);
        reg.proposeDestinations(account, address(1), address(2));

        _expectRole(manager, reconcilerRole);
        vm.prank(manager);
        reg.settleMint(lotId, 1, 1, bytes32(0));
        _expectRole(manager, reconcilerRole);
        vm.prank(manager);
        reg.settleCashReturn(lotId, 1, bytes32(0));

        // each role works for what it is for
        vm.prank(manager);
        reg.setMaxCashInTransit(address(bond), CAP * 2);
        bond.mint(_recv(account), 10e18);
        vm.prank(reconciler);
        reg.settleMint(lotId, 10e6, 10e18, bytes32("ok"));
        assertEq(reg.getLot(lotId).open, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         MORE: SETTLES, CAP, PREVIEWS
    //////////////////////////////////////////////////////////////*/

    /// @dev A cancelled deposit whose cash came back frees exactly its share of the cap, and nothing else does.
    function test_SettleCashReturn_FreesTheCap_EmitsAndCloses() public {
        _configure();
        uint256 lot1 = _record(CAP - 1);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        _record(2);
        // a bond lot does not touch the cash cap
        _recordBonds(1e18);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        _record(2);
        cash.mint(_recv(account), CAP - 1);
        vm.prank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.CashReturnSettled(account, lot1, bytes32("c"), address(bond), CAP - 1, 0, 0);
        reg.settleCashReturn(lot1, CAP - 1, bytes32("c"));
        assertEq(reg.totalCashInTransit(address(bond)), 0);
        assertEq(reg.getLot(lot1).open, 0, "closed");
        _record(CAP); // the whole cap is available again
        assertEq(reg.bondsOut(account, address(bond)), 1e18, "the bond lot is untouched");
    }

    /// @dev Preview codes are ordered like the strict path: a stale lot reports 204 before the cap would report 205.
    function test_PreviewCashOut_StaleWinsOverCap() public {
        _configure();
        _record(CAP);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 205);
        vm.warp(block.timestamp + AGE + 1);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 204, "stale reported first");
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        reg.checkCashOut(account, address(bond), address(cash), 1);
    }

    /// @dev A partial settle of the head lot keeps the head (and the clock) where it is; only closing it moves on.
    function test_OldestOpenAt_UnchangedByPartialSettleOfHead() public {
        _configure();
        uint256 t0 = block.timestamp;
        uint256 a = _record(100e6);
        vm.warp(t0 + 1 days);
        uint256 b = _record(100e6);
        _mint(a, 40e6);
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, t0, "partial settle keeps the head");
        (uint256 id,) = reg.oldestOpenLot(account, address(bond));
        assertEq(id, a);
        _mint(a, 60e6);
        assertEq(reg.transit(account, address(bond)).oldestOpenAt, t0 + 1 days, "closing it moves the clock");
        (id,) = reg.oldestOpenLot(account, address(bond));
        assertEq(id, b);
    }

    /// @dev Lot ids are global; each (account, instrument) pair sees only its own, in order.
    function test_Lots_IdsGlobal_QueuesPerPair() public {
        _configure();
        MockERC20 bond2 = new MockERC20("Gyld Bond 2", "GB2", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond2);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setMaxCashInTransit(address(bond2), CAP);
        reg.setMaxTotalCashInTransit(address(bond2), GLOBAL_CAP);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.stopPrank();

        uint256 l1 = _record(1e6); // account / bond
        vm.prank(account);
        uint256 l2 = reg.recordCashOut(address(bond2), address(cash), 2e6); // account / bond2
        vm.prank(other);
        uint256 l3 = reg.recordCashOut(address(bond), address(cash), 3e6); // other / bond
        uint256 l4 = _record(4e6); // account / bond
        assertEq(l1, 1);
        assertEq(l2, 2);
        assertEq(l3, 3);
        assertEq(l4, 4);
        uint256[] memory q = reg.lotsOf(account, address(bond));
        assertEq(q.length, 2);
        assertEq(q[0], 1);
        assertEq(q[1], 4);
        assertEq(reg.lotsOf(account, address(bond2)).length, 1);
        assertEq(reg.lotsOf(other, address(bond)).length, 1);
        assertEq(reg.cashOut(account, address(bond)), 5e6);
        assertEq(reg.cashOut(account, address(bond2)), 2e6);
        assertEq(reg.totalCashInTransit(address(bond)), 8e6, "per instrument, across accounts");
        assertEq(reg.totalCashInTransit(address(bond2)), 2e6);
        // staleness is per pair too: age only the bond2 lot's clock? all share a clock, so settle bond lots and check
        vm.warp(block.timestamp + AGE + 1);
        assertTrue(reg.isStale(account, address(bond2)));
        bond2.mint(_recv(account), 2e18);
        _freshNav();
        vm.prank(admin);
        reg.settleMint(l2, 2e6, 2e18, bytes32("l2"));
        assertFalse(reg.isStale(account, address(bond2)), "bond2 pair settled");
        assertTrue(reg.isStale(account, address(bond)), "bond pair still has its old lots");
    }

    /// @dev Every record emits its lot id; the ids a caller sees match the registry's counter.
    function test_Records_EmitSequentialLotIds() public {
        _configure();
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.CashOutRecorded(account, address(bond), 1, address(cash), 5e6, 5e6);
        _record(5e6);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.BondsOutRecorded(account, address(bond), 2, address(cash), 7e18, 7e18);
        _recordBonds(7e18);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.CashOutRecorded(account, address(bond), 3, address(cash), 1e6, 6e6);
        _record(1e6);
        assertEq(reg.lotCount(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                   DELIVERY CHECKS, apiRef, MANUAL SETTLE
    //////////////////////////////////////////////////////////////*/

    /// @dev One Gyld reference settles once, across lots and kinds; a reverted settle does not consume it.
    function test_ApiRef_UsedOnce() public {
        _configure();
        uint256 a = _record(10e6);
        uint256 b = _record(10e6);
        bond.mint(_recv(account), 20e18);
        vm.startPrank(admin);
        reg.settleMint(a, 10e6, 10e18, bytes32("req-1"));
        assertTrue(reg.apiRefUsed(bytes32("req-1")));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.API_REF_REUSED.selector, bytes32("req-1")));
        reg.settleMint(b, 10e6, 10e18, bytes32("req-1"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.API_REF_REUSED.selector, bytes32("req-1")));
        reg.proposeManualSettle(b, 10e6, bytes32("req-1"));
        reg.settleMint(b, 10e6, 10e18, bytes32("req-2"));
        vm.stopPrank();
        assertEq(reg.cashOut(account, address(bond)), 0);
    }

    /// @dev The manual path: manager-only, one pending per lot, timelocked, cancellable, bounded by the lot, and
    ///      the only way to shrink a lot without the asset arriving.
    function test_ManualSettle_Lifecycle() public {
        _configure();
        uint256 lot = _record(100e6);
        uint256 bondLot = _recordBonds(5e18);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOT_NOT_FOUND.selector, 99));
        reg.proposeManualSettle(99, 1, bytes32("x"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 100e6, 100e6 + 1));
        reg.proposeManualSettle(lot, 100e6 + 1, bytes32("x"));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.executeManualSettle(lot);

        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSettleProposed(
            account, lot, bytes32("loss"), 40e6, block.timestamp + reg.MANUAL_SETTLE_DELAY()
        );
        reg.proposeManualSettle(lot, 40e6, bytes32("loss"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.MANUAL_SETTLE_PENDING.selector, lot));
        reg.proposeManualSettle(lot, 1, bytes32("other"));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        reg.executeManualSettle(lot);
        assertEq(reg.getLot(lot).open, 100e6, "the lot itself does not move while pending");
        assertEq(reg.transit(account, address(bond)).cashOut, 100e6, "gross position unchanged");
        assertEq(reg.transitNet(account, address(bond)).cashOut, 60e6, "net position already carries the write-down");
        assertEq(reg.totalCashInTransitNet(address(bond)), 60e6);
        assertTrue(reg.apiRefUsed(bytes32("loss")), "the reference is reserved at propose");
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.API_REF_REUSED.selector, bytes32("loss")));
        reg.proposeManualSettle(bondLot, 1, bytes32("loss"));

        // cancel restores the value and releases the reference, then re-propose and execute
        reg.cancelManualSettle(lot);
        assertEq(reg.transitNet(account, address(bond)).cashOut, 100e6, "cancel restores the net position");
        assertFalse(reg.apiRefUsed(bytes32("loss")), "released");
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        reg.cancelManualSettle(lot);
        reg.proposeManualSettle(lot, 40e6, bytes32("loss"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSettled(
            account, lot, bytes32("loss"), address(bond), GyldInTransitRegistry.LotKind.CASH_OUT, 40e6, 60e6, 60e6
        );
        reg.executeManualSettle(lot);
        assertEq(reg.cashOut(account, address(bond)), 60e6);
        assertEq(reg.totalCashInTransit(address(bond)), 60e6);
        assertEq(reg.transitNet(account, address(bond)).cashOut, 60e6, "net == gross once executed");
        assertTrue(reg.apiRefUsed(bytes32("loss")));

        // a bond lot too (e.g. bonds burnt at Gyld with nothing paid out)
        reg.proposeManualSettle(bondLot, 5e18, bytes32("default"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(bondLot);
        assertEq(reg.bondsOut(account, address(bond)), 0);
        assertEq(reg.getLot(bondLot).open, 0);
        vm.stopPrank();
        // the reconciler has no loss path at all
        vm.prank(address(0x5E77));
        vm.expectRevert();
        reg.proposeManualSettle(lot, 1, bytes32("z"));
    }

    /// @dev The pause trigger: true while any OPEN lot of the pair has a manual settle pending, false once it is
    ///      executed or cancelled, and never for another pair or a closed lot.
    function test_HasPendingManualSettle_TracksOpenLotsOnly() public {
        _configure();
        uint256 a = _record(10e6);
        uint256 b = _record(20e6);
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        vm.startPrank(admin);
        reg.proposeManualSettle(b, 5e6, bytes32("x"));
        assertTrue(reg.hasPendingManualSettle(account, address(bond)));
        assertFalse(reg.hasPendingManualSettle(other, address(bond)), "another account is unaffected");
        reg.cancelManualSettle(b);
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        reg.proposeManualSettle(a, 10e6, bytes32("y"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(a);
        vm.stopPrank();
        assertFalse(reg.hasPendingManualSettle(account, address(bond)), "executed: nothing pending");
        assertEq(reg.getLot(a).open, 0);
    }

    /*//////////////////////////////////////////////////////////////
                      RECEIVER, NAV TIE, PENDING WRITE-DOWNS
    //////////////////////////////////////////////////////////////*/

    /// @dev Every strategy gets its mailbox with its first destinations, through either path; only the registry
    ///      can move funds out of it, and only into the strategy.
    function test_Receiver_CreatedWithDestinations_RegistryOnly() public {
        assertEq(_recv(account), address(0), "no receiver before destinations");
        vm.prank(admin);
        reg.setDestinations(account, deposit, holding);
        GyldDeliveryReceiver r = reg.receiverOf(account);
        assertTrue(address(r) != address(0));
        assertEq(r.REGISTRY(), address(reg));
        assertEq(r.STRATEGY(), account);
        // timelocked path for a never-set strategy also creates one, once
        vm.startPrank(admin);
        reg.proposeDestinations(other, address(0xD2), holding);
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(other);
        address r2 = _recv(other);
        assertTrue(r2 != address(0) && r2 != address(r));
        reg.proposeDestinations(other, address(1), address(2));
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(other);
        assertEq(_recv(other), r2, "a rotation keeps the receiver");
        vm.stopPrank();
        // nobody but the registry can sweep, and a sweep only ever pays the strategy
        bond.mint(address(r), 5e18);
        vm.prank(account);
        vm.expectRevert(GyldDeliveryReceiver.ONLY_REGISTRY.selector);
        r.sweep(address(bond), 5e18);
        vm.prank(admin);
        vm.expectRevert(GyldDeliveryReceiver.ONLY_REGISTRY.selector);
        r.sweep(address(bond), 5e18);
        assertEq(r.balance(address(bond)), 5e18);
    }

    /// @dev A settle only acknowledges what sits in the RECEIVER. The strategy's own balance is irrelevant: a user
    ///      deposit into the vault (cash landing in the strategy) can neither fake a payout nor block one.
    function test_Settle_RequiresDeliveryInReceiver_NotInStrategy() public {
        _configure();
        uint256 cashLot = _record(100e6);
        uint256 bondLot = _recordBonds(10e18);
        // the strategy is flush with both tokens by other routes: none of it counts
        bond.mint(account, 1000e18);
        cash.mint(account, 1_000_000e6);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, cashLot, 0, 100e18));
        reg.settleMint(cashLot, 100e6, 100e18, bytes32("m"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, cashLot, 0, 100e6));
        reg.settleCashReturn(cashLot, 100e6, bytes32("c"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, bondLot, 0, 10e6));
        reg.settleRedemption(bondLot, 10e18, 10e6, bytes32("r"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, bondLot, 0, 10e18));
        reg.settleReturn(bondLot, 10e18, bytes32("b"));
        vm.stopPrank();
        assertEq(reg.cashOut(account, address(bond)), 100e6, "nothing moved");
        assertFalse(reg.apiRefUsed(bytes32("m")), "a reverted settle consumes no reference");
        // one wei short in the receiver is still short; exact is enough, and the sweep lands in the strategy
        bond.mint(_recv(account), 100e18 - 1);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, cashLot, 100e18 - 1, 100e18)
        );
        reg.settleMint(cashLot, 100e6, 100e18, bytes32("m"));
        bond.mint(_recv(account), 1);
        uint256 walletBefore = bond.balanceOf(account);
        vm.prank(admin);
        reg.settleMint(cashLot, 100e6, 100e18, bytes32("m"));
        assertEq(bond.balanceOf(account), walletBefore + 100e18, "the settle is what moves the delivery");
        assertEq(bond.balanceOf(_recv(account)), 0);
        // the strategy spending everything it has does not block the bond return either
        uint256 all = bond.balanceOf(account);
        vm.prank(account);
        bond.transfer(other, all);
        bond.mint(_recv(account), 10e18);
        vm.prank(admin);
        reg.settleReturn(bondLot, 10e18, bytes32("b"));
        assertEq(reg.getLot(bondLot).open, 0);
    }

    /// @dev One delivery backs one settle: the sweep drains what it acknowledges, so the same bonds cannot be
    ///      used for a second lot, and a partial fill needs its own delivery.
    function test_Settle_DeliveryIsConsumed_NoReuseAcrossLots() public {
        _configure();
        uint256 a = _record(100e6);
        uint256 b = _record(100e6);
        bond.mint(_recv(account), 100e18); // Gyld filled A only
        vm.startPrank(admin);
        reg.settleMint(a, 100e6, 100e18, bytes32("a"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, b, 0, 100e18));
        reg.settleMint(b, 100e6, 100e18, bytes32("b"));
        vm.stopPrank();
        // partials: 40 then 60, each needing its own delivery
        bond.mint(_recv(account), 40e18);
        vm.prank(admin);
        reg.settleMint(b, 40e6, 40e18, bytes32("b1"));
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, b, 0, 60e18));
        reg.settleMint(b, 60e6, 60e18, bytes32("b2"));
        bond.mint(_recv(account), 60e18);
        vm.prank(admin);
        reg.settleMint(b, 60e6, 60e18, bytes32("b2"));
        assertEq(reg.getLot(b).open, 0);
    }

    /// @dev THE K2 ATTACK, closed: a decrease must be covered by the delivered VALUE at the live NAV within the
    ///      instrument's bounds. A 1-wei delivery cannot erase a lot, on either leg.
    function test_Settle_TiedToNav_OneWeiCannotClearALot() public {
        _configure();
        uint256 cashLot = _record(1000e6);
        uint256 bondLot = _recordBonds(1000e18);
        // mint floor = cash * (1 - fee) / (1 + premium) = 1000e6 / 1.05; redemption floor = value * (1 - discount)
        uint256 mintFloor = uint256(1000e6) * 10_000 / 10_500;
        bond.mint(_recv(account), 1);
        cash.mint(_recv(account), 1);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, cashLot, 0, mintFloor));
        reg.settleMint(cashLot, 1000e6, 1, bytes32("m"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, bondLot, 1, 950e6));
        reg.settleRedemption(bondLot, 1000e18, 1, bytes32("r"));
        vm.stopPrank();
        assertEq(reg.cashOut(account, address(bond)), 1000e6);
        assertEq(reg.bondsOut(account, address(bond)), 1000e18);
        // exactly at the floor passes; one unit under does not (the receiver holds enough either way)
        bond.mint(_recv(account), mintFloor * 1e12 - 1);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, cashLot, mintFloor - 1, mintFloor)
        );
        reg.settleMint(cashLot, 1000e6, mintFloor * 1e12 - 1, bytes32("m"));
        vm.prank(admin);
        reg.settleMint(cashLot, 1000e6, mintFloor * 1e12, bytes32("m"));
        assertEq(bond.balanceOf(account), mintFloor * 1e12, "swept");
        cash.mint(_recv(account), 950e6 - 1);
        vm.prank(admin);
        reg.settleRedemption(bondLot, 1000e18, 950e6, bytes32("r"));
        assertEq(reg.getLot(cashLot).open, 0);
        assertEq(reg.getLot(bondLot).open, 0);
    }

    /// @dev The tie follows the live NAV and the expected fee; without a usable NAV the settle waits.
    function test_Settle_TieUsesLiveNavAndFee_NoNavNoSettle() public {
        _configure();
        uint256 lot = _record(100e6);
        navFeed.setLatestAnswer(1.25e8); // NAV 1.25: 100 of cash buys 80 bonds
        bond.mint(_recv(account), 76e18);
        vm.prank(admin);
        reg.setTransitFeeBps(address(bond), 100); // floor = 100 * 0.99 / 1.05 = 94.29 of value = 75.4 bonds at 1.25
        vm.prank(admin);
        reg.settleMint(lot, 100e6, 76e18, bytes32("ok"));
        assertEq(reg.getLot(lot).open, 0);
        // a NAV failure (suspended) blocks the tie; the manual path still works
        uint256 lot2 = _record(100e6);
        bond.mint(_recv(account), 100e18);
        vm.prank(admin);
        bonds.setNavSuspended(address(bond), true);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.NAV_UNAVAILABLE.selector, uint8(2))); // SUSPENDED
        reg.settleMint(lot2, 100e6, 100e18, bytes32("blocked"));
        // oracle unset at all
        GyldInTransitRegistry bare = new GyldInTransitRegistry(admin, address(bonds));
        vm.startPrank(admin);
        bare.setDestinations(account, deposit, holding);
        bare.setMaxTransitAge(AGE);
        bare.setMaxCashInTransit(address(bond), CAP);
        bare.setMaxTotalCashInTransit(address(bond), CAP);
        vm.stopPrank();
        vm.prank(account);
        uint256 l3 = bare.recordCashOut(address(bond), address(cash), 1e6);
        bond.mint(address(bare.receiverOf(account)), 1e18);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.NAV_UNAVAILABLE.selector, type(uint8).max));
        bare.settleMint(l3, 1e6, 1e18, bytes32("x"));
        // and the oracle must bind THIS registry
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.ORACLE_MISMATCH.selector, address(oracle)));
        bare.setValuationOracle(address(oracle));
    }

    /// @dev Cash-for-cash and bonds-for-bonds settles have no NAV in them: they work with no oracle at all.
    function test_Settle_ReturnsNeedNoNav() public {
        GyldInTransitRegistry bare = new GyldInTransitRegistry(admin, address(bonds));
        vm.startPrank(admin);
        bare.setDestinations(account, deposit, holding);
        bare.setMaxTransitAge(AGE);
        bare.setMaxCashInTransit(address(bond), CAP);
        bare.setMaxTotalCashInTransit(address(bond), CAP);
        vm.stopPrank();
        vm.startPrank(account);
        uint256 c = bare.recordCashOut(address(bond), address(cash), 7e6);
        uint256 b = bare.recordBondsOut(address(bond), address(cash), 3e18);
        vm.stopPrank();
        address r = address(bare.receiverOf(account));
        cash.mint(r, 7e6);
        bond.mint(r, 3e18);
        vm.startPrank(admin);
        bare.settleCashReturn(c, 7e6, bytes32("c"));
        bare.settleReturn(b, 3e18, bytes32("b"));
        vm.stopPrank();
        assertEq(cash.balanceOf(account), 7e6);
        assertEq(bond.balanceOf(account), 3e18);
    }

    /// @dev A pending write-down is recognised from the proposal on; the reconciler settling part of the lot in
    ///      the meantime clamps it, closing the lot drops it (and frees the reference), and the window expires.
    function test_ManualSettle_Provisional_Clamped_Dropped_Expires() public {
        _configure();
        uint256 lot = _record(100e6);
        vm.prank(admin);
        reg.proposeManualSettle(lot, 80e6, bytes32("w"));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 20e6, "80 written down provisionally");
        // Gyld fills 50 after all: the pending amount is clamped to what is left open (50)
        _mint(lot, 50e6);
        (uint256 amt,,,,,) = reg.pendingManualSettles(lot);
        assertEq(amt, 50e6, "clamped to open");
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0, "50 open, 50 pending");
        assertTrue(reg.hasPendingManualSettle(account, address(bond)));
        // the reconciler closes the rest honestly: the proposal is dropped and its reference released
        bond.mint(_recv(account), 50e18);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSettleCancelled(lot);
        vm.prank(admin);
        reg.settleMint(lot, 50e6, 50e18, _ref());
        (,,,,, uint64 at) = reg.pendingManualSettles(lot);
        assertEq(at, 0, "dropped with the lot");
        assertFalse(reg.apiRefUsed(bytes32("w")), "reference released");
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0);
        // expiry: a proposal left alone past its window must be re-proposed
        uint256 lot2 = _record(10e6);
        vm.startPrank(admin);
        reg.proposeManualSettle(lot2, 10e6, bytes32("late"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY() + reg.MANUAL_SETTLE_WINDOW() + 1);
        vm.expectRevert(GyldInTransitRegistry.CHANGE_EXPIRED.selector);
        reg.executeManualSettle(lot2);
        reg.cancelManualSettle(lot2);
        reg.proposeManualSettle(lot2, 10e6, bytes32("late"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lot2);
        vm.stopPrank();
        assertEq(reg.getLot(lot2).open, 0);
    }

    /// @dev A delivery that reached the STRATEGY instead of the receiver (Gyld misconfigured) cannot be settled;
    ///      governance books it manually and, if something strayed into the receiver, rescues it.
    function test_ManualSettle_OverridesAMisroutedDelivery_AndRescue() public {
        _configure();
        uint256 lot = _record(100e6);
        bond.mint(account, 100e18); // Gyld paid the strategy directly: invisible to the receiver check
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, lot, 0, 100e18));
        reg.settleMint(lot, 100e6, 100e18, bytes32("m"));
        _loss(lot, 100e6);
        assertEq(reg.getLot(lot).open, 0);
        // a stray token in the receiver is governance's to move, and it only ever goes to the strategy
        MockERC20 stray = new MockERC20("S", "S", 18);
        stray.mint(_recv(account), 7);
        vm.prank(other);
        vm.expectRevert();
        reg.rescueFromReceiver(account, address(stray), 7);
        vm.prank(admin);
        vm.expectRevert(GyldInTransitRegistry.RECEIVER_NOT_SET.selector);
        reg.rescueFromReceiver(other, address(stray), 7);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(stray), 7);
        assertEq(stray.balanceOf(account), 7);
    }

    /// @dev The P4 flag: true exactly while the receiver holds an unswept delivery of the pair's bond or cash.
    function test_HasUnsettledDelivery_TracksTheReceiver() public {
        _configure();
        assertFalse(reg.hasUnsettledDelivery(other, address(bond)), "no receiver: false");
        assertFalse(reg.hasUnsettledDelivery(account, address(bond)));
        uint256 lot = _record(10e6);
        bond.mint(_recv(account), 10e18);
        assertTrue(reg.hasUnsettledDelivery(account, address(bond)), "bonds waiting");
        vm.prank(admin);
        reg.settleMint(lot, 10e6, 10e18, bytes32("m"));
        assertFalse(reg.hasUnsettledDelivery(account, address(bond)), "swept");
        cash.mint(_recv(account), 1);
        assertFalse(reg.hasUnsettledDelivery(account, address(bond)), "nothing open: a balance is not a delivery");
        (uint256 ub, uint256 uc) = reg.unsweptDelivery(account, address(bond));
        assertEq(ub, 0);
        assertEq(uc, 1, "but the amounts are visible for the dust policy");
        _recordBonds(1e18);
        assertTrue(reg.hasUnsettledDelivery(account, address(bond)), "a lot is open again: cash waiting");
    }

    /*//////////////////////////////////////////////////////////////
                    INSTRUMENT-WIDE CAP AND SEGREGATION
    //////////////////////////////////////////////////////////////*/

    /// @dev The second cap bounds the chain's total cash at Gyld per instrument across strategies: a strategy with
    ///      per-strategy headroom is still refused once the instrument is full, and any strategy's settle frees it.
    function test_GlobalCap_BoundsTheInstrumentAcrossStrategies() public {
        _configure(); // account: per-strategy CAP, instrument-wide 3 * CAP
        vm.startPrank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        reg.setMaxTotalCashInTransit(address(bond), CAP + CAP / 2);
        vm.stopPrank();
        uint256 mine = _record(CAP); // account fills its own cap
        assertEq(reg.previewCashOut(other, address(bond), address(cash), CAP / 2), 0);
        assertEq(
            reg.previewCashOut(other, address(bond), address(cash), CAP / 2 + 1),
            207,
            "per-strategy headroom left, instrument full"
        );
        vm.prank(other);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.GLOBAL_CAP_EXCEEDED.selector, CAP + CAP / 2 + 1, CAP + CAP / 2)
        );
        reg.recordCashOut(address(bond), address(cash), CAP / 2 + 1);
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), CAP / 2);
        assertEq(reg.totalCashInTransit(address(bond)), CAP + CAP / 2);
        // the other strategy's settle frees instrument-wide headroom for this one
        _mint(mine, CAP / 2);
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), CAP / 2);
        assertEq(reg.cashOut(other, address(bond)), CAP);
        assertEq(reg.totalCashInTransit(address(bond)), CAP + CAP / 2);
        // lowering the cap below what is out blocks new deposits without touching open lots
        vm.prank(admin);
        reg.setMaxTotalCashInTransit(address(bond), 1);
        assertEq(reg.totalCashInTransit(address(bond)), CAP + CAP / 2, "nothing written down");
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 207, "headroom of its own, none left");
        // exits are never capped
        vm.prank(other);
        reg.recordBondsOut(address(bond), address(cash), 1e18);
    }

    /// @dev Segregation (Gyld pools cash per account): a deposit address, which identifies the Gyld account on that
    ///      chain, belongs to at most one strategy. Checked on the immediate path, at proposal and at execution; a
    ///      rotation releases the old address; the holding wallet may be shared.
    function test_Segregation_OneDepositAddressPerStrategy() public {
        _configure();
        assertEq(reg.accountOfDepositAddress(deposit), account);
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_IN_USE.selector, deposit, account));
        reg.setDestinations(other, deposit, address(0x42));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_IN_USE.selector, deposit, account));
        reg.proposeDestinations(other, deposit, address(0x42));
        // only the cash account is exclusive: the holding wallet can be Gyld-wide
        reg.setDestinations(other, address(0xD2), holding);
        assertEq(reg.accountOfDepositAddress(address(0xD2)), other);
        // free when proposed, taken by execution time: refused at execute, the loser cancels
        reg.proposeDestinations(other, address(0xD3), holding);
        reg.proposeDestinations(account, address(0xD3), holding);
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(account);
        assertEq(reg.accountOfDepositAddress(deposit), address(0), "a rotation releases the old address");
        assertEq(reg.accountOfDepositAddress(address(0xD3)), account);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_IN_USE.selector, address(0xD3), account)
        );
        reg.executeDestinations(other);
        reg.cancelDestinations(other);
        // a released address can be taken by another strategy; a strategy may re-propose its own
        reg.proposeDestinations(other, deposit, holding);
        reg.proposeDestinations(account, address(0xD3), address(0x43));
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(other);
        reg.executeDestinations(account);
        vm.stopPrank();
        assertEq(reg.depositAddressOf(other), deposit);
        assertEq(reg.accountOfDepositAddress(deposit), other);
        assertEq(reg.depositAddressOf(account), address(0xD3));
        assertEq(reg.accountOfDepositAddress(address(0xD2)), address(0), "other's first address released");
    }

    /*//////////////////////////////////////////////////////////////
               NAV TIE (FUZZ), CAPS VS PROPOSALS, FLAGS, RESCUE
    //////////////////////////////////////////////////////////////*/

    /// @dev A fresh instrument whose entry / exit tolerance is `tolBps`, wired into the registry with both caps.
    function _instrumentWithTolerance(uint16 tolBps, uint256 feeBps) internal returns (MockERC20 b) {
        b = new MockERC20("Gyld Bond F", "GBF", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(b);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = tolBps;
        cfg.maxExitDiscountBps = tolBps;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setDestinations(account, deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(b), type(uint256).max);
        reg.setMaxTotalCashInTransit(address(b), type(uint256).max);
        reg.setTransitFeeBps(address(b), feeBps);
        vm.stopPrank();
    }

    /// @dev The mint tie over its whole parameter space: a settle is accepted exactly when the delivered bonds are
    ///      worth the consumed cash net of the expected fee and the entry premium, at the ORACLE's NAV; a refused
    ///      settle leaves the receiver, the reference and the lot untouched.
    function testFuzz_SettleMint_NavTie(uint64 navRaw, uint16 feeRaw, uint16 tolRaw, uint128 bondsRaw) public {
        uint256 navAnswer = bound(uint256(navRaw), 0.5e8, 2e8);
        uint256 fee = bound(uint256(feeRaw), 0, 1000);
        uint16 tol = uint16(bound(uint256(tolRaw), 1, 2000));
        uint256 bondsReceived = bound(uint256(bondsRaw), 1, 2500e18);
        uint256 cashConsumed = 1000e6;
        MockERC20 b = _instrumentWithTolerance(tol, fee);
        navFeed.setLatestAnswer(int256(navAnswer));
        vm.prank(account);
        uint256 lot = reg.recordCashOut(address(b), address(cash), cashConsumed);
        uint256 nav = oracle.previewNav(address(b)).nav;
        assertGt(nav, 0);
        uint256 delivered = bondsReceived * nav / 1e18;
        uint256 required = (cashConsumed * (10_000 - fee) / 10_000) * 10_000 / (10_000 + tol);
        uint256 allowed = cashConsumed * (10_000 + tol) / 10_000;
        b.mint(_recv(account), bondsReceived);
        vm.prank(admin);
        if (delivered < required || delivered > allowed) {
            vm.expectRevert(
                delivered < required
                    ? abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, lot, delivered, required)
                    : abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, lot, delivered, allowed)
            );
            reg.settleMint(lot, cashConsumed, bondsReceived, bytes32("f"));
            assertEq(b.balanceOf(_recv(account)), bondsReceived, "nothing swept");
            assertEq(b.balanceOf(account), 0);
            assertFalse(reg.apiRefUsed(bytes32("f")), "reference not burnt");
            assertEq(reg.getLot(lot).open, cashConsumed, "lot untouched");
        } else {
            reg.settleMint(lot, cashConsumed, bondsReceived, bytes32("f"));
            assertEq(reg.getLot(lot).open, 0);
            assertEq(b.balanceOf(account), bondsReceived, "swept into the strategy");
            assertEq(b.balanceOf(_recv(account)), 0);
            assertTrue(reg.apiRefUsed(bytes32("f")));
        }
    }

    /// @dev The redemption tie, same shape: cash paid must cover the bonds consumed at the oracle's NAV net of the
    ///      fee and the exit discount.
    function testFuzz_SettleRedemption_NavTie(uint64 navRaw, uint16 feeRaw, uint16 tolRaw, uint96 cashRaw) public {
        uint256 navAnswer = bound(uint256(navRaw), 0.5e8, 2e8);
        uint256 fee = bound(uint256(feeRaw), 0, 1000);
        uint16 tol = uint16(bound(uint256(tolRaw), 1, 2000));
        uint256 cashReturned = bound(uint256(cashRaw), 1, 2500e6);
        uint256 bondsConsumed = 1000e18;
        MockERC20 b = _instrumentWithTolerance(tol, fee);
        navFeed.setLatestAnswer(int256(navAnswer));
        vm.prank(account);
        uint256 lot = reg.recordBondsOut(address(b), address(cash), bondsConsumed);
        uint256 nav = oracle.previewNav(address(b)).nav;
        uint256 value = bondsConsumed * nav / 1e18;
        uint256 required = (value * (10_000 - fee) / 10_000) * (10_000 - tol) / 10_000;
        uint256 allowed = value * (10_000 + tol) / 10_000;
        cash.mint(_recv(account), cashReturned);
        vm.prank(admin);
        if (cashReturned < required || cashReturned > allowed) {
            vm.expectRevert(
                cashReturned < required
                    ? abi.encodeWithSelector(
                        GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, lot, cashReturned, required
                    )
                    : abi.encodeWithSelector(
                        GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, lot, cashReturned, allowed
                    )
            );
            reg.settleRedemption(lot, bondsConsumed, cashReturned, bytes32("r"));
            assertEq(cash.balanceOf(_recv(account)), cashReturned, "nothing swept");
            assertEq(reg.getLot(lot).open, bondsConsumed);
            assertFalse(reg.apiRefUsed(bytes32("r")));
        } else {
            reg.settleRedemption(lot, bondsConsumed, cashReturned, bytes32("r"));
            assertEq(reg.getLot(lot).open, 0);
            assertEq(cash.balanceOf(account), cashReturned);
            assertEq(cash.balanceOf(_recv(account)), 0, "drained");
            assertTrue(reg.apiRefUsed(bytes32("r")));
        }
    }

    /// @dev Caps are GROSS: a proposed write-down is netted from the valuation at once, but it frees no cap headroom
    ///      (per strategy or instrument-wide) until it executes. Otherwise a proposal would be a way to deposit past
    ///      the cap for two days.
    function test_ManualSettle_PendingProposalFreesNoCap() public {
        _configure();
        uint256 lot = _record(CAP);
        vm.prank(admin);
        reg.proposeManualSettle(lot, CAP, bytes32("w"));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0, "netted from the valuation");
        assertEq(reg.totalCashInTransitNet(address(bond)), 0);
        assertEq(reg.totalCashInTransit(address(bond)), CAP, "gross unchanged");
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1), 205, "cap still full");
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.CAP_EXCEEDED.selector, CAP + 1, CAP));
        reg.recordCashOut(address(bond), address(cash), 1);
        // instrument-wide too: a second strategy with its own headroom is held by the gross total
        vm.startPrank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        reg.setMaxTotalCashInTransit(address(bond), CAP);
        vm.stopPrank();
        assertEq(reg.previewCashOut(other, address(bond), address(cash), 1), 207);
        // execution frees both
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        vm.prank(admin);
        reg.executeManualSettle(lot);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), CAP), 0);
        assertEq(reg.previewCashOut(other, address(bond), address(cash), CAP), 0);
    }

    /// @dev A proposal on a BOND lot nets bonds in transit; a later honest return clamps it and the execute
    ///      finishes whatever is left.
    function test_ManualSettle_BondsLot_NetsAndClamps() public {
        _configure();
        uint256 lot = _recordBonds(10e18);
        vm.prank(admin);
        reg.proposeManualSettle(lot, 6e18, bytes32("b"));
        assertEq(reg.transitNet(account, address(bond)).bondsOut, 4e18, "6 of 10 written down provisionally");
        assertEq(reg.bondsOut(account, address(bond)), 10e18, "gross unchanged");
        assertTrue(reg.hasPendingManualSettle(account, address(bond)));
        assertEq(reg.totalCashInTransitNet(address(bond)), 0, "no cash involved");
        // Gyld returns 7 of the 10 bonds: 3 stay open, the proposal is clamped to 3
        bond.mint(_recv(account), 7e18);
        vm.prank(admin);
        reg.settleReturn(lot, 7e18, bytes32("r"));
        (uint256 amt,,,,,) = reg.pendingManualSettles(lot);
        assertEq(amt, 3e18, "clamped to open");
        assertEq(reg.transitNet(account, address(bond)).bondsOut, 0, "3 open, 3 pending");
        assertEq(bond.balanceOf(account), 7e18);
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        vm.prank(admin);
        reg.executeManualSettle(lot);
        assertEq(reg.getLot(lot).open, 0);
        assertEq(reg.bondsOut(account, address(bond)), 0);
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
    }

    /// @dev `hasUnsettledDelivery` is per instrument for bonds and shared for cash: two instruments on the same cash
    ///      token share the receiver's cash, so a payout for either flags both (the PPS pusher waits for both).
    function test_HasUnsettledDelivery_BondsPerInstrument_CashShared() public {
        _configure();
        MockERC20 bond2 = new MockERC20("Gyld Bond 2", "GB2", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond2);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setMaxCashInTransit(address(bond2), CAP);
        reg.setMaxTotalCashInTransit(address(bond2), CAP);
        vm.stopPrank();
        _record(1e6);
        vm.prank(account);
        reg.recordCashOut(address(bond2), address(cash), 1e6);
        bond2.mint(_recv(account), 1);
        assertFalse(reg.hasUnsettledDelivery(account, address(bond)), "another instrument's bonds do not count");
        assertTrue(reg.hasUnsettledDelivery(account, address(bond2)));
        cash.mint(_recv(account), 1);
        assertTrue(reg.hasUnsettledDelivery(account, address(bond)), "cash is shared across instruments");
        assertTrue(reg.hasUnsettledDelivery(account, address(bond2)));
        assertFalse(reg.hasUnsettledDelivery(account, address(otherCash)), "unregistered token: no lots, no revert");
        otherCash.mint(_recv(account), 1);
        assertFalse(reg.hasUnsettledDelivery(account, address(otherCash)), "no lot can be waiting for it");
        (uint256 ub,) = reg.unsweptDelivery(account, address(otherCash));
        assertEq(ub, 1, "the amount is still readable");
    }

    /// @dev A rescue moves tokens, never lots, so it is refused for an instrument's bond while that instrument has
    ///      lots open for the account (that is a live delivery: settle it, or write the lot off first). Stray tokens
    ///      and written-off lots rescue freely. Zero amounts are refused.
    function test_Rescue_MovesTokensNotLots_BlockedWhileLotsOpen() public {
        _configure();
        uint256 lot = _record(100e6);
        bond.mint(_recv(account), 100e18); // a real delivery
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.RESCUE_BLOCKED.selector, address(bond)));
        reg.rescueFromReceiver(account, address(bond), 100e18);
        assertTrue(reg.hasUnsettledDelivery(account, address(bond)), "still a delivery waiting for its settle");
        // a stray token is never blocked
        MockERC20 stray = new MockERC20("S", "S", 18);
        stray.mint(_recv(account), 3);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(stray), 3);
        assertEq(stray.balanceOf(account), 3);
        // governance writes the lot off: the bond is now a stray too, and the rescue lands it in the wallet
        _loss(lot, 100e6);
        assertEq(reg.cashOut(account, address(bond)), 0);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ReceiverRescued(account, address(bond), 100e18);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(bond), 100e18);
        assertEq(bond.balanceOf(account), 100e18, "paid to the strategy");
        vm.prank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.rescueFromReceiver(account, address(bond), 0);
    }

    /// @dev The receiver on its own: the deployer is the registry, the strategy is fixed, zero is refused.
    function test_Receiver_Standalone() public {
        vm.expectRevert(GyldDeliveryReceiver.ZERO_ADDRESS.selector);
        new GyldDeliveryReceiver(address(0));
        GyldDeliveryReceiver r = new GyldDeliveryReceiver(account);
        assertEq(r.REGISTRY(), address(this), "whoever deploys it is its registry");
        assertEq(r.STRATEGY(), account);
        cash.mint(address(r), 5e6);
        assertEq(r.balance(address(cash)), 5e6);
        r.sweep(address(cash), 2e6);
        assertEq(cash.balanceOf(account), 2e6);
        assertEq(r.balance(address(cash)), 3e6);
        vm.prank(account);
        vm.expectRevert(GyldDeliveryReceiver.ONLY_REGISTRY.selector);
        r.sweep(address(cash), 1);
        vm.expectRevert(); // more than it holds: the token refuses
        r.sweep(address(cash), 4e6);
    }

    /*//////////////////////////////////////////////////////////////
                    FINAL REVIEW: BAND, ORACLE, GUARDS
    //////////////////////////////////////////////////////////////*/

    /// @dev THE INFLATE ATTACK, closed: a reconciler cannot sweep a whole delivery against a sliver of decrease (that
    ///      would leave the lot open and the strategy counted twice). Both legs; the band's ceiling is the
    ///      instrument's tolerance above the decrease at NAV.
    function test_Settle_AboveBand_FullDeliveryCannotBackASliverOfDecrease() public {
        _configure();
        uint256 cashLot = _record(1000e6);
        bond.mint(_recv(account), 1000e18); // Gyld filled the whole lot
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, cashLot, 1000e6, 1.05e6)
        );
        reg.settleMint(cashLot, 1e6, 1000e18, bytes32("sliver"));
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, cashLot, 1000e6, 525e6));
        reg.settleMint(cashLot, 500e6, 1000e18, bytes32("half"));
        vm.prank(admin);
        reg.settleMint(cashLot, 1000e6, 1000e18, bytes32("full"));
        assertEq(reg.getLot(cashLot).open, 0);
        assertEq(reg.cashOut(account, address(bond)), 0, "nothing left to double count");
        // redemption leg, the cross-lot version: the receiver holds a cancelled deposit's 1000 of cash AND a 500
        // payout; sweeping all 1500 against the 500-bond lot would leave the 1000 lot open with its cash in the wallet
        uint256 cancelled = _record(1000e6);
        uint256 bondLot = _recordBonds(500e18);
        cash.mint(_recv(account), 1500e6);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, bondLot, 1500e6, 525e6));
        reg.settleRedemption(bondLot, 500e18, 1500e6, bytes32("grab"));
        vm.startPrank(admin);
        reg.settleRedemption(bondLot, 500e18, 500e6, bytes32("pay"));
        reg.settleCashReturn(cancelled, 1000e6, bytes32("back"));
        vm.stopPrank();
        assertEq(cash.balanceOf(account), 1500e6);
        assertEq(cash.balanceOf(_recv(account)), 0);
    }

    /// @dev The mirror fuzz: a FULL delivery against a fuzzed decrease is accepted exactly inside the band.
    function testFuzz_SettleMint_DecreaseMustMatchTheDelivery(uint96 cashRaw, uint16 tolRaw, uint16 feeRaw) public {
        uint256 cashConsumed = bound(uint256(cashRaw), 1, 1000e6);
        uint16 tol = uint16(bound(uint256(tolRaw), 1, 2000));
        uint256 fee = bound(uint256(feeRaw), 0, 1000);
        MockERC20 b = _instrumentWithTolerance(tol, fee);
        vm.prank(account);
        uint256 lot = reg.recordCashOut(address(b), address(cash), 1000e6);
        uint256 bondsReceived = 1000e18; // worth 1000e6 at NAV 1.00
        b.mint(_recv(account), bondsReceived);
        uint256 required = (cashConsumed * (10_000 - fee) / 10_000) * 10_000 / (10_000 + tol);
        uint256 allowed = cashConsumed * (10_000 + tol) / 10_000;
        vm.prank(admin);
        if (1000e6 > allowed) {
            vm.expectRevert(
                abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, lot, 1000e6, allowed)
            );
            reg.settleMint(lot, cashConsumed, bondsReceived, bytes32("f"));
            assertEq(reg.getLot(lot).open, 1000e6, "lot untouched");
        } else {
            assertGe(1000e6, required, "the ceiling implies the floor here");
            reg.settleMint(lot, cashConsumed, bondsReceived, bytes32("f"));
            assertEq(reg.getLot(lot).open, 1000e6 - cashConsumed);
            assertEq(b.balanceOf(account), bondsReceived);
        }
    }

    /// @dev The valuation oracle: first set immediate, later changes behind the destination timelock, must pin this
    ///      registry at set, at proposal and again at execution; zero refused; events.
    function test_ValuationOracle_FirstSetImmediate_ChangesTimelocked() public {
        GyldInTransitRegistry bare = new GyldInTransitRegistry(admin, address(bonds));
        GyldBondYieldSourceOracle o1 = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bonds), address(bare));
        GyldBondYieldSourceOracle o2 = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bonds), address(bare));
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_ADDRESS.selector);
        bare.setValuationOracle(address(0));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.ORACLE_MISMATCH.selector, address(oracle)));
        bare.setValuationOracle(address(oracle));
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ValuationOracleSet(address(o1));
        bare.setValuationOracle(address(o1));
        vm.expectRevert(GyldInTransitRegistry.ORACLE_ALREADY_SET.selector);
        bare.setValuationOracle(address(o2));
        // changes: propose / execute / cancel
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.ORACLE_MISMATCH.selector, address(oracle)));
        bare.proposeValuationOracle(address(oracle));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        bare.executeValuationOracle();
        vm.expectRevert(GyldInTransitRegistry.CHANGE_NOT_PENDING.selector);
        bare.cancelValuationOracle();
        uint64 at = uint64(block.timestamp + bare.DESTINATION_DELAY());
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ValuationOracleProposed(address(o2), at);
        bare.proposeValuationOracle(address(o2));
        vm.expectRevert(GyldInTransitRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        bare.executeValuationOracle();
        assertEq(address(bare.valuationOracle()), address(o1), "unchanged until executed");
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ValuationOracleCancelled();
        bare.cancelValuationOracle();
        bare.proposeValuationOracle(address(o2));
        vm.warp(at);
        bare.executeValuationOracle();
        vm.stopPrank();
        assertEq(address(bare.valuationOracle()), address(o2));
        (address pending, uint64 pendingAt) = bare.pendingValuationOracle();
        assertEq(pending, address(0));
        assertEq(pendingAt, 0);
    }

    /// @dev A released deposit address with open cash lots still pointing at it is not free for another strategy
    ///      (the money in flight would land in a Gyld account now shared by two strategies).
    function test_Segregation_ReleasedAddressWaitsForOpenLots() public {
        _configure();
        uint256 lot = _record(100e6);
        assertEq(reg.openCashLotsAt(deposit), 1);
        vm.startPrank(admin);
        reg.proposeDestinations(account, address(0xD3), holding);
        vm.warp(block.timestamp + reg.DESTINATION_DELAY());
        reg.executeDestinations(account); // the owner may always rotate away
        assertEq(reg.accountOfDepositAddress(deposit), address(0), "released");
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_HAS_OPEN_LOTS.selector, deposit, 1)
        );
        reg.setDestinations(other, deposit, holding);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_HAS_OPEN_LOTS.selector, deposit, 1)
        );
        reg.proposeDestinations(other, deposit, holding);
        vm.stopPrank();
        navFeed.setUpdatedAt(block.timestamp);
        _mint(lot, 100e6);
        assertEq(reg.openCashLotsAt(deposit), 0);
        vm.prank(admin);
        reg.setDestinations(other, deposit, holding);
        assertEq(reg.accountOfDepositAddress(deposit), other);
    }

    /// @dev An expired proposal no longer wedges the lot: a new proposal replaces it (and releases the old reference)
    ///      instead of reverting MANUAL_SETTLE_PENDING; the window boundaries are inclusive on both ends.
    function test_ManualSettle_ExpiredProposalIsReplaced_WindowBoundaries() public {
        _configure();
        uint256 lot = _record(100e6);
        vm.startPrank(admin);
        reg.proposeManualSettle(lot, 60e6, bytes32("old"));
        (,,,,, uint64 at) = reg.pendingManualSettles(lot);
        vm.warp(at - 1);
        vm.expectRevert(GyldInTransitRegistry.CHANGE_TIMELOCK_NOT_ELAPSED.selector);
        reg.executeManualSettle(lot);
        vm.warp(at + reg.MANUAL_SETTLE_WINDOW() + 1);
        vm.expectRevert(GyldInTransitRegistry.CHANGE_EXPIRED.selector);
        reg.executeManualSettle(lot);
        assertEq(reg.transitNet(account, address(bond)).cashOut, 40e6, "an expired proposal is still netted...");
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSettleCancelled(lot);
        reg.proposeManualSettle(lot, 100e6, bytes32("new")); // ...until it is replaced
        assertFalse(reg.apiRefUsed(bytes32("old")), "old reference released");
        assertTrue(reg.apiRefUsed(bytes32("new")));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0);
        (,,,,, at) = reg.pendingManualSettles(lot);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.MANUAL_SETTLE_PENDING.selector, lot));
        reg.proposeManualSettle(lot, 1, bytes32("third")); // a LIVE one still blocks
        vm.warp(at + reg.MANUAL_SETTLE_WINDOW()); // last second of the window
        reg.executeManualSettle(lot);
        vm.stopPrank();
        assertEq(reg.getLot(lot).open, 0);
    }

    /// @dev No settle can touch the receiver without decreasing a lot: zero decreases are refused on every leg.
    function test_Settle_ZeroDecreaseCannotSweep() public {
        _configure();
        uint256 cashLot = _record(10e6);
        uint256 bondLot = _recordBonds(10e18);
        bond.mint(_recv(account), 10e18);
        cash.mint(_recv(account), 10e6);
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.settleMint(cashLot, 0, 10e18, bytes32("a"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.settleCashReturn(cashLot, 0, bytes32("b"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.settleRedemption(bondLot, 0, 10e6, bytes32("c"));
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.settleReturn(bondLot, 0, bytes32("d"));
        vm.stopPrank();
        assertEq(bond.balanceOf(_recv(account)), 10e18);
        assertEq(cash.balanceOf(_recv(account)), 10e6);
    }

    /// @dev A bond token that skims on transfer cannot shrink a lot by more than the strategy receives.
    function test_Sweep_RequiresTheExactDelta() public {
        SkimmingToken skim = new SkimmingToken();
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(skim);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 500;
        cfg.maxExitDiscountBps = 500;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setDestinations(account, deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(skim), CAP);
        reg.setMaxTotalCashInTransit(address(skim), CAP);
        vm.stopPrank();
        vm.prank(account);
        uint256 lot = reg.recordCashOut(address(skim), address(cash), 100e6);
        skim.mint(_recv(account), 100e18);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.SWEEP_SHORT.selector, address(skim), 100e18, 100e18 - 1)
        );
        reg.settleMint(lot, 100e6, 100e18, bytes32("s"));
        assertEq(reg.getLot(lot).open, 100e6, "all or nothing");
    }

    /// @dev Pinning the residual the receiver does NOT close: two instruments on one cash token share the receiver's
    ///      cash, so a payout for B can be swept against A's lot when it fits A's band. Value-neutral for the strategy
    ///      (A closes, B stays open and valued, the cash is in the wallet); only the lot labels are wrong and B's own
    ///      settle then waits for a delivery that already left.
    function test_Settle_CrossInstrumentCashIsFungibleInTheReceiver() public {
        _configure();
        MockERC20 bond2 = new MockERC20("Gyld Bond 2", "GB2", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond2);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 500;
        cfg.maxExitDiscountBps = 500;
        vm.prank(admin);
        bonds.registerInstrument(cfg);
        uint256 lotA = _recordBonds(100e18);
        vm.prank(account);
        uint256 lotB = reg.recordBondsOut(address(bond2), address(cash), 100e18);
        cash.mint(_recv(account), 100e6); // B's payout
        vm.prank(admin);
        reg.settleRedemption(lotA, 100e18, 100e6, bytes32("mislabelled")); // fits A's band: accepted
        assertEq(reg.getLot(lotA).open, 0);
        assertEq(reg.getLot(lotB).open, 100e18, "B still valued, cash in the wallet: total value unchanged");
        assertEq(cash.balanceOf(account), 100e6);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, lotB, 0, 100e6));
        reg.settleRedemption(lotB, 100e18, 100e6, bytes32("b"));
    }

    /*//////////////////////////////////////////////////////////////
                  EVENTS, DECIMALS, SCRIPT SMOKE, MORE FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev Every configuration setter announces itself; monitoring keys off these.
    function test_Events_ConfigurationSetters() public {
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.MaxTransitAgeUpdated(AGE);
        reg.setMaxTransitAge(AGE);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.MaxCashInTransitUpdated(address(bond), CAP);
        reg.setMaxCashInTransit(address(bond), CAP);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.MaxTotalCashInTransitUpdated(address(bond), GLOBAL_CAP);
        reg.setMaxTotalCashInTransit(address(bond), GLOBAL_CAP);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.TransitFeeUpdated(address(bond), 25);
        reg.setTransitFeeBps(address(bond), 25);
        // the receiver's creation is announced with the first pair, with the address the registry stored
        vm.recordLogs();
        reg.setDestinations(account, deposit, holding);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool sawReceiver;
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics[0] == GyldInTransitRegistry.ReceiverCreated.selector) {
                assertEq(address(uint160(uint256(logs[i].topics[1]))), account);
                assertEq(address(uint160(uint256(logs[i].topics[2]))), _recv(account));
                sawReceiver = true;
            }
        }
        assertTrue(sawReceiver, "ReceiverCreated");
        uint64 at = uint64(block.timestamp + reg.DESTINATION_DELAY());
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.DestinationsProposed(account, address(0xD3), address(0x43), at);
        reg.proposeDestinations(account, address(0xD3), address(0x43));
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.DestinationsCancelled(account);
        reg.cancelDestinations(account);
        vm.stopPrank();
    }

    /// @dev The redemption mirror fuzz: a fixed payout against a fuzzed bond decrease is accepted exactly inside
    ///      the band, so under-reporting the bonds consumed (leaving bonds "in transit" that were already sold)
    ///      is refused.
    function testFuzz_SettleRedemption_DecreaseMustMatchThePayout(
        uint96 bondsRaw,
        uint16 tolRaw,
        uint16 feeRaw
    )
        public
    {
        uint256 bondsConsumed = bound(uint256(bondsRaw), 1, 1000e18);
        uint16 tol = uint16(bound(uint256(tolRaw), 1, 2000));
        uint256 fee = bound(uint256(feeRaw), 0, 1000);
        MockERC20 b = _instrumentWithTolerance(tol, fee);
        vm.prank(account);
        uint256 lot = reg.recordBondsOut(address(b), address(cash), 1000e18);
        uint256 cashReturned = 1000e6; // the whole lot's worth at NAV 1.00
        cash.mint(_recv(account), cashReturned);
        uint256 value = bondsConsumed / 1e12;
        uint256 required = (value * (10_000 - fee) / 10_000) * (10_000 - tol) / 10_000;
        uint256 allowed = value * (10_000 + tol) / 10_000;
        vm.prank(admin);
        if (cashReturned > allowed) {
            vm.expectRevert(
                abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, lot, cashReturned, allowed)
            );
            reg.settleRedemption(lot, bondsConsumed, cashReturned, bytes32("r"));
            assertEq(reg.getLot(lot).open, 1000e18, "lot untouched");
        } else {
            assertGe(cashReturned, required);
            reg.settleRedemption(lot, bondsConsumed, cashReturned, bytes32("r"));
            assertEq(reg.getLot(lot).open, 1000e18 - bondsConsumed);
            assertEq(cash.balanceOf(account), cashReturned);
        }
    }

    /// @dev A 6-decimal bond: `bondScale` comes from the instrument, so the band is in cash units either way.
    function test_Settle_Band_SixDecimalBond() public {
        MockERC20 b6 = new MockERC20("Gyld Bond 6", "GB6", 6);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(b6);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 500;
        cfg.maxExitDiscountBps = 500;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setDestinations(account, deposit, holding);
        reg.setMaxTransitAge(AGE);
        reg.setMaxCashInTransit(address(b6), CAP);
        reg.setMaxTotalCashInTransit(address(b6), CAP);
        vm.stopPrank();
        navFeed.setLatestAnswer(1.25e8); // NAV 1.25: 1000 of cash buys 800 bonds
        vm.prank(account);
        uint256 lot = reg.recordCashOut(address(b6), address(cash), 1000e6);
        b6.mint(_recv(account), 800e6);
        vm.prank(admin);
        reg.settleMint(lot, 1000e6, 800e6, bytes32("m")); // delivered = 800e6 * 1.25e6 / 1e6 = 1000e6, in band
        assertEq(reg.getLot(lot).open, 0);
        assertEq(b6.balanceOf(account), 800e6);
        // and the ceiling in 6 decimals: 800 bonds against 100 of decrease is 10x too much
        vm.prank(account);
        uint256 lot2 = reg.recordCashOut(address(b6), address(cash), 1000e6);
        b6.mint(_recv(account), 800e6);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_ABOVE_NAV.selector, lot2, 1000e6, 105e6));
        reg.settleMint(lot2, 100e6, 800e6, bytes32("m2"));
    }

    /// @dev Rescue uses the same delta check as a sweep: a token that skims cannot be "rescued" for more than lands.
    function test_Rescue_RequiresTheExactDelta() public {
        _configure();
        SkimmingToken skim = new SkimmingToken();
        skim.mint(_recv(account), 10e18);
        vm.prank(admin);
        vm.expectRevert(
            abi.encodeWithSelector(GyldInTransitRegistry.SWEEP_SHORT.selector, address(skim), 10e18, 10e18 - 1)
        );
        reg.rescueFromReceiver(account, address(skim), 10e18);
    }

    /*//////////////////////////////////////////////////////////////
            REVIEW ROUND 4: LEDGER WORDS, RESCUE, BOUNDS, SWEEP PROPOSALS
    //////////////////////////////////////////////////////////////*/

    /// @dev Cash returns and redemption payouts land in the lot's CASH token, so a cash rescue is refused while any
    ///      lot of the account (either kind) could still be paid in it; the same token is free once nothing is open.
    function test_Rescue_CashBlockedWhileAnyLotPaysInIt() public {
        _configure();
        cash.mint(_recv(account), 5e6); // a stray cash balance
        uint256 bondLot = _recordBonds(10e18); // its payout is cash
        assertEq(reg.openLotsPayingIn(account, address(cash)), 1);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.RESCUE_BLOCKED.selector, address(cash)));
        reg.rescueFromReceiver(account, address(cash), 5e6);
        uint256 cashLot = _record(10e6); // a cash return would also land in cash
        assertEq(reg.openLotsPayingIn(account, address(cash)), 2);
        // other tokens are never blocked
        otherCash.mint(_recv(account), 1);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(otherCash), 1);
        // close the bond lot: the cash lot still pays in cash
        bond.mint(_recv(account), 10e18);
        vm.prank(admin);
        reg.settleReturn(bondLot, 10e18, _ref());
        assertEq(reg.openLotsPayingIn(account, address(cash)), 1);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.RESCUE_BLOCKED.selector, address(cash)));
        reg.rescueFromReceiver(account, address(cash), 5e6);
        // the cash lot settles against the stray balance itself (a return IS cash in the receiver)...
        vm.prank(admin);
        reg.settleCashReturn(cashLot, 5e6, _ref());
        _loss(cashLot, 5e6);
        assertEq(reg.openLotsPayingIn(account, address(cash)), 0, "nothing open pays in cash");
        // ...and anything left is a stray again
        cash.mint(_recv(account), 2);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(cash), 2);
        assertEq(cash.balanceOf(account), 5e6 + 2);
        // another strategy's lots never block this one's rescue
        vm.prank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.prank(other);
        reg.recordBondsOut(address(bond), address(cash), 1e18);
        cash.mint(_recv(account), 3);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(cash), 3);
    }

    /// @dev Gyld's ledger is per legal entity, so only one strategy may fund it when `solePrincipal` is set:
    ///      every other strategy's cash leg is refused (preview 209), bond legs are untouched, zero clears it.
    function test_SolePrincipal_OnlyThatStrategyMayDeposit() public {
        _configure();
        vm.prank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.prank(other);
        vm.expectRevert();
        reg.setSolePrincipal(account); // MANAGER only
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.SolePrincipalSet(account);
        vm.prank(admin);
        reg.setSolePrincipal(account);
        assertEq(reg.previewCashOut(other, address(bond), address(cash), 1e6), 209);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1e6), 0);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.NOT_SOLE_PRINCIPAL.selector, account));
        reg.recordCashOut(address(bond), address(cash), 1e6);
        vm.prank(other);
        reg.recordBondsOut(address(bond), address(cash), 1e18); // redeeming is not funding the ledger
        _record(1e6);
        vm.prank(admin);
        reg.setSolePrincipal(address(0));
        assertEq(reg.previewCashOut(other, address(bond), address(cash), 1e6), 0);
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), 1e6);
    }

    /// @dev The per-pair open-lot bound: every walk the registry does is over at most `MAX_OPEN_LOTS_PER_PAIR`
    ///      lots, and hitting it refuses both legs (previews 210 / 305) until something settles.
    function test_OpenLotBound_RefusesBothLegsUntilASettle() public {
        _configure();
        uint256 max = reg.MAX_OPEN_LOTS_PER_PAIR();
        uint256 first;
        for (uint256 i; i < max; ++i) {
            uint256 id = i % 2 == 0 ? _record(1e6) : _recordBonds(1e18);
            if (i == 0) first = id;
        }
        assertEq(reg.openLots(account, address(bond)), max);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1e6), 210);
        assertEq(reg.previewBondsOut(account, address(bond), address(cash)), 305);
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.TOO_MANY_OPEN_LOTS.selector, max, max));
        reg.recordCashOut(address(bond), address(cash), 1e6);
        vm.prank(account);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.TOO_MANY_OPEN_LOTS.selector, max, max));
        reg.recordBondsOut(address(bond), address(cash), 1e18);
        // another pair of the same strategy is not affected
        MockERC20 b2 = new MockERC20("Gyld Bond 2", "GB2", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(b2);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setMaxCashInTransit(address(b2), CAP);
        reg.setMaxTotalCashInTransit(address(b2), CAP);
        vm.stopPrank();
        vm.prank(account);
        reg.recordCashOut(address(b2), address(cash), 1e6);
        // a partial settle frees nothing, closing a lot frees one slot
        _mint(first, 1e6 / 2);
        assertEq(reg.openLots(account, address(bond)), max);
        _mint(first, 1e6 / 2);
        assertEq(reg.openLots(account, address(bond)), max - 1);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1e6), 0);
        _record(1e6);
        assertEq(reg.openLots(account, address(bond)), max);
    }

    /// @dev `hasPendingManualSettle` is a counter now: it follows proposals across lots, cancels, executes, clamps
    ///      and drops exactly.
    function test_HasPendingManualSettle_CountsAcrossLots() public {
        _configure();
        uint256 l1 = _record(10e6);
        uint256 l2 = _record(20e6);
        uint256 l3 = _recordBonds(5e18);
        vm.startPrank(admin);
        reg.proposeManualSettle(l1, 10e6, bytes32("a"));
        reg.proposeManualSettle(l2, 5e6, bytes32("b"));
        reg.proposeManualSettle(l3, 5e18, bytes32("c"));
        reg.cancelManualSettle(l1);
        vm.stopPrank();
        assertTrue(reg.hasPendingManualSettle(account, address(bond)));
        _mint(l2, 20e6); // closes l2: its proposal is dropped
        assertTrue(reg.hasPendingManualSettle(account, address(bond)), "l3 still pending");
        vm.startPrank(admin);
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(l3);
        vm.stopPrank();
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        assertFalse(reg.hasPendingManualSettle(other, address(bond)), "another account: nothing");
    }

    /// @dev The expiry view: false while live, true once the window closed, false again when replaced or cancelled.
    function test_IsManualSettleExpired_View() public {
        _configure();
        uint256 lot = _record(10e6);
        assertFalse(reg.isManualSettleExpired(lot), "no proposal");
        vm.startPrank(admin);
        reg.proposeManualSettle(lot, 10e6, bytes32("a"));
        (,,,,, uint64 at) = reg.pendingManualSettles(lot);
        vm.warp(at + reg.MANUAL_SETTLE_WINDOW());
        assertFalse(reg.isManualSettleExpired(lot), "last second of the window");
        vm.warp(block.timestamp + 1);
        assertTrue(reg.isManualSettleExpired(lot));
        assertTrue(reg.hasPendingManualSettle(account, address(bond)), "still flagged while expired");
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0, "still netted while expired");
        reg.proposeManualSettle(lot, 10e6, bytes32("b"));
        assertFalse(reg.isManualSettleExpired(lot), "replaced");
        reg.cancelManualSettle(lot);
        assertFalse(reg.isManualSettleExpired(lot), "cancelled");
        vm.stopPrank();
    }

    /// @dev A filled order whose receipt is out of the band (the NAV moved after the fill): the reconciler cannot
    ///      settle it, governance proposes ONE decrease-plus-sweep, only the recognised loss is netted meanwhile,
    ///      and at execution the bonds enter the wallet as the claim leaves the valuation, atomically.
    function test_ManualSweep_AtomicDecreaseAndSweep() public {
        _configure();
        uint256 lot = _record(100e6);
        bond.mint(_recv(account), 90e18); // worth 90 at NAV 1.00: below the 5% band for a 100 debit
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, lot, 90e6, 95_238_095));
        reg.settleMint(lot, 100e6, 90e18, bytes32("x"));
        // validation of the proposal
        vm.startPrank(admin);
        vm.expectRevert(GyldInTransitRegistry.ZERO_AMOUNT.selector);
        reg.proposeManualSweep(lot, 100e6, 10e6, address(bond), 0, bytes32("s"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.LOSS_EXCEEDS_DECREASE.selector, 101e6, 100e6));
        reg.proposeManualSweep(lot, 100e6, 101e6, address(bond), 90e18, bytes32("s"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.INVALID_SWEEP_TOKEN.selector, address(otherCash)));
        reg.proposeManualSweep(lot, 100e6, 10e6, address(otherCash), 1, bytes32("s"));
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 100e6, 101e6));
        reg.proposeManualSweep(lot, 101e6, 10e6, address(bond), 90e18, bytes32("s"));
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSweepAttached(lot, address(bond), 90e18, 10e6);
        reg.proposeManualSweep(lot, 100e6, 10e6, address(bond), 90e18, bytes32("s"));
        vm.stopPrank();
        assertTrue(reg.apiRefUsed(bytes32("s")), "reference reserved at proposal");
        assertTrue(reg.hasPendingManualSettle(account, address(bond)));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 90e6, "only the recognised loss is netted");
        assertEq(reg.totalCashInTransitNet(address(bond)), 90e6);
        (uint256 amt, uint256 netted, uint256 sweepAmt, address sweepTok,,) = reg.pendingManualSettles(lot);
        assertEq(amt, 100e6);
        assertEq(netted, 10e6);
        assertEq(sweepAmt, 90e18);
        assertEq(sweepTok, address(bond));
        // execution: decrease and sweep in one transaction
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSweepExecuted(lot, address(bond), 90e18);
        vm.prank(admin);
        reg.executeManualSettle(lot);
        assertEq(reg.getLot(lot).open, 0);
        assertEq(reg.cashOut(account, address(bond)), 0);
        assertEq(bond.balanceOf(account), 90e18, "delivery in the wallet");
        assertEq(bond.balanceOf(_recv(account)), 0);
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0);
        assertEq(reg.maxTotalCashInTransit(address(bond)) - reg.totalCashInTransitNet(address(bond)), GLOBAL_CAP);
    }

    /// @dev Zero loss: a pure out-of-band receipt moves nothing until it executes; the receiver must hold the sweep
    ///      at execution (the whole execute reverts otherwise, lot and proposal untouched); a reconciler settle in
    ///      the meantime drops the sweep proposal because its facts changed.
    function test_ManualSweep_ZeroLoss_NeedsTheDelivery_DroppedByAReconcilerSettle() public {
        _configure();
        uint256 lot = _record(100e6);
        vm.prank(admin);
        reg.proposeManualSweep(lot, 100e6, 0, address(bond), 96e18, bytes32("s"));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 100e6, "nothing netted");
        assertTrue(reg.hasPendingManualSettle(account, address(bond)), "but flagged: governance is deciding");
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, lot, 0, 96e18));
        reg.executeManualSettle(lot);
        assertEq(reg.getLot(lot).open, 100e6, "untouched");
        assertTrue(reg.apiRefUsed(bytes32("s")), "proposal still stands");
        // Gyld settles part of it honestly after all: the sweep proposal falls
        bond.mint(_recv(account), 40e18);
        _freshNav();
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.ManualSettleCancelled(lot);
        vm.prank(admin);
        reg.settleMint(lot, 40e6, 40e18, bytes32("m"));
        assertFalse(reg.apiRefUsed(bytes32("s")), "reference released");
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        assertEq(reg.getLot(lot).open, 60e6);
        // the plain decrease on the same lot still clamps instead of dropping
        vm.prank(admin);
        reg.proposeManualSettle(lot, 60e6, bytes32("p"));
        bond.mint(_recv(account), 20e18);
        vm.prank(admin);
        reg.settleMint(lot, 20e6, 20e18, bytes32("m2"));
        (uint256 amt, uint256 netted,,,,) = reg.pendingManualSettles(lot);
        assertEq(amt, 40e6, "clamped");
        assertEq(netted, 40e6, "netting clamped with it");
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0);
    }

    /// @dev A deregistered instrument re-registered in another cash denomination: a priced settle of an old lot would
    ///      value its units in the wrong currency, so it is refused; the governed sweep closes such lots.
    function test_Settle_RefusedAfterDenominationChange_ManualSweepCloses() public {
        _configure();
        uint256 lot = _record(100e6);
        bond.mint(_recv(account), 100e18);
        vm.startPrank(admin);
        bonds.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + bonds.DEREGISTER_DELAY());
        bonds.executeDeregisterInstrument(address(bond));
        _freshNav();
        // unregistered: no NAV, no priced settle
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.NAV_UNAVAILABLE.selector, uint8(1)));
        reg.settleMint(lot, 100e6, 100e18, bytes32("m"));
        // re-registered against another cash token
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(otherCash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 500;
        cfg.maxExitDiscountBps = 500;
        bonds.registerInstrument(cfg);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.INSTRUMENT_DENOMINATION_CHANGED.selector, lot));
        reg.settleMint(lot, 100e6, 100e18, bytes32("m"));
        // the returns need no NAV and are still fine (same token in, same token out)
        cash.mint(_recv(account), 1e6);
        reg.settleCashReturn(lot, 1e6, bytes32("r"));
        // the rest closes through the governed sweep
        reg.proposeManualSweep(lot, 99e6, 0, address(bond), 100e18, bytes32("s"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lot);
        vm.stopPrank();
        assertEq(reg.getLot(lot).open, 0);
        assertEq(bond.balanceOf(account), 100e18);
    }

    /// @dev Setting a sole principal never strands another strategy: its open lots still settle, it can still redeem
    ///      and still record bond lots; only NEW cash deposits are refused. Clearing re-enables them.
    function test_SolePrincipal_OthersStillSettleAndRedeem() public {
        _configure();
        vm.prank(admin);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.prank(other);
        uint256 lot = reg.recordCashOut(address(bond), address(cash), 50e6);
        vm.prank(admin);
        reg.setSolePrincipal(account);
        // the open lot of the non-principal settles as before
        bond.mint(_recv(other), 50e18);
        vm.prank(admin);
        reg.settleMint(lot, 50e6, 50e18, _ref());
        assertEq(reg.cashOut(other, address(bond)), 0);
        // and it may still redeem
        vm.prank(other);
        reg.recordBondsOut(address(bond), address(cash), 10e18);
        // but not fund the ledger
        assertEq(reg.previewCashOut(other, address(bond), address(cash), 1e6), 209);
        vm.prank(other);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.NOT_SOLE_PRINCIPAL.selector, account));
        reg.recordCashOut(address(bond), address(cash), 1e6);
        // the principal itself is unaffected; re-pointing the principal moves the gate
        _record(1e6);
        vm.expectEmit(true, true, true, true);
        emit GyldInTransitRegistry.SolePrincipalSet(other);
        vm.prank(admin);
        reg.setSolePrincipal(other);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1e6), 209);
        vm.prank(other);
        reg.recordCashOut(address(bond), address(cash), 1e6);
    }

    /// @dev Sweep proposals on BONDS_OUT lots: a redemption payout outside the band (cash swept) and a bond return
    ///      (bonds swept); the execute pays the strategy and closes the lot either way.
    function test_ManualSweep_BondLot_CashPayoutOrBondReturn() public {
        _configure();
        uint256 lot = _recordBonds(100e18);
        // Gyld sold at 90 for bonds worth 100: below the 5% band for a settleRedemption
        cash.mint(_recv(account), 90e6);
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, lot, 90e6, 95e6));
        reg.settleRedemption(lot, 100e18, 90e6, bytes32("x"));
        vm.startPrank(admin);
        reg.proposeManualSweep(lot, 60e18, 6e18, address(cash), 54e6, bytes32("s1"));
        assertEq(reg.transitNet(account, address(bond)).bondsOut, 94e18, "only the recognised loss is netted");
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lot);
        vm.stopPrank();
        assertEq(cash.balanceOf(account), 54e6, "payout in the wallet");
        assertEq(reg.getLot(lot).open, 40e18);
        assertEq(reg.bondsOut(account, address(bond)), 40e18);
        // the rest comes back as bonds (a cancelled remainder), swept through the same path
        bond.mint(_recv(account), 40e18);
        vm.startPrank(admin);
        reg.proposeManualSweep(lot, 40e18, 0, address(bond), 40e18, bytes32("s2"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lot);
        vm.stopPrank();
        assertEq(bond.balanceOf(account), 40e18);
        assertEq(reg.getLot(lot).open, 0);
        assertEq(reg.openLots(account, address(bond)), 0);
        assertEq(cash.balanceOf(_recv(account)), 36e6, "what the sweep did not name stays in the receiver");
        assertFalse(reg.hasUnsettledDelivery(account, address(bond)), "nothing open: not a delivery");
    }

    /// @dev A sweep proposal is cancelled or expires like a plain one: netting and reference released, counter back
    ///      to zero, an expired one replaced by the next proposal.
    function test_ManualSweep_CancelAndExpiry() public {
        _configure();
        uint256 lot = _record(100e6);
        vm.startPrank(admin);
        reg.proposeManualSweep(lot, 100e6, 30e6, address(bond), 70e18, bytes32("a"));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 70e6);
        reg.cancelManualSettle(lot);
        assertEq(reg.transitNet(account, address(bond)).cashOut, 100e6, "netting released");
        assertFalse(reg.apiRefUsed(bytes32("a")));
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        reg.proposeManualSweep(lot, 100e6, 30e6, address(bond), 70e18, bytes32("a")); // the ref is free again
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY() + reg.MANUAL_SETTLE_WINDOW() + 1);
        assertTrue(reg.isManualSettleExpired(lot));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 70e6, "expired: still netted");
        vm.expectRevert(GyldInTransitRegistry.CHANGE_EXPIRED.selector);
        reg.executeManualSettle(lot);
        reg.proposeManualSettle(lot, 100e6, bytes32("b")); // replaces it, as a plain write-off this time
        (,, uint256 sweepAmt, address sweepTok,,) = reg.pendingManualSettles(lot);
        assertEq(sweepAmt, 0);
        assertEq(sweepTok, address(0));
        assertFalse(reg.apiRefUsed(bytes32("a")));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 0);
        vm.stopPrank();
    }

    /// @dev The sweep moves exactly `sweepAmount`: a receiver holding more keeps the rest as an unswept balance for
    ///      the next settle or a rescue once nothing is open.
    function test_ManualSweep_MovesExactlyTheNamedAmount() public {
        _configure();
        uint256 lot = _record(100e6);
        bond.mint(_recv(account), 120e18);
        vm.startPrank(admin);
        reg.proposeManualSweep(lot, 100e6, 0, address(bond), 90e18, bytes32("s"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lot);
        vm.stopPrank();
        assertEq(bond.balanceOf(account), 90e18);
        assertEq(bond.balanceOf(_recv(account)), 30e18);
        (uint256 ub,) = reg.unsweptDelivery(account, address(bond));
        assertEq(ub, 30e18);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(bond), 30e18); // nothing open on the instrument any more
        assertEq(bond.balanceOf(account), 120e18);
    }

    /// @dev The open-lot bound is released by a manual execute that closes the lot, not by one that leaves it open.
    function test_OpenLotBound_FreedByManualClose() public {
        _configure();
        uint256 max = reg.MAX_OPEN_LOTS_PER_PAIR();
        uint256 first;
        for (uint256 i; i < max; ++i) {
            uint256 id = _record(1e6);
            if (i == 0) first = id;
        }
        vm.startPrank(admin);
        reg.proposeManualSettle(first, 1e6 / 2, bytes32("half"));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(first);
        vm.stopPrank();
        assertEq(reg.openLots(account, address(bond)), max, "half open still counts");
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1e6), 210);
        _loss(first, 1e6 / 2);
        assertEq(reg.openLots(account, address(bond)), max - 1);
        assertEq(reg.previewCashOut(account, address(bond), address(cash), 1e6), 0);
    }

    /// @dev The cash guard counts open lots of EVERY instrument that pays in the token: closing the lots of one bond
    ///      does not free a rescue while another bond's lot still pays in the same cash.
    function test_Rescue_CashGuardSpansInstruments() public {
        _configure();
        MockERC20 b2 = new MockERC20("Gyld Bond 2", "GB2", 18);
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(b2);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.startPrank(admin);
        bonds.registerInstrument(cfg);
        reg.setMaxCashInTransit(address(b2), CAP);
        reg.setMaxTotalCashInTransit(address(b2), CAP);
        vm.stopPrank();
        uint256 lotA = _record(10e6);
        vm.prank(account);
        reg.recordBondsOut(address(b2), address(cash), 1e18);
        assertEq(reg.openLotsPayingIn(account, address(cash)), 2);
        cash.mint(_recv(account), 1);
        _loss(lotA, 10e6);
        assertEq(reg.cashOut(account, address(bond)), 0, "bond A has nothing open");
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.RESCUE_BLOCKED.selector, address(cash)));
        reg.rescueFromReceiver(account, address(cash), 1);
        // the b2 lot returns its bonds: nothing pays in cash any more
        b2.mint(_recv(account), 1e18);
        vm.prank(admin);
        reg.settleReturn(2, 1e18, _ref());
        assertEq(reg.openLotsPayingIn(account, address(cash)), 0);
        vm.prank(admin);
        reg.rescueFromReceiver(account, address(cash), 1);
    }

    /// @dev The denomination guard covers the redemption leg too: a bond lot recorded against one cash token cannot
    ///      be priced once the instrument is re-registered against another.
    function test_Settle_RedemptionRefusedAfterDenominationChange() public {
        _configure();
        uint256 lot = _recordBonds(10e18);
        vm.startPrank(admin);
        bonds.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + bonds.DEREGISTER_DELAY());
        bonds.executeDeregisterInstrument(address(bond));
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(otherCash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxExitDiscountBps = 500;
        bonds.registerInstrument(cfg);
        _freshNav();
        cash.mint(_recv(account), 10e6);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.INSTRUMENT_DENOMINATION_CHANGED.selector, lot));
        reg.settleRedemption(lot, 10e18, 10e6, bytes32("r"));
        // the bond return still works (no NAV, same token in and out)
        bond.mint(_recv(account), 4e18);
        reg.settleReturn(lot, 4e18, bytes32("ret"));
        assertEq(reg.getLot(lot).open, 6e18);
        vm.stopPrank();
    }

    /// @dev Over random decreases and recognised losses: the valuation moves by exactly the recognised loss at the
    ///      proposal, by the rest at execution, and the sweep lands the named amount in the wallet.
    function testFuzz_ManualSweep_NetsOnlyTheRecognisedLoss(uint96 amountRaw, uint96 lossRaw, uint96 sweepRaw) public {
        _configure();
        uint256 amount = bound(uint256(amountRaw), 1, 1000e6);
        uint256 loss = bound(uint256(lossRaw), 0, amount);
        uint256 sweep = bound(uint256(sweepRaw), 1, 1000e18);
        uint256 lot = _record(1000e6);
        bond.mint(_recv(account), sweep);
        vm.startPrank(admin);
        reg.proposeManualSweep(lot, amount, loss, address(bond), sweep, bytes32("f"));
        assertEq(reg.transitNet(account, address(bond)).cashOut, 1000e6 - loss);
        assertEq(reg.totalCashInTransitNet(address(bond)), 1000e6 - loss);
        assertTrue(reg.hasPendingManualSettle(account, address(bond)));
        vm.warp(block.timestamp + reg.MANUAL_SETTLE_DELAY());
        reg.executeManualSettle(lot);
        vm.stopPrank();
        assertEq(reg.cashOut(account, address(bond)), 1000e6 - amount);
        assertEq(reg.transitNet(account, address(bond)).cashOut, 1000e6 - amount, "no netting left behind");
        assertEq(bond.balanceOf(account), sweep);
        assertEq(bond.balanceOf(_recv(account)), 0);
        assertFalse(reg.hasPendingManualSettle(account, address(bond)));
        assertEq(reg.openLots(account, address(bond)), amount == 1000e6 ? 0 : 1);
    }

    /// @dev The configure script's read-only check runs against a fully configured registry without reverting:
    ///      it is the operator's view and nothing else exercises it.
    function test_Script_RunCheckReadsAConfiguredRegistry() public {
        _configure();
        vm.startPrank(admin);
        reg.setTransitFeeBps(address(bond), 50);
        reg.setDestinations(other, address(0xD2), address(0x42));
        vm.stopPrank();
        uint256 lot = _record(100e6);
        bond.mint(_recv(account), 1); // an unswept dust delivery, to hit that branch
        vm.prank(admin);
        reg.proposeManualSettle(lot, 1e6, bytes32("p")); // and a pending proposal
        vm.prank(admin);
        reg.proposeDestinations(other, address(0xD5), address(0x45)); // and a pending rotation
        ConfigureGyldInTransitRegistry script = new ConfigureGyldInTransitRegistry();
        address[] memory strategies = new address[](3);
        strategies[0] = account;
        strategies[1] = other;
        strategies[2] = address(0x9999); // never configured: UNSET branches
        address[] memory bondTokens = new address[](1);
        bondTokens[0] = address(bond);
        script.runCheck(uint64(block.chainid), address(reg), strategies, bondTokens);
        // and on a bare registry every value prints UNSET
        GyldInTransitRegistry bare = new GyldInTransitRegistry(admin, address(bonds));
        script.runCheck(uint64(block.chainid), address(bare), strategies, bondTokens);
    }
}

/// @dev An ERC20 that keeps 1 wei of every transfer (fee-on-transfer stand-in)
contract SkimmingToken is MockERC20 {
    constructor() MockERC20("Skim", "SKIM", 18) { }

    function transfer(address to, uint256 value) public override returns (bool) {
        _transfer(msg.sender, to, value - 1);
        _burn(msg.sender, 1);
        return true;
    }
}
