# Relay Bridge Integration — Technical Specification

## Overview

Integrate Relay (relay.link) as a third intent/RFQ bridge in Superform v2-core, alongside Across and deBridge. Deliverables are contracts-only:

1. `RelaySendFundsAndExecuteOnDstHook` — source-side NONACCOUNTING bridge hook (ERC20 pre-approved + native ETH) calling `RelayDepository.depositErc20/depositNative`
2. `ApproveAndRelaySendFundsAndExecuteOnDstHook` — ERC20 variant with the house approve-0/approve/deposit/approve-0 pattern
3. `RelayAdapter` (`src/adapters/`) — permissionless destination adapter (optional robustness path)
4. Unit + fork + cross-chain e2e tests (the last requires a new `relay` facilitator in the pigeon repo)
5. Deploy/config wiring (pattern only; chain enablement deferred)

The SuperBundler `/quote` orchestration is a **separate backend workstream**; this spec documents the destination `txs[]` contract the backend must implement (§ Bundler Contract).

## Problem Statement / Motivation

Relay's differentiated value is **chain coverage**: 60+ EVM chains including long-tail L2s that Across/deBridge/Stargate don't serve — notably **Robinhood chain (4663)**, already in Relay's supported list. Secondary value is quote competition on existing chains. Relay's RFQ economics resemble Across, but its integration surface is materially different: **there is no destination receiver-callback interface**. The solver executes off-chain-quoted `txs[]` atomically via `RelayRouterV3.multicall` (or allocator-signed depository `execute`), with `msg.sender` = router, never the user.

The decisive architectural fact: `SuperDestinationExecutor.processBridgedExecution` is already `msg.sender`-agnostic, takes `account` explicitly, validates the user's signed Merkle intent on-chain, and gates execution on balance checks — so Relay's solver can call it **directly**. That makes the contract-side integration smaller than Across's; the complexity shifts to the off-chain quote orchestration (out of scope).

## Proposed Solution

### Architecture

```
SOURCE CHAIN                                  DESTINATION CHAIN
┌─────────────┐  depositErc20/Native   ┌──────────────────┐
│ Smart Acct  │ ─────────────────────▶ │ RelayDepository  │  (escrow, event-only)
│ (hook exec) │   (account, orderId)   └──────────────────┘
└─────────────┘                                 │ off-chain: Oracle matches deposit↔fill
                                                ▼
                                        ┌──────────────────┐   txs[] atomic, in order
                                        │ Relay solver via │ ─────────────────────────┐
                                        │ RelayRouterV3    │                          │
                                        └──────────────────┘                          ▼
                              PRIMARY: 1. transfer funds → account        ┌─────────────────────────┐
                                       2. call ──────────────────────────▶│ SuperDestinationExecutor│
                              OPTIONAL: 1. transfer funds → RelayAdapter  │ .processBridgedExecution│
                                        2. call RelayAdapter ────────────▶│ (sig + balance + root)  │
                                           .processRelayExecution         └─────────────────────────┘
```

- **Primary destination path:** solver's `txs[]` = `[deliver funds to account, call processBridgedExecution(...)]`. Safety = user's signed intent (Merkle leaf binds executorCalldata, chainid, account, executor, dstTokens, intentAmounts) + balance validation + per-account root replay gate. A malicious solver can only no-op or execute exactly what the user signed.
- **Optional adapter path:** `txs[]` = `[deliver funds to RelayAdapter, call processRelayExecution(...)]` — atomic pull → forward (with `failedTransfers` self-claim fallback, ERC20 + native) → best-effort try/catch executor call. Permissionless per Across internal rules, hardened with two extra guards (below).

### Verified Relay facts (from source, not guessed — see research/framework-docs.md)

