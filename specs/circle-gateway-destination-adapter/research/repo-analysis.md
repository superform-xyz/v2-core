# Research: Repository Analysis — `src/adapters/CircleGatewayAdapter.sol`

Source: repo-research-analyst agent, 2026-09-23. Everything below was read directly from the repo at the paths cited.

One correction to the brief up front: the **default profile does not enable `via_ir`** — `foundry.toml:69 via_ir = true` sits under `[profile.coverage]` (lines 62-69), and `[profile.default]` (lines 3-55) only sets `optimizer = true`, `optimizer_runs = 200`, `solc = "0.8.30"`, `evm_version = "prague"`. Stack-too-deep is therefore a real risk for a function that holds many `bytes29` views plus the CCTP-style locals; see Gotchas.

---

## 1. The template: `src/adapters/CCTPAdapter.sol` (696 lines)

Section map, with what is CCTP-specific vs. what carries over:

| Lines | Section | CCTP-specific? |
|---|---|---|
| 1-15 | Header, imports (`IERC20`, `SafeERC20`, `ReentrancyGuard`, vendor `IMessageTransmitterV2`/`ITokenMinterV2`, `ISuperDestinationExecutor`, `ISuperValidator`) | vendor imports are CCTP; rest verbatim |
| 17-22 | `interface IDestinationValidatorSource { function SUPER_DESTINATION_VALIDATOR() external view returns (address); }` — declared **file-level, local on purpose** | verbatim (redeclare locally; do not import from CCTPAdapter.sol) |
| 24-30 | `ITokenMessengerV2MinterSource` (`localMinter()`, `localMessageTransmitter()`) | CCTP only — drop; replace with a local `IGatewayMinter` view interface (`gatewayMint`, `domain`, `isTokenSupported`, `isDenylisted`, `paused`, `isTransferSpecHashUsed`) |
| 32-58 | Contract NatSpec: pull-driven rationale, PERMISSIONLESS safety anchors (1-3), donation-proof delta, multi-token model | adapt wording; structure verbatim |
| 66-82 | Wire offsets `BURN_TOKEN_OFFSET=152 … HOOKDATA_OFFSET=376` | CCTP — replace with Attestation/TransferSpec absolute offsets (table in §3) |
| 84-123 | `SUPPORTED_MESSAGE_VERSION=1`, `BODY_VERSION_OFFSET=148`, `DESTINATION_CALLER_OFFSET=108`, `SOURCE_DOMAIN_OFFSET=4`, `RECIPIENT_OFFSET=76` (the "recipient pin"), `MESSAGE_SENDER_OFFSET=248`, `SUPPORTED_BODY_VERSION=1` | CCTP — Gateway equivalents: `ATTESTATION_MAGIC`, `TRANSFER_SPEC_MAGIC`, `TRANSFER_SPEC_VERSION=1`, `destinationContract == GATEWAY_MINTER` (the analogue of the recipient pin), `sourceDepositor` (analogue of `messageSender`) |
| 125-148 | `MIN_EXECUTION_GAS = 2_000_000` with the full floor-not-stipend / EIP-150 / review-I1 rationale | verbatim |
| 150-155 | `MISCONFIG_UNPINNED = 1`, `MISCONFIG_MINT_ELSEWHERE = 2` | verbatim |
| 157-163 | `MATCH_OK = 0`, `MISMATCH_EXECUTOR = 1`, `MISMATCH_VALIDATOR = 2` | verbatim |
| 165-179 | `struct HookPayload { bytes initData; bytes executorCalldata; address account; address[] dstTokens; uint256[] intentAmounts; bytes sigData; }` | verbatim |
| 185-204 | Storage: `MESSAGE_TRANSMITTER`, `USDC`, `TOKEN_MESSENGER`, `SUPER_DESTINATION_EXECUTOR`, `SUPER_DESTINATION_VALIDATOR` (all `immutable`), `failedTransfers` mapping | replace first three with `GATEWAY_MINTER`, `USDC`; keep executor/validator/mapping verbatim |
| 210-264 | Errors | keep `ADDRESS_NOT_VALID`, `ZERO_AMOUNT`, `INSUFFICIENT_FAILED_BALANCE`, `DESTINATION_CALLER_MISMATCH`, `NOTHING_MINTED`, `INVALID_SENDER`, `INSUFFICIENT_GAS`; new: `GATEWAY_MINTER_NOT_VALID`, `PAYLOAD_TOO_SHORT`, `ATTESTATION_SET_NOT_SUPPORTED`, `INVALID_ATTESTATION_MAGIC`, `INVALID_TRANSFER_SPEC_MAGIC`, `UNSUPPORTED_TRANSFER_SPEC_VERSION`, `PAYLOAD_LENGTH_MISMATCH`, `DESTINATION_CONTRACT_MISMATCH`, `DESTINATION_DOMAIN_MISMATCH`, `DESTINATION_RECIPIENT_MISMATCH`; `RECEIVE_MESSAGE_FAILED` has no analogue (`gatewayMint` returns nothing; it reverts on failure) |
| 270-325 | Events: `TransferSucceeded`, `TransferFailed` (fires on EVERY escrow credit), `ExecutionFailed(account, bytes4 selector)`, `HookPayloadUndecodable`, `DestinationTargetMismatch(account, uint8 code)`, `NonUsdcMintEscrowed`, `MisconfiguredMessageRelayed(uint8 indexed kind, bytes32 mintRecipient)`, `FailedTransferClaimed` | verbatim; rename the `messageSender` param to `sourceDepositor` |
| 331-360 | Constructor: zero-checks; wired-deployment sanity; assigns immutables; caches `SUPER_DESTINATION_VALIDATOR` via `IDestinationValidatorSource` | copy shape; Gateway sanity = `gatewayMinter_.code.length != 0`, `IGatewayMinter(gatewayMinter_).isTokenSupported(usdc_)` (Ethereum `domain() == 0` is valid — do not require non-zero) |
| 374-555 | `receiveAndExecute(bytes calldata message, bytes calldata attestation) external nonReentrant` — step ordering below | adapt |
| 557-566 | `decodeHookPayload(bytes calldata message) external view` — self-call guard, `abi.decode(message[HOOKDATA_OFFSET:], (bytes, bytes, address, address[], uint256[], bytes))` | verbatim with `HOOKDATA_OFFSET = 380` |
| 568-594 | `checkDestinationTargets(bytes calldata sigData) external view returns (uint8 code)` | verbatim |
| 600-613 | `claimFailedTransfer(address token, uint256 amount) external nonReentrant` | verbatim (selector matches `ClaimFailedTransferHook`) |
| 619-638 | `_resolveLocalToken` (TokenMinterV2 registry lookup) | CCTP only — drop. Gateway's `destinationToken` is the LOCAL address in the spec (absolute offset 152) |
| 640-670 | `_receiveNonUsdc(...)` | adapt: `_mintNonUsdc(payload, signature, token, sourceDepositor)` calling `gatewayMint` |
| 672-694 | `_tryTransfer` + `_isTrueWord` | verbatim |

