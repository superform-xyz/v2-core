# Spec-flow analysis — `CircleGatewayAdapter`

Source: spec-flow analysis, 2026-09-23. Baseline is interview-notes.md **as revised by the "Post-research
decisions" addendum** (line 76+), which overrides Rounds 1-4 where they conflict. Cross-checked against
`src/adapters/CCTPAdapter.sol` (template) and `lib/evm-gateway-contracts/src/modules/minter/Mints.sol` (minter).

Convention: **GAP** = missing/underspecified behavior the technical-spec must resolve. **QUESTION** = needs an
answer from Cosmin/Circle/SDK before implementation, not resolvable by reading the repo.

---

## Flow 1 — Happy path, single attestation, existing account

**Actors:** user's smart account (already deployed), SDK (built the burn intent, obtained attestation), relayer,
Circle (minter), SuperDestinationExecutor/Validator.

**Preconditions:** account already has code; `destinationRecipient = destinationCaller = adapter`;
`destinationToken = USDC`; `hookData` = valid 6-tuple; `account` decodes to the real account; attestation not
expired (`maxBlockHeight >= block.number`); hash unused; minter not paused; adapter/account not denylisted/blacklisted.

**Steps:** relayer calls `receiveAndExecute(payload, signature)` → adapter pre-mint checks (magic, spec magic/version,
length, `destinationContract==GATEWAY_MINTER`, `destinationDomain==domain()`, caller∈{adapter,0}, recipient==adapter,
token==USDC, hookData decodes, `account∉{0,adapter}`) → `gatewayMint` → delta measured (`post-pre`), cross-checked
against `Σvalue` (=`value` for n=1) → funds transferred to account → gas floor check → `processBridgedExecution`.

**Success:** `TransferSucceeded(account, USDC, minted)`; `SuperDestinationExecutorExecuted`; no `ExecutionFailed`.

**Failure branches:** any pre-mint check fails → revert, hash unused, attestation expires in ~10 min, off-chain
balance restored, SDK/user must re-sign with a fresh `salt`. Post-mint: transfer fails → escrow to account
(`TransferFailed`); execution reverts → `ExecutionFailed(account, selector)`, funds still delivered.

**GAP:** none — this is the fully-specified path. Confirms the baseline the other flows deviate from.

---

## Flow 2 — First-time account (initData)

**Actors:** same as Flow 1, but `account.code.length == 0` at delivery time.

**Steps:** identical mint/measure/pass to `processBridgedExecution`, which internally does
`_validateOrCreateAccount`: `initData.length > 0 && account.code.length == 0` → CREATE2-deploys via
`abi.encodePacked(senderCreator, factory, factoryCalldata)`, else `ACCOUNT_NOT_CREATED`.

**Ordering fact carried from CCTP:** USDC is transferred to the counterfactual address **before** the account
exists (step 4 of `receiveAndExecute` runs before the executor is even called) — this is safe only because the
address is a deterministic CREATE2 target the SDK computed off-chain and USDC transfers do not require code at
the recipient.

**Failure branches:** `initData` garbage / factory reverts → `_createAccount` reverts → `processBridgedExecution`
reverts entirely → adapter's `try/catch` swallows it → `ExecutionFailed(account, selector)`; USDC is **already at
the (still codeless) address** — stuck there until a valid `initData` is delivered by a *direct* re-drive of
`processBridgedExecution` (permissionless, per repo-analysis §5) with corrected calldata, since the merkle root
never got marked used (the whole executor call reverted).

**GAP:** `initData` is inside the *signed* `sigData`/executor-calldata bundle authored once by the SDK — if the
factory/salt logic was wrong at signing time, there is **no way to correct `initData` and still match the signed
root** (a different `initData` changes the leaf). The only recovery is a **brand-new signed intent** (new root),
which requires the user to sign again — but the USDC is already sitting at the (uncreated) address from the
*first* attempt. Does the second intent's SDK-computed factory/salt still resolve to the **same** counterfactual
address so the stranded USDC becomes spendable once the corrected `initData` lands? If not, this is a stuck-funds
class distinct from anything CCTP documents. **QUESTION for the technical-spec.**

**GAP:** no adapter-level check that `account` (decoded from hookData) actually matches the CREATE2 address that
`initData` would produce — that check lives entirely in `SuperDestinationExecutor._createAccount`
(`INVALID_ACCOUNT` on mismatch). Confirm this errors into the same bare-catch `ExecutionFailed` path (it does,
per repo-analysis) and that funds (already delivered pre-execution) are not otherwise affected.

---

## Flow 3 — AttestationSet, N source chains, identical routing

**Decision in force (overrides Round 1):** accept a set iff **every** member has
`destinationRecipient=destinationCaller=adapter`, identical `destinationToken` (USDC), and byte-identical
`hookData`; measure **one** delta around the single `gatewayMint` call, cross-check against `Σvalue`, deliver
once, execute once. Any other set → pre-mint `ATTESTATION_SET_MIXED`.

