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
    IPendleRouterV4,
    LimitOrderData,
    FillOrderParams,
    TokenInput,
    TokenOutput,
    ApproxParams,
    SwapType,
    SwapData
} from "../../../src/vendor/pendle/IPendleRouterV4.sol";

import { PendleUnifiedHook } from "../../../src/hooks/swappers/pendle/PendleUnifiedHook.sol";
import { MockHook } from "../../mocks/MockHook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";

/// @title PendleUnifiedHookE2E
/// @notice End-to-end tests for PendleUnifiedHook using real mainnet addresses via fork
/// @dev Tests build(), inspect(), and full execution with real Pendle Router V4 and DETH market
contract PendleUnifiedHookE2E is Test {
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

    PendleUnifiedHook public hook;
    MockHook public prevHook;

    address public sy;
    address public pt;
    address public yt;
    address public user;

    function setUp() public {
        // Pin to block before DETH market expiry (Jan 29, 2026) to ensure consistent Pendle state
        vm.createSelectFork(vm.envString("ETHEREUM_RPC_URL"), 24_300_000);

        hook = new PendleUnifiedHook(PENDLE_ROUTER);
        prevHook = new MockHook(ISuperHook.HookType.NONACCOUNTING, address(0));

        (sy, pt, yt) = IPendleMarket(DETH_MARKET).readTokens();
        user = makeAddr("user");
    }

    /*//////////////////////////////////////////////////////////////
                        BUILD TESTS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify build() produces correct 9-execution structure for redeem with real market
    function test_Build_RedeemPyToToken_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];

        uint256 redeemAmount = 1e18;
        bytes memory data = _buildRedeemData(DETH_MARKET, yt, redeemAmount, tokenOut, tokenOut, 1, false);

        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // 7 hook executions + 2 wrappers = 9
        assertEq(executions.length, 9, "Redeem should produce 9 executions");

        // Verify approve pattern targets
        assertEq(executions[1].target, pt, "exec[1] should target PT (approve(0))");
        assertEq(executions[2].target, pt, "exec[2] should target PT (approve)");
        assertEq(executions[3].target, yt, "exec[3] should target YT (approve(0))");
        assertEq(executions[4].target, yt, "exec[4] should target YT (approve)");
        assertEq(executions[5].target, PENDLE_ROUTER, "exec[5] should target router (redeem)");
        assertEq(executions[6].target, pt, "exec[6] should target PT (reset)");
        assertEq(executions[7].target, yt, "exec[7] should target YT (reset)");

        // Verify approve calldatas encode correct amounts
        assertEq(executions[1].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[2].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, redeemAmount)));
        assertEq(executions[3].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[4].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, redeemAmount)));
        assertEq(executions[6].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
        assertEq(executions[7].callData, abi.encodeCall(IERC20.approve, (PENDLE_ROUTER, 0)));
    }

    /// @notice Verify build() produces correct 3-execution structure for swapExactTokenForPt with real market
    function test_Build_SwapExactTokenForPt_RealMarket() public view {
        address[] memory tokensIn = IStandardizedYield(sy).getTokensIn();
        require(tokensIn.length > 0, "No valid tokens in");
        address tokenIn = tokensIn[0];

        uint256 inputAmount = 1e18;
        bytes memory data = _buildSwapTokenForPtData(DETH_MARKET, user, inputAmount, tokenIn, pt, 1, false);

        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // 4 hook executions (approve(0), approve, call, approve(0)) + 2 wrappers = 6
        assertEq(executions.length, 6, "SwapTokenForPt should produce 6 executions");
        assertEq(executions[3].target, PENDLE_ROUTER, "exec[3] should target router");
        assertEq(executions[3].value, 0, "Should have zero value for ERC20 tokenIn");
    }

    /// @notice Verify build() produces correct 6-execution structure for swapExactPtForToken with real market
    function test_Build_SwapExactPtForToken_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];

        uint256 ptAmount = 1e18;
        bytes memory data = _buildSwapPtForTokenData(DETH_MARKET, user, ptAmount, tokenOut, 1, false);

        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // 4 hook executions (approve(0), approve, call, approve(0)) + 2 wrappers = 6
        assertEq(executions.length, 6, "SwapPtForToken should produce 6 executions");
        assertEq(executions[3].target, PENDLE_ROUTER, "exec[3] should target router");
    }

    /// @notice Verify build() correctly encodes the redeemPyToToken calldata with real YT address
    function test_Build_RedeemPyToToken_CallDataEncoding_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];
        uint256 redeemAmount = 2.5e18;

        bytes memory data = _buildRedeemData(DETH_MARKET, yt, redeemAmount, tokenOut, tokenOut, 1e17, false);
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
    }

    /*//////////////////////////////////////////////////////////////
                        INSPECT TESTS (REAL MARKET)
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify inspect() returns packed outputToken (20 bytes) for redeem
    function test_Inspect_RedeemPyToToken_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        bytes memory data = _buildRedeemData(DETH_MARKET, yt, 1e18, tokenOut, tokenOut, 1, false);
        bytes memory packed = hook.inspect(data);

        assertEq(packed.length, 20, "Inspect should return 20 bytes (outputToken)");

        address inspectedOutputToken = packed.toAddress(0);
        assertEq(inspectedOutputToken, tokenOut, "Output token should match header outputToken at offset 72");
    }

    /// @notice Verify inspect() returns packed outputToken (20 bytes) for swapExactTokenForPt
    function test_Inspect_SwapExactTokenForPt_RealMarket() public view {
        address[] memory tokensIn = IStandardizedYield(sy).getTokensIn();
        address tokenIn = tokensIn[0];

        bytes memory data = _buildSwapTokenForPtData(DETH_MARKET, user, 1e18, tokenIn, pt, 1, false);
        bytes memory packed = hook.inspect(data);

        assertEq(packed.length, 20, "Inspect should return 20 bytes (outputToken)");

        address inspectedOutputToken = packed.toAddress(0);
        assertEq(inspectedOutputToken, pt, "Output token should match PT at offset 72");
    }

    /// @notice Verify inspect() returns packed outputToken (20 bytes) for swapExactPtForToken
    function test_Inspect_SwapExactPtForToken_RealMarket() public view {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];

        bytes memory data = _buildSwapPtForTokenData(DETH_MARKET, user, 1e18, tokenOut, 1, false);
        bytes memory packed = hook.inspect(data);

        assertEq(packed.length, 20, "Inspect should return 20 bytes (outputToken)");

        address inspectedOutputToken = packed.toAddress(0);
        assertEq(inspectedOutputToken, tokenOut, "Output token should match header outputToken at offset 72");
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

    /// @notice Verify build reverts with an invalid tokenOut for direct redemption on real market
    function test_Build_RedeemPyToToken_RevertsWithInvalidTokenOut_RealMarket() public {
        address invalidToken = makeAddr("invalidToken");
        bytes memory data = _buildRedeemData(DETH_MARKET, yt, 1e18, invalidToken, invalidToken, 1, false);

        vm.expectRevert(PendleUnifiedHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify build reverts with a mismatched YT on real market
    function test_Build_RedeemPyToToken_RevertsWithWrongYT_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];
        address wrongYT = makeAddr("wrongYT");

        bytes memory data = _buildRedeemData(DETH_MARKET, wrongYT, 1e18, tokenOut, tokenOut, 1, false);

        vm.expectRevert(PendleUnifiedHook.YT_NOT_VALID.selector);
        hook.build(address(prevHook), user, data);
    }

    /// @notice Verify build reverts with mismatched market for swapExactTokenForPt
    function test_Build_SwapExactTokenForPt_RevertsWithWrongMarket_RealMarket() public {
        address[] memory tokensIn = IStandardizedYield(sy).getTokensIn();
        address tokenIn = tokensIn[0];

        // yieldSource is DETH_MARKET but txData contains a different market
        address wrongMarket = makeAddr("wrongMarket");
        bytes memory data = _buildSwapTokenForPtDataWithYieldSource(
            DETH_MARKET, // yieldSource header
            wrongMarket, // market in txData (mismatch)
            user,
            1e18,
            tokenIn,
            address(0), // outputToken (irrelevant, reverts with MARKET_NOT_VALID first)
            1,
            false
        );

        vm.expectRevert(PendleUnifiedHook.MARKET_NOT_VALID.selector);
        hook.build(address(prevHook), user, data);
    }

    /*//////////////////////////////////////////////////////////////
                    EXECUTION TESTS (REAL ROUTER)
    //////////////////////////////////////////////////////////////*/

    /// @notice Full e2e execution: redeem PT+YT for tokenOut via real Pendle Router
    /// @dev Uses deal() to give PT/YT to user, warps past maturity, then executes
    function test_Execute_RedeemPyToToken_DirectRedemption_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");

        // Use the first valid tokenOut
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
        if (block.timestamp < expiry) {
            vm.warp(expiry + 1 days);
        }

        // Build hook data and executions
        bytes memory data = _buildRedeemData(DETH_MARKET, yt, redeemAmount, tokenOut, tokenOut, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Execute all as user (preExecute, approvals, redeem, resets, postExecute)
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

        // Verify PT was consumed (YT balance may not decrease due to deal() bypassing Pendle internals)
        assertEq(IERC20(pt).balanceOf(user), 0, "PT should be fully consumed");
    }

    /// @notice Execute swapExactTokenForPt with real Pendle Router (pre-maturity only)
    /// @dev Skips if market is expired since swaps require active liquidity
    function test_Execute_SwapExactTokenForPt_RealMarket() public {
        // Check if market is pre-maturity (swaps only work before expiry)
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) {
            // Market is expired, skip this test
            return;
        }

        // Get a valid input token for SY
        address[] memory tokensIn = IStandardizedYield(sy).getTokensIn();
        require(tokensIn.length > 0, "No valid tokens in");
        address tokenIn = tokensIn[0];

        uint256 inputAmount = 1e18;

        // Deal input tokens to user
        deal(tokenIn, user, inputAmount);

        // Pre-approve the Pendle Router (PendleUnifiedHook swap paths don't include approvals)
        vm.prank(user);
        IERC20(tokenIn).approve(PENDLE_ROUTER, inputAmount);

        uint256 ptBefore = IERC20(pt).balanceOf(user);

        // Build hook data and executions
        bytes memory data = _buildSwapTokenForPtData(DETH_MARKET, user, inputAmount, tokenIn, pt, 1, false);
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
    }

    /// @notice Execute swapExactPtForToken with real Pendle Router (pre-maturity only)
    /// @dev Skips if market is expired since swaps require active liquidity
    function test_Execute_SwapExactPtForToken_RealMarket() public {
        // Check if market is pre-maturity
        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp >= expiry) {
            return;
        }

        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        require(tokensOut.length > 0, "No valid tokens out");
        address tokenOut = tokensOut[0];

        uint256 ptAmount = 1e18;

        // Deal PT to user
        deal(pt, user, ptAmount);

        // Pre-approve the Pendle Router
        vm.prank(user);
        IERC20(pt).approve(PENDLE_ROUTER, ptAmount);

        uint256 tokenOutBefore = IERC20(tokenOut).balanceOf(user);

        // Build hook data and executions
        bytes memory data = _buildSwapPtForTokenData(DETH_MARKET, user, ptAmount, tokenOut, 1, false);
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
    }

    /// @notice Verify the hook correctly tracks output amount via pre/post execute on real redeem
    function test_Execute_RedeemPyToToken_OutAmountTracking_RealMarket() public {
        address[] memory tokensOut = IStandardizedYield(sy).getTokensOut();
        address tokenOut = tokensOut[0];
        uint256 redeemAmount = 1e18;

        deal(pt, user, redeemAmount);
        deal(yt, user, redeemAmount);

        uint256 expiry = IPYieldToken(yt).expiry();
        if (block.timestamp < expiry) vm.warp(expiry + 1 days);

        uint256 tokenOutBefore = IERC20(tokenOut).balanceOf(user);

        bytes memory data = _buildRedeemData(DETH_MARKET, yt, redeemAmount, tokenOut, tokenOut, 1, false);
        Execution[] memory executions = hook.build(address(prevHook), user, data);

        // Execute all
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

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _buildRedeemData(
        address market_,
        address yt_,
        uint256 amount_,
        address tokenOut_,
        address tokenRedeemSy_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        view
        returns (bytes memory)
    {
        TokenOutput memory output = TokenOutput({
            tokenOut: tokenOut_,
            minTokenOut: minTokenOut_,
            tokenRedeemSy: tokenRedeemSy_,
            pendleSwap: address(0),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        bytes memory txData = abi.encodeWithSelector(IPendleRouterV4.redeemPyToToken.selector, user, yt_, amount_, output);

        bytes memory payload = abi.encode(market_, uint256(0), txData);
        return bytes.concat(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(0)),
            bytes20(tokenOut_),
            bytes32(amount_),
            bytes32(uint256(0)),
            bytes32(minTokenOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(payload.length),
            payload
        );
    }

    function _buildSwapTokenForPtData(
        address market_,
        address receiver_,
        uint256 inputAmount_,
        address tokenIn_,
        address outputToken_,
        uint256 minPtOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        return _buildSwapTokenForPtDataWithYieldSource(market_, market_, receiver_, inputAmount_, tokenIn_, outputToken_, minPtOut_, usePrevHookAmount_);
    }

    function _buildSwapTokenForPtDataWithYieldSource(
        address yieldSource_,
        address market_,
        address receiver_,
        uint256 inputAmount_,
        address tokenIn_,
        address outputToken_,
        uint256 minPtOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        TokenInput memory input = TokenInput({
            tokenIn: tokenIn_,
            netTokenIn: inputAmount_,
            tokenMintSy: tokenIn_,
            pendleSwap: address(0),
            swapData: SwapData({ swapType: SwapType.NONE, extRouter: address(0), extCalldata: "", needScale: false })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 0,
            guessMax: type(uint256).max,
            guessOffchain: 0,
            maxIteration: 256,
            eps: 1e15
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

        bytes memory payload = abi.encode(yieldSource_, uint256(0), txData);
        return bytes.concat(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(0)),
            bytes20(outputToken_),
            bytes32(inputAmount_),
            bytes32(uint256(0)),
            bytes32(minPtOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(payload.length),
            payload
        );
    }

    function _buildSwapPtForTokenData(
        address market_,
        address receiver_,
        uint256 exactPtIn_,
        address tokenOut_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        TokenOutput memory output = TokenOutput({
            tokenOut: tokenOut_,
            minTokenOut: minTokenOut_,
            tokenRedeemSy: tokenOut_,
            pendleSwap: address(0),
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
            IPendleRouterV4.swapExactPtForToken.selector, receiver_, market_, exactPtIn_, output, limit
        );

        bytes memory payload = abi.encode(market_, uint256(0), txData);
        return bytes.concat(
            bytes32(0),
            bytes20(address(0)),
            bytes20(address(0)),
            bytes20(tokenOut_),
            bytes32(exactPtIn_),
            bytes32(uint256(0)),
            bytes32(minTokenOut_),
            usePrevHookAmount_ ? bytes1(0x01) : bytes1(0x00),
            bytes32(payload.length),
            payload
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
