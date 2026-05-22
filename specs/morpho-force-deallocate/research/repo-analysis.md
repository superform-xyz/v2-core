# Repository Research: ForceDeallocateMorphoHook

## 1. Existing Morpho Hooks Pattern (MetaMorphoReallocateHook)

**Primary reference:** `src/hooks/vaults/metamorpho/MetaMorphoReallocateHook.sol`

**Structure:**
- Constructor: `BaseHook(HookType.NONACCOUNTING, HookSubTypes.MISC)`
- Implements `ISuperHookContextAware` for `usePrevHookAmount` support
- No `_preExecute`/`_postExecute` overrides (NONACCOUNTING)
- Only overrides `_buildHookExecutions()` and `inspect()`
- No constructor arguments

**Data layout:**
```
bytes32 placeholder (0-32)       -- reserved
address metaMorphoVault (32-52)  -- via data.extractYieldSource()
bool usePrevHookAmount (52)      -- single byte
uint8 prevHookAmountIndex (53)   -- single byte
bytes allocationsData (54+)      -- abi.encoded
```

## 2. Hook Registration & Deployment

Morpho hooks deployed via `DeployV2OtherHooks.s.sol` → `_deployMorphoHooksSet()` (lines 173-267).

**Files to modify for new hooks:**

| File | Change |
|------|--------|
| `script/utils/Constants.sol` (~line 220) | Add hook key constants |
| `script/DeployV2OtherHooks.s.sol` | Add to MorphoHookAddresses struct + deployment |
| `script/run/regenerate_bytecode.sh` (~line 186) | Add to MORPHO_HOOK_CONTRACTS array |
| `script/run/deploy_v2_other_hooks_staging_prod.sh` (~line 250) | Add to MORPHO_HOOKS array |

## 3. Vendor Interfaces

Existing in `src/vendor/morpho/`:
- `IMorpho.sol` — Morpho Blue core
- `IMetaMorpho.sol` — MetaMorpho V1 vault's `reallocate()`
- `IIrm.sol`, `IOracle.sol`, `MarketParamsLib.sol`, `MathLib.sol`, `SharesMathLib.sol`

New: `IMorphoVaultV2.sol` with `forceDeallocate` signature.

## 4. Approve-and-X Pattern

Best reference: `src/hooks/vaults/4626/ApproveAndDeposit4626VaultHook.sol`

Pattern: 4 executions — zero-approve-action-zero:
```solidity
executions[0] = approve(token, spender, 0);     // reset
executions[1] = approve(token, spender, amount); // set
executions[2] = coreAction(...);                 // action
executions[3] = approve(token, spender, 0);      // cleanup
```

Approve variant data layout includes `address token` field.

## 5. Deadline/Slippage Protection

Reference: `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol` (lines 53, 187-189):
```solidity
error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);
if (deadline < block.timestamp) revert EXPIRED_DEADLINE(deadline, block.timestamp);
```

## 6. Error Definitions

Errors defined per-hook (no shared file). BaseHook provides common errors. Hook-specific errors added in each contract.

## 7. Test Patterns

- **Unit:** `test/unit/hooks/vaults/metamorpho/MetaMorphoReallocateHook.t.sol`
  - Extends `Helpers`, uses `makeAddr()`, `_encodeData()` helper
  - Sections: CONSTRUCTOR, BUILD, USE_PREV_HOOK_AMOUNT, INSPECT, FUZZ
  - `hook.build()` returns 3 executions (pre + hook + post)

- **Integration:** `test/integration/metamorpho/MetaMorphoReallocateHookE2E.t.sol`
  - `vm.createSelectFork()` with real Ethereum fork
  - Real vault address, `vm.prank()`, `assertApproxEqRel()`

## 8. Proposed Data Layout

**ForceDeallocateMorphoHook:**
```
bytes32 placeholder (0-32)
address morphoVaultV2 (32-52)
address adapter (52-72)
uint256 assets (72-104)
uint256 deadline (104-136)
uint256 maxPenaltyBps (136-168)
bool usePrevHookAmount (168)
bytes adapterData (169+)
```

**ApproveAndForceDeallocateMorphoHook:**
```
bytes32 placeholder (0-32)
address morphoVaultV2 (32-52)
address token (52-72)
address adapter (72-92)
uint256 assets (92-124)
uint256 deadline (124-156)
uint256 maxPenaltyBps (156-188)
bool usePrevHookAmount (188)
bytes adapterData (189+)
```

## 9. New Files to Create

| File | Purpose |
|------|---------|
| `src/vendor/morpho/IMorphoVaultV2.sol` | Vault V2 interface |
| `src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol` | Base hook |
| `src/hooks/vaults/metamorpho/ApproveAndForceDeallocateMorphoHook.sol` | Approve variant |
| `test/unit/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.t.sol` | Unit tests |
| `test/integration/metamorpho/ForceDeallocateMorphoHookE2E.t.sol` | Fork E2E tests |
