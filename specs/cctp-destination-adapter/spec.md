# CCTP Destination Adapter Spec

## Metadata
- Project: Superform v2-core
- Milestone: CCTP V2 Integration (Destination Side)
- Linear Issue: N/A
- Interview Date: 2026-09-21
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

`src/adapters/` has adapters for Across, deBridge, Relay, and Stargate — but none for CCTP, even
though the CCTP source hooks are live in prod on every chain. The gap is not deliberate. The original
CCTP spec assumed *"Circle's attestation service + off-chain relayers handle the receive side"*
(`specs/cctp-bridge-hooks/interview-notes.md:28-33`), which is wrong:
`MessageTransmitterV2.receiveMessage` verifies and mints, then stops — it never reads `hookData`.
Whoever relays the message must execute the hook. The result is already shipped: `CCTPSendHook` emits
the exact 6-tuple `DebridgeAdapter` decodes, and nothing consumes it. Any CCTP transfer carrying
`hookCallData` today delivers USDC and silently does nothing else.

This spec builds `CCTPAdapter`: set as both `mintRecipient` and `destinationCaller` on the source burn,
it exposes a permissionless `relay(message, attestation)` that calls `receiveMessage` itself, takes
custody of the minted USDC, parses `hookData` from the same attested bytes, forwards the exact minted
amount to the target account, and calls `processBridgedExecution`. No changes to the deployed hooks.

Two findings from research changed the design and one threatens the scope. **(1)** Full-balance
forwarding — chosen in interview on a precedent that turned out to be false — is a drain vector here,
and was replaced with balance-delta accounting. **(2)** `MessageTransmitterV2.maxMessageBodySize` is
**8192 bytes** (measured live), capping `hookData` at 7964. The 6-tuple is the fat format, and Stargate
already had to abandon it under LayerZero's *looser* 10 KB limit. Phase 0 gates the whole project on
measuring real intents.

## Requirements

### Functional
1. Permissionless `relay(bytes message, bytes attestation)` calling `MessageTransmitterV2.receiveMessage`
2. Reject non-V2 messages (`uint32` at offset 0 must be `1`)
3. Parse `hookData` at absolute offset 376 and decode the 6-tuple, matching `DebridgeAdapter:158`
4. Assert `executor` / `validator` from `sigData.proofDst[]`, mirroring `AcrossV3AdapterV2:176-187`
5. Forward the balance delta measured around `receiveMessage`, cross-checked against
   `amount@216 - feeExecuted@312`; forward the smaller
6. Call `processBridgedExecution` best-effort in try/catch with an unbound catch
7. Escrow failed forwards in `failedTransfers` / `totalEscrowed`; expose `claimFailedTransfer`
8. Emit `Relayed` unconditionally so off-chain can distinguish silent no-ops from real execution

### Non-Functional
- Constructor strictly `(messageTransmitterV2, superDestinationExecutor)` — both chain-invariant, which
  yields **one CREATE2 address on every chain** and makes `destinationCaller` pinning cheap for the SDK
- `nonReentrant` on `relay()` and `claimFailedTransfer()`
- `MIN_EXECUTION_GAS` floor plus a `{gas: G}` stipend on the executor call
- Self-call isolation for `abi.decode` panics
- CCTP V2 only; deployed conditionally on `MessageTransmitterV2.code.length > 0`
- No hook changes, no governance surface, no admin rescue

## Technical Design

### Architecture
```
Source chain                        Destination chain

CCTPSendHook                        CCTPAdapter  (mintRecipient AND destinationCaller)
 depositForBurnWithHook(              relay(message, attestation)   [permissionless, nonReentrant]
   mintRecipient     = dstAdapter      │ 1. version == 1
   destinationCaller = dstAdapter      │ 2. decode hookData (self-call isolated)
   hookData = 6-tuple)                 │ 3. preBalance → receiveMessage → postBalance
 │                                     │ 4. amount = min(delta, amount - feeExecuted)
 └─── Circle attestation ─────────►    │ 5. _tryTransfer → escrow on failure
                                       │ 6. gas floor → try processBridgedExecution catch { }
```

Because the adapter calls `receiveMessage` from inside `relay()`, `msg.sender` seen by the transmitter
is the **adapter**, not the EOA — that is what lets `relay()` stay permissionless while
`destinationCaller` still guarantees the mint can only happen alongside hook execution.

### Data Model
No storage beyond `failedTransfers[account][token]` and `totalEscrowed[token]`. Message offsets:
`version@0`, `destinationCaller@108`, body@148, `mintRecipient@184`, `amount@216`, `maxFee@280`,
`feeExecuted@312`, `expirationBlock@344`, **`hookData@376`**.

### API Changes
New external surface: `relay(bytes,bytes)`, `claimFailedTransfer(address,uint256)`,
`decodeHookData(bytes)` (external only to enable the self-call). No changes to any existing contract.

## Implementation Plan

### Phase 0: Payload-size gate (BLOCKING)
- [ ] Encode the 2–3 most complex intended CCTP intents with realistic `SignatureData`
- [ ] Assert `hookData.length <= 7964`
- [ ] If it fits: proceed + add an SDK pre-flight assertion and a documented hook-count cap
- [ ] If not: **escalate** — `CCTPSendHookV2` becomes mandatory and adapter-only scope is void

### Phase 1: Contract
- [ ] `src/vendor/bridges/cctp/IMessageTransmitterV2.sol`
- [ ] `src/adapters/CCTPAdapter.sol`
- [ ] NatSpec documenting the deliberate divergence from Circle's `onlyOwner` wrapper
- [ ] Tune `MIN_EXECUTION_GAS`

