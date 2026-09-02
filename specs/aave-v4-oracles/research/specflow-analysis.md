# SpecFlow Gap Analysis — Aave V4 Accounting Oracles

Produced by spec-flow-analyzer, 2026-09-02. Verified against `BaseLedger.sol`, `AbstractYieldSourceOracle.sol`, `SuperExecutorBase.sol`, all `src/hooks/loan/**`, `HookDataDecoder.sol`, and the existing oracle suites.

**Baseline note (resolved after analysis):** the analyzer ran against `dev` @ `94197d26`; the SUP-20842 repay-cap/zero-debt-skip semantics live in PR #996 (`2bb8e676`, branch `feat/repay-cap-convergence-sup-20842`), stacked on PR #990. The technical spec's baseline is dev + #990 + #996 merged.

---

## Headline findings (both absent from all prior research)

### Finding A — [P0] No loan hook calls `SuperLedger.updateAccounting`. Ever.
- `BaseLoanHook.sol:29`: every loan hook (Aave V3/V4, Morpho, Euler; V1 and V2) is `HookType.NONACCOUNTING`.
- `SuperExecutorBase._updateAccounting` (188-211) only fires for `INFLOW`/`OUTFLOW` hook types — for loan hooks the entire accounting block is skipped: no oracle read, no snapshot, no fee.
- The 52-byte header's `yieldSourceOracleId`/`yieldSource` bytes are documented as `placeholder0`/`placeholder1` in the loan hooks and never read (zero grep hits for `extractYieldSourceOracleId` under `src/hooks/loan/`).
- The cited precedents (`EulerDebtOracle`, `MorphoBlueDebtOracle`, `MorphoBlueYieldSourceOracle`) are deployed but **hook-unwired** — their ~700-line suites instantiate the oracles directly; no hook references them. They are standalone accounting/monitoring oracles, not live fee-pipeline components.
- Consequence: "reuse the existing V2 loan hooks unchanged" does not by itself produce any SuperLedger accounting. The spec must pick: (a) new accounting-typed hook variants, (b) standalone/monitoring-only oracles for this scope (precedent-consistent), or (c) new wiring design.

### Finding B — [P0] Bundled open/close hooks publish ONE `(outAmount, outToken)` per call.
`_settleOpen` publishes the borrow leg only; `_settleClose` the withdrawn-collateral leg only; `_settleRepay` publishes 0. One hook call touches TWO ledger positions (supply + debt) but the interface carries one. If live wiring is ever added, either the single-leg hooks (`AaveV4SupplyHook`/`BorrowHook`/`RepayHook`/`WithdrawHook`, currently also NONACCOUNTING) become the seam, or the settle interface must publish two events.

