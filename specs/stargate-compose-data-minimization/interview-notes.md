# Interview Notes: Stargate Compose Data Minimization

## Date: 2026-06-05

## Problem Statement
LayerZero has a 10k byte limit on messages. The current Stargate hook and adapter compose message format contains redundant data — `executorCalldata`, `account`, `dstTokens`, and `intentAmounts` are encoded at the top level AND duplicated inside `sigData` (within `DstProof.info`). The `executorCalldata` alone is typically 1-5 KB, so this duplication can push the total LZ message past the 10k limit for complex operations.

## Evidence
- Tenderly simulation showing the limit being exceeded: https://www.tdly.co/shared/simulation/7ee45a9f-2166-4dd1-bf87-1ed186c0b3b7
- Transaction: `0x4ea04967a1a7a897b0e3563865433ec121aec09a6377baf869900070dba60dff`
- Contract: StargateOFTUSDC on Flare chain
- The total LZ message exceeds 10k bytes

## Key Decisions

### Scope: Modes 0-2 only
- Mode 0 (taxi), 1 (bus), and 2 (OFT) use composeMsg with the standard encoding
- Mode 3 (lzMulticall) uses raw executeCalldata directly and has a different payload structure — excluded

### SigData: Keep as-is
- Do NOT strip proofSrc or filter DstProof entries for the current chain only
- Only remove the redundant top-level fields (executorCalldata, account, dstTokens, intentAmounts)
- Simpler implementation, still achieves the primary savings (1-5 KB from removing duplicate executorCalldata)

### Deployment: New V2 contracts
- Deploy as new contracts: `StargateAdapterV2`, `StargateSendHookV2`, `ApproveAndStargateSendHookV2`
- Existing deployments keep working — no migration needed
- New operations use V2 with compact encoding

### Security: Same trust model
- Current adapter already transfers tokens before executor validation — accepted design
- Extracting account from sigData instead of top-level doesn't change the trust model
- The executor validates the full signature chain afterward

## Current Data Flow
```
Hook (source) → composeMsg → LZ → Adapter (dest) → Executor
```

### Current composeMsg encoding:
```
abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, sigData)
```

### Proposed composeMsg encoding:
```
abi.encode(initData, sigData)
```

### Adapter extraction:
The adapter decodes sigData as SignatureData, finds the DstProof for the current chain, and extracts:
- `executorCalldata` ← `proofDst[currentChain].info.data`
- `account` ← `proofDst[currentChain].info.account`
- `dstTokens` ← `proofDst[currentChain].info.dstTokens`
- `intentAmounts` ← `proofDst[currentChain].info.intentAmounts`

Then calls `processBridgedExecution` with all parameters as before.

## Size Savings Estimate
- **Primary**: Removing duplicate `executorCalldata` saves 1-5 KB
- **Secondary**: Removing duplicate `account` (32 bytes), `dstTokens` (64+ bytes), `intentAmounts` (64+ bytes)
- **ABI overhead**: Fewer dynamic fields saves ~200 bytes in offset pointers and length prefixes
- **Total estimated savings**: 1.5-5.5 KB depending on operation complexity

## Constraints
- SuperDestinationExecutor: locked bytecode — interface unchanged
- SuperDestinationValidator: locked bytecode — sigData format unchanged
- The adapter must call `processBridgedExecution` with exact same parameters as before

## Contracts to Create
1. `src/hooks/bridges/stargate/StargateSendHookV2.sol` — compact composeMsg encoding
2. `src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol` — same with approval pattern
3. `src/adapters/StargateAdapterV2.sol` — decodes compact format, extracts fields from sigData

## Risk Notes
- Adapter now depends on sigData internal structure (ISuperValidator.SignatureData, DstProof, DstInfo)
- If validator signature format changes in the future, adapter must be updated too
- This coupling is acceptable since both are part of the same protocol
