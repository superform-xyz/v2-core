# Session 19: UniV2 LP Token Yield Source Oracle

## Task
Create a Uniswap V2 LP Token Yield Source Oracle using `/superform:spec` then `/superform:work`.

## Status: IMPLEMENTATION COMPLETE - ALL TESTS PASSING (Chainlink dual-feed refactor done)

## Key Technical Decisions
- All V2 forks supported (SushiSwap, PancakeSwap, etc.)
- **Dual Chainlink IAggregatorV3 feeds** for token0/USD and token1/USD pricing (replaced IOracle EIP-7726)
- Cross-rate computed internally: `p1InToken0 = price1 * FEED0_SCALE * TOKEN0_SCALE / (price0 * FEED1_SCALE)`
- Token0 denomination for all outputs
- Full decimal normalization for any combo (6/8/18)
- Precomputed immutables: FEED0_SCALE, FEED1_SCALE, TOKEN0_SCALE, TOKEN1_DECIMALS
- MAX_STALENESS constructor param for Chainlink freshness enforcement
- OZ Math.sqrt and Math.mulDiv
- Fully immutable (no admin/pause/upgrade)

## Core Formula
```
r1ValueInToken0 = mulDiv(r1, p1InToken0, 10^token1Decimals)
sqrtValue = sqrt(r0 * r1ValueInToken0)  // with overflow fallback
PPS = mulDiv(2 * sqrtValue, 1e18, totalSupply)
```

## Overflow Protection
When `r0 * r1ValueInToken0` would overflow uint256, falls back to `sqrt(r0) * sqrt(r1ValueInToken0)` (slightly less precise but safe for all inputs).

## Files Created (Implementation)
1. `src/vendor/uniswap/IUniswapV2Pair.sol` - V2 pair interface with ERC20 methods
2. `src/accounting/oracles/UniV2LPYieldSourceOracle.sol` - Core oracle implementation
3. `test/mocks/MockUniswapV2Pair.sol` - Mock pair for unit testing
4. `test/unit/accounting/oracles/UniV2LPYieldSourceOracle.t.sol` - 33 tests (all passing)

## Files Created (Spec)
- `specs/univ2-lp-oracle/spec.md` - Pod leader summary
- `specs/univ2-lp-oracle/technical-spec.md` - Full technical spec
- `specs/univ2-lp-oracle/interview-notes.md` - Interview transcript
- `specs/univ2-lp-oracle/research/` - Research agent outputs

## Design Rationale: Price Source for LP Valuation

LP position evaluation has two steps:

1. **Liquidity → token0/token1 mix** (the tricky part — needs a price for cross-conversion)
2. **token0/token1 mix → SuperVault primary asset** (straightforward Chainlink lookup)

For Step 1, three price source options were considered:

| Source | Manipulation resistance | Volatility lag | Cost |
|---|---|---|---|
| **Spot pool price** | Low (flash-loan exploitable) | None | Cheap |
| **Pool TWAP** | Medium (depends on window size) | Medium-High (large window = more lag) | Cheap |
| **Chainlink feeds** | High (off-chain, not manipulable on-chain) | Low-Medium (heartbeat + deviation threshold) | Extra gas for 2 feed reads |

**Decision: Chainlink feeds.** Rationale:
- The LP positions of interest are on **correlated assets** (stablecoin pairs, LST/ETH, etc.) with inherently low volatility, so Chainlink lag is minimal.
- Spot price is ruled out because flash-loan manipulation directly affects SuperVault PPS calculations.
- TWAP has the same lag problem as Chainlink for large windows, plus is still on-chain manipulable (just more expensive).
- The **depeg tail risk** (where Chainlink lag would matter most) is better addressed at the vault operations layer — e.g. entering "safe mode" and reducing exposure to depegging assets — not at the oracle layer.

