# Session 18: Morpho Blue Market Oracle

## Branch
`feat/morpho-blue-tests`

## Goal
Implement a yield source oracle for Morpho Blue lending markets (supply-side only), consisting of:
1. `MorphoBlueMarketWrapper` — immutable wrapper giving a Morpho Blue market an addressable identity
2. `MorphoBlueYieldSourceOracle` — oracle that replicates Morpho's interest accrual in view context

## Spec
`specs/morpho-blue-market-oracle/` — created this session. Pod leader approval pending.

## Key Design Decisions
- **Supply-side only** (lender positions, not borrower tracking)
- **Permissionless wrapper deployment** — anyone can deploy a wrapper for any valid Morpho market
- **View replication** of Morpho's `_accrueInterest` using `IIrm.borrowRateView` + `wTaylorCompounded`
- **Standalone** — no SuperLedgerConfiguration registration yet (no fee calculation)
- **Generic** — any market supported via wrapper, no code changes per market
- **All chains** where Morpho Blue exists (Ethereum, Base, etc.)
- **Zero-IRM markets** — skip accrual, return stored state
- **Bit-exact parity** with MorphoBalancesLib.expectedMarketBalances

## Files

### New (untracked, all complete)
- `src/accounting/oracles/MorphoBlueMarketRegistry.sol` — replaces wrapper
- `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol`
- `test/integration/morpho/MorphoBlueMarketFork.t.sol`

### Deleted
- `src/accounting/oracles/MorphoBlueMarketWrapper.sol` — replaced by registry

### New (spec)
- `specs/morpho-blue-market-oracle/spec.md`
- `specs/morpho-blue-market-oracle/technical-spec.md`
- `specs/morpho-blue-market-oracle/interview-notes.md`
- `specs/morpho-blue-market-oracle/research/repo-analysis.md`
- `specs/morpho-blue-market-oracle/research/best-practices.md`
- `specs/morpho-blue-market-oracle/research/evm-security.md`

## Implementation Details

### MorphoBlueMarketRegistry (replaces Wrapper)
- `AccessControl` with `DEFAULT_ADMIN_ROLE` + `MARKET_MANAGER_ROLE`
- `registerMarket(morpho_, loanToken_, collateralToken_, oracle_, irm_, lltv_)` → validates via `idToMarketParams`, derives `marketKey = address(uint160(uint256(Id.unwrap(id))))`, stores `MarketInfo{morpho, params, registered}`
- `deregisterMarket(marketKey)` — removes market, oracle reverts for that key
- `getMarketInfo(marketKey)` → `(MarketParams, address morpho)` — reverts `MARKET_NOT_REGISTERED` if not registered
- `isRegistered(marketKey)` / `computeMarketKey(...)` — query helpers
- Constructor takes `admin_` address; `MARKET_MANAGER_ROLE` granted to admin

### MorphoBlueYieldSourceOracle
- Extends `AbstractYieldSourceOracle`
- Adds `MorphoBlueMarketRegistry public immutable REGISTRY` — constructor takes `registry_` param
- `yieldSourceAddress` in all methods is now a `marketKey` (pseudo-address from registry)
- `_getAccruedMarketState` calls `REGISTRY.getMarketInfo(yieldSourceAddress)` to get `(mp, morpho)` — no wrapper
- `_getAccruedMarketState` replicates Morpho's `_accrueInterest`:
  - Three-condition skip: `elapsed > 0 && totalBorrowAssets > 0 && irm != address(0)`
  - Fee denominator subtraction: `toSharesDown(totalSupplyAssets - feeAmount, totalSupplyShares)`
  - Uses inner scoped blocks `{}` to avoid stack-too-deep
- Rounding: `toSharesDown` for deposits, `toSharesUp` for withdrawals, `toAssetsDown` for value
- `getBalanceOfOwner` returns **supply shares** (not assets) — non-ERC20, non-transferable

### Key Fix Applied This Session
Added `&& mp.irm != address(0)` third condition to accrual skip (matches MorphoBalancesLib exactly).
Also refactored with inner scoped blocks to fix pre-existing stack-too-deep compile error.

### Test Results
All tests updated to use registry-based keys (wbtcUsdcKey, wstethWethKey) instead of wrapper addresses.
- 7 registry tests (storesMarketParams, computesCorrectKey, rejectsInvalidMarket, isRegistered, deregister, accessControl, doubleRegister)
- 14 oracle isolation tests (decimals, PPS, TVL, conversions, round-trip, supply lifecycle)
- 3 E2E hook lifecycle tests (LendHook supply → oracle → WithdrawHook withdraw)
- 11 true hook lifecycle tests: setExecutionContext → preExecute → ops → postExecute (WBTC/USDC + wstETH/WETH)
- 5 multi-user / multi-market / oracle-accrual cross-check tests
- 5 additional oracle accrual fork tests (30d warp, daily monotonic, large withdraw, zero balance)
- 9 fuzz tests (round-trip, PPS monotonic, supply-PPS invariant, rounding, TVL consistency, hook lifecycle fuzz)
- Batch methods (getPricePerShareMultiple, getTVLMultiple)
- Helpers: `_supplyViaLendHook`, `_withdrawViaWithdrawHook` (full hook lifecycle), `_supplyToMorpho` (direct)
- Code compiles cleanly (`forge build` successful); fork tests require 1Password sign-in for ETHEREUM_RPC_URL

