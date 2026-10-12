# Interview Notes — Binance Swap Hook (BSC)

- Date: 2026-10-02
- Linear: SUP-21203
- Security mode: auto-enabled (on-chain feature)
- Origin: Notion "Binance Web3 API — bStocks RFQ Integration Brief" (item 2 of 4)
- Explicit instruction: do not rely on the Notion brief alone; research independently

## Context

SuperMAG7 on BNB Chain needs to acquire bStocks (tokenized MAG7 equities) with USD1.
DEX depth is thin, so Binance proposed an RFQ leg via their market maker plus an AMM
fallback. **This spec covers only the AMM fallback hook.**

Scope rationale: the RFQ leg needs zero new Solidity (existing `ApproveERC20Hook` plus
a Merkle leaf). The AMM hook is needed regardless of whether the Binance RFQ commercial
relationship materialises, so it is separable and should ship first.

## Naming correction

The brief calls this "the LiquidMesh DEX router". Binance's dev-docs reference LiquidMesh
only as a *vendor shortcut* for `/quote-and-swap`, not a contract. The hook is named for
the router it pins, not the vendor label: **`SwapBinanceHook`**.

## Decisions

### Round 1

| # | Question | Decision | Rationale |
|---|---|---|---|
| 1 | Router binding | **Immutable + validate `to`** | Matches the invariant across all 4 shipped aggregator hooks. Binance returns a dynamic `to`; hook reverts on mismatch and OMS re-quotes. Rejects the brief's router-in-calldata. |
| 2 | Calldata validation | **In-hook `outputMin` + outcome check** | Router is a mutable selector-dispatch diamond with no stable published ABI, so Kyber-style decode-and-validate is not reliably available. Validate the result, not the intent. |
| 3 | `usePrevHookAmount` | **Unsupported — revert** | No Binance equivalent of KyberSwap's `IScaleHelper`; the embedded amount cannot be safely rescaled. Also keeps the strategy-level slippage check armed, since it is skipped when this flag is true. |
| 4 | Contract scope | **Swap + ApproveAndSwap** | Consistency with odos / kyberswap / openocean / uniswap / aerodrome, which all ship both. |

### Round 2

| # | Question | Decision | Rationale |
|---|---|---|---|
| 5 | bStock rebasing | **Flag loudly, hook-only scope** | Rebase cannot land mid-transaction, so hook balance-delta is sound. Vault-level PPS accounting is where it bites — separate spec, go-live blocker. |
| 6 | `outputMin == 0` | **Revert** (`MIN_OUT_NOT_VALID`) | Mirrors `PendleUnifiedHook:184`. Allowing zero makes the protection opt-out and defeats decision 2. |
| 7 | Native BNB | **Not supported, ERC20 only** | Real flow is USD1 ↔ bStock, both BEP-20. Removes `value:` path, NATIVE sentinel, `_isNativeInput`. |
| 8 | Testing | **BSC fork + live API via surl** | Follows the `OdosAPIParser` precedent. Mocks would encode our assumptions about a diamond we cannot read — the most likely thing to be wrong. |

### Round 3 — after security research (corrections)

Two findings from the EVM security pass invalidated earlier reasoning. Both are recorded
here because decisions 4 and 5 were taken on the strength of claims that turned out false.

