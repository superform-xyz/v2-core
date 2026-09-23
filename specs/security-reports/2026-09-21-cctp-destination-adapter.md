# Security Analysis Report — CCTPAdapter

## Metadata
- **Target:** `src/adapters/CCTPAdapter.sol`, `src/vendor/bridges/cctp/IMessageTransmitterV2.sol`
- **Branch:** `feat/cctp-destination-adapter`
- **Mode:** review (inline scan + 3 parallel agents + empirical gas measurement)
- **Date:** 2026-09-21
- **Contract Type Detected:** Bridge (cross-chain receiver + token custody + downstream execution)
- **Files Analyzed:** 2 (plus 4 sibling adapters and the destination executor as baseline)
- **References:** `/Users/cosming/Documents/AI/Solidity/vulnerabilities.md`;
  `superform-specs/guidelines/solidity/coding-rules.md`; ChainSecurity's Circle CCTP V2 audit;
  evmresearch.io; OWASP SC Top 10

> **Path note:** the `/superform:security` skill points at `/guidelines/solidity/*` inside v2-core.
> That directory does not exist here. Correct paths are the two absolute ones above.

## Summary

| Severity | Count | Blocks Merge | Status |
|---|---|---|---|
| P0 Critical | 0 | Yes | — |
| P1 High | 0 | Yes | — |
| P2 Medium | 3 | No | 2 fixed, 1 accepted (user decision) |
| P3 Low | 8 | No | 2 fixed, 6 advisory |

## Verdict

**PASS** — no P0 or P1 findings. Both P2 findings were fixed and covered by tests during this review.

## P2 Findings (Fixed)

### [P2-1] BurnMessageV2 body version never validated
- **File:** `src/adapters/CCTPAdapter.sol:181` (pre-fix)
- **Category:** Cross-Chain / Input Validation (OWASP SC05)
- **Description:** The adapter validated only the outer `MessageV2` header version at offset 0. Every
  offset it then trusts — `mintRecipient@184`, `amount@216`, `feeExecuted@312`, `hookData@376` —
  assumes the `BurnMessageV2` body layout, whose own `version` field at absolute offset 148 went
  unchecked.
- **Real-World Precedent:** **Circle's own audit found exactly this bug in their reference
  implementation.** ChainSecurity CS-EVM-CCTP2-013, "Possible Underflows in Relay Function": a message
  of a different body format passed to `CCTPHookWrapper.relay()` caused an underflow when slicing
  hookData. Circle's fix validates "lengths **and versions of both MessageV2 and BurnMessageV2**."
  Our own research file quotes that wrapper doing the body-version check — it simply wasn't carried
  into the implementation.
- **Exploit Scenario:** Not attacker-reachable today (Circle will not attest a malformed body), so the
  risk is forward-looking: a future CCTP body-format bump silently shifts every offset, and the adapter
  would parse garbage from an otherwise validly-attested message.
- **Fix applied:**
  ```solidity
  uint256 internal constant BODY_VERSION_OFFSET = 148;
  uint32  internal constant SUPPORTED_BODY_VERSION = 1;
  ...
  if (uint32(bytes4(message[BODY_VERSION_OFFSET:BODY_VERSION_OFFSET + 4])) != SUPPORTED_BODY_VERSION) {
      revert UNSUPPORTED_BODY_VERSION();
  }
  ```
- **Test:** `test_Revert_UnsupportedBodyVersion`. Validated against **real** Circle messages by the
  pigeon E2E suite, which still passes.
- **Reference:** ChainSecurity CS-EVM-CCTP2-013; vulnerabilities.md §16, §33

### [P2-2] `MIN_EXECUTION_GAS` floor too low to close the vector it was added for
- **File:** `src/adapters/CCTPAdapter.sol:71` (pre-fix)
- **Category:** DoS / Gas griefing
- **Description:** The floor was 500_000. Per EIP-150 the inner call receives 63/64 of what remains, so
  a caller supplying exactly the floor guaranteed the executor only **~492k gas** — below what a
  realistic destination intent needs. The griefing vector the floor was introduced to close therefore
  remained open for any non-trivial hook chain.
- **Empirical basis (measured this session):**

  | Path | Gas |
  |---|---|
  | Mocked executor, pre-existing account | 112_611 |
  | Real hooks, state-overridden account (`AcrossDestinationExecutionE2E`) | 317_191 |
  | **Real cap-validated SuperVault deposit (`CrossChainSuperVaultDestinationE2E`)** | **660_370** |

  First-time accounts add a CREATE2 deploy via `SuperDestinationExecutor._createAccount` (`:166, 216-225`).
- **Exploit Scenario:** A griefer calls `receiveAndExecute` with exactly 500k gas. Mint and transfer
  succeed; the executor OOGs; the catch branch fires. Funds are delivered but the atomic execution is
  lost, and **the CCTP nonce is consumed so the message can never be re-relayed** (unlike `lzCompose`,
  this is one-shot). Impact is bounded — the merkle root is not consumed and
  `processBridgedExecution` is permissionless, so anyone can re-drive it — hence P2 not P1.
