# CCTP Destination Adapter — Repo Analysis

Research to inform building `CCTPAdapter` (CCTP V2 destination-side receiver) for Superform v2-core.
All file paths are absolute-from-repo-root under `/Users/cosming/1.Coding/Superform/v2-core`.

---

## 1. Existing adapter pattern

All adapters live in `src/adapters/` and share one job: receive bridged funds + payload, push funds to the
intent `account`, then call `SUPER_DESTINATION_EXECUTOR.processBridgedExecution(...)`. There are two generations:

- **V1 (simple, revert-on-failure):** `AcrossV3Adapter.sol`, `DebridgeAdapter.sol`
- **V2 (hardened, best-effort, failed-transfer escrow + self-claim):** `AcrossV3AdapterV2.sol`, `RelayAdapter.sol`,
  `StargateAdapter.sol` — **these are the templates to copy for the new `CCTPAdapter`.**

### Common signature/style facts
- SPDX `Apache-2.0`, `pragma solidity 0.8.30;` (all adapters).
- `using SafeERC20 for IERC20;` in every adapter (`DebridgeAdapter.sol:18`, `AcrossV3Adapter.sol:19`,
  `AcrossV3AdapterV2.sol:25`, `RelayAdapter.sol:36`, `StargateAdapter.sol:30`).
- Immutable `ISuperDestinationExecutor public immutable SUPER_DESTINATION_EXECUTOR;` set in constructor, always
  zero-checked with `error ADDRESS_NOT_VALID();` (e.g. `AcrossV3Adapter.sol:31-38`, `RelayAdapter.sol:72,128-133`).
- `@author Superform Labs` NatSpec, `/*//// STORAGE / ERRORS / EVENTS / CONSTRUCTOR ////*/` banner comments.

### Constructor args per adapter
- `AcrossV3Adapter(address acrossSpokePool_, address superDestinationExecutor_)` — `AcrossV3Adapter.sol:33`.
- `AcrossV3AdapterV2(address acrossSpokePool_, address superDestinationExecutor_)` — `AcrossV3AdapterV2.sol:105`.
- `DebridgeAdapter(address dlnDestination, address superDestinationExecutor_)` — `DebridgeAdapter.sol:33`; also reads
  `IDlnDestination(dlnDestination).externalCallAdapter()` and stores `DLN_DESTINATION`.
- `RelayAdapter(address superDestinationExecutor_)` — **single arg** (permissionless), `RelayAdapter.sol:128`.
- `StargateAdapter(address lzEndpoint_, address tokenMessaging_, address superDestinationExecutor_)` —
  `StargateAdapter.sol:140`.

> For `CCTPAdapter` the natural constructor is
> `CCTPAdapter(address messageTransmitterV2_, address superDestinationExecutor_)` — analogous to Across
> `(spokePool, executor)` and Debridge `(dlnDestination, executor)`.

### Trust / `onlyX` gating (how each authenticates the caller)
- **Across (V1 & V2):** `if (msg.sender != ACROSS_SPOKE_POOL) revert INVALID_SENDER();`
  (`AcrossV3Adapter.sol:56`, `AcrossV3AdapterV2.sol:128`). `INVALID_SENDER` comes from `IAcrossV3Receiver`.
- **Debridge:** `modifier onlyExternalCallAdapter` checks `msg.sender ==
  IDlnDestination(DLN_DESTINATION).externalCallAdapter()` (`DebridgeAdapter.sol:45-48`), applied to both entrypoints.
- **Stargate:** `if (msg.sender != LZ_ENDPOINT) revert INVALID_SENDER();` (`StargateAdapter.sol:179`) **plus** a
  second authenticity check that `_from` is a registered pool via `TOKEN_MESSAGING.assetIds(_from) != 0`
  (`StargateAdapter.sol:193`).
- **Relay:** **permissionless** — `processRelayExecution` has no sender check by design
  (`RelayAdapter.sol:24-34,149`); safety is anchored by the executor's signed-intent + balance validation plus two
  adapter-local guards (`INSUFFICIENT_FUNDS_RECEIVED` balance check `RelayAdapter.sol:182-186`, and `totalEscrowed`
  exclusion `RelayAdapter.sol:52,184`).

