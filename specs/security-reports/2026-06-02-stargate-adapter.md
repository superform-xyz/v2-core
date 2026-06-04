# Security Analysis Report

## Metadata
- **Target:** `src/adapters/StargateAdapter.sol`
- **Mode:** review
- **Date:** 2026-06-02
- **Contract Types Detected:** Bridge (LayerZero V2 compose receiver, Stargate adapter)
- **Files Analyzed:** 1
- **Agents Used:** Vulnerability Scanner, Solidity Best Practices, EVM Security Researcher

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 1 | Yes |
| P2 Medium | 4 | No |
| P3 Low | 5 | No |

## Verdict
**FAIL** -- 1 blocking finding (P1) must be resolved before merge.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [P1-1] `_tryTransfer` Uses Bare `IERC20.transfer()` — Breaks for Non-Standard Tokens (USDT)

- **File:** `src/adapters/StargateAdapter.sol:236`
- **SWC:** SWC-104
- **Category:** Token
- **Description:** `_tryTransfer` calls bare `IERC20(token).transfer(account, amount)` inside a try/catch expecting `returns (bool result)`. Tokens like USDT on Ethereum do not return a boolean from `transfer()`. When called, the EVM executes the transfer but the ABI decoder reverts trying to decode zero-length return data as `bool`. Solidity's try/catch rolls back the inner call's state changes (including the transfer) and falls into the `catch` block, setting `success = false`. The result: **USDT transfers will systematically fail** even when the adapter has sufficient balance. Every USDT compose will be routed to `failedTransfers`, forcing users to manually claim via `claimFailedTransfer` (which uses `safeTransfer` and works correctly). The user's merkle root is also consumed by `processBridgedExecution` running with no token balance at the account, requiring a new signature.

  The contract imports `SafeERC20` and uses it in `claimFailedTransfer` (line 215), making this an inconsistency within the same contract. USDT is a Stargate-supported token.

- **Exploit Scenario:** A Stargate USDT compose arrives on Ethereum. The adapter holds USDT from `lzReceive`. `_tryTransfer` calls `IERC20(USDT).transfer(account, amount)`. USDT's transfer succeeds at EVM level but returns no data. The try/catch reverts the inner call and sets `success = false`. The amount is stored in `failedTransfers`. `processBridgedExecution` runs but account has no USDT, so execution fails. The user must manually claim and get a new signature.

- **Real-World Precedent:** Non-standard ERC20 return values are one of the most common token integration bugs. OpenZeppelin's SafeERC20 was created specifically to address this (SWC-104). USDT, BNB, and OMG are well-known non-compliant tokens. [Sherlock Audit Finding #579](https://github.com/sherlock-audit/2025-05-lend-audit-contest-judging/issues/579).

- **Vulnerable Code:**
  ```solidity
  // Line 236
  try IERC20(token).transfer(account, amount) returns (bool result) {
      success = result;
  } catch {
      success = false;
  }
  ```

- **Secure Pattern:**
  ```solidity
  // Use low-level call matching SafeERC20's internal approach but non-reverting
  (bool callSuccess, bytes memory returnData) = token.call(
      abi.encodeCall(IERC20.transfer, (account, amount))
  );
  // Verify: call succeeded AND (no return data OR returned true)
  success = callSuccess && (returnData.length == 0 || abi.decode(returnData, (bool)));
  ```

- **Reference:** SWC-104 (Unchecked Call Return Value), OpenZeppelin SafeERC20

---

## P2 Findings (Medium - Should Fix)

### [P2-1] `IStargate(_from).token()` Revert Blocks Compose Pipeline Permanently

- **File:** `src/adapters/StargateAdapter.sol:170`
- **SWC:** N/A
- **Category:** DoS / Cross-Chain
- **Description:** `IStargate(_from).token()` is called without try/catch. If `_from` reverts on `.token()` (paused pool, upgraded interface, unexpected contract), the entire compose reverts, permanently blocking ALL subsequent composes from the same source OApp. This violates the contract's own design principle: "lzCompose MUST NOT revert (except for invalid sender)." The `abi.decode` on line 163 has the same risk — a malformed compose payload causes a revert that blocks the pipeline.

