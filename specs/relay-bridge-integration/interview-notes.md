# Relay Bridge Integration — Interview Notes

**Date:** 2026-08-07
**Interviewer:** Claude (superform:spec)
**Feature:** Relay bridge source-side send hooks (RelayDepositHook + ApproveAnd variant) and destination adapter in `src/adapters`
**Prior context:** Recovered Relay analysis at `.claude/sessions/relay-bridge-analysis.md` (2026-08-06)

## Background (from prior analysis)

- Relay is an RFQ/intent bridge with economics similar to Across, but **no destination receiver-callback interface** (no `handleV3AcrossMessage` equivalent). The solver executes off-chain-quoted `txs[]` on the destination via a Router/Multicaller; `msg.sender` is the Router, not the user.
- `SuperDestinationExecutor.processBridgedExecution` is already `msg.sender`-agnostic, takes `account` explicitly, validates the signed intent on-chain, and gates on balance checks — so Relay's solver can call it directly.
- Origin side: direct deposit to `RelayDepository.depositErc20(account, token, amount, id)` / native variant (or `RelayReceiver`); origin tx carries only an `id`, no destination payload. Destination execution is specified off-chain in the Relay `/quote` API.
- Trust model: permissioned solver network, trusted Oracle + MPC Allocator, Security Council. User-fund safety rests on Superform's own destination signature + balance validation; Relay only affects liveness.
- Strategic value: chain coverage (~47+ chains incl. long-tail L2s) and quote competition.

## Decisions

### Destination flow
**Q:** Adapter as mandatory entry vs direct-to-executor?
**A:** **Direct to executor; adapter optional.** Solver's `txs[]` delivers funds to the account then calls `processBridgedExecution` directly. The adapter is still built as a robustness option (atomic pull → forward → execute), not the mandatory path.

### Adapter authorization
**Q:** Restrict adapter callers or permissionless?
**A:** **Permissionless, similar to Across — "we need to respect the same rules."** Same internal rules as `AcrossV3AdapterV2`: decode `(initData, sigData)`, match `DstProof` for `block.chainid`, transfer funds to account with `failedTransfers` self-claim fallback, best-effort try/catch call into `SUPER_DESTINATION_EXECUTOR.processBridgedExecution`. Safety anchored by signed-intent validation + balance checks in the executor, not by caller identity.

### Source hook variants
**A (multi-select):**
- ERC20 deposit hook (`RelaySendFundsAndExecuteOnDstHook`) with `usePrevHookAmount` chaining + `ApproveAndRelaySend…` variant, mirroring the Across pair
- **Native ETH deposit** support (Relay `depositNative` / `RelayReceiver` path)
- **Non-EVM origins (Solana/Bitcoin/Tron) explicitly out of scope** — EVM-only

### Scope
**A:** **Contracts only.** Hooks + adapter + tests + deploy/config wiring. SuperBundler `/quote` orchestration is a separate backend workstream; the spec documents the required destination `txs[]` ordering contract for the backend team.

### Relay address wiring
**A:** **Immutable constructor param** — one hook deployment per chain with the chain's Relay depository baked in (like Across SpokePool). Avoids hookData-supplied arbitrary approval targets.

### Testing
**A (multi-select):**
- Unit tests with mocked Relay depository (hook build/inspect/chaining, adapter decode/forward/fallback, fuzz on amounts + malformed messages)
- Fork integration tests against real deployed Relay contracts
- **Cross-chain e2e simulation** — user note: *"you might need to add relay in pigeon if not present already `/Users/cosming/1.Coding/Superform/pigeon`"*. Verified: pigeon currently has across, axelar, cctp, celer, debridge, hyperlane, layerzero(-v2), wormhole — **no relay module; adding one is in scope** (in the pigeon repo).

### Chain targeting
**A:** **Spec the pattern, defer chain list.** Constants structured per-chain like Across; actual enablement decided at deploy time (keeps spec unblocked from RH launch work).

### Token risks
**A:** **Non-standard tokens not supported.** SafeERC20 everywhere; fee-on-transfer/rebasing explicitly unsupported (same stance as Across/deBridge hooks); documented limitation.

### Native on destination
**A:** **ERC20 + native fills supported.** Adapter gets `receive()`, forwards native to account, `failedTransfers` fallback covers native too.

### Liveness / refunds
**A:** **Document as trust assumption.** Unfilled deposits sit with Relay's depository; refunds via Relay's off-chain Oracle/Allocator flow. Same trust class as Across/deBridge fill liveness; add to SECURITY.md-style trade-offs. No on-chain escape hatch possible with Relay's design.

## Open items for research phase
- Exact Relay depository/receiver contract names, addresses, and function signatures (verify against Relay docs — don't guess)
- Whether a single Relay quote guarantees ordered execution of [deliver funds → call executor] atomically on destination (the caveat from the prior analysis; determines how strongly to recommend routing through the adapter)
- Relay deposit `id` semantics (who generates, uniqueness, refund linkage)
- Native deposit call shape (`depositNative` signature / RelayReceiver fallback behavior)
