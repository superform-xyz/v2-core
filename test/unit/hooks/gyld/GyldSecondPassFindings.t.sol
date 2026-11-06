// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import "forge-std/Test.sol";

import { GyldBondRegistry } from "../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldTradeGuardHook } from "../../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { ApproveAndTradeGyldBondHook } from "../../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";

import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockAggregator } from "../../../mocks/MockAggregator.sol";
import { MockGyldNavFeed } from "../../../mocks/gyld/MockGyldNavFeed.sol";
import { MockGyldSettlement } from "../../../mocks/gyld/MockGyldSettlement.sol";
import { IGyldTradePolicy } from "../../../../src/interfaces/accounting/IGyldTradePolicy.sol";
import { MockGyldTradePolicy } from "../../../../test/mocks/gyld/MockGyldTradePolicy.sol";

/// @dev A bond token that can be redenominated after registration, modelling a proxied or upgradeable
///      series token. Gyld's real stack deploys each series through a TokenFactory, so a proxy is the
///      likely shape.
contract MockRedenominatingBond {
    uint8 public decimals;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    constructor(uint8 decimals_) {
        decimals = decimals_;
    }

    function setDecimals(uint8 decimals_) external {
        decimals = decimals_;
    }

    /// @dev Redenominate: rescale every tracked balance along with the decimals, as a real redenomination
    ///      would. `holders` is explicit so the mock stays trivial.
    function redenominate(uint8 newDecimals, address holder) external {
        uint256 old = balanceOf[holder];
        uint8 oldDecimals = decimals;
        decimals = newDecimals;
        uint256 rescaled = newDecimals >= oldDecimals
            ? old * 10 ** (newDecimals - oldDecimals)
            : old / 10 ** (oldDecimals - newDecimals);
        totalSupply = totalSupply - old + rescaled;
        balanceOf[holder] = rescaled;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

/// @dev A NAV feed reporting an absurd number of decimals, to probe the unprotected multiplications in
///      the USD conversion.
contract MockHighDecimalsFeed {
    uint8 public decimals;

    constructor(uint8 d) {
        decimals = d;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, 1e8, block.timestamp, block.timestamp, 1);
    }
}

/// @title GyldSecondPassFindingsTest
/// @notice Executable verification of the findings from the SECOND independent review round. Each test
///         reproduces the current behaviour so the finding is a fact rather than an assertion, and so the
///         assertion flips visibly when a fix lands.
contract GyldSecondPassFindingsTest is Test {
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    GyldTradeGuardHook internal guard;
    MockGyldSettlement internal settlement;

    MockERC20 internal cash; // 6 decimals
    MockGyldNavFeed internal nativeFeed; // 8 decimals
    MockAggregator internal chainlinkFeed; // 8 decimals

    address internal admin = address(0xA11CE);
    address internal holder = address(0xB0DB01DE2);

    /// @dev The shipping caps from ConstantsOtherHooks, restated here because this suite is about what
    ///      happens when they are applied to the WRONG direction.
    uint256 internal constant CASH_CAP = 500_000e6;
    uint256 internal constant BOND_CAP = 500_000e18;
    MockGyldTradePolicy internal tradePolicy;


    function setUp() public {
        tradePolicy = new MockGyldTradePolicy();
        vm.warp(1_800_000_000);
        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry));
        guard = new GyldTradeGuardHook(address(oracle));
        settlement = new MockGyldSettlement();

        cash = new MockERC20("Vault Bridge USDC", "vbUSDC", 6);
        nativeFeed = new MockGyldNavFeed(8);
        chainlinkFeed = new MockAggregator(8);
        chainlinkFeed.setLatestAnswer(1.02523785e8);
    }

    function _register(GyldBondRegistry.InstrumentConfig memory cfg) internal {
        vm.prank(admin);
        registry.registerInstrument(cfg);
    }

    function _cfg(
        address bondToken,
        address feed,
        uint8 kind
    )
        internal
        view
        returns (GyldBondRegistry.InstrumentConfig memory cfg)
    {
        cfg.bondToken = bondToken;
        cfg.cashToken = address(cash);
        cfg.navFeed = feed;
        cfg.navFeedKind = kind;
        cfg.maxObservationAge = 2 days;
        cfg.maxPublicationAge = 2 hours;
    }

    /*//////////////////////////////////////////////////////////////
       FINDING 1 — A STALE CACHED SCALE MARKS A POSITION AT ZERO,
                   AND THE BATCH READ CALLS THAT A SUCCESS
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED, and this is the worst shape a pricing bug can take: not a revert, not a wrong number
    ///      a human would notice, but a SILENT ZERO that the batch read reports as `succeeded == true`, so
    ///      the pipeline's decline-to-publish safety net never fires.
    ///      `bondScale` is cached at registration; `oracle.decimals()` is read LIVE. Nothing compares them.
    ///      Proposed fix: have the oracle assert the cached scales against live `decimals()` on the VALUE
    ///      path, and return the cached scale from `decimals()` so the oracle cannot contradict itself.
    function test_Finding_StaleBondScale_MarksPositionAtZeroAndReportsSuccess() public {
        MockRedenominatingBond bond = new MockRedenominatingBond(18);
        nativeFeed.setFreshNav(address(bond), 102.523785e8); // a bond near par, as in the plan's example
        _register(_cfg(address(bond), address(nativeFeed), registry.FEED_KIND_GYLD_NATIVE()));

        bond.mint(holder, 1500e18);
        uint256 before = oracle.getTVLByOwnerOfShares(address(bond), holder);
        assertEq(before, 153_785_677_500, "153,785.6775 vbUSDC, correct");

        // The series token is redenominated to 6 decimals. Balances rescale; the cached scale does not.
        bond.redenominate(6, holder);
        assertEq(bond.balanceOf(holder), 1500e6, "the holder still owns 1500 whole bonds");
        assertEq(oracle.decimals(address(bond)), 6, "the oracle reports the LIVE decimals");
        assertEq(registry.getInstrumentConfig(address(bond)).bondScale, 1e18, "but the registry still caches 1e18");

        // The mark collapses to zero without reverting.
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 0, "a 153k position now marks at ZERO");

        // And the batch read calls that a success, so the pipeline publishes it.
        address[] memory sources = new address[](1);
        sources[0] = address(bond);
        address[][] memory owners = new address[][](1);
        owners[0] = new address[](1);
        owners[0][0] = holder;
        (uint256[][] memory tvls, bool[][] memory ok) = oracle.getTVLByOwnerOfSharesMultiple(sources, owners);
        assertTrue(ok[0][0], "reported as a SUCCESSFUL read");
        assertEq(tvls[0][0], 0, "with a value of zero");
    }

    /// @dev The inverse direction overstates instead, by the same mechanism and equally silently.
    function test_Finding_StaleBondScale_OverstatesWhenDecimalsRise() public {
        MockRedenominatingBond bond = new MockRedenominatingBond(6);
        nativeFeed.setFreshNav(address(bond), 1e8);
        _register(_cfg(address(bond), address(nativeFeed), registry.FEED_KIND_GYLD_NATIVE()));

        bond.mint(holder, 1500e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), holder), 1500e6, "1500 vbUSDC, correct");

        bond.redenominate(18, holder);
        assertEq(
            oracle.getTVLByOwnerOfShares(address(bond), holder),
            1500e18,
            "the same 1500 bonds now mark at 1.5e18 cash units, a trillion times too high"
        );
    }

    /// @dev The oracle contradicts ITSELF: its own `decimals()` and the scale it values with disagree.
    ///      That inconsistency is what lets the ledger and the TVL read diverge.
    function test_Finding_OracleDecimalsAndCachedScaleCanDisagree() public {
        MockRedenominatingBond bond = new MockRedenominatingBond(18);
        nativeFeed.setFreshNav(address(bond), 1e8);
        _register(_cfg(address(bond), address(nativeFeed), registry.FEED_KIND_GYLD_NATIVE()));
        bond.setDecimals(6);

        assertEq(oracle.decimals(address(bond)), 6, "live");
        assertEq(10 ** oracle.decimals(address(bond)), 1e6);
        assertEq(registry.getInstrumentConfig(address(bond)).bondScale, 1e18, "cached");
    }

    /*//////////////////////////////////////////////////////////////
      FINDING 2 — THE TWO TRADE INSTANCES ARE NOT BOUND TO A DIRECTION
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED, and this one is a flaw in the DEPLOY WIRING added earlier today. The two instances
    ///      exist so each direction's cap is denominated in that direction's input token. But `_validatePair`
    ///      accepts EITHER orientation on EITHER instance, and `CashIn`/`BondIn` are deploy-key strings with
    ///      no on-chain meaning. So a BUY leaf presented against the bond-side instance gets a cash cap of
    ///      500,000e18 raw vbUSDC wei, which is about 87,000x the token's entire live supply on Katana.
    ///      Because `outputMin` is caller-chosen, that cap IS the loss bound, so it becomes vacuous.
    ///      Proposed fix: an `INPUT_IS_BOND` immutable checked in `_validatePair`, set per instance at deploy.
    function test_Finding_BuyLeafAgainstTheBondInstanceGetsAVacuousCap() public {
        MockERC20 bond = new MockERC20("Gyld Bond", "GB", 18);
        _register(_cfg(address(bond), address(chainlinkFeed), registry.FEED_KIND_CHAINLINK()));

        // The SELL-side instance, carrying the bond-denominated cap.
        ApproveAndTradeGyldBondHook bondInHook = new ApproveAndTradeGyldBondHook(address(settlement), BOND_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.SELL);

        // A BUY leaf: cash in, bond out. The cash amount is far above the cash-side cap AND above the
        // entire live vbUSDC supply on Katana (about 5.72M), yet it builds.
        uint256 absurdCash = 1_000_000_000e6; // one billion vbUSDC
        assertGt(absurdCash, CASH_CAP, "far above the cash-side cap");
        bytes memory data = _tradeData(address(cash), address(bond), absurdCash);

        bondInHook.build(address(0), address(this), data); // no revert
        assertLt(absurdCash, BOND_CAP, "because the bond-denominated cap is 1e12 larger");
    }

    /// @dev The mirror case: a SELL leaf against the cash-side instance is capped at 5e11 wei of an
    ///      18-decimal bond, i.e. 0.0000005 bonds, silently bricking the sell side.
    function test_Finding_SellLeafAgainstTheCashInstanceIsBricked() public {
        MockERC20 bond = new MockERC20("Gyld Bond", "GB", 18);
        _register(_cfg(address(bond), address(chainlinkFeed), registry.FEED_KIND_CHAINLINK()));

        ApproveAndTradeGyldBondHook cashInHook = new ApproveAndTradeGyldBondHook(address(settlement), CASH_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);

        bytes memory data = _tradeData(address(bond), address(cash), 1e18); // one whole bond
        vm.expectRevert(ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
        cashInHook.build(address(0), address(this), data);
    }

    /// @dev And the deploy script's guards cannot detect either misuse: they only assert the caps are
    ///      non-zero, distinct, and that the two addresses differ. All three hold in both cases above.
    function test_Finding_DeployGuardsCannotDetectDirectionMisuse() public {
        MockERC20 bond = new MockERC20("Gyld Bond", "GB", 18);
        _register(_cfg(address(bond), address(chainlinkFeed), registry.FEED_KIND_CHAINLINK()));

        ApproveAndTradeGyldBondHook a = new ApproveAndTradeGyldBondHook(address(settlement), CASH_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        ApproveAndTradeGyldBondHook b = new ApproveAndTradeGyldBondHook(address(settlement), BOND_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.SELL);

        assertTrue(address(a) != address(b), "distinct addresses, as the deploy asserts");
        assertTrue(a.MAX_INPUT_AMOUNT() != b.MAX_INPUT_AMOUNT(), "distinct caps, as the deploy asserts");
        // Yet neither knows which direction it is for: both accept both orientations.
        bytes memory buy = _tradeData(address(cash), address(bond), 1000e6);
        bytes memory sell = _tradeData(address(bond), address(cash), 1000e6);
        a.build(address(0), address(this), buy);
        a.build(address(0), address(this), sell);
        b.build(address(0), address(this), buy);
        b.build(address(0), address(this), sell);
    }

    /*//////////////////////////////////////////////////////////////
       FINDING 8 SUB-NOTE — THE UNPROTECTED MULTIPLY IN THE USD PATH
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `_toCashUnits` computes `navFeedScale * answer` and `cashFeedScale * cashScale` as
    ///      plain uint256 multiplies OUTSIDE `mulDiv`, and `_precomputeScales` accepts any `decimals()` up
    ///      to 77. A NAV feed reporting a high enough decimals therefore PANICS, which breaks `previewNav`'s
    ///      documented totality in a place the known reverting-feed finding does not cover.
    ///      Proposed fix: bound `decimals()` to something sane (36) in `_validateRegistration`.
    function test_Finding_HighDecimalsFeedPanicsTheUsdConversion() public {
        MockERC20 bond = new MockERC20("Gyld Bond", "GB", 18);
        MockHighDecimalsFeed bigFeed = new MockHighDecimalsFeed(70);
        MockAggregator cashFeed = new MockAggregator(18);
        cashFeed.setLatestAnswer(1e18);

        GyldBondRegistry.InstrumentConfig memory cfg =
            _cfg(address(bond), address(bigFeed), registry.FEED_KIND_CHAINLINK());
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = address(cashFeed);
        _register(cfg);

        // 10 ** 70 was accepted as a scale; the conversion's bare multiply now overflows.
        assertEq(registry.getInstrumentConfig(address(bond)).navFeedScale, 10 ** 70, "an absurd scale stored");
        vm.expectRevert(stdError.arithmeticError);
        oracle.previewNav(address(bond));
    }

    /// @dev And the registry accepts the absurd decimals in the first place, which is where it should stop.
    function test_Finding_RegistryAcceptsAbsurdFeedDecimals() public {
        MockERC20 bond = new MockERC20("Gyld Bond", "GB", 18);
        MockHighDecimalsFeed bigFeed = new MockHighDecimalsFeed(77);
        _register(_cfg(address(bond), address(bigFeed), registry.FEED_KIND_CHAINLINK()));
        assertEq(registry.getInstrumentConfig(address(bond)).navFeedScale, 10 ** 77, "no upper bound on scale");
    }

    /*//////////////////////////////////////////////////////////////
      FINDING 10 — PREVIEW AND STRICT PATHS DISAGREE ON WHICH REASON
    //////////////////////////////////////////////////////////////*/

    /// @dev FIXED. The preview now mirrors the strict path's ordering, so for an instrument that is BOTH
    ///      suspended and named with the wrong cash token, both paths name suspension. Previously the
    ///      preview blamed a transient condition while execution reverted on a permanently wrong leaf, so an
    ///      OMS trusting the preview would retry a leaf that could never execute.
    function test_Fixed_PreviewAndStrictPathsNameTheSameReason() public {
        MockERC20 bond = new MockERC20("Gyld Bond", "GB", 18);
        MockERC20 wrongCash = new MockERC20("DAI", "DAI", 18);
        _register(_cfg(address(bond), address(chainlinkFeed), registry.FEED_KIND_CHAINLINK()));
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        bytes memory leaf = abi.encodePacked(
            bytes32(0), bytes20(address(bond)), bytes20(address(wrongCash)), uint256(2 days), uint256(2 hours)
        );

        assertEq(
            guard.previewTradable(leaf, holder),
            uint256(uint8(GyldBondYieldSourceOracle.NavFailure.SUSPENDED)),
            "the preview names suspension"
        );
        vm.expectRevert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        guard.build(address(0), holder, leaf);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _tradeData(
        address inputToken,
        address outputToken,
        uint256 inputAmount
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = abi.encode(block.timestamp + 1 hours, hex"deadbeef");
        return bytes.concat(
            abi.encodePacked(
                bytes32(0),
                bytes20(address(0)),
                bytes20(inputToken),
                bytes20(outputToken),
                inputAmount,
                uint256(1),
                uint256(1),
                false,
                payload.length
            ),
            payload
        );
    }
}
