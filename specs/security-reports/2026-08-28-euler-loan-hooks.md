# Security Analysis Report — Euler EVK/EVC Loan Hooks

> **REMEDIATION STATUS (2026-08-28, same day):** All findings fixed except P3-4 (raw `IERC20.approve`,
> accepted — consistent with the Morpho precedent and fail-closed). See "Fixes Applied" at the end
> of this report. 154 Euler tests (91 unit + 48 branch-coverage fork + 15 E2E fork) pass after the
> changes; the full 654-test loan-hook suite passes; locked bytecode of already-deployed hooks
> verified byte-identical.

## Metadata
- **Target:** `src/hooks/loan/euler/` (BaseEulerLoanHook, EulerDepositCollateralAndBorrowHook, EulerRepayHook, EulerRepayAndWithdrawHook) + `src/vendor/euler/` (IEVault, IEVC)
- **Mode:** review (3 parallel agents: vulnerability scanner, best-practices, external EVM security research)
- **Date:** 2026-08-28
- **Contract Types Detected:** lending-protocol integration hooks (Euler EVK vaults + EVC), ERC-7579 execution-builder pattern
- **Files Analyzed:** 6 (plus context: BaseHook, BaseLoanHook, BaseLoanHookV2, Morpho sibling hooks)
- **Vulnerability Database:** superform-specs/guidelines/solidity/vulnerabilities.md (36 sections, 300+ patterns)

## Summary

| Severity | Count | Blocks Merge |
|----------|-------|--------------|
| P0 Critical | 0 | — |
| P1 High | 0 | — |
| P2 Medium | 3 | No |
| P3 Low | 12 | No |

## Verdict

**PASS** — No P0 or P1 findings. Safe to proceed. The three P2 findings are architectural/robustness items that deserve a decision (or a documented trade-off) before merge, but do not gate it.

### Verified-safe highlights (explicitly probed, no finding)

- **Repay `receiver` semantics:** EVK's `repay(amount, receiver)` treats `receiver` as the **debtor** (assets pulled from caller). The hooks hardcode `receiver = account` everywhere; the trap is documented in `IEVault.sol` NatSpec. External research flagged this as the #1 integrator wiring mistake — the hooks get it right.
- **1-wei repay front-run vs. `DELTA_MISMATCH`:** build, `_preExecute` and `_postExecute` all resolve `debtOf` in the same transaction (EVK views virtually accrue by timestamp), so a third-party partial repay front-run shifts all resolutions consistently — no settle-check grief. `min(cap, debt)` absorbs it by design.
- **Approval hygiene:** approve-0 → approve-exact → approve-0 sandwich on every leg; no dangling allowance on any success path; USDT-compatible.
- **Controller disable path:** always routed through `IEVault.disableController()` (the vault self-disables via the EVC); the dangerous EVC-direct `disableController(address)` is deliberately omitted from the vendor interface.
- **Operation ordering:** repay strictly precedes withdraw; collateral/controller enables precede borrow — consistent with EVK's per-call (not per-batch) account status checks under `callThroughEVC` re-routing.
- **Sub-accounts/operators:** hooks only ever use the plain executing account (sub-account 0); no operator or EVC-permit surface exists.
- **Euler v1 hack pattern (donateToReserves, $197M):** not applicable to EVK v2 (no self-collateralization, structural status checks); no analogous unchecked mutation path in the hooks.
- **Inflation/donation attack on EVK vaults:** mitigated at the vault layer by EVK's virtual deposit; residual risk is listing-process hygiene only.
- Strict 197-byte decode, canonical booleans, reserved-zero enforcement, sentinel rejection, execution-array index arithmetic — all verified correct.

---

## P0 Findings (Critical)

None found.

## P1 Findings (High)

None found.

## P2 Findings (Medium)

### [P2-1] Protocol addresses (EVC / vaults) come from user calldata, not pinned immutables — a signed hostile `controllerVault` gains standing authority over ALL account collateral

