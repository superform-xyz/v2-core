// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IGenericFactory
/// @notice Minimal interface for Euler's GenericFactory (the canonical EVK eVaultFactory)
/// @dev Only includes the function needed by Superform hooks. The canonical factory is
///      GPL-2.0-licensed; this minimal interface avoids license conflict.
///      One canonical factory is deployed per chain (published in euler-xyz/euler-interfaces);
///      every genuine EVK vault is one of its beacon proxies.
interface IGenericFactory {
    /// @notice Whether an address is a proxy (vault) deployed by this factory
    /// @param proxy The address to check
    /// @return True if the address was deployed by this factory
    function isProxy(address proxy) external view returns (bool);
}
