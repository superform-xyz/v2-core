# CCTP V2 Destination-Side Mechanics — Reference

Source: `circlefin/evm-cctp-contracts@master` read directly, cross-verified against
developers.circle.com/cctp and live `eth_getCode`/`eth_call` against public RPCs (Sept 2026).

## 1. Hook execution semantics — CONFIRMED: no auto-execution

`MessageTransmitterV2.receiveMessage` verifies, mints, and stops:

```solidity
function receiveMessage(bytes calldata message, bytes calldata attestation)
    external override whenNotPaused returns (bool success)
{
    (bytes32 _nonce, uint32 _sourceDomain, bytes32 _sender, address _recipient,
     uint32 _finalityThresholdExecuted, bytes memory _messageBody) =
        _validateReceivedMessage(message, attestation);

    usedNonces[_nonce] = NONCE_USED;

    if (_finalityThresholdExecuted < FINALITY_THRESHOLD_FINALIZED) {
        require(IMessageHandlerV2(_recipient).handleReceiveUnfinalizedMessage(...), "...");
    } else {
        require(IMessageHandlerV2(_recipient).handleReceiveFinalizedMessage(...), "...");
    }
    emit MessageReceived(...);
    return true;
}
```

`_recipient` is the message header's `recipient` field, which for `depositForBurnWithHook` is always
**`TokenMessengerV2`** on the destination domain — not the mint recipient, not a hook target.
`TokenMessengerV2._handleReceiveMessage` → `_validatedReceivedMessage` → `_mintAndWithdraw` →
`TokenMinterV2.mint` → USDC `mint()`. **`hookData` is never read by `TokenMessengerV2`.**

Circle docs: *"CCTP does not implement hook execution in the core protocol. Instead, hooks are treated
as opaque metadata passed along with the burn message."* Only the caller who supplied `message` to
`receiveMessage` has access to those bytes. **Whoever relays the message is fully responsible for
executing the hook.** No push callback exists.

## 2. Circle's `CCTPHookWrapper` — reference implementation

At `src/examples/CCTPHookWrapper.sol` (under `src/`, not repo root). Solidity 0.7.6, `Ownable2Step`.

```solidity
contract CCTPHookWrapper is Ownable2Step {
    IReceiverV2 public immutable messageTransmitter;
    uint32 public constant supportedMessageVersion = 1;
    uint32 public constant supportedMessageBodyVersion = 1;
    uint256 internal constant ADDRESS_BYTE_LENGTH = 20;

    function relay(bytes calldata message, bytes calldata attestation)
        external virtual
        returns (bool relaySuccess, bool hookSuccess, bytes memory hookReturnData)
    {
        _checkOwner();                                    // <-- onlyOwner

        bytes29 _msg = message.ref(0);
        MessageV2._validateMessageFormat(_msg);
        require(MessageV2._getVersion(_msg) == supportedMessageVersion, "Invalid message version");

        bytes29 _msgBody = MessageV2._getMessageBody(_msg);
        BurnMessageV2._validateBurnMessageFormat(_msgBody);
        require(BurnMessageV2._getVersion(_msgBody) == supportedMessageBodyVersion, "Invalid message body version");

        relaySuccess = messageTransmitter.receiveMessage(message, attestation);
        require(relaySuccess, "Receive message failed");

        bytes29 _hookData = BurnMessageV2._getHookData(_msgBody);
        if (_hookData.isValid()) {
            uint256 _hookDataLength = _hookData.len();
            if (_hookDataLength >= ADDRESS_BYTE_LENGTH) {
                address _target = _hookData.indexAddress(0);
                bytes memory _hookCalldata = _hookData.postfix(_hookDataLength - ADDRESS_BYTE_LENGTH, 0).clone();
                (hookSuccess, hookReturnData) = _executeHook(_target, _hookCalldata);
            }
        }
    }

    function _executeHook(address _hookTarget, bytes memory _hookCalldata)
        internal virtual returns (bool _success, bytes memory _returnData)
    { (_success, _returnData) = address(_hookTarget).call(_hookCalldata); }
}
```

### ⚠️ Finding that challenges an interview premise

**Circle's `relay()` is `onlyOwner`, not permissionless.** Their own doc-comment explains why:

> *"Due to the lack of atomicity with the hook call, permissionless relay of messages containing hooks
> via an implementation like this contract should be carefully considered, as a malicious caller could
> use a low gas attack to consume the message's nonce without executing the hook."*