- **File:** `src/hooks/loan/euler/BaseEulerLoanHook.sol:123` (constructor pins nothing), `src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol:100-106`
- **SWC:** N/A
- **Category:** Access Control / Logic
- **Description:** Every Morpho loan hook pins the protocol singleton at deploy (`address public immutable morpho`). The Euler hooks deviate: `evc`, `controllerVault` and `collateralVault` are activation calldata, and `_validateBindings` only checks **self-reported** values (`vault.EVC() == evc`, `vault.asset() == asset`) that any hostile contract satisfies trivially. The sharpest shape is the *real* EVC with a hostile `controllerVault`: `IEVC.enableController(account, controllerVault)` registers arbitrary code as the account's controller, and an EVC controller holds `controlCollateral` power over **every** enabled collateral of the account, **indefinitely** — a blast radius beyond "the user loses what they signed." The exact-delta settle checks only bound what moves inside the transaction, not the persistent authority granted. EVK vault deployment is permissionless, so "looks like a real EVault" is not evidence of safety.
- **Exploit Scenario:** A phishing frontend gets a user to sign a Merkle leaf whose `controllerVault` is attacker code reporting the canonical EVC and the right `asset()`. The attacker vault delivers the exact borrow amount so `_settleOpen` passes. Weeks later the attacker calls `controlCollateral` through the EVC and drains all of the account's enabled EVK collateral positions.
- **Real-World Precedent:** Seneca Protocol (Feb 2024) and Dough Finance (Jul 2024) — approval/batched-execution drains via attacker-controlled call targets.
- **Vulnerable Code:**
  ```solidity
  constructor(bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) { }   // nothing pinned
  ...
  callData: abi.encodeCall(IEVC.enableController, (account, vars.controllerVault))
  ```
- **Secure Pattern:** Pin the EVC per chain as an immutable (Morpho precedent) and, where feasible, verify vault provenance via the canonical `GenericFactory.isProxy()`:
  ```solidity
  address public immutable EVC_ADDR;
  constructor(address evc_, bytes32 hookSubtype_) BaseLoanHookV2(hookSubtype_) {
      if (evc_ == address(0)) revert ADDRESS_NOT_VALID();
      EVC_ADDR = evc_;
  }
  // _validateBindings: if (IEVault(vars.controllerVault).EVC() != EVC_ADDR) revert VAULT_EVC_MISMATCH();
  // ideally: if (!IGenericFactory(EVAULT_FACTORY).isProxy(vars.controllerVault)) revert UNTRUSTED_VAULT();
  ```
  If calldata-supplied addresses are retained by design (the `inspect()` payload does correctly expose `evc`/`controllerVault`/`collateralVault` for off-chain allowlisting), the deviation from the Morpho immutable precedent and the total reliance on off-chain leaf vetting must be documented in SECURITY.md, and the platform's leaf-vetting must hard-allowlist the EVC and factory-verified vaults.
- **Reference:** vulnerabilities.md Section 2 (Access Control), Section 36 ("Trust boundaries defined"); SECURITY.md ("hook safety depends on external contract trustworthiness")

### [P2-2] Exact-cap close intents deterministically revert under ordinary interest accrual — `predictedClear` is knife-edge on `cap == debtOf`

- **File:** `src/hooks/loan/euler/BaseEulerLoanHook.sol:235-236`, `src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol:71-74, 101-105`
- **SWC:** N/A
- **Category:** DoS / Logic
- **Description:** `predictedClear = (min(cap, debtOf) == debtOf)`. Debt accrues per second (rounded up), so a cap set to the exact debt at *signing* time is almost always below the debt at *execution* time. In `EulerRepayAndWithdrawHook` the failure is not graceful: with `predictedClear == false` the controller stays enabled and a (typically full-balance) withdrawal then runs EVK's end-of-call health check against residual dust debt with near-zero remaining collateral — the withdrawal reverts, killing the entire chained userOp including upstream legs. The only safe encoding is `cap = type(uint256).max`, but nothing enforces or warns at decode time. (The attacker-assisted variant is benign — third parties can only *reduce* debt, which keeps `predictedClear` true — so this is a natural-cause DoS, but it hits the most natural full-close encoding.)
- **Exploit Scenario:** User signs a full close with `repayAmount = debtOf` from simulation and `withdrawAmount = maxWithdraw`. Ten minutes later debt has accrued 3 wei above the cap; `disableController` is not emitted and the full-collateral withdraw fails the health check — the whole intent reverts until re-signed.
- **Vulnerable Code:**
  ```solidity
  actualRepay = cap < debt ? cap : debt;
  predictedClear = actualRepay == debt;   // knife-edge equality vs. per-second accrual
  ```
- **Secure Pattern:** Fail fast with a precise error instead of an opaque health-check revert, or mandate the max-cap encoding for closes in the builder:
  ```solidity
  if (!predictedClear
          && IEVault(vars.collateralVault).previewWithdraw(vars.secondary)
              >= IEVault(vars.collateralVault).balanceOf(account)) {
      revert RESIDUAL_DEBT_FULL_WITHDRAW();
  }
  ```
