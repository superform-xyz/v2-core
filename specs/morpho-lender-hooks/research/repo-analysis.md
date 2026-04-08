# Repo Analysis: MorphoLendHook

## Key Findings

### Inheritance Chain
BaseLoanHook forces HookType.NONACCOUNTING (line 25). All Morpho hooks inherit this.
MorphoLendHook will be NONACCOUNTING initially (no oracle yet).

### Data Layout (same as MorphoSupplyHook)
- loanToken(20)|collateralToken(20)|oracle(20)|irm(20)|amount(32)|lltv(32)|usePrevHookAmount(1)
- Amount at offset 80, usePrevHookAmount at offset 144

### Key Code References
- BaseLoanHook: src/hooks/loan/BaseLoanHook.sol:25 (NONACCOUNTING)
- BaseMorphoLoanHook: src/hooks/loan/morpho/BaseMorphoLoanHook.sol:73-91 (_generateMarketParams)
- MorphoSupplyHook: src/hooks/loan/morpho/MorphoSupplyHook.sol:84-97 (execution pattern)
- HookSubTypes.LOAN: src/libraries/HookSubTypes.sol:21

### outAmount Tracking
- MorphoSupplyHook: tracks collateralToken balance decrease (pre - post)
- MorphoLendHook: should track loanToken balance decrease (pre - post)
- Helper: BaseLoanHook.getLoanTokenBalance(account, data) at line 55-58

### MorphoWithdrawHook Bug
- Calls IMorphoBase.withdraw() (correct for lender withdrawal)
- BUT _preExecute/_postExecute track getCollateralTokenBalance (wrong for lending)
- This means outAmount = 0 for lending withdrawals
- Need new MorphoLendWithdrawHook that tracks loanToken balance
