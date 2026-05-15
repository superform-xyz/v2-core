# Security Analysis Report

## Metadata
- **Target:** `src/hooks/claim/flare/` (ClaimRFLRHook.sol, WithdrawRFLRHook.sol)
- **Mode:** review
- **Date:** 2026-05-15
- **Contract Types Detected:** Claim/reward hooks (NONACCOUNTING)
- **Files Analyzed:** 4 (2 hooks + BaseHook + IRNat interface)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 6 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

## Critical Pattern Checklist

| # | Pattern | Result |
|---|---------|--------|
| 1 | Reentrancy | PASS - BaseHook transient mutex guards + `msg.sender == account` |
| 2 | Access Control | PASS - `preExecute`/`postExecute` restricted to account |
| 3 | Division Before Multiplication | PASS - No division operations |
| 4 | Unchecked Return Values | PASS - Balance delta pattern validates outcomes |
| 5 | Missing Reentrancy Guards | PASS - Transient storage mutexes serve as guards |
| 6 | abi.encodePacked Collisions | PASS - Only fixed-size types used |
| 7 | tx.origin Authentication | PASS - Not used |
| 8 | Floating Pragma | PASS - Locked to `0.8.30` |

---

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

### [1] ClaimRFLRHook.inspect() returns empty bytes -- inconsistent with sibling hook

- **File:** `src/hooks/claim/flare/ClaimRFLRHook.sol:87-89`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Logic
- **Description:** `ClaimRFLRHook.inspect()` returns `""` while `WithdrawRFLRHook.inspect()` returns `abi.encodePacked(RNAT)`. All other claim hooks in the codebase (Fluid, Gearbox, Merkl, Yearn) return encoded addresses. The function is also marked `pure` when the interface declares `view`. Off-chain systems relying on `inspect()` to verify hook targets will receive no useful information.
- **Vulnerable Code:**
  ```solidity
  function inspect(bytes calldata) external pure override returns (bytes memory) {
      return "";
  }
  ```
- **Secure Pattern:**
  ```solidity
  function inspect(bytes calldata) external view override returns (bytes memory) {
      return abi.encodePacked(RNAT);
  }
  ```

### [2] WithdrawRFLRHook always calls withdrawAll with no slippage protection

- **File:** `src/hooks/claim/flare/WithdrawRFLRHook.sol:48-64`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Logic
- **Description:** `withdrawAll(true)` applies a 50% penalty on locked (unvested) rFLR. The hook has no minimum output parameter and no way to withdraw only vested amounts. A user with significant unvested rFLR will silently lose 50% of the unvested portion. While the NatSpec documents this, there is no on-chain safeguard.
- **Exploit Scenario:** A user or off-chain system calls WithdrawRFLRHook without checking `IRNat.getBalancesOf()` first. 80% of their rFLR is locked. They lose 40% of their total rFLR to the penalty.
- **Vulnerable Code:**
  ```solidity
  executions[0] = Execution({
      target: RNAT,
      value: 0,
      callData: abi.encodeCall(IRNat.withdrawAll, (true))
  });
  ```
- **Secure Pattern:** Add optional `minOutAmount` parameter:
  ```solidity
  function _postExecute(address, address account, bytes calldata data) internal override {
      uint256 received = IERC20(WFLR).balanceOf(account) - getOutAmount(account);
      if (data.length >= 32) {
          uint256 minOut = BytesLib.toUint256(data, 0);
          if (received < minOut) revert SLIPPAGE_EXCEEDED();
      }
      _setOutAmount(received, account);
  }
  ```

### [3] Missing NatSpec on _preExecute / _postExecute in both hooks

- **File:** `src/hooks/claim/flare/ClaimRFLRHook.sol:95-102`, `WithdrawRFLRHook.sol:75-82`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Other
- **Description:** Both `_preExecute` and `_postExecute` overrides lack `@inheritdoc BaseHook` or `@dev` documentation. Other recently-merged hooks (e.g., `ClaimAssetsDETHHook`) include `/// @dev outAmount is the WETH delta` comments. The `_decodeProjectIds` helper is also undocumented.
- **Secure Pattern:**
  ```solidity
  /// @inheritdoc BaseHook
  /// @dev Snapshots the rFLR balance before claim execution
  function _preExecute(address, address account, bytes calldata) internal override { ... }

  /// @inheritdoc BaseHook
  /// @dev outAmount is the rFLR delta (post-balance minus pre-balance)
  function _postExecute(address, address account, bytes calldata) internal override { ... }
  ```

---

## P3 Findings (Low - Consider Fixing)

### [4] Unbounded loop in _decodeProjectIds

