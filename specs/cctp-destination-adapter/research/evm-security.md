# CCTP V2 Destination Adapter — EVM / DeFi Security Research

**Date:** 2026-08-13
**Scope:** `CCTPAdapter.receiveAndExecute(bytes message, bytes attestation)` — permissionless, stateless, USDC-only, immutable, `ReentrancyGuard`.
**Primary reference:** `superform-specs/guidelines/solidity/vulnerabilities.md` (sections cited inline).
**Comparanda in repo:** `src/adapters/AcrossV3AdapterV2.sol`, `src/executors/SuperDestinationExecutor.sol`, `src/hooks/bridges/cctp/CCTPSendHook.sol`.

---

## 0. Flow under review + trust model (read this first)

```
receiveAndExecute(message, attestation)  [permissionless, nonReentrant]
 1. MessageTransmitterV2.receiveMessage(message, attestation)
      → Circle attesters verified; nonce marked used (replay guard); destinationCaller==msg.sender(adapter) enforced;
        mints (amount - feeExecuted) USDC to mintRecipient (== adapter)
 2. slice hookData from attested BurnMessageV2 body
 3. abi.decode(hookData) => (initData, executorCalldata, account, dstTokens, intentAmounts, signature)
 4. SafeERC20.safeTransfer(USDC, account, <minted amount>)
 5. SuperDestinationExecutor.processBridgedExecution(...)  → EIP-1271 sig + merkleRoot (replay-guarded) + runs hooks
```

**Two independent trust layers, and what each actually secures:**

- **Circle attestation + `destinationCaller == adapter`** authenticates the *token delivery*. `account`, `amount`, `mintRecipient` all live inside the Circle-signed message; an attacker cannot forge them without a real source-chain burn. This is what makes step 4 (transfer to `account`) safe — **not** the user's EIP-1271 signature.
- **Executor EIP-1271 signature + `usedMerkleRoots`** authenticates *hook execution* on the account. It re-binds `account`, `block.chainid`, `dstTokens`, `intentAmounts`, `executorCalldata` (see `SuperDestinationExecutor.processBridgedExecution`, `destinationData`).

The single most important architectural fact: **the adapter must never trust anything from `msg.sender`/calldata other than what Circle attested and what the immutable `MESSAGE_TRANSMITTER`/`USDC`/`EXECUTOR` return.** The adapter is the *caller* of `receiveMessage` (auth is inverted vs. a callback receiver like Across), so it inherits Circle's verification for free — provided `MESSAGE_TRANSMITTER` and `USDC` are immutable and correct.

---

## 1. Relevant vulnerability patterns for THIS adapter

### 1.1 Cross-chain replay — is CCTP nonce + executor merkle root redundant or complementary? (vuln §16.1, §33.4, §41.2, §9.1)
**They are complementary, not redundant. Neither alone is sufficient.**

- **CCTP nonce** (`MessageTransmitterV2.usedNonces[nonce]`) prevents re-receiving *the same attested CCTP message*. Second `receiveMessage` **reverts**. This alone does **not** stop the same signed *intent* from being executed if it was also bridged by another path.
- **Executor merkle root** (`usedMerkleRoots[account][merkleRoot]`) prevents the same signed *intent* from executing twice regardless of transport. This is what covers the **cross-bridge replay** trade-off already documented in `SECURITY.md` (e.g. same intent sent via both Across and CCTP — first consumes the root, second no-ops but still delivers tokens).

**Gap to verify, not assume:**
- Confirm `receiveMessage` *reverts* (not returns `false`) on used nonce, and that the adapter **checks the boolean return** (`require(success)`), so a partially-successful mint can't be silently ignored (vuln §8.1 unchecked return). Do not rely solely on revert.
- The adapter itself stores **no** nonce set (stateless). That is acceptable *only because* the mint and the execution are atomic in one tx and both downstream contracts are replay-guarded. Do not add adapter-local replay logic that could diverge from CCTP's.
- Chain-binding lives in the executor (`uint64(block.chainid)` inside `destinationData`) — good. But the *token delivery* has no chain check in the adapter; it doesn't need one because `destinationDomain` is baked into the attested message and the transmitter is a per-chain deployment. Still, **assert `mintRecipient == address(this)`** as fail-fast (see 1.4).

