# Security Analysis Report

## Metadata
- **Target:** src/accounting/oracles/ERC20YieldSourceOracle.sol + test/unit/accounting/oracles/ERC20YieldSourceOracle.t.sol + test/integration/accounting/ERC20YieldSourceOracleBSCFork.t.sol
- **Mode:** review (inline scan + 3 parallel agents + on-chain verification of external claims)
- **Date:** 2026-09-16
- **Contract Types Detected:** yield-source oracle (stateless view leaf), token integration
- **Files Analyzed:** 3 primary + 6 context (AbstractYieldSourceOracle, BaseLedger, SuperLedger, FlatFeeLedger, SuperLedgerConfiguration, IYieldSourceOracle)
- **Vulnerability Database:** superform-specs/guidelines/solidity/vulnerabilities.md (36 sections; note: not present at the v2-core path referenced by tooling — found under superform-specs)

## Summary

| Severity | Count | Blocks Merge |
|----------|-------|--------------|
| P0 Critical | 0 | — |
| P1 High | 0 (contract) / see Architectural section | — |
| P2 Medium | 1 | No |
| P3 Low | 7 | No |

## Verdict

**PASS** — no P0 or P1 findings in the contract code. The contract body is stateless
(view/pure only), has no reentrancy/access-control/arithmetic surface, locked pragma,
bare `catch {}` only (no returnbomb), and is strictly harder-guarded than its
identity-PPS sibling (EulerDebtOracle lacks the fee-bypass override this contract adds).

The significant risk mass lives in the **surrounding architecture** (off-chain validator
pricing of issuer-controlled RWA tokens) — see the Architectural Findings section. Those
are launch controls for the whitelisting/validator side, not contract changes.

All five documented-accepted behaviors (feePercent=0 invariant, rebasing/FoT exclusion,
global-totalSupply TVL, batch isolation asymmetry, any-address identity converters) were
verified against actual code paths end-to-end — **zero documentation/behavior mismatches**.
Notably verified: `BaseLedger._processOutflow` with real `SuperLedger` and no cost-basis
snapshot truncates `usedShares` to 0 → recomputed `amountAssets` 0 → fee 0 (benign only
emergently, exactly as the hazard tests pin); `FlatFeeLedger` fees the full principal.

## P2 Findings (Should Fix)

### [P2-1] BSC fork suite would run against a public rate-limited RPC in CI
- **File:** test/integration/accounting/ERC20YieldSourceOracleBSCFork.t.sol:46
- **Category:** Test infrastructure / CI determinism
- **Description:** `vm.envOr("BSC_RPC_URL", <public dataseed>)` with no pinned block means
  `make ftest-ci` would hit a rate-limited public node at latest state — the exact
  flakiness class that got the Flare fork suites excluded from CI. Fleet has two
  conventions: skip-if-env-unset (UniV3CLPOracleFork) or envOr-fallback + CI exclusion
  (Firelight suites).
- **Resolution applied:** kept the Firelight convention (public fallback so the suite runs
  with zero local setup; pinning is impossible on non-archival public BSC nodes, documented
  in the @dev) and added the contract to the Makefile CI fork-suite exclusion list.

## P3 Findings (Consider Fixing)

### [P3-1] Donation-sensitive NAV input (fixed — docs)
- **File:** src/accounting/oracles/ERC20YieldSourceOracle.sol (getBalanceOfOwner)
- **Category:** Vault/NAV accounting (vulnerabilities.md §28.3 analog)
- **Description:** `getBalanceOfOwner(token, strategy)` is the off-chain NAV input and is a
  raw spot `balanceOf`. Anyone can transfer tokens directly to the strategy; the read
  cannot distinguish donated from deposited value. Griefing/accounting-noise (donor loses
  value pro-rata), not theft. The whitelist-diligence NatSpec covered rebasing, FoT,
  blocklist, double-entry, decimals — but not donations.
- **Resolution applied:** donation line added to contract NatSpec diligence list and
  SECURITY.md #15 (off-chain pricer should reconcile balance deltas against executed flows).

