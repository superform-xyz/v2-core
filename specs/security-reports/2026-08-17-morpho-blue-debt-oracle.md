# Security Analysis Report: MorphoBlueDebtOracle

## Metadata
- **Target:** `src/accounting/oracles/MorphoBlueDebtOracle.sol`
- **Mode:** review (3 parallel agents: vulnerability scanner, best practices, EVM security research)
- **Date:** 2026-08-17
- **Contract Types Detected:** General (Oracle) -- read-only oracle with external calls to Morpho Blue and IRM
- **Files Analyzed:** 1 primary + 5 dependencies
- **Solidity Version:** 0.8.30 (locked pragma)

## Summary

| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | -- |
| P1 High | 0 | -- |
| P2 Medium | 3 | No |
| P3 Low | 7 | No |

## Verdict

**PASS** -- No P0 or P1 findings. Safe to proceed.

The contract is well-written, correctly replicates Morpho Blue's borrow-side interest accrual logic, and has appropriate NatSpec documentation. The P2 findings are defense-in-depth improvements rather than exploitable vulnerabilities.

---

## Inline Scan Checklist

| # | Pattern | Status | Notes |
|---|---------|--------|-------|
| 1 | Reentrancy | PASS | All functions are `view` -- no state modifications |
| 2 | Access Control | PASS | No state-changing functions; constructor validates inputs |
| 3 | Division Before Multiplication | PASS | Uses Morpho's `SharesMathLib` (mulDivUp/mulDivDown) |
| 4 | Unchecked Return Values | PASS | No `.call()`/`.send()`/`.transfer()` |
| 5 | Missing Reentrancy Guards | PASS | All `view` -- no reentrancy surface |
| 6 | abi.encodePacked Collisions | PASS | No `abi.encodePacked` usage |
| 7 | tx.origin Authentication | PASS | No `tx.origin` usage |
| 8 | Floating Pragma | PASS | Locked to `0.8.30` |

---

## P0 Critical

None found.

## P1 High

None found.

## P2 Medium

### P2-1: No on-chain enforcement of `feePercent = 0` constraint

- **File:** `MorphoBlueDebtOracle.sol` (inherited from `AbstractYieldSourceOracle.sol:90-126`)
- **Category:** Logic Error / Misconfiguration Risk
- **Description:** The NatSpec (lines 25-29) documents that this oracle MUST NOT be configured with `feePercent > 0` because the inherited `getAssetOutputWithFees()` relies on cost-basis snapshots that debt positions never take. The entire debt balance would be treated as "profit" and fees applied to the full amount. This constraint is not enforced programmatically -- an admin misconfiguring `SuperLedgerConfiguration` could silently corrupt accounting.
- **Exploit Scenario:** Admin sets `feePercent > 0` for a `yieldSourceOracleId` backed by this debt oracle. On withdrawal, `getAssetOutputWithFees()` applies performance fees to the full debt balance, grossly overcharging and corrupting SuperLedger accounting.
- **Secure Pattern:** Override `getAssetOutputWithFees()` in `MorphoBlueDebtOracle` to bypass fee logic:
  ```solidity
  function getAssetOutputWithFees(
      bytes32, address yieldSourceAddress, address assetOut,
      address, uint256 usedShares
  ) external view override returns (uint256) {
      return getAssetOutput(yieldSourceAddress, assetOut, usedShares);
  }
  ```
- **Note:** `EulerDebtOracle` has the same gap (documented but not enforced on-chain).

### P2-2: IRM revert can DoS the oracle for a market

- **File:** `MorphoBlueDebtOracle.sol:264`
- **Category:** External Call Safety / DoS
- **Description:** `IIrm(mp.irm).borrowRateView(mp, mkt)` is called without try/catch. If the IRM reverts (bug, pause, proxy upgrade, self-destruct), all oracle functions revert for that market, bricking SuperLedger debt position reads.
- **Exploit Scenario:** A whitelisted IRM is an upgradeable proxy. After governance action, its `borrowRateView` begins reverting. All oracle queries for that market fail, preventing SuperLedger from computing debt values.
- **Mitigation in place:** The registry's `MARKET_MANAGER_ROLE` + `setIrmApproval()` whitelist limits IRM attack surface. The canonical `AdaptiveCurveIrm` is non-reverting. Residual risk is limited to proxy-upgradeable IRMs.
- **Secure Pattern (optional):** Wrap in try/catch and fall back to stale (non-accrued) state:
  ```solidity
  try IIrm(mp.irm).borrowRateView(mp, mkt) returns (uint256 _borrowRate) {
      uint256 interest = s.totalBorrowAssets.wMulDown(_borrowRate.wTaylorCompounded(elapsed));
      s.totalBorrowAssets += interest;
  } catch {
      // Fall back to stale state rather than reverting
  }
  ```
  Trade-off: stale data may be worse than reverting in some contexts.

