# YoYieldSourceOracle Technical Specification

**Version:** 1.0
**Date:** 2026-02-23
**Author:** Superform Engineering

---

## 1. Overview

### 1.1 Purpose
Create `YoYieldSourceOracle` - a specialized oracle for Yo Vaults that support async redemption. This oracle extends `AbstractYieldSourceOracle` to correctly value SuperVault positions in Yo Vaults by accounting for both held shares and pending async redemption requests.

### 1.2 Problem Statement
Standard ERC-4626 oracles cannot accurately value Yo Vault positions because:
1. Yo Vaults use async redemptions - when `requestRedeem()` is called, shares are burned but assets are not immediately received
2. During the async redemption window, using only `balanceOf * convertToAssets` would undervalue the position
3. The pending redemption value must be included to maintain accurate PPS calculations

### 1.3 Target Use Cases
- **SuperWETH** holding yoETH positions
- **SuperUSDC** holding yoUSDC positions

---

## 2. Valuation Formula

### 2.1 Core Formula
```
yo_position_value = held_value + pending_value
```

Where:
- `held_value = yoVault.convertToAssets(yoVault.balanceOf(owner))`
- `pending_value = yoVault.pendingRedeemRequest(owner).assets`

### 2.2 Component Sources

| Component | Function Call | Returns |
|-----------|---------------|---------|
| `yoShares_held` | `yoVault.balanceOf(owner)` | Current yoToken balance |
| `held_value` | `yoVault.convertToAssets(yoShares_held)` | Asset value of held shares |
| `pending_assets` | `yoVault.pendingRedeemRequest(owner).assets` | Assets owed from async redeems |

**Important:** Both `held_value` and `pending_value` are denominated in the Yo Vault's underlying asset.

---

## 3. Interface Requirements

### 3.1 IYoVault Interface

The oracle requires the following interface from Yo Vaults:

```solidity
interface IYoVault {
    /// @notice Returns the share token balance of an account
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the number of decimals of the share token
    function decimals() external view returns (uint8);

    /// @notice Converts shares to assets at current exchange rate
    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    /// @notice Converts assets to shares at current exchange rate
    function convertToShares(uint256 assets) external view returns (uint256 shares);

    /// @notice Returns pending redeem request for an owner
    /// @dev Returns accumulated pending assets and shares across all requests
    /// @param owner The address to check pending requests for
    /// @return assets The total pending assets to be received
    /// @return shares The total pending shares (burned but not yet fulfilled)
    function pendingRedeemRequest(address owner) external view returns (uint256 assets, uint256 shares);

    /// @notice Returns total assets managed by the vault
    function totalAssets() external view returns (uint256);

    /// @notice Preview deposit assets to shares conversion
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
}
```

### 3.2 Key Interface Differences from ERC-7540

| Standard ERC-7540 | Yo Vault |
|-------------------|----------|
| `pendingRedeemRequest(requestId, controller)` returns `uint256 pendingShares` | `pendingRedeemRequest(owner)` returns `(uint256 assets, uint256 shares)` |
| Uses request IDs | Address-based accumulator |
| Returns shares only | Returns both assets and shares |

---

## 4. Contract Implementation