### Phase 2: Tests
- [ ] `MockMessageTransmitterV2` (none exists today)
- [ ] Unit suite per `RelayAdapterUnitTests.t.sol` + `AdaptersUnitTests._buildDestinationData()`
- [ ] Adversarial suite — self-funding drain test first
- [ ] Fork suite extending `CCTPHooksForkE2E:882-1229`; `CctpV2Helper` variant returning
      `(message, attestation)`; replace the empty-`proofDst` fixture at `:20-28`

### Phase 3: Deployment
- [ ] Deploy-script wiring + conditional availability gating + constants
- [ ] Bytecode regeneration and locked artifacts
- [ ] Verify one CREATE2 address across chains

## Test Plan
- [ ] Unit: version rejection, 6-tuple decode, delta accounting, cross-check, executor/validator
      assertions, transfer failure → escrow, claim path, gas floor, malformed hookData
- [ ] Adversarial: self-funding drain, two messages in one tx, reentrant relay, gas-griefed relay,
      blacklisted account, `destinationCaller` bypass
- [ ] Invariants: forwarded ≤ mint delta; post-relay balance == escrow total; funds only ever reach the
      account named in the attested message; no cross-account claim; a poisoned message never blocks the
      next relay
- [ ] Fork: full burn→attest→relay→execute against the real mainnet `MessageTransmitterV2`

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|---|---|---|---|---|---|
| hookData exceeds the 7964-byte ceiling | Business Logic | Medium | **High** — voids scope | Phase 0 gate; fallback `CCTPSendHookV2` | Stargate hit LZ's looser 10 KB limit |
| Full-balance drain (**resolved in design**) | Vault Accounting | High if built as first specified | Critical | Delta + parsed cross-check | Sonne Finance — $20M |
| hookData accepted from a side channel | Cross-Chain | Low | Critical | Parse only from the attested message; never add `execute(hookData)` | CrossCurve/Axelar — $3M |
| SDK sets `destinationCaller = 0` | Cross-Chain | Medium | High — stranded | SDK checklist; pre-flight assert | — |
| SDK omits `chainsWithDestinationExecution` | Cross-Chain | Medium | Medium — forwarded, never executed | SDK checklist #9 | — |
| Gas-limit griefing forces the catch branch | Operational | Medium | Low-Med — one-shot, no loss | Gas floor; permissionless re-drive of `processBridgedExecution` | Circle's own warning on their wrapper |
| Silent no-op misread as success | Operational | High | Medium | `Relayed` event + off-chain correlation | — |
| Adapter USDC-blacklisted | Token Behavior | Very low | High — permanently unmintable | Accepted; `mintRecipient` can't be re-attested | — |
| Circle attester compromise | Cross-Chain | Very low | Critical | Accepted centralization | KelpDAO $292M; Ronin $624M |
| Reentrancy via the hook chain | Reentrancy | Low | Medium | `nonReentrant` + per-frame delta | — |
| BurnMessageV2 offset drift | Cross-Chain | Low | High | Fork tests against real bytecode | — |

## Open Questions (Resolved)

| Question | Answer | Decided By |
|---|---|---|
| Was the destination path deliberately skipped? | No — an incorrect assumption that CCTP auto-executes hooks | Investigation |
| Does CCTP auto-execute hookData? | **No.** `receiveMessage` verifies and mints, then stops | Circle source + docs |
| Is `CCTPHookWrapper` canonical? | Yes in shape, but its `relay()` is `onlyOwner` and its hookData convention (`target‖calldata`, packed) differs from ours — do not reuse its parsing | Circle source |
| Exact `hookData` offset | **376** (148 header + 228 body prefix) | Circle source, corroborated by `CctpV2Helper` |
| Is `MessageTransmitterV2` deterministic? | Yes — `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`, verified live on 6 chains | `eth_getCode` |
| Can `receiveMessage` give the minted amount? | No — returns `bool`. Use a balance delta | Circle source |
| 6-tuple or 2-tuple? | 6-tuple, dictated by the deployed locked hooks | Repo analysis |
| Amount forwarding | **Revised:** delta + parsed cross-check, not full balance | Security research |
| Permissionless `relay()` safe? | Yes, given `destinationCaller` pinning + gas floor; divergence from Circle documented | Security research |
| Which token to measure? | `dstTokens[0]` from the attested hookData; the delta is the guard | Design |
| Is the SDK-trust model an exception? | No — Across/Stargate/deBridge all trust the SDK for the destination recipient | Hook analysis |
| Is `intentAmounts` rescaled on chained amounts? | No, and Across/Stargate share the limitation. SDK must set a slippage-floored intent | Hook analysis |

## Corrections to Prior Specs
1. `specs/cctp-bridge-hooks/interview-notes.md:28-33` — the "no receive hook needed" assumption is
   **wrong** and is the root cause of this gap.
2. `specs/cctp-bridge-hooks/research/framework-docs.md:83` — *"If hookData provided … hook is
   executed"* is **wrong**, stated without citation.
3. `specs/cctp-bridge-hooks/spec.md:47-58` and `technical-spec.md:131-141` — the hook data layout is
   **obsolete** (missing the 52-byte strategy header, invents `hookCallDataLength`). Canonical source is
   `src/hooks/bridges/cctp/CCTPSendHook.sol:32-43`.
4. `specs/stargate-compose-adapter/spec.md` — "Transfer full adapter token balance" does not describe
   the shipped code (`StargateAdapterV2:324` forwards `amountLD`).

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/) — repo-analysis · framework-docs · evm-security · hook-master-plan

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
Run Phase 0 (payload-size gate) before approving scope. Then:
`/superform:work specs/cctp-destination-adapter/technical-spec.md`
