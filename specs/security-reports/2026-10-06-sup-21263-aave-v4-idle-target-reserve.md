# Security Analysis Report

## Metadata
- **Target:** PR #1027 (`feat/aave-v4-idle-target-reserve`, SUP-21263) — 7 production `.sol` files of 17 changed
- **Mode:** review (inline scan + 3 parallel agents)
- **Date:** 2026-10-06
- **Contract Types Detected:** ERC-7579 executor hooks (intent-signed, Merkle-leaf authorised) over an Aave V4
  Hub/Spoke lending market; vault-adjacent share accounting (identity PPS, accumulators keyed
  `(user, yieldSource)`). Not ERC-4626. Plus two Forge deployment/configuration scripts.
- **Files Analysed:** 7 production (`src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol`,
  `AaveV4LendHook.sol`, `AaveV4RedeemHook.sol`, `src/interfaces/accounting/IAaveV4MarketRegistry.sol`,
  `src/libraries/AaveV4ReserveKey.sol`, `script/ConfigureAaveV4ReserveRegistry.s.sol`,
  `script/DeployV2OtherHooks.s.sol`). The 10 test files in the PR were reviewed separately in the PR
  comment and are out of scope here.

### ⚠️ Scope limitation — read before trusting any coverage claim

**The skill's vulnerability database is not installed on this machine.** `guidelines/solidity/vulnerabilities.md`
(the "36 sections, 300+ patterns, 175+ exploits" reference) and `guidelines/solidity/coding-rules.md` do not
exist anywhere — not in the repo, `~/.claude`, or the plugin cache. Verified by `find` across all three.

Consequently:
- the critical-pattern checklist below is the **10-pattern list reproduced inside the skill itself**, which is
  available, not a sweep of 300+ patterns;
- **no `vulnerabilities.md` section numbers are cited anywhere in this report.** Any such citation would be
  fabricated. Findings reference the actual code, and named real-world precedents with URLs;
- the coding-standards pass derived house style **empirically** from named unchanged siblings
  (`BaseAaveV4LoanHookV2.sol`, the six V2 LOAN hooks, `BaseMorphoMoneyMarketHook.sol`, the 7 files in
  `src/interfaces/accounting/`, and a count of 589 `require(string)` vs 0 custom-error reverts across
  `script/*.s.sol`). Each standards finding names the file it was derived from.

If that database is vendored somewhere, re-run to get the cross-reference it promises.

## Summary

| Severity | Count | Blocks Merge | Status |
|----------|-------|--------------|--------|
| P0 Critical | 0 | Yes | — |
| P1 High | 0 | Yes | — |
| P2 Medium | 6 | No | **5 fixed, 1 flagged for decision** |
| P3 Low | 9 | No | **6 fixed, 3 accepted** |

## Verdict

**PASS** — no P0 or P1 findings.

One P2 (**P2-1**) was a genuine defect introduced by this PR and is **fixed**: it allowed an atomically
chainable accumulator-stranding and total performance-fee bypass inside a single signed bundle. It would have
been P1 had `feePercent` not been 0 by operational invariant. It is now closed in code, not in the allowlist,
and pinned by two regressions.

One P2 (**P2-2**, redeem path bricked by market deregistration) is **not fixed** — it needs a product
decision, and the change it implies is outside the ticket. See below.

---

## P0 Findings (Critical)

None found.

## P1 Findings (High)

None found.

### Two P1s were REPORTED and are NOT real — recorded so they are not re-raised

**"`_requireTargetIsMarketLeg` reverts unconditionally; every idle lend and redeem is dead"** and
**"membership narrowed to the supply leg only; SUP-21263's premise is not implemented."**