> For `CCTPAdapter`, the trust anchor is the **CCTP `destinationCaller` = adapter** mechanism. Because
> `IMessageTransmitterV2.receiveMessage` mints USDC to `mintRecipient` (= adapter) and CCTP itself enforces that
> only `destinationCaller` (= adapter) can relay when set, the adapter self-authenticates by being the required
> caller. `receiveAndExecute` itself can be permissionless (anyone can submit the attestation), Relay-style — the
> mint is gated by CCTP, and downstream execution is gated by the signed intent in the executor.

### How each receives funds + payload
- **Across V1 (`handleV3AcrossMessage`, `AcrossV3Adapter.sol:46-88`):** SpokePool has already delivered `tokenSent`
  to the adapter; `message` is the 6-field tuple; `safeTransfer(account, amount)` then executor call.
- **Across V2 (`AcrossV3AdapterV2.sol:118-174`):** SpokePool delivers tokens; `message` is compact 2-field
  `abi.encode(initData, sigData)`; account/executorCalldata/dstTokens/intentAmounts are **extracted from `sigData`**
  (see §2 `_extractFromSigData`).
- **Debridge (`DebridgeAdapter.sol:54-117`):** two entrypoints `onEtherReceived` (native) and `onERC20Received`
  (ERC20). Debridge passes token+amount as call args; payload in `_payload` (6-field tuple).
- **Stargate (`lzCompose`, `StargateAdapter.sol:167-223`):** token delivered in a **separate prior tx** (`lzReceive`);
  `amountLD` parsed from the OFTComposeMsgCodec header (bytes 12-44), inner payload after the 76-byte header.
- **Relay (`processRelayExecution`, `RelayAdapter.sol:149-212`):** `payable`; funds either pre-delivered to adapter
  or arrive as `msg.value`; `message` is compact 2-field format.

> For `CCTPAdapter`, funds are **minted to the adapter by `receiveMessage`** inside the same call, then the adapter
> reads its own USDC balance delta (or the burn-message amount) and `safeTransfer`s to `account`. The payload
> (`hookData`) is **sliced out of the attested CCTP message itself**, not passed as a separate arg — this is the key
> structural difference from every existing adapter.

### How each calls `processBridgedExecution`
Identical 7-arg call in all adapters (`tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata,
sigData`):
- Across V1: `AcrossV3Adapter.sol:79-87` (direct, reverts propagate).
- Debridge: routed through private `_handleMessageReceived(...)` → `DebridgeAdapter.sol:122-143` (direct).
- Across V2: wrapped in `try/catch { emit ExecutionFailed(...) }` `AcrossV3AdapterV2.sol:163-173`.
- Relay: `try/catch` `RelayAdapter.sol:201-211` (catch binds no var → returnbomb-safe).
- Stargate: `try/catch` `StargateAdapter.sol:299-304`.

### Event / error conventions
- V1 adapters carry almost no events (rely on executor events). Errors: `ADDRESS_NOT_VALID`, `INVALID_SENDER`
  (from interface), Debridge adds `ON_ETHER_RECEIVED_FAILED`, `ONLY_EXTERNAL_CALL_ADAPTER`.
- V2 adapters define a **standard event set** (copy these names): `TransferSucceeded`, `TransferFailed`,
  `ExecutionFailed`, `FailedTransferClaimed` (`AcrossV3AdapterV2.sol:83-99`, `RelayAdapter.sol:106-122`,
  `StargateAdapter.sol:90-131` adds `guid`-indexed variants + decode-failure events).
- V2 error set: `ADDRESS_NOT_VALID`, `ACCOUNT_NOT_VALID`, `INSUFFICIENT_FAILED_BALANCE`, `ZERO_AMOUNT`,
  `ETH_TRANSFER_FAILED` (native), plus adapter-specific (`NO_DST_PROOF_FOR_CHAIN`, `INSUFFICIENT_FUNDS_RECEIVED`,
  `MSG_VALUE_NOT_ALLOWED`).

