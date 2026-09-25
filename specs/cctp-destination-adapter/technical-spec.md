# CCTP Destination Adapter — Technical Specification

**Feature:** `src/adapters/CCTPAdapter.sol`
**Date:** 2026-09-21 · **Status:** Draft, pending pod leader approval
**Security mode:** enabled (cross-chain, token custody, permissionless entrypoint)

## Overview

Build the destination-side adapter that completes Circle's CCTP V2 flow for the already-deployed
`CCTPSendHook` / `ApproveAndCCTPSendHook`. The adapter is set as both `mintRecipient` and
`destinationCaller` on the source burn; it exposes a permissionless
`relay(bytes message, bytes attestation)` that calls `MessageTransmitterV2.receiveMessage` itself,
takes custody of the minted USDC, parses `hookData` from the same attested message, forwards the
exact minted amount to the target smart account, and calls
`SuperDestinationExecutor.processBridgedExecution`.

## Problem statement

`src/adapters/` holds adapters for Across (V1+V2), deBridge, Relay, and Stargate (V1+V2) — but none
for CCTP or Circle Gateway, while the CCTP source hooks are **live in prod on every chain**.

The gap is not deliberate. `specs/cctp-bridge-hooks/interview-notes.md:28-33` asserted:

> *"Send-side hooks only — no receive hook needed. Circle's attestation service + off-chain relayers
> handle the receive side (calling receiveMessage on MessageTransmitter)."*

**That is wrong.** `MessageTransmitterV2.receiveMessage` verifies the attestation and mints to
`mintRecipient`, then stops — it never reads `hookData`. Circle's docs are explicit: *"CCTP does not
implement hook execution in the core protocol. Instead, hooks are treated as opaque metadata passed
along with the burn message."* Whoever relays the message is fully responsible for executing the hook.

The consequence is already shipped: `CCTPSendHook` builds
`abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)` — the exact
6-tuple `DebridgeAdapter._decodeMessage` (`src/adapters/DebridgeAdapter.sol:158`) decodes — and hands
it to `depositForBurnWithHook`. **A wire format exists with no consumer.** Any CCTP transfer carrying
`hookCallData` today delivers USDC and silently does nothing else.

## Proposed solution

A wrapper-pattern adapter modelled on Circle's own `CCTPHookWrapper`, with Superform's decode and
failure-handling conventions:

```
Source chain                          Destination chain

CCTPSendHook                          CCTPAdapter
 depositForBurnWithHook(                relay(message, attestation)   [permissionless, nonReentrant]
   mintRecipient      = dstAdapter       │ 1. assert message version == 1  (uint32 @ 0)
   destinationCaller  = dstAdapter       │ 2. preBalance = token.balanceOf(this)
   hookData           = 6-tuple)         │ 3. MessageTransmitterV2.receiveMessage(message, attestation)
 │                                       │ 4. received = postBalance - preBalance
 └──── Circle attestation ───────────►   │    cross-check vs (amount@216 - feeExecuted@312)
                                         │ 5. hookData = message[376:] → self-call decode (6-tuple)
                                         │ 6. gas floor check
                                         │ 7. _tryTransfer(token, account, received)
                                         │      └─ on failure: credit failedTransfers + totalEscrowed
                                         │ 8. try processBridgedExecution(...) catch { emit }
```

## Technical considerations

### Why the adapter must be `mintRecipient`
CCTP has no push callback. There is no analogue to `handleV3AcrossMessage` or `lzCompose` — nothing
calls the adapter. It must pull the message in, which means it must hold the funds to forward them.

### Why `destinationCaller` must be the adapter
`MessageTransmitterV2._validateReceivedMessage` enforces
`require(destinationCaller == msg.sender.toBytes32(), "Invalid caller for message")` when the field is
non-zero. Because the adapter calls `receiveMessage` from inside `relay()`, `msg.sender` seen by the
transmitter is **the adapter contract**, not the EOA that called `relay()`. That is what makes
"permissionless `relay()` + restricted `destinationCaller`" work: anyone may trigger it, but the mint
can only ever happen inside the adapter's own code path, atomically with hook execution.

With `destinationCaller = bytes32(0)` instead, a third party calls `receiveMessage` directly, USDC
mints to the adapter, nothing executes, no `failedTransfers` credit is recorded, and the nonce is
spent — permanently stranded absent an admin rescue that this scope rejects.

