# Health Check Hooks Spec (Morpho Blue + Aave V4)

## Metadata
- Project: Superform V2
- Milestone: Leverage strategies — piece 1 of 3 (health check → leverage loop → deleverage)
- Linear Issue: N/A
- Interview Date: 2026-10-21
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

Two NONACCOUNTING, PASSTHROUGH guard hooks — `MorphoHealthCheckHook` and `AaveV4HealthCheckHook` — that revert
unless the executing smart account's health factor on the named venue is at or above a `minHealthFactor` carried in
calldata (and therefore committed in the strategy's merkle leaf). They move no funds, grant no approvals and emit no
executions of their own; placed after a BORROW / RELEASE / swap leg they make the whole userOp unwind when the
position would end up too close to liquidation.

"Health factor" means the same thing on both venues: WAD-scaled, `1e18` = the venue's own liquidation line,
`type(uint256).max` = no debt.

## Requirements

### Functional
1. Revert with `HEALTH_FACTOR_BELOW_MINIMUM(healthFactor, minHealthFactor)` iff `healthFactor < minHealthFactor`
2. An account with no debt passes at any threshold (`type(uint256).max` means "must have no debt")
3. Header identity pinned to the body: Morpho market key (`MorphoBlueMarketRegistry.computeMarketKey` derivation),
   Aave V4 `AaveV4ReserveKey.computeMarketKey(spoke, supplyReserveId, borrowReserveId)`; mismatch reverts
4. The check observes post-action state within the same userOp (build-time read + authoritative `_postExecute` read)
5. PASSTHROUGH: the previous hook's `outAmount` / `outToken` flow through the guard unchanged
6. Sizeless (S2): `decodeAmounts` / `amountRoles` empty, `ISuperHookInflowOutflow` yes, `ISuperHookOutflow` no
7. `minHealthFactor < 1e18` is rejected (`INVALID_MIN_HEALTH_FACTOR`)
8. `previewHealthFactor(data, account)` view exposes the exact number the guard enforces (OMS sizing)

### Non-Functional
- Read-only: every venue interaction is a STATICCALL; no approvals, no state writes, no events
- Morpho: no `accrueInterest` execution — view accrual via `MorphoBalancesLib.expectedBorrowBalances`
- Fork-tested end to end through the real SuperExecutor + paymaster on Ethereum mainnet for both venues
- No change to any deployed hook's bytecode (`AaveV4LoanBytecodeUnchanged.t.sol` stays green)

## Technical Design

### Architecture

```
SmartAccount (Nexus)
    └── SuperExecutor._processHook
        └── HealthCheckHook.build()          -> reads venue (staticcall), reverts if hf < min
            └── returns [preExecute, postExecute]   (no executions of its own)
                └── postExecute()            -> same read, authoritative (post-action, inside the account batch)
```

### Data Model

**MorphoHealthCheckHook** — exactly 196 bytes, constructor arg `morpho` (singleton):

| Offset | Type | Field | Validation |
|---|---|---|---|
| 0 | bytes32 | placeholder0 | none |
| 32 | address | yieldSource = market key | `!= 0`, `== address(uint160(uint256(Id.unwrap(marketParams.id()))))` |
| 52 | address | loanToken | `!= 0`, `!= collateralToken` |
| 72 | address | collateralToken | `!= 0` |
| 92 | address | oracle | `!= 0` (priced for the comparison only) |
| 112 | address | irm | `!= 0` |
| 132 | uint256 | lltv | part of the pinned key |
| 164 | uint256 | minHealthFactor | `>= 1e18` |

**AaveV4HealthCheckHook** — exactly 168 bytes, no constructor args (Spoke from calldata):

| Offset | Type | Field | Validation |
|---|---|---|---|
| 0 | bytes32 | placeholder0 | none |
| 32 | address | yieldSource = market key | `!= 0`, `AaveV4ReserveKey.requireHeaderIsMarketKey` |
| 52 | address | spoke | `!= 0`; the only call target |
| 72 | uint256 | supplyReserveId | identity only |
| 104 | uint256 | borrowReserveId | identity only |
| 136 | uint256 | minHealthFactor | `>= 1e18` |

The Aave V4 read is Spoke-wide (cross-reserve); the reserve ids name the market the guard belongs to so its leaf
shares the whitelist bucket of the PLEDGE / BORROW / RELEASE legs it protects. They do not scope the check.

### API Changes

- `src/vendor/aave-v4/IAaveV4Spoke.sol`: `struct UserAccountData` (7 fields, upstream order) +
  `getUserAccountData(address)`. Interfaces emit no bytecode; nothing in `src/` implements it.
- No new subtype: both hooks use `HookSubTypes.MISC` (decision: avoid touching anything shared with deployed hooks).
  Manifest intent `config`, `legSizing: []`, listed under `sizelessHooks`.

## Implementation Plan

### Phase 1: Core Implementation
- [x] `IAaveV4Spoke` extension
- [x] `src/hooks/loan/morpho/MorphoHealthCheckHook.sol`
- [x] `src/hooks/loan/aave-v4/AaveV4HealthCheckHook.sol`

### Phase 2: Testing
- [x] Unit: `test/unit/hooks/loan/{MorphoHealthCheckHook,AaveV4HealthCheckHook}.t.sol` (23 + 21 tests, incl. fuzz)
- [x] Sizing enumeration: `HookSizingInterface.t.sol` (124 → 126 hooks)
- [x] Fork E2E: `MorphoV2HooksFork.t.sol` (12 health-check tests), `AaveV4V2HooksFork.t.sol` (12 health-check tests)

### Phase 3: Deployment
- [x] `Constants.sol` keys, `DeployV2OtherHooks.s.sol` (Morpho V2 set 6 → 7, Aave V4 standalone set 3 → 4)
- [x] `regenerate_bytecode.sh`, deploy / verify shells, `generated-bytecode` + `locked-bytecode{,-dev}` artifacts
- [x] `tooling/hook-{classification,enrichment}.yaml`, `manifests/hooks.json` regenerated and linted
- [ ] Deploy via `DeployV2OtherHooks.runLoanHooksV2` / `runAaveV4V2Standalone` (idempotent: existing hooks skipped)

## Test Plan

See `technical-spec.md` → Acceptance Criteria.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Morpho oracle manipulation | Price feeds a `>=` comparison only, never sizes an amount; same oracle and math as Morpho's `_isHealthy`, so the guard is never looser than the venue. A reverting or LOW price fails closed. A HIGH price overstates collateral for Morpho and the guard alike, so the guard is conservative only relative to the venue's contemporaneous oracle and math; it is not an independent price-integrity or executable-exit check |
| Aave V4 stale dynamic-config keys | After BORROW / flagged RELEASE the keys are fresh (the leg refreshed them). After PLEDGE-only or swap-only legs the figure may be optimistic if governance tightened a collateral factor; documented, OMS sizes with margin above 1e18 |
| Executor builds hooks before executing earlier ones (future change) | Check repeated in `_postExecute`, which always runs after every preceding hook inside the account batch |
| Zero-IRM Morpho market | Rejected at decode (`expectedBorrowBalances` has no zero-IRM guard) |
| Aave struct reshape upstream | Only a TRUNCATED return (fewer than 7 words) reverts the decode. A same-width REORDER is silently mis-decoded: a RAY-scaled collateral/debt value in word 2 satisfies any WAD threshold and the guard fails OPEN (see the `IAaveV4Spoke.getUserAccountData` warning). Backstop: the pinned mainnet-fork test re-verifies field order; re-verify against the live Spoke before adopting a new Spoke implementation |
| Threshold mis-signing below liquidation | `minHealthFactor >= 1e18` enforced |

## Open Questions (Resolved)

| Question | Decision |
|---|---|
| Build + post check or post only | Both |
| Reject `minHealthFactor < 1e18` | Yes |
| New `HEALTH_CHECK` subtype | No — `MISC`, avoid touching shared surfaces |
| Aave identity | Market key + Spoke in body |
| Aave reserve-id sanity checks | Skipped (identity only) |
| `previewHealthFactor` / event | View yes, event no |
| Morpho `placeholder0` | Unvalidated |

## Approval
- [ ] Reviewed by: 
- [ ] Approved by: 

## Next Steps
Deploy with `DeployV2OtherHooks` (`runLoanHooksV2` on Morpho chains, `runAaveV4V2Standalone` on Aave V4 chains);
then piece 2 (leverage loop) and piece 3 (deleverage).
