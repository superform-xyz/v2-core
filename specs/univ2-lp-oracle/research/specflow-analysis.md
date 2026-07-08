# SpecFlow Analysis: UniV2 LP Token Yield Source Oracle

## User Flow Overview

This is a view-only, stateless oracle contract. The flows are **call flows** initiated by other contracts or off-chain systems.

### Flow 1: Price Per Share Query
Caller calls `getPricePerShare(pairAddress)`. Internally: fetch `getReserves()`, `token0()`, `token1()`, `totalSupply()`, call `IOracle.getQuote()` for token1→token0 price, compute `2 * sqrt(r0 * r1 * p1) / totalSupply`.

### Flow 2: Deposit Simulation (getShareOutput)
Caller provides assetsIn in token0. Oracle computes LP tokens receivable using fair price inversion: `assetsIn * ONE_LP / pricePerShare`.

### Flow 3: Withdrawal Simulation (getWithdrawalShareOutput)
Caller provides assetsIn in token0, wants LP tokens to burn. Rounds up to favor protocol.

### Flow 4: Asset Output (getAssetOutput)
Caller provides sharesIn (LP count), wants token0 value. `sharesIn * pricePerShare / ONE_LP`.

### Flow 5: Per-Owner TVL (getTVLByOwnerOfShares)
Fetches owner's LP balance, applies `getAssetOutput`.

### Flow 6: Total TVL (getTVL)
Applies `getAssetOutput(totalSupply)`.

### Flow 7: Raw Balance (getBalanceOfOwner)
Direct `balanceOf(owner)` call.

### Flow 8: Batch Variants (inherited)
`getPricePerShareMultiple`, `getTVLMultiple`, `getTVLByOwnerOfSharesMultiple`, `getAssetOutputWithFees`.

## Flow Permutations Matrix

| Dimension | Variant | Impact |
|---|---|---|
| Reserves | Both non-zero (normal) | All flows work |
| Reserves | One or both zero | sqrt yields 0; needs guard |
| totalSupply | Zero | Division by zero; must guard |
| totalSupply | Non-zero but tiny (dust) | Rounding errors |
| Oracle price | Returns 0 | Zero propagation; needs guard |
| Oracle price | Reverts (UnsupportedPair/UntrustedData) | Call reverts (hard revert pattern) |
| Oracle price | Extremely large | Potential overflow before sqrt |
| Token decimals | 6/18 (USDC/WETH) | Normalization critical |
| Token decimals | 18/18 | Simplest case |
| Token decimals | 6/6, 8/18, etc. | Must handle all combos |
| baseAsset param | token0 / address(0) / ignored | Spec: always token0 math |
| Owner | No LP tokens | Returns 0 gracefully |

## Key Gaps Identified

### Gap 1: getPricePerShare Output Unit
**Critical.** Must return token0 amount for 1e18 LP tokens, in token0 native decimals. This is consistent with how `decimals()` returns 18 (LP decimals) and the pattern `pps = value_of(10^decimals) in asset terms`. For USDC/WETH: value of 1e18 LP in USDC (6-dec).

### Gap 2: Decimal Normalization Order
**Critical.** The exact mulDiv decomposition to avoid overflow while maintaining precision must be specified. For `r0 * r1 * p1_in_token0`: normalize by dividing out token1Decimals in the intermediate step.

### Gap 3: Zero Guards
Need explicit `ZERO_TOTAL_SUPPLY` and `ZERO_ORACLE_PRICE` custom errors. Return early with 0 for zero-reserve pools would cause downstream issues; better to revert.

### Gap 4: baseAsset Parameter
Ignore `baseAsset` entirely (always token0 terms). Consistent with token0 denomination decision.

### Gap 5: getShareOutput is Fair Price Inversion
`assetsIn * ONE_LP / pps` — an estimate, not a real deposit simulation. Acceptable for accounting.

### Gap 6: getTVL Could Skip Oracle
`getTVL = 2 * r0_normalized` (direct from reserves, no oracle call) is mathematically equivalent and cheaper. But using `getAssetOutput(totalSupply)` is simpler and more consistent.

## Recommended Resolutions

1. **Output unit**: `getPricePerShare` returns token0 value of 1e18 LP tokens, in token0 native decimals
2. **Normalization**: `scaledProduct = mulDiv(k, p1InToken0, 10^token1Decimals)` then `sqrt(scaledProduct)`
3. **Zero guards**: Revert with `ZERO_TOTAL_SUPPLY` and `ZERO_ORACLE_PRICE` custom errors
4. **baseAsset**: Ignore (unused parameter, always token0)
5. **Constructor**: Validate `oracle_ != address(0)` with `ZERO_ADDRESS` error
6. **getShareOutput/getAssetOutput**: Fair price inversion approach
7. **getTVL**: Use `getAssetOutput(totalSupply)` for consistency
