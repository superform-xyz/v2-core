# Security Analysis Report: PendleUnifiedHook

## Metadata
- **Target:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`
- **Mode:** review
- **Date:** 2026-04-03
- **Contract Types Detected:** Swapper/DEX Integration (Pendle Router V4)
- **Files Analyzed:** 1 primary + 4 dependencies
- **Analysis Agents:** Vulnerability Scanner, Best Practices, EVM Security Researcher, Codebase Pattern Explorer

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 0 | - |
| P2 Medium | 5 | No |
| P3 Low | 8 | No |

## Verdict
**PASS** - No P0 or P1 findings. 5 medium-severity findings should be addressed before merge.

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Missing approve-to-zero pattern for USDT-like tokens in redeem path

- **File:** `PendleUnifiedHook.sol:242-252`
- **SWC:** SWC-114
- **Category:** Token Integration
- **Description:** The `_buildRedeemExecutions` function calls `IERC20.approve(PENDLE_ROUTER_V4, finalAmount)` on PT and YT tokens without first resetting the allowance to zero. Every other "Approve" hook in the codebase (`ApproveAndSwapOdosV2Hook`, `ApproveAndSwapKyberSwapHook`, `ApproveAndDeposit4626VaultHook`, etc.) follows the `approve(0) -> approve(amount)` pattern. USDT-like tokens require allowance to be zero before setting a new non-zero value.
- **Exploit Scenario:** If PT or YT wraps a USDT-like token with this restriction, and there's residual allowance from a prior partial execution, the approve call reverts, making redemption impossible.
- **Vulnerable Code:**
  ```solidity
  executions[0] = Execution({
      target: pt, value: 0,
      callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount))
  });
  ```
- **Secure Pattern:**
  ```solidity
  executions = new Execution[](5);
  executions[0] = Execution({ target: pt, value: 0,
      callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0)) });
  executions[1] = Execution({ target: pt, value: 0,
      callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount)) });
  executions[2] = Execution({ target: yt, value: 0,
      callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0)) });
  executions[3] = Execution({ target: yt, value: 0,
      callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), finalAmount)) });
  executions[4] = Execution({ /* redeemPyToToken call */ });
  ```

### [P2-2] `inspect()` silently returns empty bytes for unrecognized selectors

- **File:** `PendleUnifiedHook.sol:129-171`
- **SWC:** N/A
- **Category:** Input Validation / Consistency
- **Description:** Both `_buildHookExecutions` (line 114) and `_decodeTokenOut` (line 425) revert with `INVALID_SELECTOR()` for unknown selectors. However, `inspect()` silently returns empty `bytes memory packed`. This could mislead off-chain validation systems that rely on `inspect()` to extract security-relevant parameters.
- **Vulnerable Code:**
  ```solidity
  } else if (selector == IPendleRouterV4.redeemPyToToken.selector) {
      // ...
  }
  // No revert -- returns empty bytes
  ```
- **Secure Pattern:**
  ```solidity
  } else if (selector == IPendleRouterV4.redeemPyToToken.selector) {
      // ...
  } else {
      revert INVALID_SELECTOR();
  }
  ```

### [P2-3] `minTokenOut`/`minPtOut` can be scaled to zero, removing slippage protection

- **File:** `PendleUnifiedHook.sol:235,295,357` + `HookDataUpdater.sol:9-30`
- **SWC:** N/A
- **Category:** MEV / Slippage Protection
- **Description:** When `usePrevHookAmount` is true and the previous hook outputs a very small amount relative to the original, `HookDataUpdater.getUpdatedOutputAmount` can scale `minTokenOut`/`minPtOut` down to zero (due to `PRECISION = 1e5` rounding). The zero check for min output happens BEFORE the scaling (lines 212, 285, 351), not after. A zero min output means no slippage protection, enabling sandwich attacks.
- **Exploit Scenario:** Previous hook outputs 1 wei vs original 1e18. Scaling reduces minTokenOut from 1000 to 0. MEV bot sandwiches the swap.
- **Vulnerable Code:**
  ```solidity
  if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID(); // checked BEFORE scaling
  // ...
  output.minTokenOut = HookDataUpdater.getUpdatedOutputAmount(finalAmount, netPyIn, output.minTokenOut);
  // minTokenOut could now be 0
  ```
- **Secure Pattern:**
  ```solidity
  output.minTokenOut = HookDataUpdater.getUpdatedOutputAmount(finalAmount, netPyIn, output.minTokenOut);
  if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID(); // check AFTER scaling
  ```
  Apply at all three scaling locations (lines 235, 295, 357).

### [P2-4] Missing swap routing validation in `_buildSwapPtForTokenExecutions`

- **File:** `PendleUnifiedHook.sol:329-378`
- **SWC:** N/A
- **Category:** Input Validation / Consistency
- **Description:** The `_buildRedeemExecutions` function validates `tokenRedeemSy` against `IStandardizedYield.isValidTokenOut()` and checks that `extRouter != address(0)` when swap routing is used (lines 215-228). However, `_buildSwapPtForTokenExecutions` does NOT perform any swap routing validation on the `TokenOutput` struct. The `swapData.extRouter` could be `address(0)` even when `swapType != NONE`, which would cause the Pendle router to fail with an opaque error rather than a descriptive custom error.
- **Vulnerable Code:**
  ```solidity
  // _buildSwapPtForTokenExecutions has no swap routing validation
  ```
- **Secure Pattern:**
  ```solidity
  // After line 351, before line 353:
  if (output.swapData.swapType != SwapType.NONE) {
      if (output.swapData.swapType != SwapType.ETH_WETH && output.swapData.extRouter == address(0)) {
          revert INVALID_EXT_ROUTER();
      }
  }
  ```

### [P2-5] `abi.encodeWithSelector` used instead of type-safe `abi.encodeCall`

- **File:** `PendleUnifiedHook.sol:316-325,370-378`
- **SWC:** N/A
- **Category:** Code Quality / Type Safety
- **Description:** The `_buildRedeemExecutions` function correctly uses `abi.encodeCall` (line 256), which provides compile-time type checking. However, `_buildSwapTokenForPtExecutions` (line 316) and `_buildSwapPtForTokenExecutions` (line 370) use `abi.encodeWithSelector`, which has no compile-time argument type checking. A wrong argument order or type mismatch would silently produce corrupt calldata.
- **Vulnerable Code:**
  ```solidity
  callData: abi.encodeWithSelector(
      IPendleRouterV4.swapExactTokenForPt.selector,
      receiver, market, minPtOut, guessPtOut, input, limit
  )
  ```
- **Secure Pattern:**
  ```solidity
  callData: abi.encodeCall(
      IPendleRouterV4.swapExactTokenForPt,
      (receiver, market, minPtOut, guessPtOut, input, limit)
  )
  ```

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Unused `IPYieldToken` import
- **File:** `PendleUnifiedHook.sol:23`
- **Description:** `IPYieldToken` is imported but never used. Remove to reduce compilation overhead.

### [P3-2] Misplaced section headers (STORAGE vs CONSTANTS vs IMMUTABLES)
- **File:** `PendleUnifiedHook.sol:42-55`
- **Description:** `PENDLE_ROUTER_V4` (immutable) is under `STORAGE` header. Constants at lines 42-44 have no header. Recommend grouping under `CONSTANTS` and `IMMUTABLES`.

### [P3-3] Redundant `data.extractYieldSource()` calls in `inspect()`
- **File:** `PendleUnifiedHook.sol:138,148,160,163`
- **Description:** `extractYieldSource()` is called 3-4 times across branches. Extract once at top of function.

### [P3-4] No validation of `guessPtOut.maxIteration`
- **File:** `PendleUnifiedHook.sol:287-289`
- **Description:** An unbounded `maxIteration` could cause excessive gas consumption in the Pendle router's binary search. Consider capping at 256.

### [P3-5] `_postExecute` underflow gives opaque Solidity panic error
- **File:** `PendleUnifiedHook.sol:181`
- **Description:** If post-balance < pre-balance (fee-on-transfer token, or balance manipulation), the subtraction underflows with a generic Solidity panic. Consider adding a custom error for better diagnostics.

### [P3-6] Residual approval after redeem (no approve-to-zero after operation)
- **File:** `PendleUnifiedHook.sol:241-257`
- **Description:** Unlike other ApproveAnd* hooks that reset approval to 0 after the operation, the redeem path leaves residual allowance on the Pendle router.

### [P3-7] `value` decoded unconditionally but only used in swapExactTokenForPt branch
- **File:** `PendleUnifiedHook.sol:100`
- **Description:** `BytesLib.toUint256(data, VALUE_OFFSET)` is decoded for all selectors but only used in the `swapExactTokenForPt` path. Move into the relevant branch to save gas.

### [P3-8] Magic number `1e18` for EPS validation
- **File:** `PendleUnifiedHook.sol:289`
- **Description:** Should be a named constant (e.g., `MAX_EPS`) for readability.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view), `preExecute()`, `postExecute()`, `inspect()` (view), `decodeUsePrevHookAmount()` (pure)
- **Value Transfer Points:** ETH via `execValue` in swapExactTokenForPt; ERC20 approvals for PT/YT in redeem
- **Oracle Dependencies:** `IPendleMarket.readTokens()` (user-supplied market address), `IStandardizedYield.isValidTokenOut()` (SY from market)
- **Cross-Contract Interactions:** Pendle Router V4 (immutable), user-supplied market contract, SY/PT/YT tokens from market
- **Approval Pattern:** Redeem includes inline approvals (missing approve-to-zero); Swaps have NO inline approvals (rely on preceding hooks; no ApproveAndSwap variant exists)

## Design Notes

The explore agent confirmed that the codebase has two hook patterns:
1. **Regular hooks** (e.g., `SwapOdosV2Hook`) - single execution, no approvals, require preceding `ApproveERC20Hook`
2. **ApproveAndSwap hooks** (e.g., `ApproveAndSwapOdosV2Hook`) - 4 executions: approve(0) -> approve(amount) -> swap -> approve(0)

PendleUnifiedHook is **inconsistent**: the redeem path uses pattern #1-modified (inline approvals without approve-to-zero), while swap paths use pattern #1 (no approvals). There is no `ApproveAndSwapPendleUnifiedHook` variant. This inconsistency should be resolved by either:
- Adding approve-to-zero pattern to redeem AND adding approvals to swap paths
- Or creating a separate `ApproveAndSwapPendleUnifiedHook` and removing approvals from redeem

## Security Knowledge Sources
- **PenPie hack (Sept 2024, $27M):** Reentrancy via permissionless Pendle market creation -- mitigated here by off-chain validation + Pendle router checks
- **ERC20 approve race condition (SWC-114):** Missing approve-to-zero pattern deviates from codebase standard
- **Balance differential donation attacks:** Mitigated by atomic smart account execution
- **Uniswap V4 hook security lessons:** Pre/post mutex pattern well-designed; view-only `build()` prevents state manipulation
- **Pendle PT/YT maturity edge cases:** Post-maturity swaps revert at router level (no hook-level guard)
