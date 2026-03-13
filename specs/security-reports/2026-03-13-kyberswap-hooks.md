# Security Analysis Report

## Metadata
- **Target:** `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol`, `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol`
- **Mode:** review
- **Date:** 2026-03-13
- **Contract Types Detected:** DEX/Swapper Hook
- **Files Analyzed:** 2 (+ vendor interfaces, BaseHook, HookDataUpdater for context)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 3 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 6 | No |

## Verdict
**FAIL** - 3 blocking findings (P1) should be evaluated before merge.

## P1 Findings (High - Must Fix)

### P1-1: Missing Zero-Amount Validation After usePrevHookAmount

- **File:** `SwapKyberSwapHook.sol` / `ApproveAndSwapKyberSwapHook.sol`
- **SWC:** N/A
- **Category:** Logic
- **Description:** When `usePrevHookAmount=true` and the previous hook's `getOutAmount()` returns 0, the hook will attempt a swap with `amount=0`. The 1inch hook has an explicit check: `if (amount == 0) revert INVALID_INPUT_AMOUNT()`. The KyberSwap hooks lack this guard.
- **Exploit Scenario:** If a previous hook fails silently (returns 0), the KyberSwap hook would proceed to approve 0 tokens and call the router with a 0-amount swap. While likely to revert at the router level, this wastes gas and provides poor error messaging.
- **Vulnerable Code:**
  ```solidity
  // In _buildHookExecutions, after getting prevAmount:
  inputAmount = ISuperHookResult(prevHook_).getOutAmount(account_);
  // No zero check — proceeds to build swap with potentially 0 amount
  ```
- **Secure Pattern:**
  ```solidity
  inputAmount = ISuperHookResult(prevHook_).getOutAmount(account_);
  if (inputAmount == 0) revert ZERO_AMOUNT();
  ```
- **Reference:** 1inch hook pattern at `Swap1InchHook.sol`
- **Assessment:** LOW REAL-WORLD RISK. The router itself will revert on zero-amount swaps. However, explicit validation provides better error messages and consistency with other hooks.

### P1-2: Division by Zero in _proportionalScale When originalAmount=0

- **File:** `SwapKyberSwapHook.sol:~169` / `ApproveAndSwapKyberSwapHook.sol:~198`
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:** If `originalAmount` (from hookData) is 0 while `usePrevHookAmount=true`, `Math.mulDiv(srcAmounts[i], newAmount, originalAmount)` will revert with division by zero. This path is only reachable when: (1) ScaleHelper is not set or fails, AND (2) the encoded `inputAmount` in hookData is 0.
- **Exploit Scenario:** A malformed hookData with `inputAmount=0` and `usePrevHookAmount=true` would cause the proportional fallback to panic-revert instead of a clean custom error.
- **Vulnerable Code:**
  ```solidity
  params.desc.srcAmounts[i] = Math.mulDiv(params.desc.srcAmounts[i], newAmount, originalAmount);
  // originalAmount could be 0
  ```
- **Secure Pattern:**
  ```solidity
  // Already guarded if P1-1 (zero amount check) is implemented — originalAmount=0 with
  // usePrevHookAmount would mean the hookData was constructed with inputAmount=0,
  // and newAmount from prevHook would also need to be non-zero (checked by P1-1).
  // Adding explicit guard:
  if (originalAmount == 0) revert ZERO_AMOUNT();
  ```
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)
- **Assessment:** LOW REAL-WORLD RISK. Requires malformed hookData (inputAmount=0 with usePrevHookAmount=true). Would revert anyway (Solidity panic), but a clean error is better.

### P1-3: Unvalidated approveTarget From User-Controlled txData

- **File:** `ApproveAndSwapKyberSwapHook.sol:_getApproveTarget()`
- **SWC:** N/A
- **Category:** Access Control
- **Description:** The `approveTarget` is decoded from user-provided `txData` and used as the approval spender. Unlike Odos which hardcodes `address(ODOS_ROUTER_V2)` as the spender, KyberSwap's architecture requires extracting `approveTarget` from the calldata because KyberSwap separates `callTarget` and `approveTarget` in `SwapExecutionParams`.
- **Exploit Scenario:** A malicious `txData` could set `approveTarget` to an attacker-controlled address, causing the hook to approve tokens to the attacker. However, the swap call still goes to `KYBER_ROUTER` (hardcoded), so the attacker would need to front-run and transfer the approved tokens before the swap call reverts (due to insufficient balance).
- **Vulnerable Code:**
  ```solidity
  function _getApproveTarget(bytes calldata txData_) internal pure returns (address target) {
      IMetaAggregationRouterV2.SwapExecutionParams memory params = abi.decode(
          BytesLib.slice(txData_, 4, txData_.length - 4),
          (IMetaAggregationRouterV2.SwapExecutionParams)
      );
      target = params.approveTarget == address(0) ? address(KYBER_ROUTER) : params.approveTarget;
  }
  ```
- **Secure Pattern:** This is an architectural constraint of KyberSwap — `approveTarget` must be decoded from txData because it varies per route. The mitigation is:
  1. The approval is sandwiched: `approve(0)` → `approve(amt)` → swap → `approve(0)` — residual approval is always cleared
  2. Off-chain validation should verify `approveTarget` is a known KyberSwap executor
  3. Could add an allowlist of known KyberSwap executor addresses (but this would require maintenance)
