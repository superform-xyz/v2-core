# Security Analysis Report: Spark PSM Hooks

## Metadata
- **Target:** `src/hooks/swappers/spark-psm/` (4 hooks + IPSM3 vendor interface)
- **Mode:** review
- **Date:** 2026-03-09
- **Contract Types Detected:** AMM/DEX swapper hooks with external protocol calls
- **Files Analyzed:** 5 (+ 2 dependencies: BaseHook, HookDataUpdater)
- **Vulnerability Database:** vulnerabilities.md (36 sections, 300+ patterns, 175+ exploits)

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 1 | No |
| P3 Low | 3 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed.

The hooks are well-written and closely follow the established UniswapV3 hook patterns. One actionable P2 finding (missing address(0) validation) is a defense-in-depth improvement. The `inspect()` receiver inconsistency was noted but is per user request (receiver was intentionally added).

---

## P0 Findings (Critical)
None found.

## P1 Findings (High)
None found.

## P2 Findings (Medium)

### [Missing assetIn/assetOut Address(0) Validation]
- **File:** All 4 hooks (e.g., `SwapSparkPSMExactInHook.sol:72-73`)
- **SWC:** N/A
- **Category:** Logic / Input Validation
- **Description:** The UniswapV3 hooks validate `tokenIn != address(0)` and `tokenOut != address(0)`, reverting with `NATIVE_ETH_NOT_SUPPORTED`. The PSM hooks skip this check. For `ApproveAndSwap` variants, calling `IERC20.approve` on `address(0)` would execute a call to an empty address before reaching the PSM, resulting in confusing error messages instead of a clear revert.
- **Exploit Scenario:** A misconfigured bundler passes `assetIn = address(0)`. The approve calls to the zero address succeed silently (no code there), then the PSM swap fails with an opaque error.
- **Vulnerable Code:**
  ```solidity
  address assetIn = data.toAddress(0);
  address assetOut = data.toAddress(20);
  // No address(0) check
  ```
- **Secure Pattern:**
  ```solidity
  address assetIn = data.toAddress(0);
  address assetOut = data.toAddress(20);
  if (assetIn == address(0) || assetOut == address(0)) revert ADDRESS_NOT_VALID();
  ```
- **Reference:** vulnerabilities.md Section 2 (Access Control / Input Validation)

---

## P3 Findings (Low)

### [No Deadline/Expiry on PSM Swaps]
- **File:** All 4 hooks
- **Category:** MEV
- **Description:** UniswapV3 hooks include a `deadline` parameter. PSM hooks omit it. However, this is **mitigated** by: (1) PSM uses deterministic oracle pricing, not AMM pricing (no sandwich vector); (2) `minAmountOut`/`maxAmountIn` bound acceptable rates; (3) SuperValidator enforces timestamp-based expiry on the overall Merkle root.
- **Reference:** vulnerabilities.md Section 6

### [HookDataUpdater Precision Loss (Inherited)]
- **File:** `HookDataUpdater.sol` (shared library, not PSM-specific)
- **Category:** Arithmetic
- **Description:** The two-step percentage calculation (`PRECISION = 1e5`) can produce slight rounding differences vs direct `Math.mulDiv(outputAmount, amount, _prevAmount)`. This is an inherited property from the shared library, identical to how UniswapV3 hooks use it. Not a net-new vulnerability.
- **Reference:** vulnerabilities.md Section 3

### [abi.encodePacked in inspect() with Fixed-Size Types]
- **File:** All 4 hooks `inspect()` function
- **Category:** Other (SWC-133)
- **Description:** `abi.encodePacked(assetOut, receiver)` with two `address` types. Safe because both are fixed 20-byte types — no collision possible. Informational only.
- **Reference:** vulnerabilities.md Section 9

---

## Critical Pattern Scan (8/8 Pass)

| # | Pattern | Status |
|---|---------|--------|
| 1 | Reentrancy | PASS - BaseHook pre/post execute mutex via transient storage |
| 2 | Access Control | PASS - `preExecute`/`postExecute` enforce `msg.sender == account` |
| 3 | Division Before Multiplication | PASS - Uses `Math.mulDiv` (OpenZeppelin) |
| 4 | Unchecked Return Values | PASS - Calls via `abi.encodeCall` in Execution arrays |
| 5 | Missing Reentrancy Guards | PASS - BaseHook mutex pattern |
| 6 | abi.encodePacked Collisions | PASS - Only fixed-size types |
| 7 | tx.origin Authentication | PASS - No `tx.origin` usage |
| 8 | Floating Pragma | PASS - `pragma solidity 0.8.30` (locked) |

## Attack Surface Summary

### External Entry Points
- `build()` (view) - Returns Execution[] arrays, no side effects
- `preExecute()` / `postExecute()` - Protected by `msg.sender == account`
- `inspect()` (pure) - Returns packed data, read-only
- `decodeUsePrevHookAmount()` (pure) - Read-only

### Value Transfer Points
- PSM `swapExactIn`/`swapExactOut` calls (tokens move through PSM)
- `IERC20.approve` calls on `assetIn` (ApproveAndSwap variants only)

### Oracle Dependencies
- sUSDS rate via PSM's `rateProvider` (governance-controlled, not flash-loan-manipulable)

### Security Properties Verified
- Receiver always forced to `account` in PSM calls
- Approve-and-revoke pattern: `approve(0) → approve(exact) → swap → approve(0)`
- ExactOut correctly approves `maxAmountIn` (NOT `amountOut`)
- Zero residual approvals after execution
- Balance delta tracking via pre/post snapshot pattern
- Atomic batch execution via ERC-7579 (all-or-nothing rollback)

## Exploit Precedent Check

| Similar Protocol | Exploit | Loss | Relevance | Our Mitigation |
|---|---|---|---|---|
| SIR.trading (Mar 2025) | Transient storage slot collision | $355K | Uses transient storage | keccak256-keyed slots, unique contexts |
| Li.Fi (Jul 2024) | Residual approval drain | $11.6M | Handles approvals | Approve-and-revoke pattern |
| Balancer V2 (Nov 2025) | Rounding error compounding | $128M | Swap math | PSM is deterministic, not compoundable |
| CurioDAO (Mar 2024) | PSM fork governance exploit | $16M | PSM integration | Using canonical PSM3, not a fork |

## Coding Standards Summary
- **Compliant:** Locked pragma, custom errors, NatSpec, import organization, section banners
- **Minor:** Consider extracting `_decodeSwapParams()` helper (P3, consistency with UniV3)
- **Minor:** Add `@dev Assumes tokens are already approved to the PSM` to non-Approve hook variants (P3)

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 1, 2, 3, 4, 6, 8, 9, 10, 13, 15, 36
- **evmresearch.io patterns checked:** vulnerability-patterns (approval, reentrancy, oracle), exploit-analyses (SIR, Balancer, Li.Fi)
- **Coding rules validated:** coding-rules.md full compliance check
- **Historical exploits cross-referenced:** 7 (SIR, Balancer, Li.Fi, SocketDotTech, CurioDAO, DeltaPrime, SenecaUSD)
- **OWASP Smart Contract Top 10 (2025):** 10/10 categories assessed
