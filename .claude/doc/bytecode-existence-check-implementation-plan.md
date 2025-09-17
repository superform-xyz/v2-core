# Bytecode Existence Check System - Implementation Plan

## Executive Summary
Implement a comprehensive system that checks for bytecode artifact existence before attempting contract deployment, enhancing the existing skippedContracts mechanism to distinguish between chain-unavailable and missing-bytecode scenarios.

## Current Architecture Analysis

### Existing Components
1. **DeployV2Base.s.sol** - Base deployment functionality with:
   - Environment-based bytecode path resolution (`__getBytecodeArtifactPath`)
   - Bytecode loading via `vm.getCode()` (`__getBytecode`)
   - Contract deployment status tracking (`ContractStatus` struct)

2. **DeployV2Core.s.sol** - Main deployment logic with:
   - `ContractAvailability` struct with existing `skippedContracts` array
   - Chain-specific contract availability checks
   - Deployment summary logging

3. **deploy_v2_staging_prod.sh** - Orchestration script with:
   - Global bytecode validation via `validate_locked_bytecode()` 
   - Per-network deployment status analysis
   - Smart deployment logic (skip fully deployed networks)

### Current Skip Logic
- Existing `skippedContracts` tracks chain-specific unavailability (missing bridge/protocol support)
- Shell script validates ALL expected bytecode files exist before starting
- No granular per-contract bytecode existence checking during deployment

## Implementation Plan

### Phase 1: Enhance ContractAvailability Structure

#### 1.1 Extend ContractAvailability Struct
**File:** `script/DeployV2Core.s.sol`

Add new fields to track bytecode availability:
```solidity
struct ContractAvailability {
    // ... existing fields ...
    string[] skippedContracts;           // Chain-unavailable contracts
    string[] missingBytecodeContracts;   // Contracts with missing bytecode  
    uint256 expectedMissingBytecode;     // Count of missing bytecode contracts
}
```

**Rationale:** Separate tracking allows distinguishing between "contract not supported on this chain" vs "contract coded but bytecode missing."

#### 1.2 Add Bytecode Existence Check Function  
**File:** `script/DeployV2Base.s.sol`

```solidity
/// @notice Check if bytecode artifact exists for a contract
/// @param contractName Name of the contract
/// @param env Environment (0 = prod, 1/2 = dev/staging)
/// @return exists Whether the bytecode file exists
function __bytecodeExists(string memory contractName, uint256 env) internal view returns (bool exists) {
    string memory artifactPath = __getBytecodeArtifactPath(contractName, env);
    
    // Use vm.tryFfi or file existence check
    // Since Foundry doesn't have direct file existence check, use try/catch on vm.getCode
    try vm.getCode(artifactPath) returns (bytes memory bytecode) {
        return bytecode.length > 0;
    } catch {
        return false;
    }
}
```

**Alternative Implementation (More Robust):**
```solidity
function __bytecodeExists(string memory contractName, uint256 env) internal returns (bool exists) {
    string memory artifactPath = __getBytecodeArtifactPath(contractName, env);
    
    // Use shell command to check file existence
    string[] memory inputs = new string[](3);
    inputs[0] = "test";
    inputs[1] = "-f"; 
    inputs[2] = artifactPath;
    
    try vm.ffi(inputs) returns (bytes memory) {
        return true;
    } catch {
        return false;
    }
}
```

### Phase 2: Integrate Bytecode Checks into Availability Analysis

#### 2.1 Enhance Contract Availability Analysis
**File:** `script/DeployV2Core.s.sol`

Modify `__getChainContractAvailability()` to include bytecode checks:

```solidity
function __getChainContractAvailability(uint64 chainId, uint256 env) 
    internal returns (ContractAvailability memory availability) {
    
    // ... existing chain-specific availability logic ...
    
    // NEW: Check bytecode availability for all contracts
    string[] memory allContractNames = _getAllExpectedContractNames();
    uint256 missingBytecodeCount = 0;
    string[] memory tempMissingBytecode = new string[](allContractNames.length);
    
    for (uint256 i = 0; i < allContractNames.length; i++) {
        // Skip if already marked as chain-unavailable
        bool isChainSkipped = false;
        for (uint256 j = 0; j < availability.skippedContracts.length; j++) {
            if (keccak256(bytes(allContractNames[i])) == keccak256(bytes(availability.skippedContracts[j]))) {
                isChainSkipped = true;
                break;
            }
        }
        
        // Only check bytecode for contracts that should be available on this chain
        if (!isChainSkipped && !__bytecodeExists(allContractNames[i], env)) {
            tempMissingBytecode[missingBytecodeCount] = allContractNames[i];
            missingBytecodeCount++;
        }
    }
    
    // Create properly sized missing bytecode array
    availability.missingBytecodeContracts = new string[](missingBytecodeCount);
    for (uint256 i = 0; i < missingBytecodeCount; i++) {
        availability.missingBytecodeContracts[i] = tempMissingBytecode[i];
    }
    availability.expectedMissingBytecode = missingBytecodeCount;
    
    // Adjust expected totals to account for missing bytecode
    availability.expectedTotal = availability.expectedTotal - missingBytecodeCount;
    
    return availability;
}
```

