// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.30;

// external
import { BytesLib } from "../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IFluidLendingStakingRewards } from "../../../vendor/fluid/IFluidLendingStakingRewards.sol";

// Superform
import {
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware,
    ISuperHookInspector
} from "../../../interfaces/ISuperHook.sol";
import { BaseHook } from "../../BaseHook.sol";
import { HookSubTypes } from "../../../libraries/HookSubTypes.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";
import { HookDataDecoder } from "../../../libraries/HookDataDecoder.sol";

/// @title FluidClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         bytes32 placeholder = bytes32(BytesLib.slice(data, 0, 32), 0);
/// @notice         address stakingRewards = BytesLib.toAddress(data, 32);
/// @notice         address rewardToken = BytesLib.toAddress(data, 52);
/// @notice         address account = BytesLib.toAddress(data, 72);
contract FluidClaimRewardHook is
    BaseHook,
    BaseClaimRewardHook,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
{
    using HookDataDecoder for bytes;

    constructor() BaseHook(HookType.OUTFLOW, HookSubTypes.CLAIM) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc BaseHook
    function _buildHookExecutions(
        address,
        address,
        bytes calldata data
    )
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address stakingRewards = data.extractYieldSource();
        if (stakingRewards == address(0)) revert ADDRESS_NOT_VALID();

        return _build(stakingRewards, abi.encodeCall(IFluidLendingStakingRewards.getReward, ()));
    }

    /// @inheritdoc ISuperHookInflowOutflow
    function decodeAmount(bytes memory) external pure returns (uint256) {
        return 0;
    }

    /// @inheritdoc ISuperHookContextAware
    function decodeUsePrevHookAmount(bytes memory) external pure returns (bool) {
        return false;
    }

    /// @inheritdoc ISuperHookOutflow
    function replaceCalldataAmount(bytes memory data, uint256) external pure returns (bytes memory) {
        return data;
    }

    /// @inheritdoc ISuperHookInspector
    function inspect(bytes calldata data) external pure override returns (bytes memory) {
        return abi.encodePacked(data.extractYieldSource(), BytesLib.toAddress(data, 52));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address account, bytes calldata data) internal override {
        address stakingRewards = BytesLib.toAddress(data, 32);
        asset = BytesLib.toAddress(data, 52);
        if (asset == address(0)) revert ASSET_ZERO_ADDRESS();

        address rewardsToken = IFluidLendingStakingRewards(stakingRewards).rewardsToken();
        if (asset != rewardsToken) revert INVALID_REWARD_TOKEN();

        _setOutAmount(_getBalance(data, account), account);
    }

    function _postExecute(address, address account, bytes calldata data) internal override {
        _setOutAmount(_getBalance(data, account) - getOutAmount(account), account);
    }
}
