# External Research — Binance API, router, bStocks, USD1

Primary sources only where marked. Secondary/unverified claims are labelled.

## ⚠️ HEADLINE: bStocks are NOT balance-rebasing

The earlier conclusion — repeated in two places in this spec — that bStocks "rebase" in the
balance-changing sense is **wrong**. They implement a **display-only multiplier**:

- **EIP-8056 "Scaled UI Amount"** — Draft, created 2025-10-20, authors from Superstate, Uniswap,
  Robinhood, Coinbase (not Binance). https://eips.ethereum.org/EIPS/eip-8056
- **BEP-677** — BNB Chain adoption, Draft, 2026-04-14, adds BSC-only `IERC8056Scheduled` (`0xeb0093dd`).
  https://raw.githubusercontent.com/bnb-chain/BEPs/master/BEPs/BEP-677.md

BEP-677 is normative: standard BEP-20 functions **"MUST continue to operate on raw amounts regardless
of the current multiplier value,"** and DeFi protocols must **"maintain all calculations using raw
amounts only."**

**Consequence for the hook:** `balanceOf` and `totalSupply` are raw and are untouched by a multiplier
change. The mid-swap inflation vector (evm-security.md A4) **does not exist** — a router cannot
inflate our balance delta by moving the multiplier, because the delta is denominated in raw units.
Balance-delta accounting is sound here, and it is sound for a reason stronger than timing.

**Consequence for the vault (out of scope, still blocking):** the multiplier governs *valuation*, not
balance, so NAV/PPS must apply it. Two traps:
1. The flip is **time-triggered and emits no event** at the moment it takes effect.
2. A pending change can be **overwritten and accelerated to the next block**. Real instance: QQQB at
   block 123,084,013, tx `0x4580e9034a38d22f177423b4004b1ddc026f71511cf08d117ee7b55980206391`, moving
   `effectiveAt` forward by 180s. BEP-677 tells integrators not to rely on the announced `effectiveAt`
   and to monitor `UIMultiplierChangeOverwritten`.

**Any cached multiplier is unsafe. Read it fresh at point of use.**

## bStocks — token roster

83 tokens, all 18 decimals, all behind one beacon, one Compliance contract, one PauseManager.
Includes AAPLB, TSLAB, NVDAB, COINB, MSTRB, METAB, MSFTB, GOOGLB, AMZNB plus leveraged/inverse ETF
wrappers (SOXLB, SOXSB, TQQQB, MUUB).

Sampled addresses (on-chain verified): AMDB `0x75Fd4cF6f8392E41E70391D60c90C0D5211603a1`,
CRCLB `0x80f3D493EBCe97e343c53D29a137942416B4ffC0`, MUB `0xcdf2f3e0fa43C47A6662a91C9E4a7C5f69762699`,
SNDKB `0x3eE4dF61bd4F867E349BEaE8bFE07bc31b4850fb`.

- **No official issuer-published address list exists.** Per `bstocks.finance/en/integration`, request
  from `operations@bstocks.finance`. Do not ship a hardcoded roster sourced from third parties.
- ⚠️ `docs.bstocker.finance` is **not official** and lists fake demo tokens. Do not cite it.
- `setName`/`setSymbol`/`setIdentifier` let the admin rename a token at any time. **Never cache
  symbol as identity.**

Issuer: **BTECH Holdings Ltd** (Binance group affiliate), regulated under **ADGM FSRA**. Corroborated
on-chain by ADGM ISIN format and the verified source header citing FSMR 2015 s.58(2)(b).

## bStocks — which powers have actually been exercised

Full `eth_getLogs` history via a BSC archive endpoint:

