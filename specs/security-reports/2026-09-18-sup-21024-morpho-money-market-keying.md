# Security Analysis Report

## Metadata
- **Target:** PR #1010 — SUP-21024 "MorphoLend/Withdraw as MONEY_MARKET with per-market ledger keying" (`feat/sup-21024-morpho-lend-withdraw-money-market` @ `e9602466`, base `dev` @ `c4480ce4`)
- **Mode:** review
- **Date:** 2026-09-18
- **Contract Types Detected:** lending-market integration hooks (stateless, ERC-7579 executor context); vault-style share accounting via SuperLedger + registry-resolved yield-source oracle
- **Files Analyzed:** 5 source files (`BaseMorphoMoneyMarketHook.sol` new, `MorphoLendHook.sol`, `MorphoWithdrawHook.sol`, `MorphoRepayHook.sol`, `MorphoRepayAndWithdrawHook.sol`) + 9 test files as evidence; context read: `BaseHook`, `BaseLoanHook`, `BaseMorphoLoanHook`, `SuperExecutorBase`, `BaseLedger`/`SuperLedger`, `MorphoBlueYieldSourceOracle`, `MorphoBlueMarketRegistry`, `HookDataDecoder`, `IMorpho`, `SharesMathLib`
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (36 sections, 300+ patterns, 175+ exploits) + `coding-rules.md`; external: evmresearch.io (439-note sitemap), Morpho Blue source, OWASP SC Top 10 (2025)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 0 security · 1 external-review interoperability (F1, fixed) · 3 code-quality/gas (fixed) · 2 operational advisories | No |
| P3 Low | 5 | No |

## Verdict
**PASS** — No P0 or P1 findings. Safe to proceed. The design's primary control — header market key recomputed from the body and pinned on every `build` **and** `preExecute` path, with the Morpho singleton fixed as the `morpho` immutable — holds; no calldata-derived address is ever a call target or approve spender in the two money-market hooks, and the executor/ledger/oracle chain fails closed for unregistered markets.

## Focus-area closure (requested in the review brief)