**Correction to D5.** The claim "a rebase cannot land mid-transaction, so the hook's balance
delta is sound" is **wrong**. `_preExecute` and `_postExecute` are separate executions in the
same batch, and the router runs between them. If `bStock.rebase()` is permissionless (as
Ampleforth's is), a router implementation can invoke it mid-swap; the delta is then credited
with `existingBalance x rebaseFactor` instead of swap output, defeating `outputMin` entirely.
Magnitude scales with the strategy's existing position, not trade size.

**Correction to D4.** Shipping a plain `Swap` variant alongside a standalone `ApproveERC20Hook`
leaf — the configuration the Notion brief proposes — is the Socket/Li.Fi shape. For the plain
variant the Layer-1 `inputToken` and `inputAmount` are decorative: they never reach the executed
call because the spend amount lives inside the opaque blob. The only input-side bound in the
entire system is the live allowance.

| # | Question | Decision | Rationale |
|---|---|---|---|
| 9 | Rebase inflation | **Enforce invariant in-hook** | Snapshot `totalSupply` in `_preExecute`, revert in `_postExecute` on change. Turns the D5 assumption into an enforced property. |
| 10 | Variant scope (supersedes D4) | **`ApproveAndSwap` only** | Single contract: `approve(0) -> approve(exact) -> swap -> approve(0)`, then assert residual allowance is zero. No standing allowance can exist for the blob to harvest. No plain `Swap` variant ships for this router. |
| 11 | Bounding loss per tx | **Immutable `MAX_INPUT_AMOUNT` + commit `inputToken` in leaf** | `outputMin` is chosen by the same actor that supplies the calldata, so it bounds nothing under a compromised key. The cap makes loss-per-tx finite; committing `inputToken` closes the "any approved token" degree of freedom. |

### Round 4 — open, needs sign-off

| # | Question | Status |
|---|---|---|
| 12 | `replaceCalldataAmounts` / hook-sizing mode | **OPEN.** Modern swap hooks register as `replaceCalldata`, letting the OMS resize by rewriting Layer-1 `inputAmount`. For Binance that desyncs the header from the amount embedded in the opaque blob. Candidate: declare `sizeless` and revert in `replaceCalldataAmounts`. Consistent with D3. |

## Design properties that follow (not decisions, but spec requirements)

- `inspect()` commits `abi.encodePacked(inputToken, outputToken)` (**corrected 2026-10-12** — was `abi.encode`; the periphery root generator only emits 20-byte packed address args, and two fixed-width addresses are unambiguous). The router is **not** committed —
  it is an immutable, so `hookAddress` already pins it transitively through the leaf.
- ~~Use `abi.encode`, not `abi.encodePacked`, inside `inspect()`.~~ **Withdrawn 2026-10-12.** The
  SuperBank root generator (`v2-periphery/script/superbank-roots/tree_builder.py::encode_hook_args`)
  can only concatenate configured `address` args as raw 20 bytes, so a 64-byte `abi.encode` leaf could
  never be produced off-chain. Two fixed-width addresses packed are unambiguous; the collision concern
  only applies if a variable-length field is ever added, which would be a new hook revision anyway.
- Negative rebase / reverse split must revert with `OUTPUT_BALANCE_DECREASED`, not `panic(0x11)`.
- Every built execution carries `value: 0`; the API's `value` field is never read.
- The leaf must be placed in the **strategy** root, never the global root — a global leaf
  `(hook, bStock)` would authorise every SuperVault in the system. Nothing in code enforces
  this; it is a deployment invariant.
- The spec must state plainly that in-hook `outputMin` is a mistake guard against an honest
  manager, not a control against a compromised key — the same concession the source already
  makes about `expectedAssetsOrSharesOut`.

## What pinning the router actually buys

Exactly one thing: no caller can retarget the call (the Dexible hack, $2.05M, 2023). It does
**not** pin the code. The dispatcher resolves `keccak(selector, 0x5e12...a35c5)` and
`delegatecall`s the result, with EIP-1967 slots empty and no `Upgraded` event. An audit of
today's implementation has a shelf life of one storage write, and that write is unobservable
through standard proxy tooling. Metamorphic redeploy is dead on BSC post-EIP-6780 (Tycho /
BEP-344), so address reuse is not the concern — the mutable selector map is.

Compensating control: poll `keccak(selector, 0x5e12...a35c5)` for every selector the OMS uses,
every block, and auto-veto the leaf on change via the existing `bannedLeaves` / veto path,
which does not wait out a timelock.

### Round 5 — after external research (second correction to the rebase question)

**bStocks do not rebase balances.** They implement **EIP-8056 / BEP-677 "Scaled UI Amount"** — a
display-only multiplier. BEP-677 is normative: standard BEP-20 functions "MUST continue to operate on
raw amounts regardless of the current multiplier value." `balanceOf` and `totalSupply` are raw.

This invalidates the Round 3 correction, not just the original D5 reasoning. The mid-swap inflation
vector does not exist — a router cannot move our delta by moving the multiplier, because the delta is
denominated in raw units. The original conclusion (balance delta is sound) was right; both stated
reasons for it were wrong.

Source of the error: bstocks.finance's own marketing copy says "a built-in rebase mechanism handles
dividends and splits automatically", which is not what the contracts do.

| # | Question | Decision | Rationale |
|---|---|---|---|
| 13 | D9's `totalSupply` guard (supersedes D9) | **Drop it** | Could never fire under raw-amount semantics. Replaced by natspec recording why balance-delta accounting is safe, so the reasoning survives the next reader. |
| 14 | Sanctions / compliance check | **Off-chain pre-trade, none in-hook** | The epoch counter can invalidate the sanctions list mid-transaction, so an in-hook read is not a trustworthy gate. A sanctioned strategy reverts on transfer and the batch fails closed. OMS checks eligibility before quoting; leaf auto-vetoed if the strategy is listed. |

### Where the risk actually moved

Confirmed by full on-chain log history across all 83 bStocks:

- **Every privileged key in the bStocks stack is an EOA.** `DEFAULT_ADMIN_ROLE` on all 83 tokens is
  `0x45e35Fe982F3869221b222Abea372fA97AA7679d`. No multisig, no timelock anywhere.
- **The sanctions list is live and actively worked** — ~2,520 addresses, 1–45 added every 1–2 days
  through October 2026. Per-token blocklist, pause and beacon upgrade have **never** been used.
- **Reverse splits: capable, zero precedent.** 24 multiplier updates ever, all upward, all cash
  dividends. The ADGM prospectus explicitly contemplates downward moves. **No public corporate-actions
  calendar** — the only forward signal is on-chain `pendingMultiplier()`, and a pending change can be
  overwritten and accelerated to the next block (real instance: QQQB, +180s).
- **USD1 `_approve` is gated by `whenNotPaused notFrozen(from) notFrozen(to)`** — a freeze blocks even
  *setting* an allowance, which hits the D10 approve-then-pull sequence differently from a
  transfer-only block. Minting and freezing are single-EOA-reachable; seize needs the 3-of-6 Safe.
- **No official bStocks address list exists.** Roster must come from `operations@bstocks.finance`.
  `docs.bstocker.finance` is not official and lists fake tokens.

## Security probing (DeFi)

Covered during research rather than as separate questions; carried into the attack surface
analysis:

- **Token compatibility** — bStocks are **EIP-8056 / BEP-677 display-multiplier** tokens, NOT
  balance-rebasing (see Round 5). Pausability and a global sanctions list exist and the latter is
  actively used. Issuer is BTECH Holdings Ltd, a Binance affiliate, ADGM FSRA regulated.
- **Upgrade/trust** — target router is a per-selector `delegatecall` dispatcher. Implementations
  are mutable with no EIP-1967 `Upgraded` event to monitor.
- **MEV/slippage** — aggregator hooks currently enforce no slippage in-hook; the only backstop
  is manager-supplied `expectedAssetsOrSharesOut`, explicitly described in source as a mistake
  guard rather than a security control.
- **Access control** — execution is Merkle-gated through `executeHooks`; `inspect()` determines
  what the leaf commits.

## Open questions carried into the spec

1. **Which router address do we pin?** `0xb300000b72DEAEb607a12d5f54773D1C19c7028d` is labelled
   "Binance: DEX Router" and deployed at the same address on BSC/Ethereum/Arbitrum/Optimism/Base,
   but we have not confirmed it is the `to` the API returns for a USD1→bStock BSC route.
   **Blocking** — the chosen design cannot be deployed without it. *(Superseded: pinned router is the
   LiquidMesh diamond `0xB444…DA5`, not `0xb300…028d`; see `technical-spec.md` §"Corrections after
   implementation".)*
2. Does any bStock implement a transfer blocklist or whitelist that would reject the strategy
   address? Must be read from a deployed bStock contract directly.
3. Is `approveTarget` / `dexContractAddress` from the quote response stable enough to hardcode
   as the approval-hook spender leaf?
4. ~~Does the rebase ever go negative?~~ **Resolved (Round 5):** the multiplier can go sub-1x and the
   prospectus contemplates it, but there is zero precedent across all 83 tokens. It affects valuation
   only, never raw balances.

## Notes

- The skill references `/guidelines/solidity/vulnerabilities.md`; this file does not exist in
  v2-periphery, v2-core, or the plugin directory. Security research fell back to evmresearch.io
  and general EVM security knowledge.