- **Reference:** vulnerabilities.md Section 7.4 (Unexpected Revert DoS), Section 25 (stale-value assumptions between signing and execution)

### [P2-3] Duplicated close-leg validation + disable-collateral predicate in EulerRepayAndWithdrawHook

- **File:** `src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol:70-74` and `:160-168`
- **SWC:** N/A
- **Category:** Logic (maintainability → divergence risk)
- **Description:** The withdraw-leg validation and the two-line `disableCollateral` predicate are copy-pasted verbatim into both `_buildHookExecutions` and `_preExecute`. The sibling `EulerDepositCollateralAndBorrowHook` correctly extracts its shared resolution into `_resolveOpenAmounts`; this hook does not. If one copy is ever edited without the other, build-time and preExecute-time behavior silently diverge — exactly the drift class the extracted-helper pattern exists to prevent, and here divergence would directly desynchronize the built executions from the settle expectations.
- **Secure Pattern:** Extract a shared helper:
  ```solidity
  function _resolveCloseLegs(address prevHook, address account, EulerVars memory vars)
      internal view
      returns (uint256 actualRepay, bool predictedClear, bool disableCollateral)
  {
      if (vars.secondary == 0 || vars.secondary == type(uint256).max) revert AMOUNT_NOT_VALID();
      (actualRepay, predictedClear) = _resolveRepayCap(prevHook, account, vars);
      disableCollateral = predictedClear
          && IEVault(vars.collateralVault).previewWithdraw(vars.secondary)
              == IEVault(vars.collateralVault).balanceOf(account);
  }
  ```
- **Reference:** coding-rules.md (DRY/common checks); vulnerabilities.md Section 36 (code quality)

## P3 Findings (Low)

### [P3-1] Fail-open safety flags in plain (non-context-keyed) transient storage

- **File:** `src/hooks/loan/euler/BaseEulerLoanHook.sol:62-66`; consumers at `EulerRepayHook.sol:122-124`, `EulerRepayAndWithdrawHook.sol:177-184`
- **Category:** Reentrancy / transient-storage poisoning (SWC-107-adjacent)
- **Description:** The amount transients inherited from BaseLoanHookV2 are fail-closed under interleaving (poisoning → `DELTA_MISMATCH` revert). The two new booleans `expectedControllerDisabled`/`expectedCollateralDisabled` are fail-**open**: if a callback-capable token/vault in the chain hands execution to a third party mid-settle (documented SECURITY.md exclusion), an attacker can run their own `setExecutionContext` + `preExecute` on the same hook contract with unrelated data resolving `predictedClear = false`, overwriting the flags so the victim's `_postExecute` silently **skips** `_verifyDebtCleared` and the collateral-disabled check. Direct impact is limited (the built `disableController`/`disableCollateral` executions still revert on their own failure), but flags that exist precisely to catch nonstandard vault behavior deserve context-keying.
- **Fix:** Store the flags via BaseHook's context-keyed tstore pattern (as `outAmount`/`outToken` already are).
- **Reference:** vulnerabilities.md Section 10.4 (ERC-777 hooks), Section 23; BaseLoanHookV2.sol:39-45 caveat

### [P3-2] Dust-debt griefing: full third-party repay forces `NO_OUTSTANDING_DEBT` and reverts the whole chained intent

- **File:** `src/hooks/loan/euler/BaseEulerLoanHook.sol:229-230`
- **Category:** DoS / MEV
- **Description:** EVK repay is permissionless on behalf of any debtor. Partial front-runs are absorbed by `min(cap, debt)`, but a *full* front-run repay makes `_resolveRepayCap` hard-revert, cancelling the victim's entire userOp including unrelated upstream legs. Griefer cost = the victim's debt, so it is only economical against dust debts.
- **Fix:** For the standalone repay hook, degrade gracefully on zero debt: emit no provider calls, settle a zero delta, still emit `disableController` if the controller remains enabled.
- **Reference:** vulnerabilities.md Section 7.4, Section 6

### [P3-3] Full-exit detection (`previewWithdraw(secondary) == balanceOf`) false-negatived by 1-wei share donation / preview rounding — stale enabled collaterals accumulate toward the EVC's 10-collateral cap

