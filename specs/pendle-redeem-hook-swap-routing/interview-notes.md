# Interview Notes: PendleUnifiedHook

**Date:** 2026-02-02
**Feature:** Merge Pendle hooks and fix swap routing validation

## Problem Statement

The current `PendleRouterRedeemHook` doesn't work with SuperVault's `executeHooks` when the desired output token differs from the accounting token.

### Root Cause
The hook validates `tokenOut` against `SY.isValidTokenOut()` (lines 162-169), but this only allows direct SY redemption tokens. Pendle's `redeemPyToToken` supports a 3-step flow:
1. Redeem PT+YT → SY
2. Redeem SY → `tokenRedeemSy` (must be valid SY output)
3. If `swapData` is provided, swap `tokenRedeemSy` → `tokenOut` (can be ANY token)

The fix: validate `tokenRedeemSy` against `isValidTokenOut()` when `swapData` indicates a swap is being used.

## Decisions Made

### Approach
- **Decision:** Merge existing PendleRouterRedeemHook and PendleRouterSwapHook into a unified hook
- **Rationale:** Reduces complexity, enables atomic operations with single slippage management

### Hook Name
- **Decision:** `PendleUnifiedHook`
- **Rationale:** Emphasizes the unified nature of the hook

### Supported Selectors (Minimal Set)
1. `redeemPyToToken` - Redeem PT+YT to token (with optional swap routing)
2. `swapExactTokenForPt` - Swap token to PT
3. `swapExactPtForToken` - Swap PT to token

### Security - External Router Validation
- **Decision:** Non-zero check only for `swapData.extRouter`
- **Rationale:** Trust Pendle router to handle routing safely, minimize validation overhead

### Inspect Function
- **Decision:** Keep simple with fixed data for Merkle tree compatibility
- **Constraint:** Cannot contain dynamic data like output amounts; only fixed data that won't change call-to-call
- **Approach:** Follow current hooks' pattern - include yield source, receiver, market, fixed token addresses

### Data Format
- **Decision:** Selector-specific format (pass raw Pendle router calldata)
- **Constraint:** Keep data passing similar to current hooks for smooth off-chain transition
- **Format:** Common header (yieldSource, usePrevHookAmount, value) + selector-specific tail (raw calldata)

### Migration Strategy
- **Decision:** Deprecate old hooks (PendleRouterRedeemHook and PendleRouterSwapHook)
- **Approach:** Mark as deprecated, encourage migration to PendleUnifiedHook

### ETH Support
- **Decision:** Handle ETH where Pendle allows it
- **Current state:**
  - SwapHook: Supports native ETH as `tokenIn` (sets execValue for payable calls)
  - RedeemHook: Explicitly rejects `tokenOut == address(0)`, but `_getBalance` handles ETH
- **Merged hook:** Maintain ETH support for input, evaluate ETH output based on Pendle router capabilities

### Testing
- **Decision:** Comprehensive tests
- **Requirements:**
  - Refactor existing tests (don't remove any)
  - Ensure all existing functionality works
  - Add tests for new swap routing flow
  - Include fuzzing and integration with SuperVault executeHooks

## Technical Context

### Files to Merge
- `src/hooks/swappers/pendle/PendleRouterRedeemHook.sol`
- `src/hooks/swappers/pendle/PendleRouterSwapHook.sol`

### Key Interfaces
- `src/vendor/pendle/IPendleRouterV4.sol` - Router interface with TokenOutput struct
- `src/vendor/pendle/IStandardizedYield.sol` - SY interface with isValidTokenOut
- `src/vendor/pendle/IPendleMarket.sol` - Market interface for token lookups

### TokenOutput Struct (Critical)
```solidity
struct TokenOutput {
    address tokenOut;        // Final desired output (can be any token)
    uint256 minTokenOut;     // Slippage protection for entire operation
    address tokenRedeemSy;   // Intermediate token (must be valid SY output)
    address pendleSwap;
    SwapData swapData;       // Routing for tokenRedeemSy → tokenOut
}
```

### Validation Fix
When `swapData.swapType != SwapType.NONE`:
- Validate `tokenRedeemSy` against `SY.isValidTokenOut()` (not `tokenOut`)
- Validate `swapData.extRouter != address(0)`

When `swapData.swapType == SwapType.NONE`:
- Validate `tokenOut` against `SY.isValidTokenOut()` (current behavior)

## Open Questions (Resolved)

| Question | Answer |
|----------|--------|
| Modify existing or create new? | Merge into new PendleUnifiedHook |
| Security for extRouter? | Non-zero check only |
| Inspect function changes? | Keep simple, fixed data only |
| Which selectors? | Minimal: redeemPyToToken, swapExactTokenForPt, swapExactPtForToken |
| What about old hooks? | Deprecate |
| Data format? | Selector-specific, keep similar to current for smooth transition |
| Testing scope? | Comprehensive + refactor existing |
| ETH support? | Handle where Pendle allows |
