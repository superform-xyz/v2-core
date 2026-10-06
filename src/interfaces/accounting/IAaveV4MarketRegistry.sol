// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

/// @title IAaveV4MarketRegistry
/// @author Superform Labs
/// @notice The minimal `AaveV4ReserveRegistryV2` surface the Aave V4 idle hooks resolve a market key
///         through.
/// @dev WHY THIS INTERFACE EXISTS AT ALL (SUP-21263). A market key is
///      `keccak256(abi.encode(spoke, supplyReserveId, borrowReserveId, MARKET_KEY_DOMAIN))` truncated to an
///      address — a one-way commitment. Once the idle body carries a single `targetReserveId` that may be
///      EITHER leg of the market, "is this id one of the market's legs?" is no longer derivable from
///      calldata, so the hooks must read the registration. That is the whole dependency: ONE view call
///      (`getMarketInfo`) per authenticating entry point, no state, no privileged surface.
///      `isMarketRegistered` is carried for the non-reverting probe that off-chain consumers and
///      `test_RegistryInterfaceParity` use; no hook calls it.
/// @dev `AaveV4ReserveRegistryV2` deliberately does NOT inherit this interface. It is live and seeded at one
///      address per environment across every supported chain, and its constructor argument is also
///      `AaveV4ReserveOracle`'s — editing it would move both CREATE2 addresses. Structural parity with the
///      deployed registry is therefore pinned by test (`test_RegistryInterfaceParity`) rather than by the
///      compiler. Keep the signatures and the error name below byte-identical to the registry's.
interface IAaveV4MarketRegistry {
    /// @notice Thrown by the REGISTRY when the key is not a registered market
    /// @dev THE HOOKS DO NOT RAISE THIS — they bubble it. `BaseAaveV4MoneyMarketHook` imports this
    ///      interface but does not inherit it, so this declaration is in no deployed hook ABI; the selector
    ///      a caller observes is the registry's own, propagated out of `getMarketInfo`.
    ///      It is declared anyway for ONE reason: because the registry deliberately does not inherit this
    ///      interface (inheriting would change its creation code and move its live CREATE2 address), the
    ///      compiler cannot check that the two agree. `test_RegistryInterfaceParity` pins the selector
    ///      against the registry's by name instead, and that test needs a named declaration to compare.
    ///      Note the sibling interfaces here — `IAaveV4MarketPosition`, `IAaveV4OwnerSnapshot` — document
    ///      this revert in prose and declare nothing, because they ARE inherited by the oracle.
    error MARKET_NOT_REGISTERED();

    /// @notice The two reserve legs and underlyings bound to a registered market key
    /// @dev REVERTS `MARKET_NOT_REGISTERED` for an unregistered key AND for a reserve key — the market and
    ///      reserve namespaces are separate mappings with no fallback in either direction, cross-guarded by
    ///      `KEY_NAMESPACE_COLLISION` on every write path. Fail-closed by construction: the returned legs
    ///      are always the unique preimage of `marketKey`, because the registry derives the key FROM the
    ///      legs it stores and has no setter that mutates them.
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
