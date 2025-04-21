// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IOracle } from "../../vendor/awesome-oracles/IOracle.sol";

/// @title ISuperAdjudicator
/// @author SuperForm Labs
/// @notice Interface for the SuperAdjudicator contract, managing strategist/disputer staking, PPS disputes, and
/// slashing.
interface ISuperAdjudicator {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZERO_ADDRESS();
    error ZERO_AMOUNT();
    error INVALID_AMOUNT();
    error ALREADY_REGISTERED();
    error NOT_REGISTERED();
    error ACCESS_DENIED();
    error INVALID_ROLE();
    error STAKE_TOO_LOW();
    error INSUFFICIENT_STAKE();
    error UNSTAKE_QUEUE_ACTIVE();
    error NOT_IN_UNSTAKE_QUEUE();
    error UNSTAKE_NOT_READY();
    error DISPUTE_WINDOW_PASSED();
    error ALREADY_IN_DISPUTE();
    error DISPUTE_NOT_FOUND();
    error DISPUTE_ALREADY_RESOLVED();
    error INVALID_DISPUTE_STATUS();
    error INVALID_STAKEHOLDER();
    error CANNOT_UNSTAKE_DURING_DISPUTE();
    error INVALID_TOKEN();
    error INVALID_CONFIGURATION();
    error TRANSFER_FAILED();
    error PERIPHERY_REGISTRY_NOT_SET();
    error DISPUTED_TX_HASH_NOT_FOUND();
    error INVALID_BLOCK_NUMBER();
    error CANNOT_UNREGISTER_DURING_DISPUTE();
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Initialized(address peripheryRegistry, address admin, address adjudicator);
    event StrategistRegistered(address indexed strategist);
    event StrategistUnregistered(address indexed strategist);
    event Staked(address indexed stakeholder, bool indexed isStrategist, uint256 amount);
    event UnstakeRequested(address indexed stakeholder, uint256 amount, uint256 availableAt);
    event Unstaked(address indexed stakeholder, uint256 amount);
    event PPSDisputed(address indexed strategy, address indexed disputer, uint256 blockNumber, bytes32 txHash);
    event DisputeResolved(
        uint256 indexed disputeId,
        bool indexed strategistFault,
        address indexed strategist,
        address disputer,
        uint256 slashAmount,
        uint256 reward
    );
    event StrategistSlashed(
        uint256 indexed disputeId, address indexed strategist, uint256 slashAmount, uint256 remainingStake
    );
    event DisputerSlashed(
        uint256 indexed disputeId, address indexed disputer, uint256 slashAmount, uint256 remainingStake
    );
    event ConfigUpdated(string indexed key, uint256 value);
    event RoleAddressUpdated(bytes32 indexed role, address indexed account);
    event PeripheryRegistryUpdated(address peripheryRegistry);
    event RewardPaid(uint256 indexed disputeId, address indexed disputer, address rewardToken, uint256 rewardAmount);

    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Represents the status and details of a PPS dispute.
    enum DisputeStatus {
        Pending, // Dispute initiated, awaiting adjudication
        Resolved_StrategistFault, // Resolved, strategist was at fault
        Resolved_DisputerFault // Resolved, disputer was at fault (or PPS was correct)

    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Holds staking information for a user (strategist or disputer).
    struct StakeInfo {
        uint256 totalStake; // Total amount staked
        uint256 unstakeRequestAmount; // Amount requested for unstaking
        uint256 unstakeAvailableAt; // Timestamp when unstake becomes available
        bool isStrategist; // Flag indicating if the staker is a registered strategist
        uint256 activeDisputes; // Counter for active disputes this staker is involved in
    }

    /// @notice Holds details about a specific PPS dispute.
    struct DisputeInfo {
        address strategy; // The strategy contract being disputed
        address strategist; // The strategist associated with the strategy (at time of dispute)
        address disputer; // The user who initiated the dispute
        uint256 blockNumber; // Block number of the disputed PPS update
        bytes32 txHash; // Transaction hash of the disputed PPS update
        uint256 submittedAt; // Timestamp when the dispute was submitted
        DisputeStatus status; // Current status of the dispute
        uint256 realPPS; // The correct PPS as determined by adjudication (if resolved)
        uint256 disputedPPS; // The PPS value submitted by the strategist (if resolved)
        uint256 updateTimestamp; // Timestamp of the disputed PPS update
    }

    // Local variables struct to prevent stack too deep errors
    struct SlashCalcVars {
        uint256 deltaT;
        uint256 deltaPPS;
        uint256 deltaPPS_Bps;
        uint256 severityFactor;
        uint256 decayFactor;
        uint256 oneDay;
        uint256 oneWeek;
        uint256 weeksPassed;
        uint256 decayReduction;
        uint256 finalSlashBps;
    }

    // Local variables struct to prevent stack too deep errors in resolveDispute
    struct ResolveDisputeVars {
        uint256 totalStake;
        uint256 slashAmount;
        uint256 reward;
        address disputer;
        IERC20 stakingToken;
        address rewardTokenAddress;
        IOracle superOracle;
        uint256 rewardAmount;
    }

