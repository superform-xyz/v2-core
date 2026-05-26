# Security Analysis Report

## Metadata
- **Target:** `src/adapters/StargateAdapter.sol`
- **Mode:** review
- **Date:** 2026-05-26
- **Contract Types Detected:** Bridge (LayerZero V2 compose receiver)
- **Files Analyzed:** 1 (+ 2 peer adapters for comparison)
- **Agents Used:** Vulnerability Scanner, Best Practices Reviewer, EVM Security Researcher

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 6 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

The contract is well-written, follows codebase patterns, and has strong documentation. The P2 findings are defense-in-depth recommendations, not exploitable vulnerabilities under normal operations.

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

---

## P2 Findings (Medium)

### [P2-1] Missing `_from` Parameter Validation

- **File:** `src/adapters/StargateAdapter.sol:125`
- **SWC:** N/A (Bridge-specific)
- **Category:** Access Control / Missing Source Validation
- **Description:** `lzCompose` accepts any address as `_from` and calls `IStargate(_from).token()` without validating that `_from` is a legitimate Stargate pool or OFT adapter. The LZ EndpointV2 provides trust by only calling `lzCompose` with the OApp that registered the compose during `lzReceive`, and the `composeQueue` hash verification prevents message tampering. However, the [LayerZero V2 Security Checklist](https://github.com/windhustler/Interoperability-Protocol-Security-Checklist/blob/main/audit-checklists/LayerZeroV2.md) explicitly recommends validating `_from`. The [Tapioca Sherlock audit (2024-02, #109)](https://github.com/sherlock-audit/2024-02-tapioca-judging/issues/109) found a real High-severity issue from missing `_from` validation.
- **Exploit Scenario:** In an infrastructure compromise (e.g., KelpDAO-style DVN attack), a fake compose could provide a malicious `_from` that returns an arbitrary `token()` address, causing the adapter to sweep unrelated tokens held from prior failed composes.
- **Real-World Precedent:** KelpDAO $292M exploit (April 2026) — DVN infrastructure compromise led to forged cross-chain messages. LayerZero's post-mortem confirmed single-verifier configurations were vulnerable.
- **Vulnerable Code:**
  ```solidity
  address tokenSent = IStargate(_from).token();
  ```
- **Secure Pattern:**
  ```solidity
  mapping(address => bool) public allowedPools;
  error POOL_NOT_ALLOWED();

  // In lzCompose:
  if (!allowedPools[_from]) revert POOL_NOT_ALLOWED();
  address tokenSent = IStargate(_from).token();
  ```
  Note: Adding an allowlist requires governance/admin functions and changes the contract from being immutable/stateless. An alternative is documenting the trust assumption explicitly.

### [P2-2] Balance-Based Accounting — Cross-User Dust Leakage

- **File:** `src/adapters/StargateAdapter.sol:130-138`
- **SWC:** N/A (Bridge-specific)
- **Category:** Balance-Based Accounting
- **Description:** The adapter transfers its full `balanceOf` (ERC20) or `address(this).balance` (ETH) to the target account, rather than the `amountLD` from the OFTComposeMsgCodec header. If a prior compose failed (revert in `processBridgedExecution`), those tokens remain in the adapter. The next successful compose sweeps all accumulated tokens — including the prior user's — to a different account.
- **Exploit Scenario:** User A's compose delivers 1000 USDC, but `processBridgedExecution` reverts (expired signature). User B's compose delivers 500 USDC. Adapter has 1500 USDC, all swept to User B's account.
- **Vulnerable Code:**
  ```solidity
  uint256 balance = IERC20(tokenSent).balanceOf(address(this));
  IERC20(tokenSent).safeTransfer(account, balance);
  ```
- **Secure Pattern:**
  ```solidity
  // Extract amountLD from OFTComposeMsgCodec header (bytes 12-44)
  uint256 amountLD = abi.decode(_message[12:44], (uint256));
  IERC20(tokenSent).safeTransfer(account, amountLD);
  ```
- **Design Note:** The team has deliberately chosen balance-based transfers (documented in `@dev WARNING` on lines 22-23) because `amountLD` can differ from actual credit due to Stargate's shared-decimals dust removal. This is an accepted tradeoff. The risk is limited since `processBridgedExecution` validates `intentAmounts` independently.

### [P2-3] Missing Event Emission for Compose Execution — **FIXED**

- **File:** `src/adapters/StargateAdapter.sol:70,145,150`
- **SWC:** N/A
- **Category:** Code Quality / Observability
- **Description:** The `lzCompose` function transfers tokens and triggers downstream execution but emits no event. Off-chain indexing and monitoring of Stargate compose callbacks is impossible from the adapter's perspective. The `AcrossV3Adapter`'s interface pattern (`AcrossFundsReceivedAndExecuted`) establishes a precedent for this.
- **Resolution:** Added `ComposeExecuted(address indexed account, address indexed tokenSent, uint256 amount)` event. Emitted in both ETH and ERC20 paths. Also cached ETH balance before transfer (P3-5). Unit tests updated with `vm.expectEmit` assertions.

---

## P3 Findings (Low)

### [P3-1] No `account == address(0)` Validation
- **File:** `src/adapters/StargateAdapter.sol:114`
- **Category:** Input Validation
- **Description:** The decoded `account` is not checked for zero address. For native ETH, this would burn ETH permanently. For ERC20, OpenZeppelin's `safeTransfer` would revert. Consistent with `AcrossV3Adapter` and `DebridgeAdapter` (neither checks this).
- **Fix:** `if (account == address(0)) revert ADDRESS_NOT_VALID();`

### [P3-2] Missing Reentrancy Guard (Defense-in-Depth)
- **File:** `src/adapters/StargateAdapter.sol:93-150`
- **SWC:** SWC-107
- **Category:** Missing Reentrancy Guards
- **Description:** No `nonReentrant` modifier on `lzCompose`. Mitigated by: (1) `msg.sender != LZ_ENDPOINT` blocks re-entry, (2) no mutable state to corrupt, (3) `SuperDestinationExecutor` has its own `nonReentrant`. Consistent with both peer adapters.

### [P3-3] `processBridgedExecution` Revert Blocks Compose
- **File:** `src/adapters/StargateAdapter.sol:141-149`
- **Category:** DoS / Compose Retry
- **Description:** If `processBridgedExecution` reverts, the entire compose reverts and enters the LZ endpoint retry queue. Tokens from `lzReceive` remain in the adapter. Combined with P2-2, stuck tokens could be swept by the next compose. A `try/catch` wrapping the executor call would prevent compose-level revert, but would also remove the ability to retry.

### [P3-4] Unconstrained `receive()` Function
- **File:** `src/adapters/StargateAdapter.sol:82`
- **Category:** ETH Handling
- **Description:** Anyone can send ETH to the adapter. Combined with balance-based transfer, donated ETH gets swept to the next compose's account. Required for `StargatePoolNative` compatibility. Already documented with `@dev WARNING`.

### [P3-5] Cache ETH Balance Before Transfer
- **File:** `src/adapters/StargateAdapter.sol:132`
- **Category:** Gas Optimization
- **Description:** `address(this).balance` is used inline in the `call`. If an event is added (P2-3), the balance should be cached. For symmetry with the ERC20 path:
  ```solidity
  uint256 ethBalance = address(this).balance;
  (bool success,) = account.call{ value: ethBalance }("");
  ```

### [P3-6] `_from.token()` Reverts for Non-Stargate OApps
- **File:** `src/adapters/StargateAdapter.sol:125`
- **Category:** External Call Safety
- **Description:** If `_from` doesn't implement `token()`, the call reverts and the compose enters retry queue. Tokens remain stuck. Addressed by P2-1 (allowlist would prevent this).

---

## Attack Surface Summary

- **External Entry Points:** `lzCompose()` (only callable by LZ EndpointV2), `receive()` (unrestricted)
- **Value Transfer Points:** ETH via `account.call{value}`, ERC20 via `safeTransfer`, both use full adapter balance
- **Oracle Dependencies:** None
- **Cross-Contract Interactions:** `IStargate(_from).token()` (view call to Stargate pool), `processBridgedExecution()` (to SuperDestinationExecutor)
- **Upgrade Mechanisms:** None (immutable contract, no proxy)

## Peer Adapter Comparison

| Feature | AcrossV3Adapter | DebridgeAdapter | StargateAdapter |
|---------|----------------|-----------------|-----------------|
| Transfer amount | Parameter (`amount`) | Parameter (`_transferredAmount`) | `balanceOf(address(this))` |
| Token source | Parameter (`tokenSent`) | Parameter (`_token`) | `_from.token()` call |
| Source validation | `msg.sender == SPOKE_POOL` | `msg.sender == externalCallAdapter` | `msg.sender == LZ_ENDPOINT` only |
| `_from` allowlist | N/A | N/A | **None** |
| Reentrancy guard | No | No | No |
| Events | Via interface | Via return values | **None** |
| `account == 0` check | No | No | No |

## Infrastructure Trust Note

The EVM Security Researcher flagged the **KelpDAO DVN compromise pattern** ($292M, April 2026) as relevant. In that incident, a compromised single-verifier DVN allowed forged cross-chain messages. The StargateAdapter transfers tokens BEFORE `processBridgedExecution` validates the signature, meaning a DVN compromise could drain tokens even though execution would fail. This is not a code vulnerability but an infrastructure trust assumption. Verify Stargate uses multi-DVN verification (2-of-2 minimum per LZ's post-KelpDAO requirements).

## Security Knowledge Sources
- LayerZero V2 Security Checklist (windhustler/Interoperability-Protocol-Security-Checklist)
- LayerZero V2 EndpointV2 MessagingComposer.sol source code
- Tapioca Sherlock audit (2024-02, Issue #109)
- KelpDAO $292M incident reports (LayerZero, CoinDesk, The Defiant)
- Nomad Bridge $190M exploit analysis (Immunefi)
- Stargate V2 composability documentation
- OFTComposeMsgCodec source code (LayerZero-v2)
- OWASP SCWE-154: Calldata Decode Without Length Check
- Cyfrin Solodit donation attack checklist