Both were artifacts of a **live mutation in the working tree** at the moment that reviewer read the file — an
unconditional `revert RESERVE_NOT_IN_MARKET()` injected by a concurrent mutation-testing agent (labelled
`MUTATION 3 / HARD PROBE` in the source). The mutation was removed; restoration verified byte-exact two ways
(diff against the agent's pre-edit backup, and `test_IdleHooks_BytecodePinned` matching an artifact generated
before any mutation existed). Root cause was an instruction of mine telling that agent to restore with
`git checkout --` in a tree with uncommitted work. Process lesson recorded in
`.claude/sessions/context_session_sup21263.md`.

**"Authorisation now factors through mutable registry storage, losing the pure-derivation invariant"**
(external research, cited against Morpho Blue's `Id = keccak256(marketParams)` and Uniswap v4's `PoolId`).

**Does not transfer to this registry design, and the evidence is decisive.** `_markets` has exactly two
writers: the single store at `AaveV4ReserveRegistryV2.sol:669`, where
`marketKey = computeMarketKey(spoke_, supplyId_, borrowId_)` is derived **from the very values it stores**, and
a `delete` at `:743`. `MARKET_ALREADY_REGISTERED` (`:665`) blocks overwrite, and no setter mutates a registered
market's legs. Therefore a different leg tuple is a different key, and `getMarketInfo(K)` can only ever return
K's unique preimage.

`_requireTargetIsMarketLeg` then calls `requireHeaderIsMarketKey(K, bodySpoke, returnedLegs)`, which re-derives
and compares — **proving** the returned legs hash to K with the body's spoke. That is precisely the
"dual-binding" the research recommended as the strongest mitigation; it is already implemented. The registry
read is reduced to a boolean allowlist ("is K registered"), which narrows authority rather than expanding it.
A compromised `MARKET_MANAGER_ROLE` can add headers (which still need a signature) or remove them (DoS,
see P2-2) — it cannot make a signed header move a reserve the signer did not commit to.

---

## P2 Findings (Medium)

### P2-1 — Market-blind chaining token made the R6 stranding atomically chainable, with a total fee bypass — **FIXED**

- **File:** `src/hooks/loan/aave-v4/AaveV4LendHook.sol:189`, `AaveV4RedeemHook.sol:88,142` (as written before the fix)
- **Category:** Accounting / share accounting
- **Introduced by:** this PR

The first cut of the R5 fix set the chaining token to `computeReserveKey(spoke, targetReserveId)` — leg-exact,
but with **no market component** (`AaveV4ReserveKey.sol:85` is `keccak256(abi.encode(spoke, reserveId))`).
On the Base MAG7 spoke reserve 7 (USDC) is the borrow leg of **all seven** equity markets, so
`lend(market A, target 7)` and `redeem(market B, target 7)` published and expected the *same* token.

**Exploit scenario (reachable through `SuperExecutor`, one signed bundle):**
`[AaveV4LendHook(header = marketKey(spoke,0,7), target 7), AaveV4RedeemHook(header = marketKey(spoke,1,7),
target 7, usePrevHookAmount = true)]`. `_resolvePrevHookOutput` passes. The INFLOW credits
`usersAccumulatorShares[user][marketKey(0,7)]`; the OUTFLOW consumes under `marketKey(1,7)`, whose accumulator
is empty, so `BaseLedger.calculateCostBasisView:84-86` **caps `usedShares` to 0** rather than reverting.
`_processOutflow` then prices `mulDiv(0, pps, 10 ** decimals) = 0`, so `_calculateFees(0, 0, feePercent)` is
**0 regardless of `feePercent`** — a total performance-fee bypass — and market A's shares and cost basis are
stranded permanently.

This made the R6 hazard, documented as a two-intent ops risk controlled by the OMS allowlist, reachable
**atomically in one intent**. The docblock's rule "chain only on the SAME leg" was itself insufficient; the
correct rule is same leg **and** same market.

**Fix applied.** New `_idleChainToken(vars)` in `BaseAaveV4MoneyMarketHook`, committing the **(market, leg)
pair** under its own domain separator:

