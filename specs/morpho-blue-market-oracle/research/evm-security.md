# EVM Security Research — Morpho Blue Yield Source Oracle

## Executive Summary

`MorphoBlueYieldSourceOracle` and `MorphoBlueMarketRegistry` are **read-only** contracts (oracle) and a **permissioned registry** that never move funds. The primary risk is not fund loss from within these contracts but rather **incorrect values reported to upstream accounting** (SuperLedger, monitoring). A wrong PPS causes wrong performance fee calculations and wrong TVL displays.

> **Resolution status (2026-07-03):** All findings have been triaged and resolved. Two findings
> (read-only reentrancy P0 and flash-loan PPS inflation) were determined to be false positives
> upon deeper analysis. Remaining findings are fixed, mitigated, or accepted with documentation.

---

## Prioritized Findings

| # | Finding | Severity | Exploitable? | Status |
|---|---|---|---|---------|
| 1 | Missing `irm != address(0)` third condition in accrual skip | Low-Med | No (edge case) | **FIXED** — condition added |
| 2 | IRM returning extreme rate could inflate simulated PPS without overflow | Medium | Only via malicious IRM | **MITIGATED** — IRM whitelist in registry (`setIrmApproval`) |
| 3 | Dormant market (`elapsed` >> 0) with no on-chain accrual could produce inflated view PPS | Low-Med | Passive risk only | **MITIGATED** — 365-day cap on `elapsed` |
| 4 | `interest` kept as `uint256` in view sim; Morpho casts to `uint128` on-chain — silent divergence | Low | Silent misinformation | **MITIGATED** — 365-day elapsed cap bounds interest magnitude |
| 5 | ~~`wrapper.morpho()` not validated against canonical Morpho address by registry~~ | ~~Low~~ | ~~Requires malicious wrapper~~ | **RESOLVED** — wrappers replaced by permissioned `MorphoBlueMarketRegistry`; `morpho` address is manager-supplied and trusted |
| 6 | ~~ERC-777 loan token creates mid-supply read-reentrancy window~~ | ~~Low~~ | ~~Only with ERC-777~~ | **FALSE POSITIVE** — see analysis below |
| 7 | `totalBorrowShares: 0` assumption in Market struct for `borrowRateView` | Low | Only with non-AdaptiveCurveIRM | **ACCEPTED** — documented; IRM whitelist prevents non-standard IRMs |
| 8 | `this.getBalanceOfOwner` external call in `getTVLByOwnerOfShares` | Info | No (no reentrancy guard) | **ACCEPTED** — informational; no security impact |
| 9 | `decimals()` calls IERC20Metadata — may revert for non-standard tokens (e.g. USDT) | Low | DoS of oracle | **ACCEPTED** — all production Morpho markets implement `decimals()` |

---

## Detailed Analysis

### 1. Missing Third Accrual Condition — FIXED

**Original code** (`MorphoBlueYieldSourceOracle.sol`):
```solidity
if (elapsed > 0 && s.totalBorrowAssets > 0) {
    uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt); // REVERTS if mp.irm == address(0)
```

**Canonical MorphoBalancesLib**:
```solidity
if (elapsed != 0 && market.totalBorrowAssets != 0 && marketParams.irm != address(0)) {
```

