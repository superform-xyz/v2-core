# Session 5: Morpho Blue Oracles for SuperLedger

## Goal
Create two oracles for Morpho Blue positions:
1. `MorphoLendYieldSourceOracle` — lend/supply side (PPS increases over time)
2. `MorphoBorrowCostOracle` — borrow/debt side (PPS increases = growing debt)

## Plan Source
`/Users/cosming/Documents/AI/research/morpho-oracles-plan.md`

## Key Design
- Both extend `AbstractYieldSourceOracle` (no AccessControl — permissionless registration)
- Use `mapping(address yieldSourceId => Id marketId)` for market registration
  - Needed because Morpho Blue is a singleton — markets are identified by `MarketParams` hashed to `Id` (bytes32), not addresses
  - `IYieldSourceOracle` requires `address yieldSourceAddress` (20 bytes), can't fit 32-byte Id
  - `registerMarket` is the minimal bridge: permissionless, one-time per yieldSourceId, validates market exists on Morpho
- Pure on-chain reads from Morpho's singleton — no record hooks, no stored state
- Use `SharesMathLib` for conversions (toAssetsDown/Up, toSharesDown/Up)
- Lend oracle rounds DOWN (favor protocol), Borrow oracle rounds UP (conservative debt)

## Design Decisions
- **Why registerMarket is needed**: Morpho is a singleton (one contract, many markets identified by bytes32 Id). IYieldSourceOracle uses address (20 bytes). 32 bytes can't fit in 20 bytes. Explored splitting Id across two address params but only works for functions with 2+ address params — getPricePerShare(address), decimals(address), getTVL(address) only have one.
- **Why not one oracle per market**: User rejected as "even worse" — too many deployments for hundreds of markets.
- **registerMarket is permissionless**: No AccessControl, no admin roles. Anyone can register any existing Morpho market. One-time per yieldSourceId.

## Location: v2-periphery (MOVED from v2-core)
All oracle code lives in v2-periphery, NOT v2-core.

### Files in v2-periphery
- [x] `src/oracles/MorphoLendYieldSourceOracle.sol`
- [x] `src/oracles/MorphoBorrowCostOracle.sol`
- [x] `test/mocks/MockMorpho.sol` (MockMorphoERC20 + MockMorpho)
- [x] `test/oracles/MorphoLendYieldSourceOracle.t.sol` (19 unit tests)
- [x] `test/oracles/MorphoBorrowCostOracle.t.sol` (16 unit tests)
- [x] `test/oracles/MorphoOraclesE2E.t.sol` (22 e2e tests on mainnet fork)

### Files DELETED from v2-core
- `src/accounting/oracles/MorphoLendYieldSourceOracle.sol`
- `src/accounting/oracles/MorphoBorrowCostOracle.sol`
- `test/unit/accounting/oracles/MorphoLendYieldSourceOracle.t.sol`
- `test/unit/accounting/oracles/MorphoBorrowCostOracle.t.sol`
- `test/unit/accounting/oracles/mocks/MockMorpho.sol`
- `test/integration/morpho/MorphoOraclesE2E.t.sol`

## Iteration 2: AccessControl + Deployment Scripts

- Added `AccessControl` with `MANAGER_ROLE` for market registration/unregistration to both oracles
- Created `DeployMorphoOracles.s.sol` deployment script (deterministic deploy, multi-chain)
- Created `deploy_morpho_oracles.sh` bash deployment script (simulate/execute/check modes)
- Added 2 more e2e tests for access control → 24 e2e tests total

## Iteration 3: SuperVault E2E Tests + Multi-Decimal Coverage

### SuperVault E2E Tests
- Created `test/oracles/MorphoOraclesSuperVaultE2E.t.sol` — 22 tests
- Tests integrate real deployed SuperVault strategies with oracles on forked mainnet
- Covers: strategy yield source discovery, oracle-strategy position tracking, multi-strategy same market, SuperVault accounting consistency, interest accrual, full lifecycle (supply + borrow), multi-registration, cross-oracle consistency
- Key SuperVault constants: SUPER_USDC_VAULT, SUPER_WBTC_VAULT, SUPER_WETH_VAULT + their strategies

### Multi-Decimal Unit Tests
- Added 18 new tests to `MorphoLendYieldSourceOracle.t.sol` (6-dec, 8-dec, cross-decimal)
- Added 16 new tests to `MorphoBorrowCostOracle.t.sol` (6-dec, 8-dec, cross-decimal)
- Added `_setupDecimalMarket` helper to both test files
- Key learning: Morpho virtual share offset (1e6) causes integer PPS truncation for low-decimal tokens

### Files Added/Modified
- [x] `test/oracles/MorphoOraclesSuperVaultE2E.t.sol` (NEW - 22 tests)
- [x] `test/oracles/MorphoLendYieldSourceOracle.t.sol` (UPDATED - 44 tests total, was 19)
- [x] `test/oracles/MorphoBorrowCostOracle.t.sol` (UPDATED - 38 tests total, was 16)

## Test Results (Final)
- 44 lend unit tests: ALL PASS (includes 6-dec, 8-dec, 18-dec, cross-decimal)
- 38 borrow unit tests: ALL PASS (includes 6-dec, 8-dec, 18-dec, cross-decimal)
- 24 e2e integration tests: ALL PASS (mainnet fork, real Morpho contract)
- 22 SuperVault e2e tests: ALL PASS (mainnet fork, real SuperVault strategies)
- **Total: 128 tests passing**

## Implementation Notes
- v2-periphery imports v2-core via `@superform-v2-core/=lib/v2-core/` remapping
- MockMorpho mock named `MockMorphoERC20` (not `MockERC20`) to avoid collision with existing v2-periphery MockERC20
- E2E tests use `vm.envString("ETHEREUM_RPC_URL")` and inline constants (MORPHO address, USDC, WBTC, etc.)
- Market existence validated by checking `lastUpdate > 0` on Morpho
- For 6-decimal tokens (USDC), PPS at `10^decimals` base has low precision (~1), so interest accrual tests use `getAssetOutput` with large share amounts
- Morpho share precision = asset_decimals + 6 (due to VIRTUAL_SHARES = 1e6)
- `supply()` triggers `_accrueInterest()`, so TVL increases by more than deposit amount