```solidity
bytes32 internal constant IDLE_CHAIN_TOKEN_DOMAIN = keccak256("AaveV4Idle.CHAIN_TOKEN");

function _idleChainToken(IdleVars memory vars) internal pure returns (address) {
    return address(
        uint160(uint256(keccak256(abi.encode(vars.marketKey, vars.targetReserveId, IDLE_CHAIN_TOKEN_DOMAIN))))
    );
}
```

Both simpler choices are wrong and the docblock now says why: the market key is leg-ambiguous (would allow an
8-decimal figure to drive a 6-decimal withdraw), the reserve key is market-blind (the above). Only the pair is
safe. Derived in the base, so **no edit to the frozen `AaveV4ReserveKey.sol`** — and both leaves' now-unused
imports of it were removed.

**Regressions:** `test_UsePrev_CrossMarketChain_FailsClosed` (asserts the cross-market chain reverts
`PREV_TOKEN_MISMATCH`, **and** that the old market-blind reserve key is refused) and
`test_ChainToken_IsUniquePerMarketAndLeg` (distinct per market, per leg, and colliding with none of the market
/ reserve / debt namespaces nor a real token). The derivation is written out as a literal formula in the test,
so changing `_idleChainToken` breaks the test rather than silently agreeing with it.

### P2-2 — Market deregistration bricks the idle *exit* path at build time — **NOT FIXED, needs a decision**

- **File:** `src/hooks/loan/aave-v4/BaseAaveV4MoneyMarketHook.sol:264-272`
- **Category:** Availability / external dependency
- **Pre-existing in kind; this PR moves the failure earlier**

`REGISTRY.getMarketInfo` reverts for a deregistered key, and `_requireTargetIsMarketLeg` runs in `build`,
`_preExecute` and `_postExecute`. So one `MARKET_MANAGER_ROLE` deregistration (2-day timelock) leaves every
open idle position under that key with **no Superform redeem path** — failing in `validateHookCompliance`
before any user-facing diagnostic. The V1 `AaveV4WithdrawHook` is not an escape hatch: it requires the
collateral flag, which an idle position never has. Recovery means calling the Spoke directly through the
account's owner validator, outside the ledger, which also strands the accumulator.

