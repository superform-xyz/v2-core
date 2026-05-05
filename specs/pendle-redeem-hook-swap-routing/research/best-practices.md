# Pendle Finance Router V4 Integration Best Practices

## 1. Pendle Router V4 Integration Patterns

### 1.1 Architecture Overview

The Pendle Router V4 uses a **Diamond Pattern (ERC-2535)** architecture:
- **Single entry point**: All operations go through the same address
- **Key Router Address**: `0x888888888889758F76e7103c6CbF23ABbF58F946` (all EVM chains)

### 1.2 Core Function Signatures

```solidity
// Swap token to PT (pre-maturity)
function swapExactTokenForPt(
    address receiver,
    address market,
    uint256 minPtOut,
    ApproxParams calldata guessPtOut,
    TokenInput calldata input,
    LimitOrderData calldata limit
) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm);

// Swap PT to token (pre-maturity)
function swapExactPtForToken(
    address receiver,
    address market,
    uint256 exactPtIn,
    TokenOutput calldata output,
    LimitOrderData calldata limit
) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);

// Redeem PT+YT to token (post-maturity)
function redeemPyToToken(
    address receiver,
    address YT,
    uint256 netPyIn,
    TokenOutput calldata output
) external returns (uint256 netTokenOut, uint256 netSyInterm);
```

## 2. TokenOutput Struct Usage with SwapData

### 2.1 Simple TokenOutput (No Aggregator)

When tokenOut is directly redeemable from SY:

```solidity
function createTokenOutputSimple(
    address tokenOut,
    uint256 minTokenOut
) pure returns (TokenOutput memory) {
    return TokenOutput({
        tokenOut: tokenOut,
        minTokenOut: minTokenOut,
        tokenRedeemSy: tokenOut,  // Same as tokenOut
        pendleSwap: address(0),   // No swap needed
        swapData: SwapData({
            swapType: SwapType.NONE,
            extRouter: address(0),
            extCalldata: bytes(""),
            needScale: false
        })
    });
}
```

### 2.2 TokenOutput with External Aggregator

When tokenOut is NOT directly redeemable from SY:

```solidity
TokenOutput memory output = TokenOutput({
    tokenOut: USDC,              // Final token (not in SY.getTokensOut())
    minTokenOut: minExpected,    // Slippage protection
    tokenRedeemSy: wstETH,       // Token from SY (must be in SY.getTokensOut())
    pendleSwap: PENDLE_SWAP,     // Pendle's swap helper (DO NOT HARDCODE)
    swapData: SwapData({
        swapType: SwapType.ODOS,
        extRouter: ODOS_ROUTER,
        extCalldata: odosEncodedCalldata,
        needScale: true
    })
});
```

### 2.3 Flow Diagram

```
TokenOutput Flow:
SY --> Redeem to tokenRedeemSy --> Aggregator swap --> Final tokenOut

TokenInput Flow:
User sends tokenIn --> Aggregator swap --> tokenMintSy --> Mint SY
```

## 3. Security Considerations

### 3.1 Critical Security Checks (Must Have)

**1. Receiver Validation**
```solidity
if (receiver != expectedAccount) revert RECEIVER_NOT_VALID();
```

**2. Market/YT Address Validation**
```solidity
if (market != expectedMarket) revert MARKET_NOT_VALID();
```

**3. Minimum Output Validation**
```solidity
if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();
```

**4. Amount Validation**
```solidity
if (input.netTokenIn == 0) revert AMOUNT_IN_NOT_VALID();
```

**5. TokenOut Validation Against SY**
```solidity
address SY = abi.decode(yt.staticcall("SY()"), (address));
if (!IStandardizedYield(SY).isValidTokenOut(tokenOut)) revert TOKEN_OUT_NOT_LISTED();
```

### 3.2 External Aggregator Security

**1. Never Hardcode pendleSwap Address** - Can be upgraded

**2. Validate External Router Addresses**
```solidity
if (swapData.swapType != SwapType.NONE) {
    if (swapData.extRouter == address(0)) revert INVALID_ROUTER();
}
```

## 4. Slippage Handling

### 4.1 Two-Layer Slippage Protection

**Layer 1: Pendle-level slippage** (`minTokenOut` in TokenOutput)
- Protects the entire operation end-to-end

**Layer 2: Aggregator-level slippage** (in `extCalldata`)
- Encoded in the aggregator's calldata

### 4.2 Recommended Slippage Values

| Operation | Recommended Slippage |
|-----------|---------------------|
| Simple redemption (no aggregator) | 0.1% - 0.5% |
| With DEX aggregator | 0.5% - 2% |
| Post-maturity redemption (no swap) | 0.01% - 0.1% |

## 5. Gas Optimization

### 5.1 ApproxParams Optimization

**Default (no optimization) ~ 180k gas:**
```solidity
ApproxParams memory defaultApprox = ApproxParams({
    guessMin: 0,
    guessMax: type(uint256).max,
    guessOffchain: 0,
    maxIteration: 256,
    eps: 1e14
});
```

**Optimized with off-chain hint ~ 40k gas savings:**
```solidity
ApproxParams memory optimized = ApproxParams({
    guessMin: expectedPtOut * 95 / 100,
    guessMax: expectedPtOut * 105 / 100,
    guessOffchain: expectedPtOut,  // Checked FIRST
    maxIteration: 10,
    eps: 1e14
});
```

## 6. Common Pitfalls

1. **RouterStatic Misuse**: Never use for on-chain transactions
2. **ApproxParams Decimal Mismatch**: Scale to PT decimals (usually 18)
3. **ETH vs ERC20 Value**: Don't send ETH value with ERC20 swaps
4. **Post-Expiry Trading**: Use `redeemPyToToken` after maturity
5. **Aggregator Receiver**: Must be Pendle router for subsequent ops

## 7. Sources

- [Pendle Router Integration Guide](https://docs.pendle.finance/pendle-v2/Developers/Contracts/PendleRouter/ContractIntegrationGuide)
- [Pendle Router Overview](https://docs.pendle.finance/cn/pendle-v2/Developers/Contracts/PendleRouter/PendleRouterOverview)
- [Pendle Hosted SDK](https://docs.pendle.finance/pendle-v2/Developers/Backend/HostedSdk)
- [pendle-core-v2-public](https://github.com/pendle-finance/pendle-core-v2-public)
