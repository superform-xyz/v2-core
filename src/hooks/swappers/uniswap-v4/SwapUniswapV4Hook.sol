// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External imports
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform imports
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";

// Real Uniswap V4 imports
import { IPoolManager } from "v4-core/interfaces/IPoolManager.sol";
import { IUnlockCallback } from "v4-core/interfaces/callback/IUnlockCallback.sol";
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
contract SwapUniswapV4Hook is BaseHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V4 Pool Manager contract
    IPoolManager public immutable POOL_MANAGER;

    /// @notice Temporary storage for unlock data during execution
    bytes private pendingUnlockData;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the swap output is below the minimum required
    error INSUFFICIENT_OUTPUT_AMOUNT(uint256 actual, uint256 minimum);

    /// @notice Thrown when an unauthorized caller attempts to use the unlock callback
    error UNAUTHORIZED_CALLBACK();

    /// @notice Thrown when the hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /// @notice Thrown when quote deviation exceeds safety bounds
    error QUOTE_DEVIATION_EXCEEDS_SAFETY_BOUNDS();

    /// @notice Thrown when swap execution fails
    error SWAP_EXECUTION_FAILED();

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

    /// @notice Thrown when the quote calculation fails
    error QUOTE_CALCULATION_FAILED();

    /// @notice Thrown when an invalid price limit is provided (e.g., 0)
    error INVALID_PRICE_LIMIT();
    error INVALID_OUTPUT_DELTA();

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

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V4 swap hook
    /// @param poolManager_ The address of the Uniswap V4 Pool Manager
    constructor(address poolManager_) BaseHook(ISuperHook.HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        POOL_MANAGER = IPoolManager(poolManager_);
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
        // Extract just the token and amount for the transfer
        (address inputToken, uint256 amountIn) = _getTransferParams(prevHook, account, data);

        // Single execution: transfer tokens from account to hook
        // Since the account is executing this, it should use transfer, not transferFrom
        executions = new Execution[](1);
        executions[0] = Execution({
            target: inputToken,
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, address(this), amountIn)
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        // Store relevant context for postExecute
        asset = _getInputToken(data);
        spToken = _getOutputToken(data);

        // Prepare and store unlock data for postExecute
        pendingUnlockData = _prepareUnlockData(prevHook, account, data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, /* prevHook */ address account, bytes calldata /* data */ ) internal override {
        // Now the hook has the tokens, execute unlock
        // The callback will come to this hook since we're msg.sender
        bytes memory unlockResult = POOL_MANAGER.unlock(pendingUnlockData);

        // Clear storage
        delete pendingUnlockData;

        // Decode the output amount from unlock result
        uint256 outputAmount = abi.decode(unlockResult, (uint256));

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

        // Validate price limit - must be non-zero
        if (sqrtPriceLimitX96 == 0) {
            revert INVALID_PRICE_LIMIT();
        }

        // Determine swap direction and currencies
        Currency inputCurrency = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        Currency outputCurrency = zeroForOne ? poolKey.currency1 : poolKey.currency0;
        address inputToken = Currency.unwrap(inputCurrency);

        // Sync the input currency first (required for ERC20 settlement)
        POOL_MANAGER.sync(inputCurrency);

        // Transfer input tokens from this hook to the Pool Manager
        // The hook already has the tokens from the account via transfer in _buildHookExecutions
        IERC20(inputToken).transfer(address(POOL_MANAGER), amountIn);

        // Settle the input currency with the Pool Manager
        POOL_MANAGER.settle();

        // Execute the swap with dynamic parameters
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn), // Exact input (negative for exact input)
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        BalanceDelta swapDelta = POOL_MANAGER.swap(poolKey, swapParams, additionalData);

        // Extract output amount and validate against minimum
        int128 deltaOut = zeroForOne ? swapDelta.amount1() : swapDelta.amount0();

        // Per Uniswap V4 docs, BalanceDelta signs are from the caller's perspective:
        // positive = caller receives (owed by pool), negative = caller pays (owes to pool)
        // For exact-input swaps (amountSpecified < 0), output delta is positive (we receive output)
        if (deltaOut <= 0) {
            revert INVALID_OUTPUT_DELTA();
        }

        uint256 amountOut = uint256(int256(deltaOut));
        if (amountOut < minAmountOut) {
            revert INSUFFICIENT_OUTPUT_AMOUNT(amountOut, minAmountOut);
        }

        // Take output tokens and send to the specified receiver
        POOL_MANAGER.take(outputCurrency, dstReceiver, amountOut);

        return abi.encode(amountOut);
    }

    /*//////////////////////////////////////////////////////////////
                            DYNAMIC MIN AMOUNT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates new minAmountOut ensuring ratio protection
    /// @dev Formula: newMinAmount = originalMinAmount * (actualAmountIn / originalAmountIn)
    ///      Validates that ratio change doesn't exceed maxSlippageDeviationBps
    /// @param params The recalculation parameters
    /// @return newMinAmountOut The calculated minAmountOut with ratio protection
    function _calculateDynamicMinAmount(
        RecalculationParams memory params,
        PoolKey memory poolKey,
        bool zeroForOne
    )
        internal
        view
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

        // Validate quote deviation using the calculated amount
        _validateQuoteDeviation(poolKey, params.actualAmountIn, newMinAmountOut, zeroForOne);
    }

    /// @notice Internal function to calculate ratio deviation in basis points
    /// @dev Handles both increases and decreases from the 1:1 ratio
    /// @param amountRatio The ratio in 1e18 precision
    /// @return ratioDeviationBps The deviation in basis points
    function _calculateRatioDeviationBps(uint256 amountRatio) private pure returns (uint256 ratioDeviationBps) {
        if (amountRatio > 1e18) {
            // Ratio increased (more actual than original)
            ratioDeviationBps = ((amountRatio - 1e18) * 10_000) / 1e18;
        } else {
            // Ratio decreased (less actual than original)
            ratioDeviationBps = ((1e18 - amountRatio) * 10_000) / 1e18;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            QUOTE GENERATION LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Generate on-chain quote using pool state and real V4 math
    /// @dev Uses SwapMath.computeSwapStep for accurate quote calculation
    /// @param params The quote parameters
    /// @return result The quote result with expected amounts
    function getQuote(QuoteParams memory params) public view returns (QuoteResult memory result) {
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

    /// @notice Validate quote deviation from expected output
    /// @dev Ensures on-chain quote aligns with user expectations within tolerance
    /// @param poolKey The pool key to validate against
    /// @param amountIn The input amount
    /// @param expectedMinOut The expected minimum output
    /// @param zeroForOne Whether swapping token0 for token1
    /// @return isValid True if the quote is within acceptable bounds
    function _validateQuoteDeviation(
        PoolKey memory poolKey,
        uint256 amountIn,
        uint256 expectedMinOut,
        bool zeroForOne
    )
        internal
        view
        returns (bool isValid)
    {
        QuoteResult memory quote = getQuote(
            QuoteParams({
                poolKey: poolKey,
                zeroForOne: zeroForOne,
                amountIn: amountIn,
                sqrtPriceLimitX96: 0 // No price limit for quote validation
             })
        );

        // Calculate deviation percentage in basis points
        uint256 deviationBps = quote.amountOut > expectedMinOut
            ? ((quote.amountOut - expectedMinOut) * 10_000) / quote.amountOut
            : ((expectedMinOut - quote.amountOut) * 10_000) / expectedMinOut;

        isValid = deviationBps <= 1000; // 10% max deviation (more reasonable for live conditions)

        if (!isValid) {
            revert QUOTE_DEVIATION_EXCEEDS_SAFETY_BOUNDS();
        }

        return isValid;
    }

    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        // Decode hook data to extract token information
        (PoolKey memory poolKey,,,,,,,,) = _decodeHookData(data);

        // Return packed token addresses for inspection
        return abi.encodePacked(
            Currency.unwrap(poolKey.currency0), // Input token
            Currency.unwrap(poolKey.currency1) // Output token
        );
    }

    /// @notice Decodes the usePrevHookAmount flag from hook data
    /// @param data The encoded hook data
    /// @return usePrevHookAmount Whether to use the previous hook's output amount
    function decodeUsePrevHookAmount(bytes calldata data) external pure returns (bool usePrevHookAmount) {
        if (data.length < 298) {
            revert INVALID_HOOK_DATA();
        }
        usePrevHookAmount = _decodeBool(data, 297);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

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
        // Decode minimal data needed for transfer
        PoolKey memory poolKey = abi.decode(data[0:160], (PoolKey));
        bool zeroForOne = _decodeBool(data, 296);
        bool usePrevHookAmount = _decodeBool(data, 297);

        inputToken = zeroForOne ? Currency.unwrap(poolKey.currency0) : Currency.unwrap(poolKey.currency1);

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
        } else {
            // Extract originalAmountIn from position 200-232
            amountIn = uint256(bytes32(data[200:232]));
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
            }),
            poolKey,
            zeroForOne
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
        if (data.length < 298) {
            revert INVALID_HOOK_DATA();
        }

        // Decode the structured data
        poolKey = abi.decode(data[0:160], (PoolKey));
        dstReceiver = address(bytes20(data[160:180]));
        sqrtPriceLimitX96 = uint160(bytes20(data[180:200]));
        originalAmountIn = uint256(bytes32(data[200:232]));
        originalMinAmountOut = uint256(bytes32(data[232:264]));
        maxSlippageDeviationBps = uint256(bytes32(data[264:296]));
        zeroForOne = _decodeBool(data, 296);
        usePrevHookAmount = _decodeBool(data, 297);

        // Additional data is everything after the fixed structure
        if (data.length > 298) {
            additionalData = data[298:];
        }
    }

    /// @notice Gets the input token from hook data
    /// @param data The hook data
    /// @return inputToken The input token address
    function _getInputToken(bytes calldata data) internal pure returns (address inputToken) {
        (PoolKey memory poolKey,,,,,, bool zeroForOne,,) = _decodeHookData(data);
        inputToken = zeroForOne ? Currency.unwrap(poolKey.currency0) : Currency.unwrap(poolKey.currency1);
    }

    /// @notice Gets the output token from hook data
    /// @param data The hook data
    /// @return outputToken The output token address
    function _getOutputToken(bytes calldata data) internal pure returns (address outputToken) {
        (PoolKey memory poolKey,,,,,, bool zeroForOne,,) = _decodeHookData(data);
        outputToken = zeroForOne ? Currency.unwrap(poolKey.currency1) : Currency.unwrap(poolKey.currency0);
    }
}
