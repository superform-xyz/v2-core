# EVM Security Analysis: Odos V3 Swap Hook

## Priority Actions

| Priority | Action | Rationale |
|----------|--------|-----------|
| P0 | Implement `MAX_REFERRAL_FEE` cap with revert | Prevents output drain via V3 fee mechanism |
| P0 | Validate feeRecipient != address(0) when fee > 0 | Prevents fee burns |
| P1 | Include executor and feeRecipient in `inspect()` | Enables off-chain validation |
| P1 | Fuzz test referral fee boundaries | Boundary condition verification |
| P2 | Fork test against live Odos V3 on mainnet | Validates real-world behavior |

## Attack Surface

### A. Referral Fee Drain (HIGH -- V3-specific)
V3 passes fee inline per-swap. Router caps at 2%, but hook should also validate.
Fee denomination: `FEE_DENOM = 1e18`, so 2% = `2e16`.

### B. Arbitrary Executor Call (CRITICAL -- inherited from V2)
Executor address from user-supplied hook data. Off-chain validation via `inspect()`.
Precedent: Kame Aggregator exploit (Sep 2025, $1.325M) -- unvalidated executor in swap().

### C. Opaque pathDefinition (HIGH -- inherited from V2)
pathDefinition bytes passed through blindly. Router enforces outputMin as safety net.

### D. Approval Window (MEDIUM -- ApproveAndSwap only)
approve(0)-approve(N)-swap-approve(0) is atomic within ERC-7579 execution.

### E. Balance Delta Underflow (LOW)
Solidity 0.8.30 reverts on underflow. DoS vector, not fund-loss.

## Exploit Precedents

| Exploit | Loss | Relevance |
|---------|------|-----------|
| Kame Aggregator (Sep 2025) | $1.325M | Arbitrary executor in swap() |
| SwapNet/Aperture (Jan 2026) | $17M | Unvalidated swap calldata |
| Odos LimitOrderRouter (Jan 2025) | $50K | Arbitrary call in Odos codebase |
| Transit Swap (Oct 2022) | $21M | Arbitrary external call in aggregator |

## Recommended Fuzz Tests
1. Referral fee BPS fuzzing (above/below/at cap)
2. Input amount and outputMin scaling with extreme ratios
3. pathDefinitionLength bounds
4. Zero-amount edge cases
