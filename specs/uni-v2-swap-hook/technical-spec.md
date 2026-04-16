# Uni V2 Swap Hook Technical Specification

## Overview

Implement a generic Uniswap V2-compatible swap hook for the Superform v2-core protocol. The hook enables token swaps via any UniswapV2Router02-compatible DEX (SparkDex on Flare being the initial target). It supports single-hop and multi-hop paths, native token swaps, and hook chaining via `usePrevHookAmount`.

## Problem Statement / Motivation

Superform v2 needs swap capabilities on chains where Uni V2 forks are the primary DEX infrastructure (e.g., SparkDex on Flare). A generic Uni V2 hook enables reuse across all Uni V2-compatible routers without per-DEX customization.

## Proposed Solution

Create two hook contracts following the established dual-hook pattern:
1. **`SwapUniV2Hook`** - Executes swaps assuming tokens are pre-approved to the router
2. **`ApproveAndSwapUniV2Hook`** - Handles approval lifecycle before swap

Both share the same data layout and inherit from `BaseHook` with `HookType.NONACCOUNTING` and `HookSubTypes.SWAP`.

## Technical Design

### Constructor

```solidity
constructor(address router_, address native_, address weth_)
    BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP)
{
    if (router_ == address(0)) revert ADDRESS_NOT_VALID();
    SWAP_ROUTER = IUniswapV2Router(router_);
    NATIVE = native_;
    WETH = weth_;
}
```

Three immutables:
- `SWAP_ROUTER` - The Uni V2 router address
- `NATIVE` - Sentinel address for native token detection (e.g., `0xEeee...EEEE`)
- `WETH` - The wrapped native token address (e.g., WFLR on Flare)

### Hook Data Layout (shared by both variants)

```
address tokenIn        = BytesLib.toAddress(data, 0);        // 20 bytes - NATIVE sentinel for native input
address tokenOut       = BytesLib.toAddress(data, 20);       // 20 bytes - NATIVE sentinel for native output
uint256 deadline       = BytesLib.toUint256(data, 40);       // 32 bytes
uint256 amountIn       = BytesLib.toUint256(data, 72);       // 32 bytes
uint256 amountOutMin   = BytesLib.toUint256(data, 104);      // 32 bytes
bool usePrevHookAmount = _decodeBool(data, 136);             // 1 byte
uint256 pathLength     = BytesLib.toUint256(data, 137);      // 32 bytes (number of addresses)
address[] path         = decoded from (169, pathLength * 20) // variable length
```

**Key design decisions:**
- **Both variants share the same layout** (follows Uni V3 pattern where both SwapUniswapV3Hook and ApproveAndSwapUniswapV3Hook use identical data encoding)
- **tokenIn/tokenOut use NATIVE sentinel** for native token detection
- **path always contains real addresses** (WETH, not NATIVE) - no path mutation needed
- **pathLength = number of addresses** (multiply by 20 for byte length)
- `USE_PREV_HOOK_AMOUNT_POSITION = 136`

**Minimum data length**: 169 + pathLength * 20 bytes. With minimum 2-address path: 209 bytes.

### Router Function Selection

```
if tokenIn == NATIVE:
    → swapExactETHForTokens(amountOutMin, path, account, deadline)  // value = amountIn
elif tokenOut == NATIVE:
    → swapExactTokensForETH(amountIn, amountOutMin, path, account, deadline)
else:
    → swapExactTokensForTokens(amountIn, amountOutMin, path, account, deadline)
```

### Interface

```solidity
// src/hooks/swappers/uniswap-v2/interfaces/IUniswapV2Router.sol

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}
```

### SwapUniV2Hook Implementation