- **File:** `src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol:72-74, 166-168`
- **Category:** Vault / Logic
- **Description:** The strict equality is internally consistent (build and `_preExecute` recompute identically in-tx — no revert path), but trivially false-negatived: 1-wei share donation to the account, `previewWithdraw(maxWithdraw)` round-trip landing at `balance − 1`, or exchange-rate accrual between signing and execution. The hook then succeeds but never emits `disableCollateral`; dust-enabled collateral vaults accumulate against the EVC's hard cap of 10 per account until a future `enableCollateral` for a new position reverts, requiring manual cleanup.
- **Fix:** Detect full exit post-hoc (emit `disableCollateral` whenever `predictedClear` and verify `balanceOf(account) == 0` after withdrawal) or use share-denominated `redeem(balanceOf)` for the full-exit case so donations cannot desynchronize assets from shares.
- **Reference:** vulnerabilities.md Section 22.3, Section 28

### [P3-4] Raw `IERC20.approve` in built executions — no SafeERC20 semantics for false-returning tokens

- **File:** all three concrete hooks (approval executions)
- **Category:** Token (SWC-104)
- **Description:** ERC-7579 account execution doesn't decode return data, so a token returning `false` on approve proceeds silently and the subsequent provider call fails with an opaque allowance revert instead of a clean error. Fail-closed (whole tx reverts) and consistent with the Morpho precedent — severity-limited. Fee-on-transfer/rebasing exclusion is already documented in BaseLoanHookV2.
- **Fix:** Document the supported-token matrix in NatSpec, or route through a `forceApprove`-style helper target.
- **Reference:** vulnerabilities.md Sections 10.3, 10.5, 8.1

### [P3-5] `getCollateralTokenBalance` reverts on EulerRepayHook data while ERC-165 advertises full `ISuperHookLoans`

- **File:** `src/hooks/loan/euler/EulerRepayHook.sol:37-40` (limitation NatSpec), `src/hooks/loan/BaseLoanHook.sol:86-89` (non-virtual getter)
- **Category:** Logic / interface contract
- **Description:** The repay layout reserves `collateralAsset = 0`, so the inherited getter does `IERC20(address(0)).balanceOf(...)` → abi-decode revert, while `supportsInterface(ISuperHookLoans)` returns true. An ERC-165-driven integrator calling the full interface uniformly will DoS its own batch. Documented in NatSpec, hence informational.
- **Fix:** Make the getter `virtual` in BaseLoanHook and override to `return 0` when the collateral slot is the reserved zero address.
- **Reference:** vulnerabilities.md Section 29, Section 36

### [P3-6] `decodeUsePrevHookAmount` panics (0x32) instead of `INVALID_DATA_LENGTH` on short data

- **File:** `src/hooks/loan/euler/BaseEulerLoanHook.sol:132-134`
- **Fix:** Length-check before `_decodeStrictBool`. (Same weakness exists codebase-wide in `BaseLoanHook`.)

### [P3-7] Redundant second read of the secondary word in `_decodeEuler`

- **File:** `src/hooks/loan/euler/BaseEulerLoanHook.sol:158,169` — `_requireZeroWord` re-reads a word already decoded into `vars.secondary`. Check the decoded value directly.

### [P3-8] Unconditional re-decode in `EulerRepayAndWithdrawHook._postExecute`

- **File:** `src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol:176-184` — `_decodeEuler` runs even when both flags are false and `vars` is unused. `EulerRepayHook` gets this right.

### [P3-9] Collateral-disabled verification inlined instead of a base helper alongside `_verifyDebtCleared`

- **File:** `EulerRepayAndWithdrawHook.sol:180-184` — add `_verifyCollateralDisabled` in `BaseEulerLoanHook` next to `_verifyDebtCleared`, co-locating declaration (`expectedCollateralDisabled`, `COLLATERAL_NOT_DISABLED`) and enforcement.

### [P3-10] Missing CONSTRUCTOR section banners in the three concrete hooks

- **File:** `EulerDepositCollateralAndBorrowHook.sol:37`, `EulerRepayHook.sol:42`, `EulerRepayAndWithdrawHook.sol:41` — sibling Morpho V2 hooks use the ASCII banner; the Euler hooks drop the constructor bare.

### [P3-11] Incomplete `@param`/`@return` NatSpec tags on several internal functions

- **File:** `BaseEulerLoanHook.sol` (`_validateBindings`, `_validateControllerState`, `_validateOpenMarket`, `_resolveRepayCap` params, `_inspectComposite`, `_inspectRepay`), `EulerDepositCollateralAndBorrowHook.sol:151` — nudge toward the fully-tagged style `_decodeEuler` demonstrates.

### [P3-12] Vendor interface NatSpec missing `@return` tags on simple views

