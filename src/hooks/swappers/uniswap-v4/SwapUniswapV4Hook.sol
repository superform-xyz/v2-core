// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// External imports
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform imports
import { BaseHook } from "../../BaseHook.sol";
import { ISuperHook, ISuperHookResult } from "../../../interfaces/ISuperHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { DynamicMinAmountCalculator } from "../../../libraries/uniswap-v4/DynamicMinAmountCalculator.sol";
import { UniswapV4QuoteOracle } from "../../../libraries/uniswap-v4/UniswapV4QuoteOracle.sol";

// Uniswap V4 imports
import { 
    IPoolManagerSuperform, 
    IUnlockCallback,
    PoolKey, 
    PoolId, 
    Currency,
    CurrencyLibrary,
    BalanceDelta,
    BalanceDeltaLibrary
} from "../../../interfaces/external/uniswap-v4/IPoolManagerSuperform.sol";

/// @title SwapUniswapV4Hook
/// @author Superform Labs  
/// @notice Hook for executing swaps via Uniswap V4 with dynamic minAmountOut recalculation
/// @dev Implements dynamic slippage protection and on-chain quote generation
///      Solves the circular dependency issues faced with 0x Protocol by using real-time calculations
contract SwapUniswapV4Hook is BaseHook, IUnlockCallback {
    using DynamicMinAmountCalculator for DynamicMinAmountCalculator.RecalculationParams;
    using CurrencyLibrary for address;
    using BalanceDeltaLibrary for BalanceDelta;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V4 Pool Manager contract
    IPoolManagerSuperform public immutable POOL_MANAGER;

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

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V4 swap hook
    /// @param poolManager_ The address of the Uniswap V4 Pool Manager
    constructor(address poolManager_) BaseHook(ISuperHook.HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        POOL_MANAGER = IPoolManagerSuperform(poolManager_);
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
        uint256 actualAmountIn = usePrevHookAmount ? 
            ISuperHookResult(prevHook).getOutAmount(account) : 
            originalAmountIn;

        // Calculate dynamic minAmountOut with ratio protection
        uint256 dynamicMinAmountOut = DynamicMinAmountCalculator.calculateDynamicMinAmount(
            DynamicMinAmountCalculator.RecalculationParams({
                originalAmountIn: originalAmountIn,
                originalMinAmountOut: originalMinAmountOut,
                actualAmountIn: actualAmountIn,
                maxSlippageDeviationBps: maxSlippageDeviationBps
            })
        );

        // Validate quote deviation using on-chain oracle
        _validateQuoteDeviation(poolKey, actualAmountIn, dynamicMinAmountOut);

        // Create unlock call with recalculated parameters
        bytes memory unlockData = abi.encode(
            poolKey, 
            actualAmountIn, 
            dynamicMinAmountOut, 
            dstReceiver,
            sqrtPriceLimitX96,
            additionalData
        );

        // Build execution for the unlock call
        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(POOL_MANAGER),
            value: 0,
            callData: abi.encodeWithSelector(IPoolManagerSuperform.unlock.selector, unlockData)
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address prevHook, address account, bytes calldata data) internal override {
        // Set execution context for tracking
        (, address dstReceiver,,,,,, bytes memory additionalData) = _decodeHookData(data);
        
        // Store relevant context for postExecute
        asset = _getInputToken(data);
        spToken = _getOutputToken(data);
        
        // Additional pre-execution validations can be added here
    }

    /// @inheritdoc BaseHook
    function _postExecute(address prevHook, address account, bytes calldata data) internal override {
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
        POOL_MANAGER.settle(inputCurrency);

        // Execute the swap with dynamic parameters
        IPoolManagerSuperform.SwapParams memory swapParams = IPoolManagerSuperform.SwapParams({
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
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external view override returns (bytes memory) {
        // Decode hook data to extract token information
        (PoolKey memory poolKey,,,,,,,) = _decodeHookData(data);
        
        // Return packed token addresses for inspection
        return abi.encodePacked(
            Currency.unwrap(poolKey.currency0), // Input token
            Currency.unwrap(poolKey.currency1)  // Output token
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

    /// @notice Validates quote deviation using on-chain oracle
    /// @dev Ensures the dynamic minAmountOut aligns with current market conditions
    /// @param poolKey The pool key for the swap
    /// @param actualAmountIn The actual input amount
    /// @param dynamicMinAmountOut The calculated minimum output amount
    function _validateQuoteDeviation(
        PoolKey memory poolKey,
        uint256 actualAmountIn,
        uint256 dynamicMinAmountOut
    ) 
        internal 
        view 
    {
        bool isValid = UniswapV4QuoteOracle.validateQuoteDeviation(
            POOL_MANAGER,
            poolKey,
            actualAmountIn,
            UniswapV4QuoteOracle.ValidationParams({
                expectedMinOut: dynamicMinAmountOut,
                maxDeviationBps: 500 // 5% max deviation from on-chain quote
            })
        );
        
        if (!isValid) {
            revert QuoteDeviationExceedsSafetyBounds();
        }
    }

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