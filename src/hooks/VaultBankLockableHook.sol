// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { HookDataDecoder } from "../libraries/HookDataDecoder.sol";

/// @title VaultBankLockableHook
/// @author Superform Labs
/// @notice Base implementation for all vault bank lockable hooks in the Superform system
abstract contract VaultBankLockableHook {
    using HookDataDecoder for bytes;

    /// @notice The vault bank address (if applicable) for cross-chain operations
    /// @dev Used primarily in bridge hooks to track source/destination vault banks
    address public transient vaultBank;

    /// @notice The destination chain ID for cross-chain operations
    /// @dev Used primarily in bridge hooks to track target chain
    uint256 public transient dstChainId;
}