### Finding C — [P0] The supply-oracle "identity vs real-PPS/shares" tension is FORCED, not open.
- `BaseLedger._takeSnapshot` (120-142) treats inflow amounts as literal SHARES (`usersAccumulatorShares += amountShares; costBasis += shares * pps / 10^decimals`) — unit-safe only when the hook reports protocol shares (as ERC4626 vault hooks do).
- Every loan-hook settle measures **ERC20 wallet-balance deltas in ASSET units** — architecturally forced: V4 spokes mint no transferable share token, and the loan-hook philosophy is "no amount derived from a ratio/oracle inside the hook".
- A real-PPS/shares supply oracle (best-practices rec #2) would require a state-delta-reading hook — new hook design, out of MVP scope. `MorphoBlueYieldSourceOracle`'s shares-based design is NOT a working end-to-end precedent (it's unwired too).
- **Resolution: identity/asset-denominated supply oracle (Euler-shaped) is the only design unit-consistent with the existing hook architecture.**

---

## Identified gaps

1. **[P0]** Accounting-wiring scope undecided (Finding A) — must be an explicit spec statement.
2. **[P0]** Bundled hooks can't drive two ledger updates (Finding B).
3. **[P0]** Supply-oracle shape forced to identity (Finding C).
4. **[P1]** SUP-20842 baseline ambiguity — resolved above (dev + #990 + #996).
5. **[P1]** `getTVL` aggregate views missing from vendored `IAaveV4Spoke` (`getReserveDebt`, `getReserveSuppliedAssets` exist upstream) — needs an owner + acceptance criterion.
6. **[P1]** `TokenizationSpoke` ambiguity: if Base equity reserves route through TokenizationSpoke (ERC-4626-shaped), the whole three-contract design is the wrong shape (`ERC4626YieldSourceOracle` applies instead). **Implementation-blocking Joao question.**
7. **[P2]** Registry doesn't restrict registrable spokes; same economic reserve could be registered under two spokes, splitting a user position across two yieldSource keys with no on-chain detection. Decide allowlist vs documented accepted risk.
8. **[P2]** Premium-debt rounding direction unverified — could make `approve(drawn+premium)` 1 wei short of `repay(max)`'s pull (reverting execution, not misaccounting).
9. **[P2]** `getAssetOutputWithFees` with no ledger config falls through to plain output (inherited try/catch) — fine by precedent, make it an explicit AC line (some equity markets may legitimately have no fee config).
10. **[P3]** `getPricePerShareMultiple`/`getTVLMultiple` have NO try/catch isolation (only `getTVLByOwnerOfSharesMultiple` does) — one reverting key poisons those batch calls; document + known-issue test.

## Edge cases

- Registration with EOA/codeless spoke → must revert typed, not garbage-decode (named test).
- Same underlying registered under two spokes → key rebinding impossible (hash-derived) but economic duplication possible (Gap 7).
- Fee-misconfiguration test is inert under NONACCOUNTING wiring — note in spec so "we have a test" isn't mistaken for "reachable in production today".
- Third-party partial repay before execution: cap semantics resolve to live debt; any future accounting-aware repay hook must compute usedShares from the RESOLVED amount, not the signed cap (mirrors SUP-20842's settle rule).
- Paused/frozen reserve mid-intent: hook mutations revert atomically — non-issue for accounting (state it, don't leave open).
- Per-leg decimals: each oracle resolves decimals from its OWN reserve's `Reserve.decimals` (equity 18 vs USDC 6) — explicit AC.

## Questions requiring answers

**By pod/spec-author (code-level):**
1. Accounting wiring in scope? → Recommend: standalone oracles (precedent-consistent), wiring = follow-up ticket.
2. Identity supply oracle confirmed? → Yes, per Finding C.
3. SUP-20842 baseline? → dev + #990 + #996 (resolved).
4. Spoke allowlist in registry? → decide (Morpho precedent has none, but Morpho has a singleton; V4 has multiple spokes by design).
5. MorphoBlue supply oracle is dev-only in prod locked-bytecode — is Aave the first of this pattern to prod?

**For Joao/Aave (implementation gates in bold):**
6. **Plain Spoke or TokenizationSpoke for Base equities?** (changes the deliverable entirely)
7. Premium rounding direction in `getUserDebt`.
8. Does supply PPS net bad-debt socialization immediately?
9. Any governance path that rebinds a reserveId?
10. View liveness under paused/frozen (trading-hours) reserves.
11. B20 transfer hooks/callbacks; `receiveSharesEnabled` × KYC interactions.
12. **Base equities spoke address + reserve ids + pinned block** (fork tests, registry seeding).
13. $1M incentive mechanism (likely Merit-style; no oracle impact — close the item).

## Suggested acceptance-criteria additions

1. Explicit accounting-wiring scope statement (standalone-only for SUP-20854; follow-up ticket for live wiring).
2. Test (or explicit non-goal) anchoring that hook `outAmount` is asset-denominated wallet-delta, not spoke shares.
3. Zero-debt behavior test cross-referenced to the exact baseline commit.
4. Vendored-interface extension (`getReserveDebt`, `getReserveSuppliedAssets`) as a named deliverable.
5. Registry test: same-underlying-two-spokes either disallowed or documented accepted risk.
6. Codeless/EOA-spoke registration typed-revert test.
7. TokenizationSpoke confirmation gate before implementation starts.
8. Batch-view isolation: add try/catch parity OR document + known-issue test for `getPricePerShareMultiple`/`getTVLMultiple`.
