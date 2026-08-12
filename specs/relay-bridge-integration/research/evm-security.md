# Security Research Report: Relay (relay.link) Bridge Integration for Superform v2-core

**Scope:** Source-side Relay deposit hooks (ERC20 + native, immutable depository, hook-chained amounts); permissionless destination adapter (`decode(initData, sigData)` → forward funds → `failedTransfers` fallback → best-effort `processBridgedExecution`); and the primary path where Relay's solver calls `SuperDestinationExecutor.processBridgedExecution` directly.

**Primary reference:** `/Users/cosming/1.Coding/Superform/superform-specs/guidelines/solidity/vulnerabilities.md` (the vulnerability DB lives under `superform-specs/`, not `v2-core/`).

**Grounding code read:** `AcrossV3AdapterV2.sol`, `AcrossSendFundsAndExecuteOnDstHookV2.sol`, `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.sol`, `DebridgeAdapter.sol`, `SuperDestinationExecutor.sol`, plus the Stargate adapter security report (`specs/security-reports/2026-05-26-stargate-adapter.md`).

---

## 0. The single most important finding first

The Across and deBridge adapters are **caller-authenticated**: `AcrossV3AdapterV2.handleV3AcrossMessage` requires `msg.sender == ACROSS_SPOKE_POOL` (line 128), and `DebridgeAdapter` requires `msg.sender == externalCallAdapter` (line 46). That check is what makes the `amount`/`tokenSent` parameters *trustworthy* — the bridge itself only calls the callback after it has actually delivered the funds.

The Relay adapter, per the interview decision, is **permissionless and `msg.sender`-agnostic**. If it keeps the Across shape — take `(tokenSent, amount, message)`, transfer `amount` to `account`, and on failure credit `failedTransfers[account][tokenSent] += amount` — then **the trust that made the Across pattern safe is gone, but the accounting that relied on that trust remains.** This is the central risk of the whole integration. It is safe to let anyone *call* the executor (signature + balance anchor it); it is **not** safe to let anyone *assert an `amount` that mutates adapter state* (`failedTransfers`).

---

## 1. RELEVANT VULNERABILITY PATTERNS

### 1.1 Permissionless entry-point abuse / phantom-credit accounting — **CRITICAL for the adapter**
- **DB refs:** §2.1 Missing Access Control; §33.4 / §41.2 Message Replay via Missing Nonce; Stargate report **P2-2 "Balance-Based Accounting — Cross-User Dust Leakage."**
- If the adapter credits `failedTransfers[account][token] += amount` using a caller-supplied `amount` without proving receipt, any address can inflate a claimable balance for tokens it never delivered. Combined with real tokens that *other* users' fills leave transiently in the adapter, an attacker drains via `claimFailedTransfer`. This is the permissionless analogue of the Stargate P2-2 cross-user sweep, escalated from "dust leakage" to "arbitrary credit."
- Even without the claim path, a permissionless adapter that forwards `IERC20(token).safeTransfer(account, amount)` of *whatever the adapter happens to hold* lets a caller front-run a real fill and redirect/misattribute funds sitting in the adapter (§6.1 Transaction Ordering Dependence).

### 1.2 Native-transfer failure modes
- **DB refs:** §8.1 Unchecked Return Values; §10.6 Missing Zero-Address Checks (native to `address(0)` is *burned*, not reverted — Stargate report **P3-1**); Appendix H.2 Gas Stipend Manipulation; §18.4.2 Gnosis Native-Token Callback.
- Native send must use `call{value:}` (not `transfer`/`send` — 2300-gas stipend breaks smart-account receivers). `DebridgeAdapter.onEtherReceived` (line 77) sends `address(this).balance` and **reverts** on failure (`ON_ETHER_RECEIVED_FAILED`) — no pull fallback. For a permissionless native path this is both a balance-based-accounting bug (sweeps donated/residual ETH) *and* a fund-lock risk (a reverting recipient bricks the fill with no self-claim). The Relay adapter must (a) forward an *explicit recorded amount*, not `balance`, and (b) record a native `failedTransfers` entry instead of reverting.

### 1.3 try/catch OOG and returnbomb around the best-effort executor call
- **DB refs:** §13.1 Gas Griefing; §29.3 try/catch Decoding Failures; Appendix **H.1 Returnbomb** (Nomad research); §7.3 Block Gas Limit DoS.
- `AcrossV3AdapterV2` wraps the executor in `try … catch { }` (lines 163-173). `catch { }` with **no bound variable does not copy revert returndata into memory**, so the classic returnbomb is neutered on the catch side. Two residual risks:
  1. **63/64 OOG griefing (§13.1):** a griefer can size gas so the inner call consumes almost everything and the `catch`/post-catch logic runs out of gas, reverting the whole tx. Anchor the executor call with an explicit gas floor or ensure no critical state mutation happens *after* the try/catch.
  2. **Success-path decode:** `processBridgedExecution` returns nothing today; if a future signature returns data, `try … returns (…)` would move decode failures *outside* the catch (§29.3). Keep the callee returning nothing.

