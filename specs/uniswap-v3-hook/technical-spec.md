# Uniswap V3 Hook Technical Specification

## Overview

This specification describes the implementation of `SwapUniswapV3Hook` and `ApproveAndSwapUniswapV3Hook` for the Superform v2-core protocol. These hooks enable token swaps via Uniswap V3's `SwapRouter.exactInputSingle` function, with primary deployment targeting Hyperliquid (Project X DEX).

## Problem Statement / Motivation

Superform v2-periphery will be deployed on Hyperliquid, which uses Project X as its primary DEX. Project X is a Uniswap V3 fork with modifications for HyperEVM's 50ms finality and a 20% protocol fee enabled by default. The existing `SwapUniswapV4Hook` cannot be used as Project X implements the V3 interface, not V4.

**Why this matters:**
- Enables token swaps on Hyperliquid within Superform operations
- Supports hook chaining for complex DeFi operations
- Maintains consistency with existing swap hook patterns (Odos, 1inch)

## Proposed Solution

Create two hook variants following existing patterns:
1. **SwapUniswapV3Hook**: For tokens already approved to the router
2. **ApproveAndSwapUniswapV3Hook**: Handles approval before swap and cleanup after

Both hooks will:
- Use `exactInputSingle` for single-hop swaps
- Support dynamic slippage recalculation via `HookDataUpdater`
- Use BytesLib packed data format for gas efficiency
- Include deadline parameter for MEV protection

## Technical Considerations

### Architecture
- **HookType**: `NONACCOUNTING` (same as Odos hooks)
- **HookSubType**: `SWAP` (from `HookSubTypes.sol`)
- **Router**: Immutable address in constructor
- **Native ETH**: NOT handled internally - users must chain with `DepositWETHHook`/`WithdrawWETHHook`

### Data Structure

BytesLib packed format (225 bytes total):

| Offset | Length | Type | Field | Description |
|--------|--------|------|-------|-------------|
| 0 | 20 | address | tokenIn | Input token (must be ERC-20, use WETH for ETH) |
| 20 | 20 | address | tokenOut | Output token (must be ERC-20, use WETH for ETH) |
| 40 | 4 | uint32 | fee | Pool fee tier (read as uint24 from first 3 bytes) |
| 44 | 20 | address | recipient | Swap output recipient (should equal account) |
| 64 | 32 | uint256 | deadline | Unix timestamp for MEV protection |
| 96 | 32 | uint256 | sqrtPriceLimitX96 | Price limit (0 = no limit) |
| 128 | 32 | uint256 | originalAmountIn | Original amount for slippage calc |
| 160 | 32 | uint256 | originalMinAmountOut | Original minimum output |
| 192 | 32 | uint256 | \_reserved | Reserved for future use |
| 224 | 1 | bool | usePrevHookAmount | Use previous hook's output as input |

**Note**: Fee is stored as uint32 (4 bytes) but only the first 3 bytes are used to decode the uint24 value. This maintains alignment with the address at offset 44.

### Slippage Recalculation

Using `HookDataUpdater.getUpdatedOutputAmount` pattern from Odos hooks:

```solidity
if (usePrevHookAmount) {
    uint256 _prevAmount = originalAmountIn;
    amountIn = ISuperHookResult(prevHook).getOutAmount(account);
    amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
        amountIn,
        _prevAmount,
        originalMinAmountOut
    );
}
```

Formula: `newMinOut = originalMinOut * (actualAmountIn / originalAmountIn)`

### Performance Implications
- SwapUniswapV3Hook: ~130k gas (preExecute + swap + postExecute)
- ApproveAndSwapUniswapV3Hook: ~180k gas (adds 3 approve calls)
- BytesLib packed format saves ~10k gas vs ABI encoding

### Security Considerations
- **Reentrancy**: Protected via BaseHook's transient storage mutexes
- **Approval cleanup**: ApproveAndSwap variant clears approvals after swap
- **Slippage protection**: amountOutMinimum enforced by router
- **MEV protection**: Deadline parameter prevents stale transaction execution
- **Fee-on-transfer tokens**: NOT supported (Uniswap V3 limitation)

## Acceptance Criteria

### Functional Requirements
- [ ] SwapUniswapV3Hook executes exactInputSingle on SwapRouter
- [ ] ApproveAndSwapUniswapV3Hook handles approve → swap → cleanup cycle
- [ ] Both hooks correctly decode BytesLib packed data structure
- [ ] usePrevHookAmount flag chains input from previous hook output
- [ ] Slippage recalculated proportionally when chaining
- [ ] outAmount set correctly in postExecute for next hook chaining
- [ ] Works with Project X (Hyperliquid) SwapRouter interface

