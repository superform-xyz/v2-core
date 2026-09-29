# Security Analysis Report — final pass

## Metadata
- **Target:** `src/hooks/loan/aave-v4/BaseAaveV4StandaloneLoanHookV2.sol`, `AaveV4SupplyHookV2.sol` (PLEDGE), `AaveV4BorrowHookV2.sol` (BORROW), `AaveV4WithdrawHookV2.sol` (RELEASE) — SUP-21141, working tree stacked on `16f24312`
- **Mode:** review (inline scan + vulnerability scanner + best-practices + EVM research agents)
- **Date:** 2026-09-29
- **Contract Types Detected:** lending-protocol integration hooks (ERC-7579 executor modules; no vault / AMM / bridge / governance / token surface of their own)
- **Files Analyzed:** 4 targets + inherited `BaseAaveV4LoanHookV2`, `BaseLoanHookV2`, `BaseLoanHook`, `BaseHook`, vendor `IAaveV4Spoke`; upstream `aave/aave-v4` `Spoke.sol` / `Hub.sol` fetched for semantics
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (sections 1–48 + appendices); no `coding-rules.md` exists, fallback ruleset = CLAUDE.md style guide
- **Builds on:** `2026-09-28-aave-v4-v2-standalone-loan-hooks.md` (PASS, 3 P2 / 6 P3). Every fix that report lists was verified present at the cited lines (table below). Accepted / documented items are not re-opened.

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 0 new (prior P2-1 accepted, P2-2 fixed + verified, P2-3 documented; framing corrected below) | No |
| P3 Low | 3 new (1 documented + pinned by test, 1 NatSpec batch fixed, 1 optional hardening left as a decision) | No |

## Verdict
**PASS** — no P0 / P1 / P2 findings. Three new hooks are unchanged in logic since the 2026-09-28 review; only NatSpec moved (bytecode unaffected: `bytecode_hash = "none"`, lock test 4/4 green).

## Inline critical-pattern scan
| # | Pattern | Result |
|---|---|---|
| 1/5 | Reentrancy / guards | PASS — hooks hold no funds; Spoke money functions `nonReentrant`; executor `_processHook` `nonReentrant`; BaseHook pre/post mutexes context-keyed |
| 2 | Access control | PASS — `preExecute` / `postExecute` require `msg.sender == account` (`BaseHook.sol:187,196`, pinned by unit `test_Standalone_AccountParameterIsAuthoritative`); every emitted Spoke call hardcodes `onBehalfOf = account` (`SupplyHookV2:90,97`, `BorrowHookV2:76`, `WithdrawHookV2:84`) |
| 3 | Division before multiplication | PASS — no arithmetic beyond direction-guarded deltas |
| 4/6 | Unchecked returns / low-level calls | PASS — no `.call`, no `try/catch`; Spoke returns ignored in favour of measured deltas |
| 6 | `abi.encodePacked` collisions | PASS — fixed-width fields only (`_inspectAaveV4V2`), exact 241-byte layout |
| 7 | `tx.origin` | PASS |
| 8 | Floating pragma | PASS — `0.8.30` |
| 9 | Returnbomb / EIP-150 | PASS — no `catch (bytes memory)` |
| 10 | Trusted caller, untrusted params | ACCEPTED (unchanged) — `spoke` is Merkle-committed signed calldata exposed by `inspect()` |

## P0 Findings
None found.

## P1 Findings
None found.

## P2 Findings
None found.

**Framing correction to prior P2-3 (dynamic-config refresh):** upstream `Spoke.updateUserDynamicConfig` is gated `onlyPositionManager || _checkCanCall` (ChainSecurity 2026-03-23 §2.2). A random third party therefore cannot re-key an account's collateral factors ahead of a BORROW / RELEASE; only the account, its approved position managers, or an AccessManager-roled caller can. The off-chain pre-flight caveat stands (the hook's own risk-increasing call refreshes all keys), but the threat model is governance timing, not griefing.

## P3 Findings

