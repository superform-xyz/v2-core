# CCTP V2 (EVM) — Framework Reference for a Destination Adapter

Technical reference for building a destination adapter that calls
`MessageTransmitterV2.receiveMessage` and parses `hookData` out of a CCTP V2 burn
message.

**Primary sources**
- Circle docs: CCTP EVM Smart Contracts — https://developers.circle.com/cctp/evm-smart-contracts
- Circle docs: Message Format — https://developers.circle.com/stablecoins/message-format
- Circle docs: Finality Thresholds and Fees — https://developers.circle.com/cctp/cctp-finality-and-fees
- Circle docs: Supported Blockchains / Domains — https://developers.circle.com/cctp/cctp-supported-blockchains
- Source: `circlefin/evm-cctp-contracts` (branch `master`) — https://github.com/circlefin/evm-cctp-contracts
  - `src/v2/MessageTransmitterV2.sol`
  - `src/v2/TokenMessengerV2.sol`
  - `src/messages/v2/MessageV2.sol`
  - `src/messages/v2/BurnMessageV2.sol`
  - `src/roles/Attestable.sol` (attester management + signature verification, inherited by V2)

> Note: CCTP V2 contracts are CREATE2-deployed, so `MessageTransmitterV2` and
> `TokenMessengerV2` share **the same address on every EVM chain** (see §7).

---

## 1. `MessageTransmitterV2.receiveMessage`

Source: `src/v2/MessageTransmitterV2.sol`.

```solidity
function receiveMessage(
    bytes calldata message,
    bytes calldata attestation
) external override whenNotPaused returns (bool success)
```

**Return:** returns `true` on success. In practice it does **not** return `false`
on a bad message — invalid input **reverts** (see below). Treat a non-reverting
call as success.

**What it does on success:**
1. Validates the attestation over `message` via `_verifyAttestationSignatures`
   (inherited from `Attestable`).
2. Parses the outer `MessageV2` header (see §2), enforces `version`,
   `destinationDomain == localDomain`, `recipient != 0`, and the
   `destinationCaller` rule (see below).
3. Marks the message nonce used (replay protection, see below).
4. Routes to the recipient contract named in the header's `recipient` field by
   calling one of the `IMessageHandlerV2` callbacks, selected by
   `finalityThresholdExecuted`:
   - `finalityThresholdExecuted < FINALITY_THRESHOLD_FINALIZED` (2000) →
     `IMessageHandlerV2(recipient).handleReceiveUnfinalizedMessage(sourceDomain, sender, finalityThresholdExecuted, messageBody)`
   - otherwise →
     `IMessageHandlerV2(recipient).handleReceiveFinalizedMessage(sourceDomain, sender, finalityThresholdExecuted, messageBody)`
   Both branches `require` the handler to return `true`, else the whole call
   reverts. For a USDC burn/mint, `recipient` is `TokenMessengerV2` and the
   handler performs the mint (see §4).

**Invalid attestation:** it **reverts** (does not return `false`).
`_verifyAttestationSignatures` reverts with strings such as
`"Invalid attestation length"`, `"Invalid signature order or dupe"`, and
`"Invalid signature: not attester"`.

**Replay / nonce protection:** uses a `usedNonces` mapping keyed by the header
`nonce` (a `bytes32` chosen by Circle/Iris, not a sequential counter as in V1).
```solidity
require(usedNonces[_nonce] == 0, "Nonce already used");
// ...after validation...
usedNonces[_nonce] = NONCE_USED;
```
So each message can be received exactly once.

**`destinationCaller`:** when the header `destinationCaller` is non-zero, only
that address may submit the message:
```solidity
if (_msg._getDestinationCaller() != bytes32(0)) {
    require(
        _msg._getDestinationCaller() == msg.sender.toBytes32(),
        "Invalid caller for message"
    );
}
```
If `destinationCaller == bytes32(0)`, anyone can call `receiveMessage`
(permissionless relay). **Adapter implication:** if you want your adapter to be
the only address that can trigger the mint+hook, the source-chain call must set
`destinationCaller` to your adapter's address (bytes32-left-padded); otherwise a
third party can front-run the `receiveMessage` call (though the mint still goes
to `mintRecipient` regardless).

---

## 2. Outer message wire format — `MessageV2`

