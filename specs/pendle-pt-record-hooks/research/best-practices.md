# Best Practices — Composable On-Chain Hook Pipelines that Pass Trade Results Between Steps

Research for `pendle-pt-record-hooks`: a `PendlePTHook` swap (BUY_PT / SELL_PT / REDEEM_PT)
immediately followed by a `RecordPurchasePendlePTHook` / `RecordRedemptionPendlePTHook` that must
record into `PendlePTAmortizedOracleV2` the **actual** PT amount moved by the preceding swap, read
from balance deltas, not from quoted amounts.

Scope note: this is written against the patterns already in `v2-core` (`src/hooks/BaseHook.sol`,
`src/hooks/swappers/pendle/PendlePTHook.sol`, `src/accounting/oracles/PendlePTAmortizedOracleV2.sol`,
`src/hooks/oracles/pendle/Record*PendlePTAmortizedOracleHookV2.sol`) so the recommendations match the
codebase rather than a greenfield design.

---

## 0. How this pipeline actually executes (context for the rest)

Every hook in `v2-core` runs as a 3-part `Execution[]` built by `BaseHook.build()`:
`preExecute` first, hook body in the middle, `postExecute` last (`src/hooks/BaseHook.sol`). The
ERC-7579 account replays these `Execution`s in order in a single transaction. A "following hook" is
therefore just the next set of executions in the same call frame sequence; it can read the previous
hook's already-committed result synchronously.

