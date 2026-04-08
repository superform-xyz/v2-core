# Security Analysis Report

## Metadata
- **Target:** `src/hooks/loan/morpho/` (8 files)
- **Mode:** review
- **Date:** 2026-03-31
- **Contract Types Detected:** DeFi Lending (Morpho Blue)
- **Files Analyzed:** 8
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | — |
| P1 High | 0 (2 documented known limitations) | — |
| P2 Medium | 9 | No |
| P3 Low | 12 | No |

## Verdict
**PASS** — No P0 or P1 findings. All previously identified P1s are documented as KNOWN LIMITATIONs. P2/P3 findings are advisory.

---

## Known Limitations (Documented, Not Blocking)

### [KNOWN P1-2] Front-Running Full Repayment Griefing
- **Files:** MorphoRepayHook.sol, MorphoRepayAndWithdrawHook.sol
- **Status:** Documented in contract NatSpec
- **Description:** Attacker can front-run full repayment by repaying 1 wei of shares on behalf of the borrower, changing the share balance and causing the victim's tx to revert.
- **Mitigation:** Private mempools or slippage tolerance on share amounts.
- **Source:** Morpho Blue IMorpho.sol interface documentation; EVM Security Researcher

### [KNOWN P1-3] Stale Approval TOCTOU on Full Repayment
- **Files:** MorphoRepayHook.sol, MorphoRepayAndWithdrawHook.sol
- **Status:** Documented in contract NatSpec
- **Description:** Interest accrues between `build()` and `execute()`. Approval from `sharesToAssets()`/`deriveLoanAmount()` may be stale. `_preExecute` calls `accrueInterest()` but approval was already set.
- **Mitigation:** Off-chain bundler should execute UserOps promptly after building.

### [KNOWN] Thin Market Borrow Share Manipulation
- **Files:** MorphoBorrowHook.sol, MorphoSupplyAndBorrowHook.sol
- **Status:** Documented in MorphoBorrowHook NatSpec
- **Description:** Borrow share price manipulation possible in markets with <1e4 assets borrowed.
- **Mitigation:** Off-chain bundler refuses to route to thin markets.
- **Source:** Morpho Blue `createMarket` documentation; EVM Security Researcher

---

## P0 Findings (Critical — Must Fix)

None found.

## P1 Findings (High — Must Fix)

None found.

## P2 Findings (Medium — Should Fix)

### [P2-1] MorphoWithdrawHook: `outAmount` Keyed to `recipient` Instead of `account`
- **File:** MorphoWithdrawHook.sol:100-109
- **SWC:** N/A
- **Category:** Logic
- **Description:** `_preExecute`/`_postExecute` store outAmount using `recipient` as the key (extracted from data offset 100). All other hooks key by `account`. Downstream hooks calling `getOutAmount(account)` will get 0 when `recipient != account`, silently breaking `usePrevHookAmount` chaining.
- **Exploit Scenario:** In a multi-hook chain, `MorphoWithdrawHook` with `receiver != account` is followed by another hook using `usePrevHookAmount`. The next hook reads 0 instead of the withdrawn amount, causing incorrect operation or revert.
- **Vulnerable Code:**
  ```solidity
  function _preExecute(address, address, bytes calldata data) internal override {
      address recipient = BytesLib.toAddress(data, 100);
      _setOutAmount(getLoanTokenBalance(recipient, data), recipient);
  }
  ```
