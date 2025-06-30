// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {Swap1InchHook} from "../../../../../src/core/hooks/swappers/1inch/Swap1InchHook.sol";
import {ISuperHook} from "../../../../../src/core/interfaces/ISuperHook.sol";
import {MockERC20} from "../../../../mocks/MockERC20.sol";
import "../../../../../src/vendor/1inch/I1InchAggregationRouterV6.sol";
import "forge-std/console.sol";

import {BytesLib} from "../../../../../src/vendor/BytesLib.sol";

contract MockPrevHook {
    uint256 public outAmountValue;

    constructor(uint256 _outAmount) {
        outAmountValue = _outAmount;
    }

    function outAmount() external view returns (uint256) {
        return outAmountValue;
    }
}

struct ExecData {
    address receiver;
    address fromToken;
    uint256 amount;
    uint256 minReturn;
}

contract Swap1InchHookBugTest is Test {
    using AddressLib for Address;
    using ProtocolLib for Address;

    Swap1InchHook public hook;
    address public mockRouter;
    address public srcToken;
    address public dstToken;
    address public dstReceiver;
    address public mockPair;
    
    uint256 swap1Amount = 1000;
    uint256 swap1OutAmount = 950;
    uint256 swap1MinReturn = 900; // 10% slippage

    uint256 swap2Amount = 2000;
    uint256 swap2MinReturn = 1800; // 10% slippage

    uint256 prevHookAmount = swap1OutAmount;
    
    function setUp() public {
        srcToken = address(new MockERC20("Source Token", "SRC", 18));
        dstToken = address(new MockERC20("Destination Token", "DST", 18));
        dstReceiver = makeAddr("dstReceiver");
        
        mockRouter = makeAddr("mockRouter");
        mockPair = makeAddr("mockPair");
        
        hook = new Swap1InchHook(mockRouter);
    }

    function test_Bug_UsePrevHookAmount_UpdatesAmountAndMinReturn() public {
        vm.mockCall(mockPair, abi.encodeWithSignature("token0()"), abi.encode(srcToken));
        vm.mockCall(mockPair, abi.encodeWithSignature("token1()"), abi.encode(dstToken));
        
        
        // 2. Now, build with usePrevHookAmount = true (bug case)
        MockPrevHook prevHook = new MockPrevHook(prevHookAmount);
        
        bytes memory buggyHookData = _buildUnoswapData(
            swap2Amount, // Different than prevHookAmount
            swap2MinReturn,
            true // usePrevHookAmount
        );

        Execution[] memory bugExecutions = hook.build(address(prevHook), address(this), buggyHookData);

        console.log("bugExecutions[0].callData:", bugExecutions[1].callData.length);
        
        ExecData memory bugDecodeData = decodeUnoswapData(bytes(bugExecutions[1].callData));

        
        console.log("\nWith usePrevHookAmount = true:");
        console.log("receiver:", bugDecodeData.receiver);
        console.log("fromToken:", bugDecodeData.fromToken);
        console.log("amount:", bugDecodeData.amount);
        console.log("minReturn:", bugDecodeData.minReturn);
        
        // Get the expected minReturn based on the code's SLIPPAGE calculation
        uint256 percentageDecrease = 5250; // 5.25% (2000 => 950)
        uint256 expectedMinReturn =  swap2MinReturn - ((swap2MinReturn * percentageDecrease) / 10_000);
        console.log("Expected minReturn:", expectedMinReturn);
        
        // Verify amount changed to prevHookAmount
        assertEq(bugDecodeData.amount, prevHookAmount, "Amount should be updated to previous hook amount");
        
        // Verify minReturn is updated according to the slippage calculation
        assertEq(bugDecodeData.minReturn, expectedMinReturn, "MinReturn should be updated based on slippage calculation");
        
        // Verify minReturn is different from the original
        assertTrue(bugDecodeData.minReturn != swap2MinReturn, "MinReturn should be different from original");
    }
    
    function _buildUnoswapData(
        uint256 _amount, 
        uint256 _minAmount,
        bool usePrevHookAmount
    ) private view returns (bytes memory) {
        bytes memory unoswapData = abi.encode(
            dstReceiver, // receiver
            srcToken, // fromToken
            _amount, // amount
            _minAmount, // minReturn
            mockPair // dex (uniswap pair)
        );

        bytes4 selector = I1InchAggregationRouterV6.unoswapTo.selector;
        bytes memory callData = abi.encodePacked(selector, unoswapData);
        return abi.encodePacked(dstToken, dstReceiver, uint256(0), usePrevHookAmount, callData);
    }

    function decodeUnoswapData(bytes memory data) public pure returns (ExecData memory rst) {
        // Skip the selector (4 bytes) and decode using abi.decode
        // This matches how the data is encoded in _validateUnoswap
        (
            Address to, 
            Address token, 
            uint256 amount, 
            uint256 minReturn, 
        ) = abi.decode(BytesLib.slice(data, 4, data.length - 4), (Address, Address, uint256, uint256, Address));
        
        // Extract actual addresses from Address type using the unwrap pattern
        rst.receiver = to.get();
        rst.fromToken = token.get();
        rst.amount = amount;
        rst.minReturn = minReturn;
        // Note: we don't need dex for this test
    }
}
