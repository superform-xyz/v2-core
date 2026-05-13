# Best Practices: DETHYieldSourceOracle

## Architecture Decisions

| Decision | Recommendation | Reference |
|----------|---------------|-----------|
| yieldSourceAddress | AsyncRedeemer address | Matches hook pattern |
| Price source | Machine.convertToAssets() | Not external AMM |
| Share token discovery | Immutable constructor resolution | Gas optimization |
| Pending tracking | ERC-721 enumeration or requestId scanning | Depends on AsyncRedeemer interface |
| Error handling | R1 for pricing, R2 for async TVL | ERC7540 oracle pattern |

## Function-by-Function Guide

| Function | Source | Rounding | Error Policy |
|----------|--------|----------|-------------|
| `decimals()` | DETH_TOKEN.decimals() | N/A | R1 (hard revert) |
| `getShareOutput()` | Machine.convertToShares() | Floor | R1 |
| `getWithdrawalShareOutput()` | Manual mulDiv inverse | Ceil | R1 |
| `getAssetOutput()` | Machine.convertToAssets() | Floor | R1 |
| `getPricePerShare()` | Machine.convertToAssets(ONE_SHARE) | Floor | R1 |
| `getBalanceOfOwner()` | DETH.balanceOf() | N/A | R1 |
| `getTVLByOwnerOfShares()` | held + pending NFTs | N/A | R1 held, R2 pending |
| `getTVL()` | Machine.totalAssets() | N/A | R1 |

## Key Patterns

1. **Use convertToAssets/convertToShares, NOT preview functions** - async vaults may revert on preview*
2. **Immutable address resolution** - store Machine, DETH, WETH in constructor
3. **R1/R2 error handling** - hard revert for pricing, graceful degradation for async TVL
4. **Ceil rounding on getWithdrawalShareOutput** - favors vault, uses Math.mulDiv
5. **Early return on zero balance** - avoid wasted external calls
6. **Bounded iteration for NFT scanning** - MAX_PENDING_REQUESTS cap
