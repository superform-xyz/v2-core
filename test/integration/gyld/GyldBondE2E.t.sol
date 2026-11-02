// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { ApproveAndTradeGyldBondHook } from "../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";
import { GyldTradeGuardHook } from "../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { GyldBondRegistry } from "../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../src/interfaces/ISuperHookSwap.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";
import { MockGyldSettlement } from "../../mocks/gyld/MockGyldSettlement.sol";

/// @title GyldBondE2EBase
/// @notice Shared end-to-end setup on the ONLY instrument configuration that can actually ship.
/// @dev WHY THIS EXISTS ALONGSIDE `GyldBondFlowIntegration`. That suite registers its instrument with
///      `FEED_KIND_GYLD_NATIVE` and `requiresObservationTime = true`. Research into Gyld's real stack
///      (2026-11-02) found their NAV oracle is `KaleidoscopeNAVFeed`, described as Chainlink
///      `AggregatorV3Interface`-compatible with 8 decimals — so the native branch has no feed to serve it and
///      that configuration is unreachable in production. Everything here therefore runs on
///      `FEED_KIND_CHAINLINK` against an 8-decimal aggregator, which is the configuration a real instrument
///      must use. See the session log, finding N1/N2/N8.
/// @dev Also covers the executor-level gaps the test audit identified: both trade instances coexisting in one
///      batch, state flipping mid-batch so the guard's `_postExecute` genuinely observes something its own
///      `build()` could not, the previous-hook flag surfacing through a real chain, and the per-transaction
///      cap resetting across transaction boundaries.
abstract contract GyldBondE2EBase is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    GyldTradeGuardHook internal guard;
    ApproveAndTradeGyldBondHook internal buyHook; // cash in, cash-denominated cap
    ApproveAndTradeGyldBondHook internal sellHook; // bond in, bond-denominated cap
    MockGyldSettlement internal settlement;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals, standing in for vbUSDC
    MockAggregator internal navFeed; // 8 decimals, Chainlink-shaped: THE realistic feed

    AccountInstance internal instance;
    address internal strategy;
    ISuperExecutor internal superExecutor;

    address internal admin = address(0xA11CE);

    /// @dev One bond is worth 1.00 cash at entry. Chainlink-shaped feeds carry only a publication clock.
    int256 internal constant NAV_AT_ENTRY = 1e8;
    int256 internal constant NAV_AFTER_COUPON = 1.02e8;

    uint256 internal constant CASH_CAP = 500_000e6;
    uint256 internal constant BOND_CAP = 500_000e18;
    uint256 internal constant LEAF_PUB_AGE = 1 days;
    /// @dev A Chainlink-shaped feed reports no observation time, so the observation bound is inert. It is
    ///      still committed in the leaf, which is finding C7.
    uint256 internal constant LEAF_OBS_AGE = 2 days;

    receive() external payable { }

    function setUp() public virtual {
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond 2030", "GB30", 18);
        cash = new MockERC20("Vault Bridge USDC", "vbUSDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(NAV_AT_ENTRY);

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(new SuperLedgerConfiguration()), address(registry));
        settlement = new MockGyldSettlement();

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = registry.FEED_KIND_CHAINLINK(); // the shippable branch
        cfg.cashToken = address(cash);
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        guard = new GyldTradeGuardHook(address(oracle));
        buyHook = new ApproveAndTradeGyldBondHook(address(settlement), CASH_CAP);
        sellHook = new ApproveAndTradeGyldBondHook(address(settlement), BOND_CAP);

        instance = makeAccountInstance(keccak256("gyld-e2e-strategy"));
        strategy = instance.account;
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        cash.mint(strategy, 10_000e6);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _guardLeaf() internal view returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(address(bond)), bytes20(address(cash)), LEAF_OBS_AGE, LEAF_PUB_AGE);
    }

    function _tradeLeaf(
        bytes32 quoteId,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount
    )
        internal
        view
        returns (bytes memory)
    {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory venue =
            settlement.encodeFill(quoteId, strategy, inputToken, outputToken, inputAmount, outputAmount, deadline);
        bytes memory payload = abi.encode(deadline, venue);
        return bytes.concat(
            abi.encodePacked(
                bytes32(0),
                bytes20(address(0)),
                bytes20(inputToken),
                bytes20(outputToken),
                inputAmount,
                outputAmount, // outputQuote: this hook constrains it, unlike most peers
                outputAmount, // outputMin
                false,
                payload.length
            ),
            payload
        );
    }

    function _op(address[] memory hooks, bytes[] memory data) internal returns (UserOpData memory) {
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
        );
    }

    function _guardedBuy(uint256 cashIn, uint256 bondsOut, bytes32 quoteId) internal returns (UserOpData memory) {
        address[] memory hooks = new address[](2);
        hooks[0] = address(guard);
        hooks[1] = address(buyHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardLeaf();
        data[1] = _tradeLeaf(quoteId, address(cash), address(bond), cashIn, bondsOut);
        return _op(hooks, data);
    }
}

