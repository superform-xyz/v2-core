# EVM Security Research: Aave V4 Accounting Oracles (SUP-20854)

Produced by security researcher, 2026-09-02.
**Scope:** `AaveV4DebtOracle`, `AaveV4SupplyYieldSourceOracle`, `AaveV4ReserveRegistry` — read-only accounting oracles feeding SuperLedger cost-basis/fee logic, including tokenized-equity collateral markets on Base.
**Vulnerability DB:** `/Users/cosming/1.Coding/Superform/superform-specs/guidelines/solidity/vulnerabilities.md` (5052 lines; note the DB lives in superform-specs, NOT v2-core). Section numbers refer to that file.

Key in-repo references: `EulerDebtOracle.sol` (debt shape), `MorphoBlueMarketRegistry.sol` (registry), `MorphoBlueDebtOracle.sol`, `AbstractYieldSourceOracle.sol`, `BaseLedger.sol` (`_processOutflow` L198, `_calculateFees` L232-246), `IAaveV4Spoke.sol` (`getUserDebt` L93, `getUserSuppliedAssets` L99, `Reserve.flags` L30).

## 1. Relevant Vulnerability Patterns

### 1.1 Read-only reentrancy against lending-state views — §1.4, §18.3.1, §28.4
**Severity in context: Medium (down-rated from Critical).** Classic pattern (Curve Jul 2023, Sentiment, Sturdy): a view returns mid-transaction-inconsistent state during a callback. These oracles read position state, not pool-ratio state; Aave spokes update user state atomically per operation, and the oracles hold no price feeds (own-asset denomination removes the ratio-manipulation surface).
Residual: if a hook chain ever runs during an Aave flash-loan/position-manager callback, `getUserDebt` may include transiently drawn debt. Ordering concern at the hook/executor layer, not fixable in a view-only oracle — document; assert in hook design reviews that accounting reads never occur inside an Aave-initiated callback frame.

### 1.2 Oracle-consumer staleness — §4.2, §48.6, §48.11
Mostly N/A by design (no price feeds, no heartbeat). Surviving question: do spoke views include accrued-but-unindexed interest + premium? (Framework research says yes — virtually accrued; **fork-verify anyway**.) If views lagged, debt would under-report, violating "report at least what's owed". Equity trading hours create NO staleness here — no price inside the oracle.

