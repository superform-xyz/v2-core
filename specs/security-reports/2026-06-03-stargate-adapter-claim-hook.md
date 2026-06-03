# Security Analysis Report

## Metadata
- **Target:** `src/adapters/StargateAdapter.sol`, `src/hooks/claim/stargate/ClaimFailedTransferHook.sol`
- **Mode:** review
- **Date:** 2026-06-03
- **Contract Types Detected:** Bridge (LZ V2 compose receiver), Hook (ERC-7579 module)
- **Files Analyzed:** 2
- **Vulnerability Database:** vulnerabilities.md (36+ sections, 373+ patterns, 233+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 7 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

The three previously applied security fixes (compose sender trust, unbacked credits, returnbomb) are correctly implemented. All critical LZ V2 bridge patterns have been mitigated.

---

## P0 Findings (Critical - Must Fix)

None found.

## P1 Findings (High - Must Fix)

None found.

Note: The EVM security researcher identified 2 patterns at P1 severity (compose queue blocking, unbacked credits) but both are **correctly mitigated** in the current implementation.

---

## P2 Findings (Medium - Should Fix)

### [P2-1] Unbounded Return Data in _tryTransfer
- **File:** `src/adapters/StargateAdapter.sol:345-347`
- **SWC:** N/A
- **Category:** Gas / DoS
- **Description:** `_tryTransfer` uses `bytes memory returnData` from a low-level `.call()`. If the token returns an extremely large `bytes` blob, the return data is fully copied into memory inside `handleCompose`. While this won't block the LZ compose queue (the outer `try...catch` catches the OOG), it could cause the entire `handleCompose` to fail. The tokens would remain in the adapter but no `failedTransfers` credit would be recorded (the whole frame reverts before the credit is written).
- **Practical Impact:** Limited — `tokenSent` comes from `IStargate(_from).token()` on a registered Stargate pool, so only legitimate tokens (USDC, USDT, ETH) are used in practice.
- **Exploit Scenario:** A Stargate pool wrapping a non-standard token that returns very large data on `transfer()` could cause `_tryTransfer` to OOG. Tokens would be stranded in the adapter with no accounting entry.
- **Vulnerable Code:**
  ```solidity
  (bool callSuccess, bytes memory returnData) =
      token.call(abi.encodeCall(IERC20.transfer, (account, amount)));
  success = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));
  ```
- **Secure Pattern:** Use assembly to cap return data size:
  ```solidity
  assembly {
      let ptr := mload(0x40)
      mstore(ptr, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
      mstore(add(ptr, 0x04), and(account, 0xffffffffffffffffffffffffffffffffffffffff))
      mstore(add(ptr, 0x24), amount)
      success := call(gas(), token, 0, ptr, 0x44, 0x00, 0x20)
      switch returndatasize()
      case 0 { }
      case 0x20 { success := and(success, mload(0x00)) }
      default { success := 0 }
  }
  ```
- **Reference:** vulnerabilities.md Section 13.2 (Unbounded Return Data), Section 41.7

### [P2-2] ETH Claim Permanently Fails for Non-Receivable Smart Accounts
- **File:** `src/adapters/StargateAdapter.sol:319`
- **SWC:** N/A
- **Category:** DoS
- **Description:** In `claimFailedTransfer`, ETH is sent via `msg.sender.call{value: amount}("")`. If the smart account's implementation is upgraded (via ERC-7579 module change) to lack a `receive()` function, or has a reverting fallback, their `failedTransfers` balance becomes permanently unclaimable. The contract is intentionally admin-less (no rescue function), and there is no alternative claim mechanism (e.g., claiming to a different address, or WETH wrapping fallback).
- **Exploit Scenario:** A smart account user's account is upgraded to an implementation that reverts on ETH receive. Their failed transfer balance becomes permanently locked. Not exploitable by third parties but represents a user fund-loss risk.
- **Vulnerable Code:**
  ```solidity
  if (token == address(0)) {
      (bool success,) = msg.sender.call{ value: amount }("");
      if (!success) revert ETH_TRANSFER_FAILED();
  }
  ```
- **Secure Pattern:** Add optional recipient or WETH fallback:
  ```solidity
  // Option A: Allow claiming to a different address
  function claimFailedTransfer(address token, uint256 amount, address recipient) external nonReentrant { ... }
  // Option B: Wrap as WETH if ETH send fails
  ```
- **Reference:** vulnerabilities.md Section 7.4 (Unexpected Revert DoS)

### [P2-3] Missing NatSpec @param on External handleCompose Function
- **File:** `src/adapters/StargateAdapter.sol:227`
- **SWC:** N/A
- **Category:** Other (Code Quality)
- **Description:** `handleCompose` is `external` (appears in ABI) but lacks `@param` tags for its 5 parameters. While only called via self-call, it is part of the contract's external interface and should be fully documented.
- **Vulnerable Code:**
  ```solidity
  /// @notice Compose handler -- external so lzCompose can wrap it in try/catch to absorb decode panics
  /// @dev MUST only be called by this contract (self-call from lzCompose)
  function handleCompose(bytes32 _guid, bytes calldata _message, address tokenSent, uint256 amountLD, address composeFrom) external
  ```
- **Secure Pattern:**
  ```solidity
  /// @param _guid The LayerZero unique message identifier
  /// @param _message The full OFTComposeMsgCodec-encoded message including header
  /// @param tokenSent The resolved token address from the Stargate pool
  /// @param amountLD The amount in local decimals extracted from the compose header
  /// @param composeFrom The source chain sender address (fallback claimant)
  ```
- **Reference:** Superform coding-rules.md: NatSpec for all public/external functions

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] abi.encodeWithSignature Instead of abi.encodeCall
- **File:** `src/hooks/claim/stargate/ClaimFailedTransferHook.sol:66`
- **Category:** Code Quality
- **Description:** Uses string-based `abi.encodeWithSignature("claimFailedTransfer(address,uint256)", token, amount)` which bypasses compile-time type checking. The rest of the codebase uses `abi.encodeCall`. Create a minimal interface or import StargateAdapter directly.
- **Reference:** vulnerabilities.md Section 15 (Code Quality)

