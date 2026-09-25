# Security Analysis Report — Morpho LOAN hooks carry the registry market key at header offset 32

## Metadata
- **Target:** uncommitted changes on `feat/morpho-hooks-redeploy` (off `dev` @ `be78f005`) — 14 source files under `src/hooks/loan/morpho/`, 16 test files, `test/utils/MorphoMarketKey.sol` (new), 24 bytecode locks
- **Mode:** review (3 parallel agents + independent verification)
- **Date:** 2026-09-18
- **Contract types:** hooks (money-market / lending integration), NONACCOUNTING execution units
- **Vulnerability database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (§1, §2, §3, §9, §10, §13, §14, §15, §36)

## Summary

| Severity | Count | Blocks merge |
|---|---|---|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 0 | No |
| P3 Low | 10 | No |

## Verdict

**PASS.** No P0/P1/P2 findings. The change is a net security improvement: it removes the last calldata-derived call target and approve spender from the Morpho family, closes a latent cross-layout confusion in the V1 repay path, and binds five body fields that were previously unbound on three preExecute paths. The ten P3 items are robustness, test-coverage and documentation hygiene.

---

## What changed

All 11 Morpho LOAN hooks (5 V1 borrower, 6 V2) now treat header offset 32 as the **registry market key** of the body `MarketParams` — `address(uint160(uint256(Id.unwrap(marketParams.id()))))` — instead of the Morpho Blue singleton.

- `_requireYieldSourceIsMorpho` (`view`, `YIELD_SOURCE_MISMATCH`) and `_requireHeaderMorpho(bytes)` are deleted. `_requireHeaderIsMarketKey(address, MarketParams)` (`pure`, `MARKET_KEY_MISMATCH`) replaces both.
- `_marketKey` / `_requireHeaderIsMarketKey` / `MARKET_KEY_MISMATCH` were hoisted from `BaseMorphoMoneyMarketHook` into `BaseMorphoLoanHook`, with an independent copy in `BaseMorphoLoanHookV2` (the two trees descend separately from the untouchable `BaseLoanHook` / `BaseLoanHookV2`).
- Every `Execution.target`, every `IERC20.approve` spender and every `IMorpho*` receiver is now the `morpho` immutable.
- `inspect()` is unchanged as a function: it still packs offset 32 verbatim followed by the same five body fields, 132 bytes, `pure`.

### Scope discipline

The change set is confined to `src/hooks/loan/morpho/`. No executor, ledger, registry, oracle, or shared loan base (`BaseLoanHook`, `BaseLoanHookV2`) is touched, satisfying the standing constraint that executor modules stay untouched. Calldata layouts, offsets and lengths are unchanged — filtering the diff to non-comment lines touching offsets or decoders yields only struct field renames.

---

## Key derivation is correct

`_marketKey` in both bases is a byte-identical expression to `MorphoBlueMarketRegistry.computeMarketKey` (`src/accounting/oracles/MorphoBlueMarketRegistry.sol:296-303`), and all four sites — registry, both hook bases, and the new test helper — resolve the same vendored `src/vendor/morpho/MarketParamsLib.sol`. `MarketParamsLib.id` keccaks the contiguous 5×32-byte struct, matching Morpho's own `_id`.

`test/unit/hooks/loan/MorphoLoanHooks.t.sol:2162` cross-checks the test derivation against a live `registry.computeMarketKey`, closing the chain test-helper ≡ registry ≡ hook.

---

## Pin coverage: 22 of 22 paths

The pin precedes every `Execution` construction, every provider read and every `prevHook` call, on both entry points of all 11 leaves. Verified line-by-line against `git show HEAD:` for every hook.

| Leaf | `_buildHookExecutions` | `_preExecute` |
|---|---|---|
| MorphoSupplyHook | pin `:82` → prevHook `:85`, exec `:91` | pin `:169` → balance `:170` |
| MorphoBorrowHook | pin `:66` → prevHook `:69`, exec `:75` | pin `:108` → balance `:109` |
| MorphoRepayHook | pin `:92` → `.id()` `:94`, exec `:97` | pin `:184` → `accrueInterest` `:185` |
| MorphoSupplyAndBorrowHook | pin `:77` → prevHook `:80`, oracle `:85`, exec `:88` | pin `:164` → balance `:165` |
| MorphoRepayAndWithdrawHook | pin `:101` → `.id()` `:102`, exec `:105` | pin `:264` → `accrueInterest` `:265` |
| MorphoSupplyAndBorrowHookV2 | pin `:68` → resolve `:69`, exec `:76` | pin `:138` → resolve `:139` |
| MorphoRepayHookV2 | pin `:78` → resolve `:80`, exec `:85` | pin `:118` → `_accrueInterest` `:120` |
| MorphoRepayAndWithdrawHookV2 | pin `:77` → resolve `:79`, exec `:87` | pin `:171` → `_accrueInterest` `:172` |
| MorphoSupplyHookV2 | pin `:71` → resolve `:72`, exec `:78` | pin `:107` → resolve `:109` |
| MorphoBorrowHookV2 | pin `:71` → resolve `:72`, exec `:77` | pin `:108` → resolve `:110` |
| MorphoWithdrawCollateralHookV2 | pin `:75` → resolve `:77`, exec `:80` | pin `:139` → resolve `:141` |

