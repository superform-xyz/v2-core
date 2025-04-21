// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Interfaces
import { ISuperAdjudicator } from "./interfaces/ISuperAdjudicator.sol";
import { IPeripheryRegistry } from "./interfaces/IPeripheryRegistry.sol";
import { IOracle } from "../vendor/awesome-oracles/IOracle.sol";

// External
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol"; // Using Ownable for simplicity, could
    // use AccessControl
import { ReentrancyGuard } from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20, IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";

/// @title SuperAdjudicator
/// @author SuperForm Labs
/// @notice Manages staking for strategists and disputers, handles PPS disputes, and executes slashing based on
/// off-chain adjudication.
/// @dev Uses Ownable for admin control. A more robust system might use AccessControl.
contract SuperAdjudicator is ISuperAdjudicator, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address public adjudicator; // Address authorized to resolve disputes

    /*//////////////////////////////////////////////////////////////
                                STATE
    //////////////////////////////////////////////////////////////*/

    address public override peripheryRegistry;

    // Configuration
    uint256 public override minStrategistStake;
    uint256 public override disputeStakeRequired;
    uint256 public override unstakeQueueDuration; // In seconds
    uint256 public override disputeWindowBlocks; // Max blocks old a PPS update can be disputed
    uint256 public override maxChallengerReward; // Max $UP reward for successful dispute
    uint256 public override baseSlashBps; // Base slash percentage (1% = 100 BPS)

    // Staking Data
    mapping(address staker => StakeInfo info) public stakeInfo;
    mapping(address strategist => bool isRegistered) public registeredStrategists; // Tracks registered strategists

    // Dispute Data
    mapping(uint256 disputeId => DisputeInfo info) public disputeInfo; // Maps disputeId to info
    mapping(bytes32 disputeTxHash => mapping(uint256 blockNumber => mapping(address strategy => bool isDisputed)))
        public disputedTxHashes;

    uint256 public disputeId;
    // Internal tracking
    uint256 public totalStaked; // Total $UP staked in the contract

    // Constants for staking token in periphery registry
    bytes32 private constant STAKING_TOKEN_KEY = keccak256("STAKING_TOKEN");
    // Constants for reward token in periphery registry
    bytes32 private constant REWARD_TOKEN_KEY = keccak256("REWARD_TOKEN");
    // Constants for SuperOracle in periphery registry
    bytes32 private constant SUPER_ORACLE_KEY = keccak256("SUPER_ORACLE");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR & INITIALIZER
    //////////////////////////////////////////////////////////////*/

    // Using Ownable, owner() is the admin
    constructor(
        address _initialOwner,
        address _adjudicator,
        address _peripheryRegistry,
        uint256 _minStrategistStake,
        uint256 _disputeStakeRequired,
        uint256 _unstakeQueueDuration,
        uint256 _disputeWindowBlocks,
        uint256 _maxChallengerReward,
        uint256 _baseSlashBps
    )
        Ownable(_initialOwner)
    {
        if (_adjudicator == address(0)) revert ZERO_ADDRESS();
        if (_peripheryRegistry == address(0)) revert ZERO_ADDRESS();
        if (_minStrategistStake == 0) revert INVALID_CONFIGURATION();
        if (_disputeStakeRequired == 0) revert INVALID_CONFIGURATION();
        // Allow 0 for unstake duration or dispute window? Let's require > 0 for now.
        if (_unstakeQueueDuration == 0) revert INVALID_CONFIGURATION();
        if (_disputeWindowBlocks == 0) revert INVALID_CONFIGURATION();
        if (_baseSlashBps == 0) revert INVALID_CONFIGURATION();

        // Validate registry has treasury set
        address treasury = IPeripheryRegistry(_peripheryRegistry).getTreasury();
        if (treasury == address(0)) revert ZERO_ADDRESS();

        adjudicator = _adjudicator;
        peripheryRegistry = _peripheryRegistry;
        minStrategistStake = _minStrategistStake;
        disputeStakeRequired = _disputeStakeRequired;
        unstakeQueueDuration = _unstakeQueueDuration;
        disputeWindowBlocks = _disputeWindowBlocks;
        maxChallengerReward = _maxChallengerReward;
        baseSlashBps = _baseSlashBps;

        emit Initialized(_peripheryRegistry, _initialOwner, _adjudicator);
        emit ConfigUpdated("minStrategistStake", _minStrategistStake);
        emit ConfigUpdated("disputeStakeRequired", _disputeStakeRequired);
        emit ConfigUpdated("unstakeQueueDuration", _unstakeQueueDuration);
        emit ConfigUpdated("disputeWindowBlocks", _disputeWindowBlocks);
        emit ConfigUpdated("maxChallengerReward", _maxChallengerReward);
        emit ConfigUpdated("baseSlashBps", _baseSlashBps);
        emit RoleAddressUpdated(keccak256("ADJUDICATOR_ROLE"), _adjudicator);
    }

    // No separate initializer needed as using constructor

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyAdjudicator() {
        if (msg.sender != adjudicator) revert ACCESS_DENIED();
        _;
    }

    // Ownable provides onlyOwner modifier for admin functions

    /*//////////////////////////////////////////////////////////////
                            CONFIGURATION VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // Configuration view functions already defined by public state variables

    /*//////////////////////////////////////////////////////////////
                            ROLE MANAGEMENT VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function isStrategist(address account) public view override returns (bool) {
        return registeredStrategists[account];
    }

    /// @notice Gets the address associated with a specific role (adapting for Ownable).
    function getRoleAddress(bytes32 role) public view override returns (address) {
        if (role == keccak256("ADMIN_ROLE")) {
            return owner();
        } else if (role == keccak256("ADJUDICATOR_ROLE")) {
            return adjudicator;
        }
        revert INVALID_ROLE();
    }

    /*//////////////////////////////////////////////////////////////
                        PERIPHERY REGISTRY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAdjudicator
    function setPeripheryRegistry(address _peripheryRegistry) external override onlyOwner {
        if (_peripheryRegistry == address(0)) revert ZERO_ADDRESS();

        // Validate registry has treasury set
        address treasury = IPeripheryRegistry(_peripheryRegistry).getTreasury();
        if (treasury == address(0)) revert ZERO_ADDRESS();

        peripheryRegistry = _peripheryRegistry;
        emit PeripheryRegistryUpdated(_peripheryRegistry);
    }

    /// @dev Internal helper to get the staking token from registry
    function _getStakingToken() internal view returns (IERC20) {
        if (peripheryRegistry == address(0)) revert PERIPHERY_REGISTRY_NOT_SET();

        // Get stakingToken from periphery registry using the new getter
        address stakingTokenAddress = IPeripheryRegistry(peripheryRegistry).getStakingToken();
        if (stakingTokenAddress == address(0)) revert ZERO_ADDRESS();
        return IERC20(stakingTokenAddress);
    }

    /// @dev Internal helper to get the treasury from registry
    function _getTreasury() internal view returns (address) {
        if (peripheryRegistry == address(0)) revert PERIPHERY_REGISTRY_NOT_SET();
        address treasury = IPeripheryRegistry(peripheryRegistry).getTreasury();
        if (treasury == address(0)) revert ZERO_ADDRESS();
        return treasury;
    }

    /// @dev Internal helper to get the SuperOracle from registry
    function _getSuperOracle() internal view returns (IOracle) {
        if (peripheryRegistry == address(0)) revert PERIPHERY_REGISTRY_NOT_SET();

        // Get SuperOracle from periphery registry
        address superOracleAddress = IPeripheryRegistry(peripheryRegistry).getSuperOracle();
        if (superOracleAddress == address(0)) revert ZERO_ADDRESS();
        return IOracle(superOracleAddress);
    }

    /// @dev Internal helper to get the reward token from registry
    function _getRewardToken() internal view returns (address) {
        if (peripheryRegistry == address(0)) revert PERIPHERY_REGISTRY_NOT_SET();

        // Get reward token from periphery registry
        address rewardTokenAddress = IPeripheryRegistry(peripheryRegistry).getRewardToken();
        if (rewardTokenAddress == address(0)) revert ZERO_ADDRESS();
        return rewardTokenAddress;
    }

    /*//////////////////////////////////////////////////////////////
                        STAKING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAdjudicator
    function stake(uint256 amount) external override nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();

        StakeInfo storage staker = stakeInfo[msg.sender];
        bool isStrat = registeredStrategists[msg.sender];

        // If strategist, ensure stake remains >= min requirement after adding
        if (isStrat && staker.totalStake + amount < minStrategistStake) {
            // This check might be redundant if we only check on unstake/slash,
            // but good for explicit clarity during staking.
            revert STAKE_TOO_LOW();
        }

        staker.totalStake += amount;
        staker.isStrategist = isStrat; // Update in case they were registered after first stake

        totalStaked += amount;

        // Get stakingToken from registry
        IERC20 stakingToken = _getStakingToken();
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(msg.sender, isStrat, amount);
    }

    /// @inheritdoc ISuperAdjudicator
    function requestUnstake(uint256 amount) external override nonReentrant {
        if (amount == 0) revert ZERO_AMOUNT();
        StakeInfo storage staker = stakeInfo[msg.sender];
        if (amount > staker.totalStake) revert INSUFFICIENT_STAKE();
        if (staker.unstakeRequestAmount > 0) revert UNSTAKE_QUEUE_ACTIVE(); // Only one request at a time
        if (staker.activeDisputes > 0) revert CANNOT_UNSTAKE_DURING_DISPUTE(); // Cannot unstake if involved in disputes

        // If strategist, ensure remaining stake meets minimum requirement
        if (staker.isStrategist && staker.totalStake - amount < minStrategistStake) {
            revert STAKE_TOO_LOW();
        }

        staker.unstakeRequestAmount = amount;
        staker.unstakeAvailableAt = block.timestamp + unstakeQueueDuration;

        emit UnstakeRequested(msg.sender, amount, staker.unstakeAvailableAt);
    }

    /// @inheritdoc ISuperAdjudicator
    function unstake() external override nonReentrant {
        StakeInfo storage staker = stakeInfo[msg.sender];
        uint256 amountToUnstake = staker.unstakeRequestAmount;

        if (amountToUnstake == 0) revert NOT_IN_UNSTAKE_QUEUE();
        if (block.timestamp < staker.unstakeAvailableAt) revert UNSTAKE_NOT_READY();

        // Re-check strategist minimum stake in case config changed or they were slashed
        if (staker.isStrategist && staker.totalStake - amountToUnstake < minStrategistStake) {
            // This might prevent unstaking if slashed below min during queue. Is this desired?
            // Alternative: allow unstake but potentially make them unable to act as strategist.
            // For now, prevent unstake to maintain min stake requirement strictly.
            revert STAKE_TOO_LOW();
        }

        // Reset unstake request
        staker.unstakeRequestAmount = 0;
        staker.unstakeAvailableAt = 0;

        // Update stake amounts
        staker.totalStake -= amountToUnstake;
        totalStaked -= amountToUnstake;

        // Get stakingToken from registry and transfer tokens back
        IERC20 stakingToken = _getStakingToken();
        stakingToken.safeTransfer(msg.sender, amountToUnstake);

        emit Unstaked(msg.sender, amountToUnstake);
    }

    /// @inheritdoc ISuperAdjudicator
    function getStakeInfo(address account) public view override returns (StakeInfo memory) {
        return stakeInfo[account];
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGIST REGISTRATION (Admin)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAdjudicator
    function registerStrategist(address strategist) external override onlyOwner {
        if (strategist == address(0)) revert ZERO_ADDRESS();
        if (registeredStrategists[strategist]) revert ALREADY_REGISTERED();
        registeredStrategists[strategist] = true;
        // Update stakeInfo if they already staked
        if (stakeInfo[strategist].totalStake > 0) {
            stakeInfo[strategist].isStrategist = true;
        }
        emit StrategistRegistered(strategist);
    }

    /// @inheritdoc ISuperAdjudicator
    function unregisterStrategist(address strategist) external override onlyOwner {
        if (!registeredStrategists[strategist]) revert NOT_REGISTERED();

        // Check if the strategist has any ongoing disputes
        StakeInfo storage strategistStake = stakeInfo[strategist];
        if (strategistStake.activeDisputes > 0) revert CANNOT_UNREGISTER_DURING_DISPUTE();

        // Prevent unregistering if stake is below min? Or just let them be inactive?
        // Let's allow unregistering, but they can't act as strategist without meeting stake if re-registered.
        registeredStrategists[strategist] = false;
        // Update stakeInfo
        stakeInfo[strategist].isStrategist = false;
        emit StrategistUnregistered(strategist);
    }

    /*//////////////////////////////////////////////////////////////
                        DISPUTE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAdjudicator
    function disputePPS(
        address strategy_,
        uint256 disputeBlockNumber_,
        bytes32 disputeTxHash_
    )
        external
        override
        nonReentrant
        returns (uint256)
    {
        StakeInfo storage disputerStake = stakeInfo[msg.sender];
        // Requester must have at least disputeStakeRequired staked *in total*
        if (disputerStake.totalStake < disputeStakeRequired) revert INSUFFICIENT_STAKE();

        // Check if the hash is already under dispute
        if (disputedTxHashes[disputeTxHash_][disputeBlockNumber_][strategy_]) revert ALREADY_IN_DISPUTE();

        if (disputeBlockNumber_ == 0 || disputeBlockNumber_ >= block.number) revert INVALID_BLOCK_NUMBER();
        if (block.number - disputeBlockNumber_ > disputeWindowBlocks) revert DISPUTE_WINDOW_PASSED();

        disputedTxHashes[disputeTxHash_][disputeBlockNumber_][strategy_] = true;

        // Increment active disputes counter
        disputerStake.activeDisputes += 1;

        // Store dispute info (strategist address filled later)
        disputeInfo[++disputeId] = DisputeInfo({
            strategy: strategy_,
            strategist: address(0), // To be filled by adjudicator
            disputer: msg.sender,
            blockNumber: disputeBlockNumber_,
            txHash: disputeTxHash_,
            submittedAt: block.timestamp,
            status: DisputeStatus.Pending,
            realPPS: 0,
            disputedPPS: 0,
            updateTimestamp: 0 // To be filled by adjudicator
         });

        emit PPSDisputed(strategy_, msg.sender, disputeBlockNumber_, disputeTxHash_);

        return disputeId;
    }

    /// @inheritdoc ISuperAdjudicator
    function resolveDispute(
        uint256 disputeId_,
        bool strategistFault_,
        address strategist_,
        uint256 realPPS_,
        uint256 disputedPPS_,
        uint256 ppsUpdateTimestamp_
    )
        external
        override
        onlyAdjudicator // Only the designated adjudicator can resolve
        nonReentrant
    {
        // Create local variables struct
        ResolveDisputeVars memory vars;

        // Validate inputs and dispute state
        _validateDisputeResolution(disputeId_, strategist_);

        // Get dispute and staker info
        DisputeInfo storage dispute = disputeInfo[disputeId_];
        StakeInfo storage strategistStake = stakeInfo[strategist_];
        StakeInfo storage disputerStake = stakeInfo[dispute.disputer];

        // Update dispute details
        _updateDisputeDetails(dispute, strategist_, realPPS_, disputedPPS_, ppsUpdateTimestamp_);

        dispute.status =
            strategistFault_ ? DisputeStatus.Resolved_StrategistFault : DisputeStatus.Resolved_DisputerFault;

        vars.totalStake = strategistFault_ ? strategistStake.totalStake : disputerStake.totalStake;

        // presumes same calculation method for both strategist and disputer
        (vars.slashAmount, vars.reward) = _calculateSlashAndReward(
            SlashCalcArgs({
                totalStrategistStake: vars.totalStake,
                realPPS: realPPS_,
                disputedPPS: disputedPPS_,
                ppsUpdateTimestamp: ppsUpdateTimestamp_
            })
        );

        if (vars.slashAmount > 0) {
            if (strategistFault_) {
                if (vars.slashAmount > strategistStake.totalStake) {
                    vars.slashAmount = strategistStake.totalStake; // Cannot slash more than staked
                }

                strategistStake.totalStake -= vars.slashAmount;
                totalStaked -= vars.slashAmount;

                emit StrategistSlashed(disputeId_, strategist_, vars.slashAmount, strategistStake.totalStake);
            } else {
                disputerStake.totalStake -= vars.slashAmount;
                totalStaked -= vars.slashAmount;

                emit DisputerSlashed(disputeId_, strategist_, vars.slashAmount, disputerStake.totalStake);
            }
            _transferSlashedFunds(vars.slashAmount);
        }
        vars.disputer = dispute.disputer;
        if (vars.reward > 0) {
            // Get the staking token, reward token, and SuperOracle
            vars.stakingToken = _getStakingToken();
            vars.rewardTokenAddress = _getRewardToken();
            vars.superOracle = _getSuperOracle();

            // Get the equivalent amount in reward token
            vars.rewardAmount =
                vars.superOracle.getQuote(vars.reward, address(vars.stakingToken), vars.rewardTokenAddress);

            if (vars.rewardAmount > 0) {
                // Transfer reward tokens to disputer
                IERC20(vars.rewardTokenAddress).safeTransfer(vars.disputer, vars.rewardAmount);

                // Emit event about reward payment
                emit RewardPaid(disputeId_, vars.disputer, vars.rewardTokenAddress, vars.rewardAmount);
            }
        }

        disputerStake.activeDisputes -= 1;
        strategistStake.activeDisputes -= 1;

        emit DisputeResolved(disputeId_, strategistFault_, strategist_, vars.disputer, vars.slashAmount, vars.reward);
    }

    /// @dev Validates dispute resolution inputs
    function _validateDisputeResolution(uint256 disputeId_, address strategist_) internal view {
        DisputeInfo storage dispute = disputeInfo[disputeId_];
        if (!disputedTxHashes[dispute.txHash][dispute.blockNumber][dispute.strategy]) {
            revert DISPUTED_TX_HASH_NOT_FOUND();
        }
        if (dispute.disputer == address(0)) revert DISPUTE_NOT_FOUND();
        if (dispute.status != DisputeStatus.Pending) revert DISPUTE_ALREADY_RESOLVED();
        if (strategist_ == address(0)) revert INVALID_STAKEHOLDER();

        // Ensure stakers exist
        if (stakeInfo[strategist_].totalStake == 0) revert INVALID_STAKEHOLDER();
        if (stakeInfo[dispute.disputer].totalStake == 0) revert INVALID_STAKEHOLDER();
    }

    /// @dev Updates dispute details with adjudicator-provided information
    function _updateDisputeDetails(
        DisputeInfo storage dispute,
        address strategist_,
        uint256 realPPS_,
        uint256 disputedPPS_,
        uint256 ppsUpdateTimestamp_
    )
        internal
    {
        dispute.strategist = strategist_;
        dispute.realPPS = realPPS_;
        dispute.disputedPPS = disputedPPS_;
        dispute.updateTimestamp = ppsUpdateTimestamp_;

        // Increment strategist's active disputes counter
        StakeInfo storage strategistStake = stakeInfo[strategist_];
        strategistStake.activeDisputes += 1;
    }

    /// @inheritdoc ISuperAdjudicator
    function getDisputeInfo(uint256 disputeId_) public view override returns (DisputeInfo memory) {
        return disputeInfo[disputeId_];
    }

    /*//////////////////////////////////////////////////////////////
                        CONFIGURATION FUNCTIONS (Admin)
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc ISuperAdjudicator
    function updateConfig(
        uint256 minStrategistStake_,
        uint256 disputeStakeRequired_,
        uint256 unstakeQueueDuration_,
        uint256 disputeWindowBlocks_,
        uint256 maxChallengerReward_,
        uint256 baseSlashBps_
    )
        external
        override
        onlyOwner // Admin function
    {
        if (minStrategistStake_ == 0) revert INVALID_CONFIGURATION();
        if (disputeStakeRequired_ == 0) revert INVALID_CONFIGURATION();
        if (unstakeQueueDuration_ == 0) revert INVALID_CONFIGURATION();
        if (disputeWindowBlocks_ == 0) revert INVALID_CONFIGURATION();
        if (baseSlashBps_ == 0) revert INVALID_CONFIGURATION();
        // Allow 0 max reward

        minStrategistStake = minStrategistStake_;
        disputeStakeRequired = disputeStakeRequired_;
        unstakeQueueDuration = unstakeQueueDuration_;
        disputeWindowBlocks = disputeWindowBlocks_;
        maxChallengerReward = maxChallengerReward_;
        baseSlashBps = baseSlashBps_;

        emit ConfigUpdated("minStrategistStake", minStrategistStake_);
        emit ConfigUpdated("disputeStakeRequired", disputeStakeRequired_);
        emit ConfigUpdated("unstakeQueueDuration", unstakeQueueDuration_);
        emit ConfigUpdated("disputeWindowBlocks", disputeWindowBlocks_);
        emit ConfigUpdated("maxChallengerReward", maxChallengerReward_);
        emit ConfigUpdated("baseSlashBps", baseSlashBps_);
    }

    /// @inheritdoc ISuperAdjudicator
    function setRoleAddress(bytes32 role_, address account_) external override onlyOwner {
        if (account_ == address(0)) revert ZERO_ADDRESS();
        if (role_ == keccak256("ADMIN_ROLE")) {
            // Transfer ownership if changing admin
            transferOwnership(account_);
        } else if (role_ == keccak256("ADJUDICATOR_ROLE")) {
            adjudicator = account_;
        } else {
            revert INVALID_ROLE();
        }
        emit RoleAddressUpdated(role_, account_);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculates the slash amount for a strategist and the reward for the disputer.
    /// @param args The arguments for the slash calculation.
    /// @return slashAmount The amount of stake to slash from the strategist.
    /// @return disputerReward The amount of reward ($UP equivalent) for the disputer.
    function _calculateSlashAndReward(SlashCalcArgs memory args)
        internal
        view
        returns (uint256 slashAmount, uint256 disputerReward)
    {
        SlashCalcVars memory vars;

        // PRD: SA = f(deltaT, deltaPPS)
        // deltaT = block.timestamp - ppsUpdateTimestamp
        // deltaPPS = abs(realPPS - disputedPPS)

        vars.deltaT = block.timestamp > args.ppsUpdateTimestamp ? block.timestamp - args.ppsUpdateTimestamp : 0;
        vars.deltaPPS =
            args.realPPS > args.disputedPPS ? args.realPPS - args.disputedPPS : args.disputedPPS - args.realPPS;

        // --- Define Slashing Function f(deltaT, deltaPPS) ---
        // This needs careful design based on desired penalty severity.
        // Example: Slash a percentage of stake, increasing with deltaPPS and decreasing with deltaT.
        // Let's use a simple linear approach for demonstration.
        // Need a base percentage, a PPS deviation factor, and a time decay factor.

        // Normalize deltaPPS (e.g., express as basis points difference relative to realPPS)
        vars.deltaPPS_Bps = 0;
        if (args.realPPS > 0) {
            // Scale deltaPPS by 10000 for BPS, divide by realPPS
            vars.deltaPPS_Bps = vars.deltaPPS.mulDiv(10_000, args.realPPS, Math.Rounding.Ceil);
        }

        // Use the configurable baseSlashBps (e.g., 1% = 100 BPS)

        // Increase slash based on deviation severity (e.g., multiply by deltaPPS_Bps/10?)
        // Cap the multiplier to prevent extreme slashes.
        vars.severityFactor = Math.min(vars.deltaPPS_Bps / 10, 100); // Max factor of 100 (e.g., 10% deviation)

        // Time decay: Reduce slash amount the older the dispute resolution is.
        // Example: Full slash within 1 day, halves every week?
        vars.decayFactor = 10_000; // Start at 100% (BPS)
        vars.oneDay = 1 days;
        vars.oneWeek = 7 days;
        if (vars.deltaT > vars.oneDay) {
            // Simple linear decay example: reduce by 10% per week after the first day
            vars.weeksPassed = (vars.deltaT - vars.oneDay) / vars.oneWeek;
            vars.decayReduction = Math.min(vars.weeksPassed * 1000, 9000); // Max 90% reduction
            vars.decayFactor -= vars.decayReduction;
        }

        // Calculate final slash percentage
        vars.finalSlashBps =
            (baseSlashBps * (100 + vars.severityFactor) / 100).mulDiv(vars.decayFactor, 10_000, Math.Rounding.Floor);

        // Calculate slash amount based on total stake
        slashAmount = args.totalStrategistStake.mulDiv(vars.finalSlashBps, 10_000, Math.Rounding.Floor);

        // Calculate disputer reward
        disputerReward = Math.min(slashAmount, maxChallengerReward);

        // Ensure slashAmount is not more than available stake (handled in resolveDispute)
        return (slashAmount, disputerReward);
    }

    /// @dev Transfers slashed funds to the treasury.
    function _transferSlashedFunds(uint256 amount) internal {
        if (amount > 0) {
            // Get the treasury address from registry
            address treasury = _getTreasury();
            // Get stakingToken from registry
            IERC20 stakingToken = _getStakingToken();

            // Transfer from this contract's balance to treasury
            stakingToken.safeTransfer(treasury, amount);
        }
    }
}
