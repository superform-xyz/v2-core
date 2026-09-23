# Phase 0 Result — Payload Size Gate: **PASS**

**Date:** 2026-09-21 · **Harness:** `test/unit/adapters/CCTPPayloadSizeGate.t.sol` (5 tests, all passing)
**Ceiling:** `MessageTransmitterV2.maxMessageBodySize() == 8192` (verified live), minus the 228-byte
fixed `BurnMessageV2` prefix ⇒ **hookData must be ≤ 7964 bytes**.

## Verdict

**The adapter-only scope holds.** Realistic CCTP intents fit with room to spare, and the
`CCTPSendHookV2` fallback is **not** justified.

## The binding constraint is destination fan-out, not hook count

The spec predicted hook count would be the cliff. It isn't — it's the number of destination chains in
one signature, because `SignatureData.proofDst[]` carries a **duplicate `executorCalldata` per
destination**.

### Hook-count sweep, single destination (6-tuple, the deployed format)

| Hooks | hookData, no initData | with 320B initData | Fits? |
|---|---|---|---|
| 1 | 2912 | 3232 | ✅ |
| 2 | 3360 | 3680 | ✅ |
| 4 | 4256 | 4576 | ✅ |
| 6 | 5152 | 5472 | ✅ |
| 8 | 6048 | 6368 | ✅ |

~448 bytes per hook. At 8 hooks there is still ~1600 bytes of headroom — the cliff sits around
**11–12 hooks**, far beyond any realistic intent.

### Destination-chain sweep (2-hook intent, 320B initData)

| Destinations | 6-tuple (deployed) | 2-tuple (hypothetical V2) |
|---|---|---|
| 1 | 3680 ✅ | 2688 ✅ |
| 2 | 5184 ✅ | 4192 ✅ |
| 3 | 6688 ✅ | 5696 ✅ |
| 4 | **8192 ❌** | 7200 ✅ |
| 5 | — | **8704 ❌** |

~1504 bytes per additional destination.

## Why `CCTPSendHookV2` is not worth building

The compact 2-tuple saves 992–1888 bytes (the top-level `executorCalldata` copy), which buys **exactly
one more destination chain** — 3 → 4. It does not change the shape of the problem, because the dominant
cost is the per-destination `DstProof` duplication that the 2-tuple *also* pays.

Against that: a new contract, a new bytecode lock, a new deployment index, and an SDK migration. **Not
justified.** Revisit only if 4+ destination chains in a single signature becomes a real product
requirement.

## Guardrails to carry into the SDK

1. **Hard limit: 3 destination chains per CCTP-bearing signature.** 4 overflows at exactly 8192 bytes.
2. Pre-flight assertion on `hookData.length <= 7964` before the user signs, so the failure is caught
   client-side rather than as a revert inside `depositForBurnWithHook`.
3. Hook count needs no product cap — the ceiling is ~11 hooks, well beyond realistic intents.

## Caveats

- `HOOK_DATA_BYTES = 125` models the larger real layouts (`ApproveERC20Hook` = 125;
  `Deposit4626VaultHook` = 85), so the sweep is conservative.
- `PROOF_DEPTH = 8` (a tree over ~256 leaves). Each extra level of depth costs 32 bytes per proof.
- Swap hooks carrying raw router calldata (1inch/Odos) are far larger than 125 bytes and are **not**
  modelled here. An intent chaining a swap on the destination should be measured separately before
  being shipped over CCTP.
