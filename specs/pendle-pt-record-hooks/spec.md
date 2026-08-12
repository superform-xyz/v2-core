# Pendle PT Record Hooks Spec

## Metadata
- Project: v2-core
- Milestone: Hook standardization / Pendle PT accounting
- Linear Issue: N/A
- Interview Date: 2026-08-11
- Status: [ ] Draft / [x] Ready for Review / [ ] Approved

## Summary

The amortized-oracle record hooks currently source their recorded PT amount from the generic
`ISuperHookResult.getOutAmount(account)`, which only exposes a hook's **output**. That is correct for
a PT purchase (output = PT) but wrong for a PT sale/redemption (output = the asset received; PT is the
**input**) — so the V2 redemption recorder records the received asset as `ptSold`. The generic result
interface cannot express a trade's input side, and the pre-V2 purchase recorder additionally demanded
`syAccountingAssetSpent` as user input (the motivating OMS-normalization failure on tx
`0x62582b…385fa`).

This feature adds two new hooks — `RecordPurchasePendlePTHook` and `RecordRedemptionPendlePTHook` —
that read a new context-aware `IPendlePTHookResult.TradeResult` from the production `PendlePTHook`
(operation + input/output token + input/output amounts, populated from **actual balance deltas**),
resolve the correct PT amount per operation, and record into `PendlePTAmortizedOracleV2` with the
on-chain PT→SY calc (no `syAccountingAssetSpent`). Because calldata layout and bytecode change, this
ships as a **new hook deployment**.

## Requirements

