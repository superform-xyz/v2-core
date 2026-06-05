# Stargate Compose Data Minimization — Technical Specification

## Overview

LayerZero V2 enforces a 10,000-byte message size limit (default in SendUln302). The current Stargate hook/adapter compose message duplicates `executorCalldata`, `account`, `dstTokens`, and `intentAmounts` — these exist at the top level AND inside `sigData.proofDst[i].info`. Since `executorCalldata` is typically 1-5 KB, this duplication can push messages past the 10k limit for complex operations.

The fix: encode only `abi.encode(initData, sigData)` in the compose message, and have the adapter extract the redundant fields from sigData on the destination chain. No changes to executor or validator contracts.

## Problem Statement

Evidence: Tenderly simulation `0x4ea04967a1a7a897b0e3563865433ec121aec09a6377baf869900070dba60dff` on Flare chain exceeds the 10k LZ message limit calling `quoteSend` on StargateOFTUSDC.

Current composeMsg wire format (6-field ABI-encoded):
```
abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)
```

Where sigData internally contains (within `DstProof.info`):
- `info.data` = executorCalldata (DUPLICATE)
- `info.account` = account (DUPLICATE)
- `info.dstTokens` = dstTokens (DUPLICATE)
- `info.intentAmounts` = intentAmounts (DUPLICATE)

## Proposed Solution

### New composeMsg wire format (2-field ABI-encoded):
```
abi.encode(initData, sigData)
```

### Adapter extraction logic:
```solidity
(bytes memory initData, bytes memory sigDataRaw) = abi.decode(innerPayload, (bytes, bytes));

// Decode SignatureData
(,,,, bytes32[] memory proofSrc, ISuperValidator.DstProof[] memory proofDst,) =
    abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

// Find DstProof for current chain
for (uint256 i; i < proofDst.length; ++i) {
    if (proofDst[i].dstChainId == uint64(block.chainid)) {
        account = proofDst[i].info.account;
        executorCalldata = proofDst[i].info.data;
        dstTokens = proofDst[i].info.dstTokens;
        intentAmounts = proofDst[i].info.intentAmounts;
        break;
    }
}

// Call executor with same interface as before
SUPER_DESTINATION_EXECUTOR.processBridgedExecution(
    tokenSent, account, dstTokens, intentAmounts, initData, executorCalldata, sigDataRaw
);
```

### Size savings (TaxiCodec overhead = 75 bytes, effective max composeMsg ≈ 9,925 bytes):

| Component | V1 Size | V2 Size | Savings |
|-----------|---------|---------|---------|
| executorCalldata (duplicate) | 1-5 KB | 0 | **1-5 KB** |
| account (duplicate) | 32 B | 0 | 32 B |
| dstTokens (duplicate, 1 token) | 96 B | 0 | 96 B |
| intentAmounts (duplicate, 1 token) | 96 B | 0 | 96 B |
| ABI offsets (4 fewer fields) | 128 B | 0 | 128 B |
| ABI lengths (4 fewer fields) | 128 B | 0 | 128 B |
| **Total** | | | **~1.5-5.5 KB** |

## Technical Considerations

### Architecture
- V2 contracts deployed alongside V1 — no migration, no breaking changes
- V2 hook ↔ V2 adapter must be used together (incompatible with V1 counterparts)
- Executor and validator interfaces unchanged (locked bytecode)

### Security (parity with V1)
All V1 security patterns MUST be preserved:

1. `msg.sender == LZ_ENDPOINT` — blocks unauthorized compose calls
2. `TOKEN_MESSAGING.assetIds(_from) == 0` — blocks spoofed pools
3. `try this.handleCompose(...) catch {}` — bare catch prevents returnbomb + compose queue blocking
4. `preBalance` check — prevents unbacked failedTransfers credits
5. `account == address(0)` guard with `composeFrom` fallback
6. `nonReentrant` on `claimFailedTransfer`

New V2-specific mitigations:
7. `uint64(block.chainid)` explicit cast for DstProof matching
8. Graceful "no matching DstProof" handling — emit event + return, no revert
9. All sigData parsing as pure memory operations — no new external calls in decode path

