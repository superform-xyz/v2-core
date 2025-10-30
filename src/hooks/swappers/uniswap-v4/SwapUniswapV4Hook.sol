// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External imports
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

// Superform imports
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

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
/// @dev data has the following structure
/// @notice         address currency0 = BytesLib.toAddress(data, 0);
/// @notice         address currency1 = BytesLib.toAddress(data, 20);
/// @notice         uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice         int24 tickSpacing = int24(BytesLib.toUint32(data, 44));
/// @notice         address hooks = BytesLib.toAddress(data, 48);
/// @notice         address dstReceiver = BytesLib.toAddress(data, 68);
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 88));
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 120);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 152);
/// @notice         uint256 maxSlippageDeviationBps = BytesLib.toUint256(data, 184);
/// @notice         bool zeroForOne = _decodeBool(data, 216);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 217);
/// @notice         bytes additionalData = BytesLib.slice(data, 218, data.length - 218);
contract SwapUniswapV4Hook is BaseHook, IUnlockCallback {
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

    uint256 private constant MAX_BPS = 10_000; // 100%

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

    /// @notice Parameters for quote calculation
    /// @param poolKey The pool key to quote against
    /// @param zeroForOne Whether swapping token0 for token1
    /// @param amountIn The input amount for the swap
    /// @param sqrtPriceLimitX96 Optional price limit for the swap (0 for no limit)
    struct QuoteParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Result of a quote calculation
    /// @param amountOut The expected output amount
    /// @param sqrtPriceX96After The expected price after the swap
    struct QuoteResult {
        uint256 amountOut;
        uint160 sqrtPriceX96After;
    }

    /// @notice Struct to hold swap execution parameters and results
    /// @param inputCurrency The input currency for the swap
    /// @param outputCurrency The output currency for the swap
    /// @param inputToken The input token address
    /// @param effectivePriceLimitX96 The effective price limit for the swap
    /// @param swapDelta The delta returned from the swap
    struct SwapExecutionParams {
        Currency inputCurrency;
        Currency outputCurrency;
        address inputToken;
        uint160 effectivePriceLimitX96;
        BalanceDelta swapDelta;
    }

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V4 swap hook
    /// @param poolManager_ The address of the Uniswap V4 Pool Manager
    constructor(address poolManager_) BaseHook(ISuperHook.HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        POOL_MANAGER = IPoolManager(poolManager_);
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
        address dstReceiver = data.toAddress(68);
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
    function _postExecute(address, /* prevHook */ address account, bytes calldata data) internal override {
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
        address dstReceiver = data.toAddress(68);
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
    }

    /*//////////////////////////////////////////////////////////////
                            UNLOCK CALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUnlockCallback
    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        // Ensure only the Pool Manager can call this
        if (msg.sender != address(POOL_MANAGER)) {
            revert UNAUTHORIZED_CALLBACK();
        }

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

        // Determine swap direction and currencies
        SwapExecutionParams memory params;
        params.inputCurrency = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        params.outputCurrency = zeroForOne ? poolKey.currency1 : poolKey.currency0;
        params.inputToken = Currency.unwrap(params.inputCurrency);
        params.effectivePriceLimitX96 = effectivePriceLimitX96;

        // STEP 1: Execute swap FIRST (before any transfers)
        // For exact-input swaps, the swap only accounts deltas - it doesn't require tokens to be present
        // This allows us to see the exact delta amounts (which may differ from amountIn due to protocol fees)
        // before transferring tokens
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn), // Exact input (negative for exact input)
            sqrtPriceLimitX96: params.effectivePriceLimitX96
        });

        params.swapDelta = POOL_MANAGER.swap(poolKey, swapParams, additionalData);

        // STEP 2: Extract deltas for BOTH currencies (CRITICAL: handle both explicitly)
        // After swap, both currencies have deltas accounted to this hook contract
        // - Negative delta = we owe tokens (need to settle)
        // - Positive delta = we receive tokens (need to take)
        int128 delta0 = params.swapDelta.amount0();
        int128 delta1 = params.swapDelta.amount1();

        // STEP 3: Handle currency0 delta
        // IMPORTANT: For exact-input swaps with protocol fees, delta0 might be less than -amountIn
        // We must settle exactly -delta0, not amountIn, to avoid residual delta causing CurrencyNotSettled()
        if (delta0 < 0) {
            // Negative delta: we owe currency0, need to settle
            uint256 amountToSettle = uint256(uint128(-delta0));

            if (poolKey.currency0.isAddressZero()) {
                // Native token: settle with exact amount needed
                // Excess (if any) remains in hook contract for postExecute handling
                if (address(this).balance < amountToSettle) {
                    revert INVALID_PREVIOUS_NATIVE_TRANSFER_HOOK_USAGE();
                }
                POOL_MANAGER.settle{ value: amountToSettle }();
            } else {
                // ERC-20: Sync AFTER swap to reset the CurrencyReserves state
                // settle() accounts balance increase from last sync, so we sync now to reset
                POOL_MANAGER.sync(poolKey.currency0);

                // Transfer exactly amountToSettle tokens
                // settle() will calculate: balanceAfter - balanceBefore = amountToSettle
                IERC20(params.inputToken).transfer(address(POOL_MANAGER), amountToSettle);

                // settle() accounts +amountToSettle delta, canceling -delta0 exactly
                POOL_MANAGER.settle();
            }
        } else if (delta0 > 0) {
            // Positive delta: we receive currency0, need to take
            uint256 amountToTake = uint256(int256(delta0));
            POOL_MANAGER.take(poolKey.currency0, dstReceiver, amountToTake);
        }
        // If delta0 == 0, nothing to do

        // STEP 4: Handle currency1 delta - this is our output
        if (delta1 < 0) {
            // Negative delta: we owe currency1 (shouldn't happen for exact-input zeroForOne swap)
            // But handle it for completeness
            uint256 amountToSettle = uint256(uint128(-delta1));
            if (poolKey.currency1.isAddressZero()) {
                POOL_MANAGER.settle{ value: amountToSettle }();
            } else {
                POOL_MANAGER.sync(poolKey.currency1);
                IERC20(Currency.unwrap(poolKey.currency1)).transfer(address(POOL_MANAGER), amountToSettle);
                POOL_MANAGER.settle();
            }
        } else if (delta1 > 0) {
            // Positive delta: we receive currency1, need to take (this is our output)
            uint256 amountToTake = uint256(int256(delta1));
            if (amountToTake < minAmountOut) {
                revert INSUFFICIENT_OUTPUT_AMOUNT(amountToTake, minAmountOut);
            }
            POOL_MANAGER.take(poolKey.currency1, dstReceiver, amountToTake);
        }
        // If delta1 == 0, nothing to do

        // STEP 5: Return the output amount
        // For zeroForOne: output is currency1 (delta1)
        // For !zeroForOne: output is currency0 (delta0)
        uint256 amountOut = zeroForOne ? uint256(int256(delta1)) : uint256(int256(delta0));
        return abi.encode(amountOut);
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        // Decode token addresses directly using BytesLib
        address currency0 = data.toAddress(0);
        address currency1 = data.toAddress(20);

        // Return packed token addresses for inspection
        return abi.encodePacked(
            currency0, // Input token
            currency1 // Output token
        );
    }

    /// @notice Decodes the usePrevHookAmount flag from hook data
    /// @param data The encoded hook data
    /// @return usePrevHookAmount Whether to use the previous hook's output amount
    function decodeUsePrevHookAmount(bytes calldata data) external pure returns (bool usePrevHookAmount) {
        if (data.length < 218) {
            revert INVALID_HOOK_DATA();
        }
        usePrevHookAmount = _decodeBool(data, 217);
    }

    /// @notice Generate on-chain quote using pool state and real V4 math
    /// @dev Uses SwapMath.computeSwapStep for accurate quote calculation
    /// @param params The quote parameters
    /// @return result The quote result with expected amounts
    function getQuote(QuoteParams memory params) external view returns (QuoteResult memory result) {
        PoolId poolId = params.poolKey.toId();

        // Get current pool state using StateLibrary
        (uint160 sqrtPriceX96,, uint24 protocolFee, uint24 lpFee) = POOL_MANAGER.getSlot0(poolId);

        // Validate pool has liquidity
        if (sqrtPriceX96 == 0) {
            revert ZERO_LIQUIDITY();
        }

        // Get pool liquidity
        uint128 liquidity = POOL_MANAGER.getLiquidity(poolId);

        // Calculate target price (simplified - use current price if no limit)
        uint160 sqrtPriceTargetX96 = params.sqrtPriceLimitX96 == 0
            ? (params.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1)
            : params.sqrtPriceLimitX96;

        // Use real V4 SwapMath for accurate quote
        (uint160 sqrtPriceNextX96,, uint256 amountOut,) = SwapMath.computeSwapStep(
            sqrtPriceX96,
            sqrtPriceTargetX96,
            liquidity,
            -int256(params.amountIn), // Negative for exact input
            lpFee + protocolFee
        );

        result.amountOut = amountOut;
        result.sqrtPriceX96After = sqrtPriceNextX96;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates new minAmountOut ensuring ratio protection
    /// @dev Formula: newMinAmount = originalMinAmount * (actualAmountIn / originalAmountIn)
    ///      Validates that ratio change doesn't exceed maxSlippageDeviationBps
    /// @param params The recalculation parameters
    /// @return newMinAmountOut The calculated minAmountOut with ratio protection
    function _calculateDynamicMinAmount(RecalculationParams memory params)
        internal
        pure
        returns (uint256 newMinAmountOut)
    {
        // Input validation
        if (params.originalAmountIn == 0 || params.originalMinAmountOut == 0) {
            revert INVALID_ORIGINAL_AMOUNTS();
        }
        if (params.actualAmountIn == 0) {
            revert INVALID_ACTUAL_AMOUNT();
        }

        // Calculate the ratio of actual to original amount (using 1e18 precision)
        uint256 amountRatio = (params.actualAmountIn * 1e18) / params.originalAmountIn;

        // Calculate new minAmountOut proportionally
        newMinAmountOut = (params.originalMinAmountOut * amountRatio) / 1e18;

        // Calculate ratio deviation in basis points
        uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);
        // Validate ratio deviation is within allowed bounds
        if (ratioDeviationBps > params.maxSlippageDeviationBps) {
            revert EXCESSIVE_SLIPPAGE_DEVIATION(ratioDeviationBps, params.maxSlippageDeviationBps);
        }

        // Note: Quote validation removed - the ratio check protects against excessive input deviation,
        // and the actual swap will validate against minAmountOut in unlockCallback
    }

    /// @notice Internal function to calculate ratio deviation in basis points
    /// @dev Handles both increases and decreases from the 1:1 ratio
    /// @param amountRatio The ratio in 1e18 precision
    /// @return ratioDeviationBps The deviation in basis points
    function _calculateRatioDeviationBps(uint256 amountRatio) private pure returns (uint256 ratioDeviationBps) {
        if (amountRatio > 1e18) {
            // Ratio increased (more actual than original)
            ratioDeviationBps = ((amountRatio - 1e18) * MAX_BPS) / 1e18;
        } else {
            // Ratio decreased (less actual than original)
            ratioDeviationBps = ((1e18 - amountRatio) * MAX_BPS) / 1e18;
        }
    }

    /// @notice Extract transfer parameters without causing stack depth issues
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the hook
    /// @param data The encoded hook data
    /// @return inputToken The input token address
    /// @return amountIn The amount to transfer
    function _getTransferParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (address inputToken, uint256 amountIn)
    {
        // Decode minimal data needed for transfer using BytesLib
        address currency0 = data.toAddress(0);
        address currency1 = data.toAddress(20);
        bool zeroForOne = _decodeBool(data, 216);
        bool usePrevHookAmount = _decodeBool(data, 217);

        // Get input token address (native ETH = address(0))
        inputToken = zeroForOne ? currency0 : currency1;

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
        } else {
            // Extract originalAmountIn from new position 120-152
            amountIn = data.toUint256(120);
        }
    }

    /// @notice Prepare unlock data for the pool manager
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the hook
    /// @param data The encoded hook data
    /// @return unlockData The encoded data for the unlock callback
    function _prepareUnlockData(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (bytes memory unlockData)
    {
        // Decode hook data
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

        // Calculate actual amount
        uint256 actualAmountIn = usePrevHookAmount ? ISuperHookResult(prevHook).getOutAmount(account) : originalAmountIn;
        // Calculate dynamic min amount
        uint256 dynamicMinAmountOut = _calculateDynamicMinAmount(
            RecalculationParams({
                originalAmountIn: originalAmountIn,
                originalMinAmountOut: originalMinAmountOut,
                actualAmountIn: actualAmountIn,
                maxSlippageDeviationBps: maxSlippageDeviationBps
            })
        );

        // Encode unlock data
        unlockData = abi.encode(
            poolKey, actualAmountIn, dynamicMinAmountOut, dstReceiver, sqrtPriceLimitX96, zeroForOne, additionalData
        );
    }

    /// @notice Decodes the enhanced hook data structure
    /// @param data The encoded hook data
    /// @return poolKey The Uniswap V4 pool key
    /// @return dstReceiver The destination receiver address
    /// @return sqrtPriceLimitX96 The price limit for the swap
    /// @return originalAmountIn The original user-provided amount in
    /// @return originalMinAmountOut The original user-provided minimum amount out
    /// @return maxSlippageDeviationBps The maximum allowed slippage deviation
    /// @return zeroForOne Whether swapping token0 for token1
    /// @return usePrevHookAmount Whether to use previous hook amount
    /// @return additionalData Any additional data for the swap
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
        if (data.length < 218) {
            revert INVALID_HOOK_DATA();
        }

        // Construct PoolKey from individual components to avoid stack too deep
        poolKey = PoolKey({
            currency0: Currency.wrap(data.toAddress(0)),
            currency1: Currency.wrap(data.toAddress(20)),
            fee: uint24(data.toUint32(40)),
            tickSpacing: int24(int32(data.toUint32(44))),
            hooks: IHooks(data.toAddress(48))
        });

        // Validate PoolKey components
        if (Currency.unwrap(poolKey.currency0) == Currency.unwrap(poolKey.currency1)) revert INVALID_HOOK_DATA();
        if (poolKey.fee == 0) revert INVALID_HOOK_DATA();
        if (poolKey.tickSpacing == 0) revert INVALID_HOOK_DATA();

        // Decode remaining fields using BytesLib
        dstReceiver = data.toAddress(68);
        sqrtPriceLimitX96 = uint160(data.toUint256(88));
        originalAmountIn = data.toUint256(120);
        originalMinAmountOut = data.toUint256(152);
        maxSlippageDeviationBps = data.toUint256(184);
        zeroForOne = _decodeBool(data, 216);
        usePrevHookAmount = _decodeBool(data, 217);

        // Additional data is everything after the fixed structure
        if (data.length > 218) {
            additionalData = data.slice(218, data.length - 218);
        }
    }

    /// @notice Gets the output token from hook data
    /// @param data The hook data
    /// @return outputToken The output token address
    function _getOutputToken(bytes calldata data) internal pure returns (address outputToken) {
        // Decode just the needed fields using BytesLib
        address currency0 = data.toAddress(0);
        address currency1 = data.toAddress(20);
        bool zeroForOne = _decodeBool(data, 216);

        // Get output token address (native ETH = address(0))
        outputToken = zeroForOne ? currency1 : currency0;
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSIENT STORAGE HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Stores unlock data in transient storage using the correct pattern
    /// @dev Follows SignatureTransientStorage pattern: stores length first, then data chunks
    /// @param data The unlock data to store
    function _storeUnlockData(bytes memory data) private {
        bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
        uint256 len = data.length;

        // Store the length first
        assembly {
            tstore(storageKey, len)
        }

        // Store data in 32-byte chunks
        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := mload(add(add(data, 0x20), i))
                tstore(add(storageKey, div(add(i, 32), 32)), word)
            }
        }
    }

    /// @notice Loads unlock data from transient storage
    /// @dev Follows SignatureTransientStorage pattern: loads length first, then reconstructs data
    /// @return out The retrieved unlock data
    function _loadUnlockData() private view returns (bytes memory out) {
        bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
        uint256 len;

        // Load the length first
        assembly {
            len := tload(storageKey)
        }

        // Create new bytes array of the correct length
        out = new bytes(len);
        // Load data from 32-byte chunks
        for (uint256 i; i < len; i += 32) {
            bytes32 word;
            assembly {
                word := tload(add(storageKey, div(add(i, 32), 32)))
            }

            // Copy word to output bytes
            assembly {
                mstore(add(add(out, 0x20), i), word)
            }
        }
    }

    /// @notice Clears unlock data from transient storage
    /// @dev Clears the length slot (data chunks will be automatically cleared)
    function _clearUnlockData() private {
        bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
        assembly {
            tstore(storageKey, 0)
        }
    }
}