### Deliberate divergence from Circle's reference wrapper
Circle's `CCTPHookWrapper.relay()` is **`onlyOwner`**, with this warning:

> *"Due to the lack of atomicity with the hook call, permissionless relay of messages containing hooks
> via an implementation like this contract should be carefully considered, as a malicious caller could
> use a low gas attack to consume the message's nonce without executing the hook."*

We diverge deliberately. Circle's wrapper does not check `destinationCaller` at all, so for them an
open `relay()` means anyone can burn the nonce. Pinning `destinationCaller` to the adapter closes the
direct path; the residual is gas-starvation *through* `relay()`, addressed by the gas floor below and
bounded by the fact that `processBridgedExecution` is itself permissionless and re-drivable.
**State this in the contract NatSpec** — a reviewer will otherwise ask why it isn't `onlyOwner`.

### Message format: 6-tuple, dictated not chosen
The live hooks emit the 6-tuple; they are locked bytecode and a V2 hook is out of scope. A 2-tuple
adapter would decode the wrong arity. Decode as `DebridgeAdapter._decodeMessage` does.

The adapter should **still** walk `sigData.proofDst[]` to assert `executor == SUPER_DESTINATION_EXECUTOR`
and `validator == SUPER_DESTINATION_VALIDATOR`, mirroring `AcrossV3AdapterV2.sol:176-187`. Without
those checks, an intent signed for a different chain's executor produces a forwarded-but-never-executed
delivery. This also pre-builds the `_extractFromSigData` helper, making a future 2-tuple migration cheap.

### Which token to measure and forward
The minted token is the destination-chain USDC, which cannot be derived from the message's `burnToken`
(a source-chain address). Taking local USDC as a constructor argument would break the single-CREATE2-
address property (§ Deployment).

**Decision: use `dstTokens[0]` from the attested hookData.** It is covered by the signature, and the
balance delta is itself the guard — a message naming the wrong token yields a delta of 0 and moves
nothing, while the executor's signature check fails independently. Revert if `dstTokens.length == 0`.

*Alternative considered:* `ITokenMinterV2.getLocalToken(remoteDomain, remoteToken)` — correct but needs
a third constructor argument. Rejected to preserve address determinism.

## Attack surface analysis

Full analysis in [research/evm-security.md](./research/evm-security.md).

### The finding that changed the design: full-balance forwarding is unsafe here

The interview chose full-balance forwarding on the stated precedent that it matched
`StargateAdapterV2` and `RelayAdapter`. **That precedent is false.** Verified:

| Adapter | Actually forwards |
|---|---|
| `StargateAdapterV2:324` | `amountLD` from the trusted LZ header (`preBalance` only guards `failedTransfers`) |
| `RelayAdapter:183-190` | caller-supplied `amount`, gated by `balance - totalEscrowed[token] >= amount` |
| `DebridgeAdapter:111` | `_transferredAmount` callback param (balance used *only* for native ETH, `:77`) |
| `AcrossV3AdapterV2` | the `amount` param from the SpokePool callback |

Zero of four forward full ERC20 balance. And CCTP is uniquely exposed: the adapter is a **standing,
publicly known `mintRecipient`** — anyone can `depositForBurn` to it from any chain, or simply
`IERC20.transfer` to it, entirely outside its code path. Since forwarding is unconditional and precedes
the signature check (correct, and true of every adapter — money follows the message, the signature only
gates the hook), full-balance forwarding is a drain:

> Attacker burns $1 via `depositForBurnWithHook` with `mintRecipient = adapter`,
> `destinationCaller = adapter`, hookData naming **their own** account with a garbage signature. The
> signature check fails and is caught — but the unconditional transfer already sent the adapter's
> **entire** balance to them. Cost: $1 plus gas.

Sonne Finance's shape (Appendix M.4, $20M): never let an externally inflatable `balanceOf(this)`
determine a payout. Worse still, full-balance forwarding would **raid the `failedTransfers` escrow** —
which is exactly why `RelayAdapter` maintains `totalEscrowed` (`:49`).

**Resolution: balance delta measured strictly around `receiveMessage`, cross-checked against
`amount@216 - feeExecuted@312` parsed from the attested body. Forward the minimum.**

### Checklist

