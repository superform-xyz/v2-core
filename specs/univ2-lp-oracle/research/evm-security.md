# EVM Security Research: UniV2 LP Token Oracle

## Relevant Vulnerability Patterns

### Oracle Manipulation (Section 4)
- **4.1 Spot Price Manipulation**: UniV2 reserves can be manipulated via flash loans. MITIGATED by Alpha Homora formula.
- **4.2 TWAP vs Spot**: Using external IOracle (not on-chain reserves) for underlying prices. IOracle is expected to use TWAP or Chainlink.
- **4.3 Stale Prices**: IOracle could return stale data. MITIGATED by adding staleness awareness (delegate to IOracle implementation).

### Flash Loan Attacks (Section 5)
- **5.1 Reserve Manipulation**: Classic attack on naive LP pricing. MITIGATED by fair pricing formula.
- **5.2 Donation Attacks**: Sending tokens directly to pair can change reserves. MITIGATED by sqrt-based formula.

### Token Decimal Issues (Section 10)
- **10.4 Tokens with >18 decimals**: Could cause overflow in formula. MITIGATED by using Math.mulDiv.
- **10.1-10.3**: Fee-on-transfer and rebasing tokens not supported (out of scope).

### Reentrancy (Section 1)
- **1.4 Read-only Reentrancy**: Oracle is view-only, no state changes. LOW RISK.
- All external calls are view functions (getReserves, getQuote, balanceOf). NO REENTRANCY RISK.

## Exploit Precedents

| Protocol | Year | Loss | Attack | Relevance |
|----------|------|------|--------|-----------|
| Warp Finance | 2020 | $7.7M | Naive LP pricing via reserves | Direct - exactly what fair pricing prevents |
| Harvest Finance | 2020 | $34M | Oracle manipulation | Related - shows importance of manipulation-resistant pricing |
| Alpha Homora | 2021 | $37M | Re-entrancy in lending, NOT oracle | Their formula was sound; exploit was elsewhere |

## Attack Surface Map

### External Calls
1. `IUniswapV2Pair(pair).getReserves()` - view, trusted
2. `IUniswapV2Pair(pair).token0/token1()` - view, trusted
3. `IOracle(oracle).getQuote()` - view, trusted but could revert or return stale data
4. `IERC20(pair).balanceOf()` - view, trusted
5. `IERC20(pair).totalSupply()` - view, trusted
6. `IERC20Metadata(token).decimals()` - view, trusted

### Arithmetic Risks
1. **Overflow in r0 * r1**: uint112 * uint112 fits in uint256 (224 bits < 256 bits). SAFE.
2. **Overflow after scaling**: Need Math.mulDiv when multiplying scaled values
3. **sqrt precision**: OZ Math.sqrt rounds down. Acceptable for pricing (conservative).
4. **Division by totalSupply**: Could be 0 on fresh pairs. Need zero-check.

### Data Staleness
1. **Reserve staleness**: getReserves returns latest reserves (no staleness issue for reserves themselves)
2. **Oracle price staleness**: IOracle could return outdated prices. Mitigation delegated to IOracle implementation.

## Recommended Security Patterns

1. **Fair pricing formula** - prevents reserve manipulation
2. **Math.mulDiv** throughout - prevents overflow
3. **Zero-checks** on totalSupply and oracle prices
4. **No state changes** - pure view oracle, no reentrancy risk
5. **Immutable oracle address** - no governance attack surface

## Testing Recommendations

### Fuzz Tests
1. **Reserve ranges**: Fuzz (r0, r1) from 1 wei to type(uint112).max
2. **Decimal combos**: Test (6,6), (6,18), (18,6), (18,18), (8,18) decimal pairs
3. **Oracle price ranges**: Fuzz prices from very small to very large
4. **Invariant**: getPricePerShare * totalSupply should approximate total pool value

### Edge Cases
1. Zero totalSupply (empty pool)
2. Extremely imbalanced reserves
3. Very small oracle prices (near zero)
4. Very large oracle prices
5. Same token as both token0 and token1 (shouldn't happen in UniV2 but validate)