- **Fix applied:** floor raised to **`2_000_000`**, with the measurement basis recorded in NatSpec.
- **Refined rationale (from the scanner agent, sharper than the original):** the dangerous case is not
  "floor rejects" — that reverts and unwinds, leaving the nonce unspent and the message retriable. It is
  **"floor passes yet gas is still short"**: the executor reverts into the catch, the *outer transaction
  succeeds*, and the CCTP nonce is consumed with hooks unexecuted — precisely the one-shot outcome the
  floor exists to prevent. So the floor must be calibrated against the realistic **maximum**, not the
  adversarial minimum. A conservatively high floor costs relayers only a higher gas *limit* (unused gas
  is refunded), so there is no reason to keep it tight.
- **Relayer impact:** callers must now supply roughly 2.3M+ gas. Add to the SDK/relayer checklist.
- **Note:** this was a defect in hardening added earlier in this same session, not in the pre-existing
  contract.
- **Reference:** evmresearch.io "insufficient gas griefing in relayer patterns"; vulnerabilities.md §7

## P3 Findings

### [P3-1] `checkDestinationTargets` lacked the self-call guard its cited precedent uses — **FIXED**
The NatSpec claimed to mirror `StargateAdapterV2.handleCompose`, but that function both documents
*and enforces* `if (msg.sender != address(this)) revert INVALID_SENDER();` (`:268`). Ours had neither.
Harmless today (the function is `view`), but a future edit adding state would silently inherit an
unguarded entrypoint. Guard and `INVALID_SENDER()` added; covered by
`test_Revert_CheckDestinationTargets_NotSelfCalled`.

### [P3-2] Execution-outcome observability is under-documented (advisory)
`processBridgedExecution` **returns normally** on three no-op paths — insufficient balance, already-used
merkle root, and empty executor calldata — so the adapter's `catch` never fires for them and
`ExecutionFailed` is not emitted.

Importantly, this is **not** an actual blind spot: `SuperDestinationExecutor` emits a distinct event on
every path (`:128, 135, 143, 194, 200, 208`), so an indexer watching the full transaction can
distinguish all cases. It is also identical across every sibling adapter. The gap is that
`CCTPAdapter`'s NatSpec does not say so, inviting tooling built against the adapter's own four events
to misread a silent no-op as success. **Recommend a NatSpec note only; no logic change.**

### [P3-3] Circle-acknowledged reentrancy one layer above the adapter (risk register)
ChainSecurity CS-EVM-CCTP2-001, **acknowledged and left unfixed by Circle**:
`MessageTransmitterV2.receiveMessage` calls the recipient handler *before* emitting `MessageReceived`,
and the path runs `TokenMessengerV2 → TokenMinterV2.mint → token.mint()`. If a bridged token ever
implements a mint hook, reentry is possible inside the single `receiveMessage` call — i.e. between our
`pre` and `post` balance snapshots.

Not exploitable with mainnet USDC (FiatTokenV2 has no mint hook) and `nonReentrant` covers the
adapter's own surface. Worth a risk-register entry rather than dismissal, plus a test asserting
reentry *during* `receiveMessage` (current tests only cover reentry *after* it returns).

### [P2-3] 3-arg constructor contradicts the spec's two-arg design — **accepted, user decision**
The technical spec explicitly rejected taking local USDC as a constructor arg, to preserve one CREATE2
address across all chains. The shipped contract takes it anyway, so `CCTPAdapter` gets a distinct
address per chain — the pattern the spec's own risk register flags (wrong per-chain
`mintRecipient`/`destinationCaller` ⇒ permanently stranded mint, no CCTP retry path).

**This was an explicit user decision during implementation** ("keep 3-arg as built"), recorded in
`specs/cctp-destination-adapter/IMPLEMENTATION-NOTES.md`. It is also arguably the *safer* code choice:
an immutable USDC removes the silent-failure mode where a message naming the wrong `dstTokens[0]`
yields a zero delta and moves nothing.

**Action required (operational, not code):** the spec's deployment guidance is now stale. Confirm the
deploy scripts and SDK maintain a genuine per-chain address table — as they already must for
`AcrossV3AdapterV2` (10 addresses) and `StargateAdapterV2` (14) — and that no code path assumes a
single global `CCTPAdapter` constant.

### [P3-7] Malformed 6-tuple hookData reverts with no event trail — **reviewed, no change (recommendation rejected)**
The scanner recommended wrapping the outer `abi.decode` in the self-call try/catch idiom and emitting a
decode-failure event, mirroring `StargateAdapterV2`'s `ComposeDecodeFailed`.

**I disagree, and did not apply it.** Catching here would make things strictly worse: if the 6-tuple is
undecodable there is no `account` to forward to and no key under which to credit `failedTransfers`, so
the mint would succeed and strand USDC *inside the adapter permanently, with no claim path*. The
current behavior — panic, revert, mint never happens — fails closed and leaves the funds unminted on
the source chain rather than trapped here. Only the depositor who authored the bad hookData is
affected, and they authored it.