    struct SlashCalcArgs {
        uint256 totalStrategistStake;
        uint256 realPPS;
        uint256 disputedPPS;
        uint256 ppsUpdateTimestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            PERIPHERY REGISTRY
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the address of the periphery registry.
    function peripheryRegistry() external view returns (address);

    /// @notice Sets the periphery registry address (callable by ADMIN_ROLE).
    /// @param _peripheryRegistry The new address for the periphery registry.
    function setPeripheryRegistry(address _peripheryRegistry) external;

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the minimum stake required for a strategist.
    function minStrategistStake() external view returns (uint256);

    /// @notice Returns the stake required for a user to initiate a dispute.
    function disputeStakeRequired() external view returns (uint256);

    /// @notice Returns the duration of the unstake queue in seconds.
    function unstakeQueueDuration() external view returns (uint256);

    /// @notice Returns the maximum age (in blocks) a PPS update can be disputed.
    function disputeWindowBlocks() external view returns (uint256);

    /// @notice Returns the maximum reward amount given to a successful challenger.
    function maxChallengerReward() external view returns (uint256);

    /// @notice Returns the base slash percentage in basis points.
    function baseSlashBps() external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if an address is a registered strategist.
    function isStrategist(address account) external view returns (bool);

    /// @notice Gets the address associated with a specific role.
    function getRoleAddress(bytes32 role) external view returns (address);

    /*//////////////////////////////////////////////////////////////
                        STAKING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Allows a registered strategist or any user to stake tokens.
    /// @param amount The amount of staking tokens to stake.
    function stake(uint256 amount) external;

    /// @notice Initiates the unstaking process for the caller.
    /// @param amount The amount of staking tokens to request unstaking for.
    function requestUnstake(uint256 amount) external;

    /// @notice Completes the unstaking process after the queue duration.
    function unstake() external;

    /// @notice Returns the staking information for a given address.
    function getStakeInfo(address account) external view returns (StakeInfo memory);

    /*//////////////////////////////////////////////////////////////
                        STRATEGIST REGISTRATION (Admin)
    //////////////////////////////////////////////////////////////*/

    /// @notice Registers an address as a strategist (callable by ADMIN_ROLE).
    /// @param strategist The address to register.
    function registerStrategist(address strategist) external;

    /// @notice Unregisters an address as a strategist (callable by ADMIN_ROLE).
    /// @param strategist The address to unregister.
    function unregisterStrategist(address strategist) external;

    /*//////////////////////////////////////////////////////////////
                        DISPUTE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initiates a dispute against a PPS update. Requires the caller to have sufficient stake.
    /// @param strategy The address of the SuperVaultStrategy contract.
    /// @param disputeBlockNumber The block number of the `PPSUpdated` event being disputed.
    /// @param disputeTxHash The transaction hash of the `PPSUpdated` event being disputed.
    /// @return disputeId A unique identifier for the submitted dispute.
    function disputePPS(
        address strategy,
        uint256 disputeBlockNumber,
        bytes32 disputeTxHash
    )
        external
        returns (uint256 disputeId);

    /// @notice Resolves a pending dispute (callable by ADJUDICATOR_ROLE).
    /// @param disputeId The unique identifier of the dispute to resolve.
    /// @param strategistFault True if the off-chain adjudication determined the strategist was at fault.
    /// @param strategist The strategist address associated with the disputed strategy.
    /// @param realPPS The correct PPS value determined off-chain.
    /// @param disputedPPS The incorrect PPS value submitted by the strategist.
    /// @param ppsUpdateTimestamp Timestamp of the original PPS update transaction.
    function resolveDispute(
        uint256 disputeId,
        bool strategistFault,
        address strategist,
        uint256 realPPS,
        uint256 disputedPPS,
        uint256 ppsUpdateTimestamp
    )
        external;

    /// @notice Returns the details of a specific dispute.
    function getDisputeInfo(uint256 disputeId) external view returns (DisputeInfo memory);

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS (Admin)
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates configuration parameters (callable by ADMIN_ROLE).
    /// @param _minStrategistStake New minimum strategist stake.
    /// @param _disputeStakeRequired New stake required for disputes.
    /// @param _unstakeQueueDuration New unstake queue duration.
    /// @param _disputeWindowBlocks New dispute window in blocks.
    /// @param _maxChallengerReward New maximum challenger reward.
    /// @param _baseSlashBps New base slash percentage in basis points.
    function updateConfig(
        uint256 _minStrategistStake,
        uint256 _disputeStakeRequired,
        uint256 _unstakeQueueDuration,
        uint256 _disputeWindowBlocks,
        uint256 _maxChallengerReward,
        uint256 _baseSlashBps
    )
        external;

    /// @notice Updates the address for a specific role (callable by ADMIN_ROLE).
    /// @param role The role identifier (e.g., keccak256("ADMIN_ROLE")).
    /// @param account The new address for the role.
    function setRoleAddress(bytes32 role, address account) external;
}
