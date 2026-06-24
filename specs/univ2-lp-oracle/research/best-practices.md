# Best Practices: UniV2 LP Token Oracle

## Alpha Homora Fair Pricing Formula

### Formula
```
LP_price = 2 * sqrt((r0 * p0) * (r1 * p1)) / totalSupply
```

### Why Flash-Loan Resistant
- Naive pricing: `LP_value = (r0 * p0 + r1 * p1) / totalSupply` - manipulable via reserve manipulation
- Fair pricing uses sqrt of product instead of sum - immune to reserve ratio changes
- Flash loans can change r0/r1 ratio but sqrt(r0*r1) stays constant (constant product invariant)
- External oracle prices (p0, p1) are not manipulable within a single tx (when using TWAP/Chainlink)

### Token0 Denomination Simplification
When denominating in token0: p0 = 1 (price of token0 in itself)
```
LP_price_in_token0 = 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
```
Where `p1_in_token0 = IOracle.getQuote(10^token1Decimals, token1, token0)`

## Decimal Normalization

### Challenge
- token0 can be 6 decimals (USDC), token1 can be 18 decimals (WETH)
- reserves are in token-native decimals
- IOracle.getQuote returns in quote token decimals (token0 decimals)
- LP tokens are always 18 decimals
- Output (getPricePerShare) must be in token0 decimals

### Strategy
1. Normalize reserves to 18 decimals before sqrt
2. Normalize oracle price output
3. Use Math.mulDiv for safe multiplication
4. Scale final result to token0 decimals

### Overflow Considerations
- reserves are uint112 (max ~5.19e33)
- r0 * r1 can be up to ~2.69e67 - fits in uint256 (max ~1.15e77)
- After scaling to 18 decimals: need to be careful
- Use Math.mulDiv(r0, r1_scaled, 1) to prevent intermediate overflow

## Known Vulnerabilities

### Warp Finance (2020) - $7.7M
- Used naive LP pricing (sum of reserves * prices / totalSupply)
- Attacker flash-loaned to manipulate reserve ratios
- Fixed by Alpha Homora fair pricing formula

### Mitigation
- ALWAYS use fair pricing formula
- NEVER use raw reserves for pricing
- Use external oracle (not spot) for underlying token prices
- Check oracle staleness

## Implementation Best Practices

1. Use `Math.mulDiv()` for all multiplications followed by division
2. Use `Math.sqrt()` from OpenZeppelin - battle-tested
3. Hardcode LP decimals as 18 (all UniV2 pairs use 18)
4. Validate oracle is not returning 0 prices
5. No admin functions (fully immutable)
