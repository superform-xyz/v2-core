# Uniswap V3 SwapRouter02 Hook Spec

## Metadata
- Project: Superform v2-core
- Milestone: Multi-chain swap coverage
- Linear Issue: N/A
- Interview Date: 2026-05-31
- Status: [x] Draft / [ ] Ready for Review / [ ] Approved

## Summary

Create `SwapUniswapV3Router02Hook` and `ApproveAndSwapUniswapV3Router02Hook` targeting Uniswap V3 SwapRouter02. The existing v1 hooks use `ISwapRouter.exactInputSingle` (selector `0x414bf389`, includes `deadline`) which is ABI-incompatible with SwapRouter02's `IV3SwapRouter.exactInputSingle` (selector `0x04e45aaf`, no `deadline`). This blocks swap support on Stable chain (988) and limits coverage on chains where only SwapRouter02 is deployed.

The new hooks mirror the v1 pattern with a simplified data layout (141 bytes vs 193 — no deadline field) and improved validations (zero-amount check, same-token check, overflow guard).

## Requirements

### Functional
1. `IV3SwapRouter.sol` interface with `ExactInputSingleParams` (7 fields, no deadline)
2. `SwapUniswapV3Router02Hook` — single execution (swap only)
3. `ApproveAndSwapUniswapV3Router02Hook` — 4 executions (approve(0), approve(amt), swap, approve(0))
4. New `uniswapV3SwapRouter02s` config mapping with addresses for 10+ chains
5. Deployment script integration (availability check, bytecode check, hook deployment)

### Non-Functional
- Data layout: 141 bytes (32 bytes shorter than v1)
- No deadline validation in hook (delegated to bundler, per SECURITY.md item 10)
- Recipient forced to `account` for balance tracking

## Technical Design

### Architecture
Same directory as v1 hooks (`src/hooks/swappers/uniswap-v3/`). New `IV3SwapRouter` interface alongside existing `ISwapRouter`. Both hook types extend `BaseHook` with `HookType.NONACCOUNTING` and `HookSubTypes.SWAP`.

### Data Layout
```
Offset | Field
0      | address tokenIn (20)
20     | address tokenOut (20)
40     | uint24 fee (4, packed as uint32)
44     | uint160 sqrtPriceLimitX96 (32)
76     | uint256 amountIn (32)
108    | uint256 amountOutMinimum (32)
140    | bool usePrevHookAmount (1)
```

### New Files
1. `src/hooks/swappers/uniswap-v3/interfaces/IV3SwapRouter.sol`
2. `src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol`
3. `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol`
4. `test/unit/hooks/swappers/uniswap-v3/UniswapV3Router02UnitTests.t.sol`
5. `test/integration/uniswap-v3/UniswapV3Router02HookIntegrationTest.t.sol`

### Modified Files
1. `script/utils/ConfigBase.sol` — add mapping
2. `script/utils/ConfigCore.sol` — add 16 chain addresses
3. `script/utils/Constants.sol` — add hook keys
4. `script/DeployV2Core.s.sol` — availability + deployment
5. `script/run/regenerate_bytecode.sh` — add contract names
6. `test/utils/Constants.sol` — add MAINNET_V3_SWAP_ROUTER_02

## Implementation Plan

### Phase 1: Core Implementation
- [ ] Create `IV3SwapRouter.sol` interface
- [ ] Create `SwapUniswapV3Router02Hook.sol`
- [ ] Create `ApproveAndSwapUniswapV3Router02Hook.sol`
- [ ] Add config mapping + addresses in ConfigBase/ConfigCore
- [ ] Add hook key constants
- [ ] Write unit tests
- [ ] Write fork integration tests
- [ ] Update deployment script
- [ ] Regenerate bytecode

## Test Plan
- [ ] Unit tests: constructor, data decoding, execution building, balance tracking, inspect, edge cases, fuzz
- [ ] Fork tests: USDC/WETH swaps on Ethereum mainnet SwapRouter02, usePrevHookAmount, slippage revert

## Risks & Mitigations
| Risk | Category | Likelihood | Impact | Mitigation | Precedent |
|------|----------|------------|--------|------------|-----------|
| No deadline in hook | Business Logic | Low | Low | Bundler enforces time; SECURITY.md item 10 accepts this | N/A |
| amountIn=0 from prev hook | Token Behavior | Low | Medium | Added explicit zero-amount check | Algebra hook pattern |
| Sandwich attack on swap | MEV | Medium | Medium | amountOutMinimum + bundler MEV protection | Standard DEX risk |
| Wrong Router02 address | Operational | Low | High | Verified from Uniswap governance + on-chain | N/A |

## Open Questions (Resolved)
| Question | Answer | Decided By |
|----------|--------|------------|
| Same directory or separate? | Same directory | Interview |
| New config or reuse existing? | New `uniswapV3SwapRouter02s` | Interview |
| Keep deadline or skip? | Skip — bundler handles it | Interview |
| Data layout order? | Same order minus deadline | Interview |
| Which chains? | All with canonical Router02 | Interview |
| Fork test chain? | Ethereum mainnet | Interview |

## Interview Notes
See: [interview-notes.md](./interview-notes.md)

## Technical Details
See: [technical-spec.md](./technical-spec.md)

## Research
See: [research/](./research/)

---

## Approval
- [ ] Pod Leader Approved
- Approved date: ___

## Next Steps
After approval, run: `/superform:work specs/uniswap-v3-router02-hook/technical-spec.md`
