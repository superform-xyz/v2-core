# Session 7: Aave V4 Loan Hooks

## Goal
Build 6 lending protocol hooks for Aave V4's Hub-and-Spoke architecture on Ethereum mainnet, following the Morpho loan hook patterns.

## Spec
Full spec at: `specs/aave-v4-hooks/technical-spec.md`
Interview notes at: `specs/aave-v4-hooks/interview-notes.md`
Research at: `specs/aave-v4-hooks/research/`

## Key Context
- Aave V4 launched March 30, 2026 on Ethereum mainnet
- Hub-and-Spoke architecture: Hub holds liquidity, Spokes are user-facing
- Share-based accounting (no stataTokens needed)
- Entry point is the Spoke contract (not Pool like V3)
- BLOCKER: Spoke functions protected by `onlyPositionManager(onBehalfOf)` — must verify

## Architecture
```
BaseLoanHook (NONACCOUNTING, ISuperHookLoans)
  └── BaseAaveV4LoanHook (data layout, decode functions)
        ├── AaveV4SupplyHook          (LOAN)
        ├── AaveV4WithdrawHook        (LOAN_REPAY)
        ├── AaveV4BorrowHook          (LOAN)
        ├── AaveV4RepayHook           (LOAN_REPAY)
        ├── AaveV4SupplyAndBorrowHook (LOAN)
        └── AaveV4RepayAndWithdrawHook (LOAN_REPAY)
```

## Data Layout (from technical spec)
```
address loanToken            (position 0)   -- borrowed asset address
address collateralToken      (position 20)  -- collateral asset address
address spoke                (position 40)  -- Aave V4 Spoke address
uint256 supplyReserveId      (position 60)  -- collateral reserve ID
uint256 borrowReserveId      (position 92)  -- loan reserve ID
uint256 amount               (position 124) -- operation amount
bool    usePrevHookAmount    (position 156)
bool    isFullRepayment      (position 157) -- repay hooks only
```

## Aave V4 Spoke Interface
```solidity
function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256);
```

## Reference Implementation
Morpho hooks at `src/hooks/loan/morpho/` — see BaseMorphoLoanHook, MorphoSupplyHook, MorphoBorrowHook, MorphoWithdrawHook, MorphoRepayHook, MorphoSupplyAndBorrowHook, MorphoRepayAndWithdrawHook

## Key Differences from Morpho
1. No constructor args — Spoke address comes from calldata (not constructor)
2. reserveId (uint256) instead of MarketParams (4 addresses)
3. Approval target is Spoke (not Morpho contract)
4. No callback mechanism in Aave V4 Spoke
5. Two reserveIds needed for combined hooks (supply + borrow)

## Status
- [x] Spec complete
- [ ] superform-hook-master planning
- [ ] Phase 0: Resolve Position Manager blocker & create interface
- [ ] Phase 1: BaseAaveV4LoanHook
- [ ] Phase 2: Individual hooks (4)
- [ ] Phase 3: Combined hooks (2)
- [ ] Phase 4: Tests
