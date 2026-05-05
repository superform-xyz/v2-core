# Session 3: KyberSwap Hook Implementation

## Overview
Implementing KyberSwap MetaAggregationRouterV2 swap hooks for Superform v2-core.

## Spec Location
- `/specs/kyberswap-hook/` - Full spec with interview notes, research, and technical details

## Implementation Plan
- **Full plan**: `.claude/doc/KyberSwapHook/implementation-plan.md`

## Key Decisions
- **Pattern**: 1inch raw calldata approach (not Odos manual struct construction)
- **Router**: `0x6131B5fae19EA4f9D964eAc0408E4408b66337b5` (same all chains)
- **Variants**: SwapKyberSwapHook + ApproveAndSwapKyberSwapHook
- **Critical feature**: `_updateTxDataAmounts()` to decode/re-encode calldata for usePrevHookAmount (improvement over 0x)
- **Native ETH**: Supported via value forwarding
- **Approval target**: Must extract `approveTarget` from decoded txData (KyberSwap separates callTarget and approveTarget)
- **Inspector**: Returns packed addresses (callTarget, approveTarget, srcToken, dstToken) - addresses only per protocol requirement

## Files to Create
1. `src/vendor/kyberswap/IMetaAggregationRouterV2.sol`
2. `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol`
3. `src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol`
4. `test/mocks/MockKyberSwapRouter.sol`
5. `test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol`
6. `test/unit/hooks/swappers/kyberswap/KyberSwapUpdateTxData.t.sol`

## Files to Modify (Deployment)
7. `script/utils/Constants.sol` - Add SWAP_KYBERSWAP_HOOK_KEY + APPROVE_AND_SWAP_KYBERSWAP_HOOK_KEY
8. `script/utils/ConfigBase.sol` - Add kyberSwapRouters mapping to EnvironmentData
9. `script/utils/ConfigCore.sol` - Add router addresses for all 14 chains
10. `script/DeployV2Core.s.sol` - Full deployment integration (struct fields, availability, deploy, assign, validate)
11. `script/run/regenerate_bytecode.sh` - Add both hook names

## Status
- [x] Spec created
- [x] Hook-master planning complete
- [x] Struct field ordering VERIFIED: `clientData` comes BEFORE `desc` (selector `0xe21fd0e9`)
- [x] Implement vendor interface (`src/vendor/kyberswap/IMetaAggregationRouterV2.sol`)
- [x] Implement SwapKyberSwapHook (`src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol`)
- [x] Implement ApproveAndSwapKyberSwapHook (`src/hooks/swappers/kyberswap/ApproveAndSwapKyberSwapHook.sol`)
- [x] Implement MockKyberSwapRouter (`test/mocks/MockKyberSwapRouter.sol`)
- [x] Implement unit tests (`test/unit/hooks/swappers/kyberswap/KyberSwapUnitTests.t.sol`) - 24 tests passing
- [x] Implement _updateTxDataAmounts tests (`test/unit/hooks/swappers/kyberswap/KyberSwapUpdateTxData.t.sol`) - 6 tests passing (including fuzz)
- [x] Build & test - ALL 30 TESTS PASSING
- [x] Fork-based integration tests (`test/integration/kyberswap/KyberSwapHookIntegration.t.sol`) - 14 tests passing
- [x] KyberSwapAPIParser (`test/utils/parsers/KyberSwapAPIParser.sol`) - API helper for real routing
- [x] E2E swap tests with real KyberSwap API (`test/integration/kyberswap/KyberSwapE2ESwap.t.sol`) - 2 tests passing
- [x] ALL 95 TESTS PASSING (27 unit + 7 updateTxData + 4 ScaleHelper unit + 16 library unit + 37 integration + 4 E2E)
- [x] ScaleHelper integration for multihop amount scaling safety
- [ ] Deployment script changes (deferred - documented in plan)

## Critical Notes for Implementation

### BLOCKING: Verify Struct Field Ordering
Before ANY implementation, run:
```bash
cast interface 0x6131B5fae19EA4f9D964eAc0408E4408b66337b5 --etherscan-api-key $ETHERSCAN_API_KEY
```
The spec flags that `clientData` might come BEFORE `desc` in `SwapExecutionParams`. If the ordering differs from what's in the spec, ALL decode/encode logic changes.

### _updateTxDataAmounts Design
- Fully decodes `SwapExecutionParams` from txData (after 4-byte selector)
- Updates `desc.amount = newAmount`
- Updates `desc.minReturnAmount` using `HookDataUpdater.getUpdatedOutputAmount(newAmount, originalAmount, desc.minReturnAmount)`
- Re-encodes with `abi.encodePacked(selector, abi.encode(params))`
- Gas-intensive but only runs in `view` function (off-chain simulation)
- Uses `BytesLib.slice` to extract bytes after selector

