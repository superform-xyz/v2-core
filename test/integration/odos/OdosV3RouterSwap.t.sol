// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import { MODULE_TYPE_VALIDATOR } from "modulekit/accounts/kernel/types/Constants.sol";
import { UserOpData, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MockERC20 } from "../../mocks/MockERC20.sol";
import { MockValidatorModule } from "../../mocks/MockValidatorModule.sol";
import { ISuperExecutor } from "../../../src/interfaces/ISuperExecutor.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { MinimalBaseIntegrationTest } from "../MinimalBaseIntegrationTest.t.sol";
import { SwapOdosV3Hook } from "../../../src/hooks/swappers/odos/SwapOdosV3Hook.sol";
import { ApproveAndSwapOdosV3Hook } from "../../../src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol";
import { MockOdosRouterV3 } from "../../mocks/MockOdosRouterV3.sol";

/// @title OdosV3RouterSwap
/// @notice Integration test for Odos V3 swap hooks executing through a smart account via SuperExecutor
contract OdosV3RouterSwap is MinimalBaseIntegrationTest {
    using ModuleKitHelpers for *;

    MockOdosRouterV3 public odosRouterV3;
    address public swapInputToken;
    address public swapOutputToken;

    function setUp() public override {
        blockNumber = 0;
        super.setUp();

        MockValidatorModule validator = new MockValidatorModule();
        instanceOnEth.installModule({ moduleTypeId: MODULE_TYPE_VALIDATOR, module: address(validator), data: "" });

        odosRouterV3 = new MockOdosRouterV3();

        MockERC20 _inputToken = new MockERC20("Input Token", "IN", 18);
        swapInputToken = address(_inputToken);

        MockERC20 _outputToken = new MockERC20("Output Token", "OUT", 18);
        swapOutputToken = address(_outputToken);
    }

    /// @notice Test SwapOdosV3Hook executing an ERC-20 swap through a smart account
    function test_SwapOdosV3Hook_SmartAccountSwap() public {
        uint256 amount = 1e18;

        // Fund the router with output tokens so the swap can succeed
        deal(swapOutputToken, address(odosRouterV3), 10e18);

        // Fund the smart account with input tokens
        deal(swapInputToken, accountEth, amount);

        // Approve router to spend smart account's tokens (via approve hook first)
        SwapOdosV3Hook swapHook = new SwapOdosV3Hook(address(odosRouterV3));

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(swapInputToken, address(odosRouterV3), amount, false);

        // Build V3 hook data using helper (which prepends the 52-byte strategy header)
        hookData[1] = _createOdosV3SwapHookData(
            swapInputToken,
            amount,
            accountEth,
            swapOutputToken,
            amount,
            amount - amount * 50 / 10_000,
            bytes(""),
            address(0),
            uint64(0),
            uint64(0),
            address(0),
            false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 outputBalanceBefore = IERC20(swapOutputToken).balanceOf(accountEth);

        executeOp(opData);

        uint256 outputBalanceAfter = IERC20(swapOutputToken).balanceOf(accountEth);
        assertGt(outputBalanceAfter, outputBalanceBefore, "Smart account should have received output tokens");
    }

    /// @notice Test ApproveAndSwapOdosV3Hook executing an ERC-20 swap through a smart account
    function test_ApproveAndSwapOdosV3Hook_SmartAccountSwap() public {
        uint256 amount = 1e18;

        // Fund the router with output tokens
        deal(swapOutputToken, address(odosRouterV3), 10e18);

        // Fund the smart account with input tokens
        deal(swapInputToken, accountEth, amount);

        ApproveAndSwapOdosV3Hook approveAndSwapHook = new ApproveAndSwapOdosV3Hook(address(odosRouterV3));

        address[] memory hookAddresses_ = new address[](1);
        hookAddresses_[0] = address(approveAndSwapHook);

        bytes[] memory hookData = new bytes[](1);

        // Build V3 hook data using helper (which prepends the 52-byte strategy header)
        hookData[0] = _createOdosV3SwapHookData(
            swapInputToken,
            amount,
            accountEth,
            swapOutputToken,
            amount,
            amount - amount * 50 / 10_000,
            bytes(""),
            address(0),
            uint64(0),
            uint64(0),
            address(0),
            false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 outputBalanceBefore = IERC20(swapOutputToken).balanceOf(accountEth);

        executeOp(opData);

        uint256 outputBalanceAfter = IERC20(swapOutputToken).balanceOf(accountEth);
        assertGt(outputBalanceAfter, outputBalanceBefore, "Smart account should have received output tokens");
    }

    /// @notice Test ApproveAndSwapOdosV3Hook with native ETH input through a smart account
    function test_ApproveAndSwapOdosV3Hook_NativeETH_SmartAccountSwap() public {
        uint256 amount = 1e18;

        // Fund the router with output tokens
        deal(swapOutputToken, address(odosRouterV3), 10e18);

        // Fund the smart account with native ETH (extra for gas)
        vm.deal(accountEth, amount + 1 ether);

        ApproveAndSwapOdosV3Hook approveAndSwapHook = new ApproveAndSwapOdosV3Hook(address(odosRouterV3));

        address[] memory hookAddresses_ = new address[](1);
        hookAddresses_[0] = address(approveAndSwapHook);

        bytes[] memory hookData = new bytes[](1);

        // Build V3 hook data using helper (native ETH: inputToken = address(0))
        hookData[0] = _createOdosV3SwapHookData(
            address(0), // native ETH input
            amount,
            accountEth,
            swapOutputToken,
            amount,
            amount - amount * 50 / 10_000,
            bytes(""),
            address(0),
            uint64(0),
            uint64(0),
            address(0),
            false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 outputBalanceBefore = IERC20(swapOutputToken).balanceOf(accountEth);

        executeOp(opData);

        uint256 outputBalanceAfter = IERC20(swapOutputToken).balanceOf(accountEth);
        assertGt(outputBalanceAfter, outputBalanceBefore, "Smart account should have received output tokens from native swap");
    }

    /// @notice Test SwapOdosV3Hook with referral fee through a smart account
    function test_SwapOdosV3Hook_WithReferralFee_SmartAccountSwap() public {
        uint256 amount = 1e18;

        deal(swapOutputToken, address(odosRouterV3), 10e18);
        deal(swapInputToken, accountEth, amount);

        SwapOdosV3Hook swapHook = new SwapOdosV3Hook(address(odosRouterV3));

        address[] memory hookAddresses_ = new address[](2);
        hookAddresses_[0] = approveHook;
        hookAddresses_[1] = address(swapHook);

        bytes[] memory hookData = new bytes[](2);
        hookData[0] = _createApproveHookData(swapInputToken, address(odosRouterV3), amount, false);

        address referralRecipient = makeAddr("referralRecipient");
        uint64 referralFee = 1e16; // 1% (within 2% cap)

        // Build V3 hook data using helper (which prepends the 52-byte strategy header)
        hookData[1] = _createOdosV3SwapHookData(
            swapInputToken,
            amount,
            accountEth,
            swapOutputToken,
            amount,
            amount - amount * 50 / 10_000,
            bytes(""),
            address(0),
            uint64(123),
            referralFee,
            referralRecipient,
            false
        );

        ISuperExecutor.ExecutorEntry memory entryToExecute =
            ISuperExecutor.ExecutorEntry({ hooksAddresses: hookAddresses_, hooksData: hookData });

        UserOpData memory opData = _getExecOps(instanceOnEth, superExecutorOnEth, abi.encode(entryToExecute));

        uint256 outputBalanceBefore = IERC20(swapOutputToken).balanceOf(accountEth);

        executeOp(opData);

        uint256 outputBalanceAfter = IERC20(swapOutputToken).balanceOf(accountEth);
        assertGt(outputBalanceAfter, outputBalanceBefore, "Swap with referral fee should succeed");
    }
}
