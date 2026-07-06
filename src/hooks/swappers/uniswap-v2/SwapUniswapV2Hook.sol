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

/// @title SwapUniswapV2Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via any Uniswap V2-compatible router
/// @dev Assumes tokens are already approved to the router
/// @dev Supports single-hop and multi-hop paths, native token swaps via configurable NATIVE sentinel
/// @dev data has the following structure (standard 52-byte strategy header + hook-specific):
/// @notice         bytes32 placeholder0 = BytesLib.toBytes32(data, 0);
/// @notice         address placeholder1 = BytesLib.toAddress(data, 32);
/// @notice         address tokenIn = BytesLib.toAddress(data, 52);
/// @notice         address tokenOut = BytesLib.toAddress(data, 72);
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 92);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 124);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 156);
/// @dev Payload: abi.encode(uint256 deadline, address[] path)
/// @dev Fee-on-transfer tokens are NOT supported
/// @dev Rebasing tokens are NOT supported as output tokens
contract SwapUniswapV2Hook is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {
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

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 156;

    uint256 private constant AMOUNT_POSITION = 92;

    uint256 private constant PAYLOAD_OFFSET = 157;

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

    /// @notice Initialize the Uniswap V2 swap hook
    /// @param router_ The address of the Uniswap V2 Router
    /// @param native_ The sentinel address for native token detection
    constructor(address router_, address native_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (router_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = IUniswapV2Router(router_);
        NATIVE = native_;
    }

    /// @notice Human-readable name for UI display
    function name() external pure override returns (string memory) {
        return "Swap Uniswap V2";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via Uniswap V2";
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
        if (data.length < 157) revert INVALID_HOOK_DATA();

        UniswapV2SwapParams memory p = _decodeSwapParams(prevHook, account, data);

        executions = new Execution[](1);

        if (p.tokenIn == NATIVE) {
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: p.amountIn,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactETHForTokens, (p.amountOutMin, p.path, account, p.deadline)
                )
            });
        } else if (p.tokenOut == NATIVE) {
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: 0,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForETH, (p.amountIn, p.amountOutMin, p.path, account, p.deadline)
                )
            });
        } else {
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: 0,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForTokens, (p.amountIn, p.amountOutMin, p.path, account, p.deadline)
                )
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
        _setOutToken(data.toAddress(72), account);
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
        p.tokenIn = data.toAddress(52);
        p.tokenOut = data.toAddress(72);

        uint256 originalAmountIn = data.toUint256(AMOUNT_POSITION);
        uint256 originalMinAmountOut = data.toUint256(124);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        // Decode hook-specific payload
        (p.deadline, p.path) = abi.decode(data[PAYLOAD_OFFSET:], (uint256, address[]));

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
    /// @param data The hook data containing tokenOut at offset 20
    /// @return The balance of the output token (native balance or ERC-20 balance)
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address tokenOut = data.toAddress(72);
        if (tokenOut == NATIVE) {
            return account.balance;
        }
        return IERC20(tokenOut).balanceOf(account);
    }
}
