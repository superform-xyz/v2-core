# Repository Pattern Analysis — `src/adapters/CCTPAdapter.sol`

## 1. Existing adapter anatomy

**`AcrossV3Adapter.sol` (legacy V1, deregistered)**
Immutables `ACROSS_SPOKE_POOL`, `SUPER_DESTINATION_EXECUTOR` (`:24-25`), zero-checked in ctor (`:33-39`)
against `ADDRESS_NOT_VALID()` (`:31`). Entrypoint `handleV3AcrossMessage` (`:46-54`), gated inline by
`if (msg.sender != ACROSS_SPOKE_POOL) revert INVALID_SENDER();` (`:56-58`). Decodes the **6-tuple**
(`:63-70`). Unconditional `safeTransfer` (`:76`), single unguarded executor call (`:79-87`) — no
try/catch, no events, no claim path, no `ReentrancyGuard`. **Absent from `DeployV2Core.s.sol`'s
`adapterContracts` array (`:354-355`)** — frozen/legacy, kept only for its locked artifact.

**`AcrossV3AdapterV2.sol` (current preferred Across pattern)**
Adds `SUPER_DESTINATION_VALIDATOR`, cached via a **local minimal interface**
`IDestinationValidatorSource` (`:18-20, 45, 127-135`) — deliberately not folded into the shared
`ISuperDestinationExecutor`, because that interface is compiled into already-deployed locked bytecode
(NatSpec `:15-17`). Decodes the **compact 2-tuple** (`:157`) then `_extractFromSigData` (`:236-256`).

Validation order: proof found (`NO_DST_PROOF_FOR_CHAIN`, `:165-167`) → account non-zero
(`:171-173`) → `executor == SUPER_DESTINATION_EXECUTOR` (`EXECUTOR_NOT_VALID`, `:178-180`) →
`validator == SUPER_DESTINATION_VALIDATOR` (`VALIDATOR_NOT_VALID`, `:185-187`). **The only adapter
that binds executor+validator identity into its own reverts** — the stricter, newer style.

Transfer via `trySafeTransfer`, **reverts** the whole fill on failure (`:191-193`) — safe because
Across fills are independent (NatSpec `:76-79`). Executor call in try/catch with a `code.length == 0`
guard (`:200`) and a **bounded 4-byte selector copy in assembly** inside catch (`:210-222`) — never
copies full returndata.

**`DebridgeAdapter.sol`**
Immutables `SUPER_DESTINATION_EXECUTOR`, `DLN_DESTINATION` (`:23-24`); the ctor additionally reads
`IDlnDestination(dlnDestination).externalCallAdapter()` and zero-checks it (`:38-41`) — the only
adapter validating itself against a live read of the bridge's own config. Uses a **named modifier**
`onlyExternalCallAdapter` (`:45-48`) rather than an inline check.

Two entrypoints, `onEtherReceived` / `onERC20Received` (`:54-63, 87-96`), both decoding the **same
6-tuple** via private `_decodeMessage` (`:145-159`) — **the exact shape `CCTPSendHook` produces.**
Native uses `.call{value: balance}` (`:77-78`); ERC20 uses `safeTransfer(account, _transferredAmount)`
(`:111`) — the trusted callback param, **not** balance. No try/catch, no events, no claim path.

**`RelayAdapter.sol` (newest "no bridge-native callback" pattern — closest analogue to CCTP)**
Single immutable `SUPER_DESTINATION_EXECUTOR` (`:43`). Uses `ReentrancyGuard`, `nonReentrant` on
**both** external functions (`:35, 156, 222`). **Permissionless** entrypoint `processRelayExecution`
(`:149-157`), documented safe (NatSpec `:15-34`) via the executor's own signature+balance validation
plus two adapter-local guards unique to this file: `INSUFFICIENT_FUNDS_RECEIVED` — claimed `amount`
must actually be held, **excluding escrow** (`:180-186`) — and a `totalEscrowed` mapping excluded from
spendable balance so a caller cannot redirect other users' escrowed funds (`:27-28, 49-52`).

