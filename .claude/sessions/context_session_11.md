# Session 11: OFT Send Hook Implementation

## Status: Implementation Complete - All Unit Tests Passing

## Goal
Extend StargateSendHook and ApproveAndStargateSendHook to support generic LayerZero V2 OFT/OFTAdapter tokens via mode flag.

## Spec
See: `specs/oft-send-hook/technical-spec.md`

## Key Design Decisions
- Repurpose `isBusMode` byte (offset 225) as `uint8 mode` (0=taxi, 1=bus, 2=OFT)
- No data layout offset changes (290 byte minimum preserved)
- New IOFT vendor interface at `src/vendor/bridges/layerzero/IOFT.sol`
- `stargatePool` field serves double duty (pool OR OFT address)
- msg.value: OFT mode = `lzNativeFee` only (critical for StargateSendHook)

## UP OFT Addresses
- Ethereum (1): UpOFTAdapter 0x722ff7C0665F4b1823c9C4cFcDF73A43de5865BD
- Base (8453): UpOFT 0x5b2193fDc451C1f847bE09CA9d13A4Bf60f8c86B
- HyperEVM (999): UpOFT 0x642fFC3496AcA19106BAB7A42F1F221a329654fe
- Flare (14): UpOFT 0xe030A89fd2b7f858c8aA47725679CA25D467dFD1

## Files to Modify
1. NEW: `src/vendor/bridges/layerzero/IOFT.sol`
2. MODIFY: `src/hooks/bridges/stargate/StargateSendHook.sol`
3. MODIFY: `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`
4. MODIFY: `test/unit/hooks/bridges/StargateHooks.t.sol`
5. MODIFY: `test/integration/stargate/StargateHooksFork.t.sol` (add OFT tests to existing file)

## Implementation Plan
See: `.claude/doc/OFTSendHook/implementation-plan.md`

### Summary of Changes

#### File 1: `src/vendor/bridges/layerzero/IOFT.sol` (NEW)
- New IOFT interface with `send()`, `token()`, `SendParam`, `MessagingFee`, `MessagingReceipt`, `OFTReceipt`
- Structs have identical field layout to IStargate counterparts
- `send()` selector: `0xc7c7f5b3` (different from `sendToken()`: `0xcbef2aa9`)
- `token()` selector: `0xfc0c546a` (same as IStargate)

#### File 2: `src/hooks/bridges/stargate/StargateSendHook.sol` (MODIFY)
- Import IOFT
- Struct: `bool isBusMode` -> `uint8 mode`
- New error: `MODE_NOT_VALID()`
- Decoding: `_decodeBool(data, 225)` -> `uint8(data[225])` + validation `if (s.mode > 2)`
- NatSpec: `bool isBusMode` -> `uint8 mode`
- Execution building: full replacement of lines 159-209 with mode-branched logic
  - mode <= 1: Stargate path (unchanged behavior)
  - mode == 2: OFT path with `IOFT.send()` and `value = lzNativeFee` ONLY
- Both lzTokenFee > 0 and lzTokenFee == 0 paths handled for both modes

#### File 3: `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol` (MODIFY)
- Same import, struct, error, decoding changes as StargateSendHook
- `_buildExecutions` refactored: pre-compute `sendCallData` bytes before lzTokenFee branching
  - mode <= 1: `sendCallData = abi.encodeCall(IStargate.sendToken, ...)`
  - mode == 2: `sendCallData = abi.encodeCall(IOFT.send, ...)`
  - Same 3-branch lzTokenFee logic uses `sendCallData` uniformly
- msg.value stays `lzNativeFee` for ALL modes (no change needed -- ERC20 hook)
- Pool validation unchanged: `IStargate(s.stargatePool).token()` works for OFT too (same selector)

#### File 4: `test/unit/hooks/bridges/StargateHooks.t.sol` (MODIFY)
- Import IOFT
- Helper signature: `_encodeStargateData(bool, bool, bool)` -> `_encodeStargateData(bool, uint8, bool)`
- ALL 27+ existing callers updated: `false` -> `0`, `true` -> `1`
- 20 new test functions for OFT mode covering:
  - Basic OFT send for both hooks
  - msg.value verification (lzNativeFee only vs lzNativeFee + amountLD)
  - ComposeMsg with OFT mode
  - PrevHookAmount with OFT mode
  - LzTokenFee with OFT mode (both same-token and different-token paths)
  - Token validation in OFT mode
  - Mode validation (mode=3 and mode=255 revert)
  - Selector verification (IOFT.send vs IStargate.sendToken)
  - OftCmd always empty in OFT mode
  - Backward compatibility (mode=0 matches old taxi, mode=1 matches old bus)

