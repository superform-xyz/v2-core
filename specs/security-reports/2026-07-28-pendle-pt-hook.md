# Security Analysis Report

## Metadata
- **Target:** `src/hooks/swappers/pendle/PendlePTHook.sol`
- **Mode:** review
- **Date:** 2026-07-28
- **Contract Types Detected:** DeFi Hook, AMM Integration, Limit Order, Yield Protocol
- **Files Analyzed:** 6 (PendlePTHook.sol, BaseHook.sol, IPendleRouterV4.sol, PendleUnifiedHook.sol, IPendleMarket.sol, IPYieldToken.sol)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 1 | Yes |
| P2 Medium | 4 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** - No P0 findings. One P1 finding is an accepted, documented trust assumption (not a code bug). Safe to proceed with noted recommendations.

---

## P0 Findings (Critical)

None found.

---

## P1 Findings (High)

### [P1-1] Double `readTokens()` in buy path: redundant external call + missing SY validation

- **File:** `PendlePTHook.sol:193` and `PendlePTHook.sol:414`
- **SWC:** N/A
- **Severity:** P1 High
- **Category:** State Consistency / Validation Gap
- **Description:** The buy path calls `readTokens()` twice: once at line 193 (in `_buildHookExecutions`) to derive `(sy, pt, yt)` for routing, and again at line 414 (in `_buildSwapTokenForPtExecutions`) to re-derive `pt` for the output token. This creates two issues:
  1. **TOCTOU risk:** If a malicious market returns different values between calls, the routing logic validates against one PT while the execution targets another. The `OUTPUT_TOKEN_MISMATCH` check at line 225 would catch a divergence, but the window exists.
  2. **Missing SY validation in buy path:** The sell and redeem paths validate `tokenRedeemSy`/`tokenOut` against SY (`isValidTokenOut`), but the buy path never validates `tokenMintSy` against `isValidTokenIn`. The `sy` from line 193 is not passed to the buy builder.
  3. **Gas waste:** ~2600 gas for the redundant warm external call.

  Note: PendleUnifiedHook has the exact same double `readTokens()` pattern. Within legitimate Pendle markets, `readTokens()` returns immutable values. The risk applies only if `yieldSource` points to a malicious contract.
- **Exploit Scenario:** A malicious market contract returns different values on successive `readTokens()` calls. The first call passes the routing check, the second returns a different PT. The `OUTPUT_TOKEN_MISMATCH` guard would revert, so the practical risk is a DoS rather than fund loss.
- **Vulnerable Code:**
  ```solidity
  // Line 193: first readTokens()
  (address sy, address pt, address yt) = IPendleMarket(yieldSource).readTokens();

  // Buy path does NOT pass sy, pt to the builder
  (executions, derivedTokenOut) = _buildSwapTokenForPtExecutions(
      account, yieldSource, headerInputToken, netTokenIn, scaledOutputMin, routingParams
  );

  // Line 414 inside builder: second readTokens()
  (, address pt_,) = IPendleMarket(yieldSource).readTokens();
  tokenOut = pt_;
  ```
- **Secure Pattern:** Pass `pt` from the first `readTokens()` into the builder (same approach as sell/redeem paths):
  ```solidity
  (executions, derivedTokenOut) = _buildSwapTokenForPtExecutions(
      account, yieldSource, headerInputToken, pt, netTokenIn, scaledOutputMin, routingParams
  );
  // Inside builder: tokenOut = pt; (no second readTokens())
  ```

---

## P2 Findings (Medium)

### [P2-1] `epsSkipMarket` not validated

- **File:** `PendlePTHook.sol:639-649`
- **SWC:** N/A
- **Category:** Missing Input Validation
- **Description:** `LimitOrderData.epsSkipMarket` controls when the Pendle Router skips AMM in favor of limit orders. Unlike `ApproxParams.eps` (validated against `MAX_EPS` at line 397), `epsSkipMarket` is unbounded. An extreme value could force the Router to skip the AMM entirely, routing all volume through potentially manipulatable limit orders. The `scaledOutputMin` provides a backstop, but the signer may not realize the AMM was bypassed.
- **Secure Pattern:**
  ```solidity
  if (limit.epsSkipMarket > MAX_EPS) revert EPS_NOT_VALID();
  ```

### [P2-2] `FillOrderParams.signature` not validated

- **File:** `PendlePTHook.sol:652-658`
- **SWC:** N/A
- **Category:** Missing Input Validation
- **Description:** The `signature` field is not checked for emptiness. An empty signature passes hook validation but will be rejected by the Pendle Router, wasting gas and reverting the entire transaction. This could serve as a griefing vector.
- **Secure Pattern:**
  ```solidity
  if (fills[i].signature.length == 0) revert SIGNATURE_NOT_VALID();
  ```

### [P2-3] `order.token` and `order.YT` not validated

- **File:** `PendlePTHook.sol:663-666`
- **SWC:** N/A
- **Category:** Missing Input Validation
- **Description:** `_validateOrder` checks `expiry`, `maker`, and `receiver`, but not `order.token` or `order.YT`. Zero addresses in these fields could cause unexpected Pendle Router behavior. PendleUnifiedHook has the same gap.
- **Secure Pattern:**
  ```solidity
  if (order.token == address(0)) revert ADDRESS_NOT_VALID();
  if (order.YT == address(0)) revert ADDRESS_NOT_VALID();
  ```