### ReentrancyGuard
- V1 (`AcrossV3Adapter`, `Debridge`): **no** ReentrancyGuard.
- V2 (`AcrossV3AdapterV2`, `RelayAdapter`, `StargateAdapter`): **inherit `ReentrancyGuard`** from
  `@openzeppelin/contracts/utils/ReentrancyGuard.sol` and mark `claimFailedTransfer` (and Relay's
  `processRelayExecution`) `nonReentrant` (`AcrossV3AdapterV2.sol:7,24,184`; `RelayAdapter.sol:7,35,156,222`;
  `StargateAdapter.sol:7,29,315`).

### SafeERC20 + non-standard token handling
- Straight `IERC20(token).safeTransfer(account, amount)` in V1 (`AcrossV3Adapter.sol:76`, `DebridgeAdapter.sol:111`).
- V2 adds a `_tryTransfer` internal that uses a **low-level `token.call(abi.encodeCall(IERC20.transfer, ...))`** so
  non-standard ERC20s (USDT) that don't return a bool don't revert the whole flow
  (`AcrossV3AdapterV2.sol:236-241`, `RelayAdapter.sol:280-289`, `StargateAdapter.sol:345-354`). USDC returns a bool
  so a plain `safeTransfer` is also fine, but reusing `_tryTransfer` keeps the best-effort semantics.

### `_handleMessageReceived` / `_decodeMessage` shape
- **Debridge** is the cleanest reference for the private-helper split: `_decodeMessage(bytes) →
  (initData, executorCalldata, account, dstTokens, intentAmounts, sigData)` via
  `abi.decode(message,(bytes,bytes,address,address[],uint256[],bytes))` (`DebridgeAdapter.sol:145-159`), and
  `_handleMessageReceived(tokenSent, ...)` that just forwards to the executor (`DebridgeAdapter.sol:122-143`).
- V2 adapters replace `_decodeMessage` with `_extractFromSigData` (§2).

---

## 2. The exact payload contract

### Source encoding — `CCTPSendHook` (`src/hooks/bridges/cctp/CCTPSendHook.sol`)
- Data layout is a fixed 52-byte strategy header + hook fields, documented at `CCTPSendHook.sol:32-43`. Relevant
  offsets: `burnToken@52`, `amount@72`, `destinationDomain@104`, `mintRecipient@108`, `destinationCaller@140`,
  `maxFee@172`, `minFinalityThreshold@204`, `usePrevHookAmount@208`, `hookCallData@209+`.
- The hook receives `hookCallData` pre-encoded as **5 fields**
  `abi.decode(hookCallData,(bytes,bytes,address,address[],uint256[]))` =
  `(initData, executorCalldata, account, dstTokens, intentAmounts)` (`CCTPSendHook.sol:150-156`).
- It fetches the destination signature from the validator's transient storage
  `ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)` (`CCTPSendHook.sol:148`) and **re-encodes to
  6 fields** appending the signature:
  `abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature)` (`CCTPSendHook.sol:158`).
  This 6-field blob is passed as CCTP `hookData` into
  `ITokenMessengerV2.depositForBurnWithHook(amount, destinationDomain, mintRecipient, burnToken, destinationCaller,
  maxFee, minFinalityThreshold, hookData)` (`CCTPSendHook.sol:168-181`; interface at
  `src/vendor/bridges/cctp/ITokenMessengerV2.sol:18-27`).

> **Therefore `CCTPAdapter` must decode the sliced `hookData` as the 6-field tuple**
> `(bytes initData, bytes executorCalldata, address account, address[] dstTokens, uint256[] intentAmounts,
> bytes signature)` — identical to Debridge/AcrossV1's `_decodeMessage`
> (`DebridgeAdapter.sol:157-158`, `AcrossV3Adapter.sol:63-70`). This is the **6-field V1 shape**, not the compact
> 2-field V2 shape — because the CCTP hook packs all fields into `hookData` rather than relying on `sigData`
> extraction. `signature` here is the raw `userSignatureData` passed as the 7th arg to `processBridgedExecution`.

