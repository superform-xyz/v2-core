# Security Analysis Report — Aave V4 Accounting Oracles

## Metadata
- **Target:** `src/accounting/oracles/AaveV4ReserveRegistry.sol`, `AaveV4DebtOracle.sol`, `AaveV4SupplyYieldSourceOracle.sol`, `src/vendor/aave-v4/IAaveV4Spoke.sol` (extension) — SUP-20854, branch `cosmin-sup-20854-feature-aave-v4-debt-oracle`
- **Mode:** review (3 security agents) + 3 additional parallel code reviewers (adversarial correctness, deploy/tooling wiring, test quality) — 6 independent streams total
- **Date:** 2026-09-02
- **Contract Types Detected:** accounting oracle (view-only) + permissioned registry; no vault/AMM/bridge/governance/token surface
- **Files Analyzed:** 4 source + 3 test suites + deploy tooling diff
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (36 sections; NOTE: the DB lives in superform-specs, not v2-core)

## Summary

| Severity | Count | Blocks Merge | Status |
|----------|-------|--------------|--------|
| P0 Critical | 0 | — | — |
| P1 High | 0 | — | — |
| P2 Medium | 1 (fmt/CI) | No | **FIXED** |
| P3 Low | 8 | No | **7 FIXED, 1 accepted-documented** |

## Verdict

**PASS** — No P0/P1 findings across all six review streams. The adversarial reviewer explicitly failed to refute correctness on any logic, integration, or ABI axis, including independent on-chain `cast` verification of the vendored ABI against the live spoke at the pinned block. All P2/P3 items were remediated in the same branch (except one explicitly accepted with documentation), and the full suite re-passes: **71 AaveV4-oracle tests (45 unit / 7 fork / 19 E2E) + 566 accounting-oracle-path tests, 0 failures**; artifacts regenerated post-fix.

## Findings & Remediation

### P2

**V1 — `forge fmt --check` failure (two 124-char constructor lines)** — `AaveV4DebtOracle.sol`, `AaveV4SupplyYieldSourceOracle.sol`. Would break CI fmt gates. **FIXED**: constructors reformatted to house multi-line style; `forge fmt --check` now clean on all three files.

### P3

1. **Pending deregistrations never expire** (scanner P3-1; adversarial F2; external research F1) — a ripe abandoned proposal defeats the 2-day warning window at execution time. Precedent-identical to `MorphoBlueMarketRegistry`; no code change (interview decision: registry model verbatim). **FIXED via documentation**: NatSpec on `proposeDeregisterReserve` now states non-expiry explicitly with the ops-runbook rule (cancel abandoned proposals; alert on pending > a few days via `ReserveDeregistrationProposed` without matching terminal event). The re-propose-resets-timer behavior is documented as OZ-standard and extend-only (can never shorten — verified and now tested).
2. **Missing zero-address check on `superLedgerConfiguration_`** (scanner P3-2) — asymmetric with the `registry_` check; fail-silent fee path on the supply oracle if misdeployed. **FIXED**: both constructors now revert `ZERO_ADDRESS` on either param (deliberately stricter than the Euler/Morpho precedents).
3. **NatSpec overclaim: "unregistered keys revert ... never a zero return"** (adversarial F1) — false for the pure identity passthroughs which never consult the registry. **FIXED**: both contract headers now precisely scope which views resolve the registry (and revert) vs. the pure converters (identity for any key; cannot be used to probe registration).
4. **`assetIn`/`assetOut` params silently ignored** (adversarial F3) — fleet-wide precedent behavior (`INVALID_BASE_ASSET` unused across all oracles); no on-chain consumer passes attacker-chosen assets. **ACCEPTED, precedent-consistent** — documented here; candidate for a fleet-wide follow-up, not this PR.
5. **Constructor `@notice` missing** (best-practices V2) — **FIXED** on both oracles.
6. **`MARKET_MANAGER_ROLE` NatSpec missing** (V3, gap inherited from Morpho) — **FIXED** (backport to Morpho registry is a follow-up candidate).
7. **`decimals_` return-name underscore** (V5) — **FIXED**: renamed `underlyingDecimals`.
8. **Section banner drift** (V6) — **FIXED**: `STATE` label aligned across the family.

### Deploy/tooling review (all 8 wiring checks PASS)

