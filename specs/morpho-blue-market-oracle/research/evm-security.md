# EVM Security Research — Morpho Blue Yield Source Oracle

## Executive Summary

`MorphoBlueYieldSourceOracle` and `MorphoBlueMarketWrapper` are **read-only** contracts that never move funds. The primary risk is not fund loss from within these contracts but rather **incorrect values reported to upstream accounting** (SuperLedger, monitoring). A wrong PPS causes wrong performance fee calculations and wrong TVL displays.

---

## Prioritized Findings

| # | Finding | Severity | Exploitable? | Status |
|---|---|---|---|---------|
| 1 | Missing `irm != address(0)` third condition in accrual skip | Low-Med | No (edge case) | Not mitigated |
| 2 | IRM returning extreme rate could inflate simulated PPS without overflow | Medium | Only via malicious IRM | Mitigated by governance whitelist |
| 3 | Dormant market (`elapsed` >> 0) with no on-chain accrual could produce inflated view PPS | Low-Med | Passive risk only | Not mitigated |
| 4 | `interest` kept as `uint256` in view sim; Morpho casts to `uint128` on-chain — silent divergence | Low | Silent misinformation | Not mitigated |
| 5 | `wrapper.morpho()` not validated against canonical Morpho address by registry | Low | Requires malicious wrapper | Registry must validate |
| 6 | ERC-777 loan token creates mid-supply read-reentrancy window | Low | Only with ERC-777 | Protected by Morpho token requirements |
| 7 | `totalBorrowShares: 0` assumption in Market struct for `borrowRateView` | Low | Only with non-AdaptiveCurveIRM | Documented assumption |
| 8 | `this.getBalanceOfOwner` external call in `getTVLByOwnerOfShares` | Info | No (no reentrancy guard) | Refactor recommended |
| 9 | `decimals()` calls IERC20Metadata — may revert for non-standard tokens (e.g. USDT) | Low | DoS of oracle | No protection |

---

## Detailed Analysis

### 1. Missing Third Accrual Condition

**Current code** (`MorphoBlueYieldSourceOracle.sol` line ~175):
```solidity
if (elapsed > 0 && s.totalBorrowAssets > 0) {
    uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt); // REVERTS if mp.irm == address(0)
```

**Canonical MorphoBalancesLib**:
```solidity
if (elapsed != 0 && market.totalBorrowAssets != 0 && marketParams.irm != address(0)) {
```

