# Security Analysis Report

## Metadata
- **Target:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol`
- **Mode:** review
- **Date:** 2026-06-25
- **Contract Types Detected:** AMM/DEX Oracle, Vault Accounting
- **Files Analyzed:** 1
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 2 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 3 | No |

## Verdict
**FAIL** - 2 blocking findings (P1) should be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [P1-1] Intermediate Overflow in Cross-Rate Computation

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:209`
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** The cross-rate computation `price1 * FEED0_SCALE` and `price0 * FEED1_SCALE` are computed as intermediate products *before* being passed to `Math.mulDiv`. If both `price1` and `FEED0_SCALE` are large (e.g., an 18-decimal Chainlink feed with answer ~1e18), this multiplication can overflow `uint256` before `mulDiv` even executes.
- **Exploit Scenario:** With an 18-decimal Chainlink feed returning a large price answer (some L2 feeds use 18 decimals), `price1 * FEED0_SCALE` could be `1e18 * 1e18 = 1e36`, which is safe. However, if a custom aggregator or wrapped feed uses higher precision or returns values > 1e30, the product `price * FEED_SCALE` can overflow uint256. While standard Chainlink 8-decimal feeds are safe (`price * 1e8` won't overflow), deploying with non-standard feeds breaks silently.
- **Vulnerable Code:**
  ```solidity
  uint256 p1InToken0 = Math.mulDiv(price1 * FEED0_SCALE, TOKEN0_SCALE, price0 * FEED1_SCALE);
  ```
- **Secure Pattern:**
  ```solidity
  // Use nested mulDiv to avoid any intermediate overflow
  uint256 p1InToken0 = Math.mulDiv(
      Math.mulDiv(price1, FEED0_SCALE, FEED1_SCALE),
      TOKEN0_SCALE,
      price0
  );
  ```
  Or restructure to keep all multiplications inside `mulDiv`:
  ```solidity
  // numerator = price1 * FEED0_SCALE * TOKEN0_SCALE
  // denominator = price0 * FEED1_SCALE
  uint256 p1InToken0 = Math.mulDiv(price1, FEED0_SCALE * TOKEN0_SCALE, price0 * FEED1_SCALE);
  ```
  Note: The second form still has `FEED0_SCALE * TOKEN0_SCALE` and `price0 * FEED1_SCALE` as intermediate products. The nested `mulDiv` approach is safest.
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)

### [P1-2] Potential Overflow in `2 * sqrtValue`

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:230`
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** `2 * sqrtValue` is computed before passing to `Math.mulDiv`. If `sqrtValue` exceeds `type(uint256).max / 2` (~5.78e76), this overflows. While extreme, the overflow fallback path on line 226 computes `sqrt(r0) * sqrt(r1ValueInToken0)`, which can produce very large values when both reserves and cross-rate are large in token0 terms.
- **Exploit Scenario:** With max reserves (uint112.max ≈ 5.19e33) and a high cross-rate, `r1ValueInToken0` could be very large. In the split-sqrt path, `sqrt(5.19e33) * sqrt(very_large)` could exceed `type(uint256).max / 2`. While practically unlikely for standard token pairs, the code lacks an explicit guard.
- **Vulnerable Code:**
  ```solidity
  return Math.mulDiv(2 * sqrtValue, ONE_LP, totalSupply);
  ```
- **Secure Pattern:**
  ```solidity
  // Move the constant 2 into the mulDiv numerator to avoid intermediate overflow
  return Math.mulDiv(sqrtValue, 2 * ONE_LP, totalSupply);
  ```
  Since `2 * ONE_LP = 2e18` which is well within uint256 range, this is always safe.
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)

---

## P2 Findings (Medium - Should Fix)

### [P2-1] No Constructor Validation for `maxStaleness_`

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:95`
- **SWC:** N/A
- **Category:** Logic
- **Description:** `maxStaleness_` is accepted without validation. Setting it to 0 would cause all Chainlink reads to revert (since `block.timestamp - updatedAt > 0` is almost always true). Setting it to `type(uint256).max` effectively disables staleness checking. Both are likely deployment misconfigurations.
- **Vulnerable Code:**
  ```solidity
  MAX_STALENESS = maxStaleness_;
  ```
- **Secure Pattern:**
  ```solidity
  if (maxStaleness_ == 0 || maxStaleness_ > 86_400) revert INVALID_STALENESS();
  MAX_STALENESS = maxStaleness_;
  ```
  Alternatively, use a more permissive upper bound like `7 days` if needed for infrequently-updated feeds.
- **Reference:** vulnerabilities.md Section 15 (Code Quality)

