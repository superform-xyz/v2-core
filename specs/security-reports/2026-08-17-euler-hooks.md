# Security Review: Euler V2 Lending Hooks

**Date:** 2026-08-17
**Reviewer:** Claude Code Security Review (3-agent parallel analysis)
**Scope:** Euler V2 lending hook contracts for Superform v2-core

## Contracts Analyzed

| Contract | Path |
|----------|------|
| EulerDepositCollateralHook | `src/hooks/loan/euler/EulerDepositCollateralHook.sol` |
| EulerBorrowHook | `src/hooks/loan/euler/EulerBorrowHook.sol` |
| EulerRepayHook | `src/hooks/loan/euler/EulerRepayHook.sol` |
| EulerWithdrawCollateralHook | `src/hooks/loan/euler/EulerWithdrawCollateralHook.sol` |
| EulerDepositCollateralAndBorrowHook | `src/hooks/loan/euler/EulerDepositCollateralAndBorrowHook.sol` |
| EulerRepayAndWithdrawHook | `src/hooks/loan/euler/EulerRepayAndWithdrawHook.sol` |
| BaseLoanHook | `src/hooks/loan/BaseLoanHook.sol` |
| IEVault | `src/vendor/euler/IEVault.sol` |
| IEVC | `src/vendor/euler/IEVC.sol` |

---

## P0 Critical Findings

None found.

---

## P1 High Findings

### P1-1: Full Repayment Fails Due to Interest Accrual Between `build()` and `execute()` [KNOWN P1-3]

- **Files:** `EulerRepayHook.sol:106-127`, `EulerRepayAndWithdrawHook.sol:164-232`
- **Category:** Logic / TOCTOU
- **Description:** When `isFullRepayment = true`, `_buildHookExecutions` reads `debtOf(account)` at build time and uses that exact value for both the ERC20 `approve` amount and the `repay` amount. Since `build()` is a view function called off-chain and `execute()` happens later (possibly blocks apart), Euler V2 debt accrues interest continuously. The approved amount becomes insufficient, causing either a partial repay (leaving residual dust) or a revert on `disableController()` (which requires zero debt). The Euler V2 EVault documentation explicitly states: "To pay off a loan in full, you should specify MAX_UINT256 as the amount."
- **Vulnerable Code:**
  ```solidity
  // EulerRepayHook.sol:106-127
  repayAmount = IEVault(vars.controllerVault).debtOf(account); // stale at execution time
  executions[1] = Execution({
      target: vars.debtAsset,
      callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, repayAmount)) // insufficient
  });
  executions[2] = Execution({
      target: vars.controllerVault,
      callData: abi.encodeCall(IEVault.repay, (repayAmount, account)) // may not fully repay
  });
  executions[4] = Execution({
      target: vars.controllerVault,
      callData: abi.encodeCall(IEVault.disableController, ()) // reverts if debt != 0
  });
  ```
- **Recommendation:** Use `type(uint256).max` for both approve and repay in full repayment mode. Euler V2's `repay()` natively handles this sentinel value by capping the transfer to the exact debt owed:
  ```solidity
  executions[1] = Execution({
      target: vars.debtAsset,
      callData: abi.encodeCall(IERC20.approve, (vars.controllerVault, type(uint256).max))
  });
  executions[2] = Execution({
      target: vars.controllerVault,
      callData: abi.encodeCall(IEVault.repay, (type(uint256).max, account))
  });
  ```
  The trailing `approve(0)` execution already resets the allowance, so this is safe.
- **Status:** KNOWN LIMITATION (documented as P1-3 in NatSpec)

---

### P1-2: Full Repayment Front-Running via Debt Donation [KNOWN P1-2]

- **Files:** `EulerRepayHook.sol:108`, `EulerRepayAndWithdrawHook.sol:166`
- **Category:** MEV / Front-Running
- **Description:** An attacker can front-run a full repayment transaction by calling `IEVault.repay(1, victimAccount)` on behalf of the borrower. This reduces the borrower's debt by 1 wei. The victim's pre-computed `repayAmount` from `debtOf` is now larger than the actual debt. Combined with interest accrual in the opposite direction, the mismatch causes the user's transaction to either partially repay or revert on `disableController()`.
- **Recommendation:** Using `type(uint256).max` for full repay (P1-1 fix) also mitigates this. The `_postExecute` in `EulerRepayAndWithdrawHook` already validates `debtOf(account) != 0` with `FULL_REPAY_FAILED()` (line 377), which is a good defensive check. With `type(uint256).max`, the repay amount is calculated atomically at execution time, making front-running irrelevant.
- **Status:** KNOWN LIMITATION (documented as P1-2 in NatSpec)

---

## P2 Medium Findings

