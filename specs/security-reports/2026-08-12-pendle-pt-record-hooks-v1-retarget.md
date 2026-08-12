# Security Analysis Report — Pendle PT Record Hooks (V1 retarget)

## Metadata
- **Target:** uncommitted changes on `feat/pendle-pt-record-hooks`
  - `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol`
  - `src/hooks/oracles/pendle/RecordRedemptionPendlePTHook.sol`
  - `src/vendor/pendle/IPendlePTAmortizedOracle.sol`
  - `script/DeployV2Core.s.sol` (Pendle PT Record Hooks wiring + availability gate)
- **Mode:** review (inline scan + 3 parallel agents: vulnerability scanner, best-practices, EVM security research)
- **Date:** 2026-08-12
- **Contract Types Detected:** ERC-7579 hook composition, Pendle PT amortized-cost yield-source oracle, TWAP-based pricing
- **Files Analyzed:** 4 (+ context: `PendlePTAmortizedOracle.sol` V1, `BaseHook.sol`, `PendlePTHook.sol`, `IPendlePTHookResult.sol`)
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (36 sections)

## Summary
| Severity | Count | Blocks Merge | Status |
|----------|-------|-------------|--------|
| P0 Critical | 0 | Yes | — |
| P1 High | 0 | Yes | — |
| P2 Medium | 1 | No | Fixed |
| P3 Low / Info | 6 | No | 2 fixed, 4 documented/verified-safe |

## Verdict
**PASS** — No P0 or P1 findings. The hook-side diff is tight; all convergent risk sat in the hook↔V1-oracle **unit contract** (decimals) and the **deliberate design choice** (per spec) to derive cost basis from the oracle's on-chain TWAP instead of an off-chain quote. All tests green.

## Remediation status (post-review fixes applied)
| Finding | Action |
|---|---|
| **P2-1** decimals unit mismatch | **Fixed** — `RecordPurchasePendlePTHook` now enforces `PT.decimals() == SY.assetInfo().assetDecimals` at build time (new `DECIMALS_MISMATCH` error), refusing markets where the V1 oracle math would silently DoS/corrupt. New unit tests `test_Build_RevertsOnDecimalsMismatch` / `test_Build_MatchedDecimals_Pass`. |
| **P3-1** deploy gate/block predicate mismatch | **Fixed** — availability gate now keys on the V1 flag (`pendlePTAmortizedOracleHooks`) mirroring the deploy block that binds to `configuration.pendlePTAmortizedOracles`; deploy script recompiles. |
| **P3-4** vestigial `twapDuration` / shared error | **Fixed** — dedicated `SY_VALUE_NOT_VALID`; `MIN_TWAP_DURATION` cached as immutable (saves a per-build staticcall); NatSpec corrected. |
| best-practice nits | **Applied** — `VERSION = 1` on both recorders (locked-bytecode family convention); `ORACLE` stored as the typed interface; interface `@param`/`@return` wording corrected. |
| **P3-2 / P3-3** TWAP cost basis / cardinality | **Documented** (design-accepted / ops onboarding); P3-2 additionally proven not same-tx manipulable. |
| **P3-5 / P3-6** | Verified safe, no change. |

Bytecode regenerated + synced (generated/locked-dev/locked) for both recorders. Post-fix tests: purchase unit **27**, redemption **20**, V1 fork E2E **14**, PendlePTHookE2E **32**, legacy oracle-hooks **17**, HookSizingInterface **217** — all green.

---

## Design context (why the "self-referential cost basis" findings are a chosen tradeoff)
The spec explicitly requires the purchase recorder to "calculate the SY accounting cost on-chain … rather than requiring `syAccountingAssetSpent` as user input." This deliberately replaces an **off-chain quoted cost** — the exact vector behind the PT-mAPOLLO / Kyber poisoned-quote incident that opened this session — with the oracle's own TWAP valuation. The research agent's F1/F2 (cost basis == mark, TWAP-manipulable) are therefore accepted, bounded tradeoffs, not defects: the face-value cap (`sySpent ≤ ptAmount` since the rate ≤ 1 pre-maturity), the 15-min TWAP cost-to-move, and per-`msg.sender` isolation bound the blast radius to the actor's own book value and its own performance-fee baseline. They are recorded below as P3 with mitigations, not as blockers.

---

## P2 Findings (Medium — Should Fix)

