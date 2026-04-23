# Algebra Integral Integration Best Practices

## Critical Version Discovery

SparkDEX V4 uses **Algebra Integral v1.2.2**, which has a DIFFERENT interface from v1.0.

### v1.0-integral ExactInputSingleParams (OLDER - e.g., QuickSwap legacy)
```solidity
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 limitSqrtPrice;
}
```

### v1.2-integral ExactInputSingleParams (CURRENT - SparkDEX V4)
```solidity
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    address deployer;        // NEW in v1.2
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 limitSqrtPrice;
}
```

The `deployer` field identifies which pool deployer contract created the pool. In v1.2, different deployers can create different pools for the same token pair, so this is essential for routing.

## SparkDEX V4 Contract Addresses (Flare)
From SparkDEX docs:
- **SwapRouter**: `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F`
- AlgebraFactory: `0x805488DaA81c1b9e7C5cE3f1DCeA28F21448EC6A`
- AlgebraPoolDeployer: `0x59a662Ed724F19AD019307126CbEBdcF4b57d6B1`
- NonfungiblePositionManager: `0x49BE8AA6c684b15e0C5450e8Fa0b16Bec1435596`
- Quoter: `0xD637cbc214Bc3dD354aBb309f4fE717ffdD0B28C`

**NOTE**: Byzantine provided address `0x2a91D9296ee2fe4139b49c7071b2f29f59a9f9aE` which does NOT match the documented SwapRouter. Need to verify what this address actually is.

## Key Differences from Uniswap V3
1. No fee parameter - pools identified by (tokenIn, tokenOut, deployer)
2. Dynamic fees managed by plugins
3. `limitSqrtPrice` instead of `sqrtPriceLimitX96` (same type uint160, same semantics)
4. `limitSqrtPrice = 0` means no price limit
5. No built-in oracle (available via plugins)
6. Custom errors for gas efficiency
7. Has `exactInputSingleSupportingFeeOnTransferTokens` for fee-on-transfer tokens

## Security Considerations
- Same deadline/slippage enforcement as UniV3
- `limitSqrtPrice` protects against sandwich attacks
- Router uses `checkDeadline` modifier
- Router enforces `amountOutMinimum` via require

## Sources
- [Algebra Integral SwapRouter Docs](https://docs.algebra.finance/algebra-integral/integration-of-algebra-integral-protocol/specification-and-description-of-contracts/swaprouter)
- [Algebra GitHub - ISwapRouter v1.0](https://github.com/cryptoalgebra/Algebra/blob/v1.0-integral/src/periphery/contracts/interfaces/ISwapRouter.sol)
- [Algebra GitHub - ISwapRouter v1.2](https://github.com/cryptoalgebra/Algebra/blob/v1.2-integral/src/periphery/contracts/interfaces/ISwapRouter.sol)
- [SparkDEX V4 Contract Addresses](https://docs.sparkdex.ai/additional-information/smart-contract-overview/v4-dex)
- [Migration from UniswapV3](https://github.com/cryptoalgebra/algebra-integral-docs/blob/main/integration-of-algebra-integral-protocol/migration-from-uniswapv3.md)
