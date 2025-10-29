# Deploy ApproveAndAcrossSendFundsAndExecuteOnDstHook Implementation Plan

## Overview
This document provides a detailed implementation plan for integrating the new `ApproveAndAcrossSendFundsAndExecuteOnDstHook` into the Superform v2 Core deployment system, following the exact same patterns as the existing `AcrossSendFundsAndExecuteOnDstHook`.

## Analysis of Existing AcrossSendFundsAndExecuteOnDstHook Pattern

### 1. **DeployV2Core.s.sol Integration**

**Key Constants:**
- Hook key constant: `ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "AcrossSendFundsAndExecuteOnDstHook"` (line 114 in script/utils/Constants.sol)
- Hook is deployed at index `18` in the hooks array
- Constructor parameters: `(configuration.acrossSpokePoolV3s[chainId], superValidator)`

**Availability Check Pattern (around line 158-161):**
```solidity
if (configuration.acrossSpokePoolV3s[chainId] != address(0)) {
    expectedHooks += 1; // AcrossSendFundsAndExecuteOnDstHook
} else {
    potentialSkips[skipCount++] = "AcrossSendFundsAndExecuteOnDstHook";
}
```

**Contract Check Pattern (around line 693-704):**
```solidity
if (availability.acrossV3Adapter && superValidator != address(0)) {
    __checkContract(
        ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
        __getSalt(ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY),
        abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator),
        env
    );
} else if (!availability.acrossV3Adapter) {
    console2.log(
        "SKIPPED AcrossSendFundsAndExecuteOnDstHook: Across Spoke Pool not configured for chain", chainId
    );
} else {
    revert("ACROSS_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
}
```

**Deployment Pattern (around line 1604-1614):**
```solidity
if (availability.acrossV3Adapter && superValidator != address(0)) {
    hooks[18] = HookDeployment(
        ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
        abi.encodePacked(
            __getBytecode("AcrossSendFundsAndExecuteOnDstHook", env),
            abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
        )
    );
} else {
    console2.log(" SKIPPED AcrossSendFundsAndExecuteOnDstHook deployment: Not available on chain", chainId);
    hooks[18] = HookDeployment("", ""); // Empty deployment
}
```

**Address Mapping Pattern (around line 1754-1755):**
```solidity
hookAddresses.acrossSendFundsAndExecuteOnDstHook =
    Strings.equal(hooks[18].name, ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[18] : address(0);
```

### 2. **HookAddresses Struct**
The struct currently has: `address acrossSendFundsAndExecuteOnDstHook;` (line 49)
**Missing**: `address approveAndAcrossSendFundsAndExecuteOnDstHook;` field

### 3. **Hook Contract Analysis**
**File**: `/Users/timepunk/work/v2-core/src/hooks/bridges/across/ApproveAndAcrossSendFundsAndExecuteOnDstHook.sol`

**Constructor signature**: `constructor(address spokePoolV3_, address validator_)`
- Same parameters as the original AcrossSendFundsAndExecuteOnDstHook
- Uses `BaseHook(HookType.NONACCOUNTING, HookSubTypes.BRIDGE)`

### 4. **Constants Analysis**
**Current status in script/utils/Constants.sol:**
- Missing: `APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY` constant
- Found in test/utils/Constants.sol (line 81): `"ApproveAndAcrossSendFundsAndExecuteOnDstHook"`

### 5. **Bytecode Generation**
**Current regenerate_bytecode.sh:**
- Contains `"AcrossSendFundsAndExecuteOnDstHook"` at line 120
- **Missing**: `"ApproveAndAcrossSendFundsAndExecuteOnDstHook"` entry

### 6. **Array Structure Analysis**
Current hook array has `uint256 len = 34` (line 1514)
- Index 18: AcrossSendFundsAndExecuteOnDstHook  
- Highest used index: 33
- **Available index for new hook**: Need to determine next available index (likely after index 18)

## Implementation Plan

### Phase 1: Constants and Structure Updates

#### 1.1 Add Missing Hook Key Constant
**File**: `/Users/timepunk/work/v2-core/script/utils/Constants.sol`
**Action**: Add after line 114:
```solidity
string internal constant APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY = "ApproveAndAcrossSendFundsAndExecuteOnDstHook";
```

#### 1.2 Update HookAddresses Struct
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Action**: Add after line 49 (after `acrossSendFundsAndExecuteOnDstHook`):
```solidity
address approveAndAcrossSendFundsAndExecuteOnDstHook;
```

### Phase 2: Availability Calculations

#### 2.1 Update Expected Hook Count
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Location**: Around line 158-162
**Action**: Modify the Across availability check:
```solidity
if (configuration.acrossSpokePoolV3s[chainId] != address(0)) {
    expectedHooks += 2; // AcrossSendFundsAndExecuteOnDstHook + ApproveAndAcrossSendFundsAndExecuteOnDstHook
} else {
    potentialSkips[skipCount++] = "AcrossSendFundsAndExecuteOnDstHook";
    potentialSkips[skipCount++] = "ApproveAndAcrossSendFundsAndExecuteOnDstHook";
}
```

#### 2.2 Update Hook List in Comments
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Location**: Around line 251
**Action**: Update the comment list to include the new hook:
```solidity
"AcrossSendFundsAndExecuteOnDstHook", "ApproveAndAcrossSendFundsAndExecuteOnDstHook", "DeBridgeSendOrderAndExecuteOnDstHook", "DeBridgeCancelOrderHook",
```

### Phase 3: Contract Checking

