# YoYieldSourceOracle Specification

**Feature:** Oracle for Yo Vaults with async redemption support
**Pod:** Superform Engineering
**Date:** 2026-02-23
**Status:** Ready for Review

---

## Summary

Create `YoYieldSourceOracle` to correctly value SuperVault positions in Yo Vaults (yoETH, yoUSDC). Unlike standard ERC-4626 vaults, Yo Vaults support async redemptions where shares are burned but assets are not immediately received. This oracle adds pending redemption value to ensure accurate PPS calculations.

---

## Problem

When a SuperVault calls `requestRedeem()` on a Yo Vault:
1. yoToken shares are burned immediately
2. Underlying assets are NOT received until fulfillment
3. Using only `balanceOf × PPS` would show a sudden drop in position value
4. This creates artificial PPS discontinuity for SuperVault depositors

---

## Solution

**Valuation Formula:**
```
yo_position_value = held_value + pending_value
```

Where:
- `held_value` = `yoVault.convertToAssets(yoVault.balanceOf(owner))`
- `pending_value` = `yoVault.pendingRedeemRequest(owner).assets`

This ensures smooth transitions during async redemption cycles.

---

## Key Implementation Details

### Interface Requirement
Yo Vaults must expose:
```solidity
function pendingRedeemRequest(address owner)
    external view returns (uint256 assets, uint256 shares);
```

This differs from standard ERC-7540 which uses request IDs.

### Core Method Override
The `getTVLByOwnerOfShares()` method is the key change:
```solidity
function getTVLByOwnerOfShares(
    address yieldSourceAddress,
    address ownerOfShares
) public view override returns (uint256) {
    IYoVault vault = IYoVault(yieldSourceAddress);

    // Held shares value
    uint256 heldShares = vault.balanceOf(ownerOfShares);
    uint256 heldValue = heldShares > 0 ? vault.convertToAssets(heldShares) : 0;

    // Pending async redemption value
    (uint256 pendingAssets, ) = vault.pendingRedeemRequest(ownerOfShares);

    return heldValue + pendingAssets;
}
```

---

## Scope

### In Scope
- `YoYieldSourceOracle` contract inheriting `AbstractYieldSourceOracle`
- `IYoVault` interface definition
- Unit tests for all state transitions
- Deployment script following existing patterns
- Mock contract for testing

### Out of Scope
- Cross-asset conversion (handled by existing SV oracle infrastructure)
- Yo Vault implementation changes
- Hook implementations for Yo Vault deposits/redeems

---

## Target Vaults

| SuperVault | Yo Vault | Underlying |
|------------|----------|------------|
| SuperWETH | yoETH | WETH |
| SuperUSDC | yoUSDC | USDC |

---

## State Transitions (PPS Stability)

| Action | PPS Change |
|--------|------------|
| Normal hold | Stable |
| Sync redeem | Stable |
| Request async redeem | Stable |
| Fulfill async redeem | Stable |
| Partial fulfillment | Stable |
| Multiple requests | Stable |

---

## Files to Create

```
src/interfaces/vendor/IYoVault.sol          # Interface
src/accounting/oracles/YoYieldSourceOracle.sol  # Oracle
test/unit/accounting/YoYieldSourceOracle.t.sol  # Tests
test/mocks/MockYoVault.sol                  # Mock
script/DeployYoYieldSourceOracle.s.sol      # Deploy
```

---

## Open Questions

1. Confirm `pendingRedeemRequest(owner)` returns `(uint256 assets, uint256 shares)`
2. Confirm yoETH uses 18 decimals, yoUSDC uses 6 decimals
3. Need production addresses for yoETH and yoUSDC vaults

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Yo Vault upgrade changes interface | Medium | Monitor proxy admin |
| PPS manipulation via flash loan | Low | Same risk as other oracles |
| Atomicity assumption violated | Very Low | Solidity TX guarantees |

---

## References

- [Interview Notes](./interview-notes.md)
- [Technical Specification](./technical-spec.md)
- [AbstractYieldSourceOracle](../../src/accounting/oracles/AbstractYieldSourceOracle.sol)
- [ERC4626YieldSourceOracle](../../src/accounting/oracles/ERC4626YieldSourceOracle.sol)
- [SuperVaultYieldSourceOracle](../../src/accounting/oracles/SuperVaultYieldSourceOracle.sol)
