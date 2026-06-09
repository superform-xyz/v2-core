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

### Phase 3: Deployment constants — COMPLETE

Added to `script/utils/Constants.sol`:
- `ACROSS_V3_ADAPTER_V2_KEY = "AcrossV3AdapterV2"`
- `ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY = "AcrossSendFundsAndExecuteOnDstHookV2"`
- `APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_V2_KEY = "ApproveAndAcrossSendFundsAndExecuteOnDstHookV2"`

### Phase 4: Across V2 Compact Format — COMPLETE

Applied the same data minimization pattern from Stargate V2 to the Across adapter.

1. **`src/adapters/AcrossV3AdapterV2.sol`** — Created
   - Compact 2-field decode: `abi.decode(message, (bytes, bytes))` → (initData, sigDataRaw)
   - `_extractFromSigData()` decodes SignatureData and finds matching DstProof by `uint64(block.chainid)`
   - Returns `ExtractedData` struct to avoid stack-too-deep
   - `NoDstProofForChain` event for graceful no-match (emit + return, no revert)
   - `failedTransfers` mapping + `claimFailedTransfer()` with nonReentrant
   - `_tryTransfer()` handles non-standard ERC20s, returns false for address(0) account
   - All V1 security patterns preserved: sender check, try/catch for executor

2. **`src/hooks/bridges/across/AcrossSendFundsAndExecuteOnDstHookV2.sol`** — Created
   - Receives 1-field destinationMessage: `abi.encode(initData)` from bundler
   - Retrieves sigData from transient storage via `ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account)`
   - Produces compact 2-field output: `abi.encode(initData, sigData)`
   - Minimum destinationMessage length check: 64 bytes
   - Same data layout as V1 (same byte offsets for all fixed fields)

3. **`src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHookV2.sol`** — Created
   - Same compact encoding as the non-approve variant
   - 4-execution approval pattern: approve(0) → approve(amount) → bridge → approve(0)

4. **`test/unit/hooks/bridges/AcrossHooksV2.t.sol`** — Created (29 tests, all passing)
   - `MockAcrossSignatureStorageV2` returns sigData with DstProof matching current chain
   - AcrossSendFundsAndExecuteOnDstHookV2 tests: constructor, build with/without destinationMessage, compact encoding, prevHookAmount scaling, native value update, reverts (data too short, zero amount, zero recipient, zero prevHookAmount, short destinationMessage), inspector, decodeUsePrevHookAmount
   - ApproveAndAcrossSendFundsAndExecuteOnDstHookV2 tests: constructor, ERC20 approval pattern (4 executions), build with destinationMessage, prevHookAmount, reverts (data too short, zero amount, zero recipient), inspector, decodeUsePrevHookAmount, subtype

5. **`test/integration/across/AcrossV3AdapterV2E2EFork.t.sol`** — Created (19 tests, all passing)
   - Fork tests on Base mainnet
   - Tests: compact format transfer succeeds, execution fails but tokens transferred, transfer fails + claim, zero account reverts, NoDstProofForChain reverts, invalid sender, constructor zero address, claim zero/unauthorized, multiple failed transfers accumulate, different users isolation, partial claim, claim exceeds balance, multiple DstProofs first match, empty proofDst reverts, large sigData correct chain, event verification, immutable getters

### Phase 5: Security Fixes — COMPLETE

1. **CRITICAL: NoDstProofForChain → revert** (was graceful emit+return causing permanent token loss)
   - Across fills are independent — reverting is safe (unlike Stargate lzCompose)
   - Changed from `emit NoDstProofForChain(guid, chainId); return;` to `revert NO_DST_PROOF_FOR_CHAIN()`
   - Updated tests to `vm.expectRevert`

2. **MEDIUM: address(0) account → revert** (was crediting unclaimable failedTransfers[address(0)])
   - Added explicit `if (extracted.account == address(0)) revert ACCOUNT_NOT_VALID()`
   - Matches V1 behavior where `safeTransfer(address(0))` reverts
   - Updated tests to `vm.expectRevert`

### Phase 6: Deployment Logic — COMPLETE

Modified `script/DeployV2Core.s.sol`:
- `CoreContracts` struct: added `address acrossV3AdapterV2`
- `HookAddresses` struct: added `acrossSendFundsAndExecuteOnDstHookV2` and `approveAndAcrossSendFundsAndExecuteOnDstHookV2`
- `ContractAvailability` struct: added `bool acrossV3AdapterV2`
- `_populateCoreContractsFromStatus()`: added AcrossV3AdapterV2 lookup
- `_getContractAvailability()`: adapter array 4, V2 availability set alongside V1, hooks array 72, expectedHooks -= 4 for V1+V2
- `_deployCoreContracts()`: AcrossV3AdapterV2 deployment block (same constructor args as V1)
- `_deployHooks()`: len=78, hooks[76-77] for V2 Across hooks, address mappings, validation checks

Modified `script/run/regenerate_bytecode.sh`:
- Added `AcrossV3AdapterV2` to `CORE_CONTRACTS` array
- Added `AcrossSendFundsAndExecuteOnDstHookV2` and `ApproveAndAcrossSendFundsAndExecuteOnDstHookV2` to `HOOK_CONTRACTS` array

### Phase 7: Bytecode Generation — COMPLETE

Generated and copied bytecode for 3 new contracts to all 3 folders:
- `script/generated-bytecode/`
- `script/locked-bytecode/`
- `script/locked-bytecode-dev/`

### Security Recheck Summary — NO REGRESSIONS

| Aspect | V1 | V2 | Status |
|--------|----|----|--------|
| Sender check | revert INVALID_SENDER | Same | OK |
| Transfer | safeTransfer (reverts) | _tryTransfer + failedTransfers | V2 more robust |
| address(0) | safeTransfer reverts | Explicit revert ACCOUNT_NOT_VALID | OK |
| No DstProof | N/A | revert NO_DST_PROOF_FOR_CHAIN | OK |
| Executor call | Direct (reverts propagate) | try/catch (best-effort) | V2 more robust |
| Claim | None | claimFailedTransfer + nonReentrant | V2 improvement |
| Hook data layout | Same byte offsets | Same | OK |
| Min length check | None | < 64 → revert | V2 more robust |
