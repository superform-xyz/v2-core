// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@ERC4337/account-abstraction/contracts/interfaces/IPaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SuperSponsorshipPaymaster } from "../../src/paymaster/SuperSponsorshipPaymaster.sol";
import { ISuperSponsorshipPaymaster } from "../../src/interfaces/ISuperSponsorshipPaymaster.sol";
import { MockEntryPoint } from "../mocks/MockEntryPoint.sol";
import { MockSuperVaultAggregator } from "../mocks/MockSuperVaultAggregator.sol";

/*//////////////////////////////////////////////////////////////
                              HANDLER
//////////////////////////////////////////////////////////////*/

/// @dev Drives the paymaster with strangers funding, the funding role crediting and withdrawing,
///      the manager writing senders (including zero as a block), pausing, and the EntryPoint
///      sponsoring ops end to end. Adversarial actions attempt role-gated writes from strangers
///      and count any that are accepted.
contract PaymasterHandler is Test {
    SuperSponsorshipPaymaster public immutable paymaster;
    MockEntryPoint public immutable ep;
    address public immutable admin;
    address public immutable funder;
    address public immutable manager;

    address[4] public strategies;
    address[6] public strangers;

    // model of the sender state machine, per strategy
    mapping(address => bool) public ghost_initialized;
    mapping(address => bool) public ghost_explicitSet;
    mapping(address => address) public ghost_explicitValue;

    // accounting ghosts, per strategy
    mapping(address => uint256) public ghost_funded;
    mapping(address => uint256) public ghost_credited;
    mapping(address => uint256) public ghost_withdrawn;
    mapping(address => uint256) public ghost_debited;
    uint256 public ghost_unallocatedDeposited;

    // coverage + adversarial counters
    uint256 public calls_fund;
    uint256 public calls_credit;
    uint256 public calls_withdraw;
    uint256 public calls_setSender;
    uint256 public calls_block;
    uint256 public calls_sponsor;
    uint256 public calls_sponsorAttempt;
    uint256 public calls_sponsorSkipSender0;
    uint256 public calls_sponsorSkipPaused;
    uint256 public calls_sponsorSkipEmpty;
    uint256 public calls_fundAfterBlock;
    uint256 public ghost_unauthorizedWriteAccepted;
    uint256 public ghost_denySenderValidated;
    uint256 public ghost_denyWrongReason;
    uint256 public calls_denyChecked;

    constructor(SuperSponsorshipPaymaster p, MockEntryPoint e, address a, address f, address m) {
        paymaster = p;
        ep = e;
        admin = a;
        funder = f;
        manager = m;
        for (uint256 i; i < 4; ++i) {
            strategies[i] = address(uint160(0xA000 + i));
        }
        for (uint256 i; i < 6; ++i) {
            strangers[i] = address(uint160(0xB000 + i));
        }
    }

    function _s(uint256 seed) internal view returns (address) {
        return strategies[seed % 4];
    }

    function _who(uint256 seed) internal view returns (address) {
        return strangers[(seed >> 8) % 6];
    }

    function _markInitialized(address s) internal {
        ghost_initialized[s] = true;
    }

    /*//////////////////////// anyone ////////////////////////*/

    function fundAnyone(uint256 seed, uint256 amount) external {
        address s = _s(seed);
        address who = _who(seed);
        amount = bound(amount, 1, 5 ether);
        vm.deal(who, amount);

        bool wasBlocked = ghost_explicitSet[s] && ghost_explicitValue[s] == address(0);

        vm.prank(who);
        paymaster.fundStrategy{ value: amount }(s);

        ghost_funded[s] += amount;
        _markInitialized(s);
        calls_fund++;
        if (wasBlocked) calls_fundAfterBlock++;
    }

    /// @notice ADVERSARIAL: a stranger attempts every role-gated write. None may succeed.
    function strangerAttemptsRoleGatedWrites(uint256 seed) external {
        address s = _s(seed);
        address who = _who(seed);
        vm.startPrank(who);
        try paymaster.withdrawStrategyFunds(s, who, 1) {
            ghost_unauthorizedWriteAccepted++;
        } catch { }
        try paymaster.creditStrategy(s, 1) {
            ghost_unauthorizedWriteAccepted++;
        } catch { }
        try paymaster.setAllowedSender(s, who) {
            ghost_unauthorizedWriteAccepted++;
        } catch { }
        try paymaster.pauseStrategy(s) {
            ghost_unauthorizedWriteAccepted++;
        } catch { }
        try paymaster.setGlobalPause(true) {
            ghost_unauthorizedWriteAccepted++;
        } catch { }
        vm.stopPrank();
    }

    /*//////////////////////// FUNDING_ROLE ////////////////////////*/

    function depositUnallocated(uint256 amount) external {
        amount = bound(amount, 1, 5 ether);
        vm.deal(address(this), amount);
        ep.depositTo{ value: amount }(address(paymaster));
        ghost_unallocatedDeposited += amount;
    }

    function creditByRole(uint256 seed, uint256 amount) external {
        address s = _s(seed);
        uint256 pool = paymaster.unallocatedBalance();
        if (pool == 0) return;
        amount = bound(amount, 1, pool);

        vm.prank(funder);
        paymaster.creditStrategy(s, amount);

        ghost_credited[s] += amount;
        _markInitialized(s);
        calls_credit++;
    }

    function withdrawByRole(uint256 seed, uint256 amount) external {
        address s = _s(seed);
        uint256 bal = paymaster.getStrategyBudget(s).balance;
        if (bal == 0) return;
        amount = bound(amount, 1, bal);

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(s, address(0xFEE), amount);

        ghost_withdrawn[s] += amount;
        calls_withdraw++;
    }

    /*//////////////////////// MANAGER_ROLE ////////////////////////*/

    function managerSetsSender(uint256 seed, uint8 choice) external {
        address s = _s(seed);
        address[4] memory choices =
            [address(0), address(0xACC), paymaster.DEFAULT_ALLOWED_SENDER(), address(uint160(0xC000 + (seed % 7)))];
        address v = choices[choice % 4];

        vm.prank(manager);
        paymaster.setAllowedSender(s, v);

        ghost_explicitSet[s] = true;
        ghost_explicitValue[s] = v;
        _markInitialized(s);
        calls_setSender++;
        if (v == address(0)) calls_block++;
    }

    function managerPauses(uint256 seed, bool pause) external {
        address s = _s(seed);
        vm.prank(manager);
        // pause one call in four, otherwise unpause: a mostly-paused fleet starves sponsorship
        if (pause && seed % 4 == 0) paymaster.pauseStrategy(s);
        else paymaster.unpauseStrategy(s);
    }

    /*//////////////////////// EntryPoint ////////////////////////*/

    /// @notice Sponsor an op from the strategy's current allowed sender, through validate and
    ///         postOp. When the sender is zero the validation MUST revert; count any that pass.
    function sponsorOp(uint256 seed, uint256 maxCost, uint256 actualCost) external {
        address s = _s(seed);
        calls_sponsorAttempt++;
        if (paymaster.globalPaused()) return;

        address sender = paymaster.allowedSender(s);
        if (sender == address(0)) {
            calls_sponsorSkipSender0++;
            _probeDenial(s);
            return;
        }
        if (paymaster.getStrategyBudget(s).paused) {
            calls_sponsorSkipPaused++;
            return;
        }

        uint256 bal = paymaster.getStrategyBudget(s).balance;
        if (bal == 0) {
            calls_sponsorSkipEmpty++;
            return;
        }
        maxCost = bound(maxCost, 1, bal);
        actualCost = bound(actualCost, 0, maxCost);

        vm.prank(address(ep));
        (bytes memory ctx,) = paymaster.validatePaymasterUserOp(_op(s, sender), bytes32(0), maxCost);
        vm.prank(address(ep));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, actualCost, 0);

        ghost_debited[s] += actualCost; // fee-per-gas 0, so overhead adds nothing
        calls_sponsor++;
    }

    /// @notice ADVERSARIAL + COVERAGE: the manager blocks a strategy, a stranger funds it, and an
    ///         op from the canonical executor must be denied for exactly UNAUTHORIZED_SENDER.
    ///         Makes the denial path reachable on every campaign instead of by luck.
    function blockFundThenProbe(uint256 seed, uint256 amount) external {
        address s = _s(seed);
        vm.prank(manager);
        paymaster.setAllowedSender(s, address(0));
        ghost_explicitSet[s] = true;
        ghost_explicitValue[s] = address(0);
        _markInitialized(s);
        calls_setSender++;
        calls_block++;

        address who = _who(seed);
        amount = bound(amount, 1, 1 ether);
        vm.deal(who, amount);
        vm.prank(who);
        paymaster.fundStrategy{ value: amount }(s);
        ghost_funded[s] += amount;
        calls_fund++;
        calls_fundAfterBlock++;

        if (!paymaster.globalPaused()) _probeDenial(s);

        // Leave the strategy usable again. The block itself is still exercised (and the
        // model records the explicit zero in between), but a persistent block on one of four
        // strategies would starve the sponsor path for the rest of the run.
        address d = paymaster.DEFAULT_ALLOWED_SENDER();
        vm.prank(manager);
        paymaster.setAllowedSender(s, d);
        ghost_explicitValue[s] = d;
        calls_setSender++;
    }

    /// @notice COMPOSITE: a stranger funds, then the EntryPoint sponsors from that budget in the
    ///         same step. Guarantees the sponsor path is exercised on every campaign, whatever
    ///         the fuzzer does to the other strategies.
    function fundThenSponsor(uint256 seed, uint256 amount, uint256 maxCost, uint256 actualCost) external {
        address s = _s(seed);
        address who = _who(seed);
        amount = bound(amount, 1, 5 ether);
        vm.deal(who, amount);
        bool wasBlocked = ghost_explicitSet[s] && ghost_explicitValue[s] == address(0);
        vm.prank(who);
        paymaster.fundStrategy{ value: amount }(s);
        ghost_funded[s] += amount;
        _markInitialized(s);
        calls_fund++;
        if (wasBlocked) calls_fundAfterBlock++;

        address sender = paymaster.allowedSender(s);
        if (sender == address(0) || paymaster.globalPaused() || paymaster.getStrategyBudget(s).paused) return;
        uint256 bal = paymaster.getStrategyBudget(s).balance;
        maxCost = bound(maxCost, 1, bal);
        actualCost = bound(actualCost, 0, maxCost);
        vm.prank(address(ep));
        (bytes memory ctx,) = paymaster.validatePaymasterUserOp(_op(s, sender), bytes32(0), maxCost);
        vm.prank(address(ep));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, actualCost, 0);
        ghost_debited[s] += actualCost;
        calls_sponsor++;
    }

    /// @dev Validation from the canonical executor against a zero-sender strategy must revert with
    ///      UNAUTHORIZED_SENDER. The default is read BEFORE the prank: an external call in the
    ///      argument list would consume the prank, the validation would arrive from this handler,
    ///      and it would revert for the wrong reason while looking like a correct denial.
    function _probeDenial(address s) internal {
        address d = paymaster.DEFAULT_ALLOWED_SENDER();
        PackedUserOperation memory op = _op(s, d);
        vm.prank(address(ep));
        try paymaster.validatePaymasterUserOp(op, bytes32(0), 1) {
            ghost_denySenderValidated++;
        } catch (bytes memory reason) {
            if (bytes4(reason) != ISuperSponsorshipPaymaster.UNAUTHORIZED_SENDER.selector) {
                ghost_denyWrongReason++;
            }
            calls_denyChecked++;
        }
    }

    function _op(address strategy, address sender) internal view returns (PackedUserOperation memory op) {
        op.sender = sender;
        op.callData = abi.encodeWithSelector(bytes4(0x4fb2fbd5), strategy, bytes(""));
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(100_000), uint128(150_000)));
        op.preVerificationGas = 50_000;
        op.gasFees = bytes32(abi.encodePacked(uint128(10 gwei), uint128(500 gwei)));
        op.paymasterAndData = abi.encodePacked(address(paymaster), uint128(100_000), uint128(50_000), strategy);
    }

    function strategyAt(uint256 i) external view returns (address) {
        return strategies[i];
    }
}