**Nothing was unpinned.** All 26 guarded entry points (13 hooks × 2) carry exactly one guard before and after. `grep` for `_requireYieldSourceIsMorpho`, `_requireHeaderMorpho`, `YIELD_SOURCE_MISMATCH` across `src/` returns zero hits — no orphaned helper, no leaf left calling a removed function.

The only reordering is in five V1 build paths where the pin moved from before to after `_generateMarketParams`. That helper is `internal pure` in-memory struct construction — no staticcall, no storage read, no execution — so the pin still dominates every effect.

**`_postExecute` needs no pin.** It constructs no execution and makes no Morpho call; its only external reads take the token address directly from calldata offsets 52/72, which the market key does not gate. Within one `_processHook` the same `hookData` was already pinned in `_preExecute`, and an out-of-band call is caught by the caller check, the post-execute mutex, and the executor's last-caller check.

### The three rewritten V1 preExecutes are strictly stronger

`MorphoSupplyHook`, `MorphoBorrowHook` and `MorphoSupplyAndBorrowHook` replaced a one-line `_requireHeaderMorpho(data)` with a full decode plus pin. Zero headers are still rejected with the same `ADDRESS_NOT_VALID`. Newly added on these paths: minimum-length enforcement, zero-checks on the four body addresses, and the five-field identity pin. Nothing was relaxed.

---

## Latent bug closed (hardening)

The V1 repay layout reads `lltv` at offset 164 while the borrow layout reads it at 197, and `_decodeHookData` guards length with `<` rather than `!=`. A 230-byte borrow payload fed to `MorphoRepayHook` previously passed the singleton pin and built a repay against a **wrong-`lltv` market**. It now fails `MARKET_KEY_MISMATCH`.

This was not the ticket's goal and is worth recording as an independent benefit.

---

## Call-target surface: clean

Exhaustive sweep of `target:`, `IERC20.approve` and `IMorpho*(...)` across all 11 leaves:

| | Before | After |
|---|---|---|
| `Execution.target` = `morpho` | 2 | 20 |
| `Execution.target` = calldata-derived | 18 | 0 |
| approve spender = `morpho` | 3 | 29 |
| approve spender = calldata-derived | 26 | 0 |
| empty callback args | 13 | 13 |

`vars.marketKey` is used only in the pin and in `inspect()`. It is never a target, spender or call receiver.

The old pin's effect (target equals the singleton) is now a structural property of the code rather than a runtime assertion. That is strictly better: a refactor that forgets the pin can no longer redirect a call, only skip an identity check.

One calldata-derived call target remains, unchanged by this diff: the Morpho `IOracle.price()` staticcall inside `deriveLoanAmount` at `MorphoSupplyAndBorrowHook.sol:145`. Pre-existing, inside a `view` build, bounded by Morpho's own health check.

**Design property to record:** LOAN hooks are NONACCOUNTING and therefore have **no registry allowlist**, unlike the money-market pair whose key resolves through `MorphoBlueMarketRegistry.getMarketInfo` and reverts `MARKET_NOT_REGISTERED`. A signed payload can name any market and token pair. Morpho's own `createMarket` bounds this to governance-enabled IRM and LLTV, and the whole calldata is covered by the userOp signature. Unchanged by this diff, consistent with `SECURITY.md`.

---

## Reentrancy: unchanged

Every Morpho call with a callback slot passes empty data, in all 11, before and after. `borrow`, `withdraw` and `withdrawCollateral` have no callback parameter. Moving the target to the immutable changes nothing about the callback surface, since the target's identity was already equal to `morpho` at execution time under the old pin. `_processHook` remains `nonReentrant` and the pre/post mutexes are intact.

---

## Truncation and collisions: negligible

