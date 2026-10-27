# Health Check Hooks — Technical Spec

## Overview

`MorphoHealthCheckHook` and `AaveV4HealthCheckHook` are NONACCOUNTING, PASSTHROUGH guards that revert unless the
executing account's health factor on the named venue is at or above a calldata-committed `minHealthFactor` (WAD,
`1e18` = liquidation line). They inherit `BaseHook` directly in the `MarkRootAsUsedHook` shape.

## Problem Statement / Motivation

Leverage strategies chain PLEDGE / BORROW / swap / RELEASE legs. Each venue only enforces its own liquidation line
(health factor ≥ 1e18) on its own legs; nothing lets a strategy commit, in the merkle leaf, to a stricter margin that
is checked after the whole chain ran. Without a guard an OMS mis-sizing or a price move between signing and execution
can leave a position one tick from liquidation.

## Proposed Solution

One hook per venue, zero executions, check in `build()` (post-action already, because the executor builds hook N only
after hook N-1 executed) and again in `_postExecute` (authoritative, inside the account batch).

### Venue functions called (all STATICCALL)

- Morpho Blue singleton (`morpho` immutable): `position(id, account)`, `market(id)`; body IRM: `borrowRateView`;
  body oracle: `price()`.
- Aave V4 Spoke (calldata): `getUserAccountData(account)`.

### Health factor

**Morpho** (mirrors `Morpho._isHealthy` exactly):

```
(_, borrowShares, collateral) = position(id, account)
if borrowShares == 0: return uint256.max                            // never prices
(totalBorrowAssets, totalBorrowShares) = expectedBorrowBalances(morpho, mp)   // view accrual, wTaylorCompounded
borrowed  = borrowShares.toAssetsUp(totalBorrowAssets, totalBorrowShares)     // rounds UP (Morpho)
maxBorrow = collateral.mulDivDown(oracle.price(), 1e36).wMulDown(lltv)        // rounds DOWN (Morpho)
hf        = maxBorrow.wDivDown(borrowed)                                      // rounds DOWN
```

At `min = 1e18`: `floor(maxBorrow·1e18 / borrowed) ≥ 1e18 ⇔ maxBorrow ≥ borrowed ⇔ Morpho._isHealthy`.

**Aave V4**: `getUserAccountData(account).healthFactor` (WAD; `uint256.max` when no debt;
`HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18` upstream). Struct order verified against the Ethereum Main Spoke
implementation (`SpokeInstance` @ `0xabd0e26f…`) and upstream `aave/aave-v4` `src/spoke/interfaces/ISpoke.sol`:
`riskPremium, avgCollateralFactor, healthFactor, totalCollateralValue, totalDebtValueRay, activeCollateralCount,
borrowCount`.

## Technical Considerations

### Where the check runs
`BaseHook.build()` wraps the hook's executions with `preExecute` / `postExecute`; with an empty inner array the
executor's `validateHookCompliance` accepts the 2-element result (`SuperExecutorBase.sol:127-152` rejects only
`length < 2`). A revert in either `build()` (executor frame) or `postExecute` (account batch frame) propagates to the
EntryPoint, which records `UserOperationRevertReason` and reverts the account's state — the whole userOp unwinds.

### PASSTHROUGH
`_preExecute` is the base default: with a previous hook it forwards `outAmount` / `outToken`, so
`[BORROW, HEALTH_CHECK, REPAY(usePrev)]` lets the repay size itself from the borrow's output through the guard.

### Aave V4 stale dynamic-config keys
`getUserAccountData` evaluates with the account's STORED dynamic-config keys. `borrow` and a flagged `withdraw`
refresh the keys of all flagged reserves first, `supply` / `setUsingAsCollateral` do not. After BORROW / RELEASE
(the intended position) the number is the Spoke's post-action health; after PLEDGE-only / swap-only legs it may be
optimistic if governance tightened a collateral factor since the last refresh. No hook-side fix exists without a
state-changing refresh; the OMS sizes `minHealthFactor` with margin.

## Attack Surface Analysis

### Token Risks
None — no token is moved or approved.

### Reentrancy
None — every external interaction is a STATICCALL from a `view` path; no state is written.

