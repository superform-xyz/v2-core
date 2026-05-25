# Stargate V2 Research - Interface & Integration

## Date: 2026-05-05

---

## 1. Stargate V2 Interface Specification

### IStargate Interface (sendToken function)

Stargate V2 uses per-token pool contracts (e.g., StargatePoolUSDC, StargatePoolETH) that each implement the `IStargate` interface. The key function is `sendToken()`:

```solidity
interface IStargate {
    struct SendParam {
        uint32 dstEid;           // LayerZero V2 endpoint ID for destination chain
        bytes32 to;              // Recipient address on destination (bytes32 for cross-VM support)
        uint256 amountLD;        // Amount in local decimals to send
        uint256 minAmountLD;     // Minimum amount in local decimals to receive on destination
        bytes extraOptions;      // LayerZero V2 extra options (gas, value for dst execution)
        bytes composeMsg;        // Compose message for destination execution (LZ compose pattern)
        bytes oftCmd;            // OFT command: empty bytes = taxi mode, "0x01" = bus mode
    }

    struct MessagingReceipt {
        bytes32 guid;            // Global unique identifier for the message
        uint64 nonce;            // Message nonce
        MessagingFee fee;        // Actual fee paid
    }

    struct MessagingFee {
        uint256 nativeFee;       // Fee in native token (ETH/MATIC etc.)
        uint256 lzTokenFee;      // Fee in LZ token (usually 0)
    }

    struct OFTReceipt {
        uint256 amountSentLD;    // Actual amount sent (after dust removal)
        uint256 amountReceivedLD; // Amount to be received on destination
    }

    /// @notice Send tokens cross-chain via Stargate/LayerZero V2
    /// @param _sendParam The parameters for the send operation
    /// @param _fee The messaging fee (native + optional LZ token)
    /// @param _refundAddress The address to refund excess native fee to
    /// @return msgReceipt The messaging receipt with guid and nonce
    /// @return oftReceipt The OFT receipt with actual amounts sent/received
    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt);

    /// @notice Quote the messaging fee for a send operation
    /// @param _sendParam The parameters for the send operation
    /// @param _payInLzToken Whether to pay fee in LZ token
    /// @return fee The estimated messaging fee
    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory fee);
}
```

### Key Design Decisions

1. **Per-Pool Addressing**: Unlike Across (single SpokePool), Stargate V2 has a separate pool contract per token (e.g., StargatePoolUSDC at one address, StargatePoolETH at another). The hook needs to accept the pool address in the data layout since the bundler selects the appropriate pool.

2. **LayerZero V2 Endpoint IDs (EIDs)**: Stargate V2 uses LZ V2 endpoint IDs (uint32) instead of chain IDs. The bundler must map chain IDs to EIDs.

3. **Taxi vs Bus Mode**: Controlled by the `oftCmd` field:
   - **Taxi mode**: `oftCmd = ""` (empty bytes) - immediate message delivery, higher fee
   - **Bus mode**: `oftCmd = abi.encodePacked(uint8(1))` or specific bus encoding - batched delivery, lower fee

4. **Dust Removal**: Stargate V2 internally removes dust (amounts below the shared decimal precision). The `amountSentLD` in OFTReceipt may differ from `amountLD` in SendParam.

5. **Native Token Handling**: For native ETH pools (StargatePoolNative), `msg.value` must include both the `amountLD` AND the `nativeFee`. For ERC20 pools, `msg.value` only includes the `nativeFee`.

---

## 2. LayerZero V2 Compose Message Pattern

### How composeMsg Works for Destination Execution

When `composeMsg` is non-empty in `SendParam`, LayerZero V2 triggers a compose call on the destination after token delivery:

1. Source chain: User calls `stargate.sendToken()` with `composeMsg` set
2. LZ V2 delivers the message to destination Stargate pool
3. Destination Stargate pool calls `ILayerZeroEndpointV2.sendCompose()`
4. LZ V2 endpoint calls `lzCompose()` on the designated receiver (the Stargate pool address)
5. The compose receiver processes the message

### Compose Message Structure for SuperDestinationExecutor

For Superform integration, the `composeMsg` follows the same authentication pattern as Across:

```solidity
// Before signature appending (what goes into hook data):
bytes memory destinationMessage = abi.encode(
    initData,           // bytes - initialization data for destination executor
    executorCalldata,   // bytes - calldata for destination execution
    account,            // address - the smart account on destination
    dstTokens,          // address[] - tokens expected on destination
    intentAmounts       // uint256[] - expected amounts
);

// After signature appending (what gets encoded as composeMsg):
bytes memory composeMsg = abi.encode(
    initData,
    executorCalldata,
    account,
    dstTokens,
    intentAmounts,
    signature           // bytes - validator signature from transient storage
);
```

### LayerZero V2 extraOptions Encoding

The `extraOptions` field configures destination gas and native value:

```solidity
// For compose execution, extraOptions must include compose gas:
// Using LayerZero's OptionsBuilder library pattern:
bytes memory extraOptions = OptionsBuilder.newOptions()
    .addExecutorLzComposeOption(0, composeGasLimit, 0); // index, gasLimit, value

// Simplified encoding (raw bytes):
// Type 3 options with compose option
// uint16 optionType = 3 (EXECUTOR)
// uint8 workerType = 1
// uint16 size
// uint8 optionId = 3 (LZ_COMPOSE)
// uint16 index = 0
// uint128 gasLimit
// uint128 value = 0
```

For our hook, the bundler pre-computes `extraOptions` and passes it as raw bytes in the data layout. The hook does not need to construct this.

---

## 3. Proposed Data Layout (Tight Packing with BytesLib)

### StargateSendHook (Native ETH variant)

```
Offset  | Type      | Size | Field
--------|-----------|------|---------------------------
0       | uint256   | 32   | lzNativeFee (native fee for LZ messaging)
32      | address   | 20   | stargatePool (per-token pool contract)
52      | uint32    | 4    | dstEid (LZ V2 destination endpoint ID)
56      | bytes32   | 32   | to (recipient on destination, bytes32 format)
88      | uint256   | 32   | amountLD (amount in local decimals)
120     | uint256   | 32   | minAmountLD (min amount on destination)
152     | bool      | 1    | usePrevHookAmount
153     | bool      | 1    | isBusMode (false = taxi, true = bus)
154     | uint256   | 32   | extraOptionsLength
186     | bytes     | var  | extraOptions (LZ V2 executor options)
186+eol | uint256   | 32   | composeMsgLength (0 if no dst execution)
218+eol | bytes     | var  | composeMsg (destination execution message)
```

Total minimum size (no extraOptions, no composeMsg): 154 + 32 + 32 = 218 bytes

### ApproveAndStargateSendHook (ERC20 variant)

Same data layout as above. The difference is:
- For ERC20: `msg.value` = `lzNativeFee` only (tokens are transferred via approve+transferFrom)
- For Native: `msg.value` = `lzNativeFee + amountLD` (ETH is sent with the call)

Both variants share the same data encoding. The native variant passes `lzNativeFee + amountLD` as `value` in the Execution struct. The ERC20 variant passes only `lzNativeFee` as `value`.

---

## 4. Implementation Plan

### File Structure

```
src/
  vendor/
    bridges/
      stargate/
        IStargate.sol           # Stargate V2 interface (sendToken, quoteSend, structs)
  hooks/
    bridges/
      stargate/
        StargateSendHook.sol                    # Native ETH bridge hook
        ApproveAndStargateSendHook.sol          # ERC20 bridge hook with approval pattern
test/
  unit/
    hooks/
      bridges/
        StargateHooks.t.sol     # Unit tests for both variants
```

### 4.1 StargateSendHook.sol

**Purpose**: Bridge native tokens (ETH) cross-chain via Stargate V2 with optional destination execution.

**Constructor Parameters**:
- `address validator_` - The SuperValidator address for signature retrieval

**Why no `stargatePool` in constructor**: Unlike Across (single SpokePool per chain), Stargate V2 has different pool addresses per token. The pool address is passed in the hook data because the bundler selects the appropriate pool based on the token being bridged.

**Key Implementation Details**:
- HookType: `NONACCOUNTING`
- SubType: `HookSubTypes.BRIDGE`
- Implements: `ISuperHookContextAware`
- The `stargatePool` address comes from hook data (not constructor) because each token has its own pool
- `value` in Execution = `lzNativeFee + amountLD` for native token sends
- Signature appending to `composeMsg` follows same pattern as Across
- Bus/Taxi mode controlled by `isBusMode` flag:
  - Taxi: `oftCmd = ""` (empty bytes)
  - Bus: `oftCmd = abi.encodePacked(uint8(1))` (or empty - TBD based on Stargate docs)

