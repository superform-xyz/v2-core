// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

// Superform
import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldTradePolicy } from "../../../../src/accounting/oracles/GyldTradePolicy.sol";
import { IGyldTradePolicy } from "../../../../src/interfaces/accounting/IGyldTradePolicy.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockGyldNavFeed } from "../../../mocks/gyld/MockGyldNavFeed.sol";
import {
    MockSuperVaultStrategyState,
    MockHostileAggregator
} from "../../../mocks/gyld/MockSuperVaultStrategyState.sol";

/// @dev A sequencer uptime feed. Index 1 is the answer (0 = up, 1 = down) and index 2 is `startedAt`, the
///      word this repo's oracles read.
contract MockSequencerFeed {
    int256 private _answer;
    uint256 private _startedAt;

    constructor(int256 answer_, uint256 startedAt_) {
        _answer = answer_;
        _startedAt = startedAt_;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, _answer, _startedAt, _startedAt, 1);
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}

/// @dev A feed that throws rather than returning a bad value — the case that makes `previewTrade` revert.
contract MockRevertingFeed {
    error FEED_IS_DOWN();

    function latestRoundData() external pure returns (uint80, int256, uint256, uint256, uint80) {
        revert FEED_IS_DOWN();
    }

    function decimals() external pure returns (uint8) {
        return 8;
    }
}

/// @dev Has code, but throws on `getVaultInfo` — the actual `catch` arm, which a codeless address cannot
///      reach (a call there succeeds with empty data and the decode failure is uncatchable).
contract MockStrategyRevertingVaultInfo {
    error NO_VAULT_FOR_YOU();

    function getVaultInfo() external pure returns (address, address, uint8) {
        revert NO_VAULT_FOR_YOU();
    }
}

/// @dev A strategy that answers but names no vault.
contract MockStrategyWithNoVault {
    function getVaultInfo() external pure returns (address, address, uint8) {
        return (address(0), address(0), 18);
    }
}

/// @dev Stands in for a SuperVault strategy: the one read the commitment needs, plus a vault token whose
///      supply a test can move the way a mid-leg deposit would.
contract MockStrategyWithVault {
    MockERC20 public vaultToken;

    constructor() {
        vaultToken = new MockERC20("Vault Share", "svUSDC", 18);
        vaultToken.mint(address(this), 1_000_000e18);
    }

    function getVaultInfo() external view returns (address, address, uint8) {
        return (address(vaultToken), address(0), 18);
    }
}

