// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// external
import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";

// Superform
import { IPeripheryRegistry } from "./interfaces/IPeripheryRegistry.sol";

/// @title PeripheryRegistry
/// @author Superform Labs
/// @notice A registry for periphery configurations
contract PeripheryRegistry is Ownable2Step, IPeripheryRegistry {
    /*//////////////////////////////////////////////////////////////
                                 STORAGE
    //////////////////////////////////////////////////////////////*/
    mapping(address => bool) public isHookRegistered;
    mapping(address => bool) public isFulfillRequestsHookRegistered;
    address[] public registeredHooks;
    address[] public registeredFulfillRequestsHooks;

    address private treasury;
    address private superAdjudicator;
    address private superOracle;
    address private stakingToken;
    address private rewardToken;

    uint256 private feeSplit;
    uint256 private proposedFeeSplit;
    uint256 private feeSplitEffectiveTime;

    uint256 public svSlippageTolerance;

    // Fee split configuration
    uint256 private constant ONE_WEEK = 7 days;
    uint256 private constant MAX_FEE_SPLIT = 10_000;

    constructor(address owner_, address treasury_) Ownable(owner_) {
        if (owner_ == address(0)) revert INVALID_ACCOUNT();
        if (treasury_ == address(0)) revert INVALID_ADDRESS();

        // Initialize with a default fee split of 20% (2000 basis points)
        feeSplit = 2000;

        treasury = treasury_;
        emit TreasuryUpdated(treasury_);

        svSlippageTolerance = 100; // 1%
    }

    /*//////////////////////////////////////////////////////////////
                                 OWNER METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IPeripheryRegistry
    function setSvSlippageTolerance(uint256 svSlippageTolerance_) external onlyOwner {
        if (svSlippageTolerance_ > 10_000) revert INVALID_SLIPPAGE_TOLERANCE();
        svSlippageTolerance = svSlippageTolerance_;
        emit SvSlippageToleranceUpdated(svSlippageTolerance_);
    }

    /// @inheritdoc IPeripheryRegistry
    function registerHook(address hook_, bool isFulfillRequestsHook_) external onlyOwner {
        if (hook_ == address(0)) revert INVALID_ADDRESS();

        if (isFulfillRequestsHook_) {
            if (isFulfillRequestsHookRegistered[hook_]) revert HOOK_ALREADY_REGISTERED();
            isFulfillRequestsHookRegistered[hook_] = true;
            registeredFulfillRequestsHooks.push(hook_);
            emit FulfillRequestsHookRegistered(hook_);
        }

        if (!isHookRegistered[hook_]) {
            isHookRegistered[hook_] = true;
            registeredHooks.push(hook_);
            emit HookRegistered(hook_);
        } else if (!isFulfillRequestsHook_) {
            revert HOOK_ALREADY_REGISTERED();
        }
    }

    /// @inheritdoc IPeripheryRegistry
    function unregisterHook(address hook_, bool isFulfillRequestsHook_) external onlyOwner {
        if (isFulfillRequestsHook_) {
            if (!isFulfillRequestsHookRegistered[hook_]) revert HOOK_NOT_REGISTERED();
            isFulfillRequestsHookRegistered[hook_] = false;

            // Remove from fulfill requests hooks array
            for (uint256 i = 0; i < registeredFulfillRequestsHooks.length; i++) {
                if (registeredFulfillRequestsHooks[i] == hook_) {
                    registeredFulfillRequestsHooks[i] =
                        registeredFulfillRequestsHooks[registeredFulfillRequestsHooks.length - 1];
                    registeredFulfillRequestsHooks.pop();
                    break;
                }
            }
            emit FulfillRequestsHookUnregistered(hook_);
        }

        if (isHookRegistered[hook_]) {
            isHookRegistered[hook_] = false;

            // Remove from regular hooks array
            for (uint256 i = 0; i < registeredHooks.length; i++) {
                if (registeredHooks[i] == hook_) {
                    registeredHooks[i] = registeredHooks[registeredHooks.length - 1];
                    registeredHooks.pop();
                    break;
                }
            }
            emit HookUnregistered(hook_);
        } else if (!isFulfillRequestsHook_) {
            revert HOOK_NOT_REGISTERED();
        }
    }

    /// @inheritdoc IPeripheryRegistry
    function proposeFeeSplit(uint256 feeSplit_) external onlyOwner {
        if (feeSplit_ > MAX_FEE_SPLIT) revert INVALID_FEE_SPLIT();

        proposedFeeSplit = feeSplit_;
        feeSplitEffectiveTime = block.timestamp + ONE_WEEK;

        emit FeeSplitProposed(feeSplit_, feeSplitEffectiveTime);
    }

    /// @inheritdoc IPeripheryRegistry
    function executeFeeSplitUpdate() external {
        if (feeSplitEffectiveTime == 0 || block.timestamp < feeSplitEffectiveTime) revert TIMELOCK_NOT_EXPIRED();

        feeSplit = proposedFeeSplit;
        proposedFeeSplit = 0;
        feeSplitEffectiveTime = 0;

        emit FeeSplitUpdated(feeSplit);
    }

    /// @inheritdoc IPeripheryRegistry
    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert INVALID_ADDRESS();
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    /// @inheritdoc IPeripheryRegistry
    function setSuperAdjudicator(address superAdjudicator_) external onlyOwner {
        if (superAdjudicator_ == address(0)) revert INVALID_ADDRESS();
        superAdjudicator = superAdjudicator_;
        emit SuperAdjudicatorUpdated(superAdjudicator_);
    }

    /// @inheritdoc IPeripheryRegistry
    function setSuperOracle(address superOracle_) external onlyOwner {
        if (superOracle_ == address(0)) revert INVALID_ADDRESS();
        superOracle = superOracle_;
        emit SuperOracleUpdated(superOracle_);
    }

    /// @inheritdoc IPeripheryRegistry
    function setRewardToken(address rewardToken_) external onlyOwner {
        if (rewardToken_ == address(0)) revert INVALID_ADDRESS();
        rewardToken = rewardToken_;
        emit RewardTokenUpdated(rewardToken_);
    }

    /// @inheritdoc IPeripheryRegistry
    function setStakingToken(address stakingToken_) external onlyOwner {
        if (stakingToken_ == address(0)) revert INVALID_ADDRESS();
        stakingToken = stakingToken_;
        emit StakingTokenUpdated(stakingToken_);
    }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IPeripheryRegistry
    function getRegisteredHooks() external view returns (address[] memory) {
        return registeredHooks;
    }

    /// @inheritdoc IPeripheryRegistry
    function getSuperformFeeSplit() external view returns (uint256) {
        return feeSplit;
    }

    /// @inheritdoc IPeripheryRegistry
    function getTreasury() external view returns (address) {
        return treasury;
    }

    /// @inheritdoc IPeripheryRegistry
    function getReputationSystem() external view returns (address) {
        return superAdjudicator;
    }

    /// @inheritdoc IPeripheryRegistry
    function getSuperAdjudicator() external view returns (address) {
        return superAdjudicator;
    }

    /// @inheritdoc IPeripheryRegistry
    function getSuperOracle() external view returns (address) {
        return superOracle;
    }

    /// @inheritdoc IPeripheryRegistry
    function getRewardToken() external view returns (address) {
        return rewardToken;
    }

    /// @inheritdoc IPeripheryRegistry
    function getStakingToken() external view returns (address) {
        return stakingToken;
    }
}
