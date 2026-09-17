// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { Id, IMorphoStaticTyping, MarketParams } from "../../../vendor/morpho/IMorpho.sol";
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
///      HEADER IDENTITY (differs from the LOAN hooks). SuperExecutorBase posts INFLOW / OUTFLOW to
///      SuperLedger keyed by the header yield source (offset 32), and MorphoBlueYieldSourceOracle
///      resolves that same address through MorphoBlueMarketRegistry. Morpho Blue is ONE singleton
///      hosting MANY markets, so the singleton cannot be the accounting key: every market's cost
///      basis and price-per-share would collapse onto one address and the oracle could not resolve
///      it. Offset 32 therefore carries the REGISTRY MARKET KEY — `MarketParams.id()` truncated to
///      an address, identical to `MorphoBlueMarketRegistry.computeMarketKey` — of the body
///      MarketParams. It is derived on-chain from the body and asserted against the header on every
///      build / preExecute path (MARKET_KEY_MISMATCH), so a header cannot name a different market
///      than the one it acts on. The Morpho Blue singleton is the `morpho` immutable: the sole call
///      target and approve spender. inspect() packs the singleton plus the MarketParams filter, the
///      same 6-field identity as the rest of the family.
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

    /// @notice Thrown when the header yield source (offset 32) is not the registry market key of
    ///         the body MarketParams
    error MARKET_KEY_MISMATCH();

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

    /// @dev The registry market key for a market: the Morpho market id truncated to an address.
    ///      Must stay identical to `MorphoBlueMarketRegistry.computeMarketKey`.
    /// @param marketParams The body MarketParams (loan, collateral, oracle, irm, lltv)
    /// @return The address SuperLedger and the Morpho yield-source oracle are keyed by
    function _marketKey(MarketParams memory marketParams) internal pure returns (address) {
        return address(uint160(uint256(Id.unwrap(marketParams.id()))));
    }

    /// @dev Primary header pin for the money-market hooks: the header yield source (offset 32) —
    ///      the address the executor posts accounting against — must equal the market key derived
    ///      from the body MarketParams. Runs on every build and preExecute path.
    /// @param headerKey The header-derived yield source (offset 32)
    /// @param marketParams The body MarketParams
    function _requireHeaderIsMarketKey(address headerKey, MarketParams memory marketParams) internal pure {
        if (headerKey != _marketKey(marketParams)) revert MARKET_KEY_MISMATCH();
    }

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
