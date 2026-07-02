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

/// @title ApproveAndSwapUniswapV3Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via Uniswap V3 with approval handling
/// @dev Handles: approve(0) -> approve(amount) -> swap -> approve(0)
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes placeholder = BytesLib.slice(data, 0, 52);
/// @notice         address tokenIn = BytesLib.toAddress(data, 52);
/// @notice         address tokenOut = BytesLib.toAddress(data, 72);
/// @notice         uint24 fee = uint24(BytesLib.toUint32(data, 92));
/// @notice         address recipient = BytesLib.toAddress(data, 96);
/// @notice         uint256 deadline = BytesLib.toUint256(data, 116);
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 148));
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 180);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 212);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 244);
contract ApproveAndSwapUniswapV3Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;

    struct UniswapV3SwapParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 deadline;
        uint160 sqrtPriceLimitX96;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 SwapRouter contract
    ISwapRouter public immutable SWAP_ROUTER;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 244;

    uint256 private constant AMOUNT_POSITION = 180;

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

    /// @notice Initialize the Uniswap V3 swap hook with approval handling
    /// @param swapRouter_ The address of the Uniswap V3 SwapRouter
    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = ISwapRouter(swapRouter_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Uniswap V3";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Uniswap V3";
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
        if (data.length < 245) revert INVALID_HOOK_DATA();

        UniswapV3SwapParams memory p = _decodeSwapParams(data);

        if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
            uint256 prevAmountIn = ISuperHookResult(prevHook).getOutAmount(account);
            p.amountOutMinimum =
                HookDataUpdater.getUpdatedOutputAmount(prevAmountIn, p.amountIn, p.amountOutMinimum);
            p.amountIn = prevAmountIn;
        }

        // Build: approve(0) -> approve(amount) -> swap -> approve(0)
        executions = new Execution[](4);

        executions[0] = Execution({
            target: p.tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });

        executions[1] = Execution({
            target: p.tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), p.amountIn))
        });

        executions[2] =
            Execution({ target: address(SWAP_ROUTER), value: 0, callData: _encodeSwapCall(p, account) });

        executions[3] = Execution({
            target: p.tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });
    }

    function _encodeSwapCall(UniswapV3SwapParams memory p, address account) private pure returns (bytes memory) {
        return abi.encodeCall(
            ISwapRouter.exactInputSingle,
            (
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: p.tokenIn,
                    tokenOut: p.tokenOut,
                    fee: p.fee,
                    recipient: account,
                    deadline: p.deadline,
                    amountIn: p.amountIn,
                    amountOutMinimum: p.amountOutMinimum,
                    sqrtPriceLimitX96: p.sqrtPriceLimitX96
                })
            )
        );
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(72);
        _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(72);
        uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        _setOutAmount(finalBalance - initialBalance, account);
        _setOutToken(tokenOut, account);
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
        address tokenOut = data.toAddress(72);
        return abi.encodePacked(tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes swap parameters from hook data
    /// @param data The encoded hook data
    /// @dev prevHook/account handling is done in _buildHookExecutions to reduce stack depth
    function _decodeSwapParams(bytes calldata data) private view returns (UniswapV3SwapParams memory p) {
        p.tokenIn = data.toAddress(52);
        p.tokenOut = data.toAddress(72);

        if (p.tokenIn == address(0) || p.tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();

        p.fee = uint24(data.toUint32(92));
        p.deadline = data.toUint256(116);

        if (p.deadline < block.timestamp) revert EXPIRED_DEADLINE(p.deadline, block.timestamp);

        p.sqrtPriceLimitX96 = uint160(data.toUint256(148));
        p.amountIn = data.toUint256(180);
        p.amountOutMinimum = data.toUint256(212);
    }
}
