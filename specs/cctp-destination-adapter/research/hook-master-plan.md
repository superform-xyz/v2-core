# CCTP Destination Adapter — Source-Hook Side Analysis

**Scope:** the SOURCE-HOOK half of `src/adapters/CCTPAdapter.sol` and its coupling to the already-deployed
`CCTPSendHook` / `ApproveAndCCTPSendHook`.
**Status:** research/planning only. No code written, no files modified.
**Companion:** `specs/cctp-destination-adapter/interview-notes.md`

---

## 0. Executive summary (read this first)

1. **The payload contract holds.** `CCTPSendHook` emits exactly the 6-tuple
   `abi.encode(bytes,bytes,address,address[],uint256[],bytes)` that `DebridgeAdapter._decodeMessage`
   (`src/adapters/DebridgeAdapter.sol:157-158`) decodes. **Zero field-level mismatch.** An adapter written to
   the deBridge shape will decode CCTP `hookData` correctly.
2. **No hook change is required.** `mintRecipient` (offset 108) and `destinationCaller` (offset 140) are both
   free-form caller-supplied `bytes32` with no constraint beyond `mintRecipient != bytes32(0)`
   (`CCTPSendHook.sol:123`). The SDK can set both to the destination adapter today.
3. **A CCTPAdapter constructed as `(MessageTransmitterV2, SuperDestinationExecutor)` gets the SAME CREATE2
   address on every chain** — both args are already chain-invariant in prod. This removes the single biggest
   SDK objection to the `destinationCaller`-restriction decision.
4. **HARD CONSTRAINT the interview notes miss: `maxMessageBodySize == 8192`** on `MessageTransmitterV2`
   (verified live on Ethereum/Optimism/Base/Linea). With the fat 6-tuple, `hookData` is capped at **7964 bytes**
   and complex intents WILL revert at `depositForBurnWithHook` on the source chain. This is the one finding that
   could force a `CCTPSendHookV2`. See §7.
5. **Two source-side footguns the SDK must get right or funds sit idle on destination:** the
   `amount == 0 && usePrevHookAmount == true` pattern silently disables `maxFee` scaling (`CCTPSendHook.sol:134`),
   and `intentAmounts` is never rescaled when the chained amount moves. See §3 and §5.

---

## 1. Payload contract between hook and adapter

### 1.1 Hook packed input layout (what the SDK encodes into `hooksData[i]`)

Both hooks are byte-identical on the decode path. Source of truth:
`src/hooks/bridges/cctp/CCTPSendHook.sol:32-43` (NatSpec) and `:110-128` (code);
mirrored verbatim at `src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol:32-43` and `:110-128`.

| Offset | Type      | Field                  | Read at |
|--------|-----------|------------------------|---------|
| 0      | bytes32   | `placeholder0`         | — |
| 32     | address   | `placeholder1`         | — |
| 52     | address   | `burnToken`            | `CCTPSendHook.sol:113` |
| 72     | uint256   | `amount`               | `:114` (`AMOUNT_POSITION = 72`, `:51`) |
| 104    | uint32    | `destinationDomain`    | `:115` |
| 108    | bytes32   | `mintRecipient`        | `:116` |
| 140    | bytes32   | `destinationCaller`    | `:117` |
| 172    | uint256   | `maxFee`               | `:118` |
| 204    | uint32    | `minFinalityThreshold` | `:119` |
| 208    | bool      | `usePrevHookAmount`    | `:130` (`USE_PREV_HOOK_AMOUNT_POSITION = 208`, `:50`) |
| 209    | bytes     | `hookCallData`         | `:127` — **slice to end, NO length prefix** |

**Correction to carry into the spec:** `specs/cctp-bridge-hooks/spec.md:47-58` and
`specs/cctp-bridge-hooks/technical-spec.md:131-141` document a *different, obsolete* layout — no 52-byte
strategy header, and a `uint256 hookCallDataLength` at offset 157. The **deployed** hook has neither.
`hookCallData` is `BytesLib.slice(data, 209, data.length - 209)` — it must be the last field and its length is
implicit. Anyone reading the old spec to build an SDK encoder will produce garbage. Treat
`CCTPSendHook.sol:32-43` as canonical.

Validation the hook performs, in order (`CCTPSendHook.sol:110-141`):
- `data.length < 209` → `DATA_NOT_VALID()` (`:110`)
- `burnToken == address(0)` → `ADDRESS_NOT_VALID()` (`:122`)
- `mintRecipient == bytes32(0)` → `RECIPIENT_NOT_VALID()` (`:123`)
- `amount == 0` (post-chaining) → `AMOUNT_NOT_VALID()` (`:141`)
- `hookCallData.length > 0 && < 160` → `DATA_NOT_VALID()` (`:146`)

Notably **absent**: any constraint on `destinationCaller`, `destinationDomain`, `maxFee`, or
`minFinalityThreshold`. `destinationCaller == bytes32(0)` (permissionless receive) is accepted by the hook.

### 1.2 The signature-append path

`CCTPSendHook.sol:143-159` / `ApproveAndCCTPSendHook.sol:143-159`:

```
if (hookCallData.length > 0) {
    if (hookCallData.length < 160) revert DATA_NOT_VALID();                       // :146
    bytes memory signature = ISuperSignatureStorage(VALIDATOR)
                                 .retrieveSignatureData(account);                 // :148
    (initData, executorCalldata, _account, dstTokens, intentAmounts) =
        abi.decode(hookCallData, (bytes, bytes, address, address[], uint256[]));  // :150-156
    hookCallData = abi.encode(initData, executorCalldata, _account,
                              dstTokens, intentAmounts, signature);               // :158
}
```

Three things the adapter author must internalise:

- **The SDK supplies a 5-tuple; the wire carries a 6-tuple.** The hook re-encodes. The SDK never encodes
  `sigData` itself (it cannot — the signature commits to the merkle root that would contain it;
  see the circular-dependency note at `CCTPSendHook.sol:28-31`).
