// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title ILayerZeroComposer
/// @notice Interface for contracts that receive composed LayerZero V2 messages
/// @dev See https://docs.layerzero.network/v2/developers/evm/composer/overview
interface ILayerZeroComposer {
    /// @notice Composes a LayerZero message from an OApp
    /// @param _from The address initiating the composition (destination OApp/pool, NOT the source chain sender)
    /// @param _guid The unique identifier for the corresponding LayerZero src/dst tx
    /// @param _message The composed message payload (OFTComposeMsgCodec-encoded)
    /// @param _executor The address of the executor for the composed message
    /// @param _extraData Additional arbitrary data passed by the executor
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable;
}
