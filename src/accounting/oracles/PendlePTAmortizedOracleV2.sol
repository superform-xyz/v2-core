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

/// @title PendlePTAmortizedOracleV2
/// @author Superform Labs
/// @notice V2: Provides amortized cost pricing for Pendle PT positions with on-chain rate calculation
/// @dev Key differences from V1:
///      - recordPurchase calculates sySpent from ptBought using on-chain PT rate (no off-chain price dependency)
///      - twapDuration is passed as parameter (configurable per-call via hook)
///      - Eliminates need for off-chain price conversion for exotic assets
/// @dev Uses Book Value accounting with linear pull-to-par amortization
/// @dev Implements IYieldSourceOracle for compatibility with SuperYieldSourceOracle
contract PendlePTAmortizedOracleV2 is AbstractYieldSourceOracle, AccessControl {
    using Math for uint256;
    using SafeCast for uint256;
    using PendlePYOracleLib for IPMarket;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role for managers who can correct book values and configure markets
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /// @notice Default TWAP duration used for IYieldSourceOracle functions
    uint32 public constant DEFAULT_TWAP_DURATION = 900; // 15 * 60

    /// @notice Default minimum TWAP duration (used when market not configured)
    /// @dev Spot price (twapDuration=0) can be manipulated via flash loans
    /// @dev 300 seconds (5 minutes) provides reasonable manipulation resistance
    uint32 public constant DEFAULT_MIN_TWAP_DURATION = 300; // 5 * 60

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

    /// @notice Minimum TWAP duration per market (0 means use DEFAULT_MIN_TWAP_DURATION)
    /// @dev Configurable by manager to accommodate different market liquidity characteristics
    mapping(address market => uint32) public marketMinTwapDuration;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when book value state is updated
    event BookValueUpdated(address indexed strategy, address indexed market, uint256 newBookValue, uint256 timestamp);

    /// @notice Emitted when book value is manually corrected by admin
    event BookValueCorrected(
        address indexed strategy,
        address indexed market,
        uint256 oldBookValue,
        uint256 newBookValue,
        address indexed correctedBy
    );

    /// @notice Emitted when a PT purchase is recorded (V2: includes calculated sySpent and twapDuration used)
    /// @param strategy The strategy address (msg.sender)
    /// @param market The Pendle market address
    /// @param ptBought Amount of PT received
    /// @param calculatedSySpent The sySpent calculated from PT rate
    /// @param twapDuration The TWAP duration used for rate calculation
    event PurchaseRecorded(
        address indexed strategy,
        address indexed market,
        uint256 ptBought,
        uint256 calculatedSySpent,
        uint32 twapDuration
    );

    /// @notice Emitted when a PT redemption is recorded
    event RedemptionRecorded(address indexed strategy, address indexed market, uint256 ptSold);

    /// @notice Emitted when minimum TWAP duration is configured for a market
    event MinTwapDurationSet(address indexed market, uint32 minTwapDuration);

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

    /// @notice Thrown when book value would exceed face value (sanity check)
    error BOOK_VALUE_EXCEEDS_FACE_VALUE();

    /// @notice Thrown when twapDuration is below MIN_TWAP_DURATION
    /// @dev Prevents spot price manipulation via flash loans
    error TWAP_DURATION_TOO_SHORT();

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
    }

    /*//////////////////////////////////////////////////////////////
                          STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Record a PT purchase - called by strategy via hooks AFTER deposit
    /// @dev V2: Calculates sySpent from ptBought using on-chain PT-to-SY rate
    /// @dev twapDuration must be >= market's configured minimum (or DEFAULT_MIN_TWAP_DURATION)
    /// @dev IMPORTANT: Uses getPtToSyRate (not getPtToAssetRate) because book value is in SY terms
    ///      At maturity: 1 PT = 1 SY (regardless of SY exchange rate to underlying)
    /// @dev msg.sender is the strategy being updated
    /// @param market The Pendle market address
    /// @param ptBought Amount of PT received from the purchase
    /// @param twapDuration TWAP duration for rate calculation (must be >= market's min TWAP)
    function recordPurchase(address market, uint256 ptBought, uint32 twapDuration) external {
        address strategy = msg.sender;
        if (market == address(0)) revert ZERO_ADDRESS();
        if (ptBought == 0) revert ZERO_AMOUNT();
        if (twapDuration < getMinTwapDuration(market)) revert TWAP_DURATION_TOO_SHORT();

        // Get PT address and maturity from market
        (, IPPrincipalToken pt,) = IPMarket(market).readTokens();
        uint256 maturity = pt.expiry();
        if (block.timestamp >= maturity) revert MARKET_EXPIRED();

        // Calculate sySpent from PT-to-SY rate (key V2 change)
        // IMPORTANT: Use getPtToSyRate, NOT getPtToAssetRate
        // Book value is stored in SY terms (1 PT = 1 SY at maturity)
        // getPtToAssetRate would incorporate the SY exchange rate, causing unit mismatch
        uint256 ptToSyRate = IPMarket(market).getPtToSyRate(twapDuration);
        uint256 sySpent = ptBought.mulDiv(ptToSyRate, 1e18);

        // Get current PT balance (after purchase) and derive previous balance
        uint256 currentPtBalance = IERC20(address(pt)).balanceOf(strategy);
        uint256 previousPtBalance = currentPtBalance - ptBought;

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

        emit PurchaseRecorded(strategy, market, ptBought, sySpent, twapDuration);
        emit BookValueUpdated(strategy, market, newBookValue, block.timestamp);
    }

    /// @notice Record a PT redemption - called by strategy via hooks AFTER redeem
    /// @dev msg.sender is the strategy being updated
    /// @param market The Pendle market address
    /// @param ptSold Amount of PT that was sold/redeemed
    function recordRedemption(address market, uint256 ptSold) external {
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
    /// @param strategy The strategy address
    /// @param market The Pendle market address
    /// @return exists True if position has been recorded
    function hasPosition(address strategy, address market) external view returns (bool exists) {
        return bookValues[strategy][market].lastUpdateTime > 0;
    }

    /*//////////////////////////////////////////////////////////////
                        MANAGER FUNCTIONS
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

    /// @notice Set minimum TWAP duration for a specific market
    /// @dev Can only be called by manager. Different markets may need different minimums
    ///      based on their liquidity characteristics.
    /// @param market The Pendle market address
    /// @param minTwapDuration Minimum TWAP duration in seconds (0 to use DEFAULT_MIN_TWAP_DURATION)
    function setMinTwapDuration(address market, uint32 minTwapDuration) external onlyRole(MANAGER_ROLE) {
        if (market == address(0)) revert ZERO_ADDRESS();

        marketMinTwapDuration[market] = minTwapDuration;

        emit MinTwapDurationSet(market, minTwapDuration);
    }

    /// @notice Get the effective minimum TWAP duration for a market
    /// @param market The Pendle market address
    /// @return The minimum TWAP duration (market-specific or DEFAULT_MIN_TWAP_DURATION)
    function getMinTwapDuration(address market) public view returns (uint32) {
        uint32 configured = marketMinTwapDuration[market];
        return configured > 0 ? configured : DEFAULT_MIN_TWAP_DURATION;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculate current book value for external view
    /// @dev Returns value in SY terms (consistent with recordPurchase which uses getPtToSyRate)
    /// @dev IMPORTANT: Book value is stored in SY terms, NOT asset terms
    ///      At maturity: 1 PT = 1 SY (face value), regardless of SY exchange rate to underlying
    /// @param strategy The strategy address holding the PT
    /// @param market The Pendle market address
    /// @return Current amortized book value in SY terms
    function _calculateBookValue(address strategy, address market) internal view returns (uint256) {
        BookValueState memory state = bookValues[strategy][market];

        // Get PT address from market
        (, IPPrincipalToken pt,) = IPMarket(market).readTokens();

        // Read current PT amount from chain
        uint256 currentPtAmount = IERC20(address(pt)).balanceOf(strategy);
        uint256 maturity = pt.expiry();

        // Edge case: no PT held
        if (currentPtAmount == 0) return 0;

        // At or after maturity, book value = face value (1 PT = 1 SY)
        // IMPORTANT: Return ptAmount directly, NOT getAssetOutput
        // Book value is in SY terms (from recordPurchase using getPtToSyRate)
        // Using getAssetOutput would convert to asset terms, causing unit mismatch
        // for yield-bearing SY tokens (e.g., wstETH where SY exchangeRate > 1)
        if (block.timestamp >= maturity) {
            return currentPtAmount;
        }

        // Calculate amortized book value using current balance
        return _calculateAmortizedBookValue(state, currentPtAmount, maturity);
    }

    /// @notice Core amortization formula
    /// @dev B(t) = A - (A - B(t0)) * (T - t) / (T - t0)
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
    function decimals(address market) external view override returns (uint8) {
        return IERC20Metadata(_pt(market)).decimals();
    }

    /// @inheritdoc IYieldSourceOracle
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
    /// @dev Uses DEFAULT_TWAP_DURATION for IYieldSourceOracle compatibility
    function getPricePerShare(address market) public view override returns (uint256 price) {
        price = IPMarket(market).getPtToAssetRate(DEFAULT_TWAP_DURATION);
    }

    /// @inheritdoc IYieldSourceOracle
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
