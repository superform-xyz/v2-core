// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IFluidLendingStakingRewards } from "../../../../vendor/fluid/IFluidLendingStakingRewards.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import {
    ISuperHook,
    ISuperHookResultOutflow,
    ISuperHookInflowOutflow,
    ISuperHookOutflow,
    ISuperHookContextAware
} from "../../../interfaces/ISuperHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";

/// @title FluidClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address stakingRewards = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
contract FluidClaimRewardHook is BaseHook, BaseClaimRewardHook, ISuperHook, ISuperHookInflowOutflow, ISuperHookOutflow, ISuperHookContextAware {
    constructor(address registry_) BaseHook(registry_, HookType.OUTFLOW) { }

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
        address stakingRewards = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
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

    /*//////////////////////////////////////////////////////////////
                                 EXTERNAL METHODS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc ISuperHook
    function preExecute(address, address, bytes memory data) external {
        outAmount = _getBalance(data);
    }

    /// @inheritdoc ISuperHook
    function postExecute(address, address, bytes memory data) external {
        outAmount = _getBalance(data) - outAmount;
    }

  
}
