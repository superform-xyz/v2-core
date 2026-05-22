# SpecFlow Analysis: ForceDeallocateMorphoHook

## Critical Gaps Identified

### 1. Penalty Enforcement Mechanism (CRITICAL)
- `penaltyShares` is a return value from `forceDeallocate()` — hook cannot read Execution return values
- **Resolution**: Pre-check via `vault.forceDeallocatePenalty(adapter)` in `_buildHookExecutions` (static view call)
- Formula: `vault.forceDeallocatePenalty(adapter) / 1e14 > maxPenaltyBps` → revert

### 2. BPS vs WAD Unit Inconsistency (CRITICAL)
- Vault uses WAD (1e18), hook param named `maxPenaltyBps` implies BPS (0-10000)
- **Resolution**: `maxPenaltyBps` is in BPS. Convert: `penaltyWAD / 1e14 = penaltyBps`

### 3. Token for ApproveAndForce Variant (CRITICAL)
- `forceDeallocate` does NOT pull tokens from caller — it moves assets internally
- Penalty burns vault SHARES from `onBehalf` via internal `withdraw()`
- **Resolution**: Approve variant may approve vault shares to vault (safety measure for penalty share burn if allowance needed). Or may not be needed — verify in fork tests.

### 4. outAmount Semantics (IMPORTANT)
- **Resolution**: `outAmount = assets` (the extraction amount)

### 5. Deadline Check Location (IMPORTANT)
- **Resolution**: In `_buildHookExecutions` following SwapAlgebraIntegralHook pattern

### 6. HookSubType (IMPORTANT)
- **Resolution**: `HookSubTypes.MISC` (same as MetaMorphoReallocateHook)

### 7. Constructor (IMPORTANT)
- **Resolution**: No parameters (stateless, vault address in hook data)

## Complete Flow Permutation Matrix

| Scenario | usePrevHookAmount | Penalty | Deadline | Expected |
|---|---|---|---|---|
| Normal extraction | false | within tolerance | valid | Success |
| Chained from prev hook | true | within tolerance | valid | Success |
| Zero penalty adapter | false | 0 | valid | Success, no shares burned |
| Penalty exceeds max | false | > maxPenaltyBps | valid | Revert PENALTY_TOO_HIGH |
| Expired deadline | false | any | expired | Revert EXPIRED_DEADLINE |
| Unregistered adapter | false | N/A | valid | Vault-level revert |
| Insufficient shares | false | high | valid | Vault-level revert |
| assets = 0 | false | N/A | valid | Revert AMOUNT_NOT_VALID |
| vault = address(0) | false | N/A | valid | Revert ADDRESS_NOT_VALID |
| adapter = address(0) | false | N/A | valid | Revert ADDRESS_NOT_VALID |
| maxPenaltyBps = 0 + penalty > 0 | false | > 0 | valid | Revert (zero tolerance) |
