# Morpho Blue Market Oracle — Technical Specification

## Overview

Morpho Blue markets have no contract address — a market is identified purely by a `MarketParams` struct (loanToken, collateralToken, oracle, irm, lltv). The Superform oracle system requires a single address as `yieldSourceAddress`. This feature introduces two contracts to solve this:

1. **`MorphoBlueMarketRegistry`** — a permissioned singleton registry (AccessControl) that maps pseudo-addresses to `MarketParams` and the Morpho singleton address. Enforces an IRM whitelist and uses a 2-day timelock for deregistration.
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

### Contract 1: `MorphoBlueMarketRegistry`

**Location**: `src/accounting/oracles/MorphoBlueMarketRegistry.sol`

**Purpose**: Permissioned singleton registry that maps pseudo-addresses (market keys) to `MarketParams` and the Morpho singleton address. Enables `MorphoBlueYieldSourceOracle` to be a singleton supporting any registered market without per-market deployments.

**Market key derivation**: `address(uint160(uint256(Id.unwrap(marketId))))` — the lower 20 bytes of the 32-byte keccak256 Morpho market ID. Collision probability is negligible (~2^-80 for 2^20 markets); a collision merely prevents registration of the second market.

**Access Control**:
- `DEFAULT_ADMIN_ROLE` — can manage roles
- `MARKET_MANAGER_ROLE` — can register markets, propose/execute/cancel deregistrations, approve IRMs

**IRM whitelist**: Non-zero IRMs must be pre-approved via `setIrmApproval` before any market using that IRM can be registered. Zero-IRM markets (no-interest) are always permitted. This prevents rogue IRMs from corrupting PPS via malicious `borrowRateView`.

**Deregistration timelock**: Market deregistration is a two-step process with a 2-day delay:
1. `proposeDeregisterMarket(marketKey)` — starts the timelock
2. `executeDeregisterMarket(marketKey)` — executes after 2 days
3. `cancelDeregisterMarket(marketKey)` — aborts before execution

**State**:
```solidity
struct MarketInfo {
    address morpho;
    MarketParams params;
    bool registered;
}

mapping(address marketKey => MarketInfo) private _markets;
mapping(address irm => bool) public approvedIrms;
mapping(address marketKey => uint256 executeAfter) public pendingDeregistrations;
```

**Key methods**:
- `registerMarket(morpho_, loanToken_, collateralToken_, oracle_, irm_, lltv_) → marketKey` — validates market exists on Morpho, IRM approved, not already registered
- `getMarketInfo(marketKey) → (MarketParams, address morpho)` — reverts `MARKET_NOT_REGISTERED` if not found
- `computeMarketKey(loanToken_, collateralToken_, oracle_, irm_, lltv_) → address` — pure key derivation

### Contract 2: `MorphoBlueYieldSourceOracle`

**Location**: `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol`

**Inheritance**: `AbstractYieldSourceOracle`

**Constructor**: Takes `MorphoBlueMarketRegistry` address (immutable `REGISTRY`) and `superLedgerConfiguration_`.

**Core mechanism — `_getAccruedMarketState`**:

Reads `MarketParams` and `morpho` from the registry, then reads `IMorphoStaticTyping.market(id)` (stale stored values) and replicates Morpho's `_accrueInterest` in a pure view context using `IIrm.borrowRateView` + `MathLib.wTaylorCompounded`. This matches the canonical `MorphoBalancesLib.expectedMarketBalances` pattern from Morpho's own periphery library.

```
AccruedState:
  totalSupplyAssets = stored + interest (if elapsed > 0, borrows > 0, irm != 0)
  totalSupplyShares = stored + feeShares (if fee > 0)
  totalBorrowAssets = stored + interest
```

**Interest accrual sequence** (must follow exactly):
1. `elapsed = block.timestamp - lastUpdate`; cap at 365 days
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

- `MorphoBlueMarketRegistry`: deployed once per chain by Superform, admin granted `DEFAULT_ADMIN_ROLE` + `MARKET_MANAGER_ROLE`
- `MorphoBlueYieldSourceOracle`: deployed once per chain, constructor takes `registry_` and `superLedgerConfiguration_`
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

### Oracle & Price
- [x] `marketOracle` (collateral price oracle) is NOT used by the yield oracle — collateral oracle manipulation does not affect yield oracle
- [x] Flash loan resistance: `totalSupplyAssets` and `totalSupplyShares` are updated only via Morpho's write functions; flash loans don't change these values
- [x] Stale state: view-context interest accrual via `borrowRateView` + `wTaylorCompounded` eliminates staleness
- [x] Elapsed cap: 365-day maximum prevents `wTaylorCompounded` overflow on dormant markets

### Access Control
- [x] Oracle: no admin functions, no upgradeability — fully immutable view contract
- [x] Registry: `MARKET_MANAGER_ROLE` required for registration/deregistration/IRM approval
- [x] Deregistration requires 2-day timelock — prevents accidental or malicious instant removal

