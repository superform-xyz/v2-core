// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Superform imports
import { 
    IPoolManagerSuperform, 
    PoolKey, 
    Currency,
    CurrencyLibrary,
    BalanceDelta,
    BalanceDeltaLibrary,
    IUnlockCallback
} from "../../src/interfaces/external/uniswap-v4/IPoolManagerSuperform.sol";

/// @title MockPoolManager
/// @author Superform Labs
/// @notice Mock implementation of Uniswap V4 PoolManager for testing
/// @dev Simulates V4 pool behavior for integration testing before mainnet launch
contract MockPoolManager is IPoolManagerSuperform {
    using CurrencyLibrary for address;
    using BalanceDeltaLibrary for BalanceDelta;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Mock pool states
    mapping(bytes32 => PoolState) public pools;

    /// @notice Current unlock callback caller
    address private unlockCaller;

    /// @notice Mock exchange rates (token1 per token0 in 1e18 precision)
    mapping(bytes32 => uint256) public mockExchangeRates;

    /// @notice Mock liquidity for pools
    mapping(bytes32 => uint256) public mockLiquidity;

    struct PoolState {
        uint160 sqrtPriceX96;
        int24 tick;
        uint16 protocolFee;
        uint24 lpFee;
        bool initialized;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event MockSwap(
        bytes32 indexed poolId,
        address indexed user,
        bool zeroForOne,
        int256 amountSpecified,
        uint256 amountIn,
        uint256 amountOut
    );

    event MockUnlock(address indexed caller, bytes data);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        // Initialize common mock pools with reasonable state
        _initializeMockPool(
            _getMockPoolId(address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)), // USDC/WETH
            1771845812700000000000000000000000, // Mock sqrt price for USDC/WETH
            60, // tick
            3000, // 0.3% LP fee
            3000e18 // 3000 USDC per WETH
        );

        _initializeMockPool(
            _getMockPoolId(address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599)), // WETH/WBTC
            1000000000000000000000000000000000, // Mock sqrt price for WETH/WBTC
            60, // tick
            3000, // 0.3% LP fee
            20e18 // 20 WETH per WBTC
        );
    }

    /*//////////////////////////////////////////////////////////////
                            POOL MANAGER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPoolManagerSuperform
    function getSlot0(
        bytes32 poolId
    ) external view override returns (uint160 sqrtPriceX96, int24 tick, uint16 protocolFee, uint24 lpFee) {
        PoolState memory pool = pools[poolId];
        require(pool.initialized, "Pool not initialized");
        
        return (pool.sqrtPriceX96, pool.tick, pool.protocolFee, pool.lpFee);
    }

    /// @inheritdoc IPoolManagerSuperform
    function swap(
        PoolKey memory key,
        SwapParams memory params,
        bytes calldata hookData
    ) external override returns (BalanceDelta swapDelta) {
        bytes32 poolId = keccak256(abi.encode(key));
        PoolState memory pool = pools[poolId];
        require(pool.initialized, "Pool not initialized");

        // Calculate swap amounts using mock logic
        uint256 amountIn;
        uint256 amountOut;

        if (params.amountSpecified < 0) {
            // Exact input swap
            amountIn = uint256(-params.amountSpecified);
            amountOut = _calculateMockOutput(poolId, params.zeroForOne, amountIn);
        } else {
            // Exact output swap (not commonly used in tests)
            amountOut = uint256(params.amountSpecified);
            amountIn = _calculateMockInput(poolId, params.zeroForOne, amountOut);
        }

        // Apply fees
        uint256 feeAmount = (amountIn * pool.lpFee) / 1000000;
        amountOut = amountOut - feeAmount;

        // Create balance delta
        if (params.zeroForOne) {
            swapDelta = BalanceDelta({
                amount0: int128(uint128(amountIn)),   // Positive = tokens taken from user
                amount1: -int128(uint128(amountOut))  // Negative = tokens given to user
            });
        } else {
            swapDelta = BalanceDelta({
                amount0: -int128(uint128(amountOut)), // Negative = tokens given to user
                amount1: int128(uint128(amountIn))    // Positive = tokens taken from user
            });
        }

        emit MockSwap(poolId, msg.sender, params.zeroForOne, params.amountSpecified, amountIn, amountOut);
    }

    /// @inheritdoc IPoolManagerSuperform
    function unlock(bytes calldata data) external override returns (bytes memory) {
        unlockCaller = msg.sender;
        emit MockUnlock(msg.sender, data);
        
        // Call the unlock callback
        bytes memory result = IUnlockCallback(msg.sender).unlockCallback(data);
        
        unlockCaller = address(0);
        return result;
    }

    /// @inheritdoc IPoolManagerSuperform
    function take(Currency currency, address to, uint256 amount) external override {
        require(unlockCaller != address(0), "Not in unlock context");
        
        // Transfer tokens from this contract to the recipient
        // In a real scenario, this would be from the pool reserves
        IERC20(Currency.unwrap(currency)).transfer(to, amount);
    }

    /// @inheritdoc IPoolManagerSuperform
    function settle(Currency currency) external override {
        require(unlockCaller != address(0), "Not in unlock context");
        
        // In a real scenario, this would settle the currency balance
        // For mock purposes, we assume tokens have been transferred to this contract
    }

    /*//////////////////////////////////////////////////////////////
                            MOCK SETUP FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize a mock pool with given parameters
    /// @param poolId The pool identifier
    /// @param sqrtPriceX96 Initial sqrt price
    /// @param tick Initial tick
    /// @param lpFee LP fee tier
    /// @param exchangeRate Exchange rate for calculations (token1 per token0)
    function _initializeMockPool(
        bytes32 poolId,
        uint160 sqrtPriceX96,
        int24 tick,
        uint24 lpFee,
        uint256 exchangeRate
    ) internal {
        pools[poolId] = PoolState({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            protocolFee: 0,
            lpFee: lpFee,
            initialized: true
        });

        mockExchangeRates[poolId] = exchangeRate;
        mockLiquidity[poolId] = 1e24; // High liquidity for testing
    }

    /// @notice Set up a mock pool for testing
    /// @param key The pool key
    /// @param exchangeRate Exchange rate (token1 per token0 in 1e18 precision)
    function setupMockPool(PoolKey memory key, uint256 exchangeRate) external {
        bytes32 poolId = keccak256(abi.encode(key));
        
        _initializeMockPool(
            poolId,
            1000000000000000000000000000000000, // Default sqrt price
            60, // Default tick
            key.fee,
            exchangeRate
        );
    }

    /// @notice Add liquidity to mock pool (for more realistic testing)
    /// @param poolId Pool identifier
    /// @param token0 Token0 address
    /// @param token1 Token1 address
    /// @param amount0 Amount of token0 to add
    /// @param amount1 Amount of token1 to add
    function addMockLiquidity(
        bytes32 poolId,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) external {
        // Transfer tokens to this contract to simulate pool reserves
        if (amount0 > 0) {
            IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).transferFrom(msg.sender, address(this), amount1);
        }

        mockLiquidity[poolId] += amount0 + amount1;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate mock output amount for a swap
    /// @param poolId Pool identifier
    /// @param zeroForOne Swap direction
    /// @param amountIn Input amount
    /// @return amountOut Output amount
    function _calculateMockOutput(
        bytes32 poolId,
        bool zeroForOne,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        uint256 exchangeRate = mockExchangeRates[poolId];
        
        if (zeroForOne) {
            // Selling token0 for token1
            amountOut = (amountIn * exchangeRate) / 1e18;
        } else {
            // Selling token1 for token0  
            amountOut = (amountIn * 1e18) / exchangeRate;
        }

        // Apply simple slippage based on amount size
        uint256 slippage = (amountIn * 100) / mockLiquidity[poolId]; // Basic slippage model
        amountOut = (amountOut * (10000 - slippage)) / 10000;
    }

    /// @notice Calculate mock input amount for an exact output swap
    /// @param poolId Pool identifier
    /// @param zeroForOne Swap direction
    /// @param amountOut Desired output amount
    /// @return amountIn Required input amount
    function _calculateMockInput(
        bytes32 poolId,
        bool zeroForOne,
        uint256 amountOut
    ) internal view returns (uint256 amountIn) {
        uint256 exchangeRate = mockExchangeRates[poolId];
        
        if (zeroForOne) {
            // Need token0 to get token1
            amountIn = (amountOut * 1e18) / exchangeRate;
        } else {
            // Need token1 to get token0
            amountIn = (amountOut * exchangeRate) / 1e18;
        }

        // Add slippage buffer
        uint256 slippage = (amountOut * 100) / mockLiquidity[poolId];
        amountIn = (amountIn * (10000 + slippage)) / 10000;
    }

    /// @notice Generate mock pool ID from token pair
    /// @param token0 First token address
    /// @param token1 Second token address
    /// @return poolId Mock pool identifier
    function _getMockPoolId(address token0, address token1) internal pure returns (bytes32 poolId) {
        // Sort tokens to match V4 conventions
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }
        
        poolId = keccak256(abi.encodePacked(token0, token1, uint24(3000))); // Assume 0.3% fee
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Check if pool is initialized
    /// @param poolId Pool identifier
    /// @return initialized Whether the pool exists
    function isPoolInitialized(bytes32 poolId) external view returns (bool initialized) {
        return pools[poolId].initialized;
    }

    /// @notice Get mock exchange rate for a pool
    /// @param poolId Pool identifier
    /// @return exchangeRate Exchange rate (token1 per token0)
    function getExchangeRate(bytes32 poolId) external view returns (uint256 exchangeRate) {
        return mockExchangeRates[poolId];
    }

    /// @notice Get mock liquidity for a pool
    /// @param poolId Pool identifier
    /// @return liquidity Available liquidity
    function getLiquidity(bytes32 poolId) external view returns (uint256 liquidity) {
        return mockLiquidity[poolId];
    }
}