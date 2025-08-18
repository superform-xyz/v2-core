// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@ERC4337/account-abstraction/contracts/interfaces/IPaymaster.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

// Superform
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { ISuperNativePaymaster } from "../../../src/interfaces/ISuperNativePaymaster.sol";
import { MockEntryPoint, MockEntryPointRejectETH } from "../../mocks/MockEntryPoint.sol";
import { Helpers } from "../../utils/Helpers.sol";
import { IEntryPointSimulations } from "modulekit/external/ERC4337.sol";

contract SuperNativePaymasterTest is Helpers {
    using UserOperationLib for PackedUserOperation;

    SuperNativePaymaster public paymaster;
    MockEntryPoint public mockEntryPoint;
    address public sender;
    uint256 public maxFeePerGas;
    uint256 public maxGasLimit;
    uint256 public nodeOperatorPremium;

    receive() external payable { }

    function setUp() public {
        mockEntryPoint = new MockEntryPoint();
        paymaster = new SuperNativePaymaster(IEntryPoint(address(mockEntryPoint)));

        sender = makeAddr("sender");
        maxFeePerGas = 10 gwei;
        maxGasLimit = 1_000_000;
        nodeOperatorPremium = 10; // 10%

        vm.deal(address(this), LARGE);
        vm.deal(sender, LARGE);
        vm.deal(address(mockEntryPoint), LARGE);
    }

    function test_Constructor() public view {
        assertEq(address(paymaster.entryPoint()), address(mockEntryPoint));
    }

    function test_InvalidConstructor_Paymaster() public {
        vm.expectRevert();
        new SuperNativePaymaster(IEntryPoint(address(0)));
    }

    function test_CalculateRefund_ExceedingMaxCost() public {
        uint256 maxCost = maxGasLimit * maxFeePerGas;
        uint256 actualGasCost = maxCost;
        vm.expectRevert(ISuperNativePaymaster.INVALID_NODE_OPERATOR_PREMIUM.selector);
        paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, 100_000);
    }

    function test_CalculateRefund_NoRefund() public view {
        uint256 maxCost = maxGasLimit * maxFeePerGas;
        uint256 actualGasCost = maxCost;

        uint256 refund = paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium);

        assertEq(refund, 0);
    }

    function test_CalculateRefund_HighPremium() public view {
        uint256 maxCost = maxGasLimit * maxFeePerGas;
        uint256 actualGasCost = maxCost / 2;
        uint256 highPremium = 10_000; // 100%

        uint256 refund = paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, highPremium);

        assertEq(refund, 0);
    }

    function test_HandleOps() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        paymaster.handleOps{ value: 1 ether }(ops);

        assertEq(mockEntryPoint.depositAmount(), 1 ether);
    }

    function test_HandleOps_RevertWhenTransferFails() public {
        // Create a mock EntryPoint that rejects ETH
        MockEntryPointRejectETH mockEntryPointRejectsETH = new MockEntryPointRejectETH();

        // Deploy paymaster with our special mock EntryPoint
        SuperNativePaymaster paymasterWithRejectingEntryPoint =
            new SuperNativePaymaster(IEntryPoint(address(mockEntryPointRejectsETH)));

        // Add some ETH to the paymaster
        vm.deal(address(paymasterWithRejectingEntryPoint), 1 ether);

        // Create a dummy user operation
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);

        // This should revert because the EntryPoint will reject ETH transfers
        vm.expectRevert(ISuperNativePaymaster.INSUFFICIENT_BALANCE.selector);
        paymasterWithRejectingEntryPoint.handleOps(ops);
    }

    function test_PostOp_WithRefund() public {
        vm.deal(address(paymaster), 2 ether);
        mockEntryPoint.depositTo{ value: 2 ether }(address(paymaster));

        bytes memory context = abi.encode(sender, maxFeePerGas, maxGasLimit, nodeOperatorPremium, uint256(0));
        uint256 actualGasCost = maxGasLimit * maxFeePerGas / 2;

        vm.deal(address(mockEntryPoint), 10 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);

        assertEq(mockEntryPoint.withdrawAddress(), sender);
        assertTrue(mockEntryPoint.withdrawAmount() > 0);
    }

    function test_ValidatePaymasterUserOp_InsufficientBalance() public {
        // Setup test values
        uint256 addBalance = 0.001 ether;

        // Create user operation with specific gas parameters
        PackedUserOperation memory userOp = _createUserOp();

        // Use the same encoding that works in test_ValidatePaymasterUserOp_RevertIf_InvalidMaxGasLimit
        userOp.paymasterAndData = bytes.concat(
            bytes20(address(paymaster)), // 20 bytes
            new bytes(32), // 32 bytes of padding (to align to offset 52)
            abi.encode(maxGasLimit, nodeOperatorPremium) // your actual payload
        );

        // Initially paymaster has no balance
        assertEq(address(paymaster).balance, 0, "Initial paymaster balance should be 0");
        assertEq(mockEntryPoint.getDepositInfo(address(paymaster)).deposit, 0, "Initial deposit should be 0");

        // Transfer and deposit the exact required amount
        vm.deal(address(paymaster), addBalance);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: addBalance }(address(paymaster));

        // Call handleOps which should deposit the funds to EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;
        vm.expectRevert("AA31 paymaster deposit too low");
        mockEntryPoint.handleOps(ops, payable(sender));
    }

    function test_ValidatePaymasterUserOp_OperatorPremiumTooHigh() public {
        // Setup test values
        uint256 addBalance = 1 ether;

        // Create user operation with specific gas parameters
        PackedUserOperation memory userOp = _createUserOp();

        userOp.paymasterAndData = bytes.concat(
            new bytes(52),
            abi.encodePacked(uint256(1)),
            abi.encodePacked(uint256(100_000)),
            abi.encodePacked(uint256(1))
        );
        // Initially paymaster has no balance
        assertEq(address(paymaster).balance, 0, "Initial paymaster balance should be 0");
        assertEq(mockEntryPoint.getDepositInfo(address(paymaster)).deposit, 0, "Initial deposit should be 0");

        // Transfer and deposit the exact required amount
        vm.deal(address(paymaster), addBalance);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: addBalance }(address(paymaster));

        // Call handleOps which should deposit the funds to EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        vm.startPrank(address(mockEntryPoint));
        vm.expectRevert(ISuperNativePaymaster.INVALID_NODE_OPERATOR_PREMIUM.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 0);
        vm.stopPrank();
    }

    function test_SimulateHandleOp_RevertIfEmptyValue() public {
        // Create a dummy user operation
        PackedUserOperation memory op;

        // This should revert because msg.value is 0
        vm.expectRevert(ISuperNativePaymaster.EMPTY_MESSAGE_VALUE.selector);
        paymaster.simulateHandleOp(op, address(0), "");
    }

    function test_SimulateHandleOp_Success() public {
        // Setup
        PackedUserOperation memory op;
        address target = address(0xBEEF);
        bytes memory callData = hex"CAFECAFE";

        // Simulate handling the operation with some ETH value
        paymaster.simulateHandleOp{ value: 0.1 ether }(op, target, callData);

        // Verify the simulation was forwarded to the entry point
        // We can only test that the call happened and the parameters were passed correctly
        assertEq(mockEntryPoint.lastSimulationTarget(), target);
        assertEq(mockEntryPoint.lastSimulationCallData(), callData);
    }

    function test_SimulateValidation_RevertIfEmptyValue() public {
        // Create a dummy user operation
        PackedUserOperation memory op;

        // This should revert because msg.value is 0
        vm.expectRevert(ISuperNativePaymaster.EMPTY_MESSAGE_VALUE.selector);
        paymaster.simulateValidation(op);
    }

    function test_SimulateValidation_Success() public {
        // Prepare input op
        PackedUserOperation memory op = _createUserOp();

        // Set return value in mock
        mockEntryPoint.setValidationReturnValue(false);

        // Call with value
        uint256 sendValue = 1 ether;
        vm.deal(address(this), sendValue);
        IEntryPointSimulations.ValidationResult memory result = paymaster.simulateValidation{ value: sendValue }(op);

        assertEq(result.paymasterInfo.stake, 2e6);
    }

    function _createUserOp() internal view returns (PackedUserOperation memory) {
        PackedUserOperation memory op;
        op.sender = sender;
        op.nonce = uint256(1);
        op.initCode = "";
        op.callData = "";
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(100_000), uint128(150_000))); // callGasLimit,
            // verificationGasLimit
        op.preVerificationGas = 50_000;
        op.gasFees = bytes32(abi.encodePacked(uint128(maxFeePerGas), uint128(maxFeePerGas / 2))); // maxFeePerGas,
            // maxPriorityFeePerGas
        op.paymasterAndData = abi.encodePacked(address(paymaster));
        op.signature = "";

        return op;
    }
}
