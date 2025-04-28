// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IIncentiveFundContract {
    /**
     * @notice Settles the incentive for a user.
     * @param user The address of the user.
     * @param amount The amount of incentive to settle (can be positive or negative).
     */
    function settleIncentive(address user, int256 amount) external;
}