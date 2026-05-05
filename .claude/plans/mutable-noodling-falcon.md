# Plan: CCTP V2 Bridge Hook Integration

## Context

Superform v2-core currently supports two bridge protocols: **Across V3** and **deBridge**. Both enable cross-chain execution by bridging tokens + execution data to a destination chain adapter, which then calls `SuperDestinationExecutor.processBridgedExecution()`.

Circle's **CCTP V2** (Cross-Chain Transfer Protocol) enables native USDC/EURC cross-chain transfers via burn-and-mint. Unlike Across/deBridge which push tokens and messages to adapters, CCTP uses a **pull model**: someone must call `receiveMessage(message, attestation)` on the destination to mint tokens. This makes the integration pattern slightly different.

**Goal:** Add CCTP V2 as a third bridge option, following the same source-hook + destination-adapter pattern as Across and deBridge.

## CCTP V2 Protocol Details

- **TokenMessengerV2** (`0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d`) — universal address across all chains
- **MessageTransmitterV2** (`0x81D40F21F12A8F0E3252Bccb954D722d4c464B64`) — universal address across all chains
- Only supports USDC (and EURC on some chains) — no native ETH
- Uses domain IDs (not chain IDs): ETH=0, AVAX=1, OP=2, ARB=3, BASE=6, POLYGON=7, UNICHAIN=10, LINEA=11, SONIC=13, WORLDCHAIN=14
- `destinationCaller` parameter restricts who can relay on destination — MUST be set to the adapter address for security

### Key V2 Function Signatures

```solidity
// Source chain — burn tokens
function depositForBurn(
    uint256 amount,
    uint32 destinationDomain,
    bytes32 mintRecipient,
    address burnToken,
    bytes32 destinationCaller,
    uint256 maxFee,
    uint32 minFinalityThreshold
) external;

// Destination chain — mint tokens
function receiveMessage(
    bytes calldata message,
    bytes calldata attestation
) external returns (bool success);
```

### Finality Thresholds
- `2000` = Finalized (hardest finality, slowest)
- `1000` = Confirmed (standard)
- `500` = Fast Transfer (~30 seconds)

## Architecture

### Flow (mirroring Across/deBridge pattern)

```
SOURCE CHAIN                                   DESTINATION CHAIN
─────────────                                  ─────────────────
1. SmartAccount executes hook                  5. Keeper calls CCTPAdapter.receiveAndExecute()
2. Hook calls TokenMessengerV2.depositForBurn  6. Adapter calls MessageTransmitter.receiveMessage()
3. USDC burned, CCTP message emitted           7. USDC minted to adapter
4. Circle Iris creates attestation             8. Adapter transfers USDC to account
                                               9. Adapter calls processBridgedExecution()
```

**Key difference from Across/deBridge:** The adapter calls `receiveMessage` itself (pull model), then executes. Setting `destinationCaller = adapter` ensures only the adapter can relay, making receive + execute atomic.

**Execution data transport:** The keeper retrieves execution data from the source chain event and passes it as a separate parameter to `receiveAndExecute`. This avoids parsing CCTP message internals.

## Files to Create

### 1. `src/vendor/bridges/cctp/ITokenMessengerV2.sol`

```solidity
interface ITokenMessengerV2 {
    function depositForBurn(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold
    ) external;
}
```

### 2. `src/vendor/bridges/cctp/IMessageTransmitterV2.sol`

```solidity
interface IMessageTransmitterV2 {
    function receiveMessage(
        bytes calldata message,
        bytes calldata attestation
    ) external returns (bool success);
}
```

### 3. `src/hooks/bridges/cctp/CCTPSendAndExecuteOnDstHook.sol`

**No-approve variant** — for when USDC approval to TokenMessengerV2 already exists.

Constructor: `(address tokenMessengerV2_, address validator_)`
Hook type: `NONACCOUNTING`, subtype: `BRIDGE`

Data layout (packed bytes):
```
Offset | Size | Type    | Field
-------|------|---------|-------
0      | 20   | address | burnToken
20     | 32   | uint256 | amount
52     | 4    | uint32  | destinationDomain
56     | 32   | bytes32 | mintRecipient (adapter on dst, left-padded to bytes32)
88     | 32   | bytes32 | destinationCaller (adapter on dst, or bytes32(0))
120    | 32   | uint256 | maxFee
152    | 4    | uint32  | minFinalityThreshold
156    | 1    | bool    | usePrevHookAmount
157+   | var  | bytes   | destinationMessage
```

