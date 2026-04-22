# UniswapV2Router02 Interface and SparkDex Research

## 1. UniswapV2Router02 Interface

### Core Swap Functions (IUniswapV2Router01)

```solidity
function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external payable returns (uint256[] memory amounts);
function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
```

### Fee-on-Transfer Variants (IUniswapV2Router02)

```solidity
function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external payable;
function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;
```

Note: Fee-on-transfer variants have NO return values.

### Utility Functions
```solidity
function factory() external pure returns (address);
function WETH() external pure returns (address);
function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
```

## 2. SparkDex on Flare

- **QuickSwap fork** (which is itself a Uni V2 fork)
- **Standard UniswapV2Router02 interface** - no modifications
- Router: `0x4a1E5A90e9943467FAd1acea1E7F0e5e88472a1e` (Flare)
- Factory: `0x16b619B04c961E8f4F06C10B42FDAbb328980A89`
- WFLR: `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d`

## 3. Path Format

- `address[] calldata` - flat array of token addresses
- Single-hop: `[tokenA, tokenB]`
- Multi-hop: `[tokenA, tokenB, tokenC]` (two hops)
- For native swaps: path must start/end with WETH address

## 4. Native Token Swaps

- `swapExactETHForTokens`: msg.value is input, path[0] must be WETH
- `swapExactTokensForETH`: path[last] must be WETH, router unwraps and sends native
- Router wraps/unwraps internally

## 5. Return Values

Standard functions return `uint256[] memory amounts` where:
- `amounts[0]` = input amount
- `amounts[amounts.length - 1]` = final output

## Verification Items

1. Confirm router.WETH() returns WFLR address on Flare
2. Confirm router.factory() returns expected factory
3. Verify SparkDex V2 router source is identical to canonical UniswapV2Router02
