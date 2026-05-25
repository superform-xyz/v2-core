// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ITokenMessengerV2
/// @notice Interface for Circle's CCTP V2 TokenMessenger contract
/// @dev See https://developers.circle.com/cctp/evm-smart-contracts
interface ITokenMessengerV2 {
    /// @notice Burns tokens on source chain and mints on destination chain with hook data
    /// @param amount Amount of tokens to burn
    /// @param destinationDomain CCTP domain ID for destination chain (NOT EVM chain ID)
    /// @param mintRecipient Recipient address on destination chain (left-padded bytes32)
    /// @param burnToken Token to burn (USDC address on source chain)
    /// @param destinationCaller Restricts who can call receiveMessage on destination (bytes32(0) = anyone)
    /// @param maxFee Maximum fee deducted from transfer amount
    /// @param minFinalityThreshold Minimum finality level (>= 2000 = standard, < 2000 = fast)
    /// @param hookData Hook data for composable cross-chain actions on destination
    /// @return Raw CCTP message bytes
    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes memory hookData
    ) external returns (bytes memory);
}