- **Exploit Scenario:** A Stargate pool is temporarily paused or upgraded, causing `.token()` to revert. A compose message arrives. The revert blocks that compose AND all subsequent composes from the same srcEid/sender pair indefinitely.

- **Vulnerable Code:**
  ```solidity
  // Line 170 — reverts if _from.token() reverts
  address tokenSent = IStargate(_from).token();
  ```

- **Secure Pattern:**
  ```solidity
  address tokenSent;
  try IStargate(_from).token() returns (address t) {
      tokenSent = t;
  } catch {
      emit ComposeTokenResolutionFailed(_from, _message);
      return; // graceful exit, pipeline unblocked
  }
  ```

### [P2-2] Missing `_from` Parameter Validation — No Allowlist for Stargate Pools

- **File:** `src/adapters/StargateAdapter.sol:170`
- **SWC:** N/A
- **Category:** Access Control / Cross-Chain
- **Description:** `lzCompose` accepts any address as `_from` and calls `.token()` on it without validating it is a legitimate Stargate pool or OFT. While the LZ EndpointV2 provides trust guarantees (compose queue hash verification), the [LayerZero V2 Security Checklist](https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md) explicitly recommends validating `_from`. [Tapioca Sherlock audit (2024-02, #109)](https://github.com/sherlock-audit/2024-02-tapioca-judging/issues/109) identified a real High-severity issue from this pattern. In an infrastructure compromise (similar to KelpDAO April 2026 — $292M), a crafted compose could provide a malicious `_from` whose `.token()` returns an attacker-controlled token.

- **Vulnerable Code:**
  ```solidity
  address tokenSent = IStargate(_from).token(); // no validation on _from
  ```

- **Secure Pattern:** Add a pool allowlist (requires admin/governance), or at minimum add code existence check. Given the contract is immutable, consider encoding known pools as constructor parameters, or accept the risk as documented with the defense layers (LZ endpoint + merkle root signature).

### [P2-3] Reentrancy in `claimFailedTransfer` — Cross-Function Re-entry Possible

- **File:** `src/adapters/StargateAdapter.sol:203-219`
- **SWC:** SWC-107
- **Category:** Reentrancy
- **Description:** `claimFailedTransfer` correctly follows CEI (state updated on line 209 before external call on line 212), preventing same-token double-claims. However, during the ETH `call` on line 212, the recipient can re-enter `claimFailedTransfer` for a **different** token pair. This is only exploitable if the same account has failed transfers for multiple tokens (claiming one's own legitimate tokens in a re-entrant fashion), so the financial impact is limited. Event ordering would be confused.

- **Vulnerable Code:**
  ```solidity
  failedTransfers[msg.sender][token] = available - amount; // state update
  if (token == address(0)) {
      (bool success,) = msg.sender.call{ value: amount }(""); // re-entry point
  ```

- **Secure Pattern:**
  ```solidity
  import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

  contract StargateAdapter is ILayerZeroComposer, ReentrancyGuard {
      function claimFailedTransfer(address token, uint256 amount) external nonReentrant {
  ```

### [P2-4] `ComposeExecuted` Event Misleading When Execution Subsequently Fails

- **File:** `src/adapters/StargateAdapter.sol:181`
- **SWC:** N/A
- **Category:** Logic
- **Description:** `ComposeExecuted` is emitted when the token transfer succeeds (line 181), but the subsequent `processBridgedExecution` may fail (caught by try/catch, emitting `ExecutionFailed`). The event name implies the entire compose operation succeeded. Downstream consumers reading `ComposeExecuted` + `ExecutionFailed` receive contradictory signals.

- **Secure Pattern:** Rename to `TransferSucceeded` to clarify scope, or move `ComposeExecuted` emission into the try success block so it only fires when both transfer AND execution succeed.

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Unconstrained `receive()` — Donated ETH Permanently Locked

- **File:** `src/adapters/StargateAdapter.sol:121`
- **Category:** ETH Handling
- **Description:** `receive()` accepts ETH from anyone. Since the adapter uses `amountLD` (not `address(this).balance`), donated ETH does not affect composes but is permanently locked with no sweep mechanism. Required for StargatePoolNative compatibility.

### [P3-2] No `account == address(0)` Validation — Unclaimable `failedTransfers`

- **File:** `src/adapters/StargateAdapter.sol:159`
- **Category:** Input Validation
- **Description:** If a malformed compose message contains `account = address(0)`, any failed transfer stored at `failedTransfers[address(0)][token]` is permanently unclaimable since no one can call `claimFailedTransfer` as `msg.sender == address(0)`. Cannot add a revert (would block pipeline), but could skip the transfer entirely.

### [P3-3] `failedTransfers` for Non-Payable Accounts Creates Permanently Locked Funds

- **File:** `src/adapters/StargateAdapter.sol:178`
- **Category:** DoS
- **Description:** If ETH is stored in `failedTransfers` for a non-payable contract, the claim also fails (ETH send reverts). Funds become permanently locked. Superform smart accounts (Nexus/Safe) are payable, so this is unlikely in practice.

### [P3-4] `_guid` Not Included in Events — No Compose-to-Transaction Correlation

- **File:** `src/adapters/StargateAdapter.sol:136`
- **Category:** Cross-Chain / Observability
- **Description:** The `_guid` parameter (globally unique LZ transaction ID) is ignored. Including it in events would enable tracing composes to their source transactions for monitoring and post-mortem analysis.

### [P3-5] ETH Transfer in `_tryTransfer` Forwards All Gas

- **File:** `src/adapters/StargateAdapter.sol:233`
- **Category:** Gas
- **Description:** `account.call{value: amount}("")` forwards all remaining gas. A malicious account with an expensive `receive()` could consume gas, leaving insufficient gas for `processBridgedExecution`. The execution would fail in the try/catch and pipeline remains unblocked. Consistent with other adapters (Across, deBridge).

---

## Attack Surface Summary

- **External Entry Points:** `lzCompose()` (callable only by LZ_ENDPOINT), `claimFailedTransfer()` (callable by anyone for their own balance), `receive()` (unrestricted)
- **Value Transfer Points:** `_tryTransfer` (ETH via `.call{value}`, ERC20 via `.transfer`), `claimFailedTransfer` (ETH via `.call{value}`, ERC20 via `.safeTransfer`)
- **Oracle Dependencies:** None
- **Cross-Contract Interactions:** `IStargate(_from).token()`, `SUPER_DESTINATION_EXECUTOR.processBridgedExecution()`, `IERC20(token).transfer()` / `.safeTransfer()`
- **Upgrade Mechanisms:** None — fully immutable contract

## Coding Standards Findings

| # | Severity | Description |
|---|----------|-------------|
| 1 | P2 | SafeERC20 usage inconsistency: `_tryTransfer` uses bare `transfer`, `claimFailedTransfer` uses `safeTransfer` |
| 2 | P3 | Missing `@notice` on `receive()` (only has `@dev`) |
| 3 | P3 | No event emitted on `receive()` for ETH deposits (gas trade-off) |

All other standards pass: locked pragma, custom errors, CEI pattern in `claimFailedTransfer`, comprehensive NatSpec, proper import organization, section separators.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 8 (Unchecked Return Values), 9 (abi.encodePacked), 10 (Token Integration), 13 (Gas), 15 (Code Quality), 16 (Cross-Chain), 33 (Bridge)
- **External sources checked:** LayerZero V2 Security Checklist, Stargate V2 Composability Docs, OFTComposeMsgCodec source, Tapioca Sherlock audit #109, KelpDAO incident report, OWASP Smart Contract Top 10, OpenZeppelin SafeERC20
- **Historical exploits cross-referenced:** KelpDAO ($292M, April 2026), Tapioca OFT impersonation (2024), SWC-104 non-standard token returns
