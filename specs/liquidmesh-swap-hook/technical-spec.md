# ApproveAndSwapBinanceHook — Technical Specification

- Date: 2026-10-02
- Status: Draft, pending pod leader approval
- Security mode: auto-enabled (on-chain feature)
- Origin: Notion "Binance Web3 API — bStocks RFQ Integration Brief", item 2 of 4

## Corrections after implementation (2026-10-12)

- **Input asset is USDT, not USD1.** SuperMAG7 funds the AMM leg with Binance-Peg USDT on BSC
  (`0x55d398326f99059fF775485246999027B3197955`, "Tether USD", 18 decimals, owner-controlled BEP20).
  Every "USD1" below should be read as the input token in general; the USD1-specific findings
  (`_approve` gated by `notFrozen`, the freezer-role topology, the Monad 6-decimal address) are
  historical and no longer apply. BSC USDT is 18 decimals, so the cap arithmetic is unchanged.
- **`MAX_INPUT_AMOUNT` = 10,000,000 USDT** (`10_000_000e18`), chosen by the pod as a fat-finger
  guard rather than a risk limit. **It is enforced per account per TRANSACTION, not per execution**
  (independent review R-P2-1): a leaf carries no amount, so the same leaf can be repeated N times in one
  `executeHooks`; `_preExecute` keeps a transient running sum of header `inputAmount`s and reverts
  `INPUT_EXCEEDS_CAP` before granting any approval once the sum would exceed the cap.
- **BSC USDT has no pause / freeze / blacklist** (plain non-proxy BEP20, owner `mint`/`burn`); the
  USD1-era "frozen input blocks `_approve`" analysis is vacuous for the real input. The bStock side
  consults `pauseManager().isTokenPaused(token)` and `compliance().checkIsCompliant(from,to)` on
  transfer; both are exercised on the fork (`test_Executor_BStockPaused_*`,
  `test_Executor_StrategySanctioned_*`) and fail the batch closed.
- **Router monitoring**: the diamond has a standard `diamondCut` facet (emits `DiamondCut`) and the
  swap facet keeps a mutable inner-router list (`addRouters` `0x4b01f85e` / `removeRouters`
  `0x5580e904`, `setFeeRecipient` `0xe74b981b`). Subscribe to those events rather than polling a
  selector map (the "no Upgraded event" statement below was written for the `0xb300…` dispatcher).
  The inner-router list on BSC includes the LI.FI Diamond and 1inch v6, i.e. arbitrary-calldata
  routers with caller-chosen receivers — which is why `outputMin` + the per-tx cap are the only
  on-chain bounds against a compromised key.
- **Router** is the LiquidMesh diamond `0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5`, not the generic
  Binance dispatcher `0xb300…028d` named in the problem statement — see "Dependencies & risks".
- **`inspect()` is `abi.encodePacked(inputToken, outputToken)`** — see "Leaf encoding and SuperBank
  root tooling".

## Overview

SuperMAG7 on BNB Chain acquires bStocks (tokenized MAG7 equities) with USD1. DEX depth is thin,
so Binance proposed an RFQ leg through their market maker plus an AMM fallback. **This spec covers
only the AMM fallback hook.**

The RFQ leg needs **zero new Solidity** — it uses the existing `ApproveERC20Hook` plus a Merkle
leaf. The AMM hook is required whether or not the Binance RFQ commercial relationship materialises,
so it is separable and should ship first.

### Naming

The brief calls this "the LiquidMesh DEX router". Binance's dev-docs reference LiquidMesh only as a
*vendor shortcut* for `/quote-and-swap`, not a contract. The hook is named for the router it pins:
**`ApproveAndSwapBinanceHook`**.

## Problem statement

Binance's `/swap` endpoint returns `{from, to, data, value, gas, gasPrice}` — ABI-encoded calldata
for a router the API chooses per route. Four properties make this harder than the four aggregator
hooks already shipped:

1. **The router is dynamic.** Every existing hook pins its router as an immutable. Binance returns
   `to` per quote.
