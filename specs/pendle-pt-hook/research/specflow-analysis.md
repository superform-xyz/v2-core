# PendlePTHook SpecFlow Analysis

## Flow Permutations Matrix

| Flow | inputToken | outputToken | yt.isExpired() | Result | Native ETH? | usePrevHookAmount? |
|---|---|---|---|---|---|---|
| Buy PT | non-PT ERC20 | PT | false | swapExactTokenForPt | No | Yes / No |
| Buy PT | non-PT ERC20 | PT | true | swapExactTokenForPt | No | Yes / No |
| Buy PT (native) | address(0) | PT | false | swapExactTokenForPt with value | Yes | Yes / No |
| Buy PT (native) | address(0) | PT | true | swapExactTokenForPt with value | Yes | Yes / No |
| Sell PT | PT | non-PT ERC20 | false | swapExactPtForToken | No | Yes / No |
| Sell PT | PT | non-PT ERC20 | true | ROUTES TO REDEEM | No | Yes / No |
| Redeem PT | PT | non-PT ERC20 | true | redeemPyToToken | No | Yes / No |
| Redeem PT | PT | native ETH | true | redeemPyToToken w/ ETH_WETH | No | Yes / No |
| REVERT | PT | PT | any | revert INVALID_PT_OPERATION | - | - |
| REVERT | non-PT | non-PT | any | revert INVALID_PT_OPERATION | - | - |

## Resolved Gaps

All gaps identified by the specflow analyzer are addressed in the technical spec:

| Gap | Resolution |
|-----|-----------|
| Q1: Single readTokens() call | Yes — single call at top of `_buildHookExecutions`, locals passed to builders |
| Q2: Expiry boundary | Routes to redeem (correct — Router rejects expired swaps anyway). User without YT gets Router-level revert |
| Q3: Native ETH sentinel | `address(0)` per PendleUnifiedHook pattern |
| Q4: LimitOrderData | Constructed internally as empty `LimitOrderData memory emptyLimit` — not in payload |
| Q5: readTokens() validation | `sy == address(0)` checked. PT/YT zero checks inherited from routing logic |
| Q6: scaledOutputMin zero-check | Yes — `if (scaledOutputMin == 0) revert MIN_OUT_NOT_VALID()` included |
| Q7: Per-flow payload schema | Buy: `abi.encode(tokenMintSy, pendleSwap, SwapData, ApproxParams)`. Sell/Redeem: `abi.encode(tokenRedeemSy, pendleSwap, SwapData)` |
| Q8: replaceCalldataAmounts + build | Standard OMS pattern: replace then rebuild. Documented behavior |
| Q9: inputToken == outputToken == PT | Falls through to `INVALID_PT_OPERATION()` via catch-all else branch |
| Q10: Native ETH + usePrevHookAmount | Same accepted limitation as PendleUnifiedHook — view function reads amount at build time |
| Q11: tokenMintSy validation | Not validated (same as PendleUnifiedHook — Router validates at SY level) |
| Q12: Native ETH output | Handled by `_getBalance` checking `address(0)` and `NATIVE_TOKEN` sentinel |
| Q13: Buy post-maturity | Not blocked — Router handles AMM availability |
| Q14: name/description | `"Pendle PT"` / `"Executes Pendle PT operations (buy, sell, or redeem)"` |
| Q15: outputQuote | Ignored on-chain (OMS-only field) |
| Q16: yieldSource validation | Let readTokens() bubble up revert. Trust model same as PendleUnifiedHook |
