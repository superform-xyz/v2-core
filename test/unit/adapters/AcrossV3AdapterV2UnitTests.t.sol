// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { AcrossV3AdapterV2 } from "../../../src/adapters/AcrossV3AdapterV2.sol";
import { IAcrossV3Receiver } from "../../../src/vendor/bridges/across/IAcrossV3Receiver.sol";
import { ISuperValidator } from "../../../src/interfaces/ISuperValidator.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { Helpers } from "../../utils/Helpers.sol";

contract AcrossV2MockSpokePool {
    using SafeERC20 for IERC20;

    error ALREADY_FILLED();

    mapping(bytes32 relayId => bool isFilled) public filled;

    function fill(
        bytes32 relayId,
        address adapter,
        address token,
        uint256 amount,
        bytes memory message
    )
        external
    {
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
        OutOfGas
    }

    error MOCK_EXECUTION_FAILED();

    ExecutionMode public executionMode;
    uint256 public callCount;

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

        ++callCount;
    }
}

contract AcrossV3AdapterV2UnitTests is Helpers {
    bytes32 internal constant RELAY_ID = keccak256("relay-id");
    uint256 internal constant AMOUNT = 1000e18;

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

    function test_Fill_SucceedsAndExecutes() public {
        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 1);
    }

    function test_Fill_RevertIf_TransferReturnsFalse() public {
        vm.mockCall(address(token), abi.encodeCall(IERC20.transfer, (account, AMOUNT)), abi.encode(false));

        vm.expectRevert(AcrossV3AdapterV2.TRANSFER_FAILED.selector);
        _fill(RELAY_ID);
        vm.clearMockedCalls();

        _assertRolledBackFill();
        assertEq(adapter.failedTransfers(account, address(token)), 0);
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

        vm.expectEmit(true, false, false, false, address(adapter));
        emit AcrossV3AdapterV2.ExecutionFailed(account);

        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 0);
    }

    function test_Fill_ExecutorReturnBombRemainsBestEffort() public {
        executor.setExecutionMode(AcrossV2MockDestinationExecutor.ExecutionMode.ReturnBomb);

        vm.expectEmit(true, false, false, false, address(adapter));
        emit AcrossV3AdapterV2.ExecutionFailed(account);

        _fill(RELAY_ID);

        _assertSuccessfulFill();
        assertEq(executor.callCount(), 0);
    }

    function _fill(bytes32 relayId) internal {
        vm.prank(relayer);
        spokePool.fill(relayId, address(adapter), address(token), AMOUNT, _buildMessage());
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
        address[] memory dstTokens = new address[](1);
        dstTokens[0] = address(token);

        uint256[] memory intentAmounts = new uint256[](1);
        intentAmounts[0] = AMOUNT;

        ISuperValidator.DstProof[] memory proofDst = new ISuperValidator.DstProof[](1);
        proofDst[0] = ISuperValidator.DstProof({
            proof: new bytes32[](0),
            dstChainId: uint64(block.chainid),
            info: ISuperValidator.DstInfo({
                account: account,
                executor: address(executor),
                dstTokens: dstTokens,
                intentAmounts: intentAmounts,
                validator: address(0xBEEF),
                data: hex"deadbeef"
            })
        });

        uint64[] memory chainsWithDestinationExecution = new uint64[](1);
        chainsWithDestinationExecution[0] = uint64(block.chainid);

        bytes memory sigData = abi.encode(
            chainsWithDestinationExecution,
            uint48(type(uint48).max),
            uint48(0),
            keccak256("root"),
            new bytes32[](0),
            proofDst,
            hex"abcdef"
        );

        return abi.encode(hex"1234", sigData);
    }
}
