# Uniswap V3 SwapRouter02 Hook - Technical Specification

## Overview

Create `SwapUniswapV3Router02Hook` and `ApproveAndSwapUniswapV3Router02Hook` targeting Uniswap V3 SwapRouter02's `IV3SwapRouter.exactInputSingle` interface. SwapRouter02 removes `deadline` from the swap params struct (handled via multicall wrapper instead), making the existing v1 hooks incompatible. This enables swap support on Stable chain (988) and all chains with canonical Uniswap V3 SwapRouter02 deployments.

## Problem Statement

The existing `SwapUniswapV3Hook` uses `ISwapRouter.exactInputSingle` (selector `0x414bf389`) with 8 fields including `deadline`. SwapRouter02 uses `IV3SwapRouter.exactInputSingle` (selector `0x04e45aaf`) with 7 fields — no `deadline`. The ABI mismatch causes calls to revert. Stable chain (988) only has SwapRouter02 deployed.

## Implementation

### 1. New Interface: `src/hooks/swappers/uniswap-v3/interfaces/IV3SwapRouter.sol`

```solidity
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.30;

/// @title IV3SwapRouter
/// @notice Interface for Uniswap V3 SwapRouter02's exactInputSingle
/// @dev SwapRouter02 removes deadline from struct (handled via multicall wrapper)
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}
```

### 2. `src/hooks/swappers/uniswap-v3/SwapUniswapV3Router02Hook.sol`

Based on existing `SwapUniswapV3Hook.sol` with these changes:
- Import `IV3SwapRouter` instead of `ISwapRouter`
- Remove `deadline` from data layout (141 bytes instead of 193)
- Remove `EXPIRED_DEADLINE` error
- Remove deadline validation
- Add `if (tokenIn == tokenOut) revert INVALID_HOOK_DATA()` (from Algebra hook)
- Add `if (amountIn == 0) revert AMOUNT_NOT_VALID()` (from security research)
- Add overflow check in `_postExecute`: `if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID()`

#### Data Layout (141 bytes)

```
Offset | Size | Field
0      | 20   | address tokenIn
20     | 20   | address tokenOut
40     | 4    | uint24 fee (packed as uint32)
44     | 32   | uint160 sqrtPriceLimitX96 (stored as uint256)
76     | 32   | uint256 originalAmountIn
108    | 32   | uint256 originalMinAmountOut
140    | 1    | bool usePrevHookAmount
```

```solidity
contract SwapUniswapV3Router02Hook is BaseHook, ISuperHookContextAware {
    IV3SwapRouter public immutable SWAP_ROUTER;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 140;

    error INVALID_HOOK_DATA();
    error NATIVE_ETH_NOT_SUPPORTED();

    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = IV3SwapRouter(swapRouter_);
    }

    function _buildHookExecutions(address prevHook, address account, bytes calldata data)
        internal view override returns (Execution[] memory executions)
    {
        if (data.length < 141) revert INVALID_HOOK_DATA();

        (address tokenIn, address tokenOut, uint24 fee, uint160 sqrtPriceLimitX96,
         uint256 amountIn, uint256 amountOutMinimum) = _decodeSwapParams(prevHook, account, data);

        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: abi.encodeCall(IV3SwapRouter.exactInputSingle, (
                IV3SwapRouter.ExactInputSingleParams({
                    tokenIn: tokenIn, tokenOut: tokenOut, fee: fee,
                    recipient: account, amountIn: amountIn,
                    amountOutMinimum: amountOutMinimum, sqrtPriceLimitX96: sqrtPriceLimitX96
                })
            ))
        });
    }

    function _decodeSwapParams(address prevHook, address account, bytes calldata data)
        internal view returns (address tokenIn, address tokenOut, uint24 fee,
        uint160 sqrtPriceLimitX96, uint256 amountIn, uint256 amountOutMinimum)
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);
        if (tokenIn == address(0) || tokenOut == address(0)) revert NATIVE_ETH_NOT_SUPPORTED();
        if (tokenIn == tokenOut) revert INVALID_HOOK_DATA();

        fee = uint24(data.toUint32(40));
        sqrtPriceLimitX96 = uint160(data.toUint256(44));

        uint256 originalAmountIn = data.toUint256(76);
        uint256 originalMinAmountOut = data.toUint256(108);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(amountIn, originalAmountIn, originalMinAmountOut);
        } else {
            amountIn = originalAmountIn;
            amountOutMinimum = originalMinAmountOut;
        }
        if (amountIn == 0) revert AMOUNT_NOT_VALID();
    }

    // _preExecute, _postExecute, decodeUsePrevHookAmount, inspect — same pattern as v1
    // _postExecute adds: if (finalBalance < initialBalance) revert AMOUNT_NOT_VALID();
}
```

### 3. `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Router02Hook.sol`

Same as `SwapUniswapV3Router02Hook` except `_buildHookExecutions` returns 4 executions:
1. `approve(router, 0)` — reset for USDT-like tokens
2. `approve(router, amountIn)` — set exact amount
3. `exactInputSingle(params)` — the swap
4. `approve(router, 0)` — cleanup

### 4. Configuration Changes

#### `script/utils/ConfigBase.sol`
Add after `uniswapV3SwapRouters` mapping:
```solidity
mapping(uint64 chainId => address swapRouter02) uniswapV3SwapRouter02s;
```