The 160-bit truncation is never dereferenced on the LOAN path. The hook passes the **full 256-bit `MarketParams`** to the singleton, so Morpho acts on exactly the body's market; the key is never resolved through the registry and is never a call target.

| Attack | Cost |
|---|---|
| Targeted second preimage on a specific key | ~2^160 keccak evaluations |
| Birthday collision among attacker-created real markets | ~2^80 `createMarket` calls |
| Accidental, at ~2^20 real markets | ~2^-121 |

Even granting a collision, the impact ceiling is off-chain mis-attribution plus the registry refusing the second registration. A careless strategist gains nothing: any body produces its own key, and the header must match it.

---

## Leaf and `inspect()` consequences

`inspect()` is **not consumed anywhere on-chain** in this repo. The validators hash the userOp hash and the destination data, not inspect bytes. It is purely an off-chain identity surface, consumed by the aggregator in the periphery repo.

**The function is behaviourally identical before and after.** Both versions pack offset 32 verbatim plus the same five body fields. The map from payload bytes to inspect bytes is unchanged, so **no two payloads that differed before can coincide now, and Merkle leaf hashes do not change.**

What changed is which payloads survive the pin. Within that surviving set the mapping is strictly more discriminating: the old encoding gave every Morpho borrow leaf the same chain-constant first 20 bytes, whereas two markets on one singleton are now distinguishable in field 0.

**Practical consequence for SUP-21025:** an off-chain builder still emitting the singleton at offset 32 produces leaves that hash and verify correctly, then revert at execution with `MARKET_KEY_MISMATCH`. Fail-closed, but the break surfaces at execution rather than at proof construction. The leaf builder now needs one key-first encoding for all 13 hooks.

---

## P3 Findings

### P3-1 — V2 leaves pin a throwaway `MarketParams` copy
`MorphoSupplyAndBorrowHookV2.sol:68`+`:73`; `MorphoRepayHookV2.sol:78`+`:79`, `:118`+`:119`; `MorphoRepayAndWithdrawHookV2.sol:77`+`:78`, `:171`+`:174`; `MorphoSupplyHookV2.sol:71`+`:75`; `MorphoBorrowHookV2.sol:71`+`:74`; `MorphoWithdrawCollateralHookV2.sol:75`+`:76`, `:139`+`:141`.

Category: logic robustness / TOCTOU-by-refactor. The pin validates one allocation, then a second independent one is built and used:

```solidity
_requireHeaderIsMarketKey(vars.marketKey, _marketParams(vars));   // pinned copy, discarded
vars.amount1 = _resolveOpenAmount1(...);                          // vars mutated here
MarketParams memory marketParams = _marketParams(vars);           // the copy actually used
```

Correct today, because `_marketParams` is pure over the five identity fields and `amount1` is not one of them. But `MorphoSupplyAndBorrowHookV2` already mutates `vars` between the pin and the rebuild, so safety rests on an invariant nobody enforces. The V1 leaves do it correctly, pinning the struct they then use.

Fix, which also removes a redundant keccak and a 160-byte allocation per path:
```solidity
MarketParams memory marketParams = _marketParams(vars);
_requireHeaderIsMarketKey(vars.marketKey, marketParams);
```

### P3-2 — No negative-pin test on `_preExecute` for `MorphoRepayHookV2` and `MorphoRepayAndWithdrawHookV2`
`MorphoLoanHooksV2.t.sol:422-433` (open only); `MorphoHeaderIdentitySharedMorpho.t.sol:227-252` (all six V2 but `build()` only).

Both are pinned in source. Neither has a mismatched-header preExecute test anywhere, and these are precisely the two whose preExecute makes a **state-changing** `accrueInterest` call immediately after the pin. A future refactor could drop the pin from the two paths where it matters most and every test would stay green.

`test_AllOps_RevertIf_HeaderIsOtherMarketKey` (`:256-273`) also covers only 6 of 8 ops, skipping repay and close, despite its name and doc comment claiming every op.

Fix: extend both loops to call `preExecute` for all six V2 hooks, and add the two missing ops.

### P3-3 — `inspect()` echoes the unvalidated header
`BaseMorphoLoanHookV2.sol:270` and the five V1 leaves.

`inspect()` never runs the pin (it must stay `pure`), so on a mismatched payload the first 20 bytes name market B while the remaining 112 describe market A. Harmless on-chain — both entry points revert. The exposure is any off-chain consumer that reads market identity from `inspect()[0:20]` rather than recomputing from `[20:132]`.

