# Aave V3 IPool Integration — Framework Documentation

Research compiled for building an `IPool` integration hook in Solidity 0.8.30.

Sources: official Aave docs (aave.com/docs), the canonical `aave-dao/aave-v3-origin`
monorepo (successor to `aave/aave-v3-core`), and the `bgd-labs/aave-address-book` /
`aave-dao/aave-address-book` registries. URLs cited inline and in the References section.

---

## 1. Summary

Aave V3 is a non-custodial liquidity protocol. Suppliers deposit an underlying asset and
receive an interest-bearing **aToken** (1:1, rebasing via a liquidity index); borrowers draw
debt against collateral and accrue **variableDebtToken** balances. All user-facing entry
points go through a single upgradeable `Pool` proxy per market. An integrator interacts with
that proxy through the `IPool` interface — the concrete `Pool` address is a transparent proxy
resolved from a `PoolAddressesProvider`.

Canonical source today is the **`aave-dao/aave-v3-origin`** monorepo. The older
`aave/aave-v3-core` repo holds the original V3.0 sources and is effectively frozen — new
integrations should target `aave-v3-origin`. Both are **MIT licensed** (interfaces) / BUSL-1.1
(some protocol implementation files); the `IPool` and `DataTypes` files you vendor are MIT.

---

## 2. Version Information

- Interface pragma: `pragma solidity ^0.8.0;` — compatible with your project's `0.8.30`.
- License: `// SPDX-License-Identifier: MIT` on `IPool.sol` and `DataTypes.sol`.
- The `IPool` ABI for the functions you care about (supply/withdraw/borrow/repay/etc.) has
  been **stable since V3.0** and is intentionally preserved for backwards compatibility across
  V3.1 → V3.4. `getReserveData` returns the legacy struct precisely to keep that ABI stable.

**Canonical import paths (`aave-v3-origin`, current `main`):**

```
src/contracts/interfaces/IPool.sol
src/contracts/protocol/libraries/types/DataTypes.sol
```

**Legacy import paths (`aave/aave-v3-core`, V3.0.x):**

```
contracts/interfaces/IPool.sol
contracts/protocol/libraries/types/DataTypes.sol
```

npm packages that ship these: `@aave/core-v3` (V3.0/3.1 era) and the newer
`aave-v3-origin` package. For addresses, use `@bgd-labs/aave-address-book`.

---

## 3. Key Concepts

- **One Pool proxy per market.** Resolve it once; never hardcode implementation addresses
  (they are upgraded). Prefer reading `getPool()` off the `PoolAddressesProvider` when you want
  to be upgrade-proof, or hardcode the proxy (proxies are stable — see Section 6).
- **aToken vs variableDebtToken.** `getReserveData(asset).aTokenAddress` is the receipt token
  you receive on `supply`; `variableDebtTokenAddress` tracks variable-rate debt.
- **interestRateMode.** `1` = stable, `2` = variable. **Stable is fully removed in V3.2+**
  (see Section 5) — always pass `2`.
- **`onBehalfOf` / `to`.** supply/borrow/repay let you act for another account; for a hook the
  smart account itself is normally both the caller and the `onBehalfOf`/`to` target.
- **referralCode.** Deprecated / inactive; pass `0`.
- **Base-currency accounting.** `getUserAccountData` returns values in the market's base
  currency (USD, 8 decimals, via the Aave oracle), not in token units.

---

## 4. Implementation Guide — Exact `IPool` Signatures

All signatures below are verbatim from `aave-dao/aave-v3-origin` `src/contracts/interfaces/IPool.sol`
(MIT, `^0.8.0`). Documented revert conditions are drawn from the Pool validation logic
(`ValidationLogic` / `Errors.sol`).

### supply
```solidity
function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16 referralCode
) external;
```
Supplies `amount` of `asset`; mints aTokens 1:1 to `onBehalfOf`. Caller must have approved the
Pool for `amount` of `asset` first.
Reverts: `RESERVE_INACTIVE` (27), `RESERVE_FROZEN` (28), `RESERVE_PAUSED` (29),
`INVALID_AMOUNT` (26, amount == 0), `SUPPLY_CAP_EXCEEDED` (51). Underlying `transferFrom`
reverts if allowance/balance insufficient.

### withdraw
```solidity
function withdraw(
    address asset,
    uint256 amount,
    address to
) external returns (uint256);
```
Burns caller's aTokens and sends `amount` of underlying to `to`. Pass `type(uint256).max` to
withdraw the full balance. Returns the actual amount withdrawn.
Reverts: `NOT_ENOUGH_AVAILABLE_USER_BALANCE` (32), `RESERVE_INACTIVE` (27), `RESERVE_PAUSED`
(29), `INVALID_AMOUNT` (26), and health-factor checks
(`HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD` (35)) if the withdrawn asset is collateral.