### P2-3: 365-day elapsed cap diverges from Morpho core

- **File:** `MorphoBlueDebtOracle.sol:253-254`
- **Category:** Logic Error / Oracle Accuracy
- **Description:** The oracle caps `elapsed` to 365 days (line 254). Morpho's `_accrueInterest` has no such cap. If a market goes untouched for >365 days, the oracle underreports accrued debt. When someone eventually interacts with the market (triggering full on-chain accrual), the oracle value jumps discontinuously.
- **Mitigation in place:** The cap prevents `wTaylorCompounded` overflow (which would also affect Morpho core). Markets with >365 days inactivity are extremely rare on mainnet. The cap is a liveness trade-off: returning a value (even slightly underreported) is preferable to reverting for SuperLedger reads.
- **Assessment:** Accepted trade-off. Matches the supply-side oracle's identical cap.

---

## P3 Low

### P3-1: `decimals()` uint8 overflow for tokens with `decimals() > 249`

- **File:** `MorphoBlueDebtOracle.sol:110`
- **Description:** `IERC20Metadata(mp.loanToken).decimals() + 6` overflows `uint8` if token decimals > 249. Solidity 0.8.x reverts on overflow. No legitimate ERC-20 has decimals > 18. Same pattern exists in `MorphoBlueYieldSourceOracle`.
- **Assessment:** Theoretical only. Registry's `MARKET_MANAGER_ROLE` prevents registering such tokens.

### P3-2: No staleness indicator for oracle consumers

- **File:** `MorphoBlueDebtOracle.sol:253`
- **Description:** The oracle returns computed values regardless of how stale the underlying Morpho market data is. No function exposes `lastUpdate` to consumers for staleness checks.
- **Recommendation:** Consider adding a `getLastUpdate(address yieldSourceAddress)` view function for monitoring.

### P3-3: Fragile uint128 casting pattern

- **File:** `MorphoBlueDebtOracle.sol:259-260`
- **Description:** `uint128(s.totalBorrowAssets)` and `uint128(s.totalBorrowShares)` are cast when constructing the `Market` struct for the IRM. Currently safe (values were just assigned from uint128), but future refactoring could make this dangerous if interest is computed before the cast.
- **Recommendation:** Add inline comment asserting the invariant (already partially done at line 268-269).

### P3-4: IRM returning extreme borrow rate could overflow `wTaylorCompounded`

- **File:** `MorphoBlueDebtOracle.sol:265`
- **Description:** `borrowRate.wTaylorCompounded(elapsed)` can overflow for extreme `borrowRate * elapsed` products. The canonical `AdaptiveCurveIrm` bounds output, but custom whitelisted IRMs theoretically could not.
- **Mitigation:** IRM whitelist. Morpho core has the identical overflow risk. No additional mitigation needed.

### P3-5: Taylor approximation underestimates interest for large rate*elapsed

- **File:** `MorphoBlueDebtOracle.sol:265`
- **Description:** `wTaylorCompounded` uses a 3rd-order Taylor expansion of `e^(x*n) - 1`. For large `x*n`, the approximation underestimates the true exponential. This is a known Morpho design property and the oracle replicates it exactly.
- **Assessment:** Conservative (underreports debt). Matches Morpho core behavior.

### P3-6: Read-only reentrancy during Morpho callbacks

- **File:** `MorphoBlueDebtOracle.sol` (entire contract)
- **Description:** The oracle could be read during a Morpho callback (e.g., `onMorphoFlashLoan`). Morpho's checks-effects-interactions pattern ensures stored state is consistent before callbacks. Superform's hooks pass empty callback data, preventing reentrancy through Morpho's callback mechanism.
- **Assessment:** Not exploitable. Multiple layers of defense.

### P3-7: Flash loan oracle manipulation (contextual)

