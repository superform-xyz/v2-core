# Security Analysis Report — PR #989 "make Across destination delivery atomic"

## Metadata
- **Target:** PR #989, `src/adapters/AcrossV3AdapterV2.sol` (branch `fix/across-atomic-destination-delivery`), with `SuperDestinationExecutor.sol` and the PR's unit tests as context
- **Mode:** review (inline scan + 3 parallel agents)
- **Date:** 2026-08-31
- **Contract Types Detected:** Bridge receiver (Across V3 `handleV3AcrossMessage`)
- **Files Analyzed:** 3
- **Vulnerability Database:** superform-specs/guidelines/solidity/vulnerabilities.md (36 sections, 300+ patterns) + live-verified Across `SpokePool.sol` source + external research

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|--------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 3 | No |
| P3 Low | 6 | No |

## Verdict
**PASS** — no P0/P1 findings. The PR is directionally correct and fixes the observed
incident (whole-execution OOG silently swallowed). However, **P2-1 shows the fix is
incomplete for a realistic class of intents**, and one cheap addition (a min-gas floor)
closes both P2-1 and P2-2 simultaneously. Strongly recommended before or immediately
after merge.

## Ground truth (verified against Across SpokePool source)
- The SpokePool calls `handleV3AcrossMessage` directly with **no try/catch**: any adapter
  revert reverts the entire fill atomically (tokens + message together). PR #989's
  atomic-revert semantics are the SpokePool's native behavior — no funds can be lost;
  worst case is an origin-chain refund after `fillDeadline`.
- **Slow fills also execute the message**, but **V5-witness-tagged messages are excluded
  from slow fill** (`nonV5Fill`). If Superform intents use V5 encoding, an
  always-reverting fill's only escape is the origin refund — size `fillDeadline`
  accordingly.
