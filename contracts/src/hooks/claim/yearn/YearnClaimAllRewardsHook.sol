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

//TODO: We might need to add a non-transient option
//      The following hook claims an array of rewards tokens
//      How we store those to be used in the `postExecute` is the question?
contract YearnClaimAllRewardsHook is BaseHook, BaseClaimRewardHook, ISuperHook {
    constructor(address registry_, address author_) BaseHook(registry_, author_) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function build(address, bytes memory data) external pure override returns (Execution[] memory executions) {
        address yearnVault = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        if (yearnVault == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yearnVault, abi.encodeCall(IYearnStakingRewardsMulti.getReward, ()));
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, bytes memory) external pure {}

    /// @inheritdoc ISuperHook
    function postExecute(address, bytes memory) external pure {}
}
