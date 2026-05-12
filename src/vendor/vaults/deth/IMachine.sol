// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IMachine
/// @notice Minimal interface for Dialectic's Machine vault
/// @dev Machine is a modified ERC-4626 vault with separate share and accounting tokens.
///      Deployed as a BeaconProxy at 0x0447D0aD7FD6a3409B48Ecbb9DDB075C1e11D735.
interface IMachine {
    /// @notice Returns the share token address (DETH)
    /// @return The address of the DETH share token
    function shareToken() external view returns (address);

    /// @notice Returns the accounting token address (WETH)
    /// @return The address of the WETH accounting token
    function accountingToken() external view returns (address);
}