### [P3-A] "One mode per (account, reserve), on-chain both ways" is overstated — residual flag-flip via sibling hooks / manual call — DOCUMENTED + PINNED
- **File:** `BaseAaveV4StandaloneLoanHookV2.sol` `_resolveReleaseAmount` (sole mode gate is `_isUsingAsCollateral`); bypass emitters `AaveV4SupplyAndBorrowHookV2.sol` (composite OPEN V2), legacy `AaveV4SupplyHook.sol` / `AaveV4SupplyAndBorrowHook.sol` — all bytecode-locked, none carry `_requireNoIdlePosition`
- **SWC:** N/A · **Category:** Logic / accounting integrity (residual of prior P2-2)
- **Description:** P2-2 closed PLEDGE→idle and RELEASE→un-flagged. RELEASE's mode marker is the Spoke flag alone; the flag can be set over an un-flagged idle position by OPEN V2, a V1 supply hook, or a direct `setUsingAsCollateral(true)`. After that RELEASE(max) pays the merged position with no ledger OUTFLOW. All paths are the account's own signed intents (Spoke `onlyPositionManager`), so this is a routing-policy residual, not an attacker path.
- **Exploit Scenario:** OMS routes an OPEN V2 onto a (spoke, reserve) the same account idle-lends; the next RELEASE(max) moves ledger-tracked assets out and the idle accumulator goes stale.
- **Resolution:** caveat added to `AaveV4WithdrawHookV2` NatSpec and spec §4; pinned by fork `test_AaveV4V2_Release_ManualFlagOverIdlePosition_PaysOut_Residual`; §9 follow-up to encode the rule in the manifest / OMS classifier. No change possible in the locked siblings; none needed in the three new hooks.
- **Reference:** vulnerabilities.md §22, §25.1; prior report P2-2.

### [P3-B] NatSpec accuracy — FIXED
- Four places said "before any Spoke call" while the guard itself reads the Spoke (`getReserve`, `getUserReserveStatus`, `getUserSuppliedAssets`); reworded to "before any provider execution is emitted" (base `_requireNoIdlePosition` / `_resolveReleaseAmount`, `SupplyHookV2` header, `WithdrawHookV2` header). Base `@notice` now names the reserve binding, release resolver and mode guards it adds over the Morpho twin. One orphaned line break reflowed. `forge fmt --check` clean; bytecode lock 4/4.

### [P3-C] PLEDGE settles on wallet spend only; the credited position is unverified — OPTIONAL HARDENING (decision for the owner)
- **File:** `BaseAaveV4StandaloneLoanHookV2.sol` `_settleSupplyCollateral`
- **Category:** Logic (rounding / sparse-reserve index)
- **Description:** `Hub.add` mints `toAddedSharesDown`, so the credited `getUserSuppliedAssets` is ≤ spend; on established reserves the loss is ≤ 1 index wei (spec §5 pins 1 wei on WETH). On a fresh or near-empty reserve with a manipulated index the round-down could be material (dTRINITY dLEND, 2026-03-17, ~$257K, six-day-old cbBTC market). Aave V4's Hub has no V3-style flash-premium index path, so the vector does not port directly; the current control is the OMS rule "only route to reserves with meaningful `getReserveSuppliedAssets`" (spec §6).
- **Option (hooks are not yet deployed, so bytecode is still free):** snapshot `getUserSuppliedAssets` in PLEDGE `_preExecute` and require `suppliedAfter - suppliedBefore + 1 >= amount` in `_postExecute` (1-wei tolerance), converting a bad credit into a fail-closed revert. Cost: two extra Spoke staticcalls per pledge. Not required if the OMS rule is enforced. **Not applied** — left as a decision.
- **Reference:** vulnerabilities.md §22 / §28 analogues; evmresearch "low-decimal tokens reduce the minimum cost of inflation attacks".

