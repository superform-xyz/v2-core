# Pendle PT Record Hooks — Interview Notes

- Feature: `RecordPurchasePendlePTHook` + `RecordRedemptionPendlePTHook` (new hooks) that compose
  correctly with the production `PendlePTHook` flow and record into `PendlePTAmortizedOracleV2`.
- Interview date: 2026-08-11
- Security mode: ON (on-chain feature — auto-enabled)
- Branch: `feat/pendle-pt-record-hooks` (off `dev`)

## Summary / Goal

Make the amortized-oracle record hooks derive the recorded PT amount correctly from an actual
`PendlePTHook` trade, in both automatic (`usePrevHookAmount == true`) and manual
(`usePrevHookAmount == false`) modes. The current V2 record hooks pull the amount via the generic
`ISuperHookResult(prevHook).getOutAmount(account)`, which only exposes the previous hook's OUTPUT.
That is correct for a PT purchase (output = PT) but WRONG for a PT sale/redemption (output = asset
received, PT is the INPUT) — so the redemption recorder would record the received asset amount as
`ptSold`.

## Motivating bug

Real PT purchase on Ethereum: `0x62582b07d6c667822af3f1bb03ab2bfa5687cfb1ef7c068df23265ae2c7385fa`.
Adding `RecordPurchasePendlePTAmortizedOracleHook` (non-V2) as the following hook failed during OMS
normalization: `hook_params.syAccountingAssetSpent is required for hook
RecordPurchasePendlePTAmortizedOracleHook`.

Root causes:
1. On a PT purchase, `PendlePTHook` output is PT (PT bought = prev hook OUTPUT amount). On a PT
   sale/matured redemption, `PendlePTHook` input is PT (PT sold = prev hook INPUT amount); its
   output is the asset received and must NOT be recorded as `ptSold`.
2. The generic `ISuperHookResult` interface only exposes output token + amount, so it cannot support
   redemption accounting by itself.
3. The non-V2 purchase recorder requires `syAccountingAssetSpent`, which OMS treats as mandatory
   user input. (V2 already removed this by calling `recordPurchase(market, ptAmount, twapDuration)`
   and computing SY cost on-chain.)

## Requirements (from brief)

### Common amount semantics (both hooks)
Encode `uint256 amount` + `bool usePrevHookAmount`. Behavior:
```
uint256 resolvedAmount = amount;
if (usePrevHookAmount) resolvedAmount = /* operation-specific PendlePTHook amount */;
if (resolvedAmount == 0) revert AMOUNT_NOT_VALID();
```
Encoded amount MAY be zero when `usePrevHookAmount == true`; validation happens AFTER the prev-hook
value replaces it.

### Purchase recorder (`RecordPurchasePendlePTHook`)
- `amount` == PT bought.
- `usePrev == false` → encoded amount; `true` → actual PT **output** amount from `PendlePTHook`.
- Validate preceding op is a PT **purchase** (`Operation.BUY_PT`).
- Validate prev hook's market matches encoded/committed market.
- Validate output token is the PT from `market.readTokens()`.
- Compute SY accounting cost on-chain via the V2 oracle approach — no `syAccountingAssetSpent` user
  input. Selected `twapDuration` must satisfy the oracle's configured minimum.

### Redemption recorder (`RecordRedemptionPendlePTHook`)
- `amount` == PT sold/redeemed.
- `usePrev == false` → encoded amount; `true` → actual PT **input** amount from `PendlePTHook`.
- NEVER use `ISuperHookResult(prevHook).getOutAmount(account)` as `ptSold`.
- Validate preceding op is a PT **sale** (`SELL_PT`) or **matured-PT redemption** (`REDEEM_PT`).
- Validate prev hook's market matches; input token is the PT from `market.readTokens()`.

### New interface on `PendlePTHook`
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
- Populate from ACTUAL execution balance deltas (not quoted amounts), using the existing per-account
  execution context; must not leak across accounts or executions.

### Proposed calldata (keep 52-byte strategy header, market-only `inspect()` commitment, S2 sizeless
metadata, `PipeMode.PASSTHROUGH`)
- Purchase: `bytes32 placeholder0, address placeholder1, address market, uint256 amount, uint32 twapDuration, bool usePrevHookAmount`
- Redemption: `bytes32 placeholder0, address placeholder1, address market, uint256 amount, bool usePrevHookAmount`

## Technical decisions (resolved in interview)

