# CCTP Destination Adapter Spec

## Metadata
- Project: Superform v2-core
- Milestone: Cross-chain bridge adapters
- Linear Issue: N/A
- Interview Date: 2026-08-13
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary
The CCTP V2 send side is already shipped (`CCTPSendHook`/`ApproveAndCCTPSendHook` → `TokenMessengerV2.depositForBurnWithHook`, packing the executor payload into `hookData`), but there is no destination adapter — so CCTP can only deliver USDC, not run Superform's destination hooks (deposit-after-bridge). This spec adds `CCTPAdapter`, the destination receiver, mirroring the V2 adapter template (`RelayAdapter`/`AcrossV3AdapterV2`).

The one structural difference from every existing adapter: **CCTP has no push callback.** `MessageTransmitterV2.receiveMessage` only mints to `mintRecipient`; it never forwards `hookData`. So the adapter is *pull-driven* — a permissionless relayer calls `receiveAndExecute(message, attestation)`, the adapter calls `receiveMessage` itself, slices `hookData` from the attested message, funds the account with the exact mint delta, and calls `SuperDestinationExecutor.processBridgedExecution` (the identical terminal call all adapters make).

## Requirements

### Functional
1. `receiveAndExecute(bytes message, bytes attestation)` — permissionless, `nonReentrant`: fail-fast checks → `receiveMessage` (mint) → forward mint **delta** to the decoded `account` → `try/catch` `processBridgedExecution` with the 6-field payload.
2. Decode `hookData = message[376:]` as `(bytes initData, bytes executorCalldata, address account, address[] dstTokens, uint256[] intentAmounts, bytes signature)`.
3. `claimFailedTransfer(account, token)` escrow path for recipients that reject the USDC transfer (blacklist/pause).
4. New vendor interface `IMessageTransmitterV2.receiveMessage(bytes,bytes) returns (bool)`.
5. Backend sets the send hook's `mintRecipient` **and** `destinationCaller` to the destination adapter (config-only; no hook change).

### Non-Functional
- Trust-minimized: verification fully delegated to Circle's transmitter + the executor's EIP-1271 signature/Merkle-root replay checks; no home-grown verification, no approvals, no arbitrary calls from adapter context.
- Donation-proof accounting: forward `balanceOf(this)` **delta** only; adapter net balance returns to baseline each call.
- Matches repo conventions (Apache-2.0, pragma 0.8.30, custom errors, SafeERC20, ReentrancyGuard, NatSpec).

## Technical Design

### Architecture
```
source: CCTPSendHook → TokenMessengerV2.depositForBurnWithHook
        (mintRecipient = destinationCaller = CCTPAdapter; hookData = executor payload)
Circle attests
dest:   relayer → CCTPAdapter.receiveAndExecute(message, attestation)
          require(len>=376); require(mintRecipient==this)
          pre = USDC.balanceOf(this); receiveMessage(...) [mints amount-fee]; minted = post-pre
          decode message[376:]; _tryTransfer(account, minted)  → escrow on failure
          try SuperDestinationExecutor.processBridgedExecution(USDC, account, dstTokens, intentAmounts, initData, executorCalldata, sig) catch { emit ExecutionFailed }
```

### Data Model
- Immutables: `MESSAGE_TRANSMITTER`, `USDC`, `SUPER_DESTINATION_EXECUTOR`.
- Storage: `mapping(account => mapping(token => uint256)) failedTransfers` (escrow only).
- Offset constants: header 148, `mintRecipient` @184, hookData @376.

### API Changes
- New: `src/adapters/CCTPAdapter.sol`, `src/vendor/bridges/cctp/IMessageTransmitterV2.sol`.
- `DeployV2Core.s.sol`: adapter struct field + availability bool + `configuration.messageTransmittersV2[chain]` (+ per-chain USDC + executor), CREATE2 deploy, `_checkAdapterContracts`, `Constants.sol` key, locked-bytecode artifact. Not in `hook-sizing-manifest.json` (adapters aren't hooks).

## Implementation Plan

### Phase 1: Contract + interface
- [ ] Vendor `IMessageTransmitterV2` (cross-check vs `lib/pigeon`).
- [ ] `CCTPAdapter` on the `RelayAdapter`/`AcrossV3AdapterV2` template (guard, SafeERC20, `_tryTransfer`, `failedTransfers`, `try/catch`).
- [ ] Assert offsets (184/216/312/376) against Circle `MessageV2`/`BurnMessageV2`.

### Phase 2: Tests
- [ ] `CCTPAdapterE2EFork.t.sol` using `lib/pigeon` `CctpV2Helper` (attester mock) — happy path (mint delta forwarded + vault deposit runs).
- [ ] 17 negative/fuzz cases + offset unit test + 6 invariants.

### Phase 3: Deploy wiring
- [ ] `DeployV2Core` struct/availability/config/check + `Constants.sol` key + locked bytecode.
- [ ] Coordinate OMS to set `mintRecipient`/`destinationCaller` = adapter per destination chain.

## Test Plan
- [ ] Unit tests for: byte-offset slicing, `_tryTransfer` fallback, `claimFailedTransfer`, constructor zero-checks.
- [ ] Integration (fork) tests for: full mint→fund→execute path; used-root no-op; executor-revert → `ExecutionFailed`; blacklisted recipient → escrow+claim.
- [ ] Fuzz/invariant: donation-proof delta (INV-2), baseline balance (INV-1), exact delivery = `amount−feeExecuted` (INV-3), replayed message reverts (INV-5), used root delivers-but-no-ops (INV-6).

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Donated/pre-seeded USDC swept to attacker account | Vault Accounting | Med | High | Forward measured `post−pre` delta only; INV-2 | deBridge/Across sweep class |
| Blacklisted/reverting `account` strands the burn | Token Behavior | Med | Med | `_tryTransfer` → `failedTransfers` escrow + `claimFailedTransfer` | USDC blocklist DoS (10.5) |
| Malformed/truncated hookData | Business Logic | Low | Med | `require(len>=376)`; bounds-checked `abi.decode` | — |
| Cross-transport intent replay | Cross-Chain | Low | High | executor `usedMerkleRoots` (complements CCTP nonce) | SECURITY.md cross-bridge replay |
| Same-message replay | Cross-Chain | Low | Med | CCTP `usedNonces` (reverts); check bool return | Nomad 2022 - $190M |
| Griefer front-runs relay / redirects funds | MEV/Operational | Low | Low | `account` inside attested body; griefer only pays gas | — |
| Destination hook set reverts | Business Logic | Med | Low | returnbomb-safe `try/catch`; delivery not unwound | LZ compose failures |
| Leftover approvals / arbitrary calls | Access Control | Low | High | zero approvals; no arbitrary calls from adapter | LI.FI/Socket 2024 |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| hookData source | Parse from attested message (trustless) | Interview |
| destinationCaller | Enforce = adapter (atomic mint+execute) | Interview |
| Minted token | USDC-only, immutable | Interview |
| Failure mode | Non-reverting; funds to account; escrow for rejected transfers | Interview + security |
| Relayer access | Permissionless | Interview |
| Reentrancy | Stateless + `nonReentrant` | Interview |
| Deployment | `DeployV2Core` adapters + config | Interview |
| Testing | Fork + real transmitter, `lib/pigeon` attester mock | Interview + repo |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/) — repo-analysis, framework-docs, evm-security, specflow-analysis

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/cctp-destination-adapter/technical-spec.md`