2. **The router is a mutable diamond.** The pinned router is the LiquidMesh diamond
   `0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5` (BSC): a standard `diamondCut` facet plus a swap facet
   with a mutable inner-router list (see "Corrections after implementation"). The research phase
   wrongly identified the generic "Binance: DEX Router" dispatcher `0xb300…028d` (codesize 180,
   `keccak(selector, 0x5e12…a35c5)` → `delegatecall`, no `Upgraded` event) as the target; that
   contract is **not** what the hook pins, but the mutability concern applies to both.
3. **No scaling helper.** `SwapKyberSwapHook` supports `usePrevHookAmount` only because KyberSwap
   ships `IScaleHelper`. Binance ships no equivalent, so amounts inside the blob cannot be rewritten.
4. **The output token is issuer-controlled.** bStocks are EIP-8056 / BEP-677 display-multiplier
   BEP-20s issued by BTECH Holdings Ltd (Binance affiliate, ADGM FSRA regulated). `balanceOf` is raw
   and unaffected by the multiplier, but the issuer holds pause, sanctions-list and raw burn/seize
   powers — and **every privileged key in the stack is an EOA, with no multisig or timelock**.

## Proposed solution

A single `ApproveAndSwap` contract that pins the router, scopes the allowance to one execution,
validates the *outcome* rather than the opaque calldata, and caps loss per transaction.

No plain `Swap` variant ships for this router. For a plain variant the Layer-1 `inputToken` and
`inputAmount` are decorative — they never reach the executed call, because the spend amount lives
inside the blob. Paired with a standing `ApproveERC20Hook` leaf (what the brief proposes), the only
input-side bound in the system is the live allowance. That is the Socket / Li.Fi configuration.

### Design decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Router immutable; reject payload `to` != pinned | Matches the invariant across all four shipped aggregator hooks. Closes Dexible. |
| D2 | Validate outcome, not calldata | Mutable diamond, no stable published ABI. Kyber-style `abi.decode` of the blob is not reliably available. |
| D3 | `usePrevHookAmount` reverts | No scaler. Also keeps the strategy backstop armed — it is skipped when this flag is true. |
| D6 | `outputMin == 0` reverts | Mirrors `PendleUnifiedHook:184`. Independent support in `aggregator-amount-scaling.md` rec #5. |
| D7 | ERC20 only, `value: 0` on every execution | Real flow is USD1 ↔ bStock. Removes the native path entirely. The API's `value` is never read. |
| D8 | BSC fork + live API via `surl` | Mocks would encode guesses about a diamond we cannot read. |
| ~~D9~~ | ~~`totalSupply` invariant~~ — superseded by D13 | — |
| D10 | `ApproveAndSwap` only; assert zero residual allowance | No standing allowance can exist for the blob to harvest. |
| D11 | Immutable `MAX_INPUT_AMOUNT`; commit `inputToken` in leaf as `abi.encodePacked(inputToken, outputToken)` | `outputMin` is caller-chosen, so it bounds nothing under a compromised key. Packed (40 bytes), not `abi.encode`: see "Leaf encoding and SuperBank root tooling" — changed 2026-10-12. |
| D12 | `sizeless` (on-chain S2 form) — **resolved 2026-10-12** | `replaceCalldata` would desync Layer-1 `inputAmount` from the blob: a smaller approve makes the router's pull revert, a larger one trips `MIN_OUT_NOT_MET`. No resize can succeed, so the hook returns empty `decodeAmounts`/`amountRoles`, identity `replaceCalldataAmounts` (reverts `INVALID_AMOUNTS_LENGTH` on non-empty), and is pinned `sizeless` in the generator OVERRIDES (auto-detection would otherwise classify it `replaceCalldata`). `external` rejected: documented as a migration-backlog state, not a permanent one. |
| D13 | No rebase guard | bStocks are EIP-8056/BEP-677 display-multiplier tokens; `balanceOf` is raw, so a guard could never fire. Natspec records why the delta is safe. |
| D14 | No in-hook compliance check | The sanctions epoch counter can invalidate the list mid-transaction, so an in-hook read is not a trustworthy gate. Fails closed on transfer; OMS checks pre-trade. |

