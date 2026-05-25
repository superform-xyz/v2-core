# Repository Research: Odos V3 Swap Hook Implementation

## 1. Existing Odos V2 Hook Templates

### SwapOdosV2Hook
**File:** `src/hooks/swappers/odos/SwapOdosV2Hook.sol`

- Inherits `BaseHook` and `ISuperHookContextAware` (line 31)
- Constructor: `BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)` (line 37)
- Immutable: `IOdosRouterV2 public immutable ODOS_ROUTER_V2` (line 32)
- `USE_PREV_HOOK_AMOUNT_POSITION = 156` (line 34)
- `_buildHookExecutions` returns 1 execution (the swap call) (line 68)
- Supports native token via `address(0)` pattern
- `_preExecute`: stores output token balance before swap (line 97-98)
- `_postExecute`: calculates delta (after - before) (line 101-103)
- `inspect()`: returns `abi.encodePacked(executor)` (line 88-92)

**Data layout:**
```
Offset 0:   address inputToken       (20 bytes)
Offset 20:  uint256 inputAmount      (32 bytes)
Offset 52:  address inputReceiver    (20 bytes)
Offset 72:  address outputToken      (20 bytes)
Offset 92:  uint256 outputQuote      (32 bytes)
Offset 124: uint256 outputMin        (32 bytes)
Offset 156: bool usePrevHookAmount   (1 byte)
Offset 157: uint256 pathDefLength    (32 bytes)
Offset 189: bytes pathDefinition     (variable)
Offset 189+len: address executor     (20 bytes)
Offset 189+len+20: uint32 referralCode (4 bytes)
```

### ApproveAndSwapOdosV2Hook
**File:** `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol`

- Defines internal `HookParams` struct
- `_buildHookExecutions` returns 4 executions:
  1. `approve(router, 0)` — reset
  2. `approve(router, inputAmount)` — set
  3. `swap(...)` — execute
  4. `approve(router, 0)` — clear
- Same data layout as SwapOdosV2Hook

## 2. BaseHook Architecture
**File:** `src/hooks/BaseHook.sol`

- Constructor: `constructor(ISuperHook.HookType hookType_, bytes32 subType_)`
- Uses transient storage for execution state
- Override points: `_buildHookExecutions()`, `_preExecute()`, `_postExecute()`, `inspect()`
- Helper utilities: `_decodeBool`, `_setOutAmount`, `getOutAmount`, `_replaceCalldataAmount`

## 3. Fee Validation Patterns

**MerklClaimRewardHook** (`src/hooks/claim/merkl/MerklClaimRewardHook.sol:37-38,72-73`):
```solidity
uint256 public constant BPS = 10_000;
uint256 public constant MAX_FEE_PERCENT = 5000; // 50%
if (feePercent > MAX_FEE_PERCENT) revert FEE_NOT_VALID();
if (feePercent > 0 && feeReceiver == address(0)) revert ADDRESS_NOT_VALID();
```

**SuperLedgerConfiguration** (`src/accounting/SuperLedgerConfiguration.sol:43`):
```solidity
uint256 internal constant MAX_FEE_PERCENT = 5000;
```

**Recommended for V3:** `MAX_REFERRAL_FEE_BPS = 500` (5%) with custom error.

## 4. Test Patterns

### Unit Tests
**File:** `test/unit/hooks/swappers/odos/OdosUnitTests.t.sol`
- Inline `MockOdosRouter` at top
- Inherits `Helpers`
- Tests: constructor validation, decodeUsePrevHookAmount, build execution count, prevHookAmount, preExecute/postExecute, inspect

### Integration Tests
**File:** `test/integration/odos/OdosRouterEthSwap.t.sol`
- Uses `MinimalBaseIntegrationTest` + `OdosAPIParser`
- Toggle for real vs mock router

### Helper
**File:** `test/utils/InternalHelpers.sol:211-240` — `_createOdosSwapHookData()`

### Mocks
- `test/mocks/MockOdosRouterV2.sol` — Full mock (0.5% slippage)
- `test/mocks/MockOdosSwap.sol` — Simple mock
- `test/mocks/MockHook.sol` — Generic prevHook

## 5. Deployment

### Core deployment pattern
**File:** `script/DeployV2Core.s.sol:2312-2319`
```solidity
hooks[18] = _createSafeHookDeploymentWithArgs(
    SWAP_ODOSV2_HOOK_KEY, "SwapOdosV2Hook", env, abi.encode(configuration.odosRouters[chainId])
);
```

### Other hooks pattern (recommended for V3)
**File:** `script/DeployV2OtherHooks.s.sol` — for post-audit hooks

### Constants
- `script/utils/Constants.sol:169,191` — hook key strings
- `script/utils/ConfigCore.sol:121-135` — per-chain router addresses

## 6. V3 Data Layout (Proposed)
```
Offset 0:   address inputToken            (20 bytes)
Offset 20:  uint256 inputAmount           (32 bytes)
Offset 52:  address inputReceiver         (20 bytes)
Offset 72:  address outputToken           (20 bytes)
Offset 92:  uint256 outputQuote           (32 bytes)
Offset 124: uint256 outputMin             (32 bytes)
Offset 156: bool usePrevHookAmount        (1 byte)
Offset 157: uint256 pathDefinitionLength  (32 bytes)
Offset 189: bytes pathDefinition          (variable)
Offset 189+len: address executor          (20 bytes)
Offset 189+len+20: uint256 referralCode   (32 bytes)   ← was uint32 (4 bytes)
Offset 189+len+52: uint256 referralFee    (32 bytes)   ← NEW
Offset 189+len+84: address feeRecipient   (20 bytes)   ← NEW
```

## 7. Files to Create/Modify

**New files:**
1. `src/vendor/odos/IOdosRouterV3.sol`
2. `src/hooks/swappers/odos/SwapOdosV3Hook.sol`
3. `src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol`
4. `test/unit/hooks/swappers/odos/OdosV3UnitTests.t.sol`
5. `test/mocks/MockOdosRouterV3.sol`

**Files to modify:**
- `script/utils/ConstantsOtherHooks.sol`
- `script/DeployV2OtherHooks.s.sol`
- `script/run/regenerate_bytecode.sh`
- `test/utils/InternalHelpers.sol`

## 8. Key Decisions
- Fee cap: `MAX_REFERRAL_FEE_BPS = 500` in `_buildHookExecutions()`
- `inspect()` returns `abi.encodePacked(executor, feeRecipient)`
- V2 hooks unchanged, V3 in same directory
- Deploy via `DeployV2OtherHooks.s.sol`