### [P2-2] No Token-Pair Consistency Validation

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:89-110`
- **SWC:** N/A
- **Category:** Logic
- **Description:** The constructor does not verify that `token0_` and `token1_` match the actual token0/token1 of the LP pair. If swapped, the cross-rate is inverted and PPS is wrong. Since the oracle is immutable, a misconfiguration requires redeployment.
- **Current Code:** Constructor accepts `token0_`, `token1_` but doesn't cross-check against any pair.
- **Recommendation:** This is a configuration-time risk only. Document deployment requirements clearly. Adding a pair address to the constructor for validation would change the architecture (the oracle doesn't currently know which pair it serves until `getPricePerShare` is called). Evaluate tradeoff.

### [P2-3] Missing Chainlink `minAnswer`/`maxAnswer` Circuit Breaker Check

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:278-283`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** Chainlink aggregators have built-in `minAnswer` and `maxAnswer` bounds. During extreme market events (e.g., LUNA crash), prices can hit these bounds and the feed returns a clamped value instead of the actual price. The oracle should check if the returned answer equals `minAnswer` or `maxAnswer` and revert if so, as the price is unreliable.
- **Exploit Scenario:** During a token depeg, Chainlink returns `minAnswer` (e.g., $0.10 for a stablecoin that's actually worth $0.001). The oracle would use $0.10 as the price, overvaluing LP positions and allowing arbitrage against the SuperVault.
- **Vulnerable Code:**
  ```solidity
  (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
  if (answer <= 0) revert INVALID_PRICE();
  ```
- **Secure Pattern:**
  ```solidity
  (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
  if (answer <= 0) revert INVALID_PRICE();
  // Check circuit breaker bounds (requires reading from aggregator)
  // Note: minAnswer/maxAnswer are on the aggregator, not the proxy
  // For production, consider an off-chain monitoring approach instead
  ```
- **Reference:** vulnerabilities.md Section 4 (Oracle Manipulation)

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Split-Sqrt Precision Loss (Documented, Acceptable)

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:224-226`
- **SWC:** N/A
- **Category:** Arithmetic
- **Description:** The overflow fallback `sqrt(r0) * sqrt(r1ValueInToken0)` can differ from `sqrt(r0 * r1ValueInToken0)` by up to 1 wei in the sqrt result. For extremely large values, this could compound to a very small relative error. The code documents this tradeoff. The error is < 1 part in 1e15 for realistic inputs.
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)

### [P3-2] L2 Sequencer Uptime Check Not Included

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:278-283`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** On L2 chains (Base, Arbitrum, Optimism), Chainlink provides a sequencer uptime feed. If the L2 sequencer goes down and comes back up, stale prices may appear fresh (updatedAt resets). Chainlink recommends checking the sequencer uptime feed and enforcing a grace period after sequencer restart.
- **Recommendation:** This is an operational concern best addressed at the deployment/architecture layer rather than in every oracle contract. Options: (a) add L2 sequencer check to this oracle, (b) add a wrapper/middleware that checks sequencer before calling any Chainlink-based oracle, (c) handle at the SuperVault operations layer. Option (b) or (c) is recommended to avoid code duplication across oracle contracts.
- **Reference:** Chainlink L2 Sequencer Uptime documentation

### [P3-3] `roundId` and `answeredInRound` Not Validated

- **File:** `src/accounting/oracles/UniV2LPYieldSourceOracle.sol:279`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** The `latestRoundData()` return values `roundId` and `answeredInRound` are discarded. Some Chainlink integrations check `answeredInRound >= roundId` to ensure the answer is from the current round. However, with `latestRoundData()` (as opposed to `getRoundData()`), this check is redundant since the latest round always has `answeredInRound == roundId`. The staleness check via `updatedAt` is sufficient.
- **Reference:** vulnerabilities.md Section 4 (Oracle)

---

## Attack Surface Summary

### External Entry Points
All functions are `view`/`pure` — no state modifications, no value transfers:
- `getPricePerShare(address)` — core pricing
- `getShareOutput(address, address, uint256)` — LP tokens for assets
- `getWithdrawalShareOutput(address, address, uint256)` — LP tokens to burn (ceil)
- `getAssetOutput(address, address, uint256)` — assets for LP tokens
- `getTVL(address)` — total value locked
- `getTVLByOwnerOfShares(address, address)` — user TVL
- `getBalanceOfOwner(address, address)` — LP balance
- `decimals(address)` — always 18
- Inherited batch methods from `AbstractYieldSourceOracle`

### Oracle Dependencies
- **Chainlink FEED0** (token0/USD) — `IAggregatorV3.latestRoundData()`
- **Chainlink FEED1** (token1/USD) — `IAggregatorV3.latestRoundData()`
- Both feeds validated for: positive answer, staleness within `MAX_STALENESS`

### Cross-Contract Interactions
- `IUniswapV2Pair.getReserves()` — pool reserves (view)
- `IUniswapV2Pair.totalSupply()` — LP supply (view)
- `IUniswapV2Pair.balanceOf(address)` — LP balance (view)
- All interactions are read-only. No reentrancy risk.

### Upgrade Mechanisms
- **None** — fully immutable contract with no admin functions, no proxy, no state variables

---

## Coding Standards Findings

### Compliant
- Solidity 0.8.30 with locked pragma
- Custom errors instead of revert strings
- NatSpec on all public/external functions
- Checks-Effects-Interactions pattern (N/A — all view functions)
- OpenZeppelin Math library usage
- Immutable design — no state-changing functions

### Minor Notes
- `TOKEN1_DECIMALS` stored as `uint8` while all other precomputed values are scales (`10**decimals`). Could store `TOKEN1_SCALE = 10 ** token1.decimals()` for consistency and gas savings (avoids `10 ** uint256(TOKEN1_DECIMALS)` exponentiation on each call)
- Constructor could benefit from emitting an initialization event for deployment verification, though this is optional for immutable contracts

---

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 4 (Oracle), 5 (Flash Loans), 6 (MEV), 8 (Unchecked Returns), 9 (abi.encodePacked), 10 (Token Integration), 15 (Code Quality), 22 (Vault Accounting), 28 (Donation Attacks), 31 (AMM)
- **Coding rules validated:** Pragma lock, custom errors, NatSpec, visibility modifiers, OZ imports
- **Historical exploits cross-referenced:** Alpha Homora oracle design, Warp Finance LP manipulation (2020), Harvest Finance (2020)