/// @title GyldBondE2E
/// @notice End-to-end tests through a real ERC-7579 smart account and `SuperExecutor` over ERC-4337.
contract GyldBondE2E is GyldBondE2EBase {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
          THE FIRST PROOF, ON THE CONFIGURATION THAT CAN SHIP
    //////////////////////////////////////////////////////////////*/

    /// @dev Buy, hold through a NAV update, sell back, all on a Chainlink-shaped feed. The existing
    ///      integration and fork suites prove this on the Gyld-native branch, which Gyld has not built.
    function test_E2E_ChainlinkConfiguration_BuyHoldSellBack() public {
        uint256 cashIn = 1000e6;
        uint256 bondsOut = 1000e18;

        executeOp(_guardedBuy(cashIn, bondsOut, keccak256("buy")));
        assertEq(bond.balanceOf(strategy), bondsOut, "bonds held");
        assertEq(cash.balanceOf(strategy), 10_000e6 - cashIn, "cash spent");
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), strategy), 1000e6, "valued at entry NAV");
        assertEq(oracle.previewNav(address(bond)).observedAt, 0, "a Chainlink feed reports no observation clock");

        // Hold through a coupon accrual. The publication clock is the only one that moves.
        vm.warp(block.timestamp + 2 days);
        navFeed.setLatestAnswer(NAV_AFTER_COUPON);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), strategy), 1020e6, "coupon accrued");

        // Sell back through the bond-side instance.
        uint256 cashBack = 1020e6;
        cash.mint(address(settlement), cashBack);
        address[] memory hooks = new address[](2);
        hooks[0] = address(guard);
        hooks[1] = address(sellHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardLeaf();
        data[1] = _tradeLeaf(keccak256("sell"), address(bond), address(cash), bondsOut, cashBack);
        executeOp(_op(hooks, data));

        assertEq(bond.balanceOf(strategy), 0, "bonds sold");
        assertGt(cash.balanceOf(strategy), 10_000e6, "the round trip earned the coupon");
        assertEq(cash.allowance(strategy, address(settlement)), 0, "no standing allowance");
        assertEq(bond.allowance(strategy, address(settlement)), 0, "no standing allowance");
    }

    /*//////////////////////////////////////////////////////////////
            BOTH TRADE INSTANCES IN ONE BATCH, ONE USEROP
    //////////////////////////////////////////////////////////////*/

    /// @dev THE GAP THE TEST AUDIT NAMED. The deploy wiring mandates two instances per pair, one per
    ///      direction, each with a cap denominated in its own input token. Nothing had ever executed both in
    ///      a single batch. This proves they compose: four hooks, one UserOp, each instance's own
    ///      per-transaction accumulator, and a net position of zero at the end.
    function test_E2E_OneBatch_BuyThenSell_BothInstancesCoexist() public {
        uint256 cashIn = 1000e6;
        uint256 bondsRound = 1000e18;
        uint256 cashBack = 1000e6;
        cash.mint(address(settlement), cashBack);

        address[] memory hooks = new address[](4);
        hooks[0] = address(guard);
        hooks[1] = address(buyHook);
        hooks[2] = address(guard);
        hooks[3] = address(sellHook);
        bytes[] memory data = new bytes[](4);
        data[0] = _guardLeaf();
        data[1] = _tradeLeaf(keccak256("rt-buy"), address(cash), address(bond), cashIn, bondsRound);
        data[2] = _guardLeaf();
        data[3] = _tradeLeaf(keccak256("rt-sell"), address(bond), address(cash), bondsRound, cashBack);

        executeOp(_op(hooks, data));

        assertEq(bond.balanceOf(strategy), 0, "bought and sold within one batch");
        assertEq(cash.balanceOf(strategy), 10_000e6, "flat on cash at a flat NAV");
        // Each instance accumulated only ITS OWN leg, in its own token's units.
        assertEq(buyHook.txSpent(strategy), cashIn, "the buy instance counted the cash leg");
        assertEq(sellHook.txSpent(strategy), bondsRound, "the sell instance counted the bond leg");
    }

    /// @dev And the two accumulators are genuinely independent: the bond leg's 1e21 does not exhaust the
    ///      cash leg's 5e11 cap, which is the whole reason there are two instances.
    function test_E2E_OneBatch_TheTwoCapsDoNotInterfere() public {
        cash.mint(address(settlement), 1000e6);
        address[] memory hooks = new address[](4);
        hooks[0] = address(guard);
        hooks[1] = address(buyHook);
        hooks[2] = address(guard);
        hooks[3] = address(sellHook);
        bytes[] memory data = new bytes[](4);
        data[0] = _guardLeaf();
        data[1] = _tradeLeaf(keccak256("i-buy"), address(cash), address(bond), 1000e6, 1000e18);
        data[2] = _guardLeaf();
        data[3] = _tradeLeaf(keccak256("i-sell"), address(bond), address(cash), 1000e18, 1000e6);

        executeOp(_op(hooks, data));
        assertGt(sellHook.txSpent(strategy), buyHook.MAX_INPUT_AMOUNT(), "the bond leg exceeds the CASH cap");
        assertLt(buyHook.txSpent(strategy), buyHook.MAX_INPUT_AMOUNT(), "yet the cash leg is well inside its own");
    }

    /*//////////////////////////////////////////////////////////////
        "CHECKED TWICE" — STATE THAT CHANGES DURING THE BATCH
    //////////////////////////////////////////////////////////////*/

    /// @dev THE GUARD'S SECOND HEADLINE CLAIM, finally exercised at the executor level. Its NatSpec says it
    ///      is checked once at `build()` and once authoritatively in `_postExecute` from inside the batch.
    ///      Every prior test flipped the registry BEFORE the UserOp, so the guard would have refused at build
    ///      whatever its position, and `_postExecute` proved nothing. Here a `MockHook` positioned between
    ///      the guard's legs SUSPENDS the instrument during execution, so `build()` saw a healthy instrument
    ///      and only the post-execute check can catch it.
    function test_E2E_SuspensionLandingMidBatch_IsCaughtByPostExecute() public {
        // The account needs the manager role so its own batch can flip the switch.
        bytes32 managerRole = registry.INSTRUMENT_MANAGER_ROLE();
        vm.prank(admin);
        registry.grantRole(managerRole, strategy);

        MockHook flipper = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(cash));
        Execution[] memory injected = new Execution[](1);
        injected[0] = Execution({
            target: address(registry),
            value: 0,
            callData: abi.encodeCall(GyldBondRegistry.setNavSuspended, (address(bond), true))
        });
        flipper.setExecutionBytes(abi.encode(injected));

        // The guard is healthy at build time: prove it, so the refusal below can only come from postExecute.
        assertEq(guard.previewTradable(_guardLeaf(), strategy), 0, "healthy before the batch runs");

        address[] memory hooks = new address[](2);
        hooks[0] = address(guard);
        hooks[1] = address(flipper);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardLeaf();
        data[1] = "";

        instance.expect4337Revert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        executeOp(_op(hooks, data));

        // The guard refused, so no trade settled. Deliberately NOT asserting whether the injected flip was
        // rolled back: that depends on how ModuleKit surfaces a failed UserOp, which is not what this test
        // is about.
        assertEq(bond.balanceOf(strategy), 0, "no trade settled behind the refusal");
        assertEq(cash.balanceOf(strategy), 10_000e6, "and no cash moved");
    }

    /// @dev The same mechanism for a price that goes stale mid-batch rather than a suspension, via the
    ///      registry's un-timelocked staleness bounds. Tightening them to one second makes the live feed
    ///      stale from inside the batch.
    function test_E2E_StalenessTightenedMidBatch_IsCaughtByPostExecute() public {
        bytes32 managerRole = registry.INSTRUMENT_MANAGER_ROLE();
        vm.prank(admin);
        registry.grantRole(managerRole, strategy);
        // Age the feed slightly so a one-second bound makes it stale, without being stale at build time.
        navFeed.setUpdatedAt(block.timestamp - 10 minutes);
        assertEq(guard.previewTradable(_guardLeaf(), strategy), 0, "fresh under the leaf's one-day bound");

        MockHook flipper = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(cash));
        Execution[] memory injected = new Execution[](1);
        injected[0] = Execution({
            target: address(registry),
            value: 0,
            callData: abi.encodeCall(GyldBondRegistry.setStalenessBounds, (address(bond), 1, 1))
        });
        flipper.setExecutionBytes(abi.encode(injected));

        address[] memory hooks = new address[](2);
        hooks[0] = address(guard);
        hooks[1] = address(flipper);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardLeaf();
        data[1] = "";

        instance.expect4337Revert(GyldTradeGuardHook.NAV_PUBLICATION_STALE.selector);
        executeOp(_op(hooks, data));
    }

    /*//////////////////////////////////////////////////////////////
              THE PREVIOUS-HOOK FLAG THROUGH A REAL CHAIN
    //////////////////////////////////////////////////////////////*/

    /// @dev Only the direct `build()` rejection was tested. Here the guard precedes the trade in a real
    ///      chain and the trade's leaf sets the flag, so the refusal travels out through the executor.
    /// @dev A `MockHook` is deliberately NOT used as the preceding hook: the executor decodes the previous
    ///      hook's own calldata when piping an amount, and a mock carrying empty data makes that decode
    ///      revert `slice_outOfBounds` before the Gyld hook is ever reached. The guard is a real hook with
    ///      real calldata, so the chain exercises the piping path rather than a mock's hole.
    function test_E2E_UsePrevHookAmount_RefusedThroughTheExecutor() public {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory venue = settlement.encodeFill(
            keccak256("prev"), strategy, address(cash), address(bond), 1000e6, 1000e18, deadline
        );
        bytes memory leafWithFlag = buyHook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: address(cash),
                outputToken: address(bond),
                inputAmount: 1000e6,
                outputQuote: 1000e18,
                outputMin: 1000e18,
                usePrevHookAmount: true
            }),
            abi.encode(deadline, venue)
        );
        assertTrue(buyHook.decodeUsePrevHookAmount(leafWithFlag), "the flag is set in the leaf");

        address[] memory hooks = new address[](2);
        hooks[0] = address(guard);
        hooks[1] = address(buyHook);
        bytes[] memory data = new bytes[](2);
        data[0] = _guardLeaf();
        data[1] = leafWithFlag;

        instance.expect4337Revert(ApproveAndTradeGyldBondHook.USE_PREV_HOOK_NOT_SUPPORTED.selector);
        executeOp(_op(hooks, data));
        assertEq(cash.balanceOf(strategy), 10_000e6, "nothing moved");
    }

    /*//////////////////////////////////////////////////////////////
              THE CAP ACCUMULATES WITHIN ONE TRANSACTION
    //////////////////////////////////////////////////////////////*/

    /// @dev Two buy legs in ONE batch against a cap that fits only one. The second must be refused at its
    ///      own `preExecute`, before any approval, and atomicity must undo the first.
    function test_E2E_CapAccumulatesWithinOneBatch() public {
        ApproveAndTradeGyldBondHook capped = new ApproveAndTradeGyldBondHook(address(settlement), 1500e6);
        settlement.setAllowReplay(true); // a venue that does not enforce single-use ids

        bytes memory leaf = _tradeLeaf(keccak256("rep"), address(cash), address(bond), 1000e6, 1000e18);
        address[] memory hooks = new address[](2);
        hooks[0] = address(capped);
        hooks[1] = address(capped);
        bytes[] memory data = new bytes[](2);
        data[0] = leaf;
        data[1] = leaf;

        instance.expect4337Revert(ApproveAndTradeGyldBondHook.INPUT_EXCEEDS_CAP.selector);
        executeOp(_op(hooks, data));
        assertEq(cash.balanceOf(strategy), 10_000e6, "the batch is atomic: the first leg rolled back");
        assertEq(bond.balanceOf(strategy), 0);
    }
}

