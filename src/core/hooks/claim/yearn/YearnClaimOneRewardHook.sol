// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IYearnStakingRewardsMulti } from "../../../../vendor/yearn/IYearnStakingRewardsMulti.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

/// @title YearnClaimOneRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
/// @notice         address rewardToken = BytesLib.toAddress(BytesLib.slice(data, 20, 20), 0);
contract YearnClaimOneRewardHook is BaseHook, BaseClaimRewardHook {
    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function build(
        address,
        address,
        bytes memory data
    )
        external
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = BytesLib.toAddress(data, 0);
        address rewardToken = BytesLib.toAddress(data, 20);
        if (yieldSource == address(0) || rewardToken == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yieldSource, abi.encodeCall(IYearnStakingRewardsMulti.getOneReward, (rewardToken)));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data);
    }

    function _postExecute(address, address, bytes calldata data) internal override {
        outAmount = _getBalance(data) - outAmount;
    }
}
