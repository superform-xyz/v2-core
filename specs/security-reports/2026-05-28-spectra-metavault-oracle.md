# Security Analysis Report

## Metadata
- **Target:** `src/accounting/oracles/SpectraMetaVaultOracle.sol`
- **Mode:** review
- **Date:** 2026-05-28
- **Contract Types Detected:** Vault/ERC4626 Oracle (ERC-7540 async)
- **Files Analyzed:** 1 (+ base class + interface for context)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 3 | No |
| P3 Low | 5 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

---

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

### [P2-1] convertToAssets Revert Inside try/catch Propagates — Breaks R2 Graceful Degradation
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:227-240`
- **SWC:** N/A
- **Category:** DoS
- **Description:** Components 2 and 3 use `try vault.pendingRedeemRequest(...)` / `try vault.claimableRedeemRequest(...)`, but inside the success branch, `vault.convertToAssets(pendingShares)` is called without try/catch. If `convertToAssets()` reverts (e.g., during unsettled epoch or vault migration), the entire `getAsyncStateBreakdown` reverts, losing ALL 5 components. The NatSpec states "On failure, component = 0 (drops individually, never reverts entirely)" but this is not fully true. Component 1 (`heldShares -> convertToAssets`) is also unwrapped, which is intentional per spec but adds to the propagation surface.
- **Exploit Scenario:** During epoch settlement, `convertToAssets()` temporarily reverts. Any system depending on `getTVLByOwnerOfShares` (fee calculations, portfolio valuation) becomes unavailable for all users of this vault — a temporary DoS on accounting.
- **Real-World Precedent:** Accepted pattern in `ERC7540YieldSourceOracle` — same behavior exists there.
- **Vulnerable Code:**
  ```solidity
  try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
      if (pendingShares > 0) {
          pendingRedeemValue = vault.convertToAssets(pendingShares); // reverts propagate
      }
  } catch { }
  ```
- **Secure Pattern:**
  ```solidity
  try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
      if (pendingShares > 0) {
          try vault.convertToAssets(pendingShares) returns (uint256 value) {
              pendingRedeemValue = value;
          } catch { }
      }
  } catch { }
  ```
- **Reference:** vulnerabilities.md Section 13 (DoS — external call revert)
- **Status:** Accepted risk (documented in technical spec). Same pattern in generic oracle.

### [P2-2] Epoch Boundary Rate Inconsistency for Claimable Redeem (Component 3)
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:236-240`
- **SWC:** N/A
- **Category:** Oracle
- **Description:** Component 3 converts `claimableRedeemRequest` shares using the **current** `convertToAssets` rate. However, claimable redeem shares were settled at a **previous epoch's** snapshot rate. If PPS has changed between settlement and oracle read, the oracle over/under-values the claimable position. The magnitude depends on epoch frequency (~28h) and PPS volatility.
- **Exploit Scenario:** Epoch 5 settles with PPS=1.00. Before epoch 6 settles, PPS rises to 1.05. The oracle values claimable shares at 1.05 instead of 1.00, overvaluing by 5%. This feeds into SuperLedger fee calculations.
- **Real-World Precedent:** This is the exact issue that motivated diverging from `maxWithdraw()` (which used OZ `_convertToAssets` with broken pricing). The current approach uses the overridden `convertToAssets` which is closer to correct but not exact.
- **Secure Pattern:** Verify whether MetaVaultWrapper's `convertToAssets` already applies the settlement-epoch rate to claimable shares (it does via Amphor's epoch accounting). If so, this is a non-issue. Document the assumption.
- **Reference:** ERC-7540 Specification; Nethermind Lagoon V1-V5 audit
- **Status:** Likely mitigated by vault's own epoch accounting. Needs on-chain verification.