### Consumption — `ISuperDestinationExecutor.processBridgedExecution`
Interface: `src/interfaces/ISuperDestinationExecutor.sol:108-117`. Arg order:
`(address tokenSent, address targetAccount, address[] dstTokens, uint256[] intentAmounts, bytes initData,
bytes executorCalldata, bytes userSignatureData)`.

Implementation: `src/executors/SuperDestinationExecutor.sol:94-144`. Key behaviors:
1. `tokenSent` (1st arg) is **ignored** in the impl (`function processBridgedExecution(address, ...)` —
   `SuperDestinationExecutor.sol:95`). Balance is checked on-chain against `dstTokens`/`intentAmounts`.
2. `dstTokens.length == intentAmounts.length` else `revert ARRAY_LENGTH_MISMATCH` (`:107`).
3. `_validateOrCreateAccount(account, initData)` — creates the account from initData if code-less
   (`:109,164-171,216-226`).
4. Signature validation: builds
   `destinationData = abi.encode(executorCalldata, uint64(block.chainid), account, address(this), dstTokens,
   intentAmounts)` (`:115-116`) and calls
   `ISuperDestinationValidator.isValidDestinationSignature(account, abi.encode(userSignatureData, destinationData))`;
   must equal magic `0x5c2ec0f3` else `revert INVALID_SIGNATURE` (`:40,119-123`).
5. **Funds must be pre-transferred to the account.** `_validateBalances(account, dstTokens, intentAmounts)` reads
   `IERC20(_token).balanceOf(account)` (`:180-214`); if any balance `< intentAmount` it **emits
   `SuperDestinationExecutorReceivedButNotEnoughBalance` and `return`s (no revert)** (`:125,199-209`). Zero
   `intentAmount` → emits `SuperDestinationExecutorInvalidIntentAmount` and returns (`:193-195`).
6. Replay: if `usedMerkleRoots[account][merkleRoot]` → emit `...RootUsedAlready` and return (no revert) (`:127-130`);
   otherwise marks used (`:132`). Root is decoded from `userSignatureData` field 4 via
   `_decodeMerkleRoot` = `abi.decode(sig,(uint64[],uint48,uint48,bytes32,bytes32[],DstProof[],bytes))` (`:173-178`).
7. Empty-hooks guard: `_shouldSkipCalldata` (selector != `execute` or length ≤ `EMPTY_EXECUTION_LENGTH`=228) → emit
   `SuperDestinationExecutorReceivedButNoHooks` and return (`:134-137,158-162`).
8. Success path: wraps `executorCalldata` in a single self-`Execution`, calls `_execute`, emits
   `SuperDestinationExecutorExecuted` (`:139-143`).

> **Non-reverting design:** insufficient balance / used root / no hooks all emit-and-return. This is exactly why the
> V2 adapters wrap the call in `try/catch` only to catch the *signature-revert* path (`INVALID_SIGNATURE`,
> `ARRAY_LENGTH_MISMATCH`, `ACCOUNT_NOT_CREATED`) — the funds must already be at the account before the call so the
> balance check passes. `CCTPAdapter` MUST transfer minted USDC to `account` **before** calling
> `processBridgedExecution`, matching every existing adapter.

---

## 3. Vendor interface conventions

- CCTP interfaces live at `src/vendor/bridges/cctp/`. Currently only `ITokenMessengerV2.sol` (source/burn side).
  A new **`IMessageTransmitterV2.sol`** (destination/mint side) belongs in this same folder.
- Vendor interface style (see `ITokenMessengerV2.sol:1-28`, `IAcrossV3Receiver.sol:1-27`,
  `src/vendor/bridges/debridge/IExternalCallExecutor.sol`, `src/vendor/bridges/stargate/*`):
  - SPDX header — **mixed in repo**: `ITokenMessengerV2.sol` uses `Apache-2.0`; `IAcrossV3Receiver.sol:1` uses
    `UNLICENSED`. Recommend `Apache-2.0` to match the sibling CCTP file.
  - `pragma solidity 0.8.30;` for repo-authored vendor interfaces (`ITokenMessengerV2.sol:2`,
    `IAcrossV3Receiver.sol:2`). (The pigeon copy uses `>=0.8.0`.)
  - Rich `@notice`/`@param`/`@return` NatSpec per function; link to `https://developers.circle.com/cctp`.
