---
title: YoYieldSourceOracle - Async Redemption Oracle Pattern
category: new-feature
date: 2026-02-23
spec: /specs/yo-oracle/spec.md
components: [YoYieldSourceOracle, IYoVault, MockYoVault]
tags: [oracle, async-redemption, yo-vault, pps-stability, erc7540-alternative]
---

# YoYieldSourceOracle - Async Redemption Oracle Pattern

## Summary

Implemented `YoYieldSourceOracle` - an oracle for Yo Vaults with async redemption support. The key innovation is the `getTVLByOwnerOfShares()` method that includes **both** held shares value **AND** pending async redemption value. This ensures PPS stability during async redemption cycles where shares are burned but assets haven't been received yet.

Unlike ERC-7540 which uses request IDs, Yo Vaults use an address-based accumulator pattern where `pendingRedeemRequest(owner)` returns total pending `(assets, shares)` for an address.

## Implementation Details

### Key Decisions

**1. Interface Design (IYoVault)**

Yo Vaults differ from ERC-7540 in their pending request tracking:
- ERC-7540: `pendingRedeemRequest(requestId, controller)` - request ID based
- Yo Vault: `pendingRedeemRequest(owner)` - address-based accumulator

```solidity
// src/vendor/yo/IYoVault.sol
function pendingRedeemRequest(address owner) external view returns (uint256 assets, uint256 shares);
```

This returns the **accumulated** pending assets and shares across all requests for an owner.

**2. PPS Stability Formula**

The critical insight is that during async redemption:
1. User requests redeem → shares are burned
2. Request is pending → user has neither shares nor assets in wallet
3. Without accounting for pending, PPS would spike artificially

Solution:
```
yo_position_value = held_value + pending_value
                  = convertToAssets(balanceOf(owner)) + pendingAssets
```

**3. Minimal Interface**

Only exposed the methods actually needed by the oracle, keeping the interface focused:
- `balanceOf`, `decimals` - standard ERC20
- `convertToAssets`, `convertToShares` - price conversion
- `pendingRedeemRequest` - async redemption tracking
- `totalAssets`, `previewDeposit` - vault operations

### Code Examples

**Core TVL Calculation:**
```solidity
// src/accounting/oracles/YoYieldSourceOracle.sol:116-136
function getTVLByOwnerOfShares(
    address yieldSourceAddress,
    address ownerOfShares
) public view override returns (uint256) {
    IYoVault vault = IYoVault(yieldSourceAddress);

    // Component 1: Value of held shares
    uint256 heldShares = vault.balanceOf(ownerOfShares);
    uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;

    // Component 2: Value of pending async redemptions
    (uint256 pendingAssets,) = vault.pendingRedeemRequest(ownerOfShares);

    // Total position value
    return heldValue + pendingAssets;
}
```

**Withdrawal Share Calculation (Ceil Rounding):**
```solidity
// Favor the vault by rounding up shares required
return Math.mulDiv(assetsIn, oneShare, assetsPerShare, Math.Rounding.Ceil);
```

### Patterns to Reuse

**1. Interface Override Conflict Resolution**

When a mock inherits both ERC20 and a custom interface with `balanceOf`:
```solidity
function balanceOf(address account) public view override(ERC20, IYoVault) returns (uint256) {
    return super.balanceOf(account);
}
```

**2. Mock Testing Helpers**

Add direct state manipulation helpers for clean tests:
```solidity
function setPendingRedeemRequest(address owner, uint256 assets_, uint256 shares_) external {
    pendingAssets[owner] = assets_;
    pendingShares[owner] = shares_;
}

function setTotalAssets(uint256 amount) external {
    _totalAssets = amount;
}
```

This avoids complex test setup with token approvals just to set state.

## Testing Strategy

### Unit Tests (25 tests)

**Categories:**
1. `decimals()` - Share token decimals
2. `getShareOutput()` - Deposit preview
3. `getWithdrawalShareOutput()` - Withdraw share calculation with ceil rounding
4. `getAssetOutput()` - Redeem preview
5. `getPricePerShare()` - One-share asset value
6. `getBalanceOfOwner()` - Share balance (excludes pending)
7. `getTVLByOwnerOfShares()` - **Critical** - includes pending
8. `getTVL()` - Total vault assets

**Critical PPS Stability Tests:**
```solidity
function test_getTVLByOwnerOfShares_ppsStabilityOnRequest() public {
    // Setup: user has 100e18 shares at 1.1 PPS = 110e18 assets
    // Action: simulate async redeem request (burns shares, creates pending)
    // Assert: TVL remains 110e18 (pending_assets, not held_value)
}

function test_getTVLByOwnerOfShares_ppsStabilityOnFulfill() public {
    // Setup: user has pending redemption
    // Action: fulfill redemption (pending cleared, assets transferred)
    // Assert: TVL now comes from balanceOf (no longer pending)
}
```

**Edge Cases:**
- Zero balances
- Zero pending
- Different decimal tokens (6, 8, 18)
- Large values (1e30)
- Price appreciation scenarios

### Integration Testing (Future)

Verify against actual Yo Vault deployment:
1. Check `pendingRedeemRequest` return format matches
2. Validate conversion functions match expected behavior
3. Test full async redemption cycle

## Prevention & Best Practices

### Interface Design
- **Verify actual contract interface** before finalizing - Yo Vault uses address-based accumulator, not ERC-7540 request IDs
- Keep interfaces minimal - only expose what the oracle actually needs

### Testing Mocks
- Add direct state setters (`setTotalAssets`, `setPendingRedeemRequest`) to avoid complex setup
- Handle Solidity override conflicts explicitly with `override(A, B)` syntax

### Oracle Implementation
- Always use `Math.Rounding.Ceil` for withdrawal calculations to favor the vault
- Check for zero values before division to prevent reverts
- Document the valuation formula clearly in NatSpec

## Related Documentation

- [AbstractYieldSourceOracle](../../../src/accounting/oracles/AbstractYieldSourceOracle.sol) - Base class pattern
- [ERC4626YieldSourceOracle](../../../src/accounting/oracles/ERC4626YieldSourceOracle.sol) - Similar implementation for standard vaults
- [ERC7540YieldSourceOracle](../../../src/accounting/oracles/ERC7540YieldSourceOracle.sol) - Different async pattern (request ID based)
- [Technical Spec](./technical-spec.md) - Original implementation requirements
