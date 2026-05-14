# Security Analysis Report

## Metadata
- **Target:** `src/accounting/oracles/DETHYieldSourceOracle.sol` (301 lines)
- **Dependencies Analyzed:** `AbstractYieldSourceOracle.sol`, `IDETHAsyncRedeemer.sol`, `IMachine.sol`
- **Mode:** review
- **Date:** 2026-05-13
- **Contract Types Detected:** View-only Oracle, Vault (async redemption)
- **Files Analyzed:** 4
- **Focus:** FOUNDATION immutable and its impact on `getTVLByOwnerOfShares`

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 5 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed with awareness of P2 items.

---

## P0 Findings (Critical - Must Fix)

None found.

## P1 Findings (High - Must Fix)

None found.

---

## P2 Findings (Medium - Should Fix)

### [F-01] FOUNDATION TVL Attribution to All Queried Owners (Cross-Query Inflation)

- **File:** `DETHYieldSourceOracle.sol:197-204`
- **SWC:** N/A
- **Category:** Logic
- **Description:** The FOUNDATION's pending redemption NFTs are added to **every** `ownerOfShares` query (except FOUNDATION itself). If `getTVLByOwnerOfSharesMultiple` is called with multiple owners for the same yield source, each owner gets FOUNDATION's pending value attributed. This breaks the invariant `sum(TVL_per_owner) <= getTVL()`. While documented in NatSpec as a single-strategy assumption, there is no on-chain enforcement.
- **Exploit Scenario:** Two strategy addresses A and B are registered with the same oracle and yield source. When the system queries TVL for both, each gets FOUNDATION's 100 ETH pending value added. Total reported TVL inflated by 100 ETH.
- **Vulnerable Code:**
  ```solidity
  // Component 3: FOUNDATION pending value added to ALL queries
  address foundation = FOUNDATION;
  if (foundation != address(0) && foundation != ownerOfShares) {
      pendingValue += _getPendingRedemptionValue(yieldSourceAddress, machineAddr, foundation);
  }
  ```
- **Secure Pattern:** Bind FOUNDATION attribution to a single designated strategy:
  ```solidity
  address public immutable DESIGNATED_STRATEGY;

  // Only add FOUNDATION value for the designated strategy
  if (foundation != address(0) && ownerOfShares == DESIGNATED_STRATEGY) {
      pendingValue += _getPendingRedemptionValue(yieldSourceAddress, machineAddr, foundation);
  }
  ```
- **Reference:** TVL attribution correctness; ERC-7540 accounting best practices

---

### [F-02] Silent TVL Truncation at MAX_PENDING_REQUESTS Boundary

- **File:** `DETHYieldSourceOracle.sol:270-271`
- **SWC:** N/A (related: SWC-128)
- **Category:** Oracle
- **Description:** When pending requests exceed 200, the oracle silently scans only the first 200 (oldest), dropping newer requests. No flag, event, or revert signals truncation. Scanning oldest-first means the most recent legitimate requests (likely the largest/most relevant) are dropped. Downstream consumers (SuperLedger, solvency monitors) receive under-reported TVL with no indication of incompleteness.
- **Exploit Scenario:** A whitelisted attacker creates 200+ small redemption requests. The strategy's large legitimate requests fall outside the scan window, causing TVL to drop. Alternatively, high organic activity could naturally exceed the cap.
- **Vulnerable Code:**
  ```solidity
  uint256 scanLimit = pendingCount > MAX_PENDING_REQUESTS ? MAX_PENDING_REQUESTS : pendingCount;
  ```
- **Secure Pattern:** Option A - reverse scan (newest first) to prioritize recent requests. Option B - return a truncation flag:
  ```solidity
  // Option A: Scan newest-to-oldest
  for (uint256 i; i < scanLimit; ++i) {
      uint256 requestId = nextId - 1 - i;  // newest first
      // ...
  }
  ```
- **Reference:** SWC-128 (DoS with Block Gas Limit); Oracle completeness guarantees

---

### [F-03] Machine.convertToAssets() Donation Attack Vector (Needs Verification)

- **File:** `DETHYieldSourceOracle.sol:102,123,144,153,194,294`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** Every pricing function routes through `Machine.convertToAssets()` or `convertToShares()`. The NatSpec assumes Machine uses internal accounting (not balance-based). If Machine's implementation uses `totalAssets / totalSupply` based on actual token balances rather than internal tracking, a flash-loan donation attack could inflate the oracle's price-per-share. The Makina Finance exploit ($4.13M, Jan 2026) affected the same Dialectic/Machine vault family. Machine is a BeaconProxy, meaning its implementation can be upgraded -- a future upgrade could change the pricing model.
- **Exploit Scenario:** Attacker flash-loans WETH, donates to Machine (bypassing deposit), reads inflated `convertToAssets()` via the oracle, then uses the inflated TVL to extract value from the Superform protocol (e.g., reduced performance fees, incorrect PPS).
- **Vulnerable Code:**
  ```solidity
  return IMachine(machineAddr).convertToAssets(sharesIn);
  ```
