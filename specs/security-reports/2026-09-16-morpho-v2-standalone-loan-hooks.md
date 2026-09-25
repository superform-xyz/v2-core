# Security Analysis Report — Morpho V2 Standalone Borrower Hooks (PLEDGE / BORROW / RELEASE)

## Metadata
- **Target:** src/hooks/loan/morpho/{BaseMorphoStandaloneLoanHookV2, MorphoSupplyHookV2, MorphoBorrowHookV2, MorphoWithdrawCollateralHookV2}.sol + new/extended test suites (branch feat/morpho-v2-standalone-loan-hooks)
- **Mode:** review (inline scan + 3 parallel agents + orchestrator verification of executor exec-mode)
- **Date:** 2026-09-16
- **Contract Types Detected:** ERC-7579 executor hooks (build-only), lending/borrower (Morpho Blue)
- **Files Analyzed:** 4 new src + 4 test files, 8 context files (BaseHook, BaseLoanHook/V2, BaseMorphoLoanHookV2, shipped V2 siblings, SuperExecutorBase, vendored IMorpho)
- **Vulnerability Database:** superform-specs/guidelines/solidity/vulnerabilities.md

## Summary

| Severity | Count | Blocks Merge |
|----------|-------|--------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 1 | No |
| P3 Low | 8 | No |

## Verdict

**PASS** — no P0/P1. Inline scan clean on all 10 critical patterns (locked pragma, no
try/catch, no low-level calls, encodePacked over fixed-size types only, empty Morpho callback
bytes throughout — `borrow`/`withdrawCollateral` have no callback parameter at all, verified in
the vendored interface). The sibling-convention divergence check found **zero divergences** from
the shipped SUP-20796 hooks, and all eight documented-accepted behaviors were verified against
the implemented code with no doc/behavior mismatches.

Execution-model probes (adversarial): build/preExecute divergence is impossible for third
parties (atomic `_processHook`, no external yield point on the happy path — collateral doesn't
accrue, so even the RELEASE max sentinel cannot diverge); direct `preExecute`/`postExecute`
calls are gated by `msg.sender == account`; third-party donations/repays cannot corrupt the
published outputs (wallet donations mid-batch force `DELTA_MISMATCH`, Morpho-position donations
never touch wallet balances); Morpho transfers exact `assets` on all three calls, so strict
delta equality has no rounding leak; the PLEDGE approve-0/N/…/0 pattern is USDT-class safe.

**Orchestrator-verified:** the ERC-7579 try-mode concern from external research is closed —
modulekit's `ERC7579ExecutorBase._execute` hard-codes `EXECTYPE_DEFAULT` (single and batch), so
hook reverts always abort the whole userOp; empirically confirmed by the fork tests that assert
`UserOperationRevertReason` on failed inner Morpho calls.

## P2 Findings (Should Fix)

### [P2-1] BORROW/RELEASE are the family's first FAIL-OPEN prev-pipe consumers — an inflated predecessor output creates unintended debt instead of reverting
- **File:** src/hooks/loan/morpho/MorphoBorrowHookV2.sol (`_resolveExactPrimary` prev path); MorphoWithdrawCollateralHookV2.sol (`_resolveReleaseAmount` prev path)
- **Category:** Intent-pipeline sizing / transient-output poisoning amplification
- **Description:** Every shipped `usePrevHookAmount` consumer sizes a *spend* leg: if an
  attacker inflates the predecessor's published `outAmount` mid-transaction (requires a
  callback-bearing token in the chain — the accepted SECURITY.md hook-safety assumption, e.g.
  via the `setOutAmount` write window after `resetExecutionState` and before `_updateAccounting`
  of the preceding accounting hook), the spend fails closed — the wallet doesn't hold the
  inflated amount, so the transfer or `DELTA_MISMATCH` reverts. BORROW inverts this: the sized
  amount is **minted by Morpho** (`borrow` pays out unconditionally up to LTV), so a poisoned
  prev output executes AND settles clean (`_settleBorrow` compares two values both derived from
  the poison). Victim outcome: more debt than the signed intent, plus liquidation exposure.
  RELEASE fails open analogously (over-withdraws the victim's own collateral while Morpho's
  health check passes). The signed calldata word is ignored under usePrev (shipped convention),
  so nothing bounds the piped value.
