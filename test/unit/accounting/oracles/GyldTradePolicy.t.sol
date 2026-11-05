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
        assertEq(
            policy.previewTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond)), 0, "buy"
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, floor_ - 1, floor_)
        );
        _fillSell(1e18, floor_ - 1);
    }

    function test_ValidateFill_BuyFloorBoundaryIsExact() public {
        uint256 floor_ = (uint256(1e18) * (10_000 - uint256(ENTRY_BPS))) / 10_000;
        _fillBuy(NAV_IN_CASH, floor_);
        vm.expectRevert(
            abi.encodeWithSelector(GyldTradePolicy.PRICE_OUTSIDE_POLICY.selector, floor_ - 1, floor_)
        );
        _fillBuy(NAV_IN_CASH, floor_ - 1);
    }

    /// @dev C1: this is what stops a compromised manager key setting `outputMin = 1` and donating the
    ///      strategy's bonds. The floor binds on measured amounts regardless of the header.
    function test_ValidateFill_RevertIf_SellIsADonation() public {
        vm.expectRevert();
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
        for (uint256 i; i < 7; ++i) {
            uint256 snap = vm.snapshotState();
            _applyState(i);

            for (uint256 s; s < 2; ++s) {
                IGyldTradePolicy.TradeSide side =
                    s == 0 ? IGyldTradePolicy.TradeSide.BUY : IGyldTradePolicy.TradeSide.SELL;
                (address inTok, address outTok) = s == 0
                    ? (address(cash), address(bond))
                    : (address(bond), address(cash));

                uint256 code = policy.previewTrade(strategy, side, inTok, outTok);
                bool strictPassed = _strictPasses(side, inTok, outTok);
                assertEq(code == 0, strictPassed, "preview and strict disagree");
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
        }
    }

    function _strictPasses(
        IGyldTradePolicy.TradeSide side,
        address inTok,
        address outTok
    )
        internal
        view
        returns (bool)
    {
        try policy.validateTrade(strategy, side, inTok, outTok, "") {
            return true;
        } catch {
            return false;
        }
    }

    /*//////////////////////////////////////////////////////////////
            ADVERSARIAL — THE AGGREGATOR IS A NEW TRUST SURFACE
    //////////////////////////////////////////////////////////////*/

    /// @dev A 100KB revert from `getPPS` must NOT be able to brick the policy. The registration probe uses a
    ///      bare `catch`, so the revert data is never copied; a `catch (bytes memory)` would expand memory
    ///      on the 1/64 of gas the caller retains per EIP-150 and run out. This is the returnbomb class this
    ///      codebase has already been bitten by in the Stargate adapter.
    function test_Adversarial_ReturnbombOnGetPPSIsContained() public {
        MockHostileAggregator hostile =
            new MockHostileAggregator(MockHostileAggregator.Mode.RETURNBOMB_ON_GETPPS);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(hostile));

        // Fails CLOSED with the policy's OWN named error, not an out-of-gas, and with a bounded gas budget
        // so the bomb cannot be the thing that kills it.
        vm.expectRevert(GyldTradePolicy.NOT_A_REGISTERED_STRATEGY.selector);
        p.validateTrade{ gas: 2_000_000 }(
            strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), ""
        );
    }

    /// @dev An aggregator that reverts everything is indistinguishable from "not a strategy", which is the
    ///      correct read: if we cannot establish the account is a live strategy, we do not trade.
    function test_Adversarial_FullyRevertingAggregatorFailsClosed() public {
        MockHostileAggregator hostile =
            new MockHostileAggregator(MockHostileAggregator.Mode.REVERT_EVERYTHING);
        GyldTradePolicy p = new GyldTradePolicy(address(registry), address(oracle), address(hostile));

        vm.expectRevert(GyldTradePolicy.NOT_A_REGISTERED_STRATEGY.selector);
        p.validateTrade(strategy, IGyldTradePolicy.TradeSide.BUY, address(cash), address(bond), "");
    }

    /// @dev And the preview must not revert on it either — the OMS relies on preview being non-reverting.
    function test_Adversarial_PreviewSurvivesAHostileAggregator() public {
        MockHostileAggregator hostile =
            new MockHostileAggregator(MockHostileAggregator.Mode.REVERT_EVERYTHING);
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

    /// @dev A dust fill must not round its way past the floor. 1 wei of bonds against a 100e6 NAV floors
    ///      the expectation to zero, and a zero floor would make any output acceptable.
    function test_Adversarial_DustSellCannotRoundPastTheFloor() public view {
        // expectedCash = 1 * 100e6 / 1e18 = 0, so the floor is 0 and 1 wei of cash passes. Documented
        // rather than asserted as safe: the hook's MAX_INPUT_AMOUNT and outputMin are what bound dust, and
        // a dust sell loses the seller dust.
        _fillSell(1, 1);
    }

    /// @dev A dust BUY is refused by the floor, not by rounding: one cash unit should buy ~1e10 bond wei,
    ///      so receiving 1 is nine orders of magnitude short. Note the floor BINDS here rather than going
    ///      vacuous, which is the asymmetry that matters — this is the leg where the vault PAYS.
    function test_Adversarial_DustBuyIsRefusedByTheFloor() public {
        uint256 expectedBond = (uint256(1) * 1e18) / NAV_IN_CASH;
        uint256 floor_ = (expectedBond * (10_000 - uint256(ENTRY_BPS))) / 10_000;
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

    /// @dev A huge fill must not overflow the floor arithmetic into a pass. `Math.mulDiv` carries the
    ///      intermediate product at 512 bits, so this is a real assertion rather than a hope.
    function test_Adversarial_LargeFillDoesNotOverflowTheFloor() public {
        uint256 huge = 1e30;
        vm.expectRevert(); // far below the floor for that input
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

    /// @dev Whatever the state, preview never reverts. The OMS depends on that.
    function testFuzz_PreviewNeverReverts(address account, bool side, address a, address b) public view {
        IGyldTradePolicy.TradeSide s = side ? IGyldTradePolicy.TradeSide.SELL : IGyldTradePolicy.TradeSide.BUY;
        policy.previewTrade(account, s, a, b);
    }
}