This was a deliberate design choice, so that a mismatch yields a different leaf **as well as** a revert. Acceptable, but it must be documented at the interface so off-chain code knows which convention applies.

### P3-4 — The `morpho` immutable is the sole call-target authority, with no post-deploy assertion
`BaseMorphoLoanHook.sol:126-129`, `BaseMorphoLoanHookV2.sol:111-115`; `script/DeployV2OtherHooks.s.sol`.

The constructor's zero-check is now the only on-chain gate on the address receiving every Morpho call and every approve allowance.

**Accurate framing:** the old pin did not validate the immutable either. It asserted header-equals-immutable, a consistency check — a payload carrying a bogus address would have passed. What is lost is a *detection* property that held only under honest bundler encoding: correct calldata against a misconfigured hook used to revert. The residual risk is unchanged in kind, only in visibility.

Mitigations already in place: a single per-chain config entry feeds all 13 hooks, and the argument is part of the CREATE2 init code, so a wrong singleton yields a different address and the value is verifiable by reading the immutable.

Gap: `grep '.morpho()'` over `script/` returns nothing. Assertions exist only against mocks in unit tests.

Fix: add a post-deploy `assertEq(hook.morpho(), MORPHO_BLUE)` for all 13 in the deploy verification script, and update the release checklist's canonical-singleton item to state that it is now the only guard.

### P3-5 — Vacuous inspect assertion
`MorphoLoanHooks.t.sol:2060`:
```solidity
assertEq(BytesLib.toAddress(out, 0), BytesLib.toAddress(datas[i], 32), "field 0 = header market key");
```
This asserts only that `inspect()` echoes bytes 32..52 of its own input. It passes for any header and proves nothing about the key. It would stay green with `_marketKey` deleted entirely. The previous assertion against a constant was strictly stronger.

Fix: assert the independently derived key, `_mmKey(loanToken, collateralToken, address(mockOracle), MORPHO_IRM, lltv)`.

### P3-6 — `test_AllOps_InspectIsPerMarket` passes for the wrong reason
`MorphoHeaderIdentitySharedMorpho.t.sol:292`, `:314`.

The two `keccak256(a) != keccak256(b)` assertions would be green under the old singleton-first encoding too, since markets A and B already differ in bytes 20..132. Only `:316-317` are non-vacuous. The name says "AllOps" while only open and pledge are exercised.

Fix: assert `bytes20(a) != bytes20(b)`, which is false before this change, and either rename or loop all eight.

### P3-7 — Test-helper duplication not anchored
Nine helpers in three shapes. Two suites delegate to the shared `morphoMarketKey`, five import it, and seven hand-roll the same expression (`MorphoLoanHooks.t.sol:181`, `MorphoHeaderIdentitySharedMorpho.t.sol:584`, `MorphoHeaderIdentityFork.t.sol:127`, `MorphoHeaderIdentityE2E.t.sol:880`, `MorphoBaseChainHooksFork.t.sol:211`, `MorphoLendIntegrationTest.t.sol:146`, `MorphoLendE2E.t.sol:164`).

`test/utils/MorphoMarketKey.sol` itself is correct, and reimplementing rather than calling the registry is the right call — `computeMarketKey` is `external pure` and needs a deployed instance the unit suites do not have.

Fix: make every per-suite wrapper a one-liner over the shared function, and add a registry cross-check for `morphoMarketKey` in a fork suite that has a registry. That anchor is what makes the duplication acceptable rather than merely convenient.

### P3-8 — Tautological assertions left behind
`MorphoHeaderIdentitySharedMorpho.t.sol:393` asserts the target is not `otherMorpho`, which is now unreachable from calldata by construction. `testFuzz_CallTargetsAlwaysMorpho_ArbitraryBody` (`:412-463`) has the same problem: its value was "no crafted body redirects the target", now tautological.

Fix: keep as cheap regression guards but relabel. The fuzz test's remaining real content is that an arbitrary well-formed body still produces a well-shaped execution set.

### P3-9 — Stale documentation
`src/`: the layout NatSpec is **correct** in the bases and 10 leaves. The repo-wide convention across 46 files is `address yieldSource = data.extractYieldSource()` — the identifier mirrors the decoder name, not the struct member — and the Morpho lines already carry the corrected trailing comment naming the market key. The single deviation is `MorphoSupplyHook.sol:21`, which was renamed to `address marketKey` and should be reverted to match the other 45 files.

The header-identity paragraph now appears three times in one inheritance chain (`BaseMorphoLoanHook` → `BaseMorphoMoneyMarketHook` → `MorphoLendHook`), where the leaf copy used to be load-bearing and is now a restatement. Trim the leaf copy to the money-market-specific half; do not mirror it onto the 11 loan leaves.

