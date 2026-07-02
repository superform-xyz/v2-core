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
import { WrappedNativeHook } from "../../src/hooks/tokens/native/WrappedNativeHook.sol";
import { ISuperNativePaymaster } from "../../src/interfaces/ISuperNativePaymaster.sol";
import { SuperNativePaymaster } from "../../src/paymaster/SuperNativePaymaster.sol";

/// @title WrappedNativeHookIntegrationTest
/// @notice Integration tests for WrappedNativeHook (wrapping and unwrapping native tokens)
contract WrappedNativeHookIntegrationTest is MinimalBaseIntegrationTest {
    WrappedNativeHook public wrappedNativeHook;
    ISuperNativePaymaster public superNativePaymaster;

    address public wrappedNative;
    uint256 public wrapAmount;
    uint256 public unwrapAmount;

    /// @notice Struct to hold balance data for tests
    struct TestBalances {
        uint256 initialNative;
        uint256 initialWrapped;
        uint256 finalNative;
        uint256 finalWrapped;
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
        bytes wrapHookData;
        bytes unwrapHookData;
        uint256 netWrappedIncrease;
    }

    function setUp() public override {
        blockNumber = ETH_BLOCK;
        super.setUp();

        wrappedNative = CHAIN_1_WETH;

        wrappedNativeHook = new WrappedNativeHook(wrappedNative);

        superNativePaymaster = ISuperNativePaymaster(new SuperNativePaymaster(IEntryPoint(ENTRYPOINT_ADDR)));

        wrapAmount = 1 ether;
        unwrapAmount = 0.5 ether;

        vm.deal(accountEth, 10 ether);
    }

    receive() external payable { }

    /// @notice Test native -> wrapped native conversion (wrap)
    function test_Wrap() public {
        console2.log("=== WrappedNativeHook Test: native -> wrapped ===");

        TestBalances memory balances;
        HookExecutionData memory execData;

        balances.initialNative = accountEth.balance;
        balances.initialWrapped = IERC20(wrappedNative).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  Native:", balances.initialNative);
        console2.log("  Wrapped:", balances.initialWrapped);

        // wrap=true, usePrevHookAmount=false
        execData.hookData = abi.encodePacked(bytes32(0), address(0), wrapAmount, true, false);

        execData.hooksAddresses = new address[](1);
        execData.hooksAddresses[0] = address(wrappedNativeHook);

        execData.hooksData = new bytes[](1);
        execData.hooksData[0] = execData.hookData;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        balances.finalNative = accountEth.balance;
        balances.finalWrapped = IERC20(wrappedNative).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  Native:", balances.finalNative);
        console2.log("  Wrapped:", balances.finalWrapped);

        assertLe(
            balances.finalNative,
            balances.initialNative - wrapAmount + 0.01 ether,
            "Native balance should decrease by approximately wrap amount"
        );
        assertEq(
            balances.finalWrapped, balances.initialWrapped + wrapAmount, "Wrapped balance should increase by wrap amount"
        );
    }

    /// @notice Test wrapped native -> native conversion (unwrap)
    function test_Unwrap() public {
        console2.log("=== WrappedNativeHook Test: wrapped -> native ===");

        TestBalances memory balances;
        HookExecutionData memory execData;

        // First, get some wrapped native
        _wrapNative(accountEth, 2 ether);

        balances.initialNative = accountEth.balance;
        balances.initialWrapped = IERC20(wrappedNative).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  Native:", balances.initialNative);
        console2.log("  Wrapped:", balances.initialWrapped);

        // wrap=false, usePrevHookAmount=false
        execData.hookData = abi.encodePacked(bytes32(0), address(0), unwrapAmount, false, false);

        execData.hooksAddresses = new address[](1);
        execData.hooksAddresses[0] = address(wrappedNativeHook);

        execData.hooksData = new bytes[](1);
        execData.hooksData[0] = execData.hookData;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        vm.deal(address(superNativePaymaster), 10 ether);

        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        balances.finalNative = accountEth.balance;
        balances.finalWrapped = IERC20(wrappedNative).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  Native:", balances.finalNative);
        console2.log("  Wrapped:", balances.finalWrapped);

        assertGe(
            balances.finalNative,
            balances.initialNative + unwrapAmount - 0.01 ether,
            "Native balance should increase by approximately unwrap amount"
        );
        assertEq(
            balances.finalWrapped,
            balances.initialWrapped - unwrapAmount,
            "Wrapped balance should decrease by unwrap amount"
        );
    }

    /// @notice Test wrap and then unwrap in a single transaction
    function test_WrapAndUnwrap() public {
        console2.log("=== WrappedNativeHook Combined Test: wrap then unwrap ===");

        TestBalances memory balances;
        HookExecutionData memory execData;
        CombinedTestData memory combinedData;

        balances.initialNative = accountEth.balance;
        balances.initialWrapped = IERC20(wrappedNative).balanceOf(accountEth);

        console2.log("Initial balances:");
        console2.log("  Native:", balances.initialNative);
        console2.log("  Wrapped:", balances.initialWrapped);

        combinedData.wrapHookData = abi.encodePacked(bytes32(0), address(0), wrapAmount, true, false);
        combinedData.unwrapHookData = abi.encodePacked(bytes32(0), address(0), unwrapAmount, false, false);

        execData.hooksAddresses = new address[](2);
        execData.hooksAddresses[0] = address(wrappedNativeHook);
        execData.hooksAddresses[1] = address(wrappedNativeHook);

        execData.hooksData = new bytes[](2);
        execData.hooksData[0] = combinedData.wrapHookData;
        execData.hooksData[1] = combinedData.unwrapHookData;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        vm.deal(address(superNativePaymaster), 10 ether);

        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        balances.finalNative = accountEth.balance;
        balances.finalWrapped = IERC20(wrappedNative).balanceOf(accountEth);

        console2.log("Final balances:");
        console2.log("  Native:", balances.finalNative);
        console2.log("  Wrapped:", balances.finalWrapped);

        combinedData.netWrappedIncrease = wrapAmount - unwrapAmount;
        assertLe(
            balances.finalNative,
            balances.initialNative - combinedData.netWrappedIncrease + 0.01 ether,
            "Native balance should decrease by approximately net amount"
        );
        assertEq(
            balances.finalWrapped,
            balances.initialWrapped + combinedData.netWrappedIncrease,
            "Wrapped balance should increase by net amount"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for wrap direction
    function test_Wrap_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 1 ether;
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), originalAmount, true, false);

        assertEq(wrappedNativeHook.decodeAmounts(hookData)[0], originalAmount, "Wrap decodeAmount mismatch");

        uint256 newAmount = 0.5 ether;
        bytes memory replaced = wrappedNativeHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(wrappedNativeHook.decodeAmounts(replaced)[0], newAmount, "Wrap replaced amount mismatch");
        assertFalse(wrappedNativeHook.decodeUsePrevHookAmount(replaced), "usePrevHookAmount should be preserved");
    }

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for unwrap direction
    function test_Unwrap_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 1 ether;
        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), originalAmount, false, false);

        assertEq(wrappedNativeHook.decodeAmounts(hookData)[0], originalAmount, "Unwrap decodeAmount mismatch");

        uint256 newAmount = 0.5 ether;
        bytes memory replaced = wrappedNativeHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(wrappedNativeHook.decodeAmounts(replaced)[0], newAmount, "Unwrap replaced amount mismatch");
    }

    /// @notice Wrap: build with 1 ETH, replace to 0.5 ETH, execute, verify only 0.5 converted
    function test_Wrap_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        uint256 originalAmount = 1 ether;
        uint256 newAmount = 0.5 ether;

        bytes memory hookData = abi.encodePacked(bytes32(0), address(0), originalAmount, true, false);
        bytes memory replaced = wrappedNativeHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));

        HookExecutionData memory execData;
        execData.hooksAddresses = new address[](1);
        execData.hooksAddresses[0] = address(wrappedNativeHook);

        execData.hooksData = new bytes[](1);
        execData.hooksData[0] = replaced;

        execData.entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: execData.hooksAddresses, hooksData: execData.hooksData });
        execData.userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(execData.entry));

        uint256 wrappedBefore = IERC20(wrappedNative).balanceOf(accountEth);

        executeOpsThroughPaymaster(execData.userOpData, superNativePaymaster, 2e18);

        uint256 wrappedAfter = IERC20(wrappedNative).balanceOf(accountEth);

        assertEq(wrappedAfter - wrappedBefore, newAmount, "Should wrap exactly the replaced amount");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper to wrap native token directly (bypassing hook)
    function _wrapNative(address account, uint256 amount) internal {
        vm.startPrank(account);
        (bool success,) = wrappedNative.call{ value: amount }(abi.encodeWithSignature("deposit()"));
        require(success, "Native wrap failed");
        vm.stopPrank();
    }
}
