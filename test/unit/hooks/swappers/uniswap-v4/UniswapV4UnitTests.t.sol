// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { SwapUniswapV4Hook } from "../../../../../src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract UniswapV4UnitTests is Helpers {
    SwapUniswapV4Hook public swapHook;

    address currency0 = address(0x1111111111111111111111111111111111111111);
    address currency1 = address(0x2222222222222222222222222222222222222222);
    uint24 fee = 3000;
    int24 tickSpacing = 60;
    address hooks = address(0);
    address dstReceiver = address(0x4444444444444444444444444444444444444444);
    uint160 sqrtPriceLimitX96 = 0;
    uint256 originalAmountIn = 1000;
    uint256 originalMinAmountOut = 950;
    uint256 maxSlippageDeviationBps = 100;
    bool zeroForOne = true;

    function setUp() public {
        // Deploy with a mock pool manager address
        address poolManager = address(0x5555555555555555555555555555555555555555);
        swapHook = new SwapUniswapV4Hook(poolManager);
    }

    /*//////////////////////////////////////////////////////////////
                    SwapUniswapV4Hook DecodeAmounts Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapUniV4_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(swapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_SwapUniV4_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2000;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapUniV4_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapUniV4_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(0), address(this), replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapUniV4_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 92 (52-byte placeholder + currency0(20) + currency1(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds hook data matching the UniswapV4 new layout:
    /// placeholder(0-51) | currency0(52) | currency1(72) | amountIn(92) | amountOutMin(124) |
    /// zeroForOne(156) | usePrevHookAmount(157) | abi.encode(fee, tickSpacing, hooks, dstReceiver, sqrtPriceLimitX96, maxSlippageDeviationBps, additionalData)(158+)
    function _buildHookData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(currency0),
            bytes20(currency1),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            zeroForOne ? bytes1(0x01) : bytes1(0x00),
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00),
            abi.encode(fee, tickSpacing, hooks, dstReceiver, sqrtPriceLimitX96, maxSlippageDeviationBps, bytes(""))
        );
    }
}