- **Secure Pattern:**
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      address recipient = BytesLib.toAddress(data, 100);
      _setOutAmount(getLoanTokenBalance(recipient, data), account);
  }
  ```
- **Reference:** BaseHook.sol transient storage context design

### [P2-2] MorphoWithdrawHook: Missing XOR Validation for `assets` and `shares`
- **File:** MorphoWithdrawHook.sol:70
- **SWC:** N/A
- **Category:** Logic
- **Description:** Only validates both aren't zero, but doesn't validate both aren't non-zero. Morpho Blue docs: "Either `assets` or `shares` should be zero." Passing both non-zero causes Morpho to ignore `shares` when `assets > 0`, creating a misleading API.
- **Vulnerable Code:**
  ```solidity
  if (vars.assets == 0 && vars.shares == 0) revert AMOUNT_NOT_VALID();
  ```
- **Secure Pattern:**
  ```solidity
  if (vars.assets == 0 && vars.shares == 0) revert AMOUNT_NOT_VALID();
  if (vars.assets != 0 && vars.shares != 0) revert AMOUNT_NOT_VALID();
  ```
- **Reference:** Morpho Blue IMorpho.sol documentation

### [P2-3] MorphoSupplyAndBorrowHook: Zero Oracle Price Not Validated
- **File:** MorphoSupplyAndBorrowHook.sol:134-141
- **SWC:** SWC-110
- **Category:** Oracle
- **Description:** `deriveLoanAmount` calls `oracleInstance.price()` without checking for zero. If `price == 0`, `loanAmount = 0`, collateral is supplied but no loan tokens borrowed. Collateral is locked with no borrow proceeds, requiring separate recovery. Historical precedent: Morpho PAXG/USDC $230K oracle exploit (Oct 2024).
- **Vulnerable Code:**
  ```solidity
  uint256 price = oracleInstance.price();
  uint256 fullAmount = Math.mulDiv(collateralAmount, price, PRICE_SCALING_FACTOR);
  ```
- **Secure Pattern:**
  ```solidity
  uint256 price = oracleInstance.price();
  if (price == 0) revert ORACLE_PRICE_NOT_VALID();
  uint256 fullAmount = Math.mulDiv(collateralAmount, price, PRICE_SCALING_FACTOR);
  ```
- **Reference:** vulnerabilities.md Section 4; Morpho PAXG/USDC exploit 2024

### [P2-4] `morpho` Should Be `immutable`
- **File:** BaseMorphoLoanHook.sol:50
- **Category:** Gas / Security
- **Description:** `morpho` is set once in constructor, never modified. Regular storage costs ~2100 gas (cold SLOAD) per read vs 3 gas for immutable. Read in every hook execution. All other protocol address references in the codebase use `immutable`.
- **Vulnerable Code:**
  ```solidity
  address public morpho;
  ```
- **Secure Pattern:**
  ```solidity
  address public immutable morpho;
  ```
- **Reference:** vulnerabilities.md Section 13 (Gas)

### [P2-5] `morphoStaticTyping` Should Be `immutable`
- **Files:** MorphoRepayHook.sol:43, MorphoRepayAndWithdrawHook.sol:43
- **Category:** Gas / Security
- **Description:** Set once in constructor, never modified. Read multiple times per repay execution (`deriveShareBalance`, `deriveLoanAmount`, `sharesToAssets`).
- **Secure Pattern:**
  ```solidity
  IMorphoStaticTyping public immutable morphoStaticTyping;
  ```

### [P2-6] MorphoWithdrawHook: Missing `onBehalf`/`recipient` Zero-Address Validation
- **File:** MorphoWithdrawHook.sol:128
- **Category:** Logic
- **Description:** Validates `loanToken`, `collateralToken`, `oracle`, `irm` for zero address but not `onBehalf` or `recipient`. Zero `recipient` would burn tokens permanently. Zero `onBehalf` queries empty position.
- **Secure Pattern:**
  ```solidity
  if (loanToken == address(0) || collateralToken == address(0) || oracle == address(0)
      || irm == address(0) || onBehalf == address(0) || recipient == address(0)) {
      revert ADDRESS_NOT_VALID();
  }
  ```

### [P2-7] MorphoRepayHook Missing `_postExecute` — `outAmount` Always 0
- **File:** MorphoRepayHook.sol
- **Category:** Logic
- **Description:** Only overrides `_preExecute` (calls `accrueInterest`), no `_postExecute`. `getOutAmount()` returns 0. Every other Morpho hook sets outAmount. Downstream hooks using `usePrevHookAmount` after RepayHook get 0.
- **Recommendation:** Either implement `_preExecute`/`_postExecute` to track loanToken consumed, or add NatSpec documenting that RepayHook does not support `usePrevHookAmount` chaining.

### [P2-8] Duplicated Struct and Decode Logic Between SupplyHook and LendHook
- **Files:** MorphoSupplyHook.sol:31-137, MorphoLendHook.sol:34-147
- **Category:** Code Duplication
- **Description:** `SupplyHookLocalVars` and `LendHookLocalVars` are structurally identical. `_decodeSupplyHookData()` and `_decodeLendHookData()` are character-for-character identical. Should be consolidated into `BaseMorphoLoanHook`.

### [P2-9] Duplicated `deriveShareBalance` and `sharesToAssets` Functions
- **Files:** MorphoRepayHook.sol:144-158, MorphoRepayAndWithdrawHook.sol:168-226
- **Category:** Code Duplication
- **Description:** Both hooks independently implement `deriveShareBalance()` and `sharesToAssets()`. Both also independently declare `morphoStaticTyping` storage. Should be extracted to a shared base.

---

## P3 Findings (Low — Consider Fixing)

### [P3-1] Magic Number `144` Instead of Named Constant
- **Files:** BaseMorphoLoanHook.sol:118,145; MorphoSupplyHook.sol:126; MorphoLendHook.sol:136
- **Description:** `USE_PREV_HOOK_AMOUNT_POSITION` is `private` in `BaseLoanHook`, inaccessible to children. Should be `internal`.

### [P3-2] Magic Numbers in MorphoWithdrawHook Offsets
- **File:** MorphoWithdrawHook.sol:101,108,122-126
- **Description:** Offsets `80`, `100`, `120`, `152`, `184` used as raw numbers. Should be named constants.

### [P3-3] Duplicated Address Validation Block Across 6 Hooks
- **Files:** BorrowHook, SupplyHook, SupplyAndBorrowHook, RepayHook, RepayAndWithdrawHook, LendHook
- **Description:** Identical `if (vars.loanToken == address(0) || ...)` block in 6 hooks. Could be moved into decode functions.

### [P3-4] MorphoLendHook Uses `@notice` Instead of `@inheritdoc BaseHook`
- **File:** MorphoLendHook.sol:55-59
- **Description:** Inconsistent with all other hooks that use `/// @inheritdoc BaseHook` for overridden functions.