### 4.1 Contract Structure

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IYoVault } from "../../interfaces/vendor/IYoVault.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title YoYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Yo Vaults with async redemption support
/// @dev Accounts for both held shares and pending async redemption requests
///      Total position value = held_value + pending_value
contract YoYieldSourceOracle is AbstractYieldSourceOracle {
    constructor(address superLedgerConfiguration_)
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {}
}
```

### 4.2 Method Implementations

#### 4.2.1 `decimals`
```solidity
function decimals(address yieldSourceAddress) external view override returns (uint8) {
    return IYoVault(yieldSourceAddress).decimals();
}
```

#### 4.2.2 `getShareOutput` (for deposits)
```solidity
function getShareOutput(
    address yieldSourceAddress,
    address,
    uint256 assetsIn
) external view override returns (uint256) {
    return IYoVault(yieldSourceAddress).previewDeposit(assetsIn);
}
```

#### 4.2.3 `getWithdrawalShareOutput`
```solidity
function getWithdrawalShareOutput(
    address yieldSourceAddress,
    address,
    uint256 assetsIn
) external view override returns (uint256) {
    IYoVault vault = IYoVault(yieldSourceAddress);
    uint256 shareDecimals = vault.decimals();
    uint256 oneShare = 10 ** shareDecimals;

    uint256 assetsPerShare = vault.convertToAssets(oneShare);
    if (assetsPerShare == 0) return 0;

    return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
}
```

#### 4.2.4 `getAssetOutput` (for redemptions)
```solidity
function getAssetOutput(
    address yieldSourceAddress,
    address,
    uint256 sharesIn
) public view override returns (uint256) {
    return IYoVault(yieldSourceAddress).convertToAssets(sharesIn);
}
```

#### 4.2.5 `getPricePerShare`
```solidity
function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
    IYoVault vault = IYoVault(yieldSourceAddress);
    uint256 _decimals = vault.decimals();
    return vault.convertToAssets(10 ** _decimals);
}
```

#### 4.2.6 `getBalanceOfOwner`
Standard balance - does NOT include pending redemptions:
```solidity
function getBalanceOfOwner(
    address yieldSourceAddress,
    address ownerOfShares
) public view override returns (uint256) {
    return IYoVault(yieldSourceAddress).balanceOf(ownerOfShares);
}
```

#### 4.2.7 `getTVLByOwnerOfShares` (THE KEY METHOD)
This is where the async redemption logic applies:
```solidity
function getTVLByOwnerOfShares(
    address yieldSourceAddress,
    address ownerOfShares
) public view override returns (uint256) {
    IYoVault vault = IYoVault(yieldSourceAddress);

    // Component 1: Value of held shares
    uint256 heldShares = vault.balanceOf(ownerOfShares);
    uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;

    // Component 2: Value of pending async redemptions
    (uint256 pendingAssets, ) = vault.pendingRedeemRequest(ownerOfShares);

    // Total position value
    return heldValue + pendingAssets;
}
```

#### 4.2.8 `getTVL`
```solidity
function getTVL(address yieldSourceAddress) public view override returns (uint256) {
    return IYoVault(yieldSourceAddress).totalAssets();
}
```

---

## 5. State Transition Analysis

### 5.1 Steady State (No Pending Redeems)
```
State:  SV holds N yoShares, no pending requests
Value:  N × yo_PPS + 0 = N × yo_PPS
```
Standard ERC-4626 behavior. `pendingRedeemRequest().assets = 0`.

### 5.2 Sync Redeem (Sufficient Liquidity)
```
Before: SV holds N yoShares, liquid_assets = L
TX:     SV calls redeem(X shares) → succeeds, receives Y underlying
After:  SV holds (N-X) yoShares, liquid_assets = L + Y

Value before: N × yo_PPS + 0 + L
Value after:  (N-X) × yo_PPS + 0 + (L + Y)
```
**Net change: zero** (since `Y = X × yo_PPS`).

### 5.3 Async Redeem - Request Phase
```
Before: SV holds N yoShares, pendingRedeemRequest().assets = 0
TX:     SV calls requestRedeem(X shares) → shares burned, request queued
After:  SV holds (N-X) yoShares, pendingRedeemRequest().assets = Y

Value before: N × yo_PPS + 0
Value after:  (N-X) × yo_PPS + Y
```
**Net change: zero** (since `Y = X × yo_PPS` at request time). No PPS discontinuity.

### 5.4 Async Redeem - Fulfillment Phase
```
Before: SV holds M yoShares, pendingRedeemRequest().assets = Y, liquid_assets = L
TX:     Yo keeper calls fulfillRedeem() → Y assets pushed to SV
After:  SV holds M yoShares, pendingRedeemRequest().assets = 0, liquid_assets = L + Y

Value before: M × yo_PPS + Y + L
Value after:  M × yo_PPS + 0 + (L + Y)
```
**Net change: zero**.

### 5.5 Multiple Requests Before Fulfillment
```
TX1:    requestRedeem(X1) → burns X1 shares, pending += Y1
TX2:    requestRedeem(X2) → burns X2 shares, pending += Y2

