# Repo Analysis — Aave V4 Oracles (AaveV4DebtOracle + AaveV4SupplyYieldSourceOracle + AaveV4ReserveRegistry)

Produced by repo-research-analyst, 2026-09-02. All paths relative to v2-core root.

---

## 1. AbstractYieldSourceOracle — the oracle contract surface

File: `src/accounting/oracles/AbstractYieldSourceOracle.sol` (203 lines, implements `IYieldSourceOracle` from `src/interfaces/accounting/IYieldSourceOracle.sol`)

Abstract (virtual, must implement) methods:
- `decimals(address yieldSourceAddress) → uint8` — line 38
- `getShareOutput(address yieldSourceAddress, address assetIn, uint256 assetsIn) → uint256` — lines 41-49
- `getWithdrawalShareOutput(...)` — lines 52-60
- `getAssetOutput(address, address assetOut, uint256 sharesIn) → uint256` — lines 63-71 (`public view virtual`, called by the fee wrapper)
- `getPricePerShare(address) → uint256` — line 74 (`public view virtual` — the value SuperLedger consumes)
- `getTVLByOwnerOfShares(address, address ownerOfShares) → uint256` — lines 77-84
- `getTVL(address) → uint256` — line 87
- `getBalanceOfOwner(address, address) → uint256` — lines 144-151

Concrete (inherited):
- `getAssetOutputWithFees(bytes32 yieldSourceOracleId, address yieldSourceAddress, address assetOut, address user, uint256 usedShares)` — lines 90-126. Calls `getAssetOutput`, then `try config = SuperLedgerConfiguration.getYieldSourceOracleConfig(id)`; if `config.feePercent > 0 && config.ledger != 0` it fetches pps + decimals from the configured oracle and calls `ISuperLedger(config.ledger).previewFees(...)` (lines 112-114), then ADDS the fee to the output (line 117). Missing/invalid config falls through the catch to plain asset output (lines 122-125). This is the path debt oracles must neutralize (Morpho does; Euler does not).
- `getPricePerShareMultiple(address[])` — lines 128-141: plain loop, NO revert isolation.
- `getTVLByOwnerOfSharesMultiple(address[], address[][]) → (uint256[][] userTvls, bool[][] succeeded)` — lines 153-190: the ONLY batch method with try/catch isolation (external self-call per pair at line 180; revert records 0 + succeeded=false, lines 184-187).
- `getTVLMultiple(address[])` — lines 192-201: plain loop, no isolation.

Constructor: single `address superLedgerConfiguration_` stored as `immutable SUPER_LEDGER_CONFIGURATION` (lines 21, 29-31). Error `ARRAY_LENGTH_MISMATCH` (line 163).

## 2. EulerDebtOracle — the debt-oracle template

File: `src/accounting/oracles/EulerDebtOracle.sol` (104 lines).
- Constructor pass-through only (line 38).
- Identity PPS: `getPricePerShare` returns `10 ** decimals()` (lines 52-54); `getShareOutput`/`getWithdrawalShareOutput`/`getAssetOutput` are pure identity passthroughs (lines 57-69).
- `getBalanceOfOwner` = `debtOf(owner)` — asset units, not shares (lines 73-83); `getTVLByOwnerOfShares` identical (lines 87-97); `getTVL` = `totalBorrows()` (lines 101-103). `decimals` = vault `decimals()` (lines 45-47).
- NatSpec invariants (lines 17-36): feePercent = 0 operational invariant — no on-chain guard, both fee paths documented (inherited `getAssetOutputWithFees` AND `BaseLedger._processOutflow`); own-asset denomination, conversion external (lines 30-32); `debtOf` rounds UP / conservative (line 33); empty revert on non-contract yieldSource isolated by batch try/catch (lines 35-36).
- Euler does NOT override `getAssetOutputWithFees`; Morpho (later, post-security-review) DOES. Interview decision #5 says "match Euler/MorphoBlue precedent exactly" — the two differ on this point; the Morpho override is the security review's P2-1 recommendation and the newer precedent.
- Vendor interface: `src/vendor/euler/IEVaultDebt.sol` (17 lines: `decimals`, `debtOf`, `totalBorrows`).

## 3. MorphoBlue registry pattern (non-address-keyed markets)

