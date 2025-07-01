// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;


/// @title VaultBankLockableHook
/// @author Superform Labs
/// @notice Base implementation for all vault bank lockable hooks in the Superform system
abstract contract VaultBankLockableHook {
    /// @notice The vault bank address (if applicable) for cross-chain operations
    /// @dev Used primarily in bridge hooks to track source/destination vault banks
    address public transient vaultBank;
    
    /// @notice The destination chain ID for cross-chain operations
    /// @dev Used primarily in bridge hooks to track target chain
    uint256 public transient dstChainId;


    /// @notice Extracts the vault bank and destination chain ID
    /// @dev Used to retrieve lock details for cross-chain operations
    /// @return vaultBank The vault bank address
    /// @return dstChainId The destination chain ID
    function extractLockDetails() external view returns (address, uint256) {
        return (vaultBank, dstChainId);
    }
}