# KyberSwap Hook - Interview Notes

## Feature Summary
Create a new swap hook for KyberSwap's MetaAggregationRouterV2, following the same patterns as the existing Odos V2 swap hooks. The hook integrates KyberSwap's aggregator router into Superform's hook system for token swaps.

## Requirements Gathered

### Router
- **KyberSwap MetaAggregationRouterV2** - the aggregator router that routes through multiple DEXes for best price
- Most similar to how Odos works as an aggregator

### Hook Variants
- **Both variants needed:**
  - `ApproveAndSwapKyberSwapHook` - handles ERC-20 approval + swap in one hook
  - `SwapKyberSwapHook` - swap only, assumes prior approval or native ETH

### Chain Support
- All chains where KyberSwap is available
- KyberSwap supports: Ethereum, Arbitrum, Optimism, Polygon, BNB Chain, Avalanche, Base, Fantom, Cronos, zkSync, Polygon zkEVM, Linea, Scroll, Mantle, and more
- Priority: chains where Superform is deployed (Ethereum, Base, BSC, Arbitrum)

### Native ETH Support
- **Yes** - support ETH as input token by sending value with swap call (like Odos SwapOnly variant)

### Referral/Fee System
- **Include if available** - research KyberSwap's fee/referral mechanism and integrate it

### Data Encoding Layout
- **Optimize for KyberSwap** - design the data layout specifically for KyberSwap's router params
- Don't need to match Odos byte offsets, but keep common fields (inputToken, inputAmount, outputToken) in similar conceptual positions

### Inspect Function
- **Mirror Odos pattern** - return relevant address/data for security validation
- Research KyberSwap's router to determine the equivalent field to Odos's executor address

### Slippage Protection
- **Explicit slippage params** - include outputQuote and outputMin in hook data
- Similar to Odos approach, giving more control at the hook level

### Testing
- **Unit + Fork tests** - both unit tests with mocks and fork-based integration tests against live KyberSwap routers

## Technical Decisions
- Follows existing hook patterns: extends BaseHook, NONACCOUNTING HookType, SWAP subtype
- Uses BytesLib for data decoding (same as Odos)
- Implements ISuperHookContextAware for usePrevHookAmount support
- Implements ISuperHookInspector for security validation
- Uses HookDataUpdater for output amount adjustment when chaining hooks
- Pre/post execute pattern tracks output token balance delta

## Security Considerations (Auto-enabled - on-chain feature)
- Approval pattern: approve(0) -> approve(amount) -> swap -> approve(0) for ApproveAndSwap variant
- Router address validation in constructor (non-zero check)
- usePrevHookAmount for safe hook chaining
- Output amount validation via balance checks (pre/post pattern)
- Need to research KyberSwap router's trust model and potential attack vectors