### [P2-3] Potential Double-Counting Between balanceOf (C1) and pendingRedeemRequest (C2)
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:220-231`
- **SWC:** N/A
- **Category:** Vault
- **Description:** If MetaVaultWrapper's `requestRedeem` does NOT reduce `balanceOf(owner)` (i.e., shares stay in balance while also counted by `pendingRedeemRequest`), Components 1 and 2 would double-count the same shares, inflating `getTVLByOwnerOfShares`. The ERC-7540 spec states shares MUST be removed from owner during `requestRedeem`, but implementations may vary.
- **Exploit Scenario:** User requests redemption of 100 shares. If `balanceOf` still returns 100 AND `pendingRedeemRequest` also returns 100, TVL is doubled.
- **Secure Pattern:** Verify on-chain that `requestRedeem` decrements `balanceOf`. The ERC-7540 spec requires this. Add integration test confirming mutual exclusivity invariant.
- **Reference:** vulnerabilities.md Section 22 (Vault/Share Accounting)
- **Status:** ERC-7540 spec guarantees mutual exclusivity. Needs on-chain verification for this specific vault.

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] getTVL Excludes Pending/Claimable Deposits — Inconsistent with getTVLByOwnerOfShares
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:179-183`
- **Category:** Logic
- **Description:** `getTVL()` returns `convertToAssets(totalSupply())` which only counts minted shares. Components 4+5 (pending/claimable deposits) represent assets not yet minted into shares. This means `sum(getTVLByOwnerOfShares)` can exceed `getTVL()`.
- **Secure Pattern:** Document as known limitation. Consider adding aggregate pending deposit tracking if available from vault.

### [P3-2] getWithdrawalShareOutput Returns 0 Instead of Reverting When PPS=0
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:99-100`
- **Category:** Arithmetic
- **Description:** When `convertToAssets(oneShare) == 0` (unsettled epoch), function returns 0 shares needed for withdrawal. This is semantically incorrect — no valid conversion exists. `getPricePerShare` would hard-revert in the same scenario (R1 pattern), but this function silently returns 0.
- **Secure Pattern:** Consider reverting with a custom error for consistency with R1 pattern.

### [P3-3] _getShareToken Catches All Reverts, Not Just "Not Implemented"
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:263-269`
- **Category:** Logic
- **Description:** If `share()` reverts due to transient error (gas, proxy issue), the oracle silently falls back to vault address as share token. Additionally, if `share()` returns `address(0)`, it's used as-is causing downstream reverts.
- **Secure Pattern:** Add `if (shareToken == address(0)) return yieldSourceAddress;` after successful `share()` call.

### [P3-4] No Zero-Address Validation in Constructor
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:41-48`
- **SWC:** SWC-123
- **Category:** Logic
- **Description:** Constructor accepts `address(0)` for `superLedgerConfiguration_`. Same pattern as all other oracles — should be fixed in `AbstractYieldSourceOracle` base class.

### [P3-5] Empty catch Blocks Lack Inline Comments
- **File:** `src/accounting/oracles/SpectraMetaVaultOracle.sol:231,240,245,250`
- **Category:** Other
- **Description:** Four `catch { }` blocks have no inline comment. While function-level NatSpec explains R2 degradation, inline comments improve readability.
- **Secure Pattern:** `} catch { } // graceful degradation: component defaults to 0`

---

## Attack Surface Summary

- **External Entry Points:** `decimals`, `getShareOutput`, `getWithdrawalShareOutput`, `getAssetOutput`, `getPricePerShare`, `getBalanceOfOwner`, `getTVLByOwnerOfShares`, `getTVL`, `getAsyncStateBreakdown` (all `view`)
- **Value Transfer Points:** None (pure read-only oracle)
- **Oracle Dependencies:** `vault.convertToAssets()`, `vault.convertToShares()` — relies on vault's epoch snapshot rate
- **Cross-Contract Interactions:** `IERC7540` (vault), `IERC20` (share token), `IERC20Metadata` (decimals)
- **Upgrade Mechanisms:** None (immutable deployment, no proxy)

## Coding Standards Findings

| # | Rule | Severity | Status |
|---|------|----------|--------|
| 1 | Zero-address constructor validation | P2 | Should fix in base class |
| 2 | Empty catch block comments | P3 | Cosmetic |
| 3 | Import comment casing (`// External` vs `// external`) | P3 | Cosmetic, matches ERC7540 oracle |
| 4 | Missing `virtual` on `getAsyncStateBreakdown` | P3 | Enhancement |

Overall: Code is well-written, consistent with sibling oracle patterns, excellent NatSpec documentation.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 3, 4, 5, 10, 13, 15, 22, 28, 36
- **evmresearch.io patterns checked:** vulnerability-patterns/donation-attack, exploit-analyses/erc4626, security-patterns/oracle-defense, protocol-mechanics/async-vaults
- **Coding rules validated:** 11 rules checked
- **Historical exploits cross-referenced:** Mountain Protocol wUSDM ($320K, Feb 2025), Venus Protocol (86 WETH, Feb 2025), dForce read-only reentrancy ($3.7M, 2023), Amphor Sherlock audit (2024-03)
- **OWASP SC Top 10 (2025):** All 10 categories assessed; SC02 (Oracle Manipulation) most relevant
