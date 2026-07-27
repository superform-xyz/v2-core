// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import {
    ApproveAndSwapAerodromeUniversalRouterHook
} from "../../../src/hooks/swappers/aerodrome/ApproveAndSwapAerodromeUniversalRouterHook.sol";
import {
    SwapAerodromeUniversalRouterHook
} from "../../../src/hooks/swappers/aerodrome/SwapAerodromeUniversalRouterHook.sol";
import { ISuperHookSwap } from "../../../src/interfaces/ISuperHookSwap.sol";
import { HookDataUpdater } from "../../../src/libraries/HookDataUpdater.sol";
import { BytesLib } from "../../../src/vendor/BytesLib.sol";

interface IAerodromeRouterImmutables {
    function WETH9() external view returns (address);
    function PERMIT2() external view returns (address);
}

interface IPermit2Allowance {
    function allowance(
        address owner,
        address token,
        address spender
    )
        external
        view
        returns (uint160 amount, uint48 expiration, uint48 nonce);
}

contract AerodromeForkPreviousResult {
    address private outputToken;
    uint256 private outputAmount;

    function setResult(address outputToken_, uint256 outputAmount_) external {
        outputToken = outputToken_;
        outputAmount = outputAmount_;
    }

    function getOutToken(address) external view returns (address) {
        return outputToken;
    }

    function getOutAmount(address) external view returns (uint256) {
        return outputAmount;
    }
}

