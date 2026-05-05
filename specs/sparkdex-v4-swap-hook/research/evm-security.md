# EVM Security Research: Algebra Integral Swap Hook

## Attack Surface Summary

The hook follows the established approve->swap->revoke pattern. Key risks:

1. **Sandwich attacks** - Mitigated by `amountOutMinimum` + `limitSqrtPrice`
2. **Approval race condition** - Mitigated by approve(0)->approve(amount) pattern
3. **Fee-on-transfer tokens** - Balance-delta accounting in postExecute handles output correctly; fee-on-transfer as input may cause router revert
4. **Router trust** - Immutable address, exact-amount approval, cleared after use
5. **Recipient redirection** - Prevented by forcing recipient to `account`

## Exploit Precedents

| Incident | Loss | Relevance |
|----------|------|-----------|
| Li.Fi Protocol (2024) | $11M | Approval drain via arbitrary calldata - our hook constructs calldata internally |
| Gamma Strategies (2024) | $6.2M | Algebra V3 pool price manipulation - our amountOutMinimum protects |
| Cork Protocol (2025) | $11M | Uniswap V4 hook access control - BaseHook handles via UNAUTHORIZED_CALLER |

## Recommended Mitigations (All Already Established)
- approve(0)->approve(amount)->swap->approve(0) pattern
- Deadline validation in hook + router (defense-in-depth)
- Recipient forced to account
- Balance-delta accounting (doesn't trust router return value)
- Constructor validation of router address
- Immutable router address

Full details in security agent output.