Min data length: 157 bytes.

Builds 1 execution: `TokenMessengerV2.depositForBurn(amount, domain, recipient, token, caller, fee, finality)`

Signature injection: same pattern as Across — decode 5-tuple from destinationMessage, retrieve sig from transient storage, re-encode as 6-tuple.

Emits event for keeper: `CCTPBridgeInitiated(destinationDomain, account, mintRecipient, amount, destinationMessage)`.

### 4. `src/hooks/bridges/cctp/ApproveAndCCTPSendAndExecuteOnDstHook.sol`

**Approve variant** — includes approve(0) → approve(amount) → depositForBurn → approve(0).

Same data layout as above. Builds 4 executions (approve pattern targeting `burnToken` → `tokenMessengerV2`).

### 5. `src/adapters/CCTPAdapter.sol`

Constructor: `(address messageTransmitter_, address superDestinationExecutor_)`

```solidity
function receiveAndExecute(
    bytes calldata message,
    bytes calldata attestation,
    address tokenMinted,      // USDC/EURC address on destination
    bytes calldata executionData  // abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)
) external {
    // 1. Check balance before
    uint256 balBefore = IERC20(tokenMinted).balanceOf(address(this));
    // 2. Receive message → mints to this adapter
    IMessageTransmitterV2(MESSAGE_TRANSMITTER).receiveMessage(message, attestation);
    // 3. Calculate received
    uint256 received = IERC20(tokenMinted).balanceOf(address(this)) - balBefore;
    // 4. Decode execution data
    // 5. Transfer to account
    IERC20(tokenMinted).safeTransfer(account, received);
    // 6. Execute
    SUPER_DESTINATION_EXECUTOR.processBridgedExecution(...)
}
```