- **File:** `MorphoBlueDebtOracle.sol` (entire contract)
- **Description:** An attacker could flash borrow to inflate `totalBorrowAssets`/`totalBorrowShares`, then read the oracle during the callback. The oracle would reflect inflated values. However, SuperLedger accounting decisions are made off-chain by the bundler and validated on-chain, not computed on-chain from oracle values in a single transaction.
- **Assessment:** Not exploitable in the current architecture. The oracle's `toAssetsUp` rounding means inflated state overreports debt (conservative).

---

## Interest Accrual Correctness Verification

The oracle's `_getAccruedBorrowState()` was verified against Morpho Blue's canonical `_accrueInterest`:

| Aspect | Morpho Core | MorphoBlueDebtOracle | Match? |
|--------|------------|---------------------|--------|
| Rate function | `IIrm.borrowRate()` (state-modifying) | `IIrm.borrowRateView()` (view) | Correct for view context |
| Interest formula | `totalBorrowAssets.wMulDown(rate.wTaylorCompounded(elapsed))` | Same | Bit-exact |
| Borrow assets update | `totalBorrowAssets += interest` | Same | Bit-exact |
| Borrow shares update | Not modified | Not modified | Correct |
| Fee share accrual | Only on supply side | Omitted (correct) | Intentional |
| Market struct for IRM | Full 6-field struct | Full 6-field struct | Matching |
| Elapsed cap | None | 365 days | Divergence (P2-3) |

**Conclusion:** Bit-exact with Morpho's logic for the borrow side, with the single documented divergence (365-day cap).

---

## Cross-Oracle Consistency (Debt vs Supply)

| Aspect | MorphoBlueDebtOracle | MorphoBlueYieldSourceOracle | Assessment |
|--------|---------------------|----------------------------|------------|
| `decimals()` | `loanToken.decimals() + 6` | Same | Consistent |
| `getShareOutput` | `toSharesDown` | `toSharesDown` | Consistent |
| `getWithdrawalShareOutput` | `toSharesUp` | `toSharesUp` | Consistent |
| `getAssetOutput` | `toAssetsUp` | `toAssetsDown` | Intentionally different (documented) |
| `getPricePerShare` | `toAssetsUp` | `toAssetsDown` | Intentionally different (documented) |
| `getBalanceOfOwner` | `borrowShares` | `supplyShares` | Correct per Morpho |
| Fee share accrual | Omitted | Present | Correct for borrow vs supply |
| Elapsed cap | 365 days | 365 days | Consistent |
| REGISTRY immutable | Yes | Yes | Consistent |

---

## Attack Surface Summary

- **External Entry Points:** 8 public/external view functions (decimals, getPricePerShare, getShareOutput, getWithdrawalShareOutput, getAssetOutput, getBalanceOfOwner, getTVLByOwnerOfShares, getTVL) + inherited batch methods and `getAssetOutputWithFees`
- **Value Transfer Points:** None (read-only oracle, no ETH/token transfers)
- **Oracle Dependencies:** Reads from Morpho Blue's `market()` and `position()` stored state
- **Cross-Contract Interactions:** `REGISTRY.getMarketInfo()`, `IMorphoStaticTyping.market()`, `IMorphoStaticTyping.position()`, `IIrm.borrowRateView()`, `IERC20Metadata.decimals()`
- **Upgrade Mechanisms:** None (no proxy, no admin functions, immutable REGISTRY)

---

## Coding Standards Compliance

| Check | Status |
|-------|--------|
| Locked pragma | PASS (`0.8.30`) |
| Custom errors (no require strings) | PASS |
| NatSpec on all public/external | PASS (`@inheritdoc` + `@dev`) |
| Import organization | PASS (grouped: external, vendor, superform) |
| Naming conventions | PASS (UPPER_CASE constants, camelCase functions, trailing underscore params) |
| Visibility modifiers | PASS |
| Immutability | PASS (`REGISTRY` is immutable) |
| Event emission | N/A (no state changes) |
| Checks-Effects-Interactions | N/A (no state changes) |

---

## Recommendations (Priority Order)

1. **(P2-1) Override `getAssetOutputWithFees()`** to programmatically enforce the no-fee constraint for debt positions, rather than relying on NatSpec documentation alone.
2. **(P2-2) Document IRM proxy-upgrade risk** in operational procedures. Consider monitoring IRM health with periodic `borrowRateView` calls.
3. **(P2-3) No code change needed** for elapsed cap -- accepted trade-off, well-documented.
4. **(P3-2) Consider adding** a `getLastUpdate()` view function for monitoring staleness.
