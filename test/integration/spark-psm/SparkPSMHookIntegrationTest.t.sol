// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapSparkPSMExactInHook } from "../../../src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol";
import {
    ApproveAndSwapSparkPSMExactInHook
} from "../../../src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactInHook.sol";
import { SwapSparkPSMExactOutHook } from "../../../src/hooks/swappers/spark-psm/SwapSparkPSMExactOutHook.sol";
import {
    ApproveAndSwapSparkPSMExactOutHook
} from "../../../src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactOutHook.sol";
import { IPSM3 } from "../../../src/vendor/spark/IPSM3.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { Constants } from "../../utils/Constants.sol";

import "forge-std/console2.sol";

/// @title SparkPSMHookIntegrationTest
/// @notice Integration tests for Spark PSM hooks using a real Base fork
/// @dev Tests actual swaps against the deployed PSM3 contract on Base
///      Requires BASE_RPC_URL environment variable
contract SparkPSMHookIntegrationTest is Test, Constants {
    function _singleAmount(uint256 amt) internal pure returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = amt;
    }

    SwapSparkPSMExactInHook public swapExactInHook;
    ApproveAndSwapSparkPSMExactInHook public approveAndSwapExactInHook;
    SwapSparkPSMExactOutHook public swapExactOutHook;
    ApproveAndSwapSparkPSMExactOutHook public approveAndSwapExactOutHook;

    IPSM3 public psm;
    address public account;

    address public constant USDC = CHAIN_8453_USDC;
    address public constant USDS = CHAIN_8453_USDS;
    address public constant SUSDS = CHAIN_8453_SUSDS;
    address public constant PSM_ADDRESS = CHAIN_8453_SPARK_PSM3;

    uint256 public constant REFERRAL_CODE = 0;

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY));

        psm = IPSM3(PSM_ADDRESS);
        account = address(this);

        swapExactInHook = new SwapSparkPSMExactInHook(PSM_ADDRESS);
        approveAndSwapExactInHook = new ApproveAndSwapSparkPSMExactInHook(PSM_ADDRESS);
        swapExactOutHook = new SwapSparkPSMExactOutHook(PSM_ADDRESS);
        approveAndSwapExactOutHook = new ApproveAndSwapSparkPSMExactOutHook(PSM_ADDRESS);
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildExactInHookData(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes32(0), // yieldSourceOracleId (52-byte header)
            bytes20(address(0)), // yieldSource (52-byte header)
            bytes20(assetIn),
            bytes20(assetOut),
            bytes32(amountIn),
            bytes32(minAmountOut),
            bytes20(account), // receiver (ignored, forced to account)
            bytes32(REFERRAL_CODE),
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00)
        );
    }

    function _buildExactOutHookData(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes32(0), // yieldSourceOracleId (52-byte header)
            bytes20(address(0)), // yieldSource (52-byte header)
            bytes20(assetIn),
            bytes20(assetOut),
            bytes32(amountOut),
            bytes32(maxAmountIn),
            bytes20(account),
            bytes32(REFERRAL_CODE),
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00)
        );
    }

    /// @notice Execute an array of Execution structs as this contract (simulating smart account)
    function _executeAll(Execution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success, bytes memory returndata) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    EXACT IN: USDC -> USDS (1:1)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndSwapExactIn: USDC -> USDS via real PSM
    function test_ApproveAndSwapExactIn_USDC_to_USDS() public {
        uint256 amountIn = 1000e6; // 1000 USDC
        // PSM does 1:1 with decimal adjustment: 1000 USDC (6 dec) = 1000 USDS (18 dec)
        uint256 minAmountOut = 999e18; // Allow 1 USDS slippage for rounding

        deal(USDC, account, amountIn);

        uint256 initialUSDC = IERC20(USDC).balanceOf(account);
        uint256 initialUSDS = IERC20(USDS).balanceOf(account);

        bytes memory hookData = _buildExactInHookData(USDC, USDS, amountIn, minAmountOut, false);

        // Build executions (includes preExecute, approve(0), approve(amt), swap, approve(0), postExecute)
        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "Should have 6 executions");

        // Execute all
        _executeAll(executions);

        uint256 finalUSDC = IERC20(USDC).balanceOf(account);
        uint256 finalUSDS = IERC20(USDS).balanceOf(account);

        uint256 usdcSpent = initialUSDC - finalUSDC;
        uint256 usdsReceived = finalUSDS - initialUSDS;

        console2.log("USDC spent:", usdcSpent);
        console2.log("USDS received:", usdsReceived);

        assertEq(usdcSpent, amountIn, "Should spend exact USDC");
        assertGe(usdsReceived, minAmountOut, "Should receive at least minAmountOut USDS");
        // 1:1 rate: 1000 USDC should give exactly 1000e18 USDS
        assertEq(usdsReceived, 1000e18, "Should receive exactly 1000 USDS");

        // Verify no residual approval
        assertEq(IERC20(USDC).allowance(account, PSM_ADDRESS), 0, "No residual USDC approval");

        // Verify outAmount tracking
        uint256 trackedOutAmount = approveAndSwapExactInHook.getOutAmount(account);
        assertEq(trackedOutAmount, usdsReceived, "outAmount should match received USDS");
    }

    /// @notice Test ApproveAndSwapExactIn: USDS -> USDC via real PSM
    function test_ApproveAndSwapExactIn_USDS_to_USDC() public {
        uint256 amountIn = 1000e18; // 1000 USDS
        uint256 minAmountOut = 999e6; // Allow slippage

        deal(USDS, account, amountIn);

        uint256 initialUSDS = IERC20(USDS).balanceOf(account);
        uint256 initialUSDC = IERC20(USDC).balanceOf(account);

        bytes memory hookData = _buildExactInHookData(USDS, USDC, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 usdsSpent = initialUSDS - IERC20(USDS).balanceOf(account);
        uint256 usdcReceived = IERC20(USDC).balanceOf(account) - initialUSDC;

        console2.log("USDS spent:", usdsSpent);
        console2.log("USDC received:", usdcReceived);

        assertEq(usdsSpent, amountIn, "Should spend exact USDS");
        assertGe(usdcReceived, minAmountOut, "Should receive at least minAmountOut USDC");
        // 1:1 rate: 1000 USDS (18 dec) -> 1000 USDC (6 dec)
        assertEq(usdcReceived, 1000e6, "Should receive exactly 1000 USDC");
        assertEq(IERC20(USDS).allowance(account, PSM_ADDRESS), 0, "No residual approval");
    }

    /*//////////////////////////////////////////////////////////////
                    EXACT IN: sUSDS swaps (oracle rate)
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndSwapExactIn: USDC -> sUSDS via real PSM (oracle rate)
    function test_ApproveAndSwapExactIn_USDC_to_sUSDS() public {
        uint256 amountIn = 1000e6; // 1000 USDC

        deal(USDC, account, amountIn);
        // Ensure PSM has enough sUSDS liquidity
        deal(SUSDS, PSM_ADDRESS, 10_000e18);

        // Preview to get expected output
        uint256 expectedOut = psm.previewSwapExactIn(USDC, SUSDS, amountIn);
        // Allow 1 wei slippage (PSM rounding)
        uint256 minAmountOut = expectedOut > 0 ? expectedOut - 1 : 0;

        uint256 initialSUSDS = IERC20(SUSDS).balanceOf(account);

        bytes memory hookData = _buildExactInHookData(USDC, SUSDS, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 susdsReceived = IERC20(SUSDS).balanceOf(account) - initialSUSDS;

        console2.log("Expected sUSDS:", expectedOut);
        console2.log("Actual sUSDS received:", susdsReceived);

        assertGt(susdsReceived, 0, "Should receive sUSDS");
        assertGe(susdsReceived, minAmountOut, "Should meet slippage");
        // sUSDS is oracle-based, so amount < 1000e18 (since sUSDS appreciates)
        assertLt(susdsReceived, 1000e18, "sUSDS should be less than 1:1 (oracle rate)");
        assertEq(IERC20(USDC).allowance(account, PSM_ADDRESS), 0, "No residual approval");
    }

    /*//////////////////////////////////////////////////////////////
                    EXACT OUT: USDC -> USDS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndSwapExactOut: want exactly 1000 USDS, pay USDC
    function test_ApproveAndSwapExactOut_USDC_to_USDS() public {
        uint256 amountOut = 1000e18; // Want exactly 1000 USDS
        // Preview to get expected input needed
        uint256 expectedIn = psm.previewSwapExactOut(USDC, USDS, amountOut);
        uint256 maxAmountIn = expectedIn + 2; // 2 wei buffer for rounding

        deal(USDC, account, maxAmountIn);

        uint256 initialUSDC = IERC20(USDC).balanceOf(account);
        uint256 initialUSDS = IERC20(USDS).balanceOf(account);

        bytes memory hookData = _buildExactOutHookData(USDC, USDS, amountOut, maxAmountIn, false);

        Execution[] memory executions = approveAndSwapExactOutHook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "Should have 6 executions");

        _executeAll(executions);

        uint256 usdcSpent = initialUSDC - IERC20(USDC).balanceOf(account);
        uint256 usdsReceived = IERC20(USDS).balanceOf(account) - initialUSDS;

        console2.log("USDC spent:", usdcSpent);
        console2.log("USDS received:", usdsReceived);

        assertLe(usdcSpent, maxAmountIn, "Should not exceed maxAmountIn");
        assertEq(usdsReceived, amountOut, "Should receive exact amountOut USDS");
        assertEq(IERC20(USDC).allowance(account, PSM_ADDRESS), 0, "No residual approval");

        // Verify outAmount tracking
        uint256 trackedOutAmount = approveAndSwapExactOutHook.getOutAmount(account);
        assertEq(trackedOutAmount, usdsReceived, "outAmount should match received USDS");
    }

    /// @notice Test ApproveAndSwapExactOut: want sUSDS, pay USDC (oracle rate)
    function test_ApproveAndSwapExactOut_USDC_to_sUSDS() public {
        uint256 amountOut = 500e18; // Want 500 sUSDS

        // Ensure PSM has enough sUSDS liquidity
        deal(SUSDS, PSM_ADDRESS, 10_000e18);

        uint256 expectedIn = psm.previewSwapExactOut(USDC, SUSDS, amountOut);
        uint256 maxAmountIn = expectedIn + 2; // Buffer for rounding

        deal(USDC, account, maxAmountIn);

        uint256 initialSUSDS = IERC20(SUSDS).balanceOf(account);

        bytes memory hookData = _buildExactOutHookData(USDC, SUSDS, amountOut, maxAmountIn, false);

        Execution[] memory executions = approveAndSwapExactOutHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 susdsReceived = IERC20(SUSDS).balanceOf(account) - initialSUSDS;

        console2.log("Expected input USDC:", expectedIn);
        console2.log("sUSDS received:", susdsReceived);

        assertEq(susdsReceived, amountOut, "Should receive exact sUSDS amount");
        assertEq(IERC20(USDC).allowance(account, PSM_ADDRESS), 0, "No residual approval");
    }

    /*//////////////////////////////////////////////////////////////
                    PRE-APPROVED SWAP HOOKS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test SwapExactIn (pre-approved): USDC -> USDS
    function test_SwapExactIn_PreApproved_USDC_to_USDS() public {
        uint256 amountIn = 500e6;
        uint256 minAmountOut = 499e18;

        deal(USDC, account, amountIn);
        // Pre-approve PSM
        IERC20(USDC).approve(PSM_ADDRESS, amountIn);

        uint256 initialUSDS = IERC20(USDS).balanceOf(account);

        bytes memory hookData = _buildExactInHookData(USDC, USDS, amountIn, minAmountOut, false);

        Execution[] memory executions = swapExactInHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "Should have 3 executions (pre + swap + post)");

        _executeAll(executions);

        uint256 usdsReceived = IERC20(USDS).balanceOf(account) - initialUSDS;
        assertEq(usdsReceived, 500e18, "Should receive 500 USDS");
    }

    /// @notice Test SwapExactOut (pre-approved): USDC -> USDS
    function test_SwapExactOut_PreApproved_USDC_to_USDS() public {
        uint256 amountOut = 500e18;
        uint256 expectedIn = psm.previewSwapExactOut(USDC, USDS, amountOut);
        uint256 maxAmountIn = expectedIn + 2;

        deal(USDC, account, maxAmountIn);
        IERC20(USDC).approve(PSM_ADDRESS, maxAmountIn);

        uint256 initialUSDS = IERC20(USDS).balanceOf(account);

        bytes memory hookData = _buildExactOutHookData(USDC, USDS, amountOut, maxAmountIn, false);

        Execution[] memory executions = swapExactOutHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "Should have 3 executions (pre + swap + post)");

        _executeAll(executions);

        uint256 usdsReceived = IERC20(USDS).balanceOf(account) - initialUSDS;
        assertEq(usdsReceived, amountOut, "Should receive exact 500 USDS");
    }

    /*//////////////////////////////////////////////////////////////
                    LARGE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test with large amounts (whale scenario)
    function test_ApproveAndSwapExactIn_LargeAmount_USDC_to_USDS() public {
        uint256 amountIn = 1_000_000e6; // 1M USDC
        uint256 minAmountOut = 999_999e18;

        // Skip if PSM doesn't have enough USDS liquidity at the forked block
        uint256 psmUsdsBalance = IERC20(USDS).balanceOf(PSM_ADDRESS);
        vm.skip(psmUsdsBalance < 1_000_000e18);

        deal(USDC, account, amountIn);
        // Ensure PSM has enough USDS liquidity to fulfill the swap
        deal(USDS, PSM_ADDRESS, 2_000_000e18);

        bytes memory hookData = _buildExactInHookData(USDC, USDS, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 usdsBalance = IERC20(USDS).balanceOf(account);
        console2.log("USDS received for 1M USDC:", usdsBalance);

        assertEq(usdsBalance, 1_000_000e18, "Should receive 1M USDS");
    }

    /*//////////////////////////////////////////////////////////////
                    SMALL AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test with minimum viable amounts
    function test_ApproveAndSwapExactIn_SmallAmount_USDC_to_USDS() public {
        uint256 amountIn = 1e6; // 1 USDC
        uint256 minAmountOut = 0; // No slippage requirement

        deal(USDC, account, amountIn);

        bytes memory hookData = _buildExactInHookData(USDC, USDS, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 usdsReceived = IERC20(USDS).balanceOf(account);
        assertEq(usdsReceived, 1e18, "Should receive 1 USDS for 1 USDC");
    }

    /*//////////////////////////////////////////////////////////////
                    ALL TOKEN PAIR TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test sUSDS -> USDS swap
    function test_ApproveAndSwapExactIn_sUSDS_to_USDS() public {
        uint256 amountIn = 100e18; // 100 sUSDS

        deal(SUSDS, account, amountIn);

        uint256 expectedOut = psm.previewSwapExactIn(SUSDS, USDS, amountIn);
        uint256 minAmountOut = expectedOut > 0 ? expectedOut - 1 : 0;

        bytes memory hookData = _buildExactInHookData(SUSDS, USDS, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 usdsReceived = IERC20(USDS).balanceOf(account);

        console2.log("USDS received for 100 sUSDS:", usdsReceived);

        assertGt(usdsReceived, 0, "Should receive USDS");
        assertGe(usdsReceived, minAmountOut, "Should meet slippage");
        // sUSDS -> USDS: should be MORE than 100e18 USDS (since sUSDS appreciates)
        assertGt(usdsReceived, 100e18, "sUSDS should convert to more USDS (appreciating)");
    }

    /// @notice Test sUSDS -> USDC swap
    function test_ApproveAndSwapExactIn_sUSDS_to_USDC() public {
        uint256 amountIn = 100e18; // 100 sUSDS

        deal(SUSDS, account, amountIn);

        uint256 expectedOut = psm.previewSwapExactIn(SUSDS, USDC, amountIn);
        uint256 minAmountOut = expectedOut > 0 ? expectedOut - 1 : 0;

        bytes memory hookData = _buildExactInHookData(SUSDS, USDC, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 usdcReceived = IERC20(USDC).balanceOf(account);

        console2.log("USDC received for 100 sUSDS:", usdcReceived);

        assertGt(usdcReceived, 0, "Should receive USDC");
        assertGe(usdcReceived, minAmountOut, "Should meet slippage");
        // 100 sUSDS should convert to more than 100 USDC
        assertGt(usdcReceived, 100e6, "sUSDS should convert to more USDC");
    }

    /// @notice Test USDS -> sUSDS swap
    function test_ApproveAndSwapExactIn_USDS_to_sUSDS() public {
        uint256 amountIn = 1000e18; // 1000 USDS

        deal(USDS, account, amountIn);
        // Ensure PSM has enough sUSDS liquidity
        deal(SUSDS, PSM_ADDRESS, 10_000e18);

        uint256 expectedOut = psm.previewSwapExactIn(USDS, SUSDS, amountIn);
        uint256 minAmountOut = expectedOut > 0 ? expectedOut - 1 : 0;

        bytes memory hookData = _buildExactInHookData(USDS, SUSDS, amountIn, minAmountOut, false);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, hookData);
        _executeAll(executions);

        uint256 susdsReceived = IERC20(SUSDS).balanceOf(account);

        console2.log("sUSDS received for 1000 USDS:", susdsReceived);

        assertGt(susdsReceived, 0, "Should receive sUSDS");
        assertGe(susdsReceived, minAmountOut, "Should meet slippage");
        // 1000 USDS -> less than 1000 sUSDS (since sUSDS appreciates)
        assertLt(susdsReceived, 1000e18, "Should get less sUSDS than USDS (appreciating)");
    }

    /*//////////////////////////////////////////////////////////////
                    INSPECT FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_ReturnsAssetOutAndReceiver() public view {
        bytes memory hookData = _buildExactInHookData(USDC, USDS, 1000e6, 999e18, false);

        bytes memory inspectResult = swapExactInHook.inspect(hookData);
        assertEq(inspectResult.length, 40);

        address decodedAssetOut;
        address decodedReceiver;
        assembly {
            decodedAssetOut := mload(add(inspectResult, 20))
            decodedReceiver := mload(add(inspectResult, 40))
        }
        assertEq(decodedAssetOut, USDS);
        assertEq(decodedReceiver, account);
    }

    /*//////////////////////////////////////////////////////////////
                    CONSTRUCTOR VALIDATION
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_ValidPSMAddress() public view {
        assertEq(address(swapExactInHook.PSM()), PSM_ADDRESS);
        assertEq(address(approveAndSwapExactInHook.PSM()), PSM_ADDRESS);
        assertEq(address(swapExactOutHook.PSM()), PSM_ADDRESS);
        assertEq(address(approveAndSwapExactOutHook.PSM()), PSM_ADDRESS);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for all SparkPSM hooks
    function test_SparkPSM_DecodeAmounts_ReplaceCalldataAmounts() public view {
        uint256 originalAmount = 1000e6;

        bytes memory exactInData = _buildExactInHookData(USDC, USDS, originalAmount, 999e18, false);
        bytes memory exactOutData = _buildExactOutHookData(USDC, USDS, originalAmount, 1001e6, false);

        // Verify decodeAmount for all hooks
        assertEq(swapExactInHook.decodeAmounts(exactInData)[0], originalAmount, "SwapExactIn decodeAmount");
        assertEq(approveAndSwapExactInHook.decodeAmounts(exactInData)[0], originalAmount, "ApproveAndSwapExactIn decodeAmount");
        assertEq(swapExactOutHook.decodeAmounts(exactOutData)[0], originalAmount, "SwapExactOut decodeAmount");
        assertEq(approveAndSwapExactOutHook.decodeAmounts(exactOutData)[0], originalAmount, "ApproveAndSwapExactOut decodeAmount");

        // Replace and verify roundtrip
        uint256 newAmount = 500e6;
        bytes memory replacedExactIn = approveAndSwapExactInHook.replaceCalldataAmounts(exactInData, _singleAmount(newAmount));
        bytes memory replacedExactOut = approveAndSwapExactOutHook.replaceCalldataAmounts(exactOutData, _singleAmount(newAmount));

        assertEq(approveAndSwapExactInHook.decodeAmounts(replacedExactIn)[0], newAmount, "ExactIn replaced amount");
        assertEq(approveAndSwapExactOutHook.decodeAmounts(replacedExactOut)[0], newAmount, "ExactOut replaced amount");

        // Verify other fields preserved
        assertFalse(approveAndSwapExactInHook.decodeUsePrevHookAmount(replacedExactIn), "ExactIn usePrevHookAmount preserved");
        assertFalse(approveAndSwapExactOutHook.decodeUsePrevHookAmount(replacedExactOut), "ExactOut usePrevHookAmount preserved");
    }

    /// @notice ApproveAndSwapExactIn: build with 1000 USDC, replace to 500 USDC, execute, verify only 500 spent
    function test_SparkPSM_ApproveAndSwapExactIn_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        uint256 originalAmount = 1000e6;
        uint256 newAmount = 500e6;

        deal(USDC, account, originalAmount);

        bytes memory hookData = _buildExactInHookData(USDC, USDS, originalAmount, 0, false);
        bytes memory replaced = approveAndSwapExactInHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(approveAndSwapExactInHook.decodeAmounts(replaced)[0], newAmount, "Amount not replaced correctly");

        uint256 usdsBefore = IERC20(USDS).balanceOf(account);

        Execution[] memory executions = approveAndSwapExactInHook.build(address(0), account, replaced);
        _executeAll(executions);

        uint256 usdcAfter = IERC20(USDC).balanceOf(account);
        uint256 usdsAfter = IERC20(USDS).balanceOf(account);

        assertEq(usdcAfter, originalAmount - newAmount, "Should only spend replaced amount");
        assertGt(usdsAfter - usdsBefore, 0, "Should receive USDS");
        // 1:1 rate: 500 USDC -> 500 USDS
        assertEq(usdsAfter - usdsBefore, 500e18, "Should receive exactly 500 USDS");
    }

    /// @notice ApproveAndSwapExactOut: build with 1000e18, replace to 500e18, execute, verify correct output
    function test_SparkPSM_ApproveAndSwapExactOut_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        uint256 originalAmountOut = 1000e18;
        uint256 newAmountOut = 500e18;

        // Fund more than needed
        uint256 expectedIn = psm.previewSwapExactOut(USDC, USDS, newAmountOut);
        uint256 maxAmountIn = expectedIn + 2;
        deal(USDC, account, maxAmountIn + 1000e6); // extra buffer

        bytes memory hookData = _buildExactOutHookData(USDC, USDS, originalAmountOut, maxAmountIn + 1000e6, false);
        bytes memory replaced = approveAndSwapExactOutHook.replaceCalldataAmounts(hookData, _singleAmount(newAmountOut));
        assertEq(approveAndSwapExactOutHook.decodeAmounts(replaced)[0], newAmountOut, "Amount not replaced correctly");

        uint256 usdsBefore = IERC20(USDS).balanceOf(account);

        Execution[] memory executions = approveAndSwapExactOutHook.build(address(0), account, replaced);
        _executeAll(executions);

        uint256 usdsAfter = IERC20(USDS).balanceOf(account);
        assertEq(usdsAfter - usdsBefore, newAmountOut, "Should receive exactly replaced amount out");
    }
}
