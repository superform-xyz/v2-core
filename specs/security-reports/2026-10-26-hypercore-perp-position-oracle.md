# Security Analysis Report

## Metadata
- **Target:** uncommitted HyperCore perp position oracle change set (branch `feat/hypercore-perp-position-oracle`):
  `src/vendor/hyperliquid/HyperCoreReadLib.sol`, `src/interfaces/accounting/IHyperCorePerpSnapshot.sol`,
  `src/accounting/oracles/HyperCorePerpPositionOracle.sol`, HyperCore block of `script/DeployV2OtherHooks.s.sol`,
  HyperCore key block of `script/utils/ConstantsOtherHooks.sol`, `test/unit/hooks/hypercore/HyperCoreDeployment.t.sol`
- **Mode:** review (inline critical-pattern scan + 3 parallel agents: vulnerability DB, coding standards, external research)
- **Date:** 2026-10-26
- **Contract Types Detected:** oracle / general (view-only, zero storage, no tokens, no value transfer, no admin, no upgradeability)
- **Files Analyzed:** 6
- **Vulnerability Database:** `superform-specs/guidelines/solidity/vulnerabilities.md` (36 sections, 300+ patterns)
- **Live verification:** HyperEVM chain 999 (public RPC) and Hyperliquid info API, 2026-10-26

## Summary
| Severity | Count | Blocks Merge |
|----------|-------|-------------|
| P0 Critical | 0 | Yes |
| P1 High | 0 | Yes |
| P2 Medium | 2 | No |
| P3 Low | 9 | No |

## Verdict
**PASS** - No P0 or P1 findings. Safe to proceed. Both P2s are documentation defects in the consumer contract
(the values returned are correct); they should be fixed before a NAV consumer is built on the interface.

## Remediation status (2026-10-26, same day, uncommitted)
Applied: P2-1, P2-2, P3-1, P3-2, P3-3, P3-4, P3-5 (NatSpec), P3-6, P3-7, P3-9 — documentation-only changes to the
interface, library, oracle header, deployment test and spec. Because NatSpec feeds the metadata hash, the locked and
generated artifacts were regenerated from the rebuilt source and the bytecode-equals-source lock test re-passed.
Not applied: P3-8 (`SignedMath.abs` swap — correct as written; owner's call). 81 tests across the three mocked suites
green after the changes.

Follow-up (2026-10-27, `/code-review high`): added a caller-gas floor (`MIN_CALLER_GAS` / `INSUFFICIENT_GAS`) so
EIP-150 clamping cannot mis-report a valid read as `PRECOMPILE_CALL_FAILED` (closes the P3-5 residual); added
`getAccountSnapshotOnDex` so HIP-3 legs can be reconciled against their own dex's margin (closes the P2-1/P2-2
follow-up); excluded the replay fork suite from CI as well; guarded `register_hypercore_hooks.sh` against
registering the oracle as a hook. Artifacts regenerated; 112 tests green.

## Inline critical-pattern scan
| # | Pattern | Result |
|---|---------|--------|
| 1 | Reentrancy | N/A — all paths `view`, only `staticcall` |
| 2 | Access control | N/A — no privileged functions, no storage |
| 3 | Division before multiplication | PASS — no division anywhere |
| 4 | Unchecked return values | PASS — `ok` checked, returndata length checked exactly (static) / lower-bounded (dynamic) |
| 5 | Missing reentrancy guards | N/A |
| 6 | `abi.encodePacked` collisions | PASS — none used |
| 7 | `tx.origin` | PASS — none |
| 8 | Floating pragma | PASS — `0.8.30` locked |
| 9 | Returnbomb / EIP-150 | PASS — no try/catch; per-read gas cap 500k; callee is a fixed-address node precompile |
| 10 | Trusted caller, untrusted params | N/A — read-only; caller-supplied index fails closed via the precompile |

## P0 Findings (Critical - Must Fix)
None found.

## P1 Findings (High - Must Fix)
None found.

## P2 Findings (Medium - Should Fix)