This hazard is **already documented** for the accounting path (SECURITY.md §16 item 3, "UNGUARDED,
OPS-ENFORCED"). SUP-21263 converts an accounting-time revert into a build-time revert — strictly better for
lend, no change in recoverability for redeem.

**Why not fixed here.** The suggested remedy — let redeem fall back to a non-reverting
`isMarketRegistered` probe plus a reserve-key pin — changes the authorisation model for the exit path and is
outside this ticket (which forbids registry changes and does not contemplate a withdraw-only mode). The
precedent cited is real and worth weighing: Compound v2 separates `_setMintPaused` from `_setBorrowPaused`, and
Aave's `freezeReserve` deliberately separates "no new supply" from "no withdraw". A registry-level
`marketWithdrawOnly` flag would be the clean two-phase retirement.

**Recommendation:** treat as a follow-up ticket. Until then the ops rule in SECURITY.md §16 item 3 stands —
confirm `getBalanceOfOwner` and `usersAccumulatorShares` are zero for every holder before proposing a market
deregistration, and use the 2-day timelock as the window to check.

### P2-3 — The only gate for R6 was absent from the runbook the script prints — **FIXED**

- **File:** `script/ConfigureAaveV4ReserveRegistry.s.sol`

`_assertIdleSettlementDesignated` takes a deliberate warn-and-continue branch on a chain with no curated
designation (correct — reverting would trap reserve seeding with no table to fill). But the only path that
*fails* is `runCheckAll`'s `require(idleViolations == 0)`, and `_printRemainingSteps` listed two remaining
steps and **never mentioned `runCheckAll`**. So `configureAll` printed "Configuration Complete" over an
ambiguous idle topology, with the warning as one line in a several-hundred-line log.

**Fix:** `runCheckAll` is now step **0** of the printed runbook, ahead of SuperLedger registration, with an
explicit note that it is the only gate that fails on ambiguity; and the warn path ends in a terminal banner
(`>>> STATUS: IDLE DESIGNATION MISSING - DO NOT SIGN IDLE LEAVES ON THIS RESERVE <<<`) rather than a mid-log
line. A `console2.log` buried mid-run is not an ops control.

### P2-4 — Seeded, bound and oracle-resolved registry were three independently chosen addresses — **FIXED**

- **File:** `script/ConfigureAaveV4ReserveRegistry.s.sol:609` (`_prepare`), `script/DeployV2OtherHooks.s.sol`

The hooks' immutable `REGISTRY` is derived from the locked artifact at deploy time and validated only for
`code.length > 0`; `_prepare` accepted the registry as an **operator-supplied parameter** and cross-checked it
against nothing. A re-lock of `AaveV4ReserveRegistryV2.json`, or a divergence between `locked-bytecode/` and
`locked-bytecode-dev/` (which the deploy docblock itself flags as byte-identical *today*), would shift the
derived CREATE2 address to a different, also-deployed, unseeded registry. `code.length > 0` passes, hooks bind
to it, and **every idle op including every redeem** reverts `MARKET_NOT_REGISTERED` — the P2-2 lock arriving by
accident, reported by the deploy script as success.

**Fix:** `_prepare` now asserts the supplied registry equals the committed deployment record
(`REGISTRY_ADDRESS_DRIFT`), tolerating only the no-record case so a first-ever bring-up is not blocked.

### P2-5 — `_idleSettlementCandidates` could under-count and silently skip its own gate — **FIXED**

- **File:** `script/ConfigureAaveV4ReserveRegistry.s.sol`
- **Introduced by:** this PR

The candidate count enumerated reserve pairs and `break`-ed at the first unlisted id. That idiom is house-wide
in this file, but everywhere else it truncates an *enumeration*; here it truncated a **count**. With a gap in
the reserve id space (reserve 3 delisted, 4–7 live) the count for reserve R misses markets `(R,4)…(R,7)`,
under-counts to `<= 1`, and `_assertIdleSettlementDesignated` returns early — **the designation requirement is
silently skipped for exactly the ambiguous reserve it exists to protect.** Fail-open in a gate whose docblock
says "reverts rather than warns".

**Fix:** the registry already maintains this count exactly. `registerMarket` increments `marketRefs` on the
supply leg's reserve key and the borrow leg's debt key (`:678-679`); `executeDeregisterMarket` decrements both
(`:739-740`); nothing else writes that mapping (verified — all six references enumerated). So:

```
candidates(spoke, R) == marketRefs[computeReserveKey(spoke, R)] + marketRefs[computeDebtKey(spoke, R)]
```

Now O(1), immune to id gaps, ~11× fewer live calls per `runCheckAll` on the Base MAG7 spoke, and the same
source `_assertIdleCanonical` and `_printIdleCanonicality` already read.

### P2-6 — `feePercent == 0` was a documented assumption with nothing enforcing it — **FIXED**

- **File:** `script/ConfigureAaveV4ReserveRegistry.s.sol` (`_printLedgerStatus`)

The whole safety argument for the accepted R1/R6 trade-offs rests on `feePercent == 0`: the identity PPS makes
cost basis equal the amount, so a mis-stated realized profit is multiplied by zero. The script **printed**
`feePercent (MUST be 0)` and carried on. One governance call turns a documented accounting quirk into a value
leak, and P2-1 showed a path where the fee computes to zero regardless.

**Fix:** the audit now reverts `AAVE_V4_FEE_PERCENT_MUST_BE_ZERO` when a non-zero fee is configured for the
supplied ledger oracle id. Per the external research, converting this convention into an enforced property is
the highest value-per-line item available here.

---

## P3 Findings (Low)

**Fixed:**

1. **`_postExecute` did not re-pin `underlying`** (`AaveV4LendHook.sol`, `AaveV4RedeemHook.sol`) — the one
   identity field the hardening missed, and the redeem hook publishes it *as* its `outToken`, so the comment's
   claim "nor publish an arbitrary `outToken`" was false. Not reachable through `SuperExecutor`
   (`setExecutionContext` allocates a fresh transient context per invocation, so a forged earlier context is
   invisible). Now re-pinned, which makes the claim true as written.
2. **`_requireTargetIsMarketLeg`'s docblock argued against its own code** — still said "called from build and
   `_preExecute` only … a third registry read would be pure gas" after review added the third call.
3. **`expectedPrevToken`'s `@param` named "the header market key"** — the exact type SUP-21263 stopped using.
4. **`AaveV4LendHook.inspect`'s docblock named `supplyReserveId`**, a field that no longer exists; its redeem
   twin had been migrated, so the pair disagreed.
5. **`AaveV4ReserveKey.sol` attributed `computeReserveKey` to "the lend hook's `outToken`"** — now neither
   leaf reaches it (the chain token is derived in the base), so the note was wrong twice over.
6. **`IAaveV4MarketRegistry`'s rationale for declaring `MARKET_NOT_REGISTERED` was factually wrong** — it said
   the hook raises that selector. The hook imports but does not inherit the interface, so the declaration is in
   no deployed ABI; the selector a caller sees is the registry's, bubbled. Corrected to state the real reason
   (the registry deliberately does not inherit, so the compiler cannot check parity —
   `test_RegistryInterfaceParity` pins it by name), plus the undocumented revert is now on the function and the
   "two view calls" claim narrowed to one.
7. **Audit output depended on unspecified operand evaluation order** — `return a + b` where both operands emit
   logs; Solidity does not specify operand order and it differs between the legacy and IR pipelines, so the
   two sections could print in either order. Now sequenced through locals.
8. **`_printIdleSettlement` printed `NONE` for two different problems** — "no designation curated" (an ops
   gap) versus "curated but unregistered" (what the assert *reverts* on), making the audit less informative
   than the gate. Now distinguished.
9. **Unused imports** of `AaveV4ReserveKey` left in both leaves after the chain-token moved to the base.

**Accepted, not changed:**

- **`_assertIdleCanonical` retains the hard-`require` trap shape** inside `configureAll` that the designation
  gate was reworked to avoid: an out-of-band double-claim blocks all reserve seeding until deregistration
  (2-day timelock). Pre-existing from #1025; splitting it (warn in `configureAll`, fail in `runCheckAll`) is a
  reasonable follow-up but widens this PR's scope.
- **`inspect()` is now `pure` and no longer authenticates** — deliberate and documented. Confirmed it has
  **no on-chain consumer** in v2-core (only the interface declaration and docblocks), so this is purely an
  off-chain/OMS contract change. Flagged for the OMS side: a registration check must move from "inspect
  reverts" to "`isMarketRegistered(marketKey)` is true".
- **`@param` coverage on the new script helpers is inconsistent** with parts of the same file. The file has
  been internally inconsistent for several tickets; the new code sits inside both halves of the existing split
  rather than establishing a third convention.

---

## Inline Critical-Pattern Scan

Against the 10 patterns reproduced in the skill. Scope: the 5 production `src/` files.

| # | Pattern | Result |
|---|---------|--------|
| 1, 5 | Reentrancy / missing guards | **Pass.** No low-level calls, `delegatecall` or `selfdestruct`. `_processHook` is `nonReentrant`; all hook state is `transient` and context-keyed; executions are approve/supply/withdraw on `getReserve`-pinned targets with no callbacks. Hooks custody no funds. |
| 2 | Access control | **Pass.** Every external function in scope is `pure`. `preExecute`/`postExecute` gate `msg.sender == account` (`BaseHook.sol:187,196`) plus a `lastCaller` check and a post-execute mutex. All registry writes are `onlyRole(MARKET_MANAGER_ROLE)`. |
| 3 | Division before multiplication | **Pass.** None introduced. Positive result worth recording: the oracle returns `pps = 10 ** decimals` unconditionally, so `mulDiv(shares, pps, 10 ** decimals)` is exact and the R1/R2 **decimals mismatch cancels algebraically** — it is a units-labelling problem, not a precision one. |
| 4 | Unchecked return values | **Pass.** No bare `.call`/`.send`/`.transfer`. |
| 6 | `abi.encodePacked` collisions | **Pass.** One use (`_inspectIdle`); all four operands fixed-width (`address,address,address,uint256`) → 92 bytes, injective, no length ambiguity. Adding `targetReserveId` was **necessary and sufficient**: without it two bodies moving different assets under one market key would hash identically. Preimage is 92 bytes ≠ 64, so the leaf/internal-node second-preimage class does not apply. |
| 7 | `tx.origin` | **Pass.** Absent. |
| 8 | Floating pragma | **Pass.** Hooks, library and interface all pinned `0.8.30`. The scripts use `>=0.8.30`, conventional in this repo and not deployed. |
| 9 | Returnbomb / EIP-150 OOG | **Pass.** No `try`/`catch` in the changed production code. `getMarketInfo` returns 5 static words and `getReserve` an all-static struct, so solc decodes a fixed size — no memory bomb even from a hostile registry or spoke. The script's `_probe` uses the safe bare `catch { }`. |
| 10 | Trusted caller, untrusted params | **Pass, and this was the main hunt.** `marketKey`, `spoke`, `supplyReserveId`, `borrowReserveId` are keccak-pinned to each other; `targetReserveId` ∈ the two pinned legs; `underlying == getReserve(target).underlying`; `amount` and the bool live in the disjoint resize window `[124,156)`; and `SuperValidator._createLeaf` signs the whole `userOpHash`, so the entire 157-byte body is committed — not just `inspect()` output. The only free choice left to a signer is *which of the two legs*, which is the intended new capability. |

**Vault-adjacent additions** (donation/inflation, first-depositor, rounding, ERC20 integration): no exposure
found. Aave V4 `supply(reserveId, amount, onBehalfOf)` lets a third party inflate the account's position, but
the lend hook snapshots its baseline in `_preExecute` and no external code runs before `_postExecute`, so a
front-run donation shifts baseline and post consistently. The `<= 1` wei round-down is a dust loss inside
Aave, not arbitrage: `credited` is what reaches the ledger and a later redeem consumes the same read.

---

## Attack Surface Summary

- **External entry points:** `build`, `preExecute`, `postExecute` (executor/account-gated); `inspect`,
  `decodeAmounts`, `replaceCalldataAmounts`, `decodeUsePrevHookAmount`, `name`, `description` (all `pure`).
- **Value transfer points:** `IAaveV4Spoke.supply` / `withdraw`, with `onBehalfOf` hardcoded to `account`;
  `IERC20.approve` to the Spoke, reset to 0 before and after.
- **Oracle dependencies:** none at execution time. `AaveV4ReserveOracle` is consulted by the *ledger*, not the
  hooks, and returns identity PPS.
- **Cross-contract interactions:** `AaveV4ReserveRegistryV2.getMarketInfo` (new, 3× per op — 1 cold + 2 warm);
  `IAaveV4Spoke.getReserve` / `getUserReserveStatus` / `getUserSuppliedAssets`.
- **Upgrade mechanisms:** none in the hooks (immutable, CREATE2, no proxy). The registry is role-gated with a
  2-day deregistration timelock — the sole mutable dependency, and the source of P2-2.

## Security Knowledge Sources

- **Internal:** `vulnerabilities.md` and `coding-rules.md` **unavailable** (see scope limitation). House style
  derived empirically from named sibling files.
- **External, primary:** Morpho Blue docs (hash-of-params market identity); Uniswap v4 `PoolId.sol`;
  [Trail of Bits — Building secure Uniswap v4 hooks](https://blog.trailofbits.com/2026/07/30/building-secure-uniswap-v4-hooks/)
  (hook bug classes 1–7; "re-check the derived id on every user-controlled path");
  [Code4rena Revert Lend H-01](https://github.com/code-423n4/2024-04-revert-mitigation-findings/issues/7)
  (authorising datum binds a selector, not the asset);
  [BlockSec — Bunni V2, $8.4M](https://blocksec.com/blog/bunni-incident-repeated-small-withdrawals-compound-a-rounding-error-into-an-8.4m-drain)
  (repeated small withdrawals compound a rounding error);
  [Sherlock — Securing Aave V4](https://sherlock.xyz/case-studies/aave) (the single Medium: rounding amplified
  by a low-decimal asset); [ERC-7528](https://eips.ethereum.org/EIPS/eip-7528) and
  [OZ 5.1 `SafeERC20` codeless-address hardening](https://docs.openzeppelin.com/contracts/5.x/changelog)
  (pseudo-address identifiers); Aave V4 reserve/spoke docs;
  [OWASP SCS Top 10:2025](https://scs.owasp.org/sctop10/archive/2025/Top10:2025/).
- **Honest note on precedent:** there is **no public Aave V4 exploit** (live ~30 Mar 2026; 345 days of review,
  $1.5M programme, Sherlock contest with no Critical/High), and **no published post-mortem** of a signed intent
  whose asset set was redirected by an admin registry write, nor of a fee moving 0 → non-zero over a mixed-unit
  accumulator. Finding *shapes* transfer; incidents do not exist. Treat any claim otherwise as extrapolation.

## Verification After Fixes

Run with `FOUNDRY_DYNAMIC_TEST_LINKING=false`. **This matters:** the repo default (`foundry.toml:54`,
`dynamic_test_linking = true`) serves stale hook bytecode to the fork suites — under a hard-revert probe all 8
Base idle fork tests passed with the hook reverting on every input. Any mutation or coverage work on fork tests
in this repo is meaningless without the flag off.

| Suite | Result |
|---|---|
| `test/unit/**/*AaveV4*` | 669/669 |
| Aave V4 integration (14 suites) | 252/252 |
| `ConfigureAaveV4ReserveRegistry` | 32/32 |
| Bytecode pins | 8/8 — 12 LOAN hooks, both registries and the oracle still pinned and untouched |

Bytecode for both idle hooks was regenerated and re-copied to `locked-bytecode/` and `locked-bytecode-dev/`
after the P2-1 fix. **The hooks' CREATE2 addresses therefore moved again** — any address recorded before this
report is superseded.

## Recommended Follow-Ups

1. **P2-2** — decide on a withdraw-only / two-phase market retirement so deregistration cannot strand the idle
   exit path. Needs a registry change, so it is its own ticket.
2. **Bunni-shape rounding invariant** — `N` tiny OUTFLOWs must never yield more assets, nor a smaller ledger
   decrement, than one equivalent large OUTFLOW, exercised with a 6-decimal and an 18-decimal leg under one
   market key. Not added here: it belongs in the ledger's own fuzz suite rather than the hook suite, and the
   mixed-decimal accumulator is an accepted trade-off whose safety rests on `feePercent == 0` (now enforced by
   P2-6).
3. **Structural fix for R1** — key ledger accumulators `(user, yieldSource, asset)` instead of
   `(user, yieldSource)`. Out of scope (frozen ledger), but it is the only change that removes the
   mixed-unit accumulator rather than documenting it.
4. **OMS side of the `inspect` contract change** — move any header-validity check from "inspect reverts" to
   `isMarketRegistered(marketKey)`.
