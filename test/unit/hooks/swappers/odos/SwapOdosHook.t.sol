// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { MockSwapOdosHook } from "../../../../mocks/unused-hooks/MockSwapOdosHook.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { ISuperHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import { BytesLib } from "../../../../../src/vendor/BytesLib.sol";
import { IOdosRouterV2 } from "../../../../../src/vendor/odos/IOdosRouterV2.sol";
import { console2 } from "forge-std/console2.sol";

contract MockOdosRouter is IOdosRouterV2 {
    function swap(
        swapTokenInfo calldata,
        bytes calldata,
        address,
        uint32
    )
        external
        payable
        override
        returns (uint256 outputAmount)
    {
        return 0;
    }

    function swapPermit2(
        permit2Info memory,
        swapTokenInfo memory,
        bytes calldata,
        address,
        uint32
    )
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return 0;
    }

    function swapCompact()
        external
        payable
        override
        returns (uint256) {
            return 0;
    }
}

contract SwapOdosHookTest is BaseTest {
    MockSwapOdosHook public hook;
    MockOdosRouter public odosRouter;
    MockHook public prevHook;

    address inputToken;
    address outputToken;
    address inputReceiver;
    address account;

    uint256 inputAmount = 1000;
    uint256 outputQuote = 900;
    uint256 outputMin = 850;
    bytes pathDefinition;
    address executor;
    uint32 referralCode = 123;
    bool usePrevHookAmount;

    receive() external payable { }

    function setUp() public override {
        super.setUp();

        account = address(this);
        executor = makeAddr("executor");
        inputReceiver = makeAddr("inputReceiver");

        odosRouter = new MockOdosRouter();

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        inputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        outputToken = address(_outputToken);

        pathDefinition = abi.encode("mock_path_definition");

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, inputToken);

        hook = new MockSwapOdosHook(address(this), address(odosRouter));
    }

    function test_Constructor() public view {
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(hook.odosRouterV2()), address(odosRouter));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new MockSwapOdosHook(address(this), address(0));
    }

    function _buildData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory data = bytes.concat(
            bytes20(inputToken),
            bytes32(inputAmount),
            bytes20(inputReceiver),
            bytes20(outputToken),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes4(referralCode)
        );

        return data;
    }

    function test_Build() public view {
        bytes memory data = _buildData(false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(odosRouter));
        assertEq(executions[0].value, 0);
    }

    function test_Build_WithPrevHookAmount() public {
        bytes memory data = _buildData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(odosRouter));
        assertEq(executions[0].value, 0);
    }

    function test_PreExecute() public {
        bytes memory data = _buildData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        hook.preExecute(address(0), account, data);

        assertEq(hook.outAmount(), 500);
    }

    function test_PostExecute() public {
        bytes memory data = _buildData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        hook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        hook.postExecute(address(0), account, data);

        assertEq(hook.outAmount(), 300);
    }

    function test_BytesLengthDecoding() public view {
        bytes memory testPathDefinition = abi.encode("test_path_longer_than_before");

        bytes memory data = bytes.concat(
            bytes20(inputToken),
            bytes32(inputAmount),
            bytes20(inputReceiver),
            bytes20(outputToken),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(testPathDefinition.length),
            testPathDefinition,
            bytes20(executor),
            bytes4(referralCode)
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_BooleanDecoding_True() public {
        bytes memory data = _buildData(true);

        prevHook.setOutAmount(2000);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_BooleanDecoding_False() public view {
        bytes memory data = _buildData(false);

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_ZeroValue() public view {
        bytes memory data = bytes.concat(
            bytes20(inputToken),
            bytes32(0), // Zero input amount
            bytes20(inputReceiver),
            bytes20(outputToken),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes4(referralCode)
        );

        Execution[] memory executions = hook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }
}
