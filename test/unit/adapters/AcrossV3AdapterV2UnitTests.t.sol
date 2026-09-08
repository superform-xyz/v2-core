// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AcrossV3AdapterV2 } from "../../../src/adapters/AcrossV3AdapterV2.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import {
    DestinationSimulationTestBase,
    RecordingDestinationExecutor
} from "../simulationHelpers/DestinationSimulationTestBase.sol";

contract AcrossV2MockSpokePool {
    using SafeERC20 for IERC20;

    error ALREADY_FILLED();

    mapping(bytes32 relayId => bool isFilled) public filled;

    function fill(bytes32 relayId, address adapter, address token, uint256 amount, bytes memory message) external {
        if (filled[relayId]) revert ALREADY_FILLED();

        filled[relayId] = true;
        IERC20(token).safeTransferFrom(msg.sender, adapter, amount);
        IAcrossV3Receiver(adapter).handleV3AcrossMessage(token, amount, msg.sender, message);
    }
}

contract AcrossV2MockDestinationExecutor {
    enum ExecutionMode {
        Success,
        EmptyRevert,
        CustomError,
        ReturnBomb,
        OutOfGas,
        ShortRevert
    }

    error MOCK_EXECUTION_FAILED();

    ExecutionMode public executionMode;
    uint256 public callCount;

    /// @dev Matches the default validator used by _signatureData
    function SUPER_DESTINATION_VALIDATOR() external pure returns (address) {
        return address(0xFACE);
    }

    function setExecutionMode(ExecutionMode mode) external {
        executionMode = mode;
    }

    function processBridgedExecution(
        address,
        address,
        address[] memory,
        uint256[] memory,
        bytes memory,
        bytes memory,
        bytes memory
    )
        external
    {
        ExecutionMode mode = executionMode;

        if (mode == ExecutionMode.EmptyRevert) {
            assembly ("memory-safe") {
                revert(0, 0)
            }
        }
        if (mode == ExecutionMode.CustomError) revert MOCK_EXECUTION_FAILED();
        if (mode == ExecutionMode.ReturnBomb) revert(string(new bytes(100_000)));
        if (mode == ExecutionMode.OutOfGas) {
            assembly ("memory-safe") {
                for { } 1 { } { }
            }
        }
        if (mode == ExecutionMode.ShortRevert) {
            // 2 bytes of revert data — shorter than a selector
            assembly ("memory-safe") {
                mstore8(0, 0xde)
                mstore8(1, 0xad)
                revert(0, 2)
            }
        }

        ++callCount;
    }
}

