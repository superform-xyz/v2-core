// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { PendlePTHook } from "../../../../src/hooks/swappers/pendle/PendlePTHook.sol";
import {
    IPendleRouterV4,
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
import { SwapCalldataLayout } from "../../../../src/libraries/SwapCalldataLayout.sol";
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
        bytes memory data = _createBuyPtDataWithNative(market, inputAmount, minOut, false);
        prevHook.setOutAmount(inputAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 1 hook execution + 2 wrappers = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, inputAmount);
    }

    function test_Build_BuyPt_WithPrevHookAmount() public {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, true);
        prevHook.setOutAmount(2500, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(pendleRouter));
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

    function test_Build_SellPt_WithSwapRouting() public view {
        bytes memory data = _createSellPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ODOS, address(0xBEEF), false
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_SellPt_WithEthWethSwapType() public view {
        // ETH_WETH allows extRouter = address(0)
        bytes memory data = _createSellPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ETH_WETH, address(0), false
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_Build_SellPt_RevertIf_NoExtRouter_SwapRouting() public {
        bytes memory data = _createSellPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ODOS, address(0), false
        );
        vm.expectRevert(PendlePTHook.EXT_ROUTER_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SellPt_RevertIf_ExtRouterNativeToken() public {
        bytes memory data = _createSellPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ODOS, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, false
        );
        vm.expectRevert(PendlePTHook.EXT_ROUTER_NOT_VALID.selector);
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

    function test_Build_SellPt_RevertIf_TokenRedeemSyNotValid() public {
        // Use swap routing with invalid tokenRedeemSy
        address invalidRedeemSy = address(0xDEAD);
        bytes memory data = _createSellPtDataWithCustomRedeemSy(
            market, inputAmount, minOut, invalidRedeemSy, SwapType.ODOS, address(0xBEEF), false
        );
        vm.expectRevert(PendlePTHook.TOKEN_REDEEM_SY_NOT_VALID.selector);
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

    function test_Build_RedeemPt_WithSwapRouting() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ODOS, address(0xBEEF), false
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
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

    function test_Build_RedeemPt_RevertIf_NoExtRouter() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ODOS, address(0), false
        );
        vm.expectRevert(PendlePTHook.EXT_ROUTER_NOT_VALID.selector);
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

    function test_Build_RedeemPt_WithEthWethSwapType() public {
        ytToken.setExpired(true);
        bytes memory data = _createRedeemPtDataWithSwapRouting(
            market, inputAmount, minOut, SwapType.ETH_WETH, address(0), false
        );
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9);
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
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_BuyPt() public view {
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        bytes memory result = hook.inspect(data);
        assertEq(result.length, 40);
        assertEq(BytesLib.toAddress(result, 0), market);
        assertEq(BytesLib.toAddress(result, 20), address(ptToken));
    }

    function test_Inspect_SellPt() public view {
        bytes memory data = _createSellPtData(market, inputAmount, minOut, false);
        bytes memory result = hook.inspect(data);
        assertEq(result.length, 40);
        assertEq(BytesLib.toAddress(result, 0), market);
        assertEq(BytesLib.toAddress(result, 20), address(outputToken));
    }

    function test_Inspect_RedeemPt() public view {
        bytes memory data = _createRedeemPtData(market, inputAmount, minOut, false);
        bytes memory result = hook.inspect(data);
        assertEq(result.length, 40);
        assertEq(BytesLib.toAddress(result, 0), market);
        assertEq(BytesLib.toAddress(result, 20), address(outputToken));
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
        bytes memory data = _createBuyPtData(market, inputAmount, minOut, false);
        bytes memory payload = hook.decodePayload(data);
        assertGt(payload.length, 0);
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
        bytes memory payload = abi.encode(address(inputToken), address(0), SwapData(SwapType.NONE, address(0), "", false), ApproxParams(900, 1100, 1000, 10, 1e17), emptyLimit);
        bytes memory encoded = hook.encodeSwapData(header, payload);

        assertEq(hook.decodeInputToken(encoded), address(inputToken));
        assertEq(hook.decodeOutputToken(encoded), address(ptToken));
        assertEq(hook.decodeInputAmount(encoded), inputAmount);
        assertEq(hook.decodeOutputMin(encoded), minOut);
    }

    function test_Name() public view {
        assertEq(hook.name(), "Pendle PT");
    }

    function test_Description() public view {
        assertEq(hook.description(), "Executes Pendle PT operations (buy, sell, or redeem)");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates buy PT data: inputToken → PT
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
        SwapData memory swapData = SwapData({
            swapType: SwapType.NONE,
            extRouter: address(0),
            extCalldata: "",
            needScale: false
        });

        LimitOrderData memory emptyLimit;

        // No selector prefix — routingParams IS the payload
        bytes memory routingParams = abi.encode(
            address(inputToken), // tokenMintSy
            address(this),       // pendleSwap
            swapData,
            guessPtOut_,
            emptyLimit
        );

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
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        SwapData memory swapData = SwapData({
            swapType: SwapType.NONE,
            extRouter: address(0),
            extCalldata: "",
            needScale: false
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        LimitOrderData memory emptyLimit;

        bytes memory routingParams = abi.encode(
            address(inputToken), // tokenMintSy
            address(this),       // pendleSwap
            swapData,
            guessPtOut,
            emptyLimit
        );

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(0)),                 // inputToken = native ETH
            bytes20(address(ptToken)),           // outputToken = PT
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Creates sell PT data: PT → outputToken
    function _createSellPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createSellPtDataWithSwapRouting(market_, inputAmount_, minOut_, SwapType.NONE, address(0), usePrevHookAmount_);
    }

    function _createSellPtDataWithSwapRouting(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createSellPtDataWithCustomRedeemSy(
            market_, inputAmount_, minOut_, address(outputToken), swapType_, extRouter_, usePrevHookAmount_
        );
    }

    function _createSellPtDataWithCustomRedeemSy(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        address tokenRedeemSy_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        SwapData memory swapData = SwapData({
            swapType: swapType_,
            extRouter: extRouter_,
            extCalldata: "",
            needScale: false
        });

        LimitOrderData memory emptyLimit;

        bytes memory routingParams = abi.encode(
            tokenRedeemSy_,
            swapType_ != SwapType.NONE ? address(0xBEEF) : address(0), // pendleSwap
            swapData,
            emptyLimit
        );

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(ptToken)),           // inputToken = PT (sell)
            bytes20(address(outputToken)),        // outputToken
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

    function _createRedeemPtDataWithSwapRouting(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createSellPtDataWithSwapRouting(market_, inputAmount_, minOut_, swapType_, extRouter_, usePrevHookAmount_);
    }

    /// @dev Creates invalid data where both inputToken and outputToken are PT
    function _createInvalidBothPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(address(outputToken), address(0), SwapData(SwapType.NONE, address(0), "", false), emptyLimit);
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(ptToken)),           // inputToken = PT
            bytes20(address(ptToken)),           // outputToken = PT (invalid!)
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Creates invalid data where neither token is PT
    function _createInvalidNoPtData(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        LimitOrderData memory emptyLimit;
        bytes memory routingParams = abi.encode(address(outputToken), address(0), SwapData(SwapType.NONE, address(0), "", false), emptyLimit);
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(inputToken)),        // inputToken != PT
            bytes20(address(outputToken)),        // outputToken != PT (invalid!)
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

    /// @dev Creates buy PT data with limit orders
    function _createBuyPtDataWithLimitOrders(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        LimitOrderData memory limit_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        SwapData memory swapData = SwapData({
            swapType: SwapType.NONE,
            extRouter: address(0),
            extCalldata: "",
            needScale: false
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        bytes memory routingParams = abi.encode(
            address(inputToken),
            address(this),
            swapData,
            guessPtOut,
            limit_
        );

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

    /// @dev Creates sell PT data with limit orders
    function _createSellPtDataWithLimitOrders(
        address market_,
        uint256 inputAmount_,
        uint256 minOut_,
        LimitOrderData memory limit_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        SwapData memory swapData = SwapData({
            swapType: SwapType.NONE,
            extRouter: address(0),
            extCalldata: "",
            needScale: false
        });

        bytes memory routingParams = abi.encode(
            address(outputToken),
            address(0),
            swapData,
            limit_
        );

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(address(ptToken)),
            bytes20(address(outputToken)),
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
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
