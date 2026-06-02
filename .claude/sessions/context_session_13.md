# Session 13: Add lzMulticall Mode (mode=3) to Stargate Bridge Hooks

## Summary
Added mode 3 (lzMulticall) to both `StargateSendHook` and `ApproveAndStargateSendHook`. This mode allows the bundler to batch multiple LayerZero operations via `ILZMultiCall.execute(calls, quoteId)`.

## Changes Made

### 1. New Interface: `src/vendor/bridges/layerzero/ILZMultiCall.sol`
- Minimal interface with `Call` struct and `execute()` function

### 2. `src/hooks/bridges/stargate/StargateSendHook.sol`
- Added `ILZMultiCall` import
- Added `executeCalldata` field to `StargateSendData` struct
- Changed mode validation from `> 2` to `> 3`
- Wrapped `to` validation and `pool.token()` check in `if (s.mode <= 2)`
- Wrapped `usePrevHookAmount`, `amountLD` validation, and `composeMsg` processing in `if (s.mode <= 2)`
- Added `executeCalldata` decoding for mode 3 (after composeMsg)
- Changed OFT branch from `else` to `else if (s.mode == 2)` and added `else` for mode 3
- Mode 3 execution: single execution targeting `stargatePool` (=lzMulticall address) with `lzNativeFee` as value and raw `executeCalldata`

### 3. `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`
- Same structural changes as StargateSendHook for validation and decoding
- In `_buildExecutions()`: changed OFT branch to `else if (s.mode == 2)` and added `else` for mode 3 that sets `sendCallData = s.executeCalldata`
- The 4-execution approve pattern stays the same — `stargatePool` = lzMulticall address, so approvals target lzMulticall

### 4. `test/unit/hooks/bridges/StargateHooks.t.sol`
- Added `ILZMultiCall` import
- Updated mode=3 revert tests to use mode=4
- Updated fuzz test to exclude mode 3 (needs executeCalldata)
- Added 10 new tests for mode 3:
  - `test_StargateSend_Build_LzMulticallMode` - basic success
  - `test_StargateSend_Build_LzMulticallMode_PoolValidationSkipped` - no token() needed
  - `test_StargateSend_Build_LzMulticallMode_ToZeroAllowed` - bytes32(0) ok
  - `test_StargateSend_Build_LzMulticallMode_RevertIf_EmptyExecuteCalldata`
  - `test_StargateSend_Build_LzMulticallMode_RevertIf_PoolZero`
  - `test_StargateSend_Build_LzMulticallMode_CorrectValueAndCalldata`
  - `test_ApproveAndStargateSend_Build_LzMulticallMode` - 6 executions with approve pattern
  - `test_ApproveAndStargateSend_Build_LzMulticallMode_TokenMatchSkipped`
  - `test_ApproveAndStargateSend_Build_LzMulticallMode_CalldataForwarded`
  - `test_ApproveAndStargateSend_Build_LzMulticallMode_RevertIf_InputTokenZero`
- Added helpers: `_encodeLzMulticallData()`, `_buildMockExecuteCalldata()`

### 5. `test/integration/stargate/StargateHooksFork.t.sol`
- Added `ILZMultiCall` import
- Updated mode=3 revert tests to use mode=4
- Added LZ_MULTICALL constant: `0xAcdDAC6C77318B615f7F6fB9bb67c6833e9c05f1` (real deployed address, same on all EVM chains)
- Added 8 new integration tests:
  - `test_Fork_LzMulticall_ContractExists` - verifies contract is deployed on mainnet
  - `test_Fork_StargateSend_LzMulticallMode_Build` - build with realistic Stargate sendToken inner calls
  - `test_Fork_ApproveAndStargateSend_LzMulticallMode_Build` - approval targets lzMulticall
  - `test_Fork_ApproveAndStargateSend_LzMulticallMode_ApprovalLifecycle` - **real execution** on fork: approve, call lzMulticall.execute, cleanup
  - `test_Fork_StargateSend_LzMulticallMode_SkipsPoolValidation` - pool.token() not called
  - `test_Fork_StargateSend_LzMulticallMode_ValueIsLzNativeFee` - value = lzNativeFee
  - `test_Fork_StargateSend_LzMulticallMode_MultipleCallsCalldata` - multi-send with real quoteSend fees
  - `test_Fork_StargateSend_LzMulticallMode_RevertIf_EmptyCalldata` - empty calldata reverts
- Added helpers: `_encodeLzMulticallForkData()`, `_buildMultiSendCalldata()`
- Added 2 pigeon cross-chain tests for mode 3:
  - `test_Fork_CrossChain_LzMulticall_StargateSend_WithPigeon` - full ETH→Base flow: pre-fund lzMulticall with USDC, Call[] does approve+sendToken, pigeon relays LZ message, verify USDC received on Base (~999.4 USDC received for 1000 sent)
  - `test_Fork_CrossChain_LzMulticall_ApproveAndStargateSend_WithPigeon` - full ETH→Base flow: account holds USDC, hook approves lzMulticall, Call[] does transferFrom+approve+sendToken, pigeon relays, verify receipt on Base
- Added helpers: `_buildPigeonSendCalls()`, `_buildPigeonTransferAndSendCalls()`

### 6. Bytecode Regenerated
- `script/generated-bytecode/StargateSendHook.json`
- `script/generated-bytecode/ApproveAndStargateSendHook.json`

## Key Addresses
- LZMultiCall: `0xAcdDAC6C77318B615f7F6fB9bb67c6833e9c05f1` (same on all EVM chains via CREATE2)
- TransferDelegate: `0x72fAEbF58A62e33C044c37D8D973a961633ea294`
- LZ Endpoint (ETH & Base): `0x1a44076050125825900e736c501f859c50fE728c`
- Stargate USDC Pool ETH: `0xc026395860Db2d07ee33e05fE50ed7bD583189C7`
- USDC ETH: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`
- USDC Base: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

## Test Results
- Unit tests: 116/116 pass
- Integration tests: 43/43 pass (was 33, added 8 fork + 2 pigeon cross-chain)