#### 2.2 Helper Function for Contract Names
**File:** `script/DeployV2Core.s.sol`

```solidity
/// @notice Get all expected contract names for bytecode checking
/// @return contractNames Array of all contract names that could be deployed
function _getAllExpectedContractNames() internal pure returns (string[] memory contractNames) {
    // Return comprehensive list of all possible contracts
    // This should match the contracts in regenerate_bytecode.sh
    string[] memory contracts = new string[](52); // Adjust size as needed
    
    // Core contracts (always expected)
    contracts[0] = "SuperExecutor";
    contracts[1] = "SuperDestinationExecutor"; 
    contracts[2] = "SuperValidator";
    // ... add all contract names ...
    
    return contracts;
}
```

### Phase 3: Enhanced Deployment Logic

#### 3.1 Modify Contract Deployment Functions
**File:** `script/DeployV2Base.s.sol`

Enhance `__checkContractOnChain()` to skip missing bytecode:

```solidity
function __checkContractOnChain(
    string memory contractName,
    bytes32 salt,
    bytes memory args,
    uint64 chainId,
    uint256 env
) internal returns (bool isDeployed, address contractAddr) {
    
    // NEW: Check bytecode existence first
    if (!__bytecodeExists(contractName, env)) {
        console2.log("[SKIP] %s - Bytecode artifact not found", contractName);
        // Return zero address and false to indicate skip
        return (false, address(0));
    }
    
    // Existing bytecode loading and deployment check logic
    string memory artifactPath = __getBytecodeArtifactPath(contractName, env);
    bytes memory bytecode = vm.getCode(artifactPath);
    
    // ... rest of existing logic ...
}
```

#### 3.2 Safe Bytecode Loading Function
**File:** `script/DeployV2Base.s.sol`

```solidity
/// @notice Safely get bytecode with existence check
/// @param contractName Name of the contract  
/// @param env Environment
/// @return bytecode Contract bytecode (empty if file doesn't exist)
/// @return exists Whether the file exists
function __getBytcodeSafe(string memory contractName, uint256 env) 
    internal view returns (bytes memory bytecode, bool exists) {
    
    if (!__bytecodeExists(contractName, env)) {
        return ("", false);
    }
    
    return (__getBytecode(contractName, env), true);
}
```

### Phase 4: Enhanced Logging and Reporting

#### 4.1 Improve Deployment Summary Logging
**File:** `script/DeployV2Core.s.sol`

Enhance `_logContractSummary()` to show missing bytecode:

```solidity
function _logContractSummary(ContractAvailability memory availability, uint64 chainId) internal view {
    // ... existing logging ...
    
    // NEW: Show missing bytecode contracts
    if (availability.missingBytecodeContracts.length > 0) {
        console2.log("");
        console2.log("=== Contracts SKIPPED due to missing bytecode ===");
        for (uint256 i = 0; i < availability.missingBytecodeContracts.length; i++) {
            console2.log("  MISSING BYTECODE:", availability.missingBytecodeContracts[i]);
        }
        console2.log("  Missing bytecode files: %d", availability.expectedMissingBytecode);
    }
    
    // Update summary statistics
    console2.log("");
    console2.log("=== DEPLOYMENT SUMMARY ===");
    console2.log("  Expected on this chain: %d", availability.expectedTotal);
    console2.log("  Skipped (chain unavailable): %d", availability.skippedContracts.length);  
    console2.log("  Skipped (missing bytecode): %d", availability.expectedMissingBytecode);
    console2.log("  Available for deployment: %d", availability.expectedTotal);
}
```

### Phase 5: Shell Script Enhancements

#### 5.1 Individual Contract Bytecode Validation
**File:** `script/run/deploy_v2_staging_prod.sh`

Add function to report contracts with missing bytecode:

```bash
# Function to report contracts that are coded but missing bytecode
report_missing_bytecode_contracts() {
    log "INFO" "Checking for contracts with missing bytecode artifacts..."
    
    local script_path="$PROJECT_ROOT/script/run/regenerate_bytecode.sh"
    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}❌ Cannot find regenerate_bytecode.sh${NC}"
        return 1
    fi
    
    local missing_contracts=()
    
    # Check each contract type
    local contract_arrays=("CORE_CONTRACTS" "HOOK_CONTRACTS" "ORACLE_CONTRACTS")
    
    for array_name in "${contract_arrays[@]}"; do
        local contracts
        contracts=$(extract_contracts_from_regenerate_script "$array_name")
        
        for contract in $contracts; do
            [[ -z "$contract" ]] && continue
            local file_path="$LOCKED_BYTECODE_PATH/${contract}.json"
            if [ ! -f "$file_path" ]; then
                missing_contracts+=("$contract")
            fi
        done
    done
    
    if [ ${#missing_contracts[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Contracts defined in regenerate_bytecode.sh but missing bytecode:${NC}"
        for contract in "${missing_contracts[@]}"; do
            echo -e "${YELLOW}   📄 $contract${NC}"
        done
        echo -e "${YELLOW}   These contracts will be automatically skipped during deployment${NC}"
        echo ""
        return 1
    fi
    
    echo -e "${GREEN}✅ All coded contracts have bytecode artifacts available${NC}"
    return 0
}
```

