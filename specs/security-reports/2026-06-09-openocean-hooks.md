# Security Analysis Report

## Metadata
- **Target:** `src/libraries/OpenOceanDynamicAmountUpdater.sol`, `src/hooks/swappers/openocean/SwapOpenOceanHook.sol`, `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol`
- **Mode:** review
- **Date:** 2026-06-09
- **Contract Types Detected:** DEX/Swapper hooks, Library
- **Files Analyzed:** 3
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 3 | Yes |
| P2 Medium | 4 | No |
| P3 Low | 5 | No |

## Verdict
**FAIL** - 3 blocking findings (P1) must be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [P1-1] No Validation of `desc.dstReceiver` — Swap Output Sent to Arbitrary Address

- **File:** `src/libraries/OpenOceanDynamicAmountUpdater.sol:52-55`
- **SWC:** N/A
- **Category:** Access Control
- **Description:** The `updateTxDataAmounts` function validates `desc.referrer` but never validates `desc.dstReceiver`. An attacker who controls the `txData_` parameter (via the hook's `data` calldata) can set `dstReceiver` to their own address, causing the swap output to be sent to them instead of the smart account. The existing 1inch hooks in the same codebase (`OneInchV6DynamicAmountUpdater`) validate `dstReceiver` against the expected receiver.
- **Exploit Scenario:** A malicious off-chain bundler or compromised API response provides txData where `desc.dstReceiver` is set to the attacker's address. The swap executes successfully, but all output tokens go to the attacker rather than the user's smart account.
- **Vulnerable Code:**
  ```solidity
  // Only referrer is validated — dstReceiver is not checked
  if (desc.referrer != expectedReferrer_) revert INVALID_OPENOCEAN_REFERRER();
  if ((desc.flags & PARTIAL_FILL) != 0) revert PARTIAL_FILL_NOT_ALLOWED();

  desc.amount = newAmount_;
  desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(...);
  ```
- **Secure Pattern:**
  ```solidity
  function updateTxDataAmounts(
      bytes memory txData_,
      address expectedReferrer_,
      address expectedReceiver_,  // Add receiver parameter
      uint256 newAmount_,
      uint256 originalAmount_
  ) internal pure returns (bytes memory) {
      // ... decode ...
      if (desc.referrer != expectedReferrer_) revert INVALID_OPENOCEAN_REFERRER();
      if (desc.dstReceiver != expectedReceiver_) revert INVALID_DST_RECEIVER();
      // ...
  }
  ```
- **Reference:** Comparison with `OneInchV6DynamicAmountUpdater` in same codebase which validates `desc.dstReceiver`

### [P1-2] No Validation of `desc.dstToken` Against Expected `outputToken`

- **File:** `src/hooks/swappers/openocean/SwapOpenOceanHook.sol:59-65`, `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol:59-67`
- **SWC:** N/A
- **Category:** Logic
- **Description:** Both hooks decode `outputToken` from the hook data (used for balance tracking in `_preExecute`/`_postExecute`) but never validate that `desc.dstToken` inside the OpenOcean txData matches this expected `outputToken`. If they diverge, the swap may output a different token than what the hook tracks, causing incorrect `outAmount` accounting and potential fund loss in subsequent hooks.
- **Exploit Scenario:** Crafted txData has `desc.dstToken = USDT` while hookData has `outputToken = USDC`. The swap outputs USDT (which the hook doesn't track), and `_postExecute` computes an incorrect `outAmount` based on USDC balance change (which may be zero), breaking downstream hook chains.
- **Vulnerable Code:**
  ```solidity
  address outputToken = BytesLib.toAddress(data, 0);
  // ... later ...
  _validateTokenPair(_getInputToken(txData_), outputToken);
  // desc.dstToken is never compared to outputToken
  ```
- **Secure Pattern:**
  ```solidity
  address outputToken = BytesLib.toAddress(data, 0);
  address txDataOutputToken = _getOutputToken(txData_);
  if (!_isSameToken(txDataOutputToken, outputToken)) revert OUTPUT_TOKEN_MISMATCH();
  ```
- **Reference:** vulnerabilities.md Section 8 (Logic Errors)

### [P1-3] Unvalidated `caller` Address in OpenOcean Swap Call

- **File:** `src/libraries/OpenOceanDynamicAmountUpdater.sol:38-44`
- **SWC:** N/A
- **Category:** Access Control
- **Description:** The `caller` field (first parameter of `IOpenOceanExchange.swap`) is decoded from txData but never validated. The `caller` contract is the entity that receives the tokens and executes the actual swap route via `makeCalls()`. The existing 1inch hook validates the equivalent field (`executor`) against a known allowlist. A malicious `caller` contract could steal tokens that are sent to it during the swap execution.
- **Exploit Scenario:** An attacker provides txData with a malicious `caller` contract. When the OpenOcean router calls `caller.makeCalls()`, the malicious contract receives the input tokens and never returns them, effectively draining the user's funds.
- **Vulnerable Code:**
  ```solidity
  (
      IOpenOceanCaller caller,
      IOpenOceanExchange.SwapDescription memory desc,
      IOpenOceanCaller.CallDescription[] memory calls
  ) = abi.decode(...);
  // caller is never validated
  ```
- **Secure Pattern:**
  ```solidity
  // Option A: Validate caller in the library
  if (address(caller) != expectedCaller_) revert INVALID_CALLER();

  // Option B: Validate caller in inspect() function
  // The existing inspect() already returns address(caller) — ensure off-chain validation uses this
  ```
- **Reference:** Comparison with `OneInchV6DynamicAmountUpdater` which validates the executor

---

## P2 Findings (Medium - Should Fix)

### [P2-1] HookDataUpdater Precision Loss Can Zero Out `minReturnAmount`

- **File:** `src/libraries/OpenOceanDynamicAmountUpdater.sol:53-55`
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:** `HookDataUpdater.getUpdatedOutputAmount` uses a two-step percentage calculation with `1e5` PRECISION constant. When `newAmount_` is significantly smaller than `originalAmount_`, the percentage calculation can truncate to zero, resulting in `minReturnAmount = 0`. This eliminates slippage protection entirely.
- **Exploit Scenario:** Original amount is 1000e18, new amount is 0.001e18. The percentage ratio truncates to zero, making `minReturnAmount = 0`, allowing the swap to return near-zero output without reverting.
- **Vulnerable Code:**
  ```solidity
  desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.minReturnAmount);
  desc.guaranteedAmount = HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.guaranteedAmount);
  ```
- **Secure Pattern:**
  ```solidity
  desc.minReturnAmount = HookDataUpdater.getUpdatedOutputAmount(newAmount_, originalAmount_, desc.minReturnAmount);
  if (desc.minReturnAmount == 0 && newAmount_ > 0) revert ZERO_MIN_RETURN();
  ```
- **Reference:** vulnerabilities.md Section 3 (Precision Loss)

### [P2-2] Missing Zero-Amount Check After `usePrevHookAmount` Resolution

- **File:** `src/hooks/swappers/openocean/SwapOpenOceanHook.sol:67-70`, `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol:69-73`
- **SWC:** N/A
- **Category:** Logic
- **Description:** When `usePrevHookAmount` is true, `executionAmount` is set from `prevHook.getOutAmount(account)`. If the previous hook returned zero (e.g., failed silently), the swap proceeds with zero input amount. While `OpenOceanDynamicAmountUpdater` reverts on zero, adding explicit validation in the hook provides defense-in-depth.
- **Vulnerable Code:**
  ```solidity
  uint256 executionAmount = inputAmount;
  if (usePrevHookAmount) {
      executionAmount = ISuperHookResult(prevHook).getOutAmount(account);
  }
  // No check for executionAmount == 0
  ```
- **Secure Pattern:**
  ```solidity
  if (usePrevHookAmount) {
      executionAmount = ISuperHookResult(prevHook).getOutAmount(account);
      if (executionAmount == 0) revert ZERO_EXECUTION_AMOUNT();
  }
  ```
- **Reference:** vulnerabilities.md Section 8 (Input Validation)

### [P2-3] `inputToken` from Hook Data Not Validated Against `desc.srcToken` in ApproveAndSwap

- **File:** `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol:59-67`
- **SWC:** N/A
- **Category:** Logic
- **Description:** The `ApproveAndSwap` variant decodes `inputToken` from hookData offset 0 and uses it for ERC20 approval. It validates `inputToken != outputToken` and `_getInputToken(txData_) != outputToken`, but never validates that `inputToken == _getInputToken(txData_)`. If they differ, the hook approves token A but the swap pulls token B.
- **Vulnerable Code:**
  ```solidity
  address inputToken = BytesLib.toAddress(data, 0);
  // ...
  _validateTokenPair(inputToken, outputToken);
  _validateTokenPair(_getInputToken(txData_), outputToken);
  // inputToken vs _getInputToken(txData_) never compared
  ```
- **Secure Pattern:**
  ```solidity
  address inputToken = BytesLib.toAddress(data, 0);
  address txDataInputToken = _getInputToken(txData_);
  if (inputToken != txDataInputToken) revert INPUT_TOKEN_MISMATCH();
  _validateTokenPair(inputToken, outputToken);
  ```
- **Reference:** vulnerabilities.md Section 8 (Logic Errors)

### [P2-4] Redundant Triple ABI Decoding of `txData` (Gas Optimization)

- **File:** `src/hooks/swappers/openocean/SwapOpenOceanHook.sol:65,72-74,75`
- **SWC:** N/A
- **Category:** Gas
- **Description:** Both hooks decode txData's ABI-encoded parameters up to 3 times per call: once in `_getInputToken()` for validation, once in `OpenOceanDynamicAmountUpdater.updateTxDataAmounts()`, and once in `_isNativeInput()`. Each decode allocates fresh memory for the full SwapDescription struct and CallDescription[] array.
- **Secure Pattern:** Decode once and pass the struct through, or cache the input token address.
- **Reference:** vulnerabilities.md Section 13 (Gas Optimization)

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Referrer Check as Sole Security Gate Is Weak

- **File:** `src/libraries/OpenOceanDynamicAmountUpdater.sol:47`
- **Category:** Access Control
- **Description:** The referrer field in OpenOcean's SwapDescription is user-settable. While spoofing it requires the attacker to know the expected referrer address, the referrer is a public immutable on the hook contract and can be read by anyone. The referrer check is a convenience validation, not a security boundary. The `inspect()` function provides the actual off-chain security gate.
- **Reference:** Design tradeoff acknowledged — `inspect()` is the primary security mechanism.

### [P3-2] `_postExecute` Underflow Risk with Fee-on-Transfer Tokens

- **File:** `src/hooks/swappers/openocean/SwapOpenOceanHook.sol:110`, `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol:132`
- **Category:** Token
- **Description:** `_postExecute` computes `_getBalance(account, data) - getOutAmount(account)`. If the output token is fee-on-transfer and the post-swap balance is less than the pre-swap balance stored in `outAmount`, this underflows. Solidity 0.8.30 would revert, causing a permanent DoS for that hook execution.
- **Reference:** vulnerabilities.md Section 10 (Token Integration)

### [P3-3] Native Call Value Sum Validation Edge Case

- **File:** `src/libraries/OpenOceanDynamicAmountUpdater.sol:84-85`
- **Category:** Logic
- **Description:** `_scaleNativeCallValues` returns early if `originalValueSum == 0`, but then checks `originalValueSum != originalAmount_`. If the OpenOcean route has native input but routes through a wrapper (so no calls carry value), this would pass validation when it shouldn't. Low risk — OpenOcean API typically constructs valid routes.

### [P3-4] `abi.encodePacked` in `inspect()` — No Current Collision Risk

- **File:** `src/hooks/swappers/openocean/SwapOpenOceanHook.sol:100-102`
- **Category:** Code Quality
- **Description:** `inspect()` uses `abi.encodePacked` with multiple `address` values. Since all values are fixed-width (20 bytes), there's no collision risk. However, `abi.encode` would be safer if the return format ever changes.
- **Reference:** vulnerabilities.md Section 9

### [P3-5] Unused Variable Silencing Pattern

- **File:** `src/hooks/swappers/openocean/SwapOpenOceanHook.sol:98`, `src/hooks/swappers/openocean/ApproveAndSwapOpenOceanHook.sol:120`
- **Category:** Code Quality
- **Description:** `calls;` used as a bare statement to silence the unused variable warning. Standard Solidity convention is to leave unnamed: `(, , ) = abi.decode(...)` or comment the variable name.

---

## Attack Surface Summary

### External Entry Points
- `_buildHookExecutions()` — called by the execution framework with user-supplied `data` calldata
- `inspect()` — pure function for off-chain validation
- `decodeUsePrevHookAmount()` — pure decoder
- `_preExecute()` / `_postExecute()` — hook lifecycle, called by framework

### Value Transfer Points
- OpenOcean router swap execution (native ETH value or ERC20 via approval)
- `desc.dstReceiver` determines where swap output goes (UNVALIDATED — P1-1)

### Oracle Dependencies
- None (swap amounts determined by DEX routing, not oracles)

### Cross-Contract Interactions
- `ISuperHookResult(prevHook).getOutAmount(account)` — reads previous hook output
- `IOpenOceanExchange(OPENOCEAN_ROUTER).swap()` — external swap execution
- `IERC20.approve()` / `IERC20.balanceOf()` — standard token interactions

### Key Comparison: OpenOcean vs 1inch Hooks (Same Codebase)
| Validation | 1inch Hook | OpenOcean Hook |
|------------|-----------|----------------|
| Executor/Caller | Validated | **NOT validated** |
| dstReceiver | Validated (== account) | **NOT validated** |
| srcReceiver | Validated | **NOT validated** |
| dstToken vs outputToken | Validated | **NOT validated** |
| Referrer | N/A | Validated |
| Route internals | Fully decoded & validated | **NOT decoded** |

---

## Coding Standards Findings

- Missing NatSpec on `_buildHookExecutions`, `_preExecute`, `_postExecute`, `_getBalance`, `_isNative`, `_isNativeInput`, `_getInputToken`
- Missing `@inheritdoc` annotations on overridden functions
- Import grouping does not follow Superform convention (OpenZeppelin → external → internal → interfaces)
- Unused variable silenced with bare statement instead of unnamed parameter
- Inconsistent native token handling: library uses hardcoded `ETH_ADDRESS`, hooks use immutable `NATIVE`

---

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 8, 9, 10, 13, 15
- **evmresearch.io patterns checked:** DEX integration risks, approval patterns, MEV/sandwich, calldata manipulation
- **Coding rules validated:** NatSpec, imports, naming, error handling
- **Historical exploits cross-referenced:** OpenOcean-specific and DEX aggregator exploits from Appendix J/K/L/M
- **Codebase comparison:** OneInchV6DynamicAmountUpdater, SwapOneInchV6Hook, ApproveAndSwapOneInchV6Hook