### ApproveAndSwapKyberSwapHook Approval Target
- KyberSwap separates `callTarget` and `approveTarget` in `SwapExecutionParams`
- Must decode txData to extract `approveTarget`
- Approvals go to `approveTarget`; swap call goes to `KYBER_ROUTER`
- If `approveTarget == address(0)`, fall back to `address(KYBER_ROUTER)`

### Data Layouts
**SwapKyberSwapHook**: outputToken(20) + value(32) + inputAmount(32) + outputMin(32) + usePrevHookAmount(1) + txDataLength(32) + txData_(var)
- USE_PREV_HOOK_AMOUNT_POSITION = 116
- outputToken at offset 0 for _getBalance

**ApproveAndSwapKyberSwapHook**: inputToken(20) + outputToken(20) + inputAmount(32) + outputMin(32) + usePrevHookAmount(1) + txDataLength(32) + txData_(var)
- USE_PREV_HOOK_AMOUNT_POSITION = 104
- outputToken at offset 20 for _getBalance

### Deployment Integration Summary
- Hook array length: 52 -> 54
- New indices: 52 (SwapKyberSwapHook), 53 (ApproveAndSwapKyberSwapHook)
- Availability flag: `swapKyberSwapHooks`
- Config mapping: `kyberSwapRouters`
- potentialSkips array size: 28 -> 30
- baseHooks array size: 52 -> 54

## Progress Log
- **2026-03-10**: Hook-master completed implementation plan. Full plan at `.claude/doc/KyberSwapHook/implementation-plan.md`
- **2026-03-10**: Struct field ordering verified via function selector analysis (`cast sig`). Confirmed `clientData` before `desc`.
- **2026-03-10**: Created vendor interface, both hook implementations, mock router, and all unit tests.
- **2026-03-10**: All 30 tests passing (24 unit + 6 updateTxData including fuzz test).
- **2026-03-10**: Created fork-based integration tests (14 tests) against real Ethereum mainnet state.
- **2026-03-10**: Created KyberSwapAPIParser for calling KyberSwap Aggregator API from Solidity tests via Surl.
- **2026-03-10**: Created E2E swap tests executing actual swaps through real KyberSwap router with real API routing data.
  - `test_E2E_ApproveAndSwap_USDC_to_WETH`: 1000 USDC → ~0.49 WETH via ApproveAndSwapKyberSwapHook
  - `test_E2E_SwapHook_WETH_to_USDC`: 0.5 WETH → ~1015 USDC via SwapKyberSwapHook (pre-approved)
- **2026-03-10**: ALL 46 TESTS PASSING.
- **2026-03-10**: Added DAM (Reservoir) → USDC E2E test. DAM token at `0x0FedbA9178b70e8b54e2Af08eBffcf28A1e5A43B` (18 decimals). 1000 DAM → ~35.79 USDC via ApproveAndSwapKyberSwapHook. All 3 E2E tests passing (47 total).
- **2026-03-11**: Added ScaleHelper integration for `usePrevHookAmount` multihop safety.
  - Primary: KyberSwap ScaleHelper (`0x2f577A41BeC1BE1152AeEA12e73b7391d15f655D`) properly scales `targetData` internals
  - Fallback: Proportional scaling of `desc.amount`, `srcAmounts`, `feeAmounts`, `minReturnAmount`
  - New interface: `src/vendor/kyberswap/IScaleHelper.sol`
  - Constructor now takes `(router_, scaleHelper_)` — pass `address(0)` for fallback-only mode
  - New test: `test_SwapHook_UpdateTxData_ScalesSrcAmountsMultiReceiver` validates split route scaling
  - Learnings documented at `specs/knowledge/aggregator-amount-scaling.md`
- **2026-03-11**: Added ScaleHelper unit tests (4 tests) with mock ScaleHelpers (success, fail, revert).
- **2026-03-11**: Added E2E ScaleHelper test `test_E2E_ScaleHelper_UsePrevHookAmount_USDC_to_WETH`:
  - Quotes API for 1000 USDC, simulates prevHook returning 1030 USDC (+3%)
  - Real ScaleHelper scales calldata, verifies approval amount = actual amount
  - Swap succeeds: 1030 USDC → ~0.5098 WETH (~3% more than quoted)
- **2026-03-11**: Added 19 new fork-based integration tests (33 total) covering ScaleHelper, usePrevHookAmount, native ETH, split routes, fee amounts, large amounts.
- **2026-03-11**: Fixed E2E test flakiness — root cause: KyberSwap API routes through `ekubo-v3` and `axima-v2` DEXes which use Uniswap V4 PoolManager (`0x00000000000014aA86C5d3c41765bb24e11bd701`), incompatible with Foundry's fork (`EvmError: NotActivated`).
  - Added `excludedSources` parameter to `KyberSwapAPIParser.surlCallRoutes()` (5-param overload)
  - E2E tests exclude `ekubo-v3,axima-v2` from routing
  - Added retry mechanism with `vm.snapshotState()`/`vm.revertToState()` as safety net
  - Replaced DAM token (no routes without incompatible DEXes) with LINK (`0x514910771AF9Ca656af840dff83E8264EcF986CA`)
  - ALL 72 TESTS PASSING (35 unit + 33 integration + 4 E2E) — E2E tests pass consistently on first attempt
