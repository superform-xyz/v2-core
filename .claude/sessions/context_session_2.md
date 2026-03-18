# Session 2: Spark PSM Hook Implementation

## Overview
Implementing 4 Solidity hooks for Sky.money Spark PSM integration (USDC/USDS/sUSDS swaps).

## Spec
See: `specs/spark-psm-hook/technical-spec.md`

## Implementation Plan
1. IPSM3 vendor interface
2. MockPSM3 test mock
3. SwapSparkPSMExactInHook
4. ApproveAndSwapSparkPSMExactInHook
5. SwapSparkPSMExactOutHook
6. ApproveAndSwapSparkPSMExactOutHook
7. SparkPSMExactInUnitTests
8. SparkPSMExactOutUnitTests

## Pattern Reference
- SwapUniswapV3Hook / ApproveAndSwapUniswapV3Hook
- Hook data: 157 bytes (vs 193 for UniV3)
- USE_PREV_HOOK_AMOUNT_POSITION = 156

## Progress
- [x] Phase 1: Foundation (IPSM3, MockPSM3)
- [x] Phase 2: ExactIn hooks + tests
- [x] Phase 3: ExactOut hooks + tests

## Files Created
```
src/vendor/spark/IPSM3.sol                                          (vendor interface)
src/hooks/swappers/spark-psm/SwapSparkPSMExactInHook.sol            (ExactIn, pre-approved)
src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactInHook.sol  (ExactIn, approve+revoke)
src/hooks/swappers/spark-psm/SwapSparkPSMExactOutHook.sol           (ExactOut, pre-approved)
src/hooks/swappers/spark-psm/ApproveAndSwapSparkPSMExactOutHook.sol (ExactOut, approve+revoke)
test/mocks/MockPSM3.sol                                              (test mock)
test/unit/hooks/swappers/spark-psm/SparkPSMExactInUnitTests.t.sol   (38 tests)
test/unit/hooks/swappers/spark-psm/SparkPSMExactOutUnitTests.t.sol  (39 tests)
```

## Test Results

### Unit Tests (mocks)
- 77 tests passed, 0 failed, 0 skipped
- All ExactIn tests: 38 pass
- All ExactOut tests: 39 pass (includes critical maxAmountIn approval tests)

### Integration Tests (Base fork, real PSM)
- 14 tests passed, 0 failed, 0 skipped
- All 4 hooks tested against real PSM3 at 0x1601843c5E9bC251A3272907010AFa41Fa18347E
- Token pairs verified: USDC↔USDS (1:1), USDC↔sUSDS (oracle), USDS↔sUSDS (oracle)
- Large amounts (1M USDC), small amounts (1 USDC), ExactIn/ExactOut all pass
- Zero residual approvals confirmed
- outAmount tracking verified against actual balance deltas

## Key Implementation Details

### Hook Data Layout (157 bytes)
```
Offset  Size  Type      Field
0       20    address   assetIn
20      20    address   assetOut
40      32    uint256   amount          (amountIn for ExactIn, amountOut for ExactOut)
72      32    uint256   slippageParam   (minAmountOut for ExactIn, maxAmountIn for ExactOut)
104     20    address   receiver        (IGNORED — forced to account)
124     32    uint256   referralCode
156     1     bool      usePrevHookAmount
```

### Critical Design Decisions
1. **Receiver = account**: Always hardcoded in PSM call, ignores hook data receiver field
2. **ExactOut approves maxAmountIn**: `ApproveAndSwapSparkPSMExactOutHook` approves `maxAmountIn` (NOT `amountOut`)
3. **ExactOut chained approval**: When `usePrevHookAmount=true`, scaled `maxAmountIn` used for approval
4. **Approve pattern**: `approve(0) → approve(exact) → swap → approve(0)` for all ApproveAnd* hooks

### Remaining (Phase 4: Deployment - not in scope for this session)
- [ ] PSM address constants per chain
- [ ] Hook key constants in Constants.sol
- [ ] Conditional deployment logic
