// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IRedSnwapper } from "../vendor/sushiswap/IRedSnwapper.sol";
import { IRouteProcessor7 } from "../vendor/sushiswap/IRouteProcessor7.sol";

/// @title SushiSwapAmountUpdater
/// @author Superform Labs
/// @notice Validates and (for chained swaps) rescales a SushiSwap v7 `RedSnwapper.snwap` calldata whose
///         `executorData` is a nested RouteProcessor `processRoute(...)` call, WITHOUT touching the route bytes.
/// @dev Both heads have a fixed ABI layout once their selectors are validated, so every field the hooks care about is
///      read and patched at a fixed offset (the PancakeSwapAmountUpdater style). Exactly four words are ever written:
///      the outer `amountIn` / `amountOutMin` and the nested `amountIn` / `amountOutMin`.
///
///      Why both heads: with `takeSurplus == true` (what the API emits) the nested `amountOutMin` is a recipient CAP,
///      not a floor — output above it stays with the executor (verified on a Katana fork: a halved nested min halved
///      what the recipient received). Patching only the outer head would therefore leak the proportional surplus to
///      the executor on every upsized execution. The outer RedSnwapper `amountOutMin` is the real on-chain floor.
///
///      Why the route bytes are not parsed: the RouteProcessor7 route format is not public (its prefix already
///      differs from RouteProcessor6) and does not need to be — in the RedSnwapper flow the executor swaps whatever
///      it was pre-funded with (`processMyERC20` / `processNative` lineage) and splits by `uint16 share / 65535`, so
///      the route is amount-agnostic. The only amount-bearing command in the public lineage (`applyPermit`, an
///      absolute permit value) is not emitted for a RedSnwapper-fronted swap, and even then the hook's approval
///      (== execution amount) bounds what can be pulled. A multi-split live route executing at 80% / 120% without
///      re-encoding is the regression guard.
///
///      Rounding: amounts are exact; both mins use ceil. Ceil on the outer min keeps the RedSnwapper floor
///      conservative; ceil on the nested cap can only hand MORE output to the account. With ceil and a non-zero new
///      amount a positive min never collapses to zero.
library SushiSwapAmountUpdater {
    /// @notice snwap(address,uint256,address,address,uint256,address,bytes)
    bytes4 internal constant SNWAP_SELECTOR = IRedSnwapper.snwap.selector; // 0x5f3bd1c8
    /// @notice processRoute(address,uint256,address,uint256,address,bytes,bool,uint32)
    bytes4 internal constant PROCESS_ROUTE_SELECTOR = IRouteProcessor7.processRoute.selector; // 0x6be92b89

    // ─── Outer `snwap` head: 7 arg slots at 4 + 32*i, absolute offsets from the start of txData ───
    uint256 private constant OUTER_TOKEN_IN_SLOT = 4;
    uint256 private constant OUTER_AMOUNT_IN_SLOT = 36;
    uint256 private constant OUTER_RECIPIENT_SLOT = 68;
    uint256 private constant OUTER_TOKEN_OUT_SLOT = 100;
    uint256 private constant OUTER_MIN_OUT_SLOT = 132;
    uint256 private constant OUTER_EXECUTOR_SLOT = 164;
    uint256 private constant OUTER_EXECUTOR_DATA_PTR_SLOT = 196; // offset, relative to args start (byte 4)
    uint256 private constant OUTER_HEAD_MIN_LENGTH = 228; // 4 + 7 * 32

    // ─── Nested `processRoute` head: 8 arg slots at innerBase + 4 + 32*i, RELATIVE to innerBase ───
    uint256 private constant INNER_TOKEN_IN_REL = 4;
    uint256 private constant INNER_AMOUNT_IN_REL = 36;
    uint256 private constant INNER_TOKEN_OUT_REL = 68;
    uint256 private constant INNER_MIN_OUT_REL = 100;
    uint256 private constant INNER_TO_REL = 132;
    uint256 private constant INNER_ROUTE_PTR_REL = 164; // offset, relative to innerBase + 4
    uint256 private constant INNER_HEAD_MIN_LENGTH = 260; // 4 + 8 * 32

    error INVALID_SELECTOR();
    error INVALID_INNER_SELECTOR();
    error TXDATA_TOO_SHORT();
    error INVALID_EXECUTOR_DATA_OFFSET();
    error INVALID_ROUTE_OFFSET();
    error INNER_TOKEN_MISMATCH();
    error INNER_AMOUNT_MISMATCH();
    error INNER_RECIPIENT_MISMATCH();
    error ZERO_AMOUNT();

    /// @notice The outer `snwap` fields; the nested head is asserted equal field-by-field, so one copy suffices.
    struct Fields {
        address tokenIn;
        uint256 amountIn;
        address recipient;
        address tokenOut;
        uint256 amountOutMin;
        address executor;
    }

    /// @notice Validate both heads and return the outer fields
    /// @dev Reverts on: wrong outer/inner selector (which rejects `snwapMultiple` and the `*TransferValue*`
    ///      executor variants), truncated data, an `executorData` offset that does not point past the outer head, a
    ///      route offset that does not point past the nested head, nested tokens / amount / `to` that differ from the
    ///      outer tokens / amount / recipient, and a zero `amountIn` (RedSnwapper's balance mode).
    /// @param txData_ The raw `snwap` calldata (selector + ABI-encoded args)
    function readFields(bytes memory txData_) internal pure returns (Fields memory f) {
        _locateInner(txData_);
        f.tokenIn = address(uint160(_readWord(txData_, OUTER_TOKEN_IN_SLOT)));
        f.amountIn = _readWord(txData_, OUTER_AMOUNT_IN_SLOT);
        f.recipient = address(uint160(_readWord(txData_, OUTER_RECIPIENT_SLOT)));
        f.tokenOut = address(uint160(_readWord(txData_, OUTER_TOKEN_OUT_SLOT)));
        f.amountOutMin = _readWord(txData_, OUTER_MIN_OUT_SLOT);
        f.executor = address(uint160(_readWord(txData_, OUTER_EXECUTOR_SLOT)));
    }

    /// @notice Rescale a validated `snwap` calldata to a new input amount, in place
    /// @dev Patches outer amountIn (exact), outer amountOutMin (ceil), nested amountIn (exact), nested amountOutMin
    ///      (ceil). The denominator is the EMBEDDED outer amountIn (asserted equal to the nested one; the hooks
    ///      additionally assert it equals the header `inputAmount` before calling this). Non-interference by
    ///      construction: the outer words live in [4, 228), the nested words in [innerBase, innerBase + 260) with
    ///      innerBase ≥ 260, and the route region starts at or after innerBase + 292 — all disjoint.
    /// @param txData_ The raw `snwap` calldata, mutated in place
    /// @param newAmount_ The resolved execution amount
    function rescale(bytes memory txData_, uint256 newAmount_) internal pure {
        if (newAmount_ == 0) revert ZERO_AMOUNT();
        uint256 innerBase = _locateInner(txData_);

        uint256 originalAmount = _readWord(txData_, OUTER_AMOUNT_IN_SLOT); // non-zero, checked in _locateInner
        if (newAmount_ == originalAmount) return;

        uint256 outerMin =
            Math.mulDiv(_readWord(txData_, OUTER_MIN_OUT_SLOT), newAmount_, originalAmount, Math.Rounding.Ceil);
        uint256 innerMin = Math.mulDiv(
            _readWord(txData_, innerBase + INNER_MIN_OUT_REL), newAmount_, originalAmount, Math.Rounding.Ceil
        );

        _writeWord(txData_, OUTER_AMOUNT_IN_SLOT, newAmount_);
        _writeWord(txData_, OUTER_MIN_OUT_SLOT, outerMin);
        _writeWord(txData_, innerBase + INNER_AMOUNT_IN_REL, newAmount_);
        _writeWord(txData_, innerBase + INNER_MIN_OUT_REL, innerMin);
    }

    /// @dev Runs every structural and consistency check and returns the absolute offset of the nested selector.
    function _locateInner(bytes memory txData_) private pure returns (uint256 innerBase) {
        uint256 len = txData_.length;
        if (len < OUTER_HEAD_MIN_LENGTH) revert TXDATA_TOO_SHORT();
        if (_selector(txData_, 0) != SNWAP_SELECTOR) revert INVALID_SELECTOR();

        // executorData length word must live in the dynamic tail, never inside the validated outer head
        uint256 execOff = _readWord(txData_, OUTER_EXECUTOR_DATA_PTR_SLOT);
        if (execOff > len) revert INVALID_EXECUTOR_DATA_OFFSET();
        uint256 innerLenPos = 4 + execOff;
        if (innerLenPos < OUTER_HEAD_MIN_LENGTH) revert INVALID_EXECUTOR_DATA_OFFSET();
        if (len < innerLenPos + 32) revert TXDATA_TOO_SHORT();
        uint256 innerLen = _readWord(txData_, innerLenPos);
        if (innerLen < INNER_HEAD_MIN_LENGTH) revert TXDATA_TOO_SHORT();
        innerBase = innerLenPos + 32;
        if (innerLen > len || len < innerBase + innerLen) revert TXDATA_TOO_SHORT();

        if (_selector(txData_, innerBase) != PROCESS_ROUTE_SELECTOR) revert INVALID_INNER_SELECTOR();

        // route bytes must be self-contained inside executorData and start past the nested head (never read)
        uint256 routeOff = _readWord(txData_, innerBase + INNER_ROUTE_PTR_REL);
        if (routeOff > innerLen) revert INVALID_ROUTE_OFFSET();
        uint256 routeLenRel = 4 + routeOff;
        if (routeLenRel < INNER_HEAD_MIN_LENGTH) revert INVALID_ROUTE_OFFSET();
        if (routeLenRel + 32 > innerLen) revert TXDATA_TOO_SHORT();
        uint256 routeLen = _readWord(txData_, innerBase + routeLenRel);
        if (routeLen > innerLen || routeLenRel + 32 + routeLen > innerLen) revert TXDATA_TOO_SHORT();

        // nested head must describe the same trade as the outer head, so the four-word patch is complete
        if (
            _readWord(txData_, innerBase + INNER_TOKEN_IN_REL) != _readWord(txData_, OUTER_TOKEN_IN_SLOT)
                || _readWord(txData_, innerBase + INNER_TOKEN_OUT_REL) != _readWord(txData_, OUTER_TOKEN_OUT_SLOT)
        ) revert INNER_TOKEN_MISMATCH();
        uint256 outerAmount = _readWord(txData_, OUTER_AMOUNT_IN_SLOT);
        if (_readWord(txData_, innerBase + INNER_AMOUNT_IN_REL) != outerAmount) revert INNER_AMOUNT_MISMATCH();
        if (_readWord(txData_, innerBase + INNER_TO_REL) != _readWord(txData_, OUTER_RECIPIENT_SLOT)) {
            revert INNER_RECIPIENT_MISMATCH();
        }
        if (outerAmount == 0) revert ZERO_AMOUNT();
    }

    function _selector(bytes memory data_, uint256 offset_) private pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            selector := mload(add(add(data_, 0x20), offset_))
        }
    }

    function _readWord(bytes memory data_, uint256 offset_) private pure returns (uint256 word) {
        assembly ("memory-safe") {
            word := mload(add(add(data_, 0x20), offset_))
        }
    }

    function _writeWord(bytes memory data_, uint256 offset_, uint256 value_) private pure {
        assembly ("memory-safe") {
            mstore(add(add(data_, 0x20), offset_), value_)
        }
    }
}