Files: `src/accounting/oracles/MorphoBlueMarketRegistry.sol` (307 lines), `src/accounting/oracles/MorphoBlueDebtOracle.sol` (366 lines).

Registry:
- **Key derivation**: pseudo-address = `address(uint160(uint256(Id.unwrap(marketId))))` — lower 20 bytes of the 32-byte keccak market Id (NatSpec lines 16-22, code line 203, `computeMarketKey` pure preview at 285-305). Collision analysis in NatSpec (~2^-121 accidental; collision only blocks second registration, never overwrites).
- **Governance**: OZ `AccessControl`; `MARKET_MANAGER_ROLE = keccak256("MARKET_MANAGER_ROLE")` (line 77); constructor grants `DEFAULT_ADMIN_ROLE` + `MARKET_MANAGER_ROLE` to a single `admin_` (lines 139-143; deployed with `admin = DEPLOYER` per `DeployV2Core.s.sol:2637, 4765-4774`).
- **Registration** (`registerMarket`, lines 173-210): role-gated; validates loanToken ≠ 0, IRM whitelisted via `setIrmApproval` (lines 155-158, zero IRM exempt), market exists on the Morpho singleton (`idToMarketParams`, lines 199-200), key not already registered (line 205). The Morpho singleton address itself is caller-trusted, no whitelist (NatSpec lines 29-31).
- **Mutability**: add-only; deregistration is TIMELOCKED — propose/execute/cancel with `DEREGISTER_DELAY = 2 days` (lines 84, 220-254), with a heavily documented SAFETY INVARIANT (lines 33-40, 216-218, 230-237): never deregister with active Superform positions or the oracle bricks PPS reads and users can't withdraw through SuperLedger.
- **Resolution**: `getMarketInfo(marketKey) → (MarketParams, morpho)` reverts `MARKET_NOT_REGISTERED()` for unknown keys (lines 260-264); `isRegistered` view (269-271). Custom errors (lines 49-71).

Debt oracle specifics beyond Euler's shape:
- `immutable REGISTRY` with zero-address check in constructor (lines 116, 125-133, error `ZERO_ADDRESS` line 99).
- Overrides `getAssetOutputWithFees` to bypass fee math entirely (lines 215-228) — NatSpec notes it only protects the view path, not `BaseLedger._processOutflow`.
- `getBalanceOfOwner` returns raw borrowShares (232-245) while `getTVLByOwnerOfShares` returns accrued asset debt (249-262) — shares-based, unlike Euler/Aave. **Aave V4 is asset-based like Euler** (`getUserDebt` returns asset units) → AaveV4DebtOracle follows the Euler identity-PPS shape, not the Morpho accrual shape.
- Registry sharing: one registry serves both supply and debt oracles for the same key (NatSpec lines 44-47) — same model wanted for `AaveV4ReserveRegistry`.
- Monitoring extra: `getLastUpdate` view (lines 277-282, per security review P3-2).

For Aave V4 the analogous key: lower 20 bytes of `keccak256(abi.encode(spoke, reserveId))`, registration validating `spoke.getReserve(reserveId)` doesn't revert and optionally binding/storing `underlying` (mirroring the hooks' reserve→token binding).

## 4. ERC4626YieldSourceOracle — supply-side fee-capable template

File: `src/accounting/oracles/ERC4626YieldSourceOracle.sol` (107 lines). Pure passthroughs: `decimals` (21-23), `getShareOutput = previewDeposit` (26-37), `getWithdrawalShareOutput = previewWithdraw` (40-51), `getAssetOutput = previewRedeem` (54-65), `getPricePerShare = convertToAssets(10**decimals)` (68-72), `getBalanceOfOwner = balanceOf` (75-85), `getTVLByOwnerOfShares = convertToAssets(balanceOf)` with zero-shares short-circuit (88-101), `getTVL = totalAssets()` (104-106). Does NOT override `getAssetOutputWithFees` — the inherited fee-capable version is the point. No cost-basis logic in the oracle; snapshots/fees live in the ledger.

For `AaveV4SupplyYieldSourceOracle`: `getUserSuppliedAssets` returns asset units directly → identity PPS (like Euler) but with the inherited fee-capable `getAssetOutputWithFees` retained (unlike the debt oracle). `getBalanceOfOwner`/`getTVLByOwnerOfShares` = `getUserSuppliedAssets(reserveId, owner)`. **TVL: the minimal `IAaveV4Spoke` exposes no aggregate supply getter — vendor-interface addition is an open item.**

