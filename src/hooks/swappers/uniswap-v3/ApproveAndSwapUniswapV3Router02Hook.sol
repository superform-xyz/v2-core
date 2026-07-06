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
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
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
/// @dev Payload: abi.encode(uint24 fee, uint160 sqrtPriceLimitX96)
/// @dev data has the following structure (standard 52-byte strategy header + Layer 1 + Layer 2):
/// @notice         bytes32   placeholder0     = BytesLib.toBytes32(data, 0);
/// @notice         address   placeholder1     = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken       = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken      = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount      = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote      = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin        = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes     payload          = BytesLib.slice(data, 221, payload_paramLength);
contract ApproveAndSwapUniswapV3Router02Hook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 SwapRouter02 contract
    IV3SwapRouter public immutable SWAP_ROUTER;

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

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

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Uniswap V3 Router02";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Uniswap V3 Router02";
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
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) revert INVALID_HOOK_DATA();

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
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        _setOutAmount(IERC20(outputToken).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        uint256 finalBalance = IERC20(outputToken).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID();
        _setOutAmount(finalBalance - initialBalance, account);
        _setOutToken(outputToken, account);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
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
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(outputToken);
    }

    // ─── ISuperHookSwap ──────────────────────────────────────────────────────

    /// @inheritdoc ISuperHookSwap
    function encodeSwapData(
        ISuperHookSwap.SwapHeader calldata header,
        bytes calldata payload
    )
        external
        pure
        override
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(SwapCalldataLayout.HEADER_SIZE)),
            bytes20(header.inputToken),
            bytes20(header.outputToken),
            bytes32(header.inputAmount),
            bytes32(header.outputQuote),
            bytes32(header.outputMin),
            bytes1(header.usePrevHookAmount ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeInputAmount(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputQuote(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodeOutputMin(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
    }

    /// @inheritdoc ISuperHookSwap
    function decodePayload(bytes calldata data) external pure override returns (bytes memory) {
        uint256 payloadLen = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        return BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLen);
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
        tokenIn = data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (tokenIn == address(0) || tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (tokenIn == tokenOut) revert INVALID_HOOK_DATA();

        uint256 originalAmountIn = data.toUint256(AMOUNT_POSITION);
        uint256 originalMinAmountOut = data.toUint256(SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        uint256 payloadLength = data.toUint256(SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);
        (fee, sqrtPriceLimitX96) = abi.decode(payload, (uint24, uint160));

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