### [P3-2] NatSpec @notice Used for @dev Content
- **File:** `src/hooks/claim/stargate/ClaimFailedTransferHook.sol:22-24`
- **Category:** Code Quality
- **Description:** Data layout documentation uses `@notice` tags for developer-facing byte-offset details. Should use `@dev`.

### [P3-3] Missing NatSpec on _preExecute and _postExecute
- **File:** `src/hooks/claim/stargate/ClaimFailedTransferHook.sol:86-91`
- **Category:** Code Quality
- **Description:** Override functions lack `/// @inheritdoc BaseHook` and `@dev` comments. Other hooks consistently document these.

### [P3-4] Missing @param/@return on _getBalance
- **File:** `src/hooks/claim/stargate/ClaimFailedTransferHook.sol:98-100`
- **Category:** Code Quality
- **Description:** Private function has `@notice` and `@dev` but missing `@param` and `@return` tags.

### [P3-5] No Explicit Data Length Validation in Hook
- **File:** `src/hooks/claim/stargate/ClaimFailedTransferHook.sol:55-57`
- **Category:** Logic
- **Description:** `_buildHookExecutions` doesn't validate `data.length >= 72` before BytesLib calls. BytesLib internally reverts with a generic string error rather than a descriptive custom error.

### [P3-6] composeFrom Collision for Multiple Zero-Account Failures
- **File:** `src/adapters/StargateAdapter.sol:264-268`
- **Category:** Logic
- **Description:** If two composes from the same `composeFrom` both have `account == address(0)`, their credits accumulate under the same key. First claimer gets all. Edge case requiring source chain bug (encoding `account = address(0)`). Documented and accepted.

