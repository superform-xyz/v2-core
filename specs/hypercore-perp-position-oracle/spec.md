# HyperCore Perp Position Oracle — Spec

## Metadata
- Project: Superform V2
- Chain: HyperEVM (chain 999; testnet 998)
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved
- Related: `src/hooks/hypercore/*` (write side, CoreWriter), SUP-21477 snapshot pattern
- Implementation: `src/vendor/hyperliquid/HyperCoreReadLib.sol`, `src/interfaces/accounting/IHyperCorePerpSnapshot.sol`,
  `src/accounting/oracles/HyperCorePerpPositionOracle.sol`
- Tests: `test/unit/accounting/oracles/HyperCoreReadLib.t.sol`, `test/unit/accounting/oracles/HyperCorePerpPositionOracle.t.sol`,
  `test/integration/hypercore/HyperCorePerpPositionOracleFork.t.sol` (live bytes replayed into mocks),
  `test/integration/hypercore/HyperCorePerpPositionOracleLiveFork.t.sol` (unmodified oracle on a fork through
  `test/utils/HyperCorePrecompileForwarder.sol`; excluded from CI, opt-in sweeps via `HYPERCORE_FORK_FULL=true`)

## Summary

A read-only oracle that lets HyperEVM contracts observe an account's **HyperCore perp
positions** (today they are write-only through CoreWriter and "nothing EVM-observable").
It is a structured snapshot read — not a scalar PPS — because a perp position is signed,
mark-to-market, USD-denominated and per-perp. Values are produced by HyperCore **read
precompiles** and returned raw for the consumer (validator / OMS / snapshot) to net and price.

## Can we read HyperCore positions on HyperEVM? Yes.

Read precompiles live at `0x00..0800+`, are `staticcall`-able from a `view` path, and the docs
guarantee the returned values "match the latest HyperCore state at the time the EVM block is
constructed" — synchronous, no external feed. Gas: `2000 + 65*(input_len + output_len)`.

| Precompile | Address | Input | Returns |
|---|---|---|---|
| `position2` | `0x..0813` | `(address user, uint32 perp)` | `Position` (below). uint32 successor of `position` (`0x..0800`, uint16) |
| `withdrawable` | `0x..0803` | `(address user)` | `uint64` withdrawable USDC margin, 6 dp |
| `markPx` | `0x..0806` | `(uint32 index)` | `uint64` mark price, `6 - szDecimals` dp |
| `oraclePx` | `0x..0807` | `(uint32 index)` | `uint64` oracle price, `6 - szDecimals` dp |
| `perpAssetInfo` | `0x..080a` | `(uint32 perp)` | `{string coin; uint32 marginTableId; uint8 szDecimals; uint8 maxLeverage; bool onlyIsolated}` (struct-wrapped on the wire) |
| `accountMarginSummary` | `0x..080f` | `(uint32 perpDex, address user)` | `{int64 accountValue; uint64 marginUsed; uint64 ntlPos; int64 rawUsd}`, 6 dp USD |
| `coreUserExists` | `0x..0810` | `(address user)` | `bool` |
| `spotBalance` | `0x..0801` | `(address, uint64 token)` | spot balance (out of scope v1) |
| `userVaultEquity` | `0x..0802` | `(address, address vault)` | vault equity (out of scope v1) |

Inputs are RAW `abi.encode(args)` with no function selector, so the vendor file is a `staticcall` library,
not a Solidity `interface`. Invalid inputs make the precompile fail and consume all gas forwarded to it.
Verified live on chain 999 on 2026-10-26: BTC is index 0 with `szDecimals = 5`, so `markPx` is in 1 dp.

```solidity
struct Position {
    int64  szi;            // signed size (negative = short), in szDecimals
    uint64 entryNtl;       // entry notional, 6-dp USD
    int64  isolatedRawUsd; // isolated margin, 6-dp USD, signed (0 for cross)
    uint32 leverage;       // NON-ZERO even on empty rows (observed live) — gate on szi != 0
    bool   isIsolated;
}
```

## Design

