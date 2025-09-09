// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { UserOpData } from "modulekit/ModuleKit.sol";
import "forge-std/console2.sol";

// Superform
import { ISuperExecutor } from "../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "./MinimalBaseIntegrationTest.t.sol";
import { DepositWETHHook } from "../../src/hooks/tokens/weth/DepositWETHHook.sol";
import { WithdrawWETHHook } from "../../src/hooks/tokens/weth/WithdrawWETHHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

/// @title WETHHooksIntegrationTest
/// @notice Integration tests for WETH deposit and withdraw hooks
contract WETHHooksIntegrationTest is MinimalBaseIntegrationTest {
    DepositWETHHook public depositWETHHook;
    WithdrawWETHHook public withdrawWETHHook;
    ISuperNativePaymaster public superNativePaymaster;

    address public weth;
    uint256 public depositAmount;
    uint256 public withdrawAmount;

    /// @notice Struct to hold balance data for tests
    struct TestBalances {
        uint256 initialETH;
        uint256 initialWETH;
        uint256 finalETH;
        uint256 finalWETH;
    }

    /// @notice Struct to hold hook execution data
    struct HookExecutionData {
        bytes hookData;
        address[] hooksAddresses;
        bytes[] hooksData;
        ISuperExecutor.ExecutorEntry entry;
        UserOpData userOpData;
    }

    /// @notice Struct to hold combined test data
    struct CombinedTestData {
        bytes depositHookData;
        bytes withdrawHookData;
        uint256 netWETHIncrease;
    }

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        weth = CHAIN_1_WETH;

        // Deploy WETH hooks
        depositWETHHook = new DepositWETHHook(weth);
        withdrawWETHHook = new WithdrawWETHHook(weth);

        // Deploy SuperNativePaymaster
        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        depositAmount = 1 ether;
        withdrawAmount = 0.5 ether;

        // Give the account some ETH for testing
        vm.deal(accountEth, 10 ether);
    }

    receive() external payable { }

    /// @notice Test ETH to WETH conversion using DepositWETHHook
    function test_DepositWETHHook() public {
        console2.log("=== DepositWETHHook Test: ETH to WETH ===");

        TestBalances memory balances;
        HookExecutionData memory execData;

        // Check initial balances
        balances.initialETH = accountEth.balance;
        balances.initialWETH = IERC20(weth).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  ETH:", balances.initialETH);
        console2.log("  WETH:", balances.initialWETH);

        // Prepare hook data: amount to deposit, don't use prev hook amount
        execData.hookData = abi.encodePacked(depositAmount, false);

        // Setup hook execution
        execData.hooksAddresses = new address[](1);
        execData.hooksAddresses[0] = address(depositWETHHook);

        execData.hooksData = new bytes[](1);
        execData.hooksData[0] = execData.hookData;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        // Execute the deposit operation
        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        // Check final balances
        balances.finalETH = accountEth.balance;
        balances.finalWETH = IERC20(weth).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  ETH:", balances.finalETH);
        console2.log("  WETH:", balances.finalWETH);

        // Verify the deposit worked (allow for gas costs)
        assertLe(
            balances.finalETH,
            balances.initialETH - depositAmount + 0.01 ether,
            "ETH balance should decrease by approximately deposit amount"
        );
        assertEq(
            balances.finalWETH, balances.initialWETH + depositAmount, "WETH balance should increase by deposit amount"
        );
    }

    /// @notice Test WETH to ETH conversion using WithdrawWETHHook
    function test_WithdrawWETHHook() public {
        console2.log("=== WithdrawWETHHook Test: WETH to ETH ===");

        TestBalances memory balances;
        HookExecutionData memory execData;

        // First, deposit some ETH to get WETH
        _depositETHToWETH(accountEth, 2 ether);

        // Check initial balances after deposit
        balances.initialETH = accountEth.balance;
        balances.initialWETH = IERC20(weth).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  ETH:", balances.initialETH);
        console2.log("  WETH:", balances.initialWETH);

        // Prepare hook data: amount to withdraw, don't use prev hook amount
        execData.hookData = abi.encodePacked(withdrawAmount, false);

        // Setup hook execution
        execData.hooksAddresses = new address[](1);
        execData.hooksAddresses[0] = address(withdrawWETHHook);

        execData.hooksData = new bytes[](1);
        execData.hooksData[0] = execData.hookData;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        // Fund the paymaster for gas fees
        vm.deal(address(superNativePaymaster), 10 ether);

        // Execute the withdrawal operation
        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        // Check final balances
        balances.finalETH = accountEth.balance;
        balances.finalWETH = IERC20(weth).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  ETH:", balances.finalETH);
        console2.log("  WETH:", balances.finalWETH);

        // Verify the withdrawal worked (allow for gas costs)
        assertGe(
            balances.finalETH,
            balances.initialETH + withdrawAmount - 0.01 ether,
            "ETH balance should increase by approximately withdraw amount"
        );
        assertEq(
            balances.finalWETH, balances.initialWETH - withdrawAmount, "WETH balance should decrease by withdraw amount"
        );
    }

    /// @notice Test combined deposit and withdraw in a single transaction
    function test_DepositAndWithdrawWETH() public {
        console2.log("=== Combined DepositWETH and WithdrawWETH Test ===");

        TestBalances memory balances;
        HookExecutionData memory execData;
        CombinedTestData memory combinedData;

        // Check initial balances
        balances.initialETH = accountEth.balance;
        balances.initialWETH = IERC20(weth).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  ETH:", balances.initialETH);
        console2.log("  WETH:", balances.initialWETH);

        // Prepare hook data
        combinedData.depositHookData = abi.encodePacked(depositAmount, false);
        combinedData.withdrawHookData = abi.encodePacked(withdrawAmount, false);

        // Setup hook execution with both hooks
        execData.hooksAddresses = new address[](2);
        execData.hooksAddresses[0] = address(depositWETHHook);
        execData.hooksAddresses[1] = address(withdrawWETHHook);

        execData.hooksData = new bytes[](2);
        execData.hooksData[0] = combinedData.depositHookData;
        execData.hooksData[1] = combinedData.withdrawHookData;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        // Fund the paymaster for gas fees
        vm.deal(address(superNativePaymaster), 10 ether);

        // Execute both operations
        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        // Check final balances
        balances.finalETH = accountEth.balance;
        balances.finalWETH = IERC20(weth).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  ETH:", balances.finalETH);
        console2.log("  WETH:", balances.finalWETH);

        // Net effect: deposited more than withdrawn (allow for gas costs)
        combinedData.netWETHIncrease = depositAmount - withdrawAmount;
        assertLe(
            balances.finalETH,
            balances.initialETH - combinedData.netWETHIncrease + 0.01 ether,
            "ETH balance should decrease by approximately net amount"
        );
        assertEq(
            balances.finalWETH,
            balances.initialWETH + combinedData.netWETHIncrease,
            "WETH balance should increase by net amount"
        );
    }

    /// @notice Helper to deposit ETH to WETH directly
    function _depositETHToWETH(address account, uint256 amount) internal {
        vm.startPrank(account);
        (bool success,) = weth.call{ value: amount }(abi.encodeWithSignature("deposit()"));
        require(success, "WETH deposit failed");
        vm.stopPrank();
    }
}