**`receiveAndExecute` step ordering (:374-555), with the F1/F2 block:**

1. `:376-380` fail-fast: length; header version; body version.
2. `:381-411` F1/F2 block, scoped `{}`: `selfWord`; `destinationCaller != selfWord && != 0 → DESTINATION_CALLER_MISMATCH` (zero ACCEPTED); recipient pin; `mintRecipient != selfWord` → if `destinationCaller != selfWord → MINT_RECIPIENT_MISMATCH` else **pass-through** (`receiveMessage`, `MisconfiguredMessageRelayed(2)`, return); `if (destinationCaller == 0) emit MisconfiguredMessageRelayed(1)`.
3. `:414-415` read `messageSender` from the FIXED body.
4. `:421-425` `_resolveLocalToken`; `!= USDC → _receiveNonUsdc; return`.
5. `:429-431` `pre`; `receiveMessage`; `minted = post - pre`.
6. `:436-449` `claimed = amount - feeExecuted`; clamp; surplus.
7. `:455` `minted == 0 → NOTHING_MINTED`.
8. `:463-470` `try this.decodeHookPayload(message)`.
9. `:475-484` `!decoded || account == 0 || account == this` → escrow to `messageSender` (`TransferFailed` + `HookPayloadUndecodable`), return.
10. `:489-492` surplus credited to `account`.
11. `:506-515` `try this.checkDestinationTargets(p.sigData)` → `targetsMatch` / `DestinationTargetMismatch`.
12. `:518-523` `_tryTransfer(account, minted)` → `TransferSucceeded` or escrow.
13. `:534` `if (!targetsMatch) return;`
14. `:536` gas floor.
15. `:541-554` `try processBridgedExecution(...) {} catch { bytes4 selector; assembly ("memory-safe") { if gt(returndatasize(), 3) { mstore(0, 0) returndatacopy(0, 0, 4) selector := mload(0) } } emit ExecutionFailed(account, selector); }` — copy byte-for-byte.

