// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Vm } from "forge-std/Vm.sol";

import { SuperLedgerConfiguration } from "../../../src/accounting/SuperLedgerConfiguration.sol";
import { AcrossV3AdapterV2 } from "../../../src/adapters/AcrossV3AdapterV2.sol";
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

/// @title AcrossV3AdapterV2ValidSigE2E
/// @notice E2E with a VALID owner signature through the production adapter and the REAL
///         SuperDestinationExecutor + SuperDestinationValidator: the success path executes hooks
///         and consumes the merkle root; a tampered message fails signature validation with the
///         real INVALID_PROOF selector surfaced in ExecutionFailed.
contract AcrossV3AdapterV2ValidSigE2E is MerkleTreeHelper {
    uint256 internal constant AMOUNT = 1_000_000;
    uint48 internal constant VALID_UNTIL = type(uint48).max;

    address internal spokePool;
    address internal owner;
    uint256 internal ownerPk;

    SuperDestinationValidator internal validator;
    SuperDestinationExecutor internal executor;
    AcrossV3AdapterV2 internal adapter;
    ExecutingERC7579Account internal account;
    HookLifecycleTarget internal lifecycleTarget;
    MockHook internal hook;
    MockERC20 internal token;

    function setUp() public {
        spokePool = makeAddr("acrossSpokePool");
        (owner, ownerPk) = makeAddrAndKey("accountOwner");

        token = new MockERC20("Mock Token", "MOCK", 18);
        lifecycleTarget = new HookLifecycleTarget();
        hook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(token));

        validator = new SuperDestinationValidator();
        executor = new SuperDestinationExecutor(address(new SuperLedgerConfiguration()), address(validator));
        adapter = new AcrossV3AdapterV2(spokePool, address(executor));

        account = new ExecutingERC7579Account();
        account.installModule(MODULE_TYPE_VALIDATOR, address(validator), abi.encode(owner));
        account.installModule(MODULE_TYPE_EXECUTOR, address(executor), bytes(""));

        Execution[] memory hookExecutions = new Execution[](1);
        hookExecutions[0] = Execution({
            target: address(lifecycleTarget), value: 0, callData: abi.encodeCall(HookLifecycleTarget.execute, ())
        });
        hook.setExecutions(hookExecutions);
    }

    function test_E2E_ValidSignature_ExecutesHooksAndConsumesRoot() public {
        (bytes memory message, bytes32 root) = _signedMessage(_executorCalldata());
        token.mint(address(adapter), AMOUNT);

        vm.recordLogs();
        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), message);

        assertEq(token.balanceOf(address(account)), AMOUNT, "Tokens delivered to account");
        assertEq(token.balanceOf(address(adapter)), 0, "Adapter empty");
        assertTrue(hook.preExecuteCalled(), "Hook preExecute ran");
        assertTrue(hook.postExecuteCalled(), "Hook postExecute ran");
        assertEq(lifecycleTarget.callCount(), 1, "Hook execution reached target");
        assertEq(lifecycleTarget.lastCaller(), address(account), "Target called by the account");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "Merkle root consumed");
        _assertNoExecutionFailed(vm.getRecordedLogs());
    }

    function test_E2E_TamperedIntentAmounts_FailProofWithSelectorAndPreserveRoot() public {
        bytes memory executorCalldata = _executorCalldata();
        bytes32 root = _signedRoot(executorCalldata, _singleUint(AMOUNT));
        // Message claims a different intent amount than the signed leaf — proof must fail
        bytes memory message = _message(executorCalldata, _singleUint(AMOUNT - 1), root, _sign(root));
        token.mint(address(adapter), AMOUNT);

        vm.recordLogs();
        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), message);

        assertEq(token.balanceOf(address(account)), AMOUNT, "Tokens still delivered best-effort");
        assertEq(lifecycleTarget.callCount(), 0, "Tampered intent must not execute");
        assertFalse(executor.isMerkleRootUsed(address(account), root), "Root preserved for legit retry");
        assertEq(
            _findExecutionFailedSelector(vm.getRecordedLogs()),
            SuperValidatorBase.INVALID_PROOF.selector,
            "ExecutionFailed carries the real validator's revert selector"
        );
    }

    function test_E2E_ValidSignature_RetryAfterTamperStillExecutes() public {
        bytes memory executorCalldata = _executorCalldata();
        bytes32 root = _signedRoot(executorCalldata, _singleUint(AMOUNT));
        bytes memory tampered = _message(executorCalldata, _singleUint(AMOUNT - 1), root, _sign(root));

        token.mint(address(adapter), AMOUNT);
        vm.prank(spokePool);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, makeAddr("relayer"), tampered);
        assertEq(lifecycleTarget.callCount(), 0, "Tampered fill must not execute");

        // The untampered intent remains executable: permissionless retry directly on the executor
        ISuperValidator.DstProof[] memory proofs = _dstProofs(executorCalldata, _singleUint(AMOUNT));
        executor.processBridgedExecution(
            address(token),
            address(account),
            _singleAddress(address(token)),
            _singleUint(AMOUNT),
            bytes(""),
            executorCalldata,
            _sigData(proofs, root, _sign(root))
        );

        assertEq(lifecycleTarget.callCount(), 1, "Legit intent executed on retry");
        assertTrue(executor.isMerkleRootUsed(address(account), root), "Root consumed by retry");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executorCalldata() internal view returns (bytes memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = address(hook);
        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hex"01";

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hooksData });
        return abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));
    }

    /// @dev Leaf over the REAL destination tuple; single-leaf tree → root == leaf, empty proof
    function _signedRoot(bytes memory executorCalldata, uint256[] memory intentAmounts)
        internal
        view
        returns (bytes32)
    {
        return _createDestinationValidatorLeaf(
            executorCalldata,
            uint64(block.chainid),
            address(account),
            address(executor),
            _singleAddress(address(token)),
            intentAmounts,
            VALID_UNTIL,
            address(validator)
        );
    }

    function _sign(bytes32 root) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(validator.namespace(), root));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, MessageHashUtils.toEthSignedMessageHash(messageHash));
        return abi.encodePacked(r, s, v);
    }

    function _dstProofs(
        bytes memory executorCalldata,
        uint256[] memory intentAmounts
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
                account: address(account),
                executor: address(executor),
                dstTokens: _singleAddress(address(token)),
                intentAmounts: intentAmounts,
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

    function _message(
        bytes memory executorCalldata,
        uint256[] memory intentAmounts,
        bytes32 root,
        bytes memory signature
    )
        internal
        view
        returns (bytes memory)
    {
        return abi.encode(bytes(""), _sigData(_dstProofs(executorCalldata, intentAmounts), root, signature));
    }

    function _signedMessage(bytes memory executorCalldata) internal view returns (bytes memory message, bytes32 root) {
        root = _signedRoot(executorCalldata, _singleUint(AMOUNT));
        message = _message(executorCalldata, _singleUint(AMOUNT), root, _sign(root));
    }

    function _singleAddress(address value) internal pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = value;
    }

    function _singleUint(uint256 value) internal pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }

    function _findExecutionFailedSelector(Vm.Log[] memory logs) internal view returns (bytes4) {
        bytes32 topic = keccak256("ExecutionFailed(address,bytes4)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                return abi.decode(logs[i].data, (bytes4));
            }
        }
        revert("ExecutionFailed not emitted by adapter");
    }

    function _assertNoExecutionFailed(Vm.Log[] memory logs) internal view {
        bytes32 topic = keccak256("ExecutionFailed(address,bytes4)");
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter == address(adapter) && logs[i].topics.length > 0 && logs[i].topics[0] == topic) {
                revert("Unexpected ExecutionFailed");
            }
        }
    }
}
