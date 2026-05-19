# Stargate Native Fee Sponsorship — Interview Notes

**Date:** 2026-05-15
**Interviewer:** Claude (AI)
**Interviewee:** Cosmin (Pod Lead)

---

## Feature Summary

Support Stargate V2 bridge hooks that require native tokens (`msg.value`) for LayerZero messaging fees. The bundler sponsors native ETH atomically during ERC-4337 UserOp execution. The smart account should not need to hold native tokens before execution.

## Source Spec

Notion document: "Stargate Native Fee Sponsorship in Bundler" — describes 3 on-chain components and bundler integration.

## Existing Context

- **StargateSendHook** exists on PR #885 (`feat/cctp-bridge-hook`). It sends `lzNativeFee + amountLD` as `msg.value` to the Stargate pool.
- **SuperNativePaymaster** exists at `src/paymaster/SuperNativePaymaster.sol` — current bundler gas wrapper for ERC-4337.
- **SuperSponsorshipPaymaster** exists at `src/paymaster/SuperSponsorshipPaymaster.sol` — per-strategy gas budgets (separate concern, already deployed on Base).

---

## Technical Decisions

### 1. Paymaster Modification Approach
**Decision:** Option A — Pass sponsorship address as a function parameter in `sponsorNativeAndHandleUserOp`. No constructor change, no paymaster redeployment needed.

**Rationale:** Avoids redeploying SuperNativePaymaster on all chains. Slightly higher gas per call but much simpler operationally.

### 2. Access Control on NativeFeeSponsorship
**Decision:** Fully permissionless. Anyone can call `depositForAccount`. Open balance model.

**Rationale:** Matches the spec's open balance philosophy. The mapping key `(sponsor, account)` provides sufficient isolation. Only the account can withdraw (via `msg.sender`), only the sponsor can reclaim.

### 3. Chain Deployment
**Decision:** Deploy on ALL Superform chains.

**Rationale:** Even if Stargate V2 isn't on every chain today, the sponsorship mechanism is generic and could be used for any native-fee-requiring bridge in the future.

### 4. Hook Sponsorship Address
**Decision:** Immutable constructor parameter.

**Rationale:** More secure — the hook always targets the same NativeFeeSponsorship contract. Hook data is simpler: only `(sponsor, amount)` = 52 bytes.

### 5. Bundler Authorization
**Decision:** Permissionless — anyone can call `sponsorNativeAndHandleUserOp`, consistent with existing `handleOps`.