| Mechanism | Ever used? |
|---|---|
| Per-token blocklist (`AddedToBlocklist`) | **Never — 0 events** |
| Global **sanctions** list | ✅ **Heavily used** — 94 txs, ~2,528 added, 8 removed → **~2,520 live**. Bulk OFAC-style import of 1,913 at block 100,803,824 (2026-05-27, pre-launch), then 1–45 additions every 1–2 days through ~2026-10-01 |
| Per-token pause / `pauseAllTokens` | **Never** |
| Beacon `upgradeTo` | **Never in production** — one `Upgraded` at deploy block 100,899,332; `implementation()` unchanged when sampled at blocks 106M/110M/115M/120M/125.29M |

Caveats: 5 of 491 Compliance log chunks failed, so ~2,520 is a **lower bound**.
`setSanctionedAddresses()` / `resetSanctionedAddresses()` bump an epoch counter that **invalidates the
whole list in one transaction** — "is X sanctioned" is not a monotone predicate. **Do not cache it.**

**Role topology, uniform across all 83 tokens:** `DEFAULT_ADMIN_ROLE` is a single EOA
`0x45e35Fe982F3869221b222Abea372fA97AA7679d`; `ISSUER_ROLE` is the same three addresses everywhere.
**Every resolvable privileged key in the bStocks stack is an EOA — no multisig, no timelock anywhere.**

Geo-restriction (US/UK/EU excluded) is enforced **off-chain** via a REST eligibility endpoint, not in
the contracts.

## bStocks — reverse splits

Capability confirmed by both source and documents; precedent is zero.

- Multiplier range 1e-9x to 1e9x, **no monotonicity constraint**
- bStocks FAQ: "in the case of a reverse stock split, the Multiplier adjust downward"
- ADGM prospectus, Definitions p.7: "'Multiplier' means the on-chain rebasing mechanism by which
  Certificate balances are adjusted to reflect stock splits, **reverse stock splits**, the
  reinvestment of dividends…"
- BEP-677 Rationale: "allows **sub-1× multipliers (e.g., a 0.5× reverse split is `5e17`)**" and warns
  low multipliers can make wallets display zero for small holders

Complete `UIMultiplierUpdated` + `UIMultiplierChangeOverwritten` history, all 83 tokens, blocks
102,000,000 → 125,294,333, no unresolved gaps (83 initial-set events for 83 tokens):
- 83 initial `UIMultiplierUpdated(0 → 1e18)` at deploy
- **24 real updates across 23 tokens — all upward**, every one a cash-dividend reinvestment,
  +0.022% (WDCB) to +0.90% (SOXSB)
- 1 overwrite (QQQB)
- **0 downward events. 0 splits, forward or reverse.**

Includes the leveraged/inverse ETFs, the usual reverse-split candidates. Independently matched against
Binance's announcement feed: ~9 corporate actions Jun–Oct 2026, all cash dividends, none containing
"Split"/"Reverse"/"Delist"/"Halt".

**Genuinely absent from the prospectus** (not merely unfound): no M&A/merger adjustment methodology
(§24.2 only disclaims takeover/squeeze-out rules); delisting/insolvency → "the holder bears that loss
in full… no obligation to compensate"; redemption suspendable at the Issuer's "sole discretion";
**no public corporate-actions calendar** — the only reliable forward signal is on-chain
`pendingMultiplier()` / `hasPendingMultiplier()` / `effectiveAt()`.

Open criticism from the EIP discussion (unverified as to resolution): reverse splits can round small
holders' UI balance to zero with no dust-extinguishment mechanism, and `Σ balanceOfUI ≠ totalSupplyUI`
due to unspecified rounding.

## USD1 on BSC

`0x8d0D000Ee44948FC98c9B98A4FA4921476f08B0d` — proxy deployed block 46,151,905 (2025-01-28);
V1 impl `0x3398385c205c060eF54744eE817c1487e28A6616`; **upgraded to V2 at block 90,773,092,
2026-04-05 13:59:51 UTC**. V2 impl `0x694Aa534bdef8eD63244eB902E7914e527891F08`
(`contracts/StablecoinV2.sol:StablecoinV2`, solc 0.8.24), **verified on Sourcify**, exact match on
both chain 56 (2026-05-20) and chain 1 (2026-05-22).