The observability half of the finding is also unactionable: a reverted transaction cannot emit an
event. (Stargate's case differs because `lzCompose` has a hard must-never-revert liveness constraint
from LayerZero's ordered queue; CCTP messages are independent, so we are free to revert.)

Rationale recorded in-contract as a NatSpec comment so a future maintainer does not "fix" it.

### [P3-8] `claimFailedTransfer` accepts an arbitrary `token` — confirmed non-exploitable
`failedTransfers` is only ever credited under the `address(USDC)` key, so any other token reverts
`INSUFFICIENT_FAILED_BALANCE` before a transfer is attempted. Vestigial generality inherited from the
`RelayAdapter`/`StargateAdapterV2` pattern, which genuinely need multi-token and native-ETH support.
No change required.

### [P3-4 … P3-6] Style / documentation (advisory, not applied)
- Wire-offset constants `internal` where `StargateAdapterV2.COMPOSE_MSG_OFFSET` is `private`.
- `IMessageTransmitterV2` imported under the `// Superform Interfaces` banner; siblings use a separate
  `// Vendor Interfaces` banner.
- `AMOUNT_OFFSET`/`FEE_EXECUTED_OFFSET` asserted without the field-by-field derivation given for the
  other two offsets; return-code constants documented as a group rather than individually.

## Verified-Safe Properties

Confirmed present rather than assumed, several with external citations:

| Property | Evidence |
|---|---|
| Call target never derived from hookData | `SUPER_DESTINATION_EXECUTOR` is `immutable`; only typed params flow from hookData. **Conduit PR #1 (Sept 2026)** shipped the opposite and was rated High — "anyone could originate their own CCTP burn naming the executor as mintRecipient with arbitrary hookData." We are structurally immune. |
| Delta accounting is donation-proof AND brick-proof | **Conduit's second High finding** was donation-triggered underflow bricking from re-measuring `balanceOf` *after* hooks ran. We measure once, immediately around `receiveMessage`, before the executor runs, with no cross-call state. The distinction is load-bearing — "also forward leftover dust" would reintroduce it. |
| No admin privileges | Zero owner/admin functions; all four trust anchors `immutable`. Directly counter to the Poly Network pattern ($600M+), where the relay contract held admin rights over its own authorization registry. |
| Returnbomb-safe | Both catches are bare (`catch { }`), never binding revert data. vulnerabilities.md §51 / EIP-150. |
| `destinationCaller` enforcement | Verified against **real deployed Circle bytecode** by `test_E2E_Pigeon_DestinationCallerBlocksDirectReceive` — a direct `receiveMessage` from an attacker EOA reverts `"Invalid caller for message"`. |
| Attested-data-only | Every byte read from `message` is covered by the attestation; the one pre-verification read (`mintRecipient@184`) is gated by `receiveMessage` reverting on a bad attestation. |
| Arithmetic | Solidity 0.8.30 checked math, no `unchecked` blocks. `amount - feeExecuted` cannot underflow because `TokenMessengerV2` enforces `fee < amount` *before* the adapter computes it. |

## Attack Surface Summary

- **External entry points:** `receiveAndExecute` (permissionless by design),
  `claimFailedTransfer` (keyed by `msg.sender`), `checkDestinationTargets` (now self-call only)
- **Value transfer points:** `_tryTransfer` to the intent account; `claimFailedTransfer` to the recipient
- **Oracle dependencies:** none
- **Cross-contract interactions:** `MessageTransmitterV2.receiveMessage`, `USDC.transfer`,
  `SuperDestinationExecutor.processBridgedExecution` — all immutable addresses
- **Upgrade mechanisms:** none; non-upgradeable, no proxy, no admin

## Test Status After Fixes

| Suite | Result |
|---|---|
| `CCTPAdapterUnitTests` | 24 passed |
| `CCTPAdapterPigeonE2E` (real messages, real Circle contracts) | 6 passed |
| `CCTPAdapterE2EFork` | 4 passed |
| `CCTPHooksFork` (+E2E) | 32 passed |
| All adapter unit suites | 115 passed |

## Adjudicated and Confirmed Safe

The scanner was asked eight specific questions; all were resolved with reasoning rather than assertion:

1. **Pre-verification read of `mintRecipient@184`** — not exploitable. It is a fail-fast optimization,
   not a trust decision; `receiveMessage` still independently verifies the attestation over the whole
   message. Section 50 ("trusted caller, untrusted params") does not apply: `receiveAndExecute` makes
   no trust decision on `msg.sender` at all — safety comes from the attestation validating the
   *parameters themselves*, which structurally avoids that class.
2. **`amount - feeExecuted` underflow** — impossible for an attested message (`TokenMessengerV2`
   enforces `fee < amount`), and Solidity 0.8.30 checked math makes any violation fail closed.
3. **Gas floor** — elevated to P2-2 above.
4. **Memory-expansion OOG via crafted `sigData`** — closed by the 7964-byte hookData ceiling. At ~8KB
   (~2000 words) expansion costs low tens of thousands of gas, nowhere near 63/64 of a budget.
5. **`claimFailedTransfer` arbitrary token** — unreachable, see P3-8.
6. **Missing `totalEscrowed`** — genuinely unnecessary, not a gap. `RelayAdapter` needs it because it
   forwards a *caller-supplied* amount checked against total balance. We never consult total balance:
   pre-existing balances appear in both `pre` and `post` and cancel out of the subtraction. The agent
   attempted three breaks (reentrancy, a CCTP mint-time callback, sequential batched calls) and found
   none.
7. **`minted == 0`** — benign. `_validateBalances` rejects `intentAmount == 0` and no-ops gracefully.
8. **Residual reentrancy** — none. `nonReentrant` blocks same-contract reentry; all state a hook could
   observe is finalized before the executor call; `usedMerkleRoots` is set before `_execute`.

## Outstanding

- Recommended follow-ups: reentrancy-during-`receiveMessage` test (P3-3); NatSpec note on
  execution-outcome observability (P3-2); optional style items (P3-4…6).
- A genuine Circle-attested testnet run remains the one thing no fork test can substitute for.


---

# Round 2 — Re-review (security re-scan + `/code-review high`)

Both reviews were re-run after the round-1 fixes. **The dominant theme was one I got wrong twice.**

## The systemic error: "revert = retriable" is FALSE for CCTP

I reused `AcrossV3AdapterV2`'s "fail closed, the message stays retriable" reasoning in several places.
It does not transfer. Across can revert safely because an unfilled deposit still sits in the SpokePool
and either gets filled by another relayer or refunds at origin. **CCTP has no refund**: the USDC is
destroyed the instant `depositForBurnWithHook` succeeds, and the only path to that value is a
successful relay of one specific, immutable, already-attested message.

So any revert whose trigger is **determined by the message bytes** is not a retry — it is permanent,
unrecoverable destruction, because the identical bytes hit the identical revert forever. Only
`INSUFFICIENT_GAS` is genuinely retriable, because gas is a per-call choice by the caller.

Three paths had this bug. All three are now fixed:

| Path | Was | Now |
|---|---|---|
| `EXECUTOR_NOT_VALID` / `VALIDATOR_NOT_VALID` | revert ⇒ permanent burn | deliver funds, skip execution, emit `DestinationTargetMismatch` |
| Malformed 6-tuple hookData | uncaught `abi.decode` panic ⇒ permanent burn | self-call isolated; escrow to `messageSender`, emit `HookPayloadUndecodable` |
| `ACCOUNT_NOT_VALID` | revert ⇒ permanent burn | escrow to `messageSender` |

### Why my justification for the non-fix was wrong

I argued in round 1 that catching the decode panic would be *worse*, because there would be "no key
under which to credit `failedTransfers`." **That is factually incorrect.**
`BurnMessageV2.messageSender` sits at body offset 100 → **absolute 248**, inside the FIXED 228-byte
body — always readable regardless of whether the tail decodes. Circle's `TokenMessengerV2` hard-codes
it to `msg.sender` at burn time, so it is attested and unspoofable (verified: it appears nowhere as a
parameter in `CCTPSendHook` or `ITokenMessengerV2`).

For a Superform-originated burn it is the depositing smart account itself — the very value the tail was
supposed to decode to as `account`. For an adversarial burn it is whoever burned their own tokens.
Crediting it back is never wrong.

## Other round-2 findings fixed

| # | Severity | Finding | Fix |
|---|---|---|---|
| R2-1 | High | `destinationCaller` never validated, though the NatSpec claimed it as safety anchor #2. `CCTPSendHook:123` validates only `mintRecipient`, so zero is possible | Fail-fast check at offset 108. **Note:** cannot prevent the bypass itself (a direct `receiveMessage` never touches this contract) — SDK enforcement remains the real control |
| R2-2 | Medium | Non-USDC CCTP token (EURC) would mint here, leave the USDC delta at 0, and **succeed** with the nonce consumed and funds stranded | `NOTHING_MINTED` guard |
| R2-3 | Low | Over-mint surplus silently retained — the round-1 test literally asserted 200e6 sitting dead in the adapter | Credited to `failedTransfers`, claimable |
| R2-4 | Low | `_tryTransfer` could panic on a short non-empty return payload, converting a recoverable escrow into a hard revert | Length-guarded |

**Rejected recommendation:** the code reviewer proposed validating `burnToken@152 == address(USDC)`.
That would reject every legitimate message — `burnToken` is the **source**-chain address
(Ethereum USDC ≠ Base USDC). Used a minted-delta guard instead.

## Verified correct by the re-scan (no regressions)

Body-version check (offsets re-derived from Circle's source independently), the self-call guard (a
`STATICCALL` to a `view` function cannot touch `ReentrancyGuard._status`, so no false reentrancy trip),
the 2M gas floor, and the delta+clamp invariant `minted_final + surplus == raw delta`.

## Remaining accepted exposure

- **`NOTHING_MINTED`** still reverts after a mint of a *non-USDC* token. Unlike the other two, there is
  no cheap safe fix — the adapter cannot custody or credit an arbitrary token without an extra
  `TokenMinterV2.getLocalToken` call. Lower priority: requires a burnToken misconfiguration.
- **`destinationCaller = 0` bypass** — mitigated by SDK discipline, not by code. Pre-existing accepted
  risk (technical-spec.md:127, 455).
- **No rescue path by design.** Zero admin functions is good against the Poly Network pattern, but it
  means any remaining edge case is unrecoverable. Worth an explicit decision before audit.

## Test Status After Round 2

| Suite | Result |
|---|---|
| `CCTPAdapterUnitTests` | 28 passed (+4) |
| `CCTPAdapterPigeonE2E` (real Circle contracts) | 6 passed |
| `CCTPAdapterE2EFork` | 4 passed |
| `CCTPHooksFork` (+E2E) | 32 passed |
| All adapter unit suites | 119 passed |

---

# Round 3 — Review of this session's changes (2026-09-22)

**Scope:** the uncommitted delta on `feat/cctp-destination-adapter` vs `7f542d57` (`CCTPAdapter.sol`
+283/−29, plus tests). **Method:** inline critical-pattern scan (10/10 adjudicated with grep evidence)
+ vulnerability-scanner agent + coding-standards agent, run in parallel. The external-precedent
researcher was deliberately skipped this round (ecosystem unchanged in a day; scope was the diff).

**Caveat from Round 2 resolved.** That round's rescan agent could not read the vulnerability DB. This
round the DB was staged as a world-readable scratchpad copy; the scanner cited §1, §2, §7, §8, §10.3,
§16, §29.3, §33 and App. H. Its "no P0/P1" now rests on the pattern database, not general reasoning.

## Verdict: PASS — no P0/P1. Two P2 (one fixed, one accepted), one new P3 (fixed), standards items fixed.

| # | Finding | Sev | Status |
|---|---|---|---|
| P2-1 | `_tryTransfer` still did `abi.decode(returnData,(bool))` behind a length guard. The ABI decoder **panics** on any 32-byte word ≠ 0/1 (reproduced on `RelayAdapterV2` the same day), so the guard was insufficient — a hard revert instead of an escrow. Nil exposure with canonical USDC; elevate to P1 the moment `usdc_` is anything else. | P2 | **FIXED** — `_isTrueWord` raw-word read. `test_R3_NonBoolReturnWordEscrowsInsteadOfPanicking` |
| P2-2 | `NOTHING_MINTED` after a non-USDC CCTP mint (EURC): the mint unwinds, the nonce survives, but `destinationCaller` pins the message to this adapter, which hits the same revert forever — the burned EURC can never be extracted here. Reachable only by SDK/user misconfiguration of `burnToken`. **Correction to Round 2:** the "cheap fix" is NOT cheap — measuring the actually-minted token needs `TokenMinterV2.getLocalToken(sourceDomain, burnToken)` wiring plus an arbitrary-token escrow/claim path. A design change, not a patch. | P2 | **FIXED in Round 4** (see addendum below) |
| P3-1 (new) | hookData naming `account == address(this)`. The self-transfer **succeeds** trivially, so nothing is credited, `TransferSucceeded` fires misleadingly, and the USDC becomes indistinguishable from a donation — permanently stuck with no rescue path. Triggerable by an SDK bug. | P3 | **FIXED** — routed through the escrow-to-`messageSender` path exactly like `account == 0`. `test_R3_SelfAccountEscrowsToMessageSender` |
| Std P2 | Comment at the target-mismatch step still described the pre-Round-2 design ("fail closed… only an explicit mismatch reverts") while the code delivers funds and skips execution. A maintainer trusting it could reintroduce the fund-destroying revert. | P2 (docs) | **FIXED** |
| Std P3 ×5 | Return codes documented as a group; `HookPayload` fields undocumented; double-emit on the escrow path unjustified; `unchecked` lacked an adjacent safety note; `address(this)` word computed twice. Also a stale `relay()` name in the gas-floor NatSpec (found during anchor verification, not by either agent). | P3 | **FIXED** |
| Std P3 (#7) | `receiveAndExecute` ~137 lines; extraction suggested. | P3 | **DEFERRED** — behavior-preserving refactor; house style keeps one function (Across/Relay do too) |
| Pre-existing P3-2/-4/-5/-6 | Observability note on `ExecutionFailed`; constants `internal`→`private` (verified nothing inherits the contract and the tests redeclare their own offsets); vendor import banner; field-by-field offset derivation. | P3 | **FIXED** |
| Pre-existing P3-7 | Round 1 recorded the catch-and-escrow recommendation as **rejected**. That language is superseded: Round 2 reversed it and the shipped code escrows undecodable hookData to the attested burner. | — | Report corrected |

## Adjudicated safe (reasoning verified, not asserted)

- **Escrow-to-`messageSender`**: the burner always burns their *own* USDC; a malformed/self-referential hookData escrows it back to them. `claimFailedTransfer` pays only `msg.sender`'s own credit — no path redirects another party's escrow.
- **Surplus credited to `account`, not `messageSender`** — correct: a facilitator/paymaster may legitimately burn on behalf of a different smart account; crediting the facilitator would misattribute. Unreachable against the real transmitter anyway (`fee < amount` enforced at burn). `unchecked` guarded by `claimed < minted`.
- **Two self-calls under `nonReentrant`** are `STATICCALL`s and cannot touch `_status`. Memory-expansion gas DoS via crafted hookData is closed by the 7964-byte `maxMessageBodySize` ceiling (~8KB ⇒ low tens of thousands of gas vs a 2M floor). Adjudicated analytically; the ceiling itself is verified live and by the pigeon E2E on real bytecode — not separately stress-tested.
- **Pre-verification reads** (`destinationCaller@108`, `mintRecipient@184`, versions, `messageSender@248`) only gate reverts; `receiveMessage` reverting unwinds everything. Using `messageSender` post-mint is sound.
- **`targetsMatch` skip** is a pure function of attested `sigData`; a relaying third party cannot force it.
- **`MIN_EXECUTION_GAS` after the transfer** unwinds mint+transfer atomically, nonce unspent — now **proven on the real transmitter**: `test_E2E_Pigeon_InsufficientGas_LeavesNonceUnconsumed`.
- **`claimFailedTransfer`** keys on `address(USDC)` at all three credit sites (transfer failure, surplus, escrow fallback).
- **Relay hardenings** (one-shot intent, token binding, saturating escrow) are **not gaps** here — CCTP's nonce is single-use, the token is an immutable, and there is no pool-balance model. Only `_isTrueWord` applied (now done).

## Test gaps: addressed / remaining

Added (7): non-bool return word; self-account escrow; surplus→account with `messageSender ≠ account`;
header version 2 and body version 2 forward-compat; a fuzz over `(amount, fee, mint)` asserting
`delivered == min(delta, amount−fee)` and `delivered + surplus == delta`; and the real-transmitter
gas-floor/nonce E2E above.

Remaining: a real-EURC E2E (impossible on mainnet forks today — EURC is not registered on the Base/Ethereum minters; covered by mocks + a real-minter ordering fork test, see Round 4);
`HookPayloadUndecodable` / `DestinationTargetMismatch` exercised against real Circle attestations
(mock-only today); reentrancy *during* `receiveMessage` (P3-3, Circle-acknowledged, accepted).

## Status after Round 3
`CCTPAdapterUnitTests` 34 · `CCTPPayloadSizeGate` 6 · CCTP integration 43 (incl. 7 pigeon E2E) — green.
Locked bytecode regenerated and verified on `bytecode.object` (deployed 7714 bytes; whole-file md5 is
NOT a valid check — the artifact `id` and non-code keys differ across rebuilds).


---

# Round 4 addendum — P2-2 fixed (2026-09-22)

**Decision.** User chose to fix rather than accept. Re-scoped once the code was checked: the escrow/claim
side was already token-generic (`failedTransfers[account][token]`, `claimFailedTransfer(token, amount)`),
so the "design change" reduced to one lookup plus one branch. Full write-up in
`specs/cctp-destination-adapter/IMPLEMENTATION-NOTES.md` § Round 4.

**Reachability, corrected.** Round 3 said "SDK/user misconfiguration". More precisely: the deployed source
hooks accept any `burnToken` (`CCTPSendHook.sol:113`), so this is reachable from our own product surface —
but only once Circle registers a second token on the relevant minters. Verified live on 2026-09-22:
Base `TokenMinterV2 (0xfd78EE91…)`: `getLocalToken(0, EURC_ETH) == 0`; Ethereum `burnLimitsPerMessage(EURC_ETH)
== 0`. So a non-USDC burn is rejected at the source today; the fix is forward-protection for an immutable
contract.

**Change.** `constructor(messageTransmitter, tokenMessenger, usdc, superDestinationExecutor)`; pre-mint
lookup `TOKEN_MESSENGER.localMinter().getLocalToken(sourceDomain@4, burnToken@152)`; `address(0)` →
`UNSUPPORTED_BURN_TOKEN`; non-USDC → `_receiveNonUsdc` (measure that token's delta, escrow to attested
`messageSender`, `TransferFailed` + `NonUsdcMintEscrowed`, no decode, no execution); USDC → unchanged.

**Re-adjudicated for this change.**
- Two new pre-`receiveMessage` STATICCALLs (messenger → minter). Both are Circle contracts already trusted
  by the transmitter's mint path; a malicious/rotated minter could at worst mis-route to escrow (funds
  stay claimable by the burner) or return 0 (clean revert, message unconsumed). No new fund-loss path.
- Escrow goes to `messageSender`, not the decoded `account`: no dependence on the untrusted tail, and
  for a Superform-originated burn they are the same address. Same CREATE2 same-address assumption as the
  existing undecodable-hookData escrow.
- Reading the minter at call time (not cached) is deliberate: Circle can rotate it and the adapter is
  immutable. Cost ≈ 5k gas per relay.
- Vendored `ITokenMessengerV2.sol` untouched; verified `CCTPSendHook` / `ApproveAndCCTPSendHook`
  `bytecode.object` still equal their locked artifacts (their metadata hashes that file).
- `_receiveNonUsdc` is `private`, called only from inside the `nonReentrant` entry; token `balanceOf`
  calls are views on a Circle-registered token.

**Tests.** +6 unit (`test_R4_*`), +1 fork (`test_Fork_UnregisteredBurnToken_RejectedBeforeTransmitter`,
real Base messenger/minter, proves lookup-before-attestation ordering). Totals: unit 40 · size-gate 6 ·
CCTP integration 44 · all adapters 131 · deploy-script 5 — green. Locked bytecode regenerated and
verified on `bytecode.object` (deployed 8851 B).

**Open after Round 4.** `destinationCaller = 0` bypass (SDK), no rescue path for true donations, BSC
domain-17 unverified, swap-hook Phase 0 unmeasured, reentrancy-during-`receiveMessage` (P3-3, accepted).


---

# Round 5 — Security analysis of the Round-4 change (2026-09-22)

**Scope:** the non-USDC routing change (Round 4) plus the whole adapter for context. **Method:** inline
critical-pattern scan (10/10 clean, grep evidence) + vulnerability scanner (DB §1/§2/§8/§10/§16/§33 + the
2024–2026 pattern file, both readable this time) + coding-standards agent + external-precedent researcher
(Circle source, live `cast` on Ethereum/Base/Sepolia, ChainSecurity July-2025 report, incident write-ups).

## Verdict: PASS — no P0/P1. One P2-class hardening found in-round and applied; one P3 applied; docs fixed.

| # | Finding | Sev | Status |
|---|---|---|---|
| R5-1 | **Forged non-burn message reaches the adapter (Allbridge class).** `sendMessage` is permissionless and `receiveMessage` dispatches to ANY recipient; Circle attests it. A BurnMessageV2-shaped body with `destinationCaller = adapter` passes every fail-fast check, `getLocalToken` resolves USDC, and the attacker's handler runs inside our `receiveMessage`. Value forgery already impossible (delta-measured: only the attacker's own donation is creditable; reentry blocked by the shared guard) — but `messageSender` is attacker-chosen, the lookup messenger ≠ minting messenger, and attacker code executes mid-flight. Found inline; independently rated P2 by the researcher. | P2 | **FIXED** — `recipient@76 == TOKEN_MESSENGER` (`RECIPIENT_MISMATCH`), before any external call. Unit ×2 + fork ordering test. `sender@44` binding adjudicated redundant: `TokenMessengerV2.onlyRemoteTokenMessenger` enforces it before any mint. |
| R5-2 | Constructor only checked `localMinter() != 0`; a wrong-but-populated `tokenMessenger_` (chain where Circle's CREATE2 differs; permissive fallback at the expected address) would deploy an adapter that reverts on every relay, no admin to repoint. | P3 | **FIXED** — `localMessageTransmitter() == messageTransmitter_` bound at construction; dedicated `TOKEN_MESSENGER_NOT_VALID`. |
| R5-3 | `TransferFailed` NatSpec described one of its four emission sites; `failedTransfers` doc missed the surplus credit. | P2 (docs) | **FIXED** |
| R5-4 | Runtime `localMinter() == 0` (Circle rotation window) → empty revert from a call to `address(0)`. | P3 | **FIXED** — legible `TOKEN_MESSENGER_NOT_VALID` in `_resolveLocalToken`. |
| R5-5 | Std P3 ×8: `NOTHING_MINTED` doc vs clamped call site; `ADDRESS_NOT_VALID` reused; stale "@N" parenthetical; `receiveAndExecute` NatSpec omitted the non-USDC branch; `_receiveNonUsdc` lacked `@param`; `private`/`internal` mixed; scoped block → helper (the "frees its stack slot" rationale was moot under `via_ir`); vendor header; fmt. | P3 | **FIXED** (all) |

## Corrections to Round 4 (from live verification)
- "Only USDC registered on Ethereum/Base mainnet today" — **false on Ethereum**: USYC is linked in
  `TokenMinterV2` (from BNB, domain 17; `burnLimitsPerMessage(USYC) == 7.5e13`; `remoteTokenMessengers(17)`
  set). Base is USDC-only. The non-USDC path is therefore live on Ethereum, not forward-protection.
- "EURC would hit the escrow path" — **false**: EURC on CCTP (live 2026-09-02, Ethereum + Base) runs through
  Circle's separate `CrossChainTokenService`, never `TokenMinterV2` (`getLocalToken(0, EURC_ETH) == 0`
  everywhere). Test/notes wording corrected; the adapter NatSpec never named EURC.