- **Reference implementation already in-repo (do not import, but mirror the signature):**
  `lib/pigeon/src/cctp/interfaces/IMessageTransmitterV2.sol:6-27` defines
  `receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool);` plus
  `attesterManager()`, `enableAttester`, `isEnabledAttester`, etc. The adapter only needs `receiveMessage`; keep the
  vendor interface minimal (just `receiveMessage`, optionally `usedNonces`) to match `ITokenMessengerV2`'s minimalism.
- The canonical **MessageTransmitterV2 address** (same on all mainnet EVM chains via CREATE2) is
  `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64` (`lib/pigeon/src/cctp/CctpV2Helper.sol:15`). The TokenMessengerV2
  address `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` is already a repo constant
  (`script/utils/Constants.sol:334-335`, `CCTP_V2_TOKEN_MESSENGER`). A matching `CCTP_V2_MESSAGE_TRANSMITTER`
  constant does **not yet exist** and must be added.

---

## 4. Deployment wiring (`script/DeployV2Core.s.sol`)

### How adapters are declared
- Deployed-address struct fields: `acrossV3AdapterV2`, `relayAdapter`, `debridgeAdapter`, `stargateAdapter`,
  `stargateAdapterV2` (`DeployV2Core.s.sol:28-32`).
- Availability booleans mirror them (`:279-283`) plus `uint256 expectedAdapters` (`:303`).
- Adapter name list + counting: `adapterContracts = ["AcrossV3AdapterV2","RelayAdapter","DebridgeAdapter",
  "StargateAdapter","StargateAdapterV2"]` (`:353-358`), decremented per unavailable chain (`:360-397`).

### Per-chain config addresses (`configuration.*`)
Config is a big struct of `mapping(uint64 chainId => address)` in `script/utils/ConfigBase.sol:15-45`:
`acrossSpokePoolV3s` (`:17`), `relayDepositories` (`:18`), `debridgeDstDln` (`:20`), `lzEndpointV2s` (`:40`), etc.
Populated per chain in `script/utils/ConfigCore.sol` (e.g. `acrossSpokePoolV3s` `:19-35`, `relayDepositories`
`:41-57`, `debridgeDstDln` `:79+`). **There is no `messageTransmitterV2s` mapping yet** — but note CCTP uses the same
address on all EVM chains, so a single `Constants.sol` constant (like `CCTP_V2_TOKEN_MESSENGER`) is the established
pattern rather than a per-chain mapping.

### Availability gating pattern (copy for CCTP)
Each adapter gates on its config address being non-zero, e.g. AcrossV3AdapterV2:
`if (configuration.acrossSpokePoolV3s[chainId] != address(0)) { availability.acrossV3AdapterV2 = true; } else {
expectedAdapters -= 1; potentialSkips[...] = "AcrossV3AdapterV2"; }` (`:360-397`). Stargate requires **two** addresses
(`lzEndpointV2s` && `tokenMessaging`) (`:384-396`). RelayAdapter keys on `relayDepositories` even though its
constructor only takes the executor (`:368-373`).

> For CCTP: since MessageTransmitterV2 is a fixed constant present on every supported chain, availability is
> effectively always-true (like a core contract) — or gate on a new per-chain `cctpMessageTransmitters` mapping if
> you want per-chain opt-out. Simplest: mirror `CCTP_V2_TOKEN_MESSENGER` with a `CCTP_V2_MESSAGE_TRANSMITTER`
> constant and treat availability as unconditional.

### Deploy / check / validate blocks (three places to add CCTP wiring)
1. **Deploy** (CREATE2 via `__deployContractIfNeeded`): RelayAdapter is the closest template —
   `RELAY_ADAPTER_KEY`, salt, `abi.encodePacked(__getBytecode("RelayAdapter", env),
   abi.encode(coreContracts.superDestinationExecutor))`, then post-deploy `require(... SUPER_DESTINATION_EXECUTOR()
   == ...)` (`:2958-2982`). AcrossV3AdapterV2 shows the 2-arg constructor packing
   (`:872-882`, `abi.encode(spokePool, superDestinationExecutor)`).
