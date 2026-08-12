# EVM Security Research — Pendle PT Record Hooks

Feature under review: `RecordPurchasePendlePTHook` + `RecordRedemptionPendlePTHook` recording PT
trades into `PendlePTAmortizedOracleV2`, plus extending `PendlePTHook` to expose
`IPendlePTHookResult` (operation + input/output token + input/output amounts) populated from
**actual execution balance deltas**, read by the record hooks in the same ERC-7579 executor flow
(per-account transient context, approved-address prev-hook binding). Oracle prices PT→SY via a
Pendle TWAP with a configured minimum `twapDuration`.

**Primary reference:** `guidelines/solidity/vulnerabilities.md` (Superform internal vuln DB; resolved
on this machine at `/Users/cosming/1.Coding/Superform/superform-specs/guidelines/solidity/vulnerabilities.md`).
Section numbers below are that file's numbering.

**Code read for grounding (all under `/Users/cosming/1.Coding/Superform/v2-core`):**
- `src/hooks/swappers/pendle/PendlePTHook.sol` (the hook being extended)
- `src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol`
- `src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol`
- `src/accounting/oracles/PendlePTAmortizedOracleV2.sol`
- `src/hooks/BaseHook.sol` (transient per-account execution-context machinery)
- `src/executors/SuperExecutorBase.sol` (`_processHook` loop, `setExecutionContext`/`resetExecutionState`)

---

## 0. How the mechanism actually works (grounding for the analysis)

These facts drive every finding below; they were verified in code, not assumed.

1. **Per-hook transient context, keyed by account then by a per-account nonce.**
   `BaseHook` stores `outAmount`/`outToken` in EIP-1153 transient storage at
   `keccak256(HOOK_EXECUTION_STORAGE, context, offset)`, where `context` is an `executionNonce`
   looked up per account at `keccak256(ACCOUNT_CONTEXT_STORAGE, account)`
   (`BaseHook.sol:362-389`). Each hook contract has its **own** transient storage; the record hook
   reads the *PendlePTHook's* storage via `ISuperHookResult(prevHook).getOutAmount(account)`.

2. **The executor drives context lifecycle per hook** (`SuperExecutorBase._processHook`, `:300-331`):
   `setExecutionContext(account)` (→ `_createExecutionContext` increments `executionNonce`,
   `BaseHook.sol:142-145,366-378`) → `_execute` (runs `preExecute`/router calls/`postExecute`) →
   `resetExecutionState(account)`. `_processHook` is `nonReentrant`.

3. **`resetExecutionState` clears ONLY the pre/post mutexes, NOT `outAmount`/`outToken`**
   (`_clearExecutionState`, `BaseHook.sol:441-444`). This is *why* the next hook (the record hook)
   can still read the PendlePTHook's result after PendlePTHook's own `_processHook` finished. The new
   `getPendleTradeResult` data MUST live in the same transient, context-nonce-keyed slots so it
   inherits the exact same lifetime and isolation.

4. **Isolation properties that the transient+nonce design already provides** (and that the feature
   must not break):
   - *Cross-account:* different `account` → different context nonce → disjoint slots.
   - *Cross-execution within one tx:* a second PendlePTHook run calls `setExecutionContext` again →
     `executionNonce++` → fresh (zero) slots, so run #1's values are not read by run #2.
   - *Cross-transaction:* transient storage clears at tx end.
   Using a plain `mapping(address => TradeResult)` in **regular** storage would defeat all three
   (see Attack Surface AS-1).

5. **`PendlePTHook` today only tracks the OUTPUT delta.** `_preExecute` snapshots the *output* token
   balance of `account`; `_postExecute` sets `outAmount = outputBalanceAfter - outputBalanceBefore`
   and `outToken = header.outputToken` (`PendlePTHook.sol:347-355`, `_getBalance` `:628-636`). To
   expose PT-spent for SELL/REDEEM it must additionally snapshot the *input* token balance in
   `_preExecute` and compute the input delta in `_postExecute`. Every risk of the existing output
   path (below) now also applies to the new input path.

6. **The oracle re-derives balances independently.** `recordPurchase` computes
   `previousPtBalance = balanceOf(strategy) - ptBought` and reverts on
   `BOOK_VALUE_EXCEEDS_FACE_VALUE` (`PendlePTAmortizedOracleV2.sol:184-201`); `recordRedemption`
   computes `previousPtBalance = balanceOf(strategy) + ptSold` and does a `mulDiv` by
   `previousPtBalance` (`:227-235`). The recorded amount and the on-chain `balanceOf` at record time
   MUST be mutually consistent or the record reverts (DoS) or mis-amortizes. `msg.sender` to the
   oracle is the smart account/strategy (`:166,215`).

