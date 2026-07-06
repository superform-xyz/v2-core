// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External imports
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform imports
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";

// Real Uniswap V4 imports
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { IUnlockCallback } from "v4-core/interfaces/callback/IUnlockCallback.sol";
import { IHooks } from "v4-core/interfaces/IHooks.sol";
import { PoolKey } from "v4-core/types/PoolKey.sol";
import { PoolId, PoolIdLibrary } from "v4-core/types/PoolId.sol";
import { Currency, CurrencyLibrary } from "v4-core/types/Currency.sol";
import { BalanceDelta, BalanceDeltaLibrary } from "v4-core/types/BalanceDelta.sol";
import { StateLibrary } from "v4-core/libraries/StateLibrary.sol";
import { SwapMath } from "v4-core/libraries/SwapMath.sol";
import { TickMath } from "v4-core/libraries/TickMath.sol";

/// @title SwapUniswapV4Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via Uniswap V4 with dynamic minAmountOut recalculation
/// @dev Implements dynamic slippage protection and on-chain quote generation
/// @dev Payload: abi.encode(bool zeroForOne, uint24 fee, int24 tickSpacing, address hooks, address dstReceiver, uint160 sqrtPriceLimitX96, uint256 maxSlippageDeviationBps, bytes additionalData)
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
contract SwapUniswapV4Hook is BaseHook, ISuperHookSwap, IUnlockCallback, ISuperHookInflowOutflow, ISuperHookOutflow {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V4 Pool Manager contract
    IPoolManager public immutable POOL_MANAGER;

    /// @notice Storage slot for transient unlock data
    bytes32 private constant PENDING_UNLOCK_DATA_SLOT = keccak256("SwapUniswapV4Hook.pendingUnlockData");

    uint256 private transient initialBalance;

    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;
    uint256 private constant MAX_BPS = 10_000; // 100%
    uint256 private constant MAX_ADDITIONAL_DATA_LEN = 4096; // hard cap to bound gas on user-controlled data

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the swap output is below the minimum required
    error INSUFFICIENT_OUTPUT_AMOUNT(uint256 actual, uint256 minimum);

    /// @notice Thrown when an unauthorized caller attempts to use the unlock callback
    error UNAUTHORIZED_CALLBACK();

    /// @notice Thrown when the hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /// @notice Thrown when the ratio deviation exceeds the maximum allowed
    /// @param actualDeviation The actual ratio deviation in basis points
    /// @param maxAllowed The maximum allowed deviation in basis points
    error EXCESSIVE_SLIPPAGE_DEVIATION(uint256 actualDeviation, uint256 maxAllowed);

    /// @notice Thrown when original amounts are zero or invalid
    error INVALID_ORIGINAL_AMOUNTS();

    /// @notice Thrown when actual amount is zero
    error INVALID_ACTUAL_AMOUNT();

    /// @notice Thrown when the pool has zero liquidity
    error ZERO_LIQUIDITY();

    /// @notice Thrown when an invalid price limit is provided (e.g., 0)
    error INVALID_PRICE_LIMIT();
    error INVALID_OUTPUT_DELTA();

    /// @notice Thrown when hook retains token balance after execution
    error HOOK_BALANCE_NOT_CLEARED(address token, uint256 remaining);

    error OUTPUT_AMOUNT_DIFFERENT_THAN_TRUE();

    error INVALID_PREVIOUS_NATIVE_TRANSFER_HOOK_USAGE();

    error INVALID_REMAINING_NATIVE_AMOUNT();

    error EXCESSIVE_ADDITIONAL_DATA();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Parameters for dynamic minAmount recalculation
    /// @param originalAmountIn The original user-provided amountIn
    /// @param originalMinAmountOut The original user-provided minAmountOut
    /// @param actualAmountIn The actual amountIn (potentially changed by bridges/hooks)
    /// @param maxSlippageDeviationBps Maximum allowed ratio change in basis points (e.g., 100 = 1%)
    struct RecalculationParams {
        uint256 originalAmountIn;
        uint256 originalMinAmountOut;
        uint256 actualAmountIn;
        uint256 maxSlippageDeviationBps;
    }

    /// @notice Struct to hold swap execution parameters and results
    struct SwapExecutionParams {
        Currency inputCurrency;
        Currency outputCurrency;
        address inputToken;
        uint160 effectivePriceLimitX96;
        BalanceDelta swapDelta;
        PoolKey poolKey;
        uint256 amountIn;
        uint256 minAmountOut;
        address dstReceiver;
        bool zeroForOne;
        int128 delta0;
        int128 delta1;
        address currency1Token;
        int128 outDelta;
        uint256 amountOut;
        uint256 excess;
        uint256 balance;
    }

    /// @notice Struct to hold decoded payload fields
    struct DecodedPayload {
        bool zeroForOne;
        uint24 fee;
        int24 tickSpacing;
        address hooksAddr;
        address dstReceiver;
        uint160 sqrtPriceLimitX96;
        uint256 maxSlippageDeviationBps;
        bytes additionalData;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V4 swap hook
    /// @param poolManager_ The address of the Uniswap V4 Pool Manager
    constructor(address poolManager_) BaseHook(ISuperHook.HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        POOL_MANAGER = IPoolManager(poolManager_);
    }

    /// @inheritdoc ISuperHook
    function name() external pure override returns (string memory) {
        return "Swap Uniswap V4";
    }

    /// @notice One-sentence description of what this hook does
    function description() external pure override returns (string memory) {
        return "Swaps tokens via Uniswap V4";
    }


    /// @notice Allows contract to receive native ETH for native token swaps
    receive() external payable { }

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
        (address inputToken, uint256 amountIn) = _getTransferParams(prevHook, account, data);

        if (inputToken != address(0)) {
            executions = new Execution[](1);
            executions[0] = Execution({
                target: inputToken,
                value: 0,
                callData: abi.encodeWithSelector(IERC20.transfer.selector, address(this), amountIn)
            });
        }
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        // Store relevant context for postExecute
        (asset,) = _getTransferParams(prevHook, account, data);

        // Get initial balance (handle native ETH vs ERC-20)
        address outputToken = _getOutputToken(data);
        address dstReceiver = _decodeDstReceiver(data);
        if (outputToken == address(0)) {
            // Native ETH
            initialBalance = dstReceiver.balance;
        } else {
            // ERC-20 token
            initialBalance = IERC20(outputToken).balanceOf(dstReceiver);
        }

        // Prepare and store unlock data in transient storage for postExecute
        bytes memory unlockData = _prepareUnlockData(prevHook, account, data);
        _storeUnlockData(unlockData);
    }

    /// @inheritdoc BaseHook
    function _postExecute(
        address,
        /* prevHook */
        address account,
        bytes calldata data
    )
        internal
        override
    {
        // Retrieve unlock data from transient storage
        bytes memory unlockData = _loadUnlockData();

        // Execute unlock - the callback will come to this hook since we're msg.sender
        bytes memory unlockResult = POOL_MANAGER.unlock(unlockData);

        // Clear transient storage
        _clearUnlockData();

        // Decode the output amount from unlock result
        uint256 outputAmount = abi.decode(unlockResult, (uint256));

        // Calculate true output amount (handle native ETH vs ERC-20)
        address outputToken = _getOutputToken(data);
        address dstReceiver = _decodeDstReceiver(data);
        uint256 currentBalance;
        if (outputToken == address(0)) {
            // Native ETH
            currentBalance = dstReceiver.balance;
        } else {
            // ERC-20 token
            currentBalance = IERC20(outputToken).balanceOf(dstReceiver);
        }
        uint256 trueOutputAmount = currentBalance - initialBalance;

        if (outputAmount != trueOutputAmount) revert OUTPUT_AMOUNT_DIFFERENT_THAN_TRUE();

        // Set the output amount for the next hook
        _setOutAmount(outputAmount, account);
        _setOutToken(outputToken, account);
    }

    /*//////////////////////////////////////////////////////////////
                            UNLOCK CALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUnlockCallback
    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(POOL_MANAGER)) revert UNAUTHORIZED_CALLBACK();

        // Decode unlock data
        (
            PoolKey memory poolKey,
            uint256 amountIn,
            uint256 minAmountOut,
            address dstReceiver,
            uint160 sqrtPriceLimitX96,
            bool zeroForOne,
            bytes memory additionalData
        ) = abi.decode(data, (PoolKey, uint256, uint256, address, uint160, bool, bytes));

        // Normalize price limit: 0 means no limit -> set to extreme bound depending on direction
        uint160 effectivePriceLimitX96 = sqrtPriceLimitX96 == 0
            ? (zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1)
            : sqrtPriceLimitX96;

        // Populate params struct
        SwapExecutionParams memory params;
        params.poolKey = poolKey;
        params.amountIn = amountIn;
        params.minAmountOut = minAmountOut;
        params.dstReceiver = dstReceiver;
        params.zeroForOne = zeroForOne;
        params.inputCurrency = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        params.outputCurrency = zeroForOne ? poolKey.currency1 : poolKey.currency0;
        params.inputToken = Currency.unwrap(params.inputCurrency);
        params.effectivePriceLimitX96 = effectivePriceLimitX96;
        params.currency1Token = Currency.unwrap(poolKey.currency1);

        // Execute swap
        params.swapDelta = POOL_MANAGER.swap(
            params.poolKey,
            IPoolManager.SwapParams({
                zeroForOne: params.zeroForOne,
                amountSpecified: -int256(params.amountIn),
                sqrtPriceLimitX96: params.effectivePriceLimitX96
            }),
            additionalData
        );

        params.delta0 = params.swapDelta.amount0();
        params.delta1 = params.swapDelta.amount1();

        // Settle/take deltas and refund excess via helpers (avoids stack-too-deep under --ir-minimum)
        _settleCurrencyDelta(params.delta0, params.poolKey.currency0, params.inputToken, params);
        _settleCurrencyDelta(params.delta1, params.poolKey.currency1, params.currency1Token, params);

        // Compute and enforce output minimum
        params.outDelta = params.zeroForOne ? params.delta1 : params.delta0;
        params.amountOut = params.outDelta > 0 ? uint256(uint128(params.outDelta)) : 0;
        if (params.amountOut < params.minAmountOut) {
            revert INSUFFICIENT_OUTPUT_AMOUNT(params.amountOut, params.minAmountOut);
        }

        // Refund unconsumed input
        _refundExcessInput(params);

        return abi.encode(params.amountOut);
    }

    /// @notice Settle or take a single currency delta with the pool manager
    function _settleCurrencyDelta(
        int128 delta,
        Currency currency,
        address token,
        SwapExecutionParams memory params
    )
        private
    {
        if (delta < 0) {
            uint256 amountToSettle = uint256(uint128(-delta));
            if (currency.isAddressZero()) {
                if (address(this).balance < amountToSettle) revert INVALID_PREVIOUS_NATIVE_TRANSFER_HOOK_USAGE();
                POOL_MANAGER.settle{ value: amountToSettle }();
            } else {
                POOL_MANAGER.sync(currency);
                IERC20(token).transfer(address(POOL_MANAGER), amountToSettle);
                POOL_MANAGER.settle();
            }
        } else if (delta > 0) {
            uint256 amountToTake = uint256(int256(delta));
            bool isOutputCurrency = Currency.unwrap(currency) == Currency.unwrap(params.outputCurrency);
            if (isOutputCurrency && amountToTake < params.minAmountOut) {
                revert INSUFFICIENT_OUTPUT_AMOUNT(amountToTake, params.minAmountOut);
            }
            POOL_MANAGER.take(currency, params.dstReceiver, amountToTake);
        }
    }

    /// @notice Refund unconsumed input tokens after settlement
    function _refundExcessInput(SwapExecutionParams memory params) private {
        Currency inputCurrency;
        address inputToken;
        if (params.delta0 < 0) {
            inputCurrency = params.poolKey.currency0;
            inputToken = params.inputToken;
        } else if (params.delta1 < 0) {
            inputCurrency = params.poolKey.currency1;
            inputToken = params.currency1Token;
        } else {
            return;
        }

        if (inputCurrency.isAddressZero()) {
            params.balance = address(this).balance;
            if (params.balance > 0) {
                (bool success,) = params.dstReceiver.call{ value: params.balance }("");
                if (!success) revert INVALID_REMAINING_NATIVE_AMOUNT();
            }
        } else {
            params.balance = IERC20(inputToken).balanceOf(address(this));
            if (params.balance > 0) {
                IERC20(inputToken).transfer(params.dstReceiver, params.balance);
            }
        }
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address outputToken = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        (,,,, address dstReceiver,,,) = abi.decode(
            data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:],
            (bool, uint24, int24, address, address, uint160, uint256, bytes)
        );
        return abi.encodePacked(outputToken, dstReceiver);
    }

    /// @notice Decodes the usePrevHookAmount flag from hook data
    function decodeUsePrevHookAmount(bytes calldata data) external pure returns (bool usePrevHookAmount) {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) {
            revert INVALID_HOOK_DATA();
        }
        usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
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

    /// @notice Calculates new minAmountOut ensuring ratio protection
    function _calculateDynamicMinAmount(RecalculationParams memory params)
        internal
        pure
        returns (uint256 newMinAmountOut)
    {
        if (params.originalAmountIn == 0 || params.originalMinAmountOut == 0) {
            revert INVALID_ORIGINAL_AMOUNTS();
        }
        if (params.actualAmountIn == 0) {
            revert INVALID_ACTUAL_AMOUNT();
        }

        newMinAmountOut = Math.mulDiv(params.originalMinAmountOut, params.actualAmountIn, params.originalAmountIn);
        if (newMinAmountOut == 0) revert INVALID_OUTPUT_DELTA();

        uint256 amountRatio = (params.actualAmountIn * 1e18) / params.originalAmountIn;
        uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);
        if (ratioDeviationBps > params.maxSlippageDeviationBps) {
            revert EXCESSIVE_SLIPPAGE_DEVIATION(ratioDeviationBps, params.maxSlippageDeviationBps);
        }
    }

    function _calculateRatioDeviationBps(uint256 amountRatio) private pure returns (uint256 ratioDeviationBps) {
        if (amountRatio > 1e18) {
            ratioDeviationBps = ((amountRatio - 1e18) * MAX_BPS) / 1e18;
        } else {
            ratioDeviationBps = ((1e18 - amountRatio) * MAX_BPS) / 1e18;
        }
    }

    /// @notice Extract transfer parameters without causing stack depth issues
    function _getTransferParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (address inputToken, uint256 amountIn)
    {
        address currency0 = data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address currency1 = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        // Decode zeroForOne from payload
        (bool zeroForOne,,,,,,,) = abi.decode(
            data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:],
            (bool, uint24, int24, address, address, uint160, uint256, bytes)
        );

        inputToken = zeroForOne ? currency0 : currency1;

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
        } else {
            amountIn = data.toUint256(AMOUNT_POSITION);
        }
    }

    /// @notice Prepare unlock data for the pool manager
    function _prepareUnlockData(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (bytes memory unlockData)
    {
        (
            PoolKey memory poolKey,
            address dstReceiver,
            uint160 sqrtPriceLimitX96,
            uint256 originalAmountIn,
            uint256 originalMinAmountOut,
            uint256 maxSlippageDeviationBps,
            bool zeroForOne,
            bool usePrevHookAmount,
            bytes memory additionalData
        ) = _decodeHookData(data);

        uint256 actualAmountIn = usePrevHookAmount ? ISuperHookResult(prevHook).getOutAmount(account) : originalAmountIn;
        uint256 dynamicMinAmountOut = _calculateDynamicMinAmount(
            RecalculationParams({
                originalAmountIn: originalAmountIn,
                originalMinAmountOut: originalMinAmountOut,
                actualAmountIn: actualAmountIn,
                maxSlippageDeviationBps: maxSlippageDeviationBps
            })
        );

        unlockData = abi.encode(
            poolKey, actualAmountIn, dynamicMinAmountOut, dstReceiver, sqrtPriceLimitX96, zeroForOne, additionalData
        );
    }

    function _decodeHookData(bytes calldata data)
        internal
        pure
        returns (
            PoolKey memory poolKey,
            address dstReceiver,
            uint160 sqrtPriceLimitX96,
            uint256 originalAmountIn,
            uint256 originalMinAmountOut,
            uint256 maxSlippageDeviationBps,
            bool zeroForOne,
            bool usePrevHookAmount,
            bytes memory additionalData
        )
    {
        if (data.length < SwapCalldataLayout.MIN_DATA_LENGTH) {
            revert INVALID_HOOK_DATA();
        }

        // Read standard header fields
        originalAmountIn = data.toUint256(AMOUNT_POSITION);
        originalMinAmountOut = data.toUint256(SwapCalldataLayout.OUTPUT_MIN_OFFSET);
        usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);

        // Decode payload (zeroForOne is now in the payload)
        DecodedPayload memory p = _decodePayload(data);
        zeroForOne = p.zeroForOne;
        dstReceiver = p.dstReceiver;
        sqrtPriceLimitX96 = p.sqrtPriceLimitX96;
        maxSlippageDeviationBps = p.maxSlippageDeviationBps;
        additionalData = p.additionalData;

        if (additionalData.length > MAX_ADDITIONAL_DATA_LEN) {
            revert EXCESSIVE_ADDITIONAL_DATA();
        }

        // Construct PoolKey
        poolKey = PoolKey({
            currency0: Currency.wrap(data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET)),
            currency1: Currency.wrap(data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET)),
            fee: p.fee,
            tickSpacing: p.tickSpacing,
            hooks: IHooks(p.hooksAddr)
        });

        // Validate PoolKey components
        if (Currency.unwrap(poolKey.currency0) == Currency.unwrap(poolKey.currency1)) revert INVALID_HOOK_DATA();
        if (poolKey.fee == 0) revert INVALID_HOOK_DATA();
        if (poolKey.tickSpacing == 0) revert INVALID_HOOK_DATA();
    }

    function _decodePayload(bytes calldata data) private pure returns (DecodedPayload memory p) {
        (p.zeroForOne, p.fee, p.tickSpacing, p.hooksAddr, p.dstReceiver, p.sqrtPriceLimitX96, p.maxSlippageDeviationBps, p.additionalData) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (bool, uint24, int24, address, address, uint160, uint256, bytes));
    }

    /// @notice Gets the output token from hook data
    function _getOutputToken(bytes calldata data) internal pure returns (address outputToken) {
        address currency0 = data.toAddress(SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address currency1 = data.toAddress(SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        // Decode zeroForOne from payload
        (bool zeroForOne,,,,,,,) = abi.decode(
            data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:],
            (bool, uint24, int24, address, address, uint160, uint256, bytes)
        );

        outputToken = zeroForOne ? currency1 : currency0;
    }

    /// @notice Decodes the dstReceiver from the payload
    function _decodeDstReceiver(bytes calldata data) internal pure returns (address dstReceiver) {
        (,,,, dstReceiver,,,) =
            abi.decode(data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:], (bool, uint24, int24, address, address, uint160, uint256, bytes));
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSIENT STORAGE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _storeUnlockData(bytes memory data) private {
        bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
        uint256 len = data.length;

        assembly ("memory-safe") {
            tstore(storageKey, len)
        }

        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly ("memory-safe") {
                word := mload(add(add(data, 0x20), i))
                tstore(add(storageKey, div(add(i, 32), 32)), word)
            }
        }
    }

    function _loadUnlockData() private view returns (bytes memory out) {
        bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
        uint256 len;

        assembly ("memory-safe") {
            len := tload(storageKey)
        }

        out = new bytes(len);
        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly ("memory-safe") {
                word := tload(add(storageKey, div(add(i, 32), 32)))
            }

            assembly ("memory-safe") {
                mstore(add(add(out, 0x20), i), word)
            }
        }
    }

    function _clearUnlockData() private {
        bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
        assembly ("memory-safe") {
            tstore(storageKey, 0)
        }
    }
}
