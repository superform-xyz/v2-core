// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import { IPMarket } from "@pendle/interfaces/IPMarket.sol";
import { IPPrincipalToken } from "@pendle/interfaces/IPPrincipalToken.sol";
import { IStandardizedYield } from "@pendle/interfaces/IStandardizedYield.sol";
import { PendlePYOracleLib } from "@pendle/oracles/PtYtLpOracle/PendlePYOracleLib.sol";

// Superform
import { AbstractYieldSourceOracle } from "./AbstractYieldSourceOracle.sol";
import { IYieldSourceOracle } from "../../interfaces/accounting/IYieldSourceOracle.sol";

/// @title PendlePTAmortizedOracle
/// @author Superform Labs
/// @notice Provides amortized cost pricing for Pendle PT positions held by strategies
/// @dev Uses Book Value accounting with linear pull-to-par amortization
/// @dev Implements IYieldSourceOracle for compatibility with SuperYieldSourceOracle
/// @dev Strategies call recordPurchase/recordRedemption directly via hooks
/// @dev recordPurchase: Called AFTER deposit - ptAmount is PT received from deposit hook
/// @dev recordRedemption: Called AFTER redeem - ptSold is PT that was sold
///
/// @dev TRUST MODEL: This oracle is permissionless - any address can record purchases/redemptions.
/// @dev Book values are stored per-caller (strategy => market => state), so callers can only
/// @dev affect their own recorded positions. A malicious caller cannot corrupt data for other strategies.
/// @dev The oracle simply tracks what each caller reports; it does not validate actual PT holdings.
contract PendlePTAmortizedOracle is AbstractYieldSourceOracle, AccessControl {
    using Math for uint256;
    using SafeCast for uint256;
    using PendlePYOracleLib for IPMarket;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role for managers who can correct book values
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice The Time-Weighted Average Price duration used for Pendle oracle queries
    uint32 public immutable TWAP_DURATION;

    /// @notice Default TWAP duration set to 15 minutes
    uint32 private constant DEFAULT_TWAP_DURATION = 900; // 15 * 60

    /// @notice Price decimals for Pendle oracle (1e18)
    uint256 private constant PRICE_DECIMALS = 18;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice State for tracking book value - stores values at last update
    /// @dev Packed into single storage slot (24 bytes)
    struct BookValueState {
        uint128 lastUpdateBookValue; // B(t0): Book value at last update
        uint64 lastUpdateTime; // t0: Timestamp of last update
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Book value state per strategy per market
    /// @dev strategy => market => BookValueState
    mapping(address strategy => mapping(address market => BookValueState)) public bookValues;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when book value state is updated
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @param newBookValue The new book value after the update
    /// @param timestamp The timestamp of the update
    event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp);

    /// @notice Emitted when book value is manually corrected by admin
    /// @param strategy The strategy address
    /// @param market The Pendle market address
    /// @param oldBookValue The previous book value
    /// @param newBookValue The corrected book value
    /// @param correctedBy The admin who made the correction
    event BookValueCorrected(
        address indexed strategy,
        address indexed market,
        uint256 oldBookValue,
        uint256 newBookValue,
        address indexed correctedBy
    );

    /// @notice Emitted when a PT purchase is recorded
    /// @param strategy The strategy address (msg.sender)
    /// @param market The Pendle market address
    /// @param sySpent Amount of SY spent on the purchase
    /// @param ptAmount Amount of PT received
    event PurchaseRecorded(
        address indexed strategy,
        address indexed market,
        uint256 sySpent,
        uint256 ptAmount
    );

    /// @notice Emitted when a PT redemption is recorded
    /// @param strategy The strategy address (msg.sender)
    /// @param market The Pendle market address
    /// @param ptSold Amount of PT sold/redeemed
    event RedemptionRecorded(
        address indexed strategy,
        address indexed market,
        uint256 ptSold
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when a zero address is provided
    error ZERO_ADDRESS();

    /// @notice Thrown when a zero amount is provided
    error ZERO_AMOUNT();

    /// @notice Thrown when querying a position that doesn't exist
    error NO_POSITION();

    /// @notice Thrown when trying to record a purchase after market has expired
    error MARKET_EXPIRED();

    /// @notice Thrown when redemption amount exceeds current holdings
    error INSUFFICIENT_POSITION();

    /// @notice Thrown when book value would exceed face value (sanity check)
    error BOOK_VALUE_EXCEEDS_FACE_VALUE();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize the oracle with an admin and SuperLedgerConfiguration
    /// @param admin The admin address who receives DEFAULT_ADMIN_ROLE and MANAGER_ROLE
    /// @param superLedgerConfiguration_ Address of the SuperLedgerConfiguration contract
    constructor(
        address admin,
        address superLedgerConfiguration_
    )
        AbstractYieldSourceOracle(superLedgerConfiguration_)
    {
        if (admin == address(0)) revert ZERO_ADDRESS();
        if (superLedgerConfiguration_ == address(0)) revert ZERO_ADDRESS();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MANAGER_ROLE, admin);

        TWAP_DURATION = DEFAULT_TWAP_DURATION;
    }

    /*//////////////////////////////////////////////////////////////
                          STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Record a PT purchase - called by strategy via hooks AFTER deposit
    /// @dev msg.sender is the strategy being updated
    /// @dev Called AFTER deposit hook - ptAmount comes from deposit hook output (usePrevHookAmount)
    /// @param market The Pendle market address
    /// @param sySpent Amount of SY spent on the purchase (book value increment)
    /// @param ptAmount Amount of PT received from the purchase
    function recordPurchase(
        address market,
        uint256 sySpent,
        uint256 ptAmount
    )
        external
    {
        address strategy = msg.sender;
        if (market == address(0)) revert ZERO_ADDRESS();
        if (sySpent == 0 || ptAmount == 0) revert ZERO_AMOUNT();

        // Get PT address and maturity from market
        (, IPPrincipalToken pt,) = IPMarket(market).readTokens();
        uint256 maturity = pt.expiry();
        if (block.timestamp >= maturity) revert MARKET_EXPIRED();

        // Get current PT balance (after purchase) and derive previous balance
        uint256 currentPtBalance = IERC20(address(pt)).balanceOf(strategy);
        uint256 previousPtBalance = currentPtBalance - ptAmount;

        BookValueState storage state = bookValues[strategy][market];

        // Calculate current book value (if position exists) and add new purchase
        uint256 newBookValue;
        if (state.lastUpdateTime > 0) {
            // Existing position: amortize and add
            uint256 currentBookValue = _calculateAmortizedBookValue(state, previousPtBalance, maturity);
            newBookValue = currentBookValue + sySpent;
        } else {
            // First purchase
            newBookValue = sySpent;
        }

        // Sanity check: book value should not exceed face value
        if (newBookValue > currentPtBalance) revert BOOK_VALUE_EXCEEDS_FACE_VALUE();

        state.lastUpdateBookValue = newBookValue.toUint128();
        state.lastUpdateTime = block.timestamp.toUint64();

        emit PurchaseRecorded(strategy, market, sySpent, ptAmount);
        emit BookValueUpdated(strategy, market, newBookValue, block.timestamp);
    }

    /// @notice Record a PT redemption - called by strategy via hooks AFTER redeem
    /// @dev msg.sender is the strategy being updated
    /// @dev Called AFTER redeem hook - ptSold is the PT amount that was sold
    /// @param market The Pendle market address
    /// @param ptSold Amount of PT that was sold/redeemed
    function recordRedemption(
        address market,
        uint256 ptSold
    )
        external
    {
        address strategy = msg.sender;
        if (market == address(0)) revert ZERO_ADDRESS();
        if (ptSold == 0) revert ZERO_AMOUNT();

        BookValueState storage state = bookValues[strategy][market];
        if (state.lastUpdateTime == 0) revert NO_POSITION();

        // Get PT address and maturity from market
        (, IPPrincipalToken pt,) = IPMarket(market).readTokens();
        uint256 maturity = pt.expiry();

        // Get current PT balance (after redemption) and derive previous balance
        uint256 currentPtBalance = IERC20(address(pt)).balanceOf(strategy);
        uint256 previousPtBalance = currentPtBalance + ptSold;

        // Calculate current book value using previous ptAmount
        uint256 currentBookValue = _calculateAmortizedBookValue(state, previousPtBalance, maturity);

        // Cost basis accounting: proportionally reduce book value
        uint256 costBasis = currentBookValue.mulDiv(ptSold, previousPtBalance);
        uint256 newBookValue = currentBookValue - costBasis;

        state.lastUpdateBookValue = newBookValue.toUint128();
        state.lastUpdateTime = block.timestamp.toUint64();

        emit RedemptionRecorded(strategy, market, ptSold);
        emit BookValueUpdated(strategy, market, newBookValue, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get the current amortized book value for a position
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @return bookValue Current amortized book value
    function getBookValue(address strategy, address market) external view returns (uint256 bookValue) {
        BookValueState memory state = bookValues[strategy][market];
        if (state.lastUpdateTime == 0) revert NO_POSITION();
        return _calculateBookValue(strategy, market);
    }

    /// @notice Check if a position exists
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @return exists True if position has been recorded
    function hasPosition(address strategy, address market) external view returns (bool exists) {
        return bookValues[strategy][market].lastUpdateTime > 0;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Correct book value state in case of errors
    /// @dev Can only be called by manager. Use with caution - only for error recovery.
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @param newBookValue The corrected book value
    function correctBookValue(
        address strategy,
        address market,
        uint128 newBookValue
    )
        external
        onlyRole(MANAGER_ROLE)
    {
        if (strategy == address(0) || market == address(0)) revert ZERO_ADDRESS();

        // Get PT address and current balance to validate
        (, IPPrincipalToken pt,) = IPMarket(market).readTokens();
        uint256 currentPtBalance = IERC20(address(pt)).balanceOf(strategy);

        // Sanity check: corrected book value should not exceed current PT balance
        if (newBookValue > currentPtBalance) revert BOOK_VALUE_EXCEEDS_FACE_VALUE();

        BookValueState storage state = bookValues[strategy][market];
        uint256 oldBookValue = state.lastUpdateBookValue;

        state.lastUpdateBookValue = newBookValue;
        state.lastUpdateTime = block.timestamp.toUint64();

        emit BookValueCorrected(strategy, market, oldBookValue, newBookValue, msg.sender);
        emit BookValueUpdated(strategy, market, newBookValue, block.timestamp);
    }

    /// @notice Delete a position entirely (for cleanup of erroneous entries)
    /// @dev Can only be called by manager. Resets all state for the position.
    /// @param strategy The strategy address
    /// @param market The Pendle market address
    function deletePosition(address strategy, address market) external onlyRole(MANAGER_ROLE) {
        if (strategy == address(0) || market == address(0)) revert ZERO_ADDRESS();

        BookValueState storage state = bookValues[strategy][market];
        if (state.lastUpdateTime == 0) revert NO_POSITION();

        uint256 oldBookValue = state.lastUpdateBookValue;

        delete bookValues[strategy][market];

        emit BookValueCorrected(strategy, market, oldBookValue, 0, msg.sender);
        emit BookValueUpdated(strategy, market, 0, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate current book value for external view
    /// @dev Used by getBookValue() - uses current PT balance for amortization
    /// @dev Returns value in underlying asset decimals (same format as getAssetOutput)
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @return Current amortized book value in underlying asset decimals
    function _calculateBookValue(address strategy, address market) internal view returns (uint256) {
        BookValueState memory state = bookValues[strategy][market];

        // Get PT address from market
        (, IPPrincipalToken pt,) = IPMarket(market).readTokens();

        // Read current PT amount from chain
        uint256 currentPtAmount = IERC20(address(pt)).balanceOf(strategy);
        uint256 maturity = pt.expiry();

        // Edge case: no PT held
        if (currentPtAmount == 0) return 0;

        // At or after maturity, convert PT to asset value using getAssetOutput for consistent decimals
        // At maturity TWAP rate = 1.0, so this returns face value properly normalized
        if (block.timestamp >= maturity) {
            return getAssetOutput(market, address(0), currentPtAmount);
        }

        // Calculate amortized book value using current balance
        // Note: Book value is stored in SY terms which has same decimals as underlying asset
        return _calculateAmortizedBookValue(state, currentPtAmount, maturity);
    }

    /// @notice Core amortization formula
    /// @dev B(t) = A - (A - B(t0)) * (T - t) / (T - t0)
    /// @dev Used by both _calculateBookValue and strategy functions
    /// @param state The stored book value state
    /// @param ptAmount The PT amount to use for amortization (face value)
    /// @param maturity The PT maturity timestamp
    /// @return Amortized book value
    function _calculateAmortizedBookValue(
        BookValueState memory state,
        uint256 ptAmount,
        uint256 maturity
    )
        internal
        view
        returns (uint256)
    {
        uint256 A = ptAmount;
        uint256 B_t0 = state.lastUpdateBookValue;
        uint256 t0 = state.lastUpdateTime;

        // Edge case: no PT
        if (A == 0) return 0;

        // At or after maturity, book value = face value
        if (block.timestamp >= maturity) {
            return A;
        }

        // Before any time has passed, book value = B(t0)
        if (block.timestamp <= t0) {
            return B_t0;
        }

        // Linear amortization: B(t) = A - (A - B(t0)) * (T - t) / (T - t0)
        uint256 timeRemaining = maturity - block.timestamp;
        uint256 totalDuration = maturity - t0;

        if (A >= B_t0) {
            uint256 unamortizedDiscount = (A - B_t0).mulDiv(timeRemaining, totalDuration);
            return A - unamortizedDiscount;
        } else {
            // Defensive: shouldn't happen (book value > face value is invalid for zero-coupon bond)
            // Cap at face value to avoid propagating corrupted data
            return A;
        }
    }

    /*//////////////////////////////////////////////////////////////
                    IYIELDSOURCEORACLE IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the PT token decimals for the given market
    function decimals(address market) external view override returns (uint8) {
        return IERC20Metadata(_pt(market)).decimals();
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Calculates shares output using Pendle TWAP rate
    function getShareOutput(
        address market,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256 sharesOut)
    {
        uint256 pricePerShare = getPricePerShare(market);
        if (pricePerShare == 0) return 0;

        IStandardizedYield sY = IStandardizedYield(_sy(market));
        (,, uint8 assetDecimals) = sY.assetInfo();
        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();

        // Scale assetsIn to 1e18 terms
        uint256 assetsIn18 = assetsIn * (10 ** (PRICE_DECIMALS - assetDecimals));

        // sharesOut = assetsIn18 * 10^ptDecimals / pricePerShare
        sharesOut = Math.mulDiv(assetsIn18, 10 ** uint256(ptDecimals), pricePerShare);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Calculates withdrawal shares using Pendle TWAP rate
    function getWithdrawalShareOutput(
        address market,
        address,
        uint256 assetsIn
    )
        external
        view
        override
        returns (uint256)
    {
        uint256 pricePerShare = getPricePerShare(market);
        if (pricePerShare == 0) return 0;

        IStandardizedYield sY = IStandardizedYield(_sy(market));
        (,, uint8 assetDecimals) = sY.assetInfo();
        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();

        uint256 assetsIn18 = assetsIn * (10 ** (PRICE_DECIMALS - assetDecimals));
        return Math.mulDiv(assetsIn18, 10 ** uint256(ptDecimals), pricePerShare, Math.Rounding.Ceil);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Calculates asset output using Pendle TWAP rate
    function getAssetOutput(
        address market,
        address,
        uint256 sharesIn
    )
        public
        view
        override
        returns (uint256 assetsOut)
    {
        uint256 pricePerShare = getPricePerShare(market);
        uint8 ptDecimals = IERC20Metadata(_pt(market)).decimals();

        IStandardizedYield sY = IStandardizedYield(_sy(market));
        (,, uint8 assetDecimals) = sY.assetInfo();

        // assetsOut18 = sharesIn * pricePerShare / 10^ptDecimals
        uint256 assetsOut18 = Math.mulDiv(sharesIn, pricePerShare, 10 ** uint256(ptDecimals));

        // Scale from 1e18 to asset decimals
        assetsOut = Math.mulDiv(assetsOut18, 1, 10 ** (PRICE_DECIMALS - assetDecimals));
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the Pendle TWAP PT-to-Asset rate
    function getPricePerShare(address market) public view override returns (uint256 price) {
        price = IPMarket(market).getPtToAssetRate(TWAP_DURATION);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the PT balance of the owner
    function getBalanceOfOwner(
        address market,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256 balance)
    {
        balance = IERC20(address(_pt(market))).balanceOf(ownerOfShares);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns the AMORTIZED book value for the strategy's position
    /// @dev This is the key method that uses book value accounting instead of market price
    /// @param market The Pendle market address (yieldSourceAddress)
    /// @param ownerOfShares The strategy address holding the PT
    /// @return tvl The amortized book value of the position
    function getTVLByOwnerOfShares(
        address market,
        address ownerOfShares
    )
        public
        view
        override
        returns (uint256 tvl)
    {
        BookValueState memory state = bookValues[ownerOfShares][market];

        // If no position recorded, fall back to market-based calculation
        if (state.lastUpdateTime == 0) {
            uint256 ptBalance = IERC20(address(_pt(market))).balanceOf(ownerOfShares);
            if (ptBalance == 0) return 0;
            return getAssetOutput(market, address(0), ptBalance);
        }

        // Return amortized book value
        return _calculateBookValue(ownerOfShares, market);
    }

    /// @inheritdoc IYieldSourceOracle
    /// @dev Returns total TVL using market price (not book value)
    /// @dev Book value is strategy-specific, so total TVL uses market rate
    function getTVL(address market) public view override returns (uint256 tvl) {
        IERC20Metadata pt = IERC20Metadata(_pt(market));
        uint256 ptTotalSupply = pt.totalSupply();

        if (ptTotalSupply == 0) return 0;

        tvl = getAssetOutput(market, address(0), ptTotalSupply);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get PT address from market
    function _pt(address market) internal view returns (address ptAddress) {
        (, IPPrincipalToken ptAddressInt,) = IPMarket(market).readTokens();
        ptAddress = address(ptAddressInt);
    }

    /// @notice Get SY address from market
    function _sy(address market) internal view returns (address sYAddress) {
        (IStandardizedYield sYAddressInt,,) = IPMarket(market).readTokens();
        sYAddress = address(sYAddressInt);
    }
}
