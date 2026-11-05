// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { stdError } from "forge-std/StdError.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Superform
import { ApproveAndTradeGyldBondHook } from "../../../../../src/hooks/swappers/gyld/ApproveAndTradeGyldBondHook.sol";
import { GyldTradeGuardHook } from "../../../../../src/hooks/swappers/gyld/GyldTradeGuardHook.sol";
import { GyldBondRegistry } from "../../../../../src/accounting/oracles/GyldBondRegistry.sol";
import { GyldBondYieldSourceOracle } from "../../../../../src/accounting/oracles/GyldBondYieldSourceOracle.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";

import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { MockAggregator } from "../../../../mocks/MockAggregator.sol";
import { MockGyldSettlement } from "../../../../mocks/gyld/MockGyldSettlement.sol";
import { MockGyldNavFeed } from "../../../../mocks/gyld/MockGyldNavFeed.sol";
import {
    MockReentrantGyldSettlement,
    MockGyldSettlementWithExtraPowers,
    MockFeeOnTransferERC20
} from "../../../../mocks/gyld/GyldAdversarialMocks.sol";
import { InternalHelpers } from "../../../../utils/InternalHelpers.sol";
import { IGyldTradePolicy } from "../../../../../src/interfaces/accounting/IGyldTradePolicy.sol";
import { MockGyldTradePolicy } from "../../../../../test/mocks/gyld/MockGyldTradePolicy.sol";

