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
import {
    MockRevertingFeed,
    MockEmptyReturnFeed,
    MockHugeNavFeed,
    MockRevertingBalanceERC20
} from "../../../mocks/gyld/GyldAdversarialMocks.sol";

/// @title GyldBondOracleAdversarialTest
/// @notice Adversarial coverage for `GyldBondYieldSourceOracle`: what a hostile, dead or absurd feed or token
///         can do to it, how it behaves at the extremes of the four scales it juggles, and whether the reads
///         documented as total really are.
contract GyldBondOracleAdversarialTest is Test {
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockAggregator internal navFeed;
    MockAggregator internal cashFeed;
    MockGyldNavFeed internal nativeFeed;

    address internal admin = address(0xA11CE);
    address internal holder = address(0xB0DB01DE2);
    address internal second = address(0xC0FFEE1);

    uint8 internal KIND_CHAINLINK;
    uint8 internal KIND_NATIVE;

    uint256 internal constant MAX_PUB_AGE = 1 days;
    uint256 internal constant MAX_OBS_AGE = 2 days;

    function setUp() public {
        vm.warp(1_800_000_000);
        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry));
        KIND_CHAINLINK = registry.FEED_KIND_CHAINLINK();
        KIND_NATIVE = registry.FEED_KIND_GYLD_NATIVE();

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(1e8);
        cashFeed = new MockAggregator(8);
        cashFeed.setLatestAnswer(1e8);
        nativeFeed = new MockGyldNavFeed(8);
        nativeFeed.setFreshNav(address(bond), 1e8);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _register(GyldBondRegistry.InstrumentConfig memory cfg) internal {
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    function _cfg(
        address bondToken,
        address cashToken,
        address feed,
        uint8 kind
    )
        internal
        view
        returns (GyldBondRegistry.InstrumentConfig memory cfg)
    {
        cfg.bondToken = bondToken;
        cfg.cashToken = cashToken;
        cfg.navFeed = feed;
        cfg.navFeedKind = kind;
        cfg.maxObservationAge = MAX_OBS_AGE;
        cfg.maxPublicationAge = MAX_PUB_AGE;
    }

    function _registerDefault() internal {
        _register(_cfg(address(bond), address(cash), address(navFeed), KIND_CHAINLINK));
    }

    /*//////////////////////////////////////////////////////////////
                     A DEAD FEED VERSUS A TOTAL READ
    //////////////////////////////////////////////////////////////*/

    /// @dev FINDING (awaiting an owner decision, pinned here so the behaviour is explicit).
    ///      `previewNav` is documented as "Reverts for nothing", and `GyldTradeGuardHook.previewTradable` plus
    ///      the OMS pre-flight both depend on that. But the feed read inside `_tryNav` is a plain external
    ///      call, so a feed that REVERTS (a paused aggregator, a proxy pointed at a dead implementation, a
    ///      self-destructed contract) propagates its revert straight through `previewNav`.
    ///      Consequence: on exactly the malformed feed the OMS most needs to detect, the pre-flight fails with
    ///      an opaque bubble-up instead of a reason code, and the guard's named errors are lost too.
    ///      Fix: wrap the NAV and cash feed reads in a bare `try/catch` (bare, NOT `catch (bytes memory)`,
    ///      to avoid a returnbomb) and map a failed call onto a new `NavFailure` arm.
    function test_Finding_RevertingNavFeed_BreaksPreviewNavTotality() public {
        MockRevertingFeed deadFeed = new MockRevertingFeed();
        _register(_cfg(address(bond), address(cash), address(deadFeed), KIND_CHAINLINK));

        vm.expectRevert(MockRevertingFeed.FEED_DEAD.selector);
        oracle.previewNav(address(bond));

        // The value reads also bubble the feed's own error rather than a named oracle error.
        vm.expectRevert(MockRevertingFeed.FEED_DEAD.selector);
        oracle.getPricePerShare(address(bond));
    }

    /// @dev Same gap on the Gyld-native branch.
    function test_Finding_RevertingNativeFeed_BreaksPreviewNavTotality() public {
        MockRevertingFeed deadFeed = new MockRevertingFeed();
        _register(_cfg(address(bond), address(cash), address(deadFeed), KIND_NATIVE));
        vm.expectRevert(MockRevertingFeed.FEED_DEAD.selector);
        oracle.previewNav(address(bond));
    }

    /// @dev And on the cash feed, which is read only on the USD-denominated path.
    function test_Finding_RevertingCashFeed_BreaksPreviewNavTotality() public {
        MockRevertingFeed deadCash = new MockRevertingFeed();
        GyldBondRegistry.InstrumentConfig memory cfg =
            _cfg(address(bond), address(cash), address(navFeed), KIND_CHAINLINK);
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(deadCash);
        _register(cfg);

        vm.expectRevert(MockRevertingFeed.FEED_DEAD.selector);
        oracle.previewNav(address(bond));
    }

    /// @dev A feed returning EMPTY returndata fails the decode rather than reading as zero.
    function test_EmptyReturnFeed_FailsTheDecode() public {
        MockEmptyReturnFeed emptyFeed = new MockEmptyReturnFeed();
        GyldBondRegistry.InstrumentConfig memory cfg =
            _cfg(address(bond), address(cash), address(navFeed), KIND_CHAINLINK);
        _register(cfg);
        // Swap the feed in via the timelocked path, since registration itself needs a working `decimals()`.
        vm.startPrank(admin);
        registry.proposeFeedChange(address(bond), address(emptyFeed), KIND_CHAINLINK);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.expectRevert(); // `decimals()` on the new feed returns nothing
        registry.executeFeedChange(address(bond));
        vm.stopPrank();
    }

    /// @dev A sequencer feed that reverts takes the whole read with it, before any NAV feed is consulted.
    function test_RevertingSequencerFeed_PropagatesToEveryRead() public {
        GyldBondRegistry.InstrumentConfig memory cfg =
            _cfg(address(bond), address(cash), address(navFeed), KIND_CHAINLINK);
        cfg.sequencerUptimeFeed = address(new MockRevertingFeed());
        _register(cfg);

        vm.expectRevert(MockRevertingFeed.FEED_DEAD.selector);
        oracle.previewNav(address(bond));
    }

    /// @dev A bond token whose `balanceOf` reverts breaks the balance read too. Same class as above, and the
    ///      reason the "preserve visible holdings" guarantee is conditional on a sane token.
    function test_RevertingBalanceToken_BreaksTheIdentityRead() public {
        MockRevertingBalanceERC20 badToken = new MockRevertingBalanceERC20();
        vm.expectRevert(MockRevertingBalanceERC20.BALANCE_DEAD.selector);
        oracle.getBalanceOfOwner(address(badToken), holder);
    }

    /*//////////////////////////////////////////////////////////////
                           ARITHMETIC EXTREMES
    //////////////////////////////////////////////////////////////*/

    /// @dev FINDING (awaiting an owner decision, pinned here so the behaviour is explicit).
    ///      On the Gyld-NATIVE branch the feed answer arrives as a `uint256` and is cast with
    ///      `_outsideBounds(int256(rawNav), ...)`. Any NAV at or above 2**255 casts to a NEGATIVE int256, so
    ///      the UPPER circuit-breaker bound (`answer >= maxAnswer`) can never trip for it. An instrument
    ///      configured with only a maximum therefore accepts an absurd NAV and marks the position at it.
    ///      A non-zero MINIMUM incidentally catches the same value, because a negative answer is <= any
    ///      positive minimum, which is why `test_HugeNav_CaughtWhenAMinimumIsConfigured` passes.
    ///      Fix: on the native branch, bound `rawNav` in uint256 space before the cast, e.g. reject any
    ///      `rawNav > uint256(uint192(type(int192).max))`.
    function test_Finding_HugeNativeNavBypassesAnUpperOnlyCircuitBreaker() public {
        MockHugeNavFeed huge = new MockHugeNavFeed(); // reports type(uint256).max
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(address(bond), address(cash), address(huge), KIND_NATIVE);
        cfg.navMaxAnswer = 2e8; // an upper bound only, which is the natural way to cap a bond's NAV
        _register(cfg);

        // int256(type(uint256).max) == -1, so `answer >= maxAnswer` is false and the breaker does not trip.
        assertEq(
            oracle.previewNav(address(bond)).failureCode,
            uint8(GyldBondYieldSourceOracle.NavFailure.OK),
            "the upper bound did not trip on a NAV far above it"
        );
        assertEq(
            oracle.getPricePerShare(address(bond)),
            type(uint256).max / 100,
            "and the position is marked at an absurd price"
        );
    }

    /// @dev The same absurd NAV IS caught once a non-zero minimum is configured, because the wrapped negative
    ///      answer falls below it. Pinned as the mitigation available today without a contract change.
    function test_HugeNav_CaughtWhenAMinimumIsConfigured() public {
        MockHugeNavFeed huge = new MockHugeNavFeed();
        GyldBondRegistry.InstrumentConfig memory cfg = _cfg(address(bond), address(cash), address(huge), KIND_NATIVE);
        cfg.navMinAnswer = 1e6;
        cfg.navMaxAnswer = 2e8;
        _register(cfg);

        assertEq(
            oracle.previewNav(address(bond)).failureCode,
            uint8(GyldBondYieldSourceOracle.NavFailure.CIRCUIT_BREAKER),
            "a configured minimum catches it"
        );
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    /// @dev The Chainlink branch has no such gap: its answer is already an int256, so a negative value is
    ///      rejected outright before the bounds are consulted.
    function test_ChainlinkBranch_NegativeAnswerIsRejectedBeforeBounds() public {
        GyldBondRegistry.InstrumentConfig memory cfg =
            _cfg(address(bond), address(cash), address(navFeed), KIND_CHAINLINK);
        cfg.navMaxAnswer = 2e8;
        _register(cfg);
        navFeed.setLatestAnswer(type(int256).min);

        assertEq(
            oracle.previewNav(address(bond)).failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE)
        );
    }

    /// @dev A zero-decimal bond: one whole bond is one wei of the token, so NAV per share equals the raw
    ///      conversion and `getAssetOutput(1)` is the full NAV.
    function test_ZeroDecimalBond_ScalesCorrectly() public {
        MockERC20 wholeBond = new MockERC20("Whole", "WB", 0);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        feed.setFreshNav(address(wholeBond), 1.25e8);
        _register(_cfg(address(wholeBond), address(cash), address(feed), KIND_NATIVE));

        assertEq(registry.getInstrumentConfig(address(wholeBond)).bondScale, 1, "scale is one");
        assertEq(oracle.getPricePerShare(address(wholeBond)), 1.25e6, "1.25 cash per whole bond");
        assertEq(oracle.getAssetOutput(address(wholeBond), address(cash), 1), 1.25e6, "one unit is one bond");
        assertEq(oracle.getAssetOutput(address(wholeBond), address(cash), 4), 5e6);
    }

    /// @dev An 18-decimal cash token against an 8-decimal feed: the conversion must scale UP, not truncate.
    function test_EighteenDecimalCash_ScalesUp() public {
        MockERC20 bigCash = new MockERC20("DAI", "DAI", 18);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        feed.setFreshNav(address(bond), 1.05e8);
        _register(_cfg(address(bond), address(bigCash), address(feed), KIND_NATIVE));

        assertEq(oracle.getPricePerShare(address(bond)), 1.05e18, "1.05 at 18 cash decimals");
    }

    /// @dev An 18-decimal NAV feed against a 6-decimal cash token: the conversion must scale DOWN and floor.
    function test_EighteenDecimalNavFeed_ScalesDownAndFloors() public {
        MockGyldNavFeed bigFeed = new MockGyldNavFeed(18);
        bigFeed.setFreshNav(address(bond), 1.050000000000999999e18);
        _register(_cfg(address(bond), address(cash), address(bigFeed), KIND_NATIVE));

        assertEq(oracle.getPricePerShare(address(bond)), 1.05e6, "the sub-unit tail is floored away");
    }

    /// @dev THE FOUR-SCALE CASE. A USD NAV feed at 18 decimals, a cash/USD feed at 8, a 6-decimal cash token
    ///      and an 18-decimal bond. Every scale in the formula is different, which is where an off-by-one
    ///      exponent would hide.
    function test_MismatchedFeedDecimals_UsdConversionIsExact() public {
        MockAggregator navFeed18 = new MockAggregator(18);
        navFeed18.setLatestAnswer(2e18); // 2.00 USD per bond
        MockAggregator cashFeed8 = new MockAggregator(8);
        cashFeed8.setLatestAnswer(0.5e8); // cash is worth 0.50 USD

        GyldBondRegistry.InstrumentConfig memory cfg =
            _cfg(address(bond), address(cash), address(navFeed18), KIND_CHAINLINK);
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed8);
        _register(cfg);

        // 2.00 USD at 0.50 USD per cash unit is 4.00 cash units, expressed in 6 decimals.
        assertEq(oracle.getPricePerShare(address(bond)), 4e6);
    }

    /// @dev A NAV below one unit of the cash token's precision is unusable rather than free.
    function test_SubUnitNav_IsUnusable() public {
        MockGyldNavFeed feed = new MockGyldNavFeed(18);
        feed.setFreshNav(address(bond), 1e11); // 1e-7 at 18 decimals, below 1e-6 cash precision
        _register(_cfg(address(bond), address(cash), address(feed), KIND_NATIVE));

        assertEq(
            oracle.previewNav(address(bond)).failureCode, uint8(GyldBondYieldSourceOracle.NavFailure.ZERO_OR_NEGATIVE)
        );
        vm.expectRevert(GyldBondYieldSourceOracle.INVALID_PRICE.selector);
        oracle.getPricePerShare(address(bond));
    }

    function test_GetTVL_ZeroSupplyIsZero() public {
        _registerDefault();
        assertEq(bond.totalSupply(), 0);
        assertEq(oracle.getTVL(address(bond)), 0);
    }

    /// @dev A balance large enough to overflow the TVL product must revert, not wrap into a small number.
    ///      Needs a zero-decimal bond, because with an 18-decimal bond the division by `bondScale` keeps even
    ///      a maximal balance inside range.
    function test_AbsurdBalance_OverflowsRatherThanWrapping() public {
        MockERC20 wholeBond = new MockERC20("Whole", "WB", 0);
        MockGyldNavFeed feed = new MockGyldNavFeed(8);
        feed.setFreshNav(address(wholeBond), 1e8);
        _register(_cfg(address(wholeBond), address(cash), address(feed), KIND_NATIVE));

        wholeBond.mint(holder, type(uint256).max);
        vm.expectRevert(); // Math.mulDiv: the result does not fit in a uint256
        oracle.getTVLByOwnerOfShares(address(wholeBond), holder);
    }

    /// @dev And an 18-decimal bond at a maximal balance does NOT overflow, because the scale division keeps
    ///      the product in range. Pinned so the asymmetry above is not read as a general overflow.
    function test_MaximalBalanceOnAnEighteenDecimalBond_DoesNotOverflow() public {
        _registerDefault();
        bond.mint(holder, type(uint256).max / 1e5);
        oracle.getTVLByOwnerOfShares(address(bond), holder);
    }

    /*//////////////////////////////////////////////////////////////
                      THE BATCH READ'S FAILURE MASK
    //////////////////////////////////////////////////////////////*/

    /// @dev One unusable instrument must not take a healthy sibling's price with it. This is what lets the
    ///      pricing pipeline publish the good rows and decline the bad ones.
    function test_BatchRead_IsolatesAFailingInstrument() public {
        MockERC20 healthyBond = new MockERC20("Healthy", "HB", 18);
        MockGyldNavFeed healthyFeed = new MockGyldNavFeed(8);
        healthyFeed.setFreshNav(address(healthyBond), 2e8);

        _registerDefault();
        _register(_cfg(address(healthyBond), address(cash), address(healthyFeed), KIND_NATIVE));

        bond.mint(holder, 1e18);
        healthyBond.mint(holder, 1e18);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        address[] memory sources = new address[](2);
        sources[0] = address(bond);
        sources[1] = address(healthyBond);
        address[][] memory owners = new address[][](2);
        owners[0] = new address[](1);
        owners[0][0] = holder;
        owners[1] = new address[](1);
        owners[1][0] = holder;

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertFalse(ok[0][0], "the suspended instrument declines to publish");
        assertEq(tvls[0][0], 0);
        assertTrue(ok[1][0], "the healthy sibling still publishes");
        assertEq(tvls[1][0], 2e6);
    }

    /// @dev Several owners of one instrument, one of whom holds nothing: a zero balance is a SUCCESSFUL zero,
    ///      not a failure, because it short-circuits before any feed is read.
    function test_BatchRead_ZeroBalanceIsASuccessfulZero() public {
        _registerDefault();
        bond.mint(holder, 3e18);
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        address[] memory sources = new address[](1);
        sources[0] = address(bond);
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](2);
        owners[0][0] = holder; // holds a suspended instrument: must fail
        owners[0][1] = second; // holds nothing: must succeed at zero

        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertFalse(ok[0][0]);
        assertTrue(ok[0][1]);
        assertEq(tvls[0][1], 0);
    }

    function test_BatchRead_RevertIf_ArrayLengthMismatch() public {
        address[] memory sources = new address[](2);
        address[][] memory owners = new address[][](1);
        vm.expectRevert(IYieldSourceOracle.ARRAY_LENGTH_MISMATCH.selector);
        oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev TVL is monotonic in NAV: a higher complete NAV can never mark a position lower.
    function testFuzz_TvlIsMonotonicInNav(uint96 navA, uint96 navB, uint96 balance) public {
        navA = uint96(bound(navA, 1e6, 1e14));
        navB = uint96(bound(navB, 1e6, 1e14));
        balance = uint96(bound(balance, 1e9, 1e24));
        if (navA > navB) (navA, navB) = (navB, navA);

        bond.mint(holder, balance);
        _register(_cfg(address(bond), address(cash), address(nativeFeed), KIND_NATIVE));

        nativeFeed.setFreshNav(address(bond), navA);
        uint256 low = oracle.getTVLByOwnerOfShares(address(bond), holder);
        nativeFeed.setFreshNav(address(bond), navB);
        uint256 high = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertLe(low, high, "a higher NAV never marks lower");
    }

    /// @dev TVL is monotonic in balance at a fixed NAV.
    function testFuzz_TvlIsMonotonicInBalance(uint96 small, uint96 extra) public {
        small = uint96(bound(small, 1e9, 1e20));
        extra = uint96(bound(extra, 0, 1e20));
        _register(_cfg(address(bond), address(cash), address(nativeFeed), KIND_NATIVE));

        bond.mint(holder, small);
        uint256 before = oracle.getTVLByOwnerOfShares(address(bond), holder);
        bond.mint(holder, extra);
        assertLe(before, oracle.getTVLByOwnerOfShares(address(bond), holder));
    }

    /// @dev Asset output never exceeds the exact product, for any NAV and size: rounding always favours the
    ///      vault. This is the invariant that stops a withdrawer extracting a wei of free value per call.
    function testFuzz_AssetOutputNeverExceedsTheExactValue(uint96 nav, uint96 shares) public {
        nav = uint96(bound(nav, 1e6, 1e14));
        shares = uint96(bound(shares, 1, type(uint96).max));
        _register(_cfg(address(bond), address(cash), address(nativeFeed), KIND_NATIVE));
        nativeFeed.setFreshNav(address(bond), nav);

        uint256 navInCash = oracle.getPricePerShare(address(bond));
        uint256 out = oracle.getAssetOutput(address(bond), address(cash), shares);
        assertLe(out, (uint256(shares) * navInCash) / 1e18, "never rounds in the holder's favour");
    }

    /// @dev Withdrawing then depositing the same cash amount can never leave the holder with more shares than
    ///      they burned, for any NAV.
    function testFuzz_WithdrawDepositRoundTripNeverCreatesShares(uint96 nav, uint96 assets) public {
        nav = uint96(bound(nav, 1e6, 1e14));
        assets = uint96(bound(assets, 1, 1e18));
        _register(_cfg(address(bond), address(cash), address(nativeFeed), KIND_NATIVE));
        nativeFeed.setFreshNav(address(bond), nav);

        uint256 burned = oracle.getWithdrawalShareOutput(address(bond), address(cash), assets);
        uint256 credited = oracle.getShareOutput(address(bond), address(cash), assets);
        assertGe(burned, credited, "a round trip never creates shares");
    }

    /// @dev A suspended instrument's balance read is total for any balance.
    function testFuzz_SuspendedBalanceReadIsTotal(uint256 amount) public {
        amount = bound(amount, 0, 1e30);
        bond.mint(holder, amount);
        _registerDefault();
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        assertEq(oracle.getBalanceOfOwner(address(bond), holder), amount);
    }
}
