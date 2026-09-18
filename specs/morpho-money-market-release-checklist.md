# Morpho Blue money-market hooks — release & integration checklist

Scope: `MorphoLendHook` (INFLOW) and `MorphoWithdrawHook` (OUTFLOW) as shipped by SUP-21024 (#1010) and SUP-21005, plus the header identity rules from SUP-21038 (#1009). Consumers: SUP-21025 (Erebor leaves), SUP-21026 (Superman registration), bundler/OMS sizing. This is the "T3" reminder list from the #1010 review, kept next to the code so it is not lost between tickets.

## 1. What is deployed (new CREATE2 addresses)
- `MorphoLendHook`, `MorphoWithdrawHook` — money-market semantics (header market key, INFLOW/OUTFLOW, key-first `inspect()`, lend `amountRoles` IN/ASSETS, lend `outToken` = market key).
- `MorphoRepayHook`, `MorphoRepayAndWithdrawHook` — accrue interest via the header yield source (#1010 follow-up).
- Everything else in the Morpho family (V1 supply/borrow/supply-and-borrow, all six V2 hooks) is byte-identical to `dev` and keeps its address. Old lend/withdraw addresses stay valid for already-signed roots.
- No executor or ledger redeploy.

## 2. Per-chain prerequisites — before any root publishes the new lend/withdraw addresses
- [ ] **Canonical singleton.** The hook constructor arg (`morpho` immutable, `DeployV2OtherHooks` `morphoArg`) must be the canonical Morpho Blue singleton for that chain (`0xBBBB…` on mainnet/Base). The header never carries it; the hook cannot be re-pointed after deploy.
- [ ] **IRM approval.** `MorphoBlueMarketRegistry.setIrmApproval(<AdaptiveCurveIRM>, true)` for the chain's canonical IRM (one IRM per chain today).
- [ ] **Market registration.** `registerMarket(morpho, loanToken, collateralToken, oracle, irm, lltv)` for every market the product will lend into. Curation checklist per market: the Morpho `IOracle` scale factor matches loan/collateral decimals (PAXG/USDC-style misconfigurations socialise bad debt onto suppliers), collateral is liquid, `morpho` argument equals the canonical singleton, market exists on-chain (`market(id).lastUpdate != 0`).
- [ ] **Yield-source oracle wiring.** Deploy `MorphoBlueYieldSourceOracle(ledgerConfig, registry)` and register it in `SuperLedgerConfiguration.setYieldSourceOracles` under the Morpho salt (`SUPERFORM_MORPHO_BLUE_YS`) with the intended ledger, fee percent and fee recipient. The header oracle id is the **derived** config id `keccak256(abi.encodePacked(salt, configSetter))`, not the raw salt.
- [ ] **Debt oracle isolation.** If `MorphoBlueDebtOracle` is also configured, its config id must point to a **different** ledger than the supply-side oracle id (both resolve registry keys; sharing a ledger would let the two share accumulators).
- [ ] **Fail-closed reminders.** An unregistered market reverts `MARKET_NOT_REGISTERED` at accounting (whole userOp reverts). `executeDeregisterMarket` (2-day timelock) bricks Superform withdrawals for tracked positions in that market until re-registered — check `getTVLByOwnerOfShares` for tracked accounts before executing.

## 3. Integration contract (SUP-21025 Erebor, SUP-21026 Superman, bundler, OMS)
- [ ] **Header, money-market hooks (lend/withdraw):** offset 0 = derived Morpho YS oracle config id; **offset 32 = `MorphoBlueMarketRegistry.computeMarketKey(loan, collateral, oracle, irm, lltv)`** — the Morpho market `Id` truncated to 160 bits — **not** the singleton. The hook reverts `MARKET_KEY_MISMATCH` if offset 32 ≠ key(body).
- [ ] **Header, LOAN hooks (V1 borrower + all V2):** offset 32 = the Morpho singleton (unchanged, `YIELD_SOURCE_MISMATCH` otherwise).
- [ ] **Leaves:** `inspect()` for lend/withdraw is 132 bytes, **market key first**, then the five MarketParams; LOAN hooks are singleton first. `SuperVaultAggregator` hashes the raw `inspect()` bytes, so Erebor must encode leaves key-first for money-market hooks (regression: `test/integration/morpho/MorphoLendStrategyProofFork.t.sol`).
- [ ] **Sizing (OMS):** lend `amountRoles` = `[IN, ASSETS]` (offset 132 = loan-token assets). Withdraw `amountRoles` = `[IN/ASSETS, IN/SHARES]`; the MONEY_MARKET withdraw main is sized on **slot 1 (SHARES)** with slot 0 set to 0 (Morpho XOR — both nonzero reverts).
- [ ] **Output denomination:** lend `outAmount` is **Morpho supply shares** (≈ assets × 1e6 on a fresh market, always share-denominated), and `outToken` is the **market key** (a codeless pseudo-address), never the loan token. Hooks that verify the previous output token (`BaseLoanHookV2` family, Aerodrome) fail closed with `PREV_TOKEN_MISMATCH`; legacy `usePrevHookAmount` consumers without a token check would receive a share count — **do not chain lend into an asset-denominated hop without conversion.** Withdraw `outAmount` is loan-token assets with `outToken` = loan token.
- [ ] **Behaviour change to audit in the strategy catalogue:** `Lend → {RepayV2, BorrowV2, RepayAndWithdrawV2, Aerodrome}(usePrevHookAmount)` used to pass the token check with a share count; it now reverts. Any live chain of that shape must be rewritten before the new lend address is published.
- [ ] **Manifests:** `manifests/hooks.json` `amountMeta` for `MorphoLendHook` is `IN/ASSETS` (hand-authored in `tooling/hook-enrichment.yaml`); regenerate after redeploy for addresses (`make manifest`).

## 4. Open follow-ups (tracked, not blocking)
- Manifest ↔ on-chain `amountMeta` conformance test (security report 2026-09-18-sup-21005, P2-T1).
- Zero-accrual round-trip fuzz across 6/8/18-decimal loan tokens; differential pps vs `MorphoBalancesLib` after warps (security report 2026-09-18-sup-21024, open items).
- CI smoke jobs (`treasury-config-smoke-test`, `deployment-smoke-test`) now report real results (`continue-on-error`, exit code propagated) — a red badge there is a real failure, not noise.
