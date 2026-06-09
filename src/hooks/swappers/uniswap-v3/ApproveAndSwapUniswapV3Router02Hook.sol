// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform
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
import { IV3SwapRouter } from "./interfaces/IV3SwapRouter.sol";

/// @title ApproveAndSwapUniswapV3Router02Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via Uniswap V3 SwapRouter02 with approval handling
/// @dev Handles: approve(0) -> approve(amount) -> swap -> approve(0)
/// @dev SwapRouter02 removes deadline from ExactInputSingleParams (deadline handled via multicall wrapper)
/// @dev Fee-on-transfer and rebasing tokens are NOT supported (Uniswap V3 limitation)
/// @dev data has the following structure:
/// @notice         address tokenIn = BytesLib.toAddress(data, 0);
/// @notice         address tokenOut = BytesLib.toAddress(data, 20);
/// @notice         uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 44));
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 76);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 108);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 140);
contract ApproveAndSwapUniswapV3Router02Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 SwapRouter02 contract
    IV3SwapRouter public immutable SWAP_ROUTER;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 140;

    uint256 private constant AMOUNT_POSITION = 76;

    /// @notice Minimum valid hook data length
    uint256 private constant MIN_HOOK_DATA_LENGTH = 141;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /// @notice Thrown when native ETH is used (use WETH instead)
    error NATIVE_ETH_NOT_SUPPORTED();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V3 SwapRouter02 swap hook with approval handling
    /// @param swapRouter_ The address of the Uniswap V3 SwapRouter02
    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = IV3SwapRouter(swapRouter_);
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
        if (data.length < MIN_HOOK_DATA_LENGTH) revert INVALID_HOOK_DATA();

        (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        ) = _decodeSwapParams(prevHook, account, data);

        // Build: approve(0) -> approve(amount) -> swap -> approve(0)
        executions = new Execution[](4);

        // Reset approval to 0 (handles USDT-like tokens)
        executions[0] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });

        // Set approval to exact amount
        executions[1] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), amountIn))
        });

        // Execute swap
        executions[2] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: abi.encodeCall(
                IV3SwapRouter.exactInputSingle,
                (
                    IV3SwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: fee,
                        recipient: account,
                        amountIn: amountIn,
                        amountOutMinimum: amountOutMinimum,
                        sqrtPriceLimitX96: sqrtPriceLimitX96
                    })
                )
            )
        });

        // Clear approval after swap
        executions[3] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(20);
        _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(20);
        uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID();
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
    function decodeAmount(bytes memory data) external pure returns (uint256) {
        return BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256 amount) external pure returns (bytes memory) {
        return _replaceCalldataAmount(data, amount, AMOUNT_POSITION);
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
    /// @dev Recipient is always set to `account` to ensure balance tracking works correctly for hook chaining
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the swap
    /// @param data The encoded hook data
    /// @return tokenIn The input token address
    /// @return tokenOut The output token address
    /// @return fee The Uniswap V3 pool fee tier
    /// @return sqrtPriceLimitX96 The price limit for the swap (0 = no limit)
    /// @return amountIn The amount of input tokens to swap
    /// @return amountOutMinimum The minimum acceptable output amount
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
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);

        if (tokenIn == address(0) || tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (tokenIn == tokenOut) revert INVALID_HOOK_DATA();

        uint32 rawFee = data.toUint32(40);
        if (rawFee > type(uint24).max) revert INVALID_HOOK_DATA();
        fee = uint24(rawFee);

        uint256 rawSqrtPriceLimit = data.toUint256(44);
        if (rawSqrtPriceLimit > type(uint160).max) revert INVALID_HOOK_DATA();
        sqrtPriceLimitX96 = uint160(rawSqrtPriceLimit);

        uint256 originalAmountIn = data.toUint256(76);
        uint256 originalMinAmountOut = data.toUint256(108);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
                amountIn,
                originalAmountIn,
                originalMinAmountOut
            );
            if (amountOutMinimum == 0) revert AMOUNT_NOT_VALID();
        } else {
            amountIn = originalAmountIn;
            amountOutMinimum = originalMinAmountOut;
        }

        if (amountIn == 0) revert AMOUNT_NOT_VALID();
    }
}