### Functional
1. Both hooks encode `uint256 amount` + `bool usePrevHookAmount`; `resolvedAmount = usePrev ? (op PT amount) : amount`; revert `AMOUNT_NOT_VALID` if `resolvedAmount == 0` **after** resolution.
2. Purchase recorder: `amount` = PT bought; auto = `TradeResult.outputAmount`; require `operation == BUY_PT`, `outputToken == PT`, market match; call `recordPurchase(market, ptBought, twapDuration)` (on-chain SY cost; `twapDuration >= getMinTwapDuration`).
3. Redemption recorder: `amount` = PT sold/redeemed; auto = `TradeResult.inputAmount`; require `operation ∈ {SELL_PT, REDEEM_PT}`, `inputToken == PT`, market match; call `recordRedemption(market, ptSold)`. Never use `getOutAmount` as `ptSold`.
4. Extend `PendlePTHook` with `IPendlePTHookResult` populated from real input+output balance deltas in the existing transient per-account context; add ERC-165 support.
5. Pin an approved `PendlePTHook` in each record hook (checked before any call into `prevHook`).
6. Keep 52-byte header, market-only `inspect()`, S2 sizeless metadata, `PipeMode.PASSTHROUGH` (forwards the swap's output asset+amount).

### Non-Functional
- `TradeResult` strictly in transient nonce-keyed context (no cross-account/execution leak).
- Registry manifests updated for both automatic and manual modes; staging vs prod addresses separated.
- Use `getPtToSyRate` (NOT `getPtToAssetRate`); enforce TWAP minimum.

## Technical Design

### Architecture
In one atomic ERC-7579 executor sequence: `PendlePTHook` executes buy/sell/redeem and writes its
`TradeResult` to transient context in `_postExecute`; the immediately-following record hook's
`build()` reads `getPendleTradeResult(account)`, validates, resolves the PT amount, and emits one
`Execution` to the oracle. Passthrough forwards the swap output downstream.

### Data Model
New `IPendlePTHookResult` (`src/interfaces/`): `enum Operation {NONE,BUY_PT,SELL_PT,REDEEM_PT}`;
`struct TradeResult {operation, market, inputToken, outputToken, inputAmount, outputAmount}`;
`getPendleTradeResult(address) view`. Stored in `BaseHook` transient context at new offsets (≥5),
keyed by `_makeAccountContextKey(account)` + `executionNonce` (existing offsets: outAmount=1,
mutex=2/3, outToken=4).

### API Changes
- `PendlePTHook`: input-token snapshot in `_preExecute`; populate `TradeResult` in `_postExecute`;
  `getPendleTradeResult`; extend `supportsInterface`.
- Oracle (unchanged): `recordPurchase(address,uint256,uint32)`, `recordRedemption(address,uint256)`.
- Calldata — Purchase: `header | market@52 | amount@72 | twapDuration@104 | usePrev@108`;
  Redemption: `header | market@52 | amount@72 | usePrev@104`.

## Implementation Plan

### Phase 1: Interface + PendlePTHook
- [ ] `IPendlePTHookResult` in `src/interfaces/`
- [ ] `PendlePTHook`: input snapshot, `TradeResult` population, `getPendleTradeResult`, ERC-165

### Phase 2: Record hooks
- [ ] `RecordPurchasePendlePTHook`, `RecordRedemptionPendlePTHook` (approved-hook pin, validations, resolution)

### Phase 3: Registry + deploy
- [ ] `manifests/hooks.json` + `hook-sizing-manifest.json` (both modes); `regenerate_bytecode.sh` + locked bytecode (staging+prod)
- [ ] `DeployV2Core.s.sol` wiring (oracle from `pendlePTAmortizedOraclesV2`, approved PendlePTHook per env); mirror deployed chains

### Phase 4: Tests
- [ ] Unit + fuzz + fork (migration/version blocking handled off-chain — out of scope here)

## Test Plan
- [ ] Unit tests for: both record hooks (build shape, all validations/reverts, manual+auto), `PendlePTHook.getPendleTradeResult`
- [ ] Fuzz tests for: `recorded ptBought == output delta` (buy); `recorded ptSold == input delta ≠ output` (sell/redeem); zero-amount revert; TWAP-min boundary
- [ ] Fork tests for: buy, sell, matured redeem, manual, automatic, market mismatch, PT-token mismatch, execution-context isolation, two-trades-in-sequence, passthrough direction (extend `PendlePTHookE2E.t.sol` @ ETH block 24_300_000)

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| TradeResult leaks across account/execution | Business Logic | Low | High | Transient nonce-keyed context; reject stale/foreign result | — |
| Read-only reentrancy of view read by next hook | Reentrancy | Low | High | Post-commit read + mutexes; CEI in snapshots | Curve 2023 ($69M) |
| TWAP manipulation on low-liquidity market | Oracle | Med | High | `twapDuration >= getMinTwapDuration`; reject spot; require cardinality | Penpie 2024 (~$27M) |
| Prev-hook spoofing / wrong recorder pairing | Access Control | Low | High | Approved-hook pin (before any call) + market/PT-token match | Cork 2025 (~$11M) |
| Fee-on-transfer/rebasing skews input or output delta | Token Behavior | Low | Med | Measure `balanceOf` deltas both sides; consistency with oracle re-derivation | — |
| SY-vs-asset rate confusion in cost basis | Business Logic | Low | High | Use `getPtToSyRate`; redemption is 1:1 in SY terms | — |
| Genuine zero-fill reverts atomic action | Business Logic | Low | Med | Accepted by design (G-1: always revert per brief) | — |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Prev-hook binding: address vs ERC-165 | Approved address only (pinned), no ERC-165 | User (interview) |
| TradeResult storage mechanism | Reuse existing transient per-account context; add input-delta capture — no new machinery | User (interview) |
| Deploy chains | Mirror where `PendlePTHook` + `PendlePTAmortizedOracleV2` are deployed | User (interview) |
| Deploy scripts | Separate staging vs prod addresses (`env` 0/2 → locked-bytecode / -dev; `saltNamespace`) | User (interview) |
| G-1: zero resolved amount | Always revert `AMOUNT_NOT_VALID` in both modes, per brief (a genuine zero-fill reverts the atomic action by design) | User |
| G-2: OMS normalization coverage | Out of scope — OMS lives off-repo; this repo only ships the manifests (informational) | User |
| G-3: PT-token validation source | Re-read `readTokens()` on the committed + `TradeResult`-matched market (Merkle-anchored, not caller-arbitrary) | User |
| G-4: old-version migration block | Handled off-chain (strategy config / Merkle-root generation); no on-chain gating in scope | User |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/) — repo-analysis, framework-docs, best-practices, evm-security, specflow-analysis

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/pendle-pt-record-hooks/technical-spec.md`