- **File:** `src/vendor/euler/IEVault.sol:17,20,23,27,51` (`asset`, `EVC`, `balanceOf`, `maxDeposit`, `cash`).

---

## Attack Surface Summary

- **External Entry Points:** hook lifecycle (`build`, `preExecute`, `postExecute` — mutex/context-gated by BaseHook), pure views (`inspect`, `decodeAmounts`, `decodeUsePrevHookAmount`, `replaceCalldataAmounts`), `ISuperHookLoans` getters.
- **Value Transfer Points:** built executions from the smart account — ERC-20 approvals to the collateral/controller vault, `EVault.deposit/withdraw/borrow/repay` (all receivers/debtors hardcoded to the account).
- **Oracle Dependencies:** none in the hooks themselves; each target EVault carries a governor-chosen oracle that drives its health checks (vault-selection risk, see P2-1 and listing-hygiene note).
- **Cross-Contract Interactions:** IEVault (deposit/withdraw/borrow/repay/disableController + views), IEVC (enableCollateral/enableController/disableCollateral + views), previous hook's `getOutToken`/`getOutAmount`.
- **Upgrade Mechanisms:** none — hooks are immutable; persistent risk surface is the standing EVC controller/collateral enablement on the account (see P2-1).
- **Trust boundaries:** hook calldata is user-signed (Merkle leaf) and vetted off-chain via `inspect()`; EVC/vault addresses are calldata, so off-chain allowlisting is currently the sole barrier against hostile-vault leaves.

## External research notes (Euler-specific)

- **Euler v1 hack (Mar 2023, ~$197M, donateToReserves/self-liquidation):** pattern does not carry to EVK v2; meta-lesson (every mutation path must end in verification; economic-logic flaws evade tooling) is satisfied by the delta-settle + post-verify design.
- **Euler v2 audit posture:** EVC/EVK audited by Spearbit, ChainSecurity, Certora, OpenZeppelin, Trail of Bits and a record Cantina competition; no EVK/EVC exploit reported through 2025. Integration risk therefore concentrates in the hook layer and **vault selection**, consistent with P2-1.
- **Listing hygiene for new EVK targets:** EVK's virtual deposit defeats Sonne-class empty-market donation attacks at the vault layer; still seed/verify liquidity, oracle config and decimals when whitelisting a new vault.
- **Sub-account caveat:** plain ERC-20 transfers to EVC sub-account addresses are unrecoverable; hooks correctly never derive receivers from user data.
- **OWASP SC Top 10 (2025) mapping:** highest-relevance categories are SC01 Access Control / SC04 Input Validation / SC06 Unchecked External Calls (all → P2-1), SC03 Logic Errors (→ P2-2), SC10 DoS (→ P2-2, P3-2, P3-3).

## Coding Standards Findings

Overall strong compliance: fixed pragma 0.8.30, custom errors only, explicit visibility, repo-convention import blocks, SCREAMING_SNAKE errors, trailing-underscore constructor params, above-bar security NatSpec (invariant block, EVC omitted-function rationale, repay debtor-semantics caution, documented `getCollateralTokenBalance` limitation). `inspect` being `pure` improves on Morpho's `view`. No events — consistent with the whole hook family (provider contracts emit; hook state is transient). Deviations are P2-3 and P3-6…P3-12 above.

## Fixes Applied (2026-08-28)

- **P2-1 (fixed — stronger than recommended):** `BaseEulerLoanHook` now constructor-pins the
  canonical per-chain `EVC_ADDRESS` **and** `EVAULT_FACTORY` (both singletons per chain, from
  euler-xyz/euler-interfaces; Base: EVC `0x5301c7dD…8989`, factory `0x7F321498…f8D0`). The calldata
  `evc` must equal the pin (`EVC_NOT_CANONICAL`) and every configured vault must pass
  `GenericFactory.isProxy` (`UNTRUSTED_VAULT`) — a hostile contract self-reporting the canonical
  EVC/asset can no longer be enabled as controller. New vendor interface `IGenericFactory`. Deploy
  script/config wired per the Morpho constructor-arg pattern (`ConfigOtherHooks.eulerEvcs` /
  `eulerEVaultFactories`, gated on presence).
- **P2-2 (fixed):** `EulerRepayAndWithdrawHook` fails fast with `RESIDUAL_DEBT_FULL_WITHDRAW` when
  residual debt would meet a full-collateral withdrawal (the doomed exact-cap close encoding).
