// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    SwapSparkPSMExactInHook
} from "../../../../../src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol";
import {
    ApproveAndSwapSparkPSMExactInHook
} from "../../../../../src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactInHook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { MockPSM3 } from "../../../../mocks/MockPSM3.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract SparkPSMExactInTest is Helpers {
    SwapSparkPSMExactInHook public swapHook;
    ApproveAndSwapSparkPSMExactInHook public approveAndSwapHook;
    MockPSM3 public psm;
    MockHook public prevHook;

    address assetIn;
    address assetOut;
    address account;
    address receiver;

    uint256 originalAmountIn = 1000;
    uint256 originalMinAmountOut = 950;
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

        swapHook = new SwapSparkPSMExactInHook(address(psm));
        approveAndSwapHook = new ApproveAndSwapSparkPSMExactInHook(address(psm));
    }

    /*//////////////////////////////////////////////////////////////
                         SwapSparkPSMExactInHook Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Constructor() public view {
        assertEq(uint256(swapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapHook.PSM()), address(psm));
    }

    function test_SwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapSparkPSMExactInHook(address(0));
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
        bytes memory shortData = new bytes(208); // Less than 209
        vm.expectRevert(SwapSparkPSMExactInHook.INVALID_HOOK_DATA.selector);
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

        // Should return assetOut + receiver packed (40 bytes)
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
                    ApproveAndSwapSparkPSMExactInHook Tests
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_Constructor() public view {
        assertEq(uint256(approveAndSwapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapHook.PSM()), address(psm));
    }

    function test_ApproveAndSwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapSparkPSMExactInHook(address(0));
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

        // 2 pre/post + 4 (approve(0), approve(amount), swap, approve(0)) = 6 executions
        assertEq(executions.length, 6);

        // executions[0] is preExecute
        // executions[1] is approve(0)
        assertEq(executions[1].target, assetIn);
        // executions[2] is approve(amount)
        assertEq(executions[2].target, assetIn);
        // executions[3] is swap
        assertEq(executions[3].target, address(psm));
        // executions[4] is approve(0)
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
        bytes memory shortData = new bytes(208); // Less than 209
        vm.expectRevert(ApproveAndSwapSparkPSMExactInHook.INVALID_HOOK_DATA.selector);
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

        // Delta: 800 - 500 = 300
        assertEq(approveAndSwapHook.getOutAmount(account), 300);
    }

    function test_ApproveAndSwapHook_Inspect() public view {
        bytes memory data = _buildHookData(false);
        bytes memory inspected = approveAndSwapHook.inspect(data);

        // Should return assetOut + receiver packed (40 bytes)
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
        assertEq(data.length, 209);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_ApproveAndSwapHook_Build_ExactMinimumDataLength() public view {
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 209);

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

        // Decode the PSM swapExactIn calldata from swap execution at index 1
        // Selector (4) + assetIn (32) + assetOut (32) + amountIn (32) + minAmountOut (32) + receiver (32) +
        // referralCode (32)
        bytes memory swapCalldata = executions[1].callData;

        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            // amountIn at offset: 4 + 32 + 32 = 68
            decodedAmountIn := mload(add(swapCalldata, 100)) // 68 + 32
            // minAmountOut at offset: 4 + 32 + 32 + 32 = 100
            decodedMinAmountOut := mload(add(swapCalldata, 132)) // 100 + 32
        }

        // newAmountIn should be prevHookAmount = 2000
        assertEq(decodedAmountIn, 2000);
        // newMinOut = originalMinOut * (newAmountIn / originalAmountIn) = 950 * (2000 / 1000) = 1900
        assertEq(decodedMinAmountOut, 1900);
    }

    function test_ApproveAndSwapHook_SlippageRecalculation_VerifyValues() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // The swap execution is at index 3
        bytes memory swapCalldata = executions[3].callData;

        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, 2000);
        assertEq(decodedMinAmountOut, 1900);
    }

    function test_SwapHook_NoSlippageRecalculation_VerifyValues() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;

        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, originalAmountIn);
        assertEq(decodedMinAmountOut, originalMinAmountOut);
    }

    function test_SwapHook_SlippageRecalculation_SmallerPrevAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        uint256 prevHookAmount = 500; // Half of original
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, 500);
        // newMinOut = 950 * (500 / 1000) = 475
        assertEq(decodedMinAmountOut, 475);
    }

    function test_SwapHook_SlippageRecalculation_EqualAmounts() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        uint256 prevHookAmount = 1000; // Same as original
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, 1000);
        assertEq(decodedMinAmountOut, 950);
    }

    function test_SwapHook_SlippageRecalculation_ZeroOriginalAmount() public {
        // When originalAmountIn is 0, HookDataUpdater returns original outputAmount
        bytes memory data = _buildHookDataCustomAmounts(0, 950, true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, 2000);
        // When originalAmountIn is 0, HookDataUpdater returns original outputAmount (950)
        assertEq(decodedMinAmountOut, 950);
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
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes20(differentReceiver), // Different from account
            bytes32(referralCode),
            bytes1(0x00)
        );

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Decode receiver from swap calldata
        // swapExactIn(assetIn, assetOut, amountIn, minAmountOut, receiver, referralCode)
        // Selector (4) + assetIn (32) + assetOut (32) + amountIn (32) + minAmountOut (32) + receiver (32)
        bytes memory swapCalldata = executions[1].callData;
        address decodedReceiver;
        assembly ("memory-safe") {
            // receiver at offset: 4 + 32*4 = 132, so mload at 132+32 = 164
            decodedReceiver := mload(add(swapCalldata, 164))
        }

        // Receiver should be forced to account
        assertEq(decodedReceiver, account);
        assertTrue(decodedReceiver != differentReceiver);
    }

    function test_ApproveAndSwapHook_ReceiverForcedToAccount() public view {
        address differentReceiver = address(0xBEEF);

        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(assetIn),
            bytes20(assetOut),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes20(differentReceiver),
            bytes32(referralCode),
            bytes1(0x00)
        );

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Swap is at index 3
        bytes memory swapCalldata = executions[3].callData;
        address decodedReceiver;
        assembly ("memory-safe") {
            decodedReceiver := mload(add(swapCalldata, 164))
        }

        assertEq(decodedReceiver, account);
        assertTrue(decodedReceiver != differentReceiver);
    }

    /*//////////////////////////////////////////////////////////////
                     Approval Sequence Tests
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_VerifyApprovalSequence() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify execution sequence:
        // 0: preExecute
        // 1: approve(0)
        // 2: approve(amountIn)
        // 3: swap
        // 4: approve(0)
        // 5: postExecute

        assertEq(executions.length, 6);

        // Verify approve(0) at index 1
        assertEq(executions[1].target, assetIn);
        bytes memory approve0Calldata = executions[1].callData;
        uint256 approve0Amount;
        assembly ("memory-safe") {
            approve0Amount := mload(add(approve0Calldata, 68))
        }
        assertEq(approve0Amount, 0);

        // Verify approve(amountIn) at index 2
        assertEq(executions[2].target, assetIn);
        bytes memory approveAmountCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly ("memory-safe") {
            approvedAmount := mload(add(approveAmountCalldata, 68))
        }
        assertEq(approvedAmount, originalAmountIn);

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

    function test_ApproveAndSwapHook_ApproveAmountMatchesPrevHook() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify approve amount matches prevHookAmount
        bytes memory approveCalldata = executions[2].callData;
        uint256 approveAmount;
        assembly ("memory-safe") {
            approveAmount := mload(add(approveCalldata, 68))
        }

        assertEq(approveAmount, 2000);
    }

    /*//////////////////////////////////////////////////////////////
                     Zero Amount Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_ZeroAmountIn() public view {
        bytes memory data = _buildHookDataCustomAmounts(0, 0, false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, 0);
        assertEq(decodedMinAmountOut, 0);
    }

    function test_SwapHook_ZeroPrevHookAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        prevHook.setOutAmount(0, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
        }

        assertEq(decodedAmountIn, 0);
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
            // referralCode at offset: 4 + 32*5 = 164, so mload at 164+32 = 196
            decodedReferralCode := mload(add(swapCalldata, 196))
        }

        assertEq(decodedReferralCode, referralCode);
    }

    /*//////////////////////////////////////////////////////////////
                     Large Amount Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_SlippageRecalculation_LargeAmounts() public {
        uint256 largeAmountIn = 1_000_000e18;
        uint256 largeMinOut = 950_000e18;

        bytes memory data = _buildHookDataCustomAmounts(largeAmountIn, largeMinOut, true);

        uint256 prevHookAmount = 2_000_000e18;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedMinAmountOut;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
            decodedMinAmountOut := mload(add(swapCalldata, 132))
        }

        assertEq(decodedAmountIn, 2_000_000e18);
        assertEq(decodedMinAmountOut, 1_900_000e18);
    }

    /*//////////////////////////////////////////////////////////////
                     FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SwapHook_SlippageRecalculation(
        uint256 originalAmount,
        uint256 originalMinOut,
        uint256 prevAmount
    )
        public
    {
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        originalMinOut = bound(originalMinOut, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        bytes memory data = _buildHookDataCustomAmounts(originalAmount, originalMinOut, true);
        prevHook.setOutAmount(prevAmount, account);

        // Should not revert
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 100))
        }

        // amountIn should always be prevAmount when usePrevHookAmount is true
        assertEq(decodedAmountIn, prevAmount);
    }

    function testFuzz_SwapHook_DataLength(uint8 extraBytes) public view {
        bytes memory baseData = _buildHookData(false);
        bytes memory extraData = new bytes(extraBytes);
        bytes memory data = bytes.concat(baseData, extraData);

        // Should not revert for any length >= 157
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapSparkPsmExactIn_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(swapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_SwapSparkPsmExactIn_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapSparkPsmExactIn_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapSparkPsmExactIn_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_ApproveAndSwapSparkPsmExactIn_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapSparkPsmExactIn_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapSparkPSMExactIn_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapSparkPSMExactIn_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapSparkPSMExactIn_ReplaceCalldataAmounts_PreservesOtherFields() public view {
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
            bytes32(originalAmountIn), // 92-123
            bytes32(originalMinAmountOut), // 124-155
            bytes20(receiver), // 156-175
            bytes32(referralCode), // 176-207
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // 208
        );
    }

    function _buildHookDataCustomAmounts(
        uint256 _amountIn,
        uint256 _minAmountOut,
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
            bytes32(_amountIn),
            bytes32(_minAmountOut),
            bytes20(receiver),
            bytes32(referralCode),
            _usePrevHookAmount ? bytes1(0x01) : bytes1(0x00)
        );
    }
}
