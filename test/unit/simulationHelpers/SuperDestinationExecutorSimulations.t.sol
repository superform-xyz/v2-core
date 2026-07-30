// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { ISuperDestinationExecutor } from "../../../src/interfaces/ISuperDestinationExecutor.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import {
    SuperDestinationExecutorSimulations
} from "../../mocks/simulationHelpers/SuperDestinationExecutorSimulations.sol";

import {
    AcceptingDestinationValidator,
    DestinationSimulationTestBase,
    RecordingERC7579Account
} from "./DestinationSimulationTestBase.sol";

contract SuperDestinationExecutorSimulationsTest is DestinationSimulationTestBase {
    bytes32 internal constant ROOT = keccak256("executor-root");

    SuperDestinationExecutorSimulations internal executor;
    AcceptingDestinationValidator internal validator;
    RecordingERC7579Account internal account;
    MockERC20 internal token;

    function setUp() public {
        validator = new AcceptingDestinationValidator();
        executor = new SuperDestinationExecutorSimulations(address(0xCAFE), address(validator));
        account = new RecordingERC7579Account();
        token = new MockERC20("Mock Token", "MOCK", 18);
    }

    function test_ProcessBridgedExecution_HappyPathMarksRoot() public {
        bytes memory signatureData = _executorSignatureData(ROOT);

        executor.processBridgedExecution(
            address(token),
            address(account),
            new address[](0),
            new uint256[](0),
            bytes(""),
            _validExecutorCalldata(),
            signatureData
        );

        assertEq(account.callCount(), 1);
        assertTrue(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function test_ProcessBridgedExecution_RevertIf_IntentAmountIsZero() public {
        bytes memory signatureData = _executorSignatureData(ROOT);

        vm.expectRevert(
            abi.encodeWithSelector(
                SuperDestinationExecutorSimulations.INVALID_INTENT_AMOUNT.selector, address(account), address(token)
            )
        );
        executor.processBridgedExecution(
            address(token),
            address(account),
            _singleAddress(address(token)),
            _singleUint(0),
            bytes(""),
            _validExecutorCalldata(),
            signatureData
        );

        assertFalse(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function test_ProcessBridgedExecution_RevertIf_ERC20BalanceIsInsufficient() public {
        bytes memory signatureData = _executorSignatureData(ROOT);

        vm.expectRevert(
            abi.encodeWithSelector(
                SuperDestinationExecutorSimulations.INSUFFICIENT_ACCOUNT_BALANCE.selector,
                address(account),
                address(token),
                1,
                0
            )
        );
        executor.processBridgedExecution(
            address(token),
            address(account),
            _singleAddress(address(token)),
            _singleUint(1),
            bytes(""),
            _validExecutorCalldata(),
            signatureData
        );

        assertFalse(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function test_ProcessBridgedExecution_RevertIf_NativeBalanceIsInsufficient() public {
        bytes memory signatureData = _executorSignatureData(ROOT);

        vm.expectRevert(
            abi.encodeWithSelector(
                SuperDestinationExecutorSimulations.INSUFFICIENT_ACCOUNT_BALANCE.selector,
                address(account),
                address(0),
                1,
                0
            )
        );
        executor.processBridgedExecution(
            address(0),
            address(account),
            _singleAddress(address(0)),
            _singleUint(1),
            bytes(""),
            _validExecutorCalldata(),
            signatureData
        );

        assertFalse(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function test_ProcessBridgedExecution_RevertIf_RootAlreadyUsed() public {
        bytes32[] memory roots = new bytes32[](1);
        roots[0] = ROOT;
        vm.prank(address(account));
        executor.markRootsAsUsed(roots);

        vm.expectRevert(ISuperDestinationExecutor.MERKLE_ROOT_ALREADY_USED.selector);
        executor.processBridgedExecution(
            address(token),
            address(account),
            new address[](0),
            new uint256[](0),
            bytes(""),
            _validExecutorCalldata(),
            _executorSignatureData(ROOT)
        );
    }

    function test_ProcessBridgedExecution_RevertIf_NoExecutableHooks() public {
        address[] memory hooks = new address[](0);
        bytes[] memory hookData = new bytes[](0);
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookData });
        bytes memory emptyExecution = abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));

        vm.expectRevert(SuperDestinationExecutorSimulations.INVALID_EXECUTOR_CALLDATA.selector);
        executor.processBridgedExecution(
            address(token),
            address(account),
            new address[](0),
            new uint256[](0),
            bytes(""),
            emptyExecution,
            _executorSignatureData(ROOT)
        );

        assertFalse(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function test_ProcessBridgedExecution_RevertIf_WrongExecutorSelector() public {
        bytes memory wrongCalldata = bytes.concat(bytes4(keccak256("wrongFunction(bytes)")), new bytes(300));

        vm.expectRevert(SuperDestinationExecutorSimulations.INVALID_EXECUTOR_CALLDATA.selector);
        executor.processBridgedExecution(
            address(token),
            address(account),
            new address[](0),
            new uint256[](0),
            bytes(""),
            wrongCalldata,
            _executorSignatureData(ROOT)
        );

        assertFalse(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function test_ProcessBridgedExecution_AccountRevertRollsBackRoot() public {
        account.setShouldRevert(true);

        vm.expectRevert(RecordingERC7579Account.MOCK_ACCOUNT_EXECUTION_REVERTED.selector);
        executor.processBridgedExecution(
            address(token),
            address(account),
            new address[](0),
            new uint256[](0),
            bytes(""),
            _validExecutorCalldata(),
            _executorSignatureData(ROOT)
        );

        assertFalse(executor.isMerkleRootUsed(address(account), ROOT));
    }

    function _executorSignatureData(bytes32 root) private view returns (bytes memory) {
        return _signatureData(
            address(account),
            address(executor),
            new address[](0),
            new uint256[](0),
            _validExecutorCalldata(),
            uint64(block.chainid),
            root
        );
    }

    function _validExecutorCalldata() private pure returns (bytes memory) {
        address[] memory hooks = new address[](1);
        hooks[0] = address(0xBEEF);
        bytes[] memory hookData = new bytes[](1);
        hookData[0] = hex"01";

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookData });
        return abi.encodeCall(ISuperExecutor.execute, (abi.encode(entry)));
    }
}