/*//////////////////////////////////////////////////////////////
                            INVARIANTS
//////////////////////////////////////////////////////////////*/

/// @notice Properties of permissionless funding and the sender state machine, under random
///         interleavings of strangers, the two roles, and the EntryPoint.
contract SuperSponsorshipPaymasterInvariantTest is StdInvariant, Test {
    SuperSponsorshipPaymaster internal paymaster;
    MockEntryPoint internal ep;
    PaymasterHandler internal handler;

    address internal admin = makeAddr("admin");
    address internal funder = makeAddr("funder");
    address internal manager = makeAddr("manager");

    function setUp() public {
        ep = new MockEntryPoint();
        paymaster = new SuperSponsorshipPaymaster(IEntryPoint(address(ep)), admin, address(new MockSuperVaultAggregator()));
        vm.startPrank(admin);
        paymaster.grantRole(paymaster.FUNDING_ROLE(), funder);
        paymaster.grantRole(paymaster.MANAGER_ROLE(), manager);
        vm.stopPrank();
        vm.deal(address(ep), 1000 ether);

        handler = new PaymasterHandler(paymaster, ep, admin, funder, manager);
        targetContract(address(handler));
    }

    /// @notice Sum of budgets equals totalAllocated, always.
    function invariant_totalAllocatedEqualsSumOfBudgets() public view {
        uint256 sum;
        for (uint256 i; i < 4; ++i) {
            sum += paymaster.getStrategyBudget(handler.strategyAt(i)).balance;
        }
        assertEq(sum, paymaster.totalAllocated());
    }

    /// @notice The EntryPoint deposit always covers every budget; funding by strangers cannot
    ///         create allocation without a matching deposit.
    function invariant_entryPointDepositCoversAllocation() public view {
        assertGe(ep.balanceOf(address(paymaster)), paymaster.totalAllocated());
        assertEq(
            ep.balanceOf(address(paymaster)),
            paymaster.totalAllocated() + paymaster.unallocatedBalance(),
            "deposit = allocated + unallocated"
        );
    }

    /// @notice Per strategy: balance == funded + credited - withdrawn - debited.
    function invariant_perStrategyConservation() public view {
        for (uint256 i; i < 4; ++i) {
            address s = handler.strategyAt(i);
            ISuperSponsorshipPaymaster.StrategyBudget memory b = paymaster.getStrategyBudget(s);
            assertEq(
                b.balance,
                handler.ghost_funded(s) + handler.ghost_credited(s) - handler.ghost_withdrawn(s)
                    - handler.ghost_debited(s),
                "budget conservation"
            );
            assertEq(b.totalDebited, handler.ghost_debited(s), "debit ledger");
        }
    }

    /// @notice Never configured means deny: an uninitialized strategy has a zero sender.
    function invariant_uninitializedMeansDeny() public view {
        for (uint256 i; i < 4; ++i) {
            address s = handler.strategyAt(i);
            if (!paymaster.senderInitialized(s)) {
                assertEq(paymaster.allowedSender(s), address(0));
            }
        }
    }

    /// @notice The sender equals the model: the manager's last explicit value if any, else the
    ///         default once funded or credited, else zero.
    function invariant_senderMatchesModel() public view {
        for (uint256 i; i < 4; ++i) {
            address s = handler.strategyAt(i);
            address expected = handler.ghost_explicitSet(s)
                ? handler.ghost_explicitValue(s)
                : (handler.ghost_initialized(s) ? paymaster.DEFAULT_ALLOWED_SENDER() : address(0));
            assertEq(paymaster.allowedSender(s), expected, "sender model");
            assertEq(paymaster.senderInitialized(s), handler.ghost_initialized(s), "flag model");
        }
    }

    /// @notice A manager's block (explicit zero) is never re-armed by funding or crediting.
    function invariant_managerBlockSurvivesFunding() public view {
        for (uint256 i; i < 4; ++i) {
            address s = handler.strategyAt(i);
            if (handler.ghost_explicitSet(s) && handler.ghost_explicitValue(s) == address(0)) {
                assertEq(paymaster.allowedSender(s), address(0), "block re-armed");
            }
        }
    }

    /// @notice Initialization never reverts to false.
    function invariant_initializedIsMonotonic() public view {
        for (uint256 i; i < 4; ++i) {
            address s = handler.strategyAt(i);
            if (handler.ghost_initialized(s)) assertTrue(paymaster.senderInitialized(s));
        }
    }

    /// @notice No stranger ever succeeds at a role-gated write, and no op is ever validated for a
    ///         strategy whose sender is zero.
    function invariant_strangersCannotWriteAndDenyIsDeny() public view {
        assertEq(handler.ghost_unauthorizedWriteAccepted(), 0, "role gate breached");
        assertEq(handler.ghost_denySenderValidated(), 0, "zero sender validated an op");
        assertEq(handler.ghost_denyWrongReason(), 0, "denial must be UNAUTHORIZED_SENDER, not an unrelated revert");
    }

    /// @notice Coverage floor: the campaign must have exercised every path these invariants
    ///         depend on, including funding AFTER a manager block.
    function afterInvariant() public {
        emit log_named_uint("calls_fund", handler.calls_fund());
        emit log_named_uint("calls_credit", handler.calls_credit());
        emit log_named_uint("calls_withdraw", handler.calls_withdraw());
        emit log_named_uint("calls_setSender", handler.calls_setSender());
        emit log_named_uint("calls_block", handler.calls_block());
        emit log_named_uint("calls_sponsor", handler.calls_sponsor());
        emit log_named_uint("calls_sponsorAttempt", handler.calls_sponsorAttempt());
        emit log_named_uint("calls_sponsorSkipSender0", handler.calls_sponsorSkipSender0());
        emit log_named_uint("calls_sponsorSkipPaused", handler.calls_sponsorSkipPaused());
        emit log_named_uint("calls_sponsorSkipEmpty", handler.calls_sponsorSkipEmpty());
        emit log_named_uint("calls_fundAfterBlock", handler.calls_fundAfterBlock());
        emit log_named_uint("calls_denyChecked", handler.calls_denyChecked());
        assertGt(handler.calls_fund(), 0, "never funded");
        assertGt(handler.calls_credit(), 0, "never credited");
        assertGt(handler.calls_withdraw(), 0, "never withdrew");
        assertGt(handler.calls_setSender(), 0, "manager never wrote");
        assertGt(handler.calls_block(), 0, "manager never blocked");
        assertGt(handler.calls_sponsor(), 0, "never sponsored an op");
        assertGt(handler.calls_fundAfterBlock(), 0, "never funded a blocked strategy");
        assertGt(handler.calls_denyChecked(), 0, "never exercised a zero-sender denial");
    }
}
