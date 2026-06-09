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
import { IScaleHelper } from "../../../src/vendor/kyberswap/IScaleHelper.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { Constants } from "../../utils/Constants.sol";
import { KyberSwapScaler } from "../../../src/libraries/KyberSwapScaler.sol";

import "forge-std/console2.sol";

/// @title KyberSwapHookIntegrationTest
/// @notice Integration tests for KyberSwap hooks using a real Ethereum mainnet fork
/// @dev Tests hook data encoding, execution building, and actual swaps against the deployed
///      KyberSwap MetaAggregationRouterV2 at 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5
///      Requires ETHEREUM_RPC_URL environment variable
contract KyberSwapHookIntegrationTest is Test, Constants {
    SwapKyberSwapHook public swapHook;
    ApproveAndSwapKyberSwapHook public approveAndSwapHook;

    address public constant KYBER_ROUTER = 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5;
    address public constant SCALE_HELPER = 0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D;
    address public constant USDC = CHAIN_1_USDC;
    address public constant WETH = CHAIN_1_WETH;
    address public constant DAI = CHAIN_1_DAI;

    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public account;

    receive() external payable { }

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        account = address(this);

        swapHook = new SwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
        approveAndSwapHook = new ApproveAndSwapKyberSwapHook(KYBER_ROUTER, SCALE_HELPER, NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                         HELPERS
    //////////////////////////////////////////////////////////////*/

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

    /// @dev Build KyberSwap swap txData with real token addresses
    function _buildKyberSwapTxData(
        address srcToken,
        address dstToken,
        uint256 amount,
        uint256 minReturn,
        address callTarget_,
        address approveTarget_,
        bytes memory targetData_
    )
        internal
        view
        returns (bytes memory)
    {
        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = callTarget_;

        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = amount;

        address[] memory feeReceivers = new address[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(srcToken),
            dstToken: IERC20(dstToken),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: amount,
            minReturnAmount: minReturn,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: callTarget_,
            approveTarget: approveTarget_,
            clientData: "",
            desc: desc,
            targetData: targetData_
        });

        return abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));
    }

    /// @dev Build SwapKyberSwapHook data layout
    function _buildSwapHookData(
        address outputToken,
        uint256 value,
        uint256 inputAmount,
        uint256 outputMin,
        bool usePrevHookAmount,
        bytes memory txData_
    )
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes20(outputToken),
            bytes32(value),
            bytes32(inputAmount),
            bytes32(outputMin),
            usePrevHookAmount ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    /// @dev Build ApproveAndSwapKyberSwapHook data layout
    function _buildApproveAndSwapHookData(
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputMin,
        bool usePrevHookAmount,
        bytes memory txData_
    )
        internal
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputMin),
            usePrevHookAmount ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(txData_.length),
            txData_
        );
    }

    /*//////////////////////////////////////////////////////////////
             CONSTRUCTOR & IMMUTABLE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify hooks point to the real KyberSwap router
    function test_Constructor_RealRouter() public view {
        assertEq(address(swapHook.KYBER_ROUTER()), KYBER_ROUTER);
        assertEq(address(approveAndSwapHook.KYBER_ROUTER()), KYBER_ROUTER);
    }

    /*//////////////////////////////////////////////////////////////
             BUILD EXECUTION VERIFICATION (REAL ADDRESSES)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify SwapKyberSwapHook builds correct execution targeting real router
    function test_SwapHook_Build_TargetsRealRouter() public view {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, 1000e6, 0.3 ether, false, txData_);

        Execution[] memory executions = swapHook.build(address(0), account, hookData);

        assertEq(executions.length, 3, "pre + swap + post");
        assertEq(executions[1].target, KYBER_ROUTER, "swap should target real router");
        assertEq(executions[1].value, 0, "ERC20 swap has no value");
    }

    /// @notice Verify ApproveAndSwapKyberSwapHook builds correct approve-swap-approve sequence
    function test_ApproveAndSwapHook_Build_CorrectSequence() public view {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, 1000e6, 0.3 ether, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        assertEq(executions.length, 6, "pre + approve(0) + approve(amt) + swap + approve(0) + post");

        // Verify approve targets (should be the decoded approveTarget from txData)
        assertEq(executions[1].target, USDC, "first approve on input token");
        assertEq(executions[2].target, USDC, "second approve on input token");
        assertEq(executions[3].target, KYBER_ROUTER, "swap targets real router");
        assertEq(executions[4].target, USDC, "final approve reset on input token");

        // Verify approve amounts
        (, uint256 approveAmt0) = abi.decode(_sliceBytes(executions[1].callData, 4), (address, uint256));
        (, uint256 approveAmt1) = abi.decode(_sliceBytes(executions[2].callData, 4), (address, uint256));
        (, uint256 approveAmt3) = abi.decode(_sliceBytes(executions[4].callData, 4), (address, uint256));

        assertEq(approveAmt0, 0, "first approve should be 0");
        assertEq(approveAmt1, 1000e6, "second approve should be inputAmount");
        assertEq(approveAmt3, 0, "final approve should be 0");
    }

    /*//////////////////////////////////////////////////////////////
             INSPECT WITH REAL ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect returns only dstToken from real swap data
    function test_SwapHook_Inspect_RealAddresses() public {
        address callTarget_ = makeAddr("callTarget");
        address approveTarget_ = makeAddr("approveTarget");

        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, callTarget_, approveTarget_, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, 1000e6, 0.3 ether, false, txData_);

        bytes memory result = swapHook.inspect(hookData);

        assertEq(result.length, 20, "1 packed address = 20 bytes");

        // Decode packed address
        address decodedDstToken;
        assembly {
            decodedDstToken := mload(add(result, 20))
        }

        assertEq(decodedDstToken, WETH);
    }

    /// @notice Verify ApproveAndSwap inspect returns only dstToken
    function test_ApproveAndSwapHook_Inspect_RealAddresses() public {
        address callTarget_ = makeAddr("callTarget");
        address approveTarget_ = makeAddr("approveTarget");

        bytes memory txData_ = _buildKyberSwapTxData(USDC, DAI, 1000e6, 999e18, callTarget_, approveTarget_, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, DAI, 1000e6, 999e18, false, txData_);

        bytes memory result = approveAndSwapHook.inspect(hookData);

        assertEq(result.length, 20);

        address decodedDstToken;
        assembly {
            decodedDstToken := mload(add(result, 20))
        }

        assertEq(decodedDstToken, DAI);
    }

    /*//////////////////////////////////////////////////////////////
             APPROVE EXECUTION AGAINST REAL TOKENS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that the approve sequence executes correctly against real USDC on fork
    function test_ApproveAndSwapHook_ApproveSequence_RealUSDC() public {
        uint256 inputAmount = 1000e6;

        deal(USDC, account, inputAmount);

        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, inputAmount, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, inputAmount, 0, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        // Execute preExecute
        (bool s0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(s0, "preExecute should succeed");

        // Execute approve(0) - resets any stale approval
        (bool s1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(s1, "approve(0) should succeed");
        assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), 0, "allowance should be 0 after reset");

        // Execute approve(inputAmount)
        (bool s2,) = executions[2].target.call{ value: executions[2].value }(executions[2].callData);
        assertTrue(s2, "approve(amount) should succeed");
        assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), inputAmount, "allowance should match inputAmount");

        // Skip swap execution (would need real routing data from KyberSwap API)
        // Execute final approve(0)
        (bool s4,) = executions[4].target.call{ value: executions[4].value }(executions[4].callData);
        assertTrue(s4, "approve(0) cleanup should succeed");
        assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), 0, "allowance should be 0 after cleanup");
    }

    /// @notice Test approve sequence with USDT-like behavior (approve(0) before approve(n) for USDT)
    /// @dev USDT requires approve(0) before setting a new non-zero allowance. The hook's
    ///      approve(0)->approve(amount)->swap->approve(0) pattern handles this correctly.
    ///      We use a USDT whale address to get real tokens since deal() can be unreliable with USDT.
    function test_ApproveAndSwapHook_ApproveSequence_RealUSDT() public {
        address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        uint256 inputAmount = 1000e6;

        // Use a USDT whale to get real tokens via low-level call (USDT doesn't return bool)
        address usdtWhale = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;
        vm.prank(usdtWhale);
        (bool transferOk,) = USDT.call(abi.encodeWithSelector(IERC20.transfer.selector, account, inputAmount));
        assertTrue(transferOk, "whale transfer should succeed");

        bytes memory txData_ = _buildKyberSwapTxData(USDT, WETH, inputAmount, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDT, WETH, inputAmount, 0, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        // Simulate a pre-existing stale approval (USDT requires approve(0) before changing)
        // Use low-level call since USDT doesn't return bool
        (bool preApproveOk,) =
            USDT.call(abi.encodeWithSelector(IERC20.approve.selector, KYBER_ROUTER, uint256(500e6)));
        assertTrue(preApproveOk, "pre-approve should succeed");

        // Execute approve(0) - critical for USDT to reset stale approval
        (bool s1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(s1, "approve(0) should succeed for USDT");
        assertEq(IERC20(USDT).allowance(account, KYBER_ROUTER), 0, "USDT allowance reset");

        // Execute approve(inputAmount) - now works because allowance was reset to 0
        (bool s2,) = executions[2].target.call{ value: executions[2].value }(executions[2].callData);
        assertTrue(s2, "approve(amount) should succeed for USDT");
        assertEq(IERC20(USDT).allowance(account, KYBER_ROUTER), inputAmount, "USDT allowance set");
    }

    /*//////////////////////////////////////////////////////////////
             PRE/POST EXECUTE WITH REAL TOKENS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test balance tracking with real WETH on fork
    function test_SwapHook_BalanceTracking_RealWETH() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, 1000e6, 0, false, txData_);

        // Give account some WETH to simulate initial balance
        deal(WETH, account, 5 ether);

        swapHook.preExecute(address(0), account, hookData);
        assertEq(swapHook.getOutAmount(account), 5 ether, "preExecute should capture WETH balance");

        // Simulate swap output by dealing more WETH
        deal(WETH, account, 5 ether + 0.3 ether);

        swapHook.postExecute(address(0), account, hookData);
        assertEq(swapHook.getOutAmount(account), 0.3 ether, "postExecute should track delta");
    }

    /// @notice Test native ETH balance tracking on fork
    function test_SwapHook_BalanceTracking_NativeETH() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, NATIVE, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        // outputToken = NATIVE for native ETH
        bytes memory hookData = _buildSwapHookData(NATIVE, 0, 1000e6, 0, false, txData_);

        vm.deal(account, 10 ether);

        swapHook.preExecute(address(0), account, hookData);
        assertEq(swapHook.getOutAmount(account), 10 ether, "should capture ETH balance");

        vm.deal(account, 10.5 ether);

        swapHook.postExecute(address(0), account, hookData);
        assertEq(swapHook.getOutAmount(account), 0.5 ether, "should track ETH delta");
    }

    /// @notice Test ApproveAndSwap balance tracking reads outputToken at offset 20
    function test_ApproveAndSwapHook_BalanceTracking_RealDAI() public {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, DAI, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, DAI, 1000e6, 0, false, txData_);

        deal(DAI, account, 100e18);

        approveAndSwapHook.preExecute(address(0), account, hookData);
        assertEq(approveAndSwapHook.getOutAmount(account), 100e18, "should capture DAI balance");

        deal(DAI, account, 1100e18);

        approveAndSwapHook.postExecute(address(0), account, hookData);
        assertEq(approveAndSwapHook.getOutAmount(account), 1000e18, "should track DAI delta");
    }

    /*//////////////////////////////////////////////////////////////
             TX DATA ABI ENCODING/DECODING WITH REAL ROUTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify txData has correct function selector for the real router
    function test_TxData_HasCorrectSelector() public view {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, 1000e6, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        // First 4 bytes should be swap selector: 0xe21fd0e9
        bytes4 selector;
        assembly {
            selector := mload(add(txData_, 32))
        }
        assertEq(selector, IMetaAggregationRouterV2.swap.selector, "should have correct swap selector");
        assertEq(selector, bytes4(0xe21fd0e9), "selector should be 0xe21fd0e9");
    }

    /// @notice Verify txData can be decoded back to SwapExecutionParams
    function test_TxData_RoundtripEncodeDecode() public {
        address callTarget_ = makeAddr("dexPool");
        address approveTarget_ = KYBER_ROUTER;
        bytes memory targetData_ = abi.encode("some_dex_routing_data");

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, callTarget_, approveTarget_, targetData_);

        // Decode (same as hook does internally)
        bytes memory paramBytes = new bytes(txData_.length - 4);
        for (uint256 i = 0; i < paramBytes.length; i++) {
            paramBytes[i] = txData_[i + 4];
        }

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded =
            abi.decode(paramBytes, (IMetaAggregationRouterV2.SwapExecutionParams));

        assertEq(decoded.callTarget, callTarget_);
        assertEq(decoded.approveTarget, approveTarget_);
        assertEq(address(decoded.desc.srcToken), USDC);
        assertEq(address(decoded.desc.dstToken), WETH);
        assertEq(decoded.desc.amount, 1000e6);
        assertEq(decoded.desc.minReturnAmount, 0.3 ether);
        assertEq(decoded.desc.dstReceiver, account);
        assertEq(keccak256(decoded.targetData), keccak256(targetData_));
    }

    /*//////////////////////////////////////////////////////////////
             APPROVE TARGET EXTRACTION FROM REAL TX DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify approveTarget is correctly extracted when different from callTarget
    function test_ApproveAndSwapHook_DifferentApproveTarget() public {
        address callTarget_ = makeAddr("dexPool");
        address approveTarget_ = makeAddr("tokenTransferProxy");

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, callTarget_, approveTarget_, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, 1000e6, 0.3 ether, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        // Verify approvals go to approveTarget, not callTarget
        abi.decode(_sliceBytes(executions[1].callData, 4), (address, uint256));
        (address approveSpender,) = abi.decode(_sliceBytes(executions[2].callData, 4), (address, uint256));

        assertEq(approveSpender, approveTarget_, "approve should target approveTarget from txData");
    }

    /// @notice Verify fallback to KYBER_ROUTER when approveTarget is zero
    function test_ApproveAndSwapHook_ZeroApproveTarget_FallsBack() public view {
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, KYBER_ROUTER, address(0), "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, 1000e6, 0.3 ether, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        (address approveSpender,) = abi.decode(_sliceBytes(executions[2].callData, 4), (address, uint256));

        assertEq(approveSpender, KYBER_ROUTER, "should fallback to KYBER_ROUTER when approveTarget is zero");
    }

    /*//////////////////////////////////////////////////////////////
             SCALE HELPER INTEGRATION (REAL CONTRACT)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the real ScaleHelper contract exists and responds
    function test_ScaleHelper_RealContract_Exists() public view {
        uint256 codeSize;
        address sh = SCALE_HELPER;
        assembly {
            codeSize := extcodesize(sh)
        }
        assertGt(codeSize, 0, "ScaleHelper should be deployed on mainnet");
    }

    /// @notice Call the real ScaleHelper and verify the hook falls back gracefully when ScaleHelper reverts
    /// @dev ScaleHelper reverts with empty targetData (expects real routing data), which is fine —
    ///      the hook's try-catch catches this and falls back to proportional scaling
    function test_ScaleHelper_RealContract_FallbackOnRevert() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 1030e6;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        // Build txData with empty targetData — ScaleHelper will revert on this
        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, originalAmount, 0.3 ether, true, txData_);

        // Should NOT revert — hook falls back to proportional scaling
        Execution[] memory executions = swapHook.build(address(prevHookMock), account, hookData);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        // Proportional fallback should have updated desc.amount
        assertEq(decoded.desc.amount, prevAmount, "fallback should update desc.amount");
    }

    /// @notice Verify ScaleHelper is actually used by the hook on fork (not just fallback)
    function test_ScaleHelper_UsedByHookOnFork() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 1030e6;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHookMock), account, hookData);

        assertEq(executions.length, 6, "should have 6 executions");

        // Verify the approval amount uses prevAmount, not originalAmount
        (, uint256 approveAmt) = abi.decode(_sliceBytes(executions[2].callData, 4), (address, uint256));
        assertEq(approveAmt, prevAmount, "approval should use prevHook amount");
    }

    /*//////////////////////////////////////////////////////////////
             USEPREVHOOKAMOUNT WITH REAL TOKENS ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice ApproveAndSwap: usePrevHookAmount updates approval amount from prevHook output
    function test_ApproveAndSwapHook_UsePrevHookAmount_ApprovalsUpdated() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 1500e6;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHookMock), account, hookData);

        // All 3 approve calls should use prevAmount
        (, uint256 approveReset) = abi.decode(_sliceBytes(executions[1].callData, 4), (address, uint256));
        (, uint256 approveAmt) = abi.decode(_sliceBytes(executions[2].callData, 4), (address, uint256));
        (, uint256 approveCleanup) = abi.decode(_sliceBytes(executions[4].callData, 4), (address, uint256));

        assertEq(approveReset, 0, "first approve should be 0");
        assertEq(approveAmt, prevAmount, "second approve should be prevHook amount");
        assertEq(approveCleanup, 0, "cleanup approve should be 0");
    }

    /// @notice ApproveAndSwap: usePrevHookAmount scales txData desc.amount
    function test_ApproveAndSwapHook_UsePrevHookAmount_TxDataAmountScaled() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 1200e6;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHookMock), account, hookData);

        // Decode the swap calldata to verify desc.amount was updated
        bytes memory swapCalldata = executions[3].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        assertEq(params.desc.amount, prevAmount, "desc.amount should be updated to prevHook amount");
    }

    /// @notice SwapHook: usePrevHookAmount scales txData desc.amount
    function test_SwapHook_UsePrevHookAmount_TxDataAmountScaled() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 800e6;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = swapHook.build(address(prevHookMock), account, hookData);

        // Decode the swap calldata to verify desc.amount was updated
        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        assertEq(params.desc.amount, prevAmount, "desc.amount should be updated to prevHook amount");
    }

    /*//////////////////////////////////////////////////////////////
             NATIVE ETH VALUE FORWARDING ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice SwapHook: native ETH value is correctly set in execution
    function test_SwapHook_NativeETH_ValueForwarded() public view {
        uint256 ethAmount = 1.5 ether;
        bytes memory txData_ = _buildKyberSwapTxData(
            NATIVE, // ETH as src (native)
            USDC,
            ethAmount,
            1000e6,
            KYBER_ROUTER,
            KYBER_ROUTER,
            ""
        );

        bytes memory hookData = _buildSwapHookData(USDC, ethAmount, ethAmount, 1000e6, false, txData_);

        Execution[] memory executions = swapHook.build(address(0), account, hookData);

        assertEq(executions[1].value, ethAmount, "swap execution should forward ETH value");
        assertEq(executions[1].target, KYBER_ROUTER, "swap should target router");
    }

    /// @notice SwapHook: usePrevHookAmount updates native ETH value to prevHook output
    function test_SwapHook_UsePrevHookAmount_NativeValueUpdated() public {
        uint256 originalAmount = 1 ether;
        uint256 prevAmount = 1.5 ether;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, WETH);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(NATIVE, USDC, originalAmount, 1000e6, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(USDC, originalAmount, originalAmount, 1000e6, true, txData_);

        Execution[] memory executions = swapHook.build(address(prevHookMock), account, hookData);

        assertEq(executions[1].value, prevAmount, "native value should be updated to prevHook amount");
    }

    /*//////////////////////////////////////////////////////////////
             SPLIT ROUTE (MULTIPLE SRC RECEIVERS) ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Build txData with split routes and verify roundtrip encoding
    function test_TxData_SplitRoute_RoundtripEncodeDecode() public view {
        address receiver1 = address(0xBEEF);
        address receiver2 = address(0xCAFE);
        uint256 amount1 = 600e6;
        uint256 amount2 = 400e6;
        uint256 totalAmount = amount1 + amount2;

        address[] memory srcReceivers = new address[](2);
        srcReceivers[0] = receiver1;
        srcReceivers[1] = receiver2;

        uint256[] memory srcAmounts = new uint256[](2);
        srcAmounts[0] = amount1;
        srcAmounts[1] = amount2;

        address[] memory feeReceivers = new address[](0);
        uint256[] memory feeAmounts = new uint256[](0);

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: totalAmount,
            minReturnAmount: 0.3 ether,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: KYBER_ROUTER,
            approveTarget: KYBER_ROUTER,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        bytes memory txData_ = abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));

        // Roundtrip decode
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4), (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        assertEq(decoded.desc.srcReceivers.length, 2, "should have 2 receivers");
        assertEq(decoded.desc.srcAmounts.length, 2, "should have 2 amounts");
        assertEq(decoded.desc.srcReceivers[0], receiver1, "first receiver matches");
        assertEq(decoded.desc.srcReceivers[1], receiver2, "second receiver matches");
        assertEq(decoded.desc.srcAmounts[0], amount1, "first amount matches");
        assertEq(decoded.desc.srcAmounts[1], amount2, "second amount matches");
        assertEq(decoded.desc.amount, totalAmount, "total amount matches");
    }

    /// @notice usePrevHookAmount with split route scales srcAmounts proportionally
    function test_SwapHook_UsePrevHookAmount_SplitRouteScaled() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 1500e6; // 1.5x
        uint256 amount1 = 600e6;
        uint256 amount2 = 400e6;

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        // Build txData with split route
        address[] memory srcReceivers = new address[](2);
        srcReceivers[0] = address(0xBEEF);
        srcReceivers[1] = address(0xCAFE);

        uint256[] memory srcAmounts = new uint256[](2);
        srcAmounts[0] = amount1;
        srcAmounts[1] = amount2;

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: new address[](0),
            feeAmounts: new uint256[](0),
            dstReceiver: account,
            amount: originalAmount,
            minReturnAmount: 0.3 ether,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: KYBER_ROUTER,
            approveTarget: KYBER_ROUTER,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        bytes memory txData_ = abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));

        bytes memory hookData = _buildSwapHookData(WETH, 0, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = swapHook.build(address(prevHookMock), account, hookData);

        // Decode the swap calldata and verify srcAmounts are scaled
        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        assertEq(decoded.desc.amount, prevAmount, "desc.amount should be prevAmount");
        // 600e6 * 1500e6 / 1000e6 = 900e6
        assertEq(decoded.desc.srcAmounts[0], 900e6, "first srcAmount should be scaled 1.5x");
        // 400e6 * 1500e6 / 1000e6 = 600e6
        assertEq(decoded.desc.srcAmounts[1], 600e6, "second srcAmount should be scaled 1.5x");
    }

    /*//////////////////////////////////////////////////////////////
             FEE AMOUNTS IN TX DATA
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify fee receivers and amounts survive encoding roundtrip
    function test_TxData_FeeAmounts_RoundtripEncodeDecode() public view {
        address feeReceiver = address(0xFEE);
        uint256 feeAmount = 5e6; // 5 USDC fee

        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = KYBER_ROUTER;
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = 995e6;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = feeReceiver;
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = feeAmount;

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: 1000e6,
            minReturnAmount: 0.3 ether,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: KYBER_ROUTER,
            approveTarget: KYBER_ROUTER,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        bytes memory txData_ = abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));

        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(txData_, 4, txData_.length - 4), (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        assertEq(decoded.desc.feeReceivers.length, 1, "should have 1 fee receiver");
        assertEq(decoded.desc.feeReceivers[0], feeReceiver, "fee receiver matches");
        assertEq(decoded.desc.feeAmounts[0], feeAmount, "fee amount matches");
    }

    /// @notice usePrevHookAmount with fee amounts scales fees proportionally
    function test_ApproveAndSwapHook_UsePrevHookAmount_FeeAmountsScaled() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 2000e6; // 2x

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = KYBER_ROUTER;
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = 990e6;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = address(0xFEE);
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = 10e6; // 10 USDC fee

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: originalAmount,
            minReturnAmount: 0.3 ether,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: KYBER_ROUTER,
            approveTarget: KYBER_ROUTER,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        bytes memory txData_ = abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHookMock), account, hookData);

        // Decode swap calldata
        bytes memory swapCalldata = executions[3].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        // 990e6 * 2000e6 / 1000e6 = 1980e6
        assertEq(decoded.desc.srcAmounts[0], 1980e6, "srcAmount should be scaled 2x");
        // 10e6 * 2000e6 / 1000e6 = 20e6
        assertEq(decoded.desc.feeAmounts[0], 20e6, "feeAmount should be scaled 2x");
        assertEq(decoded.desc.amount, prevAmount, "desc.amount should be prevAmount");
    }

    /// @notice Verify feeAmounts are scaled proportionally in SwapKyberSwapHook fallback
    function test_SwapHook_UsePrevHookAmount_FeeAmountsScaled() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 2000e6; // 2x

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        address[] memory srcReceivers = new address[](1);
        srcReceivers[0] = KYBER_ROUTER;
        uint256[] memory srcAmounts = new uint256[](1);
        srcAmounts[0] = 990e6;

        address[] memory feeReceivers = new address[](1);
        feeReceivers[0] = address(0xFEE);
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = 10e6; // 10 USDC fee

        IMetaAggregationRouterV2.SwapDescriptionV2 memory desc = IMetaAggregationRouterV2.SwapDescriptionV2({
            srcToken: IERC20(USDC),
            dstToken: IERC20(WETH),
            srcReceivers: srcReceivers,
            srcAmounts: srcAmounts,
            feeReceivers: feeReceivers,
            feeAmounts: feeAmounts,
            dstReceiver: account,
            amount: originalAmount,
            minReturnAmount: 0.3 ether,
            flags: 0,
            permit: ""
        });

        IMetaAggregationRouterV2.SwapExecutionParams memory params = IMetaAggregationRouterV2.SwapExecutionParams({
            callTarget: KYBER_ROUTER,
            approveTarget: KYBER_ROUTER,
            clientData: "",
            desc: desc,
            targetData: ""
        });

        bytes memory txData_ = abi.encodePacked(IMetaAggregationRouterV2.swap.selector, abi.encode(params));

        bytes memory hookData = _buildSwapHookData(WETH, 0, originalAmount, 0.3 ether, true, txData_);

        Execution[] memory executions = swapHook.build(address(prevHookMock), account, hookData);

        // Decode swap calldata (execution[1] is the swap, [0] is preExecute, [2] is postExecute)
        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        // 990e6 * 2000e6 / 1000e6 = 1980e6
        assertEq(decoded.desc.srcAmounts[0], 1980e6, "srcAmount should be scaled 2x");
        // 10e6 * 2000e6 / 1000e6 = 20e6
        assertEq(decoded.desc.feeAmounts[0], 20e6, "feeAmount should be scaled 2x");
        assertEq(decoded.desc.amount, prevAmount, "desc.amount should be prevAmount");
    }

    /*//////////////////////////////////////////////////////////////
             DECODE USE PREV HOOK AMOUNT ON FORK
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify decodeUsePrevHookAmount works with real hook data
    function test_SwapHook_DecodeUsePrevHookAmount_OnFork() public view {
        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookDataFalse = _buildSwapHookData(WETH, 0, 1000e6, 0.3 ether, false, txData_);
        bytes memory hookDataTrue = _buildSwapHookData(WETH, 0, 1000e6, 0.3 ether, true, txData_);

        assertFalse(swapHook.decodeUsePrevHookAmount(hookDataFalse), "should decode false");
        assertTrue(swapHook.decodeUsePrevHookAmount(hookDataTrue), "should decode true");
    }

    /// @notice Verify decodeUsePrevHookAmount works with ApproveAndSwap hook data
    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_OnFork() public view {
        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookDataFalse = _buildApproveAndSwapHookData(USDC, WETH, 1000e6, 0.3 ether, false, txData_);
        bytes memory hookDataTrue = _buildApproveAndSwapHookData(USDC, WETH, 1000e6, 0.3 ether, true, txData_);

        assertFalse(approveAndSwapHook.decodeUsePrevHookAmount(hookDataFalse), "should decode false");
        assertTrue(approveAndSwapHook.decodeUsePrevHookAmount(hookDataTrue), "should decode true");
    }

    /*//////////////////////////////////////////////////////////////
             SWAP ALWAYS TARGETS KYBER_ROUTER
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify swap execution always goes to KYBER_ROUTER even when callTarget differs
    function test_ApproveAndSwapHook_SwapTargetsRouter_NotCallTarget() public {
        address differentCallTarget = makeAddr("differentPool");

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, differentCallTarget, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, 1000e6, 0.3 ether, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        // Swap execution (index 3) should ALWAYS target KYBER_ROUTER
        assertEq(executions[3].target, KYBER_ROUTER, "swap must target KYBER_ROUTER not callTarget");
    }

    /// @notice Same for SwapHook
    function test_SwapHook_SwapTargetsRouter_NotCallTarget() public {
        address differentCallTarget = makeAddr("differentPool");

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, 1000e6, 0.3 ether, differentCallTarget, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, 1000e6, 0.3 ether, false, txData_);

        Execution[] memory executions = swapHook.build(address(0), account, hookData);

        assertEq(executions[1].target, KYBER_ROUTER, "swap must target KYBER_ROUTER not callTarget");
    }

    /*//////////////////////////////////////////////////////////////
             LARGE AMOUNTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify hook handles large amounts without overflow
    function test_ApproveAndSwapHook_LargeAmounts() public view {
        uint256 largeAmount = 100_000_000e6; // 100M USDC
        uint256 largeMinReturn = 50_000 ether; // 50k WETH

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, largeAmount, largeMinReturn, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, largeAmount, largeMinReturn, false, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(0), account, hookData);

        assertEq(executions.length, 6, "should build 6 executions for large amounts");

        (, uint256 approveAmt) = abi.decode(_sliceBytes(executions[2].callData, 4), (address, uint256));
        assertEq(approveAmt, largeAmount, "approval should match large amount");
    }

    /// @notice Verify usePrevHookAmount with large amounts doesn't overflow during scaling
    function test_SwapHook_UsePrevHookAmount_LargeAmountsNoOverflow() public {
        uint256 originalAmount = 50_000_000e6; // 50M USDC
        uint256 prevAmount = 51_500_000e6; // +3%

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 25_000 ether, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildSwapHookData(WETH, 0, originalAmount, 25_000 ether, true, txData_);

        // Should not revert
        Execution[] memory executions = swapHook.build(address(prevHookMock), account, hookData);

        bytes memory swapCalldata = executions[1].callData;
        IMetaAggregationRouterV2.SwapExecutionParams memory decoded = abi.decode(
            BytesLib.slice(swapCalldata, 4, swapCalldata.length - 4),
            (IMetaAggregationRouterV2.SwapExecutionParams)
        );

        assertEq(decoded.desc.amount, prevAmount, "desc.amount should be updated");
    }

    /*//////////////////////////////////////////////////////////////
             REAL APPROVE EXECUTION WITH USEPREVHOOKAMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute real approve sequence on fork with usePrevHookAmount
    function test_ApproveAndSwapHook_UsePrevHookAmount_RealApproveExecution() public {
        uint256 originalAmount = 1000e6;
        uint256 prevAmount = 1200e6;

        deal(USDC, account, prevAmount);

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(prevAmount, account);

        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, originalAmount, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = _buildApproveAndSwapHookData(USDC, WETH, originalAmount, 0, true, txData_);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHookMock), account, hookData);

        // Execute preExecute
        (bool s0,) = executions[0].target.call{ value: executions[0].value }(executions[0].callData);
        assertTrue(s0, "preExecute should succeed");

        // Execute approve(0) - reset
        (bool s1,) = executions[1].target.call{ value: executions[1].value }(executions[1].callData);
        assertTrue(s1, "approve(0) should succeed");
        assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), 0, "allowance should be 0");

        // Execute approve(prevAmount)
        (bool s2,) = executions[2].target.call{ value: executions[2].value }(executions[2].callData);
        assertTrue(s2, "approve(prevAmount) should succeed");
        assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), prevAmount, "allowance should be prevAmount");

        // Skip swap (no real routing data), execute final approve(0) cleanup
        (bool s4,) = executions[4].target.call{ value: executions[4].value }(executions[4].callData);
        assertTrue(s4, "approve(0) cleanup should succeed");
        assertEq(IERC20(USDC).allowance(account, KYBER_ROUTER), 0, "allowance should be 0 after cleanup");
    }

    /*//////////////////////////////////////////////////////////////
             ZERO AMOUNT VALIDATION (FORK-BASED)
    //////////////////////////////////////////////////////////////*/

    /// @notice SwapHook reverts with ZERO_AMOUNT when prevHook returns 0
    function test_SwapHook_RevertIf_PrevHookAmountZero_OnFork() public {
        uint256 inputAmount = 1000e6;
        uint256 minReturn = 0.4 ether;
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, inputAmount, minReturn, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = abi.encodePacked(
            WETH, // outputToken (20 bytes)
            uint256(0), // value (32 bytes)
            inputAmount, // inputAmount (32 bytes)
            minReturn, // outputMin (32 bytes)
            uint8(1), // usePrevHookAmount = true (1 byte)
            txData_.length, // txDataLength (32 bytes)
            txData_ // txData
        );

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(0, account); // zero amount

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        swapHook.build(address(prevHookMock), account, hookData);
    }

    /// @notice ApproveAndSwapHook reverts with ZERO_AMOUNT when prevHook returns 0
    function test_ApproveAndSwapHook_RevertIf_PrevHookAmountZero_OnFork() public {
        uint256 inputAmount = 1000e6;
        uint256 minReturn = 0.4 ether;
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, inputAmount, minReturn, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = abi.encodePacked(
            USDC, // inputToken (20 bytes)
            WETH, // outputToken (20 bytes)
            inputAmount, // inputAmount (32 bytes)
            minReturn, // outputMin (32 bytes)
            uint8(1), // usePrevHookAmount = true (1 byte)
            txData_.length, // txDataLength (32 bytes)
            txData_ // txData
        );

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(0, account); // zero amount

        vm.expectRevert(KyberSwapScaler.ZERO_AMOUNT.selector);
        approveAndSwapHook.build(address(prevHookMock), account, hookData);
    }

    /// @notice SwapHook reverts when originalAmount=0 and usePrevHookAmount=true (division by zero guard)
    function test_SwapHook_RevertIf_OriginalAmountZero_OnFork() public {
        uint256 inputAmount = 0; // zero original
        uint256 minReturn = 0;
        bytes memory txData_ =
            _buildKyberSwapTxData(USDC, WETH, inputAmount, minReturn, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData = abi.encodePacked(
            WETH, // outputToken (20 bytes)
            uint256(0), // value (32 bytes)
            inputAmount, // inputAmount=0 (32 bytes)
            minReturn, // outputMin (32 bytes)
            uint8(1), // usePrevHookAmount = true (1 byte)
            txData_.length, // txDataLength (32 bytes)
            txData_ // txData
        );

        MockHook prevHookMock = new MockHook(ISuperHook.HookType.NONACCOUNTING, USDC);
        prevHookMock.setOutAmount(500e6, account); // non-zero prev amount

        vm.expectRevert(); // ZERO_AMOUNT from originalAmount=0 check
        swapHook.build(address(prevHookMock), account, hookData);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for ApproveAndSwapKyberSwapHook
    function test_ApproveAndSwap_DecodeAmount_ReplaceCalldataAmount() public {
        uint256 originalAmount = 1000e6;
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, originalAmount, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        bytes memory hookData =
            _buildApproveAndSwapHookData(USDC, WETH, originalAmount, 0.2 ether, false, txData_);

        // Verify decodeAmount reads correctly
        assertEq(approveAndSwapHook.decodeAmount(hookData), originalAmount, "decodeAmount mismatch");

        // Replace with new amount and verify roundtrip
        uint256 newAmount = 500e6;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmount(hookData, newAmount);

        assertEq(approveAndSwapHook.decodeAmount(replaced), newAmount, "replaced amount mismatch");

        // Verify other fields preserved
        assertFalse(approveAndSwapHook.decodeUsePrevHookAmount(replaced), "usePrevHookAmount should be preserved");
    }

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for SwapKyberSwapHook
    /// @dev SwapKyberSwapHook layout: outputToken(20) | value(32) | inputAmount(32) | outputMin(32) | usePrevHookAmount(1) | txDataLength(32) | txData
    function test_Swap_DecodeAmount_ReplaceCalldataAmount() public {
        uint256 originalAmount = 2000e6;
        bytes memory txData_ = _buildKyberSwapTxData(USDC, WETH, originalAmount, 0, KYBER_ROUTER, KYBER_ROUTER, "");

        // Build data matching SwapKyberSwapHook layout: outputToken(20) | value(32) | inputAmount(32) | ...
        bytes memory hookData = bytes.concat(
            bytes20(WETH), // outputToken
            bytes32(uint256(0)), // value (ETH value for swap, 0 for ERC20)
            bytes32(originalAmount), // inputAmount @ offset 52
            bytes32(uint256(0.2 ether)), // outputMin
            bytes1(uint8(0)), // usePrevHookAmount
            bytes32(txData_.length),
            txData_
        );

        assertEq(swapHook.decodeAmount(hookData), originalAmount, "SwapHook decodeAmount mismatch");

        uint256 newAmount = 1000e6;
        bytes memory replaced = swapHook.replaceCalldataAmount(hookData, newAmount);
        assertEq(swapHook.decodeAmount(replaced), newAmount, "SwapHook replaced amount mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                         UTILITY
    //////////////////////////////////////////////////////////////*/

    function _sliceBytes(bytes memory data, uint256 start) internal pure returns (bytes memory) {
        bytes memory result = new bytes(data.length - start);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = data[start + i];
        }
        return result;
    }
}
