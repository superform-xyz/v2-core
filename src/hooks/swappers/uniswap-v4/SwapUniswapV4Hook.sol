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
///      Solves the circular dependency issues faced with 0x Protocol by using real-time calculations
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

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the swap output is below the minimum required
    error InsufficientOutputAmount(uint256 actual, uint256 minimum);

    /// @notice Thrown when an unauthorized caller attempts to use the unlock callback
    error UnauthorizedCallback();

    /// @notice Thrown when the hook data is malformed or insufficient
    error InvalidHookData();

    /// @notice Thrown when quote deviation exceeds safety bounds
    error QuoteDeviationExceedsSafetyBounds();

    /// @notice Thrown when swap execution fails
    error SwapExecutionFailed();

    /// @notice Thrown when the ratio deviation exceeds the maximum allowed
    /// @param actualDeviation The actual ratio deviation in basis points
    /// @param maxAllowed The maximum allowed deviation in basis points
    error ExcessiveSlippageDeviation(uint256 actualDeviation, uint256 maxAllowed);

    /// @notice Thrown when original amounts are zero or invalid
    error InvalidOriginalAmounts();

    /// @notice Thrown when actual amount is zero
    error InvalidActualAmount();

    /// @notice Thrown when the pool has zero liquidity
    error ZeroLiquidity();

    /// @notice Thrown when the quote calculation fails
    error QuoteCalculationFailed();

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
        // Decode enhanced hook data with dynamic recalculation parameters
        (
            PoolKey memory poolKey,
            address dstReceiver,
            uint160 sqrtPriceLimitX96,
            uint256 originalAmountIn,
            uint256 originalMinAmountOut,
            uint256 maxSlippageDeviationBps,
            bool usePrevHookAmount,
            bytes memory additionalData
        ) = _decodeHookData(data);

        // Get actual swap amount (potentially changed by previous hooks/bridges)
        uint256 actualAmountIn = usePrevHookAmount ? ISuperHookResult(prevHook).getOutAmount(account) : originalAmountIn;

        // Calculate dynamic minAmountOut with ratio protection
        uint256 dynamicMinAmountOut = _calculateDynamicMinAmount(
            RecalculationParams({
                originalAmountIn: originalAmountIn,
                originalMinAmountOut: originalMinAmountOut,
                actualAmountIn: actualAmountIn,
                maxSlippageDeviationBps: maxSlippageDeviationBps
            })
        );

        // Validate quote deviation using on-chain oracle
        _validateQuoteDeviation(poolKey, actualAmountIn, dynamicMinAmountOut);

        // Create unlock call with recalculated parameters
        bytes memory unlockData =
            abi.encode(poolKey, actualAmountIn, dynamicMinAmountOut, dstReceiver, sqrtPriceLimitX96, additionalData);

        // Build execution for the unlock call
        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(POOL_MANAGER),
            value: 0,
            callData: abi.encodeWithSelector(IPoolManager.unlock.selector, unlockData)
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, /* prevHook */ address, /* account */ bytes calldata data) internal override {
        // Store relevant context for postExecute
        asset = _getInputToken(data);
        spToken = _getOutputToken(data);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, /* prevHook */ address account, bytes calldata /* data */ ) internal override {
        // Calculate and set the final output amount
        uint256 outputBalance = IERC20(spToken).balanceOf(account);
        _setOutAmount(outputBalance, account);

        // Additional post-execution cleanup can be added here
    }

    /*//////////////////////////////////////////////////////////////
                            UNLOCK CALLBACK
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IUnlockCallback
    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        // Ensure only the Pool Manager can call this
        if (msg.sender != address(POOL_MANAGER)) {
            revert UnauthorizedCallback();
        }

        // Decode unlock data
        (
            PoolKey memory poolKey,
            uint256 amountIn,
            uint256 minAmountOut,
            address dstReceiver,
            uint160 sqrtPriceLimitX96,
            bytes memory additionalData
        ) = abi.decode(data, (PoolKey, uint256, uint256, address, uint160, bytes));

        // Determine swap direction (assuming token0 -> token1 for now)
        bool zeroForOne = true; // This should be determined from pool key analysis

        // Take input tokens from the account and settle with Pool Manager
        Currency inputCurrency = zeroForOne ? poolKey.currency0 : poolKey.currency1;
        POOL_MANAGER.take(inputCurrency, address(this), amountIn);
        POOL_MANAGER.settle();

        // Execute the swap with dynamic parameters
        IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn), // Exact input (negative for exact input)
            sqrtPriceLimitX96: sqrtPriceLimitX96
        });

        BalanceDelta swapDelta = POOL_MANAGER.swap(poolKey, swapParams, additionalData);

        // Extract output amount and validate against minimum
        uint256 amountOut = uint256(int256(-swapDelta.amount1()));
        if (amountOut < minAmountOut) {
            revert InsufficientOutputAmount(amountOut, minAmountOut);
        }

        // Transfer output tokens to the specified receiver
        Currency outputCurrency = zeroForOne ? poolKey.currency1 : poolKey.currency0;
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
    function _calculateDynamicMinAmount(RecalculationParams memory params)
        internal
        pure
        returns (uint256 newMinAmountOut)
    {
        // Input validation
        if (params.originalAmountIn == 0 || params.originalMinAmountOut == 0) {
            revert InvalidOriginalAmounts();
        }
        if (params.actualAmountIn == 0) {
            revert InvalidActualAmount();
        }

        // Calculate the ratio of actual to original amount (using 1e18 precision)
        uint256 amountRatio = (params.actualAmountIn * 1e18) / params.originalAmountIn;

        // Calculate new minAmountOut proportionally
        newMinAmountOut = (params.originalMinAmountOut * amountRatio) / 1e18;

        // Calculate ratio deviation in basis points
        uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);

        // Validate ratio deviation is within allowed bounds
        if (ratioDeviationBps > params.maxSlippageDeviationBps) {
            revert ExcessiveSlippageDeviation(ratioDeviationBps, params.maxSlippageDeviationBps);
        }
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
    function _getQuote(QuoteParams memory params) internal view returns (QuoteResult memory result) {
        PoolId poolId = params.poolKey.toId();

        // Get current pool state using StateLibrary
        (uint160 sqrtPriceX96,, uint24 protocolFee, uint24 lpFee) = POOL_MANAGER.getSlot0(poolId);

        // Validate pool has liquidity
        if (sqrtPriceX96 == 0) {
            revert ZeroLiquidity();
        }

        // Get pool liquidity
        uint128 liquidity = POOL_MANAGER.getLiquidity(poolId);

        // Calculate target price (simplified - use current price if no limit)
        uint160 sqrtPriceTargetX96 = params.sqrtPriceLimitX96 == 0
            ? (params.zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1)
            : params.sqrtPriceLimitX96;

        // Use real V4 SwapMath for accurate quote
        (uint160 sqrtPriceNextX96, , uint256 amountOut, ) = SwapMath.computeSwapStep(
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
    /// @return isValid True if the quote is within acceptable bounds
    function _validateQuoteDeviation(
        PoolKey memory poolKey,
        uint256 amountIn,
        uint256 expectedMinOut
    )
        internal
        view
        returns (bool isValid)
    {
        QuoteResult memory quote = _getQuote(
            QuoteParams({
                poolKey: poolKey,
                zeroForOne: true, // Assuming token0 -> token1 for validation
                amountIn: amountIn,
                sqrtPriceLimitX96: 0 // No price limit for quote validation
             })
        );

        // Calculate deviation percentage in basis points
        uint256 deviationBps = quote.amountOut > expectedMinOut
            ? ((quote.amountOut - expectedMinOut) * 10_000) / quote.amountOut
            : ((expectedMinOut - quote.amountOut) * 10_000) / expectedMinOut;

        isValid = deviationBps <= 500; // 5% max deviation

        if (!isValid) {
            revert QuoteDeviationExceedsSafetyBounds();
        }

        return isValid;
    }


    /*//////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        // Decode hook data to extract token information
        (PoolKey memory poolKey,,,,,,,) = _decodeHookData(data);

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
        if (data.length < 297) {
            revert InvalidHookData();
        }
        usePrevHookAmount = _decodeBool(data, 296);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes the enhanced hook data structure
    /// @param data The encoded hook data
    /// @return poolKey The Uniswap V4 pool key
    /// @return dstReceiver The destination receiver address
    /// @return sqrtPriceLimitX96 The price limit for the swap
    /// @return originalAmountIn The original user-provided amount in
    /// @return originalMinAmountOut The original user-provided minimum amount out
    /// @return maxSlippageDeviationBps The maximum allowed slippage deviation
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
            bool usePrevHookAmount,
            bytes memory additionalData
        )
    {
        if (data.length < 297) {
            revert InvalidHookData();
        }

        // Decode the structured data
        poolKey = abi.decode(data[0:160], (PoolKey));
        dstReceiver = address(bytes20(data[160:180]));
        sqrtPriceLimitX96 = uint160(bytes20(data[180:200]));
        originalAmountIn = uint256(bytes32(data[200:232]));
        originalMinAmountOut = uint256(bytes32(data[232:264]));
        maxSlippageDeviationBps = uint256(bytes32(data[264:296]));
        usePrevHookAmount = _decodeBool(data, 296);

        // Additional data is everything after the fixed structure
        if (data.length > 297) {
            additionalData = data[297:];
        }
    }

    /// @notice Gets the input token from hook data
    /// @param data The hook data
    /// @return inputToken The input token address
    function _getInputToken(bytes calldata data) internal pure returns (address inputToken) {
        (PoolKey memory poolKey,,,,,,,) = _decodeHookData(data);
        inputToken = Currency.unwrap(poolKey.currency0); // Assuming token0 is input
    }

    /// @notice Gets the output token from hook data
    /// @param data The hook data
    /// @return outputToken The output token address
    function _getOutputToken(bytes calldata data) internal pure returns (address outputToken) {
        (PoolKey memory poolKey,,,,,,,) = _decodeHookData(data);
        outputToken = Currency.unwrap(poolKey.currency1); // Assuming token1 is output
    }
}
