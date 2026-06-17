# Session 19: Complete Sizing Interface for All Remaining Hooks

## Status: COMPLETE
- Date: 2026-06-17

## Overview
Completed the sizing interface migration for all 31 remaining S3 hooks, bringing the total to zero S3 hooks. Every hook now explicitly declares its sizing capability as either S1 (sizable) or S2 (authoritatively sizeless).

## Changes Made

### Task 1: ForceDeallocateMorphoHook → S1 (sizable)
**File:** `src/hooks/vaults/metamorpho/ForceDeallocateMorphoHook.sol`
- Added `ISuperHookInflowOutflow, ISuperHookOutflow` to imports and inheritance
- Implemented `decodeAmounts()` → reads uint256 at ASSETS_OFFSET (72)
- Implemented `amountRoles()` → 1 entry: Direction.IN, Denomination.TOKEN
- Overrode `_supportsSizingInterface()` → true
- Implemented `replaceCalldataAmounts()` → writes at ASSETS_OFFSET (72)

### Task 2: 5 Opaque-Blob Hooks → S2
Each got `ISuperHookInflowOutflow` in inheritance + empty `decodeAmounts()`, `amountRoles()`, and custom `supportsInterface()` (true for InflowOutflow, false for Outflow):
- `src/hooks/swappers/pendle/PendleUnifiedHook.sol`
- `src/hooks/swappers/spectra/SpectraExchangeDepositHook.sol`
- `src/hooks/swappers/1inch/Swap1InchHook.sol`
- `src/hooks/tokens/BatchTransferHook.sol`
- `src/hooks/bridges/circle/CircleGatewayMinterHook.sol`

### Task 3: 25 Sizeless Hooks → S2
Same S2 pattern applied via Python script to all 25 hooks:
- 4 oracle hooks (RecordPurchase/RedemptionPendlePT V1/V2)
- 3 flare claim hooks (ClaimRFLR, WithdrawRFLR, WithdrawVestedRFLR)
- 8 7540 cancel/claim hooks
- 3 admin/config hooks (SetOperator7540, SetSlippage, MarkRootAsUsed)
- 7 other hooks (DeBridgeCancel, CircleGatewayAddDelegate, CircleGatewayRemoveDelegate, OfframpTokens, EthenaUnstake, MetaMorphoReallocate, PendleRouterSwap)

### Task 4: Tests Updated
**File:** `test/unit/hooks/HookSizingInterface.t.sol`
- Added imports for all 31 new hooks
- Added state variables and setUp deployments
- Added `test_ForceDeallocateMorpho_*` tests (5 tests): supportsInterface, decodeAmounts, amountRoles, roundtrip, revert on wrong length
- Added `test_NewlyS2_*` tests (4 tests): SupportsInterface_InflowOutflow, DoesNotSupport_Outflow, AmountRoles_Empty, DecodeAmounts_Empty
- All 215 tests pass

## Three-State Detection After This PR
- **S1**: Hooks where `supportsInterface(ISuperHookInflowOutflow) == true` AND `amountRoles().length > 0` — bundler can resize
- **S2**: Hooks where `supportsInterface(ISuperHookInflowOutflow) == true` AND `amountRoles().length == 0` — bundler knows nothing to resize
- **S3**: Zero hooks remaining — every hook explicitly declares its sizing capability

### Task 5: Manifest Alignment (Superform OS 2.0)
Fixed alignment between on-chain Solidity implementation and off-chain manifest/classification system.

**Problem:** All 30 S2 hooks had `legSizing: [sized]` in `hook-classification.yaml`, were missing from `sizelessHooks` in `hook-enrichment.yaml`, and had no `amountMeta` override (defaulting to `[{IN, TOKEN}]` instead of `[]`).

**Files changed:**
- `tooling/hook-classification.yaml` — Changed `legSizing: [sized]` → `legSizing: []` for all 30 S2 hooks, with descriptive comments
- `tooling/hook-enrichment.yaml` — Added 30 hooks to `sizelessHooks` list and `amountMeta` overrides (empty `[]`)
- `manifests/hooks.json` — Regenerated via `python tooling/generate_hook_manifest.py`

**Manifest distribution after fix:**
- S1 (sized, both interfaces): 83 hooks
- S2 (sizeless, InflowOutflow only): 37 hooks
- S3 (no interfaces): 0 hooks

## Verification
- `forge build` — Compiler run successful
- `forge test --match-contract HookSizingInterfaceTest` — 215 tests passed, 0 failed
- Manifest regenerated — 120 hooks, 0 S3 remaining
