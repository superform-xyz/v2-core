# OFT Send Hook - SpecFlow Analysis

## Flow Permutations Matrix

| Mode | Hook Variant | lzTokenFee | usePrevHook | composeMsg | Execution Count |
|------|-------------|------------|-------------|------------|-----------------|
| 0 (taxi) | StargateSendHook | 0 | false | none | 1 |
| 0 (taxi) | StargateSendHook | >0 | false | none | 4 |
| 1 (bus) | StargateSendHook | 0 | false | none | 1 |
| 1 (bus) | StargateSendHook | >0 | false | none | 4 |
| 2 (OFT) | StargateSendHook | 0 | false | none | 1 |
| 2 (OFT) | StargateSendHook | >0 | false | none | 4 |
| 0 (taxi) | ApproveAndStargateSendHook | 0 | false | none | 4 |
| 0 (taxi) | ApproveAndStargateSendHook | >0 same | false | none | 4 |
| 0 (taxi) | ApproveAndStargateSendHook | >0 diff | false | none | 7 |
| 2 (OFT) | ApproveAndStargateSendHook | 0 | false | none | 4 |
| 2 (OFT) | ApproveAndStargateSendHook | >0 same | false | none | 4 |
| 2 (OFT) | ApproveAndStargateSendHook | >0 diff | false | none | 7 |

All flows also cross-product with `usePrevHookAmount = true` and `composeMsg` populated.

## Key Gaps Identified

### Critical

1. **SendParam struct has `oftCmd` in both IOFT and IStargate** — the framework docs research confirmed the struct is identical. The IOFT interface should include `oftCmd` (pass `bytes("")` for generic OFT sends).

2. **lzTokenFee + Mode 2**: The OFT contract receives lzToken approval and routes it to the LZ endpoint. Same pattern as Stargate. Both hooks should support `lzTokenFee > 0` in Mode 2, with approval target being the OFT address (stored in `stargatePool` field).

3. **ApproveAndStargateSendHook Mode 2 with pure OFT**: Always generate approval executions (4 or 7) regardless of `approvalRequired()`. Approving an OFT that doesn't need it wastes ~200 gas per approve call but is safe and avoids on-chain branching complexity.

4. **StargateSendHook Mode 2 is valid** for native OFTs that burn from caller. `msg.value = lzNativeFee` only. Use case: UP OFT on Base/HyperEVM/Flare.

### Important

5. **Destination executor compose compatibility**: `SuperDestinationExecutor` may need to accept compose deliveries from OFT contract addresses (not just Stargate pools). This is a configuration/deployment concern, not a hook code change.

6. **`inspect()` function**: No changes needed. Off-chain tooling has access to full calldata and can read mode byte at offset 225 directly.

7. **Mode constants**: Use `uint8 private constant` values for readability:
   - `MODE_STARGATE_TAXI = 0`
   - `MODE_STARGATE_BUS = 1`
   - `MODE_OFT = 2`

### Resolved

- **Invalid mode (>2)**: Revert with `MODE_NOT_VALID()` custom error (not reusing `DATA_NOT_VALID()` for clarity)
- **Struct field rename**: `bool isBusMode` → `uint8 mode`
- **Backward compatibility**: Values 0 and 1 maintain identical behavior to `isBusMode` false/true
- **Compose message format**: Identical between Stargate and OFT modes — same signature-appending pattern
- **Refund address**: Same semantics (third parameter to both `sendToken` and `send`)
