# KyberSwap Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: DEX Aggregator Expansion
- Linear Issue: N/A
- Interview Date: 2026-03-10
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Create two swap hooks for KyberSwap's MetaAggregationRouterV2 aggregator (`0x6131B5fae19EA4f9D964eAc0408E4408b66337b5`), following the 1inch hook pattern (raw calldata with validation). The hooks enable token swaps through KyberSwap within the Superform hook execution chain, supporting both ERC-20 and native ETH swaps across all chains where KyberSwap is deployed.

KyberSwap's `SwapDescriptionV2` contains dynamic arrays for fee management, making the 1inch raw-calldata approach (vs. Odos manual-struct-construction) the better fit. The API returns fully encoded `swap(SwapExecutionParams)` calldata that the hook forwards to the router.

## Requirements

### Functional
1. `SwapKyberSwapHook` - swap-only variant (1 execution, assumes prior approval or native ETH)
2. `ApproveAndSwapKyberSwapHook` - approve(0)->approve(amount)->swap->approve(0) (4 executions)
3. Both variants support `usePrevHookAmount` for hook chaining via `ISuperHookContextAware`
4. Both variants track output amounts via pre/post balance delta pattern
5. `inspect()` returns `callTarget` and `approveTarget` for security whitelisting
6. Native ETH support (value forwarding for ETH-as-input swaps)
7. Vendor interface `IMetaAggregationRouterV2.sol` with verified struct layouts

### Non-Functional
- Gas-efficient: raw calldata forwarding avoids struct reconstruction overhead
- Consistent with existing hook patterns (BaseHook, HookSubTypes.SWAP, NONACCOUNTING)
- Deployable on all Superform chains where KyberSwap is available
- **CRITICAL: `usePrevHookAmount` must update both `desc.amount` AND `desc.minReturnAmount`** in the encoded calldata (improvement over 0x where this wasn't possible). KyberSwap uses standard ABI encoding so we can decode, modify, and re-encode `SwapExecutionParams`.

## Technical Design

### Architecture

```
Hook Data (packed bytes)
    |
    v
_buildHookExecutions()
    |
    +--> [For ApproveAndSwap only]
    |    approve(router, 0)
    |    approve(router, inputAmount)
    |
    +--> swap() call with raw txData to KyberSwap Router
    |
    +--> [For ApproveAndSwap only]
         approve(router, 0)
```

### Data Model

**SwapKyberSwapHook data layout:**
- `address outputToken` (20B) + `uint256 value` (32B) + `uint256 inputAmount` (32B) + `uint256 outputMin` (32B) + `bool usePrevHookAmount` (1B) + `uint256 txDataLength` (32B) + `bytes txData_` (variable)

**ApproveAndSwapKyberSwapHook data layout:**
- `address inputToken` (20B) + `address outputToken` (20B) + `uint256 inputAmount` (32B) + `uint256 outputMin` (32B) + `bool usePrevHookAmount` (1B) + `uint256 txDataLength` (32B) + `bytes txData_` (variable)

### Files to Create
- `src/vendor/kyberswap/IMetaAggregationRouterV2.sol`
- `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol`
- `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol`
- `test/mocks/MockKyberSwapRouter.sol`
- `test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol`
- `test/integration/kyberswap/KyberSwapIntegration.t.sol`

## Implementation Plan

### Phase 1: Foundation
- [ ] Verify exact `SwapExecutionParams` struct field ordering from Etherscan verified source
- [ ] Create `IMetaAggregationRouterV2.sol` vendor interface
- [ ] Create `MockKyberSwapRouter.sol`

### Phase 2: Hook Implementation
- [ ] Implement `SwapKyberSwapHook.sol` (swap-only variant)
- [ ] Implement `ApproveAndSwapKyberSwapHook.sol` (approve + swap variant)
- [ ] Implement `_updateTxDataAmounts()` for usePrevHookAmount support

### Phase 3: Testing
- [ ] Unit tests with mock router
- [ ] Fork-based integration tests against live KyberSwap router

### Phase 4: Deployment (future)
- [ ] Add KyberSwap router addresses to deployment configuration
- [ ] Add availability flags and deployment logic to `DeployV2Core.s.sol`

## Test Plan
- [ ] Unit tests for: constructor validation, build() execution count, usePrevHookAmount, pre/post execute balance tracking, inspect(), approval sequence, decodeUsePrevHookAmount
- [ ] Integration tests for: real swap on mainnet fork via KyberSwap router
- [ ] Edge cases: zero amounts, native ETH, fee-on-transfer tokens, large swaps

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Lingering token approval | Token Behavior | Low | Critical | approve(0)->approve(n)->swap->approve(0) pattern | LI.FI 2024 - $11.6M |
| Calldata manipulation | Business Logic | Low | High | Balance delta tracking + inspect() for off-chain validation | SwapNet 2025 - $16.8M |
| Router proxy upgrade | Operational | Low | High | Approval window is single-tx atomic; document trust assumption | N/A |
| Struct field ordering mismatch | Operational | Medium | Medium | Verify from Etherscan before implementation | N/A |
| KyberSwap pool exploit | Business Logic | Low | Medium | Hook uses aggregator (not pools directly); minReturnAmount enforced | KyberSwap Elastic 2023 - $47M |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Router version? | MetaAggregationRouterV2 | User |
| Hook variants? | Both (SwapOnly + ApproveAndSwap) | User |
| Chains? | All where KyberSwap available | User |
| Native ETH? | Yes | User |
| Referral system? | Include via clientData field (API-level, not on-chain param) | Research |
| Data layout? | Optimized for KyberSwap (1inch raw calldata pattern) | User + Research |
| Slippage? | Explicit params in hook data for scaling | User |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/kyberswap-hook/technical-spec.md`