- **`signature` is the FULL `SignatureData` blob**, not a raw 65-byte ECDSA signature.
  `SuperValidator.validateUserOp` stores `_userOp.signature` verbatim into transient storage
  (`src/validators/SuperValidator.sol:94-95`), and `retrieveSignatureData` returns it
  (`:29-32`). Its shape is `abi.encode(uint64[], uint48, uint48, bytes32, bytes32[], DstProof[], bytes)`
  (`src/interfaces/ISuperValidator.sol:45-60`). Confirmed by the executor's own decode at
  `src/executors/SuperDestinationExecutor.sol:173-177`.
- **The transient store is only populated when `chainsWithDestinationExecution.length > 0`**
  (`SuperValidator.sol:61,94-95`). If the SDK forgets to populate `chainsWithDestinationExecution` in the
  signature, `retrieveSignatureData` returns empty bytes, the hook happily encodes
  `sigData = ""`, the burn goes through, and the destination adapter's
  `abi.decode(sigData, (...))` — or `SuperDestinationValidator.isValidDestinationSignature` — fails.
  **Funds mint to the adapter, forward to the account, execution never happens.** Silent, irreversible.

**On the `< 160` guard:** the true minimum ABI encoding of `(bytes, bytes, address, address[], uint256[])` is
**288 bytes** (5×32 head + 4×32 minimum tail length-words), not 160. The guard is a cheap lower bound;
`abi.decode` at `:150-156` does the real bounds checking and reverts on anything malformed. Not a
vulnerability — just don't rely on `>= 160` implying decodability.

### 1.3 Final wire shape vs `DebridgeAdapter._decodeMessage` — field by field

| # | Hook emits (`CCTPSendHook.sol:158`) | `DebridgeAdapter._decodeMessage` (`:157-158`) | Match |
|---|---|---|---|
| 0 | `bytes initData` | `bytes initData` | ✅ |
| 1 | `bytes executorCalldata` | `bytes executorCalldata` | ✅ |
| 2 | `address _account` | `address account` | ✅ |
| 3 | `address[] dstTokens` | `address[] dstTokens` | ✅ |
| 4 | `uint256[] intentAmounts` | `uint256[] intentAmounts` | ✅ |
| 5 | `bytes signature` | `bytes sigData` | ✅ |

**Result: byte-identical. No mismatch.** Same tuple produced by `DeBridgeSendOrderAndExecuteOnDstHook._buildExternalCall`
(`src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol:388`) and consumed by
`StargateAdapterV2.handleCompose` (`src/adapters/StargateAdapterV2.sol:250`). A `CCTPAdapter` copying
`DebridgeAdapter._decodeMessage` verbatim is correct.

### 1.4 Deliberate divergence you must decide on: 6-tuple (V1) vs 2-tuple (V2)

The rest of the codebase has already migrated **away** from this shape:

| Adapter | Wire format | Decode site |
|---|---|---|
| `DebridgeAdapter` | 6-tuple | `src/adapters/DebridgeAdapter.sol:157-158` |
| `StargateAdapter` (V1) | 6-tuple | `src/adapters/StargateAdapter.sol:250` |
| `StargateAdapterV2` | **2-tuple** `(initData, sigData)` | `src/adapters/StargateAdapterV2.sol:272` |
| `AcrossV3AdapterV2` | **2-tuple** | `src/adapters/AcrossV3AdapterV2.sol:155` |
| `RelayAdapter` | **2-tuple** | `src/adapters/RelayAdapter.sol:163` |

The V2 adapters recover `account`, `executor`, `validator`, `executorCalldata`, `dstTokens`, `intentAmounts`
by walking `sigData.proofDst[]` for the entry matching `block.chainid`
(`AcrossV3AdapterV2._extractFromSigData`, `:228-248`). Rationale in
`specs/stargate-compose-data-minimization/spec.md:12`: the 6-tuple duplicates `executorCalldata` (1–5 KB)
that already lives inside `sigData.proofDst[i].info`, and the duplication was blowing past LayerZero's 10k
message limit on real intents.

**CCTP has a 8192-byte body limit — tighter than LayerZero's 10k.** See §7.

Note also that the V2 adapters gained two safety checks the 6-tuple adapters structurally cannot have:
`extracted.executor != SUPER_DESTINATION_EXECUTOR → EXECUTOR_NOT_VALID` and
`extracted.validator != SUPER_DESTINATION_VALIDATOR → VALIDATOR_NOT_VALID`
(`AcrossV3AdapterV2.sol:176-187`). A 6-tuple CCTPAdapter can still perform these — it just has to
additionally decode `sigData` to reach `proofDst[i].info.executor/.validator`, i.e. do the V2 work anyway.

---

## 2. Do the deployed hooks need changing?

### Verdict: **NO. Adapter-only is achievable.** The decision holds.

Evidence:

- `mintRecipient` is read as a raw `bytes32` at offset 108 (`CCTPSendHook.sol:116`) and forwarded unaltered
  into `depositForBurnWithHook` (`:174`). The only constraint is `!= bytes32(0)` (`:123`).
  `bytes32(uint256(uint160(adapter)))` passes.
- `destinationCaller` is read as a raw `bytes32` at offset 140 (`:117`) and forwarded unaltered (`:175`).
  **There is no validation on it at all.** Any value, including the adapter address, is accepted.
- Nothing in either hook inspects, cross-checks, or constrains the relationship between `mintRecipient`,
  `destinationCaller`, and the `account`/`dstTokens` inside `hookCallData`. The hook is a pure pass-through
  for all three.
- `inspect()` (`:225-230`) returns `abi.encodePacked(burnToken, address(uint160(uint256(mintRecipient))))`.
  Setting `mintRecipient` to the adapter simply makes `inspect()` report the adapter — which is what the
  off-chain risk screen wants to see. `inspect` has no on-chain consumer (grep: only declared at
  `src/interfaces/ISuperHook.sol:49`, never called from `src/executors/`, `src/validators/`, `src/accounting/`).

