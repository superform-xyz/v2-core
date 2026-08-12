# Migration Runbook — Pendle PT Record Hooks + PendlePTHook redeploy (F1)

**Why:** `PendlePTHook`'s creation bytecode changed (added `getPendleTradeResult`). The record hooks
(`RecordPurchasePendlePTHook`, `RecordRedemptionPendlePTHook`) pin the PendlePTHook via an **immutable**
constructor arg, so they must be deployed *after* the new PendlePTHook exists and *bound to its new
address*. The currently-recorded prod `0xb37CBfCd…` (8 chains) and staging `0xCDBaC0d3…` (5 chains)
addresses do **not** expose `getPendleTradeResult` and must be replaced.

Deployed via `script/run/deploy/deploy_v2_staging_prod.sh` → `DeployV2Core.s.sol:DeployV2Core`.

## Preconditions (already done in this PR)
- New bytecode locked for all three contracts: `PendlePTHook`, `RecordPurchasePendlePTHook`,
  `RecordRedemptionPendlePTHook` — synced across `generated-bytecode/`, `locked-bytecode/` (prod),
  `locked-bytecode-dev/` (staging); verified `generated == locked == locked-dev` per contract.
- Deploy wiring binds the record hooks to the **V1** oracle (`configuration.pendlePTAmortizedOracles`)
  and resolves `approvedPendlePTHook` env-specifically: `_resolveApprovedPendlePTHook(chainId, env, …)`
  computes the new PendlePTHook CREATE2 address (per-env salt + per-env locked bytecode) and
  cross-checks it against `script/output/{prod|staging}/…`, warning if the recorded address is stale.

## Sequence (per environment: prod = env 0, staging = env 2)
1. **Redeploy PendlePTHook** on all target chains (prod: 8, staging: 5) with the new bytecode.
   Deterministic CREATE2 → new env-specific address (differs from the old one because bytecode changed).
2. **Regenerate the env output** (`script/output/{prod|staging}/{chainId}/*-latest.json`) so `.PendlePTHook`
   holds the NEW address. After this step, `_resolveApprovedPendlePTHook` logs "env output confirmed"
   (recorded == computed) instead of the STALE warning.
3. **Deploy the two record hooks**, bound to the new PendlePTHook. The resolver already binds to the new
   computed address even if step 2 lagged, but do step 2 first so records are consistent.
4. **Regenerate `manifests/hooks.json`** AFTER deployment — replace the old PendlePTHook addresses
   (`manifests/hooks.json:4699+` prod, `:4692-4696` staging) and add the two record-hook address maps.
5. **Per-chain bytecode verification**: confirm on-chain code at each new address matches the locked
   artifact (prod → `locked-bytecode/`, staging → `locked-bytecode-dev/`).
6. **Orphan hygiene**: the old `0xb37C…` / `0xCDBaC…` PendlePTHook instances (and any never-whitelisted
   predecessors, e.g. `0x265f…`) are now orphaned — do not register; leave for historical decoding only.
7. **Merkle / registry re-propose** with the NEW addresses (downstream, D1).

## Downstream (not in this repo)
- erebor registry entries for both record hooks + the bundling chain (PendlePTHook root →
  RecordPurchase `next_required`, RecordRedemption same-seq alternate). NONE→NONE PASSTHROUGH hooks must
  not be offered as lane roots.
- OMS auto-mode params: `usePrevHookAmount=true`, `amount=0`, `twapDuration=900` (= the V1 oracle minimum).
- **New V1-only onboarding constraint:** only offer markets where `PT.decimals() == SY.assetInfo().assetDecimals`
  — the record hook now reverts `DECIMALS_MISMATCH` otherwise (V1 oracle unit invariant).
- Registry-side deprecation flag for the retained legacy `…AmortizedOracleHook{,V2}` hooks (F6).

## Permanent coupling
Any future `PendlePTHook` redeploy changes its address → **both record hooks must be redeployed too**
(immutable binding). Keep steps 1–4 together whenever PendlePTHook changes.
