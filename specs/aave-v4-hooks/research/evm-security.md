# EVM Security Research: Aave V4 Lending Protocol Hooks

## Critical Findings Summary

| Priority | Finding | Mitigation |
|----------|---------|------------|
| **P0** | `reserveId` has no intrinsic address validation (unlike Morpho's address-based MarketParams) | Include expected token address in calldata, validate on-chain against Spoke's reserve data |
| **P0** | `onBehalfOf` must always be the smart account itself | Hardcode `account` as `onBehalfOf` in all Spoke calls |
| **P1** | Approval pattern must follow reset-set-operate-reset (P1-1) | Replicate exact 4-step approval pattern from MorphoSupplyHook |
| **P1** | Full repayment interest accrual staleness (P1-3) | Call interest accrual in `_preExecute`, add small approval buffer |
| **P1** | Front-running full repayment (P1-2) | Document as known limitation |
| **P2** | Position Manager authorization required | Verify smart account is registered as Position Manager |
| **P2** | Thin market share manipulation | Off-chain bundler should refuse thin markets |
| **P2** | Rounding direction must favor protocol in repay, favor user in borrow/withdraw | Use proper rounding in all share/asset conversions |
| **P3** | Fee-on-transfer token balance discrepancy | Balance-diff pattern naturally handles this |

## Relevant Vulnerability Patterns

### 1. Reentrancy
- Aave V4 Spoke does NOT have callback mechanisms like Morpho
- ERC-777/callback token risk remains on `safeTransferFrom`
- Cross-hook reentrancy mitigated by SuperExecutorBase `nonReentrant`
- BaseHook mutex prevents single-hook reentrancy

### 2. Access Control
- `reserveId` (uint256) provides no address validation unlike Morpho's MarketParams
- `onBehalfOf` must always be the smart account address
- Position Manager authorization required on Aave V4 Spoke

### 3. Flash Loan Exploitation
- Classic pattern: flash borrow -> deposit as collateral -> borrow -> extract
- Mitigated by Merkle-tree signature validation (attacker can't craft arbitrary sequences)
- Off-chain bundler must validate parameters

### 4. Token Integration
- Must use zero-approve-set-approve-zero-approve pattern (P1-1)
- Approve the **Spoke** address (not Hub) — Spoke calls `safeTransferFrom`
- Fee-on-transfer handled by balance-diff pattern
- USDT non-standard approval handled by zero-first pattern

### 5. Share Accounting
- Aave V4 uses shares internally — same patterns as ERC-4626
- Donation attack: tokens donated directly to Hub inflate share price
- Interest accrual between build() and execute() makes approvals stale
- Rounding: round UP for repayment, round DOWN for withdrawal

## Exploit Precedents

| Protocol | Date | Loss | Relevance | Lesson |
|----------|------|------|-----------|--------|
| Euler Finance | Mar 2023 | $197M | VERY HIGH | Self-collateralization + donation = insolvency |
| Radiant Capital | Jan 2024 | $4.5M | HIGH | Rounding vulnerability in thin markets |
| Compound | Sep 2021 | $160M | MEDIUM | Parameter validation critical |
| Aave rsETH | Apr 2026 | $196M | CRITICAL | Underlying collateral can be compromised externally |

## Attack Surface

### reserveId Manipulation
Unlike Morpho's 4-address MarketParams, Aave V4's uint256 reserveId has no intrinsic validation. Include expected token address in calldata and validate on-chain.

### Approval Risks
- Infinite approval to Spoke leaves permanent allowance if Spoke is upgraded maliciously
- Exact approval + reset (P1-1 pattern) is required
- Stale approval for full repayment needs buffer

### Cross-Hook Reentrancy
- LOW risk within Superform architecture
- nonReentrant on executor + BaseHook mutex + transient storage

## Testing Recommendations

### Fuzz Tests
- Supply with random amounts, verify shares match
- Borrow with various LTV ratios, verify health factor
- Full repayment with interest accrual
- Partial repay proportional collateral withdrawal

### Invariant Tests
- Supply + withdraw round-trip returns ~same amount
- outAmount + remaining balance == original balance
- Health factor > 1 after any borrow
- Approvals always zero after hook execution

### Integration Tests (Mainnet Fork)
- Basic supply/withdraw USDC cycle
- Supply collateral + borrow cycle
- Full repay + withdraw with interest accrual
- Multi-hook chain: Swap -> Supply -> Borrow
- USDT approval edge case
- Stale approval for full repayment