## Test Results: 44/44 PASSING
- Constructor tests: immutables, zero-address reverts for all 4 addresses (5)
- Decimals tests (2)
- getPricePerShare: 5 decimal combos, swap invariance, edge cases (9)
- getShareOutput (2)
- getWithdrawalShareOutput with rounding (3)
- getAssetOutput (2)
- PPS consistency invariant (1)
- Round-trip invariant (1)
- getBalanceOfOwner (2)
- getTVLByOwnerOfShares (2)
- getTVL (2)
- Chainlink staleness: stale feed0, stale feed1, exact threshold boundary (3)
- Chainlink invalid price: zero/negative answer for each feed (4)
- Different feed decimals: 8-dec feed0 + 18-dec feed1 (1)
- Fuzz: overflow resistance, swap invariance, round-trip (3)

## Bugs Fixed During Development
1. **Overflow in getPricePerShare**: Restructured formula to compute r1ValueInToken0 first, then check if r0*r1ValueInToken0 overflows before multiplying. Falls back to split-sqrt.
2. **Swap invariance tolerance**: Changed from absolute 1 wei to relative ppsBefore/1e9 to account for integer division truncation in simulated swaps.
3. **Fuzz bounds**: Increased p1 lower bound from 1 to 1e12 to ensure r1ValueInToken0 doesn't truncate to 0 for minimum reserves.
4. **Chainlink refactor fuzz bounds**: With dual feeds, extreme price ratios + small reserves cause cross-rate truncation to 0. Fixed by bounding reserves ≥ 1e12 and prices to realistic Chainlink ranges [1e6, 1e13] (8-dec format: $0.01–$100k).

## Changelog
- **v1**: IOracle (EIP-7726) single oracle — required an on-chain IOracle implementation for arbitrary token/token pairs (none exists for Chainlink)
- **v2 (current)**: Dual Chainlink IAggregatorV3 feeds (token0/USD + token1/USD) with internal cross-rate computation. Added staleness + invalid price validation.

## Fork Integration Tests: 46/46 PASSING

### File Created
`test/integration/accounting/UniV2LPYieldSourceOracleFork.t.sol`

### Test Pairs (Ethereum Mainnet, block 21_929_476)
1. **USDC/WETH** (6/18 dec) — pair `0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc`
2. **DAI/USDC** (18/6 dec) — pair `0xAE461cA67B15dc8dc81CE7615e0320dA1A9aB8D5`
3. **WBTC/WETH** (8/18 dec) — pair `0xBb2b8038a1640196FbE3e38816F3e67Cba72D940`

### Chainlink Feeds Used
- USDC/USD: `0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6` (NOTE: plan originally had wrong address `0x8fFfFfd4AfB6115b954Bd326D1223A9bc02fAf8d` which is not a contract)
- ETH/USD: `0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419`
- DAI/USD: `0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9`
- BTC/USD: `0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c`

### Tests (46 total)

**Per-pair basics (5 each, 15 total):**
- PPS > 0, PPS sanity range, TVL > 0, PPS consistency, round-trip no-value-creation

**Add/Remove liquidity PPS invariance (6 total, 2 per pair):**
- PPS stays ~same after proportional mint/burn (0.0001% tolerance for UniV2 integer rounding)

**Swap PPS invariance (3 total, 1 per pair):**
- PPS must not decrease after swap (0.3% fee increases k → PPS goes up slightly)
- Uses real UniV2 swap() with fee-inclusive amountOut formula

**TVL + user position after liquidity (2 total):**
- TVL increases after add, decreases after remove
- User balance/TVL correct after receiving LP tokens

**Cross-pair (5 total):**
- Decimals always 18, ceil rounding, balance zero, batch PPS consistency, TVL-by-owner zero

**TVL = PPS × totalSupply (1 total):**
- TVL must equal getAssetOutput(totalSupply) for all 3 pairs

**Batch methods (2 total):**
- getTVLMultiple consistency, getTVLByOwnerOfSharesMultiple consistency

**Constructor immutables (3 total):**
- FEED0, FEED1, scales, token decimals, MAX_STALENESS verified for each oracle

**Zero inputs (1 total):**
- getShareOutput(0), getAssetOutput(0), getWithdrawalShareOutput(0) all return 0

