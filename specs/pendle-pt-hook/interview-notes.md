# PendlePTHook Interview Notes

**Date:** 2026-07-28
**Interviewer:** Claude
**Interviewee:** Cosmin (Engineering)

## Feature Summary

PendlePTHook is a simplified Pendle hook specifically for PT (Principal Token) operations. Unlike PendleUnifiedHook which requires a selector in the payload, PendlePTHook derives the operation type entirely from header fields:

- **Buy PT:** `outputToken == PT` and `inputToken != PT` → `swapExactTokenForPt`
- **Sell PT (pre-maturity):** `inputToken == PT` and `outputToken != PT` and `!yt.isExpired()` → `swapExactPtForToken`
- **Redeem PT (post-maturity):** `inputToken == PT` and `outputToken != PT` and `yt.isExpired()` → `redeemPyToToken`
- **Anything else:** revert

## Key Design Decisions

### 1. No Selector in Payload
The operation type is derived from header tokens + YT expiry status. No 4-byte selector prefix needed.

### 2. Payload Contains All Routing Params
Payload = `abi.encode(tokenMintSy/tokenRedeemSy, pendleSwap, SwapData, ApproxParams)` — same routing params as PendleUnifiedHook minus the selector prefix. No limit orders.

### 3. No Limit Orders
Pure AMM swaps only. LimitOrderData always empty. Simplest implementation.

### 4. PT Derived from Market
PT address derived on-chain from `IPendleMarket(yieldSource).readTokens()`, then validated against header tokens. Same trust model as PendleUnifiedHook.

### 5. Inspect Returns (yieldSource, outputToken)
Same 40-byte format as PendleUnifiedHook: `abi.encodePacked(yieldSource, outputToken)`.

### 6. Sized Hook (ISuperHookOutflow)
Implements ISuperHookOutflow with replaceCalldataAmounts. OMS can splice amounts. AMOUNT_POSITION at standard SwapCalldataLayout offset.

### 7. Redeem Mode
Uses `redeemPyToToken` (burns PT+YT pair). Standard Pendle V4 redemption for expired PTs.

## Trust Model
Same as PendleUnifiedHook:
- yieldSource (Pendle market) is trusted from the signed intent
- readTokens() on market returns (SY, PT, YT) — a malicious market could return attacker-controlled addresses
- Signer is responsible for only submitting known-good market addresses
- pendleSwap and SwapData.extRouter are user-supplied via signed intent, not whitelisted

## Differences from PendleUnifiedHook
1. No selector in payload — route derived from header
2. No limit orders — pure AMM only
3. Simpler payload encoding (no selector prefix, no LimitOrderData)
4. Same interfaces: ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookInspector
