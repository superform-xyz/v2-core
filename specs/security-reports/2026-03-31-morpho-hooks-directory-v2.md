# Security Analysis Report (v2 — Post-Fix Re-Scan)

## Metadata
- **Target:** `src/hooks/loan/morpho/` (8 files)
- **Mode:** review
- **Date:** 2026-03-31
- **Contract Types Detected:** DeFi Lending (Morpho Blue)
- **Files Analyzed:** 8 (BaseMorphoLoanHook, MorphoBorrowHook, MorphoSupplyHook, MorphoSupplyAndBorrowHook, MorphoRepayHook, MorphoRepayAndWithdrawHook, MorphoWithdrawHook, MorphoLendHook)
- **Previous Report:** `2026-03-31-morpho-hooks-directory.md`

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | — |
| P1 High | 0 (2 known, documented) | — |
| P2 Medium | 4 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** — No new P0 or P1 findings. All previously identified P1s are documented as KNOWN LIMITATIONs in contract NatSpec. P2s are advisory.

---

## Known Limitations (Documented, Not Blocking)

### [KNOWN P1-2] Front-Running Full Repayment Griefing
- **Files:** MorphoRepayHook.sol, MorphoRepayAndWithdrawHook.sol
- **Status:** Documented in contract NatSpec
- **Description:** An attacker can front-run full repayment by repaying 1 wei of shares on behalf of the borrower, causing the share balance to change and the victim's tx to revert.
- **Mitigation:** Use private mempools or add slippage tolerance to share amounts.

### [KNOWN P1-3] Stale Approval TOCTOU on Full Repayment
- **Files:** MorphoRepayHook.sol, MorphoRepayAndWithdrawHook.sol
- **Status:** Documented in contract NatSpec
- **Description:** Interest accrues between `build()` and `execute()`. The approval set during `build()` from `sharesToAssets()`/`deriveLoanAmount()` may be stale. `_preExecute` calls `accrueInterest()` but the approval was already set.
- **Mitigation:** The off-chain bundler should execute UserOps promptly after building.

---

## P2 Findings (Medium — Should Fix)

### [P2-1] `morpho` Storage Variable Should Be `immutable`
- **File:** BaseMorphoLoanHook.sol:50
- **Category:** Gas / Security
- **Description:** `morpho` is set once in the constructor and never modified. Declaring it `immutable` saves ~2100 gas per access (SLOAD vs stack push) and prevents any future accidental modification.
- **Vulnerable Code:**
  ```solidity
  address public morpho;
  ```
- **Secure Pattern:**
  ```solidity
  address public immutable morpho;
  ```

### [P2-2] `morphoStaticTyping` Storage Variables Should Be `immutable`
- **Files:** MorphoRepayHook.sol:44, MorphoRepayAndWithdrawHook.sol:44
- **Category:** Gas / Security
- **Description:** `morphoStaticTyping` is set once in the constructor and never modified. Same rationale as P2-1.
- **Vulnerable Code:**
  ```solidity
  IMorphoStaticTyping public morphoStaticTyping;
  ```
- **Secure Pattern:**
  ```solidity
  IMorphoStaticTyping public immutable morphoStaticTyping;
  ```

### [P2-3] RepayHook Does Not Set `outAmount`
- **File:** MorphoRepayHook.sol:166-171
- **Category:** Logic
- **Description:** `MorphoRepayHook._preExecute` only calls `accrueInterest()` and never calls `_setOutAmount()`. There is no `_postExecute` override. This means `getOutAmount()` always returns 0 for RepayHook. If a downstream hook chains via `usePrevHookAmount`, it would receive 0.
- **Impact:** Low in practice — repay hooks are typically terminal in a chain. But inconsistent with other hooks that set outAmount.
- **Recommendation:** Either add `_preExecute`/`_postExecute` to track loanToken consumed, or document that RepayHook does not support `usePrevHookAmount` chaining.

### [P2-4] Potential Underflow in `_postExecute` Balance Tracking
- **Files:** MorphoBorrowHook.sol, MorphoSupplyHook.sol, MorphoSupplyAndBorrowHook.sol, MorphoLendHook.sol
- **Category:** Arithmetic
- **Description:** In `_postExecute`, the pattern `balance_after - getOutAmount(account)` assumes `balance_after >= pre_balance`. If an external factor reduces the balance between `_preExecute` and `_postExecute` (e.g., a fee-on-transfer token interaction, or the account being drained by another tx in the same bundle), this could underflow and revert.
- **Impact:** Low — Morpho Blue doesn't charge fees on the hook's execution path, and smart account operations are atomic. But fee-on-transfer tokens could trigger this.
- **Recommendation:** Document as acceptable for standard tokens. If fee-on-transfer support is ever needed, add safe subtraction.

---

## P3 Findings (Low — Consider Fixing)

### [P3-1] Duplicate `deriveShareBalance` and `sharesToAssets` Functions
- **Files:** MorphoRepayHook.sol:145-159, MorphoRepayAndWithdrawHook.sol:169-227
- **Description:** Both hooks independently implement `deriveShareBalance()` and `sharesToAssets()`. Could be consolidated into `BaseMorphoLoanHook` to reduce code duplication.

### [P3-2] MorphoLendHook Defines Its Own `LendHookLocalVars` Struct
- **File:** MorphoLendHook.sol:35-43
- **Description:** `LendHookLocalVars` has the same first 7 fields as `BaseMorphoLoanHook.BuildHookLocalVars` minus `isFullRepayment`. Consider reusing the base struct.

### [P3-3] Magic Numbers in MorphoWithdrawHook
- **File:** MorphoWithdrawHook.sol:101-102,108-109,122-126
- **Description:** Byte offsets `80`, `100`, `120`, `152`, `184` are used as raw numbers. Consider adding named constants similar to `LOAN_TOKEN_OFFSET` pattern.

### [P3-4] `onBehalf`/`recipient` Zero Address Not Validated in WithdrawHook
- **File:** MorphoWithdrawHook.sol:128-130
- **Description:** The hook validates `loanToken`, `collateralToken`, `oracle`, and `irm` for zero address but not `onBehalf` or `recipient`. A zero `recipient` would cause Morpho to revert, but the error would be opaque.

### [P3-5] Inconsistent outAmount Keying in WithdrawHook
- **File:** MorphoWithdrawHook.sol:100-109
- **Description:** `_preExecute`/`_postExecute` key outAmount by `recipient` address (extracted from data offset 100), while all other hooks key by `account`. If `usePrevHookAmount` is used after a WithdrawHook, the downstream hook would query `getOutAmount(account)` which would return 0 instead of the recipient-keyed value.

---

## Attack Surface Summary
- **External Entry Points:** `buildHookExecutions()`, `preExecute()`, `postExecute()` (called by execution engine)
- **Value Transfer Points:** All Morpho calls (supply, borrow, repay, withdraw, supplyCollateral, withdrawCollateral)
- **Oracle Dependencies:** Morpho market oracle for borrow amount calculation in SupplyAndBorrowHook
- **Cross-Contract Interactions:** Morpho Blue protocol, ERC-20 approve/balanceOf
- **Upgrade Mechanisms:** None (hooks are not upgradeable)

## Coding Standards Findings
- NatSpec format reverted to offchain-parser-compatible format (completed this session)
- `using` directives properly propagated to all child contracts (fixed this session)
- Import organization follows existing conventions
- Custom errors used throughout (no revert strings)