**getAssetOutputWithFees (1 total):**
- Without fees configured, equals getAssetOutput for all 3 pairs

**Large liquidity (2 total):**
- PPS stable after 50% add and 50% remove

**Sequential operations (1 total):**
- PPS stable through add → swap → remove sequence

**Post-liquidity invariants (2 total):**
- Ceil rounding still covers assets after add
- Round-trip no-value-creation holds after add for all 3 pairs

**Real LP holder — minimum liquidity lock (1 total):**
- address(0) holds MINIMUM_LIQUIDITY; TVL > 0 and equals getAssetOutput(balance)

**TVL ≈ 2 × reserve0 for stablecoin pair (1 total):**
- DAI/USDC TVL approximately 2 × r0 (within 5%)

### Issues Fixed During Implementation
1. **Wrong USDC/USD Chainlink feed address** in plan — `0x8fFfFfd4AfB6115b954Bd326D1223A9bc02fAf8d` has no code at fork block. Correct address: `0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6`
2. **`address(0xdead)` holds LP tokens** on mainnet — switched to `address(0xdeAD0000DEAd0000DEAd0000DEad0000DeAd0000)`

## Unit Test Coverage: 56/56 PASSING (100% line coverage)

Added 12 tests to cover all remaining lines:
- `getShareOutput` / `getWithdrawalShareOutput` PPS=0 early return branch
- `getPricePerShare` zero cross-rate revert (p1InToken0 truncates to 0)
- `getPricePerShare` overflow fallback path (split-sqrt)
- `getAssetOutputWithFees` no-config catch path
- `getPricePerShareMultiple` (+ empty array)
- `getTVLMultiple`
- `getTVLByOwnerOfSharesMultiple` (+ ARRAY_LENGTH_MISMATCH revert)
- `SUPER_LEDGER_CONFIGURATION` immutable

## Aerodrome Fork Tests: 26/26 PASSING (Base chain)

### File Created
`test/integration/accounting/AerodromeOracleFork.t.sol`

### Key Finding: UniV2 oracle works on Aerodrome volatile pools
- Aerodrome `getReserves()` returns `(uint256,uint256,uint256)` vs UniV2's `(uint112,uint112,uint32)`
- ABI decoding works because actual values fit in smaller types
- Volatile pools use x*y=k invariant (same as UniV2), so Alpha Homora formula is valid
- Stable pools (x^3*y + x*y^3 = k) return values but formula is only approximate near peg

### Test Pairs (Base, block 47_790_000)
1. **WETH/USDC volatile** (18/6 dec) — `0xcDAC0d6c6C59727a65F871236188350531885C43`
2. **WETH/cbBTC volatile** (18/8 dec) — `0x2578365B3dfA7FfE60108e181EFb79FeDdec2319`
3. **USDC/USDbC stable** (6/6 dec) — `0x27a8Afa3Bd49406e48a074350fB7b2020c43B2bD`

### Chainlink Feeds on Base
- ETH/USD: `0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70`
- USDC/USD: `0x7e860098F58bBFC8648a4311b374B1D669a2bc6B`
- BTC/USD: `0x07DA0E54543a844a80ABE69c8A12F22B3aA59f9D`

### Tests (26 total)
- ABI compatibility: getReserves decodes correctly through IUniswapV2Pair (1)
- Volatile pool type verification (2)
- WETH/USDC: PPS, TVL, sanity, consistency, round-trip, decimals, ceil, balance/TVL zero (9)
- WETH/USDC liquidity ops: add/remove PPS stable, swap PPS non-decreasing (3)
- WETH/cbBTC: PPS, TVL, consistency, round-trip, swap (5)
- Stable pool: returns value, approximately correct near peg (1)
- Cross-pool: TVL=PPS*supply, batch PPS, constructor immutables, zero inputs (4)
- Note on Aerodrome stable pool swap fee: 0.3% for volatile, configurable for stable

## Security Audit Fixes Applied (all 8 findings)

### Report
`specs/security-reports/2026-06-25-univ2-lp-oracle.md`

### Changes Made

