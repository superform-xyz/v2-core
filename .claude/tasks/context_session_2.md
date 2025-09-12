# Session Context 2 - ApproveAndAcrossSendFundsAndExecuteOnDstHook Implementation

## Goal
Create a new hook `ApproveAndAcrossSendFundsAndExecuteOnDstHook` that combines the approval pattern from `ApproveAndSwapOdosV2Hook` with the bridge functionality from `AcrossSendFundsAndExecuteOnDstHook`.

## Completed Plan Analysis
- Analyzed existing AcrossSendFundsAndExecuteOnDstHook.sol
- Analyzed existing ApproveAndSwapOdosV2Hook.sol
- Created comprehensive implementation plan using hooks-agent
- Identified key patterns: 4-execution pattern (approve 0 → approve amount → execute → approve 0)

## Implementation Plan (Approved)
The plan includes:
1. New contract in `/src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol`
2. Transform from 1 execution to 4 executions for ERC20 tokens
3. Handle native tokens with 1 execution (skip approvals)
4. Maintain exact same data structure as original hook
5. Comprehensive testing strategy
6. Proper integration with existing codebase

## Implementation Completed
- ✅ Created ApproveAndAcrossSendFundsAndExecuteOnDstHook contract
- ✅ Implemented 4-execution pattern (approve 0 → approve amount → execute → approve 0)  
- ✅ Added native token handling logic
- ✅ Implemented interface methods (decodeUsePrevHookAmount, inspect)
- ✅ Created comprehensive test suite (14 tests)
- ✅ Added contract to constants and deployment files
- ✅ Updated deployment script with proper indexing

## Issues Resolved
- ✅ Removed native token handling entirely (not needed - users should use original AcrossSendFundsAndExecuteOnDstHook for natives)
- ✅ Simplified to ERC20-only with clean approve pattern
- ✅ Fixed all test failures
- ✅ All 12 tests now passing

## Final Implementation Summary
- **ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol**: ERC20-only bridge hook with approve pattern
- **Execution Pattern**: 4 hook executions (approve 0 → approve amount → bridge → approve 0) + preExecute + postExecute = 6 total
- **Use Case**: For ERC20 tokens that need approval before bridging via Across
- **Native Tokens**: Use original AcrossSendFundsAndExecuteOnDstHook instead
- **Testing**: 12 comprehensive tests covering all scenarios
- **Integration**: Added to constants, deployment scripts, and contract verification

## Key Learnings
1. BaseHook automatically wraps hook executions with preExecute/postExecute
2. Tests need to account for the full execution count (hook + 2)
3. Native token handling should be kept in the original hook for simplicity
4. Using make commands instead of direct forge is important for consistency