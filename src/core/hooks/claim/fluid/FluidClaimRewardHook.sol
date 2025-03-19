// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.28;

// external
import { BytesLib } from "../../../../vendor/BytesLib.sol";
import { Execution } from "modulekit/accounts/erc7579/lib/ExecutionLib.sol";
import { IFluidLendingStakingRewards } from "../../../../vendor/fluid/IFluidLendingStakingRewards.sol";

// Superform
import { BaseHook } from "../../BaseHook.sol";
import { BaseClaimRewardHook } from "../BaseClaimRewardHook.sol";
import { ISuperHook, ISuperHookNonAccounting } from "../../../interfaces/ISuperHook.sol";

/// @title FluidClaimRewardHook
/// @author Superform Labs
/// @dev data has the following structure
/// @notice         address stakingRewards = BytesLib.toAddress(BytesLib.slice(data, 0, 20), 0);
contract FluidClaimRewardHook is BaseHook, BaseClaimRewardHook, ISuperHook, ISuperHookNonAccounting {
    constructor(address registry_, address author_) BaseHook(registry_, author_, HookType.NONACCOUNTING) { }

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

    /// @inheritdoc ISuperHookNonAccounting
    /// @notice Returns the outAmount of shares
    /// @return outAmount The outAmount of shares
    function shareOutAmount() external view returns (uint256) {
        return outAmount;
    }

    /// @inheritdoc ISuperHookNonAccounting
    /// @dev This hook does not return assets, so we revert
    function assetOutAmount() external pure returns (uint256) {
        revert OUT_AMOUNT_DISABLED();
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
