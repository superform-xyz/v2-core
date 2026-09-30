# Security Analysis Report

## Metadata
- **Target:** SUP-21141 — Aave V4 V2 standalone PLEDGE / BORROW / RELEASE loan hooks (uncommitted, branch
  `cosmin-sup-21141-feature-add-aave-v4-v2-standalone-pledge-borrow-and-release`, stacked on PR #1018):
  `src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol` (new), `AaveV4SupplyHookV2.sol` (new), `AaveV4BorrowHookV2.sol` (new),
  `AaveV4WithdrawHookV2.sol` (new). Context read: `BaseHook`, `BaseLoanHook`, `BaseLoanHookV2`, `BaseAaveV4LoanHookV2`, the deployed
  OPEN / REPAY / CLOSE V2 hooks, the idle `BaseAaveV4MoneyMarketHook` pair, `SuperExecutorBase`, the Morpho standalone twins, and the
  upstream `aave/aave-v4` Spoke / Hub / AssetLogic / LiquidationLogic sources (verified Ethereum Main Spoke implementation).
- **Mode:** review (inline critical-pattern scan + vulnerability scanner + best-practices + EVM security research agents), plus three
  extra reviewers requested by the ticket owner: code-simplicity, correctness (test-vs-claim), adversarial live-fork probe (16 probes).
- **Date:** 2026-09-28
- **Contract Types Detected:** general — lending-protocol integration hooks (stateless, ERC-7579 executor context), NONACCOUNTING /
  LOAN subtype; no ledger posting.
- **Files Analyzed:** 4 new source files; tests as evidence: `test/unit/hooks/loan/AaveV4StandaloneLoanHooksV2.t.sol` (45),
  `test/unit/hooks/LoanHooksV2SizingIntegration.t.sol` (28), `test/integration/AaveV4V2HooksFork.t.sol` (32, Ethereum block 24_884_274),
  `AaveV4LoanBytecodeUnchanged.t.sol` (9 deployed LOAN artifacts byte-identical).
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (sections 1-51 + appendices A-M) + `coding-rules.md`;
  external: aave-v4 sources/docs, evmresearch.io, OWASP SC Top 10 (2025), 2025-2026 incident write-ups.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 (1 fixed in review, 1 accepted carry-over, 1 documented off-chain pre-flight) | No |
| P3 Low | 6 (4 fixed in review, 2 documented/accepted) | No |

## Verdict
**PASS** — No P0 or P1 findings. The primary controls hold and were exercised on the live Spoke: every amount is resolved and
bounded before any Spoke call (zero / max sentinel / above-position all revert with a specific error); both reserve ids are bound to
the declared tokens through `getReserve().underlying`; the Spoke is the only call target and approve spender, with approve-0 /
approve-N / … / approve-0 bracketing; `onBehalfOf` and the token receiver are always the account (self-call); settlement is by
measured wallet delta with strict equality, never by the Spoke's return values. The adversarial fork probe could not produce a
`DELTA_MISMATCH`, a partial fill, or any state change from a failed operation across liquidation (full and partial), freeze, pause,
oracle-low price, health-factor boundary bisection, same-hook reuse in one userOp, V1/V2 mixing and OMS-style amount replacement.
The one code change that came out of the review closes the LOAN-vs-idle mode-mixing gap on-chain in both directions (P2-2).

## Inline critical-pattern scan
| # | Pattern | Result |
|---|---|---|
| 1/5 | Reentrancy / missing guards | PASS — hooks hold no funds; Spoke `supply` / `withdraw` / `borrow` / `setUsingAsCollateral` are `nonReentrant` (transient) with no user callbacks; token movement is `safeTransferFrom(account → hub)` / `safeTransfer(to)` on plain ERC-20s; executor `_processHook` is `nonReentrant`; BaseHook pre/post mutexes |
| 2 | Access control | PASS — `preExecute` / `postExecute` require `msg.sender == account`; Spoke `onlyPositionManager(onBehalfOf)` self-call (outsider `supply` / `withdraw` / `setUsingAsCollateral` onBehalfOf → `Unauthorized()` 0x82b42900, live-probed) |
| 3 | Division before multiplication | PASS — no arithmetic beyond direction-guarded balance deltas |
| 4/6 | Unchecked returns / low-level calls | PASS — no `.call`, no `try/catch`; Spoke return values are ignored in favour of measured deltas |
| 6 | `abi.encodePacked` collisions | PASS — fixed-width 241-byte layout, exact length enforced |
| 7 | `tx.origin` | PASS — not used |
| 8 | Floating pragma | PASS — `pragma solidity 0.8.30` |
| 9 | Returnbomb / EIP-150 | PASS — no `catch (bytes memory)` |
| 10 | Trusted caller, untrusted params | ACCEPTED — `spoke` is signed calldata (Merkle-committed, exposed by `inspect()`), same trust shape as every shipped Aave V4 hook; strict deltas force a fake spoke to take exactly `amount` |

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

### [P2-1] BORROW / RELEASE are fail-open prev-pipe consumers (carry-over of the Morpho standalone review P2-1) — ACCEPTED
- **File:** `src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol:105` (`_resolveExactPrimary`), `:160` (`_resolveReleaseAmount`)
- **SWC:** N/A
- **Category:** Logic
- **Description:** With `usePrevHookAmount` the signed calldata word is ignored entirely and the predecessor's transient output sizes a
  provider-minted leg (BORROW) or the account's own collateral withdrawal (RELEASE). A poisoned predecessor output therefore sizes a
  leg that settles clean (the delta equals the poisoned expectation). The prerequisite — a third party writing `setOutAmount` mid-batch
  through a callback-bearing token — is absent in Superform chains, and the executor hard-codes `EXECTYPE_DEFAULT`; BORROW is
  additionally bounded by Aave's own health check. Same acceptance as the Morpho twins; no new severity.
- **Exploit Scenario:** A callback-bearing token in the chain lets an attacker overwrite the predecessor's `outAmount` before BORROW
  reads it; BORROW then draws more debt than the signer intended (still within the account's LTV).
- **Real-World Precedent:** None recorded for output piping (Instadapp `setId/getId`, DeFi Saver `$return`); ERC-7579 executor failures
  are context confusion (Safe7579 audit H2), which the `msg.sender == account` gate covers.
- **Vulnerable Code:** `resolved = usePrevHookAmount ? _resolvePrevHookOutput(prevHook, account, expectedToken) : amountWord;`
- **Secure Pattern (optional, pre-deployment):** treat the signed word as a cap on the piped value — `if (usePrevHookAmount &&
  amountWord != 0 && resolved > amountWord) revert AMOUNT_NOT_VALID();` — the hooks are not deployed yet so there is no back-compat
  cost. Not applied: keeps parity with the Morpho and OPEN / REPAY / CLOSE semantics; bundler policy (no callback-bearing tokens
  feeding a BORROW / RELEASE usePrev slot) stands.
- **Reference:** vulnerabilities.md Section 17 (transient state), Morpho standalone report 2026-09-16 P2-1.

### [P2-2] LOAN hooks could pay out or flip an idle, ledger-tracked position (mode mixing) — FIXED
- **File:** `src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol:136` (`_requireNoIdlePosition`), `:171` (RELEASE flag check);
  `AaveV4SupplyHookV2.sol:76,117`
- **SWC:** N/A
- **Category:** Vault / accounting integrity
- **Description:** Aave keeps one share balance per (account, reserve). The idle MONEY_MARKET hooks (PR #1018) post INFLOW / OUTFLOW
  to SuperLedger and refuse collateral-flagged reserves (`RESERVE_IS_COLLATERAL`), but nothing refused the reverse: RELEASE would
  withdraw an un-flagged position with no ledger outflow (the Spoke does not even run a health check on un-flagged withdrawals), and
  PLEDGE would flip an idle position into LOAN mode. Live probe 3 confirmed it: a direct idle-style `supply(0.5 WETH)` followed by
  PLEDGE(1 WETH) produced one 1.4999… WETH flagged position that RELEASE(max) paid out in full. The spec had left this to an
  off-chain "one mode per (account, reserve)" rule.
- **Exploit Scenario:** Not attacker-reachable (self-call only); an OMS routing error would silently move ledger-tracked assets out
  with cost basis and PPS left stale on the ledger.
- **Fix applied:** `getUserReserveStatus` is read before any Spoke call on both paths. PLEDGE reverts `RESERVE_HAS_IDLE_POSITION`
  when the reserve is un-flagged and carries a position (fresh or already-flagged reserves pass); RELEASE reverts
  `RESERVE_NOT_COLLATERAL` when the reserve is not flagged (after the empty-position check, so the existing `AMOUNT_NOT_VALID`
  semantics are unchanged). Together with the idle pair this makes the partition on-chain: flag false = idle MONEY_MARKET, flag true =
  LOAN. Evidence: unit `test_Pledge_Build_RevertIf_IdlePositionOnReserve`, `test_Pledge_Build_FreshOrFlaggedReserve_Passes`,
  `test_Release_Build_RevertIf_NotCollateral`; fork `test_AaveV4V2_Standalone_UnflaggedPosition_RefusedByPledgeAndRelease` (direct
  un-flagged supply, then PLEDGE / RELEASE(max) / RELEASE(exact) all refused, position and flag untouched). Trade-off: an account that
  manually ran `setUsingAsCollateral(false)` must re-enable before a standalone RELEASE (the idle redeem hook covers that state).
- **Reference:** vulnerabilities.md Section 22 (share accounting), idle-hooks report 2026-09-28 P2-1.

### [P2-3] Risk-increasing actions refresh the account's dynamic-config keys for ALL flagged reserves; `getUserAccountData` does not — DOCUMENTED (off-chain)
- **File:** upstream `Spoke.sol` `_processUserAccountData(user, refreshConfig)`; hooks unaffected
- **SWC:** N/A
- **Category:** DoS / liveness
- **Description:** `borrow` and a flagged `withdraw` re-key every flagged reserve's collateral factor to the latest governance value
  before the health check, while the `getUserAccountData` view uses the account's stale keys. After an ARFC risk-parameter cut, a
  BORROW or RELEASE that the view says is comfortable reverts `HealthFactorBelowThreshold()`; the refresh is also sticky on success.
  Whole-userOp revert, no fund risk; the OMS sizer and bundler dry-run are wrong exactly when it matters.
- **Mitigation:** OMS sizes with `getDynamicReserveConfig(id, getReserve(id).dynamicConfigKey)` for every flagged reserve, or
  `eth_call`s the real `borrow` / `withdraw` from the account. Recorded in the spec §6; no hook change.
- **Reference:** aave.com/docs/aave-v4/positions/withdraw ("risk-increasing action … will update the Dynamic Config").

## P3 Findings (Low - Consider Fixing)

### [P3-1] Fork test claimed a Spoke health-check revert but was failing inside the hook — FIXED (correctness reviewer)
- **File:** `test/integration/AaveV4V2HooksFork.t.sol` (`test_AaveV4V2_Release_Undercollateralized_SpokeHealthCheckReverts`)
- **Description:** The test released `SUPPLY_AMOUNT` after the composite open; the supply credit rounds down 1 wei, so the hook
  reverted `AMOUNT_NOT_VALID` before any Spoke call and the untyped any-failure helper accepted it. The helper also only looked for
  `UserOperationRevertReason`, which EntryPoint v0.7 omits on empty revert data (probe 9c).
- **Fix applied:** amount 0.9 ether and a typed check on the Spoke's `HealthFactorBelowThreshold()` (0x851aedc1) for all three
  health-check tests; the any-failure helper is deleted.

### [P3-2] An exact RELEASE word equal to the pledged amount is unsatisfiable in the same block — DOCUMENTED + PINNED (fork probe 1a')
- **File:** `src/hooks/loan/aave-v4/AaveV4WithdrawHookV2.sol` NatSpec; `BaseAaveV4StandaloneLoanHookV2.sol:181`
- **Description:** PLEDGE(1e18) credits 1e18 − 1 (Hub `toAddedSharesDown`), so "release exactly what I pledged" is above the
  position until accrual adds ≥ 1 wei (passes after ~30 days). Fail-closed, consistent with "exact, never a cap"; a sizer that mirrors
  the pledge word into the release word produces a reverting op.
- **Fix applied:** NatSpec on the release hook (size from `getUserSuppliedAssets` or use the sentinel) and
  `test_AaveV4V2_Release_ExactAboveSupplied_Reverts` now asserts the 1-wei round-down and the refusal of the exact pledged word;
  `test_AaveV4V2_Release_ExactEqualsSupplied_PaysAll` pins that exact == supplied pays everything. OMS: clamp the release word to
  `getUserSuppliedAssets` at build time.

### [P3-3] PLEDGE publishes `outAmount = 0` (terminal), not the collateral amount — ACCEPTED deviation from the ticket wording
- **File:** `src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol:190` (`_settleSupplyCollateral`)
- **Description:** The ticket text reads as if PLEDGE publishes the pledged amount. A pledge consumes the collateral and produces
  nothing; publishing the spend would let a downstream `usePrevHookAmount` consumer mistake it for produced tokens. Zero (with
  `outToken = collateralToken` for classification) makes such chaining fail closed (`AMOUNT_NOT_VALID`, probe 9a) and mirrors
  `_settleRepay` and the Morpho supply twin. Documented in the spec §3.5.

### [P3-4] Off-chain pre-flight items surfaced by the EVM research and the fork probe — DOCUMENTED (no hook change)
- Position-manager invariant: the Hub pays `msg.sender`; these selectors must never be routed through an Aave position manager
  (`setUserPositionManager*`) — receiver would diverge from `onBehalfOf` (the strict deltas would fail closed).
- `DrawCapExceeded` / `AddCapExceeded` are per-Spoke caps on top of Hub liquidity; a frozen reserve allows RELEASE but not PLEDGE /
  BORROW (probe 5: `ReserveFrozen()` 0x6d305815, `ReservePaused()` 0xd37f5f1c bubble through the hook); `MAX_USER_RESERVES_LIMIT`
  is a per-Spoke immutable (65535 on Ethereum Core = disabled); a `collateralFactor == 0` reserve (Base MAG7 USDC) can be flagged
  but backs no borrow.
- PLEDGE settles on the wallet spend only; on a freshly listed, nearly empty reserve a donated share price would make the credit
  round-down material (dTRINITY-class), so the OMS routes PLEDGE only to reserves with meaningful `getReserveSuppliedAssets`.
- Liquidation between signing and execution: the flag is never cleared by `LiquidationLogic`; RELEASE(exact) above the shrunken
  position fails closed, RELEASE(max) pays the remainder exactly (probes 1b / 1c). Gas-griefing only.
- Recorded in the spec §6 and §9.

### [P3-5] NatSpec gaps — FIXED (best-practices reviewer)
- "No Spoke constructor arg" and the ISuperHookLoans getter-offset note on the standalone base; per-parameter docs on the new
  helpers.

### [P3-6] Test hygiene — FIXED (simplicity + correctness reviewers)
- Typed `vm.expectRevert` in the sizing suite (`INVALID_AMOUNTS_LENGTH`, `RESERVED_FIELD_NOT_ZERO`); two sizing tests duplicating unit
  coverage removed; `assertGe(+2)` wallet checks replaced by `assertApproxEqAbs(…, 2)`; the `console2` flag observation replaced by
  an assertion (flag stays true after a full release); a tautological assertion deleted; unit
  `test_Release_Build_UsePrev_EqualsSupplied_Passes` added; the spec's stale totals line removed.

## Adversarial fork probe (live Ethereum, block 24_884_274) — condensed
| Probe | Result |
|---|---|
| Third party reduces a zero-debt pledge | impossible: `liquidationCall` → `ReserveNotBorrowed()`, onBehalfOf writes → `Unauthorized()` |
| Full liquidation (365 d warp + oracle mock, `MustNotLeaveDust` forces full cover) | RELEASE(signed exact) → `AMOUNT_NOT_VALID`; RELEASE(exact = remainder) pays exactly; empty → `AMOUNT_NOT_VALID` |
| Partial liquidation, oracle-low price live | RELEASE(1 wei) / BORROW(1 wei) → `HealthFactorBelowThreshold`; PLEDGE while HF < 1 succeeds (adding collateral) |
| RELEASE usePrev with predecessor output == supplied / supplied + 1 | exact receipt / `AMOUNT_NOT_VALID` with full rollback incl. the predecessor's allowance |
| Un-flagged idle supply + PLEDGE + RELEASE(max) | mode mixing reproduced → closed by P2-2 (now refused on both sides) |
| BORROW with an unrelated un-flagged `supplyReserveId` | succeeds: the id is identity-only, as documented |
| Freeze / pause via AccessManager role 301 (mocked `canCall`) | PLEDGE / BORROW → `ReserveFrozen`; RELEASE works frozen, blocked paused; exits after unpause |
| HF boundary bisection (max borrow 1_933_415_085 USDC-wei; max withdraw 15_283_045 wei) | +1 wei on either → `HealthFactorBelowThreshold`; exact boundary lands HF 1.000000000000000000 |
| Same PLEDGE hook twice in one userOp; PLEDGE → PLEDGE(usePrev); PLEDGE → RELEASE(usePrev) | one collateral event, allowance 0; usePrev from a terminal hook → `AMOUNT_NOT_VALID`, atomic |
| V2 PLEDGE then legacy V1 withdraw above position | V1 silently full-withdraws (the behaviour V2 refuses); V2 then reverts on the empty position |
| PLEDGE the whole wallet, then PLEDGE(1 wei) on an empty wallet | second reverts with empty data (WETH9 `require`), no `UserOperationRevertReason` — harness note folded into P3-1 |
| OMS `replaceCalldataAmounts(data, [max])` on a usePrev payload | valid payload; prev governs when chained, sentinel live only with usePrev = false |
| RELEASE(WETH) → BORROW(usePrev) | `PREV_TOKEN_MISMATCH`, atomic |

## Attack Surface Summary
- **External Entry Points:** `build` (view; strict decode + reserve bind + amount resolution + mode guard), `preExecute` /
  `postExecute` (account-only), `decodeAmounts` / `replaceCalldataAmounts` / `decodeUsePrevHookAmount` / `amountRoles` / `inspect`
  (pure sizing surface, strict on the same layout as `build`).
- **Value Transfer Points:** PLEDGE `approve(spoke, 0) → approve(spoke, amount) → supply(id, amount, account) →
  setUsingAsCollateral(id, true, account) → approve(spoke, 0)`; BORROW `borrow(id, amount, account)`; RELEASE
  `withdraw(id, amount | max, account)`. Receiver is always the account (Hub pays `msg.sender`).
- **Oracle Dependencies:** none in the hooks; health arbitration is the Spoke's (Aave oracle + dynamic config, P2-3).
- **Cross-Contract Interactions:** Spoke (`getReserve`, `getUserSuppliedAssets`, `getUserReserveStatus`, the four money functions),
  ERC-20 approve / balanceOf. `spoke` is signed calldata (accepted trust shape).
- **Upgrade Mechanisms:** none in the hooks (immutable, no admin); Hub / Spoke are governance-upgradeable — a fee or short transfer
  fails loudly via `DELTA_MISMATCH`.
- **Bytecode isolation:** the standalone helpers live in a separate abstract; `AaveV4LoanBytecodeUnchanged.t.sol` proves the nine
  deployed LOAN artifacts unchanged.

## Coding Standards Findings
- Locked pragma, explicit visibility, custom errors, NatSpec on every public / external / internal helper (P3-5 fixed), imports grouped
  external / Superform, CEI not applicable (hooks hold no state beyond BaseHook transients). Hooks emit no events by base convention
  (executor events carry the trace). `forge fmt --check` clean on all changed files.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 5, 6, 7, 10, 13, 15, 17, 22, 28, 36, 50, 51; appendices J, K, L, M.
- **evmresearch.io patterns checked:** lending-position mode mixing, share-price inflation on sparse markets, approval hygiene,
  intent-pipeline sizing, ERC-7579 executor context.
- **Coding rules validated:** coding-rules.md full pass on the four files.
- **Historical exploits cross-referenced:** Sturdy 2023 (collateral toggle path), Morpho App Apr 2025 and SwapNet / Aperture Jan 2026
  (approval intermediaries), dTRINITY dLEND Mar 2026 (index inflation), KelpDAO / rsETH Apr 2026 (reserve stress), Safe7579 audit H2.
- **Upstream sources:** aave/aave-v4 `Spoke.sol`, `Hub.sol`, `AssetLogic.sol`, `LiquidationLogic.sol`, `PositionStatusMap.sol`;
  Aave V4 positions / risk-premium docs; OWASP SC Top 10 (2025); Trail of Bits "six mistakes in ERC-4337 smart accounts" (2026-03).