### [P2-1] "Every USD figure is 6-dp USDC" is false for HIP-3 legs: they are denominated in the dex's collateral token
- **File:** `src/interfaces/accounting/IHyperCorePerpSnapshot.sol` (DECIMALS paragraph; `entryNtl`, `isolatedRawUsd`, `notionalUsd` @param), `src/vendor/hyperliquid/HyperCoreReadLib.sol` (DECIMALS @dev)
- **SWC:** N/A
- **Category:** Logic (denomination)
- **Description:** HIP-3 builder dexes choose their quote asset. Verified live via `meta.collateralToken`: xyz/abcd/para/mkts/io = token 0 (USDC), flx/vntl/km = 360 (USDH), hyna = 235 (USDE), cash = 268 (USDT0). For a leg on those dexes `entryNtl`, `isolatedRawUsd`, `markPx`, `oraclePx` and therefore `notionalUsd` are 6-dp units of USDH/USDE/USDT0, not USDC. The 6-decimal scaling itself holds everywhere (verified: `flx:TSLA` szDec 2 → `markPx(20000) = 3955000` = 395.5000).
- **Exploit Scenario:** A NAV consumer sums `notionalUsd` or nets `entryNtl` across dexes as "USD", mixing stablecoins with different depeg risk (USDE is a synthetic dollar) and mis-valuing the account. No attacker required; a USDE depeg would be invisible.
- **Vulnerable Code:**
  ```solidity
  ///      DECIMALS: every USD figure is 6-dp USDC. ...
  ```
- **Secure Pattern:** Reword to "6-dp units of the perp dex's collateral token (USDC on dex 0; HIP-3 dexes may use USDH, USDE, USDT0, …)". `coin` (`"dex:COIN"`) is the only on-chain hint of the dex; consumers must keep a dex → collateral allow-list or treat non-dex-0 legs separately. Follow-up: surface `perpDex` per leg (`perp / 10000`, see P2-2).
- **Reference:** vulnerabilities.md Section 3 (decimals/denomination), OWASP SC03

### [P2-2] HIP-3 precompile index space is `perpDex * 10000 + indexInMeta`, not the API asset id; undocumented in the interface
- **File:** `src/interfaces/accounting/IHyperCorePerpSnapshot.sol` (ONE PERP DEX paragraph), `src/vendor/hyperliquid/HyperCoreReadLib.sol:35-38`, `specs/hypercore-perp-position-oracle/spec.md`
- **SWC:** N/A
- **Category:** Logic (index space)
- **Description:** Verified live: `perpAssetInfo(10000)` = `xyz:XYZ100`, `(20000)` = `flx:TSLA`, `(70000)` = `cash:USA500`; the trading API's ids (`100000 + dex*10000 + i`, e.g. 110000) revert. The oracle correctly fails closed on API ids, but the docs only say "HIP-3 index space is NOT validated"; an integrator deriving indices from the API with an off-by-100000 correction in the wrong direction reads ANOTHER dex's market silently. Also `position` (0x800, uint16) cannot address dexes ≥ 7 (index ≥ 70000) — the library's `position2` choice is required, not stylistic. The BBO precompile (0x80e) uses the API id space; any future extension must not reuse the `perp` argument.
- **Exploit Scenario:** Consumer config lists `xyz:TSLA` as 110001 (API id) → `PRECOMPILE_CALL_FAILED` (safe). Consumer "fixes" it by subtracting 100000 everywhere → dex-0 index 10001 is read for a native perp list that happens to include 1 → wrong market, no error.
- **Secure Pattern:** Document `precompileIndex = perpDexIndex * 10000 + indexInMeta` (0 ≤ indexInMeta < 10000) in the interface and spec; recommend consumers assert `coin` equals the expected symbol (or starts with the expected `"dex:"` prefix) before trusting a leg.
- **Reference:** vulnerabilities.md Section 16 (chain-specific assumptions); Hyperliquid asset-ids docs; hl-price-guard, colosseum-pools PR #161 (independent confirmations)

## P3 Findings (Low - Consider Fixing)

