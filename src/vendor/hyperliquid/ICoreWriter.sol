// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ICoreWriter
/// @author Superform Labs
/// @notice Minimal interface for Hyperliquid's CoreWriter system contract on HyperEVM
/// @dev Deployed at 0x3333333333333333333333333333333333333333 on chain 999 (and 998 testnet).
/// @dev CRITICAL: CoreWriter performs no validation and has no revert path. Its entire runtime is a
///      fixed gas-burn loop, one LOG2, and a return. A malformed payload, an unknown action id, and
///      an empty payload all execute successfully and silently do nothing on HyperCore. Every
///      guarantee about what actually happens comes from the caller's encoding being correct.
interface ICoreWriter {
    /// @notice Emitted for every accepted raw action
    /// @param user The HyperCore actor, which is msg.sender of sendRawAction
    /// @param data The raw versioned action payload
    event RawAction(address indexed user, bytes data);

    /// @notice Forwards a versioned action payload to HyperCore
    /// @param data abi.encodePacked(bytes1 version, bytes3 actionId, abi.encode(args))
    function sendRawAction(bytes calldata data) external;
}
