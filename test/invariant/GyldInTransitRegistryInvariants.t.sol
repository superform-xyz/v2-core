// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { GyldInTransitRegistry } from "../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";

import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockAggregator } from "../mocks/MockAggregator.sol";

/// @dev Random records, random per-lot settles of every kind, random time. The registry's bookkeeping must stay
///      consistent with a brute-force walk over the lots after every call.
contract GyldInTransitHandler is Test {
    GyldInTransitRegistry public immutable REG;
    MockAggregator public immutable FEED;
    address public immutable ADMIN;
    address public immutable CASH;
    address[] public actors;
    address[] public bonds;

    uint256 public records;
    uint256 public settles;
    uint256 public pendingProposed;
    uint256 public rotations;
    uint256 public navTied;
    uint256 public manualExecuted;
    uint256 public donations;
    uint256 public collisions;
    uint256 public skipped;
    uint256 public warped;
    /// @dev The destination each lot was sent to when it was recorded (the registry must snapshot exactly this)
    mapping(uint256 lotId => address destination) public expectedDest;

    constructor(
        GyldInTransitRegistry reg,
        MockAggregator feed,
        address admin,
        address cash,
        address[] memory actors_,
        address[] memory bonds_
    ) {
        REG = reg;
        FEED = feed;
        ADMIN = admin;
        CASH = cash;
        actors = actors_;
        bonds = bonds_;
    }

    function recordCash(uint256 a, uint256 b, uint256 amount) external {
        address actor = actors[a % actors.length];
        address bond = bonds[b % bonds.length];
        amount = bound(amount, 1, 1e9);
        if (REG.previewCashOut(actor, bond, CASH, amount) != 0) {
            ++skipped;
            return;
        }
        vm.prank(actor);
        uint256 lotId = REG.recordCashOut(bond, CASH, amount);
        expectedDest[lotId] = REG.depositAddressOf(actor);
        ++records;
    }

    function recordBonds(uint256 a, uint256 b, uint256 shares) external {
        address actor = actors[a % actors.length];
        address bond = bonds[b % bonds.length];
        shares = bound(shares, 1, 1e21);
        if (REG.previewBondsOut(actor, bond, CASH) != 0) {
            ++skipped;
            return;
        }
        vm.prank(actor);
        uint256 lotId = REG.recordBondsOut(bond, CASH, shares);
        expectedDest[lotId] = REG.redeemHoldingWalletOf(actor);
        ++records;
    }

    /// @dev Rotate an actor's deposit address through the timelocked path. Addresses are drawn from a small pool so
    ///      collisions with another actor's live address happen often: those must be refused, never silently taken.
    function rotate(uint256 a, uint256 seed) external {
        address actor = actors[a % actors.length];
        address dep = address(uint160(0xD000 + seed % 8));
        address holder = REG.accountOfDepositAddress(dep);
        uint256 openAt = REG.openCashLotsAt(dep);
        address hold = REG.redeemHoldingWalletOf(actor); // hoisted: the call after expectRevert must be the one
        vm.startPrank(ADMIN);
        if (holder != address(0) && holder != actor) {
            vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_IN_USE.selector, dep, holder));
            REG.proposeDestinations(actor, dep, hold);
            vm.stopPrank();
            ++collisions;
            return;
        }
        if (holder != actor && openAt != 0) {
            vm.expectRevert(
                abi.encodeWithSelector(GyldInTransitRegistry.DEPOSIT_ADDRESS_HAS_OPEN_LOTS.selector, dep, openAt)
            );
            REG.proposeDestinations(actor, dep, hold);
            vm.stopPrank();
            ++collisions;
            return;
        }
        REG.proposeDestinations(actor, dep, hold);
        vm.warp(block.timestamp + REG.DESTINATION_DELAY());
        FEED.setUpdatedAt(block.timestamp);
        REG.executeDestinations(actor);
        vm.stopPrank();
        ++rotations;
    }

    /// @dev Anyone can send tokens to a receiver: dust, a misdirected transfer, a donation. Nothing may leave it
    ///      except through a settle (against a lot) or a MANAGER rescue.
    function donate(uint256 a, uint256 b, uint256 amount, bool isCash) external {
        address recv = address(REG.receiverOf(actors[a % actors.length]));
        if (isCash) MockERC20(CASH).mint(recv, bound(amount, 1, 1e8));
        else MockERC20(bonds[b % bonds.length]).mint(recv, bound(amount, 1, 1e20));
        ++donations;
    }

    function settle(uint256 lotSeed, uint256 amountSeed, uint256 kindSeed) external {
        uint256 n = REG.lotCount();
        if (n == 0) return;
        uint256 id = lotSeed % n + 1;
        GyldInTransitRegistry.Lot memory l = REG.getLot(id);
        if (l.open == 0) {
            ++skipped;
            return;
        }
        (,, uint64 pendingAt) = REG.pendingManualSettles(id);
        bool bondProposal = l.kind == GyldInTransitRegistry.LotKind.BONDS_OUT && kindSeed % 3 == 2;
        if (pendingAt != 0 && (kindSeed % 4 == 1 || bondProposal)) {
            // an already-pending lot cannot take a second proposal: execute (or cancel) the one it has instead
            vm.startPrank(ADMIN);
            if (block.timestamp > pendingAt + REG.MANUAL_SETTLE_WINDOW()) {
                REG.cancelManualSettle(id);
            } else {
                if (pendingAt > block.timestamp) vm.warp(pendingAt);
                FEED.setUpdatedAt(block.timestamp);
                REG.executeManualSettle(id);
                ++manualExecuted;
            }
            vm.stopPrank();
            ++settles;
            return;
        }
        if (pendingAt != 0 && kindSeed % 4 == 2) {
            ++skipped;
            return;
        }
        FEED.setUpdatedAt(block.timestamp); // the NAV tie needs a fresh feed; time moves a lot in these runs
        uint256 amt = bound(amountSeed, 1, l.open);
        bytes32 ref = keccak256(abi.encode(id, settles, kindSeed));
        // Gyld "delivers" first, into the account's RECEIVER: every settle sweeps what it acknowledges (NAV 1.00,
        // 6-dec cash vs 18-dec bonds)
        address recv = address(REG.receiverOf(l.account));
        if (l.kind == GyldInTransitRegistry.LotKind.CASH_OUT) {
            uint256 k = kindSeed % 4;
            if (k == 0) {
                MockERC20(l.bondToken).mint(recv, amt * 1e12);
                vm.prank(ADMIN);
                REG.settleMint(id, amt, amt * 1e12, ref);
                ++navTied;
            } else if (k == 1) {
                // a loss: the manager's timelocked path
                vm.startPrank(ADMIN);
                REG.proposeManualSettle(id, amt, ref);
                vm.warp(block.timestamp + REG.MANUAL_SETTLE_DELAY());
                FEED.setUpdatedAt(block.timestamp);
                REG.executeManualSettle(id);
                ++manualExecuted;
                vm.stopPrank();
            } else if (k == 2) {
                // a proposal left pending (netted, not executed): later settles must clamp or drop it
                vm.prank(ADMIN);
                REG.proposeManualSettle(id, amt, ref);
                ++pendingProposed;
            } else {
                MockERC20(CASH).mint(recv, amt);
                vm.prank(ADMIN);
                REG.settleCashReturn(id, amt, ref);
            }
        } else {
            uint256 k = kindSeed % 3;
            uint256 cashOut_ = amt / 1e12; // the bonds' value at NAV 1.00 in 6-dec cash; zero for dust lots
            if (k == 0 && cashOut_ != 0) {
                MockERC20(CASH).mint(recv, cashOut_);
                vm.prank(ADMIN);
                REG.settleRedemption(id, amt, cashOut_, ref);
                ++navTied;
            } else if (k == 1 || k == 0) {
                MockERC20(l.bondToken).mint(recv, amt);
                vm.prank(ADMIN);
                REG.settleReturn(id, amt, ref);
            } else {
                // a bond write-down left pending
                vm.prank(ADMIN);
                REG.proposeManualSettle(id, amt, ref);
                ++pendingProposed;
            }
        }
        ++settles;
    }

    function warp(uint256 s) external {
        vm.warp(block.timestamp + bound(s, 0, 3 days));
        FEED.setUpdatedAt(block.timestamp);
        ++warped;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function bondCount() external view returns (uint256) {
        return bonds.length;
    }
}