### Informational (no action)
- **Same-hook-twice `usePrev` self-chain:** the executor calls `setExecutionContext` for the second run before its `build()`, so the pipe reads an empty output slot (`outToken == address(0)`) and rejects it with `PREV_TOKEN_MISMATCH` (traced live; fork `test_AaveV4V2_SelfChain_UsePrev_FailsClosed_StateUnchanged`). Fail-closed; BaseHook-wide. Unit `test_Borrow_AsPrevHook_TokenDenominationEnforced` documents the pipe-level token match when the output is populated.
- **Context-zero aliasing in direct-call tests:** the first execution context in a tx is `0`, which an account that never ran `preExecute` also reads. Test-harness artefact only (the executor assigns contexts); noted in `test_Standalone_AccountParameterIsAuthoritative`.
- **RELEASE(max) receipt vs pre-read:** identical by construction — `Spoke.withdraw` clamps to `hub.previewRemoveByShares(...)`, which is exactly `getUserSuppliedAssets`; `Hub.remove` transfers exactly that amount and reverts (never clamps) on `InsufficientLiquidity`. Fork asserts strict equality.
- **Dust shares after RELEASE(max):** `toAddedSharesUp(toAddedAssetsDown(shares)) ≤ shares` may leave a wei-scale share remainder with `getUserSuppliedAssets == 0`; next RELEASE → `AMOUNT_NOT_VALID`, PLEDGE passes. No hook impact.
- **Flag never cleared by `withdraw` / `liquidationCall`** (source-confirmed); `setUsingAsCollateral(true)` early-returns when already set, skipping frozen/paused validation on the flag leg — `supply` still reverts frozen/paused, so no gap.
- **TOB-AAVE-7 (resolved upstream):** HF validated before premium refresh (≤ 2 wei). Post-fix safe; OMS should still not size BORROW / RELEASE to the exact `HealthFactorBelowThreshold` boundary (fork bisection lands HF = 1.0 exactly; next accrual makes the account liquidatable).
- **TOB-AAVE-1 (risk accepted upstream):** 1-wei flagged collateral legs block Aave deficit reporting. A Superform account is not the attacker profile; `DUST_LIQUIDATION_THRESHOLD` closes small positions fully.
- **Position managers:** the only third-party path to an account's position is a manager the account itself approved (`setUserPositionManagersWithSig`, ERC-1271 for smart accounts). Hub pays `msg.sender`, so a manager-routed flow fails `DELTA_MISMATCH`. Precedent: sAVAX rebalancer delegation abuse, 2026-04-19. Recommendation unchanged: Superform accounts never sign manager grants.

## Verified prior fixes (2026-09-28 report)
| Fix | Location | Present |
|---|---|---|
| P2-1 fail-open prev pipe — accepted, no cap | `BaseAaveV4StandaloneLoanHookV2.sol` `_resolveExactPrimary` | yes (as accepted) |
| P2-2 PLEDGE `RESERVE_HAS_IDLE_POSITION` on build + preExecute | base `_requireNoIdlePosition`; `AaveV4SupplyHookV2.sol` `_buildHookExecutions` / `_preExecute` | yes |
| P2-2 RELEASE `RESERVE_NOT_COLLATERAL` after the empty-position check | base `_resolveReleaseAmount` | yes |
| P2-3 / P3-4 off-chain pre-flight documented | spec §6 | yes |
| P3-1 typed `HealthFactorBelowThreshold` (0x851aedc1), any-failure helper removed | fork suite | yes |
| P3-2 over-position exact / PREV rejected; 1-wei sizing note | base; `AaveV4WithdrawHookV2` NatSpec; fork `_ExactAboveSupplied_Reverts` | yes |
| P3-3 PLEDGE `outAmount = 0`, `outToken = collateral` | base `_settleSupplyCollateral` | yes |
| P3-5 / P3-6 NatSpec + test hygiene | base, sizing, fork, unit | yes |

## Test coverage added in this pass (all green)
| Suite | Before | After |
|---|---|---|
| unit `AaveV4StandaloneLoanHooksV2.t.sol` | 45 | 79 (+8 fuzz) |
| sizing `LoanHooksV2SizingIntegration.t.sol` | 28 | 30 |
| fork `AaveV4V2HooksFork.t.sol` | 32 | 58 |
| bytecode lock | 4 | 4 |

