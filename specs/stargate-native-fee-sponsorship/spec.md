# Stargate Native Fee Sponsorship Spec

## Metadata
- Project: Superform v2-core
- Milestone: Stargate V2 Integration
- Linear Issue: N/A
- Interview Date: 2026-05-15
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Enable the Superform bundler to sponsor native ETH for smart accounts that need it for Stargate V2 / LayerZero messaging fees during ERC-4337 UserOp execution. The smart account does not need to hold native tokens before execution.

Three on-chain components: a standalone ETH sponsorship ledger (`NativeFeeSponsorship`), a withdrawal hook (`FetchNativeFeeHook`), and a new paymaster function (`sponsorNativeAndHandleOps`). The bundler deposits the messaging fee into the ledger, then the smart account withdraws it via hook during UserOp execution, atomically preceding the Stargate bridge hook.

## Requirements

### Functional
1. NativeFeeSponsorship: ETH ledger with `mapping(sponsor => mapping(account => uint256))` — deposit, account withdrawal, sponsor reclaim
2. FetchNativeFeeHook: NONACCOUNTING hook with immutable SPONSORSHIP address, withdraws sponsored ETH to smart account
3. SuperNativePaymaster: New `sponsorNativeAndHandleOps(ops, deposits, sponsorship)` — deposits sponsorship + handles ops atomically
4. Batch support: `NativeFeeDeposit[]` struct array (account + amount) independent of ops — one entry per unique sender needing sponsorship
5. Only sponsors `lzNativeFee` (LayerZero messaging fee), NOT `amountLD` (bridged amount)

### Non-Functional
- Deploy on ALL Superform chains (mechanism is generic, not Stargate-specific)
- No access control — fully permissionless open balance model
- No admin functions, no Pausable — pure ledger contract
- Existing `handleOps` function unchanged (backward compatible)

## Technical Design

### Architecture

```
Bundler → SuperNativePaymaster.sponsorNativeAndHandleOps()
              │
              ├── NativeFeeSponsorship.depositForAccount(bundler, smartAccount)
              ├── EntryPoint.deposit (gas funds)
              └── EntryPoint.handleOps()
                    │
                    └── UserOp execution chain:
                          ├── FetchNativeFeeHook → NativeFeeSponsorship.withdrawSponsoredNative()
                          └── StargateSendHook → Stargate pool
```

### Data Model

**NativeFeeSponsorship:**
```solidity
mapping(address sponsor => mapping(address account => uint256 amount)) public sponsoredNative;
```

**FetchNativeFeeHook data:** `abi.encodePacked(address sponsor, uint256 amount)` — 52 bytes

### API Changes

New paymaster function (no constructor change — Option A):
```solidity
struct NativeFeeDeposit {
    address account;
    uint256 amount;
}

function sponsorNativeAndHandleOps(
    PackedUserOperation[] calldata ops,
    NativeFeeDeposit[] calldata deposits,
    address sponsorship
) external payable;
```
`deposits` array is independent of `ops` — one entry per unique sender needing sponsorship, reducing calldata for same-sender batches.

## Implementation Plan

### Phase 1: Core Contracts
- [ ] `src/interfaces/INativeFeeSponsorship.sol` — Interface with errors, events, functions
- [ ] `src/sponsorship/NativeFeeSponsorship.sol` — Ledger contract with ReentrancyGuard + CEI
- [ ] `test/unit/sponsorship/NativeFeeSponsorshipTest.t.sol` — Unit tests

### Phase 2: Hook
- [ ] `src/hooks/sponsorship/FetchNativeFeeHook.sol` — NONACCOUNTING hook, TOKEN subtype
- [ ] `test/unit/hooks/sponsorship/FetchNativeFeeHookTest.t.sol` — Unit tests

### Phase 3: Paymaster
- [ ] `src/interfaces/ISuperNativePaymaster.sol` — Add new function, errors, events
- [ ] `src/paymaster/SuperNativePaymaster.sol` — Add `sponsorNativeAndHandleOps`
- [ ] `test/unit/paymaster/SuperNativePaymasterSponsorshipTest.t.sol` — Unit tests

### Phase 4: Deployment
- [ ] `script/utils/ConstantsOtherHooks.sol` — Add hook key constants
- [ ] `script/DeployV2OtherHooks.s.sol` — Add deployment function
- [ ] `script/run/regenerate_bytecode.sh` — Add bytecode generation
- [ ] `script/run/deploy_v2_other_hooks_staging_prod.sh` — Add chain support

## Test Plan
- [ ] Unit tests for: NativeFeeSponsorship (deposit, withdraw, reclaim, edge cases, events)
- [ ] Unit tests for: FetchNativeFeeHook (constructor, build, data validation, inspect)
- [ ] Unit tests for: SuperNativePaymaster sponsorNativeAndHandleOps (batch, atomicity, backward compat)
- [ ] Integration tests for: Full flow paymaster → sponsorship → FetchNativeFeeHook → StargateSendHook (mainnet fork)
- [ ] Invariant: `sum(deposits) - sum(withdrawals) == contract.balance`

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Orphaned deposits on inner call revert | Business Logic | Medium | Low | Sponsor reclaims manually via `withdrawSponsorDeposit` | N/A — novel pattern |
| Race between sponsor reclaim and account withdrawal | Business Logic | Low | Low | Atomic `sponsorNativeAndHandleOps` mitigates normal flow | N/A |
| Overfetch (hook withdraws more than Stargate needs) | Operational | Low | Low | Excess stays on smart account; bundler quotes correctly | N/A |
| Reentrancy on ETH transfers | Reentrancy | Low | High | ReentrancyGuard + CEI pattern | Standard DeFi practice |
| ETH transfer failure to smart account | Operational | Very Low | Medium | Revert with `ETH_TRANSFER_FAILED`; Nexus/Safe accept ETH | N/A |
| Locked bytecode requires paymaster redeployment | Operational | High | Low | Same constructor, new deployment; update registry | Standard Superform process |

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| Constructor change vs parameter? | Parameter approach — Option A (no constructor change) | Cosmin |
| Access control on deposits? | Fully permissionless | Cosmin |
| Which chains? | All Superform chains | Cosmin |
| Hook immutable vs data? | Immutable constructor param for SPONSORSHIP | Cosmin |
| Include Stargate hook? | Separate workstream (PR #885) | Cosmin |
| Emergency pause? | No — minimal, pure ledger | Cosmin |
| Orphan handling? | Manual sponsor reclaim | Cosmin |
| Atomicity model? | Accept orphan risk on inner call revert | Cosmin |
| Batch support? | Yes — NativeFeeDeposit[] struct (account+amount), independent of ops | Cosmin |
| Native scope? | Only lzNativeFee, not amountLD | Cosmin |
| Reentrancy model? | ReentrancyGuard + CEI sufficient | Cosmin |
| Testing? | Unit + fork integration | Cosmin |
| HookSubType? | TOKEN | Cosmin |
| Deposits array shape? | Struct (account+amount), independent of ops array | Cosmin |

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
After approval, run: `/superform:work specs/stargate-native-fee-sponsorship/technical-spec.md`
