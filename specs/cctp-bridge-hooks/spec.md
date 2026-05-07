# CCTP V2 Bridge Hooks Spec

## Metadata
- Project: Superform V2 Core
- Milestone: Bridge Hook Expansion
- Linear Issue: N/A
- Interview Date: 2026-05-05
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Build an `ApproveAndCCTPSendHook` for cross-chain USDC transfers using Circle's CCTP V2 burn-and-mint protocol. The hook calls `TokenMessengerV2.depositForBurnWithHook()` on the source chain to burn USDC with optional destination execution data (validator-signed hookCallData). CCTP V2 guarantees 1:1 minting on the destination chain with no slippage, supports fast finality (8-20 sec), and is deployed on all Superform-supported chains.

This follows the same pattern as existing Stargate and Across bridge hooks but is simpler: no native ETH variant needed (USDC is always ERC20), no msg.value required (fees deducted from amount), and no proportional min-amount scaling (1:1 guaranteed).

## Requirements

### Functional
1. Single hook: `ApproveAndCCTPSendHook` with constructor `(address tokenMessenger, address validator)`
2. 4-execution approve pattern: approve(0) → approve(amount) → depositForBurnWithHook → approve(0)
3. All execution values = 0 (no native ETH needed)
4. Packed data layout with BytesLib decoding (157 bytes minimum + variable hookCallData)
5. `usePrevHookAmount` support for chaining from prior hooks
6. Validator signature appended to hookCallData for destination execution
7. `inspect()` returns burnToken + mintRecipient addresses only
8. Validates: burnToken != 0, mintRecipient != bytes32(0), amount != 0

### Non-Functional
- Gas-efficient packed data decoding
- Follows existing hook patterns exactly (Stargate/Across reference)
- Comprehensive unit tests (~25 tests) + fork test against mainnet

## Technical Design

### Architecture

```
src/vendor/bridges/cctp/ITokenMessengerV2.sol  (NEW - interface)
src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol  (NEW - main hook)
test/unit/hooks/bridges/CCTPHooks.t.sol  (NEW - tests)
```

Constructor args:
- `tokenMessenger_`: TokenMessengerV2 at `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` (same all chains)
- `validator_`: SuperValidator address (for signature retrieval)

### Data Model

Packed bytes layout:
```
[0:20]   address burnToken          - USDC on source chain
[20:52]  uint256 amount             - Amount to burn
[52:56]  uint32  destinationDomain  - CCTP domain ID (NOT chain ID)
[56:88]  bytes32 mintRecipient      - Recipient on destination
[88:120] bytes32 destinationCaller  - Restrict relay caller
[120:152] uint256 maxFee            - Max fee (deducted from amount)
[152:156] uint32  minFinalityThreshold - Fast (<2000) or standard (>=2000)
[156:157] bool   usePrevHookAmount  - Use prev hook output
[157:189] uint256 hookCallDataLen   - Length of variable hookCallData
[189:...]  bytes  hookCallData      - Destination execution payload
```

### API Changes

New interface: `ITokenMessengerV2.depositForBurnWithHook()`
```solidity
function depositForBurnWithHook(
    uint256 amount, uint32 destinationDomain, bytes32 mintRecipient,
    address burnToken, bytes32 destinationCaller, uint256 maxFee,
    uint32 minFinalityThreshold, bytes memory hookData
) external returns (bytes memory);
```

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `ITokenMessengerV2.sol` interface
- [ ] Create `ApproveAndCCTPSendHook.sol` hook contract
- [ ] Create `CCTPHooks.t.sol` unit tests
- [ ] Run tests and verify all pass

### Phase 2: Deployment Integration
- [ ] Add hook key constant to `Constants.sol`
- [ ] Add to `DeployV2Core.s.sol` (index 64, array length 65)
- [ ] Add to `regenerate_bytecode.sh`
- [ ] Generate and lock bytecode

## Test Plan
- [ ] Unit tests for: constructor validation, data decoding, approval pattern, hookCallData signature, prevHookAmount, inspect, revert conditions, fuzz amounts/domains (~25 tests)
- [ ] Fork test for: real TokenMessengerV2 on Ethereum mainnet
- [ ] Build verification: `forge build` succeeds with no errors

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Zero mintRecipient burns USDC permanently | Logic | Low | Critical | Validate mintRecipient != bytes32(0) | N/A |
| Circle attestation service downtime | Operational | Low | High | Outside hook scope, systemic risk | N/A |
| USDC blocklist blocks user's transfer | Token Behavior | Low | Medium | Transaction reverts gracefully | N/A |
| Incorrect TokenMessengerV2 address | Operational | Low | Critical | Verified via Etherscan, CREATE2 deterministic | N/A |
| hookCallData format mismatch with bundler | Cross-Chain | Medium | High | Use same ABI format as Stargate/Across | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| One hook or two? | One (ApproveAndCCTPSendHook only) | Interview — USDC is always ERC20 |
| depositForBurn or depositForBurnWithHook? | depositForBurnWithHook | Research — CCTP V2 supports native hookData |
| Parameter name? | maxFee (not maxBurnAmountPerMessage) | Circle docs verification |
| TokenMessengerV2 address? | 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d | Etherscan verification |
| maxFee validation at hook level? | No — defer to TokenMessengerV2 | Consistent with Stargate pattern |
| hookCallData wire format? | Same as Stargate/Across (5-tuple + signature) | Pattern consistency |

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
After approval, run: `/superform:work specs/cctp-bridge-hooks/technical-spec.md`
