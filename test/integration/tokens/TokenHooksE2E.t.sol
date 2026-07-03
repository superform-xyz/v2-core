// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

import { BatchTransferHook } from "../../../src/hooks/tokens/BatchTransferHook.sol";
import { TransferHook } from "../../../src/hooks/tokens/TransferHook.sol";
import { TransferERC20Hook } from "../../../src/hooks/tokens/erc20/TransferERC20Hook.sol";
import { NativeTransferHook } from "../../../src/hooks/tokens/NativeTransferHook.sol";
import { Constants } from "../../utils/Constants.sol";

/// @title TokenHooksE2E
/// @notice Fork integration tests for token transfer hooks
contract TokenHooksE2E is Test, Constants {
    BatchTransferHook public batchTransferHook;
    TransferHook public transferHook;
    TransferERC20Hook public transferERC20Hook;
    NativeTransferHook public nativeTransferHook;

    address public account;
    address public recipient;

    /// @dev Use WETH address as native token representation on mainnet
    address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        vm.createSelectFork(vm.envString(ETHEREUM_RPC_URL_KEY), ETH_BLOCK);

        account = address(this);
        recipient = makeAddr("recipient");

        batchTransferHook = new BatchTransferHook(NATIVE_TOKEN);
        transferHook = new TransferHook(NATIVE_TOKEN);
        transferERC20Hook = new TransferERC20Hook();
        nativeTransferHook = new NativeTransferHook();
    }

    receive() external payable { }

    /*//////////////////////////////////////////////////////////////
                             HELPERS
    //////////////////////////////////////////////////////////////*/

    function _executeAll(Execution[] memory executions) internal {
        for (uint256 i = 0; i < executions.length; i++) {
            (bool success, bytes memory returndata) =
                executions[i].target.call{ value: executions[i].value }(executions[i].callData);
            if (!success) {
                assembly ("memory-safe") {
                    revert(add(returndata, 32), mload(returndata))
                }
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    BATCH TRANSFER TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test BatchTransferHook: deal tokens → batch transfer → assert balances
    function test_BatchTransfer() public {
        uint256 usdcAmount = 1000e6;
        uint256 wethAmount = 1e18;
        deal(CHAIN_1_USDC, account, usdcAmount);
        deal(CHAIN_1_WETH, account, wethAmount);

        uint256 recipientUsdcBefore = IERC20(CHAIN_1_USDC).balanceOf(recipient);
        uint256 recipientWethBefore = IERC20(CHAIN_1_WETH).balanceOf(recipient);

        // Build batch data: address to + abi.encode(address[] tokens, uint256[] amounts)
        address[] memory tokens = new address[](2);
        tokens[0] = CHAIN_1_USDC;
        tokens[1] = CHAIN_1_WETH;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = usdcAmount;
        amounts[1] = wethAmount;

        bytes memory hookData = bytes.concat(bytes32(0), bytes20(address(0)), bytes20(recipient), abi.encode(tokens, amounts));

        Execution[] memory executions = batchTransferHook.build(address(0), account, hookData);
        _executeAll(executions);

        assertEq(
            IERC20(CHAIN_1_USDC).balanceOf(recipient) - recipientUsdcBefore,
            usdcAmount,
            "Recipient should receive USDC"
        );
        assertEq(
            IERC20(CHAIN_1_WETH).balanceOf(recipient) - recipientWethBefore,
            wethAmount,
            "Recipient should receive WETH"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    TRANSFER HOOK (ERC20 PATH) TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test TransferHook with ERC20: deal USDC → transfer → assert moved
    function test_TransferERC20ViaTransferHook() public {
        uint256 amount = 500e6;
        deal(CHAIN_1_USDC, account, amount);

        uint256 recipientBefore = IERC20(CHAIN_1_USDC).balanceOf(recipient);

        // Data: 52-byte header + address token + address to + uint256 amount + bool usePrevHookAmount
        bytes memory hookData = bytes.concat(
            bytes32(0), bytes20(address(0)), // 52-byte strategy header
            bytes20(CHAIN_1_USDC), bytes20(recipient), bytes32(amount), bytes1(0x00) // usePrevHookAmount = false
        );

        Execution[] memory executions = transferHook.build(address(0), account, hookData);
        _executeAll(executions);

        assertEq(
            IERC20(CHAIN_1_USDC).balanceOf(recipient) - recipientBefore, amount, "Recipient should receive USDC"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    TRANSFER HOOK (NATIVE ETH PATH) TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test TransferHook with native ETH: deal ETH → transfer → assert moved
    function test_TransferNativeViaTransferHook() public {
        uint256 amount = 1 ether;
        vm.deal(account, amount);

        uint256 recipientBefore = recipient.balance;

        // Data: 52-byte header + address token(NATIVE) + address to + uint256 amount + bool usePrevHookAmount
        bytes memory hookData =
            bytes.concat(bytes32(0), bytes20(address(0)), bytes20(NATIVE_TOKEN), bytes20(recipient), bytes32(amount), bytes1(0x00));

        Execution[] memory executions = transferHook.build(address(0), account, hookData);
        _executeAll(executions);

        assertEq(recipient.balance - recipientBefore, amount, "Recipient should receive ETH");
    }

    /*//////////////////////////////////////////////////////////////
                    TRANSFER ERC20 HOOK TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test TransferERC20Hook: deal USDC → transfer → assert moved
    function test_TransferERC20() public {
        uint256 amount = 250e6;
        deal(CHAIN_1_USDC, account, amount);

        uint256 recipientBefore = IERC20(CHAIN_1_USDC).balanceOf(recipient);

        // Data: 52-byte header + address token + address to + uint256 amount + bool usePrevHookAmount
        bytes memory hookData = bytes.concat(
            bytes32(0), bytes20(address(0)), // 52-byte strategy header
            bytes20(CHAIN_1_USDC), bytes20(recipient), bytes32(amount), bytes1(0x00) // usePrevHookAmount = false
        );

        Execution[] memory executions = transferERC20Hook.build(address(0), account, hookData);
        _executeAll(executions);

        assertEq(
            IERC20(CHAIN_1_USDC).balanceOf(recipient) - recipientBefore, amount, "Recipient should receive USDC"
        );
    }

    /*//////////////////////////////////////////////////////////////
                    NATIVE TRANSFER HOOK TEST
    //////////////////////////////////////////////////////////////*/

    /// @notice Test NativeTransferHook: deal ETH → transfer → assert moved
    function test_NativeTransfer() public {
        uint256 amount = 2 ether;
        vm.deal(account, amount);

        uint256 recipientBefore = recipient.balance;

        // Data: 52-byte header + address to + uint256 amount
        bytes memory hookData = bytes.concat(bytes32(0), bytes20(address(0)), bytes20(recipient), bytes32(amount));

        Execution[] memory executions = nativeTransferHook.build(address(0), account, hookData);
        _executeAll(executions);

        assertEq(recipient.balance - recipientBefore, amount, "Recipient should receive ETH");
    }
}
