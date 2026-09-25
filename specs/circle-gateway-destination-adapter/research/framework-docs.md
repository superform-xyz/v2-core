# Circle Gateway (evm-gateway-contracts) — integration reference for `CircleGatewayAdapter`

Scope: parsing a single Circle Gateway `Attestation` in a Superform adapter, calling
`GatewayMinter.gatewayMint`, and producing valid attestations in fork tests against the real minter.
All file references are into `lib/evm-gateway-contracts` (vendored at commit `569d7ce`) unless stated.
Everything below was checked against the source, a via-IR compile, and a mainnet fork run (see section 9).

---

## 1. Summary

Circle Gateway is a burn-on-source / mint-on-destination USDC system. The destination contract is
`GatewayMinter` (UUPS proxy, same address on every EVM chain). It accepts a byte-encoded `Attestation`
(or `AttestationSet`) plus an ECDSA signature from a Circle-controlled *attestation signer* and mints
`TransferSpec.value` of `destinationToken` to `destinationRecipient`. The adapter's job is to read the
`TransferSpec` fields before/after the mint and act on `hookData`.

Key facts that change how the adapter should be written:

- The attestation signature is **EIP-191 (`personal_sign`) over `keccak256(payload)`**, NOT EIP-712.
  `Mints._verifyAttestationSignature` = `ECDSA.recover(keccak256(attestation).toEthSignedMessageHash(), signature)`
  (`src/modules/minter/Mints.sol:256-261`). There is no domain separator, chain id, or verifying contract in the
  digest. Replay across chains is prevented only by `destinationDomain`/`destinationContract` checks inside the spec.
- The parsing libs are pure Solidity + `TypedMemView` (`bytes29` views), all assembly is `("memory-safe")`,
  no OpenZeppelin dependency. Only `GatewayMinter`/`Mints`/`GatewayCommon` pull OZ (upgradeable v5.2.0 nested).
- The libs take `bytes memory`, never `calldata`. Copy calldata to memory once, then build views.
- `AttestationLib.cursor(bytes)` performs *full structural validation* (magic, header lengths, inner spec magic,
  version, hook-data length consistency) and reverts with typed custom errors. After `cursor()` succeeds every
  getter is safe (no out-of-bounds reads).

## 2. Version information

| Item | Value |
|---|---|
| Vendored submodule commit | `569d7cef11b70fac4eb696a98b9c5997d87b32d3` — "Sync latest changes (#4)", 2025-07-21 (release **1.0.0**) |
| Upstream default branch | `master`, last push 2026-09-02; releases 1.1.0 (2025/11), 1.2.0 (2026/01), 1.3.0 (2026/06+) |
| Upstream changes since vendored commit, `src/` | **Only GatewayWallet-side files changed** (Burns, Batches, ContractSignatureSigners, ContractSignersAllowlist, BurnIntentLib, BatchedDelta) plus `GatewayCommon.sol` (+`RenounceOwnershipDisabled` / `renounceOwnership()` override) and `GatewayMinter.sol` (+`InsufficientBalance` event decl). `AttestationLib.sol`, `TransferSpecLib.sol`, `TransferSpec.sol`, `Attestations.sol`, `Cursor.sol`, `AddressLib.sol`, `Mints.sol`: **zero diff** (`git log 569d7ce..origin/master -- <files>` is empty). `TRANSFER_SPEC_VERSION` is still `1`, no new fields. |
| Deployed mainnet minter | proxy `0x2222222d7164433c4C09B0b0D809a9b52C04C205`, ERC-1967 implementation `0xc2ff68068362aea1ca22a3896d05b2b812ce51b1` on both Ethereum and Base (checked 2026-09-23). Runtime bytecode of that implementation is **byte-identical to the vendored `script/compiled-contract-artifacts/GatewayMinter.json` `deployedBytecode`** except the three 32-byte UUPS `__self` immutable slots (solc 0.8.29 per CBOR tail). So the vendored commit is exactly what is live. |
| Live config (Ethereum) | `domain()=0`, `owner()=0x3c54FFa14d01EF3A555106007A4fED6E8964aAB6`, `paused()=false`, `isTokenSupported(USDC)=true`, `tokenMintAuthority(USDC)=address(0)` (so the minter calls `USDC.mint` directly; USDC `isMinter(minter)=true`, allowance ≈ 97.3M USDC), pauser `0x6fa314D4Dce1d49233c329a60fDBd96a6BCbe6Fb`, denylister `0x7e575bC81e8a4A57f841512fbE72ed4C9976ae1c`. |
| Live config (Base) | `domain()=6`, `owner()=0xF1237f985D146D8AeC106c742Ec6D8C4A98bB788`, `isTokenSupported(USDC 0x8335…2913)=true`, same implementation. |
| Addresses / domains (Circle docs) | Mainnet: Wallet `0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE`, Minter `0x2222222d7164433c4C09B0b0D809a9b52C04C205` on Ethereum(0), Avalanche(1), OP(2), Arbitrum(3), Base(6), Polygon(7), Unichain(10), Sonic(13), World Chain(14), Sei(16), HyperEVM(19), Arc(26). Testnet: Wallet `0x0077777d7EBA4688BDeF3E311b846F25870A19B9`, Minter `0x0022222ABE238Cc2C7Bb1f21003F0a260052475B`. Source: https://developers.circle.com/gateway/references/contract-addresses |
| v2-core already uses | `script/utils/Constants.sol:183-184` (`GATEWAY_WALLET`, `GATEWAY_MINTER`), `src/hooks/bridges/circle/CircleGatewayMinterHook.sol`, `test/utils/InternalHelpers.sol:16-38` (magic constants). |