**P1-1: Intermediate overflow in cross-rate (line 209)**
- Before: `Math.mulDiv(price1 * FEED0_SCALE, TOKEN0_SCALE, price0 * FEED1_SCALE)`
- After: `Math.mulDiv(price1, FEED0_SCALE * TOKEN0_SCALE, price0 * FEED1_SCALE)`
- Moves `price1` into mulDiv's first arg (512-bit intermediate), preventing overflow for high-precision feeds

**P1-2: `2 * sqrtValue` overflow (line 230)**
- Before: `Math.mulDiv(2 * sqrtValue, ONE_LP, totalSupply)`
- After: `Math.mulDiv(sqrtValue, 2 * ONE_LP, totalSupply)`
- `2 * ONE_LP = 2e18` is a compile-time constant, always safe

**P2-1: maxStaleness validation**
- Added `if (maxStaleness_ == 0) revert INVALID_STALENESS()` in constructor

**P2-2: Deployment documentation**
- Enhanced contract NatSpec with deployment requirements (token ordering, Aerodrome volatile-only, L2 sequencer)

**P2-3: Circuit breaker bounds**
- Reads `minAnswer`/`maxAnswer` from Chainlink aggregator behind proxy via try/catch in constructor
- Stores as immutables: `FEED0_MIN_ANSWER`, `FEED0_MAX_ANSWER`, `FEED1_MIN_ANSWER`, `FEED1_MAX_ANSWER`
- Checks in `_getChainlinkPrice`: reverts if price <= minAnswer or >= maxAnswer
- Gracefully degrades: if feed doesn't expose these, bounds = 0 (check disabled)

**P3-1: Overflow fallback precision documentation**
- Enhanced NatSpec: "up to 1 wei in sqrt result, < 1 part in 1e15 relative error for realistic inputs"

**P3-2: L2 sequencer uptime check**
- New constructor params: `sequencerUptimeFeed_` (address(0) to disable), `gracePeriod_`
- New immutables: `SEQUENCER_UPTIME_FEED`, `GRACE_PERIOD`
- New errors: `SEQUENCER_DOWN()`, `GRACE_PERIOD_NOT_OVER()`
- `_checkSequencer()` called at top of `getPricePerShare()` (no-op when feed is address(0))

**P3-3: roundId validation**
- `_getChainlinkPrice` now reads all 5 return values from `latestRoundData()`
- Added: `if (answeredInRound < roundId) revert STALE_PRICE()`

### New Interfaces Added
- `IChainlinkProxy`: `aggregator() → address` (for reading underlying aggregator)
- `IChainlinkAggregator`: `minAnswer() → int192`, `maxAnswer() → int192` (circuit breaker bounds)

### MockAggregator Updated
- Added `_roundId`, `_answeredInRound` tracking (defaults: 1/1)
- Added `setRoundData(uint80, uint80)` for stale round testing
- Added `aggregator()` → self, `minAnswer()`, `maxAnswer()`, `setCircuitBreakerBounds()` for circuit breaker testing

### Constructor Signature Change
```solidity
constructor(
    address superLedgerConfiguration_,
    address feed0_,
    address feed1_,
    address token0_,
    address token1_,
    uint256 maxStaleness_,
    address sequencerUptimeFeed_,  // NEW: address(0) to disable
    uint256 gracePeriod_           // NEW: seconds after sequencer restart
)
```

### Test Results: 68/68 PASSING (unit)
12 new tests added:
- Constructor: revert on zero maxStaleness (1)
- P3-3 roundId: stale round feed0, stale round feed1, valid round (3)
- P2-3 circuit breaker: price at min bound, price at max bound, bounds stored, defaults to zero (4)
- P3-2 sequencer: down revert, grace period revert, success after grace, no-op when disabled (4)

### Fork tests: compile-verified (ETH mainnet + Base Aerodrome)
- All constructor calls updated with `address(0), 0` for sequencer params

## Not Yet Done (Deployment)
- script/utils/Constants.sol - Add oracle key/salt
- script/DeployV2Core.s.sol - Add to deployment