Hand-edited array sizes, indices, constructor-arg encodings, salts, verification records, and artifacts all verified internally consistent; artifacts byte-identical between `generated-bytecode/` and `locked-bytecode-dev/` with correct constructor ABIs, correctly absent from prod `locked-bytecode/`. Remediated alongside: `potentialMissing` scratch array bumped 110 → 130 (pre-existing overflow headroom), stale count comments removed. **Also remediated (follow-ups applied same-branch):** `verify_v2_staging_prod.sh` gained constructor-arg and source-path case entries for all three contracts (UniV3CLPRegistry pattern; registry via `$deployer`, oracles via `$super_ledger_config` + resolved registry address), and the `MARKET_MANAGER_ROLE` NatSpec gap was backported to `MorphoBlueMarketRegistry` (comment-only; bytecode verified unchanged, no artifact refresh needed). Remaining pre-existing gap out of scope: Euler/Morpho oracle entries in the verify script.

### Test-quality review → remediation

Added in response (unit suite 37 → 45 tests):
- **F3 liveness (the only fully unmet spec AC)**: `test_views_liveUnderPausedFrozenFlags` — proves the oracles never gate on reserve flags (paused|frozen), so accounting reads survive equity trading-hour pauses.
- **Role-gating negatives** for propose/execute/cancel deregistration (regression guard on the highest-consequence registry action).
- **Real-ledger round trip**: `test_realLedger_supplyRoundTrip_principalChargesZeroFee` — executable proof of the never-over-charge NatSpec claim through a real `SuperLedger` cost-basis snapshot (fee == 0 on principal at 10% configured fee).
- **PPS overflow boundary**: decimals 77 works, 78 reverts — pins the NatSpec claim.
- **Zombie-pending invariant**: re-registered key can never inherit a live pending deregistration (structural proof, now also a test).
- **Re-propose extends timelock** + **fuzzed timelock boundary** + **registry event emission** (all four events).
- **Dud fuzz fixed**: `computeReserveKey` now fuzzed against an independent inline keccak recomputation (was f(x)==f(x)).
- **Unregistered-key sweep completed** (supply `decimals`, both `getTVLByOwnerOfShares`).
- **E2E invariant**: `getTVL(key) >= getBalanceOfOwner(key, user)` on both oracles.
- **Warp-survival comment** added to the E2E header: warped mutations pass because the V4 price layer at this block performs no Chainlink staleness enforcement (empirically verified by the reviewer); documents the breakage mode if Aave ships staleness-guarded adapters.

## Attack Surface Summary

- **External entry points:** registry `registerReserve` / `proposeDeregisterReserve` / `executeDeregisterReserve` / `cancelDeregisterReserve` (all `MARKET_MANAGER_ROLE`-gated); everything else is view/pure.
- **Value transfer points:** none — zero token movement in all three contracts.
- **Oracle dependencies:** none — no price feeds by design; spoke views are live-accrued position state.
- **Cross-contract interactions:** `spoke.getReserve/getUserDebt/getUserSuppliedAssets/getReserveDebt/getReserveSuppliedAssets` (STATICCALLs to an Aave-governed proxy); `SuperLedgerConfiguration`/`ISuperLedger` on the inherited fee view path only.
- **Upgrade mechanisms:** none in-scope; Aave spokes are TransparentUpgradeableProxies (bindings survive by address; semantics drift mitigated by interface pinning, fork tests, ops monitoring — spec risk table).
- **Highest-consequence residual (unchanged, triple-anchored):** the debt oracle's `feePercent = 0` operational invariant — full debt taxed as profit if violated on the unguarded `BaseLedger._processOutflow` path; view path is override-protected; inert under current NONACCOUNTING wiring; anchored by NatSpec + runbook + executable tests. Named precedent: Compound Prop 62 (~$80M, wrong-baseline accrual) and Moonwell 2025 ($1.8M, config-not-code).

## Key External-Research Deltas (folded into code/docs)

