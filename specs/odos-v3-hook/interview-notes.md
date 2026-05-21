# Odos V3 Hook - Interview Notes

**Date:** 2026-05-20
**Feature:** odos-v3-hook
**Security Mode:** Enabled (--security)

---

## Round 1: Scope & Architecture

### Q1: Which V3 functions should the hook support?
**Answer:** `swap()` only — no `swapMulti()` or `swapWithHook()`.

### Q2: How should `swapReferralInfo` (code, fee, feeRecipient) be handled?
**Answer:** Fully parameterized in hook data — all 3 fields (code, fee, feeRecipient) encoded in the data payload, allowing callers to specify any referral configuration.

### Q3: Hook variants needed?
**Answer:** Both — `SwapOdosV3Hook` (no-approve) and `ApproveAndSwapOdosV3Hook` (approve-swap-revoke pattern).

### Q4: V2 coexistence?
**Answer:** Coexist — keep V2 hooks as-is, add V3 alongside. No removal or migration.

---

## Round 2: DeFi Security Probing

### Q5: Token compatibility (fee-on-transfer, rebasing, exotic tokens)?
**Answer:** Same as V2 — standard ERC-20 only. Balance delta pattern (`_preExecute`/`_postExecute`) is sufficient. No special handling for exotic tokens.

### Q6: Referral fee validation — should we cap the `fee` field to prevent drain?
**Answer:** Cap fee BPS — add a max fee check (e.g., fee <= 500 bps) to prevent accidental or malicious 100% fee drain via the `swapReferralInfo.fee` field.

### Q7: MEV/sandwich protection?
**Answer:** Same as V2 — `outputMin` slippage check enforced by Odos router is sufficient. No additional deadline or private mempool changes needed at the hook level.

### Q8: Access control?
**Answer:** Same as V2 — no access restrictions on the hook itself. SuperExecutor already validates userOps via Merkle proof, which provides the access control layer.

---

## Key Technical Context

### V2 → V3 Router Differences
- **Router address:** `0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05` (all supported EVM chains)
- **Referral:** V2 `uint32 referralCode` → V3 `swapReferralInfo { uint256 code, uint256 fee, address feeRecipient }`
- **New V3 functions (NOT needed):** `swapWithHook()`, `swapMulti()`, `swapMultiPermit2()`
- **Same:** `swapTokenInfo` struct unchanged, `pathDefinition` + `executor` pattern unchanged

### Existing V2 Hook Data Layout (for reference)
```
inputToken(20) + inputAmount(32) + inputReceiver(20) + outputToken(20) + outputQuote(32) + outputMin(32) + usePrevHookAmount(1) + pathDefinitionLength(32) + pathDefinition(var) + executor(20) + referralCode(4)
```

### V3 Hook Data Layout (proposed)
```
inputToken(20) + inputAmount(32) + inputReceiver(20) + outputToken(20) + outputQuote(32) + outputMin(32) + usePrevHookAmount(1) + pathDefinitionLength(32) + pathDefinition(var) + executor(20) + referralCode(32) + referralFee(32) + referralFeeRecipient(20)
```

### Security Decisions
- **Fee cap:** Max referral fee BPS check required (prevent drain)
- **Token handling:** Standard ERC-20 only, balance delta pattern
- **MEV:** outputMin is sufficient
- **Access:** Executor-level validation only (same as V2)