### 6. Stargate Hook Scope
**Decision:** Stargate hook is a separate workstream (PR #885). This spec covers ONLY NativeFeeSponsorship, FetchNativeFeeHook, and paymaster changes.

### 7. Emergency Mechanism
**Decision:** Minimal — no Pausable, no admin functions. Pure ledger contract.

### 8. Orphaned Deposit Handling
**Decision:** Sponsor reclaims manually via `withdrawSponsorDeposit`. No time-based expiry.

**Accepted risk:** If inner UserOp execution reverts (ERC-4337 still charges gas, postOp runs), the sponsorship deposit stays. Bundler reclaims via separate transaction.

### 9. Atomicity Model
**Decision:** Accept orphan risk. If UserOp inner call fails, deposit stays in sponsorship. Bundler reclaims manually.

**Note:** The sponsorship deposit happens BEFORE `entryPoint.handleOps`. If `handleOps` reverts entirely (e.g., validation failure), the whole tx reverts including the deposit. But if the inner call execution fails (ERC-4337 still processes postOp), the deposit persists.

### 10. Batch Support
**Decision:** Design for batch from the start. Use a struct-based deposits array independent of ops:
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
One deposit entry per unique account needing sponsorship. Reduces calldata for same-sender batches (most common case).

**Rationale:** Most handleOps calls have one sender, so a parallel `uint256[]` array would be mostly zeros. The struct approach is more explicit and gas-efficient.

### 11. Native Fee Scope
**Decision:** FetchNativeFeeHook sponsors ONLY the `lzNativeFee` (LayerZero messaging fee), NOT the `amountLD` (bridged amount). Smart account must hold native ETH for `amountLD` separately (e.g., via WETH unwrap hook before the Stargate hook).

### 12. Reentrancy Protection
**Decision:** OpenZeppelin's `ReentrancyGuard` is sufficient on NativeFeeSponsorship. Cross-contract reentrancy during ETH transfer to smart accounts is not a concern because smart accounts (Nexus/Safe) are trusted.

### 13. Testing Strategy
**Decision:** Unit tests + mainnet fork integration tests. Fork tests should use real Stargate V2 contracts to validate the full flow: paymaster -> sponsorship -> FetchNativeFeeHook -> StargateSendHook.

---

## Acceptance Criteria

### Core Contracts
- [ ] NativeFeeSponsorship contract deployed with mapping(sponsor => mapping(account => amount))
- [ ] depositForAccount correctly credits sponsoredNative[sponsor][account]
- [ ] withdrawSponsoredNative correctly debits and transfers ETH to msg.sender (account)
- [ ] withdrawSponsorDeposit correctly debits and transfers ETH to specified recipient
- [ ] All mutating functions have ReentrancyGuard
- [ ] All mutating functions follow Checks-Effects-Interactions pattern

### Hook
- [ ] FetchNativeFeeHook is NONACCOUNTING with immutable SPONSORSHIP address
- [ ] Hook data: (address sponsor, uint256 amount) = 52 bytes packed
- [ ] _buildHookExecutions returns single Execution calling withdrawSponsoredNative
- [ ] Hook validates: sponsor != address(0), amount > 0, data length >= 52

### Paymaster
- [ ] sponsorNativeAndHandleOps accepts (PackedUserOperation[] ops, uint256[] nativeAmounts)
- [ ] Validates nativeAmounts.length == ops.length
- [ ] Validates sum(nativeAmounts) <= msg.value
- [ ] Deposits each nativeAmount into NativeFeeSponsorship for corresponding op.sender
- [ ] Remaining msg.value goes to EntryPoint gas deposit
- [ ] handleOps reverts propagate correctly (atomic with gas deposit)
- [ ] Existing handleOps function unchanged and still works

### Security
- [ ] No reentrancy vulnerabilities in NativeFeeSponsorship
- [ ] Sponsor can only withdraw own deposits
- [ ] Account can only withdraw deposits made for it
- [ ] ETH transfer failures revert with clear errors
- [ ] Zero-address and zero-amount checks on all functions

### Testing
- [ ] Unit tests for NativeFeeSponsorship (deposit, withdraw, reclaim, edge cases)
- [ ] Unit tests for FetchNativeFeeHook (constructor, build, data validation)
- [ ] Unit tests for paymaster sponsorNativeAndHandleOps
- [ ] Fork integration test: full flow with Stargate V2

---

## Security Concerns Discussed

1. **Race condition between sponsor reclaim and account withdrawal** — Accepted tradeoff. Atomic `sponsorNativeAndHandleOps` mitigates for normal flow.
2. **Orphaned deposits on inner call revert** — Bundler reclaims manually. No automated cleanup.
3. **Overfetch** — If hook withdraws more than needed, excess stays on smart account. Bundler's responsibility to quote correctly.
4. **Cross-contract reentrancy** — Not a concern for trusted smart accounts (Nexus/Safe).
5. **ERC-4337 postOp gas charging** — Sponsorship deposit is not affected by postOp; it's a separate ledger.

---

## Open Questions (Resolved)

| Question | Answer | Decided By |
|----------|--------|------------|
| Constructor change vs parameter? | Parameter approach (no redeployment) | Cosmin |
| Access control on deposits? | Fully permissionless | Cosmin |
| Which chains? | All Superform chains | Cosmin |
| Hook immutable vs data? | Immutable constructor param | Cosmin |
| Include Stargate hook? | Separate (PR #885) | Cosmin |
| Emergency pause? | No — minimal | Cosmin |
| Orphan handling? | Manual sponsor reclaim | Cosmin |
| Atomicity model? | Accept orphan risk | Cosmin |
| Batch support? | Yes — array of amounts | Cosmin |
| Native scope? | Only lzNativeFee, not amountLD | Cosmin |
| Reentrancy model? | ReentrancyGuard sufficient | Cosmin |
| Testing? | Unit + fork integration | Cosmin |