- `depositNative(address depositor, bytes32 id) external payable`; `depositErc20(address depositor, address token, uint256 amount, bytes32 id)` pulls via `safeTransferFrom(msg.sender)` → approval required. Deposits are **event-only** (no on-chain state, no id uniqueness).
- Canonical depository `0x4cD00E387622C35bDDB9b4c962C136462338BC31` on most EVM chains via CREATE2; **exceptions** (Cronos, Metis, Polygon zkEVM, Mantle, Linea, Taiko: `0x59916d…EcCA`; Zero: `0xa88cf7…3b9b`). Verify per chain at deploy against `relay-depository/deployments/addresses.prod.json`.
- `explicitDeposit: true` (depository path) is **required for smart-contract wallets** — the legacy RelayReceiver/implicit path is EOA-only and must not be integrated.
- Destination `txs[]` execute **in order, atomically** (`allowFailure=false`) within one router multicall; reverts unwind the whole fill into the refund path. `msg.sender` = `RelayRouterV3` (`0xb92F…fF4F` most chains).
- Refunds: solver fast-refund on the **origin chain** + Oracle attestation. **No user-side on-chain claim exists** on the depository. Always set `refundTo`.
- Trust stack: permissioned solvers, threshold-signed Oracle, NEAR-MPC Allocator (balance-bounded), Security Council. Audits: Spearbit/Cantina (Feb 2025), Certora (Jun 2025), Zellic (Nov 2025 settlement, Apr 2026 oracle). None of this bears on Superform user-fund safety — only liveness.

## Technical Design

Full contract design in `research/hook-master-plan.md` (superform-hook-master, mandatory per CLAUDE.md). Summary of the load-bearing decisions:

### Vendor interface — `src/vendor/bridges/relay/IRelayDepository.sol`
`depositNative`, explicit-amount `depositErc20`, `allocator()`. The full-allowance `depositErc20` overload is intentionally excluded.

### Hook 1 — `RelaySendFundsAndExecuteOnDstHook`
- `BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)` + `ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow`
- `constructor(address relayDepository_)` → immutable `RELAY_DEPOSITORY`. **No `VALIDATOR` immutable, no sigData append** — Relay's origin deposit carries only the `bytes32 id`; the destination payload travels off-chain in the quote `txs[]`.
- **Data layout (137 bytes):** 52-byte strategy header + `token`@52 (`address(0)` = native), `amount`@72 (`AMOUNT_POSITION`), `depositId`@104, `usePrevHookAmount`@136. No value/dstChainId/outputAmount/deadline fields — Relay binds those off-chain to the `depositId`.
- Build: single `Execution` → `depositNative(account, depositId){value: amount}` or `depositErc20(account, token, amount, depositId)`. **`depositor` is always `account`, never from hookData** — pins Relay refund attribution to the smart account.
- Reverts: `DATA_NOT_VALID` (<137), `AMOUNT_NOT_VALID` (0, incl. after chaining), `ID_NOT_VALID` (zero depositId = unattributable deposit).
- Standard sizing surface: `decodeAmounts`/`amountRoles` (`[IN, TOKEN]`)/`replaceCalldataAmounts`/`decodeUsePrevHookAmount`/`_supportsSizingInterface() → true`; `inspect()` = packed `token` (addresses only). Default TRANSFORM pipe mode, no pre/post overrides (terminal bridge hook, matches Across V2).

### Hook 2 — `ApproveAndRelaySendFundsAndExecuteOnDstHook`
Same layout/surface; ERC20-only (`token == address(0)` → `ADDRESS_NOT_VALID`); 4 executions: `approve(dep, 0)` → `approve(dep, amount)` → `depositErc20(...)` → `approve(dep, 0)`.

### Adapter — `RelayAdapter`
```solidity
function processRelayExecution(address tokenSent, uint256 amount, bytes calldata message)
    external payable nonReentrant
```
`message = abi.encode(bytes initData, bytes sigData)` — the exact compact 2-field V2 format of `AcrossV3AdapterV2`/`StargateAdapterV2`; `sigData` (the 7-tuple `SignatureData` blob) is only *read* for `DstProof` routing and **forwarded byte-identical** so validator signatures stay valid.