### Performance
- `abi.decode` for 2-tuple: ~800-1,500 gas (vs ~2,000-3,000 for 6-tuple in V1)
- Additional SignatureData decode: ~2,000-3,000 gas for nested struct
- Net gas impact on destination: roughly neutral (simpler outer decode, deeper inner decode)

## Attack Surface Analysis

### Token Risks
- [x] Transfer-before-validation: Same as V1 — accepted design
- [x] Zero-account handling: Preserved from V1 with composeFrom fallback

### Reentrancy
- [x] CEI pattern followed — token transfer before execution, same as V1
- [x] `handleCompose` gated by `msg.sender == address(this)`
- [x] `claimFailedTransfer` protected by `nonReentrant`

### Cross-Chain Risks
- [x] Message replay: `usedMerkleRoots` in executor — unchanged
- [x] Compose spoofing: Pool registration check — unchanged
- [x] Version mismatch: V2 hook → V1 adapter fails gracefully (caught by try/catch)

### DOS Vectors
- [x] Memory expansion gas bomb: Malformed sigData with inflated arrays → absorbed by try/catch + EIP-150 1/64 rule
- [x] Unbounded DstProof iteration: Bounded by message size (max ~10k bytes)

### Exploit Precedents
| Exploit | Mitigation |
|---------|-----------|
| CrossCurve $3M (2026) — missing sender validation | Retain `msg.sender == LZ_ENDPOINT` + pool check |
| Tapioca lzCompose (2024) — compose impersonation | Don't trust composeFrom for execution, only for fallback claims |
| KelpDAO $292M (2026) — DVN compromise | Operational: ensure 3/3+ DVN config |

## Acceptance Criteria

### Functional
- [ ] V2 compose message uses `abi.encode(initData, sigData)` format
- [ ] V2 adapter correctly extracts account, executorCalldata, dstTokens, intentAmounts from sigData
- [ ] V2 adapter calls `processBridgedExecution` with identical parameters as V1
- [ ] Modes 0 (taxi), 1 (bus — no compose), and 2 (OFT) work correctly
- [ ] Failed transfer + claim flow works identically to V1
- [ ] Hook `inspect()` function returns correct data for the new format

### Security
- [ ] All 6 V1 security checks preserved (see Technical Considerations)
- [ ] No matching DstProof → emits event + returns (no revert)
- [ ] Zero account → failedTransfers keyed by composeFrom
- [ ] Malformed sigData → caught by try/catch, emits ComposeDecodeFailed

### Non-Functional
- [ ] compose message size reduced by 1.5-5.5 KB vs V1
- [ ] Gas cost on destination chain is within 10% of V1

## Implementation

### Phase 1: New Contracts

#### 1. `src/adapters/StargateAdapterV2.sol`

```solidity
contract StargateAdapterV2 is ILayerZeroComposer, ReentrancyGuard {
    // Same immutables as V1: LZ_ENDPOINT, TOKEN_MESSAGING, SUPER_DESTINATION_EXECUTOR
    // Same storage: failedTransfers mapping
    // Same events + new: NoDstProofForChain(bytes32 guid, uint64 chainId)

    function lzCompose(address _from, bytes32 _guid, bytes calldata _message, address, bytes calldata) external payable {
        // Same validation as V1: sender check, message length, pool registration
        // Same: extract amountLD, composeFrom from OFTComposeMsgCodec header
        // Same: resolve token via IStargate(_from).token()
        // Same: try this.handleCompose(...) catch { emit ComposeDecodeFailed(_guid); }
    }

    function handleCompose(bytes32 _guid, bytes calldata _message, address tokenSent, uint256 amountLD, address composeFrom) external {
        if (msg.sender != address(this)) revert INVALID_SENDER();

        // NEW: Decode compact 2-field format
        (bytes memory initData, bytes memory sigDataRaw) = abi.decode(_message[COMPOSE_MSG_OFFSET:], (bytes, bytes));

        // NEW: Extract fields from sigData
        (address account, bytes memory executorCalldata, address[] memory dstTokens, uint256[] memory intentAmounts)
            = _extractFromSigData(sigDataRaw);

        // SAME AS V1: preBalance check, account validation, transfer, execution
        // ...
    }

    function _extractFromSigData(bytes memory sigDataRaw) internal view returns (...) {
        // Decode SignatureData struct
        (,,,,, ISuperValidator.DstProof[] memory proofDst,) =
            abi.decode(sigDataRaw, (uint64[], uint48, uint48, bytes32, bytes32[], ISuperValidator.DstProof[], bytes));

        // Find DstProof for current chain
        uint64 currentChain = uint64(block.chainid);
        for (uint256 i; i < proofDst.length; ++i) {
            if (proofDst[i].dstChainId == currentChain) {
                return (
                    proofDst[i].info.account,
                    proofDst[i].info.data,
                    proofDst[i].info.dstTokens,
                    proofDst[i].info.intentAmounts
                );
            }
        }
        revert NO_DST_PROOF_FOR_CHAIN();
    }

    // SAME AS V1: claimFailedTransfer, _tryTransfer, receive()
}
```

