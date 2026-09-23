// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title ITokenMinterV2
/// @author Superform Labs
/// @notice Minimal interface for Circle's CCTP V2 TokenMinter contract
/// @dev See https://developers.circle.com/cctp/evm-smart-contracts and circlefin/evm-cctp-contracts
///      `src/v2/TokenMinterV2.sol`. Only the lookup the CCTPAdapter needs is declared; the full contract
///      also owns burn limits and the local-token registry admin.
interface ITokenMinterV2 {
    /// @notice Resolves the local token that a burn of `remoteToken` on `remoteDomain` mints on this chain
    /// @param remoteDomain CCTP domain ID of the source chain (NOT EVM chain ID)
    /// @param remoteToken Source-chain token address, left-padded to bytes32 (BurnMessageV2.burnToken)
    /// @return Local token address, or address(0) when the pair is not registered
    function getLocalToken(uint32 remoteDomain, bytes32 remoteToken) external view returns (address);
}