### 1.3 Fee-accounting manipulation: feePercent = 0 invariant — §14.3, §25.5 + BaseLedger source
**Blast radius if violated (traced):** debt takes no cost-basis snapshots → `costBasis = 0` → `_calculateFees`: `profit = amountAssets` → **the entire repaid debt is treated as profit**. At 10% fee on a 100k USDC repay, 10k USDC skimmed from a user who earned nothing. Both fee paths exposed: `BaseLedger._processOutflow` (ledger) and `getAssetOutputWithFees` (view, L105-122).
Interview locked operational-invariant-only (decision #5). Spec must require: (a) NatSpec block ≥ EulerDebtOracle L17-24 strength covering both paths; (b) ops runbook + governance-review checklist item (debt oracle id must have feePercent = 0 or be unregistered); (c) **an executable unit test demonstrating the misconfiguration damage**.
Note `_calculateFees` L244 `FEE_NOT_SET` revert on feePercent==0-with-profit — unreachable from guarded call sites; correctness must never depend on reaching it.

**Supply-side (fee-capable) leaks** (known SECURITY.md trade-offs, restate):
- Direct spoke withdrawal (self-calls allowed by `onlyPositionManager`) bypasses SuperLedger → cost-basis desync → fee drift on later tracked outflows.
- Utilization-spike accrual nudging (§17.5, §28.2) — dust-level per tx on Aave-style curves. Low.

### 1.4 Registry key rebinding / admin risk — §2.1, §34.6, §35.x
The decisive property in MorphoBlueMarketRegistry: the key is **hash-DERIVED** from market identity (L202-203) — a key can only ever bind to the params that hash to it; re-registration after deregistration cannot rebind to a different market. No-overwrite (L205), 2-day timelocked deregistration (L84, L220-246).
**Critical spec requirement:** derive `reserveKey` from `(spoke, reserveId)` — `address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))` — NOT operator-chosen. With an operator-chosen key, a compromised MARKET_MANAGER_ROLE could rebind an active key to a different reserve, silently repointing SuperLedger cost basis — a fee/accounting corruption primitive. "Mirror MorphoBlueMarketRegistry" is only safe if the *derivation* is mirrored, not just the role model.
Also inherit: register-time validation (`getReserve(reserveId)` succeeds, non-zero underlying — matches hooks' binding check); deregistration SAFETY INVARIANT NatSpec (L33-40); spoke-trust note (spoke is the trust root, role-gated; no IRM analog exists in V4 — consider an approved-spokes set if multiple spokes per chain).

### 1.5 Paused/frozen reserve DoS on accounting reads — §7.2, §7.4, §46.4, G.2
V3 views keep working when paused; V4 expected to match but **must be fork-verified** — equity reserves may pause routinely. If a view reverts while paused: single-key reads brick `_processOutflow` (withdrawal accounting DoS, externally triggered); batch reads survive via try/catch as `0, succeeded=false` — consumers must not read that as "position closed". Documented-risk item + Joao-call question.

### 1.6 Empty-revert / malformed-return handling in batch views — §29.3, §29.4
- §29.3: try/catch does NOT catch return-data decode failures in the caller — a spoke returning malformed data post-upgrade (or a codeless account, §29.4) aborts the whole batch. Acceptable inherited risk — document; test as known-issue.
- Unregistered keys must **revert with a typed registry error** (clean, catchable, batch-isolated) — never return 0 (0 would let SuperLedger record zero-value outflows → fee bypass / zero PPS).

### 1.7 Donation/inflation against the supply read — §22.1, §22.2, §28.1, §28.3, §18.1.2
Structurally mitigated: V4 supply accounting is internal share/index bookkeeping; donating underlying to the spoke does not move `getUserSuppliedAssets`. Empty-market donation attacks (Hundred/Sonne/Onyx) are an *Aave-side* risk on fresh low-liquidity equity reserves — one line in the risk section since Superform users may be early suppliers.

## 2. Exploit Precedents

| Incident | Date / Loss | Mechanism | Relevance |
|---|---|---|---|
| Sentiment | Apr 2023, ~$1M | Read-only reentrancy: Balancer view read during joinPool callback | Medium — defines the review question: can any hook chain read these oracles inside an Aave callback frame? |
| Sturdy Finance | Jun 2023, ~$800k | Same Balancer read-only reentrancy | Medium, same lesson |
| Curve/Vyper | Jul 2023, ~$70M | Broken locks; `get_virtual_price` consumers | Low-Medium background |
| Cream (yUSD) | Oct 2021, $130M | `getPricePerFullShare` accounting view inflated by donation | High conceptual — same class; mitigated (no donatable balances, identity PPS, no pool math) |
| Euler | Mar 2023, $197M | `donateToReserves` desynced internal debt accounting | Medium — are there V4 ops (liquidation, premium re-rating, socialization) that change `getUserDebt` discontinuously? Safe only while feePercent = 0 |
| Compound Prop 62 | Sep 2021, ~$80M+ | Reward-accrual math with wrong baseline self-drained | Medium — costBasis=0 → everything-is-profit is exactly this shape |
| Hundred/Sonne/Onyx/Midas | 2022-24 | Empty-market donation + rounding on forks | Low for oracles; Medium for early equity-reserve participation (Aave-side) |
| Venus (LUNA) | May 2022 | Paused markets froze accounting | Low-Medium; maps to §1.5 |

**Synthesis:** every precedent attacks (a) views over manipulable pool balances/ratios or (b) accrual math with a wrong baseline. Decisions taken (identity PPS, own-asset units, no price feeds, validated registry) eliminate (a). Class (b) survives as the feePercent invariant + premium-debt semantics — concentrate spec/test effort there.

## 3. Attack Surface Map

### AaveV4DebtOracle (view-only)
| Surface | Vector | Assessment |
|---|---|---|
| balance/TVL-by-owner → `getUserDebt` | Transient debt in callback frames; premium accrual lag | Hook-layer ordering risk (§1.1); fork-verify accrual (§1.2) |
| drawn + premium sum | Overflow | Checked 0.8.30; batch try/catch isolates — fine |
| `getPricePerShare` = 10**decimals | decimals ≥ 78 revert | Non-issue; document per Euler |
| Fee paths | feePercent > 0 → full debt taxed as profit | **Highest-consequence item** (§1.3) |
| `getTVL` | Needs aggregate view — vendor interface extension (`getReserveDebt`) | Spec decision |
| Unregistered/deregistered key | Reverts → accounting brick if deregistered live | Inherit SAFETY INVARIANT |

### AaveV4SupplyYieldSourceOracle (view-only, fee-capable)
| Surface | Vector | Assessment |
|---|---|---|
| `getUserSuppliedAssets`/shares | Donation inflation | Structurally mitigated (§1.7) |
| Cost-basis/fee math | Direct-withdraw desync; accrual nudging | Known accepted trade-offs, restate |
| Balance semantics | Consumer misreading units | NatSpec required |
| Paused/frozen equity reserve | View revert → outflow DoS | Aave-side assumption to verify (§1.5) |

### AaveV4ReserveRegistry (only writable surface)
| Surface | Vector | Assessment |
|---|---|---|
| `registerReserve` | Malicious/wrong spoke; wrong binding | Role-gated + register-time `getReserve` validation; spoke = trust root |
| Key derivation | Operator-chosen key → rebinding primitive | **Must be hash-derived** (§1.4) |
| Deregistration | Live-position brick; rebind-after-deregister | Timelock + SAFETY INVARIANT + hash-derived keys |
| MARKET_MANAGER_ROLE compromise | Hostile spoke under new key | Blast radius limited by hash derivation + no-overwrite; separate hot key per Morpho note |

## 4. Recommended Security Patterns

1. **Hash-derived registry keys** from (spoke, reserveId) — binding immutable-by-construction. Single most important decision.
2. **Register-time on-chain validation** — `getReserve` succeeds, non-zero underlying; store (spoke, reserveId, underlying); consider exposing underlying for consumer cross-checks.
3. **No-overwrite + timelocked deregistration + SAFETY INVARIANT NatSpec** — copy Morpho verbatim.
4. **Revert-on-unregistered, typed error** — never return 0.
5. **Identity PPS + own-asset units + zero price feeds** — keep; cross-asset conversion stays external.
6. **Conservative rounding documented** — debt never under-reports (V4 rounds up at source; pass through).
7. **feePercent = 0 invariant triple-anchored** — NatSpec (both paths), ops runbook/governance checklist, executable misconfiguration test.
8. **Immutable constructor-light oracles** — immutables + zero-address checks, no admin surface.
9. **Locked-bytecode freshness** — regenerate + verify (PR #990 R1 precedent).
10. **Vendor interface pinning** — extend `IAaveV4Spoke` minimally; fork-pin against the live spoke; V4 is pre-hardening.

## 5. Protocol Interaction Risks

1. **Mid-transaction spoke state / callback frames** — is `getUserDebt` consistent at every externally observable point (spoke↔hub sequencing), or only post-transaction? Joao-call question. Superform hooks never sit inside Aave callbacks today; a future flash-loan hook would change that.
2. **Premium debt semantics** — can premium > 0 with drawn == 0? Does repay retire premium or drawn first (interacts with SUP-20842 cap logic)? Can premium be re-rated discontinuously (safe only while feePercent = 0)?
3. **RWA/equity reserve pausing** — verify view liveness under flags on the real Base spoke; hook settle path separately at risk from transfer restrictions (cross-reference, keep out of oracle scope).
4. **V4 API drift** — pin interface; fork-test every assumption; gate deployment on re-verification against the audited release.
5. **Spoke multiplicity** — per-risk-tier spokes are part of V4 design; registry handles it via the key, but ops must not register the same economic reserve under two spokes splitting one user position across yieldSource keys.

## 6. Testing Recommendations

Unit (mock spoke with `setUserDebt(drawn, premium)`):
1. **feePercent misconfiguration demonstration**: feePercent=1000 → feeAmount == 10% of full debt; feePercent=0 → 0. Executable documentation of the invariant.
2. **Supply fee math with cost basis**: deposit → accrue (index bump) → withdraw; fuzz amount/accrual/feePercent ∈ [0,10000]; invariants: `fee == (assetsOut - costBasis) * feePercent / 10_000`, fee == 0 on loss, no underflow/FEE_NOT_SET reachable.
3. **Zero edges**: (0,0), drawn-only, premium-only, fuzz to uint128 max each; `total == drawn + premium` exact; overflow reverts isolated in batch.
4. **Unregistered key**: every view reverts typed; batch returns `0, succeeded=false` for that entry only.
5. **Registry lifecycle**: duplicate-register reverts; timelock boundary fuzz; post-deregistration reads revert; re-registration restores the identical key (`computeReserveKey` property test).
6. **Registry validation**: reverting/zero-underlying/codeless spoke → typed revert (§29.4).
7. **Cost-basis desync (supply)**: ledger deposit → direct spoke withdraw half → ledger withdraw rest; assert documented trade-off behavior, quantified fee drift.

Invariant/fuzz (§25.7):
8. Debt balance monotonic non-decreasing under pure accrual.
9. `getTVL(key) >= getTVLByOwnerOfShares(key, user)` for any single user.
10. Batch/single equivalence for all registered keys.

Base fork:
11. `getUserDebt` post-borrow includes same-block premium; warp → accrual visible in-view without state touch.
12. Repay-to-zero via V2 hooks → oracle reads exactly 0 (both components) — consistent with SUP-20842 zero-debt-skip.
13. Read all views while a reserve is paused/frozen (or mock flags) — pin the view-liveness assumption.
14. Decimals sweep: USDC (6), WETH (18), equity token (verify actual decimals).
15. Malformed-spoke batch abort as documented known-issue test (§29.3).

**Bottom line:** decisions already taken eliminate the manipulable-view class (Sentiment/Cream/Sturdy). Three residual items with spec-level teeth: (1) feePercent = 0 blast radius (anchor with executable test), (2) hash-derived registry keys (rebinding impossible by construction), (3) two Aave-side assumptions for the Joao call + fork tests: view consistency at callback-observable points, and view liveness under paused/frozen equity reserves.