### 1.2 Message-parsing / offset bugs when slicing hookData (vuln §23, §29, §14.3, §8.1)
CCTP V2 layout (verify against the deployed `MessageTransmitterV2`/`TokenMessengerV2` version before coding — offsets below are from the CCTP V2 spec):

```
MessageV2 header = 148 bytes:
  0   version(uint32) | 4 sourceDomain | 8 destinationDomain | 12 nonce(bytes32)
  44  sender(bytes32) | 76 recipient(bytes32) | 108 destinationCaller(bytes32)
  140 minFinalityThreshold(uint32) | 144 finalityThresholdExecuted(uint32)
  148 messageBody...
BurnMessageV2 body (offsets within message = 148 + below):
  0 version | 4 burnToken(b32) | 36 mintRecipient(b32) | 68 amount(u256)
  100 messageSender(b32) | 132 maxFee(u256) | 164 feeExecuted(u256) | 196 expirationBlock(u256) | 228 hookData...
=> hookData starts at message offset 148+228 = 376
=> amount at 216, feeExecuted at 312, mintRecipient at 184, destinationCaller at 108
```

Risks and controls:
- **hookData has NO internal length prefix** — it is "the rest of the body." So a "hookDataLength lying" attack is not possible: length is derived from `message.length`. Good. But the raw `message` came through `receiveMessage` which already validated header structure; still, the adapter must independently bound-check before slicing: **`require(message.length >= 376)`** (or the correct constant) before `BytesLib.slice(message, 376, message.length - 376)`. Reading past end / underflow on `length - 376` is the classic offset bug (vuln §23, §29).
- Prefer **`abi.decode`** of the sliced hookData into the 6-tuple over hand-rolled assembly. `abi.decode` bounds-checks offsets and reverts on truncated/garbage input; manual assembly reads can return dirty memory (vuln §23.x). Truncated/oversized/garbage hookData will then revert cleanly.
- **Oversized hookData** = gas cost only; caller pays. Note gas-griefing if a relayer is reimbursed (vuln §13.1, §13.2 unbounded return data).
- **Stranding side-effect of strict parsing (important):** because `destinationCaller == adapter`, *only* the adapter can receive this message, and if the adapter always reverts on a malformed hookData, the burned USDC is **permanently stuck in CCTP limbo** (burned on source, never mintable on dest). This is user-self-inflicted (they built the burn) but must be documented; see 4.6 for the fallback trade-off. Map to vuln §7 (DoS) / unused-funds stranding.

### 1.3 Balance-delta accounting, `feeExecuted`, and the donated-balance sweep (vuln §22.2, §28, §46.1, §10.1) — **HIGHEST-RISK ITEM**
The amount to transfer to `account` must be the amount **this `receiveMessage` call actually minted**, i.e. `amount - feeExecuted`.

- **NEVER transfer `IERC20(USDC).balanceOf(address(this))`.** If the adapter ever sweeps its full balance to the decoded `account`, then: (a) any USDC **donated** to the adapter, or (b) USDC left by a concurrent/failed in-flight message, can be **redirected to an attacker-chosen `account`** by crafting a (legitimately-attested, cheap) CCTP message with `account = attacker` and near-zero `amount`. This is the donation/inflation family (vuln §22.2, §28) applied to a stateless router.
- **NEVER transfer the gross burn `amount`** (the `amount` field at body offset 68). Circle deducts `feeExecuted`, so the adapter only *holds* `amount - feeExecuted`; transferring `amount` reverts *or* drains a donated buffer.
- **Recommended: exact balance delta.**
  ```
  uint256 pre  = USDC.balanceOf(address(this));
  MESSAGE_TRANSMITTER.receiveMessage(message, attestation);  // require success
  uint256 minted = USDC.balanceOf(address(this)) - pre;      // == amount - feeExecuted, by construction
  USDC.safeTransfer(account, minted);
  ```
  Delta is immune to: (i) pre-existing/donated balance (excluded), (ii) `feeExecuted` (naturally netted), (iii) any out-of-band direct mint to the adapter, and (iv) USDC not being fee-on-transfer today but defensively correct if Circle changes fee mechanics. This single choice neutralizes the sweep vector.