- **Secure Pattern:** Verify Machine's implementation on-chain. If balance-based, add PPS sanity bounds:
  ```solidity
  uint256 pps = IMachine(machineAddr).convertToAssets(oneShare);
  // Sanity check: PPS should not deviate >X% from last known value
  require(pps <= lastKnownPPS * 110 / 100, "PPS_TOO_HIGH");
  ```
- **Reference:** Euler Finance ERC-4626 exchange rate manipulation; MixBytes inflation attack overview

**ACTION REQUIRED:** Verify Machine's `convertToAssets()` implementation uses internal tracking, not `IERC20(asset).balanceOf(address(this))`.

---

### [F-04] Double Loop Scan Gas Cost with FOUNDATION

- **File:** `DETHYieldSourceOracle.sol:197-204`
- **SWC:** SWC-128
- **Category:** Gas / DoS
- **Description:** When `FOUNDATION != address(0)`, `_getPendingRedemptionValue` is called twice -- once for `ownerOfShares` and once for `FOUNDATION`. Each call fetches `lastFinalizedRequestId()` and `nextRequestId()` again (redundant), and runs up to 200 iterations with `ownerOf()` + `getShares()` calls. Worst case: 800 external calls for a single TVL query. Batch functions (`getTVLByOwnerOfSharesMultiple`) multiply this further: 5 yield sources x 3 owners = 12,000 external call pairs.
- **Vulnerable Code:**
  ```solidity
  uint256 pendingValue = _getPendingRedemptionValue(yieldSourceAddress, machineAddr, ownerOfShares);
  // ... second call for FOUNDATION
  pendingValue += _getPendingRedemptionValue(yieldSourceAddress, machineAddr, foundation);
  ```
- **Secure Pattern:** Merge into a single-pass loop that checks both addresses:
  ```solidity
  function _getPendingRedemptionValueForTwo(
      address asyncRedeemer, address machineAddr,
      address owner, address foundation
  ) internal view returns (uint256) {
      // ... fetch lastFinalized, nextId ONCE
      bool checkFoundation = foundation != address(0) && foundation != owner;
      uint256 ownerShares; uint256 foundationShares;
      for (uint256 i; i < scanLimit; ++i) {
          // Check nftOwner against both addresses in single iteration
          if (nftOwner == owner) ownerShares += shares;
          else if (checkFoundation && nftOwner == foundation) foundationShares += shares;
      }
      return convertToAssets(ownerShares + foundationShares);
  }
  ```
- **Reference:** SWC-128; Gas optimization for view functions with external calls

---

### [F-05] Pending Share Valuation Mismatch (Needs Verification)

- **File:** `DETHYieldSourceOracle.sol:293-294`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** Pending redemption shares are valued using the **current** `Machine.convertToAssets()` rate. However, the actual WETH payout at finalization may differ if AsyncRedeemer locks the rate at request time or uses a finalization-time rate. If Machine's PPS drops between request and finalization, the oracle over-reports pending TVL. This creates a systematic mismatch between reported TVL and realizable value. Lido's WithdrawalQueueERC721 locks the share rate at finalization time, creating a similar divergence.
- **Vulnerable Code:**
  ```solidity
  try IMachine(machineAddr).convertToAssets(totalPendingShares) returns (uint256 value) {
      totalPendingValue = value;
  }
  ```
- **Secure Pattern:** If the AsyncRedeemer stores a locked asset amount per request, use that instead:
  ```solidity
  // If AsyncRedeemer exposes getLockedAssets(requestId):
  try redeemer.getLockedAssets(requestId) returns (uint256 assets) {
      totalPendingAssets += assets;
  }
  ```

**ACTION REQUIRED:** Verify AsyncRedeemer's rate model -- does `getShares()` return locked shares valued at request-time rate, current rate, or finalization-time rate?

---

## P3 Findings (Low - Consider Fixing)

### [F-06] getTVL() Staleness Inconsistency with getTVLByOwnerOfShares()

- **File:** `DETHYieldSourceOracle.sol:215-218`
- **Category:** Oracle
- **Description:** `getTVL()` returns `Machine.lastTotalAum()` (cached snapshot), while `getTVLByOwnerOfShares()` uses live `convertToAssets()`. These can diverge significantly between Machine accounting refreshes, confusing solvency monitors that compare the two. Already documented in NatSpec.