2-tuple + `_extractFromSigData`, but its `ExtractedData` struct (`:58-65`) **omits**
`executor`/`validator`. `_tryTransfer` (`:280-289`); on failure **credits `failedTransfers` /
`totalEscrowed` instead of reverting** (`:189-197`). Executor try/catch with a **fully empty catch**
(`catch { }`, `:201-211`) — stricter returnbomb-safety than AcrossV3AdapterV2's selector capture.
`claimFailedTransfer` (`:222-239`) is the canonical claim shape.

**`StargateAdapter.sol` / `StargateAdapterV2.sol` (LayerZero compose)**
`lzCompose` (`V2:203-213`) gated on `msg.sender == LZ_ENDPOINT` (`:215`) **plus** a registered-pool
check `TOKEN_MESSAGING.assetIds(_from) != 0` (V1 `:193`; V2 adds an `allowedOFTs` bypass for non-pool
OFTs like USDT0, `:57-63, 181-184, 224`) — needed because LZ V2's `sendCompose` is permissionless.

**MUST NOT revert** after the sender check (a revert blocks the ordered LZ compose queue for all
subsequent composes from that source) — hence the `this.handleCompose(...)` self-call wrapped in
try/catch purely to absorb `abi.decode` panics, with an empty catch emitting `ComposeDecodeFailed`
(`V2:239-247`). Amount comes from the OFTComposeMsgCodec header (`amountLD` bytes 12-44,
`COMPOSE_MSG_OFFSET = 76`, `:37, 230-233`) — **not adapter balance.** V1 decodes the 6-tuple
(`:243-250`); V2 the 2-tuple (`:270-275`). `failedTransfers` credited only if `preBalance >= amountLD`
snapshotted *before* any transfer attempt (`V2:310-333`). V2 treats a missing `DstProof` as a
**graceful non-revert** (`NoDstProofForChain`, `:279-288`) — the only adapter that does so, because of
the queue constraint. `lzCompose` itself is **not** `nonReentrant`; only `claimFailedTransfer` is.

## 2. Canonical adapter skeleton

1. `SPDX-License-Identifier: Apache-2.0`, `pragma solidity 0.8.30;` (exact pin).
2. Import grouping: `// External Dependencies` (OZ) → `// Vendor Interfaces`
   (`../vendor/bridges/<bridge>/`) → `// Superform Interfaces`.
3. Section banners: `STORAGE` → `STRUCTS` (only to dodge stack-too-deep) → `ERRORS` → `EVENTS` →
   `CONSTRUCTOR` → feature logic → `CLAIM LOGIC` → `INTERNAL`.
4. **Errors**: `SCREAMING_SNAKE_CASE` custom errors, never revert strings. `ADDRESS_NOT_VALID()` for
   every zero-address ctor arg, checked before assignment.
5. **NatSpec**: `@title` / `@author Superform Labs` / `@notice` at contract level; `@dev` records *why*
   (trust assumptions, revert-vs-emit rationale) — RelayAdapter spends ~20 lines justifying its
   permissionless design (`:15-34`).
6. `using SafeERC20 for IERC20;` everywhere. `safeTransfer`/`trySafeTransfer` for
   must-succeed-or-revert adapters; hand-rolled `_tryTransfer` for must-degrade-to-escrow adapters.
7. **`_tryTransfer`** — byte-identical across `RelayAdapter:280-289`, `StargateAdapter:345-354`,
   `StargateAdapterV2:424-433` (copy-pasted, no shared base): native via `.call{value:}`, ERC20 via
   low-level `token.call(abi.encodeCall(IERC20.transfer,...))` with
   `success = callSuccess && (returnData.length == 0 || abi.decode(returnData,(bool)))`.
8. **`_extractFromSigData`** — only in the 2-tuple adapters (`AcrossV3AdapterV2:236-256`,
   `RelayAdapter:250-272`, `StargateAdapterV2:394-416`): decode the 7-field `SignatureData`,
   linear-scan `DstProof[]` for `dstChainId == block.chainid`.
9. **Numbered inline comments** in the entrypoint (`// 1. Validate Sender`, `// 2. Decode…`):
   sender check → decode → extract/validate → transfer → best-effort execute. Keep this.

**Which divergence to follow for CCTP:**
- Revert posture: StargateAdapterV2 must never revert (ordered queue); Relay/Across may. CCTP messages
  are independent → **may revert**, like Relay.
