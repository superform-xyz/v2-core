# Framework Docs: Stargate V2 / LayerZero V2 Compose Message Encoding

## 1. LayerZero V2 Message Size Limit

**Default: 10,000 bytes**, enforced in `SendLibBase._assertMessageSize()`.
- Applies to the **`message` field of the LZ packet** (application-level payload)
- For Stargate taxi mode: TaxiCodec message = 43 bytes header + 32 bytes sender prefix + `SendParam.composeMsg`
- **Effective max composeMsg ≈ 9,925 bytes**

## 2. OFTComposeMsgCodec (76-byte header — destination only)

Added on destination chain by `endpoint.sendCompose()`. NOT counted in 10k source limit.

| Bytes | Field | Type | Size |
|-------|-------|------|------|
| 0-7 | nonce | uint64 | 8 |
| 8-11 | srcEid | uint32 | 4 |
| 12-43 | amountLD | uint256 | 32 |
| 44-75 | composeFrom | bytes32 | 32 |
| 76+ | composeMsg | bytes | variable |

## 3. TaxiCodec (Source-Chain Message — counted in 10k)

| Bytes | Field | Type | Size |
|-------|-------|------|------|
| 0 | MSG_TYPE_TAXI | uint8 | 1 |
| 1-2 | assetId | uint16 | 2 |
| 3-34 | receiver | bytes32 | 32 |
| 35-42 | amountSD | uint64 | 8 |
| 43-74 | sender (composeFrom) | bytes32 | 32 (only if compose) |
| 75+ | composeMsg | bytes | variable |

**Total overhead before user composeMsg: 75 bytes**

## 4. Taxi vs Bus vs OFT Mode

| Mode | Composable | Encoding | Notes |
|------|------------|----------|-------|
| 0 (taxi) | YES | TaxiCodec | Immediate delivery, full compose support |
| 1 (bus) | NO | BusCodec | Batched, lower fee, compose discarded |
| 2 (OFT) | YES | OFTMsgCodec | Direct IOFT.send(), 72 bytes overhead |
| 3 (lzMulticall) | N/A | Raw calldata | Different payload structure |

## 5. Complete Compose Flow (Taxi Mode)

### Source Chain
1. User → `IStargate.sendToken(sendParam, fee, refund)` with `sendParam.composeMsg`
2. StargateBase → `_taxi()` → `ITokenMessaging.taxi()`
3. TokenMessaging → `TaxiCodec.encodeTaxi(sender, assetId, receiver, amountSD, composeMsg)`
4. `_lzSend()` → **SendUln302 checks `_assertMessageSize(message.length, 10000)`**

### Destination Chain
5. `_lzReceive()` on TokenMessaging → `_lzReceiveTaxi()` → `receiveTokenTaxi()`
6. Credits tokens to receiver
7. If compose: `OFTComposeMsgCodec.encode(nonce, srcEid, amountLD, composeMsg)` → `endpoint.sendCompose()`
8. Executor triggers `endpoint.lzCompose()` → verifies hash → calls `StargateAdapter.lzCompose()`
9. Adapter skips 76-byte header, decodes inner payload

## 6. Key Constraints

- Bus mode cannot compose (discards composeMsg)
- One compose per lzReceive (index always 0)
- composeQueue stores keccak256(message), not full data
- OFTComposeMsgCodec header is destination-only (not in 10k budget)
- TaxiCodec sender prefix (32 bytes) IS in 10k budget

## 7. V2 Compact Format Size Budget

| Component | V1 | V2 | Savings |
|-----------|----|----|---------|
| executorCalldata (duplicate) | 1-5 KB | 0 | 1-5 KB |
| account (duplicate) | 32 B | 0 | 32 B |
| dstTokens (duplicate) | 64+ B | 0 | 64+ B |
| intentAmounts (duplicate) | 64+ B | 0 | 64+ B |
| ABI offset pointers | ~128 B | 0 | ~128 B |
| **Total savings** | | | **~1.5-5.5 KB** |

## Sources
- [LZ V2 Protocol Overview](https://docs.layerzero.network/v2/developers/evm/protocol-contracts-overview)
- [OFTComposeMsgCodec.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oft/libs/OFTComposeMsgCodec.sol)
- [TaxiCodec.sol](https://github.com/stargate-protocol/stargate-v2/blob/main/packages/stg-evm-v2/src/libs/TaxiCodec.sol)
- [Stargate Composability](https://docs.stargate.finance/developers/protocol-docs/composability)
- [LZ V2 Design Patterns](https://docs.layerzero.network/v2/developers/evm/oapp/message-design-patterns)
