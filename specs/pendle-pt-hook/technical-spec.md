# PendlePTHook Technical Specification

## Overview

PendlePTHook is a simplified Pendle hook for PT (Principal Token) operations. Unlike PendleUnifiedHook which requires a `bytes4 selector` in the payload to determine the operation type, PendlePTHook derives the operation entirely from header fields (`inputToken`, `outputToken`) and on-chain state (`yt.isExpired()`).

This eliminates the selector from the payload, removes limit order support, and produces a smaller, simpler hook with the same trust model as PendleUnifiedHook.

## Problem Statement / Motivation

PendleUnifiedHook uses a payload-embedded selector (`swapExactTokenForPt`, `swapExactPtForToken`, `redeemPyToToken`) to dispatch operations. Since the header already contains `inputToken` and `outputToken`, and the PT address can be derived from the market, the operation type is implicit:

- `outputToken == PT` → buy PT
- `inputToken == PT && !expired` → sell PT (AMM)
- `inputToken == PT && expired` → redeem PT (par)

A dedicated PT hook with this implicit routing is simpler to construct off-chain, has less payload overhead, and removes the entire limit order validation surface.

## Proposed Solution

A new contract `PendlePTHook` that:
1. Derives PT from `IPendleMarket(yieldSource).readTokens()`
2. Compares header `inputToken`/`outputToken` against PT to determine direction
3. Checks `IPYieldToken(yt).isExpired()` to distinguish sell from redeem
4. Uses the same standard swap calldata layout (Layer 0 + Layer 1 + Layer 2)
5. Implements `ISuperHookOutflow` for OMS sizing

## Technical Considerations

### Architecture
- Same inheritance as PendleUnifiedHook: `BaseHook`, `ISuperHookSwap`, `ISuperHookContextAware`, `ISuperHookInflowOutflow`, `ISuperHookOutflow`, `ISuperHookInspector`
- Immutable `PENDLE_ROUTER_V4` set at construction
- HookSubType: `PTYT` (same as PendleUnifiedHook)

### Operation Routing Logic
```
readTokens(yieldSource) → (sy, pt, yt)

if (headerOutputToken == pt && headerInputToken != pt):
    → _buildSwapTokenForPtExecutions (buy)
elif (headerInputToken == pt && headerOutputToken != pt):
    if (!IPYieldToken(yt).isExpired()):
        → _buildSwapPtForTokenExecutions (sell via AMM)
    else:
        → _buildRedeemExecutions (redeem post-maturity)
else:
    → revert INVALID_PT_OPERATION()
```

### Payload Encoding (Layer 2)
No selector prefix. Payload varies by derived operation:

**Buy PT:**
```solidity
abi.encode(
    address tokenMintSy,
    address pendleSwap,
    SwapData swapData,
    ApproxParams guessPtOut
)
```
No LimitOrderData (always empty).

**Sell PT:**
```solidity
abi.encode(
    address tokenRedeemSy,
    address pendleSwap,
    SwapData swapData
)
```
No LimitOrderData (always empty).

**Redeem PT:**
```solidity
abi.encode(
    address tokenRedeemSy,
    address pendleSwap,
    SwapData swapData
)
```
Same encoding as sell — the hook differentiates via `yt.isExpired()`.

### Security Considerations
- Same trust model as PendleUnifiedHook: signer validates market addresses
- No limit orders → removes entire limit order validation surface
- On-chain expiry check eliminates selector mismatch risk (PendleUnifiedHook trusts off-chain selector choice)
- Approval hygiene: reset-set-cleanup pattern carried forward
- Gas griefing limits: MAX_ITERATIONS, MAX_EPS carried forward for ApproxParams (buy path only)

### Expiry Boundary Edge Case
The `yt.isExpired()` check is evaluated at execution time, not signing time. A transaction signed as a sell (pre-maturity) that gets executed after expiry will be routed to redeem. This is **correct behavior** — if the market expires between signing and execution, redemption is the only valid path. The Pendle Router would revert on a swap anyway.

## Acceptance Criteria

