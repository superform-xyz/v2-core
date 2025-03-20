// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { BasePaymaster } from "@account-abstraction/core/BasePaymaster.sol";
import { IEntryPoint } from "@account-abstraction/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@account-abstraction/interfaces/IPaymaster.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";
import { PackedUserOperation } from "@account-abstraction/interfaces/PackedUserOperation.sol";
import { IEntryPointSimulations } from "@account-abstraction/interfaces/IEntryPointSimulations.sol";
import { RhinestoneModuleKit, ModuleKitHelpers, AccountInstance, UserOpData } from "modulekit/ModuleKit.sol";


// Superform
import { BaseTest } from "../../BaseTest.t.sol";

import { SuperNativePaymaster } from "../../../src/core/paymaster/SuperNativePaymaster.sol";
import { MockEntryPoint } from "../../mocks/MockEntryPoint.sol";

contract SuperNativePaymasterTest is BaseTest {
    using UserOperationLib for PackedUserOperation;
    
    SuperNativePaymaster public paymaster;
    AccountInstance public instance;
    MockEntryPoint public mockEntryPoint;
    address public sender;
    uint256 public maxFeePerGas;
    uint256 public maxGasLimit;
    uint256 public nodeOperatorPremium;

    receive() external payable {}

    function setUp() public override {
        super.setUp();
        

        vm.selectFork(FORKS[ETH]);
        instance = accountInstances[ETH];
        
        mockEntryPoint = new MockEntryPoint();
        paymaster = new SuperNativePaymaster(IEntryPoint(address(mockEntryPoint)));
        
        sender = makeAddr("sender");
        maxFeePerGas = 10 gwei;
        maxGasLimit = 1000000;
        nodeOperatorPremium = 10; // 10%
        
        vm.deal(address(this), LARGE);
        vm.deal(sender, LARGE);
        vm.deal(address(mockEntryPoint), LARGE);
    }
    
    function test_Constructor() public view {
        assertEq(address(paymaster.entryPoint()), address(mockEntryPoint));
    }
    
    function test_CalculateRefund_WithRefund() public view {
        uint256 maxCost = maxGasLimit * maxFeePerGas;
        uint256 actualGasCost = maxCost / 2;
        uint256 expectedRefund = maxCost - (actualGasCost * 110 / 100);
        
        uint256 refund = paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium);
        
        assertEq(refund, expectedRefund);
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
        uint256 highPremium = 110; // 110%
        
        uint256 refund = paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, highPremium);
        
        assertEq(refund, 0);
    }
    
    function test_HandleOps() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        
        paymaster.handleOps{value: 1 ether}(ops);
        
        assertEq(mockEntryPoint.depositAmount(), 1 ether);
    }
    
    function test_HandleOps_RevertIf_EmptyValue() public {
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        
        vm.expectRevert(SuperNativePaymaster.EMPTY_MESSAGE_VALUE.selector);
        paymaster.handleOps(ops);
    }
    
    function test_SimulateHandleOp() public {
        PackedUserOperation memory op = _createUserOp();
        address target = address(0x123);
        bytes memory callData = "";
        
        IEntryPointSimulations.ExecutionResult memory result = paymaster.simulateHandleOp{value: 1 ether}(op, target, callData);
        
        assertEq(result.preOpGas, 100000);
        assertEq(mockEntryPoint.depositAmount(), 1 ether);
    }
    
    function test_SimulateHandleOp_RevertIf_EmptyValue() public {
        PackedUserOperation memory op = _createUserOp();
        address target = address(0x123);
        bytes memory callData = "";
        
        vm.expectRevert(SuperNativePaymaster.EMPTY_MESSAGE_VALUE.selector);
        paymaster.simulateHandleOp(op, target, callData);
    }
   
    function test_SimulateValidation_RevertIf_EmptyValue() public {
        PackedUserOperation memory op = _createUserOp();
        
        // Use bytes4 selector for the custom error
        bytes4 selector = SuperNativePaymaster.EMPTY_MESSAGE_VALUE.selector;
        vm.expectRevert(selector);
        paymaster.simulateValidation(op);
    }
    
    function test_ValidatePaymasterUserOp_RevertIf_InsufficientBalance() public {
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster),
            abi.encode(maxGasLimit, nodeOperatorPremium)
        );
        
        PackedUserOperation memory userOp = _createUserOp();
        userOp.paymasterAndData = paymasterAndData;
        
        bytes32 userOpHash = keccak256("userOpHash");
        uint256 maxCost = 1 ether;
        
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(SuperNativePaymaster.INSUFFICIENT_BALANCE.selector);
        paymaster.validatePaymasterUserOp(userOp, userOpHash, maxCost);
    }
    
    function test_PostOp_WithRefund() public {
        vm.deal(address(paymaster), 2 ether);
        mockEntryPoint.depositTo{value: 2 ether}(address(paymaster));

        bytes memory context = abi.encode(sender, maxFeePerGas, maxGasLimit, nodeOperatorPremium);
        uint256 actualGasCost = maxGasLimit * maxFeePerGas / 2;
        
        vm.deal(address(mockEntryPoint), 10 ether);
        
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);
        
        assertEq(mockEntryPoint.withdrawAddress(), sender);
        assertTrue(mockEntryPoint.withdrawAmount() > 0);
    }
    
    function test_PostOp_NoRefund() public {
        bytes memory context = abi.encode(sender, maxFeePerGas, maxGasLimit, 200); // 200% premium
        uint256 actualGasCost = maxGasLimit * maxFeePerGas / 2;
        
        vm.deal(address(mockEntryPoint), 10 ether);
        
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);
        
        assertEq(mockEntryPoint.withdrawAddress(), address(0));
        assertEq(mockEntryPoint.withdrawAmount(), 0);
    }
    
    function test_PostOp_Reverted() public {
        bytes memory context = abi.encode(sender, maxFeePerGas, maxGasLimit, nodeOperatorPremium);
        uint256 actualGasCost = maxGasLimit * maxFeePerGas / 2;
        
        vm.deal(address(mockEntryPoint), 10 ether);
        
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.postOpReverted, context, actualGasCost, 0);
        
        assertEq(mockEntryPoint.withdrawAddress(), address(0));
        assertEq(mockEntryPoint.withdrawAmount(), 0);
    }
    
    function test_Receive() public {
        vm.deal(address(this), 1 ether);
        (bool success,) = address(paymaster).call{value: 1 ether}("");
        assertTrue(success);
        assertEq(address(paymaster).balance, 1 ether);
    }
    
    function _createUserOp() internal view returns (PackedUserOperation memory) {
        PackedUserOperation memory op;
        op.sender = sender;
        op.nonce = uint256(1);
        op.initCode = "";
        op.callData = "";
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(100000), uint128(150000))); // callGasLimit, verificationGasLimit
        op.preVerificationGas = 50000;
        op.gasFees = bytes32(abi.encodePacked(uint128(maxFeePerGas), uint128(maxFeePerGas / 2))); // maxFeePerGas, maxPriorityFeePerGas
        op.paymasterAndData = abi.encodePacked(address(paymaster));
        op.signature = "";
        
        return op;
    }
}
