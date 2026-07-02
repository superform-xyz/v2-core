// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test } from "forge-std/Test.sol";

// Superform imports
import { SwapUniswapV3Hook } from "../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol";
import { ApproveAndSwapUniswapV3Hook } from "../../../src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol";
import { MockSuperVaultStrategy } from "../../mocks/MockSuperVaultStrategy.sol";
import { Constants } from "../../utils/Constants.sol";

import "forge-std/console2.sol";

/// @title UniswapV3SuperVaultIntegrationTest
/// @author Superform Labs
/// @notice Integration tests for Uniswap V3 swap hooks using MockSuperVaultStrategy.executeHooks
/// @dev Tests swap functionality via a mocked SuperVault strategy to simulate real vault manager flows
contract UniswapV3SuperVaultIntegrationTest is Test, Constants {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to avoid stack too deep in swap tests
    struct SwapTestParams {
        uint256 sellAmount;
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        uint256 expectedMinOut;
        uint256 initialTokenInBalance;
        uint256 initialTokenOutBalance;
        uint256 finalTokenInBalance;
        uint256 finalTokenOutBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    MockSuperVaultStrategy public mockVault;
    SwapUniswapV3Hook public swapHook;
    ApproveAndSwapUniswapV3Hook public approveAndSwapHook;

    address public manager;

    // Uniswap V3 fee tiers
    uint24 public constant FEE_LOW = 500; // 0.05%
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    uint24 public constant FEE_HIGH = 10_000; // 1%

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY));

        // Setup manager
        manager = makeAddr("vaultManager");

        // Deploy mock SuperVault strategy
        mockVault = new MockSuperVaultStrategy(manager);

        // Deploy hooks with real Uniswap V3 SwapRouter
        swapHook = new SwapUniswapV3Hook(MAINNET_V3_SWAP_ROUTER);
        approveAndSwapHook = new ApproveAndSwapUniswapV3Hook(MAINNET_V3_SWAP_ROUTER);

        console2.log("MockSuperVaultStrategy deployed at:", address(mockVault));
        console2.log("SwapUniswapV3Hook deployed at:", address(swapHook));
        console2.log("ApproveAndSwapUniswapV3Hook deployed at:", address(approveAndSwapHook));
        console2.log("Manager:", manager);
    }

    // CRITICAL: Integration test contracts MUST include receive() for potential ETH refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook data for Uniswap V3 swap
    /// @param tokenIn Input token address
    /// @param tokenOut Output token address
    /// @param fee Pool fee tier
    /// @param recipient Recipient of output tokens
    /// @param deadline Transaction deadline
    /// @param sqrtPriceLimitX96 Price limit for the swap
    /// @param amountIn Amount of input tokens
    /// @param amountOutMinimum Minimum output amount
    /// @param usePrevHookAmount Whether to use previous hook's output
    function _buildHookData(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        address recipient,
        uint256 deadline,
        uint160 sqrtPriceLimitX96,
        uint256 amountIn,
        uint256 amountOutMinimum,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0), // 32 bytes: yieldSourceOracleId (header)
            address(0), // 20 bytes: yieldSource (header)
            tokenIn, // 20 bytes (offset 52)
            tokenOut, // 20 bytes (offset 72)
            uint32(fee), // 4 bytes (offset 92, using uint32 for fee encoding)
            recipient, // 20 bytes (offset 96)
            deadline, // 32 bytes (offset 116)
            uint256(sqrtPriceLimitX96), // 32 bytes (offset 148)
            amountIn, // 32 bytes (offset 180)
            amountOutMinimum, // 32 bytes (offset 212)
            usePrevHookAmount // 1 byte (offset 244)
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SUPERVAULT EXECUTEHOOKS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test successful USDC -> WETH swap using executeHooks
    function test_SuperVault_executeHooks_USDC_to_WETH() public {
        console2.log("=== SuperVault executeHooks USDC -> WETH Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1000e6; // 1000 USDC
        params.tokenIn = CHAIN_1_USDC;
        params.tokenOut = CHAIN_1_WETH;
        params.fee = FEE_MEDIUM;
        params.recipient = address(mockVault); // Vault receives the tokens
        params.deadline = block.timestamp + 1 hours;
        params.sqrtPriceLimitX96 = 0; // No price limit
        params.expectedMinOut = 0.2 ether; // Expect at least ~0.2 WETH (conservative)

        // Fund the mock vault with USDC
        deal(CHAIN_1_USDC, address(mockVault), params.sellAmount);

        // Get initial balances
        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(address(mockVault));
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(address(mockVault));

        console2.log("Initial USDC balance:", params.initialTokenInBalance);
        console2.log("Initial WETH balance:", params.initialTokenOutBalance);

        // Build hook data
        bytes memory hookData = _buildHookData(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.recipient,
            params.deadline,
            params.sqrtPriceLimitX96,
            params.sellAmount,
            params.expectedMinOut,
            false // usePrevHookAmount
        );

        // Build executeHooks args
        address[] memory hooks = new address[](1);
        hooks[0] = address(approveAndSwapHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = params.expectedMinOut;

        MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut
        });

        // Execute hooks as manager
        vm.prank(manager);
        mockVault.executeHooks(args);

        // Verify swap results
        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(address(mockVault));
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(address(mockVault));

        console2.log("Final USDC balance:", params.finalTokenInBalance);
        console2.log("Final WETH balance:", params.finalTokenOutBalance);

        // Calculate amounts
        uint256 usdcSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 wethReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        console2.log("USDC spent:", usdcSpent);
        console2.log("WETH received:", wethReceived);

        // Verify swap executed correctly
        assertEq(usdcSpent, params.sellAmount, "Should spend exact USDC amount");
        assertGt(wethReceived, 0, "Should receive some WETH");
        assertGe(wethReceived, params.expectedMinOut, "Should receive at least minimum WETH");

        console2.log("SuperVault executeHooks USDC -> WETH test passed");
    }

    /// @notice Test successful WETH -> USDC swap using executeHooks
    function test_SuperVault_executeHooks_WETH_to_USDC() public {
        console2.log("=== SuperVault executeHooks WETH -> USDC Test ===");

        SwapTestParams memory params;
        params.sellAmount = 1 ether; // 1 WETH
        params.tokenIn = CHAIN_1_WETH;
        params.tokenOut = CHAIN_1_USDC;
        params.fee = FEE_MEDIUM;
        params.recipient = address(mockVault);
        params.deadline = block.timestamp + 1 hours;
        params.sqrtPriceLimitX96 = 0;
        params.expectedMinOut = 1000e6; // Expect at least 1000 USDC (conservative)

        // Fund the mock vault with WETH
        deal(CHAIN_1_WETH, address(mockVault), params.sellAmount);

        // Get initial balances
        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(address(mockVault));
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(address(mockVault));

        console2.log("Initial WETH balance:", params.initialTokenInBalance);
        console2.log("Initial USDC balance:", params.initialTokenOutBalance);

        // Build hook data
        bytes memory hookData = _buildHookData(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.recipient,
            params.deadline,
            params.sqrtPriceLimitX96,
            params.sellAmount,
            params.expectedMinOut,
            false
        );

        // Build executeHooks args
        address[] memory hooks = new address[](1);
        hooks[0] = address(approveAndSwapHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = params.expectedMinOut;

        MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut
        });

        // Execute hooks as manager
        vm.prank(manager);
        mockVault.executeHooks(args);

        // Verify swap results
        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(address(mockVault));
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(address(mockVault));

        console2.log("Final WETH balance:", params.finalTokenInBalance);
        console2.log("Final USDC balance:", params.finalTokenOutBalance);

        // Calculate amounts
        uint256 wethSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 usdcReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        console2.log("WETH spent:", wethSpent);
        console2.log("USDC received:", usdcReceived);

        // Verify swap executed correctly
        assertEq(wethSpent, params.sellAmount, "Should spend exact WETH amount");
        assertGt(usdcReceived, 0, "Should receive some USDC");
        assertGe(usdcReceived, params.expectedMinOut, "Should receive at least minimum USDC");

        console2.log("SuperVault executeHooks WETH -> USDC test passed");
    }

    /// @notice Test executeHooks with different fee tiers
    function test_SuperVault_executeHooks_DifferentFeeTiers() public {
        console2.log("=== SuperVault executeHooks Different Fee Tiers Test ===");

        uint256 sellAmount = 0.1 ether; // 0.1 WETH
        uint256 expectedMinOut = 100e6; // Expect at least 100 USDC

        // Fund the mock vault with WETH
        deal(CHAIN_1_WETH, address(mockVault), sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));
        uint256 initialUSDC = IERC20(CHAIN_1_USDC).balanceOf(address(mockVault));

        // Build hook data with low fee tier (0.05%)
        bytes memory hookData = _buildHookData(
            CHAIN_1_WETH,
            CHAIN_1_USDC,
            FEE_LOW, // 0.05% fee tier
            address(mockVault),
            block.timestamp + 1 hours,
            0,
            sellAmount,
            expectedMinOut,
            false
        );

        // Build executeHooks args
        address[] memory hooks = new address[](1);
        hooks[0] = address(approveAndSwapHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = expectedMinOut;

        MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut
        });

        // Execute hooks as manager
        vm.prank(manager);
        mockVault.executeHooks(args);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));
        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(address(mockVault));

        assertLt(finalWETH, initialWETH, "Should spend WETH");
        assertGt(finalUSDC, initialUSDC, "Should receive USDC");

        console2.log("SuperVault executeHooks fee tier test passed");
    }

    /// @notice Test executeHooks with hook chaining (usePrevHookAmount)
    function test_SuperVault_executeHooks_HookChaining() public {
        console2.log("=== SuperVault executeHooks Hook Chaining Test ===");

        uint256 mockPrevAmount = 500e6; // 500 USDC from previous hook

        // Fund the mock vault with USDC
        deal(CHAIN_1_USDC, address(mockVault), mockPrevAmount);

        // Create mock previous hook
        MockPrevHookForVault mockPrevHook = new MockPrevHookForVault(mockPrevAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));

        // Build swap hook data with usePrevHookAmount = true
        bytes memory swapHookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            address(mockVault),
            block.timestamp + 1 hours,
            0,
            1000e6, // originalAmountIn (different from actual)
            0.1 ether, // originalMinAmountOut
            true // usePrevHookAmount = true
        );

        // Build executeHooks args with two hooks
        address[] memory hooks = new address[](2);
        hooks[0] = address(mockPrevHook);
        hooks[1] = address(approveAndSwapHook);

        bytes[] memory hookCalldata = new bytes[](2);
        hookCalldata[0] = ""; // Mock hook needs no data
        hookCalldata[1] = swapHookData;

        uint256[] memory expectedOut = new uint256[](2);
        expectedOut[0] = mockPrevAmount; // Mock hook outputs this
        expectedOut[1] = 0.05 ether; // Expect some WETH (recalculated based on 500 USDC input)

        MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut
        });

        // Execute hooks as manager
        vm.prank(manager);
        mockVault.executeHooks(args);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));

        // Should receive WETH based on mockPrevAmount (500 USDC), not originalAmountIn (1000 USDC)
        assertGt(finalWETH, initialWETH, "Should receive WETH");

        console2.log("WETH received:", finalWETH - initialWETH);
        console2.log("SuperVault executeHooks hook chaining test passed");
    }

    /// @notice Test executeHooks reverts when output is below minimum
    function test_SuperVault_executeHooks_RevertsOnSlippageViolation() public {
        console2.log("=== SuperVault executeHooks Slippage Revert Test ===");

        uint256 sellAmount = 1000e6; // 1000 USDC
        uint256 impossibleMinOut = 1000 ether; // Impossible: expecting 1000 ETH for 1000 USDC

        // Fund the mock vault with USDC
        deal(CHAIN_1_USDC, address(mockVault), sellAmount);

        // Build hook data with impossible minimum output
        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            address(mockVault),
            block.timestamp + 1 hours,
            0,
            sellAmount,
            impossibleMinOut, // Impossible minimum
            false
        );

        // Build executeHooks args
        address[] memory hooks = new address[](1);
        hooks[0] = address(approveAndSwapHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = impossibleMinOut; // This check will also fail in the mock vault

        MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut
        });

        // Expect revert due to minimum output not met
        vm.prank(manager);
        vm.expectRevert(); // Could be from Uniswap router or MockSuperVaultStrategy
        mockVault.executeHooks(args);

        console2.log("SuperVault executeHooks slippage revert test passed");
    }

    /// @notice Test executeHooks with multiple sequential swaps
    function test_SuperVault_executeHooks_MultipleSequentialSwaps() public {
        console2.log("=== SuperVault executeHooks Multiple Sequential Swaps Test ===");

        // First swap: USDC -> WETH
        uint256 usdcAmount = 2000e6;
        deal(CHAIN_1_USDC, address(mockVault), usdcAmount);

        bytes memory hookData1 = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            address(mockVault),
            block.timestamp + 1 hours,
            0,
            usdcAmount,
            0.4 ether, // Expect ~0.4 WETH
            false
        );

        // First execution
        {
            address[] memory hooks = new address[](1);
            hooks[0] = address(approveAndSwapHook);

            bytes[] memory hookCalldata = new bytes[](1);
            hookCalldata[0] = hookData1;

            uint256[] memory expectedOut = new uint256[](1);
            expectedOut[0] = 0.4 ether;

            MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
                hooks: hooks,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: expectedOut
            });

            vm.prank(manager);
            mockVault.executeHooks(args);
        }

        uint256 wethAfterFirst = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));
        console2.log("WETH after first swap:", wethAfterFirst);
        assertGt(wethAfterFirst, 0, "Should have WETH after first swap");

        // Second swap: WETH -> USDC (swap half back)
        uint256 wethToSwap = wethAfterFirst / 2;
        bytes memory hookData2 = _buildHookData(
            CHAIN_1_WETH,
            CHAIN_1_USDC,
            FEE_MEDIUM,
            address(mockVault),
            block.timestamp + 1 hours,
            0,
            wethToSwap,
            500e6, // Expect at least 500 USDC
            false
        );

        // Second execution
        {
            address[] memory hooks = new address[](1);
            hooks[0] = address(approveAndSwapHook);

            bytes[] memory hookCalldata = new bytes[](1);
            hookCalldata[0] = hookData2;

            uint256[] memory expectedOut = new uint256[](1);
            expectedOut[0] = 500e6;

            MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
                hooks: hooks,
                hookCalldata: hookCalldata,
                expectedAssetsOrSharesOut: expectedOut
            });

            vm.prank(manager);
            mockVault.executeHooks(args);
        }

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));
        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(address(mockVault));

        console2.log("Final WETH balance:", finalWETH);
        console2.log("Final USDC balance:", finalUSDC);

        assertGt(finalWETH, 0, "Should have remaining WETH");
        assertGt(finalUSDC, 0, "Should have USDC after swap back");

        console2.log("SuperVault executeHooks multiple swaps test passed");
    }

    /// @notice Test outAmount tracking is correct after executeHooks
    function test_SuperVault_executeHooks_OutAmountTracking() public {
        console2.log("=== SuperVault executeHooks OutAmount Tracking Test ===");

        uint256 sellAmount = 1000e6;
        deal(CHAIN_1_USDC, address(mockVault), sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));

        bytes memory hookData = _buildHookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            address(mockVault),
            block.timestamp + 1 hours,
            0,
            sellAmount,
            0.2 ether,
            false
        );

        address[] memory hooks = new address[](1);
        hooks[0] = address(approveAndSwapHook);

        bytes[] memory hookCalldata = new bytes[](1);
        hookCalldata[0] = hookData;

        uint256[] memory expectedOut = new uint256[](1);
        expectedOut[0] = 0.2 ether;

        MockSuperVaultStrategy.ExecuteArgs memory args = MockSuperVaultStrategy.ExecuteArgs({
            hooks: hooks,
            hookCalldata: hookCalldata,
            expectedAssetsOrSharesOut: expectedOut
        });

        vm.prank(manager);
        mockVault.executeHooks(args);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(address(mockVault));
        uint256 wethReceived = finalWETH - initialWETH;

        // Verify the hook's outAmount matches actual balance change
        uint256 hookOutAmount = approveAndSwapHook.getOutAmount(address(mockVault));

        console2.log("WETH received (balance):", wethReceived);
        console2.log("Hook outAmount:", hookOutAmount);

        assertEq(hookOutAmount, wethReceived, "Hook outAmount should match balance change");

        console2.log("SuperVault executeHooks outAmount tracking test passed");
    }
}

