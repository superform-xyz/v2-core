# Security Analysis Report

## Metadata
- **Target:** SUP-21142 — Aave V4 idle MONEY_MARKET lend/redeem hooks (uncommitted, branch
  `cosmin-sup-21142-feature-add-aave-v4-idle-money_market-lendredeem-hooks`): `src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol` (new),
  `AaveV4LendHook.sol` (new), `AaveV4RedeemHook.sol` (new); in-review edit to `src/vendor/aave-v4/IAaveV4Spoke.sol` (one view added).
  Context read: `BaseHook`, `BaseLoanHook`, `BaseLoanHookV2`, `SuperExecutorBase`, `BaseLedger`, `AaveV4SupplyYieldSourceOracle`,
  `AaveV4ReserveRegistry`, the Morpho money-market twins, the upstream `aave/aave-v4` Spoke/Hub/AssetLogic/LiquidationLogic sources and
  the verified Ethereum Spoke implementation.
- **Mode:** review (inline critical-pattern scan + vulnerability scanner + best-practices + EVM security research agents)
- **Date:** 2026-09-28
- **Contract Types Detected:** general — lending-protocol integration hooks (stateless, ERC-7579 executor context); identity-PPS
  accounting through SuperLedger + registry-resolved yield-source oracle
- **Files Analyzed:** 3 new source files (+1 interface edit); tests as evidence: `test/unit/hooks/loan/AaveV4MoneyMarketHooks.t.sol`,
  `AaveV4LoanBytecodeUnchanged.t.sol`, `test/unit/hooks/HookSizingInterface.t.sol`, `test/integration/AaveV4IdleHooksFork.t.sol`,
  `AaveV4IdleHooksBaseFork.t.sol`
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (sections 1-48 + appendices A-M) + `coding-rules.md`;
  external: aave-v4 sources/docs, evmresearch.io, OWASP SC Top 10 (2025), 2025-2026 incident write-ups

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 2 (1 fixed in review, 1 accepted liveness trade-off) · 1 code-quality (fixed) | No |
| P3 Low | 6 (2 fixed in review, 4 documented/accepted) | No |

## Verdict
**PASS** — No P0 or P1 findings. The primary controls hold: the header reserve key is recomputed from the body and pinned in the
pure decoder (build, preExecute and inspect all fail closed); the Spoke is the only call target and approve spender; `onBehalfOf` is
always the account; a third party cannot touch the account's position (live probe: outsider `supply`/`withdraw` onBehalfOf reverts
`Unauthorized()` 0x82b42900, self-call succeeds); the executor/ledger/oracle chain fails closed for unregistered reserve keys
(fork-verified with GHO reserve 13). Exact-delta settlement was proven against the upstream Spoke/Hub math: full withdrawal pays
exactly the pre-read `getUserSuppliedAssets` (same virtual index in the same block), partial withdrawal pays exactly `amount`.

## Inline critical-pattern scan
| # | Pattern | Result |
|---|---|---|
| 1/5 | Reentrancy / missing guards | PASS — hooks hold no funds; Spoke `supply`/`withdraw` are `nonReentrant` with no user callbacks; BaseHook pre/post mutexes; executor `_processHook` is `nonReentrant` |
| 2 | Access control | PASS — `preExecute`/`postExecute` require `msg.sender == account`; `hookType` storage has no setter; Spoke `onlyPositionManager` self-call rule |
| 3 | Division before multiplication | PASS — no arithmetic beyond deltas; Aave's rounding is read, never recomputed |
| 4 | Unchecked return values | PASS — no low-level calls; provider calls are account executions decoded by the executor |
| 6 | `abi.encodePacked` collisions | PASS — `inspect` packs four fixed-size fields (3 × address + uint256) |
| 7 | `tx.origin` | PASS — absent |
| 8 | Floating pragma | PASS — `0.8.30` pinned |
| 9 | Returnbomb / EIP-150 | N/A — no `try/catch`; every external return is fixed-size |
| 10 | Trusted caller, untrusted params | PASS in the trust model — the Spoke address is calldata, but calldata is strategy-signed and Merkle-committed and `inspect()` binds spoke + reserve + underlying + key; the same trust shape as every Aave V4 hook |

## P2 Findings (Medium)

