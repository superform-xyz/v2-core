// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IPancakeSwapRouter } from "../vendor/pancakeswap/IPancakeSwapRouter.sol";

/// @title PancakeSwapAmountUpdater
/// @author Superform Labs
/// @notice Reads and (for chained swaps) rescales the amount inside a PancakeSwap `swapExactIn` calldata
///         WITHOUT decoding the heavy nested `RouterPath[][]` route data. The `swapExactIn` head layout is
///         fixed once the selector is validated, so the token pair, recipient, min-output and the single
///         route's input amount are read/patched at fixed offsets.
/// @dev `usePrevHookAmount` rescaling is supported ONLY for single-route calldata with no fee config:
///      PancakeSwap splits the input across `routesAmount[]` and the router self-corrects intra-path rounding
///      from `weight` ratios, so a single-route patch (routesAmount[0] = newAmount, scale minOutputAmount)
///      is exact and safe. Multi-split routes stay usable for FIXED-amount (non-chained) swaps; attempting to
///      chain them reverts rather than silently mis-sizing. The router's own `minOutputAmount` check is the
///      ultimate slippage backstop in every case.
library PancakeSwapAmountUpdater {
    /// @notice swapExactIn(uint256,(address,address,uint256,uint256),uint256[],
    ///         (uint256[],address[],uint256[],bytes[],address)[][],uint256,address)
    bytes4 internal constant SWAP_EXACT_IN_SELECTOR = 0xedad400c;

    // ─── Fixed head offsets, measured from the start of `txData` (i.e. including the 4-byte selector) ───
    // Args region starts at byte 4; arg slot i starts at 4 + 32*i. `request` is a 4-field static tuple
    // encoded inline (slots 1-4). Layout: [0]orderId [1]inputToken [2]outputToken [3]minOutputAmount
    // [4]deadline [5]routesAmount-offset [6]routes-offset [7]feeConfig [8]recipient.
    uint256 private constant INPUT_TOKEN_SLOT = 36; // slot 1
    uint256 private constant OUTPUT_TOKEN_SLOT = 68; // slot 2
    uint256 private constant MIN_OUTPUT_SLOT = 100; // slot 3
    uint256 private constant ROUTES_AMOUNT_PTR_SLOT = 164; // slot 5 (offset, relative to args start = byte 4)
    uint256 private constant FEE_CONFIG_SLOT = 228; // slot 7
    uint256 private constant RECIPIENT_SLOT = 260; // slot 8
    uint256 private constant HEAD_MIN_LENGTH = 292; // 4 + 32*9 (slots 0..8 all present)

    error INVALID_SELECTOR();
    error TXDATA_TOO_SHORT();
    error INVALID_ROUTES_OFFSET();
    error SINGLE_ROUTE_REQUIRED();
    error FEE_CONFIG_UNSUPPORTED();
    error ZERO_AMOUNT();

    /// @notice Validate the selector and read the token pair + recipient from a `swapExactIn` calldata
    /// @param txData_ The raw router calldata (selector + ABI-encoded args)
    /// @return srcToken request.inputToken (the router's own native sentinel on native-input routes)
    /// @return dstToken request.outputToken
    /// @return recipient The output recipient (must equal the Superform account)
    function readFields(bytes memory txData_)
        internal
        pure
        returns (address srcToken, address dstToken, address recipient)
    {
        if (txData_.length < HEAD_MIN_LENGTH) revert TXDATA_TOO_SHORT();
        if (_selector(txData_) != SWAP_EXACT_IN_SELECTOR) revert INVALID_SELECTOR();
        srcToken = address(uint160(_readWord(txData_, INPUT_TOKEN_SLOT)));
        dstToken = address(uint160(_readWord(txData_, OUTPUT_TOKEN_SLOT)));
        recipient = address(uint160(_readWord(txData_, RECIPIENT_SLOT)));
    }

    /// @notice Rescale a SINGLE-ROUTE, zero-fee `swapExactIn` calldata to a new input amount, in place
    /// @dev Reverts (rather than mis-sizing) on multi-route or non-zero feeConfig calldata. Scales
    ///      request.minOutputAmount with EXACT full-precision mulDiv (ceil) against the EMBEDDED route amount
    ///      — never a mutable header — so the floor tracks the new size truthfully and the quote denominator
    ///      cannot be weakened by a prior header rewrite.
    /// @param txData_ The raw router calldata, mutated in place (routesAmount[0] and minOutputAmount)
    /// @param newAmount_ The resolved input amount for the single route
    function rescaleSingleRoute(bytes memory txData_, uint256 newAmount_) internal pure {
        if (newAmount_ == 0) revert ZERO_AMOUNT();
        if (txData_.length < HEAD_MIN_LENGTH) revert TXDATA_TOO_SHORT();
        if (_selector(txData_) != SWAP_EXACT_IN_SELECTOR) revert INVALID_SELECTOR();
        if (_readWord(txData_, FEE_CONFIG_SLOT) != 0) revert FEE_CONFIG_UNSUPPORTED();

        // routesAmount data lives at (args-start + offset) == (4 + ptr)
        uint256 arrPos = 4 + _readWord(txData_, ROUTES_AMOUNT_PTR_SLOT);
        // Non-interference: the array length word (arrPos) and element word (arrPos+32) must live in the
        // dynamic tail, never the fixed head. A legit swapExactIn places routesAmount data at the tail start
        // (arrPos == HEAD_MIN_LENGTH); this guard makes it provable that the in-place element write below
        // cannot clobber a validated head word (tokens/minOut/deadline/feeConfig/recipient/the array pointers)
        // via a malicious offset — so the surgical patch is non-interfering by construction.
        if (arrPos < HEAD_MIN_LENGTH) revert INVALID_ROUTES_OFFSET();
        if (txData_.length < arrPos + 32) revert TXDATA_TOO_SHORT();
        if (_readWord(txData_, arrPos) != 1) revert SINGLE_ROUTE_REQUIRED();
        uint256 elemPos = arrPos + 32;
        if (txData_.length < elemPos + 32) revert TXDATA_TOO_SHORT();

        // Denominator is the EMBEDDED route amount (the real quote size), read before we overwrite it.
        uint256 originalRouteAmount = _readWord(txData_, elemPos);
        if (originalRouteAmount == 0) revert ZERO_AMOUNT();

        uint256 originalMinOut = _readWord(txData_, MIN_OUTPUT_SLOT);
        // Exact proportional scaling (ceil keeps the floor conservative), no percentage quantization.
        // Ceil + the newAmount_/originalRouteAmount != 0 guards above make this >= 1 whenever
        // originalMinOut > 0, so a positive floor can never silently collapse to 0.
        uint256 scaledMinOut = Math.mulDiv(originalMinOut, newAmount_, originalRouteAmount, Math.Rounding.Ceil);

        _writeWord(txData_, MIN_OUTPUT_SLOT, scaledMinOut);
        _writeWord(txData_, elemPos, newAmount_);
    }

    /// @notice Sum of the embedded routesAmount array (the exact amount the router will pull), for any route
    ///         count. Used by the hook to assert the header amount truthfully describes the executed trade.
    /// @param txData_ The raw router calldata
    /// @return total The summed input across all routes
    function totalRoutesAmount(bytes memory txData_) internal pure returns (uint256 total) {
        if (txData_.length < HEAD_MIN_LENGTH) revert TXDATA_TOO_SHORT();
        if (_selector(txData_) != SWAP_EXACT_IN_SELECTOR) revert INVALID_SELECTOR();
        uint256 arrPos = 4 + _readWord(txData_, ROUTES_AMOUNT_PTR_SLOT);
        if (arrPos < HEAD_MIN_LENGTH) revert INVALID_ROUTES_OFFSET();
        if (txData_.length < arrPos + 32) revert TXDATA_TOO_SHORT();
        uint256 n = _readWord(txData_, arrPos);
        uint256 end = arrPos + 32 + n * 32;
        if (n == 0 || txData_.length < end) revert TXDATA_TOO_SHORT();
        for (uint256 i; i < n; ++i) {
            total += _readWord(txData_, arrPos + 32 + i * 32);
        }
    }

    function _selector(bytes memory data_) private pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            selector := mload(add(data_, 0x20))
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
