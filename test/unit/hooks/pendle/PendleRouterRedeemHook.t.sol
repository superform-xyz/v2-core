// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Helpers } from "../../../utils/Helpers.sol";
import { PendleRouterRedeemHook } from "../../../../src/hooks/swappers/pendle/PendleRouterRedeemHook.sol";
import { IPendleRouterV4, TokenOutput, SwapData, SwapType } from "../../../../src/vendor/pendle/IPendleRouterV4.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockYieldToken } from "../../../mocks/MockYieldToken.sol";
import { MockStandardizedYield } from "../../../mocks/MockStandardizedYield.sol";
import { ISuperHook } from "../../../../src/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/hooks/BaseHook.sol";

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

        pendleRouter = CHAIN_1_PENDLE_ROUTER;
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
        assertEq(address(hook.PENDLE_ROUTER_V4()), address(pendleRouter));
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
        assertEq(executions.length, 5);
        assertEq(executions[1].target, address(ptToken));
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(ytToken));
        assertEq(executions[2].value, 0);
        assertEq(executions[3].target, address(pendleRouter));
        assertEq(executions[3].value, 0);

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
        assertEq(executions[3].callData, expectedCallData);
    }

    function test_Build_WithPrevHookAmountXQA() public {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, true);

        prevHook.setOutAmount(2500, address(this)); // Set a different amount in the previous hook

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);

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

        assertEq(executions[3].callData, expectedCallData);
    }

    function test_Inspect() public view {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);
        bytes memory argsEncoded = hook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function test_PreExecute() public {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);

        tokenOut.mint(account, 500);
        hook.preExecute(address(0), account, data);
        assertEq(hook.getOutAmount(address(this)), 500);
    }

    function test_PostExecute() public {
        bytes memory data =
            _createRedeemData(amount, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, false);

        tokenOut.mint(account, 500);
        hook.preExecute(address(0), account, data);

        tokenOut.mint(account, 300);
        hook.postExecute(address(0), account, data);
        assertEq(hook.getOutAmount(address(this)), 300);
    }

    function test_UsePrevHookAmount() public view {
        bytes memory data =
            _createRedeemData(1000, address(ytToken), address(ptToken), address(tokenOut), minTokenOut, true);
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

    function test_Build_RevertIf_InvalidDataLength() public {
        // Create data with length less than TOKEN_OUTPUT_OFFSET (125 bytes)
        // Data needs: amount(32) + yt(20) + pt(20) + tokenOut(20) + minTokenOut(32) + usePrevHookAmount(1) = 125 bytes minimum
        // Provide only 100 bytes to trigger the error
        bytes memory data = new bytes(100);

        vm.expectRevert(PendleRouterRedeemHook.INVALID_DATA_LENGTH.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_PreExecute_RevertIf_InvalidDataLength() public {
        // Create data with length less than endOfTokenOutOffset (92 bytes)
        // endOfTokenOutOffset = 72 (start of tokenOut) + 20 (size of address) = 92
        // Provide only 80 bytes to trigger the error in _getBalance
        bytes memory data = new bytes(80);

        vm.expectRevert(PendleRouterRedeemHook.INVALID_DATA_LENGTH.selector);
        hook.preExecute(address(0), account, data);
    }

    function test_PostExecute_RevertIf_InvalidDataLength() public {
        // Create data with length less than endOfTokenOutOffset (92 bytes)
        // Provide only 70 bytes to trigger the error in _getBalance
        bytes memory data = new bytes(70);

        vm.expectRevert(PendleRouterRedeemHook.INVALID_DATA_LENGTH.selector);
        hook.postExecute(address(0), account, data);
    }

    function test_Build_RevertIf_TokenOutMismatch() public {
        // Create a TokenOutput struct with a different tokenOut than the explicit parameter
        SwapData memory swapData =
            SwapData({ swapType: SwapType.ODOS, extRouter: address(0), extCalldata: "", needScale: false });
        
        TokenOutput memory output = TokenOutput({
            tokenOut: address(0x999), // Different from the explicit tokenOut parameter
            minTokenOut: minTokenOut,
            tokenRedeemSy: address(0),
            pendleSwap: address(0),
            swapData: swapData
        });

        bytes memory tokenOutputEncoded = abi.encode(output);
        
        // Pack the data with explicit tokenOut that differs from struct tokenOut
        bytes memory data = abi.encodePacked(
            amount,
            address(ytToken),
            address(ptToken),
            address(tokenOut), // Explicit parameter
            minTokenOut,
            bytes1(uint8(0)),
            tokenOutputEncoded
        );

        vm.expectRevert(PendleRouterRedeemHook.TOKEN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_MinTokenOutMismatch() public {
        // Create a TokenOutput struct with a different minTokenOut than the explicit parameter
        SwapData memory swapData =
            SwapData({ swapType: SwapType.ODOS, extRouter: address(0), extCalldata: "", needScale: false });
        
        TokenOutput memory output = TokenOutput({
            tokenOut: address(tokenOut),
            minTokenOut: 999, // Different from the explicit minTokenOut parameter
            tokenRedeemSy: address(0),
            pendleSwap: address(0),
            swapData: swapData
        });

        bytes memory tokenOutputEncoded = abi.encode(output);
        
        // Pack the data with explicit minTokenOut that differs from struct minTokenOut
        bytes memory data = abi.encodePacked(
            amount,
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            minTokenOut, // Explicit parameter
            bytes1(uint8(0)),
            tokenOutputEncoded
        );

        vm.expectRevert(PendleRouterRedeemHook.MIN_TOKEN_OUT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SuccessWithMatchingParams() public view {
        // Create a TokenOutput struct where tokenOut and minTokenOut match the explicit parameters
        bytes memory data = _createRedeemData(
            amount,
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            false
        );

        // Should successfully build executions when params match
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);
        assertEq(executions[3].target, pendleRouter);
    }

    function test_Build_RevertIf_PrevHookAmountZero() public {
        bytes memory data = _createRedeemData(
            amount,
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            true // usePrevHookAmount = true
        );

        // Set prevHook to return 0
        prevHook.setOutAmount(0, address(this));

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SuccessWithAmountFromData() public view {
        // Test the else branch where usePrevHookAmount = false and amountFromData is used
        bytes memory data = _createRedeemData(
            amount, // Valid amount from data
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            false // usePrevHookAmount = false
        );

        // Should successfully build executions using amount from data
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);
        assertEq(executions[3].target, pendleRouter);
    }

    function test_Build_SuccessWithAmountFromPrevHook() public {
        bytes memory data = _createRedeemData(
            amount,
            address(ytToken),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            true // usePrevHookAmount = true
        );

        // Set prevHook to return a valid amount
        prevHook.setOutAmount(5000, address(this));

        // Should successfully build executions using amount from prevHook
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);
        assertEq(executions[3].target, pendleRouter);
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

    function test_GetBalance_NativeTokenY() public {
        // Create redeem data with tokenOut as address(0) (native token)
        bytes memory data = _createRedeemData(
            amount,
            address(ytToken),
            address(ptToken),
            address(0), // Native token (address(0))
            minTokenOut,
            false
        );

        // Give the account some ETH balance to test the native token balance check
        vm.deal(account, 3 ether);

        // This should trigger _getBalance with tokenOut == address(0), returning receiver.balance
        hook.preExecute(address(0), account, data);

        // Verify that the hook captured the native token balance
        assertEq(hook.getOutAmount(address(this)), 3 ether);
    }

    function test_Build_RevertIf_SYCallFails() public {
        // Create a YT token where SY() call will fail
        MockYieldToken mockYT = new MockYieldToken("Mock YT", "MYT", 18);
        mockYT.setSYCallShouldFail(true);

        bytes memory data = _createRedeemData(
            amount,
            address(mockYT),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            false
        );

        vm.expectRevert(PendleRouterRedeemHook.SY_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_RevertIf_TokenOutNotListed() public {
        // Create SY contract that doesn't list the tokenOut
        MockStandardizedYield mockSY = new MockStandardizedYield(address(0), address(ptToken), address(0));
        
        // Create YT token pointing to this SY
        MockYieldToken mockYT = new MockYieldToken("Mock YT", "MYT", 18);
        mockYT.setSY(address(mockSY));

        // Create a token that won't be in the SY's tokensOut list
        MockERC20 invalidTokenOut = new MockERC20("Invalid Out", "INVOUT", 18);

        bytes memory data = _createRedeemData(
            amount,
            address(mockYT),
            address(ptToken),
            address(invalidTokenOut),
            minTokenOut,
            false
        );

        vm.expectRevert(PendleRouterRedeemHook.TOKEN_OUT_NOT_LISTED.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_Build_SuccessWithValidSYAndTokenOut() public {
        // Create SY contract with valid token list
        MockStandardizedYield mockSY = new MockStandardizedYield(address(tokenOut), address(ptToken), address(0));
        
        // Set tokenOut as valid in the SY
        address[] memory validTokensOut = new address[](1);
        validTokensOut[0] = address(tokenOut);
        mockSY.setTokensOut(validTokensOut);
        
        // Create YT token pointing to this SY
        MockYieldToken mockYT = new MockYieldToken("Mock YT", "MYT", 18);
        mockYT.setSY(address(mockSY));

        bytes memory data = _createRedeemData(
            amount,
            address(mockYT),
            address(ptToken),
            address(tokenOut),
            minTokenOut,
            false
        );

        // Should not revert
        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 5);
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