### borrow
```solidity
function borrow(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint16 referralCode,
    address onBehalfOf
) external;
```
Borrows `amount` against collateral supplied by `onBehalfOf`; mints variableDebtTokens. If
borrowing for another account, that account must have granted credit delegation.
Reverts: `RESERVE_INACTIVE` (27), `RESERVE_FROZEN` (28), `RESERVE_PAUSED` (29),
`BORROWING_NOT_ENABLED` (30), `INVALID_INTEREST_RATE_MODE_SELECTED` (33),
`COLLATERAL_BALANCE_IS_ZERO` (34), `HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD` (35),
`COLLATERAL_CANNOT_COVER_NEW_BORROW` (36), `BORROW_CAP_EXCEEDED` (50),
`PRICE_ORACLE_SENTINEL_CHECK_FAILED` (49). In V3.2+ passing `interestRateMode == 1` reverts.

### repay
```solidity
function repay(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    address onBehalfOf
) external returns (uint256);
```
Repays debt of `onBehalfOf`; burns variableDebtTokens. Pass `type(uint256).max` to repay the
full debt. Caller must have approved the Pool for the underlying. Returns amount repaid.
Reverts: `NO_DEBT_OF_SELECTED_TYPE` (39), `INVALID_INTEREST_RATE_MODE_SELECTED` (33),
`RESERVE_INACTIVE` (27), `RESERVE_PAUSED` (29), `INVALID_AMOUNT` (26).

### repayWithATokens
```solidity
function repayWithATokens(
    address asset,
    uint256 amount,
    uint256 interestRateMode
) external returns (uint256);
```
Repays the caller's own debt using the caller's aTokens of the same asset — no underlying
transfer, no prior approval needed. `onBehalfOf` is implicitly `msg.sender`. Returns amount
repaid.
Reverts: `NO_DEBT_OF_SELECTED_TYPE` (39), `NO_OUTSTANDING_VARIABLE_DEBT` /
`NO_OUTSTANDING_...` variants, `INVALID_INTEREST_RATE_MODE_SELECTED` (33), `RESERVE_PAUSED` (29).

### setUserUseReserveAsCollateral
```solidity
function setUserUseReserveAsCollateral(
    address asset,
    bool useAsCollateral
) external;
```
Enables/disables the caller's supplied `asset` as collateral.
Reverts: `UNDERLYING_BALANCE_ZERO` (43) when enabling with no aToken balance,
`HEALTH_FACTOR_LOWER_THAN_LIQUIDATION_THRESHOLD` (35) when disabling would make the position
unsafe, `RESERVE_INACTIVE` (27), `RESERVE_PAUSED` (29).

### getReserveData
```solidity
function getReserveData(address asset)
    external
    view
    returns (DataTypes.ReserveDataLegacy memory);
```
Returns the reserve state/config. **Return type is `DataTypes.ReserveDataLegacy`** (not
`DataTypes.ReserveData`) — deliberately kept ABI-stable for integrators. This is the function
you use to read `aTokenAddress` / `variableDebtTokenAddress` (see Section 4b). No revert for an
unlisted asset — it returns a zero-filled struct, so check `aTokenAddress != address(0)`.

### getUserAccountData
```solidity
function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
```
`*Base` values are in the market base currency (USD, 8 decimals). `ltv` and
`currentLiquidationThreshold` are in basis points (1e4). `healthFactor` is WAD (1e18);
`type(uint256).max` means no debt. View, no revert.

### getConfiguration
```solidity
function getConfiguration(address asset)
    external
    view
    returns (DataTypes.ReserveConfigurationMap memory);
```
Returns the packed reserve configuration bitmap (`uint256 data`). Decode with
`ReserveConfiguration` library helpers (getLtv, getLiquidationThreshold, getDecimals,
getActive, getFrozen, getPaused, getBorrowingEnabled, getSupplyCap, getBorrowCap, etc.).

### 4b. Getting the aToken address for a reserve

```solidity
DataTypes.ReserveDataLegacy memory d = IPool(pool).getReserveData(asset);
address aToken   = d.aTokenAddress;
address vDebt    = d.variableDebtTokenAddress;
// d.stableDebtTokenAddress still exists in the struct for ABI compatibility but is
// address(0) / unused on V3.2+ markets — do not rely on it.
```

There is no separate `getReserveAToken(asset)` on the stable public ABI; `getReserveData` is
the canonical path. (Newer origin builds added convenience getters, but `getReserveData` is the
maximally compatible route across all V3.x deployments.)

---

## 4c. DataTypes struct shapes

