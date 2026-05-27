# SpecFlow Analysis — Stargate Native Fee Sponsorship

## Flow Permutations Matrix

| Scenario | Deposit? | Deposit Survives? | Op Executes? | Orphan? | Resolution |
|---|---|---|---|---|---|
| Validation failure (bad sig/nonce) | Yes (reverts) | No | No | No | Full tx revert, retry |
| Execution failure (insufficient sponsorship) | Yes | Yes | No | Yes | Sponsor reclaims manually |
| Execution failure (Stargate send fails) | Yes (consumed) | No (withdrawn) | Partial | No | ETH stays on smart account |
| Successful bridge | Yes | No (consumed) | Yes | No | Clean |
| Batch: all ops succeed | Yes x N | No | Yes x N | No | Clean |
| Batch: first succeeds, second fails execution | Yes x N | N-1 consumed, 1 survives | Partial | Yes (1) | Sponsor reclaims 1 |
| Batch: all fail validation | Yes x N (reverts) | No | No | No | Full tx revert |
| Overfetch (amount > lzNativeFee) | Yes | Partially | Yes | No | Excess on smart account |
| Zero-amount op in batch | Skipped | N/A | N/A | N/A | Valid for mixed batches |
| FetchNativeFeeHook without deposit | N/A | N/A | Reverts | No | Clean revert |
| Multiple FetchNativeFeeHooks in single op | Supported | Both withdraw | Yes | No | Bundler sums fees |

## Gaps Identified and Resolutions

### Already Resolved (by interview/implementation plan)

| # | Gap | Resolution |
|---|-----|------------|
| 6 | Missing events | Events defined: NativeDeposited, NativeWithdrawnByAccount, NativeWithdrawnBySponsor |
| 7 | account == sponsor | Functional, no security issue — open balance model handles it |
| 8 | No interface | INativeFeeSponsorship.sol defined in implementation plan |
| 9 | receive() function | No receive() — all ETH via depositForAccount only |
| 10 | Withdrawal destination | msg.sender (smart account) — Nexus/Safe accept ETH |
| 12 | HookSubType | TOKEN (decided in interview) |
| 13 | inspect() return | Returns abi.encodePacked(SPONSORSHIP) — defined in plan |
| 14 | Multiple FetchNativeFeeHooks | Supported — bundler sums fees in single nativeAmount |
| 15 | Hook placement | No on-chain enforcement — bundler responsibility |
| 19 | Paymaster event | SponsorNativeAndHandleOp event defined in plan |
| 22 | Counterfactual deployment | initCode deploys account before callData executes |
| 23 | Dust deposit griefing | Isolated by (sponsor, account) key |

### Requires Attention

| # | Gap | Priority | Note |
|---|-----|----------|------|
| 20 | Sponsorship address in function signature | HIGH | Option A = parameter. Add `address sponsorship` as third param |
| 27 | Locked bytecode → redeployment needed | HIGH | Adding function = new bytecode = redeployment regardless |
| 1 | _postOp refund interaction | MEDIUM | Bundler recovers less than msg.value due to postOp refunds — document |
| 3 | depositForAccount fails mid-batch | MEDIUM | Whole tx reverts — sequential calls before handleOps |
| 4 | nativeAmounts[i] == 0 in batch | MEDIUM | Allow and skip deposit for mixed batches |
| 5 | _postOp withdraws from EntryPoint deposit | MEDIUM | Same behavior as existing handleOps — bundler accounting |
| 17 | EntryPoint version compat | MEDIUM | Existing handleOps already calls from contract — verified pattern |
| 18 | Gas overhead of deposit loop | LOW | Document in NatSpec |
| 28 | Fork test chain selection | LOW | Use Ethereum mainnet fork |
| 30 | Fuzz/invariant tests | LOW | Add to test plan |