#### `script/utils/ConfigCore.sol`
Add new section after line 334:
```solidity
// ===== UNISWAP V3 SWAP ROUTER 02 ADDRESSES =====
configuration.uniswapV3SwapRouter02s[MAINNET_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
configuration.uniswapV3SwapRouter02s[BASE_CHAIN_ID] = 0x2626664c2603336E57B271c5C0b26F421741e481;
configuration.uniswapV3SwapRouter02s[ARBITRUM_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
configuration.uniswapV3SwapRouter02s[OPTIMISM_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
configuration.uniswapV3SwapRouter02s[POLYGON_CHAIN_ID] = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
configuration.uniswapV3SwapRouter02s[BNB_CHAIN_ID] = 0xB971eF87ede563556b2ED4b1C0b0019111Dd85d2;
configuration.uniswapV3SwapRouter02s[AVALANCHE_CHAIN_ID] = 0xbb00FF08d01D300023C629E8fFfFcb65A5a578cE;
configuration.uniswapV3SwapRouter02s[UNICHAIN_CHAIN_ID] = 0x73855d06De49d0fe4a9c42636ba96c62dA12ff9c;
configuration.uniswapV3SwapRouter02s[LINEA_CHAIN_ID] = 0x3d4e44Eb1374240CE5F1B871ab261CD16335B76a;
configuration.uniswapV3SwapRouter02s[BERACHAIN_CHAIN_ID] = address(0); // Not deployed
configuration.uniswapV3SwapRouter02s[SONIC_CHAIN_ID] = address(0); // Not confirmed
configuration.uniswapV3SwapRouter02s[GNOSIS_CHAIN_ID] = address(0); // Not confirmed
configuration.uniswapV3SwapRouter02s[WORLDCHAIN_CHAIN_ID] = 0x091AD9e2e6e5eD44c1c66dB50e49A601F9f36cF6;
configuration.uniswapV3SwapRouter02s[HYPEREVM_CHAIN_ID] = address(0); // Uses HyperSwap v1 router
configuration.uniswapV3SwapRouter02s[FLARE_CHAIN_ID] = address(0); // Not deployed
configuration.uniswapV3SwapRouter02s[STABLE_CHAIN_ID] = 0x32eaf9B5d5F2CD7361c5012890C943D7de84C22a;
```

#### `script/utils/Constants.sol`
Add hook key constants:
```solidity
string internal constant SWAP_UNISWAPV3_ROUTER02_HOOK_KEY = "SwapUniswapV3Router02Hook";
string internal constant APPROVE_AND_SWAP_UNISWAPV3_ROUTER02_HOOK_KEY = "ApproveAndSwapUniswapV3Router02Hook";
```

### 5. Deployment Script Changes

#### `script/DeployV2Core.s.sol`
- Add `bool swapUniswapV3Router02Hooks` to `ContractAvailability` struct
- Add availability check: `if (configuration.uniswapV3SwapRouter02s[chainId] != address(0))`
- Add bytecode checks for both new hook keys
- Add hook deployment entries with Router02 addresses

### 6. Bytecode Regeneration

Add to `script/run/regenerate_bytecode.sh` `HOOK_CONTRACTS` array:
```bash
"SwapUniswapV3Router02Hook"
"ApproveAndSwapUniswapV3Router02Hook"
```

### 7. Unit Tests

**File:** `test/unit/hooks/swappers/uniswap-v3/UniswapV3Router02UnitTests.t.sol`

Mirror existing `UniswapV3UnitTests.t.sol` structure with:
- `MockV3SwapRouter` implementing `IV3SwapRouter.exactInputSingle`
- `_buildHookData()` helper with new layout (no deadline, 141 bytes)
- Tests: constructor, decodeUsePrevHookAmount, build execution count, preExecute/postExecute balance tracking, inspect, data length validation, same-token revert, zero-amount revert, native ETH revert, slippage recalculation, fuzz tests

### 8. Integration/Fork Tests

**File:** `test/integration/uniswap-v3/UniswapV3Router02HookIntegrationTest.t.sol`

Fork tests against Ethereum mainnet SwapRouter02 (`0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45`):
- USDC -> WETH swap
- WETH -> USDC swap
- usePrevHookAmount chaining
- Slippage revert
- Large/small amount edge cases

Add test constant:
```solidity
address public constant MAINNET_V3_SWAP_ROUTER_02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
```

## Security Considerations

- **Deadline removal:** Acceptable per SECURITY.md item 10. Bundler handles time constraints.
- **amountIn == 0 check:** Added to prevent zero-amount swaps from usePrevHookAmount edge case.
- **tokenIn == tokenOut check:** Added to prevent self-swap nonsense.
- **Recipient forced to account:** Critical for balance tracking — maintained from v1.
- **Overflow check in _postExecute:** Prevents underflow if finalBalance < initialBalance.
- **Fee-on-transfer / rebasing tokens:** Unsupported by Uniswap V3. Documented in NatSpec.

## Verification

```bash
forge build
forge test --match-path "test/unit/hooks/swappers/uniswap-v3/UniswapV3Router02UnitTests.t.sol" -vv
forge test --match-path "test/integration/uniswap-v3/UniswapV3Router02HookIntegrationTest.t.sol" -vv --fork-url $ETHEREUM_RPC_URL
bash script/run/regenerate_bytecode.sh SwapUniswapV3Router02Hook
bash script/run/regenerate_bytecode.sh ApproveAndSwapUniswapV3Router02Hook
```

## References

- [IV3SwapRouter.sol](https://github.com/Uniswap/swap-router-contracts/blob/main/contracts/interfaces/IV3SwapRouter.sol)
- [Official Uniswap V3 Deployments](https://github.com/Uniswap/docs/tree/main/docs/contracts/v3/reference/deployments)
- Existing v1 hooks: `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol`
- Security analysis: `specs/uniswap-v3-router02-hook/research/evm-security.md`
