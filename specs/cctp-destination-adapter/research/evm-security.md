# CCTP Destination Adapter — Security Research

Grounded in the existing adapters, `src/executors/SuperDestinationExecutor.sol`,
`src/hooks/bridges/cctp/CCTPSendHook.sol`, `lib/pigeon/src/cctp/CctpV2Helper.sol`, and the
vulnerability database.

> **Path note:** `vulnerabilities.md` is NOT under `v2-core/guidelines/` (that directory does not exist
> in this repo). It lives at `/Users/cosming/Documents/AI/Solidity/vulnerabilities.md`, and
> `coding-rules.md` at `/Users/cosming/1.Coding/Superform/superform-specs/guidelines/solidity/coding-rules.md`.
> The `/superform:spec` skill's documented paths are stale.

## 1. Relevant vulnerability patterns

**Cross-chain message trust — Sec 16, 33**
- *16.1 / 33.4 replay* — not the adapter's job. `MessageTransmitterV2.usedNonces` guards the message;
  `SuperDestinationExecutor.usedMerkleRoots[account][root]` (lines 36, 127-132) guards the intent. Two
  independent layers; the adapter adds none.
- *16.2 / 33.1 false deposit* — CCTP's trust root is Circle's attester set alone. The adapter's whole
  job is not to weaken it: accept hookData **only** from the attested `message` bytes.
- *33.3 Nomad zero-root* — analog lives in `_decodeMerkleRoot`/`usedMerkleRoots` (zero-initialized
  mapping). Executor-side and already shipped; only becomes adapter-relevant if the adapter ever
  special-cases a "no signature found" path. Don't build one.

**Access control — Sec 2** — `relay()` is deliberately permissionless; the access control that matters
is `destinationCaller` at the transmitter layer, not a function modifier. Never add a `tx.origin`
"trusted keeper" shortcut later (2.2).

**Reentrancy — Sec 1** — `relay()` moves tokens, then calls the executor, which calls the smart
account, which runs arbitrary user hooks (1.1). A hook can reenter `relay()` with a second valid
message (1.3, analyzed in §2.4). Read-only exposure (1.4) is low today but the adapter does carry a
nonzero USDC balance mid-call.

**USDC token behavior — Sec 10** — USDC is not fee-on-transfer, but *the pattern that causes 10.1*
(trusting `balanceOf(this)` as a proxy for "what I just received") is exactly the mistake the
full-balance design makes, and the canonical 10.1 fix (before/after delta) is exactly the right fix
here. Use the low-level-call `_tryTransfer` pattern (10.3) rather than bare `IERC20.transfer`.
Blocklist/pause must not brick `relay()` nor strand funds unrecoverably.

**Flash loan — Sec 5** — not applicable in the classic sense (the burn is irreversible). The real
atomic vector is **self-funding via a second unrelated transfer landing at the adapter**, see §3.

**MEV — Sec 6** — `relay()` is a race among permissionless callers (6.1); no price/slippage surface
exists, so no sandwich vector (6.2).

**DoS / gas — Sec 7, 8, Appendix H** — a hostile hook revert must not brick `relay()` for the next
message (7.4). The `catch` must bind no variable (Appendix H.1 returnbomb) — as
`RelayAdapter.sol:209` and `StargateAdapterV2.sol:344` already do; `StargateAdapterV2.sol:239-247`
goes further and wraps *decode* in a self-call try/catch.

## 2. Permissionless relay threat model

### 2.1 `destinationCaller` restriction — validated correct
The adapter calls `receiveMessage` from inside `relay()`, so `msg.sender` seen by the transmitter is
always the adapter, regardless of who called `relay()`. This closes the "third party mints without
running the hook" gap. Independently confirmed against Circle's source in
[framework-docs.md §5](./framework-docs.md) — `require(destinationCaller == msg.sender.toBytes32(),
"Invalid caller for message")`. **Sound.**

### 2.2 Gas-limit griefing — Medium, one-shot
A caller tunes gas so `receiveMessage` + the token forward succeed but the nested
`processBridgedExecution` dies under EIP-150's 63/64 rule. The `try/catch` swallows it by design.

