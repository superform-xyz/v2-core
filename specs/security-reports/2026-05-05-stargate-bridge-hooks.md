# Security Analysis Report

## Metadata
- **Target:** `src/hooks/bridges/stargate/` (StargateSendHook.sol, ApproveAndStargateSendHook.sol)
- **Mode:** review
- **Date:** 2026-05-05
- **Contract Types Detected:** Bridge (cross-chain via LayerZero V2/Stargate V2)
- **Files Analyzed:** 2
- **Lines of Code:** 384 (170 + 214)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

The hooks follow the established Across bridge hook patterns closely. The primary design trade-off (user-controlled pool address vs immutable) is intentional and mitigated by the Merkle-signed data + `inspect()` allowlisting system.

---

## P0 Findings (Critical - Must Fix)

None found.

## P1 Findings (High - Must Fix)

None found.

## P2 Findings (Medium - Should Fix)

### [P2-1] User-Controlled `stargatePool` Target Without On-Chain Pool Validation

- **File:** `StargateSendHook.sol:112` and `ApproveAndStargateSendHook.sol:117`
- **SWC:** N/A
- **Category:** Trust Model / Insufficient Validation
- **Description:** Unlike the Across hook which stores `SPOKE_POOL_V3` as an immutable, the `stargatePool` address comes from user-signed hook data. While the data IS user-signed (Merkle proof validated), and `inspect()` exposes it for off-chain allowlisting, no on-chain validation confirms the address is a legitimate Stargate pool. If the off-chain validation layer (bundler/inspect check) has a gap, a malicious pool address would receive ETH (StargateSendHook) or token approvals (ApproveAndStargateSendHook).
- **Exploit Scenario:** A compromised bundler constructs hook data with a malicious contract as `stargatePool`. The user signs this (trusting the bundler). When executed, the malicious contract receives `lzNativeFee + amountLD` in native ETH, or token approval + LZ fee in the ERC20 variant.
- **Vulnerable Code:**
  ```solidity
  if (s.stargatePool == address(0)) revert POOL_NOT_VALID();
  // Only checks != address(0), no legitimacy validation
  ```
- **Secure Pattern:** Add pool legitimacy check (increases gas but adds defense-in-depth):
  ```solidity
  // Verify pool's declared token matches expected inputToken
  // For native hook, verify pool.token() == address(0)
  if (IStargate(s.stargatePool).token() != expectedToken) revert POOL_NOT_VALID();
  ```
  *Note:* This is a documented design decision per the spec. The `inspect()` function provides the off-chain validation path. Consider whether on-chain enforcement is worth the gas cost.
- **Reference:** Trust boundary validation, defense-in-depth

---

### [P2-2] Input Validation Ordering - Address Checks After External Call

- **File:** `StargateSendHook.sol:100-113` and `ApproveAndStargateSendHook.sol:105-119`
- **SWC:** N/A
- **Category:** Logic / CEI Pattern
- **Description:** When `usePrevHookAmount=true`, the code calls `ISuperHookResult(prevHook).getOutAmount(account)` (external call) before validating `stargatePool`, `inputToken`, and `to` addresses. If these addresses are invalid, the external call is wasted gas. While this is a view function (no state mutation risk), it violates the Checks-Effects-Interactions principle for validation ordering.
- **Exploit Scenario:** No direct exploit. A transaction with invalid addresses wastes gas on the `prevHook` call before reverting. This is a gas-efficiency and code clarity issue.
- **Vulnerable Code:**
  ```solidity
  if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
      uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account); // external call
      // ... scaling logic
  }
  if (s.amountLD == 0) revert AMOUNT_NOT_VALID();
  if (s.stargatePool == address(0)) revert POOL_NOT_VALID(); // checked AFTER external call
  if (s.to == bytes32(0)) revert ADDRESS_NOT_VALID();
  ```