### Caveat to state plainly in the spec

Adapter-only means **the `mintRecipient == adapter` invariant is enforced off-chain only.** A
malformed/malicious intent that sets `mintRecipient` to something else still burns USDC and mints it
wherever the field says, with `hookData` attached that nothing will ever execute. The hook's on-chain
guarantee is limited to "not `bytes32(0)`".

This is not unique to CCTP — Across (`recipient`), Stargate (`to`), and deBridge (`receiverDst`) are all
in the same position for their generic hooks. The precedent for on-chain enforcement exists but only in the
SuperVault cap-aware subclasses: `SuperVaultCapBridgeCommon._enforceCrossChainCap` calls
`guard.isApprovedAdapter(chainId, transportAdapter)` and reverts `TRANSPORT_ADAPTER_NOT_APPROVED`
(`src/hooks/bridges/SuperVaultCapBridgeCommon.sol:220-221`), with the guard resolved from SuperGovernor
at execution (`:184-187`). See §4.

### The ONE thing that could force a hook change

Not `mintRecipient`. It is the **8192-byte message-body ceiling** (§7). If real intents exceed
`8192 - 228 = 7964` bytes of `hookData`, the source `depositForBurnWithHook` reverts and no CCTP intent of
that complexity can ever be built with the deployed hook. The fix is a compact 2-tuple `CCTPSendHookV2`
(mirroring `StargateSendHookV2.sol:159-171` / `AcrossSendFundsAndExecuteOnDstHookV2.sol:145-157`), which
**is** a new hook + new bytecode lock + new deployment index. Measure before deciding — see §7 for the
measurement procedure.

---

## 3. SDK / off-chain integration checklist

### 3.1 Fields that MUST equal the destination adapter address

| Hook field | Offset | Required value | Why |
|---|---|---|---|
| `mintRecipient` | 108 | `bytes32(uint256(uint160(cctpAdapter[dstChainId])))` | The adapter needs custody to forward. CCTP mints to this address and stops. |
| `destinationCaller` | 140 | `bytes32(uint256(uint160(cctpAdapter[dstChainId])))` | `MessageTransmitterV2.receiveMessage` enforces `msg.sender == destinationCaller`. Setting it to the adapter guarantees the mint can only happen inside `CCTPAdapter.relay()`, i.e. atomically with hook execution. |

Both are left-padded `bytes32`, i.e. the 20-byte address in the low-order bytes.

**Do NOT set `destinationCaller = bytes32(0)`.** That is the pre-decision behaviour and it is the strand
vector: anyone may then call `receiveMessage` directly, USDC mints to the adapter, and nothing runs the
hook. The funds sit in the adapter with no `failedTransfers` credit (nothing recorded them) and no
`relay()` path left (nonce consumed). Only an adapter-level sweep/rescue could recover them — and the
interview explicitly rejected adding admin rescue.

### 3.2 Resolving the adapter address per destination chain

**Strong recommendation: deploy `CCTPAdapter` with constructor `(address messageTransmitterV2, address superDestinationExecutor)` and nothing else.**

Verified: both args are already chain-invariant in prod.

- `MessageTransmitterV2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64` — code present and
  `maxMessageBodySize() == 8192` on Ethereum (`localDomain 0`), Optimism (`2`), Base (`6`), Linea (`11`).
  (Flare has no CCTP deployment at all — confirms the chain-scope gating.) The address matches the
  constant already used by `lib/pigeon/src/cctp/CctpV2Helper.sol:15`.
- `SuperDestinationExecutor = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF` — identical across **all 18**
  prod chains (`script/output/prod/*/`).

⇒ Same salt + same initcode + same constructor args ⇒ **one CREATE2 address for `CCTPAdapter` on every chain.**
The SDK gets a single constant, no per-chain lookup, no risk of using chain A's adapter in chain B's intent.

This matches the `RelayAdapter` precedent exactly: single constructor arg (`superDestinationExecutor_`,
`src/adapters/RelayAdapter.sol:128-133`) ⇒ one address, `0xcf91365ee9D079CCF0E09eF228aFeC45AFf676F2`, across
all 17 chains it is deployed on. `DebridgeAdapter` likewise ⇒ `0x5bE003c2cD2DaCD4Cd23488DB7E74568475a36d8`
on 14 chains.

The counter-examples are the ones to avoid: `AcrossV3AdapterV2` has **10 distinct addresses** and
`StargateAdapterV2` **14 distinct addresses**, because their constructors take per-chain protocol addresses
(SpokePool / allowed-OFT list). If the `CCTPAdapter` constructor ever takes the local USDC address or a
domain id, this property is lost and the SDK is back to per-chain resolution. **Resist that.**

Fallback if the property cannot be preserved: resolve from `script/output/<env>/<chainId>/<Chain>-latest.json`
under a `CCTPAdapter` key, same mechanism already used for `DebridgeAdapter` / `RelayAdapter`.

### 3.3 `intentAmounts` relative to `maxFee`

CCTP V2 deducts the fee **from the transferred amount**, not from `msg.value`. The destination account
receives `amount - feeExecuted` where `feeExecuted <= maxFee`
(`BurnMessageV2` carries both `maxFee` and `feeExecuted`).

The destination check is a floor, not an equality
(`src/executors/SuperDestinationExecutor.sol:206-211`):

```
uint256 _balance = IERC20(_token).balanceOf(account);
if (_intentAmount != 0 && _balance < _intentAmount) { emit …NotEnoughBalance; return false; }
```

Therefore:

```
intentAmounts[0]  <=  amount - maxFee      (worst-case delivery)
```