### 1.4 Calldata forgery / message-length validation
- **DB refs:** §29.4 Low-Level Call to Non-Existent Account; OWASP **SCWE-154 Calldata Decode Without Length Check**; §29.5 Dirty High-Order Bits.
- On a *permissionless* adapter, `message` is fully attacker-controlled. `abi.decode` on malformed/short data reverts (safe-ish), but attacker-chosen well-formed data with arbitrary `account`/`dstTokens`/`intentAmounts` reaches the executor — forgery is contained **only** because the executor re-derives `destinationData` and checks the signature. The adapter must not take any irreversible action (token move, state write) based on unauthenticated decoded fields *before* the executor validates. Mirror the Across hook's `destinationMessage.length >= 64` check.

### 1.5 Approval residue on the source hooks
- **DB refs:** §10.5 Approval Race Condition (SWC-114); §6.1; §47.x Modern Approval Patterns.
- The `ApproveAndAcross…` hook does the correct `approve(0) → approve(amount) → call → approve(0)` quadruple. The Relay `ApproveAnd…` variant **must** replicate the trailing reset; if the Relay depository pulls less than approved (partial pull), residual allowance is a standing risk. Use `forceApprove` semantics. The immutable-depository decision removes the "arbitrary approval target in hookData" class entirely.

### 1.6 Replay (intent, cross-chain, cross-bridge)
- **DB refs:** §16.1, §33.4, §39.2 Intent Replay, §40.1 Cross-Chain UserOp Replay, §21.4 Signature Replay Across Accounts.
- The executor binds `uint64(block.chainid)`, `account`, `address(this)`, `dstTokens`, `intentAmounts`, and `executorCalldata` into `destinationData` before signature check, and tracks `usedMerkleRoots[account][root]`. Strong anti-replay posture. Residual items:
  - **Cross-bridge replay** (documented SECURITY.md trade-off): balance check reads `balanceOf(account)` — a *snapshot*, not a delta. Harmless for fund-safety (root single-use per account) but "message delivery ≠ these specific funds arrived." The permissionless Relay path widens *who* can trigger, not *whether* exploitable.
  - **Order of checks (correct today):** balance check returns *before* marking root used — an underfunded replay does NOT burn the root. Preserve this ordering; reversing it would let a griefer burn a user's root with an underfunded call.

### 1.7 Front-running / griefing the destination
- **DB refs:** §6.1 TOD; §34.2; §40.2; SECURITY.md "front-running when marking roots as processed."
- An observer can front-run the solver's execute call. If funds are already at `account`, front-running just *completes the user's intent early* (benign). The exploitable variant is front-running the *adapter* to poison `failedTransfers` (§1.1) or consume a transiently-held balance (§1.2).

---

## 2. EXPLOIT PRECEDENTS

| Incident (DB ref) | Architecture parallel | Applies? | Why / why not |
|---|---|---|---|
| **Wormhole $326M** (§33.1, §41.3) — forged VAA | Forged bridge message accepted without full validation | **Mitigated by design** | Superform doesn't trust Relay's attestation for fund-safety; executor re-derives `destinationData` and verifies the user's own signature. Forged message → fails signature or balance check. |
| **Nomad $190M** (§33.3) — default Merkle root accepted | Merkle-proof validation with default-valid root | **Not applicable**, note pattern | The root is the *user's own signed intent*; per-account dedup. Verify `_decodeMerkleRoot` can't return `0x0` for empty sigData and be marked used (per-account so harmless, but assert it). |
| **Ronin $624M** (§16.1, §33.2) — validator key compromise | Trusting bridge signer set | **Outside Superform's trust boundary** | Relay Oracle/Allocator/solver compromise affects liveness and Relay's own escrow, not Superform user funds. Document in SECURITY.md as a Relay-side assumption. |
| **KelpDAO $292M** (DVN compromise) — transfers before validation | Adapter transfers funds *before* executor validates | **Partially applies** | Funds go to the *user's own account* (in the signed intent), so a forged message is not theft. The lesson that applies: **don't let "transfer before validate" act on attacker-chosen amounts/tokens** (§1.1). |
| **CrossCurve $3M** (§41.1) — receiver executes without `msg.sender == gateway` | The exact check the Relay adapter is *dropping* | **Design tension** | Superform substitutes *signature + balance* anchoring for *caller* anchoring. Valid **for execution authorization**, but does **not** authorize the adapter's *fund-forwarding/credit* logic — the adapter must forward only funds it provably received this call. |
| **Stargate adapter P2-2/P3-4** (internal) — balance-based transfer + open `receive()` sweeps residual tokens | Native `receive()` + `address(this).balance` forwarding | **Directly applies** | Use per-call recorded amounts, never `balanceOf(this)`/`address(this).balance`, exactly as Stargate was fixed. |

