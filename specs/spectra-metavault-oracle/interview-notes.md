# SpectraMetaVaultOracle Interview Notes

## Date: 2026-05-28

## Context

The Spectra MetaVault at `0x6420a613e936602ca3f1ad5680b3f4d47d473bf1` on Base is a MetaVaultWrapper (UUPS proxy, impl `0x9bae29812bbc7ad442f49b180d0eb7c5bf107afe`) over an Amphor AsyncVault (infra vault at `0x2154a519d08bfd3f6e0303fd3ac0511c58424bbe`). It's a full EIP-7540 async vault (async both deposit and redeem). Asset is USDC (6 decimals).

## Problem Statement

The generic `ERC7540YieldSourceOracle` has two bugs when used with Spectra MetaVaultWrapper:

### Bug 1: getTVL() returns 0
- MetaVaultWrapper does NOT override `totalAssets()` from OZ ERC4626Upgradeable
- OZ default: `totalAssets() = asset.balanceOf(address(this))` = idle USDC in the vault
- Currently returns 0 because all assets are deployed to the infra vault
- Our oracle's `getTVL()` calls `totalAssets()` directly → returns 0

### Bug 2: maxWithdraw uses wrong pricing function (double-counting / meaningless value)
- MetaVaultWrapper does NOT override `maxWithdraw()` from OZ ERC4626Upgradeable
- OZ default: `maxWithdraw(owner) = _convertToAssets(balanceOf(owner), Floor)`
- `_convertToAssets` uses `totalAssets()/totalSupply()` (idle USDC ratio)
- BUT MetaVaultWrapper DOES override `convertToAssets()` to use epoch snapshot rate
- So `maxWithdraw` and `convertToAssets` use DIFFERENT pricing
- Component 3 (`maxWithdraw`) in getTVLByOwnerOfShares returns a meaningless value based on idle USDC, not epoch NAV

### On-chain verified data:
- `totalAssets() = 0` (idle USDC)
- `totalSupply = 513917`
- `convertToAssets(1e6) = 863399` (epoch 5 snapshot rate, ~0.863 USDC/share)
- `convertToAssets(1e6, epoch=6) = 0` (current epoch unsettled)
- `share()` reverts (not implemented)
- `previewDeposit/previewRedeem` revert with `NotImplemented()`
- `maxDeposit/maxRedeem/maxWithdraw` return 0 during unsettled epoch
- `epochId = 6`, `requestId` always 0 (accumulated pattern)
- PPS is lagged to last settled epoch (lock-at-fulfillment, Centrifuge-V3 family)

## Technical Decisions

### Q: Oracle scope?
**A: Spectra-specific.** Tailored to MetaVaultWrapper behavior. Can encode Spectra-specific assumptions (epoch snapshots, infra vault, etc). Simpler than a generic approach.

### Q: getTVL fix?
**A: `convertToAssets(totalSupply)`.** Uses the overridden convertToAssets with totalSupply. Simple, uses epoch snapshot rate. May not include pending deposits/redeems sitting as idle USDC, but acceptable.

### Q: PPS guards?
**A: No guards in oracle.** Oracle is a pure read layer. PPS trust is an operational concern handled via monitoring/alerting, not oracle code.

### Q: Share token discovery?
**A: Inherit fallback.** Keep the `try share() catch { return vault }` pattern from ERC7540YieldSourceOracle. Works for MetaVaultWrapper since `share()` reverts and vault IS the share token.

### Q: Error handling for claimableRedeemRequest?
**A: try/catch (graceful degradation).** Consistent with the generic oracle's R2 strategy. If claimableRedeemRequest reverts, component = 0.

### Q: Pending redeem component?
**A: Keep as-is.** `convertToAssets(pendingShares)` already uses the epoch snapshot rate via the overridden `convertToAssets`. No change needed.

### Q: File location?
**A: `src/accounting/oracles/SpectraMetaVaultOracle.sol`** — same directory as ERC7540YieldSourceOracle.sol.

### Q: Read-only reentrancy?
**A: Not a concern.** Oracle is pure view. MetaVaultWrapper state is only modified during user-initiated operations.

### Q: UUPS upgrade risk?
**A: Accept the risk.** Same risk exists for every external vault integration. Not unique to this oracle.

### Q: Multiple vaults?
**A: Multiple vaults expected.** Spectra will deploy more MetaVaults with the same wrapper pattern. Oracle should work for any MetaVaultWrapper instance.

## Acceptance Criteria

- [ ] `getPricePerShare()` returns correct epoch snapshot rate via `convertToAssets(10^decimals)`
- [ ] `getTVL()` returns `convertToAssets(totalSupply())` instead of `totalAssets()`
- [ ] `getTVLByOwnerOfShares()` Component 3 uses `claimableRedeemRequest(0, owner)` → `convertToAssets(claimableShares)` instead of `maxWithdraw(owner)`
- [ ] All other components (1, 2, 4, 5) behave identically to ERC7540YieldSourceOracle
- [ ] `share()` fallback to vault address works when `share()` reverts
- [ ] All async components wrapped in try/catch for graceful degradation (R2)
- [ ] Works for any MetaVaultWrapper instance, not hardcoded to a specific address
- [ ] Unit tests covering all 5 TVL components
- [ ] Unit test verifying getTVL uses convertToAssets(totalSupply) not totalAssets
- [ ] Fork test against live Base MetaVault at 0x6420
- [ ] Bytecode generated and locked

## Testing Strategy

- **Unit tests**: Mock MetaVaultWrapper with divergent `totalAssets()` vs `convertToAssets(totalSupply())`, verify oracle uses the correct one. Mock `maxWithdraw` returning wrong value, verify oracle doesn't use it.
- **Fork tests**: Against live 0x6420 on Base, verify getTVL > 0, verify no double-counting.
- **Edge cases**: Zero balances, zero totalSupply, reverts from claimableRedeemRequest.