- **Exploit Scenario:** Victim signs approve(777-token)→…→BORROW(usePrev). During the preceding
  hook's fee transfer, the attacker's `tokensReceived` callback calls
  `prevHook.setOutAmount(inflatedAmount, victim)` (unauthenticated; mutexes already cleared).
  The borrow hook resolves the inflated amount and borrows it against the victim's collateral.
- **Secure Pattern (fixable in the NEW, unlocked hooks only):** treat the signed calldata word
  as a CAP on the prev-pipe value for provider-minting legs:
  `if (usePrev) { resolved = prevOut; require(resolved <= amountWord); }` — a poisoned pipe can
  then never size a mint leg beyond what the user signed. Encoding impact: OMS must place a real
  upper bound in the word for BORROW/RELEASE usePrev flows instead of a placeholder (hooks are
  not yet deployed, so no back-compat constraint). Alternative (status quo): bundler policy
  never routes callback-capable tokens into chains feeding a mint-leg usePrev slot.
- **Reference:** vulnerabilities.md §23.7, §1.5, §39.3, §25.1 (spend legs fail closed / mint legs fail open asymmetry).
- **Status:** ACCEPTED AS-IS (user decision — see Resolution Log): callback-bearing tokens are
  not used in Superform chains, so the poisoning prerequisite is absent in practice.

## P3 Findings (Consider Fixing)

1. **Self-chaining DoS (fail-closed):** `hookA == prevHook` with usePrev always reverts
   `PREV_TOKEN_MISMATCH` because `setExecutionContext` re-contexts the hook between build and
   preExecute. No fund risk; contradicts the determinism comment in locked `BaseLoanHookV2`
   (cannot be edited). Mitigation: bundler routing rule — never pipe a V2 loan hook into the
   same hook contract.
2. **RELEASE `decodeAmounts` returns the raw max sentinel** to off-chain sizing consumers —
   identical to the shipped close hook's slot-2 convention; informational for OMS.
3. **Fork-suite banner numbering:** Ethereum suite restarts at "6." (duplicating 6/7); Base
   suite's new banner is unnumbered/two-line. Style only.
4. **`_resolveReleaseAmount` NatSpec parity:** missing `@param`/`@return` tags and placed after
   `_postExecute`, unlike sibling `_resolveWithdrawLeg`.
5. **Dangling reflowed comment** in Base suite chained-test (orphaned `// COLLATERAL_USDC`
   continuation line).
