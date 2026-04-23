# Security Analysis Report

## Metadata
- **Target:** `src/hooks/loan/aave-v4/` (7 Solidity files)
- **Mode:** review
- **Date:** 2026-04-21
- **Contract Types Detected:** Lending hooks (Aave V4 Hub-and-Spoke)
- **Files Analyzed:** 7
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 8 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

Note: Two known limitations (front-running full repayment P1-2, interest accrual P1-3) are already documented in the source code and accepted as operational risks mitigated off-chain.

---

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

### Known Limitations (Already Documented)

#### [KL-1] Full Repayment Front-Running (Documented as P1-2)
- **File:** `AaveV4RepayHook.sol:26-28`, `AaveV4RepayAndWithdrawHook.sol:27-29`
- **Status:** Already documented in NatSpec
- **Description:** An attacker can front-run full repayment by repaying a small amount on behalf of the borrower, causing the victim's `type(uint256).max` repay to overshoot and revert.
- **Mitigation:** Private mempools, slippage tolerance, prompt execution by bundler.

#### [KL-2] Interest Accrual Between build() and execute() (Documented as P1-3)
- **File:** `AaveV4RepayHook.sol:29-31`, `AaveV4RepayAndWithdrawHook.sol:30-32`
- **Status:** Already documented in NatSpec
- **Description:** Interest accrues between build() and execute(). For full repayment, the approval set during build() may be slightly stale.
- **Mitigation:** `type(uint256).max` approval covers interest drift; bundler should execute promptly.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Arithmetic Underflow in SupplyAndBorrowHook When loanToken == collateralToken
- **File:** `AaveV4SupplyAndBorrowHook.sol:109`
- **SWC:** SWC-101
- **Severity:** P2 Medium
- **Category:** Arithmetic
- **Description:** `_postExecute` computes `getOutAmount(account) - getCollateralTokenBalance(account, data)`. If `loanToken == collateralToken`, the borrow proceeds increase the token balance, which could make the post-balance greater than the pre-balance stored in outAmount, causing an arithmetic underflow revert.
- **Exploit Scenario:** A bundler constructs a SupplyAndBorrow where loanToken and collateralToken are the same ERC-20 (e.g., using recursive leverage). The borrow proceeds increase the collateral token balance beyond the stored pre-balance, causing _postExecute to revert with underflow.
- **Vulnerable Code:**
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      _setOutAmount(getOutAmount(account) - getCollateralTokenBalance(account, data), account);
  }
  ```
- **Secure Pattern:**
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      uint256 preBalance = getOutAmount(account);
      uint256 postBalance = getCollateralTokenBalance(account, data);
      // When loanToken == collateralToken, borrow proceeds increase balance
      _setOutAmount(preBalance > postBalance ? preBalance - postBalance : 0, account);
  }
  ```
- **Note:** This may be an intentional design constraint — if loanToken should never equal collateralToken, consider adding an explicit check in `_buildHookExecutions` to enforce this invariant.
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)

### [P2-2] Arithmetic Underflow in RepayAndWithdrawHook When loanToken == collateralToken
- **File:** `AaveV4RepayAndWithdrawHook.sol:134`
- **SWC:** SWC-101
- **Severity:** P2 Medium
- **Category:** Arithmetic
- **Description:** `_postExecute` computes `getCollateralTokenBalance(account, data) - getOutAmount(account)`. If `loanToken == collateralToken`, the repay reduces the token balance, but the withdrawal increases it. Depending on relative amounts, this subtraction may underflow.
- **Exploit Scenario:** Same-token scenario with repay+withdraw where the pre/post balance relationship is inverted due to both operations affecting the same token balance.
- **Vulnerable Code:**
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      _setOutAmount(getCollateralTokenBalance(account, data) - getOutAmount(account), account);
  }
  ```
- **Secure Pattern:**
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      uint256 postBalance = getCollateralTokenBalance(account, data);
      uint256 preBalance = getOutAmount(account);
      _setOutAmount(postBalance > preBalance ? postBalance - preBalance : 0, account);
  }
  ```
- **Reference:** vulnerabilities.md Section 3 (Arithmetic)

