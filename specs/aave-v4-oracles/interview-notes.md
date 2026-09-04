# Aave V4 Oracles — Interview Notes

**Date:** 2026-09-02
**Linear:** SUP-20854
**Interviewee:** Cosmin (via Claude Code interview)
**Context origin:** Aave V4 launching tokenized equities on Base with $1M Aave incentives; call with Joao (Aave) scheduled 2026-09-03. Goal: head start on the oracle gap so Superform smart accounts can borrow stables against equity collateral with full SuperLedger accounting.

## Session learnings carried in (pre-interview facts, verified in-repo)

- Aave V4 V2 loan hooks (`AaveV4SupplyAndBorrowHookV2`, `AaveV4RepayHookV2`, `AaveV4RepayAndWithdrawHookV2`) already exist and are spoke/reserveId-**calldata**-parameterized with on-chain reserve→token binding (`getReserve(reserveId).underlying` must match declared token). New Base equity markets need zero hook changes.
- As of SUP-20842 (PR #996), repays are cap-to-live-debt with graceful zero-debt skip across all providers — relevant to equity collateral where third-party repays/interest drift previously bricked signed intents.
- **No Aave oracle of any kind exists** in `src/accounting/oracles/` (neither V3 nor V4, neither supply nor debt side).
- Closest precedents:
  - `EulerDebtOracle.sol` — identity PPS (debt returned in asset units by `debtOf`), `getTVL = totalBorrows()`, **feePercent = 0 operational invariant** (debt takes no cost-basis snapshots; nonzero fee would treat entire balance as profit), own-asset denomination with cross-asset conversion external, empty-revert isolation via AbstractYieldSourceOracle batch try/catch.
  - `MorphoBlueDebtOracle.sol` + `MorphoBlueMarketRegistry.sol` — precedent for non-address-keyed markets (Morpho markets are Id-keyed; Aave V4 positions are (spoke, reserveId) pairs).
- Debt read: `spoke.getUserDebt(reserveId, account)` → (drawn, premium), total = drawn + premium (same call the V2 hooks use). Supply read: `spoke.getUserSuppliedAssets(reserveId, account)`.
- Aave's own price oracles handle health/liquidation internally; Superform oracles are for SuperLedger accounting only — oracle work does not block a basic hook-level integration demo.
- Deployed debt oracles for Euler/MorphoBlue were recorded in dev commit `e58a82b5` (salvaged from #983) — deployment/manifest path precedent.

## Decisions (interview answers)

| # | Question | Decision |
|---|----------|----------|
| 1 | MVP scope | **Debt + supply oracle pair** for Aave V4 (`AaveV4DebtOracle` + `AaveV4SupplyYieldSourceOracle`). V3 explicitly out of scope for this spec. |
| 2 | (spoke, reserveId) keying | **Registry pattern** mirroring `MorphoBlueMarketRegistry` — an `AaveV4ReserveRegistry` mapping a synthetic yieldSource key to (spoke, reserveId). |
| 3 | Linear | **SUP-20854** — link and sync spec. |
| 4 | Chain scope | **All V4 chains day one** — spec the full deployment matrix wherever Aave V4 spokes exist (Base is the launch driver). |
| 5 | Debt-oracle fee guard | **Operational invariant only** (NatSpec + config discipline, feePercent = 0), matching Euler/MorphoBlue debt oracle precedent exactly — keeps the three debt oracles identical in shape. No on-chain guard. |
| 6 | Supply-side fees | **Fee-capable** — normal cost-basis/fee mechanics like `ERC4626YieldSourceOracle`; whether equities markets charge performance fees on Aave supply yield is a `SuperLedgerConfiguration` decision, not a code constraint. |
| 7 | Cross-asset valuation | **Own-asset units** (Euler precedent): debt oracle reports in the borrow asset, supply oracle in the reserve underlying; conversion external. No price feeds inside the oracles → no staleness/manipulation surface from equity trading hours. |
| 8 | Registry governance | **Match MorphoBlueMarketRegistry verbatim** — same role-gating/mutability model, one precedent, one audit story. |
| 9 | Testing depth | **Unit + Base fork** — mock-spoke unit suite (AaveV4 mock with `setUserDebt(drawn, premium)` already exists from the hooks work) + fork tests against the real Base V4 spoke, including an equities reserve once live. Matches the loan-hooks testing bar. |
| 10 | RWA/equity caveats | **Documented risk section only** — oracles read spoke state so are insulated; transfer restrictions/allowlists/trading-hour pausing affect the hook settle path (strict delta equality) and are captured as risks + open questions for the Aave/Joao conversation. No code mitigations in this spec. |

## Non-functional requirements surfaced

- Oracles are view-only, constructor-light (superLedgerConfiguration + registry refs), no admin keys beyond the registry's inherited model.
- Batch methods must isolate per-source reverts (inherited `AbstractYieldSourceOracle` try/catch behavior).
- Deployment via the locked-bytecode path (`regenerate_bytecode.sh` → generated + locked JSON twins, precedent commit `e58a82b5`); artifact freshness matters (Review R1 on PR #990 was exactly a stale-artifact blocker — verify no stale selector/ABI in committed JSONs).
- `debtOf`-analog semantics: conservative rounding (report at least what's owed); document `getBalanceOfOwner` returns asset units, not shares.

## Risks discussed

- **Debt oracle + nonzero fee misconfiguration** → entire debt read as profit; mitigated by NatSpec + ops runbook (accepted residual risk to stay precedent-identical).
- **Registry key rebinding** → whatever MorphoBlueMarketRegistry allows; inherit its model and its mitigations.
- **RWA token behaviors** (allowlists, pausing, trading hours) → hook-layer risk, documented, raised with Aave.
- **V4 API drift** — Aave V4 is new; `getUserDebt`/`getUserSuppliedAssets`/premium semantics could change pre-mainnet-hardening; pin vendor interfaces and fork-test against the live Base spoke.

## Timeline note

Spec wanted ahead of the Joao (Aave) call on 2026-09-03 — spec-first, implementation after pod-leader approval.