Set it to exactly `amount - maxFee` for the tightest safe bound, or lower if you also want headroom for
the `usePrevHookAmount` scaling risk in §5.

Three corollaries:

- **`intentAmounts[0] > amount - maxFee` ⇒ guaranteed failure whenever Circle charges the full `maxFee`.**
  `_validateBalances` returns `false`, `processBridgedExecution` **returns early without reverting**
  (`SuperDestinationExecutor.sol:125`), the merkle root is NOT marked used (`:127-132`), and the USDC sits
  on the account un-deployed. Note the adapter's `try/catch` never fires — there is no revert.
  **An adapter author must not treat "no catch" as "executed".** Only the
  `SuperDestinationExecutorReceivedButNotEnoughBalance` event distinguishes the two.
- **This failure is recoverable.** `processBridgedExecution` is `external` with **no access control**
  (`SuperDestinationExecutor.sol:94-105`). Anyone can re-call it with the same six arguments once the
  account balance reaches `intentAmounts[0]` (user tops up the shortfall). Document this as the operational
  runbook — it is the entire reason a too-high `intentAmounts` is a recoverable mistake rather than a loss.
- **`intentAmounts[0] == 0` is an instant abort**, not a "skip the check":
  `if (_intentAmount == 0) { emit …InvalidIntentAmount; return false; }` (`:193-196`).
  Never encode zero.

Also: Circle's `TokenMessengerV2` requires `maxFee < amount`. With `minFinalityThreshold >= 2000` (standard)
the fee is typically 0 and delivery is the full `amount`; with `< 2000` (fast) the fee is real. If `maxFee`
is set below Circle's quoted fast-transfer fee the burn still succeeds on-chain but the attestation service
falls back to finality-based (slow) attestation — a latency surprise, not a revert.

### 3.4 Full SDK checklist for a CCTP intent

| # | Requirement | Breakage if wrong |
|---|---|---|
| 1 | `mintRecipient` (off 108) = `bytes32(uint160(CCTPAdapter))` | USDC mints elsewhere; `hookData` never executed; loss. |
| 2 | `destinationCaller` (off 140) = same adapter address, **not** `bytes32(0)` | Third party receives the message, USDC stranded in adapter with no `relay()` path and no `failedTransfers` credit. |
| 3 | `burnToken` (off 52) = **source-chain** USDC | Hook reverts `ADDRESS_NOT_VALID` only for `address(0)`; a wrong non-zero token reverts inside TokenMessengerV2. |
| 4 | `destinationDomain` (off 104) = CCTP **domain id**, not EVM chain id | Message routed to the wrong chain. No recovery. Cross-check against `localDomain()` on the target `MessageTransmitterV2`. |
| 5 | `hookCallData` = `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts)` — **5 fields, no sigData**, placed last with no length prefix | Hook's `abi.decode` (`:150-156`) reverts → whole UserOp reverts. Fails loudly, at least. |
| 6 | `intentAmounts[0] <= amount - maxFee`, and `> 0` | Destination silently no-ops; funds idle on account; root unconsumed; manual re-trigger needed. |
| 7 | `dstTokens[0]` = **destination-chain** USDC | Balance check reads the wrong token; silent no-op as above. |
| 8 | `dstTokens.length == intentAmounts.length` | `ARRAY_LENGTH_MISMATCH` revert inside `processBridgedExecution` (`:107`) → adapter `catch` fires, funds already forwarded. |
| 9 | `chainsWithDestinationExecution` in the signature includes the CCTP destination chain, with a 1:1 `proofDst` entry | `retrieveSignatureData` returns `""` (`SuperValidator.sol:61,94-95`); hook encodes empty sigData; destination signature validation fails forever. **Funds forwarded, never executed.** |
| 10 | `proofDst[i].info.executor` = `SuperDestinationExecutor` on the destination; `.validator` = `SuperDestinationValidator` there | `destinationData` reconstruction (`SuperDestinationExecutor.sol:115-116`) won't match the signed leaf → `INVALID_SIGNATURE` revert inside the adapter's `try` → funds forwarded, never executed. |
| 11 | `proofDst[i].info.account` == the outer `account` in `hookCallData` | Mismatch: the outer `account` drives the transfer and the signature check; the signature will fail. |
| 12 | `hookData` total length `<= 7964` bytes | `depositForBurnWithHook` **reverts on the source chain** (`maxMessageBodySize` 8192 minus 228-byte BurnMessageV2). Fails safe, but the intent is unbuildable. See §7. |
| 13 | `amount` (off 72) is a realistic non-zero estimate **even when `usePrevHookAmount == true`** | `maxFee` scaling is skipped when `amount == 0` (`:134`); a stale absolute `maxFee >= actual amount` reverts `TokenMessengerV2`'s `maxFee < amount`. See §5. |
| 14 | `hookCallData.length >= 160` (it always will be — real encodings are ≥ 288) | `DATA_NOT_VALID` (`:146`). |
| 15 | Approval: use `ApproveAndCCTPSendHook` **or** chain an approve hook before `CCTPSendHook` | `CCTPSendHook` does no approval (`:25-26`); the burn reverts on allowance. |

---

## 4. How the other bridge pairs plumb the destination adapter

| Pair | Field naming the dst adapter | Where it lives | Supplied by | On-chain enforcement (generic hook) |
|---|---|---|---|---|
| **Across V1/V2** | `recipient` | packed offset **84** (`AcrossSendFundsAndExecuteOnDstHookV2.sol:34,110`) | SDK/user | none — only `recipient != address(0)` (`:141-143`) |
| **Stargate V1/V2** | `to` (bytes32) | packed offset **128** (`StargateSendHookV2.sol:41,121`) | SDK/user | none — only `to != bytes32(0)` (`:128`) |
| **deBridge** | `receiverDst` (bytes) + `externalCall.executorAddress` | dynamic slice; envelope built at `DeBridgeSendOrderAndExecuteOnDstHook.sol:374-392` | SDK/user | none in the generic hook |
| **Relay** | *n/a* | — | — | Relay has **no destination receiver callback**; the origin deposit carries only `depositId` (`RelaySendFundsAndExecuteOnDstHook.sol:22-26`). The adapter call is composed off-chain in the Relay quote's `txs[]` and executed by the solver. |
| **CCTP** | `mintRecipient` + `destinationCaller` | packed offsets **108** and **140** | SDK/user | none beyond `mintRecipient != bytes32(0)` |