- **New accepted residual:** USYC is permissioned (Entitlements allowlist). A USYC burn on BNB with
  `mintRecipient = destinationCaller = adapter` reverts inside `receiveMessage` at the mint, so `_receiveNonUsdc`
  cannot uphold "never revert" for it — the burn is stranded. **Confirmed on-chain (2026-09-22):** `eth_call`
  `USYC.mint(0xdead, 1)` from the real TokenMinterV2 reverts (`0x7f63bd0f`) while a mint to an entitled address
  succeeds. Reachable only by a KYC'd USYC holder targeting this adapter deliberately (the SDK never builds it).
  Accepted; no on-chain mitigation short of allowlisting the adapter. The routing itself is proven on the real
  Ethereum registry: `test_Fork_Ethereum_RealRegistry_RoutesUsycToNonUsdcBranch` (`(17, USYC_BNB)` → USYC,
  `(6, USDC_BASE)` → USDC, `(6, EURC)` → `UNSUPPORTED_BURN_TOKEN`).

## Adjudicated safe (scanner focus questions, verified against Circle source)
- Offsets: `sourceDomain@4`, `burnToken@152 (148+4)`, `messageSender@248 (148+100)` match `MessageV2` /
  `BurnMessage(V2)` indices; `TokenMinterV2.mint` → `_getLocalToken(sourceDomain, burnToken)`, the same internal
  `getLocalToken` wraps. Header and body versions pinned, so no offset-shifting confusion.