> *"WARNING: this implementation does NOT enforce atomicity in the hook call. This is to prevent a
> failed hook call from preventing relay of a message if this contract is set as the destinationCaller."*

Circle independently identified the same risk logged as open question 5 in the interview notes, and
mitigated it by **caller-gating `relay()`** rather than by restricting `destinationCaller` — their
wrapper never checks `destinationCaller` at all.

**How this maps to the Superform design** (permissionless `relay()` + `destinationCaller == adapter`):
the vector narrows but does not disappear.
- A third party **cannot** call `MessageTransmitterV2.receiveMessage` directly to burn the nonce —
  `destinationCaller` restricts that to the adapter address (see §5).
- A third party **can** still call the adapter's own permissionless `relay()` with a tight gas limit:
  `receiveMessage` succeeds (mint completes, nonce consumed), and the `try/catch`'d
  `processBridgedExecution` is starved into the `catch` branch. The nonce is now spent; the message
  cannot be re-relayed.
- Residual impact is bounded because tokens are forwarded to the account *before* the executor call,
  and `SuperDestinationExecutor.processBridgedExecution` is itself permissionless — anyone can
  re-drive the same payload afterwards (this is precisely the recovery path `RelayAdapter.sol:18`
  documents for solvers). So the griefing costs one atomic execution, not the funds.

**This is a deliberate divergence from Circle's reference pattern and must be stated in the spec**,
with the reasoning above — a reviewer will otherwise ask why the adapter isn't `onlyOwner`.

### Other wrapper details
- Validates header version and body version both `== 1`; reverts on V1 or any future version.
- Uses `TypedMemView` (`bytes29`) rather than `BytesLib`.
- **Its hookData convention is `target(20 bytes) || hookCallData(dynamic)`, ABI-*packed*.** Superform's
  `CCTPSendHook` emits a full ABI-*encoded* 6-tuple with no leading target address. **The adapter must
  NOT reuse `CCTPHookWrapper`'s hookData parsing** — decode the 6-tuple with `abi.decode`, matching
  `DebridgeAdapter._decodeMessage`.
- `hookData` shorter than 20 bytes is silently skipped (no hook, no revert).
- `test/examples/CCTPHookWrapper.t.sol` is a useful template for our mock-transmitter unit tests.

## 3. Message byte layout

### 3a. `MessageV2` header (`src/messages/v2/MessageV2.sol`), offsets from byte 0 of raw `message`

| Field | Bytes | Type | Offset |
|---|---|---|---|
| `version` | 4 | uint32 | 0 |
| `sourceDomain` | 4 | uint32 | 4 |
| `destinationDomain` | 4 | uint32 | 8 |
| `nonce` | 32 | bytes32 | 12 |
| `sender` | 32 | bytes32 | 44 |
| `recipient` | 32 | bytes32 | 76 |
| `destinationCaller` | 32 | bytes32 | 108 |
| `minFinalityThreshold` | 4 | uint32 | 140 |
| `finalityThresholdExecuted` | 4 | uint32 | 144 |
| `messageBody` | dynamic | bytes | **148** (`MESSAGE_BODY_INDEX`) |

### 3b. `BurnMessageV2` body (`src/messages/v2/BurnMessageV2.sol`)

| Field | Bytes | Type | Offset in body | **Absolute offset in raw message** |
|---|---|---|---|---|
| `version` | 4 | uint32 | 0 | 148 |
| `burnToken` | 32 | bytes32 | 4 | 152 |
| `mintRecipient` | 32 | bytes32 | 36 | 184 |
| `amount` | 32 | uint256 | 68 | 216 |
| `messageSender` | 32 | bytes32 | 100 | 248 |
| `maxFee` | 32 | uint256 | 132 | 280 |
| `feeExecuted` | 32 | uint256 | 164 | 312 |
| `expirationBlock` | 32 | uint256 | 196 | 344 |
| **`hookData`** | dynamic | bytes | **228** | **376** |

Minimum valid burn-message body length is 228 bytes (`_validateBurnMessageFormat`).

`BytesLib` calls against the raw attested `message`:

```solidity
// mintRecipient:   message.slice(184, 32)
// amount:          message.slice(216, 32)
// maxFee:          message.slice(280, 32)
// feeExecuted:     message.slice(312, 32)
// expirationBlock: message.slice(344, 32)
// destinationCaller (defensive check): message.slice(108, 32)
// hookData:        message.slice(376, message.length - 376)  -> abi.decode as the 6-tuple
```

