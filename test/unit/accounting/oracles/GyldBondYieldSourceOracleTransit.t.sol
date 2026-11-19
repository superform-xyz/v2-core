// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { GyldInTransitRegistry } from "../../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";

/// @title GyldBondYieldSourceOracleTransitTest
/// @notice The in-transit half of the oracle (SUP-21848): what the registry entries add to each read (cash at
///         face, bonds at the live NAV, both net of `transitFeeBps`), the stale flag (a gate, never a write-down), and
/// the invariants the existing reads keep.
///         The pre-existing suite runs with `IN_TRANSIT == address(0)` and is unchanged.
contract GyldBondYieldSourceOracleTransitTest is Test {
    GyldBondRegistry internal registry;
    GyldInTransitRegistry internal transit;
    GyldBondYieldSourceOracle internal oracle;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals
    MockAggregator internal navFeed; // 8 decimals, Chainlink-shaped

    address internal admin = address(0xA11CE);
    address internal holder = address(0xB0DB);
    address internal deposit = address(0xDE90);
    address internal holding = address(0x401D);

    int256 internal constant NAV_ANSWER = 1.05e8;
    uint256 internal constant NAV_IN_CASH = 1.05e6;
    uint256 internal constant AGE = 14 days;

    function setUp() public {
        vm.warp(1_800_000_000);
        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(NAV_ANSWER);

        registry = new GyldBondRegistry(admin);
        transit = new GyldInTransitRegistry(admin, address(registry));
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(transit));

        _register(address(bond), 18);
        vm.startPrank(admin);
        transit.setDestinations(holder, deposit, holding);
        transit.setMaxTransitAge(AGE);
        transit.setMaxCashInTransit(address(bond), type(uint256).max);
        transit.setMaxTotalCashInTransit(address(bond), type(uint256).max);
        transit.setValuationOracle(address(oracle));
        vm.stopPrank();
    }

    /// @dev Gyld delivers into the strategy's receiver; a settle sweeps it into the wallet
    function _recv(address acct) internal view returns (address) {
        return address(transit.receiverOf(acct));
    }

    function _register(address bondToken, uint8) internal {
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = bondToken;
        cfg.navFeed = address(navFeed);
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.maxEntryPremiumBps = 500;
        cfg.maxExitDiscountBps = 500;
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    function _cashOut(uint256 amount) internal {
        vm.prank(holder);
        transit.recordCashOut(address(bond), address(cash), amount);
    }

    function _bondsOut(uint256 shares) internal {
        vm.prank(holder);
        transit.recordBondsOut(address(bond), address(cash), shares);
    }

    function _setFee(uint256 bps) internal {
        vm.prank(admin);
        transit.setTransitFeeBps(address(bond), bps);
    }

    /// @dev The loss path: MANAGER proposes, waits out the delay, executes (no asset arrives).
    function _loss(uint256 lotId, uint256 amount, bytes32 ref) internal {
        vm.startPrank(admin);
        transit.proposeManualSettle(lotId, amount, ref);
        vm.warp(block.timestamp + transit.MANUAL_SETTLE_DELAY());
        transit.executeManualSettle(lotId);
        vm.stopPrank();
        navFeed.setLatestAnswer(NAV_ANSWER); // keep the feed fresh across the warp
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_PinsRegistry_And_RejectsMismatch() public {
        assertEq(address(oracle.IN_TRANSIT()), address(transit));
        GyldBondRegistry otherBonds = new GyldBondRegistry(admin);
        GyldInTransitRegistry foreign = new GyldInTransitRegistry(admin, address(otherBonds));
        vm.expectRevert(GyldBondYieldSourceOracle.REGISTRY_MISMATCH.selector);
        new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(foreign));
        // zero = feature off
        GyldBondYieldSourceOracle off = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(0));
        assertEq(address(off.IN_TRANSIT()), address(0));
        assertFalse(off.hasStaleTransit(address(bond), holder));
    }

    /*//////////////////////////////////////////////////////////////
                          getTVLByOwnerOfShares
    //////////////////////////////////////////////////////////////*/

    function test_TVL_HeldPlusCashAtFace_PlusBondsAtLiveNav() public {
        bond.mint(holder, 100e18);
        _cashOut(250e6);
        _bondsOut(10e18);
        // 100 bonds * 1.05 + 250 cash + 10 bonds * 1.05: bonds in transit mark exactly like wallet bonds
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 105e6 + 250e6 + 10 * NAV_IN_CASH);
        _bondsOut(10e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 105e6 + 250e6 + 20 * NAV_IN_CASH);
        // the live NAV moves: held and in-transit bonds move together, cash does not
        navFeed.setLatestAnswer(1.2e8);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 120 * 1.2e6 + 250e6, "both legs at 1.20");
    }

    /// @dev The expected-fee haircut nets BOTH in-transit legs and never touches wallet bonds.
    function test_TVL_FeeHaircut_NetsTransitLegsOnly() public {
        bond.mint(holder, 100e18);
        _cashOut(1000e6);
        _bondsOut(10e18);
        uint256 gross = 100 * NAV_IN_CASH + 1000e6 + 10 * NAV_IN_CASH;
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), gross, "no haircut by default");
        _setFee(50); // 0.5%
        uint256 inTransit = 1000e6 + 10 * NAV_IN_CASH;
        assertEq(
            oracle.getTVLByOwnerOfShares(address(bond), holder),
            100 * NAV_IN_CASH + inTransit * 9950 / 10_000,
            "transit legs net of 0.5%, wallet bonds untouched"
        );
        _setFee(1000);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 100 * NAV_IN_CASH + inTransit * 9000 / 10_000);
        _setFee(0);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), gross);
    }

    function test_TVL_ZeroShortCircuit_StillHolds_WithNoTransit() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        // no balance, no transit: zero WITHOUT touching the suspended feed
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 0);
    }

    function test_TVL_TransitWithSuspendedNav_CashOnlyPrices_BondsRevert() public {
        _cashOut(1e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        // lazy NAV: a position with no bonds anywhere (wallet or transit) is cash at face, no feed read
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 1e6, "cash-only position needs no NAV");
        _bondsOut(1e18);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
        // identity read still answers, and it is the plain balance: in-transit is valuation, not balance
        _unsuspendAndRecord();
    }

    function _unsuspendAndRecord() internal {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), false);
        _bondsOut(3e18);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        assertEq(
            oracle.getBalanceOfOwner(address(bond), holder), bond.balanceOf(holder), "plain balance under suspension"
        );
    }

    /// @dev K8 (review on SUP-21848): a stale lot is FLAGGED and gates new deposits, but it is never written down.
    ///      Zeroing it made the price per share fall for as long as the reconciler lagged, which is a discount for
    ///      whoever buys in that window. A loss is booked through the manager's manual settle, never by the clock.
    function test_TVL_StaleTransit_StillValued_OnlyFlagged() public {
        bond.mint(holder, 1e18);
        _cashOut(100e6);
        _bondsOut(2e18);
        uint256 before = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertEq(before, NAV_IN_CASH + 100e6 + 2 * NAV_IN_CASH);
        assertFalse(oracle.hasStaleTransit(address(bond), holder));
        vm.warp(block.timestamp + AGE + 1);
        navFeed.setLatestAnswer(NAV_ANSWER); // keep the feed itself fresh
        assertTrue(oracle.hasStaleTransit(address(bond), holder), "flagged");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), before, "no cliff: value unchanged while stale");
        assertEq(
            oracle.getTVL(address(bond)), NAV_IN_CASH + 100e6, "getTVL (supply at NAV + cash in transit) unchanged too"
        );
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 1e18);
        // the gate is the registry's, not the oracle's
        assertEq(transit.previewCashOut(holder, address(bond), address(cash), 1), 204, "new deposits blocked");
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        vm.prank(holder);
        transit.recordCashOut(address(bond), address(cash), 1);
        // the only thing that moves the value is a settle: here a governance-booked loss
        _loss(1, 100e6, bytes32("lost"));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), before - 100e6, "a booked loss moves it");
    }

    function test_TVL_6DecimalBond() public {
        MockERC20 bond6 = new MockERC20("Gyld Bond 6", "GB6", 6);
        _register(address(bond6), 6);
        vm.startPrank(admin);
        transit.setMaxCashInTransit(address(bond6), type(uint256).max);
        transit.setMaxTotalCashInTransit(address(bond6), type(uint256).max);
        vm.stopPrank();
        bond6.mint(holder, 100e6);
        vm.prank(holder);
        transit.recordBondsOut(address(bond6), address(cash), 10e6);
        vm.prank(holder);
        transit.recordCashOut(address(bond6), address(cash), 5e6);
        // 100 * 1.05 + 10 * 1.05 + 5
        assertEq(oracle.getTVLByOwnerOfShares(address(bond6), holder), 105e6 + 10.5e6 + 5e6);
        // balance: the wallet only; bonds in the holding wallet and cash at Gyld are value, not balance
        assertEq(oracle.getBalanceOfOwner(address(bond6), holder), 100e6);
    }

    /*//////////////////////////////////////////////////////////////
                            getBalanceOfOwner
    //////////////////////////////////////////////////////////////*/

    /// @dev Review finding (SUP-21848): the balance must not be padded with in-transit cash converted at NAV
    ///      (assumes a fill, adds a NAV dependency to an identity read) nor with bonds in Gyld's holding wallet
    ///      (not redeemable from the wallet). Value lives in TVL; the breakdown in `registry.transit`.
    function test_BalanceOfOwner_IsThePlainBalance_NeverReverts() public {
        bond.mint(holder, 2e18);
        _cashOut(2.1e6); // 2 bonds' worth at 1.05
        _bondsOut(1e18);
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 2e18, "wallet balance only");
        GyldInTransitRegistry.Transit memory t = transit.transit(holder, address(bond));
        assertEq(t.cashOut, 2.1e6, "cash in transit is reported as cash");
        assertEq(t.bondsOut, 1e18, "bonds in transit are reported as bonds");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 3 * NAV_IN_CASH + 2.1e6, "value counts both");
        // unregistered token: plain balance, no registry lookup
        MockERC20 stray = new MockERC20("S", "S", 18);
        stray.mint(holder, 7);
        assertEq(oracle.getBalanceOfOwner(address(stray), holder), 7);
    }

    /*//////////////////////////////////////////////////////////////
                                 getTVL
    //////////////////////////////////////////////////////////////*/

    function test_GetTVL_AddsCashNotBonds() public {
        bond.mint(holder, 100e18);
        bond.mint(holding, 10e18); // bonds "in the holding wallet" are still in totalSupply
        _cashOut(50e6);
        _bondsOut(10e18);
        assertEq(oracle.getTVL(address(bond)), 110 * NAV_IN_CASH + 50e6, "supply at NAV plus cash in transit only");
        _setFee(100);
        assertEq(oracle.getTVL(address(bond)), 110 * NAV_IN_CASH + 50e6 * 99 / 100, "cash in transit net of the fee");
    }

    /*//////////////////////////////////////////////////////////////
                              PRICING UNCHANGED
    //////////////////////////////////////////////////////////////*/

    function test_PerSharePricing_IgnoresTransit() public {
        _cashOut(1000e6);
        _bondsOut(1e18);
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
        assertEq(oracle.getAssetOutput(address(bond), address(cash), 1e18), NAV_IN_CASH);
        assertEq(oracle.getShareOutput(address(bond), address(cash), NAV_IN_CASH), 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev TVL is additive in both transit legs at the live mark, and the fee haircut scales exactly the
    ///      in-transit part.
    function testFuzz_TVL_AdditiveAtLiveNav_FeeNetsTransitOnly(
        uint96 held,
        uint64 cashIn,
        uint96 bondsIn,
        uint16 feeRaw
    )
        public
    {
        uint256 h = bound(uint256(held), 0, 1e24);
        uint256 c = bound(uint256(cashIn), 0, 1e12);
        uint256 b = bound(uint256(bondsIn), 0, 1e24);
        uint256 fee = bound(uint256(feeRaw), 0, 1000);
        if (h != 0) bond.mint(holder, h);
        uint256 base = oracle.getTVLByOwnerOfShares(address(bond), holder);
        if (c != 0) _cashOut(c);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), base + c, "cash at face");
        if (b != 0) _bondsOut(b);
        uint256 full = oracle.getTVLByOwnerOfShares(address(bond), holder);
        uint256 inTransit = c + b * NAV_IN_CASH / 1e18;
        assertEq(full, base + inTransit, "bonds in transit at the live NAV, like wallet bonds");
        _setFee(fee);
        uint256 net = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertEq(net, base + inTransit * (10_000 - fee) / 10_000, "haircut on the transit part only");
        assertGe(net, base, "the haircut never reaches wallet bonds");
    }

    /*//////////////////////////////////////////////////////////////
                         MORE: ACCOUNTS, ROUNDING, LOTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Two strategies on the same instrument: each is valued on its own lots; getTVL sums the cash legs.
    function test_TVL_TwoAccountsAreIndependent_GetTVLSumsCash() public {
        address other = address(0x07E7);
        vm.prank(admin);
        transit.setDestinations(other, address(0xD2), holding);
        bond.mint(holder, 10e18);
        bond.mint(other, 20e18);
        _cashOut(100e6);
        vm.prank(other);
        transit.recordCashOut(address(bond), address(cash), 300e6);
        vm.prank(other);
        transit.recordBondsOut(address(bond), address(cash), 5e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 10 * NAV_IN_CASH + 100e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), other), 20 * NAV_IN_CASH + 300e6 + 5 * NAV_IN_CASH);
        assertEq(oracle.getTVL(address(bond)), 30 * NAV_IN_CASH + 400e6, "supply at NAV + all cash in transit");
        // settling one account never moves the other
        _loss(2, 300e6, bytes32("gone"));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 10 * NAV_IN_CASH + 100e6, "holder untouched");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), other), 25 * NAV_IN_CASH);
        assertEq(oracle.getTVL(address(bond)), 30 * NAV_IN_CASH + 100e6);
    }

    /// @dev The haircut rounds DOWN on the combined transit value, once, never per leg and never on wallet bonds.
    function test_TVL_FeeHaircut_RoundsDownOnce() public {
        bond.mint(holder, 3e18);
        _cashOut(7); // 7 raw cash units
        _bondsOut(1e18); // 1.05e6
        _setFee(33); // 0.33%
        uint256 inTransit = 7 + NAV_IN_CASH;
        uint256 expected = 3 * NAV_IN_CASH + (inTransit * (10_000 - 33)) / 10_000;
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), expected);
        // a single-unit transit value nets to zero under any non-zero fee (floor), wallet bonds unaffected
        address tiny = address(0x7111);
        vm.prank(admin);
        transit.setDestinations(tiny, address(0xD4), holding);
        bond.mint(tiny, 1e18);
        vm.prank(tiny);
        transit.recordCashOut(address(bond), address(cash), 1);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), tiny), NAV_IN_CASH + 0);
    }

    /// @dev Valuation follows the OPEN part of each lot through partial settles, not what was recorded. A delivery
    ///      sitting in the receiver is NOT valued (the open lot still is), and the settle that sweeps it into the
    ///      wallet shrinks the lot in the same transaction: nothing is ever counted twice.
    function test_TVL_TracksOpenAcrossPartialSettles_ReceiverNeverCounted() public {
        bond.mint(holder, 1e18);
        _cashOut(1000e6);
        _bondsOut(10e18);
        uint256 wallet = NAV_IN_CASH; // 1 bond
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), wallet + 1000e6 + 10 * NAV_IN_CASH);
        // Gyld mints 380 bonds (399 of value at 1.05) for 400 of the cash: in the receiver they count for nothing
        bond.mint(_recv(holder), 380e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), wallet + 1000e6 + 10 * NAV_IN_CASH, "unswept");
        assertTrue(oracle.hasUnsettledDelivery(address(bond), holder));
        vm.prank(admin);
        transit.settleMint(1, 400e6, 380e18, bytes32("p1"));
        wallet += 380 * NAV_IN_CASH;
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), wallet + 600e6 + 10 * NAV_IN_CASH);
        assertFalse(oracle.hasUnsettledDelivery(address(bond), holder));
        // 4 bonds sold, 4 of cash paid out (NAV 1.05, within the 5% discount)
        cash.mint(_recv(holder), 4e6);
        vm.prank(admin);
        transit.settleRedemption(2, 4e18, 4e6, bytes32("r1"));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), wallet + 600e6 + 6 * NAV_IN_CASH);
        assertEq(cash.balanceOf(holder), 4e6, "swept into the wallet");
        // the remaining 600 of cash is lost (governance books it), the remaining 6 bonds come back
        _loss(1, 600e6, bytes32("p2"));
        bond.mint(_recv(holder), 6e18);
        vm.prank(admin);
        transit.settleReturn(2, 6e18, bytes32("r2"));
        wallet += 6 * NAV_IN_CASH;
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), wallet, "everything settled: wallet only");
        assertEq(transit.transit(holder, address(bond)).oldestOpenAt, 0);
    }

    /// @dev A stale lot keeps its value AND its haircut; the fee is not a second penalty for lateness.
    function test_TVL_StaleLot_KeepsValueAndHaircut() public {
        _setFee(100);
        _cashOut(500e6);
        uint256 v = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertEq(v, 500e6 * 99 / 100);
        vm.warp(block.timestamp + AGE + 1);
        navFeed.setLatestAnswer(NAV_ANSWER);
        assertTrue(oracle.hasStaleTransit(address(bond), holder));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), v, "same value while stale");
    }

    /// @dev Many lots, mixed kinds, settled in a shuffled order: the valuation is always the sum of what is open.
    function test_TVL_ManyLots_ShuffledSettles() public {
        bond.mint(holder, 2e18);
        uint256 cashOpen;
        uint256 bondsOpen;
        for (uint256 i = 1; i <= 8; ++i) {
            if (i % 2 == 1) {
                _cashOut(i * 10e6);
                cashOpen += i * 10e6;
            } else {
                _bondsOut(i * 1e18);
                bondsOpen += i * 1e18;
            }
        }
        assertEq(
            oracle.getTVLByOwnerOfShares(address(bond), holder),
            2 * NAV_IN_CASH + cashOpen + bondsOpen * NAV_IN_CASH / 1e18
        );
        uint8[8] memory order = [7, 2, 5, 8, 1, 4, 3, 6];
        uint256 walletBonds = 2e18;
        vm.startPrank(admin);
        for (uint256 k; k < 8; ++k) {
            uint256 id = order[k];
            GyldInTransitRegistry.Lot memory l = transit.getLot(id);
            uint256 half = l.open / 2;
            if (l.kind == GyldInTransitRegistry.LotKind.CASH_OUT) {
                bond.mint(_recv(holder), half * 1e12); // the mint lands in the receiver first (1 bond per 1.00)
                transit.settleMint(id, half, half * 1e12, bytes32(id));
                walletBonds += half * 1e12;
                cashOpen -= half;
            } else {
                bond.mint(_recv(holder), half); // the returned bonds land in the receiver first
                walletBonds += half;
                transit.settleReturn(id, half, bytes32(id));
                bondsOpen -= half;
            }
            assertEq(
                oracle.getTVLByOwnerOfShares(address(bond), holder),
                (walletBonds + bondsOpen) * NAV_IN_CASH / 1e18 + cashOpen,
                "wallet plus open after each settle"
            );
        }
        vm.stopPrank();
        assertEq(transit.cashOut(holder, address(bond)), cashOpen);
        assertEq(transit.bondsOut(holder, address(bond)), bondsOpen);
    }

    /// @dev The three do-not-push signals are plain flags. Staleness never moves value. A PROPOSED write-down is
    ///      recognised at once (the delay is a review period, not a head start for whoever reads the event), and a
    ///      cancel restores it; the execute itself then changes nothing.
    function test_PauseSignals_StaleAndPendingImpairment_ProvisionalRecognition() public {
        bond.mint(holder, 1e18);
        _cashOut(100e6);
        uint256 v = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertFalse(oracle.hasPendingImpairment(address(bond), holder));
        vm.prank(admin);
        transit.proposeManualSettle(1, 100e6, bytes32("imp"));
        assertTrue(oracle.hasPendingImpairment(address(bond), holder), "pending impairment flagged");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), v - 100e6, "the proposal is priced in now");
        assertEq(oracle.getTVL(address(bond)), 1 * NAV_IN_CASH, "getTVL nets it too");
        vm.prank(admin);
        transit.cancelManualSettle(1);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), v, "a cancel restores the value");
        vm.warp(block.timestamp + AGE + 1);
        navFeed.setLatestAnswer(NAV_ANSWER);
        assertTrue(oracle.hasStaleTransit(address(bond), holder));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), v, "stale changes nothing");
        vm.prank(admin);
        transit.proposeManualSettle(1, 100e6, bytes32("imp"));
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), v - 100e6, "re-proposed: priced in again");
        vm.warp(block.timestamp + transit.MANUAL_SETTLE_DELAY());
        navFeed.setLatestAnswer(NAV_ANSWER);
        vm.prank(admin);
        transit.executeManualSettle(1);
        assertFalse(oracle.hasPendingImpairment(address(bond), holder));
        assertFalse(oracle.hasStaleTransit(address(bond), holder), "nothing open any more");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), v - 100e6, "the execute is not a second step");
        // feature off: all flags are false
        GyldBondYieldSourceOracle off = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry), address(0));
        assertFalse(off.hasPendingImpairment(address(bond), holder));
        assertFalse(off.hasUnsettledDelivery(address(bond), holder));
    }

    /// @dev Lazy NAV rescues a CASH-ONLY position only: wallet bonds, or bonds in transit, still need the feed, so a
    ///      suspended instrument reverts for them (and getTVL always, since supply is priced).
    function test_TVL_WalletBondsPlusCashOnlyTransit_SuspendedReverts() public {
        bond.mint(holder, 1e18);
        _cashOut(100e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVL(address(bond));
        address cashOnly = address(0xCA54);
        vm.prank(admin);
        transit.setDestinations(cashOnly, address(0xD5), holding);
        vm.prank(cashOnly);
        transit.recordCashOut(address(bond), address(cash), 5e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), cashOnly), 5e6, "cash-only still prices");
    }
}
