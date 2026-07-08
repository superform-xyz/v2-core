// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";

import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { IPaymaster } from "@ERC4337/account-abstraction/contracts/interfaces/IPaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { SuperSponsorshipPaymaster } from "../../../src/paymaster/SuperSponsorshipPaymaster.sol";
import { ISuperSponsorshipPaymaster } from "../../../src/interfaces/ISuperSponsorshipPaymaster.sol";

/// @title MockSimpleAccount
/// @notice Minimal ERC-4337 account that validates any UserOp signed by its owner
contract MockSimpleAccount {
    address public immutable owner;
    IEntryPoint public immutable entryPoint;

    constructor(address owner_, IEntryPoint entryPoint_) {
        owner = owner_;
        entryPoint = entryPoint_;
    }

    function validateUserOp(
        PackedUserOperation calldata,
        bytes32, /* userOpHash */
        uint256 missingAccountFunds
    )
        external
        returns (uint256 validationData)
    {
        // Pay prefund if needed
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{ value: missingAccountFunds }("");
            require(success, "prefund failed");
        }
        // Always return success (0) for test simplicity
        return 0;
    }

    /// @dev The call target — just succeeds
    function doNothing() external { }

    receive() external payable { }
}

/// @title SuperSponsorshipPaymasterForkTest
/// @notice E2E fork tests against the real ERC-4337 v0.7 EntryPoint
/// @dev Uses forked Ethereum mainnet with the canonical EntryPoint at 0x0000000071727De22E5E9d8BAf0edAc6f37da032
contract SuperSponsorshipPaymasterForkTest is Test {
    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address constant ENTRYPOINT_ADDR = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    IEntryPoint public entryPoint;
    SuperSponsorshipPaymaster public paymaster;
    MockSimpleAccount public account;

    address public admin;
    address public funder;
    address public manager;
    address public bundler;
    address public strategy1;
    address public strategy2;

    address public accountOwner;
    uint256 public accountOwnerKey;

    /*//////////////////////////////////////////////////////////////
                            SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"));

        entryPoint = IEntryPoint(ENTRYPOINT_ADDR);

        admin = makeAddr("admin");
        funder = makeAddr("funder");
        manager = makeAddr("manager");
        bundler = makeAddr("bundler");
        strategy1 = makeAddr("strategy1");
        strategy2 = makeAddr("strategy2");

        (accountOwner, accountOwnerKey) = makeAddrAndKey("accountOwner");

        // Deploy paymaster
        paymaster = new SuperSponsorshipPaymaster(entryPoint, admin);

        // Grant roles
        vm.startPrank(admin);
        paymaster.grantRole(paymaster.FUNDING_ROLE(), funder);
        paymaster.grantRole(paymaster.MANAGER_ROLE(), manager);
        vm.stopPrank();

        // Deploy mock account
        account = new MockSimpleAccount(accountOwner, entryPoint);

        // Fund accounts
        vm.deal(admin, 100 ether);
        vm.deal(funder, 100 ether);
        vm.deal(bundler, 100 ether);
        vm.deal(address(account), 10 ether); // account needs ETH for potential prefund
    }

    /*//////////////////////////////////////////////////////////////
                    REAL ENTRYPOINT DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_DeploymentAgainstRealEntryPoint() public view {
        assertEq(address(paymaster.entryPoint()), ENTRYPOINT_ADDR);
        assertTrue(paymaster.hasRole(paymaster.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_Fork_GetDepositFromRealEntryPoint() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // getDeposit() calls real entryPoint.balanceOf(address(this))
        assertEq(paymaster.getDeposit(), 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    FUND / CREDIT / WITHDRAW VIA REAL EP
    //////////////////////////////////////////////////////////////*/

    function test_Fork_FundStrategy_DepositsToRealEntryPoint() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 3 ether }(strategy1);

        // Verify on real EntryPoint
        assertEq(entryPoint.balanceOf(address(paymaster)), 3 ether);
        assertEq(paymaster.totalAllocated(), 3 ether);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 3 ether);
    }

    function test_Fork_CreditStrategy_FromUnallocatedDeposit() public {
        // Fund strategy1 first
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        // Send ETH directly to paymaster and deposit to EP to create unallocated
        vm.deal(address(paymaster), 3 ether);
        vm.prank(address(paymaster));
        entryPoint.depositTo{ value: 3 ether }(address(paymaster));

        assertEq(paymaster.unallocatedBalance(), 3 ether);

        vm.prank(funder);
        paymaster.creditStrategy(strategy2, 2 ether);

        assertEq(paymaster.getStrategyBudget(strategy2).balance, 2 ether);
        assertEq(paymaster.unallocatedBalance(), 1 ether);
        assertEq(paymaster.totalAllocated(), 7 ether);
    }

    function test_Fork_WithdrawStrategyFunds_FromRealEntryPoint() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);

        address recipient = makeAddr("recipient");
        uint256 recipientBefore = recipient.balance;

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, 3 ether);

        // Verify real EP deposit decreased
        assertEq(entryPoint.balanceOf(address(paymaster)), 2 ether);
        assertEq(recipient.balance - recipientBefore, 3 ether);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 2 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    FULL E2E: REAL ENTRYPOINT handleOps
    //////////////////////////////////////////////////////////////*/

    function test_Fork_E2E_HandleOps_SponsoredUserOp() public {
        // 1. Fund strategy
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // 2. Build UserOp
        PackedUserOperation memory userOp = _buildUserOp(strategy1);

        // 3. Submit via real EntryPoint
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = userOp;

        uint256 strategyBalBefore = paymaster.getStrategyBudget(strategy1).balance;
        uint256 totalAllocBefore = paymaster.totalAllocated();

        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        // 4. Verify strategy was debited
        uint256 gasUsed = strategyBalBefore - paymaster.getStrategyBudget(strategy1).balance;
        assertTrue(gasUsed > 0, "Strategy should have been debited");
        assertEq(
            paymaster.getStrategyBudget(strategy1).totalDebited, gasUsed, "totalDebited should match"
        );
        assertEq(
            paymaster.totalAllocated(), totalAllocBefore - gasUsed, "totalAllocated should decrease"
        );
    }

    function test_Fork_E2E_HandleOps_MultipleStrategies() public {
        // Fund two strategies
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);
        paymaster.fundStrategy{ value: 5 ether }(strategy2);
        vm.stopPrank();

        // Build two UserOps for different strategies
        PackedUserOperation[] memory ops = new PackedUserOperation[](2);
        ops[0] = _buildUserOp(strategy1);
        ops[1] = _buildUserOpWithNonce(strategy2, 1);

        uint256 s1Before = paymaster.getStrategyBudget(strategy1).balance;
        uint256 s2Before = paymaster.getStrategyBudget(strategy2).balance;

        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        // Both should be debited independently
        assertTrue(paymaster.getStrategyBudget(strategy1).balance < s1Before, "Strategy1 should be debited");
        assertTrue(paymaster.getStrategyBudget(strategy2).balance < s2Before, "Strategy2 should be debited");
    }

    function test_Fork_E2E_HandleOps_InsufficientBudget_Reverts() public {
        // Fund with very small amount
        vm.prank(funder);
        paymaster.fundStrategy{ value: 0.0001 ether }(strategy1);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);

        // EntryPoint should revert because paymaster validation fails
        vm.prank(bundler);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(bundler));
    }

    function test_Fork_E2E_HandleOps_PausedStrategy_Reverts() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);

        // EntryPoint should revert because paymaster rejects paused strategy
        vm.prank(bundler);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(bundler));
    }

    function test_Fork_E2E_HandleOps_GlobalPaused_Reverts() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        vm.prank(admin);
        paymaster.setGlobalPause(true);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);

        vm.prank(bundler);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(bundler));
    }

    function test_Fork_E2E_HandleOps_ExceedsSingleOpCap_Reverts() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Set a very low per-op cap
        vm.prank(manager);
        paymaster.setMaxSingleOpCost(strategy1, 1); // 1 wei cap

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);

        vm.prank(bundler);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(bundler));
    }

    function test_Fork_E2E_HandleOps_WithPostOpOverhead() public {
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);

        // Set a reasonable overhead
        vm.prank(admin);
        paymaster.setPostOpGasOverhead(40_000);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);

        uint256 balBefore = paymaster.getStrategyBudget(strategy1).balance;

        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        uint256 gasUsed = balBefore - paymaster.getStrategyBudget(strategy1).balance;
        assertTrue(gasUsed > 0, "Should be debited with overhead");
    }

    /*//////////////////////////////////////////////////////////////
                    LIFECYCLE E2E TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fork_E2E_FullLifecycle() public {
        // 1. Fund strategy
        vm.prank(funder);
        paymaster.fundStrategy{ value: 10 ether }(strategy1);
        assertEq(paymaster.getStrategyBudget(strategy1).balance, 10 ether);

        // 2. Execute a sponsored UserOp
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);

        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        uint256 remainingBalance = paymaster.getStrategyBudget(strategy1).balance;
        uint256 totalDebited = paymaster.getStrategyBudget(strategy1).totalDebited;
        assertTrue(remainingBalance < 10 ether);
        assertTrue(totalDebited > 0);
        assertEq(remainingBalance + totalDebited, 10 ether);

        // 3. Pause strategy
        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        // 4. Verify new ops are rejected
        ops[0] = _buildUserOpWithNonce(strategy1, 1);
        vm.prank(bundler);
        vm.expectRevert();
        entryPoint.handleOps(ops, payable(bundler));

        // 5. Unpause and verify ops work again
        vm.prank(manager);
        paymaster.unpauseStrategy(strategy1);

        ops[0] = _buildUserOpWithNonce(strategy1, 1);
        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        // 6. Withdraw remaining funds
        // Note: internal balance slightly exceeds real EP deposit when postOpGasOverhead = 0,
        // because postOp's actualGasCost doesn't include the postOp gas itself.
        // Withdraw the actual EP deposit (which is the safe amount).
        address recipient = makeAddr("recipient");
        uint256 epDeposit = entryPoint.balanceOf(address(paymaster));
        uint256 internalBalance = paymaster.getStrategyBudget(strategy1).balance;

        // The internal balance should be >= EP deposit (we undercount gas used)
        assertTrue(internalBalance >= epDeposit, "Internal balance should be >= EP deposit");

        vm.prank(funder);
        paymaster.withdrawStrategyFunds(strategy1, recipient, epDeposit);

        assertEq(recipient.balance, epDeposit);
    }

    function test_Fork_E2E_MultiStrategy_Lifecycle() public {
        // Fund multiple strategies
        vm.startPrank(funder);
        paymaster.fundStrategy{ value: 5 ether }(strategy1);
        paymaster.fundStrategy{ value: 3 ether }(strategy2);
        vm.stopPrank();

        assertEq(paymaster.totalAllocated(), 8 ether);

        // Execute op on strategy1
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = _buildUserOp(strategy1);
        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        // Verify only strategy1 was debited
        assertTrue(paymaster.getStrategyBudget(strategy1).balance < 5 ether);
        assertEq(paymaster.getStrategyBudget(strategy2).balance, 3 ether);

        // Pause strategy1, execute on strategy2
        vm.prank(manager);
        paymaster.pauseStrategy(strategy1);

        ops[0] = _buildUserOpForStrategy2WithNonce(0);
        vm.prank(bundler);
        entryPoint.handleOps(ops, payable(bundler));

        assertTrue(paymaster.getStrategyBudget(strategy2).balance < 3 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    ENTRYPOINT STAKE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function test_Fork_AddStakeToEntryPoint() public {
        // The admin can deposit stake for the paymaster
        vm.deal(address(paymaster), 1 ether);
        vm.prank(address(paymaster));
        entryPoint.addStake{ value: 1 ether }(86_400);

        IEntryPoint.DepositInfo memory info = entryPoint.getDepositInfo(address(paymaster));
        assertEq(info.stake, 1 ether);
        assertTrue(info.staked);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildUserOp(address strategy) internal view returns (PackedUserOperation memory) {
        return _buildUserOpWithNonce(strategy, 0);
    }

    function _buildUserOpWithNonce(
        address strategy,
        uint256 nonce
    )
        internal
        view
        returns (PackedUserOperation memory)
    {
        // callData: account.doNothing()
        bytes memory callData = abi.encodeWithSelector(MockSimpleAccount.doNothing.selector);

        // paymasterAndData: [0:20] paymaster, [20:36] verificationGasLimit, [36:52] postOpGasLimit, [52:72] strategy
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster),
            uint128(500_000), // paymaster verification gas
            uint128(100_000), // paymaster postOp gas
            strategy
        );

        return PackedUserOperation({
            sender: address(account),
            nonce: nonce,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(500_000), uint128(500_000))),
            preVerificationGas: 100_000,
            gasFees: bytes32(abi.encodePacked(uint128(2 gwei), uint128(10 gwei))),
            paymasterAndData: paymasterAndData,
            signature: ""
        });
    }

    function _buildUserOpForStrategy2WithNonce(uint256 nonce) internal returns (PackedUserOperation memory) {
        // Need a separate account for strategy2 to avoid nonce conflicts
        MockSimpleAccount account2 = new MockSimpleAccount(accountOwner, entryPoint);
        vm.deal(address(account2), 10 ether);

        bytes memory callData = abi.encodeWithSelector(MockSimpleAccount.doNothing.selector);
        bytes memory paymasterAndData = abi.encodePacked(
            address(paymaster),
            uint128(500_000),
            uint128(100_000),
            strategy2
        );

        return PackedUserOperation({
            sender: address(account2),
            nonce: nonce,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(abi.encodePacked(uint128(500_000), uint128(500_000))),
            preVerificationGas: 100_000,
            gasFees: bytes32(abi.encodePacked(uint128(2 gwei), uint128(10 gwei))),
            paymasterAndData: paymasterAndData,
            signature: ""
        });
    }
}
