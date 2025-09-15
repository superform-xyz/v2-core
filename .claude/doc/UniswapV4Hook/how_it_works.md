1. Hook Initialization & Setup

constructor(address poolManager_) BaseHook(ISuperHook.HookType.NONACCOUNTING, HookSubTypes.SWAP) {
    POOL_MANAGER = IPoolManagerSuperform(poolManager_);
}

- Hook is initialized with the Uniswap V4 PoolManager address
- Inherits from BaseHook with NONACCOUNTING type (doesn't affect vault accounting)
- Uses SWAP subtype identifier

2. Hook Data Structure (297+ bytes)

When someone wants to execute a swap, they provide encoded data containing:

// Bytes 0-159:   PoolKey (pool identifier)
// Bytes 160-179: dstReceiver (who gets output tokens)
// Bytes 180-199: sqrtPriceLimitX96 (price protection)
// Bytes 200-231: originalAmountIn (user's intended input)
// Bytes 232-263: originalMinAmountOut (user's intended min output)
// Bytes 264-295: maxSlippageDeviationBps (ratio protection limit)
// Byte 296:      usePrevHookAmount (use previous hook's output?)
// Bytes 297+:    Additional hook data (optional)

3. Execution Flow - Step by Step

Step 3a: build() Function Called

The SuperExecutor calls build() to get execution steps:

function build(address prevHook, address account, bytes calldata hookData)
    returns (Execution[] memory executions)

This returns 3 executions in order:
1. preExecute
2. Main swap via PoolManager.unlock
3. postExecute

Step 3b: _buildHookExecutions() - Core Logic

This is where the magic happens:

function _buildHookExecutions(address prevHook, address account, bytes calldata data) 
    internal view returns (Execution[] memory executions)

Sub-step 1: Decode Hook Data
(
    PoolKey memory poolKey,
    address dstReceiver,
    uint160 sqrtPriceLimitX96,
    uint256 originalAmountIn,      // What user originally wanted
    uint256 originalMinAmountOut,  // What user originally expected
    uint256 maxSlippageDeviationBps,
    bool usePrevHookAmount,
    bytes memory additionalData
) = _decodeHookData(data);

Sub-step 2: Get Actual Amount (Dynamic Recalculation Trigger)
uint256 actualAmountIn = usePrevHookAmount ?
    ISuperHookResult(prevHook).getOutAmount(account) :  // Use previous hook's output
    originalAmountIn;                                   // Use original amount

Sub-step 3: Dynamic MinAmount Recalculation
This is your colleague's critical requirement:

uint256 dynamicMinAmountOut = DynamicMinAmountCalculator.calculateDynamicMinAmount(
    DynamicMinAmountCalculator.RecalculationParams({
        originalAmountIn: originalAmountIn,        // User's original: 1000 USDC
        originalMinAmountOut: originalMinAmountOut, // User's original: 0.33 WETH
        actualAmountIn: actualAmountIn,            // Actual after bridge: 1200 USDC (20% more)
        maxSlippageDeviationBps: maxSlippageDeviationBps // Max allowed: 100 bps (1%)
    })
);

What happens inside the calculator:
- Calculates ratio: 1200 / 1000 = 1.2 (20% increase)
- Calculates new min: 0.33 * 1.2 = 0.396 WETH
- Checks deviation: 20% > 1% → REVERTS with ExcessiveSlippageDeviation

If the change was only 1%: 1010 / 1000 = 1.01, new min = 0.33 * 1.01 = 0.3333 WETH ✅

Sub-step 4: Quote Validation
_validateQuoteDeviation(poolKey, actualAmountIn, dynamicMinAmountOut);

Uses UniswapV4QuoteOracle to get current market quote and ensures our calculated dynamicMinAmountOut isn't too far from reality.

Sub-step 5: Create Execution
bytes memory unlockData = abi.encode(
    poolKey, actualAmountIn, dynamicMinAmountOut,
    dstReceiver, sqrtPriceLimitX96, additionalData
);

executions[0] = Execution({
    target: address(POOL_MANAGER),
    value: 0,
    callData: abi.encodeWithSelector(IPoolManager.unlock.selector, unlockData)
});

4. Actual Execution Phase

Step 4a: preExecute() Called

function _preExecute(address prevHook, address account, bytes calldata data) internal override {
    asset = _getInputToken(data);   // Store input token (e.g., USDC)
    spToken = _getOutputToken(data); // Store output token (e.g., WETH)
    // Sets execution context for tracking
}

Step 4b: PoolManager.unlock() Called

The PoolManager immediately calls back to our unlockCallback():

function unlockCallback(bytes calldata data) external override returns (bytes memory) {
    // Only PoolManager can call this
    require(msg.sender == address(POOL_MANAGER), "UNAUTHORIZED");

    // Decode the unlock data
    (PoolKey memory poolKey, uint256 amountIn, uint256 minAmountOut,
    address dstReceiver, uint160 sqrtPriceLimitX96, bytes memory additionalData) =
        abi.decode(data, (...));

Step 4c: Token Settlement

// Take input tokens from user and settle with PoolManager
Currency inputCurrency = zeroForOne ? poolKey.currency0 : poolKey.currency1;
POOL_MANAGER.take(inputCurrency, address(this), amountIn);
POOL_MANAGER.settle(inputCurrency);

Step 4d: Execute Swap

IPoolManagerSuperform.SwapParams memory swapParams = IPoolManagerSuperform.SwapParams({
    zeroForOne: zeroForOne,
    amountSpecified: -int256(amountIn), // Negative = exact input
    sqrtPriceLimitX96: sqrtPriceLimitX96
});

BalanceDelta swapDelta = POOL_MANAGER.swap(poolKey, swapParams, additionalData);

Step 4e: Validate & Transfer Output

// Extract actual output amount
uint256 amountOut = uint256(int256(-swapDelta.amount1()));

// Critical validation - this is where dynamic recalculation pays off
if (amountOut < minAmountOut) {
    revert InsufficientOutputAmount(amountOut, minAmountOut);
}

// Transfer output tokens to receiver
Currency outputCurrency = zeroForOne ? poolKey.currency1 : poolKey.currency0;
POOL_MANAGER.take(outputCurrency, dstReceiver, amountOut);

Step 4f: postExecute() Called

function _postExecute(address prevHook, address account, bytes calldata data) internal override {
    // Calculate final output amount
    uint256 outputBalance = IERC20(spToken).balanceOf(account);
    _setOutAmount(outputBalance, account); // Store for next hook in chain
}

5. Why This Solves the 0x Problem

0x Protocol Issues:
- Pre-computed quotes with circular dependencies
- Complex transaction patching (800-1200 lines of code)
- Bridge fee changes break everything

V4 Hook Solution:
- Real-time calculation: No pre-computed quotes needed
- Dynamic adjustment: Automatically handles amount changes
- Ratio protection: Prevents manipulation while allowing legitimate changes
- Single integration: One PoolManager vs 29+ protocol patchers

6. Example Execution Scenario

Initial Setup:
- User wants to swap 1000 USDC → WETH
- Expects ≥0.33 WETH output (3000 USDC/WETH rate)
- Sets 1% max deviation tolerance

Bridge Reduces Amount:
- Across bridge takes 2% fee
- Actual amount becomes 980 USDC (2% less)

Dynamic Recalculation:
- Ratio: 980/1000 = 0.98 (-2% change)
- New min: 0.33 * 0.98 = 0.3234 WETH
- Deviation: 2% > 1% → Would revert

With Higher Tolerance:
- Set 5% max deviation tolerance
- Same calculation: 2% < 5% → Proceeds
- Swap executes with 0.3234 WETH minimum

This elegant solution maintains proportional slippage protection while handling real-world scenarios where amounts change due to bridge fees, previous hook outputs, or other legitimate reasons.