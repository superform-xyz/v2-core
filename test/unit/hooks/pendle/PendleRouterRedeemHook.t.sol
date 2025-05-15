// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Helpers } from "../../../utils/Helpers.sol";
import { PendleRouterRedeemHook } from "../../../../src/core/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
import { IPendleRouterV4, TokenOutput, SwapData, SwapType } from "../../../../src/vendor/pendle/IPendleRouterV4.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";

contract PendleRouterRedeemHookTest is Helpers {
    PendleRouterRedeemHook public hook;
    address public pendleRouter;
    MockHook public prevHook;
    MockERC20 public tokenOut;
    MockERC20 public ytToken;
    MockERC20 public ptToken;

    address public account;
    uint256 public amount = 1500;
    uint256 public minTokenOut = 1000;

    function setUp() public {
        account = address(this);

        pendleRouter = CHAIN_1_PendleRouter;
        tokenOut = new MockERC20("Output Token", "OUT", 18);
        vm.label(address(tokenOut), "Output Token");

        ytToken = new MockERC20("YT Token", "YT", 18);
        vm.label(address(ytToken), "YT Token");

        ptToken = new MockERC20("PT Token", "PT", 18);
        vm.label(address(ptToken), "PT Token");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(tokenOut));
        hook = new PendleRouterRedeemHook(pendleRouter);
    }

    function test_Constructor() public view {
        assertEq(address(hook.pendleRouterV4()), address(pendleRouter));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new PendleRouterRedeemHook(address(0));
    }

    function test_Build() public view {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
        assertEq(executions[0].target, address(ptToken));
        assertEq(executions[0].value, 0);
        assertEq(executions[1].target, address(ytToken));
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(pendleRouter));
        assertEq(executions[2].value, 0);

        SwapData memory swapData =
            SwapData({ swapType: SwapType.ODOS, extRouter: address(0), extCalldata: "", needScale: false });

        // Verify the calldata is correctly constructed
        bytes memory expectedCallData = abi.encodeWithSelector(
            IPendleRouterV4.redeemPyToToken.selector,
            account,
            address(ytToken),
            amount,
            TokenOutput({
                tokenOut: address(tokenOut),
                minTokenOut: minTokenOut,
                tokenRedeemSy: address(0),
                pendleSwap: address(0),
                swapData: swapData
            })
        );
        assertEq(executions[2].callData, expectedCallData);
    }

    function test_Build_WithPrevHookAmount() public {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, true);

        prevHook.setOutAmount(2500); // Set a different amount in the previous hook

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);

        SwapData memory swapData =
            SwapData({ swapType: SwapType.ODOS, extRouter: address(0), extCalldata: "", needScale: false });

        // Verify the calldata is correctly constructed
        bytes memory expectedCallData = abi.encodeWithSelector(
            IPendleRouterV4.redeemPyToToken.selector,
            account,
            address(ytToken),
            2500,
            TokenOutput({
                tokenOut: address(tokenOut),
                minTokenOut: minTokenOut,
                tokenRedeemSy: address(0),
                pendleSwap: address(0),
                swapData: swapData
            })
        );

        assertEq(executions[2].callData, expectedCallData);
    }

    function test_PreExecute() public {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);

        tokenOut.mint(account, 500);
        hook.preExecute(address(0), account, data);
        assertEq(hook.outAmount(), 500);
    }

    function test_PostExecute() public {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);

        tokenOut.mint(account, 500);
        hook.preExecute(address(0), account, data);

        tokenOut.mint(account, 300);
        hook.postExecute(address(0), account, data);
        assertEq(hook.outAmount(), 300);
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data = _createRedeemData(1000, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, true);
        assertTrue(hook.decodeUsePrevHookAmount(data));

        data = _createRedeemData(1000, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_Build_RevertIf_InvalidYT() public {
        bytes memory data = _createRedeemData(
            amount,
            address(0), // Invalid YT address
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            false
        );

        vm.expectRevert(PendleRouterRedeemHook.YT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidTokenOut() public {
        bytes memory data = _createRedeemData(
            amount,
            address(ytToken),
            address(ptToken),
            address(0), // Invalid token out address
            minTokenOut,
            false
        );

        vm.expectRevert(PendleRouterRedeemHook.TOKEN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidMinTokenOut() public {
        bytes memory data = _createRedeemData(
            amount,
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            0, // Invalid min token out
            false
        );

        vm.expectRevert(PendleRouterRedeemHook.MIN_TOKEN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_InvalidAmount() public {
        bytes memory data = _createRedeemData(
            0, // Invalid amount
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            false
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_DecodeUsePrevHookAmount() public view {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, true);

        bool usePrevHookAmount = hook.decodeUsePrevHookAmount(data);
        assertTrue(usePrevHookAmount);

        data = _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);

        usePrevHookAmount = hook.decodeUsePrevHookAmount(data);
        assertFalse(usePrevHookAmount);
    }

    function _createRedeemData(
        uint256 amount_,
        address yt_,
        address pt_,
        address tokenOut_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        // mocking purposes
        SwapData memory swapData =
            SwapData({ swapType: SwapType.ODOS, extRouter: address(0), extCalldata: "", needScale: false });
        bytes memory tokenOutput = abi.encode(
            TokenOutput({
                tokenOut: tokenOut_,
                minTokenOut: minTokenOut_,
                tokenRedeemSy: address(0),
                pendleSwap: address(0),
                swapData: swapData
            })
        );
        return abi.encodePacked(amount_, yt_, pt_, tokenOut_, minTokenOut_, usePrevHookAmount_, tokenOutput);
    }
}