### [P2-3] Magic Numbers for Byte Offsets
- **File:** `BaseAaveV4LoanHook.sol:220,244`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Code Quality
- **Description:** Byte offsets 157 and 158 used in `_decodeSupplyAndBorrowHookData` and `_decodeRepayAndWithdrawHookData` are inline magic numbers. Other offsets (0, 20, 40, 60, 92, 124, 156) follow a pattern but the final offsets for borrowAmount/withdrawAmount and isFullRepayment lack named constants.
- **Current Code:**
  ```solidity
  vars.borrowAmount = BytesLib.toUint256(data, 157);
  // ...
  vars.isFullRepayment = _decodeBool(data, 157);
  vars.withdrawAmount = BytesLib.toUint256(data, 158);
  ```
- **Corrected Code:** Define named constants for all byte offsets, or at minimum add inline comments explaining the offset calculation (e.g., `// 156 (usePrevHookAmount) + 1`).
- **Reference:** coding-rules.md

### [P2-4] Inline Minimum Data Length Computation
- **File:** `BaseAaveV4LoanHook.sol:206,229`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Code Quality
- **Description:** Minimum data length checks use inline arithmetic (`156 + 1 + 32`, `156 + 1 + 1 + 32`) rather than named constants. These should reference the expected packed struct size for clarity and maintainability.
- **Reference:** coding-rules.md

### [P2-5] NatSpec Data Layout Documentation Mismatch
- **File:** `AaveV4SupplyAndBorrowHook.sol:25`, `AaveV4RepayAndWithdrawHook.sol:24`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Documentation
- **Description:** The NatSpec in SupplyAndBorrowHook documents `uint256 supplyAmount` at offset 124 but the decoded struct field is `amount`. Similarly, RepayAndWithdrawHook documents `uint256 repayAmount` at offset 124 but uses `amount`. While functionally correct, the naming inconsistency between docs and code could confuse integrators.
- **Reference:** coding-rules.md (NatSpec accuracy)

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] @inheritdoc Inconsistency Across Hooks
- **File:** All 6 leaf hooks (inspect functions)
- **Description:** `inspect()` uses `@inheritdoc BaseHook` in some hooks but the function is actually defined in `ISuperHookInspector`. Since BaseHook inherits from ISuperHookInspector and provides the override, `@inheritdoc BaseHook` is technically correct but inconsistent with the interface origin.
- **Reference:** coding-rules.md

