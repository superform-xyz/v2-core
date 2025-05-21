// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Tests

import {UserOpData} from "modulekit/ModuleKit.sol";
import {IPendleMarket} from "../../../src/vendor/pendle/IPendleMarket.sol";
import {IPendleRouterV4, TokenInput, SwapData, SwapType} from "../../../src/vendor/pendle/IPendleRouterV4.sol";
import {PendleRouterRedeemHook} from "../../../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
import {PendleRouterSwapHook} from "../../../src/core/hooks/swappers/pendle/PendleRouterSwapHook.sol";
import {IStandardizedYield} from "../../../src/vendor/pendle/IStandardizedYield.sol";
import {ISuperExecutor} from "../../../src/core/interfaces/ISuperExecutor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {MinimalBaseIntegrationTest} from "../MinimalBaseIntegrationTest.t.sol";
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
import {OdosAPIParser} from "../../utils/parsers/OdosAPIParser.sol";

contract PendleRouterHookTests is MinimalBaseIntegrationTest, OdosAPIParser {
    address public token;

    address public pendlePufETHMarket;

    PendleRouterSwapHook public swapHook;

    IERC20 public eUSDe;
    IERC20 public yt_eUSDe;
    IERC20 public pt_eUSDe;

    uint256 public constant expiry = 22_411_332;

    PendleRouterRedeemHook public pendleredeemHook;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        // Token Out = Token Redeem Sy = Ethena USDe
        eUSDe = IERC20(0x4c9EDD5852cd905f086C759E8383e09bff1E68B3);

        // YT Ethena USDe
        yt_eUSDe = IERC20(0x733Ee9Ba88f16023146EbC965b7A1Da18a322464);

        // PT Ethena USDe
        pt_eUSDe = IERC20(0x917459337CaAC939D41d7493B3999f571D20D667);

        deal(address(eUSDe), accountEth, 10e18);

        pendleredeemHook = new PendleRouterRedeemHook(CHAIN_1_PendleRouter);

        token = CHAIN_1_USDC;
        pendlePufETHMarket = 0x58612beB0e8a126735b19BB222cbC7fC2C162D2a;

        swapHook = new PendleRouterSwapHook(CHAIN_1_PendleRouter);
    }

    // tx example: https://etherscan.io/tx/0x36b2c58e314e9d9bf73fc0d632ed228e35cd6b840066d12d39f72c633bad27a5
    function test_PendleRouterSwap_Token_To_Pt() public {
        uint256 amount = 1e6;

        // get tokens
        deal(token, accountEth, amount);
        IPendleMarket _market = IPendleMarket(pendlePufETHMarket);
        (address sy, address pt,) = _market.readTokens();
        // note syTokenIns [1] is WETH for this SY, which should have high liquidity
        address[] memory syTokenIns = IStandardizedYield(sy).getTokensIn();
        uint256 balance = IERC20(pt).balanceOf(accountEth);
        assertEq(balance, 0);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = address(approveHook);
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(token, CHAIN_1_PendleRouter, amount, false);
        hookData[1] = _createPendleRouterSwapHookDataWithOdos(
            pendlePufETHMarket, accountEth, false, 1 ether, false, amount, CHAIN_1_USDC, syTokenIns[1]
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hookAddresses_, hooksData: hookData});
        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        executeOp(opData);

        balance = IERC20(pt).balanceOf(accountEth);
        assertGt(balance, 0);
    }

    // mintPyFromToken tx
    // example:https://etherscan.io/inputdatadecoder?tx=0xa5af7fe6016b5683f48e36e79bd300728b352fa45262d153426167d0d89862fa
    // redeemPyToToken tx example:
    // https://etherscan.io/inputdatadecoder?tx=0xca0e4932ecb628b2996ba1f24089f9faa98ccc2451afa14fbb964336fa6351c0
    function test_PendleRouterRedeemHook() public {
        vm.warp(22_384_742);

        uint256 eUSDeBalance = eUSDe.balanceOf(accountEth);
        uint256 ptBalance = pt_eUSDe.balanceOf(accountEth); // 0

        TokenInput memory tokenInput = TokenInput({
            tokenIn: address(eUSDe),
            netTokenIn: 1e18,
            tokenMintSy: address(eUSDe),
            pendleSwap: address(0),
            swapData: SwapData({swapType: SwapType.NONE, extRouter: address(0), extCalldata: bytes(""), needScale: false})
        });

        vm.startPrank(accountEth);
        eUSDe.approve(address(IPendleRouterV4(CHAIN_1_PendleRouter)), 1e18);
        IPendleRouterV4(CHAIN_1_PendleRouter).mintPyFromToken(
            accountEth, // receiver
            address(yt_eUSDe), // YT
            0.7e18, // minPyOut
            tokenInput
        );

        assertEq(eUSDe.balanceOf(accountEth), eUSDeBalance - 1e18);
        assertGt(pt_eUSDe.balanceOf(accountEth), ptBalance);

        vm.warp(expiry + 1 days);

        address[] memory hooks = new address[](1);
        hooks[0] = address(pendleredeemHook);

        bytes[] memory data = new bytes[](1);
        data[0] = _createPendleRedeemHookData(
            1e18, address(yt_eUSDe), address(pt_eUSDe), address(eUSDe), address(eUSDe), 1e17, false
        );

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({hooksAddresses: hooks, hooksData: data});

        UserOpData memory userOpData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        executeOp(userOpData);

        assertEq(eUSDe.balanceOf(accountEth), eUSDeBalance);
        assertEq(pt_eUSDe.balanceOf(accountEth), ptBalance);
    }

    function _createTokenToPtPendleTxDataWithOdos(
        address _market,
        address _receiver,
        address _tokenIn,
        uint256 _minPtOut,
        uint256 _amount,
        address _tokenMintSY,
        bytes memory _odosCalldata,
        address pendleSwap,
        address odosRouter
    ) internal pure returns (bytes memory pendleTxData) {
        // no limit order needed
        LimitOrderData memory limit = LimitOrderData({
            limitRouter: address(0),
            epsSkipMarket: 0,
            normalFills: new FillOrderParams[](0),
            flashFills: new FillOrderParams[](0),
            optData: "0x"
        });

        // TokenInput
        TokenInput memory input = TokenInput({
            tokenIn: _tokenIn,
            netTokenIn: _amount,
            tokenMintSy: _tokenMintSY, //CHAIN_1_cUSDO,
            pendleSwap: pendleSwap,
            swapData: SwapData({
                extRouter: odosRouter,
                extCalldata: _odosCalldata,
                needScale: false,
                swapType: SwapType.ODOS
            })
        });
        /*
        The guessMax and guessOffchain are being set based on the initial USDC _amount (1e6). However, these guesses are
        used for the internal Pendle swap which involves SY and PT tokens, likely with 18 decimals and completely
        different magnitudes. A guessMax of 2e6 wei for an 18-decimal token is extremely small and likely far below the
        actual expected PT output amount. The true value falls outside the provided [guessMin, guessMax] range, causing
        the approximation to fail.
        We need to provide more realistic bounds for the expected PT output. Since 1 USDC is roughly $1 and the PT is
        likely near par, a reasonable very rough guess for the PT amount (18 decimals) might be around 1e18. Let's widen
        the approximation bounds significantly.*/
        ApproxParams memory guessPtOut =
            ApproxParams({guessMin: 1, guessMax: 1e24, guessOffchain: 1e18, maxIteration: 30, eps: 10_000_000_000_000});

        pendleTxData = abi.encodeWithSelector(
            IPendleRouterV4.swapExactTokenForPt.selector, _receiver, _market, _minPtOut, guessPtOut, input, limit
        );
    }

    function _createPendleRedeemHookData(
        uint256 amount,
        address yt,
        address pt,
        address tokenOut,
        address tokenRedeemSy,
        uint256 minTokenOut,
        bool usePrevHookAmount
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            amount,
            yt,
            pt,
            tokenOut,
            minTokenOut,
            usePrevHookAmount,
            abi.encode(_createPendleRedeemTokenOutput(tokenOut, minTokenOut, tokenRedeemSy))
        );
    }

    function _createPendleRedeemTokenOutput(address tokenOut, uint256 minTokenOut, address tokenRedeemSy)
        internal
        pure
        returns (TokenOutput memory)
    {
        return TokenOutput({
            tokenOut: tokenOut,
            minTokenOut: minTokenOut,
            tokenRedeemSy: tokenRedeemSy,
            pendleSwap: address(0),
            swapData: SwapData({swapType: SwapType.NONE, extRouter: address(0), extCalldata: bytes(""), needScale: false})
        });
    }

    function _createPendleRouterSwapHookDataWithOdos(
        address market,
        address account,
        bool usePrevHookAmount,
        uint256 value,
        bool ptToToken,
        uint256 amount,
        address tokenIn,
        address tokenMint
    ) internal returns (bytes memory) {
        bytes memory pendleTxData;
        if (!ptToToken) {
            // call Odos swapAPI to get the calldata
            // note, odos swap receiver has to be pendle router
            bytes memory odosCalldata = _createOdosSwapCalldataRequest(tokenIn, tokenMint, amount, CHAIN_1_PendleRouter);

            decodeOdosSwapCalldata(odosCalldata);

            pendleTxData = _createTokenToPtPendleTxDataWithOdos(
                market, account, tokenIn, 1, amount, tokenMint, odosCalldata, CHAIN_1_PendleSwap, CHAIN_1_ODOS_ROUTER
            );
        } else {
            //TODO: fill with the other
            revert("Not implemented");
        }
        return abi.encodePacked(
            /**
             * yieldSourceOracleId
             */
            bytes4(bytes("")),
            /**
             * yieldSource
             */
            market,
            usePrevHookAmount,
            value,
            pendleTxData
        );
    }

    function _createOdosSwapCalldataRequest(address _tokenIn, address _tokenOut, uint256 _amount, address _receiver)
        internal
        returns (bytes memory)
    {
        // get pathId
        QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
        inputTokens[0] = QuoteInputToken({tokenAddress: _tokenIn, amount: _amount});
        QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
        outputTokens[0] = QuoteOutputToken({tokenAddress: _tokenOut, proportion: 1});
        string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, _receiver, ETH, true);

        // get assemble data
        string memory swapCompactData = surlCallAssemble(pathId, _receiver);
        return fromHex(swapCompactData);
    }
}