## 5. IAaveV4Spoke vendor interface

File: `src/vendor/aave-v4/IAaveV4Spoke.sol` (101 lines; every money function returns `(shares, assets)` — NatSpec lines 10-11).
- `Reserve` struct (lines 24-32): `address underlying; address hub; uint16 assetId; uint8 decimals; uint24 collateralRisk; uint8 flags; uint32 dynamicConfigKey;` — `decimals` available directly on the reserve.
- `supply(uint256 reserveId, uint256 amount, address onBehalfOf) → (uint256, uint256)` — line 41
- `withdraw(reserveId, amount, onBehalfOf) → (shares, assets)` — line 51 (max sentinel = full withdrawal, lines 44-45)
- `borrow(...)` — line 59; `repay(...)` — line 70 (amount > debt = full repayment, lines 63-64)
- `setUsingAsCollateral(reserveId, bool, onBehalfOf)` — line 79 (V4 does not auto-enable collateral)
- `getReserve(uint256 reserveId) → Reserve` — line 85, reverts if reserve not listed (line 82)
- `getUserDebt(uint256 reserveId, address user) → (uint256 drawnDebt, uint256 premiumDebt)` — line 93; total = drawn + premium (line 88)
- `getUserSuppliedAssets(uint256 reserveId, address user) → uint256` — line 99

## 6. BaseAaveV4LoanHookV2 — how hooks read state

File: `src/hooks/loan/aave-v4/BaseAaveV4LoanHookV2.sol` (229 lines).
- `_totalDebt(vars, account)` (177-180): `spoke.getUserDebt(borrowReserveId, account)` → `drawn + premium` — exactly what the debt oracle's `getBalanceOfOwner` should return.
- `_suppliedAssets(vars, account)` (183-185): `spoke.getUserSuppliedAssets(supplyReserveId, account)` — the supply oracle's `getBalanceOfOwner`.
- Reserve→token binding: `_validateReserves` (166-174) — `getReserve(id).underlying` must equal declared token else `TOKEN_RESERVE_MISMATCH` (line 74). Registry should perform the same binding check at registration.
- Spoke is calldata-parameterized; one deployment serves any spoke — mirrored by "one oracle + registry serves any (spoke, reserveId)".

## 7. SuperLedger / SuperLedgerConfiguration consumption

- `src/accounting/BaseLedger.sol`:
  - `_updateAccounting` (262-304) is the entry point: loads config by `yieldSourceOracleId` (275-276), then `getPricePerShare(yieldSource)` at line 282 — reverts `INVALID_PRICE` if pps == 0 (identity PPS never zero). Inflow → `_takeSnapshot` with pps + oracle decimals (285-294; snapshot math 130-142: `costBasis += shares * pps / 10^decimals`). Outflow → `decimals()` (296), `_processOutflow` (198-222) → `_calculateCostBasis` + fee from `config.feePercent` directly via `_calculateFees` (219-221, 232-247: `profit = amountAssets - costBasis`, fee = `profit * feePercent / 10_000`). This is the un-guarded ledger fee path — with no snapshots, costBasis = 0 and the whole debt reads as profit.
  - `previewFees` (94-116) is what `getAssetOutputWithFees` calls back into.
  - Oracle `getBalanceOfOwner`/`getTVL*` have no on-chain consumers in v2-core outside the oracles themselves — periphery/monitoring/off-chain surface; on-chain-critical surface is `getPricePerShare` + `decimals`.
- `src/executors/SuperExecutorBase.sol:188-211` — `_updateAccounting` extracts `yieldSourceOracleId` + `yieldSource` from hook data → oracle id + yieldSource key (registry pseudo-address for Aave V4) flow in via hook data.
- `src/accounting/SuperLedgerConfiguration.sol`:
  - Permissionless `setYieldSourceOracles(salts, configs)` (63-82); id = `_deriveWithSender(salt, msg.sender)` (289, 326) — manager-scoped ids, two-step manager transfer, proposal + 1-week timelock for changes (84-120).
  - Fee bounds: `MAX_FEE_PERCENT = 5000`, `MAX_FEE_PERCENT_CHANGE = 5000`, `MAX_INITIAL_FEE_PERCENT = 2500` (43-53). **feePercent = 0 is a valid initial config and 0→0 changes bypass validation** — debt-oracle invariant enforceable only by ops discipline.