- Minter rotation: `localMinter()` read and the transmitter's `_getLocalMinter()` execute in one tx; rotation is
  two owner txs (`removeLocalMinter` → `addLocalMinter`); in the window both sides revert, nonce unspent.
- Non-USDC delta: minting is not a transfer (no fee-on-transfer skew); token comes from Circle's registry, not the
  message; `failedTransfers` keyed per (account, token) so a stuck token cannot block other claimants.
- Pre-mint calls are views into Circle contracts; both entrypoints `nonReentrant`; no read-only-reentrancy victim.
- `UNSUPPORTED_BURN_TOKEN` cannot strand a mint Circle would have performed (same lookup, same minter, now the
  same messenger thanks to R5-1).
- Cost of the live minter read ≈ 8k gas (~1% of the 2M floor); caching is not defensible given rotation.

## External precedent (researcher) — status
- ChainSecurity CS-EVM-CCTP2-013 (both versions validated) ✔ handled; -001 (arbitrary recipient reentrancy)
  ✔ handled by guards + R5-1; -016 (`feeExecuted > 0` legitimately on re-attested fast burns) ✔ handled by delta;
  -002 (burn limit without linked pair → source burn with no mint) — Circle-side misconfiguration, accepted.
- Allbridge (2026-08-19) — closed by delta measurement + R5-1.
- Base→Arc pre-launch stranding — inverse case; documents why `destinationCaller = adapter` is right and why
  `destinationCaller = 0` (accepted SDK-enforced gap) turns USDC into an unrescuable donation.