- **Reference:** LI.FI $9M exploit (arbitrary approval target), SwapNet $17M exploit
- **Assessment:** MEDIUM REAL-WORLD RISK. The approve(0) cleanup after swap mitigates residual approval. The real risk is MEV front-running between approve(amt) and the swap call. However, this is the same trust model as the raw calldata approach used by all aggregator hooks — the off-chain system is trusted to provide valid txData.

## P2 Findings (Medium - Should Fix)

### P2-1: Double Decoding of SwapExecutionParams in ApproveAndSwapKyberSwapHook

- **File:** `ApproveAndSwapKyberSwapHook.sol`
- **Category:** Gas/Efficiency
- **Description:** When `usePrevHookAmount=true`, the hook decodes `SwapExecutionParams` twice: once in `_getApproveTarget()` and once in `_updateTxDataAmounts()`. Each decode is expensive due to the complex nested struct.
- **Recommendation:** Reorder `_getApproveTarget` call to after `_updateTxDataAmounts` and extract `approveTarget` from the already-decoded params. Or decode once and pass the result.

### P2-2: Code Duplication Between Hooks

- **File:** Both hooks
- **Category:** Maintainability
- **Description:** `_updateTxDataAmounts()` and `_proportionalScale()` are identical in both hooks. Changes to scaling logic must be synchronized.
- **Recommendation:** Extract shared logic to a library (e.g., `KyberSwapScaler.sol`) or an abstract base contract.

### P2-3: ScaleHelper External Dependency

- **File:** Both hooks
- **Category:** External Dependency
- **Description:** ScaleHelper (`0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D`) is an external KyberSwap contract. If compromised, it could return malicious calldata. The hooks use `try/catch` so a revert falls back to proportional scaling, but a successful return of bad data would be used.
- **Recommendation:** Accept as known risk. The off-chain system should verify ScaleHelper results independently.

### P2-4: HookDataUpdater Precision Loss

- **File:** Both hooks (via `HookDataUpdater.getUpdatedOutputAmount`)
- **Category:** Arithmetic
- **Description:** `HookDataUpdater` uses percent-based calculation with `PRECISION=1e5`, which can lose precision compared to `Math.mulDiv(outputAmount, newAmount, originalAmount)`. For example, with small amounts the rounding through percent calculation loses more than direct proportional calculation.
- **Recommendation:** Accept as protocol-wide pattern — all hooks use `HookDataUpdater` consistently. Changing for KyberSwap only would break consistency.

### P2-5: Potential Underflow in _postExecute

- **File:** `BaseHook.sol` (applies to all hooks)
- **Category:** Arithmetic
- **Description:** If the output token balance decreases during execution (e.g., fee-on-transfer token where the hook is also the recipient), `_getBalance(account) - preBalance` could underflow.
- **Recommendation:** This is a BaseHook concern, not KyberSwap-specific. The protocol trusts that vault tokens behave correctly.

## P3 Findings (Low - Consider Fixing)

### P3-1: callTarget Not Validated
- **Description:** `callTarget` in `SwapExecutionParams` is decoded but the swap call always goes to `KYBER_ROUTER` (hardcoded). The `callTarget` field is informational only. No risk.

### P3-2: dstReceiver Not Validated Against Account
- **Description:** The `desc.dstReceiver` in txData is not validated to match `account_`. The off-chain system must ensure the receiver is correct.
- **Assessment:** Standard trust model for raw calldata hooks. Odos and 1inch have the same pattern.

### P3-3: outputMin Never Enforced On-Chain
- **Description:** The `outputMin` field in hookData is not used for on-chain slippage checks. The router's own `minReturnAmount` in the swap params provides slippage protection.
- **Assessment:** By design — the router enforces slippage. `outputMin` is for off-chain validation only.

### P3-4: Empty Catch Block in ScaleHelper Try/Catch
- **Description:** The `catch` block after ScaleHelper call is empty (falls through to proportional scaling). Consider logging or emitting an event for debugging.

### P3-5: Residual Approval Window (MEV)
- **Description:** Between `approve(amount)` and `approve(0)` there's a window where MEV bots could exploit the approval. Mitigated by atomic execution within a single transaction (ERC-7579 batched execution).

### P3-6: Missing NatSpec on Internal Functions
- **Description:** Internal functions like `_proportionalScale`, `_getApproveTarget` lack NatSpec documentation.

## Attack Surface Summary

- **External Entry Points:** `build()` (view), `inspect()` (view) — both inherited from BaseHook
- **Value Transfer Points:** Native ETH forwarding via `value` field, ERC-20 approvals and swaps
- **Oracle Dependencies:** None (swap pricing from KyberSwap API, not on-chain oracles)
- **Cross-Contract Interactions:** KyberSwap Router, KyberSwap ScaleHelper, ERC-20 tokens
- **Upgrade Mechanisms:** None (immutable deployment)

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 6 (MEV), 8 (Unchecked Returns), 10 (Token Integration), 13 (Gas)
- **evmresearch.io patterns checked:** DEX aggregator integration, approval-based attacks, calldata manipulation
- **Historical exploits cross-referenced:** KyberSwap Elastic $47M (Nov 2023), LI.FI $9M (arbitrary approval), SwapNet $17M
