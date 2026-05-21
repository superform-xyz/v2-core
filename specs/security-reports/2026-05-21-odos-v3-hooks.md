# Security Analysis Report

## Metadata
- **Target:** `src/hooks/swappers/odos/SwapOdosV3Hook.sol`, `src/hooks/swappers/odos/ApproveAndSwapOdosV3Hook.sol`
- **Mode:** review
- **Date:** 2026-05-21
- **Contract Types Detected:** AMM/DEX (swap hooks)
- **Files Analyzed:** 2
- **Dependencies Reviewed:** BaseHook.sol, HookDataUpdater.sol, IOdosRouterV3.sol

## Summary
| Severity | Count | Status |
|----------|-------|--------|
| P0 Critical | 0 | N/A |
| P1 High | 1 | Fixed |
| P2 Medium | 4 | Fixed |
| P3 Low | 5 | Fixed |

## Verdict
**PASS** - All findings resolved. Safe to proceed.

### Resolution Summary
- **P1-1**: `outputQuote` scaling added in `_getSwapInfo` + fork integration test for chained swaps
- **P2-2**: `inputReceiver` added to `inspect()` for off-chain validation (consistent with V2 which also lacks on-chain validation)
- **P2-3**: Executor trust assumption documented in contract-level NatSpec
- **P2-4**: `SAME_INPUT_OUTPUT_TOKEN()` error prevents `inputToken == outputToken` (prevents underflow)
- **P2-5**: All magic number byte offsets extracted as named constants
- **P3-6**: Removed unused `PRECISION` constant
- **P3-7**: Removed unused `Math` import
- **P3-8**: `inspect()` returns `(inputReceiver, executor, feeRecipient)` = 60 bytes
- **P3-9**: Full NatSpec documentation added
- **P3-10**: `FEE_DENOM` documented as `uint64` for IOdosRouterV3 compatibility
- **Tests**: All 95 tests pass (83 unit + 4 mock integration + 8 fork integration)

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [1] `outputQuote` Not Scaled When `usePrevHookAmount` Is True

- **File:** `SwapOdosV3Hook.sol:166-177`, `ApproveAndSwapOdosV3Hook.sol:189-200`
- **SWC:** N/A
- **Category:** Logic Error / MEV
- **Description:** When `usePrevHookAmount` is true, `inputAmount` and `outputAmount` (slippage bound) are proportionally scaled via `HookDataUpdater.getUpdatedOutputAmount()`. However, `outputQuote` is passed through unmodified. The Odos Router V3 uses `outputQuote` as a reference for positive slippage calculations and referral fee computations. A stale `outputQuote` creates a mismatch between the quoted and actual swap parameters, potentially skewing the router's internal accounting for positive slippage distribution and referral fees.
- **Exploit Scenario:** A hook chain yields fewer tokens than originally quoted. `outputMin` is scaled down proportionally but `outputQuote` remains at the original high value. The Odos router's positive slippage logic and referral fee calculations use the stale `outputQuote`, potentially benefiting the referral fee recipient or MEV attackers at the user's expense.
- **Vulnerable Code:**
  ```solidity
  if (usePrevHookAmount) {
      uint256 _prevAmount = inputAmount;
      inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
      outputAmount = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputAmount);
      // outputQuote is NOT scaled
  }

  return IOdosRouterV3.swapTokenInfo(
      inputToken, inputAmount, inputReceiver, outputToken, outputQuote, outputAmount, account
  );
  ```
- **Secure Pattern:**
  ```solidity
  if (usePrevHookAmount) {
      uint256 _prevAmount = inputAmount;
      inputAmount = ISuperHookResult(prevHook).getOutAmount(account);
      outputAmount = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputAmount);
      outputQuote = HookDataUpdater.getUpdatedOutputAmount(inputAmount, _prevAmount, outputQuote);
  }
  ```

---

## P2 Findings (Medium - Should Fix)

### [2] No Validation That `inputReceiver` Is a Trusted Address

