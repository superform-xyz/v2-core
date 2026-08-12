// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "forge-std/Test.sol";

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IPYieldToken } from "../../../src/vendor/pendle/IPYieldToken.sol";
import { IStandardizedYield } from "../../../src/vendor/pendle/IStandardizedYield.sol";
import {
    LimitOrderData,
    FillOrderParams,
    Order,
    OrderType,
    TokenInput,
    TokenOutput,
    ApproxParams,
    SwapType
} from "../../../src/vendor/pendle/IPendleRouterV4.sol";

import { PendlePTHook } from "../../../src/hooks/swappers/pendle/PendlePTHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { IPendlePTHookResult } from "../../../src/interfaces/IPendlePTHookResult.sol";
import { RecordPurchasePendlePTHook } from "../../../src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol";
import { RecordRedemptionPendlePTHook } from "../../../src/hooks/oracles/pendle/RecordRedemptionPendlePTHook.sol";
import { MockPendlePTAmortizedOracle } from "../../mocks/MockPendlePTAmortizedOracle.sol";

/// @title PendlePTHookE2E
/// @notice End-to-end fork tests for PendlePTHook using real mainnet Pendle Router V4 and DETH market
/// @dev Tests build(), inspect(), and full execution against real on-chain state
contract PendlePTHookE2E is Test {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Pendle Router V4 (same address on all chains)
    address constant PENDLE_ROUTER = 0x888888888889758F76e7103c6CbF23ABbF58F946;

    /// @dev DETH Pendle Market on Ethereum mainnet
    address constant DETH_MARKET = 0x937c7868824ae53dB3b7C634de209FB7a74E362c;

    /// @dev WETH on Ethereum mainnet
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    PendlePTHook public hook;
    MockHook public prevHook;

    address public sy;
    address public pt;
    address public yt;
    address public user;

    function setUp() public {
        // Pin to block before DETH market expiry (Jan 29, 2026) to ensure consistent Pendle state
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 24_300_000);

        hook = new PendlePTHook(PENDLE_ROUTER);
        prevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(0));

        (sy, pt, yt) = IPendleMarket(DETH_MARKET).readTokens();
        user = makeAddr("user");
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD TESTS — BUY PT (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build() produces correct 6-execution structure for buy PT with real market
    function test_Build_BuyPt_RealMarket() public view {
        address tokenIn = _firstErc20TokenIn();

        uint256 inputAmount = 1e18;
        bytes memory data = _buildBuyPtData(DETH_MARKET, tokenIn, pt, inputAmount, 1, false);

        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // 4 hook executions (approve(0), approve, call, approve(0)) + 2 wrappers = 6
        assertEq(executions.length, 6, "BuyPt should produce 6 executions");

        // Verify approve pattern targets
        assertEq(executions[1].target, tokenIn, "exec[1] should target tokenIn (approve(0))");
        assertEq(executions[2].target, tokenIn, "exec[2] should target tokenIn (approve)");
        assertEq(executions[3].target, PENDLE_ROUTER, "exec[3] should target router");
        assertEq(executions[4].target, tokenIn, "exec[4] should target tokenIn (cleanup)");

        // Verify approve amounts
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, inputAmount)));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
    }

    /// @notice Verify build() correctly encodes the swapExactTokenForPt calldata with real market
    function test_Build_BuyPt_CallDataEncoding_RealMarket() public view {
        address tokenIn = _firstErc20TokenIn();

        uint256 inputAmount = 2.5e18;
        uint256 minPtOut = 1e17;
        bytes memory data = _buildBuyPtData(DETH_MARKET, tokenIn, pt, inputAmount, minPtOut, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Decode the swapExactTokenForPt calldata (exec[3])
        bytes memory args = _removeSelector(executions[3].callData);
        (address receiver_, address market_, uint256 minPtOut_, ApproxParams memory guess_, TokenInput memory input_, LimitOrderData memory limit_) =
            abi.decode(args, (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));

        assertEq(receiver_, user, "Receiver should be user");
        assertEq(market_, DETH_MARKET, "Market should match");
        assertEq(minPtOut_, minPtOut, "minPtOut should match");
        assertEq(input_.tokenIn, tokenIn, "tokenIn should match");
        assertEq(input_.netTokenIn, inputAmount, "netTokenIn should match");
        assertGt(guess_.maxIteration, 0, "maxIteration should be set");

        // Internally-constructed fields: no auxiliary swapping, no limit orders
        assertEq(input_.tokenMintSy, tokenIn, "tokenMintSy should be the header inputToken");
        assertEq(input_.pendleSwap, address(0), "pendleSwap should be zero");
        assertEq(uint256(input_.swapData.swapType), uint256(SwapType.NONE), "swapType should be NONE");
        assertEq(limit_.limitRouter, address(0), "limit order should be empty");
        assertEq(limit_.normalFills.length, 0, "normalFills should be empty");
        assertEq(limit_.flashFills.length, 0, "flashFills should be empty");
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD TESTS — SELL PT (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build() produces correct 6-execution structure for sell PT with real market
    function test_Build_SellPt_RealMarket() public view {
        // Skip if market is expired (sell requires active liquidity)
        if (IPYieldToken(yt).isExpired()) return;

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];

        uint256 ptAmount = 1e18;
        bytes memory data = _buildSellPtData(DETH_MARKET, pt, tokenOut, ptAmount, 1, false);

        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // 4 hook executions (approve(0), approve, call, approve(0)) + 2 wrappers = 6
        assertEq(executions.length, 6, "SellPt should produce 6 executions");

        assertEq(executions[1].target, pt, "exec[1] should target PT (approve(0))");
        assertEq(executions[2].target, pt, "exec[2] should target PT (approve)");
        assertEq(executions[3].target, PENDLE_ROUTER, "exec[3] should target router");
        assertEq(executions[4].target, pt, "exec[4] should target PT (cleanup)");
    }

    /// @notice Verify build() correctly encodes the swapExactPtForToken calldata with real market
    function test_Build_SellPt_CallDataEncoding_RealMarket() public view {
        if (IPYieldToken(yt).isExpired()) return;

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        uint256 ptAmount = 2.5e18;
        uint256 minTokenOut = 1e17;
        bytes memory data = _buildSellPtData(DETH_MARKET, pt, tokenOut, ptAmount, minTokenOut, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Decode the swapExactPtForToken calldata (exec[3])
        bytes memory args = _removeSelector(executions[3].callData);
        (address receiver_, address market_, uint256 exactPtIn_, TokenOutput memory output_, LimitOrderData memory limit_) =
            abi.decode(args, (address, address, uint256, TokenOutput, LimitOrderData));

        assertEq(receiver_, user, "Receiver should be user");
        assertEq(market_, DETH_MARKET, "Market should match");
        assertEq(exactPtIn_, ptAmount, "exactPtIn should match");
        assertEq(output_.tokenOut, tokenOut, "tokenOut should match");
        assertEq(output_.minTokenOut, minTokenOut, "minTokenOut should match");

        // Internally-constructed fields: no auxiliary swapping, no limit orders
        assertEq(output_.tokenRedeemSy, tokenOut, "tokenRedeemSy should be the header outputToken");
        assertEq(output_.pendleSwap, address(0), "pendleSwap should be zero");
        assertEq(uint256(output_.swapData.swapType), uint256(SwapType.NONE), "swapType should be NONE");
        assertEq(limit_.limitRouter, address(0), "limit order should be empty");
    }

    /*//////////////////////////////////////////////////////////////
                    BUILD TESTS — REDEEM PT (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build() produces correct 9-execution structure for redeem with real market
    function test_Build_RedeemPt_RealMarket() public {
        // Warp past expiry to trigger redeem path
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];

        uint256 redeemAmount = 1e18;
        bytes memory data = _buildRedeemData(DETH_MARKET, pt, tokenOut, redeemAmount, 1, false);

        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // 7 hook executions + 2 wrappers = 9
        assertEq(executions.length, 9, "Redeem should produce 9 executions");

        assertEq(executions[1].target, pt, "exec[1] should target PT (approve(0))");
        assertEq(executions[2].target, pt, "exec[2] should target PT (approve)");
        assertEq(executions[3].target, yt, "exec[3] should target YT (approve(0))");
        assertEq(executions[4].target, yt, "exec[4] should target YT (approve)");
        assertEq(executions[5].target, PENDLE_ROUTER, "exec[5] should target router (redeem)");
        assertEq(executions[6].target, pt, "exec[6] should target PT (reset)");
        assertEq(executions[7].target, yt, "exec[7] should target YT (reset)");

        // Verify approve calldatas
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, redeemAmount)));
        assertEq(executions[3].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, redeemAmount)));
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
    }

    /// @notice Verify build() correctly encodes the redeemPyToToken calldata with real YT
    function test_Build_RedeemPt_CallDataEncoding_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        uint256 redeemAmount = 2.5e18;
        bytes memory data = _buildRedeemData(DETH_MARKET, pt, tokenOut, redeemAmount, 1e17, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Decode the redeemPyToToken calldata (exec[5])
        bytes memory args = _removeSelector(executions[5].callData);
        (address receiver_, address yt_, uint256 amount_, TokenOutput memory output_) =
            abi.decode(args, (address, address, uint256, TokenOutput));

        assertEq(receiver_, user, "Receiver should be user");
        assertEq(yt_, yt, "YT should match market's YT");
        assertEq(amount_, redeemAmount, "Amount should match");
        assertEq(output_.minTokenOut, 1e17, "minTokenOut should match");
        assertEq(output_.tokenOut, tokenOut, "tokenOut should match");
        assertEq(output_.tokenRedeemSy, tokenOut, "tokenRedeemSy should be the header outputToken");
        assertEq(output_.pendleSwap, address(0), "pendleSwap should be zero");
        assertEq(uint256(output_.swapData.swapType), uint256(SwapType.NONE), "swapType should be NONE");
    }

    /*//////////////////////////////////////////////////////////////
                        INSPECT TESTS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect() returns only the packed yieldSource for buy PT
    function test_Inspect_BuyPt_RealMarket() public view {
        address tokenIn = _firstErc20TokenIn();

        bytes memory data = _buildBuyPtData(DETH_MARKET, tokenIn, pt, 1e18, 1, false);
        bytes memory packed = hook.inspect(data);

        assertEq(packed.length, 20, "Inspect should return 20 bytes");
        assertEq(packed.toAddress(0), DETH_MARKET, "yieldSource should match market");
    }

    /// @notice Verify inspect() returns only the packed yieldSource for sell PT
    function test_Inspect_SellPt_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        bytes memory data = _buildSellPtData(DETH_MARKET, pt, tokenOut, 1e18, 1, false);
        bytes memory packed = hook.inspect(data);

        assertEq(packed.length, 20, "Inspect should return 20 bytes");
        assertEq(packed.toAddress(0), DETH_MARKET, "yieldSource should match market");
    }

    /// @notice Verify inspect() output is identical for both directions on the same market
    function test_Inspect_DirectionAgnostic_RealMarket() public view {
        address tokenIn = _firstErc20TokenIn();
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();

        bytes memory buyData = _buildBuyPtData(DETH_MARKET, tokenIn, pt, 1e18, 1, false);
        bytes memory sellData = _buildSellPtData(DETH_MARKET, pt, tokensOut[0], 1e18, 1, false);

        assertEq(hook.inspect(buyData), hook.inspect(sellData), "Inspect must not lock a direction");
    }

    /*//////////////////////////////////////////////////////////////
                    VALIDATION TESTS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the real SY correctly reports valid token outputs
    function test_SYValidation_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        assertGt(tokensOut.length, 0, "SY should have at least one valid token out");

        for (uint256 i; i < tokensOut.length; i++) {
            assertTrue(
                IStandardizedYield(sy).isValidTokenOut(tokensOut[i]),
                "Token from getTokensOut should pass isValidTokenOut"
            );
        }
    }

    /// @notice Verify build reverts with an invalid tokenIn for buy on real market
    function test_Build_BuyPt_RevertsWithInvalidTokenIn_RealMarket() public {
        address invalidToken = makeAddr("invalidToken");
        bytes memory data = _buildBuyPtData(DETH_MARKET, invalidToken, pt, 1e18, 1, false);

        vm.expectRevert(PendlePTHook.TOKEN_IN_NOT_LISTED.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify build reverts with an invalid tokenOut for sell on real market
    function test_Build_SellPt_RevertsWithInvalidTokenOut_RealMarket() public {
        if (IPYieldToken(yt).isExpired()) return;

        address invalidToken = makeAddr("invalidToken");
        bytes memory data = _buildSellPtData(DETH_MARKET, pt, invalidToken, 1e18, 1, false);

        vm.expectRevert(PendlePTHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify build reverts with an invalid tokenOut for redeem on real market
    function test_Build_RedeemPt_RevertsWithInvalidTokenOut_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        address invalidToken = makeAddr("invalidToken");
        bytes memory data = _buildRedeemData(DETH_MARKET, pt, invalidToken, 1e18, 1, false);

        vm.expectRevert(PendlePTHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify the hook correctly routes same payload to sell vs redeem based on expiry
    function test_ExpiryRouting_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        // Build data with PT as input — same (empty) payload for both paths
        bytes memory data = _buildSellPtData(DETH_MARKET, pt, tokenOut, 1e18, 1, false);

        // Pre-maturity: should route to sell (6 executions)
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) {
            Execution[] memory sellExecs = hook.build(address(prevHook), user, data);
            assertEq(sellExecs.length, 6, "Pre-maturity should produce 6 executions (sell)");
        }

        // Post-maturity: the exact same data routes to redeem (9 executions)
        vm.warp(expiry + 1 days);
        Execution[] memory redeemExecs = hook.build(address(prevHook), user, data);
        assertEq(redeemExecs.length, 9, "Post-maturity should produce 9 executions (redeem)");
    }

    /*//////////////////////////////////////////////////////////////
                EXECUTION TESTS — BUY PT (REAL ROUTER)
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute swapExactTokenForPt with real Pendle Router (pre-maturity only)
    function test_Execute_BuyPt_RealMarket() public {
        // Skip if market is expired
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address tokenIn = _firstErc20TokenIn();

        uint256 inputAmount = 1e18;

        // Deal input tokens to user
        deal(tokenIn, user, inputAmount);

        uint256 ptBefore = IERC20(pt).balanceOf(user);

        // Build hook data and executions
        bytes memory data = _buildBuyPtData(DETH_MARKET, tokenIn, pt, inputAmount, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Execute all as user
        vm.startPrank(user);
        for (uint256 i; i < executions.length; i++) {
            (bool success, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string(abi.encodePacked("Execution ", vm.toString(i), " failed: ", ret)));
        }
        vm.stopPrank();

        // Verify user received PT
        uint256 ptAfter = IERC20(pt).balanceOf(user);
        assertGt(ptAfter, ptBefore, "Should receive PT from swap");

        // Verify input tokens consumed
        assertEq(IERC20(tokenIn).balanceOf(user), 0, "Input tokens should be consumed");
    }

    /*//////////////////////////////////////////////////////////////
                EXECUTION TESTS — SELL PT (REAL ROUTER)
    //////////////////////////////////////////////////////////////*/

    /// @notice Execute swapExactPtForToken with real Pendle Router (pre-maturity only)
    function test_Execute_SellPt_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];

        uint256 ptAmount = 1e18;

        // Deal PT to user
        deal(pt, user, ptAmount);

        uint256 tokenOutBefore = IERC20(tokenOut).balanceOf(user);

        // Build hook data and executions
        bytes memory data = _buildSellPtData(DETH_MARKET, pt, tokenOut, ptAmount, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Execute all as user
        vm.startPrank(user);
        for (uint256 i; i < executions.length; i++) {
            (bool success, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string(abi.encodePacked("Execution ", vm.toString(i), " failed: ", ret)));
        }
        vm.stopPrank();

        uint256 tokenOutAfter = IERC20(tokenOut).balanceOf(user);
        assertGt(tokenOutAfter, tokenOutBefore, "Should receive tokenOut from PT swap");

        // Verify PT consumed
        assertEq(IERC20(pt).balanceOf(user), 0, "PT should be fully consumed");
    }

    /*//////////////////////////////////////////////////////////////
                EXECUTION TESTS — REDEEM PT (REAL ROUTER)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full e2e execution: redeem PT+YT for tokenOut via real Pendle Router
    function test_Execute_RedeemPt_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];
        uint256 redeemAmount = 1e18;

        // Deal PT and YT to user
        deal(pt, user, redeemAmount);
        deal(yt, user, redeemAmount);
        assertEq(IERC20(pt).balanceOf(user), redeemAmount, "PT not dealt");
        assertEq(IERC20(yt).balanceOf(user), redeemAmount, "YT not dealt");

        uint256 tokenOutBefore = IERC20(tokenOut).balanceOf(user);

        // Warp past expiry for post-maturity redemption
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        // Build hook data and executions
        bytes memory data = _buildRedeemData(DETH_MARKET, pt, tokenOut, redeemAmount, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Execute all as user
        vm.startPrank(user);
        for (uint256 i; i < executions.length; i++) {
            (bool success, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success, string(abi.encodePacked("Execution ", vm.toString(i), " failed: ", ret)));
        }
        vm.stopPrank();

        // Verify user received tokenOut
        uint256 tokenOutAfter = IERC20(tokenOut).balanceOf(user);
        assertGt(tokenOutAfter, tokenOutBefore, "Should receive tokens from redemption");

        // Verify PT was consumed
        assertEq(IERC20(pt).balanceOf(user), 0, "PT should be fully consumed");
    }

    /*//////////////////////////////////////////////////////////////
            EXECUTION TESTS — OUT AMOUNT TRACKING (REAL ROUTER)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify the hook correctly tracks output amount via pre/post execute on real redeem
    function test_Execute_RedeemPt_OutAmountTracking_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];
        uint256 redeemAmount = 1e18;

        deal(pt, user, redeemAmount);
        deal(yt, user, redeemAmount);

        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        uint256 tokenOutBefore = IERC20(tokenOut).balanceOf(user);

        bytes memory data = _buildRedeemData(DETH_MARKET, pt, tokenOut, redeemAmount, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        vm.startPrank(user);
        for (uint256 i; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success);
        }
        vm.stopPrank();

        // After postExecute, getOutAmount should reflect the tokens received
        uint256 outAmount = hook.getOutAmount(user);
        uint256 tokenOutAfter = IERC20(tokenOut).balanceOf(user);
        uint256 actualReceived = tokenOutAfter - tokenOutBefore;

        assertEq(outAmount, actualReceived, "getOutAmount should match actual tokens received");
        assertGt(outAmount, 0, "Should have received tokens");
    }

    /// @notice Verify buy PT output tracking matches actual PT received
    function test_Execute_BuyPt_OutAmountTracking_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address tokenIn = _firstErc20TokenIn();
        uint256 inputAmount = 1e18;

        deal(tokenIn, user, inputAmount);

        uint256 ptBefore = IERC20(pt).balanceOf(user);

        bytes memory data = _buildBuyPtData(DETH_MARKET, tokenIn, pt, inputAmount, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        vm.startPrank(user);
        for (uint256 i; i < executions.length; i++) {
            (bool success,) = executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(success);
        }
        vm.stopPrank();

        uint256 outAmount = hook.getOutAmount(user);
        uint256 ptAfter = IERC20(pt).balanceOf(user);
        uint256 actualReceived = ptAfter - ptBefore;

        assertEq(outAmount, actualReceived, "getOutAmount should match actual PT received");
        assertGt(outAmount, 0, "Should have received PT");
    }

    /*//////////////////////////////////////////////////////////////
        TRADE RESULT + RECORD HOOK COMPOSITION (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    function _exec(Execution[] memory executions) internal {
        vm.startPrank(user);
        for (uint256 i; i < executions.length; i++) {
            (bool ok, bytes memory ret) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            assertTrue(ok, string(abi.encodePacked("exec ", vm.toString(i), " failed: ", ret)));
        }
        vm.stopPrank();
    }

    function _recordPurchaseData(
        address market_,
        uint256 amount_,
        uint32 twap_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), market_, amount_, twap_, usePrev_);
    }

    function _recordRedemptionData(
        address market_,
        uint256 amount_,
        bool usePrev_
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(bytes(new bytes(52)), market_, amount_, usePrev_);
    }

    /// @notice Real BUY: TradeResult mirrors balance deltas, and the purchase recorder (auto) records
    ///         the ACTUAL PT received (output side).
    function test_TradeResult_And_RecordPurchase_BuyPt_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address tokenIn = _firstErc20TokenIn();
        uint256 inputAmount = 1e18;
        deal(tokenIn, user, inputAmount);

        uint256 tokenInBefore = IERC20(tokenIn).balanceOf(user);
        uint256 ptBefore = IERC20(pt).balanceOf(user);

        _exec(hook.build(address(prevHook), user, _buildBuyPtData(DETH_MARKET, tokenIn, pt, inputAmount, 1, false)));

        uint256 ptReceived = IERC20(pt).balanceOf(user) - ptBefore;
        uint256 tokenSpent = tokenInBefore - IERC20(tokenIn).balanceOf(user);
        assertGt(ptReceived, 0, "PT received");

        IPendlePTHookResult.TradeResult memory r = hook.getPendleTradeResult(user);
        assertEq(uint256(r.operation), uint256(IPendlePTHookResult.Operation.BUY_PT), "op BUY_PT");
        assertEq(r.market, DETH_MARKET, "market");
        assertEq(r.outputToken, pt, "output PT");
        assertEq(r.outputAmount, ptReceived, "outputAmount == actual PT received");
        assertEq(r.inputToken, tokenIn, "input token");
        assertEq(r.inputAmount, tokenSpent, "inputAmount == token spent");

        MockPendlePTAmortizedOracle mockOracle = new MockPendlePTAmortizedOracle();
        RecordPurchasePendlePTHook rec = new RecordPurchasePendlePTHook(address(mockOracle), address(hook));
        Execution[] memory recEx = rec.build(address(hook), user, _recordPurchaseData(DETH_MARKET, 0, 900, true));
        uint256 expectedSySpent = mockOracle.getAssetOutput(DETH_MARKET, address(0), ptReceived);
        assertEq(
            recEx[1].callData,
            abi.encodeWithSignature(
                "recordPurchase(address,uint256,uint256)", DETH_MARKET, expectedSySpent, ptReceived
            ),
            "records actual PT received, valued on-chain (V1: market, sySpent, ptAmount)"
        );
    }

    /// @notice Real SELL: PT is the INPUT — the redemption recorder must record PT SPENT (inputAmount),
    ///         never the output asset received.
    function test_TradeResult_And_RecordRedemption_SellPt_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];
        uint256 ptAmount = 1e18;
        deal(pt, user, ptAmount);

        uint256 tokenOutBefore = IERC20(tokenOut).balanceOf(user);

        _exec(hook.build(address(prevHook), user, _buildSellPtData(DETH_MARKET, pt, tokenOut, ptAmount, 1, false)));

        uint256 assetReceived = IERC20(tokenOut).balanceOf(user) - tokenOutBefore;
        assertGt(assetReceived, 0, "asset received");

        IPendlePTHookResult.TradeResult memory r = hook.getPendleTradeResult(user);
        assertEq(uint256(r.operation), uint256(IPendlePTHookResult.Operation.SELL_PT), "op SELL_PT");
        assertEq(r.inputToken, pt, "input PT");
        assertEq(r.inputAmount, ptAmount, "inputAmount == PT spent (full)");
        assertEq(r.outputToken, tokenOut, "output asset");
        assertEq(r.outputAmount, assetReceived, "outputAmount == asset received");

        RecordRedemptionPendlePTHook rec = new RecordRedemptionPendlePTHook(makeAddr("oracleV2"), address(hook));
        Execution[] memory recEx = rec.build(address(hook), user, _recordRedemptionData(DETH_MARKET, 0, true));
        // Records PT SPENT (inputAmount), NOT the received asset (assetReceived).
        assertEq(
            recEx[1].callData,
            abi.encodeWithSignature("recordRedemption(address,uint256)", DETH_MARKET, r.inputAmount),
            "records actual PT spent"
        );
    }

    /// @notice Real matured REDEEM: operation is REDEEM_PT and inputAmount is the PT redeemed.
    function test_TradeResult_And_RecordRedemption_MaturedRedeem_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];
        uint256 redeemAmount = 1e18;
        deal(pt, user, redeemAmount);
        deal(yt, user, redeemAmount);

        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        _exec(hook.build(address(prevHook), user, _buildRedeemData(DETH_MARKET, pt, tokenOut, redeemAmount, 1, false)));

        IPendlePTHookResult.TradeResult memory r = hook.getPendleTradeResult(user);
        assertEq(uint256(r.operation), uint256(IPendlePTHookResult.Operation.REDEEM_PT), "op REDEEM_PT");
        assertEq(r.inputToken, pt, "input PT");
        assertEq(r.inputAmount, redeemAmount, "inputAmount == PT redeemed");

        RecordRedemptionPendlePTHook rec = new RecordRedemptionPendlePTHook(makeAddr("oracleV2"), address(hook));
        Execution[] memory recEx = rec.build(address(hook), user, _recordRedemptionData(DETH_MARKET, 0, true));
        assertEq(
            recEx[1].callData,
            abi.encodeWithSignature("recordRedemption(address,uint256)", DETH_MARKET, redeemAmount),
            "records actual PT redeemed"
        );
    }

    /// @notice Execution-context isolation (P2 regression guard): a TradeResult recorded in one execution
    ///         context MUST NOT be readable in a later context. Before the context-nonce keying fix the
    ///         TradeResult was keyed by account only, so the stale buy would leak here and a redemption
    ///         recorder would consume it. After the fix the new context reads Operation.NONE and the
    ///         recorder reverts OPERATION_NOT_VALID.
    function test_TradeResult_ContextIsolation_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address tokenIn = _firstErc20TokenIn();
        deal(tokenIn, user, 1e18);

        // Context 0: real buy populates the TradeResult.
        _exec(hook.build(address(prevHook), user, _buildBuyPtData(DETH_MARKET, tokenIn, pt, 1e18, 1, false)));
        assertEq(
            uint256(hook.getPendleTradeResult(user).operation),
            uint256(IPendlePTHookResult.Operation.BUY_PT),
            "context 0 sees BUY_PT"
        );

        // Advance to a fresh execution context for the same account.
        hook.setExecutionContext(user);

        // New context: the prior trade is gone (isolated by context nonce, not just account).
        assertEq(
            uint256(hook.getPendleTradeResult(user).operation),
            uint256(IPendlePTHookResult.Operation.NONE),
            "new context sees NONE (no leak across contexts)"
        );

        // A recorder built against the empty context must reject it rather than record a stale amount.
        RecordRedemptionPendlePTHook rec = new RecordRedemptionPendlePTHook(makeAddr("oracleV2"), address(hook));
        vm.expectRevert(RecordRedemptionPendlePTHook.OPERATION_NOT_VALID.selector);
        rec.build(address(hook), user, _recordRedemptionData(DETH_MARKET, 0, true));
    }

    /// @notice Cross-hook wrong-direction: a purchase recorder after a SELL must revert (op mismatch).
    function test_RecordPurchase_RejectsSell_RealMarket() public {
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) return;

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        deal(pt, user, 1e18);
        _exec(hook.build(address(prevHook), user, _buildSellPtData(DETH_MARKET, pt, tokensOut[0], 1e18, 1, false)));

        RecordPurchasePendlePTHook rec =
            new RecordPurchasePendlePTHook(address(new MockPendlePTAmortizedOracle()), address(hook));
        vm.expectRevert(RecordPurchasePendlePTHook.OPERATION_NOT_VALID.selector);
        rec.build(address(hook), user, _recordPurchaseData(DETH_MARKET, 0, 900, true));
    }

    /*//////////////////////////////////////////////////////////////
            LIMIT ORDER VALIDATION TESTS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build() accepts empty limit order data with real market
    function test_Build_BuyPt_EmptyLimitOrders_RealMarket() public view {
        address tokenIn = _firstErc20TokenIn();

        bytes memory data = _buildBuyPtData(DETH_MARKET, tokenIn, pt, 1e18, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);
        assertEq(executions.length, 6, "Empty limit orders should still produce 6 executions");
    }

    /// @notice Verify limit order validation rejects expired orders on real fork (uses real block.timestamp)
    function test_Build_BuyPt_RevertIf_ExpiredLimitOrder_RealMarket() public {
        address tokenIn = _firstErc20TokenIn();

        LimitOrderData memory limit = _createLimitOrderDataWithExpiry(block.timestamp - 1);

        bytes memory data = _buildBuyPtDataWithLimit(DETH_MARKET, tokenIn, pt, 1e18, 1, limit, false);

        vm.expectRevert(PendlePTHook.ORDER_EXPIRED.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify limit order validation rejects expired orders for sell on real fork
    function test_Build_SellPt_RevertIf_ExpiredLimitOrder_RealMarket() public {
        if (IPYieldToken(yt).isExpired()) return;

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        LimitOrderData memory limit = _createLimitOrderDataWithExpiry(block.timestamp - 1);

        bytes memory data = _buildSellPtDataWithLimit(DETH_MARKET, pt, tokenOut, 1e18, 1, limit, false);

        vm.expectRevert(PendlePTHook.ORDER_EXPIRED.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify limit order validation rejects zero maker address on real fork
    function test_Build_BuyPt_RevertIf_ZeroMaker_RealMarket() public {
        address tokenIn = _firstErc20TokenIn();

        LimitOrderData memory limit = _createLimitOrderDataWithExpiry(block.timestamp + 1 hours);
        limit.normalFills[0].order.maker = address(0);

        bytes memory data = _buildBuyPtDataWithLimit(DETH_MARKET, tokenIn, pt, 1e18, 1, limit, false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify limit order validation rejects zero making amount on real fork
    function test_Build_BuyPt_RevertIf_ZeroMakingAmount_RealMarket() public {
        address tokenIn = _firstErc20TokenIn();

        LimitOrderData memory limit = _createLimitOrderDataWithExpiry(block.timestamp + 1 hours);
        limit.normalFills[0].makingAmount = 0;

        bytes memory data = _buildBuyPtDataWithLimit(DETH_MARKET, tokenIn, pt, 1e18, 1, limit, false);

        vm.expectRevert(PendlePTHook.MAKING_AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify limit order validation rejects too many fills on real fork
    function test_Build_BuyPt_RevertIf_TooManyFills_RealMarket() public {
        address tokenIn = _firstErc20TokenIn();

        LimitOrderData memory limit;
        limit.limitRouter = address(0xCAFE);
        limit.normalFills = new FillOrderParams[](65);
        for (uint256 i; i < 65; ++i) {
            limit.normalFills[i] = _createValidFillOrderParams(block.timestamp + 1 hours);
        }

        bytes memory data = _buildBuyPtDataWithLimit(DETH_MARKET, tokenIn, pt, 1e18, 1, limit, false);

        vm.expectRevert(PendlePTHook.TOO_MANY_FILLS.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify limit order validation rejects optData exceeding max length on real fork
    function test_Build_BuyPt_RevertIf_OptDataTooLong_RealMarket() public {
        address tokenIn = _firstErc20TokenIn();

        LimitOrderData memory limit = _createLimitOrderDataWithExpiry(block.timestamp + 1 hours);
        limit.optData = new bytes(1025);

        bytes memory data = _buildBuyPtDataWithLimit(DETH_MARKET, tokenIn, pt, 1e18, 1, limit, false);

        vm.expectRevert(PendlePTHook.OPT_DATA_TOO_LONG.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify limit order validation rejects zero limitRouter when fills exist
    function test_Build_BuyPt_RevertIf_ZeroLimitRouter_RealMarket() public {
        address tokenIn = _firstErc20TokenIn();

        LimitOrderData memory limit = _createLimitOrderDataWithExpiry(block.timestamp + 1 hours);
        limit.limitRouter = address(0);

        bytes memory data = _buildBuyPtDataWithLimit(DETH_MARKET, tokenIn, pt, 1e18, 1, limit, false);

        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        hook.build(address(prevHook), user, data);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Creates a LimitOrderData with one normal fill, using the given expiry
    function _createLimitOrderDataWithExpiry(uint256 expiry_) internal pure returns (LimitOrderData memory limit) {
        limit.limitRouter = address(0xCAFE);
        limit.epsSkipMarket = 0;
        limit.optData = "";
        limit.normalFills = new FillOrderParams[](1);
        limit.normalFills[0] = _createValidFillOrderParams(expiry_);
    }

    /// @dev Creates a valid FillOrderParams for testing
    function _createValidFillOrderParams(uint256 expiry_) internal pure returns (FillOrderParams memory) {
        Order memory order = Order({
            salt: 1,
            expiry: expiry_,
            nonce: 0,
            orderType: OrderType.SY_FOR_PT,
            token: address(0x1111),
            YT: address(0x2222),
            maker: address(0xABCD),
            receiver: address(0xABCD),
            makingAmount: 1000,
            lnImpliedRate: 0,
            failSafeRate: 0,
            permit: ""
        });

        return FillOrderParams({ order: order, signature: hex"deadbeef", makingAmount: 500 });
    }

    /// @dev Returns the first non-native tokenIn listed by the SY (ERC20 buy path)
    function _firstErc20TokenIn() internal view returns (address) {
        address[] memory tokensIn = IStandardizedYield(sy).getTokensIn();
        for (uint256 i; i < tokensIn.length; i++) {
            if (tokensIn[i] != address(0)) return tokensIn[i];
        }
        revert("No ERC20 tokens in");
    }

    /// @dev Builds buy PT data: tokenIn → PT. Payload = abi.encode(ApproxParams, LimitOrderData)
    function _buildBuyPtData(
        address market_,
        address tokenIn_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 minPtOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        LimitOrderData memory emptyLimit;
        return _buildBuyPtDataWithLimit(
            market_, tokenIn_, outputToken_, inputAmount_, minPtOut_, emptyLimit, usePrevHookAmount_
        );
    }

    /// @dev Builds buy PT data with custom LimitOrderData
    function _buildBuyPtDataWithLimit(
        address market_,
        address tokenIn_,
        address outputToken_,
        uint256 inputAmount_,
        uint256 minPtOut_,
        LimitOrderData memory limit_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 0,
            guessMax: type(uint256).max,
            guessOffchain: 0,
            maxIteration: 256,
            eps: 1e15
        });

        // PendlePTHook: no selector prefix — routingParams IS the payload
        bytes memory routingParams = abi.encode(guessPtOut, limit_);

        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(tokenIn_),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minPtOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Builds sell PT data: PT → tokenOut. Payload = abi.encode(LimitOrderData)
    function _buildSellPtData(
        address market_,
        address inputToken_,
        address tokenOut_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        LimitOrderData memory emptyLimit;
        return _buildSellPtDataWithLimit(
            market_, inputToken_, tokenOut_, exactPtIn_, minTokenOut_, emptyLimit, usePrevHookAmount_
        );
    }

    /// @dev Builds sell PT data with custom LimitOrderData
    function _buildSellPtDataWithLimit(
        address market_,
        address inputToken_,
        address tokenOut_,
        uint256 exactPtIn_,
        uint256 minTokenOut_,
        LimitOrderData memory limit_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory routingParams = abi.encode(limit_);
        return bytes.concat(
            bytes32(0),
            bytes20(market_),
            bytes20(inputToken_),
            bytes20(tokenOut_),
            bytes32(exactPtIn_),
            bytes32(uint256(0)),
            bytes32(minTokenOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(routingParams.length),
            routingParams
        );
    }

    /// @dev Builds redeem PT data: PT → tokenOut (post-maturity)
    /// @dev Identical to sell — routing is determined by YT.isExpired()
    function _buildRedeemData(
        address market_,
        address inputToken_,
        address tokenOut_,
        uint256 amount_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _buildSellPtData(market_, inputToken_, tokenOut_, amount_, minTokenOut_, usePrevHookAmount_);
    }

    /// @dev Removes the first 4 bytes (selector) from calldata for abi.decode
    function _removeSelector(bytes memory data) internal pure returns (bytes memory result) {
        result = new bytes(data.length - 4);
        for (uint256 i; i < result.length; ++i) {
            result[i] = data[i + 4];
        }
    }
}
