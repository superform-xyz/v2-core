// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    SwapUniswapV3Router02Hook
} from "../../../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol";
import {
    ApproveAndSwapUniswapV3Router02Hook
} from "../../../../../src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol";
import { IV3SwapRouter } from "../../../../../src/hooks/swappers/uniswap-v3/interfaces/IV3SwapRouter.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract MockV3SwapRouter is IV3SwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata) external payable override returns (uint256 amountOut) {
        return 0;
    }
}

contract UniswapV3Router02HookTest is Helpers {
    SwapUniswapV3Router02Hook public swapHook;
    ApproveAndSwapUniswapV3Router02Hook public approveAndSwapHook;
    MockV3SwapRouter public router;
    MockHook public prevHook;

    address tokenIn;
    address tokenOut;
    address account;

    uint24 fee = 3000;
    uint160 sqrtPriceLimitX96 = 0;
    uint256 originalAmountIn = 1000;
    uint256 originalMinAmountOut = 950;

    receive() external payable { }

    function setUp() public {
        account = address(this);

        router = new MockV3SwapRouter();

        MockERC20 _tokenIn = new MockERC20("Token In", "TIN", 18);
        tokenIn = address(_tokenIn);

        MockERC20 _tokenOut = new MockERC20("Token Out", "TOUT", 18);
        tokenOut = address(_tokenOut);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, tokenIn);

        swapHook = new SwapUniswapV3Router02Hook(address(router));
        approveAndSwapHook = new ApproveAndSwapUniswapV3Router02Hook(address(router));
    }

    /*//////////////////////////////////////////////////////////////
                         SwapUniswapV3Router02Hook Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Constructor() public view {
        assertEq(uint256(swapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapHook.SWAP_ROUTER()), address(router));
    }

    function test_SwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapUniswapV3Router02Hook(address(0));
    }

    function test_SwapHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _buildHookData(false);
        assertFalse(swapHook.decodeUsePrevHookAmount(data));
    }

    function test_SwapHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _buildHookData(true);
        assertTrue(swapHook.decodeUsePrevHookAmount(data));
    }

    function test_SwapHook_Build() public view {
        bytes memory data = _buildHookData(false);
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // 2 pre/post + 1 swap = 3 executions
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
        assertEq(executions[1].value, 0);
    }

    function test_SwapHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
    }

    function test_SwapHook_Build_RevertIf_InvalidHookData() public {
        bytes memory shortData = new bytes(140); // Less than 141
        vm.expectRevert(SwapUniswapV3Router02Hook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(prevHook), account, shortData);
    }

    function test_SwapHook_PreExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        swapHook.preExecute(address(0), account, data);

        assertEq(swapHook.getOutAmount(account), 500);
    }

    function test_SwapHook_PostExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        swapHook.preExecute(address(0), account, data);

        MockERC20(tokenOut).mint(account, 300);
        swapHook.postExecute(address(0), account, data);

        // Delta: 800 - 500 = 300
        assertEq(swapHook.getOutAmount(account), 300);
    }

    function test_SwapHook_Inspect() public view {
        bytes memory data = _buildHookData(false);
        bytes memory inspected = swapHook.inspect(data);

        // Should return tokenOut packed (20 bytes)
        assertEq(inspected.length, 20);

        address decodedTokenOut;
        assembly {
            decodedTokenOut := mload(add(inspected, 20))
        }

        assertEq(decodedTokenOut, tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                    ApproveAndSwapUniswapV3Router02Hook Tests
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_Constructor() public view {
        assertEq(uint256(approveAndSwapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapHook.SWAP_ROUTER()), address(router));
    }

    function test_ApproveAndSwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapUniswapV3Router02Hook(address(0));
    }

    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_False() public view {
        bytes memory data = _buildHookData(false);
        assertFalse(approveAndSwapHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndSwapHook_DecodeUsePrevHookAmount_True() public view {
        bytes memory data = _buildHookData(true);
        assertTrue(approveAndSwapHook.decodeUsePrevHookAmount(data));
    }

    function test_ApproveAndSwapHook_Build() public view {
        bytes memory data = _buildHookData(false);
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // 2 pre/post + 4 (approve(0), approve(amount), swap, approve(0)) = 6 executions
        assertEq(executions.length, 6);

        // executions[0] is preExecute
        // executions[1] is approve(0)
        assertEq(executions[1].target, tokenIn);
        // executions[2] is approve(amount)
        assertEq(executions[2].target, tokenIn);
        // executions[3] is swap
        assertEq(executions[3].target, address(router));
        // executions[4] is approve(0)
        assertEq(executions[4].target, tokenIn);
    }

    function test_ApproveAndSwapHook_Build_WithPrevHookAmount() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        assertEq(executions.length, 6);
        assertEq(executions[3].target, address(router));
    }

    function test_ApproveAndSwapHook_Build_RevertIf_InvalidHookData() public {
        bytes memory shortData = new bytes(140); // Less than 141
        vm.expectRevert(ApproveAndSwapUniswapV3Router02Hook.INVALID_HOOK_DATA.selector);
        approveAndSwapHook.build(address(prevHook), account, shortData);
    }

    function test_ApproveAndSwapHook_PreExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        approveAndSwapHook.preExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 500);
    }

    function test_ApproveAndSwapHook_PostExecute() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        approveAndSwapHook.preExecute(address(0), account, data);

        MockERC20(tokenOut).mint(account, 300);
        approveAndSwapHook.postExecute(address(0), account, data);

        // Delta: 800 - 500 = 300
        assertEq(approveAndSwapHook.getOutAmount(account), 300);
    }

    function test_ApproveAndSwapHook_Inspect() public view {
        bytes memory data = _buildHookData(false);
        bytes memory inspected = approveAndSwapHook.inspect(data);

        // Should return tokenOut packed (20 bytes)
        assertEq(inspected.length, 20);

        address decodedTokenOut;
        assembly {
            decodedTokenOut := mload(add(inspected, 20))
        }

        assertEq(decodedTokenOut, tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                         Edge Case Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Build_ExactMinimumDataLength() public view {
        // Test with exactly 193 bytes (minimum valid length: 52-byte header + 141 hook-specific bytes)
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 193);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_ApproveAndSwapHook_Build_ExactMinimumDataLength() public view {
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 193);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_SwapHook_SlippageRecalculation_VerifyValues() public {
        bytes memory data = _buildHookData(true);

        // Set previous hook amount to 2x original (2000 vs 1000)
        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // The swap execution is at index 1
        bytes memory swapCalldata = executions[1].callData;

        // IV3SwapRouter.ExactInputSingleParams ABI layout (7 fields, no deadline):
        // selector(4) + tokenIn(32) + tokenOut(32) + fee(32) + recipient(32) + amountIn(32) + amountOutMin(32) +
        // sqrtPriceLimitX96(32)
        // amountIn memory offset: 4 + 32*4 + 32(length prefix) = 164
        // amountOutMinimum memory offset: 4 + 32*5 + 32(length prefix) = 196
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        // newAmountIn should be prevHookAmount = 2000
        assertEq(decodedAmountIn, 2000);
        // newMinOut = originalMinOut * (newAmountIn / originalAmountIn) = 950 * (2000 / 1000) = 1900
        assertEq(decodedAmountOutMinimum, 1900);
    }

    function test_ApproveAndSwapHook_SlippageRecalculation_VerifyValues() public {
        bytes memory data = _buildHookData(true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // The swap execution is at index 3
        bytes memory swapCalldata = executions[3].callData;

        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, 2000);
        assertEq(decodedAmountOutMinimum, 1900);
    }

    function test_SwapHook_NoSlippageRecalculation_VerifyValues() public view {
        // Test with usePrevHookAmount = false to ensure original values are used
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;

        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        // Should use original values, not recalculated
        assertEq(decodedAmountIn, originalAmountIn);
        assertEq(decodedAmountOutMinimum, originalMinAmountOut);
    }

    function test_ApproveAndSwapHook_NoSlippageRecalculation_VerifyValues() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[3].callData;

        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, originalAmountIn);
        assertEq(decodedAmountOutMinimum, originalMinAmountOut);
    }

    /*//////////////////////////////////////////////////////////////
                            Fee Tier Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_DifferentFeeTiers() public view {
        // Test 0.01% fee tier (100)
        bytes memory data = _buildHookDataWithFee(100);
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);

        // Test 0.05% fee tier (500)
        data = _buildHookDataWithFee(500);
        executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);

        // Test 1% fee tier (10000)
        data = _buildHookDataWithFee(10000);
        executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                        Slippage Recalculation Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_SlippageRecalculation() public {
        bytes memory data = _buildHookData(true);

        // Set previous hook amount to 2x original
        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Verify swap execution was built
        assertEq(executions.length, 3);
        assertEq(executions[1].target, address(router));
    }

    /*//////////////////////////////////////////////////////////////
                     SLIPPAGE EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_SlippageRecalculation_ZeroOriginalAmount() public {
        // When originalAmountIn is 0, HookDataUpdater returns original outputAmount
        bytes memory data = _buildHookDataCustomAmounts(0, 950, true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        // amountIn should be prevHookAmount
        assertEq(decodedAmountIn, 2000);
        // When originalAmountIn is 0, HookDataUpdater returns original outputAmount (950)
        assertEq(decodedAmountOutMinimum, 950);
    }

    function test_SwapHook_SlippageRecalculation_VerySmallAmounts() public {
        // Test with very small amounts to check for rounding issues
        bytes memory data = _buildHookDataCustomAmounts(1, 1, true);

        uint256 prevHookAmount = 2;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, 2);
        // newMinOut = 1 * (2 / 1) = 2
        assertEq(decodedAmountOutMinimum, 2);
    }

    function test_SwapHook_SlippageRecalculation_LargeAmounts() public {
        // Test with large amounts (realistic DeFi scenario)
        uint256 largeAmountIn = 1_000_000e18;
        uint256 largeMinOut = 950_000e18;

        bytes memory data = _buildHookDataCustomAmounts(largeAmountIn, largeMinOut, true);

        uint256 prevHookAmount = 2_000_000e18;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, 2_000_000e18);
        assertEq(decodedAmountOutMinimum, 1_900_000e18);
    }

    function test_SwapHook_SlippageRecalculation_SmallerPrevAmount() public {
        // Test when previous hook amount is SMALLER than original
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        uint256 prevHookAmount = 500;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, 500);
        // newMinOut = 950 * (500 / 1000) = 475
        assertEq(decodedAmountOutMinimum, 475);
    }

    function test_SwapHook_SlippageRecalculation_EqualAmounts() public {
        // Test when previous hook amount equals original (no change)
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        uint256 prevHookAmount = 1000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
            decodedAmountOutMinimum := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, 1000);
        assertEq(decodedAmountOutMinimum, 950);
    }

    /*//////////////////////////////////////////////////////////////
                     ZERO AMOUNT / REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_ZeroAmountIn() public {
        // amountIn = 0 with usePrevHookAmount = false should revert
        bytes memory data = _buildHookDataCustomAmounts(0, 0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_ZeroAmountIn() public {
        bytes memory data = _buildHookDataCustomAmounts(0, 0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_RevertIf_ZeroPrevHookAmount() public {
        // prevHook returns 0, should revert
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);
        prevHook.setOutAmount(0, account);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_ZeroPrevHookAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);
        prevHook.setOutAmount(0, account);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     SAME TOKEN REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_SameToken() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn),
            bytes20(tokenIn), // tokenOut == tokenIn
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );

        vm.expectRevert(SwapUniswapV3Router02Hook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_SameToken() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn),
            bytes20(tokenIn), // tokenOut == tokenIn
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );

        vm.expectRevert(ApproveAndSwapUniswapV3Router02Hook.INVALID_HOOK_DATA.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     POST EXECUTE OVERFLOW GUARD TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_PostExecute_RevertIf_BalanceDecreased() public {
        bytes memory data = _buildHookData(false);

        // Pre-execute with 500 balance
        MockERC20(tokenOut).mint(account, 500);
        swapHook.preExecute(address(0), account, data);

        // Burn tokens to simulate balance decrease
        MockERC20(tokenOut).burn(account, 200);

        // Post-execute should revert since finalBalance (300) < initialBalance (500)
        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.postExecute(address(0), account, data);
    }

    function test_ApproveAndSwapHook_PostExecute_RevertIf_BalanceDecreased() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        approveAndSwapHook.preExecute(address(0), account, data);

        MockERC20(tokenOut).burn(account, 200);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndSwapHook.postExecute(address(0), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     APPROVE AND SWAP EDGE CASES
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_SlippageRecalculation_ZeroOriginalAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(0, 950, true);

        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify approve amount matches prevHookAmount
        bytes memory approveCalldata = executions[2].callData; // approve(amount) is at index 2
        uint256 approveAmount;
        assembly {
            // Skip selector (4 bytes), skip spender address (32 bytes), get amount
            approveAmount := mload(add(approveCalldata, 68))
        }

        assertEq(approveAmount, 2000);
    }

    function test_ApproveAndSwapHook_VerifyApprovalSequence() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Verify execution sequence:
        // 0: preExecute
        // 1: approve(0)
        // 2: approve(amount)
        // 3: swap
        // 4: approve(0)
        // 5: postExecute

        assertEq(executions.length, 6);

        // Verify approve(0) at index 1
        assertEq(executions[1].target, tokenIn);
        bytes memory approve0Calldata = executions[1].callData;
        uint256 approve0Amount;
        assembly {
            approve0Amount := mload(add(approve0Calldata, 68))
        }
        assertEq(approve0Amount, 0);

        // Verify approve(amount) at index 2
        assertEq(executions[2].target, tokenIn);
        bytes memory approveAmountCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly {
            approvedAmount := mload(add(approveAmountCalldata, 68))
        }
        assertEq(approvedAmount, originalAmountIn);

        // Verify swap at index 3
        assertEq(executions[3].target, address(router));

        // Verify approve(0) cleanup at index 4
        assertEq(executions[4].target, tokenIn);
        bytes memory cleanupCalldata = executions[4].callData;
        uint256 cleanupAmount;
        assembly {
            cleanupAmount := mload(add(cleanupCalldata, 68))
        }
        assertEq(cleanupAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                     NATIVE ETH REJECTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_NativeETH_TokenIn() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(address(0)), // tokenIn = native ETH
            bytes20(tokenOut),
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );

        vm.expectRevert(SwapUniswapV3Router02Hook.NATIVE_ETH_NOT_SUPPORTED.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_RevertIf_NativeETH_TokenOut() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn),
            bytes20(address(0)), // tokenOut = native ETH
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );

        vm.expectRevert(SwapUniswapV3Router02Hook.NATIVE_ETH_NOT_SUPPORTED.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_NativeETH_TokenIn() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(address(0)), // tokenIn = native ETH
            bytes20(tokenOut),
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );

        vm.expectRevert(ApproveAndSwapUniswapV3Router02Hook.NATIVE_ETH_NOT_SUPPORTED.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_NativeETH_TokenOut() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn),
            bytes20(address(0)), // tokenOut = native ETH
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );

        vm.expectRevert(ApproveAndSwapUniswapV3Router02Hook.NATIVE_ETH_NOT_SUPPORTED.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     RECIPIENT FORCED TO ACCOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RecipientForcedToAccount() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Decode recipient from swap calldata
        bytes memory swapCalldata = executions[1].callData;
        address decodedRecipient;
        assembly {
            // recipient is at offset 4 + 32*3 = 100 (after selector + tokenIn + tokenOut + fee)
            // memory offset: 100 + 32 = 132
            decodedRecipient := mload(add(swapCalldata, 132))
        }

        // Recipient should be forced to account
        assertEq(decodedRecipient, account);
    }

    function test_ApproveAndSwapHook_RecipientForcedToAccount() public view {
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Decode recipient from swap calldata (swap is at index 3)
        bytes memory swapCalldata = executions[3].callData;
        address decodedRecipient;
        assembly {
            decodedRecipient := mload(add(swapCalldata, 132))
        }

        // Recipient should be forced to account
        assertEq(decodedRecipient, account);
    }

    function test_SwapHook_ZeroSqrtPriceLimitMeansNoLimit() public view {
        bytes memory data = _buildHookData(false);

        // Should not revert - 0 is valid (means no limit)
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                     FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_SwapHook_SlippageRecalculation(
        uint256 originalAmount,
        uint256 originalMinOut,
        uint256 prevAmount
    )
        public
    {
        // Bound inputs to reasonable values
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        originalMinOut = bound(originalMinOut, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        bytes memory data = _buildHookDataCustomAmounts(originalAmount, originalMinOut, true);
        prevHook.setOutAmount(prevAmount, account);

        // Should not revert
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        assembly {
            decodedAmountIn := mload(add(swapCalldata, 164))
        }

        // amountIn should always be prevAmount when usePrevHookAmount is true
        assertEq(decodedAmountIn, prevAmount);
    }

    function testFuzz_SwapHook_DataLength(uint8 extraBytes) public view {
        // Test with various data lengths >= 141
        bytes memory baseData = _buildHookData(false);
        bytes memory extraData = new bytes(extraBytes);
        bytes memory data = bytes.concat(baseData, extraData);

        // Should not revert for any length >= 141
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapUniV3Router02_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(swapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_SwapUniV3Router02_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapUniV3Router02_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapUniV3Router02_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_ApproveAndSwapUniV3Router02_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapUniV3Router02_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    /*//////////////////////////////////////////////////////////////
                    REPLACE + BUILD ROUNDTRIP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapUniV3Router02_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapUniV3Router02_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapUniV3Router02_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 128 (52-byte placeholder + tokenIn(20) + tokenOut(20) + fee(4) + sqrtPrice(32))
        for (uint256 i = 0; i < 128; i++) {
            assertEq(replaced[i], data[i]);
        }
        // bytes after amount (160+) unchanged
        for (uint256 i = 160; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
        assertEq(swapHook.decodeAmounts(replaced)[0], 999);
    }

    function test_ApproveAndSwapUniV3Router02_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 128 (52-byte placeholder + tokenIn(20) + tokenOut(20) + fee(4) + sqrtPrice(32))
        for (uint256 i = 0; i < 128; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 160; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], 999);
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/

    function _buildHookData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn), // 52-71
            bytes20(tokenOut), // 72-91
            bytes4(uint32(fee)), // 92-95
            bytes32(uint256(sqrtPriceLimitX96)), // 96-127
            bytes32(originalAmountIn), // 128-159
            bytes32(originalMinAmountOut), // 160-191
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // 192
        );
    }

    function _buildHookDataWithFee(uint24 _fee) internal view returns (bytes memory) {
        return bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes4(uint32(_fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(originalAmountIn),
            bytes32(originalMinAmountOut),
            bytes1(0x00)
        );
    }

    function _buildHookDataCustomAmounts(
        uint256 _amountIn,
        uint256 _minAmountOut,
        bool _usePrevHookAmount
    )
        internal
        view
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(52)), // 52-byte placeholder
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes4(uint32(fee)),
            bytes32(uint256(sqrtPriceLimitX96)),
            bytes32(_amountIn),
            bytes32(_minAmountOut),
            _usePrevHookAmount ? bytes1(0x01) : bytes1(0x00)
        );
    }
}