No `msg.sender` restriction needed — security comes from:
- CCTP attestation validation (Circle's attesters)
- `destinationCaller` restriction (only adapter can call receiveMessage)
- `processBridgedExecution` validates Merkle proof signature

## Files to Modify

### 6. `script/utils/Constants.sol`

Add CCTP V2 contract addresses (same on all chains):
```solidity
address internal constant CCTP_TOKEN_MESSENGER_V2 = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
address internal constant CCTP_MESSAGE_TRANSMITTER_V2 = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;
```

Add key constants (next to `ACROSS_V3_ADAPTER_KEY` at line 32):
```solidity
string internal constant CCTP_ADAPTER_KEY = "CCTPAdapter";
string internal constant CCTP_SEND_AND_EXECUTE_ON_DST_HOOK_KEY = "CCTPSendAndExecuteOnDstHook";
string internal constant APPROVE_AND_CCTP_SEND_AND_EXECUTE_ON_DST_HOOK_KEY = "ApproveAndCCTPSendAndExecuteOnDstHook";
```

### 7. `script/DeployV2Core.s.sol`

Changes needed:
1. **`CoreContracts` struct** (line 18): Add `address cctpAdapter;`
2. **`HookAddresses` struct** (line 32): Add `address cctpSendAndExecuteOnDstHook;` and `address approveAndCCTPSendAndExecuteOnDstHook;`
3. **`ContractAvailability` struct** (line 222): Add `bool cctpAdapter;`
4. **`_getContractAvailability`** (line 266): Add CCTP availability check — CCTP is available on all chains where TokenMessengerV2 exists. Since the address is universal, we can check code.length on-chain, or use a config mapping like `cctpTokenMessengerV2s[chainId]`. Simplest: add per-chain config for CCTP support (skip BNB, Berachain, Gnosis, HyperEVM, Flare).
5. **Core deployment section** (~line 1666): Add CCTPAdapter deployment alongside AcrossV3Adapter/DebridgeAdapter:
   ```solidity
   if (availability.cctpAdapter) {
       coreContracts.cctpAdapter = __deployContractIfNeeded(
           CCTP_ADAPTER_KEY, chainId, __getSalt(CCTP_ADAPTER_KEY),
           abi.encodePacked(__getBytecode("CCTPAdapter", env),
               abi.encode(CCTP_MESSAGE_TRANSMITTER_V2, coreContracts.superDestinationExecutor))
       );
   }
   ```
6. **Hook array** (line 2188): Increase `len = 56` → `len = 58`. Add hooks at indices 56-57:
   ```solidity
   // CCTP Bridge Hooks - Only deploy if available
   if (availability.cctpAdapter) {
       superValidator = _getContract(chainId, SUPER_VALIDATOR_KEY);
       hooks[56] = _createSafeHookDeploymentWithArgs(
           CCTP_SEND_AND_EXECUTE_ON_DST_HOOK_KEY,
           "CCTPSendAndExecuteOnDstHook", env,
           abi.encode(CCTP_TOKEN_MESSENGER_V2, superValidator)
       );
       hooks[57] = _createSafeHookDeploymentWithArgs(
           APPROVE_AND_CCTP_SEND_AND_EXECUTE_ON_DST_HOOK_KEY,
           "ApproveAndCCTPSendAndExecuteOnDstHook", env,
           abi.encode(CCTP_TOKEN_MESSENGER_V2, superValidator)
       );
   } else {
       hooks[56] = HookDeployment("", "", "");
       hooks[57] = HookDeployment("", "", "");
   }
   ```
7. **Hook address assignment** (~line 2612): Add entries for the CCTP hooks.
8. **Adapter count** in `_getContractAvailability`: Update `adapterContracts` array to include CCTPAdapter.
9. **Output JSON**: Add CCTPAdapter, CCTPSendAndExecuteOnDstHook, ApproveAndCCTPSendAndExecuteOnDstHook.

### 8. `script/run/regenerate_bytecode.sh`

Add to `HOOK_CONTRACTS` array:
```bash
"CCTPSendAndExecuteOnDstHook"
"ApproveAndCCTPSendAndExecuteOnDstHook"
```

Add to `CORE_CONTRACTS` array:
```bash
"CCTPAdapter"
```

### 9. Copy bytecode to locked directories

After `regenerate_bytecode.sh`, copy JSON files to:
- `script/locked-bytecode/` (prod)
- `script/locked-bytecode-dev/` (dev/staging)

## Files to Create (Tests)

### 10. `test/unit/hooks/bridges/cctp/CCTPSendAndExecuteOnDstHook.t.sol`

Test cases:
- Constructor validation (zero addresses)
- `_buildHookExecutions` with valid data → correct depositForBurn calldata
- `usePrevHookAmount` adjusts amount from previous hook
- `destinationMessage` signature injection from transient storage
- Minimum data length enforcement
- Zero amount rejection
- `inspect()` returns expected addresses
- `decodeUsePrevHookAmount()` correct decode

### 11. `test/unit/hooks/bridges/cctp/ApproveAndCCTPSendAndExecuteOnDstHook.t.sol`

Same as above plus:
- 4 executions returned (approve pattern)
- Approve targets correct token and spender (TokenMessengerV2)

### 12. `test/unit/adapters/CCTPAdapter.t.sol`

Test cases:
- Constructor validation
- `receiveAndExecute` with mock MessageTransmitter
- Token balance delta correctly transfers to account
- `processBridgedExecution` called with correct params
- Execution data decode and forwarding

## Supported Chains

CCTP V2 is available on these Superform chains:

| Chain | Chain ID | CCTP Domain |
|-------|----------|-------------|
| Ethereum | 1 | 0 |
| Avalanche | 43114 | 1 |
| Optimism | 10 | 2 |
| Arbitrum | 42161 | 3 |
| Base | 8453 | 6 |
| Polygon | 137 | 7 |
| Unichain | 130 | 10 |
| Linea | 59144 | 11 |
| Sonic | 146 | 13 |
| Worldchain | 480 | 14 |

**NOT supported:** BNB (56), Berachain (80094), Gnosis (100), HyperEVM (999), Flare (14)

## Key References

- `src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHook.sol` — source hook pattern
- `src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol` — approve variant pattern
- `src/adapters/AcrossV3Adapter.sol` — destination adapter pattern (push model)
- `src/adapters/DebridgeAdapter.sol` — alternative adapter pattern
- `src/hooks/BaseHook.sol` — base hook class
- `src/interfaces/ISuperDestinationExecutor.sol` — `processBridgedExecution` signature
- `src/interfaces/ISuperSignatureStorage.sol` — transient storage signature retrieval
- `src/vendor/BytesLib.sol` — packed bytes decoding utilities

## Verification

1. `forge build` — compiles cleanly
2. Run unit tests for both hooks and adapter
3. Verify data layout matches documentation
4. Check that hook indices don't conflict with existing hooks in DeployV2Core.s.sol