Source: `src/messages/v2/MessageV2.sol`. Big-endian, tightly packed, fixed
148-byte header followed by the dynamic body.

| Field | Index constant | Byte offset | Length | Type |
|---|---|---|---|---|
| version | `VERSION_INDEX` | 0 | 4 | uint32 |
| sourceDomain | `SOURCE_DOMAIN_INDEX` | 4 | 4 | uint32 |
| destinationDomain | `DESTINATION_DOMAIN_INDEX` | 8 | 4 | uint32 |
| nonce | `NONCE_INDEX` | 12 | 32 | bytes32 |
| sender | `SENDER_INDEX` | 44 | 32 | bytes32 |
| recipient | `RECIPIENT_INDEX` | 76 | 32 | bytes32 |
| destinationCaller | `DESTINATION_CALLER_INDEX` | 108 | 32 | bytes32 |
| minFinalityThreshold | `MIN_FINALITY_THRESHOLD_INDEX` | 140 | 4 | uint32 |
| finalityThresholdExecuted | `FINALITY_THRESHOLD_EXECUTED_INDEX` | 144 | 4 | uint32 |
| messageBody | `MESSAGE_BODY_INDEX` | 148 | dynamic | bytes |

Verbatim constants:
```solidity
uint8 private constant VERSION_INDEX = 0;
uint8 private constant SOURCE_DOMAIN_INDEX = 4;
uint8 private constant DESTINATION_DOMAIN_INDEX = 8;
uint8 private constant NONCE_INDEX = 12;
uint8 private constant SENDER_INDEX = 44;
uint8 private constant RECIPIENT_INDEX = 76;
uint8 private constant DESTINATION_CALLER_INDEX = 108;
uint8 private constant MIN_FINALITY_THRESHOLD_INDEX = 140;
uint8 private constant FINALITY_THRESHOLD_EXECUTED_INDEX = 144;
uint8 private constant MESSAGE_BODY_INDEX = 148;
```

**Total header length = 148 bytes.** Body is retrieved as
`message.slice(148, message.len() - 148)`. Note V2's `version` is 1 and the
`nonce` is a full `bytes32` (V1 used a `uint64` at offset 12 and a 116-byte
header — do not reuse V1 offsets).

