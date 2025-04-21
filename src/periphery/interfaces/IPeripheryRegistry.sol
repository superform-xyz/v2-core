// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

/// @title IPeripheryRegistry
/// @author Superform Labs
/// @notice Interface for the PeripheryRegistry contract that manages periphery addresses
interface IPeripheryRegistry {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error NOT_AUTHORIZED();
    error INVALID_ACCOUNT();
    error INVALID_ADDRESS();
    error INVALID_FEE_SPLIT();
    error HOOK_NOT_REGISTERED();
    error TIMELOCK_NOT_EXPIRED();
    error HOOK_ALREADY_REGISTERED();
    error INVALID_SLIPPAGE_TOLERANCE();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event HookRegistered(address indexed hook);
    event HookUnregistered(address indexed hook);
    event FulfillRequestsHookRegistered(address indexed hook);
    event FulfillRequestsHookUnregistered(address indexed hook);
    event FeeSplitUpdated(uint256 superformFeeSplit);
    event FeeSplitProposed(uint256 superformFeeSplit, uint256 effectiveTime);
    event TreasuryUpdated(address indexed treasury);
    event SvSlippageToleranceUpdated(uint256 svSlippageTolerance);
    event SuperAdjudicatorUpdated(address indexed superAdjudicator);
    event StakingTokenUpdated(address indexed stakingToken);
    event SuperOracleUpdated(address indexed superOracle);
    event RewardTokenUpdated(address indexed rewardToken);
    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Get the current Superform fee split.
    /// @return The fee split in basis points (0-10000).

    function getSuperformFeeSplit() external view returns (uint256);

    /// @notice Get all registered hooks
    function getRegisteredHooks() external view returns (address[] memory);

    /// @notice Check if a hook is registered
    /// @param hook_ The hook to check
    /// @return True if the hook is registered, false otherwise
    function isHookRegistered(address hook_) external view returns (bool);

    /// @notice Get the current SuperVault slippage tolerance.
    /// @return The slippage tolerance in basis points (0-10000).
    function svSlippageTolerance() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @dev Set the SuperVault slippage tolerance.
    /// @param svSlippageTolerance_ The new slippage tolerance in basis points (0-10000).
    function setSvSlippageTolerance(uint256 svSlippageTolerance_) external;

    /// @notice Check if a fulfill requests hook is registered
    /// @param hook_ The hook to check
    /// @return True if the hook is registered, false otherwise
    function isFulfillRequestsHookRegistered(address hook_) external view returns (bool);

    /// @notice Register a hook
    /// @param hook_ The address of the hook to register
    /// @param isFulfillRequestsHook_ Whether this is a fulfill requests hook or a regular hook
    /// @dev Only callable by owner
    function registerHook(address hook_, bool isFulfillRequestsHook_) external;

    /// @notice Unregister a hook
    /// @param hook_ The address of the hook to unregister
    /// @param isFulfillRequestsHook_ Whether this is a fulfill requests hook or a regular hook
    /// @dev Only callable by owner
    function unregisterHook(address hook_, bool isFulfillRequestsHook_) external;

    /// @dev Propose a new fee split for Superform.
    /// @param feeSplit_ The new fee split in basis points (0-10000).
    function proposeFeeSplit(uint256 feeSplit_) external;

    /// @dev Execute the proposed fee split update after timelock.
    function executeFeeSplitUpdate() external;

    /// @dev Get the treasury address.
    /// @return The treasury address.
    function getTreasury() external view returns (address);

    /// @dev Set the treasury address.
    /// @param treasury_ The new treasury address.
    function setTreasury(address treasury_) external;

    /// @dev Set the super adjudicator address.
    /// @param superAdjudicator_ The new super adjudicator address.
    function setSuperAdjudicator(address superAdjudicator_) external;

    /// @dev Get the reputation system address.
    /// @return The reputation system address.
    function getReputationSystem() external view returns (address);

    /// @dev Get the super adjudicator address.
    /// @return The super adjudicator address.
    function getSuperAdjudicator() external view returns (address);

    /// @dev Get the staking token address.
    /// @return The staking token address used by the reputation system.
    function getStakingToken() external view returns (address);

    /// @dev Set the staking token address.
    /// @param stakingToken_ The new staking token address.
    function setStakingToken(address stakingToken_) external;

    /// @dev Get the Super Oracle address.
    /// @return The Super Oracle address.
    function getSuperOracle() external view returns (address);

    /// @dev Set the Super Oracle address.
    /// @param superOracle_ The new Super Oracle address.
    function setSuperOracle(address superOracle_) external;

    /// @dev Get the reward token address.
    /// @return The reward token address.
    function getRewardToken() external view returns (address);

    /// @dev Set the reward token address.
    /// @param rewardToken_ The new reward token address.
    function setRewardToken(address rewardToken_) external;
}