7. **TWAP minimum is enforced oracle-side, not hook-side.** `recordPurchase` reverts
   `TWAP_DURATION_TOO_SHORT` if `twapDuration < getMinTwapDuration(market)` (default 300s,
   `:165-169,336-339`). `recordRedemption` takes **no** `twapDuration` and does **no** rate read —
   it is pure cost-basis bookkeeping. The purchase path is the only TWAP-exposed one.

---

## 1. Relevant vulnerability patterns (mapped to `vulnerabilities.md`)

### 1.1 Cross-account / cross-execution context leakage
- **§23.7 Transient Storage Misuse (EIP-1153)** — *directly on point.* The whole feature rests on
  reading one hook's transient result from another hook mid-transaction. Detection bullets ("callback
  functions relying on transient storage state", "assumptions about transient storage clearing
  mid-transaction") describe exactly the `getPendleTradeResult` read path. The new struct must be
  stored under the same `_makeKey(context, offset)` scheme with fresh offsets — never in regular
  storage, never keyed by account alone.
- **§21.4 Signature Replay Across Accounts** / **§40.1 Cross-Chain UserOperation Replay** — the
  *account-scoping* discipline these demand ("Signature includes account address", bind to the
  specific account) is the same discipline as keying the trade result by `account`. A read that
  resolves to the wrong account is the on-chain-context analogue of a cross-account replay.
- **§1.2 Cross-Function Reentrancy / §1.3 Cross-Contract Reentrancy** — the read spans two contracts
  (record hook → PendlePTHook) within one executor call; stale/mid-flight context is the failure
  mode.

### 1.2 Read-only reentrancy of `getPendleTradeResult` / `getOutAmount` used by the next hook
- **§1.4 Read-Only Reentrancy** (High; Curve July 2023) — *the headline pattern for the view read.*
  "View functions return inconsistent data when called during reentrancy, affecting dependent
  contracts." The record hook is precisely a dependent contract consuming a view (`getOutAmount` /
  new `getPendleTradeResult`) of another contract for accounting. If any external call between the
  PendlePTHook snapshot and the record-hook read can move `account`'s PT/asset balance or re-enter,
  the consumed value is inconsistent.
- **§1.5 ERC Token Callback Reentrancy** / **§10.4 ERC-777 Hooks** — a PT, YT, SY, or output asset
  with transfer callbacks can re-enter *during* the router call, i.e. between `_preExecute` snapshot
  and `_postExecute` delta. Note `_processHook` is `nonReentrant` at the executor, but that guard
  does not cover re-entry that happens *inside* the Pendle router execution window and mutates
  `account`'s balances via a token hook.