`test/`: stale references to the removed error and helper at `MorphoHeaderIdentitySharedMorpho.t.sol:41`, `:409`, `MorphoLoanHooks.t.sol:2006`, `:2035-2036`, `:2054-2056`, `MorphoHeaderIdentityFork.t.sol:36`. Stale test names: `test_Build_RevertIf_YieldSourceMismatch`, `test_Standalone_Build_RevertIf_YieldSourceMismatch`, `test_V1Borrowers_RevertIf_YieldSourceMismatch`, `test_Inspect_PacksHeaderYieldSource`.

Note: `test_V1Borrowers_RevertIf_YieldSourceMismatch` is now a near-duplicate of the singleton test. It should be repurposed into the V1 "another market's key" negative, which is currently missing entirely.

No `@N` doc tags were introduced, so the compile-error class was avoided.

### P3-10 — Unused imports
`test/utils/InternalHelpers.sol:23` no longer references `MORPHO_BLUE`. The `BaseMorphoMoneyMarketHook` import is unused in `MorphoHeaderIdentitySharedMorpho.t.sol:19`, `MorphoHeaderIdentityFork.t.sol:14` and `MorphoHeaderIdentityE2E.t.sol:26`, since the selector references moved to `BaseMorphoLoanHook`.

---

## Design decision: duplication of the pin across the two bases

`_marketKey`, `_requireHeaderIsMarketKey` and `MARKET_KEY_MISMATCH` are duplicated between `BaseMorphoLoanHook` and `BaseMorphoLoanHookV2`. **Recommendation: keep as is.**

A shared free function would compile in both trees, so the `using X for T` non-inheritance constraint is not the real blocker. The actual reasons:

1. The **error** cannot move cheaply. The two declarations share a selector, and roughly 15 `vm.expectRevert(X.MARKET_KEY_MISMATCH.selector)` sites name them explicitly. A file-level error rewrites all of them for zero functional gain.
2. Extracting `_marketKey` from `BaseMorphoLoanHook` changes the inherited-internal set of `MorphoLendHook` and `MorphoWithdrawHook`, which are currently byte-identical to `dev`. Refactoring buys four lines and costs two extra CREATE2 address moves.

The genuine risk of duplication is drift from `computeMarketKey`, which is a test problem and is addressed by P3-7.

---

## Verification performed

- Full read of all 11 leaves and 3 bases; mechanical old-versus-new diff of every guard, target, spender, callback argument and inspect payload against `git show HEAD:`.
- Repo-wide sweep of `extractYieldSource()` consumers. The only cross-hook reader is `SuperExecutorBase._updateAccounting:194`, inside the `INFLOW || OUTFLOW` branch. All 11 loan hooks inherit NONACCOUNTING from `BaseLoanHook:29` and none reassigns, so offset 32 has zero on-chain consumers for them.
- Confirmed no calldata layout constant, decode offset or slice boundary moved.
- `forge test --match-path "test/unit/hooks/loan/*.t.sol"` → **648 passed, 0 failed**.
- Creation bytecode equality across `out/`, `script/generated-bytecode/` and `script/locked-bytecode/` for all 13 hooks → all match. The `MorphoLendHook` generated-bytecode diff is confined to `sourceMap` and metadata (inherited NatSpec text); the verifier compares `vm.getCode` output only, so the locked CREATE2 addresses hold.

---

## Follow-ups

**Before merge (recommended, not blocking):** P3-1 (pin the struct you use), P3-2 (preExecute negatives for repay and close V2), P3-5 (vacuous assertion), P3-6 (assert the first 20 bytes).

**Before deploy:** P3-4 — add the post-deploy singleton assertion to the deploy script and update the release checklist's canonical-singleton item to state that it is now the only guard.

**Documentation and tickets:** P3-3 (document the inspect echo convention at the interface), P3-9 and P3-10 (hygiene). SUP-21038 and SUP-21026 text still says "yieldSource = the Morpho singleton". SUP-21025's leaf builder now needs one key-first encoding for all 13 hooks, and the bundler must pack `computeMarketKey(MarketParams)` at offset 32 for every Morpho hook.

**Coverage gap, likely by design:** the real-proof strategy authorization regression covers only lend and withdraw. The 11 loan hooks have no equivalent. That is consistent with the borrower family being validated through raw-calldata leaves rather than the inspect-based strategy path, but it should be a conscious decision rather than an omission.
