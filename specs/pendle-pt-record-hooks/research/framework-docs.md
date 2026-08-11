# Pendle V2/V4 PT Mechanics & Router/Market Interfaces — Framework Docs

Research for `specs/pendle-pt-record-hooks`. Goal: correctly **identify** and **account** a PT trade
(buy / sell / redeem) from an integrating smart contract, and understand the on-chain rate math the
amortized oracle depends on.

Repo under study: `/Users/cosming/1.Coding/Superform/v2-core`.

## Source hierarchy used (most authoritative first)

1. **The repo's own vendored Pendle library** — `lib/pendle-core-v2-public/` (this is Pendle Labs'
   public core-v2 code, a git submodule). Signatures and math here are the ground truth for what the
   deployed contracts actually do.
2. **The repo's slimmed vendored interfaces** — `src/vendor/pendle/*.sol` (only the selectors the
   hooks need).
3. **The repo's consumers** — `src/hooks/swappers/pendle/*.sol`, `src/hooks/oracles/pendle/*.sol`,
   `src/accounting/oracles/PendlePTAmortizedOracle*.sol`.
4. **Official Pendle docs** — `https://docs.pendle.finance/` (Developers section). NOTE: the docs
   site is a client-rendered SPA; deep-link paths could not be fetched during this research (all
   returned 404 to a server-side fetch or rendered only the page title). Cite the domain, but the
   code in (1) is the binding reference. Cross-check any doc URL manually before shipping.

---

## 1. `IPendleMarket.readTokens()` → `(SY, PT, YT)`

**Signature (repo vendored, slim):**
`src/vendor/pendle/IPendleMarket.sol:5`
```solidity
function readTokens() external view returns (address sy, address pt, address yt);
```

**Signature (full Pendle lib):** `lib/pendle-core-v2-public/contracts/interfaces/IPMarket.sol`
returns typed tokens:
```solidity
function readTokens() external view returns (IStandardizedYield _SY, IPPrincipalToken _PT, IPYieldToken _YT);
```
Used this way in `PendlePTAmortizedOracleV2.sol:172` — `(, IPPrincipalToken pt,) = IPMarket(market).readTokens();`
and in the Pendle oracle lib `getSYandPYIndexCurrent` (`PendlePYOracleLib.sol`):
`(IStandardizedYield SY, , IPYieldToken YT) = market.readTokens();`.

**Semantics — the ordering is fixed and positional:**
- **index 0 = SY** (Standardized Yield): an ERC-4626-like wrapper (`IStandardizedYield`) that
  normalizes any yield-bearing token into a "shares" token. `SY.exchangeRate()` converts SY → asset
  (`assetBalance = exchangeRate * syBalance / 1e18`), see `src/vendor/pendle/IStandardizedYield.sol:102-108`.
- **index 1 = PT** (Principal Token): the zero-coupon claim on 1 unit of the SY's underlying at
  maturity. **This is "the PT".** It is what the strategy holds and what we account.
- **index 2 = YT** (Yield Token): the claim on the yield accrued between now and maturity.

**Every consumer in the repo relies on this positional contract.** Examples:
- `PendlePTHook.sol:202` — `(address sy, address pt, address yt) = IPendleMarket(yieldSource).readTokens();`
  then routes on `headerOutputToken == pt` / `headerInputToken == pt`.
- `PendleUnifiedHook.sol:384, 518, 611` — same destructuring.
- Oracle helpers `_pt()` / `_sy()` (`PendlePTAmortizedOracleV2.sol:562-571`) index positions 1 and 0.

**Trust caveat (already documented in the hooks):** `readTokens()` is only as trustworthy as the
`market` address. A malicious/rogue market can return attacker-controlled addresses. Both
`PendlePTHook` (lines 72-75) and `PendleUnifiedHook` (lines 56-67) explicitly push market
whitelisting up to the intent signer — the hook does NOT whitelist markets. Any new record/accounting
hook must inherit the same assumption: the market passed to `recordPurchase`/`recordRedemption` is
trusted from the signed intent, and PT identity is whatever position-1 of that market says.

---

## 2. `YT.isExpired()` / maturity — SELL vs REDEEM, and why post-maturity redeem is ~1:1 PT→asset

