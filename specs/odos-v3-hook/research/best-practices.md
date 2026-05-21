# Best Practices: Odos V3 DEX Swap Hook

## Summary Matrix

| Practice | Priority | Validated By | Codebase Precedent |
|---|---|---|---|
| Fee cap (max BPS) on referral fee | MUST HAVE | Hook contract | `MerklClaimRewardHook`, `SuperLedgerConfiguration` |
| feeRecipient != address(0) when fee > 0 | MUST HAVE | Hook contract | `MerklClaimRewardHook` |
| approve(0)-approve(N)-swap-approve(0) | MUST HAVE | Execution array | All `ApproveAndSwap*` hooks |
| outputMin enforcement | MUST HAVE | Odos router | Router-level enforcement |
| outputMin proportional adjustment | MUST HAVE | HookDataUpdater | All swap hooks with usePrevHookAmount |
| Balance delta via pre/post | MUST HAVE | Transient storage | All swap hooks |
| Executor returned via inspect() | RECOMMENDED | Off-chain validation | V2 Odos hooks, 1inch hook |
| BaseHook mutex for reentrancy | MUST HAVE | Built-in | BaseHook base class |
| Native ETH handling (address(0)) | MUST HAVE | Balance check + value | V2 SwapOdosV2Hook |
| Custom errors, no revert strings | MUST HAVE | Code style | All hooks |

## Key Insights

1. **Fee denomination:** V3 uses `FEE_DENOM = 1e18` (not BPS). Fee of 2% = `2e16`. Router caps at `FEE_DENOM / 50` (2%).
2. **Approval pattern:** Hooks build `Execution[]` arrays for the smart account. Cannot use `SafeERC20.forceApprove` since the hook is not the token holder.
3. **Balance delta is the only reliable output measurement** -- router return values are not accessible from the ERC-7579 execution context.
4. **BaseHook provides reentrancy protection** via transient storage mutexes.
5. **pathDefinition is opaque** -- validated only by the Odos router's outputMin enforcement.