**_buildHookExecutions Logic**:
1. Validate data length >= 218 bytes minimum
2. Decode all fields using BytesLib
3. If `usePrevHookAmount`:
   - Get `outAmount` from prevHook
   - Scale `minAmountLD` proportionally: `minAmountLD = mulDiv(minAmountLD, outAmount, amountLD)`
   - Update `amountLD = outAmount`
   - Recalculate `lzNativeFee + amountLD` for value (since amountLD changed)
4. Validate: `amountLD != 0`, `stargatePool != address(0)`, `to != bytes32(0)`
5. If `composeMsg` is present, append signature from validator
6. Build SendParam struct
7. Build MessagingFee struct: `{nativeFee: lzNativeFee, lzTokenFee: 0}`
8. Return single Execution targeting stargatePool with `sendToken()` call

### 4.2 ApproveAndStargateSendHook.sol

**Purpose**: Bridge ERC20 tokens cross-chain with approval pattern.

**Constructor Parameters**:
- `address validator_` - The SuperValidator address for signature retrieval

**Key Differences from Native variant**:
- Returns 4 Executions: approve(0) -> approve(amount) -> sendToken() -> approve(0)
- `value` in bridge Execution = `lzNativeFee` only (no amountLD in value)
- Requires knowing the token address for approval - derived from Stargate pool or passed separately
- Token address must be queried from the pool or passed in data

**Important consideration**: The ERC20 variant needs the token address for the approval calls. Options:
1. Add `inputToken` address to data layout (adds 20 bytes)
2. Call `stargatePool.token()` in a view function (but we're in `view` context and can't call external state-changing functions)

**Decision**: Add `address inputToken` to data layout at offset 32 (between lzNativeFee and stargatePool). This keeps the hook view-only and avoids external calls for token discovery.

### Revised Data Layout (Both Variants)

```
Offset  | Type      | Size | Field
--------|-----------|------|---------------------------
0       | uint256   | 32   | lzNativeFee
32      | address   | 20   | stargatePool
52      | address   | 20   | inputToken (for approval; address(0) for native)
72      | uint32    | 4    | dstEid
76      | bytes32   | 32   | to (recipient on destination)
108     | uint256   | 32   | amountLD
140     | uint256   | 32   | minAmountLD
172     | bool      | 1    | usePrevHookAmount
173     | bool      | 1    | isBusMode
174     | uint256   | 32   | extraOptionsLength
206     | bytes     | var  | extraOptions
206+eol | uint256   | 32   | composeMsgLength
238+eol | bytes     | var  | composeMsg (destinationMessage)
```

Total minimum size: 174 + 32 + 32 = 238 bytes (with zero-length extraOptions and composeMsg)

### 4.3 IStargate.sol (Vendor Interface)

Minimal interface containing only what our hooks need:

```solidity
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

interface IStargate {
    struct SendParam {
        uint32 dstEid;
        bytes32 to;
        uint256 amountLD;
        uint256 minAmountLD;
        bytes extraOptions;
        bytes composeMsg;
        bytes oftCmd;
    }

    struct MessagingFee {
        uint256 nativeFee;
        uint256 lzTokenFee;
    }

    struct MessagingReceipt {
        bytes32 guid;
        uint64 nonce;
        MessagingFee fee;
    }

    struct OFTReceipt {
        uint256 amountSentLD;
        uint256 amountReceivedLD;
    }

    function sendToken(
        SendParam calldata _sendParam,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory, OFTReceipt memory);

    function quoteSend(
        SendParam calldata _sendParam,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    function token() external view returns (address);
}
```

---

## 5. Constructor Parameters Summary

### StargateSendHook
| Parameter | Type | Purpose |
|-----------|------|---------|
| `validator_` | `address` | SuperValidator for retrieving signature data from transient storage |

### ApproveAndStargateSendHook
| Parameter | Type | Purpose |
|-----------|------|---------|
| `validator_` | `address` | SuperValidator for retrieving signature data from transient storage |

**Note**: Unlike Across (which has a single SpokePool per chain), Stargate V2 has per-token pools. The pool address is passed in hook data since it varies per operation.

---

## 6. Security Considerations

