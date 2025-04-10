// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IFluidLendingStakingRewards } from "../../../../vendor/fluid/IFluidLendingStakingRewards.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

/// @title FluidClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address stakingRewards = BytesLib.toAddress(data, 0);
contract FluidClaimRewardHook is BaseHook, BaseClaimRewardHook {
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
        address stakingRewards = BytesLib.toAddress(data, 0);
        if (stakingRewards == address(0)) revert ADDRESS_NOT_VALID();

        return _build(stakingRewards, abi.encodeCall(IFluidLendingStakingRewards.getReward, ()));
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