### [P3-2] Live token code is issuer-mutable; decimals read live (fixed — docs; see A-1)
- **File:** src/accounting/oracles/ERC20YieldSourceOracle.sol (decimals/getPricePerShare)
- **Category:** Token integration (§10)
- **Description:** Every non-pure read executes issuer-controlled code. A post-whitelist
  upgrade changing `decimals()` shifts `getPricePerShare` by orders of magnitude while
  balances keep their old scaling. Not fixable in a stateless registry-free oracle;
  residual risk is operational. **Confirmed concretely on-chain** — see A-1 (shared
  beacon).
- **Resolution applied:** beacon/implementation monitoring added to the SECURITY.md #15
  whitelister checklist.

### [P3-3] Identity converters ignore assetIn — future-hook footgun (accepted, pinned)
- **File:** src/accounting/oracles/ERC20YieldSourceOracle.sol (getShareOutput et al.)
- **Category:** Logic/semantics (§14, §25)
- **Description:** `getShareOutput(NVDAb, USDC, x) == x` — economically meaningless 1:1 for
  cross-asset queries, no revert. No on-chain consumer exists today (only BaseLedger
  consumes oracles, and only `getPricePerShare`/`decimals`); behavior is pinned by
  `test_fuzz_identity_assetInIgnored` and the contract-level "all cross-asset pricing
  happens OFF-CHAIN" doc. Accepted as-is; revisit if a future hook quotes these as swap
  min-outs.

### [P3-4..7] Style/test-quality (fixed)
- **P3-4** Fork fuzz tests not named `*_fuzz_*`, 256 runs excessive against a live fork →
  renamed and bounded.
- **P3-5** `test_balanceViews_revertForContractWithoutERC20` chained two `expectRevert`s in
  one test → split into two tests.
- **P3-6** `MockRebasingERC20.decimals` was a lowercase constant → function form.
- **P3-7** Constructor NatSpec missing `@notice` → added.

## Architectural Findings (off-chain / operational — outside this contract's fix surface)

These do not gate the contract merge but are **launch controls** for SuperMAG7
whitelisting and the validator network. Severity here reflects risk to the system, not a
contract defect.

### [A-1] All seven B-tokens share ONE upgradeable beacon — single-key re-implementation of the entire whitelist (P1-operational) — VERIFIED ON-CHAIN
- AAPLB/TSLAB/NVDAB (spot-checked; others share the deploy pattern) are 284-byte
  BeaconProxies delegating through beacon `0x156d6DcE9a4F6139a3406f1F021F1A4880De93a3`
  (owner `0x4333DAf4481F281F3D3d2B8735cE80bc00028d0C`, current implementation
  `0xCFEd6c4679297ea4889F8183bC057B4A86C64e46`). One `upgradeTo` on the beacon swaps
  `balanceOf`/`decimals`/transfer semantics for **every whitelisted token simultaneously**,
  with no holder consent and no per-token signal.
- The EIP-1967 implementation slot on the tokens themselves is empty — standard
  proxy-implementation monitoring pointed at the token addresses sees nothing. Monitoring
  must watch the **beacon's** implementation.
- **Launch control:** monitor the beacon implementation address; auto-suspend pricing for
  all B-tokens on change until re-attested.

### [A-2] Issuer corporate-action convention must be pinned per token before pricing (P1-operational)
- External research (bstocks.finance issuer docs) claims B-tokens handle dividends/splits
  via an on-chain balance **multiplier (rebase)**. On-chain probe of the *current*
  implementation found **no** multiplier/rebase selectors — so the mechanism is not live
  today, but the shared beacon (A-1) means it can be introduced in one transaction, and
  competing issuer families genuinely differ (Coinbase B20 = fixed balances + total-return
  multiplier price; Backed = airdrops; Dinari = USDC at ex-dividend).
- If the token's convention and the price feed's convention are mismatched, NAV is wrong by
  the full dividend/split ratio during every corporate-action window (weekend/overnight
  windows of 3-5% single-name moves are documented; splits are 10x-class).
- **Launch control:** whitelist metadata must record each token's corporate-action
  convention + matching feed type, confirmed with the issuer in writing (the NatSpec
  checklist already requires this — it must be enforced, with pricing refusing tokens
  whose convention is unset). Chainlink's tokenized-equity feeds document the reference
  pattern: scheduled pause windows around corporate actions.