### Input Validation
- Minimum data length check (238 bytes)
- `stargatePool != address(0)`
- `to != bytes32(0)` (destination recipient)
- `amountLD != 0` (cannot bridge zero)
- `inputToken != address(0)` for ERC20 variant

### Fee Manipulation Prevention
- `lzNativeFee` is set by the bundler and validated off-chain via `quoteSend()`
- Excess fee is refunded to the account (refundAddress = account)
- No on-chain oracle needed since bundler pre-computes fees

### Approval Race Condition (ERC20 variant)
- Reset to 0 before approving exact amount
- Reset to 0 after execution completes
- Same pattern as ApproveAndAcrossSendFundsAndExecuteOnDstHook

### usePrevHookAmount Scaling
- Uses `Math.mulDiv` for safe proportional scaling of `minAmountLD`
- Prevents overflow/underflow in ratio calculations

### composeMsg Integrity
- Signature is appended using same decode/re-encode pattern as Across
- Cannot corrupt existing payload since it's fully decoded and re-encoded

---

## 7. Stargate V2 Chain Support (LayerZero V2 Endpoint IDs)

| Chain | LZ V2 EID | Stargate V2 Status |
|-------|-----------|-------------------|
| Ethereum | 30101 | Deployed |
| Base | 30184 | Deployed |
| Arbitrum | 30110 | Deployed |
| Optimism | 30111 | Deployed |
| Polygon | 30109 | Deployed |
| Avalanche | 30106 | Deployed |
| BNB Chain | 30102 | Deployed |
| Linea | 30183 | Deployed |
| Sonic (FTM v2) | 30332 | Deployed (as Sonic) |
| Berachain | 30361 | Check deployment status |
| Gnosis | 30145 | Check deployment status |
| World Chain | TBD | Check deployment status |
| Unichain | TBD | Check deployment status |
| HyperEVM | TBD | Check deployment status |
| Flare | 30295 | Deployed |

**Note**: The hook is chain-agnostic in implementation. The bundler passes the correct pool addresses and EIDs. No chain-specific logic in the hook contracts.

---

## 8. Key Differences from Across Pattern

| Aspect | Across | Stargate V2 |
|--------|--------|-------------|
| Target contract | Single SpokePool per chain | Per-token Pool address |
| Constructor | spokePoolV3_, validator_ | validator_ only |
| Chain identifier | uint256 chainId | uint32 dstEid (LZ endpoint ID) |
| Recipient format | address | bytes32 |
| Fee handling | Included in outputAmount spread | Explicit nativeFee + amountLD |
| Destination execution | message field in depositV3Now | composeMsg in SendParam + extraOptions |
| Mode selection | N/A | Taxi vs Bus (oftCmd field) |
| Slippage | outputAmount (dst amount) | minAmountLD (min dst amount) |
| Token routing | inputToken/outputToken pair | Same token (pool-based, 1:1) |

---

## 9. Inspector Function Design

Following the PROTOCOL REQUIREMENT of only returning addresses:

```solidity
function inspect(bytes calldata data) external pure override returns (bytes memory) {
    address stargatePool = BytesLib.toAddress(data, 32);
    address inputToken = BytesLib.toAddress(data, 52);
    // Extract 'to' as address (first 20 bytes of bytes32)
    address toAddress = address(uint160(uint256(BytesLib.toBytes32(data, 76))));

    return abi.encodePacked(
        stargatePool,   // The Stargate pool being used
        inputToken,     // The input token
        toAddress       // The destination recipient (truncated to address)
    );
}
```

---

## 10. Deployment Integration Notes

### Constants.sol additions needed:
```solidity
string internal constant STARGATE_SEND_HOOK_KEY = "StargateSendHook";
string internal constant APPROVE_AND_STARGATE_SEND_HOOK_KEY = "ApproveAndStargateSendHook";
```

### Deployment approach:
Since Stargate V2 pool addresses vary per token (not a single router per chain), and the pool address is passed in hook data by the bundler, the hooks only need the `validator` address at deployment time. This means:
- No per-chain Stargate pool configuration needed in ConfigCore.sol
- Hooks deploy on ALL chains (validator is always available)
- Chain/token support is determined by the bundler's knowledge of pool addresses
- Same deployment simplicity as token utility hooks

This is a KEY architectural difference from Across/deBridge hooks which have a single router per chain in their constructor.
