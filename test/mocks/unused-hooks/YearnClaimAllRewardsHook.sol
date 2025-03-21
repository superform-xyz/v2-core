// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../src/vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";

// Superform
import { BaseHook } from "../../../src/core/hooks/BaseHook.sol";
import { BaseClaimRewardHook } from "../../../src/core/hooks/claim/BaseClaimRewardHook.sol";

import { ISuperHook } from "../../../src/core/interfaces/ISuperHook.sol";
import { IYearnStakingRewardsMulti } from "../../../src/vendor/yearn/IYearnStakingRewardsMulti.sol";

//TODO: We might need to add a non-transient option
//      The following hook claims an array of rewards tokens
//      How we store those to be used in the `postExecute` is the question?
/// @notice         address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
contract YearnClaimAllRewardsHook is BaseHook, BaseClaimRewardHook, ISuperHook {
    constructor(address registry_) BaseHook(registry_, HookType.NONACCOUNTING) { }

    /*//////////////////////////////////////////////////////////////
                                 VIEW METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
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
        address yieldSource = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
        if (yieldSource == address(0)) revert ADDRESS_NOT_VALID();

        return _build(yieldSource, abi.encodeCall(IYearnStakingRewardsMulti.getReward, ()));
    }

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory) external view { }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory) external view { }
}
