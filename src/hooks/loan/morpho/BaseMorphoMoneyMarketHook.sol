// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IMorphoStaticTyping, MarketParams } from "../../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../../vendor/morpho/MarketParamsLib.sol";

// Superform
import { BaseMorphoLoanHook } from "./BaseMorphoLoanHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";
import { ISuperHook } from "../../../interfaces/ISuperHook.sol";

/// @title BaseMorphoMoneyMarketHook
/// @author Superform Labs
/// @notice Base for the Morpho Blue idle lend / redeem hooks (MorphoLendHook, MorphoWithdrawHook)
///         — the MONEY_MARKET, vault-main-accounted side of the Morpho family
/// @dev Inherited ONLY by the two lender leaves. The shared loan bases (BaseLoanHook,
///      BaseMorphoLoanHook) fix `HookType.NONACCOUNTING` for the borrower hooks and must not
///      change. `hookType` is plain storage on BaseHook, so this base reassigns it after
///      construction — INFLOW for lend, OUTFLOW for redeem — with zero impact on any sibling.
///
///      HEADER IDENTITY: inherited unchanged from BaseMorphoLoanHook — offset 32 is the registry
///      MARKET KEY of the body MarketParams, pinned by `_requireHeaderIsMarketKey`, and the Morpho
///      Blue singleton is the `morpho` immutable. What is SPECIFIC to the money-market side is that
///      the key is also load-bearing on-chain: SuperExecutorBase posts INFLOW / OUTFLOW to
///      SuperLedger keyed by the header yield source, and MorphoBlueYieldSourceOracle resolves that
///      same address through MorphoBlueMarketRegistry. Keying by the singleton would collapse every
///      market's cost basis and price-per-share onto one address and the oracle could not resolve
///      it at all.
///
///      FAIL-CLOSED ALLOWLIST: the oracle resolves the market key through
///      `MorphoBlueMarketRegistry.getMarketInfo`, which reverts `MARKET_NOT_REGISTERED` for an
///      unregistered market. A lend/withdraw into an unregistered market therefore reverts at
///      accounting; markets must be registered (and their IRM approved) before being enabled.
///      SECURITY INVARIANT: all Morpho calls use empty callback data ("").
abstract contract BaseMorphoMoneyMarketHook is BaseMorphoLoanHook {
    using MarketParamsLib for MarketParams;
    using HookDataDecoder for bytes;

    /*//////////////////////////////////////////////////////////////
                               ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the header yield-source oracle id (offset 0) is zero
    error ORACLE_ID_NOT_VALID();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param morpho_ Address of the Morpho Blue singleton (call target)
    /// @param hookType_ INFLOW (lend) or OUTFLOW (redeem)
    constructor(address morpho_, ISuperHook.HookType hookType_) BaseMorphoLoanHook(morpho_, HookSubTypes.LOAN) {
        // BaseLoanHook fixes NONACCOUNTING for the shared loan family; the money-market lend side
        // is vault-main accounting, so reassign the (storage) type here without touching any base.
        hookType = hookType_;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @dev The account's current Morpho supply shares in a market, read from the singleton
    /// @param marketParams The body MarketParams
    /// @param account The account whose position is read
    /// @return supplyShares The account's supply shares
    function _supplyShares(
        MarketParams memory marketParams,
        address account
    )
        internal
        view
        returns (uint256 supplyShares)
    {
        (supplyShares,,) = IMorphoStaticTyping(morpho).position(marketParams.id(), account);
    }

    /// @dev Rejects a zero header oracle id (offset 0). The executor would also revert
    ///      (`MANAGER_NOT_SET`), but this gives an early, specific revert during simulation.
    /// @param data The hook data
    function _requireOracleId(bytes memory data) internal pure {
        if (data.extractYieldSourceOracleId() == bytes32(0)) revert ORACLE_ID_NOT_VALID();
    }
}