```solidity
contract SwapUniV2Hook is BaseHook, ISuperHookContextAware {
    IUniswapV2Router public immutable SWAP_ROUTER;
    address public immutable NATIVE;
    address public immutable WETH;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 136;

    error INVALID_HOOK_DATA();
    error INVALID_PATH_LENGTH();
    error EXPIRED_DEADLINE(uint256 deadline, uint256 currentTimestamp);

    constructor(address router_, address native_, address weth_)
        BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) { ... }

    function _buildHookExecutions(address prevHook, address account, bytes calldata data)
        internal view override returns (Execution[] memory executions)
    {
        // 1. Validate minimum data length
        if (data.length < 209) revert INVALID_HOOK_DATA();

        // 2. Decode fixed fields
        (address tokenIn, address tokenOut, uint256 deadline,
         uint256 amountIn, uint256 amountOutMin, address[] memory path)
            = _decodeSwapParams(prevHook, account, data);

        // 3. Build execution based on native detection
        executions = new Execution[](1);

        if (tokenIn == NATIVE) {
            // Native input: swapExactETHForTokens with value
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: amountIn,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactETHForTokens,
                    (amountOutMin, path, account, deadline)
                )
            });
        } else if (tokenOut == NATIVE) {
            // Native output: swapExactTokensForETH
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: 0,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForETH,
                    (amountIn, amountOutMin, path, account, deadline)
                )
            });
        } else {
            // ERC-20 to ERC-20: swapExactTokensForTokens
            executions[0] = Execution({
                target: address(SWAP_ROUTER),
                value: 0,
                callData: abi.encodeCall(
                    IUniswapV2Router.swapExactTokensForTokens,
                    (amountIn, amountOutMin, path, account, deadline)
                )
            });
        }
    }

    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address tokenOut = data.toAddress(20);
        return abi.encodePacked(tokenOut);
    }

    // --- Internal Helpers ---

    function _decodeSwapParams(address prevHook, address account, bytes calldata data)
        internal view returns (
            address tokenIn, address tokenOut, uint256 deadline,
            uint256 amountIn, uint256 amountOutMin, address[] memory path
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);
        deadline = data.toUint256(40);

        // Deadline validation (fail fast)
        if (deadline < block.timestamp) revert EXPIRED_DEADLINE(deadline, block.timestamp);

        uint256 originalAmountIn = data.toUint256(72);
        uint256 originalAmountOutMin = data.toUint256(104);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        // Decode path
        uint256 pathLength = data.toUint256(137);
        if (pathLength < 2) revert INVALID_PATH_LENGTH();
        if (data.length < 169 + pathLength * 20) revert INVALID_HOOK_DATA();

        path = new address[](pathLength);
        for (uint256 i = 0; i < pathLength; i++) {
            path[i] = data.toAddress(169 + i * 20);
        }

        // usePrevHookAmount chaining
        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMin = HookDataUpdater.getUpdatedOutputAmount(
                amountIn, originalAmountIn, originalAmountOutMin
            );
        } else {
            amountIn = originalAmountIn;
            amountOutMin = originalAmountOutMin;
        }
    }

    function _getBalance(address account, bytes memory data) private view returns (uint256) {
        address tokenOut = BytesLib.toAddress(data, 20);
        if (tokenOut == NATIVE) {
            return account.balance;
        }
        return IERC20(tokenOut).balanceOf(account);
    }
}
```

### ApproveAndSwapUniV2Hook Implementation

Identical to `SwapUniV2Hook` except `_buildHookExecutions` adds approval steps conditionally:

```solidity
function _buildHookExecutions(address prevHook, address account, bytes calldata data)
    internal view override returns (Execution[] memory executions)
{
    // Decode params (same as SwapUniV2Hook)
    (address tokenIn, address tokenOut, uint256 deadline,
     uint256 amountIn, uint256 amountOutMin, address[] memory path)
        = _decodeSwapParams(prevHook, account, data);

    // Build swap calldata
    bytes memory swapCallData;
    uint256 swapValue;

    if (tokenIn == NATIVE) {
        // Native input: skip approvals, set value
        swapValue = amountIn;
        swapCallData = abi.encodeCall(
            IUniswapV2Router.swapExactETHForTokens,
            (amountOutMin, path, account, deadline)
        );

        // Only 1 execution (no approvals for native)
        executions = new Execution[](1);
        executions[0] = Execution({ target: address(SWAP_ROUTER), value: swapValue, callData: swapCallData });
    } else {
        if (tokenOut == NATIVE) {
            swapCallData = abi.encodeCall(
                IUniswapV2Router.swapExactTokensForETH,
                (amountIn, amountOutMin, path, account, deadline)
            );
        } else {
            swapCallData = abi.encodeCall(
                IUniswapV2Router.swapExactTokensForTokens,
                (amountIn, amountOutMin, path, account, deadline)
            );
        }

        // 4 executions: approve(0) -> approve(amount) -> swap -> approve(0)
        executions = new Execution[](4);

        executions[0] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });
        executions[1] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), amountIn))
        });
        executions[2] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: swapCallData
        });
        executions[3] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });
    }
}
```

### File Structure

```
src/hooks/swappers/uniswap-v2/
├── SwapUniV2Hook.sol
├── ApproveAndSwapUniV2Hook.sol
└── interfaces/
    └── IUniswapV2Router.sol
```

## Acceptance Criteria

### Functional Requirements
- [ ] ERC-20 to ERC-20 single-hop swap works correctly
- [ ] ERC-20 to ERC-20 multi-hop swap works correctly
- [ ] Native to ERC-20 swap via `swapExactETHForTokens` works
- [ ] ERC-20 to Native swap via `swapExactTokensForETH` works
- [ ] `usePrevHookAmount` chaining works with proportional `amountOutMin` scaling
- [ ] ApproveAndSwap variant handles USDT-compatible approval pattern
- [ ] ApproveAndSwap with native input skips approval steps
- [ ] `inspect()` returns correct tokenOut address
- [ ] `decodeUsePrevHookAmount()` correctly reads the flag
- [ ] Recipient is always forced to the smart account address
- [ ] Deadline validation fails fast before building executions

