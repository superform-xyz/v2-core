// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { strings } from "@stringutils/strings.sol";
import { SuperNativePaymaster } from "../../../src/paymaster/SuperNativePaymaster.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { OdosV3APIParser } from "../../utils/parsers/OdosV3APIParser.sol";
import { SwapOdosV3Hook } from "../../../src/hooks/swappers/odos/SwapOdosV3Hook.sol";
import { ApproveAndSwapOdosV3Hook } from "../../../src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol";
import { IEntryPoint } from "@ERC4337/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/// @title OdosV3RouterSwapFork
/// @notice Fork-based integration tests for Odos V3 hooks using the real Odos V3 router on a forked mainnet.
///         Routes are obtained from the Odos API via FFI (Surl).
/// @dev Run with: forge test --match-contract OdosV3RouterSwapFork --ffi -vvv
contract OdosV3RouterSwapFork is MinimalBaseIntegrationTest, OdosV3APIParser {
    using ModuleKitHelpers for *;
    using strings for *;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        MockValidatorModule validator = new MockValidatorModule();
        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev External wrapper for Odos API call so try/catch can be used
    function getOdosRouteExternal(
        address inputToken,
        uint256 inputAmount,
        address outputToken
    )
        external
        returns (OdosV3DecodedSwap memory decoded)
    {
        QuoteInputToken[] memory quoteInputTokens = new QuoteInputToken[](1);
        quoteInputTokens[0] = QuoteInputToken({ tokenAddress: inputToken, amount: inputAmount });

        QuoteOutputToken[] memory quoteOutputTokens = new QuoteOutputToken[](1);
        quoteOutputTokens[0] = QuoteOutputToken({ tokenAddress: outputToken, proportion: 1 });

        string memory pathId = surlCallQuoteV2(quoteInputTokens, quoteOutputTokens, accountEth, ETH, false);
        string memory txDataHex = surlCallAssemble(pathId, accountEth);
        decoded = decodeOdosV3SwapCalldata(fromHex(txDataHex));
    }

    /// @dev Get a route from Odos API and decode into V3-compatible format. Skips test if API fails.
    function _getOdosRoute(
        address inputToken,
        uint256 inputAmount,
        address outputToken
    )
        internal
        returns (OdosV3DecodedSwap memory decoded)
    {
        try this.getOdosRouteExternal(inputToken, inputAmount, outputToken) returns (OdosV3DecodedSwap memory result) {
            decoded = result;
        } catch {
            vm.skip(true);
        }
    }

    /// @dev Build V3 hook data from decoded API response with extra slippage
    function _buildV3HookData(OdosV3DecodedSwap memory decoded) internal pure returns (bytes memory) {
        uint256 adjustedOutputMin = decoded.tokenInfo.outputMin - decoded.tokenInfo.outputMin * 1e4 / 1e5;

        return _createOdosV3SwapHookData(
            decoded.tokenInfo.inputToken,
            decoded.tokenInfo.inputAmount,
            decoded.tokenInfo.inputReceiver,
            decoded.tokenInfo.outputToken,
            decoded.tokenInfo.outputQuote,
            adjustedOutputMin,
            decoded.pathDefinition,
            decoded.executor,
            decoded.referralInfo.code,
            decoded.referralInfo.fee,
            decoded.referralInfo.feeRecipient,
            false
        );
    }

    /*//////////////////////////////////////////////////////////////
                    SwapOdosV3Hook: ERC-20 SWAPS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test SwapOdosV3Hook: USDC -> WETH swap with separate approve hook
    function test_fork_SwapOdosV3Hook_USDC_to_WETH() public {
        uint256 amount = 2000e6; // 2000 USDC (6 decimals)
        deal(CHAIN_1_USDC, accountEth, amount);

        OdosV3DecodedSwap memory decoded = _getOdosRoute(CHAIN_1_USDC, amount, CHAIN_1_WETH);

        SwapOdosV3Hook swapHook = new SwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(CHAIN_1_USDC, ODOS_ROUTER_V3, amount, false);
        hookData[1] = _buildV3HookData(decoded);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 wethBalanceBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        executeOp(opData);
        uint256 wethBalanceAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        assertGt(wethBalanceAfter, wethBalanceBefore, "Account should have received WETH from USDC swap");
    }

    /// @notice Test SwapOdosV3Hook: DAI -> USDC swap (stablecoin to stablecoin)
    function test_fork_SwapOdosV3Hook_DAI_to_USDC() public {
        uint256 amount = 10_000e18; // 10,000 DAI (18 decimals)
        deal(CHAIN_1_DAI, accountEth, amount);

        OdosV3DecodedSwap memory decoded = _getOdosRoute(CHAIN_1_DAI, amount, CHAIN_1_USDC);

        SwapOdosV3Hook swapHook = new SwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(CHAIN_1_DAI, ODOS_ROUTER_V3, amount, false);
        hookData[1] = _buildV3HookData(decoded);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 usdcBalanceBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        executeOp(opData);
        uint256 usdcBalanceAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertGt(usdcBalanceAfter, usdcBalanceBefore, "DAI to USDC swap should have received USDC");
    }

    /*//////////////////////////////////////////////////////////////
                SwapOdosV3Hook: NATIVE ETH SWAPS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test SwapOdosV3Hook: ETH -> USDC swap (no approve needed for native ETH)
    function test_fork_SwapOdosV3Hook_ETH_to_USDC() public {
        uint256 amount = 1e18;

        OdosV3DecodedSwap memory decoded = _getOdosRoute(address(0), amount, CHAIN_1_USDC);

        SwapOdosV3Hook swapHook = new SwapOdosV3Hook(ODOS_ROUTER_V3);

        // No approve hook for native ETH - just the swap hook
        address[] memory hookAddresses_ = new address[](1);
        hookAddresses_[0] = address(swapHook);

        bytes[] memory hookData = new bytes[](1);
        hookData[0] = _buildV3HookData(decoded);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 usdcBalanceBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        executeOp(opData);
        uint256 usdcBalanceAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertGt(usdcBalanceAfter, usdcBalanceBefore, "Account should have received USDC from ETH swap");
    }

    /*//////////////////////////////////////////////////////////////
                ApproveAndSwapOdosV3Hook: ERC-20 SWAPS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndSwapOdosV3Hook: USDC -> WETH (single hook handles approve + swap)
    function test_fork_ApproveAndSwapOdosV3Hook_USDC_to_WETH() public {
        uint256 amount = 1000e6; // 1000 USDC
        deal(CHAIN_1_USDC, accountEth, amount);

        OdosV3DecodedSwap memory decoded = _getOdosRoute(CHAIN_1_USDC, amount, CHAIN_1_WETH);

        ApproveAndSwapOdosV3Hook approveAndSwapHook = new ApproveAndSwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](1);
        hookAddresses_[0] = address(approveAndSwapHook);

        bytes[] memory hookData = new bytes[](1);
        hookData[0] = _buildV3HookData(decoded);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 wethBalanceBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        executeOp(opData);
        uint256 wethBalanceAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        assertGt(wethBalanceAfter, wethBalanceBefore, "ApproveAndSwap should have received WETH from USDC swap");
    }

    /// @notice Test ApproveAndSwapOdosV3Hook: WETH -> USDC swap
    function test_fork_ApproveAndSwapOdosV3Hook_WETH_to_USDC() public {
        uint256 amount = 2e18; // 2 WETH
        deal(CHAIN_1_WETH, accountEth, amount);

        OdosV3DecodedSwap memory decoded = _getOdosRoute(CHAIN_1_WETH, amount, CHAIN_1_USDC);

        ApproveAndSwapOdosV3Hook approveAndSwapHook = new ApproveAndSwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](1);
        hookAddresses_[0] = address(approveAndSwapHook);

        bytes[] memory hookData = new bytes[](1);
        hookData[0] = _buildV3HookData(decoded);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 usdcBalanceBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        executeOp(opData);
        uint256 usdcBalanceAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertGt(usdcBalanceAfter, usdcBalanceBefore, "WETH to USDC ApproveAndSwap should have received USDC");
    }

    /*//////////////////////////////////////////////////////////////
            ApproveAndSwapOdosV3Hook: NATIVE ETH SWAPS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test ApproveAndSwapOdosV3Hook: Native ETH -> USDC swap
    function test_fork_ApproveAndSwapOdosV3Hook_NativeETH_to_USDC() public {
        uint256 amount = 1e18;
        vm.deal(accountEth, amount + 2 ether); // extra for gas

        OdosV3DecodedSwap memory decoded = _getOdosRoute(address(0), amount, CHAIN_1_USDC);

        ApproveAndSwapOdosV3Hook approveAndSwapHook = new ApproveAndSwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](1);
        hookAddresses_[0] = address(approveAndSwapHook);

        bytes[] memory hookData = new bytes[](1);
        hookData[0] = _buildV3HookData(decoded);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 usdcBalanceBefore = IERC20(CHAIN_1_USDC).balanceOf(accountEth);
        executeOp(opData);
        uint256 usdcBalanceAfter = IERC20(CHAIN_1_USDC).balanceOf(accountEth);

        assertGt(usdcBalanceAfter, usdcBalanceBefore, "Native ETH swap should have received USDC");
    }

    /*//////////////////////////////////////////////////////////////
                      PAYMASTER INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test SwapOdosV3Hook: USDC -> WETH with SuperNativePaymaster
    function test_fork_SwapOdosV3Hook_WithPaymaster_USDC_to_WETH() public {
        uint256 amount = 1000e6; // 1000 USDC
        deal(CHAIN_1_USDC, accountEth, amount);

        OdosV3DecodedSwap memory decoded = _getOdosRoute(CHAIN_1_USDC, amount, CHAIN_1_WETH);

        SwapOdosV3Hook swapHook = new SwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(CHAIN_1_USDC, ODOS_ROUTER_V3, amount, false);
        hookData[1] = _buildV3HookData(decoded);

        address paymaster = address(new SuperNativePaymaster(IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032)));
        SuperNativePaymaster superNativePaymaster = SuperNativePaymaster(paymaster);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute), paymaster);

        uint256 wethBalanceBefore = IERC20(CHAIN_1_WETH).balanceOf(accountEth);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = opData.userOp;

        address bundler = vm.addr(1234);
        vm.deal(bundler, 30 ether);
        vm.prank(bundler);
        superNativePaymaster.handleOps{ value: 20 ether }(ops);

        uint256 wethBalanceAfter = IERC20(CHAIN_1_WETH).balanceOf(accountEth);
        assertGt(wethBalanceAfter, wethBalanceBefore, "Paymaster swap should have received WETH");
    }

    /*//////////////////////////////////////////////////////////////
                    CHAINED SWAP WITH usePrevHookAmount
    //////////////////////////////////////////////////////////////*/

    /// @dev Build V3 hook data with usePrevHookAmount=true and extra slippage
    function _buildV3HookDataWithPrevAmount(OdosV3DecodedSwap memory decoded) internal pure returns (bytes memory) {
        uint256 adjustedOutputMin = decoded.tokenInfo.outputMin - decoded.tokenInfo.outputMin * 1e4 / 1e5;

        return _createOdosV3SwapHookData(
            decoded.tokenInfo.inputToken,
            decoded.tokenInfo.inputAmount,
            decoded.tokenInfo.inputReceiver,
            decoded.tokenInfo.outputToken,
            decoded.tokenInfo.outputQuote,
            adjustedOutputMin,
            decoded.pathDefinition,
            decoded.executor,
            decoded.referralInfo.code,
            decoded.referralInfo.fee,
            decoded.referralInfo.feeRecipient,
            true
        );
    }

    /// @notice Test chained swap: USDC -> WETH -> DAI with usePrevHookAmount on second hop
    /// @dev Validates P1-1 fix: outputQuote is properly scaled when usePrevHookAmount is true.
    ///      The second hook reads the actual WETH output from the first hook and proportionally
    ///      scales both outputMin and outputQuote before calling the Odos router.
    function test_fork_ChainedSwap_USDC_to_WETH_to_DAI_usePrevHookAmount() public {
        uint256 amount = 2000e6; // 2000 USDC
        deal(CHAIN_1_USDC, accountEth, amount);

        // Step 1: Get route for USDC -> WETH
        OdosV3DecodedSwap memory decoded1 = _getOdosRoute(CHAIN_1_USDC, amount, CHAIN_1_WETH);

        // Step 2: Get route for expected WETH -> DAI (using outputQuote as the estimated WETH amount)
        OdosV3DecodedSwap memory decoded2 = _getOdosRoute(CHAIN_1_WETH, decoded1.tokenInfo.outputQuote, CHAIN_1_DAI);

        // Deploy separate hook instances (each uses its own transient storage context)
        ApproveAndSwapOdosV3Hook hook1 = new ApproveAndSwapOdosV3Hook(ODOS_ROUTER_V3);
        ApproveAndSwapOdosV3Hook hook2 = new ApproveAndSwapOdosV3Hook(ODOS_ROUTER_V3);

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = address(hook1);
        hookAddresses_[1] = address(hook2);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _buildV3HookData(decoded1);
        hookData[1] = _buildV3HookDataWithPrevAmount(decoded2);

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 daiBalanceBefore = IERC20(CHAIN_1_DAI).balanceOf(accountEth);
        executeOp(opData);
        uint256 daiBalanceAfter = IERC20(CHAIN_1_DAI).balanceOf(accountEth);

        assertGt(daiBalanceAfter, daiBalanceBefore, "Chained USDC to WETH to DAI swap with usePrevHookAmount should receive DAI");
    }
}
