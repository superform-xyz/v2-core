# PendleUnifiedHook Technical Specification

## Overview

Merge `PendleRouterRedeemHook` and `PendleRouterSwapHook` into a unified `PendleUnifiedHook` that fixes the tokenOut validation issue for swap routing, enabling atomic redemption + swap operations with single slippage management.

## Problem Statement

The current `PendleRouterRedeemHook` validates `tokenOut` against `SY.isValidTokenOut()`, but this only allows direct SY redemption tokens. Pendle's `redeemPyToToken` supports a 3-step atomic flow via the `TokenOutput` struct:
1. Redeem PT+YT → SY
2. Redeem SY → `tokenRedeemSy` (must be valid SY output)
3. If `swapData` is provided, swap `tokenRedeemSy` → `tokenOut` (can be ANY token)

**The fix:** Validate `tokenRedeemSy` (not `tokenOut`) when `swapData.swapType != SwapType.NONE`.

## Technical Approach

### Supported Selectors

```solidity
// 1. Redeem PT+YT to token (with optional swap routing)
function redeemPyToToken(address receiver, address YT, uint256 netPyIn, TokenOutput calldata output)

// 2. Swap token to PT
function swapExactTokenForPt(address receiver, address market, uint256 minPtOut, ApproxParams calldata guessPtOut, TokenInput calldata input, LimitOrderData calldata limit)

// 3. Swap PT to token
function swapExactPtForToken(address receiver, address market, uint256 exactPtIn, TokenOutput calldata output, LimitOrderData calldata limit)
```

### Data Layout

Keep similar to current `PendleRouterSwapHook` for smooth off-chain transition:

```
Offset 0-31:   bytes32 placeholder (yieldSourceOracleId)
Offset 32-51: address yieldSource (market for swaps, YT for redeem)
Offset 52:    bool usePrevHookAmount
Offset 53-84: uint256 value (msg.value for payable calls)
Offset 85+:   bytes txData (raw Pendle router calldata with 4-byte selector)
```

### Core Validation Logic

```solidity
function _validateTxData(bytes calldata data, address account, ...) private view returns (bytes memory) {
    bytes4 selector = bytes4(data[0:4]);

    if (selector == IPendleRouterV4.redeemPyToToken.selector) {
        return _validateRedeemPyToToken(data, account, ...);
    } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
        return _validateSwapExactTokenForPt(data, account, ...);
    } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
        return _validateSwapExactPtForToken(data, account, ...);
    } else {
        revert INVALID_SELECTOR();
    }
}
```

### tokenRedeemSy Validation Fix (Core Bug Fix)

```solidity
function _validateRedeemPyToToken(...) private view returns (bytes memory) {
    (address receiver, address yt, uint256 netPyIn, TokenOutput memory output) =
        abi.decode(data[4:], (address, address, uint256, TokenOutput));

    if (receiver != account) revert RECEIVER_NOT_VALID();
    if (output.minTokenOut == 0) revert MIN_OUT_NOT_VALID();

    // Get SY from YT
    address SY = IPYieldToken(yt).SY();

    // CORE FIX: Validate based on swap routing
    if (output.swapData.swapType != SwapType.NONE) {
        // Swap routing: validate tokenRedeemSy (intermediate token)
        if (!IStandardizedYield(SY).isValidTokenOut(output.tokenRedeemSy)) {
            revert TOKEN_REDEEM_SY_NOT_VALID();
        }
        // Validate external router is set
        if (output.swapData.extRouter == address(0)) {
            revert INVALID_EXT_ROUTER();
        }
    } else {
        // Direct redemption: validate tokenOut
        if (!IStandardizedYield(SY).isValidTokenOut(output.tokenOut)) {
            revert TOKEN_OUT_NOT_LISTED();
        }
    }

    // Update amount if using prevHook
    if (usePrevHookAmount) {
        netPyIn = ISuperHookResult(prevHook).getOutAmount(account);
    }
    if (netPyIn == 0) revert AMOUNT_NOT_VALID();

    return abi.encodeWithSelector(selector, receiver, yt, netPyIn, output);
}
```

### Execution Building

```solidity
function _buildHookExecutions(address prevHook, address account, bytes calldata data)
    internal view override returns (Execution[] memory executions)
{
    bytes4 selector = bytes4(data[85:89]);

    if (selector == IPendleRouterV4.redeemPyToToken.selector) {
        return _buildRedeemExecutions(prevHook, account, data);
    } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
        return _buildSwapTokenForPtExecutions(prevHook, account, data);
    } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
        return _buildSwapPtForTokenExecutions(prevHook, account, data);
    } else {
        revert INVALID_SELECTOR();
    }
}

function _buildRedeemExecutions(...) private view returns (Execution[] memory) {
    // Decode and validate
    bytes memory validatedTxData = _validateRedeemPyToToken(...);
    (,address yt, uint256 amount,) = abi.decode(validatedTxData[4:], (...));

    // Get PT from YT
    address pt = IPYieldToken(yt).PT();

    executions = new Execution[](3);
    // Approve PT
    executions[0] = Execution({
        target: pt,
        value: 0,
        callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), amount))
    });
    // Approve YT
    executions[1] = Execution({
        target: yt,
        value: 0,
        callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), amount))
    });
    // Call redeemPyToToken
    executions[2] = Execution({
        target: address(PENDLE_ROUTER_V4),
        value: 0,
        callData: validatedTxData
    });
}
```

