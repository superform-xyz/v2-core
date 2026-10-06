// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4MarketRegistry
/// @author Superform Labs
/// @notice The minimal `AaveV4ReserveRegistryV2` surface the Aave V4 idle hooks consume: resolving a market
///         key back to its two reserve legs.
/// @dev WHY THIS INTERFACE EXISTS AT ALL (SUP-21263). A market key is
///      `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))` truncated to an
///      address — a one-way commitment. Once the idle body carries a single `targetReserveId` that may be
///      EITHER leg of the market, "is this id one of the market's legs?" is no longer derivable from
///      calldata, so the hooks must read the registration. That is the whole dependency: two view calls, no
///      state, no privileged surface.
/// @dev `AaveV4ReserveRegistryV2` deliberately does NOT inherit this interface. It is live and seeded at one
///      address per environment across every supported chain, and its constructor argument is also
///      `AaveV4ReserveOracle`'s — editing it would move both CREATE2 addresses. Structural parity with the
///      deployed registry is therefore pinned by test (`test_RegistryInterfaceParity`) rather than by the
///      compiler. Keep the signatures and the error name below byte-identical to the registry's.
interface IAaveV4MarketRegistry {
    /// @notice Thrown when the key is not a registered market
    /// @dev Declared here so a hook reverting on an unregistered header surfaces the SAME selector the
    ///      registry raises — identical name and empty argument list, therefore identical selector.
    error MARKET_NOT_REGISTERED();

    /// @notice The two reserve legs and underlyings bound to a registered market key
    /// @param marketKey The market key, as carried at idle-header offset 32
    /// @return spoke The Aave V4 spoke holding both reserves
    /// @return supplyReserveId The market's COLLATERAL leg
    /// @return borrowReserveId The market's LOAN leg
    /// @return collateralToken The collateral reserve's underlying
    /// @return loanToken The loan reserve's underlying
    function getMarketInfo(address marketKey)
        external
        view
        returns (
            address spoke,
            uint256 supplyReserveId,
            uint256 borrowReserveId,
            address collateralToken,
            address loanToken
        );

    /// @notice Whether the key is a registered market
    /// @dev Non-reverting probe, unlike `getMarketInfo`
    /// @param marketKey The key to test
    /// @return True when the market is registered
    function isMarketRegistered(address marketKey) external view returns (bool);
}
