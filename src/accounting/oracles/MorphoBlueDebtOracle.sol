// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// morpho vendor
import { IMorphoStaticTyping, MarketParams, Market, Id } from "../../vendor/morpho/IMorpho.sol";
import { MarketParamsLib } from "../../vendor/morpho/MarketParamsLib.sol";
import { SharesMathLib } from "../../vendor/morpho/SharesMathLib.sol";
import { MathLib } from "../../vendor/morpho/MathLib.sol";
import { IIrm } from "../../vendor/morpho/IIrm.sol";

// superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { MorphoBlueMarketRegistry } from "./MorphoBlueMarketRegistry.sol";

/// @title MorphoBlueDebtOracle
/// @author Superform Labs
/// @notice Oracle for Morpho Blue debt positions (borrow side).
/// @dev ACCOUNTING UNIT: All values (PPS, TVL, asset conversions) are denominated in the
///      market's **loanToken** -- the token borrowers owe. This oracle tracks borrow-side
///      positions only. It does NOT report collateral value or equity NAV.
///
///      IMPORTANT -- Fee configuration:
///      This oracle MUST NOT be configured with feePercent > 0 in SuperLedgerConfiguration.
///      The inherited getAssetOutputWithFees() is overridden to always bypass fee computation.
///      Debt positions do not take cost-basis snapshots, so the base implementation's
///      previewFees() would treat the entire debt balance as "profit" and apply fees
///      incorrectly. The override enforces this constraint programmatically.
///
///      Interest accrual: Unlike EulerDebtOracle (which uses identity PPS because Euler's
///      debtOf() returns accrued debt directly), Morpho Blue stores stale borrow totals.
///      This oracle replicates Morpho's _accrueInterest logic in a view context to return
///      accurate (non-stale) debt values. The implementation mirrors
///      MorphoBlueYieldSourceOracle._getAccruedMarketState() but returns borrow-side state.
///
///      Registry sharing: Uses the same MorphoBlueMarketRegistry as the supply-side oracle.
///      Markets need only be registered once; the same market key (pseudo-address) is used
///      by both oracles.
///
///      Semantic notes for downstream consumers:
///      - getBalanceOfOwner() returns the borrower's borrowShares (NOT accrued debt in assets).
///        This is consistent with MorphoBlueYieldSourceOracle which returns supplyShares.
///      - getTVLByOwnerOfShares() returns accrued debt in asset units (borrowShares * borrow PPS).
///      - getTVL() returns accrued totalBorrowAssets (aggregate outstanding debt).
///      - getPricePerShare() returns the borrow share price: how many loanToken assets one
///        full borrow share unit (10^(loanDecimals+6)) is worth. This increases over time
///        as interest accrues.
///      - Rounding: toAssetsUp is used for debt conversion (conservative -- borrower owes
///        at least this much). This matches MorphoRepayHook.sharesToAssets() convention.
///
///      IRM safety: The registry enforces that only whitelisted IRMs can be used in registered
///      markets, preventing rogue borrowRateView implementations from corrupting oracle PPS.
///      Note: if a whitelisted IRM is a proxy and is upgraded to a reverting implementation,
///      the oracle will also revert for that market. Ensure whitelisted IRMs are either
///      non-upgradeable or monitored for upgrade events.
///
///      Elapsed cap: Interest accrual caps elapsed time to 365 days to prevent
///      wTaylorCompounded overflow. This diverges from Morpho core which has no cap;
///      for markets untouched for >365 days the oracle will underreport accrued debt.
///      In practice, markets with active borrowing are interacted with far more frequently
///      than annually (liquidations, repayments, supply/withdrawal all trigger accrual).
///
///      Decimals safety: loanToken.decimals() must be <= 249 to avoid uint8 overflow when
///      adding the virtual shares offset of 6. Standard ERC-20 tokens have decimals <= 18;
///      the registry's MARKET_MANAGER_ROLE gatekeeper is expected to only register tokens
///      with safe decimal counts. Solidity 0.8.x checked arithmetic will revert on overflow.
///
///      Taylor approximation: wTaylorCompounded uses a 3rd-order Taylor expansion of
///      e^(rate * time) - 1. For large rate * time products the approximation underestimates
///      the true exponential. This is a known property of Morpho Blue; the oracle replicates
///      this same approximation, so values are bit-exact with Morpho's internal computation.
///      The underestimation is conservative (reports slightly less debt than true mathematical
///      value).
contract MorphoBlueDebtOracle is AbstractYieldSourceOracle {
    using MarketParamsLib for MarketParams;
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is supplied where one is not permitted
    error ZERO_ADDRESS();

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Accrued borrow-side market state after replicating Morpho's interest logic.
    struct AccruedBorrowState {
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

    /// @notice Deploys the MorphoBlueDebtOracle with the given ledger configuration and market registry
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
    /// @dev Borrow shares have the same virtual offset as supply shares (VIRTUAL_SHARES = 1e6),
    ///      so decimals = loanToken.decimals() + 6, matching MorphoBlueYieldSourceOracle.
    ///      Reverts via checked arithmetic if loanToken.decimals() > 249 (uint8 overflow).
    function decimals(address yieldSourceAddress) external view override returns (uint8) {
        (MarketParams memory mp,) = REGISTRY.getMarketInfo(yieldSourceAddress);
        return IERC20Metadata(mp.loanToken).decimals() + 6;
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns borrow-side PPS using toAssetsUp (conservative for borrower).
    function getPricePerShare(address yieldSourceAddress) public view override returns (uint256) {
        (AccruedBorrowState memory s, MarketParams memory mp) = _getAccruedBorrowState(yieldSourceAddress);
        uint8 dec = IERC20Metadata(mp.loanToken).decimals();
        return (10 ** (uint256(dec) + 6)).toAssetsUp(s.totalBorrowAssets, s.totalBorrowShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Converts assets to borrow shares. Rounds down (fewer shares = less debt).
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
        (AccruedBorrowState memory s,) = _getAccruedBorrowState(yieldSourceAddress);
        return assetsIn.toSharesDown(s.totalBorrowAssets, s.totalBorrowShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Converts assets to borrow shares (withdrawal/repay direction). Rounds up.
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
        (AccruedBorrowState memory s,) = _getAccruedBorrowState(yieldSourceAddress);
        return assetsIn.toSharesUp(s.totalBorrowAssets, s.totalBorrowShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Converts borrow shares to assets. Rounds up (conservative -- borrower owes at least this much).
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
        (AccruedBorrowState memory s,) = _getAccruedBorrowState(yieldSourceAddress);
        return sharesIn.toAssetsUp(s.totalBorrowAssets, s.totalBorrowShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Overridden to bypass fee computation entirely. Debt positions do not take cost-basis
    ///      snapshots, so the base implementation's previewFees() would treat the entire debt
    ///      balance as "profit" and apply fees incorrectly. This override ensures correct behavior
    ///      regardless of SuperLedgerConfiguration settings.
    function getAssetOutputWithFees(
        bytes32,
        address yieldSourceAddress,
        address assetOut,
        address,
        uint256 usedShares
    )
        external
        view
        override
        returns (uint256)
    {
        return getAssetOutput(yieldSourceAddress, assetOut, usedShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns raw borrowShares from position(), consistent with supply-side oracle returning supplyShares.
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
        (, uint128 borrowShares,) = IMorphoStaticTyping(morpho).position(id, ownerOfShares);
        return uint256(borrowShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns accrued debt in asset units: borrowShares * borrow PPS (using toAssetsUp).
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
        (AccruedBorrowState memory s,) = _getAccruedBorrowState(yieldSourceAddress);
        return shares.toAssetsUp(s.totalBorrowAssets, s.totalBorrowShares);
    }

    /// @inheritdoc AbstractYieldSourceOracle
    /// @dev Returns accrued totalBorrowAssets (aggregate outstanding debt, not totalSupplyAssets).
    function getTVL(address yieldSourceAddress) public view override returns (uint256) {
        (AccruedBorrowState memory s,) = _getAccruedBorrowState(yieldSourceAddress);
        return s.totalBorrowAssets;
    }

    /// @notice Returns the last time Morpho accrued interest on-chain for this market
    /// @dev Useful for monitoring staleness. If block.timestamp - getLastUpdate() is large,
    ///      the oracle's view-replicated accrual may diverge from Morpho's actual state
    ///      (Taylor approximation error grows, and the 365-day elapsed cap may apply).
    /// @param yieldSourceAddress The market key registered in MorphoBlueMarketRegistry
    /// @return The block.timestamp of Morpho's last on-chain interest accrual for this market
    function getLastUpdate(address yieldSourceAddress) external view returns (uint256) {
        (MarketParams memory mp, address morpho) = REGISTRY.getMarketInfo(yieldSourceAddress);
        Id id = mp.id();
        (,,,, uint128 lastUpdate,) = IMorphoStaticTyping(morpho).market(id);
        return uint256(lastUpdate);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reads on-chain Morpho state and accrues interest for the borrow side in a view context
    /// @dev Mirrors MorphoBlueYieldSourceOracle._getAccruedMarketState() but only tracks borrow totals.
    ///      Key difference: no fee share accrual (fees only affect supply shares, not borrow shares).
    ///      Interest accrual only increases totalBorrowAssets; totalBorrowShares stays constant.
    ///
    ///      Elapsed cap: elapsed is capped to 365 days before calling wTaylorCompounded. Morpho
    ///      core has no such cap, so for markets untouched for >365 days the oracle underreports
    ///      accrued debt. This is an accepted trade-off: capping prevents wTaylorCompounded overflow
    ///      and ensures the oracle remains callable (returning a value rather than reverting).
    ///
    ///      IRM dependency: borrowRateView() is called without try/catch. If the IRM reverts, the
    ///      entire oracle call reverts. This is acceptable because a reverting IRM would also brick
    ///      Morpho's own accrueInterest(), meaning the market itself is broken. The registry's IRM
    ///      whitelist mitigates this risk; ensure whitelisted IRMs are non-upgradeable or monitored.
    ///
    ///      Overflow safety: wTaylorCompounded(borrowRate, elapsed) can overflow for extreme
    ///      borrowRate * elapsed products. The canonical AdaptiveCurveIrm bounds its output,
    ///      preventing this. Custom IRMs must also bound their rates; the registry whitelist
    ///      provides administrative control over which IRMs are accepted.
    ///
    ///      Taylor approximation: wTaylorCompounded uses a 3rd-order Taylor expansion of
    ///      e^(rate * time) - 1. For large rate * time products this underestimates the true
    ///      exponential, which is conservative (less debt reported than mathematically owed).
    ///      This matches Morpho core's own computation exactly.
    /// @param yieldSourceAddress The market key registered in MorphoBlueMarketRegistry
    /// @return s The accrued borrow state (totalBorrowAssets and totalBorrowShares after interest)
    /// @return mp The MarketParams for this market
    function _getAccruedBorrowState(address yieldSourceAddress)
        internal
        view
        returns (AccruedBorrowState memory s, MarketParams memory mp)
    {
        address morpho;
        (mp, morpho) = REGISTRY.getMarketInfo(yieldSourceAddress);

        uint128 lastUpdate;
        uint128 totalSupplyAssets;
        uint128 totalSupplyShares;
        uint128 fee;

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

            s.totalBorrowAssets = _totalBorrowAssets;
            s.totalBorrowShares = _totalBorrowShares;
            totalSupplyAssets = _totalSupplyAssets;
            totalSupplyShares = _totalSupplyShares;
            lastUpdate = _lastUpdate;
            fee = _fee;
        }

        uint256 elapsed = block.timestamp - lastUpdate;
        if (elapsed > 365 days) elapsed = 365 days;
        if (elapsed > 0 && s.totalBorrowAssets > 0 && mp.irm != address(0)) {
            Market memory mkt = Market({
                totalSupplyAssets: totalSupplyAssets,
                totalSupplyShares: totalSupplyShares,
                totalBorrowAssets: s.totalBorrowAssets.toUint128(),
                totalBorrowShares: s.totalBorrowShares.toUint128(),
                lastUpdate: lastUpdate,
                fee: fee
            });
            uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt);
            uint256 interest = s.totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));

            s.totalBorrowAssets += interest;
            // NOTE: totalBorrowShares is NOT modified by interest accrual.
            // Interest only changes totalBorrowAssets (increasing the value per share).
        }
    }
}
