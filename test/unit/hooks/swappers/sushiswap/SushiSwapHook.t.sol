// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapSushiSwapHook } from "../../../../../src/hooks/swappers/sushiswap/SwapSushiSwapHook.sol";
import {
    ApproveAndSwapSushiSwapHook
} from "../../../../../src/hooks/swappers/sushiswap/ApproveAndSwapSushiSwapHook.sol";
import { SushiSwapAmountUpdater } from "../../../../../src/libraries/SushiSwapAmountUpdater.sol";
import { IRedSnwapper } from "../../../../../src/vendor/sushiswap/IRedSnwapper.sol";
import { IRouteProcessor7 } from "../../../../../src/vendor/sushiswap/IRouteProcessor7.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookInspector
} from "../../../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { SushiKatanaFixtures } from "../../../../integration/sushiswap/SushiKatanaFixtures.sol";

library BytesLibReader {
    function len(bytes memory d, uint256 off) internal pure returns (uint256 w) {
        assembly ("memory-safe") {
            w := mload(add(add(d, 0x20), off))
        }
    }
}

contract SushiSwapHookTest is Test, SushiKatanaFixtures {
    SwapSushiSwapHook private swapHook;
    ApproveAndSwapSushiSwapHook private approveHook;
    MockHook private prevHook;

    address private account;
    address private inputToken;
    address private outputToken;

    // Common fixture numbers (quote 1000 in -> 1000 out, outer floor 900, header floor 950, inner cap 1000)
    uint256 private constant IN = 1000;
    uint256 private constant OUTER_MIN = 900;
    uint256 private constant HEADER_MIN = 950;
    uint256 private constant INNER_CAP = 1000;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        inputToken = address(new MockERC20("Input", "IN", 18));
        outputToken = address(new MockERC20("Output", "OUT", 18));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);
        prevHook.setOutToken(inputToken);

        swapHook = new SwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
        approveHook = new ApproveAndSwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapSushiSwapHook(address(0), ROUTE_PROCESSOR, NATIVE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapSushiSwapHook(RED_SNWAPPER, address(0), NATIVE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, address(0));
    }

    function test_Constructor_ApproveVariant_RevertsOnZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapSushiSwapHook(address(0), ROUTE_PROCESSOR, NATIVE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapSushiSwapHook(RED_SNWAPPER, address(0), NATIVE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, address(0));
    }

    function test_Immutables() public view {
        assertEq(swapHook.RED_SNWAPPER(), RED_SNWAPPER);
        assertEq(swapHook.ROUTE_PROCESSOR(), ROUTE_PROCESSOR);
        assertEq(swapHook.NATIVE(), NATIVE);
        assertEq(approveHook.RED_SNWAPPER(), RED_SNWAPPER);
        assertEq(approveHook.ROUTE_PROCESSOR(), ROUTE_PROCESSOR);
        assertEq(approveHook.NATIVE(), NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD SHAPE
    //////////////////////////////////////////////////////////////*/

    function test_Swap_FixedAmount_SingleExecutionToRedSnwapper() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);

        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3); // pre + 1 + post
        assertEq(ex[1].target, RED_SNWAPPER);
        assertEq(ex[1].value, 0);
        assertEq(ex[1].callData, txData);
    }

    function test_ApproveAndSwap_FixedAmount_ApproveSwapReset() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 6); // pre + 4 + post
        assertEq(ex[1].target, inputToken);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, IN)));
        assertEq(ex[3].target, RED_SNWAPPER);
        assertEq(ex[3].value, 0);
        assertEq(ex[3].callData, txData);
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, 0)));
    }

    function test_NativeInput_ForwardsValue_NoApprovals() public view {
        bytes memory txData = _tx(NATIVE, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(NATIVE, outputToken, IN, HEADER_MIN, false, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].target, RED_SNWAPPER);
        assertEq(ex[1].value, IN);

        ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].value, IN);
    }

    function test_NativeInput_HeaderZeroAddress_PayloadSentinel_Ok() public view {
        bytes memory txData = _tx(NATIVE, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(address(0), outputToken, IN, HEADER_MIN, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].value, IN);
    }

    function test_Revert_NativeInput_PayloadZeroAddress() public {
        // RedSnwapper would try IERC20(0).safeTransferFrom; fail early instead.
        bytes memory txData = _tx(address(0), outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(NATIVE, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.INPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_NativeOutput_Ok_And_Revert_PayloadZeroAddress() public {
        bytes memory txData = _tx(inputToken, NATIVE, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, NATIVE, IN, HEADER_MIN, false, txData);
        swapHook.build(address(prevHook), account, data);
        data = _data(inputToken, address(0), IN, HEADER_MIN, false, txData);
        swapHook.build(address(prevHook), account, data);

        txData = _tx(inputToken, address(0), IN, OUTER_MIN, INNER_CAP, account);
        data = _data(inputToken, NATIVE, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                           VALIDATION (fixed path)
    //////////////////////////////////////////////////////////////*/

    function test_Revert_InputTokenMismatch() public {
        bytes memory txData = _tx(address(0xBAD), outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.INPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INPUT_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_OutputTokenMismatch() public {
        bytes memory txData = _tx(inputToken, address(0xBAD), IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.OUTPUT_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_SameInputOutputToken() public {
        bytes memory txData = _tx(inputToken, inputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, inputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_RecipientNotAccount() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, address(0xBAD));
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INVALID_RECIPIENT.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_InvalidExecutor() public {
        bytes memory inner = _inner(inputToken, outputToken, IN, INNER_CAP, account);
        bytes memory txData = abi.encodeWithSelector(
            IRedSnwapper.snwap.selector, inputToken, IN, account, outputToken, OUTER_MIN, address(0xBAD), inner
        );
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.INVALID_EXECUTOR.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INVALID_EXECUTOR.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_ZeroOutputMin() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, 0, false, txData);
        vm.expectRevert(SwapSushiSwapHook.ZERO_OUTPUT_MIN.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.ZERO_OUTPUT_MIN.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_HeaderAmountMismatch_FixedPath() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN + 1, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.INPUT_AMOUNT_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INPUT_AMOUNT_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_InvalidSelector_SurfacesFromLibrary() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        txData[0] = 0x00;
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_SELECTOR.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_InnerTransferValueSelector() public {
        bytes memory inner = abi.encodeWithSelector(
            bytes4(0xe9406cf4),
            address(0xFEE),
            1,
            inputToken,
            IN,
            outputToken,
            INNER_CAP,
            account,
            hex"",
            true,
            uint32(0)
        );
        bytes memory txData = abi.encodeWithSelector(
            IRedSnwapper.snwap.selector, inputToken, IN, account, outputToken, OUTER_MIN, ROUTE_PROCESSOR, inner
        );
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_INNER_SELECTOR.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_SnwapMultiple() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        (txData[0], txData[1], txData[2], txData[3]) = (bytes1(0xd3), bytes1(0x37), bytes1(0x21), bytes1(0xa5));
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SushiSwapAmountUpdater.INVALID_SELECTOR.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_MalformedPayload() public {
        bytes memory data = _dataRawPayload(inputToken, outputToken, IN, HEADER_MIN, false, hex"deadbeef");
        vm.expectRevert();
        swapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            usePrevHookAmount
    //////////////////////////////////////////////////////////////*/

    function test_UsePrevHookAmount_PatchesBothHeads_Down() public {
        prevHook.setOutAmount(950, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        _assertPatched(ex[1].callData, 950, 855, 950);

        ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, 950)), "approval == execution amount");
        _assertPatched(ex[3].callData, 950, 855, 950);
    }

    function test_UsePrevHookAmount_PatchesBothHeads_Up() public {
        prevHook.setOutAmount(1050, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, 1050)));
        _assertPatched(ex[3].callData, 1050, 945, 1050);
    }

    function test_UsePrevHookAmount_NativeInput_ValueIsScaled() public {
        prevHook.setOutAmount(1234, account);
        prevHook.setOutToken(NATIVE);
        bytes memory txData = _tx(NATIVE, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(NATIVE, outputToken, IN, HEADER_MIN, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].value, 1234);
        _assertPatched(ex[1].callData, 1234, 1111, 1234); // ceil(900*1.234)=1110.6->1111
    }

    function test_UsePrevHookAmount_PrevTokenZeroAddress_NativeInput_Ok() public {
        prevHook.setOutAmount(500, account);
        prevHook.setOutToken(address(0)); // WrappedNativeHook publishes address(0) for unwraps
        bytes memory txData = _tx(NATIVE, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(NATIVE, outputToken, IN, HEADER_MIN, true, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].value, 500);
    }

    function test_Revert_UsePrevHookAmount_ZeroPrevHook() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        swapHook.build(address(0), account, data);
    }

    function test_Revert_UsePrevHookAmount_ZeroPrevAmount() public {
        prevHook.setOutAmount(0, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);
        vm.expectRevert(SwapSushiSwapHook.ZERO_EXECUTION_AMOUNT.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.ZERO_EXECUTION_AMOUNT.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_UsePrevHookAmount_PrevTokenMismatch() public {
        prevHook.setOutAmount(900, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        prevHook.setOutToken(outputToken);
        vm.expectRevert(SwapSushiSwapHook.PREV_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);

        prevHook.setOutToken(address(0)); // unset predecessor token with an ERC20 input
        vm.expectRevert(ApproveAndSwapSushiSwapHook.PREV_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    function test_Revert_UsePrevHookAmount_HeaderAmountMismatch() public {
        prevHook.setOutAmount(900, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN * 2, HEADER_MIN, true, txData);
        vm.expectRevert(SwapSushiSwapHook.INPUT_AMOUNT_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Security_UsePrevHookAmount_WrongRecipient() public {
        prevHook.setOutAmount(900, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, address(0xBAD));
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);
        vm.expectRevert(SwapSushiSwapHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                       PRE / POST EXECUTE (hook floor)
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_FixedPath_EnforcesHeaderMin() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);

        MockERC20(outputToken).mint(account, 10); // pre-existing balance must be ignored
        swapHook.preExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, HEADER_MIN - 1);
        vm.expectRevert(
            abi.encodeWithSelector(SwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, HEADER_MIN - 1, HEADER_MIN)
        );
        swapHook.postExecute(address(prevHook), account, data);

        MockERC20(outputToken).mint(account, 1);
        swapHook.postExecute(address(prevHook), account, data);
        assertEq(swapHook.getOutAmount(account), HEADER_MIN);
        assertEq(swapHook.getOutToken(account), outputToken);
    }

    function test_PostExecute_ScaledFloor_Down_And_Up() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        // 95% -> required = ceil(950 * 950 / 1000) = 903
        prevHook.setOutAmount(950, account);
        approveHook.preExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, 902);
        vm.expectRevert(
            abi.encodeWithSelector(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, 902, 903)
        );
        approveHook.postExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, 1);
        approveHook.postExecute(address(prevHook), account, data);
        assertEq(approveHook.getOutAmount(account), 903);

        // 150% -> required = 1425 (fresh hook instance to reset mutexes)
        ApproveAndSwapSushiSwapHook fresh = new ApproveAndSwapSushiSwapHook(RED_SNWAPPER, ROUTE_PROCESSOR, NATIVE);
        prevHook.setOutAmount(1500, account);
        fresh.preExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, 1424);
        vm.expectRevert(
            abi.encodeWithSelector(ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, 1424, 1425)
        );
        fresh.postExecute(address(prevHook), account, data);
    }

    /// @dev Security review: a predecessor slot cleared between build and pre must not yield a zero floor.
    function test_PreExecute_Revert_ZeroPredecessorAmount() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);
        prevHook.setOutAmount(0, account);
        vm.expectRevert(SwapSushiSwapHook.ZERO_EXECUTION_AMOUNT.selector);
        swapHook.preExecute(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.ZERO_EXECUTION_AMOUNT.selector);
        approveHook.preExecute(address(prevHook), account, data);
    }

    function test_PostExecute_NativeOutput_UsesBalanceDelta() public {
        bytes memory txData = _tx(inputToken, NATIVE, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, NATIVE, IN, HEADER_MIN, false, txData);
        vm.deal(account, 5 ether);
        swapHook.preExecute(address(prevHook), account, data);
        vm.deal(account, 5 ether + HEADER_MIN);
        swapHook.postExecute(address(prevHook), account, data);
        assertEq(swapHook.getOutAmount(account), HEADER_MIN);
        assertEq(swapHook.getOutToken(account), NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                         SIZING / replaceCalldataAmounts
    //////////////////////////////////////////////////////////////*/

    function test_Both_ReplaceCalldataAmounts_RescalesHeaderAndPayload() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _dataWithQuote(inputToken, outputToken, IN, 1001, HEADER_MIN, false, txData);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1500;

        bytes memory out = swapHook.replaceCalldataAmounts(data, amounts);
        assertEq(swapHook.decodeInputAmount(out), 1500, "header amount");
        assertEq(swapHook.decodeOutputQuote(out), 1501, "header quote floor(1001*1.5)");
        assertEq(swapHook.decodeOutputMin(out), 1425, "header min ceil(950*1.5)");
        assertEq(swapHook.decodeInputToken(out), inputToken);
        assertEq(swapHook.decodeOutputToken(out), outputToken);
        assertFalse(swapHook.decodeUsePrevHookAmount(out));
        bytes memory patched = abi.decode(swapHook.decodePayload(out), (bytes));
        _assertPatched(patched, 1500, 1350, 1500);

        bytes memory out2 = approveHook.replaceCalldataAmounts(data, amounts);
        assertEq(keccak256(out2), keccak256(out), "both variants rewrite identically");
    }

    function test_ReplaceThenBuild_Consistent() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 700;
        bytes memory out = approveHook.replaceCalldataAmounts(data, amounts);
        Execution[] memory ex = approveHook.build(address(prevHook), account, out);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, 700)));
        _assertPatched(ex[3].callData, 700, 630, 700);
    }

    /// @dev Review finding: a header that disagrees with the embedded amount must not be "laundered" into a
    ///      consistent-looking resize (the two halves would be scaled by different denominators).
    function test_Both_Revert_ReplaceCalldataAmounts_HeaderEmbeddedMismatch() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN * 2, HEADER_MIN, false, txData);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 700;
        vm.expectRevert(SwapSushiSwapHook.INPUT_AMOUNT_MISMATCH.selector);
        swapHook.replaceCalldataAmounts(data, amounts);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INPUT_AMOUNT_MISMATCH.selector);
        approveHook.replaceCalldataAmounts(data, amounts);
    }

    function test_Revert_SameInputOutput_NativeEquivalence() public {
        bytes memory txData = _tx(NATIVE, NATIVE, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(address(0), NATIVE, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapSushiSwapHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Approve_Revert_UsePrevHookAmount_HeaderAmountMismatch() public {
        prevHook.setOutAmount(900, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN * 2, HEADER_MIN, true, txData);
        vm.expectRevert(ApproveAndSwapSushiSwapHook.INPUT_AMOUNT_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
    }

    /// @dev Non-canonical but valid ABI: executorData placed 32 bytes later than canonical (a gap word). Both the
    ///      library and RedSnwapper's decoder follow the offset word, so the patch lands on the moved words.
    function test_NonCanonicalExecutorDataOffset_PatchFollowsOffset() public {
        prevHook.setOutAmount(500, account);
        bytes memory inner = _inner(inputToken, outputToken, IN, INNER_CAP, account);
        bytes memory head = abi.encode(inputToken, IN, account, outputToken, OUTER_MIN, ROUTE_PROCESSOR, uint256(256));
        // tail = [gap word][length word][inner bytes, right-padded to 32]
        bytes memory txData = bytes.concat(
            IRedSnwapper.snwap.selector,
            head,
            new bytes(32),
            bytes32(inner.length),
            inner,
            new bytes((32 - inner.length % 32) % 32)
        );
        // sanity: canonical decode still works
        (,, address rcpt,,, address exec, bytes memory decodedInner) =
            abi.decode(_strip(txData), (address, uint256, address, address, uint256, address, bytes));
        assertEq(rcpt, account);
        assertEq(exec, ROUTE_PROCESSOR);
        assertEq(decodedInner, inner);

        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        bytes memory out = ex[1].callData;
        assertEq(_word(out, 36), 500);
        assertEq(_word(out, 296 + 32), 500, "inner amount patched at the shifted position");
        assertEq(_word(out, 360 + 32), 500, "inner cap patched at the shifted position");
    }

    function test_Both_Revert_ReplaceCalldataAmounts_WrongLength() public {
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, hex"");
        uint256[] memory amounts = new uint256[](2);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapHook.replaceCalldataAmounts(data, amounts);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        approveHook.replaceCalldataAmounts(data, amounts);
    }

    function test_Both_Revert_ReplaceCalldataAmounts_ZeroAmounts() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 10;
        bytes memory zeroHeader = _data(inputToken, outputToken, 0, HEADER_MIN, false, txData);
        vm.expectRevert(SushiSwapAmountUpdater.ZERO_AMOUNT.selector);
        swapHook.replaceCalldataAmounts(zeroHeader, amounts);
        amounts[0] = 0;
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SushiSwapAmountUpdater.ZERO_AMOUNT.selector);
        approveHook.replaceCalldataAmounts(data, amounts);
    }

    function test_Both_DecodeAmounts_And_Roles() public view {
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, hex"");
        uint256[] memory a = swapHook.decodeAmounts(data);
        assertEq(a.length, 1);
        assertEq(a[0], IN);
        a = approveHook.decodeAmounts(data);
        assertEq(a[0], IN);
        ISuperHookInflowOutflow.AmountMeta[] memory m = swapHook.amountRoles(data);
        assertEq(uint8(m[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint8(m[0].denom), uint8(ISuperHookInflowOutflow.Denomination.TOKEN));
        m = approveHook.amountRoles(data);
        assertEq(uint8(m[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
    }

    /*//////////////////////////////////////////////////////////////
                             METADATA / ERC165
    //////////////////////////////////////////////////////////////*/

    function test_Both_NameAndDescription() public view {
        assertEq(swapHook.name(), "Swap SushiSwap");
        assertEq(swapHook.description(), "Swaps tokens via SushiSwap aggregator");
        assertEq(approveHook.name(), "Approve and Swap SushiSwap");
        assertEq(approveHook.description(), "Approves and swaps tokens via SushiSwap aggregator");
        assertEq(uint8(swapHook.hookType()), uint8(ISuperHook.HookType.NONACCOUNTING));
        assertEq(swapHook.subtype(), keccak256("Swap"));
    }

    function test_Both_SupportsInterface() public view {
        address[2] memory hooks = [address(swapHook), address(approveHook)];
        for (uint256 i; i < hooks.length; i++) {
            IERC165 h = IERC165(hooks[i]);
            assertTrue(h.supportsInterface(type(ISuperHookInflowOutflow).interfaceId), "inflowoutflow");
            assertTrue(h.supportsInterface(type(ISuperHookOutflow).interfaceId), "outflow");
            assertTrue(h.supportsInterface(type(IERC165).interfaceId), "erc165");
            assertTrue(h.supportsInterface(type(ISuperHook).interfaceId), "superhook");
            assertTrue(h.supportsInterface(type(ISuperHookResult).interfaceId), "result");
            assertTrue(h.supportsInterface(type(ISuperHookInspector).interfaceId), "inspector");
            assertFalse(h.supportsInterface(bytes4(0xffffffff)), "unknown");
        }
    }

    function test_Both_Inspect_ReturnsOutputTokenOnly() public view {
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, hex"");
        assertEq(swapHook.inspect(data), abi.encodePacked(outputToken));
        assertEq(approveHook.inspect(data), abi.encodePacked(outputToken));
    }

    function test_Both_EncodeSwapData_RoundTrip() public view {
        ISuperHookSwap.SwapHeader memory hdr = ISuperHookSwap.SwapHeader({
            inputToken: inputToken,
            outputToken: outputToken,
            inputAmount: IN,
            outputQuote: 1001,
            outputMin: HEADER_MIN,
            usePrevHookAmount: true
        });
        bytes memory payload = abi.encode(hex"c0ffee");
        bytes memory enc = swapHook.encodeSwapData(hdr, payload);
        bytes memory expected = bytes.concat(
            new bytes(52),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(IN),
            bytes32(uint256(1001)),
            bytes32(HEADER_MIN),
            bytes1(uint8(1)),
            bytes32(payload.length),
            payload
        );
        assertEq(enc, expected, "layout mismatch");
        assertEq(swapHook.decodeInputToken(enc), inputToken);
        assertEq(swapHook.decodeOutputToken(enc), outputToken);
        assertEq(swapHook.decodeInputAmount(enc), IN);
        assertEq(swapHook.decodeOutputQuote(enc), 1001);
        assertEq(swapHook.decodeOutputMin(enc), HEADER_MIN);
        assertTrue(swapHook.decodeUsePrevHookAmount(enc));
        assertEq(swapHook.decodePayload(enc), payload);
        assertEq(approveHook.encodeSwapData(hdr, payload), enc);
        assertEq(approveHook.decodePayload(enc), payload);
    }

    function test_Security_TargetAlwaysPinnedRedSnwapper() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        assertEq(swapHook.build(address(prevHook), account, data)[1].target, RED_SNWAPPER);
        assertEq(approveHook.build(address(prevHook), account, data)[3].target, RED_SNWAPPER);
    }

    /*//////////////////////////////////////////////////////////////
                              FUZZ / ADVERSARIAL
    //////////////////////////////////////////////////////////////*/

    /// @dev For any actual amount, build patches both heads with the same ratio, the approval equals the actual
    ///      amount, and the floor `_postExecute` will demand equals ceil(headerMin * actual / quoted).
    function testFuzz_UsePrevHookAmount_ApprovalValueAndFloorAreConsistent(uint128 actualRaw) public {
        uint256 actual = bound(uint256(actualRaw), 1, type(uint112).max);
        prevHook.setOutAmount(actual, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (RED_SNWAPPER, actual)), "approval == actual");
        _assertPatched(
            ex[3].callData,
            actual,
            Math.mulDiv(OUTER_MIN, actual, IN, Math.Rounding.Ceil),
            Math.mulDiv(INNER_CAP, actual, IN, Math.Rounding.Ceil)
        );

        // the hook floor: exactly the scaled header min, enforced on the delta
        uint256 required = Math.mulDiv(HEADER_MIN, actual, IN, Math.Rounding.Ceil);
        approveHook.preExecute(address(prevHook), account, data);
        if (required > 1) {
            MockERC20(outputToken).mint(account, required - 1);
            vm.expectRevert(
                abi.encodeWithSelector(
                    ApproveAndSwapSushiSwapHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, required - 1, required
                )
            );
            approveHook.postExecute(address(prevHook), account, data);
            MockERC20(outputToken).mint(account, 1);
        } else {
            MockERC20(outputToken).mint(account, required);
        }
        approveHook.postExecute(address(prevHook), account, data);
        assertEq(approveHook.getOutAmount(account), required);
    }

    /// @dev Native input: the forwarded value is exactly the predecessor amount for any amount.
    function testFuzz_UsePrevHookAmount_NativeValueTracksPredecessor(uint128 actualRaw) public {
        uint256 actual = bound(uint256(actualRaw), 1, type(uint112).max);
        prevHook.setOutAmount(actual, account);
        prevHook.setOutToken(NATIVE);
        bytes memory txData = _tx(NATIVE, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(NATIVE, outputToken, IN, HEADER_MIN, true, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].value, actual);
        assertEq(_word(ex[1].callData, 36), actual);
    }

    /// @dev replaceCalldataAmounts keeps header and payload consistent for any size, and the result builds.
    function testFuzz_ReplaceCalldataAmounts_ConsistentAndBuildable(uint128 newRaw) public view {
        uint256 newAmount = bound(uint256(newRaw), 1, type(uint112).max);
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _dataWithQuote(inputToken, outputToken, IN, 1001, HEADER_MIN, false, txData);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = newAmount;

        bytes memory out = swapHook.replaceCalldataAmounts(data, amounts);
        assertEq(swapHook.decodeInputAmount(out), newAmount);
        assertEq(swapHook.decodeOutputQuote(out), Math.mulDiv(1001, newAmount, IN, Math.Rounding.Floor));
        assertEq(swapHook.decodeOutputMin(out), Math.mulDiv(HEADER_MIN, newAmount, IN, Math.Rounding.Ceil));
        bytes memory patched = abi.decode(swapHook.decodePayload(out), (bytes));
        assertEq(_word(patched, 36), newAmount);
        assertEq(_word(patched, 296), newAmount);
        // header amount == embedded amount, so the resized data passes the fixed-path consistency check
        Execution[] memory ex = swapHook.build(address(prevHook), account, out);
        assertEq(ex[1].callData, patched);
    }

    function test_Adversarial_PayloadLengthOverrunsData() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        // claim a payload longer than the data actually carries
        uint256 declared = BytesLibReader.len(data, 189);
        _write(data, 189, declared + 64);
        vm.expectRevert();
        swapHook.build(address(prevHook), account, data);
    }

    function test_Adversarial_TrailingBytesAfterPayloadAreIgnored() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, OUTER_MIN, INNER_CAP, account);
        bytes memory data = bytes.concat(_data(inputToken, outputToken, IN, HEADER_MIN, false, txData), hex"deadbeef");
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].callData, txData, "declared payload length wins; trailing bytes never reach the venue");
    }

    /// @dev A payload whose nested call names the account but whose outer recipient is a third party (or vice
    ///      versa) is rejected by the library before the hook even compares with `account`.
    function test_Adversarial_SplitRecipient_Rejected() public {
        bytes memory inner = _inner(inputToken, outputToken, IN, INNER_CAP, account);
        bytes memory txData = abi.encodeWithSelector(
            IRedSnwapper.snwap.selector, inputToken, IN, address(0xBAD), outputToken, OUTER_MIN, ROUTE_PROCESSOR, inner
        );
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SushiSwapAmountUpdater.INNER_RECIPIENT_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    /// @dev Zero-length route + takeSurplus false + referral code set: structurally valid, nothing in the head the
    ///      hook constrains, so it builds (the venue decides whether an empty route is executable).
    function test_Adversarial_UnconstrainedTailFields_Build() public view {
        bytes memory inner = abi.encodeWithSelector(
            IRouteProcessor7.processRoute.selector,
            inputToken,
            IN,
            outputToken,
            INNER_CAP,
            account,
            hex"",
            false,
            uint32(42)
        );
        bytes memory txData = abi.encodeWithSelector(
            IRedSnwapper.snwap.selector, inputToken, IN, account, outputToken, OUTER_MIN, ROUTE_PROCESSOR, inner
        );
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex[1].callData, txData);
    }

    function test_Decoders_OnLiveFixture() public view {
        bytes memory data =
            _hookData(VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, OUTER_MIN_USDC_KAT, true, TX_USDC_KAT);
        assertEq(swapHook.decodeInputToken(data), VB_USDC);
        assertEq(swapHook.decodeOutputToken(data), KAT);
        assertEq(swapHook.decodeInputAmount(data), QUOTE_USDC_KAT_IN);
        assertEq(swapHook.decodeOutputQuote(data), QUOTE_USDC_KAT_OUT);
        assertEq(swapHook.decodeOutputMin(data), OUTER_MIN_USDC_KAT);
        assertTrue(swapHook.decodeUsePrevHookAmount(data));
        assertEq(abi.decode(swapHook.decodePayload(data), (bytes)), TX_USDC_KAT);
        assertEq(swapHook.inspect(data), abi.encodePacked(KAT));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _inner(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 innerMin,
        address to
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IRouteProcessor7.processRoute.selector,
            tokenIn,
            amountIn,
            tokenOut,
            innerMin,
            to,
            hex"01aa",
            true,
            uint32(0)
        );
    }

    function _tx(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 outerMin,
        uint256 innerMin,
        address recipient
    )
        private
        pure
        returns (bytes memory)
    {
        return abi.encodeWithSelector(
            IRedSnwapper.snwap.selector,
            tokenIn,
            amountIn,
            recipient,
            tokenOut,
            outerMin,
            ROUTE_PROCESSOR,
            _inner(tokenIn, tokenOut, amountIn, innerMin, recipient)
        );
    }

    function _data(
        address in_,
        address out_,
        uint256 amount,
        uint256 outputMin,
        bool flag,
        bytes memory txData
    )
        private
        pure
        returns (bytes memory)
    {
        return _hookData(in_, out_, amount, outputMin, outputMin, flag, txData);
    }

    function _dataWithQuote(
        address in_,
        address out_,
        uint256 amount,
        uint256 quote,
        uint256 outputMin,
        bool flag,
        bytes memory txData
    )
        private
        pure
        returns (bytes memory)
    {
        return _hookData(in_, out_, amount, quote, outputMin, flag, txData);
    }

    /// @dev Header with an arbitrary (not abi.encode(bytes)) payload.
    function _dataRawPayload(
        address in_,
        address out_,
        uint256 amount,
        uint256 outputMin,
        bool flag,
        bytes memory payload
    )
        private
        pure
        returns (bytes memory)
    {
        return bytes.concat(
            new bytes(52),
            bytes20(in_),
            bytes20(out_),
            bytes32(amount),
            bytes32(outputMin),
            bytes32(outputMin),
            bytes1(flag ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    function _strip(bytes memory d) private pure returns (bytes memory out) {
        out = new bytes(d.length - 4);
        for (uint256 i; i < out.length; ++i) {
            out[i] = d[i + 4];
        }
    }

    function _assertPatched(bytes memory d, uint256 amount, uint256 outerMin, uint256 innerMin) private pure {
        assertEq(_word(d, 36), amount, "outer amountIn");
        assertEq(_word(d, 132), outerMin, "outer min");
        assertEq(_word(d, 296), amount, "inner amountIn");
        assertEq(_word(d, 360), innerMin, "inner cap");
    }
}
