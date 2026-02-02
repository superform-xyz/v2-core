// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { PendleUnifiedHook } from "../../../../src/hooks/swappers/pendle/PendleUnifiedHook.sol";
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
import { MockYieldToken } from "../../../mocks/MockYieldToken.sol";
import { MockStandardizedYield } from "../../../mocks/MockStandardizedYield.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";

contract PendleUnifiedHookTest is Helpers {
    PendleUnifiedHook public hook;
    MockPendleRouter public pendleRouter;
    MockHook public prevHook;
    MockERC20 public inputToken;
    MockERC20 public outputToken;
    MockERC20 public ptToken;
    MockERC20 public syToken;
    MockYieldToken public ytToken;
    MockStandardizedYield public mockSY;

    address public account;
    address public receiver;
    address public market;
    uint256 public minPtOut = 1000;
    uint256 public exactPtIn = 2000;
    uint256 public inputAmount = 1500;
    uint256 public redeemAmount = 1500;
    uint256 public minTokenOut = 1000;

    function setUp() public {
        account = address(this);
        receiver = account;

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
        // Market should use mockSY (not syToken) because the hook validates via market.readTokens().sy
        market = address(new MockPendleMarket(address(mockSY), address(ptToken), address(ytToken)));
        vm.label(market, "Market");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(inputToken));
        hook = new PendleUnifiedHook(address(pendleRouter));
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
        new PendleUnifiedHook(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                        SWAP EXACT TOKEN FOR PT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SwapExactTokenForPt() public view {
        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 1 hook execution + 2 wrappers (preExecute, postExecute) = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, 0);
    }

    function test_Build_SwapExactTokenForPt_WithNativeETH() public {
        bytes memory data = _createSwapTokenForPtDataWithNative(receiver, market, minPtOut, inputAmount, false);

        prevHook.setOutAmount(inputAmount, account);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 1 hook execution + 2 wrappers = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, inputAmount);
    }

    function test_Build_SwapExactTokenForPt_WithPrevHookAmount() public {
        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, true);

        prevHook.setOutAmount(2500, account);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
    }

    function test_Build_SwapExactTokenForPt_RevertIf_InvalidReceiver() public {
        bytes memory data = _createSwapTokenForPtData(address(0x123), market, minPtOut, inputAmount, false);

        vm.expectRevert(PendleUnifiedHook.RECEIVER_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_InvalidMarket() public {
        // Create data where yieldSource (header) is real market, but txData has different market
        bytes memory data = _createSwapTokenForPtDataWithYieldSource(
            market, // yieldSource in header = real market
            receiver,
            address(0x456), // market in txData = different (invalid)
            minPtOut,
            inputAmount,
            false
        );

        vm.expectRevert(PendleUnifiedHook.MARKET_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_ZeroMinPtOut() public {
        bytes memory data = _createSwapTokenForPtData(receiver, market, 0, inputAmount, false);

        vm.expectRevert(PendleUnifiedHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_ZeroAmount() public {
        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, 0, false);

        vm.expectRevert(PendleUnifiedHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_InvalidGuessParams() public {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 1100,
            guessMax: 900, // Invalid: guessMin > guessMax
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        bytes memory data = _createSwapTokenForPtDataWithApprox(receiver, market, minPtOut, inputAmount, guessPtOut, false);

        vm.expectRevert(PendleUnifiedHook.INVALID_GUESS_PT_OUT.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_InvalidEps() public {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 2e18 // Invalid: eps > 1e18
        });

        bytes memory data = _createSwapTokenForPtDataWithApprox(receiver, market, minPtOut, inputAmount, guessPtOut, false);

        vm.expectRevert(PendleUnifiedHook.EPS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        SWAP EXACT PT FOR TOKEN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SwapExactPtForToken() public view {
        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 1 hook execution + 2 wrappers = 3
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
        assertEq(executions[1].value, 0);
    }

    function test_Build_SwapExactPtForToken_WithPrevHookAmount() public {
        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, true);

        prevHook.setOutAmount(3000, account);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
    }

    function test_Build_SwapExactPtForToken_RevertIf_InvalidReceiver() public {
        bytes memory data = _createSwapPtForTokenData(address(0x123), market, exactPtIn, minTokenOut, false);

        vm.expectRevert(PendleUnifiedHook.RECEIVER_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactPtForToken_RevertIf_InvalidMarket() public {
        // Create data where yieldSource (header) is real market, but txData has different market
        bytes memory data = _createSwapPtForTokenDataWithYieldSource(
            market, // yieldSource in header = real market
            receiver,
            address(0x456), // market in txData = different (invalid)
            exactPtIn,
            minTokenOut,
            false
        );

        vm.expectRevert(PendleUnifiedHook.MARKET_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactPtForToken_RevertIf_ZeroMinTokenOut() public {
        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, 0, false);

        vm.expectRevert(PendleUnifiedHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactPtForToken_RevertIf_ZeroAmount() public {
        bytes memory data = _createSwapPtForTokenData(receiver, market, 0, minTokenOut, false);

        vm.expectRevert(PendleUnifiedHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        REDEEM PY TO TOKEN TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RedeemPyToToken_DirectRedemption() public view {
        // Direct redemption: tokenOut is valid SY output token
        // yieldSource is now always the market address
        bytes memory data = _createRedeemData(
            market, // yieldSource is market, not YT
            redeemAmount,
            address(outputToken), // tokenOut == tokenRedeemSy
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        // 3 hook executions (approve PT, approve YT, redeemPyToToken) + 2 wrappers = 5
        assertEq(executions.length, 5);
        assertEq(executions[1].target, address(ptToken)); // PT approval
        assertEq(executions[2].target, address(ytToken)); // YT approval
        assertEq(executions[3].target, address(pendleRouter)); // redeemPyToToken
    }

    function test_Build_RedeemPyToToken_WithSwapRouting() public {
        // CORE FIX TEST: Swap routing where tokenOut != tokenRedeemSy
        // tokenRedeemSy (outputToken) is valid SY output
        // tokenOut (inputToken) is NOT a valid SY output, but that's OK with swap routing
        address tokenRedeemSy = address(outputToken); // Valid SY output
        address tokenOut = address(inputToken); // Final destination token (via swap)
        address extRouter = makeAddr("odosRouter");

        bytes memory data = _createRedeemData(
            market, // yieldSource is market, not YT
            redeemAmount,
            tokenOut,
            tokenRedeemSy,
            minTokenOut,
            SwapType.ODOS,
            extRouter,
            false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);
        assertEq(executions[3].target, address(pendleRouter));
    }

    function test_Build_RedeemPyToToken_WithPrevHookAmount() public {
        bytes memory data = _createRedeemData(
            market, // yieldSource is market, not YT
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            true
        );

        prevHook.setOutAmount(5000, account);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);
    }

    function test_Build_RedeemPyToToken_RevertIf_InvalidYT() public {
        // Create a different market with different YT
        MockYieldToken otherYT = new MockYieldToken("Other YT", "OYT", 18);
        otherYT.setSY(address(mockSY));
        otherYT.setPT(address(ptToken));
        address otherMarket = address(new MockPendleMarket(address(syToken), address(ptToken), address(otherYT)));

        // yieldSource (otherMarket) has different YT than what's in txData (ytToken)
        bytes memory data = _createRedeemDataWithYieldSource(
            otherMarket, // market with different YT
            address(ytToken), // YT in txData doesn't match market's YT
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        vm.expectRevert(PendleUnifiedHook.YT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_RevertIf_InvalidReceiver() public {
        bytes memory data = _createRedeemDataWithReceiver(
            address(0x456), // wrong receiver
            market, // yieldSource is market
            address(ytToken),
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        vm.expectRevert(PendleUnifiedHook.RECEIVER_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_RevertIf_ZeroMinTokenOut() public {
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(outputToken),
            address(outputToken),
            0, // Invalid minTokenOut
            SwapType.NONE,
            address(0),
            false
        );

        vm.expectRevert(PendleUnifiedHook.MIN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_RevertIf_ZeroAmount() public {
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            0, // Invalid amount
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        vm.expectRevert(PendleUnifiedHook.AMOUNT_IN_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_RevertIf_TokenOutNotListed_DirectRedemption() public {
        // Direct redemption where tokenOut is NOT in SY's valid outputs
        MockERC20 invalidToken = new MockERC20("Invalid", "INV", 18);

        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(invalidToken), // Not in SY's tokensOut
            address(invalidToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        vm.expectRevert(PendleUnifiedHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_RevertIf_TokenRedeemSyNotValid_SwapRouting() public {
        // CORE FIX TEST: Swap routing where tokenRedeemSy is NOT valid
        MockERC20 invalidIntermediateToken = new MockERC20("Invalid Intermediate", "INVINT", 18);
        address extRouter = makeAddr("odosRouter");

        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(inputToken), // Final output
            address(invalidIntermediateToken), // NOT in SY's tokensOut - should fail
            minTokenOut,
            SwapType.ODOS,
            extRouter,
            false
        );

        vm.expectRevert(PendleUnifiedHook.TOKEN_REDEEM_SY_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_RevertIf_NoExtRouter_SwapRouting() public {
        // Swap routing without external router
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(inputToken),
            address(outputToken), // Valid tokenRedeemSy
            minTokenOut,
            SwapType.ODOS,
            address(0), // Missing external router
            false
        );

        vm.expectRevert(PendleUnifiedHook.INVALID_EXT_ROUTER.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                            INVALID SELECTOR TEST
    //////////////////////////////////////////////////////////////*/

    function test_Build_RevertIf_InvalidSelector() public {
        bytes memory txData = abi.encodePacked(bytes4(0xdeadbeef), bytes(abi.encode(receiver)));
        bytes memory data = abi.encodePacked(bytes32(0), market, bytes1(uint8(0)), uint256(0), txData);

        vm.expectRevert(PendleUnifiedHook.INVALID_SELECTOR.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        LIMIT ORDER VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SwapExactTokenForPt_WithNormalFills() public view {
        bytes memory data = _createSwapTokenForPtDataWithLimitOrders(
            receiver, market, minPtOut, inputAmount, true, false, false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_Build_SwapExactTokenForPt_WithFlashFills() public view {
        bytes memory data = _createSwapTokenForPtDataWithLimitOrders(
            receiver, market, minPtOut, inputAmount, false, true, false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_OrderExpired() public {
        bytes memory data = _createSwapTokenForPtDataWithExpiredOrder(
            receiver, market, minPtOut, inputAmount, false
        );

        vm.expectRevert(PendleUnifiedHook.ORDER_EXPIRED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_OrderMakerInvalid() public {
        bytes memory data = _createSwapTokenForPtDataWithInvalidOrderMaker(
            receiver, market, minPtOut, inputAmount, false
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_OrderReceiverInvalid() public {
        bytes memory data = _createSwapTokenForPtDataWithInvalidOrderReceiver(
            receiver, market, minPtOut, inputAmount, false
        );

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_RevertIf_MakingAmountZero() public {
        bytes memory data = _createSwapTokenForPtDataWithZeroMakingAmount(
            receiver, market, minPtOut, inputAmount, false
        );

        vm.expectRevert(PendleUnifiedHook.MAKING_AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactPtForToken_WithNormalFills() public view {
        bytes memory data = _createSwapPtForTokenDataWithLimitOrders(
            receiver, market, exactPtIn, minTokenOut, true, false, false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_Build_SwapExactPtForToken_WithFlashFills() public view {
        bytes memory data = _createSwapPtForTokenDataWithLimitOrders(
            receiver, market, exactPtIn, minTokenOut, false, true, false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                        SY VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_RedeemPyToToken_RevertIf_SYNotValid() public {
        // Create YT with zero SY address
        MockYieldToken badYT = new MockYieldToken("Bad YT", "BYT", 18);
        badYT.setSY(address(0));
        badYT.setPT(address(ptToken));

        // Create market with SY = address(0) (via readTokens returning zero SY)
        address badMarket = address(new MockPendleMarket(address(0), address(ptToken), address(badYT)));

        bytes memory data = _createRedeemDataWithYieldSource(
            badMarket, // market with SY = address(0)
            address(badYT),
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        vm.expectRevert(PendleUnifiedHook.SY_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                        VALUE COMPUTATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Build_SwapExactTokenForPt_WithNativeETH_ExplicitValue() public view {
        // Test case: usePrevHookAmount=false, value > 0, tokenIn = address(0)
        // This should use the explicit value from hook data
        uint256 explicitValue = 2 ether;
        bytes memory data = _createSwapTokenForPtDataWithNativeAndValue(
            receiver, market, minPtOut, inputAmount, explicitValue, false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        // The execution value should be the explicit value
        assertEq(executions[1].value, explicitValue);
    }

    /*//////////////////////////////////////////////////////////////
                        DECODE USE PREV HOOK AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Inspect_SwapExactTokenForPt() public view {
        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, false);
        bytes memory packed = hook.inspect(data);
        assertGt(packed.length, 0);
    }

    function test_Inspect_SwapExactPtForToken() public view {
        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, false);
        bytes memory packed = hook.inspect(data);
        assertGt(packed.length, 0);
    }

    function test_Inspect_RedeemPyToToken() public view {
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );
        bytes memory packed = hook.inspect(data);
        assertGt(packed.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        PRE/POST EXECUTE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PreExecute_SwapTokenForPt() public {
        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, false);

        ptToken.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);
        assertEq(hook.getOutAmount(address(this)), 500);
    }

    function test_PostExecute_SwapTokenForPt() public {
        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, false);

        ptToken.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);

        ptToken.mint(receiver, 300);
        hook.postExecute(address(0), receiver, data);
        assertEq(hook.getOutAmount(address(this)), 300);
    }

    function test_PreExecute_RedeemPyToToken() public {
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        outputToken.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);
        assertEq(hook.getOutAmount(address(this)), 500);
    }

    function test_PostExecute_RedeemPyToToken() public {
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(outputToken),
            address(outputToken),
            minTokenOut,
            SwapType.NONE,
            address(0),
            false
        );

        outputToken.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);

        outputToken.mint(receiver, 300);
        hook.postExecute(address(0), receiver, data);
        assertEq(hook.getOutAmount(address(this)), 300);
    }

    function test_GetBalance_NativeToken() public {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(0), // Native token
            minTokenOut: minTokenOut,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
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

        bytes memory data = abi.encodePacked(bytes32(0), market, bytes1(uint8(0)), uint256(0), txData);

        vm.deal(receiver, 5 ether);
        hook.preExecute(address(0), receiver, data);
        assertEq(hook.getOutAmount(address(this)), 5 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createSwapTokenForPtData(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        return _createSwapTokenForPtDataWithApprox(receiver_, market_, minPtOut_, inputAmount_, guessPtOut, usePrevHookAmount_);
    }

    function _createSwapTokenForPtDataWithApprox(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        ApproxParams memory guessPtOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createSwapTokenForPtDataFull(market_, receiver_, market_, minPtOut_, inputAmount_, guessPtOut_, usePrevHookAmount_);
    }

    function _createSwapTokenForPtDataWithYieldSource(
        address yieldSource_,
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });
        return _createSwapTokenForPtDataFull(yieldSource_, receiver_, market_, minPtOut_, inputAmount_, guessPtOut, usePrevHookAmount_);
    }

    function _createSwapTokenForPtDataFull(
        address yieldSource_,
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        ApproxParams memory guessPtOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount_,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut_, input, limit
        );

        return abi.encodePacked(bytes32(0), yieldSource_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapTokenForPtDataWithNative(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal pure returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(0), // Native ETH
            netTokenIn: inputAmount_,
            tokenMintSy: address(0),
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
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
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapPtForTokenData(
        address receiver_,
        address market_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createSwapPtForTokenDataWithYieldSource(market_, receiver_, market_, exactPtIn_, minTokenOut_, usePrevHookAmount_);
    }

    function _createSwapPtForTokenDataWithYieldSource(
        address yieldSource_,
        address receiver_,
        address market_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: minTokenOut_,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector, receiver_, market_, exactPtIn_, output, limit
        );

        return abi.encodePacked(bytes32(0), yieldSource_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createRedeemData(
        address market_,
        uint256 amount_,
        address tokenOut_,
        address tokenRedeemSy_,
        uint256 minTokenOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        // Get YT from market for txData
        (,, address yt_) = MockPendleMarket(market_).readTokens();
        return _createRedeemDataWithYieldSource(
            market_, yt_, amount_, tokenOut_, tokenRedeemSy_, minTokenOut_, swapType_, extRouter_, usePrevHookAmount_
        );
    }

    function _createRedeemDataWithYieldSource(
        address yieldSource_,
        address yt_,
        uint256 amount_,
        address tokenOut_,
        address tokenRedeemSy_,
        uint256 minTokenOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        return _createRedeemDataFull(
            yieldSource_, receiver, yt_, amount_, tokenOut_, tokenRedeemSy_, minTokenOut_, swapType_, extRouter_, usePrevHookAmount_
        );
    }

    function _createRedeemDataWithReceiver(
        address receiver_,
        address yieldSource_,
        address yt_,
        uint256 amount_,
        address tokenOut_,
        address tokenRedeemSy_,
        uint256 minTokenOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal pure returns (bytes memory) {
        return _createRedeemDataFull(
            yieldSource_, receiver_, yt_, amount_, tokenOut_, tokenRedeemSy_, minTokenOut_, swapType_, extRouter_, usePrevHookAmount_
        );
    }

    function _createRedeemDataFull(
        address yieldSource_,
        address receiver_,
        address yt_,
        uint256 amount_,
        address tokenOut_,
        address tokenRedeemSy_,
        uint256 minTokenOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal pure returns (bytes memory) {
        TokenOutput memory output = TokenOutput({
            tokenOut: tokenOut_,
            minTokenOut: minTokenOut_,
            tokenRedeemSy: tokenRedeemSy_,
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: swapType_,
                extRouter: extRouter_,
                extCalldata: "",
                needScale: false
            })
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.redeemPyToToken.selector, receiver_, yt_, amount_, output
        );

        return abi.encodePacked(bytes32(0), yieldSource_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    /*//////////////////////////////////////////////////////////////
                    LIMIT ORDER HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _createSwapTokenForPtDataWithLimitOrders(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool hasNormalFills_,
        bool hasFlashFills_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount_,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        LimitOrderData memory limit = _createLimitOrderData(hasNormalFills_, hasFlashFills_);

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapPtForTokenDataWithLimitOrders(
        address receiver_,
        address market_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        bool hasNormalFills_,
        bool hasFlashFills_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: minTokenOut_,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        LimitOrderData memory limit = _createLimitOrderData(hasNormalFills_, hasFlashFills_);

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactPtForToken.selector, receiver_, market_, exactPtIn_, output, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createLimitOrderData(bool hasNormalFills_, bool hasFlashFills_) internal view returns (LimitOrderData memory) {
        FillOrderParams[] memory normalFills;
        FillOrderParams[] memory flashFills;

        if (hasNormalFills_) {
            normalFills = new FillOrderParams[](1);
            normalFills[0] = _createValidFillOrderParams();
        } else {
            normalFills = new FillOrderParams[](0);
        }

        if (hasFlashFills_) {
            flashFills = new FillOrderParams[](1);
            flashFills[0] = _createValidFillOrderParams();
        } else {
            flashFills = new FillOrderParams[](0);
        }

        return LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: flashFills,
            optData: ""
        });
    }

    function _createValidFillOrderParams() internal view returns (FillOrderParams memory) {
        Order memory order = Order({
            salt: 12345,
            expiry: block.timestamp + 1 days,
            nonce: 1,
            orderType: OrderType.SY_FOR_PT,
            token: address(inputToken),
            YT: address(ytToken),
            maker: address(this),
            receiver: address(this),
            makingAmount: 1000,
            lnImpliedRate: 1e17,
            failSafeRate: 1e16,
            permit: ""
        });

        return FillOrderParams({
            order: order,
            signature: "",
            makingAmount: 1000
        });
    }

    function _createSwapTokenForPtDataWithExpiredOrder(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount_,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        // Create expired order
        Order memory order = Order({
            salt: 12345,
            expiry: block.timestamp - 1, // Expired
            nonce: 1,
            orderType: OrderType.SY_FOR_PT,
            token: address(inputToken),
            YT: address(ytToken),
            maker: address(this),
            receiver: address(this),
            makingAmount: 1000,
            lnImpliedRate: 1e17,
            failSafeRate: 1e16,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({
            order: order,
            signature: "",
            makingAmount: 1000
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapTokenForPtDataWithInvalidOrderMaker(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount_,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        // Create order with invalid maker
        Order memory order = Order({
            salt: 12345,
            expiry: block.timestamp + 1 days,
            nonce: 1,
            orderType: OrderType.SY_FOR_PT,
            token: address(inputToken),
            YT: address(ytToken),
            maker: address(0), // Invalid
            receiver: address(this),
            makingAmount: 1000,
            lnImpliedRate: 1e17,
            failSafeRate: 1e16,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({
            order: order,
            signature: "",
            makingAmount: 1000
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapTokenForPtDataWithInvalidOrderReceiver(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount_,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        // Create order with invalid receiver
        Order memory order = Order({
            salt: 12345,
            expiry: block.timestamp + 1 days,
            nonce: 1,
            orderType: OrderType.SY_FOR_PT,
            token: address(inputToken),
            YT: address(ytToken),
            maker: address(this),
            receiver: address(0), // Invalid
            makingAmount: 1000,
            lnImpliedRate: 1e17,
            failSafeRate: 1e16,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({
            order: order,
            signature: "",
            makingAmount: 1000
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapTokenForPtDataWithZeroMakingAmount(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(inputToken),
            netTokenIn: inputAmount_,
            tokenMintSy: address(inputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e17
        });

        // Create order with zero makingAmount
        Order memory order = Order({
            salt: 12345,
            expiry: block.timestamp + 1 days,
            nonce: 1,
            orderType: OrderType.SY_FOR_PT,
            token: address(inputToken),
            YT: address(ytToken),
            maker: address(this),
            receiver: address(this),
            makingAmount: 1000,
            lnImpliedRate: 1e17,
            failSafeRate: 1e16,
            permit: ""
        });

        FillOrderParams[] memory normalFills = new FillOrderParams[](1);
        normalFills[0] = FillOrderParams({
            order: order,
            signature: "",
            makingAmount: 0 // Invalid
        });

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: normalFills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
    }

    function _createSwapTokenForPtDataWithNativeAndValue(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        uint256 explicitValue_,
        bool usePrevHookAmount_
    ) internal pure returns (bytes memory) {
        TokenInput memory input = TokenInput({
            tokenIn: address(0), // Native ETH
            netTokenIn: inputAmount_,
            tokenMintSy: address(0),
            pendleSwap: address(0),
            swapData: SwapData({
                swapType: SwapType.NONE,
                extRouter: address(0),
                extCalldata: "",
                needScale: false
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
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
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit
        );

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), explicitValue_, txData);
    }
}
