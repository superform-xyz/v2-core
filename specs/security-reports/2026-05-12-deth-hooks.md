# Security Analysis Report

## Metadata
- **Target:** `src/hooks/vaults/deth/` (3 hook contracts + 2 vendor interfaces)
- **Mode:** review
- **Date:** 2026-05-12
- **Contract Types Detected:** Vault/ERC4626 (async redemption hooks)
- **Files Analyzed:** 5 (+ BaseHook.sol for context)
- **Agents Used:** Vulnerability Scanner, Best Practices, EVM Security Research

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | - |
| P1 High | 1 | Yes |
| P2 Medium | 4 | No |
| P3 Low | 7 | No |

## Verdict
**CONDITIONAL PASS** - 1 P1 finding should be evaluated before merge. The P1 is an external protocol risk (Makina oracle exploit on same protocol family) rather than a code bug in the hooks. All hook code paths are well-structured and follow established patterns.

---

## P0 Findings (Critical - Must Fix)

None found.

---

## P1 Findings (High - Must Fix)

### [P1-1] Makina/Dialectic Oracle Was Exploited in January 2026 for $4M

- **File:** N/A (external protocol risk)
- **SWC:** N/A
- **Severity:** P1 High
- **Category:** Oracle / External Protocol Risk
- **Description:** The exact protocol family these hooks integrate with (Dialectic/Makina) was exploited in January 2026. The attacker inflated `sharePrice` from 1.01 to 1.33 by flash-loaning ~280M USDC to manipulate Curve pool spot prices feeding into Makina's `MachineShareOracle`. Root causes: permissionless oracle updates, synchronous spot price reads without TWAP, no flash-loan protections. The exploit targeted DUSD, but DETH uses the same Machine architecture.
- **Real-World Precedent:** Makina $4M hack (Jan 2026) - exact same protocol family
- **Mitigation:**
  1. Verify the DETH Machine's oracle has been patched post-exploit
  2. Consider adding share-price deviation bounds before executing `requestRedeem`
  3. Ensure `minAssets` slippage parameter is set aggressively by the off-chain system
  4. Note: `minAssets` is checked at request time but PPS is recalculated at finalization -- users cannot cancel

---

## P2 Findings (Medium - Should Fix)

### [P2-1] `ClaimAssetsDETHHook` Sets `spToken = asyncRedeemer` (Not an ERC-20)

- **File:** `src/hooks/vaults/deth/ClaimAssetsDETHHook.sol:93`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Cross-Contract Interactions / Accounting
- **Description:** In `_preExecute`, `spToken` is set to the `asyncRedeemer` address. In other OUTFLOW hooks (e.g., `Redeem4626VaultHook`), `spToken` is set to the share token (an ERC-20). The `asyncRedeemer` is an ERC-721 minter, not an ERC-20. If any downstream component (SuperLedger, cost basis) calls `IERC20(spToken).balanceOf(account)`, it would revert or return unexpected results.

  The comparable `ClaimWithdrawFirelightVaultHook` sets `spToken = yieldSource` which is the vault itself (also not a share token but at least an ERC-20). This is a known pattern in the codebase but should be explicitly documented or use the DETH share token instead.
- **Vulnerable Code:**
  ```solidity
  spToken = asyncRedeemer;
  ```
- **Secure Pattern (Option A - use share token):**
  ```solidity
  spToken = IMachine(machine).shareToken(); // DETH - actual ERC-20 share token
  ```
- **Secure Pattern (Option B - document intent):**
  ```solidity
  // spToken set to asyncRedeemer as yield source identifier for oracle/accounting lookups
  // NOTE: asyncRedeemer is NOT an ERC-20 -- do not call balanceOf on spToken
  spToken = asyncRedeemer;
  ```

### [P2-2] ERC-721 Callback Reentrancy During `requestRedeem` NFT Mint

- **File:** `src/hooks/vaults/deth/RequestRedeemDETHHook.sol:65-69` and `ApproveAndRequestRedeemDETHHook.sol:75-79`
- **SWC:** SWC-107
- **Severity:** P2 Medium
- **Category:** Reentrancy
- **Description:** When `requestRedeem()` is called on the AsyncRedeemer, it mints an ERC-721 NFT to the account (smart account). If the AsyncRedeemer uses `_safeMint`, the `onERC721Received` callback occurs MID-execution-batch -- between the `requestRedeem` call and the final `approve(0)` cleanup (in `ApproveAndRequestRedeemDETHHook`). The BaseHook's pre/post execute mutex prevents re-entering the SAME hook, but does not prevent the callback from triggering OTHER operations on the smart account.
- **Mitigation:** The BaseHook mutex provides same-hook protection. Verify: (a) whether the AsyncRedeemer uses `_safeMint` or `_mint`, (b) whether the smart account (Nexus/Safe) prevents arbitrary module execution during `onERC721Received` callbacks.
- **Assessment:** Low exploitability given the smart account execution model. The SuperExecutor controls the execution batch atomically.

