# Morpho Force Deallocate Hook - Interview Notes

**Date:** 2026-05-21
**Interviewer:** Claude
**Interviewee:** Cosmin G.

---

## Feature Summary

Create a `ForceDeallocateMorphoHook` (and `ApproveAndForceDeallocateMorphoHook`) for Morpho Vault V2. The `forceDeallocate` function is a V2-only feature that allows permissionless extraction of assets from an adapter back to the vault's idle balance, with a penalty mechanism (up to 2%).

## Requirements

### Target Architecture
- **Morpho Vault V2 only** — not for MetaMorpho V1/V1.1
- V2 uses an adapter-based architecture (vs V1's market-based `reallocate()`)
- The "single liquidity adapter" is a V2 limitation/feature

### Use Case
- **Emergency extraction** — pulling funds from compromised or underperforming adapters quickly
- Not routine rebalancing (that's what `reallocate` is for)

### Deployment Chains
- Same as existing Morpho hooks: **Ethereum, Base, Optimism, Arbitrum, BNB**

## Technical Decisions

### Hook Type
- **NONACCOUNTING** — no tokens leave the smart account, just internal vault rebalancing (assets move from adapter to vault idle)
- Similar pattern to `MetaMorphoReallocateHook`

### Access Control
- **Smart account owner only** — standard hook triggered via UserOp
- No additional access control beyond standard Superform validation

### Variants
- **Both base + approve** variants:
  - `ForceDeallocateMorphoHook` (base)
  - `ApproveAndForceDeallocateMorphoHook` (with approval)

### Penalty Mechanism
- forceDeallocate charges a penalty (up to 2%) based on remaining time in a timelock window
- **Add `maxPenaltyBps` parameter** — revert if penalty exceeds the user's tolerance
- This protects against executing when penalty is unexpectedly high

### Deadline Protection
- **Add `deadline` parameter** — revert if `block.timestamp > deadline`
- Prevents stale execution that could result in different penalty than expected

### onBehalf Parameter
- **Always `msg.sender`** (the smart account) — no configurable `onBehalf`
- Safest approach: always deallocate on behalf of the executing smart account

## Security Decisions

### Reentrancy
- **Trust vault's guards** — Morpho Vault V2 has its own reentrancy protection
- The vault calls `adapter.deallocate()` which could be arbitrary code, but Morpho handles this internally
- No additional `ReentrancyGuard` on our hook

### MEV/Timing Risk
- Penalty is deterministic based on timelock state
- Deadline parameter mitigates stale execution
- maxPenaltyBps mitigates unexpected penalty changes between signing and execution

### Token Compatibility
- forceDeallocate moves the vault's underlying asset — whatever token the Vault V2 uses
- No special token handling needed in the hook (vault handles token transfers internally)

## Testing Strategy

### Approach
- **Fork mainnet** — test against real Morpho Vault V2 deployments on Ethereum/Base
- No mocks — test with real contracts

### Key Test Cases
- Successful forceDeallocate with penalty within tolerance
- Revert when penalty exceeds maxPenaltyBps
- Revert when deadline has passed
- Revert when vault address is invalid
- Integration with Superform execution flow

## Interface

- **Research and create** the Vault V2 interface (`IMorphoVaultV2.sol`)
- Need to find the exact function signature from Morpho's repositories

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| V1 or V2? | V2 only | Cosmin |
| Emergency or routine? | Emergency extraction | Cosmin |
| ACCOUNTING or NONACCOUNTING? | NONACCOUNTING | Cosmin |
| Approve variant? | Both base + approve | Cosmin |
| Penalty validation? | maxPenaltyBps parameter | Cosmin |
| Reentrancy guard? | Trust vault's guards | Cosmin |
| Deadline? | Yes, add deadline parameter | Cosmin |
| onBehalf configurable? | No, always msg.sender | Cosmin |
| Testing approach? | Fork mainnet | Cosmin |
| Interface source? | Research from Morpho repos | Cosmin |