Remappings actually in effect in v2-core (`forge remappings`): `evm-gateway/=lib/evm-gateway-contracts/src/`,
`lib/evm-gateway-contracts:src/=lib/evm-gateway-contracts/src/` (context remapping — the libs import each other as
`src/lib/...`), `@memview-sol/=lib/evm-gateway-contracts/lib/memview-sol/contracts/` (auto-detected from the
submodule's `remappings.txt`), `@openzeppelin/contracts-upgradeable/=lib/evm-gateway-contracts/lib/openzeppelin-contracts-upgradeable/contracts/`
(auto-detected, v5.2.0), `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/` (v2-core's own v5.3.0).

Compiler profile: v2-core's `[profile.default]` does **not** set `via_ir`; only `[profile.coverage]` does
(`foundry.toml:69`). The snippet in section 7 was compiled with `via_ir = true`, solc 0.8.30, evm `prague` and
produced no warnings.

## 3. Key concepts and exact API

### 3.1 Wire formats (`src/lib/Attestations.sol`, `src/lib/TransferSpec.sol`)

`Attestation` (magic `0xff6fb334` = `bytes4(keccak256("circle.gateway.Attestation"))`, `Attestations.sol:23`):

| offset | bytes | field |
|---|---|---|
| 0 | 4 | magic |
| 4 | 32 | `maxBlockHeight` (uint256; **destination-chain block height**; for Arbitrum it is L1 block height) |
| 36 | 4 | transfer spec length (uint32) |
| 40 | n | encoded `TransferSpec` |

`AttestationSet` (magic `0x1e12db71`, `Attestations.sol:24`): `magic[4] | numAttestations[4] | attestations...` (offsets `Attestations.sol:33-35`).

`TransferSpec` (magic `0xca85def7`, version `1`; `TransferSpec.sol:21-42`):

| offset | bytes | field | offset | bytes | field |
|---|---|---|---|---|---|
| 0 | 4 | magic | 176 | 32 | destinationRecipient |
| 4 | 4 | version | 208 | 32 | sourceSigner |
| 8 | 4 | sourceDomain | 240 | 32 | destinationCaller (0 = any caller) |
| 12 | 4 | destinationDomain | 272 | 32 | value |
| 16 | 32 | sourceContract | 304 | 32 | salt |
| 48 | 32 | destinationContract | 336 | 4 | hookData length (uint32) |
| 80 | 32 | sourceToken | 340 | n | hookData |
| 112 | 32 | destinationToken | | | |
| 144 | 32 | sourceDepositor | | | |

Minimum sizes: attestation header 40, spec header 340, so a minimal single attestation is 380 bytes.
`keccak256(encodedTransferSpec)` is the cross-chain id and replay key (`TransferSpecHashes`). Addresses are
left-padded `bytes32`; `AddressLib._bytes32ToAddress` just truncates to the low 20 bytes (no check that the
upper 12 bytes are zero).

Solidity structs (`TransferSpec.sol:68-83`, `Attestations.sol:51-54,67-69`):

```solidity
struct TransferSpec { uint32 version; uint32 sourceDomain; uint32 destinationDomain; bytes32 sourceContract;
    bytes32 destinationContract; bytes32 sourceToken; bytes32 destinationToken; bytes32 sourceDepositor;
    bytes32 destinationRecipient; bytes32 sourceSigner; bytes32 destinationCaller; uint256 value; bytes32 salt;
    bytes hookData; }
struct Attestation { uint256 maxBlockHeight; TransferSpec spec; }
struct AttestationSet { Attestation[] attestations; }
struct Cursor { bytes29 memView; uint256 offset; uint32 numElements; uint32 index; bool done; }  // Cursor.sol:23-34
```

### 3.2 `AttestationLib` (`src/lib/AttestationLib.sol`) — `library`, all `internal pure`

| signature | line | notes |
|---|---|---|
| `function _isSet(bytes29 ref) private pure returns (bool)` | 51 | **private** — not callable from the adapter. Compare the first 4 bytes yourself. |
| `function _asAttestationOrSetView(bytes memory data) internal pure returns (bytes29 ref)` | 65 | reverts `TransferPayloadDataTooShort(4, len)` if `len < 4`; `InvalidTransferPayloadMagic(magic)` if magic is neither. Returns a view typed with the magic. |
| `function _validateAttestation(bytes29 attestationView) internal pure` | 126 | outer header (`TransferPayloadHeaderTooShort(40,len)`, `TransferPayloadOverallLengthMismatch(40+specLen,len)`) then `getTransferSpec` + `TransferSpecLib._validateTransferSpecStructure`. |
| `function _validateAttestationSet(bytes29 setView) internal pure` | 150 | set header + per-element checks (`TransferPayloadSet*` errors). |
| `function _validate(bytes memory data) internal pure returns (bytes29 ref)` | 212 | cast + dispatch to the two above. |
| `function cursor(bytes memory data) internal pure returns (Cursor memory c)` | 233 | `_validate(data)` then builds the cursor. Single attestation: `offset=0, numElements=1, done=false`. Set: `offset=8, numElements=N, done=(N==0)`. |
| `function next(Cursor memory c) internal pure returns (bytes29 ref)` | 258 | reverts `CursorOutOfBounds()` if `c.done`; returns the element view typed `ATTESTATION_MAGIC`, advances `offset/index`, sets `done` when `index >= numElements`. |
| `function getMaxBlockHeight(bytes29 ref) internal pure returns (uint256)` | 286 | |
| `function getTransferSpecLength(bytes29 ref) internal pure returns (uint32)` | 294 | |
| `function getTransferSpec(bytes29 ref) internal pure returns (bytes29)` | 302 | slices `[40, 40+len)` typed `TRANSFER_SPEC_MAGIC`; reverts `InvalidTransferSpecMagic(magic)` if inner magic is wrong. Note: if the slice overruns, `slice` returns `NULL` and the following `index(0,4)` reverts with a **string** revert from TypedMemView (`indexErrOverrun`) — only reachable if you skipped `cursor()`. |
| `function getNumAttestations(bytes29 ref) internal pure returns (uint32)` | 320 | set only. |
| `function encodeAttestation(Attestation memory) internal pure returns (bytes memory)` | 330 | `abi.encodePacked(MAGIC, maxBlockHeight, uint32(spec.length), spec)`. |
| `function encodeAttestationSet(AttestationSet memory) internal pure returns (bytes memory)` | 345 | byte-by-byte copy loops; test-only in practice. |

Errors live in `TransferSpecLib` (`TransferSpecLib.sol:67-180`): `TransferSpecDataTooShort`, `InvalidTransferSpecMagic(bytes4)`,
`TransferSpecHeaderTooShort(uint256,uint256)`, `InvalidTransferSpecVersion(uint32)`, `TransferSpecOverallLengthMismatch(uint256,uint256)`,
`TransferSpecHookDataFieldTooLarge`, `TransferSpecInvalidHookData`, `IdentityPrecompileCallFailed`, `TransferPayloadDataTooShort`,
`InvalidTransferPayloadMagic(bytes4)`, `TransferPayloadHeaderTooShort`, `TransferPayloadOverallLengthMismatch`, `TransferPayloadSetHeaderTooShort`,
`TransferPayloadSetElementHeaderTooShort`, `TransferPayloadSetElementTooShort`, `TransferPayloadSetInvalidElementMagic`,
`TransferPayloadSetOverallLengthMismatch`, `TransferPayloadSetTooManyElements`, `CursorOutOfBounds`.

### 3.3 `TransferSpecLib` (`src/lib/TransferSpecLib.sol`) — `library`

| signature | line |
|---|---|
| `function _toMemViewType(bytes4 magic) internal pure returns (uint40)` | 188 |
| `function _validateTransferSpecStructure(bytes29 specView) internal pure` | 205 — `TransferSpecHeaderTooShort(340,len)`, `InvalidTransferSpecVersion(v)`, `TransferSpecOverallLengthMismatch(340+hookLen,len)` |
| `getVersion / getSourceDomain / getDestinationDomain (bytes29) → uint32` | 232 / 240 / 248 |
| `getSourceContract / getDestinationContract / getSourceToken / getDestinationToken / getSourceDepositor / getDestinationRecipient / getSourceSigner / getDestinationCaller / getSalt (bytes29) → bytes32` | 256 / 264 / 272 / 280 / 288 / 296 / 304 / 312 / 328 |
| `function getValue(bytes29 ref) internal pure returns (uint256)` | 320 |
| `function getHookDataLength(bytes29 ref) internal pure returns (uint32)` | 336 |
| `function getHookData(bytes29 ref) internal pure returns (bytes29)` | 344 — returns a zero-typed (type `0`) slice `[340, 340+len)`; empty slice when len 0; reverts `TransferSpecInvalidHookData` if the slice would overrun (unreachable after validation). |
| `function encodeTransferSpec(TransferSpec memory) internal pure returns (bytes memory)` | 372 — reverts `TransferSpecHookDataFieldTooLarge` if `hookData.length > type(uint32).max` |
| `function getHash(bytes29 ref) internal pure returns (bytes32)` | 465 — `ref.keccak()` = the replay/cross-chain id |
| `function getTypedDataHash(bytes29 spec) internal view returns (bytes32)` | 477 — EIP-712 struct hash of the spec (`TRANSFER_SPEC_TYPEHASH`, `TransferSpec.sol:87`). Used for **burn intents on the wallet side only**; NOT used for attestation signatures. Contains a **non-`memory-safe`** assembly block (staticcall to the identity precompile) — do not call it from the adapter; unused internal library functions are not compiled in, so merely importing the lib is fine. |

### 3.4 `AddressLib` (`src/lib/AddressLib.sol`)

`_checkNotZeroAddress(address)` (30, reverts `InvalidAddress()`), `_addressToBytes32(address) → bytes32` (43),
`_bytes32ToAddress(bytes32) → address` (54, `address(uint160(uint256(buf)))`, silently drops high 12 bytes).

### 3.5 `TypedMemView` (`@memview-sol/TypedMemView.sol`, summa-tx memview-sol **v2.1.1**, commit `3750a8f`, `pragma >=0.8.12`)

A `bytes29` packs `type[5] | loc[12] | len[12]` (top 29 bytes). Relevant API (all `internal`):

| function | line | notes |
|---|---|---|
| `NULL` constant `bytes29 = 0xff..ff` | 63 | returned by `build/slice` on overrun |
| `ref(bytes memory arr, uint40 newType) pure → bytes29` | 313 | view over the *data* of a memory array; `build` returns `NULL` if `loc+len > mload(0x40)` — so views must point into allocated memory (never calldata) |
| `castTo(bytes29, uint40) pure → bytes29` | 250 | retype |
| `typeOf / isType / assertType(bytes29, uint40)` | 330 / 222 / 233 | `assertType` reverts with a **string** ("Type assertion failed. Got 0x.. Expected 0x..") |
| `isValid / assertValid` | 196 / 211 | `isValid` = type != 0xffffffffff and `end <= mload(0x40)` |
| `loc(bytes29) → uint96`, `len(bytes29) → uint96`, `end` | 353 / 385 / 399 | |
| `slice(bytes29, uint256 idx, uint256 len, uint40 newType) pure → bytes29` | 413 | returns `NULL` (no revert) on overrun |
| `index(bytes29, uint256 idx, uint8 nBytes) pure → bytes32` | 489 | left-aligned; reverts with string on overrun or `nBytes > 32` |
| `indexUint(bytes29, uint256 idx, uint8 nBytes) pure → uint256` | 516 | right-aligned |
| `keccak(bytes29) pure → bytes32` | 547 | |
| `clone(bytes29) view → bytes memory` | 695 | copies via identity precompile (`staticcall` to address 4, `require(res,"identity OOG")`); allocates `len + 0x20` and sets the free-memory pointer to an **unaligned** value (`ptr + len + 0x20`, no 32-byte rounding). Solidity tolerates this, but it is unusual; see the `mcopy` alternative in section 7. Because it is `view`, any adapter function that uses `.clone()` cannot be `pure`. |
| `equal / untypedEqual / join / joinKeccak` | 641 / 620 / 776 / 748 | not needed |

All assembly blocks in TypedMemView are annotated `("memory-safe")` — verified with `grep`. via-IR stack-to-memory
mover therefore stays enabled for contracts that use it.

### 3.6 `GatewayMinter` / `Mints` (`src/GatewayMinter.sol`, `src/modules/minter/Mints.sol`, `src/GatewayCommon.sol`, `src/modules/common/*.sol`)

Inheritance: `GatewayMinter is GatewayCommon, Mints`; `GatewayCommon is Initializable, UUPSUpgradeable, Ownable2StepUpgradeable, Pausing, Denylist, TokenSupport, TransferSpecHashes, Domain`.

`function gatewayMint(bytes memory attestationPayload, bytes memory signature) external whenNotPaused notDenylisted(msg.sender)` (`Mints.sol:161`). Validation sequence, in order:

1. `whenNotPaused` (OZ `EnforcedPause()`), `notDenylisted(msg.sender)` → `AccountDenylisted(address)` (`Denylist.sol`).
2. `_verifyAttestationSignature` (`Mints.sol:256`): `ECDSA.recover(keccak256(payload).toEthSignedMessageHash(), signature)`; OZ `ECDSAInvalidSignature*` on malformed sig; `InvalidAttestationSigner()` if recovered address is not in `attestationSigners`.
3. `AttestationLib.cursor(payload)` → all structural errors from section 3.2/3.3.
4. `MustHaveAtLeastOneAttestation()` if `numElements == 0` (empty set).
5. Per attestation `i` (`index = cursor.index - 1`):
   - `AttestationExpiredAtIndex(i, maxBlockHeight, block.number)` if `maxBlockHeight < block.number` (`Mints.sol:269`). Equality is allowed.
   - `attestation.getTransferSpec()` (inner magic check).
   - `_validateAttestationTransferSpec` (`Mints.sol:284`): `AttestationValueMustBePositiveAtIndex(i)` if `value == 0`; `AccountDenylisted(recipient)`; `InvalidAttestationDestinationCallerAtIndex(i, caller, msg.sender)` if `destinationCaller != 0 && != msg.sender`; `InvalidAttestationDestinationDomainAtIndex(i, dom, domain())`; `InvalidAttestationDestinationContractAtIndex(i, c, address(this))`; `UnsupportedTokenAtIndex(i, token)`; if `sourceDomain == destinationDomain`: `InvalidAttestationTokenAtIndex(i, srcToken, dstToken)` when they differ.
   - `_mint` (`Mints.sol:333`): `specHash = spec.getHash()`; `TransferSpecHashUsed(specHash)` if already used, else mark used; `minter = tokenMintAuthority(token) == 0 ? token : authority`; `IMintableToken(minter).mint(recipient, value)` (**return bool is ignored**; FiatToken reverts on failure anyway); emit `AttestationUsed`.

Event (`Mints.sol:47-55`):

```solidity
event AttestationUsed(address indexed token, address indexed recipient, bytes32 indexed transferSpecHash,
    uint32 sourceDomain, bytes32 sourceDepositor, bytes32 sourceSigner, uint256 value);
```

`IMintableToken.mint(address to, uint256 amount) external returns (bool)` (`src/interfaces/IMintableToken.sol`). On mainnet USDC the minter calls `FiatTokenV2_2.mint` directly (mint authority unset), which requires the minter to be a configured USDC minter with allowance (it is; see section 2).

Public views: `domain() → uint32` (`Domain.sol`), `isTokenSupported(address) → bool` (`TokenSupport.sol`), `tokenMintAuthority(address) → address` (`Mints.sol:207`), `isTransferSpecHashUsed(bytes32) → bool` (`TransferSpecHashes.sol`), `isAttestationSigner(address) → bool` (`Mints.sol:199`), `isDenylisted(address) → bool`, `denylister()`, `pauser()`, `paused()` (OZ), `owner()` / `pendingOwner()` (OZ 2-step).

Owner functions for fork tests: `addAttestationSigner(address) public onlyOwner` (`Mints.sol:231`, reverts `InvalidAddress()` on zero, emits `AttestationSignerAdded`), `removeAttestationSigner(address)` (243), `addSupportedToken(address)`, `updateMintAuthority(address token, address authority) onlyOwner tokenSupported(token)` (217). Pausing is `onlyPauser` (`pause()/unpause()`), denylisting is `onlyDenylister`.

## 4. Detecting single `Attestation` vs `AttestationSet`

`_isSet` is private, so do it inline. Correct and cheap:

```solidity
if (payload.length < 4) revert PAYLOAD_TOO_SHORT();          // mirrors TransferPayloadDataTooShort
bytes4 magic = bytes4(payload);                                // bytes memory -> bytes4 takes the first 4 bytes
if (magic == ATTESTATION_SET_MAGIC) revert ATTESTATION_SET_NOT_SUPPORTED();   // 0x1e12db71
// anything other than ATTESTATION_MAGIC (0xff6fb334) is rejected by cursor() with InvalidTransferPayloadMagic
```

Constants are importable: `import { ATTESTATION_MAGIC, ATTESTATION_SET_MAGIC } from "evm-gateway/lib/Attestations.sol";`
(`test/utils/InternalHelpers.sol:36-38` already hardcodes the same values).

Circle's API returns an `AttestationSet` whenever the transfer request batches several burn intents (multi-source
unified balance). Rejecting sets means the adapter only supports single-source transfers; the caller must request
per-source transfers. Document this in the adapter NatSpec.

What to check yourself vs delegate to `gatewayMint`:

| check | who | why |
|---|---|---|
| length ≥ 4, not a set | adapter | needed before any parsing; the minter *would* accept a set and mint N times |
| structural validity (magic/lengths/version) | `AttestationLib.cursor` in the adapter | you need the fields before the external call anyway; it is the same code the minter runs, so anything that passes here passes there |
| `destinationCaller == address(adapter)` | adapter (revert early) and minter (enforced) | adapter should require a **non-zero** caller equal to itself; a zero caller lets anyone front-run the mint and strand the payload |
| `destinationContract == GATEWAY_MINTER`, `destinationDomain == minter.domain()` | minter | optional early check in adapter for better errors |
| `destinationRecipient` | adapter | decide who must receive (usually the adapter itself so it can forward) |
| signature, expiry, replay, token support, denylist, pause | minter | do not duplicate; cannot be evaluated without minter state (except `isTransferSpecHashUsed` view for a pre-check) |

## 5. Test utilities (`lib/evm-gateway-contracts/test/util/`)

- `SignatureTestUtils.sol` (`contract SignatureTestUtils is Test`):
  - `_signAttestationWithTransferSpec(TransferSpec memory, uint256 signerKey) internal view returns (bytes memory encodedAttestation, bytes memory signature)` — wraps the spec in `Attestation{maxBlockHeight: block.number + 5, spec}` (private `_createAttestation`), encodes with `AttestationLib.encodeAttestation`, signs `keccak256(encoded).toEthSignedMessageHash()` with `vm.sign`, packs `r,s,v`.
  - `_signAttestationSetWithTransferSpec(TransferSpec[] memory, uint256)` — same for a set.
  - Burn-intent helpers (`_signBurnIntentWithTransferSpec(spec, GatewayWallet, key)`, `_signBurnIntents(...)`) use EIP-712 with `wallet.domainSeparator()` — wallet side only.
  - `maxBlockHeight = block.number + 5` is hardcoded; write your own helper if you need control (see section 7b).
- `MultichainTestUtils.sol` (`is DeployUtils, SignatureTestUtils`): `_initializeGatewayContracts(string chainName)` deploys *fresh* wallet+minter on a fork and configures USDC MasterMinter; `_createTransferSpec(ChainSetup src, ChainSetup dst, amount, depositor, recipient, signer, destinationCaller)`; `_mintFromChain(...)` pranks `destinationCaller` and calls `gatewayMint`. Fixed keys: `depositorPrivateKey`, `delegatePrivateKey`; `HOOK_DATA = "Test hook data"`. The v2-core `CrosschainTestsGateway.t.sol` inherits this and re-implements `_setupChain` (deploying its own minter, not the real one).
- `DeployUtils.sol`: `deploy(owner, domain)`, `deployMinterOnly(owner, domain)` (ERC1967Proxy → `UpgradeablePlaceholder` → `upgradeToAndCall(GatewayMinter.initialize(...))`).
- `ForkTestUtils.sol`: `forkVars()` gives `{usdc, domain}` for chain ids 1/11155111/42161/421614/8453/84532 (mainnet domains 0/3/6).
- `TransferPayloadTestUtils.sol`: `_verifyTransferSpecFieldsFromView`, `_getCorruptedInnerSpecHookDataLengthData` (useful for negative tests).
- Importing `MultichainTestUtils` drags in `test/mock_fiattoken/**` (v2-core already remaps `test/mock_fiattoken/`), OZ upgradeable 5.2.0 and `GatewayWallet`. For a test that only targets the real minter, import only `GatewayMinter` + `AttestationLib` + `MessageHashUtils` to keep compile time down.

"EIP-712 domain used by the minter for attestation signatures": **there is none**. The digest is
`keccak256("\x19Ethereum Signed Message:\n32" || keccak256(payload))`. Chain id and verifying contract are not part of
the signature, so the same signed attestation is only protected by `destinationDomain`/`destinationContract` in the
spec and by the per-chain signer set.

## 6. Solidity / via-IR gotchas

1. `bytes29` is a plain value type; passing it around, storing in structs (`Cursor`) and returning from internal
   functions is fine under via-IR. No `abi.encode` of `bytes29` in external interfaces (it would encode as a
   right-padded 29-byte value — never expose it).
2. Views are validated against the free-memory pointer (`build`). Building a view over memory you obtained from
   `abi.decode`, a `calldata` → `memory` copy, or `new bytes(n)` is fine; do not try to view calldata.
3. `AttestationLib.cursor` and every getter are `pure`; `TypedMemView.clone` and `TransferSpecLib.getTypedDataHash`
   are `view` (staticcall to precompiles). Mark adapter helpers accordingly.
4. `TypedMemView.index` overruns and `assertType` failures revert with **string** reasons, not custom errors. After a
   successful `cursor()` they are unreachable; if you skip `cursor()` your revert surface becomes strings.
5. `getHookData` returns a view typed `0`; do not `assertType` it.
6. `clone()` leaves the free memory pointer unaligned. Harmless for solc, but if you prefer canonical allocation use
   the `mcopy` helper below (evm `prague` in v2-core, so `mcopy` is available).
7. OZ: the libs (`AttestationLib`, `TransferSpecLib`, `AddressLib`, `Cursor`, `TypedMemView`) import **no**
   OpenZeppelin code. `Mints.sol` imports `ECDSA`/`MessageHashUtils` from `@openzeppelin/contracts/` (resolves to
   v2-core's v5.3.0) and `GatewayCommon`/modules import `@openzeppelin/contracts-upgradeable/` (resolves to the nested
   v5.2.0). Mixing 5.2 upgradeable with 5.3 core compiles today (v2-core already compiles `GatewayMinter` in tests);
   keep the adapter free of `GatewayMinter.sol` imports and use a local minimal interface (as
   `CircleGatewayMinterHook.sol` does with `IGatewayMinter`) so production bytecode never depends on the nested OZ.
8. `forge lint` `unsafe-typecast` fires on `bytes4(payload)`; add `// forge-lint: disable-next-line(unsafe-typecast)`
   with a justification (it truncates to the first 4 bytes on purpose). Lint is off for `lib/evm-gateway-contracts/**`.
9. `via_ir` is only enabled in the `coverage` profile in v2-core; the default profile (used by `forge build`/`make ftest`)
   compiles without IR. Both paths compile the libs (verified: via-IR build of the snippet below, and the existing hook
   builds in default profile).
10. `maxBlockHeight` is compared with `block.number` on the destination chain; on Arbitrum `block.number` is the L1
    height (matches Circle's semantics). Attestations from Circle expire ~10 minutes after issuance.

## 7. Implementation guide and code

### 7a. Parsing a single attestation safely in the adapter

Compiled with solc 0.8.30, `via_ir = true`, evm `prague` — no warnings. Round-trip and revert paths covered by
tests (section 9).

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { TypedMemView } from "@memview-sol/TypedMemView.sol";
import { AttestationLib } from "evm-gateway/lib/AttestationLib.sol";
import { ATTESTATION_SET_MAGIC } from "evm-gateway/lib/Attestations.sol";
import { TransferSpecLib } from "evm-gateway/lib/TransferSpecLib.sol";
import { AddressLib } from "evm-gateway/lib/AddressLib.sol";
import { Cursor } from "evm-gateway/lib/Cursor.sol";

interface IGatewayMinter {
    function gatewayMint(bytes memory attestationPayload, bytes memory signature) external;
    function domain() external view returns (uint32);
    function isTransferSpecHashUsed(bytes32) external view returns (bool);
}

contract CircleGatewayAdapterParsing {
    using TypedMemView for bytes29;
    using TransferSpecLib for bytes29;
    using AttestationLib for bytes29;
    using AttestationLib for Cursor;

    error ATTESTATION_SET_NOT_SUPPORTED();
    error PAYLOAD_TOO_SHORT();

    struct ParsedAttestation {
        uint256 maxBlockHeight;
        uint32 sourceDomain;
        uint32 destinationDomain;
        address destinationContract;
        address destinationToken;
        address sourceDepositor;
        address destinationRecipient;
        address destinationCaller;
        uint256 value;
        bytes32 specHash;   // == keccak256(encoded TransferSpec) == AttestationUsed.transferSpecHash
        bytes hookData;
    }

    /// @dev `attestationPayload` is copied to memory once; every view below points into that copy.
    function _parseSingleAttestation(bytes calldata attestationPayload)
        internal
        pure
        returns (ParsedAttestation memory p)
    {
        bytes memory payload = attestationPayload;
        if (payload.length < 4) revert PAYLOAD_TOO_SHORT();
        // forge-lint: disable-next-line(unsafe-typecast)  -- intentionally reads the 4-byte magic
        if (bytes4(payload) == ATTESTATION_SET_MAGIC) revert ATTESTATION_SET_NOT_SUPPORTED();

        // Full structural validation; reverts with TransferSpecLib.* errors on any malformed input.
        Cursor memory c = AttestationLib.cursor(payload);
        bytes29 att = c.next();                 // numElements is always 1 here
        bytes29 spec = att.getTransferSpec();   // inner magic checked

        p.maxBlockHeight = att.getMaxBlockHeight();
        p.sourceDomain = spec.getSourceDomain();
        p.destinationDomain = spec.getDestinationDomain();
        p.destinationContract = AddressLib._bytes32ToAddress(spec.getDestinationContract());
        p.destinationToken = AddressLib._bytes32ToAddress(spec.getDestinationToken());
        p.sourceDepositor = AddressLib._bytes32ToAddress(spec.getSourceDepositor());
        p.destinationRecipient = AddressLib._bytes32ToAddress(spec.getDestinationRecipient());
        p.destinationCaller = AddressLib._bytes32ToAddress(spec.getDestinationCaller());
        p.value = spec.getValue();
        p.specHash = spec.getHash();
        p.hookData = _viewToBytes(spec.getHookData());   // or: spec.getHookData().clone() (view, not pure)
    }

    /// @dev pure, word-aligned replacement for TypedMemView.clone()
    function _viewToBytes(bytes29 v) private pure returns (bytes memory out) {
        uint256 len = v.len();
        uint256 loc = v.loc();
        assembly ("memory-safe") {
            out := mload(0x40)
            mstore(out, len)
            mcopy(add(out, 0x20), loc, len)
            mstore(0x40, add(out, and(add(add(len, 0x20), 0x1f), not(0x1f))))
        }
    }
}
```

Recommended adapter flow around the mint (mirrors `CCTPAdapter`'s pull model):

```solidity
ParsedAttestation memory p = _parseSingleAttestation(attestationPayload);
if (p.destinationCaller != address(this)) revert INVALID_DESTINATION_CALLER();   // must be non-zero AND us
if (p.destinationRecipient != address(this)) revert INVALID_RECIPIENT();          // if the adapter forwards funds
// optional early checks for clearer errors (the minter enforces them anyway):
// if (p.destinationContract != GATEWAY_MINTER) revert ...; if (p.destinationDomain != IGatewayMinter(GATEWAY_MINTER).domain()) revert ...;
uint256 pre = IERC20(p.destinationToken).balanceOf(address(this));
IGatewayMinter(GATEWAY_MINTER).gatewayMint(attestationPayload, signature);       // reverts on any minter failure
uint256 minted = IERC20(p.destinationToken).balanceOf(address(this)) - pre;      // == p.value for USDC; measure anyway
// act on p.hookData / p.specHash / minted
```

`gatewayMint` takes `bytes memory`; pass the calldata slices straight through (`abi.encodeCall` / direct call both
copy). Do not re-encode the payload — the signature is over the exact bytes.

### 7b. Building and signing an attestation in a fork test against the REAL minter

Verified against Ethereum mainnet (fork of `https://ethereum-rpc.publicnode.com`, minter `0x2222…C205`): owner prank →
`addAttestationSigner` → `gatewayMint` minted 100 USDC to the recipient, `isTransferSpecHashUsed` flipped to true,
replay reverted with `TransferSpecHashUsed(hash)`, wrong `msg.sender` reverted.

```solidity
import { Test } from "forge-std/Test.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { AttestationLib } from "evm-gateway/lib/AttestationLib.sol";
import { Attestation } from "evm-gateway/lib/Attestations.sol";
import { TransferSpec } from "evm-gateway/lib/TransferSpec.sol";
import { TransferSpecLib } from "evm-gateway/lib/TransferSpecLib.sol";
import { AddressLib } from "evm-gateway/lib/AddressLib.sol";

interface IGatewayMinterAdmin {
    function owner() external view returns (address);
    function domain() external view returns (uint32);
    function addAttestationSigner(address) external;
    function isAttestationSigner(address) external view returns (bool);
    function isTransferSpecHashUsed(bytes32) external view returns (bool);
    function gatewayMint(bytes memory, bytes memory) external;
}

contract GatewayForkHelpers is Test {
    using MessageHashUtils for bytes32;

    address constant GATEWAY_WALLET = 0x77777777Dcc4d5A8B6E418Fd04D8997ef11000eE;
    address constant GATEWAY_MINTER = 0x2222222d7164433c4C09B0b0D809a9b52C04C205;

    /// Circle-style attestation signature: EIP-191 over keccak256(payload). No EIP-712 domain.
    function _signAttestation(TransferSpec memory spec, uint256 signerPk, uint256 maxBlockHeight)
        internal
        pure
        returns (bytes memory payload, bytes memory signature)
    {
        payload = AttestationLib.encodeAttestation(Attestation({ maxBlockHeight: maxBlockHeight, spec: spec }));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, keccak256(payload).toEthSignedMessageHash());
        signature = abi.encodePacked(r, s, v);
    }

    function _spec(
        uint32 srcDomain, address srcUsdc, address dstUsdc, address depositor,
        address recipient, address destinationCaller, uint256 value, bytes memory hookData
    ) internal view returns (TransferSpec memory) {
        return TransferSpec({
            version: 1,
            sourceDomain: srcDomain,
            destinationDomain: IGatewayMinterAdmin(GATEWAY_MINTER).domain(),
            sourceContract: AddressLib._addressToBytes32(GATEWAY_WALLET),
            destinationContract: AddressLib._addressToBytes32(GATEWAY_MINTER),
            sourceToken: AddressLib._addressToBytes32(srcUsdc),
            destinationToken: AddressLib._addressToBytes32(dstUsdc),
            sourceDepositor: AddressLib._addressToBytes32(depositor),
            destinationRecipient: AddressLib._addressToBytes32(recipient),
            sourceSigner: AddressLib._addressToBytes32(depositor),
            destinationCaller: AddressLib._addressToBytes32(destinationCaller),
            value: value,
            salt: keccak256(abi.encode(vm.randomUint())),   // unique per attestation, else TransferSpecHashUsed
            hookData: hookData
        });
    }

    function _enrollSigner(uint256 signerPk) internal {
        vm.prank(IGatewayMinterAdmin(GATEWAY_MINTER).owner());
        IGatewayMinterAdmin(GATEWAY_MINTER).addAttestationSigner(vm.addr(signerPk));
    }
}
// usage inside a test:
//   vm.createSelectFork(vm.rpcUrl("mainnet")); _enrollSigner(pk);
//   TransferSpec memory s = _spec(6, BASE_USDC, ETH_USDC, depositor, address(adapter), address(adapter), 100e6, hookData);
//   (bytes memory payload, bytes memory sig) = _signAttestation(s, pk, block.number + 100);
//   adapter.receiveAndExecute(payload, sig);   // adapter calls gatewayMint internally
```

Notes: `sourceDomain != destinationDomain` avoids the same-domain `sourceToken == destinationToken` rule; if you use
the same domain, set both tokens to the local USDC. Mainnet USDC's `mint` works because the live minter is a
configured FiatToken minter with a large allowance (`minterAllowance ≈ 97.3M USDC` at the time of checking) — no
MasterMinter pranking needed, unlike `MultichainTestUtils._initializeGatewayContracts`.

## 8. Do not do this

- Do not sign attestations with EIP-712 / `wallet.domainSeparator()` — that is the burn-intent path; the minter
  uses `personal_sign` over `keccak256(payload)`.
- Do not skip `AttestationLib.cursor()` and read fields with `TypedMemView.index` directly — you lose the custom
  errors and get string reverts (or `NULL` views) on malformed input.
- Do not call `AttestationLib._isSet` (private) or rely on `cursor().numElements == 1` to reject sets — a set with
  exactly one element also has `numElements == 1`; check the magic bytes.
- Do not accept `destinationCaller == 0` in the adapter — anyone can then call `gatewayMint` first and the funds
  land at `destinationRecipient` without your `hookData` being executed.
- Do not `abi.decode` the payload or re-encode it before calling `gatewayMint`; the signature covers the raw bytes.
- Do not re-check signer / expiry / replay in the adapter with your own logic; call `isTransferSpecHashUsed` at most
  as a pre-flight view and let the minter be the source of truth.
- Do not build views over `calldata`, or over memory allocated *after* the view was created and then reused
  (`TypedMemView.build` validates against the free memory pointer at creation time only).
- Do not use `TransferSpecLib.getTypedDataHash` in production code (non-memory-safe assembly, wallet-only semantics).
- Do not import `GatewayMinter.sol` into the adapter; use a local minimal interface so the deployed bytecode does not
  depend on the nested OZ upgradeable 5.2.0 tree.
- Do not pass `hookData` longer than `type(uint32).max` when encoding (reverts `TransferSpecHookDataFieldTooLarge`);
  practically, keep `hookData` small — the whole payload is calldata on the destination and Circle attests it as-is.
- Do not assume `maxBlockHeight` is an Arbitrum L2 block on Arbitrum; it is the L1 height (`block.number` there).
- Do not `vm.expectRevert` with `AttestationLib.X` selectors — all errors are declared on `TransferSpecLib`
  (e.g. `TransferSpecLib.InvalidTransferPayloadMagic.selector`).

## 9. Verification performed

- via-IR compile (solc 0.8.30, evm prague, optimizer 200) of the parsing snippet against
  `lib/evm-gateway-contracts/src` + memview-sol: success, no memory-safety warnings.
- Local tests: round-trip of all fields incl. 37-byte and empty `hookData` (`clone()` and `mcopy` helper agree),
  `specHash == keccak256(encodeTransferSpec(spec))`, set rejection by magic, and revert selectors for: too short,
  `InvalidTransferPayloadMagic`, `TransferPayloadHeaderTooShort(40, 8)`, `TransferPayloadOverallLengthMismatch`,
  `InvalidTransferSpecMagic`, `InvalidTransferSpecVersion(2)`.
- Mainnet fork test against the real `GatewayMinter` proxy: `owner()` prank → `addAttestationSigner` →
  `gatewayMint` mints 100e6 USDC, `isTransferSpecHashUsed` true, replay → `TransferSpecHashUsed`, wrong caller reverts.
- Deployed implementation bytecode diffed against the vendored artifact: identical modulo UUPS `__self` immutable.

## 10. References

- Vendored sources: `/Users/cosming/1.Coding/Superform/v2-core/lib/evm-gateway-contracts/src/lib/{AttestationLib,Attestations,TransferSpecLib,TransferSpec,Cursor,AddressLib}.sol`, `src/modules/minter/Mints.sol`, `src/GatewayMinter.sol`, `src/GatewayCommon.sol`, `src/modules/common/{Denylist,Domain,Pausing,TokenSupport,TransferSpecHashes}.sol`, `src/interfaces/IMintableToken.sol`
- TypedMemView: `/Users/cosming/1.Coding/Superform/v2-core/lib/evm-gateway-contracts/lib/memview-sol/contracts/TypedMemView.sol` (v2.1.1)
- Test utils: `/Users/cosming/1.Coding/Superform/v2-core/lib/evm-gateway-contracts/test/util/{SignatureTestUtils,MultichainTestUtils,DeployUtils,ForkTestUtils,TransferPayloadTestUtils}.sol`
- Existing v2-core integration: `src/hooks/bridges/circle/CircleGatewayMinterHook.sol`, `test/integration/circle/CrosschainTestsGateway.t.sol` (skipped), `test/unit/hooks/bridges/CircleGatewayUnitTests.sol`, `test/utils/InternalHelpers.sol`, `script/utils/Constants.sol:182-184`, `src/adapters/CCTPAdapter.sol` (pull-model adapter to mirror)
- Upstream: https://github.com/circlefin/evm-gateway-contracts (master, CHANGELOG.md), commits since vendored: `adf2435` (1271 contract signers), `2341ea7` (cursor refactor, BurnIntentLib only), `ee628dc` (batches), `fd51093` (1.3.0)
- Circle docs: https://developers.circle.com/gateway/references/contract-addresses , https://developers.circle.com/gateway/references/technical-guide , https://developers.circle.com/api-reference/gateway/all/create-transfer-attestation , https://developers.circle.com/gateway/references/contract-interfaces-and-events
- Scratch verification project (compile + tests): `/private/tmp/claude-501/-Users-cosming-1-Coding-Superform-v2-core/dca83915-6cd3-4650-bc7b-f271eb14f06c/scratchpad/gwproj/` (`contracts/Snippet.sol`, `test/Snippet.t.sol`)
