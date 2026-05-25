# CCTP Bridge Hooks - SpecFlow Analysis

## Date: 2026-05-06

## User Flows

### Flow 1: Simple CCTP Transfer (no destination execution)
User bridges USDC cross-chain with no destination-side execution.
- hookCallDataLength = 0
- 4 executions: approve(0) → approve(amount) → depositForBurnWithHook(empty hookData) → approve(0)

### Flow 2: CCTP Transfer with Destination Execution
User bridges USDC and triggers Superform operation on destination.
- hookCallDataLength > 0, signature appended from validator
- 4 executions with hookData containing signed destination payload

### Flow 3: Transfer Using Previous Hook's Output Amount
Prior hook (swap, redeem) produces USDC, CCTP hook consumes that amount.
- usePrevHookAmount = true
- maxFee stays static (bundler must set appropriately)

## Critical Gaps Identified

### Gap 1: hookCallData Wire Format
**Resolution**: Use same format as Stargate/Across: `abi.decode(hookCallData, (bytes, bytes, address, address[], uint256[]))` → append signature → `abi.encode(initData, executorCalldata, account, dstTokens, intentAmounts, signature)`. This is passed as `hookData` to `depositForBurnWithHook`.

### Gap 2: maxFee Validation
**Resolution**: Defer to TokenMessengerV2 (same pattern as Stargate not validating LZ fees). The hook passes through maxFee without validation.

### Gap 3: outAmount Post-Execution
**Resolution**: Not applicable — bridge hooks are typically terminal. If needed, set to `amount` (gross amount).

### Gap 4: hookCallDataLength Field
**Resolution**: Keep explicit length prefix in data layout (matches DeBridge pattern). Required because off-chain bundler packs data with explicit lengths.

### Gap 5: inspect() Return Value
**Resolution**: Return `abi.encodePacked(burnToken, address(uint160(uint256(mintRecipient))))` — matches Stargate pattern of returning pool + inputToken + to.

### Gap 6: $10M Limit
**Resolution**: Do NOT enforce at hook level. Let TokenMessengerV2 handle it. Consistent with how other hooks defer protocol-specific limits.

### Gap 7: burnToken Validation
**Resolution**: Check `burnToken != address(0)` (revert ADDRESS_NOT_VALID). Do NOT whitelist to USDC only — TokenMessengerV2 handles token validation.
