# Repo Analysis: Firelight Vault Hooks

## Key Patterns Identified

### BaseHook Architecture
- File: `src/hooks/BaseHook.sol`
- Three HookTypes: NONACCOUNTING (0), INFLOW (1), OUTFLOW (2)
- Lifecycle: `preExecute → hookExecutions → postExecute`
- Transient storage for `usedShares`, `spToken`, `asset`, `outAmount`

### Closest Analogues

**RedeemFirelightVaultHook → EthenaCooldownSharesHook**
- File: `src/hooks/vaults/ethena/EthenaCooldownSharesHook.sol`
- HookType: NONACCOUNTING, HookSubType: COOLDOWN
- Burns shares but doesn't return assets
- Tracks `usedShares` via share balance delta

**ClaimWithdrawFirelightVaultHook → EthenaUnstakeHook**
- File: `src/hooks/vaults/ethena/EthenaUnstakeHook.sol`
- HookType: OUTFLOW, HookSubType: ETHENA
- Claims assets after cooldown
- Tracks `outAmount` via asset balance delta + `usedShares` via `previewWithdraw`

### Data Encoding Convention
```
bytes32 yieldSourceOracleId  [0:32]
address yieldSource          [32:52]
uint256 amount/shares        [52:84]
bool    usePrevHookAmount    [84:85]
```

### HookSubTypes Available
- `COOLDOWN` — semantically matches redeem (initiates cooldown)
- `CLAIM` — defined but unused, semantically matches claim
- `ERC4626` — user's choice for both hooks

### Interface Selection per Hook Capability
| Interface | Purpose |
|-----------|---------|
| ISuperHookInflowOutflow | Has amount param (decodeAmount) |
| ISuperHookOutflow | OUTFLOW amount replacement (replaceCalldataAmount) |
| ISuperHookContextAware | Uses prev hook output (decodeUsePrevHookAmount) |
| ISuperHookAsyncCancelations | Async cancel support |
| ISuperHookInspector | Merkle tree leaf computation (inspect) |

### File Locations
- Hooks: `src/hooks/vaults/firelight/`
- Interface: `src/vendor/vaults/firelight/IFirelightVault.sol`
- Tests: `test/unit/hooks/vaults/firelight/`

### Test Pattern (from EthenaHooksTests)
- Inherit `Helpers`
- Constructor verification (hookType, SUB_TYPE)
- Build execution verification (target, calldata, count)
- Build revert tests (zero address, zero amount)
- usePrevHookAmount tests with MockHook
- Pre/post execute delta tracking tests
- Inspector tests