### P2-1: `EulerRepayAndWithdrawHook` Tracks Wrong Token for `outAmount` in Repay-Only Mode

- **File:** `EulerRepayAndWithdrawHook.sol:359-370`
- **Category:** Logic
- **Description:** The hook always tracks the collateral token balance for `outAmount` computation and sets `outToken` to the collateral token address. In repay-only mode (`secondaryAmount == 0`), no collateral is withdrawn, so the balance delta is 0. If a downstream hook uses `prevHook.getOutAmount(account)` expecting the repaid amount, it receives 0, breaking amount forwarding.
- **Vulnerable Code:**
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      _setOutAmount(getCollateralTokenBalance(account, data), account); // always tracks collateral
  }
  function _postExecute(address, address account, bytes calldata data) internal override {
      uint256 preBal = getOutAmount(account);
      uint256 postBal = getCollateralTokenBalance(account, data);
      _setOutAmount(postBal - preBal, account); // 0 when no withdrawal
      _setOutToken(getCollateralTokenAddress(data), account); // always collateral token
  }
  ```
- **Recommendation:** In repay-only mode, track the debt token balance delta instead:
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      uint256 secondaryAmount = BytesLib.toUint256(data, SECONDARY_AMOUNT_OFFSET);
      if (secondaryAmount == 0) {
          _setOutAmount(getLoanTokenBalance(account, data), account);
      } else {
          _setOutAmount(getCollateralTokenBalance(account, data), account);
      }
  }
  ```

---

### P2-2: Liquidation Capacity Check Bypassed When `collateralValue = 0`

- **Files:** `EulerDepositCollateralAndBorrowHook.sol:310-316`, `EulerRepayAndWithdrawHook.sol:386-393`
- **Category:** Logic / Edge Case
- **Description:** When `maxLiqCapUtilBps > 0` but `collateralValue = 0` (e.g., oracle returns 0 due to price feed failure) and `liabilityValue = 0`, the check `0 * 10_000 > 0 * maxLiqCapUtilBps` evaluates to `false`, allowing the operation to proceed despite no recognized collateral. While Euler's own EVC health check would likely catch this, the hook-level safety guard fails silently.
- **Vulnerable Code:**
  ```solidity
  if (liabilityValue * 10_000 > collateralValue * maxLiqCapUtilBps) {
      revert LIQUIDATION_CAPACITY_EXCEEDED();
  }
  ```
- **Recommendation:** Add explicit zero-collateral guard:
  ```solidity
  if (liabilityValue > 0 && collateralValue == 0) revert LIQUIDATION_CAPACITY_EXCEEDED();
  if (liabilityValue * 10_000 > collateralValue * maxLiqCapUtilBps) {
      revert LIQUIDATION_CAPACITY_EXCEEDED();
  }
  ```

---

### P2-3: `_postExecute` Underflow With Fee-on-Transfer or Rebasing Tokens

- **Files:** `EulerDepositCollateralHook.sol:158-159`, `EulerRepayHook.sol:202-203`
- **Category:** Arithmetic
- **Description:** In `_postExecute`, `EulerDepositCollateralHook` computes `preBal - postBal` (collateral consumed). With fee-on-transfer tokens, the balance delta may differ from expected, and with rebasing tokens that rebase upward mid-transaction, `postBal > preBal` causes an underflow revert (DoS, not fund loss due to Solidity 0.8.30 overflow checks). Same pattern in `EulerRepayHook` for `getOutAmount(account) - getLoanTokenBalance(account, data)`.
- **Recommendation:** Add conditional handling:
  ```solidity
  uint256 preBal = getOutAmount(account);
  uint256 postBal = getCollateralTokenBalance(account, data);
  _setOutAmount(preBal > postBal ? preBal - postBal : 0, account);
  ```

---

### P2-4: Stale Collateral Registration in EVC After Position Unwind

- **Files:** `EulerRepayHook.sol`, `EulerRepayAndWithdrawHook.sol`
- **Category:** State Management
- **Description:** `EulerBorrowHook` and `EulerDepositCollateralAndBorrowHook` call `enableCollateral(account, collateralVault)` and `enableController(account, controllerVault)`. On full repayment, `disableController()` is called but `disableCollateral()` is never called. After fully unwinding a position, the account still has the collateral vault registered in the EVC. The EVC limits accounts to 10 collateral slots, so stale registrations could fill up the array. If the user later enables a new controller, the stale collateral could unexpectedly be used.
- **Recommendation:** Add `IEVC.disableCollateral(account, collateralVault)` as an execution step in the full repayment + withdraw path after `disableController()`.

---

### P2-5: TOCTOU on Vault Configuration (Oracle/IRM/UnitOfAccount)

