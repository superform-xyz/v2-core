// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IAggregatorV3 } from "modulekit/integrations/interfaces/chainlink/IAggregatorV3.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ApproveAndTradeGyldBondHook } from "../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";
import { GyldTradeGuardHook } from "../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { GyldBondRegistry } from "../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockGyldSettlement } from "../../mocks/gyld/MockGyldSettlement.sol";
import { MockGyldNavFeed } from "../../mocks/gyld/MockGyldNavFeed.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";
import { ConstantsOtherHooks } from "../../../script/utils/ConstantsOtherHooks.sol";
import { IGyldTradePolicy } from "../../../src/interfaces/accounting/IGyldTradePolicy.sol";
import { GyldTradePolicy } from "../../../src/accounting/oracles/GyldTradePolicy.sol";
import { MockSuperVaultStrategyState } from "../../../test/mocks/gyld/MockSuperVaultStrategyState.sol";

/// @dev `ConstantsOtherHooks` and the test `Constants` both declare several names, so the production
///      values are read through this wrapper instead of by inheritance. Same approach as
///      `ProdBinanceConstants`.
contract ProdGyldConstants is ConstantsOtherHooks {
    function cashCap() external pure returns (uint256) {
        return GYLD_MAX_CASH_INPUT_AMOUNT_KATANA;
    }

    function bondCap() external pure returns (uint256) {
        return GYLD_MAX_BOND_INPUT_AMOUNT_KATANA;
    }

    function cashToken() external pure returns (address) {
        return GYLD_CASH_TOKEN_KATANA;
    }
}

