# Pendle PT Record Hooks — Technical Specification

## Overview

Introduce two new Superform v2 hooks — `RecordPurchasePendlePTHook` and
`RecordRedemptionPendlePTHook` — that record PT trades into `PendlePTAmortizedOracleV2` by sourcing
the PT amount (and market) from the **actual balance-delta result** of the preceding production
`PendlePTHook`, rather than the scalar `ISuperHookResult.getOutAmount`. This requires extending
`PendlePTHook` with a context-aware `IPendlePTHookResult` interface exposing both sides of the
completed trade. New calldata layout + bytecode → treat as a **new hook deployment**, not an
in-place update.

## Problem Statement / Motivation

Real PT purchase on Ethereum (`0x62582b07d6c667822af3f1bb03ab2bfa5687cfb1ef7c068df23265ae2c7385fa`)
failed OMS normalization with `hook_params.syAccountingAssetSpent is required`. Deeper issue: the
generic `ISuperHookResult.getOutAmount(account)` only exposes a hook's **output**. That is correct
for a PT **buy** (output = PT) but structurally wrong for a **sell/redeem** (output = the asset
received; PT is the **input**). The current V2 redemption recorder
(`RecordRedemptionPendlePTAmortizedOracleHookV2.sol:102`) records the received-asset amount as
`ptSold` — a correctness bug. There is no interface exposing a trade's input side, so redemption
accounting cannot be done from the generic result.

## Proposed Solution

1. **`IPendlePTHookResult`** (new interface, `src/interfaces/`): `Operation { NONE, BUY_PT, SELL_PT,
   REDEEM_PT }`, `TradeResult { operation, market, inputToken, outputToken, inputAmount,
   outputAmount }`, `getPendleTradeResult(address account) returns (TradeResult)`.
2. **Extend `PendlePTHook`** to populate and expose the `TradeResult` from actual execution balance
   deltas, reusing the existing transient per-account context — add an **input-token** snapshot
   (it currently snapshots only the output token).
3. **New record hooks** that pin an approved `PendlePTHook`, read `getPendleTradeResult`, validate
   operation/market/PT-token, resolve the PT amount (output for buy, input for sell/redeem) with the
   `amount` + `usePrevHookAmount` fallback, and call the oracle.

## Technical Approach

### Architecture (in-flow, same tx)

```
SuperExecutor sequence (one UserOp):
  [ ... optional funding/swap ... ]
  PendlePTHook           -> executes buy/sell/redeem; _postExecute writes TradeResult
                            into transient per-account context (nonce-keyed)
  RecordPurchase/Redemption Hook (immediately after)
                         -> build() reads prevHook.getPendleTradeResult(account),
                            validates, resolves PT amount, calls oracle.recordX(...)
                            PipeMode.PASSTHROUGH -> forwards prevHook out amount+token
```

### `IPendlePTHookResult` and context storage

- New interface lives in `src/interfaces/` (sibling to `ISuperHookResult`,
  `src/interfaces/ISuperHook.sol:81,89`).
- `BaseHook` transient context is keyed by `_makeAccountContextKey(account)` with a monotonic
  `executionNonce`; value slots via `_makeKey(context, offset)`. Existing offsets: `outAmount=1`,
  mutexes `2/3`, `outToken=4` (`BaseHook.sol:52-55,362-364,387-389`).
- **`TradeResult` gets new offsets (≥5):** `operation`, `market`, `inputToken`, `inputAmount`
  (`outputToken`/`outputAmount` can reuse the existing `outToken=4` / `outAmount=1`). These MUST use
  the same context-nonce-keyed transient slots so isolation is inherited automatically:
  `resetExecutionState` clears only mutexes (`BaseHook.sol:441-444`); transient values are wiped at
  tx end and are unreachable next execution because the nonce increments. **This is the feature's
  central invariant** (vuln DB §23.7 transient-storage misuse).

### `PendlePTHook` changes

- Operation is already determined in `_buildHookExecutions` (`PendlePTHook.sol:208-228`):
  - `output == PT && input != PT` → `swapExactTokenForPt` → **BUY_PT** (PT is output)
  - `input == PT && output != PT && !YT.isExpired()` → `swapExactPtForToken` → **SELL_PT** (PT is input)
  - `input == PT && output != PT && YT.isExpired()` → `redeemPyToToken` → **REDEEM_PT** (PT is input)