Flow: zero-amount / msg.value-consistency checks → decode → `DstProof` match by `block.chainid` (revert `NO_DST_PROOF_FOR_CHAIN` — safe, atomic batch unwinds the fund leg) → account zero-check → **permissionless guards** → native-aware `_tryTransfer` (Stargate pattern: `call{value:}` for native, low-level tolerant ERC20 transfer) with `failedTransfers[account][token]` credit on failure → `try processBridgedExecution … catch { emit ExecutionFailed }` (variable-less catch — no returndata copy, returnbomb-safe).

**Two mandatory deviations from AcrossV3AdapterV2** (it has `msg.sender == SpokePool`; we have no caller to trust — dropping either guard reintroduces a critical vuln, see research/evm-security.md finding #1):
1. **`INSUFFICIENT_FUNDS_RECEIVED` guard:** `available = (native ? address(this).balance : balanceOf(this)) − totalEscrowed[token]`; require `available >= amount`. Blocks phantom-credit attacks (crediting `failedTransfers` with money that doesn't exist).
2. **`totalEscrowed[token]` accounting:** incremented with `failedTransfers` credits, decremented in claims. Blocks escrow-sweep attacks (an attacker signing their *own* valid intent to redirect *other users'* escrowed failed-transfer funds).

`claimFailedTransfer(token, amount)`: nonReentrant, msg.sender's own balance only, native branch (`token == address(0)` → `call{value:}` reverting `ETH_TRANSFER_FAILED`), decrements both mappings.

## Attack Surface Analysis

Full analysis in `research/evm-security.md` (grounded in the internal vulnerability DB + Stargate adapter security report). Summary:

### Resolved by design
| Vector | Mitigation | Ref |
|---|---|---|
| Phantom `failedTransfers` credit via caller-supplied amount (Critical) | `INSUFFICIENT_FUNDS_RECEIVED` balance guard | evm-security §1.1 |
| Cross-user escrow sweep via self-signed valid intent (Critical) | `totalEscrowed` accounting | hook-master §5.4 |
| Native forwarding failures / balance-based sweeps (High) | recorded-amount forwarding, native-aware `_tryTransfer` + native `failedTransfers`, never `address(this).balance`-forwarding | evm-security §1.2, Stargate P2-2/P3-x |
| Returnbomb / try-catch decode | variable-less `catch { }`, callee returns nothing | evm-security §1.3, App. H.1 |
| Approval residue | approve-0/approve/deposit/approve-0; immutable depository sole spender | §1.5 |
| Refund redirection via hookData | `depositor` hardcoded to `account` | hook-master §3.3 |
| hookData-supplied arbitrary approval targets | immutable per-chain depository (constructor param) | interview |
| Message forgery on permissionless entrypoints | executor re-derives `destinationData`, verifies user signature; adapter takes no irreversible action on unauthenticated fields beyond guarded forwarding | evm-security §1.4, §2 |
| Replay | `usedMerkleRoots[account][root]`; balance-check-before-root-burn ordering preserved (underfunded call never burns a root) | §1.6 |
| Reentrancy | `nonReentrant` on adapter entry + claim | §3(b) |

### Accepted trust assumptions (approved 2026-08-07, document in SECURITY.md)
1. **Relay fill/refund liveness:** unfilled deposits sit in Relay's depository; refunds depend on Relay's solver/Oracle/Allocator stack; no user-side on-chain claim. Same trust class as Across/deBridge relayer liveness. User-fund *execution* safety stays anchored in Superform's destination signature + balance validation.
2. **Adapter non-atomic-solver window:** funds parked in the adapter between two *separate* solver txs (a deviation from Relay's own atomic-batch protocol) are claimable by any validly-signed own-account message until the second leg lands. Mitigation is procedural: the bundler must always request one atomic `txs[]` batch (which `RelayRouterV3.multicall` with `allowFailure=false` guarantees). The adapter is the optional path.
3. **Balance-gate is a snapshot** (existing SECURITY.md cross-bridge-replay class): execution triggers on any sufficient balance, not funds-from-this-fill; third parties can trigger execution the moment the account is funded (benign — executes exactly the signed intent).

### Exploit precedent check
Wormhole/Nomad/Ronin-class bridge thefts do **not** translate: Superform never trusts Relay's attestation for fund custody. The precedents that survive — KelpDAO ("act before validate") and the internal Stargate P2-2 (balance-based sweep) — are exactly what the two adapter guards close. See evm-security §2 for the full table.

## Bundler Contract (documentation for backend team — out of scope to implement)

Per intent, one atomic Relay fill batch (`allowFailure = false` on every call), via `POST /quote` with `explicitDeposit: true`, `includeProtocolData: true`, `refundTo` always set, `user = account`:

- **Primary:** `txs = [ transfer(account, amount) (or native value to account), processBridgedExecution(tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata, sigData) ]`
- **Adapter path:** `txs = [ transfer(RelayAdapter, amount), RelayAdapter.processRelayExecution(tokenSent, amount, abi.encode(initData, sigData)) (native: value on this call) ]`

Ordering is mandatory (executor balance gate / adapter funds guard). Backend obligations carried as acceptance criteria:
- `depositId` in hookData must equal `protocol.v2.orderId` from the same quote. It is signature-bound: hookData lives inside the signed userOp calldata, so the user's signature commits to the specific orderId — the bundler cannot substitute post-signature.
- `intentAmounts` must encode the **minimum acceptable** fill (netting out Relay `fees.*`) — it is the on-chain min-output surrogate; optimistic amounts cause permanent silent no-ops.
- Never reuse one signed Merkle root across two Relay quotes (second fill becomes un-auto-executable).
- **Retry/monitoring ownership (decided 2026-08-07):** backend/keeper monitors fills vs intents, retries `processBridgedExecution` after top-ups, alerts on stuck states (under-fill, wrong-token, refund-landed).
- `usePrevHookAmount` chaining is supported on-chain (decided 2026-08-07): the bundler must quote with `slippageTolerance`/`EXPECTED_OUTPUT` covering expected drift between quote-time and execution-time amounts; large drift risks a refund instead of a fill.

## Acceptance Criteria

### Functional
- [ ] `IRelayDepository` vendor interface (explicit-amount overload only)
- [ ] `RelaySendFundsAndExecuteOnDstHook`: ERC20 + native paths, 137-byte layout, chaining, full sizing surface, `inspect` = token
- [ ] `ApproveAndRelaySendFundsAndExecuteOnDstHook`: ERC20-only, 4-execution approval quad
- [ ] `RelayAdapter`: permissionless entry with both guards, native-aware forwarding + fallback, byte-identical sigData forwarding, native-aware self-claim
- [ ] Hooks discoverable by manifest tooling (`tooling/hook-classification.yaml` entries, `make manifest` green)
- [ ] Deploy wiring: Constants/ConfigBase/ConfigCore/DeployV2Core availability gating (chain list deferred), `regenerate_bytecode.sh`, post-deploy asserts
- [ ] SECURITY.md: Relay liveness/refund + adapter atomicity trust assumptions; note Relay has **no cancellation flow** (unlike deBridge)

### Security (all must hold — see Testing)
- [ ] Phantom-credit and escrow-sweep adversarial tests pass
- [ ] No stranded funds without a claim path (invariant)
- [ ] Underfunded execution never burns a Merkle root
- [ ] Post-hook allowance to depository == 0
- [ ] Reentrancy and returnbomb regression tests pass

### Quality gates
- [ ] `forge build` + full `make ftest` green on `pre-dev`-based branch (hook work must NOT go on `feat/rh-deployment`)
- [ ] NatSpec on all public/external functions; custom errors; Solidity 0.8.30

## Test Plan

Per hook-master-plan §8, plus specflow additions:

1. **Unit — hooks** (`test/unit/hooks/bridges/RelayHooks.t.sol`, mirrors `AcrossHooksV2.t.sol`): constructor/immutables/subtype, build ERC20 (3 execs: pre+deposit+post) and native (`value == amount`), ApproveAnd (6 execs, ordering), all reverts (short data, zero amount, zero id, native-on-ApproveAnd, chained-zero), chaining via `MockHook`, sizing surface + fuzz `replaceCalldataAmounts` round-trip, `inspect` = 20 bytes.
2. **Unit — adapter** (`test/unit/adapters/RelayAdapterUnitTests.t.sol`): happy ERC20/native (msg.value and pre-funded via `receive()`), all reverts, **phantom-credit attempt → `INSUFFICIENT_FUNDS_RECEIVED`**, **escrow-sweep regression** (attacker's own valid message vs escrowed balance), failed-transfer credit paths (ERC20 + native to `NonPayableContract`), claims (partial/over/native/`ETH_TRANSFER_FAILED`), executor-revert containment, returnbomb mock executor, fuzz amounts + garbage messages.
3. **Non-atomic race documentation test:** simulate a two-tx solver (fund adapter in tx1, attacker claims with own valid intent before tx2) — asserts the *documented* residual behavior so the trust assumption is visible in the suite, not just prose.
4. **Amount-drift test:** chained amount ≠ static quote amount — asserts the deposit succeeds with the chained amount (drift resolution is off-chain; test documents the boundary).
5. **Fork** (`test/integration/relay/`): `RelayAdapterE2EFork.t.sol` (Base fork, real `SUPER_DST_EXECUTOR`, MerkleTreeHelper-signed intents, pranked solver); `RelayHooksFork.t.sol` (real depository `0x4Cd0…BC31`, assert `RelayErc20Deposit`/`RelayNativeDeposit` via `vm.recordLogs` — both events have no indexed params).
6. **Cross-chain e2e** (Phase 4, depends on pigeon): new `pigeon/src/relay/` facilitator — captures deposit events from logs, takes destination `txs[]` **as parameters** (origin event carries no payload, only the id), executes them in order under a pranked solver with revert-on-first-failure (models `allowFailure=false`); convenience wrappers `helpRelayDirect`/`helpRelayViaAdapter`. Include the **reordered case** (execute before funds) proving the balance gate no-ops safely. Then a v2-core e2e consuming it, bumping `lib/pigeon`.

## Implementation Phases

Per hook-master-plan §10 (MVP-first):
- **Phase 1 (MVP, v2-core, branch off `pre-dev`):** vendor interface → both hooks → `MockRelayDepository` + hook unit tests → adapter → adapter unit tests → classification/manifest green
- **Phase 2:** fork integration tests
- **Phase 3:** deploy wiring + dry-run
- **Phase 4:** pigeon facilitator (separate repo) + cross-chain e2e + `lib/pigeon` bump

Deferred/out of scope: SuperBundler `/quote` orchestration (documented above), non-EVM origins, chain enablement list, fee-on-transfer/rebasing tokens, cancellation flow (impossible — Relay has no on-chain cancel).

## Dependencies & Risks

| Risk | Mitigation |
|---|---|
| Depository address drift (non-canonical chains; Relay redeploys) | Verify per chain against `addresses.prod.json` at deploy; recommend a CI check (follow-up) |
| Solver deviates from atomic batching (adapter path) | Accepted trust assumption; documented; adapter is optional path |
| Backend fee mis-estimation → permanent silent no-op | `intentAmounts` = minimum-acceptable rule in bundler contract + keeper retry handoff |
| Pigeon facilitator is a cross-repo dependency | Phase 4 is isolated; Phases 1–3 ship independently |
| Branch conflict with RH launch (`feat/rh-deployment`) | Implement on a `pre-dev`-based branch |

## References & Research
- `research/hook-master-plan.md` — full contract design, layouts, edge-case matrix, task breakdown (superform-hook-master)
- `research/repo-analysis.md` — Across/deBridge template with file:line references
- `research/framework-docs.md` — verified Relay interfaces, addresses, API, refunds, audits
- `research/evm-security.md` — vulnerability patterns, exploit precedents, invariants
- `research/specflow-analysis.md` — 10 user flows, permutation matrix, resolved questions
- Prior analysis: `.claude/sessions/relay-bridge-analysis.md` (2026-08-06)
- Templates: `src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol`, `src/adapters/AcrossV3AdapterV2.sol`, `src/adapters/StargateAdapterV2.sol` (native handling)
- Relay: docs.relay.link, github.com/relayprotocol/relay-depository, relay-periphery