1. **Prev-hook binding = approved address only.** The record hooks pin an immutable approved
   `PendlePTHook` address in their constructor and require `prevHook == APPROVED_PENDLE_PT_HOOK`.
   No ERC-165 check (redundant given the pinned address). This is in addition to the existing
   strategy/Merkle authorization. (A new `PendlePTHook` requires redeploying the record hooks —
   acceptable; matches "treat as new hook deployment".)

2. **Result storage = reuse the existing in-flow per-account context — no new machinery.** The record
   hooks run in the SAME execution sequence immediately after `PendlePTHook`, so they read its result
   exactly like `usePrevHookAmount` reads `getOutAmount(account)` today (set in `PendlePTHook._postExecute`,
   read by the next hook's `build`). Account-keying + same-flow ordering already prevents cross-account /
   cross-execution leaks — no transient-storage, nonce, or execution-id apparatus is added.
   - **Minimal delta to `PendlePTHook`:** it currently tracks only the OUTPUT balance delta
     (`getOutAmount`). To expose PT-spent for sell/redeem, it must ALSO snapshot the INPUT-token
     balance in `_preExecute` and compute the input delta in `_postExecute`, storing operation +
     tokens + input/output amounts in the same per-account context, exposed via `getPendleTradeResult`.

3. **Chains = mirror wherever `PendlePTHook` + `PendlePTAmortizedOracleV2` are already deployed.**

4. **Deployment scripts must keep separate staging vs prod addresses** (distinct approved
   `PendlePTHook` / oracle addresses per environment).

## Operation routing reference (from `PendlePTHook`)
- output == PT && input != PT → `swapExactTokenForPt` (BUY_PT)
- input == PT && output != PT && !yt.isExpired() → `swapExactPtForToken` (SELL_PT)
- input == PT && output != PT && yt.isExpired() → `redeemPyToToken` (REDEEM_PT)
- Header: `inputToken@52`, `outputToken@72`. `_preExecute` snapshots output balance; `_postExecute`
  sets `outAmount = outputBalanceAfter - outputBalanceBefore`.

## Acceptance criteria (from brief)
- Buy → purchase recorder succeeds with encoded `amount == 0` & `usePrev == true`; records actual PT received.
- Purchase no longer requires `syAccountingAssetSpent` (on-chain V2 calc).
- Sell → redemption recorder succeeds with `amount == 0` & `usePrev == true`; records actual PT spent (not output asset).
- Both work in manual mode (non-zero `amount`, `usePrev == false`).
- Zero resolved amount reverts in both.
- Purchase rejects sell/redeem results; redemption rejects buy results.
- Both reject: mismatched market, wrong PT token, incompatible prev hook, stale execution context, result belonging to another account.
- Passthrough preserves prev hook's output amount + output token for downstream hooks.
- Hook-registry normalization accepts both automatic and manual modes using the new schemas.
- Unit + fuzz + fork tests: buy, sell, matured redemption, manual, automatic, TWAP minimum, market mismatch, token mismatch, execution-context isolation.

## Deployment / migration
Treat as a NEW hook deployment (calldata layout, build derivation, runtime bytecode all change):
deploy updated `PendlePTHook` result impl first; deploy the record hooks against the intended
amortized oracle version; register new build paths + impl addresses atomically with OMS support;
update strategy Merkle roots / allowed hook sequences before enabling; retain old hook
records/addresses for historical decoding but block new strategies from the incompatible versions;
verify bytecode + registry metadata on every supported chain; **separate staging vs prod addresses**.

## Out of scope
- Combining purchase + redemption recording into a single hook contract.
- Changing the amortization formula beyond adopting the existing V2 on-chain PT→SY calc for purchases.
- Supporting arbitrary previous swap hooks that don't implement `IPendlePTHookResult`.

## Security focus (for research)
- Cross-account / cross-execution context leakage (the whole point of account-keyed, same-flow read).
- Malicious `market.readTokens()` returning attacker-controlled PT/token addresses (already flagged in
  `PendlePTHook` NatSpec) — record hooks validate against the committed market.
- Balance-delta measurement vs fee-on-transfer / rebasing PT or asset tokens.
- Oracle TWAP manipulation / `twapDuration` minimum enforcement.
- Reentrancy around the pre/post balance snapshots.
- Prev-hook spoofing (mitigated by approved-address pin + strategy/Merkle auth).

## Reference files
- `src/hooks/oracles/pendle/RecordPurchasePendlePTAmortizedOracleHookV2.sol`
- `src/hooks/oracles/pendle/RecordRedemptionPendlePTAmortizedOracleHookV2.sol`
- `src/accounting/oracles/PendlePTAmortizedOracleV2.sol`
- `src/hooks/swappers/pendle/PendlePTHook.sol`
