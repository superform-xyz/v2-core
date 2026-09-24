// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { TransferSpec } from "evm-gateway/lib/TransferSpec.sol";

import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { CircleGatewayAdapter } from "../../../src/adapters/CircleGatewayAdapter.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperSenderCreator } from "../../../src/executors/helpers/SuperSenderCreator.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";
import { SuperValidatorBase } from "../../../src/validators/SuperValidatorBase.sol";

import { MockHook } from "../../mocks/MockHook.sol";
import {
    ExecutingERC7579Account,
    HookLifecycleTarget
} from "../../unit/simulationHelpers/AcrossDestinationExecutionE2E.t.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";
import { GatewayAttestationHelpers, IGatewayMinterLive, IFiatTokenBlacklist } from "./GatewayAttestationHelpers.sol";

/// @dev Account factory the real SuperSenderCreator forwards to: deploys a fresh ERC-7579 account WITH both modules
///      installed and returns it. The executor requires the returned address to equal the signed `account`.
contract Account7579Factory {
    function deploy(address validator, address owner, address executor) external returns (address) {
        ExecutingERC7579Account a = new ExecutingERC7579Account();
        a.installModule(MODULE_TYPE_VALIDATOR, validator, abi.encode(owner));
        a.installModule(MODULE_TYPE_EXECUTOR, executor, bytes(""));
        return address(a);
    }
}

/// @dev Hook execution target that can be toggled to revert, so the real executor's `_execute` fails.
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