Both structs are `abi.encodePacked`, not `abi.encode` — the `uint32` fields are 4-byte packed, not
left-padded to 32. That is why offsets are non-round.

## 4. Addresses & domain IDs

**`MessageTransmitterV2` = `0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`** — same deterministic address
on every chain. Verified by `eth_getCode`: identical 4350-byte proxy bytecode live on Ethereum, Base,
Arbitrum, Optimism, Polygon, Unichain.

`TokenMessengerV2` = `0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d` — matches what `CCTPSendHook` is
deployed with.

Both sit behind EIP-1967 transparent proxies — configure the **proxy** address, never an implementation.

| Chain | Domain | Chain | Domain |
|---|---|---|---|
| Ethereum | 0 | Linea | 11 |
| Avalanche | 1 | Codex | 12 |
| OP Mainnet | 2 | Sonic | 13 |
| Arbitrum | 3 | World Chain | 14 |
| Base | 6 | Monad | 15 |
| Polygon PoS | 7 | Sei | 16 |
| Unichain | 10 | BNB Smart Chain | 17 |

Runtime-confirmed on Ethereum mainnet: `MessageTransmitterV2.version() == 1`; legacy V1
`MessageTransmitter` (`0x0a992d191deec32afe36203ad87d7d289a738f81`) `.version() == 0`;
`TokenMessengerV2.messageBodyVersion() == 1`.

⚠️ **BSC caveat (UNVERIFIED):** CCTP domain 17 exists for BNB Smart Chain, but one secondary source
raised an unconfirmed USDC-vs-USYC support asymmetry there. Confirm independently against Circle's
supported-chains page — or by checking `MessageTransmitterV2` has code plus a registered remote
`TokenMessengerV2` for our source domains — before deploying the adapter to BSC.

## 5. `destinationCaller` enforcement

```solidity
if (_msg._getDestinationCaller() != bytes32(0)) {
    require(_msg._getDestinationCaller() == msg.sender.toBytes32(), "Invalid caller for message");
}
```

- `bytes32(0)` → check skipped, anyone may relay.
- Non-zero → `msg.sender` must match exactly, else revert **`"Invalid caller for message"`**.
- No bypass, escrow, or admin override. A restricted message can never be relayed by anyone else.
- **Why "permissionless `relay()` + restricted `destinationCaller`" works:** when the adapter calls
  `receiveMessage`, `msg.sender` as seen by the transmitter is the **adapter contract address**, not
  the EOA that called `relay()`. The restriction is satisfied by the call chain passing through the
  adapter, regardless of who triggered it.

## 6. Fees

```solidity
uint256 _expirationBlock = _msg._getExpirationBlock();
require(_expirationBlock == 0 || _expirationBlock > block.number, "Message expired and must be re-signed");
_amount = _msg._getAmount();
_fee = _msg._getFeeExecuted();
require(_fee == 0 || _fee < _amount, "Fee equals or exceeds amount");
require(_fee <= _msg._getMaxFee(), "Fee exceeds max fee");
...
_mintAndWithdraw(_remoteDomain, _burnToken, _mintRecipient, _amount - _fee, _fee);
```

- Recipient receives **`amount - feeExecuted`** — confirms the interview assumption. The fee is minted
  separately to the `feeRecipient` role (two `ITokenMinterV2.mint` calls, second only when `fee > 0`).
- `feeExecuted` is fixed by Circle's attestation service at signing time and is readable straight from
  the attested body at absolute offset 312 — no extra RPC needed.
- Fast (`finalityThresholdExecuted < 2000`) vs finalized (`>= 2000`) dispatch; `TokenMessengerV2` also
  requires `>= TOKEN_MESSENGER_MIN_FINALITY_THRESHOLD (500)` on the unfinalized path.
- Circle: *"CCTP charges fees on Fast Transfers only. Standard Transfers are free."* Standard transfers
  should carry `feeExecuted == 0`.
- Circle also offers a newer prepaid/upfront source-side fee option. Our balance-based forwarding is
  correct either way since it reads the balance, not the fee field — but note it in the spec.

## 7. Return value & events

- Returns `bool success`, and only ever returns `true` — every failure reverts. "Returns true" and
  "did not revert" are equivalent today.
