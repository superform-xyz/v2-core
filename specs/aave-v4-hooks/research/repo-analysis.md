# Repository Research: Lending Protocol Hook Patterns

## Architecture & Inheritance

```
BaseHook (abstract)
  └── BaseLoanHook (abstract)
        └── BaseMorphoLoanHook (abstract)
              ├── MorphoSupplyHook
              ├── MorphoWithdrawHook
              ├── MorphoBorrowHook
              ├── MorphoRepayHook
              ├── MorphoSupplyAndBorrowHook
              ├── MorphoRepayAndWithdrawHook
              └── MorphoLendHook
```

## Key Files
- `src/hooks/BaseHook.sol` — transient storage (usedShares, spToken, asset, executionNonce, lastCaller)
- `src/hooks/loan/BaseLoanHook.sol` — all loan hooks are NONACCOUNTING, shared byte offsets
- `src/hooks/loan/morpho/BaseMorphoLoanHook.sol` — stores morpho address, data layout, decode functions
- `src/vendor/morpho/` — minimal external interfaces

## BaseLoanHook Pattern
- **All loan hooks are `HookType.NONACCOUNTING`** (not INFLOW/OUTFLOW)
- Defines shared offsets: `AMOUNT_POSITION = 80`, `USE_PREV_HOOK_AMOUNT_POSITION = 144`
- Implements `ISuperHookLoans`: getLoanTokenAddress, getCollateralTokenAddress, getLoanTokenBalance, getCollateralTokenBalance
- Loan/collateral addresses at fixed positions (offset 0 and 20) in hook data

## Data Layout (Morpho)
| Field | Offset | Size | Type |
|---|---|---|---|
| loanToken | 0 | 20 | address |
| collateralToken | 20 | 20 | address |
| oracle | 40 | 20 | address |
| irm | 60 | 20 | address |
| amount | 80 | 32 | uint256 |
| lltv | 112 | 32 | uint256 |
| usePrevHookAmount | 144 | 1 | bool |
| isFullRepayment | 145 | 1 | bool |

## Hook Type & SubType Assignments
| Hook | HookType | SubType |
|---|---|---|
| SupplyHook | NONACCOUNTING | LOAN |
| BorrowHook | NONACCOUNTING | LOAN |
| SupplyAndBorrowHook | NONACCOUNTING | LOAN |
| LendHook | NONACCOUNTING | LOAN |
| RepayHook | NONACCOUNTING | LOAN_REPAY |
| WithdrawHook | NONACCOUNTING | LOAN_REPAY |
| RepayAndWithdrawHook | NONACCOUNTING | LOAN_REPAY |

**Important correction:** ALL Morpho loan hooks are NONACCOUNTING (via BaseLoanHook), NOT INFLOW/OUTFLOW as initially discussed in the interview. The interview answers about hook types were incorrect — they should all be NONACCOUNTING with LOAN or LOAN_REPAY subtypes.

## Approval Pattern (P1-1 Security)
1. `approve(protocol, 0)` — reset for USDT-like tokens
2. `approve(protocol, amount)` — exact approval
3. *protocol call*
4. `approve(protocol, 0)` — cleanup

## outAmount Tracking
| Hook | Tracks | Direction |
|---|---|---|
| Supply | Collateral consumed | pre - post |
| Borrow | Loan tokens received | post - pre |
| Repay | Loan tokens consumed | pre - post |
| Withdraw | Loan tokens received | post - pre |
| SupplyAndBorrow | Collateral consumed | pre - post |
| RepayAndWithdraw | Collateral received | post - pre |
| Lend | Supply shares received | post - pre |

## Constructor Pattern
Protocol address passed via constructor, stored in plain storage:
```solidity
constructor(address morpho_, bytes32 hookSubtype_) BaseLoanHook(hookSubtype_) {
    if (morpho_ == address(0)) revert ADDRESS_NOT_VALID();
    morpho = morpho_;
}
```

## Deployment Pattern
- Hook keys in Constants.sol
- Protocol addresses per chain in ConstantsOtherHooks.sol
- Chain mapping in ConfigOtherHooks.sol
- CREATE2 deployment in DeployV2OtherHooks.s.sol
- Bytecode from locked/generated directories

## Test Pattern
- Single test file per protocol with all hooks tested
- Inline mock contracts (MockMorpho, MockOracle, MockIRM)
- Standard categories: constructor, build, build revert, prev hook, pre/post execute, inspector, decode
- Helper encoding functions with abi.encodePacked