### Oracle & Price
The V2 loan hooks treat the Morpho oracle as identity only ("never priced") so a manipulated price can never size
an amount. This hook is the one documented exception: `price()` feeds a `>=` comparison and nothing else. Reverting
oracle → userOp reverts (fail-closed). High price → passes only what Morpho itself would consider healthy at that
instant (same oracle, same math). Low price → reverts a healthy position (fail-closed).

### Access Control
`account` is always the executing smart account passed by the executor; no `onBehalf` exists in calldata.
`preExecute` / `postExecute` keep BaseHook's `msg.sender == account` and single-call mutexes.

### DeFi Interaction Risks
Aave stale-config caveat (above). Morpho `irm == 0` markets rejected at decode. Checked arithmetic reverts (fail-
closed) on the same products Morpho computes in `_isHealthy`.

### Exploit Precedent
Not applicable — the guard moves nothing. A compromised oracle degrades it to "as strict as the venue", never looser.

## Acceptance Criteria

### Functional

| Criterion | Proof |
|---|---|
| Reverts iff `hf < min`, with both numbers | unit `test_Build_RevertIf_HealthFactorBelowMin`, `testFuzz_Threshold_PassIffHealthFactorAtLeastMin` (both suites) |
| No debt passes, Morpho never prices | `test_Build_Pass_NoDebt_ReturnsMax_NeverCallsOracle`, `test_Build_Pass_EmptyAccount_MaxHealthFactor` |
| Venue HF read reverts with debt -> fails closed | Morpho: unit `test_Build_RevertIf_OracleReverts_WithDebt`, fork `test_V2_HealthCheck_OracleReverts_WithDebt_FailsClosed`; Aave: fork `test_AaveV4V2_HealthCheck_SpokeReverts_WithDebt_FailsClosed` |
| Rounding parity with Morpho `_isHealthy` | `test_Build_Boundary_MatchesMorphoIsHealthy`; fork `test_V2_HealthCheck_MatchesManualMorphoFormula` |
| View accrual | `test_Build_ViewAccrual_LowersHealthFactorAfterWarp` |
| Aave number == Spoke read | fork `test_AaveV4V2_HealthCheck_MatchesSpokeGetUserAccountData`, `test_Build_ReadsSpokeFromCalldata` |
| Header pins | `test_Build_RevertIf_HeaderNotMarketKey`, `_SwappedReserveIds`, `_KeyFromAnotherSpoke`; fork `_WrongMarketKey_Reverts`, `_WrongSpokeInHeader_Reverts` |
| Exact lengths, zero checks, `min >= 1e18` | `test_Build_RevertIf_WrongLength`, `_ZeroAddresses` / `_ZeroSpoke` / `_ZeroKey`, `_IdenticalTokens`, `_MinBelowWad` |
| `[pre, post]` only; post is authoritative | `test_Build_ReturnsOnlyPreAndPost`, `test_PostExecute_CatchesStateChangeAfterBuild` |
| Whole userOp unwinds | fork `*_PledgeBorrow_BelowMin_UnwindsBorrow`, `*_PledgeBorrow_MaxThreshold_Unwinds`, `*_AfterRelease_BelowMin_UnwindsRelease` (balances and positions unchanged) |
| Leverage-loop composite (3 supply+borrow rounds + guard) | fork `*_HealthCheck_LeverageLoop_Composite_Passes` (cumulative position, passes at margin), `*_LeverageLoop_Composite_BelowMin_UnwindsAll` (whole loop unwinds) |
| Passes post-action in one userOp | fork `*_PledgeBorrow_OneUserOp_Passes` |
| PASSTHROUGH under the real executor | fork `*_ForwardsBorrowOutput_ToRepay` (wallet nets to zero, ≤ 2 wei dust) |
| Sizeless S2 | `test_SizingApi_Sizeless`; `HookSizingInterface.t.sol` NewlyS2 lists + `_allHooks` 126 |
| Threshold in the leaf | `test_Inspect_PacksIdentityAndThreshold` (164 / 136 bytes); `test_Leaf_ThresholdDowngrade_FailsOldProof` (old proof fails after a threshold change) |

### Non-Functional
- Deployed hooks' bytecode unchanged: `AaveV4LoanBytecodeUnchanged.t.sol` (8 tests) green; regenerating the two new
  artifacts touched no other file under `script/generated-bytecode`.
- `manifests/hooks.json` regenerated and linted (171 hooks).

## Implementation