#### 5.2 Enhanced Analysis Reporting
Modify `analyze_deployment_status()` to call the new reporting function:

```bash
analyze_deployment_status() {
    echo -e "${BLUE}📊 Analyzing deployment status across all networks...${NC}"
    
    # NEW: Report missing bytecode contracts
    if ! report_missing_bytecode_contracts; then
        echo -e "${CYAN}ℹ️  Note: Some contracts will be skipped due to missing bytecode${NC}"
        echo -e "${CYAN}    This is expected if those contracts haven't been compiled for this environment${NC}"
        echo ""
    fi
    
    # ... existing analysis logic ...
}
```

### Phase 6: Error Handling and Recovery

#### 6.1 Graceful Bytecode Loading
**File:** `script/DeployV2Base.s.sol`

```solidity
/// @notice Enhanced contract checking with bytecode validation
function __checkContractOnChainSafe(/*...*/) internal returns (bool isDeployed, address contractAddr, string memory skipReason) {
    
    // Check bytecode existence
    if (!__bytecodeExists(contractName, env)) {
        return (false, address(0), "MISSING_BYTECODE");
    }
    
    // Try to load bytecode
    try this.__getBytecode(contractName, env) returns (bytes memory bytecode) {
        if (bytecode.length == 0) {
            return (false, address(0), "EMPTY_BYTECODE");  
        }
        
        // Continue with normal deployment checking
        // ... existing logic ...
        
    } catch Error(string memory reason) {
        return (false, address(0), string(abi.encodePacked("BYTECODE_ERROR:", reason)));
    } catch {
        return (false, address(0), "BYTECODE_LOAD_FAILED");
    }
}
```

## Implementation Priority

### High Priority (Core Functionality)
1. **Phase 1.2** - Add `__bytecodeExists()` function to DeployV2Base
2. **Phase 2.1** - Enhance ContractAvailability analysis with bytecode checks  
3. **Phase 3.1** - Modify deployment logic to skip missing bytecode
4. **Phase 4.1** - Enhance logging to show missing bytecode contracts

### Medium Priority (Enhanced UX)
5. **Phase 1.1** - Extend ContractAvailability struct
6. **Phase 5.1** - Add missing bytecode reporting to shell script
7. **Phase 2.2** - Helper function for contract names

### Lower Priority (Robustness)
8. **Phase 3.2** - Safe bytecode loading functions
9. **Phase 6.1** - Enhanced error handling
10. **Phase 5.2** - Enhanced shell script analysis

## Implementation Notes

### Security Considerations
- Bytecode existence checks happen before any deployment attempts
- Failed bytecode loading is handled gracefully without stopping deployment
- Clear distinction between missing bytecode and deployment failures
- No changes to core deployment security logic

### Performance Impact  
- Minimal: File existence checks are fast
- Bytecode loading happens only once per contract (existing behavior)
- Early exit for missing bytecode saves processing time

### Backward Compatibility
- All changes are additive to existing structures
- Existing deployment flow continues to work
- Shell script maintains current behavior for valid deployments
- No breaking changes to external interfaces

### Testing Strategy
- Unit tests for `__bytecodeExists()` function
- Integration tests with missing bytecode scenarios  
- Shell script tests with partially missing bytecode
- End-to-end deployment tests on test networks

## File Changes Summary

### Modified Files
1. **script/DeployV2Base.s.sol**
   - Add `__bytecodeExists()` function
   - Enhance `__checkContractOnChain()` with bytecode validation
   - Add `__getBytcodeSafe()` helper function

2. **script/DeployV2Core.s.sol**
   - Extend `ContractAvailability` struct  
   - Modify `__getChainContractAvailability()` for bytecode checks
   - Enhance `_logContractSummary()` with missing bytecode reporting
   - Add `_getAllExpectedContractNames()` helper

3. **script/run/deploy_v2_staging_prod.sh**
   - Add `report_missing_bytecode_contracts()` function
   - Enhance `analyze_deployment_status()` with missing bytecode reporting

### No New Files Required
All functionality integrates into existing architecture without requiring new files.

## Expected Outcomes

### Immediate Benefits
- Deployments no longer fail due to missing bytecode artifacts
- Clear distinction between chain-unavailable vs missing bytecode contracts  
- Enhanced logging shows exactly which contracts are skipped and why
- Shell script provides upfront visibility into missing contracts

### Long-term Benefits
- More reliable deployment process across environments
- Better developer experience with clear skip reasons
- Easier debugging of deployment issues
- Foundation for future contract selection/filtering features

This implementation plan provides a comprehensive solution that enhances the existing deployment system without disrupting current functionality, while adding the requested bytecode existence checking capabilities.