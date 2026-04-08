# Security Analysis Report

## Metadata
- **Target:** `src/hooks/loan/morpho/` (8 Solidity files + 1 base)
- **Mode:** review
- **Date:** 2026-03-31
- **Contract Types Detected:** Lending hooks (Morpho Blue integration)
- **Files Analyzed:** 9 (BaseMorphoLoanHook, MorphoBorrowHook, MorphoSupplyHook, MorphoWithdrawHook, MorphoSupplyAndBorrowHook, MorphoRepayHook, MorphoRepayAndWithdrawHook, MorphoLendHook, BaseLoanHook)
- **Analysis Sources:** Vulnerability Scanner Agent, Best Practices Agent, EVM Security Researcher Agent

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 1 | Yes |
| P1 High | 3 | Yes |
| P2 Medium | 8 | No |
| P3 Low | 15+ | No |

## Verdict
**FAIL** - 4 blocking findings (1 P0 + 3 P1) must be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

### [P0-1] MorphoWithdrawHook tracks wrong token in pre/post execute
- **File:** `src/hooks/loan/morpho/MorphoWithdrawHook.sol:97-105`
- **SWC:** N/A
- **Category:** Logic
- **Description:** `MorphoWithdrawHook` calls `getCollateralTokenBalance()` in both `_preExecute` and `_postExecute`, but `IMorphoBase.withdraw()` sends **loanToken** (not collateralToken) to the recipient. `BaseLoanHook.getCollateralTokenBalance()` reads the token at data offset 20 (collateralToken), while `getLoanTokenBalance()` reads at offset 0 (loanToken). The `outAmount` computed by this hook is always wrong -- it measures collateral balance changes when it should measure loan token balance changes.
- **Exploit Scenario:** Any hook chained after `MorphoWithdrawHook` that reads `getOutAmount()` (via `usePrevHookAmount`) will receive an incorrect value (likely 0 or garbage), causing downstream operations to use wrong amounts. This breaks hook composability entirely for lender-side withdraw flows.
- **Vulnerable Code:**
```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(getCollateralTokenBalance(account, data), account); // WRONG: should be getLoanTokenBalance
}

function _postExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account); // WRONG
}
```
- **Secure Pattern:**
```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(getLoanTokenBalance(account, data), account);
}

function _postExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(getLoanTokenBalance(account, data) - getOutAmount(account), account);
}
```
- **Note:** The post-execute subtraction order also needs to match MorphoBorrowHook pattern (new - old) since withdraw increases loanToken balance.

---

## P1 Findings (High - Must Fix)

### [P1-1] Missing trailing approve(0) cleanup in supply/lend hooks
- **File:** `src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol:92-125`
- **File:** `src/hooks/loan/morpho/MorphoSupplyHook.sol:68-110`
- **File:** `src/hooks/loan/morpho/MorphoLendHook.sol:92-137`
- **SWC:** SWC-114
- **Category:** Token
- **Description:** `MorphoRepayHook` and `MorphoRepayAndWithdrawHook` correctly include a trailing `approve(morpho, 0)` execution to reset the allowance after the Morpho operation. However, `MorphoSupplyAndBorrowHook`, `MorphoSupplyHook`, and `MorphoLendHook` do NOT include this cleanup. If the Morpho operation reverts partially or consumes less than the approved amount, a dangling allowance remains on the smart account, creating a token drain risk.
- **Exploit Scenario:** If `supplyCollateral` or `supply` reverts after the approval is set (e.g., due to market being paused, or a Morpho callback revert), the Morpho contract retains a non-zero allowance from the smart account. A subsequent transaction could exploit this allowance.
- **Vulnerable Code (MorphoSupplyAndBorrowHook):**
```solidity
// Only 4 executions: approve(0), approve(amount), supplyCollateral, borrow
// No trailing approve(0) cleanup
```
- **Secure Pattern (following MorphoRepayHook):**
```solidity
// 5 executions: approve(0), approve(amount), supplyCollateral, borrow, approve(0)
executions[4] = Execution({
    target: vars.collateralToken,
    value: 0,
    callData: abi.encodeCall(IERC20.approve, (morpho, 0))
});
```

### [P1-2] Repay front-running vulnerability
- **File:** `src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol:90-139`
- **File:** `src/hooks/loan/morpho/MorphoRepayHook.sol:57-128`
- **SWC:** N/A
- **Category:** MEV
- **Description:** Morpho's own documentation warns: "An attacker can front-run a repay with a small repay making the transaction revert for underflow." For full repayment, `MorphoRepayAndWithdrawHook` reads current share balance via `deriveShareBalance()` and passes it as the shares parameter. An attacker can front-run by repaying a tiny amount on behalf of the user (Morpho allows anyone to `repay` on behalf), reducing the user's borrow shares. The user's transaction then tries to repay shares that no longer exist, causing an underflow revert.
- **Exploit Scenario:** Attacker monitors mempool for repay transactions. Before the victim's full repayment executes, attacker repays 1 wei of shares on the victim's behalf. The victim's transaction now tries to repay N shares but only N-1 exist, causing revert.
- **Mitigation:**
  1. For full repayment, use `type(uint256).max` as the shares parameter (if Morpho supports it as "repay all")
  2. Add slippage tolerance to the share amount
  3. Use private mempools (Flashbots) for repayment transactions
  4. Document this as a known limitation for off-chain bundler handling

