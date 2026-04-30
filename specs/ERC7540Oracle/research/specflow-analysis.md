# ERC7540YieldSourceOracle: SpecFlow Analysis

## Date: 2026-04-29

---

## Consumer Flows

### Flow A: On-Chain Accounting (BaseLedger)
```
Hook triggers updateAccounting()
  -> BaseLedger._updateAccounting()
  -> oracle.getPricePerShare(yieldSource)   [hard revert on failure]
  -> oracle.decimals(yieldSource)           [hard revert on failure]
  -> _takeSnapshot() or _processOutflow()
```
Only `getPricePerShare()` and `decimals()` called on-chain.

### Flow B: Off-Chain Keeper TVL Read
```
Keeper calls eth_call -> getTVLByOwnerOfShares(vault, smartAccount)
  -> heldValue    = convertToAssets(share.balanceOf(owner))
  -> pendingRedeemValue = convertToAssets(pendingRedeemRequest(REQUEST_ID, owner))
  -> claimableRedeemValue = maxWithdraw(owner)
  -> pendingDepositValue  = pendingDepositRequest(REQUEST_ID, owner)
  -> claimableDepositValue = claimableDepositRequest(REQUEST_ID, owner)
  -> returns sum
```
Each async component wrapped in try/catch.

### Flow C: Monitoring / Observability
```
Monitor calls getAsyncStateBreakdown(vault, owner)
  -> returns 5 individual components (same try/catch pattern)
```

---

## Flow Permutations Matrix

| Vault State | Held | PendingRedeem | ClaimableRedeem | PendingDeposit | ClaimableDeposit | Expected TVL |
|---|---|---|---|---|---|---|
| Fresh account | 0 | 0 | 0 | 0 | 0 | 0 |
| Shares held only | >0 | 0 | 0 | 0 | 0 | heldValue |
| Request redeem submitted | 0 | >0 | 0 | 0 | 0 | pendingRedeemValue |
| Partially fulfilled | 0 | >0 | >0 | 0 | 0 | pending + claimable |
| Fully fulfilled, unclaimed | 0 | 0 | >0 | 0 | 0 | claimableRedeemValue |
| Request deposit submitted | 0 | 0 | 0 | >0 | 0 | pendingDepositValue |
| Deposit fulfilled, unclaimed | 0 | 0 | 0 | 0 | >0 | claimableDepositValue |
| All states active | >0 | >0 | >0 | >0 | >0 | sum of all 5 |

---

## Identified Gaps

### Critical (blocks correct implementation)

**Gap 1: Yo-style vault interface mismatch.** Yo's `pendingRedeemRequest(address)` returns `(uint256 assets, uint256 shares)` — different selector than standard `pendingRedeemRequest(uint256, address)`. The oracle cannot call both via the same interface.

**Resolution:** Maintain separate `YoYieldSourceOracle` for Yo vaults. The new `ERC7540YieldSourceOracle` handles only standard 7540 (Vanilla + Centrifuge V3).

**Gap 2: `claimableRedeemRequest` returns shares, not assets.** The oracle must convert to assets. D1 specifies using `maxWithdraw(controller)` for the claimable redeem component — this returns assets directly, bypassing the need to convert claimable shares.

**Resolution:** Use `maxWithdraw(owner)` for claimable redeem value (D1). Do NOT call `claimableRedeemRequest` + `convertToAssets`.

**Gap 3: Cancel-in-flight states unspecified.** ERC-7540 defines CancelPending and CancelClaimable states. During cancel-deposit, assets move from `pendingDepositRequest` to `claimableCancelDepositRequest`. The oracle's five-component formula doesn't account for cancel states.

**Resolution:** Cancel-in-flight states are brief transient windows. During cancel-pending, `pendingDepositRequest` should still report the pending value per spec. Once cancel is claimable, the user claims assets back to their balance. The five-component formula is correct for the steady-state. Document this as a known limitation: brief TVL undercount during cancel-fulfillment window.

### Important (significantly affects correctness)

**Gap 4: `pendingRedeemValue` conversion for Centrifuge.** `convertToAssets(pendingShares)` uses current PPS, but Centrifuge fulfillment uses epoch-locked price. Value may differ.

**Resolution:** Accept per D5. The difference is bounded by the vault's exit fee (0-0.5%). Using current `convertToAssets` is the best available approximation since the oracle has no access to the future fulfillment price.

**Gap 5: `getShareOutput` calls `previewDeposit` which may revert on async vaults.**

**Resolution:** Use `convertToShares(assets)` instead of `previewDeposit(assets)`, matching the pattern in the deleted oracle at `test/mocks/unused-oracles/ERC7540YieldSourceOracle.sol`.

**Gap 6: `getTVL` calls `totalAssets()` with no try/catch.**

**Resolution:** `getTVL` follows R1 pattern (hard revert). Same as `getPricePerShare`. Document that batch callers must handle per-vault reverts.

**Gap 7: `decimals()` call chain (share() -> decimals()) can revert at two points.**

**Resolution:** Both `share()` and `IERC20Metadata(share).decimals()` follow R1 (hard revert). If either fails, the vault is misconfigured and should not be registered.

**Gap 8: `getAsyncStateBreakdown` return type unspecified.**

**Resolution:** Return 5 named `uint256` values. A struct could be used but adds complexity. Keep it simple: `returns (uint256 held, uint256 pendingRedeem, uint256 claimableRedeem, uint256 pendingDeposit, uint256 claimableDeposit)`.

### Nice-to-Have

**Gap 9:** `getAsyncStateBreakdown` returns 0 on catch — indistinguishable from "no position." Consider emitting events or using sentinel values for monitoring.

**Gap 10:** `getAsyncStateBreakdown` not in `IYieldSourceOracle` interface. Callers must cast to concrete type.

**Gap 11:** `REQUEST_ID = 0` assumption should be verified against mainnet Centrifuge at onboarding.

---

## Recommended Clarifications for Technical Spec

1. Explicitly state: Yo vaults use separate `YoYieldSourceOracle`, NOT the new oracle
2. Specify `convertToShares` (not `previewDeposit`) for `getShareOutput`
3. Specify `maxWithdraw(owner)` (not `convertToAssets(claimableShares)`) for claimable redeem
4. Specify `pendingDepositRequest` and `claimableDepositRequest` return assets directly (no conversion)
5. Specify `convertToAssets(pendingShares)` for pending redeem (accepting D5 tolerance)
6. Document cancel-in-flight as known brief undercount window
7. All R1 functions (getPricePerShare, decimals, getTVL) hard revert on any sub-call failure
8. `getAsyncStateBreakdown` returns 5 uint256 values, 0 on catch per component
9. Assume `controller == owner == smartAccount` (documented invariant)
10. One oracle instance per (vault-type, REQUEST_ID) pair
