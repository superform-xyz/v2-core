# Security Analysis Report

## Metadata
- **Target:** `src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol`, `src/hooks/vaults/metamorpho/ApproveAndForceDeallocateMorphoHook.sol`
- **Mode:** review
- **Date:** 2026-05-22
- **Contract Types Detected:** Vault/ERC4626, General (NONACCOUNTING hooks)
- **Files Analyzed:** 3 (2 hooks + 1 vendor interface)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 8 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

---

## P0 Findings (Critical - Must Fix)

None found.

## P1 Findings (High - Must Fix)

None found.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] TOCTOU Gap: Penalty and Deadline Checks Only in `_buildHookExecutions` (view)

- **File:** `ForceDeallocateMorphoHook.sol:88-109`, `ApproveAndForceDeallocateMorphoHook.sol:94-116`
- **SWC:** SWC-114 (Transaction Order Dependence)
- **Severity:** P2 Medium
- **Category:** Logic
- **Description:** The penalty tolerance check (`forceDeallocatePenalty(adapter) / WAD_TO_BPS > maxPenaltyBps`) and deadline check (`block.timestamp > deadline`) are only performed in `_buildHookExecutions()`, which is a `view` function called off-chain during transaction building. By the time the transaction is mined, the penalty may have changed (e.g., Morpho governance updated it) or the deadline may have passed. Neither `_preExecute` nor `_postExecute` re-validates these conditions.
- **Exploit Scenario:** A user builds a transaction with a 10 bps penalty tolerance. Before the tx is mined, Morpho governance raises the penalty to 200 bps. The transaction executes with the higher penalty because `_preExecute` doesn't re-check.
- **Vulnerable Code:**
  ```solidity
  // _preExecute does NOT re-check penalty or deadline
  function _preExecute(address prevHook, address account, bytes calldata data) internal override {
      uint256 assets = data.toUint256(ASSETS_OFFSET);
      bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET);
      if (usePrevHookAmount) {
          assets = ISuperHookResult(prevHook).getOutAmount(account);
      }
      _setOutAmount(assets, account);
  }
  ```
- **Secure Pattern:**
  ```solidity
  function _preExecute(address prevHook, address account, bytes calldata data) internal override {
      // Re-validate deadline on-chain
      uint256 deadline = data.toUint256(DEADLINE_OFFSET);
      if (deadline != 0 && block.timestamp > deadline) {
          revert EXPIRED_DEADLINE(deadline, block.timestamp);
      }
      // Re-validate penalty on-chain
      address vault = data.extractYieldSource();
      address adapter = data.toAddress(ADAPTER_OFFSET);
      uint256 penaltyBps = IMorphoVaultV2(vault).forceDeallocatePenalty(adapter) / WAD_TO_BPS;
      uint256 maxPenaltyBps = data.toUint256(MAX_PENALTY_BPS_OFFSET);
      if (penaltyBps > maxPenaltyBps) {
          revert PENALTY_TOO_HIGH(penaltyBps, maxPenaltyBps);
      }
      // Set outAmount
      uint256 assets = data.toUint256(ASSETS_OFFSET);
      if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET)) {
          assets = ISuperHookResult(prevHook).getOutAmount(account);
      }
      _setOutAmount(assets, account);
  }
  ```
- **Mitigating Factor:** Morpho penalty changes are rare governance events. The `forceDeallocate` function itself enforces a max 2% penalty cap. The Superform execution pipeline typically has short latency between build and execution.
- **Reference:** vulnerabilities.md Section 6 (MEV/Front-Running), Section 22 (Vault Vulnerabilities)

---

### [P2-2] `outAmount` Set to Requested Amount, Not Actual Deallocated Amount

- **File:** `ForceDeallocateMorphoHook.sol:140-147`, `ApproveAndForceDeallocateMorphoHook.sol:156-163`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Logic
- **Description:** `_preExecute` sets `outAmount` to the requested `assets` value, but `forceDeallocate()` returns `penaltyShares` (the shares burned). The actual amount of assets deallocated could differ from the requested amount if the vault partially fills or the penalty accounting differs. There is no `_postExecute` to reconcile the actual result. Any downstream hook relying on `getOutAmount()` will receive the requested amount rather than the actual amount.
- **Vulnerable Code:**
  ```solidity
  function _preExecute(address prevHook, address account, bytes calldata data) internal override {
      uint256 assets = data.toUint256(ASSETS_OFFSET);
      bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_OFFSET);
      if (usePrevHookAmount) {
          assets = ISuperHookResult(prevHook).getOutAmount(account);
      }
      _setOutAmount(assets, account); // Sets requested, not actual
  }
  ```
