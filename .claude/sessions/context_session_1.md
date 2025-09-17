# Context Session 1: Bytecode Existence Check System Implementation

## Task Overview
Implement a system for Superform v2 deployment scripts that allows skipping deployment of contracts when their bytecode artifacts are not present in the appropriate bytecode folder.

## Current Context
- Branch: deployMerklHookToProd 
- Environment: Superform v2 core with ERC-7579 modular architecture
- Deployment system uses environment-based bytecode folders (locked-bytecode vs locked-bytecode-dev)
- Existing skippedContracts system for chain-specific availability

## Requirements Analysis
1. Check bytecode artifact existence before deployment attempts
2. Skip deployment with proper logging when bytecode missing
3. Track contracts skipped due to missing bytecode vs chain unavailability
4. Update shell scripts for enhanced reporting
5. Leverage existing availability.skippedContracts structure

## Research Phase - COMPLETED

### Architecture Analysis
1. **Current Deployment System:**
   - `DeployV2Base.s.sol` provides base deployment functionality
   - `DeployV2Core.s.sol` handles main deployment logic with ContractAvailability struct
   - Uses environment-based bytecode folders: `locked-bytecode` (prod) vs `locked-bytecode-dev` (staging)
   - Shell script `deploy_v2_staging_prod.sh` orchestrates deployment across networks

2. **Existing Skip Mechanisms:**
   - `ContractAvailability` struct has `skippedContracts` array for chain-specific unavailability
   - Tracks contracts that can't be deployed due to missing configurations (bridge support, protocol availability)
   - Shell script validates locked bytecode files exist using `validate_locked_bytecode()` function

3. **Current Bytecode Loading:**
   - `__getBytecodeArtifactPath()` returns path based on environment 
   - `__getBytecode()` and `__checkContractOnChain()` use `vm.getCode()` to load bytecode
   - No current check for bytecode existence before attempting to load

4. **Deployment Flow:**
   - Check phase: `__checkContractOnChain()` determines deployment status
   - Deploy phase: Only missing contracts get deployed
   - Shell script already has logic to skip networks where all contracts are deployed

### Key Findings
- Shell script already validates that bytecode files exist before starting deployment
- Missing: Individual contract-level bytecode existence checking during deployment
- Need: Enhanced tracking to distinguish "missing bytecode" vs "chain unavailable" skips
- Need: Better reporting in shell script for contracts coded but missing bytecode

## Implementation Plan Created
Detailed plan saved to implementation document...