# Security Analysis Report — SUP-21038 Morpho Blue header identity

## Metadata
- **Target:** 10 changed Morpho hook files on `feat/sup-21038-morpho-header-identity`
  (BaseMorphoLoanHook, BaseMorphoLoanHookV2, MorphoLendHook, MorphoWithdrawHook, + 6 V2 leaves)
- **Mode:** review (3 parallel agents: vuln scanner, best-practices, EVM researcher)
- **Date:** 2026-09-17
- **Contract types:** ERC-7579 loan / money-market hooks integrating Morpho Blue (shared singleton)
- **Vulnerability DB:** superform-specs/guidelines/solidity/vulnerabilities.md

## Summary
| Severity | Count | Blocks merge |
|----------|-------|--------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium (advisory / hardening) | 3 | No |
| P3 Low | 6 | No |

## Verdict
**PASS** — No exploitable P0/P1 in the current code. The `_requireYieldSourceIsMorpho` pin is
correctly placed ahead of every use of the header-derived `yieldSource` as a call target or approve
spender (verified in **both** `build` and `preExecute` for all in-scope leaves); no view / sizing /
settle / inspect path uses the header target unguarded; Morpho callbacks pass empty data (`""`);
approvals are zero-reset on both sides; zero-address headers revert `ADDRESS_NOT_VALID`; malformed /
short calldata fails closed via BytesLib bounds checks.

The one item worth acting on is a **regression-hardening** concern (P2 below): the pin is effectively
the *primary* control (not "defense-in-depth"), and it is enforced by convention across ~16 call
sites — a future hook or refactor that omits it would reintroduce the arbitrary-call/approve class.
A single invariant test converts that convention into a CI-enforced guarantee.

---

## P0 / P1
**None found.**

---

## P2 Findings (advisory — recommend addressing, none block merge)

### P2-1 — The header→target pin is the *primary* control, enforced only by per-site convention
- **Category:** Logic / arbitrary external call (defense-in-depth mislabel)
- **Files:** all 8 changed leaves (`_buildHookExecutions` + `_preExecute`); `BaseMorphoLoanHook*.sol` `_requireYieldSourceIsMorpho`
- **Description:** Every Morpho call target and every `approve` spender is the header-decoded
  `vars.yieldSource` (offset 32). This is the exact shape of the SwapNet/Aperture ($17M) and 1inch
  Fusion ($5M) arbitrary-call/approve exploits — a contract that holds approvals and issues a call
  whose target comes from calldata. It is neutralized *today* because `_requireYieldSourceIsMorpho`
  reverts unless `yieldSource == morpho` (immutable), and it runs before the `Execution[]` is built
  on every path. But since the pinned value must equal the immutable, the calldata value carries
  **zero on-chain freedom** — the "defense-in-depth" label is inaccurate; it is the only thing
  preventing an arbitrary-call primitive. Risk is a future missing pin on a new path → instant P0.
