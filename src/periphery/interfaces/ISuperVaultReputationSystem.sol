// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @title ISuperVaultReputationSystem
/// @notice Interface for managing strategist and disputer stakes, handling disputes, and slashing.
/// @author SuperForm Labs
interface ISuperVaultReputationSystem {
    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @param amount Amount requested to unstake.
    /// @param availableTimestamp Timestamp when the unstake becomes available.
    struct UnstakeRequest {
        uint256 amount;
        uint256 availableTimestamp;
    }

    /// @param disputer The address of the disputer.
    /// @param status The current status of the dispute.
    /// @param stake The amount staked by the disputer for this dispute.
    /// @param rewardAmount Amount rewarded to the disputer if successful.
    /// @param slashAmount Amount slashed from the strategist/disputer.
    struct DisputeInfo {
        address disputer;
        DisputeStatus status;
        uint256 stake;
        uint256 rewardAmount;
        uint256 slashAmount;
    }

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    enum DisputeStatus {
        Open, // Dispute has been raised
        Slashed, // Strategist was slashed
        Failed, // Dispute failed, disputer slashed
        Resolved // Dispute closed (e.g., after reward/slash payout)

    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event AdminUpdated(address indexed newAdmin);
    event AdjudicatorUpdated(address indexed newAdjudicator);
    event UpTokenUpdated(address indexed newUpToken);
    event SuperOracleUpdated(address indexed newSuperOracle);
    event TreasuryUpdated(address indexed newTreasury);
    event MinStrategistStakeUpdated(uint256 newMinStake);
    event UnstakeQueuePeriodUpdated(uint256 newPeriod);
    event MaxChallengerRewardUpdated(uint256 newMaxReward);

    event StrategistRegistered(address indexed strategist);
    event StakeDeposited(address indexed staker, uint256 amount, bool isStrategist);
    event UnstakeRequested(address indexed staker, uint256 amount, uint256 availableTimestamp);
    event UnstakeCompleted(address indexed staker, uint256 amount);
    event DisputeRaised(
        bytes32 indexed disputeId,
        address indexed strategy,
        uint256 updateBlockNumber,
        bytes32 updateTxHash,
        address indexed disputer,
        uint256 disputerStake
    );
    event StrategistSlashed(
        bytes32 indexed disputeId,
        address indexed strategist,
        uint256 slashAmount,
        address indexed disputer,
        uint256 rewardAmount
    );
    event DisputeFailed(bytes32 indexed disputeId, address indexed disputer, uint256 slashAmount);
    event DisputeResolved(bytes32 indexed disputeId, DisputeStatus finalStatus);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error ZeroAddress();
    error InvalidAmount();
    error NotAdmin();
    error NotAdjudicator();
    error NotRegisteredStrategist();
    error AlreadyRegisteredStrategist();
    error InsufficientStake();
    error CallerNotStaker();
    error StakeBelowMinimum();
    error UnstakeQueueActive();
    error InvalidUnstakeAmount();
    error NoUnstakeRequest();
    error OngoingDisputeCannotUnstake();
    error InvalidDisputeWindow();
    error DisputeAlreadyExists();
    error DisputeNotFound();
    error InvalidDisputeStatus();
    error InvalidSlashAmount();
    error InvalidTxHash();
    error ArithmeticError();
    error OracleConversionFailed();
    error TransferFailed();

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setAdmin(address newAdmin) external;
    function setAdjudicator(address newAdjudicator) external;
    function setUpToken(address newUpToken) external;
    function setSuperOracle(address newSuperOracle) external;
    function setTreasury(address newTreasury) external;
    function setMinStrategistStake(uint256 newMinStake) external;
    function setUnstakeQueuePeriod(uint256 newPeriod) external;
    function setMaxChallengerReward(uint256 newMaxReward) external;

    /*//////////////////////////////////////////////////////////////
                        STAKING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows an admin-approved strategist to register.
    /// @param strategist The address of the strategist to register.
    function registerStrategist(address strategist) external;

    /// @notice Allows registered strategists or any disputer to deposit stake.
    /// @dev Requires UP token approval.
    /// @param amount The amount of UP tokens to stake.
    function stake(uint256 amount) external;

    /// @notice Initiates the unstaking process for a staker.
    /// @param amount The amount of UP tokens to request unstaking for.
    function unstakeRequest(uint256 amount) external;

    /// @notice Completes the unstaking process after the queue period.
    /// @dev Can only be called after the unstake queue period has passed.
    /// @dev Fails if the staker has an ongoing dispute.
    function unstake() external;

    /*//////////////////////////////////////////////////////////////
                        DISPUTE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Raises a dispute against a specific PPS update.
    /// @dev Requires the caller (disputer) to have sufficient stake.
    /// @param strategy The address of the strategy contract where the PPS was updated.
    /// @param updateBlockNumber The block number when the disputed PPS was calculated.
    /// @param updateTxHash The transaction hash of the `updatePPS` call.
    /// @param disputerStake The amount of UP tokens the disputer stakes for this challenge.
    /// @return disputeId A unique identifier for the dispute.
    function disputePPS(
        address strategy,
        uint256 updateBlockNumber,
        bytes32 updateTxHash,
        uint256 disputerStake
    )
        external
        returns (bytes32 disputeId);

    /// @notice Called by the Adjudicator to slash a strategist if a dispute is successful.
    /// @param disputeId The unique identifier for the dispute.
    /// @param strategist The address of the strategist to slash.
    /// @param updatePPSTimestamp The timestamp of the block containing the disputed PPS update tx.
    /// @param realPPS The accurate PPS calculated by the reference oracle.
    /// @param disputedPPS The incorrect PPS submitted by the strategist.
    function slashStrategist(
        bytes32 disputeId,
        address strategist,
        uint256 updatePPSTimestamp,
        uint256 realPPS,
        uint256 disputedPPS
    )
        external;

    /// @notice Called by the Adjudicator to slash a disputer if a dispute fails.
    /// @param disputeId The unique identifier for the dispute.
    /// @param disputer The address of the disputer to slash.
    /// @param updatePPSTimestamp The timestamp of the block containing the disputed PPS update tx.
    /// @param realPPS The accurate PPS calculated by the reference oracle.
    /// @param disputedPPS The incorrect PPS submitted by the strategist.
    function slashDisputer(
        bytes32 disputeId,
        address disputer,
        uint256 updatePPSTimestamp,
        uint256 realPPS,
        uint256 disputedPPS
    )
        external;

    /// @notice Resolves a dispute after slashing/rewarding.
    /// @param disputeId The unique identifier for the dispute.
    function resolveDispute(bytes32 disputeId) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function admin() external view returns (address);
    function adjudicator() external view returns (address);
    function upToken() external view returns (IERC20);
    function superOracle() external view returns (address); // Replace with actual ISuperOracle if available
    function treasury() external view returns (address);
    function minStrategistStake() external view returns (uint256);
    function unstakeQueuePeriod() external view returns (uint256);
    function maxChallengerReward() external view returns (uint256);

    function isStrategistRegistered(address account) external view returns (bool);
    function strategistStake(address strategist) external view returns (uint256);
    function disputerStake(address disputer, bytes32 disputeId) external view returns (uint256);
    function totalStake(address account) external view returns (uint256); // Sum of strategist + all active dispute
        // stakes
    function getUnstakeRequest(address staker) external view returns (UnstakeRequest memory);
    function getDisputeInfo(bytes32 disputeId) external view returns (DisputeInfo memory);
    function hasOngoingDispute(address account) external view returns (bool);
}