### [P3-7] Missing @dev on inspect Function
- **File:** `src/hooks/claim/stargate/ClaimFailedTransferHook.sol:75`
- **Category:** Code Quality
- **Description:** `inspect` has `@inheritdoc` but no `@dev` explaining the returned packed `(adapter, token)` semantics.

---

## Attack Surface Summary

### External Entry Points
| Function | Contract | Access Control |
|----------|----------|---------------|
| `lzCompose()` | StargateAdapter | `msg.sender == LZ_ENDPOINT` + `TOKEN_MESSAGING.assetIds(_from) != 0` |
| `handleCompose()` | StargateAdapter | `msg.sender == address(this)` (self-call only) |
| `claimFailedTransfer()` | StargateAdapter | `nonReentrant`, msg.sender claims own balance |
| `receive()` | StargateAdapter | Open (accepts ETH from StargatePoolNative) |
| `buildHookExecutions()` | ClaimFailedTransferHook | Via ERC-7579 module system |

### Value Transfer Points
- `_tryTransfer()` — ETH via `.call{value}` or ERC20 via low-level `.call(transfer)`
- `claimFailedTransfer()` — ETH via `.call{value}` or ERC20 via `safeTransfer`
- `receive()` — accepts incoming ETH

### Cross-Contract Interactions
- `TOKEN_MESSAGING.assetIds(_from)` — Stargate pool validation
- `IStargate(_from).token()` — Token resolution from verified pool
- `SUPER_DESTINATION_EXECUTOR.processBridgedExecution()` — Downstream execution
- `IERC20.transfer()` / `IERC20.safeTransfer()` — Token transfers
- `IERC20.balanceOf()` — preBalance snapshot

### Trust Assumptions
1. **LZ Endpoint** delivers authentic compose messages (DVN security)
2. **TokenMessaging** registry accurately reflects legitimate Stargate pools (Stargate governance)
3. **Stargate pools** return correct `token()` address
4. **SuperDestinationExecutor** independently validates signatures/merkle proofs

---

## Exploit Precedent Cross-Reference

| Pattern | Similar Protocol | Exploit | Loss | Our Status |
|---------|-----------------|---------|------|------------|
| Permissionless compose spoofing | CrossCurve (Jan 2026) | Fabricated bridge messages | $3M | MITIGATED (assetIds check) |
| Compose queue blocking | Tapioca (Code4rena 2023) | lzCompose revert DoS | N/A | MITIGATED (non-reverting design) |
| DVN compromise | KelpDAO (Apr 2026) | Single-DVN RPC spoofing | $292M | EXTERNAL TRUST (Stargate DVN config) |
| Unbacked credits | Decent (Code4rena 2024) | Tokens left in bridge | N/A | MITIGATED (preBalance guard) |
| Compose flow bypass | Brix Money (Code4rena 2025) | Access control bypass via compose | N/A | MITIGATED (executor validates independently) |
| Returnbomb gas griefing | General pattern | EIP-150 catch block OOG | N/A | MITIGATED (bare catch blocks) |

---

## Coding Standards Findings Summary

| Severity | Count | Category |
|----------|-------|----------|
| P2 | 1 | Missing @param on external function |
| P3 | 5 | NatSpec completeness, abi.encodeCall preference |

Both contracts use custom errors exclusively, follow CEI pattern, emit events for all state changes, use locked pragma, and properly organize imports. Overall coding standards compliance is strong.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 7, 8, 9, 10, 13, 14, 15, 16, 33, 41.5, 41.6, 41.7
- **evmresearch.io patterns checked:** vulnerability-patterns (bridge, returnbomb, compose), exploit-analyses (CrossCurve, KelpDAO), security-patterns (non-reverting compose)
- **Coding rules validated:** 11 categories checked from coding-rules.md
- **Historical exploits cross-referenced:** 6 (from Appendix J/K/L/M + Code4rena reports)
- **OWASP Smart Contract Top 10:** All 10 categories assessed
