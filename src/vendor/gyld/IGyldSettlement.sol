// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IGyldSettlement
/// @author Superform Labs
/// @notice Minimal interface for Gyld's bond settlement contract.
/// @dev ASSUMED ABI — NOT CONFIRMED WITH GYLD. There is no Gyld code in this repository, and Gyld's public
///      material describes prelaunch capabilities rather than a verified Katana deployment. Every member below
///      is a confirmation item. `ApproveAndTradeGyldBondHook` therefore treats the venue calldata as OPAQUE and
///      validates the OUTCOME (balances, allowance) rather than decoding this struct, exactly as
///      `ApproveAndSwapBinanceHook` does for an upgradeable router. If and when Gyld confirms a stable,
///      non-upgradeable settlement ABI, the hook may be tightened to decode and cross-check these fields.
/// @dev The venue MUST provide the following for the integration to be safe. These are not optional:
///      R1 SINGLE-USE QUOTE IDS. A replayed fill must revert at the venue. SuperVault leaves carry no amount
///         and no nonce and are reusable by design, so there is NO on-chain replay protection on that path.
///         Replay protection is a venue guarantee, not a hook feature — the same posture the Pendle hooks take
///         toward the Pendle Router's nonce manager.
///      R2 TAKER BINDING. The venue must pull from and deliver to `msg.sender`, or validate `taker == msg.sender`.
///         "The strategy is the payer and recipient, never the operator or hook" is only enforceable if this holds.
///      R3 EXPIRY INSIDE THE SIGNED PAYLOAD, not a caller-chosen argument.
///      R4 PAIR, AMOUNT AND MIN-OUT INSIDE THE SIGNED PAYLOAD, so the hook's header checks cross-check a
///         signature rather than standing alone.
///      R5 ATOMICITY. A failed fill must revert, never partially transfer.
///      R6 A READABLE PAUSE FLAG.
///      R7 A STABLE, NON-UPGRADEABLE ABI, otherwise typed decoding is unsafe.
interface IGyldSettlement {
    /// @notice A venue-signed executable quote.
    /// @param quoteId Single-use identifier (R1)
    /// @param taker The account the fill debits and credits (R2)
    /// @param bondToken The bond being bought or sold
    /// @param cashToken The cash denomination of the trade
    /// @param cashAmount Cash leg size, in `cashToken` units
    /// @param bondAmount Bond leg size, in `bondToken` units
    /// @param isBuy True when the taker pays cash and receives bonds
    /// @param expiry Quote expiry, inside the signed payload (R3)
    struct Quote {
        bytes32 quoteId;
        address taker;
        address bondToken;
        address cashToken;
        uint256 cashAmount;
        uint256 bondAmount;
        bool isBuy;
        uint256 expiry;
    }

    /// @notice Executes a signed quote atomically (R5)
    function fill(Quote calldata quote, bytes calldata signature) external;

    /// @notice Whether a quote id has already been consumed (R1)
    function quoteUsed(bytes32 quoteId) external view returns (bool);

    /// @notice Whether the venue is paused (R6)
    function paused() external view returns (bool);
}