#### 3.1 Add Contract Check
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Location**: After line 700 (after existing AcrossSendFundsAndExecuteOnDstHook check)
**Action**: Add new check block:
```solidity
if (availability.acrossV3Adapter && superValidator != address(0)) {
    __checkContract(
        APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
        __getSalt(APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY),
        abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator),
        env
    );
} else if (!availability.acrossV3Adapter) {
    console2.log(
        "SKIPPED ApproveAndAcrossSendFundsAndExecuteOnDstHook: Across Spoke Pool not configured for chain", chainId
    );
} else {
    revert("APPROVE_AND_ACROSS_HOOK_CHECK_FAILED_MISSING_SUPER_VALIDATOR");
}
```

### Phase 4: Hook Deployment

#### 4.1 Determine Hook Index
**Analysis needed**: Review all hook indices to find the next available slot after index 18.
**Recommendation**: Use index 19 and shift DeBridge hooks to indices 20-21.

#### 4.2 Add Hook Deployment
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Location**: After line 1614 (after existing AcrossSendFundsAndExecuteOnDstHook deployment)
**Action**: Add new deployment block at chosen index:
```solidity
if (availability.acrossV3Adapter && superValidator != address(0)) {
    hooks[19] = HookDeployment(
        APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY,
        abi.encodePacked(
            __getBytecode("ApproveAndAcrossSendFundsAndExecuteOnDstHook", env),
            abi.encode(configuration.acrossSpokePoolV3s[chainId], superValidator)
        )
    );
} else {
    console2.log(" SKIPPED ApproveAndAcrossSendFundsAndExecuteOnDstHook deployment: Not available on chain", chainId);
    hooks[19] = HookDeployment("", ""); // Empty deployment
}
```

#### 4.3 Update Subsequent Hook Indices
**CRITICAL**: All hooks currently at index 19+ need to be shifted up by 1
- DeBridgeSendOrderAndExecuteOnDstHook: 19 → 20
- DeBridgeCancelOrderHook: 20 → 21
- All other hooks need corresponding index updates

#### 4.4 Update Array Length
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Location**: Line 1514
**Action**: Change from `uint256 len = 34;` to `uint256 len = 35;`

### Phase 5: Address Mapping

#### 5.1 Add Address Mapping
**File**: `/Users/timepunk/work/v2-core/script/DeployV2Core.s.sol`
**Location**: After line 1755 (after existing acrossSendFundsAndExecuteOnDstHook mapping)
**Action**: Add new mapping:
```solidity
hookAddresses.approveAndAcrossSendFundsAndExecuteOnDstHook =
    Strings.equal(hooks[19].name, APPROVE_AND_ACROSS_SEND_FUNDS_AND_EXECUTE_ON_DST_HOOK_KEY) ? addresses[19] : address(0);
```

#### 5.2 Update Subsequent Address Mappings
**CRITICAL**: All address mappings for hooks at index 19+ need index updates to match new positions

### Phase 6: Bytecode Generation

#### 6.1 Add to Regeneration Script
**File**: `/Users/timepunk/work/v2-core/script/run/regenerate_bytecode.sh`
**Location**: After line 120 (after "AcrossSendFundsAndExecuteOnDstHook")
**Action**: Add new entry:
```bash
"ApproveAndAcrossSendFundsAndExecuteOnDstHook"
```

## Risk Analysis & Considerations

### High Risk Areas
1. **Index Conflicts**: Shifting all hooks after index 18 requires careful coordination
2. **Array Bounds**: Increasing array length and ensuring all references are updated
3. **Address Mapping Consistency**: All mappings must use correct indices
4. **Bytecode Dependencies**: New hook must have bytecode generated before deployment

### Validation Requirements
1. **Test Compilation**: Ensure all changes compile without errors
2. **Index Verification**: Verify all hook indices are sequential and correct
3. **Address Mapping Verification**: Ensure all address mappings use correct indices
4. **Bytecode Availability**: Confirm bytecode exists for the new hook

### Deployment Considerations
1. **Multi-Chain Compatibility**: Same availability logic applies to all chains
2. **Backwards Compatibility**: Existing deployments should not be affected
3. **Configuration Dependencies**: Requires same Across configuration as original hook

## Files to Modify

1. **script/utils/Constants.sol** - Add hook key constant
2. **script/DeployV2Core.s.sol** - Main deployment logic changes
3. **script/run/regenerate_bytecode.sh** - Add to bytecode generation

## Testing Strategy

1. **Unit Tests**: Verify deployment logic for both available and unavailable scenarios
2. **Integration Tests**: Test complete deployment flow with new hook
3. **Multi-Chain Tests**: Verify behavior across different chain configurations
4. **Bytecode Tests**: Ensure bytecode generation includes new hook

## Implementation Sequence

1. Add constants and struct updates (low risk)
2. Update availability calculations (medium risk)
3. Add contract checking (medium risk)
4. Update hook deployment and indices (high risk - requires careful coordination)
5. Update address mappings (high risk - must match new indices)
6. Add bytecode generation (low risk)
7. Test and validate (critical)

## Notes

- The `ApproveAndAcrossSendFundsAndExecuteOnDstHook` follows the same architectural patterns as the original
- Constructor parameters are identical: `(spokePoolV3_, validator_)`
- Same availability dependencies: requires `acrossSpokePoolV3s[chainId]` and `superValidator`
- Same conditional deployment logic based on chain-specific Across configuration
- The hook provides ERC20-specific functionality with approve pattern, complementing the native token version