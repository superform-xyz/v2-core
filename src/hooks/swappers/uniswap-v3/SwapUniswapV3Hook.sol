// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";

/// @title SwapUniswapV3Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via Uniswap V3 SwapRouter.exactInputSingle
/// @dev Assumes tokens are already approved to the router
/// @dev data has the following structure:
/// @notice         address tokenIn = BytesLib.toAddress(data, 0);
/// @notice         address tokenOut = BytesLib.toAddress(data, 20);
/// @notice         uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice         address recipient = BytesLib.toAddress(data, 44);
/// @notice         uint256 deadline = BytesLib.toUint256(data, 64);
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 96));
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 128);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 160);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 192);
contract SwapUniswapV3Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 SwapRouter contract
    ISwapRouter public immutable SWAP_ROUTER;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 192;

    uint256 private constant AMOUNT_POSITION = 128;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /// @notice Thrown when native ETH is used (use WETH instead)
    error NATIVE_ETH_NOT_SUPPORTED();

    /// @notice Thrown when the deadline has passed
    /// @param deadline The provided deadline timestamp
    /// @param currentTimestamp The current block timestamp
    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V3 swap hook
    /// @param swapRouter_ The address of the Uniswap V3 SwapRouter
    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = ISwapRouter(swapRouter_);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length < 193) revert INVALID_HOOK_DATA();

        // Decode parameters
        (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 deadline,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        ) = _decodeSwapParams(prevHook, account, data);

        // Build swap execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: fee,
                        recipient: recipient,
                        deadline: deadline,
                        amountIn: amountIn,
                        amountOutMinimum: amountOutMinimum,
                        sqrtPriceLimitX96: sqrtPriceLimitX96
                    })
                )
            )
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        // Store initial balance of output token
        address tokenOut = data.toAddress(20);
        _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        // Calculate delta (final - initial balance)
        address tokenOut = data.toAddress(20);
        uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        _setOutAmount(finalBalance - initialBalance, account);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    /// @dev This hook implements ISuperHookInflowOutflow + ISuperHookOutflow
    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address tokenOut = data.toAddress(20);
        return abi.encodePacked(tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes swap parameters from hook data
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the swap
    /// @param data The encoded hook data
    /// @dev recipient is forced to account to ensure balance tracking works correctly for hook chaining
    function _decodeSwapParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 deadline,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);

        // Native ETH not supported - use WETH instead
        if (tokenIn == address(0) || tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();

        fee = uint24(data.toUint32(40));
        // Force recipient to account - balance tracking in _preExecute/_postExecute
        // requires output tokens to go to account for usePrevHookAmount to work
        recipient = account;
        deadline = data.toUint256(64);

        // Validate deadline hasn't passed
        if (deadline < block.timestamp) revert EXPIRED_DEADLINE(deadline, block.timestamp);

        // sqrtPriceLimitX96: 0 means no price limit (swap executes at any price)
        sqrtPriceLimitX96 = uint160(data.toUint256(96));

        uint256 originalAmountIn = data.toUint256(128);
        uint256 originalMinAmountOut = data.toUint256(160);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
                amountIn,
                originalAmountIn,
                originalMinAmountOut
            );
        } else {
            amountIn = originalAmountIn;
            amountOutMinimum = originalMinAmountOut;
        }
    }
}
