// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import { MarketParams } from "./IMorpho.sol";

/// @title IMetaMorpho
/// @notice Minimal interface for MetaMorpho vault's reallocate function
struct MarketAllocation {
    MarketParams marketParams;
    uint256 assets;
}

interface IMetaMorpho {
    /// @notice Reallocates the vault's supply across Morpho Blue markets
    /// @dev The caller must be an allocator, curator, or owner of the vault
    /// @dev totalWithdrawn must equal totalSupplied (net-zero invariant)
    /// @param allocations Array of target allocations per market
    function reallocate(MarketAllocation[] calldata allocations) external;
}