- **Secure Pattern:**
  ```solidity
  if (s.stargatePool == address(0)) revert POOL_NOT_VALID();
  if (s.to == bytes32(0)) revert ADDRESS_NOT_VALID();
  // For ApproveAndStargateSendHook: if (s.inputToken == address(0)) revert ADDRESS_NOT_VALID();

  if (_decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION)) {
      uint256 outAmount = ISuperHookResult(prevHook).getOutAmount(account);
      if (s.amountLD > 0 && s.minAmountLD > 0) {
          s.minAmountLD = Math.mulDiv(s.minAmountLD, outAmount, s.amountLD);
      }
      s.amountLD = outAmount;
  }
  if (s.amountLD == 0) revert AMOUNT_NOT_VALID();
  ```
- **Reference:** Checks-Effects-Interactions pattern, fail-fast validation

---

### [P2-3] Data Length Validation Insufficient for Variable-Length Fields

- **File:** `StargateSendHook.sol:82` and `ApproveAndStargateSendHook.sol:86`
- **SWC:** SWC-129
- **Category:** Data Validation / Bounds Checking
- **Description:** The check `data.length < 238` only validates the fixed-field portion. After reading `extraOptionsLength` at offset 174, the code slices variable-length data without first validating that `data.length >= 238 + extraOptionsLength + composeMsgLength`. While `BytesLib.slice` will revert on out-of-bounds, the error is a generic string revert ("slice_outOfBounds") rather than the informative `DATA_NOT_VALID()` error, making debugging and monitoring harder.
- **Exploit Scenario:** Malformed data with `extraOptionsLength` exceeding actual data length causes BytesLib revert instead of clean custom error. Not exploitable for fund theft (reverts), but degrades error handling quality.
- **Vulnerable Code:**
  ```solidity
  if (data.length < 238) revert DATA_NOT_VALID();
  uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
  s.extraOptions = BytesLib.slice(data, 206, extraOptionsLength); // could revert with generic error
  ```
- **Secure Pattern:**
  ```solidity
  if (data.length < 238) revert DATA_NOT_VALID();
  uint256 extraOptionsLength = BytesLib.toUint256(data, 174);
  if (data.length < 238 + extraOptionsLength) revert DATA_NOT_VALID();
  s.extraOptions = BytesLib.slice(data, 206, extraOptionsLength);

  uint256 composeMsgOffset = 206 + extraOptionsLength;
  uint256 composeMsgLength = BytesLib.toUint256(data, composeMsgOffset);
  if (data.length < composeMsgOffset + 32 + composeMsgLength) revert DATA_NOT_VALID();
  ```
- **Reference:** Input validation, defensive programming

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] `inspect()` Truncates `bytes32` Recipient to `address`

- **File:** `StargateSendHook.sol:167` and `ApproveAndStargateSendHook.sol:154`
- **SWC:** N/A
- **Category:** Information Loss
- **Description:** The `to` field is `bytes32` (supporting non-EVM chains per LayerZero V2), but `inspect()` truncates it to `address` via `address(uint160(uint256(...)))`. Two different non-EVM recipients with the same lower 20 bytes but different upper 12 bytes would produce identical `inspect()` output, potentially bypassing off-chain whitelist checks.
- **Secure Pattern:** Return full `bytes32`:
  ```solidity
  BytesLib.toBytes32(data, 76) // to (full bytes32 for cross-VM support)
  ```

### [P3-2] `abi.decode` of `composeMsg` Reverts with Uninformative Error

- **File:** `StargateSendHook.sol:119-125` and `ApproveAndStargateSendHook.sol:125-131`
- **SWC:** N/A
- **Category:** Error Handling
- **Description:** If `composeMsg` is non-empty but malformed, `abi.decode` reverts with a generic panic rather than `DATA_NOT_VALID()`. Since data is user-signed, this is self-grief only, but makes monitoring harder.
- **Secure Pattern:** Add minimum length check before decode:
  ```solidity
  if (s.composeMsg.length > 0) {
      if (s.composeMsg.length < 160) revert DATA_NOT_VALID(); // min ABI-encoded size
      // ... decode
  }
  ```

### [P3-3] No On-Chain Validation That `inputToken` Matches Pool's Token

