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

    /*//////////////////////////////////////////////////////////////
                  REFUND-ONLY-ON-SUCCESS REGRESSIONS (SUP-21683)
    //////////////////////////////////////////////////////////////*/

    /// @dev Exact replay of the production incident: Base block 53,253,207, tx 0x4f7d2285...4b9b. The ERC-20 fee
    ///      transfer reverted (`transfer amount exceeds balance`), EntryPoint called back with `opReverted`, and the
    ///      sender nevertheless received 336,898,980,000 wei out of the bundler-funded deposit. The guard must make
    ///      that withdrawal impossible while leaving the deposit intact.
    function test_PostOp_OpReverted_NoRefund_ProductionReplay() public {
        (bytes memory context, uint256 actualGasCost) = _productionIncidentContext();
        mockEntryPoint.depositTo{ value: 1 ether }(address(paymaster));
        uint256 depositBefore = mockEntryPoint.getDepositInfo(address(paymaster)).deposit;

        // The refund the unguarded contract would have paid — the amount actually observed on-chain.
        assertEq(_expectedRefund(actualGasCost), 336_898_980_000, "replay must reproduce the observed refund");

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opReverted, context, actualGasCost, 0);

        assertEq(mockEntryPoint.withdrawAddress(), address(0), "no withdrawal may be initiated");
        assertEq(mockEntryPoint.withdrawAmount(), 0, "no value may leave the deposit");
        assertEq(mockEntryPoint.getDepositInfo(address(paymaster)).deposit, depositBefore, "deposit must be untouched");
    }

    /// @dev The success path is unchanged: same context, same numbers, refund still paid in full. This is what
    ///      guarantees the fix did not introduce an upfront-balance or fee-first requirement.
    function test_PostOp_OpSucceeded_ProductionReplay_StillRefunds() public {
        (bytes memory context, uint256 actualGasCost) = _productionIncidentContext();
        mockEntryPoint.depositTo{ value: 1 ether }(address(paymaster));
        uint256 expected = _expectedRefund(actualGasCost);

        vm.expectEmit(true, false, false, true, address(paymaster));
        emit ISuperNativePaymaster.SuperNativePaymasterRefund(
            0x16C17F3Bc224552eCBDb134c1D4760eD177075e9, expected, expected
        );

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);

        assertEq(mockEntryPoint.withdrawAddress(), 0x16C17F3Bc224552eCBDb134c1D4760eD177075e9);
        assertEq(mockEntryPoint.withdrawAmount(), expected, "successful cashback must be preserved exactly");
        assertEq(expected, 336_898_980_000);
    }

    /// @dev `postOpReverted` is never passed by EntryPoint v0.7, but the guard covers it rather than relying on
    ///      that. A 2025 audit note had the original `postOpReverted` branch removed as dead code, and the
    ///      parameter name went with it — which is how the `opReverted` case ended up unhandled.
    function test_PostOp_PostOpReverted_NoRefund() public {
        (bytes memory context, uint256 actualGasCost) = _productionIncidentContext();
        mockEntryPoint.depositTo{ value: 1 ether }(address(paymaster));

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.postOpReverted, context, actualGasCost, 0);

        assertEq(mockEntryPoint.withdrawAmount(), 0);
        assertEq(mockEntryPoint.withdrawAddress(), address(0));
    }

    /// @dev The diagnostic event survives on the failure path, so a failed callback stays observable off-chain.
    function test_PostOp_OpReverted_StillEmitsPostOpEvent() public {
        (bytes memory context, uint256 actualGasCost) = _productionIncidentContext();
        mockEntryPoint.depositTo{ value: 1 ether }(address(paymaster));

        vm.expectEmit(false, false, false, true, address(paymaster));
        emit ISuperNativePaymaster.SuperNativePaymasterPostOp(context);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opReverted, context, actualGasCost, 0);
    }

    /// @dev Fee-first then a later reverting hook: the fee WAS collected during execution, but the op still
    ///      reverted, so the whole batch unwound and the token transfer is gone with it. A refund would hand out
    ///      bundler value for an operation that paid nothing.
    function test_PostOp_FeeFirstThenRevert_NoRefund() public {
        bytes memory context =
            abi.encode(sender, maxFeePerGas, maxFeePerGas - 1, maxGasLimit, nodeOperatorPremium, uint256(25_000));
        uint256 actualGasCost = maxGasLimit * maxFeePerGas / 4; // deep underspend: a large refund would be due
        mockEntryPoint.depositTo{ value: 10 ether }(address(paymaster));

        assertGt(
            paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium),
            0,
            "a refund must be owed on the success path for this to be a meaningful test"
        );

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opReverted, context, actualGasCost, 0);

        assertEq(mockEntryPoint.withdrawAmount(), 0);
    }

    /// @dev Mixed batch: EntryPoint calls back once per op. Only the successful ones may be refunded.
    function test_PostOp_MixedBatch_OnlySuccessfulOpsRefunded() public {
        address senderA = makeAddr("opA");
        address senderB = makeAddr("opB");
        uint256 actualGasCost = maxGasLimit * maxFeePerGas / 2;
        mockEntryPoint.depositTo{ value: 10 ether }(address(paymaster));

        // op A reverts: nothing paid out.
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(
            IPaymaster.PostOpMode.opReverted,
            abi.encode(senderA, maxFeePerGas, maxFeePerGas - 1, maxGasLimit, nodeOperatorPremium, uint256(0)),
            actualGasCost,
            0
        );
        assertEq(mockEntryPoint.withdrawAmount(), 0, "failed op in the batch must not be refunded");

        // op B succeeds: refunded as usual, and it is B that receives it.
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(
            IPaymaster.PostOpMode.opSucceeded,
            abi.encode(senderB, maxFeePerGas, maxFeePerGas - 1, maxGasLimit, nodeOperatorPremium, uint256(0)),
            actualGasCost,
            0
        );
        assertEq(mockEntryPoint.withdrawAddress(), senderB);
        assertGt(mockEntryPoint.withdrawAmount(), 0, "successful op in the batch must still be refunded");
    }

    /// @dev Property: a refund is payable on exactly one mode. Any other mode withdraws nothing, whatever the
    ///      gas numbers are.
    function testFuzz_PostOp_RefundOnlyOnSuccess(uint8 modeSeed, uint96 gasCostSeed) public {
        IPaymaster.PostOpMode mode = IPaymaster.PostOpMode(modeSeed % 3);
        uint256 actualGasCost = uint256(gasCostSeed) % (maxGasLimit * maxFeePerGas);
        bytes memory context =
            abi.encode(sender, maxFeePerGas, maxFeePerGas - 1, maxGasLimit, nodeOperatorPremium, uint256(0));
        mockEntryPoint.depositTo{ value: 10 ether }(address(paymaster));

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(mode, context, actualGasCost, 0);

        if (mode == IPaymaster.PostOpMode.opSucceeded) {
            assertEq(
                mockEntryPoint.withdrawAmount(),
                paymaster.calculateRefund(maxGasLimit, maxFeePerGas, actualGasCost, nodeOperatorPremium)
            );
        } else {
            assertEq(mockEntryPoint.withdrawAmount(), 0, "only opSucceeded may pay a refund");
        }
    }

    /// @dev The ticket's reproduction context, verbatim from the on-chain callback.
    function _productionIncidentContext() private pure returns (bytes memory context, uint256 actualGasCost) {
        context = abi.encode(
            0x16C17F3Bc224552eCBDb134c1D4760eD177075e9, // sender
            uint256(1_000_000), // maxFeePerGas
            uint256(11_000_000), // maxPriorityFeePerGas (inverted upstream — tracked in SUP-21682)
            uint256(637_219), // maxGasLimit
            uint256(10), // nodeOperatorPremium (bps)
            uint256(25_000) // postOpGas
        );
        actualGasCost = 275_020_000_000;
    }

    /// @dev Mirrors `_postOp`'s own arithmetic for the success path.
    function _expectedRefund(uint256 actualGasCost) private view returns (uint256) {
        uint256 price = 1_000_000; // min(maxFeePerGas, maxPriorityFeePerGas + basefee) for the replay context
        return paymaster.calculateRefund(637_219, 1_000_000, actualGasCost + (25_000 * price), 10);
    }

    function test_PostOp_WithRefund() public {
        vm.deal(address(paymaster), 2 ether);
        mockEntryPoint.depositTo{ value: 2 ether }(address(paymaster));

        bytes memory context =
            abi.encode(sender, maxFeePerGas, maxFeePerGas - 1, maxGasLimit, nodeOperatorPremium, uint256(0));
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
