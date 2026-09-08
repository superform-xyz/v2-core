// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { DataTypes } from "./DataTypes.sol";

/// @title IPool (Aave V3 minimal subset)
/// @notice Signatures taken verbatim from aave-dao/aave-v3-origin
///         (src/contracts/interfaces/IPool.sol). Only the functions the Superform V3 loan hooks and
///         their fork tests use are vendored. Aave publishes IPool as `pragma ^0.8.0`; re-pinning to
///         0.8.30 matches this repo's convention.
/// @dev `interestRateMode` must be 2 (variable). Stable rate (1) was removed in Aave V3.2 and reverts.
interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    )
        external;

    function repay(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        address onBehalfOf
    )
        external
        returns (uint256);

    function repayWithATokens(address asset, uint256 amount, uint256 interestRateMode) external returns (uint256);

    /// @notice Explicitly enables/disables a supplied reserve as collateral for the caller.
    /// @dev Enabling when already enabled is a no-op (returns without revert); it reverts only for a
    ///      genuinely non-collateral asset or when enabling would leave the position unhealthy. Used
    ///      by the supply-and-borrow hook to cover the cases where supply does not auto-enable
    ///      (isolation mode with other collateral, or a reserve previously disabled with a balance).
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

    // Used only by fork tests to resolve aToken / variableDebtToken and assert positions.
    function getReserveData(address asset) external view returns (DataTypes.ReserveDataLegacy memory);

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}
