// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Vendor
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { IUniswapV2Router } from "./interfaces/IUniswapV2Router.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import {
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";

/// @title ApproveAndSwapUniswapV2Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via any Uniswap V2-compatible router with approval handling
/// @dev Handles: approve(0) -> approve(amount) -> swap -> approve(0) for ERC-20 inputs
/// @dev Skips approval steps entirely when input is native token
/// @dev data has the following structure:
/// @dev         address tokenIn = BytesLib.toAddress(data, 0);
/// @dev         address tokenOut = BytesLib.toAddress(data, 20);
/// @dev         uint256 deadline = BytesLib.toUint256(data, 40);
/// @dev         uint256 originalAmountIn = BytesLib.toUint256(data, 72);
/// @dev         uint256 originalMinAmountOut = BytesLib.toUint256(data, 104);
/// @dev         bool usePrevHookAmount = _decodeBool(data, 136);
/// @dev         uint256 pathLength = BytesLib.toUint256(data, 137);
/// @dev         address[] path = decoded from (169, pathLength * 20);
/// @dev Fee-on-transfer tokens are NOT supported
/// @dev Rebasing tokens are NOT supported as output tokens
contract ApproveAndSwapUniswapV2Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V2 Router contract
    IUniswapV2Router public immutable SWAP_ROUTER;

    /// @notice Sentinel address for native token detection (e.g., 0xEeee...EEEE)
    address public immutable NATIVE;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 136;

    uint256 private constant AMOUNT_POSITION = 72;

    /// @notice Maximum allowed path length to prevent gas griefing
    uint256 private constant MAX_PATH_LENGTH = 10;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /// @notice Thrown when the swap path length is invalid (< 2 or > MAX_PATH_LENGTH)
    error INVALID_PATH_LENGTH();

    /// @notice Thrown when path endpoints do not match tokenIn/tokenOut
    error INVALID_PATH();

    /// @notice Thrown when the deadline has passed
    /// @param deadline The provided deadline timestamp
    /// @param currentTimestamp The current block timestamp
    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V2 swap hook with approval handling
    /// @param router_ The address of the Uniswap V2 Router
    /// @param native_ The sentinel address for native token detection
    constructor(address router_, address native_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = IUniswapV2Router(router_);
        NATIVE = native_;
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
        /// @dev Minimum data length: 169 bytes fixed data + 2 * 20 bytes minimum path (2 addresses) = 209
        if (data.length < 209) revert INVALID_HOOK_DATA();

        // Decode parameters
        (
            address tokenIn,
            address tokenOut,
            uint256 deadline,
            uint256 amountIn,
            uint256 amountOutMin,
            address[] memory path
        ) = _decodeSwapParams(prevHook, account, data);

        if (tokenIn == NATIVE) {
            // Native input: skip approvals, only 1 execution with value
            executions = new Execution[](1);
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: amountIn,
                callData: abi.encodeCall(IUniswapV2Router.swapExactETHForTokens, (amountOutMin, path, account, deadline))
            });
        } else {
            // ERC-20 input: approve(0) -> approve(amount) -> swap -> approve(0)
            bytes memory swapCallData;

            if (tokenOut == NATIVE) {
                swapCallData = abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForETH, (amountIn, amountOutMin, path, account, deadline)
                );
            } else {
                swapCallData = abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForTokens, (amountIn, amountOutMin, path, account, deadline)
                );
            }

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
            executions[2] = Execution({ target: address(SWAP_ROUTER), value: 0, callData: swapCallData });

            // Clear approval after swap
            executions[3] = Execution({
                target: tokenIn,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
            });
        }
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        // Store initial balance of output token
        _setOutAmount(_getBalance(account, data), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        // Calculate delta (final - initial balance)
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
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
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the swap
    /// @param data The encoded hook data
    /// @dev Recipient is forced to account to ensure balance tracking works correctly for hook chaining
    /// @return tokenIn The input token address (or NATIVE sentinel)
    /// @return tokenOut The output token address (or NATIVE sentinel)
    /// @return deadline The deadline timestamp for the swap
    /// @return amountIn The amount of input tokens
    /// @return amountOutMin The minimum amount of output tokens
    /// @return path The swap path array (always real token addresses, never NATIVE sentinel)
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
            uint256 deadline,
            uint256 amountIn,
            uint256 amountOutMin,
            address[] memory path
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);
        deadline = data.toUint256(40);

        // Validate deadline hasn't passed
        if (deadline < block.timestamp) revert EXPIRED_DEADLINE(deadline, block.timestamp);

        uint256 originalAmountIn = data.toUint256(72);
        uint256 originalMinAmountOut = data.toUint256(104);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        // Decode variable-length path
        uint256 pathLength = data.toUint256(137);
        if (pathLength < 2 || pathLength > MAX_PATH_LENGTH) revert INVALID_PATH_LENGTH();
        if (data.length < 169 + pathLength * 20) revert INVALID_HOOK_DATA();

        path = new address[](pathLength);
        for (uint256 i = 0; i < pathLength;) {
            path[i] = data.toAddress(169 + i * 20);
            unchecked { ++i; }
        }

        // Validate path endpoints match tokenIn/tokenOut (for non-native tokens)
        // Native tokens use WETH in the path; the router validates WETH consistency
        if (tokenIn != NATIVE && path[0] != tokenIn) revert INVALID_PATH();
        if (tokenOut != NATIVE && path[pathLength - 1] != tokenOut) revert INVALID_PATH();

        // usePrevHookAmount chaining
        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            if (amountIn == 0) revert AMOUNT_NOT_VALID();
            amountOutMin =
                HookDataUpdater.getUpdatedOutputAmount(amountIn, originalAmountIn, originalMinAmountOut);
        } else {
            amountIn = originalAmountIn;
            amountOutMin = originalMinAmountOut;
        }
    }

    /// @notice Gets the balance of the output token for balance-delta tracking
    /// @param account The account to check the balance of
    /// @param data The hook data containing tokenOut at offset 20
    /// @return The balance of the output token (native balance or ERC-20 balance)
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address tokenOut = data.toAddress(20);
        if (tokenOut == NATIVE) {
            return account.balance;
        }
        return IERC20(tokenOut).balanceOf(account);
    }
}
