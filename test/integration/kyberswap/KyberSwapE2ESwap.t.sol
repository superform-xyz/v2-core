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
import { IScaleHelper } from "../../../src/vendor/kyberswap/IScaleHelper.sol";
import { ISuperHook, ISuperHookResult } from "../../../src/interfaces/ISuperHook.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Constants } from "../../utils/Constants.sol";
import { KyberSwapAPIParser } from "../../utils/parsers/KyberSwapAPIParser.sol";

import "forge-std/console2.sol";

/// @title KyberSwapE2ESwap
/// @notice End-to-end swap tests using real KyberSwap API routing data
/// @dev Requires: ETHEREUM_RPC_URL env var, --ffi flag for surl HTTP calls
///      Tests actual token swaps through the real KyberSwap MetaAggregationRouterV2.
///      Uses retry mechanism because the API may return routes through DEXes (e.g. Uniswap V4)
///      that use EVM features incompatible with Foundry's fork environment.
contract KyberSwapE2ESwap is Test, Constants, KyberSwapAPIParser {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;

    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public constant SCALE_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;
    address public constant USDC = CHAIN_1_USDC;
    address public constant WETH = CHAIN_1_WETH;
    address public constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA; // Chainlink (LINK) - 18 decimals

    uint256 constant MAX_RETRIES = 3;

    address public account;

    receive() external payable { }

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        account = address(this);

        swapHook = new SwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER);
        approveAndSwapHook = new ApproveAndSwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Execute all, revert-propagating version
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

    /// @dev Execute all, returns false on failure instead of reverting
    function _tryExecuteAll(Execution[] memory executions) internal returns (bool) {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) return false;
        }
        return true;
    }

    /// @dev Get swap txData from KyberSwap API (route + build)
    function _getKyberSwapTxData(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        internal
        returns (bytes memory txData_, uint256 expectedOut)
    {
        // Exclude DEXes that use EVM features incompatible with Foundry's fork (UniV4 PoolManager, Ekubo)
        string memory routeSummary =
            surlCallRoutes(tokenIn, tokenOut, amountIn, "ethereum", "ekubo-v3,axima-v2");
        expectedOut = extractAmountOut(routeSummary);
        string memory txDataHex = surlCallBuild(routeSummary, account, account, 200, "ethereum");
        txData_ = fromHex(txDataHex);
    }

    /*//////////////////////////////////////////////////////////////
                E2E: USDC -> WETH via ApproveAndSwapHook
    //////////////////////////////////////////////////////////////*/

    /// @notice Full end-to-end swap: USDC -> WETH using real KyberSwap API routing
    function test_E2E_ApproveAndSwap_USDC_to_WETH() public {
        uint256 inputAmount = 1000e6; // 1000 USDC

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(USDC, account, inputAmount);

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(USDC, WETH, inputAmount);
            console2.log("Attempt", attempt, "- Expected WETH out:", expectedOut);

            bytes memory hookData = bytes.concat(
                bytes20(USDC),
                bytes20(WETH),
                bytes32(inputAmount),
                bytes32(expectedOut * 90 / 100),
                bytes1(uint8(0)),
                bytes32(txData_.length),
                txData_
            );

            uint256 usdcBefore = IERC20(USDC).balanceOf(account);
            uint256 wethBefore = IERC20(WETH).balanceOf(account);

            Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);
            assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

            if (_tryExecuteAll(executions)) {
                uint256 usdcSpent = usdcBefore - IERC20(USDC).balanceOf(account);
                uint256 wethReceived = IERC20(WETH).balanceOf(account) - wethBefore;

                console2.log("USDC spent:", usdcSpent);
                console2.log("WETH received:", wethReceived);

                assertEq(usdcSpent, inputAmount, "should spend all USDC");
                assertGt(wethReceived, 0, "should receive WETH");
                assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), 0, "no residual approval");
                assertEq(
                    approveAndSwapHook.getOutAmount(account), wethReceived, "outAmount should match received WETH"
                );
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries - API returns incompatible routes");
    }

    /*//////////////////////////////////////////////////////////////
                E2E: WETH -> USDC via SwapHook (pre-approved)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full end-to-end swap: WETH -> USDC using SwapKyberSwapHook with pre-approval
    function test_E2E_SwapHook_WETH_to_USDC() public {
        uint256 inputAmount = 0.5 ether; // 0.5 WETH

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(WETH, account, inputAmount);

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(WETH, USDC, inputAmount);
            console2.log("Attempt", attempt, "- Expected USDC out:", expectedOut);

            // Decode approveTarget from txData and pre-approve WETH
            {
                IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
                    BytesLib.slice(txData_, 4, txData_.length - 4),
                    (IMetaAggregationRouterV2.SwapExecutionParams)
                );
                address target = params.approveTarget == address(0) ? KYBER_ROUTER : params.approveTarget;
                IERC20(WETH).approve(target, inputAmount);
            }

            bytes memory hookData = bytes.concat(
                bytes20(USDC),
                bytes32(uint256(0)),
                bytes32(inputAmount),
                bytes32(expectedOut * 90 / 100),
                bytes1(uint8(0)),
                bytes32(txData_.length),
                txData_
            );

            uint256 wethBefore = IERC20(WETH).balanceOf(account);
            uint256 usdcBefore = IERC20(USDC).balanceOf(account);

            Execution[] memory executions = swapHook.build(address(0), account, hookData);
            assertEq(executions.length, 3, "pre + swap + post");

            if (_tryExecuteAll(executions)) {
                uint256 wethSpent = wethBefore - IERC20(WETH).balanceOf(account);
                uint256 usdcReceived = IERC20(USDC).balanceOf(account) - usdcBefore;

                console2.log("WETH spent:", wethSpent);
                console2.log("USDC received:", usdcReceived);

                assertEq(wethSpent, inputAmount, "should spend all WETH");
                assertGt(usdcReceived, 0, "should receive USDC");
                assertEq(swapHook.getOutAmount(account), usdcReceived, "outAmount should match received USDC");
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries - API returns incompatible routes");
    }

    /*//////////////////////////////////////////////////////////////
                E2E: LINK -> USDC via ApproveAndSwapHook
    //////////////////////////////////////////////////////////////*/

    /// @notice Full end-to-end swap: LINK -> USDC using real KyberSwap API routing
    function test_E2E_ApproveAndSwap_LINK_to_USDC() public {
        uint256 inputAmount = 100e18; // 100 LINK (18 decimals)

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(LINK, account, inputAmount);

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(LINK, USDC, inputAmount);
            console2.log("Attempt", attempt, "- Expected USDC out:", expectedOut);

            bytes memory hookData = bytes.concat(
                bytes20(LINK),
                bytes20(USDC),
                bytes32(inputAmount),
                bytes32(expectedOut * 90 / 100),
                bytes1(uint8(0)),
                bytes32(txData_.length),
                txData_
            );

            uint256 linkBefore = IERC20(LINK).balanceOf(account);
            uint256 usdcBefore = IERC20(USDC).balanceOf(account);

            Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);
            assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

            if (_tryExecuteAll(executions)) {
                uint256 linkSpent = linkBefore - IERC20(LINK).balanceOf(account);
                uint256 usdcReceived = IERC20(USDC).balanceOf(account) - usdcBefore;

                console2.log("LINK spent:", linkSpent);
                console2.log("USDC received:", usdcReceived);

                assertEq(linkSpent, inputAmount, "should spend all LINK");
                assertGt(usdcReceived, 0, "should receive USDC");
                assertEq(IERC20(LINK).allowance(account, KYBER_ROUTER), 0, "no residual approval");
                assertEq(
                    approveAndSwapHook.getOutAmount(account), usdcReceived, "outAmount should match received USDC"
                );
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries - API returns incompatible routes");
    }

    /*//////////////////////////////////////////////////////////////
        E2E: ScaleHelper + usePrevHookAmount with real contracts
    //////////////////////////////////////////////////////////////*/

    /// @notice Tests usePrevHookAmount with real ScaleHelper: get routing for 1000 USDC,
    ///         but prevHook returns 1030 USDC (+3%, within ScaleHelper window).
    ///         ScaleHelper should properly scale targetData and the swap should succeed.
    function test_E2E_ScaleHelper_UsePrevHookAmount_USDC_to_WETH() public {
        uint256 quotedAmount = 1000e6; // API quote for 1000 USDC
        uint256 actualAmount = 1030e6; // prevHook returns 1030 USDC (+3%)

        // Deploy mock prevHook once (survives snapshots since it's in test contract state)
        MockPrevHookForE2E mockPrevHook = new MockPrevHookForE2E();
        mockPrevHook.setOutAmount(actualAmount, account);

        for (uint256 attempt = 0; attempt < MAX_RETRIES; attempt++) {
            uint256 snap = vm.snapshotState();
            deal(USDC, account, actualAmount);

            (bytes memory txData_, uint256 expectedOut) = _getKyberSwapTxData(USDC, WETH, quotedAmount);
            console2.log("Attempt", attempt, "- Expected WETH out (for 1000 USDC):", expectedOut);

            bytes memory hookData = bytes.concat(
                bytes20(USDC),
                bytes20(WETH),
                bytes32(quotedAmount),
                bytes32(expectedOut * 85 / 100),
                bytes1(uint8(1)),
                bytes32(txData_.length),
                txData_
            );

            uint256 usdcBefore = IERC20(USDC).balanceOf(account);
            uint256 wethBefore = IERC20(WETH).balanceOf(account);

            Execution[] memory executions = approveAndSwapHook.build(address(mockPrevHook), account, hookData);
            assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

            // Verify the approval amount matches the actual (scaled) amount
            (, bytes memory approveCalldata) =
                abi.decode(abi.encode(executions[2].target, executions[2].callData), (address, bytes));
            (, uint256 approvedAmount) =
                abi.decode(BytesLib.slice(approveCalldata, 4, approveCalldata.length - 4), (address, uint256));
            assertEq(approvedAmount, actualAmount, "approval should be for actual (scaled) amount");

            if (_tryExecuteAll(executions)) {
                uint256 usdcSpent = usdcBefore - IERC20(USDC).balanceOf(account);
                uint256 wethReceived = IERC20(WETH).balanceOf(account) - wethBefore;

                console2.log("ScaleHelper test - USDC spent:", usdcSpent);
                console2.log("ScaleHelper test - WETH received:", wethReceived);

                assertEq(usdcSpent, actualAmount, "should spend all USDC (actual amount)");
                assertGt(wethReceived, 0, "should receive WETH");
                assertGt(wethReceived, expectedOut * 95 / 100, "should receive close to or more than quoted output");
                return;
            }

            console2.log("Attempt", attempt, "failed (incompatible route), retrying...");
            vm.revertToState(snap);
        }
        revert("E2E swap failed after all retries - API returns incompatible routes");
    }
}

/// @dev Simple mock that implements ISuperHookResult for E2E testing of usePrevHookAmount
contract MockPrevHookForE2E is ISuperHookResult {
    mapping(address => uint256) private _outAmounts;

    function setOutAmount(uint256 amount, address account) external {
        _outAmounts[account] = amount;
    }

    function hookType() external pure override returns (ISuperHook.HookType) {
        return ISuperHook.HookType.NONACCOUNTING;
    }

    function spToken() external pure override returns (address) {
        return address(0);
    }

    function asset() external pure override returns (address) {
        return address(0);
    }

    function getOutAmount(address account) external view override returns (uint256) {
        return _outAmounts[account];
    }
}
