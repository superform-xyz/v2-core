# EVM Security Analysis — ApproveAndSwapBinanceHook

Grounded in: `SuperVaultStrategy.sol:273` (`executeHooks`), `:730` (`_processSingleHookExecution`),
`:1115` (`_validateHook`), `SuperVaultAggregator.sol:1341` (`_createLeaf`), `:1360`
(`_validateSingleHook`), `BaseHook.sol:186-205`, `SwapKyberSwapHook.sol`, `ApproveAndSwapOdosV2Hook.sol`.

NOTE: `/guidelines/solidity/vulnerabilities.md` does not exist in this environment. Sources are
OWASP SCS Top 10 (2025), SWC Registry (vocabulary only — unmaintained), and primary incident writeups.

## CORRECTION (post-dated, after external research)

**A4 is withdrawn, and so is the "rebase cannot land mid-transaction is false" finding below.**
bStocks implement EIP-8056 / BEP-677 "Scaled UI Amount" — a display-only multiplier. BEP-677 is
normative that standard BEP-20 functions operate on raw amounts regardless of the multiplier, so
`balanceOf` and `totalSupply` are raw. A router cannot inflate the balance delta by moving the
multiplier. The reasoning below was sound given the premise that bStocks were balance-rebasing; that
premise was wrong. Mitigation 4 is dropped (decision D13).

The A5 downstream-sizing concern survives in its donation form, and section C's share-vs-balance
and aAMPL points survive as **valuation** concerns for the vault, not balance concerns for the hook.

## Assumptions that were WRONG

**"Rebase cannot land mid-transaction."** False. `_preExecute` is execution `[0]` and `_postExecute`
is `[n-1]` of the same call (`BaseHook.sol:175-188`). Between them the pinned diamond runs
attacker-chosen code with full control of the call stack. If `rebase()` is permissionless, a router
implementation calls it mid-swap and the delta is credited `existingBalance x rebaseFactor`.
**Blocking question: is `rebase()` on a deployed bStock callable by an unprivileged address?**

**"outputMin bounds the loss."** It lives at offset 156 and is supplied by the same actor that
supplies the calldata, and is not in the Merkle leaf. 1 wei passes the non-zero check. Against an
honest manager it is a real mistake guard; against a compromised OMS key it is nothing — the same
concession the source already makes at `SuperVaultStrategy.sol:763`.

**"Pinning the router secures the call."** It prevents caller-retargeting and nothing else.

**Unlisted but load-bearing:** for a plain `Swap` variant the input side is entirely unbound.
`inputToken` (52) and `inputAmount` (92) never reach the executed call — the spend amount is inside
the blob. The only input-side bound in the system is the live allowance. This is why D10 ships
`ApproveAndSwap` only.

## A. Attack surface

| # | Vector | Precondition | Impact |
|---|---|---|---|
| A1 | Allowance harvesting — blob pulls a different approved token, or the full allowance rather than `inputAmount` | any residual allowance | loss up to residual allowance |
| A2 | `outputMin = 1 wei`; router keeps the input, returns dust | compromised key | ≈ full `inputAmount` |
| A3 | Receiver redirection — recipient lives in the blob, nothing binds it to the strategy | A2 | ≈ full `inputAmount` |
| A4 | ~~Intra-tx rebase inflation~~ **WITHDRAWN** — see correction below | — | none |
| A5 | Downstream sizing poisoning — inflated `getOutAmount` consumed by the next hook's `usePrevHookAmount`, which skips the strategy backstop | A4 or donation + multi-hook batch | over-sized follow-on leg |
| A6 | Global-root over-authorization — `_validateSingleHook` tries the global root first (`:1142`); a global leaf authorises every SuperVault | leaf in global root | blast radius = all strategies |
| A7 | Returndata / gas bomb — `target.call` discards unbounded returndata | malicious impl | batch DoS |
| A8 | Liveness coupling — any `to` change bricks the hook until redeploy | normal ops | cannot trade the mandate |
| A9 | Negative rebase underflow → `panic(0x11)` | reverse split in-tx | opaque fail-closed DoS |
| A10 | PPS auto-pause as split-day DoS — 50% deviation default (`SuperVaultAggregator.sol:70`) → `checksFailed` → auto-pause + `ppsStale` (`:1286`); blocks deposits, mints, redeem fulfilment | corporate action, calendar-predictable | vault frozen on a known date |

