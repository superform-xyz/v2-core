// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// Superform
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldTradeGuardHook } from "../../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockGyldNavFeed } from "../../../mocks/gyld/MockGyldNavFeed.sol";

/// @dev A sequencer uptime feed whose index-3 word (the one the repo's oracles read as `startedAt`) is fully
///      settable, including to zero and to a future timestamp.
contract MockSettableSequencer {
    int256 private _answer;
    uint256 private _startedAt;

    constructor(uint256 startedAt_) {
        _startedAt = startedAt_;
    }

    function setStartedAt(uint256 startedAt_) external {
        _startedAt = startedAt_;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, _answer, _startedAt, _startedAt, 1);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}

/// @dev A bond token whose `decimals()` can be changed after registration, standing in for a token behind an
///      upgradeable proxy.
contract MockMutableDecimalsToken {
    uint8 public decimals;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setDecimals(uint8 decimals_) external {
        decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

/// @title GyldBondReviewFindingsTest
/// @notice Verification that the security-review findings are FIXED. This file began as a set of
///         reproductions asserting the buggy behaviour; each test has since been flipped to assert the
///         corrected behaviour, so it now reads as a regression suite for those fixes.
/// @dev Each test still names the finding it came from, so the history is traceable from the code.
contract GyldBondReviewFindingsTest is Test {
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    GyldTradeGuardHook internal guard;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;
    MockAggregator internal cashFeed;
    MockGyldNavFeed internal nativeFeed;

    address internal admin = address(0xA11CE);
    address internal holder = address(0xB0DB01DE2);

    uint8 internal KIND_CHAINLINK;
    uint8 internal KIND_NATIVE;

    uint256 internal constant MAX_PUB_AGE = 2 hours;
    /// @dev The new named code for a zero or future clock (F3/F7)
    uint8 internal constant INVALID_TS = uint8(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP);
    uint256 internal constant MAX_OBS_AGE = 2 days;

    function setUp() public {
        vm.warp(1_800_000_000);
        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry));
        guard = new GyldTradeGuardHook(address(oracle));
        KIND_CHAINLINK = registry.FEED_KIND_CHAINLINK();
        KIND_NATIVE = registry.FEED_KIND_GYLD_NATIVE();

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("AUSD", "AUSD", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(102.37e8);
        cashFeed = new MockAggregator(8);
        cashFeed.setLatestAnswer(0.9985e8);
        nativeFeed = new MockGyldNavFeed(8);
        nativeFeed.setFreshNav(address(bond), 102.37e8);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _cfg() internal view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        cfg.bondToken = address(bond);
        cfg.cashToken = address(cash);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = KIND_CHAINLINK;
        cfg.maxObservationAge = MAX_OBS_AGE;
        cfg.maxPublicationAge = MAX_PUB_AGE;
    }

    function _register(GyldBondRegistry.InstrumentConfig memory cfg) internal {
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    function _setRecoveryNav(uint256 value) internal {
        vm.prank(admin);
        registry.proposeRecoveryNav(address(bond), value);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(admin);
        registry.executeRecoveryNav(address(bond));
    }

    function _guardLeaf() internal view returns (bytes memory) {
        return
            abi.encodePacked(bytes32(0), bytes20(address(bond)), bytes20(address(cash)), MAX_OBS_AGE, uint256(30 days));
    }

    /*//////////////////////////////////////////////////////////////
       P1-1 — THE SUSPENSION SWITCH IS INERT ONCE A RECOVERY NAV IS SET
    //////////////////////////////////////////////////////////////*/

    /// @dev FIXED (F2). `navSuspended` is now checked BEFORE the recovery override in both `_nav` and
    ///      `previewNav`, so the un-timelocked incident switch works even once a terminal value is installed.
    ///      The contradictory "suspended AND OK" status is gone.
    function test_Fixed_F2_SuspensionNowOutranksTheRecoveryOverride() public {
        _register(_cfg());
        _setRecoveryNav(40e6); // 40.00 cash per bond
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        GyldBondYieldSourceOracle.NavStatus memory status = oracle.previewNav(address(bond));
        assertTrue(status.suspended, "governance suspended");
        assertEq(
            status.failureCode,
            uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED),
            "and the status now AGREES with the flag"
        );
        assertEq(status.nav, 0, "no price is published while suspended");

        // Every value read now refuses.
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getPricePerShare(address(bond));
        bond.mint(holder, 1500e18);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
    }

    /// @dev And the override still works when the instrument is NOT suspended, which is the whole point of
    ///      having it: a defaulted-but-unsuspended instrument values at its agreed recovery.
    function test_Fixed_F2_RecoveryOverrideStillAppliesWhenNotSuspended() public {
        _register(_cfg());
        _setRecoveryNav(40e6);
        assertEq(oracle.getPricePerShare(address(bond)), 40e6, "the override is in force");
        assertEq(oracle.previewNav(address(bond)).failureCode, 0);
    }

    /// @dev FIXED (F2). The guard now reads `status.suspended` DIRECTLY, defensively, rather than inferring
    ///      it from the oracle's failure code. So it refuses even if the oracle's ordering ever regresses.
    function test_Fixed_F2_GuardRefusesASuspendedInstrument() public {
        _register(_cfg());
        _setRecoveryNav(40e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        assertEq(
            guard.previewTradable(_guardLeaf(), holder),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED)),
            "the preview reports suspension"
        );
        vm.expectRevert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        guard.build(address(0), holder, _guardLeaf());
    }

    /// @dev FIXED (F2). The batch read's `succeeded` mask is the pipeline's decline-to-publish safety net.
    ///      A suspended row now reports FAILURE, so the net works again even with an override installed.
    function test_Fixed_F2_BatchReadReportsASuspendedRowAsUnsuccessful() public {
        _register(_cfg());
        _setRecoveryNav(40e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        bond.mint(holder, 1e18);

        address[] memory sources = new address[](1);
        sources[0] = address(bond);
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = holder;

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertFalse(ok[0][0], "a suspended instrument declines to publish");
        assertEq(tvls[0][0], 0);
    }

    /*//////////////////////////////////////////////////////////////
          P1-2 — recoveryNav IS UNVALIDATED AND UNIT-AMBIGUOUS
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `proposeRecoveryNav` validates nothing: not non-zero, not against the circuit-breaker
    ///      bounds, not against the live feed. `_nav` then returns it RAW, skipping `_toCashUnits`, so it must
    ///      be entered in CASH decimals (6) while every other NAV number the same operator handles is in FEED
    ///      decimals (8). A feed-style figure is accepted and marks the position 100x too high.
    ///      Proposed fix: bound `recoveryNav` against the instrument's own scale and bounds, and re-validate
    ///      at execute time rather than only at propose time.
    function test_Finding_P1_2_RecoveryNavAcceptsAFeedStyleFigureAndMarks100xTooHigh() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 90e8;
        cfg.navMaxAnswer = 110e8; // bounds that WOULD have caught this, in feed decimals
        _register(cfg);

        _setRecoveryNav(40e8); // the operator typed the feed-style 40.00, i.e. 4_000_000_000
        bond.mint(holder, 1500e18);

        assertEq(oracle.getPricePerShare(address(bond)), 40e8, "accepted verbatim, 4000.00 cash per bond");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 6_000_000e6, "6,000,000 cash");
        // The correctly denominated figure would have been 40e6, marking 60,000 cash.
        assertEq(uint256(6_000_000e6) / uint256(60_000e6), 100, "a 100x over-mark, inside the breaker");
    }

    /// @dev CONFIRMED. The circuit breaker is applied only to a raw FEED answer in `_readNavFeed`, never to
    ///      `recoveryNav`, so no bound configuration can catch a mis-denominated override.
    function test_Finding_P1_2_CircuitBreakerNeverAppliesToRecoveryNav() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 1;
        cfg.navMaxAnswer = 2; // an absurdly tight breaker
        _register(cfg);

        _setRecoveryNav(type(uint128).max);
        assertEq(oracle.getPricePerShare(address(bond)), type(uint128).max, "the breaker is not consulted");
    }

    /// @dev FIXED (F4). An explicit `recoveryNavSet` flag now enables the override, so a recovery of ZERO is
    ///      a representable total loss rather than being indistinguishable from clearing it. Executing a zero
    ///      recovery no longer resumes the feed on a defaulted instrument.
    function test_Fixed_F4_ZeroRecoveryMeansTotalLossNotNoOverride() public {
        _register(_cfg());
        _setRecoveryNav(40e6);
        assertEq(oracle.getPricePerShare(address(bond)), 40e6);

        _setRecoveryNav(0);
        navFeed.setUpdatedAt(block.timestamp); // the two timelock warps aged the feed; republish
        assertTrue(registry.getInstrumentConfig(address(bond)).recoveryNavSet, "the override is STILL in force");

        // The ASSET side stays readable, so a worthless holding remains visible and marks at zero rather
        // than silently reverting to a par feed price.
        assertEq(oracle.getPricePerShare(address(bond)), 0, "marked at zero, not at the feed");
        bond.mint(holder, 1500e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 0, "a worthless holding is visible");
        assertEq(oracle.getAssetOutput(address(bond), address(cash), 1500e18), 0);

        // The SHARE side divides by the price, so zero is a named refusal rather than a panic.
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getShareOutput(address(bond), address(cash), 1e6);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getWithdrawalShareOutput(address(bond), address(cash), 1e6);

        // And it is not a tradable price.
        assertEq(
            oracle.previewNav(address(bond)).failureCode,
            uint8(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE),
            "not tradable"
        );
        vm.expectRevert(GyldTradeGuardHook.INVALID_PRICE.selector);
        guard.build(address(0), holder, _guardLeaf());
    }

    /// @dev And clearing is now a SEPARATE, explicit action that returns the instrument to its feed.
    function test_Fixed_F4_ClearingIsDistinctFromRecordingATotalLoss() public {
        _register(_cfg());
        _setRecoveryNav(40e6);

        vm.prank(admin);
        registry.clearRecoveryNav(address(bond));
        assertFalse(registry.getInstrumentConfig(address(bond)).recoveryNavSet, "override removed");

        navFeed.setUpdatedAt(block.timestamp);
        assertEq(oracle.getPricePerShare(address(bond)), 102.37e6, "the feed is authoritative again");
    }

    /// @dev Clearing an override that was never set is a mistake worth naming.
    function test_Fixed_F4_ClearingWhenNothingIsSetReverts() public {
        _register(_cfg());
        vm.expectRevert(GyldBondRegistry.RECOVERY_NOT_SET.selector);
        vm.prank(admin);
        registry.clearRecoveryNav(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
      P1-3 — A FUTURE PUBLICATION TIMESTAMP DISABLES THE FRESHNESS CHECK
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED, and worse than the panic fixed on 2026-11-02. `_checkFreshness` only compares the ages
    ///      when `block.timestamp > publishedAt`, so a future-dated publication is treated as age zero FOREVER
    ///      rather than as a failure. On a Chainlink-kind feed `observedAt` is hardcoded to zero, so the
    ///      observation check is skipped too: such an instrument has NO freshness check at all.
    ///      Proposed fix: reject a future timestamp outright with a dedicated failure code, on both clocks and
    ///      in all four places (oracle `_checkFreshness`, oracle `_toCashUnits`, guard `_requireTradable`,
    ///      guard `previewTradable`).
    /// @dev FIXED (F3). A future publication time is now rejected as unusable data instead of being read as
    ///      age zero. Previously the age comparison was skipped whenever the stamp was ahead of the chain,
    ///      so a feed stamped into the future bypassed the staleness bound for as long as the stamp lasted.
    function test_Fixed_F3_FutureDatedPublicationIsRejected() public {
        _register(_cfg());
        navFeed.setUpdatedAt(block.timestamp + 3650 days);
        assertEq(oracle.previewNav(address(bond)).failureCode, INVALID_TS, "a future stamp is invalid, not fresh");
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_TIMESTAMP.selector);
        oracle.getPricePerShare(address(bond));
    }

    /// @dev A zero publication time is rejected too, which is what an uninitialised feed reports.
    function test_Fixed_F3_ZeroPublicationTimeIsRejected() public {
        _register(_cfg());
        navFeed.setUpdatedAt(0);
        assertEq(oracle.previewNav(address(bond)).failureCode, INVALID_TS);
    }

    /// @dev And the normal path is untouched: a stamp at or inside the bound still passes.
    function test_Fixed_F3_CurrentPublicationStillPasses() public {
        _register(_cfg());
        navFeed.setUpdatedAt(block.timestamp - MAX_PUB_AGE);
        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "the bound itself is still fresh");
    }

    /// @dev CONFIRMED. The guard inherits the same one-sided comparison, so it keeps authorising trades.
    /// @dev FIXED (F3) in the guard too, on both its paths.
    function test_Fixed_F3_GuardRejectsAFutureDatedNav() public {
        _register(_cfg());
        navFeed.setUpdatedAt(block.timestamp + 3650 days);

        assertEq(guard.previewTradable(_guardLeaf(), holder), INVALID_TS, "the preview names it");
        vm.expectRevert(GyldTradeGuardHook.INVALID_TIMESTAMP.selector);
        guard.build(address(0), holder, _guardLeaf());
    }

    /// @dev CONFIRMED on the cash feed too: `_toCashUnits` carries the identical one-sided guard.
    function test_Fixed_F3_FutureDatedCashFeedIsRejected() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg);

        cashFeed.setUpdatedAt(block.timestamp + 3650 days);
        navFeed.setUpdatedAt(block.timestamp); // keep the NAV side fresh to isolate the cash side

        // FIXED (F3): the cash price sits in the DENOMINATOR, so accepting a future stamp there was the most
        // damaging version of this bug.
        assertEq(oracle.previewNav(address(bond)).failureCode, INVALID_TS, "the cash clock is validated too");
    }

    /*//////////////////////////////////////////////////////////////
                 P2-7 — THE SEQUENCER CHECK'S TWO GAPS
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `_sequencerOk` computes `block.timestamp - startedAt` unguarded, so a sequencer feed
    ///      reporting a future timestamp PANICS. `previewNav` is documented as never reverting and the guard's
    ///      preview depends on that, so this is the same class as the bug fixed one layer up on 2026-11-02,
    ///      in the copy that was missed.
    ///      Proposed fix: `if (startedAt == 0 || startedAt > block.timestamp) return false;`
    function test_Fixed_F7_FutureSequencerTimestampIsRejectedNotPanicking() public {
        MockSettableSequencer seq = new MockSettableSequencer(block.timestamp);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.sequencerUptimeFeed = address(seq);
        cfg.gracePeriod = 1 hours;
        _register(cfg);

        seq.setStartedAt(block.timestamp + 1);
        // FIXED (F7): reported as a named failure instead of panicking, so the preview stays total.
        assertEq(oracle.previewNav(address(bond)).failureCode, INVALID_TS, "no panic, a reason code");
        assertEq(guard.previewTradable(_guardLeaf(), holder), INVALID_TS, "and the guard's preview survives");
    }

    /// @dev CONFIRMED. Chainlink uses `startedAt == 0` to signal a round that has not started, i.e. round
    ///      data is unavailable. `block.timestamp - 0 >= gracePeriod` is true, so the oracle reads that as
    ///      "sequencer up and past its grace period": the protection is inverted exactly when the data is
    ///      missing.
    function test_Fixed_F7_ZeroSequencerTimestampIsRejected() public {
        MockSettableSequencer seq = new MockSettableSequencer(0);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.sequencerUptimeFeed = address(seq);
        cfg.gracePeriod = 1 hours;
        _register(cfg);

        // FIXED (F7): zero is Chainlink's "round has not started", now rejected rather than read as an
        // ancient healthy timestamp.
        assertEq(oracle.previewNav(address(bond)).failureCode, INVALID_TS, "an unstarted round is invalid");
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_TIMESTAMP.selector);
        oracle.getPricePerShare(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
        P2-1 — THE CASH FEED IS A DIVISOR WITH AN OPTIONAL BREAKER
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `_validateRegistration` mandates a `cashFeed` whenever the NAV is USD-denominated, but
    ///      `_validateBounds(0, 0)` passes, so the feed's circuit breaker defaults to disabled. The cash price
    ///      is the DIVISOR in `_toCashUnits`, so a glitch toward zero amplifies without bound while the NAV in
    ///      the numerator only scales linearly.
    ///      Proposed fix: require non-zero cash bounds whenever `navIsUsdDenominated`.
    function test_Finding_P2_1_UnboundedCashFeedDivisorAmplifiesAGlitch() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg);
        bond.mint(holder, 1500e18);

        uint256 healthy = oracle.getTVLByOwnerOfShares(address(bond), holder);

        cashFeed.setLatestAnswer(1); // 1e-8 USD per cash unit
        uint256 glitched = oracle.getTVLByOwnerOfShares(address(bond), holder);

        assertGt(glitched / healthy, 99_000_000, "roughly a hundred-million-fold over-mark");
        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "reported as a healthy row");
    }

    /// @dev And the same glitch IS caught once bounds are configured, which is the available mitigation today.
    function test_Finding_P2_1_ConfiguredCashBoundsCatchTheGlitch() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        cfg.cashMinAnswer = 0.95e8;
        cfg.cashMaxAnswer = 1.05e8;
        _register(cfg);

        cashFeed.setLatestAnswer(1);
        assertEq(
            oracle.previewNav(address(bond)).failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED)
        );
    }

    /*//////////////////////////////////////////////////////////////
       P2-2 — "CASH IS ONE DOLLAR" IS STILL CONFIGURABLE, IN REVERSE
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. The registry rejects a USD-denominated NAV with no cash feed. The symmetric mistake is
    ///      unchecked: register a feed that quotes USD with `navIsUsdDenominated = false`, and the oracle
    ///      rescales it straight into cash decimals, i.e. treats one dollar as one cash unit. No cash feed is
    ///      needed, and nothing on-chain can detect it.
    ///      Proposed fix: this is an unverifiable operator assertion. Say so in the NatSpec and make it a
    ///      two-person deployment check; the registry cannot catch it.
    function test_Finding_P2_2_UsdFeedConfiguredAsCashDenominatedIsAccepted() public {
        // Exactly the same feed, registered WITHOUT the USD flag and with no cash feed at all.
        _register(_cfg());
        bond.mint(holder, 1500e18);

        uint256 assumedAtPar = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertEq(assumedAtPar, 153_555e6, "one dollar treated as one cash unit");

        // What the correctly configured instrument would have marked, at the 0.9985 cash price. Computed
        // from variables, not literals, so the division floors at runtime instead of being a rational const.
        uint256 navAnswer = 10_237_000_000; // 102.37 at 8 decimals
        uint256 cashPrice = 99_850_000; // 0.9985 at 8 decimals
        uint256 navInCash = (navAnswer * 1e8 * 1e6) / (1e8 * cashPrice);
        uint256 correct = (1500e18 * navInCash) / 1e18;
        assertGt(correct, assumedAtPar, "the mis-configuration understates the position");
        assertApproxEqRel(correct - assumedAtPar, uint256(230.6e6), uint256(0.01e18), "~230 cash on 1500 bonds");
    }

    /// @dev CONFIRMED. `executeFeedChange` can change the feed and its kind but NOT `navIsUsdDenominated`,
    ///      `cashFeed`, or the circuit-breaker bounds, so there is no supported migration between
    ///      denominations. The only remedy is deregister and re-register, which the registry's own NatSpec
    ///      forbids while a position is live.
    function test_Finding_P2_2_NoMigrationPathBetweenDenominations() public {
        _register(_cfg());
        MockAggregator usdFeed = new MockAggregator(8);
        usdFeed.setLatestAnswer(102.37e8);

        vm.prank(admin);
        registry.proposeFeedChange(address(bond), address(usdFeed), KIND_CHAINLINK, 0, 0);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(admin);
        registry.executeFeedChange(address(bond));

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertEq(stored.navFeed, address(usdFeed), "the feed changed");
        assertFalse(stored.navIsUsdDenominated, "but the denomination flag cannot be changed");
        assertEq(stored.cashFeed, address(0), "and no cash feed can be added");
    }

    /*//////////////////////////////////////////////////////////////
          P1-5 / P2-4 — INSTANT, FAIL-OPEN VALUATION CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `setStalenessBounds` is role-gated but has no timelock and no suspension side effect,
    ///      and it moves the mark in the FAIL-OPEN direction. The guard's leaf-committed bounds protect signed
    ///      TRADES, not the oracle read that the price-per-share pipeline uses, so loosening re-marks the
    ///      vault instantly while every signed leaf still carries a tight bound.
    ///      Proposed fix: allow tightening instantly, timelock or force-suspend on loosening.
    function test_Finding_P1_5_LooseningStalenessBoundsReMarksInstantly() public {
        _register(_cfg());
        navFeed.setUpdatedAt(block.timestamp - 29 days);

        assertEq(
            oracle.previewNav(address(bond)).failureCode,
            uint8(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE),
            "a 29-day-old NAV is stale under the 2-hour bound"
        );

        vm.prank(admin);
        registry.setStalenessBounds(address(bond), 30 days, 30 days);

        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "one instant call makes it current");
        assertEq(oracle.getPricePerShare(address(bond)), 102.37e6);
        assertFalse(registry.getInstrumentConfig(address(bond)).navSuspended, "and nothing was suspended");
    }

    /// @dev CONFIRMED. `refreshScales` re-reads `decimals()` live, instantly and without suspending, so a
    ///      token behind an upgradeable proxy that reports a different `decimals()` moves the mark by a power
    ///      of ten on one role-gated call.
    ///      Proposed fix: force-suspend on any scale change, as `executeFeedChange` already does.
    function test_Finding_P2_4_RefreshScalesCanReMarkByAPowerOfTenInstantly() public {
        MockMutableDecimalsToken proxyBond = new MockMutableDecimalsToken(18);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        feed.setFreshNav(address(proxyBond), 1e8);

        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(proxyBond);
        cfg.navFeed = address(feed);
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);

        proxyBond.mint(holder, 1e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(proxyBond), holder), 1e6, "one bond marked at 1.00");

        proxyBond.setDecimals(12);
        vm.prank(admin);
        registry.refreshScales(address(proxyBond));

        assertEq(
            oracle.getTVLByOwnerOfShares(address(proxyBond), holder),
            1e12,
            "the same balance is now marked a million times higher"
        );
        assertFalse(registry.getInstrumentConfig(address(proxyBond)).navSuspended, "with no suspension");
    }

    /// @dev CONFIRMED. The circuit-breaker bounds are write-once: no setter exists, and the timelocked
    ///      feed-change path does not carry them. A feed swap to a different-decimals feed therefore leaves
    ///      the bounds in the OLD feed's units, tripping the breaker on every read, permanently. This fails
    ///      closed, so it is an availability problem, but the only on-chain exit is deregistration, which the
    ///      registry's own NatSpec forbids while a position is live.
    ///      Proposed fix: carry the bounds in the feed-change payload, or force-suspend and require the live
    ///      answer to sit inside the stored bounds after any scale change.
    function test_Fixed_F6_FeedSwapCarriesItsOwnBounds() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 90e8;
        cfg.navMaxAnswer = 110e8; // sane bounds, in the 8-decimal feed's units
        _register(cfg);
        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "healthy before the swap");

        MockAggregator feed18 = new MockAggregator(18);
        feed18.setLatestAnswer(102.37e18); // the same price, at 18 decimals
        vm.startPrank(admin);
        // FIXED (F6): the proposal carries bounds in the NEW feed's units, so a scale change is expressible.
        registry.proposeFeedChange(address(bond), address(feed18), KIND_CHAINLINK, 90e18, 110e18);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeFeedChange(address(bond));
        registry.setNavSuspended(address(bond), false); // the force-suspension still applies, then resume
        vm.stopPrank();
        feed18.setUpdatedAt(block.timestamp); // the timelock warp aged it; publish a current round

        GyldBondRegistry.InstrumentConfig memory stored = registry.getInstrumentConfig(address(bond));
        assertEq(stored.navFeedScale, 1e18, "scale refreshed");
        assertEq(stored.navMaxAnswer, 110e18, "AND the bounds came with it");
        assertEq(oracle.previewNav(address(bond)).failureCode, 0, "an economically identical feed values normally");
        assertEq(oracle.getPricePerShare(address(bond)), 102.37e6, "same price, new scale");
    }

    /*//////////////////////////////////////////////////////////////
        P2-3 — PROPOSALS HAVE NO CANCEL AND NO EXPIRY WINDOW
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `cancelDeregisterInstrument` exists; there is no `cancelRecoveryNav` and no
    ///      `cancelFeedChange`, and neither has an upper execution window. A proposal made during a scare
    ///      months ago stays executable forever, so the two-day delay gives no protection against a stale
    ///      proposal landing as an instant mark jump.
    ///      Proposed fix: add cancel functions and a grace window, as OpenZeppelin's TimelockController does.
    function test_Finding_P2_3_AMonthsOldRecoveryNavProposalIsStillExecutable() public {
        _register(_cfg());
        vm.prank(admin);
        registry.proposeRecoveryNav(address(bond), 40e6);

        // Six months pass. The instrument recovered; the feed reports a healthy price.
        vm.warp(block.timestamp + 180 days);
        navFeed.setUpdatedAt(block.timestamp);
        bond.mint(holder, 1500e18);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 153_555e6, "marked off the live feed");

        vm.prank(admin);
        registry.executeRecoveryNav(address(bond));
        assertEq(
            oracle.getTVLByOwnerOfShares(address(bond), holder),
            60_000e6,
            "a 61 percent mark-down from one stale proposal, with no delay"
        );
    }

    function test_Finding_P2_3_NoCancelFunctionExistsForEitherTimelockedChange() public {
        _register(_cfg());
        vm.startPrank(admin);
        registry.proposeRecoveryNav(address(bond), 40e6);
        registry.proposeFeedChange(address(bond), address(cashFeed), KIND_CHAINLINK, 0, 0);
        vm.stopPrank();

        // The only way to neutralise either is to re-propose, which restarts the clock but cannot clear it.
        vm.prank(admin);
        registry.proposeRecoveryNav(address(bond), 0);
        assertGt(registry.pendingRecoveryNavAt(address(bond)), 0, "still pending, just with a zero value");
        assertGt(registry.pendingFeedAt(address(bond)), 0, "and the feed change cannot be withdrawn at all");
    }

    /*//////////////////////////////////////////////////////////////
                  P2-5 — ONE BOUND FOR TWO UNRELATED FEEDS
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `_toCashUnits` reuses `cfg.maxPublicationAge` for the cash feed. A bond NAV wants a
    ///      tight bound; a Chainlink stablecoin feed has a 24-hour heartbeat. With a 2-hour bound every read
    ///      fails on the cash side for a perfectly healthy instrument, and the operational fix is to loosen
    ///      the shared field, which simultaneously loosens the NAV bound. This is the forcing function that
    ///      makes the fail-open control above get used in production.
    ///      Proposed fix: a separate `maxCashPublicationAge`.
    function test_Finding_P2_5_SharedPublicationBoundBreaksAHealthyInstrument() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg); // maxPublicationAge is 2 hours, right for a bond NAV

        // The NAV is fresh; the cash feed simply has not had a round in three hours, which is normal.
        navFeed.setUpdatedAt(block.timestamp);
        cashFeed.setUpdatedAt(block.timestamp - 3 hours);

        assertEq(
            oracle.previewNav(address(bond)).failureCode,
            uint8(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED),
            "a healthy instrument is unpriceable because of the other feed's cadence"
        );
    }

    /*//////////////////////////////////////////////////////////////
          P3-2 — A BOND CAN BE REGISTERED AS ANOTHER BOND'S CASH
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `_validateRegistration` rejects only `bondToken == cashToken`. Registering instrument A
    ///      with instrument B's bond token as its cash denomination is accepted, after which the trade hook's
    ///      pair gate approves the (A, B) pair, contradicting its NatSpec claim to reject a bond-for-bond
    ///      trade. Governance misconfiguration only, hence low severity.
    ///      Proposed fix: reject a `cashToken` that is itself a registered bond.
    function test_Finding_P3_2_ABondCanBeRegisteredAsAnotherBondsCashDenomination() public {
        MockERC20 bondB = new MockERC20("Bond B", "BB", 18);
        MockGyldNavFeed feedB = new MockGyldNavFeed(8);
        feedB.setFreshNav(address(bondB), 50e8);

        _register(_cfg()); // A against real cash

        GyldBondRegistry.InstrumentConfig memory cfgB = _cfg();
        cfgB.bondToken = address(bondB);
        cfgB.cashToken = address(bond); // B's "cash" is A's bond token
        cfgB.navFeed = address(feedB);
        cfgB.navFeedKind = KIND_NATIVE;
        _register(cfgB);

        assertTrue(registry.isApprovedPair(address(bondB), address(bond)), "a bond-for-bond pair is approved");
    }

    /*//////////////////////////////////////////////////////////////
                P3-1 — A DECLARED ERROR THAT IS NEVER USED
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `FUTURE_OBSERVATION` is declared on the oracle but never reverted; a future observation
    ///      is reported as `ZERO_OR_NEGATIVE` and surfaces as `INVALID_PRICE`. A monitor reading the code will
    ///      log "zero or negative price" when the real signal is a timestamp from the future.
    ///      Proposed fix: add the enum member, return it, and revert with the declared error.
    function test_Fixed_FutureObservationHasItsOwnFailureCode() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(nativeFeed);
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);

        nativeFeed.setNav(address(bond), 102.37e8, block.timestamp + 1 days, block.timestamp);
        // FIXED: a future valuation now gets its own named code instead of being reported as a zero price.
        assertEq(oracle.previewNav(address(bond)).failureCode, INVALID_TS, "named for what it is");
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_TIMESTAMP.selector);
        oracle.getPricePerShare(address(bond));
    }
}