### [P1-3] Stale interest accrual between build and execute (TOCTOU)
- **File:** `src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol:90-139`
- **SWC:** N/A
- **Category:** Logic
- **Description:** `_buildHookExecutions()` is a `view` function that reads share-to-asset conversions BEFORE interest is accrued. `_preExecute()` then calls `accrueInterest()` which changes `totalBorrowAssets/totalBorrowShares`. If significant time passes between `build()` and execution, or another transaction accrues interest in between, the approval amounts computed in `build()` become stale. For full repayment, the approval amount may be insufficient to cover the actual debt after interest accrual.
- **Mitigation:**
  1. Add a buffer (e.g., 0.1-1%) to approval amounts in `build()` for interest accrual
  2. For full repayment, compute approval as `sharesToAssets() * 101 / 100` (1% buffer)
  3. Document that `build()` outputs have a limited validity window
  4. The off-chain bundler should execute UserOps promptly after building

---

## P2 Findings (Medium - Should Fix)

### [P2-1] MorphoSupplyAndBorrowHook outAmount tracks supply shares instead of borrowed amount
- **File:** `src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol:174-184`
- **Category:** Logic
- **Description:** `_preExecute` stores `getCollateralTokenBalance` and `_postExecute` computes `pre - post` (collateral decrease = amount supplied). However, this combined hook performs both supply AND borrow. The `outAmount` reflects collateral consumed, not loan tokens received. A chained hook expecting `outAmount` to be the borrowed USDC amount would get the wrong value.
- **Mitigation:** Document clearly what `outAmount` represents for this hook, or track the loanToken balance increase instead.

### [P2-2] Underflow risk in postExecute balance-delta calculations
- **File:** `src/hooks/loan/morpho/MorphoSupplyHook.sol:140`
- **File:** `src/hooks/loan/morpho/MorphoBorrowHook.sol:142`
- **File:** `src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol:180`
- **Category:** Arithmetic
- **Description:** Post-execute computes `preBalance - postBalance` (or vice versa). If the balance moved in an unexpected direction (airdrop, rebasing token, concurrent tx), Solidity 0.8.30 checked math causes revert. The entire UserOperation fails.
- **Mitigation:** Use safe subtraction: `a > b ? a - b : 0`, or add explicit directional validation.

### [P2-3] Stale approval in full repayment (MorphoRepayHook)
- **File:** `src/hooks/loan/morpho/MorphoRepayHook.sol:80-82`
- **Category:** Logic
- **Description:** For `isFullRepayment`, `sharesToAssets()` is called during `build()` to determine approval amount. Interest accrual between build and execute may cause the actual repayment amount to exceed the approved amount, causing the repay to revert. Same issue as P1-3 but specific to RepayHook.
- **Mitigation:** Add interest buffer to full repayment approval amount.

### [P2-4] Stale approval in full repayment (MorphoRepayAndWithdrawHook)
- **File:** `src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol:99-101`
- **Category:** Logic
- **Description:** Same as P2-3 but for the combined repay+withdraw hook.

### [P2-5] Division by zero in partial repayment
- **File:** `src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol:180-193`
- **Category:** Arithmetic
- **Description:** `deriveCollateralForPartialRepayment()` computes `Math.mulDiv(fullCollateral, amount, fullLoanAmount)`. If `fullLoanAmount` is 0 (edge case: position has collateral but no borrow), this divides by zero and reverts with an opaque error.
- **Mitigation:** Add `if (fullLoanAmount == 0) revert NO_OUTSTANDING_DEBT()` before the division.

### [P2-6] Redundant storage variables across all hooks
- **File:** All 8 hook files
- **Category:** Gas
- **Description:** `BaseMorphoLoanHook` stores `IMorpho morphoInterface`. Every child redundantly stores `address morpho` and `IMorphoBase morphoBase`. `morphoBase` is declared in all 7 children but never read. This wastes 1-3 storage slots per child contract.
- **Mitigation:** Consolidate to a single `address public morpho` in the base contract. Remove `morphoBase` entirely. Cast to specific interfaces at call sites.

