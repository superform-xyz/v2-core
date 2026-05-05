# Session 8: ERC7540YieldSourceOracle Implementation

## Overview
Implementing the ERC7540YieldSourceOracle per `specs/ERC7540Oracle/technical-spec.md`.

## Plan

### Phase 1: Oracle Contract
- Create `src/accounting/oracles/ERC7540YieldSourceOracle.sol`
- 7 abstract method implementations + `getAsyncStateBreakdown()`
- Constructor with `superLedgerConfiguration_` and `requestId_`

### Phase 2: Mock Vault
- Create `test/mocks/MockERC7540VaultFull.sol` — comprehensive mock with settable state
- Separate ERC-20 share token, all 5 async components configurable

### Phase 3: Unit Tests
- Create `test/unit/accounting/ERC7540YieldSourceOracle.t.sol`
- All 8 public methods + error handling + edge cases + fuzz

### Phase 4: Integration
- Verify `forge build` passes
- Run tests

## Key Design Decisions
- D1: `maxWithdraw(controller)` for claimable redeem (Centrifuge locked redeemPrice)
- D2: `REQUEST_ID` as immutable constructor param (default 0)
- D3: Hybrid R1/R2 error handling
- D5: `convertToAssets` excludes fees (bounded 0-0.5%)
- Yo vaults keep existing `YoYieldSourceOracle` (different function selector)
- Uses `convertToShares` not `previewDeposit` for `getShareOutput`