`finalityThresholdExecuted` semantics (from
https://developers.circle.com/cctp/cctp-finality-and-fees): `<= 1000` = Fast
(Circle-attested / "confirmed"), `2000` = Standard (finalized). Values below 1000
are treated as 1000; above 1000 as 2000.

---

## 3. Burn message body — `BurnMessageV2`

Source: `src/messages/v2/BurnMessageV2.sol`. This is what sits at `messageBody`
(offset 148 of the outer message) for a USDC transfer.

| Field | Byte offset (within body) | Length | Type |
|---|---|---|---|
| version | 0 | 4 | uint32 |
| burnToken | 4 | 32 | bytes32 |
| mintRecipient | 36 | 32 | bytes32 |
| amount | 68 | 32 | uint256 |
| messageSender | 100 | 32 | bytes32 |
| maxFee | 132 | 32 | uint256 |
| feeExecuted | 164 | 32 | uint256 |
| expirationBlock | 196 | 32 | uint256 |
| hookData | 228 | dynamic | bytes |

Verbatim constants (partial):
```solidity
uint8 private constant MAX_FEE_INDEX = 132;
uint8 private constant FEE_EXECUTED_INDEX = 164;
uint8 private constant EXPIRATION_BLOCK_INDEX = 196;
uint8 private constant HOOK_DATA_INDEX = 228;
```

**Fixed body length before hookData = 228 bytes.** `hookData` is everything from
offset 228 to the end of the body.

**Slicing hookData from the raw outer `message`:** absolute offset =
`148 (outer header) + 228 (burn body header) = 376`. So:
```solidity
bytes memory hookData = message[376:];   // calldata slice; empty if none
```
`hookData` is empty for a plain `depositForBurn` and non-empty for
`depositForBurnWithHook`.

---

## 4. `TokenMessengerV2.depositForBurn(WithHook)` and the mint

Source: `src/v2/TokenMessengerV2.sol`.

```solidity
function depositForBurn(
    uint256 amount,
    uint32  destinationDomain,
    bytes32 mintRecipient,
    address burnToken,
    bytes32 destinationCaller,
    uint256 maxFee,
    uint32  minFinalityThreshold
) external notDenylistedCallers;

function depositForBurnWithHook(
    uint256 amount,
    uint32  destinationDomain,
    bytes32 mintRecipient,
    address burnToken,
    bytes32 destinationCaller,
    uint256 maxFee,
    uint32  minFinalityThreshold,
    bytes   calldata hookData
) external notDenylistedCallers;
```

**How the params flow into the message:**
- `mintRecipient`, `amount`, `maxFee`, `hookData` and the burn token are packed
  into the `BurnMessageV2` body via
  `BurnMessageV2._formatMessageForRelay(messageBodyVersion, burnToken.toBytes32(), mintRecipient, amount, msg.sender.toBytes32(), maxFee, hookData)`.
  `messageSender` is the source-chain caller (`msg.sender`).
- `destinationCaller` is **not** in the burn body; it is passed to the relayer /
  `MessageTransmitterV2.sendMessage`, so it lands in the **outer** `MessageV2`
  header `destinationCaller` field (offset 108).
- `feeExecuted` and `expirationBlock` are populated by Circle/Iris during
  attestation, not by the caller. `depositForBurnWithHook` requires non-empty
  `hookData`.

**How the mint works (destination side):** `receiveMessage` routes to
`TokenMessengerV2.handleReceiveFinalizedMessage` /
`handleReceiveUnfinalizedMessage`, which validate the burn body and mint via the
local token minter:
```solidity
_mintAndWithdraw(_remoteDomain, _burnToken, _mintRecipient, _amount - _fee, _fee);
```
`mintRecipient` receives `amount - feeExecuted`; the `feeExecuted` portion is
minted to Circle's fee recipient. `feeExecuted <= maxFee`.

**Balance-delta measurement:** a destination adapter that is the `mintRecipient`
should measure `USDC.balanceOf(adapter)` before/after `receiveMessage`. The
delta equals `amount - feeExecuted`, i.e. the **net** minted amount — do not
assume it equals the source `amount`. Read `feeExecuted` (body offset 164) if you
need the gross amount.

---

## 5. Is hookData executed automatically?

**No.** `hookData` is opaque to CCTP. `TokenMessengerV2` encodes it into the burn
body on the source chain and, on the destination chain, mints to `mintRecipient`
and **ignores** `hookData` entirely — there is no auto-callback to
`mintRecipient` and no execution of `hookData` anywhere in the V2 contracts.
Interpreting/executing `hookData` is entirely the responsibility of the
destination recipient/relayer (i.e. your adapter).

Practical consequence for the adapter design: the adapter must itself
(a) call `receiveMessage` (or observe that someone did), (b) receive/measure the
minted USDC (be the `mintRecipient`, or pull from it), and (c) parse and act on
`hookData` sliced from the raw message per §3. CCTP will not call you back with
the hook.

---

## 6. Attestation / attester mechanics (for fork tests)

Source: `src/roles/Attestable.sol` (inherited by the V2 transmitter via
`AttestableV2`).

**Signature format:** `attestation` is the concatenation of 65-byte
`(r,s,v)` ECDSA signatures over `keccak256(message)`, one per required attester,
sorted by **strictly increasing recovered signer address**.

`_verifyAttestationSignatures` logic:
- `require(attestation.length == 65 * signatureThreshold, "Invalid attestation length");`
- For each 65-byte chunk: `address recovered = ECDSA.recover(keccak256(message), sig);`
- `require(recovered > lastAttester, "Invalid signature order or dupe");` (enforces ascending order, blocks duplicates)
- `require(isEnabledAttester[recovered], "Invalid signature: not attester");`

**Attester management (onlyAttesterManager unless noted):**
- `enableAttester(address)` — adds an attester (must be nonzero, not already enabled).
- `disableAttester(address)` — removes one; reverts `"Too few enabled attesters"` (min 2) and `"Signature threshold is too low"`.
- `setSignatureThreshold(uint256)` — reverts `"Invalid signature threshold"` (nonzero), `"New signature threshold too high"` (≤ enabled count), `"Signature threshold already set"`.
- `updateAttesterManager(address)` — owner only.

**Fork-test recipe for a crafted message + valid attestation:**
1. On the forked destination chain, get the `MessageTransmitterV2` owner /
   attesterManager (`attesterManager()`), impersonate it with
   `vm.prank`/`vm.startPrank`.
2. Reduce trust surface to a single key you control: `setSignatureThreshold(1)`
   then `enableAttester(vm.addr(pk))`. (You cannot drop below 2 enabled
   attesters, but threshold 1 means only one signature is checked; make sure your
   controlled attester is the one whose signature you provide, and that
   ascending-order/enabled checks pass. Alternatively disable the real attesters
   down to the 2-attester floor plus your key and sign with the lowest.)
3. Build the outer `MessageV2` bytes yourself (packed per §2) wrapping a
   `BurnMessageV2` body (§3) with your desired `mintRecipient`/`hookData`. Use a
   unique `nonce` (any unused `bytes32`), set `destinationDomain` = local domain,
   `finalityThresholdExecuted` (e.g. 2000 for finalized routing), and
   `destinationCaller` = 0 or your adapter.
4. `digest = keccak256(message)`; `(v,r,s) = vm.sign(pk, digest)`;
   `attestation = abi.encodePacked(r,s,v)`.
5. Call `receiveMessage(message, attestation)` from the adapter (or any address
   if `destinationCaller == 0`). The transmitter will route to `TokenMessengerV2`
   which mints via the local minter — note the minter must recognize the
   transmitter, which it already does on a mainnet fork.

Alternatively (no attester swap): impersonate the live attester set is
impossible without their keys, so overriding the attester set as above is the
standard fork approach.

---

## 7. Addresses, domain IDs, and V2 availability

**CCTP V2 contract addresses (identical on all EVM chains via CREATE2):**
- `MessageTransmitterV2`: `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`
- `TokenMessengerV2`: `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`

Confirmed for Ethereum, Arbitrum, Base, OP Mainnet, Polygon PoS, Avalanche,
Linea, Unichain (and the rest of the V2 set). Always re-verify against
https://developers.circle.com/cctp/evm-smart-contracts before deploy — a few
newer/non-standard chains can differ.

**CCTP domain IDs** (chain-agnostic; NOT EVM chainIds) — source
https://developers.circle.com/cctp/cctp-supported-blockchains:

| Chain | Domain | CCTP V2 |
|---|---|---|
| Ethereum | 0 | yes |
| Avalanche | 1 | yes |
| OP Mainnet | 2 | yes |
| Arbitrum | 3 | yes |
| Noble | 4 | V1 only |
| Solana | 5 | yes |
| Base | 6 | yes |
| Polygon PoS | 7 | yes |
| Sui | 8 | V1 only |
| Aptos | 9 | V1 only |
| Unichain | 10 | yes |
| Linea | 11 | yes |
| Codex | 12 | yes |
| Sonic | 13 | yes |
| World Chain | 14 | yes |
| Monad | 15 | yes |
| Sei | 16 | yes |
| BNB Smart Chain | 17 | yes |
| XDC | 18 | yes |
| HyperEVM | 19 | yes |
| Ink | 21 | yes |
| Plume | 22 | yes |
| Starknet | 25 | yes |
| Arc testnet | 26 | yes |
| Stellar | 27 | yes |
| ... | ... | ... |

CCTP V2 is live on all supported EVM chains above; **Noble (4), Sui (8), and
Aptos (9) are CCTP V1 only** (no V2 burn-with-hook). Domain IDs feed the
`sourceDomain`/`destinationDomain` header fields and the
`destinationDomain` argument of `depositForBurn`.

---

## Adapter build checklist (derived)

1. Adapter (or its designated relayer) calls
   `MessageTransmitterV2.receiveMessage(message, attestation)`. Bad attestation
   reverts — no need to check a bool.
2. To gate who can relay, set source-side `destinationCaller` to the adapter's
   bytes32 address; else relay is permissionless.
3. Mint of `amount - feeExecuted` USDC lands at `mintRecipient`. Make the adapter
   the `mintRecipient` and use a balance delta, or read `amount`/`feeExecuted`
   from the body.
4. Slice `hookData` from the raw `message` at absolute offset **376**
   (`message[376:]`) and act on it — CCTP never calls back.
5. Guard against replay at the adapter level too if needed; CCTP's `usedNonces`
   already prevents a second `receiveMessage` for the same message.
