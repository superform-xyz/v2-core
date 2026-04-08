# MorphoLendHook Interview Notes

## Feature Summary
Create a `MorphoLendHook` for the lender side of Morpho Blue markets. Unlike the existing borrower-side hooks (`MorphoSupplyHook` = `supplyCollateral`, `MorphoBorrowHook` = `borrow`), this hook calls `supply()` on Morpho Blue, allowing users to lend assets to a market and earn interest from borrowers.

## Key Decisions

### Scope: Single Hook Only
- **MorphoLendHook** — calls `IMorphoBase.supply(marketParams, assets, 0, onBehalf, "")`
- No new withdrawal hook — existing `MorphoWithdrawHook` already calls `withdraw()` which handles lender withdrawal with both assets AND shares support
- No combined hooks — keep individual hooks, chain as needed
- No oracle for now — focus on hook only, oracle to be designed separately later

### Naming
- `MorphoLendHook` — clear distinction from `MorphoSupplyHook` (which supplies collateral for borrowing)

### Data Layout
- Keep all MarketParams fields (lltv is required as market identifier, not a position parameter)
- Layout: `loanToken(20)|collateralToken(20)|oracle(20)|irm(20)|amount(32)|lltv(32)|usePrevHookAmount(1)`
- Same fields as MorphoSupplyHook but calling `supply()` instead of `supplyCollateral()`
- Generic — works with any Morpho Blue market

### Inheritance
- Do NOT create a new base class
- Can extend existing `BaseMorphoLoanHook` for `_generateMarketParams` helper reuse

### Withdrawal
- Existing `MorphoWithdrawHook` already supports both `assets` and `shares` parameters
- For full position withdrawal: pass shares, set assets to 0
- For partial withdrawal: pass assets, set shares to 0
- `Redeem4626VaultHook` pattern uses shares for outflow — consistent approach

### Testing
- E2E test with real deployed SuperVaultStrategy on mainnet fork
- Follow `MorphoSuperVaultE2E.t.sol` pattern
- Test: lend → verify supply shares created → withdraw → verify position closed

## Technical Context

### Morpho Blue Supply (Lender Side)
```solidity
function supply(
    MarketParams memory marketParams,
    uint256 assets,    // amount to lend
    uint256 shares,    // OR shares to mint (set one to 0)
    address onBehalf,  // position owner
    bytes memory data  // callback data (empty for us)
) external returns (uint256 assetsSupplied, uint256 sharesSupplied);
```

### PPS Behavior
- Lender supply shares appreciate as interest accrues from borrowers
- PPS = totalSupplyAssets / totalSupplyShares (monotonically increasing)
- Fundamentally different from collateral (constant) and borrow (debt grows)
- Oracle design deferred to separate spec

### Existing Hook Architecture
- All Morpho hooks in `src/hooks/loan/morpho/`
- `BaseMorphoLoanHook` provides `_generateMarketParams`, `_decodeHookData`, balance helpers
- `BaseHook` provides `_buildHookExecutions`, `_preExecute`, `_postExecute`, `_setOutAmount`, `getOutAmount`
- Hook execution lifecycle: `setExecutionContext` → `build` → `execute` → `resetExecutionState` → `getOutAmount`

### Key Difference: supply() vs supplyCollateral()
| Function | Side | Token Approved | Yield | Shares |
|----------|------|---------------|-------|--------|
| `supplyCollateral()` | Borrower | collateralToken | None | collateral (uint128) |
| `supply()` | Lender | loanToken | Yes (interest) | supplyShares (uint256) |

For MorphoLendHook:
1. Approve loanToken to Morpho (reset + set)
2. Call `supply(marketParams, amount, 0, account, "")`
3. Track outAmount as loanToken balance change (amount spent)
