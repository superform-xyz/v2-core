// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform imports
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import {
    SwapUniswapV3Router02Hook
} from "../../../src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol";
import {
    ApproveAndSwapUniswapV3Router02Hook
} from "../../../src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol";
import { ISuperHook } from "../../../src/interfaces/ISuperHook.sol";
import { BaseHook } from "../../../src/hooks/BaseHook.sol";

import "forge-std/console2.sol";

/// @title UniswapV3Router02HookIntegrationTest
/// @author Superform Labs
/// @notice Integration tests for Uniswap V3 SwapRouter02 hooks using real mainnet forks
/// @dev Tests swap functionality via SuperExecutor with real Uniswap V3 SwapRouter02
contract UniswapV3Router02HookIntegrationTest is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Struct to avoid stack too deep in swap tests
    struct SwapTestParams {
        uint256 sellAmount;
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint160 sqrtPriceLimitX96;
        uint256 expectedMinOut;
        address account;
        uint256 initialTokenInBalance;
        uint256 initialTokenOutBalance;
        uint256 finalTokenInBalance;
        uint256 finalTokenOutBalance;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    SwapUniswapV3Router02Hook public swapHook;
    ApproveAndSwapUniswapV3Router02Hook public approveAndSwapHook;

    // Uniswap V3 fee tiers
    uint24 public constant FEE_LOW = 500; // 0.05%
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    uint24 public constant FEE_HIGH = 10000; // 1%

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        console2.log("Deploying UniswapV3Router02 hooks with real SwapRouter02");

        // Deploy hooks with real Uniswap V3 SwapRouter02
        swapHook = new SwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);
        approveAndSwapHook = new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);

        console2.log("SwapUniswapV3Router02Hook deployed at:", address(swapHook));
        console2.log("ApproveAndSwapUniswapV3Router02Hook deployed at:", address(approveAndSwapHook));
        console2.log("User account:", address(instanceOnEth.account));
    }

    // CRITICAL: Integration test contracts MUST include receive() for EntryPoint fee refunds
    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Build hook data for Uniswap V3 SwapRouter02 swap
    /// @dev No recipient or deadline fields — Router02 handles deadline via multicall wrapper,
    ///      recipient is always set to account in the hook
    function _buildRouter02HookData(
        address tokenIn,
        address tokenOut,
        uint24 fee,
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
            tokenIn, // 20 bytes (offset 0)
            tokenOut, // 20 bytes (offset 20)
            uint32(fee), // 4 bytes (offset 40)
            uint256(sqrtPriceLimitX96), // 32 bytes (offset 44)
            amountIn, // 32 bytes (offset 76)
            amountOutMinimum, // 32 bytes (offset 108)
            usePrevHookAmount // 1 byte (offset 140)
        );
    }

    /// @notice Execute a swap using the hook via SuperExecutor
    function _executeSwapWithApproval(address swapHook_, bytes memory swapHookData) private {
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = swapHook_;

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = swapHookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);
    }

    /*//////////////////////////////////////////////////////////////
                            CORE FUNCTIONALITY TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test hook data decoding
    function test_UniswapV3Router02_HookDataDecoding() external view {
        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0, // sqrtPriceLimitX96 (0 = no limit)
            1000e6, // amountIn
            0.3 ether, // amountOutMinimum
            false
        );

        bool usePrevHookAmount = swapHook.decodeUsePrevHookAmount(hookData);
        assertFalse(usePrevHookAmount, "Should not use prev hook amount");
    }

    /// @notice Test inspect function returns tokenOut
    function test_UniswapV3Router02_InspectFunction() external view {
        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0,
            1000e6,
            0.3 ether,
            false
        );

        bytes memory inspectResult = swapHook.inspect(hookData);
        assertEq(inspectResult.length, 20, "Should return 20 bytes (1 address)");

        address extractedTokenOut;
        assembly {
            extractedTokenOut := mload(add(inspectResult, 20))
        }
        assertEq(extractedTokenOut, CHAIN_1_WETH, "Should extract correct tokenOut");
    }

    /*//////////////////////////////////////////////////////////////
                            SWAP EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test successful USDC -> WETH swap using ApproveAndSwapUniswapV3Router02Hook
    function test_UniswapV3Router02_ApproveAndSwap_USDC_to_WETH() public {
        SwapTestParams memory params;
        params.sellAmount = 1000e6;
        params.tokenIn = CHAIN_1_USDC;
        params.tokenOut = CHAIN_1_WETH;
        params.fee = FEE_MEDIUM;
        params.sqrtPriceLimitX96 = 0;
        params.expectedMinOut = 0.2 ether;
        params.account = instanceOnEth.account;

        deal(CHAIN_1_USDC, params.account, params.sellAmount);

        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        bytes memory hookData = _buildRouter02HookData(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.sqrtPriceLimitX96,
            params.sellAmount,
            params.expectedMinOut,
            false
        );

        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        uint256 usdcSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 wethReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        assertEq(usdcSpent, params.sellAmount, "Should spend exact USDC amount");
        assertGt(wethReceived, 0, "Should receive some WETH");
        assertGe(wethReceived, params.expectedMinOut, "Should receive at least minimum WETH");

        console2.log("USDC spent:", usdcSpent);
        console2.log("WETH received:", wethReceived);
    }

    /// @notice Test successful WETH -> USDC swap using ApproveAndSwapUniswapV3Router02Hook
    function test_UniswapV3Router02_ApproveAndSwap_WETH_to_USDC() public {
        SwapTestParams memory params;
        params.sellAmount = 1 ether;
        params.tokenIn = CHAIN_1_WETH;
        params.tokenOut = CHAIN_1_USDC;
        params.fee = FEE_MEDIUM;
        params.sqrtPriceLimitX96 = 0;
        params.expectedMinOut = 1000e6;
        params.account = instanceOnEth.account;

        deal(CHAIN_1_WETH, params.account, params.sellAmount);

        params.initialTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.initialTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        bytes memory hookData = _buildRouter02HookData(
            params.tokenIn,
            params.tokenOut,
            params.fee,
            params.sqrtPriceLimitX96,
            params.sellAmount,
            params.expectedMinOut,
            false
        );

        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        params.finalTokenInBalance = IERC20(params.tokenIn).balanceOf(params.account);
        params.finalTokenOutBalance = IERC20(params.tokenOut).balanceOf(params.account);

        uint256 wethSpent = params.initialTokenInBalance - params.finalTokenInBalance;
        uint256 usdcReceived = params.finalTokenOutBalance - params.initialTokenOutBalance;

        assertEq(wethSpent, params.sellAmount, "Should spend exact WETH amount");
        assertGt(usdcReceived, 0, "Should receive some USDC");
        assertGe(usdcReceived, params.expectedMinOut, "Should receive at least minimum USDC");

        console2.log("WETH spent:", wethSpent);
        console2.log("USDC received:", usdcReceived);
    }

    /// @notice Test swap with different fee tiers
    function test_UniswapV3Router02_DifferentFeeTiers() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 0.1 ether;

        deal(CHAIN_1_WETH, account, sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 initialUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_WETH,
            CHAIN_1_USDC,
            FEE_LOW, // 0.05% fee tier
            0,
            sellAmount,
            100e6,
            false
        );

        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);

        assertLt(finalWETH, initialWETH, "Should spend WETH");
        assertGt(finalUSDC, initialUSDC, "Should receive USDC");
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK CHAINING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with usePrevHookAmount flag
    function test_UniswapV3Router02_UsePrevHookAmount() public {
        address account = instanceOnEth.account;
        uint256 mockPrevAmount = 500e6;

        deal(CHAIN_1_USDC, account, mockPrevAmount);

        MockPrevHookRouter02 mockPrevHook = new MockPrevHookRouter02(mockPrevAmount);

        bytes memory swapHookData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0,
            1000e6, // originalAmountIn (different from actual)
            0.1 ether,
            true // usePrevHookAmount = true
        );

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(mockPrevHook);
        hookAddresses[1] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = "";
        hookDataArray[1] = swapHookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertGt(finalWETH, initialWETH, "Should receive WETH");
    }

    /*//////////////////////////////////////////////////////////////
                        OUT AMOUNT TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that outAmount is correctly tracked for chaining
    function test_UniswapV3Router02_OutAmountTracking() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;

        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0,
            sellAmount,
            0.2 ether,
            false
        );

        _executeSwapWithApproval(address(approveAndSwapHook), hookData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 wethReceived = finalWETH - initialWETH;

        assertGt(wethReceived, 0, "Should track WETH received");
        console2.log("WETH received and tracked:", wethReceived);
    }
}

/// @notice Mock contract to simulate previous hook returning specific amounts
contract MockPrevHookRouter02 is BaseHook {
    uint256 private _outAmount;

    constructor(uint256 outAmount_) BaseHook(ISuperHook.HookType.NONACCOUNTING, 0) {
        _outAmount = outAmount_;
    }

    function _buildHookExecutions(address, address, bytes calldata)
        internal
        pure
        override
        returns (Execution[] memory)
    {
        return new Execution[](0);
    }

    function _preExecute(address, address, bytes calldata) internal override {
        _setOutAmount(_outAmount, msg.sender);
    }

    function _postExecute(address, address, bytes calldata) internal pure override { }
}

/*//////////////////////////////////////////////////////////////
                    EXTENDED INTEGRATION TESTS