## Technical considerations

### What pinning the router actually buys

Exactly one thing: no caller can retarget the call. It does **not** pin the code. Pinning the
address is equivalent to pinning a proxy whose admin is a third party, with monitoring deliberately
unavailable. An audit of today's implementation has a shelf life of one storage write, and that
write is unobservable through standard proxy tooling.

Metamorphic address reuse is dead on BSC post-EIP-6780 (Tycho / BEP-344), so `SELFDESTRUCT`-and-
redeploy is not the concern. The mutable selector map achieves the same effect without the trick.

**Compensating control (off-chain, required):** poll `keccak(selector, 0x5e12...a35c5)` every block
for every selector the OMS uses, and auto-veto the leaf on change via the existing `bannedLeaves`
path, which does not wait out a timelock.

### Honest statement of the residual

In-hook `outputMin` is a **mistake guard against an honest manager, not a control against a
compromised key** — it is supplied by the same actor that supplies the calldata and is not committed
in the leaf, so 1 wei passes the non-zero check. This is the same concession the source already
makes at `SuperVaultStrategy.sol:763` ("not to protect the user but rather a honest manager from
doing a mistake"). `MAX_INPUT_AMOUNT` is what makes loss finite.

Under the house full-trust OMS key model this residue is acceptable and consistent with the shipped
Kyber/Odos hooks. It will **not** survive a scoped-key tier or a partner-operated signer, which is
plausible given the commercial setup.

### Leaf encoding and SuperBank root tooling

How a hook leaf is validated on-chain (v2-periphery):

```
SuperVaultStrategy._validateHook      hookArgs = ISuperHookInspector(hook).inspect(hookCalldata)   ← read on-chain
SuperVaultAggregator._createLeaf      leaf     = keccak256(bytes.concat(keccak256(abi.encode(hook, hookArgs))))
SuperVaultAggregator._validateSingleHook   global root tried first, then strategy root; bannedLeaves veto
```

The proof side never re-encodes anything; only the **off-chain root generator** does. That generator,
`v2-periphery/script/superbank-roots/tree_builder.py::encode_hook_args`, has exactly one encoding: it
takes the `args` listed for the hook in `config/superbank_hook_config.json`, resolves each to an
address, and concatenates them as raw 20-byte values in config order. It cannot emit a 64-byte
`abi.encode(address, address)` without a code change, which is why `inspect()` is packed:

```solidity
inspect(data) = abi.encodePacked(inputToken, outputToken)   // 40 bytes
```

Resulting requirements (all off-chain, none enforceable on-chain):

1. **Config entry with two args, in this order.** Siblings use a single `dst_token` arg; copying that
   yields a 20-byte leaf that never validates (`test_StrategyLeaf_SingleArgConfig_DoesNotValidate`).
   Swapping the order is also a dead leaf (`test_StrategyLeaf_RejectsSwappedArgOrder`).
   ```json
   "ApproveAndSwapBinanceHook": {
     "_comment": "inspect() = encodePacked(inputToken, outputToken). src: BSC USDT only. dst: the bStock roster. Filters are DELIBERATELY unsatisfiable so registry tokens never expand either side; only additionalAddresses contribute.",
     "args": [
       { "name": "src_token", "type": "token", "filter": { "tags": ["mag7-src-only"] }, "additionalAddresses": ["0x55d398326f99059fF775485246999027B3197955"] },
       { "name": "dst_token", "type": "token", "filter": { "tags": ["mag7-bstock-only"] }, "additionalAddresses": ["<AAPLB>", "<NVDAB>", "..."] }
     ]
   }
   ```
   One leaf per (USDT, bStock) pair; the generator takes the product of the two arg lists. **An
   unfiltered `type: "token"` arg means "every registry token on that chain" plus `additionalAddresses`**
   (`tree_builder.py:62`, `superbank_tree_builder.py:151-193`). BSC has no registry tokens today, so an
   unfiltered entry happens to resolve to exactly `{USDT} × {bStocks}` — the day someone registers a BSC
   token for another vault it would silently widen to every registered token on BOTH sides, each leaf
   authorising `MAX_INPUT_AMOUNT` of that token. Hence the filters above. Do not add bStocks to
   `src_token` unless selling bStocks back to USDT is intended — that is a separate leaf and a separate
   `MAX_INPUT_AMOUNT` interpretation (raw bStock units).

   **Caveat on which generator.** `script/superbank-roots/` builds per-hook SuperBank trees and its
   `deployments.json` / `address_registry.json` have no chain-56 entries, so it cannot produce the
   SuperMAG7 SuperVault **strategy** root as-is. The strategy-root generator lives in the OMS / superman
   tooling. The on-chain leaf formula is the same, and `encode_hook_args` here is the reference encoder,
   but the OMS encoder for a two-`address` hook must be confirmed before the first root is proposed.
2. **Strategy root only.** A leaf `(hook, USD1, bStock)` in the global root authorises every SuperVault.
3. **Hook address in `deployments.json`** before generating; `ConfigureV2Periphery.s.sol:_hookKeys()`
   must carry `ApproveAndSwapBinanceHook` for `SuperGovernor.registerHook`.

`test/unit/hooks/swappers/binance/BinanceLeafCommitment.t.sol` replicates both the aggregator leaf
formula and the generator's encoder byte-for-byte and pins every property above.

## Attack surface analysis

### Token risks
- [x] **Display multiplier, not a rebase** — EIP-8056 / BEP-677 mandates raw-amount semantics for
      `balanceOf`/`totalSupply`, so the balance delta is sound whatever the multiplier does (D13)
- [x] **Raw balance decrease** — named `OUTPUT_BALANCE_DECREASED`, not `panic(0x11)`. The multiplier
      cannot cause this, but the issuer's raw burn/seize powers can
- [x] **Pausable / sanctions** — resolved: per-token blocklist and pause have **never** been used;
      the global sanctions list is actively maintained (~2,520 addresses, updated every 1–2 days).
      Handled off-chain per D14; fails closed on transfer
- [ ] **USD1 `_approve` is gated by `notFrozen`/`whenNotPaused`** — a freeze blocks even *setting* an
      allowance, so the D10 sequence fails at execution `[1]` rather than at the swap. Atomic, so no
      stuck state, but the failure mode differs from a transfer-only block
- [x] Missing return values — `abi.encodeCall(IERC20.approve, ...)`; consider SafeERC20 for exotic BEP-20s
- [x] Fee-on-transfer — balance-delta accounting handles it; `outputMin` catches shortfalls

### Reentrancy
Genuinely small; do not spend mitigation budget here. `executeHooks` is `nonReentrant`;
`preExecute`/`postExecute` require `msg.sender == account` with one-shot mutexes; `handleOperations*`
are vault-gated; PPS is pushed by `ECDSAPPSOracle` rather than derived from balances. The classic
"reenter a deposit at mid-swap depressed NAV" does not work.

### Access control & authorization
- [x] Merkle-gated via `executeHooks`; `inspect()` commits `abi.encodePacked(inputToken, outputToken)` (40 bytes — packed, not `abi.encode`, because v2-periphery `tree_builder.encode_hook_args` can only concatenate 20-byte address args; see `BinanceLeafCommitment.t.sol`)
- [x] Router committed transitively through `hookAddress` — **not** duplicated in `inspect()`
- [ ] **Leaf must go in the strategy root, never the global root.** A global leaf `(hook, bStock)`
      authorises every SuperVault in the system. `_validateSingleHook` tries the global root first
      (`SuperVaultAggregator.sol:1142`). Nothing in code enforces this — deployment invariant.

### DeFi interaction risks
- [x] MEV / slippage — in-hook `outputMin` plus strategy `expectedAssetsOrSharesOut`
- [x] Allowance harvesting — D10 scopes approval to the execution and asserts zero residual
- [x] Receiver redirection — caught by the balance delta, given a meaningful `outputMin`
- [ ] Returndata / gas bomb — `_processSingleHookExecution` discards unbounded returndata. Accepted.
- [ ] **Vault-level multiplier valuation** — OUT OF SCOPE, go-live blocker. See below.

### Exploit precedent
Li.Fi (Jul 2024, ~$9.7–11.6M), Socket (Jan 2024, $3.3M), Dexible (Feb 2023, ~$2.05M), Transit Swap
(Oct 2022, ~$21M), Multichain (Jul 2023, ~$126M), Balancer/STA (Jun 2020, ~$450k), Aave aAMPL
(2022+, no theft, >14 months frozen). Full table and relevance in `research/evm-security.md`.

## The thing most likely to cost money is not this hook

A pausable, sanctionable, seizable, multiplier-revalued, issuer-controlled output token inside a
share-accounted vault with a 50% PPS deviation auto-pause is **aAMPL**. Nobody stole anything in that
incident; depositors still could not withdraw for fourteen months, and it resolved through a
negotiated 60/40 settlement.

For the SuperMAG7 vault (all **out of scope here, all go-live blockers**):

- **The multiplier governs valuation and must be read fresh at point of use.** The flip is
  time-triggered and emits **no event** at the moment it takes effect, and a pending change can be
  overwritten and accelerated to the next block — a real instance exists (QQQB at block 123,084,013,
  `effectiveAt` moved forward 180s). BEP-677 tells integrators not to rely on the announced
  `effectiveAt` and to monitor `UIMultiplierChangeOverwritten`. **Any cached multiplier is a bug.**
- **A reverse split is a schedulable outage.** A sub-1x multiplier revalues holdings downward with no
  economic loss; >50% trips `checksFailed` → auto-pause + `ppsStale` (`SuperVaultAggregator.sol:70`,
  `:1286`), blocking deposits, mints and redeem fulfilment. Zero precedent across all 83 tokens so
  far — but there is **no public corporate-actions calendar**, so the only forward signal is polling
  on-chain `pendingMultiplier()` / `hasPendingMultiplier()` / `effectiveAt()`.
- **Sanctioning is the live freeze risk**, not the unused blocklist. One EOA controls a list touched
  every 1–2 days. If the strategy is listed, the position is immobile while NAV still reports it live.
- **Do not design for in-kind bStock redemption**, and verify the strategy can both send and receive
  before deploying capital.
- **Never cache a bStock symbol as identity** — `setName`/`setSymbol`/`setIdentifier` let the admin
  rename a token at any time. And **never hardcode USD1's address or assume 18 decimals across
  chains**: Monad's USD1 is a different address with 6 decimals.

## Implementation

Implementation: [`src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol`](../../src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol) (v2-core)

Six executions total (pre + approve(0) + approve(exact) + swap + approve(0) + post), matching the
`ApproveAndSwap*` count asserted at `OdosV3UnitTests.t.sol:101`.

Follow `CORE/specs/knowledge/integration-issues/adding-dex-swap-hooks.md` and the Aerodrome natspec
style (defers the byte-offset table to `ISuperHookSwap`) rather than Kyber's repeated offset block.

Boilerplate to copy verbatim from `SwapKyberSwapHook.sol:183-230`: `encodeSwapData`, the seven
`decode*` members, `decodeAmounts`, `amountRoles`, `_supportsSizingInterface`.

## Test plan

Per D8: BSC fork, live quotes via a new `CORE/test/utils/parsers/BinanceAPIParser.sol`, paired with a
**malicious-router harness** `vm.etch`ed at the pinned address so the adversary is controllable.

Copy two resilience idioms: retry with `vm.snapshotState()` per attempt
(`KyberSwapBaseNativeE2E.t.sol:34,85`) and `vm.skip(true)` on API failure via an `external` getter so
`try/catch` works (`OdosV3RouterSwapFork.t.sol:38-73`).

`ffi = true` is global and `ftest-ci` excludes only Flare tests, so **this will run in CI** — plan for
API flakiness or gate it.

Invariants and the twelve adversarial cases are enumerated in `research/evm-security.md` §H. The
load-bearing one: *total input spent ≤ header `inputAmount`* — expected to fail without D10/D11, and
the test that justifies both.

## Dependencies & risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Router address | Resolved | — | Pinned to the LiquidMesh diamond `0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5`; the `0xb300…028d` research candidate was the generic dispatcher (see "Corrections after implementation") |
| Diamond implementation swapped | Medium | Critical | Selector-map monitoring + `bannedLeaves` veto |
| Strategy added to the global sanctions list | Medium | Critical | Off-chain monitoring + leaf auto-veto (D14); fails closed |
| Reverse split trips the 50% PPS auto-pause | Medium | High | Poll `pendingMultiplier()`; no public calendar exists |
| bStock admin is a single EOA, no timelock | Confirmed | Critical | Accepted counterparty risk; monitor `implementation()` and role changes |
| Binance changes `to` per route | Medium | Liveness | Fail-closed; OMS re-quotes. Recovery needs redeploy + root update |
| CI flakiness from live API | High | Low | `vm.skip` + retry idioms |

## Open questions

1. ~~Which router address do we pin?~~ **RESOLVED.** The pinned router is the LiquidMesh diamond
   `0xB44446b0c8E56988c34f7Ff73Ae904982b5FdDA5`. The research candidate `0xb300...028d` ("Binance:
   DEX Router", same address on BSC/Ethereum/Arbitrum/Optimism/Base) is the generic dispatcher, not
   the `to` returned for a BSC route — see "Corrections after implementation".
2. ~~Does any bStock implement a blocklist?~~ **RESOLVED.** Per-token blocklist exists but has never
   been used (0 events). The live mechanism is a global sanctions list: ~2,520 addresses, updated
   every 1–2 days, controlled by a single EOA. Handled per D14.
3. ~~Is `rebase()` permissionless?~~ **RESOLVED — question was malformed.** There is no balance
   rebase; the multiplier is display-only and does not touch `balanceOf`.
4. ~~D12 — `sizeless` vs `replaceCalldata` in `hook-sizing-manifest.json`.~~ **RESOLVED: `sizeless`.** See D12.
5. Is `approveTarget` / `dexContractAddress` from the quote response stable enough to hardcode?
6. Does obtaining a Binance API key require KYB? (Gates the RFQ workstream, not this hook.)
7. **Obtain the authoritative bStock roster from `operations@bstocks.finance`** — no official
   published address list exists, and third-party lists include fakes.
8. Residual on the router: no `DiamondCut` event history retrieved (needs a keyed archive RPC), and
   the swap facet source is unverified everywhere.

## Modified files

**v2-core**
- `src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol` *(new)*
- `test/unit/hooks/swappers/binance/BinanceUnitTests.t.sol` *(new)*
- `test/integration/binance/BinanceHookE2E.t.sol` *(new)*
- `test/utils/parsers/BinanceAPIParser.sol` *(new)*
- `test/mocks/MockBinanceRouter.sol` *(new)*
- `test/utils/InternalHelpers.sol` — add `_createBinanceSwapHookData`
- `script/utils/ConstantsOtherHooks.sol` — hook key + router literal
- `script/utils/ConfigOtherHooks.sol` — per-chain router + cap mappings
- `script/DeployV2OtherHooks.s.sol` — `_deployBinanceHooks` + `runBinance` entrypoint
- `script/run/regenerate_bytecode.sh` — add to contracts array
- `hook-sizing-manifest.json` — **D12** (CI-enforced)
- `tooling/hook-classification.yaml`, `tooling/hook-enrichment.yaml` — (CI-enforced)
- `CHANGELOG-hook-descriptions.md`, `CHANGELOG-hook-sizing.md`

**v2-periphery**
- `script/ConfigureV2Periphery.s.sol` — append the JSON key to `_hookKeys()` (`:512-573`)
- `script/superbank-roots/config/deployments.json` — hook-name → address entry
- `script/run/networks-production.sh:13` — uncomment the BSC line if deploying from periphery

No new chain plumbing: BSC/56 routers, constants and six sibling swap hooks are already deployed
(`CORE/script/output/prod/56/BNB-latest.json`). The only BSC gap is that SuperBank roots have never
been generated for it (no `generated/prod/56/`).