**Reentrancy is genuinely small and should not absorb mitigation budget.** `executeHooks` is
`nonReentrant`; `preExecute`/`postExecute` require `msg.sender == account` with one-shot mutexes;
`handleOperations*` are vault-gated; PPS is pushed by `ECDSAPPSOracle` rather than derived from
balances. The classic "reenter a deposit at mid-swap depressed NAV" does not work here.

## B. The diamond

Given `.call` (not `delegatecall`) from the strategy, a malicious implementation **can**:
`transferFrom` up to the live allowance; return success having delivered nothing; deliver to a third
party; call any other contract as itself including `bStock.rebase()`; emit events that off-chain
NAV tooling consumes; grief with gas and returndata; fail selectively by caller to evade monitoring.

It **cannot**: write strategy storage; move unapproved tokens; impersonate the strategy to the
aggregator; spend BNB (ERC20-only, `value == 0`); re-enter `executeHooks`/`pre`/`postExecute`.

Metamorphic address reuse is dead on BSC post-EIP-6780 (Tycho / BEP-344), so the concern is not
`SELFDESTRUCT`-and-redeploy — it is the mutable selector map, which achieves the same effect without
the trick. Pinning the address is equivalent to pinning a proxy whose admin is a third party, with
monitoring deliberately unavailable.

## C. Rebasing-token risks

- Intra-tx induced rebase — A4, the real break. Mitigated by the `totalSupply` invariant (D9).
- Front-running an *external* rebase does not help; both snapshots land the same side. Exposure is specifically intra-tx.
- Negative rebase — A9. Also at vault level: a reverse split shrinks `balanceOf` with no economic loss; any NAV path pricing per-unit without a split-adjusted index reports a cliff, and >50% trips auto-pause.
- Donation — inflates the delta. Negative-EV for the donor, so griefing and accounting pollution rather than theft, except via A5.
- Share-vs-balance semantics — if bStock is `shares x index`, the delta is index-dependent and not a stable unit of account across blocks. Off-chain accounting storing the delta as a quantity will drift. This is what broke aAMPL.

## D. Restricted-token risks

- **DoS on acquisition** — paused/blocklisted bStock reverts the whole batch. Atomic, safe, annoying.
- **Half-complete swap** — impossible within one tx (any failed execution reverts, `:756`). Possible across the trust boundary if Binance ever routes USD1→bStock through a request/settle flow: the input leaves and the delta is 0. Fails closed only while `outputMin` is meaningful; at `outputMin = 1` a non-atomic route silently becomes an unsecured IOU.
- **Funds stranded (the real risk)** — both legs are issuer-controlled. A blocklisted or non-whitelisted strategy address leaves the position immobile while NAV still reports it live. Worse with force-transfer/wipe powers typical of regulated token standards: the position can be seized to zero, and the NAV cliff trips the deviation auto-pause, freezing redemptions exactly when users want out.
- **Migration trap** — per-address whitelisting means a future strategy migration cannot move bStocks. Do not design for in-kind bStock redemption. Verify the strategy address can both send and receive before deploying capital.

## E. Merkle leaf

Leaf is `keccak256(bytes.concat(keccak256(abi.encode(hookAddress, inspect(data)))))`.

Because `hookAddress` is in the leaf and the router is an immutable constructor arg, **the router is
already committed transitively — putting it in `inspect()` adds nothing. Drop it.**

`inspect()` MUST commit:
1. `outputToken` — without it, one leaf authorises swapping into any token (laundering path; makes A3 trivially profitable via an attacker-deployed token).
2. `inputToken` — the gap in the Kyber/Odos siblings, and it matters more here because nothing else bounds the input. Without it a leaf minted for "USD1 → bStock" authorises calldata spending any token approved to that router. Socket/Dexible shape exactly.
3. A bound on value at risk — `outputMin` cannot be committed verbatim (it moves every quote), so commit a quantized proxy: immutable `MAX_INPUT_AMOUNT`, or a bucketed input ceiling in the leaf.

Concretely, with leaf = `(hook, bStock)` only: a key holding that one leaf can, in a single
`executeHooks`, consume any residual allowance, spend the entire input balance rather than
`inputAmount`, direct output to itself, and pass `outputMin = 1`. One leaf, full principal.