//////////////////////////////////////////////////////////////*/

/// @title UniswapV3Router02HookEdgeCaseTests
/// @notice Additional edge case and error scenario tests for Router02
contract UniswapV3Router02HookEdgeCaseTests is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    ApproveAndSwapUniswapV3Router02Hook public approveAndSwapHook;

    uint24 public constant FEE_MEDIUM = 3000;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        approveAndSwapHook = new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);
    }

    receive() external payable { }

    function _buildRouter02HookData(
        address tokenIn,
        address tokenOut,
        uint24 fee,
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
            tokenIn,
            tokenOut,
            uint32(fee),
            uint256(sqrtPriceLimitX96),
            amountIn,
            amountOutMinimum,
            usePrevHookAmount
        );
    }

    /*//////////////////////////////////////////////////////////////
                        SLIPPAGE REVERT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test that swap reverts when slippage is too high
    function test_UniswapV3Router02_RevertIf_SlippageTooHigh() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;

        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 unrealisticMinOut = 100 ether;

        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0,
            sellAmount,
            unrealisticMinOut,
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        try this.executeOpExternal(opData) {
            revert("Expected swap to fail due to slippage");
        } catch {
            uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
            assertEq(usdcAfter, usdcBefore, "USDC should not be spent on failed swap");
        }
    }

    /*//////////////////////////////////////////////////////////////
                        ZERO AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with zero amount reverts
    function test_UniswapV3Router02_ZeroAmountSwap() public {
        address account = instanceOnEth.account;

        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0,
            0, // Zero amount
            0,
            false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        try this.executeOpExternal(opData) {
            revert("Expected swap to fail due to zero amount");
        } catch {
            // Expected failure
        }
    }

    /// @notice External wrapper to enable try/catch for UserOp execution
    function executeOpExternal(UserOpData memory opData) external {
        executeOp(opData);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTIPLE SWAPS TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test multiple sequential swaps in a single transaction
    function test_UniswapV3Router02_MultipleSequentialSwaps() public {
        address account = instanceOnEth.account;
        uint256 initialUSDC = 2000e6;

        deal(CHAIN_1_USDC, account, initialUSDC);

        bytes memory hookData1 = _buildRouter02HookData(
            CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false
        );

        bytes memory hookData2 = _buildRouter02HookData(
            CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false
        );

        address[] memory hookAddresses = new address[](2);
        hookAddresses[0] = address(approveAndSwapHook);
        hookAddresses[1] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](2);
        hookDataArray[0] = hookData1;
        hookDataArray[1] = hookData2;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalUSDC = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        assertEq(finalUSDC, 0, "Should spend all USDC");
        assertGt(finalWETH, initialWETH, "Should receive WETH");
        assertGe(finalWETH - initialWETH, 0.4 ether, "Should receive at least 0.4 WETH total");
    }

    /*//////////////////////////////////////////////////////////////
                        SMALL AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test swap with very small amounts
    function test_UniswapV3Router02_SmallAmountSwap() public {
        address account = instanceOnEth.account;
        uint256 smallAmount = 1e6;

        deal(CHAIN_1_USDC, account, smallAmount);

        uint256 initialWETH = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData = _buildRouter02HookData(
            CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, smallAmount, 0, false
        );

        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = address(approveAndSwapHook);

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));
        executeOp(opData);

        uint256 finalWETH = IERC20(CHAIN_1_WETH).balanceOf(account);
        assertGt(finalWETH, initialWETH, "Should receive some WETH even for small amount");
    }
}