### [P2-4] `_postExecute` underflow gives opaque Panic instead of custom error

- **File:** `PendlePTHook.sol:349`
- **SWC:** SWC-101
- **Category:** Arithmetic / Error Handling
- **Description:** If post-execution balance < pre-execution balance (e.g., due to a buggy/malicious market), the subtraction `_getBalance(account, data) - getOutAmount(account)` reverts with `Panic(0x11)` instead of an informative custom error. Same pattern exists in PendleUnifiedHook.
- **Secure Pattern:**
  ```solidity
  uint256 postBalance = _getBalance(account, data);
  uint256 preBalance = getOutAmount(account);
  if (postBalance < preBalance) revert OUTPUT_DECREASED();
  _setOutAmount(postBalance - preBalance, account);
  ```

---

## P3 Findings (Low)

### [P3-1] `order.failSafeRate` not validated
- **File:** `PendlePTHook.sol:663-666` | An extreme `failSafeRate` could lead to poor fills, though `scaledOutputMin` provides a backstop.

### [P3-2] Unbounded `extCalldata` and `permit` lengths
- **File:** `PendlePTHook.sol:669-678` | While `optData` is bounded by `MAX_OPT_DATA_LENGTH` and fills by `MAX_FILLS`, `SwapData.extCalldata` and `Order.permit` have no length bounds, allowing gas-expensive ABI decoding. Since data is signed, the signer bears responsibility.

### [P3-3] `isExpired()` boundary timing edge case
- **File:** `PendlePTHook.sol:209` | At the exact expiry block, a sell intent could route to redeem. The sell-format payload (4 fields) would be decoded as redeem-format (3 fields), causing a safe ABI revert. Not exploitable but worth documenting for intent constructors.

### [P3-4] Import ordering inconsistency
- **File:** `PendlePTHook.sol:19` | `IERC165` (OpenZeppelin) is placed inside the `// Superform` import block instead of with other externals. Shared pattern with PendleUnifiedHook.

### [P3-5] Missing `@param`/`@return` NatSpec on validation helpers
- **File:** `PendlePTHook.sol:638-689` | Functions `_validateLimitOrders`, `_validateFillOrders`, `_validateOrder`, `_validateSwapData`, `_getBalance` lack `@param`/`@return` tags. Consistent with PendleUnifiedHook.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view), `preExecute()`, `postExecute()`, `setExecutionContext()`, `resetExecutionState()`, `setOutAmount()` (all from BaseHook)
- **Value Transfer Points:** Native ETH via `netTokenIn` in buy path (line 449); ERC20 approvals to Pendle Router V4
- **Oracle Dependencies:** `IPendleMarket.readTokens()` (immutable market config, not price oracle); `IPYieldToken.isExpired()` (immutable expiry timestamp)
- **Cross-Contract Interactions:** Pendle Router V4 (`swapExactTokenForPt`, `swapExactPtForToken`, `redeemPyToToken`); SY contract (`isValidTokenOut`, `getTokensIn/Out`); user-supplied `pendleSwap` and `extRouter` (unwhitelisted, per NatSpec)
- **Upgrade Mechanisms:** None (no proxy, no admin functions, immutable router address)

## Checks Passed (No Findings)

| Pattern | Status |
|---------|--------|
| Reentrancy (SWC-107) | PASS - BaseHook uses transient storage mutexes |
| Access Control | PASS - `msg.sender == account` checks in pre/postExecute |
| Division Before Multiplication | PASS - Uses `Math.mulDiv` |
| Unchecked Return Values | PASS - Executions handled by ERC-7579 framework |
| tx.origin (SWC-115) | PASS - Not used |
| Floating Pragma (SWC-103) | PASS - Locked `0.8.30` (vendor files excepted) |
| Returnbomb / EIP-150 | PASS - No try/catch blocks |
| Token Approval Hygiene | PASS - approve(0) + approve(amount) + approve(0) pattern |
| Signature Replay | PASS - Delegated to Pendle Router nonce manager (documented) |
| Flash Loan Attack | PASS - View-only build, no held funds |

## Coding Standards

The contract is well-written with:
- Locked pragma `0.8.30`
- 13 custom errors with NatSpec
- Proper checks-effects-interactions ordering
- Consistent naming with PendleUnifiedHook
- Validation functions extracted as DRY helpers (improvement over PendleUnifiedHook)
- Trust assumptions clearly documented in NatSpec (lines 63-67)

## Security Knowledge Sources
- **Exploit precedents cross-referenced:** Penpie $27M (malicious SY), SIR.trading $355K (tstore collision)
- **Pendle security audits reviewed:** ChainSecurity Pendle V2 Core (Aug 2024)
- **EVM patterns checked:** EIP-1153 tstore reentrancy, ERC20 approve race, ABI decode gas bomb, sandwich MEV
- **SWC patterns checked:** SWC-101, SWC-103, SWC-107, SWC-114, SWC-115, SWC-133