### [P3-5] `@dev` Used Instead of `@notice` on Public Functions
- **Files:** MorphoRepayHook.sol:140, MorphoRepayAndWithdrawHook.sol:164, MorphoSupplyAndBorrowHook.sol:120
- **Description:** Public view functions use `@dev` as primary tag instead of `@notice`.

### [P3-6] Struct Outside Proper Section Header
- **File:** MorphoRepayAndWithdrawHook.sol:45
- **Description:** `BuildExecutionContext` struct placed after STORAGE section without its own STRUCTS header.

### [P3-7] MorphoLendHook Inline Cast vs Cached Reference
- **File:** MorphoLendHook.sol:171
- **Description:** `IMorphoStaticTyping(morpho).position(...)` inline cast, inconsistent with RepayHook/RepayAndWithdrawHook which store `morphoStaticTyping`.

### [P3-8] `AMOUNT_POSITION` and `USE_PREV_HOOK_AMOUNT_POSITION` Should Be `internal`
- **File:** BaseLoanHook.sol:19-20
- **Description:** Declared `private` but commented as "inherited" in `BaseMorphoLoanHook`. Should be `internal` so children can reference them.

### [P3-9] Missing NatSpec on `BaseLoanHook` Contract
- **File:** BaseLoanHook.sol:14-15
- **Description:** Has `@title` and `@author` but missing `@notice` and `@dev`.

### [P3-10] Missing NatSpec on `BaseLoanHook._decodeAmount()`
- **File:** BaseLoanHook.sol:63-65
- **Description:** No NatSpec documentation.

### [P3-11] `deriveLoanAmount` NatSpec Missing `@param`/`@return`
- **File:** MorphoSupplyAndBorrowHook.sol:120-123
- **Description:** Uses duplicate `@dev` tags and lacks `@param`/`@return` documentation.

### [P3-12] Potential Underflow in `_postExecute` Balance Tracking
- **Files:** MorphoBorrowHook.sol:99, MorphoSupplyHook.sol:146, MorphoLendHook.sol:160
- **Description:** `balance_after - pre_balance` assumes balance moved in expected direction. If violated (fee-on-transfer, external interference), reverts with underflow. This is actually fail-safe behavior but could benefit from explicit error messages.

---

## Attack Surface Summary

- **External Entry Points:** `buildHookExecutions()` (view), `preExecute()` (internal), `postExecute()` (internal), `inspect()` (pure), `deriveShareBalance()` (view), `sharesToAssets()` (view), `deriveLoanAmount()` (view), `deriveCollateralForPartialRepayment()` (view)
- **Value Transfer Points:** All Morpho calls — `supply`, `borrow`, `repay`, `withdraw`, `supplyCollateral`, `withdrawCollateral`
- **Oracle Dependencies:** `IOracle(oracle).price()` in MorphoSupplyAndBorrowHook.deriveLoanAmount
- **Cross-Contract Interactions:** Morpho Blue protocol, ERC-20 approve/balanceOf, IMorphoStaticTyping.position
- **Upgrade Mechanisms:** None (hooks are not upgradeable)

## Positive Security Patterns Observed

1. Consistent `approve(0) -> approve(amount) -> operation -> approve(0)` pattern across all approval hooks
2. Empty callback data `""` on all Morpho calls prevents callback reentrancy (documented as security invariant)
3. `preExecuteMutex`/`postExecuteMutex` in BaseHook prevents re-execution
4. `INVALID_DATA_LENGTH` checks in all decode functions prevent OOB reads
5. Known limitations well-documented in NatSpec with severity labels
6. Custom errors used throughout (no revert strings)
7. Locked pragma `0.8.30` on all files
8. Rounding direction consistently favors protocol (`toAssetsUp`, `mulDiv` rounds down for collateral withdrawal)

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 3, 4, 5, 10, 13, 15, 22, 36
- **evmresearch.io patterns checked:** vulnerability-patterns (lending, oracle, reentrancy), exploit-analyses (Morpho, lending), security-patterns (approve, transient storage)
- **External sources:** Morpho Blue docs, OWASP SC Top 10, DeFiHackLabs, ChainSecurity TSTORE research, Halborn Top 100
- **Historical exploits cross-referenced:** Morpho PAXG/USDC $230K (2024), Resolv USR $25M (2025), Radiant $4.5M (2024)
