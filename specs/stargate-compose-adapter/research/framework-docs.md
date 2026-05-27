# Framework Documentation: LayerZero V2 Compose for Stargate V2

## 1. ILayerZeroComposer Interface

**Source**: `@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol`

```solidity
interface ILayerZeroComposer {
    function lzCompose(
        address _from,           // Destination OApp that called sendCompose()
        bytes32 _guid,           // Globally unique LZ message ID
        bytes calldata _message, // OFTComposeMsgCodec-encoded message
        address _executor,       // LZ executor relaying the compose
        bytes calldata _extraData // Extra data from executor (typically empty)
    ) external payable;
}
```

**Registration**: No explicit registration. LZ endpoint calls `lzCompose()` on whatever address was the `to` recipient in the original `SendParam`. The `to` address receives tokens AND the compose callback.

## 2. OFTComposeMsgCodec

**Source**: `@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol`

### Layout
```
Offset | Type    | Size     | Field
-------|---------|----------|------------------
0      | uint64  | 8 bytes  | nonce
8      | uint32  | 4 bytes  | srcEid
12     | uint256 | 32 bytes | amountLD (post-fee)
44     | bytes32 | 32 bytes | composeFrom (sender)
76     | bytes   | variable | composeMsg (inner payload)
```

### Constants & Functions
```solidity
uint8 private constant NONCE_OFFSET = 8;
uint8 private constant SRC_EID_OFFSET = 12;
uint8 private constant AMOUNT_LD_OFFSET = 44;
uint8 private constant COMPOSE_FROM_OFFSET = 76;

function nonce(bytes calldata _msg) returns (uint64)
function srcEid(bytes calldata _msg) returns (uint32)
function amountLD(bytes calldata _msg) returns (uint256)
function composeFrom(bytes calldata _msg) returns (bytes32)
function composeMsg(bytes calldata _msg) returns (bytes memory)  // offset 76+
```

## 3. Token Delivery Timing

**Two-transaction model:**

### Transaction 1 (lzReceive):
1. LZ executor calls `EndpointV2.lzReceive()` on destination chain
2. Destination Stargate pool processes in `_lzReceive()`
3. Pool calls `_credit()` → transfers/mints tokens to `to` address (adapter)
4. Pool calls `endpoint.sendCompose(to, guid, 0, encodedMsg)` to queue compose

### Transaction 2 (lzCompose):
5. LZ executor calls `EndpointV2.lzCompose()`
6. Endpoint verifies compose hash, calls `adapter.lzCompose()`
7. **Tokens already in adapter balance at this point**

**Key**: If `lzCompose` reverts, token credit from `lzReceive` is NOT undone. Compose stays in queue for retry.

## 4. Complete Flow Diagram

```
Source Chain:                          Destination Chain:

1. StargateSendHook calls
   stargatePool.sendToken(
     to = adapterAddress,
     composeMsg = payload,
     extraOptions = [lzComposeGas]
   )

2. Stargate pool calls
   endpoint.send() with OFT message
                                       Transaction 1 (lzReceive):
        -------- LZ DVN/Executor ----→ 3. endpoint.lzReceive() →
                                          dstPool._lzReceive()
                                       4. Pool credits tokens to adapter
                                       5. Pool calls endpoint.sendCompose()

                                       Transaction 2 (lzCompose):
                                       6. endpoint.lzCompose() →
                                          adapter.lzCompose(
                                            _from = dstPool,
                                            _guid, _message,
                                            _executor, _extraData
                                          )
                                       7. Adapter decodes OFTComposeMsgCodec
                                       8. Adapter transfers tokens to account
                                       9. Adapter calls processBridgedExecution()
```

## 5. Files Needed (Not in v2-core)

| File | Purpose |
|------|---------|
| `src/vendor/bridges/layerzero/ILayerZeroComposer.sol` | Interface (CREATE) |
| `src/vendor/bridges/layerzero/OFTComposeMsgCodec.sol` | Codec library (CREATE) |
| `src/adapters/StargateAdapter.sol` | Adapter contract (CREATE) |

**Existing assets**: `IStargate.sol`, `IOFT.sol` already in vendor. Both have `token()` with selector `0xfc0c546a`.

## 6. LZ Endpoint V2

**Address**: `0x1a44076050125825900e736c501f859c50fE728c` (same on ALL EVM chains via CREATE2)

## 7. Compose Message Inner Payload

After extracting from OFTComposeMsgCodec (offset 76+), the inner payload is the standard 6-tuple:

```solidity
(bytes initData, bytes executorCalldata, address account,
 address[] dstTokens, uint256[] intentAmounts, bytes sigData)
```

Signature already appended by StargateSendHook on source chain (lines 147-161).

## References

- [LayerZero V2 Composers Overview](https://docs.layerzero.network/v2/developers/evm/composer/overview)
- [Stargate V2 Composability](https://stargateprotocol.gitbook.io/stargate/v2-developer-docs/integrate-with-stargate/composability)
- [OFTComposeMsgCodec.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oft/libs/OFTComposeMsgCodec.sol)
- [OFTCore.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oft/OFTCore.sol)
- [LZ V2 Design Patterns](https://docs.layerzero.network/v2/developers/evm/oapp/message-design-patterns)
- [Stargate Composability Tutorial](https://github.com/stargate-protocol/tutorial-protocol-composability)
- [LZ V2 Security Checklist](https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md)
