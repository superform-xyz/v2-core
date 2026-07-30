// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { PendlePTHook } from "../../../../src/hooks/swappers/pendle/PendlePTHook.sol";
import {
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    Order,
    OrderType,
    SwapData,
    SwapType
} from "../../../../src/vendor/pendle/IPendleRouterV4.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockPendleRouter } from "../../../mocks/MockPendleRouter.sol";
import { MockPendleMarket } from "../../../mocks/MockPendleMarket.sol";
import { MockYieldToken } from "../../../mocks/MockYieldToken.sol";
import { MockStandardizedYield } from "../../../mocks/MockStandardizedYield.sol";
import { ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow } from "../../../../src/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";
import { HookDataUpdater } from "../../../../src/libraries/HookDataUpdater.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ISuperHookSwap } from "../../../../src/interfaces/ISuperHookSwap.sol";

contract PendlePTHookTest is Helpers {
    PendlePTHook public hook;
    MockPendleRouter public pendleRouter;
    MockHook public prevHook;
    MockERC20 public inputToken;
    MockERC20 public outputToken;
    MockERC20 public ptToken;
    MockERC20 public syToken;
    MockYieldToken public ytToken;
    MockStandardizedYield public mockSY;

    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public account;
    address public market;
    uint256 public inputAmount = 1500;
    uint256 public minOut = 1000;

    function setUp() public {
        account = address(this);

        inputToken = new MockERC20("Input Token", "IN", 18);
        vm.label(address(inputToken), "Input Token");
        outputToken = new MockERC20("Output Token", "OUT", 18);
        vm.label(address(outputToken), "Output Token");

        ptToken = new MockERC20("PT Token", "PT", 18);
        vm.label(address(ptToken), "PT Token");
        syToken = new MockERC20("SY Token", "SY", 18);
        vm.label(address(syToken), "SY Token");

        // Create mock SY with tokenOut as valid output
        mockSY = new MockStandardizedYield(address(outputToken), address(ptToken), address(0));
        address[] memory validTokensOut = new address[](2);
        validTokensOut[0] = address(outputToken);
        validTokensOut[1] = address(syToken);
        mockSY.setTokensOut(validTokensOut);
        // Buy path validates isValidTokenIn — list inputToken and native (address(0))
        address[] memory validTokensIn = new address[](2);
        validTokensIn[0] = address(inputToken);
        validTokensIn[1] = address(0);
        mockSY.setTokensIn(validTokensIn);
        vm.label(address(mockSY), "Mock SY");

        // Create YT that points to the mock SY and PT
        ytToken = new MockYieldToken("YT Token", "YT", 18);
        ytToken.setSY(address(mockSY));
        ytToken.setPT(address(ptToken));
        vm.label(address(ytToken), "YT Token");

        pendleRouter = new MockPendleRouter(address(inputToken), address(ptToken), address(ytToken));
        market = address(new MockPendleMarket(address(mockSY), address(ptToken), address(ytToken)));
        vm.label(market, "Market");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));
        hook = new PendlePTHook(address(pendleRouter));
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor() public view {
        assertEq(address(hook.PENDLE_ROUTER_V4()), address(pendleRouter));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new PendlePTHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        BUY PT TESTS (outputToken == PT)
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 4 hook executions (approve(0), approve, call, approve(0)) + 2 wrappers = 6
        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(pendleRouter));
        assertEq(executions[3].value, 0);
    }

    function test_Build_BuyPt_WithNativeETH() public {
        bytes memory data = _createBuyPtDataWithNative(market, address(0), inputAmount, minOut, false);
        prevHook.setOutAmount(inputAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 1 hook execution + 2 wrappers = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, inputAmount);
    }

    function test_Build_BuyPt_NativeSentinelNormalized() public view {
        // Header inputToken = 0xEeee… sentinel — must build the native path with tokenIn = address(0)
        bytes memory data = _createBuyPtDataWithNative(market, NATIVE_TOKEN, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, inputAmount);

        bytes memory args = _removeSelector(executions[1].callData);
        (,,,, TokenInput memory input,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
        assertEq(input.tokenIn, address(0), "sentinel not normalized to address(0)");
        assertEq(input.tokenMintSy, address(0), "tokenMintSy not normalized to address(0)");
    }

    function test_Build_BuyPt_WithPrevHookAmount() public {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(2500, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(pendleRouter));
    }

    function test_Build_BuyPt_InternalSwapDataIsNone() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,,,, TokenInput memory input, LimitOrderData memory limit) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertEq(input.tokenIn, address(inputToken), "tokenIn != header inputToken");
        assertEq(input.tokenMintSy, address(inputToken), "tokenMintSy != header inputToken");
        assertEq(input.pendleSwap, address(0), "pendleSwap not zeroed");
        assertEq(uint256(input.swapData.swapType), uint256(SwapType.NONE), "swapType not NONE");
        assertEq(input.swapData.extRouter, address(0), "extRouter not zeroed");
        assertEq(input.swapData.extCalldata.length, 0, "extCalldata not empty");
        assertEq(limit.limitRouter, address(0), "limit order not empty");
        assertEq(limit.normalFills.length, 0, "normalFills not empty");
        assertEq(limit.flashFills.length, 0, "flashFills not empty");
    }

    function test_Build_BuyPt_RevertIf_TokenInNotListed() public {
        // SY that does NOT list inputToken as valid tokenIn
        address[] memory noTokens = new address[](0);
        mockSY.setTokensIn(noTokens);

        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        vm.expectRevert(PendlePTHook.TOKEN_IN_NOT_LISTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroMinOut() public {
        bytes memory data = _createBuyPtData(market, inputAmount, 0, false);
        vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroAmount() public {
        bytes memory data = _createBuyPtData(market, 0, minOut, false);
        vm.expectRevert(PendlePTHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_InvalidGuessParams() public {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 1100,
            guessMax: 900,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        vm.expectRevert(PendlePTHook.GUESS_PT_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_InvalidEps() public {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 2e18
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        vm.expectRevert(PendlePTHook.EPS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_InvalidMaxIteration() public {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 257,
            eps: 1e17
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        vm.expectRevert(PendlePTHook.MAX_ITERATION_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_MaxIterationBoundary() public view {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 256,
            eps: 1e17
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_MaxEpsBoundary() public view {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e18
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_VerifyApprovePattern() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // executions[0] = preExecute wrapper
        // executions[1] = approve(router, 0) - reset
        assertEq(executions[1].target, address(inputToken));
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));
        // executions[2] = approve(router, amount)
        assertEq(executions[2].target, address(inputToken));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), inputAmount)));
        // executions[3] = router call
        assertEq(executions[3].target, address(pendleRouter));
        // executions[4] = approve(router, 0) - cleanup
        assertEq(executions[4].target, address(inputToken));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));
    }

    /*//////////////////////////////////////////////////////////////
                        SELL PT TESTS (inputToken == PT, !expired)
    //////////////////////////////////////////////////////////////*/

    function test_Build_SellPt() public view {
        ytToken.isExpired(); // ensure not expired (default)
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 4 hook executions (approve(0), approve, call, approve(0)) + 2 wrappers = 6
        assertEq(executions.length, 6);
    }

    function test_Build_SellPt_WithPrevHookAmount() public {
        bytes memory data = _createSellPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(2500, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_SellPt_InternalFieldsZeroed() public view {
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,,, TokenOutput memory output, LimitOrderData memory limit) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        assertEq(output.tokenOut, address(outputToken), "tokenOut != header outputToken");
        assertEq(output.tokenRedeemSy, address(outputToken), "tokenRedeemSy != header outputToken");
        assertEq(output.pendleSwap, address(0), "pendleSwap not zeroed");
        assertEq(uint256(output.swapData.swapType), uint256(SwapType.NONE), "swapType not NONE");
        assertEq(output.swapData.extRouter, address(0), "extRouter not zeroed");
        assertEq(limit.limitRouter, address(0), "limit order not empty");
        assertEq(limit.normalFills.length, 0, "normalFills not empty");
        assertEq(limit.flashFills.length, 0, "flashFills not empty");
    }

    function test_Build_SellPt_RevertIf_ZeroMinOut() public {
        bytes memory data = _createSellPtData(market, inputAmount, 0, false);
        vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_ZeroAmount() public {
        bytes memory data = _createSellPtData(market, 0, minOut, false);
        vm.expectRevert(PendlePTHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_TokenOutNotListed() public {
        // Set up a new SY that does NOT list outputToken as valid
        MockStandardizedYield badSY = new MockStandardizedYield(address(outputToken), address(ptToken), address(0));
        address[] memory noTokens = new address[](0);
        badSY.setTokensOut(noTokens);

        MockYieldToken badYT = new MockYieldToken("Bad YT", "BYT", 18);
        badYT.setSY(address(badSY));
        badYT.setPT(address(ptToken));

        address badMarket = address(new MockPendleMarket(address(badSY), address(ptToken), address(badYT)));

        bytes memory data = _createSellPtData(badMarket, inputAmount, minOut, false);
        vm.expectRevert(PendlePTHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                    REDEEM PT TESTS (inputToken == PT, expired)
    //////////////////////////////////////////////////////////////*/

    function test_Build_RedeemPt_DirectRedemption() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 7 hook executions (approve(0)PT, approvePT, approve(0)YT, approveYT, redeem, approve(0)PT, approve(0)YT) + 2 wrappers = 9
        assertEq(executions.length, 9);
    }

    function test_Build_RedeemPt_WithPrevHookAmount() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(2500, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9);
    }

    function test_Build_RedeemPt_RevertIf_ZeroMinOut() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, inputAmount, 0, false);
        vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPt_RevertIf_ZeroAmount() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, 0, minOut, false);
        vm.expectRevert(PendlePTHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPt_RevertIf_TokenOutNotListed() public {
        ytToken.setExpired(true);
        MockStandardizedYield badSY = new MockStandardizedYield(address(outputToken), address(ptToken), address(0));
        address[] memory noTokens = new address[](0);
        badSY.setTokensOut(noTokens);

        MockYieldToken badYT = new MockYieldToken("Bad YT", "BYT", 18);
        badYT.setSY(address(badSY));
        badYT.setPT(address(ptToken));
        badYT.setExpired(true);

        address badMarket = address(new MockPendleMarket(address(badSY), address(ptToken), address(badYT)));

        bytes memory data = _createRedeemPtData(badMarket, inputAmount, minOut, false);
        vm.expectRevert(PendlePTHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPt_VerifyApprovePattern() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // executions[0] = preExecute
        // executions[1] = approve(router, 0) PT reset
        assertEq(executions[1].target, address(ptToken));
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));
        // executions[2] = approve(router, amount) PT
        assertEq(executions[2].target, address(ptToken));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), inputAmount)));
        // executions[3] = approve(router, 0) YT reset
        assertEq(executions[3].target, address(ytToken));
        assertEq(executions[3].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));
        // executions[4] = approve(router, amount) YT
        assertEq(executions[4].target, address(ytToken));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), inputAmount)));
        // executions[5] = redeemPyToToken call
        assertEq(executions[5].target, address(pendleRouter));
        // executions[6] = approve(router, 0) PT cleanup
        assertEq(executions[6].target, address(ptToken));
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));
        // executions[7] = approve(router, 0) YT cleanup
        assertEq(executions[7].target, address(ytToken));
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));
    }

    function test_Build_RedeemPt_InternalFieldsZeroed() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        assertEq(output.tokenOut, address(outputToken), "tokenOut != header outputToken");
        assertEq(output.tokenRedeemSy, address(outputToken), "tokenRedeemSy != header outputToken");
        assertEq(output.pendleSwap, address(0), "pendleSwap not zeroed");
        assertEq(uint256(output.swapData.swapType), uint256(SwapType.NONE), "swapType not NONE");
    }

    /*//////////////////////////////////////////////////////////////
                        INVALID OPERATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_BothTokensArePt() public {
        // inputToken == PT AND outputToken == PT
        bytes memory data = _createInvalidBothPtData(market, inputAmount, minOut, false);
        vm.expectRevert(PendlePTHook.INVALID_PT_OPERATION.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_NeitherTokenIsPt() public {
        // inputToken != PT AND outputToken != PT
        bytes memory data = _createInvalidNoPtData(market, inputAmount, minOut, false);
        vm.expectRevert(PendlePTHook.INVALID_PT_OPERATION.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_SyAddressZero() public {
        // Market with SY = address(0)
        address badMarket = address(new MockPendleMarket(address(0), address(ptToken), address(ytToken)));
        bytes memory data = _createBuyPtData(badMarket, inputAmount, minOut, false);
        vm.expectRevert(PendlePTHook.SY_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        EXPIRY BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_ExpiryRouting_PreMaturity() public view {
        // !yt.isExpired() routes to sell (4 hook execs + 2 wrappers = 6)
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_ExpiryRouting_PostMaturity() public {
        // yt.isExpired() routes to redeem (7 hook execs + 2 wrappers = 9)
        ytToken.setExpired(true);
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9);
    }

    function test_Build_ExpiryRouting_SamePayloadDifferentPath() public {
        // Sell and redeem payloads are identical (empty), so expiry-boundary routing is harmless.
        // Same payload, sell path pre-maturity
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        Execution[] memory sellExecs = hook.build(address(prevHook), account, data);
        assertEq(sellExecs.length, 6);

        // Same payload, redeem path post-maturity
        ytToken.setExpired(true);
        Execution[] memory redeemExecs = hook.build(address(prevHook), account, data);
        assertEq(redeemExecs.length, 9);
    }

    /*//////////////////////////////////////////////////////////////
                    MIN-OUT SCALING TESTS (usePrevHookAmount)
    //////////////////////////////////////////////////////////////*/

    function test_MinOutScaling_BuyPt_Increase() public {
        uint256 prevHookAmount = 3000;
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Decode swapExactTokenForPt call (index 3: preExec, approve(0), approve, call)
        bytes memory args = _removeSelector(executions[3].callData);
        (,, uint256 minPtOut_,,, ) = abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        assertEq(minPtOut_, expectedMinOut, "Buy: minPtOut not scaled on increase");
    }

    function test_MinOutScaling_BuyPt_Decrease() public {
        uint256 prevHookAmount = 750;
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,, uint256 minPtOut_,,, ) = abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        assertEq(minPtOut_, expectedMinOut, "Buy: minPtOut not scaled on decrease");
    }

    function test_MinOutScaling_SellPt_Increase() public {
        uint256 prevHookAmount = 3000;
        bytes memory data = _createSellPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Decode swapExactPtForToken call (index 3: preExec, approve(0), approve, call)
        bytes memory args = _removeSelector(executions[3].callData);
        (,,, TokenOutput memory output, ) = abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        assertEq(output.minTokenOut, expectedMinOut, "Sell: minTokenOut not scaled on increase");
    }

    function test_MinOutScaling_RedeemPt_Increase() public {
        ytToken.setExpired(true);
        uint256 prevHookAmount = 3000;
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Decode redeemPyToToken call (index 5: preExec, approve(0)PT, approvePT, approve(0)YT, approveYT, redeem)
        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        assertEq(output.minTokenOut, expectedMinOut, "Redeem: minTokenOut not scaled on increase");
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_MinOutScaling_BuyPt(uint256 prevHookAmount) public {
        prevHookAmount = bound(prevHookAmount, 1, type(uint128).max);
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);

        uint256 expectedScaledMin = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        if (expectedScaledMin == 0) {
            vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
            hook.build(address(prevHook), account, data);
        } else {
            Execution[] memory executions = hook.build(address(prevHook), account, data);
            assertGt(executions.length, 0);
        }
    }

    function testFuzz_MinOutScaling_SellPt(uint256 prevHookAmount) public {
        prevHookAmount = bound(prevHookAmount, 1, type(uint128).max);
        bytes memory data = _createSellPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);

        uint256 expectedScaledMin = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        if (expectedScaledMin == 0) {
            vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
            hook.build(address(prevHook), account, data);
        } else {
            Execution[] memory executions = hook.build(address(prevHook), account, data);
            assertGt(executions.length, 0);
        }
    }

    function testFuzz_MinOutScaling_RedeemPt(uint256 prevHookAmount) public {
        ytToken.setExpired(true);
        prevHookAmount = bound(prevHookAmount, 1, type(uint128).max);
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);

        uint256 expectedScaledMin = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut);
        if (expectedScaledMin == 0) {
            vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
            hook.build(address(prevHook), account, data);
        } else {
            Execution[] memory executions = hook.build(address(prevHook), account, data);
            assertGt(executions.length, 0);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        LIMIT ORDER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt_WithNormalFills() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_WithFlashFills() public view {
        LimitOrderData memory limit = _createLimitOrderData(false, true);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_SellPt_WithNormalFills() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_SellPt_WithFlashFills() public view {
        LimitOrderData memory limit = _createLimitOrderData(false, true);
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_RevertIf_OrderExpired() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.expiry = block.timestamp - 1;
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.ORDER_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_OrderExpired() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.expiry = block.timestamp - 1;
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.ORDER_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroMaker() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.maker = address(0);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroReceiver() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.receiver = address(0);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_TooManyFills() public {
        LimitOrderData memory limit;
        limit.limitRouter = address(0xCAFE);
        limit.normalFills = new FillOrderParams[](65);
        for (uint256 i; i < 65; ++i) {
            limit.normalFills[i] = _createValidFillOrderParams();
        }
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.TOO_MANY_FILLS.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_OptDataTooLong() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.optData = new bytes(1025);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.OPT_DATA_TOO_LONG.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroMakingAmount() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].makingAmount = 0;
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.MAKING_AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_LimitRouterZeroWithFills() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.limitRouter = address(0);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_EpsSkipMarketTooHigh() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.epsSkipMarket = 1e18 + 1;
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.EPS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_EmptySignature() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].signature = "";
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.SIGNATURE_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroOrderToken() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.token = address(0);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_ZeroOrderYT() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.YT = address(0);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_PermitTooLong() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.permit = new bytes(257);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.PERMIT_TOO_LONG.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                    LIMIT ORDER TESTS — SELL PATH REVERTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SellPt_RevertIf_ZeroMaker() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.maker = address(0);
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_TooManyFills() public {
        LimitOrderData memory limit;
        limit.limitRouter = address(0xCAFE);
        limit.flashFills = new FillOrderParams[](65);
        for (uint256 i; i < 65; ++i) {
            limit.flashFills[i] = _createValidFillOrderParams();
        }
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.TOO_MANY_FILLS.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_EpsSkipMarketTooHigh() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.epsSkipMarket = 1e18 + 1;
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.EPS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_OptDataTooLong() public {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.optData = new bytes(1025);
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.OPT_DATA_TOO_LONG.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_LimitRouterZeroWithFlashFills() public {
        LimitOrderData memory limit = _createLimitOrderData(false, true);
        limit.limitRouter = address(0);
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_FlashFillEmptySignature() public {
        LimitOrderData memory limit = _createLimitOrderData(false, true);
        limit.flashFills[0].signature = "";
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        vm.expectRevert(PendlePTHook.SIGNATURE_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                    LIMIT ORDER TESTS — BOUNDARIES
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt_MaxFillsBoundary() public view {
        LimitOrderData memory limit;
        limit.limitRouter = address(0xCAFE);
        limit.normalFills = new FillOrderParams[](64); // exactly MAX_FILLS
        for (uint256 i; i < 64; ++i) {
            limit.normalFills[i] = _createValidFillOrderParams();
        }
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_OptDataMaxLengthBoundary() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.optData = new bytes(1024); // exactly MAX_OPT_DATA_LENGTH
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_PermitMaxLengthBoundary() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.permit = new bytes(256); // exactly MAX_PERMIT_LENGTH
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_OrderExpiryAtCurrentTimestamp() public view {
        // expiry < block.timestamp reverts; expiry == block.timestamp is still valid
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.expiry = block.timestamp;
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_EpsSkipMarketMaxBoundary() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.epsSkipMarket = 1e18; // exactly MAX_EPS
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    /*//////////////////////////////////////////////////////////////
                LIMIT ORDER TESTS — ROUTER CALLDATA ROUND-TRIP
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt_LimitOrdersReachRouterCalldata() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, true);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,,,, TokenInput memory input, LimitOrderData memory decodedLimit) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertEq(decodedLimit.limitRouter, address(0xCAFE), "limitRouter should pass through");
        assertEq(decodedLimit.normalFills.length, 1, "normal fills should pass through");
        assertEq(decodedLimit.flashFills.length, 1, "flash fills should pass through");
        assertEq(decodedLimit.normalFills[0].makingAmount, 500);
        assertEq(decodedLimit.normalFills[0].order.maker, address(0xABCD));

        // Limit orders present must NOT re-enable auxiliary swapping
        assertEq(input.pendleSwap, address(0), "pendleSwap stays zeroed with limit orders");
        assertEq(uint256(input.swapData.swapType), uint256(SwapType.NONE), "swapType stays NONE with limit orders");
        assertEq(input.tokenMintSy, address(inputToken), "tokenMintSy stays the header inputToken");
    }

    function test_Build_SellPt_LimitOrdersReachRouterCalldata() public view {
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,,, TokenOutput memory output, LimitOrderData memory decodedLimit) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        assertEq(decodedLimit.limitRouter, address(0xCAFE), "limitRouter should pass through");
        assertEq(decodedLimit.normalFills.length, 1, "normal fills should pass through");

        assertEq(output.pendleSwap, address(0), "pendleSwap stays zeroed with limit orders");
        assertEq(uint256(output.swapData.swapType), uint256(SwapType.NONE), "swapType stays NONE with limit orders");
        assertEq(output.tokenRedeemSy, address(outputToken), "tokenRedeemSy stays the header outputToken");
    }

    function test_Build_BuyPt_WithLimitOrdersAndPrevHookAmount() public {
        // Min-out scaling must still apply when limit orders are present
        uint256 prevHookAmount = 3000;
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        bytes memory data = _createBuyPtDataWithLimitOrders(market, inputAmount, minOut, limit, true);
        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,, uint256 minPtOut_,, TokenInput memory input, LimitOrderData memory decodedLimit) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertEq(input.netTokenIn, prevHookAmount);
        assertEq(minPtOut_, HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minOut));
        assertEq(decodedLimit.normalFills.length, 1, "limit orders survive amount replacement");
    }

    function test_Build_RedeemPt_IgnoresExpiredLimitOrderInSellPayload() public {
        // Post-expiry, a sell payload with an EXPIRED limit order routes to redeem and is ignored
        // (redeem decodes no payload) — the signed intent stays executable after maturity.
        ytToken.setExpired(true);
        LimitOrderData memory limit = _createLimitOrderData(true, false);
        limit.normalFills[0].order.expiry = 1; // long expired
        bytes memory data = _createSellPtDataWithLimitOrders(market, inputAmount, minOut, limit, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9, "redeem path should ignore the sell payload entirely");
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_BuyPt() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        bytes memory result = hook.inspect(data);
        // yieldSource only (20 bytes) — direction-agnostic market lock
        assertEq(result.length, 20);
        assertEq(BytesLib.toAddress(result, 0), market);
    }

    function test_Inspect_SellPt() public view {
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        bytes memory result = hook.inspect(data);
        assertEq(result.length, 20);
        assertEq(BytesLib.toAddress(result, 0), market);
    }

    function test_Inspect_RedeemPt() public view {
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, false);
        bytes memory result = hook.inspect(data);
        assertEq(result.length, 20);
        assertEq(BytesLib.toAddress(result, 0), market);
    }

    function test_Inspect_SameForBothDirections() public view {
        // Buy and sell data for the same market must produce identical inspect output
        bytes memory buyData = _createBuyPtData(market, inputAmount, minOut, false);
        bytes memory sellData = _createSellPtData(market, inputAmount, minOut, false);
        assertEq(hook.inspect(buyData), hook.inspect(sellData));
    }

    /*//////////////////////////////////////////////////////////////
                    ISuperHookSwap INTERFACE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeAmounts() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        uint256[] memory amounts = hook.decodeAmounts(data);
        assertEq(amounts.length, 1);
        assertEq(amounts[0], inputAmount);
    }

    function test_AmountRoles() public view {
        ISuperHookInflowOutflow.AmountMeta[] memory meta = hook.amountRoles(new bytes(0));
        assertEq(meta.length, 1);
        assertEq(uint256(meta[0].dir), uint256(ISuperHookInflowOutflow.Direction.IN));
        assertEq(uint256(meta[0].denom), uint256(ISuperHookInflowOutflow.Denomination.TOKEN));
    }

    function test_ReplaceCalldataAmounts() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 9999;
        bytes memory result = hook.replaceCalldataAmounts(data, amounts);
        uint256 replaced = BytesLib.toUint256(result, 92);
        assertEq(replaced, 9999);
    }

    function test_ReplaceCalldataAmounts_RevertIf_InvalidLength() public {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;
        vm.expectRevert(BaseHook.INVALID_AMOUNTS_LENGTH.selector);
        hook.replaceCalldataAmounts(data, amounts);
    }

    function test_SupportsInterface_ISuperHookOutflow() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookOutflow).interfaceId));
    }

    function test_SupportsInterface_ISuperHookInflowOutflow() public view {
        assertTrue(hook.supportsInterface(type(ISuperHookInflowOutflow).interfaceId));
    }

    function test_DecodeInputToken() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        assertEq(hook.decodeInputToken(data), address(inputToken));
    }

    function test_DecodeOutputToken() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        assertEq(hook.decodeOutputToken(data), address(ptToken));
    }

    function test_DecodeInputAmount() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        assertEq(hook.decodeInputAmount(data), inputAmount);
    }

    function test_DecodeOutputQuote() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        assertEq(hook.decodeOutputQuote(data), 0);
    }

    function test_DecodeOutputMin() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        assertEq(hook.decodeOutputMin(data), minOut);
    }

    function test_DecodePayload() public view {
        // Buy payload = abi.encode(ApproxParams, LimitOrderData) — larger than the bare 160-byte ApproxParams
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        bytes memory payload = hook.decodePayload(data);
        assertGt(payload.length, 160);

        // Sell payload = abi.encode(LimitOrderData) — non-empty even with an empty limit struct
        bytes memory sellData = _createSellPtData(market, inputAmount, minOut, false);
        bytes memory sellPayload = hook.decodePayload(sellData);
        assertGt(sellPayload.length, 0);
    }

    function test_EncodeSwapData() public view {
        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: address(inputToken),
            outputToken: address(ptToken),
            inputAmount: inputAmount,
            outputQuote: 0,
            outputMin: minOut,
            usePrevHookAmount: false
        });
        LimitOrderData memory emptyLimit;
        bytes memory payload = abi.encode(ApproxParams(900, 1100, 1000, 10, 1e17), emptyLimit);
        bytes memory encoded = hook.encodeSwapData(header, payload);

        assertEq(hook.decodeInputToken(encoded), address(inputToken));
        assertEq(hook.decodeOutputToken(encoded), address(ptToken));
        assertEq(hook.decodeInputAmount(encoded), inputAmount);
        assertEq(hook.decodeOutputMin(encoded), minOut);
        assertEq(hook.decodePayload(encoded), payload);
    }

    function test_Name() public view {
        assertEq(hook.name(), "Pendle PT");
    }

    function test_Description() public view {
        assertEq(hook.description(), "Executes Pendle PT operations (buy, sell, or redeem)");
    }

    /*//////////////////////////////////////////////////////////////
                    PRE/POST EXECUTE — OUT AMOUNT TRACKING
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute() public {
        outputToken.mint(account, 500);

        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        hook.preExecute(address(0), account, data);

        assertEq(hook.getOutAmount(account), 500);
    }

    function test_PostExecute() public {
        outputToken.mint(account, 500);

        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        hook.preExecute(address(0), account, data);

        // Simulate the swap crediting the account
        outputToken.mint(account, 300);

        hook.postExecute(address(0), account, data);

        assertEq(hook.getOutAmount(account), 300, "outAmount should be the balance delta");
        assertEq(hook.getOutToken(account), address(outputToken), "outToken should be the header outputToken");
    }

    function test_PostExecute_BuyPt_TracksPtDelta() public {
        ptToken.mint(account, 100);

        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        hook.preExecute(address(0), account, data);

        // Simulate the buy crediting PT
        ptToken.mint(account, 777);

        hook.postExecute(address(0), account, data);

        assertEq(hook.getOutAmount(account), 777);
        assertEq(hook.getOutToken(account), address(ptToken));
    }

    function test_PrePostExecute_NativeOutput_ZeroAddress() public {
        address acc = makeAddr("nativeAccount");
        vm.deal(acc, 1 ether);

        bytes memory data = _createSellPtDataWithOutputToken(market, address(0), inputAmount, minOut, false);
        vm.prank(acc);
        hook.preExecute(address(0), acc, data);
        assertEq(hook.getOutAmount(acc), 1 ether, "preExecute should snapshot native balance");

        vm.deal(acc, 1.5 ether);
        vm.prank(acc);
        hook.postExecute(address(0), acc, data);
        assertEq(hook.getOutAmount(acc), 0.5 ether, "postExecute should track native delta");
    }

    function test_PrePostExecute_NativeOutput_Sentinel() public {
        address acc = makeAddr("sentinelAccount");
        vm.deal(acc, 2 ether);

        bytes memory data = _createSellPtDataWithOutputToken(market, NATIVE_TOKEN, inputAmount, minOut, false);
        vm.prank(acc);
        hook.preExecute(address(0), acc, data);
        assertEq(hook.getOutAmount(acc), 2 ether, "sentinel output should read native balance");

        vm.deal(acc, 3 ether);
        vm.prank(acc);
        hook.postExecute(address(0), acc, data);
        assertEq(hook.getOutAmount(acc), 1 ether);
    }

    /*//////////////////////////////////////////////////////////////
                    USE-PREV-HOOK-AMOUNT EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount() public view {
        assertEq(hook.decodeUsePrevHookAmount(_createBuyPtData(market, inputAmount, minOut, false)), false);
        assertEq(hook.decodeUsePrevHookAmount(_createBuyPtData(market, inputAmount, minOut, true)), true);
    }

    function test_Build_BuyPt_NativeWithPrevHookAmount() public {
        uint256 prevHookAmount = 2500;
        bytes memory data = _createBuyPtDataWithNative(market, address(0), inputAmount, minOut, true);
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, prevHookAmount, "native value should be the prev hook amount");

        bytes memory args = _removeSelector(executions[1].callData);
        (,,,, TokenInput memory input,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
        assertEq(input.netTokenIn, prevHookAmount, "netTokenIn should be the prev hook amount");
    }

    function test_Build_RevertIf_PrevHookAmountZero_ScaledMinZero() public {
        // prevHook returns 0 with a non-zero header inputAmount: outputMin scales to 0 → MIN_OUT_NOT_VALID
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(0, account);
        vm.expectRevert(PendlePTHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_PrevHookAmountZero_HeaderAmountZero() public {
        // Header inputAmount = 0 skips scaling (prevAmount == 0 → outputMin unchanged),
        // then netTokenIn = 0 from prevHook → AMOUNT_IN_NOT_VALID
        bytes memory data = _createBuyPtData(market, 0, minOut, true);
        prevHook.setOutAmount(0, account);
        vm.expectRevert(PendlePTHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        MALFORMED PAYLOAD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt_RevertIf_EmptyPayload() public {
        // Buy requires abi.encode(ApproxParams); an empty payload must revert on decode
        bytes memory data = bytes.concat(
            bytes32(0),
            bytes20(market),
            bytes20(address(inputToken)),
            bytes20(address(ptToken)),
            bytes32(inputAmount),
            bytes32(uint256(0)),
            bytes32(minOut),
            bytes1(0x00),
            bytes32(uint256(0))
        );
        vm.expectRevert();
        hook.build(address(prevHook), account, data);
    }

    function test_Build_BuyPt_RevertIf_TruncatedPayload() public {
        // Payload shorter than a full ApproxParams encoding must revert on decode
        bytes memory garbage = new bytes(64);
        bytes memory data = bytes.concat(
            bytes32(0),
            bytes20(market),
            bytes20(address(inputToken)),
            bytes20(address(ptToken)),
            bytes32(inputAmount),
            bytes32(uint256(0)),
            bytes32(minOut),
            bytes1(0x00),
            bytes32(garbage.length),
            garbage
        );
        vm.expectRevert();
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_MalformedPayload() public {
        // Sell decodes abi.encode(LimitOrderData); garbage payload must revert
        bytes memory garbage = hex"deadbeefdeadbeef";
        bytes memory data = bytes.concat(
            bytes32(0),
            bytes20(market),
            bytes20(address(ptToken)),
            bytes20(address(outputToken)),
            bytes32(inputAmount),
            bytes32(uint256(0)),
            bytes32(minOut),
            bytes1(0x00),
            bytes32(garbage.length),
            garbage
        );
        vm.expectRevert();
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPt_IgnoresNonEmptyPayload() public {
        // Redeem takes no payload (redeemPyToToken has no limit orders); trailing bytes are ignored
        ytToken.setExpired(true);
        bytes memory garbage = hex"deadbeefdeadbeef";
        bytes memory data = bytes.concat(
            bytes32(0),
            bytes20(market),
            bytes20(address(ptToken)),
            bytes20(address(outputToken)),
            bytes32(inputAmount),
            bytes32(uint256(0)),
            bytes32(minOut),
            bytes1(0x00),
            bytes32(garbage.length),
            garbage
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9);
    }

    /*//////////////////////////////////////////////////////////////
                    ROUTER CALLDATA ASSERTIONS
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt_RouterCallReceiverAndMarket() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (address receiver_, address market_, uint256 minPtOut_, ApproxParams memory guess_, TokenInput memory input_,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertEq(receiver_, account, "receiver should be the account");
        assertEq(market_, market, "market should be the yieldSource");
        assertEq(minPtOut_, minOut, "minPtOut should be the header outputMin");
        assertEq(input_.netTokenIn, inputAmount, "netTokenIn should be the header inputAmount");
        assertEq(guess_.guessMin, 900);
        assertEq(guess_.guessMax, 1100);
        assertEq(guess_.guessOffchain, 1000);
        assertEq(guess_.maxIteration, 10);
        assertEq(guess_.eps, 1e17);
    }

    function test_Build_SellPt_RouterCallReceiverAndMarket() public view {
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (address receiver_, address market_, uint256 exactPtIn_,,) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        assertEq(receiver_, account, "receiver should be the account");
        assertEq(market_, market, "market should be the yieldSource");
        assertEq(exactPtIn_, inputAmount, "exactPtIn should be the header inputAmount");
    }

    function test_Build_RedeemPt_RouterCallUsesMarketYt() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[5].callData);
        (address receiver_, address yt_, uint256 amount_,) =
            abi.decode(args, (address, address, uint256, TokenOutput));

        assertEq(receiver_, account, "receiver should be the account");
        assertEq(yt_, address(ytToken), "redeem must target the market's YT");
        assertEq(amount_, inputAmount, "redeem amount should be the header inputAmount");
    }

    function test_Build_SellPt_NativeOutput() public {
        // SY listing native (address(0)) as tokenOut: sell PT → native
        address[] memory tokensOut = new address[](1);
        tokensOut[0] = address(0);
        mockSY.setTokensOut(tokensOut);

        bytes memory data = _createSellPtDataWithOutputToken(market, address(0), inputAmount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);

        bytes memory args = _removeSelector(executions[3].callData);
        (,,, TokenOutput memory output,) = abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));
        assertEq(output.tokenOut, address(0), "tokenOut should be native (address(0))");
        assertEq(output.tokenRedeemSy, address(0), "tokenRedeemSy should follow the header outputToken");
    }

    /*//////////////////////////////////////////////////////////////
                    APPROX PARAMS BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_BuyPt_GuessMinEqualsGuessMax() public view {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 1000,
            guessMax: 1000,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_BuyPt_ZeroedApproxParams() public view {
        // All-zero ApproxParams (Pendle's "let the router decide" convention) must pass validation
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 0,
            guessMax: 0,
            guessOffchain: 0,
            maxIteration: 0,
            eps: 0
        });
        bytes memory data = _createBuyPtDataWithApprox(market, inputAmount, minOut, guessPtOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    /*//////////////////////////////////////////////////////////////
                    INTERFACE / REPLACE-AMOUNT COVERAGE
    //////////////////////////////////////////////////////////////*/

    function test_SupportsInterface_CoreInterfaces() public view {
        assertTrue(hook.supportsInterface(type(ISuperHook).interfaceId));
        assertFalse(hook.supportsInterface(bytes4(0xdeadbeef)));
    }

    function test_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 4242;
        bytes memory result = hook.replaceCalldataAmounts(data, amounts);

        assertEq(hook.decodeInputAmount(result), 4242, "amount should be replaced");
        assertEq(hook.decodeInputToken(result), address(inputToken), "inputToken must be untouched");
        assertEq(hook.decodeOutputToken(result), address(ptToken), "outputToken must be untouched");
        assertEq(hook.decodeOutputMin(result), minOut, "outputMin must be untouched");
        assertEq(hook.decodePayload(result), hook.decodePayload(data), "payload must be untouched");
        assertEq(result.length, data.length, "length must not change");
    }

    function testFuzz_ReplaceCalldataAmounts(uint256 newAmount) public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = newAmount;
        bytes memory result = hook.replaceCalldataAmounts(data, amounts);

        assertEq(hook.decodeInputAmount(result), newAmount);
        uint256[] memory decoded = hook.decodeAmounts(result);
        assertEq(decoded[0], newAmount);
    }

    function testFuzz_Build_BuyPt_NetTokenInMatchesHeader(uint256 amount) public view {
        amount = bound(amount, 1, type(uint128).max);
        bytes memory data = _createBuyPtData(market, amount, minOut, false);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[3].callData);
        (,,,, TokenInput memory input,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
        assertEq(input.netTokenIn, amount);
        // Approve execution must match the router pull amount
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), amount)));
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates buy PT data: inputToken → PT. Payload = abi.encode(ApproxParams)
    function _createBuyPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });
        return _createBuyPtDataWithApprox(market_, inputAmount_, minOut_, guessPtOut, usePrevHookAmount_);
    }

    function _createBuyPtDataWithApprox(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        ApproxParams memory guessPtOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        // No selector prefix — routingParams IS the payload
        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(guessPtOut_, emptyLimit);

        return bytes.concat(
            bytes32(0),                          // yieldSourceOracleId
            bytes20(market_),                    // yieldSource
            bytes20(address(inputToken)),        // inputToken
            bytes20(address(ptToken)),           // outputToken (PT for buy)
            bytes32(inputAmount_),               // inputAmount
            bytes32(uint256(0)),                 // outputQuote
            bytes32(minOut_),                    // outputMin
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),       // payload_paramLength
            routingParams                        // payload (no selector!)
        );
    }

    function _createBuyPtDataWithNative(
        address market_,
        address nativeInputToken_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(guessPtOut, emptyLimit);

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(nativeInputToken_),          // inputToken = address(0) or 0xEeee… sentinel
            bytes20(address(ptToken)),           // outputToken = PT
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Creates sell PT data: PT → outputToken. Payload = abi.encode(LimitOrderData) (empty limit).
    function _createSellPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        LimitOrderData memory emptyLimit;
        return _createSellPtDataWithLimitOrders(market_, inputAmount_, minOut_, emptyLimit, usePrevHookAmount_);
    }

    /// @dev Creates sell PT data with custom limit orders
    function _createSellPtDataWithLimitOrders(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        LimitOrderData memory limit_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        bytes memory routingParams = abi.encode(limit_);
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(ptToken)),           // inputToken = PT (sell)
            bytes20(address(outputToken)),       // outputToken
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Creates buy PT data with custom limit orders
    function _createBuyPtDataWithLimitOrders(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        LimitOrderData memory limit_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        bytes memory routingParams = abi.encode(guessPtOut, limit_);

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(inputToken)),
            bytes20(address(ptToken)),
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Creates a LimitOrderData with optional normal and flash fills
    function _createLimitOrderData(
        bool hasNormalFills,
        bool hasFlashFills
    ) internal view returns (LimitOrderData memory limit) {
        limit.limitRouter = address(0xCAFE);
        limit.epsSkipMarket = 0;
        limit.optData = "";

        if (hasNormalFills) {
            limit.normalFills = new FillOrderParams[](1);
            limit.normalFills[0] = _createValidFillOrderParams();
        }
        if (hasFlashFills) {
            limit.flashFills = new FillOrderParams[](1);
            limit.flashFills[0] = _createValidFillOrderParams();
        }
    }

    /// @dev Creates a valid FillOrderParams for testing
    function _createValidFillOrderParams() internal view returns (FillOrderParams memory) {
        Order memory order = Order({
            salt: 1,
            expiry: block.timestamp + 1 hours,
            nonce: 0,
            orderType: OrderType.SY_FOR_PT,
            token: address(inputToken),
            YT: address(ytToken),
            maker: address(0xABCD),
            receiver: address(0xABCD),
            makingAmount: 1000,
            lnImpliedRate: 0,
            failSafeRate: 0,
            permit: ""
        });

        return FillOrderParams({ order: order, signature: hex"deadbeef", makingAmount: 500 });
    }

    /// @dev Creates sell PT data with a custom output token (e.g. native)
    function _createSellPtDataWithOutputToken(
        address market_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(emptyLimit);
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(ptToken)),           // inputToken = PT (sell)
            bytes20(outputToken_),               // outputToken
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Creates redeem PT data: PT → outputToken (expired)
    /// Uses same layout as sell — expiry routing is handled by YT.isExpired()
    function _createRedeemPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createSellPtData(market_, inputAmount_, minOut_, usePrevHookAmount_);
    }

    /// @dev Creates invalid data where both inputToken and outputToken are PT
    function _createInvalidBothPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(ptToken)),           // inputToken = PT
            bytes20(address(ptToken)),           // outputToken = PT (invalid!)
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(uint256(0))
        );
    }

    /// @dev Creates invalid data where neither token is PT
    function _createInvalidNoPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(inputToken)),        // inputToken != PT
            bytes20(address(outputToken)),       // outputToken != PT (invalid!)
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(uint256(0))
        );
    }

    /// @dev Removes the first 4 bytes (selector) from calldata for abi.decode
    function _removeSelector(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data[i + 4];
        }
    }
}
