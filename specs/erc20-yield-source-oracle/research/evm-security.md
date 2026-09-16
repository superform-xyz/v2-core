# EVM Security Research — ERC20YieldSourceOracle

- **Date:** 2026-09-15
- **Scope:** view-only, stateless, identity-PPS oracle for plain ERC20 tokens (first consumers: BSC tokenized stocks NVDAb/TSLAb held directly by `SuperVaultStrategy`); one instance serves all tokens; no admin, no registry, no token movement.
- **Vulnerability DB:** `superform-specs/guidelines/solidity/vulnerabilities.md` (cited as "DB §")
- **Direct precedent:** `specs/security-reports/2026-09-02-aave-v4-oracles.md` (branch `cosmin-sup-20854-feature-aave-v4-debt-oracle`) — its residual-risk framing (feePercent = 0 triple-anchoring, identity-PPS class, fee-view bypass per PR #997 F1) transfers almost verbatim.
- **Closest deployed sibling:** `src/accounting/oracles/StakingYieldSourceOracle.sol` — already identity-PPS + `balanceOf`/`totalSupply`, but hardcodes `decimals = 18` / `pps = 1e18` and does **not** override `getAssetOutputWithFees` (pre-#997 shape). The new oracle is that contract with decimals passthrough plus the post-#997 fee bypass.

---

## 1. Relevant Vulnerability Patterns

### 1.1 Token-behavior classes vs `balanceOf`/`totalSupply` reads

The oracle's entire data surface is three STATICCALLs into an arbitrary whitelisted token: `decimals()`, `balanceOf(owner)`, `totalSupply()`. Every "weird ERC20" class reduces to: *the token lies, drifts, or reverts on one of these three reads.*

| Class | DB ref | Effect on this oracle | Severity here |
|---|---|---|---|
| Rebasing (stETH, AMPL, split-rebased stock tokens) | §10.2 | `balanceOf` drift is *transparently passed through* — for an identity-PPS oracle the balance **is** the value in token units, so a rebase silently changes measured holdings between validator snapshots. Corporate actions on tokenized stocks (splits, reverse splits) are the realistic trigger: if the issuer implements a 10:1 split as a balance rebase, balance×price is conserved **only if** the off-chain price source updates atomically with the same snapshot. Declared out-of-scope in the interview (decision #6) — must stay a *documented* exclusion, not a silent one. | High (off-chain PPS correctness), zero (on-chain) |
| Fee-on-transfer | §10.1 | Mostly N/A for the oracle itself: it reads settled balances, which are ground truth *after* the fee. The §10.1 hazard (assuming transfer amount == balance delta) belongs to hooks/strategy code, not a view oracle. Honest assessment: no oracle-side defense needed; whitelisting checklist item only. | Low |
| Double-entry / proxy tokens (TUSD class) | §18.1.3 | **The strongest genuinely-applicable class.** Two entry-point addresses reading one balance ⇒ if the manager whitelists both (or a legacy + canonical address), the off-chain pricer counts the same holdings twice ⇒ vault PPS inflated ⇒ *real value extraction* via SuperVault share mint/redeem at the inflated PPS. One oracle instance serving all tokens means the oracle cannot carry a per-token whitelist — the strategy whitelist (`SuperVaultStrategy.manageYieldSource`) is the only gate, and it accepts any (source, oracle) pair. | High (ops) |
| Blocklist / pausable (regulated stock tokens are the canonical case) | §7.4 spirit | Inverse of the rsETH finding in the Aave report: `balanceOf` keeps reading fine while the strategy's assets are frozen/blocked ⇒ PPS overstates *redeemable* NAV. Backed-style bTokens are publicly documented as upgradeable proxies with pause + sanctions-list mechanics — verify the exact BSC deployments. A pause that reverts `totalSupply()`/`balanceOf()` (rare but possible under upgrade) turns into batch poisoning (below). | Medium (ops/monitoring) |
| >18 decimals / missing `decimals()` | §26.4.2; AaveV4 report 78-boundary test | Identity converters are decimal-agnostic (pure passthrough of `amountIn`). `getPricePerShare = 10 ** decimals(token)` reverts via checked arithmetic at decimals ≥ 78 (same pinned boundary as AaveV4); `BaseLedger` does the same `10 ** decimals` (BaseLedger.sol:141,217). Non-ERC20 / no-`decimals()` addresses revert naturally on the probe — this is the *intended* validation gate (interview decision #3). | Low |
| `totalSupply`-manipulable (issuer mint/burn, flash-mint, bridged supply) | §26.1.2, §28.3 | `getTVL(token) = totalSupply()` is *global chain supply*, not vault holdings — the issuer changes it arbitrarily and legitimately on every mint/redeem. This is a semantics decision (interview decision #1, mirroring ERC4626's `totalAssets()`), fine for monitoring, **meaningless for pricing** — the validator network must use `getBalanceOfOwner(token, strategy)`, never `getTVL`. Pin this in NatSpec. | Low (if documented) |

### 1.2 Fee-pipeline misuse — the PR #997 F1 class (identity PPS + configured fee ⇒ principal taxed)

The oracle satisfies `IYieldSourceOracle`, so nothing but configuration prevents it being registered in `SuperLedgerConfiguration` and driven by the fee pipeline. Three concrete paths, in descending on-chain guardedness:

1. **Inherited fee view** — `AbstractYieldSourceOracle.getAssetOutputWithFees` (AbstractYieldSourceOracle.sol:90–126) consults the ledger config and *adds* `previewFees` on top of the base output. **Guarded by design decision:** bypass-overridden to `return getAssetOutput(...)` exactly like post-#997 `AaveV4SupplyYieldSourceOracle.getAssetOutputWithFees` (that file's lines 149–162 on the branch). This is the only path the oracle's own code can protect.
2. **`BaseLedger._processOutflow`** (BaseLedger.sol:198–222) — unguarded by the oracle. With identity PPS, a snapshot-then-withdraw round trip reads zero profit (`_calculateFees` profit = 0), and snapshot-less shares get capped to 0 by `calculateCostBasisView` (BaseLedger.sol:84–90) ⇒ fee 0. Benign *today*, but this safety is emergent from cost-basis math, not enforced.
3. **`FlatFeeLedger._processOutflow`** (FlatFeeLedger.sol:38–57) — **fees the ENTIRE amount with cost basis hardcoded to 0.** Registering this oracle's id with FlatFeeLedger + feePercent > 0 taxes full principal on every outflow. This is the maximal expression of the F1 class and is pure configuration, not code.

Named config-not-code precedents (from the Aave report's residual): Compound Prop 62 (~$80M, wrong-baseline accrual) and Moonwell 2025 ($1.8M). The mitigation shape is the Aave report's **triple anchoring**: NatSpec invariant + ops runbook + executable test (§4 below).

### 1.3 Read-only reentrancy (DB §1.4, §18.3.1)

Honest assessment: **not applicable today.** `balanceOf`/`totalSupply` on plain ERC20s have no transient mid-transaction inconsistency of the Curve/Balancer `get_virtual_price` kind. The exception class is ERC-777-style transfer hooks (DB §1.5, §10.4), where a `tokensToSend` callback observes pre-debit state — relevant *only if* some future on-chain contract reads this oracle within the same transaction that moves the token. Today no on-chain contract consumes these views at all (grep confirms zero non-oracle, non-interface callers of `getBalanceOfOwner`/`getTVL*`/`getAssetOutputWithFees` in `src/`), and the validator network reads at settled blocks. Document the assumption; do not engineer for it.

### 1.4 Batch-view poisoning (DB §7.1, §13.2, Appendix H, §25.3)

Inherited from `AbstractYieldSourceOracle`:
- `getPricePerShareMultiple` (lines 129–141) and `getTVLMultiple` (lines 193–201) have **no try/catch** — one reverting entry (whitelisted EOA, token upgraded-to-revert, pause that reverts `totalSupply`) reverts the entire batch. For this oracle, `getPricePerShare` reverts iff `decimals()` reverts, and `getTVL` reverts iff `totalSupply()` reverts.
- `getTVLByOwnerOfSharesMultiple` (lines 154–190) isolates failures via an external self-call try/catch with a `succeeded` mask — poisoning-resistant, and returnbomb (Appendix H.1) is bounded because the whole thing is a view consumed off-chain (griefer pays their own eth_call gas).
- §25.3 duplicate entries: batch callers can pass the same token twice; deduplication is the off-chain aggregator's duty, not the oracle's. Note it in NatSpec, don't add state.

This matches the interview's testing expectation ("known one-reverting-entry poisoning of unprotected Multiple() views") — pin as documented behavior, consistent with the fleet.

### 1.5 Oracle-as-type-discriminator (DB §14.3; SuperVaultStrategy.sol:94, 599–625, 871–877)

The strategy never calls the oracle on-chain — the stored oracle address tells the **off-chain validator network how to price the source**. Two misuse shapes:
- **Wrong pair, plausible token:** manager attaches ERC20YieldSourceOracle to an ERC-4626 share ⇒ pricer treats vault shares as plain tokens (prices them at the *share token's* market/reference price, or fails to find one); or attaches ERC4626YieldSourceOracle to a plain ERC20 ⇒ batch calls revert (`convertToAssets` missing). Mispricing in the first shape is silent.
- **Hostile token, correct oracle:** a malicious "stock token" that reports arbitrary `balanceOf(strategy)` fully controls its own contribution to PPS. The oracle *cannot* defend this — same trust model as the whole oracle fleet (DB §14.3 "sanitize inputs" ends at the `decimals()` probe; manager is trusted; garbage in, garbage out — Aave report §"Registry role-holder capture": manager must be a multisig, never a hot EOA; Term Finance 2026 / KiloEx 2025 precedents).

The only on-chain check that survives the "no admin, no registry" design constraint is the `decimals()` probe (decision #3). Everything else is whitelisting discipline (§4 ops).

### 1.6 Non-applicable classes (checked, honestly excluded)

- Access control (§2), signature/crypto (§9), proxy/upgrade of the *oracle itself* (§11, §27), storage (§23), first-depositor/inflation *of the oracle* (§22.1): no state, no admin, no shares, immutable-only constructor — structurally absent.
- Spot-price manipulation / flash loans (§4.1, §5): the oracle quotes identity, not a market price; there is no curve to bend.
- Front-running/MEV (§6): views only, nothing to order.

---

## 2. Exploit Precedents

| Incident | Class | Applies here? |
|---|---|---|
| **Compound `sweepToken` TUSD double-entry (2021)** — legacy TUSD entry point allowed sweeping the "non-underlying" address that shared balances with the real underlying (DB §18.1.3) | double-entry token | **Yes, adapted:** not sweep, but double-*count*. Whitelisting both entry points of one balance inflates off-chain PPS ⇒ extractable via share mint/redeem. The only precedent on this list that converts to direct value extraction through this oracle's data. |
| **Aave AMPL pool breakage (2020–21) & the long tail of aToken/rebasing-in-vault audit findings** (DB §10.2) | rebasing vs balance-based accounting | **Yes, for the off-chain consumer:** identity passthrough means any rebase (incl. split-as-rebase corporate actions on tokenized stocks) shifts measured holdings between snapshots. The oracle itself cannot be "wrong" — it reports the balance faithfully — but the (balance × off-chain price) product breaks if the two legs desynchronize. |
| **stETH 1–2 wei transfer rounding / share-vs-balance drift** | balance semantics | Marginal: no transfer accounting in the oracle; at most dust-level noise in off-chain PPS. Effectively N/A. |
| **Hundred Finance ($7.4M, 2023), Sonne ($20M, 2024), Wise Lending** — donation/first-depositor share inflation (DB §28.1) | vault-PPS donation | **Mostly N/A for this oracle.** Donating stock tokens to the strategy *raises* PPS for existing holders at the donor's expense — not an attack unless SuperVault share math has empty-vault/rounding states (DB §22.3), which is SuperVault's surface, not the oracle's. The oracle is a faithful conduit; there is no exchange-rate function of its own to inflate. |
| **Sentiment ($1M) / Sturdy ($0.8M, 2023)** — LP oracle read during reentrancy callback (DB §28.4, §1.4) | read-only reentrancy on price views | **N/A today:** no on-chain consumer, off-chain reads at settled blocks, no mid-tx window. Becomes reviewable only if a contract ever reads these views in a tx that also moves the token (§1.3). |
| **Compound Prop 62 (~$80M) / Moonwell 2025 ($1.8M)** — configuration, not code | fee/config invariant violation | **Yes:** the exact class of the feePercent = 0 invariant. The code can be perfect and the FlatFeeLedger registration still taxes principal (§1.2 path 3). |
| **rsETH 2026-04-18 (from the Aave report)** — accounting views stayed live through freeze | view liveness under issuer intervention | **Yes, inverted:** liveness is expected (plain `balanceOf` survives pauses that gate *transfers*), but a blocklist hit on the strategy makes live reads overstate *redeemable* value. Monitoring concern, not oracle code. |

---

## 3. Attack Surface Map

Deliberately small; enumerated exhaustively:

- **Entry points:** all `external view`/`pure` — `decimals`, `getPricePerShare(+Multiple)`, `getShareOutput`, `getWithdrawalShareOutput`, `getAssetOutput`, `getAssetOutputWithFees` (bypass), `getBalanceOfOwner`, `getTVLByOwnerOfShares(+Multiple)`, `getTVL(+Multiple)`. No state-mutating function exists.
- **State:** one immutable (`SUPER_LEDGER_CONFIGURATION`, inherited). No storage, no roles, no upgrade path, no token custody. Zero value-transfer points.
- **External calls:** STATICCALLs to the *arbitrary caller-supplied token address* — `decimals()`, `balanceOf()`, `totalSupply()`. The token is the only counterparty and is fully attacker-choosable at the call level (the oracle serves any address). Malicious tokens can: revert (⇒ batch poisoning of the two unprotected `Multiple()` views, §1.4), returnbomb (bounded: view-only, self-call try/catch on the ByOwner batch), or lie (⇒ garbage-in-garbage-out; only *whitelisted* tokens' lies reach the validator network).
- **Ledger reachability:** `SUPER_LEDGER_CONFIGURATION` is stored but — with the fee-view bypass — never read by any code path in this contract. The ledger is reachable only via future registration of this oracle's id in `SuperLedgerConfiguration` (§1.2 paths 2–3), which is outside the contract's control: the highest-consequence residual, config-anchored not code-anchored.
- **Consumers:** today exclusively off-chain (validator network via `SuperVaultStrategy`'s stored (token → oracle) metadata; monitoring/periphery batch views). No on-chain reader exists in `src/`.
- **Trust roots:** (1) SuperVault curator/manager whitelisting honest, single-entry-point, non-rebasing tokens; (2) `SuperLedgerConfiguration` governance never registering this id with feePercent > 0 (or at all); (3) issuer of the tokenized stocks (upgradeable proxies — semantics can drift under our feet, same acceptance as Aave spoke proxies in the precedent report).

---

## 4. Recommended Security Patterns

### Code must pin
1. **Fee bypass, exact post-#997 shape:** `getAssetOutputWithFees(bytes32, address yieldSource, address assetOut, address, uint256 usedShares) → getAssetOutput(yieldSource, assetOut, usedShares)` — ignore id and user, never touch `SUPER_LEDGER_CONFIGURATION`. Mirror `AaveV4SupplyYieldSourceOracle` verbatim.
2. **Invariant NatSpec on the contract header** (the AaveV4Supply header lines 33–58 are the template): (a) the view bypass protects only the view path — `BaseLedger._processOutflow`/`FlatFeeLedger._processOutflow` are NOT guarded on-chain; correct behavior depends on the operational invariant **feePercent = 0 (or unregistered)**; FlatFeeLedger registration is categorically forbidden (fees full principal); (b) re-enabling fees requires a new oracle version, never a config change; (c) identity-PPS semantics: values are in token units, cross-asset pricing is external; (d) `getTVL` = global `totalSupply`, monitoring-only, never a pricing input — pricing consumers must use `getBalanceOfOwner`; (e) rebasing/fee-on-transfer/blocklist tokens explicitly out of scope — defenses belong to the whitelister; (f) which views revert for non-ERC20 inputs (`decimals`, and `getPricePerShare` via the decimals read) vs. which are pure identity for any address (scope precisely — Aave report P3-3 was exactly an overclaim here).
3. **Constructor:** revert `ZERO_ADDRESS` on `superLedgerConfiguration_` (Aave P3-2 fix precedent — stricter than StakingYieldSourceOracle), even though the bypass makes it unused; keeps the fleet constructor contract honest.
4. **No `INVALID_BASE_ASSET`, `assetIn` ignored:** fleet-wide accepted precedent (Aave report P3-4); document, don't validate.
5. **`getPricePerShare = 10 ** decimals(token)`**, with the ≥78 checked-overflow boundary documented (cannot occur for real ERC20s; pinned by test as in AaveV4).

### Ops must pin
1. **Ledger config runbook rule:** this oracle's id never registered in `SuperLedgerConfiguration`; if a future wiring requires registration, feePercent = 0 and ledger ≠ FlatFeeLedger, with a config monitor alerting on any `SuperLedgerConfiguration` event referencing this oracle address (v2-monitoring candidate).
2. **Per-token whitelisting checklist** (executed before every `manageYieldSource(token, erc20Oracle, Add)`): single entry point verified (proxy implementation reviewed; no TUSD-class secondary address — §18.1.3); not a rebasing/redenominating token, and the issuer's corporate-action mechanism (splits!) confirmed in writing; blocklist/pause semantics documented and the strategy address monitored against the sanctions list; token is not itself a vault share/LP token (type-discriminator misuse, §1.5); decimals confirmed ≤ 18.
3. **Curator/manager role is a multisig, never a hot EOA** (Term Finance/KiloEx precedent, carried over from the Aave report runbook).
4. **Validator-network contract:** pricing must key on `getBalanceOfOwner(token, strategy)` per whitelisted token, deduplicated by *balance slot* not just address; `getTVL` consumed for monitoring only.

### Tests must pin
See §5 — the load-bearing ones are the fee-bypass executable proof, the FlatFeeLedger hazard documentation test, and the batch-poisoning behavior pins.

---

## 5. Testing Recommendations

Unit (bar: AaveV4/Euler oracle suites, 45-test shape):
1. **Identity fuzz:** ∀ (token, assetIn, amount): `getShareOutput == getWithdrawalShareOutput == getAssetOutput == amount`; round trip `getAssetOutput(getShareOutput(x)) == x`; `assetIn` fuzzled over arbitrary addresses (incl. zero, the token itself) with no effect.
2. **Decimals reflection:** mock tokens at 6/8/18 decimals ⇒ `decimals` passthrough, `getPricePerShare == 10 ** d`; boundary pin: d = 77 works, d = 78 reverts (AaveV4 pattern).
3. **Balance/TVL reads:** mint/burn/transfer on mock ⇒ `getBalanceOfOwner`/`getTVLByOwnerOfShares` track `balanceOf`, `getTVL` tracks `totalSupply`; a *rebasing mock* test documenting (not defending) that a rebase shifts reported balance — the out-of-scope declaration made executable.
4. **Fee-view bypass (the F1 pin):** register the oracle id in a real `SuperLedgerConfiguration` with feePercent = 10% against (a) `SuperLedger` and (b) `FlatFeeLedger`; assert `getAssetOutputWithFees == getAssetOutput` in both — configured fee ignored. Companion hazard-documentation test: the same config driven through `FlatFeeLedger.updateAccounting` outflow charges fee on full principal — executable proof of *why* the operational invariant exists (mirrors the re-scoped AaveV4 hazard-demo test).
5. **Real-ledger round trip:** `BaseLedger` inflow snapshot at identity PPS then outflow ⇒ feeAmount == 0 on principal at 10% configured fee (`test_realLedger_supplyRoundTrip_principalChargesZeroFee` analogue).
6. **Non-ERC20 sweep:** EOA and contract-without-`decimals` ⇒ `decimals`/`getPricePerShare` revert; identity converters and (if implemented via raw calls) balance reads behavior pinned explicitly per function.
7. **Batch behavior:** one reverting token inside `getTVLMultiple`/`getPricePerShareMultiple` reverts the whole batch (documented fleet behavior, pinned); same token inside `getTVLByOwnerOfSharesMultiple` yields `succeeded = false`, others unaffected; duplicate token entries return duplicated values (dedup is caller's job — §25.3 pin).
8. **Invariant (fuzz owners/mints):** `getTVL(token) >= getBalanceOfOwner(token, owner)` on standard mocks (E2E invariant from the Aave suite) — with a comment that hostile/misreporting tokens can violate it (not a guarantee, a sanity pin).

Fork (BSC, if NVDAb/TSLAb addresses confirmed from the Venus VIP-654 list; else parameterized mocks):
9. `decimals`, live `balanceOf`/`totalSupply` snapshot vs. direct token reads at a pinned block (parity).
10. **Liveness under issuer flags:** views stay callable while the token is paused/the owner is blocklisted, if the deployment exposes such flags (AaveV4 `test_views_liveUnderPausedFrozenFlags` analogue — proves accounting reads survive trading-hour pauses, and simultaneously documents the "live reads ≠ realizable value" caveat).
11. **Proxy check (script or test):** assert the whitelisted token address is the canonical entry point (read implementation slot; grep issuer docs for legacy addresses) — the executable arm of the double-entry checklist item.

Explicitly not needed (and why): donation/inflation attack tests (no exchange-rate function of its own — §2), reentrancy tests (no state, no callbacks reachable — §1.3), access-control negatives (no privileged functions exist).
