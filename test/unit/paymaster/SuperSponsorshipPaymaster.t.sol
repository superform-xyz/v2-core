// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@ERC4337/account-abstraction/contracts/interfaces/IPaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import { SuperSponsorshipPaymaster } from "../../../src/paymaster/SuperSponsorshipPaymaster.sol";
import { ISuperSponsorshipPaymaster } from "../../../src/interfaces/ISuperSponsorshipPaymaster.sol";
import { MockEntryPoint } from "../../mocks/MockEntryPoint.sol";
import { Helpers } from "../../utils/Helpers.sol";

contract SuperSponsorshipPaymasterTest is Helpers {
    SuperSponsorshipPaymaster public paymaster;
    MockEntryPoint public mockEntryPoint;

    address public admin;
    address public funder;
    address public manager;
    address public strategy1;
    address public strategy2;
    address public strategy3;
    address public recipient;
    address public randomUser;

    bytes32 public constant FUNDING_ROLE = keccak256("FUNDING_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    receive() external payable { }

    function setUp() public {
        mockEntryPoint = new MockEntryPoint();

        admin = makeAddr("admin");
        funder = makeAddr("funder");
        manager = makeAddr("manager");
        strategy1 = makeAddr("strategy1");
        strategy2 = makeAddr("strategy2");
        strategy3 = makeAddr("strategy3");
        recipient = makeAddr("recipient");
        randomUser = makeAddr("randomUser");

        paymaster = new SuperSponsorshipPaymaster(IEntryPoint(address(mockEntryPoint)), admin);

        // Grant roles
        vm.startPrank(admin);
        paymaster.grantRole(FUNDING_ROLE, funder);
        paymaster.grantRole(MANAGER_ROLE, manager);
        vm.stopPrank();

        // Set allowed senders for all strategies (default-deny requires explicit setup)
        vm.startPrank(manager);
        paymaster.setAllowedSender(strategy1, address(0xACC));
        paymaster.setAllowedSender(strategy2, address(0xACC));
        paymaster.setAllowedSender(strategy3, address(0xACC));
        vm.stopPrank();

        // Fund accounts
        vm.deal(admin, 100 ether);
        vm.deal(funder, 100 ether);
        vm.deal(randomUser, 100 ether);
        vm.deal(address(mockEntryPoint), 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(paymaster.entryPoint()), address(mockEntryPoint));
        assertTrue(paymaster.hasRole(paymaster.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(paymaster.hasRole(FUNDING_ROLE, admin));
        assertTrue(paymaster.hasRole(MANAGER_ROLE, admin));
    }

    function test_Constructor_RevertsZeroAdmin() public {
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        new SuperSponsorshipPaymaster(IEntryPoint(address(mockEntryPoint)), address(0));
    }

    function test_Constructor_RevertsZeroEntryPoint() public {
        vm.expectRevert();
        new SuperSponsorshipPaymaster(IEntryPoint(address(0)), admin);
    }

    function test_Constructor_GrantsAllRolesToAdmin() public view {
        assertTrue(paymaster.hasRole(paymaster.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(paymaster.hasRole(FUNDING_ROLE, admin));
        assertTrue(paymaster.hasRole(MANAGER_ROLE, admin));
    }

    function test_Constructor_SetsDefaultPostOpOverhead() public view {
        assertEq(paymaster.postOpGasOverhead(), paymaster.MIN_POST_OP_OVERHEAD());
        assertEq(paymaster.postOpGasOverhead(), 40_000);
    }

    /*//////////////////////////////////////////////////////////////
                        FUND STRATEGY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FundStrategy() public {
        uint256 amount = 1 ether;

        vm.prank(funder);
        paymaster.fundStrategy{ value: amount }(strategy1);

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance, amount);
        assertEq(paymaster.totalAllocated(), amount);
    }

    function test_FundStrategy_EmitsEvent() public {
        uint256 amount = 1 ether;

        vm.expectEmit(true, false, false, true);
        emit ISuperSponsorshipPaymaster.StrategyFunded(strategy1, amount);

        vm.prank(funder);
        paymaster.fundStrategy{ value: amount }(strategy1);
    }

    function test_FundStrategy_DepositsToEntryPoint() public {
        uint256 amount = 1 ether;

        vm.prank(funder);
        paymaster.fundStrategy{ value: amount }(strategy1);

        assertEq(mockEntryPoint.balanceOf(address(paymaster)), amount);
    }

    function test_FundStrategy_MultipleStrategies() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);
        paymaster.fundStrategy{ value: 2 ether }(strategy2);
        paymaster.fundStrategy{ value: 3 ether }(strategy3);
        vm.stopPrank();

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 1 ether);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 2 ether);
        assertEq(paymaster.getStrategyBudget(strategy3).balance, 3 ether);
        assertEq(paymaster.totalAllocated(), 6 ether);
    }

    function test_FundStrategy_AdditiveFunding() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);
        paymaster.fundStrategy{ value: 2 ether }(strategy1);
        vm.stopPrank();

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 3 ether);
        assertEq(paymaster.totalAllocated(), 3 ether);
    }

    function test_FundStrategy_RevertsZeroAddress() public {
        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.fundStrategy{ value: 1 ether }(address(0));
    }

    function test_FundStrategy_RevertsZeroAmount() public {
        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_AMOUNT.selector);
        paymaster.fundStrategy{ value: 0 }(strategy1);
    }

    function test_FundStrategy_RevertsNonFundingRole() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, FUNDING_ROLE
            )
        );
        paymaster.fundStrategy{ value: 1 ether }(strategy1);
    }

    function testFuzz_FundStrategy(uint256 amount) public {
        amount = bound(amount, 1, 50 ether);
        vm.deal(funder, amount);

        vm.prank(funder);
        paymaster.fundStrategy{ value: amount }(strategy1);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, amount);
        assertEq(paymaster.totalAllocated(), amount);
    }

    /*//////////////////////////////////////////////////////////////
                        CREDIT STRATEGY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreditStrategy() public {
        vm.deal(address(paymaster), 5 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 5 ether }(address(paymaster));

        vm.prank(funder);
        paymaster.creditStrategy(strategy1, 3 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 3 ether);
        assertEq(paymaster.totalAllocated(), 3 ether);
        assertEq(paymaster.unallocatedBalance(), 2 ether);
    }

    function test_CreditStrategy_EmitsEvent() public {
        vm.deal(address(paymaster), 5 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 5 ether }(address(paymaster));

        vm.expectEmit(true, false, false, true);
        emit ISuperSponsorshipPaymaster.StrategyCredited(strategy1, 3 ether);

        vm.prank(funder);
        paymaster.creditStrategy(strategy1, 3 ether);
    }

    function test_CreditStrategy_FromFundedThenCredited() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.deal(address(paymaster), 3 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 3 ether }(address(paymaster));

        vm.prank(funder);
        paymaster.creditStrategy(strategy2, 2 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 2 ether);
        assertEq(paymaster.totalAllocated(), 7 ether);
        assertEq(paymaster.unallocatedBalance(), 1 ether);
    }

    function test_CreditStrategy_RevertsZeroAddress() public {
        vm.deal(address(paymaster), 5 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 5 ether }(address(paymaster));

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.creditStrategy(address(0), 1 ether);
    }

    function test_CreditStrategy_RevertsZeroAmount() public {
        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_AMOUNT.selector);
        paymaster.creditStrategy(strategy1, 0);
    }

    function test_CreditStrategy_RevertsInsufficientUnallocated() public {
        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.INSUFFICIENT_UNALLOCATED_BALANCE.selector);
        paymaster.creditStrategy(strategy1, 1 ether);
    }

    function test_CreditStrategy_RevertsNonFundingRole() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, FUNDING_ROLE
            )
        );
        paymaster.creditStrategy(strategy1, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    WITHDRAW STRATEGY FUNDS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_WithdrawStrategyFunds() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        uint256 recipientBefore = recipient.balance;

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 3 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 2 ether);
        assertEq(paymaster.totalAllocated(), 2 ether);
        assertEq(recipient.balance - recipientBefore, 3 ether);
    }

    function test_WithdrawStrategyFunds_EmitsEvent() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.expectEmit(true, true, false, true);
        emit ISuperSponsorshipPaymaster.StrategyWithdrawn(strategy1, recipient, 3 ether);

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 3 ether);
    }

    function test_WithdrawStrategyFunds_FullBalance() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 5 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 0);
        assertEq(paymaster.totalAllocated(), 0);
    }

    function test_WithdrawStrategyFunds_RevertsZeroRecipient() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.withdrawStrategyFunds(strategy1, address(0), 1 ether);
    }

    function test_WithdrawStrategyFunds_RevertsZeroAmount() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_AMOUNT.selector);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 0);
    }

    function test_WithdrawStrategyFunds_RevertsExceedsBalance() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.WITHDRAW_EXCEEDS_BALANCE.selector);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 2 ether);
    }

    function test_WithdrawStrategyFunds_RevertsInsufficientEntryPointDeposit() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Simulate EP deposit being lower than internal balance (drift scenario)
        // Set EP deposit to 2 ETH while internal balance is 5 ETH
        mockEntryPoint.setDeposit(address(paymaster), 2 ether);

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.INSUFFICIENT_ENTRYPOINT_DEPOSIT.selector);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 3 ether);
    }

    function test_WithdrawStrategyFunds_RevertsNonFundingRole() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, FUNDING_ROLE
            )
        );
        paymaster.withdrawStrategyFunds(strategy1, recipient, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    VALIDATE PAYMASTER USER OP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ValidatePaymasterUserOp_Success() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);
        uint256 maxCost = 1 ether;

        vm.prank(address(mockEntryPoint));
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);

        assertEq(validationData, 0);
        (address decodedStrategy, uint256 decodedMaxCost) = abi.decode(context, (address, uint256));
        assertEq(decodedStrategy, strategy1);
        assertEq(decodedMaxCost, maxCost);
    }

    function test_ValidatePaymasterUserOp_ReturnsStrategyInContext() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy2);

        PackedUserOperation memory userOp = _createUserOp(strategy2);

        vm.prank(address(mockEntryPoint));
        (bytes memory context,) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);

        (address decodedStrategy,) = abi.decode(context, (address, uint256));
        assertEq(decodedStrategy, strategy2);
    }

    function test_ValidatePaymasterUserOp_ExactBudgetMatch() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);

        assertEq(validationData, 0);
    }

    function test_ValidatePaymasterUserOp_PreChargesBalance() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);
        uint256 maxCost = 2 ether;

        vm.prank(address(mockEntryPoint));
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);

        // Balance should be reduced by maxCost after validation
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 8 ether);
        assertEq(paymaster.totalAllocated(), 8 ether);
    }

    function test_ValidatePaymasterUserOp_BundleOverCommitmentPrevented() public {
        // Fund strategy with 1 ETH
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);
        uint256 maxCost = 0.5 ether;

        // First validation: pre-charges 0.5 ETH, balance = 0.5 ETH
        vm.prank(address(mockEntryPoint));
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 0.5 ether);

        // Second validation: pre-charges 0.5 ETH, balance = 0 ETH
        vm.prank(address(mockEntryPoint));
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 0);

        // Third validation: should revert (balance = 0 < 0.5 maxCost)
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INSUFFICIENT_STRATEGY_BUDGET.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
    }

    function test_ValidatePaymasterUserOp_RevertsGlobalPaused() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(admin);
        paymaster.setGlobalPause(true);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.GLOBAL_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    function test_ValidatePaymasterUserOp_RevertsStrategyPaused() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.STRATEGY_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    function test_ValidatePaymasterUserOp_RevertsInsufficientBudget() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 0.5 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INSUFFICIENT_STRATEGY_BUDGET.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    function test_ValidatePaymasterUserOp_RevertsExceedsSingleOpCap() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 0.5 ether);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_SINGLE_OP_CAP.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    function test_ValidatePaymasterUserOp_WithinSingleOpCap() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 2 ether);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(validationData, 0);
    }

    function test_ValidatePaymasterUserOp_DefaultCapWhenZeroMaxSingleOpCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        // DEFAULT_MAX_GAS * maxFeePerGas = 4_000_000 * 500 gwei = 2 ether — at boundary, should pass
        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 2 ether);
        assertEq(validationData, 0);
    }

    function test_ValidatePaymasterUserOp_RevertsNotEntryPoint() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(randomUser);
        vm.expectRevert("Sender not EntryPoint");
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            POST OP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PostOp_DebitsStrategy() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        uint256 actualGasCost = 0.01 ether;
        uint256 maxCost = 1 ether;

        // Validate first (pre-charges maxCost)
        bytes memory context = _validateOp(strategy1, maxCost);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        // Net effect: balance decreased by actualGasCost (overhead * 0 = 0)
        assertEq(budget.balance, 10 ether - actualGasCost);
        assertEq(budget.totalDebited, actualGasCost);
        assertEq(paymaster.totalAllocated(), 10 ether - actualGasCost);
    }

    function test_PostOp_EmitsEvent() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        uint256 actualGasCost = 0.01 ether;
        bytes memory context = _validateOp(strategy1, 1 ether);

        vm.expectEmit(true, false, false, true);
        emit ISuperSponsorshipPaymaster.StrategyDebited(strategy1, actualGasCost);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);
    }

    function test_PostOp_WithOverhead() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(admin);
        paymaster.setPostOpGasOverhead(50_000);

        uint256 actualGasCost = 0.01 ether;
        uint256 actualUserOpFeePerGas = 10 gwei;
        uint256 expectedCost = actualGasCost + (50_000 * actualUserOpFeePerGas);

        bytes memory context = _validateOp(strategy1, 2 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, actualUserOpFeePerGas);

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance, 10 ether - expectedCost);
        assertEq(budget.totalDebited, expectedCost);
    }

    function test_PostOp_WithDefaultOverhead() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Default overhead is MIN_POST_OP_OVERHEAD (40_000)
        uint256 actualGasCost = 0.01 ether;
        uint256 actualUserOpFeePerGas = 10 gwei;
        uint256 expectedCost = actualGasCost + (40_000 * actualUserOpFeePerGas);

        bytes memory context = _validateOp(strategy1, 2 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, actualUserOpFeePerGas);

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance, 10 ether - expectedCost);
    }

    function test_PostOp_CapsToMaxCostWhenTotalCostExceeds() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Set high overhead so totalCost > maxCost
        vm.prank(admin);
        paymaster.setPostOpGasOverhead(500_000);

        uint256 actualGasCost = 0.9 ether;
        uint256 feePerGas = 1 gwei;
        uint256 maxCost = 1 ether;

        // totalCost would be 0.9 ETH + (500_000 * 1 gwei) = 0.9 ETH + 0.0005 ETH = 0.9005 ETH
        // Which is < maxCost, so let's use a scenario where it actually exceeds
        // Use maxCost = 0.5 ETH, actualGasCost = 0.4 ETH, overhead = 500_000 * 1 gwei = 0.0005 ETH
        // totalCost = 0.4005 ETH < 0.5 ETH... still doesn't exceed

        // Let's use: maxCost small, overhead large
        maxCost = 0.01 ether;
        actualGasCost = 0.005 ether;
        feePerGas = 200 gwei;
        // totalCost = 0.005 + 500_000 * 200 gwei = 0.005 + 0.1 = 0.105 ETH > 0.01 maxCost

        bytes memory context = _validateOp(strategy1, maxCost);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, feePerGas);

        // totalCost should be capped to maxCost
        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.totalDebited, maxCost); // capped to maxCost
        assertEq(budget.balance, 10 ether - maxCost); // full maxCost debited
    }

    function test_PostOp_NeverRevertsWhenTotalCostExceedsMaxCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);

        vm.prank(admin);
        paymaster.setPostOpGasOverhead(500_000);

        uint256 maxCost = 0.5 ether;
        uint256 actualGasCost = 0.4 ether;
        uint256 feePerGas = 500 gwei;
        // totalCost = 0.4 + 500_000 * 500 gwei = 0.4 + 0.25 = 0.65 ETH > 0.5 maxCost

        bytes memory context = _validateOp(strategy1, maxCost);

        // Should NOT revert — totalCost is capped
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, feePerGas);

        // Verify capped behavior
        assertEq(paymaster.getStrategyBudget(strategy1).totalDebited, maxCost);
    }

    function test_PostOp_RefundsExcessAfterPreCharge() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 5 ether);

        uint256 maxCost = 5 ether;
        uint256 actualGasCost = 0.01 ether;

        // After validate: balance = 10 - 5 = 5 ETH
        bytes memory context = _validateOp(strategy1, maxCost);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);

        // After postOp: refund = 5 - 0.01 = 4.99, balance = 5 + 4.99 = 9.99 ETH
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, 0);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 9.99 ether);
        assertEq(paymaster.totalAllocated(), 9.99 ether);
    }

    function test_PostOp_AccumulatesTotalDebited() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.startPrank(address(mockEntryPoint));

        bytes memory ctx1 = _validateOpPranked(strategy1, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, 0.01 ether, 0);

        bytes memory ctx2 = _validateOpPranked(strategy1, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx2, 0.02 ether, 0);

        bytes memory ctx3 = _validateOpPranked(strategy1, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx3, 0.03 ether, 0);

        vm.stopPrank();

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.totalDebited, 0.06 ether);
        assertEq(budget.balance, 10 ether - 0.06 ether);
    }

    function test_PostOp_OpReverted_StillDebits() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        uint256 actualGasCost = 0.01 ether;
        bytes memory context = _validateOp(strategy1, 1 ether);

        // Even on opReverted, the paymaster pays
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opReverted, context, actualGasCost, 0);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 10 ether - actualGasCost);
    }

    function test_PostOp_RevertsNotEntryPoint() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);
        bytes memory context = _validateOp(strategy1, 1 ether);

        vm.prank(randomUser);
        vm.expectRevert("Sender not EntryPoint");
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 0.01 ether, 0);
    }

    function testFuzz_PostOp(uint256 gasCost) public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 50 ether }(strategy1);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap for high maxCost
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 11 ether);

        gasCost = bound(gasCost, 1, 10 ether);
        bytes memory context = _validateOp(strategy1, 11 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, gasCost, 0);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 50 ether - gasCost);
        assertEq(paymaster.getStrategyBudget(strategy1).totalDebited, gasCost);
    }

    /*//////////////////////////////////////////////////////////////
                    MANAGEMENT FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetMaxSingleOpCost() public {
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 0.5 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).maxSingleOpCost, 0.5 ether);
    }

    function test_SetMaxSingleOpCost_EmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit ISuperSponsorshipPaymaster.MaxSingleOpCostSet(strategy1, 0.5 ether);

        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 0.5 ether);
    }

    function test_SetMaxSingleOpCost_ResetToZero() public {
        vm.startPrank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 0.5 ether);
        paymaster.setMaxSingleOpCost(strategy1, 0);
        vm.stopPrank();

        assertEq(paymaster.getStrategyBudget(strategy1).maxSingleOpCost, 0);
    }

    function test_SetMaxSingleOpCost_RevertsNonManagerRole() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, MANAGER_ROLE
            )
        );
        paymaster.setMaxSingleOpCost(strategy1, 0.5 ether);
    }

    function test_SetMaxSingleOpCost_RevertsZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.setMaxSingleOpCost(address(0), 0.5 ether);
    }

    function test_PauseStrategy() public {
        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        assertTrue(paymaster.getStrategyBudget(strategy1).paused);
    }

    function test_PauseStrategy_EmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit ISuperSponsorshipPaymaster.StrategyPaused(strategy1);

        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);
    }

    function test_PauseStrategy_RevertsZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.pauseStrategy(address(0));
    }

    function test_UnpauseStrategy() public {
        vm.startPrank(manager);
        paymaster.pauseStrategy(strategy1);
        assertTrue(paymaster.getStrategyBudget(strategy1).paused);

        paymaster.unpauseStrategy(strategy1);
        assertFalse(paymaster.getStrategyBudget(strategy1).paused);
        vm.stopPrank();
    }

    function test_UnpauseStrategy_EmitsEvent() public {
        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        vm.expectEmit(true, false, false, false);
        emit ISuperSponsorshipPaymaster.StrategyUnpaused(strategy1);

        vm.prank(manager);
        paymaster.unpauseStrategy(strategy1);
    }

    function test_UnpauseStrategy_RevertsZeroAddress() public {
        vm.prank(manager);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.unpauseStrategy(address(0));
    }

    function test_PauseStrategy_RevertsNonManagerRole() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, MANAGER_ROLE
            )
        );
        paymaster.pauseStrategy(strategy1);
    }

    function test_UnpauseStrategy_RevertsNonManagerRole() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, MANAGER_ROLE
            )
        );
        paymaster.unpauseStrategy(strategy1);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetPostOpGasOverhead() public {
        vm.prank(admin);
        paymaster.setPostOpGasOverhead(50_000);

        assertEq(paymaster.postOpGasOverhead(), 50_000);
    }

    function test_SetPostOpGasOverhead_EmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit ISuperSponsorshipPaymaster.PostOpGasOverheadSet(50_000);

        vm.prank(admin);
        paymaster.setPostOpGasOverhead(50_000);
    }

    function test_SetPostOpGasOverhead_AcceptsMinValue() public {
        vm.prank(admin);
        paymaster.setPostOpGasOverhead(40_000);
        assertEq(paymaster.postOpGasOverhead(), 40_000);
    }

    function test_SetPostOpGasOverhead_AcceptsMaxValue() public {
        vm.prank(admin);
        paymaster.setPostOpGasOverhead(500_000);
        assertEq(paymaster.postOpGasOverhead(), 500_000);
    }

    function test_SetPostOpGasOverhead_RevertsBelowMinimum() public {
        vm.prank(admin);
        vm.expectRevert(ISuperSponsorshipPaymaster.POST_OP_OVERHEAD_BELOW_MINIMUM.selector);
        paymaster.setPostOpGasOverhead(39_999);
    }

    function test_SetPostOpGasOverhead_RevertsExceedsMax() public {
        vm.prank(admin);
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_MAX_POST_OP_OVERHEAD.selector);
        paymaster.setPostOpGasOverhead(500_001);
    }

    function test_SetPostOpGasOverhead_RevertsNonAdmin() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, bytes32(0)
            )
        );
        paymaster.setPostOpGasOverhead(50_000);
    }

    function test_SetGlobalPause_On() public {
        vm.prank(admin);
        paymaster.setGlobalPause(true);

        assertTrue(paymaster.globalPaused());
    }

    function test_SetGlobalPause_Off() public {
        vm.startPrank(admin);
        paymaster.setGlobalPause(true);
        paymaster.setGlobalPause(false);
        vm.stopPrank();

        assertFalse(paymaster.globalPaused());
    }

    function test_SetGlobalPause_EmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit ISuperSponsorshipPaymaster.GlobalPauseSet(true);

        vm.prank(admin);
        paymaster.setGlobalPause(true);
    }

    function test_SetGlobalPause_RevertsNonAdmin() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, bytes32(0)
            )
        );
        paymaster.setGlobalPause(true);
    }

    function test_SweepETH() public {
        vm.deal(address(paymaster), 2 ether);

        uint256 recipientBefore = recipient.balance;

        vm.prank(admin);
        paymaster.sweepETH(recipient);

        assertEq(recipient.balance - recipientBefore, 2 ether);
        assertEq(address(paymaster).balance, 0);
    }

    function test_SweepETH_EmitsEvent() public {
        vm.deal(address(paymaster), 2 ether);

        vm.expectEmit(true, false, false, true);
        emit ISuperSponsorshipPaymaster.ETHSwept(recipient, 2 ether);

        vm.prank(admin);
        paymaster.sweepETH(recipient);
    }

    function test_SweepETH_NoOpWhenZeroBalance() public {
        assertEq(address(paymaster).balance, 0);

        uint256 recipientBefore = recipient.balance;

        vm.prank(admin);
        paymaster.sweepETH(recipient);

        assertEq(recipient.balance, recipientBefore);
    }

    function test_SweepETH_RevertsZeroAddress() public {
        vm.deal(address(paymaster), 1 ether);

        vm.prank(admin);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.sweepETH(address(0));
    }

    function test_SweepETH_RevertsNonAdmin() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, bytes32(0)
            )
        );
        paymaster.sweepETH(recipient);
    }

    /*//////////////////////////////////////////////////////////////
                        RECONCILE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Reconcile_AdjustsTotalAllocated() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Simulate drift: reduce EP deposit below totalAllocated
        mockEntryPoint.setDeposit(address(paymaster), 8 ether);

        assertEq(paymaster.totalAllocated(), 10 ether);

        vm.prank(admin);
        paymaster.reconcile();

        assertEq(paymaster.totalAllocated(), 8 ether);
        // Auto-pauses when drift is corrected
        assertTrue(paymaster.globalPaused());
    }

    function test_Reconcile_EmitsEvent() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        mockEntryPoint.setDeposit(address(paymaster), 7 ether);

        vm.expectEmit(false, false, false, true);
        emit ISuperSponsorshipPaymaster.GlobalPauseSet(true);
        vm.expectEmit(false, false, false, true);
        emit ISuperSponsorshipPaymaster.Reconciled(3 ether);

        vm.prank(admin);
        paymaster.reconcile();
    }

    function test_Reconcile_NoOpWhenNoDrift() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // No drift: EP deposit == totalAllocated
        uint256 allocatedBefore = paymaster.totalAllocated();

        vm.prank(admin);
        paymaster.reconcile();

        assertEq(paymaster.totalAllocated(), allocatedBefore);
        // No drift → no auto-pause
        assertFalse(paymaster.globalPaused());
    }

    function test_Reconcile_RevertsNonAdmin() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, bytes32(0)
            )
        );
        paymaster.reconcile();
    }

    /*//////////////////////////////////////////////////////////////
                EMERGENCY WITHDRAW FROM ENTRYPOINT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EmergencyWithdrawFromEntryPoint() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        uint256 recipientBefore = recipient.balance;

        vm.prank(admin);
        paymaster.emergencyWithdrawFromEntryPoint(recipient, 3 ether);

        assertEq(recipient.balance - recipientBefore, 3 ether);
        assertEq(paymaster.totalAllocated(), 7 ether);
    }

    function test_EmergencyWithdrawFromEntryPoint_EmitsEvent() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.expectEmit(true, false, false, true);
        emit ISuperSponsorshipPaymaster.EmergencyWithdrawn(recipient, 3 ether);

        vm.prank(admin);
        paymaster.emergencyWithdrawFromEntryPoint(recipient, 3 ether);
    }

    function test_EmergencyWithdrawFromEntryPoint_CapsToTotalAllocated() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Add extra unallocated deposit
        vm.deal(address(paymaster), 3 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 3 ether }(address(paymaster));

        // Withdraw more than totalAllocated (5 ETH) but within EP deposit (8 ETH)
        vm.prank(admin);
        paymaster.emergencyWithdrawFromEntryPoint(recipient, 7 ether);

        // totalAllocated should be 0 (capped)
        assertEq(paymaster.totalAllocated(), 0);
    }

    function test_EmergencyWithdrawFromEntryPoint_RevertsZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.emergencyWithdrawFromEntryPoint(address(0), 1 ether);
    }

    function test_EmergencyWithdrawFromEntryPoint_RevertsZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_AMOUNT.selector);
        paymaster.emergencyWithdrawFromEntryPoint(recipient, 0);
    }

    function test_EmergencyWithdrawFromEntryPoint_RevertsNonAdmin() public {
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, randomUser, bytes32(0)
            )
        );
        paymaster.emergencyWithdrawFromEntryPoint(recipient, 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetStrategyBudget_DefaultValues() public view {
        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance, 0);
        assertEq(budget.totalDebited, 0);
        assertEq(budget.maxSingleOpCost, 0);
        assertFalse(budget.paused);
    }

    function test_GetStrategyBudget_AfterOperations() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 1 ether);

        bytes memory context = _validateOp(strategy1, 1 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 0.1 ether, 0);

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance, 4.9 ether);
        assertEq(budget.totalDebited, 0.1 ether);
        assertEq(budget.maxSingleOpCost, 1 ether);
        assertFalse(budget.paused);
    }

    function test_UnallocatedBalance_NoDeposits() public view {
        assertEq(paymaster.unallocatedBalance(), 0);
    }

    function test_UnallocatedBalance_AllAllocated() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        assertEq(paymaster.unallocatedBalance(), 0);
    }

    function test_UnallocatedBalance_Partial() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.deal(address(paymaster), 3 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 3 ether }(address(paymaster));

        assertEq(paymaster.unallocatedBalance(), 3 ether);
    }

    function test_UnallocatedBalance_AfterPostOpDebit() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        bytes memory context = _validateOp(strategy1, 2 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1 ether, 0);

        // EP still has 5 ether deposit (mock doesn't auto-debit)
        // totalAllocated = 5 - 1 = 4
        // unallocated = 5 - 4 = 1
        assertEq(paymaster.unallocatedBalance(), 1 ether);
    }

    function test_TotalAllocated_TracksFundAndWithdraw() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 3 ether }(strategy1);
        paymaster.fundStrategy{ value: 2 ether }(strategy2);
        assertEq(paymaster.totalAllocated(), 5 ether);

        paymaster.withdrawStrategyFunds(strategy1, recipient, 1 ether);
        assertEq(paymaster.totalAllocated(), 4 ether);
        vm.stopPrank();
    }

    function test_Receive_AcceptsETH() public {
        vm.deal(randomUser, 1 ether);
        vm.prank(randomUser);
        (bool success,) = address(paymaster).call{ value: 1 ether }("");
        assertTrue(success);
        assertEq(address(paymaster).balance, 1 ether);
    }

    function test_GetDeposit() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        assertEq(paymaster.getDeposit(), 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    SUPPORTS INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_IPaymaster() public view {
        assertTrue(paymaster.supportsInterface(type(IPaymaster).interfaceId));
    }

    function test_SupportsInterface_IAccessControl() public view {
        assertTrue(paymaster.supportsInterface(type(IAccessControl).interfaceId));
    }

    function test_SupportsInterface_IERC165() public view {
        assertTrue(paymaster.supportsInterface(type(IERC165).interfaceId));
    }

    function test_SupportsInterface_RandomInterfaceFails() public view {
        assertFalse(paymaster.supportsInterface(bytes4(0xdeadbeef)));
    }

    /*//////////////////////////////////////////////////////////////
                    ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AdminCanGrantFundingRole() public {
        address newFunder = makeAddr("newFunder");

        vm.prank(admin);
        paymaster.grantRole(FUNDING_ROLE, newFunder);

        assertTrue(paymaster.hasRole(FUNDING_ROLE, newFunder));
    }

    function test_AdminCanGrantManagerRole() public {
        address newManager = makeAddr("newManager");

        vm.prank(admin);
        paymaster.grantRole(MANAGER_ROLE, newManager);

        assertTrue(paymaster.hasRole(MANAGER_ROLE, newManager));
    }

    function test_AdminCanRevokeRoles() public {
        vm.startPrank(admin);
        paymaster.revokeRole(FUNDING_ROLE, funder);
        paymaster.revokeRole(MANAGER_ROLE, manager);
        vm.stopPrank();

        assertFalse(paymaster.hasRole(FUNDING_ROLE, funder));
        assertFalse(paymaster.hasRole(MANAGER_ROLE, manager));
    }

    function test_NonAdminCannotGrantRoles() public {
        address newFunder = makeAddr("newFunder");

        vm.prank(funder);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, funder, bytes32(0)
            )
        );
        paymaster.grantRole(FUNDING_ROLE, newFunder);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-STRATEGY FLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultiStrategy_IndependentBudgets() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);
        paymaster.fundStrategy{ value: 3 ether }(strategy2);
        vm.stopPrank();

        // Debit strategy1
        bytes memory ctx1 = _validateOp(strategy1, 2 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, 1 ether, 0);

        // strategy1 affected, strategy2 untouched
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 4 ether);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 3 ether);
        assertEq(paymaster.totalAllocated(), 7 ether);
    }

    function test_MultiStrategy_PauseIsolation() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);
        paymaster.fundStrategy{ value: 5 ether }(strategy2);
        vm.stopPrank();

        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        PackedUserOperation memory userOp1 = _createUserOp(strategy1);
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.STRATEGY_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp1, bytes32(0), 1 ether);

        PackedUserOperation memory userOp2 = _createUserOp(strategy2);
        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp2, bytes32(0), 1 ether);
        assertEq(validationData, 0);
    }

    function test_MultiStrategy_GlobalPauseAffectsAll() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);
        paymaster.fundStrategy{ value: 5 ether }(strategy2);
        vm.stopPrank();

        vm.prank(admin);
        paymaster.setGlobalPause(true);

        PackedUserOperation memory userOp1 = _createUserOp(strategy1);
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.GLOBAL_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp1, bytes32(0), 1 ether);

        PackedUserOperation memory userOp2 = _createUserOp(strategy2);
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.GLOBAL_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp2, bytes32(0), 1 ether);
    }

    function test_MultiStrategy_ConcurrentOps() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);
        paymaster.fundStrategy{ value: 5 ether }(strategy2);
        paymaster.fundStrategy{ value: 5 ether }(strategy3);
        vm.stopPrank();

        vm.startPrank(address(mockEntryPoint));
        bytes memory ctx1 = _validateOpPranked(strategy1, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, 0.1 ether, 0);
        bytes memory ctx2 = _validateOpPranked(strategy2, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx2, 0.2 ether, 0);
        bytes memory ctx3 = _validateOpPranked(strategy3, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx3, 0.3 ether, 0);
        vm.stopPrank();

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 4.9 ether);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 4.8 ether);
        assertEq(paymaster.getStrategyBudget(strategy3).balance, 4.7 ether);
        assertEq(paymaster.totalAllocated(), 14.4 ether);
    }

    function test_FullLifecycle_FundValidatePostOpWithdraw() public {
        // 1. Fund
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // 2. Validate (pre-charges)
        PackedUserOperation memory userOp = _createUserOp(strategy1);
        vm.prank(address(mockEntryPoint));
        (bytes memory context, uint256 validationData) =
            paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(validationData, 0);

        // 3. PostOp (refunds excess)
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 0.05 ether, 0);

        // 4. Check state
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 9.95 ether);
        assertEq(paymaster.getStrategyBudget(strategy1).totalDebited, 0.05 ether);
        assertEq(paymaster.totalAllocated(), 9.95 ether);

        // 5. Withdraw remaining
        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 9.95 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 0);
        assertEq(paymaster.totalAllocated(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    BOUNDARY CONDITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ValidatePaymasterUserOp_BudgetExactlyEqualsCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(validationData, 0);
    }

    function test_ValidatePaymasterUserOp_BudgetOneLessThanCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 ether - 1 }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INSUFFICIENT_STRATEGY_BUDGET.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    function test_ValidatePaymasterUserOp_MaxSingleOpCostExactlyEqualsCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 1 ether);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(validationData, 0);
    }

    function test_ValidatePaymasterUserOp_MaxSingleOpCostOneLessThanCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 1 ether - 1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_SINGLE_OP_CAP.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
    }

    function test_WithdrawStrategyFunds_ExactBalanceWithdraw() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 5 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 0);
        assertEq(paymaster.totalAllocated(), 0);
    }

    function test_WithdrawStrategyFunds_OneMoreThanBalance() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.WITHDRAW_EXCEEDS_BALANCE.selector);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 5 ether + 1);
    }

    function test_CreditStrategy_ExactUnallocatedBalance() public {
        vm.deal(address(paymaster), 5 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 5 ether }(address(paymaster));

        vm.prank(funder);
        paymaster.creditStrategy(strategy1, 5 ether);

        assertEq(paymaster.unallocatedBalance(), 0);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
    }

    function test_CreditStrategy_OneMoreThanUnallocated() public {
        vm.deal(address(paymaster), 5 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 5 ether }(address(paymaster));

        vm.prank(funder);
        vm.expectRevert(ISuperSponsorshipPaymaster.INSUFFICIENT_UNALLOCATED_BALANCE.selector);
        paymaster.creditStrategy(strategy1, 5 ether + 1);
    }

    /*//////////////////////////////////////////////////////////////
                    ARITHMETIC EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_PostOp_MinimalGasCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        bytes memory context = _validateOp(strategy1, 1 ether);

        // 1 wei gas cost
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 1, 0);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 10 ether - 1);
        assertEq(paymaster.getStrategyBudget(strategy1).totalDebited, 1);
    }

    function test_PostOp_OverheadWithLargeFeePerGas() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 100 ether }(strategy1);

        vm.prank(admin);
        paymaster.setPostOpGasOverhead(100_000);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap for high maxCost
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 10 ether);

        uint256 actualGasCost = 0.5 ether;
        uint256 feePerGas = 100 gwei;
        uint256 expectedCost = actualGasCost + (100_000 * feePerGas);

        bytes memory context = _validateOp(strategy1, 10 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, actualGasCost, feePerGas);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 100 ether - expectedCost);
    }

    function test_PostOp_ZeroGasCost() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        bytes memory context = _validateOp(strategy1, 1 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 0, 0);

        // Balance unchanged (0 gas cost + 0 overhead effect)
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 10 ether);
        assertEq(paymaster.getStrategyBudget(strategy1).totalDebited, 0);
    }

    function test_PostOp_ZeroGasCostWithOverhead() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(admin);
        paymaster.setPostOpGasOverhead(50_000);

        uint256 feePerGas = 10 gwei;
        uint256 expectedCost = 50_000 * feePerGas;

        bytes memory context = _validateOp(strategy1, 1 ether);

        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 0, feePerGas);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 10 ether - expectedCost);
    }

    function test_FundStrategy_SmallAmount() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 1 }(strategy1);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 1);
        assertEq(paymaster.totalAllocated(), 1);
    }

    function testFuzz_FundAndWithdraw(uint256 fundAmount, uint256 withdrawAmount) public {
        fundAmount = bound(fundAmount, 1, 50 ether);
        withdrawAmount = bound(withdrawAmount, 1, fundAmount);

        vm.deal(funder, fundAmount);

        vm.prank(funder);
        paymaster.fundStrategy{ value: fundAmount }(strategy1);

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, withdrawAmount);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, fundAmount - withdrawAmount);
        assertEq(paymaster.totalAllocated(), fundAmount - withdrawAmount);
    }

    function testFuzz_CreditStrategy(uint256 depositAmount, uint256 creditAmount) public {
        depositAmount = bound(depositAmount, 1, 50 ether);
        creditAmount = bound(creditAmount, 1, depositAmount);

        vm.deal(address(paymaster), depositAmount);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: depositAmount }(address(paymaster));

        vm.prank(funder);
        paymaster.creditStrategy(strategy1, creditAmount);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, creditAmount);
        assertEq(paymaster.unallocatedBalance(), depositAmount - creditAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    MULTI-OP SEQUENTIAL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MultipleValidateAndPostOp_SameStrategy() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Op 1: validate + postOp
        bytes memory ctx1 = _validateOp(strategy1, 2 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, 0.05 ether, 0);

        // Op 2: validate + postOp
        bytes memory ctx2 = _validateOp(strategy1, 2 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx2, 0.03 ether, 0);

        // Op 3: validate + postOp
        bytes memory ctx3 = _validateOp(strategy1, 2 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx3, 0.07 ether, 0);

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.totalDebited, 0.15 ether);
        assertEq(budget.balance, 9.85 ether);
        assertEq(paymaster.totalAllocated(), 9.85 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    ROLE TRANSITION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PauseUnpauseFlowWithOps() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        // Can validate
        vm.prank(address(mockEntryPoint));
        (, uint256 vd) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(vd, 0);

        // Pause
        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        // Cannot validate (budget was reduced by pre-charge above, but pause check comes first)
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.STRATEGY_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);

        // Unpause
        vm.prank(manager);
        paymaster.unpauseStrategy(strategy1);

        // Can validate again
        vm.prank(address(mockEntryPoint));
        (, vd) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(vd, 0);
    }

    function test_GlobalPauseUnpauseFlowWithOps() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        PackedUserOperation memory userOp = _createUserOp(strategy1);

        // Global pause
        vm.prank(admin);
        paymaster.setGlobalPause(true);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.GLOBAL_PAUSED.selector);
        paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);

        // Global unpause
        vm.prank(admin);
        paymaster.setGlobalPause(false);

        vm.prank(address(mockEntryPoint));
        (, uint256 vd) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), 1 ether);
        assertEq(vd, 0);
    }

    function test_RevokeRolePreventsAccess() public {
        vm.prank(admin);
        paymaster.revokeRole(FUNDING_ROLE, funder);

        vm.prank(funder);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, funder, FUNDING_ROLE)
        );
        paymaster.fundStrategy{ value: 1 ether }(strategy1);
    }

    function test_RevokeManagerRolePreventsManagement() public {
        vm.prank(admin);
        paymaster.revokeRole(MANAGER_ROLE, manager);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, manager, MANAGER_ROLE)
        );
        paymaster.pauseStrategy(strategy1);
    }

    /*//////////////////////////////////////////////////////////////
                    STATE INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Invariant_TotalAllocatedEqualsSumOfBalances() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 3 ether }(strategy1);
        paymaster.fundStrategy{ value: 2 ether }(strategy2);
        paymaster.fundStrategy{ value: 1 ether }(strategy3);
        vm.stopPrank();

        // Debit some
        vm.startPrank(address(mockEntryPoint));
        bytes memory ctx1 = _validateOpPranked(strategy1, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, 0.5 ether, 0);
        bytes memory ctx2 = _validateOpPranked(strategy2, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx2, 0.3 ether, 0);
        vm.stopPrank();

        // Withdraw some
        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy3, recipient, 0.5 ether);

        uint256 s1 = paymaster.getStrategyBudget(strategy1).balance;
        uint256 s2 = paymaster.getStrategyBudget(strategy2).balance;
        uint256 s3 = paymaster.getStrategyBudget(strategy3).balance;

        assertEq(paymaster.totalAllocated(), s1 + s2 + s3);
    }

    function test_Invariant_BalancePlusTotalDebitedEqualsOriginalFunding() public {
        uint256 fundAmount = 10 ether;

        vm.prank(funder);
        paymaster.fundStrategy{ value: fundAmount }(strategy1);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 10 ether);

        // Multiple debits
        vm.startPrank(address(mockEntryPoint));
        bytes memory ctx1 = _validateOpPranked(strategy1, 2 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, 1 ether, 0);
        bytes memory ctx2 = _validateOpPranked(strategy1, 3 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx2, 2 ether, 0);
        bytes memory ctx3 = _validateOpPranked(strategy1, 1 ether);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx3, 0.5 ether, 0);
        vm.stopPrank();

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance + budget.totalDebited, fundAmount);
    }

    function testFuzz_Invariant_BalancePlusTotalDebitedEqualsOriginal(
        uint256 fundAmount,
        uint256 debit1,
        uint256 debit2
    )
        public
    {
        fundAmount = bound(fundAmount, 1 ether, 50 ether);
        debit1 = bound(debit1, 0, fundAmount / 3);
        debit2 = bound(debit2, 0, fundAmount / 3);

        vm.deal(funder, fundAmount);
        vm.prank(funder);
        paymaster.fundStrategy{ value: fundAmount }(strategy1);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap for fuzzed values
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 50 ether);

        vm.startPrank(address(mockEntryPoint));
        bytes memory ctx1 = _validateOpPranked(strategy1, debit1 + 1);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx1, debit1, 0);
        bytes memory ctx2 = _validateOpPranked(strategy1, debit2 + 1);
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx2, debit2, 0);
        vm.stopPrank();

        ISuperSponsorshipPaymaster.StrategyBudget memory budget = paymaster.getStrategyBudget(strategy1);
        assertEq(budget.balance + budget.totalDebited, fundAmount);
    }

    function test_Invariant_UnallocatedBalancePlusTotalAllocatedEqualsDeposit() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.deal(address(paymaster), 3 ether);
        vm.prank(address(paymaster));
        mockEntryPoint.depositTo{ value: 3 ether }(address(paymaster));

        vm.prank(funder);
        paymaster.creditStrategy(strategy2, 1 ether);

        uint256 deposit = mockEntryPoint.balanceOf(address(paymaster));
        assertEq(paymaster.unallocatedBalance() + paymaster.totalAllocated(), deposit);
    }

    /*//////////////////////////////////////////////////////////////
                    SWEEP ETH EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_SweepETH_DoesNotAffectEntryPointDeposit() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.deal(address(paymaster), 2 ether);

        uint256 epDepositBefore = mockEntryPoint.balanceOf(address(paymaster));

        vm.prank(admin);
        paymaster.sweepETH(recipient);

        assertEq(mockEntryPoint.balanceOf(address(paymaster)), epDepositBefore);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
        assertEq(recipient.balance, 2 ether);
    }

    function test_SweepETH_MultipleCallsWithNewDeposits() public {
        vm.deal(address(paymaster), 1 ether);
        vm.prank(admin);
        paymaster.sweepETH(recipient);
        assertEq(recipient.balance, 1 ether);

        vm.deal(address(paymaster), 0.5 ether);
        vm.prank(admin);
        paymaster.sweepETH(recipient);
        assertEq(recipient.balance, 1.5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    FUND + CREDIT COMBINED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FundThenCredit_DifferentStrategies() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 10 ether);

        // Debit some from strategy1 (creates unallocated in mock)
        bytes memory context = _validateOp(strategy1, 4 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, context, 3 ether, 0);

        // Now unallocated = EP deposit - totalAllocated = 10 - 7 = 3
        assertEq(paymaster.unallocatedBalance(), 3 ether);

        // Credit strategy2 from unallocated
        vm.prank(funder);
        paymaster.creditStrategy(strategy2, 2 ether);

        assertEq(paymaster.getStrategyBudget(strategy2).balance, 2 ether);
        assertEq(paymaster.unallocatedBalance(), 1 ether);
    }

    function test_FundMultipleThenWithdrawAll() public {
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 3 ether }(strategy1);
        paymaster.fundStrategy{ value: 2 ether }(strategy2);
        paymaster.fundStrategy{ value: 1 ether }(strategy3);

        paymaster.withdrawStrategyFunds(strategy1, recipient, 3 ether);
        paymaster.withdrawStrategyFunds(strategy2, recipient, 2 ether);
        paymaster.withdrawStrategyFunds(strategy3, recipient, 1 ether);
        vm.stopPrank();

        assertEq(paymaster.totalAllocated(), 0);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 0);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 0);
        assertEq(paymaster.getStrategyBudget(strategy3).balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    MANAGEMENT STATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PauseAlreadyPausedStrategy() public {
        vm.startPrank(manager);
        paymaster.pauseStrategy(strategy1);
        paymaster.pauseStrategy(strategy1);
        vm.stopPrank();

        assertTrue(paymaster.getStrategyBudget(strategy1).paused);
    }

    function test_UnpauseAlreadyUnpausedStrategy() public {
        vm.prank(manager);
        paymaster.unpauseStrategy(strategy1);

        assertFalse(paymaster.getStrategyBudget(strategy1).paused);
    }

    function test_SetMaxSingleOpCost_UpdateExistingValue() public {
        vm.startPrank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 1 ether);
        assertEq(paymaster.getStrategyBudget(strategy1).maxSingleOpCost, 1 ether);

        paymaster.setMaxSingleOpCost(strategy1, 2 ether);
        assertEq(paymaster.getStrategyBudget(strategy1).maxSingleOpCost, 2 ether);
        vm.stopPrank();
    }

    function test_SetPostOpGasOverhead_UpdateValue() public {
        vm.startPrank(admin);
        paymaster.setPostOpGasOverhead(50_000);
        assertEq(paymaster.postOpGasOverhead(), 50_000);

        paymaster.setPostOpGasOverhead(100_000);
        assertEq(paymaster.postOpGasOverhead(), 100_000);

        paymaster.setPostOpGasOverhead(40_000);
        assertEq(paymaster.postOpGasOverhead(), 40_000);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                    RECEIVE + UNALLOCATED TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Receive_IncreasesContractBalanceNotDeposit() public {
        vm.deal(randomUser, 5 ether);
        vm.prank(randomUser);
        (bool success,) = address(paymaster).call{ value: 5 ether }("");
        assertTrue(success);

        assertEq(address(paymaster).balance, 5 ether);
        assertEq(mockEntryPoint.balanceOf(address(paymaster)), 0);
        assertEq(paymaster.unallocatedBalance(), 0);
    }

    function test_UnallocatedBalance_AfterWithdraw() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 4 ether);

        assertEq(paymaster.unallocatedBalance(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    FULL LIFECYCLE COMPLEX TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ComplexLifecycle_FundCreditDebitWithdraw() public {
        // 1. Fund strategy1 with 10 ETH
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Set explicit maxSingleOpCost to bypass DEFAULT_MAX_GAS cap
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 10 ether);

        // 2. Debit 2 ETH from strategy1 (creates unallocated in mock)
        bytes memory ctx = _validateOp(strategy1, 3 ether);
        vm.prank(address(mockEntryPoint));
        paymaster.postOp(IPaymaster.PostOpMode.opSucceeded, ctx, 2 ether, 0);

        // 3. Credit 1 ETH to strategy2 from unallocated
        vm.prank(funder);
        paymaster.creditStrategy(strategy2, 1 ether);

        // 4. Fund strategy3 with 3 ETH
        vm.prank(funder);
        paymaster.fundStrategy{ value: 3 ether }(strategy3);

        // 5. Verify state
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 8 ether);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 1 ether);
        assertEq(paymaster.getStrategyBudget(strategy3).balance, 3 ether);
        assertEq(paymaster.totalAllocated(), 12 ether);
        assertEq(paymaster.unallocatedBalance(), 1 ether); // 10 + 3 EP deposit - 12 allocated

        // 6. Withdraw from strategy1
        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 3 ether);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
        assertEq(paymaster.totalAllocated(), 9 ether);
    }

    function test_FundSameStrategyFromMultipleFunders() public {
        address funder2 = makeAddr("funder2");
        vm.deal(funder2, 100 ether);

        vm.prank(admin);
        paymaster.grantRole(FUNDING_ROLE, funder2);

        vm.prank(funder);
        paymaster.fundStrategy{ value: 3 ether }(strategy1);

        vm.prank(funder2);
        paymaster.fundStrategy{ value: 2 ether }(strategy1);

        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
        assertEq(paymaster.totalAllocated(), 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    ATTACK REPRODUCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reproduces the real attack: no-op UserOp (empty callData).
    ///      With the calldata validation, empty callData is rejected.
    function test_Attack_NoOpCallDataBlocked() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Attacker submits a no-op UserOp (empty callData, mimicking the real attack)
        PackedUserOperation memory attackOp = _createUserOpFull(strategy1, address(0xACC), 150_000, "");

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INVALID_CALLDATA.selector);
        paymaster.validatePaymasterUserOp(attackOp, bytes32(0), 1 ether);

        // Verify no funds were drained
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
    }

    /// @dev Attacker uses wrong selector (not Nexus.execute)
    function test_Attack_WrongSelectorBlocked() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Build calldata with wrong outer selector
        bytes memory badCallData = abi.encodeWithSelector(bytes4(0xdeadbeef), bytes32(0), bytes("dummy"));
        PackedUserOperation memory attackOp = _createUserOpFull(strategy1, address(0xACC), 150_000, badCallData);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INVALID_CALLDATA.selector);
        paymaster.validatePaymasterUserOp(attackOp, bytes32(0), 1 ether);
    }

    /// @dev Attacker uses correct Nexus selector but wrong execution target
    function test_Attack_WrongExecutionTargetBlocked() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Build calldata targeting a random address instead of the executor
        address fakeTarget = makeAddr("fakeTarget");
        bytes memory innerCallData = abi.encodeWithSelector(bytes4(0x09c5eabe), bytes(""));
        bytes memory executionCalldata = abi.encodePacked(fakeTarget, uint256(0), innerCallData);
        bytes memory badCallData = abi.encodeWithSelector(bytes4(0xe9ae5c53), bytes32(0), executionCalldata);

        PackedUserOperation memory attackOp = _createUserOpFull(strategy1, address(0xACC), 150_000, badCallData);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INVALID_CALLDATA.selector);
        paymaster.validatePaymasterUserOp(attackOp, bytes32(0), 1 ether);
    }

    /// @dev Attacker uses correct target but wrong inner selector (not SuperExecutor.execute)
    function test_Attack_WrongInnerSelectorBlocked() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        address executor = paymaster.DEFAULT_ALLOWED_SENDER();
        bytes memory innerCallData = abi.encodeWithSelector(bytes4(0xdeadbeef), bytes(""));
        bytes memory executionCalldata = abi.encodePacked(executor, uint256(0), innerCallData);
        bytes memory badCallData = abi.encodeWithSelector(bytes4(0xe9ae5c53), bytes32(0), executionCalldata);

        PackedUserOperation memory attackOp = _createUserOpFull(strategy1, address(0xACC), 150_000, badCallData);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INVALID_CALLDATA.selector);
        paymaster.validatePaymasterUserOp(attackOp, bytes32(0), 1 ether);
    }

    /// @dev Reproduces the real attack: inflated total gas with valid calldata.
    ///      DEFAULT_MAX_GAS * maxFeePerGas = 4M * 500 gwei = 2 ether cap.
    function test_Attack_InflatedGasLimitBlocked() public {
        // Fund the strategy (no maxSingleOpCost set, so DEFAULT_MAX_GAS applies)
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Attacker inflates total gas so maxCost exceeds DEFAULT_MAX_GAS * maxFeePerGas
        PackedUserOperation memory attackOp =
            _createUserOpWithSenderAndGas(strategy1, address(0xACC), 12_000_000);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_SINGLE_OP_CAP.selector);
        paymaster.validatePaymasterUserOp(attackOp, bytes32(0), 3 ether);

        // Verify no funds were drained
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
    }

    /// @dev Ensures maxCost at exactly DEFAULT_MAX_GAS * maxFeePerGas is allowed (boundary)
    function test_Attack_ExactDefaultMaxCostAllowed() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        PackedUserOperation memory op =
            _createUserOpWithSenderAndGas(strategy1, address(0xACC), 150_000);

        // DEFAULT_MAX_GAS * maxFeePerGas = 4_000_000 * 500 gwei = 2 ether (exact boundary)
        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(op, bytes32(0), 2 ether);
        assertEq(validationData, 0);
    }

    /// @dev Ensures maxCost at DEFAULT_MAX_GAS * maxFeePerGas + 1 is rejected (boundary)
    function test_Attack_OneOverDefaultMaxCostRejected() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        PackedUserOperation memory op =
            _createUserOpWithSenderAndGas(strategy1, address(0xACC), 150_000);

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_SINGLE_OP_CAP.selector);
        paymaster.validatePaymasterUserOp(op, bytes32(0), 2 ether + 1);
    }

    /// @dev When maxSingleOpCost is set, the DEFAULT_MAX_GAS check is bypassed
    ///      and the cost-based cap is used instead.
    function test_Attack_InflatedGasWithMaxSingleOpCostSet() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Set an explicit maxSingleOpCost — this disables the callGasLimit check
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 2 ether);

        // High callGasLimit is allowed since maxSingleOpCost is set and maxCost is within cap
        PackedUserOperation memory op =
            _createUserOpWithSenderAndGas(strategy1, address(0xACC), 12_000_000);

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(op, bytes32(0), 1 ether);
        assertEq(validationData, 0);

        // But if maxCost exceeds the cap, it reverts
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_SINGLE_OP_CAP.selector);
        paymaster.validatePaymasterUserOp(op, bytes32(0), 3 ether);
    }

    /// @dev The legitimate sender with valid calldata can submit UserOps
    function test_Attack_LegitimateCallSucceeds() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Valid calldata + allowed sender (set in setUp)
        PackedUserOperation memory op = _createUserOp(strategy1);

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(op, bytes32(0), 1 ether);
        assertEq(validationData, 0);
    }

    /// @dev Per-strategy sender override restricts userOp.sender
    function test_Attack_PerStrategySenderOverride() public {
        address allowedAccount = makeAddr("allowedAccount");

        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(manager);
        paymaster.setAllowedSender(strategy1, allowedAccount);

        // Wrong sender with valid calldata — rejected by sender check
        PackedUserOperation memory op = _createUserOpFull(strategy1, address(0xACC), 150_000, _validNexusCallData());

        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.UNAUTHORIZED_SENDER.selector);
        paymaster.validatePaymasterUserOp(op, bytes32(0), 1 ether);

        // Correct sender — passes
        PackedUserOperation memory op2 =
            _createUserOpFull(strategy1, allowedAccount, 150_000, _validNexusCallData());

        vm.prank(address(mockEntryPoint));
        (, uint256 validationData) = paymaster.validatePaymasterUserOp(op2, bytes32(0), 1 ether);
        assertEq(validationData, 0);
    }

    /// @dev Full attack scenario: all three defenses (calldata, sender, gas cap)
    function test_Attack_FullScenario_AllDefensesBlock() public {
        address allowedAccount = makeAddr("allowedAccount");

        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        vm.prank(manager);
        paymaster.setAllowedSender(strategy1, allowedAccount);

        // Attack vector 1: empty calldata (calldata check fires first)
        PackedUserOperation memory op1 = _createUserOpFull(strategy1, allowedAccount, 150_000, "");
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.INVALID_CALLDATA.selector);
        paymaster.validatePaymasterUserOp(op1, bytes32(0), 1 ether);

        // Attack vector 2: valid calldata, wrong sender (sender check fires)
        PackedUserOperation memory op2 =
            _createUserOpFull(strategy1, makeAddr("attacker"), 150_000, _validNexusCallData());
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.UNAUTHORIZED_SENDER.selector);
        paymaster.validatePaymasterUserOp(op2, bytes32(0), 1 ether);

        // Attack vector 3: valid calldata, correct sender, inflated maxCost (gas cap fires)
        PackedUserOperation memory op3 =
            _createUserOpFull(strategy1, allowedAccount, 12_000_000, _validNexusCallData());
        vm.prank(address(mockEntryPoint));
        vm.expectRevert(ISuperSponsorshipPaymaster.EXCEEDS_SINGLE_OP_CAP.selector);
        paymaster.validatePaymasterUserOp(op3, bytes32(0), 3 ether);

        // No funds drained in any case
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    ALLOWED SENDER MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetAllowedSender() public {
        address executor = makeAddr("executor");

        vm.prank(manager);
        vm.expectEmit(true, true, false, false);
        emit ISuperSponsorshipPaymaster.AllowedSenderSet(strategy1, executor);
        paymaster.setAllowedSender(strategy1, executor);

        assertEq(paymaster.allowedSender(strategy1), executor);
    }

    function test_SetAllowedSender_ResetToZeroBlocksAllOps() public {
        address executor = makeAddr("executor");

        vm.startPrank(manager);
        paymaster.setAllowedSender(strategy1, executor);
        assertEq(paymaster.allowedSender(strategy1), executor);

        // Setting to address(0) blocks all UserOps for this strategy (default-deny)
        paymaster.setAllowedSender(strategy1, address(0));
        assertEq(paymaster.allowedSender(strategy1), address(0));
        vm.stopPrank();
    }

    function test_SetAllowedSender_RevertsZeroStrategy() public {
        vm.prank(manager);
        vm.expectRevert(ISuperSponsorshipPaymaster.ZERO_ADDRESS.selector);
        paymaster.setAllowedSender(address(0), makeAddr("executor"));
    }

    function test_SetAllowedSender_RevertsUnauthorized() public {
        vm.prank(randomUser);
        vm.expectRevert();
        paymaster.setAllowedSender(strategy1, makeAddr("executor"));
    }

    /*//////////////////////////////////////////////////////////////
                          HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Validates a UserOp and returns the context (already pranked as EP)
    function _validateOp(address strategy, uint256 maxCost) internal returns (bytes memory context) {
        PackedUserOperation memory userOp = _createUserOp(strategy);
        vm.prank(address(mockEntryPoint));
        (context,) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
    }

    /// @dev Validates a UserOp without setting prank (caller must be already pranked as EP)
    function _validateOpPranked(address strategy, uint256 maxCost) internal returns (bytes memory context) {
        PackedUserOperation memory userOp = _createUserOp(strategy);
        (context,) = paymaster.validatePaymasterUserOp(userOp, bytes32(0), maxCost);
    }

    function _createUserOp(address strategy) internal view returns (PackedUserOperation memory) {
        return _createUserOpFull(strategy, address(0xACC), 150_000, _validNexusCallData());
    }

    /// @dev Creates a UserOp with custom sender and callGasLimit for attack reproduction tests
    function _createUserOpWithSenderAndGas(
        address strategy,
        address sender,
        uint128 callGasLimit
    )
        internal
        view
        returns (PackedUserOperation memory)
    {
        return _createUserOpFull(strategy, sender, callGasLimit, _validNexusCallData());
    }

    /// @dev Creates a UserOp with custom sender, callGasLimit, and callData
    function _createUserOpFull(
        address strategy,
        address sender,
        uint128 callGasLimit,
        bytes memory callData
    )
        internal
        view
        returns (PackedUserOperation memory)
    {
        PackedUserOperation memory op;
        op.sender = sender;
        op.nonce = 0;
        op.initCode = "";
        op.callData = callData;
        op.accountGasLimits = bytes32(abi.encodePacked(uint128(100_000), callGasLimit));
        op.preVerificationGas = 50_000;
        op.gasFees = bytes32(abi.encodePacked(uint128(10 gwei), uint128(500 gwei)));
        op.paymasterAndData = abi.encodePacked(
            address(paymaster),
            uint128(100_000),
            uint128(50_000),
            strategy
        );
        op.signature = "";
        return op;
    }

    /// @dev Builds valid Nexus.execute(mode, executionCalldata) callData that passes
    ///      the paymaster's calldata validation: correct selectors and target.
    ///      Layout: [0:4] Nexus.execute selector, [4:36] mode, [36:68] offset,
    ///      [68:100] len, [100:120] target, [120:152] value, [152:156] inner selector, [156:] data
    function _validNexusCallData() internal view returns (bytes memory) {
        address executor = paymaster.DEFAULT_ALLOWED_SENDER();
        // Inner calldata: SuperExecutor.execute(bytes) with empty data
        bytes memory innerCallData = abi.encodeWithSelector(bytes4(0x09c5eabe), bytes(""));
        // executionCalldata: packed as [target(20)] [value(32)] [calldata(variable)]
        bytes memory executionCalldata = abi.encodePacked(executor, uint256(0), innerCallData);
        // Nexus.execute(ExecutionMode mode, bytes executionCalldata)
        bytes memory nexusCallData = abi.encodeWithSelector(bytes4(0xe9ae5c53), bytes32(0), executionCalldata);
        return nexusCallData;
    }
}
