# Stargate Bridge Hook - Interview Notes

## Date: 2026-05-05

## Feature Summary
Create a Stargate V2 bridge hook for Superform, following the same pattern as the existing Across bridge hooks. The hook will enable cross-chain token transfers via Stargate/LayerZero V2 with support for destination chain execution via LZ compose messages.

## Technical Decisions

### Version: Stargate V2
- Uses LayerZero V2 messaging infrastructure
- OFT (Omnichain Fungible Token) pattern
- `Pool.sendToken()` interface on StargatePool contracts
- Actively maintained, modern architecture

### Destination Execution: Yes - with composeMsg
- Enable cross-chain execution on destination using LayerZero's compose pattern
- Same authentication pattern as Across: append validator signature to composeMsg payload
- SuperDestinationExecutor decodes and validates on destination chain
- Signature retrieved from validator contract transient storage (avoids circular dependency with Merkle root)

### Hook Variants: Both
1. **StargateSendHook** - Native ETH via value (no approval needed)
2. **ApproveAndStargateSendHook** - ERC20 approval pattern (approve 0 → approve amount → execute → approve 0)

### Chain Support: All Stargate V2 chains
- Hook is chain-agnostic in implementation
- SuperBundler passes correct pool/endpoint addresses
- Covers: ETH, Base, Arb, OP, Polygon, Avalanche, BSC, and any future Stargate V2 chains

### LayerZero Fee Handling
- Support both native value and LZ fee
- Fees will likely be paid via LZ native fee mechanism
- Need separate field for `lzNativeFee` in hook data, distinct from bridge value

### Send Mode: Both Taxi and Bus
- Configurable via flag in hook data
- Taxi mode: immediate send (higher fee, faster)
- Bus mode: batched messages (cheaper, slower)
- Bundler selects appropriate mode

### Data Encoding: Tight Packing
- Use BytesLib with fixed offsets (consistent with Across hooks)
- Gas efficient for calldata
- Same pattern as existing bridge hooks

### Slippage: Explicit minAmountLD
- Bundler calculates and passes exact minimum amount on destination (in local decimals)
- Consistent with Across's `outputAmount` approach
- More control for the bundler

### Authentication (Destination)
- Same pattern as Across: validator signature appended to composeMsg
- SuperDestinationExecutor integration on destination chain
- Signature from validator transient storage

## Requirements

### Functional
1. Send tokens cross-chain via Stargate V2 pools
2. Support destination chain execution via LZ composeMsg
3. Handle both native ETH and ERC20 tokens
4. Support `usePrevHookAmount` for chaining with previous hooks
5. Support taxi mode (immediate) and bus mode (batched)
6. Proper approval pattern for ERC20 (reset → approve → execute → reset)
7. Append validator signature to destination message for auth
8. Implement `ISuperHookContextAware` and `ISuperHookInspector`

### Non-Functional
- Gas efficient (tight packing, minimal storage)
- Chain-agnostic (bundler provides pool addresses)
- Consistent with existing bridge hook patterns
- No external state dependencies beyond constructor params

## Security Considerations
- Approval race condition mitigation (approve 0 before and after)
- Input validation (minimum data length, zero address checks, zero amount checks)
- Proper handling of `usePrevHookAmount` with Math.mulDiv for outputAmount scaling
- LZ fee handling must not allow fee manipulation
- composeMsg integrity (signature appending must not corrupt payload)

## Testing Strategy
- Unit tests for data encoding/decoding
- Unit tests for both hook variants
- Tests for `usePrevHookAmount` chaining
- Tests with and without destination message
- Tests for taxi vs bus mode
- Integration tests with mock Stargate pool
