// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { HyperCoreGasTopUpHook } from "../../../../src/hooks/hypercore/HyperCoreGasTopUpHook.sol";
import { TransferHook } from "../../../../src/hooks/tokens/TransferHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../../src/interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../../src/libraries/HookSubTypes.sol";
import { Helpers } from "../../../utils/Helpers.sol";

/// @dev Local EVM receiver only: it does not simulate HyperCore credit or settlement.
contract GasTopUpReceiver {
    address public lastSender;
    uint256 public lastValue;
    bytes public lastData;
    uint256 public totalReceived;
    bool public rejecting;

    function setRejecting(bool value) external {
        rejecting = value;
    }

    fallback() external payable {
        require(!rejecting, "receiver rejected transfer");
        lastSender = msg.sender;
        lastValue = msg.value;
        lastData = msg.data;
        totalReceived += msg.value;
    }
}

contract GasTopUpSourceHook is BaseHook {
    address private immutable OUTPUT_TOKEN;
    uint256 private immutable OUTPUT_AMOUNT;

    constructor(address token, uint256 amount) BaseHook(HookType.NONACCOUNTING, bytes32(0)) {
        OUTPUT_TOKEN = token;
        OUTPUT_AMOUNT = amount;
    }

    function name() external pure override returns (string memory) {
        return "Top-up test source";
    }

    function description() external pure override returns (string memory) {
        return "Publishes a separately funded test principal";
    }

    function _buildHookExecutions(
        address,
        address,
        bytes calldata
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        executions = new Execution[](0);
    }

    function _postExecute(address, address account, bytes calldata) internal override {
        _setOutAmount(OUTPUT_AMOUNT, account);
        _setOutToken(OUTPUT_TOKEN, account);
    }
}

/// @dev Executes one hook's local lifecycle atomically, without an EntryPoint.
contract GasTopUpAccount {
    receive() external payable { }

    function executeHook(ISuperHook hook, address prevHook, bytes memory data) external {
        Execution[] memory executions = hook.build(prevHook, address(this), data);
        hook.setExecutionContext(address(this));
        for (uint256 i; i < executions.length; ++i) {
            (bool success, bytes memory result) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(result, 32), mload(result))
                }
            }
        }
        hook.resetExecutionState(address(this));
    }
}

