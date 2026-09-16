# ERC20YieldSourceOracle — SpecFlow Gap Analysis

(Condensed pass, 2026-09-15. The repo-analysis and evm-security documents already enumerate the
function-level edge cases exhaustively; this note captures only flow-level gaps and decisions
they surfaced, in place of a third full agent run — deviation noted deliberately for a
single-contract, view-only feature.)

## User flows

1. **Whitelist flow (the feature's purpose):** SuperVault primary manager calls
   `manageYieldSource(stockToken, erc20Oracle, Add)` → strategy stores the pair → validator
   network sees the token in `getYieldSourcesList()` and, keyed on the oracle address, prices it
   via `getBalanceOfOwner(token, strategy) × offchainPrice`. No v2-core runtime involvement.
2. **Monitoring flow:** periphery/monitoring batch views (`getTVLByOwnerOfSharesMultiple` etc.)
   sweep positions; the isolated batch tolerates a broken token, the two unisolated batches do
   not (documented fleet behavior).
3. **Future upgrade flow:** on-chain stock feeds later → `manageYieldSource(…, UpdateOracle)`
   swaps to a price-aware oracle without touching this one. This spec deliberately leaves that
   oracle out of scope.

## Gaps surfaced and resolved

| Gap | Resolution |
|---|---|
| `getTVL` semantics ambiguous for plain ERC20s (global supply vs vault holdings) | Decision #1: `totalSupply()`, with NatSpec pinning "monitoring-only, never a pricing input; pricing consumers must use getBalanceOfOwner" (security §1.1) |
| Fee-pipeline misuse (identity PPS + fee config; FlatFeeLedger taxes full principal) | Decision #2: bypass override + triple anchoring (NatSpec invariant, ops runbook line, executable tests incl. FlatFeeLedger hazard demo) |
| Double-entry tokens double-counted by off-chain pricer (TUSD class — strongest applicable risk) | Ops whitelisting checklist item + executable proxy/canonical-entry check recommendation (security §4); oracle stays registry-free by design |
| Batch ROLLOUT NOTE: `getTVLByOwnerOfSharesMultiple` returns the new tuple ABI | New oracle implements the current interface — lands on the new ABI side of the mixed fleet; no action, note in spec |
| Verify-script gap precedent (EulerDebtOracle missing from both cases) | Wire both verify cases in this PR; do not replicate the gap |
| Non-ERC20 whitelisted by mistake | decimals() probe reverts on query (decision #3); identity converters still answer for any address — scope the revert surface precisely in NatSpec (avoid the AaveV4 P3-3 overclaim) |
| Rebasing/corporate-action tokens (stock splits implemented as rebases) | Declared out of scope, made *executable* via a rebasing-mock documentation test; whitelisting checklist requires issuer's corporate-action mechanism confirmed in writing |

## Explicitly out of scope (confirmed)

- supervault-pricing / validator-network changes (separate repo/workstream).
- On-chain stock price feeds (Venus/Chainlink wrappers).
- Periphery changes (manageYieldSource already suffices).
- Engineering defenses for rebasing/fee-on-transfer tokens (documented exclusions).