- **Files:** `EulerDepositCollateralAndBorrowHook.sol:161-169`, `EulerRepayAndWithdrawHook.sol:182-190`
- **Category:** TOCTOU
- **Description:** `EulerDepositCollateralAndBorrowHook` validates `oracle()`, `unitOfAccount()`, and `interestRateModel()` at build-time. Vault governance could change these parameters between `build()` and `execute()`. Since Euler V2 vaults are governance-configurable, a vault governor could change the oracle to a manipulated one before execution. The `_postExecute` already validates `maxPostDebt` and liquidation capacity but does not re-validate oracle/IRM/unit-of-account.
- **Recommendation:** Consider re-validating oracle/IRM/unit-of-account in `_postExecute`, or document this as a known risk mitigated by off-chain monitoring.

---

### P2-6: `BaseHook.setExecutionContext` and `setOutAmount` Lack Access Control

- **Files:** `BaseHook.sol:142-145`, `BaseHook.sol:204-214`
- **Category:** Access Control
- **Description:** `setExecutionContext(address caller)` and `setOutAmount(uint256, address)` are `external` with no access control. Anyone can call `setExecutionContext` to overwrite the execution context or `setOutAmount` to inject arbitrary amounts before the mutex is set. If `usePrevHookAmount` is true on the next hook, it would read the attacker-controlled value. Impact is mitigated by transient storage clearing at transaction boundaries and atomic execution via the executor module.
- **Recommendation:** Restrict to authorized callers (e.g., the SuperExecutor):
  ```solidity
  function setExecutionContext(address caller) external onlyAuthorizedExecutor { ... }
  ```
- **Note:** This is a `BaseHook` issue, not Euler-specific. May be mitigated architecturally.

---

### P2-7: EVC Address Not Validated in `EulerRepayAndWithdrawHook`

- **File:** `EulerRepayAndWithdrawHook.sol:331-355`
- **Category:** Input Validation
- **Description:** `_decodeRepayWithdrawData` does not decode or validate the EVC address (offset 92). Compare with `EulerBorrowHook._decodeBorrowData` which validates `vars.evc == address(0)`. While the hook doesn't use the EVC in execution, `inspect()` reads the EVC address from calldata. A zero EVC would produce invalid packed output.
- **Recommendation:** Add EVC validation in decode:
  ```solidity
  address evc = BytesLib.toAddress(data, EVC_OFFSET);
  if (evc == address(0)) revert ADDRESS_NOT_VALID();
  ```

---

### P2-8: `EulerWithdrawCollateralHook` Uses `HookSubTypes.LOAN_REPAY` Instead of `LOAN`

- **File:** `EulerWithdrawCollateralHook.sol:69`
- **Category:** Semantics
- **Description:** `EulerWithdrawCollateralHook` constructor passes `HookSubTypes.LOAN_REPAY` but withdrawing collateral is not a repayment action. `EulerDepositCollateralHook` uses `HookSubTypes.LOAN`. If `LOAN_REPAY` has different validation/accounting treatment, this could cause misclassification.
- **Recommendation:** Verify this is intentional. If not:
  ```solidity
  constructor() BaseLoanHook(HookSubTypes.LOAN) { }
  ```
- **Note:** The Aave V3 withdraw hook uses `LOAN_REPAY` too, suggesting this may be intentional convention.

---

## P3 Low / Informational Findings

### P3-1: Missing `BaseEulerLoanHook` Abstract Base Contract

- **Files:** All 6 Euler hooks
- **Category:** Architecture
- **Description:** All 6 Euler hooks duplicate identical constants (`COLLATERAL_VAULT_OFFSET`, `DEBT_ASSET_OFFSET`, etc.), errors (`INVALID_DATA_LENGTH`), and follow the same data layout. The Aave V3 hooks centralize these in `BaseAaveV3LoanHook`. Creating a `BaseEulerLoanHook` would reduce code duplication and deployment costs.

### P3-2: Missing NatSpec Documentation

- **Files:** All Euler hooks, `BaseLoanHook.sol`
- **Category:** Documentation
- **Description:** `INVALID_DATA_LENGTH` error lacks `@notice` in several hooks. Internal decode functions (`_decodeDepositData`, `_decodeBorrowData`, etc.) lack NatSpec. `BaseLoanHook` lacks `@notice`/`@dev`. Struct fields lack documentation.

### P3-3: Magic Numbers in `BaseLoanHook` Token Helpers

- **File:** `BaseLoanHook.sol:77-94`
- **Category:** Code Quality
- **Description:** `getLoanTokenAddress` and `getCollateralTokenAddress` use raw literals `52` and `72` instead of named constants.

### P3-4: Euler V1 Donation Attack Not Applicable to V2