- Fee edge: a fast transfer can legally mint `amount − fee` down to 1 unit → SDK must size intents against
  `amount − maxFee` or use `TokenMessengerWithFees` (P3, SDK checklist).
- Not confirmed by the researcher: `CrossChainTokenService` message format/addresses; whether
  `TokenMessengerWithFees` leaves the destination message byte-identical (very likely).

## Status after Round 5
Unit 43 · size-gate 6 · integration 46 · all adapters 134 · deploy-script 5 — green. Bytecode regenerated and
verified on `bytecode.object` (deployed 9021 B); `CCTPSendHook` / `ApproveAndCCTPSendHook` locked bytecode
unchanged. Open/accepted: `destinationCaller = 0` (SDK), no donation rescue (by design), permissioned-token mint
revert (USYC), BSC domain-17 path unverified end-to-end, swap-hook Phase 0 unmeasured, P3-3 reentrancy during
`receiveMessage`.

---

# Round 6 — Re-analysis with the relay Round-2 lenses (2026-09-23)

**Scope:** full re-read of `CCTPAdapter.sol` as it stands (not the diff), the generic deploy wiring, and the
tests — applying what PR #1014's second review surfaced on the sibling adapter: third-party griefing on
public messages, deploy-script code paths that only work from a warm script instance, and NatSpec claims
that outrun the code.

