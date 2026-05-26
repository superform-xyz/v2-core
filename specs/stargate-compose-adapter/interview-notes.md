# Stargate Compose Adapter - Interview Notes

## Date: 2026-05-26

## Feature Summary
Create a `StargateAdapter` contract that receives Stargate V2 / LayerZero V2 compose messages on the destination chain, decodes the OFT compose payload, transfers received tokens to the target account, and calls `SuperDestinationExecutor.processBridgedExecution()`. Follows the same adapter pattern as `AcrossV3Adapter` and `DebridgeAdapter`.

## Key Decisions

### 1. Token Flow: Adapter Receives All
- `to` field in StargateSendHook = adapter address (bytes32-encoded)
- Stargate delivers tokens to the adapter contract
- LZ endpoint calls `lzCompose()` on the adapter
- Adapter transfers tokens to user account, then calls `processBridgedExecution()`
- Same pattern as AcrossV3Adapter

### 2. Scope: Stargate + OFT
- Single adapter handles both Stargate pool compose messages and generic OFT compose messages
- Both use the same `OFTComposeMsgCodec` format
- Mode 0/1 (Stargate taxi/bus) and mode 2 (generic OFT) from the send hook are all handled

### 3. Native ETH Support: Yes
- Support both ERC20 and native ETH delivery
- Stargate native pools (StargatePoolNative) deliver ETH
- Adapter needs `receive()` function
- ETH forwarded to account via `call{value: balance}("")`
- Same dual-path approach as DebridgeAdapter

### 4. Sender Validation: Endpoint Only
- Only validate `msg.sender == LZ_ENDPOINT`
- Trust that the LZ endpoint is secure
- No pool whitelist or factory checks needed
- Simpler, works with any Stargate pool / OFT without governance

### 5. Amount Source: Use Adapter Balance
- Transfer the adapter's full token balance to the account
- Don't decode `amountLD` from OFTComposeMsgCodec for transfer amount
- Simpler approach, handles rounding and edge cases
- Note: amountLD in codec is post-Stargate-fee amount (received, not sent)

### 6. Chains: All Superform Chains
- Deploy on all chains where Superform operates
- LZ V2 endpoint is the same address on all EVM chains: `0x1a44076050125825900e736c501f859c50fE728c`

### 7. Source Hook Changes: None (Bundler Concern)
- No changes to StargateSendHook
- Bundler is responsible for setting `to = adapter address` when compose messages are included
- Document this in spec

### 8. Token Identification: Call `_from.token()`
- Call `token()` on the `_from` address (Stargate pool or OFT) to get the underlying token
- Works for all Stargate pools and most OFTs
- Native pools return `address(0)` for ETH
- `token()` selector is `0xfc0c546a` (same for both IStargate and IOFT)

### 9. Contract Design: Standalone StargateAdapter
- New contract at `src/adapters/StargateAdapter.sol`
- Clean separation, follows AcrossV3Adapter pattern
- Implements `ILayerZeroComposer` interface

## Architecture Flow

```
Source Chain:                    Destination Chain:
StargateSendHook               StargateAdapter
   |                              |
   | sendToken(to=adapter)        | 1. Stargate delivers tokens to adapter
   | composeMsg included          | 2. LZ endpoint calls lzCompose()
   v                              | 3. Adapter decodes OFTComposeMsgCodec
Stargate Pool ──── LZ V2 ────>   | 4. Transfer tokens to account
                                  | 5. Call processBridgedExecution()
                                  v
                              SuperDestinationExecutor
```

## OFTComposeMsgCodec Format
```
Offset | Type    | Size | Field
-------|---------|------|------------------
0      | uint64  | 8    | nonce
8      | uint32  | 4    | srcEid
12     | uint256 | 32   | amountLD (received)
44     | bytes32 | 32   | composeSender
76     | bytes   | var  | composeMsg (our payload)
```

## ComposeMsg Payload (Inner)
Same as Across/deBridge:
```
abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)
```

## Security Considerations
- Reentrancy: ETH forwarding before external call (processBridgedExecution). Should follow CEI or use reentrancy guard.
- Compose message replay: LZ endpoint handles nonce tracking, prevents replay
- Sender validation: Only LZ endpoint can call lzCompose
- Token identification: Relies on _from.token() being accurate
- Balance-based transfer: Risk of dust accumulation if previous compose fails. Need to handle or document.