### [P2-3] DETH Rebasing Behavior Could Affect Balance Measurements

- **File:** `src/hooks/vaults/deth/RequestRedeemDETHHook.sol:94-99`
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Token Integration
- **Description:** Both `RequestRedeemDETHHook` and `ApproveAndRequestRedeemDETHHook` compute `usedShares`/`outAmount` via balance differentials between `_preExecute` and `_postExecute`. If DETH rebases between these calls (within the same transaction), the delta would be incorrect. While intra-transaction rebase is unlikely, verify whether `requestRedeem()` triggers a `sync()` on the Machine that changes DETH balances.
- **Mitigation:** Verify DETH's rebase trigger mechanism. If `requestRedeem` can trigger a rebase, the `usedShares` subtraction on line 99 (`usedShares - _getSharesBalance`) could underflow (revert) or produce wrong values.

### [P2-4] Async PPS Gap: `minAssets` Checked at Request Time, PPS Recalculated at Finalization

- **File:** `src/hooks/vaults/deth/RequestRedeemDETHHook.sol:54` (minAssets decoded but only enforced by AsyncRedeemer)
- **SWC:** N/A
- **Severity:** P2 Medium
- **Category:** Business Logic / Oracle
- **Description:** The `minAssets` slippage check occurs at `requestRedeem()` time in the AsyncRedeemer, but the actual PPS is recalculated when the keeper calls `finalizeRequests()`. There is no cancel mechanism -- once DETH is transferred, the user must wait for finalization. If the PPS changes adversely between request and finalization, the user has no recourse. This is a documented design limitation of the Dialectic protocol, not a hook bug.
- **Mitigation:** The SuperForm off-chain system should: (a) set `minAssets` aggressively based on the Fair Pricing Service, (b) monitor finalization PPS for deviations, (c) alert if finalization takes longer than expected (43200 second delay).

---

## P3 Findings (Low - Consider Fixing)

### [P3-1] Inconsistent IERC20 Import Path in `ApproveAndRequestRedeemDETHHook`

- **File:** `src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol:6`
- **Description:** Imports from `@openzeppelin/contracts/interfaces/IERC20.sol` while all other hooks use `@openzeppelin/contracts/token/ERC20/IERC20.sol`. Both resolve to the same interface.
- **Fix:**
  ```solidity
  import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
  ```

### [P3-2] hookData Layout Uses `placeholder` Instead of `yieldSourceOracleId`

- **File:** `src/hooks/vaults/deth/ApproveAndRequestRedeemDETHHook.sol:23`
- **Description:** Uses `bytes32 placeholder` for position 0, while `RequestRedeemDETHHook` and `ClaimAssetsDETHHook` use `bytes32 yieldSourceOracleId`. All reference hooks (`ApproveAndDeposit4626VaultHook`) use `yieldSourceOracleId`.
- **Fix:** Change `placeholder` to `yieldSourceOracleId` in the NatSpec comment.

### [P3-3] `inspect()` Uses `@inheritdoc BaseHook` Instead of `@inheritdoc ISuperHookInspector`

- **File:** All 3 DETH hooks
- **Description:** Reference hooks use `/// @inheritdoc ISuperHookInspector` for the `inspect()` function. All 3 DETH hooks use `/// @inheritdoc BaseHook`.
- **Fix:** Change to `/// @inheritdoc ISuperHookInspector` (also add `ISuperHookInspector` to imports for `RequestRedeemDETHHook` and `ClaimAssetsDETHHook`).

### [P3-4] `inspect()` Placed in Wrong Section in `RequestRedeemDETHHook`

- **File:** `src/hooks/vaults/deth/RequestRedeemDETHHook.sol:73`
- **Description:** `inspect()` is inside the `VIEW METHODS` section. In all reference hooks and the companion DETH hooks, it's in the `EXTERNAL METHODS` section.
- **Fix:** Move `inspect()` to the `EXTERNAL METHODS` section.

### [P3-5] Gas: `_getSharesBalance` Makes Redundant External Calls

