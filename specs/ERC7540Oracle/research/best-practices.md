# ERC-7540 Oracle Best Practices Research

## Date: 2026-04-29

---

## 1. ERC-7540 Standard Interface Signatures

### Core View Functions

```solidity
function pendingRedeemRequest(uint256 requestId, address controller) external view returns (uint256 pendingShares);
function claimableRedeemRequest(uint256 requestId, address controller) external view returns (uint256 claimableShares);
function pendingDepositRequest(uint256 requestId, address controller) external view returns (uint256 pendingAssets);
function claimableDepositRequest(uint256 requestId, address controller) external view returns (uint256 claimableAssets);
```

### RequestId Patterns

- **requestId == 0 (Accumulated Pattern)**: Vault uses controller address to discriminate state. Multiple requests aggregated. Most common pattern — spec was "written primarily with those use cases in mind."
- **requestId != 0 (Per-Request Pattern)**: Requests of same requestId MUST be fungible, transition to Claimable simultaneously with identical exchange rates. Epoch-based vaults.

### Mutual Exclusivity Guarantees

The spec is explicit:
- `pendingDepositRequest` "MUST NOT include any assets in Claimable state"
- `claimableDepositRequest` "MUST NOT include any assets in Pending state"
- Same for redeem requests

**Simple addition of all components is correct** — no double-count in compliant vaults.

### previewRedeem MUST Revert

"previewRedeem/previewWithdraw MUST revert for all callers and inputs" when vault implements async redemption. **Never call these on a 7540 vault.**

### Error Handling

View functions (pending/claimable): "MUST NOT revert unless due to integer overflow caused by an unreasonably large input." But non-compliant vaults may revert — wrap in try/catch.

## 2. Centrifuge V3 Implementation

### redeemPrice Tracking

Centrifuge uses `LPValues` struct per user per vault:

```solidity
struct LPValues {
    uint128 maxDeposit;    // denominated in currency
    uint128 maxMint;       // denominated in tranche tokens
    uint128 maxWithdraw;   // denominated in currency
    uint128 maxRedeem;     // denominated in tranche tokens
}
```

On fulfillment (`handleExecutedCollectRedeem`):
```solidity
lpValues.maxWithdraw = lpValues.maxWithdraw + currencyPayout;
lpValues.maxRedeem = lpValues.maxRedeem + trancheTokensPayout;
```

Redemption price = weighted average across multiple epoch fulfillments.

### maxWithdraw IS the Correct Method

`maxWithdraw` returns exact currency payout locked at epoch execution. More reliable than `convertToAssets(claimableShares)` because exchange rate at fulfillment may differ from current rate.

### claimableRedeemRequest == maxRedeem

In Centrifuge: `claimableRedeemRequest(_, controller)` literally delegates to `maxRedeem(controller)`.

### ERC-7575 share() Token

7540 MUST implement ERC-7575 — share token is separate ERC-20. Use `vault.share()` to get it.

### Gotchas

1. Price CAN change between Pending and Claimed
2. Shares burned at request time — leave `balanceOf()` immediately
3. Multiple fulfillment accumulation — maxWithdraw/maxRedeem are weighted averages

## 3. Yo Vaults

### Non-Standard Interface

```solidity
// Standard: pendingRedeemRequest(uint256 requestId, address controller) returns (uint256 shares)
// Yo:       pendingRedeemRequest(address owner) returns (uint256 assets, uint256 shares)
```

No requestId, returns `(assets, shares)` tuple, assets fixed at request time.

### Rate Locking

Assets locked at request time — provides TVL stability during async period. Different from standard 7540 which only returns shares.

### Hybrid Sync/Async

Immediate redemption if liquidity sufficient, else stored for later fulfillment.

## 4. Oracle Best Practices

### Five-Component Formula

```
TVL = heldValue + pendingRedeemValue + claimableRedeemValue + pendingDepositValue + claimableDepositValue
```