## Verdict: adapter PASS; one P2 deploy-script bug fixed; two NatSpec nits fixed

| # | Finding | Sev | Status |
|---|---|---|---|
| R6-1 | **Check/deploy constructor-arg mismatch (same class as relay R2-F2).** `_checkCoreContracts` still encoded the pre-Round-4 3-arg constructor `(transmitter, usdc, executor)` while the deploy block encodes 4 `(transmitter, tokenMessenger, usdc, executor)`. The wrapper's check pass would compute a wrong CREATE2 address, report `CCTPAdapter` missing on every run, and the deploy would land at a different address than the one reported/verified. | P2 (deploy) | **FIXED** — check pass encodes the 4 args. New `test/script/DeployV2CoreCCTPAdapterArgs.t.sol` runs the real check pass and asserts its recorded address equals `computeAddress(bytecode, deploy-args, salt)`. Real check pass on Base now reports `CCTPAdapter` at `0xf70790169e93D05E0A655960268de5261b9Cb67A`, 107/108 deployed. |
| R6-2 | **No deploy-time proof that `configuration.usdcs[chainId]` is what the minter mints.** The adapter routes every message through `getLocalToken` and escrows anything ≠ `USDC` without executing; a wrong local-USDC config would silently park every USDC intent in escrow. | P3 (deploy) | **FIXED** — deploy block requires `TokenMinterV2.getLocalToken(remoteDomain, remoteUSDC) == usdcs[chainId]` for the canonical pair (Ethereum-domain-0 USDC for every chain; Base-domain-6 USDC on Ethereum). Verified live on Base and Ethereum. |
| R6-3 | `checkDestinationTargets` NatSpec still said an explicit mismatch "reverts"; `ExecutionFailed` NatSpec named the executor events without their `SuperDestinationExecutor` prefix. | P3 (docs) | **FIXED** |