- **Secure Pattern:**
  ```solidity
  // Option A: Add _postExecute to reconcile actual balance change
  function _postExecute(address, address account, bytes calldata data) internal override {
      address token = /* underlying token */;
      uint256 actualBalance = IERC20(token).balanceOf(account);
      // Compare with pre-execution snapshot and update outAmount
      _setOutAmount(actualBalance - preBalance, account);
  }

  // Option B: Accept the approximation and document it clearly
  // (Current approach - acceptable if downstream hooks don't depend on exact amounts)
  ```
- **Mitigating Factor:** This is a NONACCOUNTING hook, so it doesn't interact with the ledger. The penalty is a share burn on the caller, not a reduction in deallocated assets. The `forceDeallocate` function deallocates exactly `assets` worth of underlying — the penalty is separate. This means `outAmount = assets` is likely correct for the underlying asset amount received.
- **Reference:** vulnerabilities.md Section 22 (Vault Vulnerabilities)

---

### [P2-3] `type(uint256).max` Approval Instead of Exact Amount (ApproveAndForceDeallocate)

- **File:** `ApproveAndForceDeallocateMorphoHook.sol:128-131`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Token
- **Description:** The approve variant uses `type(uint256).max` approval instead of the exact `assets` amount. While the approval is reset to 0 after execution (line 138-139), during the execution window the vault has unlimited spending allowance on the smart account's tokens. If the vault contract has any vulnerability or if the execution is somehow interrupted between steps 2 and 4, the max approval persists.
- **Vulnerable Code:**
  ```solidity
  executions[1] = Execution({
      target: token,
      value: 0,
      callData: abi.encodeCall(IERC20.approve, (vault, type(uint256).max))
  });
  ```
- **Secure Pattern:**
  ```solidity
  executions[1] = Execution({
      target: token,
      value: 0,
      callData: abi.encodeCall(IERC20.approve, (vault, assets))
  });
  ```
- **Mitigating Factor:** The zero-approve → max-approve → action → zero-approve pattern is a common Superform convention used in other hooks. The final zero-approve (execution[3]) cleans up the allowance. The vault is a trusted Morpho contract. The execution is atomic within the smart account's `execute` call, so partial execution is unlikely.
- **Reference:** vulnerabilities.md Section 10 (Token Integration)

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] WAD-to-BPS Integer Truncation Understates Penalty

- **File:** `ForceDeallocateMorphoHook.sol:104`, `ApproveAndForceDeallocateMorphoHook.sol:111`
- **SWC:** SWC-101 (Integer Overflow/Underflow)
- **Severity:** P3 Low
- **Category:** Arithmetic
- **Description:** `forceDeallocatePenalty()` returns a WAD value (1e18 scale). The conversion `/ WAD_TO_BPS` (1e14) uses integer division which truncates. For example, a penalty of `0.00105e18` (10.5 bps) would truncate to `10` bps, understating the actual penalty and potentially passing a `maxPenaltyBps = 10` check when the real penalty is 10.5 bps.
- **Mitigating Factor:** Morpho penalties are set in clean WAD values (0, 0.001e18, 0.02e18), so truncation is unlikely in practice. The max penalty is 2% (200 bps), and the truncation error is at most 0.01 bps.
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)

### [P3-2] Missing `prevHook` Address Validation When `usePrevHookAmount = true`

- **File:** `ForceDeallocateMorphoHook.sol:96-98`, `ApproveAndForceDeallocateMorphoHook.sol:103-105`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Logic
- **Description:** When `usePrevHookAmount` is true, the code calls `ISuperHookResult(prevHook).getOutAmount(account)` without checking that `prevHook != address(0)`. If called with `prevHook = address(0)`, the call would revert with an opaque error.
- **Mitigating Factor:** The Superform execution pipeline always provides a valid `prevHook` address when hooks are chained. This is enforced at the executor level.
- **Reference:** vulnerabilities.md Section 8 (Unchecked Return Values)

### [P3-3] Token Incompatibility: `approve(0)` Reverts on Some Tokens

- **File:** `ApproveAndForceDeallocateMorphoHook.sol:126-127,138-139`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Token
- **Description:** The NatSpec documents "This hook does not support tokens reverting on 0 approval" (line 19). Some non-standard ERC-20 tokens (e.g., BNB) revert on `approve(0)`. The hook correctly documents this limitation.
- **Mitigating Factor:** Already documented. Morpho vaults typically use standard ERC-20 tokens (USDT, USDC, WETH, DAI). The base `ForceDeallocateMorphoHook` (no approve variant) can be used for incompatible tokens.

### [P3-4] Permissionless Front-Running of `forceDeallocate`

