# Framework Documentation: Uniswap V3 SwapRouter02

## IV3SwapRouter.ExactInputSingleParams (NO deadline)

```solidity
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    uint24 fee;
    address recipient;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 sqrtPriceLimitX96;
}
```

7 fields. Function signature:
```solidity
function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
```

Selector: `0x04e45aaf`

## Deadline Handling in SwapRouter02

Deadline moved to `MulticallExtended` wrapper:
```solidity
function multicall(uint256 deadline, bytes[] calldata data) external payable checkDeadline(deadline) returns (bytes[] memory)
function multicall(bytes32 previousBlockhash, bytes[] calldata data) external payable checkPreviousBlockhash(previousBlockhash) returns (bytes[] memory)
```

Calling `exactInputSingle` directly = NO deadline enforcement.

## Special: amountIn = 0

In SwapRouter02, setting `amountIn = 0` uses `CONTRACT_BALANCE` pattern (router's current token balance). Our hook should always provide explicit amountIn.

## Canonical Deployment Addresses

| Chain | ID | SwapRouter02 Address |
|-------|----|---------------------|
| Ethereum | 1 | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Base | 8453 | `0x2626664c2603336E57B271c5C0b26F421741e481` |
| Arbitrum | 42161 | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Optimism | 10 | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Polygon | 137 | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| BNB Chain | 56 | `0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2` |
| Avalanche | 43114 | `0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE` |
| Linea | 59144 | `0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a` |
| World Chain | 480 | `0x091AD9e2e6e5eD44c1c66dB50e49A601F9f36cF6` |
| Unichain | 130 | `0x73855d06De49d0fe4a9c42636ba96c62dA12ff9c` |
| Stable | 988 | `0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a` |

**Not confirmed:** Sonic, Gnosis, Berachain, Flare, HyperEVM

## V1 vs V2 Comparison

| Aspect | SwapRouter v1 | SwapRouter02 |
|--------|---------------|--------------|
| Package | @uniswap/v3-periphery | @uniswap/swap-router-contracts |
| Selector | 0x414bf389 | 0x04e45aaf |
| Deadline | In struct | In multicall wrapper |
| V2 routing | No | Yes |
| amountIn=0 | N/A | Uses CONTRACT_BALANCE |
| Return value | uint256 amountOut | uint256 amountOut (same) |

## Source
- [swap-router-contracts repo](https://github.com/Uniswap/swap-router-contracts)
- [IV3SwapRouter.sol](https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/IV3SwapRouter.sol)
- [Official deployment docs](https://github.com/Uniswap/docs/tree/main/docs/contracts/v3/reference/deployments)