contract AcrossV3AdapterV2UnitTests is DestinationSimulationTestBase {
    bytes32 internal constant RELAY_ID = keccak256("relay-id");
    bytes32 internal constant ROOT = keccak256("root");
    uint256 internal constant AMOUNT = 1000e18;
    bytes4 internal constant ERROR_STRING_SELECTOR = bytes4(keccak256("Error(string)"));

    AcrossV2MockSpokePool internal spokePool;
    AcrossV2MockDestinationExecutor internal executor;
    AcrossV3AdapterV2 internal adapter;
    MockERC20 internal token;

    address internal relayer;
    address internal account;

    function setUp() public {
        relayer = makeAddr("relayer");
        account = makeAddr("account");

        spokePool = new AcrossV2MockSpokePool();
        executor = new AcrossV2MockDestinationExecutor();
        adapter = new AcrossV3AdapterV2(address(spokePool), address(executor));
        token = new MockERC20("Across Test Token", "ATT", 18);

        token.mint(relayer, AMOUNT);
        vm.prank(relayer);
        token.approve(address(spokePool), AMOUNT);
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(AcrossV3AdapterV2.ADDRESS_NOT_VALID.selector);
        new AcrossV3AdapterV2(address(0), address(executor));

        vm.expectRevert(AcrossV3AdapterV2.ADDRESS_NOT_VALID.selector);
        new AcrossV3AdapterV2(address(spokePool), address(0));
    }

    function test_Fill_SucceedsAndExecutes() public {
        vm.expectEmit(true, true, false, true, address(adapter));
        emit AcrossV3AdapterV2.TransferSucceeded(account, address(token), AMOUNT);

        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 1);
    }

    function test_Fill_RevertIf_CallerNotSpokePool() public {
        vm.prank(makeAddr("notSpokePool"));
        vm.expectRevert(IAcrossV3Receiver.INVALID_SENDER.selector);
        adapter.handleV3AcrossMessage(address(token), AMOUNT, relayer, _buildMessage());
    }

    function test_Fill_RevertIf_NoDstProofForChain() public {
        bytes memory message = _buildMessage(account, address(executor), uint64(block.chainid) + 1);

        vm.expectRevert(AcrossV3AdapterV2.NO_DST_PROOF_FOR_CHAIN.selector);
        _fillWithMessage(RELAY_ID, message);

        _assertRolledBackFill();
    }

    function test_Fill_RevertIf_AccountIsZero() public {
        bytes memory message = _buildMessage(address(0), address(executor), uint64(block.chainid));

        vm.expectRevert(AcrossV3AdapterV2.ACCOUNT_NOT_VALID.selector);
        _fillWithMessage(RELAY_ID, message);

        _assertRolledBackFill();
    }

    function test_Fill_RevertIf_SignedExecutorMismatch() public {
        bytes memory message = _buildMessage(account, makeAddr("wrongExecutor"), uint64(block.chainid));

        vm.expectRevert(AcrossV3AdapterV2.EXECUTOR_NOT_VALID.selector);
        _fillWithMessage(RELAY_ID, message);

        _assertRolledBackFill();
    }

    function test_Fill_RevertIf_TransferReturnsFalse() public {
        vm.mockCall(address(token), abi.encodeCall(IERC20.transfer, (account, AMOUNT)), abi.encode(false));

        vm.expectRevert(AcrossV3AdapterV2.TRANSFER_FAILED.selector);
        _fill(RELAY_ID);
        vm.clearMockedCalls();

        _assertRolledBackFill();
    }

    function test_Fill_RevertIf_TransferReverts() public {
        vm.mockCallRevert(
            address(token),
            abi.encodeCall(IERC20.transfer, (account, AMOUNT)),
            abi.encodeWithSignature("Error(string)", "transfer failed")
        );

        vm.expectRevert(AcrossV3AdapterV2.TRANSFER_FAILED.selector);
        _fill(RELAY_ID);
        vm.clearMockedCalls();

        _assertRolledBackFill();
    }

    function test_Fill_RevertIf_ExecutorHasNoCode() public {
        vm.etch(address(executor), "");

        vm.expectRevert(AcrossV3AdapterV2.DESTINATION_EXECUTION_FAILED.selector);
        _fill(RELAY_ID);
    }

    function test_Fill_RevertIf_SignedValidatorMismatch() public {
        bytes memory sigData = _signatureData(
            account,
            address(executor),
            makeAddr("wrongValidator"),
            _singleAddress(address(token)),
            _singleUint(AMOUNT),
            hex"deadbeef",
            uint64(block.chainid),
            ROOT
        );

        vm.expectRevert(AcrossV3AdapterV2.VALIDATOR_NOT_VALID.selector);
        _fillWithMessage(RELAY_ID, abi.encode(hex"1234", sigData));

        _assertRolledBackFill();
    }

    function test_Fill_ForwardsExactArgumentsToExecutor() public {
        RecordingDestinationExecutor recorder = new RecordingDestinationExecutor();
        AcrossV3AdapterV2 recordingAdapter = new AcrossV3AdapterV2(address(spokePool), address(recorder));
        bytes memory sigData = _signatureData(
            account,
            address(recorder),
            _singleAddress(address(token)),
            _singleUint(AMOUNT),
            hex"deadbeef",
            uint64(block.chainid),
            ROOT
        );

        vm.prank(relayer);
        spokePool.fill(RELAY_ID, address(recordingAdapter), address(token), AMOUNT, abi.encode(hex"1234", sigData));

        assertEq(recorder.callCount(), 1);
        assertEq(
            recorder.lastCallHash(),
            keccak256(
                abi.encode(
                    address(token),
                    account,
                    _singleAddress(address(token)),
                    _singleUint(AMOUNT),
                    hex"1234",
                    hex"deadbeef",
                    sigData
                )
            )
        );
    }

    function test_Fill_RevertAtomicallyIf_ExecutorFailsWithoutData() public {
        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.EmptyRevert);

        vm.expectRevert(AcrossV3AdapterV2.DESTINATION_EXECUTION_FAILED.selector);
        _fill(RELAY_ID);

        _assertRolledBackFill();
    }

    function test_Fill_RevertAtomicallyOnOutOfGasAndCanRetry() public {
        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.OutOfGas);

        vm.expectRevert(AcrossV3AdapterV2.DESTINATION_EXECUTION_FAILED.selector);
        _fillWithGas(RELAY_ID, 2_000_000);
        _assertRolledBackFill();

        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.Success);
        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 1);
    }

    function test_Fill_SucceedsIf_ExecutorReturnsCustomError() public {
        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.CustomError);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit AcrossV3AdapterV2.ExecutionFailed(account, AcrossV2MockDestinationExecutor.MOCK_EXECUTION_FAILED.selector);

        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 0);
    }

    function test_Fill_ExecutorShortRevertDataEmitsZeroSelector() public {
        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.ShortRevert);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit AcrossV3AdapterV2.ExecutionFailed(account, bytes4(0));

        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 0);
    }

    function test_Fill_UsesFirstMatchingDstProof() public {
        address secondAccount = makeAddr("secondAccount");

        ISuperValidator.DstProof[] memory proofs = new ISuperValidator.DstProof[](3);
        proofs[0] = _dstProof(makeAddr("otherChainAccount"), address(executor), uint64(block.chainid) + 1);
        proofs[1] = _dstProof(account, address(executor), uint64(block.chainid));
        proofs[2] = _dstProof(secondAccount, address(executor), uint64(block.chainid));

        _fillWithMessage(RELAY_ID, abi.encode(hex"1234", _encodeSigData(proofs)));

        _assertSuccessfulFill();
        assertEq(token.balanceOf(secondAccount), 0);
        assertEq(executor.callCount(), 1);
    }

    function test_Fill_RevertIf_TokenHasNoCode() public {
        address noCodeToken = makeAddr("noCodeToken");

        vm.prank(address(spokePool));
        vm.expectRevert(AcrossV3AdapterV2.TRANSFER_FAILED.selector);
        adapter.handleV3AcrossMessage(noCodeToken, AMOUNT, relayer, _buildMessage());
    }

    function test_Fill_RevertIf_MalformedMessage() public {
        vm.prank(address(spokePool));
        vm.expectRevert();
        adapter.handleV3AcrossMessage(address(token), AMOUNT, relayer, hex"deadbeef");
    }

    function testFuzz_Fill_DeliversExactAmount(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        address fuzzRelayer = makeAddr("fuzzRelayer");
        token.mint(fuzzRelayer, amount);

        vm.startPrank(fuzzRelayer);
        token.approve(address(spokePool), amount);
        spokePool.fill(RELAY_ID, address(adapter), address(token), amount, _buildMessage());
        vm.stopPrank();

        assertEq(token.balanceOf(account), amount);
        assertEq(token.balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 1);
    }

    function test_Fill_ExecutorReturnBombRemainsBestEffort() public {
        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.ReturnBomb);

        vm.expectEmit(true, false, false, true, address(adapter));
        emit AcrossV3AdapterV2.ExecutionFailed(account, ERROR_STRING_SELECTOR);

        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 0);
    }

    function _fill(bytes32 relayId) internal {
        _fillWithMessage(relayId, _buildMessage());
    }

    function _fillWithMessage(bytes32 relayId, bytes memory message) internal {
        vm.prank(relayer);
        spokePool.fill(relayId, address(adapter), address(token), AMOUNT, message);
    }

    function _fillWithGas(bytes32 relayId, uint256 gasLimit) internal {
        vm.prank(relayer);
        spokePool.fill{ gas: gasLimit }(relayId, address(adapter), address(token), AMOUNT, _buildMessage());
    }

    function _assertSuccessfulFill() internal view {
        assertTrue(spokePool.filled(RELAY_ID));
        assertEq(token.balanceOf(relayer), 0);
        assertEq(token.allowance(relayer, address(spokePool)), 0);
        assertEq(token.balanceOf(account), AMOUNT);
        assertEq(token.balanceOf(address(adapter)), 0);
    }

    function _assertRolledBackFill() internal view {
        assertFalse(spokePool.filled(RELAY_ID));
        assertEq(token.balanceOf(relayer), AMOUNT);
        assertEq(token.allowance(relayer, address(spokePool)), AMOUNT);
        assertEq(token.balanceOf(account), 0);
        assertEq(token.balanceOf(address(adapter)), 0);
        assertEq(executor.callCount(), 0);
    }

    function _buildMessage() internal view returns (bytes memory) {
        return _buildMessage(account, address(executor), uint64(block.chainid));
    }

    function _buildMessage(address account_, address executor_, uint64 chainId_) internal view returns (bytes memory) {
        bytes memory sigData = _signatureData(
            account_, executor_, _singleAddress(address(token)), _singleUint(AMOUNT), hex"deadbeef", chainId_, ROOT
        );
        return abi.encode(hex"1234", sigData);
    }

    function _dstProof(
        address account_,
        address executor_,
        uint64 chainId_
    )
        internal
        view
        returns (ISuperValidator.DstProof memory)
    {
        return ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: chainId_,
            info: ISuperValidator.DstInfo({
                account: account_,
                executor: executor_,
                dstTokens: _singleAddress(address(token)),
                intentAmounts: _singleUint(AMOUNT),
                validator: address(0xFACE),
                data: hex"deadbeef"
            })
        });
    }

    function _encodeSigData(ISuperValidator.DstProof[] memory proofs) internal pure returns (bytes memory) {
        uint64[] memory destinationChains = new uint64[](proofs.length);
        for (uint256 i; i < proofs.length; ++i) {
            destinationChains[i] = proofs[i].dstChainId;
        }

        return abi.encode(
            destinationChains, uint48(type(uint48).max), uint48(0), ROOT, new bytes32[](0), proofs, new bytes(65)
        );
    }
}
