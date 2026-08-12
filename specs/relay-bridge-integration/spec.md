# Relay Bridge Integration Spec

## Metadata
- Project: v2-core
- Milestone: N/A (post-RH-launch bridge expansion)
- Linear Issue: N/A
- Interview Date: 2026-08-07
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Add Relay (relay.link) as a third intent/RFQ bridge alongside Across and deBridge. Relay's differentiated value is chain coverage (60+ EVM chains including Robinhood 4663, which Across/deBridge don't serve) plus quote competition. Relay has no destination receiver-callback: solvers execute off-chain-quoted `txs[]` atomically via their router, with `msg.sender` never being the user — which happens to match `SuperDestinationExecutor.processBridgedExecution` exactly (msg.sender-agnostic, signature + balance anchored). The primary destination path is therefore the solver calling the existing executor directly; contracts to build are two source-side deposit hooks, one optional permissionless destination adapter, and tests. The off-chain SuperBundler `/quote` orchestration is a separate backend workstream; this spec documents its contract.

## Requirements

### Functional
1. `RelaySendFundsAndExecuteOnDstHook` — source hook, ERC20 (pre-approved) + native ETH, calling immutable per-chain `RelayDepository.depositErc20/depositNative(account, orderId)`; `usePrevHookAmount` chaining supported
2. `ApproveAndRelaySendFundsAndExecuteOnDstHook` — ERC20 variant with approve-0/approve/deposit/approve-0
3. `RelayAdapter` (src/adapters) — permissionless optional path: decode `(initData, sigData)`, DstProof match, forward funds (ERC20 + native) with `failedTransfers` self-claim fallback, try/catch call to `processBridgedExecution`; hardened with received-funds guard + escrow accounting
4. Deploy/config wiring patterned on Across (chain enablement deferred); manifest tooling entries
5. New `relay` facilitator module in the pigeon repo for cross-chain e2e simulation

### Non-Functional
- Non-standard tokens (fee-on-transfer, rebasing) unsupported — documented limitation, consistent with Across/deBridge
- EVM-only; non-EVM origins out of scope
- Solidity 0.8.30, custom errors, NatSpec, locked-bytecode deploy compatibility
- Implementation branch off `pre-dev` (not `feat/rh-deployment`)

## Technical Design

### Architecture
- **Source:** hook builds one execution to the immutable Relay depository; `depositor` always = `account` (pins refund attribution); hook data = 137 bytes (header + token@52, amount@72, depositId@104, usePrevHookAmount@136). No on-chain destination message — unlike Across, the signed-intent payload travels in the bundler's quote `txs[]`, so the hooks carry no validator/sigData machinery.
- **Destination (primary):** solver's atomic `txs[]` = [deliver funds to account → `processBridgedExecution`]. Safety = user's signed Merkle intent + balance validation + root replay gate (all existing).
- **Destination (optional adapter):** same message format as AcrossV3AdapterV2 (`abi.encode(initData, sigData)`, sigData forwarded byte-identical), Stargate-style native handling, plus two permissionless-specific guards: `INSUFFICIENT_FUNDS_RECEIVED` (balance − escrow ≥ amount) and `totalEscrowed` bookkeeping — these block phantom-credit and cross-user escrow-sweep attacks and are non-negotiable.

### Data Model
No storage in hooks. Adapter: `failedTransfers[account][token]` (address(0) = native) + `totalEscrowed[token]`.

### API Changes
New vendor interface `IRelayDepository` (verified against Relay source). Bundler-facing contract documented in technical-spec (txs[] ordering, orderId binding via signed hookData, intentAmounts-as-min-output, root-reuse prohibition, retry/monitoring ownership).

## Implementation Plan

### Phase 1: MVP contracts + unit tests (v2-core)
- [ ] `IRelayDepository` vendor interface
- [ ] Both hooks + `MockRelayDepository` + `RelayHooks.t.sol`
- [ ] `RelayAdapter` + `RelayAdapterUnitTests.t.sol` (incl. phantom-credit & escrow-sweep adversarial tests)
- [ ] `hook-classification.yaml` + `make manifest` green

### Phase 2: Fork integration
- [ ] `RelayAdapterE2EFork.t.sol` (Base, real executor, signed intents)
- [ ] `RelayHooksFork.t.sol` (real depository `0x4Cd0…BC31`)

### Phase 3: Deploy wiring
- [ ] Constants/ConfigBase/ConfigCore/DeployV2Core/regenerate_bytecode + dry run

### Phase 4: Cross-chain e2e (cross-repo)
- [ ] Pigeon `src/relay/` facilitator; v2-core e2e; `lib/pigeon` bump
- [ ] SECURITY.md trust-assumption entries

## Test Plan
- [ ] Unit tests for: both hooks (layout, chaining, sizing surface, reverts), adapter (guards, fallback, claims, reentrancy, returnbomb)
- [ ] Integration tests for: Base-fork adapter e2e with signed intents; hooks against real depository
- [ ] E2E tests for: pigeon-simulated source-deposit → solver-fill → destination-execute (direct + adapter paths, incl. reordered/underfunded no-op case)
- [ ] Invariants: no stranded funds without claim path; executor never executes without balance; underfunded calls never burn roots; escrow conservation; permissionless-caller safety; zero residual allowance

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Phantom failedTransfers credit on permissionless adapter | Access Control | High (if unguarded) | Critical | `INSUFFICIENT_FUNDS_RECEIVED` guard | Stargate internal report P2-2 |
| Cross-user escrow sweep via self-signed intent | Vault Accounting | Medium | High | `totalEscrowed` accounting | Stargate P2-2 (escalated) |
| Native transfer failure / burn | Token Behavior | Medium | High | native-aware `_tryTransfer` + native failedTransfers, zero-address guard | Stargate P3-1 |
| Solver splits atomic batch (adapter path) | Cross-Chain | Low | Medium | Accepted trust assumption; documented; bundler mandates atomic txs[] | — |
| Relay no-fill / refund liveness | Cross-Chain | Low | Medium | Documented trust assumption (same class as Across relayer liveness); `refundTo` always set | — |
| Solver under-fill → silent no-op | Business Logic | Medium | Medium | `intentAmounts` = min acceptable; backend keeper retry/monitoring handoff | — |
| try/catch OOG grief | Operational | Low | Low | variable-less catch, state writes before try | Nomad returnbomb research |
| Depository address drift on non-canonical chains | Operational | Low | Critical | per-chain verification at deploy vs addresses.prod.json | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Destination flow: adapter mandatory vs direct? | Direct-to-executor primary; adapter optional robustness path | User (interview, 2026-08-07) |
| Adapter authorization | Permissionless, Across internal rules | User (interview) |
| Source variants | ERC20 + native; EVM-only | User (interview) |
| Scope | Contracts only; bundler contract documented | User (interview) |
| Depository address wiring | Immutable constructor param per chain | User (interview) |
| Chain list | Pattern only; enablement at deploy time | User (interview) |
| Non-standard tokens | Unsupported | User (interview) |
| Keep `usePrevHookAmount` chaining despite off-chain quote-time amounts? | Yes — bundler covers drift via slippage tolerance; documented | User (2026-08-07) |
| Adapter non-atomic-solver residual exposure | Accepted, documented in SECURITY.md + NatSpec | User (2026-08-07) |
| Under-fill/wrong-token retry ownership | Backend/keeper handoff with explicit acceptance criteria | User (2026-08-07) |
| Is orderId bundler-substitutable post-signature? | No — depositId is in hookData inside the signed userOp calldata | Research (architecture) |

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
After approval, run: `/superform:work specs/relay-bridge-integration/technical-spec.md`