### Conclusion: CCTP is **not** the odd one out

User-supplied, off-chain-trusted, zero on-chain binding is **the convention** for every generic bridge hook
in the repo except Relay (which is structurally different). CCTP asking the SDK to set `mintRecipient` and
`destinationCaller` to the adapter is exactly what Across asks for `recipient`, Stargate for `to`, and
deBridge for `receiverDst`. **The interview decision is consistent with the codebase, not an exception.**

CCTP is mildly *stricter* than the others, in a good way: with `destinationCaller` pinned to the adapter, a
third party physically cannot deliver the mint outside `relay()`. Across and Stargate have no equivalent —
their adapters are pure push receivers and must defend themselves (hence `AcrossV3AdapterV2`'s
`EXECUTOR_NOT_VALID` / `VALIDATOR_NOT_VALID` checks and `RelayAdapter`'s balance-minus-escrow guard at
`RelayAdapter.sol:181-186`).

### The one existing on-chain convention, and whether to adopt it

`ICrossChainPositionCapGuard.isApprovedAdapter(chainId, adapter)`, resolved from SuperGovernor at execution
time (`SuperVaultCapBridgeCommon.sol:184-187, 220-221`), used by the SuperVault cap-aware subclasses
(`SuperVaultAcrossCapBridgeHook`, `SuperVaultDeBridgeCapBridgeHook`, `SuperVaultStargateCapBridgeHook`).
`SuperVaultDeBridgeCapBridgeHook.sol:28-35` spells out the model precisely: *"the order `receiverDst` is the
bridge TRANSPORT receiver — in the real destination flow it is the DebridgeAdapter… This hook therefore
requires `receiverDst` to be a governance-approved destination adapter for the canonical destination chain,
and requires the external-call `executorAddress` to be that SAME adapter."*

**If** you ever want the consistent, on-chain-enforced option for CCTP, that is its shape: a
`SuperVaultCCTPCapBridgeHook` subclass asserting
`isApprovedAdapter(destinationChainId, address(uint160(uint256(mintRecipient))))` and
`mintRecipient == destinationCaller`. That is a SuperVault-scope follow-up, **not** a blocker for the
generic adapter, and it does not touch the deployed generic hooks.

Note the mapping wrinkle: the guard is keyed by **EVM chainId**, while the CCTP hook only carries a
**CCTP domain id** (offset 104). A cap-aware CCTP hook would need a domain→chainId table. Worth recording
as future work, not solving now.

---

## 5. Chained-hook interactions (`usePrevHookAmount`)

### 5.1 What actually happens at execution

`CCTPSendHook.sol:130-139`:

```
if (_decodeBool(data, 208)) {
    uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);
    if (s.amount > 0 && s.maxFee > 0) {
        s.maxFee = Math.mulDiv(s.maxFee, outAmount, s.amount);   // proportional, floored
    }
    s.amount = outAmount;
}
if (s.amount == 0) revert AMOUNT_NOT_VALID();
```

Let `A` = signed `amount`, `F` = signed `maxFee`, `I` = signed `intentAmounts[0]`, `A'` = realised swap output.

- `F' = floor(F · A' / A)`
- delivered on destination: `D = A' − feeExecuted`, with `feeExecuted <= F'`
- so `D >= A' − F' >= A'·(A − F)/A`
- the destination check is `balanceOf(account) >= I` with **`I` fixed at signing time**
  (`SuperDestinationExecutor.sol:206-211`); it is never rescaled by anything.

### 5.2 Does the signed `intentAmounts` still reconcile?

**Only if `A' >= A`.** Walk through:

| Case | `D` vs `I` | Outcome |
|---|---|---|
| `A' == A` (bundler prediction exact) | `D ≈ I` | Passes, assuming `I <= A − maxFee`. |
| `A' > A` (swap outperformed) | `D > I` | **Passes.** The surplus lands on the account as dust; destination hooks consume their signed amounts. Note the user also pays a proportionally *larger* absolute `maxFee`. |
| `A' < A` (swap underperformed — the common case) | `D < I` whenever the shortfall exceeds the `I` headroom | **Fails.** `_validateBalances` → `false` → early `return` at `SuperDestinationExecutor.sol:125`. No revert. Root NOT consumed (`:127-132`). USDC idle on the destination account. |

`intentAmounts` scales with **nothing**. The `maxFee` scaling at `:135` preserves the *fee ratio*; it does
nothing for the *intent floor*. So a 1% adverse swap move on a `I = A − maxFee` intent is enough to
silently strand the delivery.

**This is not CCTP-specific.** `AcrossSendFundsAndExecuteOnDstHookV2.sol:126-128` scales `outputAmount`
by the same `Math.mulDiv`, and `AcrossV3AdapterV2` pulls `intentAmounts` from the signed
`proofDst[i].info` (`:236`) — equally unscalable. Ditto `StargateSendHookV2.sol:151-154` for `minAmountLD`.
CCTP inherits an existing systemic limitation rather than introducing one. Say so explicitly in the spec so
the adapter author does not go hunting for a CCTP-specific bug.

**Mitigation (SDK, not contract):** when `usePrevHookAmount == true`, set
`I = floor((A − maxFee) · (1 − slippageFloorBps/10_000))` using the same slippage floor the preceding swap
hook enforces. That makes the intent check provably satisfiable for any swap outcome the swap hook itself
would accept.