### Inspect Function

Keep simple with fixed data for Merkle tree compatibility:

```solidity
function inspect(bytes calldata data) external view override returns (bytes memory packed) {
    bytes calldata txData_ = data[85:];
    bytes4 selector = bytes4(txData_[0:4]);

    if (selector == IPendleRouterV4.redeemPyToToken.selector) {
        (address receiver, address yt,, TokenOutput memory output) =
            abi.decode(txData_[4:], (address, address, uint256, TokenOutput));
        address pt = IPYieldToken(yt).PT();
        // Include swap routing addresses when used
        packed = abi.encodePacked(
            yt, pt, output.tokenOut, output.tokenRedeemSy,
            output.pendleSwap, output.swapData.extRouter
        );
    } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
        (address receiver, address market,,, TokenInput memory input,) =
            abi.decode(txData_[4:], (address, address, uint256, ApproxParams, TokenInput, LimitOrderData));
        packed = abi.encodePacked(
            data.extractYieldSource(), receiver, market,
            input.tokenIn, input.tokenMintSy, input.pendleSwap, input.swapData.extRouter
        );
    } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
        (address receiver, address market,, TokenOutput memory output,) =
            abi.decode(txData_[4:], (address, address, uint256, TokenOutput, LimitOrderData));
        packed = abi.encodePacked(
            data.extractYieldSource(), receiver, market,
            output.tokenOut, output.tokenRedeemSy, output.pendleSwap, output.swapData.extRouter
        );
    }
}
```

### Balance Tracking

```solidity
function _preExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(_getBalance(account, data), account);
}

function _postExecute(address, address account, bytes calldata data) internal override {
    _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
}

function _getBalance(address account, bytes calldata data) private view returns (uint256) {
    address tokenOut = _decodeTokenOut(data);

    if (tokenOut == address(0)) {
        return account.balance;
    }
    return IERC20(tokenOut).balanceOf(account);
}

function _decodeTokenOut(bytes calldata data) private view returns (address) {
    bytes4 selector = bytes4(data[85:89]);

    if (selector == IPendleRouterV4.redeemPyToToken.selector) {
        (,,, TokenOutput memory output) = abi.decode(data[89:], (...));
        return output.tokenOut;
    } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
        (, address market,,,,) = abi.decode(data[89:], (...));
        (, address pt,) = IPendleMarket(market).readTokens();
        return pt;
    } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
        (,,, TokenOutput memory output,) = abi.decode(data[89:], (...));
        return output.tokenOut;
    }
    revert INVALID_SELECTOR();
}
```

### Native ETH Handling

```solidity
function _buildSwapTokenForPtExecutions(...) private view returns (Execution[] memory) {
    // ... validation ...

    // Determine if native ETH is used
    (bool isTokenForPt, address tokenIn) = _extractTokenIn(validatedTxData);
    uint256 netTokenIn = usePrevHookAmount
        ? ISuperHookResult(prevHook).getOutAmount(account)
        : BytesLib.toUint256(data, 53);

    uint256 execValue = (isTokenForPt && tokenIn == address(0)) ? netTokenIn : 0;

    executions = new Execution[](1);
    executions[0] = Execution({
        target: address(PENDLE_ROUTER_V4),
        value: execValue,
        callData: validatedTxData
    });
}
```

## Acceptance Criteria

### Functional Requirements
- [ ] Support `redeemPyToToken` with swap routing (tokenOut != tokenRedeemSy)
- [ ] Support `redeemPyToToken` without swap routing (current behavior)
- [ ] Support `swapExactTokenForPt` with all current functionality
- [ ] Support `swapExactPtForToken` with all current functionality
- [ ] Maintain `usePrevHookAmount` chaining functionality
- [ ] Support native ETH as input for swapExactTokenForPt
- [ ] Track output balances correctly for all selectors

### Security Requirements
- [ ] Validate `tokenRedeemSy` against SY when swap routing is used
- [ ] Validate `tokenOut` against SY when no swap routing
- [ ] Validate `extRouter != address(0)` when swap routing is used
- [ ] Validate receiver matches account
- [ ] Validate minTokenOut/minPtOut > 0
- [ ] Validate amount > 0
- [ ] Validate ApproxParams bounds (guessMin <= guessMax, eps <= 1e18)
- [ ] Validate limit order expiry and addresses

