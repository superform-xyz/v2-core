# Repository Research: Stargate Compose Data Minimization

## 1. Adapter Decode/Forward Patterns

All three adapters (Across, Debridge, Stargate) decode the **same 6-field ABI-encoded payload**:
```solidity
abi.decode(message, (bytes, bytes, address, address[], uint256[], bytes))
//         initData, executorCalldata, account, dstTokens, intentAmounts, sigData
```

### StargateAdapter (`src/adapters/StargateAdapter.sol`)
- Lines 243-250: `handleCompose()` decodes after skipping 76-byte OFTComposeMsgCodec header
- Line 214: Uses `try this.handleCompose(...)` self-call pattern to catch decode panics
- Lines 257-258: Pre-balance snapshot prevents unbacked failedTransfer credits
- Lines 279-304: Non-reverting error handling (emit events to avoid blocking LZ compose pipeline)

### AcrossV3Adapter (`src/adapters/AcrossV3Adapter.sol`)
- Lines 63-70: Same 6-field decode, simpler (no non-revert pattern needed)

### DebridgeAdapter (`src/adapters/DebridgeAdapter.sol`)
- Lines 145-158: `_decodeMessage()` helper with same 6-field decode

**Key: All adapters call `processBridgedExecution` with identical parameter order.**

## 2. Hook Compose Message Encoding

### StargateSendHook (`src/hooks/bridges/stargate/StargateSendHook.sol`)
- Lines 148-166: Encoding flow:
  1. Receives **5-field** composeMsg: `(initData, executorCalldata, account, dstTokens, intentAmounts)`
  2. Retrieves sigData from transient storage: `ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)` (line 153)
  3. Validates `_account == account` (line 163)
  4. Re-encodes as **6-field**: `abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature)` (line 165)
- Line 151: Minimum size check: `s.composeMsg.length < 160`

### ApproveAndStargateSendHook (`src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`)
- Lines 154-172: Identical compose encoding logic
- Lines 210-287: 4-execution approval pattern (approve 0 -> approve amount -> send -> approve 0)

### Hook data layout (tightly packed):
```
Offset 0:    uint256 lzNativeFee      (32 bytes)
Offset 32:   address stargatePool     (20 bytes)
Offset 52:   address inputToken       (20 bytes)
Offset 72:   uint32  dstEid           (4 bytes)
Offset 76:   bytes32 to               (32 bytes)
Offset 108:  uint256 amountLD         (32 bytes)
Offset 140:  uint256 minAmountLD      (32 bytes)
Offset 172:  bool    usePrevHookAmount (1 byte)
Offset 173:  uint8   mode             (1 byte)
Offset 174:  uint256 extraOptionsLen   (32 bytes)
Offset 206:  bytes   extraOptions      (variable)
...+off:     uint256 composeMsgLen     (32 bytes)
...+off+32:  bytes   composeMsg        (variable)
```

## 3. SignatureData / DstProof / DstInfo Structs

From `src/interfaces/ISuperValidator.sol`:

```solidity
struct SignatureData {
    uint64[] chainsWithDestinationExecution;
    uint48 validUntil;
    uint48 validAfter;
    bytes32 merkleRoot;
    bytes32[] proofSrc;
    DstProof[] proofDst;
    bytes signature;
}

struct DstProof {
    bytes32[] proof;
    uint64 dstChainId;
    DstInfo info;
}

struct DstInfo {
    address account;
    address executor;
    address[] dstTokens;
    uint256[] intentAmounts;
    address validator;
    bytes data;              // <-- This is executorCalldata!
}
```

**Critical: `DstInfo.data` = `executorCalldata`** (confirmed in SuperValidator.sol line 78: `callData: dstProof.info.data`).

## 4. BaseValidatorBase SigData Parsing

From `src/validators/SuperValidatorBase.sol` lines 136-149:
```solidity
function _decodeSignatureData(bytes memory sigDataRaw) internal pure virtual returns (SignatureData memory) {
    (...) = abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], DstProof[], bytes));
    return SignatureData(...);
}
```

From `SuperDestinationValidator.sol` lines 110-116:
```solidity
function _extractProof(SignatureData memory sigData) private view returns (bytes32[] memory) {
    for (uint256 i; i < len; ++i) {
        if (sigData.proofDst[i].dstChainId == block.chainid) return sigData.proofDst[i].proof;
    }
    revert PROOF_NOT_FOUND();
}
```

## 5. Signature Retrieval from Transient Storage

From `src/interfaces/ISuperSignatureStorage.sol` line 23:
```solidity
function retrieveSignatureData(address account) external view returns (bytes memory);
```
Returns the full sigData bytes (ABI-encoded SignatureData struct).

## 6. Deployment Patterns

**V2 precedent:** `PendlePTAmortizedOracleV2` uses "V2" suffix, separate deployment script, separate constants key.

**Constants** (`script/utils/Constants.sol`):
- `STARGATE_ADAPTER_KEY = "StargateAdapter"` (line 35)
- `STARGATE_SEND_HOOK_KEY = "StargateSendHook"` (line 276)
- `APPROVE_AND_STARGATE_SEND_HOOK_KEY = "ApproveAndStargateSendHook"` (line 277)

V2 will need: `STARGATE_ADAPTER_V2_KEY`, `STARGATE_SEND_HOOK_V2_KEY`, `APPROVE_AND_STARGATE_SEND_HOOK_V2_KEY`.

## 7. Test Patterns

### Unit tests (`test/unit/hooks/bridges/StargateHooks.t.sol`)
- Uses `MockStargateSignatureStorage` returning hardcoded sigData
- `vm.mockCall` for `IStargate.token()`, `ISuperHookResult.getOutAmount()`
- Helper: `_encodeStargateData(bool usePrevHookAmount, uint8 mode, bool includeComposeMsg)`
- Naming: `test_StargateSend_Build_TaxiMode()`, `test_StargateSend_Build_RevertIf_DataTooShort()`

### Integration/fork tests (`test/integration/stargate/StargateAdapterFork.t.sol`)
- Real on-chain Stargate contracts via `vm.createSelectFork()`
- Helpers: `_encodeComposeMsg()`, `_buildStargateDestinationData()`, `_mockProcessBridgedExecution()`

### E2E tests (`test/integration/stargate/StargateAdapterE2EFork.t.sol`)
- Full flow: source sendToken -> pigeon relay -> lzCompose -> processBridgedExecution
- Uses `MerkleTreeHelper` for Merkle tree construction

## 8. V2 Implementation Implications

**Hook V2:**
- Receive 1-field composeMsg `(initData)` instead of 5-field
- Retrieve sigData from transient storage
- Produce `abi.encode(initData, sigData)` as compact 2-field composeMsg
- Remove `_account != account` validation (account no longer in top-level)
- Update minimum composeMsg length check

**Adapter V2:**
- Decode 2-field format: `(initData, sigData)`
- Decode sigData using same ABI structure as `_decodeSignatureData()`
- Find DstProof matching `block.chainid`
- Extract account, executorCalldata, dstTokens, intentAmounts from DstInfo
- Call `processBridgedExecution()` unchanged