### 5.3 Edge cases that make the scaling misbehave

**(a) `amount == 0` with `usePrevHookAmount == true` — the big one.**
The guard is `if (s.amount > 0 && s.maxFee > 0)` (`:134`). With `A == 0` the scaling is **skipped entirely**
and `maxFee` stays at its absolute signed value while `amount` becomes `A'`. If `F >= A'`,
`TokenMessengerV2` reverts on `maxFee < amount` and the whole UserOp fails. If `F < A'` but
disproportionate, the user overpays. "Encode `amount = 0` because the amount is unknown at sign time" is a
natural SDK pattern and it is **wrong here**. Always encode a realistic non-zero estimate.

**(b) `F'` floors to 0 on a large downscale.**
`Math.mulDiv(F, A', A)` with `A' << A` yields `maxFee = 0`. The burn still succeeds (`0 < A'`), but with
`minFinalityThreshold < 2000` Circle's fast-transfer fee exceeds 0, so the message is attested only at
finality — a slow transfer instead of a fast one. Latency surprise, not a loss. Upside: delivery is the full
`A'`, so the intent check is *more* likely to pass.

**(c) OMS resizing (`replaceCalldataAmounts`) leaves `maxFee` and `intentAmounts` stale.**
`decodeAmounts` exposes exactly one slot — `AMOUNT_POSITION = 72` (`CCTPSendHook.sol:194-197, 51`) — and
`replaceCalldataAmounts` rewrites only that slot (`:211-222`). `maxFee` (offset 172) is not a declared slot,
and `intentAmounts` is buried inside `hookCallData`. Per the interface contract at
`src/interfaces/ISuperHook.sol:128-131` (*"A slot belongs in decodeAmounts/amountRoles iff the OMS can
rewrite it at execution time without invalidating any commitment embedded in the same data"*), `maxFee` is
correctly excluded — but the practical consequence is that **any OMS resize of a CCTP leg must be followed
by an SDK-side re-derivation of `maxFee` and `intentAmounts` before signing.** This is an off-chain
invariant with no on-chain backstop.

**(d) CCTP send is terminal in a chain.**
Neither hook overrides `_postExecute`, and `_pipeMode()` defaults to `TRANSFORM`
(`BaseHook.sol:308, 347-349`), so no `outAmount` is ever set. Any hook chained *after* a CCTP send with
`usePrevHookAmount == true` reads `0` and reverts `AMOUNT_NOT_VALID`. Consistent with the other bridge
hooks; just don't design a post-bridge leg on the source chain.

---

## 6. Risks and open questions for the adapter author

### R1 — Silent non-execution is the dominant failure mode, and `try/catch` does not see it
`processBridgedExecution` **returns normally** (no revert) on three distinct failures:
insufficient balance (`SuperDestinationExecutor.sol:125`), already-used merkle root (`:127-130`), and
empty/foreign executor calldata (`:134-137`). The interview's `try/catch` + `claimFailedTransfer` design
only covers the revert path. Recommendation: the adapter should emit a `Relayed(account, token, amount)`
event unconditionally and rely on off-chain correlation with
`SuperDestinationExecutorExecuted` / `…ReceivedButNotEnoughBalance` / `…ReceivedButRootUsedAlready`.
Do not add an on-chain success assertion — it would revert the whole relay and re-strand the funds.

### R2 — 8192-byte body limit (see §7). Highest-impact open item.

### R3 — `sigData` provenance is unverified by the 6-tuple shape
The outer `account`, `dstTokens`, `intentAmounts` are re-hashed into `destinationData` and checked against
the signature (`SuperDestinationExecutor.sol:115-123`), so a forged outer tuple fails closed. **But**
`initData` is not covered by that check — it feeds `_validateOrCreateAccount` (`:164-171`), which only
verifies `computedAddress == account`. That is adequate, but the adapter should still mirror
`AcrossV3AdapterV2`'s executor/validator assertions (`:176-187`) by decoding `sigData.proofDst[]`, because
without them an intent signed for a *different* chain's executor produces a forwarded-but-never-executed
delivery — exactly the failure mode `EXECUTOR_NOT_VALID` was added to prevent.

### R4 — Donation sweeping is riskier here than in the push adapters
The interview accepts "forward full adapter balance". `RelayAdapter` protects itself with
`balance - totalEscrowed[token] < amount → INSUFFICIENT_FUNDS_RECEIVED` (`RelayAdapter.sol:181-186`)
because its entrypoint is permissionless. `CCTPAdapter.relay()` is also permissionless. Since the adapter
mints USDC itself inside `receiveMessage`, it can compute the exact delta
(`balanceAfter − balanceBefore`) rather than sweeping the whole balance. **Strongly prefer the delta.**
Sweeping the balance means: any USDC escrowed for a previous failed transfer, or donated, is handed to the
next relayer's account. If a `failedTransfers` escrow ledger exists (per the interview's
`claimFailedTransfer` decision), sweeping the full balance **actively steals from it** — the
`totalEscrowed` accounting in `RelayAdapter.sol:49` exists for exactly this reason.

### R5 — Griefing: forced `catch` via gas starvation (interview open question 5)
A permissionless `relay()` with a caller-chosen gas limit can 63/64-starve the inner
`processBridgedExecution` call so it OOGs, the `catch` fires, and the merkle root is left unconsumed while
the USDC has already been forwarded to the account. Outcome: funds delivered, intent unexecuted, and
recoverable only by someone re-calling `processBridgedExecution` (which is permissionless, so recovery is
open to anyone). Consider `AcrossV3AdapterV2`'s treatment: it distinguishes empty revert data (OOG) from a
real selector and **reverts** on empty (`AcrossV3AdapterV2.sol:219-233, 96-99`). For CCTP that is not
available — reverting also unwinds `receiveMessage`, and the nonce is only consumed on success, so it would
actually be safe to revert and retry. **Worth re-examining the "never revert" decision specifically for the
OOG case**, since unlike Stargate's ordered compose queue there is nothing to block.