### [P2-7] Inconsistent address validation across hooks
- **File:** `src/hooks/loan/morpho/MorphoRepayHook.sol:69`
- **File:** `src/hooks/loan/morpho/MorphoRepayAndWithdrawHook.sol:78`
- **File:** `src/hooks/loan/morpho/MorphoSupplyAndBorrowHook.sol:84`
- **Category:** Logic
- **Description:** `MorphoBorrowHook` and `MorphoSupplyHook` validate all 4 addresses (loanToken, collateralToken, oracle, irm). `MorphoRepayHook`, `MorphoRepayAndWithdrawHook`, and `MorphoSupplyAndBorrowHook` only validate loanToken and collateralToken, skipping oracle and irm.
- **Mitigation:** Standardize all hooks to validate all 4 address fields.

### [P2-8] Inconsistent data length validation
- **File:** All hooks except MorphoLendHook
- **Category:** Logic
- **Description:** Only `MorphoLendHook` validates `data.length < MIN_DATA_LENGTH` before decoding. All other hooks skip this check. Short data causes low-level BytesLib reverts that are hard to debug.
- **Mitigation:** Add `MIN_DATA_LENGTH` validation to all decode functions.

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Unused constants in 3 hooks
- `PRICE_SCALING_FACTOR` and `PERCENTAGE_SCALING_FACTOR` declared but never used in MorphoBorrowHook, MorphoRepayHook, MorphoRepayAndWithdrawHook.

### [P3-2] Code duplication: identical BorrowHookLocalVars struct and _decodeBorrowHookData
- Duplicated between MorphoBorrowHook and MorphoSupplyAndBorrowHook. Should be in BaseMorphoLoanHook.

### [P3-3] Unused import: HookDataDecoder imported but never used
- All 8 Morpho hook files import and declare `using HookDataDecoder for bytes` but no HookDataDecoder methods are called.

### [P3-4] Duplicate imports from same file
- `ISuperHookResult` and `ISuperHookInspector` imported separately from `ISuperHook.sol`. Should be consolidated.

### [P3-5] Unused error: LTV_RATIO_NOT_VALID in MorphoBorrowHook
- Declared at line 51 but never referenced. Only used in MorphoSupplyAndBorrowHook.

### [P3-6] Redundant morphoInterface reassignment
- MorphoRepayHook and MorphoRepayAndWithdrawHook re-assign `morphoInterface` in their constructors, already set by BaseMorphoLoanHook.

### [P3-7] Missing NatSpec across hooks
- BaseMorphoLoanHook missing contract-level NatSpec
- Multiple constructors undocumented (all except MorphoLendHook)
- `_preExecute`/`_postExecute` missing `@inheritdoc` in most hooks
- `_buildHookExecutions` missing NatSpec in 6 hooks
- Public functions `deriveShareBalance`/`sharesToAssets` undocumented in MorphoRepayHook

### [P3-8] Magic numbers in byte offsets
- Raw numbers (0, 20, 40, 60, 80, 112, 144, 145) used directly. Should use named constants.

### [P3-9] Transient storage composability note
- Hooks use empty callback data `""` to Morpho, preventing callback reentrancy. This is correct but should be documented as a security invariant.

### [P3-10] Rounding in partial repayment favors protocol
- `Math.mulDiv` rounds down by default. This is acceptable (protocol-favorable) but should be documented.

### [P3-11] Borrow share manipulation in low-liquidity markets
- Morpho docs warn about sub-1e4 market manipulation. Off-chain bundler should refuse thin markets.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view), `_preExecute()`, `_postExecute()`, `inspect()`, `getOutAmount()`, public view functions (`deriveShareBalance`, `sharesToAssets`, `deriveLoanAmount`, `deriveCollateralForPartialRepayment`)
- **Value Transfer Points:** All hooks generate `Execution[]` arrays executed by smart accounts -- token approvals, Morpho supply/borrow/repay/withdraw calls
- **Oracle Dependencies:** `MorphoSupplyAndBorrowHook.deriveLoanAmount()` calls `IOracle(oracle).price()` -- oracle address from user-supplied data, validated at Morpho market level
- **Cross-Contract Interactions:** Morpho Blue (`supply`, `supplyCollateral`, `borrow`, `repay`, `withdraw`, `withdrawCollateral`, `accrueInterest`), ERC20 tokens (`approve`, `balanceOf`)
- **Transient Storage:** `outAmount` per account, execution mutexes -- cleared per-hook-execution

---

## Coding Standards Findings

6 P2 Medium issues (redundant storage, unused storage, missing NatSpec on public functions, inconsistent data validation, code duplication, inconsistent address validation) and 15+ P3 Low issues (NatSpec, naming, imports, magic numbers, style). See Best Practices Agent output for full details.

---

## Security Knowledge Sources
- **Vulnerability Scanner:** Cross-referenced code against balance tracking, approval patterns, arithmetic safety
- **Best Practices:** Checked NatSpec, imports, storage optimization, validation consistency, code duplication
- **EVM Security Research:** Morpho Blue $230K oracle exploit (Oct 2024), OWASP SC Top 10 (2025), Morpho risk documentation, ChainSecurity TSTORE analysis, Certora rounding research, SWC-114 approval race conditions
