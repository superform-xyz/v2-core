# Repository Research: Bridge Integration Pattern in Superform v2-core

Reference report for spec'ing the Relay (relay.link) integration: source-side send hooks in `src/hooks/bridges/relay/` + `src/adapters/RelayAdapter.sol`. All paths absolute under `/Users/cosming/1.Coding/Superform/v2-core/`.

---

## 1. Across integration (the template to copy)

### 1.1 Files

| File | Role |
|---|---|
| `src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol` | Current-gen send hook (native-capable, no approvals) |
| `src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.sol` | ERC20 variant wrapping the bridge call in approve 0 / approve N / call / approve 0 |
| `src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol` + `ApproveAnd...Hook.sol` | Legacy V1 (6-field destination message); still deployed but V2 is the template |
| `src/adapters/AcrossV3AdapterV2.sol` | Destination adapter (compact 2-field message) |
| `src/adapters/AcrossV3Adapter.sol` | Legacy V1 adapter (6-field message, no failure handling) |
| `src/vendor/bridges/across/IAcrossSpokePoolV3.sol`, `IAcrossV3Receiver.sol` | Vendored external interfaces (Relay's interfaces should go in `src/vendor/bridges/relay/`) |

### 1.2 `AcrossSendFundsAndExecuteOnDstHookV2` (46-232)

**Declaration** (line 46): `contract ... is BaseHook, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow`.

**Constructor** (75-79): `constructor(address spokePoolV3_, address validator_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)`; zero-address checks revert `ADDRESS_NOT_VALID()`; stores `SPOKE_POOL_V3` (public immutable, line 50) and `VALIDATOR` (private immutable, line 51 — this is the **SuperValidator**, used only for `retrieveSignatureData`). Bridge target addresses are immutable constructor params, one deployment per chain — this is the pattern the interview notes lock in for Relay (`specs/relay-bridge-integration/interview-notes.md:36`).

**Hook data layout** — tightly packed via `abi.encodePacked`, decoded with `BytesLib` at fixed offsets (doc block lines 30-45, decode at 106-120):

| Offset | Type | Field |
|---|---|---|
| 0 | bytes32 | placeholder0 (yieldSourceOracleId slot — standard 52-byte strategy header; `src/libraries/HookDataDecoder.sol:10-16`) |
| 32 | address | placeholder1 (yieldSource slot) |
| 52 | uint256 | `value` (native msg.value for the bridge call) |
| 84 | address | `recipient` (= destination adapter address) |
| 104 | address | `inputToken` |
| 124 | address | `outputToken` |
| 144 | uint256 | `inputAmount` — `AMOUNT_POSITION = 144` (line 53) |
| 176 | uint256 | `outputAmount` |
| 208 | uint256 | `destinationChainId` |
| 240 | address | `exclusiveRelayer` |
| 260 | uint32 | `fillDeadlineOffset` |
| 264 | uint32 | `exclusivityPeriod` |
| 268 | bool (1 byte) | `usePrevHookAmount` — `USE_PREV_HOOK_AMOUNT_POSITION = 268` (line 52) |
| 269..end | bytes | `destinationMessage` = `abi.encode(initData)` (V2, 1-field) |

Guard: `if (data.length < 269) revert DATA_NOT_VALID()` (line 106; note the ApproveAnd variant still has the stale `< 217` check at its line 108).

**usePrevHookAmount chaining** (122-137): if set, reads `ISuperHookResult(prevHook).getOutAmount(account)`, rescales `outputAmount` proportionally via `Math.mulDiv(outputAmount, outAmount, inputAmount)`, then overwrites `inputAmount = outAmount`. **Native handling**: if `inputToken == IAcrossSpokePoolV3(SPOKE_POOL_V3).wrappedNativeToken()` and `value != 0`, `value` is also set to `outAmount` (131-136) so msg.value tracks the chained amount. Then `inputAmount == 0` reverts `AMOUNT_NOT_VALID`, `recipient == 0` reverts `ADDRESS_NOT_VALID` (139-143).

**Signature append** (145-157): if `destinationMessage.length > 0` (min 64 bytes check), fetch `sigData = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)` — the full signed `SignatureData` blob that SuperValidator parked in **transient storage** during userOp validation (`src/validators/SuperValidator.sol:29, 93`; interface `src/interfaces/ISuperSignatureStorage.sol:23`). It decodes the 1-field input and re-encodes `abi.encode(initData, sigData)`. This two-phase construction exists because the signature can't be inside the merkle root it signs (circular dependency — explained in V1 hook doc, `AcrossSendFundsAndExecuteOnDstHook.sol:25-28`).

**Execution built** (160-180): single `Execution` targeting `SPOKE_POOL_V3` with `value: d.value`, calldata `IAcrossSpokePoolV3.depositV3Now(account /*depositor*/, recipient, inputToken, outputToken, inputAmount, outputAmount, destinationChainId, exclusiveRelayer, fillDeadlineOffset, exclusivityPeriod, destinationMessage)`.

**Standard interface surface** (every bridge send hook implements the same set):
- `name()` / `description()` (82-89) — pure strings, consumed by `tooling/generate_hook_manifest.py`.
- `decodeUsePrevHookAmount(bytes)` (188-190) — `ISuperHookContextAware`.
- `decodeAmounts(bytes)` (193-196) → `[inputAmount]`; `amountRoles(bytes)` (199-202) → `[AmountMeta(Direction.IN, Denomination.TOKEN)]` — `ISuperHookInflowOutflow`.
- `_supportsSizingInterface() → true` (205-207) — enables ERC-165 sizing detection in `BaseHook.supportsInterface` (`src/hooks/BaseHook.sol:251-266`).
- `replaceCalldataAmounts(bytes, uint256[])` (210-221) — `ISuperHookOutflow`; single-amount, delegates to `_replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION)`.
- `inspect(bytes)` (224-231) — `abi.encodePacked(recipient, inputToken, outputToken, exclusiveRelayer)`; convention: return the packed set of every address embedded in hook data so the off-chain layer / merkle validation can whitelist targets.

**NONACCOUNTING behavior**: hook type `NONACCOUNTING` (`src/interfaces/ISuperHook.sol:246-251` — swap/bridge hooks don't touch the ledger). The Across hooks override **neither** `_preExecute` nor `_postExecute` and keep default `_pipeMode() = TRANSFORM` (`BaseHook.sol:347-349`), so they never set an `outAmount` — funds leave the chain, nothing meaningful flows to a next hook. (`DeBridgeCancelOrderHook.sol:231` shows the alternative: a `PASSTHROUGH` override that auto-forwards prev output; see §4.)

### 1.3 `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2`

Identical layout/constructor/interfaces; differences:
- ERC20-only (doc line 31: "For native token transfers, use AcrossSendFundsAndExecuteOnDstHookV2 instead"); its `usePrevHookAmount` branch (124-133) skips the native `value` adjustment.
- `_buildHookExecutions` returns **4 executions** (156-181): `approve(SPOKE_POOL_V3, 0)` → `approve(SPOKE_POOL_V3, inputAmount)` → bridge call (via private `_buildBridgeExecution`, 238-266) → `approve(SPOKE_POOL_V3, 0)` cleanup. This reset-approve-execute-cleanup quad is the house pattern for all ApproveAnd* hooks.

### 1.4 `AcrossV3AdapterV2` — full flow (`src/adapters/AcrossV3AdapterV2.sol`)

- Declaration (24): `contract AcrossV3AdapterV2 is IAcrossV3Receiver, ReentrancyGuard`.
- Immutables (32, 35): `ACROSS_SPOKE_POOL`, `SUPER_DESTINATION_EXECUTOR`; constructor zero-checks (105-111).
- `failedTransfers` mapping (38): `account => token => amount`.
- `handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes message)` (118-174), steps:
  1. **msg.sender guard** (128-130): `msg.sender != ACROSS_SPOKE_POOL` → `INVALID_SENDER()` (error lives on `IAcrossV3Receiver`).
  2. **Decode** (133): `(bytes initData, bytes sigDataRaw) = abi.decode(message, (bytes, bytes))`.
  3. **Extract from sigData** (136, impl 206-228): decodes `SignatureData` as `(uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes)` (mirrors `SuperValidatorBase._decodeSignatureData`), loops `proofDst[]` for `dstChainId == uint64(block.chainid)`, and pulls `account`, `executorCalldata` (= `info.data`), `dstTokens`, `intentAmounts` from `DstProof.info`. This dedup is the whole point of V2 (contract doc 18-21): V1 duplicated those fields in the message.
  4. **No matching DstProof → revert** `NO_DST_PROOF_FOR_CHAIN()` (141-143); doc note (61-63): reverting is safe for Across because fills are independent, unlike Stargate lzCompose which must not revert.
  5. **Zero account → revert** `ACCOUNT_NOT_VALID()` (148-150).
  6. **Fund forwarding with fallback** (153-160): `_tryTransfer` (236-241) does a low-level `token.call(abi.encodeCall(IERC20.transfer, ...))` tolerant of no-return-value tokens (USDT); on failure it credits `failedTransfers[account][token] += amount` and emits `TransferFailed`, else `TransferSucceeded`. **Note**: this adapter's fallback and `claimFailedTransfer` (184-195) are **ERC20-only** — Across always delivers an ERC20 (WETH for native routes). The native-capable version of the same pattern is in `StargateAdapterV2` (`src/adapters/StargateAdapterV2.sol:66-67, 192 (receive()), 355-375 (claim with native branch), 424-433 (_tryTransfer with address(0) → account.call{value})`). Per the interview notes (line 51), the **RelayAdapter must take the Stargate-style native-inclusive version**: `receive()`, `token == address(0)` semantics, and native claim path.
  7. **Best-effort execution** (163-173): `try SUPER_DESTINATION_EXECUTOR.processBridgedExecution(tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata, sigDataRaw) {} catch { emit ExecutionFailed(account); }` — tokens are already at the account, so execution failure only loses the automated hook run, never funds.
- Claim: `claimFailedTransfer(address token, uint256 amount)` (184-195), `nonReentrant`, only `msg.sender`'s own balance, errors `ZERO_AMOUNT` / `INSUFFICIENT_FAILED_BALANCE`, event `FailedTransferClaimed`.
- Events (83-99): `TransferSucceeded`, `TransferFailed`, `ExecutionFailed`, `FailedTransferClaimed`.
- The **V1 adapter** (`AcrossV3Adapter.sol:46-88`) is the naive version: 6-field decode, unconditional `safeTransfer`, unguarded (no try/catch) executor call — do not copy.

---

## 2. deBridge integration — how it differs

**Hooks**: `src/hooks/bridges/debridge/DeBridgeSendOrderAndExecuteOnDstHook.sol` and `DeBridgeCancelOrderHook.sol` (no ApproveAnd variant; no V2 yet — deBridge still uses the 6-field destination payload).

- Same skeleton: `BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)`, constructor `(dlnSource_, validator_)` (92-96), same four interfaces, same `usePrevHookAmount` proportional rescale of `takeAmount` (127-144).
- **Variable-length data layout** (doc 29-80, `_createOrder` 245-359): because deBridge fields are dynamic `bytes`, the layout is offset-cursor based with `paramLength` prefixes — `usePrevHookAmount` at offset **52** (before value, unlike Across), `AMOUNT_POSITION = 105` (`giveAmount`).
- **Native input**: `giveTokenAddress == address(0)` means native; the chaining branch adjusts `value` by `-oldGiveAmount + outAmount` with an `AMOUNT_UNDERFLOW` guard (137-143). deBridge charges a protocol fee in `value` on top of the give amount, hence the delta arithmetic rather than assignment.
- **Signature retrieval is unconditional** (line 123) and gets folded into the DLN `ExternalCallEnvelopV1.payload` (361-383): payload = the same 6-field tuple `(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)`; envelope adds `fallbackAddress`, `executorAddress`, `executionFee`, `allowDelayedExecution`, `requireSuccessfullExecution`; final bytes = `abi.encodePacked(version, abi.encode(envelope))`.
- Single execution to `IDlnSource.createOrder(orderCreation, affiliateFee, referralCode, "")` (150-155).
- `inspect()` (195-206) decodes the whole order and packs 6 addresses.

**Adapter**: `src/adapters/DebridgeAdapter.sol` implements `IExternalCallExecutor` with **two entrypoints**: `onEtherReceived` (54-84, forwards `address(this).balance` via raw call, reverts `ON_ETHER_RECEIVED_FAILED` on failure) and `onERC20Received` (87-117, `safeTransfer`). Sender guard is a modifier `onlyExternalCallAdapter` checking `msg.sender == IDlnDestination(DLN_DESTINATION).externalCallAdapter()` (45-48) — a **dynamic lookup**, not an immutable, because deBridge can rotate its adapter. Both decode the 6-field payload (145-159) and call `processBridgedExecution` **without try/catch** and without a failedTransfers fallback — it predates the V2 hardening; the deBridge envelope's own `fallbackAddress` covers delivery failure instead.

Summary of deltas vs Across: pull-payload from deBridge's external-call adapter instead of push from SpokePool; two token-type entrypoints; dynamic sender authority; no self-claim fallback; V1 message format.

---

## 3. `SuperDestinationExecutor.processBridgedExecution`

`src/executors/SuperDestinationExecutor.sol:94-144`:

```solidity
function processBridgedExecution(
    address,                      // tokenSent — ignored
    address account,
    address[] memory dstTokens,
    uint256[] memory intentAmounts,
    bytes memory initData,
    bytes memory executorCalldata,
    bytes memory userSignatureData
) external override
```

Steps, in order:
1. `dstTokens.length != intentAmounts.length` → `ARRAY_LENGTH_MISMATCH` (106-107).
2. `_validateOrCreateAccount(account, initData)` (109, impl 164-171): if `initData` present and account has no code, counterfactually deploys via `ISuperSenderCreator.createSender` (initCode = 20-byte senderCreator address ++ senderData, 216-226) and requires the computed address matches `account`; otherwise requires account exists.
3. `_decodeMerkleRoot(userSignatureData)` (110, 173-178) — sigData shape `(uint64[], uint48, uint48, bytes32 merkleRoot, bytes32[], DstProof[], bytes)`.
4. **Signature validation** (112-123): builds `destinationData = abi.encode(executorCalldata, uint64(block.chainid), account, address(this), dstTokens, intentAmounts)` and calls `ISuperDestinationValidator(SUPER_DESTINATION_VALIDATOR).isValidDestinationSignature(account, abi.encode(userSignatureData, destinationData))`; must return magic value `0x5c2ec0f3` else `INVALID_SIGNATURE`. The validator (`src/validators/SuperDestinationValidator.sol:46-58`) reconstructs the merkle leaf from destinationData, verifies proof against the signed root, recovers the signer, and checks the account's owner + `validUntil`.
5. `_validateBalances(account, dstTokens, intentAmounts)` (125, impl 180-214): each intent amount must be non-zero and covered by the account's balance (`address(0)` → native `account.balance`, else `balanceOf`); on shortfall **emits and returns silently** (no revert) so the same root can be retried after more fills land.
6. **Replay protection** (127-132): `usedMerkleRoots[account][merkleRoot]` — if used, emit `...RootUsedAlready` and return; else mark used. Users can preemptively burn roots via `markRootsAsUsed` (147-153).
7. `_shouldSkipCalldata` (134, 158-162): calldata must start with `ISuperExecutor.execute.selector` and exceed `EMPTY_EXECUTION_LENGTH = 228`; else emit `...NoHooks` and return.
8. Execute: wraps `executorCalldata` as a self-targeted `Execution` and runs it **on the account** via `_execute(account, execs)` (139-143), emitting `SuperDestinationExecutorExecuted`.

**Why it's permissionless-safe** (key for Relay, where the solver calls this directly): no msg.sender check anywhere; every parameter the caller supplies is either (a) bound into the merkle-leaf commitment the user signed (`executorCalldata`, chainid, `account`, executor address, `dstTokens`, `intentAmounts`), (b) checked against on-chain state (balances, counterfactual address derivation), or (c) replay-gated (root). A malicious caller can only cause a no-op or execute exactly what the user signed once funds are present.

---

## 4. BaseHook conventions (`src/hooks/BaseHook.sol`)

- Constructor (128-131): `BaseHook(HookType, bytes32 subType)`; bridge hooks use `HookType.NONACCOUNTING` + `HookSubTypes.BRIDGE` = `keccak256("Bridge")` (`src/libraries/HookSubTypes.sol:8`). No new subtype needed for Relay.
- `build()` (149-183) sandwiches `_buildHookExecutions` between self-calls to `preExecute` and `postExecute`; both are mutex-guarded and account-gated (`msg.sender != account` → `UNAUTHORIZED_CALLER`, 186-201).
- **Transient storage**: per-account execution context nonce (`setExecutionContext`, 142-145, called by the executor), with keyed `tstore/tload` slots for outAmount, outToken, and pre/post mutexes (52-55, 362-439). `getOutAmount(account)` / `getOutToken(account)` (216-222) are what the next hook's `usePrevHookAmount` reads. `resetExecutionState` (225-232) requires both mutexes set.
- **PipeMode** (65-69, 293-298, 347-349): `TRANSFORM` (default; hook computes its own output, usually via balance-diff in overridden `_preExecute`/`_postExecute`), `PASSTHROUGH` (side-effect hook; default `_preExecute` auto-forwards prev hook's outAmount/outToken), `SOURCE` (reserved). Across/deBridge send hooks: default TRANSFORM with no overrides → outAmount stays 0. If a Relay send hook should let a later same-chain hook keep chaining (unusual for a terminal bridge hook), it would override `_pipeMode()` to `PASSTHROUGH` like `DeBridgeCancelOrderHook.sol:231`.
- `inspect()` default is empty virtual (243); bridge hooks must override with packed embedded addresses.
- ERC-165 sizing detection (251-266): override `_supportsSizingInterface() → true` when implementing `ISuperHookInflowOutflow`/`ISuperHookOutflow`.
- Helpers: `_decodeBool(data, offset)` (316-318), `_replaceCalldataAmount(data, amount, offset)` (328-342).
- Interface catalog in `src/interfaces/ISuperHook.sol`: `ISuperHookContextAware` (96), `ISuperHookInflowOutflow` with `Direction`/`Denomination`/`AmountMeta` (108-132), `ISuperHookOutflow` (157), `ISuperHook` with `HookType` enum and mandatory `name()`/`description()` (239-298).
- **Hook "registration"**: there is no on-chain registry write at deploy time in-core; hooks are registered post-deploy in SuperGovernor via ops scripts (`script/run/others/register_hooks_base.sh:18-36` pattern — hook name → address map, per chain) and surfaced to off-chain via the manifest (§5).

---

## 5. Constants / config / deploy wiring

- **Per-chain protocol addresses**: `script/utils/Constants.sol` — Across spokePools per chain at lines 77-88 (`ACROSS_SPOKE_POOL_MAINNET` ... `ACROSS_SPOKE_POOL_HYPEREVM`), deBridge DLN at 94-95 (`DEBRIDGE_DLN_SRC`/`DST`, same address on all chains). Contract **keys** (string, used for CREATE2 salts and artifact names): adapter keys at 34-35 (`ACROSS_V3_ADAPTER_V2_KEY = "AcrossV3AdapterV2"`, `DEBRIDGE_ADAPTER_KEY`), hook keys at 181-182 and 253 (`ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY`, etc.).
- **Configuration struct**: `script/utils/ConfigBase.sol:14-45` `EnvironmentData` holds `mapping(uint64 => address) acrossSpokePoolV3s` (17), `debridgeSrcDln`/`debridgeDstDln` (18-19). A Relay integration adds e.g. `relayDepositories` / `relayReceivers` mappings here.
- **Population**: `script/utils/ConfigCore.sol:18-33` (Across per chain, `address(0)` = "not live, skip"), 38-71 (deBridge src/dst).
- **Deploy script**: `script/DeployV2Core.s.sol`:
  - Availability accounting: adapters at 352-370, hooks at 466-516 — chains without a configured bridge address decrement expected counts and log skips.
  - Adapter deploy/check: `_checkAdapterContracts` 1720-1798 — `__checkContract(KEY, __getSalt(KEY), abi.encode(constructorArgs), env)`; AcrossV3AdapterV2 args = `(spokePool, superDestinationExecutor)` (1784-1793).
  - Hook deploy/check: 2181-2216 — Across V2 hooks args = `(spokePool, superValidator)`; deBridge send hook = `(debridgeSrcDln, superValidator)`.
  - Post-deploy invariant asserts: 884-898 (adapter's `ACROSS_SPOKE_POOL()`/`SUPER_DESTINATION_EXECUTOR()`, hooks' `SPOKE_POOL_V3()` match config).
  - **Locked bytecode system**: deployment consumes pre-built artifacts from `script/locked-bytecode/` (prod/staging) and `script/locked-bytecode-dev/`, regenerated into `script/generated-bytecode/` by `script/run/tooling/regenerate_bytecode.sh` (copies `out/<Name>.sol/<Name>.json`). Bytecode-existence gates like lines 803-811 (`__checkBytecodeExists("AcrossV3AdapterV2", env)`). A new Relay hook/adapter needs its JSON in these folders.
  - Deployment outputs land in `script/output/<env>/<chainId>/<Chain>-latest.json`.
- **Hook manifest**: `manifests/hooks.json`, generated by `make manifest` → `tooling/generate_hook_manifest.py` + `lint_hook_manifest.py` (Makefile 43-45; part of `make build`, line 17). Discovery is automatic: it rglobs `src/hooks/**/*Hook.sol` / `*HookV2.sol` (generate_hook_manifest.py:78-85) and merges deployed addresses from `script/output/*/<chain>/*-latest.json` (line 154). Entry shape (see `AcrossSendFundsAndExecuteOnDstHookV2` entry): `name`, `description`, `hookType`, `subtype`, `actionTypes` (`{intent: "bridge", stage: "instant"}`), `legSizing`, per-env `addresses`/`availableChains`, `amountMeta`, `sized`, `erc165`, `requiresApproval`, `approveVariant`, `compatibleProtocols`. There is also `hook-sizing-manifest.json` via `tooling/generate-hook-sizing-manifest.ts`. Naming the Relay hooks `*Hook.sol` makes them picked up automatically.

---

## 6. Test conventions

- **Unit — hooks**: `test/unit/hooks/bridges/AcrossHooksV2.t.sol` is the model (`contract AcrossHooksV2 is Helpers`, line 48). Uses a local `MockAcrossSignatureStorageV2` (21-46) returning a synthetic 7-tuple sigData with a `DstProof` for `block.chainid`; `vm.mockCall` for `wrappedNativeToken()` (89-93); a private `_encodeAcrossV2Data(bool usePrevHookAmount, bool includeDestinationMessage)` packer (~504-539) mirroring the offset layout. Coverage checklist to replicate for Relay: constructor + zero-address reverts, build with/without destination message, compact-format assertion, prevHook chaining (via `MockHook`) incl. output scaling and native `value`, data-too-short / amount-zero / recipient-zero / prevHook-amount-zero / short-destinationMessage reverts, `inspect`, `decodeUsePrevHookAmount` both values, `subtype`, `decodeAmounts`, `replaceCalldataAmounts` + fuzz + replace-then-build + field-preservation. Sibling files: `BridgeHooks.t.sol` (V1 Across + deBridge), `StargateHooksV2.t.sol`, `CCTPHooks.t.sol`.
- **Unit — adapters**: `test/unit/adapters/AdaptersUnitTests.sol` — one file, multiple `*AdapterTest is Helpers` contracts (Across at 26, Debridge at ~104, Stargate at 245), with tiny inline mocks (`MockDlnDestination` line 14, `MockStargatePool` 225) and `MockERC20` from `test/mocks/`; the test contract itself often plays the SUPER_DESTINATION_EXECUTOR role.
- **Fork/E2E-sim for the V2 adapter**: `test/integration/across/AcrossV3AdapterV2E2EFork.t.sol` (`contract AcrossV3AdapterV2E2EFork is MerkleTreeHelper`, line 19) — 20+ tests spanning transfer success, executor-fail-but-tokens-safe, failed transfer + claim, zero account, no DstProof, invalid sender, claim authorization/partial/exceed/isolation, multiple DstProofs, event params, immutable getters. Plus deterministic simulations in `test/unit/simulationHelpers/AcrossV3AdapterV2Simulations.t.sol` + shared helper `test/mocks/simulationHelpers/AcrossV3AdapterV2Simulations.sol` and `test/unit/simulationHelpers/AcrossDestinationExecutionE2E.t.sol`.
- **Pigeon cross-chain simulation**: `test/BaseTest.t.sol` imports `AcrossV3Helper` from `pigeon/across/AcrossV3Helper.sol` (line 146), deploys it per chain (486), and replays source-chain logs onto the destination fork via `_processAcrossV3Message` (1620-1681) with a `RELAYER_TYPE` enum controlling expected outcome events (NOT_ENOUGH_BALANCE / ENOUGH_BALANCE / NO_HOOKS / USED_ROOT / REVERT). BaseTest also deploys V1 adapter+hooks per fork with CREATE2 salt and registers them in `hooksAddresses` / `hooksByCategory[...][HookCategory.Bridges]` (545-549, 886-929), and provides hookData builders `_createAcrossV3ReceiveFundsAndExecuteHookData` (2222-2251). **Pigeon has no relay module** (only across, axelar, cctp, celer, debridge, hyperlane, layerzero(-v2), wormhole) — adding one in the pigeon repo is explicitly in scope per interview notes line 42. Stargate fork tests in `test/integration/stargate/` (`StargateAdapterV2E2EFork.t.sol` etc.) are the closest recent precedent for a full fork suite.
- Makefile: `ftest` (25), `test-integration` (37, currently pinned to one cross-chain test name).

---

## 7. Naming + placement for the Relay integration

Following the established conventions exactly:

| Artifact | Path |
|---|---|
| Send hook (native-capable) | `src/hooks/bridges/relay/RelaySendFundsAndExecuteOnDstHook.sol` (no "V2" suffix — start at the compact 2-field format like Across V2) |
| ERC20 approve variant | `src/hooks/bridges/relay/ApproveAndRelaySendFundsAndExecuteOnDstHook.sol` |
| Destination adapter | `src/adapters/RelayAdapter.sol` (matches `DebridgeAdapter.sol` naming; bridge-version suffix only if Relay versions its contracts, cf. `AcrossV3AdapterV2`) |
| Vendored interfaces | `src/vendor/bridges/relay/IRelayDepository.sol` (and receiver/router interfaces as needed) |
| Config | `RELAY_DEPOSITORY_<CHAIN>` constants in `script/utils/Constants.sol`; `relayDepositories` mapping in `ConfigBase.EnvironmentData`; population in `ConfigCore.sol`; keys `RELAY_ADAPTER_KEY = "RelayAdapter"`, `RELAY_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY`, `APPROVE_AND_RELAY_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY` |
| Deploy | availability + `__checkContract` blocks in `script/DeployV2Core.s.sol` (adapter args `(relayDepository, superDestinationExecutor)`, hook args `(relayDepository, superValidator)`), bytecode JSONs in `script/locked-bytecode{,-dev}/` |
| Tests | `test/unit/hooks/bridges/RelayHooks.t.sol`, Relay section (or `RelayAdapterTest`) in `test/unit/adapters/AdaptersUnitTests.sol`, `test/integration/relay/RelayAdapterE2EFork.t.sol`, optional `test/mocks/simulationHelpers/RelayAdapterSimulations.sol` |

**Relay-specific structural notes surfaced by this research** (feed into the spec):
- Relay has no destination receiver callback, so unlike Across the source hook carries **no destinationMessage** on-chain (origin deposit carries only an `id`) — the sigData-append machinery (`ISuperSignatureStorage.retrieveSignatureData`) is only needed if the adapter path packages a message off-chain; the executor call parameters instead travel through Relay's `/quote` `txs[]`. The permissionless safety of `processBridgedExecution` (§3) is what makes the direct-to-executor flow sound.
- The RelayAdapter, being callable by anyone (no SpokePool-style msg.sender guard is possible), must follow AcrossV3AdapterV2's decode/DstProof-match/forward/try-catch shape but drop the sender guard and add StargateAdapterV2's native handling (`receive()`, `address(0)` token semantics in `_tryTransfer` and `claimFailedTransfer`).
- The hook data layout should reuse the 52-byte header + fixed offsets + trailing `usePrevHookAmount` bool convention, with `AMOUNT_POSITION` constant and the four standard interfaces, so the manifest/sizing tooling picks it up unchanged.