- **P2-3 (fixed):** close-leg resolution extracted into a single `_resolveCloseLegs` helper shared
  by `_buildHookExecutions` and `_preExecute`.
- **P3-1 (fixed — design change):** the fail-open transient flags `expectedControllerDisabled` /
  `expectedCollateralDisabled` were **removed**. Post-execution verification is now state-derived
  (`_verifyReleaseState`: `debtOf == 0` ⟹ controller, and for closes this collateral, must be
  disabled) — unpoisonable by interleaved executions, fails closed. (BaseHook's context-key
  machinery is private, so context-keying the flags would have required touching audited code.)
- **P3-2 (fixed):** zero outstanding debt now degrades gracefully: `_resolveRepayCap` returns
  `(0, clear)`, the repay leg (approvals + repay) is skipped, disables are gated on live
  `isControllerEnabled`/`isCollateralEnabled` reads, and the intent succeeds with a zero settle.
  `NO_OUTSTANDING_DEBT` griefing (gift-repay canceling a signed multi-leg intent) is gone.
  Trade-off accepted: a repay against a wrong/empty market is now a silent no-op instead of a
  revert (bindings + inspector allowlisting still gate the market identity).
- **P3-3 (fixed):** `disableCollateral` is emitted on any predicted debt-clear while the collateral
  flag is enabled (partial or full withdrawal) — donation-proof, no fragile
  `previewWithdraw == balanceOf` equality; the flag release never locks funds and stops stale
  entries accumulating toward the EVC's 10-collateral cap.
- **P3-4 (skipped — accepted):** raw `IERC20.approve` kept, consistent with the Morpho hook
  precedent; failure mode is fail-closed (opaque revert, no fund risk).
- **P3-5 (fixed):** `BaseLoanHook._supportsLoanInterface` made `virtual` (verified byte-identical
  locked bytecode for deployed hooks under `bytecode_hash = "none"`); `EulerRepayHook` overrides it
  to `false` so ERC-165 no longer advertises an interface whose collateral getter reverts.
  `tooling/hook-enrichment.yaml` and `manifests/hooks.json` regenerated to match.
- **P3-6 (fixed):** `decodeUsePrevHookAmount` length-checks before indexing — custom
  `INVALID_DATA_LENGTH` instead of a Panic(0x32).
- **P3-7 (fixed):** `_decodeEuler` checks the already-decoded `vars.secondary` instead of
  re-reading the word.
- **P3-8 (resolved by design):** the post-execute decode is now always required by the
  state-derived verification, so there is no unused-decode branch.
- **P3-9 (fixed):** release verification co-located in the base as `_verifyReleaseState`, next to
  the errors it raises.
- **P3-10 (fixed):** CONSTRUCTOR section banners added to all three concrete hooks.
- **P3-11/P3-12 (fixed):** `@param`/`@return` NatSpec completed on the base's internal functions
  and the vendor `IEVault` simple views.

**Verification:** `forge build` clean; 91 unit + 48 branch-coverage fork + 15 E2E fork Euler tests
pass (new coverage: pinned-constructor validation, `EVC_NOT_CANONICAL`, `UNTRUSTED_VAULT` on all
three hooks against real Base state, `RESIDUAL_DEBT_FULL_WITHDRAW`, graceful zero-debt through the
full UserOp flow, donation-proof collateral release, state-derived release checks); full loan-hook
suite (654 tests) passes; `MorphoRepayHookV2` locked bytecode compared byte-for-byte after the
`virtual` change — identical; Euler generated/locked bytecode and hook manifests regenerated.

## Security Knowledge Sources

- **vulnerabilities.md sections referenced:** 1, 2, 6, 7.4, 8.1, 10.3–10.5, 14.3, 15, 22.3, 23, 25, 28, 29, 36
- **External:** Euler EVC/EVK docs & whitepaper, EVC specs.md (CER-21/51/56/57/60/68/107/110), evmresearch.io patterns (stale approvals, USDT zero-first, ERC-4626 donation, ERC-4337 transient bleed, router calldata drains), Cyfrin/Zellic/BlockSec Euler v1 analyses, Halborn/Verichains Sonne analyses, OpenZeppelin ERC-4626 defense, MixBytes Euler V2, ChainSecurity EVC audit, OWASP SC Top 10 (2025)
- **Historical exploits cross-referenced:** Euler v1 (2023), Seneca (2024), Dough Finance (2024), Sonne (2024), Onyx (2023), Hundred (2023)
- **Coding rules validated:** superform-specs/guidelines/solidity/coding-rules.md (full pass; 8 style findings)
