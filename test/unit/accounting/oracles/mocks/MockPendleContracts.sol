// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { IStandardizedYield } from "@pendle/interfaces/IStandardizedYield.sol";
import { IPPrincipalToken } from "@pendle/interfaces/IPPrincipalToken.sol";
import { IPYieldToken } from "@pendle/interfaces/IPYieldToken.sol";

/// @title MockPrincipalToken
/// @notice Minimal mock Pendle Principal Token for testing - only implements what we need
contract MockPrincipalToken {
    uint256 private _expiry;
    mapping(address => uint256) private _balances;
    uint256 private _totalSupply;

    string public constant name = "Mock PT";
    string public constant symbol = "mPT";
    uint8 public constant decimals = 18;

    constructor(uint256 expiryTimestamp) {
        _expiry = expiryTimestamp;
    }

    function expiry() external view returns (uint256) {
        return _expiry;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
        _totalSupply += amount;
    }

    function burn(address from, uint256 amount) external {
        require(_balances[from] >= amount, "Insufficient balance");
        _balances[from] -= amount;
        _totalSupply -= amount;
    }

    // ERC20 interface (minimal)
    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function approve(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function allowance(address, address) external pure returns (uint256) {
        return type(uint256).max;
    }
}

/// @title MockPendleMarket
/// @notice Minimal mock Pendle Market for testing - implements readTokens() and getPtToAssetRate()
contract MockPendleMarket {
    address private immutable _sy;
    address private immutable _pt;
    address private immutable _yt;

    // State for oracle observations (for TWAP calculation)
    bool public increaseCardinalityRequired;
    uint16 public observationCardinality;
    uint16 public observationCardinalityNext;

    // Configurable PT-to-SY rate override (0 means use default calculation)
    uint256 public ptToSyRateOverride;

    constructor(address ptAddress) {
        _sy = address(new MockSY());
        _pt = ptAddress;
        _yt = address(new MockYT());
        // Initialize oracle state
        increaseCardinalityRequired = false;
        observationCardinality = 65535; // Large enough
        observationCardinalityNext = 65535;
    }

    /// @notice Set a fixed PT-to-SY rate for testing edge cases
    /// @dev When set to 2e18, will trigger BOOK_VALUE_EXCEEDS_FACE_VALUE in recordPurchase
    /// @param rate The rate to return (0 to use default calculation)
    function setPtToSyRateOverride(uint256 rate) external {
        ptToSyRateOverride = rate;
    }

    /// @notice Returns PT to SY TWAP rate
    /// @dev If override is set, returns that; otherwise falls back to getPtToAssetRate behavior
    function getPtToSyRate(uint32) external view returns (uint256) {
        if (ptToSyRateOverride > 0) {
            return ptToSyRateOverride;
        }
        // Default: same as getPtToAssetRate since MockSY has 1:1 exchange rate
        uint256 maturity = MockPrincipalToken(_pt).expiry();
        if (block.timestamp >= maturity) {
            return 1e18; // At maturity, 1 PT = 1 SY
        }
        return 0.9e18; // Before maturity, 1 PT = 0.9 SY (10% discount)
    }

    /// @notice Set observe to return values that result in rate > 1e18 for testing
    /// @dev When observeReturnHighRate is true, observe() returns values giving rate ~2e18
    bool public observeReturnHighRate;

    function setObserveReturnHighRate(bool highRate) external {
        observeReturnHighRate = highRate;
    }

    function readTokens()
        external
        view
        returns (IStandardizedYield sy, IPPrincipalToken pt, IPYieldToken yt)
    {
        return (IStandardizedYield(_sy), IPPrincipalToken(_pt), IPYieldToken(_yt));
    }

    function expiry() external view returns (uint256) {
        return MockPrincipalToken(_pt).expiry();
    }

    /// @notice Mock observe function for Pendle oracle library
    /// @dev Returns cumulative ln(implied rate) values that result in ~0.9 PT-to-asset rate before maturity
    /// @dev When observeReturnHighRate is true, returns values that result in rate > 1e18 (negative implied rate)
    /// @param secondsAgos Array of seconds ago to observe (e.g., [900, 0] for 15-min TWAP)
    /// @return lnImpliedRateCumulative Array of cumulative ln(implied rate) values
    function observe(uint32[] calldata secondsAgos) external view returns (uint216[] memory lnImpliedRateCumulative) {
        uint256 maturity = MockPrincipalToken(_pt).expiry();
        lnImpliedRateCumulative = new uint216[](secondsAgos.length);

        // Special case: return values that give rate > 1e18 for testing BOOK_VALUE_EXCEEDS_FACE_VALUE
        if (observeReturnHighRate) {
            // To get rate > 1e18, we need negative implied rate
            // lnImpliedRate = (cumulative[older] - cumulative[newer]) / duration
            // For negative lnImpliedRate: cumulative[older] < cumulative[newer]
            //
            // secondsAgos[0] = 900 (older), secondsAgos[1] = 0 (current)
            // We want cumulative[0] < cumulative[1] (older < newer, inverted from normal)
            //
            // Return values that give a strong negative implied rate
            // This simulates extreme market conditions or oracle manipulation
            for (uint256 i = 0; i < secondsAgos.length; i++) {
                // Normally: cumulative increases over time (older < newer in absolute time means older < newer in cumulative)
                // For negative rate: we invert - larger secondsAgo gets larger cumulative
                // secondsAgos[0] = 900 -> larger cumulative[0]? No, we want smaller.
                // Actually: secondsAgos is "how long ago", so older observation has larger secondsAgo
                // We want: cumulative[older] < cumulative[newer]
                // older = secondsAgos[0] = 900, newer = secondsAgos[1] = 0
                // So cumulative[0] < cumulative[1]
                //
                // Normal: cumulative = rate * observationTime, and older observation has smaller observationTime
                // For rate > 1: cumulative[0] < cumulative[1], meaning older has SMALLER cumulative
                // But older has smaller observationTime too... so we need different scaling
                //
                // Let's just hardcode values that work:
                // cumulative[0] (older, 900 seconds ago) = 1e18
                // cumulative[1] (current) = 1e19
                // lnImpliedRate = (1e18 - 1e19) / 900 = -9e18 / 900 = -1e16 (negative)
                // This gives rate > 1e18
                if (secondsAgos[i] == 900) {
                    lnImpliedRateCumulative[i] = uint216(1e18);
                } else {
                    lnImpliedRateCumulative[i] = uint216(1e19);
                }
            }
            return lnImpliedRateCumulative;
        }

        // At maturity, implied rate should result in PT = 1 asset (rate = 1e18)
        // Before maturity, implied rate should result in PT = 0.9 asset (rate = 0.9e18)
        //
        // Pendle's formula: ptRate = syExchangeRate / pyIndexCurrent * exp(-rateAnchor * timeToExpiry / IMPLIED_RATE_TIME)
        // For simplicity, we return cumulative values that give approximately our target rate
        //
        // The library calculates: lnImpliedRate = (cumulative[older] - cumulative[newer]) / duration
        // Then: ptToAssetRate = exchangeRate * exp(-lnImpliedRate * timeToExpiry / IMPLIED_RATE_TIME) / pyIndex

        for (uint256 i = 0; i < secondsAgos.length; i++) {
            uint256 observationTime = block.timestamp - secondsAgos[i];
            uint256 timeToExpiry = maturity > observationTime ? maturity - observationTime : 0;

            if (timeToExpiry == 0) {
                // At or after maturity - no implied rate accumulation
                lnImpliedRateCumulative[i] = 0;
            } else {
                // Before maturity - return cumulative value based on implied rate
                // To get PT rate of 0.9, we need specific ln(implied rate)
                // ln(1/0.9) ≈ 0.1054 for timeToExpiry = 1 year
                // We use a simplified linear accumulation: cumulative = rate * time
                // For ~10% discount over 100 days, implied rate ≈ 0.365 (36.5% APY)
                // lnImpliedRate ≈ ln(1.365) ≈ 0.311
                //
                // Using a fixed implied rate that gives ~0.9 PT rate:
                // ptRate = 1 / (1 + impliedRate * timeToExpiry / 365 days)
                // 0.9 = 1 / (1 + r * 100/365) => r ≈ 0.406
                // ln(1.406) ≈ 0.341
                //
                // Cumulative = lnImpliedRate * observationTime (simplified)
                // We scale by 1e18 for precision
                uint256 impliedLnRate = 0.341e18; // Approximate ln(implied rate) in 1e18
                lnImpliedRateCumulative[i] = uint216(impliedLnRate * observationTime / 1e18 * 1e18);
            }
        }
    }

    /// @notice Returns PT to asset TWAP rate - at maturity returns 1e18 (1:1)
    /// @dev For testing, returns 1e18 at/after maturity, 0.9e18 before
    /// @dev Note: This function is NOT called when using PendlePYOracleLib - the library uses observe()
    function getPtToAssetRate(uint32) external view returns (uint256) {
        uint256 maturity = MockPrincipalToken(_pt).expiry();
        if (block.timestamp >= maturity) {
            return 1e18; // At maturity, 1 PT = 1 underlying
        }
        return 0.9e18; // Before maturity, 1 PT = 0.9 underlying (10% discount)
    }

    /// @notice Returns oracle state for the library's cardinality check
    function getOracleState()
        external
        view
        returns (
            bool _increaseCardinalityRequired,
            uint16 _cardinality,
            uint16 _cardinalityNext
        )
    {
        return (increaseCardinalityRequired, observationCardinality, observationCardinalityNext);
    }
}

/// @title MockSY
/// @notice Minimal mock SY for market.readTokens() and getAssetOutput()
contract MockSY {
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Returns asset info for pricing calculations
    /// @return assetType Always 0 (TOKEN) for this mock
    /// @return assetAddress Zero address (not used in our calculations)
    /// @return assetDecimals 18 decimals (matches PT decimals for consistent testing)
    function assetInfo() external pure returns (uint8 assetType, address assetAddress, uint8 assetDecimals) {
        return (0, address(0), 18);
    }

    /// @notice Returns exchange rate - used by Pendle oracle library
    /// @dev Returns 1e18 (1:1) for simplicity in unit tests
    function exchangeRate() external pure returns (uint256) {
        return 1e18;
    }
}

/// @title MockYT
/// @notice Minimal mock YT for market.readTokens() and Pendle oracle library
contract MockYT {
    function decimals() external pure returns (uint8) {
        return 18;
    }

    /// @notice Returns stored PY index - used by Pendle oracle library
    /// @dev Returns 1e18 (1:1) for simplicity in unit tests
    function pyIndexStored() external pure returns (uint256) {
        return 1e18;
    }

    /// @notice Whether to cache index in same block - used by Pendle oracle library
    function doCacheIndexSameBlock() external pure returns (bool) {
        return false;
    }

    /// @notice Returns current PY index - used by Pendle oracle library
    function pyIndexCurrent() external pure returns (uint256) {
        return 1e18;
    }
}

/// @title MockTwapOracle
/// @notice Simulates old PendlePTYieldSourceOracle behavior (TWAP-based pricing)
/// @dev Used for comparison tests between TWAP and amortized oracles
contract MockTwapOracle {
    /// @notice Simulate getTVLByOwnerOfShares using TWAP rate
    /// @param ptAmount The PT balance
    /// @param twapRate The simulated TWAP rate (PT to asset, in 1e18)
    /// @return tvl The TVL based on market rate
    function simulateTVL(uint256 ptAmount, uint256 twapRate) external pure returns (uint256 tvl) {
        // Old oracle: tvl = ptAmount * twapRate / 1e18
        // This is equivalent to getAssetOutput(market, address(0), ptBalance)
        // where pricePerShare = twapRate
        tvl = (ptAmount * twapRate) / 1e18;
    }

    /// @notice Simulate getAssetOutput using TWAP rate
    /// @param sharesIn PT amount
    /// @param twapRate The simulated TWAP rate (PT to asset, in 1e18)
    /// @return assetsOut Asset value based on market rate
    function simulateGetAssetOutput(uint256 sharesIn, uint256 twapRate) external pure returns (uint256 assetsOut) {
        // assetsOut = sharesIn * twapRate / 1e18
        assetsOut = (sharesIn * twapRate) / 1e18;
    }

    /// @notice Demonstrate the key difference from amortized oracle
    /// @dev TWAP oracle: market rate driven (volatile)
    ///      Amortized oracle: linear pull-to-par (predictable)
    function oracleDifference() external pure returns (string memory) {
        return "TWAP: Market-driven | Amortized: Linear pull-to-par";
    }
}