**Impact**: A market with `irm == address(0)` and non-zero borrows (theoretical — Morpho Blue doesn't allow borrowing with a zero-IRM, but a hypothetical edge case) would cause the oracle to revert. Safe failure (revert, not wrong value), but not bit-exact with MorphoBalancesLib. **Fix**: Add `&& mp.irm != address(0)` to the condition.

### 2. IRM Extreme Rate

The AdaptiveCurveIRM has `MAX_RATE_AT_TARGET` hard caps. Governance-whitelisted IRMs are immutable on Morpho Blue, making a post-deployment malicious IRM essentially impossible in practice. The wrapper constructor's `idToMarketParams` validation ensures the IRM was governance-approved at market creation.

If a pathological IRM returns a rate high enough to cause overflow: Solidity 0.8.x reverts on overflow → **DoS, not PPS manipulation**. This is acceptable failure behavior.

### 3. Stale Dormant Market

For a market with `totalBorrowAssets > 0` and a long `elapsed` (weeks without any on-chain interaction), `wTaylorCompounded` compounds the rate over that window. This produces an accurate result — the oracle correctly shows what suppliers have earned. It's not a manipulation risk.

The risk is that the **on-chain accrual** would cast `interest.toUint128()` and could overflow, bricking the market. The oracle's view simulation (using `uint256` throughout) would not catch this and would return a large number instead of a revert, creating silent divergence. This scenario requires unrealistically high APRs sustained over long periods.

### 4. `interest` uint128 Divergence

On-chain: `market[id].totalBorrowAssets += interest.toUint128()` → reverts if `interest > type(uint128).max`.
Oracle: `s.totalBorrowAssets += interest` → no cast, no revert.

For a bricked market (where real accrual would revert), the oracle returns a non-reverting inflated PPS. Since Morpho is immutable and markets interact frequently, this scenario is essentially theoretical.

### 5. Wrapper `morpho` Address Not Validated

The wrapper constructor validates the market exists via `idToMarketParams(id)`. It does NOT validate that `morpho_` is the canonical `0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` address. A wrapper pointing at a fake Morpho that returns non-zero addresses from `idToMarketParams` would pass construction.

**Mitigation**: The Superform registry/integration layer that registers yield source addresses should independently verify `wrapper.morpho() == CANONICAL_MORPHO_ADDRESS`.

### 6. View Reentrancy (ERC-777 Loan Token)

Morpho Blue explicitly does not support re-entrant tokens (documented in `IMorpho.sol`). Production markets use standard ERC-20 tokens. The risk is theoretical but should be documented as a known limitation.

### 7. `totalBorrowShares: 0` Assumption

Passed to `IIrm.borrowRateView()`. The production AdaptiveCurveIRM only uses utilization ratio = `totalBorrowAssets / totalSupplyAssets`. `totalBorrowShares` is unused. This is safe for all current Morpho Blue markets but would produce wrong rates for a hypothetical IRM that uses borrow shares.

### 8. `this.getBalanceOfOwner` External Call

```solidity
// getTVLByOwnerOfShares (line ~136)
uint256 shares = this.getBalanceOfOwner(yieldSourceAddress, ownerOfShares);
```

`this.` forces an external call, wasting gas and creating a re-entry point if a reentrancy guard is ever added. Prefer a shared internal function or inline the position query.

### 9. `decimals()` Revert Risk

`IERC20Metadata(loanToken).decimals()` — some ERC-20s (USDT, BNB, old tokens) don't implement this interface properly. In practice all Morpho Blue loan tokens on Ethereum/Base implement `decimals()`. Low risk but worth documenting.

---

## Attack Surface Summary

### What CANNOT be attacked:
- **Direct fund extraction**: Oracle is view-only, holds no funds
- **Flash loan PPS manipulation via supply/withdraw**: `toSharesDown` ensures proportional supply doesn't change PPS
- **Donation attacks**: Morpho's totalSupplyAssets is NOT incremented by direct token transfers
- **First depositor attack**: Virtual offsets in SharesMathLib prevent share inflation

### What CAN be attacked (bounded):
- **IRM governance compromise + upgrade**: If a whitelisted IRM were somehow made upgradeable and turned malicious (extremely unlikely, AdaptiveCurveIRM is immutable)
- **Registry accepting unvalidated wrappers**: Wrapper pointing at fake Morpho — mitigated by registry-level `morpho` address validation

---

## Recommended Fuzz Tests

```solidity
// 1. Round-trip never creates value
function testFuzz_RoundTrip_NeverCreatesValue(uint256 assets) public view {
    assets = bound(assets, 1, 1e30);
    uint256 shares = oracle.getShareOutput(address(wrapper), address(0), assets);
    uint256 assetsBack = oracle.getAssetOutput(address(wrapper), address(0), shares);
    assertLe(assetsBack, assets);
}

// 2. PPS monotonically increases with time (active market)
function testFuzz_PPS_Monotonic(uint32 elapsed) public {
    elapsed = uint32(bound(elapsed, 1, 30 days));
    uint256 ppsBefore = oracle.getPricePerShare(address(wrapper));
    vm.warp(block.timestamp + elapsed);
    uint256 ppsAfter = oracle.getPricePerShare(address(wrapper));
    assertGe(ppsAfter, ppsBefore);
}

// 3. Supply doesn't change PPS (proportional)
function testFuzz_Supply_InvariantPPS(uint256 amount) public {
    amount = bound(amount, 1e6, 100_000e6);
    uint256 ppsBefore = oracle.getPricePerShare(address(wrapper));
    _supplyToMorpho(..., amount, testUser);
    assertEq(oracle.getPricePerShare(address(wrapper)), ppsBefore);
}

// 4. Withdrawal shares >= deposit shares
function testFuzz_WithdrawalSharesGteDepositShares(uint256 assets) public view {
    assets = bound(assets, 1, 1e30);
    assertGe(
        oracle.getWithdrawalShareOutput(address(wrapper), address(0), assets),
        oracle.getShareOutput(address(wrapper), address(0), assets)
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
    uint256 shares = oracle.getBalanceOfOwner(address(wrapper), testUser);
    uint256 assetFromShares = oracle.getAssetOutput(address(wrapper), address(0), shares);
    assertEq(oracle.getTVLByOwnerOfShares(address(wrapper), testUser), assetFromShares);
}
```
