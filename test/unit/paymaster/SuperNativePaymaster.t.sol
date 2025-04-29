// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@ERC4337/account-abstraction/contracts/interfaces/IPaymaster.sol";
import { UserOperationLib } from "@account-abstraction/core/UserOperationLib.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { AccountInstance } from "modulekit/ModuleKit.sol";

// Superform
import { BaseTest } from "../../BaseTest.t.sol";
import { ISuperNativePaymaster } from "../../../src/core/interfaces/ISuperNativePaymaster.sol";
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

    receive() external payable { }

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);
        instance = accountInstances[ETH];

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

    function test_PostOp_WithRefund() public {
        vm.deal(address(paymaster), 2 ether);
        mockEntryPoint.depositTo{ value: 2 ether }(address(paymaster));

        bytes memory context = abi.encode(sender, maxFeePerGas, maxGasLimit, nodeOperatorPremium);
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