- **Invariant:** after a successful call, `USDC.balanceOf(adapter)` returns to its pre-call baseline (no net accumulation). Transfer the **full delta**, not `intentAmounts[i]` — transferring only the signed intent amount would strand `delta - intent` in the adapter, recreating the donated-buffer problem for the next call.
- Cross-check (optional, defense-in-depth): parse body `amount`(216) and `feeExecuted`(312) and `require(minted == amount - feeExecuted)` — catches an unexpected transmitter/fee behavior early. Only worth it if you're already touching those offsets to assert `mintRecipient`.

### 1.4 Validating `mintRecipient` / `destinationCaller` (vuln §41.1, §2.1)
- `destinationCaller == adapter` is **enforced by the transmitter** (`receiveMessage` reverts if `destinationCaller != 0 && destinationCaller != msg.sender`). Keeping it non-zero on the send side is a **hard requirement**: with `destinationCaller = 0`, anyone could call `MessageTransmitterV2.receiveMessage` directly with `mintRecipient = adapter`, minting to the adapter **without going through adapter logic** — parking USDC that then depends entirely on delta accounting to stay safe. Bind `destinationCaller = adapter` on the source `CCTPSendHook` path.
- **Assert `mintRecipient == bytes32(uint256(uint160(address(this))))`** in the adapter as fail-fast. Not strictly required for safety (a wrong `mintRecipient` just makes `minted == 0` and the executor no-ops), but it documents intent and prevents confusing zero-delta successes.

### 1.5 Unauthenticated `receiveAndExecute` griefing / front-running (vuln §6.1, §41.1)
Permissionless is **safe** here:
- Invalid attestation → `receiveMessage` reverts. No harm.
- Valid `(message, attestation)` from a griefer → the adapter does the honest thing (delivers to the attested `account`, consumes the nonce). The griefer merely pays gas. `account` is fixed by the attested hookData — a front-runner **cannot** substitute their own address without invalidating Circle's signature over the message.
- Racing the legitimate relayer only causes the loser's tx to revert on used-nonce. Minor wasted gas, no fund risk. Low severity.