/// @title GyldBondKatanaFork
/// @notice End-to-end fork tests on REAL Katana mainnet (chain 747474), the chain Gyld bonds are intended for.
/// @dev What is real and what is not. Gyld's settlement contract and NAV feed are deployed NOWHERE yet, so
///      those two are mocks deployed onto the fork, as is the bond token. Everything else is live Katana:
///      - the cash token is real vbUSDC, whose 6 decimals and real `transferFrom` semantics drive the trade;
///      - the cash/USD conversion reads the real Chainlink USDC/USD aggregator, so the "never assume cash is
///        one dollar" path is exercised against a genuinely off-par live answer rather than a mock at 1e8;
///      - the account is a real ERC-7579 smart account driven by a real ERC-4337 UserOp.
/// @dev Runs against KATANA_RPC_URL, defaulting to the public https://rpc.katana.network. Skips cleanly
///      without connectivity. Excluded from `ftest-ci` via FLARE_FORK_TESTS, because it depends on a public
///      RPC and on a live feed's heartbeat.
contract GyldBondKatanaFork is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                           LIVE KATANA ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @dev Vault Bridge USDC: Katana's canonical USDC, 6 decimals, a plain ERC-20 (NOT an ERC-4626 share)
    address internal constant VB_USDC = 0x203A662b0BD271A6ed5a60EdFbd04bFce608FD36;
    /// @dev Chainlink USDC/USD on Katana, 8 decimals
    address internal constant USDC_USD_FEED = 0xbe5CE90e16B9d9d988D64b0E1f6ed46EbAfb9606;
    uint256 internal constant KATANA_CHAIN_ID = 747_474;
    /// @dev Katana caps a single transaction at 2^24 gas, far below its 120M block limit. Any batch this
    ///      protocol builds has to fit inside it, so the end-to-end leg below asserts against it.
    uint256 internal constant KATANA_PER_TX_GAS_CAP = 16_777_216;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    ApproveAndTradeGyldBondHook internal buyHook;
    ApproveAndTradeGyldBondHook internal sellHook;
    GyldTradeGuardHook internal guardHook;
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    MockGyldSettlement internal settlement;
    MockGyldNavFeed internal navFeed;
    MockERC20 internal bond;

    AccountInstance internal instance;
    address internal strategy;
    ISuperExecutor internal superExecutor;

    address internal admin = address(0xA11CE);
    bool internal forked;

    /// @dev One whole bond is worth 1.00 USD at entry, reported with 8 decimals like the cash feed
    uint256 internal constant NAV_USD_AT_ENTRY = 1.0e8;
    uint256 internal constant NAV_USD_AFTER_COUPON = 1.02e8;

    uint256 internal constant CASH_CAP = 1_000_000e6;
    uint256 internal constant BOND_CAP = 1_000_000e18;
    uint256 internal constant LEAF_OBS_AGE = 2 days;
    uint256 internal constant LEAF_PUB_AGE = 1 days;

    receive() external payable { }
    GyldTradePolicy internal tradePolicy;
    MockSuperVaultStrategyState internal aggregator;


    function setUp() public {
        string memory rpc = envOr("KATANA_RPC_URL", "https://rpc.katana.network");
        if (bytes(rpc).length == 0) return;
        try vm.createSelectFork(rpc) {
            forked = true;
        } catch {
            return;
        }

        bond = new MockERC20("Gyld Bond 2030", "GB30", 18);
        navFeed = new MockGyldNavFeed(8);
        navFeed.setFreshNav(address(bond), NAV_USD_AT_ENTRY);
        settlement = new MockGyldSettlement();

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(new SuperLedgerConfiguration()), address(registry));
        aggregator = new MockSuperVaultStrategyState();
        // Real policy, real aggregator shape: AGGREGATOR == 0 would exercise a
        // configuration that cannot ship, since a paused strategy could still trade.
        tradePolicy =
            new GyldTradePolicy(address(registry), address(oracle), address(aggregator), 1 days);

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        cfg.cashToken = VB_USDC;
        // F1: a direction with a zero tolerance is reported as unconfigured, not defaulted.
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        cfg.navIsUsdDenominated = true; // the NAV feed quotes USD, so it MUST go through the cash feed
        cfg.cashFeed = USDC_USD_FEED;
        cfg.requiresObservationTime = true;
        // Generous registry bounds so the LIVE feed's heartbeat never makes this suite flaky; the leaf's own
        // bounds (one day / two days) are what the guard actually enforces on the NAV side.
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        guardHook = new GyldTradeGuardHook(address(oracle));
        buyHook = new ApproveAndTradeGyldBondHook(address(settlement), CASH_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        sellHook = new ApproveAndTradeGyldBondHook(address(settlement), BOND_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.SELL);

        instance = makeAccountInstance(keccak256("gyld-katana-strategy"));
        strategy = instance.account;
        // The policy fails closed for an address the aggregator does not know, so the
        // strategy has to exist there before any trade is attempted.
        aggregator.register(strategy);
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        deal(VB_USDC, strategy, 10_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _requireFork() internal {
        if (!forked) vm.skip(true);
    }

    function _liveCashPrice() internal view returns (uint256 answer, uint256 updatedAt) {
        (, int256 raw,, uint256 at,) = IAggregatorV3(USDC_USD_FEED).latestRoundData();
        return (uint256(raw), at);
    }

    /// @dev What the oracle should produce: NAV in USD converted through the live cash price into cash units.
    function _expectedNavInCash(uint256 navUsd) internal view returns (uint256) {
        (uint256 cashPrice,) = _liveCashPrice();
        // navUsd (1e8) * cashFeedScale (1e8) * cashScale (1e6) / (navFeedScale (1e8) * cashPrice (1e8))
        return (navUsd * 1e8 * 1e6) / (1e8 * cashPrice);
    }

    function _guardData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(address(bond)), bytes20(VB_USDC), LEAF_OBS_AGE, LEAF_PUB_AGE);
    }

    function _tradeData(
        bytes32 quoteId,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputQuote,
        uint256 outputMin,
        uint256 deadline
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory venue =
            settlement.encodeFill(quoteId, strategy, inputToken, outputToken, inputAmount, outputQuote, deadline);
        bytes memory payload = abi.encode(deadline, venue);
        return bytes.concat(
            abi.encodePacked(
                bytes32(0),
                bytes20(address(0)),
                bytes20(inputToken),
                bytes20(outputToken),
                inputAmount,
                outputQuote,
                outputMin,
                false,
                payload.length
            ),
            payload
        );
    }

    function _op(address hook, bytes memory tradeData) internal returns (UserOpData memory) {
        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = hook;
        bytes[] memory data = new bytes[](2);
        data[0] = _guardData();
        data[1] = tradeData;
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
        );
    }

    /*//////////////////////////////////////////////////////////////
                        LIVE KATANA INFRASTRUCTURE
    //////////////////////////////////////////////////////////////*/

    function test_Fork_IsKatanaMainnet() public {
        _requireFork();
        assertEq(block.chainid, KATANA_CHAIN_ID, "forked the wrong chain");
    }

    /// @dev Invariants on the live cash token, never exact values: a supply or a holder set can change.
    function test_Live_VbUsdcIsAPlainSixDecimalToken() public {
        _requireFork();
        assertEq(IERC20Metadata(VB_USDC).decimals(), 6, "vbUSDC is 6 decimals");
        assertEq(IERC20Metadata(VB_USDC).symbol(), "vbUSDC");
        assertGt(IERC20(VB_USDC).totalSupply(), 0, "live supply");
        assertGt(VB_USDC.code.length, 0, "real bytecode, not an etched stub");
    }

    /// @dev The live Chainlink answer, checked only for shape. This is also the proof that the "cash is one
    ///      dollar" assumption is false in practice: the live answer is near par but not AT par.
    function test_Live_UsdcUsdFeedIsUsable() public {
        _requireFork();
        assertEq(IAggregatorV3(USDC_USD_FEED).decimals(), 8);
        (uint256 answer, uint256 updatedAt) = _liveCashPrice();
        assertGt(answer, 0.9e8, "a plausible USDC price");
        assertLt(answer, 1.1e8, "a plausible USDC price");
        assertLe(updatedAt, block.timestamp, "not published in the future");
        assertLt(block.timestamp - updatedAt, 7 days, "within the registry bound this suite configures");
    }

    /// @dev The whole reason the cash feed is in the config. The oracle's cash-denominated NAV tracks the live
    ///      USDC price, so it is NOT simply the USD NAV rescaled.
    function test_Live_CashDenominatedNavUsesTheLiveUsdcPrice() public {
        _requireFork();
        uint256 nav = oracle.getPricePerShare(address(bond));
        assertEq(nav, _expectedNavInCash(NAV_USD_AT_ENTRY), "converted through the live feed");

        (uint256 cashPrice,) = _liveCashPrice();
        if (cashPrice < 1e8) {
            assertGt(nav, 1e6, "USDC below par means more cash units per bond");
        } else if (cashPrice > 1e8) {
            assertLt(nav, 1e6, "USDC above par means fewer cash units per bond");
        }
    }

    /*//////////////////////////////////////////////////////////////
                    THE SHIPPING CAP, AGAINST LIVE SUPPLY
    //////////////////////////////////////////////////////////////*/

    /// @dev THE CHECK A UNIT TEST CANNOT MAKE. `MAX_INPUT_AMOUNT` is the only on-chain bound on a
    ///      compromised manager key, because `outputMin` is caller-chosen and uncommitted. A cap at or above
    ///      the cash token's total supply therefore bounds NOTHING. An earlier draft of the shipping constant
    ///      was 10,000,000 vbUSDC against a live supply of about 5.72M, i.e. 1.75x the entire supply. This
    ///      reads the real supply so the constant cannot drift back above it unnoticed.
    function test_Live_CashCapIsBelowTheRealVbUsdcSupply() public {
        _requireFork();
        uint256 shippingCap = new ProdGyldConstants().cashCap();
        uint256 supply = IERC20(VB_USDC).totalSupply();
        assertGt(supply, 0, "live supply");
        assertLt(shippingCap, supply, "a cap at or above total supply bounds nothing");
        // And not merely below it: a cap within a hair of total supply is the same failure with a smaller
        // number. Require real headroom.
        assertLt(shippingCap, supply / 2, "the cap should be a fraction of circulating supply, not most of it");
    }

    /// @dev The cash cap must be scaled to the DECIMALS of the token it is denominated in. Read from the live
    ///      token rather than from a constant, so a token swap or a decimals change is caught here.
    function test_Live_CashCapMatchesTheRealTokenDecimals() public {
        _requireFork();
        ProdGyldConstants k = new ProdGyldConstants();
        // The documented cash token must be the one the cap is scaled for.
        assertEq(k.cashToken(), VB_USDC, "the constant names the token this suite reads");
        assertEq(IERC20Metadata(VB_USDC).decimals(), 6, "vbUSDC is 6 decimals");
        // 500,000 whole units at the LIVE token's decimals, so a mis-scaled constant fails loudly.
        assertEq(k.cashCap() / 10 ** IERC20Metadata(VB_USDC).decimals(), 500_000, "500,000 whole vbUSDC");
        // The bond cap is the same whole-unit size, on the 18-decimal assumption the constant documents.
        assertEq(k.bondCap() / 10 ** 18, 500_000, "500,000 whole bonds, assuming an 18-decimal bond token");
    }

    /*//////////////////////////////////////////////////////////////
                      THE FIRST PROOF, ON REAL KATANA
    //////////////////////////////////////////////////////////////*/

    /// @dev Buy a bond with real vbUSDC, hold it through a NAV update, sell it back. Same proof as the local
    ///      integration suite, but against live token bytecode and a live price feed.
    function test_E2E_BuyHoldSellOnKatana() public {
        _requireFork();
        uint256 cashIn = 1000e6;
        uint256 bondsOut = 1000e18;
        uint256 cashBefore = IERC20(VB_USDC).balanceOf(strategy);

        // ---- BUY ----
        uint256 gasBefore = gasleft();
        executeOp(
            _op(
                address(buyHook),
                _tradeData(
                    keccak256("katana-buy"),
                    VB_USDC,
                    address(bond),
                    cashIn,
                    bondsOut,
                    bondsOut,
                    block.timestamp + 1 hours
                )
            )
        );
        uint256 gasUsed = gasBefore - gasleft();

        assertEq(bond.balanceOf(strategy), bondsOut, "bonds held");
        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore - cashIn, "real vbUSDC left the account");
        assertEq(IERC20(VB_USDC).allowance(strategy, address(settlement)), 0, "no standing allowance");
        assertLt(gasUsed, KATANA_PER_TX_GAS_CAP, "the guarded leg fits under Katana's per-transaction gas cap");

        // The holding values at the live cash price, not at a notional dollar.
        assertEq(
            oracle.getTVLByOwnerOfShares(address(bond), strategy),
            (bondsOut * _expectedNavInCash(NAV_USD_AT_ENTRY)) / 1e18
        );

        // ---- HOLD through a coupon accrual ----
        // The hold is deliberately short. Warping on a fork ages the LIVE cash feed too, and once its last
        // publication falls outside `maxPublicationAge` the conversion fails closed, exactly as it should.
        // A long hold would therefore be testing the fork's frozen feed, not the instrument.
        vm.warp(block.timestamp + 2 days);
        navFeed.setFreshNav(address(bond), NAV_USD_AFTER_COUPON);
        (, uint256 cashUpdatedAt) = _liveCashPrice();
        assertLt(block.timestamp - cashUpdatedAt, 7 days, "the live cash feed is still inside the bound");
        uint256 valueAfter = oracle.getTVLByOwnerOfShares(address(bond), strategy);
        assertEq(valueAfter, (bondsOut * _expectedNavInCash(NAV_USD_AFTER_COUPON)) / 1e18);
        assertGt(valueAfter, (bondsOut * _expectedNavInCash(NAV_USD_AT_ENTRY)) / 1e18, "coupon accrued");

        // ---- SELL back to cash ----
        uint256 cashBack = 1020e6;
        deal(VB_USDC, address(settlement), cashBack); // the venue is the counterparty on the cash leg
        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(sellHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardData();
        data[1] = _tradeData(
            keccak256("katana-sell"), address(bond), VB_USDC, bondsOut, cashBack, cashBack, block.timestamp + 1 hours
        );
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );

        assertEq(bond.balanceOf(strategy), 0, "bonds sold");
        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore - cashIn + cashBack, "real cash back");
        assertGt(IERC20(VB_USDC).balanceOf(strategy), cashBefore, "the round trip earned the coupon");
        assertEq(IERC20(VB_USDC).allowance(strategy, address(settlement)), 0);
    }

    /// @dev THE SAME PROOF ON THE CONFIGURATION THAT CAN ACTUALLY SHIP. Every other test in this suite
    ///      registers its instrument with `FEED_KIND_GYLD_NATIVE`, because that is what the integration
    ///      brief assumed. Research into Gyld's real stack (2026-11-02) found their NAV oracle is
    ///      `KaleidoscopeNAVFeed`, documented as Chainlink `AggregatorV3Interface`-compatible with 8
    ///      decimals, so the native branch has no feed to serve it. This test therefore runs the buy and
    ///      sell on `FEED_KIND_CHAINLINK` against an 8-decimal aggregator, still with real vbUSDC and still
    ///      converting through the real live Chainlink USDC/USD feed. See the session log, finding N1/N2/N8.
    function test_E2E_RealisticChainlinkFeedConfiguration_BuyAndSell() public {
        _requireFork();

        // A second instrument, Chainlink-shaped, USD-denominated through the live cash feed.
        MockERC20 clBond = new MockERC20("Gyld Bond CL", "GBCL", 18);
        MockAggregator clFeed = new MockAggregator(8);
        clFeed.setLatestAnswer(int256(NAV_USD_AT_ENTRY));

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(clBond);
        cfg.navFeed = address(clFeed);
        cfg.navFeedKind = registry.FEED_KIND_CHAINLINK();
        cfg.cashToken = VB_USDC;
        // F1: a direction with a zero tolerance is reported as unconfigured, not defaulted.
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        cfg.navIsUsdDenominated = true;
        cfg.cashFeed = USDC_USD_FEED;
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        // A Chainlink-shaped feed reports no observation clock, so that half of the two-clock design is
        // inert here. Pinned, because it is the only configuration a real instrument can use.
        assertEq(oracle.previewNav(address(clBond)).observedAt, 0, "no observation clock on this branch");
        assertEq(
            oracle.getPricePerShare(address(clBond)),
            _expectedNavInCash(NAV_USD_AT_ENTRY),
            "still converted through the LIVE cash feed"
        );

        uint256 cashIn = 500e6;
        uint256 bondsOut = 500e18;
        uint256 cashBefore = IERC20(VB_USDC).balanceOf(strategy);

        bytes memory guardLeaf =
            abi.encodePacked(bytes32(0), bytes20(address(clBond)), bytes20(VB_USDC), LEAF_OBS_AGE, LEAF_PUB_AGE);
        bytes memory buyLeaf = _tradeData(
            keccak256("cl-buy"), VB_USDC, address(clBond), cashIn, bondsOut, bondsOut, block.timestamp + 1 hours
        );
        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(buyHook);
        bytes[] memory data = new bytes[](2);
        data[0] = guardLeaf;
        data[1] = buyLeaf;
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );

        assertEq(clBond.balanceOf(strategy), bondsOut, "bonds held on the shippable configuration");
        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore - cashIn, "real vbUSDC spent");
        assertEq(IERC20(VB_USDC).allowance(strategy, address(settlement)), 0, "no standing allowance");

        // And sell back, through the bond-side instance.
        uint256 cashBack = 500e6;
        deal(VB_USDC, address(settlement), cashBack);
        bytes memory sellLeaf = _tradeData(
            keccak256("cl-sell"), address(clBond), VB_USDC, bondsOut, cashBack, cashBack, block.timestamp + 1 hours
        );
        bytes[] memory sellData = new bytes[](2);
        sellData[0] = guardLeaf;
        sellData[1] = sellLeaf;
        address[] memory sellHooks = new address[](2);
        sellHooks[0] = address(guardHook);
        sellHooks[1] = address(sellHook);
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: sellHooks, hooksData: sellData }))
            )
        );

        assertEq(clBond.balanceOf(strategy), 0, "bonds sold");
        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore, "flat on cash at a flat NAV");
    }

    /// @dev And the guard still refuses a stale NAV on that branch, where the publication clock is the ONLY
    ///      freshness signal available.
    function test_E2E_RealisticConfiguration_StalePublicationStillRefuses() public {
        _requireFork();
        MockERC20 clBond = new MockERC20("Gyld Bond CL2", "GBCL2", 18);
        MockAggregator clFeed = new MockAggregator(8);
        clFeed.setLatestAnswer(int256(NAV_USD_AT_ENTRY));

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(clBond);
        cfg.navFeed = address(clFeed);
        cfg.navFeedKind = registry.FEED_KIND_CHAINLINK();
        cfg.cashToken = VB_USDC;
        // F1: a direction with a zero tolerance is reported as unconfigured, not defaulted.
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        // Published outside the LEAF's one-day bound, inside the registry's seven-day one.
        clFeed.setUpdatedAt(block.timestamp - LEAF_PUB_AGE - 1);

        bytes memory guardLeaf =
            abi.encodePacked(bytes32(0), bytes20(address(clBond)), bytes20(VB_USDC), LEAF_OBS_AGE, LEAF_PUB_AGE);
        bytes memory buyLeaf = _tradeData(
            keccak256("cl-stale"), VB_USDC, address(clBond), 500e6, 500e18, 500e18, block.timestamp + 1 hours
        );
        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(buyHook);
        bytes[] memory data = new bytes[](2);
        data[0] = guardLeaf;
        data[1] = buyLeaf;

        instance.expect4337Revert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );
        assertEq(clBond.balanceOf(strategy), 0, "nothing bought");
    }

    /// @dev An expired quote cannot execute on Katana either, and nothing partial is left behind.
    function test_E2E_ExpiredQuoteCannotExecute() public {
        _requireFork();
        uint256 cashBefore = IERC20(VB_USDC).balanceOf(strategy);
        instance.expect4337Revert(ApproveAndTradeGyldBondHook.QUOTE_EXPIRED.selector);
        executeOp(
            _op(
                address(buyHook),
                _tradeData(
                    keccak256("katana-expired"), VB_USDC, address(bond), 1000e6, 1000e18, 1000e18, block.timestamp - 1
                )
            )
        );

        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore, "no real cash moved");
        assertEq(bond.balanceOf(strategy), 0);
        assertEq(IERC20(VB_USDC).allowance(strategy, address(settlement)), 0);
    }

    /// @dev A stale NAV cannot appear fresh. The leaf's one-day publication bound refuses a NAV the registry's
    ///      seven-day bound would have tolerated.
    function test_E2E_StaleNavCannotAppearFresh() public {
        _requireFork();
        navFeed.setNav(address(bond), NAV_USD_AT_ENTRY, block.timestamp - 3 days, block.timestamp - 3 days);
        uint256 cashBefore = IERC20(VB_USDC).balanceOf(strategy);

        instance.expect4337Revert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
        executeOp(
            _op(
                address(buyHook),
                _tradeData(
                    keccak256("katana-stale"),
                    VB_USDC,
                    address(bond),
                    1000e6,
                    1000e18,
                    1000e18,
                    block.timestamp + 1 hours
                )
            )
        );

        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore, "the guard stopped it before any approval");
    }

    /// @dev The incident switch works the same on a live chain: new NAV-sensitive action stops at once, while
    ///      the holding stays visible.
    function test_E2E_SuspensionStopsTradesButNotVisibility() public {
        _requireFork();
        executeOp(
            _op(
                address(buyHook),
                _tradeData(
                    keccak256("katana-buy-2"), VB_USDC, address(bond), 500e6, 500e18, 500e18, block.timestamp + 1 hours
                )
            )
        );
        assertEq(bond.balanceOf(strategy), 500e18);

        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        assertEq(oracle.getBalanceOfOwner(address(bond), strategy), 500e18, "holdings stay visible");
        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), strategy);

        instance.expect4337Revert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        executeOp(
            _op(
                address(buyHook),
                _tradeData(
                    keccak256("katana-buy-3"), VB_USDC, address(bond), 500e6, 500e18, 500e18, block.timestamp + 1 hours
                )
            )
        );
    }

    /// @dev A venue that pulls more real vbUSDC than the leaf approved cannot: the allowance is the bound, and
    ///      real token bytecode enforces it exactly as `MockERC20` does.
    function test_E2E_VenueCannotOverPullRealVbUsdc() public {
        _requireFork();
        settlement.setOverPullBps(1);
        uint256 cashBefore = IERC20(VB_USDC).balanceOf(strategy);

        instance.expect4337Revert();
        executeOp(
            _op(
                address(buyHook),
                _tradeData(
                    keccak256("katana-overpull"),
                    VB_USDC,
                    address(bond),
                    1000e6,
                    1000e18,
                    1000e18,
                    block.timestamp + 1 hours
                )
            )
        );

        assertEq(IERC20(VB_USDC).balanceOf(strategy), cashBefore, "nothing spent");
        assertEq(bond.balanceOf(strategy), 0);
    }
}
