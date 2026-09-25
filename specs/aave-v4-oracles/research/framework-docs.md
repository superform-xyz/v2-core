# Aave V4 Spoke API — Research for Superform Accounting Oracles

Produced by framework-docs-researcher, 2026-09-02. Scope: API surface needed by `AaveV4DebtOracle` + `AaveV4SupplyYieldSourceOracle` (SUP-20854).
Primary source: `src/vendor/aave-v4/IAaveV4Spoke.sol` (only file in `src/vendor/aave-v4/`). Upstream: `aave/aave-v4` @ `main` (BUSL; vendored interface is a minimal Apache-2.0 re-declaration).

## 1. Summary

Aave V4 replaces V3's market-per-pool design with Hub-and-Spoke: a per-chain Liquidity Hub holds unified accounting per asset (`assetId`), Spokes are borrowing modules holding user positions keyed by `(spoke, reserveId)`. A reserve binds `reserveId` to `(underlying, hub, assetId)`. All money functions and position views live on the Spoke. **No aTokens/debtTokens** — positions are internal share balances converted through live hub indices.

Both oracle reads — `getUserDebt` and `getUserSuppliedAssets` — are **virtually accrued to `block.timestamp`** (verified upstream), so oracle reads are exact at read time with no keeper poke.

## 2. Full API Reference

### 2.1 Vendored interface (verbatim surface)

```solidity
struct Reserve {
    address underlying;      // reserve's ERC-20 asset — the token oracles denominate in
    address hub;             // canonically IHubBase; ABI-identical
    uint16  assetId;         // asset identifier inside the Hub
    uint8   decimals;        // underlying decimals
    uint24  collateralRisk;  // BPS
    uint8   flags;           // canonically ReserveFlags (wrapped uint8); ABI-identical
    uint32  dynamicConfigKey;
}

// Money functions — all return (shares, assets), shares first. Guarded by
// onlyPositionManager(onBehalfOf); self-calls always allowed.
function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
    // amount > max withdrawable (e.g. type(uint256).max) => full withdrawal
function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
    // amount > outstanding debt => full repayment
function setUsingAsCollateral(uint256 reserveId, bool useAsCollateral, address onBehalfOf) external;
    // V4 does NOT auto-enable collateral on supply

// Views
function getReserve(uint256 reserveId) external view returns (Reserve memory);
    // REVERTS if the reserve id is not listed — expect a revert, not a zero struct
function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);
    // (drawnDebt, premiumDebt) in underlying-asset units; total = drawn + premium
function getUserSuppliedAssets(uint256 reserveId, address user) external view returns (uint256);
```

### 2.2 Upstream `ISpoke` members NOT yet vendored (needed for getTVL / enumeration)

Verified present upstream — **extend the vendored interface**:

```solidity
function getReserveCount() external view returns (uint256);
    // count includes reserves that are not currently active
function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);
    // reserve-level (drawnDebt, premiumDebt) — the debt-oracle getTVL aggregate (totalBorrows analog)
function getReserveSuppliedAssets(uint256 reserveId) external view returns (uint256);
    // reserve-level total supplied — the supply-oracle getTVL aggregate
function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);
function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);
function getUserPosition(uint256 reserveId, address user) external view returns (UserPosition memory);
function getUserAccountData(address user) external view returns (UserAccountData memory);
function updateUserRiskPremium(address onBehalfOf) external;
```

`ReserveFlags` bit layout (upstream `ReserveFlagsMap.sol`): bit 0 `paused`, bit 1 `frozen`, bit 2 `borrowable`, bit 3 `receiveSharesEnabled`. Pause/freeze gate state-changing ops; nothing suggests views stop working (unverified — open question 5).

## 3. Semantics

### 3.1 Debt: drawn vs premium, view accrual (verified upstream)

- **Drawn debt** = principal + base borrow interest: `drawnShares.rayMulUp(drawnIndex)` — **rounds up** (conservative — matches "report at least what's owed").
- **`drawnIndex` is virtually accrued in views**: `AssetLogic.getDrawnIndex` applies `calculateLinearInterest(drawnRate, lastUpdateTimestamp)` when stale. `getUserDebt` is exact at `block.timestamp` — no stale-index gap vs a same-block `repay(max)`.
- **Premium debt** = per-position User Risk Premium: extra interest on top of the shared base rate, sized by collateral quality, recalculated on position change (or `updateUserRiskPremium`). Formula (`Premium.sol`): `premiumRay = premiumShares * drawnIndex - premiumOffsetRay` — rides the same live index, continuously view-accrued.
- **Total debt = drawn + premium** (upstream NatSpec verbatim) — exactly what hooks and the mock encode.
- Debt oracle: identity PPS in borrow-asset units, `getBalanceOfOwner = drawn + premium`, Euler-`debtOf`-shaped. Premium component's final RAY→asset truncation direction unverified (open question 1, dust-level).

### 3.2 Supply: units and view accrual (verified)

- `getUserSuppliedAssets` = `hub.previewRemoveByShares(assetId, suppliedShares)` → `toAddedAssetsDown` → `shares × totalAddedAssets / addedShares`, **rounded down** (protocol-favorable, the safe direction for a supply oracle).
- `totalAddedAssets()` includes liquidity + drawn debt + premium + unrealized fees at the live accrued index — supply read also virtually accrued.
- No sentinel gotcha on views; max sentinels exist only on mutating paths.

### 3.3 Reserve identity and enumeration

