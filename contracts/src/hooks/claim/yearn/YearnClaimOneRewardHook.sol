// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../libraries/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { IYearnStakingRewardsMulti } from "../../../interfaces/vendors/yearn/IYearnStakingRewardsMulti.sol";

/// @title YearnClaimOneRewardHook
/// @dev data has the following structure
/// @notice         address yearnVault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address rewardToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
contract YearnClaimOneRewardHook is BaseHook, BaseClaimRewardHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address yearnVault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        address rewardToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
        if (yearnVault == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yearnVault, abi.encodeCall(IYearnStakingRewardsMulti.getOneReward, (rewardToken)));
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory data) external onlyExecutor {
        outAmount = _getBalance(data) - outAmount;
    }
}