### 1.3 Reentrancy around the pre/post balance snapshots
- **§10.1 Fee-on-Transfer Tokens** — the *canonical* balance-delta guidance ("check actual balance
  change") is exactly the technique PendlePTHook uses; the vuln is trusting a nominal amount instead.
  For the new INPUT delta this cuts the other way: a fee-on-transfer PT would make
  `inputBefore - inputAfter` (PT actually leaving the account, incl. fee) diverge from the PT the
  router credited to the market — see AS-4.
- **§10.2 Rebasing Tokens** — a rebasing asset/SY/PT can change `account`'s balance between snapshot
  and post for reasons unrelated to the trade, corrupting either delta.
- **§25.1 Code Asymmetry Detection** — the input path and output path must be measured
  symmetrically. PendlePTHook currently snapshots only output; bolting on an input snapshot invites
  an asymmetry bug (e.g. input snapshot taken but native/ERC20 branch handled differently than
  `_getBalance` does for output).

### 1.4 Oracle / TWAP manipulation
- **§4.1 Spot Price Oracle Manipulation** (Critical) — `twapDuration = 0` is spot; the oracle's
  `DEFAULT_MIN_TWAP_DURATION = 300` and `TWAP_DURATION_TOO_SHORT` guard exist to forbid it. Confirm
  no code path reaches `getPtToSyRate` with a sub-minimum window.
- **§48.7 TWAP Oracle Manipulation in Low-Liquidity Pools** (High) — *the most specific match.*
  "Short TWAP window (< 30 minutes) on L2" and "TWAP oracle from pool with < $1M liquidity". The
  300s default is well under 30 minutes; on the L2s where this deploys, a low-liquidity Pendle market
  is manipulable across a few blocks. `marketMinTwapDuration` per market is the lever — verify it is
  actually raised for thin markets, not left at default.
- **§5.1 Flash Loan Price Manipulation** (Critical) — a single-tx manipulation of the Pendle market's
  PT/SY reserves just before `recordPurchase` reads `getPtToSyRate` inflates/deflates recorded
  book value. TWAP length is the mitigation; a too-short min re-opens it.
- **§4.2 Stale Oracle Data / §48.6 Same Heartbeat Across Feeds** — Pendle's PT oracle depends on the
  market's observation buffer. If cardinality is insufficient for the requested `twapDuration`,
  Pendle's `PendlePYOracleLib` reverts or returns a degenerate value. There is no
  `getOracleState`/cardinality check before pricing — analogous to a missing staleness check.
- **§48.11 Fallback Oracle Liveness Failure** — if `getPtToSyRate` reverts (uninitialized oracle,
  insufficient cardinality), `recordPurchase` reverts and the *entire hook sequence* reverts (the
  deposit/swap is undone). This is a DoS on the whole strategy action, not just the accounting.

### 1.5 Malicious `market.readTokens()` returning attacker PT/token
- **§44.2 Malicious Hook Data Processing** (Critical; Cork Protocol May 2025, $11M) —
  "hookData decoded and used without independent verification … Token addresses in hookData not
  validated against whitelist." The `market` address is attacker-supplied calldata; `readTokens()`
  on it returns `(SY, PT, YT)`. PendlePTHook's own NatSpec already flags this
  (`PendlePTHook.sol:73-75`). The record hooks add a *second* consumer of `market.readTokens()`.
- **§44.5 Arbitrary Market Creation Enabling Hook Exploitation** (Critical) — a fabricated "market"
  whose `readTokens()` returns an attacker PT lets the recorder validate against a token the attacker
  controls. Mitigation is the strategy/Merkle authorization + the requirement that the record hook's
  `market` equal the PendlePTHook's *traded* market (from `TradeResult.market`), not merely a
  self-consistent attacker market.
- **§8.2 Arbitrary External Calls** — every `readTokens()` / `getPtToSyRate()` is a call into an
  address chosen by calldata; a malicious market can reenter or return crafted values.
- **§14.3 Missing Input Validation** — the current V2 recorders validate only `market != 0` and
  `amount != 0`. No operation-type, token-match, or market-vs-prev-hook check exists yet.

### 1.6 Fee-on-transfer / rebasing PT or asset skewing balance-delta measurement
- **§46.1 Fee-on-Transfer Token Balance Mismatch** and **§46.2 Rebasing Token Share Calculation
  Drift** (2024-2026 set) — reinforce §10.1/§10.2 specifically for the delta-measurement design.
- **§46.3 Tokens with Multiple Entry Points** — a PT/asset with a second transfer entry point can
  move balance without the expected event/observation, desyncing the delta.
- **§22.2 Exchange Rate Manipulation via Direct Transfers** / **§28.x Donation & Inflation** — a
  direct PT transfer to `account` *between* the trade and the oracle's `balanceOf(strategy)` read
  changes `previousPtBalance` and can trip `BOOK_VALUE_EXCEEDS_FACE_VALUE` (DoS) or under-state cost
  basis. The oracle trusts `balanceOf` at record time, not the tight trade delta.

### 1.7 Prev-hook spoofing / unauthorized recorder
- **§2.1 Missing Access Control** — the recorder must bind `prevHook == APPROVED_PENDLE_PT_HOOK`
  (constructor-pinned immutable). Today's V2 recorders read *any* `prevHook.getOutAmount(account)`.
- **§44.1 Missing PoolManager Access Control on Hook Callbacks** (Critical; Cork $11M) — the Uniswap
  V4 analogue: hook-consumed data must originate only from the trusted caller. Here the trusted
  "caller" is the approved PendlePTHook; anything else is spoofable.
- **§8.4 / §24.2 Phantom Function Attacks** — an arbitrary `prevHook` that merely *implements*
  `getOutAmount`/`getPendleTradeResult` selectors (returning attacker values) satisfies the interface
  without being the real hook. The pinned-address check, not an ERC-165/selector check, is the
  correct defense (matches interview decision #1).
- **§25.2 Idempotency Failures / §25.3 Duplicate Entry Exploitation** — a recorder that can run
  twice against one trade (or that reads a result already consumed) double-counts book value.

### 1.8 PT decimals
- **§37.4 ERC-4626 Decimal Mismatch** (High) — the oracle scales by `10**(18 - assetDecimals)` and
  `10**ptDecimals` (`PendlePTAmortizedOracleV2.sol:429-502`). PT decimals need not be 18 and need not
  equal the asset's. `recordPurchase`'s `sySpent = ptBought * ptToSyRate / 1e18` assumes PT and SY
  share a scale (true for Pendle PT/SY, both mirror underlying decimals) — verify for any non-18
  market. The record hook must record `ptBought` in **PT token units** (the raw delta), never a
  rescaled quantity.
- **§29.5 Dirty High-Order Bits** — `twapDuration` is `uint32` read from calldata (`toUint32` at
  offset 104/analogous). Confirm the decoder masks correctly and the packed layout offsets are exact
  (a one-byte layout slip silently mis-reads market/amount/bool — see §14.1).

### 1.9 Matured-redemption edge cases
- **§14.4 Incorrect State Machine** — routing depends on `yt.isExpired()` at the exact block
  (`PendlePTHook.sol:214-226`; NatSpec `:54-55`). At the expiry block, SELL-format payload routes to
  REDEEM. The recorder must accept BOTH `SELL_PT` and `REDEEM_PT` as valid "redemption" ops and must
  not assume the operation the signer *intended* — it must trust `TradeResult.operation` derived
  from actual routing.
- **§4.x maturity boundary** — `recordPurchase` reverts `MARKET_EXPIRED` at/after maturity
  (`:174`); a BUY landing exactly at maturity is rejected oracle-side. Post-maturity book value = face
  value (`_calculateBookValue :370-372`). Ensure the purchase recorder does not attempt to price a
  matured market via TWAP.

### 1.10 DoS via revert in the record step
- **§7.4 Unexpected Revert DoS** — the record hook runs in the *same* atomic sequence as the trade.
  Any revert in `recordPurchase`/`recordRedemption` (twap-too-short, market-expired,
  book-value-exceeds-face, `NO_POSITION`, PT-balance underflow) reverts the user's whole
  deposit/swap. Every added validation is also a new DoS surface — validations must be
  attacker-*non*-triggerable given honest calldata.
- **§7.2 External Call DoS** — `readTokens()` / `getPtToSyRate()` into a griefing market can revert
  or burn gas (**§13.1 Gas Griefing**, **Appendix H Returnbomb**) to force the sequence to fail.
- **§25.2 Idempotency** — conversely, if `recordRedemption` reverts on `NO_POSITION` (no prior
  purchase recorded for that strategy+market), an honest sell of PT that was acquired *without* going
  through the purchase recorder will DoS. This is a real operational edge, not just theoretical.

---

## 2. Exploit precedents

| Incident | Loss | Root cause | Relevance to this feature | DB ref |
|---|---|---|---|---|
| **Penpie** (Sep 3, 2024) | **~$27M** | Permissionless registration of a *malicious Pendle market* + missing `nonReentrant` on batch reward harvest → attacker's fake SY/market re-enters `claimRewards` and inflates balances; flash-loaned funds returned as "rewards". | The single most relevant precedent: it is a **Pendle-market-trust + reentrancy** bug. Our record hooks consume `market.readTokens()` and a cross-contract transient result mid-flow. If `market` is not pinned to the PendlePTHook's actually-traded market, an attacker market is the Penpie entry point. | **§48.1** (Penpie Pattern), **§44.5**, Appendix C (Penpie, "Cross-Chain Reentrancy"), Appendix M.1 |
| **Curve Finance** (Jul 2023) | **$69M** (Vyper reentrancy; read-only variant drained lending markets pricing off Curve) | Read-only reentrancy: view (`get_virtual_price`) returned inconsistent data mid-callback; dependent protocols (Sentinel/Sturdy) mis-priced. | Our record hook is a *dependent consumer* of another contract's view (`getOutAmount`/`getPendleTradeResult`). Same shape: consume a view whose backing state can be mid-flight. | **§1.4**, Appendix C (Curve, Sentiment/Sturdy) |
| **Cork Protocol** (May 2025) | **$11M** | Hook callbacks callable/craftable without validating hook data & token addresses (Uniswap V4 hook trust). | Direct analogue for hook-data trust: validate `market`, PT token, operation type, and the prev-hook identity rather than trusting supplied bytes. | **§44.1**, **§44.2** |
| **Mango Markets** (Oct 2022) | **$115M** | Spot-oracle price manipulation via thin market. | The purchase recorder prices PT→SY off a Pendle TWAP; too-short window on a thin market reproduces this. | **§4.1**, Appendix C |
| **UwU Lend** (Jun 2024) | **~$20M** | Multiple oracles manipulated via flash loan. | Same class as the TWAP-min-bypass risk; underlines that "we use a TWAP" is not sufficient if the window/cardinality is weak. | Appendix M.1, **§48.7** |
| **Predy Finance** (audit finding, May 2024, Code4rena) | — (finding) | TWAP from low-liquidity pool manipulable across blocks, esp. on L2. | Cited by the DB specifically for short-window/L2 TWAP; matches our 300s default on L2 deployments. | **§48.7** |
| **BonqDAO** (Feb 2023) | part of "$120M+" oracle-manip class | Spot oracle write manipulation. | Reinforces min-window enforcement. | **§4.1** |
| **Sonne Finance** (2024) | **~$20M** | Donation to inflate exchange rate around empty/low state. | Direct PT donation to `account` between trade and oracle `balanceOf` read → `BOOK_VALUE_EXCEEDS_FACE_VALUE` DoS or skewed cost basis. | **§22.2 / §28 / Appendix M.4** |

**Note on figures:** amounts and dates above are taken from the internal vuln DB (Appendix C, M.1,
§48.1, §48.7, §44.x). The web-search budget for this session was exhausted before independent
corroboration, so treat the *Penpie ~$27M / Sep 3 2024* and *Curve $69M / Jul 2023* figures as
DB-sourced; public post-mortems (BlockSec, Rekt.News leaderboard — DB Appendix L) corroborate the
same events and can be pulled for exact links when budget is available.

---

## 3. Attack surface map (feature-specific)

```
 signed strategy intent (Merkle-authorized hook sequence)
        │
        ▼
 [ PendlePTHook ]  _processHook: setExecutionContext(acct) ─ preExecute(snapshot in+out bal)
        │                                                   ─ router call(s) into Pendle V4
        │                                                   ─ postExecute(compute in/out deltas,
        │                                                       set TradeResult{op,mkt,inTok,outTok,inAmt,outAmt})
        │            resetExecutionState(acct)  ← clears mutexes only; TradeResult PERSISTS (transient)
        ▼
 [ RecordPurchase/RedemptionPendlePTHook ]  build(): reads prevHook.getPendleTradeResult(acct)
        │            validates: prevHook==APPROVED, op matches, market matches, PT token matches,
        │                       resolvedAmount>0, twapDuration>=min (purchase)
        │            emits Execution → ORACLE.recordPurchase/recordRedemption(...)
        ▼
 [ PendlePTAmortizedOracleV2 ] msg.sender=acct; reads balanceOf(pt, acct), getPtToSyRate(twap)
```

**AS-1 — Trade-result storage lifetime (Critical design pivot).** If `getPendleTradeResult` is backed
by regular storage `mapping(address=>TradeResult)` instead of the transient, context-nonce-keyed
slots, then: (a) it survives across transactions → a later record-hook-only sequence reads a stale
trade; (b) it is not invalidated by a second same-tx trade beyond simple overwrite; (c) it leaks
across executions for the same account. Must reuse `_makeKey(context, offset)` (§23.7, §1.4).

**AS-2 — Prev-hook spoofing.** Without `prevHook == APPROVED_PENDLE_PT_HOOK`, any hook exposing the
`getPendleTradeResult`/`getOutAmount` selectors supplies attacker-chosen `op/market/amount`
(§44.1, §8.4, §2.1). The pinned immutable + strategy/Merkle auth is the two-layer defense.

**AS-3 — Market / PT-token / operation mismatch → oracle corruption.** The record hook's `market`
comes from its *own* calldata (offset 52), independent of the PendlePTHook trade. If not forced equal
to `TradeResult.market`, an attacker trades PT in market A and records `ptBought` into market B's book
value. Even the oracle's own `balanceOf(pt_B, strategy)` then references the *wrong* PT, so
`previousPtBalance = balanceOf - ptBought` may underflow-revert (DoS) or, if balances happen to line
up, silently corrupt market B's amortization (§44.2, §44.5, §14.3, §22.x).

**AS-4 — Balance-delta vs oracle-`balanceOf` desync.** Two independent measurements of "PT amount"
exist: (i) PendlePTHook's tight pre/post *delta* around the router; (ii) the oracle's
`balanceOf(strategy)` at record time. Anything that moves `account`'s PT between (i) and (ii) — a
same-sequence hook, a token-callback reentrancy (§1.5/§10.4), a direct donation (§22.2), fee-on-transfer
PT (§10.1/§46.1), or rebasing (§10.2/§46.2) — desyncs them and produces a DoS revert or wrong book
value. For SELL/REDEEM the new INPUT delta measures PT *leaving* the account; if PT is fee-on-transfer
the amount the router burns/credits differs from the account-side delta.

**AS-5 — TWAP-min bypass / thin-market manipulation.** Purchase path only. `twapDuration` is signed
calldata forwarded to the oracle, which enforces `>= getMinTwapDuration(market)`. Residual risk:
(a) `marketMinTwapDuration` left at the 300s default for a thin/L2 market (§48.7); (b) the market's
Pendle observation cardinality is too low for the requested window → `getPtToSyRate` reverts (DoS,
§48.11) or degrades. No cardinality pre-check exists.

**AS-6 — Redemption `NO_POSITION` / cost-basis DoS.** `recordRedemption` reverts if no prior purchase
was recorded (`state.lastUpdateTime == 0`) and `mulDiv`s by `previousPtBalance`
(`= balanceOf + ptSold`). A sell of PT acquired outside the recorder, or a `ptSold` larger than the
true prior balance, reverts the whole sequence (§7.4, §25.2).

**AS-7 — Matured-boundary op confusion.** SELL vs REDEEM is decided by `isExpired()` at execution
block. A recorder that hard-codes "redemption == SELL_PT only" DoS-reverts a legitimate at-maturity
redemption that routed to `REDEEM_PT`; a recorder that accepts a BUY result as a redemption
corrupts book value in the wrong direction (§14.4).

**AS-8 — Malicious market reentrancy during view build.** `market.readTokens()` in the record hook's
`build()` calls into a calldata-chosen address. `_processHook` is `nonReentrant`, but a griefing
market can returnbomb/revert to DoS (§13.1, Appendix H) or, if any state read is trusted, return a
crafted PT (§8.2, §44.5).

**AS-9 — Native ETH / sentinel asymmetry in the new INPUT snapshot.** `_getBalance` treats
`address(0)`/`0xEeee…` as native for the *output* side. The new input snapshot must handle the same
sentinels identically, or a native-input BUY mis-measures the input delta (§25.1 code asymmetry).
For PT the input is always an ERC-20 on SELL/REDEEM, but a BUY's input can be native — and BUY does
not need the input delta, so scope the input snapshot to the paths that use it.

---

## 4. Recommended defensive patterns (validation checklist)

Implement in the record hooks' `_buildHookExecutions` (view) and mirror invariants in the extended
`PendlePTHook._postExecute`.

**Prev-hook binding**
- [ ] `require(prevHook == APPROVED_PENDLE_PT_HOOK)` — constructor-pinned immutable; **no** ERC-165
      fallback (§2.1, §44.1, §8.4). New PendlePTHook ⇒ redeploy recorders (interview decision #1).
- [ ] Keep the existing strategy/Merkle authorization as the outer layer (defense in depth).

**Trade-result resolution (from `IPendlePTHookResult`)**
- [ ] Read `TradeResult` once via the pinned prevHook, for `account` (never a second, re-derived read).
- [ ] Store/read strictly in the transient, context-nonce-keyed slots (`_makeKey(context, offset)`) —
      never regular storage (§23.7, AS-1).

**Operation-type match**
- [ ] Purchase recorder: `require(op == BUY_PT)`; reject `SELL_PT`/`REDEEM_PT`/`NONE` (AS-7, §14.4).
- [ ] Redemption recorder: `require(op == SELL_PT || op == REDEEM_PT)`; reject `BUY_PT`/`NONE`.

**Market match**
- [ ] `require(recordHook.market == TradeResult.market)` — bind the recorded market to the *traded*
      market, not just a self-consistent one (AS-3, §44.2/§44.5).

**PT-token match** (defense against malicious `readTokens()`)
- [ ] Resolve `(, pt, ) = IPMarket(TradeResult.market).readTokens()`.
- [ ] Purchase: `require(TradeResult.outputToken == pt)` (PT is the OUTPUT of a BUY).
- [ ] Redemption: `require(TradeResult.inputToken == pt)` (PT is the INPUT of a SELL/REDEEM).
- [ ] Do the token check against the *same* `market` used for the record call (consistency, §25.4).

**Amount resolution & positivity**
- [ ] `resolvedAmount = usePrevHookAmount ? (op-specific delta) : encodedAmount`.
- [ ] Purchase uses `TradeResult.outputAmount`; redemption uses `TradeResult.inputAmount`
      — **never** `getOutAmount` for redemption (the motivating bug).
- [ ] `require(resolvedAmount > 0)` **after** resolution (encoded-0 allowed only when `usePrev`).
- [ ] Record the raw PT-unit amount; never rescale by decimals (§37.4).

**TWAP minimum (purchase only)**
- [ ] Forward the signed `twapDuration`; rely on the oracle's `>= getMinTwapDuration(market)` guard,
      and additionally assert it hook-side as defense in depth (§4.1, §48.7).
- [ ] Ops runbook: raise `marketMinTwapDuration` above 300s for thin / L2 markets before enabling
      them (§48.7). Consider a cardinality/oracle-state pre-check to convert a Pendle revert into a
      clear custom error (§48.11, AS-5).

**Decimals & layout**
- [ ] Treat PT decimals as market-specific; assert layout offsets with explicit constants and a
      decode unit test (§29.5, §14.1). Confirm `uint32 twapDuration` masking.

**DoS-minimization**
- [ ] Every new validation must be satisfiable by honest calldata (§7.4). Prefer specific custom
      errors over generic reverts so a griefing market can be told apart from a real misconfig.
- [ ] Do not add external calls in the record hook beyond `readTokens()` on the already-trusted
      market; keep the recorder's own `build()` free of untrusted calls (§7.2, §13.1, Appendix H).

**Passthrough integrity**
- [ ] Recorder stays `PipeMode.PASSTHROUGH` — forwards prevHook's outAmount/outToken unchanged so
      downstream hooks are unaffected (matches existing V2 `_pipeMode`, `RecordPurchase…V2.sol:177-179`).

**Extended `PendlePTHook` (input snapshot)**
- [ ] Snapshot input-token balance in `_preExecute` symmetrically with output; compute
      `inputAmount = inputBefore - inputAfter` in `_postExecute` (§25.1).
- [ ] Handle native/sentinel identically to `_getBalance` (AS-9).
- [ ] Populate `operation` from the *actual* routed branch (BUY/SELL/REDEEM incl. the expiry-block
      REDEEM case), not from the signer's intent (§14.4).
- [ ] Store the full `TradeResult` under the same transient context so lifetime == existing
      `outAmount` (survives `resetExecutionState`, dies at tx end / next `setExecutionContext`).

---

## 5. Testing recommendations

### 5.1 Core invariants (assert as properties, not just examples)
1. **I-BUY-DELTA:** after a BUY, `recorded ptBought == PendlePTHook.TradeResult.outputAmount ==
   (PT.balanceOf(account)_post − PT.balanceOf(account)_pre)`, in raw PT units.
2. **I-SELL-DELTA:** after a SELL/REDEEM, `recorded ptSold == TradeResult.inputAmount ==
   (PT.balanceOf(account)_pre − PT.balanceOf(account)_post)`; and `recorded ptSold != outputAmount`
   whenever `outputToken != PT` (guards the motivating bug).
3. **I-NO-LEAK:** for accounts A ≠ B traded in the same tx, B's recorder reads B's trade only;
   A's `outputAmount`/`inputAmount` never appears in B's recorded value.
4. **I-CTX-FRESH:** two PendlePTHook trades for the *same* account in one tx yield two independent
   `TradeResult`s; the second recorder never reads the first trade's values.
5. **I-TWAP-MIN:** `recordPurchase` reverts iff `twapDuration < getMinTwapDuration(market)`; property
   holds across the full `uint32` range and across default vs per-market configured minimums.
6. **I-OP-GATE:** purchase recorder reverts on `{SELL_PT, REDEEM_PT, NONE}`; redemption recorder
   reverts on `{BUY_PT, NONE}` — for all four `Operation` enum values.
7. **I-MARKET-BIND:** recorder reverts when `recordHook.market != TradeResult.market`, for arbitrary
   mismatched pairs.
8. **I-PT-BIND:** recorder reverts when the op-appropriate PT-side token
   (`outputToken` for BUY / `inputToken` for SELL-REDEEM) `!= market.readTokens().pt`.
9. **I-PREV-PIN:** recorder reverts when `prevHook != APPROVED_PENDLE_PT_HOOK`, including a mock that
   *implements* `getPendleTradeResult` with attacker values (phantom-interface case).
10. **I-BOOKVALUE-CONSISTENCY:** after a BUY recorded honestly, oracle
    `previousPtBalance = balanceOf − ptBought` does not underflow and
    `newBookValue <= currentPtBalance` (no spurious `BOOK_VALUE_EXCEEDS_FACE_VALUE`).
11. **I-PASSTHROUGH:** downstream `getOutAmount(account)`/`getOutToken(account)` after the recorder
    equal the PendlePTHook's output amount/token (recorder side-effect-only).

### 5.2 Fuzz scenarios
- **F1 amount modes:** fuzz `(encodedAmount, usePrevHookAmount)` including `encodedAmount==0 &&
  usePrev==true` (must succeed, record actual delta) and `resolvedAmount==0` (must revert
  `AMOUNT_NOT_VALID`). Both hooks.
- **F2 op routing near maturity:** fuzz `block.timestamp` around `pt.expiry()` (±1 block) with a
  SELL-format payload; assert the recorder accepts whichever of `SELL_PT`/`REDEEM_PT` actually
  routed, and `recordPurchase` reverts `MARKET_EXPIRED` for BUY at/after maturity.
- **F3 fee-on-transfer / rebasing PT & asset:** deploy mock PT and mock output-asset with configurable
  transfer fee and rebase; fuzz fee bps. Assert either a clean revert (preferred) or that recorded
  amount == the account-side delta the oracle will re-derive (no silent skew). Covers §10.1/§10.2/§46.x.
- **F4 balance perturbation between trade and record:** inject a hook/donation that moves
  `account`'s PT (in and out) between PendlePTHook post and the oracle call; assert no silent
  corruption — either revert or provably-correct book value (AS-4, §22.2).
- **F5 malicious market:** mock `market.readTokens()` returning attacker PT/SY/YT, reverting,
  returnbombing, and reentering; assert recorder reverts safely and `_processHook`'s `nonReentrant`
  holds (§44.5, §8.2, Appendix H).
- **F6 TWAP window sweep:** fuzz `twapDuration` and per-market min; on a low-cardinality fork market
  assert `getPtToSyRate` reverts are surfaced as a clear error, not a corrupted record (§48.7/§48.11).
- **F7 decimals matrix:** parametrize PT decimals ∈ {6,8,18} and asset decimals ∈ {6,8,18}; assert
  I-BUY-DELTA/I-SELL-DELTA and oracle scaling hold (§37.4).
- **F8 layout/offset fuzz:** property-test the calldata decoders (market/amount/twapDuration/bool)
  against `encodeSwapData`-style builders to catch offset drift (§14.1, §29.5).

### 5.3 Fork tests (mainnet + each deployed L2)
- Real PT purchase reproduction of the motivating tx
  `0x62582b07d6c667822af3f1bb03ab2bfa5687cfb1ef7c068df23265ae2c7385fa`: BUY then purchase recorder
  with `encodedAmount==0 && usePrev==true`; assert recorded PT == received PT and **no**
  `syAccountingAssetSpent` input is required.
- Real SELL and a real matured REDEEM on a live Pendle market: assert `ptSold == input delta`, never
  the received-asset amount.
- Manual mode on all three: non-zero `encodedAmount`, `usePrev==false`.
- TWAP-min fork check on the thinnest deployed market: confirm the configured `marketMinTwapDuration`
  actually rejects a manipulatable short window.

### 5.4 Negative / DoS tests
- Recorder reverts cleanly (specific error) for: wrong prevHook, op mismatch (both directions),
  market mismatch, PT-token mismatch, sub-min twap, matured BUY, `NO_POSITION` redemption,
  `ptSold > prior balance`. Each must revert the whole sequence *atomically* with a distinguishable
  error (§7.4, §25.2).
- Griefing market that returnbombs `readTokens()` / `getPtToSyRate()` — assert bounded gas, no
  executor lock-up (§13.1, Appendix H).

---

## 6. Top risks, ranked

1. **AS-1 / §23.7 — trade-result stored outside the transient context** (Critical if mis-implemented):
   collapses all cross-account / cross-execution isolation. This is the feature's central invariant.
2. **AS-2 / §44.1 §2.1 — missing pinned prev-hook binding** (Critical): attacker-supplied
   op/market/amount. Mitigated by the constructor-pinned `APPROVED_PENDLE_PT_HOOK`.
3. **AS-3 / §44.2 §44.5 — market / PT-token / op mismatch** (High→Critical): records a real trade into
   the wrong market's book value; Penpie-shaped market-trust bug.
4. **AS-4 / §10.1 §10.2 §22.2 — delta vs oracle-`balanceOf` desync** (High): DoS or silent
   mis-amortization from fee-on-transfer/rebasing/donation/callback between trade and record.
5. **AS-5 / §4.1 §48.7 — TWAP-min / thin-market** (High, purchase only): weak default window on L2
   thin markets; ensure per-market minimums are raised and cardinality is sufficient.
6. **AS-6/AS-7 / §7.4 §14.4 — record-step reverts & matured-op confusion** (Medium→High): whole-
   sequence DoS; must accept both SELL and REDEEM as redemptions.

---

## Sources

- **Primary:** Superform internal vulnerability DB — `guidelines/solidity/vulnerabilities.md`
  (resolved at `/Users/cosming/1.Coding/Superform/superform-specs/guidelines/solidity/vulnerabilities.md`).
  Sections cited inline: §1.2–§1.5, §2.1, §4.1–§4.2, §5.1, §7.2/§7.4, §8.2/§8.4, §10.1–§10.4,
  §13.1, §14.1/§14.3/§14.4, §21.4, §22.2, §23.7, §24.2, §25.1–§25.4, §28, §29.5, §37.4, §40.1,
  §44.1/§44.2/§44.5, §46.1–§46.3, §48.1/§48.6/§48.7/§48.11; Appendices C, H, L, M.1/M.4.
- **Code (grounding), all under `/Users/cosming/1.Coding/Superform/v2-core`:**
  `src/hooks/swappers/pendle/PendlePTHook.sol`,
  `src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol`,
  `src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol`,
  `src/accounting/oracles/PendlePTAmortizedOracleV2.sol`,
  `src/hooks/BaseHook.sol`, `src/executors/SuperExecutorBase.sol`.
- **Feature spec:** `specs/pendle-pt-record-hooks/interview-notes.md`.
- **External (named; exact URLs pending — web-search budget for this session was exhausted):**
  Penpie post-mortem (Sep 2024, ~$27M) — corroborated by DB §48.1 / Appendix C / M.1 and the
  Rekt.News leaderboard (DB Appendix L); Curve Finance reentrancy (Jul 2023, $69M, DB §1.4 /
  Appendix C); Cork Protocol Uniswap-V4-hook incident (May 2025, $11M, DB §44.1/§44.2);
  Code4rena *Predy* TWAP finding (May 2024, DB §48.7). Pull exact links from the vendor
  post-mortems (BlockSec/Cyfrin/CertiK) and Pendle oracle docs (`docs.pendle.finance`, PT/YT/LP
  oracle + `increaseObservationsCardinalityNext`) when budget is available.
