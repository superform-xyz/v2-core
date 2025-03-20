// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { Swap1InchHook } from "../../../../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import { BaseTest } from "../../../../BaseTest.t.sol";
import { ISuperHook, ISuperHookResult } from "../../../../../src/core/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/core/hooks/BaseHook.sol";
import "../../../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import { console2 } from "forge-std/console2.sol";


contract MockUniswapPair {
    address public token0;
    address public token1;
    
    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }
}

contract Swap1InchHookTest is BaseTest {
    Swap1InchHook public hook;

    address dstToken;
    address dstReceiver;
    address srcToken;
    uint256 value;
    bytes txData;
    address mockPair;
    address mockRouter;

    receive() external payable {}

    function setUp() public override {
        super.setUp();

        MockERC20 _mockSrcToken = new MockERC20("Source Token", "SRC", 18);
        srcToken = address(_mockSrcToken);
        
        MockERC20 _mockDstToken = new MockERC20("Destination Token", "DST", 18);
        dstToken = address(_mockDstToken);

        dstReceiver = makeAddr("dstReceiver");
        value = 1000;
        
        // Create a mock pair that will be used in the unoswap test
        mockPair = address(new MockUniswapPair(srcToken, dstToken));
        
        // Create a mock router for testing
        mockRouter = makeAddr("mockRouter");

        hook = new Swap1InchHook(address(this), address(this), mockRouter);
    }

    function test_Constructor() public view {
        assertEq(hook.author(), address(this));
        assertEq(uint256(hook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(hook.aggregationRouter()), mockRouter);
    }

    function test_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(Swap1InchHook.ZERO_ADDRESS.selector);
        new Swap1InchHook(address(this), address(this), address(0));
    }

    function test_Build_RevertIf_CalldataIsNotValid() public {
        bytes memory data = abi.encodePacked(dstToken, dstReceiver, value, bytes4(0xaaaaaaaa));
        vm.expectRevert(Swap1InchHook.INVALID_SELECTOR.selector);
        hook.build(address(0), address(this), data);
    }

    function test_Build_Unoswap() public {
        bytes memory unoswapData = abi.encode(
            dstReceiver,  // receiver
            srcToken,     // fromToken
            1000,         // amount
            100,          // minReturn
            mockPair      // dex (uniswap pair)
        );
        
        bytes4 selector = I1InchAggregationRouterV6.unoswapTo.selector;
        
        bytes memory callData = abi.encodePacked(selector, unoswapData);
        
        bytes memory hookData = abi.encodePacked(dstToken, dstReceiver, value, callData);
        
        vm.mockCall(
            mockPair,
            abi.encodeWithSignature("token0()"),
            abi.encode(srcToken)
        );
        
        vm.mockCall(
            mockPair,
            abi.encodeWithSignature("token1()"),
            abi.encode(dstToken)
        );
        
        address account = address(this);
        
        Execution[] memory executions = hook.build(address(0), account, hookData);
        
        assertEq(executions.length, 1);
        assertEq(executions[0].target, mockRouter);
        assertEq(executions[0].value, value);
        assertEq(executions[0].callData, callData);
    }
    
    function test_PreExecute() public {
        MockERC20 token = new MockERC20("Test Token", "TT", 18);
        token.mint(dstReceiver, 500); 
        
        bytes memory data = abi.encodePacked(address(token), dstReceiver, uint256(0));
        
        hook.preExecute(address(0), address(0), data);
        
        assertEq(hook.outAmount(), 500);
    }
    
    function test_PostExecute() public {
        MockERC20 token = new MockERC20("Test Token", "TT", 18);
        token.mint(dstReceiver, 500); 
        
        bytes memory data = abi.encodePacked(address(token), dstReceiver, uint256(0));
        
        hook.preExecute(address(0), address(0), data);
        
        token.mint(dstReceiver, 300); 
        
        hook.postExecute(address(0), address(0), data);
        
        assertEq(hook.outAmount(), 300);
    }
    
    function test_Build_Swap() public view {
        I1InchAggregationRouterV6.SwapDescription memory desc = I1InchAggregationRouterV6.SwapDescription({
            srcToken: IERC20(srcToken),
            dstToken: IERC20(dstToken),
            srcReceiver: payable(this),
            dstReceiver: payable(dstReceiver),
            amount: 1000,
            minReturnAmount: 100,
            flags: 0 
        });
        
        bytes memory swapData = abi.encode(
            address(0), // executor
            desc,
            bytes(""), // permit
            bytes("") // data
        );
        
        bytes4 selector = I1InchAggregationRouterV6.swap.selector;
        
        bytes memory callData = abi.encodePacked(selector, swapData);
        
        bytes memory hookData = abi.encodePacked(dstToken, dstReceiver, value, callData);
        
        address account = address(this);
        
        Execution[] memory executions = hook.build(address(0), account, hookData);
        
        assertEq(executions.length, 1);
        assertEq(executions[0].target, mockRouter);
        assertEq(executions[0].value, value);
        assertEq(executions[0].callData, callData);
    }
    
    function test_Build_ClipperSwap() public view {
        bytes memory clipperData = abi.encode(
            address(0),  // exchange
            dstReceiver, // receiver
            bytes32(0),  // srcToken
            IERC20(dstToken), // dstToken
            1000,       // amount
            100,        // minReturnAmount
            0,          // goodUntil
            bytes32(0), // bytes32 r, 
            bytes32(0)  // bytes32 vs
        );
        
        bytes4 selector = I1InchAggregationRouterV6.clipperSwapTo.selector;
        
        bytes memory callData = abi.encodePacked(selector, clipperData);
        
        bytes memory hookData = abi.encodePacked(dstToken, dstReceiver, value, callData);
        
        address account = address(this);
        
        Execution[] memory executions = hook.build(address(0), account, hookData);
        
        assertEq(executions.length, 1);
        assertEq(executions[0].target, mockRouter);
        assertEq(executions[0].value, value);
        assertEq(executions[0].callData, callData);
    }
}