/// @title GyldInTransitRegistryInvariants
/// @notice Stateful fuzz of the per-lot registry: aggregates are sums of open lots, the queue head is the oldest
///         open lot, staleness follows that lot, and every lot is well-formed, across any interleaving of records,
///         partial settles of every kind and time.
contract GyldInTransitRegistryInvariants is Test {
    GyldInTransitRegistry internal reg;
    GyldBondRegistry internal bondRegistry;
    GyldInTransitHandler internal handler;

    MockERC20 internal cash;
    MockERC20[] internal bondTokens;
    address[] internal actors;
    address[] internal bonds;
    address[] internal receiversAtBirth;

    address internal admin = address(0xA11CE);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);
    uint256 internal constant AGE = 14 days;

    function setUp() public {
        vm.warp(1_800_000_000);
        cash = new MockERC20("USD Coin", "USDC", 6);
        MockAggregator feed = new MockAggregator(8);
        feed.setLatestAnswer(1e8);
        bondRegistry = new GyldBondRegistry(admin);
        for (uint256 i; i < 2; ++i) {
            MockERC20 b = new MockERC20("Gyld Bond", "GB", 18);
            bondTokens.push(b);
            bonds.push(address(b));
            GyldBondRegistry.InstrumentConfig memory cfg;
            cfg.bondToken = address(b);
            cfg.navFeed = address(feed);
            cfg.cashToken = address(cash);
            cfg.maxObservationAge = 7 days;
            cfg.maxPublicationAge = 7 days;
            cfg.maxEntryPremiumBps = 500;
            cfg.maxExitDiscountBps = 500;
            vm.prank(admin);
            bondRegistry.registerInstrument(cfg);
        }
        reg = new GyldInTransitRegistry(admin, address(bondRegistry));
        GyldBondYieldSourceOracle oracle =
            new GyldBondYieldSourceOracle(address(0xC0FFEE), address(bondRegistry), address(reg));
        actors.push(address(0xA001));
        actors.push(address(0xA002));
        actors.push(address(0xA003));
        vm.startPrank(admin);
        reg.setMaxTransitAge(AGE);
        reg.setValuationOracle(address(oracle));
        for (uint256 i; i < actors.length; ++i) {
            // one Gyld account (deposit address) per strategy; the holding wallet may be shared
            reg.setDestinations(actors[i], _depositOf(i), holding);
        }
        for (uint256 i; i < bonds.length; ++i) {
            reg.setMaxCashInTransit(bonds[i], 1e12);
            reg.setMaxTotalCashInTransit(bonds[i], 2e12); // binds before the three per-strategy caps would
        }
        vm.stopPrank();

        handler = new GyldInTransitHandler(reg, feed, admin, address(cash), actors, bonds);
        targetContract(address(handler));
        for (uint256 i; i < actors.length; ++i) {
            receiversAtBirth.push(address(reg.receiverOf(actors[i])));
        }
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = handler.recordCash.selector;
        selectors[1] = handler.recordBonds.selector;
        selectors[2] = handler.settle.selector;
        selectors[3] = handler.warp.selector;
        selectors[4] = handler.rotate.selector;
        selectors[5] = handler.donate.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    /*//////////////////////////////////////////////////////////////
                               INVARIANTS
    //////////////////////////////////////////////////////////////*/

    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_AggregatesAreSumsOfOpenLots() public view {
        for (uint256 b; b < bonds.length; ++b) {
            uint256 totalCash;
            uint256 totalPending;
            for (uint256 a; a < actors.length; ++a) {
                (uint256 cashSum, uint256 bondSum, uint256 pendingSum, uint256 pendingBondSum) =
                    _sumOpen(actors[a], bonds[b]);
                assertEq(reg.cashOut(actors[a], bonds[b]), cashSum, "cashOut == sum of open cash lots");
                assertEq(reg.bondsOut(actors[a], bonds[b]), bondSum, "bondsOut == sum of open bond lots");
                GyldInTransitRegistry.Transit memory net = reg.transitNet(actors[a], bonds[b]);
                assertEq(net.cashOut, cashSum - pendingSum, "net cash == open minus pending proposals");
                assertEq(net.bondsOut, bondSum - pendingBondSum, "net bonds == open minus pending proposals");
                assertEq(
                    reg.hasPendingManualSettle(actors[a], bonds[b]),
                    pendingSum + pendingBondSum != 0,
                    "flag follows pending"
                );
                totalCash += cashSum;
                totalPending += pendingSum;
            }
            assertEq(reg.totalCashInTransit(bonds[b]), totalCash, "totalCashInTransit == sum over accounts");
            assertEq(reg.totalCashInTransitNet(bonds[b]), totalCash - totalPending, "net total == sum of nets");
            assertLe(totalCash, reg.maxTotalCashInTransit(bonds[b]), "instrument-wide cap never exceeded");
            for (uint256 a; a < actors.length; ++a) {
                assertLe(reg.cashOut(actors[a], bonds[b]), reg.maxCashInTransit(bonds[b]), "per-strategy cap holds");
            }
        }
    }

    /// @dev Segregation under rotation: every live deposit address is owned by exactly the strategy using it, no two
    ///      strategies share one, released addresses are free, and a rotation never replaces the receiver.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_OneGyldAccountPerStrategy_ReceiverStable() public view {
        for (uint256 a; a < actors.length; ++a) {
            address dep = reg.depositAddressOf(actors[a]);
            assertTrue(dep != address(0), "a configured strategy always has a deposit address");
            assertEq(reg.accountOfDepositAddress(dep), actors[a], "live address owned by its strategy");
            for (uint256 o = a + 1; o < actors.length; ++o) {
                assertTrue(reg.depositAddressOf(actors[o]) != dep, "no two strategies share a Gyld account");
            }
            assertEq(address(reg.receiverOf(actors[a])), receiversAtBirth[a], "rotation keeps the receiver");
        }
        // every address in the rotation pool is either free or held by a strategy currently using it
        for (uint256 k; k < 8; ++k) {
            address dep = address(uint160(0xD000 + k));
            address holder = reg.accountOfDepositAddress(dep);
            if (holder != address(0)) assertEq(reg.depositAddressOf(holder), dep, "stale claim after release");
        }
    }

    /// @dev A pending proposal never exceeds what is open on its lot, and the receiver never holds anything
    ///      after a settle swept it: the delivery flag is exactly "something of the pair sits in the receiver AND the
    ///      pair has something open" (donations included).
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_PendingProposalsAreClampedToOpen_FlagMatchesReceiver() public view {
        uint256 n = reg.lotCount();
        for (uint256 id = 1; id <= n; ++id) {
            (uint256 amt, bytes32 ref, uint64 at) = reg.pendingManualSettles(id);
            GyldInTransitRegistry.Lot memory l = reg.getLot(id);
            if (at == 0) {
                assertEq(amt, 0, "no amount without a proposal");
                continue;
            }
            assertGt(l.open, 0, "a closed lot carries no proposal");
            assertLe(amt, l.open, "pending <= open");
            assertGt(amt, 0, "a proposal is never empty");
            assertTrue(reg.apiRefUsed(ref), "a pending proposal holds its reference");
        }
        for (uint256 a; a < actors.length; ++a) {
            for (uint256 b; b < bonds.length; ++b) {
                (uint256 ub, uint256 uc) = reg.unsweptDelivery(actors[a], bonds[b]);
                address recv = address(reg.receiverOf(actors[a]));
                assertEq(ub, MockERC20(bonds[b]).balanceOf(recv), "unswept bonds == receiver balance");
                assertEq(uc, cash.balanceOf(recv), "unswept cash == receiver balance");
                bool open = reg.cashOut(actors[a], bonds[b]) != 0 || reg.bondsOut(actors[a], bonds[b]) != 0;
                assertEq(reg.hasUnsettledDelivery(actors[a], bonds[b]), open && (ub != 0 || uc != 0), "flag");
            }
        }
    }

    /// @dev `openCashLotsAt` is exactly the count of open CASH_OUT lots pinned to each address in play.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_OpenCashLotsAtMatchesTheLots() public view {
        uint256 n = reg.lotCount();
        for (uint256 k; k < 8 + actors.length; ++k) {
            address dep = k < 8 ? address(uint160(0xD000 + k)) : _depositOf(k - 8);
            uint256 count;
            for (uint256 id = 1; id <= n; ++id) {
                GyldInTransitRegistry.Lot memory l = reg.getLot(id);
                if (l.kind == GyldInTransitRegistry.LotKind.CASH_OUT && l.open != 0 && l.destination == dep) ++count;
            }
            assertEq(reg.openCashLotsAt(dep), count, "open cash lots at the address");
        }
    }

    /// @dev Not an invariant: a deterministic walk proving the handler reaches every path the invariants claim to
    ///      cover (NAV-tied settles, manual executes, rotations, refused rotations, donations).
    function test_HandlerReachesEveryPath() public {
        for (uint256 i; i < 600; ++i) {
            uint256 s = uint256(keccak256(abi.encode(i)));
            uint256 op = s % 6;
            uint256 x = s >> 32; // independent bits for the arguments: `s % 6` must not pick the actor too
            if (op == 0) handler.recordCash(x, x >> 8, x >> 16);
            else if (op == 1) handler.recordBonds(x, x >> 8, x >> 16);
            else if (op == 2) handler.settle(x, x >> 8, x >> 16);
            else if (op == 3) handler.warp(x % 2 days);
            else if (op == 4) handler.rotate(x, x >> 8);
            else handler.donate(x, x >> 8, x >> 16, x % 2 == 0);
        }
        assertGt(handler.records(), 0);
        assertGt(handler.navTied(), 0, "NAV-tied settles reached");
        assertGt(handler.manualExecuted(), 0, "manual executes reached");
        assertGt(handler.rotations(), 0, "rotations reached");
        assertGt(handler.collisions(), 0, "refused rotations reached");
        assertGt(handler.donations(), 0);
    }

    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_HeadIsTheOldestOpenLot_AndStalenessFollowsIt() public view {
        for (uint256 a; a < actors.length; ++a) {
            for (uint256 b; b < bonds.length; ++b) {
                uint256[] memory ids = reg.lotsOf(actors[a], bonds[b]);
                uint256 expectId;
                uint64 expectAt;
                for (uint256 i; i < ids.length; ++i) {
                    GyldInTransitRegistry.Lot memory l = reg.getLot(ids[i]);
                    if (l.open != 0) {
                        expectId = ids[i];
                        expectAt = l.openedAt;
                        break;
                    }
                }
                (uint256 gotId, uint64 gotAt) = reg.oldestOpenLot(actors[a], bonds[b]);
                assertEq(gotId, expectId, "head is the first open lot");
                assertEq(gotAt, expectAt, "and carries its clock");
                assertEq(reg.transit(actors[a], bonds[b]).oldestOpenAt, expectAt, "transit() agrees");
                bool expectStale = expectId != 0 && block.timestamp - expectAt > AGE;
                assertEq(reg.isStale(actors[a], bonds[b]), expectStale, "stale iff the oldest open lot aged");
                if (expectId != 0) assertEq(reg.isLotStale(expectId), expectStale);
            }
        }
    }

    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_LotsAreWellFormed() public view {
        uint256 seen;
        for (uint256 a; a < actors.length; ++a) {
            for (uint256 b; b < bonds.length; ++b) {
                uint256[] memory ids = reg.lotsOf(actors[a], bonds[b]);
                uint256 prev;
                uint64 prevAt;
                for (uint256 i; i < ids.length; ++i) {
                    assertGt(ids[i], prev, "ids strictly increasing within a pair");
                    GyldInTransitRegistry.Lot memory l = reg.getLot(ids[i]);
                    assertEq(l.account, actors[a], "lot belongs to its account");
                    assertEq(l.bondToken, bonds[b], "lot belongs to its instrument");
                    assertLe(l.open, l.recorded, "open never exceeds recorded");
                    assertGt(l.recorded, 0, "a recorded lot is never empty");
                    assertGe(l.openedAt, prevAt, "lots are appended in time order");
                    assertEq(l.destination, handler.expectedDest(ids[i]), "destination snapshotted AT RECORD TIME");
                    if (l.kind == GyldInTransitRegistry.LotKind.BONDS_OUT) assertEq(l.destination, holding);
                    prev = ids[i];
                    prevAt = l.openedAt;
                    ++seen;
                }
            }
        }
        assertEq(seen, reg.lotCount(), "every issued id lives in exactly one pair");
        assertEq(reg.getLot(reg.lotCount() + 1).recorded, 0, "the next id is unissued");
    }

    /// @dev Closed lots never come back: once open hits zero, no settle of any kind can touch the lot again.
    /// forge-config: default.invariant.runs = 32
    /// forge-config: default.invariant.depth = 80
    function invariant_ClosedLotsStayClosed() public {
        uint256 n = reg.lotCount();
        for (uint256 id = 1; id <= n; ++id) {
            GyldInTransitRegistry.Lot memory l = reg.getLot(id);
            if (l.open != 0) continue;
            vm.startPrank(admin);
            vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 0, 1));
            if (l.kind == GyldInTransitRegistry.LotKind.CASH_OUT) reg.settleCashReturn(id, 1, bytes32(0));
            else reg.settleReturn(id, 1, bytes32(0));
            vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.EXCEEDS_OPEN.selector, 0, 1));
            reg.proposeManualSettle(id, 1, keccak256(abi.encode("closed", id)));
            vm.stopPrank();
            assertFalse(reg.isLotStale(id), "a closed lot is never stale");
        }
    }

    function _depositOf(uint256 i) internal view returns (address) {
        return address(uint160(uint256(uint160(deposit)) + i));
    }

    function _sumOpen(
        address account,
        address bond
    )
        internal
        view
        returns (uint256 cashSum, uint256 bondSum, uint256 pendingSum, uint256 pendingBondSum)
    {
        uint256[] memory ids = reg.lotsOf(account, bond);
        for (uint256 i; i < ids.length; ++i) {
            GyldInTransitRegistry.Lot memory l = reg.getLot(ids[i]);
            (uint256 amt,,) = reg.pendingManualSettles(ids[i]);
            if (l.kind == GyldInTransitRegistry.LotKind.CASH_OUT) {
                cashSum += l.open;
                pendingSum += amt;
            } else {
                bondSum += l.open;
                pendingBondSum += amt;
            }
        }
    }
}