### [A-3] Realizability gap: balance reads stay green while value is frozen/unrealizable (P1-operational)
- Stream Finance (Nov 2025, ~$93M + $285M contagion) is the live precedent for
  off-chain-NAV pipelines pricing unrealizable value. For Reg-S tokenized equities the
  concrete triggers are: issuer freeze/blacklist of the strategy address (omnibus DeFi
  addresses are a known compliance target), redemption suspension, custody failure. None
  are visible to `balanceOf`.
- **Launch controls:** periodically `eth_call`-simulate a transfer from the strategy and
  zero valuation on failure; cap position size vs on-chain exit liquidity; monitor issuer
  announcements/attestations; haircut for off-hours pricing (stale-NAV timing arbitrage).

### [A-4] Whitelist economic-identity dedup (P2-operational)
- Multiple issuers now list the same underlying (AAPLx / AAPLB / Coinbase AAPL) and
  bridged copies circulate. The oracle is registry-free by design and identity converters
  answer for any address — dedup must key on (issuer, underlying, chain) in the
  whitelist procedure, not just token address.

## Attack Surface Summary
- **External entry points:** 8 view/pure functions + 3 inherited batch views. No state,
  no auth, no value transfer, no upgrade mechanism.
- **Value transfer points:** none on-chain. The economic surface is the off-chain
  validator reading `getBalanceOfOwner` × off-chain price.
- **Oracle dependencies:** none inbound; this contract IS the (identity) oracle. The real
  price dependency is entirely off-chain.
- **Cross-contract interactions:** staticcalls into issuer-controlled token code
  (decimals/balanceOf/totalSupply) — the only trust edge, covered by A-1/A-2.
- **Ledger interaction:** `getAssetOutputWithFees` bypass (view path) + operational
  feePercent=0 invariant (ledger path) — verified consistent with docs and pinned by tests.
  `getPricePerShare` is constant, so BaseLedger snapshots against this oracle cannot be
  price-manipulated (stronger than the ERC4626 siblings).

## Coding Standards Findings
Fully compliant with fleet idioms (banners, @inheritdoc, unnamed unused params,
custom errors, import order, visibility/mutability — `pure` narrowing of `view` virtuals
correct). `forge fmt` clean, full build clean. The 4 style nits (P3-4..7) were fixed.
Reference note: `guidelines/solidity/coding-rules.md` and `vulnerabilities.md` do not
exist inside v2-core — reviews used superform-specs copies + CLAUDE.md + fleet comparison.

## Security Knowledge Sources
- vulnerabilities.md sections: 1.4, 3, 4, 7, 10, 14, 15, 17, 22, 25, 28, 36 + patterns 50/51 (both confirmed N/A / clean)
- External: bstocks.finance issuer docs, Chainlink tokenized-equity feed docs
  (Coinbase/Robinhood), Stream Finance xUSD postmortems, Kraken xStocks risk disclosures,
  OWASP SC Top 10 2025 (no contract-body hits), BscScan proxy-pattern data
- On-chain verification: BSC mainnet probes of all 7 tokens (metadata, supply), AAPLB
  bytecode disassembly (BeaconProxy), beacon owner/implementation resolution, selector
  scans of the 21KB implementation

## Remediation Applied (this branch, new files only per scope constraint)
1. Contract NatSpec: donation line added to whitelist-diligence list; corporate-action
   bullet strengthened (convention must be pinned per token; shared-beacon note).
   → artifacts regenerated (generated + locked-dev); bytecode and predicted CREATE2
   address UNCHANGED (foundry.toml sets bytecode_hash = "none", so comment-only edits
   don't alter bytecode) — still 0x66005CbCc1Fb2bDea54FE4303bcA7F06219Ce9D7, re-verified
   via Plataberget check simulation (73 checked / 1 missing).
2. Constructor `@notice` added.
3. SECURITY.md #15: donation + beacon-monitoring bullets added to the checklist.
4. Fork suite: fuzz tests renamed/bounded; CI exclusion added in Makefile.
5. Unit suite: chained expectRevert test split; rebasing mock decimals as function.
No base-class or shared-contract files were modified (no fleet-wide bytecode impact).
