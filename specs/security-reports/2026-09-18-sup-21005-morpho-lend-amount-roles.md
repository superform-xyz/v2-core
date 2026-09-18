# Security Analysis Report

## Metadata
- **Target:** uncommitted SUP-21005 changes on `feat/sup-21005-morpho-lend-amount-roles-assets` (base `15b8ff93`, PR #1010 head) — "Publish MorphoLend amountRoles as ASSETS in; keep share-delta outAmount; outToken = market key"
- **Mode:** review
- **Date:** 2026-09-18
- **Contract Types Detected:** lending-market integration hook (stateless, ERC-7579 executor context); off-chain OMS sizing metadata
- **Files Analyzed:** 1 source (`src/hooks/loan/morpho/MorphoLendHook.sol`), tooling (`tooling/hook-enrichment.yaml`, `manifests/hooks.json`), 6 test files; context read: `BaseHook`, `BaseLoanHook`, `BaseMorphoMoneyMarketHook`, `BaseLoanHookV2`, `SuperExecutorBase`, `ISuperHook`, `MorphoBlueMarketRegistry`, every `getOutToken` / `getOutAmount(prev)` consumer in `src/`, `generate_hook_manifest.py`, `lint_hook_manifest.py`, `generate-hook-sizing-manifest.ts`
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` + `coding-rules.md`; external: evmresearch.io, Sherlock/Tokemak/DODO/xKeeper judgings, SIR.trading post-mortems, OZ Address/SafeERC20, ERC-4337 spec

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 0 security · 1 tooling/process (manifest ↔ on-chain `amountMeta` has no conformance guard) | No |
| P3 Low | 4 | No |

## Verdict
**PASS** — No P0 or P1 findings. The change is fail-closed at every point where a downstream hook consumes the lend hook's output: strict-equality consumers (`BaseLoanHookV2`, Aerodrome) now revert instead of silently accepting share wei as loan-token amounts; PASSTHROUGH hooks forward unchanged; `FeeSplittingHook` no longer subtracts loan-token fee legs from a share count; the executor never reads `outToken`; nothing on-chain branches on `Denomination`. The `outToken` value is exactly the header market key the executor posted the ledger against (same bytes, pinned on build + preExecute), and it cannot be set by a third party.

## Change under review
- `MorphoLendHook.amountRoles()` → leaf override returning `[IN, ASSETS]` (was inherited `[IN, TOKEN]`); `decodeAmounts` / `replaceCalldataAmounts` untouched (offset 132, one slot, bounded).
- `MorphoLendHook._postExecute` → `_setOutToken(vars.marketKey, account)` (header registry market key, codeless pseudo-address) instead of the loan token; `outAmount` stays the Morpho supply-share delta.
- `tooling/hook-enrichment.yaml` `amountMeta` override + regenerated `manifests/hooks.json` (`TOKEN → ASSETS`); NatSpec; tests.

## Consumer matrix (prev `outToken` = market key, prev `outAmount` = supply-share delta)

| Consumer | Before (`outToken` = loan token) | After (`outToken` = market key) | Verdict |
|---|---|---|---|
| `BaseLoanHookV2._resolvePrevHookOutput` (all V2 Morpho/Aave hooks) | token check passed; share count used as loan-token amount (repay only "worked" because it caps at debt) | `PREV_TOKEN_MISMATCH` at build — pinned by unit + E2E tests | fail-closed, strictly better |
| `BaseAerodromeUniversalRouterHook._scaleFromPreviousHook` | passed when `inputToken == loanToken`; `amountIn` = share count | `PREV_HOOK_TOKEN_MISMATCH` | fail-closed, strictly better |
| `FeeSplittingHook` (PASSTHROUGH override) | loan-token fee legs were subtracted from the **share count** (unit mismatch) | `_expectedKey(nonce, marketKey)` = 0 → nothing subtracted, forwards unchanged; no call on the key | forwards; old unit bug gone |
| `BaseHook` PASSTHROUGH forwarding (ApproveERC20, MarkRootAsUsed, 7540 Set*/Cancel*, Pendle Record*, …) | forwards `(loanToken, shares)` | forwards `(marketKey, shares)` | unchanged |
| `usePrevHookAmount` consumers with no token check (4626/5115/7540 deposits, Transfer/Approve, bridges, swaps, V1 loan hooks, stake hooks) | share count used as an amount of their own configured token | identical — `outAmount` unchanged by this PR | pre-existing (P3-1) |

No consumer in `src/` uses a predecessor's `outToken` as an `Execution.target` or performs a high-level call on it; a high-level call on the codeless key would revert on the extcodesize check.

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

Security: none found.

### [P2-T1] No guard that `manifests/hooks.json` `amountMeta` matches on-chain `amountRoles()`
- **File:** `tooling/generate_hook_manifest.py:198-202`, `tooling/lint_hook_manifest.py` (no `amountMeta` rule), `tooling/generate-hook-sizing-manifest.ts:166-168` (comment claims denomination is "derived from on-chain amountRoles()" — it is not)
- **Category:** Tooling / process (SWC N/A)
- **Description:** `amountMeta` is hand-authored in `hook-enrichment.yaml`; every unlisted hook silently defaults to `[IN, TOKEN]`, the lint never compares it with the compiled contract, and no test reads `hooks.json`. This is exactly how SUP-21005's bug arose (contract semantics = ASSETS, manifest said TOKEN), and it can recur for any future override with zero CI signal. Off-chain only — the OMS sizes calldata from the manifest — so no on-chain exploit, but a wrong denomination makes the OMS rewrite offset 132 in the wrong unit.
- **Secure Pattern:** a Foundry conformance test that parses `manifests/hooks.json` (`vm.readFile` + `vm.parseJson`) and, for every hook already instantiated in `test/unit/hooks/HookSizingInterface.t.sol`, asserts `amountMeta` == `hook.amountRoles("")` (length, direction, denomination). Optionally: lint fails when a source file declares `function amountRoles` without an explicit YAML entry. Fix the misleading TS comment.
- **Reference:** vulnerabilities.md §36; OZ storage-layout CI pattern (generated-vs-committed comparison)

## P3 Findings (Low - Consider Fixing)

### [P3-1] Pre-existing: share-denominated `outAmount` consumed by token-denominated `usePrevHookAmount` hooks without a token check
- **File:** producer `MorphoLendHook.sol` (`_postExecute`); consumers e.g. `ApproveAndDeposit4626VaultHook.sol:76-78`, `TransferERC20Hook.sol:65-67`
- **Category:** Logic / unit mismatch (§14.3, §22)
- **Description:** Morpho `VIRTUAL_SHARES = 1e6`, so a fresh market mints ≈ assets × 1e6 shares; an amount-only consumer would interpret that as a ~1e6× token amount. Unchanged by this PR (`outAmount` semantics are the same); the PR moves the producer to the correct side of the strict token check (`BaseLoanHookV2` shape). No third-party exploit — the chain is signed by the account owner/strategist; practical outcome is a revert on balance/allowance or an oversized approval if mis-chained. NatSpec WARNING documents it.
- **Secure Pattern (follow-up, out of scope):** add the `getOutToken == expectedToken` (or `outToken.code.length != 0`) guard to the legacy amount-only consumers; bundler chain validation should treat an INFLOW hook's `outToken` as non-addressable.

### [P3-2] Intended behaviour change: chains that relied on the accidental `outToken == loanToken` now revert
- **File:** `BaseLoanHookV2.sol:145`, `BaseAerodromeUniversalRouterHook.sol:426`
- **Description:** `Lend → {RepayV2, BorrowV2, RepayAndWithdrawV2, Aerodrome}(usePrevHookAmount)` previously passed the token check with a share count; now `PREV_TOKEN_MISMATCH` / `PREV_HOOK_TOKEN_MISMATCH`. Desired and tested. Flagged so the bundler/OMS strategy catalogue is checked for any live chain of this shape before publishing the new lend address.

### [P3-3] No on-chain discriminator between "outToken is an ERC-20" and "outToken is a ledger key"
- **File:** `src/interfaces/ISuperHook.sol` (`ISuperHookResult`)
- **Description:** The token slot is now overloaded (ERC-20 for most hooks, synthetic key for money-market lend — the same overload the ERC-4626 deposit hooks already use with the vault address, except the vault has code). Strict-equality consumers are safe because a keccak-derived key never equals a real token, but nothing lets a generic consumer tell the two apart. Design note for a later `getOutKind()`-style field; no change here.

### [P3-4] Test/doc hygiene (grouped, from the coding-standards pass) — **applied** (NatSpec deduped/reworded, `AMOUNT_NOT_VALID` selector, `A_LLTV`/`ADAPTIVE_CURVE_IRM` constants, `_execEntry` removed, `_v2Full` single V2 layout, pure-meta asserts trimmed from the fork suites; `MorphoLendHook` bytecode verified byte-neutral)
- NatSpec duplicated three ways in `MorphoLendHook.sol` (contract `@dev` OMS-sizing + WARNING paragraphs vs `amountRoles` `@dev` vs `_postExecute` `@dev`); the WARNING still opens with "Unlike ERC-4626 vault shares" while two lines later saying it mirrors the 4626 deposit hooks — reword; "offset 132" hard-coded in docs (it is `BaseLoanHook.AMOUNT_POSITION`).
- `MorphoHooksOutputSemanticsFork.t.sol`: bare `vm.expectRevert()` for the withdraw XOR (use `BaseHook.AMOUNT_NOT_VALID.selector`); inline `860_000_000_000_000_000` for market A while B uses a named constant.
- `MorphoHeaderIdentityE2E.t.sol`: `_execEntry` duplicates `_execEntryFor(instanceOnEth, …)`; `_v2mPrev` re-spells the 230-byte V2 layout instead of parameterising `_v2` with `usePrev`.
- The pure `amountRoles("")` triple-assert is repeated in five suites; the fork copies add no coverage over the unit one (`HookSizingInterface` is the designated per-hook sizing check). `assertTrue(_key(A) != _key(B))` inside a sizing test is unrelated.
- Pre-existing `forge fmt` drift in `HookSizingInterface.t.sol` / `MorphoLoanHooks.t.sol` outside the changed hunks — leave alone.

## Attack Surface Summary
- **External Entry Points:** unchanged (`build` / `preExecute` / `postExecute` account-gated; `amountRoles` / `decodeAmounts` / `replaceCalldataAmounts` pure; `inspect` pure).
- **Value Transfer Points:** unchanged (approve `morpho`, `supply` to `morpho`).
- **Oracle Dependencies:** unchanged.
- **Cross-Contract Interactions:** no new calls; `outToken` is never dereferenced on-chain.
- **Upgrade Mechanisms:** none; `MorphoLendHook` bytecode changes → new CREATE2 address (same deploy cycle as #1010).

## Coding Standards Findings
- P2-T1 and P3-4 above.
- **Checked, no finding:** `amountRoles` is `external pure override` with a valid `@inheritdoc`; import list minimal (`ISuperHookInflowOutflow` added and used); `_postExecute` decodes once and reuses the pinned `marketKey`; `replaceCalldataAmounts` stays bounded (`amounts.length == 1`, checked `bytes` indexing cannot reach header/market fields); YAML no longer mentions TOKEN for lend; manifest diff limited to the one denomination field; `forge fmt` clean on the source and the new fork suite.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 10, 14.3, 22, 23.7, 25.2, 29.4, 36
- **evmresearch.io patterns checked:** ABI values not self-describing (shares vs assets), ERC-20-vs-native double-spend sentinels, transient-storage composability, ERC-4337 bundle transient cleanup
- **External incidents cross-referenced:** Sherlock Tokemak #465 (shares fed to asset conversion), DODO #726 / xKeeper #172 (native sentinel confusion), SIR.trading Mar 2025 (transient slot reinterpretation), OZ `Address.verifyCallResultFromTarget` / SafeERC20 v5.1 no-code semantics
- **Coding rules validated:** NatSpec, mutability/visibility, imports, gas, test hygiene, §36 checklist
