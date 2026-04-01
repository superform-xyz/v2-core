# Best Practices: Morpho Blue supply()

## Key Findings

### supply() Function
- Use `assets` parameter with `shares = 0` for supply operations
- Morpho auto-accrues interest before computing shares
- Callback not invoked when data = "" (no reentrancy risk)
- Token pull happens AFTER state updates (flash-supply pattern)

### Approval Pattern
- Reset-then-set: approve(0) + approve(amount) (handles USDT)
- Add trailing approve(morpho, 0) after supply as defense-in-depth
- Total: 4 executions (approve 0, approve amount, supply, approve 0)

### Interest Accrual
- supply() auto-calls _accrueInterest() internally
- But call accrueInterest() in _preExecute if reading position data
- Supply shares don't change - value per share increases as interest accrues
- SharePrice = totalSupplyAssets / totalSupplyShares

### Edge Cases
- Zero amount: reverts (Morpho requires assets > 0 || shares > 0)
- No borrowers: supply works, no interest earned
- 100% utilization: supply works, high rates; withdrawals may revert
- First supplier: virtual shares (1e6) prevent manipulation

### Security
- No reentrancy risk (empty callback data)
- Flash loans don't affect supply shares
- No front-running vulnerability on supply()
- Supplied assets are flash-loanable by design