**Net:** signature+balance anchoring neutralizes classic bridge-theft precedents. What survives is the **adapter's own bookkeeping under untrusted input** (KelpDAO "act before validate," Stargate balance-based sweep) — and the permissionless decision amplifies exactly those.

---

## 3. ATTACK SURFACE MAP

### (a) Source-side deposit hooks
- **Approval residue** (§1.5): missing trailing `approve(0)`; partial pull leaves standing allowance.
- **Amount-chaining arithmetic** (`usePrevHookAmount`): Relay has no on-chain output field, so chaining reduces to `inputAmount = prevHook.getOutAmount(account)`. Guard `inputAmount == 0` revert; no division-by-zero in any ratio math.
- **Native value plumbing**: `value` must equal the sized amount; guard `value != 0` consistency vs `inputAmount`.
- **`destinationMessage` construction**: on the Relay path the message travels *off-chain in the `/quote txs[]`*, not origin calldata — confirm what the source hook must encode. If the source no longer carries the destination payload, the transient-storage sigData fetch may be dead code to remove.
- **Fee-on-transfer / rebasing**: explicitly unsupported; SafeERC20 + documented limitation.

### (b) The permissionless destination adapter
- **Phantom `failedTransfers` credit** (§1.1) — *the critical one*.
- **Transient-balance redirection**: funds delivered for user A swept toward user B's intent if forwarding uses `balanceOf(this)` or caller-chosen `account`.
- **Native handling** (§1.2): open `receive()`, balance-based forwarding, revert-on-fail without native `failedTransfers`, send-to-`address(0)` burn.
- **try/catch OOG** (§1.3) around `processBridgedExecution`.
- **Malformed/forged `message`** (§1.4).
- **DoS via `NO_DST_PROOF_FOR_CHAIN` revert**: fine on a permissionless adapter (costs the caller), but confirm a legitimate fill can't be griefed into this revert.
- **Reentrancy**: forward → executor → account `_execute` chain can re-enter the adapter; with mutable `failedTransfers` state, add `nonReentrant` on entry, not just claim.