- Prior art (Stargate `sgReceive`, LayerZero compose, C4 Decent #665) supports the PR's
  direction: swallowed receiver failures are a documented incident class; revert-on-OOG
  is the corrective pattern.

---

## P2 Findings (Medium — should fix)

### P2-1: Wrapped OOG defeats the empty-returndata heuristic (relayer gas-metering reopens the silent-skip)
- **File:** src/adapters/AcrossV3AdapterV2.sol:176-183
- **Category:** Gas griefing / logic — vulnerabilities.md 13.1, Appendix H.2, SWC-126
- **Description:** The catch classifies OOG by `returndatasize() == 0`, which only holds
  when the OOG occurs in the frame directly beneath the `try`. Any intermediate frame
  that wraps a sub-call failure into a typed error (`if (!success) revert SWAP_FAILED()`
  — common in Superform hooks) converts a deep OOG into **non-empty** returndata. Under
  EIP-150's 63/64 forwarding, a relayer can tune the fill gas so a hook's inner call
  OOGs while every wrapping frame completes: the adapter takes the best-effort branch
  and the fill finalizes with tokens delivered and the intent unexecuted — the exact
  outcome this PR set out to eliminate, now selectable per-fill by any relayer.
- **Exploit Scenario:** Relayer supplies gas G such that the swap hook's DEX call gets
  ~63/64^k·G and OOGs, but hook/executor/adapter frames finish. Fill finalizes; relayer
  is repaid at origin; execution silently skipped (recoverable manually — the root rolls
  back — but that is the operational burden the PR intended to remove).
- **Secure Pattern:** Enforce a minimum-gas floor **before** the `try`:
  `if (gasleft() < MIN_EXEC_GAS) revert INSUFFICIENT_EXECUTION_GAS();` with
  `MIN_EXEC_GAS` covering the worst-case intent (ideally carried per-intent in the
  signed message rather than a global constant). This makes fill success genuinely
  conditional on adequate gas regardless of how callees wrap failures, and it also
  drives `eth_estimateGas` to an adequate limit. Keep the empty-returndata revert as
  defense-in-depth.

### P2-2: Deterministic empty reverts make a fill permanently unfillable (deposit-expiry griefing)
- **File:** src/adapters/AcrossV3AdapterV2.sol:181 (and 159-161 for `TRANSFER_FAILED`)
- **Category:** DoS via unexpected revert — vulnerabilities.md 7.2/7.4, SWC-113
- **Description:** Empty returndata is not exclusive to OOG: bare `require(cond)`,
  `revert()`, ETH `transfer()` stipend failures, and `invalid` all produce it. A
  *deterministic* empty revert anywhere in the destination path (paused pool with bare
  require, filled deposit cap, blocklisted account for `TRANSFER_FAILED`) makes every
  fill attempt revert; relayers refuse after simulation; the deposit sits until
  `fillDeadline` and refunds at origin. A third party who can flip such a condition
  (e.g., front-fill a vault cap) can grief specific intents into refunds at bounded
  cost. No fund loss, but the delivery guarantee is voided and capital time-locked.
- **Secure Pattern:** The P2-1 min-gas floor is the unifying fix: with adequate gas
  guaranteed up-front, *any* revert is legitimately attributable to execution and the
  catch can be uniformly best-effort again (or the empty-returndata branch retained but
  with far fewer false positives). Additionally: sweep the destination hook call graph
  for message-less `require`/`revert()` and convert to custom errors; monitor
  fill-revert rates; confirm `fillDeadline` sizing gives refund runway.

### P2-3: Dead code cascade — `failedTransfers` subsystem is unreachable, and stranded tokens have no rescue path
- **File:** src/adapters/AcrossV3AdapterV2.sol:37, 91-95, 190-205 (+ ReentrancyGuard at 7/23)
- **Category:** Code asymmetry / stuck funds — vulnerabilities.md 25.1, SWC-131
- **Description:** Nothing credits `failedTransfers` after this PR, so
  `claimFailedTransfer` always reverts, `TransferFailed` never emits (its NatSpec still
  documents the removed credit behavior, contradicting the contract-level `@dev`), and
  `ReentrancyGuard` guards only the dead function. Meanwhile tokens can still strand in
  the adapter with no exit: an Across deposit naming the adapter as recipient with an
  **empty message** transfers tokens without invoking the handler at all, and direct
  transfers are likewise unrecoverable.
- **Secure Pattern:** Delete the mapping, claim function, `TransferFailed`,
  `INSUFFICIENT_FAILED_BALANCE`, `ZERO_AMOUNT`, and the `ReentrancyGuard` inheritance —
  or repurpose the claim path as a governance-gated sweep for stranded tokens.

---

## P3 Findings (Low — consider fixing)

1. **`ExecutionFailed` event pollution / dusting** (adapter:162,182) — `tokenSent`,
   `amount`, and the message are attacker-constructible via permissionless `depositV3`
   naming the adapter. Fund safety holds (signature binding, root rollback,
   pinned CREATE2 initData verified), but an attacker can emit
   `TransferSucceeded(victim,…)`/`ExecutionFailed(victim)` at will (forged signatures
   fail with non-empty `INVALID_SIGNATURE` → best-effort branch) and dust victim
   accounts. Include the bounded 4-byte revert selector in `ExecutionFailed` so
   monitoring can filter noise; never let these events trigger privileged actions.
2. **Adapter ignores signed `DstInfo.executor`/`validator`** (adapter:216-234) — a leaf
   naming a different executor fails validation into the best-effort branch: tokens
   delivered, intent unexecutable via this adapter. Add
   `if (info.executor != address(SUPER_DESTINATION_EXECUTOR)) revert;` before the
   transfer for a clean atomic rollback.
3. **No `nonReentrant` on `handleV3AcrossMessage`** — currently safe (adapter is
   stateless on this path; executor marks roots before `_execute`; SpokePool
   replay-protects fills), but the stateless invariant should be made explicit by
   removing ReentrancyGuard with the dead code, or the guard added if state returns.
4. **First-match on duplicate same-chain `DstProof`** — mirrors validator semantics and
   the documented one-leaf-per-destination constraint; invariant awareness only.
5. **NatSpec gaps** — `DESTINATION_EXECUTION_FAILED` omits the no-code trigger
   (line 166); constructor lacks `@param`s; `ExtractedData` members undocumented;
   `TransferSucceeded` param named `tokenSent` vs siblings' `token`; per-call
   `code.length` check on an immutable is undocumented (it is defensible — document why).
6. **Test gaps** — the new paths are well covered (OOG-with-retry, empty revert,
   returnbomb best-effort, `TRANSFER_FAILED` via false-return), but untested:
   `NO_DST_PROOF_FOR_CHAIN`, zero-account, non-SpokePool caller, reverting-token
   `TRANSFER_FAILED` branch, executor `code.length == 0`, constructor zero-address,
   `TransferSucceeded` emission assert, multi-element `DstProof[]` iteration.

---

## Verified-safe (attack surfaces that check out)
- **Returnbomb-proof catch:** parameterless `catch {}` + assembly `returndatasize()`
  only; nothing copies attacker returndata to memory (100KB revert test passes).
  `trySafeTransfer` copies ≤32 bytes and treats no-code tokens as failure.
- **Caller authentication:** `msg.sender == ACROSS_SPOKE_POOL` enforced; `relayer`
  param unused; amounts not trusted for value logic beyond forwarding the fill amount.
- **Forged messages cannot steal or burn roots:** executor re-derives `destinationData`
  and requires the account's signature magic; `usedMerkleRoots` set inside the
  reverting try-scope; hostile `initData` cannot hijack counterfactual accounts.
- **Direct-frame OOG:** empty returndata + 1/64 retained gas → deterministic
  `DESTINATION_EXECUTION_FAILED` → atomic rollback, retryable (tested).
- **Best-effort delivery target:** tokens go to the user's smart account
  (recovery-capable) with permissionless `processBridgedExecution` retry — matches the
  corrective guidance from the Stargate/Decent incident class.

## Attack Surface Summary
- **External entry points:** `handleV3AcrossMessage` (SpokePool-gated, message
  attacker-constructible), `claimFailedTransfer` (dead), executor's permissionless
  `processBridgedExecution` (signature-gated).
- **Value transfer points:** SpokePool → adapter (fill), adapter → account
  (`trySafeTransfer`), dead claim path.
- **Cross-contract:** executor → account `_execute` → arbitrary signed hooks → external
  protocols (source of both P2s).
- **Upgrade mechanisms:** none (immutable adapter; migration = redeploy + bundler
  switchover — the PR's noted quiescent-drain caveat applies).

## Recommended actions (priority order)
1. Add the min-gas floor before the executor call (closes P2-1 and P2-2 together);
   ideally per-intent gas carried in the signed message.
2. Delete the dead `failedTransfers` subsystem or convert it to a governance sweep (P2-3).
3. Sweep destination hooks for message-less `require`/`revert()` → custom errors.
4. Add the bounded revert-selector to `ExecutionFailed`; validate `DstInfo.executor`.
5. Add the missing negative-path tests (P3-6 list).
6. Ops: confirm `fillDeadline` sizing (V5 messages have no slow-fill fallback) and keep
   HyperEVM worst-case execution gas under the ~2M small-block cap.

## Security Knowledge Sources
- vulnerabilities.md sections: 1, 7, 8, 13, 15, 16, 20, 25, 26, 29, 33, 36, Appendices H/J
- Live-verified: across-protocol/contracts `SpokePool.sol` (fill atomicity, slow-fill
  `nonV5Fill`, refund semantics), OZ `trySafeTransfer`/`_callOptionalReturnBool`
- External: SWC-113/126/131, OWASP SC Top 10 2025 (SC01/SC03/SC06/SC10), ExcessivelySafeCall,
  OpenZeppelin Across audits, C4 2024-01 Decent #665, Trust Security LayerZero case study