### [P3-1] Same-block read-after-CoreWriter-write staleness not stated for execution-phase consumers
- **File:** `IHyperCorePerpSnapshot.sol` (WHERE IT MAY BE CALLED), `HyperCorePerpPositionOracle.sol:11-13`
- **Category:** Oracle. CoreWriter actions settle on HyperCore AFTER the EVM block; a hook that writes then reads in the same tx sees the pre-action state, and no read carries a sequence number to detect it.
- **Fix:** add "CoreWriter actions sent earlier in the same block are NOT visible; never use a read as a post-condition for a same-transaction write."
- **Reference:** Section 4.2

### [P3-2] "Named error" claim overstates coverage: value-level decode drift reverts anonymously
- **File:** `HyperCoreReadLib.sol` (PRECOMPILE_BAD_RETURN @dev; readers)
- **Category:** Logic. Only LENGTH drift is named; dirty high bits (`uint32 leverage`, `bool`) or a bad string offset in `PerpAssetInfo` revert with empty data from `abi.decode`. Fail-closed still holds.
- **Fix:** narrow the NatSpec ("length drift is named; value-level drift surfaces as an empty revert"). Tests already pin both behaviours.
- **Reference:** Sections 29.3, 29.5, 8.1

### [P3-3] `withdrawableUsd` is dex-0 only, undocumented
- **File:** `IHyperCorePerpSnapshot.sol` (`withdrawableUsd` @param). Verified live: an xyz fee recipient shows $1.03M withdrawable on dex xyz via the API while precompile `withdrawable()` returns 0 and `accountMarginSummary(1, user)` carries the value.
- **Fix:** "Withdrawable perp margin on `perpDex`, 6-dp units of its collateral token."

### [P3-4] Delisted / closed markets return frozen prices with no liveness flag
- **File:** `IHyperCorePerpSnapshot.sol` (markPx/oraclePx @param). Verified: MATIC (3), RNDR (20), FTM (22) are delisted yet `markPx`/`oraclePx` return last values; `PerpAssetInfo` has no delisted flag; HIP-3 stock/commodity perps freeze outside market hours.
- **Fix:** document; consumers gate on `szi != 0`, apply a mark/oracle deviation bound, reject `markPx == 0`. (Mark and oracle share CEX inputs, so deviation alone is a weak manipulation detector.)
- **Reference:** Section 4.2; JELLY (2025-03-26) thin-liquidity mark manipulation precedent

### [P3-5] Gas cap residuals
- **File:** `HyperCoreReadLib.sol` (PRECOMPILE_GAS_LIMIT). Verified live: invalid `perpAssetInfo` with `{gas: 500_000}` consumed 500,503; uncapped it consumed 29.5M of 30M (63/64). Successful frames measured 3.7k–11.1k, so real headroom is ~45x (doc says "~25x" against the 20,720 formula; 500,000/20,720 = 24.1x). Residual: a caller with < ~508k gas left still forwards 63/64 of what it has; a snapshot with a bad index pays the successful reads plus one cap.
- **Fix:** optional: state "ceiling, not floor"; consider ~100k (still 9x) if on-chain try/catch consumers appear.

### [P3-6] Misplaced `@dev` in the deployment test
- **File:** `test/unit/hooks/hypercore/HyperCoreDeployment.t.sol:74-78, 107`. The pre-existing "Guards the single most confusable pair" line now documents the oracle test; `test_TokenIsNotTheGatewayAddress` lost its doc.
- **Fix:** move the line back above `test_TokenIsNotTheGatewayAddress`.

### [P3-7] Gas-envelope NatSpec says "per unique perp" but duplicates are re-read
- **File:** `HyperCorePerpPositionOracle.sol:24`. Rows are 1:1 with the request by design; say "per requested perp (duplicates are re-read, not cached)".

### [P3-8] Hand-rolled `_abs` vs OpenZeppelin `SignedMath.abs`
- **File:** `HyperCorePerpPositionOracle.sol:111-116`. Correct as written (widens before negating), but `forge lint` flags two `unsafe-typecast` warnings and `SignedMath.abs(int256(x))` is equivalent and audited. Swapping changes bytecode → regenerate the locked artifact (the lock test will catch a miss).

