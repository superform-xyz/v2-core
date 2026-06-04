// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.30;

/// @title ITokenMessaging
/// @notice Minimal interface for Stargate V2 TokenMessaging contract
/// @dev TokenMessaging maintains a bidirectional mapping between assetIds and Stargate pool addresses.
///      Only the TokenMessaging owner can register pools via setAssetId().
///      Used by StargateAdapter to verify that a compose sender (_from) is a legitimate Stargate pool.
interface ITokenMessaging {
    /// @notice Returns the assetId for a registered Stargate pool address
    /// @dev Returns 0 for unregistered addresses — only pools registered by the owner have non-zero assetIds
    /// @param stargateImpl The Stargate pool/OFT contract address to look up
    /// @return assetId The numeric asset identifier (0 if not registered)
    function assetIds(address stargateImpl) external view returns (uint16 assetId);
}
