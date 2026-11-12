// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { SwapEverlongHook } from "../../../../../src/hooks/swappers/everlong/SwapEverlongHook.sol";
import { ApproveAndSwapEverlongHook } from "../../../../../src/hooks/swappers/everlong/ApproveAndSwapEverlongHook.sol";
import { EverlongAmountUpdater } from "../../../../../src/libraries/EverlongAmountUpdater.sol";
import { ISwapRouter02 } from "../../../../../src/vendor/everlong/ISwapRouter02.sol";
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
import { EverlongKatanaFixtures } from "../../../../integration/everlong/EverlongKatanaFixtures.sol";

contract EverlongHookTest is Test, EverlongKatanaFixtures {
    SwapEverlongHook private swapHook;
    ApproveAndSwapEverlongHook private approveHook;
    MockHook private prevHook;

    address private account;
    address private inputToken;
    address private outputToken;
    address private weth9; // a local ERC20 standing in for WETH9 so the hooks' balance reads work off-fork
    address private constant THIS = address(2);
    uint256 private constant DEADLINE = 1_800_000_000;

    // quote 1000 in -> two legs 600 + 400; tail min 900 (pre-fee); header min 950
    uint256 private constant IN = 1000;
    uint256 private constant TAIL_MIN = 900;
    uint256 private constant HEADER_MIN = 950;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        inputToken = address(new MockERC20("Input", "IN", 18));
        outputToken = address(new MockERC20("Output", "OUT", 18));
        weth9 = address(new MockERC20("Wrapped Native", "WETH9", 18));
        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);
        prevHook.setOutToken(inputToken);

        swapHook = new SwapEverlongHook(EVERLONG_ROUTER, weth9, NATIVE);
        approveHook = new ApproveAndSwapEverlongHook(EVERLONG_ROUTER, weth9, NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapEverlongHook(address(0), WETH9, NATIVE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapEverlongHook(EVERLONG_ROUTER, address(0), NATIVE);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapEverlongHook(EVERLONG_ROUTER, WETH9, address(0));
        assertEq(swapHook.ROUTER(), EVERLONG_ROUTER);
        assertEq(approveHook.WETH9(), weth9);
        assertEq(approveHook.NATIVE(), NATIVE);
    }

    /*//////////////////////////////////////////////////////////////
                              BUILD SHAPE
    //////////////////////////////////////////////////////////////*/

    function test_Swap_FixedAmount_SingleExecutionToRouter() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        Execution[] memory ex = swapHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].target, EVERLONG_ROUTER);
        assertEq(ex[1].value, 0);
        assertEq(ex[1].callData, txData, "fixed path forwards the bytes untouched");
    }

    function test_ApproveAndSwap_FixedAmount_ApproveSwapReset() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 6);
        assertEq(ex[1].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, 0)));
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, IN)), "approval == sum of legs");
        assertEq(ex[3].target, EVERLONG_ROUTER);
        assertEq(ex[3].callData, txData);
        assertEq(ex[4].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, 0)));
    }

    function test_NativeInput_ForwardsValue_NoApprovals() public view {
        bytes memory txData = _txNativeIn(outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(NATIVE, outputToken, IN, HEADER_MIN, false, txData);
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex.length, 3);
        assertEq(ex[1].value, IN);
        ex = swapHook.build(address(prevHook), account, _data(address(0), outputToken, IN, HEADER_MIN, false, txData));
        assertEq(ex[1].value, IN, "address(0) header also native");
    }

    function test_NativeOutput_RequiresUnwrapTail() public {
        bytes memory txData = _txNativeOut(inputToken, IN, TAIL_MIN, account);
        swapHook.build(address(prevHook), account, _data(inputToken, NATIVE, IN, HEADER_MIN, false, txData));
        // header NATIVE with a sweep(WETH9) tail: the account would receive WETH, not native -> rejected
        bytes memory sweepWeth = _txTo(inputToken, weth9, IN, TAIL_MIN, account);
        vm.expectRevert(SwapEverlongHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, NATIVE, IN, HEADER_MIN, false, sweepWeth));
        // header WETH9 (ERC20) with a sweep(WETH9) tail is a plain ERC20 swap
        swapHook.build(address(prevHook), account, _data(inputToken, weth9, IN, HEADER_MIN, false, sweepWeth));
        // header WETH9 with an unwrap tail: account would get native, header says ERC20 -> rejected
        vm.expectRevert(SwapEverlongHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, weth9, IN, HEADER_MIN, false, txData));
    }

    /*//////////////////////////////////////////////////////////////
                           VALIDATION (fixed path)
    //////////////////////////////////////////////////////////////*/

    function test_Revert_InputTokenMismatch_And_NativeLegsMustBeWeth9() public {
        bytes memory txData = _tx(address(0xBAD), outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapEverlongHook.INPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
        vm.expectRevert(ApproveAndSwapEverlongHook.INPUT_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
        // header NATIVE but legs in an ERC20 (not WETH9)
        bytes memory erc20Legs = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        vm.expectRevert(SwapEverlongHook.INPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, _data(NATIVE, outputToken, IN, HEADER_MIN, false, erc20Legs));
    }

    function test_Revert_OutputTokenMismatch() public {
        bytes memory txData = _tx(inputToken, address(0xBAD), IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(SwapEverlongHook.OUTPUT_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_SameInputOutput_ZeroOutputMin_RecipientNotAccount() public {
        bytes memory same = _tx(inputToken, inputToken, IN, TAIL_MIN, account);
        vm.expectRevert(SwapEverlongHook.SAME_INPUT_OUTPUT_TOKEN.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, inputToken, IN, HEADER_MIN, false, same));

        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        vm.expectRevert(ApproveAndSwapEverlongHook.ZERO_OUTPUT_MIN.selector);
        approveHook.build(address(prevHook), account, _data(inputToken, outputToken, IN, 0, false, txData));

        bytes memory other = _tx(inputToken, outputToken, IN, TAIL_MIN, address(0xBAD));
        vm.expectRevert(SwapEverlongHook.INVALID_RECIPIENT.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, outputToken, IN, HEADER_MIN, false, other));
    }

    function test_Revert_HeaderAmountMismatch_BothPaths() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        vm.expectRevert(SwapEverlongHook.INPUT_AMOUNT_MISMATCH.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, outputToken, IN + 1, HEADER_MIN, false, txData));
        prevHook.setOutAmount(900, account);
        vm.expectRevert(ApproveAndSwapEverlongHook.INPUT_AMOUNT_MISMATCH.selector);
        approveHook.build(address(prevHook), account, _data(inputToken, outputToken, IN * 2, HEADER_MIN, true, txData));
    }

    function test_Revert_UnsupportedLegSurfacesFromLibrary() public {
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(inputToken, outputToken, IN);
        c[1] = abi.encodeWithSelector(bytes4(0x09b81346), inputToken, uint256(1)); // exactOutput
        c[2] = _sweepFee(outputToken, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, _mc(c));
        vm.expectRevert(
            abi.encodeWithSelector(EverlongAmountUpdater.UNSUPPORTED_LEG_SELECTOR.selector, bytes4(0x09b81346))
        );
        swapHook.build(address(prevHook), account, data);
        // leg paying the account directly (bypasses the tail)
        bytes[] memory c2 = new bytes[](2);
        c2[0] = abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(inputToken, outputToken, 500, account, IN, 0, 0)
        );
        c2[1] = _sweepFee(outputToken, TAIL_MIN, account);
        vm.expectRevert(EverlongAmountUpdater.INVALID_LEG_RECIPIENT.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, outputToken, IN, HEADER_MIN, false, _mc(c2)));
    }

    function test_Revert_MalformedPayload() public {
        bytes memory data = bytes.concat(
            new bytes(52),
            bytes20(inputToken),
            bytes20(outputToken),
            bytes32(IN),
            bytes32(HEADER_MIN),
            bytes32(HEADER_MIN),
            bytes1(0),
            bytes32(uint256(4)),
            hex"deadbeef"
        );
        vm.expectRevert();
        swapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                    usePrevHookAmount (the chained path)
    //////////////////////////////////////////////////////////////*/

    function test_UsePrevHookAmount_MultiSplit_SumEqualsExecutionAmount_Down() public {
        prevHook.setOutAmount(950, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, 950)), "approval == execution");
        EverlongAmountUpdater.Fields memory f = _fields(ex[3].callData);
        assertEq(f.totalIn, 950, "sum of rescaled legs == execution amount");
        assertEq(f.tailMin, 855, "tail min ceil(900 * 0.95)");
        assertEq(f.recipient, account);
        assertEq(f.deadline, DEADLINE, "deadline untouched");
        (uint256 l0, uint256 l1) = _legs2(ex[3].callData);
        assertEq(l0, 570, "leg 0 floor(600 * 0.95)");
        assertEq(l1, 380, "leg 1 remainder");
    }

    function test_UsePrevHookAmount_MultiSplit_Up_RemainderOnLastLeg() public {
        prevHook.setOutAmount(1001, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        Execution[] memory ex =
            swapHook.build(address(prevHook), account, _data(inputToken, outputToken, IN, HEADER_MIN, true, txData));
        (uint256 l0, uint256 l1) = _legs2(ex[1].callData);
        assertEq(l0, 600); // floor(600.6)
        assertEq(l1, 401, "remainder absorbs the rounding so the sum is exact");
        assertEq(_fields(ex[1].callData).tailMin, 901); // ceil(900.9)
    }

    function test_UsePrevHookAmount_NativeInput_ValueEqualsSumOfLegs() public {
        prevHook.setOutAmount(1234, account);
        prevHook.setOutToken(NATIVE);
        bytes memory txData = _txNativeIn(outputToken, IN, TAIL_MIN, account);
        Execution[] memory ex =
            approveHook.build(address(prevHook), account, _data(NATIVE, outputToken, IN, HEADER_MIN, true, txData));
        assertEq(ex.length, 3, "no approvals for native");
        assertEq(ex[1].value, 1234);
        EverlongAmountUpdater.Fields memory f = _fields(ex[1].callData);
        assertEq(f.totalIn, 1234, "value == sum of legs");
        assertTrue(f.hasRefund, "refundETH kept");
        assertEq(f.tailMin, 1111); // ceil(900 * 1.234)
    }

    function test_UsePrevHookAmount_PrevTokenZeroAddress_NativeInput_Ok() public {
        prevHook.setOutAmount(500, account);
        prevHook.setOutToken(address(0));
        bytes memory txData = _txNativeIn(outputToken, IN, TAIL_MIN, account);
        Execution[] memory ex =
            swapHook.build(address(prevHook), account, _data(NATIVE, outputToken, IN, HEADER_MIN, true, txData));
        assertEq(ex[1].value, 500);
    }

    function test_Revert_UsePrevHookAmount_ZeroPrevHook_ZeroAmount_PrevTokenMismatch() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        swapHook.build(address(0), account, data);

        prevHook.setOutAmount(0, account);
        vm.expectRevert(SwapEverlongHook.ZERO_EXECUTION_AMOUNT.selector);
        swapHook.build(address(prevHook), account, data);

        prevHook.setOutAmount(900, account);
        prevHook.setOutToken(outputToken);
        vm.expectRevert(ApproveAndSwapEverlongHook.PREV_TOKEN_MISMATCH.selector);
        approveHook.build(address(prevHook), account, data);
        prevHook.setOutToken(address(0)); // unset predecessor token with an ERC20 input
        vm.expectRevert(SwapEverlongHook.PREV_TOKEN_MISMATCH.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_Revert_UsePrevHookAmount_LegGoesToZero() public {
        prevHook.setOutAmount(1, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account); // legs 600 + 400 -> 0 + 1
        vm.expectRevert(EverlongAmountUpdater.ZERO_LEG_AMOUNT.selector);
        swapHook.build(address(prevHook), account, _data(inputToken, outputToken, IN, HEADER_MIN, true, txData));
    }

    /// @dev For any actual amount: legs sum to it exactly, the approval equals it, every leg stays non-zero, and the
    ///      post-execute floor is exactly ceil(headerMin * actual / quoted).
    function testFuzz_UsePrevHookAmount_SumApprovalAndFloorConsistent(uint128 actualRaw) public {
        uint256 actual = bound(uint256(actualRaw), 10, type(uint112).max);
        prevHook.setOutAmount(actual, account);
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, true, txData);

        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, actual)));
        EverlongAmountUpdater.Fields memory f = _fields(ex[3].callData);
        assertEq(f.totalIn, actual, "sum exact");
        assertEq(f.tailMin, Math.mulDiv(TAIL_MIN, actual, IN, Math.Rounding.Ceil));
        (uint256 l0, uint256 l1) = _legs2(ex[3].callData);
        assertGt(l0, 0);
        assertGt(l1, 0);
        assertEq(l0 + l1, actual);

        uint256 required = Math.mulDiv(HEADER_MIN, actual, IN, Math.Rounding.Ceil);
        approveHook.preExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, required - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ApproveAndSwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, required - 1, required
            )
        );
        approveHook.postExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, 1);
        approveHook.postExecute(address(prevHook), account, data);
        assertEq(approveHook.getOutAmount(account), required);
    }

    function test_RefundOnErc20Input_Accepted_And_NativeInRequiresRefund() public {
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(inputToken, outputToken, IN);
        c[1] = _sweepFee(outputToken, TAIL_MIN, account);
        c[2] = _refund();
        Execution[] memory ex =
            swapHook.build(address(prevHook), account, _data(inputToken, outputToken, IN, HEADER_MIN, false, _mc(c)));
        assertEq(ex[1].callData, _mc(c), "refundETH after an ERC20 swap is harmless and accepted");

        bytes[] memory noRefund = new bytes[](2);
        noRefund[0] = _eis(weth9, outputToken, IN);
        noRefund[1] = _sweepFee(outputToken, TAIL_MIN, account);
        vm.expectRevert(SwapEverlongHook.REFUND_REQUIRED_FOR_NATIVE_INPUT.selector);
        swapHook.build(address(prevHook), account, _data(NATIVE, outputToken, IN, HEADER_MIN, false, _mc(noRefund)));
        vm.expectRevert(ApproveAndSwapEverlongHook.REFUND_REQUIRED_FOR_NATIVE_INPUT.selector);
        approveHook.build(address(prevHook), account, _data(NATIVE, outputToken, IN, HEADER_MIN, false, _mc(noRefund)));
    }

    function test_ReplaceCalldataAmounts_NativeOutPayload_Builds() public view {
        bytes memory txData = _txNativeOut(inputToken, IN, TAIL_MIN, account);
        bytes memory data = _data(inputToken, NATIVE, IN, HEADER_MIN, false, txData);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 250;
        bytes memory out = approveHook.replaceCalldataAmounts(data, amounts);
        EverlongAmountUpdater.Fields memory f = _fields(abi.decode(approveHook.decodePayload(out), (bytes)));
        assertEq(f.totalIn, 250);
        assertEq(f.tailMin, 225);
        assertTrue(f.nativeOut);
        Execution[] memory ex = approveHook.build(address(prevHook), account, out);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, 250)));
    }

    /*//////////////////////////////////////////////////////////////
                       PRE / POST EXECUTE (hook floor)
    //////////////////////////////////////////////////////////////*/

    function test_PostExecute_FixedPath_EnforcesHeaderMin() public {
        bytes memory data =
            _data(inputToken, outputToken, IN, HEADER_MIN, false, _tx(inputToken, outputToken, IN, TAIL_MIN, account));
        MockERC20(outputToken).mint(account, 10);
        swapHook.preExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, HEADER_MIN - 1);
        vm.expectRevert(
            abi.encodeWithSelector(SwapEverlongHook.INSUFFICIENT_OUTPUT_AMOUNT.selector, HEADER_MIN - 1, HEADER_MIN)
        );
        swapHook.postExecute(address(prevHook), account, data);
        MockERC20(outputToken).mint(account, 1);
        swapHook.postExecute(address(prevHook), account, data);
        assertEq(swapHook.getOutAmount(account), HEADER_MIN);
        assertEq(swapHook.getOutToken(account), outputToken);
    }

    function test_PreExecute_Revert_ZeroPredecessorAmount() public {
        bytes memory data =
            _data(inputToken, outputToken, IN, HEADER_MIN, true, _tx(inputToken, outputToken, IN, TAIL_MIN, account));
        prevHook.setOutAmount(0, account);
        vm.expectRevert(SwapEverlongHook.ZERO_EXECUTION_AMOUNT.selector);
        swapHook.preExecute(address(prevHook), account, data);
    }

    function test_PostExecute_NativeOutput_UsesBalanceDelta() public {
        bytes memory data =
            _data(inputToken, NATIVE, IN, HEADER_MIN, false, _txNativeOut(inputToken, IN, TAIL_MIN, account));
        vm.deal(account, 5 ether);
        swapHook.preExecute(address(prevHook), account, data);
        vm.deal(account, 5 ether + HEADER_MIN);
        swapHook.postExecute(address(prevHook), account, data);
        assertEq(swapHook.getOutAmount(account), HEADER_MIN);
        assertEq(swapHook.getOutToken(account), NATIVE);
    }

    /// @dev Input-side floor: more input leaving the account than the execution amount reverts even when the output
    ///      floor is satisfied (the double-charge class the security review found on cyclic paths).
    function test_PostExecute_Revert_InputOverspent_ERC20() public {
        bytes memory data =
            _data(inputToken, outputToken, IN, HEADER_MIN, false, _tx(inputToken, outputToken, IN, TAIL_MIN, account));
        MockERC20(inputToken).mint(account, IN + 1);
        swapHook.preExecute(address(prevHook), account, data);
        MockERC20(inputToken).transfer(address(0xdead), IN + 1); // one wei more than the execution amount
        MockERC20(outputToken).mint(account, HEADER_MIN);
        vm.expectRevert(abi.encodeWithSelector(SwapEverlongHook.INPUT_OVERSPENT.selector, IN + 1, IN));
        swapHook.postExecute(address(prevHook), account, data);
    }

    function test_PostExecute_InputSpentExactly_Ok() public {
        bytes memory data =
            _data(inputToken, outputToken, IN, HEADER_MIN, false, _tx(inputToken, outputToken, IN, TAIL_MIN, account));
        MockERC20(inputToken).mint(account, IN);
        swapHook.preExecute(address(prevHook), account, data);
        MockERC20(inputToken).transfer(address(0xdead), IN);
        MockERC20(outputToken).mint(account, HEADER_MIN);
        swapHook.postExecute(address(prevHook), account, data);
        assertEq(swapHook.getOutAmount(account), HEADER_MIN);
    }

    function test_PostExecute_Revert_NativeInput_Weth9Decreased() public {
        bytes memory data =
            _data(NATIVE, outputToken, IN, HEADER_MIN, false, _txNativeIn(outputToken, IN, TAIL_MIN, account));
        MockERC20(weth9).mint(account, 5);
        vm.deal(account, 1 ether);
        approveHook.preExecute(address(prevHook), account, data);
        MockERC20(weth9).transfer(address(0xdead), 1); // the router pulled WETH9 through a standing allowance
        MockERC20(outputToken).mint(account, HEADER_MIN);
        vm.expectRevert(abi.encodeWithSelector(ApproveAndSwapEverlongHook.INPUT_OVERSPENT.selector, 1, 0));
        approveHook.postExecute(address(prevHook), account, data);
    }

    function test_PostExecute_NativeInput_ValueSpent_Ok() public {
        bytes memory data =
            _data(NATIVE, outputToken, IN, HEADER_MIN, false, _txNativeIn(outputToken, IN, TAIL_MIN, account));
        vm.deal(account, 1 ether);
        swapHook.preExecute(address(prevHook), account, data);
        vm.deal(account, 1 ether - IN); // exactly the execution amount left as value
        MockERC20(outputToken).mint(account, HEADER_MIN);
        swapHook.postExecute(address(prevHook), account, data);
        vm.deal(account, 1 ether);
        SwapEverlongHook fresh = new SwapEverlongHook(EVERLONG_ROUTER, weth9, NATIVE);
        fresh.preExecute(address(prevHook), account, data);
        vm.deal(account, 1 ether - IN - 1);
        MockERC20(outputToken).mint(account, HEADER_MIN);
        vm.expectRevert(abi.encodeWithSelector(SwapEverlongHook.INPUT_OVERSPENT.selector, IN + 1, IN));
        fresh.postExecute(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                         SIZING / replaceCalldataAmounts
    //////////////////////////////////////////////////////////////*/

    function test_Both_ReplaceCalldataAmounts_RescalesHeaderAndPayload() public view {
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        bytes memory data = _hookData(inputToken, outputToken, IN, 1001, HEADER_MIN, false, txData);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1500;
        bytes memory out = swapHook.replaceCalldataAmounts(data, amounts);
        assertEq(swapHook.decodeInputAmount(out), 1500);
        assertEq(swapHook.decodeOutputQuote(out), 1501, "quote floor");
        assertEq(swapHook.decodeOutputMin(out), 1425, "min ceil");
        EverlongAmountUpdater.Fields memory f = _fields(abi.decode(swapHook.decodePayload(out), (bytes)));
        assertEq(f.totalIn, 1500);
        assertEq(f.tailMin, 1350);
        assertEq(keccak256(approveHook.replaceCalldataAmounts(data, amounts)), keccak256(out));
        // resized data builds on the fixed path (header == sum of legs)
        Execution[] memory ex = swapHook.build(address(prevHook), account, out);
        assertEq(_fields(ex[1].callData).totalIn, 1500);
    }

    function test_Both_Revert_ReplaceCalldataAmounts_HeaderEmbeddedMismatch_WrongLength_Zero() public {
        bytes memory txData = _tx(inputToken, outputToken, IN, TAIL_MIN, account);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 700;
        bytes memory bad = _data(inputToken, outputToken, IN * 2, HEADER_MIN, false, txData);
        vm.expectRevert(SwapEverlongHook.INPUT_AMOUNT_MISMATCH.selector);
        swapHook.replaceCalldataAmounts(bad, amounts);
        vm.expectRevert(ApproveAndSwapEverlongHook.INPUT_AMOUNT_MISMATCH.selector);
        approveHook.replaceCalldataAmounts(bad, amounts);

        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, txData);
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        swapHook.replaceCalldataAmounts(data, new uint256[](2));
        amounts[0] = 0;
        vm.expectRevert(EverlongAmountUpdater.ZERO_AMOUNT.selector);
        approveHook.replaceCalldataAmounts(data, amounts);
    }

    /*//////////////////////////////////////////////////////////////
                           METADATA / FIXTURE
    //////////////////////////////////////////////////////////////*/

    function test_Both_Metadata_Interfaces_Inspect() public view {
        assertEq(swapHook.name(), "Swap Everlong");
        assertEq(swapHook.description(), "Swaps tokens via Everlong Router aggregator");
        assertEq(approveHook.name(), "Approve and Swap Everlong");
        assertEq(approveHook.description(), "Approves and swaps tokens via Everlong Router aggregator");
        assertEq(swapHook.subtype(), keccak256("Swap"));
        address[2] memory hooks = [address(swapHook), address(approveHook)];
        for (uint256 i; i < 2; i++) {
            IERC165 h = IERC165(hooks[i]);
            assertTrue(h.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
            assertTrue(h.supportsInterface(type(ISuperHookOutflow).interfaceId));
            assertTrue(h.supportsInterface(type(ISuperHook).interfaceId));
            assertTrue(h.supportsInterface(type(ISuperHookResult).interfaceId));
            assertTrue(h.supportsInterface(type(ISuperHookInspector).interfaceId));
        }
        bytes memory data = _data(inputToken, outputToken, IN, HEADER_MIN, false, hex"");
        assertEq(swapHook.inspect(data), abi.encodePacked(outputToken));
        uint256[] memory a = approveHook.decodeAmounts(data);
        assertEq(a[0], IN);
        assertEq(uint8(swapHook.amountRoles(data)[0].dir), uint8(ISuperHookInflowOutflow.Direction.IN));
    }

    function test_Decoders_OnLiveFixture_And_Build() public {
        bytes memory txData = _withRecipient(TX_USDC_KAT, TAIL_RECIPIENT_OFFSET_USDC_KAT, account);
        bytes memory data =
            _hookData(VB_USDC, KAT, QUOTE_USDC_KAT_IN, QUOTE_USDC_KAT_OUT, HEADER_MIN_USDC_KAT, true, txData);
        assertEq(swapHook.decodeInputToken(data), VB_USDC);
        assertEq(swapHook.decodeOutputToken(data), KAT);
        assertEq(swapHook.decodeInputAmount(data), QUOTE_USDC_KAT_IN);
        assertEq(swapHook.decodeOutputMin(data), HEADER_MIN_USDC_KAT);
        assertTrue(swapHook.decodeUsePrevHookAmount(data));
        assertEq(abi.decode(swapHook.decodePayload(data), (bytes)), txData);
        // the live 3-leg sample rescales to 95% through the hook with the sum exact
        prevHook.setOutToken(VB_USDC);
        prevHook.setOutAmount(95_000_000, account);
        Execution[] memory ex = approveHook.build(address(prevHook), account, data);
        EverlongAmountUpdater.Fields memory f = _fields(ex[3].callData);
        assertEq(f.totalIn, 95_000_000);
        assertEq(f.tailMin, 28_790_691_722_315_338_643_762);
        assertEq(f.recipient, account);
        assertEq(ex[2].callData, abi.encodeCall(IERC20.approve, (EVERLONG_ROUTER, 95_000_000)));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _eis(address tIn, address tOut, uint256 amountIn) private pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ISwapRouter02.exactInputSingle.selector,
            ISwapRouter02.ExactInputSingleParams(tIn, tOut, 500, THIS, amountIn, 0, 0)
        );
    }

    function _sweepFee(address token, uint256 min, address rcpt) private pure returns (bytes memory) {
        return
            abi.encodeWithSelector(
                ISwapRouter02.sweepTokenWithFee.selector, token, min, rcpt, uint256(4), FEE_RECIPIENT
            );
    }

    function _unwrapFee(uint256 min, address rcpt) private pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.unwrapWETH9WithFee.selector, min, rcpt, uint256(4), FEE_RECIPIENT);
    }

    function _refund() private pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.refundETH.selector);
    }

    function _mc(bytes[] memory calls) private pure returns (bytes memory) {
        return abi.encodeWithSelector(ISwapRouter02.multicall.selector, DEADLINE, calls);
    }

    /// @dev Two-leg (60/40) ERC20 -> ERC20 multicall with a sweepTokenWithFee tail.
    function _tx(
        address tIn,
        address tOut,
        uint256 amountIn,
        uint256 tailMin,
        address rcpt
    )
        private
        pure
        returns (bytes memory)
    {
        return _txTo(tIn, tOut, amountIn, tailMin, rcpt);
    }

    function _txTo(
        address tIn,
        address tOut,
        uint256 amountIn,
        uint256 tailMin,
        address rcpt
    )
        private
        pure
        returns (bytes memory)
    {
        bytes[] memory c = new bytes[](3);
        c[0] = _eis(tIn, tOut, amountIn * 6 / 10);
        c[1] = _eis(tIn, tOut, amountIn - amountIn * 6 / 10);
        c[2] = _sweepFee(tOut, tailMin, rcpt);
        return _mc(c);
    }

    /// @dev Native in: legs in WETH9, sweep tail, trailing refundETH.
    function _txNativeIn(
        address tOut,
        uint256 amountIn,
        uint256 tailMin,
        address rcpt
    )
        private
        view
        returns (bytes memory)
    {
        bytes[] memory c = new bytes[](4);
        c[0] = _eis(weth9, tOut, amountIn * 6 / 10);
        c[1] = _eis(weth9, tOut, amountIn - amountIn * 6 / 10);
        c[2] = _sweepFee(tOut, tailMin, rcpt);
        c[3] = _refund();
        return _mc(c);
    }

    /// @dev Native out: legs to WETH9, unwrap tail, trailing refundETH.
    function _txNativeOut(
        address tIn,
        uint256 amountIn,
        uint256 tailMin,
        address rcpt
    )
        private
        view
        returns (bytes memory)
    {
        bytes[] memory c = new bytes[](4);
        c[0] = _eis(tIn, weth9, amountIn * 6 / 10);
        c[1] = _eis(tIn, weth9, amountIn - amountIn * 6 / 10);
        c[2] = _unwrapFee(tailMin, rcpt);
        c[3] = _refund();
        return _mc(c);
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

    function _fields(bytes memory txData) private view returns (EverlongAmountUpdater.Fields memory) {
        return EverlongAmountUpdater.readFields(txData, weth9);
    }

    function _legs2(bytes memory txData) private pure returns (uint256 l0, uint256 l1) {
        bytes memory body = new bytes(txData.length - 4);
        for (uint256 i; i < body.length; ++i) {
            body[i] = txData[i + 4];
        }
        (, bytes[] memory calls) = abi.decode(body, (uint256, bytes[]));
        l0 = _amt(calls[0]);
        l1 = _amt(calls[1]);
    }

    function _amt(bytes memory c) private pure returns (uint256) {
        bytes memory body = new bytes(c.length - 4);
        for (uint256 i; i < body.length; ++i) {
            body[i] = c[i + 4];
        }
        return abi.decode(body, (ISwapRouter02.ExactInputSingleParams)).amountIn;
    }
}
