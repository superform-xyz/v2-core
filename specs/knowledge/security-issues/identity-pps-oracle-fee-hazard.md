---
title: Identity-PPS Oracles Must Never Carry feePercent > 0
category: security-issues
tags: [oracles, superledger, fees, flatfeeledger, identity-pps, configuration-hazard]
date: 2026-09-16
severity: high
component: src/accounting/
---

# Identity-PPS Oracles + Fee Config = Principal Taxed as Profit

## Problem

Any oracle that reports identity price-per-share (PPS = 10^decimals, shares == assets)
combined with a `feePercent > 0` registration in `SuperLedgerConfiguration` will treat
**the user's entire principal as profit** and fee it on outflow.

Applies to: `ERC20YieldSourceOracle` (always identity), and any oracle for positions
where no hook ever snapshots cost basis.

## Why the Contract Cannot Protect Itself

There are TWO fee paths, and the contract can only guard one:

1. **View path** — `getAssetOutputWithFees()`: overridable. The identity oracle overrides
   it to bypass fees entirely (returns `getAssetOutput(...)`). Safe.
2. **Ledger accounting path** — `BaseLedger._processOutflow()` computes fees directly
   from `config.feePercent` and **never calls the oracle's fee view**. Nothing on-chain
   stops a misconfiguration here.

Worst case is `FlatFeeLedger`: it hardcodes cost basis to zero, so
`fee = feePercent × full outflow amount` — proven executable in
`test_ledgerPath_flatFeeLedger_hazard_feesFullPrincipal`
(test/unit/accounting/oracles/ERC20YieldSourceOracle.t.sol).

## Solution: Triple-Anchored Operational Invariant

The invariant "identity-PPS oracle ids carry feePercent = 0 (or are not registered at
all)" is enforced by:

1. **NatSpec** — contract-level `@dev` block in the oracle stating the invariant and
   that re-enabling fees requires a NEW oracle version, never a config change.
2. **SECURITY.md #15** — whitelister/operator runbook entry with a due-diligence
   checklist (single canonical token entry point, corporate-action mechanics confirmed,
   blocklist semantics, decimals <= 18).
3. **Executable tests** — hazard tests that DEMONSTRATE the failure (FlatFeeLedger fees
   full principal) plus proof tests that the real `SuperLedger` with no cost-basis
   snapshot charges 0. If someone later "fixes" the config assumption, tests break.

## Precedent

- PR #997 F1 (AaveV4 oracles) — same class of finding, same bypass-override remedy.
- Compound Proposal 62 (~$80M) and Moonwell 2025 ($1.8M) — config-not-code failures:
  correct contracts, catastrophic parameterization.

## Rule of Thumb

If an oracle's PPS is definitionally constant, its fee capability is definitionally
wrong. Bypass the view path in code, pin the ledger path with docs + tests, and treat
any future fee request as a new-contract decision.
