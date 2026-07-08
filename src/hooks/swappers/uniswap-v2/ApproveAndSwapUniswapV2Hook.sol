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
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";
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
/// @dev Payload: abi.encode(uint256 deadline, address[] path)
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
/// @dev Fee-on-transfer tokens are NOT supported
/// @dev Rebasing tokens are NOT supported as output tokens
contract ApproveAndSwapUniswapV2Hook is
    BaseHook,
    ISuperHookSwap,
    ISuperHookContextAware,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
{
    using BytesLib for bytes;

    struct UniswapV2SwapParams {
        address tokenIn;
        address tokenOut;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
        address[] path;
    }

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V2 Router contract
    IUniswapV2Router public immutable SWAP_ROUTER;

    /// @notice Sentinel address for native token detection (e.g., 0xEeee...EEEE)
    address public immutable NATIVE;

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

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

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Approve and Swap Uniswap V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Approves and swaps tokens via Uniswap V2";
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

        UniswapV2SwapParams memory p = _decodeSwapParams(prevHook, account, data);

        if (p.tokenIn == NATIVE) {
            executions = new Execution[](1);
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: p.amountIn,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactETHForTokens, (p.amountOutMin, p.path, account, p.deadline)
                )
            });
        } else {
            bytes memory swapCallData;
            if (p.tokenOut == NATIVE) {
                swapCallData = abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForETH, (p.amountIn, p.amountOutMin, p.path, account, p.deadline)
                );
            } else {
                swapCallData = abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForTokens,
                    (p.amountIn, p.amountOutMin, p.path, account, p.deadline)
                );
            }

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
            executions[2] = Execution({ target: address(SWAP_ROUTER), value: 0, callData: swapCallData });
            executions[3] = Execution({
                target: p.tokenIn,
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
        _setOutToken(data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
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
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the swap
    /// @param data The encoded hook data
    /// @dev Recipient is forced to account to ensure balance tracking works correctly for hook chaining
    /// @return p Decoded swap parameters as a struct (avoids stack-too-deep)
    function _decodeSwapParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (UniswapV2SwapParams memory p)
    {
        p.tokenIn = data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        p.tokenOut = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        uint256 originalAmountIn = data.toUint256(AMOUNT_POSITION);
        uint256 originalMinAmountOut = data.toUint256(SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        // Decode hook-specific payload
        uint256 payloadLength = data.toUint256(SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        bytes memory payload = BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLength);
        (p.deadline, p.path) = abi.decode(payload, (uint256, address[]));

        // Validate deadline hasn't passed
        if (p.deadline < block.timestamp) revert EXPIRED_DEADLINE(p.deadline, block.timestamp);

        // Validate path length
        if (p.path.length < 2 || p.path.length > MAX_PATH_LENGTH) revert INVALID_PATH_LENGTH();

        // Validate path endpoints match tokenIn/tokenOut (for non-native tokens)
        // Native tokens use WETH in the path; the router validates WETH consistency
        if (p.tokenIn != NATIVE && p.path[0] != p.tokenIn) revert INVALID_PATH();
        if (p.tokenOut != NATIVE && p.path[p.path.length - 1] != p.tokenOut) revert INVALID_PATH();

        // usePrevHookAmount chaining
        if (usePrevHookAmount) {
            p.amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            if (p.amountIn == 0) revert AMOUNT_NOT_VALID();
            p.amountOutMin =
                HookDataUpdater.getUpdatedOutputAmount(p.amountIn, originalAmountIn, originalMinAmountOut);
        } else {
            p.amountIn = originalAmountIn;
            p.amountOutMin = originalMinAmountOut;
        }
    }

    /// @notice Gets the balance of the output token for balance-delta tracking
    /// @param account The account to check the balance of
    /// @param data The hook data containing outputToken at offset 72
    /// @return The balance of the output token (native balance or ERC-20 balance)
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (outputToken == NATIVE) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }
}