- Header: `inputToken@52`, `outputToken@72`; `market = HookDataDecoder.extractYieldSource(data)`;
  `(SY, PT, YT) = IPendleMarket(market).readTokens()` with **PT at index 1**.
- `_getBalance` currently snapshots only the **output** token (`PendlePTHook.sol:628-636`). Add a
  symmetric **input**-token snapshot in `_preExecute`; in `_postExecute` compute
  `inputAmount = inputBalanceBefore - inputBalanceAfter` (input decreases in all three ops) and
  `outputAmount = outputBalanceAfter - outputBalanceBefore` (already computed as `outAmount`). Persist
  `operation`, `market`, `inputToken`, `outputToken`, `inputAmount`, `outputAmount` to context.
- Extend `supportsInterface` with `type(IPendlePTHookResult).interfaceId`.
- Preserve existing `getOutAmount`/`getOutToken` semantics (output side) for backward compat.

### Record hooks

Both: `BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT)`, S2 sizeless
(`decodeAmounts`/`amountRoles` length-0), `inspect()` commits market only, `PipeMode.PASSTHROUGH`.
Constructor pins `ORACLE` **and** `APPROVED_PENDLE_PT_HOOK` (both non-zero).

Common resolution in `_buildHookExecutions(prevHook, account, data)`:
```solidity
if (prevHook != APPROVED_PENDLE_PT_HOOK) revert PREV_HOOK_NOT_VALID();
IPendlePTHookResult.TradeResult memory r = IPendlePTHookResult(prevHook).getPendleTradeResult(account);
// operation gate (per hook), market match, PT-token match
if (r.market != market) revert MARKET_NOT_VALID();
(, address pt,) = IPendleMarket(market).readTokens();
uint256 resolved = amount;              // encoded fallback
if (usePrevHookAmount) resolved = /* buy: r.outputAmount ; sell/redeem: r.inputAmount */;
if (resolved == 0) revert AMOUNT_NOT_VALID();   // validate AFTER resolution
```

- **`RecordPurchasePendlePTHook`:** require `r.operation == BUY_PT`; `r.outputToken == pt`; PT amount =
  `usePrev ? r.outputAmount : amount`. Execution → `ORACLE.recordPurchase(market, ptBought,
  twapDuration)` (on-chain SY cost via `getPtToSyRate(twapDuration)`; oracle enforces
  `twapDuration >= getMinTwapDuration(market)`).
- **`RecordRedemptionPendlePTHook`:** require `r.operation == SELL_PT || r.operation == REDEEM_PT`;
  `r.inputToken == pt`; PT amount = `usePrev ? r.inputAmount : amount`. Execution →
  `ORACLE.recordRedemption(market, ptSold)` (no `twapDuration`). **Never** read `getOutAmount` as
  `ptSold`.

### Calldata (52-byte strategy header + hook-specific)

| Field | Purchase offset | Redemption offset |
|---|---|---|
| `bytes32 placeholder0` | 0 | 0 |
| `address placeholder1` | 32 | 32 |
| `address market` | 52 | 52 |
| `uint256 amount` | 72 | 72 |
| `uint32 twapDuration` | 104 | — |
| `bool usePrevHookAmount` | 108 | 104 |

### Oracle interaction (`PendlePTAmortizedOracleV2`)

- `recordPurchase(address market, uint256 ptBought, uint32 twapDuration)` (`:165-208`): cost basis
  `sySpent = ptBought * getPtToSyRate(twapDuration) / 1e18` (`:180-181`) — **must use
  `getPtToSyRate`, not `getPtToAssetRate`**. Enforces `twapDuration >= getMinTwapDuration(market)`
  (default 300s).
- `recordRedemption(address market, uint256 ptSold)` (`:214-242`): no TWAP; amortized pull-to-par.
- **Consistency requirement:** the oracle independently re-derives balances
  (`previousPtBalance = balanceOf(strategy) ∓ amount`, `:184-201,227-235`). The recorded delta must
  be consistent with the strategy's PT balance at record time, or the record reverts (whole-sequence
  DoS) or mis-amortizes.

## Attack Surface Analysis

### Token Risks
- [ ] Fee-on-transfer PT/asset — balance-delta must be measured on `account` both input and output
  sides; do not trust quotes (10.1). New **input** snapshot extends this to a second path.
- [ ] Rebasing / >18-decimal PT (10.2/10.4) — deltas + oracle re-derivation must agree.
- [ ] Missing-return-value tokens — reads are `balanceOf` only; oracle uses SafeERC20 where it moves.

