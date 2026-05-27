# Framework Docs Research: Flare RNat, SafeCast, WFLR

## RNat `withdraw(uint128 _amount, bool _wrap)` Behavior

- **Vested-only withdrawal.** Reverts if `_amount > balance - locked`. No penalty.
- Non-reward balance is consumed first; rNat rewards debited only when non-reward balance is insufficient.
- No partial fill or silent truncation — hard revert on excess.

## Is `withdraw(vestedAmount, true)` Penalty-Free?

**Yes, guaranteed penalty-free** when `vestedAmount = rNatBalance - lockedBalance`, because `withdraw` enforces `balance - locked >= _amount` which is exactly the same computation.

## Edge Case: `lockedBalance >= rNatBalance`

**This CAN happen** after partial vested withdrawals. When a user withdraws vested tokens:
- `rNatBalance` decreases (tokens withdrawn)
- `lockedBalance` remains unchanged (locked rewards untouched)

So after withdrawing, `lockedBalance >= rNatBalance` is possible. Code MUST handle this:
```solidity
uint256 vestedAmount = rNatBalance > lockedBalance ? rNatBalance - lockedBalance : 0;
```
If vestedAmount == 0, revert with custom error per interview decision.

## Vesting Schedule

Rolling linear vest: each monthly reward allocation vests independently over 12 months.
```
locked_for_month_m = rewards[m] * (12_months + month_m_start - now) / 12_months
```
NOT a single cliff — each month's rewards have their own schedule.

## Reentrancy on RNat

| Function | Guard |
|----------|-------|
| `claimRewards` | `nonReentrant` |
| `withdraw` | `mustBalance` (NOT reentrancy guard) |
| `withdrawAll` | `mustBalance` (NOT reentrancy guard) |

`mustBalance` is a balance invariant check, not reentrancy protection. Actual withdrawal uses `transfer()` (2300 gas stipend) which limits but doesn't eliminate reentrancy risk.

## WFLR Token

- WETH9-compatible wrapped native token
- Standard ERC-20 with Flare delegation extensions
- When `withdraw(amount, true)` called, RNat wraps native FLR into WFLR before sending
- Trackable via `IERC20(WFLR).balanceOf(account)`

## SafeCast

Already used in codebase. Pattern:
```solidity
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
using SafeCast for uint256;
uint128 amount = someUint256Value.toUint128(); // reverts on overflow
```

## Summary

| Question | Answer |
|----------|--------|
| `withdraw` penalty-free? | Yes, vested only |
| `lockedBalance > rNatBalance`? | Yes, after partial withdrawals |
| Revert on excess? | Yes, hard revert |
| Reentrancy guard? | No (only `mustBalance`) |
| SafeCast available? | Yes, already in codebase |