/// @title GyldBondCapResetE2E
/// @notice The per-transaction cap's RESET across a transaction boundary, which needs two transactions.
/// @dev `txSpent` lives in transient storage, so it clears at every transaction boundary. That is what makes
///      `MAX_INPUT_AMOUNT` a per-transaction bound rather than a lifetime one, and it is the hook's own
///      headline claim. It cannot be shown inside a single test body, because `setUp` and the body are
///      separate transactions and everything within one body is not. Same structure as
///      `BinanceHookTxCapResetE2E`: `setUp` performs transaction one, the body performs transaction two.
contract GyldBondCapResetE2E is GyldBondE2EBase {
    using ModuleKitHelpers for *;

    ApproveAndTradeGyldBondHook internal capped;

    function setUp() public override {
        super.setUp();
        // A cap that fits exactly one leg, and a venue that will honour a replayed quote id, so only the cap
        // can stop the second attempt.
        capped = new ApproveAndTradeGyldBondHook(address(settlement), 1000e6);
        settlement.setAllowReplay(true);

        // TRANSACTION ONE: consume the entire cap.
        address[] memory hooks = new address[](1);
        hooks[0] = address(capped);
        bytes[] memory data = new bytes[](1);
        data[0] = _tradeLeaf(keccak256("tx1"), address(cash), address(bond), 1000e6, 1000e18);
        executeOp(_op(hooks, data));
    }

    /// @dev TRANSACTION TWO. The accumulator must read zero again, and an identical leg must succeed.
    function test_E2E_CapResetsAtTheTransactionBoundary() public {
        assertEq(capped.txSpent(strategy), 0, "the accumulator cleared with the transaction");
        assertEq(bond.balanceOf(strategy), 1000e18, "transaction one did settle");

        address[] memory hooks = new address[](1);
        hooks[0] = address(capped);
        bytes[] memory data = new bytes[](1);
        data[0] = _tradeLeaf(keccak256("tx2"), address(cash), address(bond), 1000e6, 1000e18);
        executeOp(_op(hooks, data));

        assertEq(bond.balanceOf(strategy), 2000e18, "a second full-cap leg settles in a new transaction");
        assertEq(capped.txSpent(strategy), 1000e6, "and the accumulator counted only THIS transaction");
    }

    /// @dev The consequence, stated plainly: the cap bounds loss PER TRANSACTION and does not bound a
    ///      sequence of them. Two transactions spend two caps.
    function test_E2E_CapDoesNotBoundASequenceOfTransactions() public {
        uint256 beforeBalance = cash.balanceOf(strategy);
        address[] memory hooks = new address[](1);
        hooks[0] = address(capped);
        bytes[] memory data = new bytes[](1);
        data[0] = _tradeLeaf(keccak256("tx2b"), address(cash), address(bond), 1000e6, 1000e18);
        executeOp(_op(hooks, data));

        assertEq(cash.balanceOf(strategy), beforeBalance - 1000e6, "a full cap spent again");
        assertEq(bond.balanceOf(strategy), 2000e18, "two caps' worth of bonds across two transactions");
    }
}
