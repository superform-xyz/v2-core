---
title: Adding a Yield-Source Oracle - All Six Deploy-Tooling Wiring Points
category: integration-issues
tags: [oracles, deployment, create2, locked-bytecode, deploy-scripts]
date: 2026-09-16
severity: informational
component: script/DeployV2Core.s.sol
---

# Adding a Yield-Source Oracle - Deploy-Tooling Wiring Checklist

## Problem

A new oracle contract that compiles and passes tests is NOT deployable until it is wired
into six separate places in the deploy tooling. Missing any one of them fails silently:
the deploy either skips the contract or — worse — the **check phase reports "Missing: 0"**
while the contract has never been deployed anywhere.

Discovered while adding `ERC20YieldSourceOracle` (Sep 2026): five wiring points were done,
build was green, tests were green, and the Plataberget check run happily printed
"Total Contracts Checked: 72 / Missing: 0" — because the check flow enumerates contracts
in a **separate hand-maintained list** from the deploy flow.

## The Six Wiring Points

1. **`script/run/tooling/regenerate_bytecode.sh`** — add the contract name to
   `ORACLE_CONTRACTS` (or the matching family array). Then run the script to produce
   `script/generated-bytecode/<Name>.json` and copy it to `script/locked-bytecode-dev/`.

2. **`script/utils/Constants.sol`** — add the key constant, e.g.
   `string constant ERC20_YIELD_SOURCE_ORACLE_KEY = "ERC20YieldSourceOracle";`.

3. **`script/DeployV2Core.s.sol` — deploy side** (`_deployOracles`, ~line 4755):
   bump the `len` count, add the `oracles[N] = _createSafeOracleDeploymentWithArgs(...)`
   entry, AND add the name to the `string[N]` availability array (~line 726). Three edits
   in one file that must stay consistent.

4. **`script/DeployV2Core.s.sol` — check side** (`__checkContract` enumeration,
   ~line 2580–2650): a **completely separate list** from the deploy side. Add
   `__checkContract(KEY, __getSalt(KEY), abi.encode(<ctor args>), env);`
   mirroring the sibling with identical constructor args (Euler pattern for
   single-arg `superLedgerConfig` oracles). **This is the one everyone misses.**

5. **`script/run/verify/verify_v2_staging_prod.sh`** — TWO cases: the constructor-args
   case (`cast abi-encode "constructor(address)" "$super_ledger_config"`) and the
   source-path case. Precedent for missing both: EulerDebtOracle shipped with this gap.

6. **Artifacts committed** — both `script/generated-bytecode/<Name>.json` and
   `script/locked-bytecode-dev/<Name>.json`. If you change mutability/NatSpec-adjacent
   code after generating (e.g. `view` → `pure`), REGENERATE — bytecode changes.

## Verification That Actually Proves It

Run the check phase against a chain where the contract is not yet deployed:

```bash
forge script script/DeployV2Core.s.sol:DeployV2Core \
  --sig 'run(bool,uint256,uint64)' true 2 <chainId> --rpc-url <rpc>
```

Success criterion is NOT "no errors". It is:
- Total Contracts Checked increments by exactly 1, AND
- your contract appears with `Code Size: 0` / listed as missing.

If the total didn't increment, wiring point #4 is missing.

## Root Cause

Deploy-side and check-side enumerations in `DeployV2Core.s.sol` are independent
hand-maintained lists with no compile-time or runtime cross-check. The check phase
cannot know about a contract it was never told to look for.

## Related

- `specs/erc20-yield-source-oracle/` — full spec for the oracle that surfaced this
- PR #1003 — cap-bridge hooks found unwired the same way (deployed-artifact drift)
