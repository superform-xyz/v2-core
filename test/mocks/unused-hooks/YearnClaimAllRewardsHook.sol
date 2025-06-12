// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// external
import {BytesLib} from "../../../src/vendor/BytesLib.sol";
import {Execution} from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import {BaseHook} from "../../../src/core/hooks/BaseHook.sol";
import {BaseClaimRewardHook} from "../../../src/core/hooks/claim/BaseClaimRewardHook.sol";

import {IYearnStakingRewardsMulti} from "../../../src/vendor/yearn/IYearnStakingRewardsMulti.sol";

//TODO: We might need to add a non-transient option
//      The following hook claims an array of rewards tokens
//      How we store those to be used in the `postExecute` is the question?
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
contract YearnClaimAllRewardsHook is BaseHook, BaseClaimRewardHook {
    constructor() BaseHook(HookType.NONACCOUNTING, "Claim") {}

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    function _buildHookExecutions(address, address, bytes calldata data)
        internal
        pure
        override
        returns (Execution[] memory executions)
    {
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yieldSource, abi.encodeCall(IYearnStakingRewardsMulti.getReward, ()));
    }

    /*//////////////////////////////////////////////////////////////
                                 INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    function _preExecute(address, address, bytes calldata) internal override {}

    function _postExecute(address, address, bytes calldata) internal override {}
}
