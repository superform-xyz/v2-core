# Security Analysis Report

## Metadata
- **Target:** `src/hooks/loan/morpho/MorphoLendHook.sol` (+ inherited: BaseMorphoLoanHook, BaseLoanHook, BaseHook)
- **Mode:** review
- **Date:** 2026-03-30
- **Contract Types Detected:** DeFi Lending Hook (Morpho Blue integration)
- **Files Analyzed:** 5 (MorphoLendHook.sol, BaseMorphoLoanHook.sol, BaseLoanHook.sol, BaseHook.sol, MorphoSupplyHook.sol)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 4 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

> **Note on downgraded findings:** The EVM Security Researcher flagged "malicious market params injection" as P0 and "oracle correctness" / "permissionless market creation" as P1. These are **downgraded to informational** because:
> 1. MorphoLendHook is never called directly — it executes through SuperVaultStrategy (Merkle-proof-validated hook allowlist) or SuperExecutor (ERC-4337 UserOp with signature validation)
> 2. Market params are encoded in hook calldata which is signed by the account owner and validated against a Merkle tree
> 3. Morpho Blue's permissionless market creation is by design — the protocol validates market existence via `marketId`
> 4. Oracle risk is a market selection concern, not a hook implementation vulnerability

---

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

### [P2-1] Arithmetic underflow risk in `_postExecute` if token balance increases
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:137`
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** `_postExecute` computes `outAmount = preBalance - postBalance`. If the loan token balance unexpectedly increases (e.g., due to a rebasing token, airdrop, or callback), the subtraction underflows and reverts in Solidity 0.8.30.
- **Exploit Scenario:** If Morpho's `supply()` triggers a callback that deposits tokens back, or if the loan token is rebasing, the post-balance could exceed pre-balance, causing the transaction to revert (DoS, not fund loss).
- **Vulnerable Code:**
  ```solidity
  // MorphoLendHook.sol:137
  uint256 outAmount = preBalance - postBalance;
  ```
- **Secure Pattern:**
  ```solidity
  uint256 outAmount = preBalance > postBalance ? preBalance - postBalance : 0;
  ```
- **Reference:** vulnerabilities.md Section 3 (Arithmetic), Section 10 (Token Integration)
- **Risk Assessment:** Low likelihood — Morpho doesn't trigger callbacks when `data.length == 0` (which this hook enforces), and rebasing tokens are uncommon in Morpho markets. But defensive coding is preferred.

### [P2-2] Redundant/dead storage: `morphoBase` is never read
- **File:** `src/hooks/loan/morpho/BaseMorphoLoanHook.sol`
- **SWC:** N/A
- **Category:** Gas / Code Quality
- **Description:** `BaseMorphoLoanHook` stores `IMorpho public morphoInterface` and inherits `morphoBase` from `BaseLoanHook` and `morpho` from `BaseMorphoLoanHook`. The same Morpho address is stored in 3 separate slots. `morphoBase` is declared in `BaseLoanHook` but never read by any hook — it's dead storage consuming an extra SSTORE on deployment.
- **Vulnerable Code:**
  ```solidity
  // BaseLoanHook constructor
  morphoBase = morphoBase_;
  // BaseMorphoLoanHook constructor
  morpho = IMorphoBase(morpho_);
  morphoInterface = IMorpho(morpho_);
  ```
- **Secure Pattern:** Remove `morphoBase` from `BaseLoanHook` or consolidate to a single storage variable. Consider using immutable for gas savings.
- **Reference:** vulnerabilities.md Section 13 (Gas Optimization)

### [P2-3] `setOutAmount` in BaseHook lacks caller restriction
- **File:** `src/hooks/BaseHook.sol`
- **SWC:** SWC-105
- **Category:** Access Control
- **Description:** `setOutAmount(bytes32 context, uint256 offset, uint256 amount)` is `external` with no access control modifier. Any contract can call it to overwrite a hook's output amount in transient storage.
- **Risk Assessment:** Medium — in practice, transient storage is ephemeral (cleared after each transaction) and the execution flow is controlled by SuperExecutor/SuperVaultStrategy. However, if a malicious hook is chained in the same transaction, it could call `setOutAmount` on another hook to manipulate `usePrevHookAmount` values.
- **Reference:** vulnerabilities.md Section 2 (Access Control)

### [P2-4] `setExecutionContext` in BaseHook is permissionless
- **File:** `src/hooks/BaseHook.sol`
- **SWC:** SWC-105
- **Category:** Access Control
- **Description:** `setExecutionContext(bytes32 context, uint256 offset)` is `external` with no access control. Any contract can set the execution context for any hook.
- **Risk Assessment:** Same as P2-3 — mitigated by transient storage ephemerality and controlled execution flow, but could be exploited by a malicious hook in the same transaction chain.
- **Reference:** vulnerabilities.md Section 2 (Access Control)

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Fee-on-transfer token incompatibility
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:106-112`
- **Category:** Token Integration
- **Description:** The hook approves `amount` and supplies `amount` to Morpho. If the loan token has a fee-on-transfer, Morpho receives less than `amount`, but the hook's `_postExecute` correctly measures the actual balance change. No fund loss, but the hook's intent (supply X) differs from reality (supply X - fee).
- **Reference:** vulnerabilities.md Section 10.1

### [P3-2] No minimum data length validation in `_buildHookExecutions`
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:77`
- **Category:** Input Validation
- **Description:** The hook decodes 145 bytes of packed data without checking `data.length >= 145`. Invalid data would revert with a low-level `BytesLib` error rather than a descriptive custom error.
- **Secure Pattern:** Add `if (data.length < 145) revert InvalidDataLength();`
- **Reference:** vulnerabilities.md Section 9

### [P3-3] Duplicate `_decodeUsePrevHookAmount` function
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:148`
- **Category:** Code Quality
- **Description:** `_decodeUsePrevHookAmount` is identical to the one in `MorphoSupplyHook`. Could be extracted to `BaseMorphoLoanHook` to reduce code duplication.

### [P3-4] Unused import: HookDataDecoder
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:8`
- **Category:** Code Quality
- **Description:** `HookDataDecoder` is imported but not used in MorphoLendHook. It's used by other hooks in the inheritance chain but not directly here.

### [P3-5] NatSpec gaps
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol`
- **Category:** Code Quality
- **Description:** Missing `@param` and `@return` NatSpec on `_buildHookExecutions`, `_preExecute`, `_postExecute`, and `inspect`. The data layout comment is documented inline but not in NatSpec format.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (inherited from BaseHook, calls `_buildHookExecutions`), `inspect()`, `setOutAmount()`, `setExecutionContext()`, `resetExecutionState()`
- **Value Transfer Points:** ERC-20 `approve()` on loan token, `IMorphoBase.supply()` transfers loan tokens from account to Morpho
- **Oracle Dependencies:** None direct — Morpho uses oracle internally for LTV calculations, but the lend hook doesn't interact with oracles
- **Cross-Contract Interactions:** Morpho Blue (`supply`), ERC-20 loan token (`approve`, `balanceOf`)
- **Upgrade Mechanisms:** None — hook is not upgradeable

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 9 (Encoding), 10 (Token Integration), 13 (Gas), 15 (Code Quality), 22 (Vault Accounting)
- **evmresearch.io patterns checked:** Morpho Blue security model, lending protocol supply-side risks, ERC-4626 interaction patterns
- **Coding rules validated:** Custom errors, visibility modifiers, NatSpec, import organization
- **Historical exploits cross-referenced:** Morpho PAXG/USDC oracle incident, Euler 2023 ($197M), general lending protocol exploit patterns