For Gateway: step 5 becomes `GATEWAY_MINTER.gatewayMint(payload, signature)` (no bool); step 6 becomes `claimed = spec.value` (Gateway mints exactly `value`, no destination fee — `Mints.sol:340-343,349`); step 4's token comes from `destinationToken@152`.

---

## 2. `src/hooks/bridges/circle/CircleGatewayMinterHook.sol` (297 lines)

- Imports (`:22-24`) use **relative** paths to `lib/evm-gateway-contracts/src/lib/{TransferSpecLib,AttestationLib,AddressLib}.sol`. From `src/adapters/` that is `../../lib/evm-gateway-contracts/src/lib/...`. The `evm-gateway/=lib/evm-gateway-contracts/src/` remapping (`foundry.toml:49`) is equivalent (used by `test/integration/circle/CrosschainTestsGateway.t.sol:31-32`). The libs' own imports resolve through the context remapping (`foundry.toml:50`); `@memview-sol/` and `@openzeppelin/contracts-upgradeable/` come from the submodule's `remappings.txt` (`@memview-sol/=lib/evm-gateway-contracts/lib/memview-sol/contracts/`).
- `interface IGatewayMinter { function gatewayMint(bytes memory, bytes memory) external; }` at file level (`:26-28`). Do not modify this file; declare your own (richer) interface in the adapter, or add `src/vendor/bridges/circle/IGatewayMinter.sol` (precedent: `ITokenMinterV2.sol` added new in CCTP Round 4 rather than touching a vendored file).
- `using TransferSpecLib for bytes29; using AttestationLib for bytes29; using AttestationLib for Cursor;` (`:41-43`).
- Parsing pattern (`:238-266`, `:268-295`): `Cursor memory cursor = AttestationLib.cursor(payload)`, `while (!cursor.done) { attestation = cursor.next(); bytes29 spec = attestation.getTransferSpec(); ... }`, addresses via `AddressLib._bytes32ToAddress`.
- `inspect()` returns `abi.encodePacked(token)` (all specs in a set must agree, else `DESTINATION_TOKENS_DIFFER`).
- `_validateDestinationCaller` accepts `destinationCaller == account || == address(0)` — the same "0 accepted" rule.
- `decodeAmounts` returns empty ("Sizeless — amount is inside a cryptographically-signed attestation blob").

---

## 3. `lib/evm-gateway-contracts/src/lib/*` (submodule at `569d7cef`, 2025-07-21; `pragma ^0.8.29`; `TypedMemView >=0.8.12`)

**All libs are `library` with `internal` functions only** — they inline; no linking; safe under 0.8.30 and either optimizer pipeline. The hook already compiles with them in the default profile.

**Constants (`Attestations.sol:23-35`):**
```
ATTESTATION_MAGIC      = 0xff6fb334   // bytes4(keccak256("circle.gateway.Attestation"))
ATTESTATION_SET_MAGIC  = 0x1e12db71   // bytes4(keccak256("circle.gateway.AttestationSet"))
ATTESTATION_MAGIC_OFFSET = 0 | ATTESTATION_MAX_BLOCK_HEIGHT_OFFSET = 4 | ATTESTATION_TRANSFER_SPEC_LENGTH_OFFSET = 36 | ATTESTATION_TRANSFER_SPEC_OFFSET = 40
ATTESTATION_SET_NUM_ATTESTATIONS_OFFSET = 4 | ATTESTATION_SET_ATTESTATIONS_OFFSET = 8
```
**`TransferSpec.sol:21-42`:** `TRANSFER_SPEC_MAGIC = 0xca85def7`, `TRANSFER_SPEC_VERSION = 1`, offsets (relative to spec start): magic 0, version 4, sourceDomain 8, destinationDomain 12, sourceContract 16, destinationContract 48, sourceToken 80, destinationToken 112, sourceDepositor 144, destinationRecipient 176, sourceSigner 208, destinationCaller 240, value 272, salt 304, hookDataLength 336 (uint32), hookData 340. `TRANSFER_SPEC_TYPEHASH` at `:86`.

