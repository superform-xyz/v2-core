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

        // Check initial balances
        uint256 initialETHBalance = accountEth.balance;
        uint256 initialWETHBalance = IERC20(weth).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  ETH:", initialETHBalance);
        console2.log("  WETH:", initialWETHBalance);

        // Prepare hook data: amount to deposit, don't use prev hook amount
        bytes memory hookData = abi.encodePacked(depositAmount, false);

        // Setup hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(depositWETHHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Execute the deposit operation
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 2e18);

        // Check final balances
        uint256 finalETHBalance = accountEth.balance;
        uint256 finalWETHBalance = IERC20(weth).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  ETH:", finalETHBalance);
        console2.log("  WETH:", finalWETHBalance);

        // Verify the deposit worked (allow for gas costs)
        assertLe(
            finalETHBalance,
            initialETHBalance - depositAmount + 0.01 ether,
            "ETH balance should decrease by approximately deposit amount"
        );
        assertEq(finalWETHBalance, initialWETHBalance + depositAmount, "WETH balance should increase by deposit amount");
    }

    /// @notice Test WETH to ETH conversion using WithdrawWETHHook
    function test_WithdrawWETHHook() public {
        console2.log("=== WithdrawWETHHook Test: WETH to ETH ===");

        // First, deposit some ETH to get WETH
        _depositETHToWETH(accountEth, 2 ether);

        // Check initial balances after deposit
        uint256 initialETHBalance = accountEth.balance;
        uint256 initialWETHBalance = IERC20(weth).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  ETH:", initialETHBalance);
        console2.log("  WETH:", initialWETHBalance);

        // Prepare hook data: amount to withdraw, don't use prev hook amount
        bytes memory hookData = abi.encodePacked(withdrawAmount, false);

        // Setup hook execution
        address[] memory hooksAddresses = new address[](1);
        hooksAddresses[0] = address(withdrawWETHHook);

        bytes[] memory hooksData = new bytes[](1);
        hooksData[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Fund the paymaster for gas fees
        vm.deal(address(superNativePaymaster), 10 ether);

        // Execute the withdrawal operation
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 2e18);

        // Check final balances
        uint256 finalETHBalance = accountEth.balance;
        uint256 finalWETHBalance = IERC20(weth).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  ETH:", finalETHBalance);
        console2.log("  WETH:", finalWETHBalance);

        // Verify the withdrawal worked (allow for gas costs)
        assertGe(
            finalETHBalance,
            initialETHBalance + withdrawAmount - 0.01 ether,
            "ETH balance should increase by approximately withdraw amount"
        );
        assertEq(
            finalWETHBalance, initialWETHBalance - withdrawAmount, "WETH balance should decrease by withdraw amount"
        );
    }

    /// @notice Test combined deposit and withdraw in a single transaction
    function test_DepositAndWithdrawWETH() public {
        console2.log("=== Combined DepositWETH and WithdrawWETH Test ===");

        // Check initial balances
        uint256 initialETHBalance = accountEth.balance;
        uint256 initialWETHBalance = IERC20(weth).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  ETH:", initialETHBalance);
        console2.log("  WETH:", initialWETHBalance);

        // Prepare hook data
        bytes memory depositHookData = abi.encodePacked(depositAmount, false);
        bytes memory withdrawHookData = abi.encodePacked(withdrawAmount, false);

        // Setup hook execution with both hooks
        address[] memory hooksAddresses = new address[](2);
        hooksAddresses[0] = address(depositWETHHook);
        hooksAddresses[1] = address(withdrawWETHHook);

        bytes[] memory hooksData = new bytes[](2);
        hooksData[0] = depositHookData;
        hooksData[1] = withdrawHookData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooksAddresses, hooksData: hooksData });
        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        // Fund the paymaster for gas fees
        vm.deal(address(superNativePaymaster), 10 ether);

        // Execute both operations
        executeOpsThroughPaymaster(userOpData, superNativePaymaster, 2e18);

        // Check final balances
        uint256 finalETHBalance = accountEth.balance;
        uint256 finalWETHBalance = IERC20(weth).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  ETH:", finalETHBalance);
        console2.log("  WETH:", finalWETHBalance);

        // Net effect: deposited more than withdrawn (allow for gas costs)
        uint256 netWETHIncrease = depositAmount - withdrawAmount;
        assertLe(
            finalETHBalance,
            initialETHBalance - netWETHIncrease + 0.01 ether,
            "ETH balance should decrease by approximately net amount"
        );
        assertEq(finalWETHBalance, initialWETHBalance + netWETHIncrease, "WETH balance should increase by net amount");
    }

    /// @notice Helper to deposit ETH to WETH directly
    function _depositETHToWETH(address account, uint256 amount) internal {
        vm.startPrank(account);
        (bool success,) = weth.call{ value: amount }(abi.encodeWithSignature("deposit()"));
        require(success, "WETH deposit failed");
        vm.stopPrank();
    }
}
