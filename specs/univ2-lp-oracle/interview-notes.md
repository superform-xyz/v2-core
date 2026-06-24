# UniV2 LP Token Yield Source Oracle - Interview Notes

## Date: 2026-06-24

## Feature Summary
Create a Uniswap V2 LP Token Yield Source Oracle that extends `AbstractYieldSourceOracle` and implements pricing for Uniswap V2 LP tokens using the Alpha Homora fair pricing formula:
```
LP_price = 2 * sqrt((r0 * p0) * (r1 * p1)) / totalSupply
```

## Technical Decisions

### DEX Scope
- **Decision**: All V2 forks (SushiSwap, PancakeSwap, etc.)
- **Rationale**: They all share the same `IUniswapV2Pair` interface

### Price Source for Underlying Tokens
- **Decision**: Use existing `IOracle` interface (EIP-7726, awesome-oracles)
- **Rationale**: Respect the interface other oracles are already using in the codebase
- **Note**: Will also need an IOracle implementation where pairs can be added

### Denomination
- **Decision**: Token0 denomination
- **Rationale**: Matches the "asset" concept - treat token0 as the vault's underlying asset
- `getPricePerShare()` returns LP value in token0 terms

### Token Edge Cases
- **Decision**: Full decimal normalization for any combo (6/8/18/etc.), no exotic tokens
- **Rationale**: Standard ERC20 tokens only, but handle all decimal permutations

### Oracle Configuration
- **Decision**: Constructor immutable IOracle address
- **Note**: Also need an IOracle implementation that supports adding token pairs
- Pattern: `IOracle(oracle).getQuote(amount, base, quote)`

### LP Deposit/Withdraw Model
- **Decision**: Token0-only math
- `getShareOutput()` = "how many LP tokens for X token0 worth of value"
- `getAssetOutput()` = "how much token0 value for X LP tokens"
- Simplest approach, consistent with token0 denomination

### Sqrt Implementation
- **Decision**: OpenZeppelin `Math.sqrt`
- **Rationale**: Battle-tested, already used elsewhere in codebase

### Flash Loan Resistance
- **Decision**: Formula is inherently resistant + add staleness check on IOracle
- Alpha Homora formula uses external oracle prices (not reserve-based), resistant to reserve manipulation
- Add staleness validation to catch stale price feeds

### Governance
- **Decision**: Fully immutable
- No admin functions, no pausability, no upgradability
- Deploy and forget - safest from governance attack perspective

### Testing Strategy
- **Decision**: Unit + fork + fuzz
- Unit tests: Mock IUniswapV2Pair and IOracle, test formula correctness, edge cases, decimals
- Fork tests: Test against real mainnet pairs (e.g., WETH/USDC on Uniswap V2)
- Fuzz testing: Arithmetic edge cases, overflow/underflow, extreme reserve ratios

## Architecture Notes

### Key Interface: IYieldSourceOracle
Methods to implement:
- `decimals(address)` - LP token decimals (always 18 for Uni V2)
- `getPricePerShare(address)` - Fair LP price in token0 terms
- `getShareOutput(address, address, uint256)` - LP tokens for given token0 amount
- `getWithdrawalShareOutput(address, address, uint256)` - LP tokens to burn for token0 amount
- `getAssetOutput(address, address, uint256)` - Token0 amount for given LP tokens
- `getTVLByOwnerOfShares(address, address)` - TVL in token0 for owner
- `getTVL(address)` - Total TVL in token0
- `getBalanceOfOwner(address, address)` - LP balance of owner

### Fair Pricing Formula
```
LP_price = 2 * sqrt((r0 * p0) * (r1 * p1)) / totalSupply
```
Where:
- r0, r1 = pool reserves
- p0, p1 = external oracle prices (from IOracle)
- totalSupply = LP token total supply

For token0 denomination, p0 = 1 (in its own terms), so:
```
LP_price_in_token0 = 2 * sqrt(r0 * r1 * p1_in_token0) / totalSupply
```
Where p1_in_token0 = IOracle.getQuote(1e(token1Decimals), token1, token0)

### Dependencies
- `IUniswapV2Pair` interface (getReserves, token0, token1, totalSupply, decimals)
- `IOracle` (EIP-7726) for underlying token pricing
- `OpenZeppelin Math.sqrt` for square root
- `AbstractYieldSourceOracle` base class