Use `abi.encode` inside `inspect()`, not `abi.encodePacked` — packed is unambiguous only while every
committed field is fixed-width.

## F. Exploit precedents

Opaque calldata forwarded to a swap target plus standing approvals is the single most reliably
exploited pattern in DeFi, and it is the shape of this hook.

| Incident | Date | Loss | Mechanism | Relevance |
|---|---|---|---|---|
| **Li.Fi** | Jul 2024 | ~$9.7–11.6M | `GasZipFacet`, added 5 days earlier, allowed arbitrary user-controlled calls while every other facet validated against a contract+selector allowlist; 153 infinite-approval wallets drained | A diamond, one bad facet, an unvalidated blob, approvals as the loss surface. Li.Fi shipped the same class in 2022 *and* 2024 — note the base rate |
| **Socket / Bungee** | Jan 2024 | $3.3M | "Incomplete validation of user input" on a route added 3 days earlier; zero-value txs with injected `transferFrom` drained ~700 standing-approval wallets | Exactly the mechanism of A1 |
| **Dexible** | Feb 2023 | ~$2.05M | `selfSwap` let callers supply their own router; attacker's "router" called `transferFrom` on every approved account | This is what pinning prevents. Credit where due — D1 closes exactly this |
| **Transit Swap** | Oct 2022 | ~$21M | `claimTokens` external call with unvalidated parameters; attacker named token and `transferFrom` args | Same class |
| **Multichain** | Jul 2023 | ~$126M | Not a code bug — operator key compromise; routers holding user approvals drained | The counterfactual for "the router is operated by a reputable affiliate." Reputation does not bound an allowance; only the allowance does |
| **Tornado Cash gov** | May 2023 | ~483k TORN | `CREATE2` + `SELFDESTRUCT` morphing; audited code at a known address became different code | Dead on BSC post-EIP-6780, but "an address is not a behavior" is the whole of section B |
| **Balancer + STA** | Jun 2020 | ~$450–523k | Pool accounting assumed `balanceOf` moved only by amounts it transferred; a 1% burn-on-transfer token broke it | Canonical failure of balance-delta accounting against a token whose balance moves for unmodelled reasons — i.e. the definition of a rebasing token |
| **Aave aAMPL** | 2022+ | no theft | Custom rebase-aware aToken; supply drifted above debt + liquidity; 100% utilisation | **Depositors could not withdraw for >14 months**, resolved by a negotiated 60/40 split. Closest analogue to a rebasing token in a share-accounted vault. This lands on the vault accounting deferred to a separate spec |

## G. Mitigations, ranked

1. **Ship only `ApproveAndSwap`**, emitting `approve(0) → approve(exact) → swap → approve(0)`, and assert `allowance == 0` in `_postExecute`. Do not pair a standalone `ApproveERC20Hook` leaf with a plain `Swap` variant — that configuration is Socket. *(adopted: D10)*
2. **Commit `inputToken` and `outputToken` in `inspect()`; drop the router.** *(adopted: D11)*
3. **Bind `outputMin` to something the caller does not choose.** Best: slippage floor against an oracle quote. If no bStock oracle exists, fall back to immutable `MAX_INPUT_AMOUNT` plus an input ceiling in the leaf, so a bad batch is bounded rather than total. State plainly that without this the in-hook check is a mistake guard. *(adopted: D11, fallback form)*
4. ~~Rebase-index invariant across the snapshots.~~ **DROPPED (D13)** — raw-amount semantics make it
   unfireable. See the correction at the top of this file.
5. **Assert `value == 0`**; never read the API's `value`. *(adopted)*
6. **Explicit `OUTPUT_BALANCE_DECREASED`** instead of the A9 panic. *(adopted)*
7. **Leaf in the strategy root, never the global root** (A6). Deployment invariant; nothing in code enforces it.
8. **Pre-trade on-chain gates** — revert if bStock is paused, or if a blocklist/allowlist getter says the strategy cannot both send and receive. Discover these from the deployed contract first.
9. **Selector-map monitoring** — poll `keccak(selector, 0x5e12...a35c5)` every block for every selector the OMS uses; auto-veto the leaf on change via `bannedLeaves`, which does not wait out a timelock. This substitutes for the missing `Upgraded` event.
10. **Governance posture** — no in-kind bStock redemption; a corporate-action runbook that raises `deviationThreshold` ahead of known split dates or pre-pauses deliberately; disclosure that both legs are issuer-freezable.

