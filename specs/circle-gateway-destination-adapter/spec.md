# Circle Gateway Destination Adapter Spec

## Metadata
- Project: v2-core
- Milestone: Circle Gateway destination path (deferred from the CCTP adapter milestone)
- Linear Issue: N/A
- Interview Date: 2026-09-23
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary
Circle Gateway (unified USDC balance) has four deployed hooks in v2-core but no destination adapter: the only
destination path is a hook the user's account must execute itself, so there is no relayer-driven delivery, no
first-time account creation and no signed-intent execution. `CircleGatewayAdapter` mirrors `CCTPAdapter`: set as the
`TransferSpec`'s `destinationRecipient`/`destinationCaller`, it calls `GatewayMinter.gatewayMint`, measures the minted
USDC, decodes the Superform 6-tuple from `hookData`, forwards to the account and executes via
`SuperDestinationExecutor`.

Research changed one premise versus CCTP: on Gateway the source burn happens only after a successful mint and an
unused attestation expires with the balance restored, so the adapter **fails fast pre-mint** on every content
problem (no `sourceDepositor` escrow), supports homogeneous `AttestationSet`s (multi-source draws), and ships a
`recoverDirectMint` path for zero-caller specs that bypassed it.

## Requirements
### Functional
1. Permissionless `receiveAndExecute(payload, signature)`: fail-fast validation → `gatewayMint` → delta-measured
   forwarding → best-effort execution; `MisconfiguredMessageRelayed` on zero caller and pass-through.
2. Homogeneous `AttestationSet` support (identical recipient/caller/token/hookData); mixed sets rejected.
3. `recoverDirectMint(payload, signature)`: forward a Circle-signed, minter-consumed, adapter-unprocessed stray mint.
4. `claimFailedTransfer(token, amount)` for the account's own escrow; `ClaimFailedTransferHook`-compatible.
5. Deploy wiring in `DeployV2Core` with check/deploy arg parity; locked bytecode.
### Non-Functional
- Ownerless, immutable, no per-intent state a third party can set; outcome is a pure function of attested bytes.
- Never revert on content after the mint; nothing minted is ever retained unattributed.
- Real-executor and live-minter fork coverage before merge; security rounds as for CCTP.

## Technical Design
### Architecture
Relayer → adapter → (`GatewayMinter.gatewayMint` → USDC mint into adapter) → adapter forwards → `SuperDestinationExecutor`
→ account. Existing `CircleGatewayMinterHook` remains the account-driven alternative. See technical-spec.md §3–§6.
### Data Model
`failedTransfers[account][token]`, `totalEscrowed[token]`, `processed[specHash]`; immutables `GATEWAY_MINTER`, `USDC`,
`SUPER_DESTINATION_EXECUTOR`, `SUPER_DESTINATION_VALIDATOR`.
### API Changes
New contract; new vendor `IGatewayMinter.sol`; `Constants.CIRCLE_GATEWAY_ADAPTER_KEY`; `ConfigCore.gatewayMinters`.

## Implementation Plan
### Phase 1: Adapter + tests
- [ ] `src/adapters/CircleGatewayAdapter.sol` per technical-spec §6 (incl. `recoverDirectMint`)
- [ ] Unit suite (mock minter), fork E2E (live minter, EIP-191 test signer), real-executor E2E
### Phase 2: Deploy + security
- [ ] `DeployV2Core` wiring, parity test, locked bytecode, read-only check passes
- [ ] Security rounds + report; PR from `dev`

## Test Plan
- [ ] Unit tests for: fail-fast matrix, set homogeneity, clamp/surplus fuzz, escrow/claim isolation, gas floor, returnbomb, mint-authority reentrancy, `recoverDirectMint`, `balance ≥ totalEscrowed` invariant, parser-differential
- [ ] Integration tests for: live `GatewayMinter` happy path, replay, expiry, zero-caller stranding + recovery, pass-through, sets, denylist/pause/blacklist, same-domain
- [ ] E2E tests for: real executor + validator (execute/root, DstProof mismatch, tampered intent, initData creation, direct re-drive)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Restore-on-expiry not as documented | Cross-Chain | Low | High (pre-mint reverts would strand) | Confirm with Circle (Q1) before merge; design still never burns before mint | — |
| Circle signer compromise | Cross-Chain | Low | High | Delta accounting never amplifies; inherited trust, documented | Ronin 2022, Multichain 2023 |
| Minter upgrade / ABI change | Proxy/Upgrade | Low | Medium | Specs expire, balances restore; SDK migrates to a new adapter | — |
| Adapter denylisted / blacklisted / minter paused | Operational | Low | Medium (escrow frozen) | Keep escrow small; alerts; no admin by design | CS-CSpend-018 |
| Mint-authority wrapper reentrancy | Reentrancy | Low | Medium | `nonReentrant`, delta+clamp, dedicated test | — |
| hookData exceeds Circle's unpublished cap | Operational | Medium | Low (rejected at attestation) | Measure largest 6-tuple; ask Circle (Q2) | — |
| Delegate routes depositor balance with attacker hookData | Access Control | Low | Medium (Gateway model) | Out of adapter scope; guardrail + SuperVault cap hook milestone | — |
| Wrong `initData` strands USDC at counterfactual address | Business Logic | Low | Low | Deterministic accounts; same as CCTP | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Entry model | Pull-driven, mirror CCTPAdapter | Cosmin |
| Failure model | Fail fast pre-mint; escrow only post-mint | Cosmin (post-research) |
| AttestationSets | Supported with identical routing | Cosmin (post-research) |
| Escrow beneficiary for bad hookData | None — rejected pre-mint | Cosmin (post-research; supersedes `sourceDepositor`) |
| destinationCaller 0 / pass-through | CCTP F1/F2 semantics from day one | Cosmin |
| Token scope | USDC only; non-USDC rejected pre-mint | Cosmin (post-research; supersedes escrow) |
| Direct-mint recovery | `recoverDirectMint` in Phase 1 | Cosmin |
| Constructor | `(gatewayMinter, usdc, superDestinationExecutor)`; no `domain() != 0` check | Cosmin / research |
| Gas floor | 2M, same as CCTP | Cosmin |
| SuperVault/delegates; Circle controls | Out of scope / accepted, documented | Cosmin |
| Deployment | Generic wiring + parity test; no scoped entrypoint | Cosmin |

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
After approval, run: `/superform:work specs/circle-gateway-destination-adapter/technical-spec.md`
