// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title SwapCalldataLayout
/// @author Superform Labs
/// @notice Shared byte-offset constants for the Layer 1 swap calldata standard
/// @dev Imported by all SWAP-subtype hooks; eliminates magic numbers across the hook family
library SwapCalldataLayout {
    // ─── Layer 0: zero-filled strategy header ───────────────────────────────
    uint256 internal constant HEADER_SIZE = 52;

    // ─── Layer 1: standard swap tail — fixed absolute offsets ───────────────
    /// @dev address inputToken (20 bytes)
    uint256 internal constant INPUT_TOKEN_OFFSET = 52;

    /// @dev address outputToken (20 bytes)
    uint256 internal constant OUTPUT_TOKEN_OFFSET = 72;

    /// @dev uint256 inputAmount (32 bytes) — the OMS-controlled sizing amount
    uint256 internal constant INPUT_AMOUNT_OFFSET = 92;

    /// @dev uint256 outputQuote (32 bytes) — aggregator quote; equals outputMin for AMM hooks
    uint256 internal constant OUTPUT_QUOTE_OFFSET = 124;

    /// @dev uint256 outputMin (32 bytes) — minimum acceptable output (slippage guard)
    uint256 internal constant OUTPUT_MIN_OFFSET = 156;

    /// @dev bool usePrevHookAmount (1 byte)
    uint256 internal constant USE_PREV_HOOK_OFFSET = 188;

    /// @dev uint256 payloadLength (32 bytes) — byte length of the Layer 2 payload that follows
    uint256 internal constant PAYLOAD_LENGTH_OFFSET = 189;

    /// @dev bytes payload start — protocol-specific Layer 2 data (variable length)
    uint256 internal constant PAYLOAD_DATA_OFFSET = 221;

    // ─── Derived constants ───────────────────────────────────────────────────

    /// @notice Minimum valid data length for any swap hook (Layer 0 + full Layer 1, no payload)
    uint256 internal constant MIN_DATA_LENGTH = 221;

    /// @notice Alias kept for compatibility with ISuperHookInflowOutflow / ISuperHookOutflow callers
    uint256 internal constant AMOUNT_POSITION = INPUT_AMOUNT_OFFSET; // = 92
}