### Non-Functional Requirements
- [ ] Gas usage within 10% of Odos hooks for equivalent operations
- [ ] Code follows existing hook patterns and style guidelines
- [ ] NatSpec documentation for all public/external functions

### Quality Gates
- [ ] Unit tests cover all data decoding paths
- [ ] Unit tests cover usePrevHookAmount = true/false scenarios
- [ ] Integration tests pass on forked Ethereum mainnet
- [ ] Integration tests pass on forked Hyperliquid (when available)

## Success Metrics
- Hook executes swaps correctly on Hyperliquid deployment
- Gas costs comparable to existing swap hooks
- No security vulnerabilities in audit

## Dependencies & Prerequisites

### Required Files (Already Exist)
- `src/hooks/BaseHook.sol` - Base implementation
- `src/vendor/BytesLib.sol` - Data decoding utilities
- `src/libraries/HookSubTypes.sol` - Subtype constants
- `src/libraries/HookDataUpdater.sol` - Slippage recalculation
- `lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol` - Router interface

### External Dependencies
- Uniswap V3 SwapRouter deployed on target chain
- WETH contract address known for native ETH swaps

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Project X interface differs from standard V3 | Low | High | Verify interface before deployment; abstract router calls |
| Fee-on-transfer token used | Medium | Medium | Document unsupported; revert if detected |
| Approval cleanup fails | Low | Low | Transaction reverts atomically; no lingering approval |
| Stale quote executed | Medium | Medium | Deadline parameter; document best practices |

## Implementation

### Phase 1: Core Hook Implementation

#### `src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";

/// @title SwapUniswapV3Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via Uniswap V3 SwapRouter.exactInputSingle
/// @dev Assumes tokens are already approved to the router
/// @dev data has the following structure:
/// @notice         address tokenIn = BytesLib.toAddress(data, 0);
/// @notice         address tokenOut = BytesLib.toAddress(data, 20);
/// @notice         uint24 fee = uint24(BytesLib.toUint32(data, 40));
/// @notice         address recipient = BytesLib.toAddress(data, 44);
/// @notice         uint256 deadline = BytesLib.toUint256(data, 64);
/// @notice         uint160 sqrtPriceLimitX96 = uint160(BytesLib.toUint256(data, 96));
/// @notice         uint256 originalAmountIn = BytesLib.toUint256(data, 128);
/// @notice         uint256 originalMinAmountOut = BytesLib.toUint256(data, 160);
/// @notice         uint256 _reserved = BytesLib.toUint256(data, 192);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 224);
contract SwapUniswapV3Hook is BaseHook, ISuperHookContextAware {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice The Uniswap V3 SwapRouter contract
    ISwapRouter public immutable SWAP_ROUTER;

    /// @notice Position of usePrevHookAmount flag in hook data
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 224;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when hook data is malformed or insufficient
    error INVALID_HOOK_DATA();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the Uniswap V3 swap hook
    /// @param swapRouter_ The address of the Uniswap V3 SwapRouter
    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = ISwapRouter(swapRouter_);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length < 225) revert INVALID_HOOK_DATA();

        // Decode parameters
        (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 deadline,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        ) = _decodeSwapParams(prevHook, account, data);

        // Build swap execution
        executions = new Execution[](1);
        executions[0] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: fee,
                        recipient: recipient,
                        deadline: deadline,
                        amountIn: amountIn,
                        amountOutMinimum: amountOutMinimum,
                        sqrtPriceLimitX96: sqrtPriceLimitX96
                    })
                )
            )
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        // Store initial balance of output token
        address tokenOut = data.toAddress(20);
        _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        // Calculate delta (final - initial balance)
        address tokenOut = data.toAddress(20);
        uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        _setOutAmount(finalBalance - initialBalance, account);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address tokenIn = data.toAddress(0);
        address tokenOut = data.toAddress(20);
        return abi.encodePacked(tokenIn, tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Decodes swap parameters from hook data
    /// @param prevHook The previous hook in the chain
    /// @param account The account executing the swap
    /// @param data The encoded hook data
    function _decodeSwapParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 deadline,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);
        fee = uint24(data.toUint32(40));
        recipient = data.toAddress(44);
        deadline = data.toUint256(64);
        sqrtPriceLimitX96 = uint160(data.toUint256(96));

        uint256 originalAmountIn = data.toUint256(128);
        uint256 originalMinAmountOut = data.toUint256(160);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
                amountIn,
                originalAmountIn,
                originalMinAmountOut
            );
        } else {
            amountIn = originalAmountIn;
            amountOutMinimum = originalMinAmountOut;
        }
    }
}
```

#### `src/hooks/swappers/uniswap-v3/ApproveAndSwapUniswapV3Hook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { ISuperHookResult, ISuperHookContextAware } from "../../../interfaces/ISuperHook.sol";
import { ISwapRouter } from "./interfaces/ISwapRouter.sol";