### `ReserveDataLegacy` — returned by `getReserveData` (order matters for ABI)
```solidity
struct ReserveDataLegacy {
    ReserveConfigurationMap configuration;        // 0
    uint128 liquidityIndex;                       // 1
    uint128 currentLiquidityRate;                 // 2
    uint128 variableBorrowIndex;                  // 3
    uint128 currentVariableBorrowRate;            // 4
    uint128 currentStableBorrowRate;              // 5  (deprecated v3.2 — reads as 0)
    uint40  lastUpdateTimestamp;                  // 6
    uint16  id;                                   // 7
    address aTokenAddress;                        // 8  <-- aToken
    address stableDebtTokenAddress;               // 9  (deprecated v3.2 — address(0))
    address variableDebtTokenAddress;             // 10 <-- variable debt token
    address interestRateStrategyAddress;          // 11 (deprecated v3.4 IR refactor)
    uint128 accruedToTreasury;                    // 12
    uint128 unbacked;                             // 13 (deprecated in later versions)
    uint128 isolationModeTotalDebt;               // 14
}
```

### `ReserveData` — internal storage struct (current `main`, post-3.3; NOT the return type)
For reference only — `getReserveData` does NOT return this. Current internal layout adds
`deficit` (V3.3) and `virtualUnderlyingBalance` (V3.1 virtual accounting), and renames the old
stable-debt / IR-strategy slots to `__deprecated*`:
```solidity
struct ReserveData {
    ReserveConfigurationMap configuration;
    uint128 liquidityIndex;
    uint128 currentLiquidityRate;
    uint128 variableBorrowIndex;
    uint128 currentVariableBorrowRate;
    uint128 deficit;                              // V3.3+
    uint40  lastUpdateTimestamp;
    uint16  id;
    uint40  liquidationGracePeriodUntil;          // V3.1+
    address aTokenAddress;
    address __deprecatedStableDebtTokenAddress;
    address variableDebtTokenAddress;
    address __deprecatedInterestRateStrategyAddress;
    uint128 accruedToTreasury;
    uint128 virtualUnderlyingBalance;             // V3.1 virtual accounting
    // ...deprecated tail fields
}
```
Takeaway for the integrator: **vendor only `ReserveDataLegacy`** and read via `getReserveData`.
That struct's field ordering (aToken at index 8, variableDebt at index 10) is fixed and safe
across V3.0 → V3.4. Do not depend on the internal `ReserveData` layout.

### `ReserveConfigurationMap` and `UserConfigurationMap`
```solidity
struct ReserveConfigurationMap { uint256 data; }  // packed bitmap
struct UserConfigurationMap    { uint256 data; }  // packed bitmap of collateral/borrow flags
```

---

## 5. Version Differences (V3.0 → V3.1 → V3.2 → V3.3), integrator-relevant

| Area | V3.0 | V3.1 | V3.2 | V3.3 |
|------|------|------|------|------|
| supply/withdraw/borrow/repay signatures | baseline | unchanged | unchanged | unchanged |
| Stable rate | present (mode 1) | present but discouraged | **removed** — mode 1 reverts; no stableDebtToken minted | removed |
| Virtual accounting | no | **added** (`virtualUnderlyingBalance`, config flag) | yes | yes |
| eModes | category-based | same | **Liquid eModes** (per-asset flags) | same |
| `getReserveData` return | `ReserveDataLegacy` | `ReserveDataLegacy` (unchanged ABI) | `ReserveDataLegacy` (stable slots read 0) | `ReserveDataLegacy` |
| Reserve deficit | no | no | no | **`deficit` field + `eliminateReserveDeficit`** |

Key points:

- **No breaking signature changes** to supply/withdraw/borrow/repay/repayWithATokens across
  V3.0 → V3.3 (and V3.4). The interface you vendor now works against all live markets.
- **Stable-rate removal (V3.2, "stable rate removal" upgrade):** always pass
  `interestRateMode = 2`. Passing `1` reverts on V3.2+ markets. `stableDebtTokenAddress` in the
  returned struct is `address(0)` on upgraded markets — never dereference it.
- **Virtual accounting (V3.1):** internal only; changes how liquidity is tracked but not the
  supply/borrow ABI. No integration change required.
- **V3.3 deficit / `getReserveData`:** the public getter still returns `ReserveDataLegacy`, so
  the new `deficit` field is not exposed through it — no impact on reading aToken addresses.
- **V3.4 (context, beyond scope):** interest-rate strategy centralized;
  `interestRateStrategyAddress` in the legacy struct is deprecated. Still no change to the core
  supply/borrow/repay ABI.

