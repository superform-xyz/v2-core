# Repository Architecture Analysis for Euler Hooks

## Date: 2026-08-16
## Researcher: Explore Agent (Claude Opus 4.6)

---

## 1. Morpho Hook Architecture (Reference Pattern)

### Directory Structure
**Location**: `src/hooks/loan/morpho/`

Files:
- `BaseMorphoLoanHook.sol` - Abstract base with `morpho` immutable constructor arg
- `MorphoSupplyHook.sol` - Supply collateral (4 executions)
- `MorphoBorrowHook.sol` - Borrow (1 execution)
- `MorphoRepayHook.sol` - Repay debt (4 executions)
- `MorphoLendHook.sol` - Lend for interest (4 executions)
- `MorphoWithdrawHook.sol` - Withdraw lent assets (1 execution)
- `MorphoSupplyAndBorrowHook.sol` - Composite (5 executions)
- `MorphoRepayAndWithdrawHook.sol` - Composite (5 executions)

### BaseMorphoLoanHook Pattern
- Constructor takes `address morpho_` as immutable
- Offset constants: LOAN_TOKEN=52, COLLATERAL_TOKEN=72, ORACLE=92, IRM=112, LLTV=164
- Shared decoders: `_decodeHookData`, `_decodeBorrowHookData`, `_generateMarketParams`

### Individual Hook Patterns

**MorphoSupplyHook** (4 executions):
```
[0] approve(collateralToken, morpho, 0)
[1] approve(collateralToken, morpho, amount)
[2] morpho.supplyCollateral(marketParams, amount, account, "")
[3] approve(collateralToken, morpho, 0)
```
- `_preExecute`: stores collateral balance BEFORE
- `_postExecute`: computes delta, sets outToken = collateralToken

**MorphoBorrowHook** (1 execution):
```
[0] morpho.borrow(marketParams, amount, 0, account, account)
```

**MorphoRepayHook** (4 executions):
```
[0] approve(loanToken, morpho, 0)
[1] approve(loanToken, morpho, amount)
[2] morpho.repay(marketParams, amount/shares, account, "")
[3] approve(loanToken, morpho, 0)
```
- Full repay uses shares, partial uses assets

**Composite MorphoSupplyAndBorrowHook** (5 executions):
- Takes ONE input amount (collateral), derives borrow via LTV/oracle
- outAmount tracks collateral consumed (NOT borrowed amount)

---

## 2. Aave V3 Hook Architecture (Deployment Pattern Reference)

### Directory Structure
**Location**: `src/hooks/loan/aave-v3/`

Files:
- `BaseAaveV3LoanHook.sol` - Abstract base, NO constructor args
- `AaveV3SupplyHook.sol`, `AaveV3WithdrawHook.sol`
- `AaveV3BorrowHook.sol`, `AaveV3RepayHook.sol`
- `AaveV3RepayWithATokensHook.sol`
- `AaveV3SupplyAndBorrowHook.sol`
- `AaveV3RepayAndWithdrawHook.sol`

### Key Difference: NO Constructor Args
Pool address comes from calldata at offset 92, allowing single deployment per chain.

### Data Layout Variants
- Supply/Withdraw: AMOUNT=112, USE_PREV=144 (145 bytes min)
- Borrow/Repay: RATE_MODE=112, AMOUNT=113, USE_PREV=145 (146 bytes min)
- Combined: RATE_MODE=112, AMOUNT1=113, AMOUNT2=145, USE_PREV=177 (178 bytes min)

### Dual-Amount Pattern (AaveV3SupplyAndBorrowHook)
```solidity
function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
    amounts = new uint256[](2);
    amounts[0] = BytesLib.toUint256(data, CB_AMOUNT1_OFFSET);
    amounts[1] = BytesLib.toUint256(data, CB_AMOUNT2_OFFSET);
}

function amountRoles(bytes memory) external pure override
    returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
    meta = new ISuperHookInflowOutflow.AmountMeta[](2);
    meta[0] = ISuperHookInflowOutflow.AmountMeta(Direction.IN, Denomination.TOKEN);
    meta[1] = ISuperHookInflowOutflow.AmountMeta(Direction.OUT, Denomination.TOKEN);
}
```

