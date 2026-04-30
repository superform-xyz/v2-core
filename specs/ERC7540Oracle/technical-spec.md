# ERC7540YieldSourceOracle Technical Specification

## Overview

Build an `ERC7540YieldSourceOracle` that tracks the full value of smart account positions in ERC-7540 async vaults. The existing oracle infrastructure only tracks `balanceOf` (held shares), missing pending redemptions, claimable redemptions, pending deposits, and claimable deposits. This creates artificial PPS drops exploitable via deposit/withdraw timing.

## Problem Statement

When a SuperVault strategy calls `requestRedeem()` on a 7540 vault:
1. Shares leave `balanceOf(strategy)` and enter pending state
2. Existing oracles see TVL = 0 for that position (only read `balanceOf`)
3. Keeper computes lower totalAssets → pushes lower PPS
4. Attacker deposits at deflated PPS, waits for claim, profits from PPS rebound

Same problem in reverse for async deposits: assets leave idle balance, no shares yet, TVL understates.

## Proposed Solution

Five-component TVL formula:
```
TVL = heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue
```

| Component | Source | Denomination | Conversion |
|-----------|--------|-------------|------------|
| Held shares | `IERC20(vault.share()).balanceOf(owner)` | shares | `convertToAssets(shares)` |
| Pending redeem | `pendingRedeemRequest(REQUEST_ID, owner)` | shares | `convertToAssets(shares)` |
| Claimable redeem | `maxWithdraw(owner)` | assets | Already in assets (D1) |
| Pending deposit | `pendingDepositRequest(REQUEST_ID, owner)` | assets | Already in assets |
| Claimable deposit | `claimableDepositRequest(REQUEST_ID, owner)` | assets | Already in assets |

## Technical Considerations

### Architecture

The oracle extends `AbstractYieldSourceOracle` with the same constructor pattern as all existing oracles. Key architectural decisions:

- **D1**: Use `maxWithdraw(controller)` for claimable redeem component (handles Centrifuge locked redeemPrice)
- **D2**: `REQUEST_ID` as immutable constructor param (default 0, accumulated pattern)
- **D3**: Hybrid error handling — `getPricePerShare` hard reverts (R1), `getTVLByOwnerOfShares` wraps async calls in try/catch (R2)
- **D4**: Include both async deposit AND async redeem components
- **D5**: Accept `convertToAssets` excludes fees (bounded by 0-0.5%)

### Scope

- Handles **vanilla 7540** and **Centrifuge V3** vaults (both use standard `pendingRedeemRequest(uint256 requestId, address controller)` signature)
- **Yo-style vaults** continue using the existing `YoYieldSourceOracle` (different function selector: `pendingRedeemRequest(address)` returns `(uint256 assets, uint256 shares)`)
- **Invariant**: `controller == owner == smartAccount` (Superform hooks pass `account` as both)

### Performance

- View-only oracle — no state mutations, no storage writes
- Gas efficient — single `eth_call` to read all 5 components
- Zero-check optimization: skip `convertToAssets` when shares == 0

### Security Considerations

See [research/evm-security.md](./research/evm-security.md) for full analysis. Key risks:

| Risk | Severity | Mitigation |
|------|----------|------------|
| Donation attack on convertToAssets | P1 High | Per-vault onboarding validation, keeper rate limits |
| Double-count (non-compliant vault) | P1 High | INV-4 invariant test, per-vault validation |
| Vault non-compliance | P1 High | Per-vault validation at onboarding |
| Keeper key compromise | P0 Critical | On-chain PPS bounds, multi-sig (out of scope) |
| Sandwich keeper read | P2 Medium | Private mempool, PPS rate limits (keeper-side) |
| Try/catch forced revert | P2 Medium | Keeper monitoring, PPS rate limits |
| Read-only reentrancy | P3 Low | Off-chain keeper, ERC-20 only tokens |

## Attack Surface Analysis

### Token Risks
- [x] Fee-on-transfer: N/A — oracle is view-only, no token transfers
- [x] Rebasing tokens: `convertToAssets` may reflect rebased amounts — vault-dependent
- [x] Missing return values: N/A — no SafeERC20 needed (view-only)
- [x] >18 decimals: Handled via `share().decimals()` dynamically
- [x] Pausable/blocklist: May cause view function reverts — handled by try/catch (R2)

### Reentrancy
- [x] CEI pattern: N/A — view-only, no state mutations
- [x] Read-only reentrancy: P3 Low — oracle consumed off-chain by keeper, not during callbacks
- [x] Cross-contract reentrancy: N/A — no state changes

### Oracle & Price
- [x] Oracle manipulation: `convertToAssets` vulnerable to donation attacks (P1 High, vault-dependent)
- [x] Stale price: PPS hard reverts if `convertToAssets` fails — never returns stale data
- [x] Fee exclusion: `convertToAssets` excludes fees (D5, bounded by 0-0.5%)