- **File:** `src/hooks/claim/flare/ClaimRFLRHook.sol:104-110`
- **SWC:** SWC-128
- **Severity:** P3 Low
- **Category:** DoS
- **Description:** `_decodeProjectIds` reads a `length` value from user-supplied calldata with no upper bound. An extremely large length could cause out-of-gas. Self-griefing only (user pays gas), and `BytesLib.toUint256` will revert on out-of-bounds data access, but a max length check is defense-in-depth.

### [5] Missing minimum data length validation

- **File:** `src/hooks/claim/flare/ClaimRFLRHook.sol:60-84`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Logic
- **Description:** No check that `data.length >= 64` before decoding. Malformed data reverts with opaque `BytesLib.toUint256_outOfBounds` instead of a clear custom error. Consistent with other hooks (MerklClaimRewardHook also doesn't bounds-check upfront).

### [6] IRNat import categorized under "Superform" instead of "External"

- **File:** `src/hooks/claim/flare/ClaimRFLRHook.sol:13`, `WithdrawRFLRHook.sol:12`
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Other
- **Description:** `IRNat` is a vendor/external interface but placed under the `// Superform` import section. Other vendor imports (FluidLendingStakingRewards, Gearbox) are under `// External`. Should be moved for consistency.

### [7] Potential underflow in _postExecute if balance decreases

- **File:** `src/hooks/claim/flare/ClaimRFLRHook.sol:101`, `WithdrawRFLRHook.sol:81`
- **SWC:** SWC-101
- **Severity:** P3 Low
- **Category:** Arithmetic
- **Description:** `balanceOf(account) - getOutAmount(account)` reverts if post-balance < pre-balance. This is actually safe behavior (revert > incorrect accounting). Same pattern used across all claim hooks in the codebase.

### [8] Flare EVM compatibility for transient storage (EIP-1153)

- **File:** `src/hooks/BaseHook.sol` (all transient storage usage)
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Other
- **Description:** BaseHook uses `tstore`/`tload` (EIP-1153 Cancun). These hooks deploy to Flare Network. Verify Flare supports Cancun opcodes before deployment. If not supported, all hooks will fail.

### [9] Shared transient `asset` variable not keyed by execution context

- **File:** `src/hooks/BaseHook.sol:35`, used by both hooks
- **SWC:** N/A
- **Severity:** P3 Low
- **Category:** Logic
- **Description:** `asset` is `address public transient asset` -- a single slot, not keyed per account/context (unlike `outAmount`). If two accounts use the same hook in one transaction, the second write overwrites the first. Moot for these hooks since `asset` is always set to a fixed immutable (`RNAT` / `WFLR`), but worth noting for the broader BaseHook pattern.

---

## Attack Surface Summary

- **External Entry Points:** `build()` (view), `preExecute()`, `postExecute()` -- all via BaseHook
- **Value Transfer Points:** `claimRewards` (mints rFLR to account), `withdrawAll` (sends WFLR to account)
- **Oracle Dependencies:** None
- **Cross-Contract Interactions:** RNat contract (immutable address, Flare Foundation controlled)
- **Upgrade Mechanisms:** None -- hooks are non-upgradeable

## External Security Research

### Exploit Precedents Checked
| Similar Protocol | Exploit | Loss | Applicable? |
|---|---|---|---|
| Penpie (Sept 2024) | Reentrancy via reward claim with balance delta | $27M | No -- immutable targets, mutex guards |
| DeltaPrime (Sept 2024) | Unchecked claimReward | $4.8M | No -- balance delta validates |
| ERC-4626 inflation | Donation attack on balance snapshots | Various | No -- rFLR non-transferable; WFLR hook is NONACCOUNTING |

### Transient Storage Research
- ChainSecurity TSTORE low-gas reentrancy: Mitigated by BaseHook mutexes and `msg.sender == account` restriction
- No known TSTORE-specific exploits in production

## Coding Standards Findings
- 3 P3 import organization issues (IRNat categorization, redundant ISuperHookInspector import)
- Missing NatSpec on internal overrides
- Overall code quality is good -- follows established codebase patterns

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1 (Reentrancy), 2 (Access Control), 3 (Arithmetic), 8 (Unchecked Returns), 9 (encodePacked), 13 (Gas), 15 (Code Quality), 36 (Pre-PR Checklist)
- **External patterns checked:** OWASP SC Top 10 (2025), ChainSecurity TSTORE, Penpie, DeltaPrime, ERC-4626 inflation
- **Coding rules validated:** NatSpec, imports, naming, custom errors, section dividers
- **Historical exploits cross-referenced:** 3 (Penpie, DeltaPrime, ERC-4626 inflation)
