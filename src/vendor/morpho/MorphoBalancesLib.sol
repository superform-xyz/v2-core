// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import { IIrm } from "./IIrm.sol";
import { MathLib } from "./MathLib.sol";
import { SharesMathLib } from "./SharesMathLib.sol";
import { MarketParamsLib } from "./MarketParamsLib.sol";
import { IMorpho, IMorphoStaticTyping, MarketParams, Market, Id } from "./IMorpho.sol";

/// @title MorphoBalancesLib
/// @author Morpho Labs (borrow-side port by Superform Labs)
/// @notice Helper library exposing the expected borrow-side market balances and the expected
///         borrow assets of a user, simulating interest accrual up to `block.timestamp`.
/// @dev Lean port of Morpho's periphery `MorphoBalancesLib` restricted to the borrow side.
///      The fee logic of Morpho's `_accrueInterest` only mints supply shares to the fee recipient;
///      it never changes `totalBorrowAssets`/`totalBorrowShares`, so it is intentionally omitted.
///      Because Morpho's `accrueInterest` uses the same `wTaylorCompounded` interest formula with
///      the same rounding, calling `expectedBorrowAssets` in the same transaction in which
///      `accrueInterest` and a shares-denominated `repay` execute yields the exact asset amount
///      the repay will pull (repay-by-shares rounds assets up, matching `toAssetsUp`).
library MorphoBalancesLib {
    using MathLib for uint256;
    using SharesMathLib for uint256;
    using MarketParamsLib for MarketParams;

    /// @notice Returns the expected total borrow assets and shares of the market after simulating
    ///         interest accrual up to `block.timestamp`
    /// @param morpho The Morpho Blue singleton
    /// @param marketParams The market parameters
    /// @return totalBorrowAssets The expected total borrow assets after accrual
    /// @return totalBorrowShares The total borrow shares (accrual never changes borrow shares)
    function expectedBorrowBalances(
        IMorpho morpho,
        MarketParams memory marketParams
    )
        internal
        view
        returns (uint256 totalBorrowAssets, uint256 totalBorrowShares)
    {
        Id id = marketParams.id();
        Market memory market = morpho.market(id);

        totalBorrowAssets = market.totalBorrowAssets;
        totalBorrowShares = market.totalBorrowShares;

        uint256 elapsed = block.timestamp - market.lastUpdate;
        if (elapsed != 0 && totalBorrowAssets != 0) {
            uint256 borrowRate = IIrm(marketParams.irm).borrowRateView(marketParams, market);
            uint256 interest = totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
            totalBorrowAssets += interest;
        }
    }

    /// @notice Returns the expected borrow assets of `user` on the given market after simulating
    ///         interest accrual up to `block.timestamp`, rounding up (the exact amount a full
    ///         shares-denominated repayment will pull)
    /// @param morpho The Morpho Blue singleton
    /// @param marketParams The market parameters
    /// @param user The borrower
    /// @return The expected borrow assets of `user`, rounded up
    function expectedBorrowAssets(
        IMorpho morpho,
        MarketParams memory marketParams,
        address user
    )
        internal
        view
        returns (uint256)
    {
        (uint256 totalBorrowAssets, uint256 totalBorrowShares) = expectedBorrowBalances(morpho, marketParams);
        (, uint128 borrowShares,) = IMorphoStaticTyping(address(morpho)).position(marketParams.id(), user);
        return uint256(borrowShares).toAssetsUp(totalBorrowAssets, totalBorrowShares);
    }
}
