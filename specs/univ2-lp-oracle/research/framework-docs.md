# Framework Documentation

## IUniswapV2Pair Interface

```solidity
interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    // ERC20 methods (inherited):
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function decimals() external pure returns (uint8); // always returns 18
}
```

## OpenZeppelin Math Library

### Math.sqrt
```solidity
function sqrt(uint256 a) internal pure returns (uint256);
function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256);
```
- Newton's method, integer-only operations
- Handles edge cases: a == 0, a == 1

### Math.mulDiv
```solidity
function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256);
function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256);
```
- Full 512-bit precision for intermediate result
- Prevents overflow in x * y when result / denominator fits in uint256
- Credit to Remco Bloemen / Uniswap Labs

## IOracle (EIP-7726)

```solidity
interface IOracle {
    function getQuote(uint256 baseAmount, address base, address quote) external view returns (uint256 quoteAmount);
}
```
- Returns value of `baseAmount` of `base` in `quote` terms
- MUST round down towards 0
- Reverts with `OracleUnsupportedPair` if pair not supported
- Reverts with `OracleUntrustedData` if data not reliable

## IERC20Metadata

```solidity
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
```

## Foundry Testing

### Fork Testing
```solidity
uint256 fork = vm.createFork(vm.envString("ETHEREUM_RPC_URL"), blockNumber);
vm.selectFork(fork);
```

### Fuzz Testing
```solidity
function testFuzz_pricePerShare(uint112 reserve0, uint112 reserve1) public {
    reserve0 = uint112(bound(reserve0, 1e6, type(uint112).max));
    reserve1 = uint112(bound(reserve1, 1e6, type(uint112).max));
    // ...
}
```