- **Does NOT return the minted amount.**
- Events: `MessageTransmitterV2.MessageReceived(caller, sourceDomain, nonce, sender,
  finalityThresholdExecuted, messageBody)`; and from a *different* contract,
  `TokenMessengerV2.MintAndWithdraw(mintRecipient, amount, mintToken, feeCollected)`.
- **Guidance:** don't consume return values or events for the amount. Read
  `IERC20(usdc).balanceOf(address(this))` — simplest, and matches `StargateAdapterV2`/`RelayAdapter`
  precedent already in the codebase.

## 8. Replay & nonce

- `nonce` is `bytes32` in V2 (V1 used `uint64`), assigned off-chain by Circle, at offset 12.
- `mapping(bytes32 => uint256) public usedNonces` in `BaseMessageTransmitter`, `NONCE_USED = 1`.
- `require(usedNonces[_nonce] == 0, "Nonce already used")` before dispatch. Duplicate relay **reverts**
  with exactly `"Nonce already used"` — not a silent no-op.
- The nonce write happens before the handler call, but a reverting handler rolls the write back too, so
  **a failed mint does not burn the nonce**; the message stays retriable.
- `usedNonces[bytes32(0)]` is pre-claimed at `initialize()`.
- Confirms the interview note: replay protection is internal; the adapter adds none.

## 9. Failure modes

| Failure | Where | Revert string |
|---|---|---|
| Wrong `destinationCaller` | `MessageTransmitterV2._validateReceivedMessage` | `"Invalid caller for message"` |
| Nonce already used | same | `"Nonce already used"` |
| Wrong destination domain | same | `"Invalid destination domain"` |
| Wrong message version | same | `"Invalid message version"` |
| Malformed / short message | `MessageV2._validateMessageFormat` | `"Malformed message"` / `"Invalid message: too short"` |
| Paused (transmitter or `TokenMinterV2`) | `Pausable.whenNotPaused` | `"Pausable: paused"` |
| Bad attestation length | `Attestable._verifyAttestationSignatures` | `"Invalid attestation length"` |
| Unordered / duplicate signatures | same | `"Invalid signature order or dupe"` |
| Non-enabled attester | same | `"Invalid signature: not attester"` |
| Expired message | `TokenMessengerV2._validatedReceivedMessage` | `"Message expired and must be re-signed"` |
| Fee >= amount / fee > maxFee | same | `"Fee equals or exceeds amount"` / `"Fee exceeds max fee"` |
| Wrong body version | same | `"Invalid message body version"` |
| Finality threshold < 500 | `handleReceiveUnfinalizedMessage` | `"Unsupported finality threshold"` |
| Adapter is USDC-blacklisted | `TokenMinterV2.mint` → USDC | `"Blacklistable: account is blacklisted"` |
| Unsupported token pair | `TokenMinterV2._getLocalToken` | `"Mint token not supported"` |

**Design-critical property:** every failure reverts the *entire* call. There is no
"succeeds-with-no-mint" state — either the mint happens and the nonce is consumed, or nothing happens
and the message stays replayable.

→ **The `try/catch` belongs only around `processBridgedExecution`, never around `receiveMessage`.**
If `receiveMessage` reverts there is nothing to catch — no tokens moved. The interview decision is correct.

**Blacklist note:** if the adapter address is ever USDC-blacklisted, affected messages are permanently
unmintable — `mintRecipient` is baked into the signed message and cannot be re-attested to a different
address. Worth an explicit risk-register line.

**Gas-limit griefing** (open question 5): a relayer controls the gas forwarded to `relay()`, so it can
supply enough for `receiveMessage` but starve the `try/catch`'d executor call into the `catch` branch.
Funds are not lost (tokens are already forwarded to the account, and `processBridgedExecution` can be
re-driven permissionlessly), but one atomic execution is lost and the nonce is spent. Same exposure
already accepted for `StargateAdapterV2` / `RelayAdapter`; inherent to any `try/catch` adapter.

## 10. Version detection

Both V1 and V2 put a 4-byte `version` at offset 0.

- V1 (`src/messages/Message.sol`): body at offset 116, fixed 132-byte `BurnMessage` with **no `hookData`**.
- V2: body at offset 148, per §3a/3b.

**Read `uint32` at offset 0.** `0` → V1, reject. `1` → V2, proceed. Anything else → reject.
Exactly what `CCTPHookWrapper` does.
