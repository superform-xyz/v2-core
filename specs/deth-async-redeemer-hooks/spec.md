# DETH Async Redeemer Hooks Spec

## Metadata
- Project: Superform v2-core
- Milestone: DETH Exit Strategy
- Linear Issue: N/A
- Interview Date: 2026-05-11
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Build 3 custom hooks to interact with Dialectic's DETH AsyncRedeemer on Ethereum mainnet. DETH (Dialectic ETH Vault) is a leveraged wstETH/WETH loop strategy on Aave V3 with zero DEX liquidity, requiring direct interaction with the AsyncRedeemer for position exit. The AsyncRedeemer uses a two-phase async flow: request (burns DETH, mints ERC-721 NFT receipt) → Dialectic keeper finalizes (~12h) → claim (burns NFT, sends WETH).

Three hooks follow the Firelight/Ethena two-phase pattern: `RequestRedeemDETHHook` (NONACCOUNTING), `ApproveAndRequestRedeemDETHHook` (NONACCOUNTING with zero-set-execute-zero approval), and `ClaimAssetsDETHHook` (OUTFLOW). PPS tracking during the async redemption period will be handled off-chain for now (oracle to follow separately).

## Requirements

### Functional
1. `RequestRedeemDETHHook` calls `requestRedeem(shares, account, minAssets)` on AsyncRedeemer, tracking DETH balance delta via `usedShares`
2. `ApproveAndRequestRedeemDETHHook` approves DETH to AsyncRedeemer (zero-exact-execute-zero), then calls `requestRedeem`
3. `ClaimAssetsDETHHook` calls `claimAssets(requestId)` on AsyncRedeemer, tracking WETH balance delta via `outAmount`
4. All hooks support `usePrevHookAmount`, `inspect()`, and `decodeAmount()`
5. `minAssets` slippage encoded in hookData (set by Fair Pricing Service off-chain)
6. `requestId` for claim encoded in hookData by off-chain keeper

### Non-Functional
- No modifications to existing files
- Pragma `0.8.30`, NatSpec, ERC4626 HookSubType
- Mainnet fork integration tests against real AsyncRedeemer

## Technical Design

### Architecture

```
RequestRedeemDETHHook (NONACCOUNTING)
  ├── Discovers DETH via asyncRedeemer.machine().shareToken()
  ├── Builds: [preExecute, requestRedeem, postExecute]
  └── Tracks: usedShares = DETH balance delta

ApproveAndRequestRedeemDETHHook (NONACCOUNTING)
  ├── DETH token address in hookData (for approve calls)
  ├── Builds: [preExecute, approve(0), approve(shares), requestRedeem, approve(0), postExecute]
  └── Tracks: outAmount = DETH balance delta

ClaimAssetsDETHHook (OUTFLOW)
  ├── Discovers WETH via asyncRedeemer.machine().accountingToken()
  ├── Builds: [preExecute, claimAssets, postExecute]
  └── Tracks: outAmount = WETH balance delta (usedShares intentionally NOT set)
```

### Data Model

No new storage. All hooks are stateless (view for build, transient for pre/post execute).

Custom hookData layouts with `minAssets` parameter for request hooks and `requestId` for claim hook.

### New Files

| File | Type |
|------|------|
| `src/vendor/vaults/deth/IDETHAsyncRedeemer.sol` | Interface (`requestRedeem`, `claimAssets`, `machine`) |
| `src/vendor/vaults/deth/IMachine.sol` | Interface (`shareToken`, `accountingToken`) |
| `src/hooks/vaults/deth/RequestRedeemDETHHook.sol` | Hook (NONACCOUNTING) |
| `src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol` | Hook (NONACCOUNTING) |
| `src/hooks/vaults/deth/ClaimAssetsDETHHook.sol` | Hook (OUTFLOW) |
| `test/integration/deth/DETHAsyncRedeemerHooksE2E.t.sol` | Mainnet fork tests |

## Implementation Plan

### Phase 1: Interfaces
- [ ] Create `IDETHAsyncRedeemer.sol` with `requestRedeem`, `claimAssets`, `machine`
- [ ] Create `IMachine.sol` with `shareToken`, `accountingToken`

### Phase 2: Hooks
- [ ] Implement `RequestRedeemDETHHook` (NONACCOUNTING, ERC4626)
- [ ] Implement `ApproveAndRequestRedeemDETHHook` (NONACCOUNTING, ERC4626)
- [ ] Implement `ClaimAssetsDETHHook` (OUTFLOW, ERC4626)

### Phase 3: Tests
- [ ] Mainnet fork integration tests (16 test cases)
- [ ] Full E2E flow: approve → request → warp → finalize → claim

## Test Plan
- [ ] Integration tests for: requestRedeem (basic, usedShares, zero revert, usePrevHookAmount), approveAndRequestRedeem (basic, zero allowance after, usePrevHookAmount), claimAssets (basic, outAmount, NFT burned, not finalized, usedShares=0), inspect, full E2E flow
- [ ] All tests via mainnet fork against real AsyncRedeemer at `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F`

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Dialectic changes/removes whitelist | Access Control | Low-Medium | Medium | Off-chain monitoring, revert is safe | — |
| BeaconProxy upgrade changes semantics | Proxy/Upgrade | Low | High | Interface-based interaction, balance delta tracking | AllianceBlock 2024 |
| No cancel — DETH locked until finalization | Operational | Low | Medium | Trust assumption on Dialectic, documented | Lido withdrawal design |
| finalizationDelay extended by Dialectic | Operational | Low | Medium | Off-chain monitoring | — |
| ERC-721 onERC721Received callback | Reentrancy | Low | Low | BaseHook transient mutex prevents reentry | Revert Lend 2024 |
| DETH 12-decimal precision in off-chain systems | Token Behavior | Medium | Medium | Document prominently for off-chain integrators | — |
| minAssets set too low by Fair Pricing Service | Business Logic | Medium | Medium | FPS must validate PPS; no spot market reference | — |
| PPS recalculated at finalization time | Vault Accounting | Certain | Low | minAssets provides floor; bounded by Aave oracle | Lido finalization rate |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Approval strategy? | Both hooks (with and without approve) | User |
| minAssets source? | Encoded in hookData by Fair Pricing Service | User |
| requestId source? | Encoded in hookData by off-chain keeper | User |
| HookSubType? | ERC4626 (Firelight precedent) | User |
| Test strategy? | Mainnet fork only | User |
| Approve target? | DETH token approved to AsyncRedeemer (confirmed from source) | Verified |
| Oracle scope? | Hooks only for now; oracle separately later | User |
| Cancel support? | CancelationType.NONE (no cancel exists) | Verified from source |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)
- [repo-analysis.md](./research/repo-analysis.md) — Hook patterns, base class, conventions
- [best-practices.md](./research/best-practices.md) — NFT receipt patterns, approval safety, balance deltas
- [framework-docs.md](./research/framework-docs.md) — Foundry fork testing patterns
- [evm-security.md](./research/evm-security.md) — Vulnerability analysis, exploit precedents

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/deth-async-redeemer-hooks/technical-spec.md`