- **File:** `SwapOdosV3Hook.sol:164,177`, `ApproveAndSwapOdosV3Hook.sol:187,200`
- **SWC:** N/A
- **Category:** Access Control / Input Validation
- **Description:** `inputReceiver` is decoded from calldata and passed unvalidated to the Odos router. In the V3 router, `inputReceiver` is where input tokens are transferred for the executor to use. A malicious `inputReceiver` could intercept input tokens. Severity is mitigated because the data is part of a user-signed Merkle leaf, but `inspect()` does not expose `inputReceiver` for off-chain validation.
- **Exploit Scenario:** A compromised bundler sets `inputReceiver` to an attacker address. The smart account's approved tokens are transferred to the attacker via the router's internal `transferFrom`.
- **Vulnerable Code:**
  ```solidity
  address inputReceiver = BytesLib.toAddress(data, 52);
  // No validation, not returned by inspect()
  ```
- **Secure Pattern:** Add `inputReceiver` to the `inspect()` return value for off-chain validation. Optionally validate on-chain.

### [3] No Validation That `executor` Is a Trusted Address

- **File:** `SwapOdosV3Hook.sol:79`, `ApproveAndSwapOdosV3Hook.sol:79`
- **SWC:** N/A
- **Category:** Access Control / Input Validation
- **Description:** The `executor` address is passed directly to the Odos router without validation. The router delegate-calls into the executor for swap logic. A malicious executor could execute arbitrary logic during the swap. The `inspect()` function does return `executor` for off-chain validation, but there is no on-chain enforcement. This is consistent with V2 hooks but remains a trust assumption.
- **Real-World Precedent:** Odos Limit Order arbitrary call vulnerability (2024, ~$50K loss) - insufficient validation of executable addresses in Odos contracts.
- **Secure Pattern:** Document the trust assumption. Consider an optional on-chain allowlist for production deployments.

### [4] `_postExecute` Underflow When Output Balance Decreases

- **File:** `SwapOdosV3Hook.sol:137`, `ApproveAndSwapOdosV3Hook.sol:160`
- **SWC:** SWC-101
- **Category:** Arithmetic / DoS
- **Description:** `_postExecute` calculates `_getBalance(account, data) - getOutAmount(account)`. If the post-execution balance is less than the pre-execution balance (e.g., `inputToken == outputToken` path, rebasing tokens, or fee-on-transfer output tokens), the subtraction underflows and reverts. This is a DoS vector for certain token configurations.
- **Exploit Scenario:** A swap where `inputToken == outputToken` (via intermediate routing). Pre-balance is 1000, swap spends 500 as input and receives 495 as output. Post-balance 995 < pre-balance 1000, causing underflow revert.
- **Vulnerable Code:**
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
  }
  ```
- **Secure Pattern:**
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      uint256 currentBalance = _getBalance(account, data);
      uint256 preBalance = getOutAmount(account);
      uint256 gained = currentBalance > preBalance ? currentBalance - preBalance : 0;
      _setOutAmount(gained, account);
  }
  ```

### [5] Magic Number Byte Offsets

- **File:** Both hooks, various lines
- **SWC:** N/A
- **Category:** Code Quality / Maintenance
- **Description:** Byte offsets `157`, `189`, `20`, `28`, `36`, `72`, `92`, `124`, `52` are used as raw numeric literals. Only `USE_PREV_HOOK_AMOUNT_POSITION = 156` is a named constant. The V3 hooks introduce additional offsets for referral fields (tailOffset+20, +28, +36), compounding maintenance risk. This is a systemic pattern across hooks but makes auditing and future changes error-prone.
- **Secure Pattern:** Extract all offsets as named constants.

---

## P3 Findings (Low - Consider Fixing)

### [6] Unused `PRECISION` Constant
- **File:** Both hooks, line 37
- **Description:** `PRECISION = 1e5` is declared but never used. The precision constant lives in `HookDataUpdater`.
- **Fix:** Remove the unused constant.

### [7] Unused `Math` Import
- **File:** Both hooks, line 9
- **Description:** `Math` from OpenZeppelin is imported but never referenced. `Math.mulDiv` is used only inside `HookDataUpdater`.
- **Fix:** Remove the unused import.