**Steps:** adapter walks the set via `AttestationLib.cursor`/`next` over calldata-copied-to-memory bytes,
extracting each member's recipient/caller/token/hookData-hash and comparing to the first member's, **before**
calling `gatewayMint`. On match: single `gatewayMint(payload, signature)` call (Circle's own loop validates and
mints each member individually inside that one call); one delta; one `_tryTransfer`; one
`processBridgedExecution`.

**Failure branches / edge cases named in the brief:**

- **Specs differ in hookData/token/recipient/caller** → rejected pre-mint (`ATTESTATION_SET_MIXED`), hash(es)
  untouched, all members expire independently and restore off-chain balance per-source. **GAP:** the error carries
  no index/reason — an indexer/relayer cannot tell *which* member differed without re-parsing the calldata
  themselves. Should `ATTESTATION_SET_MIXED` take an index argument (mirroring `Mints.sol`'s `*AtIndex` errors)?
- **One spec of the set is expired, or already used** → `gatewayMint` reverts mid-loop
  (`AttestationExpiredAtIndex`/`TransferSpecHashUsed`) inside the **single external call**; the revert unwinds
  the *entire* `receiveAndExecute` transaction, including any hash-marking Circle's loop had already done for
  **earlier, otherwise-valid members** in the same set. Net effect: an N-source unification is entirely blocked
  by one bad member — none of the N attestations get consumed, all N wait out their own expiry and restore
  balance. **GAP/QUESTION:** what should the relayer/SDK do here? Resubmitting the identical payload will fail
  identically until every member's `maxBlockHeight` passes; there is no way to "drop" the bad member from an
  already-signed, already-attested set (the signature covers the whole payload). Does the SDK need a documented
  wait-for-full-expiry-then-resign runbook step specifically for sets, distinct from the single-attestation retry
  story?
- **Partial sets** (deliver what you have now, defer the rest) — **not supported by construction**: a set is one
  signed payload / one signature / one `gatewayMint` call. The only way to get partial delivery is for the SDK to
  request **N independent single-attestation** burn intents instead of one `BurnIntentSet`, each landing (and
  executing) separately. **QUESTION (architecture-level, not just a gap):** should Superform's SDK prefer N
  single-attestation submissions (independently retriable, but then `intentAmounts`/execution must tolerate
  **partial** funding arriving across multiple `receiveAndExecute` calls — a scenario the current design does not
  address: does the executor's balance gate + one-shot merkle-root-use model support "deliver, no-op because
  balance insufficient, deliver more later, then execute"? Per repo-analysis §5 `_validateBalances` is a **silent
  no-op**, not a queued retry — so a second, later delivery reaching sufficient balance would need to redrive
  `processBridgedExecution` itself, which is permissionless, so this actually works) vs one atomic
  `AttestationSet` (simpler semantics, all-or-nothing fragility as above)? This decision is currently unmade and
  materially changes both the adapter's set-handling code and the SDK.

**GAP:** gas/stack cost of walking a set of up to 16 members (`BurnIntentSet` max, per best-practices §1.1) purely
in the adapter's pre-mint validation loop, given `via_ir` is OFF in the default profile (repo-analysis gotcha #1).
Needs a concrete worst-case gas measurement before committing to "compare every member pre-mint."

---

## Flow 4 — Pre-mint rejections (fail fast)

All of the following are **calldata-only** checks performed **before** any external call, per the post-research
decision. For every one of them the user-visible effect is identical and needs to be stated once in the spec
rather than per-check:

| Check | Adapter behavior |
|---|---|
| bad attestation/spec magic, wrong version, length mismatch | revert (typed error) |
| set mixed (see Flow 3) | revert `ATTESTATION_SET_MIXED` |
| wrong `destinationContract`/`destinationDomain` | revert |
| third-party `destinationCaller` (≠ adapter, ≠ 0) | revert `DESTINATION_CALLER_MISMATCH` |
| recipient ≠ adapter, unpinned (caller = 0 too) | revert (not ours to relay) |
| non-USDC `destinationToken` | revert (dropped: no longer escrowed — see contradiction list) |
| undecodable hookData | revert (dropped: no longer escrowed — see contradiction list) |
| `account == 0` / `account == adapter` | revert (dropped: no longer escrowed — see contradiction list) |
| `value == 0` | left to the minter (`AttestationValueMustBePositiveAtIndex`) unless pre-checked for legibility |

**Recovery for every row above:** relayer's tx reverts (relayer pays gas, user pays nothing); Circle's off-chain
ledger balance was already decremented at attestation-issuance time and is untouched by an on-chain revert; the
attestation itself sits unconsumed until `maxBlockHeight` passes (~10 min), at which point the ledger restores the
balance; the user (via SDK) must sign a **new** `BurnIntent` (new `salt`) — the identical payload can never
succeed if the failure is a permanent malformation (wrong version, wrong domain, etc.), only if it was a transient
one (attestation not yet valid, wrong-signer-at-the-time).

**GAP — observability:** none of these fail-fast reverts emit an event (revert unwinds any logs too), so **the
only way to see a pre-mint rejection is to watch failed transactions to `receiveAndExecute`**, not the event log.
Section "events/state needed for observability" below flags this as a hard requirement, not a nice-to-have.

**GAP — SDK's job:** the SDK authors the exact spec, so every row above is really "SDK produced a spec the adapter
will reject." Should the SDK **client-side simulate** these same checks before ever asking the user to sign, so a
malformed intent never reaches the ~10-minute round trip in the first place? (Listed explicitly in the SDK
obligations checklist below.)

**QUESTION:** is `minter.domain()` ever mutable after chain-initialization (i.e., could a live chain's domain
change post-deploy, invalidating a cached construction-time check)? Interview notes Round 3 says construction
sanity is "`minter.domain()` set" — if an implementer reads that as `domain() != 0`, it will **hard-break on
Ethereum** (`domain()==0` there, confirmed live). The repo-analysis gotcha (#4) already contradicts the Round 3
phrasing; the technical-spec must use the gotcha's wording verbatim, not Round 3's.

---

## Flow 5 — `destinationCaller = 0`: honest relay vs. stray direct mint, and `recoverDirectMint`

**5a. Relayed through the adapter (accepted, flagged).** `destinationCaller == 0` in the spec means *any* caller
satisfies the minter's `destinationCaller == 0 || == msg.sender` check — including the adapter itself when it
calls `gatewayMint` from inside `receiveAndExecute`. This succeeds normally (mint → deliver → execute) and emits
`MisconfiguredMessageRelayed(kind=1, mintRecipient)` — a signal that the SDK failed to pin `destinationCaller`
(should never happen in steady state; a monitoring alert, not a user-facing failure).

**5b. Pushed directly by a stranger through `gatewayMint`.** Same spec (`destinationCaller=0`,
`destinationRecipient=adapter`), but someone calls `GatewayMinter.gatewayMint(payload, signature)` **directly**,
bypassing the adapter entirely. `hookData` is never read by the minter (confirmed in `Mints.sol` and
best-practices §1.2), so USDC lands in the adapter contract, the hash is marked used, `AttestationUsed` fires —
and **nothing else happens**: no delivery, no execution, no adapter event (the adapter was never `msg.sender`).

**`recoverDirectMint(payload, signature)` — who/what/how:**
- **Who calls it:** permissionless (anyone can supply the same payload+signature that already succeeded on the
  minter — it's public information, replayed from `AttestationUsed` or Circle's API).
- **What it verifies:** re-derives the signer itself (`ECDSA.recover(keccak256(payload).toEthSignedMessageHash())`
  ∈ `isAttestationSigner`) — it does **not** trust that the mint happened, it independently re-checks the
  signature; requires `minter.isTransferSpecHashUsed(hash) == true` (proof the mint really occurred — if false,
  this isn't a stray mint, it's just an unconsumed attestation, and the correct call is `receiveAndExecute`, not
  this); requires `!processed[hash]` in the adapter (own idempotency); recipient == adapter; token == USDC;
  hookData decodable.
- **What it forwards:** `min(Σvalue, spendable)` where `spendable = balanceOf(this) − Σescrow` (total pending
  escrow liabilities across all accounts/tokens) — i.e., it never dips into money already owed to someone else's
  `failedTransfers` claim or into a prior stray-mint's un-recovered balance.
- **Idempotency:** marks `processed[hash]`; **`receiveAndExecute` must also mark `processed[hash]` on its own
  success path**, so a spec that was properly relayed can never later be "recovered" a second time (the interview
  notes call this out explicitly — it is a cross-cutting invariant, not just a `recoverDirectMint`-local one).

**GAP — set interaction, unaddressed by the interview notes:** the phrasing "forwards `min(Σvalue, spendable)`"
uses `Σ`, implying `recoverDirectMint` **also** supports a stray-minted `AttestationSet` (someone called
`gatewayMint` directly with a whole set pinned to the adapter, `destinationCaller=0`). But the "identical routing"
consistency rule (same recipient/caller/token/hookData across members) was specified **only** for
`receiveAndExecute`'s pre-mint validation (Flow 3) — it is never restated for `recoverDirectMint`, which by
definition runs **after** the mint already happened (it cannot reject a member pre-mint; the mint is done). Does
`recoverDirectMint` need its own set-parsing + per-member `isTransferSpecHashUsed`/`processed` bookkeeping (marking
**each** member's hash individually, since a set direct-mints all-or-nothing but recovery could plausibly be
requested one member at a time by different callers racing each other)? This is unresolved and materially affects
the function's complexity (full `AttestationLib` set-cursor parsing under a non-`via_ir` profile — stack-depth
risk, per repo-analysis gotcha #1).

**GAP — spendable < Σvalue.** Named explicitly in the brief. Concrete sub-cases:
- *Someone else's donation already consumed?* A raw ERC20 `transfer` into the adapter (not via `gatewayMint`) adds
  to `balanceOf(this)` but is not a liability, so it can only ever **increase** `spendable`, never decrease it —
  not the source of a shortfall.
- *Multiple direct mints interleaved with relays:* if the adapter has already forwarded/escrowed money from an
  **earlier** relay or recovery, `Σescrow` reflects that, correctly shrinking `spendable` for a **later**
  recovery — this is the mechanism working as intended, not a bug, but means a **later** stray-mint's recovery can
  legitimately be short-changed if the adapter's balance was drawn down by unrelated escrow claims in between.
- *Ordering games between two direct mints:* two different destinationCaller=0 specs are both stray-minted to the
  adapter (balance = value1+value2, no other liabilities yet); recovering hash A first forwards `min(value1,
  value1+value2) = value1`; recovering hash B afterward forwards `min(value2, value2) = value2` — correct, no
  double-spend, order-independent as designed.
- **Unresolved: what happens to the shortfall when `spendable < Σvalue`?** The interview notes only say "forwards
  `min(Σvalue, spendable)`" — they do not say what happens to the **unforwarded difference**. Does it get credited
  to `failedTransfers[account][USDC]` so it becomes claimable once more USDC arrives at the contract later (e.g.
  from a subsequent unrelated relay), or is it simply lost track of (no bucket owns it, and a later `spendable`
  recovery of it is not obviously possible since `processed[hash]` is already set after the first partial
  recovery)? **This needs an explicit answer before implementation** — right now a partial recovery looks like it
  silently strands the shortfall permanently once `processed[hash]` is set.
- **GAP:** should there be a distinct `PartialRecovery(account, requested, forwarded)` event so this condition is
  visible off-chain, distinct from a full `TransferSucceeded`-equivalent?
- **GAP:** what if Gateway ever supports a non-USDC token (open research question Q9) and a stray mint happens for
  that token? `recoverDirectMint` explicitly requires "token USDC" per the interview notes — a non-USDC stray mint
  today is moot (Gateway is USDC-only everywhere) but has **zero** recovery path if this ever changes, since
  neither `receiveAndExecute`'s escrow (removed) nor `recoverDirectMint` (USDC-gated) would catch it. Flag as a
  documented limitation to revisit if Q9 resolves positively.

---

## Flow 6 — Pinned to adapter, `destinationRecipient` = someone else (pass-through), and set interaction

**Steps:** `destinationCaller == adapter` (pinned, satisfies the minter's caller check when the adapter itself
calls `gatewayMint`), but `destinationRecipient` is a **different** address. The adapter still calls `gatewayMint`
(it is the only party who ever could, since it's pinned) but the mint lands on the other recipient — the adapter's
own USDC balance is untouched, no forward/execute is attempted, `MisconfiguredMessageRelayed(kind=2,
mintRecipient=<other>)` fires. This is the CCTP F2 pattern verbatim (never strand a pinned burn just because the
mint target differs from the adapter).

**Interaction with sets (already covered in Flow 3, restated for completeness):** the set-acceptance rule requires
`destinationRecipient == adapter` for **every** member. A set containing even one "pinned caller, foreign
recipient" member therefore fails the homogeneity check and the **whole set** is rejected pre-mint
(`ATTESTATION_SET_MIXED`) rather than gracefully passed through — there is no member-level pass-through for sets,
only for single attestations. **GAP (documentation, not a bug):** this must be called out explicitly as an SDK
constraint — a multi-source `BurnIntentSet` can never mix "route to adapter" and "route elsewhere" members; the
SDK must build homogeneous sets or fall back to per-source single attestations.

---

## Flow 7 — Post-mint delivery failure, execution failure, gas starvation

**7a. Delivery failure (account USDC-blacklisted).** Mint succeeds; `_tryTransfer(account, minted)` fails
(low-level call returns false/non-bool word); escrow to `failedTransfers[account][USDC]`, `TransferFailed`. Once
Circle/Centre unblacklists the account, the account itself must call `claimFailedTransfer(USDC, amount)` —
**`msg.sender`-gated only, no `to` parameter** (mirrors the audited `CS-CSpend-018` fix: never let a claim be
redirected). **GAP:** a smart-contract account that was blacklisted has no *other* path to reach its own escrowed
balance except calling this function itself (via its own userOp/execution) — confirm the runbook explicitly tells
users/support "wait for unblacklist, then have the account call claimFailedTransfer directly"; there is no
relayer/proxy-claim mechanism and none should be added (audit precedent).

**7b. Execution failure → direct re-drive.** `processBridgedExecution` reverts (executor-side revert, e.g. hook
failure) → adapter's bare `catch` emits `ExecutionFailed(account, selector)`; because the executor's own call
reverted, the merkle-root "used" write unwinds with it, so the root is **still unused** and `processBridgedExecution`
is permissionless — **anyone** can re-submit the identical calldata directly against the executor later (funds are
already at the account from the delivery step, unaffected by the execution retry).

**7c. Gas starvation below the 2M floor.** `if (gasleft() < MIN_EXECUTION_GAS) revert INSUFFICIENT_GAS();` is a
**plain revert**, not inside a try/catch — this unwinds the **entire** `receiveAndExecute` call, including the
mint and the transfer that had already succeeded moments earlier. Net effect: the attestation hash is **unmarked**
again (the whole external call to it via `gatewayMint` gets rolled back too), so the spec is retriable by anyone
supplying more gas, or it simply expires and the balance restores off-chain. This differs from CCTP's rationale
(there, "starvation past the floor is not a loss" because the burn is irreversible and the message survives
regardless) — here it is **still not a loss**, but for a *different* reason (mint fully reversible pre-expiry), and
the floor's placement *after* the (variable-cost) mint is unavoidable (you cannot know true remaining gas before
paying for the mint).

**GAP/QUESTION — sustained gas-starvation griefing.** "What if the relayer keeps starving until expiry?" A griefer
who front-runs every legitimate relay attempt with a gas limit that clears the mint but not the floor forces
*every* attempt within the ~10-minute window to revert, denying delivery entirely for that window (the user then
has to wait for expiry + re-sign). Unlike a pure-calldata pre-mint rejection, **this cycle costs the griefer real
gas each time** (they still pay for a successful `gatewayMint` call before hitting the floor and reverting), which
bounds but does not eliminate the attack. Is this an accepted risk (documented: "worst case, funds are never at
risk, only delayed — legitimate relayers should submit via a private/non-public mempool channel to avoid
front-running, and/or race with a generous gas limit"), or does it need an explicit mitigation in the runbook (e.g.
recommend Flashbots-style private submission for the production relayer)? **Needs an explicit answer, not left
implicit as it currently is.**

---

## Flow 8 — Circle-side outages

| Outage | On-chain effect | What expires | What is stuck |
|---|---|---|---|
| Minter paused | `gatewayMint` reverts `EnforcedPause()` for every call | in-flight attestations, each on its own `maxBlockHeight` | escrowed `failedTransfers` balances (no expiry mechanism at all) |
| Adapter denylisted (as `msg.sender`, i.e. caller) | every `receiveAndExecute` reverts `AccountDenylisted` | same as above | same as above |
| Adapter denylisted (as `destinationRecipient`) | same modifier hits the same address (adapter is both caller and recipient in the normal path) — a single denylist entry causes total outage either way | same | same |
| Adapter USDC-blacklisted | `gatewayMint`'s internal `mint(adapter, value)` reverts (FiatToken `notBlacklisted(_to)`) | in-flight attestations | **escrowed balances become doubly stuck**: `claimFailedTransfer`'s `safeTransfer(msg.sender, amount)` also fails while the adapter itself is blacklisted, even after the *account*'s own blacklist (if any) is lifted |
| Attestation signer rotated mid-flight | any attestation signed by the **removed** signer permanently fails `InvalidAttestationSigner()` on every future attempt with that exact payload (minter checks the *current* signer set, not the set at signing time) | that specific attestation, at its own `maxBlockHeight` — no re-signing with the old key will ever help | nothing new stuck; just a longer wait |
| Minter upgraded (new ABI/wire version) | if `TRANSFER_SPEC_VERSION` bumps, the adapter's own version check correctly pre-mint-rejects the **new**-format specs (safe), but the adapter becomes permanently non-functional for the new format since it is immutable | old-format in-flight attestations may still process normally if the old call surface is preserved | nothing new, but a **new adapter deployment is required**, not a patch — must be a runbook/monitoring item |

**GAP (flagged explicitly in the brief, and confirmed genuinely unaddressed):** the escrow map (`failedTransfers`,
keyed by account only per the post-research decision) has **no expiry, no admin rescue, and no bound** — it is the
one state in this whole design that is **not** protected by Circle's 10-minute self-healing mechanism. A
denylist/blacklist/pause hitting the adapter *after* escrow has already accumulated freezes that escrow
indefinitely, with recovery depending entirely on Circle lifting the restriction (ownerless/immutable adapter, no
admin path — consistent with every other Superform adapter, but worth stating as an explicit, monitored risk
rather than an implicit one). Runbook item: **keep escrow small** (monitor `Blacklisted(adapter)`,
`Denylisted(adapter)`, `Paused` and alert/pause relaying, not just reactively investigate after the fact).

---

## Flow 9 — Same-domain transfer (`sourceDomain == destinationDomain`)

Minter adds one extra check for this case only: `sourceToken == destinationToken`. Handled entirely inside
`_validateAttestationTransferSpec` — the adapter needs **no special-casing**: it receives a normal
`AttestationUsed` mint and proceeds exactly as in Flow 1. Circle's own audit (`CS-CSpend-002`) already fixed the
non-custodial-property bug for same-domain via a mint-then-burn refactor at the protocol level.

**GAP (low priority):** confirm the technical-spec states explicitly that same-domain is a no-op distinction for
the adapter (so a reviewer doesn't go looking for special handling that shouldn't exist) — worth one line in the
spec purely to close the question, not because behavior needs to change.

---

## Flow 10 — Replay / race conditions

- **Two relayers submit the same payload.** Second one to land hits `TransferSpecHashUsed` inside `gatewayMint`,
  which is not try/catched, so the whole second `receiveAndExecute` call reverts — no double mint, second relayer
  simply loses their gas. **GAP:** should the adapter expose a cheap `isRecoverable`/pre-flight view wrapping
  `minter.isTransferSpecHashUsed` so relayer infra can avoid the doomed second submission before broadcasting? (The
  minter's own public view already covers this — likely not needed as an adapter-level addition, but worth
  confirming the relayer's off-chain code actually uses it.)
- **A relayer submits after Circle's expiry.** `AttestationExpiredAtIndex` reverts inside `gatewayMint`; safe,
  hash unused, no adapter-specific concern (equality at `maxBlockHeight` is allowed, standard off-by-one already
  handled by the minter).
- **Executor's root already used (pre-funded account, early execution) → silent no-op.** Inherited from CCTP (I4).
  If some *other* leg of a multi-chain intent (or an attacker/self pre-funding the account and triggering an early
  redundant execution) marks the same merkle root used before the Gateway delivery lands, `processBridgedExecution`
  returns normally without reverting (`ReceivedButRootUsedAlready` on the **executor**, not the adapter) — funds
  are still delivered (mint+transfer happen unconditionally before the execution step), but no `ExecutionFailed`
  fires either, because there was no revert. **GAP:** monitoring must watch `ReceivedButRootUsedAlready` on the
  executor, not just adapter events, to distinguish this "delivered, execution silently skipped" state from a
  genuine `ExecutionFailed`. Confirm this is an accepted, documented risk for Gateway too (it already is for CCTP),
  not a new concern — but Gateway's escrow semantics changed enough (account-only keying) that it's worth
  re-confirming nothing about the silent-no-op path interacts badly with the new escrow model. (It doesn't: no
  escrow event fires on this path either way, funds simply sit at the account.)
- **`sigData.validUntil` already passed by delivery time.** Unlike the balance-gate/root-used/no-hooks paths, a
  validator rejection **reverts** `processBridgedExecution` (not a silent no-op) → caught by the adapter's bare
  catch → `ExecutionFailed(account, selector)`. Because `validUntil` is baked into the signed root and is now
  permanently in the past, **no future re-drive of the same calldata will ever succeed** — this is a dead end,
  distinct from the OOG/hook-revert case which *is* retriable. **GAP/QUESTION:** should the SDK be required to set
  `validUntil` with a buffer large enough to cover Gateway's ~10-minute attestation window **plus** relay latency,
  and does the technical-spec need to say this explicitly (a validUntil sized for same-chain/CCTP-speed delivery
  will systematically fail for Gateway-routed intents)? This is a real, currently-undocumented cross-adapter
  constraint the SDK must apply differently depending on which bridge an intent uses.

---

## Flow 11 — Deployment / ops

- **Adapter address differs per chain** (GatewayMinter is the *same* address on every EVM chain, but USDC and the
  executor differ, so CREATE2 args — and therefore the adapter address — differ per chain). **GAP/QUESTION:** how
  does the SDK discover the correct per-chain adapter address — a static config file (mirroring
  `ConfigCore.usdcs`), an on-chain registry (`SuperRegistry`?), or a deploy-output artifact? Not stated anywhere in
  the research; needs an explicit answer before SDK work starts.
- **User picks a destination chain where the adapter isn't deployed.** Must be blocked in the SDK/UI **before** any
  signing happens (there is no adapter to reject the request; it would simply never get delivered and the user
  would burn a source-chain gas fee for an attestation that will time out with no destination path at all — worse
  than a clean pre-mint revert, since here nothing on the destination side ever runs to explain why). **GAP:**
  confirm the SDK's destination-chain list is generated from the **same** availability source as the deploy
  script's `gatewayMinters[chainId]`/`usdcs[chainId]` gate, so the two can't drift.
- **Gateway not live on a chain where the adapter is deployed.** Should be structurally prevented by the
  constructor sanity checks (`minter.code.length != 0`, `isTokenSupported(usdc)`) — a deploy attempt on such a
  chain reverts at construction, never producing a broken adapter. **GAP:** confirm the deploy script's
  `_getContractAvailability`/`potentialSkips` gate is keyed on the *same* two conditions so a misconfigured
  `usdcs[chainId]` entry (Gateway not live there) can't sneak an adapter deployment through with a plausible-looking
  but wrong `usdc` address that happens to pass `isTokenSupported` for an unrelated reason. Also: **what is the
  process when Circle launches Gateway on a *new* chain after our deploy script has already run everywhere else**
  — is there a documented "add one new chain" runbook distinct from the initial rollout?

---

## Flow 12 — Monitoring / observability

**Events an indexer needs, and what each does/doesn't prove:**

| Event | Proves | Does NOT prove |
|---|---|---|
| `TransferSucceeded(account, USDC, amount)` | delivery succeeded | execution ran (executor may have silently no-opped) |
| `TransferFailed(account, USDC, amount)` | delivery failed, escrowed | — |
| `ExecutionFailed(account, selector)` | execution reverted (funds already delivered) | that it's retriable (validUntil-expired failures are not, OOG/hook-revert failures are) — **the event alone cannot distinguish these two cases**; an indexer needs the selector decoded against the validator's own error set |
| `DestinationTargetMismatch(account, code)` | intent signed for a different executor/validator deployment | — |
| `MisconfiguredMessageRelayed(kind, mintRecipient)` | SDK/backend bug (kind=1 unpinned, kind=2 pinned-but-mints-elsewhere) | — |
| `FailedTransferClaimed` | escrow successfully paid out | — |
| *(new, needed)* recovery event for `recoverDirectMint` | a stray direct mint was recovered | distinguishing full vs. partial recovery — needs the `PartialRecovery`-style event proposed in Flow 5 |
| `SuperDestinationExecutorExecuted` / `...ReceivedButNotEnoughBalance` / `...ReceivedButRootUsedAlready` / `...ReceivedButNoHooks` (executor-side) | which of the three silent no-op paths occurred, or genuine execution | — must be watched **in addition to** adapter events; `ExecutionFailed` alone is not sufficient to know "did anything happen" |
| Minter's `AttestationUsed(token, recipient, transferSpecHash, sourceDomain, sourceDepositor, sourceSigner, value)` | a mint of this spec occurred, and to whom | whether it went through the adapter's normal path or was a stray direct mint |

**"Kind-1 leakage" detection** (named explicitly in the brief): correlate, in the **same transaction**,
`AttestationUsed(recipient=adapter, ...)` on the minter against **any** adapter-emitted event
(`TransferSucceeded`/`TransferFailed`/`MisconfiguredMessageRelayed`/a future recovery event). If the mint happened
with **no** paired adapter event in that tx, it was a direct `gatewayMint` call bypassing the adapter entirely —
the `transferSpecHash` from `AttestationUsed` is the key to check `processed[hash]` on the adapter before
triggering `recoverDirectMint`. **GAP — implementation requirement, not just an indexer nicety:** `processed`
must be a `public` mapping (or have a public getter) so an indexer/bot can check it cheaply before calling
`recoverDirectMint`, avoiding a wasted call against an already-recovered or already-relayed hash.

**GAP — pre-mint rejections are invisible to event-based monitoring.** Every check in Flow 4 reverts with **no**
event (a revert unwinds any logs emitted earlier in the same call too), so the *only* way to catch "the SDK is
producing malformed specs" is to watch **failed transactions** to the adapter's `receiveAndExecute` selector, not
its event log. This must be an explicit requirement in the observability section of the technical-spec, since
every other adapter in this codebase can mostly be monitored via events alone.

---

## Consolidated findings

### (a) Edge cases the acceptance criteria must add
1. `ATTESTATION_SET_MIXED` semantics: which member differs (token/recipient/caller/hookData), and whether the
   error carries an index.
2. Full 2×2 enumeration of (recipient=self/other) × (caller=adapter/zero) for a **single** attestation — the
   current three-bullet "recipient rule" prose conflates two independent dimensions; write out all four cases
   (self+pinned=normal path, self+zero=normal path+kind1, other+pinned=pass-through+kind2, other+zero=reject) as
   explicit test cases, not prose.
2b. `sourceDomain == destinationDomain` — one line confirming no special-casing is needed (Flow 9).
3. `recoverDirectMint` over an `AttestationSet` (Flow 5) — currently unaddressed: per-member hash/processed
   bookkeeping, or explicitly out of scope for Phase 1 (single-attestation stray mints only)?
4. The `spendable < Σvalue` shortfall in `recoverDirectMint` — what happens to the undelivered remainder (Flow 5).
5. First-time-account failure where the *signed* `initData` was wrong (Flow 2) — is the stranded USDC at the
   counterfactual address recoverable via a fresh, differently-signed intent, or permanently stuck?
6. Gas-starvation griefing bound: quantify griefer cost per cycle and state explicitly whether it is an accepted
   risk or needs a runbook mitigation (Flow 7c).
7. `sigData.validUntil` expiry as a **non-retriable** `ExecutionFailed` variant, distinct from OOG/hook-revert
   (Flow 10) — needs its own acceptance-criteria line since it changes what "retriable" means per failure type.
8. Escrow has no expiry/rescue path; document as an explicit, monitored risk class distinct from every other
   failure mode in this spec, all of which self-heal via Circle's ~10-minute window (Flow 8).

### (b) SDK obligations checklist
- Set `destinationRecipient = destinationCaller = adapter` (per-chain address — see (c) below for lookup).
- Set `destinationToken = USDC`.
- Author `hookData` as the exact 6-tuple ABI encoding; keep it small (no published Circle cap; benchmark, per
  best-practices R9).
- For multi-source unification: build **homogeneous** `BurnIntentSet`s only (identical recipient/caller/token/
  hookData across every member) or fall back to N independent single-attestation intents — decide which, since the
  two have materially different retry/partial-delivery properties (Flow 3 QUESTION).
- Size `sigData.validUntil` with enough buffer to cover Gateway's ~10-minute attestation window plus relay latency
  (Flow 10) — larger than whatever buffer is used for same-chain or CCTP-routed intents.
- Client-side simulate the adapter's own pre-mint checks (Flow 4) before asking the user to sign, so a malformed
  intent never reaches the round-trip-on-expiry path.
- Before pinning to an adapter: check `isDenylisted(adapter)`, `paused()` on the minter (per Round 4's existing
  runbook decision) — extend to also check `Blacklisted(adapter)` on USDC.
- Look up the correct per-chain adapter address from whatever source Flow 11's QUESTION resolves to (config file
  vs. registry) — do not hardcode.
- For first-time accounts, ensure the `initData`/factory/salt embedded in the signed intent is correct *before*
  signing — there is no adapter-level fallback if it's wrong (Flow 2).

### (c) Runbook items
- Monitor `Paused`, `Denylisted(adapter)`, `AttestationSignerRemoved`, `Upgraded` on the minter, and
  `Blacklisted(adapter)` on USDC — any of these is a full-adapter outage; escrow accumulated during the outage has
  no self-healing path (Flow 8).
- Keep escrowed balances small / sweep-claim promptly where possible, since escrow is the one state not protected
  by Circle's expiry mechanism.
- On `InvalidAttestationSigner` for a previously-valid-looking payload, check whether the signer was rotated before
  blindly retrying the same payload — it will never succeed; the correct action is a fresh attestation request.
- On a `TRANSFER_SPEC_VERSION` bump upstream, treat it as "deploy a new adapter," not "patch the old one" (immutable
  by design) — add this to the standard upstream-dependency-watch process alongside CCTP's.
- Recommend/require the production relayer submit via a private or high-priority channel to bound the
  gas-starvation griefing window (Flow 7c), if that risk is judged worth mitigating rather than merely documenting.
- One-new-chain-at-a-time deployment process once Circle launches Gateway on a chain after the initial rollout
  (Flow 11).
- Document the smart-account-must-self-call-`claimFailedTransfer` constraint (no proxy/relayer claim path) for
  support/runbook purposes (Flow 7a).

### (d) Events / state needed for observability
- `processed[hash]` must be publicly readable (mapping `public` or explicit getter) so indexers/bots can pre-check
  before calling `recoverDirectMint`.
- A distinct event for successful `recoverDirectMint` (not reusing `TransferSucceeded`, so indexers can tell a
  recovery apart from a normal relay) — name TBD, e.g. `DirectMintRecovered(account, amount, specHash)`.
- A `PartialRecovery`-style event when `spendable < Σvalue` in `recoverDirectMint`, to surface the shortfall.
- Explicit statement that pre-mint rejections (Flow 4) have **no on-chain event** — monitoring must include failed
  transactions to `receiveAndExecute`, not just successful-tx event logs.
- Explicit list of the executor-side events (`...Executed`, `...ReceivedButNotEnoughBalance`,
  `...ReceivedButRootUsedAlready`, `...ReceivedButNoHooks`) that must be watched alongside the adapter's own events
  to distinguish "executed" from "silently no-opped" (carried over from CCTP, restated here because Gateway's
  multi-source/set flows add new ways to reach the root-already-used no-op).
- `ATTESTATION_SET_MIXED` (and any other new pre-mint error) should ideally carry enough data (index, or at least
  a reason code) to be diagnosable from a failed-tx trace without re-parsing the whole payload by hand.

### (e) Contradicts / stale relative to interview-notes.md
1. **Acceptance criteria draft (lines 59-67) is stale against the post-research addendum (lines 76-90).**
   Specifically: line 61 ("escrow to `sourceDepositor` on undecodable / account 0 / account == adapter") and line
   62 ("Non-USDC supported token: measured and escrowed to `sourceDepositor`... Never reject a pinned spec on
   token") directly contradict the addendum's explicit "**Dropped:** `sourceDepositor` escrow, `_receiveNonUsdc`,
   `HookPayloadUndecodable`, `NonUsdcMintEscrowed`" and the new rule that non-USDC/undecodable/bad-account are now
   **pre-mint reverts**, not post-mint escrows. Line 64's event list still includes `HookPayloadUndecodable` and
   `NonUsdcMintEscrowed`, both explicitly dropped. **The acceptance criteria section needs a full rewrite**, not a
   patch, to reflect: pre-mint reverts for token/account/hookData validity, set-support with
   `ATTESTATION_SET_MIXED`, account-only escrow keying, and the new `recoverDirectMint` surface — none of which
   appear in the current acceptance criteria draft at all.
2. **Round 3's constructor-sanity wording ("`minter.domain()` set") risks being misread as `domain() != 0`**,
   which directly contradicts the repo-analysis gotcha (and confirmed live state: `domain()==0` on Ethereum). The
   technical-spec must use the gotcha's phrasing ("use `isTokenSupported(usdc)` as the liveness check; never
   require `domain() != 0`"), not Round 3's ambiguous phrasing.
3. **Round 1's "AttestationSet: Single attestation only... rejected before any external call"** is superseded by
   the addendum's "Supported with identical routing" — correctly flagged in the addendum itself as an override,
   but the **acceptance criteria draft was never updated to match** (no `ATTESTATION_SET_MIXED`, no "one delta for
   the whole set," no set-specific test bullets anywhere in lines 59-67 or 65's test list).
4. **Round 1's escrow-beneficiary decision ("`sourceDepositor`... NOT `sourceSigner`")** is superseded by the
   addendum's "escrow map is keyed by the intent account only; `sourceDepositor` is no longer read" — again
   correctly flagged as overridden in the addendum, but `sourceDepositor` still appears in the (stale) acceptance
   criteria and in the CCTP-carryover table's "Attested sender read... adapt → `sourceDepositor`@184" (repo-analysis
   §1, row "Attested sender read"), which should be **removed**, not adapted, once the technical-spec is written.