contract HyperCoreGasTopUpHookTest is Helpers {
    address private constant HYPE_SYSTEM = 0x2222222222222222222222222222222222222222;
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    HyperCoreGasTopUpHook private hook;
    GasTopUpAccount private account;
    GasTopUpReceiver private receiver;

    function setUp() public {
        hook = new HyperCoreGasTopUpHook();
        account = new GasTopUpAccount();
        vm.etch(HYPE_SYSTEM, address(new GasTopUpReceiver()).code);
        receiver = GasTopUpReceiver(payable(HYPE_SYSTEM));
    }

    function _data(uint256 amount) private pure returns (bytes memory) {
        return abi.encodePacked(bytes32(0), address(0), amount);
    }

    function test_MetadataAndAddressOnlyInspection() public view {
        assertEq(uint8(hook.hookType()), uint8(ISuperHook.HookType.NONACCOUNTING));
        assertEq(hook.SUB_TYPE(), HookSubTypes.HYPERCORE);
        assertEq(hook.HYPE_SYSTEM_ADDRESS(), HYPE_SYSTEM);
        assertGt(bytes(hook.name()).length, 0);
        assertGt(bytes(hook.description()).length, 0);
        assertEq(hook.inspect(_data(1 ether)), abi.encodePacked(HYPE_SYSTEM));
    }

    function testFuzz_BuildPreservesExactSignedAmount(uint256 amount) public view {
        vm.assume(amount > 0);
        bytes memory data = _data(amount);
        address prev = address(0x1234);
        Execution[] memory executions = hook.build(prev, address(account), data);
        assertEq(data.length, 84);
        assertEq(executions.length, 3);
        assertEq(executions[0].target, address(hook));
        assertEq(executions[0].value, 0);
        assertEq(executions[0].callData, abi.encodeCall(hook.preExecute, (prev, address(account), data)));
        assertEq(executions[1].target, HYPE_SYSTEM);
        assertEq(executions[1].value, amount);
        assertEq(executions[1].callData.length, 0);
        assertEq(executions[2].target, address(hook));
        assertEq(executions[2].value, 0);
        assertEq(executions[2].callData, abi.encodeCall(hook.postExecute, (prev, address(account), data)));
    }

    function test_BuildAllowsFullUint256WithoutResizing() public view {
        assertEq(hook.build(address(0), address(account), _data(type(uint256).max))[1].value, type(uint256).max);
    }

    function test_BuildRejectsZero() public {
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(0), address(account), _data(0));
    }

    function test_BuildRejectsEmptyTruncatedAndPaddedData() public {
        uint256[5] memory lengths = [uint256(0), 51, 52, 83, 85];
        for (uint256 i; i < lengths.length; ++i) {
            vm.expectRevert(HyperCoreGasTopUpHook.DATA_NOT_VALID.selector);
            hook.build(address(0), address(account), new bytes(lengths[i]));
        }
    }

    function testFuzz_BuildRejectsEveryOtherLength(uint16 length) public {
        vm.assume(length != 84);
        vm.expectRevert(HyperCoreGasTopUpHook.DATA_NOT_VALID.selector);
        hook.build(address(0), address(account), new bytes(length));
    }

    function test_S2SizingCannotRewriteFunding() public {
        bytes memory data = _data(1 ether);
        assertEq(hook.decodeAmounts(data).length, 0);
        assertEq(hook.amountRoles(data).length, 0);
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
        assertFalse(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
        assertTrue(hook.supportsInterface(type(IERC165).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookResult).interfaceId));
        assertTrue(hook.supportsInterface(type(ISuperHookInspector).interfaceId));
        assertFalse(hook.supportsInterface(0xffffffff));
        (bool success,) =
            address(hook).call(abi.encodeCall(ISuperHookOutflow.replaceCalldataAmounts, (data, _singleAmount(2 ether))));
        assertFalse(success);
        assertEq(hook.build(address(0), address(account), data)[1].value, 1 ether);
    }

    function test_LifecycleRetainsAccountAuthorizationAndMutexes() public {
        bytes memory data = _data(1 ether);
        hook.setExecutionContext(address(account));
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.preExecute(address(0), address(account), data);
        vm.expectRevert(BaseHook.UNAUTHORIZED_CALLER.selector);
        hook.postExecute(address(0), address(account), data);
        vm.prank(address(account));
        hook.preExecute(address(0), address(account), data);
        vm.expectRevert(BaseHook.PRE_EXECUTE_ALREADY_CALLED.selector);
        vm.prank(address(account));
        hook.preExecute(address(0), address(account), data);
        vm.prank(address(account));
        hook.postExecute(address(0), address(account), data);
        vm.expectRevert(BaseHook.POST_EXECUTE_ALREADY_CALLED.selector);
        vm.prank(address(account));
        hook.postExecute(address(0), address(account), data);
    }

    function test_AccountOriginatedTransferDoesNotForwardERC20Pipe() public {
        _assertPipe(address(0xCAFE));
    }

    function test_AccountOriginatedTransferDoesNotForwardNativePipe() public {
        _assertPipe(NATIVE_TOKEN);
    }

    function _assertPipe(address token) private {
        uint256 principal = 7 ether;
        uint256 topUp = 0.01 ether;
        GasTopUpSourceHook source = new GasTopUpSourceHook(token, principal);
        account.executeHook(source, address(0), "");
        vm.deal(address(account), principal);
        account.executeHook(hook, address(source), _data(topUp));
        assertEq(receiver.lastSender(), address(account));
        assertEq(receiver.lastValue(), topUp);
        assertEq(receiver.lastData().length, 0);
        assertEq(address(account).balance, principal - topUp);
        assertEq(address(hook).balance, 0);
        assertEq(hook.getOutAmount(address(account)), 0);
        assertEq(hook.getOutToken(address(account)), address(0));
        assertEq(source.getOutAmount(address(account)), principal);
        assertEq(source.getOutToken(address(account)), token);

        // A production consumer must reject the empty output instead of spending the stale principal.
        TransferHook consumer = new TransferHook(NATIVE_TOKEN);
        bytes memory consumerData = abi.encodePacked(bytes32(0), address(0), token, address(0xDE57), uint256(0), true);
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        consumer.build(address(hook), address(account), consumerData);

        // A new first-hook context cannot reuse the prior pipeline output.
        account.executeHook(hook, address(0), _data(topUp));
        assertEq(hook.getOutAmount(address(account)), 0);
        assertEq(hook.getOutToken(address(account)), address(0));
    }

    function test_FirstHookDoesNotPublishTopUpAsOutput() public {
        vm.deal(address(account), 1 ether);
        account.executeHook(hook, address(0), _data(1 ether));
        assertEq(receiver.totalReceived(), 1 ether);
        assertEq(hook.getOutAmount(address(account)), 0);
        assertEq(hook.getOutToken(address(account)), address(0));
    }

    function test_RevertingReceiverRollsBackFunding() public {
        vm.deal(address(account), 1 ether);
        receiver.setRejecting(true);
        vm.expectRevert(bytes("receiver rejected transfer"));
        account.executeHook(hook, address(0), _data(1 ether));
        assertEq(address(account).balance, 1 ether);
        assertEq(receiver.totalReceived(), 0);
    }

    function test_InsufficientAccountBalanceDoesNotFundReceiver() public {
        vm.expectRevert();
        account.executeHook(hook, address(0), _data(1 ether));
        assertEq(receiver.totalReceived(), 0);
        assertEq(address(hook).balance, 0);
    }
}