### [P3-2] Unused Import in WithdrawHook and BorrowHook
- **File:** `AaveV4WithdrawHook.sol:5`, `AaveV4BorrowHook.sol:5`
- **Description:** `IERC20` is imported but not used in these hooks (they don't generate approve executions). The import is harmless but adds noise.
- **Reference:** coding-rules.md

### [P3-3] inspect() Returns Only Spoke Address
- **File:** All 6 leaf hooks
- **Description:** `inspect()` returns only `abi.encodePacked(vars.spoke)` but does not include loanToken, collateralToken, or reserveIds. Downstream consumers that need token addresses for validation must decode the full data payload independently.
- **Reference:** Design decision — noted for awareness.

### [P3-4] No reserveId Range Validation
- **File:** `BaseAaveV4LoanHook.sol` (all decode functions)
- **Description:** `supplyReserveId` and `borrowReserveId` decoded from calldata are passed directly to Spoke without range validation. While the Spoke contract itself will revert on invalid IDs, early validation would provide clearer error messages.
- **Reference:** vulnerabilities.md Section 8 (Input Validation)

### [P3-5] Fee-on-Transfer Token Awareness
- **File:** All hooks using balance-based outAmount tracking
- **Description:** The pre/post balance tracking pattern correctly handles fee-on-transfer tokens for outAmount calculation. However, the approve amount in `_buildHookExecutions` is set to `vars.amount` which may be more than what the Spoke actually receives after transfer fees. This is informational — Aave V4 Spokes are unlikely to interact with fee-on-transfer tokens.
- **Reference:** vulnerabilities.md Section 10.1

### [P3-6] type(uint256).max Approval Window
- **File:** `AaveV4RepayHook.sol:68`, `AaveV4RepayAndWithdrawHook.sol:68`
- **Description:** During full repayment, `type(uint256).max` approval is granted to the Spoke. While this is immediately followed by the repay call and then an approval reset to 0, there is a brief window where the Spoke has unlimited approval. This is standard DeFi practice and the Spoke is a trusted protocol contract.
- **Reference:** vulnerabilities.md Section 10.3

### [P3-7] Combined Hook Atomicity Assumption
- **File:** `AaveV4SupplyAndBorrowHook.sol`, `AaveV4RepayAndWithdrawHook.sol`
- **Description:** Combined hooks (supply+borrow, repay+withdraw) generate all executions in a single array, relying on the smart account to execute them atomically. If any intermediate execution fails (e.g., insufficient collateral for borrow after supply), the entire batch reverts. This is the correct behavior but should be documented for bundler awareness.
- **Reference:** Design decision — noted for awareness.

### [P3-8] Spoke Address from Untrusted Calldata
- **File:** `BaseAaveV4LoanHook.sol` (all decode functions)
- **Description:** The Spoke address is decoded from calldata provided by the bundler. A malicious bundler could substitute a different contract address. This is mitigated by the Superform validation layer (Merkle proof validation ensures calldata integrity) and the `inspect()` function which returns the spoke for off-chain validation.
- **Reference:** vulnerabilities.md Section 2 (Access Control)

---

## Attack Surface Summary

### External Entry Points
- `build(address prevHook, address account, bytes calldata data)` — via BaseHook, generates Execution[] arrays
- `preExecute(address, address account, bytes calldata data)` — sets pre-balance snapshot
- `postExecute(address, address account, bytes calldata data)` — computes outAmount delta
- `inspect(bytes calldata data)` — pure, returns spoke address

### Value Transfer Points
- ERC-20 `approve()` calls: collateralToken/loanToken → spoke
- Spoke `supply()`, `withdraw()`, `borrow()`, `repay()` calls moving tokens between account and Aave V4

### Oracle Dependencies
- None direct. Aave V4's internal oracle (User Risk Premium) is used by the Spoke, not by these hooks.

### Cross-Contract Interactions
- `IAaveV4Spoke` (supply, withdraw, borrow, repay) — trusted Aave V4 protocol contract
- `IERC20` (approve) — token contracts
- `ISuperHookResult` (getOutAmount) — previous hook in chain (when usePrevHookAmount=true)

### Upgrade Mechanisms
- None. Hooks are immutable (no proxy, no upgradeability).

---

## Coding Standards Findings

### Compliance Summary
- Custom errors: PASS (uses `AMOUNT_NOT_VALID()`, `INVALID_DATA_LENGTH()`)
- Events: N/A (hooks don't emit events — state tracked via transient storage)
- Solidity version: PASS (locked at 0.8.30)
- Visibility modifiers: PASS (all functions have explicit visibility)
- Checks-Effects-Interactions: PASS (view functions for build, transient storage for pre/post)
- OpenZeppelin usage: PASS (IERC20, SafeERC20 in base)

### Improvements Recommended
- Add named constants for byte offsets (P2-3)
- Remove unused IERC20 imports in WithdrawHook/BorrowHook (P3-2)
- Align NatSpec field names with struct field names (P2-5)

---

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 4 (Oracle), 5 (Flash Loan), 6 (MEV), 8 (Unchecked Returns), 9 (abi.encodePacked), 10 (Token Integration), 11 (Proxy), 13 (Gas), 15 (Code Quality), 22 (Vault Accounting)
- **evmresearch.io patterns checked:** vulnerability-patterns (reentrancy, token behaviors, oracle manipulation, flash loans), security-patterns (approve patterns, CEI), protocol-mechanics (lending pools, Aave), exploit-analyses (Kelp DAO rsETH April 2026)
- **Coding rules validated:** 12 rules from coding-rules.md
- **Historical exploits cross-referenced:** Kelp DAO rsETH (April 2026, $292M), Euler (March 2023, $197M), Aave governance manipulation attempts, general Aave V3 liquidation edge cases
