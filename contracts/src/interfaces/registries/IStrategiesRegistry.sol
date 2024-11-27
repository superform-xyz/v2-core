// SPDX-License-Identifier: MIT
pragma solidity >=0.8.28;

interface IStrategiesRegistry {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @notice Get the hooks for a strategy
    /// @param strategyId_ The id of the strategy to get the hooks for
    function getHooksForStrategy(address strategyId_) external view returns (address[] memory);

    /// @notice Delist a strategy
    /// @param strategyId_ The id of the strategy to delist
    function delistStrategy(address strategyId_) external;

    /// @notice Register a strategy
    /// @param hooks_ The addresses of the hooks to register
    function registerStrategy(address[] memory hooks_) external returns (address);

    /// @notice Accept a pending strategy registration
    /// @param strategyId_ The id of the strategy to accept the registration for
    function acceptStrategyRegistration(address strategyId_) external;

    /// @notice Vote for a strategy
    /// @param strategyId_ The id of the strategy to vote for
    function vote(address strategyId_) external;
}