6. **Doc nit:** RELEASE header says sentinel "read at build time"; it re-runs in `_preExecute`
   (values provably equal — collateral doesn't accrue).
7. **Coverage note:** borrow/release usePrev covered at build level; only pledge has an
   end-to-end chained fork round-trip. Low risk (same resolver both paths).
8. **ERC-1271/leaf canonical-encoding note (external):** exact-length checks in
   `_decodeMorphoV2` already reject padded calldata; no action.

## Architectural Findings (off-chain / operational — not contract defects)

- **[A-1] Toxic-but-well-formed market params (Morpho PAXG/USDC class, Oct 2024 — $230K):**
  the hooks take MarketParams as raw calldata and delegate all health arbitration to Morpho by
  design; a misconfigured-oracle market is invisible on-chain. Launch control: the off-chain
  planner must validate the market oracle's price/scaling against a reference feed before
  building, and monitoring must watch the MARKET oracle, not reference prices (the PAXG incident
  was missed because the UI showed reference prices). Full MarketParams are already bound into
  the signed leaf via inspect() — the control needed is planner-side validation.
- **[A-2] Builder-misdirection precedent (Morpho App/Bundler3, Apr 2025 — $2.6M whitehat):**
  closest real-world analog to this architecture; failure was approvals granted to an
  initiator-agnostic intermediary. Our hooks hard-target the immutable Morpho singleton for
  approvals, reset allowance to zero in-batch, and prove it in fork tests — this class is
  structurally closed. Keep it that way: no future hook may approve an intermediary.
- **[A-3] Morpho authorization drift:** `setAuthorization`/`setAuthorizationWithSig` grant
  market-agnostic, receiver-arbitrary borrow/withdraw power. These hooks correctly use self-call
  identity only. Invariant for future work: no Superform-built execution may ever target those
  selectors (2025 permit-phishing meta applies directly).
- **[A-4] Stale exact sizing:** exact amounts + strict deltas convert market drift (liquidity
  withdrawal, accrual) into whole-batch DoS — correct integrity trade-off; near-LLTV sizing
  plus long/infinite deadlines (a documented protocol trade-off) is the risky combination.
  Planner should apply LLTV margins and short deadlines for borrower intents. Note
  `replaceCalldataAmounts` lets the bundler resize the borrow/release slot within the signed
  root's constraints — the planner's health reasoning does not cover replaced sizes; Morpho's
  health check becomes the only arbiter.

## Attack Surface Summary
- **External entry points:** `build` (view, safe for arbitrary callers — no state), `preExecute`/
  `postExecute` (gated `msg.sender == account`), sizing views, `inspect`.
- **Value movement:** entirely inside the smart account's own batch; hooks never hold funds or
  approvals (allowance-zero proven in fork tests).
- **Oracle dependencies:** none in-hook (market oracle is identity-bound calldata, never priced).
- **Cross-contract:** immutable Morpho singleton only; empty callback bytes by construction.
- **Upgrade surface:** none (no proxies, no admin, immutables only).

## Coding Standards
`forge fmt --check` clean on all 8 files; build clean; 35/35 unit, 21/21 + 13/13 fork, 24/24
sizing. Idiom-exact vs shipped siblings (banners, @inheritdoc, error reuse — zero new errors,
NatSpec offsets verified against the layout constants, import order, visibility/mutability).
The 4 style nits are P3 items 3–6 above.

## Security Knowledge Sources
- vulnerabilities.md: §1.5, §14.4, §23.7, §25.1, §25.2, §29, §39.3 + the 10-pattern critical scan
- External: Morpho PAXG oracle incident (Verichains/SolidityScan), Morpho App/Bundler3
  postmortem, Trail of Bits "Six mistakes in ERC-4337 smart accounts" (Mar 2026), EIP-7579
  exec-mode semantics (verified against modulekit source), Morpho authorization model
  (docs/MixBytes/Taichi), USD0++ depeg postmortem, OWASP SC Top 10 2025
- Notable negative result: no public 2024–2026 exploit of Morpho Blue's core
  supplyCollateral/borrow/withdrawCollateral paths — all incidents were periphery (oracle
  config, frontend/builder config, curator behavior)

## Resolution Log
- P2-1: ACCEPTED AS-IS (user decision): callback-bearing (ERC-777-style) tokens are not used in
  Superform chains, so the poisoning prerequisite is absent in practice; covered by the existing
  SECURITY.md hook-safety trust assumption. Bundler/whitelist policy: never route a
  callback-capable token into a chain feeding a BORROW/RELEASE usePrevHookAmount slot.
- P3 items 3-6: FIXED (fork-suite banners renumbered 8/9/10 + Base banner numbered single-line,
  _resolveReleaseAmount given full @param/@return tags and moved above _preExecute, dangling
  reflowed comment repaired, sentinel doc says build/preExecute time). Bytecode verified
  UNCHANGED by these edits (generated == locked, no relock needed). All suites re-run green
  (35 unit / 21 + 13 fork).
- P3 items 1, 2, 7, 8: informational, no action (self-chain routing rule + decodeAmounts
  sentinel note for OMS; borrow/release chained round-trip left as optional follow-up).