2. **Check** (`_checkAdapterContracts`, `:1752-1834`): each adapter calls
   `__checkContract(KEY, __getSalt(KEY), abi.encode(<ctor args>), env)` with a SKIPPED log branch. Relay:
   `__checkContract(RELAY_ADAPTER_KEY, __getSalt(RELAY_ADAPTER_KEY), abi.encode(superDestExecutor), env)` (`:1830`).
3. **Contract-key constants** live in `script/utils/Constants.sol:34-38` (`RELAY_ADAPTER_KEY`,
   `STARGATE_ADAPTER_KEY`, etc.). Add `CCTP_ADAPTER_KEY = "CCTPAdapter"` there. CCTP hook keys already exist at
   `Constants.sol:330-332`.

### Locked-bytecode + manifest + hook-sizing — adapters are NOT hooks
- **Confirmed: adapters do NOT appear in `hook-sizing-manifest.json`.** That manifest is keyed by `hookKey` and
  contains only hooks (`grep -i adapter hook-sizing-manifest.json` → no matches; 136 `hookKey` entries; CCTP entries
  present as `CCTP_SEND_HOOK_KEY`/`APPROVE_AND_CCTP_SEND_HOOK_KEY`). The hook-sizing/amount-replacement machinery
  (`tooling/generate-hook-sizing-manifest.ts`, `_supportsSizingInterface`) is a **hook-only** concern — an adapter
  implements no `ISuperHookInflowOutflow`, so it is correctly absent.
- Adapters **do** participate in the **locked-bytecode / deterministic-CREATE2** system: they get a
  `<Name>.json` bytecode artifact under `script/generated-bytecode/`, `script/locked-bytecode/`, and
  `script/locked-bytecode-dev/` (same treatment the PendlePTHook change in the current branch shows), are fetched via
  `__getBytecode("CCTPAdapter", env)` / `__checkBytecodeExists(...)`, deployed by CREATE2 salt, and surface only in
  the deployment output JSON (via `_getContractStatus` / `coreContracts.*`, e.g. `:2698-2699` for Relay). So:
  **CCTPAdapter needs a locked-bytecode artifact + Constants key + DeployV2Core deploy/check/validate wiring, but no
  hook-sizing-manifest entry.**

---

## 5. Test conventions for adapters

### Locations
- Unit: `test/unit/adapters/` — `AdaptersUnitTests.sol`, `RelayAdapterUnitTests.t.sol`.
- Integration/fork: `test/integration/across/AcrossV3AdapterV2E2EFork.t.sol`,
  `test/integration/relay/RelayAdapterE2EFork.t.sol`,
  `test/integration/stargate/StargateAdapter*Fork.t.sol`.
- CCTP existing: `test/unit/hooks/bridges/CCTPHooks.t.sol`, `test/integration/cctp/CCTPHooksFork.t.sol` (these test
  the *send* hook, not a destination adapter — new adapter tests go in `test/integration/cctp/`).

### Fork-test skeleton (copy `RelayAdapterE2EFork.t.sol`)
- `pragma solidity 0.8.30;`, SPDX `MIT` for tests (`RelayAdapterE2EFork.t.sol:1`,
  `AcrossV3AdapterV2E2EFork.t.sol` header, `CCTPHooksFork.t.sol:1`).
- Inherit `MerkleTreeHelper` (which extends `Helpers`) — `RelayAdapterE2EFork.t.sol:17`,
  `AcrossV3AdapterV2E2EFork.t.sol:19`.
- Hardcode real chain constants: `USDC_BASE = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`, deployed
  `SUPER_DST_EXECUTOR_BASE = 0x6ac58e854798D4aae5989B18ad5a1C0fF17817EF`
  (`RelayAdapterE2EFork.t.sol:23,26`).
- `setUp`: `vm.createFork(vm.envString(BASE_RPC_URL_KEY))`, deploy a **local** adapter against the on-chain deployed
  executor, `vm.label(...)` (`RelayAdapterE2EFork.t.sol:41-49`).
