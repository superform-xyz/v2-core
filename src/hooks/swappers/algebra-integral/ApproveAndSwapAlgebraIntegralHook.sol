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
import { IAlgebraSwapRouter } from "../../../vendor/algebra-integral/IAlgebraSwapRouter.sol";

/// @title ApproveAndSwapAlgebraIntegralHook
/// @author Superform Labs
/// @notice Hook for executing swaps via Algebra Integral with approval handling
/// @dev Handles: approve(0) -> approve(amount) -> swap -> approve(0)
/// @dev data structure same as SwapAlgebraIntegralHook
contract ApproveAndSwapAlgebraIntegralHook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Algebra Integral SwapRouter contract
    IAlgebraSwapRouter public immutable SWAP_ROUTER;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 208;

    uint256 private constant AMOUNT_POSITION = 144;

    /// @notice Minimum required hook data length (208 bytes of params + 1 byte for usePrevHookAmount flag)
    uint256 private constant MIN_HOOK_DATA_LENGTH = 209;

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

    /// @notice Initialize the Algebra Integral swap hook with approval handling
    /// @param swapRouter_ The address of the Algebra Integral SwapRouter
    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = IAlgebraSwapRouter(swapRouter_);
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Algebra Integral";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Algebra Integral DEX";
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
            address deployer,
            address recipient,
            uint256 deadline,
            uint160 limitSqrtPrice,
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
                IAlgebraSwapRouter.exactInputSingle,
                (
                    IAlgebraSwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        deployer: deployer,
                        recipient: recipient,
                        deadline: deadline,
                        amountIn: amountIn,
                        amountOutMinimum: amountOutMinimum,
                        limitSqrtPrice: limitSqrtPrice
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
            address deployer,
            address recipient,
            uint256 deadline,
            uint160 limitSqrtPrice,
            uint256 amountIn,
            uint256 amountOutMinimum
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);

        // Native ETH not supported - use WETH instead
        if (tokenIn == address(0) || tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (tokenIn == tokenOut) revert INVALID_HOOK_DATA();

        deployer = data.toAddress(40);
        // Force recipient to account - balance tracking in _preExecute/_postExecute
        // requires output tokens to go to account for usePrevHookAmount to work
        recipient = account;
        deadline = data.toUint256(80);

        // Validate deadline hasn't passed
        if (deadline < block.timestamp) revert EXPIRED_DEADLINE(deadline, block.timestamp);

        // limitSqrtPrice: 0 means no price limit (swap executes at any price)
        limitSqrtPrice = uint160(data.toUint256(112));

        uint256 originalAmountIn = data.toUint256(144);
        uint256 originalMinAmountOut = data.toUint256(176);
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

        if (amountIn == 0) revert AMOUNT_NOT_VALID();
    }
}
