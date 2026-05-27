# Security Analysis Report

## Metadata
- **Target:** `src/hooks/bridges/stargate/StargateSendHook.sol`, `src/hooks/bridges/stargate/ApproveAndStargateSendHook.sol`
- **Mode:** review
- **Date:** 2026-05-26
- **Contract Types Detected:** Bridge, Token
- **Files Analyzed:** 2 (+ BaseHook.sol, IOFT.sol, IStargate.sol as context)
- **Agents:** Vulnerability Scanner, Best Practices, EVM Security Researcher

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 1 | Yes |
| P2 Medium | 6 | No |
| P3 Low | 7 | No |

## Verdict
**FAIL** - 1 blocking finding (P1) should be evaluated before merge.

**Note:** Several P1/P2 findings are partially mitigated by Superform's Merkle proof signature system (hook data is signed by the user). The P1 finding is the most actionable regardless of architectural mitigations.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [1] composeMsg decoded `_account` not validated against executing `account`

- **File:** `StargateSendHook.sol:153-161`, `ApproveAndStargateSendHook.sol:158-166`
- **SWC:** N/A
- **Category:** Input Validation / Cross-Chain
- **Description:** When `composeMsg` is present, it is decoded into `(bytes initData, bytes executorCalldata, address _account, address[] dstTokens, uint256[] intentAmounts)`. The `_account` embedded in the compose message is never validated against the actual `account` parameter passed to `_buildHookExecutions`. The signature retrieved from the validator (`retrieveSignatureData(account)`) is for the executing account, but the compose message can instruct the destination executor to operate on behalf of a different address.
- **Exploit Scenario:** A malicious bundler constructs hook data where `composeMsg` contains `_account = victimAddress` but uses their own account to execute. If the destination executor does not independently validate that `_account` matches the bridge sender, it could execute operations on behalf of the wrong account. The Tapioca/Sherlock finding ([#109](https://github.com/sherlock-audit/2024-02-tapioca-judging/issues/109)) demonstrated a similar pattern where `lzCompose` messages impersonated the OFT contract.
- **Vulnerable Code:**
  ```solidity
  bytes memory signature = ISuperSignatureStorage(VALIDATOR).retrieveSignatureData(account);
  (
      bytes memory initData,
      bytes memory executorCalldata,
      address _account,    // NOT validated against `account`
      address[] memory dstTokens,
      uint256[] memory intentAmounts
  ) = abi.decode(s.composeMsg, (bytes, bytes, address, address[], uint256[]));
  s.composeMsg = abi.encode(initData, executorCalldata, _account, dstTokens, intentAmounts, signature);
  ```
- **Secure Pattern:**
  ```solidity
  // After decoding, validate account match:
  if (_account != account) revert ADDRESS_NOT_VALID();
  ```
- **Reference:** Cross-chain message integrity, OWASP SC02 Logic Errors

---

## P2 Findings (Medium - Should Fix)

### [2] Weak pool validation -- any contract implementing `token()` passes

- **File:** `StargateSendHook.sol:121`, `ApproveAndStargateSendHook.sol:126`
- **SWC:** SWC-125
- **Category:** Access Control / Bridge
- **Description:** `StargateSendHook` validates the pool by calling `IStargate(s.stargatePool).token()` and only checking it doesn't revert. Any contract implementing `token()` passes. `ApproveAndStargateSendHook` is slightly stronger (checks return matches `inputToken`), but a malicious contract can return any desired address. **Mitigated by Merkle proof signature** -- the user signs over `stargatePool`, so exploitation requires social engineering or a compromised bundler.
- **Exploit Scenario:** Attacker deploys a contract implementing `token()` returning the user's ERC20 address. If the user signs an intent with `stargatePool = maliciousPool`, the hook approves it to spend tokens and calls `sendToken` on it, which drains tokens.
- **Secure Pattern:** Validate against a registry of known Stargate pools/OFTs, or hardcode approved addresses like `AcrossSendFundsAndExecuteOnDstHook` does with `SPOKE_POOL_V3`.

### [3] `to` (bytes32 recipient) not validated against executing account

- **File:** `StargateSendHook.sol:109,117`, `ApproveAndStargateSendHook.sol:113,122`
- **SWC:** N/A
- **Category:** Access Control / Cross-Chain
- **Description:** The `to` field is only checked against `bytes32(0)` but never validated against the `account`. Funds can be bridged to any arbitrary destination address. **Mitigated by Merkle proof signature** -- user signs over `to`. A malicious dApp could present misleading UI while the underlying `to` field points to the attacker's address.
- **Secure Pattern:** If the protocol always bridges to the same account: `if (s.to != bytes32(uint256(uint160(account)))) revert RECIPIENT_MISMATCH();`. If flexible recipients are intended, document the design choice.

### [4] No minimum slippage floor for `minAmountLD`

- **File:** `StargateSendHook.sol:111`, `ApproveAndStargateSendHook.sol:115`
- **SWC:** N/A
- **Category:** MEV / Front-running
- **Description:** `minAmountLD` is entirely caller-specified with no minimum floor. A user/bundler can set `minAmountLD = 0`. When `usePrevHookAmount = true` and the previous hook returns a small amount, `Math.mulDiv` rounding could reduce `minAmountLD` to 0, silently removing slippage protection.
- **Secure Pattern:** Add a minimum ratio check: `if (s.minAmountLD == 0 && s.amountLD > 0) revert AMOUNT_NOT_VALID();`

### [5] `lzNativeFee` has no upper bound validation

- **File:** `StargateSendHook.sol:104,197,213`, `ApproveAndStargateSendHook.sol:107`
- **SWC:** N/A
- **Category:** Input Validation
- **Description:** `lzNativeFee` is entirely user-specified and passed directly as `value`. An inflated fee drains more native ETH than necessary. While Stargate refunds excess to `refundAddress` (the account), accounts with non-payable fallbacks will revert (liveness DoS, documented in NatSpec warning).
- **Secure Pattern:** Quote the actual fee via `quoteSend()` and validate within a tolerance, or enforce at the off-chain bundler level.

### [6] StargateSendHook mode mismatch can cause permanent ETH loss

- **File:** `StargateSendHook.sol:165-267`
- **SWC:** N/A
- **Category:** Bridge / Logic Error
- **Description:** If `mode = 0` (Stargate) is used with an OFT contract address, `lzNativeFee + amountLD` in ETH is sent to a contract that doesn't expect native ETH for token bridging. The extra `amountLD` ETH may be trapped permanently. The contract acknowledges this risk in comments (lines 219-220) but provides no programmatic protection. Both IStargate and IOFT share the `token()` selector, making on-chain distinction impossible without additional checks.
- **Secure Pattern:** For Stargate mode, verify `IStargate(s.stargatePool).token() == address(0)` (native pool check). For OFT mode, validate via a known OFT registry or Stargate factory check.

### [7] Refund address liveness DoS on non-payable smart accounts

- **File:** Both hooks -- all `sendToken`/`send` calls use `account` as refund address
- **SWC:** N/A
- **Category:** DoS
- **Description:** When Stargate/OFT overestimates fees, excess ETH is synchronously refunded to the smart account. If the account's fallback reverts (non-payable, reentrancy, gas limits), the entire bridge call reverts. This is a **known issue** documented in both hooks' NatSpec. ERC-7702 delegated EOAs and non-standard ERC-7579 accounts may have surprising fallback behavior.
- **Secure Pattern:** Already documented as accepted trade-off. Off-chain bundler should simulate execution before submission. Consider allowing an optional separate refund address.

---

## P3 Findings (Low - Consider Fixing)

### [8] `dstEid` not validated against supported chains

- **File:** `StargateSendHook.sol:108`, `ApproveAndStargateSendHook.sol:112`
- **Category:** Cross-Chain
- **Description:** No on-chain validation that `dstEid` corresponds to a chain where Superform is deployed. Tokens could be bridged to a chain with no destination executor, leaving them stranded. Mitigated by user signature over `dstEid`.

### [9] `setExecutionContext` in BaseHook has no access control

- **File:** `BaseHook.sol:115-118`
- **Category:** Access Control
- **Description:** `setExecutionContext(address caller)` is external with no modifier. However, atomic execution via ERC-7579 prevents external interleaving between `setExecutionContext` and the hook operations. Not exploitable in practice.

### [10] `inspect()` uses `abi.encodePacked` with three addresses

- **File:** `StargateSendHook.sol:280-286`, `ApproveAndStargateSendHook.sol:183-189`
- **SWC:** SWC-133
- **Category:** Encoding
- **Description:** Three fixed-size `address` types -- no actual collision risk. Future modifications adding variable-length types could introduce issues. Minor concern.

### [11] StargateSendHook `inspect()` reads `inputToken` not present in struct

- **File:** `StargateSendHook.sol:283`
- **Category:** Code Quality
- **Description:** The `StargateSendData` struct omits `inputToken` but `inspect()` reads offset 84 as "inputToken". Creates maintenance hazard if data layout changes.

### [12] `_decodeBool` forces calldata-to-memory copy (gas inefficiency)

- **File:** `BaseHook.sol:260-262`
- **Category:** Gas Optimization
- **Description:** `_decodeBool(bytes memory data, ...)` receives calldata implicitly copied to memory for a single-byte read. Adding a calldata variant would save gas for large hook data.

### [13] OFT mode token handling ambiguity (StargateSendHook)

- **File:** `StargateSendHook.sol:217-267`
- **Category:** Logic / Documentation
- **Description:** `StargateSendHook` OFT mode (mode=2) does not approve the OFT contract for ERC20 tokens. This only works with pure OFT contracts (burn-based) or native OFTs, NOT OFTAdapter contracts. `ApproveAndStargateSendHook` handles the ERC20/OFTAdapter case correctly. This is a design constraint, not a vulnerability (wrong hook reverts, no fund loss).

### [14] `StargateSendHook` discards `token()` return value

- **File:** `StargateSendHook.sol:121`
- **Category:** Code Quality
- **Description:** `IStargate(s.stargatePool).token()` is called but the return value is discarded. Unlike `ApproveAndStargateSendHook` which validates `token() == inputToken`, `StargateSendHook` only checks the call succeeds. For native pools, consider validating `token() == address(0)`.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (via BaseHook, calls `_buildHookExecutions`), `preExecute()`, `postExecute()`, `setExecutionContext()`, `inspect()`, `decodeUsePrevHookAmount()`
- **Value Transfer Points:** `Execution.value` field -- `lzNativeFee + amountLD` (Stargate native) or `lzNativeFee` (OFT/ERC20 modes). ERC20 approvals in ApproveAndStargateSendHook.
- **External Protocol Calls:** `IStargate.sendToken()`, `IOFT.send()`, `IStargate.token()`, `ISuperSignatureStorage.retrieveSignatureData()`, `ISuperHookResult.getOutAmount()`
- **Cross-Contract Interactions:** Stargate V2 pools, LayerZero V2 OFT/OFTAdapter contracts, LayerZero Endpoint (via pool), LZ Token (ZRO) for fee payment
- **Trust Assumptions:** User signs Merkle leaf containing all hook data; bundler constructs but cannot modify signed data; Stargate/LZ DVN infrastructure delivers messages faithfully (2-of-2 DVN for Stargate)

## Coding Standards Findings

From the Best Practices agent (previous session):
- **P2 Medium (2):** StargateSendHook lacks function decomposition for `_buildHookExecutions` (267-line function); `token()` return value discarded
- **P3 Low (8):** NatSpec gaps on struct fields and constructor, missing events for mode selection, inconsistent error naming patterns, `_decodeBool` gas optimization, `inspect()` documentation gaps

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 6 (MEV), 9 (Encoding), 10 (Token), 11 (Proxy), 15 (Code Quality), 16 (Cross-Chain), 33 (Bridge)
- **External sources:** LayerZero V2 docs, Stargate V2 docs, Tapioca/Sherlock lzCompose finding, ChainSecurity TSTORE audit, KelpDAO $292M exploit, OWASP SC Top 10 (2025), Zellic LayerZero audit, OpenZeppelin Across OFT audit
- **Historical exploits cross-referenced:** Tapioca lzCompose impersonation, KelpDAO DVN compromise, Rekt Leaderboard bridge exploits
