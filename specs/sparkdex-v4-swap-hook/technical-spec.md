# Algebra Integral Swap Hook - Technical Specification

## Overview

Create a chain-agnostic swap hook for Algebra Integral DEX routers (used by SparkDEX V4 on Flare, QuickSwap on Polygon, Camelot on Arbitrum). The hook follows the established Uniswap V3 hook pattern but adapts for the Algebra Integral v1.2 router interface which has no `fee` field and includes a `deployer` field.

## Problem Statement

Byzantine requested SparkDEX integration on Flare. The provided address `0x2a91D9296ee2fe4139b49c7071b2f29f59a9f9aE` is NOT the V4 SwapRouter. The actual SparkDEX V4 SwapRouter is `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F`.

Our existing Uniswap V3 hook is incompatible because Algebra Integral v1.2 has a different `ExactInputSingleParams` struct (no `fee`, adds `deployer`, uses `limitSqrtPrice`).

## Proposed Solution

Create two new hook contracts mirroring the UniV3 pattern:
- `SwapAlgebraIntegralHook` (1 execution - swap only)
- `ApproveAndSwapAlgebraIntegralHook` (4 executions - approve + swap + revoke)

## Technical Considerations

### Algebra Integral v1.2 ExactInputSingleParams

```solidity
struct ExactInputSingleParams {
    address tokenIn;
    address tokenOut;
    address deployer;        // Pool deployer address (identifies which pool)
    address recipient;
    uint256 deadline;
    uint256 amountIn;
    uint256 amountOutMinimum;
    uint160 limitSqrtPrice;
}
```

The `deployer` field is required because Algebra v1.2 supports custom pool deployers - different deployers can create different pools for the same token pair.

### Hook Data Layout (Compact - 209 bytes minimum)

```
Offset  Size  Field
0       20    tokenIn (address)
20      20    tokenOut (address)
40      20    deployer (address)         -- pool deployer for Algebra v1.2
60      20    recipient (address)        -- IGNORED, forced to account
80      32    deadline (uint256)
112     32    limitSqrtPrice (uint160 packed as uint256)
144     32    originalAmountIn (uint256)
176     32    originalMinAmountOut (uint256)
208     1     usePrevHookAmount (bool)
```

- `USE_PREV_HOOK_AMOUNT_POSITION = 208`
- Minimum data length: 209 bytes
- `limitSqrtPrice = 0` means no price limit

### SparkDEX V4 Addresses on Flare (chainId: 14)

- **SwapRouter**: `0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F`
- AlgebraPoolDeployer: `0x59a662Ed724F19AD019307126CbEBdcF4b57d6B1`
- AlgebraFactory: `0x805488DaA81c1b9e7C5cE3f1DCeA28F21448EC6A`

## Acceptance Criteria

- [ ] `IAlgebraSwapRouter` interface matching Algebra Integral v1.2
- [ ] `SwapAlgebraIntegralHook` - swap without approval handling
- [ ] `ApproveAndSwapAlgebraIntegralHook` - approve(0)->approve(amount)->swap->approve(0)
- [ ] `deployer` field properly decoded and passed to router
- [ ] Recipient forced to `account`
- [ ] Deadline validation
- [ ] Native token (address(0)) rejection
- [ ] `usePrevHookAmount` chaining support
- [ ] Balance-delta tracking via pre/post execute
- [ ] Unit tests with mock router
- [ ] Fork integration test against SparkDEX V4 on Flare
- [ ] Constants added to `test/utils/Constants.sol` and `script/utils/Constants.sol`

## Implementation

### 1. `src/hooks/swappers/algebra-integral/interfaces/IAlgebraSwapRouter.sol`

```solidity
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

interface IAlgebraSwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address deployer;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
```

### 2. `src/hooks/swappers/algebra-integral/SwapAlgebraIntegralHook.sol`

```solidity
// Mirror SwapUniswapV3Hook with:
// - IAlgebraSwapRouter instead of ISwapRouter
// - deployer field at offset 40
// - No fee field
// - limitSqrtPrice instead of sqrtPriceLimitX96
// - USE_PREV_HOOK_AMOUNT_POSITION = 208
// - data.length < 209 check
```

### 3. `src/hooks/swappers/algebra-integral/ApproveAndSwapAlgebraIntegralHook.sol`

```solidity
// Mirror ApproveAndSwapUniswapV3Hook with same changes as above
```

### 4. Unit Tests

```solidity
// test/unit/hooks/swappers/algebra-integral/AlgebraIntegralUnitTests.t.sol
// Mirror UniswapV3UnitTests.t.sol with:
// - MockAlgebraSwapRouter implementing IAlgebraSwapRouter
// - Updated data builder without fee, with deployer
// - All test categories from UniV3 tests
```

### 5. Fork Integration Test

```solidity
// test/integration/AlgebraIntegralHooksIntegrationTest.t.sol
// Fork test against Flare mainnet (chainId: 14)
// Test WFLR -> USDC swap via SparkDEX V4 router
```

### 6. Constants Updates

**`test/utils/Constants.sol`:**
```solidity
string public constant SWAP_ALGEBRA_INTEGRAL_HOOK_KEY = "SwapAlgebraIntegralHook";
string public constant APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY = "ApproveAndSwapAlgebraIntegralHook";
address public constant FLARE_ALGEBRA_INTEGRAL_SWAP_ROUTER = 0x69D57B9D705eaD73a5d2f2476C30c55bD755cc2F;
address public constant FLARE_ALGEBRA_POOL_DEPLOYER = 0x59a662Ed724F19AD019307126CbEBdcF4b57d6B1;
```

**`script/utils/Constants.sol`:**
```solidity
string internal constant SWAP_ALGEBRA_INTEGRAL_HOOK_KEY = "SwapAlgebraIntegralHook";
string internal constant APPROVE_AND_SWAP_ALGEBRA_INTEGRAL_HOOK_KEY = "ApproveAndSwapAlgebraIntegralHook";
```

## Attack Surface Analysis

### Token Risks
- [x] Fee-on-transfer: balance-delta accounting handles output; input may cause router revert (accepted)
- [x] Native token: blocked via address(0) check
- [x] USDT-like approval: handled by approve(0) pattern

### Reentrancy
- [x] CEI pattern: BaseHook transient storage mutexes
- [x] Cross-contract: atomic execution within smart account tx

### MEV/Sandwich
- [x] `amountOutMinimum` enforcement (router-level)
- [x] `limitSqrtPrice` optional price bound
- [x] `deadline` enforcement (hook + router level)

### Access Control
- [x] Immutable router address
- [x] Recipient forced to account
- [x] BaseHook UNAUTHORIZED_CALLER check

## References

- [Algebra Integral SwapRouter Docs](https://docs.algebra.finance/algebra-integral/integration-of-algebra-integral-protocol/specification-and-description-of-contracts/swaprouter)
- [SparkDEX V4 Contracts](https://docs.sparkdex.ai/additional-information/smart-contract-overview/v4-dex)
- [Algebra v1.2 ISwapRouter](https://github.com/cryptoalgebra/Algebra/blob/v1.2-integral/src/periphery/contracts/interfaces/ISwapRouter.sol)
- Existing hook: `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol`
