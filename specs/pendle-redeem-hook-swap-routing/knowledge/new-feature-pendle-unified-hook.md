---
title: PendleUnifiedHook - Unified Pendle Router Operations with Swap Routing Fix
category: new-feature
date: 2025-02-02
spec: /specs/pendle-redeem-hook-swap-routing/technical-spec.md
components:
  - src/hooks/swappers/pendle/PendleUnifiedHook.sol
  - test/unit/hooks/pendle/PendleUnifiedHook.t.sol
  - test/integration/pendle/PendleUnifiedHookIntegration.t.sol
tags:
  - pendle
  - hooks
  - swap-routing
  - redemption
  - tokenRedeemSy
---

# PendleUnifiedHook - Unified Pendle Router Operations with Swap Routing Fix

## Summary

Created `PendleUnifiedHook` to replace the deprecated `PendleRouterSwapHook` and `PendleRouterRedeemHook`. The new hook supports all three Pendle router operations (`swapExactTokenForPt`, `swapExactPtForToken`, `redeemPyToToken`) with a critical fix for swap routing validation during redemptions.

The core fix: When swap routing is used (e.g., redeem PT+YT → DETH → WETH), the hook now validates `tokenRedeemSy` (the intermediate token) against `SY.isValidTokenOut()` instead of `tokenOut` (the final destination token). This enables atomic redemption + swap operations where the final token is not directly redeemable from the SY contract.

## Problem Statement

The original `PendleRouterRedeemHook` validated `tokenOut` against `SY.isValidTokenOut()`, which broke when users wanted to redeem to a token that wasn't directly supported by the SY contract. Pendle's `redeemPyToToken` supports a 3-step flow:

1. Redeem PT+YT → SY
2. Redeem SY → `tokenRedeemSy` (must be valid SY output)
3. Swap `tokenRedeemSy` → `tokenOut` via external router (can be ANY token)

The `TokenOutput` struct already supports this:
```solidity
struct TokenOutput {
    address tokenOut;        // Final desired output (can be any token)
    uint256 minTokenOut;     // Slippage protection for entire operation
    address tokenRedeemSy;   // Intermediate token (must be valid SY output)
    address pendleSwap;      // Pendle's swap aggregator
    SwapData swapData;       // Routing for tokenRedeemSy → tokenOut
}
```

## Implementation Details

### Key Decisions

1. **Unified Hook Design**: Single hook supporting all three selectors (`redeemPyToToken`, `swapExactTokenForPt`, `swapExactPtForToken`) instead of separate hooks. This simplifies deployment and maintenance.

2. **Market as yieldSource**: For all operations, `yieldSource` is always the market address. The hook retrieves SY, PT, YT from market via `IPendleMarket(yieldSource).readTokens()`. This provides consistency across all selectors.

3. **Validation Logic Split**:
   - When `swapData.swapType == SwapType.NONE`: Direct redemption, validate `tokenOut`
   - When `swapData.swapType != SwapType.NONE`: Swap routing, validate `tokenRedeemSy`

4. **ETH_WETH Exception**: `SwapType.ETH_WETH` legitimately uses `extRouter = address(0)` because it performs internal WETH wrap/unwrap without an external aggregator.

### Core Validation Fix

```solidity
// CORE FIX: Validate based on swap routing
if (output.swapData.swapType != SwapType.NONE) {
    // Swap routing: validate tokenRedeemSy (intermediate token), NOT tokenOut
    if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
        revert TOKEN_REDEEM_SY_NOT_VALID();
    }
    // Validate external router (except for ETH_WETH which uses internal wrap/unwrap)
    if (output.swapData.swapType != SwapType.ETH_WETH && output.swapData.extRouter == address(0)) {
        revert INVALID_EXT_ROUTER();
    }
} else {
    // Direct redemption: validate tokenOut
    if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
        revert TOKEN_OUT_NOT_LISTED();
    }
}
```

### Data Layout

```
[bytes32 placeholder][address yieldSource][bool usePrevHookAmount][uint256 value][bytes txData]
    0-32                  32-52                    52-53                53-85         85+
```

### Code Examples

**Building redeem hook data with swap routing:**
```solidity
TokenOutput memory output = TokenOutput({
    tokenOut: WETH,           // Final token (NOT valid SY output)
    minTokenOut: minAmount,
    tokenRedeemSy: DETH,      // Intermediate token (valid SY output)
    pendleSwap: PENDLE_SWAP,  // Required for swap routing
    swapData: SwapData({
        swapType: SwapType.ODOS,
        extRouter: ODOS_ROUTER,
        extCalldata: odosCalldata,
        needScale: true       // Scale calldata to actual redeemed amount
    })
});
```

