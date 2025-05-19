// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {SwapOdosHook} from "../../../../../src/core/hooks/swappers/odos/SwapOdosHook.sol";
import {ApproveAndSwapOdosHook} from "../../../../../src/core/hooks/swappers/odos/ApproveAndSwapOdosHook.sol";
import {ISuperHook} from "../../../../../src/core/interfaces/ISuperHook.sol";
import {MockERC20} from "../../../../mocks/MockERC20.sol";
import {MockHook} from "../../../../mocks/MockHook.sol";
import {BaseHook} from "../../../../../src/core/hooks/BaseHook.sol";
import {IOdosRouterV2} from "../../../../../src/vendor/odos/IOdosRouterV2.sol";
import {Helpers} from "../../../../utils/Helpers.sol";

contract MockOdosRouter is IOdosRouterV2 {
    function swap(swapTokenInfo calldata, bytes calldata, address, uint32)
        external
        payable
        override
        returns (uint256 outputAmount)
    {
        return 0;
    }

    function swapPermit2(permit2Info memory, swapTokenInfo memory, bytes calldata, address, uint32)
        external
        pure
        override
        returns (uint256 amountOut)
    {
        return 0;
    }

    function swapCompact() external payable override returns (uint256) {
        return 0;
    }
}

contract ApproveAndSwapOdosHookTest is Helpers {
    ApproveAndSwapOdosHook public approveAndSwapOdosHook;
    SwapOdosHook public swapOdosHook;
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

    receive() external payable {}

    function setUp() public {
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

        approveAndSwapOdosHook = new ApproveAndSwapOdosHook(address(odosRouter));
        swapOdosHook = new SwapOdosHook(address(odosRouter));
    }

    // ------------ ApproveAndSwapOdosHook --------------
    function test_Constructor() public view {
        assertEq(uint256(approveAndSwapOdosHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapOdosHook.odosRouterV2()), address(odosRouter));
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapOdosHook(address(0));
    }

    function test_DecodeUsePrevHookAmount() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        assertFalse(approveAndSwapOdosHook.decodeUsePrevHookAmount(data));

        data = _buildApproveAndSwapOdosData(true);
        assertTrue(approveAndSwapOdosHook.decodeUsePrevHookAmount(data));
    }

    function test_DecodeUsePrevHookSwapHook() public view {
        bytes memory data = _buildSwapOdosData(false);
        assertFalse(swapOdosHook.decodeUsePrevHookAmount(data));

        data = _buildSwapOdosData(true);
        assertTrue(swapOdosHook.decodeUsePrevHookAmount(data));
    }

    function test_Build() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 4);
        assertEq(executions[0].target, address(inputToken));
        assertEq(executions[0].value, 0);
        assertEq(executions[1].target, address(inputToken));
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(odosRouter));
        assertEq(executions[2].value, 0);
        assertEq(executions[3].target, address(inputToken));
        assertEq(executions[3].value, 0);
    }

    function test_Build_WithPrevHookAmount() public {
        bytes memory data = _buildApproveAndSwapOdosData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 4);
        assertEq(executions[0].target, address(inputToken));
        assertEq(executions[0].value, 0);
        assertEq(executions[1].target, address(inputToken));
        assertEq(executions[1].value, 0);
        assertEq(executions[2].target, address(odosRouter));
        assertEq(executions[2].value, 0);
        assertEq(executions[3].target, address(inputToken));
        assertEq(executions[3].value, 0);
    }

    function test_PreExecute() public {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapOdosHook.outAmount(), 500);
    }

    function test_PostExecute() public {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosHook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        approveAndSwapOdosHook.postExecute(address(0), account, data);

        assertEq(approveAndSwapOdosHook.outAmount(), 300);
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
            bytes20(address(0)),
            bytes32(testPathDefinition.length),
            testPathDefinition,
            bytes20(executor),
            bytes4(referralCode)
        );

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 4);
    }

    function test_BooleanDecoding_True() public {
        bytes memory data = _buildApproveAndSwapOdosData(true);

        prevHook.setOutAmount(2000);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 4);
    }

    function test_BooleanDecoding_False() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 4);
    }

    function test_ZeroValue() public view {
        bytes memory data = bytes.concat(
            bytes20(inputToken),
            bytes32(uint256(0)), // Zero input amount
            bytes20(inputReceiver),
            bytes20(outputToken),
            bytes32(outputQuote),
            bytes32(outputMin),
            bytes1(uint8(0)),
            bytes20(address(0)),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes4(referralCode)
        );

        Execution[] memory executions = approveAndSwapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 4);
    }

    function test_ApproveAndSwapOdosHook_inspect() public view {
        bytes memory data = _buildApproveAndSwapOdosData(false);
        bytes memory argsEncoded = approveAndSwapOdosHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function _buildApproveAndSwapOdosData(bool usePrevious) internal view returns (bytes memory) {
        bytes memory data = bytes.concat(
            bytes20(inputToken),
            bytes32(inputAmount),
            bytes20(inputReceiver),
            bytes20(outputToken),
            bytes32(outputQuote),
            bytes32(outputMin),
            usePrevious ? bytes1(uint8(1)) : bytes1(uint8(0)),
            bytes20(address(0)),
            bytes32(pathDefinition.length),
            pathDefinition,
            bytes20(executor),
            bytes4(referralCode)
        );

        return data;
    }

    // ------------ SwapOdosHook --------------
    function test_SwapOdosHook_Constructor() public view {
        assertEq(uint256(swapOdosHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapOdosHook.odosRouterV2()), address(odosRouter));
    }

    function test_SwapOdosHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapOdosHook(address(0));
    }

    function test_SwapOdosHook_decodeUsePrevHookAmount() public view {
        bytes memory data = _buildSwapOdosData(false);
        assertEq(swapOdosHook.decodeUsePrevHookAmount(data), false);

        data = _buildSwapOdosData(true);
        assertEq(swapOdosHook.decodeUsePrevHookAmount(data), true);
    }

    function test_SwapOdosHook_Build() public view {
        bytes memory data = _buildSwapOdosData(false);

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(odosRouter));
        assertEq(executions[0].value, 0);
    }

    function test_SwapOdosHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildSwapOdosData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount);

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
        assertEq(executions[0].target, address(odosRouter));
        assertEq(executions[0].value, 0);
    }

    function test_SwapOdosHook_PreExecute() public {
        bytes memory data = _buildSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        approveAndSwapOdosHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapOdosHook.outAmount(), 500);
    }

    function test_SwapOdosHook_PostExecute() public {
        bytes memory data = _buildSwapOdosData(false);

        MockERC20 outToken = MockERC20(outputToken);
        outToken.mint(account, 500);

        swapOdosHook.preExecute(address(0), account, data);

        outToken.mint(account, 300);

        swapOdosHook.postExecute(address(0), account, data);

        assertEq(swapOdosHook.outAmount(), 300);
    }

    function test_SwapOdosHook_BytesLengthDecoding() public view {
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

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_SwapOdosHook_BooleanDecoding_True() public {
        bytes memory data = _buildSwapOdosData(true);

        prevHook.setOutAmount(2000);

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_SwapOdosHook_booleanDecoding_False() public view {
        bytes memory data = _buildSwapOdosData(false);

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_SwapOdosHook_ZeroValue() public view {
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

        Execution[] memory executions = swapOdosHook.build(address(prevHook), account, data);

        assertEq(executions.length, 1);
    }

    function test_SwapOdosHook_inspect() public view {
        bytes memory data = _buildSwapOdosData(false);
        bytes memory argsEncoded = swapOdosHook.inspect(data);
        assertGt(argsEncoded.length, 0);
    }

    function _buildSwapOdosData(bool usePrevious) internal view returns (bytes memory) {
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
}