- **File:** Both hooks
- **SWC:** SWC-114
- **Severity:** P3 Low
- **Category:** MEV
- **Description:** `forceDeallocate` is permissionless — anyone can call it. A front-runner could call `forceDeallocate` with the same adapter before the user's transaction, potentially changing the vault's idle balance state and causing the user's transaction to fail or produce different results.
- **Mitigating Factor:** Front-running `forceDeallocate` doesn't steal funds — it just deallocates assets to idle balance. The penalty is paid by the front-runner, not the original user. The user's transaction would simply encounter a different vault state.

### [P3-5] No Reentrancy Guard on Hooks

- **File:** Both hooks
- **SWC:** SWC-107
- **Severity:** P3 Low
- **Category:** Reentrancy
- **Description:** Neither hook has an explicit `nonReentrant` modifier. The `forceDeallocate` call goes to an external Morpho vault which could potentially call back.
- **Mitigating Factor:** BaseHook uses transient storage mutexes (`_preExecuteMutex`, `_postExecuteMutex`) that prevent re-entrant `preExecute`/`postExecute` calls. Morpho Vault V2 has its own reentrancy guards. The hook is NONACCOUNTING and doesn't hold funds.

### [P3-6] Missing NatSpec on `_preExecute` Override

- **File:** `ForceDeallocateMorphoHook.sol:140`, `ApproveAndForceDeallocateMorphoHook.sol:156`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Code Quality
- **Description:** The `_preExecute` override lacks NatSpec documentation explaining why `outAmount` is set to the requested assets amount and the implications for downstream hooks.

### [P3-7] Gas: `_decodeBool` Copies Calldata to Memory

- **File:** Both hooks, multiple locations
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Gas
- **Description:** `_decodeBool(data, offset)` in BaseHook accepts `bytes memory`, causing an implicit calldata-to-memory copy when called from `_buildHookExecutions` (which receives `bytes calldata`). This wastes gas on memory expansion.
- **Mitigating Factor:** This is a BaseHook design pattern shared across all hooks. Changing it would require modifying the base contract. The gas cost is minimal for the data sizes involved.

### [P3-8] Flash Loan Penalty Arbitrage (Theoretical)

- **File:** Both hooks
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Flash Loan
- **Description:** Theoretically, an attacker could use a flash loan to manipulate conditions that affect the `forceDeallocatePenalty()` return value, causing the penalty check to pass when it shouldn't. However, Morpho's penalty is a governance-set parameter, not a dynamic market value, so this is not exploitable in practice.
- **Mitigating Factor:** Morpho penalty is a static governance parameter, not influenced by market state or flash loans.

---

## Attack Surface Summary

### External Entry Points
| Function | Contract | Visibility | State-Modifying |
|----------|----------|-----------|-----------------|
| `build()` | BaseHook (inherited) | external view | No |
| `preExecute()` | BaseHook (inherited) | external | Yes (transient storage) |
| `postExecute()` | BaseHook (inherited) | external | Yes (transient storage) |
| `decodeUsePrevHookAmount()` | Both hooks | external pure | No |
| `inspect()` | Both hooks | external pure | No |

### Value Transfer Points
- `forceDeallocate()` call moves assets from adapter back to vault idle balance
- `approve()` calls (ApproveAndForceDeallocate variant) grant token spending allowance
- Penalty is paid as share burn on `onBehalf` (the smart account)

### External Protocol Dependencies
- **Morpho Vault V2** (`IMorphoVaultV2`): `forceDeallocate()` and `forceDeallocatePenalty()`
- **ERC-20 tokens** (ApproveAndForceDeallocate variant): `approve()`
- **Previous hook** (when `usePrevHookAmount = true`): `getOutAmount()`

### Trust Assumptions
1. Morpho Vault V2 contract is correctly implemented and non-malicious
2. Morpho Vault V2 has internal reentrancy guards
3. Adapter addresses are valid and registered with the vault
4. The Superform execution pipeline provides correct `prevHook` addresses
5. Token used with ApproveAndForceDeallocate does not revert on zero approval

---

## Coding Standards Findings

| # | Rule | File | Description |
|---|------|------|-------------|
| 1 | NatSpec completeness | Both hooks | `_preExecute` override missing `@inheritdoc` or custom NatSpec |
| 2 | Trailing blank line | `ForceDeallocateMorphoHook.sol:156` | File ends with trailing blank line |

---

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 6, 8, 9, 10, 13, 15, 22, 26, 28, 36
- **evmresearch.io patterns checked:** vault-withdrawal, token-approval, reentrancy-via-callback, TOCTOU-in-view-functions
- **Coding rules validated:** 12 rules checked from coding-rules.md
- **Historical exploits cross-referenced:** 5 from Appendix J/K/L/M (Morpho-related, approval-related, TOCTOU-related)