### [P2-1] V1 face-value guard mixes SY-asset decimals with PT decimals — DoS or dead guard on decimal-mismatched markets
- **File:** `src/accounting/oracles/PendlePTAmortizedOracle.sol:206`, reached via `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol:143-151`
- **SWC:** N/A · **Category:** Arithmetic / Vault & Share Accounting (vulnerabilities.md §3, §22)
- **Description:** The hook feeds `sySpent = getAssetOutput(market, 0, ptAmount)` (denominated in the SY **accounting-asset** decimals) into V1's `recordPurchase`. The oracle then checks `if (newBookValue > currentPtBalance) revert BOOK_VALUE_EXCEEDS_FACE_VALUE()`, comparing an asset-decimal value against a **PT-decimal** balance, and blends `A = ptAmount` (PT decimals) with `B_t0` (asset decimals) inside `_calculateAmortizedBookValue`. Coherent only when `PT.decimals() == assetInfo().assetDecimals`.
- **Exploit / Failure Scenario:** On a market where asset decimals > PT decimals, `sySpent` is numerically ~10^(Δdec) larger than `currentPtBalance`, so **every** `recordPurchase` reverts — the whole userOp (including the preceding successful PT swap) is permanently DoS'd for that market. In the reverse case the guard is numerically dead and `getTVLByOwnerOfShares` is corrupted. `getAssetOutput`'s `10 ** (PRICE_DECIMALS - assetDecimals)` scaling also underflows for assets with >18 decimals.
- **Reachability of THIS diff:** Pre-existing V1 oracle behavior, but the retarget makes V1 the live recording path, so it is now reachable through these hooks. **mAPOLLO is NOT affected** (PT-mAPOLLO and the USDC accounting asset are both 6-dec) — which is why the fork suite passes; the risk is other markets.
- **Secure Pattern:** Normalize both sides to a common unit before the guard (compare against `currentPtBalance` scaled by `10^(assetDec - ptDec)`), and normalize `A` inside `_calculateAmortizedBookValue`; guard the decimals scaling against `assetDecimals > 18`. **Simplest operational fix:** restrict market onboarding to `PT.decimals() == assetInfo().assetDecimals` and document the invariant in the hook NatSpec. With that onboarding rule enforced, effectively P3.
- **Reference:** §3 (Arithmetic), §22 (Vault & Share Accounting), §25 (unit-consistency heuristics). Corroborated by all three agents and the earlier hook-master review.

---

## P3 Findings (Low / Informational)

### [P3-1] Deploy-script availability gate keyed on the V2 flag while the deploy block uses V1 config — `expectedHooks` miscount — **FIXED**
- **File:** `script/DeployV2Core.s.sol:635` (gate) vs `:3806-3822` (deploy block)
- **Category:** Deployment / Operational (§36)
- **Description:** The gate decremented `expectedHooks` on `!(pendlePTAmortizedOracleHooksV2 && pendleRouterHooks)`, but the deploy block binds the recorders to `configuration.pendlePTAmortizedOracles` (V1). On a chain with V1 but not V2 (or vice-versa) the deployment-verification count diverges from what is actually deployed.
- **Resolution:** Gate changed to `pendlePTAmortizedOracleHooks` (V1) to mirror the deploy block. Deploy script recompiles. *(Applied during this review.)*
- **Reference:** §36 (deploy/config consistency).

