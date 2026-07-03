// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import {
    SwapAlgebraIntegralHook
} from "../../../../../src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol";
import {
    ApproveAndSwapAlgebraIntegralHook
} from "../../../../../src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol";
import { IAlgebraSwapRouter } from "../../../../../src/vendor/algebra-integral/IAlgebraSwapRouter.sol";
import { ISuperHook } from "../../../../../src/interfaces/ISuperHook.sol";
import { ISuperHookSwap } from "../../../../../src/interfaces/ISuperHookSwap.sol";
import { MockERC20 } from "../../../../mocks/MockERC20.sol";
import { MockHook } from "../../../../mocks/MockHook.sol";
import { BaseHook } from "../../../../../src/hooks/BaseHook.sol";
import { Helpers } from "../../../../utils/Helpers.sol";

contract MockAlgebraSwapRouter is IAlgebraSwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata) external payable override returns (uint256 amountOut) {
        return 0;
    }
}

contract AlgebraIntegralHookTest is Helpers {
    SwapAlgebraIntegralHook public swapHook;
    ApproveAndSwapAlgebraIntegralHook public approveAndSwapHook;
    MockAlgebraSwapRouter public router;
    MockHook public prevHook;

    address tokenIn;
    address tokenOut;
    address account;
    address deployer;

    uint256 deadline;
    uint160 limitSqrtPrice = 0;
    uint256 originalAmountIn = 1000;
    uint256 originalMinAmountOut = 950;

    receive() external payable { }

    function setUp() public {
        account = address(this);
        deployer = address(0xDEAD);
        deadline = block.timestamp + 3600;

        router = new MockAlgebraSwapRouter();

        MockERC20 _tokenIn = new MockERC20("Token In", "TIN", 18);
        tokenIn = address(_tokenIn);

        MockERC20 _tokenOut = new MockERC20("Token Out", "TOUT", 18);
        tokenOut = address(_tokenOut);

        prevHook = new MockHook(ISuperHook.HookType.INFLOW, tokenIn);

        swapHook = new SwapAlgebraIntegralHook(address(router));
        approveAndSwapHook = new ApproveAndSwapAlgebraIntegralHook(address(router));
    }

    /*//////////////////////////////////////////////////////////////
                         SwapAlgebraIntegralHook Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Constructor() public view {
        assertEq(uint256(swapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(swapHook.SWAP_ROUTER()), address(router));
    }

    function test_SwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new SwapAlgebraIntegralHook(address(0));
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
        bytes memory shortData = new bytes(250); // Less than 305
        vm.expectRevert(SwapAlgebraIntegralHook.INVALID_HOOK_DATA.selector);
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
        assembly ("memory-safe") {
            decodedTokenOut := mload(add(inspected, 20))
        }

        assertEq(decodedTokenOut, tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                    ApproveAndSwapAlgebraIntegralHook Tests
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_Constructor() public view {
        assertEq(uint256(approveAndSwapHook.hookType()), uint256(ISuperHook.HookType.NONACCOUNTING));
        assertEq(address(approveAndSwapHook.SWAP_ROUTER()), address(router));
    }

    function test_ApproveAndSwapHook_Constructor_RevertIf_AddressZero() public {
        vm.expectRevert(BaseHook.ADDRESS_NOT_VALID.selector);
        new ApproveAndSwapAlgebraIntegralHook(address(0));
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
        bytes memory shortData = new bytes(250); // Less than 305
        vm.expectRevert(ApproveAndSwapAlgebraIntegralHook.INVALID_HOOK_DATA.selector);
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
        assembly ("memory-safe") {
            decodedTokenOut := mload(add(inspected, 20))
        }

        assertEq(decodedTokenOut, tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                         Edge Case Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_Build_ExactMinimumDataLength() public view {
        // Test with exactly 305 bytes (minimum valid length)
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 305);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_ApproveAndSwapHook_Build_ExactMinimumDataLength() public view {
        bytes memory data = _buildHookData(false);
        assertEq(data.length, 305);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_SwapHook_SlippageRecalculation_VerifyValues() public {
        bytes memory data = _buildHookData(true);

        // Set previous hook amount to 2x original (2000 vs 1000)
        uint256 prevHookAmount = 2000;
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Decode the calldata to verify the calculated values
        // The swap execution is at index 1
        bytes memory swapCalldata = executions[1].callData;

        // Skip the 4-byte selector
        // ExactInputSingleParams struct layout in calldata after selector:
        // tokenIn (32), tokenOut (32), deployer (32), recipient (32),
        // deadline (32), amountIn (32), amountOutMinimum (32), limitSqrtPrice (32)

        // amountIn is at offset 4 + 32*5 = 164 from start of calldata → swapCalldata + 32 + 164 = swapCalldata + 196
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196)) // 32 + 4 + 32*5
            decodedAmountOutMinimum := mload(add(swapCalldata, 228)) // 32 + 4 + 32*6
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
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
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
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
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
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
        }

        assertEq(decodedAmountIn, originalAmountIn);
        assertEq(decodedAmountOutMinimum, originalMinAmountOut);
    }

    /*//////////////////////////////////////////////////////////////
                         Deployer Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_DifferentDeployers() public view {
        // Test with different deployer addresses
        address deployer1 = address(0x1111);
        bytes memory data = _buildHookDataWithDeployer(deployer1);
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);

        // Test with zero deployer (default pool deployer)
        address deployer2 = address(0);
        data = _buildHookDataWithDeployer(deployer2);

        // tokenIn is not address(0), tokenOut is not address(0), so no NATIVE_ETH revert
        // deployer being address(0) is valid - means default pool deployer
        executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_SwapHook_DeployerPassedToRouter() public view {
        address customDeployer = address(0xCAFE);
        bytes memory data = _buildHookDataWithDeployer(customDeployer);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        // Decode deployer from swap calldata
        bytes memory swapCalldata = executions[1].callData;
        address decodedDeployer;
        assembly ("memory-safe") {
            // deployer is at offset 4 + 32*2 = 68 from start of calldata → swapCalldata + 32 + 68 = swapCalldata + 100
            decodedDeployer := mload(add(swapCalldata, 100))
        }

        assertEq(decodedDeployer, customDeployer);
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

        // The slippage should be recalculated proportionally
        // newMinOut = 950 * (2000 / 1000) = 1900
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE/REPLACE AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapAlgebra_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(swapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_SwapAlgebra_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(swapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_SwapAlgebra_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = swapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(swapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_ApproveAndSwapAlgebra_DecodeAmounts() public view {
        bytes memory data = _buildHookData(false);
        assertEq(approveAndSwapHook.decodeAmounts(data)[0], originalAmountIn);
    }

    function test_ApproveAndSwapAlgebra_ReplaceCalldataAmounts() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 2e18;
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        assertEq(result.length, data.length);
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], newAmount);
    }

    function testFuzz_ApproveAndSwapAlgebra_ReplaceCalldataAmounts(uint256 fuzzAmount) public view {
        vm.assume(fuzzAmount > 0);
        bytes memory data = _buildHookData(false);
        bytes memory result = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(fuzzAmount));
        assertEq(approveAndSwapHook.decodeAmounts(result)[0], fuzzAmount);
    }

    function test_SwapAlgebraIntegral_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = swapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 3);
        assertEq(swapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_ApproveAndSwapAlgebraIntegral_ReplaceCalldataAmounts_ThenBuild() public view {
        bytes memory data = _buildHookData(false);
        uint256 newAmount = 500;
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(newAmount));
        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, replaced);
        assertEq(executions.length, 6);
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount);
    }

    function test_SwapAlgebraIntegral_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = swapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 92 (52-byte header + tokenIn(20) + tokenOut(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
    }

    function test_ApproveAndSwapAlgebraIntegral_ReplaceCalldataAmounts_PreservesOtherFields() public view {
        bytes memory data = _buildHookData(false);
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(data, _singleAmount(999));
        assertEq(replaced.length, data.length);
        // AMOUNT_POSITION is 92 (52-byte header + tokenIn(20) + tokenOut(20))
        for (uint256 i = 0; i < 92; i++) {
            assertEq(replaced[i], data[i]);
        }
        for (uint256 i = 124; i < data.length; i++) {
            assertEq(replaced[i], data[i]);
        }
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
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
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
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
        }

        assertEq(decodedAmountIn, 2);
        // newMinOut = 1 * (2 / 1) = 2 (with HookDataUpdater precision)
        assertEq(decodedAmountOutMinimum, 2);
    }

    function test_SwapHook_SlippageRecalculation_LargeAmounts() public {
        // Test with large amounts (realistic DeFi scenario)
        uint256 largeAmountIn = 1_000_000e18; // 1M tokens
        uint256 largeMinOut = 950_000e18; // 950K tokens (5% slippage)

        bytes memory data = _buildHookDataCustomAmounts(largeAmountIn, largeMinOut, true);

        uint256 prevHookAmount = 2_000_000e18; // 2M tokens from prev hook
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
        }

        assertEq(decodedAmountIn, 2_000_000e18);
        // newMinOut = 950_000e18 * (2_000_000e18 / 1_000_000e18) = 1_900_000e18
        assertEq(decodedAmountOutMinimum, 1_900_000e18);
    }

    function test_SwapHook_SlippageRecalculation_SmallerPrevAmount() public {
        // Test when previous hook amount is SMALLER than original
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        uint256 prevHookAmount = 500; // Half of original
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
        }

        assertEq(decodedAmountIn, 500);
        // newMinOut = 950 * (500 / 1000) = 475
        assertEq(decodedAmountOutMinimum, 475);
    }

    function test_SwapHook_SlippageRecalculation_EqualAmounts() public {
        // Test when previous hook amount equals original (no change)
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        uint256 prevHookAmount = 1000; // Same as original
        prevHook.setOutAmount(prevHookAmount, account);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        uint256 decodedAmountIn;
        uint256 decodedAmountOutMinimum;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
            decodedAmountOutMinimum := mload(add(swapCalldata, 228))
        }

        assertEq(decodedAmountIn, 1000);
        // No change when amounts are equal
        assertEq(decodedAmountOutMinimum, 950);
    }

    /*//////////////////////////////////////////////////////////////
                     ZERO AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_ZeroAmountIn() public {
        // Test with zero amountIn when usePrevHookAmount is false
        bytes memory data = _buildHookDataCustomAmounts(0, 0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_RevertIf_ZeroPrevHookAmount() public {
        // Test when previous hook returns zero
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        prevHook.setOutAmount(0, account);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_ZeroAmountIn() public {
        bytes memory data = _buildHookDataCustomAmounts(0, 0, false);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_ZeroPrevHookAmount() public {
        bytes memory data = _buildHookDataCustomAmounts(1000, 950, true);

        prevHook.setOutAmount(0, account);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     TOKEN IN == TOKEN OUT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_TokenInEqualsTokenOut() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenIn), // tokenOut == tokenIn
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(SwapAlgebraIntegralHook.INVALID_HOOK_DATA.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_TokenInEqualsTokenOut() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenIn), // tokenOut == tokenIn
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(ApproveAndSwapAlgebraIntegralHook.INVALID_HOOK_DATA.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     POST EXECUTE UNDERFLOW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_PostExecuteUnderflow() public {
        bytes memory data = _buildHookData(false);

        // Set initial balance high
        MockERC20(tokenOut).mint(account, 1000);
        swapHook.preExecute(address(0), account, data);

        // Burn tokens so final balance < initial balance
        MockERC20(tokenOut).burn(account, 500);

        vm.expectRevert(BaseHook.AMOUNT_NOT_VALID.selector);
        swapHook.postExecute(address(0), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_PostExecuteUnderflow() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 1000);
        approveAndSwapHook.preExecute(address(0), account, data);

        MockERC20(tokenOut).burn(account, 500);

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
        assembly ("memory-safe") {
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
        assembly ("memory-safe") {
            approve0Amount := mload(add(approve0Calldata, 68))
        }
        assertEq(approve0Amount, 0);

        // Verify approve(amount) at index 2
        assertEq(executions[2].target, tokenIn);
        bytes memory approveAmountCalldata = executions[2].callData;
        uint256 approvedAmount;
        assembly ("memory-safe") {
            approvedAmount := mload(add(approveAmountCalldata, 68))
        }
        assertEq(approvedAmount, originalAmountIn);

        // Verify swap at index 3
        assertEq(executions[3].target, address(router));

        // Verify approve(0) cleanup at index 4
        assertEq(executions[4].target, tokenIn);
        bytes memory cleanupCalldata = executions[4].callData;
        uint256 cleanupAmount;
        assembly ("memory-safe") {
            cleanupAmount := mload(add(cleanupCalldata, 68))
        }
        assertEq(cleanupAmount, 0);
    }

    /*//////////////////////////////////////////////////////////////
                     NATIVE ETH REJECTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_NativeETH_TokenIn() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(address(0)), // tokenIn = native ETH
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(SwapAlgebraIntegralHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_RevertIf_NativeETH_TokenOut() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(address(0)), // tokenOut = native ETH
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(SwapAlgebraIntegralHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_NativeETH_TokenIn() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(address(0)), // tokenIn = native ETH
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(ApproveAndSwapAlgebraIntegralHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_NativeETH_TokenOut() public {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(address(0)), // tokenOut = native ETH
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(ApproveAndSwapAlgebraIntegralHook.NATIVE_ETH_NOT_SUPPORTED.selector);
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    /*//////////////////////////////////////////////////////////////
                     DEADLINE VALIDATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RevertIf_ExpiredDeadline() public {
        uint256 expiredDeadline = block.timestamp - 1;

        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(expiredDeadline), // Expired deadline at [241:273]
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(
            abi.encodeWithSelector(SwapAlgebraIntegralHook.EXPIRED_DEADLINE.selector, expiredDeadline, block.timestamp)
        );
        swapHook.build(address(prevHook), account, data);
    }

    function test_ApproveAndSwapHook_RevertIf_ExpiredDeadline() public {
        uint256 expiredDeadline = block.timestamp - 1;

        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(expiredDeadline), // Expired deadline at [241:273]
            bytes32(uint256(limitSqrtPrice))
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ApproveAndSwapAlgebraIntegralHook.EXPIRED_DEADLINE.selector, expiredDeadline, block.timestamp
            )
        );
        approveAndSwapHook.build(address(prevHook), account, data);
    }

    function test_SwapHook_DeadlineAtCurrentTimestamp() public view {
        // Deadline exactly at block.timestamp should succeed
        uint256 exactDeadline = block.timestamp;

        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(exactDeadline),
            bytes32(uint256(limitSqrtPrice))
        );

        // Should not revert
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function test_SwapHook_ZeroLimitSqrtPriceMeansNoLimit() public view {
        // limitSqrtPrice = 0 means no price limit, should work fine
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(0)) // Zero = no price limit at [273:305]
        );

        // Should not revert - 0 is valid (means no limit)
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    /*//////////////////////////////////////////////////////////////
                     RECIPIENT FORCED TO ACCOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SwapHook_RecipientForcedToAccount() public view {
        // In the new standard layout there is no recipient field in the hook data.
        // The hook always hardcodes recipient = account. Verify the encoded calldata.
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = swapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[1].callData;
        address decodedRecipient;
        assembly ("memory-safe") {
            // recipient is at 4 (selector) + 32*3 (tokenIn+tokenOut+deployer) = 100 from calldata start
            // In memory bytes: swapCalldata ptr + 32 (length slot) + 100 = swapCalldata + 132
            decodedRecipient := mload(add(swapCalldata, 132))
        }

        assertEq(decodedRecipient, account);
    }

    function test_ApproveAndSwapHook_RecipientForcedToAccount() public view {
        // In the new standard layout there is no recipient field in the hook data.
        // The hook always hardcodes recipient = account. Verify the encoded calldata.
        bytes memory data = _buildHookData(false);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        // Swap is at index 3
        bytes memory swapCalldata = executions[3].callData;
        address decodedRecipient;
        assembly ("memory-safe") {
            decodedRecipient := mload(add(swapCalldata, 132))
        }

        assertEq(decodedRecipient, account);
    }

    /*//////////////////////////////////////////////////////////////
                     ADDITIONAL BOUNDARY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ApproveAndSwapHook_DeadlineAtCurrentTimestamp() public view {
        uint256 exactDeadline = block.timestamp;

        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(exactDeadline),
            bytes32(uint256(limitSqrtPrice))
        );

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_ApproveAndSwapHook_ZeroLimitSqrtPriceMeansNoLimit() public view {
        bytes memory data = bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(0))
        );

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    function test_SwapHook_PostExecute_ZeroDelta() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        swapHook.preExecute(address(0), account, data);

        // No tokens added — delta should be 0
        swapHook.postExecute(address(0), account, data);

        assertEq(swapHook.getOutAmount(account), 0);
    }

    function test_ApproveAndSwapHook_PostExecute_ZeroDelta() public {
        bytes memory data = _buildHookData(false);

        MockERC20(tokenOut).mint(account, 500);
        approveAndSwapHook.preExecute(address(0), account, data);

        // No tokens added — delta should be 0
        approveAndSwapHook.postExecute(address(0), account, data);

        assertEq(approveAndSwapHook.getOutAmount(account), 0);
    }

    /*//////////////////////////////////////////////////////////////
                    ISuperHookSwap Interface Tests
    //////////////////////////////////////////////////////////////*/

    function test_SwapAlgebra_EncodeSwapData_RoundTrip() public view {
        bytes memory payload = bytes.concat(bytes20(deployer), bytes32(deadline), bytes32(uint256(limitSqrtPrice)));

        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: tokenIn,
            outputToken: tokenOut,
            inputAmount: originalAmountIn,
            outputQuote: 0,
            outputMin: originalMinAmountOut,
            usePrevHookAmount: false
        });

        bytes memory encoded = swapHook.encodeSwapData(header, payload);

        assertEq(swapHook.decodeInputToken(encoded), tokenIn);
        assertEq(swapHook.decodeOutputToken(encoded), tokenOut);
        assertEq(swapHook.decodeInputAmount(encoded), originalAmountIn);
        assertEq(swapHook.decodeOutputQuote(encoded), 0);
        assertEq(swapHook.decodeOutputMin(encoded), originalMinAmountOut);

        bytes memory decodedPayload = swapHook.decodePayload(encoded);
        assertEq(decodedPayload.length, 84);
    }

    function test_ApproveAndSwapAlgebra_EncodeSwapData_RoundTrip() public view {
        bytes memory payload = bytes.concat(bytes20(deployer), bytes32(deadline), bytes32(uint256(limitSqrtPrice)));

        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: tokenIn,
            outputToken: tokenOut,
            inputAmount: originalAmountIn,
            outputQuote: 0,
            outputMin: originalMinAmountOut,
            usePrevHookAmount: false
        });

        bytes memory encoded = approveAndSwapHook.encodeSwapData(header, payload);

        assertEq(approveAndSwapHook.decodeInputToken(encoded), tokenIn);
        assertEq(approveAndSwapHook.decodeOutputToken(encoded), tokenOut);
        assertEq(approveAndSwapHook.decodeInputAmount(encoded), originalAmountIn);
        assertEq(approveAndSwapHook.decodeOutputQuote(encoded), 0);
        assertEq(approveAndSwapHook.decodeOutputMin(encoded), originalMinAmountOut);

        bytes memory decodedPayload = approveAndSwapHook.decodePayload(encoded);
        assertEq(decodedPayload.length, 84);
    }

    function test_SwapAlgebra_EncodeDecodeUsePrevHookAmount_True() public view {
        bytes memory payload = bytes.concat(bytes20(deployer), bytes32(deadline), bytes32(uint256(limitSqrtPrice)));

        ISuperHookSwap.SwapHeader memory header = ISuperHookSwap.SwapHeader({
            inputToken: tokenIn,
            outputToken: tokenOut,
            inputAmount: originalAmountIn,
            outputQuote: 0,
            outputMin: originalMinAmountOut,
            usePrevHookAmount: true
        });

        bytes memory encoded = swapHook.encodeSwapData(header, payload);
        assertTrue(swapHook.decodeUsePrevHookAmount(encoded));
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
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
        }

        // amountIn should always be prevAmount when usePrevHookAmount is true
        assertEq(decodedAmountIn, prevAmount);
    }

    function testFuzz_SwapHook_DataLength(uint8 extraBytes) public view {
        // Test with various data lengths >= 305
        bytes memory baseData = _buildHookData(false);
        bytes memory extraData = new bytes(extraBytes);
        bytes memory data = bytes.concat(baseData, extraData);

        // Should not revert for any length >= 305
        Execution[] memory executions = swapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 3);
    }

    function testFuzz_ApproveAndSwapHook_SlippageRecalculation(
        uint256 originalAmount,
        uint256 originalMinOut,
        uint256 prevAmount
    )
        public
    {
        originalAmount = bound(originalAmount, 1, type(uint128).max);
        originalMinOut = bound(originalMinOut, 1, type(uint128).max);
        prevAmount = bound(prevAmount, 1, type(uint128).max);

        bytes memory data = _buildHookDataCustomAmounts(originalAmount, originalMinOut, true);
        prevHook.setOutAmount(prevAmount, account);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);

        bytes memory swapCalldata = executions[3].callData;
        uint256 decodedAmountIn;
        assembly ("memory-safe") {
            decodedAmountIn := mload(add(swapCalldata, 196))
        }

        assertEq(decodedAmountIn, prevAmount);
    }

    function testFuzz_ApproveAndSwapHook_DataLength(uint8 extraBytes) public view {
        bytes memory baseData = _buildHookData(false);
        bytes memory extraData = new bytes(extraBytes);
        bytes memory data = bytes.concat(baseData, extraData);

        Execution[] memory executions = approveAndSwapHook.build(address(prevHook), account, data);
        assertEq(executions.length, 6);
    }

    /*//////////////////////////////////////////////////////////////
                              Helpers
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds standard 305-byte hook data (3-layer calldata standard)
    /// Layout:
    ///   [0:52]    Layer 0 placeholder
    ///   [52:72]   inputToken
    ///   [72:92]   outputToken
    ///   [92:124]  inputAmount      (AMOUNT_POSITION = 92)
    ///   [124:156] outputQuote      (0 for AMMs)
    ///   [156:188] outputMin
    ///   [188]     usePrevHookAmount
    ///   [189:221] payloadLength = 84
    ///   [221:241] deployer
    ///   [241:273] deadline
    ///   [273:305] limitSqrtPrice
    function _buildHookData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn), // [52:72]
            bytes20(tokenOut), // [72:92]
            bytes32(originalAmountIn), // [92:124] inputAmount
            bytes32(uint256(0)), // [124:156] outputQuote (0 for AMMs)
            bytes32(originalMinAmountOut), // [156:188] outputMin
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00), // [188]
            bytes32(uint256(84)), // [189:221] payloadLength
            bytes20(deployer), // [221:241]
            bytes32(deadline), // [241:273]
            bytes32(uint256(limitSqrtPrice)) // [273:305]
        );
    }

    function _buildHookDataWithDeployer(address _deployer) internal view returns (bytes memory) {
        return bytes.concat(
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(originalAmountIn),
            bytes32(uint256(0)),
            bytes32(originalMinAmountOut),
            bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(_deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
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
            bytes(new bytes(52)),
            bytes20(tokenIn),
            bytes20(tokenOut),
            bytes32(_amountIn),
            bytes32(uint256(0)),
            bytes32(_minAmountOut),
            _usePrevHookAmount ? bytes1(0x01) : bytes1(0x00),
            bytes32(uint256(84)),
            bytes20(deployer),
            bytes32(deadline),
            bytes32(uint256(limitSqrtPrice))
        );
    }
}