- **File:** `ApproveAndStargateSendHook.sol:118`
- **SWC:** N/A
- **Category:** Logical Consistency
- **Description:** If `inputToken` and `stargatePool` are mismatched (user error), the approval is granted for the wrong token. The cleanup `approve(0)` at the end would still execute, but a dangling intermediate state exists within the batch.
- **Secure Pattern:** `if (IStargate(s.stargatePool).token() != s.inputToken) revert POOL_NOT_VALID();`

### [P3-4] Missing Constructor and Error NatSpec

- **File:** Both hooks
- **SWC:** N/A
- **Category:** Documentation
- **Description:** Constructors lack `@param` tags. Custom errors `DATA_NOT_VALID()` and `POOL_NOT_VALID()` lack `@notice` documentation. Consistent with existing Across hooks but below the BaseHook documentation standard.

### [P3-5] Bus Mode Liveness Dependency

- **File:** Both hooks (bus mode path)
- **SWC:** N/A
- **Category:** Liveness / External Dependency
- **Description:** When `isBusMode=true`, the transfer is batched and only sent when the bus reaches capacity or `driveBus` is called. This creates delivery latency that could be problematic for time-sensitive cross-chain operations with composeMsg execution.
- **Mitigation:** Documented in spec. Off-chain systems should understand bus mode latency implications.

---

## Attack Surface Summary

### External Entry Points
- `build(address prevHook, address account, bytes calldata data)` (inherited from BaseHook, delegates to `_buildHookExecutions`)
- `decodeUsePrevHookAmount(bytes memory data)` (pure, informational)
- `inspect(bytes calldata data)` (pure, informational)

### Value Transfer Points
- **StargateSendHook:** Sends `lzNativeFee + amountLD` native ETH to `stargatePool`
- **ApproveAndStargateSendHook:** Grants ERC20 approval to `stargatePool`, sends `lzNativeFee` native ETH

### External Protocol Dependencies
- Stargate V2 pool contracts (`sendToken`)
- LayerZero V2 endpoint (underlying transport)
- ISuperHookResult (`prevHook.getOutAmount` when `usePrevHookAmount=true`)
- ISuperSignatureStorage (`VALIDATOR.retrieveSignatureData` for compose signature)

### Trust Assumptions
1. User signs correct pool address (validated off-chain via `inspect()`)
2. Bundler proposes legitimate parameters
3. Stargate V2 pools function correctly (external dependency)
4. LayerZero V2 DVN configuration is secure (external dependency)
5. Transient storage signature is available when hook executes (execution ordering)

---

## Coding Standards Findings

**Overall Compliance: HIGH**

The hooks closely mirror the Across bridge hook patterns. Key observations:
- Import organization: Correct (external/Superform grouping)
- Custom errors: Used throughout (no require strings)
- Section headers: Consistent with project conventions
- Approval pattern: Correctly implements USDT-safe reset-approve-execute-cleanup
- Visibility modifiers: Appropriate (`private pure` for helper in approve variant)

Minor: Missing NatSpec on constructors/errors (consistent with Across, but below BaseHook standard).

---

## External Security Research Highlights

| Concern | Source | Relevance | Risk |
|---------|--------|-----------|------|
| DVN compromise (KelpDAO $292M, Apr 2026) | Blockaid | Stargate uses robust multi-DVN; external dependency | P2 (external) |
| LZ V2 compose sender validation | LZ Security Checklist | Destination receiver must validate sender | P2 (external) |
| Bus mode liveness | Stargate Docs | Batched delivery may delay compose execution | P3 |
| Cross-chain MEV on compose | Stanford Blockchain Review | Compose reveals intent; MEV on destination | P3 (systemic) |
| Transient storage timing | ChainSecurity/Hexens | Signature must be available during hook exec | P2 (arch) |

---

## Security Knowledge Sources
- **Vulnerability patterns checked:** Reentrancy, Access Control, Arithmetic, Token Integration, Bridge/Cross-Chain, Oracle, Flash Loan, MEV, DoS, Proxy
- **External research:** LayerZero V2 Security Audit Checklist, Stargate V2 docs, KelpDAO exploit analysis, bridge security best practices
- **Coding rules validated:** 15 rules from project conventions
- **Historical exploits cross-referenced:** KelpDAO (DVN compromise), Stargate V1 patterns, bridge exploits 2023-2025
