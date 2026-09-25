// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { IMessageTransmitterV2 } from "@pigeon/cctp/interfaces/IMessageTransmitterV2.sol";

import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { CCTPAdapter } from "../../../src/adapters/CCTPAdapter.sol";
import { SuperDestinationExecutor } from "../../../src/executors/SuperDestinationExecutor.sol";
import { SuperSenderCreator } from "../../../src/executors/helpers/SuperSenderCreator.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { SuperDestinationValidator } from "../../../src/validators/SuperDestinationValidator.sol";

import { MockHook } from "../../mocks/MockHook.sol";
import {
    ExecutingERC7579Account,
    HookLifecycleTarget
} from "../../unit/simulationHelpers/AcrossDestinationExecutionE2E.t.sol";
import { MerkleTreeHelper } from "../../utils/MerkleTreeHelper.sol";

interface ITokenMessengerV2Call {
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    )
        external;
}

interface IFiatTokenBlacklist {
    function blacklister() external view returns (address);
    function blacklist(address account) external;
    function unBlacklist(address account) external;
}

/// @dev Account factory the real SuperSenderCreator forwards to: deploys a fresh ERC-7579 account WITH both modules
///      installed (the validator's onInstall then runs with the account as msg.sender) and returns it. The executor
///      requires the returned address to equal the signed `account`, which the test predicts via CREATE.
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

