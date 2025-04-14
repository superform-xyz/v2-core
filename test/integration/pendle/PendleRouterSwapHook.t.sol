// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

// Tests
import { BaseTest } from "../../BaseTest.t.sol";
import { console2 } from "forge-std/console2.sol";


import { ISuperExecutor } from "../../../src/core/interfaces/ISuperExecutor.sol";
import "../../../src/vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../src/vendor/pendle/IPendleMarket.sol";
import { IOdosRouterV2 } from "../../../src/vendor/odos/IOdosRouterV2.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { OdosAPIParser } from "../../utils/parsers/OdosAPIParser.sol";

import { UserOpData, AccountInstance } from "modulekit/ModuleKit.sol";


contract PendleRouterSwapHook is BaseTest, OdosAPIParser {
    ISuperExecutor public superExecutor;
    AccountInstance public instance;
    address public account;

    address public token;

    address public pendleMarket;
    address public pendleSwap;
    address public odosRouter;

    function setUp() public override {
        super.setUp();

        vm.selectFork(FORKS[ETH]);

        superExecutor = ISuperExecutor(_getContract(ETH, SUPER_EXECUTOR_KEY));
        instance = accountInstances[ETH];
        account = instance.account;

        token = CHAIN_1_USDC;
        pendleMarket = CHAIN_1_PendleDefaultMarket;
        pendleSwap = CHAIN_1_PendleSwap;
        odosRouter = CHAIN_1_ODOS_ROUTER;
    }

    /**
        // tx example: https://etherscan.io/tx/0x36b2c58e314e9d9bf73fc0d632ed228e35cd6b840066d12d39f72c633bad27a5
        function test_PendleRouterSwap_Token_To_Pt() public {
            uint256 amount = 1e12;

            // get tokens
            deal(token, account, amount);

            address[] memory hookAddresses = new address[](2);
            hookAddresses[0] = _getHookAddress(ETH, APPROVE_ERC20_HOOK_KEY);
            hookAddresses[1] = _getHookAddress(ETH, PENDLE_ROUTER_SWAP_HOOK_KEY);

            bytes[] memory hookData = new bytes[](2);
            hookData[0] = _createApproveHookData(token, CHAIN_1_PendleRouter, amount, false);
            hookData[1] = _createPendleRouterSwapHookDataWithOdos(false, 1 ether, false, amount, CHAIN_1_USDC, CHAIN_1_cUSDO);

            ISuperExecutor.ExecutorEntry memory entryToExecute =
                    ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookData });
            UserOpData memory opData = _getExecOps(
                    instance,
                    superExecutor,
                    abi.encode(entryToExecute),
                    _getContract(ETH, SUPER_NATIVE_PAYMASTER_KEY)
            );
            opData.userOp.paymasterAndData = bytes("");

            executeOp(opData);

                IPendleMarket _market = IPendleMarket(CHAIN_1_PendleDefaultMarket);
                (,address pt,) = _market.readTokens();

                uint256 balance = IERC20(pt).balanceOf(account);
                assertGt(balance, 0);

        }
    */

    //TODO: Move this to BaseTest
    function _createOdosSwapCalldataRequest(address _tokenIn, address _tokenOut, uint256 _amount, address _receiver) internal returns (bytes memory) {
         // get pathId
        QuoteInputToken[] memory inputTokens = new QuoteInputToken[](1);
        inputTokens[0] = QuoteInputToken({ tokenAddress: _tokenIn, amount: _amount });
        QuoteOutputToken[] memory outputTokens = new QuoteOutputToken[](1);
        outputTokens[0] = QuoteOutputToken({ tokenAddress: _tokenOut, proportion: 1 });
        string memory pathId = surlCallQuoteV2(inputTokens, outputTokens, _receiver, ETH, true);

        // get assemble data
        string memory swapCompactData = surlCallAssemble(pathId, _receiver);
        return fromHex(swapCompactData);
    }

    //TODO: Move this to BaseTest
    function _createPendleRouterSwapHookDataWithOdos(bool usePrevHookAmount, uint256 value, bool ptToToken, uint256 amount, address tokenIn, address tokenMint) internal returns (bytes memory) {
        bytes memory pendleTxData;
        if (!ptToToken) {
            // call Odos swapAPI to get the calldata
            bytes memory odosCalldata = _createOdosSwapCalldataRequest(tokenIn, tokenMint, amount, account);
            pendleTxData = _createTokenToPtPendleTxDataWithOdos(pendleMarket, account, tokenIn, 1, amount, tokenMint, odosCalldata);
        } else {
            //TODO: fill with the other 
            revert("Not implemented");
        }
        return abi.encodePacked(usePrevHookAmount, value, pendleTxData);
    }

    //TODO: Move this to BaseTest
    function _createTokenToPtPendleTxDataWithOdos(address _market, address _receiver, address _tokenIn, uint256 _minPtOut, uint256 _amount, address _tokenMintSY, bytes memory _odosCalldata) internal view returns (bytes memory pendleTxData) {
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
            tokenMintSy: _tokenMintSY,//CHAIN_1_cUSDO,
            pendleSwap: pendleSwap,
            swapData: SwapData({
                extRouter: odosRouter,
                extCalldata: _odosCalldata,
                needScale: false,
                swapType: SwapType.ODOS
            })
        });

        ApproxParams memory guessPtOut = ApproxParams({
            guessMin: 1,
            guessMax: _amount * 2,
            guessOffchain: _amount,
            maxIteration: 30,
            eps: 10000000000000
        });

        pendleTxData = abi.encodeWithSelector(IPendleRouterV4.swapExactTokenForPt.selector, _receiver, _market, _minPtOut, guessPtOut, input, limit);
    }


    
    /**
    struct PendleRouterSwapHookData {
        bool ptToToken;
        uint256 value;
        bool usePrevHookAmount;

        // pendle router swap params token to PT
        address receiver;
        address market;
        uint256 minPtOut;
        ApproxParams guessPtOut;
        TokenInput input;
        LimitOrderData limit;
    }

    function _createExtCallDataOdos(address _account, uint256 _amount) internal view returns (bytes memory) {
        (,address pt,) = IPendleMarket(CHAIN_1_PendleDefaultMarket).readTokens();
        IOdosRouterV2.swapTokenInfo memory swapTokenInfo = _createOdosSwap(
            CHAIN_1_USDC, //inputToken
            _amount, //inputAmount
            _account, //inputReceiver
            pt, //outputToken
            1, //outputQuote
            1, //outputMin
            _account //outputReceiver
        );
        return abi.encodeWithSelector(
            IOdosRouterV2.swap.selector,
            swapTokenInfo,
            hex"020203000701010102423a1323c871abc9d89eb06855bf5347048fc4a5000000000000000000000496ff00000000000000000000000000000000000000000000af88d065e77c8cc2239327c5edb3a432268e5831da10009cbd5d07dd0cecc66161fc93d7c9000da1", // path definition; what?
            0xfb2139331532e3ee59777FBbcB14aF674f3fd671, // executor? what ? TODO: determinet this?
            0
        );
    }
    */
}