Why this is worse for CCTP than for Stargate: `processBridgedExecution` writes
`usedMerkleRoots[account][root] = true` (line 132) *before* `_execute()` (line 142), but that write is
in the same frame as the revert — so an OOG unwinds it and the **merkle root is not consumed**. That
sounds like a retry safety net, except CCTP's message nonce *is* consumed, so `relay()` can never be
called again for that message. Unlike `lzCompose` (re-triggerable by anyone with more gas), this is
**one-shot**.

Residual impact is bounded: tokens are already at the account, and `processBridgedExecution` is itself
permissionless, so anyone can re-drive the same payload afterwards (the recovery path
`RelayAdapter.sol:18` documents for solvers). Cost is one atomic execution, not funds.

Mitigation: an explicit `MIN_EXECUTION_GAS` floor checked before the `try` block, plus a `{gas: G}`
stipend on the call so the outer caller cannot starve it. Document the residual one-shot property.

### 2.3 Frontrunning the relay — Low
`account`, `dstTokens`, `intentAmounts`, `executorCalldata` are all baked into the attested message —
winning the race redirects nothing. Only becomes an attack when combined with §3.

### 2.4 Reentrancy via the executor — Medium under full-balance, Low under delta
The account's hook chain can reenter `relay()` with a second valid message before the first returns.
Under full-balance forwarding this produces order-dependent interference; under delta forwarding it
structurally disappears, since each frame computes its own delta.

Note the two precedents **disagree**: `RelayAdapter.processRelayExecution` is `nonReentrant`
(line 156); `StargateAdapterV2.lzCompose`/`handleCompose` is not (only `claimFailedTransfer` is).
Follow RelayAdapter's stricter posture — CCTP's self-serve relay is closer to Relay's threat model
than to Stargate's endpoint-gated one.

### 2.6 Cross-message interference — Medium under full-balance, eliminated under delta
Two unrelated messages (different accounts, different depositors) both name this adapter as
`mintRecipient`. Any residue left by A is inherited by B under a full-balance design.

### 2.7 Stranded funds
Only when the transfer-to-account step itself fails (blacklisted account, uncreatable account). That
is what `claimFailedTransfer` exists for — **not** for executor failures, where funds are already
delivered to the account.

### 2.8 Can `claimFailedTransfer` steal in-flight funds? — No, if scoped correctly
`failedTransfers[account][token]` is credited only for the specific failed transfer and claimable only
by `msg.sender == account` (`StargateAdapterV2.sol:360`, `RelayAdapter.sol:225`). It becomes exploitable
only if a "fallback claimant" is derived from attacker-settable input (cf. `StargateAdapterV2`'s
`composeFrom` fallback, lines 279-288). Any CCTP analog must come strictly from the attested body.

## 3. Full-balance forwarding — REJECT

**The precedent claim that justified this decision is false.** Verified directly against the code:

| Adapter | What it actually forwards | Source |
|---|---|---|
| `StargateAdapterV2` | `amountLD`, parsed from the trusted OFTComposeMsgCodec header. `preBalance` is used **only** to guard `failedTransfers` crediting. | `sol:324`, `sol:311-313` |
| `RelayAdapter` | Caller-supplied `amount`, gated by `balance - totalEscrowed[token] >= amount` | `sol:183-190` |
| `DebridgeAdapter` | `_transferredAmount` (trusted callback param) for ERC20; `address(this).balance` **only** for native ETH | `sol:111`, `sol:77` |
| `AcrossV3AdapterV2` | The `amount` param from the SpokePool push callback | `handleV3AcrossMessage` |

**Zero of four forward full ERC20 balance.** The `specs/stargate-compose-adapter/spec.md` prose says
"Transfer full adapter token balance" but the shipped code does not do that.

### Why this matters far more for CCTP than for any existing adapter

CCTP has no push callback and no gatekeeper. The adapter is a **standing, publicly known
`mintRecipient`**: anyone, on any chain, can call plain `TokenMessengerV2.depositForBurn` with
`mintRecipient = adapter`, `destinationCaller = 0`, and relay it directly through
`MessageTransmitterV2` — USDC lands at the adapter entirely outside its own code path. A plain
`IERC20.transfer` achieves the same thing more cheaply.

Combine with the fact that **token forwarding is unconditional and happens before the signature
check** (a deliberate, correct design across all adapters — money follows the message, the signature
only gates the hook), and full-balance forwarding becomes a general-purpose drain:

