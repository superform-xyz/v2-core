# Uniswap V3 SwapRouter Documentation

## Summary

Uniswap V3 SwapRouter is a periphery contract that provides convenient interfaces for executing swaps through Uniswap V3 pools. Unlike V2's simple constant-product AMM, V3 introduces concentrated liquidity and multiple fee tiers, requiring more complex routing logic.

**Key Documentation Sources:**
- [Official Uniswap V3 Documentation](https://docs.uniswap.org/contracts/v3/reference/periphery/SwapRouter)
- [SwapRouter GitHub](https://github.com/Uniswap/v3-periphery/blob/main/contracts/SwapRouter.sol)
- [Error Codes Reference](https://docs.uniswap.org/contracts/v3/reference/error-codes)
- [Deployment Addresses](https://docs.uniswap.org/contracts/v3/reference/deployments/)

---

## 1. ISwapRouter Interface Specification

### Contract Location in Codebase
- **Primary**: `/Users/cosming/1.Coding/Superform/v2-core/lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol`
- **Usage Example**: `/Users/cosming/1.Coding/Superform/v2-core/lib/modulekit/src/integrations/uniswap/v3/Uniswap.sol`

### ExactInputSingleParams Struct

```solidity
struct ExactInputSingleParams {
    address tokenIn;           // Address of input token
    address tokenOut;          // Address of output token
    uint24 fee;               // Pool fee tier (500, 3000, 10000, or 100)
    address recipient;         // Address that receives output tokens
    uint256 deadline;          // Unix timestamp for transaction expiry
    uint256 amountIn;          // Exact amount of input tokens
    uint256 amountOutMinimum;  // Minimum output tokens (slippage protection)
    uint160 sqrtPriceLimitX96; // Price limit for partial fills (0 = no limit)
}
```

### exactInputSingle Function

```solidity
/// @notice Swaps `amountIn` of one token for as much as possible of another token
/// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams`
/// @return amountOut The amount of the received token
function exactInputSingle(ExactInputSingleParams calldata params)
    external
    payable
    returns (uint256 amountOut);
```

**Key Characteristics:**
- **Payable**: Function accepts ETH when swapping native tokens
- **Return Value**: Returns the actual output amount (can be used for verification)
- **Single-hop**: Executes swap through a single pool

### Other Swap Functions

```solidity
// Multi-hop exact input
struct ExactInputParams {
    bytes path;               // Encoded path: tokenA, fee, tokenB, fee, tokenC...
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
}

function exactInput(ExactInputParams calldata params)
    external payable returns (uint256 amountOut);

// Single-hop exact output
struct ExactOutputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountOut;        // Desired exact output amount
    uint256 amountInMaximum;  // Maximum input tokens allowed
    uint160 sqrtPriceLimitX96;
}

function exactOutputSingle(ExactOutputSingleParams calldata params)
    external payable returns (uint256 amountIn);

// Multi-hop exact output
struct ExactOutputParams {
    bytes path;               // Reversed path encoding
    address recipient;
    uint256 deadline;
    uint256 amountOut;
    uint256 amountInMaximum;
}

function exactOutput(ExactOutputParams calldata params)
    external payable returns (uint256 amountIn);
```

---

## 2. Native ETH Handling

### WETH9 Wrapper Pattern

Uniswap V3 pools only work with ERC-20 tokens. For native ETH swaps, the SwapRouter:
1. Accepts ETH via `msg.value`
2. Wraps ETH to WETH internally before swap
3. Optionally unwraps WETH to ETH for recipient

### Key Helper Functions (PeripheryPayments)

```solidity
// Unwrap WETH9 and send ETH to recipient
function unwrapWETH9(uint256 amountMinimum, address recipient) external payable;

// Refund any remaining ETH to msg.sender
function refundETH() external payable;

// Sweep any token balance to recipient
function sweepToken(address token, uint256 amountMinimum, address recipient) external payable;
```

### Multicall Pattern for Native ETH Swaps

When swapping ETH -> Token:
```solidity
// Single call with msg.value
swapRouter.exactInputSingle{value: amountIn}(params);
```

When swapping Token -> ETH (unwrap WETH):
```solidity
// Use multicall to combine swap + unwrap
bytes[] memory calls = new bytes[](2);
calls[0] = abi.encodeCall(ISwapRouter.exactInputSingle, (params)); // recipient = router
calls[1] = abi.encodeCall(IPeripheryPayments.unwrapWETH9, (minAmount, actualRecipient));
swapRouter.multicall(calls);
```

### Implementation Considerations

For a Superform hook:
- **ERC-20 to ERC-20**: Standard `exactInputSingle` call with `value: 0`
- **Native ETH Input**: Pass `value: amountIn` and use WETH address as tokenIn
- **Native ETH Output**:
  - Set `recipient` to the hook contract or router
  - Call `unwrapWETH9` after swap to send ETH to actual recipient
  - Or use multicall to batch these operations

---

## 3. Fee Tier Specifications

### Standard Fee Tiers

| Fee Tier | Basis Points | Percentage | Tick Spacing | Typical Use Case |
|----------|-------------|------------|--------------|------------------|
| 100      | 1 bps       | 0.01%      | 1            | Stable pairs (USDC/USDT) |
| 500      | 5 bps       | 0.05%      | 10           | Stable pairs |
| 3000     | 30 bps      | 0.30%      | 60           | Most pairs (default) |
| 10000    | 100 bps     | 1.00%      | 200          | Exotic pairs |

**Note**: The 100 bps (0.01%) tier was added via [governance proposal](https://vote.uniswapfoundation.org/proposals/9) in December 2021.

### Fee Encoding

```solidity
// Fee is stored as uint24
uint24 constant FEE_LOWEST  = 100;   // 0.01%
uint24 constant FEE_LOW     = 500;   // 0.05%
uint24 constant FEE_MEDIUM  = 3000;  // 0.30%
uint24 constant FEE_HIGH    = 10000; // 1.00%

// Default in modulekit
uint24 constant SWAPROUTER_DEFAULTFEE = 3000;
```

### Tick Spacing Relationship

- Lower fees allow tighter tick spacing (more precise price ranges)
- Higher fees require wider tick spacing
- Tick spacing is automatically determined by fee tier in the factory
- Formula: Each tick represents a 0.01% price change

### Pool Selection Strategy

1. **Stable Pairs** (USDC/USDT, DAI/USDC): Use 100 or 500 bps
2. **Major Pairs** (ETH/USDC, WBTC/ETH): Use 500 or 3000 bps
3. **Long-tail Assets**: Use 3000 or 10000 bps
4. **Check Liquidity**: Always verify pool has sufficient liquidity before routing

---

## 4. Return Value Handling

### exactInputSingle Returns

```solidity
// Returns actual output amount
uint256 amountOut = swapRouter.exactInputSingle(params);
```

**Important Considerations:**

1. **Actual vs Expected**: The return value is the actual amount received, which may differ from quotes due to:
   - Price movement between quote and execution
   - MEV/sandwich attacks
   - Pool liquidity changes

2. **Verification Pattern**:
```solidity
uint256 amountOut = swapRouter.exactInputSingle(params);
require(amountOut >= params.amountOutMinimum, "Slippage exceeded");
// Note: This check is redundant as router already enforces it
```

3. **For Hook Implementation**:
```solidity
// Pre-execution: Store initial balance
uint256 initialBalance = IERC20(tokenOut).balanceOf(recipient);

// Execute swap
uint256 reportedAmountOut = swapRouter.exactInputSingle(params);

// Post-execution: Calculate true delta
uint256 finalBalance = IERC20(tokenOut).balanceOf(recipient);
uint256 actualReceived = finalBalance - initialBalance;

// Set output for next hook
_setOutAmount(actualReceived, account);
```

### exactOutputSingle Returns

```solidity
// Returns actual input amount spent
uint256 amountIn = swapRouter.exactOutputSingle(params);

// Refund excess if amountIn < amountInMaximum
if (amountIn < amountInMaximum) {
    // Reset approval
    IERC20(tokenIn).approve(address(swapRouter), 0);
    // Transfer back unused tokens
    IERC20(tokenIn).transfer(msg.sender, amountInMaximum - amountIn);
}
```

---

## 5. Error Conditions and Reverts

### SwapRouter Specific Errors

| Error Code | Source | Meaning | Common Cause |
|------------|--------|---------|--------------|
| `Transaction too old` | PeripheryValidation | `block.timestamp > deadline` | Transaction pending too long |
| `STF` | TransferHelper | Safe Transfer From failed | Insufficient approval or balance |
| `AS` | UniswapV3Pool | `amountSpecified` is zero | Zero input amount |
| `IIA` | UniswapV3Pool | Insufficient input amount | Fee-on-transfer tokens, insufficient balance |
| `SPL` | UniswapV3Pool | sqrt price limit violation | Price moved beyond limit |
| `LOK` | UniswapV3Pool | Pool is locked | Reentrancy attempt |
| `I` | UniswapV3Pool | Pool not initialized | Pool doesn't exist or not initialized |

### Pool-Level Errors

| Error Code | Meaning |
|------------|---------|
| `TLU` | Lower tick must be below upper tick |
| `TLM` | Lower tick below minimum |
| `TUM` | Upper tick above maximum |
| `AI` | Pool already initialized |
| `M0/M1` | Mint validation failed |
| `L` | Liquidity must be > 0 for flash |
| `F0/F1` | Flash fee validation failed |
| `OLD` | Oracle observation target invalid |
| `NP` | Non-zero liquidity required for burns |
| `LO` | Maximum liquidity exceeded |

### Common Failure Scenarios

1. **STF (Safe Transfer From)**:
   - Caller hasn't approved router for `amountIn`
   - Caller's balance < `amountIn`
   - Token has transfer restrictions

2. **IIA (Insufficient Input Amount)**:
   - Fee-on-transfer tokens (NOT SUPPORTED by V3)
   - Deflationary/rebase tokens
   - Token with custom transfer logic

3. **Transaction too old**:
   - Network congestion caused delay
   - Gas price too low
   - Default deadline: `block.timestamp` (no safety margin)

4. **Slippage (amountOut < amountOutMinimum)**:
   - Price moved unfavorably
   - Front-run/sandwich attack
   - Stale quote data

### Important Note on Fee-on-Transfer Tokens

**Uniswap V3 does NOT support fee-on-transfer tokens.** Unlike V2 which had `swapExactTokensForETHSupportingFeeOnTransferTokens`, V3 has no equivalent. Attempting to swap such tokens will result in `IIA` error.

---

## 6. Deployment Addresses Across Chains

### SwapRouter (Original V3 Router)
Address: `0xE592427A0AEce92De3Edee1F18E0157C05861564`

| Chain | Deployed | Notes |
|-------|----------|-------|
| Ethereum Mainnet | Yes | Canonical address |
| Arbitrum One | Yes | Same address |
| Optimism | Yes | Same address |
| Polygon | Yes | Same address |
| Base | **Different** | Check official docs |
| BSC | **Different** | Check official docs |
| Avalanche | **Different** | Check official docs |

### SwapRouter02 (Combined V2/V3 Router)
Address varies by chain:

| Chain | SwapRouter02 Address |
|-------|---------------------|
| Ethereum Mainnet | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Arbitrum One | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Polygon | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Optimism | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Base | `0x2626664c2603336E57B271c5C0b26F421741e481` |

### UniversalRouter (Current Preferred Router)
**Note**: Uniswap now recommends UniversalRouter for new integrations.

| Chain | UniversalRouter Address |
|-------|------------------------|
| Ethereum Mainnet | `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD` |
| Arbitrum One | `0x5Dc88340E1c5c6366864Ee415d6034cadd1A9897` |
| Polygon | `0x5302086A3a25d473aAbBd0356eFf8Dd811a4d89B` |
| Base | `0x198EF79F1F515F02dFE9e3115eD9fC07183f02fC` |

### Factory Address (Same on All Chains)
`0x1F98431c8aD98523631AE4a59f267346ea31F984`

### Quoter Address (Same on Most Chains)
`0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6`

### Critical Implementation Note

> **WARNING**: "Integrators should no longer assume that they are deployed to the same addresses across chains and be extremely careful to confirm mappings."

For Superform hook implementation:
- Store router address as immutable constructor parameter
- Deploy with chain-specific addresses
- Verify addresses against official docs before deployment

---

## 7. sqrtPriceLimitX96 Parameter

### Purpose
The `sqrtPriceLimitX96` parameter provides a price limit for partial fills:
- Acts as a boundary price for the swap
- If price hits this limit before full amount is swapped, swap is partial
- Setting to `0` means no limit (swap entire amount or revert)

### Usage Patterns

```solidity
// No price limit (most common for user swaps)
uint160 sqrtPriceLimitX96 = 0;

// With price limit (for advanced use cases)
// If zeroForOne (selling token0): limit must be < current price
// If !zeroForOne (selling token1): limit must be > current price

// For zeroForOne swaps, use MIN_SQRT_PRICE + 1 as effective "no limit"
uint160 MIN_SQRT_PRICE = 4295128739;
sqrtPriceLimitX96 = MIN_SQRT_PRICE + 1;

// For !zeroForOne swaps, use MAX_SQRT_PRICE - 1
uint160 MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;
sqrtPriceLimitX96 = MAX_SQRT_PRICE - 1;
```

### Modulekit Default
From `/lib/modulekit/src/integrations/uniswap/v3/Uniswap.sol`:
```solidity
// Sets sqrtPriceLimitX96: 0 to ensure full swap
ISwapRouter.ExactInputSingleParams({
    // ...
    sqrtPriceLimitX96: sqrtPriceLimitX96  // Passed as parameter
});
```

---

## 8. Best Practices for Hook Implementation

### 1. Approval Pattern
```solidity
// Use safeApprove with reset pattern (from modulekit)
function safeApprove(IERC20 token, address spender, uint256 amount) {
    token.approve(spender, 0);  // Reset first for tokens that require it
    token.approve(spender, amount);
}
```

### 2. Deadline Handling
```solidity
// Add buffer to deadline for cross-chain scenarios
uint256 deadline = block.timestamp + 300; // 5 minutes

// Or use passed deadline from hook data for user control
uint256 deadline = params.deadline;
```

### 3. Slippage Protection
```solidity
// Calculate minAmountOut dynamically for usePrevHookAmount
if (usePrevHookAmount) {
    uint256 actualAmountIn = ISuperHookResult(prevHook).getOutAmount(account);
    // Scale minAmountOut proportionally
    minAmountOut = (originalMinAmountOut * actualAmountIn) / originalAmountIn;
}
```

### 4. Balance Verification
```solidity
// Always verify actual balance change, not just return value
function _postExecute(address, address account, bytes calldata data) internal override {
    uint256 newBalance = IERC20(outputToken).balanceOf(dstReceiver);
    uint256 actualReceived = newBalance - initialBalance;
    _setOutAmount(actualReceived, account);
}
```

### 5. Error Handling
```solidity
// Define custom errors for clarity
error SWAP_FAILED();
error INSUFFICIENT_OUTPUT();
error INVALID_TOKEN_PAIR();
error DEADLINE_EXPIRED();
```

---

## 9. Interface Differences: SwapRouter vs SwapRouter02

### SwapRouter (Original)
- Single-purpose V3 swaps
- Interface: `ISwapRouter`
- Simpler, fewer functions

### SwapRouter02 (Combined)
- Supports both V2 and V3 swaps
- Additional functions for V2 compatibility
- Slightly different parameter handling in some cases

For Superform's purposes, using the original `ISwapRouter` interface with `SwapRouter` (`0xE592427A0AEce92De3Edee1F18E0157C05861564`) is sufficient and simpler.

---

## 10. References

### Official Documentation
- [SwapRouter Reference](https://docs.uniswap.org/contracts/v3/reference/periphery/SwapRouter)
- [ISwapRouter Interface](https://docs.uniswap.org/contracts/v3/reference/periphery/interfaces/ISwapRouter)
- [Error Codes](https://docs.uniswap.org/contracts/v3/reference/error-codes)
- [Deployment Addresses](https://docs.uniswap.org/contracts/v3/reference/deployments/)
- [Single Swaps Guide](https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps)

### GitHub Sources
- [v3-periphery SwapRouter.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/SwapRouter.sol)
- [v3-periphery deploys.md](https://github.com/Uniswap/v3-periphery/blob/main/deploys.md)
- [PeripheryValidation.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/base/PeripheryValidation.sol)
- [TransferHelper.sol](https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/TransferHelper.sol)

### Codebase Files
- Interface: `/Users/cosming/1.Coding/Superform/v2-core/lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol`
- Integration: `/Users/cosming/1.Coding/Superform/v2-core/lib/modulekit/src/integrations/uniswap/v3/Uniswap.sol`
- Addresses: `/Users/cosming/1.Coding/Superform/v2-core/lib/modulekit/src/integrations/uniswap/helpers/MainnetAddresses.sol`
- Similar Hook Example: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol`
- 1inch Hook Example: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/1inch/Swap1InchHook.sol`
- Odos Hook Example: `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/odos/SwapOdosV2Hook.sol`