### Reentrancy
- [ ] **Read-only reentrancy (1.4, Curve $69M):** `getPendleTradeResult`/`getOutAmount` are views read
  by the next hook; ensure no external contract can observe a half-updated context. Mitigated by
  same-tx, post-`_postExecute` read and mutexes.
- [ ] CEI in `_postExecute` snapshot ordering.

### Oracle & Price
- [ ] **TWAP manipulation / low-liquidity market (48.7, 48.1 Penpie):** enforce `twapDuration >=
  getMinTwapDuration`; reject spot (0s) for accounting; require market observation cardinality.
- [ ] SY-vs-asset rate confusion — redemption is 1:1 in **SY** terms, not asset terms.

### Access Control / Trust
- [ ] **Prev-hook spoofing (44.x market/hook-data trust, Cork $11M):** pin `APPROVED_PENDLE_PT_HOOK`;
  the current V2 recorder pins nothing — this is a real upgrade.
- [ ] **Malicious `market.readTokens()`** returning attacker PT/token — record hooks validate against
  the committed market and check PT-token identity; market authorization remains at strategy/Merkle
  layer.

### Context Isolation
- [ ] **Cross-account / cross-execution leak (23.7):** `TradeResult` must live in the transient,
  context-nonce-keyed slots; reject stale/empty result (operation `NONE` or nonce mismatch) and a
  result whose account ≠ current.

### Exploit Precedent
| Protocol | Incident | ~Loss | Relevance | Mitigation |
|---|---|---|---|---|
| Penpie | Pendle reward reentrancy | ~$27M | Pendle-adjacent hook reentrancy | mutexes, transient nonce, CEI |
| Curve | read-only reentrancy | ~$69M | view read by next hook | post-commit read, mutex |
| Cork | market/hook-data trust | ~$11M | trusting caller-supplied market/hook | approved-hook pin + market commit |
*(loss figures from internal vuln DB; verify primary sources before publishing.)*

## Resolved Edge Cases (from flow analysis)

- **Pin before any external call (G-8):** validate `prevHook == APPROVED_PENDLE_PT_HOOK` **before**
  calling `getPendleTradeResult` — otherwise a first-hook / foreign-hook case ABI-decode-reverts on
  empty returndata instead of the clean `PREV_HOOK_NOT_VALID`.
- **Two trades in one sequence (F16):** the context is keyed by the shared `PendlePTHook` address +
  current nonce, so a recorder always sees the **latest** trade. The committed-`market` match is the
  guard — a recorder paired with the wrong trade **must revert on market mismatch**, never silently
  misrecord. (Covered by an explicit test.)
- **Redemption passthrough (G-12):** `PipeMode.PASSTHROUGH` forwards the swap's **output asset** (and
  its amount) downstream — NOT the just-recorded PT amount. Assert this direction explicitly.
- **PT-token validation source (G-3):** validate `r.inputToken`/`r.outputToken` against
  `IPendleMarket(market).readTokens()[1]` on the **committed** market (from the record hook's own
  Merkle-committed calldata, matched to `r.market`). The market is not caller-arbitrary, so re-reading
  it is acceptable; do not accept a market from anywhere other than the committed calldata.

### Resolved decisions (flow-analysis gaps)
- **G-1 zero-fill → always revert.** `resolvedAmount == 0` reverts `AMOUNT_NOT_VALID` in BOTH manual
  and automatic modes (per brief). A genuine automatic zero-fill (e.g. unfilled limit-order leg)
  therefore reverts the whole atomic action — accepted by design.
- **G-3 PT-token source → re-read `readTokens()`** on the committed + `TradeResult`-matched market
  (see above). The market is Merkle-committed, not caller-arbitrary.
- **G-2 OMS → out of scope.** OMS normalization code lives off-repo; this repo only ships the
  manifests. No OMS smoke-test gate is in scope (informational only).
- **G-4 migration → off-chain.** Blocking old/incompatible hook versions for new strategies is
  handled off-chain (strategy config / Merkle-root generation). No on-chain gating in scope; old
  on-chain records/addresses are retained for historical decoding.

## Acceptance Criteria

### Functional
- [ ] buy → `RecordPurchasePendlePTHook` with `amount==0` & `usePrev==true` records **actual PT
  received** (`r.outputAmount`).
- [ ] purchase no longer requires `syAccountingAssetSpent` (on-chain V2 calc).
- [ ] sell → `RecordRedemptionPendlePTHook` with `amount==0` & `usePrev==true` records **actual PT
  spent** (`r.inputAmount`), NOT the output asset.