### [F-07] No Constructor Validation for foundation_ (Immutable)

- **File:** `DETHYieldSourceOracle.sol:66-73`
- **Category:** Logic
- **Description:** `foundation_` accepted without validation. If set to a system address (AsyncRedeemer, Machine, share token) that happens to own NFTs, TVL would be inflated for all queries. As an immutable, this cannot be corrected post-deployment. Other oracles in the codebase (PendlePTAmortizedOracleV2) validate constructor addresses.

### [F-08] Accumulation Overflow DoS in _getPendingRedemptionValue

- **File:** `DETHYieldSourceOracle.sol:282`
- **SWC:** SWC-101
- **Category:** Arithmetic
- **Description:** `totalPendingShares += shares` accumulates up to 200 getShares() results. If a malicious AsyncRedeemer returns artificially large values, the accumulation overflows (Solidity 0.8 checked math), reverting the entire TVL query. Requires the AsyncRedeemer itself to be malicious.

### [F-09] Read-Only Reentrancy Risk via Machine BeaconProxy

- **File:** `DETHYieldSourceOracle.sol:101,143,194,294`
- **Category:** Oracle
- **Description:** Machine is deployed as a BeaconProxy and can be upgraded. A future upgrade could introduce reentrancy-exploitable callbacks. If the oracle is called during an incomplete state transition in Machine (e.g., mid-deposit with a callback), `convertToAssets()` could return inconsistent values. Similar to the Sentiment protocol exploit ($1M, April 2023) via Balancer read-only reentrancy.

### [F-10] AbstractYieldSourceOracle Missing Constructor Validation

- **File:** `AbstractYieldSourceOracle.sol:29-31`
- **Category:** Logic
- **Description:** `SUPER_LEDGER_CONFIGURATION` immutable set without zero-address check. If deployed with `address(0)`, `getAssetOutputWithFees` silently returns 0 fees (falls into catch branch). Other oracles in the codebase validate this parameter.

---

## Attack Surface Summary

- **External Entry Points:** 9 view functions (decimals, getShareOutput, getWithdrawalShareOutput, getAssetOutput, getPricePerShare, getBalanceOfOwner, getTVLByOwnerOfShares, getTVL, getAssetOutputWithFees) + 3 batch methods from AbstractYieldSourceOracle
- **Value Transfer Points:** None (view-only contract). FOUNDATION address handles value transfers operationally.
- **Oracle Dependencies:** Machine.convertToAssets(), Machine.convertToShares(), Machine.lastTotalAum(), Machine.shareToken()
- **Cross-Contract Interactions:** AsyncRedeemer (machine(), lastFinalizedRequestId(), nextRequestId(), getShares()), Machine (convertToAssets, convertToShares, lastTotalAum, shareToken), ERC721 (ownerOf), ERC20 (balanceOf), ERC20Metadata (decimals)
- **Upgrade Mechanisms:** None in the oracle. Machine is a BeaconProxy (upgradeable).
- **Trust Assumptions:** Machine uses internal accounting; FOUNDATION is trusted and single-strategy; AsyncRedeemer whitelist limits spam; Machine pricing is not manipulable via donations.

---

## Recommended Actions (Priority Order)

1. **VERIFY** Machine.convertToAssets() implementation -- confirm internal tracking, not balance-based pricing (F-03)
2. **VERIFY** AsyncRedeemer rate model for pending shares (F-05)
3. **CONSIDER** adding `DESIGNATED_STRATEGY` immutable to prevent cross-query TVL inflation (F-01)
4. **CONSIDER** merging the double loop into single-pass `_getPendingRedemptionValueForTwo` (F-04)
5. **CONSIDER** reversing scan direction to newest-first (F-02)
6. **ADD** constructor validation for `foundation_` (F-07)
7. **DOCUMENT** gas consumption profile for batch method consumers (F-04)

---

## Security Knowledge Sources
- **evmresearch.io patterns checked:** Oracle manipulation, ERC-721 enumeration, async vault patterns, proxy routing, bounded loops
- **Historical exploits cross-referenced:** Sentiment ($1M, read-only reentrancy), Makina Finance ($4.13M, Machine vault family), Euler Finance (ERC-4626 inflation), Lido (async redemption patterns)
- **Standards referenced:** ERC-4626, ERC-721, ERC-7540, SWC-101, SWC-128
- **Similar protocol analysis:** Lido WithdrawalQueueERC721, Nethermind/Lagoon ERC-7540 audit