> An attacker burns $1 of their own USDC via `depositForBurnWithHook` with `mintRecipient = adapter`,
> `destinationCaller = adapter`, and hookData naming **their own** account with garbage
> `executorCalldata`/`signature`. The signature check fails and is caught — but the unconditional
> transfer has already sent the adapter's **entire** USDC balance to the attacker's account. Cost: a
> $1 burn plus gas.

This is Sonne Finance's mechanical shape (Appendix M.4, $20M): *never let an externally inflatable
`balanceOf(this)` determine a payout.*

### Recommendation

| Approach | Verdict |
|---|---|
| Full balance `balanceOf(this)` | **Reject** — conflates "all I hold" with "what this message minted" |
| Exact amount from a trusted push-callback param | N/A — CCTP is pull-based, there is no such param |
| **Delta around the internal `receiveMessage` call** | **Recommended** — captures exactly what this message minted; immune to donations, cross-message interference, and the reentrancy shape in §2.4 |
| Parse `amount - feeExecuted` from the attested body (offsets 216 / 312) | **Recommended as a cross-check** — take the min, or assert they match |

```solidity
uint256 preBalance = USDC.balanceOf(address(this));
bool ok = MESSAGE_TRANSMITTER.receiveMessage(message, attestation);
if (!ok) revert RECEIVE_FAILED();
uint256 received = USDC.balanceOf(address(this)) - preBalance;
```

Any excess balance the adapter holds must be untouchable by `relay()`'s normal path.

## 4. Exploit precedents

