# WithdrawVestedRFLRHook Interview Notes

**Date:** 2026-05-26
**Interviewer:** Claude
**Interviewee:** Cosmin (Pod Lead)

## Feature Summary

Create a new `WithdrawVestedRFLRHook` that withdraws only the vested (unlocked) rFLR from Flare's RNat contract, avoiding the 50% penalty on locked tokens. The existing `WithdrawRFLRHook` calls `withdrawAll(true)` which burns 50% of unvested tokens. This new hook uses `withdraw(uint128, bool)` combined with `getBalancesOf()` to calculate and withdraw only the penalty-free vested portion.

## Context

- The RNat contract has two withdrawal methods:
  - `withdrawAll(bool wrap)` — withdraws everything, 50% penalty on locked portion
  - `withdraw(uint128 amount, bool wrap)` — withdraws specific amount, no penalty if amount <= vested
- `getBalancesOf(address)` returns `(wNatBalance, rNatBalance, lockedBalance)`
- Vested amount = `rNatBalance - lockedBalance`
- Full RNat interface: https://github.com/flare-foundation/flare-foundry-periphery-package/blob/main/src/flare/IRNat.sol

## Technical Decisions

### Amount Strategy
**Decision:** Always withdraw the exact vested amount (`rNatBalance - lockedBalance`)
**Rationale:** Simpler design, mirrors the `withdrawAll` pattern of the existing hook. No user-specified amount parameter needed.

### Zero Balance Handling
**Decision:** Revert with a custom error if vested amount is 0
**Rationale:** Fail explicitly so the caller knows nothing was withdrawn, rather than silently succeeding.

### Output Token
**Decision:** WFLR only (`wrap=true`)
**Rationale:** Same as existing `WithdrawRFLRHook` — simpler, ERC20-compatible output for chaining with other hooks.

### Slippage Protection
**Decision:** Keep minOut check in hook data
**Rationale:** Defensive measure against unexpected RNat contract behavior changes, even though vested withdrawal should be deterministic.

### uint128 Safe Cast
**Decision:** Add safe cast check
**Rationale:** `getBalancesOf()` returns `uint256` values but `withdraw()` takes `uint128`. Add defensive check even though rFLR supply is far below uint128.max.

### Deployment Strategy
**Decision:** Deploy alongside existing `WithdrawRFLRHook` (both available)
**Rationale:** Curators choose based on whether they want full withdrawal (with penalty) or vested-only withdrawal (penalty-free).

### MEV / Front-running
**Decision:** Document assumption in NatSpec
**Rationale:** RNat vesting is time-based (Flare system contract), not manipulable by third parties. Document this assumption for auditors.

## Interface Changes Required

- Add `withdraw(uint128 _amount, bool _wrap)` to `src/vendor/flare/IRNat.sol`

## Data Layout

- `[0:32]` uint256 minOut — minimum WFLR delta the caller will accept. If zero, no slippage check.

## Acceptance Criteria

- [ ] `IRNat.sol` interface updated with `withdraw(uint128, bool)` function
- [ ] New `WithdrawVestedRFLRHook.sol` created alongside existing hook
- [ ] Hook calculates vested amount via `getBalancesOf()` as `rNatBalance - lockedBalance`
- [ ] Hook calls `withdraw(vestedAmount, true)` to withdraw only vested tokens
- [ ] Reverts with custom error if vested amount is 0
- [ ] Safe cast from uint256 to uint128 with revert on overflow
- [ ] minOut slippage check supported via hook data
- [ ] NatSpec documents no-penalty guarantee and MEV assumption
- [ ] Unit tests covering: normal withdrawal, zero vested revert, slippage check, uint128 overflow
- [ ] Hook added to deploy scripts (`regenerate_bytecode.sh`, `DeployV2OtherHooks` or equivalent)
- [ ] Bytecode generated and copied to locked-bytecode folders
