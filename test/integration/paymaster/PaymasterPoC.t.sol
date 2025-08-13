// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {PackedUserOperation} from "modulekit/external/ERC4337.sol";
import {IEntryPoint} from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {PaymasterHelper} from "./PaymasterHelper.t.sol";
import "forge-std/console2.sol";
import "forge-std/Test.sol";

// Superform
import {ISuperExecutor} from "../../../src/interfaces/ISuperExecutor.sol";
import {SuperNativePaymaster} from "../../../src/paymaster/SuperNativePaymaster.sol";


contract PoC is PaymasterHelper {
    address[] public attesters;
    uint8 public threshold;

    bytes public mockSignature;

    // Define a struct to hold test data to avoid stack too deep errors
    struct TestData {
        address nexusAccount;
        uint256 amount;
        address[] hooksAddresses;
        bytes[] hooksData;
        ISuperExecutor.ExecutorEntry entry;
        uint256 maxGasLimit;
        SuperNativePaymaster paymaster;
        uint128 paymasterVerificationGasLimit;
        uint128 paymasterPostOpGasLimit;
        bytes paymasterData;
        bytes paymasterAndData;
        PackedUserOperation[] ops;
        uint256 maxFeePerGas;
    }

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();
        attesters = new address[](1);
        attesters[0] = address(MANAGER);
        threshold = 1;

        mockSignature = abi.encodePacked(hex"41414141");
    }

    function test_extraGas() public {
        TestData memory data;

        // create account
        data.nexusAccount = _createWithNexus(attesters, threshold, 0);

        // fund account
        vm.deal(data.nexusAccount, LARGE);

        data.amount = 10e18;

        // add tokens to account
        _getTokens(CHAIN_1_WETH, data.nexusAccount, data.amount);

        // create SuperExecutor data
        data.hooksAddresses = new address[](1);
        data.hooksData = new bytes[](1);
        data.hooksAddresses[0] = approveHook;
        data.hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), data.amount, false);
        data.entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: data.hooksAddresses, 
            hooksData: data.hooksData
        });

        // create paymaster 
        // set maxGasLimit
        // paymasterVerificationGasLimit + paymasterPostOpGasLimit + callGasLimit + verificationGasLimit + preVerificationGas
        // every value was set to 10e6, so in total we have 50e6
        data.maxGasLimit = 50e6;

        data.paymaster = new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        data.paymasterVerificationGasLimit = 10e6;
        data.paymasterPostOpGasLimit = 10e6;
        data.paymasterData = abi.encode(data.maxGasLimit, uint256(0), uint256(10e6)); // premium is zero
        data.paymasterAndData = abi.encodePacked(
            address(data.paymaster), 
            data.paymasterVerificationGasLimit, 
            data.paymasterPostOpGasLimit, 
            data.paymasterData
        );

        data.ops = _createUserOpWithPaymaster(data.nexusAccount, data.entry, data.paymasterAndData);

        // now let's calculate how much SuperBundler will pay for UserOp (for how much refund will be inflated)
        // and then we will calculate what should be refunded and compare it to what actually was refunded

        // price 4e6 as the maxPriorityFeePerGas
        // also set the basefee to one so that EntryPoint takes gasPrice as (maxPriorityFeePerGas + basefee)
        data.maxFeePerGas = 1e8;
        vm.txGasPrice(4e6);
        vm.fee(1);
        vm.deal(address(this), data.maxGasLimit * data.maxFeePerGas * 10);

        // safe the balance of account 
        uint256 ethBalanceBefore = data.nexusAccount.balance;

        // open a deposit for paymaster. it must be more than maxGasLimit * maxFeePerGas so that bundle does not revert 
        // the actualGasCost value postOp() function gets: 40645870260000 [4.064e13]
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).depositTo{value: data.maxGasLimit * data.maxFeePerGas + 5e15}(address(data.paymaster));

        // we prank paymaster because we want to use the actual gas in entryPoint.handleOps(). without the gas in the wrapper
        vm.prank(address(data.paymaster));

        vm.startSnapshotGas("handleOps");
        
        // beneficiary is this as it does not matter for gas estimations
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).handleOps{gas: data.maxGasLimit}(data.ops, payable(address(this)));

        uint256 actualGas = vm.stopSnapshotGas();

        // the real gas cost
        // we add 10e6 because EntryPoint adds verificationGasLimit to gasUsed value in its calculations internally and we need to account for that
        // the real gas cost after handleOps is: 4959282896000000 [4.95e14]
        uint256 realGasCost = (actualGas + (10e6*data.maxFeePerGas)) * tx.gasprice;

        uint256 whatShouldBeRefunded = data.paymaster.calculateRefund(data.maxGasLimit, data.maxFeePerGas, realGasCost, 0);

        // postOp refunded more than it should
        assertGt(data.nexusAccount.balance - ethBalanceBefore, whatShouldBeRefunded);
    }
    
    function test_incorrectFees() public {
        TestData memory data;

        // create account
        data.nexusAccount = _createWithNexus(attesters, threshold, 0);

        // fund account
        vm.deal(data.nexusAccount, LARGE);

        data.amount = 10e18;

        // add tokens to account
        _getTokens(CHAIN_1_WETH, data.nexusAccount, data.amount);

        // create SuperExecutor data
        data.hooksAddresses = new address[](1);
        data.hooksData = new bytes[](1);
        data.hooksAddresses[0] = approveHook;
        data.hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), data.amount, false);
        data.entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: data.hooksAddresses, 
            hooksData: data.hooksData
        });

        // create paymaster 
        // set maxGasLimit
        // paymasterVerificationGasLimit + paymasterPostOpGasLimit + callGasLimit + verificationGasLimit + preVerificationGas
        // every value was set to 10e6, so in total we have 50e6
        data.maxGasLimit = 50e6;

        data.paymaster = new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        data.paymasterVerificationGasLimit = 10e6;
        data.paymasterPostOpGasLimit = 10e6;
        data.paymasterData = abi.encode(data.maxGasLimit, uint256(0), uint256(0)); // premium is zero
        data.paymasterAndData = abi.encodePacked(
            address(data.paymaster), 
            data.paymasterVerificationGasLimit, 
            data.paymasterPostOpGasLimit, 
            data.paymasterData
        );

        data.ops = _createUserOpWithPaymaster(data.nexusAccount, data.entry, data.paymasterAndData);

        // now let's calculate how much SuperBundler will pay for UserOp (for how much refund will be inflated)
        // and then we will calculate what should be refunded and compare it to what actually was refunded

        // price 4e6 as the maxPriorityFeePerGas
        // also set the basefee to one so that EntryPoint takes gasPrice as (maxPriorityFeePerGas + basefee)
        data.maxFeePerGas = 1e8;
        vm.txGasPrice(4e6);
        vm.fee(1);
        vm.deal(address(this), data.maxGasLimit * data.maxFeePerGas * 10);

        // safe the balance of account 
        uint256 ethBalanceBefore = data.nexusAccount.balance;

        // open a deposit for paymaster. it must be more than maxGasLimit * maxFeePerGas so that bundle does not revert 
        // the actualGasCost value postOp() function gets: 40645870260000 [4.064e13]
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).depositTo{value: data.maxGasLimit * data.maxFeePerGas + 5e15}(address(data.paymaster));

        // we prank paymaster because we want to use the actual gas in entryPoint.handleOps(). without the gas in the wrapper
        vm.prank(address(data.paymaster));

        vm.startSnapshotGas("handleOps");
        
        // beneficiary is this as it does not matter for gas estimations
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).handleOps{gas: data.maxGasLimit}(data.ops, payable(address(this)));

        uint256 actualGas = vm.stopSnapshotGas();

        // the real gas cost
        // we add 10e6 because EntryPoint adds verificationGasLimit to gasUsed value in its calculations internally and we need to account for that
        // the real gas cost after handleOps is: 304553490000000 [3.045e14]
        uint256 realGasCost = (actualGas + 10e6) * tx.gasprice;

        uint256 whatShouldBeRefunded = data.paymaster.calculateRefund(data.maxGasLimit, data.maxFeePerGas, realGasCost, 0);

        // postOp refunded more than it should
        assertGt(data.nexusAccount.balance - ethBalanceBefore, whatShouldBeRefunded);
    }

    function test_incorrectGas() public {
        // create account
        address nexusAccount = _createWithNexus(attesters, threshold, 0);

        // fund account
        vm.deal(nexusAccount, LARGE);

        uint256 amount = 10e18;

        // add tokens to account
        _getTokens(CHAIN_1_WETH, nexusAccount, amount);

        // create SuperExecutor data
        address[] memory hooksAddresses = new address[](1);
        bytes[] memory hooksData = new bytes[](1);
        hooksAddresses[0] = approveHook;
        hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), amount, false);
        ISuperExecutor.ExecutorEntry memory entry =
        ISuperExecutor.ExecutorEntry({hooksAddresses: hooksAddresses, hooksData: hooksData});

        // create paymaster 
        // set maxGasLimit
        // paymasterVerificationGasLimit + paymasterPostOpGasLimit + callGasLimit + verificationGasLimit + preVerificationGas
        // every value was set to 10e6, so in total we have 50e6
        uint256 maxGasLimit = 50e6;

        SuperNativePaymaster paymaster = new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        uint128 paymasterVerificationGasLimit = 10e6;
        uint128 paymasterPostOpGasLimit = 10e6;
        bytes memory paymasterData = abi.encode(maxGasLimit, uint256(0), uint256(0)); // premium is zero
        bytes memory paymasterAndData = abi.encodePacked(address(paymaster), paymasterVerificationGasLimit, paymasterPostOpGasLimit, paymasterData);

        PackedUserOperation[] memory ops = _createUserOpWithPaymaster(nexusAccount, entry, paymasterAndData);

        // our maxFeePerGas is 1e8,
        uint256 maxFeePerGas = 1e8;

        // set the price to maxFeePerGas to calculate the gas of `actualGasCost` in `_postOp() manually
        vm.txGasPrice(1e8);

        vm.deal(address(this), maxGasLimit * maxFeePerGas * 10);

        // open a deposit for paymaster. it must be more than maxGasLimit * maxFeePerGas so that bundle does not revert 
        // the actualGasCost value postOp() function gets: 1011091300000000 [1.011e15]
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).depositTo{value: maxGasLimit * maxFeePerGas + 5e15}(address(paymaster));

        // we prank paymaster because we want to use the actual gas in entryPoint.handleOps(). without the gas in the wrapper
        vm.prank(address(paymaster));

        vm.startSnapshotGas("handleOps");
        
        // beneficiary is this as it does not matter for gas estimations
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).handleOps{gas: maxGasLimit}(ops, payable(address(this)));

        uint256 actualGas = vm.stopSnapshotGas();

        // the real gas cost
        // we add 10e6 because EntryPoint adds verificationGasLimit to gasUsed value in its calculations internally and we need to account for that
        // the real gas cost after handleOps is: 1015177900000000 [1.015e15]
        uint256 realGasCost = (actualGas + 10e6) * tx.gasprice;

        console2.log(realGasCost);
    }

    function test_postOpGasMultiplier() public {
        // This test verifies that postOpGas is correctly multiplied by maxFeePerGas
        
        // Create a simple test setup
        TestData memory data;
        data.nexusAccount = _createWithNexus(attesters, threshold, 0);
        vm.deal(data.nexusAccount, LARGE);
        
        // Configure paymaster with reasonable values
        uint256 postOpGasValue = 5e6; // 5M gas
        uint256 maxFeePerGasValue = 2e8; // 200 gwei
        uint256 maxGasLimit = 20e6;
        
        // Create paymaster and setup data
        data.paymaster = new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        
        // Create the hook data for a simple operation
        data.hooksAddresses = new address[](1);
        data.hooksData = new bytes[](1);
        data.hooksAddresses[0] = approveHook;
        data.hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), 1e18, false);
        data.entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: data.hooksAddresses, 
            hooksData: data.hooksData
        });
        
        // Set up the paymaster data with our test values
        data.paymasterVerificationGasLimit = uint128(5e6);
        data.paymasterPostOpGasLimit = uint128(postOpGasValue); // This is the key parameter we're testing
        data.paymasterData = abi.encode(maxGasLimit, uint256(0), uint256(0)); // No premium
        data.paymasterAndData = abi.encodePacked(
            address(data.paymaster), 
            data.paymasterVerificationGasLimit, 
            data.paymasterPostOpGasLimit, 
            data.paymasterData
        );
        
        data.ops = _createUserOpWithPaymaster(data.nexusAccount, data.entry, data.paymasterAndData);
        
        // Set gas pricing for the test
        data.maxFeePerGas = maxFeePerGasValue;
        vm.txGasPrice(maxFeePerGasValue / 2); // Use half of maxFeePerGas as tx.gasprice
        vm.fee(1e8); // Set a high basefee to ensure maxFeePerGas is used
        
        // Add deposit to paymaster
        uint256 initialDeposit = maxGasLimit * maxFeePerGasValue * 2;
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).depositTo{value: initialDeposit}(address(data.paymaster));
        uint256 depositBefore = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).getDepositInfo(address(data.paymaster)).deposit;
        
        // Execute operation
        vm.prank(address(data.paymaster));
        IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).handleOps{gas: maxGasLimit}(data.ops, payable(address(this)));
        
        // Check deposit after execution
        uint256 depositAfter = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032).getDepositInfo(address(data.paymaster)).deposit;
        uint256 depositUsed = depositBefore - depositAfter;
        
        // Calculate expected post-op gas cost contribution
        uint256 expectedPostOpGasCost = postOpGasValue * maxFeePerGasValue;
        
        // Verify that at least the postOp gas cost was used
        // We don't check exact equality because there are other gas costs involved
        assertGt(depositUsed, expectedPostOpGasCost, "Deposit used should be greater than postOpGas * maxFeePerGas");
        
        // Log values for debugging/verification
        console2.log("Expected postOp contribution:", expectedPostOpGasCost);
        console2.log("Total deposit used:", depositUsed);
    }

    /// @notice Struct to hold test_refundDOS data to avoid stack too deep error
    struct RefundDOSTestData {
        address nexusAccount;
        uint256 amount;
        address[] hooksAddresses;
        bytes[] hooksData;
        ISuperExecutor.ExecutorEntry entry;
        uint256 maxGasLimit;
        uint256 maxFeePerGas;
        SuperNativePaymaster paymaster;
        uint128 paymasterVerificationGasLimit;
        uint128 paymasterPostOpGasLimit;
        bytes paymasterData;
        bytes paymasterAndData;
        PackedUserOperation[] ops;
        uint256 snapshotBeforeDos;
    }

    function test_refundDOS() public {
        RefundDOSTestData memory data;
        
        // create account
        data.nexusAccount = _createWithNexus(attesters, threshold, 0);

        // fund account
        vm.deal(data.nexusAccount, LARGE);

        data.amount = 10e18;

        // add tokens to account
        _getTokens(CHAIN_1_WETH, data.nexusAccount, data.amount);

        // create SuperExecutor data
        data.hooksAddresses = new address[](1);
        data.hooksData = new bytes[](1);
        data.hooksAddresses[0] = approveHook;
        data.hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), data.amount, false);
        data.entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: data.hooksAddresses, 
            hooksData: data.hooksData
        });

        // create paymaster 
        // set maxGasLimit
        // paymasterVerificationGasLimit + paymasterPostOpGasLimit + callGasLimit + verificationGasLimit + preVerificationGas
        // every value was set to 50e6, so in total we have 250e6
        data.maxGasLimit = 250e6;

        // maxFeePerGas is set to 40 gwei
        data.maxFeePerGas = 40 gwei;

        data.paymaster = new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        data.paymasterVerificationGasLimit = 50e6;
        data.paymasterPostOpGasLimit = 50e6;
        data.paymasterData = abi.encode(data.maxGasLimit, uint256(0), uint256(0)); // premium is zero
        data.paymasterAndData = abi.encodePacked(
            address(data.paymaster), 
            data.paymasterVerificationGasLimit, 
            data.paymasterPostOpGasLimit, 
            data.paymasterData
        );

        data.ops = _createUserOpWithPaymaster(data.nexusAccount, data.entry, data.paymasterAndData);

        data.snapshotBeforeDos = vm.snapshotState(); 

        // gasPrice in EntryPoint is `min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);`
        // our priorityFee is 4e6, and we set the 1e2 basefee
        // the tx.gasprice is 1e5, so maxPriorityFeePerGas + block.basefee covers the gas price
        vm.txGasPrice(1e5);
        vm.fee(1e2);

        // SuperBundler calls paymaster.handleOps() with maxGasLimit * maxFeePerGas ether value, as was paid by the account
        // but the execution will fail since deposit will not cover the refund
        vm.deal(address(this), data.maxGasLimit * data.maxFeePerGas);
        vm.recordLogs();
        data.paymaster.handleOps{gas: data.maxGasLimit, value: address(this).balance}(data.ops);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 expectedTopic = keccak256("SuperNativePaymasterRefund(address,uint256,uint256)");
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory log = entries[i];
            if (log.topics[0] == expectedTopic) {
                (uint256 refundAmount, uint256 initialRefund) = abi.decode(log.data, (uint256, uint256));
                assertEq(refundAmount, initialRefund);
                assertGt(refundAmount, 0);
            }
        }
    }

    function test_refundDOS_LessDeposit() public {
        RefundDOSTestData memory data;
        
        // create account
        data.nexusAccount = _createWithNexus(attesters, threshold, 0);

        // fund account
        vm.deal(data.nexusAccount, LARGE);

        data.amount = 10e18;

        // add tokens to account
        _getTokens(CHAIN_1_WETH, data.nexusAccount, data.amount);

        // create SuperExecutor data
        data.hooksAddresses = new address[](1);
        data.hooksData = new bytes[](1);
        data.hooksAddresses[0] = approveHook;
        data.hooksData[0] = _createApproveHookData(CHAIN_1_WETH, address(MANAGER), data.amount, false);
        data.entry = ISuperExecutor.ExecutorEntry({
            hooksAddresses: data.hooksAddresses, 
            hooksData: data.hooksData
        });

        // create paymaster 
        // set maxGasLimit
        // paymasterVerificationGasLimit + paymasterPostOpGasLimit + callGasLimit + verificationGasLimit + preVerificationGas
        // every value was set to 50e6, so in total we have 250e6
        data.maxGasLimit = 250e6;

        // maxFeePerGas is set to 40 gwei
        data.maxFeePerGas = 40 gwei;

        data.paymaster = new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032));
        data.paymasterVerificationGasLimit = 50e6;
        data.paymasterPostOpGasLimit = 50e6;
        data.paymasterData = abi.encode(data.maxGasLimit, uint256(0), uint256(0)); 
        data.paymasterAndData = abi.encodePacked(
            address(data.paymaster), 
            data.paymasterVerificationGasLimit, 
            data.paymasterPostOpGasLimit, 
            data.paymasterData
        );

        data.ops = _createUserOpWithPaymaster(data.nexusAccount, data.entry, data.paymasterAndData);

        data.snapshotBeforeDos = vm.snapshotState(); 

        // gasPrice in EntryPoint is `min(maxFeePerGas, maxPriorityFeePerGas + block.basefee);`
        // our priorityFee is 4e6, and we set the 1e2 basefee
        // the tx.gasprice is 1e5, so maxPriorityFeePerGas + block.basefee covers the gas price
        vm.txGasPrice(1e5);
        vm.fee(1e2);

        // SuperBundler calls paymaster.handleOps() with maxGasLimit * maxFeePerGas ether value, as was paid by the account
        // but the execution will fail since deposit will not cover the refund
        vm.deal(address(this), data.maxGasLimit * data.maxFeePerGas);

        vm.recordLogs();
        data.paymaster.handleOps{gas: data.maxGasLimit, value: 2e16}(data.ops);
        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes32 expectedTopic = keccak256("SuperNativePaymasterRefund(address,uint256,uint256)");
        for (uint256 i; i < entries.length; ++i) {
            Vm.Log memory log = entries[i];
            if (log.topics[0] == expectedTopic) {
                (uint256 refundAmount, uint256 initialRefund) = abi.decode(log.data, (uint256, uint256));
                assertEq(refundAmount, 0.007e18);
                assertGt(initialRefund, refundAmount);
                assertGt(refundAmount, 0);
            }
        }
    }


    receive() external payable {}
}