**Cross-chain (Sec 16, 33)**
- [x] Message replay — `MessageTransmitterV2.usedNonces`; duplicate reverts `"Nonce already used"`
- [x] Intent replay — `SuperDestinationExecutor.usedMerkleRoots` (`:127-132`)
- [x] hookData bound to the attested message; **no `execute(hookData)` side channel** (CrossCurve, $3M)
- [x] No "no dst proof found" bypass (Nomad, $190M)

**Access control (Sec 2)**
- [x] `relay()` permissionless by design; enforcement lives at `destinationCaller`
- [x] Immutables zero-checked, never governance-mutable (LiFi/Dough, $9.7M/$6.5M)
- [x] No `tx.origin` shortcut

**Reentrancy (Sec 1)**
- [x] `nonReentrant` on `relay()` and `claimFailedTransfer()` (RelayAdapter posture, not Stargate's)
- [x] Delta accounting is per-call-frame, so nested relays cannot interfere
- [x] Transfer precedes the executor call (CEI-consistent with all adapters)

**Token behavior (Sec 10)**
- [x] `_tryTransfer` low-level pattern, not bare `transfer` (10.3)
- [x] USDC blocklist/pause on the account → `failedTransfers`, `relay()` does not revert
- [ ] **Risk register:** adapter itself blacklisted → affected messages permanently unmintable
      (`mintRecipient` is baked into the signed message and cannot be re-attested)
- [x] Balance-delta idiom (10.1's canonical fix) repurposed for bridge-hop accounting

**Gas / DoS (Sec 7, Appendix H)**
- [x] `catch { }` binds nothing — returnbomb-safe (H.1)
- [x] Self-call decode isolation for malformed hookData
- [x] `MIN_EXECUTION_GAS` floor + `{gas: G}` stipend
- [x] A hostile hook cannot block a subsequent unrelated `relay()`

**Flash loan / MEV (Sec 5, 6)** — n/a. The burn is irreversible; no price or slippage surface.

## Known failure modes

### Silent non-execution — `try/catch` does not see it
`processBridgedExecution` **returns normally** (no revert) on three distinct failures: insufficient
balance (`:125`), already-used merkle root (`:127-130`), and empty/foreign executor calldata
(`:134-137`). The try/catch only covers the revert path.

**An adapter author must not read "no catch fired" as "executed."** The adapter emits `Relayed(...)`
unconditionally; off-chain correlation against `SuperDestinationExecutorExecuted` /
`…ReceivedButNotEnoughBalance` / `…ReceivedButRootUsedAlready` distinguishes the cases. Do not add an
on-chain success assertion — it would revert the relay and re-strand the funds.

### Gas-limit griefing — Medium, one-shot
A caller tunes gas so `receiveMessage` and the transfer succeed but the executor call dies under
EIP-150's 63/64 rule. Worse for CCTP than Stargate: the merkle-root write at `:132` is rolled back by
the revert (so the root stays unused), but **CCTP's nonce is consumed**, so `relay()` can never be
called again for that message. Unlike `lzCompose`, it is one-shot.

Bounded, not fatal: tokens are already at the account and `processBridgedExecution` is permissionless
(`:94-105`), so anyone can re-drive the same payload — the documented recovery path. Mitigated by the
gas floor; residual risk documented.

### Recovery runbook
`processBridgedExecution` has **no access control**. For every silent-no-op and every griefed relay,
recovery is: top the account up to `intentAmounts[0]` if short, then re-call `processBridgedExecution`
with the same six arguments. This belongs in ops docs.

## ⚠️ Scope risk: the 8192-byte message-body ceiling

**Measured live this session:** `MessageTransmitterV2.maxMessageBodySize() == 8192` (and
`version() == 1`) at `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`.

`messageBody = BurnMessageV2 (228 fixed) + hookData`, therefore:

> **`hookData` must be ≤ 7964 bytes, or `depositForBurnWithHook` reverts on the source chain.**

The 6-tuple is the fat format. `specs/stargate-compose-data-minimization/spec.md:12` measured
`executorCalldata` at 1–5 KB and the 6-tuple's duplication overhead at 1.5–5.5 KB — and that migration
was forced by LayerZero's **10 KB** limit. **CCTP's ceiling is 20% tighter.**

Rough sizing: a 2-hook destination intent lands around 2–2.5 KB (comfortable). A 4–5-hook intent with
7702 initcode and a deep merkle proof plausibly reaches 6–9 KB — **at or over the ceiling**.

**This is the one finding that can invalidate the adapter-only scope**, so it is gated as Phase 0:
measure before the design is frozen. If real intents don't fit, a `CCTPSendHookV2` emitting the compact
2-tuple is unavoidable (copy `StargateSendHookV2.sol:159-171`) — a new contract, bytecode lock,
deployment index, and SDK migration. Escalate to the product owner *before* the adapter is audited, not
after.

## Implementation

### `src/vendor/bridges/cctp/IMessageTransmitterV2.sol` (new)
Model on `lib/pigeon/src/cctp/interfaces/IMessageTransmitterV2.sol` and the NatSpec style of the
existing `ITokenMessengerV2.sol`. Minimum: `receiveMessage(bytes,bytes) returns (bool)`.

### `src/adapters/CCTPAdapter.sol` (new)

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

contract CCTPAdapter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- STORAGE ---
    address public immutable MESSAGE_TRANSMITTER;          // 0x81D4...4B64, same on all chains
    ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;
    address public immutable SUPER_DESTINATION_VALIDATOR;  // cached via IDestinationValidatorSource

    mapping(address account => mapping(address token => uint256)) public failedTransfers;
    mapping(address token => uint256) public totalEscrowed;

    uint256 private constant SUPPORTED_MESSAGE_VERSION = 1;
    uint256 private constant HOOK_DATA_OFFSET   = 376;  // 148 header + 228 BurnMessageV2 prefix
    uint256 private constant AMOUNT_OFFSET      = 216;
    uint256 private constant FEE_EXECUTED_OFFSET = 312;
    uint256 private constant MIN_EXECUTION_GAS  = /* tune against worst-case hook chain */;

    // --- ERRORS ---
    error ADDRESS_NOT_VALID();
    error UNSUPPORTED_MESSAGE_VERSION();
    error RECEIVE_MESSAGE_FAILED();
    error ACCOUNT_NOT_VALID();
    error EXECUTOR_NOT_VALID();
    error VALIDATOR_NOT_VALID();
    error DST_TOKENS_EMPTY();
    error INSUFFICIENT_GAS();
    error NOTHING_RECEIVED();

    // --- EVENTS ---
    event Relayed(address indexed account, address indexed token, uint256 amount);
    event TransferFailed(address indexed account, address indexed token, uint256 amount);
    event ExecutionFailed(address indexed account);
    event DecodeFailed();

    constructor(address messageTransmitter_, address superDestinationExecutor_) { /* zero-check both */ }

    /// @notice Relay an attested CCTP V2 message: mint, forward, execute.
    /// @dev Permissionless by design. Diverges from Circle's onlyOwner CCTPHookWrapper because
    ///      `destinationCaller` is pinned to this adapter, so no third party can consume the nonce
    ///      outside this code path. See technical-spec.md "Deliberate divergence".
    function relay(bytes calldata message, bytes calldata attestation) external nonReentrant {
        // 1. Reject V1 / unknown versions — uint32 at offset 0
        if (BytesLib.toUint32(message, 0) != SUPPORTED_MESSAGE_VERSION) revert UNSUPPORTED_MESSAGE_VERSION();

        // 2. Decode hookData from the attested bytes (self-call isolates abi.decode panics)
        try this.decodeHookData(message) returns (DecodedMessage memory d) {
            if (d.account == address(0)) revert ACCOUNT_NOT_VALID();
            if (d.dstTokens.length == 0) revert DST_TOKENS_EMPTY();
            // executor/validator assertions from sigData.proofDst[] — AcrossV3AdapterV2:176-187
            ...
            address token = d.dstTokens[0];

            // 3. Mint, measuring exactly what THIS message delivered
            uint256 preBalance = IERC20(token).balanceOf(address(this));
            if (!IMessageTransmitterV2(MESSAGE_TRANSMITTER).receiveMessage(message, attestation)) {
                revert RECEIVE_MESSAGE_FAILED();
            }
            uint256 received = IERC20(token).balanceOf(address(this)) - preBalance;

            // 4. Cross-check against the attested body; forward the smaller
            uint256 claimed = BytesLib.toUint256(message, AMOUNT_OFFSET)
                            - BytesLib.toUint256(message, FEE_EXECUTED_OFFSET);
            uint256 amount = received < claimed ? received : claimed;
            if (amount == 0) revert NOTHING_RECEIVED();

            // 5. Forward — degrade to escrow, never revert the relay
            if (!_tryTransfer(token, d.account, amount)) {
                failedTransfers[d.account][token] += amount;
                totalEscrowed[token] += amount;
                emit TransferFailed(d.account, token, amount);
            }
            emit Relayed(d.account, token, amount);

            // 6. Best-effort execution behind an explicit gas floor
            if (gasleft() < MIN_EXECUTION_GAS) revert INSUFFICIENT_GAS();
            try SUPER_DESTINATION_EXECUTOR.processBridgedExecution{ gas: MIN_EXECUTION_GAS }(
                token, d.account, d.dstTokens, d.intentAmounts, d.initData, d.executorCalldata, d.sigData
            ) { } catch { emit ExecutionFailed(d.account); }   // unbound catch — returnbomb-safe
        } catch {
            emit DecodeFailed();
        }
    }

    /// @notice External only so `relay` can self-call it and contain abi.decode panics.
    /// @dev Mirrors StargateAdapterV2.handleCompose (:239-247). Reverts if not self-called.
    function decodeHookData(bytes calldata message) external view returns (DecodedMessage memory) {
        // hookData = message[376:], then the 6-tuple — identical to DebridgeAdapter:158
        (bytes memory initData, bytes memory executorCalldata, address account,
         address[] memory dstTokens, uint256[] memory intentAmounts, bytes memory sigData) =
            abi.decode(message[HOOK_DATA_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes));
        ...
    }

    /// @notice Claim tokens from a failed forward. Only the intended recipient may claim.
    function claimFailedTransfer(address token, uint256 amount) external nonReentrant { /* RelayAdapter:222-239 */ }

    function _tryTransfer(address token, address to, uint256 amt) internal returns (bool) { /* RelayAdapter:280-289 */ }
}
```

### Message offsets (verified against `circlefin/evm-cctp-contracts`)

| Field | Absolute offset | Size |
|---|---|---|
| `version` | 0 | 4 |
| `destinationCaller` | 108 | 32 |
| `messageBody` starts | 148 | — |
| `mintRecipient` | 184 | 32 |
| `amount` | 216 | 32 |
| `maxFee` | 280 | 32 |
| `feeExecuted` | 312 | 32 |
| `expirationBlock` | 344 | 32 |
| **`hookData`** | **376** | dynamic |

## Deployment

**Constructor must stay `(messageTransmitterV2, superDestinationExecutor)` — two args, nothing more.**
Both are chain-invariant in prod (`MessageTransmitterV2 = 0x81D4…4B64` everywhere;
`SuperDestinationExecutor = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF` on all 18 prod chains), so the
adapter gets **one CREATE2 address on every chain**. That is what makes pinning `destinationCaller`
cheap for the SDK — a single constant, no per-chain lookup, no risk of using chain A's address in chain
B's intent. Precedent: `RelayAdapter` (1 arg → one address on 17 chains), `DebridgeAdapter` (14 chains).
Counter-examples to avoid: `AcrossV3AdapterV2` (10 distinct addresses), `StargateAdapterV2` (14).

Steps:
1. `CoreContracts` struct field (`DeployV2Core.s.sol:28-32`).
2. `adapterContracts` `string[5]` → `string[6]` + `"CCTPAdapter"` (`:353-355`; `expectedAdapters` at `:358`).
3. `CCTP_ADAPTER_KEY` and `CCTP_V2_MESSAGE_TRANSMITTER` in `script/utils/Constants.sol` — a **flat
   constant**, matching `CCTP_V2_TOKEN_MESSENGER` (`:358`), not a per-chain `ConfigCore` map.
4. **Conditional availability gating** on `MessageTransmitterV2.code.length > 0`, following the other 5
   adapters (`_getContractAvailability:341-397`) — *not* the CCTP hooks' unconditional pattern. The
   hooks deploy on chains with no CCTP at all (Flare has no transmitter code).
5. `_checkAdapterContracts` verification block (`:1755-1838`).
6. Add `"CCTPAdapter"` to `CORE_CONTRACTS` in `script/run/tooling/regenerate_bytecode.sh:82-98`; create
   `script/locked-bytecode{,-dev}/CCTPAdapter.json` (manual, reviewed — no automated copy exists).

No change to `_buildCoreVerificationRecords` or its `length == 14` regression test — adapters use a
separate verification path. Prod output JSON is written automatically.

⚠️ **BSC unverified:** CCTP domain 17 exists for BNB Smart Chain but a secondary source raised an
unconfirmed USDC support caveat. Confirm before deploying there.

## SDK integration checklist

| # | Requirement | Breakage if wrong |
|---|---|---|
| 1 | `mintRecipient` (off 108) = `bytes32(uint160(CCTPAdapter))` | USDC mints elsewhere; hookData never executed; **loss** |
| 2 | `destinationCaller` (off 140) = same adapter, **not** `bytes32(0)` | Third party receives the mint; USDC stranded, no `relay()` path, no escrow credit |
| 3 | `burnToken` (off 52) = source-chain USDC | Reverts inside TokenMessengerV2 |
| 4 | `destinationDomain` (off 104) = CCTP **domain id**, not chain id | Routed to the wrong chain. No recovery |
| 5 | `hookCallData` = 5-tuple `(initData, executorCalldata, account, dstTokens, intentAmounts)`, **no sigData**, last field, no length prefix | Hook's `abi.decode` reverts → UserOp reverts (fails loudly) |
| 6 | `intentAmounts[0] <= amount - maxFee`, and `> 0` | Silent no-op; funds idle on account; root unconsumed |
| 7 | `dstTokens[0]` = **destination-chain** USDC | Adapter measures the wrong token → delta 0 → nothing moves |
| 8 | `dstTokens.length == intentAmounts.length` | `ARRAY_LENGTH_MISMATCH` → catch fires, funds already forwarded |
| 9 | `chainsWithDestinationExecution` includes the CCTP destination, 1:1 with `proofDst` | `retrieveSignatureData` returns `""`; empty sigData; **funds forwarded, never executed** |
| 10 | `proofDst[i].info.executor` / `.validator` = the destination's executor/validator | `INVALID_SIGNATURE` inside the try → forwarded, never executed |
| 11 | `proofDst[i].info.account` == the outer `account` | Signature fails |
| 12 | `hookData` total ≤ **7964 bytes** | `depositForBurnWithHook` reverts on source. See Phase 0 |
| 13 | `amount` (off 72) non-zero **even when `usePrevHookAmount == true`** | `maxFee` scaling is skipped when `amount == 0` (`CCTPSendHook:134`); a stale absolute `maxFee >= actual` reverts `maxFee < amount` |
| 14 | Use `ApproveAndCCTPSendHook`, or chain an approve hook first | `CCTPSendHook` does no approval; burn reverts on allowance |

⚠️ **The layout in `specs/cctp-bridge-hooks/spec.md:47-58` and `technical-spec.md:131-141` is
obsolete** — it lacks the 52-byte strategy header and invents a `hookCallDataLength` field. Canonical
source is `src/hooks/bridges/cctp/CCTPSendHook.sol:32-43`. An SDK encoder built from the old spec
produces unparseable data.

## Chained-hook caveat (inherited, not CCTP-specific)

`usePrevHookAmount` scales `maxFee` proportionally via `Math.mulDiv` (`CCTPSendHook:130-139`), but
**`intentAmounts` scales with nothing** — it is fixed at signing. If the preceding swap underperforms
(`A' < A`), delivery can fall below `intentAmounts[0]` and the destination silently no-ops. Across
(`AcrossSendFundsAndExecuteOnDstHookV2:126-128`) and Stargate (`StargateSendHookV2:151-154`) have the
identical limitation. **Mitigation is SDK-side:** set
`I = floor((A - maxFee) * (1 - slippageFloorBps/10_000))` using the same floor the swap hook enforces.

Also: OMS `replaceCalldataAmounts` rewrites only the amount slot at offset 72 — `maxFee` (172) and
`intentAmounts` (inside hookCallData) are left stale. Any OMS resize of a CCTP leg needs an SDK-side
re-derivation before signing. No on-chain backstop.

## Implementation plan

### Phase 0 — Payload-size gate (blocking, ~30 min)
- [ ] Encode the 2–3 most complex CCTP intents the product intends to ship, with a realistic
      `SignatureData`, and assert `hookData.length <= 7964`
- [ ] **If it fits:** proceed, add an SDK pre-flight length assertion and a documented hook-count cap
- [ ] **If it does not:** escalate — `CCTPSendHookV2` (compact 2-tuple) becomes mandatory and the
      adapter-only scope is void

### Phase 1 — Contract
- [ ] `src/vendor/bridges/cctp/IMessageTransmitterV2.sol`
- [ ] `src/adapters/CCTPAdapter.sol` — delta accounting, cross-check, self-call decode, gas floor,
      `nonReentrant`, escrow + claim, executor/validator assertions
- [ ] NatSpec documenting the divergence from Circle's `onlyOwner` wrapper
- [ ] Tune `MIN_EXECUTION_GAS` against the worst-case hook chain

### Phase 2 — Tests
- [ ] `MockMessageTransmitterV2` (none exists in `test/mocks/`)
- [ ] Unit suite modelled on `RelayAdapterUnitTests.t.sol` + `AdaptersUnitTests._buildDestinationData()`
- [ ] The 8 adversarial tests in research/evm-security.md §7 — the self-funding drain test first
- [ ] Fork suite extending `CCTPHooksForkE2E` (`:882-1229`): point `mintRecipient`/`destinationCaller`
      at the adapter, call `adapter.relay(...)`. Needs a `CctpV2Helper` variant that returns
      `(message, attestation)` instead of calling `receiveMessage` itself
- [ ] Replace `MockCCTPForkSignatureStorage`'s empty `proofDst` (`:20-28`) with a populated fixture

### Phase 3 — Deployment
- [ ] Deploy-script wiring, conditional availability gating, constants
- [ ] Bytecode regeneration + locked artifacts
- [ ] Verify one CREATE2 address across chains before broad rollout

## Risks

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|---|---|---|---|---|---|
| hookData exceeds 7964 bytes | Business logic | **Medium** | **High** — voids adapter-only scope | Phase 0 gate; fallback `CCTPSendHookV2` | Stargate hit LZ's 10 KB limit |
| Full-balance drain (**resolved in design**) | Vault accounting | High if built as first specified | Critical | Delta + parsed cross-check | Sonne Finance, $20M |
| SDK sets `destinationCaller = 0` | Cross-chain | Medium | High — stranded funds | SDK checklist #2; pre-flight assert | — |
| SDK omits `chainsWithDestinationExecution` | Cross-chain | Medium | Medium — forwarded, never executed | SDK checklist #9 | — |
| Gas-limit griefing | Operational | Medium | Low-Medium — one-shot, no loss | Gas floor; permissionless re-drive | Circle's own warning |
| Silent no-op misread as success | Operational | High | Medium | `Relayed` event + off-chain correlation | — |
| Adapter USDC-blacklisted | Token behavior | Very low | High — permanently unmintable | Risk accepted; `mintRecipient` cannot be re-attested | — |
| Circle attester compromise | Cross-chain | Very low | Critical | Accepted centralization | KelpDAO $292M; Ronin $624M |
| BurnMessageV2 offset drift | Cross-chain | Low | High | Fork tests against real bytecode | — |
| Hook-side data layout confusion | Operational | Medium | Medium | Old spec marked obsolete; cite the source file | — |

## References

**Internal** — `src/adapters/{DebridgeAdapter,RelayAdapter,StargateAdapterV2,AcrossV3AdapterV2}.sol`;
`src/executors/SuperDestinationExecutor.sol:94-214`; `src/hooks/bridges/cctp/CCTPSendHook.sol:32-43,110-181`;
`lib/pigeon/src/cctp/CctpV2Helper.sol`; `specs/cctp-bridge-hooks/`; `specs/stargate-compose-adapter/`;
`specs/stargate-compose-data-minimization/spec.md:12`

**External** — `circlefin/evm-cctp-contracts` (`src/v2/MessageTransmitterV2.sol`, `src/v2/TokenMessengerV2.sol`,
`src/messages/v2/{MessageV2,BurnMessageV2}.sol`, `src/examples/CCTPHookWrapper.sol`);
developers.circle.com/cctp

**Research** — [repo-analysis.md](./research/repo-analysis.md) ·
[framework-docs.md](./research/framework-docs.md) · [evm-security.md](./research/evm-security.md) ·
[hook-master-plan.md](./research/hook-master-plan.md)
