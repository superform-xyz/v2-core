# ApproveAndSwapBinanceHook Spec

## Metadata
- Project: SuperMAG7 / SuperformOS — BNB Chain
- Milestone: bStocks AMM leg
- Linear Issue: SUP-21203
- Interview Date: 2026-10-02
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

> **Correction 2026-10-12:** the input asset is **Binance-Peg USDT on BSC**
> (`0x55d398326f99059fF775485246999027B3197955`, 18 dec), not USD1. `MAX_INPUT_AMOUNT` is
> **10,000,000 USDT** (fat-finger guard). Router is the LiquidMesh diamond `0xB444…DA5`. `inspect()`
> is `abi.encodePacked(inputToken, outputToken)`. See technical-spec "Corrections after implementation".

## Summary

A swap hook letting a SuperVault strategy trade USD1 into bStocks (tokenized MAG7 equities) through
Binance's Web3 Trading API DEX router on BNB Chain. It is item 2 of the four in the Binance RFQ
integration brief, and the only one needing new Solidity — the RFQ leg itself uses the existing
`ApproveERC20Hook` plus a Merkle leaf. Because the AMM path is needed regardless of whether the
Binance RFQ commercial arrangement completes, it is separable and should ship first.

The design departs from the brief in three ways, each driven by research rather than the brief's own
text. The router is **pinned as an immutable** and the API's dynamic `to` is rejected on mismatch,
rather than carried in calldata. Only the **`ApproveAndSwap` variant ships** — a plain `Swap` hook
paired with a standing approval leaf, which is what the brief proposes, is the Socket/Li.Fi
configuration. And the hook **enforces slippage and a rebase invariant in-hook**, which none of the
four existing aggregator hooks do.

## Requirements

### Functional
1. Swap ERC20 → ERC20 via the Binance DEX router on BSC, using calldata from `GET /swap`
2. Reject any payload whose `to` is not the pinned router
3. Scope approval to a single execution: `approve(0) → approve(inputAmount) → swap → approve(0)`
4. Assert zero residual allowance to the router after execution
5. Enforce `received >= outputMin`, and reject `outputMin == 0`
6. Reject `inputAmount > MAX_INPUT_AMOUNT` (per-deployment immutable)
7. Reject `usePrevHookAmount == true`
8. Revert with a named error if the raw output balance fell, not an arithmetic panic
9. `inspect()` commits `abi.encodePacked(inputToken, outputToken)` (40 bytes; packed so the SuperBank root generator can emit it — changed from `abi.encode` on 2026-10-12)
10. No rebase guard and no in-hook compliance check — see D13, D14

### Non-Functional
- ERC20 only; every execution carries `value: 0` and the API's `value` is never read
- Six executions total, matching the `ApproveAndSwap*` count asserted across the family
- Loss per transaction bounded by `MAX_INPUT_AMOUNT`, not by caller-chosen `outputMin`
- No new chain plumbing — BSC/56 is already fully configured

## Technical Design

### Architecture

```
SuperVaultStrategy.executeHooks
  └─ _validateHook ── Merkle leaf = keccak(hookAddress, inspect(data))
                          inspect() = abi.encodePacked(inputToken, outputToken)
                          router committed transitively via hookAddress
  └─ ApproveAndSwapBinanceHook
       _preExecute    balanceOf(outputToken)        ← raw; multiplier is display-only
       [0] approve(BINANCE_ROUTER, 0)
       [1] approve(BINANCE_ROUTER, inputAmount)   ← the ONLY input-side bound
       [2] BINANCE_ROUTER.call(opaque txData)     ← diamond, mutable per-selector
       [3] approve(BINANCE_ROUTER, 0)
       _postExecute   delta >= outputMin?  allowance == 0?
  └─ actualOutput >= expectedAssetsOrSharesOut   (strategy backstop)
```

### Data Model
Standard `SwapCalldataLayout` (52-byte header + Layer 1 + payload). Layer 2 payload is
`abi.encode(address to, bytes txData)`.

### API Changes
None. New contract only.

## Implementation Plan

### Phase 1: Prerequisites (blocking)
- [ ] Capture `to` from a real USD1→bStock `/swap` response; confirm the router address to pin
- [ ] Obtain the authoritative bStock roster from `operations@bstocks.finance` (no official list is published)
- [ ] Stand up sanctions-list monitoring for the strategy address before capital is deployed
- [x] Resolve D12 — `sizeless` (resolved 2026-10-12, see technical-spec D12)

### Phase 2: Contract
- [ ] `src/hooks/swappers/binance/ApproveAndSwapBinanceHook.sol`
- [ ] `ISuperHookSwap` boilerplate copied from `SwapKyberSwapHook.sol:183-230`
- [ ] `test/utils/InternalHelpers.sol` — `_createBinanceSwapHookData`

### Phase 3: Tests
- [ ] `BinanceAPIParser.sol` (surl) + `MockBinanceRouter.sol` + malicious-router harness
- [ ] Unit tests with mock router; BSC fork E2E with live quotes
- [ ] Invariants and the twelve adversarial cases from `research/evm-security.md` §H