/// @title CircleGatewayAdapterRealExecutorE2E
/// @author Superform Labs
/// @notice Circle-style attestation (test signer enrolled on the REAL GatewayMinter) -> `CircleGatewayAdapter`
///         -> the REAL `SuperDestinationExecutor` + `SuperDestinationValidator` on a Base fork, with a real owner
///         signature. Proves the intent leg end to end: a valid signature executes hooks and consumes the root, a
///         DstProof for another deployment is delivered-but-skipped, a tampered intent is delivered and the real
///         validator's INVALID_PROOF is caught (root preserved), undecodable hookData is rejected BEFORE the mint
///         (spec unused, re-attestable), a real Base-USDC blacklist turns delivery into escrow that clears on
///         unblacklist, a first-time account is created through initData, a failed execution is re-driven directly
///         on the executor, and a stray zero-caller mint is recovered with the real intent executed.
contract CircleGatewayAdapterRealExecutorE2E is GatewayAttestationHelpers, MerkleTreeHelper {
    uint64 constant CHAINID_BASE = 8453;
    uint48 constant VALID_UNTIL = type(uint48).max;
    uint256 constant AMOUNT = 1000e6;

    address internal depositor = makeAddr("depositor");
    address internal owner;
    uint256 internal ownerPk;

    SuperDestinationValidator internal validator;
    SuperDestinationExecutor internal executor;
    CircleGatewayAdapter internal adapter;
    ExecutingERC7579Account internal account;
    HookLifecycleTarget internal lifecycleTarget;
    MockHook internal hook;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("accountOwner");
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));

        validator = new SuperDestinationValidator();
        executor = new SuperDestinationExecutor(address(new SuperLedgerConfiguration()), address(validator));
        adapter = new CircleGatewayAdapter(GATEWAY_MINTER, USDC_BASE, address(executor));
        _enrollSigner();

        account = new ExecutingERC7579Account();
        account.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(owner));
        account.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));

        lifecycleTarget = new HookLifecycleTarget();
        hook = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC_BASE);
        Execution[] memory hookExecutions = new Execution[](1);
        hookExecutions[0] = Execution({
            target: address(lifecycleTarget), value: 0, callData: abi.encodeCall(HookLifecycleTarget.execute, ())
        });
        hook.setExecutions(hookExecutions);
    }

    /*//////////////////////////////////////////////////////////////
                              INTENT LEG
    //////////////////////////////////////////////////////////////*/

    /// @notice A genuinely signed intent: real USDC minted and delivered, hooks executed by the account, root
    ///         consumed, nothing resting, no ExecutionFailed.
    function test_Real_ValidSignature_ExecutesHooksAndConsumesRoot() public {
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, address(executor));
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(payload, sig);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC delivered");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter empty");
        assertTrue(hook.preExecuteCalled() && hook.postExecuteCalled(), "hook lifecycle ran");
        assertEq(lifecycleTarget.callCount(), 1, "hook execution reached the target");
        assertEq(lifecycleTarget.lastCaller(), address(account), "executed by the account");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
    }

    /// @notice The signed DstProof names a DIFFERENT executor: funds delivered, execution skipped
    ///         (DestinationTargetMismatch code 1), root untouched.
    function test_Real_DstProofNamesOtherExecutor_DeliversAndSkipsExecution() public {
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, makeAddr("otherExecutor"));
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(payload, sig);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC still delivered");
        assertEq(lifecycleTarget.callCount(), 0, "no execution attempted");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root untouched");
        assertEq(_mismatchCode(logs), 1, "MISMATCH_EXECUTOR");
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
    }

    /// @notice intentAmounts in the payload differ from the signed leaf: the adapter delivers, the REAL validator
    ///         rejects the proof inside the executor, the adapter catches it and the root stays unused.
    function test_Real_TamperedIntentAmounts_DeliversButProofFails_RootPreserved() public {
        bytes memory cd = _executorCalldata();
        bytes32 root = _root(cd, AMOUNT);
        bytes memory hookData = _hookData(cd, AMOUNT - 1, address(executor), root, _sign(root));
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(payload, sig);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC delivered best-effort");
        assertEq(lifecycleTarget.callCount(), 0, "tampered intent must not execute");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root preserved for a legit retry");
        assertEq(
            _executionFailedSelector(logs),
            SuperValidatorBase.INVALID_PROOF.selector,
            "the REAL validator's INVALID_PROOF surfaced through the executor"
        );
    }

    /// @notice A root signed by the WRONG key (valid proof, forged signer): the REAL validator recovers the signer,
    ///         it is not the account owner, the executor reverts INVALID_SIGNATURE, the adapter catches it — funds
    ///         delivered, nothing executed, root preserved. Closes the negative-signature path the tampered-intent
    ///         test cannot reach (it fails earlier at the merkle proof).
    function test_Real_ForgedSigner_DeliversButRejected_RootPreserved() public {
        (, uint256 thiefPk) = makeAddrAndKey("thief");
        bytes memory cd = _executorCalldata();
        bytes32 root = _root(cd, AMOUNT);
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(thiefPk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        bytes memory hookData = _hookData(cd, AMOUNT, address(executor), root, abi.encodePacked(r, s, v));
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(payload, sig);

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC delivered best-effort");
        assertEq(lifecycleTarget.callCount(), 0, "forged signer must not execute");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root preserved");
        assertEq(
            _executionFailedSelector(vm.getRecordedLogs()),
            ISuperDestinationExecutor.INVALID_SIGNATURE.selector,
            "the REAL validator rejected the signer"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    FAIL-FAST PRE-MINT (NO FUNDS LOST)
    //////////////////////////////////////////////////////////////*/

    /// @notice Garbage hookData on a Circle-signed attestation is rejected BEFORE the mint: the minter never saw
    ///         it (hash unused), so the user re-attests with a correct payload and nothing was lost.
    function test_Real_UndecodableHookData_RejectedPreMint_ThenReattested() public {
        (TransferSpec memory bad, bytes memory badPayload) = _attestSpec(address(adapter), hex"deadbeef");
        vm.expectRevert(CircleGatewayAdapter.HOOK_PAYLOAD_INVALID.selector);
        adapter.receiveAndExecute(badPayload, _gwSign(badPayload));
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(bad)), "spec unused");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "nothing minted");

        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, address(executor));
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);
        adapter.receiveAndExecute(payload, sig);
        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "re-attested payload delivered");
        assertTrue(executor.isMerkleRootUsed(address(account), root));
    }

    /// @notice A permissionless caller starving the executor hits the floor: the whole relay unwinds, the spec is
    ///         NOT consumed on the real minter, and the same attestation relays with enough gas.
    function test_Real_GasFloor_UnwindsMint_ThenRetriable() public {
        (bytes memory hookData,) = _signedHookData(_executorCalldata(), AMOUNT, address(executor));
        (TransferSpec memory s, bytes memory payload) = _attestSpec(address(adapter), hookData);
        bytes memory sig = _gwSign(payload);

        // Budget assumption: parse + real gatewayMint (cold storage) + transfer fit inside 1.5M so the 2M floor is
        // what reverts, not a bare OOG. Re-check if the live minter's cost drifts.
        vm.expectRevert(CircleGatewayAdapter.INSUFFICIENT_GAS.selector);
        adapter.receiveAndExecute{ gas: 1_500_000 }(payload, sig);
        assertFalse(IGatewayMinterLive(GATEWAY_MINTER).isTransferSpecHashUsed(_gwHash(s)), "mint unwound");

        adapter.receiveAndExecute(payload, sig);
        assertEq(lifecycleTarget.callCount(), 1, "relayed with enough gas");
    }

    /*//////////////////////////////////////////////////////////////
                        ESCROW ON A REAL BLACKLIST
    //////////////////////////////////////////////////////////////*/

    /// @notice REAL Base USDC blacklist: delivery to a blacklisted account reverts inside FiatToken, the adapter
    ///         escrows instead of reverting the relay (the spec is consumed — the funds exist), the execution
    ///         attempt fails harmlessly (caught), and after unblacklisting the account claims. Nothing is stranded.
    function test_Real_BlacklistedAccount_EscrowsThenClaimsAfterUnblacklist() public {
        address victim = makeAddr("victim");
        bytes memory hookData =
            abi.encode(bytes(""), _executorCalldata(), victim, _one(USDC_BASE), _one(AMOUNT), bytes("sig"));
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);

        IFiatTokenBlacklist usdc = IFiatTokenBlacklist(USDC_BASE);
        vm.prank(usdc.blacklister());
        usdc.blacklist(victim);

        vm.recordLogs();
        adapter.receiveAndExecute(payload, sig);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(victim), 0, "FiatToken refused the transfer");
        assertEq(adapter.failedTransfers(victim, USDC_BASE), AMOUNT, "escrowed for the account");
        assertEq(adapter.totalEscrowed(USDC_BASE), AMOUNT);
        _assertAdapterEvent(logs, keccak256("TransferFailed(address,address,uint256)"));
        // execution was attempted: the REAL executor validates the account BEFORE its balance gate, so for a
        // plain address (no code, no initData) it reverts ACCOUNT_NOT_CREATED and the adapter catches it
        assertEq(
            _executionFailedSelector(logs), ISuperDestinationExecutor.ACCOUNT_NOT_CREATED.selector, "caught selector"
        );

        vm.prank(usdc.blacklister());
        usdc.unBlacklist(victim);
        vm.prank(victim);
        adapter.claimFailedTransfer(USDC_BASE, AMOUNT);
        assertEq(IERC20(USDC_BASE).balanceOf(victim), AMOUNT, "claimed after unblacklist");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter empty");
        assertEq(adapter.totalEscrowed(USDC_BASE), 0);
    }

    /*//////////////////////////////////////////////////////////////
                  FIRST-TIME ACCOUNT, RE-DRIVE, RECOVERY
    //////////////////////////////////////////////////////////////*/

    /// @notice First-time user: hookData carries initData (senderCreator ++ factory ++ calldata); the REAL
    ///         executor creates the account via SuperSenderCreator and the signed intent executes on it.
    function test_Real_FirstTimeAccount_CreatedViaInitData_ThenExecutes() public {
        SuperSenderCreator creator = new SuperSenderCreator();
        Account7579Factory factory = new Account7579Factory();
        address predicted = vm.computeCreateAddress(address(factory), 1);
        assertEq(predicted.code.length, 0, "account must not exist yet");

        bytes memory cd = _executorCalldata();
        bytes32 root = _rootFor(predicted, cd, AMOUNT);
        bytes memory initData = abi.encodePacked(
            address(creator),
            address(factory),
            abi.encodeCall(Account7579Factory.deploy, (address(validator), owner, address(executor)))
        );
        bytes memory hookData = abi.encode(
            initData,
            cd,
            predicted,
            _one(USDC_BASE),
            _one(AMOUNT),
            _sigData(_dstProofsFor(predicted, cd, AMOUNT), root, _sign(root))
        );
        (bytes memory payload, bytes memory sig) = _attest(address(adapter), hookData);

        adapter.receiveAndExecute(payload, sig);

        assertGt(predicted.code.length, 0, "account created by the executor");
        assertEq(IERC20(USDC_BASE).balanceOf(predicted), AMOUNT, "USDC delivered to the new account");
        assertEq(lifecycleTarget.callCount(), 1, "hooks executed by the new account");
        assertEq(lifecycleTarget.lastCaller(), predicted);
        assertTrue(executor.isMerkleRootUsed(predicted, root), "root consumed");
    }

    /// @notice A failed execution (hook reverts) is recoverable WITHOUT the adapter: funds are at the account, the
    ///         root is unused, the payload is public — re-drive `processBridgedExecution` directly.
    function test_Real_ExecutorRevert_ReDriveDirectlyOnExecutor() public {
        (TogglableTarget togglable, bytes memory cd) = _revertingHookCalldata();
        bytes32 root = _root(cd, AMOUNT);
        (bytes memory payload, bytes memory sig) =
            _attest(address(adapter), _hookData(cd, AMOUNT, address(executor), root, _sign(root)));

        vm.recordLogs();
        adapter.receiveAndExecute(payload, sig);
        assertEq(
            _executionFailedSelector(vm.getRecordedLogs()),
            bytes4(keccak256("Error(string)")),
            "bounded selector of the hook's revert surfaced"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "funds at the account");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root unused");
        assertEq(togglable.callCount(), 0);

        togglable.setShouldRevert(false);
        _redriveDirectly(cd, root);
        assertEq(togglable.callCount(), 1, "re-driven directly on the executor");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /// @notice A zero-caller spec minted directly on the real minter by a third party: `recoverDirectMint`
    ///         (keyed on the minter's used-hash record) forwards the stranded USDC and executes the REAL signed
    ///         intent — the user ends up exactly where the relay would have put them.
    function test_Real_StrayZeroCallerMint_RecoveredAndIntentExecuted() public {
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, address(executor));
        TransferSpec memory s = _gwSpec(address(adapter), address(0), USDC_BASE, depositor, AMOUNT, hookData);
        bytes memory payload = _gwEncode(s);
        bytes memory sig = _gwSign(payload);

        vm.prank(makeAddr("thirdParty"));
        IGatewayMinterLive(GATEWAY_MINTER).gatewayMint(payload, sig);
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), AMOUNT, "stranded");

        adapter.recoverDirectMint(payload);

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "delivered");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0);
        assertEq(lifecycleTarget.callCount(), 1, "intent executed");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _attest(
        address recipient,
        bytes memory hookData
    )
        internal
        returns (bytes memory payload, bytes memory sig)
    {
        (, payload) = _attestSpec(recipient, hookData);
        sig = _gwSign(payload);
    }

    function _attestSpec(
        address recipient,
        bytes memory hookData
    )
        internal
        returns (TransferSpec memory s, bytes memory payload)
    {
        s = _gwSpec(recipient, address(adapter), USDC_BASE, depositor, AMOUNT, hookData);
        payload = _gwEncode(s);
    }

    function _revertingHookCalldata() internal returns (TogglableTarget togglable, bytes memory cd) {
        togglable = new TogglableTarget();
        MockHook badHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC_BASE);
        Execution[] memory ex = new Execution[](1);
        ex[0] =
            Execution({ target: address(togglable), value: 0, callData: abi.encodeCall(TogglableTarget.execute, ()) });
        badHook.setExecutions(ex);
        togglable.setShouldRevert(true);
        cd = _executorCalldataFor(address(badHook));
    }

    function _redriveDirectly(bytes memory cd, bytes32 root) internal {
        executor.processBridgedExecution(
            USDC_BASE,
            address(account),
            _one(USDC_BASE),
            _one(AMOUNT),
            bytes(""),
            cd,
            _sigData(_dstProofsFor(address(account), cd, AMOUNT), root, _sign(root))
        );
    }

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

    function _root(bytes memory executorCalldata, uint256 minimum) internal view returns (bytes32) {
        return _rootFor(address(account), executorCalldata, minimum);
    }

    function _rootFor(address acct, bytes memory executorCalldata, uint256 minimum) internal view returns (bytes32) {
        return _createDestinationValidatorLeaf(
            executorCalldata,
            CHAINID_BASE,
            acct,
            address(executor),
            _one(USDC_BASE),
            _one(minimum),
            VALID_UNTIL,
            address(validator)
        );
    }

    function _sign(bytes32 root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        return abi.encodePacked(r, s, v);
    }

    function _hookData(
        bytes memory executorCalldata,
        uint256 minimum,
        address proofExecutor,
        bytes32 root,
        bytes memory signature
    )
        internal
        view
        returns (bytes memory)
    {
        ISuperValidator.DstProof[] memory proofs = new ISuperValidator.DstProof[](1);
        proofs[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: CHAINID_BASE,
            info: ISuperValidator.DstInfo({
                account: address(account),
                executor: proofExecutor,
                dstTokens: _one(USDC_BASE),
                intentAmounts: _one(minimum),
                validator: address(validator),
                data: executorCalldata
            })
        });
        return abi.encode(
            bytes(""),
            executorCalldata,
            address(account),
            _one(USDC_BASE),
            _one(minimum),
            _sigData(proofs, root, signature)
        );
    }

    function _sigData(
        ISuperValidator.DstProof[] memory proofs,
        bytes32 root,
        bytes memory signature
    )
        internal
        pure
        returns (bytes memory)
    {
        uint64[] memory chains = new uint64[](1);
        chains[0] = CHAINID_BASE;
        return abi.encode(chains, VALID_UNTIL, uint48(0), root, new bytes32[](0), proofs, signature);
    }

    function _dstProofsFor(
        address acct,
        bytes memory executorCalldata,
        uint256 minimum
    )
        internal
        view
        returns (ISuperValidator.DstProof[] memory proofs)
    {
        proofs = new ISuperValidator.DstProof[](1);
        proofs[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: CHAINID_BASE,
            info: ISuperValidator.DstInfo({
                account: acct,
                executor: address(executor),
                dstTokens: _one(USDC_BASE),
                intentAmounts: _one(minimum),
                validator: address(validator),
                data: executorCalldata
            })
        });
    }

    function _signedHookData(
        bytes memory executorCalldata,
        uint256 minimum,
        address proofExecutor
    )
        internal
        view
        returns (bytes memory hookData, bytes32 root)
    {
        root = _root(executorCalldata, minimum);
        hookData = _hookData(executorCalldata, minimum, proofExecutor, root, _sign(root));
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
            if (logs[i].emitter == address(adapter) && logs[i].topics.length != 0 && logs[i].topics[0] == topic) {
                return;
            }
        }
        revert("expected adapter event not emitted");
    }

    function _mismatchCode(Vm.Log[] memory logs) internal view returns (uint8) {
        bytes32 topic = keccak256("DestinationTargetMismatch(address,uint8)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length != 0 && logs[i].topics[0] == topic) {
                return abi.decode(logs[i].data, (uint8));
            }
        }
        revert("DestinationTargetMismatch not emitted");
    }

    function _executionFailedSelector(Vm.Log[] memory logs) internal view returns (bytes4) {
        bytes32 topic = keccak256("ExecutionFailed(address,bytes4)");
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length != 0 && logs[i].topics[0] == topic) {
                return abi.decode(logs[i].data, (bytes4));
            }
        }
        revert("ExecutionFailed not emitted");
    }

    function _assertNoAdapterEvent(Vm.Log[] memory logs, bytes32 topic) internal view {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length != 0 && logs[i].topics[0] == topic) {
                revert("unexpected adapter event");
            }
        }
    }
}
