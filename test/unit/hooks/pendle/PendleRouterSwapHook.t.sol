// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { PendleRouterSwapHook } from "../../../../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";
import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    Order,
    SwapData,
    SwapType,
    OrderType
} from "../../../../src/vendor/pendle/IPendleRouterV4.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockPendleRouter } from "../../../mocks/MockPendleRouter.sol";
import { MockPendleMarket } from "../../../mocks/MockPendleMarket.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";

contract PendleRouterSwapHookTest is Helpers {
    PendleRouterSwapHook public hook;
    MockPendleRouter public pendleRouter;
    MockHook public prevHook;
    MockERC20 public inputToken;
    MockERC20 public outputToken;
    MockERC20 public ptToken;
    MockERC20 public ytToken;
    MockERC20 public syToken;

    address public account;
    address public receiver;
    address public market;
    uint256 public minPtOut = 1000;
    uint256 public exactPtIn = 2000;
    uint256 public inputAmount = 1500;

    function setUp() public {
        account = address(this);
        receiver = account;

        market = makeAddr("market");

        pendleRouter = new MockPendleRouter(address(inputToken), address(ptToken), address(ytToken));
        inputToken = new MockERC20("Input Token", "IN", 18);
        vm.label(address(inputToken), "Input Token");
        outputToken = new MockERC20("Output Token", "OUT", 18);
        vm.label(address(outputToken), "Output Token");

        ytToken = new MockERC20("YT Token", "YT", 18);
        vm.label(address(ytToken), "YT Token");
        syToken = new MockERC20("Sy Token", "SY", 18);
        vm.label(address(syToken), "Sy Token");
        ptToken = new MockERC20("PT Token", "PT", 18);
        vm.label(address(ptToken), "PT Token");

        market = address(new MockPendleMarket(address(syToken), address(ptToken), address(ytToken)));
        vm.label(market, "Market");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));
        hook = new PendleRouterSwapHook(address(pendleRouter));
    }

    function test_Constructor() public view {
        assertEq(address(hook.pendleRouterV4()), address(pendleRouter));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new PendleRouterSwapHook(address(0));
    }

    function test_Build_SwapExactTokenForPt() public view {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, 0);
    }

    function test_SwapExactTokenForPt_Inspector() public view {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_UsePrevHookAmount() public view {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: 950,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector, receiver, market, exactPtIn, output, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_UsePrevHookAmount_SetToTrue() public view {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: 950,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector, receiver, market, exactPtIn, output, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(1)), uint256(0), txData);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_Build_SwapExactPtForToken() public view {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: 950,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector, receiver, market, exactPtIn, output, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, 0);
    }

    function test_SwapExactPtForToken_Inspector() public view {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: 950,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector, receiver, market, exactPtIn, output, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_PendleSwap_Build_WithPrevHookAmount() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(1)), uint256(0), txData);

        prevHook.setOutAmount(2500);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, 2500);

    }

    function test_PreExecute() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        ptToken.mint(receiver, 500);
        vm.prank(receiver);
        hook.preExecute(address(0), receiver, data);
        assertEq(hook.outAmount(), 500);
    }

    function test_PostExecute() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        ptToken.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);

        ptToken.mint(receiver, 300);
        hook.postExecute(address(0), receiver, data);
        assertEq(hook.outAmount(), 300);
    }

    function test_Build_RevertIf_InvalidReceiver() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector,
            address(0), // Invalid receiver
            market,
            minPtOut,
            guessPtOut,
            input,
            limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.RECEIVER_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidMarket() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector,
            receiver,
            address(0), // Invalid market
            minPtOut,
            guessPtOut,
            input,
            limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.MARKET_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidMinPtOut() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector,
            receiver,
            market,
            0, // Invalid minPtOut
            guessPtOut,
            input,
            limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidGuessParams() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 1100, // Invalid: guessMin > guessMax
            guessMax: 900,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.INVALID_GUESS_PT_OUT.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidEps() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 2e18 // Invalid eps > 1e18
         });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.EPS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidTokenInput() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(0), // Invalid tokenMintSy
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidSwapType() public {
        bytes memory data =
            abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), bytes4(0xdeadbeef));

        vm.expectRevert(PendleRouterSwapHook.INVALID_SWAP_TYPE.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_WithLimitOrders() public view {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        Order[] memory normalOrders = new Order[](1);
        normalOrders[0] = Order({
            salt: 0,
            expiry: block.timestamp + 1,
            nonce: 0,
            orderType: OrderType.PT_FOR_SY,
            token: address(inputToken),
            YT: address(0),
            maker: address(this),
            receiver: receiver,
            makingAmount: 1000,
            lnImpliedRate: 0,
            failSafeRate: 0,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({ order: normalOrders[0], signature: "", makingAmount: 1000 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(this),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, 0);
    }

    function test_Build_RevertIf_InvalidLimitOrder() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        Order[] memory normalOrders = new Order[](1);
        normalOrders[0] = Order({
            salt: 0,
            expiry: block.timestamp + 1 hours,
            nonce: 0,
            orderType: OrderType.PT_FOR_SY,
            token: address(inputToken),
            YT: address(0),
            maker: address(0), // Invalid maker
            receiver: receiver,
            makingAmount: 1000,
            lnImpliedRate: 0,
            failSafeRate: 0,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({ order: normalOrders[0], signature: "", makingAmount: 1000 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(this),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_ExpiredLimitOrder() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        Order[] memory normalOrders = new Order[](1);
        normalOrders[0] = Order({
            salt: 0,
            expiry: block.timestamp - 1, // Expired order
            nonce: 0,
            orderType: OrderType.PT_FOR_SY,
            token: address(inputToken),
            YT: address(0),
            maker: address(this),
            receiver: receiver,
            makingAmount: 1000,
            lnImpliedRate: 0,
            failSafeRate: 0,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({ order: normalOrders[0], signature: "", makingAmount: 1000 });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(this),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.ORDER_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidMakingAmount() public {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut =
            ApproxParams({ guessMin: 900, guessMax: 1100, guessOffchain: 1000, maxIteration: 10, eps: 1e17 });

        Order[] memory normalOrders = new Order[](1);
        normalOrders[0] = Order({
            salt: 0,
            expiry: block.timestamp + 1 hours,
            nonce: 0,
            orderType: OrderType.PT_FOR_SY,
            token: address(inputToken),
            YT: address(0),
            maker: address(this),
            receiver: receiver,
            makingAmount: 1000,
            lnImpliedRate: 0,
            failSafeRate: 0,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({
            order: normalOrders[0],
            signature: "",
            makingAmount: 0 // Invalid making amount
         });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(this),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver, market, minPtOut, guessPtOut, input, limit
        );

        bytes memory data = abi.encodePacked(bytes32(bytes("")), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleRouterSwapHook.MAKING_AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }
}