- `reserveId`s assigned sequentially (`_reserveCount++`) — stable, monotonically increasing, never reused on current codebase; `[0, getReserveCount())` is dense.
- `getReserve(reserveId)` reverts for unlisted ids. Registry validation should treat revert as "unknown reserve"; batch try/catch isolates it.
- Hooks' binding invariant (`getReserve(id).underlying == declared token`) is the same check the registry should apply at registration.

### 3.4 Position managers

- Money functions guarded by `onlyPositionManager(onBehalfOf)`; self-calls always allowed (the hooks' path). **Views are unrestricted.** Position managers mean third parties can mutate a user's debt/supply between signing and execution (the SUP-20842 motivation).

### 3.5 V4-specific gotchas

1. **Debt grows in two channels** — `drawn = 0, premium > 0` still owes; total must always be the sum (unit test `AaveV4LoanHooksV2.t.sol:372` covers it).
2. **Risk premium is per-position and repricing** — debt growth is not uniform across users of a reserve; rules out any per-reserve "debt index" shortcut (irrelevant to identity-PPS reads of live totals).
3. **feePercent = 0 invariant** applies identically to the other debt oracles.
4. **No aToken/debtToken addresses** — positions are non-transferable internal shares (unless `receiveSharesEnabled` liquidation path) — confirms the synthetic (spoke, reserveId) registry key decision.
5. **`hub`/`flags` typing**: vendored `address`/`uint8` vs upstream `IHubBase`/`ReserveFlags` — ABI-identical.
6. **Aave V4 is pre-hardening** — pin the commit the vendored interface was verified against and fork-test.

## 4. How the existing hooks consume this API

- Debt read: `BaseAaveV4LoanHookV2._totalDebt` (line 177) = `getUserDebt` → drawn + premium. Debt oracle's `getBalanceOfOwner` must be this exact sum so hook-resolved repays and ledger-read debt never disagree.
- Supply read: `_suppliedAssets` (line 183) = `getUserSuppliedAssets` — supply oracle reads the identical function.
- Reserve binding: `_validateReserves` (line 166) → `TOKEN_RESERVE_MISMATCH` — registry mirrors this.
- Full-repay sentinel: hooks pass max to `repay` but approve exactly drawn+premium — sound only because `getUserDebt` is accrued to `block.timestamp` and build/approve/repay share one transaction (verified upstream, 3.1).
- Spoke from calldata, not constructor — oracles get the same property via the registry.
- Tests: `MockAaveV4SpokeV2` (`setUserDebt(reserveId, user, drawn, premium)`) in `test/unit/hooks/loan/AaveV4LoanHooksV2.t.sol`, reusable. Fork test `test/integration/AaveV4V2HooksFork.t.sol` runs against the live **Ethereum-mainnet** Main Spoke `0x94e7A5dCbE816e498b89aB752661904E2F56c485` (WETH id 0, USDC id 7, block `AAVE_V4_BLOCK = 24_884_274`). Base spoke address still needed.

## 5. Upstream verification

Vendored `IAaveV4Spoke` **matches upstream `ISpoke`** on every shared member — no drift found. Sources:

- https://github.com/aave/aave-v4 — canonical V4 codebase (BUSL)
- https://github.com/aave/aave-v4/blob/main/src/spoke/interfaces/ISpoke.sol
- https://github.com/aave/aave-v4/blob/main/src/spoke/Spoke.sol — view implementations, `onlyPositionManager`, `_reserveCount++`
- https://github.com/aave/aave-v4/blob/main/src/spoke/libraries/UserPositionUtils.sol — `rayMulUp` drawn debt
- https://github.com/aave/aave-v4/blob/main/src/hub/libraries/Premium.sol — premium formula
- https://github.com/aave/aave-v4/blob/main/src/hub/libraries/AssetLogic.sol — `getDrawnIndex` linear accrual; `toAddedAssetsDown`
- https://github.com/aave/aave-v4/blob/main/src/hub/Hub.sol — `previewRemoveByShares`
- https://github.com/aave/aave-v4/blob/main/src/spoke/libraries/ReserveFlagsMap.sol — flag bits
- https://aave.com/docs/aave-v4 and https://aave.com/docs/aave-v4/liquidity/spokes — Hub-and-Spoke, User Risk Premium
- https://github.com/aave/aave-v4-sdk — exists; not needed on-chain

## 6. Open API questions (for the Joao call / fork verification)

1. **Premium rounding direction** — final RAY→asset truncation of the premium component in `getUserDebt` (drawn rounds up; premium unverified). Dust-level; matters for whether `approve(drawn+premium)` can be 1 wei short of `repay(max)`'s pull.
2. **Bad debt / deficit in supply PPS** — does `totalAddedAssets()` net socialized deficit, i.e., does `getUserSuppliedAssets` reflect insolvency haircuts immediately?
3. **reserveId permanence** — sequential-never-reused holds at `main`; any governance path (spoke upgrade/migration) that could rebind a reserveId to a different underlying? Registry + underlying check mitigates; confirm intent.
4. **Deployed-vs-main drift** — does the live mainnet spoke (and the upcoming Base equities spoke) match `main` semantics? Pin the audited release/commit.
5. **Views under pause/freeze** — confirm `getUserDebt`/`getUserSuppliedAssets` never revert for paused/frozen reserves (oracle liveness during equity trading-hour pauses).
6. **Liquidity premiums** (spoke-level hub credit-line pricing, distinct from user risk premium) — confirm whether they surface in spoke-level debt reads or are hub-internal.
7. **Base equities spoke address + reserve ids** — needed for fork-test matrix and registry seeding; ALSO confirm whether equities reserves use the standard Spoke or **`TokenizationSpoke`** (upstream has both — TokenizationSpoke wraps positions as ERC-20/4626-like shares, which would change the oracle shape if used).