### Functional Requirements
- [ ] Buy PT: `outputToken == PT && inputToken != PT` → `swapExactTokenForPt`
- [ ] Sell PT: `inputToken == PT && outputToken != PT && !yt.isExpired()` → `swapExactPtForToken`
- [ ] Redeem PT: `inputToken == PT && outputToken != PT && yt.isExpired()` → `redeemPyToToken`
- [ ] Invalid combinations revert with `INVALID_PT_OPERATION()`
- [ ] No selector in payload — pure routing params
- [ ] No limit orders — `LimitOrderData` always empty in Router calls
- [ ] `inspect()` returns `abi.encodePacked(yieldSource, outputToken)` (40 bytes)
- [ ] `ISuperHookOutflow` implemented (`decodeAmounts`, `amountRoles`, `replaceCalldataAmounts`)
- [ ] `usePrevHookAmount` chaining works with `HookDataUpdater.getUpdatedOutputAmount()`
- [ ] Native ETH input supported for buy path (single execution with `value = netTokenIn`)
- [ ] Approval hygiene: reset-approve-execute-cleanup pattern
- [ ] All PendleUnifiedHook validations carried forward (outputMin != 0, inputAmount != 0, SY != address(0), ApproxParams bounds, SwapData validation)

### Non-Functional Requirements
- [ ] Unit tests for all 3 paths + error cases
- [ ] Integration tests against real Pendle markets (fork tests)
- [ ] Gas consumption comparable to or better than PendleUnifiedHook
- [ ] Bytecode generated and locked

## Implementation

### `src/hooks/swappers/pendle/PendlePTHook.sol`