pendingRedeemRequest().assets = Y1 + Y2  (single accumulated slot)
```
The oracle reads the aggregate. No per-request tracking needed.

---

## 6. Deployment Configuration

### 6.1 Constructor Parameters
| Parameter | Type | Description |
|-----------|------|-------------|
| `superLedgerConfiguration_` | `address` | Address of SuperLedgerConfiguration contract |

### 6.2 Deployment Script
File: `script/DeployYoYieldSourceOracle.s.sol`
- Follows existing oracle deployment patterns
- Uses deterministic deployment via `DeterministicDeployerLib`
- Writes to `{ChainName}-latest.json`

### 6.3 Target Chains
Initial deployment on chains where SuperWETH/SuperUSDC hold Yo Vault positions.

---

## 7. Testing Requirements

### 7.1 Unit Tests

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| T1 | SV holds yoShares, no pending redeems | `TVL = balanceOf × PPS` |
| T2 | SV calls `redeem()` (sync path) | PPS unchanged before/after |
| T3 | SV calls `requestRedeem()` (async path) | PPS unchanged before/after |
| T4 | Yo keeper calls `fulfillRedeem()` | PPS unchanged before/after |
| T5 | Partial fulfillment | PPS unchanged; pending decreases, liquid increases |
| T6 | Multiple `requestRedeem()` before fulfillment | `pendingRedeemRequest().assets` reflects cumulative |
| T7 | `cancelRedeem()` called | Shares restored; PPS stable |

### 7.2 Integration Tests
- Cross-asset SV (e.g., SuperUSDC with yoETH) - verify conversion rate correctly applied
- Yo Vault PPS changes between oracle reads - `held_value` reflects new PPS; `pending_value` fixed

### 7.3 Mock Contracts
Create `MockYoVault` implementing `IYoVault` for testing:
- Configurable `pendingRedeemRequest()` return values
- Simulated async redemption flow

---

## 8. Risk Analysis

### 8.1 Atomicity Violation
**Risk:** If `fulfillRedeem()` is not fully atomic, there's a window where pending is zeroed but transfer hasn't completed.
**Mitigation:** Solidity TX atomicity ensures this doesn't happen.

### 8.2 PPS Manipulation
**Risk:** Flash loan attacks affecting `convertToAssets()`.
**Mitigation:** Same risk class as other ERC-4626 oracles. Existing sanity checks apply.

### 8.3 Exchange Rate Drift
**Risk:** If rate is locked at request time, pending value may diverge from current rate.
**Status:** Not a bug - correct economic representation of locked rate.

### 8.4 Contract Upgrade
**Risk:** If Yo Vault upgrades and `pendingRedeemRequest()` interface changes, oracle breaks.
**Mitigation:** Monitor proxy admin for upgrades.

---

## 9. Open Questions (Require Clarification)

1. **Interface Confirmation:** Verify exact function signature for `pendingRedeemRequest()` - does it return `(uint256 assets, uint256 shares)` as documented?

2. **Request ID Pattern:** Does Yo use request IDs like ERC-7540, or is it address-based accumulator only?

3. **Decimal Handling:** Confirm yoTokens use standard decimals (18 for yoETH, 6 for yoUSDC).

4. **Yo Vault Addresses:** Need production addresses for yoETH and yoUSDC vaults.

---

## 10. File Structure

```
src/
├── accounting/oracles/
│   └── YoYieldSourceOracle.sol       # Main oracle contract
├── interfaces/vendor/
│   └── IYoVault.sol                  # Yo Vault interface
test/
├── unit/accounting/
│   └── YoYieldSourceOracle.t.sol     # Unit tests
├── mocks/
│   └── MockYoVault.sol               # Mock for testing
script/
└── DeployYoYieldSourceOracle.s.sol   # Deployment script
```

---

## 11. Implementation Checklist

- [ ] Create `IYoVault` interface in `src/interfaces/vendor/`
- [ ] Implement `YoYieldSourceOracle` contract
- [ ] Create `MockYoVault` for testing
- [ ] Write unit tests covering all state transitions
- [ ] Create deployment script following existing patterns
- [ ] Add to verification script
- [ ] Deploy to staging for testing
- [ ] Production deployment after validation