## Griefing lens (relay R2-F1 analogue) — adjudicated safe
`receiveAndExecute`'s outcome is a pure function of the attested bytes plus chain state: a third party
who front-runs the relayer merely performs the relay. There is no per-message slot to burn (the nonce is
Circle's and is consumed only on success), an under-funded account cannot be "pre-poisoned" because the
transfer and the execution attempt happen in one tx, and gas starvation is closed by the 2M floor
(reverts and leaves the nonce unspent). Direct calls to `processBridgedExecution` before the relay no-op on
the balance gate with the root unused. No new finding.

## Other re-checks (no change)
Reentrancy: both entrypoints guarded; with `recipient` pinned, the only code reached inside
`receiveMessage` is Circle's messenger/minter/FiatToken. `receiveMessage` never returns `false` in V2
(it `require`s the handler result), so `RECEIVE_MESSAGE_FAILED` is a defensive backstop. `claimFailedTransfer`
on a permissioned non-USDC token (USYC) may revert for a non-entitled claimant — already-accepted residual.
Cross-chain replay excluded by the transmitter's `destinationDomain` check. Fast-transfer (`finality < 2000`)
mints are handled by delta measurement.

## Status after Round 6
CCTP unit 49 · size-gate 6 · integration 46 · script 6 (incl. parity) — green. Bytecode regenerated
(NatSpec-only; deployed 9021 B). Generic orchestrator already acts as the scoped deploy for CCTP (all other
core contracts are deployed), so no `runCCTPAdapter` entrypoint is needed.