### 1.6 Reentrancy via destination hooks (vuln §1.1–1.3, §8.2)
- `nonReentrant` + **strict CEI ordering**: `receiveMessage` → measure delta → `safeTransfer` to account → `processBridgedExecution` (the only untrusted external call, since it runs arbitrary hooks in the *account's* context).
- USDC is **not** ERC-777 / has no transfer callback, so step 4 cannot reenter. The reentrancy surface is exclusively the executor/hook call; `nonReentrant` covers it and the adapter holds **no persistent state to corrupt** (stateless). Cross-contract reentrancy into a second `receiveAndExecute` is blocked by the guard; even without state, delta accounting makes double-spend impossible.
- Wrap the executor call in `try/catch` (as Across does) so a reverting hook set doesn't unwind the *already-correct* token delivery. But note the mint+transfer are before it — a caught executor revert leaves USDC safely at `account`, root unconsumed (retryable via a bare execution later). Confirm this is the intended UX.

### 1.7 Unused-funds stranding (vuln §7, §46.4)
- **Malformed hookData** (can't decode `account`) → cannot deliver → revert → message unmintable forever (`destinationCaller` locks it to the adapter). Document.
- **Blacklisted `account`** (USDC blacklist, vuln §46.4) → `safeTransfer` reverts → same permanent-stranding outcome, *unless* you adopt the Across `failedTransfers[account][token]` claimable pattern (which sacrifices strict statelessness). Decide policy explicitly (see 4.6).
- **`intentAmounts` mismatch / undervalued delta** → executor `_validateBalances` returns false and no-ops, but USDC is already at `account` (user-recoverable). Fine.

---

## 2. Exploit precedents and what generalizes

| Incident | Root cause | Generalizes to this adapter as |
|---|---|---|
| **Nomad ($190M, 2022)** — vuln §33.3 | Zero merkle root treated as valid; fake proofs | Don't roll your own attestation check; **delegate entirely to `MessageTransmitterV2`**. Never add a "trusted" default/short-circuit path. |
| **Wormhole ($326M, 2022; $10M bug 2024)** — vuln §33.1, §41.3 | Deprecated/duplicate signature-verification path bypassed | Single verification path = the canonical transmitter. **Check `receiveMessage`'s return value**; no alternate mint routes in the adapter. |
| **Ronin ($624M) / Multichain** — vuln §33.2 | Validator/MPC key compromise | Out of adapter's control, but note: security ceiling = **Circle attester set**. Systemic dependency to document. |
| **LI.FI (2022 ~$600k; 2024 ~$10M)** | Adapter made **arbitrary external calls** with user calldata + left **infinite approvals** on routers | The killer pattern for bridge adapters. **This adapter must make ZERO approvals and ZERO arbitrary `.call`s from its own context.** All arbitrary execution happens inside the *account* via the executor, never from the adapter address. Verify no `approve`, no low-level `call` with attacker calldata originating at `address(this)`. |
| **Socket/Bungee ($3.3M, 2024)** | Unverified route target + leftover user approvals to router | Same lesson: no approvals held by the adapter; nothing to sweep. Adapter's only outbound token op is `safeTransfer` of the just-minted delta. |
| **deBridge / Socket receiver patterns** | Callback receivers not checking gateway/source | Inverted here (adapter *calls* transmitter). Equivalent control = **immutable, correct `MESSAGE_TRANSMITTER` + `USDC` + `EXECUTOR`** set in constructor with zero-address checks. |
| **CrossCurve ($3M, 2025)** — vuln §41.1 | Receiver executed without verifying message origin | Satisfied by `destinationCaller == adapter` + attestation. Ensure the adapter cannot be tricked into treating a *non-transmitter* mint as authenticated (delta accounting + immutable transmitter). |
| **Across / general** | Best-effort execution UX | Mirror the proven `AcrossV3AdapterV2` shape: deliver funds first, `try/catch` the executor, optional claimable store. |

**Net generalization:** the historically expensive bridge-adapter bugs are (1) home-grown/duplicated message verification, and (2) **arbitrary-call + leftover-approval** token theft from the adapter. This design avoids both *if* it delegates verification to CCTP and never approves/arbitrary-calls from its own context. The residual novel risk is the **stateless balance-accounting** (donated-balance sweep), addressed by exact delta.

---

## 3. Attack-surface map (per entry point / field)

```
receiveAndExecute(message, attestation)  — permissionless, nonReentrant
├─ attestation ............. verified by Circle attesters inside receiveMessage. Adapter must require(success).
├─ message header
│  ├─ nonce ................ replay guard in transmitter (reverts on reuse). Adapter stores none.
│  ├─ destinationCaller .... MUST equal adapter; enforced by transmitter. Requires send-side binding.
│  ├─ sourceDomain ......... optional adapter allowlist (defense-in-depth; not required for safety).
│  └─ mintRecipient(body) .. SHOULD assert == adapter (fail-fast); wrong value => minted delta ~0 => no-op.
├─ body.amount / feeExecuted  minted = amount - feeExecuted. Use BALANCE DELTA, never balanceOf or gross amount.
├─ body.hookData (offset 376)
│  ├─ length ............... derived from message.length (no lie possible); require message.length >= 376.
│  ├─ abi.decode 6-tuple ... truncated/garbage => revert => (stranding: documented). Use abi.decode, not asm.
│  ├─ account .............. TRANSFER destination. Trusted via Circle attestation (in signed message body).
│  │                          Also re-bound by executor EIP-1271 sig. Griefer cannot substitute it.
│  ├─ dstTokens/intentAmounts length-checked by executor (ARRAY_LENGTH_MISMATCH). try/catch recommended.
│  └─ signature ............ = full SignatureData; validated + merkle-root-replay-guarded in executor.
├─ USDC.safeTransfer(account, delta)
│  └─ reverting/blacklisted account => whole tx reverts => stranding (or claimable-store trade-off).
└─ EXECUTOR.processBridgedExecution(...)  — ONLY untrusted external call; runs arbitrary hooks in ACCOUNT ctx.
   └─ reentrancy blocked by nonReentrant; wrap in try/catch so a hook revert can't unwind token delivery.
```

**Adapter-held privileges an attacker would want and why they fail:** no approvals granted (nothing to pull); no persistent balance intended (delta returns to baseline); no arbitrary call from adapter ctx (execution is in the account); no admin/owner functions (immutable); no adapter-local replay map to desync.

---

## 4. Recommended security patterns

1. **Immutable, zero-checked constructor wiring:** `MESSAGE_TRANSMITTER`, `USDC`, `SUPER_DESTINATION_EXECUTOR` all `immutable`, all `revert ADDRESS_NOT_VALID()` on zero. No setters (avoids vuln §41.4 unauthorized peer re-init, §2.4 unprotected init).
2. **Exact balance-delta accounting (§1.3):** `pre = USDC.balanceOf(this); receiveMessage; minted = balanceOf(this) - pre; safeTransfer(account, minted)`. This is the linchpin control. Never `balanceOf`-sweep, never transfer gross `amount`.
3. **Check the transmitter return:** `bool ok = MESSAGE_TRANSMITTER.receiveMessage(...); if (!ok) revert RECEIVE_FAILED();` (vuln §8.1) — belt-and-suspenders with its own revert.
4. **Assert `mintRecipient == address(this)`** (fail-fast, §1.4). Optionally allowlist `sourceDomain`.
5. **Strict CEI + `nonReentrant`** (§1.6): mint → delta → transfer → execute. USDC has no callback; the executor is the only reentrancy surface and is guarded.
6. **Bounds-safe parsing:** `require(message.length >= HOOKDATA_OFFSET)`; slice `[HOOKDATA_OFFSET:]`; `abi.decode` the 6-tuple (reverts cleanly on bad input). Constants documented against the exact CCTP V2 layout.
7. **`account` binding is dual and must stay dual:** transfer trusts Circle attestation; hooks trust EIP-1271 sig + merkle root. Do **not** let the adapter compute/override `account` from anything but the attested hookData. A griefer redirecting funds is impossible precisely because `account` lives inside the Circle-signed message.
8. **No approvals, no arbitrary calls from the adapter** (§2, LI.FI/Socket lesson). The adapter's only token op is `safeTransfer` of the minted delta; all arbitrary logic executes in the account via the executor.
9. **`try/catch` the executor** so a bad hook set doesn't unwind correct token delivery; emit an `ExecutionFailed(account)` event for observability (mirror Across).
10. **Decide the transfer-failure / malformed-hookData policy explicitly (§4.6 below).**

### 4.6 Statelessness vs. stranding — the one real design decision
Pure-stateless `safeTransfer` means a **reverting/blacklisted `account`** or **malformed hookData** permanently strands the burn (because `destinationCaller` locks the message to this adapter). Options:
- **(A) Accept + document** (simplest, truly stateless): note that malformed burns / blacklisted recipients strand funds; UI/relayer must guarantee well-formed hookData and non-blacklisted recipients.
- **(B) Across-style claimable store** for the *transfer* leg: low-level `try transfer` → on failure `failedTransfers[account][USDC] += minted`; `claimFailedTransfer` guarded by `nonReentrant`. Sacrifices strict statelessness but avoids stranding on blacklist/reverting recipient. Does **not** help malformed hookData (can't derive `account`).
Recommend **(B)** for resilience parity with `AcrossV3AdapterV2`, unless statelessness is a hard product constraint — in which case **(A)** with loud documentation.

---

## 5. Invariants + fuzz / negative tests

### Invariants (assert as properties)
- **INV-1 (no net accumulation):** for any successful call, `USDC.balanceOf(adapter)_after == USDC.balanceOf(adapter)_before`. (Full minted delta forwarded.)
- **INV-2 (donation-proof):** seeding the adapter with an arbitrary pre-balance `D` before the call does **not** change the amount delivered to `account` (delivered == `amount - feeExecuted`), and `D` remains in the adapter (option A) or is untouched. A crafted message with `account = attacker` and tiny `amount` transfers only its own tiny `minted`, never `D`.
- **INV-3 (exact delivery):** delivered amount == `body.amount - body.feeExecuted` == measured delta.
- **INV-4 (replay-once, CCTP):** second `receiveAndExecute` with the same `(message, attestation)` reverts (transmitter used-nonce).
- **INV-5 (replay-once, intent):** the same signed intent delivered via two transports executes hooks at most once (`usedMerkleRoots`); the second delivers tokens but no-ops execution.
- **INV-6 (account integrity):** `account` used for transfer == `account` in decoded hookData == `account` re-bound in executor `destinationData`; unaffected by `msg.sender` or any non-attested input.
- **INV-7 (no approvals):** `USDC.allowance(adapter, *) == 0` at all times; adapter never emits `Approval`.
- **INV-8 (stateless / no admin):** no owner, no setters, no upgrade path; storage layout carries no attacker-influenceable persistent state (except the optional `failedTransfers` in option B).
- **INV-9 (CEI):** no state read/written after the executor call that a hook could exploit.

### Negative / fuzz tests
1. **Wrong attestation** (random / signed-by-non-attester / for a different message) → `receiveMessage` reverts; no mint, no transfer, no execution.
2. **Replayed message** → second call reverts on used nonce; adapter balance and `account` balance unchanged by the second call.
3. **hookData truncated** (drop trailing bytes so `abi.decode` fails) → reverts before transfer; assert no partial delivery.
4. **hookData garbage / wrong tuple shape** (e.g. swap field order, bad dynamic offsets) → reverts cleanly; fuzz random `bytes` of length ≥ minimum.
5. **`message.length < HOOKDATA_OFFSET`** (short message) → reverts on the length guard, not on an underflow/OOB read.
6. **Oversized hookData** (megabytes) → succeeds or reverts on gas only; assert no state corruption; measure gas for griefing analysis.
7. **`account` not matching signature** (attested `account` A, but signature signed for account B) → executor sig validation fails → `INVALID_SIGNATURE` caught by `try/catch`; **USDC still delivered to attested `account` A**; merkle root NOT consumed. Assert exactly this.
8. **`account = attacker`, tiny `amount`, pre-seeded adapter balance `D`** (the sweep test) → attacker receives only `amount - feeExecuted`; `D` untouched (INV-2).
9. **`mintRecipient != adapter`** → assert revert (fail-fast) or (if not asserting) `minted == 0`, executor no-ops, no funds moved.
10. **`destinationCaller != adapter`** (constructed message) → `receiveMessage` reverts; assert adapter cannot process it.
11. **Executor reverts** (hook set that always reverts; `ARRAY_LENGTH_MISMATCH` via `dstTokens.length != intentAmounts.length`) → caught; USDC remains at `account`; event emitted; tx succeeds; nonce consumed, root unconsumed.
12. **Reentrancy hook** attempting to re-enter `receiveAndExecute` (or `claimFailedTransfer` in option B) with a second valid message → blocked by `nonReentrant`; assert revert and no double delivery.
13. **Blacklisted / reverting-on-receive `account`** (mock USDC that reverts transfer to a specific address) → option A: whole tx reverts (document stranding); option B: `failedTransfers[account][USDC]` credited, later `claimFailedTransfer` works and is reentrancy-safe.
14. **`intentAmounts` > delivered delta** (feeExecuted higher than user expected) → executor `_validateBalances` returns false → no-op; USDC sits at `account`, recoverable.
15. **`feeExecuted == 0` and `feeExecuted == maxFee` boundaries** → delta correct in both; INV-3 holds.
16. **Fork E2E** against real CCTP V2 `MessageTransmitterV2` on a supported chain (mirror `PendlePTHookE2E.t.sol` / Across E2E): full burn-on-source → attest → `receiveAndExecute` → hooks, asserting INV-1..6.
17. **Cross-bridge replay E2E:** deliver the same signed intent via Across *and* CCTP; assert hooks run once, tokens delivered by whichever lands first, second path no-ops on `usedMerkleRoots`.

---

## 6. One-line verdict
The design is sound **if and only if** three things hold: (1) the transfer amount is the **exact balance delta** of `receiveMessage` (never `balanceOf`-sweep, never gross `amount`) — this is the only place a stateless router can leak donated/in-flight funds; (2) message verification is **fully delegated** to the immutable `MessageTransmitterV2` with its return value checked and `destinationCaller`/`mintRecipient` bound to the adapter; and (3) the adapter holds **no approvals and makes no arbitrary calls from its own context**, keeping all untrusted execution inside the account via the executor. Replay is covered by the complementary CCTP-nonce (per-message) and executor-merkle-root (per-intent) guards. The remaining decision is statelessness vs. graceful stranding handling (§4.6).
