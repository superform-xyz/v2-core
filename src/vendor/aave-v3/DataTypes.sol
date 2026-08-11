// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title DataTypes (Aave V3 minimal subset)
/// @notice Field layout mirrors aave-dao/aave-v3-origin. Only the types the Superform V3 loan hooks
///         and their fork tests reference are vendored. `ReserveDataLegacy` is ABI-stable across
///         Aave V3.0 → V3.4; the field indices in the comments are load-bearing (aToken at index 8, variable
///         debt token at index 10. `stableDebtTokenAddress` (index 9) reads `address(0)` on V3.2+
///         markets and must never be dereferenced.
library DataTypes {
    struct ReserveConfigurationMap {
        uint256 data;
    }

    struct UserConfigurationMap {
        uint256 data;
    }

    struct ReserveDataLegacy {
        ReserveConfigurationMap configuration; // 0
        uint128 liquidityIndex; // 1
        uint128 currentLiquidityRate; // 2
        uint128 variableBorrowIndex; // 3
        uint128 currentVariableBorrowRate; // 4
        uint128 currentStableBorrowRate; // 5 (V3.2+: 0)
        uint40 lastUpdateTimestamp; // 6
        uint16 id; // 7
        address aTokenAddress; // 8  <-- aToken
        address stableDebtTokenAddress; // 9  (V3.2+: address(0))
        address variableDebtTokenAddress; // 10 <-- variable debt token
        address interestRateStrategyAddress; // 11
        uint128 accruedToTreasury; // 12
        uint128 unbacked; // 13
        uint128 isolationModeTotalDebt; // 14
    }
}