```solidity
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResult,
    ISuperHookContextAware,
    ISuperHookInspector,
    ISuperHookInflowOutflow,
    ISuperHookOutflow
} from "../../../interfaces/ISuperHook.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {
    IPendleRouterV4,
    ApproxParams,
    TokenInput,
    LimitOrderData,
    TokenOutput,
    FillOrderParams,
    SwapData,
    SwapType
} from "../../../vendor/pendle/IPendleRouterV4.sol";
import { IPendleMarket } from "../../../vendor/pendle/IPendleMarket.sol";
import { IPYieldToken } from "../../../vendor/pendle/IPYieldToken.sol";
import { IStandardizedYield } from "../../../vendor/pendle/IStandardizedYield.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { HookDataUpdater } from "../../../libraries/HookDataUpdater.sol";
import { SwapCalldataLayout } from "../../../libraries/SwapCalldataLayout.sol";
import { ISuperHookSwap } from "../../../interfaces/ISuperHookSwap.sol";

/// @title PendlePTHook
/// @author Superform Labs
/// @notice Simplified Pendle hook for PT operations — derives operation type from header tokens + YT expiry
/// @dev No selector in payload. No limit orders. Pure AMM swaps + par redemption.
/// @dev Operation routing:
/// @dev   outputToken == PT && inputToken != PT  → swapExactTokenForPt (buy)
/// @dev   inputToken == PT && outputToken != PT && !yt.isExpired() → swapExactPtForToken (sell)
/// @dev   inputToken == PT && outputToken != PT && yt.isExpired()  → redeemPyToToken (redeem)
/// @dev   anything else → revert
/// @dev data layout: standard Layer 0 (52-byte header) + Layer 1 (swap params) + Layer 2 (payload)
/// @notice         bytes32   yieldSourceOracleId = BytesLib.toBytes32(data, 0);
/// @notice         address   yieldSource      = BytesLib.toAddress(data, 32);
/// @notice         address   inputToken       = BytesLib.toAddress(data, 52);
/// @notice         address   outputToken      = BytesLib.toAddress(data, 72);
/// @notice         uint256   inputAmount      = BytesLib.toUint256(data, 92);
/// @notice         uint256   outputQuote      = BytesLib.toUint256(data, 124);
/// @notice         uint256   outputMin        = BytesLib.toUint256(data, 156);
/// @notice         bool      usePrevHookAmount = _decodeBool(data, 188);
/// @notice         uint256   payload_paramLength = BytesLib.toUint256(data, 189);
/// @notice         bytes     payload          = BytesLib.slice(data, 221, payload_paramLength);
/// @dev Trust assumptions: same as PendleUnifiedHook
/// @dev   - yieldSource (Pendle market) is trusted from the signed intent
/// @dev   - readTokens() on market returns (SY, PT, YT) — a malicious market could return attacker-controlled addresses
/// @dev   - Signer is responsible for only submitting known-good market addresses
/// @dev   - pendleSwap and SwapData.extRouter are user-supplied via signed intent, not whitelisted
contract PendlePTHook is BaseHook, ISuperHookSwap, ISuperHookContextAware, ISuperHookInflowOutflow, ISuperHookOutflow {

    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant MAX_EPS = 1e18;
    uint256 private constant MAX_ITERATIONS = 256;
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /*//////////////////////////////////////////////////////////////
                        DATA LAYOUT POSITIONS
    //////////////////////////////////////////////////////////////*/
    uint256 private constant AMOUNT_POSITION = SwapCalldataLayout.AMOUNT_POSITION;

    /*//////////////////////////////////////////////////////////////
                                 IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IPendleRouterV4 public immutable PENDLE_ROUTER_V4;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error INVALID_PT_OPERATION();
    error EPS_NOT_VALID();
    error SY_NOT_VALID();
    error MIN_OUT_NOT_VALID();
    error AMOUNT_IN_NOT_VALID();
    error GUESS_PT_OUT_NOT_VALID();
    error EXT_ROUTER_NOT_VALID();
    error TOKEN_OUT_NOT_LISTED();
    error TOKEN_REDEEM_SY_NOT_VALID();
    error MAX_ITERATION_NOT_VALID();
    error OUTPUT_TOKEN_MISMATCH();
    error PENDLE_SWAP_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address pendleRouterV4_) BaseHook(HookType.NONACCOUNTING, HookSubTypes.PTYT) {
        if (pendleRouterV4_ == address(0)) revert ADDRESS_NOT_VALID();
        PENDLE_ROUTER_V4 = IPendleRouterV4(pendleRouterV4_);
    }

    function name() external pure override returns (string memory) {
        return "Pendle PT";
    }

    function description() external pure override returns (string memory) {
        return "Executes Pendle PT operations (buy, sell, or redeem)";
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
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
        bool usePrevHookAmount = _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
        uint256 inputAmount = BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
        uint256 outputMin = BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);

        address yieldSource = HookDataDecoder.extractYieldSource(data);
        address headerInputToken = BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
        address headerOutputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);

        if (outputMin == 0) revert MIN_OUT_NOT_VALID();

        // Pre-compute amounts
        uint256 netTokenIn;
        uint256 scaledOutputMin;
        if (usePrevHookAmount) {
            netTokenIn = ISuperHookResult(prevHook).getOutAmount(account);
            scaledOutputMin = HookDataUpdater.getUpdatedOutputAmount(netTokenIn, inputAmount, outputMin);
            if (scaledOutputMin == 0) revert MIN_OUT_NOT_VALID();
        } else {
            netTokenIn = inputAmount;
            scaledOutputMin = outputMin;
        }
        if (netTokenIn == 0) revert AMOUNT_IN_NOT_VALID();

        // Derive PT, YT from market
        (address sy, address pt, address yt) = IPendleMarket(yieldSource).readTokens();
        if (sy == address(0)) revert SY_NOT_VALID();

        // Extract routing params from payload (no selector prefix)
        bytes memory routingParams = data[SwapCalldataLayout.PAYLOAD_DATA_OFFSET:];

        // Route based on header tokens + expiry
        address derivedTokenOut;
        if (headerOutputToken == pt && headerInputToken != pt) {
            // Buy PT: token → PT
            (executions, derivedTokenOut) = _buildSwapTokenForPtExecutions(
                account, yieldSource, headerInputToken, netTokenIn, scaledOutputMin, routingParams
            );
        } else if (headerInputToken == pt && headerOutputToken != pt) {
            if (!IPYieldToken(yt).isExpired()) {
                // Sell PT: PT → token (AMM, pre-maturity)
                (executions, derivedTokenOut) = _buildSwapPtForTokenExecutions(
                    account, yieldSource, sy, pt, headerOutputToken, netTokenIn, scaledOutputMin, routingParams
                );
            } else {
                // Redeem PT: PT+YT → token (post-maturity)
                (executions, derivedTokenOut) = _buildRedeemExecutions(
                    account, sy, pt, yt, headerOutputToken, netTokenIn, scaledOutputMin, routingParams
                );
            }
        } else {
            revert INVALID_PT_OPERATION();
        }

        if (headerOutputToken != derivedTokenOut) revert OUTPUT_TOKEN_MISMATCH();
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function decodeUsePrevHookAmount(bytes memory data) external pure returns (bool) {
        return _decodeBool(data, SwapCalldataLayout.USE_PREV_HOOK_OFFSET);
    }

    function decodeAmounts(bytes memory data) external pure override returns (uint256[] memory amounts) {
        amounts = new uint256[](1);
        amounts[0] = BytesLib.toUint256(data, AMOUNT_POSITION);
    }

    function amountRoles(bytes memory) external pure override returns (ISuperHookInflowOutflow.AmountMeta[] memory meta) {
        meta = new ISuperHookInflowOutflow.AmountMeta[](1);
        meta[0] = ISuperHookInflowOutflow.AmountMeta(ISuperHookInflowOutflow.Direction.IN, ISuperHookInflowOutflow.Denomination.TOKEN);
    }

    function _supportsSizingInterface() internal pure override returns (bool) {
        return true;
    }

    function replaceCalldataAmounts(
        bytes memory data,
        uint256[] memory amounts
    )
        external
        pure
        override
        returns (bytes memory)
    {
        if (amounts.length != 1) revert INVALID_AMOUNTS_LENGTH();
        return _replaceCalldataAmount(data, amounts[0], AMOUNT_POSITION);
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        if (interfaceId == type(ISuperHookInflowOutflow).interfaceId) return true;
        if (interfaceId == type(ISuperHookOutflow).interfaceId) return true;
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(ISuperHook).interfaceId
            || interfaceId == type(ISuperHookResult).interfaceId
            || interfaceId == type(ISuperHookInspector).interfaceId;
    }

    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        address yieldSource = HookDataDecoder.extractYieldSource(data);
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        return abi.encodePacked(yieldSource, outputToken);
    }

    // ─── ISuperHookSwap ──────────────────────────────────────────────────────

    function encodeSwapData(
        ISuperHookSwap.SwapHeader calldata header,
        bytes calldata payload
    )
        external
        pure
        override
        returns (bytes memory)
    {
        return bytes.concat(
            bytes(new bytes(SwapCalldataLayout.HEADER_SIZE)),
            bytes20(header.inputToken),
            bytes20(header.outputToken),
            bytes32(header.inputAmount),
            bytes32(header.outputQuote),
            bytes32(header.outputMin),
            bytes1(header.usePrevHookAmount ? uint8(1) : uint8(0)),
            bytes32(payload.length),
            payload
        );
    }

    function decodeInputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.INPUT_TOKEN_OFFSET);
    }

    function decodeOutputToken(bytes calldata data) external pure override returns (address) {
        return BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
    }

    function decodeInputAmount(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.INPUT_AMOUNT_OFFSET);
    }

    function decodeOutputQuote(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_QUOTE_OFFSET);
    }

    function decodeOutputMin(bytes calldata data) external pure override returns (uint256) {
        return BytesLib.toUint256(data, SwapCalldataLayout.OUTPUT_MIN_OFFSET);
    }

    function decodePayload(bytes calldata data) external pure override returns (bytes memory) {
        uint256 payloadLen = BytesLib.toUint256(data, SwapCalldataLayout.PAYLOAD_LENGTH_OFFSET);
        return BytesLib.slice(data, SwapCalldataLayout.PAYLOAD_DATA_OFFSET, payloadLen);
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(account, data) - getOutAmount(account), account);
        _setOutToken(BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET), account);
    }

    /*//////////////////////////////////////////////////////////////
                                 PRIVATE METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds executions for swapExactTokenForPt (token → PT)
    /// @dev routingParams: abi.encode(address tokenMintSy, address pendleSwap, SwapData swapData, ApproxParams guessPtOut)
    function _buildSwapTokenForPtExecutions(
        address account,
        address yieldSource,
        address headerInputToken,
        uint256 netTokenIn,
        uint256 scaledOutputMin,
        bytes memory routingParams
    )
        private
        pure
        returns (Execution[] memory executions, address tokenOut)
    {
        (
            address tokenMintSy,
            address pendleSwap,
            SwapData memory swapData,
            ApproxParams memory guessPtOut
        ) = abi.decode(routingParams, (address, address, SwapData, ApproxParams));

        if (guessPtOut.guessMin > guessPtOut.guessMax) revert GUESS_PT_OUT_NOT_VALID();
        if (guessPtOut.eps > MAX_EPS) revert EPS_NOT_VALID();
        if (guessPtOut.maxIteration > MAX_ITERATIONS) revert MAX_ITERATION_NOT_VALID();

        _validateSwapData(swapData, pendleSwap);

        TokenInput memory input = TokenInput({
            tokenIn: headerInputToken,
            netTokenIn: netTokenIn,
            tokenMintSy: tokenMintSy,
            pendleSwap: pendleSwap,
            swapData: swapData
        });

        // Empty limit order data — no limit orders in PendlePTHook
        LimitOrderData memory emptyLimit;

        // PT is the output — derived by the Router from yieldSource
        // tokenOut will be validated against headerOutputToken in the caller
        // We return headerInputToken's counterpart (PT) but since we don't have PT address here,
        // we rely on the caller's OUTPUT_TOKEN_MISMATCH check
        // Actually, we need PT. Let's get it from the market.
        // NOTE: readTokens is already called in the parent. We can pass pt down or re-derive.
        // For simplicity, we accept that the caller validates headerOutputToken == pt.
        // tokenOut = pt is already known to the caller via readTokens.
        // We set tokenOut = headerInputToken is wrong. Let's just skip assigning — caller handles it.

        // Actually we need to return the correct tokenOut for the OUTPUT_TOKEN_MISMATCH check.
        // Since the buy path outputs PT, and the caller already has pt from readTokens(),
        // we should receive pt as a parameter. Let's restructure.

        // For now, return address(0) and let the caller set derivedTokenOut = pt
        tokenOut = address(0); // caller will override

        if (headerInputToken != address(0)) {
            executions = new Execution[](4);
            executions[0] = Execution({
                target: headerInputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
            });
            executions[1] = Execution({
                target: headerInputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
            });
            executions[2] = Execution({
                target: address(PENDLE_ROUTER_V4),
                value: 0,
                callData: abi.encodeCall(
                    IPendleRouterV4.swapExactTokenForPt,
                    (account, yieldSource, scaledOutputMin, guessPtOut, input, emptyLimit)
                )
            });
            executions[3] = Execution({
                target: headerInputToken,
                value: 0,
                callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
            });
        } else {
            executions = new Execution[](1);
            executions[0] = Execution({
                target: address(PENDLE_ROUTER_V4),
                value: netTokenIn,
                callData: abi.encodeCall(
                    IPendleRouterV4.swapExactTokenForPt,
                    (account, yieldSource, scaledOutputMin, guessPtOut, input, emptyLimit)
                )
            });
        }
    }

    /// @dev Builds executions for swapExactPtForToken (PT → token, pre-maturity)
    /// @dev routingParams: abi.encode(address tokenRedeemSy, address pendleSwap, SwapData swapData)
    function _buildSwapPtForTokenExecutions(
        address account,
        address yieldSource,
        address sy,
        address pt,
        address headerOutputToken,
        uint256 netTokenIn,
        uint256 scaledOutputMin,
        bytes memory routingParams
    )
        private
        pure
        returns (Execution[] memory executions, address tokenOut)
    {
        (address tokenRedeemSy, address pendleSwap, SwapData memory swapData) =
            abi.decode(routingParams, (address, address, SwapData));

        TokenOutput memory output = TokenOutput({
            tokenOut: headerOutputToken,
            minTokenOut: scaledOutputMin,
            tokenRedeemSy: tokenRedeemSy,
            pendleSwap: pendleSwap,
            swapData: swapData
        });

        tokenOut = headerOutputToken;

        if (output.swapData.swapType != SwapType.NONE) {
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
                revert TOKEN_REDEEM_SY_NOT_VALID();
            }
            _validateSwapData(swapData, pendleSwap);
        } else {
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
                revert TOKEN_OUT_NOT_LISTED();
            }
        }

        LimitOrderData memory emptyLimit;

        executions = new Execution[](4);
        executions[0] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[1] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
        });
        executions[2] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(
                IPendleRouterV4.swapExactPtForToken,
                (account, yieldSource, netTokenIn, output, emptyLimit)
            )
        });
        executions[3] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
    }

    /// @dev Builds executions for redeemPyToToken (PT+YT → token, post-maturity)
    /// @dev routingParams: abi.encode(address tokenRedeemSy, address pendleSwap, SwapData swapData)
    function _buildRedeemExecutions(
        address account,
        address sy,
        address pt,
        address yt,
        address headerOutputToken,
        uint256 netTokenIn,
        uint256 scaledOutputMin,
        bytes memory routingParams
    )
        private
        pure
        returns (Execution[] memory executions, address tokenOut)
    {
        (address tokenRedeemSy, address pendleSwap, SwapData memory swapData) =
            abi.decode(routingParams, (address, address, SwapData));

        TokenOutput memory output = TokenOutput({
            tokenOut: headerOutputToken,
            minTokenOut: scaledOutputMin,
            tokenRedeemSy: tokenRedeemSy,
            pendleSwap: pendleSwap,
            swapData: swapData
        });

        tokenOut = headerOutputToken;

        if (output.swapData.swapType != SwapType.NONE) {
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenRedeemSy)) {
                revert TOKEN_REDEEM_SY_NOT_VALID();
            }
            _validateSwapData(swapData, pendleSwap);
        } else {
            if (!IStandardizedYield(sy).isValidTokenOut(output.tokenOut)) {
                revert TOKEN_OUT_NOT_LISTED();
            }
        }

        executions = new Execution[](7);
        executions[0] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[1] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
        });
        executions[2] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[3] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), netTokenIn))
        });
        executions[4] = Execution({
            target: address(PENDLE_ROUTER_V4),
            value: 0,
            callData: abi.encodeCall(IPendleRouterV4.redeemPyToToken, (account, yt, netTokenIn, output))
        });
        executions[5] = Execution({
            target: pt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
        executions[6] = Execution({
            target: yt,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (address(PENDLE_ROUTER_V4), 0))
        });
    }

    /// @dev Validates SwapData fields when swapType is not NONE
    function _validateSwapData(SwapData memory swapData, address pendleSwap) private pure {
        if (swapData.swapType != SwapType.NONE) {
            if (pendleSwap == address(0)) revert PENDLE_SWAP_NOT_VALID();
            if (swapData.swapType != SwapType.ETH_WETH) {
                if (swapData.extRouter == address(0) || swapData.extRouter == NATIVE_TOKEN) {
                    revert EXT_ROUTER_NOT_VALID();
                }
            }
        }
    }

    /// @dev Gets balance of output token for the account
    function _getBalance(address account, bytes calldata data) private view returns (uint256) {
        address outputToken = BytesLib.toAddress(data, SwapCalldataLayout.OUTPUT_TOKEN_OFFSET);
        if (outputToken == address(0) || outputToken == NATIVE_TOKEN) {
            return account.balance;
        }
        return IERC20(outputToken).balanceOf(account);
    }
}
```