- RelayAdapter's `INSUFFICIENT_FUNDS_RECEIVED` + `totalEscrowed` guard exists because its `amount` is
  **caller-supplied**. CCTP's amount is derived from the adapter's own balance delta after it calls
  `receiveMessage` itself, so that specific guard is unnecessary — **but the escrow accounting still
  is**, since `claimFailedTransfer` implies a ledger that full-balance forwarding would raid.
- Reentrancy: adapters with permissionless entrypoints (Relay) use `ReentrancyGuard`; bridge-gated
  ones (Across, deBridge) do not. CCTP's `relay()` is permissionless → **use it**.

## 3. Message format reconciliation — the pivotal section

**Path A — 6-tuple direct** (`AcrossV3Adapter` legacy, `DebridgeAdapter`):
```solidity
abi.decode(message, (bytes initData, bytes executorCalldata, address account,
                     address[] dstTokens, uint256[] intentAmounts, bytes sigData))
```
(`DebridgeAdapter:145-159`). `sigData` is the entire raw `SignatureData` blob, forwarded byte-identical
into `processBridgedExecution`'s last argument. `account`, `dstTokens`, `intentAmounts`,
`executorCalldata` are carried **redundantly** in plaintext alongside `sigData`.

`CCTPSendHook._buildHookExecutions` produces **exactly this shape** (`:150-158`): it decodes the SDK's
5-tuple, fetches the signature from transient storage, and re-encodes as the 6-tuple. Confirmed
byte-identical — same fields, order, types. `dstTokens`/`intentAmounts` come from the hook's own
encoded input, not derived from `sigData`.

**Path B — compact 2-tuple** (`AcrossV3AdapterV2`, `StargateAdapterV2`, `RelayAdapter`):
`abi.decode(message, (bytes initData, bytes sigDataRaw))`, then `_extractFromSigData` walks
`sigData.proofDst[]` for `dstChainId == block.chainid`, pulling `account`, `executor`, `validator`,
`data`(→executorCalldata), `dstTokens`, `intentAmounts` from `DstProof.info`
(`ISuperValidator.sol:17-24`). Saves 1.5–5.5 KB per message (`StargateAdapterV2:21-23`) — but it is a
**hook+adapter co-design**: the source hook must already omit those fields.

**CCTPAdapter must use Path A.** Dictated, not stylistic: the CCTP hooks are already deployed as
locked bytecode, and a V2 hook was explicitly rejected in scope. A 2-tuple adapter would decode the
wrong tuple arity against what the live hooks emit.

**The structural wrinkle no existing adapter has:** every other bridge delivers the payload as a plain
function argument via a **push** callback. CCTP's `receiveMessage(message, attestation)` is a **pull**
call the adapter must make itself; it verifies and mints, then stops. So CCTPAdapter must expose
`relay(bytes message, bytes attestation)`, call `receiveMessage` itself, then parse `hookData` from
the same `message` bytes.

**Net: CCTPAdapter is a hybrid no single existing file matches** — `DebridgeAdapter` for decoding,
`RelayAdapter`/`StargateAdapterV2` for failure handling.

## 4. `SuperDestinationExecutor.processBridgedExecution`

Signature at `src/executors/SuperDestinationExecutor.sol:94-105`. **No access control** — `external`,
no modifier. The unused first parameter (`tokenSent`) is never read; safety is entirely
signature+balance based, never caller-based.

Order:
1. `dstTokens.length == intentAmounts.length` else `ARRAY_LENGTH_MISMATCH` (`:106-107`).
2. `_validateOrCreateAccount` (`:109`, impl `:164-171`) — creates via `SuperSenderCreator` if
   `initData.length > 0` and no code; requires result == `account` else `INVALID_ACCOUNT`; requires
   `account.code.length > 0` else `ACCOUNT_NOT_CREATED`. **The adapter does no account creation.**
3. `_decodeMerkleRoot(userSignatureData)` (`:173-178`).
4. **The only hard revert past this point**: rebuild
   `destinationData = abi.encode(executorCalldata, uint64(block.chainid), account, address(this), dstTokens, intentAmounts)`
   — note `tokenSent` is **never** in the signed payload, and the **adapter's address is never bound
   into it either**, only the executor's — then `isValidDestinationSignature` must return `0x5c2ec0f3`
   else `INVALID_SIGNATURE()` (`:112-123`).