### R6 — `hookData` parsing must come from the attested bytes
Parse `hookData` out of the same `message` passed to `receiveMessage`, never from a caller-supplied
side-channel. Offsets (MessageV2 header + BurnMessageV2 body), corroborated for the header half by
`lib/pigeon/src/cctp/CctpV2Helper.sol:168-186` (destinationCaller @108, minFinality @140,
finalityExecuted @144):

```
MessageV2:      version@0(4) sourceDomain@4(4) destinationDomain@8(4) nonce@12(32)
                sender@44(32) recipient@76(32) destinationCaller@108(32)
                minFinalityThreshold@140(4) finalityThresholdExecuted@144(4) body@148
BurnMessageV2:  version@0(4) burnToken@4(32) mintRecipient@36(32) amount@68(32)
                messageSender@100(32) maxFee@132(32) feeExecuted@164(32)
                expirationBlock@196(32) hookData@228
```
⇒ **absolute `hookData` offset = 376.** Verify against Circle's `evm-cctp-contracts`
`BurnMessageV2.sol` before freezing (interview open question 2).

Also note `recipient@76` is the **remote TokenMessengerV2**, not `mintRecipient`. TokenMessengerV2 mints to
`mintRecipient@36` of the body and **ignores `hookData` entirely** — which is the whole reason the wrapper
pattern is required. Confirms interview open question 1.

### R7 — Chain scope is narrower than the hook's deployment
`CCTPSendHook` is deployed at `0xd0292192F9f172D7bf9570A6A17689F91A65A55e` (and
`ApproveAndCCTPSendHook` at `0xAeE5195ec226cFC57FfF1841E270de2172470FfF`) on **all** prod chains, including
ones with no CCTP at all — Flare has no `MessageTransmitterV2` code (verified). The adapter must deploy
conditionally on `MessageTransmitterV2.code.length > 0`, following the `_getContractAvailability` pattern in
`script/DeployV2Core.s.sol`. Do not assume hook presence implies CCTP presence.

### R8 — `ITokenMessengerV2` return type is cosmetically wrong
`src/vendor/bridges/cctp/ITokenMessengerV2.sol:27` declares `returns (bytes memory)`; Circle's
`depositForBurnWithHook` returns nothing. Harmless (the selector derives from argument types only, and
`Execution` never decodes returndata), but it means the adapter author cannot rely on a returned message
blob. Do not "fix" it — that would change the locked hook bytecode.

### R9 — No destination test exists anywhere
`test/integration/cctp/CCTPHooksFork.t.sol` is burn-side only, and its
`MockCCTPForkSignatureStorage.retrieveSignatureData` (`:20-28`) returns a `proofDst` array of length **0**.
That fixture would fail every V2-style extraction and every destination signature check. The adapter test
suite needs a real `SignatureData` fixture with a populated `DstProof` for the destination chain — see
`test/BaseTest.t.sol:552` and `test/unit/simulationHelpers/CrossChainSuperVaultDestinationDeBridgeE2E.t.sol`
for working examples of the full cross-chain fixture.

`lib/pigeon/src/cctp/CctpV2Helper.sol` already provides the fork-side relay machinery (attester override
`:107-120`, finality patch `:133-146`, nonce clear `:148-153`, and — critically — it already
`vm.prank`s `destinationCaller` at `:95-97`). **It will not work unmodified for the adapter**, because the
adapter must call `receiveMessage` *itself* from inside `relay()`. The helper needs a variant that
produces `(message, attestation)` and hands them to `CCTPAdapter.relay()` instead of calling
`receiveMessage` directly.

---

## 7. The 8192-byte ceiling — measure before freezing the design

**Measured live (not from docs):** `MessageTransmitterV2.maxMessageBodySize() == 8192` on Ethereum,
Optimism, Base, and Linea. `messageBody = BurnMessageV2 (228 fixed) + hookData`, so

> **`hookData` must be ≤ 7964 bytes, or `depositForBurnWithHook` reverts on the source chain.**

The 6-tuple format is the fat one. `specs/stargate-compose-data-minimization/spec.md:12` measured
`executorCalldata` at **1–5 KB** and the duplication overhead (`executorCalldata` + `account` + `dstTokens` +
`intentAmounts` appearing both at the top level and again inside `sigData.proofDst[i].info`) at
**1.5–5.5 KB**. That migration was triggered by LayerZero's **10 KB** limit. **CCTP's limit is 20% tighter.**

Arithmetic sketch for a 2-hook destination (approve + 4626 deposit):
`initData` ~64 B (empty) or 200–400 B (with factory initcode) · `executorCalldata` ~400–600 B ·
`account`/`dstTokens`/`intentAmounts` ~160 B · `sigData` ~1–1.5 KB (contains a second copy of
`executorCalldata` plus merkle proofs) ⇒ **~2–2.5 KB. Comfortable.**
A 4–5-hook destination with a 7702 initcode and a deep merkle proof plausibly reaches **6–9 KB**, i.e.
**at or over the ceiling.**

### Action for the adapter author / spec

1. **Measure, don't guess.** Build the 2–3 most complex CCTP intents the product actually intends to ship,
   encode the real `hookCallData`, append a realistic `SignatureData`, and assert
   `length <= 7964`. This is a 30-minute Foundry test and it decides whether the "adapter-only" scope holds.
2. If everything fits with margin: **ship adapter-only against the 6-tuple.** Add a
   documented product guardrail ("CCTP destination intents are capped at N hooks") and an SDK pre-flight
   length assertion so the failure is caught before the user signs.