## H. Fuzz / invariant tests

Fork BSC with live quotes via `surl` (D8). Pair each live test with a **malicious-router harness**
`vm.etch`ed at the pinned address so the adversary is controllable.

Invariants (Medusa/Echidna configs already present):
- `allowance(inputToken, strategy, router) == 0` after every `executeHooks`, all batch shapes
- balances of every token other than input/output unchanged by any execution of this hook
- `getOutAmount == balanceAfter - balanceBefore` and `>= outputMin`, for all router behaviours
- total input spent `<= inputAmount` — **expected to fail without D10/D11**; this is the test that demonstrates the input side is unbound and justifies both
- no reachable state where `inspect(a) == inspect(b)` with differing input/output token or recipient
- `usePrevHookAmount == true` always reverts, including on malformed and truncated `data`

Adversarial cases:
1. Router returns success, transfers nothing → revert on `outputMin`
2. Router sends output to a third party → revert
3. ~~Router calls `rebase()` mid-swap~~ — **withdrawn**. Replace with: router moves the UI multiplier mid-swap → delta must be **unaffected** (asserts the raw-amount guarantee)
4. Negative rebase mid-swap → named error, not `panic(0x11)`
5. Router pulls a second approved token → revert (needs D10/D11)
6. `outputMin = 1` on a near-total-loss route → document that this does *not* revert today
7. Third-party donation between pre and post → delta must not feed a downstream `usePrevHookAmount`
8. Router returns 10MB returndata → batch must not OOG
9. Payload `to` set elsewhere → revert; assert built `target` is the immutable regardless of payload
10. Fuzz `data`/`payloadLength` around `PAYLOAD_DATA_OFFSET = 221` for `BytesLib.slice` over/under-read; siblings have no `MIN_DATA_LENGTH` check
11. bStock paused / strategy blocklisted → clean revert, no partial state
12. Simulate 4:1 and 1:10 rebases, push PPS, assert whether auto-pause trips (expected at the 50% default)

## Bottom line

Pinning the router closes Dexible and nothing else. The real security boundary is the pair
(live allowance x meaningful `outputMin`), and both halves were caller-chosen in the original design
— D10 and D11 fix the first and bound the second. Under the stated full-trust OMS model the residue
is acceptable and consistent with the shipped Kyber/Odos hooks; it will **not** survive a scoped-key
tier or a partner-operated signer, which is plausible given the commercial setup.

The thing most likely to actually cost money is none of the above. It is a pausable, blocklistable,
force-transferable, split-rebasing, jurisdiction-gated output token inside a share-accounted vault
with a 50% PPS auto-pause. That is aAMPL, and aAMPL took fourteen months and a negotiated settlement.

## Sources

Li.Fi: [QuillAudits](https://www.quillaudits.com/blog/hack-analysis/lifi-protocol-exploit) ·
Socket: [Halborn](https://www.halborn.com/blog/post/explained-the-socket-protocol-hack-january-2024) ·
Dexible: [SolidityScan](https://blog.solidityscan.com/dexible-hack-analysis-never-blindly-trust-smart-contracts-c2aee7943c1a/) ·
Transit Swap: [Halborn](https://www.halborn.com/blog/post/explained-the-transit-swap-hack-october-2022) ·
Multichain: [Halborn](https://www.halborn.com/blog/post/explained-the-multichain-hack-july-2023) ·
Balancer/STA: [1inch](https://medium.com/1inch-network/balancer-hack-2020-a8f7131c980e) ·
aAMPL: [Aave governance](https://governance.aave.com/t/ampl-problem-on-aave-v2-ethereum/15886) ·
Tornado: [Halborn](https://www.halborn.com/blog/post/explained-the-tornado-cash-hack-may-2023) ·
[EIP-6780](https://eips.ethereum.org/EIPS/eip-6780) ·
[BEP-344 / Tycho](https://forum.bnbchain.org/t/faq-about-tycho-hard-fork-cancun-on-bsc/2620) ·
[OWASP SCS Top 10 2025](https://scs.owasp.org/sctop10/archive/2025/Top10:2025/)
