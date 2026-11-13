// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BytesLib } from "../vendor/BytesLib.sol";
import { ISwapRouter02 } from "../vendor/everlong/ISwapRouter02.sol";

/// @title EverlongAmountUpdater
/// @author Superform Labs
/// @notice Validates and (for chained swaps) rescales an Everlong Router `multicall(deadline, calls)`. The router is a
///         plain Uniswap SwapRouter02, so this allowlist is the security boundary: exact-input V3 legs paying the
///         router, exactly one sweep/unwrap tail paying the account, an optional trailing `refundETH`. Anything else
///         reverts.
/// @dev `abi.decode` is used instead of fixed offsets because `calls` is a dynamic array of variable-length entries;
///      `abi.encodeWithSelector` re-emits the canonical layout.
///      Rescaling: leg `amountIn` floor-scaled with the remainder on the LAST leg (sum exact); every minimum
///      ceil-scaled; deadline, paths, fees and recipients untouched; a leg that would become 0 reverts (0 is the
///      router's CONTRACT_BALANCE sentinel). Same amount returns the original bytes.
///      Path rule: a path may not revisit the leg's tokenIn or tokenOut. The router's `pay()` wraps its own ETH
///      whenever it pays WETH9, so a native-input route cycling through WETH9 would spend the value reserved for later
///      legs and pull the account's WETH9 through any standing allowance.
///      Fees: `*WithFee` tails check `amountMinimum` BEFORE the fee, so the account receives balance x
///      (1 - feeBips/10000); capped here at MAX_TAIL_FEE_BIPS. `feeRecipient` is not pinned (a rotation must not brick
///      the hook); the hooks enforce their own post-fee floor.
library EverlongAmountUpdater {
    bytes4 internal constant MULTICALL_SELECTOR = ISwapRouter02.multicall.selector; // 0x5ae401dc
    bytes4 internal constant EXACT_INPUT_SINGLE_SELECTOR = ISwapRouter02.exactInputSingle.selector; // 0x04e45aaf
    bytes4 internal constant EXACT_INPUT_SELECTOR = ISwapRouter02.exactInput.selector; // 0xb858183f
    bytes4 internal constant SWEEP_TOKEN_SELECTOR = ISwapRouter02.sweepToken.selector; // 0xdf2ab5bb
    bytes4 internal constant SWEEP_TOKEN_WITH_FEE_SELECTOR = ISwapRouter02.sweepTokenWithFee.selector; // 0xe0e189a0
    bytes4 internal constant UNWRAP_WETH9_SELECTOR = ISwapRouter02.unwrapWETH9.selector; // 0x49404b7c
    bytes4 internal constant UNWRAP_WETH9_WITH_FEE_SELECTOR = ISwapRouter02.unwrapWETH9WithFee.selector; // 0x9b2c0a37
    bytes4 internal constant REFUND_ETH_SELECTOR = ISwapRouter02.refundETH.selector; // 0x12210e8a

    /// @dev Router `Constants.ADDRESS_THIS`: swap legs must pay the router
    address internal constant ADDRESS_THIS = address(2);
    /// @dev Router `Constants.MSG_SENDER`
    address internal constant MSG_SENDER = address(1);
    /// @dev Tail fee cap in bps (the API charges 4, the router allows up to 100)
    uint256 internal constant MAX_TAIL_FEE_BIPS = 10;

    /// @dev V3 path = token(20) [fee(3) token(20)]+
    uint256 private constant PATH_ADDR = 20;
    uint256 private constant PATH_HOP = 23;

    error INVALID_SELECTOR();
    error TXDATA_TOO_SHORT();
    error EMPTY_CALLS();
    error UNSUPPORTED_LEG_SELECTOR(bytes4 selector);
    error INVALID_LEG_ORDER();
    error INVALID_LEG_RECIPIENT();
    error INVALID_TAIL_RECIPIENT();
    error ZERO_LEG_AMOUNT();
    error LEG_TOKEN_MISMATCH();
    error TAIL_TOKEN_MISMATCH();
    error INVALID_PATH();
    error MISSING_TAIL();
    error DUPLICATE_TAIL();
    error ZERO_AMOUNT();
    error INVALID_PRICE_LIMIT();
    error FEE_TOO_HIGH();

    /// @notice What the hooks need from a validated multicall
    struct Fields {
        address tokenIn; // common tokenIn of all swap legs (WETH9 on native-input routes)
        address tokenOut; // common tokenOut of all swap legs (WETH9 on native-output routes)
        uint256 totalIn; // sum of swap-leg amountIn (hooks assert == header inputAmount)
        uint256 tailMin; // tail amountMinimum, checked PRE-fee on the router balance
        address recipient; // tail recipient (hooks assert == account)
        uint256 feeBips; // 0 for the no-fee tail variants
        address feeRecipient; // address(0) for the no-fee tail variants
        bool nativeOut; // tail is unwrapWETH9[WithFee]
        bool hasRefund; // a trailing refundETH() is present (the API appends it whenever ETH is involved, in or out)
        uint256 deadline; // never modified; the API fixes it at quote + 600 s
        uint256 swapLegs; // number of swap legs (>= 1)
    }

    enum Phase {
        SWAP,
        TAIL,
        REFUND
    }

    struct Parsed {
        uint256 deadline;
        bytes[] calls;
        Fields f;
        uint256 lastSwapIdx;
        uint256 tailIdx;
    }

    /// @notice Validate a multicall against the allowlist and return the fields the hooks check
    /// @param weth9_ The router's WETH9; `address(0)` skips only the unwrap-tail identity check
    function readFields(bytes memory txData_, address weth9_) internal pure returns (Fields memory) {
        return _parse(txData_, weth9_).f;
    }

    /// @notice Rescale a validated multicall to a new total input, returning the re-encoded calldata
    /// @param txData_ The raw `multicall(deadline, calls)` calldata (selector included)
    /// @param weth9_ The router's WETH9; `address(0)` skips only the unwrap-tail identity check (pure sizing path,
    ///        `build()` re-validates with the real one)
    /// @param newAmount_ The resolved execution amount (sum of all rescaled legs)
    function rescale(bytes memory txData_, address weth9_, uint256 newAmount_) internal pure returns (bytes memory) {
        if (newAmount_ == 0) revert ZERO_AMOUNT();
        Parsed memory p = _parse(txData_, weth9_);
        uint256 oldTotal = p.f.totalIn;
        if (newAmount_ == oldTotal) return txData_;

        uint256 assigned;
        for (uint256 i; i <= p.lastSwapIdx; ++i) {
            bytes4 sel = _selector(p.calls[i]);
            if (sel == EXACT_INPUT_SINGLE_SELECTOR) {
                ISwapRouter02.ExactInputSingleParams memory s =
                    abi.decode(_body(p.calls[i]), (ISwapRouter02.ExactInputSingleParams));
                (s.amountIn, s.amountOutMinimum, assigned) =
                    _scaledLeg(s.amountIn, s.amountOutMinimum, i == p.lastSwapIdx, newAmount_, oldTotal, assigned);
                p.calls[i] = abi.encodeWithSelector(EXACT_INPUT_SINGLE_SELECTOR, s);
            } else {
                // _parse guarantees this is an exactInput leg
                ISwapRouter02.ExactInputParams memory s =
                    abi.decode(_body(p.calls[i]), (ISwapRouter02.ExactInputParams));
                (s.amountIn, s.amountOutMinimum, assigned) =
                    _scaledLeg(s.amountIn, s.amountOutMinimum, i == p.lastSwapIdx, newAmount_, oldTotal, assigned);
                p.calls[i] = abi.encodeWithSelector(EXACT_INPUT_SELECTOR, s);
            }
        }

        p.calls[p.tailIdx] = _rescaleTail(p.calls[p.tailIdx], p.f, newAmount_, oldTotal);
        return abi.encodeWithSelector(MULTICALL_SELECTOR, p.deadline, p.calls);
    }

    /// @dev Proportional leg amount; the last leg takes the remainder. Zero legs revert. The leg's minimum is
    ///      ceil-scaled by the leg's OWN input ratio, not the total ratio: floor rounding and the remainder make
    ///      the two differ, and a minimum scaled by the larger ratio can be unreachable for a leg that was scaled
    ///      by the smaller one (PR review P2).
    function _scaledLeg(
        uint256 original,
        uint256 originalMin,
        bool isLast,
        uint256 newTotal,
        uint256 oldTotal,
        uint256 assigned
    )
        private
        pure
        returns (uint256 scaled, uint256 scaledMin, uint256 newAssigned)
    {
        scaled = isLast ? newTotal - assigned : Math.mulDiv(original, newTotal, oldTotal);
        if (scaled == 0) revert ZERO_LEG_AMOUNT();
        scaledMin = originalMin == 0 ? 0 : Math.mulDiv(originalMin, scaled, original, Math.Rounding.Ceil);
        newAssigned = assigned + scaled;
    }

    function _rescaleTail(
        bytes memory tail,
        Fields memory f,
        uint256 newTotal,
        uint256 oldTotal
    )
        private
        pure
        returns (bytes memory)
    {
        uint256 newMin = Math.mulDiv(f.tailMin, newTotal, oldTotal, Math.Rounding.Ceil);
        bytes4 sel = _selector(tail);
        if (sel == SWEEP_TOKEN_WITH_FEE_SELECTOR) {
            return abi.encodeWithSelector(sel, f.tokenOut, newMin, f.recipient, f.feeBips, f.feeRecipient);
        }
        if (sel == SWEEP_TOKEN_SELECTOR) return abi.encodeWithSelector(sel, f.tokenOut, newMin, f.recipient);
        if (sel == UNWRAP_WETH9_WITH_FEE_SELECTOR) {
            return abi.encodeWithSelector(sel, newMin, f.recipient, f.feeBips, f.feeRecipient);
        }
        return abi.encodeWithSelector(UNWRAP_WETH9_SELECTOR, newMin, f.recipient);
    }

    /// @dev Outer selector, ABI decode, then a SWAP -> TAIL -> REFUND walk over the allowlist
    function _parse(bytes memory txData_, address weth9_) private pure returns (Parsed memory p) {
        if (txData_.length < 4 + 64) revert TXDATA_TOO_SHORT();
        if (_selector(txData_) != MULTICALL_SELECTOR) revert INVALID_SELECTOR();
        (p.deadline, p.calls) = abi.decode(_body(txData_), (uint256, bytes[]));
        p.f.deadline = p.deadline;
        uint256 n = p.calls.length;
        if (n == 0) revert EMPTY_CALLS();

        Phase phase = Phase.SWAP;
        for (uint256 i; i < n; ++i) {
            bytes memory c = p.calls[i];
            if (c.length < 4) revert TXDATA_TOO_SHORT();
            bytes4 sel = _selector(c);

            if (sel == EXACT_INPUT_SINGLE_SELECTOR || sel == EXACT_INPUT_SELECTOR) {
                if (phase != Phase.SWAP) revert INVALID_LEG_ORDER();
                _swapLeg(p.f, c, sel);
                p.lastSwapIdx = i;
            } else if (
                sel == SWEEP_TOKEN_SELECTOR || sel == SWEEP_TOKEN_WITH_FEE_SELECTOR || sel == UNWRAP_WETH9_SELECTOR
                    || sel == UNWRAP_WETH9_WITH_FEE_SELECTOR
            ) {
                if (phase != Phase.SWAP) revert DUPLICATE_TAIL();
                if (p.f.swapLegs == 0) revert INVALID_LEG_ORDER(); // a tail with no swap legs before it
                _tail(p.f, c, sel, weth9_);
                p.tailIdx = i;
                phase = Phase.TAIL;
            } else if (sel == REFUND_ETH_SELECTOR) {
                if (phase != Phase.TAIL || i != n - 1) revert INVALID_LEG_ORDER();
                p.f.hasRefund = true;
                phase = Phase.REFUND;
            } else {
                revert UNSUPPORTED_LEG_SELECTOR(sel);
            }
        }
        if (phase == Phase.SWAP) revert MISSING_TAIL();
    }

    function _swapLeg(Fields memory f, bytes memory c, bytes4 sel) private pure {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 amountIn;
        if (sel == EXACT_INPUT_SINGLE_SELECTOR) {
            ISwapRouter02.ExactInputSingleParams memory s = abi.decode(_body(c), (ISwapRouter02.ExactInputSingleParams));
            // a price limit lets a leg consume only part of its amountIn
            if (s.sqrtPriceLimitX96 != 0) revert INVALID_PRICE_LIMIT();
            (tokenIn, tokenOut, recipient, amountIn) = (s.tokenIn, s.tokenOut, s.recipient, s.amountIn);
        } else {
            ISwapRouter02.ExactInputParams memory s = abi.decode(_body(c), (ISwapRouter02.ExactInputParams));
            uint256 len = s.path.length;
            if (len < PATH_ADDR + PATH_HOP || (len - PATH_ADDR) % PATH_HOP != 0) revert INVALID_PATH();
            tokenIn = BytesLib.toAddress(s.path, 0);
            tokenOut = BytesLib.toAddress(s.path, len - PATH_ADDR);
            // intermediate hops may not revisit either endpoint (path rule, see header)
            for (uint256 off = PATH_HOP; off < len - PATH_ADDR; off += PATH_HOP) {
                address mid = BytesLib.toAddress(s.path, off);
                if (mid == tokenIn || mid == tokenOut) revert INVALID_PATH();
            }
            (recipient, amountIn) = (s.recipient, s.amountIn);
        }
        if (tokenIn == tokenOut) revert INVALID_PATH();
        if (recipient != ADDRESS_THIS) revert INVALID_LEG_RECIPIENT();
        if (amountIn == 0) revert ZERO_LEG_AMOUNT();
        if (f.swapLegs == 0) {
            f.tokenIn = tokenIn;
            f.tokenOut = tokenOut;
        } else if (tokenIn != f.tokenIn || tokenOut != f.tokenOut) {
            revert LEG_TOKEN_MISMATCH();
        }
        f.totalIn += amountIn;
        ++f.swapLegs;
    }

    function _tail(Fields memory f, bytes memory c, bytes4 sel, address weth9_) private pure {
        bytes memory body = _body(c);
        if (sel == SWEEP_TOKEN_WITH_FEE_SELECTOR) {
            address token;
            (token, f.tailMin, f.recipient, f.feeBips, f.feeRecipient) =
                abi.decode(body, (address, uint256, address, uint256, address));
            if (token != f.tokenOut) revert TAIL_TOKEN_MISMATCH();
            if (f.feeBips > MAX_TAIL_FEE_BIPS) revert FEE_TOO_HIGH();
        } else if (sel == SWEEP_TOKEN_SELECTOR) {
            address token;
            (token, f.tailMin, f.recipient) = abi.decode(body, (address, uint256, address));
            if (token != f.tokenOut) revert TAIL_TOKEN_MISMATCH();
        } else if (sel == UNWRAP_WETH9_WITH_FEE_SELECTOR) {
            (f.tailMin, f.recipient, f.feeBips, f.feeRecipient) = abi.decode(body, (uint256, address, uint256, address));
            if (weth9_ != address(0) && f.tokenOut != weth9_) revert TAIL_TOKEN_MISMATCH();
            if (f.feeBips > MAX_TAIL_FEE_BIPS) revert FEE_TOO_HIGH();
            f.nativeOut = true;
        } else {
            (f.tailMin, f.recipient) = abi.decode(body, (uint256, address));
            if (weth9_ != address(0) && f.tokenOut != weth9_) revert TAIL_TOKEN_MISMATCH();
            f.nativeOut = true;
        }
        if (f.recipient == address(0) || f.recipient == MSG_SENDER || f.recipient == ADDRESS_THIS) {
            revert INVALID_TAIL_RECIPIENT();
        }
    }

    function _selector(bytes memory data_) private pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            selector := mload(add(data_, 0x20))
        }
    }

    function _body(bytes memory data_) private pure returns (bytes memory) {
        return BytesLib.slice(data_, 4, data_.length - 4);
    }
}
