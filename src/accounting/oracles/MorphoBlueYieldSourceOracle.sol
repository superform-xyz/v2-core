// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// morpho vendor
import { IMorphoStaticTyping, MarketParams, Market, Id } from "../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../vendor/morpho/MarketParamsLib.sol";
import { SharesMathLib } from "../../vendor/morpho/SharesMathLib.sol";
import { MathLib } from "../../vendor/morpho/MathLib.sol";
import { IIrm } from "../../vendor/morpho/IIrm.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { MorphoBlueMarketRegistry } from "./MorphoBlueMarketRegistry.sol";
import { IMorphoMarketPosition } from "../../interfaces/accounting/IMorphoMarketPosition.sol";
import { IMorphoOwnerSnapshot } from "../../interfaces/accounting/IMorphoOwnerSnapshot.sol";

/// @title MorphoBlueYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Morpho Blue lending markets, plus a market/owner snapshot read API (SUP-21477).
/// @dev ACCOUNTING UNIT (scalar surface): the `IYieldSourceOracle` methods (PPS, TVL, asset conversions)
///      are denominated ONLY in the market's **loanToken** and track supply-side lender positions only.
///      That scalar surface does NOT report collateral value, equity NAV, USD prices, or the Morpho market
///      oracle's LTV price. Downstream consumers (SuperLedger, monitoring, fee calculations) receive
///      loanToken-denominated figures; compose a price feed on top for USD/collateral-denominated values.
///
///      SNAPSHOT API: the separate `IMorphoMarketPosition` / `IMorphoOwnerSnapshot` reads additionally
///      expose the owner's raw collateral (collateralToken units) and accrued debt (loanToken units,
///      rounded up) legs ALONGSIDE the lending leg, side by side and never netted, for caller-side pricing
///      and classification. These reads do not change the scalar surface's single-asset, supply-side contract.
///
/// @dev Reads market identity from a MorphoBlueMarketRegistry, then queries Morpho
///      on-chain state and replicates interest accrual in a view context to return
///      accurate (non-stale) share/asset conversions.
///      The `yieldSourceAddress` parameter in all methods is a market key derived from
///      the registry via `computeMarketKey` or returned by `registerMarket`.
///
///      IRM safety: The registry enforces that only whitelisted IRMs can be used in registered
///      markets, preventing rogue `borrowRateView` implementations from corrupting oracle PPS.
///
///      Elapsed cap: Interest accrual caps elapsed time to 365 days to prevent
///      `wTaylorCompounded` overflow on chains with extended downtime (e.g., sequencer outages).
///
///      Fee guard: Fee share accrual is skipped when `feeAmount >= totalSupplyAssets` to prevent
///      arithmetic underflow in pathological market configurations.
contract MorphoBlueYieldSourceOracle is AbstractYieldSourceOracle, IMorphoMarketPosition, IMorphoOwnerSnapshot {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is supplied where one is not permitted
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Accrued market state after replicating Morpho's interest logic. Supply fields drive every
    ///      scalar lender read; the borrow fields exist so the snapshot's Debt leg accrues over the SAME
    ///      capped `elapsed` as the supply side (one pass, one bound) instead of a second uncapped helper.
    struct AccruedState {
        uint256 totalSupplyAssets;
        uint256 totalSupplyShares;
        uint256 totalBorrowAssets;
        uint256 totalBorrowShares;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Immutable registry for Morpho Blue market params
    MorphoBlueMarketRegistry public immutable REGISTRY;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    /// @param registry_ Address of the MorphoBlueMarketRegistry; must be non-zero
    constructor(
        address superLedgerConfiguration_,
        address registry_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (registry_ == address(0)) revert ZERO_ADDRESS();
        REGISTRY = MorphoBlueMarketRegistry(registry_);
    }

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Morpho Blue supply shares carry a virtual offset of VIRTUAL_SHARES = 1e6
    ///      (SharesMathLib.sol), so shares effectively have `loanDecimals + 6` decimals
    ///      of precision. Returning `loanDecimals + 6` here matches MetaMorpho's
    ///      DECIMALS_OFFSET philosophy and ensures getPricePerShare() has enough
    ///      resolution for low-decimal tokens (e.g. USDC with 6 decimals).
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        (MarketParams memory mp,) = REGISTRY.getMarketInfo(yieldSourceAddress);
        return IERC20Metadata(mp.loanToken).decimals() + 6;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        (AccruedState memory s,) = _getAccruedMarketState(yieldSourceAddress);
        return assetsIn.toSharesDown(s.totalSupplyAssets, s.totalSupplyShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getWithdrawalShareOutput(
        address yieldSourceAddress,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        (AccruedState memory s,) = _getAccruedMarketState(yieldSourceAddress);
        return assetsIn.toSharesUp(s.totalSupplyAssets, s.totalSupplyShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getAssetOutput(
        address yieldSourceAddress,
        address,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256)
    {
        (AccruedState memory s,) = _getAccruedMarketState(yieldSourceAddress);
        return sharesIn.toAssetsDown(s.totalSupplyAssets, s.totalSupplyShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Prices `10^(loanDecimals + 6)` shares (one "full" share unit accounting for
    ///      VIRTUAL_SHARES = 1e6) to match the `decimals()` return value. The cast to
    ///      uint256 before `+ 6` prevents intermediate uint8 overflow in the exponent.
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        (AccruedState memory s, MarketParams memory mp) = _getAccruedMarketState(yieldSourceAddress);
        uint8 dec = IERC20Metadata(mp.loanToken).decimals();
        return (10 ** (uint256(dec) + 6)).toAssetsDown(s.totalSupplyAssets, s.totalSupplyShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getBalanceOfOwner(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        (MarketParams memory mp, address morpho) = REGISTRY.getMarketInfo(yieldSourceAddress);
        Id id = mp.id();
        (uint256 supplyShares,,) = IMorphoStaticTyping(morpho).position(id, ownerOfShares);
        return supplyShares;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVLByOwnerOfShares(
        address yieldSourceAddress,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256)
    {
        uint256 shares = getBalanceOfOwner(yieldSourceAddress, ownerOfShares);
        if (shares == 0) return 0;
        (AccruedState memory s,) = _getAccruedMarketState(yieldSourceAddress);
        return shares.toAssetsDown(s.totalSupplyAssets, s.totalSupplyShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        (AccruedState memory s,) = _getAccruedMarketState(yieldSourceAddress);
        return s.totalSupplyAssets;
    }

    /*//////////////////////////////////////////////////////////////
                    MARKET / OWNER SNAPSHOT (SUP-21477)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IMorphoMarketPosition
    function getMarketPosition(
        address marketKey,
        address owner
    )
        external
        view
        returns (MarketPosition memory position)
    {
        if (owner == address(0)) revert ZERO_ADDRESS();
        position = _marketPosition(marketKey, owner);
    }

    /// @inheritdoc IMorphoOwnerSnapshot
    function getOwnerSnapshot(
        address owner,
        address[] calldata marketKeys
    )
        external
        view
        returns (MarketBinding[] memory markets, OwnerPosition[] memory positions)
    {
        if (owner == address(0)) revert ZERO_ADDRESS();

        uint256 n = marketKeys.length;
        markets = new MarketBinding[](n);
        // Up to three legs per unique market (Lending, Debt, and Collateral when a collateral token exists).
        positions = new OwnerPosition[](n * 3);

        uint256 mCount;
        uint256 pCount;

        for (uint256 i; i < n; ++i) {
            address key = marketKeys[i];
            // Collapse literal duplicate keys: isolation means there is nothing else to de-duplicate.
            if (_hasMarket(markets, mCount, key)) continue;

            MarketPosition memory p = _marketPosition(key, owner);

            markets[mCount++] =
                MarketBinding(key, p.morpho, p.marketId, p.loanToken, p.collateralToken);

            // Lending and Debt legs (loanToken) are always emitted, zero balances included, so the caller
            // sees a stable per-market shape and a zero-lending borrower still surfaces its debt.
            positions[pCount++] = OwnerPosition(
                key, p.morpho, p.marketId, Side.Lending, p.loanToken, p.loanDecimals, p.suppliedAssets, p.supplyShares
            );
            positions[pCount++] = OwnerPosition(
                key, p.morpho, p.marketId, Side.Debt, p.loanToken, p.loanDecimals, p.debtAssets, p.borrowShares
            );

            // Collateral leg only when the market has a collateral token. A lending-only market cannot
            // denominate collateral, so it is omitted rather than reported as a zero in an undefined token.
            if (p.collateralToken != address(0)) {
                positions[pCount++] = OwnerPosition(
                    key,
                    p.morpho,
                    p.marketId,
                    Side.Collateral,
                    p.collateralToken,
                    p.collateralDecimals,
                    p.collateral,
                    0
                );
            }
        }

        // Truncate both arrays to what was actually populated (duplicates and lending-only markets leave slack).
        assembly ("memory-safe") {
            mstore(markets, mCount)
            mstore(positions, pCount)
        }
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Resolve one registered market key into all three raw legs for `owner`
    /// @dev Reverts `MARKET_NOT_REGISTERED` via the registry for an unregistered key — no fallback, no zero
    ///      substitution. The three legs come from one `position(id, owner)` read; supply is interest-accrued
    ///      and rounded down (asset), debt is accrued and rounded up (liability), collateral is raw. Zero
    ///      supply shares never suppress collateral or debt. Assumes `owner != address(0)` (checked by the
    ///      external entrypoints).
    function _marketPosition(address marketKey, address owner) private view returns (MarketPosition memory position) {
        (MarketParams memory mp, address morpho) = REGISTRY.getMarketInfo(marketKey);
        Id id = mp.id();

        (uint256 supplyShares, uint128 borrowShares, uint128 collateral) =
            IMorphoStaticTyping(morpho).position(id, owner);

        position.morpho = morpho;
        position.marketId = Id.unwrap(id);
        position.loanToken = mp.loanToken;
        position.collateralToken = mp.collateralToken;
        position.loanDecimals = IERC20Metadata(mp.loanToken).decimals();
        position.collateralDecimals =
            mp.collateralToken == address(0) ? 0 : IERC20Metadata(mp.collateralToken).decimals();
        position.supplyShares = supplyShares;
        position.borrowShares = uint256(borrowShares);
        position.collateral = uint256(collateral);

        // One capped accrual pass drives BOTH legs: supply shares convert down (conservative asset), borrow
        // shares convert up (conservative liability). Reusing `_accrue` (not the uncapped
        // MorphoBalancesLib.expectedBorrowBalances) keeps the Debt leg on the same 365-day `elapsed` cap and
        // irm==0 early-return as the supply side and as MorphoBlueDebtOracle, and avoids a second market() read.
        AccruedState memory s = _accrue(mp, morpho);
        position.suppliedAssets = supplyShares.toAssetsDown(s.totalSupplyAssets, s.totalSupplyShares);
        position.debtAssets = position.borrowShares.toAssetsUp(s.totalBorrowAssets, s.totalBorrowShares);
    }

    /// @dev Linear scan over the bindings populated so far — market sets are small and this mirrors the
    ///      Aave snapshot's de-duplication. Returns true if `marketKey` is already bound.
    function _hasMarket(
        MarketBinding[] memory markets,
        uint256 count,
        address marketKey
    )
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < count; ++i) {
            if (markets[i].marketKey == marketKey) return true;
        }
        return false;
    }

    /// @notice Reads on-chain Morpho state and accrues interest in a view context
    /// @dev Matches MorphoBalancesLib.expectedMarketBalances. Uses inner scopes to avoid stack-too-deep.
    ///
    ///      Elapsed cap: `elapsed` is capped to 365 days before calling `wTaylorCompounded` to prevent
    ///      overflow when a chain has been halted or the market has not been touched for a long time.
    ///
    ///      Fee guard: fee share accrual is skipped when `feeAmount >= totalSupplyAssets` to prevent
    ///      underflow; this only occurs in pathological markets (fee near 100% with extreme borrow rate).
    ///
    ///      totalBorrowShares: the actual on-chain value is passed to `borrowRateView` for IRM
    ///      correctness. The canonical AdaptiveCurveIrm ignores this field, but custom IRMs may use it.
    ///
    ///      The `mp` return value is provided to callers that need market params (e.g., `getPricePerShare`
    ///      for decimals) to avoid a redundant second registry lookup.
    /// @param yieldSourceAddress The market key registered in MorphoBlueMarketRegistry
    /// @return s The accrued market state (supply assets and shares after interest)
    /// @return mp The MarketParams for this market
    function _getAccruedMarketState(address yieldSourceAddress)
        internal
        view
        returns (AccruedState memory s, MarketParams memory mp)
    {
        address morpho;
        (mp, morpho) = REGISTRY.getMarketInfo(yieldSourceAddress);
        s = _accrue(mp, morpho);
    }

    /// @notice Accrue a market's supply state to `block.timestamp` from already-resolved params
    /// @dev Body of `_getAccruedMarketState` split out so the snapshot reads can reuse it without a second
    ///      `getMarketInfo` lookup. Semantics are identical to the single-key path.
    /// @param mp The market params (already resolved from the registry)
    /// @param morpho The Morpho Blue singleton for this market
    /// @return s The accrued supply state (assets and shares after interest)
    function _accrue(MarketParams memory mp, address morpho) internal view returns (AccruedState memory s) {
        uint128 lastUpdate;
        uint128 fee;

        // Scope: read stale market state, then drop raw uint128 locals immediately
        {
            Id id = mp.id();
            (
                uint128 _totalSupplyAssets,
                uint128 _totalSupplyShares,
                uint128 _totalBorrowAssets,
                uint128 _totalBorrowShares,
                uint128 _lastUpdate,
                uint128 _fee
            ) = IMorphoStaticTyping(morpho).market(id);

            s.totalSupplyAssets = _totalSupplyAssets;
            s.totalSupplyShares = _totalSupplyShares;
            s.totalBorrowAssets = _totalBorrowAssets;
            s.totalBorrowShares = _totalBorrowShares;
            lastUpdate = _lastUpdate;
            fee = _fee;
        }

        // Replicate Morpho's _accrueInterest in a view context (matches MorphoBalancesLib.expectedMarketBalances)
        uint256 elapsed = block.timestamp - lastUpdate;
        if (elapsed > 365 days) elapsed = 365 days;
        if (elapsed > 0 && s.totalBorrowAssets > 0 && mp.irm != address(0)) {
            uint256 interest;

            // Scope: build Market struct and compute interest, then drop mkt and borrowRate
            {
                Market memory mkt = Market({
                    totalSupplyAssets: uint128(s.totalSupplyAssets),
                    totalSupplyShares: uint128(s.totalSupplyShares),
                    totalBorrowAssets: uint128(s.totalBorrowAssets),
                    totalBorrowShares: uint128(s.totalBorrowShares),
                    lastUpdate: lastUpdate,
                    fee: fee
                });
                uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt);
                interest = s.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
            }

            // Morpho's _accrueInterest adds the same interest to BOTH sides; totalBorrowShares is unchanged.
            // Accruing the Debt leg here (rather than via the uncapped MorphoBalancesLib.expectedBorrowBalances)
            // keeps it on the same 365-day-capped `elapsed` as the supply side and identical to MorphoBlueDebtOracle.
            s.totalSupplyAssets += interest;
            s.totalBorrowAssets += interest;

            if (fee > 0) {
                uint256 feeAmount = interest.wMulDown(fee);
                if (s.totalSupplyAssets >= feeAmount) {
                    uint256 feeShares =
                        feeAmount.toSharesDown(s.totalSupplyAssets - feeAmount, s.totalSupplyShares);
                    s.totalSupplyShares += feeShares;
                }
            }
        }
    }
}