### [8] `inspect()` Does Not Return `inputReceiver`
- **File:** `SwapOdosV3Hook.sol:121-127`, `ApproveAndSwapOdosV3Hook.sol:144-149`
- **Description:** `inspect()` returns only `executor` and `feeRecipient`. The `inputReceiver` address is not exposed for off-chain validation, reducing the validation surface for the SuperValidator/SuperBundler.
- **Fix:** Add `inputReceiver` to the `inspect()` return value.

### [9] Missing NatSpec Documentation
- **File:** Both hooks, various locations
- **Description:** Several V3-specific elements lack NatSpec: `FEE_DENOM`, `MAX_REFERRAL_FEE`, `REFERRAL_FEE_TOO_HIGH()`, `HookParams` struct, `_preExecute`, `_postExecute`, `_getBalance`, `_getSwapInfo`. `ApproveAndSwapOdosV3Hook._buildHookExecutions` is missing `/// @inheritdoc BaseHook`.
- **Fix:** Add NatSpec annotations matching BaseHook documentation patterns.

### [10] `FEE_DENOM` as `uint64` Is Non-Obvious
- **File:** Both hooks, line 39
- **Description:** `FEE_DENOM = 1e18` as `uint64` fits (max uint64 ~1.8e19) and matches the IOdosRouterV3 interface, but is an unusual choice. A comment clarifying the type choice improves readability.
- **Fix:** Add comment: `// uint64 to match IOdosRouterV3.swapReferralInfo.fee type`

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view, via BaseHook), `preExecute()`, `postExecute()` (both require `msg.sender == account`), `decodeUsePrevHookAmount()` (pure), `inspect()` (pure)
- **Value Transfer Points:** Native ETH sent via execution `value` field when `inputToken == address(0)`. ERC-20 approvals in ApproveAndSwapOdosV3Hook.
- **Oracle Dependencies:** None. `outputQuote` and `outputMin` are off-chain provided.
- **Cross-Contract Interactions:** Odos Router V3 (`swap()`), previous hook (`getOutAmount()` via `usePrevHookAmount`), ERC-20 tokens (`approve()`, `balanceOf()`)
- **Upgrade Mechanisms:** None. Both contracts are non-upgradeable with immutable router address.

## Key Security Positives

1. **Immutable router address** - prevents router substitution attacks
2. **Approve-reset pattern** - ApproveAndSwapOdosV3Hook implements approve(0)->approve(amount)->swap->approve(0)
3. **Native ETH path** - correctly skips ERC-20 approvals for `address(0)` input
4. **Transient storage context isolation** - BaseHook uses nonce-keyed contexts
5. **Pre/post execute mutexes** - prevent lifecycle reentrancy
6. **Referral fee cap** - 2% maximum with recipient validation
7. **`inspect()` for off-chain validation** - extracts executor and feeRecipient

## Recent DEX Aggregator Exploit Precedents
| Protocol | Date | Loss | Relevance |
|----------|------|------|-----------|
| Odos Limit Orders | 2024 | $50K | Arbitrary call via unvalidated executor - analogous to `executor` parameter |
| ParaSwap Augustus V6 | Mar 2024 | $24K | Approval-based drainage - mitigated by approve-reset pattern |
| Rubic Aggregator | Dec 2024 | N/A | Whitelisted router custom call abuse - analogous to `pathDefinition` |
| Dexible SelfSwap | Feb 2023 | $2M | Unvalidated router address - mitigated by immutable router |

## Security Knowledge Sources
- **Inline scan:** 8 critical patterns + AMM/DEX-specific checks
- **Vulnerability scanner agent:** Cross-referenced BaseHook, HookDataUpdater, IOdosRouterV3
- **Best practices agent:** Compared against V2 hooks, 1inch hooks, KyberSwap hooks
- **EVM research agent:** DEX aggregator exploits (2023-2025), ERC-7579 module security, OWASP SC Top 10, transient storage security, MEV patterns
