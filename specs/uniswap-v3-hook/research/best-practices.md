# Uniswap V3 SwapRouter Integration Best Practices

This document provides comprehensive best practices for integrating with Uniswap V3's SwapRouter in Solidity smart contracts, specifically for building a Superform v2-core hook.

## Table of Contents

1. [ExactInputSingle Function Overview](#1-exactinputsingle-function-overview)
2. [Token Approval Patterns](#2-token-approval-patterns)
3. [Native ETH Handling](#3-native-eth-handling)
4. [Deadline Parameter Best Practices](#4-deadline-parameter-best-practices)
5. [sqrtPriceLimitX96 Usage and Edge Cases](#5-sqrtpricelimitx96-usage-and-edge-cases)
6. [Slippage Protection (amountOutMinimum)](#6-slippage-protection-amountoutminimum)
7. [Common Security Pitfalls](#7-common-security-pitfalls)
8. [Gas Optimization Techniques](#8-gas-optimization-techniques)
9. [Project X (Hyperliquid) Integration Notes](#9-project-x-hyperliquid-integration-notes)
10. [Implementation Checklist](#10-implementation-checklist)

---

## 1. ExactInputSingle Function Overview

### Function Signature

```solidity
function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}
```

### Router Addresses

| Network | SwapRouter | SwapRouter02 |
|---------|-----------|--------------|
| Ethereum | `0xE592427A0AEce92De3Edee1F18E0157C05861564` | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Arbitrum | `0xE592427A0AEce92De3Edee1F18E0157C05861564` | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Base | `0xE592427A0AEce92De3Edee1F18E0157C05861564` | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |

**Recommendation**: Use SwapRouter02 for newer integrations as it provides additional safety features and multicall support.

**Sources**:
- [Uniswap Single Swaps Guide](https://docs.uniswap.org/contracts/v3/guides/swaps/single-swaps)
- [SwapRouter Reference](https://docs.uniswap.org/contracts/v3/reference/periphery/SwapRouter)

---

## 2. Token Approval Patterns

### The Approval Race Condition Problem

The ERC-20 `approve()` function has a known race condition vulnerability where:
1. User approves spender for amount X
2. User changes approval to amount Y
3. Attacker front-runs the second approval and uses the original X allowance
4. After the new approval is processed, attacker can use Y more tokens
5. Total unauthorized transfer: X + Y tokens

### Recommended Patterns

#### Pattern 1: Reset-Then-Set (Recommended for Superform hooks)

Based on the existing `ApproveAndSwapOdosV2Hook.sol` pattern:

```solidity
// Step 1: Reset approval to 0
executions[0] = Execution({
    target: inputToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (router, 0))
});

// Step 2: Set exact approval amount
executions[1] = Execution({
    target: inputToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (router, amountIn))
});

// Step 3: Execute swap
executions[2] = Execution({
    target: router,
    value: 0,
    callData: swapCalldata
});

// Step 4: Reset approval to 0 (clean up)
executions[3] = Execution({
    target: inputToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (router, 0))
});
```

#### Pattern 2: OpenZeppelin SafeERC20.forceApprove (Modern approach)

```solidity
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

using SafeERC20 for IERC20;

// forceApprove automatically handles the reset-then-set pattern
IERC20(token).forceApprove(spender, amount);
```

**Note**: `safeApprove` is deprecated. Use `forceApprove` for direct approval setting, or `safeIncreaseAllowance`/`safeDecreaseAllowance` for incremental changes.

#### Pattern 3: TransferHelper (Uniswap's approach)

```solidity
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
TransferHelper.safeApprove(tokenIn, address(swapRouter), amountIn);
```

### Why Reset to Zero After Swap?

1. **Security**: Prevents leftover allowances from being exploited
2. **Gas Refund**: Clearing storage slots provides a gas refund
3. **Best Practice**: Minimizes attack surface

**Sources**:
- [OpenZeppelin SafeERC20](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol)
- [Approval Vulnerabilities Guide](https://scsfg.io/hackers/approvals/)
- [ERC20 Approve Pattern Guide](https://speedrunethereum.com/guides/erc20-approve-pattern)

---

## 3. Native ETH Handling

### Key Concepts

1. **Uniswap V3 does NOT support native ETH directly** - all ETH must be wrapped to WETH
2. **The SwapRouter handles WETH wrapping automatically** when you send ETH with the call
3. **Leftover ETH is NOT automatically refunded** - you must call `refundETH()`

### When to Use `msg.value` vs WETH

| Scenario | Approach |
|----------|----------|
| Swapping ETH for tokens | Set `tokenIn = WETH`, send ETH via `value` |
| Swapping tokens for ETH | Set `tokenOut = WETH`, call `unwrapWETH9` after |
| Swapping ERC-20 to ERC-20 | No `value` needed, standard approval flow |

### Implementation Pattern for ETH Input

```solidity
// For ETH -> Token swaps
ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
    tokenIn: WETH9,           // Use WETH address, not address(0)
    tokenOut: outputToken,
    fee: poolFee,
    recipient: recipient,
    deadline: deadline,
    amountIn: amountIn,
    amountOutMinimum: minOut,
    sqrtPriceLimitX96: 0
});

// Execute with ETH value
uint256 amountOut = swapRouter.exactInputSingle{value: amountIn}(params);

// CRITICAL: Refund any leftover ETH
swapRouter.refundETH();
```

### Contract Requirements for ETH Handling

```solidity
// Required to receive ETH refunds
receive() external payable {}

// Or a fallback function
fallback() external payable {}
```

### Exact Output Swaps - Handling Refunds

For `exactOutputSingle` swaps, leftover input tokens must be handled:

```solidity
uint256 amountIn = swapRouter.exactOutputSingle{value: msg.value}(params);

// Refund unused ETH
if (msg.value > amountIn) {
    swapRouter.refundETH();
    // Alternatively, transfer directly:
    // (bool success, ) = msg.sender.call{value: msg.value - amountIn}("");
}

// Reset approval for unused tokens
TransferHelper.safeApprove(tokenIn, address(swapRouter), 0);
```

### Superform Pattern (from SwapUniswapV4Hook.sol)

```solidity
// Handle native ETH settlement
if (currency.isAddressZero()) {
    // Native token: settle with exact amount needed
    if (address(this).balance < amountToSettle) {
        revert INVALID_PREVIOUS_NATIVE_TRANSFER_HOOK_USAGE();
    }
    POOL_MANAGER.settle{value: amountToSettle}();
} else {
    // ERC-20 token flow
    IERC20(inputToken).transfer(address(POOL_MANAGER), amountToSettle);
    POOL_MANAGER.settle();
}

// Refund remaining ETH
if (poolKey.currency0.isAddressZero()) {
    uint256 balance = address(this).balance;
    if (balance > 0) {
        (bool success,) = dstReceiver.call{value: balance}("");
        if (!success) revert INVALID_REMAINING_NATIVE_AMOUNT();
    }
}
```

**Sources**:
- [Using Uniswap V3 in Contracts](https://soliditydeveloper.com/uniswap3)
- [Why ETH Swaps Involve WETH](https://support.uniswap.org/hc/en-us/articles/16015852009997-Why-do-ETH-swaps-involve-converting-to-WETH)

---

## 4. Deadline Parameter Best Practices

### The Problem with `block.timestamp`

Using `block.timestamp` as the deadline provides **NO protection**:

```solidity
// BAD - No protection!
deadline: block.timestamp
```

This is equivalent to saying "I'm comfortable with whatever block this transaction appears in" - it always passes because the check compares `block.timestamp` against itself.

### Security Implications

1. **Pending Transactions**: Transactions with low gas fees can stay in the mempool for hours, days, or weeks
2. **MEV Exploitation**: Miners/validators can hold transactions and execute them when profitable
3. **Price Volatility**: Prices can change dramatically while transactions are pending
4. **Sandwich Attacks**: Attackers can sandwich stale transactions for maximum extraction

### Attack Scenario

1. Alice submits a swap with `block.timestamp` deadline
2. Transaction stays pending due to low gas fee
3. ETH price drops 50% while pending
4. MEV bot detects the pending transaction
5. Bot sandwiches Alice's transaction, profiting from the outdated slippage tolerance
6. Alice receives far less than expected

### Recommended Approach

**Always use user-specified deadlines passed off-chain:**

```solidity
// GOOD - User-specified deadline
function swap(
    uint256 amountIn,
    uint256 minAmountOut,
    uint256 deadline  // Passed by user/frontend
) external {
    require(deadline > block.timestamp, "Deadline expired");

    ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
        // ... other params
        deadline: deadline,
        // ...
    });

    swapRouter.exactInputSingle(params);
}
```

### Typical Deadline Values

| Context | Typical Deadline |
|---------|------------------|
| User-initiated swap | 10-30 minutes from submission |
| Automated/keeper swap | 2-5 minutes |
| Time-sensitive arbitrage | 1-2 blocks |
| Cross-chain operations | Longer, based on bridge time |

### Superform Hook Approach

For Superform hooks where the deadline is part of the signed intent:

```solidity
// Deadline should be validated at intent signing time
// and included in the hook data
uint256 deadline = decodeDeadline(data);
require(deadline >= block.timestamp, "EXPIRED_DEADLINE");
```

**Sources**:
- [Dangerous use of deadline parameter](https://github.com/code-423n4/2024-03-revert-lend-findings/issues/147)
- [Using block.timestamp as deadline invites MEV](https://github.com/code-423n4/2022-01-dev-test-repo-findings/issues/193)
- [Deadline check not effective](https://github.com/sherlock-audit/2023-04-blueberry-judging/issues/145)

---

## 5. sqrtPriceLimitX96 Usage and Edge Cases

### What is sqrtPriceLimitX96?

This parameter sets the minimum or maximum price the user is willing to accept for the swap. It protects against extreme price movements within a single swap.

### Setting to Zero (0)

```solidity
sqrtPriceLimitX96: 0
```

**Behavior**: Setting to 0 means "no price limit" - the swap will execute regardless of how far the price moves. This is acceptable when:
- You have proper `amountOutMinimum` protection
- You're swapping small amounts relative to pool liquidity
- You understand the full amount will be swapped

**Warning**: From Uniswap docs: "We set sqrtPriceLimitX96 to 0 to ensure we swap our exact input amount."

### Non-Zero Values

```solidity
// For zeroForOne (selling token0 for token1):
sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1  // Price can drop to minimum

// For oneForZero (selling token1 for token0):
sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1  // Price can rise to maximum
```

### Critical Edge Case: Partial Swaps

**WARNING**: A non-zero `sqrtPriceLimitX96` can cause partial execution!

```solidity
// From Uniswap docs:
// "Passing in a non-zero sqrtPriceLimitX96 can mean that less tokens
// than the amount specified by amountIn are swapped."
```

If you use a non-zero price limit and DON'T handle partial execution:
1. Some input tokens won't be swapped
2. These tokens will be stuck in the router or your contract
3. You must refund unswapped tokens to the user

### Superform Implementation (from SwapUniswapV4Hook.sol)

```solidity
// Normalize price limit: 0 means no limit -> set to extreme bound
uint160 effectivePriceLimitX96 = sqrtPriceLimitX96 == 0
    ? (zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1)
    : sqrtPriceLimitX96;
```

### Recommendations

| Scenario | sqrtPriceLimitX96 Value |
|----------|------------------------|
| Simple swaps with slippage protection | `0` (rely on amountOutMinimum) |
| Price-sensitive large swaps | Calculate based on acceptable price impact |
| Arbitrage / MEV protection | Set tight limits |

**Sources**:
- [Uniswap V3 Slippage Protection](https://uniswapv3book.com/milestone_3/slippage-protection.html)
- [sqrtPriceLimitX96 Impact Issue](https://github.com/Uniswap/docs/issues/671)
- [SlowMist Uniswap V3 Analysis](https://slowmist.medium.com/slowmist-analysis-and-audit-key-points-of-the-uniswap-v3-protocol-442cdbc29baa)

---

## 6. Slippage Protection (amountOutMinimum)

### The Importance of amountOutMinimum

This is your **primary defense** against:
- Sandwich attacks
- Front-running
- Price manipulation
- High slippage in low-liquidity pools

### Never Set to Zero in Production

```solidity
// BAD - No slippage protection!
amountOutMinimum: 0
```

From Uniswap docs: "Naively set amountOutMinimum to 0. **In production, use an oracle or other data source to choose a safer value.**"

### How to Calculate amountOutMinimum

#### Option 1: Off-chain Quote (Recommended)

```typescript
// Frontend/Backend calculation
const quote = await quoter.quoteExactInputSingle(params);
const slippageTolerance = 0.5; // 0.5%
const minAmountOut = quote * (1 - slippageTolerance / 100);
```

#### Option 2: Oracle-Based

```solidity
// On-chain with Chainlink oracle
uint256 expectedOutput = (amountIn * getOraclePrice()) / 1e18;
uint256 minAmountOut = expectedOutput * (10000 - slippageBps) / 10000;
```

#### Option 3: Dynamic Recalculation (Superform Pattern)

From `SwapUniswapV4Hook.sol`:

```solidity
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

    // Calculate new minAmountOut proportionally
    newMinAmountOut = Math.mulDiv(
        params.originalMinAmountOut,
        params.actualAmountIn,
        params.originalAmountIn
    );

    if (newMinAmountOut == 0) revert INVALID_OUTPUT_DELTA();

    // Validate ratio deviation is within bounds
    uint256 amountRatio = (params.actualAmountIn * 1e18) / params.originalAmountIn;
    uint256 ratioDeviationBps = _calculateRatioDeviationBps(amountRatio);

    if (ratioDeviationBps > params.maxSlippageDeviationBps) {
        revert EXCESSIVE_SLIPPAGE_DEVIATION(ratioDeviationBps, params.maxSlippageDeviationBps);
    }
}
```

### Validation Pattern (from Swap1InchHook.sol)

```solidity
// Always validate minReturn is non-zero
if (minReturn == 0) {
    revert INVALID_OUTPUT_AMOUNT();
}

if (amount == 0) {
    revert INVALID_INPUT_AMOUNT();
}
```

**Sources**:
- [Lack of slippage protection findings](https://github.com/code-423n4/2023-05-maia-findings/issues/577)
- [Sherlock slippage audit](https://github.com/sherlock-audit/2023-06-arrakis-judging/issues/84)

---

## 7. Common Security Pitfalls

### 7.1 Input Validation Failures (34.6% of exploits)

**Always validate:**

```solidity
// Token addresses
if (tokenIn == address(0) && !isNativeETHSwap) revert INVALID_TOKEN();
if (tokenOut == address(0)) revert INVALID_TOKEN();
if (tokenIn == tokenOut) revert SAME_TOKEN();

// Amounts
if (amountIn == 0) revert ZERO_AMOUNT();
if (amountOutMinimum == 0) revert NO_SLIPPAGE_PROTECTION();

// Addresses
if (recipient == address(0)) revert INVALID_RECIPIENT();
if (recipient != expectedRecipient) revert INVALID_RECEIVER();
```

### 7.2 Access Control (27% of audited contracts)

```solidity
// Ensure only authorized callers
modifier onlyExecutor() {
    require(msg.sender == executor, "Unauthorized");
    _;
}

// Validate callback caller
if (msg.sender != address(POOL_MANAGER)) {
    revert UNAUTHORIZED_CALLBACK();
}
```

### 7.3 Reentrancy (12.7% of exploits)

```solidity
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SwapHook is ReentrancyGuard {
    function execute() external nonReentrant {
        // Swap logic
    }
}
```

Or use Checks-Effects-Interactions pattern:

```solidity
// 1. CHECKS
require(amount > 0, "Zero amount");

// 2. EFFECTS (update state)
balances[msg.sender] -= amount;

// 3. INTERACTIONS (external calls)
token.transfer(recipient, amount);
```

### 7.4 Oracle Manipulation

```solidity
// Use TWAP instead of spot price
uint256 twapPrice = oracle.consult(token, period);

// Validate price bounds
require(twapPrice >= minPrice && twapPrice <= maxPrice, "Price out of bounds");
```

### 7.5 Flash Loan Attacks (83.3% of DeFi exploits)

```solidity
// Add flash loan protection where needed
require(block.number > lastInteractionBlock[msg.sender], "Same block");
lastInteractionBlock[msg.sender] = block.number;
```

### 7.6 Decimal Handling

```solidity
// Always normalize decimals
uint8 decimalsIn = IERC20Metadata(tokenIn).decimals();
uint8 decimalsOut = IERC20Metadata(tokenOut).decimals();

// Convert to common base (e.g., 18 decimals)
uint256 normalizedIn = amountIn * (10 ** (18 - decimalsIn));
```

### 7.7 Signature Replay

From Superform's SECURITY.md - ensure:
- Include chainId in signatures
- Use unique nonces
- Include timestamp/deadline

**Sources**:
- [Common Smart Contract Vulnerabilities 2025](https://blog.bitium.agency/common-smart-contract-vulnerabilities-in-2025-reviewing-recent-vulnerabilities-how-to-stay-safe-4eaec1526c9d)
- [Top 10 Smart Contract Vulnerabilities](https://hacken.io/discover/smart-contract-vulnerabilities/)
- [Halborn Top 100 DeFi Hacks Report](https://www.halborn.com/reports/top-100-defi-hacks-2025)

---

## 8. Gas Optimization Techniques

### 8.1 Batch Operations with Multicall

```solidity
// Instead of multiple transactions, batch calls
bytes[] memory calls = new bytes[](3);
calls[0] = abi.encodeCall(router.approve, (spender, amount));
calls[1] = abi.encodeCall(router.exactInputSingle, (params));
calls[2] = abi.encodeCall(router.refundETH, ());

router.multicall(calls);
```

**Savings**: 30-50% gas reduction for multi-step operations.

### 8.2 Use Calldata Instead of Memory

```solidity
// GOOD - Uses calldata (cheaper)
function swap(bytes calldata data) external {
    // Process data
}

// BAD - Uses memory (more expensive)
function swap(bytes memory data) external {
    // Process data
}
```

### 8.3 Minimize Storage Operations

```solidity
// BAD - Multiple storage writes
function bad() external {
    storageVar1 = value1;  // SSTORE
    storageVar2 = value2;  // SSTORE
    storageVar3 = value3;  // SSTORE
}

// GOOD - Batch storage writes or use transient storage
function good() external {
    uint256 temp1 = value1;  // Memory
    uint256 temp2 = value2;  // Memory
    // ... processing ...
    storageVar = packValues(temp1, temp2);  // Single SSTORE
}
```

### 8.4 Use Transient Storage (EIP-1153)

From `SwapUniswapV4Hook.sol`:

```solidity
// Store data in transient storage (cheaper than regular storage)
bytes32 private constant PENDING_UNLOCK_DATA_SLOT = keccak256("SwapUniswapV4Hook.pendingUnlockData");

function _storeUnlockData(bytes memory data) private {
    bytes32 storageKey = PENDING_UNLOCK_DATA_SLOT;
    uint256 len = data.length;

    assembly {
        tstore(storageKey, len)  // Transient storage
    }
    // Store chunks...
}
```

### 8.5 Avoid Unnecessary Checks

```solidity
// Rely on router's built-in checks where appropriate
// Don't duplicate validation that Uniswap already does
```

### 8.6 Use Efficient Data Encoding

```solidity
// Pack data efficiently using BytesLib
address token = BytesLib.toAddress(data, 0);
uint256 amount = BytesLib.toUint256(data, 20);
bool flag = _decodeBool(data, 52);
```

### 8.7 Profile-Based Optimization

From Uniswap's approach:
- Use snapshot testing to measure gas costs
- Focus on frequently-called functions
- A 50 gas saving on a 1000 gas function = 5% improvement

**Sources**:
- [Uniswap Gas Optimization Introduction](https://docs.uniswap.org/blog/intro-to-gas-optimization?s=09)
- [RareSkills Gas Optimization Guide](https://rareskills.io/post/gas-optimization)
- [Multicall Reference](https://docs.uniswap.org/contracts/v3/reference/periphery/base/Multicall)

---

## 9. Project X (Hyperliquid) Integration Notes

### Overview

Project X is a **Uniswap V3 fork** running on Hyperliquid (HyperEVM). Key characteristics:

- **Minimal Logic Changes**: "We have not modified any logic; we only enabled the fee switch for LPs"
- **Fee Distribution**: 86% of trading fees go to LPs (different from standard Uniswap)
- **Security Audited**: PeckShield, 0xQuit, and AI security scan

### Integration Considerations

1. **Same Interface**: The SwapRouter interface should be identical to Uniswap V3
2. **Same Parameters**: `ExactInputSingleParams` structure is unchanged
3. **Different Addresses**: You'll need Project X's router address on Hyperliquid
4. **Fee Tiers**: May have different fee tier configurations

### Compatibility Checklist

| Feature | Compatibility |
|---------|--------------|
| exactInputSingle | Expected compatible |
| exactOutputSingle | Expected compatible |
| multicall | Verify availability |
| Native ETH handling | Check WETH equivalent on Hyperliquid |
| Fee tiers | Verify supported tiers |

### Recommended Approach

```solidity
// Use interface abstraction for multi-chain support
interface ISwapRouter {
    function exactInputSingle(ExactInputSingleParams calldata params)
        external payable returns (uint256 amountOut);
}

// Configure router per chain
address public immutable SWAP_ROUTER;

constructor(address _router) {
    SWAP_ROUTER = _router;  // Chain-specific router
}
```

**Sources**:
- [Project X on Hyperliquid](https://decrypt.co/329952/how-project-x-aims-give-defi-dopamine-shot-hyperliquid)
- [PRJX Evolution](https://meme-insider.com/en/article/prjx-hyperliquid-evolution-multichain-aggregator-phase-3/)

---

## 10. Implementation Checklist

### Pre-Implementation

- [ ] Identify correct SwapRouter address for target chain(s)
- [ ] Confirm WETH address for native ETH swaps
- [ ] Define fee tier(s) to support
- [ ] Plan slippage calculation strategy
- [ ] Design deadline handling approach

### Contract Implementation

- [ ] Import correct interfaces (ISwapRouter, IERC20)
- [ ] Implement `receive()` for ETH refunds
- [ ] Use reset-then-set approval pattern
- [ ] Validate all input parameters
- [ ] Handle both ERC-20 and native ETH flows
- [ ] Implement proper deadline (NOT `block.timestamp`)
- [ ] Set appropriate `amountOutMinimum` (NEVER 0 in production)
- [ ] Handle `sqrtPriceLimitX96` correctly (0 or calculated)
- [ ] Clean up approvals after swap
- [ ] Refund leftover ETH with `refundETH()`

### Security

- [ ] Add reentrancy protection
- [ ] Validate recipient addresses
- [ ] Implement access controls
- [ ] Add emergency pause functionality
- [ ] Test sandwich attack resistance
- [ ] Audit token decimal handling

### Gas Optimization

- [ ] Use calldata for function parameters
- [ ] Minimize storage operations
- [ ] Consider multicall for batched operations
- [ ] Use transient storage where applicable
- [ ] Profile gas usage with tests

### Testing

- [ ] Unit tests for all parameters
- [ ] Integration tests with forked mainnet
- [ ] Fuzz testing for edge cases
- [ ] Gas benchmarking
- [ ] Test partial execution scenarios
- [ ] Test refund mechanisms

### Documentation

- [ ] NatSpec comments for all functions
- [ ] Document hook data structure
- [ ] Document supported chains/routers
- [ ] Document error codes

---

## Quick Reference: Superform Hook Data Structure

Based on existing hooks, a recommended data structure for the Uniswap V3 hook:

```solidity
/// @dev data has the following structure
/// @notice         address tokenIn = BytesLib.toAddress(data, 0);
/// @notice         address tokenOut = BytesLib.toAddress(data, 20);
/// @notice         uint24 fee = uint24(BytesLib.toUint24(data, 40));
/// @notice         address recipient = BytesLib.toAddress(data, 43);
/// @notice         uint256 deadline = BytesLib.toUint256(data, 63);
/// @notice         uint256 amountIn = BytesLib.toUint256(data, 95);
/// @notice         uint256 amountOutMinimum = BytesLib.toUint256(data, 127);
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 159));
/// @notice         bool usePrevHookAmount = _decodeBool(data, 191);
```

---

## Additional Resources

- [Uniswap V3 Core Repository](https://github.com/Uniswap/v3-core)
- [Uniswap V3 Periphery Repository](https://github.com/Uniswap/v3-periphery)
- [Uniswap Documentation](https://docs.uniswap.org/)
- [Trail of Bits Uniswap V3 Audit](https://www.trailofbits.com/documents/UniswapV3Core.pdf)
- [Cyfrin Uniswap V3 Swaps Guide](https://www.cyfrin.io/glossary/uniswap-v3-swaps-solidity-code-examples)
- [QuickNode Uniswap V3 Guide](https://www.quicknode.com/guides/defi/dexs/how-to-swap-tokens-on-uniswap-v3)