#### 2. `src/hooks/bridges/stargate/StargateSendHookV2.sol`

Key changes from V1:
- Hook data composeMsg field now contains only `abi.encode(initData)` (1-field, no executorCalldata/account/dstTokens/intentAmounts)
- Hook retrieves sigData from transient storage and produces `abi.encode(initData, sigData)` as final composeMsg
- Remove `_account != account` validation (account no longer in composeMsg input)
- Update minimum composeMsg length check (was 160 for 5-field, now smaller for 1-field)

```solidity
// In _buildHookExecutions, when composeMsg.length > 0:
if (s.composeMsg.length > 0) {
    bytes memory initData = abi.decode(s.composeMsg, (bytes));
    bytes memory sigData = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);
    s.composeMsg = abi.encode(initData, sigData);
}
```

#### 3. `src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol`

Same changes as StargateSendHookV2, plus the existing 4-execution approval pattern.

### Phase 2: Tests

#### Unit Tests: `test/unit/hooks/bridges/StargateHooksV2.t.sol`
- Test compact encoding for modes 0, 1, 2
- Test prevHookAmount scaling
- Test revert conditions (data too short, invalid mode, invalid pool)
- Test inspect() output

#### Integration Tests: `test/integration/stargate/StargateAdapterV2Fork.t.sol`
- Test full lzCompose flow with compact format
- Test sigData extraction for various DstProof configurations
- Test no-matching-chain graceful handling
- Test failed transfer + claim flow
- Test malformed sigData handling

### Phase 3: Deployment
- Add constants: `STARGATE_ADAPTER_V2_KEY`, `STARGATE_SEND_HOOK_V2_KEY`, `APPROVE_AND_STARGATE_SEND_HOOK_V2_KEY`
- Add deployment logic to `DeployV2Core.s.sol` or separate deployment script
- Generate locked bytecodes

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| V2 hook deployed without V2 adapter | Low | Medium | Deployment docs + checklist |
| sigData format changes in future validator | Low | High | Adapter coupled to validator struct — must update together |
| Gas increase on destination from deeper decode | Low | Low | Roughly neutral — simpler outer, deeper inner |
| Complex operations still exceed 10k | Low | Medium | Secondary optimizations available: strip proofSrc, filter DstProof |

## References

### Internal
- `src/adapters/StargateAdapter.sol` — V1 adapter (6-tuple decode)
- `src/hooks/bridges/stargate/StargateSendHook.sol` — V1 hook (5→6 field encoding)
- `src/interfaces/ISuperValidator.sol` — SignatureData, DstProof, DstInfo structs
- `src/validators/SuperValidatorBase.sol:136-149` — `_decodeSignatureData()`
- `src/validators/SuperDestinationValidator.sol:110-116` — `_extractProof()`
- `src/executors/SuperDestinationExecutor.sol:94-143` — `processBridgedExecution()`

### External
- [LZ V2 Protocol Overview](https://docs.layerzero.network/v2/developers/evm/protocol-contracts-overview)
- [OFTComposeMsgCodec.sol](https://github.com/LayerZero-Labs/LayerZero-v2/blob/main/packages/layerzero-v2/evm/oapp/contracts/oft/libs/OFTComposeMsgCodec.sol)
- [TaxiCodec.sol](https://github.com/stargate-protocol/stargate-v2/blob/main/packages/stg-evm-v2/src/libs/TaxiCodec.sol)
- [Stargate Composability](https://docs.stargate.finance/developers/protocol-docs/composability)