### IRM Trust
- [x] IRM whitelist enforced at registration — only pre-approved IRMs can be used
- [x] Zero-IRM markets bypass accrual entirely (always safe)
- [ ] Malicious/upgradeable IRM could cause DoS (overflow → revert) or inflated PPS — extremely unlikely with production immutable AdaptiveCurveIRM

---

## Acceptance Criteria

### Registry
- [x] `MorphoBlueMarketRegistry` uses AccessControl with `MARKET_MANAGER_ROLE`
- [x] `registerMarket` validates market exists on Morpho, IRM is approved (or zero), not already registered
- [x] Market key = `address(uint160(uint256(Id.unwrap(marketId))))` — deterministic from params
- [x] Deregistration uses 2-day timelock (propose → execute pattern)
- [x] `setIrmApproval` gates which IRMs can be used in registered markets
- [x] `getMarketInfo` reverts `MARKET_NOT_REGISTERED` for unregistered keys

### Oracle
- [x] `MorphoBlueYieldSourceOracle` implements all 8 abstract methods from `AbstractYieldSourceOracle`
- [x] Interest accrual uses all three skip conditions: `elapsed > 0 && totalBorrowAssets > 0 && irm != address(0)`
- [x] Elapsed capped at 365 days to prevent overflow
- [x] Rounding follows Morpho convention: `toSharesDown` for deposits/fees, `toSharesUp` for withdrawals, `toAssetsDown` for value
- [x] Fee accrual uses correct denominator: `totalSupplyAssets - feeAmount` in `toSharesDown`
- [x] `decimals()` returns `loanToken.decimals() + 6` (accounts for `VIRTUAL_SHARES = 1e6`)
- [x] `getPricePerShare()` prices `10^(loanDec+6)` shares
- [x] `getAssetOutput` declared `public view` (not `external`) for internal callability
- [x] Zero-IRM markets return stored state without reverting

### Testing — Fork Tests (Ethereum mainnet, ETH_BLOCK = 21_929_476)
- [x] Two markets tested: WBTC/USDC (6 dec, LLTV 86%) and wstETH/WETH (18 dec, LLTV 94.5%)
- [x] `test_fork_decimals` — 12 for USDC (6+6), 24 for WETH (18+6)
- [x] `test_fork_pps_nonZero` — PPS > 0 and >= 1 token unit
- [x] `test_fork_pps_withInterestAccrual` — PPS after `vm.warp(+1 day)` >= PPS before
- [x] `test_fork_tvl_nonZero` — TVL > 0 for active market
- [x] `test_fork_conversions_consistent` — `getAssetOutput(1 share unit) == getPricePerShare()`
- [x] `test_fork_roundTrip_noValueCreation` — `getAssetOutput(getShareOutput(assets)) <= assets`
- [x] `test_fork_balanceOfOwner_zeroForFresh` — 0 for testUser before any supply
- [x] `test_fork_supply_oracleReflectsPosition` — balance > 0, TVL ≈ supplied amount (±1 wei)
- [x] `test_fork_supply_ppsStable` — PPS unchanged by proportional supply
- [x] `test_fork_supplyAndWithdraw_lifecycle` — full supply → verify → withdraw → balance 0, received >= supplied
- [x] `test_fork_withdrawalShareOutput_roundsUp` — withdrawal shares >= deposit shares for same assets
- [x] `test_fork_getPricePerShareMultiple` — batch method works for both markets
- [x] `test_fork_getTVLMultiple` — batch method works for both markets

### Testing — Full E2E Hook + Oracle Lifecycle
- [ ] `test_fork_morphoLendHook_supply_oracleReadsPosition` — hook supplies, oracle reads resulting position
- [ ] `test_fork_morphoWithdrawHook_withdraw_oracleReadsZero` — hook withdraws all, oracle returns 0 balance
- [ ] Full lifecycle: lendHook → oracle verify TVL → withdrawHook → oracle verify zero

### Testing — Fuzz Tests
- [x] `testFuzz_RoundTrip_NeverCreatesValue` — round-trip property
- [x] `testFuzz_PPS_MonotonicallyIncreases_WithElapsed` — PPS monotonic with time
- [x] `testFuzz_Supply_DoesNotChangePPS` — proportional supply invariant
- [x] `testFuzz_WithdrawalSharesGteDepositShares` — rounding property
- [x] `testFuzz_AccrualNoOverflow` — interest math within uint128 for realistic params

---

## Dependencies & Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| IRM does not implement `borrowRateView` | Very Low (whitelist) | DoS oracle for that market | IRM whitelist; document as known limitation |
| Rogue IRM returns malicious borrowRate | Extremely Low | PPS manipulation | IRM whitelist enforced at registration |
| `elapsed` overflow on dormant market | Very Low | Silent PPS overstatement | 365-day cap on elapsed |
| Vendored Morpho libs diverge from upstream | Very Low (Morpho Blue immutable) | Interest math mismatch | Lock vendor files at audited version |