### [P3-9] Test name "OffChain" collides with the interface's use of "off-chain"
- **File:** `HyperCoreDeployment.t.sol:78`. Rename to `...FailsClosedOnWrongChain`.

### Rejected / not applicable (reviewed)
- `test_LockedBytecode_PerpOracleMatchesSource` "could be view": **rejected** — `vm.getCode` is non-view in the vendored forge-std and the compiler refused `view` (error 8961) when tried.
- Returnbomb: callee is a fixed-address node precompile with bounded output; gas cap bounds memory expansion.
- Wrong-chain deploy: double-gated on `coreWriters[chainId]`; even if bypassed, code-less addresses yield `PRECOMPILE_BAD_RETURN(addr, 0)`; on Moonbeam/Moonriver (live precompiles at 0x800+) the selector-less payload is rejected → `PRECOMPILE_CALL_FAILED`.
- ERC-4337 validation: documented as forbidden; additionally ERC-7562 OP-041/OP-062 would make a bundler reject the userOp.
- CREATE2 front-running: no constructor, no storage → a pre-deployed copy is bit-identical and is adopted.
- Deploy wiring: key appears once, key == salt == contract name, bare creation code matches the constructor-less source, generated and locked artifacts byte-identical (solc 0.8.30, optimizer 200, prague), `locked == type(X).creationCode` pinned by test; dry run on chain 999 succeeded.
- Trailing calldata is accepted by the precompiles (verified) — harmless with centralized fixed-shape encoders.
- Off-chain operations: non-archive HyperEVM nodes fail precompile `eth_call`s at historical blocks (eRPC #1176); `eth_estimateGas` on an invalid index returns `-32003 PrecompileError`. Document for integrators.
- `coreUserExists` is true for nearly any address that ever received Core USDC → gate on `szi != 0` (already documented).

## Attack Surface Summary
- **External Entry Points:** `getPerpPosition(address,uint32)`, `getAccountSnapshot(address,uint32[])` — both `view`.
- **Value Transfer Points:** none.
- **Oracle Dependencies:** HyperCore read precompiles 0x803, 0x806, 0x807, 0x80a, 0x80f, 0x810, 0x813 (node logic, values as of block construction; mark/oracle prices are HyperCore's, manipulable only by trading on HyperCore, with deployer-pushed oracles on 6 of 10 HIP-3 dexes).
- **Cross-Contract Interactions:** `staticcall` to the precompiles only, gas-capped, length-checked.
- **Upgrade Mechanisms:** none (immutable CREATE2 deploy, no admin).

## Coding Standards Findings
`forge fmt --check` clean; pragma locked; custom errors only in `src/`; NatSpec on every external symbol and struct field; byte-length and arithmetic claims re-derived and correct; deploy/constants changes follow the HyperCore family conventions exactly; no events is correct for a state-less contract. Open nits: P3-6, P3-7, P3-8, P3-9 above.

## Security Knowledge Sources
- **vulnerabilities.md sections referenced:** 3, 4, 7, 8, 13, 14.3, 15, 16, 29, 36, 48.8, 48.11, App. D.3, App. H
- **evmresearch.io patterns checked:** precompile divergence / empty-address calls, RETURNDATASIZE return-bomb, EIP-2929 warm/cold costs, shared-upstream oracle spread checks, Mango-style uPnL-as-collateral, perp funding manipulation, L2 stale-oracle patterns
- **Coding rules validated:** coding-rules.md (documentation, errors, visibility, naming, OZ usage), .solhint.json, foundry [fmt]/[lint]
- **Historical exploits cross-referenced:** JELLY (Hyperliquid, 2025-03), Mango Markets; plus hl-price-guard / hyperevm-safety replays (unverified beyond those repos)
- **Live verification:** HyperEVM 999 `eth_call`s (index mapping, decimals, delisted prices, gas burn with/without cap, trailing calldata), Hyperliquid info API `meta` per dex (collateral tokens), `clearinghouseState` per dex (withdrawable scope)
