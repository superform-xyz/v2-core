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

/// @title MorphoBlueYieldSourceOracle
/// @author Superform Labs
/// @notice Oracle for Morpho Blue lending markets (supply-side).
/// @dev ACCOUNTING UNIT: All values (PPS, TVL, asset conversions) are denominated in the
///      market's **loanToken** — the token suppliers deposit and earn interest on. This oracle
///      tracks supply-side lender positions only. It does NOT report:
///        - Collateral token value or equity NAV
///        - USD-denominated prices
///        - Morpho market oracle prices (the on-chain oracle used for LTV calculations)
///      Downstream consumers (SuperLedger, monitoring, fee calculations) receive loanToken-
///      denominated figures. If USD or collateral-denominated values are needed, an additional
///      price feed must be composed on top.
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
contract MorphoBlueYieldSourceOracle is AbstractYieldSourceOracle {
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

    /// @dev Accrued market state after replicating Morpho's interest logic.
    ///      Only supply-side fields are included; borrow state is used internally only
    ///      and is not meaningful to oracle consumers.
    struct AccruedState {
        uint256 totalSupplyAssets;
        uint256 totalSupplyShares;
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
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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

        uint128 lastUpdate;
        uint128 fee;
        uint128 totalBorrowShares;
        uint256 totalBorrowAssets;

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
            totalBorrowAssets = _totalBorrowAssets;
            totalBorrowShares = _totalBorrowShares;
            lastUpdate = _lastUpdate;
            fee = _fee;
        }

        // Replicate Morpho's _accrueInterest in a view context (matches MorphoBalancesLib.expectedMarketBalances)
        uint256 elapsed = block.timestamp - lastUpdate;
        if (elapsed > 365 days) elapsed = 365 days;
        if (elapsed > 0 && totalBorrowAssets > 0 && mp.irm != address(0)) {
            uint256 interest;

            // Scope: build Market struct and compute interest, then drop mkt and borrowRate
            {
                Market memory mkt = Market({
                    totalSupplyAssets: uint128(s.totalSupplyAssets),
                    totalSupplyShares: uint128(s.totalSupplyShares),
                    totalBorrowAssets: uint128(totalBorrowAssets),
                    totalBorrowShares: totalBorrowShares,
                    lastUpdate: lastUpdate,
                    fee: fee
                });
                uint256 borrowRate = IIrm(mp.irm).borrowRateView(mp, mkt);
                interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
            }

            s.totalSupplyAssets += interest;

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