5. `_validateBalances` (`:125`, impl `:180-214`): zero `intentAmount` or insufficient balance emits an
   event and **returns false → early return, no revert.** This is why every adapter transfers before
   calling the executor, and why the fee-reconciliation decision needs no adapter-side math.
6. Merkle replay: already-used root emits and **returns** (no revert, `:127-130`); else mark used
   (`:132`) — after signature+balance validation, before execution.
7. `_shouldSkipCalldata` (`:134`, impl `:158-162`) — leading selector must be
   `ISuperExecutor.execute.selector` and length > `EMPTY_EXECUTION_LENGTH` (228); else emit and return.
8. Wrap in one `Execution`, call `_execute`, emit `SuperDestinationExecutorExecuted`.

**Adapter must pre-satisfy:** tokens already at `account` (the executor only checks, never moves);
`userSignatureData` byte-unmodified; `dstTokens`/`intentAmounts` matching what was signed. **The
adapter's identity is never bound on-chain** — it is enforced out-of-band via `destinationCaller`.

## 5. Deployment + bytecode locking

- `CoreContracts` struct (`DeployV2Core.s.sol:28-32`) — add a `cctpAdapter` field.
- `string[5] memory adapterContracts = ["AcrossV3AdapterV2","RelayAdapter","DebridgeAdapter","StargateAdapter","StargateAdapterV2"]`
  (`:353-355`) → bump to `string[6]` with `"CCTPAdapter"` (also bumps `expectedAdapters` at `:358`).
  `AcrossV3Adapter` v1 is intentionally absent — adapters are additive, never removed.
- Add `CCTP_ADAPTER_KEY = "CCTPAdapter"` in `script/utils/Constants.sol` (next to `:36-40`). This string
  is simultaneously the tracking key, the locked-artifact filename stem, and the CREATE2 salt seed.
- **CREATE2 salt**: `keccak256(abi.encodePacked("SuperformV2", saltNamespace, name, "v2.0"))`
  (`DeployV2Base.s.sol:391-395`) — same address on every chain within a namespace, provided constructor
  args are identical.