**Relevant selectors (repo vendored):** `src/vendor/pendle/IPYieldToken.sol`
```solidity
function SY() external view returns (address);
function PT() external view returns (address);
function expiry() external view returns (uint256);     // maturity timestamp
function isExpired() external view returns (bool);
```
`IPPrincipalToken.expiry()` returns the same maturity (used at `PendlePTAmortizedOracleV2.sol:173`
via `pt.expiry()`); PT and YT of a market share one expiry.

**How the integrator distinguishes the two operations** — canonical logic lives in
`PendlePTHook._buildHookExecutions` (`PendlePTHook.sol:205-229`):

| Condition | Operation | Router call |
|---|---|---|
| `outputToken == PT && inputToken != PT` | **BUY** | `swapExactTokenForPt` |
| `inputToken == PT && outputToken != PT && !YT.isExpired()` | **SELL** (pre-maturity) | `swapExactPtForToken` |
| `inputToken == PT && outputToken != PT && YT.isExpired()` | **REDEEM** (post-maturity) | `redeemPyToToken` |
| anything else | revert `INVALID_PT_OPERATION()` | — |

The maturity gate is a **runtime `YT.isExpired()` call**, not a stored flag
(`PendlePTHook.sol:215`). Important boundary note the hook documents itself (`PendlePTHook.sol:54-55`):
**at the exact expiry block `isExpired()` returns `true`**, so the boundary block routes to redeem. A
sell-format payload that lands on the redeem path is benign — redeem decodes no payload.

**Why the two paths are economically different:**
- **Before maturity** the AMM (SELL via `swapExactPtForToken`) prices PT at a *discount* to its face
  value — PT trades below 1 asset because the yield still belongs to YT holders. Price is set by the
  market's implied rate (see §5). You are selling into a pool and pay market spread + `netSyFee`.
- **At/after maturity** PT has fully "pulled to par": **1 PT is redeemable for 1 SY of face value**,
  independent of the AMM. This is the defining property of a zero-coupon token.

**Grounded proof that redemption is ~1:1 PT→SY (not PT→asset):** the Pendle oracle lib returns par
at expiry — `getPtToAssetRateRaw` (`PendlePYOracleLib.sol:64-76`):
```solidity
uint256 expiry = market.expiry();
if (expiry <= block.timestamp) {
    return PMath.ONE;      // 1 PT = 1 asset(*) at/after expiry
}
```
and the repo's oracle mirrors this — `_calculateBookValue` returns the raw PT amount at maturity
(`PendlePTAmortizedOracleV2.sol:370-372`): `if (block.timestamp >= maturity) return currentPtAmount;`
because **book value is stored in SY terms and 1 PT = 1 SY at maturity**.

