# Security Analysis Report

## Metadata
- **Target:** `src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol`
- **Mode:** implementation self-review against the design spec (`specs/liquidmesh-swap-hook/`)
- **Date:** 2026-10-12
- **Linear:** SUP-21203
- **Contract Types Detected:** AMM/DEX aggregator swap hook (opaque calldata)
- **Files Analyzed:** 1 contract, 1 mock, 2 test suites, deploy/verify wiring
- **Dependencies Reviewed:** BaseHook.sol, SwapCalldataLayout.sol, ISuperHookSwap.sol, the LiquidMesh router on BSC (on-chain only; source unverified)

## Summary
| Severity | Count | Status |
|----------|-------|--------|
| P0 Critical | 0 | N/A |
| P1 High | 1 | Fixed (constant corrected, still needs live confirmation) |
| P2 Medium | 3 | 3 fixed |
| P3 Low | 3 | Documented / accepted |

## Verdict
**PASS** — the contract is safe to merge and deploy. The router was confirmed on-chain by us on
2026-10-12 (see P1-1 below); the live `/swap` capture remains a runbook check whenever API credentials
are available (the E2E test asserts API `to` == pinned router).

### Resolution Summary
- **P1-1**: Router constant switched from the generic Binance dispatcher `0xb300…028d` to the
  LiquidMesh diamond `0xB444…DA5`; live E2E now asserts the API `to` equals the pinned router.
- **P2-1**: Short-data and selector-less `txData` rejected (`INVALID_HOOK_DATA`) — closes the
  `BytesLib` over-read and the diamond-fallback path.
- **P2-2**: `MAX_INPUT_AMOUNT = 10_000_000e18` (10M USDT) set as a fat-finger guard; pinned by test.
- **P2-3**: `inspect()` changed to `abi.encodePacked(inputToken, outputToken)` (40 bytes) so the
  existing periphery root generator can emit it; `BinanceLeafCommitment.t.sol` proves the match.
- **Tests**: 54 unit (incl. USDT-style and sticky-approve tokens, donation-between-pre/post) +
  11 leaf-commitment + 5 stateful invariants (128k randomised router calls, zero violations) +
  1 sizing-interface assertion + 10 BSC fork tests (5 harness on real USD1/bStock bytecode, 5 through
  a real ERC-7579 account + SuperExecutor via UserOp, proving batch atomicity on every failure path)
  all pass; 1 live LiquidMesh test skips without API credentials.
- **Input token facts (corrected by review)**: Binance-Peg USDT `0x55d3…7955` is a plain, non-proxy
  BEP20 with owner `mint`/`burn` only — no pause, blacklist or freeze. The "frozen input token" scenario
  from the USD1-era research is vacuous for the real input. The bStock side is a beacon proxy with
  `pauseManager()` / `isTokenPaused(address)` and `compliance()` / `checkIsCompliant(from,to)`; a
  transfer revert there fails the batch at the router call.

## Independent review round (2026-10-12, three parallel reviewers)

### R-P2-1 — Cap was per execution, not per transaction
**Status:** Fixed

A leaf `(hook, USDT, bStock)` carries no amount. Both production paths (`SuperVaultStrategy.executeHooks`
and `SuperExecutorBase._execute`) loop over hook entries and re-validate the same leaf each time, so a
compromised key could repeat the leaf N times in one batch and spend N × cap while every per-execution
check passed (reviewer PoC: 5 × cap in one tx). The natspec claim "loss-per-tx finite" was false.

Fix: a per-account transient accumulator (`txSpent`) in `_preExecute` sums header `inputAmount`s for the
transaction and reverts `INPUT_EXCEEDS_CAP` when the sum would exceed `MAX_INPUT_AMOUNT`, before any
approval is granted. Covered by `test_TxCap_*` (unit) and `test_Executor_RepeatedLeaf*` (fork UserOp:
two 6M entries against a 10M cap revert atomically; two 5M entries succeed).

Note on the cap's meaning: 10M USDT per transaction is a fat-finger guard chosen by the pod. Under a
compromised key it is also the loss bound per transaction, and nothing bounds the number of
transactions; that residual is accepted under the full-trust OMS key model, same as the Kyber/Odos
hooks.

### R-P3-1 — RFQ-leg allowance must not point at the diamond
**Status:** Documented (deploy-time invariant)

