// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @notice Interface for Uniswap V4 PoolManager required by Superform hooks
/// @dev Minimal interface containing only the functions needed for quote generation and swaps
interface IPoolManagerSuperform {
    /// @notice Parameters for a swap
    /// @param zeroForOne Whether to swap token0 for token1 or token1 for token0
    /// @param amountSpecified The amount of the swap (positive for exact input, negative for exact output)
    /// @param sqrtPriceLimitX96 The price limit for the swap (0 for no limit)
    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Get the current state of a pool
    /// @param poolId The ID of the pool
    /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
    /// @return tick The current tick of the pool
    /// @return protocolFee The current protocol fee of the pool
    /// @return lpFee The current LP fee of the pool
    function getSlot0(
        bytes32 poolId
    ) external view returns (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 lpFee);

    /// @notice Execute a swap on a pool
    /// @param key The pool key
    /// @param params The swap parameters
    /// @param hookData Any data to pass to the hook
    /// @return swapDelta The balance delta of the swap
    function swap(
        PoolKey memory key,
        SwapParams memory params,
        bytes calldata hookData
    ) external returns (BalanceDelta swapDelta);

    /// @notice Call the unlock callback
    /// @param data The data to pass to the callback
    /// @return The return data from the callback
    function unlock(bytes calldata data) external returns (bytes memory);

    /// @notice Take tokens from the pool manager
    /// @param currency The currency to take
    /// @param to The address to send the tokens to
    /// @param amount The amount to take
    function take(Currency currency, address to, uint256 amount) external;

    /// @notice Settle tokens with the pool manager
    /// @param currency The currency to settle
    function settle(Currency currency) external;
}

/// @notice A currency type for Uniswap V4
type Currency is address;

/// @notice Library for working with currencies
library CurrencyLibrary {
    /// @notice Wraps an address as a currency
    function wrap(address addr) internal pure returns (Currency) {
        return Currency.wrap(addr);
    }

    /// @notice Unwraps a currency to an address
    function unwrap(Currency currency) internal pure returns (address) {
        return Currency.unwrap(currency);
    }
}

/// @notice A hook interface for Uniswap V4
interface IHooks {
    // Minimal interface - can be expanded as needed
}

/// @notice A pool key for Uniswap V4
/// @param currency0 The first currency of the pool
/// @param currency1 The second currency of the pool  
/// @param fee The fee tier of the pool
/// @param tickSpacing The tick spacing of the pool
/// @param hooks The hooks contract for the pool
struct PoolKey {
    Currency currency0;
    Currency currency1;
    uint24 fee;
    int24 tickSpacing;
    IHooks hooks;
}

/// @notice A pool ID type for Uniswap V4
type PoolId is bytes32;

/// @notice Library for working with pool IDs
library PoolIdLibrary {
    /// @notice Converts a pool key to a pool ID
    function toId(PoolKey memory poolKey) internal pure returns (PoolId) {
        return PoolId.wrap(keccak256(abi.encode(poolKey)));
    }
}

/// @notice Represents a change in balance
/// @param amount0 The change in amount of currency0
/// @param amount1 The change in amount of currency1
struct BalanceDelta {
    int128 amount0;
    int128 amount1;
}

/// @notice Library for working with balance deltas
library BalanceDeltaLibrary {
    /// @notice Gets the amount0 from a balance delta
    function amount0(BalanceDelta memory delta) internal pure returns (int128) {
        return delta.amount0;
    }

    /// @notice Gets the amount1 from a balance delta
    function amount1(BalanceDelta memory delta) internal pure returns (int128) {
        return delta.amount1;
    }
}

/// @notice Interface for unlock callbacks
interface IUnlockCallback {
    /// @notice Called when the pool manager is unlocked
    /// @param data The data passed to the unlock function
    /// @return The return data from the callback
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}