- **File:** `src/hooks/vaults/deth/RequestRedeemDETHHook.sol:109-113`
- **Description:** Called twice (pre + post), each call makes 2 external calls to derive the share token address (`asyncRedeemer.machine()` + `machine.shareToken()`). These addresses are immutable. Could cache `shareToken` in transient storage during `_preExecute`.
- **Fix (optional):**
  ```solidity
  function _preExecute(address, address account, bytes calldata data) internal override {
      address asyncRedeemer = data.extractYieldSource();
      address machine = IDETHAsyncRedeemer(asyncRedeemer).machine();
      spToken = IMachine(machine).shareToken(); // cache
      usedShares = IERC20(spToken).balanceOf(account);
  }
  function _postExecute(address, address account, bytes calldata) internal override {
      usedShares = usedShares - IERC20(spToken).balanceOf(account);
  }
  ```

### [P3-6] No `minAssets > 0` Validation in Request Hooks

- **File:** `src/hooks/vaults/deth/RequestRedeemDETHHook.sol:54`, `ApproveAndRequestRedeemDETHHook.sol:55`
- **Description:** `minAssets` is decoded and passed through without validation. If `minAssets = 0`, no slippage protection exists. The AsyncRedeemer may enforce its own minimum, but the hook layer provides no guard.
- **Fix:** Consider adding `if (minAssets == 0) revert AMOUNT_NOT_VALID();` or document that 0 is acceptable.

### [P3-7] Vendor Interfaces Missing `@return` NatSpec Tags

- **File:** `src/vendor/vaults/deth/IMachine.sol:9-10`, `IDETHAsyncRedeemer.sol:24`
- **Description:** `shareToken()`, `accountingToken()`, and `machine()` lack `@return` NatSpec.
- **Fix:** Add `/// @return` tags to each function.

---

## Attack Surface Summary

### External Entry Points
| Function | Contract | Callable By | Risk |
|----------|----------|-------------|------|
| `build()` | All 3 hooks | Anyone (view) | Low - read-only |
| `preExecute()` | All 3 hooks | Account only (msg.sender check) | Low - mutex protected |
| `postExecute()` | All 3 hooks | Account only (msg.sender check) | Low - mutex protected |
| `decodeAmount()` | All 3 hooks | Anyone (pure) | None |
| `decodeUsePrevHookAmount()` | All 3 hooks | Anyone (pure) | None |
| `inspect()` | All 3 hooks | Anyone (pure/view) | None |

### Value Transfer Points
| Operation | Source | Destination | Token |
|-----------|--------|-------------|-------|
| `requestRedeem` | Account | AsyncRedeemer | DETH (shares) |
| `claimAssets` | AsyncRedeemer | Account | WETH |
| `approve` | Account allowance | AsyncRedeemer spender | DETH allowance |

### External Protocol Dependencies
| Contract | Address | Risk |
|----------|---------|------|
| AsyncRedeemer | `0xE44b62dD3F6379D6d14c38081fe1499D1a56250F` | Whitelist required, keeper dependency |
| Machine (BeaconProxy) | `0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735` | Oracle was exploited Jan 2026 |
| DETH | `0x871aB8E36CaE9AF35c6A3488B049965233DeB7ed` | 18 decimals, possible rebasing |
| WETH | `0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2` | Standard, no risk |

---

## Coding Standards Findings

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | Inconsistent IERC20 import path | P3 | Fix recommended |
| 2 | `placeholder` vs `yieldSourceOracleId` naming | P3 | Fix recommended |
| 3 | `@inheritdoc BaseHook` vs `ISuperHookInspector` | P3 | Fix recommended |
| 4 | `inspect()` placement in wrong section | P3 | Fix recommended |
| 5 | Vendor interfaces missing `@return` NatSpec | P3 | Fix recommended |
| 6 | NatSpec `@notice` misuse for data layout | P3 | Consistent with codebase, no change |
| 7 | `_preExecute`/`_postExecute` lack NatSpec | P3 | Consistent with codebase, no change |

---

## Key Observations

**What's done well:**
- Locked pragma `0.8.30` throughout
- Custom errors instead of revert strings
- Zero-set-execute-zero approval pattern (defense in depth)
- Balance delta tracking for accurate accounting
- Follows established hook patterns (Firelight, ERC-7540, Ethena)
- BaseHook transient storage mutex prevents same-hook reentrancy
- `msg.sender == account` enforcement on pre/post execute

**Design decisions to document:**
- `usedShares` intentionally not set in `ClaimAssetsDETHHook` (shares consumed in prior step)
- `RequestRedeemDETHHook` does not set `outAmount` (cannot capture requestId from return value in the execution architecture)
- Two hooks are not chainable via `usePrevHookAmount` (requestRedeem and claimAssets happen in separate transactions)