---

## Implementation Skeleton

### MorphoBlueMarketRegistry.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IMorphoStaticTyping, MarketParams, Id } from "../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../vendor/morpho/MarketParamsLib.sol";

contract MorphoBlueMarketRegistry is AccessControl {
    using MarketParamsLib for MarketParams;

    bytes32 public constant MARKET_MANAGER_ROLE = keccak256("MARKET_MANAGER_ROLE");
    uint256 public constant DEREGISTER_DELAY = 2 days;

    struct MarketInfo { address morpho; MarketParams params; bool registered; }

    mapping(address => MarketInfo) private _markets;
    mapping(address => bool) public approvedIrms;
    mapping(address => uint256) public pendingDeregistrations;

    constructor(address admin_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(MARKET_MANAGER_ROLE, admin_);
    }

    function setIrmApproval(address irm_, bool approved_) external onlyRole(MARKET_MANAGER_ROLE);
    function registerMarket(address morpho_, address loanToken_, address collateralToken_,
                           address oracle_, address irm_, uint256 lltv_)
        external onlyRole(MARKET_MANAGER_ROLE) returns (address marketKey);
    function proposeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE);
    function executeDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE);
    function cancelDeregisterMarket(address marketKey) external onlyRole(MARKET_MANAGER_ROLE);
    function getMarketInfo(address marketKey) external view returns (MarketParams memory, address morpho);
    function computeMarketKey(...) external pure returns (address);
}
```

### MorphoBlueYieldSourceOracle.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { MorphoBlueMarketRegistry } from "./MorphoBlueMarketRegistry.sol";
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
// ... vendor imports

contract MorphoBlueYieldSourceOracle is AbstractYieldSourceOracle {
    MorphoBlueMarketRegistry public immutable REGISTRY;

    struct AccruedState {
        uint256 totalSupplyAssets;
        uint256 totalSupplyShares;
        uint256 totalBorrowAssets;
    }

    constructor(address registry_, address superLedgerConfiguration_)
        AbstractYieldSourceOracle(superLedgerConfiguration_) {
        REGISTRY = MorphoBlueMarketRegistry(registry_);
    }

    // decimals: returns loanToken.decimals() + 6 (accounts for VIRTUAL_SHARES = 1e6)
    // getPricePerShare: prices 10^(loanDec+6) shares via toAssetsDown
    // getShareOutput, getWithdrawalShareOutput, getAssetOutput (public),
    // getBalanceOfOwner, getTVLByOwnerOfShares, getTVL
    // all delegate to _getAccruedMarketState

    function _getAccruedMarketState(address yieldSourceAddress)
        internal view returns (AccruedState memory s, MarketParams memory mp) {
        // 1. Read market params and morpho from REGISTRY.getMarketInfo(yieldSourceAddress)
        // 2. Read stale market state via IMorphoStaticTyping.market(id)
        // 3. Cap elapsed at 365 days
        // 4. If elapsed > 0 && totalBorrowAssets > 0 && irm != address(0):
        //    a. borrowRate = IIrm(irm).borrowRateView(mp, mkt)
        //    b. interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed))
        //    c. totalBorrowAssets += interest; totalSupplyAssets += interest
        //    d. if fee > 0: mint feeShares using toSharesDown(totalSupplyAssets - feeAmount, ...)
    }
}
```

---

## References

- `src/accounting/oracles/MorphoBlueMarketRegistry.sol` — permissioned market registry
- `src/accounting/oracles/MorphoBlueYieldSourceOracle.sol` — yield source oracle
- `test/integration/morpho/MorphoBlueMarketFork.t.sol` — fork tests
- `src/accounting/oracles/ERC4626YieldSourceOracle.sol` — canonical oracle pattern
- `src/vendor/morpho/` — IMorpho, SharesMathLib, MathLib, IIrm, MarketParamsLib
- [MorphoBalancesLib](https://github.com/morpho-org/morpho-blue/blob/main/src/libraries/periphery/MorphoBalancesLib.sol) — canonical view-context accrual reference
- `research/best-practices.md` — detailed math and conventions
- `research/evm-security.md` — security analysis and fuzz test suite

## Design Evolution

The original spec (2026-06-26 interview) described a permissionless `MorphoBlueMarketWrapper` per market. During implementation this was replaced by a permissioned `MorphoBlueMarketRegistry` singleton. Key reasons for the change:

| Aspect | Original (Wrapper) | Shipped (Registry) |
|--------|-------------------|-------------------|
| Trust model | Permissionless — anyone deploys | Permissioned — `MARKET_MANAGER_ROLE` only |
| IRM safety | Implicit (validated at Morpho market creation) | Explicit whitelist (`setIrmApproval`) |
| Deregistration | Not possible (immutable) | 2-day timelocked deregistration |
| Morpho address | Stored per-wrapper (user-supplied) | Stored per-market (manager-supplied, trusted) |
| Deployment | One wrapper per market | One registry per chain |