- **Note on the structural fix:** the EVM-research agent recommends emitting the `morpho` immutable
  directly as the target and demoting the header to a validated-but-unused field. That would make the
  class impossible by construction — **but it contradicts SUP-21038 AC3** ("Morpho calls target
  `extractYieldSource()`"). So the spec-compliant hardening is a test, not a code change.
- **Mitigation (recommended):** add an invariant test asserting that, for arbitrary well-formed
  headers, **every** `Execution.target` and every `approve` spender returned by every Morpho hook's
  `build()` equals the `morpho` immutable — so a missing pin fails CI, not production. (Also correct
  the "defense-in-depth" wording to "primary call-target pin".)
- **Reference:** vulnerabilities.md arbitrary-call / approvals; BlockSec SwapNet/Aperture; Decurity 1inch Fusion.

### P2-2 — Morpho market body (oracle / IRM / LLTV) remains free calldata → permissionless-market selection
- **Category:** Oracle / DeFi interaction
- **Files:** all leaves (body decoded from offsets 52–228, used to build `MarketParams`)
- **Description:** Once the singleton target is pinned, the remaining attacker-influenceable surface
  is the `MarketParams` body. It is "identity only" to the hook (never priced), but Morpho fully
  trusts it: `marketId = keccak256(MarketParams)` selects the market, and Morpho honors that market's
  oracle/IRM. A rogue-oracle market could misprice collateral. **Mitigating factor:** the full
  230-byte payload is covered by the SuperValidator/Merkle leaf, so a *relayer* cannot swap in a rogue
  market — only the intent signer chooses it. Residual is signing-time market legitimacy.
- **Mitigation:** treat the `yieldSourceOracleId` + `inspect()` fingerprint allowlist as a security
  control (vetted `(oracle, irm, lltv)` tuples), documented and tested — not a UI label. Optionally an
  on-chain `marketId` allowlist per deployment if ever driven by less-trusted signers. (Out of scope
  here — SUP-21024/21025/21037 — but should be recorded.)
- **Reference:** Morpho Blue permissionless market creation.

### P2-3 — Empty-callback reentrancy invariant enforced only by literal `""` per call site
- **Category:** Reentrancy (Morpho `onMorpho*` callbacks)
- **Files:** MorphoLendHook, MorphoSupplyAndBorrowHookV2, MorphoSupplyHookV2, MorphoRepayHookV2, MorphoRepayAndWithdrawHookV2 (supply/supplyCollateral/repay call sites)
- **Description:** Morpho invokes `onMorpho*` (after state update, before token transfer) when callback
  `data` is non-empty. All sites correctly pass `""`, suppressing the callback. Correct today, but
  enforced by a hardcoded literal at each site rather than a guard/helper — a refactor that threads any
  bytes in silently opens a reentrancy window into the account.
- **Mitigation:** add a test asserting the callback-data arg of every emitted Morpho execution is
  empty (decode the calldata of supply/supplyCollateral/repay executions and assert trailing `bytes`
  is empty). Optionally centralize Morpho-call construction so no hook can pass non-empty data.
- **Reference:** vulnerabilities.md §1 (reentrancy); Morpho callbacks docs.

---

## P3 Findings (low / quality)

- **P3-1 — `MorphoWithdrawHook.MIN_DATA_LENGTH = 176` is too small.** Layout reaches offset 196–227
  (needs ≥ 228); the guard passes 176–227-byte payloads that then revert opaquely in BytesLib
  (fails closed, not exploitable). Fix: `MIN_DATA_LENGTH = 228` (`MorphoWithdrawHook.sol:46`). *(This
  pre-dates SUP-21038 but lives in a changed file.)*
- **P3-2 — Stale offset comments in `BaseMorphoLoanHook.sol:37,39`** say `AMOUNT_POSITION = 80` /
  `USE_PREV_HOOK_AMOUNT_POSITION = 144`; actual inherited values are 132 / 196. Code is correct; only
  the comments mislead.
- **P3-3 — V1 base docstring over-claims.** `BaseMorphoLoanHook.sol:20-21` says "Header-aware children
  decode the yield source and pin it," but the shared V1 decoders (`_decodeHookData`,
  `_decodeBorrowHookData`) don't; only the two migrated leaves (Lend/Withdraw) do. Tighten the wording
  to state only Lend/Withdraw are header-aware (the 5 frozen borrower hooks intentionally are not).
- **P3-4 — `MorphoLendHook._preExecute` decodes the payload twice** (`:190-193` then `_getSupplyShares`
  re-decodes at `:208`). Gas; V2 leaves decode once. Fix: decode once and reuse.
- **P3-5 — V2 `inspect()` declared `view`, should be `pure`** (all 6 V2 leaves) — bodies call only
  `pure` helpers; V1 family is `pure`. Inconsistent, looser than warranted.
- **P3-6 — Minor:** V2 `_requireYieldSourceIsMorpho` missing `@param` NatSpec
  (`BaseMorphoLoanHookV2.sol`); `YIELD_SOURCE_MISMATCH` declared in both bases (harmless dup).

---

## Attack Surface Summary
- **External entry points (changed):** `build`, `preExecute`, `postExecute`, `inspect`, sizing views
  (`decodeAmounts`/`replaceCalldataAmounts`/`decodeUsePrevHookAmount`).
- **Value-transfer / call-target points:** approve(loan/collateral → yieldSource); Morpho
  supply/borrow/repay/withdraw/supplyCollateral/withdrawCollateral → yieldSource. **All gated by the
  `yieldSource == morpho` pin.**
- **Oracle dependencies:** none read on-chain by the hook (Morpho IOracle is identity-only in the body).
- **Cross-contract:** Morpho Blue singleton (immutable, non-upgradeable); ERC20 loan/collateral tokens.
- **Upgrade mechanisms:** none — hooks are immutable, locked-bytecode; `morpho` set in constructor.

## Items checked and clean
Custom errors (no revert strings) · reentrancy empty-callback `""` · approve reset-to-0 both sides ·
pin present in build + preExecute on all in-scope leaves, absent from pure inspect · `inspect` packs 6
fixed-width fields (no abi.encodePacked collision, SWC-133 precondition absent) · stale-target replay
neutralized by double immutability (Morpho singleton + per-chain `morpho` immutable) · no tx.origin ·
locked pragma 0.8.30.

## Recommended follow-up tests (additive, no bytecode impact)
1. `invariant_MorphoHooks_AllCallTargetsAreMorpho` — for arbitrary headers, every `build()` execution
   target + approve spender == `morpho` (addresses P2-1).
2. `test_MorphoHooks_CallbackDataAlwaysEmpty` — every supply/supplyCollateral/repay execution's
   trailing callback `bytes` is empty (addresses P2-3).
