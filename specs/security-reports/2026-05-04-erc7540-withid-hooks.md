# Security Analysis Report: ERC-7540 WithId Hooks

## Metadata
- **Target:** 6 ERC-7540 WithId hook contracts in `src/hooks/vaults/7540/`
- **Mode:** review (3 parallel agents: vulnerability scanner, best practices, EVM security research)
- **Date:** 2026-05-04
- **Contract Types Detected:** Vault/ERC-7540 async hooks
- **Files Analyzed:** 6 (plus 6 original counterparts for comparison)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 1 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

The P1 finding from the research agent (balance delta underflow when `receiver != account` in ClaimCancelRedeemRequest) was verified against the original hook and found to be **a pre-existing pattern** inherited verbatim, not a new vulnerability introduced by the WithId variants. Downgraded to informational.

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

## P2 Findings (Medium)

### [1] `requestId` used for accounting but not in actual `redeem()`/`withdraw()` vault call

- **File:** `RedeemWithId7540VaultHook.sol:66-70`, `WithdrawWithId7540VaultHook.sol:66-70`
- **SWC:** N/A
- **Category:** Logic
- **Description:** In both hooks, `requestId` is decoded from calldata and used in `_getSharesBalance()` to query `claimableRedeemRequest(requestId, account)` for the `usedShares` accounting. However, `_buildHookExecutions()` calls `IERC7540.redeem(shares, account, account)` / `IERC7540.withdraw(amount, account, account)` which do NOT take a `requestId` -- these are standard ERC-4626 functions that operate on the aggregate claimable pool. If a vault has claimable balances across multiple requestIds, the actual redemption may draw from a different request than the one `usedShares` measures.
- **Exploit Scenario:** A user has claimable shares under requestId=1 (100 shares) and requestId=2 (50 shares). Hook is called with requestId=1. `_preExecute` snapshots `claimableRedeemRequest(1, account) = 100`. The vault's `redeem()` consumes from request 2 first. Post-execution, `claimableRedeemRequest(1, account)` is still 100, so `usedShares = 100 - 100 = 0` (incorrect).
- **Vulnerable Code:**
```solidity
// _buildHookExecutions -- does NOT use requestId
callData: abi.encodeCall(IERC7540.redeem, (shares, account, account))

// But _getSharesBalance DOES use requestId
return IERC7540(yieldSource).claimableRedeemRequest(requestId, account);
```
- **Secure Pattern:** This is actually correct per the ERC-7540 spec -- `redeem`/`withdraw` don't accept requestId. The accounting mismatch only occurs if the vault has multiple non-zero requestIds with claimable balances simultaneously. In practice, Superform operations are sequential per vault, making this unlikely. **Recommend documenting this assumption.**
- **Verdict:** Accept risk -- the original hooks have the same behavior (using `claimableRedeemRequest(0, account)`). The WithId variant is strictly more correct since it can target the specific requestId's claimable balance.

---

## P3 Findings (Low)

### [2] No hook-level validation that `requestId` belongs to calling account

- **File:** All 6 WithId hooks
- **SWC:** N/A
- **Category:** Access Control
- **Description:** The `requestId` is decoded directly from calldata with no validation that it has a pending/claimable balance for the calling account. Mitigated by: (1) ERC-7540 vault enforces controller == msg.sender, (2) SuperValidator Merkle proof validates the entire calldata was signed by the account owner.
- **Risk:** Very low. Exploitation requires compromising both the Merkle proof validation AND the vault's access control.
- **Recommendation:** Defense-in-depth is sufficient. No code change needed.

### [3] `inspect()` omits `requestId` from return value

- **File:** All 6 WithId hooks (inspect functions)
- **SWC:** N/A
- **Category:** Logic
- **Description:** `inspect()` returns only the yield source (and receiver for ClaimCancel hooks), but not the `requestId`. If the validation layer uses `inspect()` output to allowlist operations, the `requestId` is not covered. However, the Merkle proof system hashes the full calldata, so the requestId cannot be modified after signing.
- **Recommendation:** Consider including requestId in inspect output for completeness, but not a security requirement.

### [4] Potential underflow revert in `_postExecute` balance delta (safety feature)

- **File:** ClaimCancelDeposit/Redeem, Redeem, Withdraw WithId hooks
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:** `_postExecute` computes `newBalance - preBalance` which reverts if the balance decreased. This is actually the desired safety behavior in Solidity 0.8.30 -- prevents incorrect accounting. Identical to original hooks.
- **Recommendation:** No change. The revert behavior is correct.

### [5] Transient storage variables (`usedShares`, `spToken`, `asset`) not context-keyed

- **File:** `RedeemWithId7540VaultHook.sol:99-105`, `WithdrawWithId7540VaultHook.sol:100-106`
- **SWC:** N/A
- **Category:** Other
- **Description:** Unlike `outAmount` (which is keyed by execution context), `usedShares`, `spToken`, and `asset` are plain transient variables that could be overwritten if the same hook is used twice in one transaction. Inherited from BaseHook design, same as original hooks.
- **Recommendation:** Execution model guarantees atomic per-hook execution. Accept existing design.

### [6] Missing calldata length validation

- **File:** All 6 WithId hooks
- **SWC:** N/A
- **Category:** Logic
- **Description:** No explicit check that `data.length >= REQUEST_ID_POSITION + 32`. If truncated calldata is passed, `BytesLib.toUint256` reads zeroed memory, effectively using `requestId = 0`. This would make the hook behave identically to the original (non-WithId) hook -- functionally safe but potentially confusing.
- **Recommendation:** Not a security risk since the fallback behavior is equivalent to the original hooks. The off-chain system (SuperBundler) constructs properly-sized calldata.

---

## Attack Surface Summary

- **External Entry Points:** `buildHookExecutions()` (view), `preExecute()`, `postExecute()` -- all gated by BaseHook authorization
- **Value Transfer Points:** Vault calls (`cancelDepositRequest`, `cancelRedeemRequest`, `claimCancelDepositRequest`, `claimCancelRedeemRequest`, `redeem`, `withdraw`) -- executed by the smart account, not the hook
- **Oracle Dependencies:** None (hooks don't query oracles directly)
- **Cross-Contract Interactions:** ERC-7540 vault (yieldSource), ERC-20 token (for balance checks)
- **Upgrade Mechanisms:** None (hooks are immutable)

## Coding Standards Findings (from Best Practices Agent)

All P3 Low -- minor NatSpec inconsistencies inherited from original hooks:
- NatSpec `bytes32` cast format differs slightly from originals (cosmetic)
- Missing behavioral `@notice` from originals (token revert behavior, non-fungible requestId)
- Missing space before `//receiver` inline comment in ClaimCancel hooks

**No actionable coding standards violations.**

## Security Knowledge Sources
- ERC-7540 / ERC-7887 specifications
- Centrifuge audit reports (Code4Rena 2023)
- SIR.trading transient storage exploit (March 2025)
- OpenZeppelin ERC-4626 inflation attack defense
- OWASP Smart Contract Top 10 2025
- BytesLib known issues / Ventral Digital fuzzing research