- **Bytecode**: `script/locked-bytecode/{name}.json` (prod) or `-dev/` (dev/staging) via `vm.getCode`
  (`:401-410`); `__checkBytecodeExists` soft-fails (`:431-443`). Two-stage, non-automated:
  `script/run/tooling/regenerate_bytecode.sh:82-98` copies `out/` → `script/generated-bytecode/` for a
  fixed `CORE_CONTRACTS` allowlist (currently `DebridgeAdapter, StargateAdapter, StargateAdapterV2,
  AcrossV3AdapterV2, RelayAdapter` — **not** `AcrossV3Adapter`) — `CCTPAdapter` must be added. There is
  **no automated copy into `locked-bytecode(-dev)/`**; that is a manual, reviewed step (consistent with
  `specs/stargate-compose-adapter/technical-spec.md:356`'s single unelaborated line).
- **`MessageTransmitterV2` config**: does not exist in the repo today. Precedent is
  `CCTP_V2_TOKEN_MESSENGER` — a **flat `address` constant**, not a per-chain map
  (`Constants.sol:358`), used for both hooks (`DeployV2Core.s.sol:4230, 4236`). Add
  `CCTP_V2_MESSAGE_TRANSMITTER` beside it; do not thread it through `ConfigCore`'s per-chain maps
  (contrast Across's genuinely per-chain `acrossSpokePoolV3s[chainId]`).
- **⚠️ Availability-gating inconsistency worth fixing:** the 5 existing adapters deploy *conditionally*
  via `availability.xAdapter` gated on a per-chain config address
  (`_getContractAvailability:341-397`; deploy `:2953-3040+`; verify `_checkAdapterContracts:1755-1838`).
  The **CCTP hooks deploy unconditionally** (`:4223-4238`, outside any `if`) even though CCTP is not on
  every Superform chain. `CCTPAdapter` should follow the **conditional** adapter pattern (gate on
  `MessageTransmitterV2.code.length > 0`), not the hooks' unconditional one.
- `_buildCoreVerificationRecords` (asserted `length == 14` in
  `test/script/DeployV2CoreVerificationRecords.t.sol:40`) covers only ledger/oracle/registry — adapters
  use `_checkAdapterContracts`, so **no change to the 14-record list or its regression test.**
- Prod outputs `script/output/prod/{chainId}/{Chain}-latest.json` are written automatically by
  `_exportContract`/`_writeExportedContracts` (`DeployV2Base.s.sol:449-509`) — no manual edit.
- **No hook-side deploy changes**: CCTP's hooks are pure burn hooks with no combined "send+execute"
  variant to rewire (unlike `AcrossSendFundsAndExecuteOnDstHookV2`, gated on adapter availability at
  `:2266-2287`) — confirming adapter-only is deploy-script-consistent.

## 6. Test conventions

**Base class:** adapter unit tests use the lighter `test/utils/Helpers.sol` (`Test` + `Constants`), not
the full `test/BaseTest.t.sol`. Legacy `test/unit/adapters/AdaptersUnitTests.sol` (no `.t.sol` suffix)
covers the three 6-tuple adapters together; newer adapters get their own files.

**Mocks:** the destination executor is **always mocked**, via `vm.mockCall`
(`AdaptersUnitTests.sol:75-84`) or a purpose-built mock with failure modes — `AcrossV3AdapterV2`'s
`ExecutionMode` enum (`Success/EmptyRevert/CustomError/ReturnBomb/OutOfGas/ShortRevert`) for
returnbomb-safety, `RelayAdapterUnitTests.t.sol`'s `MockDestinationExecutor` (`:11-52`) with
`shouldRevert`/`shouldReturnbomb` toggles. A shared DRY variant exists:
`test/unit/simulationHelpers/DestinationSimulationTestBase.sol` (`RecordingDestinationExecutor` +
`_signatureData(...)`). **No `MockMessageTransmitterV2` exists** — must be created, modeled on
`lib/pigeon/src/cctp/interfaces/IMessageTransmitterV2.sol:6-26`.

**Fixtures:** the 2-tuple adapters build `SignatureData`/`DstProof[]` with a dummy `hex"abcdef"`
signature. **Unnecessary for CCTP** — the relevant precedent is `AdaptersUnitTests._buildDestinationData()`
(`:88-101`), building the flat 6-tuple directly with a fake `sigData`.

**Naming:** `test_<Feature>`, `test_<Feature>_<Condition>`, `testFuzz_<Feature>` with `bound(...)`;
section banners matching contract style; `vm.expectRevert(Contract.ERROR.selector)` inline.

**Fork/E2E:** `test/integration/{bridge}/{Adapter}E2EFork.t.sol`, extending `MerkleTreeHelper`, two-fork
pattern with RPC keys from `test/utils/Constants.sol:53,55`. These deploy a **local adapter instance**
against the **real deployed** `SuperDestinationExecutor`, `deal()` funds, `vm.prank` as the bridge, and
assert "transfer succeeds, execution best-effort fails" with an intentionally invalid signature.

### The CCTP test precedent already in-repo — resolves the attestation question
`test/integration/cctp/CCTPHooksFork.t.sol` (1229 lines) contains `CCTPHooksForkE2E` (`:882-1229`),
a working real-attestation cross-fork suite built on the **already-vendored**
`lib/pigeon/src/cctp/CctpV2Helper.sol`:
- Hardcodes `MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64` (`:15`).
- `help(destDomain, forkId, logs)` filters source-fork `MessageSent(bytes)` logs, switches fork,
  **pranks the real `attesterManager()` to `enableAttester` its own test key and
  `setSignatureThreshold(1)`** (`:107-120`) — this is the answer to "a valid attester signature cannot
  be produced against forked state."
- Signs with the test key (`:125-129`), patches `finalityThresholdExecuted` via assembly (`:131-145`),
  clears `usedNonces` via `vm.store` slot 29 (`:149-153`), and calls the **real** `receiveMessage`
  (`:100`), pranking as `destinationCaller` when set (`:95-98`).
- `test_Fork_E2E_BurnAndRelay_EthToBase` (`:933-959`) already burns on an Ethereum fork and asserts
  real USDC minted on a Base fork — **but mints to a plain EOA and never exercises hookData**, exactly
  as expected given no adapter exists.

**Closest templates:** unit → `RelayAdapterUnitTests.t.sol` (failure containment + claim path; Relay is
the closest analogue since it also has no push callback) with the decode half swapped for
`AdaptersUnitTests._buildDestinationData()`. Fork → extend `CCTPHooksForkE2E` directly: point
`mintRecipient`/`destinationCaller` at the adapter and call `adapter.relay(message, attestation)` in
place of the helper's internal `receiveMessage`.

⚠️ `CCTPHooksFork.t.sol`'s `MockCCTPForkSignatureStorage.retrieveSignatureData` (`:20-28`) returns a
`proofDst` array of **length 0** — that fixture fails every destination signature check. The adapter
suite needs a real `SignatureData` fixture with a populated `DstProof`; see `test/BaseTest.t.sol:552`
and `test/unit/simulationHelpers/CrossChainSuperVaultDestinationDeBridgeE2E.t.sol`.

## 7. Prior CCTP work

**`specs/cctp-bridge-hooks/`** (PR #885, `65f8b5ab`, SUP-19679/SUP-19617) — source-side only. Shipped
decisions: the no-approval / approve-reset-approve pair; the `hookCallData` signature-append via
transient storage (dodging the circular "merkle root signs data containing its own signature"
dependency); `usePrevHookAmount` scaling `maxFee` via `Math.mulDiv`.

**The root cause of the gap**, stated plainly at `interview-notes.md:28-33`:
> *"Send-side hooks only — no receive hook needed. Circle's attestation service + off-chain relayers
> handle the receive side (calling receiveMessage on MessageTransmitter)."*

**This is incorrect** — `receiveMessage` only verifies and mints; it never executes `hookData`. The
same error is compounded at `research/framework-docs.md:83` (*"If hookData provided … hook is
executed"*), stated without citation. **That single wrong assumption is why the hook shipped with a
wire format nobody was ever built to consume.**

**Layout note:** `technical-spec.md:124-141` proposed offsets starting at `burnToken@20`; the shipped
code prepends a 52-byte strategy header, shifting everything +52 (`CCTPSendHook.sol:32-43, 113-127`).
The old spec is **obsolete** — anyone building an SDK encoder from it produces garbage.

**`specs/stargate-compose-adapter/`** — the direct architectural precedent, framed identically
("completing the destination-side flow…", `spec.md:12`). Transferable: adapter receives all tokens then
forwards; **no source hook changes** — "Bundler is responsible for setting `to = adapter address`"
(`interview-notes.md:45-48`), the same SDK trust assumption CCTP makes for
`mintRecipient`/`destinationCaller`; and sender validation **started endpoint-only in V1 and was
hardened in V2 after security review** — a precedent suggesting CCTPAdapter's posture may similarly get
hardened in a V2 once in production.

**Generalizable lessons:** (1) the delivery→execution gap is an accepted bounded risk across all
adapters; (2) the trend is toward **more** defense-in-depth (`ReentrancyGuard` added in Relay/StargateV2
despite earlier research judging it unnecessary); (3) try/catch-around-decode is only *required* where
the entrypoint has a hard liveness constraint (LZ's ordered queue) — CCTP has none, so it is optional
hardening rather than a requirement.

## Key artifact paths

- New contract: `src/adapters/CCTPAdapter.sol`
- New vendor interface: `src/vendor/bridges/cctp/IMessageTransmitterV2.sol` — model on
  `lib/pigeon/src/cctp/interfaces/IMessageTransmitterV2.sol` and the existing `ITokenMessengerV2.sol`
- Constants: `CCTP_ADAPTER_KEY`, `CCTP_V2_MESSAGE_TRANSMITTER` in `script/utils/Constants.sol`
- Deploy: `DeployV2Core.s.sol` — `CoreContracts` struct, `adapterContracts` (`:353-355`), availability
  gating, `_checkAdapterContracts` (`:1755-1838`), deploy block (pattern at `:2953-3040`)
- Bytecode: add `"CCTPAdapter"` to `regenerate_bytecode.sh:82-98`; create
  `script/locked-bytecode{,-dev}/CCTPAdapter.json`
- Tests: `test/unit/adapters/RelayAdapterUnitTests.t.sol` + `AdaptersUnitTests.sol` (unit),
  `test/integration/cctp/CCTPHooksFork.t.sol:882-1229` (fork extension point)
- Reusable infra: `lib/pigeon/src/cctp/CctpV2Helper.sol` (already proven against mainnet-fork state)