**Absolute offsets inside a single encoded `Attestation` (= 40 + spec offset):**

| Field | Abs offset | Size |
|---|---|---|
| attestation magic | 0 | 4 |
| maxBlockHeight | 4 | 32 |
| specLength (uint32) | 36 | 4 |
| spec magic | 40 | 4 |
| version | 44 | 4 |
| sourceDomain | 48 | 4 |
| destinationDomain | 52 | 4 |
| sourceContract | 56 | 32 |
| destinationContract | 88 | 32 |
| sourceToken | 120 | 32 |
| destinationToken | 152 | 32 |
| sourceDepositor | 184 | 32 |
| destinationRecipient | 216 | 32 |
| sourceSigner | 248 | 32 |
| destinationCaller | 280 | 32 |
| value | 312 | 32 |
| salt | 344 | 32 |
| hookDataLength (uint32) | 376 | 4 |
| hookData | 380 | variable |

Structural invariants the minter enforces (checkable with plain calldata arithmetic): `payload.length == 40 + specLength` (`AttestationLib.sol:104-110`) and `specLength == 340 + hookDataLength` (`TransferSpecLib.sol:219-223`) → `payload[380:]` is exactly `hookData`.

**Validation functions and reverts:** `_asAttestationOrSetView` (`:65-80`): `len < 4 → TransferPayloadDataTooShort`; bad magic → `InvalidTransferPayloadMagic`. `_validateAttestationOuterStructure` (`:95-111`): `len < 40 → TransferPayloadHeaderTooShort`; `len != 40 + specLen → TransferPayloadOverallLengthMismatch`. `_validateAttestation` (`:126-131`). `_validateAttestationSet` (`:150-202`). `_validate(bytes memory) returns (bytes29)` (`:212-220`); `cursor(bytes memory)` (`:233-249`, `numElements = 1` for a single attestation); `next(Cursor)` (`:258-278`, `CursorOutOfBounds`). Accessors (`:286-322`): `getMaxBlockHeight`, `getTransferSpecLength`, `getTransferSpec` (slices at 40, re-checks `TRANSFER_SPEC_MAGIC`), `getNumAttestations`. `TransferSpecLib._validateTransferSpecStructure` (`:205-224`): `len < 340 → TransferSpecHeaderTooShort`; `version != 1 → InvalidTransferSpecVersion`; `len != 340 + hookDataLen → TransferSpecOverallLengthMismatch`. Field getters (`:232-338`). **`getHookData(bytes29) returns (bytes29)`** (`:344-362`) — a memview slice, NOT `bytes memory`; `TypedMemView.clone(view)` or a calldata slice to `abi.decode`. **`getHash(bytes29)`** (`:465-467`) = `keccak256(encoded TransferSpec bytes)` — the replay key. Encoders: `encodeTransferSpec` (`:372-387`), `AttestationLib.encodeAttestation` (`:330-339`) = `abi.encodePacked(ATTESTATION_MAGIC, maxBlockHeight, uint32(specBytes.length), specBytes)`; `encodeAttestationSet` (`:345-386`). `AddressLib._bytes32ToAddress = address(uint160(uint256(b)))` (silently truncates the top 12 bytes). `Cursor` (`Cursor.sol:23-34`). TypedMemView: `index()` REVERTS on overrun; `slice()` returns `NULL` on overrun; `clone` (`:695`).

---

## 4. `GatewayMinter` / `Mints.sol` and the common modules

`GatewayMinter is GatewayCommon, Mints`; `GatewayCommon is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable, Pausing, Denylist, TokenSupport, TransferSpecHashes, Domain`. UUPS proxy at `0x2222222d7164433c4C09B0b0D809a9b52C04C205` (`script/utils/Constants.sol:184`).