### Minimal, most-compatible `IPool` subset to vendor

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0; // compiles under 0.8.30
import {DataTypes} from "./DataTypes.sol";

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256);
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory);
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase, uint256 totalDebtBase, uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold, uint256 ltv, uint256 healthFactor);
    function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory);
}
```

Vendor a trimmed `DataTypes` carrying only `ReserveDataLegacy`, `ReserveConfigurationMap`, and
`UserConfigurationMap`. Keep the exact field ordering shown in Section 4c.

---

## 6. Deployed Addresses (main Aave V3 markets)

Source: `bgd-labs/aave-address-book` (and `aave-dao/aave-address-book`) Solidity libraries,
cross-checked with the Aave docs Pool Addresses Provider page. Verify against the address book
before deploying — it is the source of truth and updates on upgrades.

| Network | Pool (proxy) | PoolAddressesProvider |
|---------|--------------|------------------------|
| Ethereum (Core / main) | `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` | `0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e` |
| Arbitrum | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |
| Base | `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5` | `0xe20fCBdBfFC4Dd138cE8b2E6FBb6CB49777ad64D` |
| Optimism | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |
| Polygon | `0x794a61358D6845594F94dc1DB02A252b5b4814aD` | `0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb` |

Note: Arbitrum, Optimism, and Polygon share the same deterministically-deployed Pool
(`0x794a...14aD`) and Provider (`0xa976...3CDb`). Ethereum and Base are distinct.

### Additional Ethereum markets (isolated deployments, separate Pools)

| Ethereum market | Pool (proxy) | PoolAddressesProvider |
|-----------------|--------------|------------------------|
| Prime (formerly "Lido" market — `AaveV3EthereumLido`) | `0x4e033931ad43597d96D6bcc25c280717730B58B1` | `0xcfBf336fe147D643B9Cb705648500e101504B16d` |
| EtherFi (`AaveV3EthereumEtherFi`) | `0x0AA97c284e98396202b6A04024F5E2c65026F3c0` | `0xeBa440B438Ad808101d1c451C1C5322c90BEFCdA` |

Each market is an independent Pool with its own reserve list — an asset listed on Core is not
necessarily listed on Prime/EtherFi. Resolve aToken addresses per-market via that market's
`getReserveData`.

---

## 7. Common Issues / Integration Notes

- **Approve before supply/repay.** The Pool pulls underlying via `transferFrom`; the smart
  account must approve the Pool proxy for the amount (or use permit variants
  `supplyWithPermit` / `repayWithPermit` if you want to skip a separate approve).
- **Always pass `interestRateMode = 2`.** Mode 1 reverts on all current markets (post V3.2).
- **`referralCode = 0`.** Referrals are inactive.
- **Max sentinels.** Use `type(uint256).max` for full withdraw / full repay to avoid dust and
  rounding leftovers from index accrual between quote and execution.
- **Unlisted asset returns zeroed struct** from `getReserveData` — guard with
  `require(aTokenAddress != address(0))` before treating an asset as supported.
- **Do not cache aToken/reserve addresses across markets.** Resolve from the specific market's
  Pool; the same asset maps to different aTokens on Core vs Prime vs EtherFi.
- **Health factor** from `getUserAccountData` is WAD; `< 1e18` is liquidatable. For a hook that
  borrows/withdraws collateral, re-check HF post-op if you need a safety margin.
- **Base-currency units.** `getUserAccountData` returns USD with 8 decimals, not token units —
  don't mix with token-decimal math.

---

## 8. References

- IPool interface (canonical): https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/interfaces/IPool.sol
- DataTypes: https://github.com/aave-dao/aave-v3-origin/blob/main/src/contracts/protocol/libraries/types/DataTypes.sol
- aave-v3-origin repo: https://github.com/aave-dao/aave-v3-origin
- Legacy V3 core repo: https://github.com/aave/aave-v3-core
- Aave docs — Pool: https://aave.com/docs/aave-v3/smart-contracts/pool
- Aave docs — Pool Addresses Provider: https://aave.com/docs/aave-v3/smart-contracts/pool-addresses-provider
- Aave docs — Changelog: https://aave.com/docs/resources/changelog
- V3.1 features: https://github.com/aave-dao/aave-v3-origin/blob/main/docs/3.1/Aave-v3.1-features.md
- V3.2 features (Liquid eModes + stable-rate removal): https://github.com/aave-dao/aave-v3-origin/blob/v3.2.0/docs/3.2/Aave-3.2-features.md
- V3.3 features (deficit): https://github.com/aave-dao/aave-v3-origin/blob/main/docs/3.3/Aave-v3.3-features.md
- V3.2 stable-rate-removal audit (Certora): https://github.com/aave-dao/aave-v3-origin/blob/main/audits/2024-09-10_Certora_Aave-v3.2_Stable_Rate_Removal.pdf
- Address book (Solidity, source of truth): https://github.com/bgd-labs/aave-address-book — files: `src/AaveV3Ethereum.sol`, `AaveV3Arbitrum.sol`, `AaveV3Base.sol`, `AaveV3Optimism.sol`, `AaveV3Polygon.sol`, `AaveV3EthereumLido.sol` (Prime), `AaveV3EthereumEtherFi.sol`
- Address book (aave-dao mirror): https://github.com/aave-dao/aave-address-book