| # | Question | Result | Evidence |
|---|---|---|---|
| 1 | Can a crafted header/body desynchronise the ledger key from the market acted on? | **No.** `build` and `_preExecute` both derive `MarketParams` from the body and assert `header@32 == uint160(id(body))`; `_postExecute` reads the body-derived position only; the executor passes one `hookData` to build/pre/post/`_updateAccounting`. Key derivation is byte-identical to `MorphoBlueMarketRegistry.computeMarketKey`. A zero/garbage `lltv` produces an unregistered key → `MARKET_NOT_REGISTERED` at accounting and `MARKET_NOT_CREATED` at Morpho — atomic revert either way. | `MorphoLendHook.sol:93-96,187-190`, `MorphoWithdrawHook.sol:116-117,203-204`, `BaseMorphoMoneyMarketHook.sol:76-87`, `SuperExecutorBase.sol:309,330,193-194`, `MorphoBlueMarketRegistry.sol:303-304` |
| 2 | INFLOW accounting correctness | **Correct.** `outAmount` = position after − before inside the executor's `nonReentrant` `_processHook`; Morpho fee-share accrual credits `feeRecipient`, not the account, so the delta equals shares supplied exactly. `usePrevHookAmount` is resolved at build time after the previous hook's fee-adjusted output is final and baked into calldata. | `MorphoLendHook.sol:98-100,192,199`, `SuperExecutorBase.sol:231` |
| 3 | OUTFLOW accounting + fee | **Correct**, one bounded dust effect (P3-1). `usedShares` = before − after cannot underflow (position only decreases via the account's own withdraw). By-assets and by-shares both record actual burned shares and actual assets. Fee bounded by `feeAmount ≤ outAmount` and `feePercent ≤ 50%`; ledger caps `usedShares` to the tracked accumulator. Zero-position / over-withdraw revert inside Morpho → nothing posted. | `MorphoWithdrawHook.sol:205-216`, `SuperExecutorBase.sol:216`, `BaseLedger.sol:84-89,198-222`, `SuperLedgerConfiguration.sol:43` |
| 4 | New call-target / approve-spender surface | **None.** Lend: approve spender = `morpho` immutable, supply target = `morpho`; Withdraw: target = `morpho` only. Header offset 32 is compared, never called. `loanToken` is an approve *target* (same as every ERC-4626 hook) and is bound to a registered market by the key pin + oracle resolution. Repay hooks target `vars.yieldSource` only after `_requireYieldSourceIsMorpho`; the changed `accrueInterest` call is behind that pin. | `MorphoLendHook.sol:106-120`, `MorphoWithdrawHook.sol:123`, `MorphoRepayHook.sol:188-191`, `MorphoRepayAndWithdrawHook.sol:266-269` |
| 5 | Reentrancy via Morpho callbacks | **Safe.** `supply` passes `""`; `withdraw` has no callback; Morpho only calls `onMorphoSupply` when `data.length > 0` and on `msg.sender` (the account). Position reads happen in separate account→hook calls after the Morpho call returns; `_processHook` is `nonReentrant`. Pinned by `test_MorphoCallbackDataAlwaysEmpty`. | `MorphoLendHook.sol:116`, `BaseHook.sol:187,196`, Morpho `Morpho.sol` |
| 6 | `hookType` reassignment safety | **Safe.** Storage on `BaseHook`, written only by the two constructors, read only at execution time by `SuperExecutorBase._updateAccounting:190`; nothing caches it. Sibling LOAN hooks stay NONACCOUNTING (`test_E2E_LoanHooks_StayNonAccounting`). | `BaseHook.sol:83,129`, `BaseMorphoMoneyMarketHook.sol:65` |
| 7 | Fail-closed allowlist | **Holds.** Accounting runs unconditionally for INFLOW/OUTFLOW; `decimals()` and `getPricePerShare()` both resolve through `getMarketInfo`, which reverts for unregistered keys. Pinned by `test_E2E_Lend_RevertIf_MarketNotRegistered` and `test_E2E_Lend_RevertIf_HeaderKeyIsAnotherMarket`. | `SuperExecutorBase.sol:190-211`, `MorphoBlueYieldSourceOracle.sol:103,227`, `MorphoBlueMarketRegistry.sol:262` |

## External review finding (Nicola, PR #1010 review — addressed in this pass)

### [F1-P2] `inspect()` must start with the market key (the header yield source), not the singleton
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol` / `MorphoWithdrawHook.sol` (`inspect`)
- **Category:** Interoperability / Merkle authorization
- **Description:** `SuperVaultStrategy._validateHook` passes the hook's raw `inspect()` bytes to `SuperVaultAggregator._createLeaf` (`keccak256(bytes.concat(keccak256(abi.encode(hook, args))))`). A SUP-21025 leaf encodes the market key as the first inspected address; the PR encoded the singleton, so compliant off-chain leaves could never validate on-chain (deterministic acceptance failure; no theft path — the build/preExecute key pin still holds).
- **Fix applied:** both hooks now return `abi.encodePacked(marketKey, loan, collateral, oracle, irm, lltv)` (132 bytes, `pure`); NatSpec updated; unit + shared-Morpho + two-market fork expectations flipped to key-first; new regression `test_MoneyMarket_Inspect_KeyFirst_AggregatorLeafParity` (unit) and leaf-parity asserts in the fork suite compute the leaf with the aggregator's exact formula from the SUP-21025 encoding and from `inspect()` and assert equality (and that a singleton-first encoding yields a different leaf), plus header-key sensitivity, per-MarketParams-field sensitivity and amount invariance. Lend/Withdraw re-locked. **Real-proof strategy regression** `test/integration/morpho/MorphoLendStrategyProofFork.t.sol` (mainnet fork, real deployed SuperUSDC strategy + aggregator, no `validateHook` mock): a two-leaf tree built off-hook from the SUP-21025 encoding is proposed by the strategy's real main manager, executed after the real timelock, and lend + withdraw run through `executeHooks` with real sibling proofs; a singleton-first root is rejected by `validateHook` and the strategy reverts; header-key / lltv changes break the proof while amount-only changes stay authorized.

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

Security: none found.

### [P2-Q1] `MorphoWithdrawHook._decodeWithdrawData` copies calldata to memory nine times per decode
- **File:** `src/hooks/loan/morpho/MorphoWithdrawHook.sol:222-233`
- **SWC:** N/A · **Category:** Gas
- **Description:** The decoder takes `bytes calldata` but every callee (`_requireOracleId`, `extractYieldSource`, 4× `BytesLib.toAddress`, 3× `BytesLib.toUint256`) takes `bytes memory`, so each call copies the 228-byte payload — on all four call paths (build, inspect, preExecute, postExecute). `MorphoLendHook._decodeLendHookData` and both base decoders already take `memory` (one copy).
- **Secure Pattern:** `function _decodeWithdrawData(bytes memory data) internal pure returns (WithdrawHookVars memory vars)`; callers keep passing `calldata`.
- **Reference:** coding-rules "thorough gas optimization"; vulnerabilities.md §13

### [P2-Q2] `_postExecute` re-decodes and re-reads the loan token (both money-market hooks)
- **File:** `src/hooks/loan/morpho/MorphoWithdrawHook.sol:213-217`; `src/hooks/loan/morpho/MorphoLendHook.sol:198-212`
- **Category:** Gas
- **Description:** Withdraw `_postExecute` calls `getLoanTokenBalance(account, data)`, `getLoanTokenAddress(data)` and `_decodeWithdrawData(data)` — three copies/reads plus a full re-validation the executor already ran in `_preExecute` on identical calldata. Lend `_postExecute` goes through the `_getSupplyShares(address, bytes)` wrapper (second full decode) and then `getLoanTokenAddress(data)` (third read of offset 52).
- **Secure Pattern:** decode once, reuse `vars.marketParams.loanToken` / `vars.loanToken` for balance, outToken and position; delete the `_getSupplyShares(address, bytes)` wrapper.
- **Reference:** vulnerabilities.md §13, §15.4

### [P2-Q3] `BaseMorphoLoanHook` contract NatSpec now misdescribes the money-market leaves
- **File:** `src/hooks/loan/morpho/BaseMorphoLoanHook.sol:18-25`
- **Category:** Documentation (security-assumption text)
- **Description:** The paragraph labelled as the family's security invariant says offset 32 is "the Morpho Blue singleton — the call target", that "every child pins it via `_requireYieldSourceIsMorpho`", and that this "applies to the whole V1 family — lend/withdraw and the borrower leaves alike". After this PR `MorphoLendHook`/`MorphoWithdrawHook` carry the registry market key at offset 32, never call `_requireYieldSourceIsMorpho`, and target the immutable — contradicting `BaseMorphoMoneyMarketHook.sol:23-34`.
- **Secure Pattern:** scope the paragraph to the borrower leaves and point to `BaseMorphoMoneyMarketHook` for the money-market deviation. Comment-only change; `bytecode_hash = "none"` makes it byte-neutral for the five borrower hooks.
- **Reference:** coding-rules "Maintain up-to-date API documentation"; vulnerabilities.md §36

### Operational advisories (P2, outside the PR's code but created by the design)
- **[OPS-1] Registry curation is the supply-side safety boundary.** `registerMarket` gates the IRM but accepts any `oracle_`, `collateralToken_`, `lltv_` and `morpho_`. A mis-scaled market oracle (Morpho PAXG/USDC, Oct 2024, $230K) or a looped/peg-dependent collateral (Stream xUSD, Nov 2025) socialises bad debt onto suppliers, and the yield-source oracle will faithfully report the reduced pps. Recommend a registration checklist (oracle scale factor vs token decimals, collateral liquidity, `morpho_` == canonical singleton) and, cheaply, an on-chain `morpho_` allowlist. (OWASP SC01/SC02)
- **[OPS-2] Deregistration bricks OUTFLOW accounting for tracked positions.** `executeDeregisterMarket` → `getMarketInfo` reverts → `getPricePerShare` reverts → `_updateAccounting` reverts → withdraws through Superform fail until re-registration. The 2-day timelock is documented; consider gating execution on "no tracked balance" (`getTVLByOwnerOfShares == 0` for tracked accounts) rather than process alone. (OWASP SC10)

## P3 Findings (Low - Consider Fixing)

### [P3-1] Phantom "profit" fee on zero-accrual withdraw (pps integer truncation)
- **File:** `src/accounting/BaseLedger.sol:141,242-246`, surfaced by `MorphoWithdrawHook.sol:213-217`
- **SWC:** SWC-101 class (rounding) · **Category:** Arithmetic / share accounting
- **Description:** INFLOW stores `costBasis = ⌊s·pps/10^(d+6)⌋` with `pps` rounded down; a same-rate withdraw returns `⌊s·(T+1)/(S+1e6)⌋`, so `costBasis ≤ received` and the "profit" can be strictly positive with zero accrual. Bound: `< s/10^(d+6) + 1 wei ≈ (A in whole tokens) wei` — 10k USDC → < 10,001 wei (0.01 USDC) of phantom profit, ≤ 0.0025 USDC fee at the 25% initial max. Same class and magnitude as the existing ERC-4626 path; already documented (`MorphoLendIntegrationTest.t.sol:71-73`) and pinned (`test_E2E_PartialWithdrawByAssets_UsedSharesIsPositionDiff_DustFeeOnly`). Favours the protocol by wei; not exploitable.
- **Secure Pattern:** none required; optional NatSpec note on `MorphoWithdrawHook`.
- **Reference:** vulnerabilities.md §3.3, §22.3

### [P3-2] `MorphoLendHook` publishes a mistyped pipe pair — `outToken` = loan token while `outAmount` = Morpho supply shares
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:198-201`
- **Category:** Logic / chaining contract
- **Description:** A downstream TRANSFORM hook consuming `(getOutToken, getOutAmount)` via `usePrevHookAmount` would act on ≈1e6× assets of loan token. Pre-dates the PR (the WARNING at lines 36-39 covers it), but the PR makes the hook a first-class INFLOW that the OMS sizes like an ERC-4626 deposit, so the mismatch is easier to hit by composition. No third-party exploit; the chain is user-signed.
- **Secure Pattern:** publish a non-ERC-20 identity as `outToken` (the header market key — mirrors `ApproveAndDeposit4626VaultHook`, fails the strict PREV token check in `BaseLoanHookV2`/Aerodrome, and is not misread as native by `FeeSplittingHook`) and advertise `amountRoles` = IN/ASSETS. **This is exactly SUP-21005 (stacked on this PR, implemented and stashed).**
- **Reference:** vulnerabilities.md §14.3

### [P3-3] `hookType` is mutable storage on `BaseHook` by design
- **File:** `src/hooks/BaseHook.sol:83`; reassigned at `BaseMorphoMoneyMarketHook.sol:65`
- **Category:** Code hygiene
- **Description:** No setter exists and only two constructors write it, but the design relies on it not being `immutable`. Long-term, threading the type through `BaseLoanHook`'s constructor would remove the reliance — out of scope here because it changes every legacy loan hook's bytecode.
- **Reference:** vulnerabilities.md §36

### [P3-4] 160-bit truncation: a colliding *unregistered* market would pass the header pin under a registered key
- **File:** `src/hooks/loan/morpho/BaseMorphoMoneyMarketHook.sol:76-87`; `MorphoBlueMarketRegistry.sol:303-304`
- **Category:** Logic / identifier collision
- **Description:** Second-preimage against a fixed registered key costs 2^160 (infeasible). A ~2^80 birthday pair is theoretically grindable because `loanToken`/`collateralToken`/`oracle` are free CREATE2-able inputs, and while the registry refuses to register the second market, `_requireHeaderIsMarketKey` would accept the colliding unregistered market B under A's key, ledgering B's shares with A's pps. Only the user acting on their own position can do this; outcome is self-inflicted fee mis-pricing, never third-party loss.
- **Secure Pattern:** document in the registry NatSpec; if a full-identity check is wanted later, expose `marketId(key)` from the oracle/registry and compare the 32-byte `Id` (design change — flag to Ronny, not for this PR).
- **Reference:** a16z auction-zoo issue #2; vulnerabilities.md §9

### [P3-5] Oracle-id substitution at header offset 0 (checked non-zero only)
- **File:** `src/hooks/loan/morpho/BaseMorphoMoneyMarketHook.sol:107-109`
- **Category:** Logic
- **Description:** The ledger key is a codeless pseudo-address, so every non-Morpho oracle in `src/accounting/oracles/` reverts on it (empty returndata on a high-level call). The one registry-backed resolver that would not revert is `MorphoBlueDebtOracle`. Reviewer should confirm the debt-oracle config id points at a different `ledger` than the supply-oracle id so the two cannot share accumulators. Worst case is fee under-collection on the user's own position (same class as the documented legacy-hook bypass).
- **Reference:** vulnerabilities.md §36

## Attack Surface Summary
- **External Entry Points:** `build`, `preExecute`, `postExecute` (account-gated: `msg.sender == account`), `inspect`, `amountRoles`/`decodeAmounts`/`replaceCalldataAmounts` (pure), `setExecutionContext` (open; executor checks `lastCaller`), `setOutAmount` (blocked while pre/post mutexes are set).
- **Value Transfer Points:** `IERC20.approve(morpho, amount)` + `IMorphoBase.supply(params, amount, 0, account, "")` (lend); `IMorphoBase.withdraw(params, assets, shares, account, account)` (withdraw); executor-side OUTFLOW fee transfer in `asset()` (loan token).
- **Oracle Dependencies:** `MorphoBlueYieldSourceOracle.getPricePerShare(marketKey)` via `MorphoBlueMarketRegistry.getMarketInfo` (fail-closed); Morpho's own market `IOracle` affects suppliers only through bad-debt socialisation (curation, OPS-1).
- **Cross-Contract Interactions:** Morpho Blue singleton (immutable), the loan token (approve target, bound to a registered market), SuperLedger via the unchanged executor.
- **Upgrade Mechanisms:** none (stateless hooks, CREATE2 locked bytecode); `MARKET_MANAGER_ROLE` on the registry is the sole admin surface that influences these hooks.

## Coding Standards Findings
- P2-Q1, P2-Q2, P2-Q3 above.
- **P3 nits (grouped):** unused `IMorphoStaticTyping`/`MarketParamsLib` import + dead `using MarketParamsLib for MarketParams;` in `MorphoLendHook.sol:8-9,41`; stale legacy byte counts in `BaseMorphoLoanHook.sol` comments (146/178/145 vs constants 198/230/197; "shared across all Morpho hooks" no longer true for the withdraw layout); "MONEY_MARKET" reads like a `HookSubTypes` constant but `SUB_TYPE` stays `HookSubTypes.LOAN` — reword or add the subtype (author's call); `LendHookLocalVars` stores five raw fields and rebuilds `MarketParams` at four sites whereas `WithdrawHookVars` stores the struct — align; `@inheritdoc BaseHook` for `_preExecute`/`_postExecute` and `@dev` for internals per house style; `decodeUsePrevHookAmount` override lacks `@inheritdoc`; optional `if ((assets == 0) == (shares == 0)) revert` for the XOR.
- **Checked, no finding:** custom errors everywhere; visibility and `pure`/`view` correct (the `inspect` pure→view change is required because it reads the `morpho` immutable); import grouping; no `@N` doc tags; no events needed (transient-only state, `hookType` written once); the `IMorpho(vars.yieldSource).accrueInterest` change in both repay hooks is semantically identical after the pin and consistent with the rest of those builders.

## Recommended tests (from the review)
- [ ] Ordering / transient-isolation: one userOp `Lend(A) → Lend(B) → Withdraw(A)` on one account, and a bundle of two accounts alternating — each posted INFLOW/OUTFLOW equals the on-chain position delta. (`usedShares`/`asset` are `transient` on `BaseHook`, set-before-read on every path; the test pins that invariant against refactors.)
- [ ] Callback-data invariant: decode the built `supply`/`repay` calldata and assert the trailing `bytes` is empty for every Morpho hook (lend + repay V1/V2). `test_MorphoCallbackDataAlwaysEmpty` covers lend + repay V2; extend to V1 repay hooks.
- [ ] Donated shares: third-party `supply(onBehalf = account)` then Superform withdraw — fee only on the tracked accumulator (ledger cap path), never on the untracked excess.
- [ ] Zero-accrual round trip across 6/8/18-decimal loan tokens and a near-empty market: `feeAmount` is dust-bounded (≤ (A in whole tokens) wei × feePercent).
- [ ] Differential pps: `oracle.getPricePerShare` vs `MorphoBalancesLib.expectedSupplyAssets`-derived pps after warps of 1 s / 30 d / 400 d (the 365-day cap and `feeAmount ≥ totalSupplyAssets` guard are the only deliberate deviations).

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 3.3, 9, 10, 13, 14.3, 15.4, 22.3, 28, 36
- **evmresearch.io patterns checked:** ERC-4337 multi-UserOperation transient cleanup; transient storage composability; hidden ERC callbacks reentrancy; SushiSwap RouteProcessor2; low-decimal vault inflation; rounding amplification (zkLend); parallel-path rounding inconsistency (KyberSwap/Bunni/Balancer V2); `abi.encodePacked` short-type concatenation; utilization depositor-trapping; OWASP SC Top 10 2025/2026
- **External incidents cross-referenced:** Morpho PAXG/USDC oracle scale (Oct 2024), Stream/xUSD contagion (Nov 2025), Morpho App Bundler3 approvals (Apr 2025), SIR.trading transient misuse (Mar 2025), Cream/Resupply donation inflation, Balancer V2 (Nov 2025)
- **Coding rules validated:** NatSpec, custom errors, visibility/mutability, import grouping, events, gas §13, dead code §15.4, pre-PR checklist §36
