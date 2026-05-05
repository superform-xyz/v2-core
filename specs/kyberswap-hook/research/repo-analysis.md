# Repository Analysis: Swap Hook Patterns

## Key Findings

### Hook Architecture Pattern
All swap hooks follow a two-variant pattern:
- **SwapOnly** variant: 1 execution (just the swap call). BaseHook.build() adds pre/post = 3 total.
- **ApproveAndSwap** variant: 4 executions (approve(0) + approve(amount) + swap + approve(0)). Total = 6 with pre/post.

### File Layout Convention
```
src/hooks/swappers/<protocol>/
    Swap<Protocol>Hook.sol
    ApproveAndSwap<Protocol>Hook.sol
src/vendor/<protocol>/
    I<Router>.sol
test/unit/hooks/swappers/<protocol>/
    <Protocol>UnitTests.t.sol
test/mocks/
    Mock<Router>.sol
```

### Constructor Pattern
```solidity
constructor(address router_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
    if (router_ == address(0)) revert ADDRESS_NOT_VALID();
    ROUTER = IRouter(router_);
}
```

### Data Encoding
All hooks use tightly packed bytes via BytesLib. `usePrevHookAmount` is always the LAST field (1 byte).

### Two Integration Approaches in Codebase
1. **Odos pattern** (manual struct construction): Hook decodes all params, constructs router call from scratch
2. **1inch pattern** (raw calldata): Hook stores minimal metadata + raw txData from API, validates by decoding txData

### Best Template References
- Spark PSM hooks (cleanest/newest for Odos-style)
- 1inch hook (for raw calldata style - recommended for KyberSwap)

### Deployment Pattern
- DeployV2Core.s.sol uses availability flags + configuration maps for per-chain router addresses
- Pattern: `configuration.kyberSwapRouters[chainId]` with code existence check