#### File 5: `test/integration/stargate/StargateHooksFork.t.sol` (MODIFY)
- 3 new fork tests using real UP OFTAdapter on Ethereum mainnet:
  - `test_Fork_OFTAdapter_TokenInterface()` - verify interface compatibility
  - `test_Fork_ApproveAndStargateSend_OFTMode_Build()` - build against real contract
  - `test_Fork_ApproveAndStargateSend_OFTMode_RevertIf_WrongToken()` - token validation

### Critical Notes for Implementer

1. **MOST CRITICAL**: StargateSendHook OFT mode `value` must be `lzNativeFee` ONLY, never `lzNativeFee + amountLD`. OFT contracts burn tokens from `msg.sender` internally -- sending extra ETH = permanent loss.

2. **Existing tests**: All 27+ callers of `_encodeStargateData` must be updated from `bool` to `uint8`. Missing even one will cause compilation failure.

3. **Inline encodings**: Tests that manually encode data with `abi.encodePacked(..., false, false, ...)` do NOT need changes because `false` encodes to `0x00` = `uint8(0)` = taxi mode. But replacing with `uint8(0)` is cleaner.

4. **token() selector compatibility**: Both IStargate.token() and IOFT.token() have selector `0xfc0c546a`. The existing validation `IStargate(s.stargatePool).token()` works for OFT contracts without any casting changes.

5. **No deployment script changes needed**: The hooks have the same constructor signature (just `validator_`), so existing deployment infrastructure works unchanged. New bytecode will produce new CREATE2 addresses.

## Execution Order
1. Create IOFT interface
2. Modify StargateSendHook
3. Modify ApproveAndStargateSendHook
4. Modify unit tests
5. Modify integration tests
6. `forge build`
7. `make forge-test TEST=StargateHooks`
8. `make forge-test TEST=StargateHooksFork` (requires ETHEREUM_RPC_URL)

## Progress Log
- Session started, launching superform-hook-master for planning
- Implementation plan completed at `.claude/doc/OFTSendHook/implementation-plan.md`
- Task 1: Created `src/vendor/bridges/layerzero/IOFT.sol` ✅
- Task 2: Modified `StargateSendHook.sol` with OFT mode support ✅
- Task 3: Modified `ApproveAndStargateSendHook.sol` with OFT mode support ✅
- Task 4: Updated unit tests - helper signature, 27+ callers, 20 new OFT tests ✅
- Task 5: Updated fork integration tests - helper signature, callers, 4 new OFT fork tests ✅
- Task 6: `forge build` succeeds, `forge test --match-path StargateHooks.t.sol` → 83/83 tests pass ✅
- Fork tests require ETHEREUM_RPC_URL to run (not run in this session)
- Task 7: Comprehensive fork integration tests with real UP and WBTC OFTAdapter contracts (36 fork tests) ✅
- Task 8: Security analysis (`/superform:security`) on both hooks ✅
  - Report at: `specs/security-reports/2026-05-26-stargate-hooks.md`
  - 0 P0, 1 P1, 6 P2, 7 P3 findings
- Task 9: Applied security fixes ✅
  - P1 [#1]: Added `_account != account` validation in composeMsg decoding (both hooks)
  - P2 [#3]: Added `to != bytes32(uint256(uint160(account)))` validation (both hooks)
  - P2 [#4]: Added `minAmountLD == 0` check after proportional scaling (both hooks)
  - Updated `mockTo` in unit tests to derive from `mockAccount`
  - Added 6 new security validation tests
  - 89/89 unit tests pass ✅
- Task 10: Fixed deployment scripts to preserve Nexus addresses ✅
  - Root cause: `DeployV2Core.s.sol`'s `_writeExportedContracts` merge logic fails to preserve entries from the existing JSON that aren't managed by DeployV2Core (e.g., Nexus contracts)
  - Fix: Added `preserve_existing_json_entries()` function to both deployment scripts
  - Backs up existing JSON before forge runs, merges back any dropped entries after
  - Modified: `script/run/deploy_v2_staging_prod.sh`
  - Modified: `script/run/deploy_v2_other_hooks_staging_prod.sh`
