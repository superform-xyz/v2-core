// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Vm } from "forge-std/Vm.sol";

import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { RelayAdapterV2 } from "../../../src/adapters/RelayAdapterV2.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";

import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import {
    ExecutingERC7579Account,
    HookLifecycleTarget
} from "../../unit/simulationHelpers/AcrossDestinationExecutionE2E.t.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";

/// @dev Hook execution target that can be toggled to revert, so the REAL executor's `_execute` reverts and
///      the adapter's `catch` + the executor's rolled-back root mark can be observed.
contract TogglableTarget {
    uint256 public callCount;
    bool public shouldRevert;

    function setShouldRevert(bool v) external {
        shouldRevert = v;
    }

    function execute() external {
        if (shouldRevert) revert("HOOK_TARGET_REVERTED");
        ++callCount;
    }
}

/// @title RelayAdapterV2RealExecutorE2E
/// @author Superform Labs
/// @notice Review-F1 regression matrix through the production adapter and the REAL
///         SuperDestinationExecutor + SuperDestinationValidator, with real owner signatures:
///         `intentAmounts` is the MINIMUM acceptable fill, so fills at or above it must deliver in full
///         AND execute, a fill below it is delivered but not executed (executor balance gate), and a
///         correctly matched fill leaves no unassigned surplus. Also pins the one-shot trade-off: a
///         top-up for the same root cannot come through the adapter; the direct executor path is the
///         recovery route.
/// @dev Same fixture as AcrossV3AdapterV2ValidSigE2E (ExecutingERC7579Account with both modules
///      installed). No spoke-pool prank: `processRelayExecution` is permissionless.
contract RelayAdapterV2RealExecutorE2E is MerkleTreeHelper {
    uint48 internal constant VALID_UNTIL = type(uint48).max;

    address internal owner;
    uint256 internal ownerPk;

    SuperDestinationValidator internal validator;
    SuperDestinationExecutor internal executor;
    RelayAdapterV2 internal adapter;
    ExecutingERC7579Account internal account;
    HookLifecycleTarget internal lifecycleTarget;
    MockHook internal hook;
    MockERC20 internal token;

    // second token + togglable hook for the multi-token and executor-revert scenarios
    MockERC20 internal token2;
    TogglableTarget internal togglable;
    MockHook internal togglableHook;

    // an unrelated user with their own key and account: the S1 "attacker"
    address internal attackerOwner;
    uint256 internal attackerPk;
    ExecutingERC7579Account internal attackerAccount;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("accountOwner");

        token = new MockERC20("Mock Token", "MOCK", 18);
        lifecycleTarget = new HookLifecycleTarget();
        hook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(token));

        validator = new SuperDestinationValidator();
        executor = new SuperDestinationExecutor(address(new SuperLedgerConfiguration()), address(validator));
        adapter = new RelayAdapterV2(address(executor));

        account = new ExecutingERC7579Account();
        account.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(owner));
        account.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));

        Execution[] memory hookExecutions = new Execution[](1);
        hookExecutions[0] = Execution({
            target: address(lifecycleTarget), value: 0, callData: abi.encodeCall(HookLifecycleTarget.execute, ())
        });
        hook.setExecutions(hookExecutions);

        token2 = new MockERC20("Second Token", "TWO", 18);
        togglable = new TogglableTarget();
        togglableHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(token));
        Execution[] memory togglableExecutions = new Execution[](1);
        togglableExecutions[0] =
            Execution({ target: address(togglable), value: 0, callData: abi.encodeCall(TogglableTarget.execute, ()) });
        togglableHook.setExecutions(togglableExecutions);

        (attackerOwner, attackerPk) = makeAddrAndKey("attackerOwner");
        attackerAccount = new ExecutingERC7579Account();
        attackerAccount.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(attackerOwner));
        attackerAccount.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));
    }

    /*//////////////////////////////////////////////////////////////
                    F1: MINIMUM-OUTPUT SEMANTICS (ERC20)
    //////////////////////////////////////////////////////////////*/

    /// @notice Signed minimum 99, solver delivers 100: delivered in full, hooks execute, root consumed,
    ///         nothing rests, no `SpendableBalanceRetained`.
    function test_RealExec_FillAboveSignedMinimum_ExecutesAndConsumesRoot() public {
        (bytes memory message, bytes32 root) = _signed(address(token), 99e18);
        token.mint(address(adapter), 100e18);

        vm.recordLogs();
        adapter.processRelayExecution(address(token), 100e18, message);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(token.balanceOf(address(account)), 100e18, "full fill delivered, not capped at the minimum");
        assertEq(token.balanceOf(address(adapter)), 0, "no unassigned surplus");
        assertEq(lifecycleTarget.callCount(), 1, "hooks executed");
        assertEq(lifecycleTarget.lastCaller(), address(account), "executed by the account");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
        _assertNoAdapterEvent(logs, keccak256("SpendableBalanceRetained(address,uint256)"));
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address)"));
    }

    /// @notice CONTROL: a fill exactly at the signed minimum executes.
    function test_RealExec_ExactMinimum_Executes() public {
        (bytes memory message, bytes32 root) = _signed(address(token), 100e18);
        token.mint(address(adapter), 100e18);

        adapter.processRelayExecution(address(token), 100e18, message);

        assertEq(token.balanceOf(address(account)), 100e18, "delivered");
        assertEq(lifecycleTarget.callCount(), 1, "hooks executed");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /// @notice CONTROL (partial fill): below the minimum the adapter still delivers — it never gates on
    ///         the minimum — and the REAL executor's balance gate declines to execute, leaving the root
    ///         unused. The recovery is a direct top-up to the account plus a permissionless
    ///         `processBridgedExecution`; it does not go through the adapter.
    function test_RealExec_PartialFillBelowMinimum_DeliveredNotExecuted_ThenDirectRecovery() public {
        bytes memory executorCalldata = _executorCalldata();
        bytes32 root = _root(executorCalldata, address(token), 100e18);
        bytes memory message = _message(executorCalldata, address(token), 100e18, root);
        token.mint(address(adapter), 98e18);

        adapter.processRelayExecution(address(token), 98e18, message);

        assertEq(token.balanceOf(address(account)), 98e18, "partial fill delivered by the adapter");
        assertEq(lifecycleTarget.callCount(), 0, "executor balance gate: not executed");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root preserved");

        // Solver (or anyone) tops the account up directly, then re-drives the executor directly.
        token.mint(address(account), 2e18);
        executor.processBridgedExecution(
            address(token),
            address(account),
            _one(address(token)),
            _one(100e18),
            bytes(""),
            executorCalldata,
            _sigData(_dstProofs(executorCalldata, address(token), 100e18), root, _sign(root))
        );

        assertEq(lifecycleTarget.callCount(), 1, "executed once the minimum is met");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed by the direct retry");
    }

    /// @notice ONE-SHOT TRADE-OFF, pinned: after a partial fill, a top-up THROUGH THE ADAPTER under the
    ///         same signed root is rejected. This is deliberate (a replayed signature must not be able to
    ///         drain resting funds after an execution revert rolled the executor's root mark back) and
    ///         the direct path above is the supported recovery.
    function test_RealExec_TopUpThroughAdapterSameRoot_IsRejected() public {
        (bytes memory message,) = _signed(address(token), 100e18);
        token.mint(address(adapter), 98e18);
        adapter.processRelayExecution(address(token), 98e18, message);

        token.mint(address(adapter), 2e18);
        vm.expectRevert(RelayAdapterV2.INTENT_ALREADY_DELIVERED.selector);
        adapter.processRelayExecution(address(token), 2e18, message);
        assertEq(token.balanceOf(address(adapter)), 2e18, "top-up not moved by the adapter");
    }

    /*//////////////////////////////////////////////////////////////
                    F1: MINIMUM-OUTPUT SEMANTICS (NATIVE)
    //////////////////////////////////////////////////////////////*/

    /// @notice Native: signed minimum 0.99, delivered 1.0 — delivered in full and executed.
    function test_RealExec_NativeFillAboveSignedMinimum_Executes() public {
        (bytes memory message, bytes32 root) = _signed(address(0), 0.99 ether);
        vm.deal(address(adapter), 1 ether);

        adapter.processRelayExecution(address(0), 1 ether, message);

        assertEq(address(account).balance, 1 ether, "native fill delivered in full");
        assertEq(address(adapter).balance, 0, "no unassigned surplus");
        assertEq(lifecycleTarget.callCount(), 1, "hooks executed");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /// @notice Native CONTROL: exactly the minimum executes; below it is delivered but not executed.
    function test_RealExec_NativeExactAndPartial() public {
        (bytes memory exact, bytes32 rootExact) = _signed(address(0), 1 ether);
        vm.deal(address(adapter), 1 ether);
        adapter.processRelayExecution(address(0), 1 ether, exact);
        assertEq(lifecycleTarget.callCount(), 1, "exact minimum executed");
        assertTrue(executor.isMerkleRootUsed(address(account), rootExact), "root consumed");

        // a second, distinct intent (different minimum => different root) partially filled. The executor
        // gates on the account's TOTAL balance (1 ether already delivered above), so the minimum is set
        // above 1 + 4 to keep this a genuine under-fill.
        (bytes memory underfill, bytes32 rootUnderfill) = _signed(address(0), 6 ether);
        vm.deal(address(adapter), 4 ether);
        adapter.processRelayExecution(address(0), 4 ether, underfill);
        assertEq(address(account).balance, 5 ether, "partial native fill delivered");
        assertEq(lifecycleTarget.callCount(), 1, "below-minimum native fill not executed");
        assertFalse(executor.isMerkleRootUsed(address(account), rootUnderfill), "root preserved");
    }

    /*//////////////////////////////////////////////////////////////
            S1: RESTING FUNDS ARE NOT SAFE (REAL VALIDATOR + EXECUTOR)
    //////////////////////////////////////////////////////////////*/

    /// @notice Review S1, reproduced against the real stack: a victim's fill rests in the adapter (the
    ///         solver's second leg never came). An unrelated party needs no victim key, no origin deposit
    ///         and no solver role — they sign a fresh intent for their OWN account and are paid the
    ///         victim's funds, with hooks executing for them. A second fresh root drains again: the
    ///         one-shot flag bounds each SIGNATURE, not the pool.
    function test_RealExec_S1_AttackerSelfSignedIntentDrainsRestingFunds() public {
        token.mint(address(adapter), 100e18); // victim's fill, resting

        (bytes memory attack1, bytes32 root1) = _signedFor(attackerAccount, attackerPk, address(token), 1);
        adapter.processRelayExecution(address(token), 100e18, attack1);

        assertEq(token.balanceOf(address(attackerAccount)), 100e18, "victim funds paid to the attacker's account");
        assertTrue(executor.isMerkleRootUsed(address(attackerAccount), root1), "and executed for the attacker");
        assertEq(token.balanceOf(address(adapter)), 0, "pool drained");

        // replay of the same root is the only thing the one-shot flag stops...
        token.mint(address(adapter), 50e18); // another victim
        vm.expectRevert(RelayAdapterV2.INTENT_ALREADY_DELIVERED.selector);
        adapter.processRelayExecution(address(token), 50e18, attack1);

        // ...a fresh self-signed root is a fresh shot
        (bytes memory attack2,) = _signedFor(attackerAccount, attackerPk, address(token), 1);
        adapter.processRelayExecution(address(token), 50e18, attack2);
        assertEq(token.balanceOf(address(attackerAccount)), 150e18, "drained again with a new root");
    }

    /*//////////////////////////////////////////////////////////////
                    EXECUTOR REVERT: WHY THE ONE-SHOT FLAG IS HERE
    //////////////////////////////////////////////////////////////*/

    /// @notice The executor marks the root only right before `_execute`, so a hook revert rolls that mark
    ///         back while the adapter's transfer stays committed. Without the adapter-level flag the same
    ///         signature could draw resting funds again; with it, replay is rejected and — once the hook
    ///         works — a direct `processBridgedExecution` completes the intent (funds already at the
    ///         account).
    function test_RealExec_ExecutorRevert_TransferStays_RootRolledBack_ReplayRejected_DirectRetryWorks() public {
        bytes memory cd = _executorCalldataFor(address(togglableHook));
        bytes32 root = _root(cd, address(token), 100e18);
        bytes memory message = _message(cd, address(token), 100e18, root);
        togglable.setShouldRevert(true);
        token.mint(address(adapter), 100e18);

        vm.recordLogs();
        adapter.processRelayExecution(address(token), 100e18, message);
        _assertAdapterEvent(vm.getRecordedLogs(), keccak256("ExecutionFailed(address)"));

        assertEq(token.balanceOf(address(account)), 100e18, "transfer committed despite the execution revert");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "executor's root mark rolled back");
        assertEq(togglable.callCount(), 0, "hook did not run");

        // replay through the adapter is rejected even though the executor would accept the root again
        token.mint(address(adapter), 100e18); // someone else's resting funds
        vm.expectRevert(RelayAdapterV2.INTENT_ALREADY_DELIVERED.selector);
        adapter.processRelayExecution(address(token), 100e18, message);

        // recovery: fix the hook, drive the executor directly
        togglable.setShouldRevert(false);
        executor.processBridgedExecution(
            address(token),
            address(account),
            _one(address(token)),
            _one(100e18),
            bytes(""),
            cd,
            _sigData(_dstProofsFor(account, cd, _one(address(token)), _one(100e18)), root, _sign(root))
        );
        assertEq(togglable.callCount(), 1, "executed on the direct retry");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /*//////////////////////////////////////////////////////////////
                    AUTHENTICATION BEFORE TRANSFER (vs ACROSS)
    //////////////////////////////////////////////////////////////*/

    /// @notice A message whose `intentAmounts` differ from the signed leaf fails the REAL validator INSIDE
    ///         the adapter, before any transfer: nothing moves and the root is untouched. (The Across
    ///         adapter delivers such a message best-effort and only the execution fails.)
    function test_RealExec_TamperedIntentAmounts_RejectedBeforeTransfer() public {
        bytes memory cd = _executorCalldata();
        bytes32 root = _root(cd, address(token), 100e18);
        bytes memory tampered = _message(cd, address(token), 99e18, root); // claims 99, leaf says 100
        token.mint(address(adapter), 100e18);

        // The real validator REVERTS (INVALID_PROOF) rather than returning a non-magic value; the adapter
        // does not swallow it, so the bubbled selector is the validator's own.
        vm.expectRevert(SuperValidatorBase.INVALID_PROOF.selector);
        adapter.processRelayExecution(address(token), 100e18, tampered);

        assertEq(token.balanceOf(address(account)), 0, "nothing delivered");
        assertEq(token.balanceOf(address(adapter)), 100e18, "funds untouched (solver batch would unwind)");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root untouched");
    }

    /*//////////////////////////////////////////////////////////////
                DOCUMENTED LIMITATION: ONE ADAPTER DELIVERY PER INTENT
    //////////////////////////////////////////////////////////////*/

    /// @notice An intent naming TWO destination tokens, both delivered through THIS adapter under the same
    ///         root: the first delivery lands (not executed — the second token is still short), the second
    ///         is rejected by the one-shot flag. Recovery is direct delivery of the second token plus a
    ///         direct `processBridgedExecution`. Relay quotes are single-output, so two Relay fills for one
    ///         intent is not an expected flow — but if it ever is, this flag is what needs a
    ///         delivery-level redesign (see the contract NatSpec).
    function test_RealExec_Limitation_TwoAdapterFillsForOneMultiTokenIntent_SecondRejected() public {
        bytes memory cd = _executorCalldata();
        address[] memory toks = new address[](2);
        toks[0] = address(token);
        toks[1] = address(token2);
        uint256[] memory mins = new uint256[](2);
        mins[0] = 100e18;
        mins[1] = 50e18;
        bytes32 root = _rootFor(account, cd, toks, mins);
        bytes memory message =
            abi.encode(bytes(""), _sigData(_dstProofsFor(account, cd, toks, mins), root, _sign(root)));

        token.mint(address(adapter), 100e18);
        adapter.processRelayExecution(address(token), 100e18, message);
        assertEq(token.balanceOf(address(account)), 100e18, "first token delivered");
        assertEq(lifecycleTarget.callCount(), 0, "not executed: second token still short");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root preserved");

        token2.mint(address(adapter), 50e18);
        vm.expectRevert(RelayAdapterV2.INTENT_ALREADY_DELIVERED.selector);
        adapter.processRelayExecution(address(token2), 50e18, message);

        // recovery: second token reaches the account directly; executor driven directly
        token2.mint(address(account), 50e18);
        executor.processBridgedExecution(
            address(token),
            address(account),
            toks,
            mins,
            bytes(""),
            cd,
            _sigData(_dstProofsFor(account, cd, toks, mins), root, _sign(root))
        );
        assertEq(lifecycleTarget.callCount(), 1, "executed once both minimums are met");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /*//////////////////////////////////////////////////////////////
                        FUZZ: MINIMUM-OUTPUT INVARIANT
    //////////////////////////////////////////////////////////////*/

    /// @notice INVARIANT on the real stack: the adapter always delivers the full fill, never capped and
    ///         never gated on the minimum; the executor executes iff fill >= minimum; the root is consumed
    ///         iff executed; nothing rests after a matched fill.
    function testFuzz_RealExec_MinimumSemantics(uint96 minimum, uint96 fill) public {
        vm.assume(minimum > 0 && fill > 0);
        (bytes memory message, bytes32 root) = _signed(address(token), minimum);
        token.mint(address(adapter), fill);

        adapter.processRelayExecution(address(token), fill, message);

        bool shouldExecute = fill >= minimum;
        assertEq(token.balanceOf(address(account)), fill, "full fill delivered");
        assertEq(token.balanceOf(address(adapter)), 0, "nothing rests");
        assertEq(lifecycleTarget.callCount(), shouldExecute ? 1 : 0, "executed iff fill >= minimum");
        assertEq(executor.isMerkleRootUsed(address(account), root), shouldExecute, "root used iff executed");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executorCalldata() internal view returns (bytes memory) {
        return _executorCalldataFor(address(hook));
    }

    function _executorCalldataFor(address h) internal pure returns (bytes memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = h;
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hex"01";
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hooksData });
        return abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));
    }

    /// @dev Leaf over the REAL destination tuple; single-leaf tree => root == leaf, empty proof.
    function _root(bytes memory executorCalldata, address tok, uint256 minimum) internal view returns (bytes32) {
        return _rootFor(account, executorCalldata, _one(tok), _one(minimum));
    }

    function _rootFor(
        ExecutingERC7579Account acct,
        bytes memory executorCalldata,
        address[] memory toks,
        uint256[] memory mins
    )
        internal
        view
        returns (bytes32)
    {
        return _createDestinationValidatorLeaf(
            executorCalldata,
            uint64(block.chainid),
            address(acct),
            address(executor),
            toks,
            mins,
            VALID_UNTIL,
            address(validator)
        );
    }

    function _sign(bytes32 root) internal view returns (bytes memory) {
        return _signWith(ownerPk, root);
    }

    function _signWith(uint256 pk, bytes32 root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        return abi.encodePacked(r, s, v);
    }

    /// @dev A genuinely signed single-token message for an arbitrary (account, key) pair.
    function _signedFor(
        ExecutingERC7579Account acct,
        uint256 pk,
        address tok,
        uint256 minimum
    )
        internal
        returns (bytes memory message, bytes32 root)
    {
        // a fresh salt in the executor calldata makes every call a distinct leaf/root
        bytes memory cd = abi.encodePacked(_executorCalldata(), bytes32(uint256(++saltNonce)));
        root = _rootFor(acct, cd, _one(tok), _one(minimum));
        message = abi.encode(
            bytes(""), _sigData(_dstProofsFor(acct, cd, _one(tok), _one(minimum)), root, _signWith(pk, root))
        );
    }

    uint256 internal saltNonce;

    function _dstProofs(
        bytes memory executorCalldata,
        address tok,
        uint256 minimum
    )
        internal
        view
        returns (ISuperValidator.DstProof[] memory proofs)
    {
        return _dstProofsFor(account, executorCalldata, _one(tok), _one(minimum));
    }

    function _dstProofsFor(
        ExecutingERC7579Account acct,
        bytes memory executorCalldata,
        address[] memory toks,
        uint256[] memory mins
    )
        internal
        view
        returns (ISuperValidator.DstProof[] memory proofs)
    {
        proofs = new ISuperValidator.DstProof[](1);
        proofs[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: address(acct),
                executor: address(executor),
                dstTokens: toks,
                intentAmounts: mins,
                validator: address(validator),
                data: executorCalldata
            })
        });
    }

    function _sigData(
        ISuperValidator.DstProof[] memory proofs,
        bytes32 root,
        bytes memory signature
    )
        internal
        view
        returns (bytes memory)
    {
        uint64[] memory chains = new uint64[](1);
        chains[0] = uint64(block.chainid);
        return abi.encode(chains, VALID_UNTIL, uint48(0), root, new bytes32[](0), proofs, signature);
    }

    /// @dev RelayAdapterV2 message = abi.encode(initData, sigData); the account already exists => empty initData.
    function _message(
        bytes memory executorCalldata,
        address tok,
        uint256 minimum,
        bytes32 root
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(bytes(""), _sigData(_dstProofs(executorCalldata, tok, minimum), root, _sign(root)));
    }

    function _signed(address tok, uint256 minimum) internal view returns (bytes memory message, bytes32 root) {
        bytes memory executorCalldata = _executorCalldata();
        root = _root(executorCalldata, tok, minimum);
        message = _message(executorCalldata, tok, minimum, root);
    }

    function _one(address v) internal pure returns (address[] memory a) {
        a = new address[](1);
        a[0] = v;
    }

    function _one(uint256 v) internal pure returns (uint256[] memory a) {
        a = new uint256[](1);
        a[0] = v;
    }

    function _assertAdapterEvent(Vm.Log[] memory logs, bytes32 topic) internal view {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                return;
            }
        }
        revert("expected adapter event not emitted");
    }

    function _assertNoAdapterEvent(Vm.Log[] memory logs, bytes32 topic) internal view {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                revert("unexpected adapter event");
            }
        }
    }
}
