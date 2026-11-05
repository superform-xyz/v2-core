// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
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
import { IGyldTradePolicy } from "../../../src/interfaces/accounting/IGyldTradePolicy.sol";
import { GyldTradePolicy } from "../../../src/accounting/oracles/GyldTradePolicy.sol";
import { MockSuperVaultStrategyState } from "../../../test/mocks/gyld/MockSuperVaultStrategyState.sol";
import {
    MockGyldSettlementWithExtraPowers,
    MockReentrantGyldSettlement
} from "../../mocks/gyld/GyldAdversarialMocks.sol";

/// @title GyldBondFlowIntegration
/// @notice The brief's "first proof", driven through a real ERC-7579 smart account and `SuperExecutor` over an
///         ERC-4337 UserOp: buy one bond with cash, hold it through a NAV update, and sell it back to cash.
/// @dev What this suite adds over the unit suites: the guard and the trade hook run as a CHAIN inside one
///      account batch, so hook-to-hook piping, the executor's pre/post gating and whole-batch atomicity are
///      exercised rather than each hook in isolation. Gyld is deployed nowhere, so the venue and the NAV feed
///      are mocks; the account, the executor and the ERC-4337 path are real.
contract GyldBondFlowIntegration is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    ApproveAndTradeGyldBondHook internal tradeHook;
    GyldTradeGuardHook internal guardHook;
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    MockGyldSettlement internal settlement;
    MockGyldNavFeed internal navFeed;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals

    AccountInstance internal instance;
    address internal strategy; // the smart account IS the trading account, payer and recipient
    ISuperExecutor internal superExecutor;

    address internal admin = address(0xA11CE);

    /// @dev Caps are raw input-token units, so each direction needs its own instance. See the unit suite's
    ///      `test_Build_Sell_CapIsDenominatedInRawInputUnitsNotValue`.
    uint256 internal constant CASH_CAP = 1_000_000e6;
    uint256 internal constant BOND_CAP = 1_000_000e18;

    uint256 internal constant NAV_AT_ENTRY = 1.0e8; // one bond is worth one cash unit
    uint256 internal constant NAV_AFTER_COUPON = 1.02e8; // coupon accrual lifts complete NAV by 2%

    uint256 internal constant LEAF_OBS_AGE = 2 days;
    uint256 internal constant LEAF_PUB_AGE = 1 days;
    GyldTradePolicy internal tradePolicy;
    MockSuperVaultStrategyState internal aggregator;


    function setUp() public {
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond 2030", "GB30", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockGyldNavFeed(8);
        navFeed.setFreshNav(address(bond), NAV_AT_ENTRY);

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(new SuperLedgerConfiguration()), address(registry));
        aggregator = new MockSuperVaultStrategyState();
        // Real policy, real aggregator shape: AGGREGATOR == 0 would exercise a
        // configuration that cannot ship, since a paused strategy could still trade.
        tradePolicy =
            new GyldTradePolicy(address(registry), address(oracle), address(aggregator));
        // The policy reads this from the registry and refuses to trade while it is zero, so a
        // shipping-shaped fixture has to set it.
        vm.prank(admin);
        registry.setMaxPpsAge(1 days);
        settlement = new MockGyldSettlement();

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        cfg.cashToken = address(cash);
        // F1: a direction with a zero tolerance is reported as unconfigured, not defaulted.
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.requiresObservationTime = true;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        guardHook = new GyldTradeGuardHook(address(oracle));
        tradeHook = new ApproveAndTradeGyldBondHook(address(settlement), CASH_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);

        instance = makeAccountInstance(keccak256("gyld-strategy"));
        strategy = instance.account;
        // The policy fails closed for an address the aggregator does not know, so the
        // strategy has to exist there before any trade is attempted.
        aggregator.register(strategy);
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        cash.mint(strategy, 10_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _guardData() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(address(bond)), bytes20(address(cash)), LEAF_OBS_AGE, LEAF_PUB_AGE);
    }

    function _layer1(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputQuote,
        uint256 outputMin,
        uint256 payloadLength
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0),
            bytes20(address(0)),
            bytes20(inputToken),
            bytes20(outputToken),
            inputAmount,
            outputQuote,
            outputMin,
            false,
            payloadLength
        );
    }

    /// @dev A venue-signed quote, as the hook sees it: an opaque blob plus the caller's copy of the deadline.
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
        return
            bytes.concat(_layer1(inputToken, outputToken, inputAmount, outputQuote, outputMin, payload.length), payload);
    }

    /// @dev A guarded leg: the guard runs FIRST, so a bad price stops the batch before any approval.
    function _guardedOp(bytes memory tradeData) internal returns (UserOpData memory) {
        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(tradeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardData();
        data[1] = tradeData;
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
        );
    }

    function _buyOp(uint256 cashIn, uint256 bondOut, bytes32 quoteId) internal returns (UserOpData memory) {
        return _guardedOp(
            _tradeData(quoteId, address(cash), address(bond), cashIn, bondOut, bondOut, block.timestamp + 1 hours)
        );
    }

    /*//////////////////////////////////////////////////////////////
                             THE FIRST PROOF
    //////////////////////////////////////////////////////////////*/

    /// @dev Buy one bond, hold it through a NAV update, sell it back to cash. The whole brief in one test.
    function test_FirstProof_BuyHoldThroughNavUpdateSellBack() public {
        uint256 cashIn = 1000e6;
        uint256 bondsOut = 1000e18; // NAV 1.00: 1000 cash buys 1000 bonds

        // ---- BUY ----
        executeOp(_buyOp(cashIn, bondsOut, keccak256("buy-1")));

        assertEq(bond.balanceOf(strategy), bondsOut, "bonds held");
        assertEq(cash.balanceOf(strategy), 10_000e6 - cashIn, "cash spent");
        assertEq(cash.allowance(strategy, address(settlement)), 0, "no standing allowance");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), strategy), 1000e6, "valued at entry NAV");

        // ---- HOLD through a coupon accrual ----
        vm.warp(block.timestamp + 30 days);
        aggregator.setLastUpdate(strategy, block.timestamp);
        navFeed.setFreshNav(address(bond), NAV_AFTER_COUPON);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), strategy), 1020e6, "complete NAV includes coupon accrual");
        assertEq(oracle.getPricePerShare(address(bond)), 1.02e6);

        // ---- SELL back to cash ----
        // A second instance, because the cap is denominated in the input token's raw units.
        ApproveAndTradeGyldBondHook sellHook = new ApproveAndTradeGyldBondHook(address(settlement), BOND_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.SELL);
        uint256 cashBack = 1020e6;
        bytes memory sellData = _tradeData(
            keccak256("sell-1"), address(bond), address(cash), bondsOut, cashBack, cashBack, block.timestamp + 1 hours
        );
        cash.mint(address(settlement), cashBack); // the venue is the counterparty on the cash leg

        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(sellHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardData();
        data[1] = sellData;
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );

        assertEq(bond.balanceOf(strategy), 0, "bonds sold");
        assertEq(cash.balanceOf(strategy), 10_000e6 - cashIn + cashBack, "cash back, coupon included");
        assertGt(cash.balanceOf(strategy), 10_000e6, "the round trip earned the coupon");
        assertEq(bond.allowance(strategy, address(settlement)), 0, "no standing allowance");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), strategy), 0, "nothing left to value");
    }

    /// @dev The strategy is the payer and the recipient throughout. The hook holds nothing at any point and
    ///      the venue's quote names the account as taker, which is requirement R2.
    function test_StrategyIsThePayerAndRecipient() public {
        executeOp(_buyOp(500e6, 500e18, keccak256("buy-identity")));

        assertEq(bond.balanceOf(address(tradeHook)), 0, "the hook never holds the bond");
        assertEq(cash.balanceOf(address(tradeHook)), 0, "the hook never holds the cash");
        assertEq(cash.allowance(strategy, address(tradeHook)), 0, "the hook never takes an approval for itself");
        assertEq(bond.balanceOf(strategy), 500e18);
    }

    /*//////////////////////////////////////////////////////////////
                      WHAT MUST NOT BE ABLE TO HAPPEN
    //////////////////////////////////////////////////////////////*/

    /// @dev An expired quote cannot execute, and the failure takes the whole batch with it.
    function test_ExpiredQuote_CannotExecute() public {
        bytes memory tradeData = _tradeData(
            keccak256("expired"), address(cash), address(bond), 1000e6, 1000e18, 1000e18, block.timestamp - 1
        );
        instance.expect4337Revert(ApproveAndTradeGyldBondHook.QUOTE_EXPIRED.selector);
        executeOp(_guardedOp(tradeData));

        assertEq(bond.balanceOf(strategy), 0, "no bonds");
        assertEq(cash.balanceOf(strategy), 10_000e6, "no cash moved");
        assertEq(cash.allowance(strategy, address(settlement)), 0, "no approval survived the failure");
    }

    /// @dev A stale price cannot appear fresh. The guard refuses before the trade hook is ever reached, so no
    ///      approval is granted and nothing moves.
    function test_StalePrice_BlocksTheWholeBatch() public {
        // Published a week ago: inside the registry's 7-day bound, outside this leaf's one-day bound.
        navFeed.setNav(address(bond), NAV_AT_ENTRY, block.timestamp - 6 days, block.timestamp - 6 days);

        instance.expect4337Revert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
        executeOp(_buyOp(1000e6, 1000e18, keccak256("stale")));

        assertEq(bond.balanceOf(strategy), 0);
        assertEq(cash.balanceOf(strategy), 10_000e6);
        assertEq(cash.allowance(strategy, address(settlement)), 0);
    }

    /// @dev A fresh publication of a stale valuation is the case both clocks exist for.
    function test_FreshPublicationOfStaleObservation_BlocksTheWholeBatch() public {
        navFeed.setNav(address(bond), NAV_AT_ENTRY, block.timestamp - 5 days, block.timestamp);
        instance.expect4337Revert(GyldTradeGuardHook.NAV_OBSERVATION_STALE.selector);
        executeOp(_buyOp(1000e6, 1000e18, keccak256("stale-obs")));
        assertEq(cash.balanceOf(strategy), 10_000e6, "nothing moved");
    }

    /// @dev The incident switch stops new NAV-sensitive action immediately, with no timelock.
    function test_SuspendedInstrument_BlocksNewTrades() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        instance.expect4337Revert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        executeOp(_buyOp(1000e6, 1000e18, keccak256("suspended")));
        assertEq(cash.balanceOf(strategy), 10_000e6);
    }

    /// @dev AND THE OTHER HALF OF THE REQUIREMENT: suspension preserves VISIBLE holdings. A position bought
    ///      before the incident is still readable afterwards, even though it can no longer be valued.
    function test_SuspensionPreservesVisibleHoldings() public {
        executeOp(_buyOp(1000e6, 1000e18, keccak256("buy-then-suspend")));
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        assertEq(oracle.getBalanceOfOwner(address(bond), strategy), 1000e18, "holdings stay visible");
        assertEq(oracle.decimals(address(bond)), 18);
        assertTrue(oracle.previewNav(address(bond)).suspended, "and the reason is reportable");

        vm.expectRevert(GyldBondYieldSourceOracle.NAV_SUSPENDED.selector);
        oracle.getTVLByOwnerOfShares(address(bond), strategy);
    }

    /// @dev A deregistered instrument can no longer be traded, which is why suspension is the right tool
    ///      while a position is still open.
    function test_DeregisteredInstrument_CannotBeTraded() public {
        vm.startPrank(admin);
        registry.proposeDeregisterInstrument(address(bond));
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        registry.executeDeregisterInstrument(address(bond));
        vm.stopPrank();
        navFeed.setFreshNav(address(bond), NAV_AT_ENTRY);

        instance.expect4337Revert(GyldTradeGuardHook.INSTRUMENT_NOT_REGISTERED.selector);
        executeOp(_buyOp(1000e6, 1000e18, keccak256("deregistered")));
    }

    /// @dev The per-transaction cap bounds a repeated leaf inside ONE batch, which is the only on-chain bound
    ///      on a compromised manager key, because a SuperVault leaf carries no amount.
    function test_RepeatedLeafInOneBatch_IsCappedAtPreExecute() public {
        ApproveAndTradeGyldBondHook cappedHook = new ApproveAndTradeGyldBondHook(address(settlement), 1500e6, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        settlement.setAllowReplay(true); // a venue that does NOT enforce single-use quote ids

        bytes memory tradeData = _tradeData(
            keccak256("repeat"), address(cash), address(bond), 1000e6, 1000e18, 1000e18, block.timestamp + 1 hours
        );
        address[] memory hooks = new address[](2);
        hooks[0] = address(cappedHook);
        hooks[1] = address(cappedHook);
        bytes[] memory data = new bytes[](2);
        data[0] = tradeData;
        data[1] = tradeData;

        instance.expect4337Revert(ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );
        assertEq(cash.balanceOf(strategy), 10_000e6, "the batch is atomic: the first leg rolled back too");
    }

    /// @dev A venue that takes the cash and delivers nothing, without reverting, fails the batch.
    function test_VenueDeliversNothing_FailsTheBatch() public {
        settlement.setDeliverNothing(true);
        instance.expect4337Revert(ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
        executeOp(_buyOp(1000e6, 1000e18, keccak256("no-delivery")));
        assertEq(cash.balanceOf(strategy), 10_000e6, "nothing spent");
    }

    /// @dev The guard is re-checked from INSIDE the batch, so a price that goes bad between the two legs of a
    ///      chain still stops the trade. Here the guard runs last, after the trade: the executor builds hook N
    ///      only after hook N-1 executed, so the guard sees post-trade state.
    function test_GuardAfterTrade_StillCatchesABadPrice() public {
        bytes memory tradeData = _tradeData(
            keccak256("guard-last"), address(cash), address(bond), 1000e6, 1000e18, 1000e18, block.timestamp + 1 hours
        );
        address[] memory hooks = new address[](2);
        hooks[0] = address(tradeHook);
        hooks[1] = address(guardHook);
        bytes[] memory data = new bytes[](2);
        data[0] = tradeData;
        data[1] = _guardData();

        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        instance.expect4337Revert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );
        assertEq(bond.balanceOf(strategy), 0, "the trade rolled back with the batch");
    }

    /*//////////////////////////////////////////////////////////////
                           ACCOUNTING POSTURE
    //////////////////////////////////////////////////////////////*/

    /// @dev Both hooks are NONACCOUNTING, so the ledger never consults this oracle and a suspended instrument
    ///      cannot brick accounting. Proven by selling with the instrument suspended for VALUATION: the
    ///      LEDGER needs no NAV for a NONACCOUNTING hook.
    /// @dev F1: the TRADE does now need a usable number, which is a deliberate change. A suspended
    ///      instrument with no recovery mark is refused (`NO_EXIT_MARK`), so this test publishes the
    ///      timelocked mark first — the T2 credit-event exit path — and the ledger assertion below is
    ///      unaffected either way. `test_Fixed_F1_SellOfSuspendedBondWithNoMarkIsRefused` covers the refusal.
    function test_NonAccounting_LedgerNeverTouchesTheOracle() public {
        executeOp(_buyOp(1000e6, 1000e18, keccak256("buy-na")));

        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        // Governance publishes the exit mark through the normal two-day delay.
        vm.prank(admin);
        registry.proposeRecoveryNav(address(bond), 1e6);
        vm.warp(block.timestamp + registry.DEREGISTER_DELAY());
        vm.prank(admin);
        registry.executeRecoveryNav(address(bond));
        aggregator.setLastUpdate(strategy, block.timestamp);

        ApproveAndTradeGyldBondHook sellHook = new ApproveAndTradeGyldBondHook(address(settlement), BOND_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.SELL);
        cash.mint(address(settlement), 1000e6);
        bytes memory sellData = _tradeData(
            keccak256("sell-na"), address(bond), address(cash), 1000e18, 1000e6, 1000e6, block.timestamp + 1 hours
        );
        address[] memory hooks = new address[](1);
        hooks[0] = address(sellHook);
        bytes[] memory data = new bytes[](1);
        data[0] = sellData;

        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );
        assertEq(bond.balanceOf(strategy), 0, "an unguarded sell of a suspended instrument still settles");
        assertEq(cash.balanceOf(strategy), 10_000e6, "and the ledger raised no fee against it");
    }

    /// @dev Fees are bypassed: the ledger-facing read equals the plain one, whatever the caller passes.
    function test_NonAccounting_FeesAreBypassed() public {
        executeOp(_buyOp(1000e6, 1000e18, keccak256("buy-fees")));
        assertEq(
            oracle.getAssetOutputWithFees(bytes32("ledger"), address(bond), address(cash), strategy, 1000e18),
            oracle.getAssetOutput(address(bond), address(cash), 1000e18)
        );
    }

    /*//////////////////////////////////////////////////////////////
                  FINDINGS, CONTAINED (OR NOT) BY THE BATCH
    //////////////////////////////////////////////////////////////*/

    /// @dev Companion to `GyldHooksAdversarialTest.test_Finding_OpaqueCalldataReachesAnyFunctionOnThePinnedVenue`.
    ///      A leaf whose opaque payload calls something other than a fill reaches the venue, but the batch is
    ///      atomic, so the executor rolls the whole thing back when `postExecute` refuses. This is the
    ///      containment the finding's severity depends on, so it is pinned at the executor level too.
    function test_Finding_OpaqueCalldataSweep_IsContainedByBatchAtomicity() public {
        MockGyldSettlementWithExtraPowers venue = new MockGyldSettlementWithExtraPowers();
        ApproveAndTradeGyldBondHook powerHook = new ApproveAndTradeGyldBondHook(address(venue), CASH_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        address thief = address(0xBAD);

        bytes memory hostile = venue.encodeSweep(address(cash), thief, 1000e6);
        bytes memory payload = abi.encode(block.timestamp + 1 hours, hostile);
        bytes memory tradeData =
            bytes.concat(_layer1(address(cash), address(bond), 1000e6, 1000e18, 1000e18, payload.length), payload);

        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(powerHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardData();
        data[1] = tradeData;

        instance.expect4337Revert(ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );

        assertEq(cash.balanceOf(thief), 0, "atomicity returned the swept cash");
        assertEq(cash.balanceOf(strategy), 10_000e6, "the account is whole");
        assertEq(cash.allowance(strategy, address(venue)), 0, "no allowance survived");
    }

    /// @dev F1 FIXED, and this is the headline reproduction. Pairing a guard on a HEALTHY instrument with a
    ///      trade of a SUSPENDED one used to succeed end to end: nothing on-chain tied the two leaves
    ///      together, so the guard was decoration. The trade hook now consults `GyldTradePolicy` from its
    ///      own `_preExecute`, which the executor always runs, so the mismatch is refused on the suspended
    ///      instrument no matter what the accompanying guard leaf says.
    function test_Fixed_F1_MismatchedGuardAndTradeIsRefused() public {
        MockERC20 healthyBond = new MockERC20("Healthy Bond", "HB", 18);
        MockGyldNavFeed healthyFeed = new MockGyldNavFeed(8);
        healthyFeed.setFreshNav(address(healthyBond), NAV_AT_ENTRY);

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(healthyBond);
        cfg.navFeed = address(healthyFeed);
        cfg.navFeedKind = registry.FEED_KIND_GYLD_NATIVE();
        cfg.cashToken = address(cash);
        // F1: a direction with a zero tolerance is reported as unconfigured, not defaulted.
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        cfg.requiresObservationTime = true;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        // The instrument being TRADED is suspended; the one being GUARDED is not.
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        bytes memory guardLeaf = abi.encodePacked(
            bytes32(0), bytes20(address(healthyBond)), bytes20(address(cash)), LEAF_OBS_AGE, LEAF_PUB_AGE
        );
        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(tradeHook);
        bytes[] memory data = new bytes[](2);
        data[0] = guardLeaf;
        data[1] = _tradeData(
            keccak256("mismatched"), address(cash), address(bond), 1000e6, 1000e18, 1000e18, block.timestamp + 1 hours
        );

        // The guard leaf still passes on its own: it is checking the HEALTHY instrument, exactly as the
        // finding described. That is why it was never a gate.
        vm.prank(strategy);
        guardHook.preExecute(address(0), strategy, guardLeaf);

        // And the trade is refused anyway, inside the TRADE hook's own `preExecute` — the execution the
        // executor always runs for this hook, which is what makes it unskippable. Asserted directly rather
        // than through the 4337 frame, where the EntryPoint would wrap the selector in
        // `UserOperationReverted` and hide which check fired.
        vm.prank(strategy);
        vm.expectRevert(GyldTradePolicy.NAV_SUSPENDED.selector);
        tradeHook.preExecute(address(0), strategy, data[1]);

        // Nothing moved: no bonds acquired, no cash spent.
        assertEq(bond.balanceOf(strategy), 0, "the suspended instrument was NOT traded");
        assertEq(cash.balanceOf(strategy), 10_000e6, "and no cash left the account");
    }

    /// @dev Companion to the reentrancy suite: a venue that rotates the account's execution context mid-fill
    ///      makes the hook fail closed, and the executor then rolls the input transfer back.
    function test_Reentrancy_ContextRotation_IsContainedByBatchAtomicity() public {
        MockReentrantGyldSettlement venue = new MockReentrantGyldSettlement();
        ApproveAndTradeGyldBondHook reHook = new ApproveAndTradeGyldBondHook(address(venue), CASH_CAP, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);

        bytes memory venueCalldata = venue.encodeFill(
            keccak256("reenter"), strategy, address(cash), address(bond), 1000e6, 1000e18, block.timestamp + 1 hours
        );
        bytes memory payload = abi.encode(block.timestamp + 1 hours, venueCalldata);
        bytes memory tradeData =
            bytes.concat(_layer1(address(cash), address(bond), 1000e6, 1000e18, 1000e18, payload.length), payload);
        venue.configure(address(reHook), MockReentrantGyldSettlement.Attack.ROTATE_CONTEXT, tradeData);

        address[] memory hooks = new address[](2);
        hooks[0] = address(guardHook);
        hooks[1] = address(reHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardData();
        data[1] = tradeData;

        instance.expect4337Revert(ApproveAndTradeGyldBondHook.SNAPSHOT_NOT_TAKEN.selector);
        executeOp(
            _getExecOps(
                instance,
                superExecutor,
                abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
            )
        );

        assertEq(cash.balanceOf(strategy), 10_000e6, "the input came back");
        assertEq(bond.balanceOf(strategy), 0);
    }

    /// @dev A guard placed FIRST means a bad price costs nothing: the trade hook is never reached, so no
    ///      approval is ever granted. Contrast with the guard-last ordering above, where the trade executes
    ///      and is then rolled back.
    function test_GuardFirst_NeverGrantsAnApprovalOnABadPrice() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        instance.expect4337Revert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        executeOp(_buyOp(1000e6, 1000e18, keccak256("guard-first")));

        assertEq(cash.allowance(strategy, address(settlement)), 0);
        assertEq(cash.balanceOf(strategy), 10_000e6);
    }
}
