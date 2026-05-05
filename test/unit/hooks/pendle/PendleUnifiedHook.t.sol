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
import { HookDataUpdater } from "../../../../src/libraries/HookDataUpdater.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

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

    function test_Build_SwapExactTokenForPt_RevertIf_InvalidMaxIteration() public {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 257, // Invalid: > MAX_ITERATIONS (256)
            eps: 1e17
        });

        bytes memory data = _createSwapTokenForPtDataWithApprox(receiver, market, minPtOut, inputAmount, guessPtOut, false);

        vm.expectRevert(PendleUnifiedHook.INVALID_MAX_ITERATION.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactTokenForPt_MaxIterationBoundary() public view {
        // maxIteration == 256 (MAX_ITERATIONS) should pass
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 256,
            eps: 1e17
        });

        bytes memory data = _createSwapTokenForPtDataWithApprox(receiver, market, minPtOut, inputAmount, guessPtOut, false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_Build_SwapExactTokenForPt_MaxEpsBoundary() public view {
        // eps == 1e18 (MAX_EPS) should pass
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 900,
            guessMax: 1100,
            guessOffchain: 1000,
            maxIteration: 10,
            eps: 1e18
        });

        bytes memory data = _createSwapTokenForPtDataWithApprox(receiver, market, minPtOut, inputAmount, guessPtOut, false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
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

    function test_Build_SwapExactPtForToken_WithSwapRouting() public view {
        // Valid swap routing with a real extRouter
        address extRouter = address(0x1234567890AbcdEF1234567890aBcdef12345678);
        bytes memory data = _createSwapPtForTokenDataWithSwapRouting(
            receiver, market, exactPtIn, minTokenOut, SwapType.ODOS, extRouter, false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(pendleRouter));
    }

    function test_Build_SwapExactPtForToken_WithEthWethSwapType() public view {
        // ETH_WETH swap type can use extRouter = address(0)
        bytes memory data = _createSwapPtForTokenDataWithSwapRouting(
            receiver, market, exactPtIn, minTokenOut, SwapType.ETH_WETH, address(0), false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_Build_SwapExactPtForToken_RevertIf_NoExtRouter_SwapRouting() public {
        // Swap routing without external router should revert
        bytes memory data = _createSwapPtForTokenDataWithSwapRouting(
            receiver, market, exactPtIn, minTokenOut, SwapType.ODOS, address(0), false
        );

        vm.expectRevert(PendleUnifiedHook.INVALID_EXT_ROUTER.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SwapExactPtForToken_RevertIf_ExtRouterNativeToken() public {
        // NATIVE_TOKEN sentinel as extRouter should be rejected
        bytes memory data = _createSwapPtForTokenDataWithSwapRouting(
            receiver, market, exactPtIn, minTokenOut, SwapType.ODOS, 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, false
        );

        vm.expectRevert(PendleUnifiedHook.INVALID_EXT_ROUTER.selector);
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
        // 7 hook executions (approve(0) PT, approve PT, approve(0) YT, approve YT, redeemPyToToken, reset PT, reset
        // YT) + 2 wrappers = 9
        assertEq(executions.length, 9);
        assertEq(executions[1].target, address(ptToken)); // approve(0) PT
        assertEq(executions[2].target, address(ptToken)); // approve PT
        assertEq(executions[3].target, address(ytToken)); // approve(0) YT
        assertEq(executions[4].target, address(ytToken)); // approve YT
        assertEq(executions[5].target, address(pendleRouter)); // redeemPyToToken
        assertEq(executions[6].target, address(ptToken)); // reset PT approval
        assertEq(executions[7].target, address(ytToken)); // reset YT approval
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
        assertEq(executions.length, 9);
        assertEq(executions[5].target, address(pendleRouter));
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
        assertEq(executions.length, 9);
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

    function test_Build_RedeemPyToToken_RevertIf_ExtRouterNativeToken() public {
        // NATIVE_TOKEN sentinel as extRouter should be rejected
        bytes memory data = _createRedeemData(
            market,
            redeemAmount,
            address(inputToken),
            address(outputToken), // Valid tokenRedeemSy
            minTokenOut,
            SwapType.ODOS,
            0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE, // NATIVE_TOKEN sentinel
            false
        );

        vm.expectRevert(PendleUnifiedHook.INVALID_EXT_ROUTER.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RedeemPyToToken_VerifyApprovePattern() public view {
        // Verify the full approve-to-zero pattern: approve(0)->approve(amt)->approve(0)->approve(amt)->redeem->approve(0)->approve(0)
        bytes memory data = _createRedeemData(
            market, redeemAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), false
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9); // 7 hook executions + 2 wrappers

        // executions[0] = preExecute (BaseHook wrapper)
        // executions[1] = approve(0) PT
        assertEq(executions[1].target, address(ptToken));
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));

        // executions[2] = approve(redeemAmount) PT
        assertEq(executions[2].target, address(ptToken));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), redeemAmount)));

        // executions[3] = approve(0) YT
        assertEq(executions[3].target, address(ytToken));
        assertEq(executions[3].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));

        // executions[4] = approve(redeemAmount) YT
        assertEq(executions[4].target, address(ytToken));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), redeemAmount)));

        // executions[5] = redeemPyToToken
        assertEq(executions[5].target, address(pendleRouter));

        // executions[6] = reset approve(0) PT
        assertEq(executions[6].target, address(ptToken));
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));

        // executions[7] = reset approve(0) YT
        assertEq(executions[7].target, address(ytToken));
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (address(pendleRouter), 0)));

        // executions[8] = postExecute (BaseHook wrapper)
    }

    function test_Build_RedeemPyToToken_WithEthWethSwapType() public view {
        // ETH_WETH swap type legitimately uses extRouter = address(0)
        // because it performs internal WETH wrap/unwrap operations
        bytes memory data = _createRedeemData(
            market, // yieldSource is market
            redeemAmount,
            address(0), // tokenOut = native ETH
            address(outputToken), // tokenRedeemSy = WETH (valid SY output)
            minTokenOut,
            SwapType.ETH_WETH,
            address(0), // No external router needed for ETH_WETH
            false
        );

        // Should NOT revert - ETH_WETH is allowed with extRouter = address(0)
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 9); // 7 hook executions + 2 wrappers
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

    function test_Build_SwapExactTokenForPt_RevertIf_TooManyFills() public {
        // Create 65 fill orders (exceeds MAX_FILLS = 64)
        FillOrderParams[] memory fills = new FillOrderParams[](65);
        for (uint256 i; i < 65; ++i) {
            fills[i] = FillOrderParams({
                order: Order({
                    salt: uint256(keccak256(abi.encodePacked(i))),
                    expiry: block.timestamp + 1 hours,
                    nonce: 0,
                    orderType: OrderType.SY_FOR_PT,
                    token: address(ptToken),
                    YT: address(ytToken),
                    maker: address(0x123),
                    receiver: address(0x456),
                    makingAmount: 100,
                    lnImpliedRate: 0,
                    failSafeRate: 0,
                    permit: ""
                }),
                signature: "",
                makingAmount: 100
            });
        }

        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0x789),
            epsSkipMarket: 0,
            normalFills: fills,
            flashFills: new FillOrderParams[](0),
            optData: ""
        });

        bytes memory data = _createSwapTokenForPtDataWithLimitOrderData(
            receiver, market, minPtOut, inputAmount, limit, false
        );

        vm.expectRevert(PendleUnifiedHook.TOO_MANY_FILLS.selector);
        hook.build(address(prevHook), account, data);
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
                    MIN-OUT SCALING TESTS (usePrevHookAmount)
    //////////////////////////////////////////////////////////////*/

    /// @dev Path 1: redeemPyToToken - minTokenOut scales up when prevHookAmount > original
    function test_MinOutScaling_Redeem_Increase() public {
        uint256 originalAmount = redeemAmount; // 1500
        uint256 prevHookAmount = 3000; // 2x increase

        bytes memory data = _createRedeemData(
            market, originalAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), true
        );

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Decode redeemPyToToken call (index 5: after preExecute, approve(0)PT, approvePT, approve(0)YT, approveYT)
        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, originalAmount, minTokenOut);
        assertEq(output.minTokenOut, expectedMinOut, "Redeem: minTokenOut not scaled on increase");
        assertEq(expectedMinOut, 2000, "Expected 2x scaling");
    }

    /// @dev Path 1: redeemPyToToken - minTokenOut scales down when prevHookAmount < original
    function test_MinOutScaling_Redeem_Decrease() public {
        uint256 originalAmount = redeemAmount; // 1500
        uint256 prevHookAmount = 750; // 50% decrease

        bytes memory data = _createRedeemData(
            market, originalAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), true
        );

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, originalAmount, minTokenOut);
        assertEq(output.minTokenOut, expectedMinOut, "Redeem: minTokenOut not scaled on decrease");
        assertEq(expectedMinOut, 500, "Expected 50% scaling");
    }

    /// @dev Path 1: redeemPyToToken - minTokenOut unchanged when prevHookAmount == original
    function test_MinOutScaling_Redeem_Equal() public {
        uint256 originalAmount = redeemAmount; // 1500

        bytes memory data = _createRedeemData(
            market, originalAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), true
        );

        prevHook.setOutAmount(originalAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        assertEq(output.minTokenOut, minTokenOut, "Redeem: minTokenOut should be unchanged when equal");
    }

    /// @dev Path 2: swapExactTokenForPt - minPtOut scales up when prevHookAmount > original
    function test_MinOutScaling_SwapTokenForPt_Increase() public {
        uint256 originalAmount = inputAmount; // 1500
        uint256 prevHookAmount = 3000; // 2x increase

        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, originalAmount, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Decode swapExactTokenForPt call (index 1: after preExecute)
        bytes memory args = _removeSelector(executions[1].callData);
        (,, uint256 actualMinPtOut,, TokenInput memory actualInput,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        uint256 expectedMinPtOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, originalAmount, minPtOut);
        assertEq(actualMinPtOut, expectedMinPtOut, "SwapTokenForPt: minPtOut not scaled on increase");
        assertEq(expectedMinPtOut, 2000, "Expected 2x scaling");
        assertEq(actualInput.netTokenIn, prevHookAmount, "SwapTokenForPt: netTokenIn should be prevHookAmount");
    }

    /// @dev Path 2: swapExactTokenForPt - minPtOut scales down when prevHookAmount < original
    function test_MinOutScaling_SwapTokenForPt_Decrease() public {
        uint256 originalAmount = inputAmount; // 1500
        uint256 prevHookAmount = 750; // 50% decrease

        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, originalAmount, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,, uint256 actualMinPtOut,, TokenInput memory actualInput,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        uint256 expectedMinPtOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, originalAmount, minPtOut);
        assertEq(actualMinPtOut, expectedMinPtOut, "SwapTokenForPt: minPtOut not scaled on decrease");
        assertEq(expectedMinPtOut, 500, "Expected 50% scaling");
        assertEq(actualInput.netTokenIn, prevHookAmount, "SwapTokenForPt: netTokenIn should be prevHookAmount");
    }

    /// @dev Path 2: swapExactTokenForPt - minPtOut unchanged when prevHookAmount == original
    function test_MinOutScaling_SwapTokenForPt_Equal() public {
        uint256 originalAmount = inputAmount; // 1500

        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, originalAmount, true);

        prevHook.setOutAmount(originalAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,, uint256 actualMinPtOut,, TokenInput memory actualInput,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertEq(actualMinPtOut, minPtOut, "SwapTokenForPt: minPtOut should be unchanged when equal");
        assertEq(actualInput.netTokenIn, originalAmount, "SwapTokenForPt: netTokenIn should be unchanged");
    }

    /// @dev Path 3: swapExactPtForToken - minTokenOut scales up when prevHookAmount > original
    function test_MinOutScaling_SwapPtForToken_Increase() public {
        uint256 originalAmount = exactPtIn; // 2000
        uint256 prevHookAmount = 4000; // 2x increase

        bytes memory data = _createSwapPtForTokenData(receiver, market, originalAmount, minTokenOut, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        // Decode swapExactPtForToken call (index 1: after preExecute)
        bytes memory args = _removeSelector(executions[1].callData);
        (,,, TokenOutput memory actualOutput,) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, originalAmount, minTokenOut);
        assertEq(actualOutput.minTokenOut, expectedMinOut, "SwapPtForToken: minTokenOut not scaled on increase");
        assertEq(expectedMinOut, 2000, "Expected 2x scaling");
    }

    /// @dev Path 3: swapExactPtForToken - minTokenOut scales down when prevHookAmount < original
    function test_MinOutScaling_SwapPtForToken_Decrease() public {
        uint256 originalAmount = exactPtIn; // 2000
        uint256 prevHookAmount = 1000; // 50% decrease

        bytes memory data = _createSwapPtForTokenData(receiver, market, originalAmount, minTokenOut, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,,, TokenOutput memory actualOutput,) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, originalAmount, minTokenOut);
        assertEq(actualOutput.minTokenOut, expectedMinOut, "SwapPtForToken: minTokenOut not scaled on decrease");
        assertEq(expectedMinOut, 500, "Expected 50% scaling");
    }

    /// @dev Path 3: swapExactPtForToken - minTokenOut unchanged when prevHookAmount == original
    function test_MinOutScaling_SwapPtForToken_Equal() public {
        uint256 originalAmount = exactPtIn; // 2000

        bytes memory data = _createSwapPtForTokenData(receiver, market, originalAmount, minTokenOut, true);

        prevHook.setOutAmount(originalAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,,, TokenOutput memory actualOutput,) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        assertEq(actualOutput.minTokenOut, minTokenOut, "SwapPtForToken: minTokenOut should be unchanged when equal");
    }

    /// @dev Defense-in-depth: verify near-zero scaling still produces non-zero min values
    /// The HookDataUpdater formula with PRECISION=1e5 preserves at least 1 when all inputs > 0
    function test_MinOutScaling_Redeem_NearZero() public {
        uint256 originalAmount = redeemAmount; // 1500
        uint256 prevHookAmount = 1; // Extreme decrease

        bytes memory data = _createRedeemData(
            market, originalAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), true
        );

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        // Even with extreme scaling down, the result should still be > 0
        assertGt(output.minTokenOut, 0, "Redeem: near-zero scaling should still produce non-zero min");
    }

    function test_MinOutScaling_SwapTokenForPt_NearZero() public {
        uint256 originalAmount = inputAmount; // 1500
        uint256 prevHookAmount = 1; // Extreme decrease

        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, originalAmount, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,, uint256 actualMinPtOut,,,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertGt(actualMinPtOut, 0, "SwapTokenForPt: near-zero scaling should still produce non-zero min");
    }

    function test_MinOutScaling_SwapPtForToken_NearZero() public {
        uint256 originalAmount = exactPtIn; // 2000
        uint256 prevHookAmount = 1; // Extreme decrease

        bytes memory data = _createSwapPtForTokenData(receiver, market, originalAmount, minTokenOut, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,,, TokenOutput memory actualOutput,) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        assertGt(actualOutput.minTokenOut, 0, "SwapPtForToken: near-zero scaling should still produce non-zero min");
    }

    /// @dev Fuzz: redeemPyToToken scaling matches HookDataUpdater formula for any prevHookAmount
    function testFuzz_MinOutScaling_Redeem(uint256 prevHookAmount) public {
        prevHookAmount = bound(prevHookAmount, 1, type(uint128).max);

        bytes memory data = _createRedeemData(
            market, redeemAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), true
        );

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[5].callData);
        (,,, TokenOutput memory output) = abi.decode(args, (address, address, uint256, TokenOutput));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, redeemAmount, minTokenOut);
        assertEq(output.minTokenOut, expectedMinOut, "Fuzz Redeem: minTokenOut scaling mismatch");
    }

    /// @dev Fuzz: swapExactTokenForPt scaling matches HookDataUpdater formula for any prevHookAmount
    function testFuzz_MinOutScaling_SwapTokenForPt(uint256 prevHookAmount) public {
        prevHookAmount = bound(prevHookAmount, 1, type(uint128).max);

        bytes memory data = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,, uint256 actualMinPtOut,,,) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        uint256 expectedMinPtOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, inputAmount, minPtOut);
        assertEq(actualMinPtOut, expectedMinPtOut, "Fuzz SwapTokenForPt: minPtOut scaling mismatch");
    }

    /// @dev Fuzz: swapExactPtForToken scaling matches HookDataUpdater formula for any prevHookAmount
    function testFuzz_MinOutScaling_SwapPtForToken(uint256 prevHookAmount) public {
        prevHookAmount = bound(prevHookAmount, 1, type(uint128).max);

        bytes memory data = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, true);

        prevHook.setOutAmount(prevHookAmount, account);
        Execution[] memory executions = hook.build(address(prevHook), account, data);

        bytes memory args = _removeSelector(executions[1].callData);
        (,,, TokenOutput memory actualOutput,) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        uint256 expectedMinOut = HookDataUpdater.getUpdatedOutputAmount(prevHookAmount, exactPtIn, minTokenOut);
        assertEq(actualOutput.minTokenOut, expectedMinOut, "Fuzz SwapPtForToken: minTokenOut scaling mismatch");
    }

    /// @dev Verifies that min-out values are NOT modified when usePrevHookAmount is false
    function test_MinOutNotScaled_WhenNotUsingPrevHookAmount() public view {
        // Path 1: Redeem
        bytes memory redeemData = _createRedeemData(
            market, redeemAmount, address(outputToken), address(outputToken), minTokenOut, SwapType.NONE, address(0), false
        );
        Execution[] memory redeemExecs = hook.build(address(prevHook), account, redeemData);
        bytes memory redeemArgs = _removeSelector(redeemExecs[5].callData);
        (,,, TokenOutput memory redeemOutput) = abi.decode(redeemArgs, (address, address, uint256, TokenOutput));
        assertEq(redeemOutput.minTokenOut, minTokenOut, "Redeem: minTokenOut should not scale without usePrevHookAmount");

        // Path 2: SwapTokenForPt
        bytes memory swapInData = _createSwapTokenForPtData(receiver, market, minPtOut, inputAmount, false);
        Execution[] memory swapInExecs = hook.build(address(prevHook), account, swapInData);
        bytes memory swapInArgs = _removeSelector(swapInExecs[1].callData);
        (,, uint256 actualMinPtOut,,,) =
            abi.decode(swapInArgs, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
        assertEq(actualMinPtOut, minPtOut, "SwapTokenForPt: minPtOut should not scale without usePrevHookAmount");

        // Path 3: SwapPtForToken
        bytes memory swapOutData = _createSwapPtForTokenData(receiver, market, exactPtIn, minTokenOut, false);
        Execution[] memory swapOutExecs = hook.build(address(prevHook), account, swapOutData);
        bytes memory swapOutArgs = _removeSelector(swapOutExecs[1].callData);
        (,,, TokenOutput memory swapOutOutput,) =
            abi.decode(swapOutArgs, (address, address, uint256, TokenOutput, LimitOrderData));
        assertEq(swapOutOutput.minTokenOut, minTokenOut, "SwapPtForToken: minTokenOut should not scale without usePrevHookAmount");
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

    function _createSwapPtForTokenDataWithSwapRouting(
        address receiver_,
        address market_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        SwapType swapType_,
        address extRouter_,
        bool usePrevHookAmount_
    ) internal view returns (bytes memory) {
        TokenOutput memory output = TokenOutput({
            tokenOut: address(outputToken),
            minTokenOut: minTokenOut_,
            tokenRedeemSy: address(outputToken),
            pendleSwap: address(this),
            swapData: SwapData({
                swapType: swapType_,
                extRouter: extRouter_,
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

        return abi.encodePacked(bytes32(0), market_, bytes1(usePrevHookAmount_ ? uint8(1) : uint8(0)), uint256(0), txData);
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

    function _createSwapTokenForPtDataWithLimitOrderData(
        address receiver_,
        address market_,
        uint256 minPtOut_,
        uint256 inputAmount_,
        LimitOrderData memory limit_,
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

        bytes memory txData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, receiver_, market_, minPtOut_, guessPtOut, input, limit_
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

    /// @dev Removes the first 4 bytes (selector) from calldata for abi.decode
    function _removeSelector(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data[i + 4];
        }
    }
}
