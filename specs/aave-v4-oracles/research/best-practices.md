# Best Practices Research: Aave V4 Accounting Oracles (Debt + Supply)

Produced by best-practices-researcher, 2026-09-02. Linear: SUP-20854.
Verification key: [CODE] = verified against `aave/aave-v4` GitHub main; [DOCS] = official Aave docs/blog; [3P] = third-party; [REPO] = verified in v2-core.

---

## 1. Aave V4 architecture (Hub-and-Spoke) — what the oracles read

V4 live on Ethereum mainnet ~2026-03-30; code public (BUSL) at github.com/aave/aave-v4. [DOCS/3P]

### 1.1 Topology
- **Liquidity Hub**: central settlement/liquidity per chain; credit/debit lines per Spoke; per-asset state under `assetId`.
- **Spokes**: user-facing borrowing modules holding all user positions; risk isolated per Spoke (own collateral set, risk params, liquidation config).
- Reserve maps to Hub asset: `Reserve { underlying, hub, assetId, decimals, collateralRisk, flags, dynamicConfigKey }` — matches the vendored struct. [CODE + REPO]

### 1.2 Debt tracking: drawn vs premium [CODE]
- `UserPosition`: `drawnShares` (uint120), `premiumShares` (uint120), `realizedPremiumRay`, `premiumOffsetRay` per (user, reserveId).
- Drawn debt = `drawnShares` × hub `drawnIndex`, `rayMulUp` (rounds UP).
- Premium debt = risk-premium interest from collateral composition; Ray-tracked `premiumShares * drawnIndex − premiumOffsetRay + realizedPremiumRay`.
- `getUserDebt` returns `(drawnDebt, premiumDebtRay.fromRayUp())` — **premium also rounds up to asset units**. `getUserTotalDebt(reserveId, user)` returns the sum directly. `getUserPremiumDebtRay` gives Ray precision.
- Aggregates: `getReserveDebt(reserveId)` → (drawn, premium) and **`getReserveTotalDebt(reserveId)`** — natural `getTVL()` for the debt oracle (totalBorrows analog).
- Views accrue live from the hub index — no accrual replication needed (Euler-style; none of MorphoBlueDebtOracle's elapsed-cap machinery).

### 1.3 Supply side: no aTokens on Spokes [CODE]
- Regular Spokes hold `suppliedShares` (uint120) internally; no per-reserve aToken; balances non-transferable.
- `getUserSuppliedAssets` = `hub.previewRemoveByShares(assetId, suppliedShares)` = `toAddedAssetsDown` — rounds DOWN (conservative for supplier). Interest accrues via hub share price rising.
- Share-precision views exist: `getUserSuppliedShares`, `getReserveSuppliedAssets(reserveId)`, `getReserveSuppliedShares(reserveId)`. A true PPS is derivable via `previewRemoveByShares(assetId, oneShareUnit)` — **the supply oracle can be a REAL PPS oracle** (like ERC4626YieldSourceOracle), not identity.
- **`TokenizationSpoke` exists**: optional ERC-4626-compliant wrapper tokenizing one Hub asset. If a market routes through it, plain `ERC4626YieldSourceOracle` covers it with zero new code. Base equities markets are plain-Spoke positions.

### 1.4 reserveId semantics [CODE]
- `addReserve` assigns `reserveId = _reserveCount++` — sequential, append-only, per-Spoke; no `removeReserve` in `ISpoke`. A reserveId permanently refers to the same underlying within that Spoke.
- reserveId ≠ Hub assetId; `getReserveId(hub, assetId)` maps back. Different Spokes have different ids for the same underlying — **key must be (spoke, reserveId)**.
- Deactivation via flags, not deletion — listed ids never dangle.

### 1.5 Reserve flags [CODE]
`paused (0x01)`, `frozen (0x02)`, `borrowable (0x04)`, `receiveSharesEnabled (0x08)`.
- paused = all actions prevented; frozen = no new activity (withdraw/repay still allowed).
- **Views are NOT flag-gated** — reads keep working and interest keeps accruing while paused/frozen. Pausing affects the hook settle path, not accounting reads (confirms interview decision #10).

### 1.6 Upgradeability / migration [CODE]
- Hub and Spoke deploy as **TransparentUpgradeableProxy + implementation** (per `AaveV4SpokeInstanceBatch`/`AaveV4HubInstanceBatch`), governed via AccessManager. (A third-party writeup claims the Hub is immutable — deployment code contradicts; trust the code.)
- Spoke address stable across upgrades (proxy) → registry bindings survive; ABI/semantics drift possible → pin vendored interface + fork tests + ops monitoring of Aave governance for implementation upgrades.
- Position migration between spokes = user-level action, not in-place rebinding; registry needs only deregistration discipline.

Sources: aave/aave-v4 source (Spoke.sol, ISpoke.sol, ReserveFlagsMap.sol, Hub.sol, SharesMath.sol, TokenizationSpoke.sol, deployment batches); https://aave.com/docs/aave-v4/liquidity ; https://aave.com/docs/aave-v4/liquidity/spokes ; https://aave.com/blog/understanding-aave-v4s-architecture ; https://aave.com/blog/aave-v4-live-ethereum ; https://blog.wssh.dev/posts/aave-v4 ; https://www.theblock.co/post/395617/aave-v4-launches-ethereum-mainnet

## 2. Aave V4 on Base + tokenized equities (launched ~2026-08-24)

- **Issuer:** Coinbase Onchain SPV Ltd (ADGM, bankruptcy-remote). Launch tokens: **NVDAc, METAc, AAPLc, GOOGLc**; Reg S — US persons excluded from purchase/redemption. [3P]
- **Token standard: B20** — Base-built ERC-20 extension for stablecoins/RWAs running as Base precompiles (single shared audited implementation; Base + Spearbit audits). Tokens **freely transferable onchain**, trade 24/7; only KYC'd "Vested Holders" redeem/vote. Corporate actions (dividends, splits) via an **internal multiplier, NOT rebasing** — explicitly designed so lending-collateral accounting doesn't break. [3P — Genfinity]
  - Implication: no rebase drift on `getUserSuppliedAssets`; transfer-restriction risk thinner than feared (transfers open; redemption gated). Confirm with Joao: does B20 have transfer hooks (reentrancy surface)? Does liquidator `receiveSharesEnabled` interact with vesting?
- **Aave's pricing:** Chainlink 24/5 equities-standard feeds — freeze at banded close off-hours while tokens trade 24/7. Validates decision #7: keeping price feeds OUT of Superform oracles sidesteps the trading-hours staleness surface entirely; Aave's health/liquidation layer absorbs it.
- **DeFi integration:** ~50 launch apps; Aave, Morpho, Euler listed as day-one lending integrations.
- **$1M incentive figure: not publicly verifiable.** Public precedents: $15M Avalanche V4 RWA program; Merit program on Base (off-protocol merkle airdrops). Merit-style rewards would have zero impact on oracle design. Confirm amount/mechanism on the call.

Sources: https://genfinity.io/2026/08/25/coinbase-tokenized-stocks-live-on-base/ ; https://thedefiant.io/news/defi/coinbase-launches-tokenized-stocks-on-base ; https://crypto.news/chainlink-unlocks-defi-lending-for-tokenized-stocks/ ; https://news.todayindefi.com/p/tokenized-stocks-can-now-earn-you ; https://aave.com/blog/rebuilding-securities-finance-v4 ; https://www.tradingview.com/news/cointelegraph:f635e42b7094b:0-aave-launches-v4-on-avalanche-laying-groundwork-for-tokenized-credit-markets/ ; https://app.aave.com/governance/v3/proposal/?proposalId=150 ; https://aave.com/docs/aave-v4/liquidity/incentives

## 3. Best practices: read-only accounting oracles over lending state

### 3.1 Rounding
Convention: **round debt up, claims down**. Aave V4 already does both at source (`rayMulUp`/`fromRayUp` on debt; `toAddedAssetsDown` on supply) → oracles **pass values through unmodified** (double-rounding is the anti-pattern). Euler pattern, documented in NatSpec.

### 3.2 Debt oracle shape
- Identity PPS in asset units (Euler-shaped) is correct: V4 `getUserDebt` returns live-accrued asset units. `getTVL` = `getReserveTotalDebt`. MorphoBlue's shares-based balance is the divergent one (Morpho positions have a single meaningful share unit; V4's drawn+premium shares are not one unit).
- feePercent = 0 invariant: keep NatSpec byte-similar to Euler/MorphoBlue including the BaseLedger `_processOutflow` caveat.

### 3.3 Paused/frozen reserves
- **Do not gate reads on pause state** — accounting must stay readable during incidents (V4's own views aren't gated; MorphoBlue SAFETY INVARIANT expresses the same from the registry side).
- Document that debt keeps accruing while paused/frozen ("paused market" ≠ "static debt") — interacts with SUP-20842 repay-cap semantics.
- Optionally expose flags passthrough for monitoring; never in the read path.

### 3.4 Read-only reentrancy
- Canonical failure: Curve `get_virtual_price` (ChainSecurity disclosures; MakerDAO/Enzyme/Abracadabra/Opyn impact) — unguarded view returns inconsistent mid-execution state.
- V4: Spoke uses OZ `ReentrancyGuardTransient` with `nonReentrant` on all state-changing entrypoints; views unguarded [CODE]. Standard ERC-20 transfers have no callbacks → classic vector absent. Residual vector: **tokens with transfer hooks** — exactly the B20 question for Joao.
- Mitigations in the field: (a) guard views; (b) poke-a-guarded-function trick; (c) accept when reader context makes it unexploitable. **For Superform (c) is defensible**: SuperLedger reads happen inside Superform's own executor flow, not inside attacker-controlled Aave callbacks; an attacker can't make SuperLedger read the spoke mid-Aave-transaction without already controlling the smart account. Document; don't engineer.

Sources: https://www.chainsecurity.com/blog/curve-lp-oracle-manipulation-post-mortem ; https://www.chainsecurity.com/blog/heartbreaks-curve-lp-oracles ; https://immunefi.com/blog/expert-insights/ultimate-guide-to-reentrancy/ ; https://quillaudits.medium.com/decoding-220k-read-only-reentrancy-exploit-quillaudits-30871d728ad5

### 3.5 Revert isolation & registry-miss behavior
Unregistered key → custom revert (`RESERVE_NOT_REGISTERED` analog); spoke-level reverts (unlisted reserveId → `ReserveNotListed`) isolate via the inherited batch try/catch.

## 4. Registry patterns for non-address-keyed positions

| Pattern | Example | Properties |
|---|---|---|
| Truncated hash of market identity | MorphoBlueMarketRegistry (lower 20 bytes of Id) | Deterministic, pre-computable, collision-safe (~2^-121 accidental / ~2^80 grinding / ~2^160 targeted; collision only blocks second registration) |
| Sequential counter key | none in repo | Not deterministic pre-registration; rejected by precedent |
| Micro-contract per market | per-market wrappers | Deployment per market — what the registry avoids |

**For Aave V4:** `reserveKey = address(uint160(uint256(keccak256(abi.encode(spoke, reserveId)))))` — hash-then-truncate ((spoke, reserveId) is small-structured data, unlike Morpho's already-hashed Id). Provide `computeReserveKey` pure helper. Registration validates `spoke.getReserve(reserveId)` (reverts if unlisted) and stores/verifies `underlying` (+ `decimals`). Since reserveIds are append-only/immutable per spoke, **rebinding risk is strictly lower than Morpho's**. **No IRM-approval analog needed** (no external IRM execution in V4 reads — trust collapses to "is this the canonical spoke proxy", gated by MARKET_MANAGER_ROLE) — note the intentional absence for reviewers. Second in-repo registry precedent: `UniV3CLPRegistry`.

## 5. Integrator precedents for keying Aave positions

- V3 era: integrators key by token address (aToken/variableDebtToken `balanceOf`) — V3 never needed a registry because the protocol minted address-keyed handles.
- **V4 breaks this**: no aTokens on plain Spokes → all integrators key on (spoke, reserveId, side); Aave's own data layer queries spoke-level. The pseudo-address registry is the general fit into an address-keyed accounting system.
- Morpho Blue is the closest structural precedent; v2-core's truncated-Id pseudo-address is the audited in-house adaptation.
- Side separation: supply and debt as two positions under one market key; one shared registry (MorphoBlue precedent: "Markets need only be registered once").

---

## RECOMMENDATIONS

1. **Debt oracle = Euler-shaped identity oracle.** Balance/TVL-by-owner = drawn + premium (`getUserDebt` or `getUserTotalDebt`); `getTVL` = `getReserveTotalDebt(reserveId)`; PPS = `10^decimals`; decimals from registry-stored `Reserve.decimals`. No accrual replication; no extra rounding (pass-through, documented). Copy the feePercent=0 NatSpec block from MorphoBlueDebtOracle incl. `_processOutflow` caveat.
2. **Supply oracle = REAL PPS oracle (fee-capable), not identity.** PPS from `hub.previewRemoveByShares(assetId, oneShareUnit)`; `getBalanceOfOwner` = **shares** (`getUserSuppliedShares`) so cost-basis/fee mechanics work like MorphoBlueYieldSourceOracle; `getTVL` = `getReserveSuppliedAssets(reserveId)`. V4's down-rounding on supply conversions is the conservative direction.
3. **Registry: hash-then-truncate key** with `computeReserveKey` helper; validate + store `(spoke, reserveId, underlying, decimals)` at registration; inherit MorphoBlue roles + 2-day timelocked deregistration + SAFETY INVARIANT verbatim; note intentional absence of IRM machinery.
4. **Don't gate reads on paused/frozen**; optional flags passthrough for monitoring; document accrual-through-pause.
5. **Read-only reentrancy: document, don't engineer.** Ask Joao whether B20 has transfer hooks/callbacks.
6. **Spoke-upgrade risk:** proxies with stable addresses; pin vendored interface, fork-test selectors in CI, ops-monitor Aave governance for spoke implementation upgrades.
7. **Equities notes for the risk section:** Coinbase Onchain SPV issuer (Reg S, no US persons); B20 freely transferable, KYC-gated redemption; corporate actions via internal multiplier (no rebase drift); Chainlink 24/5 feeds freeze off-hours — all absorbed at Aave's layer, none enters Superform oracles. $1M incentive figure not publicly verifiable (precedents: $15M Avalanche, Merit on Base) — confirm mechanism on the call; Merit-style would not touch oracle design.
8. **One-line TokenizationSpoke note:** ERC-4626 wrapper markets are covered by the existing `ERC4626YieldSourceOracle` — scoping guard against duplicate future work.