### Vault/Share Accounting
- [x] Double-count: ERC-7540 spec mandates mutual exclusivity; INV-4 validates
- [x] First depositor attack: Vault-level defense, not oracle concern
- [x] Rounding: `convertToAssets` rounds DOWN per spec (correct for oracle read)

### Exploit Precedent

| Similar Protocol | Exploit | Loss | Our Mitigation |
|-----------------|---------|------|----------------|
| Euler Finance (2023) | Exchange rate manipulation | $197M | Per-vault donation resistance check at onboarding |
| Curve/dForce (2023) | Read-only reentrancy | $3.7M | Off-chain keeper read, no on-chain consumption |
| Oracle manipulation (2025) | ERC-4626 vault oracle | $700K | Keeper rate limits, TWAP |

## Acceptance Criteria

### Functional Requirements
- [x] Five-component TVL tracking (held, pendingRedeem, claimableRedeem, pendingDeposit, claimableDeposit)
- [x] `getPricePerShare()` → `convertToAssets(10^decimals)` with hard revert on failure
- [x] `getTVLByOwnerOfShares()` → sum of 5 components with per-component try/catch
- [x] `getAsyncStateBreakdown()` → returns 5 components individually for monitoring
- [x] `maxWithdraw(controller)` for claimable redeem value (D1)
- [x] `REQUEST_ID` as immutable constructor param (D2)
- [x] Extends `AbstractYieldSourceOracle` base class
- [x] Compatible with `SuperLedgerConfiguration.setYieldSourceOracles()` registration

### Non-Functional Requirements
- [x] View-only — no state mutations
- [x] Solidity 0.8.30
- [x] NatSpec on all public/external functions
- [x] Custom errors (no require strings)

### Security Requirements
- [x] INV-4 invariant: no double-counting across pools
- [x] Fuzz tests for arithmetic edge cases
- [x] Fork integration tests against real Centrifuge vaults

## Implementation

### Phase 1: Oracle Contract

**Create `src/accounting/oracles/ERC7540YieldSourceOracle.sol`**

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IERC7540 } from "../../vendor/vaults/7540/IERC7540.sol";