The RFQ leg uses `ApproveERC20Hook` + a leaf committing `(token, spender)`. If that spender were the
LiquidMesh diamond: on USDT this hook's `approve(0)` would wipe the RFQ allowance every run (DoS), and on
a bStock any USDT→X blob could pull the approved bStock through the diamond. The RFQ spender must be
recorded in the spec once known and must not be `BINANCE_DEX_ROUTER_BNB`.

### R-P3-2 — Production path is `SuperVaultStrategy`, not only `SuperExecutor`
**Status:** Documented

`SuperVaultStrategy._processSingleHookExecution` calls `build()` directly, executes with raw `.call`,
and never calls `validateHookCompliance`. A router that reenters `hook.setExecutionContext(account)`
mid-batch is stopped by `BaseHook.resetExecutionState`'s `onlyLastCaller`, not by this hook's own
checks. Fails closed in both paths; the attack-surface checklist below names both.

### R-P1 (tests reviewer) — Harness gaps closed
**Status:** Fixed

Reviewer B's 41-mutant campaign found no surviving code mutant but three harness gaps: (1) no test
drove a router facet that re-enters the hook — `MockBinanceRouter` now has `REENTER_SET_CONTEXT` and
`REENTER_SET_OUT_AMOUNT` modes, covered at unit level and through a real account + `SuperExecutor`
UserOp (`SNAPSHOT_NOT_TAKEN` / `CANNOT_SET_OUT_AMOUNT`); (2) `expect4337Revert()` without a selector
asserts nothing — every executor revert test now carries the expected selector where the revert is a
hook error, and the router-mismatch / above-cap tests etch the harness so a missing check would be
observable; (3) two invariants were unfalsifiable because the mock always consumed the full allowance —
pull and send amounts are now randomised independently (partial fills), two batches run per call to
fuzz the per-tx accumulator, and a new `TxCapArithmeticExact` invariant pins the cap arithmetic.

Process finding: `dynamic_test_linking = true` can run stale bytecode after a `src/` edit. All results
here were produced with `FOUNDRY_DYNAMIC_TEST_LINKING=false forge build --force`; CI should do the same.

### R-P3-3 — Natspec corrections
**Status:** Fixed

Removed the claim that the strategy skips its slippage backstop when `usePrevHookAmount` is set (it
always runs). The router note now says the diamond emits `DiamondCut` and the swap facet has
`addRouters`/`removeRouters`; monitoring should subscribe to those rather than poll a selector map.

---

## P0 Findings (Critical - Must Fix)

None found.

## P1 Findings (High)

### P1-1 — Spec pinned the wrong router
**Status:** Fixed; router confirmed on-chain 2026-10-12

The spec's candidate `0xb300000b72DEAEb607a12d5f54773D1C19c7028d` is the generic "Binance: DEX Router"
selector-dispatch proxy. Public integrations of the LiquidMesh vendor (`binance-web3-connector-js#7`,
`ottopus#55`) show a real LiquidMesh `/swap` for a bStock on BSC targeting
`0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5`, and the quote's `approveTarget` equals that `to`.
Verified on-chain: standard EIP-2535 diamond, owner `0x1c6F8a6D1011Ca0334F6f8F5E2f9222eF1b68Fa9`,
swap facet `0xa9fA1b56f4d7Bd25375C2d40B4c8e36A9509e603` (selector `0xad43f73d`), source unverified.

Deploying with the wrong constant is not a loss of funds — every build reverts `ROUTER_MISMATCH` —
but it is a redeploy plus a root update. `BINANCE_DEX_ROUTER_BNB`, the verify script and the test
constant now carry `0xB444…DA5` with a TODO; `test_Live_USD1_to_AAPLB_LiquidMesh` reverts loudly on
mismatch.

**On-chain confirmation (2026-10-12, BSC head ~127,188,445, QuickNode RPC):** `0xB444…DA5` is a live
EIP-2535 diamond (owner `0x1c6F…8Fa9`, 6 facets, `facetAddress(0xad43f73d)` = `0xa9fA…9603`, unknown
selectors revert `0xa9ad62f8`). In the preceding 9,500 blocks it emitted events in 366 transactions;
at least 10 of those moved Binance-Peg USDT against AAPLB or NVDAB, including a direct call with the
swap selector (`0xa618621b43df39af928165bd32d789c9220f69ae404b5cbe7fd0ec24f6f1d4cd`). The generic
dispatcher `0xb300…028d` has a different owner (`0x517e…DA11`). The deploy-gate concern (review todo
001) is closed on this basis; the config row stays populated.

