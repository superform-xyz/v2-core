# ERC20YieldSourceOracle — Interview Notes

**Date:** 2026-09-15
**Interviewee:** Cosmin (pod)
**Origin:** SuperMAG7-on-BSC Slack thread (Kurisu/Subhasish/Vik, 2026-09-15) + Vik's Notion spec
(SuperMAG7 on BSC Engineering Spec). Proposal author: Subhasish.

## Context (from the thread, treated as requirements input)

- The SuperMAG7 vault on BSC will hold USDT + whitelisted tokenized stocks (NVDAb, TSLAb, AAPLb…)
  **directly in the strategy** — no wrapping vault, no lending market initially.
- PPS is computed **off-chain by the Validator Network**; stock prices come from off-chain
  aggregated sources (DeFiLlama etc.). No on-chain price oracle required for v1 (Binance may
  request an on-chain path later — decision deferred to the Binance conversation).
- The **on-chain yield-source whitelist** (`SuperVaultStrategy.yieldSources`) is the source of
  truth for *what* contributes to PPS. `manageYieldSource(source, oracle, Add)` requires a
  non-zero oracle address; convention (and validator-network consumption) requires that oracle
  to satisfy the `IYieldSourceOracle` shape.
- Verified in code: the strategy never calls the oracle on-chain — it stores and exposes it
  (`SuperVaultStrategy.sol:94,599-625,871-877`). The oracle is on-chain metadata acting as a
  type discriminator for off-chain pricing ("post-processors" per Subhasish).
- Therefore: a minimal **ERC20YieldSourceOracle** in v2-core makes plain ERC20 tokens
  whitelistable. Off-chain pricing changes (supervault-pricing repo) are explicitly OUT of scope
  for this spec.

## Decisions (AskUserQuestion rounds)

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | `getTVL(token)` semantics | **`totalSupply()`** | Honest identity answer, mirrors ERC4626YieldSourceOracle's totalAssets(); per-owner TVL (= `balanceOf`) is what consumers actually use; 0/revert would trip monitoring or batch calls |
| 2 | `getAssetOutputWithFees` | **Bypass override** (post-#997 AaveV4SupplyYieldSourceOracle shape) | Identity-PPS oracle with no cost-basis snapshots must never expose the inherited fee view — PR #997 review F1 precedent (principal taxed as profit). feePercent = 0 documented invariant |
| 3 | On-chain token validation | **`decimals()` probe only** | `decimals(token)` passthrough makes non-ERC20s revert naturally on query; same trust model as ERC4626YieldSourceOracle (manager is trusted; garbage in, garbage out) |
| 4 | Deployment scope | **Fleet-wide** | Add to ORACLE_CONTRACTS in regenerate_bytecode.sh + DeployV2Core oracle list; BSC is merely the first consumer |
| 5 | `assetIn` param in converters | **Ignore it** | Fleet-wide identity-oracle precedent (Euler/AaveV4, documented as accepted in the AaveV4 review) — pure identity passthrough of amountIn |
| 6 | Weird-token classes | **Rebasing + fee-on-transfer declared OUT of scope** (documented, not engineered) | B-tokens are plain 18-dec ERC20s; oracle is a view-only passthrough — defenses belong to whoever whitelists. >18 decimals: identity math is decimal-agnostic; note caution only |
| 7 | Delivery | **New branch off dev (`feat/erc20-yield-source-oracle`), no commit/push yet** | User instruction; small self-contained PR when approved |

## Non-goals

- supervault-pricing / validator-network changes (separate workstream, separate repo).
- On-chain stock price feeds (Venus/Chainlink wrappers) — future upgrade path via
  `manageYieldSource(…, UpdateOracle)`; not this spec.
- Any hook or ledger wiring — standalone accounting-oracle class, same as Euler/Morpho/AaveV4
  debt+supply oracles (NONACCOUNTING hooks never drive the ledger through these).
- Periphery changes — `manageYieldSource` already accepts any (source, oracle) pair.

## Testing expectations (discussed)

- Unit suite at the bar of the AaveV4/Euler oracle suites: identity passthroughs, decimals
  reflection, balance/TVL reads, fee-view bypass pinned (configured fee ignored), multi-view
  batch behavior incl. the known one-reverting-entry poisoning of unprotected Multiple() views,
  weird-decimals (6/8/18) tokens, non-ERC20 address behavior (decimals() revert).
- Fork check on BSC against real B-tokens (NVDAb/TSLAb addresses from the Venus VIP-654 list)
  if addresses are confirmed; otherwise mock-only with the addresses parameterized.
