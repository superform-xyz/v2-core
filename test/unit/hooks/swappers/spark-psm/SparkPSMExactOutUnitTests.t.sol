// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    SwapSparkPSMExactOutHook
} from "../../../../../src/hooks/swappers/spark-psm/SwapSparkPSMExactOutHook.sol";
import {
    ApproveAndSwapSparkPSMExactOutHook
} from "../../../../../src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactOutHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { MockPSM3 } from "../../../../mocks/MockPSM3.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract SparkPSMExactOutTest is Helpers {
    SwapSparkPSMExactOutHook public swapHook;
    ApproveAndSwapSparkPSMExactOutHook public approveAndSwapHook;
    MockPSM3 public psm;
    MockHook public prevHook;

    address assetIn;
    address assetOut;
    address account;
    address receiver;

    uint256 originalAmountOut = 1000;
    uint256 originalMaxAmountIn = 1050;
    uint256 referralCode = 42;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        receiver = address(this);

        psm = new MockPSM3();

        MockERC20 _assetIn = new MockERC20("USDC", "USDC", 6);
        assetIn = address(_assetIn);

        MockERC20 _assetOut = new MockERC20("USDS", "USDS", 18);
        assetOut = address(_assetOut);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, assetIn);

        swapHook = new SwapSparkPSMExactOutHook(address(psm));
        approveAndSwapHook = new ApproveAndSwapSparkPSMExactOutHook(address(psm));
    }

    /*//////////////////////////////////////////////////////////////
                         SwapSparkPSMExactOutHook Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Constructor() public view {
        assertEq(uint256(swapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapHook.PSM()), address(psm));
    }

    function test_SwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapSparkPSMExactOutHook(address(0));
    }

    function test_SwapHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _buildHookData(false);
        assertFalse(swapHook.decodeUsePrevHookAmount(data));
    }

    function test_SwapHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _buildHookData(true);
        assertTrue(swapHook.decodeUsePrevHookAmount(data));
    }

    function test_SwapHook_Build() public view {
        bytes memory data = _buildHookData(false);
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // 2 pre/post + 1 swap = 3 executions
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(psm));
        assertEq(executions[1].value, 0);
    }

    function test_SwapHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(psm));
    }

    function test_SwapHook_Build_RevertIf_InvalidHookData() public {
        bytes memory shortData = new bytes(220); // Less than 221
        vm.expectRevert(SwapSparkPSMExactOutHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(prevHook), account, shortData);
    }

    function test_SwapHook_PreExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(assetOut).mint(account, 500);
        swapHook.preExecute(address(0), account, data);

        assertEq(swapHook.getOutAmount(account), 500);
    }

    function test_SwapHook_PostExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(assetOut).mint(account, 500);
        swapHook.preExecute(address(0), account, data);

        MockERC20(assetOut).mint(account, 300);
        swapHook.postExecute(address(0), account, data);

        // Delta: 800 - 500 = 300
        assertEq(swapHook.getOutAmount(account), 300);
    }

    function test_SwapHook_Inspect() public view {
        bytes memory data = _buildHookData(false);
        bytes memory inspected = swapHook.inspect(data);

        assertEq(inspected.length, 40);

        address decodedAssetOut;
        address decodedReceiver;
        assembly ("memory-safe") {
            decodedAssetOut := mload(add(inspected, 20))
            decodedReceiver := mload(add(inspected, 40))
        }

        assertEq(decodedAssetOut, assetOut);
        assertEq(decodedReceiver, receiver);
    }

    /*//////////////////////////////////////////////////////////////
                    ApproveAndSwapSparkPSMExactOutHook Tests
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_Constructor() public view {
        assertEq(uint256(approveAndSwapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapHook.PSM()), address(psm));
    }

    function test_ApproveAndSwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapSparkPSMExactOutHook(address(0));
    }

    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _buildHookData(false);
        assertFalse(approveAndSwapHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _buildHookData(true);
        assertTrue(approveAndSwapHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndSwapHook_Build() public view {
        bytes memory data = _buildHookData(false);
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // 2 pre/post + 4 (approve(0), approve(maxAmountIn), swap, approve(0)) = 6 executions
        assertEq(executions.length, 6);

        assertEq(executions[1].target, assetIn);
        assertEq(executions[2].target, assetIn);
        assertEq(executions[3].target, address(psm));
        assertEq(executions[4].target, assetIn);
    }

    function test_ApproveAndSwapHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(psm));
    }

    function test_ApproveAndSwapHook_Build_RevertIf_InvalidHookData() public {
        bytes memory shortData = new bytes(220); // Less than 221
        vm.expectRevert(ApproveAndSwapSparkPSMExactOutHook.INVALID_HOOK_DATA.selector);
        approveAndSwapHook.build(address(prevHook), account, shortData);
    }

    function test_ApproveAndSwapHook_PreExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(assetOut).mint(account, 500);
        approveAndSwapHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 500);
    }

    function test_ApproveAndSwapHook_PostExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(assetOut).mint(account, 500);
        approveAndSwapHook.preExecute(address(0), account, data);

        MockERC20(assetOut).mint(account, 300);
        approveAndSwapHook.postExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 300);
    }

    function test_ApproveAndSwapHook_Inspect() public view {
        bytes memory data = _buildHookData(false);
        bytes memory inspected = approveAndSwapHook.inspect(data);

        assertEq(inspected.length, 40);

        address decodedAssetOut;
        address decodedReceiver;
        assembly ("memory-safe") {
            decodedAssetOut := mload(add(inspected, 20))
            decodedReceiver := mload(add(inspected, 40))
        }

        assertEq(decodedAssetOut, assetOut);
        assertEq(decodedReceiver, receiver);
    }

    /*//////////////////////////////////////////////////////////////
                         Edge Case Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Build_ExactMinimumDataLength() public view {
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 221);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_ApproveAndSwapHook_Build_ExactMinimumDataLength() public view {
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 221);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_SwapHook_RevertIf_AssetInZeroAddress() public {
        bytes memory data = _buildHookDataWithAssets(address(0), assetOut, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_RevertIf_AssetOutZeroAddress() public {
        bytes memory data = _buildHookDataWithAssets(assetIn, address(0), false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_RevertIf_BothAssetsZeroAddress() public {
        bytes memory data = _buildHookDataWithAssets(address(0), address(0), false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_AssetInZeroAddress() public {
        bytes memory data = _buildHookDataWithAssets(address(0), assetOut, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_AssetOutZeroAddress() public {
        bytes memory data = _buildHookDataWithAssets(assetIn, address(0), false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     Slippage Recalculation Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_SlippageRecalculation_VerifyValues() public {
        bytes memory data = _buildHookData(true);

        // Set previous hook amount to 2x original (2000 vs 1000)
        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Decode the PSM swapExactOut calldata from swap execution at index 1
        // swapExactOut(assetIn, assetOut, amountOut, maxAmountIn, receiver, referralCode)
        bytes memory swapCalldata = executions[1].callData;

        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            // amountOut at offset: 4 + 32 + 32 = 68, mload at 68+32 = 100
            decodedAmountOut := mload(add(swapCalldata, 100))
            // maxAmountIn at offset: 4 + 32 + 32 + 32 = 100, mload at 100+32 = 132
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        // newAmountOut should be prevHookAmount = 2000
        assertEq(decodedAmountOut, 2000);
        // newMaxAmountIn = originalMaxAmountIn * (newAmountOut / originalAmountOut) = 1050 * (2000 / 1000) = 2100
        assertEq(decodedMaxAmountIn, 2100);
    }

    function test_ApproveAndSwapHook_SlippageRecalculation_VerifyValues() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // The swap execution is at index 3
        bytes memory swapCalldata = executions[3].callData;

        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountOut, 2000);
        assertEq(decodedMaxAmountIn, 2100);
    }

    function test_SwapHook_NoSlippageRecalculation_VerifyValues() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;

        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountOut, originalAmountOut);
        assertEq(decodedMaxAmountIn, originalMaxAmountIn);
    }

    function test_SwapHook_SlippageRecalculation_SmallerPrevAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 1050, true);

        uint256 prevHookAmount = 500;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountOut, 500);
        // newMaxAmountIn = 1050 * (500 / 1000) = 525
        assertEq(decodedMaxAmountIn, 525);
    }

    function test_SwapHook_SlippageRecalculation_EqualAmounts() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 1050, true);

        uint256 prevHookAmount = 1000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountOut, 1000);
        assertEq(decodedMaxAmountIn, 1050);
    }

    /*//////////////////////////////////////////////////////////////
                     CRITICAL: ExactOut Approve Amount Tests
    //////////////////////////////////////////////////////////////*/

    /// @notice CRITICAL: Verifies that ApproveAndSwapExactOut approves maxAmountIn, NOT amountOut
    function test_ApproveAndSwapHook_ApprovesMaxAmountIn_NotAmountOut() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify approve amount at index 2 is maxAmountIn (1050), NOT amountOut (1000)
        bytes memory approveCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly ("memory-safe") {
            approvedAmount := mload(add(approveCalldata, 68))
        }

        // CRITICAL: Must be maxAmountIn, not amountOut
        assertEq(approvedAmount, originalMaxAmountIn);
        assertTrue(approvedAmount != originalAmountOut);
    }

    /// @notice Verifies scaled maxAmountIn is used for approval when chained
    function test_ApproveAndSwapHook_ChainedApproveUsesScaledMaxAmountIn() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify approve amount = scaled maxAmountIn = 1050 * (2000/1000) = 2100
        bytes memory approveCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly ("memory-safe") {
            approvedAmount := mload(add(approveCalldata, 68))
        }

        assertEq(approvedAmount, 2100);
    }

    function test_ApproveAndSwapHook_VerifyApprovalSequence() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);

        // Verify approve(0) at index 1
        assertEq(executions[1].target, assetIn);
        bytes memory approve0Calldata = executions[1].callData;
        uint256 approve0Amount;
        assembly ("memory-safe") {
            approve0Amount := mload(add(approve0Calldata, 68))
        }
        assertEq(approve0Amount, 0);

        // Verify approve(maxAmountIn) at index 2
        assertEq(executions[2].target, assetIn);
        bytes memory approveAmountCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly ("memory-safe") {
            approvedAmount := mload(add(approveAmountCalldata, 68))
        }
        assertEq(approvedAmount, originalMaxAmountIn);

        // Verify swap at index 3
        assertEq(executions[3].target, address(psm));

        // Verify approve(0) cleanup at index 4
        assertEq(executions[4].target, assetIn);
        bytes memory cleanupCalldata = executions[4].callData;
        uint256 cleanupAmount;
        assembly ("memory-safe") {
            cleanupAmount := mload(add(cleanupCalldata, 68))
        }
        assertEq(cleanupAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                     Receiver Forced to Account Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_ReceiverForcedToAccount() public view {
        address differentReceiver = address(0xBEEF);

        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(assetIn),
            bytes20(assetOut),
            bytes32(originalAmountOut),
            bytes32(originalMaxAmountIn),
            bytes1(0x00), // usePrevHookAmount = false
            abi.encode(differentReceiver, referralCode)
        );

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        address decodedReceiver;
        assembly ("memory-safe") {
            decodedReceiver := mload(add(swapCalldata, 164))
        }

        assertEq(decodedReceiver, account);
        assertTrue(decodedReceiver != differentReceiver);
    }

    function test_ApproveAndSwapHook_ReceiverForcedToAccount() public view {
        address differentReceiver = address(0xBEEF);

        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(assetIn),
            bytes20(assetOut),
            bytes32(originalAmountOut),
            bytes32(originalMaxAmountIn),
            bytes1(0x00), // usePrevHookAmount = false
            abi.encode(differentReceiver, referralCode)
        );

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[3].callData;
        address decodedReceiver;
        assembly ("memory-safe") {
            decodedReceiver := mload(add(swapCalldata, 164))
        }

        assertEq(decodedReceiver, account);
        assertTrue(decodedReceiver != differentReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                     Zero Amount Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_ZeroAmountOut() public view {
        bytes memory data = _buildHookDataCustomAmounts(0, 0, false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountOut, 0);
        assertEq(decodedMaxAmountIn, 0);
    }

    function test_SwapHook_ZeroPrevHookAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 1050, true);

        prevHook.setOutAmount(0, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountOut;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
        }

        assertEq(decodedAmountOut, 0);
    }

    /*//////////////////////////////////////////////////////////////
                     Referral Code Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_ReferralCodePassedThrough() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedReferralCode;
        assembly ("memory-safe") {
            decodedReferralCode := mload(add(swapCalldata, 196))
        }

        assertEq(decodedReferralCode, referralCode);
    }

    /*//////////////////////////////////////////////////////////////
                     Large Amount Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_SlippageRecalculation_LargeAmounts() public {
        uint256 largeAmountOut = 1_000_000e18;
        uint256 largeMaxAmountIn = 1_050_000e18;

        bytes memory data = _buildHookDataCustomAmounts(largeAmountOut, largeMaxAmountIn, true);

        uint256 prevHookAmount = 2_000_000e18;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountOut;
        uint256 decodedMaxAmountIn;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
            decodedMaxAmountIn := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountOut, 2_000_000e18);
        assertEq(decodedMaxAmountIn, 2_100_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                     FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SwapHook_SlippageRecalculation(
        uint256 originalAmount,
        uint256 originalMaxIn,
        uint256 prevAmount
    )
        public
    {
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        originalMaxIn = bound(originalMaxIn, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        bytes memory data = _buildHookDataCustomAmounts(originalAmount, originalMaxIn, true);
        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountOut;
        assembly ("memory-safe") {
            decodedAmountOut := mload(add(swapCalldata, 100))
        }

        // amountOut should always be prevAmount when usePrevHookAmount is true
        assertEq(decodedAmountOut, prevAmount);
    }

    /// @notice Fuzz test: Verify ApproveAndSwap always approves maxAmountIn (not amountOut)
    function testFuzz_ApproveAndSwapHook_ApprovesMaxAmountIn(
        uint256 amountOut_,
        uint256 maxAmountIn_
    )
        public
        view
    {
        amountOut_ = bound(amountOut_, 1, type(uint128).max);
        maxAmountIn_ = bound(maxAmountIn_, 1, type(uint128).max);

        bytes memory data = _buildHookDataCustomAmounts(amountOut_, maxAmountIn_, false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        bytes memory approveCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly ("memory-safe") {
            approvedAmount := mload(add(approveCalldata, 68))
        }

        // CRITICAL invariant: must always approve maxAmountIn
        assertEq(approvedAmount, maxAmountIn_);
    }

    function testFuzz_SwapHook_DataLength(uint8 extraBytes) public view {
        bytes memory baseData = _buildHookData(false);
        bytes memory extraData = new bytes(extraBytes);
        bytes memory data = bytes.concat(baseData, extraData);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapSparkPsmExactOut_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(swapHook.decodeAmounts(data)[0], originalAmountOut);
    }

    function test_SwapSparkPsmExactOut_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapSparkPsmExactOut_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapSparkPsmExactOut_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], originalAmountOut);
    }

    function test_ApproveAndSwapSparkPsmExactOut_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapSparkPsmExactOut_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapSparkPSMExactOut_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapSparkPSMExactOut_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapSparkPSMExactOut_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 92 (52-byte placeholder + assetIn(20) + assetOut(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/

    function _buildHookData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return _buildHookDataWithAssets(assetIn, assetOut, usePrevHookAmount);
    }

    function _buildHookDataWithAssets(
        address _assetIn,
        address _assetOut,
        bool usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(_assetIn), // 52-71
            bytes20(_assetOut), // 72-91
            bytes32(originalAmountOut), // 92-123
            bytes32(originalMaxAmountIn), // 124-155
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00), // 156
            abi.encode(receiver, referralCode) // 157+
        );
    }

    function _buildHookDataCustomAmounts(
        uint256 _amountOut,
        uint256 _maxAmountIn,
        bool _usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(assetIn),
            bytes20(assetOut),
            bytes32(_amountOut),
            bytes32(_maxAmountIn),
            _usePrevHookAmount ? bytes1(0x01) : bytes1(0x00),
            abi.encode(receiver, referralCode)
        );
    }
}
