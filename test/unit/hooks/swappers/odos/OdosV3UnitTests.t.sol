// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SwapOdosV3Hook } from "../../../../../src/hooks/swappers/odos/SwapOdosV3Hook.sol";
import { ApproveAndSwapOdosV3Hook } from "../../../../../src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { IOdosRouterV3 } from "../../../../../src/vendor/odos/IOdosRouterV3.sol";
import { Helpers } from "../../../../utils/Helpers.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockOdosV3Router is IOdosRouterV3 {
    function swap(
        swapTokenInfo calldata,
        bytes calldata,
        address,
        swapReferralInfo memory
    )
        external
        payable
        override
        returns (uint256 outputAmount)
    {
        return 0;
    }
}

contract OdosV3UnitTests is Helpers {
    ApproveAndSwapOdosV3Hook public approveAndSwapOdosV3Hook;
    SwapOdosV3Hook public swapOdosV3Hook;
    MockOdosV3Router public odosRouter;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address inputReceiver;
    address account;

    uint256 inputAmount = 1000;
    uint256 outputQuote = 900;
    uint256 outputMin = 850;
    bytes pathDefinition;
    address executor;
    uint64 referralCode = 123;
    uint64 referralFee = 0;
    address feeRecipient;

    uint256 private constant PRECISION = 1e5;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        executor = makeAddr("executor");
        inputReceiver = makeAddr("inputReceiver");
        feeRecipient = makeAddr("feeRecipient");

        odosRouter = new MockOdosV3Router();

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        inputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        outputToken = address(_outputToken);

        pathDefinition = abi.encode("mock_path_definition");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        approveAndSwapOdosV3Hook = new ApproveAndSwapOdosV3Hook(address(odosRouter));
        swapOdosV3Hook = new SwapOdosV3Hook(address(odosRouter));
    }

    // ========================== SwapOdosV3Hook: Constructor ==========================

    function test_SwapOdosV3Hook_Constructor() public view {
        assertEq(uint256(swapOdosV3Hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapOdosV3Hook.ODOS_ROUTER_V3()), address(odosRouter));
    }

    function test_SwapOdosV3Hook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapOdosV3Hook(address(0));
    }

    function test_SwapOdosV3Hook_Constants() public view {
        assertEq(swapOdosV3Hook.FEE_DENOM(), 1e18);
        assertEq(swapOdosV3Hook.MAX_REFERRAL_FEE(), 1e18 / 50); // 2%
    }

    // ========================== SwapOdosV3Hook: Build & Execution Count ==========================

    function test_SwapOdosV3Hook_Build() public view {
        bytes memory data = _buildSwapOdosV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 3); // pre + swap + post
        assertEq(executions[1].target, address(odosRouter));
        assertEq(executions[1].value, 0); // ERC-20, no value
    }

    function test_SwapOdosV3Hook_Build_VerifySwapCalldata() public view {
        bytes memory data = _buildSwapOdosV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;

        // Decode swapTokenInfo fields from calldata
        (
            address decodedInputToken,
            uint256 decodedInputAmount,
            address decodedInputReceiver,
            address decodedOutputToken,
            uint256 decodedOutputQuote,
            uint256 decodedOutputMin
        ) = _decodeSwapTokenInfo(cd);

        assertEq(decodedInputToken, inputToken);
        assertEq(decodedInputAmount, inputAmount);
        assertEq(decodedInputReceiver, inputReceiver);
        assertEq(decodedOutputToken, outputToken);
        assertEq(decodedOutputQuote, outputQuote);
        assertEq(decodedOutputMin, outputMin);
    }

    function test_SwapOdosV3Hook_Build_OutputReceiverIsAccount() public view {
        bytes memory data = _buildSwapOdosV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        address decodedOutputReceiver;
        assembly {
            decodedOutputReceiver := mload(add(cd, 228)) // offset 192 after selector
        }
        assertEq(decodedOutputReceiver, account);
    }

    function test_SwapOdosV3Hook_Build_VerifyReferralInfo() public view {
        uint64 testCode = 456;
        uint64 testFee = 1e16; // 1%
        address testRecipient = address(0xBEEF);

        bytes memory data = _buildV3DataCustomReferral(inputToken, testCode, testFee, testRecipient, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint64 decodedCode, uint64 decodedFee, address decodedRecipient) = _decodeReferralInfo(cd);

        assertEq(decodedCode, testCode);
        assertEq(decodedFee, testFee);
        assertEq(decodedRecipient, testRecipient);
    }

    function test_SwapOdosV3Hook_Build_VerifyExecutor() public view {
        bytes memory data = _buildSwapOdosV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        address decodedExecutor;
        assembly {
            decodedExecutor := mload(add(cd, 292)) // offset 256 after selector
        }
        assertEq(decodedExecutor, executor);
    }

    function test_SwapOdosV3Hook_Build_ZeroInputAmount() public view {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 0, outputQuote, outputMin, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);

        bytes memory cd = executions[1].callData;
        uint256 decodedInputAmount;
        assembly {
            decodedInputAmount := mload(add(cd, 68))
        }
        assertEq(decodedInputAmount, 0);
    }

    // ========================== SwapOdosV3Hook: decodeUsePrevHookAmount ==========================

    function test_SwapOdosV3Hook_decodeUsePrevHookAmount() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        assertEq(swapOdosV3Hook.decodeUsePrevHookAmount(data), false);

        data = _buildSwapOdosV3Data(true);
        assertEq(swapOdosV3Hook.decodeUsePrevHookAmount(data), true);
    }

    // ========================== SwapOdosV3Hook: PrevHookAmount & Slippage Recalculation ==========================

    function test_SwapOdosV3Hook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildSwapOdosV3Data(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, address(this));

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(odosRouter));
    }

    function test_SwapOdosV3Hook_SlippageRecalculation_DoublePrevAmount() public {
        // original: inputAmount=1000, outputMin=850
        // prevHook returns 2000 (2x) → outputMin should scale to ~1700
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(2000, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 2000);
        // HookDataUpdater: percentIncrease = (2000-1000)*1e5/1000 = 1e5
        // newOutputMin = 850 + 850*1e5/1e5 = 1700
        assertEq(decodedOutputMin, 1700);
    }

    function test_SwapOdosV3Hook_SlippageRecalculation_HalfPrevAmount() public {
        // original: inputAmount=1000, outputMin=850
        // prevHook returns 500 (0.5x) → outputMin should scale to ~425
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(500, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 500);
        // HookDataUpdater: percentDecrease = (1000-500)*1e5/1000 = 5e4
        // decreaseAmount = 850*5e4/1e5 = 425
        // newOutputMin = 850 - 425 = 425
        assertEq(decodedOutputMin, 425);
    }

    function test_SwapOdosV3Hook_SlippageRecalculation_EqualAmounts() public {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(1000, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 1000);
        assertEq(decodedOutputMin, 850); // unchanged
    }

    function test_SwapOdosV3Hook_SlippageRecalculation_ZeroOriginalAmount() public {
        // When original inputAmount is 0, HookDataUpdater returns outputAmount unchanged
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 0, outputQuote, 850, true);

        prevHook.setOutAmount(2000, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 2000);
        assertEq(decodedOutputMin, 850); // unchanged when _prevAmount=0
    }

    function test_SwapOdosV3Hook_SlippageRecalculation_VerySmallAmounts() public {
        // 1 wei amounts - check rounding
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1, outputQuote, 1, true);

        prevHook.setOutAmount(2, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 2);
        // percentIncrease = (2-1)*1e5/1 = 1e5
        // newOutputMin = 1 + 1*1e5/1e5 = 2
        assertEq(decodedOutputMin, 2);
    }

    function test_SwapOdosV3Hook_SlippageRecalculation_LargeAmounts() public {
        uint256 largeAmount = 1_000_000e18;
        uint256 largeOutputMin = 950_000e18;

        bytes memory data = _buildV3DataCustomAmounts(inputToken, largeAmount, outputQuote, largeOutputMin, true);

        uint256 doubleLargeAmount = 2_000_000e18;
        prevHook.setOutAmount(doubleLargeAmount, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, doubleLargeAmount);
        // percentIncrease = (2M - 1M)*1e5/1M = 1e5
        // newOutputMin = 950K + 950K*1e5/1e5 = 1.9M
        assertEq(decodedOutputMin, 1_900_000e18);
    }

    function test_SwapOdosV3Hook_ZeroPrevHookAmount() public {
        // When usePrevHookAmount=true but prevHook returns 0
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(0, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount,) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 0);
    }

    function test_SwapOdosV3Hook_NoSlippageRecalculation() public view {
        // When usePrevHookAmount=false, original values should be preserved
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 1000);
        assertEq(decodedOutputMin, 850);
    }

    // ========================== SwapOdosV3Hook: Pre/PostExecute ==========================

    function test_SwapOdosV3Hook_PreExecute() public {
        bytes memory data = _buildSwapOdosV3Data(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        swapOdosV3Hook.preExecute(address(0), account, data);

        assertEq(swapOdosV3Hook.getOutAmount(address(this)), 500);
    }

    function test_SwapOdosV3Hook_PostExecute() public {
        bytes memory data = _buildSwapOdosV3Data(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        swapOdosV3Hook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        swapOdosV3Hook.postExecute(address(0), account, data);

        assertEq(swapOdosV3Hook.getOutAmount(address(this)), 300);
    }

    function test_SwapOdosV3Hook_PrePostExecute_LargeAmounts() public {
        bytes memory data = _buildSwapOdosV3Data(false);

        MockERC20 outToken = MockERC20(outputToken);
        uint256 largePre = 1_000_000e18;
        uint256 largePost = 500_000e18;
        outToken.mint(account, largePre);

        swapOdosV3Hook.preExecute(address(0), account, data);
        assertEq(swapOdosV3Hook.getOutAmount(address(this)), largePre);

        outToken.mint(account, largePost);
        swapOdosV3Hook.postExecute(address(0), account, data);
        assertEq(swapOdosV3Hook.getOutAmount(address(this)), largePost);
    }

    // ========================== SwapOdosV3Hook: Inspect ==========================

    function test_SwapOdosV3Hook_inspect() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        bytes memory argsEncoded = swapOdosV3Hook.inspect(data);
        assertEq(argsEncoded.length, 60);
    }

    function test_SwapOdosV3Hook_inspect_Format() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        bytes memory argsEncoded = swapOdosV3Hook.inspect(data);

        address decodedInputReceiver = BytesLib.toAddress(argsEncoded, 0);
        address decodedExecutor = BytesLib.toAddress(argsEncoded, 20);
        address decodedFeeRecipient = BytesLib.toAddress(argsEncoded, 40);

        assertEq(decodedInputReceiver, inputReceiver);
        assertEq(decodedExecutor, executor);
        assertEq(decodedFeeRecipient, feeRecipient);
    }

    function test_SwapOdosV3Hook_inspect_DifferentPathLengths() public view {
        // Short path
        bytes memory shortPath = hex"aabb";
        bytes memory data1 = _buildV3DataWithPath(inputToken, shortPath, false);
        bytes memory inspected1 = swapOdosV3Hook.inspect(data1);
        assertEq(inspected1.length, 60);
        assertEq(BytesLib.toAddress(inspected1, 0), inputReceiver);
        assertEq(BytesLib.toAddress(inspected1, 20), executor);

        // Long path
        bytes memory longPath = new bytes(256);
        for (uint256 i = 0; i < 256; i++) {
            longPath[i] = bytes1(uint8(i % 256));
        }
        bytes memory data2 = _buildV3DataWithPath(inputToken, longPath, false);
        bytes memory inspected2 = swapOdosV3Hook.inspect(data2);
        assertEq(inspected2.length, 60);
        assertEq(BytesLib.toAddress(inspected2, 0), inputReceiver);
        assertEq(BytesLib.toAddress(inspected2, 20), executor);
    }

    // ========================== SwapOdosV3Hook: Fee Validation ==========================

    function test_SwapOdosV3Hook_RevertIf_ReferralFeeTooHigh() public {
        uint64 excessiveFee = swapOdosV3Hook.MAX_REFERRAL_FEE() + 1;

        bytes memory data = _buildV3DataWithFee(inputToken, excessiveFee, feeRecipient, false);

        vm.expectRevert(SwapOdosV3Hook.REFERRAL_FEE_TOO_HIGH.selector);
        swapOdosV3Hook.build(address(prevHook), account, data);
    }

    function test_SwapOdosV3Hook_RevertIf_FeeRecipientZeroWithNonZeroFee() public {
        bytes memory data = _buildV3DataWithFee(inputToken, 1, address(0), false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        swapOdosV3Hook.build(address(prevHook), account, data);
    }

    function test_SwapOdosV3Hook_FeeAtExactMax() public view {
        uint64 maxFee = swapOdosV3Hook.MAX_REFERRAL_FEE();

        bytes memory data = _buildV3DataWithFee(inputToken, maxFee, feeRecipient, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_SwapOdosV3Hook_ZeroFee_ZeroRecipient() public view {
        bytes memory data = _buildV3DataWithFee(inputToken, 0, address(0), false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_SwapOdosV3Hook_ZeroFee_NonZeroRecipient() public view {
        // Zero fee with non-zero recipient should not revert
        bytes memory data = _buildV3DataWithFee(inputToken, 0, feeRecipient, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    // ========================== SwapOdosV3Hook: Native ETH ==========================

    function test_SwapOdosV3Hook_NativeInput() public view {
        bytes memory data = _buildNativeInputSwapV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].value, inputAmount);
    }

    function test_SwapOdosV3Hook_NativeInput_VerifyCalldata() public view {
        bytes memory data = _buildNativeInputSwapV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (address decodedInputToken, uint256 decodedInputAmount,,,,) = _decodeSwapTokenInfo(cd);

        assertEq(decodedInputToken, address(0)); // native ETH
        assertEq(decodedInputAmount, inputAmount);
        assertEq(executions[1].value, inputAmount);
        assertEq(executions[1].target, address(odosRouter));
    }

    function test_SwapOdosV3Hook_NativeInput_WithPrevHookAmount() public {
        bytes memory data = _buildV3DataCustomAmountsNative(address(0), 1000, outputQuote, 850, true);

        uint256 prevAmount = 2000;
        prevHook.setOutAmount(prevAmount, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions[1].value, prevAmount); // value should be prevHookAmount
    }

    function test_SwapOdosV3Hook_PreExecute_NativeOutput() public {
        bytes memory data = _buildNativeOutputV3Data(false);
        vm.deal(account, inputAmount);
        swapOdosV3Hook.preExecute(address(prevHook), account, data);
        assertEq(swapOdosV3Hook.getOutAmount(account), inputAmount);
    }

    function test_SwapOdosV3Hook_PostExecute_NativeOutput() public {
        bytes memory data = _buildNativeOutputV3Data(false);
        vm.deal(account, 500);
        swapOdosV3Hook.preExecute(address(prevHook), account, data);
        assertEq(swapOdosV3Hook.getOutAmount(account), 500);

        vm.deal(account, 800);
        swapOdosV3Hook.postExecute(address(prevHook), account, data);
        assertEq(swapOdosV3Hook.getOutAmount(account), 300); // 800 - 500
    }

    // ========================== SwapOdosV3Hook: Path Definition Lengths ==========================

    function test_SwapOdosV3Hook_EmptyPathDefinition() public view {
        bytes memory emptyPath = bytes("");
        bytes memory data = _buildV3DataWithPath(inputToken, emptyPath, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_SwapOdosV3Hook_LongPathDefinition() public view {
        bytes memory longPath = new bytes(512);
        for (uint256 i = 0; i < 512; i++) {
            longPath[i] = bytes1(uint8(i % 256));
        }

        bytes memory data = _buildV3DataWithPath(inputToken, longPath, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_SwapOdosV3Hook_DifferentPathLengths_PreservesTail() public view {
        // Verify that executor and referral fields decode correctly with different path lengths
        bytes memory shortPath = hex"aa";
        bytes memory data1 = _buildV3DataWithPath(inputToken, shortPath, false);
        bytes memory inspected1 = swapOdosV3Hook.inspect(data1);
        assertEq(BytesLib.toAddress(inspected1, 0), inputReceiver);
        assertEq(BytesLib.toAddress(inspected1, 20), executor);
        assertEq(BytesLib.toAddress(inspected1, 40), feeRecipient);

        bytes memory mediumPath = abi.encode("medium", "path", "definition", "data");
        bytes memory data2 = _buildV3DataWithPath(inputToken, mediumPath, false);
        bytes memory inspected2 = swapOdosV3Hook.inspect(data2);
        assertEq(BytesLib.toAddress(inspected2, 0), inputReceiver);
        assertEq(BytesLib.toAddress(inspected2, 20), executor);
        assertEq(BytesLib.toAddress(inspected2, 40), feeRecipient);
    }

    // ========================== SwapOdosV3Hook: Fuzz ==========================

    function testFuzz_SwapOdosV3Hook_ReferralFeeBoundary(uint64 fee) public {
        uint64 maxFee = swapOdosV3Hook.MAX_REFERRAL_FEE();
        address recipient = fee > 0 ? feeRecipient : address(0);

        bytes memory data = _buildV3DataWithFee(inputToken, fee, recipient, false);

        if (fee > maxFee) {
            vm.expectRevert(SwapOdosV3Hook.REFERRAL_FEE_TOO_HIGH.selector);
            swapOdosV3Hook.build(address(prevHook), account, data);
        } else {
            Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
            assertEq(executions.length, 3);
        }
    }

    function testFuzz_SwapOdosV3Hook_SlippageRecalculation(
        uint256 originalAmount,
        uint256 originalMinOut,
        uint256 prevAmount
    )
        public
    {
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        originalMinOut = bound(originalMinOut, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        bytes memory data = _buildV3DataCustomAmounts(inputToken, originalAmount, outputQuote, originalMinOut, true);

        prevHook.setOutAmount(prevAmount, account);
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount,) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, prevAmount);
    }

    function testFuzz_SwapOdosV3Hook_InputAmount(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);

        bytes memory data = _buildV3DataCustomAmounts(inputToken, amount, outputQuote, outputMin, false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Constructor ==========================

    function test_ApproveAndSwapOdosV3Hook_Constructor() public view {
        assertEq(uint256(approveAndSwapOdosV3Hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapOdosV3Hook.ODOS_ROUTER_V3()), address(odosRouter));
    }

    function test_ApproveAndSwapOdosV3Hook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapOdosV3Hook(address(0));
    }

    function test_ApproveAndSwapOdosV3Hook_Constants() public view {
        assertEq(approveAndSwapOdosV3Hook.FEE_DENOM(), 1e18);
        assertEq(approveAndSwapOdosV3Hook.MAX_REFERRAL_FEE(), 1e18 / 50);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Build & Execution Count ==========================

    function test_ApproveAndSwapOdosV3Hook_Build() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 6); // pre + approve(0) + approve(amount) + swap + approve(0) + post
        assertEq(executions[1].target, address(inputToken)); // approve(0)
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(inputToken)); // approve(amount)
        assertEq(executions[2].value, 0);
        assertEq(executions[3].target, address(odosRouter)); // swap
        assertEq(executions[3].value, 0);
        assertEq(executions[4].target, address(inputToken)); // approve(0) cleanup
        assertEq(executions[4].value, 0);
    }

    function test_ApproveAndSwapOdosV3Hook_Build_VerifyApproveSequence() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        // Execution[1]: approve(router, 0)
        (address spender1, uint256 amount1) = _decodeApproveCalldata(executions[1].callData);
        assertEq(spender1, address(odosRouter));
        assertEq(amount1, 0);

        // Execution[2]: approve(router, inputAmount)
        (address spender2, uint256 amount2) = _decodeApproveCalldata(executions[2].callData);
        assertEq(spender2, address(odosRouter));
        assertEq(amount2, inputAmount);

        // Execution[4]: approve(router, 0) cleanup
        (address spender4, uint256 amount4) = _decodeApproveCalldata(executions[4].callData);
        assertEq(spender4, address(odosRouter));
        assertEq(amount4, 0);
    }

    function test_ApproveAndSwapOdosV3Hook_Build_VerifySwapCalldata() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData; // swap is at index 3

        (
            address decodedInputToken,
            uint256 decodedInputAmount,
            address decodedInputReceiver,
            address decodedOutputToken,
            uint256 decodedOutputQuote,
            uint256 decodedOutputMin
        ) = _decodeSwapTokenInfo(cd);

        assertEq(decodedInputToken, inputToken);
        assertEq(decodedInputAmount, inputAmount);
        assertEq(decodedInputReceiver, inputReceiver);
        assertEq(decodedOutputToken, outputToken);
        assertEq(decodedOutputQuote, outputQuote);
        assertEq(decodedOutputMin, outputMin);
    }

    function test_ApproveAndSwapOdosV3Hook_Build_OutputReceiverIsAccount() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        address decodedOutputReceiver;
        assembly {
            decodedOutputReceiver := mload(add(cd, 228))
        }
        assertEq(decodedOutputReceiver, account);
    }

    function test_ApproveAndSwapOdosV3Hook_Build_VerifyReferralInfo() public view {
        uint64 testCode = 789;
        uint64 testFee = 5e15; // 0.5%
        address testRecipient = address(0xBEEF);

        bytes memory data = _buildV3DataCustomReferral(inputToken, testCode, testFee, testRecipient, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint64 decodedCode, uint64 decodedFee, address decodedRecipient) = _decodeReferralInfo(cd);

        assertEq(decodedCode, testCode);
        assertEq(decodedFee, testFee);
        assertEq(decodedRecipient, testRecipient);
    }

    function test_ApproveAndSwapOdosV3Hook_Build_VerifyExecutor() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        address decodedExecutor;
        assembly {
            decodedExecutor := mload(add(cd, 292))
        }
        assertEq(decodedExecutor, executor);
    }

    function test_ApproveAndSwapOdosV3Hook_Build_ZeroInputAmount() public view {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 0, outputQuote, outputMin, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);

        // Approve amount should also be 0
        (, uint256 approveAmount) = _decodeApproveCalldata(executions[2].callData);
        assertEq(approveAmount, 0);
    }

    // ========================== ApproveAndSwapOdosV3Hook: decodeUsePrevHookAmount ==========================

    function test_ApproveAndSwapOdosV3Hook_DecodeUsePrevHookAmount() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        assertFalse(approveAndSwapOdosV3Hook.decodeUsePrevHookAmount(data));

        data = _buildApproveAndSwapOdosV3Data(true);
        assertTrue(approveAndSwapOdosV3Hook.decodeUsePrevHookAmount(data));
    }

    // ========================== ApproveAndSwapOdosV3Hook: PrevHookAmount & Slippage ==========================

    function test_ApproveAndSwapOdosV3Hook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildApproveAndSwapOdosV3Data(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, address(this));

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(odosRouter));
    }

    function test_ApproveAndSwapOdosV3Hook_ApproveAmountMatchesPrevHook() public {
        uint256 prevHookAmount = 5000;
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        // approve(amount) at index 2 should use prevHookAmount
        (, uint256 approveAmount) = _decodeApproveCalldata(executions[2].callData);
        assertEq(approveAmount, prevHookAmount);
    }

    function test_ApproveAndSwapOdosV3Hook_SlippageRecalculation_DoublePrevAmount() public {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(2000, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 2000);
        assertEq(decodedOutputMin, 1700);
    }

    function test_ApproveAndSwapOdosV3Hook_SlippageRecalculation_HalfPrevAmount() public {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(500, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 500);
        assertEq(decodedOutputMin, 425);
    }

    function test_ApproveAndSwapOdosV3Hook_SlippageRecalculation_ZeroOriginalAmount() public {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 0, outputQuote, 850, true);

        prevHook.setOutAmount(2000, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 2000);
        assertEq(decodedOutputMin, 850); // unchanged when _prevAmount=0
    }

    function test_ApproveAndSwapOdosV3Hook_ZeroPrevHookAmount() public {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, true);

        prevHook.setOutAmount(0, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint256 decodedInputAmount,) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 0);

        // approve amount should also be 0
        (, uint256 approveAmount) = _decodeApproveCalldata(executions[2].callData);
        assertEq(approveAmount, 0);
    }

    function test_ApproveAndSwapOdosV3Hook_NoSlippageRecalculation() public view {
        bytes memory data = _buildV3DataCustomAmounts(inputToken, 1000, outputQuote, 850, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint256 decodedInputAmount, uint256 decodedOutputMin) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, 1000);
        assertEq(decodedOutputMin, 850);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Pre/PostExecute ==========================

    function test_ApproveAndSwapOdosV3Hook_PreExecute() public {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosV3Hook.preExecute(address(0), account, data);

        assertEq(approveAndSwapOdosV3Hook.getOutAmount(address(this)), 500);
    }

    function test_ApproveAndSwapOdosV3Hook_PostExecute() public {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosV3Hook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        approveAndSwapOdosV3Hook.postExecute(address(0), account, data);

        assertEq(approveAndSwapOdosV3Hook.getOutAmount(address(this)), 300);
    }

    function test_ApproveAndSwapOdosV3Hook_PreExecute_NativeOutput() public {
        bytes memory data = _buildNativeOutputV3Data(false);
        vm.deal(account, inputAmount);
        approveAndSwapOdosV3Hook.preExecute(address(prevHook), account, data);
        assertEq(approveAndSwapOdosV3Hook.getOutAmount(account), inputAmount);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Inspect ==========================

    function test_ApproveAndSwapOdosV3Hook_inspect() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        bytes memory argsEncoded = approveAndSwapOdosV3Hook.inspect(data);
        assertEq(argsEncoded.length, 60);
    }

    function test_ApproveAndSwapOdosV3Hook_inspect_Format() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        bytes memory argsEncoded = approveAndSwapOdosV3Hook.inspect(data);

        address decodedInputReceiver = BytesLib.toAddress(argsEncoded, 0);
        address decodedExecutor = BytesLib.toAddress(argsEncoded, 20);
        address decodedFeeRecipient = BytesLib.toAddress(argsEncoded, 40);

        assertEq(decodedInputReceiver, inputReceiver);
        assertEq(decodedExecutor, executor);
        assertEq(decodedFeeRecipient, feeRecipient);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Fee Validation ==========================

    function test_ApproveAndSwapOdosV3Hook_RevertIf_ReferralFeeTooHigh() public {
        uint64 excessiveFee = approveAndSwapOdosV3Hook.MAX_REFERRAL_FEE() + 1;

        bytes memory data = _buildV3DataWithFee(inputToken, excessiveFee, feeRecipient, false);

        vm.expectRevert(SwapOdosV3Hook.REFERRAL_FEE_TOO_HIGH.selector);
        approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapOdosV3Hook_RevertIf_FeeRecipientZeroWithNonZeroFee() public {
        uint64 nonZeroFee = 1;

        bytes memory data = _buildV3DataWithFee(inputToken, nonZeroFee, address(0), false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapOdosV3Hook_FeeAtExactMax() public view {
        uint64 maxFee = approveAndSwapOdosV3Hook.MAX_REFERRAL_FEE();

        bytes memory data = _buildV3DataWithFee(inputToken, maxFee, feeRecipient, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_ApproveAndSwapOdosV3Hook_ZeroFee_ZeroRecipient() public view {
        bytes memory data = _buildV3DataWithFee(inputToken, 0, address(0), false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Native ETH ==========================

    function test_ApproveAndSwapOdosV3Hook_NativeInput_ExecutionCount() public view {
        bytes memory data = _buildNativeInputV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        // Native input: pre + 1 swap + post = 3 (no approvals)
        assertEq(executions.length, 3);
    }

    function test_ApproveAndSwapOdosV3Hook_NativeInput_VerifyValue() public view {
        bytes memory data = _buildNativeInputV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions[1].value, inputAmount);
        assertEq(executions[1].target, address(odosRouter));
    }

    function test_ApproveAndSwapOdosV3Hook_NativeInput_VerifyCalldata() public view {
        bytes memory data = _buildNativeInputV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[1].callData;
        (address decodedInputToken, uint256 decodedInputAmount,,,,) = _decodeSwapTokenInfo(cd);

        assertEq(decodedInputToken, address(0));
        assertEq(decodedInputAmount, inputAmount);
    }

    function test_ApproveAndSwapOdosV3Hook_NativeInput_NoApproveExecutions() public view {
        bytes memory data = _buildNativeInputV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        // Should be exactly 3 executions: pre + swap + post
        // No approve calls at all (unlike 6 for ERC-20)
        assertEq(executions.length, 3);

        // Verify the middle execution is the swap, not an approve
        assertEq(executions[1].target, address(odosRouter));
    }

    function test_ApproveAndSwapOdosV3Hook_NativeInput_WithPrevHookAmount() public {
        bytes memory data = _buildV3DataCustomAmountsNative(address(0), 1000, outputQuote, 850, true);

        uint256 prevAmount = 3000;
        prevHook.setOutAmount(prevAmount, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 3); // still 3 for native
        assertEq(executions[1].value, prevAmount);

        bytes memory cd = executions[1].callData;
        (uint256 decodedInputAmount,) = _decodeAmountsFromSwap(cd);
        assertEq(decodedInputAmount, prevAmount);
    }

    function test_ApproveAndSwapOdosV3Hook_NativeInput_WithReferralFee() public view {
        uint64 testFee = 1e16;
        address testRecipient = address(0xCAFE);

        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(uint64(42)),
            bytes8(testFee),
            bytes20(testRecipient)
        );
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(address(0)),  // native ETH input
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(payload.length),
            payload
        );

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3); // still 3 for native

        bytes memory cd = executions[1].callData;
        (uint64 decodedCode, uint64 decodedFee, address decodedRecipient) = _decodeReferralInfo(cd);
        assertEq(decodedCode, 42);
        assertEq(decodedFee, testFee);
        assertEq(decodedRecipient, testRecipient);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Path Definition ==========================

    function test_ApproveAndSwapOdosV3Hook_DifferentPathLengths() public view {
        bytes memory shortPath = hex"aabbcc";
        bytes memory data = _buildV3DataWithPath(inputToken, shortPath, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);

        bytes memory longPath = new bytes(1024);
        data = _buildV3DataWithPath(inputToken, longPath, false);
        executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    // ========================== ApproveAndSwapOdosV3Hook: Fuzz ==========================

    function testFuzz_ApproveAndSwapOdosV3Hook_ReferralFeeBoundary(uint64 fee) public {
        uint64 maxFee = approveAndSwapOdosV3Hook.MAX_REFERRAL_FEE();
        address recipient = fee > 0 ? feeRecipient : address(0);

        bytes memory data = _buildV3DataWithFee(inputToken, fee, recipient, false);

        if (fee > maxFee) {
            vm.expectRevert(SwapOdosV3Hook.REFERRAL_FEE_TOO_HIGH.selector);
            approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        } else {
            Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
            assertGt(executions.length, 0);
        }
    }

    function testFuzz_ApproveAndSwapOdosV3Hook_SlippageRecalculation(
        uint256 originalAmount,
        uint256 originalMinOut,
        uint256 prevAmount
    )
        public
    {
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        originalMinOut = bound(originalMinOut, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        bytes memory data = _buildV3DataCustomAmounts(inputToken, originalAmount, outputQuote, originalMinOut, true);

        prevHook.setOutAmount(prevAmount, account);
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        bytes memory cd = executions[3].callData;
        (uint256 decodedInputAmount,) = _decodeAmountsFromSwap(cd);

        assertEq(decodedInputAmount, prevAmount);

        // approve amount should match prevAmount
        (, uint256 approveAmount) = _decodeApproveCalldata(executions[2].callData);
        assertEq(approveAmount, prevAmount);
    }

    function testFuzz_ApproveAndSwapOdosV3Hook_InputAmount(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);

        bytes memory data = _buildV3DataCustomAmounts(inputToken, amount, outputQuote, outputMin, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function testFuzz_ApproveAndSwapOdosV3Hook_NativeETH_InputAmount(uint256 amount) public view {
        amount = bound(amount, 0, type(uint128).max);

        bytes memory data = _buildV3DataCustomAmountsNative(address(0), amount, outputQuote, outputMin, false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3); // native: no approvals
        assertEq(executions[1].value, amount);
    }

    // ========================== Boolean Decoding Edge Cases ==========================

    function test_BooleanDecoding_True_SwapHook() public {
        bytes memory data = _buildSwapOdosV3Data(true);

        prevHook.setOutAmount(2000, address(this));

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
    }

    function test_BooleanDecoding_False_SwapHook() public view {
        bytes memory data = _buildSwapOdosV3Data(false);

        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
    }

    function test_BooleanDecoding_True_ApproveAndSwapHook() public {
        bytes memory data = _buildApproveAndSwapOdosV3Data(true);

        prevHook.setOutAmount(2000, address(this));

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
    }

    function test_BooleanDecoding_False_ApproveAndSwapHook() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);

        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
    }

    // ========================== Calldata Decoders ==========================

    function _decodeSwapTokenInfo(bytes memory cd)
        internal
        pure
        returns (
            address decodedInputToken,
            uint256 decodedInputAmount,
            address decodedInputReceiver,
            address decodedOutputToken,
            uint256 decodedOutputQuote,
            uint256 decodedOutputMin
        )
    {
        assembly {
            let base := add(cd, 36) // skip 32-byte length + 4-byte selector
            decodedInputToken := mload(base)
            decodedInputAmount := mload(add(base, 32))
            decodedInputReceiver := mload(add(base, 64))
            decodedOutputToken := mload(add(base, 96))
            decodedOutputQuote := mload(add(base, 128))
            decodedOutputMin := mload(add(base, 160))
        }
    }

    function _decodeAmountsFromSwap(bytes memory cd)
        internal
        pure
        returns (uint256 decodedInputAmount, uint256 decodedOutputMin)
    {
        assembly {
            let base := add(cd, 36)
            decodedInputAmount := mload(add(base, 32))
            decodedOutputMin := mload(add(base, 160))
        }
    }

    function _decodeReferralInfo(bytes memory cd)
        internal
        pure
        returns (uint64 decodedCode, uint64 decodedFee, address decodedRecipient)
    {
        assembly {
            let base := add(cd, 36)
            decodedCode := mload(add(base, 288))
            decodedFee := mload(add(base, 320))
            decodedRecipient := mload(add(base, 352))
        }
    }

    function _decodeApproveCalldata(bytes memory cd)
        internal
        pure
        returns (address spender, uint256 amount)
    {
        assembly {
            let base := add(cd, 36)
            spender := mload(base)
            amount := mload(add(base, 32))
        }
    }

    // ========================== DecodeAmounts/ReplaceCalldataAmounts ==========================

    function test_SwapOdosV3_DecodeAmounts() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        assertEq(swapOdosV3Hook.decodeAmounts(data)[0], inputAmount);
    }

    function test_SwapOdosV3_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapOdosV3Hook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapOdosV3_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildSwapOdosV3Data(false);
        bytes memory result = swapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapOdosV3Hook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapOdosV3_DecodeAmounts() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        assertEq(approveAndSwapOdosV3Hook.decodeAmounts(data)[0], inputAmount);
    }

    function test_ApproveAndSwapOdosV3_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapOdosV3Hook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapOdosV3_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        bytes memory result = approveAndSwapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapOdosV3Hook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapOdosV3_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapOdosV3Hook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapOdosV3Hook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapOdosV3_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildApproveAndSwapOdosV3Data(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapOdosV3Hook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapOdosV3Hook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapOdosV3_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildSwapOdosV3Data(false);
        bytes memory replaced = swapOdosV3Hook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 92 (52-byte placeholder + inputToken(20) + outputToken(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    // ========================== Data Builders ==========================

    function _buildSwapOdosV3Data(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(inputToken),  // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildApproveAndSwapOdosV3Data(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(inputToken),  // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildNativeInputV3Data(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)),   // Layer 0
            bytes20(address(0)),    // native ETH input
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload                 // Layer 2
        );
    }

    function _buildNativeInputSwapV3Data(bool usePrevious) internal view returns (bytes memory) {
        return _buildNativeInputV3Data(usePrevious);
    }

    function _buildNativeOutputV3Data(bool usePrevious) internal view returns (bytes memory) {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(inputToken),  // Layer 1
            bytes20(address(0)),  // native ETH output
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildV3DataCustomAmounts(
        address _inputToken,
        uint256 _inputAmount,
        uint256 _outputQuote,
        uint256 _outputMin,
        bool usePrevious
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(_inputToken), // Layer 1
            bytes20(outputToken),
            bytes32(_inputAmount),
            bytes32(_outputQuote),
            bytes32(_outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildV3DataCustomAmountsNative(
        address _inputToken,
        uint256 _inputAmount,
        uint256 _outputQuote,
        uint256 _outputMin,
        bool usePrevious
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(_inputToken), // Layer 1
            bytes20(outputToken),
            bytes32(_inputAmount),
            bytes32(_outputQuote),
            bytes32(_outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildV3DataWithFee(
        address _inputToken,
        uint64 _referralFee,
        address _feeRecipient,
        bool usePrevious
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(_referralFee),
            bytes20(_feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(_inputToken), // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildV3DataCustomReferral(
        address _inputToken,
        uint64 _referralCode,
        uint64 _referralFee,
        address _feeRecipient,
        bool usePrevious
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes8(_referralCode),
            bytes8(_referralFee),
            bytes20(_feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(_inputToken), // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }

    function _buildV3DataWithPath(
        address _inputToken,
        bytes memory _pathDefinition,
        bool usePrevious
    )
        internal
        view
        returns (bytes memory)
    {
        bytes memory payload = bytes.concat(
            bytes20(inputReceiver),
            bytes32(_pathDefinition.length),
            _pathDefinition,
            bytes20(executor),
            bytes8(referralCode),
            bytes8(referralFee),
            bytes20(feeRecipient)
        );
        return bytes.concat(
            bytes(new bytes(52)), // Layer 0
            bytes20(_inputToken), // Layer 1
            bytes20(outputToken),
            bytes32(inputAmount),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(payload.length),
            payload               // Layer 2
        );
    }
}