/// @title CCTPAdapterRealExecutorE2E
/// @author Superform Labs
/// @notice Real burn on Ethereum -> real Circle message + attestation -> `CCTPAdapter` -> the REAL
///         `SuperDestinationExecutor` + `SuperDestinationValidator` on a Base fork, with a real owner
///         signature. Every other CCTP suite drives a mock executor; this one proves the intent leg:
///         a valid signature executes hooks and consumes the root, a DstProof for another deployment is
///         delivered-but-skipped, a tampered intent is delivered and the real validator's INVALID_PROOF
///         is caught (root preserved), undecodable hookData / account 0 escrow to the attested burner
///         who can claim, and a real Base-USDC blacklist turns delivery into escrow that clears on
///         unblacklist.
contract CCTPAdapterRealExecutorE2E is Test, MerkleTreeHelper {
    address constant TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
    address constant MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;
    address constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint32 constant DOMAIN_BASE = 6;
    uint64 constant CHAINID_BASE = 8453;
    bytes32 constant MESSAGE_SENT_TOPIC = keccak256("MessageSent(bytes)");
    uint256 constant ATTESTER_PK = 0xA11CE;
    uint48 constant VALID_UNTIL = type(uint48).max;
    uint256 constant AMOUNT = 1000e6;

    uint256 internal ethFork;
    uint256 internal baseFork;

    address internal depositor = makeAddr("depositor"); // the attested `messageSender`
    address internal owner;
    uint256 internal ownerPk;

    SuperDestinationValidator internal validator;
    SuperDestinationExecutor internal executor;
    CCTPAdapter internal adapter;
    ExecutingERC7579Account internal account;
    HookLifecycleTarget internal lifecycleTarget;
    MockHook internal hook;

    function setUp() public {
        (owner, ownerPk) = makeAddrAndKey("accountOwner");

        // --- Destination (Base) first: the adapter and account addresses go into the burn ---
        baseFork = vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        validator = new SuperDestinationValidator();
        executor = new SuperDestinationExecutor(address(new SuperLedgerConfiguration()), address(validator));
        adapter = new CCTPAdapter(MESSAGE_TRANSMITTER_V2, TOKEN_MESSENGER_V2, USDC_BASE, address(executor));

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

        // --- Source (Ethereum) ---
        ethFork = vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));
    }

    /*//////////////////////////////////////////////////////////////
                              INTENT LEG
    //////////////////////////////////////////////////////////////*/

    /// @notice A real burn carrying a genuinely signed intent: USDC delivered, hooks executed by the account,
    ///         root consumed, nothing resting, no ExecutionFailed.
    function test_Real_ValidSignature_ExecutesHooksAndConsumesRoot() public {
        vm.selectFork(baseFork); // the intent is signed against Base-side contracts (validator.namespace())
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, address(executor));
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC delivered");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter empty");
        assertTrue(hook.preExecuteCalled() && hook.postExecuteCalled(), "hook lifecycle ran");
        assertEq(lifecycleTarget.callCount(), 1, "hook execution reached the target");
        assertEq(lifecycleTarget.lastCaller(), address(account), "executed by the account");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
    }

    /// @notice The signed DstProof names a DIFFERENT executor: funds are delivered and execution is skipped
    ///         (DestinationTargetMismatch code 1); the root is untouched. A revert here would strand the burn.
    function test_Real_DstProofNamesOtherExecutor_DeliversAndSkipsExecution() public {
        vm.selectFork(baseFork); // the intent is signed against Base-side contracts (validator.namespace())
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, makeAddr("otherExecutor"));
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC still delivered");
        assertEq(lifecycleTarget.callCount(), 0, "no execution attempted");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root untouched");
        _assertAdapterEvent(logs, keccak256("DestinationTargetMismatch(address,uint8)"));
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
    }

    /// @notice intentAmounts in the message differ from the signed leaf: the adapter delivers, the REAL validator
    ///         rejects the proof inside the executor, the adapter catches it (ExecutionFailed) and the root stays
    ///         unused — authenticity failure on the intent leg never costs the bridged funds.
    function test_Real_TamperedIntentAmounts_DeliversButProofFails_RootPreserved() public {
        vm.selectFork(baseFork); // the intent is signed against Base-side contracts (validator.namespace())
        bytes memory cd = _executorCalldata();
        bytes32 root = _root(cd, AMOUNT);
        // message claims AMOUNT - 1 while the leaf was signed over AMOUNT
        bytes memory hookData = _hookData(cd, AMOUNT - 1, address(executor), root, _sign(root));
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hookData);

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "USDC delivered best-effort");
        assertEq(lifecycleTarget.callCount(), 0, "tampered intent must not execute");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root preserved for a legit retry");
        _assertAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
    }

    /*//////////////////////////////////////////////////////////////
                        ESCROW PATHS ON REAL ATTESTATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Garbage hookData on a real attested burn: escrowed to the attested burner (the EOA that called
    ///         depositForBurnWithHook), who claims it on Base.
    function test_Real_UndecodableHookData_EscrowsToBurner_WhoClaims() public {
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hex"deadbeef");

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        _assertAdapterEvent(vm.getRecordedLogs(), keccak256("HookPayloadUndecodable(address,uint256)"));

        assertEq(adapter.failedTransfers(depositor, USDC_BASE), AMOUNT, "escrowed to the attested burner");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), AMOUNT, "held pending claim");

        vm.prank(depositor);
        adapter.claimFailedTransfer(USDC_BASE, AMOUNT);
        assertEq(IERC20(USDC_BASE).balanceOf(depositor), AMOUNT, "burner recovered the funds on Base");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter empty");
    }

    /// @notice A decodable payload naming account 0 takes the same escrow path.
    function test_Real_AccountZero_EscrowsToBurner() public {
        bytes memory hookData = _hookData(_executorCalldata(), AMOUNT, address(executor), bytes32(0), new bytes(65));
        // overwrite the account (3rd tuple element) with zero by re-encoding
        hookData = abi.encode(bytes(""), _executorCalldata(), address(0), _one(USDC_BASE), _one(AMOUNT), bytes("sig"));
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hookData);

        adapter.receiveAndExecute(message, attestation);

        assertEq(adapter.failedTransfers(depositor, USDC_BASE), AMOUNT, "escrowed to the burner");
        assertEq(lifecycleTarget.callCount(), 0, "no execution");
    }

    /// @notice REAL Base USDC blacklist: delivery to a blacklisted account reverts inside FiatToken, the
    ///         adapter escrows instead of reverting the relay, execution is attempted and fails harmlessly,
    ///         and after unblacklisting the account claims. Nothing is stranded.
    function test_Real_BlacklistedAccount_EscrowsThenClaimsAfterUnblacklist() public {
        address victim = makeAddr("victim"); // plain address: the point is FiatToken's own transfer gate
        bytes memory hookData =
            abi.encode(bytes(""), _executorCalldata(), victim, _one(USDC_BASE), _one(AMOUNT), bytes("sig"));
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hookData);

        IFiatTokenBlacklist usdc = IFiatTokenBlacklist(USDC_BASE);
        vm.prank(usdc.blacklister());
        usdc.blacklist(victim);

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(victim), 0, "FiatToken refused the transfer");
        assertEq(adapter.failedTransfers(victim, USDC_BASE), AMOUNT, "escrowed for the account");
        _assertAdapterEvent(logs, keccak256("TransferFailed(address,address,uint256)"));

        vm.prank(usdc.blacklister());
        usdc.unBlacklist(victim);
        vm.prank(victim);
        adapter.claimFailedTransfer(USDC_BASE, AMOUNT);
        assertEq(IERC20(USDC_BASE).balanceOf(victim), AMOUNT, "claimed after unblacklist");
        assertEq(IERC20(USDC_BASE).balanceOf(address(adapter)), 0, "adapter empty");
    }

    /*//////////////////////////////////////////////////////////////
                    T1: FIRST-TIME ACCOUNT, FAST FEE, RE-DRIVE
    //////////////////////////////////////////////////////////////*/

    /// @notice First-time user: the account does not exist yet. hookData carries initData (senderCreator ++
    ///         factory ++ calldata); the REAL executor creates it via SuperSenderCreator, the validator is
    ///         installed by the new account itself, the signed intent (over the predicted address) executes.
    function test_Real_FirstTimeAccount_CreatedViaInitData_ThenExecutes() public {
        vm.selectFork(baseFork);
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
        (bytes memory message, bytes memory attestation) = _bridgeToBase(AMOUNT, hookData);

        adapter.receiveAndExecute(message, attestation);

        assertGt(predicted.code.length, 0, "account created by the executor");
        assertEq(IERC20(USDC_BASE).balanceOf(predicted), AMOUNT, "USDC delivered to the new account");
        assertEq(lifecycleTarget.callCount(), 1, "hooks executed by the new account");
        assertEq(lifecycleTarget.lastCaller(), predicted, "executed by the created account");
        assertTrue(executor.isMerkleRootUsed(predicted, root), "root consumed");
    }

    /// @notice Fast transfer: the attestation stamps feeExecuted, Circle mints amount - fee. An intent sized
    ///         against amount - maxFee (as the SDK must) still executes.
    function test_Real_FastTransferFee_IntentSizedAgainstMaxFee_Executes() public {
        vm.selectFork(baseFork);
        uint256 maxFee = 2e6;
        uint256 fee = 1e6;
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT - maxFee, address(executor));
        (bytes memory message, bytes memory attestation) = _bridgeToBaseWithFee(AMOUNT, hookData, maxFee, 1000, fee);

        adapter.receiveAndExecute(message, attestation);

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT - fee, "amount minus the executed fee delivered");
        assertEq(lifecycleTarget.callCount(), 1, "executed: delivered >= signed minimum");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /// @notice CONTROL: an intent naively sized at the full amount silently no-ops on a fast transfer (executor
    ///         balance gate), leaving the root unused and the USDC idle at the account — no ExecutionFailed.
    function test_Real_FastTransferFee_IntentSizedAtAmount_SilentlyNoOps() public {
        vm.selectFork(baseFork);
        (bytes memory hookData, bytes32 root) = _signedHookData(_executorCalldata(), AMOUNT, address(executor));
        (bytes memory message, bytes memory attestation) = _bridgeToBaseWithFee(AMOUNT, hookData, 2e6, 1000, 1e6);

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT - 1e6, "delivered minus fee");
        assertEq(lifecycleTarget.callCount(), 0, "not executed: below the signed minimum");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root unused");
        _assertNoAdapterEvent(logs, keccak256("ExecutionFailed(address,bytes4)"));
    }

    /// @notice A failed execution (hook reverts) is recoverable WITHOUT the adapter: funds are at the account,
    ///         the root is unused, the payload is public — re-drive `processBridgedExecution` directly.
    ///         Also pins the bounded selector surfaced by ExecutionFailed (review I1 / I2).
    function test_Real_ExecutorRevert_ReDriveDirectlyOnExecutor() public {
        vm.selectFork(baseFork);
        (TogglableTarget togglable, bytes memory cd) = _revertingHookCalldata();
        bytes32 root = _root(cd, AMOUNT);
        (bytes memory message, bytes memory attestation) =
            _bridgeToBase(AMOUNT, _hookData(cd, AMOUNT, address(executor), root, _sign(root)));

        vm.recordLogs();
        adapter.receiveAndExecute(message, attestation);
        assertEq(
            _executionFailedSelector(vm.getRecordedLogs()),
            bytes4(keccak256("Error(string)")),
            "bounded selector of the hook's revert surfaced"
        );
        assertEq(IERC20(USDC_BASE).balanceOf(address(account)), AMOUNT, "funds at the account");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "root unused");
        assertEq(togglable.callCount(), 0, "hook did not run");

        togglable.setShouldRevert(false);
        _redriveDirectly(cd, root);
        assertEq(togglable.callCount(), 1, "re-driven directly on the executor");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "root consumed");
    }

    /// @dev A hook whose execution target reverts until toggled.
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

    /// @dev The recovery path: anyone calls the permissionless executor with the public payload.
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

    /*//////////////////////////////////////////////////////////////
                           INTENT / SIGNATURE HELPERS
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

    /// @dev Leaf over the REAL Base destination tuple (chain id 8453); single-leaf tree => root == leaf.
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

    /// @dev The 6-tuple CCTPSendHook packs into hookData, with sigData carrying a DstProof for Base.
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

    /// @dev DstProof for an arbitrary account (used for the not-yet-created account case).
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

    /*//////////////////////////////////////////////////////////////
                         CCTP BRIDGE + ATTESTATION HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Real depositForBurnWithHook on the Ethereum fork with the given hookData; then on the Base fork
    ///      install a test attester, stamp the nonce/finality the attestation service would, and sign.
    ///      Leaves the Base fork selected. NOTE: the Base-side contracts were deployed BEFORE the Ethereum
    ///      fork was created, so they persist on the Base fork across the switch.
    function _bridgeToBase(
        uint256 amount,
        bytes memory hookData
    )
        internal
        returns (bytes memory message, bytes memory attestation)
    {
        return _bridgeToBaseWithFee(amount, hookData, 0, 2000, 0);
    }

    /// @dev Fast-transfer variant: `maxFee` / `minFinality` go into the burn; `feeExecuted` is what the attestation
    ///      service would stamp at body offset 164 (absolute 312) before signing.
    function _bridgeToBaseWithFee(
        uint256 amount,
        bytes memory hookData,
        uint256 maxFee,
        uint32 minFinality,
        uint256 feeExecuted
    )
        internal
        returns (bytes memory message, bytes memory attestation)
    {
        vm.selectFork(ethFork);
        deal(USDC_ETH, depositor, amount);
        bytes32 adapterB32 = bytes32(uint256(uint160(address(adapter))));

        vm.prank(depositor);
        IERC20(USDC_ETH).approve(TOKEN_MESSENGER_V2, amount);

        vm.recordLogs();
        vm.prank(depositor);
        ITokenMessengerV2Call(TOKEN_MESSENGER_V2)
            .depositForBurnWithHook(
                amount, DOMAIN_BASE, adapterB32, USDC_ETH, adapterB32, maxFee, minFinality, hookData
            );
        message = _extractMessageSent(vm.getRecordedLogs());

        vm.selectFork(baseFork);
        _installAttester();
        _setNonce(message);
        _setFinalityExecuted(message);
        if (feeExecuted != 0) _setFeeExecuted(message, feeExecuted);
        attestation = _signAttestation(message);
    }

    /// @dev BurnMessageV2.feeExecuted at absolute offset 312 (+32 length prefix).
    function _setFeeExecuted(bytes memory message, uint256 fee) internal pure {
        assembly {
            mstore(add(message, 344), fee)
        }
    }

    function _extractMessageSent(Vm.Log[] memory logs) internal pure returns (bytes memory) {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].topics.length != 0 && logs[i].topics[0] == MESSAGE_SENT_TOPIC) {
                return abi.decode(logs[i].data, (bytes));
            }
        }
        revert("no MessageSent");
    }

    function _installAttester() internal {
        IMessageTransmitterV2 t = IMessageTransmitterV2(MESSAGE_TRANSMITTER_V2);
        address attester = vm.addr(ATTESTER_PK);
        vm.startPrank(t.attesterManager());
        if (!t.isEnabledAttester(attester)) t.enableAttester(attester);
        t.setSignatureThreshold(1);
        vm.stopPrank();
    }

    /// @dev Header offset 12: the attestation service assigns the nonce (emitted as 0 at the source).
    function _setNonce(bytes memory message) internal pure {
        bytes32 nonce = keccak256(message);
        assembly {
            mstore(add(message, 44), nonce)
        }
    }

    /// @dev Offsets 140 (min) / 144 (executed): the attestation service fills finalityThresholdExecuted.
    function _setFinalityExecuted(bytes memory message) internal pure {
        assembly {
            let minFinality := shr(224, mload(add(message, 172)))
            let word := mload(add(message, 176))
            word := or(
                and(word, 0x00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffff),
                shl(224, minFinality)
            )
            mstore(add(message, 176), word)
        }
    }

    function _signAttestation(bytes memory message) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ATTESTER_PK, keccak256(message));
        return abi.encodePacked(r, s, v);
    }

    function _assertAdapterEvent(Vm.Log[] memory logs, bytes32 topic) internal view {
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length != 0 && logs[i].topics[0] == topic) {
                return;
            }
        }
        revert("expected adapter event not emitted");
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