**Integration test for swap routing:**
```solidity
function test_RedeemPyToToken_SwapRouting_DETH_to_WETH() public {
    // WETH is NOT a valid SY output, DETH is
    // This only works with the tokenRedeemSy fix

    bytes memory odosCalldata = _getOdosSwapCalldata(DETH, WETH, amount, PENDLE_ROUTER);

    bytes memory hookData = _createPendleUnifiedRedeemHookDataWithSwap(
        DETH_MARKET,  // yieldSource is market
        amount,
        yt,
        WETH,         // tokenOut (NOT valid SY output)
        DETH,         // tokenRedeemSy (valid SY output)
        minOut,
        false,
        odosCalldata
    );

    // Execute and verify WETH received
    executeOp(userOpData);
    assertGt(IERC20(WETH).balanceOf(account), balanceBefore);
}
```

## Testing Strategy

### Unit Tests (50 tests)
- Constructor validation
- All three selector builds with various parameters
- Revert conditions: invalid receiver, market, YT, minTokenOut, amount
- Swap routing validation: tokenRedeemSy, extRouter
- ETH_WETH swap type with extRouter = address(0)
- Limit order validation (normalFills, flashFills, expired, invalid maker/receiver)
- Gas griefing prevention (TOO_MANY_FILLS with 65 fill orders)
- Pre/post execute balance tracking
- Native ETH handling

### Integration Tests (3 tests)
- Direct redemption with real DETH market on mainnet fork
- Swap routing: DETH → WETH via Odos
- TokenRedeemSy validation with valid SY output

### Key Test Insights

1. **Odos API `compact` parameter**: When using `needScale: true` with Pendle, must use `compact: false` because Pendle's `_odosScaling` only handles `IOdosRouterV2.swap` selector, not `swapCompact`.

2. **Mock setup for market**: The mock market must return `mockSY` (MockStandardizedYield) not `syToken` (MockERC20), otherwise `isValidTokenOut` checks fail.

3. **Deal limitations**: `deal()` sets ERC20 balance but doesn't update Pendle's internal PT/YT accounting. Integration tests verify hook execution and output token receipt, not exact amounts.

## Deployment

### Files Updated
- `script/utils/Constants.sol` - Added `PENDLE_UNIFIED_HOOK_KEY`
- `script/DeployV2Core.s.sol` - Added to hook array (index 43), struct, deployment logic
- `script/run/regenerate_bytecode.sh` - Added to `HOOK_CONTRACTS` array
- Bytecode copied to all locked-bytecode folders

### Deployment Behavior
- Deploys when `configuration.pendleRouters[chainId] != address(0)`
- Skipped alongside `PendleRouterSwapHook` and `PendleRouterRedeemHook` when no Pendle router

## Prevention & Best Practices

### When Building Pendle Hooks

1. **Always validate the correct token**: For swap routing, validate `tokenRedeemSy` not `tokenOut`
2. **Check SwapType for validation exceptions**: `ETH_WETH` doesn't need `extRouter`
3. **Use market as yieldSource**: Provides consistent access to SY, PT, YT via `readTokens()`

### When Testing with Odos/Pendle

1. **Use `compact: false`** when `needScale: true` is required
2. **Set `pendleSwap`** to Pendle's swap aggregator address for swap routing
3. **Set `needScale: true`** when SY redemption may return less than expected (fees/rounding)

### Security Considerations

1. **Gas griefing prevention**: The hook caps `LimitOrderData` fill arrays at `MAX_FILLS = 64` to prevent attackers from crafting arrays sized to consume exact gas budgets and DoS relayers/operators.

```solidity
uint256 private constant MAX_FILLS = 64;

function _validateFillOrders(FillOrderParams[] memory fills) private view {
    if (fills.length > MAX_FILLS) revert TOO_MANY_FILLS();
    // ... validation continues
}
```

### Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `TOKEN_OUT_NOT_LISTED` | Validating tokenOut instead of tokenRedeemSy | Use swap routing with valid tokenRedeemSy |
| `INVALID_EXT_ROUTER` | extRouter=0 with non-ETH_WETH swap type | Provide extRouter or use ETH_WETH |
| `TOKEN_REDEEM_SY_NOT_VALID` | tokenRedeemSy not in SY's valid outputs | Use token from `SY.getTokensOut()` |
| `TOO_MANY_FILLS` | normalFills or flashFills array exceeds 64 | Limit fill orders to ≤64 per array |
| Odos assertion fail | Using `compact: true` with `needScale: true` | Use `compact: false` in Odos API call |
| Transfer to address(0) | Missing `pendleSwap` in TokenOutput | Set `pendleSwap` to Pendle's swap aggregator |

## Related Documentation

- [Pendle Router V4 Interface](src/vendor/pendle/IPendleRouterV4.sol)
- [PendleRouterSwapHook (deprecated)](src/hooks/swappers/pendle/PendleRouterSwapHook.sol)
- [PendleRouterRedeemHook (deprecated)](src/hooks/swappers/pendle/PendleRouterRedeemHook.sol)
- [Technical Spec](specs/pendle-redeem-hook-swap-routing/technical-spec.md)
