// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { BaseTest } from "../../../BaseTest.t.sol";
import { PendleRouterRedeemHook } from "../../../../src/core/hooks/pendle/PendleRouterRedeemHook.sol";
import { IPendleRouterV4, TokenOutput } from "../../../../src/vendor/pendle/IPendleRouterV4.sol";
import { MockERC20 } from "../../../mocks/MockERC20.sol";
import { MockHook } from "../../../mocks/MockHook.sol";
import { MockPendleRouter } from "../../../mocks/MockPendleRouter.sol";
import { ISuperHook } from "../../../../src/core/interfaces/ISuperHook.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { BaseHook } from "../../../../src/core/hooks/BaseHook.sol";
import { BytesLib } from "../../../../src/vendor/BytesLib.sol";

contract PendleRouterRedeemHookTest is BaseTest {
    PendleRouterRedeemHook public hook;
    MockPendleRouter public pendleRouter;
    MockHook public prevHook;
    MockERC20 public tokenOut;
    MockERC20 public ytToken;

    address public account;
    address public receiver;
    uint256 public amount = 1500;
    uint256 public minTokenOut = 1000;

    function setUp() public override {
        super.setUp();
        vm.selectFork(FORKS[ETH]);

        account = address(this);
        receiver = account;

        pendleRouter = new MockPendleRouter();
        tokenOut = new MockERC20("Output Token", "OUT", 18);
        vm.label(address(tokenOut), "Output Token");

        ytToken = new MockERC20("YT Token", "YT", 18);
        vm.label(address(ytToken), "YT Token");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, address(tokenOut));
        hook = new PendleRouterRedeemHook(address(pendleRouter));
    }

    function test_Constructor() public view {
        assertEq(address(hook.pendleRouterV4()), address(pendleRouter));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new PendleRouterRedeemHook(address(0));
    }

    function test_Build() public {
        bytes memory data = _createRedeemData(amount, receiver, address(ytToken), address(tokenOut), minTokenOut, false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(pendleRouter));
        assertEq(executions[0].value, 0);

        // Verify the calldata is correctly constructed
        bytes memory expectedCallData = abi.encodeWithSelector(
            IPendleRouterV4.redeemPyToToken.selector,
            receiver,
            address(ytToken),
            amount,
            pendleRouter.createTokenOutputSimple(address(tokenOut), minTokenOut)
        );
        assertEq(executions[0].callData, expectedCallData);
    }

    function test_Build_WithPrevHookAmount() public {
        bytes memory data = _createRedeemData(
            amount,
            receiver,
            address(ytToken),
            address(tokenOut),
            minTokenOut,
            true // Use previous hook amount
        );

        prevHook.setOutAmount(2500); // Set a different amount in the previous hook

        Execution[] memory executions = hook.build(address(prevHook), account, data);
        assertEq(executions.length, 1);

        // Verify the calldata uses the previous hook amount
        bytes memory expectedCallData = abi.encodeWithSelector(
            IPendleRouterV4.redeemPyToToken.selector,
            receiver,
            address(ytToken),
            2500, // Should use this amount instead of the original amount
            pendleRouter.createTokenOutputSimple(address(tokenOut), minTokenOut)
        );
        assertEq(executions[0].callData, expectedCallData);
    }

    function test_PreExecute() public {
        bytes memory data = _createRedeemData(amount, receiver, address(ytToken), address(tokenOut), minTokenOut, false);

        tokenOut.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);
        assertEq(hook.outAmount(), 500);
    }

    function test_PostExecute() public {
        bytes memory data = _createRedeemData(amount, receiver, address(ytToken), address(tokenOut), minTokenOut, false);

        tokenOut.mint(receiver, 500);
        hook.preExecute(address(0), receiver, data);

        tokenOut.mint(receiver, 300);
        hook.postExecute(address(0), receiver, data);
        assertEq(hook.outAmount(), 300);
    }

    function test_Build_RevertIf_InvalidYT() public {
        bytes memory data = _createRedeemData(
            amount,
            receiver,
            address(0), // Invalid YT address
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
            receiver,
            address(ytToken),
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
            receiver,
            address(ytToken),
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
            receiver,
            address(ytToken),
            address(tokenOut),
            minTokenOut,
            false
        );

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        hook.build(address(prevHook), account, data);
    }

    function test_DecodeUsePrevHookAmount() public {
        bytes memory data = _createRedeemData(amount, receiver, address(ytToken), address(tokenOut), minTokenOut, true);

        bool usePrevHookAmount = hook.decodeUsePrevHookAmount(data);
        assertTrue(usePrevHookAmount);

        data = _createRedeemData(amount, receiver, address(ytToken), address(tokenOut), minTokenOut, false);

        usePrevHookAmount = hook.decodeUsePrevHookAmount(data);
        assertFalse(usePrevHookAmount);
    }

    function _createRedeemData(
        uint256 amount_,
        address receiver_,
        address yt_,
        address tokenOut_,
        uint256 minTokenOut_,
        bool usePrevHookAmount_
    )
        internal
        pure
        returns (bytes memory)
    {
        bytes memory data = new bytes(125); // Total size needed for all fields

        // Pack the data according to the contract's expected format
        uint256 ptr;
        assembly {
            ptr := add(data, 32)
        }

        BytesLib.writeUint256(ptr, 0, amount_);
        BytesLib.writeAddress(ptr, 32, receiver_);
        BytesLib.writeAddress(ptr, 52, yt_);
        BytesLib.writeAddress(ptr, 72, tokenOut_);
        BytesLib.writeUint256(ptr, 92, minTokenOut_);
        BytesLib.writeBool(ptr, 124, usePrevHookAmount_);

        return data;
    }
}