This maps cleanly onto ERC-7579's own execution model. Executor modules drive the account through
`executeFromExecutor` (which "MUST ensure adequate authorization control: i.e. onlyExecutorModule"),
and the standard's hook mechanism is explicitly a pre/post pair where `preCheck` "MAY return arbitrary
data in the `hookData` return value" and `postCheck` "MAY validate the `hookData` to validate
transaction context" — i.e. the standard itself endorses carrying context between the pre and post
phases rather than through calldata ([ERC-7579](https://eips.ethereum.org/EIPS/eip-7579)). Our
`getOutAmount(account)` / proposed `getPendleTradeResult(account)` read is the same idea generalized
to "next hook reads previous hook's result."

Two ERC-7579 warnings that bear on this feature:
- "Malicious Hooks may revert on `preCheck` or `postCheck`, adding untrusted hooks may lead to a
  denial of service of the account." The record hook is only as trustworthy as the swap hook it reads
  from — hence the trust-pinning in §3.
- The standard "delegates authorization responsibility to individual account implementations." So the
  hook pair must not assume the account/executor validated the ordering; it must self-validate the
  operation and the source (§1, §3).

---

## 1. Exposing a "trade result" from one hook to the immediately-following hook

### The shape to expose

The proposed interface is the right level of detail because it makes the recorder's job total (no
inference from a single output value):

```solidity
interface IPendlePTHookResult {
    enum Operation { NONE, BUY_PT, SELL_PT, REDEEM_PT }
    struct TradeResult {
        Operation operation;
        address market;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
    }
    function getPendleTradeResult(address account) external view returns (TradeResult memory);
}
```

Key design point: the generic `ISuperHookResult` only exposes *output* token + amount
(`getOutAmount`/`getOutToken`, `src/interfaces/ISuperHook.sol`). That is sufficient for a purchase
(PT is the output) but structurally wrong for a sale/redemption (PT is the *input*; output is the
asset received). Exposing `operation + input{Token,Amount} + output{Token,Amount}` lets the purchase
recorder read `outputAmount` and the redemption recorder read `inputAmount` from the same struct,
which is exactly the motivating-bug fix. Expose the `Operation` enum too so the recorder can *assert*
the preceding op (BUY vs SELL/REDEEM) rather than trusting calldata ordering.

### Where to store it — three options and the trade-off

**(a) Persistent storage mapping (`mapping(address account => TradeResult)`).**
Simple, but wrong for this use case. It survives past the transaction, so a stale result from a prior
tx can be read by a later, unrelated tx if the writer forgets to clear or the reader forgets to
validate freshness. It also permanently pays cold-`SSTORE`/`SLOAD` gas for data whose entire lifetime
is one transaction. Only justified when a *later* transaction legitimately needs the value.

**(b) Transient storage, EIP-1153 (recommended, and what the codebase already does).**
`BaseHook` already keeps its execution context in transient storage: `usedShares`, `spToken`,
`asset`, `executionNonce`, `lastCaller` use the `transient` keyword, and `outAmount`/`outToken`/mutexes
are `tstore`/`tload` under keys derived from a per-account context
(`_makeAccountContextKey(account)` + a monotonic `executionNonce`). EIP-1153 guarantees "All values in
transient storage are discarded at the end of the transaction"
([EIP-1153](https://eips.ethereum.org/EIPS/eip-1153)), which gives automatic, gas-free cleanup and —
critically — **no cross-transaction leakage**: a `TradeResult` written in tx N cannot be read in
tx N+1. OpenZeppelin ships `TransientSlot` and `ReentrancyGuardTransient` on the same primitive and
documents the same lifetime guarantee
([OZ Utils](https://docs.openzeppelin.com/contracts/5.x/api/utils#TransientSlot)).

The right move here is **not** to add new transient-storage machinery but to extend the existing
per-account context: `PendlePTHook` currently snapshots only the output balance in `_preExecute` and
sets `outAmount = balanceAfter - balanceBefore` in `_postExecute`. Add an input-token snapshot in
`_preExecute` and an `inputAmount` delta + `operation` + `inputToken` in `_postExecute`, stored under
the same `context` key namespace, and surface them through `getPendleTradeResult(account)`. This reuses
the account-keying and nonce that already prevent cross-account and cross-execution leaks.

**(c) Same-flow read of the per-account context (this is what (b) enables).**
Because the record hook's `build`/`preExecute` runs in the *same* execution sequence, right after the
swap hook's `postExecute`, it reads the fresh transient context directly — no message-passing, no
calldata, no separate storage. This is already the mechanism `usePrevHookAmount` uses today
(`RecordPurchasePendlePTAmortizedOracleHookV2` calls
`ISuperHookResult(prevHook).getOutAmount(account)` inside `_buildHookExecutions`).

### Avoiding cross-execution leakage — the non-negotiables

1. **Key by account.** All reads/writes go through `_makeAccountContextKey(account)` so two accounts
   in the same bundle can't read each other's result.
2. **Key by execution nonce.** `BaseHook._createExecutionContext` increments `executionNonce` per
   context, so a second swap+record pair in the same tx gets a distinct slot; the recorder always
   reads the *current* context, not a leftover.
3. **Enforce completion + ordering with the mutexes.** `preExecute`/`postExecute` are guarded by
   `PRE_EXECUTE_MUTEX`/`POST_EXECUTE_MUTEX` so each fires once and in order. The recorder should only
   trust a `TradeResult` after the swap hook's post-phase has run (operation != NONE is a good sentinel;
   `NONE` means "not populated in this context" and must revert).
4. **Follow EIP-1153's slot-hygiene rule.** The spec warns to "only leave transient storage slots with
   nonzero values when those slots are intended to be used by future calls within the same
   transaction," and cautions that developers "should prefer memory ... so as not to create unexpected
   behavior on reentrancy in the same transaction"
   ([EIP-1153](https://eips.ethereum.org/EIPS/eip-1153)). Here the value *is* intended for a future
   call in the same tx (the recorder), so transient storage is correct — but keep the reset path
   (`resetExecutionState`) intact so the context can't be misread by an unrelated third hook later in
   the same bundle.

> Do not treat transient storage as a general-purpose mapping. EIP-1153 explicitly calls this out as a
> footgun under same-tx reentrancy. It is correct *here* only because the lifetime is genuinely one
> transaction and the reader is the very next hook.

---

## 2. Measuring token movement via pre/post balance deltas

The rule for this feature: **the recorded amount must come from `balanceAfter - balanceBefore` on the
account, never from the quoted/expected amount** in calldata. Pendle AMM swaps, limit-order fills, and
`redeemPyToToken` can all return a different realized amount than the quote. `PendlePTHook` already
does this for the output side (`_postExecute: _setOutAmount(_getBalance(...) - getOutAmount(...))`);
the extension mirrors it for the input side (PT spent).

Pitfalls and mitigations (`d-xo/weird-erc20` catalogs these;
[weird-erc20](https://github.com/d-xo/weird-erc20)):

| Pitfall | Effect on this feature | Mitigation |
|---|---|---|
| **Fee-on-transfer** (STA, PAXG-style) | Received/spent differs from quoted amount | Always use the *delta*, measured on the account that holds the tokens — which is exactly what balance-diff does. Never record the quote. |
| **Rebasing / balance changes outside transfer** (stETH-style, airdrops) | A rebase between the pre and post snapshot corrupts the delta | Take pre/post snapshots as tightly around the swap as possible (they already bracket only the swap execution). For PT/SY specifically the risk is low, but the recorder should treat the delta as "net movement over the window," and the oracle's `BOOK_VALUE_EXCEEDS_FACE_VALUE` guard in `recordPurchase` is a useful backstop against absurd deltas. |
| **Tokens returning `false` / no boolean** (USDT, BNB) | A failed transfer can look successful, or a `SafeERC20`-less call reverts unexpectedly | Rely on balance deltas for accounting (a genuinely failed transfer yields a zero/negative-clamped delta), and use OpenZeppelin `SafeERC20` for the transfer calls themselves ([OZ SafeERC20](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20)). |
| **Underflow when "spent" is computed** | `before - after` underflows if balance somehow rose | Compute spent as `before - after` only after asserting `after <= before` for the input token (and symmetrically `after >= before` for output); revert otherwise. Solidity 0.8 will revert on underflow, but an explicit check gives a named error. |
| **Native ETH** | `balanceOf` doesn't apply | `PendlePTHook._getBalance` already branches to `account.balance` for `address(0)`/`NATIVE_TOKEN`. Reuse that helper for the input side too. |
| **Reentrant tokens (ERC-777)** | A token hook could re-enter between snapshots | The `preExecute`/`postExecute` mutexes and account-keyed context bound the blast radius; keep snapshots adjacent to the swap and never read a half-populated context (`operation == NONE` ⇒ revert). |
| **Non-account recipient** | Delta measured on the wrong address reads zero | Measure on `account` (the SCA that receives PT/asset), consistent with the existing output-side measurement. |

General guidance from the same sources: prefer contract-level allowlisting of tokens and "balance
delta verification via pre/post-transfer balance checks rather than trusting return values"
([weird-erc20](https://github.com/d-xo/weird-erc20)). PT, SY, and the whitelisted asset set here are a
constrained, semi-trusted universe (derived from `market.readTokens()`), which materially lowers the
weird-token risk — but the deltas remain the source of truth.

---

## 3. Validating that the "previous hook" is the expected trusted contract

The recorder reads privileged data (`getPendleTradeResult`) and writes to an oracle that backs
accounting. If `prevHook` is attacker-controlled, it can return a fabricated `TradeResult` and poison
the oracle. Two validation styles:

### Address-pinning (recommended for this tightly-coupled pair)
Pin the approved `PendlePTHook` as an `immutable` in the recorder's constructor and require
`prevHook == APPROVED_PENDLE_PT_HOOK`. This is the decision recorded in the interview notes and it is
the correct one for a pair that shares a bespoke, versioned interface (`IPendlePTHookResult`) and a
matching transient-context layout. Rationale:

- **Exactness.** It authorizes one specific bytecode+layout, not "anything that claims an interface."
  The record hook depends on `PendlePTHook`'s *exact* context semantics (input-side snapshot,
  operation routing), which is a bytecode-level contract, not just a selector set.
- **No spoofing surface.** ERC-165 only proves "I implement selector X," which any contract can assert.
  It does not prove correct or honest behavior. For a data-provenance trust boundary, interface
  detection is necessary-at-best and here not even necessary.
- **Cheaper and simpler.** One `==` against an immutable vs. a `supportsInterface` staticcall.
- **Defense in depth.** This is *in addition to* the existing strategy/Merkle authorization that
  governs which hooks a strategy may run — the pin protects the recorder even if the higher-level
  allowlist is ever misconfigured.

Note the current V2 recorder does **not** pin: it calls `ISuperHookResult(prevHook).getOutAmount(account)`
on whatever `prevHook` it's handed. Adding the immutable pin is a genuine security upgrade, not just a
refactor.

### ERC-165 (`supportsInterface`)
Appropriate when a hook must interoperate with an *open set* of counterpart implementations discovered
at runtime. Not the case here — the counterpart is a single first-party contract. The interview's
"no ERC-165 check (redundant given the pinned address)" is right. If you ever did both, treat ERC-165
as a sanity check, never as the trust root.

### Practical belt-and-suspenders for the pin
Beyond `prevHook == APPROVED_PENDLE_PT_HOOK`, still validate the *content* of the result so a future
change to the swap hook can't silently corrupt records:
- `operation` matches the recorder (BUY_PT for purchase; SELL_PT or REDEEM_PT for redemption); else revert.
- `market` matches the recorder's committed market (the `inspect()` market commitment).
- The PT side matches `market.readTokens()` — output token is PT for purchase, input token is PT for
  sell/redeem. This guards against a malicious `market` returning attacker addresses (a risk
  `PendlePTHook` already documents for `readTokens()`).
- `resolvedAmount != 0` **after** the prev-hook substitution (the interview's amount-semantics rule).

---

## 4. TWAP-based oracle recording (Pendle PT → SY rate)

`PendlePTAmortizedOracleV2` already encodes the right defaults; the record hook must respect them:

- `DEFAULT_TWAP_DURATION = 900` (15 min), `DEFAULT_MIN_TWAP_DURATION = 300` (5 min), with a per-market
  override `marketMinTwapDuration`. `recordPurchase(market, ptBought, twapDuration)` reverts
  `TWAP_DURATION_TOO_SHORT` when `twapDuration < getMinTwapDuration(market)`
  (`src/accounting/oracles/PendlePTAmortizedOracleV2.sol`).

**Enforce the minimum window at the hook boundary too.** The hook lets the caller pass `twapDuration`.
Even though the oracle re-checks, validate `twapDuration >= getMinTwapDuration(market)` in the hook so
the failure is legible and can't be bypassed by a future oracle change. Never let `twapDuration == 0`
(spot) through for accounting — the oracle's own comment says "Spot price (twapDuration=0) can be
manipulated via flash loans."

**Why TWAP over spot (manipulation resistance).** `getPtToSyRate(duration)` reads Pendle's on-chain
observation buffer; a longer window averages over more blocks so a single-block/flash-loan push to the
AMM implied rate is diluted. Pendle's oracle enforces that enough history exists:
`getOracleState(market, duration)` returns `increaseCardinalityRequired`, `cardinalityRequired`, and
`oldestObservationSatisfied`, and the rate call reverts `TwapDurationTooLarge` if the requested window
exceeds available observations
([Pendle `PendlePYLpOracle`](https://github.com/pendle-finance/pendle-core-v2-public/blob/main/contracts/oracles/PtYtLpOracle/PendlePYLpOracle.sol)).

**Cardinality is a prerequisite, not automatic.** Before a market can serve a given TWAP window,
someone must have called `increaseObservationsCardinalityNext` and waited for the buffer to fill to
`cardinalityRequired`. This is an operational/deployment step per market (and per chain — Pendle's
`blockCycleNumerator` differs, e.g. Ethereum ~11,000 vs Arbitrum ~1,000, changing the cardinality
needed for the same seconds). Deployment/runbook for the record hooks must ensure each supported
market has `oldestObservationSatisfied == true` for the configured minimum window, or recording will
revert. Pendle's own integration guidance recommends checking `getOracleState` and warming cardinality
before relying on the oracle ([Pendle oracle docs](https://docs.pendle.finance/Developers/Oracles)).

**Trade-off summary.**
- *Spot (0s):* freshest, but flash-loan manipulable — disallowed for accounting.
- *Short TWAP (~5 min, the floor):* fast to warm, modest manipulation cost. Acceptable minimum; the
  codebase's 300s floor.
- *Standard TWAP (15 min default, up to 30 min):* stronger manipulation resistance, but the rate lags
  fast genuine moves and needs larger cardinality. 15 min is the codebase default and a common Pendle
  recommendation; raise per-market via `setMinTwapDuration` for thin/volatile markets.

Pick the window per market via `marketMinTwapDuration` rather than one global value: liquid, high-TVL
markets tolerate shorter windows; thin markets should be pushed toward 15–30 min.

---

## 5. Migration / versioning when calldata layout + bytecode change

The recorder's calldata layout and the `PendlePTHook` context layout are both changing (new
`IPendlePTHookResult`, new input-side snapshot, new decode offsets). Guidance:

**Deploy new; never mutate in place.** These are stateless-per-tx hooks addressed by their deployed
address and pinned to each other. The idiomatic pattern in this repo is already versioned-by-deployment:
`RecordPurchasePendlePTAmortizedOracleHook` → `...HookV2`, and `PendlePTAmortizedOracle` →
`...OracleV2`. Continue that: ship the new record hooks as new contracts at new addresses, and (because
they carry an *immutable* `APPROVED_PENDLE_PT_HOOK`) redeploy them whenever the swap hook is
redeployed. The interview's "a new `PendlePTHook` requires redeploying the record hooks — acceptable;
matches 'treat as new hook deployment'" is the correct stance. Do **not** attempt an in-place upgrade
(proxy) of a hook whose calldata offsets changed — every strategy's committed Merkle hook data encodes
the old layout and would silently misdecode.

**Reasons new-deployment beats in-place here:**
- Calldata offset changes are a hard ABI break; the account replays pre-committed hook data, so the
  code and the data must be versioned together.
- Immutability of the pinned addresses is a feature (no admin key to compromise); it also *forces*
  redeploy-on-change, which is the safe default.
- Hooks hold no long-lived state (transient only), so there is nothing to migrate — the classic reason
  to prefer in-place upgrades doesn't apply.

**Retaining old records for historical decoding.**
- The *oracle* (`PendlePTAmortizedOracleV2`) is the stateful component and stays put; new record-hook
  versions keep writing to the same oracle via the same `recordPurchase/recordRedemption` ABI, so
  historical book value is continuous. Only add a *new* oracle when its recording ABI or accounting
  math changes (as V2 did when it dropped `syAccountingAssetSpent` and moved SY cost on-chain).
- Emit versioned events. `PurchaseRecorded(strategy, market, ptBought, sySpent, twapDuration)` already
  captures enough to reconstruct history off-chain; keep events append-only and never repurpose a field.
  If a field's meaning changes, add a new event rather than overloading the old one — that keeps old
  logs decodable with the old ABI.
- Keep both old and new hook source + ABI in the deployment manifest (`hooks-deployment-manifest.md`,
  `hook-sizing-manifest.json`) so an indexer can pick the decoder by the emitting hook address. Address
  → version is the durable key.
- Maintain separate staging vs prod approved addresses (distinct `PendlePTHook`/oracle per env), as the
  interview notes require, so a staging redeploy never repoints prod records.

---

## Consolidated checklist for this feature

1. Extend `PendlePTHook`'s existing transient per-account context (not new machinery): snapshot input
   balance in `_preExecute`, compute `inputAmount` delta + set `operation`/`inputToken`/`market` in
   `_postExecute`; expose via `getPendleTradeResult(account)`.
2. Recorders read `outputAmount` (purchase) / `inputAmount` (redemption) from that struct; never use
   `getOutAmount` as `ptSold`.
3. All amounts from balance deltas on `account`; assert direction to avoid underflow; reuse
   `_getBalance` native-ETH branch; use `SafeERC20` for transfers.
4. Pin `prevHook == APPROVED_PENDLE_PT_HOOK` (immutable); no ERC-165. Additionally assert
   `operation`, `market`, and PT side vs `readTokens()`; validate `resolvedAmount != 0` after
   `usePrevHookAmount` substitution.
5. Enforce `twapDuration >= getMinTwapDuration(market)` at the hook; reject spot for accounting; warm
   Pendle oracle cardinality per market/chain during deployment.
6. Version by new deployment; keep writing to the same `PendlePTAmortizedOracleV2`; keep events
   append-only and address→version mapping in the manifests; separate staging/prod approved addresses.

---

## Sources

- [EIP-1153: Transient Storage Opcodes](https://eips.ethereum.org/EIPS/eip-1153) — end-of-tx clearing,
  reentrancy/slot-hygiene warnings, "prefer memory" caveat.
- [ERC-7579: Minimal Modular Smart Accounts](https://eips.ethereum.org/EIPS/eip-7579) — executor
  `executeFromExecutor` authorization, pre/post hook `hookData` context passing, malicious-hook DoS and
  delegated-authorization warnings.
- [OpenZeppelin Contracts — Utils (`TransientSlot`, `ReentrancyGuardTransient`)](https://docs.openzeppelin.com/contracts/5.x/api/utils#TransientSlot)
  — transient-storage primitives and single-transaction lifetime.
- [OpenZeppelin `SafeERC20`](https://docs.openzeppelin.com/contracts/5.x/api/token/erc20#SafeERC20) —
  safe transfer for non-standard-return tokens.
- [d-xo/weird-erc20](https://github.com/d-xo/weird-erc20) — fee-on-transfer, rebasing, no/false return
  values, reentrancy; recommends balance-delta verification and allowlisting.
- [Pendle `PendlePYLpOracle` (pendle-core-v2-public)](https://github.com/pendle-finance/pendle-core-v2-public/blob/main/contracts/oracles/PtYtLpOracle/PendlePYLpOracle.sol)
  — `getOracleState`, cardinality math, `getPtToSyRate`/`getPtToAssetRate`, `TwapDurationTooLarge`.
- [Pendle developer oracle docs](https://docs.pendle.finance/Developers/Oracles) —
  `increaseObservationsCardinalityNext` warm-up and TWAP integration guidance.
- Repo (authoritative for this feature): `src/hooks/BaseHook.sol` (transient per-account context,
  balance-delta, PASSTHROUGH), `src/hooks/swappers/pendle/PendlePTHook.sol` (operation routing,
  output-delta), `src/accounting/oracles/PendlePTAmortizedOracleV2.sol` (900s default / 300s min TWAP,
  per-market min, `TWAP_DURATION_TOO_SHORT`), `src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol`
  (current unpinned `prevHook` read).