New coverage: validation order (reserve binding → empty position → flag → prev pipe), preExecute/build parity, per-account authentication, over-delivery and wrong-direction settles, other-token noise ignored, usePrev settle expectations, real-hook chaining (PLEDGE terminal fail-closed, BORROW → REPAY(usePrev) under the real executor, RELEASE → PLEDGE(usePrev) round trip), all four (flag, supplied) cells incl. re-pledge after full release and the manual flag-off trade-off, sizing views strict-but-amount-agnostic with byte-exact replace (fuzz), non-canonical bool fuzz, RELEASE on the real Spoke with zero / un-flagged / flagged position, Aave `amountRoles` pinned in sizing, insufficient-wallet pledge atomic (asserted via `UserOperationEvent.success == false`), P3-A residual pinned. Governance states (`ReserveFrozen` / `ReservePaused` / non-borrowable) are now covered on the live Spoke through a mocked AccessManager `canCall` (`_setReserveFlags`): frozen refuses PLEDGE / BORROW and lets RELEASE exit, paused refuses everything, a frozen second leg rolls the whole userOp back. Not covered: `AddCapExceeded` / `DrawCapExceeded` (Hub-side caps).

## Attack Surface Summary
- **External entry points:** `build` (view), `preExecute` / `postExecute` (account-only), pure sizing views `decodeAmounts` / `replaceCalldataAmounts` / `decodeUsePrevHookAmount` / `amountRoles` / `inspect`.
- **Value transfer points:** none in the hooks; the account's `approve(spoke, amount)` → `Spoke.supply` pull (reset to 0 in-tx); `Hub.remove` / `Hub.draw` pay `msg.sender` = account.
- **Oracle dependencies:** none in the hooks; Aave's oracle governs HF inside the Spoke only.
- **Cross-contract interactions:** signed `spoke` (`getReserve`, `getUserReserveStatus`, `getUserSuppliedAssets`, `supply`, `setUsingAsCollateral`, `borrow`, `withdraw`), signed ERC-20s, previous hook's `getOutAmount` / `getOutToken`.
- **Upgrade mechanisms:** none in the hooks (immutable, no constructor args); Hub / Spoke are governance-upgradeable (static-system assumption, fails loudly via `DELTA_MISMATCH`).

## Coding Standards Findings
Three P3 NatSpec items (P3-B), all fixed. Custom errors, explicit visibility, import grouping, naming and event policy (none, matching every loan-hook sibling) all conform. Full parity table with the Morpho standalone trio: every divergence (Spoke from calldata, reserve binding instead of header key, pre-read over-withdraw guard, sentinel pass-through, mode guards, 5-execution pledge) is a deliberate Aave V4 semantic already documented in NatSpec.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 8, 9, 10, 13, 15, 22, 25, 28, 36, 50, 51
- **evmresearch.io patterns checked:** EIP-1153 transient persistence (cross-frame, ERC-4337 bundles), max-uint sentinel semantics, router arbitrary-call / approval residue, transfer-amount fidelity, pausable collateral, ERC-777/1363 callbacks, ERC-7579 module risks, low-decimal inflation cost
- **Upstream sources:** `aave/aave-v4` `Spoke.sol` / `Hub.sol`; Trail of Bits 2025-11-06 (TOB-AAVE-1, -7); ChainSecurity 2026-01-28 / 2026-03-23; Aave docs (positions/withdraw, positions/managers)
- **Historical exploits cross-referenced:** SIR.trading (EIP-1153, 2025-03), Aave ParaSwap Repay Adapter (2024-08), SwapNet/Aperture (2026-01), dTRINITY dLEND (2026-03), sAVAX rebalancer delegation (2026-04)
- **OWASP SC Top 10 2025:** SC01/04/05/06/08 covered by design; SC02/09 N/A; SC03 residual = P3-A / P3-C; SC07 only via P3-C; SC10 whole-userOp revert on freeze/pause/caps/HF