- **Vendor library** `src/vendor/hyperliquid/HyperCoreReadLib.sol` (L1Read-style): pins the
  precompile addresses, the return structs and typed `staticcall` readers. Three named errors:
  `PRECOMPILE_CALL_FAILED(precompile)` when the precompile itself fails (unknown index / dex),
  `PRECOMPILE_BAD_RETURN(precompile, len)` when the returndata length is wrong (len 0 = code-less
  address on a non-HyperEVM chain, so a wrong-chain deploy fails closed by name), and
  `INSUFFICIENT_GAS(available, required)` when the caller cannot fund the 500k per-read gas cap
  (otherwise EIP-150 would clamp the forwarded gas and a valid read could be mis-reported as an
  unknown index).
- **`HyperCorePerpPositionOracle`** (read contract, no state writes, all `staticcall`):
  - `getPerpPosition(address account, uint32 perp)` → a structured leg:
    `{ perp, coin, szDecimals, szi, entryNtl, isolatedRawUsd, leverage, isIsolated, markPx, oraclePx, notionalUsd }`.
    `coin` is HyperCore's symbol (`"dex:COIN"` for HIP-3 markets) — the on-chain hint of dex membership.
    `notionalUsd = |szi| * markPx` (unsigned, 6 dp USD; side lives in `szi`).
  - `getAccountSnapshot(address account, uint32[] perps)` (dex 0) and
    `getAccountSnapshotOnDex(address account, uint32 perpDex, uint32[] perps)` →
    `{ coreUserExists, perpDex, withdrawableUsd, accountValue, marginUsed, ntlPos, rawUsd, positions[] }`,
    ONE ROW PER INPUT (`positions[i]` is `perps[i]`, duplicates and zero-size rows included, no
    de-duplication or reordering), one call. Mirrors the SUP-21477 "input is identity, output is
    structured, never netted" pattern, but deliberately NOT its duplicate-collapsing: an integration
    that sends N indices must get N rows back in order, or row matching gets messy. The only netted
    figures are HyperCore's own `accountMarginSummary` on `perpDex` (0 for the two-argument entry point;
    `withdrawableUsd` is always dex 0 because precompile 0x803 is dex-0 scoped).
- **Perp index source (v1)**: caller-supplied `uint32 perp`, no registry. Every perp-indexed precompile
  reverts on an unknown index (verified live), so the read order is not a validation step; `perpAssetInfo`
  is read for `coin` / `szDecimals`. Interface `IHyperCorePerpSnapshot`.

## Caveats (must handle)

- **Decimals and denomination**: `szi` is in `szDecimals`; perp prices carry `6 - szDecimals` decimals (divide
  by `10^(6 - szDecimals)` for DISPLAY only); `entryNtl` / `withdrawable` / margin-summary fields are 6-dp in
  the perp dex's COLLATERAL TOKEN — USDC on dex 0, but HIP-3 dexes choose their quote asset (verified live
  2026-10-26: flx/vntl/km = USDH, hyna = USDE, cash = USDT0). Figures from different dexes are different units.
  `notionalUsd = |szi| * markPx` is already 6-dp and applies NO scaling — adding one is the bug. The oracle
  exposes the raw fields, `szDecimals`, `coin`, and the derived `notionalUsd`.
- **Perp index space**: precompiles address a market as `perpDexIndex * 10000 + indexInMeta` (10000 =
  `xyz:XYZ100`, 20000 = `flx:TSLA`, 70000 = `cash:USA500`; verified live). The trading API's asset id
  (`100000 + …`, e.g. 110000) REVERTS at the precompile. The legacy uint16 `position` (0x800) cannot reach
  dex index >= 7, hence `position2`. Consumers must check `coin` against the expected symbol.
- **Freshness / liveness**: values are as of EVM block construction; CoreWriter actions in the same block are
  not yet visible (never use a read as the post-condition of a same-tx write). Delisted perps (e.g. MATIC 3,
  RNDR 20, FTM 22) keep returning frozen prices and `perpAssetInfo` has no delisted flag; HIP-3 stock /
  commodity perps freeze outside market hours. Gate on `szi != 0`, bound mark vs oracle, reject `markPx == 0`.
- **`withdrawable` is dex-0 scoped** (precompile 0x803); other dexes' margin is only in their own
  `accountMarginSummary(dex, user)`.
- **Signed / mark-to-market**: `szi` can be negative (short) and equity can be negative. This is a
  signed leg, not a positive-only asset — treat like debt in the snapshot, never summed blindly
  into a positive NAV.
