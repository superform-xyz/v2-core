# Aave V4 Hooks - Interview Notes

**Date:** 2026-04-21
**Feature:** Aave V4 Supply, Withdraw, Borrow, Repay hooks for Hub-and-Spoke architecture

## Context

Aave V4 launched on Ethereum mainnet (March 30, 2026) with a new Hub-and-Spoke architecture:
- **Hub**: Immutable central liquidity layer holding all assets, share-based accounting
- **Spokes**: Upgradeable user-facing modules with own risk settings
- V4 moves FROM rebasing aTokens TO ERC-4626-style share-based accounting
- stataTokens (V3 ERC-4626 wrappers) are NOT needed for V4
- Entry point is the Spoke contract, not a Pool contract

## Decisions

### Hook Scope
**Full set (6 hooks)** mirroring Morpho — ALL NONACCOUNTING (per BaseLoanHook pattern):
1. AaveV4SupplyHook (NONACCOUNTING, LOAN) - approve + supply collateral to Spoke
2. AaveV4WithdrawHook (NONACCOUNTING, LOAN_REPAY) - withdraw from Spoke
3. AaveV4BorrowHook (NONACCOUNTING, LOAN) - borrow from Spoke
4. AaveV4RepayHook (NONACCOUNTING, LOAN_REPAY) - approve + repay on Spoke
5. AaveV4SupplyAndBorrowHook (NONACCOUNTING, LOAN) - combined supply + borrow
6. AaveV4RepayAndWithdrawHook (NONACCOUNTING, LOAN_REPAY) - combined repay + withdraw

### Spoke Target
**Generic** - hooks work with any Spoke address passed as yieldSource (Core, e-Mode, Isolation, RWA, Vault Spokes)

### Data Layout
**Follow Morpho pattern** - reserveId as a separate uint256 field in calldata, similar to how Morpho encodes market params

### Chain Scope
**Ethereum only** initially - deploy on chain 1 only, extend when Aave V4 expands to other chains

### Accounting
**CORRECTION**: Per BaseLoanHook pattern, ALL loan hooks are NONACCOUNTING (not INFLOW/OUTFLOW). They track outAmount via balance deltas in pre/post execute, similar to Morpho hooks. The SuperLedger is not directly updated by loan hooks.

### Risk Premium
**Pass-through** - Aave V4's User Risk Premium is handled internally by the Spoke. No special handling needed in hooks.

### Native ETH
**WETH only** - users must wrap ETH before using hooks. Can chain with existing WrapNativeHook.

### Hook Types (corrected — mirroring Morpho BaseLoanHook)
ALL hooks are NONACCOUNTING. SubTypes:
- Supply: NONACCOUNTING + LOAN
- Borrow: NONACCOUNTING + LOAN
- SupplyAndBorrow: NONACCOUNTING + LOAN
- Repay: NONACCOUNTING + LOAN_REPAY
- Withdraw: NONACCOUNTING + LOAN_REPAY
- RepayAndWithdraw: NONACCOUNTING + LOAN_REPAY

### Approvals
**Include approve step** - supply and repay hooks include ERC20.approve(spoke, amount) in their executions (self-contained)

### Interface
**Own minimal interface** - create IAaveV4Spoke.sol in src/vendor/ with only the functions we need

### Trust Model
**Trust Aave governance** - standard DeFi trust assumption, no additional safeguards needed

## Aave V4 Key Interface (Spoke)

```solidity
function supply(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256, uint256)
function withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256)
function borrow(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256)
function repay(uint256 reserveId, uint256 amount, address onBehalfOf) external returns (uint256)
```

## Data Layout Design

Following Morpho BaseLoanHook pattern (addresses at fixed positions for ISuperHookLoans):
```
address loanToken            (position 0)   -- borrowed asset address
address collateralToken      (position 20)  -- collateral asset address
address spoke                (position 40)  -- Aave V4 Spoke address
uint256 reserveId            (position 60)  -- Aave V4 reserve identifier within the Spoke
uint256 amount               (position 92)  -- supply/borrow/withdraw/repay amount
bool    usePrevHookAmount    (position 124)
bool    isFullRepayment      (position 125) -- repay hooks only
```
Note: loanToken and collateralToken positions (0, 20) are required by BaseLoanHook/ISuperHookLoans interface.

## Testing Strategy
- Unit tests for each hook (build, revert cases, pre/post execute, decode, inspector)
- Integration tests against Aave V4 on Ethereum mainnet fork
- E2E tests for full supply+withdraw and borrow+repay flows
