# Best Practices: LayerZero V2 Compose Receiver for Stargate V2

## 1. ILayerZeroComposer Interface

**Import:** `@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol`

```solidity
interface ILayerZeroComposer {
    function lzCompose(
        address _from,        // OApp/Stargate pool that called sendCompose()
        bytes32 _guid,        // Globally unique ID for the LZ src/dst tx
        bytes calldata _message, // OFTComposeMsgCodec-encoded message
        address _executor,    // LZ executor address
        bytes calldata _extraData // Extra data from executor (usually empty)
    ) external payable;
}
```

## 2. OFTComposeMsgCodec

**Import:** `@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol`

### Message Layout
```
Offset | Type    | Size    | Field         | Description
-------|---------|---------|---------------|----------------------------------
0      | uint64  | 8 bytes | nonce         | LZ message nonce from source
8      | uint32  | 4 bytes | srcEid        | Source endpoint ID
12     | uint256 | 32 bytes| amountLD      | Amount received (post-fees)
44     | bytes32 | 32 bytes| composeFrom   | Original sender on source chain
76     | bytes   | variable| composeMsg    | Application-specific payload
```

### Key Decoder Functions
```solidity
library OFTComposeMsgCodec {
    uint8 private constant COMPOSE_FROM_OFFSET = 76;

    function amountLD(bytes calldata _msg) internal pure returns (uint256) {
        return uint256(bytes32(_msg[12:44]));
    }

    function composeFrom(bytes calldata _msg) internal pure returns (bytes32) {
        return bytes32(_msg[44:76]);
    }

    function composeMsg(bytes calldata _msg) internal pure returns (bytes memory) {
        return _msg[COMPOSE_FROM_OFFSET:];
    }
}
```

## 3. Stargate V2 Compose Flow - Token Delivery Order

**Tokens are credited BEFORE compose is called. Flow:**

1. **lzReceive** (Step 1): LZ Endpoint calls `lzReceive()` on destination Stargate pool. Pool calls `_credit()` which transfers/mints tokens to the `to` address (composer). Then pool calls `endpoint.sendCompose()` to queue compose.

2. **lzCompose** (Step 2): LZ Executor calls `EndpointV2.lzCompose()`. Endpoint verifies compose hash from queue, then calls `lzCompose()` on composer. **Tokens already in composer's balance.**

**Atomicity**: `lzReceive` and `lzCompose` are separate execution contexts. If `lzCompose` reverts, token credit from `lzReceive` is NOT undone. Compose stays in queue for retry.

**Key insight**: When `lzCompose` executes, `balanceOf(address(this))` is safe to use.

## 4. Security Considerations

### 4.1 Sender Validation (CRITICAL)
- `msg.sender == LZ_ENDPOINT` is **non-negotiable**
- `_from` validation is defense-in-depth (optional per interview decision: endpoint-only)

### 4.2 Reentrancy
- ETH forwarding via `call{value}` before `processBridgedExecution` is a reentrancy vector
- Existing adapters (AcrossV3, Debridge) do NOT use ReentrancyGuard - follow same pattern

### 4.3 Replay Protection
- LZ Endpoint provides built-in replay protection via `composeQueue` mapping
- `composeQueue[receiver][guid][index]` cleared after successful execution
- Adapter does NOT need its own nonce tracking

### 4.4 Compose Failure and Retry
- If `lzCompose` reverts: tokens NOT lost (already credited in `lzReceive`)
- Compose stays in queue, can be retried indefinitely by anyone calling `endpoint.lzCompose()` again
- Adapter may hold tokens between failed compose and retry - balance-based transfer handles this naturally

### 4.5 Gas Considerations
- Source must specify enough gas via `extraOptions` with `addExecutorLzComposeOption(0, gasLimit, 0)`
- Insufficient gas = compose reverts but can be retried

## 5. Native ETH Handling

### StargatePoolNative
- `token()` returns `address(0)` for native ETH pools
- Pool sends ETH to `to` address via `call{value: amount}("")` in `_credit()`
- **Adapter MUST have `receive()` function** to accept ETH

### Detection Pattern
```solidity
address token = IStargate(_from).token();
if (token == address(0)) {
    // Native ETH path
    (bool success,) = account.call{value: address(this).balance}("");
} else {
    // ERC20 path
    IERC20(token).safeTransfer(account, balance);
}
```

## 6. LZ V2 Endpoint Address

**Confirmed canonical address on ALL EVM chains:**
```
0x1a44076050125825900e736c501f859c50fE728c
```
- Deployed via CREATE2 deterministic deployment
- Same address on Ethereum, Base, BSC, Arbitrum, Polygon, etc.
- Immutable, non-upgradeable

## 7. token() Function Compatibility

Both `IStargate.token()` and `IOFT.token()` share selector `0xfc0c546a`:
- **StargatePool (ERC20)**: Returns underlying ERC20 address
- **StargatePoolNative**: Returns `address(0)`
- **OFT contracts**: Returns `address(this)` (contract IS the token)
- **OFTAdapter contracts**: Returns inner ERC20 address

A single `IStargate(_from).token()` call works for all cases.