**Subtlety that matters for accounting (SY vs asset at par):** "1:1" is *PT→SY*, not necessarily
*PT→underlying-asset*. For a yield-bearing SY (e.g. wstETH SY where `exchangeRate() > 1`), 1 PT = 1 SY
= *more than 1 unit of the nominal asset*. The repo is deliberate about keeping book value in **SY
terms** to avoid a unit mismatch — see the extended comment at `PendlePTAmortizedOracleV2.sol:344-372`
("Using `getAssetOutput` would convert to asset terms, causing unit mismatch for yield-bearing SY
tokens"). This is why the "1:1-ish" wording is correct: exactly 1:1 in SY, and the SY→asset leg is a
separate `redeemPyToToken` conversion handled by the router.

**Redeem requires BOTH PT and YT before expiry, PT only after.** In Pendle, `redeemPyToToken` burns
**PY** = PT **and** YT together (that's what "PY" means). Before expiry you must supply equal PT+YT.
After expiry the YT is worthless/auto-satisfied and effectively only PT is needed. The redeem hooks
approve **both** PT and YT to the router regardless (`PendlePTHook._buildRedeemExecutions` lines
544-580 approve PT and YT; `PendleUnifiedHook._buildRedeemExecutions` lines 414-449 same;
`PendleRouterRedeemHook.sol:118-133` approves PT and YT). Since these hooks only reach the redeem path
post-maturity, the YT approval is a safe superset. If a future hook allows pre-maturity PY redemption,
the YT balance requirement becomes load-bearing.

---

## 3. `PendleRouterV4` — buy / sell / redeem selectors, I/O, and which side is PT

**Repo vendored interface:** `src/vendor/pendle/IPendleRouterV4.sol` (with the supporting structs
`ApproxParams`, `TokenInput`, `TokenOutput`, `LimitOrderData`, `SwapData`, enums `SwapType`,
`OrderType`). PragMa `0.8.30`.

### 3a. BUY — `swapExactTokenForPt` (PT is the OUTPUT)
```solidity
function swapExactTokenForPt(
    address receiver,
    address market,
    uint256 minPtOut,
    ApproxParams calldata guessPtOut,
    TokenInput calldata input,
    LimitOrderData calldata limit
) external payable returns (uint256 netPtOut, uint256 netSyFee, uint256 netSyInterm);
```
- Input side is an arbitrary token (`TokenInput.tokenIn`, mints SY via `tokenMintSy`); output is PT to
  `receiver`. `guessPtOut` is the off-chain binary-search hint (Pendle prices PT via approximation).
- Returns `netPtOut` (PT received — **this is the amount to record as the purchase**), `netSyFee`,
  and `netSyInterm` (SY that transited internally).
- Native ETH: pass `tokenIn == address(0)` and send `value`. The `0xEeee…` sentinel is normalized to
  `address(0)` (`PendlePTHook.sol:392-394`).
- Built at `PendlePTHook.sol:406-409` and `PendleUnifiedHook.sol:538-542`.

### 3b. SELL — `swapExactPtForToken` (PT is the INPUT, pre-maturity)
```solidity
function swapExactPtForToken(
    address receiver,
    address market,
    uint256 exactPtIn,
    TokenOutput calldata output,
    LimitOrderData calldata limit
) external returns (uint256 netTokenOut, uint256 netSyFee, uint256 netSyInterm);
```
- Input is an **exact PT amount** (`exactPtIn` — the amount to record as sold/reduced); output is
  `output.tokenOut`. No `ApproxParams` (exact-in has nothing to approximate).
- Returns `netTokenOut`, `netSyFee`, `netSyInterm`.
- Built at `PendlePTHook.sol:499-503` and `PendleUnifiedHook.sol:648-651`.

### 3c. REDEEM — `redeemPyToToken` (PY = PT+YT is the INPUT, post-maturity path in this repo)
```solidity
function redeemPyToToken(
    address receiver,
    address YT,
    uint256 netPyIn,
    TokenOutput calldata output
) external returns (uint256 netTokenOut, uint256 netSyInterm);
```
- **Second arg is the YT address, not the market.** `netPyIn` is the PY (PT+YT) amount burned; after
  maturity this equals the PT amount redeemed. Output is `output.tokenOut`.
- Returns `netTokenOut`, `netSyInterm`. **Note: no `netSyFee`** — redemption at par charges no swap
  fee (consistent with the 1:1 par property in §2).
- No `LimitOrderData` / no `ApproxParams` — there is no market trade, so nothing to limit-order or
  approximate.
- Built at `PendlePTHook.sol:568`, `PendleUnifiedHook.sol:435-438`, `PendleRouterRedeemHook.sol:129-133`.
  All pass the **YT** address as arg 2 (derived from `readTokens()` index 2).

### 3d. Also present: `mintPyFromToken` (inverse of redeem), `createTokenOutputSimple` (helper).
Not used by the PT record/account path but in the vendored interface (`IPendleRouterV4.sol:118-137`).

### Selector-based routing (PendleUnifiedHook)
`PendleUnifiedHook` decodes an explicit `bytes4 selector` and validates it is one of the three
(`PendleUnifiedHook.sol:176-182`). `PendlePTHook` instead derives the op purely from
header-token direction + expiry (no selector). Either is a valid way to identify the trade; the
record/accounting hook should agree with whichever swapper produced the PT delta.

**Which side is PT, at a glance:**
| Function | PT side | Amount to account |
|---|---|---|
| `swapExactTokenForPt` | output | `netPtOut` (return) — increase |
| `swapExactPtForToken` | input | `exactPtIn` (arg) — decrease |
| `redeemPyToToken` | input (as PY) | `netPyIn` (arg) — decrease |

---

## 4. PT vs SY vs asset, and what "SY accounting cost" of a PT purchase means

**The three-layer stack:**
```
underlying asset  ──deposit──►  SY (shares)  ──split──►  PT + YT
   (e.g. stETH)     exchangeRate   (1 SY ≈ 1 asset       PT = principal at maturity
                                    at mint, drifts up)   YT = yield until maturity
```
- **asset ↔ SY:** `SY.exchangeRate()` (`IStandardizedYield.sol:102-108`). For non-rebasing
  yield-bearing SY the rate grows over time (1 SY buys more asset later).
- **SY ↔ PT+YT:** at any time `PT_value + YT_value = 1 SY` (of face). At maturity `PT = 1 SY`,
  `YT = 0`.
- **PT ↔ asset (pricing):** `getPtToAssetRate` combines the PT/SY implied-rate discount with the
  live SY exchange rate (`PendlePYOracleLib.sol:19-26`).

**"SY accounting cost" of a PT purchase** = the number of SY units the position's book value is
credited with when PT is bought, i.e. the **cost basis expressed in SY**, not in the input token and
not in the underlying asset. This is the core V2 design decision.

- **V1** (`IPendlePTAmortizedOracle.sol` / `PendlePTAmortizedOracle.sol`) took `sySpent` as an
  explicit caller-supplied parameter (`recordPurchase(market, sySpent, ptAmount)`), i.e. the cost was
  computed off-chain.
- **V2** (`IPendlePTAmortizedOracleV2.sol` / `PendlePTAmortizedOracleV2.sol`) computes it **on-chain**
  from the PT→SY rate — this is the calc your spec cares about
  (`PendlePTAmortizedOracleV2.sol:180-181`):
  ```solidity
  uint256 ptToSyRate = IPMarket(market).getPtToSyRate(twapDuration);   // 1e18-scaled SY per PT
  uint256 sySpent    = ptBought.mulDiv(ptToSyRate, 1e18);              // cost basis in SY
  ```
  `getPtToSyRate` is deliberately used **instead of** `getPtToAssetRate` (see the extended rationale
  at `PendlePTAmortizedOracleV2.sol:157-179`): book value must live in SY units because
  **1 PT = 1 SY at maturity regardless of the SY→asset exchange rate**. Using an asset-denominated
  rate would fold the SY exchange rate into the basis and break amortization for yield-bearing SY.

**How the SY cost basis is then amortized** (this is the "amortized oracle" behavior):
`B(t) = A - (A - B(t0)) * (T - t) / (T - t0)` where `A` = PT face amount, `B(t0)` = SY book value at
last update, `T` = maturity (`PendlePTAmortizedOracleV2.sol:378-422`). Book value pulls linearly from
the discounted purchase cost (in SY) up to face value `A` at maturity — a "pull-to-par" / straight-line
accretion of the PT discount. Sanity invariant enforced: `newBookValue <= currentPtBalance`
(book value in SY can never exceed PT face; `PendlePTAmortizedOracleV2.sol:200-201`).

**Redemption accounting** reduces book value proportionally (cost-basis method), not by market price
(`PendlePTAmortizedOracleV2.sol:233-235`):
`costBasis = currentBookValue * ptSold / previousPtBalance; newBookValue -= costBasis;`.

**Wiring:** the swapper hook emits the PT delta; the record hook forwards it to the oracle. The V2
record hook reads `ptAmount` (optionally from the previous hook's `getOutAmount`) plus a `twapDuration`
and calls `recordPurchase(address,uint256,uint32)` — `RecordPurchasePendlePTAmortizedOracleHookV2.sol:97-116`.
`recordRedemption(market, ptSold)` takes no twap (redeem is at par).

---

## 5. TWAP oracle on Pendle markets — observations, cardinality, min duration

Pendle markets embed a **Uniswap-V3-style observation ring buffer** over the market's
`lnImpliedRate`. The TWAP rate is derived from cumulative observations, so a meaningful `twapDuration`
requires the buffer to (a) be large enough (**cardinality**) and (b) already hold an observation old
enough to cover the window.

**Market-level primitives** (`lib/pendle-core-v2-public/contracts/interfaces/IPMarket.sol`):
```solidity
function observe(uint32[] memory secondsAgos) external view returns (uint216[] memory lnImpliedRateCumulative); // :66
function increaseObservationsCardinalityNext(uint16 cardinalityNext) external;                                    // :68
function observations(uint256 index) external view returns (uint32 blockTimestamp, uint216 lnImpliedRateCumulative, bool initialized);
// _storage() exposes: observationIndex, observationCardinality, observationCardinalityNext (:88-91)
```

**How duration → cumulative rate** (`PendlePYOracleLib.getMarketLnImpliedRate`,
`PendlePYOracleLib.sol:96-118`):
```solidity
if (duration == 0) { /* read spot lnImpliedRate from _storage() */ }
else {
    uint32[] memory durations = new uint32[](2);
    durations[0] = duration;                       // durations[1] == 0 (now)
    uint216[] memory cum = market.observe(durations);
    return (cum[1] - cum[0]) / duration;           // time-weighted average
}
```
So `twapDuration == 0` is **spot** (single storage read, flash-loan manipulable); any `> 0` is a true
TWAP requiring buffered history.

**Cardinality requirement & oldest-observation check** — from Pendle's own oracle
(`PendlePYLpOracle.getOracleState`, `PendlePYLpOracle.sol:84-107`), also surfaced via the repo's
`IPPYLpOracle.getOracleState` (`src/vendor/pendle/IPPYLpOracle.sol:19-25`):
```solidity
returns (bool increaseCardinalityRequired, uint16 cardinalityRequired, bool oldestObservationSatisfied)
```
- `cardinalityRequired = ceil(duration * 1000 / blockCycleNumerator) + 1`
  (`_calcCardinalityRequiredRequired`, `PendlePYLpOracle.sol:109-117`), where
  `BLOCK_CYCLE_DENOMINATOR = 1000`. `blockCycleNumerator` is chain-tuned so `numerator/1000` is just
  below the real block time: **Ethereum = 11000** (11s < 12s), **Arbitrum = 1000**
  (`PendlePYLpOracle.sol:20-26`). Larger implied block time ⇒ fewer slots needed per second of TWAP.
- `increaseCardinalityRequired = cardinalityReserved < cardinalityRequired` — if true, someone must
  call `increaseObservationsCardinalityNext(cardinalityRequired)` and then wait for the buffer to
  fill before that duration is usable.
- `oldestObservationSatisfied = oldestTimestamp < block.timestamp - duration` — the ring must already
  contain a sample at least `duration` seconds old (`PendlePYLpOracle.sol:99-106`).
- `_calcCardinalityRequiredRequired` **reverts `TwapDurationTooLarge`** if the requirement overflows
  `uint16` (`PendlePYLpOracle.sol:113-114`) — an upper bound on `twapDuration`.

**Enforcing a `twapDuration` minimum (the spec's concern)** — the repo does NOT rely on Pendle to
reject short windows; it enforces its own floor in `PendlePTAmortizedOracleV2`:
- `recordPurchase` reverts `TWAP_DURATION_TOO_SHORT` when `twapDuration < getMinTwapDuration(market)`
  (`PendlePTAmortizedOracleV2.sol:169`).
- `getMinTwapDuration(market)` returns the per-market override if set, else `DEFAULT_MIN_TWAP_DURATION`
  (`PendlePTAmortizedOracleV2.sol:333-339`).
- Constants: `DEFAULT_TWAP_DURATION = 900` (15 min, used by the `IYieldSourceOracle` views),
  `DEFAULT_MIN_TWAP_DURATION = 300` (5 min). The 5-min floor is justified in-code as flash-loan
  manipulation resistance vs. spot (`PendlePTAmortizedOracleV2.sol:39-48`,
  `error TWAP_DURATION_TOO_SHORT` at :128-130). Manager can raise/lower per market via
  `setMinTwapDuration` (:320-331).

**Practical integration checklist for a new record/accounting hook:**
1. Choose `twapDuration >= oracle.getMinTwapDuration(market)` (default 300s; the code's own default
   working value is 900s).
2. Before first use of a market at a given duration, off-chain call `getOracleState(market, duration)`;
   if `increaseCardinalityRequired`, send `increaseObservationsCardinalityNext(cardinalityRequired)`
   and wait until `oldestObservationSatisfied` becomes true (buffer must age `duration` seconds).
3. Never pass `twapDuration == 0` for accounting — it is spot and manipulable, and the oracle's
   min-duration guard will revert anyway.
4. `recordPurchase` also reverts `MARKET_EXPIRED` if `block.timestamp >= pt.expiry()`
   (`PendlePTAmortizedOracleV2.sol:173-174`) — post-maturity you record via `recordRedemption`, which
   needs no TWAP because value is at par.

---

## Version-specific caveats / flags

- **Oracle V1 vs V2 API mismatch.** V1 `recordPurchase(market, sySpent, ptAmount)` (off-chain cost)
  vs V2 `recordPurchase(market, ptBought, twapDuration)` (on-chain cost via `getPtToSyRate`). The
  V1/V2 record hooks are not interchangeable — the calldata signatures differ
  (`abi.encodeWithSignature("recordPurchase(address,uint256,uint32)", ...)` in the V2 hook,
  `RecordPurchasePendlePTAmortizedOracleHookV2.sol:115`). Ensure the swapper→record→oracle triple is
  all-V1 or all-V2.
- **`getPtToSyRate` vs `getPtToAssetRate` is not interchangeable.** Book value is in SY. Swapping the
  call would silently corrupt accounting for yield-bearing SY (`exchangeRate != 1`). This is the
  single most important correctness invariant in the accounting path
  (`PendlePTAmortizedOracleV2.sol:157-181, 344-372`).
- **`redeemPyToToken` takes the YT address as its second argument, not the market.** Easy to get
  wrong; all three redeem hooks pass `yt` from `readTokens()` index 2.
- **Expiry boundary routing.** `isExpired()` is `true` at the exact expiry block, routing to redeem;
  the AMM sell path is unavailable from that block on (`PendlePTHook.sol:54, 215`).
- **Pre-maturity redeem needs equal PT and YT.** The repo's redeem paths only trigger post-maturity,
  where PT alone suffices, but they defensively approve both. Any change that permits pre-maturity PY
  redemption makes the YT balance a hard requirement.
- **`PendleRouterSwapHook` is deprecated** (`src/hooks/swappers/pendle/deprecated/`), superseded by
  `PendleUnifiedHook`. `PendleRouterRedeemHook` is marked `@custom:deprecated` in favor of
  `PendleUnifiedHook` (`PendleRouterRedeemHook.sol:39`). Prefer `PendlePTHook` (pure PT ops) or
  `PendleUnifiedHook` (selector-driven, supports aggregator swap legs) for new work.
- **Solidity pragma split.** Repo-authored vendored interfaces + hooks + oracle pin `0.8.30`; the
  upstream `lib/pendle-core-v2-public` files use `^0.8.0`. The slim `IStandardizedYield` / `IPYieldToken`
  in `src/vendor/pendle` are intentionally reduced subsets of the upstream interfaces — if you need
  `pyIndexStored()`, `doCacheIndexSameBlock()`, `pyIndexLastUpdatedBlock()` (used by
  `getSYandPYIndexCurrent`), pull the full upstream `IPYieldToken`.
- **Trust boundary is the market address.** No hook whitelists markets; `readTokens()` output is only
  as good as the signed market. Keep this assumption explicit in the new hook's docstring, mirroring
  the existing hooks.

---

## Key file references (all absolute)

Vendored interfaces:
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendleMarket.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendleRouterV4.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPYieldToken.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IStandardizedYield.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPPYLpOracle.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendlePTAmortizedOracle.sol` (V1)
- `/Users/cosming/1.Coding/Superform/v2-core/src/vendor/pendle/IPendlePTAmortizedOracleV2.sol` (V2)

Swapper hooks:
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/PendlePTHook.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/PendleUnifiedHook.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/PendleRouterRedeemHook.sol` (deprecated)
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/swappers/pendle/deprecated/PendleRouterSwapHook.sol` (deprecated)

Oracle + record/redemption hooks:
- `/Users/cosming/1.Coding/Superform/v2-core/src/accounting/oracles/PendlePTAmortizedOracleV2.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/accounting/oracles/PendlePTAmortizedOracle.sol` (V1)
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHook.sol` (V1)
- `/Users/cosming/1.Coding/Superform/v2-core/src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHook.sol` (V1)

Upstream Pendle library (submodule) — ground truth for math:
- `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/oracles/PtYtLpOracle/PendlePYOracleLib.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/oracles/PtYtLpOracle/PendlePYLpOracle.sol`
- `/Users/cosming/1.Coding/Superform/v2-core/lib/pendle-core-v2-public/contracts/interfaces/IPMarket.sol`

Official docs (SPA — verify paths in a browser; server-side fetch returned 404s during research):
- Pendle Developer docs: `https://docs.pendle.finance/` → Developers → Oracles / Contracts.