/// @notice Mock contract to simulate previous hook returning specific amounts for vault context
/// @dev Simplified version that works with MockSuperVaultStrategy
contract MockPrevHookForVault {
    uint256 private _outAmount;
    address private _lastCaller;

    constructor(uint256 outAmount_) {
        _outAmount = outAmount_;
    }

    function setExecutionContext(address caller) external {
        _lastCaller = caller;
    }

    function build(address, address account, bytes calldata) external view returns (Execution[] memory executions) {
        // Return pre + post execute calls
        executions = new Execution[](2);
        executions[0] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.preExecute, (address(0), account, ""))
        });
        executions[1] = Execution({
            target: address(this),
            value: 0,
            callData: abi.encodeCall(this.postExecute, (address(0), account, ""))
        });
    }

    function preExecute(address, address, bytes calldata) external {
        // Nothing to do
    }

    function postExecute(address, address, bytes calldata) external {
        // Nothing to do - outAmount is already set
    }

    function resetExecutionState(address) external {
        // Nothing to reset
    }

    function getOutAmount(address) external view returns (uint256) {
        return _outAmount;
    }

    function lastCaller() external view returns (address) {
        return _lastCaller;
    }
}

// Import Execution struct for MockPrevHookForVault
import { Execution } from "../../../src/interfaces/ISuperHook.sol";
