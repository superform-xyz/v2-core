<<<<<<< HEAD
# Session 7: SparkDEX V4 (Algebra Integral) Swap Hook

## Context
Byzantine requested integration with SparkDEX on Flare chain (chainId 14).
The address `0x2a91D9296ee2fe4139b49c7071b2f29f59a9f9aE` is a SparkDEX V4 router built on Algebra Integral.

## Analysis
- Our existing Uniswap V3 hook (`src/hooks/swappers/uniswap-v3/`) is NOT compatible with SparkDEX V4
- SparkDEX V4 uses Algebra Integral which has a different `ExactInputSingleParams` struct:
  - No `fee` field (Algebra uses dynamic fees, pools identified by token pair only)
  - Uses `limitSqrtPrice` instead of `sqrtPriceLimitX96`
  - Different ABI encoding = different function selector = calls would revert

## Task
Create a new SparkDEX V4 swap hook (`src/hooks/swappers/sparkdex-v4/`) following the same pattern as the Uniswap V3 hook but adapted for the Algebra Integral router interface.

## Critical Research Findings
1. SparkDEX V4 uses Algebra Integral v1.2.2, which adds a `deployer` field to `ExactInputSingleParams`
2. The actual V4 SwapRouter address is `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F` (NOT the one Byzantine provided)
3. AlgebraPoolDeployer: `0x59a662Ed724F19AD019307126CbEBdcF4b57d6B1`
4. Hook data layout is 209 bytes (includes deployer field at offset 40)

## Spec Location
`specs/sparkdex-v4-swap-hook/`

## Plan
See `specs/sparkdex-v4-swap-hook/technical-spec.md` for full implementation plan.

### Files to Create
1. `src/hooks/swappers/algebra-integral/interfaces/IAlgebraSwapRouter.sol`
2. `src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol`
3. `src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol`
4. `test/unit/hooks/swappers/algebra-integral/AlgebraIntegralUnitTests.t.sol`
5. Fork integration test

### Files to Update
- `test/utils/Constants.sol` - add hook keys + router addresses
- `script/utils/Constants.sol` - add hook keys

## Changes Made

### Completed
1. **IAlgebraSwapRouter interface** - `src/hooks/swappers/algebra-integral/interfaces/IAlgebraSwapRouter.sol`
   - `ExactInputSingleParams` struct with `deployer` field (Algebra v1.2+)
   - `exactInputSingle` function signature

2. **SwapAlgebraIntegralHook** - `src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol`
   - Swap-only variant (1 execution), assumes tokens pre-approved
   - 209-byte data layout with deployer at offset 40
   - `USE_PREV_HOOK_AMOUNT_POSITION = 208`
   - Recipient forced to account for balance tracking
   - Deadline validation, native ETH rejection

3. **ApproveAndSwapAlgebraIntegralHook** - `src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol`
   - 4-execution variant: approve(0) -> approve(amount) -> swap -> approve(0)
   - Same data layout and decode logic as SwapAlgebraIntegralHook

4. **Constants updated**
   - `test/utils/Constants.sol` - added hook keys + `FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER` + `FLARE_ALGEBRA_POOL_DEPLOYER`
   - `script/utils/Constants.sol` - added `ALGEBRA_INTEGRAL_SWAP_ROUTER_FLARE` + hook keys

5. **Unit tests** - `test/unit/hooks/swappers/algebra-integral/AlgebraIntegralUnitTests.t.sol`
   - 50 tests covering: constructor, decode, build, pre/post execute, inspect, data length,
     slippage recalculation, native ETH rejection, deadline validation, recipient forcing,
     deployer passthrough, fuzz tests
   - All 50 tests pass

6. **Spec directory** - `specs/sparkdex-v4-swap-hook/`
   - interview-notes.md, technical-spec.md, spec.md, research/

7. **Fork integration test** - `test/integration/algebra-integral/AlgebraIntegralFlareE2E.t.sol`
   - 4 E2E tests against real SparkDEX V4 pools on Flare mainnet fork
   - `test_E2E_ApproveAndSwap_WFLR_to_SPRK` — WFLR->SPRK via ApproveAndSwap (WFLR/SPRK pool)
   - `test_E2E_SwapHook_WFLR_to_SPRK` — WFLR->SPRK via SwapHook with pre-approval
   - `test_E2E_ApproveAndSwap_WFLR_to_sFLR` — WFLR->sFLR (different pool, sFLR/WFLR)
   - `test_E2E_ApproveAndSwap_WithUsePrevHookAmount` — chains WFLR->SPRK then SPRK->WFLR with usePrevHookAmount=true
   - All 4 tests pass individually; public Flare RPC rate-limits when running all 4 at once
   - Key finding: WFLR has governance tracking (`updateAtTokenTransfer`) that breaks `deal()`.
     Must acquire WFLR by wrapping native FLR via `IWFLR(FLARE_WFLR).deposit{value: amount}()`
   - Constants added: `FLARE_WFLR`, `FLARE_SFLR`, `FLARE_SPRK` in `test/utils/Constants.sol`

### Pending
- Deployment script updates (DeployV2OtherHooks.s.sol)
=======
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
>>>>>>> 6a7483b29416bb3aa4baa240d33cab93bb72c483