- **Category:** Historical Research
- **Description:** The Euler V1 exploit ($197M, March 2023) leveraged `donateToReserves` for share price manipulation. Euler V2 mitigates this with internal balance tracking -- direct token transfers don't affect share pricing. The hooks correctly interact through standard vault functions. No action needed.

### P3-5: EVC `enableCollateral`/`enableController` Authentication Pattern

- **Category:** Integration
- **Description:** Hooks generate executions where the smart account directly calls `IEVC.enableCollateral()`. The EVC uses address prefixes (first 19 bytes) to determine account ownership. Verify in integration tests that the smart account's address is correctly recognized by the EVC.

### P3-6: `inspect()` Functions Lack Input Length Validation

- **Files:** All Euler hooks
- **Category:** Input Validation
- **Description:** `inspect()` functions decode addresses from calldata without length checks. Malformed short calldata would revert at BytesLib level, but explicit validation would be more consistent.

---

## Summary Table

| # | Severity | Category | File(s) | Description | Status |
|---|----------|----------|---------|-------------|--------|
| P1-1 | P1 High | Logic | RepayHook, RepayAndWithdrawHook | Full repay uses stale `debtOf` amount | KNOWN P1-3 |
| P1-2 | P1 High | MEV | RepayHook, RepayAndWithdrawHook | Full repay front-runnable via 1 wei donation | KNOWN P1-2 |
| P2-1 | P2 Medium | Logic | RepayAndWithdrawHook | Repay-only mode outputs `outAmount = 0` | NEW |
| P2-2 | P2 Medium | Logic | DepositCollateralAndBorrowHook | Zero collateral edge case in liq capacity check | NEW |
| P2-3 | P2 Medium | Arithmetic | DepositCollateralHook, RepayHook | Underflow with fee-on-transfer tokens | NEW |
| P2-4 | P2 Medium | State | RepayHook, RepayAndWithdrawHook | Stale EVC collateral registration after unwind | NEW |
| P2-5 | P2 Medium | TOCTOU | DepositCollateralAndBorrowHook | Oracle/IRM config can change between build/execute | NEW |
| P2-6 | P2 Medium | Access Control | BaseHook.sol | `setExecutionContext`/`setOutAmount` no ACL | EXISTING |
| P2-7 | P2 Medium | Validation | RepayAndWithdrawHook | EVC address not validated | NEW |
| P2-8 | P2 Medium | Semantics | WithdrawCollateralHook | Wrong `HookSubType` -- verify intentional | NEW |
| P3-1 | P3 Low | Architecture | All hooks | Need `BaseEulerLoanHook` base contract | NEW |
| P3-2 | P3 Low | Docs | All hooks | Missing NatSpec | NEW |
| P3-3 | P3 Low | Quality | BaseLoanHook | Magic numbers in token helpers | NEW |
| P3-4 | P3 Low | Research | N/A | V1 donation attack not applicable to V2 | INFO |
| P3-5 | P3 Low | Integration | All hooks | Verify EVC address prefix auth in tests | INFO |
| P3-6 | P3 Low | Validation | All hooks | `inspect()` lacks length validation | NEW |

---

## Key Recommendations (Priority Order)

1. **Use `type(uint256).max` for full repay** -- Eliminates both P1-1 and P1-2. Euler V2's `repay()` natively handles this sentinel value. This is the single highest-impact fix.

2. **Fix `EulerRepayAndWithdrawHook` repay-only mode** -- Track debt token delta instead of collateral delta when `secondaryAmount == 0` (P2-1).

3. **Add zero-collateral guard** in liquidation capacity check (P2-2).

4. **Add `disableCollateral()` on full unwind** to clean up EVC state (P2-4).

5. **Validate EVC address** in `EulerRepayAndWithdrawHook._decodeRepayWithdrawData` (P2-7).

6. **Create `BaseEulerLoanHook`** -- Consolidate shared constants, errors, and virtual offset accessors (P3-1).

---

## External References

- [Euler V2 EVK Whitepaper](https://github.com/euler-xyz/euler-vault-kit/blob/master/docs/whitepaper.md)
- [OpenZeppelin EVK Audit](https://www.openzeppelin.com/news/euler-vault-kit-evk-audit)
- [Electisec Euler V2 Review (March 2024)](https://reports.electisec.com/2024-03-EulerV2)
- [Electisec EVC Review (December 2023)](https://reports.electisec.com/2023-12-Euler-EVC)
- [EVC Security Considerations](https://docs.euler.finance/developers/evc/security/)
- [EVC Integration Guide](https://docs.euler.finance/developers/evc/integration-guide/)
- [Interacting with EVaults](https://docs.euler.finance/developers/evk/interacting-with-vaults/)
- [Euler V2 Donation Attack Docs](https://docs.euler.finance/security/attack-vectors/donation-attacks/)