/// @title GyldHooksAdversarialTest
/// @notice Adversarial coverage for the two Gyld hooks: a venue that reenters the hook's own lifecycle, a
///         venue that can do more than fill a quote, hostile token semantics, and the question of what the
///         guard and the trade hook do NOT bind to each other.
contract GyldHooksAdversarialTest is InternalHelpers {
    ApproveAndTradeGyldBondHook internal hook;
    GyldTradeGuardHook internal guard;
    GyldBondRegistry internal registry;
    GyldBondYieldSourceOracle internal oracle;
    MockGyldSettlement internal settlement;
    MockHook internal prevHook;

    MockERC20 internal bond;
    MockERC20 internal cash;
    MockGyldNavFeed internal navFeed;
    MockAggregator internal chainlinkFeed;

    address internal account;
    address internal admin = address(0xA11CE);
    address internal attacker = address(0xBAD);

    uint256 internal constant MAX_INPUT = 10_000e6;
    uint256 internal constant CASH_IN = 1000e6;
    uint256 internal constant BOND_QUOTE = 1000e18;
    uint256 internal constant BOND_MIN = 995e18;
    bytes32 internal constant QUOTE_ID = keccak256("adversarial-quote");
    MockGyldTradePolicy internal tradePolicy;


    function setUp() public {
        tradePolicy = new MockGyldTradePolicy();
        account = address(this);
        vm.warp(1_800_000_000);

        bond = new MockERC20("Gyld Bond", "GBOND", 18);
        cash = new MockERC20("USD Coin", "USDC", 6);
        navFeed = new MockGyldNavFeed(8);
        navFeed.setFreshNav(address(bond), 1e8);
        chainlinkFeed = new MockAggregator(8);
        chainlinkFeed.setLatestAnswer(1e8);

        registry = new GyldBondRegistry(admin);
        oracle = new GyldBondYieldSourceOracle(address(0xC0FFEE), address(registry));
        settlement = new MockGyldSettlement();

        _registerBond(address(bond), address(cash), address(navFeed), registry.FEED_KIND_GYLD_NATIVE());

        hook = new ApproveAndTradeGyldBondHook(address(settlement), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        guard = new GyldTradeGuardHook(address(oracle));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(cash));

        cash.mint(account, 100 * CASH_IN);
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _registerBond(address bondToken, address cashToken, address feed, uint8 kind) internal {
        GyldBondRegistry.InstrumentConfig memory cfg;
        cfg.bondToken = bondToken;
        cfg.cashToken = cashToken;
        cfg.navFeed = feed;
        cfg.navFeedKind = kind;
        cfg.maxObservationAge = 2 days;
        cfg.maxPublicationAge = 1 days;
        vm.prank(admin);
        registry.registerInstrument(cfg);
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

    function _data(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputQuote,
        uint256 outputMin,
        bytes memory venueCalldata
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = abi.encode(block.timestamp + 1 hours, venueCalldata);
        return
            bytes.concat(_layer1(inputToken, outputToken, inputAmount, outputQuote, outputMin, payload.length), payload);
    }

    function _buyData() internal view returns (bytes memory) {
        return _data(
            address(cash),
            address(bond),
            CASH_IN,
            BOND_QUOTE,
            BOND_MIN,
            settlement.encodeFill(
                QUOTE_ID, account, address(cash), address(bond), CASH_IN, BOND_QUOTE, block.timestamp + 1 hours
            )
        );
    }

    function _guardData(address bondToken, address cashToken) internal pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), bytes20(bondToken), bytes20(cashToken), uint256(2 days), uint256(1 days));
    }

    function _run(ApproveAndTradeGyldBondHook h, bytes memory data) internal returns (uint256, bytes memory) {
        h.setExecutionContext(account);
        (uint256 failedAt, bytes memory ret) = _executeBatch(h.build(address(prevHook), account, data));
        if (failedAt == type(uint256).max) h.resetExecutionState(account);
        return (failedAt, ret);
    }

    /*//////////////////////////////////////////////////////////////
                    A VENUE THAT REENTERS THE HOOK
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds a hook pinned to a reentrant venue, plus the matching leaf.
    function _reentrantSetup(MockReentrantGyldSettlement.Attack attack)
        internal
        returns (ApproveAndTradeGyldBondHook reHook, bytes memory data)
    {
        MockReentrantGyldSettlement venue = new MockReentrantGyldSettlement();
        reHook = new ApproveAndTradeGyldBondHook(address(venue), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        bytes memory venueCalldata = venue.encodeFill(
            QUOTE_ID, account, address(cash), address(bond), CASH_IN, BOND_QUOTE, block.timestamp + 1 hours
        );
        data = _data(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, venueCalldata);
        venue.configure(address(reHook), attack, data);
    }

    /// @dev `setExecutionContext` is permissionless, so the strongest reentrancy available to a venue is to
    ///      rotate the account's execution context mid-fill. The snapshot then lives under a key the later
    ///      `postExecute` cannot reach, and the hook must fail CLOSED rather than compare against nothing.
    function test_Reentrancy_VenueRotatesTheExecutionContext_FailsClosed() public {
        (ApproveAndTradeGyldBondHook reHook, bytes memory data) =
            _reentrantSetup(MockReentrantGyldSettlement.Attack.ROTATE_CONTEXT);

        (uint256 failedAt, bytes memory ret) = _run(reHook, data);
        assertEq(failedAt, 5, "fails at postExecute");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.SNAPSHOT_NOT_TAKEN.selector);
        // This harness runs each execution as its OWN transaction, so there is no rollback here and the
        // transferred bond stays. Whole-batch atomicity is the executor's job and is covered end to end in
        // `GyldBondFlowIntegration`. What matters here is that the hook refused rather than accepting a
        // pre-trade balance as output.
        assertEq(bond.balanceOf(account), BOND_QUOTE, "the harness is not atomic; the refusal is the point");
    }

    /// @dev A venue calling `preExecute` is not the account, so the caller gate stops it. Without that gate a
    ///      venue could re-arm the snapshot after taking the input.
    function test_Reentrancy_VenueCallsPreExecute_Unauthorized() public {
        (ApproveAndTradeGyldBondHook reHook, bytes memory data) =
            _reentrantSetup(MockReentrantGyldSettlement.Attack.CALL_PRE_EXECUTE);

        (uint256 failedAt, bytes memory ret) = _run(reHook, data);
        assertEq(failedAt, 3, "the venue call itself reverts");
        assertEq(bytes4(ret), BaseHook.UNAUTHORIZED_CALLER.selector);
    }

    /// @dev Same gate on `postExecute`: a venue cannot close the hook's accounting early.
    function test_Reentrancy_VenueCallsPostExecute_Unauthorized() public {
        (ApproveAndTradeGyldBondHook reHook, bytes memory data) =
            _reentrantSetup(MockReentrantGyldSettlement.Attack.CALL_POST_EXECUTE);

        (uint256 failedAt, bytes memory ret) = _run(reHook, data);
        assertEq(failedAt, 3);
        assertEq(bytes4(ret), BaseHook.UNAUTHORIZED_CALLER.selector);
    }

    /// @dev `resetExecutionState` is gated on the last caller of `setExecutionContext`, which is the executor,
    ///      never the venue.
    function test_Reentrancy_VenueResetsExecutionState_Unauthorized() public {
        (ApproveAndTradeGyldBondHook reHook, bytes memory data) =
            _reentrantSetup(MockReentrantGyldSettlement.Attack.RESET_EXECUTION_STATE);

        (uint256 failedAt, bytes memory ret) = _run(reHook, data);
        assertEq(failedAt, 3);
        assertEq(bytes4(ret), BaseHook.UNAUTHORIZED_CALLER.selector);
    }

    /// @dev An honest reentrant venue (no attack configured) still settles, so the tests above isolate the
    ///      reentrancy rather than the mock.
    function test_Reentrancy_HonestVenueStillSettles() public {
        (ApproveAndTradeGyldBondHook reHook, bytes memory data) =
            _reentrantSetup(MockReentrantGyldSettlement.Attack.NONE);

        (uint256 failedAt,) = _run(reHook, data);
        assertEq(failedAt, type(uint256).max);
        assertEq(bond.balanceOf(account), BOND_QUOTE);
    }

    /// @dev The pre/post mutexes stop a second entry into the same context even from the account itself.
    function test_Mutex_PreExecuteCannotRunTwiceInOneContext() public {
        bytes memory data = _buyData();
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        hook.preExecute(address(0), account, data);
    }

    function test_Mutex_PostExecuteCannotRunTwiceInOneContext() public {
        bytes memory data = _buyData();
        hook.setExecutionContext(account);
        hook.preExecute(address(0), account, data);
        bond.mint(account, BOND_QUOTE);
        cash.burn(account, CASH_IN);
        hook.postExecute(address(0), account, data);
        vm.expectRevert(BaseHook.POST_EXECUTE_ALREADY_CALLED.selector);
        hook.postExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
          THE BLAST RADIUS OF OPAQUE VENUE CALLDATA — FINDING
    //////////////////////////////////////////////////////////////*/

    /// @dev FINDING (awaiting an owner decision, pinned here so the risk is explicit).
    ///      The hook forwards the leaf's venue calldata VERBATIM to the pinned settlement address, as the
    ///      account, and `inspect()` commits only the token pair. So whoever can present a valid leaf can make
    ///      the account call ANY function on the settlement contract with ANY arguments, not only a fill.
    ///      The hook's outcome assertions bound the damage, they do not bound the call: a settlement exposing
    ///      anything that moves an approved balance elsewhere is directly exploitable, because the hook grants
    ///      it an allowance for `inputAmount` immediately before the call.
    ///      Here the venue exposes `sweep(token, to, amount)`. The input leaves the account to the attacker,
    ///      no output arrives, and the leg fails only at `postExecute` on MIN_OUT. In a batch that is enough,
    ///      because the executor rolls back. It would NOT be enough if the hook were ever used outside an
    ///      atomic batch, nor if the swept token were the OUTPUT token rather than the input.
    ///      Mitigations to decide between: commit a selector allowlist in the hook, commit the venue calldata
    ///      hash into `inspect()`, or accept it on the basis that Gyld's settlement exposes no such function
    ///      and pin that with a deployment-time assertion.
    function test_Finding_OpaqueCalldataReachesAnyFunctionOnThePinnedVenue() public {
        MockGyldSettlementWithExtraPowers venue = new MockGyldSettlementWithExtraPowers();
        ApproveAndTradeGyldBondHook powerHook = new ApproveAndTradeGyldBondHook(address(venue), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);

        // A leaf whose header looks like an ordinary buy, but whose payload calls `sweep` instead of `fill`.
        bytes memory hostile = venue.encodeSweep(address(cash), attacker, CASH_IN);
        bytes memory data = _data(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, hostile);

        // The leaf identity is indistinguishable from an honest buy of the same pair.
        assertEq(powerHook.inspect(data), abi.encodePacked(address(cash), address(bond)), "same leaf identity");

        (uint256 failedAt, bytes memory ret) = _run(powerHook, data);
        // The venue call SUCCEEDS; only the post-trade assertions notice that no output arrived.
        assertEq(failedAt, 5, "the hostile call itself went through; postExecute is what refuses");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
    }

    /// @dev The same leaf executed step by step, skipping `postExecute`, shows what the outcome assertions are
    ///      actually protecting: without them the cash is simply gone.
    function test_Finding_WithoutPostExecuteTheSweepSucceeds() public {
        MockGyldSettlementWithExtraPowers venue = new MockGyldSettlementWithExtraPowers();
        ApproveAndTradeGyldBondHook powerHook = new ApproveAndTradeGyldBondHook(address(venue), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        bytes memory hostile = venue.encodeSweep(address(cash), attacker, CASH_IN);
        bytes memory data = _data(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, hostile);

        Execution[] memory ex = powerHook.build(address(prevHook), account, data);
        // Run everything except the final postExecute.
        for (uint256 i; i < ex.length - 1; ++i) {
            (bool ok,) = ex[i].target.call(ex[i].callData);
            assertTrue(ok, "every step up to postExecute succeeds");
        }
        assertEq(cash.balanceOf(attacker), CASH_IN, "the input reached the attacker");

        // And postExecute is the only thing that would have stopped it.
        vm.expectRevert(ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
        powerHook.postExecute(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                 GUARD AND TRADE ARE NOT BOUND — FINDING
    //////////////////////////////////////////////////////////////*/

    /// @dev FINDING (awaiting an owner decision, pinned here so the assumption is explicit).
    ///      Nothing on-chain links a `GyldTradeGuardHook` leaf to the `ApproveAndTradeGyldBondHook` leaf next
    ///      to it. The guard validates the instrument named in ITS OWN calldata. A leaf set can therefore
    ///      guard a fresh instrument while trading a stale or suspended one, and both hooks pass.
    ///      The Merkle root commits both leaves, so this is a correctness burden on the leaf BUILDER, not an
    ///      open attack on a correctly built intent. It is called out because the design treats the guard as
    ///      the thing that makes a Gyld trade safe, and that only holds if the builder pairs them correctly.
    ///      Mitigations to decide between: have the trade hook consult the oracle itself, or have the guard
    ///      read the next hook's calldata, or enforce the pairing in the leaf builder and document it.
    function test_Finding_GuardDoesNotBindToTheTradeItAccompanies() public {
        // A second, perfectly healthy instrument sharing the same cash token.
        MockERC20 healthyBond = new MockERC20("Healthy", "HB", 18);
        MockGyldNavFeed healthyFeed = new MockGyldNavFeed(8);
        healthyFeed.setFreshNav(address(healthyBond), 1e8);
        _registerBond(address(healthyBond), address(cash), address(healthyFeed), registry.FEED_KIND_GYLD_NATIVE());

        // The instrument actually being traded is SUSPENDED.
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);

        // A guard leaf naming the healthy instrument passes, even though the trade is of the suspended one.
        guard.build(address(prevHook), account, _guardData(address(healthyBond), address(cash)));
        assertEq(guard.previewTradable(_guardData(address(healthyBond), address(cash)), account), 0);

        // And the trade hook has no opinion on suspension at all: its gate is the approved pair.
        assertTrue(registry.isApprovedPair(address(bond), address(cash)));
        hook.build(address(prevHook), account, _buyData());
    }

    /// @dev The matching guard DOES refuse, which is the whole point. Pinned beside the finding above so the
    ///      contrast is explicit.
    function test_MatchingGuardRefusesTheSuspendedInstrument() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        bytes memory data = _guardData(address(bond), address(cash));
        vm.expectRevert(GyldTradeGuardHook.NAV_SUSPENDED.selector);
        guard.build(address(prevHook), account, data);
    }

    /// @dev And the trade hook alone will happily trade a suspended instrument, which is why the guard is
    ///      mandatory rather than optional hardening.
    function test_Finding_TradeHookAloneTradesASuspendedInstrument() public {
        vm.prank(admin);
        registry.setNavSuspended(address(bond), true);
        (uint256 failedAt,) = _run(hook, _buyData());
        assertEq(failedAt, type(uint256).max, "the trade settled with valuation suspended");
        assertEq(bond.balanceOf(account), BOND_QUOTE);
    }

    /*//////////////////////////////////////////////////////////////
                        HOSTILE TOKEN SEMANTICS
    //////////////////////////////////////////////////////////////*/

    /// @dev A cash token that taxes the SENDER on top of the transfer makes the account lose more than the
    ///      leaf authorised. The input-side snapshot is what notices; without it the overspend is invisible.
    function test_FeeOnTransferInput_RevertsInputOverspent() public {
        MockFeeOnTransferERC20 taxed = new MockFeeOnTransferERC20(6, 100); // 1% tax on the sender
        MockERC20 taxedBond = new MockERC20("Taxed Bond", "TXB", 18);
        _registerBond(address(taxedBond), address(taxed), address(chainlinkFeed), registry.FEED_KIND_CHAINLINK());
        taxed.mint(account, 10 * CASH_IN);

        bytes memory venueCalldata = settlement.encodeFill(
            QUOTE_ID, account, address(taxed), address(taxedBond), CASH_IN, BOND_QUOTE, block.timestamp + 1 hours
        );
        bytes memory data = _data(address(taxed), address(taxedBond), CASH_IN, BOND_QUOTE, BOND_MIN, venueCalldata);

        (uint256 failedAt, bytes memory ret) = _run(hook, data);
        assertEq(failedAt, 5, "fails at postExecute");
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.INPUT_OVERSPENT.selector);
    }

    /// @dev A venue delivering MORE than quoted is fine, and the hook reports what actually arrived rather
    ///      than the quote, so a downstream hook pipes the true amount.
    function test_VenueOverDelivers_OutAmountIsWhatArrived() public {
        bytes memory venueCalldata = settlement.encodeFill(
            QUOTE_ID, account, address(cash), address(bond), CASH_IN, BOND_QUOTE * 2, block.timestamp + 1 hours
        );
        bytes memory data = _data(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, venueCalldata);

        (uint256 failedAt,) = _run(hook, data);
        assertEq(failedAt, type(uint256).max);
        assertEq(hook.getOutAmount(account), BOND_QUOTE * 2, "the actual amount, not the quote");
        assertEq(bond.balanceOf(account), BOND_QUOTE * 2);
    }

    /// @dev A pre-existing output balance is not counted as trade output, which is what the snapshot is for.
    function test_PreExistingOutputBalance_IsNotCountedAsOutput() public {
        bond.mint(account, 10_000e18); // the account already holds plenty
        settlement.setDeliverNothing(true);

        (uint256 failedAt, bytes memory ret) = _run(hook, _buyData());
        assertEq(failedAt, 5);
        assertEq(bytes4(ret), ApproveAndTradeGyldBondHook.MIN_OUT_NOT_MET.selector);
    }

    /*//////////////////////////////////////////////////////////////
                           CAP ISOLATION
    //////////////////////////////////////////////////////////////*/

    /// @dev The per-transaction cap accumulates per ACCOUNT, so one account cannot exhaust another's budget.
    function test_Cap_IsPerAccount() public {
        bytes memory data = _buyData();
        hook.preExecute(address(0), account, data);
        assertEq(hook.txSpent(account), CASH_IN);
        assertEq(hook.txSpent(attacker), 0, "a different account has its own budget");
    }

    /// @dev Two hook instances keep separate accumulators, so deploying one instance per direction does not
    ///      let the two legs of a round trip eat each other's cap.
    function test_Cap_IsPerHookInstance() public {
        ApproveAndTradeGyldBondHook second = new ApproveAndTradeGyldBondHook(address(settlement), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        bytes memory data = _buyData();

        hook.preExecute(address(0), account, data);
        assertEq(hook.txSpent(account), CASH_IN);
        assertEq(second.txSpent(account), 0, "a sibling instance is unaffected");
    }

    /// @dev The cap is checked against the RUNNING SUM before any approval, so the refused repetition cannot
    ///      leave an allowance behind.
    function test_Cap_RefusalLeavesNoAllowance() public {
        ApproveAndTradeGyldBondHook capped = new ApproveAndTradeGyldBondHook(address(settlement), CASH_IN, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        settlement.setAllowReplay(true);

        (uint256 first,) = _run(capped, _buyData());
        assertEq(first, type(uint256).max);
        (uint256 second,) = _run(capped, _buyData());
        assertEq(second, 0, "refused at preExecute");
        assertEq(cash.allowance(account, address(settlement)), 0, "no allowance from the refused attempt");
    }

    /*//////////////////////////////////////////////////////////////
                        DEPLOYMENT HAZARD — FINDING
    //////////////////////////////////////////////////////////////*/

    /// @dev FINDING, low severity but worth a deployment-time check. The constructor accepts ANY non-zero
    ///      settlement address, including an ERC-20. Pinned at a token, the hook's four executions become
    ///      approve/approve/arbitrary-call/approve all against that token, so the leaf's opaque calldata could
    ///      call `transfer` on it directly as the account. The outcome assertions still apply, but the
    ///      constructor should reject a settlement address that is one of the registry's known tokens, or the
    ///      deploy script should assert it.
    function test_Finding_ConstructorAcceptsATokenAsTheSettlementAddress() public {
        ApproveAndTradeGyldBondHook misconfigured = new ApproveAndTradeGyldBondHook(address(cash), MAX_INPUT, address(tradePolicy), IGyldTradePolicy.TradeSide.BUY);
        assertEq(misconfigured.GYLD_SETTLEMENT(), address(cash), "no sanity check on what a venue is");
    }

    /*//////////////////////////////////////////////////////////////
                                 FUZZ
    //////////////////////////////////////////////////////////////*/

    /// @dev No leaf can make the hook approve a spender other than the pinned settlement, whatever the
    ///      payload contains.
    function testFuzz_OnlyThePinnedSettlementIsEverApproved(bytes calldata venueCalldata) public {
        vm.assume(venueCalldata.length >= 4 && venueCalldata.length < 2000);
        bytes memory data = _data(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, venueCalldata);

        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (address(settlement), 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (address(settlement), CASH_IN)));
        assertEq(ex[3].target, address(settlement), "the call target is immutable");
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (address(settlement), 0)));
    }

    /// @dev The venue calldata is forwarded byte for byte, with nothing prepended or appended.
    function testFuzz_VenueCalldataIsForwardedVerbatim(bytes calldata venueCalldata) public view {
        vm.assume(venueCalldata.length >= 4 && venueCalldata.length < 2000);
        bytes memory data = _data(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, venueCalldata);
        Execution[] memory ex = hook.build(address(prevHook), account, data);
        assertEq(ex[3].callData, venueCalldata);
    }

    /// @dev Whatever the guard's leaf says, a malformed one never passes and a well-formed one is decoded
    ///      into exactly the four committed fields.
    function testFuzz_GuardInspectIsInjective(uint256 obsAge, uint256 pubAge) public view {
        obsAge = bound(obsAge, 1, 30 days);
        pubAge = bound(pubAge, 1, 30 days);
        bytes memory data = abi.encodePacked(bytes32(0), bytes20(address(bond)), bytes20(address(cash)), obsAge, pubAge);
        assertEq(guard.inspect(data), abi.encodePacked(address(bond), address(cash), obsAge, pubAge));
    }

    /*//////////////////////////////////////////////////////////////
            SLIPPAGE IS CALLER-CHOSEN, NOT LEAF-COMMITTED — FINDING
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED by two independent reviews. `inspect()` commits only the token pair, so `outputQuote`,
    ///      `outputMin` and `inputAmount` are all chosen freely by whoever presents the leaf. The two header
    ///      checks are self-consistency only: `outputMin != 0` is satisfied by 1, and `outputQuote >= outputMin`
    ///      by `1 >= 1`. So `MIN_OUT_NOT_MET` guards an honest manager's mistake, NOT a compromised key, and
    ///      the per-transaction cap is the real loss bound.
    ///      This matches `ApproveAndSwapBinanceHook`, whose NatSpec says so plainly. The Gyld hook's NatSpec
    ///      instead claims "the spend is committed inside a venue-signed quote, so the OMS cannot rewrite it",
    ///      which holds only under the unconfirmed venue requirement that the quote be signed. The comment
    ///      should be aligned with the Binance wording so the residual risk is not read as mitigated.
    function test_Finding_OutputMinIsCallerChosenSoOneWeiSatisfiesSlippage() public {
        // A leaf claiming a quote of 1 wei and a floor of 1 wei passes every header check.
        bytes memory venueCalldata = settlement.encodeFill(
            QUOTE_ID, account, address(cash), address(bond), CASH_IN, 1, block.timestamp + 1 hours
        );
        bytes memory data = _data(address(cash), address(bond), CASH_IN, 1, 1, venueCalldata);
        hook.build(address(prevHook), account, data); // no revert

        uint256 cashBefore = cash.balanceOf(account);
        (uint256 failedAt,) = _run(hook, data);
        assertEq(failedAt, type(uint256).max, "the whole leg settles");
        assertEq(bond.balanceOf(account), 1, "one wei of bond received for the full cash amount");
        assertEq(cash.balanceOf(account), cashBefore - CASH_IN, "100 percent of the input spent");
    }

    /*//////////////////////////////////////////////////////////////
                  A NAMED ERROR LOST TO A PANIC — FINDING
    //////////////////////////////////////////////////////////////*/

    /// @dev CONFIRMED. `_validatePayload` checks `PAYLOAD_DATA_OFFSET + payloadLength > data.length`. The
    ///      length word is fully caller-controlled, so a value near `type(uint256).max` makes the ADDITION
    ///      overflow and the call panics instead of returning the named `INVALID_HOOK_DATA`. It still fails
    ///      closed; only the diagnostic is lost.
    ///      Proposed fix, safe because the header check already guarantees `data.length >= 221`:
    ///      `if (payloadLength > data.length - PAYLOAD_DATA_OFFSET) revert INVALID_HOOK_DATA();`
    function test_Finding_AbsurdPayloadLengthPanicsInsteadOfNamedError() public {
        bytes memory payload = abi.encode(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data = bytes.concat(
            _layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, type(uint256).max), payload
        );

        vm.expectRevert(stdError.arithmeticError);
        hook.build(address(prevHook), account, data);
    }

    /// @dev A merely too-large length still gets the named error, so only the overflow edge is affected.
    function test_LargeButNonOverflowingPayloadLength_GetsTheNamedError() public {
        bytes memory payload = abi.encode(block.timestamp + 1 hours, hex"deadbeef");
        bytes memory data =
            bytes.concat(_layer1(address(cash), address(bond), CASH_IN, BOND_QUOTE, BOND_MIN, 1e6), payload);
        vm.expectRevert(ApproveAndTradeGyldBondHook.INVALID_HOOK_DATA.selector);
        hook.build(address(prevHook), account, data);
    }
}
