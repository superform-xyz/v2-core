// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";

// Superform
import { GyldInvestorDepositHook } from "../../../src/hooks/gyld/GyldInvestorDepositHook.sol";
import { GyldInvestorRedeemHook } from "../../../src/hooks/gyld/GyldInvestorRedeemHook.sol";
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
///         stale-transit cliff; the cap across two leaves in one batch; the one legitimate chain; and the
///         fail-closed successor.
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
        transit.setDestinations(gyldDeposit, gyldHolding);
        transit.setMaxTransitAge(AGE);
        transit.setMaxCashInTransit(address(bond), CAP);
        transit.grantRole(transit.RECONCILER_ROLE(), reconciler);
        vm.stopPrank();

        depositHook = new GyldInvestorDepositHook(address(transit), address(policy));
        redeemHook = new GyldInvestorRedeemHook(address(transit));
        transferHook = new TransferHook(address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE));

        instance = makeAccountInstance(keccak256("gyld-investor-e2e-strategy"));
        strategy = instance.account;
        aggregator.register(strategy);
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

        // Gyld fills at the broker and mints 1,990 bonds (fees inside); the reconciler settles.
        vm.warp(block.timestamp + 2 days);
        _refreshClocks();
        vm.prank(gyldMinter);
        bond.mint(strategy, 1990e18);
        vm.prank(reconciler);
        transit.settleMint(1, 2000e6, 1990e18, keccak256("mint_request_id")); // lot 1 = the deposit above
        assertEq(transit.cashOut(strategy, address(bond)), 0);
        assertEq(_tvl(), before + 1990e6, "valuation moved only by what Gyld actually delivered");
        assertEq(oracle.getBalanceOfOwner(address(bond), strategy), START_BONDS + 1990e18);
    }

    function test_E2E_Deposit_StaleTransit_CliffAndBlock() public {
        executeOp(_single(address(depositHook), _leaf(1000e6, false)));
        uint256 withTransit = _tvl();
        vm.warp(block.timestamp + AGE + 1);
        _refreshClocks();
        assertTrue(oracle.hasStaleTransit(address(bond), strategy));
        assertEq(_tvl(), withTransit - 1000e6, "stale transit drops out of the valuation");
        // a second deposit leaf is refused at build, so the op cannot even be constructed
        vm.expectRevert(GyldInTransitRegistry.TRANSIT_STALE.selector);
        depositHook.build(address(0), strategy, _leaf(1, false));
        // settlement reopens
        vm.prank(reconciler);
        transit.settleMint(1, 1000e6, 1e18, bytes32("m"));
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

        // the broker sale settles, Gyld pays out to the registered withdrawal address (the strategy)
        vm.prank(gyldMinter);
        cash.mint(strategy, 399e6);
        vm.prank(reconciler);
        transit.settleRedemption(1, 400e18, 399e6, keccak256("redeem_id")); // lot 1 = the redeem above
        assertEq(transit.bondsOut(strategy, address(bond)), 0);
        assertEq(_tvl(), 600e18 * 1.02e6 / 1e18, "only held bonds remain in the bond valuation");
        assertEq(cash.balanceOf(strategy), START_CASH + 399e6);
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
        transit.proposeDestinations(address(0xBAD1), address(0xBAD2));
        executeOp(_single(address(depositHook), _leaf(100e6, false)));
        assertEq(cash.balanceOf(gyldDeposit), 100e6, "still the OLD address while the change is pending");
        assertEq(cash.balanceOf(address(0xBAD1)), 0);
        vm.warp(block.timestamp + transit.DESTINATION_DELAY());
        _refreshClocks();
        vm.prank(admin);
        transit.executeDestinations();
        executeOp(_single(address(depositHook), _leaf(100e6, false)));
        assertEq(cash.balanceOf(address(0xBAD1)), 100e6, "after the timelock the new address is used");
    }
}