**`gatewayMint(bytes memory attestationPayload, bytes memory signature) external whenNotPaused notDenylisted(msg.sender)`** (`Mints.sol:255-287`), checks in order:
1. `whenNotPaused` → `EnforcedPause()`.
2. `notDenylisted(msg.sender)` → `AccountDenylisted(addr)`. **The adapter is `msg.sender`.**
3. `_verifyAttestationSignature`: `ECDSA.recover(keccak256(attestation).toEthSignedMessageHash(), signature)`; `!isAttestationSigner(recovered) → InvalidAttestationSigner()`.
4. `AttestationLib.cursor(payload)` → structural reverts.
5. `numElements == 0 → MustHaveAtLeastOneAttestation()`.
6. Per attestation: `maxBlockHeight < block.number → AttestationExpiredAtIndex`.
7. `getTransferSpec()` → `InvalidTransferSpecMagic`.
8. `_validateAttestationTransferSpec` (`:284-327`): `value == 0`; recipient not denylisted; `destinationCaller != 0 && != msg.sender → InvalidAttestationDestinationCallerAtIndex`; domain; `destinationContract != address(this)`; `!isTokenSupported(destinationToken)`; same-domain token equality.
9. `_mint(spec)` (`:333-353`): `_checkAndMarkTransferSpecHash(spec.getHash())` → `TransferSpecHashUsed(hash)`; `minter = tokenMintAuthority(token) == 0 ? token : authority; IMintableToken(minter).mint(recipient, value)` — **return bool ignored**; FiatToken reverts on its own failure paths. `emit AttestationUsed(token, recipient, specHash, sourceDomain, depositorBytes, signerBytes, value)`.

All address comparisons in the minter go through `AddressLib._bytes32ToAddress` (truncating).

**Public view surface:** `isAttestationSigner(address)`, `tokenMintAuthority(address)`, `domain() → uint32`, `isTokenSupported(address)`, `isDenylisted(address)`, `denylister()`, `pauser()`, `paused()`, `isTransferSpecHashUsed(bytes32)`, `owner()`. Admin (`onlyOwner`): `addAttestationSigner`, `removeAttestationSigner`, `updateMintAuthority`, `addSupportedToken` (irreversible), `updatePauser`, `updateDenylister`; `denylist/unDenylist` `onlyDenylister`; `pause/unpause` `onlyPauser`.

**Live state (2026-09-23 `cast call`):**

| | Base | Ethereum |
|---|---|---|
| `domain()` | 6 | **0** |
| `isTokenSupported(USDC)` | true | true |
| `paused()` | false | false |
| `owner()` | `0xF1237f985D146D8AeC106c742Ec6D8C4A98bB788` | `0x3c54FFa14d01EF3A555106007A4fED6E8964aAB6` |
| `tokenMintAuthority(USDC)` | 0 (mints via `FiatToken.mint` directly) | 0 |
| `denylister()` | `0x082CBeca612d6Eee6130E9e07A5C044Fa48bb3F9` | `0x7e575bC81e8a4A57f841512fbE72ed4C9976ae1c` |

---

## 5. `src/executors/SuperDestinationExecutor.sol`

