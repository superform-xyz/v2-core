// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IMessageTransmitterV2
/// @author Superform Labs
/// @notice Minimal interface for Circle's CCTP V2 MessageTransmitter on the destination chain.
/// @dev See https://developers.circle.com/cctp/evm-smart-contracts and
///      circlefin/evm-cctp-contracts `src/v2/MessageTransmitterV2.sol`.
interface IMessageTransmitterV2 {
    /// @notice Verifies a CCTP message + attestation, marks the nonce used, and routes the message
    ///         body to the header recipient's handler (which mints USDC to `mintRecipient`).
    /// @dev Reverts on an invalid attestation, a used nonce, or when the message's `destinationCaller`
    ///      is non-zero and does not equal `msg.sender`. Returns true on success.
    /// @param message The raw CCTP V2 message bytes
    /// @param attestation The concatenated attester signatures over keccak256(message)
    /// @return success True when the message was received and handled
    function receiveMessage(bytes calldata message, bytes calldata attestation) external returns (bool success);
}
