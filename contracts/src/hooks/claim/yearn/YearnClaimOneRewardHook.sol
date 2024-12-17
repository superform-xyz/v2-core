// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { Execution } from "modulekit/Accounts.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

import { ISuperHook } from "../../../interfaces/ISuperHook.sol";
import { IYearnStakingRewardsMulti } from "../../../interfaces/vendors/yearn/IYearnStakingRewardsMulti.sol";

contract YearnClaimOneRewardHook is BaseHook, BaseClaimRewardHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(bytes memory data) external pure override returns (Execution[] memory executions) {
        (address yearnVault, address rewardToken) = abi.decode(data, (address, address));
        if (yearnVault == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yearnVault, abi.encodeCall(IYearnStakingRewardsMulti.getOneReward, (rewardToken)));
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        obtainedReward = _getBalance(data);
        return _returnDefaultTransientStorage();
    }

    /// @inheritdoc ISuperHook
    function postExecute(bytes memory data)
        external
        returns (address _addr, uint256 _value, bytes32 _data, bool _flag)
    {
        obtainedReward = _getBalance(data) - obtainedReward;
        return (address(0), obtainedReward, bytes32(keccak256("CLAIM")), true);
    }
}
