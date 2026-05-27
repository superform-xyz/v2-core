# EVM Security Research: WithdrawVestedRFLRHook

## 1. Reentrancy Risks — LOW

- RNat `withdraw` with `wrap=true` transfers WFLR (ERC-20, WETH9-pattern, no callbacks)
- No native FLR sent to smart account (wrap=true wraps before transfer)
- BaseHook has transient storage mutexes on pre/post execute
- RNat is a Flare system contract, not attacker-controlled
- **No additional reentrancy guard needed**

## 2. Safe Casting — P1 HIGH

- `getBalancesOf` returns uint256, `withdraw` takes uint128
- **Must use SafeCast.toUint128()** — already established pattern in codebase
- Cetus Protocol exploit ($223M, May 2025) caused by flawed overflow check — never trust "it will never overflow"

## 3. Balance Snapshot TOCTOU — VERY LOW

- Entire [preExecute, withdraw, postExecute] runs atomically via smart account execute()
- No external actor can inject between snapshot and measurement
- Safe delta pattern handles unexpected balance decreases

## 4. View Function Staleness — LOW-MEDIUM (Accepted)

- `_buildHookExecutions` is `view`, calls `getBalancesOf` at build time
- If more tokens vest between build and execution → conservative (withdraws less)
- Vesting never re-locks, so stale data can only underestimate available amount
- Build should happen close to execution time (bundler responsibility)

## 5. Critical Edge Case: lockedBalance >= rNatBalance

- **CAN happen** after partial vested withdrawals
- Must guard: `if (rNatBalance <= lockedBalance) revert NOTHING_TO_WITHDRAW()`
- Solidity 0.8.30 checked arithmetic catches underflow, but explicit check is clearer

## Must-Have Security Checks

| # | Finding | Severity |
|---|---------|----------|
| 1 | SafeCast.toUint128() for vested amount | P1 High |
| 2 | Revert if rNatBalance <= lockedBalance | P2 Medium |
| 3 | minOut slippage check in _postExecute | P2 Medium |
| 4 | Explicit lockedBalance > rNatBalance guard | P2 Medium |

## Exploit Precedents

| Exploit | Relevance | Our Mitigation |
|---------|-----------|----------------|
| Cetus ($223M, 2025) — silent truncation | uint256→uint128 cast | SafeCast.toUint128() |
| Hedgey ($44.7M, 2024) — faulty input validation | Vesting withdrawal | No user-specified amounts, explicit checks |
| PenPie ($27M, 2024) — reentrancy in reward harvesting | External call to reward contract | Trusted system contract + BaseHook mutexes |

## Recommended Code Pattern

```solidity
(, uint256 rNatBalance, uint256 lockedBalance) = IRNat(RNAT).getBalancesOf(account);
if (rNatBalance <= lockedBalance) revert NOTHING_TO_WITHDRAW();
uint256 vestedAmount = rNatBalance - lockedBalance;
uint128 withdrawAmount = vestedAmount.toUint128();
```