- `SUPER_DESTINATION_VALIDATOR` public immutable (`:32`); `usedMerkleRoots` (`:36`); `isMerkleRootUsed` (`:85-87`).
- `processBridgedExecution(address tokenSent /*unused*/, address account, address[] dstTokens, uint256[] intentAmounts, bytes initData, bytes executorCalldata, bytes userSignatureData) external` (`:94-105`) — no access control.
- Order: `ARRAY_LENGTH_MISMATCH` (`:107`); `_validateOrCreateAccount` (`:164-171`: `initData.length > 0 && account.code.length == 0` → `_createAccount`, `INVALID_ACCOUNT` on mismatch; then `ACCOUNT_NOT_CREATED`). `_createAccount` (`:216-226`): `initData = abi.encodePacked(senderCreator, factory, factoryCalldata)`. `_decodeMerkleRoot` (`:173-178`) decodes the 7-tuple (panics on garbage — caught by the adapter's bare catch). Validator call (`:115-123`): `destinationData = abi.encode(executorCalldata, uint64(block.chainid), account, address(this), dstTokens, intentAmounts)`; magic `0x5c2ec0f3`. Balance gate `_validateBalances` (`:180-214`): zero intent or short balance → event + silent no-op. Root used → `ReceivedButRootUsedAlready`; mark used (`:132`); `_shouldSkipCalldata` → `ReceivedButNoHooks`; `_execute` + `SuperDestinationExecutorExecuted`.

---

## 6. Tests to reuse

**`test/integration/cctp/CCTPAdapterRealExecutorE2E.t.sol` (658 lines)** — the real-executor harness: `ExecutingERC7579Account`, `HookLifecycleTarget` (from `test/unit/simulationHelpers/AcrossDestinationExecutionE2E.t.sol`), `MockHook`, `MerkleTreeHelper`; local `Account7579Factory` (`:52-59`), `TogglableTarget` (`:62-74`), `IFiatTokenBlacklist` (`:43-47`); setup (`:112-135`); intent helpers `_executorCalldataFor`, `_rootFor`, `_sign` (`keccak256(abi.encode(validator.namespace(), root))` → `toEthSignedMessageHash` → `vm.sign(ownerPk)`), `_hookData`, `_sigData`, `_dstProofsFor`, `_one`, `_redriveDirectly`, log assertions. Test matrix `:143-362`. Only the bridge leg (`:536-630`) is CCTP-specific — replace `_bridgeToBase` with a Gateway attestation builder (below). Drop the two fee-sized tests (no destination fee on Gateway).

**`test/integration/cctp/CCTPAdapterE2EFork.t.sol`**: `MockDestinationExecutor` with `SUPER_DESTINATION_VALIDATOR` public (`:39-60`), `ResolverHarness` pattern. Gateway analogues: replay → `TransferSpecHashUsed(hash)`, bad signer → `InvalidAttestationSigner()`.

**`test/unit/adapters/CCTPAdapterUnitTests.t.sol`**: copy `MockDestinationExecutor` (`:13-72`), `NonBoolWordUSDC` (`:74-84`), `BlacklistUSDC` (`:1014-1051`). For Gateway build payloads with the real encoder (`AttestationLib.encodeAttestation(Attestation({ maxBlockHeight, spec }))`) then mutate bytes at absolute offsets for negatives. A `MockGatewayMinter` must parse `value`@312 / `destinationRecipient`@216 / `destinationToken`@152 and mint accordingly, with revert and "mint a different token" toggles.

**Gateway signing helpers (`lib/evm-gateway-contracts/test/util/`):** `SignatureTestUtils._signAttestationWithTransferSpec(TransferSpec memory, uint256 signerKey) returns (bytes payload, bytes signature)` (`:115-123`, `maxBlockHeight: block.number + 5`, sig = `vm.sign(key, keccak256(data).toEthSignedMessageHash())`); `_signAttestationSetWithTransferSpec` (`:125-135`). `MultichainTestUtils` (`ChainSetup`, `_initializeGatewayContracts`, `_createTransferSpec(..., hookData: "Test hook data")`, `_mintFromChain`); `ForkTestUtils.forkVars()` (Ethereum 0, Arbitrum 3, Base 6). `TransferPayloadTestUtils._verifyTransferSpecFieldsFromView` — assert the adapter's calldata-offset reads agree with the lib getters. **`CrosschainTestsGateway.t.sol` is `vm.skip(true)`** (`:119`); hook data layout `abi.encodePacked(uint256(payload.length), payload, uint256(sig.length), sig)` (`:531-536`).

**Minimal fork recipe against the REAL Base minter:**
```solidity
IGatewayMinterAdmin m = IGatewayMinterAdmin(0x2222222d7164433c4C09B0b0D809a9b52C04C205);
vm.prank(m.owner()); m.addAttestationSigner(vm.addr(SIGNER_PK));   // Base owner 0xF1237f…
TransferSpec memory spec = TransferSpec({ version: 1, sourceDomain: 0, destinationDomain: 6,
  sourceContract: b32(GATEWAY_WALLET), destinationContract: b32(address(m)),
  sourceToken: b32(USDC_ETH), destinationToken: b32(USDC_BASE), sourceDepositor: b32(depositor),
  destinationRecipient: b32(address(adapter)), sourceSigner: b32(depositor),
  destinationCaller: b32(address(adapter)), value: AMOUNT, salt: keccak256(abi.encode(nonce++)),
  hookData: hookData6Tuple });
bytes memory payload = AttestationLib.encodeAttestation(Attestation({ maxBlockHeight: block.number + 5, spec: spec }));
(uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, MessageHashUtils.toEthSignedMessageHash(keccak256(payload)));
adapter.receiveAndExecute(payload, abi.encodePacked(r, s, v));
```
`tokenMintAuthority(USDC) == 0` → the proxy mints via `FiatToken.mint`; check `minterAllowance(GATEWAY_MINTER)` on the fork or raise it with the MasterMinter pranks in `MultichainTestUtils.sol:100-113`.

**`MockGatewayMinter` in `CircleGatewayUnitTests.sol:1774-1794`** mints a fixed `100e6` to `msg.sender` ignoring the payload — write a new payload-aware mock.

---

## 7. Deployment wiring precedent

- **`script/utils/Constants.sol`**: keys `:33-45` (`CCTP_ADAPTER_KEY` at `:38`; key = tracking key, artifact stem, CREATE2 salt seed via `DeployV2Base.s.sol:391`); `GATEWAY_WALLET`/`GATEWAY_MINTER` `:183-184`. Add `CIRCLE_GATEWAY_ADAPTER_KEY = "CircleGatewayAdapter"`.
- **`script/utils/ConfigCore.sol`**: `messageTransmittersV2` `:61-82`; **`usdcs` `:84-94`** (10 chains). Cleanest gate: new `gatewayMinters[chainId]` map (values `GATEWAY_MINTER` or `address(0)`) AND `usdcs[chainId] != 0` — Gateway is not live on every CCTP V2 chain.
- **`script/DeployV2Core.s.sol`**: imports `:10-11`; `CoreContracts` field `:33`; `ContractAvailability` `:286`; `_getContractAvailability` (`potentialSkips = new string[](48)` `:358`; `string[7] adapterContracts` `:361-369` → `[8]`; CCTP gate `:390-396`); `_checkAdapterContracts` CCTP block `:2047-2064`; `_populateCoreContractsFromStatus` `:2945-2946`; `_deployCoreContracts` config validation `:3029-3039`, deploy block `:3276-3338` (sanity: `isTokenSupported(usdcs[chainId])`, `domain()` logged), post-deploy requires `:3315-3334`; scoped `runCCTPAdapter` `:836-918` (reference only); Gateway hook precedent check `:2622-2627`, deploy `:4333-4339`.
- **`script/run/tooling/regenerate_bytecode.sh:82-100`** `CORE_CONTRACTS` (`"CCTPAdapter"` at `:91`). No script copies into `locked-bytecode{,-dev}/` — manual `cp`. `__getBytecodeArtifactPath`: env 0 → `locked-bytecode/`, env 1/2 → `locked-bytecode-dev/`.
- **`test/script/DeployV2CoreCCTPAdapterArgs.t.sol`** — clone: `ArgsHarness` (`runCheck`, `checkedAddress`, `deployAddress`, arg getters); assert `checked == deployAddress("CircleGatewayAdapter", 2, abi.encode(gatewayMinter, usdc(BASE), executor))`. Needs `locked-bytecode-dev/CircleGatewayAdapter.json` to exist first.

---

## 8. Conventions

- CLAUDE.md style; `.cursor/rules/` does not exist. Observed: `pragma solidity 0.8.30;`; SPDX `Apache-2.0` in `src/`, `UNLICENSED` in tests; commented import groups; banner comments per section; errors `SCREAMING_SNAKE()` with `/// @notice Thrown when …`; events PascalCase with `indexed` addresses; immutables `SCREAMING_SNAKE`; helpers `_camelCase`; ctor params `name_`; heavy NatSpec with review-round references.
- `forge fmt` (`foundry.toml:78-86`): `line_length = 120`, `bracket_spacing = true`, `multiline_func_header = "all"`, `int_types = "long"`, `number_underscore = "thousands"`, `quote_style = "double"`, `wrap_comments = true`. `lint_on_build = false`.
- Locked bytecode: `forge build` → `regenerate_bytecode.sh CircleGatewayAdapter` → `cp` into both locked dirs → verify `bytecode.object` equality. `bytecode_hash = "none"`.
- Spec folder shape mirrors `specs/cctp-destination-adapter/` (interview-notes, spec, technical-spec, IMPLEMENTATION-NOTES, research/*). Security report layout mirrors `specs/security-reports/2026-09-21-cctp-destination-adapter.md`.

---

## Carry over verbatim / adapt / new

| Item | Disposition |
|---|---|
| `IDestinationValidatorSource` local interface | verbatim (redeclare) |
| `MIN_EXECUTION_GAS = 2_000_000` + NatSpec | verbatim |
| `MISCONFIG_*`, `MATCH_OK/MISMATCH_*` | verbatim |
| `struct HookPayload` | verbatim |
| `SUPER_DESTINATION_EXECUTOR`, `SUPER_DESTINATION_VALIDATOR`, `failedTransfers` | verbatim |
| Errors `ADDRESS_NOT_VALID, ZERO_AMOUNT, INSUFFICIENT_FAILED_BALANCE, DESTINATION_CALLER_MISMATCH, NOTHING_MINTED, INVALID_SENDER, INSUFFICIENT_GAS` | verbatim |
| All 8 events | verbatim (`messageSender → sourceDepositor`) |
| Constructor zero-checks + validator caching | verbatim |
| Steps 8-15 of `receiveAndExecute` | verbatim |
| `decodeHookPayload` | verbatim with offset 380 |
| `checkDestinationTargets` | verbatim |
| `claimFailedTransfer` | verbatim |
| `_tryTransfer` + `_isTrueWord` | verbatim |
| Contract-level NatSpec | adapt |
| Offsets block | adapt → §3 table + magics/version |
| F1/F2 block | adapt: `destinationCaller`@280, `destinationRecipient`@216, `destinationContract`@88 == `GATEWAY_MINTER`, `destinationDomain`@52 == `domain()` |
| Attested sender read | adapt → `sourceDepositor`@184 |
| Token routing | adapt → `destinationToken`@152 `!= USDC → _mintNonUsdc` |
| Mint + delta | adapt → `gatewayMint(payload, signature)` |
| Cross-check | adapt → `claimed = value`@312 |
| `_receiveNonUsdc` | adapt |
| `ITokenMessengerV2MinterSource`, `TOKEN_MESSENGER`, `MESSAGE_TRANSMITTER`, `TOKEN_MESSENGER_NOT_VALID`, `RECEIVE_MESSAGE_FAILED`, `UNSUPPORTED_BURN_TOKEN`, `RECIPIENT_MISMATCH`, body-version check | drop |
| `ATTESTATION_SET_NOT_SUPPORTED`, `INVALID_ATTESTATION_MAGIC`, `PAYLOAD_LENGTH_MISMATCH`, `IGatewayMinter` view interface, ctor `isTokenSupported(usdc)` sanity | new |

---

## Concrete gotchas

1. **`via_ir` is off in the default profile.** Keep the scoped `{}` block, read fields into locals one at a time, or parse with calldata slices at the absolute offsets exactly as CCTPAdapter does (no memview in the adapter; use the libs only in tests to prove the offsets).
2. **Memview needs `bytes memory`**; `getHookData()` returns `bytes29` → `abi.decode(payload[380:], …)` in the calldata self-call (preferred).
3. **Truncation semantics.** The minter compares via `_bytes32ToAddress` (low 20 bytes). Mirror the minter: compare truncated addresses, or a spec with junk high bytes is rejected by the adapter yet accepted by the minter — and stranded if pinned.
4. **Ethereum `domain() == 0`.** Never require non-zero. Use `isTokenSupported(usdc)` as the liveness check.
5. **`AttestationExpiredAtIndex`** is a pre-hash-mark revert — hash unused, attestation dead; re-attestation is Circle's call.
6. **Denylist/pause/blacklist hit the adapter itself**; pinned specs stall until Circle acts. Keep the adapter ownerless.
7. **`gatewayMint` is one-shot and returns nothing**; all content checks BEFORE the call; nothing after it may revert on content.
8. **File-level interface name collisions** — always named imports.
9. **`potentialSkips` sized 48** — bump to 49.
10. **`_readCoreContractsFromOutput`** only matters for a scoped entrypoint; `vm.setEnv` is process-global → one sequential test.
11. **Parity test prerequisite**: `locked-bytecode-dev/CircleGatewayAdapter.json` must exist; re-run after every adapter edit.
12. **Locked-bytecode sync is manual and silent.**
13. **Submodule drift** (`569d7cef`, 2025-07-21) vs the deployed UUPS proxy — fork tests against the real proxy are the check.
14. `Cursor` import from `Cursor.sol` directly.
15. Existing `MockGatewayMinter` is payload-blind — write a new mock.
16. Executor's `tokenSent` arg is ignored; malformed `sigData` panics inside the executor and is absorbed by the bare catch.
17. **Attestation digest = `keccak256(payload).toEthSignedMessageHash()`** (Ethereum-signed-message prefix), NOT the raw hash CCTP attesters sign — do not copy the CCTP `_signAttestation` helper.