- Simulate delivery with `deal(USDC_BASE, address(adapter), amount)` then call the adapter
  (`RelayAdapterE2EFork.t.sol:57-68`).

### Attester / mock patterns for CCTP specifically
- **Pigeon `CctpV2Helper`** (`lib/pigeon/src/cctp/CctpV2Helper.sol`, imported in `CCTPHooksFork.t.sol:16` as
  `@pigeon/cctp/CctpV2Helper.sol`) is the canonical CCTP test tool:
  - Constructor takes a test attester PK (default key `0x1`) (`:30-33`).
  - `_setupTestAttester()` replaces production attesters via `attesterManager()`/`enableAttester`
    (`:107-120`); signs the message with the test key `_signMessage → abi.encodePacked(r,s,v)` (`:122-128`).
  - `help(destDomain, forkId, logs)` scans `MessageSent(bytes)` logs, patches `finalityThresholdExecuted`, and calls
    `IMessageTransmitterV2(0x81D4...).receiveMessage(message, attestation)`, pranking `destinationCaller` when set
    (`:46-104`). MessageTransmitterV2 addr `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64` (`:15`).
  - So an end-to-end `CCTPAdapter` fork test can: run the send hook to emit `MessageSent`, then drive the mint on the
    destination fork through the adapter's `receiveAndExecute` (adapter is `destinationCaller`), using this helper's
    attestation signing.
- **Mock signature storage:** `CCTPHooksFork.t.sol:18-29` (`MockCCTPForkSignatureStorage.retrieveSignatureData`)
  returns an `abi.encode(uint64[], validUntil, 0, merkleRoot, proofSrc, DstProof[], signature)` blob — the exact
  `SignatureData` shape the executor decodes.

### How `SuperDestinationValidator` signatures are produced in tests
- Real signing lives in unit tests: `test/unit/validators/SuperDestinationValidator.t.sol`. Pattern:
  build leaves with `_createDestinationValidatorLeaf(...)` (`:198-228`), build merkle root, then
  `destinationDataRaw = abi.encode(callData, chainId, sender, executor, dstTokens, intentAmounts)`
  (`:441-444`, mirrors `SuperDestinationExecutor.sol:115-116`), hash with
  `MessageHashUtils.toEthSignedMessageHash`, `(v,r,s) = vm.sign(privateKey, hash)`,
  `signature = abi.encodePacked(r,s,v)` (`:408-410`), then
  `validator.isValidDestinationSignature(signer, abi.encode(sigDataRaw, destinationDataRaw))` (`:398`).
  Helper `_createDestinationValidatorLeaf` / `_createValidatorMerkleTree` are in
  `test/utils/MerkleTreeHelper.sol:59,91`.
- **Adapter fork tests deliberately use dummy signatures.** They assert the fund-forwarding path works and that the
  executor rejects the fake proof, verifying the try/catch: e.g. `RelayAdapterE2EFork.t.sol:71-92` builds a message
  with `hex"deadbeef"` calldata and asserts `ExecutionFailed(address)` is emitted while the USDC still reaches the
  account. `_assertEventEmitted(logs, "ExecutionFailed(address)")` is the idiom. This is the recommended coverage
  level for the adapter's own tests — full valid-signature E2E belongs in a higher-level flow test.

---

## 6. Naming / style conventions to match

- SPDX: adapters/interfaces `Apache-2.0`; hooks `Apache-2.0`; tests `MIT`.
- `pragma solidity 0.8.30;` everywhere (repo pins exact — `foundry.toml`, CLAUDE.md).
- `@title` + `@author Superform Labs` on every contract.
- Section banner comments: `/*////...//// STORAGE ////...////*/` (STORAGE, STRUCTS, ERRORS, EVENTS, CONSTRUCTOR,
  and logic-section banners).
- **Custom errors only**, SCREAMING_SNAKE_CASE: `ADDRESS_NOT_VALID`, `INVALID_SENDER`, `ACCOUNT_NOT_VALID`,
  `ZERO_AMOUNT`, `INSUFFICIENT_FAILED_BALANCE`, `ETH_TRANSFER_FAILED`. No revert strings in contracts (deploy
  scripts do use `require("STRING")`).