/// @title ApproveAndSwapUniswapV3Hook
/// @author Superform Labs
/// @notice Hook for executing swaps via Uniswap V3 with approval handling
/// @dev Handles: approve(0) -> approve(amount) -> swap -> approve(0)
/// @dev data structure same as SwapUniswapV3Hook
contract ApproveAndSwapUniswapV3Hook is BaseHook, ISuperHookContextAware {
    using BytesLib for bytes;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/

    ISwapRouter public immutable SWAP_ROUTER;
    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 224;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error INVALID_HOOK_DATA();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address swapRouter_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.SWAP) {
        if (swapRouter_ == address(0)) revert ADDRESS_NOT_VALID();
        SWAP_ROUTER = ISwapRouter(swapRouter_);
    }

    /*//////////////////////////////////////////////////////////////
                            HOOK IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        override
        returns (Execution[] memory executions)
    {
        if (data.length < 225) revert INVALID_HOOK_DATA();

        (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 deadline,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        ) = _decodeSwapParams(prevHook, account, data);

        // Build: approve(0) -> approve(amount) -> swap -> approve(0)
        executions = new Execution[](4);

        // Reset approval to 0 (handles USDT-like tokens)
        executions[0] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });

        // Set approval to exact amount
        executions[1] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), amountIn))
        });

        // Execute swap
        executions[2] = Execution({
            target: address(SWAP_ROUTER),
            value: 0,
            callData: abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: fee,
                        recipient: recipient,
                        deadline: deadline,
                        amountIn: amountIn,
                        amountOutMinimum: amountOutMinimum,
                        sqrtPriceLimitX96: sqrtPriceLimitX96
                    })
                )
            )
        });

        // Clear approval after swap
        executions[3] = Execution({
            target: tokenIn,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(SWAP_ROUTER), 0))
        });
    }

    /// @inheritdoc BaseHook
    function _preExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(20);
        _setOutAmount(IERC20(tokenOut).balanceOf(account), account);
    }

    /// @inheritdoc BaseHook
    function _postExecute(address, address account, bytes calldata data) internal override {
        address tokenOut = data.toAddress(20);
        uint256 finalBalance = IERC20(tokenOut).balanceOf(account);
        uint256 initialBalance = getOutAmount(account);
        _setOutAmount(finalBalance - initialBalance, account);
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc BaseHook
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address tokenIn = data.toAddress(0);
        address tokenOut = data.toAddress(20);
        return abi.encodePacked(tokenIn, tokenOut);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _decodeSwapParams(
        address prevHook,
        address account,
        bytes calldata data
    )
        internal
        view
        returns (
            address tokenIn,
            address tokenOut,
            uint24 fee,
            address recipient,
            uint256 deadline,
            uint160 sqrtPriceLimitX96,
            uint256 amountIn,
            uint256 amountOutMinimum
        )
    {
        tokenIn = data.toAddress(0);
        tokenOut = data.toAddress(20);
        fee = uint24(data.toUint32(40));
        recipient = data.toAddress(44);
        deadline = data.toUint256(64);
        sqrtPriceLimitX96 = uint160(data.toUint256(96));

        uint256 originalAmountIn = data.toUint256(128);
        uint256 originalMinAmountOut = data.toUint256(160);
        bool usePrevHookAmount = _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);

        if (usePrevHookAmount) {
            amountIn = ISuperHookResult(prevHook).getOutAmount(account);
            amountOutMinimum = HookDataUpdater.getUpdatedOutputAmount(
                amountIn,
                originalAmountIn,
                originalMinAmountOut
            );
        } else {
            amountIn = originalAmountIn;
            amountOutMinimum = originalMinAmountOut;
        }
    }
}
```

#### `src/hooks/swappers/uniswap-v3/interfaces/ISwapRouter.sol`

Copy from `lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol` or import directly.

### Phase 2: Test Implementation

#### `test/unit/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.t.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { SwapUniswapV3Hook } from "src/hooks/swappers/uniswap-v3/SwapUniswapV3Hook.sol";
import { MockSwapRouter } from "./mocks/MockSwapRouter.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

contract SwapUniswapV3HookTest is Test {
    SwapUniswapV3Hook public hook;
    MockSwapRouter public router;
    MockERC20 public tokenIn;
    MockERC20 public tokenOut;

    address public account = address(0x1234);

    function setUp() public {
        router = new MockSwapRouter();
        hook = new SwapUniswapV3Hook(address(router));
        tokenIn = new MockERC20("TokenIn", "TIN", 18);
        tokenOut = new MockERC20("TokenOut", "TOUT", 18);
    }

    function test_constructor_setsRouter() public view {
        assertEq(address(hook.SWAP_ROUTER()), address(router));
    }

    function test_constructor_revertsOnZeroAddress() public {
        vm.expectRevert();
        new SwapUniswapV3Hook(address(0));
    }

    function test_decodeUsePrevHookAmount_true() public view {
        bytes memory data = _buildHookData(true);
        assertTrue(hook.decodeUsePrevHookAmount(data));
    }

    function test_decodeUsePrevHookAmount_false() public view {
        bytes memory data = _buildHookData(false);
        assertFalse(hook.decodeUsePrevHookAmount(data));
    }

    function test_inspect_returnsTokenAddresses() public view {
        bytes memory data = _buildHookData(false);
        bytes memory inspected = hook.inspect(data);

        address decodedTokenIn;
        address decodedTokenOut;
        assembly {
            decodedTokenIn := mload(add(inspected, 20))
            decodedTokenOut := mload(add(inspected, 40))
        }

        assertEq(decodedTokenIn, address(tokenIn));
        assertEq(decodedTokenOut, address(tokenOut));
    }

    // Helper to build hook data
    function _buildHookData(bool usePrevHookAmount) internal view returns (bytes memory) {
        return bytes.concat(
            bytes20(address(tokenIn)),      // tokenIn: 0-19
            bytes20(address(tokenOut)),     // tokenOut: 20-39
            bytes4(uint32(3000)),           // fee: 40-43
            bytes20(account),               // recipient: 44-63
            bytes32(uint256(block.timestamp + 3600)), // deadline: 64-95
            bytes32(uint256(0)),            // sqrtPriceLimitX96: 96-127
            bytes32(uint256(1e18)),         // originalAmountIn: 128-159
            bytes32(uint256(0.95e18)),      // originalMinAmountOut: 160-191
            bytes32(uint256(0)),            // reserved: 192-223
            usePrevHookAmount ? bytes1(0x01) : bytes1(0x00) // usePrevHookAmount: 224
        );
    }
}
```

### Phase 3: Integration Tests

Create integration tests that fork mainnet to test against real Uniswap V3 pools:
- Test DAI -> USDC swap
- Test WETH -> DAI swap
- Test chained swaps with usePrevHookAmount

## Future Considerations

- **Multi-hop support**: Consider adding `exactInput` for multi-hop paths in a future version
- **Quoter integration**: Add quote verification before execution
- **Cross-chain**: Verify and test on all Superform-supported chains

## Documentation Plan

- Add NatSpec comments to all public functions
- Update hook documentation with usage examples
- Add data encoding helper to SDK

## References & Research

### Internal References
- SwapOdosV2Hook pattern: `src/hooks/swappers/odos/SwapOdosV2Hook.sol:31`
- ApproveAndSwapOdosV2Hook pattern: `src/hooks/swappers/odos/ApproveAndSwapOdosV2Hook.sol`
- SwapUniswapV4Hook (complex example): `src/hooks/swappers/uniswap-v4/SwapUniswapV4Hook.sol`
- BaseHook: `src/hooks/BaseHook.sol:18`
- HookDataUpdater: `src/libraries/HookDataUpdater.sol`
- ISwapRouter interface: `lib/modulekit/src/integrations/interfaces/uniswap/v3/ISwapRouter.sol`

### External References
- Project X (Hyperliquid DEX): https://github.com/hl-x-org/v3-core
- Uniswap V3 SwapRouter docs: https://docs.uniswap.org/contracts/v3/reference/periphery/SwapRouter
- Uniswap V3 fee tiers: 100 (0.01%), 500 (0.05%), 3000 (0.3%), 10000 (1%)

### Related Work
- SpecFlow Analysis: `/specs/uniswap-v3-hook/research/specflow-analysis.md`
- Best Practices: `/specs/uniswap-v3-hook/research/best-practices.md`
- Repo Analysis: `/specs/uniswap-v3-hook/research/repo-analysis.md`
