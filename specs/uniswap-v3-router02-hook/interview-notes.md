# Interview Notes: Uniswap V3 Router02 Hook

## Date: 2026-05-31

## Feature Summary
Create `SwapUniswapV3Router02Hook` and `ApproveAndSwapUniswapV3Router02Hook` targeting Uniswap V3 SwapRouter02 interface. The existing v1 hooks use `ISwapRouter.exactInputSingle` (selector `0x414bf389`, includes `deadline` field) which is incompatible with SwapRouter02's `IV3SwapRouter.exactInputSingle` (selector `0x04e45aaf`, no `deadline` field).

## Problem Statement
- Stable chain (988) has canonical Uniswap V3 deployment with only SwapRouter02 (`0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a`), no v1 SwapRouter
- HyperEVM (999) has HyperSwap's v1-style SwapRouter (`0x1EbDFC75FfE3ba3de61E7138a3E8706aC841Af9B`)
- Many chains (Ethereum, Base, Arbitrum, etc.) have SwapRouter02 available but we only configured v1 addresses

## Technical Decisions

### 1. Directory Structure
**Decision:** Same directory (`src/hooks/swappers/uniswap-v3/`)
- Place alongside existing hooks
- Share the directory, add new `IV3SwapRouter.sol` interface

### 2. Configuration
**Decision:** New config entry `uniswapV3SwapRouter02s`
- Separate mapping in ConfigCore.sol
- Both router types can coexist per chain
- Deployer picks the right hook type per chain

### 3. Deadline Handling
**Decision:** Skip deadline entirely
- Remove `deadline` from hook data layout
- Bundler/account is responsible for deadline via multicall wrapper or block.timestamp
- Simplifies data layout (32 bytes shorter)

### 4. Data Layout
**Decision:** Same field order minus deadline
```
Offset | Size | Field
0      | 20   | address tokenIn
20     | 20   | address tokenOut
40     | 4    | uint24 fee (packed as uint32)
44     | 32   | uint160 sqrtPriceLimitX96 (stored as uint256)
76     | 32   | uint256 originalAmountIn
108    | 32   | uint256 originalAmountOutMinimum
140    | 1    | bool usePrevHookAmount
Total: 141 bytes minimum
```

### 5. Chain Deployment
**Decision:** All chains with Router02
- Configure Router02 addresses for all chains that have canonical Uniswap V3 SwapRouter02
- Stable (988): `0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a`
- Ethereum mainnet SwapRouter02: `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45`
- Need to look up addresses for Base, Arbitrum, Optimism, Polygon, etc.

### 6. Testing Strategy
**Decision:** Ethereum mainnet fork + standard coverage
- Fork tests against Ethereum mainnet (more liquidity, well-tested SwapRouter02)
- Standard test coverage: USDC/WETH pair, usePrevHookAmount, zero sqrtPriceLimitX96, invalid data, native ETH revert
- Matches existing v1 test suite scope

## Acceptance Criteria
- [ ] `IV3SwapRouter.sol` interface with `exactInputSingle` (no deadline)
- [ ] `SwapUniswapV3Router02Hook.sol` - swap-only variant
- [ ] `ApproveAndSwapUniswapV3Router02Hook.sol` - approve+swap variant
- [ ] New `uniswapV3SwapRouter02s` config mapping in ConfigCore.sol
- [ ] Router02 addresses configured for all chains with canonical Uniswap V3
- [ ] Unit tests matching v1 hook test coverage
- [ ] Fork tests against Ethereum mainnet SwapRouter02
- [ ] Bytecode regenerated