- **Zero-size rows**: a user HyperCore has never seen, or a perp never traded, returns zeros without
  reverting, and `leverage` is NON-ZERO on empty rows (observed live: 20). Only `szi != 0` means an open
  position.
- **Gas burn**: an invalid index makes the precompile consume the gas forwarded to it. The read library caps
  each read at `PRECOMPILE_GAS_LIMIT` (500k, ~24x the most expensive documented read; measured live frames are
  3.7k–11.1k) and refuses callers below `MIN_CALLER_GAS` (520k) with `INSUFFICIENT_GAS`, so an on-chain consumer
  that try/catches the oracle loses at most one cap, not 63/64 of its frame. The oracle itself never try/catches.
- **Wire-shape drift**: static returns are length-checked exactly (160 / 128 / 32 bytes) and the dynamic
  `perpAssetInfo` has a lower bound; a mismatch reverts `PRECOMPILE_BAD_RETURN(addr, len)` (len 0 = wrong chain).
- **Not for ERC-4337 validation**: values change every block and ERC-7562 forbids reading such state in
  `validateUserOp`. Consumers are off-chain readers and execution-phase hooks / OMS / snapshots.
- **One dex for margin figures**: `accountMarginSummary` is per dex. `getAccountSnapshot` uses dex 0;
  `getAccountSnapshotOnDex` takes the dex (`perp / 10000`) and echoes it as `perpDex`. Legs on a dex other
  than `perpDex` are returned but are not in `accountValue` / `ntlPos` / `marginUsed` / `rawUsd`;
  `withdrawableUsd` is dex 0 regardless.
- **Account identity**: the HyperCore position is keyed by the EVM address 1:1 (the account is its
  own Core master), consistent with the write hooks.
- **Price source**: `markPx`/`oraclePx` are Core's own oracle, not caller-manipulable; a reverting
  precompile (unknown index) fails the read closed.
- **Chain-gated**: precompiles exist only on HyperEVM (999/998). Deploy only there.

## Out of scope (v1)
Spot balances, vault equity, staking/delegations, funding accrual, cross-vs-isolated netting math,
and any write/settlement. No change to CoreWriter hooks.

## Decisions (formerly open questions)
1. **Index source**: caller-supplied `uint32 perp` via `position2` (0x813), no registry in v1. HIP-3
   builder-dex indices are representable but no index formula is assumed (index 110000 reverts live).
2. **Derived values**: raw fields + `szDecimals` + unsigned `notionalUsd`. No self-derived signed
   equity; HyperCore's own `accountMarginSummary` (signed `accountValue`, `rawUsd`) is surfaced instead.
3. **One call**: `withdrawable`, the margin summary and `coreUserExists` ride along in the snapshot.
4. **No `IYieldSourceOracle`**: standalone, zero-storage, constructor-less view contract.

## Deployment
Wired into the HyperCore family in `script/DeployV2OtherHooks.s.sol` (`_deployHyperCoreHooks`, sixth
entry), so it deploys exactly where CoreWriter is configured (`coreWriters[chainId]`: 999 today, 998 for
testnet) via `run` or `runHyperCore`. Key `HYPERCORE_PERP_POSITION_ORACLE_KEY = "HyperCorePerpPositionOracle"`
in `script/utils/ConstantsOtherHooks.sol` (also the CREATE2 salt). No constructor args. Artifacts in
`script/generated-bytecode/` and `script/locked-bytecode/` (regenerated by `regenerate_bytecode.sh`,
HYPERCORE_HOOK_CONTRACTS); `test/unit/hooks/hypercore/HyperCoreDeployment.t.sol` pins the locked bytecode
to the source and the no-args deploy path. Listed in `deploy_v2_other_hooks_staging_prod.sh` availability
checks and `verify_v2_staging_prod.sh` source paths. NOT registered with the SuperLedger (not an
`IYieldSourceOracle`). Consumer (OMS / strategy snapshot) integration remains v2 (`perpDex` is parameterised via
`getAccountSnapshotOnDex`; the oracle is not registered in SuperGovernor either — it is not a hook).

## References
- Hyperliquid docs — Interacting with HyperCore (read precompiles, `L1Read.sol`)
- `hyperliquid-dev/hyper-evm-lib`
