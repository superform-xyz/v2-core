// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapKyberSwapHook } from "../../../src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol";
import {
    ApproveAndSwapKyberSwapHook
} from "../../../src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol";
import { IMetaAggregationRouterV2 } from "../../../src/vendor/kyberswap/IMetaAggregationRouterV2.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Constants } from "../../utils/Constants.sol";
import { KyberSwapAPIParser } from "../../utils/parsers/KyberSwapAPIParser.sol";

import "forge-std/console2.sol";

/// @title KyberSwapBaseNativeE2E
/// @notice E2E swap tests on Base fork using real KyberSwap API with NATIVE (0xEeee...eE) as output token.
///         Validates the fix: previously reverted when address(0) was used as native ETH sentinel.
/// @dev Requires: BASE_RPC_URL env var, --ffi flag for surl HTTP calls
contract KyberSwapBaseNativeE2E is Test, Constants, KyberSwapAPIParser {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;

    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public constant SCALE_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant USDC = CHAIN_8453_USDC;
    address public constant WETH = CHAIN_8453_WETH;

    uint256 constant MAX_RETRIES = 3;

    address public account;

    receive() external payable { }

    function setUp() public {
        vm.createSelectFork(vm.envString(BASE_RPC_URL_KEY));

        account = address(this);

        swapHook = new SwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
        approveAndSwapHook = new ApproveAndSwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    function _tryExecuteAll(Execution[] memory executions) internal returns (bool) {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) return false;
        }
        return true;
    }

    function _getKyberSwapTxData(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        returns (bytes memory txData_, uint256 expectedOut)
    {
        string memory routeSummary =
            surlCallRoutes(tokenIn, tokenOut, amountIn, "base", "ekubo-v3,axima-v2");
        expectedOut = extractAmountOut(routeSummary);
        string memory txDataHex = surlCallBuild(routeSummary, account, account, 200, "base");
        txData_ = fromHex(txDataHex);
    }

    /*//////////////////////////////////////////////////////////////
             E2E: USDC -> NATIVE ETH via ApproveAndSwapHook
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap USDC to native ETH on Base using real KyberSwap routing with NATIVE as outputToken
    function test_E2E_ApproveAndSwap_USDC_to_NativeETH_Base() public {
        uint256 inputAmount = 500e6; // 500 USDC

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(USDC, account, inputAmount);
            vm.deal(account, 0); // zero out ETH to measure received amount cleanly

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(USDC, NATIVE, inputAmount);
            console2.log("Attempt", attempt, "- Expected ETH out:", expectedOut);

            bytes memory hookData = bytes.concat(
                bytes32(0),
                bytes20(address(0)),
                bytes20(USDC), // inputToken @52
                bytes20(NATIVE), // outputToken @72
                bytes32(inputAmount), // inputAmount @92
                bytes32(uint256(0)), // outputQuote @124
                bytes32(expectedOut * 90 / 100), // outputMin @156
                bytes1(uint8(0)), // usePrevHookAmount @188
                bytes32(txData_.length), // payloadLength @189
                txData_
            );

            uint256 usdcBefore = IERC20(USDC).balanceOf(account);
            uint256 ethBefore = account.balance;

            Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);
            assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

            if (_tryExecuteAll(executions)) {
                uint256 usdcSpent = usdcBefore - IERC20(USDC).balanceOf(account);
                uint256 ethReceived = account.balance - ethBefore;

                console2.log("USDC spent:", usdcSpent);
                console2.log("ETH received:", ethReceived);

                // Router may leave dust due to routing paths; allow up to 0.01% tolerance
                assertApproxEqRel(usdcSpent, inputAmount, 0.0001e18, "should spend ~all USDC");
                assertGt(ethReceived, 0, "should receive native ETH");
                assertEq(
                    approveAndSwapHook.getOutAmount(account), ethReceived, "outAmount should match received ETH"
                );
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries");
    }

    /*//////////////////////////////////////////////////////////////
             E2E: USDC -> NATIVE ETH via SwapHook (pre-approved)
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap USDC to native ETH on Base using SwapHook with pre-approval and NATIVE as outputToken
    function test_E2E_SwapHook_USDC_to_NativeETH_Base() public {
        uint256 inputAmount = 500e6; // 500 USDC

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(USDC, account, inputAmount);
            vm.deal(account, 0);

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(USDC, NATIVE, inputAmount);
            console2.log("Attempt", attempt, "- Expected ETH out:", expectedOut);

            // Pre-approve USDC to the router's approveTarget
            {
                IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
                    BytesLib.slice(txData_, 4, txData_.length - 4),
                    (IMetaAggregationRouterV2.SwapExecutionParams)
                );
                address target = params.approveTarget == address(0) ? KYBER_ROUTER : params.approveTarget;
                IERC20(USDC).approve(target, inputAmount);
            }

            bytes memory hookData = bytes.concat(
                bytes32(0),
                bytes20(address(0)),
                bytes20(USDC), // inputToken @52
                bytes20(NATIVE), // outputToken @72
                bytes32(inputAmount), // inputAmount @92
                bytes32(uint256(0)), // outputQuote @124
                bytes32(expectedOut * 90 / 100), // outputMin @156
                bytes1(uint8(0)), // usePrevHookAmount @188
                bytes32(txData_.length), // payloadLength @189
                txData_
            );

            uint256 usdcBefore = IERC20(USDC).balanceOf(account);
            uint256 ethBefore = account.balance;

            Execution[] memory executions = swapHook.build(address(0), account, hookData);
            assertEq(executions.length, 3, "pre + swap + post");

            if (_tryExecuteAll(executions)) {
                uint256 usdcSpent = usdcBefore - IERC20(USDC).balanceOf(account);
                uint256 ethReceived = account.balance - ethBefore;

                console2.log("USDC spent:", usdcSpent);
                console2.log("ETH received:", ethReceived);

                // Router may leave dust due to routing paths; allow up to 0.01% tolerance
                assertApproxEqRel(usdcSpent, inputAmount, 0.0001e18, "should spend ~all USDC");
                assertGt(ethReceived, 0, "should receive native ETH");
                assertEq(swapHook.getOutAmount(account), ethReceived, "outAmount should match received ETH");
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries");
    }

    /*//////////////////////////////////////////////////////////////
             E2E: WETH -> NATIVE ETH via ApproveAndSwapHook
    //////////////////////////////////////////////////////////////*/

    /// @notice Unwrap WETH to native ETH on Base via KyberSwap, NATIVE as outputToken
    function test_E2E_ApproveAndSwap_WETH_to_NativeETH_Base() public {
        uint256 inputAmount = 0.5 ether;

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(WETH, account, inputAmount);
            vm.deal(account, 0);

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(WETH, NATIVE, inputAmount);
            console2.log("Attempt", attempt, "- Expected ETH out:", expectedOut);

            bytes memory hookData = bytes.concat(
                bytes32(0),
                bytes20(address(0)),
                bytes20(WETH), // inputToken @52
                bytes20(NATIVE), // outputToken @72
                bytes32(inputAmount), // inputAmount @92
                bytes32(uint256(0)), // outputQuote @124
                bytes32(expectedOut * 95 / 100), // outputMin @156
                bytes1(uint8(0)), // usePrevHookAmount @188
                bytes32(txData_.length), // payloadLength @189
                txData_
            );

            uint256 wethBefore = IERC20(WETH).balanceOf(account);
            uint256 ethBefore = account.balance;

            Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

            if (_tryExecuteAll(executions)) {
                uint256 wethSpent = wethBefore - IERC20(WETH).balanceOf(account);
                uint256 ethReceived = account.balance - ethBefore;

                console2.log("WETH spent:", wethSpent);
                console2.log("ETH received:", ethReceived);

                assertEq(wethSpent, inputAmount, "should spend all WETH");
                assertGt(ethReceived, 0, "should receive native ETH");
                assertEq(
                    approveAndSwapHook.getOutAmount(account), ethReceived, "outAmount should match received ETH"
                );
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries");
    }
}