## P2 Findings (Medium)

### P2-1 — Unbounded reads on short data / selector-less calldata
**Status:** Fixed

Siblings have no `MIN_DATA_LENGTH` check. `_buildHookExecutions` and `inspect()` now reject
`data.length < 221`, and `txData.length < 4` is rejected so the call can never land in the diamond's
fallback. Covered by `test_Build_RevertIf_DataTooShort`, `testFuzz_Build_ShortData_Reverts`,
`test_Build_RevertIf_TxDataNoSelector`, `test_Inspect_RevertIf_DataTooShort`.

### P2-2 — `MAX_INPUT_AMOUNT` value
**Status:** Fixed (set to 10,000,000 USDT, 2026-10-12)

The input asset is Binance-Peg USDT on BSC (`0x55d398326f99059fF775485246999027B3197955`, 18 decimals),
not USD1 as the original research assumed. The cap is `10_000_000e18`: a fat-finger guard chosen by the
pod, not a risk limit — under a compromised OMS key the loss bound per execution is this value. The cap
is immutable and token-agnostic; it only bounds loss because the leaf commits `inputToken`. A leaf for
a 6-decimal token would make it 1e12× looser. `BinanceDeployConfig.t.sol` pins the production
constants and the locked bytecode so a silent change fails CI.

### P2-3 — `inspect()` encoding must be reproducible by the SuperBank root generator
**Status:** Fixed

The spec's `abi.encode(inputToken, outputToken)` (64 bytes) cannot be produced by v2-periphery
`tree_builder.encode_hook_args`, which only concatenates configured `address` args as raw 20 bytes.
`inspect()` now returns `abi.encodePacked(inputToken, outputToken)` (40 bytes): two fixed-width fields,
unambiguous, and emitted by the existing generator from a config entry with two address args in that
order. `BinanceLeafCommitment.t.sol` replicates both the aggregator's leaf formula and the generator's
encoder byte-for-byte and proves: any calldata for the committed pair validates; a different input
token, output token, hook address, swapped arg order, a single-arg sibling config, or the old 64-byte
form all fail.

Remaining deployment invariant (not enforceable on-chain): the leaf goes in the strategy root, never
the global root — a global `(hook, USD1, bStock)` leaf authorises every SuperVault.

## P3 Findings (Low)

### P3-1 — Standing allowance on another token is harvestable
**Status:** Documented, accepted

The hook scopes and clears the allowance for `inputToken` only. A pre-existing allowance to the
router on a different token (a stray `ApproveERC20Hook` leaf) can be pulled by the opaque blob.
`test_Sequence_RouterPullsSecondToken_WithStandingAllowance_Succeeds` documents it; the operator
invariant is "never create a standing allowance to this router".

### P3-2 — `outputMin` is caller-chosen and not in the leaf
**Status:** Documented, accepted

In-hook slippage is a mistake guard for an honest manager, not a control against a compromised key
(1 wei passes the non-zero check). Same concession as `SuperVaultStrategy.expectedAssetsOrSharesOut`.
`MAX_INPUT_AMOUNT` bounds the loss.

### P3-3 — Mutable diamond; returndata bomb
**Status:** Documented, accepted

Pinning the address does not pin the code; selector-map monitoring plus `bannedLeaves` veto remain
off-chain prerequisites. Unbounded returndata is copied by the account's ERC-7579 batch and is an
accepted gas cost (`test_Sequence_RouterReturndataBomb_BatchCompletes`).

## Attack Surface Checklist
- [x] Reentrancy — `executeHooks` is `nonReentrant`; pre/post are account-gated one-shot
- [x] Caller retargeting (Dexible) — router immutable, payload `to` must match
- [x] Allowance harvesting (Socket / Li.Fi) — approve(0)/approve(exact)/swap/approve(0) + `allowance == 0` assert
- [x] Any-approved-token spend — `inputToken` committed in `inspect()`
- [x] Native path — rejected (`NATIVE_ETH_NOT_SUPPORTED`), every execution `value: 0`
- [x] Chaining with opaque amounts — `usePrevHookAmount` reverts; hook is sizeless (S2)
- [x] Negative balance delta — named `OUTPUT_BALANCE_DECREASED`, not panic
- [x] Display-multiplier tokens (EIP-8056 / BEP-677) — raw `balanceOf`, no guard needed
- [ ] Vault-level multiplier valuation, reverse-split auto-pause, sanctions freeze — out of scope, go-live blockers per the spec
