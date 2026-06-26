# Interview Notes — Morpho Blue Market Oracle

**Date:** 2026-06-26
**Feature:** MorphoBlueMarketWrapper + MorphoBlueYieldSourceOracle
**Interviewer:** Claude Code
**Security mode:** Auto-enabled (on-chain oracle feature)

---

## Round 1

**Q: What is the primary scope of this oracle?**
A: **Supply-side only.** We track lender (supplier) positions only. Borrow-side accounting is out of scope.

**Q: Who deploys MorphoBlueMarketWrapper instances?**
A: **Permissionless.** Anyone can deploy a wrapper for any valid Morpho Blue market. The oracle accepts any wrapper that points to an existing market (validated in the wrapper constructor via `idToMarketParams`).

**Q: Interest accrual approach — view replication vs reading stale state?**
A: **View replication (current approach).** We replicate Morpho's `_accrueInterest()` math entirely in a view context, calling `IIrm.borrowRateView()` to get the borrow rate without a state-changing transaction. This is the preferred approach for accuracy.

---

## Round 2

**Q: Which chains does this oracle support?**
A: **All chains where Morpho Blue markets exist** — Ethereum mainnet, Base, and any future chains. The oracle is chain-agnostic; a new deployment is needed per chain but no code changes are required.

**Q: What should happen for markets with `irm == address(0)` (idle/zero-IRM markets)?**
A: **Return stale state (no accrual).** If `irm` is the zero address, skip the interest accrual calculation and return the stored `totalSupplyAssets` as-is. These markets have no borrowers and earn no interest, so the stored state is always current.

**Q: Should the spec require full hook + oracle E2E tests?**
A: **Yes.** Tests should exercise the complete lifecycle: `MorphoLendHook` supplies → oracle reads position → `MorphoWithdrawHook` withdraws. This validates the full integration path, not just the oracle in isolation.

---

## Round 3

**Q: Precision requirements for view-based interest accrual?**
A: **Bit-exact parity required.** The oracle's computed `totalSupplyAssets` (after simulated accrual) must match what Morpho would compute on-chain if `accrueInterest()` were called in the same block. This is validated by fork tests at specific block numbers.

**Q: Does the oracle need to be registered in SuperLedgerConfiguration?**
A: **Standalone / off-chain only for now.** Deploy the contracts but do not register with `SuperLedgerConfiguration`. This means no performance fee calculation via this oracle yet — it is used for monitoring/accounting/display purposes initially.

**Q: Specific markets at launch or fully generic?**
A: **Generic — any market via wrapper.** The wrapper design means any existing Morpho Blue market can be supported without code changes. Just deploy a `MorphoBlueMarketWrapper` with the market's params (validated on-chain) and point the oracle at it.

---

## Summary of Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Position side | Supply-side only | Lenders earn yield; borrow tracking is different concern |
| Wrapper deployment | Permissionless | Anyone can create a wrapper for any valid market |
| Interest accrual | View replication of Morpho math | No state change, always fresh, bit-exact |
| Chains | All Morpho Blue chains | Chain-agnostic architecture |
| Zero-IRM markets | Skip accrual, return stored state | No borrowers = no interest = stale is accurate |
| Test coverage | Full E2E hook + oracle lifecycle | Validate integration, not just oracle isolation |
| Precision | Bit-exact parity with on-chain | Fork-test validated at specific blocks |
| Registration | Standalone only | No fee calculation yet |
| Market scope | Generic via wrapper | Zero code changes per new market |

---

## Technical Constraints Identified

1. **Morpho's `Market` struct** has `totalBorrowShares` field which is NOT needed for `borrowRateView()` — pass zero safely.
2. **Fee accrual** in Morpho issues fee shares (not fee assets) which dilutes `totalSupplyShares`. This must be replicated correctly.
3. **`wTaylorCompounded`** is Morpho's custom compound interest approximation — must use their `MathLib` exactly.
4. **`toSharesDown` / `toSharesUp` / `toAssetsDown`** — direction matters; must match Morpho's SharesMathLib.
5. **Virtual offset**: Morpho uses `VIRTUAL_ASSETS = 1` and `VIRTUAL_SHARES = 1e6` in SharesMathLib — ensure our replication uses the same constants.
6. **`borrowRateView` is only defined on the AdaptiveCurveIRM** — if a custom IRM doesn't implement this function, the oracle will revert. This is an acceptable limitation for markets using non-standard IRMs.

---

## Risks Noted

- View replication of Morpho math must stay in sync with Morpho protocol upgrades (though Morpho Blue is immutable, so this risk is low)
- Custom IRMs without `borrowRateView` will cause revert — acceptable known limitation
- Permissionless wrappers mean malicious wrappers could point to valid markets with wrong params — but the constructor validates via `idToMarketParams`, so this is mitigated
