# Aave (Joao) Call Sheet — Aave V4 Oracles / Base Tokenized Equities

**Date prepared:** 2026-09-03 | **Linear:** SUP-20854 | **PR:** #997 (review F2 gates on Q1/Q2)

Ordered by what each answer unblocks. Items we already answered ourselves via fork testing are
listed at the bottom so they aren't re-asked.

## Blocking (closes PR #997 review F2)

1. **Plain Spoke or TokenizationSpoke for the Base equity markets?**
   - Plain `ISpoke` → the delivered registry + debt + supply oracles are exactly right.
   - `TokenizationSpoke` (ERC-4626 wrapper) → equity supply positions are 4626 shares; the
     existing `ERC4626YieldSourceOracle` covers them; the new supply oracle does not apply to
     equities (registry + debt oracle remain valid either way).
2. **Base equities spoke address, equity reserve ids (NVDAc/METAc/AAPLc/GOOGLc), and which
   stables are borrowable against them** — needed for the Base fork-test twin, registry
   seeding, and the deployment matrix.

## Spec-hardening (turns documented assumptions into confirmed facts)

3. **reserveId permanence**: guaranteed never rebound to a different underlying, including
   across spoke implementation upgrades (spokes are TransparentUpgradeableProxies)? We rely on
   "sequential, never reused" read from `main`.
4. **Trading-hours behavior**: do equity reserves actually pause/freeze on a schedule, and do
   the position views (`getUserDebt`, `getUserSuppliedAssets`) stay callable under those flags?
   (Our oracles don't gate on flags — unit-tested; rsETH incident suggests views stay live;
   want Aave's intent statement.)
5. **Umbrella socialization**: when bad debt is socialized, does `getUserSuppliedAssets`
   reflect the haircut immediately (supply value drops in-view), or is there a lag/settlement?

## Edge / dust (close if time permits; nothing blocks)

6. **Premium rounding** on the RAY→asset conversion in `getUserDebt` — drawn rounds up;
   premium direction unverified. Only matters for whether `approve(drawn+premium)` can be
   1 wei short of `repay(max)`'s pull.
7. **Deployed commit**: which audited release/commit is the Base spoke deployed from? (We want
   to pin the vendored interface to the 2026-03-23 ChainSecurity final / 2026-03-09 Certora
   Spoke FV lineage.)
8. **B20 token mechanics**: any transfer hooks/callbacks (read-only-reentrancy residual)? Does
   the `receiveSharesEnabled` liquidation path interact with the KYC/vesting gates? (Hook
   settle-path concern, not oracles.)

## Business (zero oracle impact; closes an open item)

9. **$1M Base incentives mechanism** — Merit-style off-chain merkle? If so it never touches
   spoke balances and the thread closes.

## Already answered ourselves — do NOT re-ask (FYI-worthy)

- Reserve-level TVL views (`getReserveDebt`, `getReserveSuppliedAssets`) exist and work on the
  live Ethereum spoke (fork-verified; vendored interface extended).
- `updateUserRiskPremium` is **AccessManager-gated on the deployed spoke** (third-party calls
  revert `AccessManagedUnauthorized`; self-calls succeed) — the pre-launch Sherlock-contest
  permissionless behavior was hardened before deployment. Worth mentioning we pinned this in
  fork tests.
- Views survive paused/frozen flags at the oracle layer (our oracles never read flags), and
  in-view accrual to `block.timestamp` is fork-verified for both debt and supply reads.