/// @title ERC7540YieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for ERC-7540 async vaults with full lifecycle TVL tracking
/// @dev Accounts for 5 TVL components: held shares + pending redeem + claimable redeem
///      + pending deposit + claimable deposit
///      Uses ERC-7575 share() for separate share token discovery
///      Uses maxWithdraw() for claimable redeem (handles Centrifuge locked redeemPrice)
contract ERC7540YieldSourceOracle is AbstractYieldSourceOracle {

    /// @notice The requestId used for accumulated-pattern 7540 vaults
    uint256 public immutable REQUEST_ID;

    /// @notice Thrown when the yield source address is zero
    error ZERO_ADDRESS();

    constructor(
        address superLedgerConfiguration_,
        uint256 requestId_
    ) AbstractYieldSourceOracle(superLedgerConfiguration_) {
        REQUEST_ID = requestId_;
    }

    // --- Core abstract method implementations ---

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Uses ERC-7575 share() to get the separate share token, then reads its decimals
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        address shareToken = IERC7540(yieldSourceAddress).share();
        return IERC20Metadata(shareToken).decimals();
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Uses convertToShares (not previewDeposit) — previewDeposit may revert on async vaults
    function getShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    ) external view override returns (uint256) {
        return IERC7540(yieldSourceAddress).convertToShares(assetsIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Manual inverse via Math.mulDiv — previewWithdraw reverts on async vaults
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    ) external view override returns (uint256) {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = vault.share();
        uint256 shareDecimals = IERC20Metadata(shareToken).decimals();
        uint256 oneShare = 10 ** shareDecimals;

        uint256 assetsPerShare = vault.convertToAssets(oneShare);
        if (assetsPerShare == 0) return 0;

        return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Uses convertToAssets (not previewRedeem) — previewRedeem reverts on async 7540 vaults
    function getAssetOutput(
        address yieldSourceAddress,
        address,
        uint256 sharesIn
    ) public view override returns (uint256) {
        return IERC7540(yieldSourceAddress).convertToAssets(sharesIn);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev R1: Hard revert. PPS must be correct or absent — returning 0/stale causes incorrect fees.
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = vault.share();
        uint256 _decimals = IERC20Metadata(shareToken).decimals();
        return vault.convertToAssets(10 ** _decimals);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    ) external view override returns (uint256) {
        address shareToken = IERC7540(yieldSourceAddress).share();
        return IERC20(shareToken).balanceOf(ownerOfShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev R2: Graceful degradation. Each async component wrapped in try/catch.
    ///      On failure, component = 0 (drops individually, never reverts entirely).
    ///      Five components: held + pendingRedeem + claimableRedeem + pendingDeposit + claimableDeposit
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    ) public view override returns (uint256) {
        (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        ) = getAsyncStateBreakdown(yieldSourceAddress, ownerOfShares);

        return heldValue + pendingRedeemValue + claimableRedeemValue
             + pendingDepositValue + claimableDepositValue;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        return IERC7540(yieldSourceAddress).totalAssets();
    }

    // --- ERC-7540 specific ---

    /// @notice Returns all 5 TVL components individually for monitoring instrumentation
    /// @param yieldSourceAddress The ERC-7540 vault address
    /// @param owner The smart account whose position to value
    /// @return heldValue Value of shares in balanceOf (assets)
    /// @return pendingRedeemValue Value of shares in pending redeem state (assets)
    /// @return claimableRedeemValue Value of claimable redeem via maxWithdraw (assets)
    /// @return pendingDepositValue Assets in pending deposit state
    /// @return claimableDepositValue Assets in claimable deposit state
    function getAsyncStateBreakdown(
        address yieldSourceAddress,
        address owner
    )
        public
        view
        returns (
            uint256 heldValue,
            uint256 pendingRedeemValue,
            uint256 claimableRedeemValue,
            uint256 pendingDepositValue,
            uint256 claimableDepositValue
        )
    {
        IERC7540 vault = IERC7540(yieldSourceAddress);
        address shareToken = vault.share();

        // Component 1: Held shares value
        uint256 heldShares = IERC20(shareToken).balanceOf(owner);
        if (heldShares > 0) {
            heldValue = vault.convertToAssets(heldShares);
        }

        // Component 2: Pending redeem value (shares → assets via convertToAssets)
        try vault.pendingRedeemRequest(REQUEST_ID, owner) returns (uint256 pendingShares) {
            if (pendingShares > 0) {
                pendingRedeemValue = vault.convertToAssets(pendingShares);
            }
        } catch { }

        // Component 3: Claimable redeem value (uses maxWithdraw — handles locked redeemPrice)
        try vault.maxWithdraw(owner) returns (uint256 withdrawable) {
            claimableRedeemValue = withdrawable;
        } catch { }

        // Component 4: Pending deposit value (already in assets)
        try vault.pendingDepositRequest(REQUEST_ID, owner) returns (uint256 pendingAssets) {
            pendingDepositValue = pendingAssets;
        } catch { }

        // Component 5: Claimable deposit value (already in assets)
        try vault.claimableDepositRequest(REQUEST_ID, owner) returns (uint256 claimableAssets) {
            claimableDepositValue = claimableAssets;
        } catch { }
    }
}
```

### Phase 2: Mock Vault for Testing

**Create `test/mocks/MockERC7540Vault.sol`**

A comprehensive mock implementing the standard ERC-7540 interface with:
- `share()` returning a separate ERC-20 token
- `pendingRedeemRequest(requestId, controller)` / `claimableRedeemRequest(requestId, controller)`
- `pendingDepositRequest(requestId, controller)` / `claimableDepositRequest(requestId, controller)`
- `maxWithdraw(controller)`, `convertToAssets(shares)`, `convertToShares(assets)`
- Settable state variables for each component (setter functions for test control)
- Epoch-based fulfillment simulation (for Centrifuge-like behavior)

### Phase 3: Unit Tests

**Create `test/unit/accounting/ERC7540YieldSourceOracle.t.sol`**

Test categories:
1. **decimals**: Returns share token decimals via ERC-7575 share()
2. **getShareOutput**: Uses `convertToShares` (not `previewDeposit`)
3. **getWithdrawalShareOutput**: Manual inverse with Ceil rounding, zero assetsPerShare edge case
4. **getAssetOutput**: Uses `convertToAssets` (not `previewRedeem`)
5. **getPricePerShare**: Hard revert on failure, correct for various decimal counts
6. **getTVLByOwnerOfShares**: Sum of 5 components, each component independently tested
7. **getAsyncStateBreakdown**: Returns 5 individual components, try/catch graceful degradation
8. **Error handling**: R1 (hard revert) vs R2 (graceful degradation) boundary verification
9. **Edge cases**: Zero balances, all components zero, single component active, all components active
10. **Fuzz**: `getTVLByOwnerOfShares` with random component values, no overflow

### Phase 4: Invariant Tests

**Create `test/invariant/ERC7540OracleInvariant.t.sol`**

Handler contracts wrapping mock vaults:
- `VanillaHandler`: Standard 7540 lifecycle (request → pending → fulfill → claimable → claim)
- `CentrifugeHandler`: Epoch-based fulfillment with locked redeemPrice
- Ghost variables tracking expected state per component

Key invariants:
- **INV-1**: `TVL >= maxWithdraw(owner)` — TVL always at least the claimable value
- **INV-2**: Sum of per-controller TVLs <= vault `totalAssets()` — no over-attribution
- **INV-3**: State transitions preserve value (round-trip within rounding tolerance)
- **INV-4**: Held + pending + claimable pools mutually exclusive — no double-count
- **INV-5**: `claimableRedeemValue == maxWithdraw(owner)` exactly
- **INV-7**: Graceful degradation — selectively reverting methods don't revert entire TVL call

### Phase 5: Fork Integration Tests

**Create `test/integration/accounting/ERC7540OracleIntegration.t.sol`**

- Fork Ethereum mainnet at pinned block (using `CHAIN_1_CENTRIFUGE_USDC` from existing tests)
- Test against real Centrifuge vault:
  - `getPricePerShare` returns non-zero value
  - `getTVLByOwnerOfShares` for an account with known position
  - `getAsyncStateBreakdown` returns consistent values
  - `decimals` matches expected share token decimals

## Files Summary

### Create
| File | Purpose |
|------|---------|
| `src/accounting/oracles/ERC7540YieldSourceOracle.sol` | Production oracle |
| `test/mocks/MockERC7540Vault.sol` | Comprehensive mock vault |
| `test/unit/accounting/ERC7540YieldSourceOracle.t.sol` | Unit tests |
| `test/invariant/ERC7540OracleInvariant.t.sol` | Invariant tests with handlers |
| `test/integration/accounting/ERC7540OracleIntegration.t.sol` | Fork integration tests |

### Modify
| File | Change |
|------|--------|
| None | No modifications to existing files needed |

### Unchanged
| File | Reason |
|------|--------|
| `AbstractYieldSourceOracle.sol` | Base class unchanged |
| `YoYieldSourceOracle.sol` | Continues for Yo vaults (different interface) |
| `ERC4626YieldSourceOracle.sol` | Continues for sync 4626 vaults |
| `SuperVaultYieldSourceOracle.sol` | Continues for SuperVaults |

## Dependencies & Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Vault non-compliance with 7540 spec | Medium | Per-vault validation at onboarding |
| Fee overstatement (convertToAssets excludes fees) | Low | Bounded by exit fee (0-0.5%) |
| MEV via PPS cadence mismatch | Low | Asymmetric pricing (deferred follow-up) |
| Centrifuge redeemPrice mismatch | High | Solved: use maxWithdraw (D1) |
| Double-count on fulfillment | Medium | INV-4 invariant, per-vault verification |
| Cancel-in-flight TVL undercount | Low | Brief transient window, documented limitation |

## Future Considerations

1. **Asymmetric pricing (bid/ask spread)**: Apply haircut on deposit PPS, premium on withdrawal PPS — deferred to follow-up (D6)
2. **`getAsyncStateBreakdown` in IYieldSourceOracle**: Consider adding to base interface for monitoring system access without casting
3. **Multi-keeper quorum**: Require 2+ keepers to agree on PPS before pushing
4. **On-chain PPS bounds**: Reject PPS changes > threshold in SuperVaultAggregator

## References & Research

### Internal References
- `src/accounting/oracles/AbstractYieldSourceOracle.sol` — base class (7 abstract methods)
- `src/accounting/oracles/YoYieldSourceOracle.sol` — reference with pending tracking (2 components)
- `src/accounting/oracles/ERC4626YieldSourceOracle.sol` — simplest oracle (held-only)
- `src/accounting/oracles/SuperVaultYieldSourceOracle.sol` — async redeem oracle (manual inverse)
- `src/vendor/vaults/7540/IERC7540.sol` — vendor interface (IERC7575 + 7540 extensions)
- `src/accounting/BaseLedger.sol:262-304` — `_updateAccounting` (calls PPS + decimals only)
- `test/utils/Constants.sol:144` — `ERC7540_YIELD_SOURCE_ORACLE_KEY` already exists

### External References
- [ERC-7540 Official EIP](https://eips.ethereum.org/EIPS/eip-7540)
- [ERC-7575 Official EIP](https://eips.ethereum.org/EIPS/eip-7575)
- [Centrifuge Liquidity Pools](https://github.com/centrifuge/liquidity-pools)
- [Recon-Fuzz ERC-7540 Properties](https://github.com/Recon-Fuzz/erc7540-reusable-properties)

### Security References
- [research/evm-security.md](./research/evm-security.md) — full vulnerability analysis
- [research/best-practices.md](./research/best-practices.md) — ERC-7540 standard analysis
- vulnerabilities.md Sections 1 (reentrancy), 4 (oracle), 10 (token), 22 (vault accounting), 28 (donation)