- `src/vendor/aave-v4/IAaveV4Spoke.sol` — `UserAccountData` + `getUserAccountData`
- `src/hooks/loan/morpho/MorphoHealthCheckHook.sol` — 196-byte layout, `morpho` immutable, `MISC` subtype
- `src/hooks/loan/aave-v4/AaveV4HealthCheckHook.sol` — 168-byte layout, no ctor args, `MISC` subtype
- Errors: `HEALTH_FACTOR_BELOW_MINIMUM(uint256,uint256)` (same signature on both), `INVALID_MIN_HEALTH_FACTOR()`,
  `INVALID_DATA_LENGTH()`; Morpho adds `MARKET_KEY_MISMATCH()`, `IDENTICAL_TOKENS()`; Aave reuses
  `AaveV4ReserveKey.MARKET_KEY_MISMATCH`; both reuse `BaseHook.ADDRESS_NOT_VALID`.
- `inspect()` is `pure`: Morpho packs `(marketKey, loanToken, collateralToken, oracle, irm, lltv, minHealthFactor)` —
  the V2 family identity plus one trailing `uint256`; Aave packs `(marketKey, spoke, supplyReserveId, borrowReserveId,
  minHealthFactor)`. The threshold is in the leaf on purpose (PR #1037 review F1): `SuperVaultStrategy._validateHook`
  hashes only `inspect()` output, so without it an execution signer could reuse a strategy permission with a lower
  minimum. Consequence: each distinct threshold is a distinct leaf, and lowering or raising the curator margin means
  publishing a new root — the same cost as changing a market or `lltv`. Off-chain leaf builders must append the WAD
  threshold as a 32-byte word.

### Deployment Changes
- `script/utils/Constants.sol`: `MORPHO_HEALTH_CHECK_HOOK_KEY`, `AAVE_V4_HEALTH_CHECK_HOOK_KEY`
- `script/DeployV2OtherHooks.s.sol`: `MorphoV2HookAddresses.morphoHealthCheckHook` (set 6 → 7, `morphoArg`),
  `AaveV4V2StandaloneHookAddresses.aaveV4HealthCheckHook` (set 3 → 4, no args). `__deployContract` skips existing
  CREATE2 code, so re-running a set on a live chain deploys only the new hook.
- `script/run/tooling/regenerate_bytecode.sh`, `script/run/deploy/deploy_v2_other_hooks_staging_prod.sh`,
  `script/run/verify/verify_v2_staging_prod.sh` arrays / path map.
- Artifacts: `script/generated-bytecode/`, `script/locked-bytecode/`, `script/locked-bytecode-dev/`.

### Test Files
- `test/unit/hooks/loan/MorphoHealthCheckHook.t.sol`, `test/unit/hooks/loan/AaveV4HealthCheckHook.t.sol`
- `test/unit/hooks/HookSizingInterface.t.sol` (enumeration)
- `test/integration/morpho/MorphoV2HooksFork.t.sol`, `test/integration/AaveV4V2HooksFork.t.sol` (section "HEALTH
  CHECK GUARD")

## Dependencies & Risks
- Morpho Blue `ORACLE_PRICE_SCALE = 1e36` pinned locally (not vendored).
- Aave V4 Spoke is governance-upgradeable. A truncated `getUserAccountData` return reverts the 7-word decode; a
  same-width field REORDER does not and would fail open (a RAY value lands in the health slot). Field order is an
  unchecked ABI assumption pinned by the mainnet-fork test; re-verify it before adopting a new Spoke implementation.
- Morpho: the guard shares Morpho's oracle and math, so it is never looser than the venue at that instant. It is not
  an independent price-integrity check: a HIGH oracle price overstates collateral for both.

## References & Research
- `.claude/doc/health-check-hooks/plan.md`, `.claude/sessions/context_session_47.md`
- `specs/aave-v4-v2-standalone-hooks/technical-spec.md` §6 (stale dynamic-config), `specs/aave-v4-oracles/research/framework-docs.md`
- Morpho Blue `Morpho.sol::_isHealthy`, `MorphoBalancesLib`, `SharesMathLib`
- Upstream `aave/aave-v4` `src/spoke/interfaces/ISpoke.sol`; Ethereum Main Spoke `0x94e7A5dCbE816e498b89aB752661904E2F56c485`