3. If it does not fit: a **`CCTPSendHookV2` emitting the compact 2-tuple `abi.encode(initData, sigData)`** is
   unavoidable. It is a small, well-precedented change — copy
   `StargateSendHookV2.sol:159-171` or `AcrossSendFundsAndExecuteOnDstHookV2.sol:145-157` verbatim — but it
   means a new contract, a new bytecode lock, a new `DeployV2Core.s.sol` index, and an SDK migration.
   **Flag this to the product owner now rather than after the adapter is audited.**
4. Whichever way it goes, **write the CCTPAdapter's decode so the 2-tuple migration is cheap.** Either
   (a) decode the 6-tuple but still walk `sigData.proofDst[]` for the executor/validator assertions (so the
   `_extractFromSigData` helper already exists), or (b) branch on the decoded tuple arity. Option (a) is
   cleaner and matches `AcrossV3AdapterV2._extractFromSigData` (`:228-248`).

---

## 8. Corrections to fold into `specs/cctp-destination-adapter/spec.md`

1. The hook data layout in `specs/cctp-bridge-hooks/spec.md:47-58` and `technical-spec.md:131-141` is
   **obsolete** (missing the 52-byte strategy header; contains a `hookCallDataLength` field that does not
   exist). Cite `src/hooks/bridges/cctp/CCTPSendHook.sol:32-43` instead.
2. Interview open question 1 (is `CCTPHookWrapper` canonical?) → **effectively answered yes**:
   `TokenMessengerV2` is the message `recipient` and ignores `hookData` entirely, so a wrapper that calls
   `receiveMessage` and then parses the same attested bytes is the only atomic option.
3. Interview open question 2 (hookData offsets) → **hookData @ absolute 376** (148 + 228); header offsets
   corroborated by `lib/pigeon/src/cctp/CctpV2Helper.sol:168-186`. Confirm the body half against Circle's
   `BurnMessageV2.sol`.
4. Interview open question 3 (deterministic `MessageTransmitterV2`?) → **yes**,
   `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`, verified on Ethereum/Optimism/Base/Linea; absent on Flare.
   Already hardcoded at `lib/pigeon/src/cctp/CctpV2Helper.sol:15`.
5. Interview open question 4 (does `receiveMessage` return enough to avoid re-parsing?) → **no**, it returns
   `bool`. Re-parse the message; compute the minted amount as a balance delta (R4).
6. **New, not in the interview notes:** the `maxMessageBodySize == 8192` constraint (§7). Add it as a
   first-class risk row.
7. **New:** the `amount == 0 && usePrevHookAmount` maxFee-scaling hole (§5.3a). Add to the SDK checklist.
8. **New:** `processBridgedExecution` is permissionless (`SuperDestinationExecutor.sol:94`) — this is the
   documented recovery path for every silent-no-op failure. Put it in the runbook.
9. **New:** constrain the `CCTPAdapter` constructor to
   `(messageTransmitterV2, superDestinationExecutor)` to preserve a single cross-chain CREATE2 address
   (§3.2). Record it as a design constraint, not an implementation detail.

---

## 9. Key file:line index

| Topic | Location |
|---|---|
| CCTP hook data layout (canonical) | `src/hooks/bridges/cctp/CCTPSendHook.sol:32-43` |
| CCTP hook decode + validation | `src/hooks/bridges/cctp/CCTPSendHook.sol:110-141` |
| `mintRecipient` / `destinationCaller` reads | `src/hooks/bridges/cctp/CCTPSendHook.sol:116-117` |
| Signature append (6-tuple re-encode) | `src/hooks/bridges/cctp/CCTPSendHook.sol:143-159` |
| `maxFee` proportional scaling | `src/hooks/bridges/cctp/CCTPSendHook.sol:130-139` |
| Approve-variant (identical decode) | `src/hooks/bridges/cctp/ApproveAndCCTPSendHook.sol:110-203` |
| deBridge 6-tuple decode (target shape) | `src/adapters/DebridgeAdapter.sol:145-159` |
| deBridge envelope build (same 6-tuple) | `src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol:374-392` |
| Stargate V1 6-tuple decode | `src/adapters/StargateAdapter.sol:250` |
| Across V2 compact 2-tuple + sigData extraction | `src/adapters/AcrossV3AdapterV2.sol:155, 228-248` |
| Across V2 executor/validator assertions | `src/adapters/AcrossV3AdapterV2.sol:176-187` |
| Relay permissionless entry + escrow guard | `src/adapters/RelayAdapter.sol:149-211` |
| `claimFailedTransfer` precedent | `src/adapters/RelayAdapter.sol:222-238` |
| Destination intent check (`>=`, early return) | `src/executors/SuperDestinationExecutor.sol:180-214` |
| Destination signature reconstruction | `src/executors/SuperDestinationExecutor.sol:115-123` |
| `processBridgedExecution` is permissionless | `src/executors/SuperDestinationExecutor.sol:94-105` |
| Merkle-root replay guard | `src/executors/SuperDestinationExecutor.sol:127-132` |
| Transient signature store (source) | `src/validators/SuperValidator.sol:29-32, 61, 94-95` |
| `SignatureData` / `DstProof` / `DstInfo` | `src/interfaces/ISuperValidator.sol:9-60` |
| OMS resizable-slot contract | `src/interfaces/ISuperHook.sol:128-131` |
| SuperVault on-chain adapter allowlist | `src/hooks/bridges/SuperVaultCapBridgeCommon.sol:184-187, 220-221` |
| SuperVault transport-vs-economic rationale | `src/hooks/bridges/debridge/SuperVaultDeBridgeCapBridgeHook.sol:28-42` |
| CCTP V2 message offsets (header) | `lib/pigeon/src/cctp/CctpV2Helper.sol:133-186` |
| CCTP fork test (burn-side only, empty proofDst) | `test/integration/cctp/CCTPHooksFork.t.sol:20-28` |
| Stargate size-minimization rationale | `specs/stargate-compose-data-minimization/spec.md:12` |
| CCTP hook deploy wiring | `script/DeployV2Core.s.sol:2359-2374, 4599-4602` |