/// @title GyldTradePolicyTest
/// @notice The F1 closure suite: every decision `GyldTradePolicy` makes, asserted directly.
/// @dev WHY THIS FILE EXISTS SEPARATELY. The hook suites use a permissive `MockGyldTradePolicy` so their
///      subject stays the hook's own mechanics. A passing test there proves only that the hook CALLS its
///      policy. This file is the one that proves the policy DECIDES correctly, against the real registry and
///      the real oracle, so F1 coverage rests here and not on a mock.
contract GyldTradePolicyTest is Test {
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    GyldTradePolicy internal policy;
    MockSuperVaultStrategyState internal aggregator;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals
    MockAggregator internal navFeed; // 8 decimals, Chainlink-kind
    MockGyldNavFeed internal nativeFeed; // 8 decimals, Gyld-native (both clocks)

    address internal admin = address(0xA11CE);
    address internal strategy = address(0x57A7E6);
    address internal stranger = address(0xBADBAD);

    uint256 internal constant MAX_OBS_AGE = 1 days;
    uint256 internal constant MAX_PUB_AGE = 2 hours;
    uint256 internal constant MAX_PPS_AGE = 1 days;

    /// @dev One whole bond is worth 100.00 cash units. bondScale is 1e18, cash has 6 decimals, and the feed
    ///      is 8-decimal, so a NAV of 100e8 becomes 100e6 raw cash units per whole bond.
    uint256 internal constant NAV = 100e8;
    uint256 internal constant NAV_IN_CASH = 100e6;

    uint16 internal constant ENTRY_BPS = 200; // 2%
    uint16 internal constant EXIT_BPS = 200; // 2%

    function setUp() public {
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond 2030", "GB30", 18);
        cash = new MockERC20("AUSD", "AUSD", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(int256(NAV));
        nativeFeed = new MockGyldNavFeed(8);
        nativeFeed.setFreshNav(address(bond), NAV);

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(this), address(registry));
        aggregator = new MockSuperVaultStrategyState();
        aggregator.register(strategy);
        policy = new GyldTradePolicy(address(registry), address(oracle), address(aggregator));
        // The policy reads this from the registry and refuses to trade while it is zero, so a
        // shipping-shaped fixture has to set it.
        vm.prank(admin);
        registry.setMaxPpsAge(MAX_PPS_AGE);

        _register(_cfg());
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _cfg() internal view returns (GyldBondRegistry.InstrumentConfig memory cfg) {
        cfg.bondToken = address(bond);
        cfg.cashToken = address(cash);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = registry.FEED_KIND_CHAINLINK();
        cfg.maxObservationAge = MAX_OBS_AGE;
        cfg.maxPublicationAge = MAX_PUB_AGE;
        cfg.maxEntryPremiumBps = ENTRY_BPS;
        cfg.maxExitDiscountBps = EXIT_BPS;
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
        // The warp above ages both the feed and the aggregator; refresh so the only thing under test is
        // the recovery mark itself.
        navFeed.setUpdatedAt(block.timestamp);
        aggregator.setLastUpdate(strategy, block.timestamp);
    }

    function _buy() internal view {
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    function _sell() internal view {
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(bond), address(cash), "");
    }

    function _fillBuy(uint256 cashIn, uint256 bondsOut) internal view {
        policy.validateFill(
            IGyldTradePolicy.FillArgs({
                account: strategy,
                side: IGyldTradePolicy.TradeSide.BUY,
                inputToken: address(cash),
                outputToken: address(bond),
                inputSpent: cashIn,
                received: bondsOut
            })
        );
    }

    function _fillSell(uint256 bondsIn, uint256 cashOut) internal view {
        policy.validateFill(
            IGyldTradePolicy.FillArgs({
                account: strategy,
                side: IGyldTradePolicy.TradeSide.SELL,
                inputToken: address(bond),
                outputToken: address(cash),
                inputSpent: bondsIn,
                received: cashOut
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTION
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_StoresImmutables() public view {
        assertEq(address(policy.REGISTRY()), address(registry));
        assertEq(address(policy.ORACLE()), address(oracle));
        assertEq(address(policy.AGGREGATOR()), address(aggregator));
        assertEq(registry.maxPpsAge(), MAX_PPS_AGE, "read from the registry, not pinned in the policy");
    }

    function test_Constructor_RevertIf_RegistryIsZero() public {
        vm.expectRevert(GyldTradePolicy.ADDRESS_NOT_VALID.selector);
        new GyldTradePolicy(address(0), address(oracle), address(aggregator));
    }

    function test_Constructor_RevertIf_OracleIsZero() public {
        vm.expectRevert(GyldTradePolicy.ADDRESS_NOT_VALID.selector);
        new GyldTradePolicy(address(registry), address(0), address(aggregator));
    }

    /// @dev A policy checking one instrument list while pricing against another is the "mismatched
    ///      deployments must fail safely" requirement. One comparison closes it at construction.
    function test_Constructor_RevertIf_OracleReadsADifferentRegistry() public {
        GyldBondRegistry other = new GyldBondRegistry(admin);
        GyldBondYieldSourceOracle foreign = new GyldBondYieldSourceOracle(address(this), address(other));
        vm.expectRevert(GyldTradePolicy.REGISTRY_MISMATCH.selector);
        new GyldTradePolicy(address(registry), address(foreign), address(aggregator));
    }

    /// @dev Zero aggregator is permitted (a chain with no SuperVault) but disables the pause/PPS checks.
    function test_Constructor_ZeroAggregatorIsPermitted() public {
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(0));
        assertEq(address(p.AGGREGATOR()), address(0));
        // And the strategy checks are then skipped entirely, for an account the aggregator never knew.
        p.validateTrade(stranger, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    /*//////////////////////////////////////////////////////////////
                       HAPPY PATH, BOTH DIRECTIONS
    //////////////////////////////////////////////////////////////*/

    function test_ValidateTrade_HealthyBuyPasses() public view {
        _buy();
    }

    function test_ValidateTrade_HealthySellPasses() public view {
        _sell();
    }

    function test_PreviewTrade_ZeroWhenEligible() public view {
        assertEq(policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)), 0, "buy");
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(bond), address(cash)), 0, "sell"
        );
    }

    /*//////////////////////////////////////////////////////////////
          SIDE IS ENFORCED AGAINST THE PAIR, NOT MERELY DECLARED
    //////////////////////////////////////////////////////////////*/

    /// @dev THE GUARANTEE THAT MATTERS MOST for the asymmetric rules: a SELL instance cannot be used to
    ///      ACQUIRE bonds. `side` decides which token must be the bond, so presenting `(cash, bond)` to the
    ///      sell side resolves `cash` as the bond and it is not a registered instrument.
    function test_ValidateTrade_RevertIf_SellSideUsedToAcquireBonds() public {
        vm.expectRevert(GyldTradePolicy.INSTRUMENT_NOT_REGISTERED.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(cash), address(bond), "");
    }

    /// @dev And the mirror: a BUY instance cannot be used to dispose of bonds.
    function test_ValidateTrade_RevertIf_BuySideUsedToDisposeOfBonds() public {
        vm.expectRevert(GyldTradePolicy.INSTRUMENT_NOT_REGISTERED.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(bond), address(cash), "");
    }

    function test_ValidateTrade_RevertIf_BondIsNotRegistered() public {
        MockERC20 other = new MockERC20("Unknown", "UNK", 18);
        vm.expectRevert(GyldTradePolicy.INSTRUMENT_NOT_REGISTERED.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(other), "");
    }

    /// @dev The cash leg must be the instrument's OWN denomination, not merely some registered token.
    function test_ValidateTrade_RevertIf_CashDenominationIsWrong() public {
        MockERC20 wrongCash = new MockERC20("Other Cash", "OC", 6);
        vm.expectRevert(GyldTradePolicy.CASH_DENOMINATION_MISMATCH.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(wrongCash), address(bond), "");
    }

    function test_PreviewTrade_CashMismatchCode() public {
        MockERC20 wrongCash = new MockERC20("Other Cash", "OC", 6);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(wrongCash), address(bond)),
            policy.POLICY_CODE_BASE() + 1
        );
    }

    /*//////////////////////////////////////////////////////////////
               VALUATION TIERS: LIVE, TERMINAL MARK, DARK
    //////////////////////////////////////////////////////////////*/

    /// @dev T2. A terminal mark is a governance write-down; buying into one is never authorised.
    function test_ValidateTrade_RevertIf_BuyIntoARecoveryMark() public {
        _setRecoveryNav(40e6);
        vm.expectRevert(GyldTradePolicy.RECOVERY_MARK_SET.selector);
        _buy();
    }

    /// @dev T2. Selling against the mark IS the credit-event exit path.
    function test_ValidateTrade_SellAgainstARecoveryMarkPasses() public {
        _setRecoveryNav(40e6);
        _sell();
    }

    /// @dev T2 outranks suspension: the mark is usable even while valuation is stopped.
    function test_ValidateTrade_SellAgainstAMarkPassesEvenWhenSuspended() public {
        _setRecoveryNav(40e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        _sell();
    }

    /// @dev T3, and the decision this design turns on: suspended with NO mark refuses the exit, because no
    ///      on-chain number exists to judge an exit price against.
    function test_ValidateTrade_RevertIf_SellWhileSuspendedWithNoMark() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldTradePolicy.NO_EXIT_MARK.selector);
        _sell();
    }

    function test_ValidateTrade_RevertIf_BuyWhileSuspended() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldTradePolicy.NAV_SUSPENDED.selector);
        _buy();
    }

    function test_PreviewTrade_SuspendedCodesDifferBySide() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(bond), address(cash)),
            policy.POLICY_CODE_BASE() + 4,
            "sell -> no exit mark"
        );
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            uint256(GyldBondYieldSourceOracle.NavFailure.SUSPENDED),
            "buy -> suspended"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    FEED HEALTH APPLIES TO BOTH SIDES
    //////////////////////////////////////////////////////////////*/

    /// @dev An ordinary feed problem is NOT `NO_EXIT_MARK`. Conflating them would tell an operator to
    ///      publish a recovery mark when the real fix is a stale feed. A sell with no usable NAV has no
    ///      floor either, so it is refused with the real reason.
    function test_ValidateTrade_StalePublicationIsNamedOnBothSides() public {
        vm.warp(block.timestamp + MAX_PUB_AGE + 1);
        aggregator.setLastUpdate(strategy, block.timestamp);

        vm.expectRevert(GyldTradePolicy.NAV_PUBLICATION_STALE.selector);
        _buy();
        vm.expectRevert(GyldTradePolicy.NAV_PUBLICATION_STALE.selector);
        _sell();
    }

    /*//////////////////////////////////////////////////////////////
                    R4-3 — THE BOUNDED EXIT GRACE
    //////////////////////////////////////////////////////////////*/

    uint32 internal constant GRACE_WINDOW = 12 hours;
    uint16 internal constant GRACE_BPS = 500; // 5%, wider than EXIT_BPS (2%)

    function _openGrace() internal {
        vm.prank(admin);
        registry.setEmergencyExit(address(bond), GRACE_WINDOW, GRACE_BPS);
    }

    /// @dev Puts the publication clock past `MAX_PUB_AGE` but inside `GRACE_WINDOW`, and keeps the
    ///      aggregator PPS fresh so the only degraded thing is the NAV publication.
    function _stalePublicationInsideGrace() internal {
        vm.warp(block.timestamp + MAX_PUB_AGE + 1 hours);
        aggregator.setLastUpdate(strategy, block.timestamp);
    }

    /// @dev THE POINT OF R4-3. Without the grace this reverts NAV_PUBLICATION_STALE and the only exit is a
    ///      2-day timelocked recovery mark.
    function test_R4_3_GracedSellIsAuthorisedOnAStalePublication() public {
        _openGrace();
        _stalePublicationInsideGrace();
        _sell();
    }

    /// @dev The grace must NEVER be mirrored onto the buy leg: there a stale reference lowers the bar.
    function test_R4_3_GraceNeverAppliesToBuy() public {
        _openGrace();
        _stalePublicationInsideGrace();
        vm.expectRevert(GyldTradePolicy.NAV_PUBLICATION_STALE.selector);
        _buy();
    }

    function test_R4_3_RevertIf_OutsideTheGraceWindow() public {
        _openGrace();
        vm.warp(block.timestamp + MAX_PUB_AGE + GRACE_WINDOW + 1);
        aggregator.setLastUpdate(strategy, block.timestamp);
        vm.expectRevert(GyldTradePolicy.NAV_PUBLICATION_STALE.selector);
        _sell();
    }

    /// @dev Unconfigured means the old behaviour, unchanged, with the real feed error rather than a
    ///      grace-specific one.
    function test_R4_3_RevertIf_GraceNotConfigured() public {
        _stalePublicationInsideGrace();
        vm.expectRevert(GyldTradePolicy.NAV_PUBLICATION_STALE.selector);
        _sell();
    }

    /// @dev Suspension is governance saying "do not trust this number". The grace must not reach around it,
    ///      and the error must stay the one that tells the operator to publish a mark.
    function test_R4_3_GraceCannotReachAroundSuspension() public {
        _openGrace();
        _stalePublicationInsideGrace();
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldTradePolicy.NO_EXIT_MARK.selector);
        _sell();
    }

    /// @dev VALUE failures are never graced: a dead cash feed means we cannot denominate in cash at all,
    ///      so no amount of time tolerance makes the number usable.
    function test_R4_3_ValueFailuresAreNotGraced() public {
        _openGrace();
        _stalePublicationInsideGrace();
        navFeed.setLatestAnswer(0);
        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _sell();
    }

    /// @dev A healthy feed must keep using the TIGHT discount even while a grace is open — the grace is an
    ///      incident control, not a standing loosening of the floor.
    function test_R4_3_HealthyFeedStillUsesTheNormalDiscount() public {
        _openGrace();
        // 1 bond at NAV_IN_CASH, floored at the NORMAL 2%: 98e6 passes, a 5%-graced 95e6 must not.
        _fillSell(1e18, (NAV_IN_CASH * (10_000 - EXIT_BPS)) / 10_000);
        vm.expectRevert(
            abi.encodeWithSelector(
                GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector,
                (NAV_IN_CASH * (10_000 - GRACE_BPS)) / 10_000,
                (NAV_IN_CASH * (10_000 - EXIT_BPS)) / 10_000
            )
        );
        _fillSell(1e18, (NAV_IN_CASH * (10_000 - GRACE_BPS)) / 10_000);
    }

    /// @dev Inside the window the floor uses the GRACED discount — otherwise the exit the grace authorises
    ///      would still fail to fill, which is the same lock-in by another route.
    function test_R4_3_GracedFillUsesTheGracedDiscount() public {
        _openGrace();
        _stalePublicationInsideGrace();
        uint256 graced = (NAV_IN_CASH * (10_000 - GRACE_BPS)) / 10_000;
        _fillSell(1e18, graced);
        // But the graced discount is still a FLOOR, not an absence of one.
        vm.expectRevert(
            abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, graced - 1, graced)
        );
        _fillSell(1e18, graced - 1);
    }

    /// @dev The stale reference is the LAST GOOD value, so the graced floor is still anchored to NAV.
    function test_R4_3_GracedFloorIsAnchoredToTheLastGoodNav() public {
        _openGrace();
        _stalePublicationInsideGrace();
        uint256 floor_ = (NAV_IN_CASH * (10_000 - GRACE_BPS)) / 10_000;
        assertEq(floor_, 95e6, "5% below a 100-cash mark");
        vm.expectRevert(abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, 1, floor_));
        _fillSell(1e18, 1);
    }

    /// @dev `previewTrade` must agree with the strict path, or the OMS skips a leg the policy would allow.
    function test_R4_3_PreviewAgreesWithTheGracedStrictPath() public {
        _openGrace();
        _stalePublicationInsideGrace();
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(bond), address(cash)),
            0,
            "graced sell previews as eligible"
        );
        assertTrue(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)) != 0,
            "buy still previews as ineligible"
        );
    }

    /// @dev Closing the grace restores the strict behaviour immediately.
    function test_R4_3_ClosingTheGraceRestoresStrictness() public {
        _openGrace();
        _stalePublicationInsideGrace();
        _sell();
        vm.prank(admin);
        registry.setEmergencyExit(address(bond), 0, 0);
        vm.expectRevert(GyldTradePolicy.NAV_PUBLICATION_STALE.selector);
        _sell();
    }

    /// @dev `requiresObservationTime` means BOTH clocks must sit inside the window, or the grace would
    ///      accept a freshly republished quote of an ancient observation — which is precisely the thing
    ///      the observation clock exists to catch.
    function test_R4_3_GraceRequiresBothClocksWhenObservationIsRequired() public {
        MockERC20 b2 = new MockERC20("Native Bond", "NB", 18);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.navFeed = address(feed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        cfg.requiresObservationTime = true;
        _register(cfg);
        // This instrument needs a window WIDER than MAX_OBS_AGE, or no observation can be both stale and
        // inside the grace, and the test would assert nothing.
        uint32 wideWindow = uint32(MAX_OBS_AGE + 1 days);
        vm.prank(admin);
        registry.setEmergencyExit(address(b2), wideWindow, GRACE_BPS);

        // Published a moment ago, OBSERVED long before the grace window opens.
        feed.setNav(address(b2), NAV, block.timestamp - wideWindow - 1, block.timestamp);
        vm.expectRevert(GyldTradePolicy.NAV_OBSERVATION_STALE.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(b2), address(cash), "");

        // Observation stale against the NORMAL bound but inside the grace: now it is authorised.
        feed.setNav(address(b2), NAV, block.timestamp - MAX_OBS_AGE - 1, block.timestamp);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(b2), address(cash), "");
    }

    /// @dev Zero or future is WRONG, not merely old, and must not be graced into acceptance.
    function test_R4_3_GraceRejectsZeroAndFutureClocks() public {
        MockERC20 b2 = new MockERC20("Native Bond", "NB", 18);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.navFeed = address(feed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        _register(cfg);
        vm.prank(admin);
        registry.setEmergencyExit(address(b2), GRACE_WINDOW, GRACE_BPS);

        // publishedAt == 0 is rejected by the oracle itself as INVALID_TIMESTAMP, which is not a clock
        // STALENESS code, so the grace never even considers it.
        feed.setNav(address(b2), NAV, block.timestamp, 0);
        vm.expectRevert(GyldTradePolicy.INVALID_TIMESTAMP.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(b2), address(cash), "");

        feed.setNav(address(b2), NAV, block.timestamp, block.timestamp + 1);
        vm.expectRevert(GyldTradePolicy.INVALID_TIMESTAMP.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(b2), address(cash), "");
    }

    function test_ValidateTrade_RevertIf_NavIsZero() public {
        navFeed.setLatestAnswer(0);
        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _buy();
    }

    function test_ValidateTrade_RevertIf_FutureDatedPublication() public {
        navFeed.setUpdatedAt(block.timestamp + 1);
        vm.expectRevert(GyldTradePolicy.INVALID_TIMESTAMP.selector);
        _buy();
    }

    function test_ValidateTrade_RevertIf_CircuitBreakerTripped() public {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.navMinAnswer = 1e8;
        cfg.navMaxAnswer = 50e8; // NAV of 100e8 is above the ceiling
        MockERC20 b2 = new MockERC20("Bounded", "BND", 18);
        cfg.bondToken = address(b2);
        _register(cfg);

        vm.expectRevert(GyldTradePolicy.CIRCUIT_BREAKER.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2)),
            uint256(GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER)
        );
    }

    /// @dev Preview must surface the oracle's own code for a feed failure, unchanged.
    function test_PreviewTrade_FeedFailureReturnsTheOracleCode() public {
        vm.warp(block.timestamp + MAX_PUB_AGE + 1);
        aggregator.setLastUpdate(strategy, block.timestamp);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            uint256(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE)
        );
    }

    /*//////////////////////////////////////////////////////////////
                      STRATEGY PAUSE AND PPS FRESHNESS
    //////////////////////////////////////////////////////////////*/

    /// @dev Fails CLOSED for an address the aggregator does not know. Only `getPPS` carries
    ///      `validStrategy` upstream, so registration has to be probed through it; the other reads would
    ///      answer "not paused" for a stranger.
    function test_ValidateTrade_RevertIf_AccountIsNotARegisteredStrategy() public {
        vm.expectRevert(GyldTradePolicy.NOT_A_REGISTERED_STRATEGY.selector);
        policy.validateTrade(stranger, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    function test_ValidateTrade_RevertIf_StrategyIsPaused() public {
        aggregator.setPaused(strategy, true);
        vm.expectRevert(GyldTradePolicy.STRATEGY_PAUSED.selector);
        _buy();
    }

    function test_ValidateTrade_RevertIf_PPSIsStale() public {
        aggregator.setPPSStale(strategy, true);
        vm.expectRevert(GyldTradePolicy.STALE_PPS.selector);
        _buy();
    }

    function test_ValidateTrade_RevertIf_PPSTimestampIsZero() public {
        aggregator.setLastUpdate(strategy, 0);
        vm.expectRevert(GyldTradePolicy.INVALID_PPS_TIMESTAMP.selector);
        _buy();
    }

    /// @dev A future stamp is WRONG, not merely old. Comparing ages first would silently skip the check,
    ///      which is the bug class this contract family has already been bitten by.
    function test_ValidateTrade_RevertIf_PPSTimestampIsInTheFuture() public {
        aggregator.setLastUpdate(strategy, block.timestamp + 1);
        vm.expectRevert(GyldTradePolicy.INVALID_PPS_TIMESTAMP.selector);
        _buy();
    }

    function test_ValidateTrade_RevertIf_PPSIsOlderThanMaxAge() public {
        aggregator.setLastUpdate(strategy, block.timestamp - MAX_PPS_AGE - 1);
        vm.expectRevert(GyldTradePolicy.PPS_EXPIRED.selector);
        _buy();
    }

    function test_ValidateTrade_PPSExactlyAtMaxAgeIsAccepted() public {
        aggregator.setLastUpdate(strategy, block.timestamp - MAX_PPS_AGE);
        _buy();
    }

    /// @dev An unset registry tolerance FAILS CLOSED with a named error rather than silently skipping the
    ///      age check. Same posture as `TRADE_FLOORS_NOT_SET`: forgetting to configure must not become
    ///      "the check is off".
    function test_ValidateTrade_RevertIf_MaxPpsAgeIsUnconfigured() public {
        vm.prank(admin);
        registry.setMaxPpsAge(0);
        vm.expectRevert(GyldTradePolicy.PPS_AGE_NOT_CONFIGURED.selector);
        _buy();
    }

    function test_PreviewTrade_UnconfiguredMaxPpsAgeCode() public {
        vm.prank(admin);
        registry.setMaxPpsAge(0);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            policy.POLICY_CODE_BASE() + 15
        );
    }

    /// @dev Retuning the tolerance is ONE role-gated transaction, with no hook redeploy and no root
    ///      re-sign. That is the whole reason it moved off the policy's initcode.
    function test_MaxPpsAgeIsRetunableWithoutRedeployingAnything() public {
        aggregator.setLastUpdate(strategy, block.timestamp - 2 days);

        vm.expectRevert(GyldTradePolicy.PPS_EXPIRED.selector);
        _buy();

        vm.prank(admin);
        registry.setMaxPpsAge(3 days); // same policy, same hook addresses

        _buy();
    }

    function test_SetMaxPpsAge_RevertIf_CallerLacksTheRole() public {
        vm.prank(stranger);
        vm.expectRevert();
        registry.setMaxPpsAge(2 days);
    }

    function test_SetMaxPpsAge_RevertIf_AboveTheCeiling() public {
        // Cache the ceiling: an external read inside the argument list consumes the prank and the
        // expectRevert, so the assertion would pass for the wrong reason.
        uint256 tooOld = registry.MAX_AGE_CEILING() + 1;
        vm.prank(admin);
        vm.expectRevert(GyldBondRegistry.INVALID_STALENESS.selector);
        registry.setMaxPpsAge(tooOld);
    }

    function test_SetMaxPpsAge_CeilingItselfIsAccepted() public {
        uint256 ceiling = registry.MAX_AGE_CEILING();
        vm.prank(admin);
        registry.setMaxPpsAge(ceiling);
        assertEq(registry.maxPpsAge(), ceiling);
    }

    function test_SetMaxPpsAge_EmitsTheEvent() public {
        vm.expectEmit(false, false, false, true);
        emit GyldBondRegistry.MaxPpsAgeUpdated(6 hours);
        vm.prank(admin);
        registry.setMaxPpsAge(6 hours);
    }

    /// @dev A zero aggregator skips the strategy block entirely, so an unconfigured tolerance is
    ///      irrelevant on a chain with no SuperVault.
    function test_ZeroAggregatorSkipsThePpsRequirementEntirely() public {
        vm.prank(admin);
        registry.setMaxPpsAge(0);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(0));
        p.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    function test_PreviewTrade_StrategyStateCodes() public {
        uint256 base = policy.POLICY_CODE_BASE();
        assertEq(
            policy.previewTrade(stranger, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            base + 13,
            "not a strategy"
        );
        aggregator.setPaused(strategy, true);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            base + 10,
            "paused"
        );
        aggregator.setPaused(strategy, false);
        aggregator.setPPSStale(strategy, true);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            base + 11,
            "pps stale"
        );
        aggregator.setPPSStale(strategy, false);
        aggregator.setLastUpdate(strategy, block.timestamp - MAX_PPS_AGE - 1);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            base + 12,
            "pps expired"
        );
        aggregator.setLastUpdate(strategy, 0);
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            base + 14,
            "invalid pps stamp"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    THE REALISED-PRICE FLOOR (validateFill)
    //////////////////////////////////////////////////////////////*/

    function test_ValidateFill_RevertIf_NothingWasSpent() public {
        vm.expectRevert(GyldTradePolicy.ZERO_FILL.selector);
        _fillBuy(0, 1e18);
    }

    function test_ValidateFill_RevertIf_NothingWasReceived() public {
        vm.expectRevert(GyldTradePolicy.ZERO_FILL.selector);
        _fillBuy(100e6, 0);
    }

    /// @dev An exact-NAV fill is comfortably inside a 2% tolerance.
    function test_ValidateFill_SellAtNavPasses() public view {
        _fillSell(1e18, NAV_IN_CASH);
    }

    function test_ValidateFill_BuyAtNavPasses() public view {
        _fillBuy(NAV_IN_CASH, 1e18);
    }

    /// @dev The boundary, both directions: exactly at the floor passes, one unit below reverts.
    function test_ValidateFill_SellFloorBoundaryIsExact() public {
        uint256 floor_ = (NAV_IN_CASH * (10_000 - uint256(EXIT_BPS))) / 10_000;
        _fillSell(1e18, floor_);
        vm.expectRevert(abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, floor_ - 1, floor_));
        _fillSell(1e18, floor_ - 1);
    }

    function test_ValidateFill_BuyFloorBoundaryIsExact() public {
        // R4-2: a PREMIUM of p means paying at most nav*(1+p), i.e. receiving at least expected/(1+p).
        // The old `expected*(1-p)` allowed a 25% premium at a 20% setting.
        uint256 floor_ = (uint256(1e18) * 10_000) / (10_000 + uint256(ENTRY_BPS));
        _fillBuy(NAV_IN_CASH, floor_);
        vm.expectRevert(abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, floor_ - 1, floor_));
        _fillBuy(NAV_IN_CASH, floor_ - 1);
    }

    /// @dev C1: this is what stops a compromised manager key setting `outputMin = 1` and donating the
    ///      strategy's bonds. The floor binds on measured amounts regardless of the header.
    function test_ValidateFill_RevertIf_SellIsADonation() public {
        // This is the designated C1 closure test, so it asserts the selector AND both args: a bare
        // expectRevert would also pass on TRADE_FLOORS_NOT_SET or INSTRUMENT_NOT_REGISTERED.
        uint256 floor_ = (NAV_IN_CASH * (10_000 - uint256(EXIT_BPS))) / 10_000;
        vm.expectRevert(abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, 1, floor_));
        _fillSell(1e18, 1);
    }

    function test_ValidateFill_RevertIf_BuyOverpaysBeyondTolerance() public {
        // Paying full NAV for half the bonds is a 50% premium.
        vm.expectRevert();
        _fillBuy(NAV_IN_CASH, 0.5e18);
    }

    /// @dev The floor follows the terminal mark, not the feed, once one is published. The feed still says
    ///      100 here; the mark says 40, and a fill at 40 must pass.
    function test_ValidateFill_SellIsFlooredAgainstTheRecoveryMarkNotTheFeed() public {
        _setRecoveryNav(40e6);
        _fillSell(1e18, 40e6);
        vm.expectRevert();
        _fillSell(1e18, 30e6); // 25% below the mark, outside a 2% tolerance
    }

    /// @dev A total loss has no meaningful floor; the hook's own `outputMin != 0` is what still forces the
    ///      trade to deliver something. Documented rather than silently relied upon.
    function test_ValidateFill_TotalLossMarkHasNoFloor() public {
        _setRecoveryNav(0);
        _fillSell(1e18, 1);
    }

    /// @dev But a zero from the FEED is NOT a total loss — `previewNav` zeroes `nav` for every non-OK code,
    ///      so returning early there would silently drop the floor for that fill. `validateTrade` normally
    ///      catches it first; this closes the window where the feed degrades between `preExecute` and
    ///      `postExecute`, which a venue call sits inside.
    function test_ValidateFill_RevertIf_FeedNavIsZeroWithNoMark() public {
        navFeed.setLatestAnswer(0); // no recovery mark set
        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _fillSell(1e18, NAV_IN_CASH);
    }

    /// @dev Unset tolerance fails CLOSED with a NAMED error, per direction, rather than computing a floor
    ///      at exact NAV and rejecting every honest trade with a confusing price error.
    function test_ValidateFill_RevertIf_SellFloorIsUnconfigured() public {
        MockERC20 b2 = new MockERC20("No Floors", "NF", 18);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.maxEntryPremiumBps = 0;
        cfg.maxExitDiscountBps = 0;
        _register(cfg);

        vm.expectRevert(GyldTradePolicy.TRADE_FLOORS_NOT_SET.selector);
        policy.validateFill(
            IGyldTradePolicy.FillArgs({
                account: strategy,
                side: IGyldTradePolicy.TradeSide.SELL,
                inputToken: address(b2),
                outputToken: address(cash),
                inputSpent: 1e18,
                received: NAV_IN_CASH
            })
        );
    }

    function test_ValidateFill_RevertIf_BuyFloorIsUnconfigured() public {
        MockERC20 b2 = new MockERC20("No Floors", "NF", 18);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.maxEntryPremiumBps = 0;
        cfg.maxExitDiscountBps = 0;
        _register(cfg);

        vm.expectRevert(GyldTradePolicy.TRADE_FLOORS_NOT_SET.selector);
        policy.validateFill(
            IGyldTradePolicy.FillArgs({
                account: strategy,
                side: IGyldTradePolicy.TradeSide.BUY,
                inputToken: address(cash),
                outputToken: address(b2),
                inputSpent: NAV_IN_CASH,
                received: 1e18
            })
        );
    }

    /// @dev Side is re-resolved inside `validateFill` too, so a mislabelled fill cannot slip past.
    function test_ValidateFill_RevertIf_SideDoesNotMatchThePair() public {
        vm.expectRevert(GyldTradePolicy.INSTRUMENT_NOT_REGISTERED.selector);
        policy.validateFill(
            IGyldTradePolicy.FillArgs({
                account: strategy,
                side: IGyldTradePolicy.TradeSide.SELL,
                inputToken: address(cash), // claims cash is the bond
                outputToken: address(bond),
                inputSpent: NAV_IN_CASH,
                received: 1e18
            })
        );
    }

    /*//////////////////////////////////////////////////////////////
               PREVIEW AND STRICT MUST AGREE, CONDITION BY CONDITION
    //////////////////////////////////////////////////////////////*/

    /// @dev The guard hook shipped with a preview that disagreed with its strict path. This pins the
    ///      invariant rather than leaving it to inspection: for a matrix of states, `previewTrade`
    ///      returning zero must mean `validateTrade` does not revert, and vice versa.
    function test_PreviewAndStrictAgreeAcrossStates() public {
        for (uint256 i; i < 9; ++i) {
            uint256 snap = vm.snapshotState();
            _applyState(i);

            for (uint256 s; s < 2; ++s) {
                IGyldTradePolicy.TradeSide side =
                    s == 0 ? IGyldTradePolicy.TradeSide.BUY : IGyldTradePolicy.TradeSide.SELL;
                (address inTok, address outTok) =
                    s == 0 ? (address(cash), address(bond)) : (address(bond), address(cash));

                uint256 code = policy.previewTrade(strategy, side, inTok, outTok);
                (bool strictPassed, bytes memory err) = _strictResult(side, inTok, outTok);
                assertEq(code == 0, strictPassed, "preview and strict disagree on pass/fail");
                if (!strictPassed) {
                    // Order is only observable when two conditions are broken together: the reported code
                    // and the thrown error must name the SAME condition, not merely both be failures.
                    assertTrue(_codeMatchesError(code, err), "preview reported a different condition");
                }
            }
            vm.revertToState(snap);
        }
    }

    function _applyState(uint256 i) internal {
        if (i == 0) return; // healthy
        if (i == 1) {
            vm.prank(admin);
            registry.setNavSuspended(address(bond), true);
        } else if (i == 2) {
            _setRecoveryNav(40e6);
        } else if (i == 3) {
            vm.warp(block.timestamp + MAX_PUB_AGE + 1);
            aggregator.setLastUpdate(strategy, block.timestamp);
        } else if (i == 4) {
            aggregator.setPaused(strategy, true);
        } else if (i == 5) {
            aggregator.setPPSStale(strategy, true);
        } else if (i == 6) {
            aggregator.setLastUpdate(strategy, block.timestamp - MAX_PPS_AGE - 1);
        } else if (i == 7) {
            // TWO conditions at once, which is what actually pins the ORDER. Valuation must be reported
            // before strategy state: with only one condition broken per state, swapping the two blocks in
            // `previewTrade` left every test green.
            vm.prank(admin);
            registry.setNavSuspended(address(bond), true);
            aggregator.setPaused(strategy, true);
        } else if (i == 8) {
            // And the mirror, so neither order can satisfy the matrix by accident.
            vm.warp(block.timestamp + MAX_PUB_AGE + 1);
            aggregator.setLastUpdate(strategy, block.timestamp - MAX_PPS_AGE - 1);
        }
    }

    function _strictResult(
        IGyldTradePolicy.TradeSide side,
        address inTok,
        address outTok
    )
        internal
        view
        returns (bool passed, bytes memory err)
    {
        try policy.validateTrade(strategy, side, inTok, outTok, "") {
            return (true, "");
        } catch (bytes memory reason) {
            return (false, reason);
        }
    }

    /// @dev Maps a `previewTrade` code onto the selector `validateTrade` throws for the same condition.
    ///      Only the conditions the matrix can reach are listed; an unmapped pairing fails the assertion
    ///      rather than passing silently.
    function _codeMatchesError(uint256 code, bytes memory err) internal view returns (bool) {
        bytes4 sel = bytes4(err);
        uint256 base = policy.POLICY_CODE_BASE();
        if (code == uint256(GyldBondYieldSourceOracle.NavFailure.SUSPENDED)) {
            return sel == GyldTradePolicy.NAV_SUSPENDED.selector;
        }
        if (code == uint256(GyldBondYieldSourceOracle.NavFailure.PUBLICATION_STALE)) {
            return sel == GyldTradePolicy.NAV_PUBLICATION_STALE.selector;
        }
        if (code == base + 3) return sel == GyldTradePolicy.RECOVERY_MARK_SET.selector;
        if (code == base + 4) return sel == GyldTradePolicy.NO_EXIT_MARK.selector;
        if (code == base + 10) return sel == GyldTradePolicy.STRATEGY_PAUSED.selector;
        if (code == base + 11) return sel == GyldTradePolicy.STALE_PPS.selector;
        if (code == base + 12) return sel == GyldTradePolicy.PPS_EXPIRED.selector;
        return false;
    }

    /*//////////////////////////////////////////////////////////////
            ADVERSARIAL — THE AGGREGATOR IS A NEW TRUST SURFACE
    //////////////////////////////////////////////////////////////*/

    /// @dev A 100KB revert from `getPPS` must NOT be able to brick the policy. The registration probe uses a
    ///      bare `catch`, so the revert data is never copied; a `catch (bytes memory)` would expand memory
    ///      on the 1/64 of gas the caller retains per EIP-150 and run out. This is the returnbomb class this
    ///      codebase has already been bitten by in the Stargate adapter.
    function test_Adversarial_ReturnbombOnGetPPSIsContained() public {
        MockHostileAggregator hostile = new MockHostileAggregator(MockHostileAggregator.Mode.RETURNBOMB_ON_GETPPS);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(hostile));

        // Fails CLOSED with the policy's OWN named error, not an out-of-gas, and with a bounded gas budget
        // so the bomb cannot be the thing that kills it.
        vm.expectRevert(GyldTradePolicy.NOT_A_REGISTERED_STRATEGY.selector);
        p.validateTrade{ gas: 2_000_000 }(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    /// @dev HONEST LIMIT OF THE BARE CATCH. It saves the REVERT path — no revert data is copied — but it
    ///      cannot save the gas path: an aggregator that burns the forwarded gas in `getPPS` takes the leg
    ///      down regardless. Asserted so the containment story is not overstated: `OUT_OF_GAS_LOOP` was
    ///      declared in the mock and exercised by nothing, which is how the returnbomb test came to read as
    ///      broader protection than it is. Fail-closed, and only reachable with a hostile
    ///      governance-set aggregator.
    function test_Adversarial_GasBurningAggregatorIsNotContained() public {
        MockHostileAggregator hostile = new MockHostileAggregator(MockHostileAggregator.Mode.OUT_OF_GAS_LOOP);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(hostile));

        vm.expectRevert(); // out of gas, NOT a named policy error
        p.validateTrade{ gas: 500_000 }(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    /// @dev An aggregator that reverts everything is indistinguishable from "not a strategy", which is the
    ///      correct read: if we cannot establish the account is a live strategy, we do not trade.
    function test_Adversarial_FullyRevertingAggregatorFailsClosed() public {
        MockHostileAggregator hostile = new MockHostileAggregator(MockHostileAggregator.Mode.REVERT_EVERYTHING);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(hostile));

        vm.expectRevert(GyldTradePolicy.NOT_A_REGISTERED_STRATEGY.selector);
        p.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    /// @dev And the preview must not revert on it either — the OMS relies on preview being non-reverting.
    function test_Adversarial_PreviewSurvivesAHostileAggregator() public {
        MockHostileAggregator hostile = new MockHostileAggregator(MockHostileAggregator.Mode.REVERT_EVERYTHING);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(hostile));

        uint256 code = p.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond));
        assertEq(code, p.POLICY_CODE_BASE() + 13, "reported, not thrown");
    }

    /// @dev An aggregator at an address with NO CODE fails closed, but NOT with a named error: a call to a
    ///      codeless address succeeds with empty returndata, and Solidity's `try` cannot catch a decoding
    ///      failure, so it bubbles as a bare revert. Documented as-is rather than dressed up — the
    ///      mitigation is the deploy script's `GYLD_AGGREGATOR_NOT_DEPLOYED` check, which makes this state
    ///      unreachable in a real deployment.
    function test_Adversarial_CodelessAggregatorFailsClosedWithoutAName() public {
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(0xDEAD));
        vm.expectRevert(); // bare: there is no selector to assert
        p.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    /*//////////////////////////////////////////////////////////////
                  ADVERSARIAL — THE REGISTRY AND THE MATH
    //////////////////////////////////////////////////////////////*/

    /// @dev Deregistering an instrument must stop trades immediately, not merely stop valuation.
    function test_Adversarial_DeregistrationStopsTrading() public {
        vm.prank(admin);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(admin);
        registry.executeDeregisterInstrument(address(bond));
        aggregator.setLastUpdate(strategy, block.timestamp);

        vm.expectRevert(GyldTradePolicy.INSTRUMENT_NOT_REGISTERED.selector);
        _buy();
        vm.expectRevert(GyldTradePolicy.INSTRUMENT_NOT_REGISTERED.selector);
        _sell();
    }

    /// @dev Tightening a floor must bite immediately — that is the point of it being registry state.
    function test_Adversarial_TighteningAFloorAppliesAtOnce() public {
        _fillSell(1e18, 99e6); // 1% discount, inside the 2% tolerance

        vm.prank(admin);
        registry.setTradeFloors(address(bond), 200, 50); // sell tolerance down to 0.5%

        vm.expectRevert();
        _fillSell(1e18, 99e6);
    }

    /// @dev A dust SELL used to round past the floor. It no longer does: the guard moved from
    ///      `expectedBond == 0` to `floor_ == 0`, which catches both legs AND the one-unit-short case
    ///      (an expectation of exactly 1 also truncates to a zero floor). The true zero-floor region was
    ///      `fair < 2` raw cash units, not `< 1` as an earlier comment here claimed.
    /// @dev Kept as a regression test with its original history intact. It was previously named
    ///      "CannotRoundPastTheFloor" with no assertion at all, which claimed the opposite of what its own
    ///      body demonstrated — the exact false-confidence shape this suite is supposed to avoid.
    /// @dev The asymmetry is GONE. Both legs now reject a zero computed floor, so neither can round past
    ///      it. The only surviving no-floor path is a deliberate zero recovery mark, which
    ///      `test_ValidateFill_TotalLossMarkHasNoFloor` covers and which returns before the floor is
    ///      computed at all.
    function test_Fixed_DustSellNoLongerRoundsPastTheFloor() public {
        // expectedCash = mulDiv(1, 100e6, 1e18) = 0 -> floor_ = 0 -> now REFUSED rather than waved through.
        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _fillSell(1, 1);

        // And the one-unit-short case the old `== 0` guard missed: an expectation of exactly 1 truncates
        // to a zero floor too, so the region really was `fair < 2`, not `fair < 1`.
        uint256 oneCashUnitOfBond = 1e18 / NAV_IN_CASH; // fair value == 1 raw cash unit
        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _fillSell(oneCashUnitOfBond, 1);
    }

    /// @dev The BUY mirror of the same one-unit-short hole.
    function test_Fixed_DustBuyWithAnExpectationOfOneIsRefused() public {
        // expectedBond == 1 gives floor_ = 1 * 10_000 / 10_200 == 0 under the fixture's 2% tolerance.
        _setRecoveryNav(1e18); // a mark that makes one cash unit buy exactly 1 bond wei
        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _fillBuy(1, 1);
    }

    /// @dev A dust BUY is refused by the floor, not by rounding: one cash unit should buy ~1e10 bond wei,
    ///      so receiving 1 is nine orders of magnitude short. The floor BINDS here rather than going
    ///      vacuous — this is the leg where the vault PAYS.
    function test_Adversarial_DustBuyIsRefusedByTheFloor() public {
        uint256 expectedBond = (uint256(1) * 1e18) / NAV_IN_CASH;
        uint256 floor_ = (expectedBond * 10_000) / (10_000 + uint256(ENTRY_BPS));
        vm.expectRevert(abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, 1, floor_));
        _fillBuy(1, 1);
    }

    /// @dev The `INVALID_PRICE` guard covers what the floor CANNOT: a NAV so large relative to the spend
    ///      that the expectation floors to ZERO, which would make the floor vacuous on the leg where the
    ///      vault pays. Reaching it needs `inputSpent * bondScale < nav`, i.e. nav above 1e18 cash units —
    ///      unreachable through an 8-decimal feed with a 6-decimal cash token, so the guard is
    ///      defence-in-depth rather than a live path. A large recovery mark is the one way to get there,
    ///      and `validateFill` is independently defensive even though `validateTrade` blocks this buy.
    function test_Adversarial_BuyWithAVacuousExpectationIsRefused() public {
        _setRecoveryNav(2e18); // absurd on purpose: one bond "worth" 2e18 raw cash units

        vm.expectRevert(GyldTradePolicy.INVALID_PRICE.selector);
        _fillBuy(1, 1); // expectedBond = 1 * 1e18 / 2e18 = 0
    }

    /// @dev A large fill must be floored correctly rather than wrapping into a pass.
    function test_Adversarial_LargeFillDoesNotOverflowTheFloor() public {
        uint256 huge = 1e30;
        // Assert the SELECTOR and both args, so this cannot pass on an arithmetic panic. Note it does NOT
        // exercise mulDiv's 512-bit path: 1e30 * 100e6 = 1e38 fits in uint256 with ~39 orders of magnitude
        // spare. Reaching that path needs inputSpent ~1e70, and the expectation would have to be computed
        // with mulDiv too. This asserts a large NON-overflowing fill is floored correctly.
        uint256 expectedCash = (huge * NAV_IN_CASH) / 1e18;
        uint256 floor_ = (expectedCash * (10_000 - uint256(EXIT_BPS))) / 10_000;
        vm.expectRevert(abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, 1, floor_));
        _fillSell(huge, 1);
    }

    /// @dev Suspension is the un-timelocked incident switch, so it must stop a BUY in the same block.
    function test_Adversarial_SuspensionStopsBuysInTheSameBlock() public {
        _buy();
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        vm.expectRevert(GyldTradePolicy.NAV_SUSPENDED.selector);
        _buy();
    }

    /*//////////////////////////////////////////////////////////////
                                  FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev For any tolerance and any realised sell, the floor is exactly the NAV value discounted by that
    ///      tolerance — no rounding slack that could be farmed.
    function testFuzz_SellFloorMatchesTheDiscountedNav(uint16 exitBps, uint128 bondsIn) public {
        exitBps = uint16(bound(exitBps, 1, registry.MAX_TOLERANCE_BPS()));
        bondsIn = uint128(bound(bondsIn, 1e12, 1e24));

        vm.prank(admin);
        registry.setTradeFloors(address(bond), ENTRY_BPS, exitBps);

        uint256 expectedCash = (uint256(bondsIn) * NAV_IN_CASH) / 1e18;
        uint256 floor_ = (expectedCash * (10_000 - uint256(exitBps))) / 10_000;
        vm.assume(floor_ > 0);

        _fillSell(bondsIn, floor_); // exactly at the floor passes
        vm.expectRevert();
        _fillSell(bondsIn, floor_ - 1); // one below never does
    }

    /// @dev Preview ABSORBS the two failures it promises to absorb, across pairs that actually REACH the
    ///      later branches. Drawing fully random tokens made every draw resolve to an unregistered bond, so
    ///      the valuation and strategy blocks were never entered and four fuzzed parameters exercised one
    ///      branch. Tokens are now drawn from a set that includes the registered pair.
    function testFuzz_PreviewAbsorbsUnknownPairs(uint8 inSel, uint8 outSel, uint8 acctSel) public view {
        address[4] memory toks = [address(cash), address(bond), address(0xBEEF), address(0)];
        address[3] memory accts = [strategy, stranger, address(0xC0FFEE)];
        address inTok = toks[inSel % 4];
        address outTok = toks[outSel % 4];
        address acct = accts[acctSel % 3];

        uint256 buy = policy.previewTrade(acct, IGyldTradePolicy.TradeSide.BUY, inTok, outTok);
        uint256 sell = policy.previewTrade(acct, IGyldTradePolicy.TradeSide.SELL, inTok, outTok);

        // Zero is only legitimate for the registered pair on the matching side with a known strategy.
        if (buy == 0) {
            assertEq(outTok, address(bond), "a passing BUY must be buying the registered bond");
            assertEq(inTok, address(cash), "...against its own cash");
            assertEq(acct, strategy, "...for a registered strategy");
        }
        if (sell == 0) {
            assertEq(inTok, address(bond), "a passing SELL must be selling the registered bond");
            assertEq(outTok, address(cash), "...for its own cash");
            assertEq(acct, strategy, "...for a registered strategy");
        }
    }

    /*//////////////////////////////////////////////////////////////
       R4-2 — THE ENTRY FLOOR IS THE RIGHT INVERSE OF A PREMIUM
    //////////////////////////////////////////////////////////////*/

    /// @dev The bug: `expected * (1 - p)` is the inverse of a DISCOUNT, not a PREMIUM. Receiving
    ///      `expected * (1 - p)` means paying `nav / (1 - p)`, so a 20% setting permitted a 25% overpay.
    ///      Now `expected / (1 + p)`, so a 20% setting permits exactly 20%.
    function test_Fixed_R4_2_EntryPremiumCeilingIsTheConfiguredValue() public {
        vm.prank(admin);
        registry.setTradeFloors(address(bond), 2000, EXIT_BPS); // 20% entry tolerance

        // Paying exactly 1.20x NAV per bond must pass: spend 1.2 * NAV of cash, receive one bond.
        uint256 cashFor120pct = (NAV_IN_CASH * 12_000) / 10_000;
        _fillBuy(cashFor120pct, 1e18);

        // Paying 1.25x NAV — what the OLD formula allowed — must now fail.
        uint256 cashFor125pct = (NAV_IN_CASH * 12_500) / 10_000;
        vm.expectRevert();
        _fillBuy(cashFor125pct, 1e18);
    }

    /// @dev And the SELL side is NOT symmetric: `fair * (1 - p)` genuinely IS a discount of p, so it was
    ///      already correct and must not be "fixed" to match the buy side.
    function test_R4_2_ExitDiscountFloorWasAlreadyCorrect() public {
        vm.prank(admin);
        registry.setTradeFloors(address(bond), ENTRY_BPS, 2000); // 20% exit tolerance

        uint256 at80pct = (NAV_IN_CASH * 8000) / 10_000;
        _fillSell(1e18, at80pct); // exactly 20% below fair passes
        vm.expectRevert();
        _fillSell(1e18, at80pct - 1); // a hair worse does not
    }

    /*//////////////////////////////////////////////////////////////
      R4-1 — THE LEG-SCOPED SHARE-SUPPLY COMMITMENT
    //////////////////////////////////////////////////////////////*/

    /// @dev A plain smart account has no vault, so the commitment is zero and the 4337 path keeps working.
    ///      Only reachable with no aggregator configured, since otherwise `validateTrade` has already
    ///      established the account is a registered strategy.
    function test_R4_1_CommitmentIsZeroForANonStrategyAccount() public {
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(0));
        assertEq(p.accountStateCommitment(address(0xE0A)), bytes32(0), "nothing to commit");
    }

    /// @dev But with an aggregator wired, an account whose vault cannot be read is a contradiction —
    ///      `validateTrade` already proved it is a registered strategy — so it fails CLOSED rather than
    ///      silently returning zero and disabling the check.
    function test_R4_1_RevertIf_AccountHasNoCode() public {
        // `strategy` is a plain address in this suite, so this is the `code.length == 0` branch — NOT the
        // catch. The catch needs an account that HAS code and reverts, covered below.
        vm.expectRevert(GyldTradePolicy.ACCOUNT_VAULT_UNREADABLE.selector);
        policy.accountStateCommitment(strategy);
    }

    /// @dev The actual catch arm: a contract that exists but throws on `getVaultInfo`. With an aggregator
    ///      wired this must fail closed rather than return a vacuous zero commitment.
    function test_R4_1_RevertIf_GetVaultInfoReverts() public {
        MockStrategyRevertingVaultInfo strat = new MockStrategyRevertingVaultInfo();
        vm.expectRevert(GyldTradePolicy.ACCOUNT_VAULT_UNREADABLE.selector);
        policy.accountStateCommitment(address(strat));
    }

    /// @dev And with NO aggregator the same account is simply "not a strategy", so zero is correct.
    function test_R4_1_GetVaultInfoRevertingIsZeroWithoutAnAggregator() public {
        MockStrategyRevertingVaultInfo strat = new MockStrategyRevertingVaultInfo();
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(0));
        assertEq(p.accountStateCommitment(address(strat)), bytes32(0));
    }

    /// @dev A strategy with no vault wired must also fail closed when an aggregator is configured — the one
    ///      branch that previously returned zero unconditionally.
    function test_R4_1_RevertIf_StrategyHasNoVault() public {
        MockStrategyWithNoVault strat = new MockStrategyWithNoVault();
        vm.expectRevert(GyldTradePolicy.ACCOUNT_VAULT_UNREADABLE.selector);
        policy.accountStateCommitment(address(strat));
    }

    /// @dev The commitment must actually track supply: same supply -> same value, moved supply -> different.
    ///      This is the whole mechanism, so it is asserted directly rather than inferred.
    function test_R4_1_CommitmentTracksVaultShareSupply() public {
        MockStrategyWithVault strat = new MockStrategyWithVault();

        // The SHIPPING policy, with its aggregator wired. An earlier version built a zero-aggregator
        // policy here for no reason, which is the configuration the deploy script refuses.
        bytes32 before = policy.accountStateCommitment(address(strat));
        assertEq(policy.accountStateCommitment(address(strat)), before, "stable while supply is unchanged");

        strat.vaultToken().mint(address(this), 1);
        assertTrue(policy.accountStateCommitment(address(strat)) != before, "moves when supply moves");
    }

    /*//////////////////////////////////////////////////////////////
       COVERAGE — THE FEED-FAILURE NAMES, ALL REACHABLE IN PRODUCTION
    //////////////////////////////////////////////////////////////*/

    /// @dev These five errors had NO assertion anywhere in the repo, which is how a mis-mapped failure code
    ///      would reach an operator as the wrong name. Every one is live config: Katana is an L2, so the
    ///      sequencer paths apply, and a USD-denominated instrument needs the cash feed.
    function _registerWithSequencer(address bondToken, address seq, uint256 grace) internal {
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = bondToken;
        cfg.sequencerUptimeFeed = seq;
        cfg.gracePeriod = grace;
        _register(cfg);
    }

    function test_Coverage_SequencerDownIsNamed() public {
        MockERC20 b2 = new MockERC20("L2 Bond", "L2B", 18);
        MockSequencerFeed seq = new MockSequencerFeed(1, block.timestamp - 1 hours); // 1 == down
        _registerWithSequencer(address(b2), address(seq), 1 hours);

        vm.expectRevert(GyldTradePolicy.SEQUENCER_DOWN.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
        // And preview must pass the oracle's own code straight through, not a policy code.
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2)),
            uint256(GyldBondYieldSourceOracle.NavFailure.SEQUENCER_DOWN_CODE)
        );
    }

    function test_Coverage_GracePeriodNotOverIsNamed() public {
        MockERC20 b2 = new MockERC20("L2 Bond", "L2B", 18);
        // Up (0), but it only just came back, so we are inside the grace window.
        MockSequencerFeed seq = new MockSequencerFeed(0, block.timestamp - 10 minutes);
        _registerWithSequencer(address(b2), address(seq), 1 hours);

        vm.expectRevert(GyldTradePolicy.GRACE_PERIOD_NOT_OVER.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2)),
            uint256(GyldBondYieldSourceOracle.NavFailure.GRACE_PERIOD)
        );
    }

    /// @dev And the grace window ending must let the trade through, or the check is a permanent block.
    function test_Coverage_GracePeriodElapsedPasses() public {
        MockERC20 b2 = new MockERC20("L2 Bond", "L2B", 18);
        MockSequencerFeed seq = new MockSequencerFeed(0, block.timestamp - 2 hours);
        _registerWithSequencer(address(b2), address(seq), 1 hours);

        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
    }

    /// @dev A Gyld-native feed carries an observation clock, so staleness there is a distinct failure from
    ///      publication staleness. Only reachable on FEED_KIND_GYLD_NATIVE.
    function test_Coverage_ObservationStaleIsNamed() public {
        MockERC20 b2 = new MockERC20("Native Bond", "NB", 18);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.navFeed = address(feed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        cfg.requiresObservationTime = true;
        _register(cfg);

        // Fresh publication, stale OBSERVATION.
        feed.setNav(address(b2), NAV, block.timestamp - MAX_OBS_AGE - 1, block.timestamp);
        vm.expectRevert(GyldTradePolicy.NAV_OBSERVATION_STALE.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2)),
            uint256(GyldBondYieldSourceOracle.NavFailure.OBSERVATION_STALE)
        );
    }

    /// @dev `requiresObservationTime` with a feed that reports none must be named, not silently accepted.
    function test_Coverage_ObservationTimeUnavailableIsNamed() public {
        MockERC20 b2 = new MockERC20("Native Bond", "NB", 18);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.navFeed = address(feed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        cfg.requiresObservationTime = true;
        _register(cfg);

        feed.setNav(address(b2), NAV, 0, block.timestamp); // observedAt == 0
        vm.expectRevert(GyldTradePolicy.OBSERVATION_TIME_UNAVAILABLE.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
    }

    /// @dev A USD-denominated NAV needs the cash/USD feed; a failure there must be its own name rather than
    ///      a generic price error, because the fix is different.
    function test_Coverage_CashFeedFailedIsNamed() public {
        MockERC20 b2 = new MockERC20("USD Bond", "UB", 18);
        MockAggregator cashFeed = new MockAggregator(8);
        cashFeed.setLatestAnswer(1e8);
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg);

        cashFeed.setLatestAnswer(0); // the cash leg is unusable
        vm.expectRevert(GyldTradePolicy.CASH_FEED_FAILED.selector);
        policy.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2), "");
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2)),
            uint256(GyldBondYieldSourceOracle.NavFailure.CASH_FEED_FAILED)
        );
    }

    /// @dev The preview counterpart of the branch the whole T2 design turns on: a mark outranking an active
    ///      suspension. This was the one state with a strict test and no preview test.
    function test_Coverage_PreviewOfMarkOutrankingSuspension() public {
        _setRecoveryNav(40e6);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.SELL, address(bond), address(cash)),
            0,
            "SELL against the mark previews as eligible even while suspended"
        );
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            policy.POLICY_CODE_BASE() + 3,
            "BUY still previews as refused"
        );
    }

    /*//////////////////////////////////////////////////////////////
          PREVIEW IS NOT UNCONDITIONALLY NON-REVERTING — PINNED
    //////////////////////////////////////////////////////////////*/

    /// @dev The interface used to claim preview never reverts. It does, when a DEPENDENCY reverts, and the
    ///      NatSpec now says so. Pinned both ways so the claim and the behaviour cannot drift apart again.
    function test_Preview_RevertsWhenTheNavFeedItselfReverts() public {
        MockERC20 b2 = new MockERC20("Broken Feed Bond", "BFB", 18);
        MockRevertingFeed broken = new MockRevertingFeed();
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg();
        cfg.bondToken = address(b2);
        cfg.navFeed = address(broken);
        _register(cfg);

        vm.expectRevert();
        policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(b2));
    }

    /// @dev But it must still ABSORB the two failures it does promise to absorb.
    function test_Preview_AbsorbsUnregisteredInstrumentAndStrategy() public view {
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(0xDEAD)),
            uint256(GyldBondYieldSourceOracle.NavFailure.NOT_REGISTERED),
            "unregistered bond is reported, not thrown"
        );
        assertEq(
            policy.previewTrade(stranger, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)),
            policy.POLICY_CODE_BASE() + 13,
            "unregistered strategy is reported, not thrown"
        );
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ — WIDER INPUTS
    //////////////////////////////////////////////////////////////*/

    /// @dev A higher mark must never lower the SELL bar. Asserted against the CONTRACT: a fill that the
    ///      lower mark accepts must still be accepted at the higher one, and the higher mark's own floor
    ///      must bite above it.
    /// @dev The earlier version of this test computed both floors in the test and compared them to each
    ///      other. It never called the policy and would have passed with `GyldTradePolicy` deleted.
    function testFuzz_SellFloorIsMonotonicInNav(uint64 navLow, uint64 navHigh) public {
        navLow = uint64(bound(navLow, 1e6, 1e11));
        navHigh = uint64(bound(navHigh, 1e6, 1e11));
        if (navLow > navHigh) (navLow, navHigh) = (navHigh, navLow);

        uint256 bondsIn = 1e18;
        uint256 floorAtLow = ((bondsIn * navLow / 1e18) * (10_000 - uint256(EXIT_BPS))) / 10_000;
        vm.assume(floorAtLow > 0);

        _setRecoveryNav(navLow);
        _fillSell(bondsIn, floorAtLow); // the low mark accepts exactly its own floor

        _setRecoveryNav(navHigh);
        // A higher mark must never LOWER the bar. Branch on the floor, not on the nav: floor division
        // means two different navs can round to the same floor, so "higher nav => strictly higher floor"
        // is false and an earlier version of this test asserted it.
        uint256 floorAtHigh = ((bondsIn * navHigh / 1e18) * (10_000 - uint256(EXIT_BPS))) / 10_000;
        assertGe(floorAtHigh, floorAtLow, "a higher mark never lowers the floor");
        if (floorAtHigh > floorAtLow) {
            vm.expectRevert(); // the old floor no longer clears the new one
            _fillSell(bondsIn, floorAtLow);
        } else {
            _fillSell(bondsIn, floorAtLow); // tied floors: still accepted
        }
    }

    /// @dev And the entry ceiling must never exceed the configured premium, for any tolerance in range.
    function testFuzz_EntryPremiumNeverExceedsTheConfiguredCeiling(uint16 entryBps) public {
        entryBps = uint16(bound(entryBps, 1, registry.MAX_TOLERANCE_BPS()));
        vm.prank(admin);
        registry.setTradeFloors(address(bond), entryBps, EXIT_BPS);

        // Paying exactly the permitted premium passes; a hair more does not.
        uint256 atCeiling = (NAV_IN_CASH * (10_000 + uint256(entryBps))) / 10_000;
        _fillBuy(atCeiling, 1e18);

        uint256 overCeiling = atCeiling + (NAV_IN_CASH / 100);
        vm.expectRevert();
        _fillBuy(overCeiling, 1e18);
    }
}