### (c) Direct solver → `processBridgedExecution` path
- Authorization rests on: (1) `isValidDestinationSignature` over `destinationData`, (2) `_validateBalances`, (3) `usedMerkleRoots`. **Attack surface = completeness of `destinationData` binding.** Verify every attacker-variable field is inside the signed struct (executorCalldata is; dstTokens/intentAmounts can't be swapped for a cheaper token).
- **Balance-gate as snapshot** (§1.6): a third party can trigger execution the moment the account is funded — confirm no hook in the intent assumes it runs atomically after a specific fill.
- **Account creation** (`_validateOrCreateAccount`): verify `account == computedAddress` binding can't be bypassed; CREATE2 determinism prevents squatting but assert `initCode` is bound into the signature domain.

### (d) Trust boundary with Relay's solver / Oracle / Allocator
- **Fund-safety:** nothing in scope — signature+balance anchor everything.
- **Liveness/UX:** solver may not fill, fill wrong token/amount, fill late.
- **Escrow risk:** unfilled origin deposits sit in Relay's depository; refunds via Relay's off-chain Oracle/Allocator; no on-chain escape hatch. Document as trust assumption equal to Across/deBridge relayer liveness.

---

## 4. RECOMMENDED SECURITY PATTERNS

1. **Forward only provably-received funds (fixes §1.1).** Never trust caller-supplied `amount`. Measure adapter balance delta and credit only the delta — `failedTransfers` credited strictly from the adapter's *own measured* pre/post balance difference, never from an argument.
2. **Pull-payment fallback for ERC20 AND native.** `failedTransfers` keyed `token == address(0)` for native (matching the executor's convention). On failed native `call{value: recordedAmount}`, record instead of revert. Never forward `address(this).balance`.
3. **Native send via `call` with fallback record**, never `transfer`/`send`.
4. **Bounded, variable-less try/catch.** Keep `catch { }` (no bound var). Keep callee returning nothing. Critical state writes *before* the try; consider explicit gas floor vs 63/64 grief.
5. **Approval hygiene:** `approve(0) → approve(amount) → deposit → approve(0)`, `forceApprove`, immutable depository as sole spender.
6. **Message-length + shape validation** before `abi.decode`; `dstTokens.length == intentAmounts.length` in the adapter too.
7. **Zero-address guards:** `account != address(0)` — critical for native to avoid burn.
8. **`nonReentrant` on adapter entry and `claimFailedTransfer`.**
9. **Preserve executor check ordering** (balance → root-used → mark-used) so underfunded replays never burn a root.
10. **Document** the Relay liveness/escrow trust assumption in SECURITY.md, and the "balance-gate is a snapshot" cross-bridge-replay caveat.

---

## 5. PROTOCOL INTERACTION RISKS

- **No on-chain min-output on deposit.** If the solver fills less than quoted, `_validateBalances` fails closed — silent no-op, no root burn, funds sit at `account`. Mitigation: the bundler must encode `intentAmounts` at the *minimum acceptable* fill — treat `intentAmounts` as the on-chain min-output surrogate.
- **Wrong-token / dust fills.** Balance gate fails → no-op; wrong token stranded at `account` (user-recoverable, not protocol-guaranteed). Document.
- **Partial fills.** If fills split across solvers and never reach `intentAmounts`, execution never triggers. Bundler must not create intents depending on aggregating independent fills.
- **Front-running the adapter/executor.** Benign for fund-safety, except: (a) poisoning `failedTransfers` (fixed by measured-amount forwarding); (b) triggering execution the instant the account is funded.
- **Residual/donated funds in the adapter.** Must never be sweepable by a later caller (Stargate P2-2/P3-4). Per-call recorded amounts close this.
- **Idempotency.** Bundler must never reuse a root across two Relay quotes (second becomes a guaranteed no-op, stranding the second fill).

---

## 6. TESTING RECOMMENDATIONS

**Invariants:**
1. **No stranded funds without a claim path:** every value the adapter receives either reaches `account` exactly or is credited to `failedTransfers[account][token]` exactly (ERC20 and native). Forwarded + claimable == total received.
2. **Executor never executes without balance;** underfunded call returns without setting `usedMerkleRoots`.
3. **Replay harmless:** identical args twice → executes at most once; underfunded first call does not burn the root.
4. **`failedTransfers` conservation:** credited == claimed + outstanding; per-account isolation.
5. **Permissionless-caller safety:** for any `msg.sender`, no sequence of adapter calls yields tokens the caller did not deliver (adversarial invariant with attacker actor).
6. **Approval residue:** after any source-hook execution, allowance(account → depository) == 0.

**Fuzz scenarios:**
- Malformed `message`: random bytes, truncated tuples, wrong arity, length mismatches, `account == address(0)`, `intentAmount == 0`, oversized arrays, **returnbomb** mock executor.
- Caller-supplied `amount` fuzz with adapter holding 0 / partial / exact / excess balance — assert invariants #1 and #5 (phantom-credit test).
- Native fills: reverting recipient, gas-consuming recipient, donated ETH in adapter, reentrant recipient.
- Amount-chaining: `inputAmount == 0`, prevHook returning 0 / max uint, FoT mismatch.
- Solver mis-fill matrix: short amount, wrong token, dust, over-fill — assert safe no-op.

**Fork / e2e:**
- Fork tests against real deployed Relay depository/receiver (verify actual signatures from Relay docs — don't guess).
- Cross-chain e2e via a new pigeon Relay module simulating solver `txs[] = [deliver funds → processBridgedExecution]`, including the *reordered* case (execute before funds arrive) proving the balance gate no-ops safely.
- Regression parity with Across/deBridge adapter test suites on the shared executor.

---

## Summary of prioritized findings

| # | Finding | Severity | Section |
|---|---|---|---|
| 1 | Permissionless adapter + caller-supplied `amount` → phantom `failedTransfers` credit / cross-user drain | **Critical** | §1.1, §3(b), §4.1 |
| 2 | Native forwarding via `address(this).balance` + revert-on-fail (no native pull-fallback) | **High** | §1.2, §4.2-4.3 |
| 3 | try/catch 63/64 OOG griefing around `processBridgedExecution` | Medium | §1.3, §4.4 |
| 4 | Approval residue on source `ApproveAnd…` variant | Medium | §1.5, §4.5 |
| 5 | No on-chain min-output → solver under-fill silently no-ops; `intentAmounts` must encode true minimum | Medium | §5 |
| 6 | Malformed/forged `message` acting before executor validation | Medium (contained) | §1.4, §4.6 |
| 7 | Balance-gate snapshot enables benign cross-bridge replay / early-execution front-running | Low (documented) | §1.6, §1.7 |

The core assurance holds: **signature + balance anchoring keeps user funds safe even with a fully malicious Relay solver and a permissionless adapter caller.** The real risk concentrates in the **adapter's own bookkeeping under untrusted input** (finding #1) and **native-value handling** (finding #2); fix those with measured-amount forwarding and a native pull-payment fallback, and the integration inherits the Across/deBridge safety profile.
