# Security Analysis Report

## Metadata
- **Target:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`
- **Mode:** review
- **Date:** 2026-07-23
- **Contract Types Detected:** General/AMM (Pendle Router V4 swap and redeem operations)
- **Files Analyzed:** 1
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 2 | Yes |
| P2 Medium | 7 | No |
| P3 Low | 9 | No |

## Verdict
**FAIL** - 2 blocking findings (P1) must be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [1] Missing `tokenRedeemSy` and `tokenOut` Validation in `swapExactPtForToken` Path

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:457-463
- **SWC:** N/A
- **Category:** Logic
- **Description:** In `_buildSwapPtForTokenExecutions`, when `output.swapData.swapType != SwapType.NONE`, the code validates `extRouter` but does NOT validate that `output.tokenRedeemSy` is a valid token out from the SY contract. The `_buildRedeemExecutions` function correctly validates both `output.tokenRedeemSy` (line 331) and `output.tokenOut` (line 341) via `IStandardizedYield(sy).isValidTokenOut()`. This asymmetry means the swap path accepts arbitrary `tokenRedeemSy` or `tokenOut` values without SY validation.
- **Exploit Scenario:** An attacker crafts a `swapExactPtForToken` call with a malicious `tokenRedeemSy` not supported by the SY contract. While the Pendle router may have its own checks, the hook layer inconsistency suggests validation was intended but missed during the unification refactor.
- **Real-World Precedent:** Penpie hack ($27M, Sep 2024) -- exploited inconsistent validation across code paths in Pendle-integrated protocols.
- **Vulnerable Code:**
  ```solidity
  // Lines 457-463 - swapExactPtForToken path
  if (output.swapData.swapType != SwapType.NONE) {
      if (output.swapData.swapType != SwapType.ETH_WETH) {
          if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
              revert INVALID_EXT_ROUTER();
          }
      }
  }
  // Missing: tokenRedeemSy validation and tokenOut validation against SY
  ```
- **Secure Pattern:**
  ```solidity
  (address sy,,) = IPendleMarket(yieldSource).readTokens();
  if (output.swapData.swapType != SwapType.NONE) {
      if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
          revert TOKEN_REDEEM_SY_NOT_VALID();
      }
      if (output.swapData.swapType != SwapType.ETH_WETH) {
          if (output.swapData.extRouter == address(0) || output.swapData.extRouter == NATIVE_TOKEN) {
              revert INVALID_EXT_ROUTER();
          }
      }
  } else {
      if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
          revert TOKEN_OUT_NOT_LISTED();
      }
  }
  ```
- **Reference:** Logic Errors / Inconsistent validation across code paths

---

### [2] Unvalidated `extCalldata` in SwapData Allows Arbitrary External Calls

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:330-338, 457-463
- **SWC:** SWC-107
- **Category:** Access Control
- **Description:** The `SwapData` struct contains `extRouter` (address) and `extCalldata` (bytes). The hook validates `extRouter != address(0)` and `extRouter != NATIVE_TOKEN` but never validates `extCalldata` contents. The Pendle Router V4 forwards a call to `extRouter` with `extCalldata` during swap execution. Since the smart account explicitly approves tokens to the Pendle Router (in the redeem path), a malicious `extCalldata` payload could instruct the external router to route funds to an attacker-controlled address. The `pendleSwap` address in `TokenInput`/`TokenOutput` is also unvalidated and used for intermediate swap aggregation.
- **Exploit Scenario:** A compromised off-chain signer provides `extCalldata` that routes tokens through a malicious aggregator path. The Pendle Router calls `extRouter` with this calldata, which could route funds to an attacker-controlled address rather than back to the Pendle Router.
- **Real-World Precedent:** SwapNet/Aperture Finance exploit ($17M, Jan 2026) -- arbitrary calldata injection through user-controlled external router calls in DeFi aggregators.
- **Vulnerable Code:**
  ```solidity
  // SwapData struct (from IPendleRouterV4.sol):
  struct SwapData {
      SwapType swapType;
      address extRouter;     // Validated: not zero/native
      bytes extCalldata;     // Never validated by the hook
      bool needScale;
  }
  // TokenInput/TokenOutput also contain:
  address pendleSwap;        // Never validated
  ```
- **Secure Pattern:** Consider adding an allowlist of permitted `extRouter` addresses and/or restricting function selectors in `extCalldata`. Validate `pendleSwap` against known Pendle swap aggregator addresses. At minimum, document the trust assumption that `extCalldata` is considered safe because it is part of the signed intent payload.
- **Reference:** Access Control / Arbitrary External Calls; OWASP SC05

---

## P2 Findings (Medium - Should Fix)

### [3] `value` Parameter Override Can Diverge from `netTokenIn` for Native ETH Swaps

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:416-419
- **SWC:** N/A
- **Category:** Logic
- **Description:** When `usePrevHookAmount` is false, `input.tokenIn == address(0)` (native ETH), and `value > 0`, the `execValue` is overridden from `netTokenIn` to `value` (from payload). This means the ETH sent to the Pendle Router can differ from `netTokenIn` used for slippage calculations. A crafted intent could specify `netTokenIn = 1 ETH` but `value = 10 ETH`, causing 10 ETH to be sent while slippage is computed against 1 ETH.
- **Vulnerable Code:**
  ```solidity
  uint256 execValue = (input.tokenIn == address(0)) ? netTokenIn : 0;
  if (!usePrevHookAmount && value > 0 && input.tokenIn == address(0)) {
      execValue = value;
  }
  ```
- **Secure Pattern:**
  ```solidity
  uint256 execValue = (input.tokenIn == address(0)) ? netTokenIn : 0;
  // Remove value override, or validate consistency:
  if (!usePrevHookAmount && value > 0 && input.tokenIn == address(0)) {
      if (value != netTokenIn) revert VALUE_MISMATCH();
      execValue = value;
  }
  ```

---

### [4] Precision Loss in `scaledOutputMin` via `HookDataUpdater` (1e5 Precision)

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:158
- **SWC:** N/A
- **Category:** Arithmetic / MEV
- **Description:** `HookDataUpdater.getUpdatedOutputAmount` uses `PRECISION = 1e5` for percentage calculations. With extreme ratios between `netTokenIn` and `inputAmount`, or for tokens with low decimal precision, the scaled output could suffer precision loss. Combined with MEV, a sandwich attack could extract value when `scaledOutputMin` is lower than intended.
- **Vulnerable Code:**
  ```solidity
  scaledOutputMin = HookDataUpdater.getUpdatedOutputAmount(netTokenIn, inputAmount, outputMin);
  ```
- **Secure Pattern:** Consider validating that `scaledOutputMin` does not deviate from `outputMin` by more than a reasonable bound, or document the precision boundaries.

---

### [5] Missing Approve-Reset Pattern in Swap Paths

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:421-429, 467-475
- **SWC:** SWC-114
- **Category:** Token
- **Description:** `_buildSwapTokenForPtExecutions` and `_buildSwapPtForTokenExecutions` produce only 1 execution (the router call) with no `approve(0) -> approve(amount)` pattern. In contrast, `_buildRedeemExecutions` correctly implements approve-reset-approve (lines 346-380). For USDT-like tokens that require allowance to be set to 0 before changing to non-zero, residual approvals from previous operations would cause reverts.
- **Secure Pattern:** Add explicit approve-reset-approve-execute-cleanup executions in swap paths, consistent with the redeem path.

---

### [6] Unvalidated `pendleSwap` Address in TokenInput/TokenOutput

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:397-404
- **SWC:** N/A
- **Category:** Access Control
- **Description:** Both `TokenInput` and `TokenOutput` contain a `pendleSwap` address used by Pendle Router V4 for intermediate swap aggregation. This address is never validated. A malicious `pendleSwap` contract could perform unexpected operations when called by the Pendle Router during the swap.
- **Secure Pattern:** Validate `pendleSwap` is either `address(0)` (no swap needed) or a whitelisted Pendle swap aggregator.

---

### [7] Penpie-Style Malicious Market/SY Reentrancy Risk

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:322, 331, 341
- **SWC:** SWC-107
- **Category:** Access Control
- **Description:** The hook calls `IPendleMarket(yieldSource).readTokens()` (line 322) and `IStandardizedYield(sy).isValidTokenOut()` (lines 331, 341). Both `yieldSource` and the returned `sy` are derived from user-supplied data. If `yieldSource` points to a malicious market, the returned token addresses could be attacker-controlled, causing the hook to build approvals and calls to malicious contracts. The `yieldSource` is validated only as `yieldSource == market` (from txData), but both come from user input.
- **Real-World Precedent:** Penpie hack ($27M, Sep 2024) -- malicious SY contracts created via permissionless market creation.
- **Secure Pattern:** Validate `yieldSource` against a registry of known-good Pendle markets, or document the trust assumption that intent signers only submit trusted market addresses.

---

### [8] Duplicate ABI Decoding in `_buildHookExecutions` and `_decodeTokenOut`

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:166-178, 504-523
- **SWC:** N/A
- **Category:** Gas
- **Description:** Each builder function fully decodes `txData` (complex structs like `TokenOutput`, `ApproxParams`, `TokenInput`, `LimitOrderData`). Then `_decodeTokenOut(txData)` at line 178 decodes it *again* to extract the output token. This double ABI decoding is significant gas waste. The output token could be returned from each builder function instead.
- **Secure Pattern:** Refactor builders to return `(Execution[] memory, address derivedTokenOut)` and validate in `_buildHookExecutions` without calling `_decodeTokenOut`.

---

### [9] Potential Arithmetic Underflow in `_postExecute` Balance Difference

- **File:** `src/hooks/swappers/pendle/PendleUnifiedHook.sol`:299
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:** `_getBalance(account, data) - getOutAmount(account)` will underflow (revert) if the post-execution balance is lower than pre-execution balance. This is safe (prevents bad accounting) but provides a poor error message. Fee-on-transfer or deflationary tokens would trigger this.
- **Secure Pattern:**
  ```solidity
  uint256 postBalance = _getBalance(account, data);
  uint256 preBalance = getOutAmount(account);
  if (postBalance < preBalance) revert BALANCE_DECREASED();
  _setOutAmount(postBalance - preBalance, account);
  ```

---

## P3 Findings (Low - Consider Fixing)

### [10] Inconsistent Native Token Sentinel (`address(0)` vs `NATIVE_TOKEN`)
- **File:** Line 529 vs line 68
- **Description:** `_getBalance` checks `outputToken == address(0)` for native ETH, but the contract defines `NATIVE_TOKEN = 0xEeee...eeE`. If `outputToken` is set to the common `0xEeee...eeE` sentinel, `_getBalance` would try `balanceOf` on it, reverting.

### [11] No `limitRouter` Validation in `LimitOrderData`
- **File:** Line 414
- **Description:** `_validateLimitOrders` validates fill parameters but not `limit.limitRouter` address.

### [12] `_validateOrder` Does Not Validate `order.nonce`
- **File:** Lines 498-501
- **Description:** Nonce validation is deferred to the Pendle Router. Stale orders pass hook-level validation.

### [13] Gas Griefing via Unbounded `optData`/`permit` in LimitOrderData
- **File:** Lines 479-501
- **Description:** `MAX_FILLS = 64` limits array length, but `optData` and individual `order.permit` fields are unbounded bytes.

### [14] Missing NatSpec on 17 Custom Errors
- **File:** Lines 83-99
- **Description:** All custom errors lack `@notice` documentation. BaseHook documents every error.

### [15] Missing `@inheritdoc` Annotations
- **File:** Lines 294-300, 201-204
- **Description:** `_preExecute`, `_postExecute`, and `_supportsSizingInterface` overrides lack `@inheritdoc BaseHook`.

### [16] Redundant Imports (`IERC165`, `ISuperHook`)
- **File:** Lines 12-19
- **Description:** Both are already available through `BaseHook` inheritance. Reference hooks like `SwapOdosV3Hook` don't import them.

### [17] Inconsistent Error Naming Convention
- **File:** Lines 83-99
- **Description:** Mix of `INVALID_X` and `X_NOT_VALID` patterns. BaseHook uses `X_NOT_VALID`.

### [18] Extra Blank Line Between `description()` and VIEW METHODS Section
- **File:** Lines 118-119
- **Description:** Double blank line where convention uses single.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view, via BaseHook), `preExecute()`, `postExecute()`, `setExecutionContext()`, `decodeAmounts()`, `amountRoles()`, `replaceCalldataAmounts()`, `encodeSwapData()`, `decodeInputToken/OutputToken/InputAmount/OutputQuote/OutputMin/Payload()`, `inspect()`, `supportsInterface()`
- **Value Transfer Points:** ETH forwarded via `execValue` in `swapExactTokenForPt`; ERC-20 approvals to Pendle Router in redeem path (PT, YT)
- **Oracle Dependencies:** None direct; relies on Pendle AMM pricing
- **Cross-Contract Interactions:** `IPendleRouterV4` (swap/redeem), `IPendleMarket.readTokens()`, `IStandardizedYield.isValidTokenOut()`, `IERC20.approve/balanceOf`
- **Upgrade Mechanisms:** None (immutable hook)

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 6 (MEV), 8 (Unchecked Returns), 9 (encodePacked), 10 (Token), 13 (Gas), 15 (Code Quality), 36 (Pre-PR Checklist)
- **evmresearch.io patterns checked:** vulnerability-patterns (AMM/DEX), exploit-analyses (Pendle/yield), security-patterns (DeFi hooks)
- **Historical exploits cross-referenced:** Penpie ($27M, Sep 2024), Cork Protocol ($11M, May 2025), SwapNet/Aperture ($17M, Jan 2026)
- **Coding rules validated:** NatSpec, imports, naming, gas optimization, error patterns