### Testing Requirements
- [ ] All existing PendleRouterSwapHook tests pass (refactored)
- [ ] All existing PendleRouterRedeemHook tests pass (refactored)
- [ ] New tests for swap routing validation fix
- [ ] Integration test with SuperVault executeHooks
- [ ] Fuzzing for amounts and parameters

## Implementation

### File Structure

```
src/hooks/swappers/pendle/
├── PendleUnifiedHook.sol      # NEW: Unified hook
├── PendleRouterRedeemHook.sol # DEPRECATED
└── PendleRouterSwapHook.sol   # DEPRECATED

test/unit/hooks/pendle/
├── PendleUnifiedHook.t.sol    # NEW: Unified tests
├── PendleRouterRedeemHook.t.sol # Keep for reference
└── PendleRouterSwapHook.t.sol   # Keep for reference
```

### PendleUnifiedHook.sol

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { BytesLib } from "../../../vendor/BytesLib.sol";

import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHookResult, ISuperHookContextAware, ISuperHookInspector } from "../../../interfaces/ISuperHook.sol";
import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    TokenOutput,
    LimitOrderData,
    FillOrderParams,
    Order,
    SwapType
} from "../../../vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";
import { IPYieldToken } from "../../../vendor/pendle/IPYieldToken.sol";

/// @title PendleUnifiedHook
/// @author Superform Labs
/// @notice Unified hook for Pendle router operations: redeem, swap token to PT, swap PT to token
/// @dev Supports swap routing for redemptions to non-SY tokens via external aggregators
/// @dev Data structure:
/// @notice         bytes32 placeholder = BytesLib.toBytes32(data, 0);
/// @notice         address yieldSource = BytesLib.toAddress(data, 32);
/// @notice         bool usePrevHookAmount = _decodeBool(data, 52);
/// @notice         uint256 value = BytesLib.toUint256(data, 53);
/// @notice         bytes txData = BytesLib.slice(data, 85, data.length - 85);
contract PendleUnifiedHook is BaseHook, ISuperHookContextAware {
    using HookDataDecoder for bytes;

    uint256 private constant USE_PREV_HOOK_AMOUNT_POSITION = 52;
    uint256 private constant TX_DATA_OFFSET = 85;

    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable PENDLE_ROUTER_V4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_SELECTOR();
    error RECEIVER_NOT_VALID();
    error MARKET_NOT_VALID();
    error YT_NOT_VALID();
    error MIN_OUT_NOT_VALID();
    error AMOUNT_NOT_VALID();
    error TOKEN_OUT_NOT_LISTED();
    error TOKEN_REDEEM_SY_NOT_VALID();
    error INVALID_EXT_ROUTER();
    error SY_NOT_VALID();
    error INVALID_GUESS_PT_OUT();
    error EPS_NOT_VALID();
    error ORDER_EXPIRED();
    error MAKING_AMOUNT_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        PENDLE_ROUTER_V4 = IPendleRouterV4(pendleRouterV4_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
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
        bytes4 selector = bytes4(data[TX_DATA_OFFSET:TX_DATA_OFFSET + 4]);

        if (selector == IPendleRouterV4.redeemPyToToken.selector) {
            return _buildRedeemExecutions(prevHook, account, data);
        } else if (selector == IPendleRouterV4.swapExactTokenForPt.selector) {
            return _buildSwapTokenForPtExecutions(prevHook, account, data);
        } else if (selector == IPendleRouterV4.swapExactPtForToken.selector) {
            return _buildSwapPtForTokenExecutions(prevHook, account, data);
        } else {
            revert INVALID_SELECTOR();
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, USE_PREV_HOOK_AMOUNT_POSITION);
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external view override returns (bytes memory packed) {
        // Implementation per selector - returns fixed data for Merkle tree
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/
    // ... selector-specific build and validation functions ...
}
```

## Dependencies & Risks

### Dependencies
- Pendle Router V4 contract stability
- IPYieldToken interface (YT.SY(), YT.PT())
- IStandardizedYield interface (isValidTokenOut)

### Risks
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| External router malicious | Low | High | Non-zero check; trust Pendle ecosystem |
| Pendle router upgrade | Low | Medium | Immutable router address; redeploy if needed |
| SY token list changes | Low | Low | Validation happens at execution time |

## Migration Plan

1. Deploy PendleUnifiedHook
2. Register new hook in SuperGovernor
3. Update off-chain bundler to use new hook
4. Mark old hooks as @deprecated in NatSpec
5. Monitor for any issues during transition
6. Remove deprecated hooks in future version

## References

- Existing hooks: `src/hooks/swappers/pendle/PendleRouterRedeemHook.sol`, `PendleRouterSwapHook.sol`
- Pendle vendor interfaces: `src/vendor/pendle/`
- BaseHook: `src/hooks/BaseHook.sol`
- Similar multi-selector pattern: `src/hooks/swappers/1inch/Swap1InchHook.sol`
- [Pendle Router Docs](https://docs.pendle.finance/pendle-v2/Developers/Contracts/PendleRouter)