| Component | Source | Denomination | Conversion |
|-----------|--------|-------------|------------|
| Held shares | `IERC20(vault.share()).balanceOf(owner)` | shares | `convertToAssets(shares)` |
| Pending redeem | `pendingRedeemRequest(0, owner)` | shares | `convertToAssets(shares)` |
| Claimable redeem | N/A | assets | `maxWithdraw(owner)` directly |
| Pending deposit | `pendingDepositRequest(0, owner)` | assets | Already in assets |
| Claimable deposit | `claimableDepositRequest(0, owner)` | assets | Already in assets |

### Defensive Pattern

Wrap optional calls in try/catch:
- Not all 7540 vaults implement both async deposit AND async redeem
- Some may revert on `pendingDepositRequest` if only async redeem supported
- `convertToAssets` "MUST NOT revert" per spec but non-compliant vaults may

### Zero-Check Optimization

Check `shares > 0` before calling `convertToAssets` to avoid wasted gas.

## 5. Fee Handling

### convertToAssets vs previewRedeem

| Function | Fee Inclusion | Revert on Async | Purpose |
|----------|--------------|-----------------|---------|
| `convertToAssets` | **Excludes fees** | MUST NOT revert | Ideal exchange rate |
| `previewRedeem` | **Includes fees** | MUST revert (7540) | Actual redemption simulation |

For 7540 oracle: `convertToAssets` is the ONLY option. Slightly optimistic for vaults with withdrawal fees (typically 0-0.5% for institutional vaults).

### Non-Compliance Patterns (2025 Audits)

- `convertToAssets` returning too many assets
- Incorrect rounding direction (should round DOWN)
- First-depositor inflation attacks
- Fee-on-transfer tokens breaking assumptions

## 6. Double-Count Prevention

### Lifecycle Mutual Exclusivity

```
[Held Shares] --requestRedeem--> [Pending Redeem] --fulfillment--> [Claimable Redeem] --claim--> [Assets]
  balanceOf()                    pendingRedeemRequest()             maxRedeem/maxWithdraw
```

Shares removed from `balanceOf` on `requestRedeem`. No overlap between pools in compliant vaults.

### Recon-Fuzz ERC-7540 Invariants

From https://github.com/Recon-Fuzz/erc7540-reusable-properties:
- **7540-1**: `convertToAssets(totalSupply) == totalAssets`
- **7540-3**: `max*` functions must never revert
- **7540-4**: Claiming beyond max must revert
- **7540-5**: `requestRedeem` reverts if shares > balance

## Summary: Must Have vs Recommended

### Must Have
1. Track all five pools
2. Use `share()` from ERC-7575 (separate token)
3. Use `requestId = 0` (accumulated pattern)
4. Never call `previewRedeem`/`previewWithdraw`
5. Use `convertToAssets` for pricing
6. Use `maxWithdraw` for claimable asset value

### Recommended
7. try/catch on optional calls
8. Zero-check before `convertToAssets`
9. Test against Centrifuge reference
10. Validate with Recon-Fuzz invariants

## Sources

- [ERC-7540 Official EIP](https://eips.ethereum.org/EIPS/eip-7540)
- [ERC-7575 Official EIP](https://eips.ethereum.org/EIPS/eip-7575)
- [Centrifuge Liquidity Pools](https://github.com/centrifuge/liquidity-pools)
- [Recon-Fuzz ERC-7540 Properties](https://github.com/Recon-Fuzz/erc7540-reusable-properties)
- [ERC-4626 Official EIP](https://eips.ethereum.org/EIPS/eip-4626)
- [OpenZeppelin ERC-4626 Docs](https://docs.openzeppelin.com/contracts/5.x/erc4626)
- [Zokyo: ERC-4626 Non-Compliance Risks](https://zokyo-auditing-tutorials.gitbook.io/zokyo-tutorials/tutorial-49)
- [ERC-7887: Cancellation for ERC-7540](https://eips.ethereum.org/EIPS/eip-7887)