- Immutables SCREAMING_SNAKE_CASE: `SUPER_DESTINATION_EXECUTOR`, `ACROSS_SPOKE_POOL`, `TOKEN_MESSENGER`.
- Events PascalCase with indexed `account`/`token`: `TransferSucceeded`, `TransferFailed`, `ExecutionFailed`,
  `FailedTransferClaimed`.
- NatSpec `@notice`/`@dev`/`@param`/`@return` on all external/public functions and the contract header (extensive
  `@dev` trust-assumption blocks in V2 adapters — see `RelayAdapter.sol:15-34`, `StargateAdapter.sol:17-28`).
- Checks-Effects-Interactions; state before external calls; returnbomb-safe `catch { }` (no bound variable).
- CLAUDE.md hard rule: **hook features must be planned by `superform-hook-master` first.** An *adapter* is not a hook
  (no `BaseHook`, not in hook-sizing-manifest), so this gate is about the CCTP *send hook*, not this destination
  adapter — but the plan-first workflow (`.claude/sessions/context_session_x.md`) still applies.

---

## Concrete recommendations for `CCTPAdapter`

1. **File:** `src/adapters/CCTPAdapter.sol`, SPDX `Apache-2.0`, pragma `0.8.30`, `is ReentrancyGuard` (V2 tier).
2. **Constructor:** `(address messageTransmitterV2_, address superDestinationExecutor_)`, both zero-checked with
   `ADDRESS_NOT_VALID`. Store as immutables `MESSAGE_TRANSMITTER`, `SUPER_DESTINATION_EXECUTOR`.
3. **Vendor interface:** add `src/vendor/bridges/cctp/IMessageTransmitterV2.sol` with (minimally)
   `receiveMessage(bytes,bytes) returns (bool)`, mirroring `ITokenMessengerV2.sol` style. Mirror pigeon's signature
   at `lib/pigeon/src/cctp/interfaces/IMessageTransmitterV2.sol:8`.
4. **`receiveAndExecute(bytes message, bytes attestation)`** (permissionless, Relay-style): snapshot USDC balance →
   `MESSAGE_TRANSMITTER.receiveMessage(message, attestation)` (mints to adapter; CCTP enforces `destinationCaller` =
   adapter) → compute minted `amount` (post-pre balance) → slice `hookData` from the BurnMessageV2 body →
   `abi.decode(hookData,(bytes,bytes,address,address[],uint256[],bytes))` (6-field, §2) → `_tryTransfer` USDC to
   `account` (emit `TransferSucceeded`/`TransferFailed` + escrow) → `try SUPER_DESTINATION_EXECUTOR
   .processBridgedExecution(USDC, account, dstTokens, intentAmounts, initData, executorCalldata, signature) { }
   catch { emit ExecutionFailed(account); }`.
5. **Reuse V2 boilerplate verbatim:** `failedTransfers` mapping, `claimFailedTransfer(token, amount) nonReentrant`,
   `_tryTransfer` low-level-call helper, the standard event/error set. USDC-only means the native-ETH branches of
   `RelayAdapter`/`StargateAdapter` can be dropped.
6. **Deployment:** add `CCTP_ADAPTER_KEY = "CCTPAdapter"` + `CCTP_V2_MESSAGE_TRANSMITTER =
   0x81D40F21F12A8F0E3252Bccb954D722d4c464B64` to `script/utils/Constants.sol`; wire deploy/check/validate in
   `DeployV2Core.s.sol` mirroring the RelayAdapter blocks (`:1828-1834`, `:2958-2982`); generate a locked-bytecode
   artifact. **Do not** add to `hook-sizing-manifest.json`.
7. **Tests:** `test/integration/cctp/CCTPAdapterE2EFork.t.sol` inheriting `MerkleTreeHelper`, using
   `@pigeon/cctp/CctpV2Helper.sol` for attestation signing and a dummy-signature `ExecutionFailed` assertion for the
   fund-forwarding path.