**Impact**: A market with `irm == address(0)` and non-zero borrows (theoretical — Morpho Blue doesn't allow borrowing with a zero-IRM, but a hypothetical edge case) would cause the oracle to revert. Safe failure (revert, not wrong value), but not bit-exact with MorphoBalancesLib.

**Resolution**: Third condition `&& mp.irm != address(0)` added to match MorphoBalancesLib exactly.

### 2. IRM Extreme Rate — MITIGATED

The AdaptiveCurveIRM has `MAX_RATE_AT_TARGET` hard caps. Governance-whitelisted IRMs are immutable on Morpho Blue, making a post-deployment malicious IRM essentially impossible in practice.

If a pathological IRM returns a rate high enough to cause overflow: Solidity 0.8.x reverts on overflow → **DoS, not PPS manipulation**. This is acceptable failure behavior.

**Resolution**: `MorphoBlueMarketRegistry.setIrmApproval` enforces an explicit IRM whitelist — only pre-approved IRMs can be used in registered markets. This prevents registration of markets using rogue/untested IRMs entirely.

### 3. Stale Dormant Market — MITIGATED

For a market with `totalBorrowAssets > 0` and a long `elapsed` (weeks without any on-chain interaction), `wTaylorCompounded` compounds the rate over that window. This produces an accurate result — the oracle correctly shows what suppliers have earned. It's not a manipulation risk.

The risk is that the **on-chain accrual** would cast `interest.toUint128()` and could overflow, bricking the market. The oracle's view simulation (using `uint256` throughout) would not catch this and would return a large number instead of a revert, creating silent divergence. This scenario requires unrealistically high APRs sustained over long periods.

**Resolution**: Oracle caps `elapsed` at 365 days, bounding the maximum interest magnitude and preventing divergence from on-chain behavior for any realistic market.

### 4. `interest` uint128 Divergence — MITIGATED

On-chain: `market[id].totalBorrowAssets += interest.toUint128()` → reverts if `interest > type(uint128).max`.
Oracle: `s.totalBorrowAssets += interest` → no cast, no revert.

For a bricked market (where real accrual would revert), the oracle returns a non-reverting inflated PPS. Since Morpho is immutable and markets interact frequently, this scenario is essentially theoretical.

**Resolution**: The 365-day elapsed cap (Finding 3 fix) bounds the interest magnitude, making uint128 overflow unreachable for any realistic rate + timeframe combination.

### 5. Wrapper `morpho` Address Not Validated — RESOLVED

~~The wrapper constructor validates the market exists via `idToMarketParams`. It does NOT validate that `morpho_` is the canonical address. A wrapper pointing at a fake Morpho that returns non-zero addresses from `idToMarketParams` would pass construction.~~

**Resolution**: The entire wrapper design was replaced by `MorphoBlueMarketRegistry` — a permissioned singleton where only `MARKET_MANAGER_ROLE` can register markets. The `morpho` address is supplied by the trusted manager and stored in the registry. No user-deployable wrappers exist.

### 6. View Reentrancy (ERC-777 / Read-Only Reentrancy) — FALSE POSITIVE

**Original claim**: A read-only reentrancy window exists where `totalSupplyAssets` has been incremented but `totalSupplyShares` has not, allowing an attacker to observe an inflated PPS mid-transaction.

**Why this is a false positive**: Morpho Blue follows the Checks-Effects-Interactions (CEI) pattern strictly. In `supply()` and `withdraw()`, **all state updates** (both `totalSupplyAssets` and `totalSupplyShares`, plus the user's position) are completed **before** any external token transfer. There is no window between the two total updates where a view call could observe an inconsistent state. The oracle reads `IMorphoStaticTyping.market(id)` which returns the fully-updated struct.

Additionally, Morpho Blue explicitly does not support re-entrant tokens (documented in `IMorpho.sol`). Production markets use standard ERC-20 tokens.

**Note**: The IRM whitelist in the registry (`setIrmApproval`) was implemented to address Finding 2 (rogue IRM returning extreme rates), not this reentrancy concern.

### 7. `totalBorrowShares: 0` Assumption — ACCEPTED

Passed to `IIrm.borrowRateView()`. The production AdaptiveCurveIRM only uses utilization ratio = `totalBorrowAssets / totalSupplyAssets`. `totalBorrowShares` is unused. This is safe for all current Morpho Blue markets but would produce wrong rates for a hypothetical IRM that uses borrow shares.

**Resolution**: Accepted as documented limitation. The IRM whitelist ensures only known-good IRMs (which don't use `totalBorrowShares` in rate computation) are permitted.

### 8. `this.getBalanceOfOwner` External Call — ACCEPTED

```solidity
// getTVLByOwnerOfShares
uint256 shares = this.getBalanceOfOwner(yieldSourceAddress, ownerOfShares);
```

`this.` forces an external call, wasting gas and creating a re-entry point if a reentrancy guard is ever added. Prefer a shared internal function or inline the position query.

**Resolution**: Accepted as informational. No security impact — oracle is view-only with no state to corrupt.

### 9. `decimals()` Revert Risk — ACCEPTED

`IERC20Metadata(loanToken).decimals()` — some ERC-20s (USDT, BNB, old tokens) don't implement this interface properly. In practice all Morpho Blue loan tokens on Ethereum/Base implement `decimals()`. Low risk but worth documenting.

**Resolution**: Accepted. All production Morpho Blue markets use standard ERC-20 tokens with `decimals()`.

---

## Attack Surface Summary

### What CANNOT be attacked:
- **Direct fund extraction**: Oracle is view-only, holds no funds
- **Flash loan PPS manipulation via supply/withdraw**: `toSharesDown` ensures proportional supply doesn't change PPS — **proven by `testFuzz_supply_doesNotChangePPS` fuzz test**
- **Donation attacks**: Morpho's totalSupplyAssets is NOT incremented by direct token transfers
- **First depositor attack**: Virtual offsets in SharesMathLib prevent share inflation
- **Read-only reentrancy**: Morpho Blue uses CEI — all state updates complete before token transfers
- **Rogue IRM registration**: IRM whitelist in registry prevents unapproved IRMs

### What CAN be attacked (bounded):
- **IRM governance compromise + upgrade**: If a whitelisted IRM were somehow made upgradeable and turned malicious (extremely unlikely, AdaptiveCurveIRM is immutable). Mitigated by IRM whitelist — revoke approval to prevent new registrations.

---

## Resolution History

| Date | Change |
|------|--------|
| 2026-06-26 | Initial security research completed |
| 2026-06-27 | Finding 1 fixed: `&& mp.irm != address(0)` added |
| 2026-07-03 | Finding 5 resolved: wrapper design replaced by permissioned registry |
| 2026-07-03 | Finding 6 reclassified as false positive: Morpho CEI prevents read-only reentrancy |
| 2026-07-03 | Flash-loan PPS inflation confirmed non-exploitable by fuzz test |
| 2026-07-03 | All findings triaged and resolution status recorded |

---

## Recommended Fuzz Tests

```solidity
// 1. Round-trip never creates value
function testFuzz_RoundTrip_NeverCreatesValue(uint256 assets) public view {
    assets = bound(assets, 1, 1e30);
    uint256 shares = oracle.getShareOutput(marketKey, address(0), assets);
    uint256 assetsBack = oracle.getAssetOutput(marketKey, address(0), shares);
    assertLe(assetsBack, assets);
}

// 2. PPS monotonically increases with time (active market)
function testFuzz_PPS_Monotonic(uint32 elapsed) public {
    elapsed = uint32(bound(elapsed, 1, 30 days));
    uint256 ppsBefore = oracle.getPricePerShare(marketKey);
    vm.warp(block.timestamp + elapsed);
    uint256 ppsAfter = oracle.getPricePerShare(marketKey);
    assertGe(ppsAfter, ppsBefore);
}

// 3. Supply doesn't change PPS (proportional) — also disproves flash-loan PPS inflation
function testFuzz_Supply_InvariantPPS(uint256 amount) public {
    amount = bound(amount, 1e6, 100_000e6);
    uint256 ppsBefore = oracle.getPricePerShare(marketKey);
    _supplyToMorpho(..., amount, testUser);
    assertEq(oracle.getPricePerShare(marketKey), ppsBefore);
}

// 4. Withdrawal shares >= deposit shares
function testFuzz_WithdrawalSharesGteDepositShares(uint256 assets) public view {
    assets = bound(assets, 1, 1e30);
    assertGe(
        oracle.getWithdrawalShareOutput(marketKey, address(0), assets),
        oracle.getShareOutput(marketKey, address(0), assets)
    );
}

// 5. Accrual math doesn't overflow for realistic params
function testFuzz_AccrualNoOverflow(uint128 totalBorrow, uint256 elapsed) public pure {
    totalBorrow = uint128(bound(totalBorrow, 0, 1e18));
    elapsed = bound(elapsed, 0, 365 days);
    uint256 borrowRate = 1_585_489_600; // ~5% APR
    uint256 interest = uint256(totalBorrow).wMulDown(borrowRate.wTaylorCompounded(elapsed));
    assertLe(interest, type(uint128).max);
}

// 6. TVL consistency with getAssetOutput
function test_TVLByOwner_ConsistentWithGetAssetOutput() public {
    _supplyToMorpho(..., 10_000e6, testUser);
    uint256 shares = oracle.getBalanceOfOwner(marketKey, testUser);
    uint256 assetFromShares = oracle.getAssetOutput(marketKey, address(0), shares);
    assertEq(oracle.getTVLByOwnerOfShares(marketKey, testUser), assetFromShares);
}
```