| Incident | Loss | What broke | Relevance | Our mitigation |
|---|---|---|---|---|
| **CrossCurve / Axelar `ReceiverAxelar`** (2026) | $3M | `expressExecute` accepted spoofed payloads — receiver trusted cross-chain data it never independently verified | **Directly relevant.** The generic "receiver trusts unverified data" shape | Parse hookData only from the `message` passed to `receiveMessage` in the same call. Never add a convenience `execute(bytes hookData)` entrypoint — this is exactly why the interview rejected the two-step design |
| **Sonne Finance** (Appendix M.4) | $20M | Donation into a Compound-v2-fork market distorted the rate for the next actor — protocol trusted `balanceOf(self)` as ground truth | **Mechanically identical to §3** | Delta-based forwarding |
| **Nomad Bridge** (Aug 2022, §33.3) | $190M | `bytes32(0)` root accepted as already-proven | Shape exists in the zero-initialized `usedMerkleRoots` mapping | Never add a "no dst proof found" bypass. Prefer RelayAdapter's **revert** over StargateAdapterV2's silent-credit — CCTP gives no second chance |
| **Wormhole** (Feb 2022, §33.1) | $326M | Deprecated function allowed a spoofed guardian-signed VAA | Not directly relevant (attestation is Circle's) | Never add a legacy/fallback verification branch to `relay()` |
| **LiFi / Dough Finance** (2024, Appendix M.5) | $9.7M / $6.5M | Arbitrary `target.call(callData)` with no allowlist | Process warning — the adapter makes no arbitrary calls today | Keep `MESSAGE_TRANSMITTER` and `SUPER_DESTINATION_EXECUTOR` `immutable`; never make them governance-mutable without a timelock |
| **KelpDAO / LayerZero** (Apr 2026) | $292M | Single off-chain verifier fed forged messages | Same *category* as Circle's single-attester centralization | Nothing code-side; ensure whoever signs off on "Circle is the sole trust root" sees this precedent |
| **Ronin** (2022) | $624M | Validator key compromise | Same centralization category | n/a to this contract |

## 5. Attack surface map

| Surface | Who can trigger | Severity | Mitigation |
|---|---|---|---|
| Full-balance sweep via unrelated `depositForBurn` to the adapter | Anyone, any chain | **High** | Delta forwarding (§3) |
| Full-balance sweep via plain ERC20 donation | Anyone | **High** | Delta forwarding (§3) |
| `destinationCaller` semantics differ from assumed | Design-time | **Critical if wrong** | Verified in framework-docs.md §5; fork-test it (§7.7) |
| hookData spoofing via a caller-supplied side channel | Anyone | **Critical** | Never build an `execute(hookData)` entrypoint |
| Gas-limit griefing → forced catch branch | Anyone | Medium (one-shot, no fund loss) | Gas floor + stipend (§2.2) |
| Reentrancy via hook chain into `relay()` | Intent signer / trusted hooks | Medium → Low with delta | `nonReentrant` + delta |
| Cross-message interference | Anyone | Medium → eliminated with delta | Delta forwarding |
| Returnbomb from a hostile hook | Hook composer | Medium (relayer gas) | `catch { }` with no bound variable |
| `claimFailedTransfer` cross-account theft | N/A if scoped right | Critical if broken | Key strictly by `msg.sender`; no attacker-settable fallback claimant |
| USDC blacklist on the target account | Circle | Low | `_tryTransfer` boolean + `failedTransfers` |
| Adapter itself USDC-blacklisted | Circle | Low but unrecoverable | Risk-register entry — `mintRecipient` is baked into the signed message and cannot be re-attested |
| BurnMessageV2 offset drift | Circle upgrade | Medium | Fork tests against real mainnet bytecode, not only a mock |

## 6. Recommended patterns

1. **hookData binding** — parse only from the attested `message`, never a parameter.
2. **Delta-based forwarding** (§3), cross-checked against the parsed `amount - feeExecuted`.
3. **`_tryTransfer` boolean pattern** — `StargateAdapterV2.sol:424-433` / `RelayAdapter.sol:280-289`.
4. **`try/catch` with an unbound catch** around the executor call only — never around `receiveMessage`
   (nothing to catch there; see framework-docs.md §9).
5. **Self-call wrapper for hookData decode** — `StargateAdapterV2.sol:239-247`, isolates `abi.decode`
   panics on malformed hookData.
6. **`nonReentrant` on `relay()`** — follow RelayAdapter, not StargateAdapterV2 (§2.4).
7. **`claimFailedTransfer` scoped by `msg.sender`**, credited only on genuine transfer failure.
8. **Immutable, zero-checked constructor addresses** — `ADDRESS_NOT_VALID()`, matching
   `StargateAdapterV2.sol:174-176`, `RelayAdapter.sol:129-131`, `DebridgeAdapter.sol:34-36`.
9. **Custom errors, not revert strings** — CLAUDE.md standard.
10. **Explicit gas floor before the executor call** (§2.2).

## 7. Testing recommendations

**Invariants**
- `invariant_forwardedAmountEqualsMintDelta` — never transfer more than the delta measured strictly
  around `receiveMessage`, regardless of pre-existing balance.
- `invariant_adapterUSDCBalanceZeroAfterRelay` — post-`relay()` balance equals exactly the escrowed
  `failedTransfers` total.
- `invariant_noFundsMoveToUnnamedAccount` — the only recipient is the `account` decoded from that
  message's own hookData.
- `invariant_claimFailedTransferOnlyBySelf` — no sequence lets `msg.sender` drain another account.
- `invariant_relayNeverPermanentlyReverts` — malformed hookData / reverting executor never blocks a
  subsequent unrelated `relay()`.
- `invariant_usedMerkleRootNotConsumedOnExecutorRevert` — documents the one-shot interaction in §2.2.

**Adversarial unit tests**
1. **Self-funding drain** (the centerpiece): pre-fund the adapter by plain transfer, relay a legitimate
   small message for `attackerAccount`, assert the attacker receives only that message's minted amount
   and the pre-existing balance stays put.
2. **Two messages in one transaction** — different accounts and amounts; assert each receives exactly
   its own.
3. **Reentrant relay via a mock hook** that reenters with a second valid message during `_execute()`.
4. **Gas-griefed relay** — calibrate so mint+transfer succeed and the executor fails; assert tokens are
   at the account, the root is unused, and a second `relay()` reverts (`"Nonce already used"`).
5. **Blacklisted account** — assert funds land in `failedTransfers`, claimable only by the account, and
   `relay()` does not revert.
6. **Malformed hookData** — assert no revert and no funds move.
7. **`destinationCaller` bypass attempt** — fork test calling `MessageTransmitterV2.receiveMessage`
   *directly* for a message whose `destinationCaller == adapter`; assert it reverts against real
   deployed bytecode, not just a mock.
8. **Offset-correctness fork test** — relay a real attested message through the real mainnet
   transmitter via the existing `pigeon` `CctpV2Helper` machinery already used in `CCTPHooksFork.t.sol`,
   confirming hookData extraction at global offset 376.