- Salt convention: `script/utils/Constants.sol:388+` — e.g. `"ERC4626YieldSourceOracle_v1.0.1"` string salts per oracle.

## 8. Deployment conventions (precedent commit e58a82b5)

Commit `e58a82b5` ("chore: record deployed Euler/MorphoBlue debt oracles (salvaged from #983) (#992)", 2026-08-31):
- Bytecode twins: `script/generated-bytecode/{EulerDebtOracle,MorphoBlueDebtOracle}.json`, `script/locked-bytecode-dev/{...}.json`; `script/locked-bytecode/` got only `EulerDebtOracle.json` — MorphoBlue registry/oracle absent from prod locked-bytecode; prod deploy of registry-dependent oracles guarded by `__checkBytecodeExists` (`DeployV2Core.s.sol:2645, 4767, 4865-4872`) and skipped when missing.
- Regeneration: `script/run/tooling/regenerate_bytecode.sh` — `ORACLE_CONTRACTS` array (~193-215) ends with `"EulerDebtOracle"`, `"MorphoBlueDebtOracle"`; new oracles appended here. Artifact freshness is the Review-R1 (PR #990) hazard.
- Deploy script: `script/DeployV2Core.s.sol` — oracle name array slots (741-746: registry `[14]`, EulerDebtOracle `[18]`, MorphoBlueDebtOracle `[19]`); registry deployed first as dependency with `abi.encode(DEPLOYER)` (4765-4774); oracles via `_createSafeOracleDeploymentWithArgs(KEY, name, env, abi.encode(superLedgerConfig[, registry]))` (4860-4872); verification-record entries 3467-3505, constructor-arg matching 3540-3572.
- Keys: `script/utils/Constants.sol:380, 384-385`.
- Outputs: one-line additions to `script/output/prod/<chainId>/<Chain>-latest.json` for 17 prod + 8 staging chains, plus `test/script/DeployV2CoreVerificationRecords.t.sol`.
- Ledger config plumbing: `script/run/config/add_to_super_ledger_staging_prod.sh` (+ `extract_configurable_oracles.sh` list) and `config_v2_ledger_staging_prod.sh` (per-chain filtering).
- Spec-format precedent: `specs/deth-oracle/`, `specs/ERC7540Oracle/`, `specs/morpho-blue-market-oracle/` each contain `interview-notes.md`, `spec.md`, `technical-spec.md`, `research/{repo-analysis,best-practices,evm-security}.md` (morpho adds `launch-checklist.md`).

## 9. Test conventions

- Debt oracle unit tests (added in e58a82b5): `test/unit/accounting/oracles/EulerDebtOracle.t.sol` (725 lines), `MorphoBlueDebtOracle.t.sol` (792 lines). Conventions: plain `forge-std/Test`, `vm.mockCall` on `makeAddr` vaults for Euler (setUp 42-58), real `SuperLedgerConfiguration` + real registry deployment for Morpho (setUp 54-61, `vm.warp(365 days * 2)`); a `MockZeroCostBasisLedger` (EulerDebtOracle.t.sol 13-31) modeling the "entire debt = profit" fee hazard; section banners; 6- and 18-decimal coverage.
- AaveV4 mock spoke: `test/unit/hooks/loan/AaveV4LoanHooksV2.t.sol:29-89` — `MockAaveV4SpokeV2` with `setReserveUnderlying` (39), `setUserDebt(reserveId, user, drawn, premium)` (43-46), `setUserSuppliedAssets` (48-50), view surface (56-66). Directly reusable.
- Fork tests: `test/integration/AaveV4V2HooksFork.t.sol` extends `MinimalBaseIntegrationTest` — forks **Ethereum mainnet**, not Base: `SPOKE_ADDR = 0x94e7A5dCbE816e498b89aB752661904E2F56c485` (line 42), `WETH_RESERVE_ID = 0`, `USDC_RESERVE_ID = 7`, pinned `AAVE_V4_BLOCK = 24_884_274` (`test/utils/Constants.sol:287`), RPC key `"ETHEREUM_RPC_URL"`. For Base fork tests: `BASE_RPC_URL_KEY = "BASE_RPC_URL"` (`test/utils/Constants.sol:47`), multi-fork helpers `test/BaseTest.t.sol:345, 1360-1370`; a Base spoke address + pinned block would be NEW constants (none exist yet).
- Oracle test homes: `test/unit/accounting/oracles/` (newer — use this), `test/unit/accounting/AbstractYieldSourceOracleTest.t.sol` (batch behavior), `test/integration/oracles/`.

## 10. 2026-08-17 MorphoBlueDebtOracle security report as precedent

File: `specs/security-reports/2026-08-17-morpho-blue-debt-oracle.md` (3-agent review, PASS, 0 P0/P1, 3 P2, 7 P3). Reusable decisions:
- **P2-1** (feePercent misconfiguration): override `getAssetOutputWithFees` to bypass fees → implemented in MorphoBlueDebtOracle (215-228); explicitly notes EulerDebtOracle has the same gap, un-fixed. Safest precedent-consistent move for AaveV4: Morpho override + Euler NatSpec block.
- **P2-2** (external-dependency revert DoS): accepted with registry whitelist mitigation — Aave analog: bricked/paused spoke reverts the oracle; batch try/catch is the containment.
- **P2-3 / P3-5**: accepted conservative divergences, each documented in NatSpec — bar: every semantic deviation gets a NatSpec paragraph + report entry.
- **P3-2**: monitoring staleness view (`getLastUpdate`) — Aave V4 accrues on read, likely N/A.
- Cross-oracle consistency + coding-standards tables (locked pragma 0.8.30, custom errors, `@inheritdoc`, grouped imports, immutable refs, trailing-underscore ctor params) — house style checklist.

---

## Conventions checklist for the new oracles

1. **Files**: `src/accounting/oracles/AaveV4DebtOracle.sol`, `AaveV4SupplyYieldSourceOracle.sol`, `AaveV4ReserveRegistry.sol`; pragma 0.8.30, Apache-2.0, custom errors, `@inheritdoc`, grouped imports.
2. **Debt oracle shape = Euler** (asset-denominated): identity PPS, pure identity converters, `getBalanceOfOwner = getTVLByOwnerOfShares = drawn + premium` (matches `BaseAaveV4LoanHookV2._totalDebt`), plus **Morpho-style `getAssetOutputWithFees` override** and the full Euler NatSpec fee-invariant block. Supply oracle: same identity shape, fee-capable (no override), `getBalanceOfOwner = getUserSuppliedAssets`; **TVL source open** (minimal spoke interface lacks aggregate getter — extend `IAaveV4Spoke` after Joao call).
3. **Registry = MorphoBlueMarketRegistry model**: AccessControl + MARKET_MANAGER_ROLE, admin ctor, pseudo-address key from lower-20-bytes of `keccak256(abi.encode(spoke, reserveId))` with `computeKey` preview, registration validates `getReserve(reserveId)` non-revert + underlying binding, `MARKET_NOT_REGISTERED`, add-only + 2-day timelocked deregistration with SAFETY INVARIANT NatSpec, `isRegistered`, shared by both oracles. No IRM-whitelist analog needed.
4. **Constructors**: oracles `(superLedgerConfiguration, registry)` with ZERO_ADDRESS check + immutable REGISTRY; registry `(admin)`.
5. **decimals()**: from `getReserve(reserveId).decimals` (uint8 on Reserve struct).
6. **Deployment**: append to `regenerate_bytecode.sh` ORACLE_CONTRACTS; commit generated + locked-bytecode-dev twins (prod locked only when locking, `__checkBytecodeExists` guard); `*_KEY` constants + versioned salt; registry-first deploy wiring + verification records in `DeployV2Core.s.sol`; per-chain output JSONs + `DeployV2CoreVerificationRecords.t.sol`; ledger registration with **feePercent = 0 for the debt oracle id** in the runbook.
7. **Tests**: unit suites in `test/unit/accounting/oracles/` at the ~700-line Euler/Morpho bar (reuse `MockAaveV4SpokeV2`; `MockZeroCostBasisLedger`-style fee-hazard test; 6/18-decimal reserves); fork tests pinned-block against the live spoke — Ethereum constants exist, Base needs new spoke/block constants.
8. **Docs**: security-review report at `specs/security-reports/<date>-aave-v4-oracles.md`; spec dir per `specs/morpho-blue-market-oracle/` layout; every semantic divergence gets NatSpec + report entry.