- [ ] matured-redeem → redemption recorder records actual PT redeemed.
- [ ] both work in manual mode (non-zero `amount`, `usePrev==false`).
- [ ] zero resolved amount reverts (`AMOUNT_NOT_VALID`) — validated after resolution.
- [ ] purchase rejects SELL/REDEEM results; redemption rejects BUY results.
- [ ] both reject: mismatched market, wrong PT token, prev hook ≠ approved, stale/empty context,
  result belonging to another account.
- [ ] passthrough preserves prev hook's output amount + output token downstream.

### Non-Functional / Security
- [ ] All Attack Surface items addressed; `getPtToSyRate` (not asset) verified; TWAP-min enforced.
- [ ] `TradeResult` strictly in transient nonce-keyed context.

### Registry / Deploy
- [ ] `manifests/hooks.json` (`generate_hook_manifest.py` + `hook-classification.yaml`) and
  `hook-sizing-manifest.json` (`generate-hook-sizing-manifest.ts`, sizeless OVERRIDES) include both
  new hooks in automatic **and** manual modes.
- [ ] Added to `regenerate_bytecode.sh` `HOOK_CONTRACTS` + `locked-bytecode/` (prod) and
  `locked-bytecode-dev/` (staging).

### Tests
- [ ] Unit (mirror `test/unit/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.t.sol`,
  `test/unit/hooks/pendle/PendlePTHook.t.sol`): build shape, all validations/reverts, manual+auto.
- [ ] Fuzz: recorded ptBought == output delta (buy); recorded ptSold == input delta (sell/redeem) and
  ≠ output; zero-amount revert; TWAP-min boundary.
- [ ] Fork (extend `test/integration/pendle/PendlePTHookE2E.t.sol`, ETH block `24_300_000`): buy, sell,
  matured redeem, manual, automatic, market/token mismatch, execution-context isolation.

## Implementation Plan

1. `IPendlePTHookResult` interface (`src/interfaces/`).
2. Extend `PendlePTHook`: input-token snapshot in `_pre/_postExecute`, populate `TradeResult` in
   transient context, implement `getPendleTradeResult`, extend `supportsInterface`.
3. `RecordPurchasePendlePTHook` + `RecordRedemptionPendlePTHook` (`src/hooks/oracles/pendle/`).
4. Registry/manifest tooling entries (both modes).
5. Deploy wiring in `DeployV2Core.s.sol` (oracle from `configuration.pendlePTAmortizedOraclesV2`,
   approved `PendlePTHook` per env), `regenerate_bytecode.sh`, locked bytecode (staging + prod).
6. Tests (unit + fuzz + fork).

## Deployment / Migration

New deployment (not metadata-only): deploy updated `PendlePTHook` first; then record hooks against the
intended oracle version; register new build paths + impl addresses atomically with OMS; update
strategy Merkle roots / allowed sequences before enabling; retain old V2 hook records/addresses for
historical decoding (address→version mapping) but block new strategies from the incompatible versions;
verify bytecode + registry metadata on every supported chain; **separate staging vs prod addresses**
(`env` 0=prod→`locked-bytecode/`, 2=staging→`locked-bytecode-dev/`; address divergence via
`saltNamespace`).

## Out of Scope
- Combining purchase + redemption into one contract.
- Changing the amortization formula beyond the existing V2 on-chain PT→SY calc.
- Supporting arbitrary previous swap hooks that don't implement `IPendlePTHookResult`.

## References & Research
- `src/hooks/swappers/pendle/PendlePTHook.sol` (routing `208-228`, balance `628-636`, pre/post `347-355`)
- `src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol` (S2 exemplar `156-179`)
- `src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol` (bug `102`)
- `src/accounting/oracles/PendlePTAmortizedOracleV2.sol` (`165-208` purchase, `214-242` redemption, TWAP-min `336-339`)
- `src/hooks/BaseHook.sol` (context `362-389`, reset `441-444`)
- `DeployV2Core.s.sol` (PendlePTHook `3782-3789`, record V2 `3614-3636`); `DeployV2Base.s.sol:391-410`
- Research: `research/repo-analysis.md`, `research/framework-docs.md`, `research/best-practices.md`,
  `research/evm-security.md`, `research/specflow-analysis.md`
- Vuln DB: `superform-specs/guidelines/solidity/vulnerabilities.md` (§23.7, §1.4, §44.x, §48.1, §48.7)