### Non-Functional Requirements
- [ ] Compatible with any UniswapV2Router02-compatible router
- [ ] Gas efficient (tightly-packed data, no on-chain quoting)
- [ ] Follows all existing hook patterns (BaseHook, BytesLib, HookDataUpdater)

### Security Requirements
- [ ] Path length validated (>= 2)
- [ ] Data length validated against pathLength
- [ ] No approval steps generated for native token input
- [ ] Balance tracking uses `account.balance` for native output
- [ ] Approval cleared to 0 after swap
- [ ] Deadline validated at hook level

## Attack Surface Analysis

### Reentrancy
- [x] BaseHook transient storage mutexes prevent re-entry into lifecycle methods
- [x] Uni V2 pair `lock` modifier prevents swap re-entry
- [ ] Native ETH callback from `swapExactTokensForETH` - mitigated by mutex

### Token Risks
- [x] USDT approval handled via approve(0)->approve(amount) pattern
- [ ] Fee-on-transfer tokens NOT supported (documented limitation)
- [ ] Rebasing tokens NOT supported as output tokens (documented limitation)

### MEV / Slippage
- [x] `amountOutMin` enforced by router
- [x] Proportional scaling via `HookDataUpdater` preserves slippage ratio
- [ ] Sandwich attacks bounded by slippage tolerance (off-chain responsibility)

### Native Token
- [x] NATIVE sentinel used only for detection; path contains real WETH
- [x] Approval steps skipped for native input
- [ ] Smart account must implement `receive()` for native output (Nexus/Safe both do)

## Exploit Precedent Check

| Protocol | Exploit | Loss | Relevance | Our Mitigation |
|----------|---------|------|-----------|----------------|
| SparkDEX Perps | Reentrancy via fallback | $1.5M (prevented) | Same chain (Flare) | BaseHook mutex |
| STA/Balancer | Fee-on-transfer drain | ~$500K | Multi-hop paths | Not supporting FoT tokens |
| ERC-777/Uniswap | Callback reentrancy | ~$25M | DEX integration | V2 pair lock + BaseHook mutex |

## Known Limitations

1. **No fee-on-transfer token support** - standard `swapExactTokensForTokens` used; FoT variants can be added later
2. **No rebasing token support** as output tokens - balance delta tracking assumes static balances
3. **Native balance interference** - if other hooks in same batch send/receive native ETH, balance delta may be incorrect
4. **Approval target is always router** - some V2 forks may use different spender (not known to apply to any current target)
5. **No path consistency validation** - `tokenOut` field and `path[last]` are not validated to match (trusts bundler)

## Dependencies & Risks

- **SparkDex router verification needed**: Confirm `router.WETH()` returns WFLR address on Flare before deployment
- **Smart account `receive()` assumption**: Nexus and Safe both support it, but must be validated for any new account types

## Implementation Plan

### Phase 1: Core Contracts
- [ ] Create `IUniswapV2Router.sol` interface
- [ ] Implement `SwapUniV2Hook.sol`
- [ ] Implement `ApproveAndSwapUniV2Hook.sol`

### Phase 2: Testing
- [ ] Unit tests for both hook variants
- [ ] Test single-hop and multi-hop paths
- [ ] Test native input and output swaps
- [ ] Test `usePrevHookAmount` chaining
- [ ] Test deadline validation
- [ ] Test approval patterns (USDT-like tokens)
- [ ] Test native input with ApproveAndSwap (approval skip)
- [ ] Fuzz tests for path length, amounts, deadline boundaries

### Phase 3: Deployment
- [ ] Add hook key constants to `script/utils/Constants.sol`
- [ ] Add router/NATIVE/WETH addresses per chain to config
- [ ] Deploy on Flare (SparkDex) as initial target
- [ ] Verify on-chain behavior

## References & Research

### Internal References
- Uni V3 hooks: `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol`
- KyberSwap NATIVE pattern: `src/hooks/swappers/kyberswap/SwapKyberSwapHook.sol:117-123`
- HookDataUpdater: `src/libraries/HookDataUpdater.sol`
- BaseHook: `src/hooks/BaseHook.sol`
- Existing IUniswapV2Router02 reference: `lib/nexus/test/foundry/shared/interfaces/IUniswapV2Router02.t.sol`

### External References
- [UniswapV2Router02 Source](https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol)
- [SparkDEX V2/V3.1 Contracts](https://docs.sparkdex.ai/additional-information/smart-contract-overview/v2-v3.1-dex)
- SparkDex V2 Router on Flare: `0x4a1E5A90e9943467FAd1acea1E7F0e5e88472a1e`
- WFLR on Flare: `0x1D80c49BbBCd1C0911346656B529DF9E5c2F783d`