- **2026-03-13**: Security review completed (`/superform:security`). Report at `specs/security-reports/2026-03-13-kyberswap-hooks.md`.
  - P1-1 (zero-amount validation) and P1-2 (div-by-zero) fixed via `KyberSwapScaler` library
  - P2-1 (double decode) fixed by moving `_getApproveTarget` before scaling in ApproveAndSwapKyberSwapHook
  - P2-2 (code duplication) fixed by extracting shared scaling logic to `src/libraries/KyberSwapScaler.sol`
  - New file: `src/libraries/KyberSwapScaler.sol` — shared library with `updateTxDataAmounts` + `_proportionalScale` + zero-amount guards
  - Both hooks now import `KyberSwapScaler` instead of duplicating scaling logic
  - Removed unused `Math` and `HookDataUpdater` imports from both hooks
  - Added 3 new unit tests: `test_SwapHook_Build_RevertIf_PrevHookAmountZero`, `test_ApproveAndSwapHook_Build_RevertIf_PrevHookAmountZero`, `test_SwapHook_Build_RevertIf_OriginalAmountZero`
  - ALL 76 TESTS PASSING (38 unit + 34 integration + 4 E2E)
  - Coverage: SwapKyberSwapHook 100%, ApproveAndSwapKyberSwapHook 100%, KyberSwapScaler 94.12%
- **2026-03-13**: Added dedicated KyberSwapScaler library unit tests and integration tests
  - New file: `test/unit/libraries/KyberSwapScalerTest.t.sol` — 16 tests covering all library paths
    - Zero-amount validation (3 tests): newAmount=0, originalAmount=0, both=0
    - Proportional scaling (8 tests): double, halve, split routes, feeAmounts scaling (covers uncovered line 78), preserves fields, correct selector, fuzz
    - ScaleHelper integration (5 tests): success, fail fallback, revert fallback, no ScaleHelper, zero amount before ScaleHelper
  - Added 3 fork-based integration tests in `KyberSwapHookIntegration.t.sol`:
    - `test_SwapHook_RevertIf_PrevHookAmountZero_OnFork`
    - `test_ApproveAndSwapHook_RevertIf_PrevHookAmountZero_OnFork`
    - `test_SwapHook_RevertIf_OriginalAmountZero_OnFork`
  - ALL 95 TESTS PASSING (54 unit + 37 integration + 4 E2E)

## E2E Test Details

### KyberSwapAPIParser (`test/utils/parsers/KyberSwapAPIParser.sol`)
- `surlCallRoutes(tokenIn, tokenOut, amountIn, chain)` - GET /routes API, returns routeSummary JSON
- `surlCallRoutes(tokenIn, tokenOut, amountIn, chain, excludedSources)` - GET /routes with DEX exclusions
- `surlCallBuild(routeSummary, sender, recipient, slippageTolerance, chain)` - POST /route/build, returns hex calldata
- `extractAmountOut(routeSummaryJson)` - Parses expected output amount from routeSummary
- `_extractJsonObject(json, key)` - Brace-counting JSON object extraction (handles nested objects/arrays/strings)
- Uses `Surl` for HTTP calls, `strings` library for JSON parsing, `BaseAPIParser.fromHex()` for hex conversion

### KyberSwapE2ESwap (`test/integration/kyberswap/KyberSwapE2ESwap.t.sol`)
- Forks Ethereum mainnet, calls real KyberSwap API for routing, executes real swaps
- Tests both hook variants: ApproveAndSwapKyberSwapHook and SwapKyberSwapHook
- Verifies: balance changes, outAmount tracking, residual approvals, selector correctness
- Excludes `ekubo-v3,axima-v2` DEXes (use UniV4 PoolManager, incompatible with Foundry fork)
- Retry mechanism (`MAX_RETRIES=3`) with `vm.snapshotState()`/`vm.revertToState()` as safety net
- Token pairs: USDC↔WETH, LINK→USDC, USDC→WETH (ScaleHelper)

### Incompatible KyberSwap DEX IDs for Foundry Fork
- `ekubo-v3` — Routes through Uniswap V4 PoolManager (`0x00000000000014aA86C5d3c41765bb24e11bd701`)
- `axima-v2` — Also routes through UniV4 PoolManager internally despite "uniswapv3" pool labels
- Both cause `EvmError: NotActivated` in Foundry's fork environment