> **Operational note:** Sourcify's v2 API rejects a malformed EIP-55 checksum with
> `{"customCode":"invalid_parameter"}`, and `/contract/{chainId}/{address}` silently returns all-null
> fields for the same input. Normalise to lowercase or valid EIP-55 before querying, and treat an
> all-null response as "bad request", not "unverified".

**Governance.** `TokenGovernor` uses OZ `AccessControlDefaultAdminRules` with a **3-day
`defaultAdminDelay`**; `DEFAULT_ADMIN_ROLE` is a **3-of-6 Gnosis Safe**
`0x0D190B74308669E8f4fE7DBCe3466169B285289d`. The role split is what matters:

| Role | Reachable by |
|---|---|
| `MINTER_ROLE` / `BURNER_ROLE` | Safe **+ EOAs** `0x2ce40f5C…`, `0x8217fb24…` |
| `FREEZER_ROLE` / `UNFREEZER_ROLE` | Safe **+ EOA** `0x82ac1318…` |
| `PAUSER_ROLE` / `UNPAUSER_ROLE` | Safe + EOA `0x2ce40f5C…` |
| `BRIDGE_MINTER_OR_BURNER_ROLE` | CCIP bridge `0xCe3f7378aE409e1CE0dD6fFA70ab683326b73f04` |
| `drainFrozenAccount`, `batchDrainFrozenAccounts`, `executeTokenFunction(bytes)` (arbitrary call into the token — the path to `reallocate`) | `DEFAULT_ADMIN_ROLE` = the 3-of-6 Safe only |

**Minting and freezing are single-EOA-reachable**; seize/forced-transfer require the Safe.
`getChecker()` = `address(0)`, and the Checker gates only mint/burn, never transfers. `paused()` =
false, no pending default admin.

**Two behaviours that bear directly on D10:**
1. `_approve` is gated by `whenNotPaused notFrozen(from) notFrozen(to)` — a freeze or pause blocks
   even **setting an allowance**, which breaks approve-then-pull flows differently from a
   transfer-only block.
2. **Cross-chain address parity is partial and decimals are not stable.** Identical at
   `0x8d0D…0B0d` on BSC and Ethereum (same impl, ProxyAdmin, TokenGovernor), both 18 decimals. But
   **Monad** USD1 is a different address `0x111111d2bf19e43c34263401e0cad979ed1cdb61` with
   **6 decimals**. No code at `0x8d0D…` on Base, Arbitrum, Optimism, Polygon, Avalanche, Linea,
   HyperEVM or Plasma. **Never hardcode the address or assume 18 decimals across chains.**

WLF's public repo `github.com/worldliberty/usd1-smart-contracts` (HEAD `a881f281`, last commit
2025-07-14) is byte-identical to the **V1** implementation and lacks `drain`, `reallocate` and
`initializeV2` — the issuer's own published repo documents code replaced on 2026-04-05. The live code
is public via Sourcify; the repo simply does not reflect it.

## Binance Trading API and the router — unchanged

Nothing in this pass touches the Target 1 or Target 2 conclusions. Two residual gaps stand:
- **No `DiamondCut` event history** for `0xb300…028d` (superseded: the pinned router is the LiquidMesh
  diamond `0xB444…DA5`, see `technical-spec.md` §"Corrections after implementation") — needs a keyed archive RPC (the same endpoint
  class used for the bStocks history would settle it)
- **The swap facet source remains unverified everywhere**

`/swap` returns `{from, to, data, value, gas, gasPrice}`; `to` is API-chosen per route. Quote responses
carry `approveTarget`; approval responses carry `dexContractAddress`. **LiquidMesh is a vendor label
for `/quote-and-swap`, not a contract.** No on-chain amount-rescaling helper exists.