### [P2-1] Same reserve as LOAN collateral and as "idle" for one account mixes modes — FIXED IN REVIEW
- **File:** `src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol` (`_requireNotCollateral`), both leaves (build + `_preExecute`)
- **SWC:** N/A · **Category:** Logic / accounting integrity
- **Description:** The Spoke's collateral flag is per (user, reserve), not per deposit (`Spoke.withdraw` runs the health-factor check
  only `if isUsingAsCollateral(reserveId)`; `LiquidationLogic` requires the flag to seize). If the account had already enabled the
  reserve as collateral (via `AaveV4SupplyHook`, a position manager, or a direct call), an "idle" lend would supply seizable collateral,
  the redeem could revert `HealthFactorBelowThreshold`, and `getUserSuppliedAssets` — the oracle's balance — would mix NONACCOUNTING LOAN
  supply with ledger-tracked idle supply. User-caused, not attacker-caused; the spec had acknowledged the HF revert but not the mixing.
- **Fix applied:** `getUserReserveStatus(reserveId, user)` added to the vendored `IAaveV4Spoke` (verified live: `(false,false)` idle,
  `(true,false)` pledged, `(false,true)` debt); both hooks call `_requireNotCollateral` after the underlying check on build and
  preExecute and revert `RESERVE_IS_COLLATERAL` (one staticcall). "One mode per (account, reserve)" is now on-chain. Pinned by unit
  `test_RevertIf_ReserveIsCollateral` (flag is per user: another account still builds) and fork
  `test_CollateralFlaggedReserve_IsRefusedByBothHooks` (self-call flags the reserve after a lend → both hooks refuse, ledger untouched;
  clearing the flag restores idle redeem). LOAN bytecode remains unchanged (`AaveV4LoanBytecodeUnchanged.t.sol` still passes after the
  interface edit — an unused interface member does not reach bytecode).
- **Reference:** vulnerabilities.md 14 (logic), 22 (accounting); aave-v4 `Spoke.sol`, `LiquidationLogic.sol`

### [P2-2] Redeem reverts entirely under Hub liquidity shortfall — ACCEPTED (liveness only)
- **File:** `src/hooks/loan/aave-v4/AaveV4RedeemHook.sol` (`_preExecute`: `expectedPrimaryAmount = min(amount, suppliedBefore)`)
- **SWC:** N/A · **Category:** DoS
- **Description:** `Hub.remove` requires `amount <= liquidity` with no partial fill. A redeem above available liquidity (including
  `max` during high utilisation — precedent: the April 2026 rsETH-driven Aave WETH bank run) reverts the whole userOp. There is no
  "withdraw what is available" mode and adding one would break the exact-delta design. No loss path; funds stay on Aave.
- **Mitigation:** keep the strict check. Bundler/OMS sizing must read Hub liquidity for the asset before choosing `amount`; `max` is
  not safe under stress; alert on utilisation for registered reserves. Documented in the spec.
- **Reference:** vulnerabilities.md 7 (DoS); aave-v4 `Hub.sol`

## P3 Findings (Low)

