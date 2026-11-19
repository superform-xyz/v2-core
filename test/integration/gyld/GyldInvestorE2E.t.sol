// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { GyldInvestorDepositHook } from "../../../src/hooks/gyld/GyldInvestorDepositHook.sol";
import { GyldInvestorRedeemHook } from "../../../src/hooks/gyld/GyldInvestorRedeemHook.sol";
import { GyldInvestorTransferBase } from "../../../src/hooks/gyld/GyldInvestorTransferBase.sol";
import { GyldInTransitRegistry } from "../../../src/accounting/oracles/GyldInTransitRegistry.sol";
import { GyldBondRegistry } from "../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { GyldTradePolicy } from "../../../src/accounting/oracles/GyldTradePolicy.sol";
import { TransferHook } from "../../../src/hooks/tokens/TransferHook.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { SuperExecutor } from "../../../src/executors/SuperExecutor.sol";
import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";

import { Helpers } from "../../utils/Helpers.sol";
import { InternalHelpers } from "../../utils/InternalHelpers.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockAggregator } from "../../mocks/MockAggregator.sol";
import { MockSuperVaultStrategyState } from "../../mocks/gyld/MockSuperVaultStrategyState.sol";

/// @title GyldInvestorE2E
/// @notice The Investor API flow through a real ERC-7579 account and `SuperExecutor` over ERC-4337: cash
///         leaves to Gyld's pinned address and the account's valuation does NOT move; the reconciler settles
///         against a simulated Gyld mint and valuation stays continuous; the mirror for redemption; the
///         stale-transit gate (no valuation cliff); the cap across two leaves in one batch; the one legitimate chain;
/// and the fail-closed successor.
contract GyldInvestorE2E is Helpers, RhinestoneModuleKit, InternalHelpers {
    using ModuleKitHelpers for *;

    GyldBondRegistry internal registry;
    GyldInTransitRegistry internal transit;
    GyldBondYieldSourceOracle internal oracle;
    GyldTradePolicy internal policy;
    MockSuperVaultStrategyState internal aggregator;
    GyldInvestorDepositHook internal depositHook;
    GyldInvestorRedeemHook internal redeemHook;
    TransferHook internal transferHook;

    MockERC20 internal bond; // 18 decimals
    MockERC20 internal cash; // 6 decimals
    MockERC20 internal vaultShares;
    MockAggregator internal navFeed; // 8 decimals, Chainlink-shaped

    AccountInstance internal instance;
    address internal strategy;
    address internal receiver;
    ISuperExecutor internal superExecutor;

    address internal admin = address(0xA11CE);
    address internal reconciler = address(0x4EC0);
    address internal gyldDeposit = address(0xDE90);
    address internal gyldHolding = address(0x401D);
    address internal gyldMinter = address(0x6E1D);

    int256 internal constant NAV_AT_ENTRY = 1e8;
    uint256 internal constant NAV_IN_CASH = 1e6;
    uint256 internal constant AGE = 14 days;
    uint256 internal constant CAP = 5000e6;
    uint256 internal constant START_CASH = 10_000e6;
    uint256 internal constant START_BONDS = 1000e18;

    receive() external payable { }

    function setUp() public {
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond 2030", "GB30", 18);
        cash = new MockERC20("Vault Bridge USDC", "vbUSDC", 6);
        navFeed = new MockAggregator(8);
        navFeed.setLatestAnswer(NAV_AT_ENTRY);

        registry = new GyldBondRegistry(admin);
        transit = new GyldInTransitRegistry(admin, address(registry));
        oracle =
            new GyldBondYieldSourceOracle(address(new SuperLedgerConfiguration()), address(registry), address(transit));
        aggregator = new MockSuperVaultStrategyState();
        policy = new GyldTradePolicy(address(registry), address(oracle), address(aggregator));
        vm.prank(admin);
        registry.setMaxPpsAge(1 days);

        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = address(bond);
        cfg.navFeed = address(navFeed);
        cfg.navFeedKind = registry.FEED_KIND_CHAINLINK();
        cfg.cashToken = address(cash);
        cfg.maxEntryPremiumBps = 200;
        cfg.maxExitDiscountBps = 200;
        cfg.maxObservationAge = 7 days;
        cfg.maxPublicationAge = 7 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);

        vm.startPrank(admin);
        transit.setMaxTransitAge(AGE);
        transit.setMaxCashInTransit(address(bond), CAP);
        transit.setMaxTotalCashInTransit(address(bond), 4 * CAP);
        transit.setValuationOracle(address(oracle));
        transit.grantRole(transit.RECONCILER_ROLE(), reconciler);
        vm.stopPrank();

        depositHook = new GyldInvestorDepositHook(address(transit), address(policy));
        redeemHook = new GyldInvestorRedeemHook(address(transit));
        transferHook = new TransferHook(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));

        instance = makeAccountInstance(keccak256("gyld-investor-e2e-strategy"));
        strategy = instance.account;
        aggregator.register(strategy);
        // destinations are per strategy: this strategy's Gyld pair, set once it exists. Setting them also deploys
        // the strategy's delivery receiver: Gyld's mint wallet and whitelisted withdrawal address.
        vm.prank(admin);
        transit.setDestinations(strategy, gyldDeposit, gyldHolding);
        receiver = address(transit.receiverOf(strategy));
        superExecutor = ISuperExecutor(new SuperExecutor(address(new SuperLedgerConfiguration())));
        instance.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });

        cash.mint(strategy, START_CASH);
        bond.mint(strategy, START_BONDS);
        vaultShares = new MockERC20("Vault Share", "svTEST", 18);
        vaultShares.mint(address(this), 1_000_000e18);
        vm.mockCall(
            strategy,
            abi.encodeWithSignature("getVaultInfo()"),
            abi.encode(address(vaultShares), address(cash), uint8(18))
        );
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _leaf(uint256 amount, bool usePrev) internal view returns (bytes memory) {
        return abi.encodePacked(
            bytes32(0), bytes20(address(0)), bytes20(address(bond)), bytes20(address(cash)), amount, usePrev
        );
    }

    function _op(address[] memory hooks, bytes[] memory data) internal returns (UserOpData memory) {
        return _getExecOps(
            instance,
            superExecutor,
            abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: data }))
        );
    }

    function _single(address hook, bytes memory data) internal returns (UserOpData memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory d = new bytes[](1);
        d[0] = data;
        return _op(hooks, d);
    }

    function _tvl() internal view returns (uint256) {
        return oracle.getTVLByOwnerOfShares(address(bond), strategy);
    }

    function _refreshClocks() internal {
        (, int256 answer,,,) = navFeed.latestRoundData();
        navFeed.setLatestAnswer(answer);
        aggregator.setLastUpdate(strategy, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                               DEPOSIT SIDE
    //////////////////////////////////////////////////////////////*/

    /// @dev The whole point: cash leaves, valuation does not move, and a simulated Gyld mint plus the
    ///      reconciler's settlement keeps it continuous.
    function test_E2E_Deposit_TvlContinuousThroughMint() public {
        uint256 before = _tvl();
        assertEq(before, START_BONDS * NAV_IN_CASH / 1e18, "1000 bonds at 1.00");

        executeOp(_single(address(depositHook), _leaf(2000e6, false)));

        assertEq(cash.balanceOf(gyldDeposit), 2000e6, "cash at Gyld's pinned address");
        assertEq(cash.balanceOf(strategy), START_CASH - 2000e6);
        assertEq(transit.cashOut(strategy, address(bond)), 2000e6);
        assertEq(_tvl(), before + 2000e6, "cash in transit counted at face");
        assertEq(depositHook.getOutAmount(strategy), 0, "terminal leg publishes zero");

        // Gyld fills at the broker and mints 1,990 bonds (fees inside) to the receiver; the reconciler settles.
        vm.warp(block.timestamp + 2 days);
        _refreshClocks();
        vm.prank(gyldMinter);
        bond.mint(receiver, 1990e18);
        assertEq(_tvl(), before + 2000e6, "a delivery in the receiver is not valued: the open lot still is");
        assertTrue(oracle.hasUnsettledDelivery(address(bond), strategy), "P4: do not push a PPS until it is swept");
        vm.prank(reconciler);
        transit.settleMint(1, 2000e6, 1990e18, keccak256("mint_request_id")); // lot 1 = the deposit above
        assertEq(transit.cashOut(strategy, address(bond)), 0);
        assertFalse(oracle.hasUnsettledDelivery(address(bond), strategy));
        assertEq(_tvl(), before + 1990e6, "valuation moved only by what Gyld actually delivered");
        assertEq(oracle.getBalanceOfOwner(address(bond), strategy), START_BONDS + 1990e18, "swept into the wallet");
        assertEq(bond.balanceOf(receiver), 0);
    }

    /// @dev A stale lot blocks new deposits and is flagged; it does NOT drop out of the valuation (K8: a late settle
    ///      is operational latency, not a loss, and a cliff here would be a discount for whoever buys in the window).
    function test_E2E_Deposit_StaleTransit_GateWithoutCliff() public {
        executeOp(_single(address(depositHook), _leaf(1000e6, false)));
        uint256 withTransit = _tvl();
        vm.warp(block.timestamp + AGE + 1);
        _refreshClocks();
        assertTrue(oracle.hasStaleTransit(address(bond), strategy));
        assertEq(_tvl(), withTransit, "stale transit stays in the valuation: no PPS cliff");
        // a second deposit leaf is refused at build, so the op cannot even be constructed
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        depositHook.build(address(0), strategy, _leaf(1, false));
        // settlement reopens (once the mint has landed in the receiver)
        vm.prank(gyldMinter);
        bond.mint(receiver, 1000e18);
        vm.prank(reconciler);
        transit.settleMint(1, 1000e6, 1000e18, bytes32("m"));
        depositHook.build(address(0), strategy, _leaf(1, false));
    }

    function test_E2E_Deposit_CapAcrossTwoLeavesInOneBatch_RevertsWhole() public {
        address[] memory hooks = new address[](2);
        hooks[0] = address(depositHook);
        hooks[1] = address(depositHook);
        bytes[] memory d = new bytes[](2);
        d[0] = _leaf(CAP, false);
        d[1] = _leaf(1, false);
        uint256 cashBefore = cash.balanceOf(strategy);
        instance.expect4337Revert(GyldInTransitRegistry.CAP_EXCEEDED.selector);
        executeOp(_op(hooks, d));
        assertEq(cash.balanceOf(strategy), cashBefore, "first leaf rolled back with the second");
        assertEq(transit.cashOut(strategy, address(bond)), 0);
    }

    /// @dev The one legitimate chain: a TransferHook that moved cash INTO the strategy, then a deposit sized
    ///      from it. `TransferHook` publishes the recipient's delta as outAmount and the token as outToken.
    function test_E2E_Chain_TransferThenDeposit_UsePrevHookAmount() public {
        // TransferHook publishes the recipient's balance delta as outAmount and the token as outToken, so a
        // plain transfer to the deposit address followed by a deposit leaf sized from it is the one legitimate
        // predecessor shape (same token, non-zero published amount).
        address[] memory hooks = new address[](2);
        hooks[0] = address(transferHook);
        hooks[1] = address(depositHook);
        bytes[] memory d = new bytes[](2);
        // TransferHook layout: token@52, to@72, amount@92, usePrev@124
        d[0] = abi.encodePacked(
            bytes32(0), bytes20(address(0)), bytes20(address(cash)), bytes20(gyldDeposit), uint256(300e6), false
        );
        d[1] = _leaf(1, true);
        uint256 cashBefore = cash.balanceOf(strategy);
        executeOp(_op(hooks, d));
        assertEq(cash.balanceOf(strategy), cashBefore - 600e6, "transfer 300 + deposit sized at 300");
        assertEq(cash.balanceOf(gyldDeposit), 600e6);
        assertEq(transit.cashOut(strategy, address(bond)), 300e6, "only the hook's own leg is recorded");
    }

    /// @dev A successor sized from the deposit hook fails closed: it published zero.
    function test_E2E_SuccessorAfterDeposit_FailsClosed() public {
        address[] memory hooks = new address[](2);
        hooks[0] = address(depositHook);
        hooks[1] = address(redeemHook);
        bytes[] memory d = new bytes[](2);
        d[0] = _leaf(100e6, false);
        d[1] = _leaf(1, true);
        uint256 cashBefore = cash.balanceOf(strategy);
        // the redeem hook requires prev outToken == bond; the deposit hook published cash -> mismatch, and
        // even with a matching token the zero amount would be refused
        instance.expect4337Revert(bytes4(keccak256("PREV_TOKEN_MISMATCH()")));
        executeOp(_op(hooks, d));
        assertEq(cash.balanceOf(strategy), cashBefore, "whole batch rolled back");
    }

    /*//////////////////////////////////////////////////////////////
                                REDEEM SIDE
    //////////////////////////////////////////////////////////////*/

    function test_E2E_Redeem_TvlContinuous_AtLiveNav_ThenPayout() public {
        uint256 before = _tvl();
        executeOp(_single(address(redeemHook), _leaf(400e18, false)));
        assertEq(bond.balanceOf(gyldHolding), 400e18, "bonds at Gyld's pinned holding wallet");
        assertEq(bond.balanceOf(strategy), START_BONDS - 400e18);
        assertEq(transit.bondsOut(strategy, address(bond)), 400e18);
        assertEq(_tvl(), before, "valuation unchanged by the exit");

        // NAV rises while the sale is pending: bonds in transit are still bonds and mark at the live NAV too
        vm.warp(block.timestamp + 1 days);
        navFeed.setLatestAnswer(1.02e8);
        aggregator.setLastUpdate(strategy, block.timestamp);
        assertEq(_tvl(), 1000e18 * 1.02e6 / 1e18, "held and in transit both at 1.02");

        // the broker sale settles, Gyld pays out to the registered withdrawal address (the receiver): 400 of cash
        // for 400 bonds at 1.02 is a 1.96% discount, inside the instrument's 2% exit bound, so the settle is
        // accepted; 399 would have been refused as a loss (SETTLE_BELOW_NAV) and left to the manual path
        vm.prank(gyldMinter);
        cash.mint(receiver, 400e6);
        vm.prank(reconciler);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.SETTLE_BELOW_NAV.selector, 1, 399e6, 399.84e6));
        transit.settleRedemption(1, 400e18, 399e6, keccak256("redeem_id"));
        vm.prank(reconciler);
        transit.settleRedemption(1, 400e18, 400e6, keccak256("redeem_id")); // lot 1 = the redeem above
        assertEq(transit.bondsOut(strategy, address(bond)), 0);
        assertEq(_tvl(), 600e18 * 1.02e6 / 1e18, "only held bonds remain in the bond valuation");
        assertEq(cash.balanceOf(strategy), START_CASH + 400e6, "swept from the receiver by the settle");
        assertEq(cash.balanceOf(receiver), 0);
    }

    function test_E2E_Redeem_WorksWhileSuspended_DepositDoesNot() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        uint256 cashBefore = cash.balanceOf(strategy);
        instance.expect4337Revert(GyldTradePolicy.NAV_SUSPENDED.selector);
        executeOp(_single(address(depositHook), _leaf(100e6, false)));
        assertEq(cash.balanceOf(strategy), cashBefore);
        executeOp(_single(address(redeemHook), _leaf(10e18, false)));
        assertEq(bond.balanceOf(gyldHolding), 10e18, "the exit stays possible during an incident");
        assertEq(transit.bondsOut(strategy, address(bond)), 10e18, "recorded without needing a usable NAV");
    }

    /*//////////////////////////////////////////////////////////////
                             DESTINATION CHANGE
    //////////////////////////////////////////////////////////////*/

    function test_E2E_ProposedDestinationChange_DoesNotAffectInFlightLeaves() public {
        vm.prank(admin);
        transit.proposeDestinations(strategy, address(0xBAD1), address(0xBAD2));
        executeOp(_single(address(depositHook), _leaf(100e6, false)));
        assertEq(cash.balanceOf(gyldDeposit), 100e6, "still the OLD address while the change is pending");
        assertEq(cash.balanceOf(address(0xBAD1)), 0);
        vm.warp(block.timestamp + transit.DESTINATION_DELAY());
        _refreshClocks();
        vm.prank(admin);
        transit.executeDestinations(strategy);
        executeOp(_single(address(depositHook), _leaf(100e6, false)));
        assertEq(cash.balanceOf(address(0xBAD1)), 100e6, "after the timelock the new address is used");
        // the lot opened before the rotation still names the address it was actually sent to
        assertEq(transit.getLot(1).destination, gyldDeposit, "old lot keeps the old destination");
        assertEq(transit.getLot(2).destination, address(0xBAD1));
    }

    /// @dev A second strategy on the same chain has no pair until governance sets one, so its leaves fail at build.
    function test_E2E_SecondStrategy_RefusedUntilItsOwnDestinationsAreSet() public {
        address second = address(0x5EC0);
        aggregator.register(second);
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        depositHook.build(address(0), second, _leaf(1, false));
        vm.expectRevert(GyldInvestorTransferBase.DESTINATION_NOT_SET.selector);
        redeemHook.build(address(0), second, _leaf(1, false));
        vm.prank(admin);
        transit.setDestinations(second, address(0xD2), address(0x42));
        depositHook.build(address(0), second, _leaf(1, false));
        redeemHook.build(address(0), second, _leaf(1, false));
    }

    /*//////////////////////////////////////////////////////////////
                    MORE: FILLS, FEES, BOOKS, SECOND STRATEGY
    //////////////////////////////////////////////////////////////*/

    /// @dev A mint request filled in two pieces settles the SAME lot twice; valuation stays continuous throughout.
    function test_E2E_PartialFills_SameLot_TvlContinuous() public {
        uint256 before = _tvl();
        executeOp(_single(address(depositHook), _leaf(2000e6, false)));
        assertEq(_tvl(), before + 2000e6);
        vm.warp(block.timestamp + 1 days);
        _refreshClocks();
        vm.prank(gyldMinter);
        bond.mint(receiver, 800e18);
        vm.prank(reconciler);
        transit.settleMint(1, 800e6, 800e18, keccak256("req/fill-1"));
        assertEq(transit.getLot(1).open, 1200e6, "lot shrank by the first fill");
        assertEq(_tvl(), before + 2000e6, "800 bonds at 1.00 + 1200 cash");
        vm.warp(block.timestamp + 1 days);
        _refreshClocks();
        vm.prank(gyldMinter);
        bond.mint(receiver, 1200e18);
        vm.prank(reconciler);
        transit.settleMint(1, 1200e6, 1200e18, keccak256("req/fill-2"));
        assertEq(transit.getLot(1).open, 0, "closed");
        assertEq(transit.transit(strategy, address(bond)).oldestOpenAt, 0);
        assertEq(_tvl(), before + 2000e6, "2000 bonds at 1.00");
        assertFalse(oracle.hasStaleTransit(address(bond), strategy));
    }

    /// @dev With the expected fee configured, the real fee at settlement is already priced in: no PPS step.
    function test_E2E_FeeHaircut_NoStepWhenTheRealFeeMatches() public {
        vm.prank(admin);
        transit.setTransitFeeBps(address(bond), 50); // Gyld's 0.5% upfront mint fee
        uint256 before = _tvl();
        executeOp(_single(address(depositHook), _leaf(2000e6, false)));
        uint256 duringTransit = _tvl();
        assertEq(duringTransit, before + 1990e6, "cash in transit net of the expected 0.5%");
        vm.warp(block.timestamp + 2 days);
        _refreshClocks();
        // Gyld debits the whole 2000 (10 of it as fee) and mints 1990 bonds (NAV 1.00). The reconciler reports the
        // GROSS debit: the band tolerates the fee, no manual settle is needed and the lot closes in one call.
        vm.prank(gyldMinter);
        bond.mint(receiver, 1990e18);
        vm.prank(reconciler);
        transit.settleMint(1, 2000e6, 1990e18, keccak256("req"));
        assertEq(_tvl(), duringTransit, "settlement does not move the valuation when the fee was as expected");
        assertEq(transit.getLot(1).open, 0);
        // a fee WORSE than expected shows up as a step of exactly the surprise
        executeOp(_single(address(depositHook), _leaf(1000e6, false)));
        uint256 withSecond = _tvl();
        vm.warp(block.timestamp + 1 days);
        _refreshClocks();
        vm.prank(gyldMinter);
        bond.mint(receiver, 990e18); // 1% taken instead of 0.5%: still inside the band (fee + 2% premium)
        vm.prank(reconciler);
        transit.settleMint(2, 1000e6, 990e18, keccak256("req2"));
        assertEq(_tvl(), withSecond - 5e6, "only the 0.5% surprise is a step");
    }

    /// @dev A rolling book through the executor (a deposit a week, each settled within a day, always one lot
    ///      overlapping the next) never goes stale, for longer than maxTransitAge many times over.
    function test_E2E_RollingBook_NeverStale() public {
        uint256 lotId;
        uint256 overlap;
        uint256 start = block.timestamp;
        for (uint256 week; week < 8; ++week) {
            executeOp(_single(address(depositHook), _leaf(500e6, false)));
            lotId = transit.lotCount();
            assertFalse(oracle.hasStaleTransit(address(bond), strategy), "never stale on a healthy book");
            vm.warp(block.timestamp + 1 days);
            _refreshClocks();
            vm.prank(gyldMinter);
            bond.mint(receiver, overlap != 0 ? 600e18 : 500e18);
            vm.prank(reconciler);
            transit.settleMint(lotId, 500e6, 500e18, bytes32(lotId));
            if (overlap != 0) {
                vm.prank(reconciler);
                transit.settleMint(overlap, 100e6, 100e18, bytes32(overlap));
            }
            executeOp(_single(address(depositHook), _leaf(100e6, false)));
            overlap = transit.lotCount();
            vm.warp(block.timestamp + 6 days);
            _refreshClocks();
            assertFalse(oracle.hasStaleTransit(address(bond), strategy));
            depositHook.build(address(0), strategy, _leaf(1, false)); // the gate stays open
        }
        assertGt(block.timestamp - start, AGE * 3);
        assertEq(transit.cashOut(strategy, address(bond)), 100e6, "only the last overlap is open");
    }

    /// @dev A cancelled redemption: Gyld sends the bonds back from the holding wallet to the receiver and the
    ///      reconciler books settleReturn. Valuation never moves, not even between the return and the settle (the
    ///      receiver is not valued, the open lot is), and the wallet is whole again after the sweep.
    function test_E2E_Redeem_Cancelled_BondsReturned() public {
        uint256 before = _tvl();
        uint256 bondsBefore = bond.balanceOf(strategy);
        executeOp(_single(address(redeemHook), _leaf(250e18, false)));
        assertEq(_tvl(), before);
        vm.warp(block.timestamp + 3 days);
        _refreshClocks();
        vm.prank(gyldHolding);
        bond.transfer(receiver, 250e18);
        assertEq(_tvl(), before, "never counted twice: the receiver is outside the valuation");
        assertTrue(oracle.hasUnsettledDelivery(address(bond), strategy), "but flagged until the settle sweeps it");
        vm.prank(reconciler);
        transit.settleReturn(1, 250e18, keccak256("redeem/cancelled"));
        assertEq(_tvl(), before, "still exactly where it started");
        assertFalse(oracle.hasUnsettledDelivery(address(bond), strategy));
        assertEq(bond.balanceOf(strategy), bondsBefore);
        assertEq(transit.bondsOut(strategy, address(bond)), 0);
    }

    /// @dev Two real ERC-7579 strategies through the same hooks and executor: own pair, own lots, own staleness,
    ///      own valuation; one strategy's stale lot never touches the other.
    function test_E2E_TwoStrategies_IndependentBooks() public {
        AccountInstance memory second = makeAccountInstance(keccak256("gyld-investor-e2e-second"));
        address strategyB = second.account;
        second.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        aggregator.register(strategyB);
        cash.mint(strategyB, START_CASH);
        bond.mint(strategyB, START_BONDS);
        vm.mockCall(
            strategyB,
            abi.encodeWithSignature("getVaultInfo()"),
            abi.encode(address(vaultShares), address(cash), uint8(18))
        );
        address depositB = address(0xDE91);
        address holdingB = address(0x401E);
        vm.prank(admin);
        transit.setDestinations(strategyB, depositB, holdingB);

        executeOp(_single(address(depositHook), _leaf(1000e6, false)));
        executeOp(_singleFor(second, address(depositHook), _leaf(2500e6, false)));
        executeOp(_singleFor(second, address(redeemHook), _leaf(100e18, false)));
        assertEq(cash.balanceOf(gyldDeposit), 1000e6, "A's pair");
        assertEq(cash.balanceOf(depositB), 2500e6, "B's pair");
        assertEq(bond.balanceOf(holdingB), 100e18);
        assertEq(transit.cashOut(strategy, address(bond)), 1000e6);
        assertEq(transit.cashOut(strategyB, address(bond)), 2500e6);
        assertEq(transit.bondsOut(strategyB, address(bond)), 100e18);
        assertEq(transit.getLot(2).account, strategyB);
        assertEq(transit.getLot(2).destination, depositB);
        assertEq(_tvl(), START_BONDS * NAV_IN_CASH / 1e18 + 1000e6);
        assertEq(oracle.getTVLByOwnerOfShares(address(bond), strategyB), START_BONDS * NAV_IN_CASH / 1e18 + 2500e6);

        // A's lot goes stale; B keeps depositing
        vm.warp(block.timestamp + AGE + 1);
        _refreshClocks();
        aggregator.setLastUpdate(strategyB, block.timestamp);
        assertTrue(oracle.hasStaleTransit(address(bond), strategy));
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        depositHook.build(address(0), strategy, _leaf(1, false));
        // B is stale too (same clock) until ITS lots settle; Gyld delivers to B, B's lots settle, A stays stale
        address receiverB = address(transit.receiverOf(strategyB));
        vm.prank(gyldMinter);
        bond.mint(receiverB, 2500e18);
        vm.prank(reconciler);
        transit.settleMint(2, 2500e6, 2500e18, bytes32("b"));
        vm.prank(holdingB);
        bond.transfer(receiverB, 100e18);
        vm.prank(reconciler);
        transit.settleReturn(3, 100e18, bytes32("b-r"));
        assertFalse(oracle.hasStaleTransit(address(bond), strategyB));
        assertTrue(oracle.hasStaleTransit(address(bond), strategy), "A still stale");
        executeOp(_singleFor(second, address(depositHook), _leaf(10e6, false)));
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        depositHook.build(address(0), strategy, _leaf(1, false));
    }

    /// @dev A loss is booked by governance through the timelocked manual settle; clocks are refreshed across the delay.
    function _bookLoss(uint256 lotId, uint256 amount, bytes32 ref) internal {
        vm.startPrank(admin);
        transit.proposeManualSettle(lotId, amount, ref);
        vm.warp(block.timestamp + transit.MANUAL_SETTLE_DELAY());
        transit.executeManualSettle(lotId);
        vm.stopPrank();
        _refreshClocks();
    }

    function _singleFor(
        AccountInstance memory inst,
        address hook,
        bytes memory data
    )
        internal
        returns (UserOpData memory)
    {
        address[] memory hooks = new address[](1);
        hooks[0] = hook;
        bytes[] memory d = new bytes[](1);
        d[0] = data;
        return _getExecOps(
            inst, superExecutor, abi.encode(ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: d }))
        );
    }

    /// @dev A cancelled deposit through the real account: Gyld withdraws the cash back to the RECEIVER, the
    ///      reconciler books settleCashReturn (cash for cash, no NAV), the wallet is whole, cap headroom is back and
    ///      TVL never moved, not even while the cash sat in the receiver.
    function test_E2E_Deposit_Cancelled_CashReturnedToReceiver() public {
        uint256 before = _tvl();
        uint256 cashBefore = cash.balanceOf(strategy);
        executeOp(_single(address(depositHook), _leaf(1000e6, false)));
        // this oracle values wallet bonds plus transit, not wallet cash: the deposit moves 1000 of cash INTO it
        assertEq(_tvl(), before + 1000e6);
        assertEq(transit.previewCashOut(strategy, address(bond), address(cash), CAP), 205, "headroom taken");
        vm.warp(block.timestamp + 2 days);
        _refreshClocks();
        // the operator cancels at Gyld (API call); Gyld withdraws the cash to the whitelisted address: the receiver
        vm.prank(gyldDeposit);
        cash.transfer(receiver, 1000e6);
        assertEq(_tvl(), before + 1000e6, "cash in the receiver is not valued; the open lot still is");
        assertTrue(oracle.hasUnsettledDelivery(address(bond), strategy), "do not push a PPS yet");
        assertEq(transit.previewCashOut(strategy, address(bond), address(cash), CAP), 205, "nothing freed yet");
        vm.prank(reconciler);
        transit.settleCashReturn(1, 1000e6, keccak256("cancel"));
        assertEq(_tvl(), before, "lot closed, cash back in the wallet: exactly where it started");
        assertEq(cash.balanceOf(strategy), cashBefore, "wallet whole again");
        assertEq(cash.balanceOf(receiver), 0);
        assertEq(transit.cashOut(strategy, address(bond)), 0);
        assertFalse(oracle.hasUnsettledDelivery(address(bond), strategy));
        assertEq(transit.previewCashOut(strategy, address(bond), address(cash), CAP), 0, "cap headroom back");
    }

    /// @dev The instrument-wide cap across two real strategies through the executor: B's leaf is refused once the
    ///      instrument is full even though B has per-strategy headroom, and A's settle lets B through.
    function test_E2E_GlobalCap_TwoStrategies() public {
        AccountInstance memory second = makeAccountInstance(keccak256("gyld-investor-e2e-strategy-C"));
        address strategyB = second.account;
        second.installModule({ moduleTypeId: MODULE_TYPE_EXECUTOR, module: address(superExecutor), data: "" });
        aggregator.register(strategyB);
        cash.mint(strategyB, START_CASH);
        vm.mockCall(
            strategyB,
            abi.encodeWithSignature("getVaultInfo()"),
            abi.encode(address(vaultShares), address(cash), uint8(18))
        );
        vm.startPrank(admin);
        transit.setDestinations(strategyB, address(0xDE92), address(0x401F));
        transit.setMaxTotalCashInTransit(address(bond), CAP + 1000e6);
        vm.stopPrank();

        executeOp(_single(address(depositHook), _leaf(CAP, false))); // A fills its own cap
        executeOp(_singleFor(second, address(depositHook), _leaf(1000e6, false))); // B: instrument now full
        assertEq(transit.totalCashInTransit(address(bond)), CAP + 1000e6);
        assertEq(transit.previewCashOut(strategyB, address(bond), address(cash), 1), 207);
        second.expect4337Revert(GyldInTransitRegistry.GLOBAL_CAP_EXCEEDED.selector);
        executeOp(_singleFor(second, address(depositHook), _leaf(1, false)));
        assertEq(transit.cashOut(strategyB, address(bond)), 1000e6, "refused leaf left nothing behind");
        // A's fill settles: the instrument has room again and B's leaf goes through
        vm.prank(gyldMinter);
        bond.mint(receiver, 500e18);
        vm.prank(reconciler);
        transit.settleMint(1, 500e6, 500e18, keccak256("a-fill"));
        executeOp(_singleFor(second, address(depositHook), _leaf(500e6, false)));
        assertEq(transit.cashOut(strategyB, address(bond)), 1500e6);
        assertEq(transit.totalCashInTransit(address(bond)), CAP + 1000e6, "back at the cap");
    }

    /// @dev Gyld pays the strategy directly instead of the receiver (an onboarding mistake). The reconciler cannot
    ///      settle it; the wallet and the lot are both counted until governance proposes the write-down, which nets
    ///      the lot from the proposal on (hasPendingImpairment up for the pusher) and closes it two days later.
    function test_E2E_MisroutedDelivery_StrategyDirect_ThenManual() public {
        uint256 before = _tvl();
        executeOp(_single(address(depositHook), _leaf(1000e6, false)));
        assertEq(_tvl(), before + 1000e6);
        vm.warp(block.timestamp + 1 days);
        _refreshClocks();
        vm.prank(gyldMinter);
        bond.mint(strategy, 1000e18); // misrouted: to the strategy, not the receiver
        assertEq(_tvl(), before + 2000e6, "counted twice: wallet bonds AND the open lot");
        assertFalse(oracle.hasUnsettledDelivery(address(bond), strategy), "the receiver saw nothing");
        vm.prank(reconciler);
        vm.expectRevert(abi.encodeWithSelector(GyldInTransitRegistry.DELIVERY_NOT_FOUND.selector, 1, 0, 1000e18));
        transit.settleMint(1, 1000e6, 1000e18, keccak256("misrouted"));
        vm.prank(admin);
        transit.proposeManualSettle(1, 1000e6, keccak256("misrouted"));
        assertEq(_tvl(), before + 1000e6, "netted from the proposal on");
        assertTrue(oracle.hasPendingImpairment(address(bond), strategy), "pusher: push the netted PPS, pause deposits");
        vm.warp(block.timestamp + transit.MANUAL_SETTLE_DELAY());
        _refreshClocks();
        vm.prank(admin);
        transit.executeManualSettle(1);
        assertEq(_tvl(), before + 1000e6, "the execute is not a second step");
        assertFalse(oracle.hasPendingImpairment(address(bond), strategy));
        assertEq(transit.cashOut(strategy, address(bond)), 0);
    }
}
