# Morpho Blue Market Oracle — Technical Specification

## Overview

Morpho Blue markets have no contract address — a market is identified purely by a `MarketParams` struct (loanToken, collateralToken, oracle, irm, lltv). The Superform oracle system requires a single address as `yieldSourceAddress`. This feature introduces two contracts to solve this:

1. **`MorphoBlueMarketWrapper`** — an immutable, permissionlessly-deployable wrapper that gives a Morpho Blue market an addressable identity.
2. **`MorphoBlueYieldSourceOracle`** — an `AbstractYieldSourceOracle` implementation that reads Morpho Blue on-chain state and **replicates interest accrual in a view context** (no state changes) to return fresh, accurate share/asset conversions.

Scope: **supply-side (lender) positions only**. Borrow tracking is out of scope.

---

## Problem Statement

Morpho Blue markets:
- Earn yield for suppliers through interest paid by borrowers
- Store market state (`totalSupplyAssets`, `totalSupplyShares`, etc.) lazily — state is only updated when `accrueInterest()` is called
- Have no per-market contract address — identity is a `bytes32` keccak256 of `MarketParams`

Without this feature, Superform cannot:
- Compute price-per-share (PPS) for Morpho Blue supply positions
- Report TVL or user balances to the accounting layer
- Register Morpho Blue markets as yield sources in SuperLedgerConfiguration

---

## Technical Design

### Contract 1: `MorphoBlueMarketWrapper`

**Location**: `src/accounting/oracles/MorphoBlueMarketWrapper.sol`

**Purpose**: Immutable wrapper providing a stable address for a specific Morpho Blue market. Fully permissionless — anyone can deploy a wrapper for any valid market.

**State**: All five `MarketParams` fields stored as immutables (zero storage slots):
```solidity
address public immutable morpho;
address public immutable loanToken;
address public immutable collateralToken;
address public immutable marketOracle;   // renamed to avoid Solidity keyword collision
address public immutable irm;
uint256 public immutable lltv;
```

**Constructor validation**: Calls `IMorphoStaticTyping(morpho_).idToMarketParams(id)` and reverts with `MARKET_DOES_NOT_EXIST()` if the market doesn't exist on Morpho. This ensures:
- The five params are self-consistent (ID derivation is deterministic)
- The IRM was governance-whitelisted at market creation time
- The market is real

**View methods**:
- `marketParams() → MarketParams` — reconstructs the struct from immutables
- `marketId() → Id` — recomputes keccak256 of the params

### Contract 2: `MorphoBlueYieldSourceOracle`

**Location**: `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol`

**Inheritance**: `AbstractYieldSourceOracle`

**Core mechanism — `_getAccruedMarketState`**:

Reads `IMorphoStaticTyping.market(id)` (stale stored values) and replicates Morpho's `_accrueInterest` in a pure view context using `IIrm.borrowRateView` + `MathLib.wTaylorCompounded`. This matches the canonical `MorphoBalancesLib.expectedMarketBalances` pattern from Morpho's own periphery library.

```
AccruedState:
  totalSupplyAssets = stored + interest (if elapsed > 0, borrows > 0, irm != 0)
  totalSupplyShares = stored + feeShares (if fee > 0)
  totalBorrowAssets = stored + interest
```

**Interest accrual sequence** (must follow exactly):
1. `elapsed = block.timestamp - lastUpdate`
2. Skip if `elapsed == 0` OR `totalBorrowAssets == 0` OR `irm == address(0)`
3. `borrowRate = IIrm(irm).borrowRateView(marketParams, market)` — view-safe
4. `interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed))`
5. `totalBorrowAssets += interest`; `totalSupplyAssets += interest`
6. If `fee > 0`: `feeAmount = interest.wMulDown(fee)`; `feeShares = feeAmount.toSharesDown(totalSupplyAssets - feeAmount, totalSupplyShares)`; `totalSupplyShares += feeShares`

**Method implementations**:

| Method | Implementation | Rounding |
|---|---|---|
| `decimals()` | `IERC20Metadata(loanToken).decimals() + 6` (accounts for `VIRTUAL_SHARES = 1e6`) | — |
| `getShareOutput()` | `assetsIn.toSharesDown(accrued.totalSupplyAssets, accrued.totalSupplyShares)` | Down (user gets fewer shares) |
| `getWithdrawalShareOutput()` | `assetsIn.toSharesUp(...)` | Up (user burns more shares) |
| `getAssetOutput()` | `sharesIn.toAssetsDown(...)` | Down (conservative) |
| `getPricePerShare()` | `(10^(dec+6)).toAssetsDown(...)` (prices one full share unit with virtual offset) | Down (= getAssetOutput of 1 share unit) |
| `getBalanceOfOwner()` | `position(id, owner).supplyShares` | — (raw shares, not assets) |
| `getTVLByOwnerOfShares()` | `shares.toAssetsDown(...)` | Down |
| `getTVL()` | `accrued.totalSupplyAssets` | — |

**Important**: `getBalanceOfOwner` returns **internal Morpho supply shares** (non-transferable, not ERC-20 tokens). Callers using this method directly must be aware they receive shares, not assets.

**Zero-IRM markets**: If `irm == address(0)`, skip accrual and return stored state. These markets have no borrowers so the stored values are always current.

### Deployment Model

- `MorphoBlueYieldSourceOracle`: deployed once per chain by Superform, constructor takes `superLedgerConfiguration_`
- `MorphoBlueMarketWrapper`: deployed permissionlessly by anyone per market (no Superform deployment script needed)
- **No registration** in `SuperLedgerConfiguration` at this stage (standalone, not fee-integrated)

---

## Attack Surface Analysis

### Token Risks
- [x] Fee-on-transfer tokens: unsupported (Morpho Blue requirement — not a new limitation)
- [x] Rebasing tokens: unsupported (Morpho docs state rebasing tokens not supported)
- [x] Missing return values: `IERC20Metadata.decimals()` — may revert for USDT-style tokens; acceptable for production markets
- [x] ERC-777: Morpho explicitly does not support re-entrant tokens; view reentrancy risk is theoretical

### Reentrancy
- [x] No state is written by the oracle — reentrancy is structurally impossible
- [x] No ETH, no ERC-721/777/1155 callbacks
- [ ] `this.getBalanceOfOwner` external call pattern in `getTVLByOwnerOfShares` — informational, refactor to internal call recommended

### Oracle & Price
- [x] `marketOracle` (collateral price oracle) is NOT used by the yield oracle — collateral oracle manipulation does not affect yield oracle
- [x] Flash loan resistance: `totalSupplyAssets` and `totalSupplyShares` are updated only via Morpho's write functions; flash loans don't change these values
- [x] Stale state: view-context interest accrual via `borrowRateView` + `wTaylorCompounded` eliminates staleness

### Access Control
- [x] No admin functions, no upgradeability, no access control — fully immutable

### IRM Trust
- [x] IRM is governance-whitelisted at Morpho market creation; wrapper constructor's `idToMarketParams` check ensures IRM was approved
- [ ] Malicious/upgradeable IRM could cause DoS (overflow → revert) or inflated PPS — extremely unlikely with production immutable AdaptiveCurveIRM
- [ ] `totalBorrowShares: 0` passed to `borrowRateView` — correct for AdaptiveCurveIRM, undocumented assumption for custom IRMs

### Wrapper Trust
- [x] Constructor validates market existence via `idToMarketParams` — ensures IRM was approved and params are consistent
- [ ] `wrapper.morpho()` address not validated against canonical address — registry must check `wrapper.morpho() == CANONICAL_MORPHO`

### Identified Code Gap (implement fix)
```solidity
// Current (missing third condition):
if (elapsed > 0 && s.totalBorrowAssets > 0) {

// Correct (matches MorphoBalancesLib exactly):
if (elapsed > 0 && s.totalBorrowAssets > 0 && mp.irm != address(0)) {
```

---

## Acceptance Criteria

