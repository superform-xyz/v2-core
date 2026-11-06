// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// Superform
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../../../src/interfaces/accounting/IYieldSourceOracle.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockGyldNavFeed } from "../../../mocks/gyld/MockGyldNavFeed.sol";

/// @dev Sequencer uptime stand-in with the two clocks SEPARATE. Index 2 is `startedAt`, the status
///      transition time, which is what a grace period is measured from and what the oracle now reads. Index
///      3 is `updatedAt`, the round's publication time. An earlier version of this mock returned the same
///      value in both positions, which made it impossible for any test to notice which one the oracle used.
contract MockSequencer {
    int256 private _answer;
    uint256 private _startedAt;
    uint256 private _updatedAt;

    constructor() {
        _startedAt = block.timestamp;
        _updatedAt = block.timestamp;
    }

    function setAnswer(int256 answer) external {
        _answer = answer;
    }

    function setStartedAt(uint256 startedAt) external {
        _startedAt = startedAt;
    }

    function setUpdatedAt(uint256 updatedAt) external {
        _updatedAt = updatedAt;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, _answer, _startedAt, _updatedAt, 1);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}

/// @title GyldBondYieldSourceOracleTest
/// @notice Unit coverage for `GyldBondYieldSourceOracle`. The organising idea under test is the staleness
///         split: identity reads are total, value reads revert, and `previewNav` reports a reason code for
///         every condition that would make a value read fail.
contract GyldBondYieldSourceOracleTest is Test {
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals
    MockAggregator internal navFeed; // 8 decimals, Chainlink-style
    MockGyldNavFeed internal nativeFeed; // 8 decimals, both clocks
    MockAggregator internal cashFeed; // 8 decimals, cash/USD
    MockSequencer internal sequencer;

    address internal admin = address(0xA11CE);
    address internal holder = address(0xB0DB01DE2);
    address internal ledgerConfig = address(0xC0FFEE);

    uint8 internal KIND_CHAINLINK;
    uint8 internal KIND_NATIVE;

    /// @dev One whole bond is worth 1.05 cash units; the feed reports with 8 decimals.
    int256 internal constant NAV_ANSWER = 1.05e8;
    /// @dev 1.05 in the cash token's 6 decimals
    uint256 internal constant NAV_IN_CASH = 1.05e6;

    uint256 internal constant MAX_OBS_AGE = 2 days;
    uint256 internal constant MAX_PUB_AGE = 1 days;

    function setUp() public {
        // Start well past the epoch so "N days ago" timestamps never underflow.
        vm.warp(1_800_000_000);

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(ledgerConfig, address(registry));

        KIND_CHAINLINK = registry.FEED_KIND_CHAINLINK();
        KIND_NATIVE = registry.FEED_KIND_GYLD_NATIVE();

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        nativeFeed = new MockGyldNavFeed(8);
        cashFeed = new MockAggregator(8);
        sequencer = new MockSequencer();

        navFeed.setLatestAnswer(NAV_ANSWER);
        nativeFeed.setFreshNav(address(bond), uint256(NAV_ANSWER));
        cashFeed.setLatestAnswer(1e8); // 1 cash = 1 USD
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _cfg() internal view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = KIND_CHAINLINK;
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = MAX_OBS_AGE;
        cfg.maxPublicationAge = MAX_PUB_AGE;
    }

    function _register(GyldBondRegistry.InstrumentConfig memory cfg) internal {
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    /// @dev The default instrument: Chainlink-style feed already quoting NAV in cash terms, no sequencer.
    function _registerDefault() internal {
        _register(_cfg());
    }

    function _registerNative() internal {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(nativeFeed);
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);
    }

    function _suspend(bool suspended) internal {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), suspended);
    }

    function _preview() internal view returns (GyldBondYieldSourceOracle.NavStatus memory) {
        return oracle.previewNav(address(bond));
    }

    function _assertFailure(GyldBondYieldSourceOracle.NavFailure expected) internal view {
        assertEq(_preview().failureCode, uint8(expected), "previewNav failure code");
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(oracle.REGISTRY()), address(registry));
        assertEq(oracle.SUPER_LEDGER_CONFIGURATION(), ledgerConfig);
    }

    function test_Constructor_RevertIf_RegistryZero() public {
        vm.expectRevert(GyldBondYieldSourceOracle.ZERO_ADDRESS.selector);
        new GyldBondYieldSourceOracle(ledgerConfig, address(0));
    }

    /// @dev The oracle mirrors `GyldBondRegistry.FEED_KIND_GYLD_NATIVE` as a private constant, so the two can
    ///      drift. Pin them together behaviourally: register with the REGISTRY's native kind and give the
    ///      instrument a feed that ONLY answers `latestNav`. If the mirror disagreed, the oracle would take
    ///      the Chainlink branch and the read would revert instead of returning the native NAV.
    function test_MirroredFeedKindAgreesWithRegistry() public {
        assertEq(KIND_NATIVE, 1, "registry's native kind");
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(nativeFeed); // has latestNav + decimals, has NO latestRoundData
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);

        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH, "native branch taken");
    }

    /*//////////////////////////////////////////////////////////////
                     IDENTITY READS — MUST NEVER REVERT
    //////////////////////////////////////////////////////////////*/

    function test_Decimals_NeverConsultsTheRegistry() public view {
        // Not registered at all, and still answers.
        assertEq(oracle.decimals(address(bond)), 18);
        assertEq(oracle.decimals(address(cash)), 6);
    }

    /// @dev "Preserve visible holdings": a suspended instrument still reports what a strategy holds.
    function test_GetBalanceOfOwner_WorksWhenSuspended() public {
        bond.mint(holder, 7e18);
        _registerDefault();
        _suspend(true);
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 7e18);
    }

    function test_GetBalanceOfOwner_WorksWhenUnregistered() public {
        bond.mint(holder, 3e18);
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), 3e18);
    }

    function test_PreviewNav_Unregistered_ReportsNotRegistered() public view {
        GyldBondYieldSourceOracle.NavStatus memory status = _preview();
        assertFalse(status.registered);
        assertEq(status.failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED));
        assertEq(status.nav, 0);
        assertEq(status.cashToken, address(0));
    }

    function test_PreviewNav_Healthy_ReportsOk() public {
        _registerDefault();
        GyldBondYieldSourceOracle.NavStatus memory status = _preview();
        assertTrue(status.registered);
        assertFalse(status.suspended);
        assertEq(status.failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.OK));
        assertEq(status.nav, NAV_IN_CASH);
        assertEq(status.cashToken, address(cash));
        assertEq(status.navFeed, address(navFeed));
        assertEq(status.publishedAt, block.timestamp);
        assertEq(status.observedAt, 0, "a Chainlink-style feed has no observation clock");
    }

    function test_PreviewNav_Suspended_ReportsSuspendedWithZeroNav() public {
        _registerDefault();
        _suspend(true);
        GyldBondYieldSourceOracle.NavStatus memory status = _preview();
        assertTrue(status.registered);
        assertTrue(status.suspended);
        assertEq(status.failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED));
        assertEq(status.nav, 0);
        assertEq(status.cashToken, address(cash), "identity survives suspension");
    }

    /*//////////////////////////////////////////////////////////////
                           VALUE READS — HEALTHY
    //////////////////////////////////////////////////////////////*/

    function test_GetPricePerShare_NonUsdFeed_RescalesToCashDecimals() public {
        _registerDefault();
        // 1.05 at feed scale 1e8 becomes 1.05 at cash scale 1e6.
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
    }

    function test_GetAssetOutput_RoundsDown() public {
        _registerDefault();
        // 3 bonds at 1.05 cash each
        assertEq(oracle.getAssetOutput(address(bond), address(cash), 3e18), 3 * NAV_IN_CASH);
        // address(0) means "whatever the configured cash is"
        assertEq(oracle.getAssetOutput(address(bond), address(0), 3e18), 3 * NAV_IN_CASH);
        // A dust share amount floors to zero rather than rounding up in the holder's favour.
        assertEq(oracle.getAssetOutput(address(bond), address(cash), 1), 0, "floored");
    }

    function test_GetAssetOutput_RevertIf_WrongAsset() public {
        _registerDefault();
        vm.expectRevert(IYieldSourceOracle.INVALID_BASE_ASSET.selector);
        oracle.getAssetOutput(address(bond), address(0xDEAD), 1e18);
    }

    function test_GetShareOutput_RoundsDown() public {
        _registerDefault();
        // 1.05 cash buys exactly one bond
        assertEq(oracle.getShareOutput(address(bond), address(cash), NAV_IN_CASH), 1e18);
        assertEq(oracle.getShareOutput(address(bond), address(0), NAV_IN_CASH), 1e18);
        // 2 cash units buys 1.904761... bonds, floored
        assertEq(oracle.getShareOutput(address(bond), address(cash), 2e6), (2e6 * 1e18) / NAV_IN_CASH);
    }

    function test_GetShareOutput_RevertIf_WrongAsset() public {
        _registerDefault();
        vm.expectRevert(IYieldSourceOracle.INVALID_BASE_ASSET.selector);
        oracle.getShareOutput(address(bond), address(0xDEAD), 1e6);
    }

    /// @dev Withdrawals round UP: the vault burns at least enough shares, never one too few.
    function test_GetWithdrawalShareOutput_RoundsUp() public {
        _registerDefault();
        uint256 floorShares = oracle.getShareOutput(address(bond), address(cash), 2e6);
        uint256 ceilShares = oracle.getWithdrawalShareOutput(address(bond), address(cash), 2e6);
        assertEq(ceilShares, floorShares + 1, "ceil is one wei of share above floor");
    }

    function test_GetWithdrawalShareOutput_RevertIf_WrongAsset() public {
        _registerDefault();
        vm.expectRevert(IYieldSourceOracle.INVALID_BASE_ASSET.selector);
        oracle.getWithdrawalShareOutput(address(bond), address(0xDEAD), 1e6);
    }

    function test_GetTVLByOwnerOfShares_PricesTheBalance() public {
        bond.mint(holder, 10e18);
        _registerDefault();
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 10 * NAV_IN_CASH);
    }

    /// @dev A zero balance short-circuits BEFORE any feed is touched, so a holder of none of a suspended
    ///      instrument is still priceable at zero rather than reverting the whole batch.
    function test_GetTVLByOwnerOfShares_ZeroBalance_ShortCircuitsBeforeFeeds() public {
        _registerDefault();
        _suspend(true);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 0);
    }

    function test_GetTVLByOwnerOfShares_ZeroBalance_UnregisteredInstrument() public view {
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 0);
    }

    function test_GetTVL_UsesTotalSupply() public {
        bond.mint(holder, 4e18);
        bond.mint(address(this), 6e18);
        _registerDefault();
        assertEq(oracle.getTVL(address(bond)), 10 * NAV_IN_CASH);
    }

    /// @dev Fees are bypassed on purpose: coupon accrual is not performance yield.
    function test_GetAssetOutputWithFees_IgnoresFeesEntirely() public {
        _registerDefault();
        uint256 plain = oracle.getAssetOutput(address(bond), address(cash), 5e18);
        uint256 withFees = oracle.getAssetOutputWithFees(bytes32("ledger"), address(bond), address(cash), holder, 5e18);
        assertEq(withFees, plain);
    }

    /// @dev The pricing pipeline's safety valve: one unusable instrument marks itself unsuccessful instead of
    ///      reverting the batch, so a wrong number is never published.
    function test_GetTVLByOwnerOfSharesMultiple_SuspendedEntryReportsUnsuccessful() public {
        bond.mint(holder, 1e18);
        _registerDefault();
        _suspend(true);

        address[] memory sources = new address[](1);
        sources[0] = address(bond);
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = holder;

        (uint256[][] memory tvls, bool[][] memory succeeded) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertFalse(succeeded[0][0], "declined to publish");
        assertEq(tvls[0][0], 0);
    }

    /*//////////////////////////////////////////////////////////////
                      VALUE READS — REVERT ON UNUSABLE
    //////////////////////////////////////////////////////////////*/

    function test_ValueReads_RevertIf_Unregistered() public {
        vm.expectRevert(GyldBondYieldSourceOracle.INSTRUMENT_NOT_REGISTERED.selector);
        oracle.getPricePerShare(address(bond));
        vm.expectRevert(GyldBondYieldSourceOracle.INSTRUMENT_NOT_REGISTERED.selector);
        oracle.getAssetOutput(address(bond), address(0), 1e18);
        vm.expectRevert(GyldBondYieldSourceOracle.INSTRUMENT_NOT_REGISTERED.selector);
        oracle.getShareOutput(address(bond), address(0), 1e6);
        vm.expectRevert(GyldBondYieldSourceOracle.INSTRUMENT_NOT_REGISTERED.selector);
        oracle.getWithdrawalShareOutput(address(bond), address(0), 1e6);
        vm.expectRevert(GyldBondYieldSourceOracle.INSTRUMENT_NOT_REGISTERED.selector);
        oracle.getTVL(address(bond));
    }

    function test_GetTVLByOwnerOfShares_RevertIf_UnregisteredWithBalance() public {
        bond.mint(holder, 1e18);
        vm.expectRevert(GyldBondYieldSourceOracle.INSTRUMENT_NOT_REGISTERED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
    }

    function test_ValueReads_RevertIf_Suspended() public {
        bond.mint(holder, 1e18);
        _registerDefault();
        _suspend(true);

        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getPricePerShare(address(bond));
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getAssetOutput(address(bond), address(0), 1e18);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getShareOutput(address(bond), address(0), 1e6);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getWithdrawalShareOutput(address(bond), address(0), 1e6);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVL(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                              RECOVERY NAV
    //////////////////////////////////////////////////////////////*/

    /// @dev A terminal override replaces the feed entirely: default or maturity is a decided number, and it
    ///      must keep working even once the feed has gone silent.
    function test_RecoveryNav_OverridesADeadFeed() public {
        _registerDefault();
        vm.prank(admin);
        registry.proposeRecoveryNav(address(bond), 0.4e6);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(admin);
        registry.executeRecoveryNav(address(bond));

        // The feed is now ancient; the override must not care.
        assertEq(oracle.getPricePerShare(address(bond)), 0.4e6);
        GyldBondYieldSourceOracle.NavStatus memory status = _preview();
        assertEq(status.failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.OK));
        assertEq(status.nav, 0.4e6);
        // An override synthesises a current timestamp on both clocks, which is correct for a decided
        // number: it is not a feed reading and has no staleness of its own. Only reachable while the
        // instrument is NOT suspended, since suspension now takes precedence.
        assertEq(status.observedAt, block.timestamp, "an override is current by construction");
    }

    /// @dev FIXED (F2). Suspension now takes precedence over the recovery override in both paths, so the
    ///      un-timelocked incident switch works even once a terminal value is installed. This test used to
    ///      pin the inverse behaviour; it now pins the fix.
    function test_SuspensionOutranksTheRecoveryOverride() public {
        _registerDefault();
        vm.prank(admin);
        registry.proposeRecoveryNav(address(bond), 0.4e6);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(admin);
        registry.executeRecoveryNav(address(bond));
        _suspend(true);

        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getPricePerShare(address(bond));
        assertEq(_preview().failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED));
    }

    /*//////////////////////////////////////////////////////////////
                           SEQUENCER LIVENESS
    //////////////////////////////////////////////////////////////*/

    function test_Sequencer_Down_BlocksEveryValueRead() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.sequencerUptimeFeed = address(sequencer);
        cfg.gracePeriod = 1 hours;
        _register(cfg);
        sequencer.setStartedAt(block.timestamp - 2 hours);

        sequencer.setAnswer(1); // down
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.SEQUENCER_DOWN_CODE);
        vm.expectRevert(GyldBondYieldSourceOracle.SEQUENCER_DOWN.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_Sequencer_UpButWithinGracePeriod_Blocks() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.sequencerUptimeFeed = address(sequencer);
        cfg.gracePeriod = 1 hours;
        _register(cfg);
        sequencer.setStartedAt(block.timestamp - 30 minutes); // restarted half an hour ago

        // The grace period is now reported DISTINCTLY from the sequencer being down, which is what an
        // operator needs in order to tell "wait" from "something is wrong".
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.GRACE_PERIOD);
        vm.expectRevert(GyldBondYieldSourceOracle.GRACE_PERIOD_NOT_OVER.selector);
        oracle.getPricePerShare(address(bond));
    }

    /// @dev F7 REGRESSION, and the test no mock could express before. The sequencer came back up a day ago
    ///      (index 2) but the feed published a round just now (index 3). Reading the publication time would
    ///      make the grace period look unelapsed and block a healthy chain; reading the transition time, as
    ///      Chainlink's own consumer example does, correctly allows it.
    function test_Sequencer_GracePeriodMeasuredFromStartedAtNotUpdatedAt() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.sequencerUptimeFeed = address(sequencer);
        cfg.gracePeriod = 1 hours;
        _register(cfg);

        sequencer.setStartedAt(block.timestamp - 1 days); // up for a day
        sequencer.setUpdatedAt(block.timestamp); // heartbeat round just now

        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH, "a long-up sequencer is not in grace");
    }

    function test_Sequencer_UpAndPastGracePeriod_Allows() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.sequencerUptimeFeed = address(sequencer);
        cfg.gracePeriod = 1 hours;
        _register(cfg);
        sequencer.setStartedAt(block.timestamp - 2 hours);

        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
    }

    /*//////////////////////////////////////////////////////////////
                         CHAINLINK-STYLE NAV FEED
    //////////////////////////////////////////////////////////////*/

    function test_ChainlinkFeed_NonPositiveAnswer_IsUnusable() public {
        _registerDefault();
        navFeed.setLatestAnswer(0);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));

        navFeed.setLatestAnswer(-1);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE);
    }

    function test_ChainlinkFeed_IncompleteRound_IsPublicationStale() public {
        _registerDefault();
        navFeed.setRoundData(10, 9); // answeredInRound behind roundId
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE);
        vm.expectRevert(GyldBondYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_ChainlinkFeed_AtOrBelowMinAnswer_TripsCircuitBreaker() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = int192(NAV_ANSWER); // answer == min is already outside
        cfg.navMaxAnswer = 10e8;
        _register(cfg);

        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_ChainlinkFeed_AtOrAboveMaxAnswer_TripsCircuitBreaker() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMaxAnswer = int192(NAV_ANSWER);
        _register(cfg);

        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER);
    }

    function test_ChainlinkFeed_InsideBounds_Allows() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 1e8;
        cfg.navMaxAnswer = 2e8;
        _register(cfg);
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
    }

    function test_ChainlinkFeed_StalePublication_Blocks() public {
        _registerDefault();
        navFeed.setUpdatedAt(block.timestamp - MAX_PUB_AGE - 1);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE);
        vm.expectRevert(GyldBondYieldSourceOracle.STALE_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_ChainlinkFeed_PublicationExactlyAtBound_Allows() public {
        _registerDefault();
        navFeed.setUpdatedAt(block.timestamp - MAX_PUB_AGE);
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH, "the bound itself is still fresh");
    }

    /// @dev A Chainlink-style feed cannot serve an instrument that demands an observation clock, and the
    ///      registry refuses to configure that. The oracle's own guard is reached only through a feed whose
    ///      observation time disappears, which `requiresObservationTime` plus a native feed reproduces below.
    function test_ChainlinkFeed_NoObservationClock_StillValues() public {
        _registerDefault();
        assertEq(_preview().observedAt, 0);
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
    }

    /*//////////////////////////////////////////////////////////////
                          GYLD-NATIVE NAV FEED
    //////////////////////////////////////////////////////////////*/

    function test_NativeFeed_ReportsBothClocks() public {
        _registerNative();
        GyldBondYieldSourceOracle.NavStatus memory status = _preview();
        assertEq(status.observedAt, block.timestamp);
        assertEq(status.publishedAt, block.timestamp);
        assertEq(status.nav, NAV_IN_CASH);
    }

    function test_NativeFeed_ZeroNav_IsUnusable() public {
        _registerNative();
        nativeFeed.setNav(address(bond), 0, block.timestamp, block.timestamp);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_NativeFeed_OutsideBounds_TripsCircuitBreaker() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(nativeFeed);
        cfg.navFeedKind = KIND_NATIVE;
        cfg.navMaxAnswer = 1e8; // NAV of 1.05e8 is above
        _register(cfg);

        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    /// @dev THE CASE BOTH CLOCKS EXIST FOR: a NAV published seconds ago, observed a week ago. A fresh
    ///      publication of a stale valuation must not pass.
    function test_NativeFeed_FreshPublicationOfStaleObservation_Blocks() public {
        _registerNative();
        nativeFeed.setNav(address(bond), uint256(NAV_ANSWER), block.timestamp - 7 days, block.timestamp);

        _assertFailure(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE);
        vm.expectRevert(GyldBondYieldSourceOracle.STALE_OBSERVATION.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_NativeFeed_ObservationExactlyAtBound_Allows() public {
        _registerNative();
        nativeFeed.setNav(address(bond), uint256(NAV_ANSWER), block.timestamp - MAX_OBS_AGE, block.timestamp);
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
    }

    /// @dev A valuation dated in the future is not fresh, it is wrong, and it now says so by name.
    function test_NativeFeed_FutureObservation_IsUnusable() public {
        _registerNative();
        nativeFeed.setNav(address(bond), uint256(NAV_ANSWER), block.timestamp + 1, block.timestamp);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.INVALID_TIMESTAMP);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_TIMESTAMP.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_NativeFeed_StalePublication_Blocks() public {
        _registerNative();
        nativeFeed.setNav(address(bond), uint256(NAV_ANSWER), block.timestamp, block.timestamp - MAX_PUB_AGE - 1);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE);
    }

    /// @dev An instrument that requires an observation clock must refuse a feed that reports none, which is
    ///      the "complete NAV with no valuation instant" case.
    function test_NativeFeed_MissingObservationTimeWhenRequired_Blocks() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(nativeFeed);
        cfg.navFeedKind = KIND_NATIVE;
        cfg.requiresObservationTime = true;
        _register(cfg);

        nativeFeed.setNav(address(bond), uint256(NAV_ANSWER), 0, block.timestamp);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_UNAVAILABLE);
        vm.expectRevert(GyldBondYieldSourceOracle.OBSERVATION_TIME_UNAVAILABLE.selector);
        oracle.getPricePerShare(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                  USD DENOMINATION — CASH IS NOT ONE DOLLAR
    //////////////////////////////////////////////////////////////*/

    function _registerUsd() internal {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg);
    }

    function test_Usd_CashAtPar_MatchesDirectQuote() public {
        _registerUsd();
        assertEq(oracle.getPricePerShare(address(bond)), NAV_IN_CASH);
    }

    /// @dev THE BUG THIS EXISTS TO PREVENT. The cash token depegs to $0.95, so the same dollar NAV must buy
    ///      MORE cash units, not the same number.
    function test_Usd_DepeggedCash_RaisesTheCashDenominatedNav() public {
        _registerUsd();
        cashFeed.setLatestAnswer(0.95e8);

        uint256 nav = oracle.getPricePerShare(address(bond));
        assertGt(nav, NAV_IN_CASH, "a weaker cash token means more cash units per bond");
        // 1.05 USD / 0.95 USD-per-cash = 1.105263 cash
        assertEq(nav, (uint256(NAV_ANSWER) * 1e8 * 1e6) / (1e8 * 0.95e8));
    }

    function test_Usd_StrongerCash_LowersTheCashDenominatedNav() public {
        _registerUsd();
        cashFeed.setLatestAnswer(1.05e8);
        assertEq(oracle.getPricePerShare(address(bond)), 1e6, "1.05 USD at 1.05 USD/cash is exactly 1 cash");
    }

    function test_Usd_CashFeedNonPositive_Fails() public {
        _registerUsd();
        cashFeed.setLatestAnswer(0);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_Usd_CashFeedIncompleteRound_Fails() public {
        _registerUsd();
        cashFeed.setRoundData(5, 4);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED);
    }

    /// @dev The cash feed is staleness-checked exactly as strictly as the NAV feed.
    function test_Usd_CashFeedStale_Fails() public {
        _registerUsd();
        cashFeed.setUpdatedAt(block.timestamp - MAX_PUB_AGE - 1);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED);
    }

    function test_Usd_CashFeedOutsideBounds_Fails() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        cfg.cashMinAnswer = 0.99e8; // a depeg below 0.99 is refused outright
        cfg.cashMaxAnswer = 1.01e8;
        _register(cfg);

        cashFeed.setLatestAnswer(0.9e8);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED);
    }

    /// @dev A NAV so small it rounds to nothing in cash units is unusable rather than free.
    function test_ConversionRoundingToZero_IsUnusable() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navFeed = address(nativeFeed);
        cfg.navFeedKind = KIND_NATIVE;
        _register(cfg);

        // 1 wei of an 8-decimal feed answer scaled into 6 cash decimals floors to zero.
        nativeFeed.setFreshNav(address(bond), 1);
        _assertFailure(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE);
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev Asset-out and share-out must be inverse up to one unit of flooring, for any NAV and any size.
    function testFuzz_AssetAndShareOutput_RoundTrip(uint96 navAnswer, uint96 shares) public {
        navAnswer = uint96(bound(navAnswer, 1e6, 1e12)); // 0.01 to 10,000 cash per bond
        shares = uint96(bound(shares, 1e12, 1e24));

        _registerDefault();
        navFeed.setLatestAnswer(int256(uint256(navAnswer)));

        uint256 assetsOut = oracle.getAssetOutput(address(bond), address(cash), shares);
        vm.assume(assetsOut > 0);
        uint256 sharesBack = oracle.getShareOutput(address(bond), address(cash), assetsOut);
        assertLe(sharesBack, shares, "a round trip never creates shares");
    }

    /// @dev Withdrawal shares are never fewer than deposit shares for the same cash amount.
    function testFuzz_WithdrawalNeverCheaperThanDeposit(uint96 assets) public {
        assets = uint96(bound(assets, 1, 1e18));
        _registerDefault();
        assertGe(
            oracle.getWithdrawalShareOutput(address(bond), address(cash), assets),
            oracle.getShareOutput(address(bond), address(cash), assets)
        );
    }

    /// @dev Identity reads are total: no NAV configuration can make a balance read revert.
    function testFuzz_BalanceReadIsTotal(uint256 amount, bool suspended, bool registered) public {
        amount = bound(amount, 0, 1e30);
        bond.mint(holder, amount);
        if (registered) {
            _registerDefault();
            navFeed.setLatestAnswer(0); // a dead feed on top
            if (suspended) _suspend(true);
        }
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), amount);
        assertEq(oracle.decimals(address(bond)), 18);
        // And previewNav still answers, whatever the state.
        oracle.previewNav(address(bond));
    }
}