### Phase 4: Deploy & register
- [ ] `ConstantsOtherHooks.sol`, `ConfigOtherHooks.sol`, `DeployV2OtherHooks.s.sol`, `regenerate_bytecode.sh`
- [ ] Both CI-enforced manifests + classification/enrichment YAML
- [ ] `SuperGovernor.registerHook`; append key to `ConfigureV2Periphery.s.sol:_hookKeys()`
- [ ] `superbank_hook_config.json` entry with TWO args in order `[src_token, dst_token]` (see technical-spec "Leaf encoding and SuperBank root tooling"); hook address in `deployments.json`
- [ ] Propose leaf **in the strategy root, never the global root**
- [ ] Stand up selector-map monitoring before any capital is deployed

## Test Plan
- [ ] Unit tests for: build-path validation, all nine revert conditions, `inspect()` determinism
- [ ] Integration tests for: live-quote BSC fork swap, six-execution ordering, allowance clearing
- [ ] Adversarial tests for: dust-return, receiver redirection, mid-swap rebase, negative rebase, second-token pull, returndata bomb, `to` mismatch, paused/blocklisted token
- [ ] Invariant: total input spent ≤ header `inputAmount` (expected to fail without D10/D11)

## Risks & Mitigations

| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|---|---|---|---|---|---|
| Opaque blob consumes a standing allowance | Access Control | High (without D10) | Critical | `ApproveAndSwap` only; assert zero residual | Socket 2024 — $3.3M; Li.Fi 2024 — ~$9.7M |
| Leaf authorises spending any approved token | Access Control | High (without D11) | Critical | Commit `inputToken` in `inspect()` | Dexible 2023 — $2.05M |
| Caller retargets the swap to its own router | Access Control | Mitigated | Critical | Router immutable; reject `to` mismatch | Dexible 2023 — $2.05M |
| Diamond implementation swapped silently | Proxy/Upgrade | Medium | Critical | Selector-map polling + `bannedLeaves` veto | Tornado Cash 2023 — 483k TORN |
| Strategy added to the global sanctions list | Token Behavior | Medium | Critical | Off-chain monitoring + leaf auto-veto; fails closed on transfer | — |
| bStock admin is a single EOA, no timelock anywhere | Access Control | Confirmed | Critical | Accepted counterparty risk; monitor `implementation()` and role changes | Multichain 2023 — ~$126M |
| `outputMin = 1 wei` passes the non-zero check | Business Logic | Low (trusted key) | Critical | `MAX_INPUT_AMOUNT` bounds the loss | Multichain 2023 — ~$126M |
| Output token frozen; position immobile | Token Behavior | Medium | Critical | Pre-trade gates; no in-kind redemption | Aave aAMPL — 14 months frozen |
| Reverse split trips the 50% PPS auto-pause | Vault Accounting | Low (0 precedent) | High | Poll `pendingMultiplier()`; no public calendar exists | Aave aAMPL |
| Cached UI multiplier goes stale | Vault Accounting | High | High | Read fresh at point of use; flip emits no event and can be accelerated | QQQB overwrite, block 123,084,013 |
| Binance changes `to` per route | Operational | Medium | Medium | Fail-closed; OMS re-quotes | — |
| Live-API tests flake in CI | Operational | High | Low | `vm.skip` + `vm.snapshotState` retry | — |

## Open Questions (Resolved)

| Question | Answer | Decided By |
|---|---|---|
| Router binding, given a dynamic `to`? | Immutable + reject mismatch | D1 |
| How to validate opaque calldata? | Outcome, not intent — no stable ABI | D2 |
| Support `usePrevHookAmount`? | No, revert — no scaler exists | D3 |
| `outputMin == 0`? | Revert | D6 |
| Native BNB? | No, ERC20 only | D7 |
| Test strategy? | BSC fork + live API via surl | D8 |
| Mid-swap rebase? | ~~Enforce invariant~~ → **no guard**; multiplier is display-only, `balanceOf` is raw | D9 → D13 |
| Which variants ship? | `ApproveAndSwap` only — supersedes D4 | D10 |
| How to bound loss per tx? | `MAX_INPUT_AMOUNT` + `inputToken` in leaf | D11 |
| Where does the compliance check live? | Off-chain pre-trade; none in-hook | D14 |

Still open: the items under "Open questions" in the technical spec (D12 is resolved: `sizeless`), of
which the router address and the bStock token powers are blocking.

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/) — `pre-interview-findings.md`, `repo-analysis.md`, `evm-security.md`,
`framework-docs.md`

Note: `evm-security.md` carries a post-dated correction withdrawing finding A4; `framework-docs.md`
is the authority on token semantics.

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/liquidmesh-swap-hook/technical-spec.md`

Before that, Phase 1 prerequisites must be closed. Two of the original four are now resolved by
research; the remaining blocker is **confirming the router address to pin**, which requires capturing
`to` from a real USD1→bStock `/swap` response.
