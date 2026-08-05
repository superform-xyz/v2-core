// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import "forge-std/console2.sol";

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { SwapAlgebraIntegralHook } from "../../../src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol";
import {
    ApproveAndSwapAlgebraIntegralHook
} from "../../../src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol";
import { Constants } from "../../utils/Constants.sol";

interface IWFLR {
    function deposit() external payable;
}

/// @title AlgebraIntegralFlareE2E
/// @notice Fork integration tests for Algebra Integral swap hooks against SparkDEX V4 on Flare mainnet
/// @dev WFLR has governance tracking (updateAtTokenTransfer) that breaks deal(), so we wrap native FLR instead
contract AlgebraIntegralFlareE2E is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    string public constant FLARE_RPC_URL_KEY = "FLARE_RPC_URL";

    /// @dev Pin the fork to a fixed block so storage reads are deterministic and archive-cacheable.
    ///      Forking at latest re-fetches every slot live and flakes in CI when the RPC times out.
    ///      Matches FlareRFLRHooksE2E's block so the foundry RPC cache is shared across Flare suites.
    uint256 public constant FORK_BLOCK = 61_344_973;

    uint256 public constant SWAP_AMOUNT = 100 ether; // 100 WFLR

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapAlgebraIntegralHook public swapHook;
    ApproveAndSwapAlgebraIntegralHook public approveAndSwapHook;

    address public account;
    uint256 public forkId;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        forkId = vm.createSelectFork(vm.envString(FLARE_RPC_URL_KEY), FORK_BLOCK);

        account = address(this);

        swapHook = new SwapAlgebraIntegralHook(FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER);
        approveAndSwapHook = new ApproveAndSwapAlgebraIntegralHook(FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER);
    }

    // Required to receive native FLR
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Acquire WFLR by wrapping native FLR (deal() breaks WFLR's governance tracking)
    function _getWFLR(uint256 amount) internal {
        vm.deal(account, amount);
        IWFLR(FLARE_WFLR).deposit{ value: amount }();
    }

    /// @dev Build hook data for Algebra Integral hooks (3-layer standard)
    function _buildHookData(
        address tokenIn,
        address tokenOut,
        address deployer,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = abi.encode(deployer, block.timestamp + 1800, uint160(0));
        return abi.encodePacked(
            bytes32(0), // header @0
            address(0), // header @32
            tokenIn, // inputToken @52
            tokenOut, // outputToken @72
            amountIn, // inputAmount @92 (AMOUNT_POSITION)
            uint256(0), // outputQuote @124
            amountOutMinimum, // outputMin @156
            usePrevHookAmount, // @188
            payload.length, // payloadLength @189
            payload
        );
    }

    /// @dev Execute all executions sequentially, return true if all succeed
    function _tryExecuteAll(Execution[] memory executions) internal returns (bool) {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) return false;
        }
        return true;
    }

    /*//////////////////////////////////////////////////////////////
              E2E: ApproveAndSwap WFLR -> SPRK
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap WFLR -> SPRK via ApproveAndSwapAlgebraIntegralHook on real SparkDEX V4 pool
    function test_E2E_ApproveAndSwap_WFLR_to_SPRK() public {
        _getWFLR(SWAP_AMOUNT);

        bytes memory hookData =
            _buildHookData(FLARE_WFLR, FLARE_SPRK, address(0), SWAP_AMOUNT, 0, false);

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);
        uint256 sprkBefore = IERC20(FLARE_SPRK).balanceOf(account);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "ApproveAndSwap WFLR->SPRK should succeed");

        uint256 wflrSpent = wflrBefore - IERC20(FLARE_WFLR).balanceOf(account);
        uint256 sprkReceived = IERC20(FLARE_SPRK).balanceOf(account) - sprkBefore;

        assertEq(wflrSpent, SWAP_AMOUNT, "should spend all WFLR");
        assertGt(sprkReceived, 0, "should receive SPRK");
        assertEq(approveAndSwapHook.getOutAmount(account), sprkReceived, "outAmount should match received SPRK");

        console2.log("WFLR spent:", wflrSpent);
        console2.log("SPRK received:", sprkReceived);
    }

    /*//////////////////////////////////////////////////////////////
              E2E: SwapHook WFLR -> SPRK (pre-approved)
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap WFLR -> SPRK via SwapAlgebraIntegralHook with pre-approval
    function test_E2E_SwapHook_WFLR_to_SPRK() public {
        _getWFLR(SWAP_AMOUNT);

        // Pre-approve WFLR to the router
        IERC20(FLARE_WFLR).approve(FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER, SWAP_AMOUNT);

        bytes memory hookData =
            _buildHookData(FLARE_WFLR, FLARE_SPRK, address(0), SWAP_AMOUNT, 0, false);

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);
        uint256 sprkBefore = IERC20(FLARE_SPRK).balanceOf(account);

        Execution[] memory executions = swapHook.build(address(0), account, hookData);
        assertEq(executions.length, 3, "pre + swap + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "SwapHook WFLR->SPRK should succeed");

        uint256 wflrSpent = wflrBefore - IERC20(FLARE_WFLR).balanceOf(account);
        uint256 sprkReceived = IERC20(FLARE_SPRK).balanceOf(account) - sprkBefore;

        assertEq(wflrSpent, SWAP_AMOUNT, "should spend all WFLR");
        assertGt(sprkReceived, 0, "should receive SPRK");
        assertEq(swapHook.getOutAmount(account), sprkReceived, "outAmount should match received SPRK");

        console2.log("WFLR spent:", wflrSpent);
        console2.log("SPRK received:", sprkReceived);
    }

    /*//////////////////////////////////////////////////////////////
              E2E: ApproveAndSwap WFLR -> sFLR (different pool)
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap WFLR -> sFLR via ApproveAndSwapAlgebraIntegralHook on the sFLR/WFLR pool
    function test_E2E_ApproveAndSwap_WFLR_to_sFLR() public {
        _getWFLR(SWAP_AMOUNT);

        bytes memory hookData =
            _buildHookData(FLARE_WFLR, FLARE_SFLR, address(0), SWAP_AMOUNT, 0, false);

        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);
        uint256 sflrBefore = IERC20(FLARE_SFLR).balanceOf(account);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);
        assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

        bool success = _tryExecuteAll(executions);
        assertTrue(success, "ApproveAndSwap WFLR->sFLR should succeed");

        uint256 wflrSpent = wflrBefore - IERC20(FLARE_WFLR).balanceOf(account);
        uint256 sflrReceived = IERC20(FLARE_SFLR).balanceOf(account) - sflrBefore;

        assertEq(wflrSpent, SWAP_AMOUNT, "should spend all WFLR");
        assertGt(sflrReceived, 0, "should receive sFLR");
        assertEq(approveAndSwapHook.getOutAmount(account), sflrReceived, "outAmount should match received sFLR");

        console2.log("WFLR spent:", wflrSpent);
        console2.log("sFLR received:", sflrReceived);
    }

    /*//////////////////////////////////////////////////////////////
              E2E: ApproveAndSwap with usePrevHookAmount
    //////////////////////////////////////////////////////////////*/

    /// @notice Chain two hooks: first swap WFLR -> SPRK, then use output as input for SPRK -> WFLR
    /// @dev Verifies usePrevHookAmount=true recalculates slippage correctly
    function test_E2E_ApproveAndSwap_WithUsePrevHookAmount() public {
        _getWFLR(SWAP_AMOUNT);

        // --- Hook 1: WFLR -> SPRK ---
        bytes memory hookData1 =
            _buildHookData(FLARE_WFLR, FLARE_SPRK, address(0), SWAP_AMOUNT, 0, false);

        Execution[] memory exec1 = approveAndSwapHook.build(address(0), account, hookData1);
        bool success1 = _tryExecuteAll(exec1);
        assertTrue(success1, "First swap WFLR->SPRK should succeed");

        uint256 sprkFromFirstSwap = approveAndSwapHook.getOutAmount(account);
        assertGt(sprkFromFirstSwap, 0, "should receive SPRK from first swap");
        console2.log("SPRK from first swap:", sprkFromFirstSwap);

        // --- Hook 2: SPRK -> WFLR with usePrevHookAmount=true ---
        // The hook data encodes the *original* amountIn (used for slippage recalculation ratio)
        // but the actual amountIn will come from the previous hook's getOutAmount
        bytes memory hookData2 =
            _buildHookData(FLARE_SPRK, FLARE_WFLR, address(0), sprkFromFirstSwap, 0, true);

        // Deploy a second ApproveAndSwap hook for the second swap
        ApproveAndSwapAlgebraIntegralHook approveAndSwapHook2 =
            new ApproveAndSwapAlgebraIntegralHook(FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER);

        uint256 sprkBefore = IERC20(FLARE_SPRK).balanceOf(account);
        uint256 wflrBefore = IERC20(FLARE_WFLR).balanceOf(account);

        // prevHook = approveAndSwapHook (the first hook that has the SPRK outAmount)
        Execution[] memory exec2 = approveAndSwapHook2.build(address(approveAndSwapHook), account, hookData2);
        assertEq(exec2.length, 6, "second hook should have 6 executions");

        bool success2 = _tryExecuteAll(exec2);
        assertTrue(success2, "Second swap SPRK->WFLR should succeed");

        uint256 sprkSpent = sprkBefore - IERC20(FLARE_SPRK).balanceOf(account);
        uint256 wflrReceived = IERC20(FLARE_WFLR).balanceOf(account) - wflrBefore;

        assertEq(sprkSpent, sprkFromFirstSwap, "should spend all SPRK from first swap");
        assertGt(wflrReceived, 0, "should receive WFLR back");
        assertEq(approveAndSwapHook2.getOutAmount(account), wflrReceived, "outAmount should match received WFLR");

        console2.log("SPRK spent:", sprkSpent);
        console2.log("WFLR received back:", wflrReceived);
    }
}