---

## 3. Base Hook Infrastructure

### BaseHook (src/hooks/BaseHook.sol)
- HookType enum: NONACCOUNTING, INFLOW, OUTFLOW
- Transient storage: `tstore`/`tload` for per-execution-context storage
- Lifecycle: `build()` -> `preExecute()` -> operations -> `postExecute()` -> `resetExecutionState()`
- PipeMode: TRANSFORM (default), PASSTHROUGH, SOURCE

### BaseLoanHook (src/hooks/loan/BaseLoanHook.sol)
- Inheritance: `BaseHook + ISuperHookLoans + ISuperHookInflowOutflow + ISuperHookOutflow`
- Fixed constants: `AMOUNT_POSITION = 132`, `USE_PREV_HOOK_AMOUNT_POSITION = 196`
- Token address helpers: `getLoanTokenAddress(52)`, `getCollateralTokenAddress(72)`
- Default single-amount sizing interface

---

## 4. Hook Interfaces

### ISuperHookLoans
- `getLoanTokenAddress(data)`, `getCollateralTokenAddress(data)`
- `getCollateralTokenBalance(account, data)`, `getLoanTokenBalance(account, data)`

### ISuperHookInflowOutflow
- `decodeAmounts(data)` - returns amount array
- `amountRoles(data)` - returns AmountMeta array (Direction + Denomination)

### ISuperHookOutflow
- `replaceCalldataAmounts(data, amounts)` - for OMS sizing

---

## 5. Deployment Patterns

### Hook Key Constants (script/utils/Constants.sol)
```solidity
string internal constant MORPHO_SUPPLY_HOOK_KEY = "MorphoSupplyHook";
string internal constant AAVE_V3_SUPPLY_HOOK_KEY = "AaveV3SupplyHook";
```

### Deployment Script (script/DeployV2OtherHooks.s.sol)
- Morpho: `abi.encodePacked(bytecode, abi.encode(morphoAddress))` (constructor arg)
- Aave V3: `bytecode` only (no constructor args)
- Conditional: Only deploy on chains where protocol exists

### Network Configuration (script/utils/ConstantsOtherHooks.sol)
- Per-chain protocol addresses
- Maps `chainId -> protocolAddress`

---

## 6. Vendor Interfaces Pattern

### Morpho Vendor (src/vendor/morpho/)
- `IMorpho.sol`, `IOracle.sol`, `IIrm.sol`, `IMetaMorpho.sol`
- `MarketParamsLib.sol`, `SharesMathLib.sol`, `MathLib.sol`

### Aave V3 Vendor (src/vendor/aave-v3/)
- `IPool.sol` - Minimal subset of pool functions
- `DataTypes.sol` - Reserve data structures

---

## 7. Testing Patterns

### Unit Tests (test/unit/hooks/loan/)
- Inherit `Helpers` (NOT `BaseTest`)
- Mock contracts for external dependencies
- Test `_buildHookExecutions` directly
- Test decoding methods and custom errors

### Fork Tests (test/integration/)
- Use `vm.createSelectFork`
- Test against real protocol deployments
- Full lifecycle tests (open -> close positions)

### Existing Euler Integration
- `test/integration/euler/EulerVaultFork.t.sol` - ERC-4626 vault tests only
- Known vaults (Ethereum): `0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9` (USDC), `0xe2D6A2a16ff6d3bbc4C90736A7e6F7Cc3C9B8fa9` (WETH)

---

## 8. Critical Implementation Patterns

### Triple-Approval (USDT Compatibility)
```
approve(token, spender, 0) -> approve(token, spender, amount) -> operation -> approve(token, spender, 0)
```

### Balance-Delta Verification
```solidity
_preExecute: _setOutAmount(token.balanceOf(account), account)
_postExecute: delta = getOutAmount(account) - token.balanceOf(account)
```

### Full-Repay Detection (Morpho)
- Full: pass shares to `repay()` with assets=0
- Partial: pass assets to `repay()` with shares=0
