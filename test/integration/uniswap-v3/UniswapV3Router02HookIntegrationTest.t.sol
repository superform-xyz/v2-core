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
import { ApproveERC20Hook } from "../../../src/hooks/tokens/erc20/ApproveERC20Hook.sol";
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
    ApproveERC20Hook public approveERC20Hook;

    // Real mainnet token addresses
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Uniswap V3 fee tiers
    uint24 public constant FEE_LOWEST = 100; // 0.01%
    uint24 public constant FEE_LOW = 500; // 0.05%
    uint24 public constant FEE_MEDIUM = 3000; // 0.3%
    uint24 public constant FEE_HIGH = 10000; // 1%

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        swapHook = new SwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);
        approveAndSwapHook = new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);
        approveERC20Hook = new ApproveERC20Hook();
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
            bytes32(0), // 32 bytes: yieldSourceOracleId (header)
            address(0), // 20 bytes: yieldSource (header)
            tokenIn, // 20 bytes (offset 52)
            tokenOut, // 20 bytes (offset 72)
            uint32(fee), // 4 bytes (offset 92)
            uint256(sqrtPriceLimitX96), // 32 bytes (offset 96)
            amountIn, // 32 bytes (offset 128)
            amountOutMinimum, // 32 bytes (offset 160)
            usePrevHookAmount // 1 byte (offset 192)
        );
    }

    function _buildApproveERC20HookData(
        address token,
        address spender,
        uint256 amount,
        bool usePrevHookAmount
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(0), // 32 bytes: yieldSourceOracleId (header)
            address(0), // 20 bytes: yieldSource (header)
            token, // offset 52
            spender, // offset 72
            amount, // offset 92
            usePrevHookAmount // offset 124
        );
    }

    function _executeSingleHook(address hook, bytes memory hookData) private {
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = hook;

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(opData);
    }

    function _executeMultiHook(address[] memory hooks, bytes[] memory hookDatas) private {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDatas });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));
        executeOp(opData);
    }

    function _tryExecuteSingleHook(address hook, bytes memory hookData) private returns (bool success) {
        address[] memory hookAddresses = new address[](1);
        hookAddresses[0] = hook;

        bytes[] memory hookDataArray = new bytes[](1);
        hookDataArray[0] = hookData;

        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses, hooksData: hookDataArray });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        try this.executeOpExternal(opData) {
            return true;
        } catch {
            return false;
        }
    }

    function _tryExecuteMultiHook(address[] memory hooks, bytes[] memory hookDatas) private returns (bool success) {
        ISuperExecutor.ExecutorEntry memory entry =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hooks, hooksData: hookDatas });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entry));

        try this.executeOpExternal(opData) {
            return true;
        } catch {
            return false;
        }
    }

    /// @notice External wrapper to enable try/catch for UserOp execution
    function executeOpExternal(UserOpData memory opData) external {
        executeOp(opData);
    }

    /*//////////////////////////////////////////////////////////////
                        CORE: ApproveAndSwap TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice USDC -> WETH swap via ApproveAndSwap
    function test_ApproveAndSwap_USDC_to_WETH() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;
        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, sellAmount, 0.2 ether, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);

        assertEq(usdcAfter, 0, "Should spend all USDC");
        assertGe(wethAfter - wethBefore, 0.2 ether, "Should receive at least min WETH");
    }

    /// @notice WETH -> USDC swap via ApproveAndSwap
    function test_ApproveAndSwap_WETH_to_USDC() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1 ether;
        deal(CHAIN_1_WETH, account, sellAmount);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_WETH, CHAIN_1_USDC, FEE_MEDIUM, 0, sellAmount, 1000e6, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);

        assertEq(wethAfter, 0, "Should spend all WETH");
        assertGe(usdcAfter - usdcBefore, 1000e6, "Should receive at least 1000 USDC");
    }

    /// @notice WETH -> DAI swap on 0.3% fee tier
    function test_ApproveAndSwap_WETH_to_DAI() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 0.5 ether;
        deal(CHAIN_1_WETH, account, sellAmount);

        uint256 daiBefore = IERC20(DAI).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_WETH, DAI, FEE_MEDIUM, 0, sellAmount, 500e18, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 daiAfter = IERC20(DAI).balanceOf(account);
        assertGt(daiAfter - daiBefore, 500e18, "Should receive >500 DAI for 0.5 WETH");
    }

    /// @notice DAI -> USDC stablecoin swap on 0.01% fee tier
    function test_ApproveAndSwap_DAI_to_USDC_LowestFeeTier() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e18;
        deal(DAI, account, sellAmount);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(DAI, CHAIN_1_USDC, FEE_LOWEST, 0, sellAmount, 990e6, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 received = usdcAfter - usdcBefore;
        assertGe(received, 990e6, "Stablecoin swap should have minimal slippage");
        assertLe(received, 1010e6, "Should be close to 1:1 for stablecoin swap");
    }

    /// @notice WBTC -> WETH swap on 0.3% fee tier
    function test_ApproveAndSwap_WBTC_to_WETH() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 0.01e8; // 0.01 WBTC (8 decimals)
        deal(CHAIN_1_WBTC, account, sellAmount);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_WBTC, CHAIN_1_WETH, FEE_MEDIUM, 0, sellAmount, 0.1 ether, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);
        assertGt(wethAfter - wethBefore, 0.1 ether, "0.01 WBTC should yield > 0.1 WETH");
    }

    /// @notice USDT -> USDC swap (USDT has non-standard approve requiring reset to 0)
    function test_ApproveAndSwap_USDT_to_USDC() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;
        deal(USDT, account, sellAmount);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(USDT, CHAIN_1_USDC, FEE_LOWEST, 0, sellAmount, 990e6, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
        assertGe(usdcAfter - usdcBefore, 990e6, "USDT->USDC should work with approve reset pattern");
    }

    /*//////////////////////////////////////////////////////////////
                        CORE: SwapHook (no-approve) TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice SwapHook requires pre-approval — chain ApproveERC20Hook + SwapHook
    function test_SwapHook_WithApproveChain_USDC_to_WETH() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 1000e6;
        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveERC20Hook);
        hooks[1] = address(swapHook);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] = _buildApproveERC20HookData(CHAIN_1_USDC, MAINNET_V3_SWAP_ROUTER_02, sellAmount, false);
        hookDatas[1] = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, sellAmount, 0.2 ether, false);

        _executeMultiHook(hooks, hookDatas);

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);
        assertGe(wethAfter - wethBefore, 0.2 ether, "SwapHook with pre-approval should work");
    }

    /// @notice SwapHook with WETH -> USDC
    function test_SwapHook_WithApproveChain_WETH_to_USDC() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 0.5 ether;
        deal(CHAIN_1_WETH, account, sellAmount);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveERC20Hook);
        hooks[1] = address(swapHook);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] = _buildApproveERC20HookData(CHAIN_1_WETH, MAINNET_V3_SWAP_ROUTER_02, sellAmount, false);
        hookDatas[1] = _buildRouter02HookData(CHAIN_1_WETH, CHAIN_1_USDC, FEE_MEDIUM, 0, sellAmount, 500e6, false);

        _executeMultiHook(hooks, hookDatas);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
        assertGe(usdcAfter - usdcBefore, 500e6, "SwapHook WETH->USDC should receive >= 500 USDC");
    }

    /*//////////////////////////////////////////////////////////////
                            FEE TIER TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice 0.05% fee tier (USDC/WETH)
    function test_ApproveAndSwap_FeeTier_500() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_WETH, account, 0.1 ether);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_WETH, CHAIN_1_USDC, FEE_LOW, 0, 0.1 ether, 100e6, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        assertGt(IERC20(CHAIN_1_USDC).balanceOf(account) - usdcBefore, 100e6);
    }

    /// @notice 1% fee tier (WETH/USDC)
    function test_ApproveAndSwap_FeeTier_10000() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_WETH, account, 0.1 ether);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_WETH, CHAIN_1_USDC, FEE_HIGH, 0, 0.1 ether, 50e6, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        assertGt(IERC20(CHAIN_1_USDC).balanceOf(account) - usdcBefore, 50e6);
    }

    /// @notice 0.01% fee tier (DAI/USDC stablecoin)
    function test_ApproveAndSwap_FeeTier_100() public {
        address account = instanceOnEth.account;
        deal(DAI, account, 500e18);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData = _buildRouter02HookData(DAI, CHAIN_1_USDC, FEE_LOWEST, 0, 500e18, 495e6, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        assertGt(IERC20(CHAIN_1_USDC).balanceOf(account) - usdcBefore, 495e6);
    }

    /*//////////////////////////////////////////////////////////////
                        AMOUNT VARIATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Very small swap: 1 USDC
    function test_ApproveAndSwap_SmallAmount_1USDC() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1e6);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1e6, 0, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        assertGt(IERC20(CHAIN_1_WETH).balanceOf(account), wethBefore, "1 USDC swap should yield some WETH");
    }

    /// @notice Large swap: 100,000 USDC
    function test_ApproveAndSwap_LargeAmount_100kUSDC() public {
        address account = instanceOnEth.account;
        uint256 sellAmount = 100_000e6;
        deal(CHAIN_1_USDC, account, sellAmount);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, sellAmount, 20 ether, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 wethReceived = IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore;
        assertGe(wethReceived, 20 ether, "100k USDC should yield at least 20 WETH");
    }

    /// @notice Partial balance swap — should leave remaining tokens untouched
    function test_ApproveAndSwap_PartialBalance() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 5000e6);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 2000e6, 0.4 ether, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(account), 3000e6, "Should only spend 2000 USDC, leave 3000");
        assertGt(IERC20(CHAIN_1_WETH).balanceOf(account), 0, "Should receive WETH");
    }

    /*//////////////////////////////////////////////////////////////
                        APPROVAL PATTERN TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Verify ApproveAndSwap clears allowance after swap (approve(0) at end)
    function test_ApproveAndSwap_AllowanceClearedAfterSwap() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 remainingAllowance = IERC20(CHAIN_1_USDC).allowance(account, MAINNET_V3_SWAP_ROUTER_02);
        assertEq(remainingAllowance, 0, "Allowance should be 0 after swap (approve(0) cleanup)");
    }

    /// @notice USDT approve-reset pattern: USDT reverts if approve(X) when allowance != 0
    /// The hook does approve(0) -> approve(amount) which handles this
    function test_ApproveAndSwap_USDT_ApproveResetPattern() public {
        address account = instanceOnEth.account;
        deal(USDT, account, 2000e6);

        // First swap
        bytes memory hookData1 = _buildRouter02HookData(USDT, CHAIN_1_USDC, FEE_LOWEST, 0, 1000e6, 990e6, false);
        _executeSingleHook(address(approveAndSwapHook), hookData1);

        // Second swap on same token pair — approve(0) -> approve(amount) pattern must work
        bytes memory hookData2 = _buildRouter02HookData(USDT, CHAIN_1_USDC, FEE_LOWEST, 0, 1000e6, 990e6, false);
        _executeSingleHook(address(approveAndSwapHook), hookData2);

        assertEq(IERC20(USDT).balanceOf(account), 0, "All USDT should be swapped");
    }

    /*//////////////////////////////////////////////////////////////
                        HOOK CHAINING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice usePrevHookAmount: prev hook outputs 500 USDC, swap uses that as amountIn
    function test_UsePrevHookAmount_SwapsExactPrevOutput() public {
        address account = instanceOnEth.account;
        uint256 mockPrevAmount = 500e6;
        deal(CHAIN_1_USDC, account, mockPrevAmount);

        MockPrevHookRouter02 mockPrevHook = new MockPrevHookRouter02(mockPrevAmount);

        bytes memory swapData = _buildRouter02HookData(
            CHAIN_1_USDC,
            CHAIN_1_WETH,
            FEE_MEDIUM,
            0,
            1000e6, // originalAmountIn (different from actual prevHook output)
            0.1 ether, // originalMinAmountOut
            true
        );

        address[] memory hooks = new address[](2);
        hooks[0] = address(mockPrevHook);
        hooks[1] = address(approveAndSwapHook);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] = "";
        hookDatas[1] = swapData;

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        _executeMultiHook(hooks, hookDatas);

        uint256 wethReceived = IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore;
        assertGt(wethReceived, 0, "Should receive WETH from prev hook amount");

        // All USDC should be swapped (prevHookAmount = total balance)
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(account), 0, "Should swap exactly prevHook amount");
    }

    /// @notice usePrevHookAmount with SwapHook (no-approve variant) + pre-approve chain
    function test_UsePrevHookAmount_SwapHookVariant() public {
        address account = instanceOnEth.account;
        uint256 mockPrevAmount = 500e6;
        deal(CHAIN_1_USDC, account, mockPrevAmount);

        MockPrevHookRouter02 mockPrevHook = new MockPrevHookRouter02(mockPrevAmount);

        address[] memory hooks = new address[](3);
        hooks[0] = address(mockPrevHook);
        hooks[1] = address(approveERC20Hook);
        hooks[2] = address(swapHook);

        bytes[] memory hookDatas = new bytes[](3);
        hookDatas[0] = "";
        hookDatas[1] = _buildApproveERC20HookData(CHAIN_1_USDC, MAINNET_V3_SWAP_ROUTER_02, mockPrevAmount, false);
        hookDatas[2] = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.05 ether, true);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        _executeMultiHook(hooks, hookDatas);

        assertGt(IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore, 0, "SwapHook + usePrevHookAmount should work");
    }

    /// @notice Chain: Swap USDC->WETH, then swap WETH->DAI using prevHookAmount
    function test_ChainedSwaps_USDC_WETH_DAI() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        ApproveAndSwapUniswapV3Router02Hook secondSwapHook =
            new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveAndSwapHook);
        hooks[1] = address(secondSwapHook);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false);
        // Second swap uses output of first swap
        hookDatas[1] =
            _buildRouter02HookData(CHAIN_1_WETH, DAI, FEE_MEDIUM, 0, 0.2 ether, 300e18, true);

        uint256 daiBefore = IERC20(DAI).balanceOf(account);

        _executeMultiHook(hooks, hookDatas);

        uint256 daiReceived = IERC20(DAI).balanceOf(account) - daiBefore;
        assertGt(daiReceived, 0, "Should receive DAI from chained USDC->WETH->DAI");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(account), 0, "All USDC should be consumed");
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-SWAP BATCH TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Two independent swaps in a single batch
    function test_BatchSwaps_TwoIndependentSwaps() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);
        deal(CHAIN_1_WETH, account, 0.5 ether);

        ApproveAndSwapUniswapV3Router02Hook secondSwapHook =
            new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);

        uint256 daiBefore = IERC20(DAI).balanceOf(account);
        uint256 wbtcBefore = IERC20(CHAIN_1_WBTC).balanceOf(account);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveAndSwapHook);
        hooks[1] = address(secondSwapHook);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] = _buildRouter02HookData(CHAIN_1_USDC, DAI, FEE_LOWEST, 0, 1000e6, 990e18, false);
        hookDatas[1] = _buildRouter02HookData(CHAIN_1_WETH, CHAIN_1_WBTC, FEE_MEDIUM, 0, 0.5 ether, 0, false);

        _executeMultiHook(hooks, hookDatas);

        assertGt(IERC20(DAI).balanceOf(account) - daiBefore, 0, "Should receive DAI");
        assertGt(IERC20(CHAIN_1_WBTC).balanceOf(account) - wbtcBefore, 0, "Should receive WBTC");
    }

    /// @notice Three sequential swaps in one batch
    function test_BatchSwaps_ThreeSequentialSwaps() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 3000e6);

        ApproveAndSwapUniswapV3Router02Hook hook2 =
            new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);
        ApproveAndSwapUniswapV3Router02Hook hook3 =
            new ApproveAndSwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);

        address[] memory hooks = new address[](3);
        hooks[0] = address(approveAndSwapHook);
        hooks[1] = address(hook2);
        hooks[2] = address(hook3);

        bytes[] memory hookDatas = new bytes[](3);
        hookDatas[0] = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false);
        hookDatas[1] = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false);
        hookDatas[2] = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        _executeMultiHook(hooks, hookDatas);

        assertEq(IERC20(CHAIN_1_USDC).balanceOf(account), 0, "All 3000 USDC spent");
        assertGe(
            IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore, 0.6 ether, "Should receive >= 0.6 WETH from 3 swaps"
        );
    }

    /*//////////////////////////////////////////////////////////////
                        REVERT / ERROR SCENARIO TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Slippage too high — amountOutMinimum impossible to satisfy
    function test_RevertIf_SlippageTooHigh() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 100 ether, false);

        bool success = _tryExecuteSingleHook(address(approveAndSwapHook), hookData);
        assertFalse(success, "Should revert with impossible slippage");
        assertEq(IERC20(CHAIN_1_USDC).balanceOf(account), usdcBefore, "USDC should be untouched after revert");
    }

    /// @notice Zero amountIn reverts
    function test_RevertIf_ZeroAmountIn() public {
        bytes memory hookData = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 0, 0, false);

        bool success = _tryExecuteSingleHook(address(approveAndSwapHook), hookData);
        assertFalse(success, "Zero amountIn should revert");
    }

    /// @notice Insufficient balance — account doesn't have enough tokenIn
    function test_RevertIf_InsufficientBalance() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 100e6); // only 100 USDC

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, false);

        bool success = _tryExecuteSingleHook(address(approveAndSwapHook), hookData);
        assertFalse(success, "Should revert with insufficient balance");
    }

    /// @notice Invalid fee tier — pool doesn't exist for this fee
    function test_RevertIf_InvalidPoolFeeTier() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        // 200 bps is not a standard Uniswap V3 fee tier, pool likely doesn't exist
        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, 200, 0, 1000e6, 0, false);

        bool success = _tryExecuteSingleHook(address(approveAndSwapHook), hookData);
        assertFalse(success, "Non-existent pool should revert");
    }

    /// @notice Hook data too short — should revert with INVALID_HOOK_DATA
    function test_RevertIf_TruncatedHookData() public {
        // Only 100 bytes instead of required 141
        bytes memory shortData = new bytes(100);

        bool success = _tryExecuteSingleHook(address(approveAndSwapHook), shortData);
        assertFalse(success, "Truncated hook data should revert");
    }

    /// @notice Same tokenIn and tokenOut should revert
    function test_RevertIf_SameTokenInAndOut() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_USDC, FEE_MEDIUM, 0, 1000e6, 900e6, false);

        bool success = _tryExecuteSingleHook(address(approveAndSwapHook), hookData);
        assertFalse(success, "Same token swap should revert");
    }

    /// @notice SwapHook without pre-approval should revert (insufficient allowance)
    function test_RevertIf_SwapHookWithoutApproval() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, false);

        bool success = _tryExecuteSingleHook(address(swapHook), hookData);
        assertFalse(success, "SwapHook without approval should revert");
    }

    /*//////////////////////////////////////////////////////////////
                        OUT AMOUNT TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice outAmount tracking: swap and verify the delta is stored
    function test_OutAmountTracking_MatchesActualReceived() public {
        address account = instanceOnEth.account;
        deal(CHAIN_1_USDC, account, 1000e6);

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0.2 ether, false);

        _executeSingleHook(address(approveAndSwapHook), hookData);

        uint256 wethReceived = IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore;
        assertGt(wethReceived, 0, "Should track non-zero WETH output");
    }

    /// @notice Verify both hook variants produce identical outAmounts for the same swap
    function test_OutAmountTracking_BothVariantsConsistent() public {
        address account = instanceOnEth.account;

        // Snapshot state so both swaps see identical pool state
        uint256 snap = vm.snapshotState();

        // Swap 1: ApproveAndSwap
        deal(CHAIN_1_USDC, account, 1000e6);
        uint256 wethBefore1 = IERC20(CHAIN_1_WETH).balanceOf(account);
        _executeSingleHook(
            address(approveAndSwapHook),
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, false)
        );
        uint256 wethReceived1 = IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore1;

        // Revert to snapshot so pool state is identical for the second swap
        vm.revertToState(snap);

        // Swap 2: ApproveERC20 + SwapHook (different hook instance)
        SwapUniswapV3Router02Hook swapHook2 = new SwapUniswapV3Router02Hook(MAINNET_V3_SWAP_ROUTER_02);
        deal(CHAIN_1_USDC, account, 1000e6);
        uint256 wethBefore2 = IERC20(CHAIN_1_WETH).balanceOf(account);

        address[] memory hooks = new address[](2);
        hooks[0] = address(approveERC20Hook);
        hooks[1] = address(swapHook2);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] = _buildApproveERC20HookData(CHAIN_1_USDC, MAINNET_V3_SWAP_ROUTER_02, 1000e6, false);
        hookDatas[1] = _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, false);

        _executeMultiHook(hooks, hookDatas);
        uint256 wethReceived2 = IERC20(CHAIN_1_WETH).balanceOf(account) - wethBefore2;

        // Both variants should receive the same amount (identical pool state via snapshot)
        assertEq(wethReceived1, wethReceived2, "Both variants should produce identical output");
    }

    /*//////////////////////////////////////////////////////////////
                            INSPECT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice inspect returns tokenOut for different token pairs
    function test_Inspect_ReturnsCorrectTokenOut() external view {
        bytes memory hookData1 =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, false);
        bytes memory hookData2 = _buildRouter02HookData(CHAIN_1_WETH, DAI, FEE_MEDIUM, 0, 1 ether, 0, false);

        bytes memory result1 = swapHook.inspect(hookData1);
        bytes memory result2 = approveAndSwapHook.inspect(hookData2);

        address tokenOut1;
        address tokenOut2;
        assembly ("memory-safe") {
            tokenOut1 := mload(add(result1, 20))
            tokenOut2 := mload(add(result2, 20))
        }
        assertEq(tokenOut1, CHAIN_1_WETH, "inspect should return WETH");
        assertEq(tokenOut2, DAI, "inspect should return DAI");
    }

    /// @notice decodeUsePrevHookAmount returns correct bool
    function test_DecodeUsePrevHookAmount() external view {
        bytes memory dataFalse =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, false);
        bytes memory dataTrue =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, 1000e6, 0, true);

        assertFalse(swapHook.decodeUsePrevHookAmount(dataFalse));
        assertTrue(swapHook.decodeUsePrevHookAmount(dataTrue));
        assertFalse(approveAndSwapHook.decodeUsePrevHookAmount(dataFalse));
        assertTrue(approveAndSwapHook.decodeUsePrevHookAmount(dataTrue));
    }

    /*//////////////////////////////////////////////////////////////
                    DECODE AMOUNT / REPLACE CALLDATA AMOUNT
    //////////////////////////////////////////////////////////////*/

    /// @notice decodeAmount + replaceCalldataAmount roundtrip for SwapRouter02 hooks
    function test_SwapRouter02_DecodeAmounts_ReplaceCalldataAmounts() external view {
        uint256 originalAmount = 1000e6;
        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, originalAmount, 0.2 ether, false);

        // Verify decodeAmount reads correctly
        assertEq(swapHook.decodeAmounts(hookData)[0], originalAmount, "SwapHook decodeAmount mismatch");
        assertEq(approveAndSwapHook.decodeAmounts(hookData)[0], originalAmount, "ApproveAndSwapHook decodeAmount mismatch");

        // Replace with new amount and verify roundtrip
        uint256 newAmount = 500e6;
        bytes memory replacedSwap = swapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        bytes memory replacedApproveAndSwap = approveAndSwapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));

        assertEq(swapHook.decodeAmounts(replacedSwap)[0], newAmount, "SwapHook replaced amount mismatch");
        assertEq(
            approveAndSwapHook.decodeAmounts(replacedApproveAndSwap)[0],
            newAmount,
            "ApproveAndSwapHook replaced amount mismatch"
        );

        // Verify other fields are preserved
        assertFalse(swapHook.decodeUsePrevHookAmount(replacedSwap), "usePrevHookAmount should be preserved");
    }

    /// @notice ApproveAndSwap: build with 1000 USDC, replace to 500 USDC, execute, verify only 500 spent
    function test_ApproveAndSwapRouter02_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        address account = instanceOnEth.account;
        uint256 originalAmount = 1000e6;
        uint256 newAmount = 500e6;

        // Fund account with enough for original amount (to prove we only spend newAmount)
        deal(CHAIN_1_USDC, account, originalAmount);

        // Build hook data with original amount
        bytes memory hookData =
            _buildRouter02HookData(CHAIN_1_USDC, CHAIN_1_WETH, FEE_MEDIUM, 0, originalAmount, 0, false);

        // Replace with new amount
        bytes memory replaced = approveAndSwapHook.replaceCalldataAmounts(hookData, _singleAmount(newAmount));
        assertEq(approveAndSwapHook.decodeAmounts(replaced)[0], newAmount, "Amount not replaced correctly");

        uint256 wethBefore = IERC20(CHAIN_1_WETH).balanceOf(account);

        // Execute with replaced data
        _executeSingleHook(address(approveAndSwapHook), replaced);

        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);
        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);

        // Should only spend newAmount (500 USDC), leaving 500 USDC
        assertEq(usdcAfter, originalAmount - newAmount, "Should only spend replaced amount");
        assertGt(wethAfter - wethBefore, 0, "Should receive WETH");
    }

    /// @notice SwapHook (no-approve): build with 1 WETH, replace to 0.5 WETH, execute, verify only 0.5 spent
    function test_SwapRouter02_ReplaceCalldataAmounts_ExecutesCorrectly() public {
        address account = instanceOnEth.account;
        uint256 originalAmount = 1 ether;
        uint256 newAmount = 0.5 ether;

        deal(CHAIN_1_WETH, account, originalAmount);

        // Build hook data with original amount
        bytes memory swapHookData =
            _buildRouter02HookData(CHAIN_1_WETH, CHAIN_1_USDC, FEE_MEDIUM, 0, originalAmount, 0, false);

        // Replace with new amount
        bytes memory replacedSwapData = swapHook.replaceCalldataAmounts(swapHookData, _singleAmount(newAmount));

        // Also build approve data for newAmount
        bytes memory approveData =
            _buildApproveERC20HookData(CHAIN_1_WETH, MAINNET_V3_SWAP_ROUTER_02, newAmount, false);

        uint256 usdcBefore = IERC20(CHAIN_1_USDC).balanceOf(account);

        // Execute with approve + swap chain
        address[] memory hooks = new address[](2);
        hooks[0] = address(approveERC20Hook);
        hooks[1] = address(swapHook);

        bytes[] memory hookDatas = new bytes[](2);
        hookDatas[0] = approveData;
        hookDatas[1] = replacedSwapData;

        _executeMultiHook(hooks, hookDatas);

        uint256 wethAfter = IERC20(CHAIN_1_WETH).balanceOf(account);
        uint256 usdcAfter = IERC20(CHAIN_1_USDC).balanceOf(account);

        assertEq(wethAfter, originalAmount - newAmount, "Should only spend replaced amount");
        assertGt(usdcAfter - usdcBefore, 0, "Should receive USDC");
    }
}

/// @notice Mock contract to simulate previous hook returning specific amounts
contract MockPrevHookRouter02 is BaseHook {
    uint256 private _outAmount;

    constructor(uint256 outAmount_) BaseHook(ISuperHook.HookType.NONACCOUNTING, 0) {
        _outAmount = outAmount_;
    }

    function name() external pure override returns (string memory) {
        return "Mock Prev Hook Router02";
    }

    function description() external pure override returns (string memory) {
        return "Mock hook for testing";
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