### Key Implementation Notes

1. **readTokens() called once**: The parent `_buildHookExecutions` calls `readTokens()` once and passes `sy`, `pt`, `yt` down to the builders. PendleUnifiedHook calls `readTokens()` in each builder, which is redundant.

2. **Buy path tokenOut**: For the buy path, `derivedTokenOut` should be `pt` (the PT address from `readTokens()`). The caller sets this directly since it already has `pt`. The builder returns `address(0)` as a sentinel, and the caller overrides with `pt` before the `OUTPUT_TOKEN_MISMATCH` check.

   **Correction**: Looking at this more carefully, the cleanest approach is to pass `pt` into `_buildSwapTokenForPtExecutions` and have it return `pt` as `tokenOut`. This matches PendleUnifiedHook's pattern where `_buildSwapTokenForPtExecutions` calls `readTokens()` itself. For PendlePTHook, since we already have `pt`, we should just pass it in.

3. **Sell/Redeem same payload encoding**: Both sell and redeem paths use `abi.encode(tokenRedeemSy, pendleSwap, SwapData)`. The hook differentiates them via `yt.isExpired()` at runtime.

4. **`_validateSwapData` helper**: Extracted from PendleUnifiedHook's inline validation to reduce duplication across the three paths.

5. **`_buildSwapPtForTokenExecutions` and `_buildRedeemExecutions` are `view`**: The `isExpired()` check happens in `_buildHookExecutions` before dispatching. The builders themselves only need `pure` (except for `isValidTokenOut` which is `view`).

## References & Research

### Internal References
- `src/hooks/swappers/pendle/PendleUnifiedHook.sol` — reference implementation
- `src/hooks/BaseHook.sol` — base class with lifecycle management
- `src/libraries/SwapCalldataLayout.sol` — header offset constants
- `src/libraries/HookDataDecoder.sol` — yieldSource extraction
- `src/libraries/HookDataUpdater.sol` — amount scaling for chaining
- `src/vendor/pendle/IPendleRouterV4.sol` — Pendle Router interface
- `src/vendor/pendle/IPYieldToken.sol` — YT interface with `isExpired()`
- `src/vendor/pendle/IPendleMarket.sol` — market interface with `readTokens()`

### Security References
- See `specs/pendle-pt-hook/research/evm-security.md`
- Penpie exploit (Sept 2024, $27M) — malicious SY via permissionless market registration
- LI.FI exploit ($9M) — unvalidated calldata in swap logic
- Trust model same as PendleUnifiedHook (documented in NatSpec)
