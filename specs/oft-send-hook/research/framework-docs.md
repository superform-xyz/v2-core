# LayerZero V2 OFT Standard - Framework Documentation Research

## 1. IOFT Interface - Exact Function Signatures

Source: [LayerZero-Labs/devtools IOFT.sol](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/interfaces/IOFT.sol)

```solidity
interface IOFT {
    function send(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    function token() external view returns (address);
    function approvalRequired() external view returns (bool);
    function sharedDecimals() external view returns (uint8);
    function oftVersion() external view returns (bytes4 interfaceId, uint64 version);

    function quoteOFT(
        SendParam calldata _sendParam
    ) external view returns (OFTLimit memory, OFTFeeDetail[] memory, OFTReceipt memory);
}
```

## 2. SendParam Struct - IDENTICAL to Stargate

**The SendParam struct is the same in both IOFT and IStargate:**

```solidity
struct SendParam {
    uint32 dstEid;        // Destination endpoint ID
    bytes32 to;           // Recipient address as bytes32
    uint256 amountLD;     // Amount in local decimals
    uint256 minAmountLD;  // Minimum amount (slippage)
    bytes extraOptions;   // Executor options (TYPE_3 encoded)
    bytes composeMsg;     // Compose message payload
    bytes oftCmd;         // OFT command (empty for generic OFT, bus/taxi for Stargate)
}
```

For generic OFTs, pass `oftCmd = bytes("")`.

## 3. Key Differences: IOFT.send() vs IStargate.sendToken()

| Aspect | IOFT.send() | IStargate.sendToken() |
|---|---|---|
| Function name | `send` | `sendToken` |
| Selector | Different 4-byte selector | Different 4-byte selector |
| Parameters | `(SendParam, MessagingFee, address)` | `(SendParam, MessagingFee, address)` |
| Returns | `(MessagingReceipt, OFTReceipt)` | `(MessagingReceipt, OFTReceipt, Ticket)` |
| `oftCmd` | Ignored (pass empty) | Controls bus/taxi mode |
| msg.value (ERC20) | `nativeFee` only | `nativeFee` only |
| msg.value (native) | `nativeFee` only (OFT uses transferFrom/burn) | `nativeFee + amountLD` |
| Approval target | OFT/OFTAdapter contract itself | Stargate pool contract |
| Compose support | Yes | Yes (taxi mode only) |

## 4. OFTAdapter vs OFT

| Aspect | OFT | OFTAdapter |
|---|---|---|
| Token relationship | Contract IS the ERC20 token | Wraps an existing ERC20 token |
| `token()` returns | `address(this)` | `address(innerToken)` |
| `approvalRequired()` | `false` | `true` |
| `_debit()` | `_burn(from, amount)` | `innerToken.safeTransferFrom(from, address(this), amount)` |
| `_credit()` | `_mint(to, amount)` | `innerToken.safeTransfer(to, amount)` |
| User approval needed? | No | **Yes** (approve OFTAdapter for underlying token) |

**UP token deployment:**
- Ethereum: `UpOFTAdapter` (wraps existing UP ERC20) → `approvalRequired() == true`
- Base/HyperEVM/Flare: `UpOFT` (native OFT) → `approvalRequired() == false`

## 5. MessagingFee Struct

```solidity
struct MessagingFee {
    uint256 nativeFee;   // Fee in native token
    uint256 lzTokenFee;  // Fee in ZRO token
}
```

Identical between IOFT and IStargate.

## 6. Return Types

```solidity
struct MessagingReceipt {
    bytes32 guid;
    uint64 nonce;
    MessagingFee fee;
}

struct OFTReceipt {
    uint256 amountSentLD;
    uint256 amountReceivedLD;
}

// Stargate-only addition:
struct Ticket {
    uint72 ticketId;
    bytes passengerBytes;
}
```

## 7. Compose Messages

When `composeMsg` is non-empty:
1. `_lzReceive()` credits tokens to recipient
2. OFT re-encodes with `OFTComposeMsgCodec.encode()` and calls `endpoint.sendCompose()`
3. Executor calls `lzCompose()` on recipient in a separate transaction

The `composeMsg` in `SendParam` is raw application payload — LZ wraps it with metadata.

**extraOptions must include compose gas** when composing:
```solidity
options = OptionsBuilder.newOptions()
    .addExecutorLzReceiveOption(65000, 0)
    .addExecutorLzComposeOption(0, 50000, 0);
```

## 8. msg.value Requirements - Critical

### Generic OFT (IOFT.send()):
```
msg.value = MessagingFee.nativeFee
```
OFT handles token via burn (OFT) or transferFrom (OFTAdapter). No amountLD in msg.value.

### Stargate Native Pool (IStargate.sendToken()):
```
msg.value = MessagingFee.nativeFee + amountLD
```
Native pools bundle token amount into msg.value.

### Stargate ERC20 Pool:
```
msg.value = MessagingFee.nativeFee
```
Same as generic OFT for ERC20.

## 9. Implications for Hook Design

Since the `SendParam` struct is identical:
1. **Same data layout works** — the hook builds the same `SendParam` regardless of mode
2. **Only the function call differs** — `abi.encodeCall(IStargate.sendToken, ...)` vs `abi.encodeCall(IOFT.send, ...)`
3. **msg.value logic changes** — in OFT mode, `value = lzNativeFee` always (never add `amountLD`)
4. **Pool validation changes** — `IStargate.token()` vs `IOFT.token()` (both exist but semantic differs)
5. **`isBusMode` irrelevant for OFT** — always pass `oftCmd = bytes("")`

## References
- [IOFT.sol (devtools)](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/interfaces/IOFT.sol)
- [OFTAdapter.sol](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/OFTAdapter.sol)
- [OFT.sol](https://github.com/LayerZero-Labs/devtools/blob/main/packages/oft-evm/contracts/OFT.sol)
- [IStargate.sol (stargate-v2)](https://github.com/stargate-protocol/stargate-v2/blob/main/packages/stg-evm-v2/src/interfaces/IStargate.sol)
- [OptionsBuilder.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/oapp/contracts/oapp/libs/OptionsBuilder.sol)
- [LayerZero V2 OFT Quickstart](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)