## Key Reference Files
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` — base class
- `src/accounting/oracles/YoYieldSourceOracle.sol` — reference (has pending tracking)
- `src/accounting/oracles/SuperVaultYieldSourceOracle.sol` — manual inverse pattern
- `src/vendor/vaults/7540/IERC7540.sol` — vendor interface
- `test/unit/accounting/YieldSourceOracles.t.sol` — existing test patterns

## Changes Made

### Files Created
1. `src/accounting/oracles/ERC7540YieldSourceOracle.sol` — Production oracle
   - Extends `AbstractYieldSourceOracle`, constructor takes `(superLedgerConfiguration_, requestId_)`
   - `REQUEST_ID` as immutable (default 0)
   - `decimals()` → `share().decimals()` (ERC-7575)
   - `getShareOutput()` → `convertToShares()` (not previewDeposit)
   - `getWithdrawalShareOutput()` → manual inverse with `Math.mulDiv(..., Ceil)`
   - `getAssetOutput()` → `convertToAssets()` (not previewRedeem)
   - `getPricePerShare()` → `convertToAssets(10^decimals)` — R1 hard revert
   - `getBalanceOfOwner()` → `IERC20(share).balanceOf(owner)`
   - `getTVLByOwnerOfShares()` → sum of 5 components via `getAsyncStateBreakdown()` — R2 try/catch
   - `getTVL()` → `totalAssets()`
   - `getAsyncStateBreakdown()` → returns 5 individual uint256 components

2. `test/mocks/MockERC7540VaultFull.sol` — Comprehensive mock
   - Separate share token (MockERC20)
   - Configurable exchange rate, per-controller state for all 5 components
   - Revert flags for each async function (R2 testing)

3. `test/unit/accounting/ERC7540YieldSourceOracle.t.sol` — 50 unit tests
   - Constructor, decimals, getShareOutput, getWithdrawalShareOutput, getAssetOutput
   - getPricePerShare, getBalanceOfOwner, getTVL
   - getAsyncStateBreakdown (all permutations)
   - getTVLByOwnerOfShares (sum correctness)
   - R1 hard revert tests, R2 graceful degradation tests (all 4 async components)
   - Edge cases (zero balances, different owners, 6-decimal vaults)
   - Fuzz tests (overflow safety, PPS rates, withdrawal inverse)

### Test Results (Phase 3: Unit Tests)
- 50/50 tests passed
- All fuzz tests passed
- Build successful (no errors)

### Phase 4: Additional Fuzz + Invariant Tests

#### Files Modified
1. `test/unit/accounting/ERC7540YieldSourceOracle.t.sol` — Added 8 fuzz tests:
   - `testFuzz_getShareOutput_variousRates` — share conversion with random rates
   - `testFuzz_getAssetOutput_variousRates` — asset conversion with random rates
   - `testFuzz_roundTrip_assetToShareToAsset` — floor rounding preserves assetsBack <= assetsIn
   - `testFuzz_getWithdrawalShareOutput_ceilFavorsVault` — ceil rounding guarantees vault gets more
   - `testFuzz_INV5_claimableRedeemValue_equalsMaxWithdraw` — INV-5 property
   - `testFuzz_INV7_gracefulDegradation_neverReverts` — R2 with random revert flags
   - `testFuzz_INV1_TVL_gte_maxWithdraw` — TVL always >= maxWithdraw
   - `testFuzz_componentSum_equals_TVL` — 5 components sum to TVL with exchange rate

2. `test/mocks/MockERC7540VaultFull.sol` — Added `burnShares(address, uint256)` helper

#### Files Created
3. `test/invariant/ERC7540OracleInvariant.t.sol` — Invariant test suite with:
   - `ERC7540LifecycleHandler`: 7 lifecycle operations (requestDeposit, fulfillDeposit, claimDeposit, requestRedeem, fulfillRedeem, claimRedeem, setExchangeRate) + ghost variables tracking state per actor (3 actors)
   - `invariant_TVL_gte_maxWithdraw` — INV-1
   - `invariant_claimableRedeemValue_equals_maxWithdraw` — INV-5
   - `invariant_componentSum_equals_TVL` — components sum to TVL
   - `invariant_TVL_neverReverts` — INV-7
   - `invariant_ghost_pendingDeposit_consistent` — INV-4 ghost
   - `invariant_ghost_claimableDeposit_consistent` — INV-4 ghost
   - `invariant_ghost_maxWithdraw_consistent` — INV-4 ghost
   - `invariant_breakdown_neverReverts` — getAsyncStateBreakdown never reverts
   - `invariant_pricePerShare_neverReverts` — getPricePerShare never reverts

#### Test Results (Phase 4)
- 58/58 unit + fuzz tests passed
- 9/9 invariant tests passed (256 runs each, 128,000 calls per invariant, 0 reverts)
- Build successful (no errors)

### Phase 5: 3-Layer Test Suite Expansion

#### Layer 1: Unit Tests (12 new tests added to existing file)

**File Modified:** `test/unit/accounting/ERC7540YieldSourceOracle.t.sol`

New tests added:
- **Batch methods:** `test_getPricePerShareMultiple_singleVault`, `test_getPricePerShareMultiple_multipleVaults`, `test_getTVLByOwnerOfSharesMultiple_singleOwner`, `test_getTVLByOwnerOfSharesMultiple_arrayLengthMismatch_reverts`, `test_getTVLMultiple_multipleVaults`
- **getAssetOutputWithFees:** `test_getAssetOutputWithFees_noConfigured` (try/catch fallback returns base output), `test_getAssetOutputWithFees_withFees` (configured with MockSuperLedger, returns base + fee)
- **Zero-decimal:** `test_decimals_zeroDecimalVault`, `test_getPricePerShare_zeroDecimalVault`
- **REQUEST_ID routing:** `test_getAsyncStateBreakdown_usesRequestId` (oracle42 + enforceRequestId mock), `test_getAsyncStateBreakdown_wrongRequestId_gracefulDegradation` (wrong ID caught by try/catch)
- **Try/catch subtlety:** `test_getTVLByOwnerOfShares_convertToAssetsRevert_insideTrySuccess_propagates` (convertToAssets inside try-success block propagates revert)

**Mock Modified:** `test/mocks/MockERC7540VaultFull.sol` — added `enforceRequestId`, `expectedRequestId`, `setEnforceRequestId(bool, uint256)` for REQUEST_ID validation

**Helper Created:** `MockSuperLedger` contract at bottom of test file — returns fixed fee from `previewFees`

**Total: 70 tests (58 existing + 12 new), all passing**

#### Layer 2: Invariant Tests (full rewrite with 3 handlers, 8 invariants)

**File Rewritten:** `test/invariant/ERC7540OracleInvariant.t.sol`

**3 Handlers:**
1. `VanillaLifecycleHandler` — 18-decimal vault, 7 ops (requestDeposit, fulfillDeposit, claimDeposit, requestRedeem, fulfillRedeem, claimRedeem, setExchangeRate). setExchangeRate recomputes ghost_totalAssets from all 5 components across all actors.
2. `CentrifugeLifecycleHandler` — 6-decimal vault, fulfillRedeem takes epochRate parameter (bounded [0.8e6, 1.2e6]). Adjusts ghost_totalAssets when epochRate differs from vault rate.
3. `DegradedLifecycleHandler` — 18-decimal vault, same ops + `toggleRevertFlag(uint8)` for 4 async revert flags. Never toggles convertToAssets/convertToShares.

**8 Invariants:**
1. `invariant_INV1_TVL_lowerBound` — TVL >= maxWithdraw for all actors (skips degraded when flag set)
2. `invariant_INV2_noOverAttribution` — sum(userTVL) <= getTVL + tolerance (1 wei per actor for floor rounding)
3. `invariant_INV3_stateTransitionPreservation` — recomputed component sum ≈ ghost_totalAssets (within 10000 wei)
4. `invariant_INV4_mutualExclusivity` — oracle components match ghost state (pendingDeposit, claimableDeposit, maxWithdraw)
5. `invariant_INV5_claimableEqualsMaxWithdraw` — claimableRedeemValue == maxWithdraw exactly
6. `invariant_INV6_decimalCorrectness` — decimals match share token AND PPS == convertToAssets(10^dec)
7. `invariant_INV7_gracefulDegradation` — getTVLByOwnerOfShares never reverts on degraded vault
8. `invariant_INV8_PPSConsistency` — getPricePerShare == convertToAssets(10^decimals) for all 3 vaults

**Total: 8/8 invariants passing (256 runs each, ~500 calls per run)**

#### Layer 3: Integration Tests (rewritten for multi-decimal coverage)

**File Rewritten:** `test/integration/accounting/ERC7540OracleIntegration.t.sol`

**Important Discovery:** The live Centrifuge USDC vault at `0x1d01Ef...` (block 21,929,476) does NOT implement ERC-7575 `share()` — the selector is not present in its bytecode. This means our oracle (which requires `share()`) cannot be tested against that vault directly. Centrifuge v3 AsyncVault (which implements `share()`) was not deployed until after that block. Lagoon Finance vaults are ERC-4626, not ERC-7540.

**Solution:** Use `MockERC7540VaultFull` configured with realistic parameters:
- Centrifuge vault: 6-dec, PPS=1.054230 (from live vault's `convertToAssets(1e6)` at block 21,929,476)
- 18-dec vault: WETH-like, PPS=1.1
- 8-dec vault: WBTC-like, PPS=1.00125
- 6-dec vault: 1:1 rate (fresh)

**4 Vault Configurations, 40 Tests:**

Centrifuge-realistic (10 tests):
- `test_centrifuge_decimals`, `test_centrifuge_getPricePerShare`, `test_centrifuge_getShareOutput`
- `test_centrifuge_getAssetOutput`, `test_centrifuge_getWithdrawalShareOutput_ceilRounding`
- `test_centrifuge_getTVL`, `test_centrifuge_getBalanceOfOwner`
- `test_centrifuge_fullLifecycle` (all 5 components)
- `test_centrifuge_breakdown_heldOnly`
- `test_centrifuge_getPricePerShareMultiple`

18-decimal / 8-decimal / 6-decimal:
- Same pattern: decimals, PPS, share output, asset output, ceil rounding, TVL, balance, lifecycle
- Plus graceful degradation tests for 18-dec and 8-dec
- Exchange rate change tests

Cross-decimal batch tests (3 tests):
- `test_batch_getPricePerShareMultiple_multiDecimal` — 4 vaults
- `test_batch_getTVLMultiple_multiDecimal` — 4 vaults
- `test_batch_getTVLByOwnerOfSharesMultiple_multiDecimal` — 3 vaults, 2 users

**Total: 40/40 tests passing**

#### Final Test Counts (Phase 5)
- Layer 1 Unit: 70 passing
- Layer 2 Invariant: 8 invariants passing (256 runs each)
- Layer 3 Integration: 40 passing (4 vault configs: centrifuge 6-dec, generic 6-dec, 18-dec, 8-dec)
- Build: clean (compiler warnings only on existing view mutability)

### Phase 6: `_getShareToken` Fallback + Live Centrifuge Fork Tests

#### Problem
The original oracle called `vault.share()` directly, which reverts on ERC-4626-style vaults where the vault IS the share token (no separate share token, no `share()` function). Some older Centrifuge vaults (v2) don't implement `share()`.

#### Solution: `_getShareToken()` fallback
Added internal helper `_getShareToken(address yieldSourceAddress)` that:
1. Tries `IERC7540(yieldSourceAddress).share()` via try/catch
2. Falls back to `yieldSourceAddress` itself if `share()` reverts

Updated all 5 call sites in the oracle that previously called `vault.share()` directly:
- `decimals()`, `getWithdrawalShareOutput()`, `getPricePerShare()`, `getBalanceOfOwner()`, `getAsyncStateBreakdown()`

#### Live Centrifuge v3 Vault Discovery
Found two active Centrifuge v3 vaults on Ethereum mainnet that implement ERC-7575 `share()`:
- **JTRSY USDC:** `0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A`
  - Tranche token: `0x8c213ee79581Ff4984583C6a801e5263418C4b86` (6-dec)
  - PPS ~1.10 USDC/share
  - TVL ~$1.27B
- **JAAA USDC:** `0x4880799eE5200fC58DA299e965df644fBf46780B`
  - Tranche token: `0x5a0F93D040De44e78F251b03c43be9CF317Dcf64` (6-dec)
  - PPS ~1.03 USDC/share
  - TVL ~$145M

Key discovery: `share()` works natively in Foundry's EVM (via `cast call`), so fork tests need NO `vm.mockCall` for core view functions.

#### Files Modified
1. **`src/accounting/oracles/ERC7540YieldSourceOracle.sol`** — Added `_getShareToken()` internal helper, updated 5 call sites
2. **`test/unit/accounting/ERC7540YieldSourceOracle.t.sol`** — Added 3 unit tests + `MockERC4626NoShare` contract:
   - `test_getShareToken_usesShareWhenAvailable` — verifies share() path
   - `test_getShareToken_fallbackToVaultAddress` — verifies fallback on vault without share()
   - `test_getShareToken_fallback_fullLifecycle` — full 5-component TVL with fallback vault
3. **`test/integration/accounting/ERC7540OracleIntegration.t.sol`** — Added `ERC7540OracleForkTest` contract (22 tests):
   - JTRSY vault: decimals, PPS, share output, asset output, ceil rounding, TVL, balance, breakdown, TVLByOwner (9 tests)
   - JAAA vault: decimals, PPS, share output, asset output, TVL, balance, TVLByOwner (7 tests)
   - Cross-vault batch: PPS multiple, TVL multiple, TVLByOwner multiple (3 tests)
   - Share token discovery validation (2 tests)
   - testUser getter (1 auto-generated)

#### Phase 6b: Fork Test Hardening — Pinned Block + Real Depositors

**Problem:** Original fork tests used unpinned block and `deal()`-created test users. No verification against real on-chain depositor state.

**Solution:** Complete rewrite of `ERC7540OracleForkTest` with:

1. **Pinned to block 24,990,000** — all expected values verified via `cast call`
2. **Exact expected value constants:**
   - JTRSY PPS = 1,101,748, shares/USDC = 907,647, totalAssets = 1,269,351,955,129,173
   - JAAA PPS = 1,031,939, shares/USDC = 969,049, totalAssets = 145,504,012,015,214
3. **Real depositor verification** (found via Transfer event logs on tranche tokens):
   - `0x86b4...` — JAAA large holder: 921,979,703,126 shares → 951,427,200,346 assets
   - `0x0401...` — JAAA small holder: 2,911,134,480 shares
   - `0xfd47...` — JAAA redeeming holder: 0 balance BUT pendingRedeemRequest = 2,911,134,477 shares (→ 3,004,114,424 assets)
4. **35 tests covering:**
   - Share token discovery (both vaults)
   - JTRSY exact values (9 tests)
   - JAAA exact values (7 tests)
   - Real depositor verification (6 tests) — including async pendingRedeem state
   - Cross-vault batch operations (4 tests)
   - Cross-validation oracle-vs-direct vault calls (3 tests)

**Key discovery:** `0xfd47...` has non-zero `pendingRedeemRequest` with 0 share balance — proves the oracle correctly values users mid-redemption.

#### Final Test Counts (Phase 6b)
- Layer 1 Unit: 73 passing (70 + 3 fallback tests)
- Layer 2 Invariant: 8 invariants passing (256 runs each)
- Layer 3 Integration (mock): 40 passing
- Layer 3 Integration (fork): 35 passing (pinned block 24,990,000, real depositors, exact values)
- **Total: 156 tests, all passing**
- Build: clean (compiler warnings only)

### Phase 7: Oracle Compatibility Analyzer — Next.js Tool

#### Overview
Created a Next.js web app at `v2-monitoring/oracle-analyzer/` that probes any vault on-chain via `eth_call` to determine which Superform oracle (ERC-4626, ERC-7540, ERC-5115) is compatible.

#### Files Created
```
v2-monitoring/oracle-analyzer/
├── app/
│   ├── globals.css          — Tailwind + dark theme styles
│   ├── layout.tsx           — Root layout with metadata
│   ├── page.tsx             — Main page: form + results
│   └── api/analyze/route.ts — POST endpoint: on-chain probing + verdicts
├── lib/
│   ├── types.ts             — TypeScript interfaces + chain configs
│   ├── oracles.ts           — Oracle addresses + compatibility rules
│   └── probes.ts            — Function selector probing via ethers.js v6
├── components/
│   ├── AnalyzerForm.tsx     — Chain dropdown + vault address + oracle filter
│   ├── VaultInfo.tsx        — Vault metadata card
│   ├── CapabilityMatrix.tsx — Green/red grid showing function support
│   └── OracleVerdict.tsx    — COMPATIBLE/PARTIAL/INCOMPATIBLE verdict cards
├── package.json             — Next.js 14 + ethers 6 + Tailwind
├── tsconfig.json            — ES2020 target for BigInt support
├── tailwind.config.ts       — Dark theme matching v2-monitoring dashboard
├── postcss.config.js
├── next.config.js           — Standalone output
├── .env.example             — RPC URL env vars template
└── .gitignore
```

#### Key Design
- **Probing**: Calls 20+ function selectors (ERC-20, ERC-4626, ERC-7575, ERC-7540, ERC-5115) + EIP-1967 proxy storage slots
- **Verdict logic**: Each oracle defines required/optional functions and an `evaluate()` function that returns COMPATIBLE/PARTIAL/INCOMPATIBLE with caveats
- **Caveats**: Auto-detects async behavior, proxy upgradability, missing state tracking, suggests better oracle
- **UI**: Dark theme (same CSS variables as v2-monitoring dashboard), single-page with form + 3 result sections
- **Build**: `npm run build` succeeds cleanly

### Phase 8: FirelightYieldSourceOracle

#### Problem
SuperVault uses `getTVLByOwnerOfShares(firelightVault, superVaultAddress)` to calculate total assets. After `redeem()`, shares are burned and the ERC4626 oracle returns TVL=0 during the ~2 day cooldown, causing artificial PPS drops.

#### On-Chain Research (Firelight vault at 0x4C18Ff3C89632c3Dd62E796c0aFA5c07c4c1B2b3)
- `currentPeriod()` = 149 (at time of research)
- `redeem()` places withdrawals into `currentPeriod + 1` (confirmed via fork test)
- Multiple redeems in same period **accumulate** (1M + 2M shares = 3000214 assets in period 150)
- `pendingWithdrawAssets()` exists (global vault total)
- PPS ~1.000071 (convertToAssets(1e6) = 1000071)
- 6 decimals

#### Key Design Decision: LOOKBACK_PERIODS
- Constructor parameter (immutable) controlling how many past periods to check for unclaimed withdrawals
- Optimized loop: checks `withdrawalsOf` first, only calls `isWithdrawClaimed` if amount > 0
- Gas costs (warm storage): lookback=2 → 10k gas, lookback=50 → 70k gas, lookback=100 → 133k gas
- Default 50 recommended (covers ~100 days of keeper delay)

#### Files Created
1. **`src/accounting/oracles/FirelightYieldSourceOracle.sol`** — Production oracle
   - Extends `AbstractYieldSourceOracle`, constructor takes `(superLedgerConfiguration_, lookbackPeriods_)`
   - `LOOKBACK_PERIODS` as immutable
   - Uses `convertToShares`/`convertToAssets` (not preview functions — safe for async)
   - `getWithdrawalShareOutput` → manual inverse with `Math.mulDiv(..., Ceil)` (same as ERC7540 oracle)
   - `getTVLByOwnerOfShares` → heldValue + `_getPendingWithdrawalValue(vault, owner)`
   - `_getPendingWithdrawalValue` loops from `max(0, currentPeriod - LOOKBACK_PERIODS)` to `currentPeriod + 1`

2. **`src/vendor/vaults/firelight/IFirelightVault.sol`** — Extended interface
   - Added: `currentPeriod()`, `withdrawalsOf()`, `isWithdrawClaimed()`, `convertToAssets()`, `convertToShares()`, `totalAssets()`, `decimals()`, `balanceOf()`

3. **`test/unit/accounting/FirelightYieldSourceOracle.t.sol`** — 36 unit + fuzz tests
   - Basic oracle functions, ceil rounding, zero assetsPerShare edge case
   - TVL with no pending, pending in next period, claimable in current period
   - Claimed period exclusion, lookback boundary, beyond lookback exclusion
   - Underflow safety (currentPeriod < LOOKBACK_PERIODS, currentPeriod = 0)
   - Multiple users, redeem simulation (TVL preserved before/after redeem)
   - Batch methods, 18-decimal vault, zero lookback oracle
   - 4 fuzz tests: round-trip, ceil favors vault, no negative TVL, redeem preserves TVL

#### Test Results
- 36/36 tests passing
- Build: clean

### Phase 8b: Firelight Oracle Hardening — MAX_LOOKBACK + Comprehensive Fork Tests

#### Oracle Changes
- Removed constructor `lookbackPeriods_` parameter — replaced with `MAX_LOOKBACK = 1000` constant
- Rationale: covers ~2000 days (~5.5 years) at ~2 days per period. Gas: ~1.34M at 1000 periods (view function, off-chain only)
- Simplified to scan from `max(0, currentPeriod - MAX_LOOKBACK)` through `currentPeriod + 1`

#### Unit Tests Updated
- `test/unit/accounting/FirelightYieldSourceOracle.t.sol` — updated for MAX_LOOKBACK constant
- **62/62 tests passing**

#### Fork Integration Tests (comprehensive lifecycle comparison)
- `test/integration/firelight/FirelightOracleFork.t.sol` — 31 tests against real Firelight vault on Flare
- Uses `vm.envString("FLARE_RPC_URL")` (QuikNode, not public RPC which rate-limits)
- 9 test sections:
  1. Oracle PPS vs Vault PPS (initial, after redeem, large/full redeem, after deposit, multiple redeems)
  2. Conversion consistency (share/asset, withdrawal ceil, round-trip)
  3. TVL at every lifecycle stage (initial, deposit, partial/full redeem, multiple redeems, two users)
  4. Global TVL consistency, PPS-totalAssets relationship
  5. Full lifecycle (deposit → partial redeem → full redeem)
  6. Pending withdrawal tracking deep dive
  7. Cross-validation table
  8. Batch methods
  9. Edge cases
- Key findings: PPS always identical (1000071), TVL preserved within 1 wei after redeem
- Deposit tests gracefully skip (vault at deposit cap, maxDeposit=739923)
- **31/31 fork tests passing**

### Phase 9: SuperSponsorshipPaymaster Role Transfer Scripts

#### Solidity Script
**File Created:** `script/TransferSuperSponsorshipPaymasterRoles.s.sol`
- Extends `DeployV2Base`
- Role mapping:
  - `FUNDING_ROLE` → GOVERNOR (`0x9e01f41da2212C1FBc32A041CfAEF72479FA48eC`)
  - `DEFAULT_ADMIN_ROLE` → SUPER_GOVERNOR (`0x89226a5Fd572f380991Bb17c20c96ba91F98aD2e`)
  - `MANAGER_ROLE` → SUPER_GOVERNOR (`0x89226a5Fd572f380991Bb17c20c96ba91F98aD2e`)
- Revoke order: FUNDING first, MANAGER second, ADMIN last (most privileged)
- `run(uint256 env, address paymasterAddr)` — grants + revokes (idempotent, skips if fully transferred)
- `runCheck(uint256 env, address paymasterAddr)` — read-only status check
- Helpers: `_logRoleStatus()`, `_isFullyTransferred()`

#### Shell Script
**File Created:** `script/run/transfer_sponsorship_paymaster_roles.sh`
- Takes 3 args: `<environment> <mode> <account>`
- Reads paymaster address from `script/output/<env>/<chainId>/<ChainName>-latest.json` per chain using python3
- Iterates over all chains via `NETWORKS` array from networks-staging.sh/networks-production.sh
- Resolves all addresses upfront, skips chains without paymaster deployment
- Optional flags: `--slow`, `--legacy`, `--check-only`
- Uses 1Password for RPC URLs, Foundry keystore for signing
- Confirmation prompt before execute mode
- Made executable with `chmod +x`

#### Build Status
- Solidity script compiles cleanly
- Shell script validated (argument parsing, address resolution logic)