- **Third-party debt mutation — CORRECTED BY E2E FORK TESTING**: the research (Sherlock contest corpus) reported `updateUserRiskPremium` as permissionlessly callable; the new E2E tests **disproved this on the deployed spoke** — it is `AccessManaged`-gated (third-party calls revert `AccessManagedUnauthorized(caller)`, selector `0x068ca9d8`; self-calls succeed), i.e. Aave hardened it between the contest and mainnet deployment. NatSpec on `AaveV4DebtOracle` rewritten to the deployment-accurate statement (self/authorized re-rating + implicit re-rating on position touch + accrual → debt still must not be assumed constant), and the gating is now pinned by `test_E2E_UpdateUserRiskPremium_GatedOnDeployment_ParityAfterSelfPoke` as a regression sentinel. Also E2E-pinned: post-poke oracle parity, poke-then-repay(max) clears to exactly zero (SUP-20842 interaction), donation immunity on the real spoke, and the real EURC reserve at ~100% utilization (`InsufficientLiquidity` on borrow while oracle reads stay live).
- **rsETH incident (2026-04-18)** empirically confirms V4 accounting views stayed coherent through a $177M crisis (freeze-not-pause response; existing positions unaffected) — strongest available evidence for the view-liveness assumption; also establishes Umbrella bad-debt socialization as a real path (supply-PPS drop case named in the risk docs).
- **Aave V4 audit corpus** (8 reports + Sherlock contest + live bounty at `github.com/aave/aave-v4/tree/main/audits`) — pin the vendored interface to the commit covered by the 2026-03-23 ChainSecurity final + 2026-03-09 Certora Spoke FV.
- **Registry role-holder capture** (Term Finance 2026, KiloEx 2025) — hash-derived keys cap rebinding; residual is hostile-spoke registration under a fresh key: `MARKET_MANAGER_ROLE` must be a multisig, never a hot EOA (runbook item); no trusted-forwarder/multicall inheritance on the registry (verified — plain `AccessControl` only).

## Coding Standards

Compliance table (best-practices agent): all four files PASS on locked pragma, license headers, custom errors, event coverage, import grouping, immutables, visibility, storage-pointer getters; documentation judged at or above the Euler/Morpho precedent bar. All flagged violations fixed (see P2/P3 above); the registry-getter gas note (V4) accepted as precedent-parity.

## Security Knowledge Sources
- vulnerabilities.md sections referenced: 1 (incl. 1.4), 2, 3, 4, 8, 9, 10, 14, 15, 22, 25, 28, 29.3/29.4, 34, 35 (35.3/35.6), 36, Appendices H/J/K/L/M
- External: Aave V4 audit corpus + Sherlock contest, OWASP SC Top 10 (2026 edition — only SC01/SC10 carry residual weight), OZ TimelockController semantics, rsETH/Term Finance/KiloEx/Moonwell 2025-26 incident analyses, live `cast` ABI verification at block 24_884_274
- Prior internal research: `specs/aave-v4-oracles/research/{evm-security,best-practices,framework-docs,specflow-analysis,repo-analysis}.md`

## PR #997 Review Findings (2026-09-03, NicolaBernini) — Remediation

- **F1 (P1) — supply fee view could fee principal in the delivered NONACCOUNTING runtime**: FIXED — `AaveV4SupplyYieldSourceOracle.getAssetOutputWithFees` now bypass-overridden (mirrors the debt oracle); feePercent = 0 is the operational invariant for BOTH oracles during the standalone phase; NatSpec/spec/tests aligned (the former hazard-demo test now pins the bypass; real-ledger tests re-scoped as future-wiring documentation). Supply artifact regenerated + mirrored post-change.
- **F2 (P1) — Base-equities gate unresolved**: scope decision recorded separately (plain-ISpoke vs TokenizationSpoke confirmation, Base spoke config + equity fork test, or explicit re-scope to generic Aave V4 infra with owned follow-up).
- **F3 (P2) — registry role handoff missing**: FIXED — `script/TransferAaveV4ReserveRegistryRoles.s.sol` added (idempotent grant + revoke + verify, `runCheck` mode; MARKET_MANAGER → GOVERNOR, DEFAULT_ADMIN → SUPER_GOVERNOR, Flare override; mirrors the MorphoBlue/UniV3 precedents); registry constructor NatSpec aligned (handoff is a blocking production-activation task; manager never a hot EOA).

## Post-Remediation State

- `forge fmt --check`: clean. Build: clean.
- Tests: 45 unit + 7 fork + 19 E2E (71 AaveV4-oracle) + 566 accounting-oracle-path + deploy verification records — all passing.
- Bytecode artifacts regenerated AFTER the constructor changes and mirrored to `locked-bytecode-dev/` (no R1-style staleness).