### [P3-1] Fee-on-transfer rejection is asymmetric between lend and redeem — DOCUMENTED (policy)
- **File:** `AaveV4LendHook.sol` `_postExecute` (spend check), `AaveV4RedeemHook.sol` `_postExecute` (receipt check)
- **Category:** Token
- **Description:** On the lend leg the account's wallet decreases by exactly `amount` even for a recipient-side fee, so the spend check
  passes (the Hub's own `InsufficientTransferred` assertion is what actually rejects FoT on supply); on the redeem leg the wallet
  receives `withdrawnAmount − fee`, so `DELTA_MISMATCH` would revert every redeem. If USDT ever activated its fee switch after
  Superform-accounted USDT idle positions existed, those positions could only be exited by a direct Spoke self-call (bypassing the ledger).
  Not attacker-driven; Aave governance does not list FoT tokens and the registry is a permissioned allowlist.
- **Mitigation:** registry runbook rule — never register a fee-on-transfer reserve; spec wording corrected ("the Hub rejects FoT on
  supply; the hook's strict receipt check rejects it on redeem").
- **Reference:** vulnerabilities.md 10.1, 46.1

### [P3-2] Identity PPS makes `feePercent` structurally inert — DOCUMENTED (design intent, stronger than "operational invariant")
- **File:** `AaveV4RedeemHook.sol` `_preExecute`/`_postExecute` with `BaseLedger._processOutflow`
- **Category:** Logic (informational)
- **Description:** With `pps = 10^d` and `cost == shares` at every snapshot, outflow profit is 0 (or 1 wei that floors to a 0 fee); a full
  redeem after accrual reports `usedShares > accumulator`, is capped, and `amountAssets` is re-priced to the accumulator, so profit is
  exactly 0 (fork `test_Lend_Then_Warp_RedeemFull_YieldNotTaxed`). A non-zero `feePercent` would therefore charge nothing — no fee-leak
  risk on misconfiguration, and no `FEE_NOT_SET` DoS is reachable. Conversely the ledger can never observe accrued yield for these keys;
  enabling performance fees needs a shares-PPS oracle version, not a config change.
- **Reference:** vulnerabilities.md 22.3, 25.1; specs/aave-v4-oracles/technical-spec.md

### [P3-3] Lend credit round-down is wei-scale, bounded by the Hub index, not strictly "1 wei" — DOCUMENTED
- **File:** `AaveV4LendHook.sol` `_postExecute` (`credited = position delta`)
- **Category:** Arithmetic
- **Description:** `credited = preview(s+Δs) − preview(s)` with `Δs = toAddedSharesDown(amount)`; two floors and an index > 1 bound the
  shortfall by roughly the index in wei, i.e. 1 wei today and a few wei as the index grows. The hook never equates the credit with the
  spend and reverts only on a zero credit, so this is a wording issue, not a check issue. Both fork suites assert `≤ 1` at their pinned
  blocks, which is exact for those blocks. Spec wording corrected.
- **Reference:** vulnerabilities.md 3.3; aave-v4 `AssetLogic.sol`

### [P3-4] Plain (non-context-keyed) transient slots in `BaseLoanHookV2` — ACCEPTED (documented base trade-off)
- **File:** `BaseLoanHookV2.sol` (`preLoanTokenBalance`, `expectedPrimaryAmount`), `BaseHook.sol` (`usedShares`, `asset`)
- **Category:** Other (EIP-1153)
- **Description:** Poisoning between the account's preExecute and postExecute requires a second account's preExecute on the same hook
  contract mid-transaction, i.e. a token or Spoke callback (none for USDC/USDT; Spoke and Hub are `nonReentrant`). UserOps are sequential
  and the executor opens a fresh context per hook, so lend→redeem→lend in one userOp cannot interleave (fork
  `test_Chain_Lend_Then_Redeem_UsePrev`). Same shape as every V2 loan hook; recorded in SECURITY.md.
- **Reference:** vulnerabilities.md 23.7

### [P3-5] Codeless reserve key as lend `outToken` — ACCEPTED (mirrors MorphoLendHook)
- **File:** `AaveV4LendHook.sol` `_postExecute` (`_setOutToken(vars.reserveKey)`)
- **Category:** Logic
- **Description:** Downstream hooks that verify the previous output token fail closed (`PREV_TOKEN_MISMATCH`); a downstream hook that used
  `outToken` in a low-level call without an `extcodesize` check would treat the codeless address as success — none exist in the V2 loan
  family. Redeem with `usePrevHookAmount` requires the reserve key (i.e. a lend) as the previous output. Documented: "chain only into
  AaveV4RedeemHook".
- **Reference:** vulnerabilities.md 8, 22

### [P3-6] Reserve pause/freeze, add-cap and upgradeable Hub/Spoke between signing and execution — ACCEPTED (static-system assumption)
- **File:** both leaves (provider calls)
- **Category:** DoS / external trust
- **Description:** Lend reverts on pause/freeze/cap; redeem reverts on pause only (a frozen reserve still allows exit). Whole userOp
  reverts, no partial state. Hub/Spoke are upgradeable (governance); an upgrade adding a withdraw fee would break the exact-delta check
  loudly (revert), never silently. Falls under SECURITY.md "hook safety depends on external contract trustworthiness".
- **Mitigation:** bundler pre-simulation; expose `getReserve().flags` to the OMS; monitor implementation-slot changes on registered spokes.
- **Reference:** vulnerabilities.md 11, 27; CLAUDE.md known trade-offs

## Coding Standards Findings (best-practices agent) — all fixed in review
- **[P2-Q1, fixed]** `forge fmt` had re-flowed the layout NatSpec so the `@notice` for `yieldSource` was swallowed mid-line (base) and
  orphan continuation lines appeared (both leaves). Rewritten with ≤120-column lines; all files `forge fmt --check` clean.
- **[P3, fixed]** `ISuperHookLoans` getter semantics on this layout (offset 72 is the SPOKE; `getCollateralTokenBalance` reverts) were
  undocumented — documented as a LIMITATION in the base NatSpec, per the `EulerRepayHook` precedent, and pinned by
  `test_LoansGetters_LimitationPinned`.
- **[P3, fixed]** `@param`/`@return` added to `_decodeIdle` and `_resolveIdleAmount` (the asymmetric `expectedPrevToken` is the field
  that needed it).
- **[P3, fixed]** Constant prefixes unified (`IDLE_*` for all six offsets/length; `SPOKE_OFFSET` also exists with a different value in the
  LOAN V2 base).
- **[P3, optional, unchanged]** `_postExecute` re-runs the full strict decode (~1k gas) — kept deliberately for the fail-closed re-pin,
  consistent with `MorphoLendHook`. Build/pre duplication is inherent to the executor calling `build` and `preExecute` separately.
- Compliant: custom errors only, pinned pragma, explicit visibility, import order and section banners byte-for-byte the sibling layout,
  correct `@inheritdoc` chain, no events (hooks report via transient outputs; the executor emits), solhint clean.

## Attack Surface Summary
- **External Entry Points:** `build` (view), `preExecute`/`postExecute` (account-gated by BaseHook), `inspect`, sizing views
  (`decodeAmounts`, `amountRoles`, `replaceCalldataAmounts`, `decodeUsePrevHookAmount`) — all pure/view except the transient-writing
  pre/post.
- **Value Transfer Points:** none inside the hooks. The account executes `approve`/`supply`/`withdraw`; the Hub pulls/pays exactly
  `amount`; approvals are reset before and after.
- **Oracle Dependencies:** none for pricing. Position read `getUserSuppliedAssets` (Hub virtual index, same block as the Spoke's own
  `min()`), collateral flag `getUserReserveStatus`, reserve binding `getReserve(id).underlying`. Accounting resolves the reserve key via
  `AaveV4SupplyYieldSourceOracle` → `AaveV4ReserveRegistry` (fail-closed).
- **Cross-Contract Interactions:** Spoke (proxy, governance-upgradeable) → Hub; USDC/underlying ERC-20.
- **Upgrade Mechanisms:** none in the hooks (immutable, no admin). Aave Hub/Spoke upgradeability is external trust.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3.3, 7, 8, 9, 10.1, 11, 14, 15, 20, 21, 22.3, 23.7, 25.1, 27, 35, 39, 40, 46.1, 46.4,
  Appendix H (returnbomb), Appendices J/K/L/M (precedent scan)
- **evmresearch.io patterns checked:** transfer-amount fidelity, ERC-4626 donation/inflation, EIP-1153 cross-call leakage, "read the actual
  delta" pattern, rounding-direction composition (Bunni, Balancer V2)
- **Upstream sources verified:** aave-v4 `Spoke.sol`, `Hub.sol`, `AssetLogic.sol`, `LiquidationLogic.sol`; verified Ethereum Spoke
  implementation; Aave position-manager docs; Sherlock/Certora Aave V4 reports
- **Coding rules validated:** 23 rules/checks
- **Historical exploits cross-referenced:** Balancer V2 (Nov 2025), Bunni, Resupply (Jun 2025), zkLend, KelpDAO/rsETH Aave bank run
  (Apr 2026), Aave CAPO (Mar 2026), Safe7579 H2, SIR (EIP-1153)
- **Live probes:** Base MAG7 Spoke — outsider `supply`/`withdraw` onBehalfOf revert `Unauthorized()`; self-call `withdraw(7, 1e6)` pays
  `(999999 shares, 1e6 assets)`; `getUserReserveStatus` ordering pinned on three live positions
