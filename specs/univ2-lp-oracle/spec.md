# UniV2 LP Token Yield Source Oracle Spec

## Metadata
- Project: v2-core
- Milestone: Oracle Expansion
- Linear Issue: N/A
- Interview Date: 2026-06-24
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Create a Uniswap V2 LP Token Yield Source Oracle that extends `AbstractYieldSourceOracle` and prices LP tokens using the Alpha Homora fair pricing formula: `LP_price = 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply`. This formula is flash-loan resistant because `sqrt(r0 * r1)` is invariant under constant-product swaps, and external oracle prices (via IOracle/EIP-7726) are not manipulable within a single transaction.

The oracle supports all V2-compatible DEX forks (SushiSwap, PancakeSwap, etc.) since they share the `IUniswapV2Pair` interface. It denominates all values in token0, is fully immutable (no admin, no pause, no upgrade), and handles arbitrary decimal combinations (6/6, 6/18, 18/18, etc.).

## Requirements

### Functional
1. Extend `AbstractYieldSourceOracle` and implement all 8 abstract methods
2. Use Alpha Homora fair pricing formula for `getPricePerShare`
3. Support all V2-compatible pairs (Uniswap, Sushi, Pancake, etc.)
4. Denominate all outputs in token0 terms
5. Handle all decimal combinations via `Math.mulDiv` normalization
6. Accept `IOracle` (EIP-7726) as constructor immutable for underlying token pricing
7. Revert with custom errors on zero totalSupply or zero oracle price

### Non-Functional
- Fully immutable: no admin, pause, or upgrade functions
- All functions are view-only (no state changes, no reentrancy risk)
- `Math.mulDiv` and `Math.sqrt` from OpenZeppelin throughout

## Technical Design

### Architecture

```
UniV2LPYieldSourceOracle
├── extends AbstractYieldSourceOracle
├── immutable: ORACLE (IOracle, EIP-7726)
├── immutable: SUPER_LEDGER_CONFIGURATION (inherited)
└── methods:
    ├── decimals() → 18 (hardcoded, all UniV2 LP)
    ├── getPricePerShare() → fair pricing formula
    ├── getShareOutput() → assetsIn * 1e18 / pps
    ├── getWithdrawalShareOutput() → assetsIn * 1e18 / pps (ceil)
    ├── getAssetOutput() → sharesIn * pps / 1e18
    ├── getTVLByOwnerOfShares() → balance * pps / 1e18
    ├── getTVL() → totalSupply * pps / 1e18
    └── getBalanceOfOwner() → pair.balanceOf(owner)
```

### Core Formula (getPricePerShare)
```
token0 = pair.token0()
token1 = pair.token1()
(r0, r1, _) = pair.getReserves()
p1 = IOracle.getQuote(10^token1Dec, token1, token0)

k = r0 * r1                                     // safe: uint112 * uint112 = 224 bits
scaledProduct = mulDiv(k, p1, 10^token1Dec)      // normalize to token0^2 precision
sqrtValue = Math.sqrt(scaledProduct)             // result in token0 precision

PPS = mulDiv(2 * sqrtValue, 1e18, totalSupply)   // per 1e18 LP tokens
```

### Data Model
No new storage. Oracle is stateless — all data fetched from:
- `IUniswapV2Pair` (reserves, tokens, totalSupply, balances)
- `IOracle` (token1 → token0 price)
- `IERC20Metadata` (token decimals)

### Files to Create
1. `src/vendor/uniswap/IUniswapV2Pair.sol` — Extended V2 pair interface
2. `src/accounting/oracles/UniV2LPYieldSourceOracle.sol` — Oracle implementation
3. `test/mocks/MockUniswapV2Pair.sol` — Mock pair for unit tests
4. `test/unit/accounting/oracles/UniV2LPYieldSourceOracle.t.sol` — Tests

### Files to Modify
1. `script/utils/Constants.sol` — Add oracle key/salt
2. `script/DeployV2Core.s.sol` — Add to deployment

## Implementation Plan

### Phase 1: Core
- [ ] Create `IUniswapV2Pair` vendor interface
- [ ] Implement `UniV2LPYieldSourceOracle` with all 8 methods
- [ ] Create `MockUniswapV2Pair` for testing
- [ ] Write unit tests (formula correctness, decimal combos, edge cases, zero guards)

### Phase 2: Advanced Testing
- [ ] Fuzz tests (reserve ranges, price ranges, overflow resistance)
- [ ] Invariant tests (swap invariance, share-asset round trip, PPS consistency)
- [ ] Fork tests against mainnet WETH/USDC pair

### Phase 3: Deployment Integration
- [ ] Add oracle key/salt to Constants.sol
- [ ] Add deployment logic to DeployV2Core.s.sol

## Test Plan
- [ ] Unit tests for: formula correctness, all 8 methods, decimal normalization (6/6, 6/18, 18/6, 18/18, 8/18), zero guards, constructor validation
- [ ] Fuzz tests for: arithmetic overflow resistance, reserve range coverage, oracle price range coverage
- [ ] Invariant tests for: swap invariance (PPS unchanged when k constant), share-asset round trip (no value creation), PPS consistency (getPricePerShare == getAssetOutput(1e18))
- [ ] Fork tests for: real WETH/USDC pair on mainnet, flash loan resistance simulation

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| Naive LP pricing (reserve manipulation) | Oracle | Certain if used | Critical | Alpha Homora fair pricing formula (sqrt invariant) | Warp Finance 2020 - $7.7M |
| External oracle manipulation | Oracle | Medium | Critical | Delegate to IOracle impl (TWAP/Chainlink required) | Harvest Finance 2020 - $34M |
| Arithmetic overflow in r0*r1*p1 | Business Logic | Medium | High | Math.mulDiv throughout, normalize before sqrt | — |
| Decimal mismatch | Business Logic | Medium | High | Normalize via mulDiv(k, p1, 10^token1Dec) | — |
| Zero totalSupply / zero oracle price | Business Logic | Low | High | Custom error reverts (ZERO_TOTAL_SUPPLY, ZERO_ORACLE_PRICE) | — |
| Oracle staleness | Oracle | Medium | Medium | Let IOracle.OracleUntrustedData revert propagate | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Which DEX forks? | All V2-compatible (same interface) | Interview |
| Price source? | IOracle (EIP-7726) | Interview |
| Denomination? | Token0 | Interview |
| Decimal handling? | Full normalization, all combos | Interview |
| Oracle config? | Constructor immutable | Interview |
| Deposit/withdraw model? | Token0-only math (fair price inversion) | Interview |
| Sqrt implementation? | OZ Math.sqrt | Interview |
| Flash loan defense? | Formula inherent + staleness via IOracle | Interview |
| Governance? | Fully immutable | Interview |
| Testing? | Unit + fork + fuzz | Interview |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/univ2-lp-oracle/technical-spec.md`