### Contracts
- [ ] `MorphoBlueMarketWrapper` stores all five `MarketParams` fields as immutables with zero storage
- [ ] Wrapper constructor validates market exists on Morpho (`MARKET_DOES_NOT_EXIST` revert for invalid)
- [ ] `MorphoBlueYieldSourceOracle` implements all 8 abstract methods from `AbstractYieldSourceOracle`
- [ ] Interest accrual uses all three skip conditions: `elapsed > 0 && totalBorrowAssets > 0 && irm != address(0)`
- [ ] Rounding follows Morpho convention: `toSharesDown` for deposits/fees, `toSharesUp` for withdrawals, `toAssetsDown` for value
- [ ] Fee accrual uses correct denominator: `totalSupplyAssets - feeAmount` in `toSharesDown`
- [ ] `getAssetOutput` declared `public view` (not `external`) for internal callability
- [ ] Zero-IRM markets return stored state without reverting

### Testing — Fork Tests (Ethereum mainnet, ETH_BLOCK = 21_929_476)
- [ ] Two markets tested: WBTC/USDC (6 dec, LLTV 86%) and wstETH/WETH (18 dec, LLTV 94.5%)
- [ ] `test_wrapper_storesMarketParams` — all fields match constructor args
- [ ] `test_wrapper_computesCorrectId` — ID matches `MarketParamsLib.id()`
- [ ] `test_wrapper_rejectsInvalidMarket` — `MARKET_DOES_NOT_EXIST` for bad LLTV
- [ ] `test_wrapper_immutable_noStorageSlots` — storage slot 0 is zero
- [ ] `test_fork_decimals` — 12 for USDC (6+6), 24 for WETH (18+6)
- [ ] `test_fork_pps_nonZero` — PPS > 0 and >= 1 token unit
- [ ] `test_fork_pps_withInterestAccrual` — PPS after `vm.warp(+1 day)` >= PPS before
- [ ] `test_fork_tvl_nonZero` — TVL > 0 for active market
- [ ] `test_fork_conversions_consistent` — `getAssetOutput(1 share unit) == getPricePerShare()`
- [ ] `test_fork_roundTrip_noValueCreation` — `getAssetOutput(getShareOutput(assets)) <= assets`
- [ ] `test_fork_balanceOfOwner_zeroForFresh` — 0 for testUser before any supply
- [ ] `test_fork_supply_oracleReflectsPosition` — balance > 0, TVL ≈ supplied amount (±1 wei)
- [ ] `test_fork_supply_ppsStable` — PPS unchanged by proportional supply
- [ ] `test_fork_supplyAndWithdraw_lifecycle` — full supply → verify → withdraw → balance 0, received >= supplied
- [ ] `test_fork_withdrawalShareOutput_roundsUp` — withdrawal shares >= deposit shares for same assets
- [ ] `test_fork_getPricePerShareMultiple` — batch method works for both wrappers
- [ ] `test_fork_getTVLMultiple` — batch method works for both wrappers

### Testing — Full E2E Hook + Oracle Lifecycle
- [ ] `test_fork_morphoLendHook_supply_oracleReadsPosition` — hook supplies, oracle reads resulting position
- [ ] `test_fork_morphoWithdrawHook_withdraw_oracleReadsZero` — hook withdraws all, oracle returns 0 balance
- [ ] Full lifecycle: lendHook → oracle verify TVL → withdrawHook → oracle verify zero

### Testing — Fuzz Tests
- [ ] `testFuzz_RoundTrip_NeverCreatesValue` — round-trip property
- [ ] `testFuzz_PPS_MonotonicallyIncreases_WithElapsed` — PPS monotonic with time
- [ ] `testFuzz_Supply_DoesNotChangePPS` — proportional supply invariant
- [ ] `testFuzz_WithdrawalSharesGteDepositShares` — rounding property
- [ ] `testFuzz_AccrualNoOverflow` — interest math within uint128 for realistic params