### [P3-2] Cost basis is the oracle's TWAP valuation, not tokens actually spent — bounded book-value inflation / performance-fee imprecision
- **File:** `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol:143`
- **Category:** Oracle & Price Manipulation / DeFi Accounting (§4, §17, §22)
- **Description:** Recorded `sySpent = getAssetOutput(...)` (15-min `getPtToAssetRate` TWAP), not `TradeResult.inputAmount`. An account buying below TWAP, or nudging the TWAP up across the window on a thin/sparse market, records a cost basis above real cost, shaving the performance fee the SuperLedger charges on the PT-discount accrual. **Bounded** by: rate ≤ 1 ⇒ `sySpent ≤ ptAmount`; the face-value cap; a 15-min TWAP being expensive to move; and per-`msg.sender` isolation (only the actor's own book/fees). Consistent with the oracle's documented permissionless trust model and SECURITY.md's "protocol fees may be bypassed in edge cases." This is the spec-chosen tradeoff (see Design context).
- **Mitigation (optional, if tighter fee integrity wanted):** record `min(TWAP valuation, actual inputAmount converted to asset units)` in auto mode; prefer a longer/market-tiered TWAP; gate recording on market liquidity/warmth; restrict manual mode in production wiring.
- **Same-tx / same-block manipulation is provably impossible (verification agent):** `sySpent` is snapshotted in `build()` and passed as a **parameter** — the oracle never re-prices, and `SuperExecutorBase._processHook` (nonReentrant) runs `build`→`_execute` with nothing pricing-relevant in between. Pendle's TWAP is same-block invariant by construction (`PendleMarketV3` writes the pre-swap `lastLnImpliedRate`; `OracleLib.write` early-returns on subsequent same-block swaps), so neither the PendlePTHook's own preceding BUY nor a same-block front-run can move the 900s cumulative. Only **sustained multi-block** pre-manipulation remains, and it is face-value capped (`getPtToAssetRateRaw ≤ 1e18`). This reduces the practical exposure to a slow, expensive, self-only, fee-baseline nudge.
- **Reference:** §4.1, §17.5, §22.3.

### [P3-3] No observation-cardinality / TWAP-warmth precheck — build-time revert can DoS the whole userOp on fresh markets
- **File:** `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol:139,143`; oracle `getPricePerShare`→`getPtToAssetRate(900)` and `recordPurchase` `MARKET_EXPIRED`
- **Category:** DoS (§7.4)
- **Description:** The `twapDuration >= ORACLE.TWAP_DURATION()` check validates only the **encoded intent number**, never the market's actual observation buffer. On a market whose cardinality was never grown to span 900s, `getPtToAssetRate(900)` reverts `OracleTargetTooOld`, unwinding the entire executor sequence (including the already-executed PT swap). **Confirmed concretely:** this is exactly the revert the fork tests hit on mAPOLLO before cardinality was increased, which is why the suite primes the market in `setUp`. A partially-warmed buffer also shortens the effective TWAP window (amplifies P3-2).
- **Mitigation:** Before pricing, call Pendle `getOracleState(market, TWAP_DURATION)`; if `increaseCardinalityRequired || !oldestObservationSatisfied`, revert with a clear error (or trigger `increaseObservationsCardinalityNext`) and restrict onboarding to warmed markets. Have the intent builder refuse BUY_PT record chains near maturity. Can be enforced entirely off-chain at onboarding — no code change strictly required, but a clear on-chain error would be friendlier than `OracleTargetTooOld`.
- **Reference:** §7.4, §4.2. Pendle docs: "How to Integrate PT and LP Oracle" (must `getOracleState` / `increaseObservationsCardinalityNext`).

### [P3-4] `twapDuration` is a vestigial field in V1 — validated but not rate-selecting; distinct zero-valuation error added — **PARTIALLY ADDRESSED**
- **File:** `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol:54,112,139,178`
- **Category:** Code Quality / Logic (§15.4)
- **Description:** V1 prices with its own immutable duration; the encoded `twapDuration` only gates pass/fail of the `>= TWAP_DURATION()` check (kept for V2-layout compatibility and as a signed-intent sanity floor). The `@return` doc previously described V2 "passed to the oracle" behavior.
- **Resolution:** `decodeTwapDuration` NatSpec corrected to state it is validated, not forwarded. The zero-valuation path now reverts with a dedicated `SY_VALUE_NOT_VALID()` (was the shared `AMOUNT_NOT_VALID`), improving revert triage. Field itself retained (removing it is a layout/bytecode change). *(Applied during this review.)*
- **Reference:** §15.4.

### [P3-5] Following hook trusts preceding hook's self-reported amount — well-guarded; residual = TradeResult freshness
- **File:** `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol:117-131`
- **Category:** ERC-7579 hook composition / trust (§39)
- **Description:** In auto mode the recorder trusts `TradeResult` from the prev hook. Mitigations are correct: `prevHook == APPROVED_PENDLE_PT_HOOK` pinned **before** any external call, `operation == BUY_PT`, market match, and PT identity re-read from the matched market. **Verified:** `TradeResult` lives in **transient** storage keyed by BaseHook's per-account execution-context nonce (`PendlePTHook.sol:734-757`), cleared per transaction — no stale/cross-account replay (this is the invariant the E2E `test_TradeResult_ContextIsolation` / `test_ContextIsolation_RealMarket` guard). Redemption correctly records `inputAmount` (PT spent), never `getOutAmount`.
- **Mitigation:** None required; keep `APPROVED_PENDLE_PT_HOOK` immutable (it is).
- **Reference:** §39 (intent-based / signed-input trust).

### [P3-6] Manual mode (`usePrevHookAmount == false`) accepts an arbitrary `market`
- **File:** `src/hooks/oracles/pendle/RecordPurchasePendlePTHook.sol:110,143`; `RecordRedemptionPendlePTHook.sol:95,137`
- **Category:** External call / trust model (§8.2)
- **Description:** With manual mode, `market` comes straight from signed hook data; a malicious "market" could return arbitrary rate/PT addresses. **Contained** by per-`msg.sender` oracle bookkeeping (documented at `PendlePTAmortizedOracle.sol:27-30`) and the signed-intent trust model (only known-good markets are signed). Auto mode is strictly stronger (market cross-checked against the committed TradeResult).
- **Mitigation:** Acceptable as designed; for defense-in-depth, validate `market` against a registry/whitelist in manual mode, or disable manual mode in production wiring.
- **Reference:** §8.2, §39.

---

## Verified-correct (checked, no finding)
- **V1 argument order:** `abi.encodeCall(IPendlePTAmortizedOracle.recordPurchase, (market, sySpent, ptAmount))` matches `recordPurchase(address, uint256 sySpent, uint256 ptAmount)` — `sySpent` 2nd, `ptAmount` 3rd; pinned by unit test `test_CallData_ArgumentOrder_MarketSySpentPtAmount`. Redemption selector `recordRedemption(address,uint256)` is byte-identical V1/V2.
- **Auto-mode guard ordering:** approved-prev-hook pinned before the external call; op/market/PT-identity all enforced; redemption uses `inputAmount` (PT spent).
- **Context isolation:** transient, execution-context-nonce-keyed TradeResult; `Operation.NONE` rejected.
- **Zero handling:** zero PT amount → `AMOUNT_NOT_VALID`; zero oracle valuation → `SY_VALUE_NOT_VALID`; oracle also enforces `ZERO_AMOUNT`.
- **Face-value cap (matched decimals):** `sySpent ≤ ptAmount` (rate ≤ 1) ⇒ no spurious `BOOK_VALUE_EXCEEDS_FACE_VALUE` DoS on legitimate buys.
- **Deploy wiring:** binds to the **V1** config field and the CREATE2 `APPROVED_PENDLE_PT_HOOK` from this run's PendlePTHook initCode; deterministic whether PendlePTHook is fresh or already on-chain.
- **Reentrancy / pragma / encoding:** `_buildHookExecutions` is `view`; only state-changing target is the trusted immutable `ORACLE`; locked pragma `0.8.30`; `abi.encodePacked` uses are single-address (no collision); PASSTHROUGH pipe + pre/post mutexes correct; ERC-165 advertises S2 sizeless correctly.

## Attack Surface Summary
- **External entry points:** `build()` (view) → `preExecute`/`postExecute` (account-gated) → single oracle `recordPurchase`/`recordRedemption` execution.
- **Value transfer points:** none in these hooks (side-effect-only; PASSTHROUGH forwards prev output).
- **Oracle dependencies:** Pendle `getPtToAssetRate(TWAP_DURATION)` via `PendlePTAmortizedOracle` — the central dependency (P2-1, P3-2, P3-3).
- **Cross-contract interactions:** `IPendlePTHookResult(prevHook)`, `IPendleMarket(market).readTokens`, `IPendlePTAmortizedOracle(ORACLE)` — all view at build time.
- **Upgrade mechanisms:** none; immutable `ORACLE` / `APPROVED_PENDLE_PT_HOOK`; locked-bytecode deployment.

## Coding-standards findings (applied / noted)
- **Applied:** dedicated `SY_VALUE_NOT_VALID()` error for zero valuation; `decodeTwapDuration` `@return` NatSpec corrected; interface `TWAP_DURATION()` `@return` tag added.
- **Noted, not applied (cosmetic / would need bytecode churn):** interface `@param sySpent` wording ("Amount of SY spent" → "purchase cost in SY accounting-asset units") and local var name `sySpent` vs legacy `syAccountingAssetSpent`; optional `VERSION` constant per the record-hook-family convention; caching `ORACLE.TWAP_DURATION()` as an immutable to save one staticcall per build; constructor `@notice` lines; storing `ORACLE` as the typed interface. None affect correctness.

## Security knowledge sources
- **vulnerabilities.md sections referenced:** 3, 4, 7, 8, 14, 15, 17, 22, 25, 36, 39.
- **Coding rules:** `superform-specs/guidelines/solidity/coding-rules.md` (NatSpec, custom errors, naming, imports, gas).
- **External (research agent):** Pendle PT oracle integration & PT-as-collateral docs, Chaos Labs PT Risk Oracle, Hacken UniV4 truncated-oracle TWAP, Cyfrin/Halborn oracle-manipulation, ChainSecurity Pendle V2 Core audit, ERC-7579/7484.

## Post-review test status
- Record-hook unit suites: 25 (purchase) + 20 (redemption) — green after adding `SY_VALUE_NOT_VALID`.
- New V1 fork suite `PendlePTHookV1AmortizedOracleE2E`: 14/14 green.
- `PendlePTHookE2E`: 32/32; V1/V2 oracle unit suites: 147; HookSizingInterface: 217. Bytecode regenerated + synced (generated/locked-dev/locked) for the changed recorder.
