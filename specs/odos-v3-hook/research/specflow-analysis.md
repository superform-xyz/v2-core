# SpecFlow Analysis: Odos V3 Hook

## Key Gaps Identified

### Critical (P1)
1. **Byte layout:** referralCode (uint64), referralFee (uint64), feeRecipient (address) should be tight-packed (BytesLib convention)
2. **ApproveAndSwap + native ETH:** Must skip approval executions for address(0) input
3. **Fee cap check location:** Place in `_buildHookExecutions()` for early revert
4. **V3 router interface:** Must define complete IOdosRouterV3 with exact struct types
5. **Zero-amount guard:** Add `inputAmount == 0` revert (1inch pattern)

### Important (P2)
6. **outputMin == 0 guard:** Add validation to prevent disabling slippage protection
7. **inspect() format:** `abi.encodePacked(executor, feeRecipient)` = 40 bytes
8. **outputQuote scaling:** Do NOT scale (match V2 behavior)
9. **feeRecipient=address(0) when fee=0:** Valid (no-fee config)
10. **Minimum data length:** 245 bytes minimum validation

### Nice-to-have (P3)
11. Shared base logic between both hooks (currently duplicated)
12. HookParams struct update for V3 fields
13. Contract naming: SwapOdosV3Hook / ApproveAndSwapOdosV3Hook confirmed

## Resolved Decisions (from analysis)
- Tight-packed byte layout (consistent with all other hooks)
- Fee cap in `_buildHookExecutions()` (view context, early revert)
- Custom error: `REFERRAL_FEE_TOO_HIGH()`
- inspect() returns `abi.encodePacked(executor, feeRecipient)`
- ApproveAndSwap skips approvals for native ETH input
- outputQuote NOT scaled when usePrevHookAmount=true
