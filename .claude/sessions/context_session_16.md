# Session 16: Stargate Compose Data Minimization — V2 Implementation

## Status: IN PROGRESS
- Date: 2026-06-05
- Spec: `specs/stargate-compose-data-minimization/`

## Overview
Implementing 3 new V2 contracts that reduce the Stargate compose message from 6-field to 2-field format (`abi.encode(initData, sigData)`), eliminating duplicate data (executorCalldata, account, dstTokens, intentAmounts) that already exists inside `sigData.proofDst[i].info`.

## Key Design Decisions
- Modes 0-2 only (mode 3 excluded from V2)
- Keep sigData as-is (no stripping of proofSrc or filtering DstProof)
- New V2 contracts alongside V1 (no breaking changes)
- Executor/validator interfaces unchanged (locked bytecode)

## Contracts to Create

### 1. `src/adapters/StargateAdapterV2.sol`
- Decode compact 2-field format: `abi.decode(innerPayload, (bytes, bytes))` → (initData, sigDataRaw)
- Extract account, executorCalldata, dstTokens, intentAmounts from sigData's DstProof.info
- Find DstProof where `dstChainId == uint64(block.chainid)`
- Call `processBridgedExecution` with same parameters as V1
- Preserve ALL V1 security patterns (sender check, pool registration, try/catch bare catch, preBalance, failedTransfers)
- New event: `NoDstProofForChain(bytes32 guid, uint64 chainId)` for graceful no-match handling

### 2. `src/hooks/bridges/stargate/StargateSendHookV2.sol`
- Hook receives 1-field composeMsg from bundler: just `abi.encode(initData)` (only initData, no executorCalldata/account/dstTokens/intentAmounts)
- Retrieves sigData from transient storage via `ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)`
- Produces compact output: `abi.encode(initData, sigData)`
- No `_account != account` validation (account no longer in composeMsg input)
- Minimum composeMsg length check updated (was 160 for 5-field, now 32 for 1-field — at minimum needs ABI offset for initData bytes)

### 3. `src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol`
- Same compose encoding changes as StargateSendHookV2
- Plus existing 4-execution approval pattern (approve 0 → approve amount → send → approve 0)

## Changes Made

### Phase 1: Core Contracts — COMPLETE

1. **`src/adapters/StargateAdapterV2.sol`** — Created
   - Compact 2-field decode: `abi.decode(innerPayload, (bytes, bytes))` → (initData, sigDataRaw)
   - `_extractFromSigData()` decodes SignatureData and finds matching DstProof by `uint64(block.chainid)`
   - Returns `ExtractedData` struct to avoid stack-too-deep (V2 has deeper decode than V1)
   - `_handleTransferAndExecution()` split from `handleCompose()` for same reason
   - `NoDstProofForChain` event for graceful no-match (emit + return, no revert)
   - All V1 security patterns preserved: sender check, pool registration, try/catch bare catch, preBalance, failedTransfers, claimFailedTransfer with nonReentrant

2. **`src/hooks/bridges/stargate/StargateSendHookV2.sol`** — Created
   - Receives 1-field composeMsg: `abi.encode(initData)` from bundler
   - Retrieves sigData from transient storage via `ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)`
   - Produces compact 2-field output: `abi.encode(initData, sigData)`
   - Minimum composeMsg length check: 64 bytes (ABI offset + length for single bytes field)
   - No `_account != account` validation (account no longer in input)
   - Modes 0-2 only (mode 3 excluded with `if (s.mode > 2) revert MODE_NOT_VALID()`)
   - Mode checks moved outside `if (s.mode <= 2)` block since all modes are <= 2

3. **`src/hooks/bridges/stargate/ApproveAndStargateSendHookV2.sol`** — Created
   - Same compose encoding as StargateSendHookV2
   - 4-execution approval pattern: approve(0) → approve(amount) → bridge → approve(0)
   - Modes 0-2 only

All 3 contracts compile successfully with `forge build`.

### Phase 2: Tests — COMPLETE

1. **`test/unit/hooks/bridges/StargateHooksV2.t.sol`** — Created (40 tests, all passing)
   - `MockStargateSignatureStorageV2` returns sigData with DstProof matching current chain
   - StargateSendHookV2 tests: constructor, taxi/bus/OFT modes, composeMsg encoding, prevHookAmount scaling, reverts (data too short, zero amount, zero pool, zero recipient, invalid mode 3, compose too short, EOA pool, extraOptions overflow), inspector, decodeUsePrevHookAmount, fail-fast validation order, data length boundary
   - ApproveAndStargateSendHookV2 tests: constructor, ERC20 approval pattern (4 executions), OFT mode, composeMsg encoding, prevHookAmount, reverts (data too short, zero input token, invalid mode, pool mismatch), inspector, fail-fast validation

2. **`test/integration/stargate/StargateAdapterV2E2EFork.t.sol`** — Created (14 tests, all passing)
   - Fork tests on Base mainnet
   - Tests: compact format transfer succeeds, execution fails but tokens transferred, transfer fails + claim, zero account + composeFrom claim, NoDstProofForChain graceful handling, invalid sender, compose too short, constructor zero address, claim zero/unauthorized, malformed payload pipeline resilience, unregistered pool, multi-compose accumulation, different users isolation
   - Helper `_buildV2ComposeMsg` creates compact 2-field format with sigData containing DstProof for current chain
   - Helper `_buildV2ComposeMsgWrongChain` for NoDstProofForChain testing

### Phase 3: Deployment constants — TODO
