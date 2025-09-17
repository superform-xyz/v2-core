# Session Context - Adding ApproveAndAcrossSendFundsAndExecuteOnDstHook to Deployment

## Task Overview
Add the new `ApproveAndAcrossSendFundsAndExecuteOnDstHook` to the Superform v2 Core deployment system using the exact same pattern as the existing `AcrossSendFundsAndExecuteOnDstHook`.

## Requirements
1. Add to DeployV2Core hook deployment script
2. Configure properly in ConfigCore 
3. Add to regenerate_bytecode.sh for bytecode regeneration
4. Follow exact same patterns as AcrossSendFundsAndExecuteOnDstHook

## Implementation Plan
Based on comprehensive analysis by superform-hook-master agent:

### Key Changes Required:
1. **Constants & Structure Updates**
   - Add hook key constant to script/utils/Constants.sol
   - Add field to HookAddresses struct in DeployV2Core.s.sol

2. **Deployment Logic Updates**
   - Place new hook at index 19, shift existing hooks 19+ up by 1
   - Update array length from 34 to 35
   - Update availability calculations to count 2 Across hooks
   - Add contract check and deployment logic
   - Update address mappings

3. **Bytecode Generation**
   - Add to regenerate_bytecode.sh

## Implementation Summary - COMPLETED ✅

Successfully added `ApproveAndAcrossSendFundsAndExecuteOnDstHook` to the Superform v2 Core deployment system using identical patterns to `AcrossSendFundsAndExecuteOnDstHook`.

### Changes Made:

1. **Constants & Structure Updates** ✅
   - Added `APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY` constant to script/utils/Constants.sol:115
   - Added `approveAndAcrossSendFundsAndExecuteOnDstHook` field to HookAddresses struct in DeployV2Core.s.sol:50

2. **Deployment Logic Updates** ✅
   - Updated availability calculations to count 2 Across hooks instead of 1 (DeployV2Core.s.sol:160)
   - Updated hook list comments to include the new hook (DeployV2Core.s.sol:253)
   - Added contract check logic for new hook (DeployV2Core.s.sol:711-724)
   - Updated hook array length from 34 to 35 (DeployV2Core.s.sol:1531)
   - Updated baseHooks array declaration from 34 to 35 (DeployV2Core.s.sol:245)

3. **Hook Array Management** ✅
   - Added deployment logic for new hook at index 19 (DeployV2Core.s.sol:1628-1634)
   - Shifted all existing hooks from indices 19+ up by 1:
     - DeBridge hooks: 19→20, 20→21
     - All subsequent hooks: 21→22, 22→23, etc. up to 33→34
   - Updated all corresponding address mappings to match new indices

4. **Address Mappings** ✅
   - Added address mapping for new hook at index 19 (DeployV2Core.s.sol:1782-1783)
   - Updated all shifted hook address mappings to use correct indices

5. **Bytecode Generation** ✅
   - Added "ApproveAndAcrossSendFundsAndExecuteOnDstHook" to regenerate_bytecode.sh:121

### Validation ✅
- All changes compile successfully with `forge build`
- Hook uses identical constructor parameters: `(spokePoolV3_, validator_)`
- Same availability dependencies: requires `acrossSpokePoolV3s[chainId]` and `superValidator`
- Same conditional deployment logic based on chain-specific Across configuration

### Deployment Notes:
- New hook is deployed at index 19, immediately after the original AcrossSendFundsAndExecuteOnDstHook (index 18)
- All hooks from original index 19 onward have been systematically shifted up by 1
- Both hooks share the same availability check and constructor parameters
- Both hooks are skipped together if Across is not available on a chain

The implementation follows the exact same patterns as the existing AcrossSendFundsAndExecuteOnDstHook, ensuring consistency with the current architecture and deployment system.