/// @notice Pinned Base execution proof for the Aerodrome Universal Router hooks.
contract AerodromeUniversalRouterHookForkTest is Test {
    using BytesLib for bytes;

    struct SwapFixture {
        uint8 routeKind;
        bytes path;
        address inputToken;
        address outputToken;
        uint256 amountIn;
        uint256 amountOutMin;
    }

    uint256 private constant FORK_BLOCK = 48_707_812;

    address private constant ROUTER = 0xcAF22ce31298CF2BF1D152862F80216478ad7c67;
    bytes32 private constant ROUTER_RUNTIME_HASH = 0xa11d1a13950f5b70dd0d7822e4e3b575778d8614e897c7810d7e6e9f310c017d;

    address private constant WETH = 0x4200000000000000000000000000000000000006;
    address private constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address private constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address private constant ROUTER_PERMIT2 = 0x494bbD8A3302AcA833D307D11838f18DbAdA9C25;

    uint8 private constant CLASSIC = 0;
    uint8 private constant SLIPSTREAM = 1;

    uint24 private constant PRIMARY_CL_TICK_50 = 50;
    uint24 private constant FACTORY_2_CL_TICK_10 = 0x10000a;
    uint24 private constant FACTORY_3_CL_TICK_10 = 0x08000a;

    SwapAerodromeUniversalRouterHook private swapHook;
    ApproveAndSwapAerodromeUniversalRouterHook private approveAndSwapHook;
    AerodromeForkPreviousResult private previousResult;

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK);

        swapHook = new SwapAerodromeUniversalRouterHook(ROUTER);
        approveAndSwapHook = new ApproveAndSwapAerodromeUniversalRouterHook(ROUTER);
        previousResult = new AerodromeForkPreviousResult();
    }

    function test_RouterRuntimeAndPublicImmutables() public view {
        assertGt(ROUTER.code.length, 0);
        assertEq(ROUTER.codehash, ROUTER_RUNTIME_HASH);
        assertEq(IAerodromeRouterImmutables(ROUTER).WETH9(), WETH);
        assertEq(IAerodromeRouterImmutables(ROUTER).PERMIT2(), ROUTER_PERMIT2);
    }

    function test_ApproveAndSwap_ClassicVolatile() public {
        _assertApproveAndSwap(
            SwapFixture(CLASSIC, abi.encodePacked(WETH, bytes1(0), USDC), WETH, USDC, 0.001 ether, 1e6)
        );
    }

    function test_ApproveAndSwap_ClassicStable() public {
        _assertApproveAndSwap(
            SwapFixture(CLASSIC, abi.encodePacked(DAI, bytes1(uint8(1)), USDC), DAI, USDC, 1 ether, 800_000)
        );
    }

    function test_ApproveAndSwap_PrimaryCLFactory() public {
        _assertApproveAndSwap(
            SwapFixture(SLIPSTREAM, abi.encodePacked(WETH, PRIMARY_CL_TICK_50, USDC), WETH, USDC, 0.001 ether, 1e6)
        );
    }

    function test_ApproveAndSwap_SecondCLFactory() public {
        _assertApproveAndSwap(
            SwapFixture(SLIPSTREAM, abi.encodePacked(WETH, FACTORY_2_CL_TICK_10, USDC), WETH, USDC, 0.001 ether, 1e6)
        );
    }

    function test_ApproveAndSwap_LatestCLFactory() public {
        _assertApproveAndSwap(
            SwapFixture(SLIPSTREAM, abi.encodePacked(WETH, FACTORY_3_CL_TICK_10, USDC), WETH, USDC, 0.001 ether, 1e6)
        );
    }

    function test_SwapOnly_ClassicWithDirectRouterApproval() public {
        _assertSwapOnly(SwapFixture(CLASSIC, abi.encodePacked(WETH, bytes1(0), USDC), WETH, USDC, 0.001 ether, 1e6));
    }

    function test_SwapOnly_CLWithDirectRouterApproval() public {
        _assertSwapOnly(
            SwapFixture(SLIPSTREAM, abi.encodePacked(WETH, FACTORY_3_CL_TICK_10, USDC), WETH, USDC, 0.001 ether, 1e6)
        );
    }

    function test_ApproveAndSwap_UsesPreviousHookAmountAndScaledMinimum() public {
        uint256 originalAmount = 0.002 ether;
        uint256 effectiveAmount = 0.001 ether;
        uint256 originalMinimum = 2e6;
        uint256 effectiveMinimum =
            HookDataUpdater.getUpdatedOutputAmount(effectiveAmount, originalAmount, originalMinimum);
        bytes memory path = abi.encodePacked(WETH, PRIMARY_CL_TICK_50, USDC);

        previousResult.setResult(WETH, effectiveAmount);
        deal(WETH, address(this), effectiveAmount);

        bytes memory data = _encodeData(
            approveAndSwapHook,
            WETH,
            USDC,
            originalAmount,
            3e6,
            originalMinimum,
            true,
            abi.encode(SLIPSTREAM, block.timestamp + 1 hours, path)
        );
        Execution[] memory executions = approveAndSwapHook.build(address(previousResult), address(this), data);
        (, bytes[] memory inputs,) = _decodeExecute(executions[3].callData);
        _assertRouterInput(inputs[0], effectiveAmount, effectiveMinimum, path);

        uint256 outputBefore = IERC20(USDC).balanceOf(address(this));
        uint256 routerInputBefore = IERC20(WETH).balanceOf(ROUTER);
        _execute(executions);
        uint256 outputDelta = IERC20(USDC).balanceOf(address(this)) - outputBefore;

        assertEq(IERC20(WETH).balanceOf(address(this)), 0);
        assertEq(IERC20(WETH).balanceOf(ROUTER), routerInputBefore);
        assertGe(outputDelta, effectiveMinimum);
        assertEq(approveAndSwapHook.getOutAmount(address(this)), outputDelta);
        assertEq(approveAndSwapHook.getOutToken(address(this)), USDC);
        assertEq(IERC20(WETH).allowance(address(this), ROUTER), 0);
        _assertNoPermit2Allowance(WETH);
    }

    function _assertApproveAndSwap(SwapFixture memory fixture) private {
        deal(fixture.inputToken, address(this), fixture.amountIn);
        uint256 outputBefore = IERC20(fixture.outputToken).balanceOf(address(this));
        uint256 routerInputBefore = IERC20(fixture.inputToken).balanceOf(ROUTER);

        bytes memory data = _encodeData(
            approveAndSwapHook,
            fixture.inputToken,
            fixture.outputToken,
            fixture.amountIn,
            fixture.amountOutMin,
            fixture.amountOutMin,
            false,
            abi.encode(fixture.routeKind, block.timestamp + 1 hours, fixture.path)
        );
        Execution[] memory executions = approveAndSwapHook.build(address(0), address(this), data);
        assertEq(executions.length, 6);
        _execute(executions);

        uint256 outputDelta = IERC20(fixture.outputToken).balanceOf(address(this)) - outputBefore;
        assertEq(IERC20(fixture.inputToken).balanceOf(address(this)), 0);
        assertEq(IERC20(fixture.inputToken).balanceOf(ROUTER), routerInputBefore);
        assertGe(outputDelta, fixture.amountOutMin);
        assertEq(approveAndSwapHook.getOutAmount(address(this)), outputDelta);
        assertEq(approveAndSwapHook.getOutToken(address(this)), fixture.outputToken);
        assertEq(IERC20(fixture.inputToken).allowance(address(this), ROUTER), 0);
        _assertNoPermit2Allowance(fixture.inputToken);
    }

    function _assertSwapOnly(SwapFixture memory fixture) private {
        deal(fixture.inputToken, address(this), fixture.amountIn);
        IERC20(fixture.inputToken).approve(ROUTER, fixture.amountIn);
        uint256 outputBefore = IERC20(fixture.outputToken).balanceOf(address(this));
        uint256 routerInputBefore = IERC20(fixture.inputToken).balanceOf(ROUTER);

        bytes memory data = _encodeData(
            swapHook,
            fixture.inputToken,
            fixture.outputToken,
            fixture.amountIn,
            fixture.amountOutMin,
            fixture.amountOutMin,
            false,
            abi.encode(fixture.routeKind, block.timestamp + 1 hours, fixture.path)
        );
        Execution[] memory executions = swapHook.build(address(0), address(this), data);
        assertEq(executions.length, 3);
        _execute(executions);

        uint256 outputDelta = IERC20(fixture.outputToken).balanceOf(address(this)) - outputBefore;
        assertEq(IERC20(fixture.inputToken).balanceOf(address(this)), 0);
        assertEq(IERC20(fixture.inputToken).balanceOf(ROUTER), routerInputBefore);
        assertGe(outputDelta, fixture.amountOutMin);
        assertEq(swapHook.getOutAmount(address(this)), outputDelta);
        assertEq(swapHook.getOutToken(address(this)), fixture.outputToken);
        assertEq(IERC20(fixture.inputToken).allowance(address(this), ROUTER), 0);
        _assertNoPermit2Allowance(fixture.inputToken);
    }

    function _assertNoPermit2Allowance(address token) private view {
        assertEq(IERC20(token).allowance(address(this), ROUTER_PERMIT2), 0);
        (uint160 amount, uint48 expiration, uint48 nonce) =
            IPermit2Allowance(ROUTER_PERMIT2).allowance(address(this), token, ROUTER);
        assertEq(amount, 0);
        assertEq(expiration, 0);
        assertEq(nonce, 0);
    }

    function _encodeData(
        ISuperHookSwap hook,
        address input,
        address output,
        uint256 amount,
        uint256 quote,
        uint256 minimum,
        bool usePrevious,
        bytes memory payload
    )
        private
        pure
        returns (bytes memory)
    {
        return hook.encodeSwapData(
            ISuperHookSwap.SwapHeader({
                inputToken: input,
                outputToken: output,
                inputAmount: amount,
                outputQuote: quote,
                outputMin: minimum,
                usePrevHookAmount: usePrevious
            }),
            payload
        );
    }

    function _decodeExecute(bytes memory callData)
        private
        pure
        returns (bytes memory commands, bytes[] memory inputs, uint256 deadline)
    {
        return abi.decode(callData.slice(4, callData.length - 4), (bytes, bytes[], uint256));
    }

    function _assertRouterInput(
        bytes memory input,
        uint256 expectedAmount,
        uint256 expectedMinimum,
        bytes memory expectedPath
    )
        private
        view
    {
        (address recipient, uint256 amount, uint256 minimum, bytes memory path, bool payerIsUser, bool isUni) =
            abi.decode(input, (address, uint256, uint256, bytes, bool, bool));
        assertEq(recipient, address(this));
        assertEq(amount, expectedAmount);
        assertEq(minimum, expectedMinimum);
        assertEq(path, expectedPath);
        assertTrue(payerIsUser);
        assertFalse(isUni);
    }

    function _execute(Execution[] memory executions) private {
        for (uint256 i; i < executions.length; ++i) {
            (bool success, bytes memory returnData) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(returnData, 0x20), mload(returnData))
                }
            }
        }
    }
}
