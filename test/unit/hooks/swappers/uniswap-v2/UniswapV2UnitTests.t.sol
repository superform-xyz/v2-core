// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SwapUniswapV2Hook } from "../../../../../src/hooks/swappers/uniswap-v2/SwapUniswapV2Hook.sol";
import {
    ApproveAndSwapUniswapV2Hook
} from "../../../../../src/hooks/swappers/uniswap-v2/ApproveAndSwapUniswapV2Hook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract UniswapV2UnitTests is Helpers {
    SwapUniswapV2Hook public swapHook;
    ApproveAndSwapUniswapV2Hook public approveAndSwapHook;

    address tokenIn = address(0x1111111111111111111111111111111111111111);
    address tokenOut = address(0x2222222222222222222222222222222222222222);
    address router = address(0x3333333333333333333333333333333333333333);
    address native = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    uint256 deadline = type(uint256).max;
    uint256 originalAmountIn = 1000;
    uint256 originalMinAmountOut = 950;

    function setUp() public {
        swapHook = new SwapUniswapV2Hook(router, native);
        approveAndSwapHook = new ApproveAndSwapUniswapV2Hook(router, native);
    }

    /*//////////////////////////////////////////////////////////////
                    SwapUniswapV2Hook DecodeAmounts Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapUniV2_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(swapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_SwapUniV2_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2000;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
        // Verify other fields unchanged
        assertEq(swapHook.decodeUsePrevHookAmount(result), false);
    }

    function testFuzz_SwapUniV2_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    /*//////////////////////////////////////////////////////////////
              ApproveAndSwapUniswapV2Hook DecodeAmounts Tests
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapUniV2_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_ApproveAndSwapUniV2_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2000;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
        assertEq(approveAndSwapHook.decodeUsePrevHookAmount(result), false);
    }

    function testFuzz_ApproveAndSwapUniV2_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapUniV2_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapUniV2_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapUniV2_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION = 124, amountIn occupies bytes 124–155
        for (uint256 i = 0; i < 124; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 156; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds hook data matching the UniswapV2 layout (with 52-byte strategy header):
    /// header(0,52) | tokenIn(52) | tokenOut(72) | deadline(92) | originalAmountIn(124) |
    /// originalMinAmountOut(156) | usePrevHookAmount(188) | pathLength(189) | path(221+)
    function _buildHookData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes32(0),          // yieldSourceOracleId placeholder (header bytes 0-31)
            bytes20(address(0)), // yieldSource placeholder (header bytes 32-51)
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(deadline),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00),
            bytes32(uint256(2)), // pathLength = 2
            bytes20(tokenIn),
            bytes20(tokenOut)
        );
    }
}
