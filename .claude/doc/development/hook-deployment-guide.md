# Comprehensive Hook Deployment Guide for Superform v2-core

## Table of Contents

1. [Overview](#overview)
2. [Complete Step-by-Step Process](#complete-step-by-step-process)
3. [Key Integration Points](#key-integration-points)
4. [Multi-Chain Considerations](#multi-chain-considerations)
5. [Testing and Validation](#testing-and-validation)
6. [Common Pitfalls](#common-pitfalls)
7. [Architecture Patterns](#architecture-patterns)
8. [Real-World Example: UniswapV4Hook](#real-world-example-uniswapv4hook)

---

## Overview

This guide provides a complete reference for deploying new hooks in the Superform v2-core system, based on the successful UniswapV4Hook implementation. It covers all necessary files, configuration patterns, and integration points required for production deployment.

### Key Principles

1. **Conditional Deployment**: Hooks deploy conditionally based on external dependency availability
2. **Multi-Chain Support**: Single deployment script handles all supported chains with proper fallback
3. **Dependency Validation**: Comprehensive availability checking before deployment
4. **Configuration-Driven**: All addresses and dependencies configured through structured config system

---

## Complete Step-by-Step Process

### Phase 1: Hook Implementation ✅ PREREQUISITE

Before deployment integration, ensure your hook is fully implemented and tested:

- [ ] Hook contract implemented in `src/hooks/[category]/[protocol]/`
- [ ] All unit and integration tests passing
- [ ] Hook follows Superform patterns (BaseHook inheritance, proper data encoding, etc.)
- [ ] Constructor dependencies identified

### Phase 2: Constants Registration

#### File: `script/utils/Constants.sol`

Add your hook's constant key:

```solidity
// Add to existing hook keys section
string internal constant YOUR_HOOK_KEY = "YourHookName";
```

**Example from UniswapV4Hook:**
```solidity
string internal constant SWAP_UNISWAPV4_HOOK_KEY = "SwapUniswapV4Hook";
```

### Phase 3: Configuration Enhancement

#### File: `script/utils/ConfigBase.sol`

Add dependency mapping to `EnvironmentData` struct:

```solidity
struct EnvironmentData {
    // ... existing fields ...
    mapping(uint64 chainId => address dependency) yourDependencyMapping;
}
```

**Example from UniswapV4Hook:**
```solidity
mapping(uint64 chainId => address poolManager) uniswapV4PoolManagers;
```

#### File: `script/utils/ConfigCore.sol`

Add dependency configuration for all supported chains:

```solidity
// In _setCoreConfiguration() function
configuration.yourDependencyMapping[MAINNET_CHAIN_ID] = DEPENDENCY_ADDRESS_MAINNET;
configuration.yourDependencyMapping[BASE_CHAIN_ID] = DEPENDENCY_ADDRESS_BASE;
// ... continue for all chains
configuration.yourDependencyMapping[UNSUPPORTED_CHAIN_ID] = address(0); // Mark as unavailable
```

**Example from UniswapV4Hook:**
```solidity
// ===== UNISWAP V4 POOL MANAGER ADDRESSES =====
configuration.uniswapV4PoolManagers[MAINNET_CHAIN_ID] = 0x000000000004444c5dc75cB358380D2e3dE08A90;
configuration.uniswapV4PoolManagers[BASE_CHAIN_ID] = 0x498581ff718922c3f8e6a244956af099b2652b2b;
configuration.uniswapV4PoolManagers[ARBITRUM_CHAIN_ID] = 0x360e68faccca8ca495c1b759fd9eee466db9fb32;
// ... 12 chains with real deployments
configuration.uniswapV4PoolManagers[BNB_CHAIN_ID] = address(0); // Not deployed
configuration.uniswapV4PoolManagers[LINEA_CHAIN_ID] = address(0); // Not deployed
// ... 5 chains without V4 deployment
```

### Phase 4: Deployment Script Integration

#### File: `script/DeployV2Core.s.sol`

**Step 1: Update Hook Address Structure**

Add your hook to the `HookAddresses` struct:

```solidity
struct HookAddresses {
    // ... existing hooks ...
    address yourHookAddress;
}
```

**Step 2: Update Contract Availability Structure**

Add availability flag to `ContractAvailability` struct:

```solidity
struct ContractAvailability {
    // ... existing flags ...
    bool yourHookAvailability;
    // ... counters and arrays remain unchanged
}
```

**Step 3: Implement Availability Check**

In `_getContractAvailability()` function:

```solidity
function _getContractAvailability(
    uint64 chainId,
    uint256 env
) internal view returns (ContractAvailability memory availability) {
    // ... existing availability checks ...

    // Your hook availability check
    if (configuration.yourDependencyMapping[chainId] != address(0)) {
        availability.yourHookAvailability = true;
        expectedHooks += 1; // YourHook
    } else {
        potentialSkips[skipCount++] = "YourHookName";
    }

    // ... rest of function
}
```

**Step 4: Increase Hook Array Length**

Update the hook deployment array size:

```solidity
function _deployHooks(uint64 chainId, uint256 env) private returns (HookAddresses memory hookAddresses) {
    // Increment this number by 1
    uint256 len = 36; // Was 35, now 36 for your new hook
    
    // ... rest of function
}
```

**Step 5: Add Conditional Hook Deployment**

Add your hook deployment logic in `_deployHooks()`:

```solidity
// Add at appropriate index (e.g., index 35 for the 36th hook)
if (availability.yourHookAvailability) {
    hooks[35] = HookDeployment(
        YOUR_HOOK_KEY,
        __getSalt(YOUR_HOOK_KEY),
        abi.encodePacked(
            __getBytecode("YourHookName", env), 
            abi.encode(configuration.yourDependencyMapping[chainId])
        )
    );
} else {
    console2.log("SKIPPED YourHookName: Dependency not configured for chain", chainId);
}
```

**Step 6: Add Hook Address Assignment**

In `_populateHookAddresses()` function:

```solidity
hookAddresses.yourHookAddress = 
    Strings.equal(hooks[35].name, YOUR_HOOK_KEY) ? addresses[35] : address(0);
```

### Phase 5: Bytecode Generation Integration

#### File: `script/run/regenerate_bytecode.sh`

Add your hook to the contract list:

```bash
contracts_to_compile=(
    # ... existing contracts ...
    "YourHookName"
)
```

---

## Key Integration Points

### 1. Constructor Dependency Pattern

**Critical Pattern**: All hooks with external dependencies must use immutable constructor parameters:

```solidity
contract YourHook is BaseHook {
    IDependency public immutable DEPENDENCY;
    
    constructor(address dependency_) BaseHook(HookType.NONACCOUNTING, YourHookSubtype) {
        DEPENDENCY = IDependency(dependency_);
    }
}
```

**Why This Works**:
- **Multi-Chain Compatibility**: Same bytecode deploys to different chains with different dependency addresses
- **Gas Efficiency**: Immutable variables are cheaper than storage reads
- **Type Safety**: Explicit interface casting at deployment time

### 2. Availability Check Pattern

**The Standard Pattern**:
```solidity
if (configuration.dependencyMapping[chainId] != address(0)) {
    availability.hookFlag = true;
    expectedHooks += 1;
} else {
    potentialSkips[skipCount++] = "HookName";
}
```

**Critical Elements**:
- Check dependency address is non-zero
- Increment expected hook count
- Add to skip list for logging

### 3. Deployment Bytecode Pattern

**Constructor Encoding**:
```solidity
abi.encodePacked(
    __getBytecode("YourHookName", env), 
    abi.encode(constructorArg1, constructorArg2, ...)
)
```

**Multi-Argument Example**:
```solidity
// Hook with multiple dependencies
abi.encodePacked(
    __getBytecode("ComplexHook", env), 
    abi.encode(
        configuration.dependency1[chainId],
        configuration.dependency2[chainId],
        CONSTANT_ADDRESS
    )
)
```

---

## Multi-Chain Considerations

### 1. Conditional Deployment Architecture

The deployment system handles three scenarios:

1. **Full Deployment**: Dependency available, hook deploys normally
2. **Conditional Skip**: Dependency unavailable, hook skipped with logging
3. **Graceful Fallback**: Hooks that depend on skipped hooks handle missing addresses

### 2. Supported Chain Matrix

**Current Superform Support (13 chains)**:
- **Mainnet** (1): Ethereum L1
- **L2s** (9): Base, Arbitrum, Optimism, Polygon, Avalanche, Linea, Sonic, Gnosis, BNB Chain
- **New Chains** (3): Unichain, World Chain, Berachain

**Example Deployment Pattern (UniswapV4)**:
- **Available on 8 chains**: Ethereum, Base, Arbitrum, Optimism, Polygon, Avalanche, Unichain, World Chain  
- **Not available on 5 chains**: BNB Chain, Linea, Sonic, Gnosis, Berachain
- **Deployment Result**: Hook deploys where available, gracefully skips unavailable chains

### 3. Configuration Management Best Practices

**Organize by Protocol Deployment Status**:
```solidity
// ===== YOUR_PROTOCOL ADDRESSES =====
// Currently deployed (X chains)
configuration.yourProtocol[MAINNET_CHAIN_ID] = 0x...;     // Live
configuration.yourProtocol[BASE_CHAIN_ID] = 0x...;        // Live  
configuration.yourProtocol[ARBITRUM_CHAIN_ID] = 0x...;    // Live

// Not yet deployed (Y chains)  
configuration.yourProtocol[BNB_CHAIN_ID] = address(0);    // Planned
configuration.yourProtocol[LINEA_CHAIN_ID] = address(0);  // Planned
```

**Benefits**:
- **Clear Documentation**: Deployment status visible in code
- **Future-Ready**: Easy to update when protocols deploy to new chains
- **Maintenance**: Clear separation between live and planned deployments

---

## Testing and Validation

### 1. Pre-Deployment Testing

**Unit Test Validation**:
```bash
# Test hook functionality in isolation
make forge-test TEST=YourHookTest

# Test integration patterns  
make forge-test TEST=YourHookIntegrationTest

# Validate deployment script compilation
forge build
```

**Deployment Script Testing**:
```bash
# Dry-run deployment on local fork
forge script script/DeployV2Core.s.sol --fork-url $MAINNET_RPC_URL --private-key $TEST_KEY

# Validate bytecode generation
./script/run/regenerate_bytecode.sh
```

### 2. Post-Deployment Validation

**Address Verification**:
```solidity
// In deployment logs, verify:
// 1. Hook deployed on expected chains
// 2. Hook skipped on expected chains  
// 3. Constructor args match expected dependencies
console2.log("YourHookName deployed:", hookAddresses.yourHookAddress);
console2.log("Dependency used:", configuration.yourDependencyMapping[chainId]);
```

**Contract Verification**:
```bash
# Verify deployed contracts on block explorers
# Uses Tenderly integration from deployment scripts
```

### 3. Integration Testing

**Test Hook Chaining**:
```solidity
// Validate hook works in UserOp execution
function testYourHookIntegration() public {
    UserOpData memory userOpData = _buildUserOpWithYourHook(callData);
    entryPoint.handleOps(userOpData.userOps, payable(address(this)));
    
    // Validate expected state changes
    assertEq(finalBalance, expectedBalance);
}
```

---

## Common Pitfalls

### ❌ NEVER DO THESE

#### 1. Hardcode Dependency Addresses

```solidity
// ❌ DON'T: Hardcoded addresses break multi-chain deployment
contract BadHook is BaseHook {
    IPoolManager constant POOL_MANAGER = IPoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90); // Ethereum only!
}
```

```solidity
// ✅ DO: Use constructor parameters for multi-chain compatibility
contract GoodHook is BaseHook {
    IPoolManager public immutable POOL_MANAGER;
    
    constructor(address poolManager_) BaseHook(...) {
        POOL_MANAGER = IPoolManager(poolManager_);
    }
}
```

#### 2. Skip Availability Checks

```solidity
// ❌ DON'T: Force deployment without dependency validation
hooks[35] = HookDeployment(
    YOUR_HOOK_KEY,
    __getBytecode("YourHook", env)  // No dependency check!
);
```

```solidity
// ✅ DO: Always check dependency availability
if (availability.yourHookAvailability) {
    hooks[35] = HookDeployment(
        YOUR_HOOK_KEY,
        abi.encodePacked(
            __getBytecode("YourHook", env), 
            abi.encode(configuration.dependency[chainId])
        )
    );
} else {
    console2.log("SKIPPED YourHook: Dependency not available");
}
```

#### 3. Forget Array Length Updates

```solidity
// ❌ DON'T: Forget to increment array length
uint256 len = 35; // Still 35 after adding hook - WILL FAIL!

// ✅ DO: Always increment for new hooks
uint256 len = 36; // Incremented to 36 for new hook
```

#### 4. Wrong Index Assignment

```solidity
// ❌ DON'T: Use wrong index for address assignment
hookAddresses.yourHook = addresses[34]; // Index 34 already used!

// ✅ DO: Use correct index for your hook
hookAddresses.yourHook = addresses[35]; // Correct index for 36th hook (0-indexed)
```

#### 5. Miss Configuration Setup

```solidity
// ❌ DON'T: Skip configuration setup
// Hook deployment will fail silently with address(0) dependencies

// ✅ DO: Always configure dependencies in ConfigCore.sol
configuration.yourDependencies[chainId] = REAL_ADDRESS;
```

#### 6. Improper Error Handling

```solidity
// ❌ DON'T: Let deployment fail silently
if (dependency == address(0)) {
    // Silent failure - hard to debug
}

// ✅ DO: Provide clear logging for skipped deployments
if (dependency == address(0)) {
    console2.log("SKIPPED YourHook: Dependency not configured for chain", chainId);
    potentialSkips[skipCount++] = "YourHook";
}
```

---

## Architecture Patterns

### 1. Dependency Classification

**Types of Dependencies**:

1. **Protocol Addresses** (e.g., Uniswap PoolManager, 1inch Router)
   - Vary by chain
   - May not be deployed on all chains
   - Require conditional deployment

2. **Standard Addresses** (e.g., Permit2, WETH)
   - Same address across chains (CREATE2)
   - Always available
   - Safe for direct usage

3. **Superform Addresses** (e.g., SuperRegistry, other hooks)
   - Deployed by Superform
   - Always available on supported chains
   - Retrieved from registry

### 2. Configuration Patterns

**Single Dependency Hook**:
```solidity
mapping(uint64 chainId => address protocol) protocolAddresses;

constructor(address protocol_) BaseHook(...) {
    PROTOCOL = IProtocol(protocol_);
}
```

**Multi-Dependency Hook**:
```solidity
mapping(uint64 chainId => ProtocolAddresses) protocolConfigs;

struct ProtocolAddresses {
    address router;
    address factory; 
    address oracle;
}

constructor(address router_, address factory_, address oracle_) BaseHook(...) {
    ROUTER = IRouter(router_);
    FACTORY = IFactory(factory_);
    ORACLE = IOracle(oracle_);
}
```

### 3. Availability Check Patterns

**Simple Availability**:
```solidity
if (configuration.protocol[chainId] != address(0)) {
    availability.protocolHook = true;
    expectedHooks += 1;
}
```

**Complex Availability** (multiple dependencies):
```solidity
ProtocolAddresses memory config = configuration.protocolConfigs[chainId];
if (config.router != address(0) && config.factory != address(0)) {
    availability.protocolHook = true;
    expectedHooks += 1;
} else {
    potentialSkips[skipCount++] = "ProtocolHook";
}
```

### 4. Future-Proofing Patterns

**Extensible Configuration**:
```solidity
struct ProtocolConfig {
    address currentVersion;    // v1.0 address
    address nextVersion;      // v2.0 address when available
    bool useNextVersion;      // Migration flag
}

mapping(uint64 chainId => ProtocolConfig) protocolConfigs;
```

**Version-Aware Deployment**:
```solidity
address targetVersion = config.useNextVersion && config.nextVersion != address(0) 
    ? config.nextVersion 
    : config.currentVersion;

if (targetVersion != address(0)) {
    // Deploy with target version
}
```

---

## Real-World Example: UniswapV4Hook

### Configuration Added

```solidity
// ConfigBase.sol - Added to EnvironmentData struct
mapping(uint64 chainId => address poolManager) uniswapV4PoolManagers;

// ConfigCore.sol - Added 12 chain configurations
configuration.uniswapV4PoolManagers[MAINNET_CHAIN_ID] = 0x000000000004444c5dc75cB358380D2e3dE08A90;
configuration.uniswapV4PoolManagers[BASE_CHAIN_ID] = 0x498581ff718922c3f8e6a244956af099b2652b2b;
configuration.uniswapV4PoolManagers[ARBITRUM_CHAIN_ID] = 0x360e68faccca8ca495c1b759fd9eee466db9fb32;
// ... 9 more chains with real addresses
configuration.uniswapV4PoolManagers[BNB_CHAIN_ID] = address(0); // Not deployed
configuration.uniswapV4PoolManagers[LINEA_CHAIN_ID] = address(0); // Not deployed  
// ... 4 more unsupported chains
```

### Deployment Integration Added

```solidity
// DeployV2Core.sol changes:

// 1. HookAddresses struct - Added field
address swapUniswapV4Hook;

// 2. ContractAvailability struct - Added flag  
bool swapUniswapV4Hook;

// 3. _getContractAvailability() - Added availability check
if (configuration.uniswapV4PoolManagers[chainId] != address(0)) {
    availability.swapUniswapV4Hook = true;
    expectedHooks += 1; // SwapUniswapV4Hook
} else {
    potentialSkips[skipCount++] = "SwapUniswapV4Hook";
}

// 4. _deployHooks() - Incremented array length
uint256 len = 35; // Incremented from 34

// 5. _deployHooks() - Added conditional deployment
if (availability.swapUniswapV4Hook) {
    hooks[34] = HookDeployment(
        SWAP_UNISWAPV4_HOOK_KEY,
        abi.encodePacked(
            __getBytecode("SwapUniswapV4Hook", env), 
            abi.encode(configuration.uniswapV4PoolManagers[chainId])
        )
    );
} else {
    console2.log("SKIPPED SwapUniswapV4Hook: Uniswap V4 PoolManager not available on chain", chainId);
}

// 6. _populateHookAddresses() - Added address assignment
hookAddresses.swapUniswapV4Hook = 
    Strings.equal(hooks[34].name, SWAP_UNISWAPV4_HOOK_KEY) ? addresses[34] : address(0);
```

### Results Achieved

**Deployment Success**: 
- ✅ Deploys on 8 chains with UniswapV4 support
- ✅ Gracefully skips 5 chains without V4 deployment
- ✅ Clear logging for skipped deployments
- ✅ No deployment failures or errors

**Multi-Chain Compatibility**:
- ✅ Single bytecode works across all chains
- ✅ Constructor receives chain-specific PoolManager address
- ✅ Future V4 deployments automatically supported

**Maintainability**:
- ✅ Adding new V4 chains requires only config update
- ✅ Clear separation of concerns
- ✅ Standardized pattern for future hooks

---

## Deployment Checklist

### ✅ Pre-Implementation

- [ ] **Hook Development Complete**: All tests passing, hook follows Superform patterns
- [ ] **Dependencies Identified**: All external contract dependencies catalogued  
- [ ] **Multi-Chain Research**: Dependency availability researched across all Superform chains
- [ ] **Constructor Design**: Immutable parameter pattern confirmed

### ✅ Configuration Phase

- [ ] **Constants Added**: Hook key constant added to Constants.sol
- [ ] **Dependency Mapping Added**: Mapping added to EnvironmentData struct in ConfigBase.sol
- [ ] **Address Configuration**: All dependency addresses configured in ConfigCore.sol  
- [ ] **Chain Support Matrix**: Clear documentation of supported vs unsupported chains

### ✅ Deployment Integration

- [ ] **Hook Address Field**: Hook address added to HookAddresses struct
- [ ] **Availability Flag**: Hook availability flag added to ContractAvailability struct
- [ ] **Availability Check**: Dependency validation logic added to _getContractAvailability()
- [ ] **Array Length Update**: Hook deployment array length incremented
- [ ] **Conditional Deployment**: Hook deployment logic added with proper conditional checks
- [ ] **Address Assignment**: Hook address assignment added to _populateHookAddresses()
- [ ] **Bytecode Generation**: Hook added to regenerate_bytecode.sh script

### ✅ Testing & Validation

- [ ] **Deployment Script Compilation**: forge build passes without errors
- [ ] **Bytecode Generation**: ./script/run/regenerate_bytecode.sh runs successfully  
- [ ] **Local Fork Testing**: Deployment script runs on local fork without errors
- [ ] **Multi-Chain Validation**: Availability logic validated across different chain scenarios
- [ ] **Integration Testing**: Hook tested in UserOp execution context

### ✅ Documentation

- [ ] **Configuration Changes**: All config changes documented
- [ ] **Supported Chains**: Clear matrix of supported vs unsupported chains
- [ ] **Future Updates**: Process documented for adding support for new chains
- [ ] **Troubleshooting**: Common issues and solutions documented

---

## Troubleshooting Guide

### Common Issues

**1. "Hook deployment failed silently"**
- **Cause**: Missing dependency configuration or wrong constructor args
- **Solution**: Check configuration.yourDependency[chainId] is set correctly
- **Debug**: Add logging to see actual vs expected constructor parameters

**2. "Array index out of bounds"**  
- **Cause**: Forgot to increment hook array length
- **Solution**: Update `uint256 len = X` to `uint256 len = X+1`

**3. "Hook address is zero after deployment"**
- **Cause**: Wrong index in address assignment or name mismatch
- **Solution**: Verify hook index matches between deployment and assignment

**4. "Bytecode generation fails"**
- **Cause**: Hook not added to regenerate_bytecode.sh
- **Solution**: Add hook name to contracts_to_compile array

**5. "Deployment succeeds but hook doesn't work"**
- **Cause**: Wrong dependency address or interface mismatch
- **Solution**: Verify dependency addresses and interface compatibility

### Debug Commands

```bash
# Verify hook compiles correctly
forge build --contracts src/hooks/category/protocol/YourHook.sol

# Test deployment script compilation  
forge script script/DeployV2Core.s.sol --dry-run

# Generate and verify bytecode
./script/run/regenerate_bytecode.sh
ls script/generated-bytecode/YourHook.json

# Test deployment on fork
forge script script/DeployV2Core.s.sol \
  --fork-url $MAINNET_RPC_URL \
  --private-key $TEST_PRIVATE_KEY \
  --broadcast --verify
```

---

## Summary

This comprehensive guide provides the complete blueprint for deploying hooks in Superform v2-core. The key takeaways:

1. **Follow the Pattern**: The UniswapV4Hook implementation provides a proven pattern that works across all scenarios
2. **Configuration-Driven**: All deployment logic should be driven by structured configuration  
3. **Conditional by Design**: Embrace conditional deployment as a feature, not a limitation
4. **Multi-Chain First**: Design for multi-chain from day one with proper fallback handling
5. **Test Thoroughly**: Validate deployment script, bytecode generation, and actual hook functionality
6. **Document Everything**: Clear documentation prevents future deployment issues

By following this guide, you can successfully deploy any hook type to the Superform ecosystem with confidence that it will work reliably across all supported chains while gracefully handling unsupported scenarios.