### Test Notes
- PPS semantics: Morpho supply shares use VIRTUAL_SHARES=1e6, so PPS for 6-decimal USDC ≈ 1 atomic unit (not 1e6). Tests assert `pps > 0`, not `pps >= 1 token`.
- Lifecycle rounding: supply+immediate withdraw loses 1 wei (Morpho's `toSharesDown`). Tests use `assertApproxEqAbs(..., 1)`.

## Security Fixes Applied (session continuation)

Security report: `specs/security-reports/2026-06-26-morpho-blue-oracle-registry.md`

### MorphoBlueMarketRegistry changes
- **P0-01 + P1-01 IRM whitelist**: `approvedIrms` mapping + `setIrmApproval(irm_, approved_)`. `registerMarket` now reverts `IRM_NOT_APPROVED` for non-zero IRMs not in whitelist. Zero-IRM markets always permitted.
- **P1-04 Deregistration timelock**: `DEREGISTER_DELAY = 2 days`. `deregisterMarket` replaced with `proposeDeregisterMarket` + `executeDeregisterMarket` + `cancelDeregisterMarket`. New state: `pendingDeregistrations` mapping. New events: `MarketDeregistrationProposed`, `MarketDeregistrationCancelled`.
- **P2-01**: Added `@dev` doc to `registerMarket` explaining morpho_ trust model (no on-chain whitelist; MARKET_MANAGER_ROLE is trusted).
- **P2-02**: Documented key truncation collision probability (~2^-80) in class NatSpec and `computeMarketKey` NatSpec.
- **P2-03**: `registerMarket` reverts `INVALID_LOAN_TOKEN` when `loanToken_ == address(0)`.
- **P2-05**: Constructor reverts `ZERO_ADDRESS` when `admin_ == address(0)`.
- **P3-04**: Added `@param`/`@return` NatSpec to `getMarketInfo`, `isRegistered`, `computeMarketKey`, `deregisterMarket`-replacement functions.
- **P3-06**: Added `// external` and `// morpho vendor` import group comments.
- New errors added: `INVALID_LOAN_TOKEN`, `IRM_NOT_APPROVED`, `ZERO_ADDRESS`, `DEREGISTRATION_NOT_PENDING`, `DEREGISTRATION_TIMELOCK_NOT_ELAPSED`.
- New events added: `IrmApprovalSet`, `MarketDeregistrationProposed`, `MarketDeregistrationCancelled`.

### MorphoBlueYieldSourceOracle changes
- **P1-02 Elapsed cap**: `if (elapsed > 365 days) elapsed = 365 days` prevents `wTaylorCompounded` overflow after chain halts.
- **P1-03 Fee guard**: Fee accrual gated with `if (s.totalSupplyAssets >= feeAmount)` to prevent underflow.
- **P2-05**: Constructor reverts `ZERO_ADDRESS` when `registry_ == address(0)`.
- **P3-01**: Reads actual `totalBorrowShares` from `market()` and passes it to the `Market` struct for `borrowRateView` (was hardcoded to 0).
- **P3-02**: `_getAccruedMarketState` now returns `(AccruedState memory s, MarketParams memory mp)`. `getPricePerShare` uses the returned `mp` for decimals — eliminates the redundant second registry call. All other callers use `(s,)` tuple destructuring.
- **P3-05**: `totalBorrowAssets` removed from `AccruedState` struct (it is borrow-side state, not needed by supply-side oracle callers). Made a local `uint256 totalBorrowAssets` variable inside `_getAccruedMarketState`.
- New error: `ZERO_ADDRESS`.
- Class NatSpec updated to document elapsed cap, IRM safety, and fee guard.

### Test changes (MorphoBlueMarketFork.t.sol)
- `setUp`: Added `registry.setIrmApproval(WBTC_USDC_IRM, true)` and `registry.setIrmApproval(WSTETH_WETH_IRM, true)` before `registerMarket` calls.
- `test_registry_deregister_clearsMarket`: Updated to use `proposeDeregisterMarket` + `vm.warp(2 days + 1)` + `executeDeregisterMarket` three-step flow.

## Status
- [x] Spec created (specs/morpho-blue-market-oracle/)
- [x] MorphoBlueMarketRegistry implemented (replaces wrapper — singleton with AccessControl)
- [x] MorphoBlueYieldSourceOracle updated to use registry
- [x] MorphoBlueMarketWrapper deleted
- [x] irm != address(0) fix applied
- [x] Stack-too-deep fix (inner scoped blocks)
- [x] Fork tests: registry + oracle isolation tests
- [x] Fork tests: E2E hook + oracle lifecycle
- [x] Fork tests: true hook lifecycle (setExecutionContext → preExecute → ops → postExecute)
- [x] Fork tests: multi-user, multi-market, oracle accrual cross-checks
- [x] Fuzz tests (including hook lifecycle fuzz)
- [x] Helper methods: _supplyViaLendHook, _withdrawViaWithdrawHook added to HELPERS section
- [x] Security fixes applied (P0-01, P1-01–04, P2-01–03/05, P3-01/02/04/05/06)
- [x] Security report: specs/security-reports/2026-06-26-morpho-blue-oracle-registry.md
- [x] Compiles cleanly (forge build successful)
- [ ] Fork tests passing (need 1Password sign-in for ETHEREUM_RPC_URL)
- [ ] Deployment script (deferred — standalone, no registration yet)
- [ ] Pod leader approval on spec

## Next Steps
- Get pod leader approval on `specs/morpho-blue-market-oracle/spec.md`
- Commit all files on `feat/morpho-blue-tests` branch
- Deployment script when oracle is registered in SuperLedgerConfiguration