---

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| IRM does not implement `borrowRateView` | Very Low (whitelist) | DoS oracle for that market | Document as known limitation |
| Wrong `decimals()` for unusual loan token | Very Low | Wrong PPS denomination | Document; add try/catch if needed |
| Registry accepts wrapper with fake `morpho` address | Low (manual exploit) | Wrong PPS from fake market | Registry must validate `wrapper.morpho()` |
| Vendored Morpho libs diverge from upstream | Very Low (Morpho Blue immutable) | Interest math mismatch | Lock vendor files at audited version |

---

## Implementation Skeleton

### MorphoBlueMarketWrapper.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IMorphoStaticTyping, MarketParams, Id } from "../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../vendor/morpho/MarketParamsLib.sol";

contract MorphoBlueMarketWrapper {
    using MarketParamsLib for MarketParams;

    error MARKET_DOES_NOT_EXIST();

    address public immutable morpho;
    address public immutable loanToken;
    address public immutable collateralToken;
    address public immutable marketOracle;
    address public immutable irm;
    uint256 public immutable lltv;

    constructor(address morpho_, address loanToken_, address collateralToken_,
                address oracle_, address irm_, uint256 lltv_) {
        // store all as immutables
        // validate: idToMarketParams(id).loanToken != address(0)
    }

    function marketParams() external view returns (MarketParams memory);
    function marketId() external view returns (Id);
}
```

### MorphoBlueYieldSourceOracle.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { IMorphoStaticTyping, MarketParams, Market, Id } from "../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../vendor/morpho/MarketParamsLib.sol";
import { SharesMathLib } from "../../vendor/morpho/SharesMathLib.sol";
import { MathLib, WAD } from "../../vendor/morpho/MathLib.sol";
import { IIrm } from "../../vendor/morpho/IIrm.sol";
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { MorphoBlueMarketWrapper } from "./MorphoBlueMarketWrapper.sol";

contract MorphoBlueYieldSourceOracle is AbstractYieldSourceOracle {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;

    struct AccruedState {
        uint256 totalSupplyAssets;
        uint256 totalSupplyShares;
        uint256 totalBorrowAssets;
    }

    constructor(address superLedgerConfiguration_)
        AbstractYieldSourceOracle(superLedgerConfiguration_) { }

    // decimals: returns loanToken.decimals() + 6 (accounts for VIRTUAL_SHARES = 1e6)
    // getPricePerShare: prices 10^(loanDec+6) shares via toAssetsDown
    // getShareOutput, getWithdrawalShareOutput, getAssetOutput (public),
    // getBalanceOfOwner, getTVLByOwnerOfShares, getTVL
    // all delegate to _getAccruedMarketState

    function _getAccruedMarketState(address yieldSourceAddress)
        internal view returns (AccruedState memory s) {
        // 1. Read market params from wrapper
        // 2. Read stale market state via IMorphoStaticTyping.market(id)
        // 3. If elapsed > 0 && totalBorrowAssets > 0 && irm != address(0):
        //    a. borrowRate = IIrm(irm).borrowRateView(mp, mkt)
        //    b. interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed))
        //    c. totalBorrowAssets += interest; totalSupplyAssets += interest
        //    d. if fee > 0: mint feeShares using toSharesDown(totalSupplyAssets - feeAmount, ...)
    }
}
```

---

## References

- `src/accounting/oracles/MorphoBlueMarketWrapper.sol` — current implementation
- `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol` — current implementation
- `test/integration/morpho/MorphoBlueMarketFork.t.sol` — fork tests
- `src/accounting/oracles/ERC4626YieldSourceOracle.sol` — canonical oracle pattern
- `src/vendor/morpho/` — IMorpho, SharesMathLib, MathLib, IIrm, MarketParamsLib
- [MorphoBalancesLib](https://github.com/morpho-org/morpho-blue/blob/main/src/libraries/periphery/MorphoBalancesLib.sol) — canonical view-context accrual reference
- `research/best-practices.md` — detailed math and conventions
- `research/evm-security.md` — security analysis and fuzz test suite
