# Session 10: Odos V3 Hook Implementation

## Status: All Implementation + Security Fixes Complete -- All 95 Tests Passing

## Overview
Implementing two new swap hooks (`SwapOdosV3Hook` and `ApproveAndSwapOdosV3Hook`) for the Odos V3 DEX aggregator router at `0x0D05a7D3448512B78fa8A9e46c4872C88C4a0D05`.

## Implementation Plan
See: `.claude/doc/OdosV3Hook/implementation-plan.md` for the full detailed plan.

## Spec
See: `specs/odos-v3-hook/technical-spec.md`

## Key Changes from V2 to V3
- V2 `uint32 referralCode` -> V3 `swapReferralInfo { uint64 code, uint64 fee, address feeRecipient }`
- Data layout tail grows from 24 bytes (V2) to 56 bytes (V3)
- Fee validation: `referralFee <= FEE_DENOM / 50` (2% cap)
- `feeRecipient != address(0)` when `fee > 0`
- `inspect()` returns `abi.encodePacked(executor, feeRecipient)` (40 bytes vs V2's 20 bytes)
- `ApproveAndSwapOdosV3Hook` adds native ETH support (skip approvals when inputToken=address(0))

## V3 Data Layout (VALIDATED)
```
Offset 0:            address inputToken            (20 bytes)
Offset 20:           uint256 inputAmount           (32 bytes)
Offset 52:           address inputReceiver         (20 bytes)
Offset 72:           address outputToken           (20 bytes)
Offset 92:           uint256 outputQuote           (32 bytes)
Offset 124:          uint256 outputMin             (32 bytes)
Offset 156:          bool usePrevHookAmount        (1 byte)
Offset 157:          uint256 pathDefinitionLength  (32 bytes)
Offset 189:          bytes pathDefinition          (variable)
Offset 189+len:      address executor              (20 bytes)
Offset 189+len+20:   uint64 referralCode           (8 bytes)
Offset 189+len+28:   uint64 referralFee            (8 bytes)
Offset 189+len+36:   address feeRecipient          (20 bytes)
```

## Research Findings Summary

### BytesLib.toUint64 -- CONFIRMED AVAILABLE
At `src/vendor/BytesLib.sol` lines 319-328. No issues, follows same pattern as toUint32/toAddress.

### Native ETH Conditional Pattern -- CONFIRMED
Reference: `ApproveAndSwapUniswapV2Hook.sol` lines 112-159. Pattern:
- If `inputToken == address(0)`: create 1 execution (swap with value), skip all approvals
- Else: create 4 executions (approve(0), approve(N), swap, approve(0))

### V2 Test Phantom Padding -- WARNING
The V2 `_buildApproveAndSwapOdosData` helper includes a spurious `bytes20(address(0))` between the bool and pathDefinitionLength. This is incorrect for the actual hook data layout (hook reads pathDefinitionLength at offset 157, but the padding puts it at 177). V3 test helpers MUST NOT replicate this -- follow `_buildSwapOdosData` pattern instead.

### Deployment: OtherHooks, NOT Core
V3 hooks go in `DeployV2OtherHooks.s.sol` (not DeployV2Core), following the Algebra Integral pattern. Bytecode goes to `generated-bytecode-other/`.

### inspect() is pure
inspect() only decodes calldata with BytesLib -- no immutable/storage access needed. Use `pure` visibility.

### FEE_DENOM is uint64
`uint64` max is ~1.8e19, and `1e18` fits. `MAX_REFERRAL_FEE = 1e18 / 50 = 2e16` also fits.

### Execution Counts (after BaseHook wrapping)
- SwapOdosV3Hook: always 3 (pre + 1 swap + post)
- ApproveAndSwapOdosV3Hook ERC-20: 6 (pre + 4 inner + post)
- ApproveAndSwapOdosV3Hook native: 3 (pre + 1 swap + post)

## Tasks
1. [ ] Create `src/vendor/odos/IOdosRouterV3.sol`
2. [ ] Create `src/hooks/swappers/odos/SwapOdosV3Hook.sol`
3. [ ] Create `src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol`
4. [ ] Create `test/mocks/MockOdosRouterV3.sol`
5. [ ] Create `test/unit/hooks/swappers/odos/OdosV3UnitTests.t.sol`
6. [ ] Modify `script/utils/ConstantsOtherHooks.sol` (add hook keys + router address)
7. [ ] Modify `script/utils/ConfigOtherHooks.sol` (add V3 router mapping)
8. [ ] Modify `script/DeployV2OtherHooks.s.sol` (add V3 deployment function)
9. [ ] Modify `script/run/regenerate_bytecode.sh` (add V3 to bytecode arrays)
10. [ ] Run `forge build` and tests

NOTE: Task 6 from original plan (`test/utils/InternalHelpers.sol`) is dropped -- the test data helper should live in the test file itself, following the V2 pattern (inline `_buildSwapOdosV3Data` in OdosV3UnitTests.t.sol).

## Security Review (2026-05-21)

### Report
See: `specs/security-reports/2026-05-21-odos-v3-hooks.md`

### Verdict: PASS (all findings resolved)

### Fixes Applied
1. **P1-1 (Critical Fix)**: `outputQuote` scaling in `_getSwapInfo` when `usePrevHookAmount=true`
   - Added `outputQuote = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputQuote)`
   - Fork integration test: `test_fork_ChainedSwap_USDC_to_WETH_to_DAI_usePrevHookAmount`

2. **P2-2**: `inputReceiver` added to `inspect()` return (60 bytes: inputReceiver + executor + feeRecipient)
3. **P2-3**: Executor trust assumption documented in contract NatSpec
4. **P2-4**: `SAME_INPUT_OUTPUT_TOKEN()` error + validation prevents underflow in `_postExecute`
5. **P2-5**: All byte offsets extracted as named constants (INPUT_TOKEN_POSITION, etc.)
6. **P3-6**: Removed unused `PRECISION` constant
7. **P3-7**: Removed unused `Math` import
8. **P3-8**: `inspect()` updated (see P2-2)
9. **P3-9**: Full NatSpec documentation added to all elements
10. **P3-10**: `FEE_DENOM` documented as `uint64` for IOdosRouterV3 compatibility

### Test Results
- 83 unit tests (OdosV3UnitTests) -- PASS
- 4 mock integration tests (OdosV3RouterSwap) -- PASS
- 8 fork integration tests (OdosV3RouterSwapFork) -- PASS
- Total: 95/95 PASS

### Updated inspect() Return Layout
```
Offset 0:   address inputReceiver  (20 bytes)
Offset 20:  address executor       (20 bytes)
Offset 40:  address feeRecipient   (20 bytes)
Total: 60 bytes
```

## Reference Files
- `src/hooks/swappers/odos/SwapOdosV2Hook.sol` -- V2 template
- `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol` -- V2 approve template
- `src/vendor/odos/IOdosRouterV2.sol` -- V2 interface
- `src/vendor/BytesLib.sol` -- toUint64 at lines 319-328
- `src/hooks/swappers/uniswap-v2/ApproveAndSwapUniswapV2Hook.sol` -- native ETH conditional pattern
- `test/unit/hooks/swappers/odos/OdosUnitTests.t.sol` -- V2 test template
- `test/mocks/MockOdosRouterV2.sol` -- V2 mock template
- `script/DeployV2OtherHooks.s.sol` -- deployment template (follow Algebra Integral pattern)
- `script/utils/ConfigOtherHooks.sol` -- config template
- `script/utils/ConstantsOtherHooks.sol` -- constants template
